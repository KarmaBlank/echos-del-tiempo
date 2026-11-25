import 'dart:async';
import 'dart:typed_data';

import 'music_catalog.dart';
import 'music_renderer.dart';
import 'music_score.dart';

/// Una pieza para el reproductor: id y cómo obtener su WAV (el
/// reproductor lo pide solo si de verdad va a sonar).
class MusicSource {
  const MusicSource(this.id, this.wav, {this.hash = ''});

  final String id;

  /// Firma de la partitura (nombre del archivo en caché).
  final String hash;
  final Future<Uint8List> Function() wav;
}

/// Reproduce la música en "decks": [MusicService.loopDecks] para los
/// bucles (crossfade) y [MusicService.jingleDeck] para los jingles. El
/// juego registra `AudioplayersMusicPlayer` (docs/specs/music.md § 6).
abstract interface class MusicPlayer {
  Future<void> play(int deck, MusicSource source,
      {required bool loop, required double volume});
  Future<void> setVolume(int deck, double volume);
  Future<void> stop(int deck);

  /// Prepara la pieza (render / archivo) sin tocarla.
  Future<void> preload(MusicSource source);
}

/// No suena: tests y plataformas sin audio. Nunca pide el WAV.
class NoopMusicPlayer implements MusicPlayer {
  const NoopMusicPlayer();

  @override
  Future<void> play(int deck, MusicSource source,
      {required bool loop, required double volume}) async {}

  @override
  Future<void> setVolume(int deck, double volume) async {}

  @override
  Future<void> stop(int deck) async {}

  @override
  Future<void> preload(MusicSource source) async {}
}

/// Un deck de bucle: qué pieza tiene y su fundido.
class _Deck {
  _Deck(this.index);

  final int index;
  String? id;

  /// Fundido actual y objetivo (0..1), y velocidad (por segundo).
  double gain = 0;
  double target = 0;
  double rate = 1;

  /// Último volumen mandado al reproductor.
  double? sent;
}

/// Música de fondo: qué bucle suena (con crossfade entre dos decks),
/// jingles en cola que tapan el bucle, "duck" bajo las ULT y volumen /
/// silencio. La lógica es pura y avanza con [tick]; en el juego un
/// `Timer` la mueve solo mientras algo se está animando. Ver
/// docs/specs/music.md § 5 y § 6.
class MusicService {
  MusicService({
    MusicPlayer player = const NoopMusicPlayer(),
    Map<String, Song>? catalog,
    Future<Uint8List> Function(Song song)? render,
    bool? autoTick,
  })  : _player = player,
        _catalog = catalog,
        _render = render ?? _renderInline,
        autoTick = autoTick ?? player is! NoopMusicPlayer;

  final MusicPlayer _player;
  final Map<String, Song>? _catalog;
  final Future<Uint8List> Function(Song song) _render;

  /// Mueve los fundidos solo (`Timer.periodic`). Apagado en tests: se
  /// llama a [tick] a mano. Con el reproductor no-op nunca hay timers.
  final bool autoTick;

  static const loopDecks = 2;
  static const jingleDeck = 2;

  /// Fundidos (s).
  static const crossfadeSeconds = 1.2;
  static const battleFadeSeconds = 0.4;

  /// Corte de la pieza de batalla al terminar la pelea (≤ 200 ms).
  static const battleCutSeconds = 0.15;
  static const jingleDuckSeconds = 0.25;
  static const jingleReturnSeconds = 1.0;
  static const ultDuckSeconds = 0.15;
  static const ultReturnSeconds = 0.6;

  /// Nivel de la música bajo una ULT.
  static const ultDuckLevel = 0.3;

  /// Nivel del bucle "de fondo" mientras suena un jingle o mientras la
  /// pantalla de resultados / subida de nivel lo retiene ([bedHeld]).
  static const jingleBedLevel = 0.3;

  /// Margen después del largo de la partitura de un jingle.
  static const jingleTailSeconds = 0.3;

  /// Cambio mínimo de volumen que se manda al reproductor.
  static const volumeEpsilon = 0.004;

  static const tickInterval = Duration(milliseconds: 40);

  Map<String, Song> get catalog => _catalog ?? kMusicCatalog;

  final _decks = [_Deck(0), _Deck(1)];
  int _active = 0;

  double _volume = 0.6;
  bool _muted = false;

  /// Duck de jingle ([jingleBedLevel] mientras suena uno o mientras está
  /// retenido) y de ULT.
  double _jingleDuck = 1, _jingleTarget = 1, _jingleRate = 1;
  bool _bedHeld = false;
  double _ultDuck = 1, _ultTarget = 1, _ultRate = 1;
  double _ultLeft = 0;

  /// Held ambience duck (fishing outside the town, biome_regions.md
  /// § 7.2.3): the loop stays at [ambienceLevel] while set.
  double _ambDuck = 1, _ambTarget = 1, _ambRate = 1;

  final _jingles = <String>[];
  String? _jingle;
  double _jingleLeft = 0;
  double? _jingleSent;

  Timer? _timer;

  /// La pieza de bucle que suena o entra (`null` = silencio).
  String? get current {
    final d = _decks[_active];
    return d.target > 0 ? d.id : null;
  }

  /// El jingle que suena ahora y los que esperan.
  String? get jingle => _jingle;
  List<String> get queuedJingles => List.unmodifiable(_jingles);

  double get volume => _volume;
  bool get muted => _muted;

  /// Retiene el bucle en [jingleBedLevel] aunque no suene ningún jingle
  /// (pantallas de fin de batalla, subida de nivel y resultados). Al
  /// soltarlo, y sin jingle, vuelve a 1 en [jingleReturnSeconds].
  bool get bedHeld => _bedHeld;
  set bedHeld(bool held) {
    if (held == _bedHeld) return;
    _bedHeld = held;
    _retargetBed();
  }

  /// Holds the loop at [level] (0..1) until called again with 1, moving
  /// there in [seconds]. Fishing ambience (biome_regions.md § 7.2.3).
  void holdAmbience(double level, {double seconds = 1.5}) {
    final l = level.clamp(0.0, 1.0);
    if (l == _ambTarget) return;
    _ambTarget = l;
    _ambRate = (_ambDuck - l).abs() / (seconds <= 0 ? 0.01 : seconds);
    if (_ambRate <= 0) _ambRate = 1;
    _kick();
  }

  /// Current ambience duck factor (tests).
  double get ambienceLevel => _ambDuck;

  /// Factor actual del duck de jingle / retención (tests).
  double get bedLevel => _jingleDuck;

  /// Volumen de la música (0..1).
  set volume(double v) {
    _volume = v.clamp(0.0, 1.0);
    _apply();
  }

  /// Silencia la música (los bucles siguen avanzando en silencio).
  set muted(bool m) {
    _muted = m;
    _apply();
  }

  double get _master => _muted ? 0 : _volume;

  /// Volumen efectivo que tiene (o debería tener) el deck [i] de bucle.
  double deckVolume(int i) {
    final d = _decks[i];
    if (d.id == null) return 0;
    return d.gain * _ultDuck * _jingleDuck * _ambDuck * _master;
  }

  /// La pieza del deck [i] de bucle.
  String? deckTrack(int i) => _decks[i].id;

  MusicSource source(String id) {
    final song = catalog[id]!;
    return MusicSource(id, () => _render(song), hash: song.hash);
  }

  static Future<Uint8List> _renderInline(Song song) async =>
      const MusicRenderer().renderWav(song);

  /// Pide el bucle [id] (`null` = silencio) con un fundido de entrada de
  /// [fade] s; la pieza que sale se va en [fadeOut] s (por defecto, lo
  /// mismo que [fade]; [battleCutSeconds] al cortar la batalla).
  void playTrack(String? id,
      {double fade = crossfadeSeconds, double? fadeOut}) {
    if (id != null && !catalog.containsKey(id)) id = null;
    final active = _decks[_active];
    final other = _decks[1 - _active];
    final rate = 1 / (fade <= 0 ? 0.001 : fade);
    final out = fadeOut ?? fade;
    final outRate = 1 / (out <= 0 ? 0.001 : out);
    if (id == null) {
      active
        ..target = 0
        ..rate = outRate;
      other
        ..target = 0
        ..rate = outRate;
      _kick();
      return;
    }
    if (active.id == id) {
      if (active.target < 1) {
        active
          ..target = 1
          ..rate = rate;
        other
          ..target = 0
          ..rate = outRate;
        _kick();
      }
      return;
    }
    if (other.id == id && other.gain > 0) {
      // Se estaba yendo: vuelve sin reiniciar.
      other
        ..target = 1
        ..rate = rate;
    } else {
      if (other.id != null) unawaited(_safe(_player.stop(other.index)));
      other
        ..id = id
        ..gain = 0
        ..target = 1
        ..rate = rate
        ..sent = 0;
      unawaited(
          _safe(_player.play(other.index, source(id), loop: true, volume: 0)));
    }
    active
      ..target = 0
      ..rate = outRate;
    _active = other.index;
    _kick();
    _apply();
  }

  /// Toca el jingle [id] (en cola si ya suena otro). Los bucles bajan a
  /// [jingleBedLevel] mientras suena. Con [interrupt] corta el jingle que
  /// suena (la cola sigue después). Cambiar de bucle nunca corta un
  /// jingle: solo otro jingle con [interrupt], silenciar o [dispose].
  void playJingle(String id, {bool interrupt = false}) {
    if (!catalog.containsKey(id) || _muted) return;
    if (_jingle == null || interrupt) {
      _startJingle(id);
    } else {
      _jingles.add(id);
    }
  }

  void _startJingle(String id) {
    _jingle = id;
    _jingleLeft = catalog[id]!.seconds + jingleTailSeconds;
    _jingleSent = _master;
    unawaited(_safe(
        _player.play(jingleDeck, source(id), loop: false, volume: _master)));
    _retargetBed();
  }

  /// El bucle baja a [jingleBedLevel] (en [jingleDuckSeconds]) mientras
  /// suena un jingle o está retenido; si no, vuelve a 1 (en
  /// [jingleReturnSeconds]).
  void _retargetBed() {
    const span = 1 - jingleBedLevel;
    if (_jingle != null || _bedHeld) {
      _jingleTarget = jingleBedLevel;
      _jingleRate = span / jingleDuckSeconds;
    } else {
      _jingleTarget = 1;
      _jingleRate = span / jingleReturnSeconds;
    }
    _kick();
  }

  /// Baja la música durante [seconds] (cinemática de ULT).
  void duck(double seconds, {double level = ultDuckLevel}) {
    if (seconds <= 0) return;
    _ultLeft = seconds > _ultLeft ? seconds : _ultLeft;
    _ultTarget = level;
    _ultRate = (1 - level) / ultDuckSeconds;
    _kick();
  }

  /// Prepara piezas en segundo plano (render a disco), una por vez.
  Future<void> preload(List<String> ids) async {
    for (final id in ids) {
      if (!catalog.containsKey(id)) continue;
      await _safe(_player.preload(source(id)));
    }
  }

  /// Avanza los fundidos, el duck y la cola de jingles [dt] segundos.
  void tick(double dt) {
    for (final d in _decks) {
      d.gain = _approach(d.gain, d.target, d.rate * dt);
      if (d.id != null && d.gain <= 0 && d.target <= 0) {
        unawaited(_safe(_player.stop(d.index)));
        d
          ..id = null
          ..sent = null;
      }
    }
    if (_ultLeft > 0) {
      _ultLeft -= dt;
      if (_ultLeft <= 0) {
        _ultLeft = 0;
        _ultTarget = 1;
        _ultRate = (1 - ultDuckLevel) / ultReturnSeconds;
      }
    }
    _ultDuck = _approach(_ultDuck, _ultTarget, _ultRate * dt);
    if (_jingle != null) {
      _jingleLeft -= dt;
      if (_jingleLeft <= 0) {
        _jingle = null;
        if (_jingles.isNotEmpty) {
          _startJingle(_jingles.removeAt(0));
        } else {
          unawaited(_safe(_player.stop(jingleDeck)));
          _retargetBed();
        }
      }
    }
    _jingleDuck = _approach(_jingleDuck, _jingleTarget, _jingleRate * dt);
    _ambDuck = _approach(_ambDuck, _ambTarget, _ambRate * dt);
    _apply();
    if (!animating) _stopTimer();
  }

  /// Hay fundidos, duck o jingles en curso.
  bool get animating =>
      _decks.any((d) => d.gain != d.target) ||
      _ultLeft > 0 ||
      _ultDuck != _ultTarget ||
      _jingle != null ||
      _jingleDuck != _jingleTarget ||
      _ambDuck != _ambTarget;

  /// Manda a cada deck el volumen efectivo si cambió.
  void _apply() {
    for (var i = 0; i < loopDecks; i++) {
      final d = _decks[i];
      if (d.id == null) continue;
      final v = deckVolume(i);
      final last = d.sent;
      if (last == null ||
          (v - last).abs() > volumeEpsilon ||
          (v == 0 && last != 0) ||
          (v == 1 && last != 1)) {
        d.sent = v;
        unawaited(_safe(_player.setVolume(i, v)));
      }
    }
    if (_jingle != null && _jingleSent != _master) {
      _jingleSent = _master;
      unawaited(_safe(_player.setVolume(jingleDeck, _master)));
    }
  }

  void _kick() {
    if (!autoTick || _timer != null || !animating) return;
    final sw = Stopwatch()..start();
    var last = Duration.zero;
    _timer = Timer.periodic(tickInterval, (_) {
      final now = sw.elapsed;
      tick((now - last).inMicroseconds / 1e6);
      last = now;
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  static double _approach(double x, double target, double step) {
    if (x < target) return x + step >= target ? target : x + step;
    if (x > target) return x - step <= target ? target : x - step;
    return x;
  }

  static Future<void> _safe(Future<void> f) => f.catchError((Object _) {});

  void dispose() {
    _stopTimer();
    for (var i = 0; i <= jingleDeck; i++) {
      unawaited(_safe(_player.stop(i)));
    }
  }
}
