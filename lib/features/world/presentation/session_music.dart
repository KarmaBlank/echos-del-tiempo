import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/music/music_catalog.dart';
import '../../../core/audio/music/music_service.dart';
import '../../../core/audio/presentation/audio_providers.dart';
import '../../../game_engine/models/battle_event.dart';
import '../../../game_engine/models/battle_state.dart';
import '../../../game_engine/models/game_session.dart';
import '../../../game_engine/rules/map_generator.dart';
import '../../combat/presentation/scene/ult_cinematic.dart';
import 'session_controller.dart';
import 'session_view.dart';

/// Conecta la sesión local con la música mientras `WorldScreen` está
/// montada (docs/specs/music.md § 5).
final sessionMusicProvider = Provider.autoDispose<SessionMusic>((ref) {
  final controller = ref.watch(sessionControllerProvider.notifier);
  final music = SessionMusic(
    ref.watch(musicServiceProvider),
    localId: controller.localId,
    themeOf: (id) => controller.engine.catalog.mission(id)?.theme,
  );
  final remove = controller.addListener(music.onView);
  ref.onDispose(remove);
  return music;
});

/// Qué pieza corresponde a cada estado (función pura).
abstract final class MusicSelector {
  /// El pueblo dentro del mapa del mundo (tiles `0..25 × 0..13`,
  /// worldgen.md § 6.5) y el borde de salida (histéresis de 2 tiles).
  static const townWidth = 26, townHeight = 14;
  static const exitMargin = 2;

  /// Si el tile ([tx], [ty]) cuenta como pueblo, sabiendo si el jugador
  /// [wasInTown]: entra con el rectángulo del pueblo, sale recién al
  /// alejarse [exitMargin] tiles.
  static bool inTown(int tx, int ty, {required bool wasInTown}) {
    if (tx < townWidth && ty < townHeight) return true;
    if (!wasInTown) return false;
    return tx < townWidth + exitMargin && ty < townHeight + exitMargin;
  }

  /// Zona con pieza propia para una misión sin zona, por su tema.
  static int zoneForTheme(String? theme) => switch (theme) {
        'pradera' => 1,
        'bosque' => 2,
        'ruinas' => 3,
        'cavernas' => 4,
        'fortaleza' => 5,
        'laberinto' => 6,
        'grieta' => 7,
        'cementerio' => 8,
        'abismo' => 9,
        'corazon' => 10,
        _ => 3,
      };

  /// Id del jefe final (bosses.md): su batalla usa [Music.bossFinal].
  static const finalBossId = 'devorador';

  /// Id (`enemyType`) del jefe de una batalla, si hay uno.
  static String? bossIdOf(BattleState? state) {
    if (state == null) return null;
    for (final e in state.enemies) {
      if (e.boss) return e.enemyType;
    }
    return null;
  }

  /// Piezas de batalla (se cortan rápido al terminar la pelea).
  static bool isBattleTrack(String id) =>
      id == Music.battle || id == Music.boss || id == Music.bossFinal;

  /// La pieza de bucle del estado.
  static String trackFor({
    required SessionMode mode,
    bool inTown = true,
    int zone = 0,
    String? theme,
    bool boss = false,
    String? bossId,
  }) {
    switch (mode) {
      case SessionMode.lobby:
        return inTown ? Music.town : Music.overworld;
      case SessionMode.prep:
      case SessionMode.result:
        return Music.town;
      case SessionMode.battle:
        if (!boss) return Music.battle;
        return bossId == finalBossId ? Music.bossFinal : Music.boss;
      case SessionMode.field:
      case SessionMode.levelUp:
        final z = Music.zones.contains(zone) ? zone : zoneForTheme(theme);
        return Music.zone(z);
    }
  }

  /// Duración (ms) de la cinemática de ULT más larga de un paso de
  /// batalla (0 si no hay ULT).
  static int ultMs(List<BattleEvent> events) {
    var ms = 0;
    for (final e in events) {
      final int? t = switch (e) {
        ActionEvent(:final kind, :final skillId)
            when kind == BattleActionKind.ultimate =>
          ultScriptFor(skillId).totalMs,
        EnemyUltEvent(:final ultId) => ultScriptFor(ultId).totalMs,
        _ => null,
      };
      if (t != null && t > ms) ms = t;
    }
    return ms;
  }
}

/// Traduce las vistas de la sesión a música: el bucle según el modo,
/// jingles (victoria / derrota / nivel / zona) y el duck de las ULT. Todo
/// sale de las vistas, así suena igual en el host y en los clientes.
///
/// Fin de batalla (docs/specs/music.md § 5.1): la pieza de batalla se
/// corta en [MusicService.battleCutSeconds], suena el jingle entero y la
/// pieza de la zona vuelve de fondo, retenida en
/// [MusicService.jingleBedLevel] hasta que no quede jingle y se cierren
/// el fin de batalla, la subida de nivel y los resultados. El jingle de
/// nivel espera a que aparezca la pantalla de subida de nivel y ahí corta
/// el de victoria.
class SessionMusic {
  SessionMusic(this.music, {required this.localId, this.themeOf});

  final MusicService music;
  final String localId;

  /// Tema del mapa de una misión (para misiones sin zona).
  final String? Function(String missionId)? themeOf;

  bool _started = false;
  bool _inTown = true;
  int? _jingledBattle;
  int? _resultId;
  int? _level;
  int? _mastery;
  int _battleSeq = 0;

  /// El jugador local subió de nivel (o de maestría) en una batalla que
  /// todavía se muestra: su jingle espera a que se cierre.
  bool _levelUpPending = false;

  /// Desenlace del último jingle de batalla todavía "vigente" (se olvida
  /// al volver al campo o al lobby).
  bool? _lastOutcome;

  /// La última pieza pedida (tests).
  String? get track => _track;
  String? _track;

  void onView(SessionView? view) {
    if (view == null) return;
    final s = view.session;
    final me = view.me;
    if (me != null) {
      const tile = MapGenerator.tileSize;
      _inTown = MusicSelector.inTown(
          (me.x / tile).floor(), (me.y / tile).floor(),
          wasInTown: _inTown);
    }

    if (!_started) {
      // Lo que ya pasó antes de mirar no suena.
      _started = true;
      _jingledBattle = s.battle?.state.ended ?? false ? s.battle!.id : null;
      _resultId = s.result?.id;
      _level = me?.profile.level;
      _battleSeq = view.battleEventSeq;
      for (final p in s.playerList) {
        _ascensions[p.id] = p.profile.ascension.id;
      }
    } else {
      _jingles(view);
      if (view.battleEventSeq != _battleSeq) {
        _battleSeq = view.battleEventSeq;
        final ms = MusicSelector.ultMs(view.battleEvents);
        if (ms > 0) music.duck(ms / 1000);
      }
    }

    // La batalla ya tiene desenlace (la pausa final antes de volver): de
    // fondo suena la pieza de la zona, no la de batalla.
    final ended =
        s.mode == SessionMode.battle && (s.battle?.state.ended ?? false);
    final m = s.mission;
    final t = MusicSelector.trackFor(
      mode: ended ? SessionMode.field : s.mode,
      inTown: _inTown,
      zone: m?.zone ?? 0,
      theme: m == null ? null : themeOf?.call(m.missionId),
      boss: s.battle?.boss ?? false,
      bossId: MusicSelector.bossIdOf(s.battle?.state),
    );
    if (t != _track) {
      final leavingBattle =
          _track != null && MusicSelector.isBattleTrack(_track!);
      _track = t;
      final intoBattle = MusicSelector.isBattleTrack(t);
      music.playTrack(t,
          fade: intoBattle
              ? MusicService.battleFadeSeconds
              : MusicService.crossfadeSeconds,
          fadeOut: leavingBattle && !intoBattle
              ? MusicService.battleCutSeconds
              : null);
    }
    music.bedHeld =
        ended || s.mode == SessionMode.levelUp || s.mode == SessionMode.result;
  }

  void _jingles(SessionView view) {
    final s = view.session;
    if (s.mode == SessionMode.field || s.mode == SessionMode.lobby) {
      _lastOutcome = null;
    }
    final b = s.battle;
    final outcome = b?.state.outcome;
    if (b != null && outcome != null && b.id != _jingledBattle) {
      _jingledBattle = b.id;
      _lastOutcome = outcome.victory;
      music.playJingle(outcome.victory ? Music.victory : Music.defeat);
    }
    final r = s.result;
    if (r != null && r.id != _resultId) {
      _resultId = r.id;
      if (_lastOutcome != r.success) {
        music.playJingle(r.success ? Music.victory : Music.defeat);
      }
      _lastOutcome = r.success;
      if (r.unlocked[localId] != null) music.playJingle(Music.zoneUnlocked);
      // Eco completado con puntos nuevos de Atlas (ecos_atlas.md § 5.1).
      if (r.success &&
          r.missionId == 'eco' &&
          (view.atlasGain?.points ?? 0) > 0) {
        music.playJingle(Music.zoneUnlocked);
      }
    }
    final level = view.me?.profile.level;
    final last = _level;
    if (level != null && last != null && level > last) {
      _levelUpPending = true;
    }
    if (level != null) _level = level;
    // Maestría (§ 6): el mismo jingle que subir de nivel.
    final mastery = view.me?.profile.mastery;
    final lastM = _mastery;
    if (mastery != null && lastM != null && mastery > lastM) {
      _levelUpPending = true;
    }
    if (mastery != null) _mastery = mastery;
    // Suena al cerrarse la batalla: si aparece la pantalla de subida de
    // nivel, corta el jingle de victoria; si no (maestría, nivel sin
    // pausa), va en cola detrás.
    if (_levelUpPending && s.mode != SessionMode.battle) {
      _levelUpPending = false;
      music.playJingle(Music.levelUp, interrupt: s.mode == SessionMode.levelUp);
    }
    // Ascensión de cualquiera de la sala (docs/specs/ascension.md § 5).
    var ascended = false;
    for (final p in s.playerList) {
      final now = p.profile.ascension.id;
      final was = _ascensions[p.id];
      if (now != null && was == null && _ascensions.containsKey(p.id)) {
        ascended = true;
      }
      _ascensions[p.id] = now;
    }
    if (ascended) music.playJingle(Music.ascension);
  }

  /// La ascensión de cada jugador en la última vista.
  final _ascensions = <String, String?>{};
}
