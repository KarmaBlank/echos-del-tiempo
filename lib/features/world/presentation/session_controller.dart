import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/service_locator.dart';
import '../../../game_engine/models/attributes.dart';
import '../../../game_engine/models/battle_command.dart';
import '../../../game_engine/models/battle_event.dart';
import '../../../game_engine/models/game_map.dart';
import '../../../game_engine/models/game_session.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/models/profile_store.dart';
import '../../../game_engine/models/session_action.dart';
import '../../../game_engine/models/session_event.dart';
import '../../../game_engine/rules/session_engine.dart';
import '../../../game_engine/rules/world_rules.dart';
import 'local_player.dart';
import 'session_view.dart';

/// Ritmo del host local. El prototipo corre `hostTick` cada 50 ms; los
/// tests suben [timeScale] (más segundos de juego por tick) o apagan el
/// timer con [autoStart] = false y avanzan con
/// `SessionController.advance`.
class SessionClock {
  const SessionClock({
    this.interval = const Duration(milliseconds: 50),
    this.timeScale = 1,
    this.autoStart = true,
  });

  final Duration interval;
  final double timeScale;
  final bool autoStart;

  /// Segundos de juego que avanza cada tick.
  double get dt => interval.inMicroseconds / 1e6 * timeScale;
}

final sessionEngineProvider =
    Provider<SessionEngine>((ref) => sl<SessionEngine>());

final profileStoreProvider = Provider<ProfileStore>((ref) => sl<ProfileStore>());

final sessionClockProvider = Provider<SessionClock>((ref) => const SessionClock());

/// La sesión local. `null` mientras carga el perfil. Se descarta (y
/// guarda) al salir de `WorldScreen`.
final sessionControllerProvider =
    StateNotifierProvider.autoDispose<SessionController, SessionView?>((ref) {
  final c = SessionController(
    engine: ref.watch(sessionEngineProvider),
    store: ref.watch(profileStoreProvider),
    clock: ref.watch(sessionClockProvider),
  );
  unawaited(c.start());
  return c;
});

/// Host local de una sala con un solo jugador en este dispositivo: es
/// dueño del `SessionEngine`, lo hace avanzar a ritmo fijo, traduce la
/// entrada en `SessionAction` y expone la sesión + eventos a la UI.
/// Ver docs/specs/exploration.md § "Controlador de sesión".
class SessionController extends StateNotifier<SessionView?> {
  SessionController({
    required this.engine,
    required this.store,
    this.clock = const SessionClock(),
    this.localId = 'local',
  }) : super(null);

  final SessionEngine engine;
  final ProfileStore store;
  final SessionClock clock;
  final String localId;

  /// Nombre y clase del perfil nuevo cuando no hay uno guardado.
  static const defaultName = 'Héroe';
  static const defaultClass = 'guerrero';

  /// Mensajes de sistema que se conservan.
  static const maxMessages = 50;

  /// Cada cuánto se guarda el perfil si cambió (`lastSave`, 2 s).
  static const saveEvery = 2.0;

  final local = LocalPlayer();
  final _events = StreamController<SessionEvent>.broadcast();
  GameSession? _s;
  Timer? _timer;

  WorldPanel? _panel;
  bool _autoChar = false;
  SessionMode? _lastMode;
  final _messages = <String>[];
  List<BattleEvent> _battleEvents = const [];
  int _battleSeq = 0;

  PlayerProfile? _lastSaved;
  double _sinceSave = 0;

  /// Todo lo que pasa en la sesión, en orden (sonido, animaciones).
  Stream<SessionEvent> get events => _events.stream;

  GameSession? get session => _s;

  /// La última vista emitida (para quien dibuja por frame, como Flame,
  /// sin suscribirse).
  SessionView? get view => state;

  GameMap get map => engine.mapFor(_s ?? engine.create());

  // ------------------------------------------------------------------
  // Ciclo de vida
  // ------------------------------------------------------------------

  /// Carga el perfil, crea la sala y entra el jugador local.
  Future<void> start() async {
    if (_s != null) return;
    PlayerProfile? profile;
    try {
      profile = await store.load();
    } catch (_) {
      profile = null;
    }
    if (!mounted) return;
    profile ??= PlayerProfile(name: defaultName, classId: defaultClass);
    final step = engine.addPlayer(engine.create(), localId, profile)!;
    _lastSaved = null;
    _step(step);
    _save(force: true);
    if (clock.autoStart) {
      _timer = Timer.periodic(clock.interval, (_) => _hostTick(clock.dt));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _save(force: true);
    unawaited(_events.close());
    super.dispose();
  }

  /// Avanza [seconds] de juego en ticks de 50 ms (tests y depuración).
  void advance(double seconds) {
    for (var t = 0.0; t < seconds - 1e-9; t += 0.05) {
      _hostTick(math.min(0.05, seconds - t));
    }
  }

  void _hostTick(double dt) {
    final s = _s;
    if (s == null || !mounted) return;
    _sendPosition();
    _sinceSave += dt;
    _step(engine.tick(_s!, dt));
    _save();
  }

  // ------------------------------------------------------------------
  // Jugador local
  // ------------------------------------------------------------------

  /// `updateMe`: mueve al jugador local con la entrada [ix], [iy]
  /// (-1..1). Lo llama el juego Flame en cada frame.
  void updateLocal(double dt, double ix, double iy) {
    final s = _s;
    final me = s?.players[localId];
    if (s == null || me == null) return;
    local.sync(me);
    local.step(engine.mapFor(s), ix, iy, dt,
        canMove: _canMove(s, me), gateOpen: s.gateOpen);
  }

  bool _canMove(GameSession s, SessionPlayer me) =>
      (s.mode == SessionMode.lobby || s.mode == SessionMode.field) &&
      me.alive &&
      _panel == null;

  /// `send({t:'pos'})`: la posición local al host (redondeada a 0.1).
  void _sendPosition() {
    final s = _s!;
    final me = s.players[localId];
    if (me == null) return;
    local.sync(me);
    if (!_canMove(s, me)) {
      local.moving = false;
      return;
    }
    final step = engine.apply(
        s,
        localId,
        MoveAction((local.x * 10).roundToDouble() / 10,
            (local.y * 10).roundToDouble() / 10,
            epoch: local.epoch, dir: local.dir, moving: local.moving));
    if (step != null) _s = step.state;
  }

  /// Pone al jugador local en (x, y) y se lo informa al host.
  @visibleForTesting
  void teleport(double x, double y) {
    final s = _s;
    final me = s?.players[localId];
    if (s == null || me == null) return;
    local
      ..sync(me)
      ..x = x
      ..y = y;
    _apply(MoveAction(x, y, epoch: local.epoch, dir: local.dir));
  }

  // ------------------------------------------------------------------
  // Interacción
  // ------------------------------------------------------------------

  bool get nearCounter =>
      _s?.mode == SessionMode.lobby && WorldRules.nearCounter(local.x, local.y);

  bool get nearArmory =>
      _s?.mode == SessionMode.lobby && WorldRules.nearArmory(local.x, local.y);

  /// `nearSeal`: el sello sin activar más cercano a menos de 26 px.
  MissionItem? get nearSeal {
    final s = _s;
    if (s == null || s.mode != SessionMode.field) return null;
    for (final it in s.mission?.items ?? const <MissionItem>[]) {
      if (it.kind == MissionItemKind.seal &&
          !it.done &&
          WorldRules.distance(local.x, local.y, it.x, it.y) <
              WorldRules.sealPromptRange) {
        return it;
      }
    }
    return null;
  }

  /// `nearMerchant` (el prototipo nunca genera mercader).
  bool get nearMerchant {
    final s = _s;
    if (s == null || s.mode != SessionMode.field) return false;
    final m = engine.mapFor(s).merchant;
    return m != null && WorldRules.distance(local.x, local.y, m.x, m.y) < 40;
  }

  /// E / Espacio.
  void interact() {
    final s = _s;
    if (s == null || _panel != null) return;
    if (s.mode == SessionMode.lobby) {
      if (nearCounter) {
        openPanel(WorldPanel.missionBoard);
      } else if (nearArmory) {
        openPanel(WorldPanel.armory);
      }
    } else if (s.mode == SessionMode.field) {
      final seal = nearSeal;
      if (seal != null) _apply(ActivateSealAction(seal.id));
    }
  }

  /// Teclas del mapa (no de batalla). Devuelve si la tecla es del juego
  /// (para que no mueva el foco entre botones). Ver la tabla del spec.
  bool handleKey(LogicalKeyboardKey key) {
    final s = _s;
    if (s == null) return false;
    if (key == LogicalKeyboardKey.keyE || key == LogicalKeyboardKey.space) {
      interact();
      return true;
    }
    if (key == LogicalKeyboardKey.escape) {
      closePanel();
      return true;
    }
    if (key == LogicalKeyboardKey.keyC && s.mode != SessionMode.battle) {
      toggleCharacter();
      return true;
    }
    final v = s.vote;
    if (s.mode == SessionMode.lobby &&
        v != null &&
        !v.yes.contains(localId) &&
        (key == LogicalKeyboardKey.keyY || key == LogicalKeyboardKey.keyN)) {
      vote(key == LogicalKeyboardKey.keyY);
      return true;
    }
    return movementKeys.contains(key) || key == LogicalKeyboardKey.tab;
  }

  /// Teclas que se leen del estado del teclado en cada frame.
  static final movementKeys = {
    LogicalKeyboardKey.keyW,
    LogicalKeyboardKey.keyA,
    LogicalKeyboardKey.keyS,
    LogicalKeyboardKey.keyD,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
  };

  // ------------------------------------------------------------------
  // Paneles
  // ------------------------------------------------------------------

  void openPanel(WorldPanel panel) {
    if (_s == null) return;
    _panel = panel;
    _emit();
  }

  /// `closePanel`: no cierra si hay que repartir puntos; en preparación
  /// vuelve al panel de preparación.
  void closePanel() {
    final s = _s;
    if (s == null || _panel == null || s.mustAllocate(localId)) return;
    if (s.mode == SessionMode.prep) {
      if (_panel == WorldPanel.prep) return;
      _panel = WorldPanel.prep;
    } else {
      _panel = null;
    }
    _emit();
  }

  void toggleCharacter() {
    if (_panel == WorldPanel.character) {
      closePanel();
    } else {
      openPanel(WorldPanel.character);
    }
  }

  // ------------------------------------------------------------------
  // Acciones (cada una devuelve si el host la aceptó)
  // ------------------------------------------------------------------

  bool proposeMission(String missionId) =>
      _apply(ProposeMissionAction(missionId));

  bool vote(bool yes) => _apply(VoteMissionAction(yes));

  bool setReady(bool ready) => _apply(ReadyAction(ready));

  bool cancelPrep() => _apply(const CancelPrepAction());

  bool changeClass(String classId) => _apply(ChangeClassAction(classId));

  bool allocate(Map<Attribute, int> add) => _apply(AllocateStatsAction(add));

  bool battleCommand(BattleCommand command) => _apply(BattleAction(command));

  bool backToLobby() => _apply(const BackToLobbyAction());

  bool _apply(SessionAction action) {
    final s = _s;
    if (s == null) return false;
    final step = engine.apply(s, localId, action);
    if (step == null) return false;
    _step(step);
    return true;
  }

  // ------------------------------------------------------------------
  // Estado
  // ------------------------------------------------------------------

  void _step(SessionStep step) {
    _s = step.state;
    var forceSave = false;
    for (final e in step.events) {
      switch (e) {
        case SystemMessageEvent(:final text):
          _messages.add(text);
          if (_messages.length > maxMessages) _messages.removeAt(0);
        case BattleStepEvent(:final events):
          _battleEvents = List.unmodifiable(events);
          _battleSeq++;
        case BattleStartedEvent():
          _battleEvents = const [];
        case MissionEndedEvent() || ReturnedToLobbyEvent():
          forceSave = true;
        default:
          break;
      }
      if (!_events.isClosed) _events.add(e);
    }
    final me = _s!.players[localId];
    if (me != null) local.sync(me);
    if (forceSave) _save(force: true);
    _emit();
  }

  void _save({bool force = false}) {
    final p = _s?.players[localId]?.profile;
    if (p == null || identical(p, _lastSaved)) return;
    if (!force && _sinceSave < saveEvery) return;
    _lastSaved = p;
    _sinceSave = 0;
    unawaited(store.save(p).catchError((Object _) {}));
  }

  /// Reglas automáticas de paneles de `hud()` + avisos, y emite la vista.
  void _emit() {
    final s = _s;
    if (s == null || !mounted) return;
    final mode = s.mode;
    final must = s.mustAllocate(localId);
    if (mode == SessionMode.prep &&
        (_panel == null ||
            _panel == WorldPanel.missionBoard ||
            _panel == WorldPanel.armory)) {
      _panel = WorldPanel.prep;
    }
    if (_panel == WorldPanel.prep && mode != SessionMode.prep) _panel = null;
    if (_panel == WorldPanel.character &&
        mode == SessionMode.field &&
        _lastMode == SessionMode.prep) {
      _panel = null;
    }
    _lastMode = mode;
    if ((_panel == WorldPanel.missionBoard || _panel == WorldPanel.armory) &&
        mode != SessionMode.lobby) {
      _panel = null;
    }
    if (must && _panel != WorldPanel.character) {
      _panel = WorldPanel.character;
      _autoChar = true;
    }
    if (_autoChar && !must) {
      _autoChar = false;
      if (_panel == WorldPanel.character) _panel = null;
    }
    if (mode == SessionMode.battle || mode == SessionMode.result) _panel = null;

    state = SessionView(
      session: s,
      localId: localId,
      map: engine.mapFor(s),
      panel: _panel,
      prompt: _prompt(),
      messages: List.unmodifiable(_messages),
      battleEvents: _battleEvents,
      battleEventSeq: _battleSeq,
    );
  }

  WorldPrompt? _prompt() {
    if (_panel != null) return null;
    if (nearArmory) return WorldPrompt.armory;
    if (nearCounter) return WorldPrompt.missionBoard;
    if (nearSeal != null) return WorldPrompt.seal;
    if (nearMerchant) return WorldPrompt.merchant;
    return null;
  }
}
