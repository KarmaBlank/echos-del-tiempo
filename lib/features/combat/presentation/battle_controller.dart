import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/service_locator.dart';
import '../../../game_engine/models/battle_command.dart';
import '../../../game_engine/models/battle_event.dart';
import '../../../game_engine/models/battle_state.dart';
import '../../../game_engine/rules/battle_engine.dart';

/// Con qué se arma una batalla.
class BattleSetup {
  final List<BattlePartyMember> party;
  final List<String> enemyTypes;
  final bool elite;
  final String? triggeredBy;

  const BattleSetup({
    required this.party,
    required this.enemyTypes,
    this.elite = false,
    this.triggeredBy,
  });
}

/// Lo que la pantalla muestra: el estado del motor + los eventos del
/// último paso (para animar números) + si espera input del jugador.
class BattleView {
  final BattleState battle;
  final List<BattleEvent> lastEvents;
  final bool waitingForPlayer;

  const BattleView(this.battle,
      {this.lastEvents = const [], this.waitingForPlayer = false});
}

/// Cuánto se espera entre pasos para que se puedan leer. Los tests lo
/// pisan con `Duration.zero`.
final battlePaceProvider =
    Provider<Duration>((ref) => const Duration(milliseconds: 700));

final battleEngineProvider = Provider<BattleEngine>((ref) => sl<BattleEngine>());

final battleControllerProvider = StateNotifierProvider.autoDispose
    .family<BattleController, BattleView, BattleSetup>(
  (ref, setup) => BattleController(
    ref.watch(battleEngineProvider),
    setup,
    pace: ref.watch(battlePaceProvider),
  ),
);

/// Maneja el ritmo de la batalla local (`battleTick` del prototipo):
/// pide el próximo turno, hace actuar a los enemigos con pausas para
/// leer el log, y frena cuando le toca a un jugador.
///
/// Hoy todos los jugadores se controlan desde este dispositivo (demo
/// local). En P2P esto lo hace el host y los demás reciben snapshots por
/// `NetSession`.
class BattleController extends StateNotifier<BattleView> {
  BattleController(this._engine, BattleSetup setup, {required this.pace})
      : super(BattleView(_engine
            .start(
              party: setup.party,
              enemyTypes: setup.enemyTypes,
              elite: setup.elite,
              triggeredBy: setup.triggeredBy,
            )
            .state)) {
    unawaited(_run(initialPause: 1.2));
  }

  final BattleEngine _engine;
  final Duration pace;
  bool _running = false;

  /// El jugador de turno actúa. Devuelve false si el motor lo rechaza
  /// (MP insuficiente, no es su turno...).
  bool command(BattleCommand cmd) {
    final cur = state.battle.current;
    if (_running || !state.waitingForPlayer || cur == null) return false;
    final step = _engine.command(state.battle, cur.id, cmd);
    if (step == null) return false;
    _apply(step);
    unawaited(_run(initialPause: 1));
    return true;
  }

  void _apply(BattleStep step, {bool waiting = false}) {
    state = BattleView(step.state,
        lastEvents: step.events, waitingForPlayer: waiting);
  }

  Future<void> _wait(double factor) =>
      Future.delayed(pace * factor);

  Future<void> _run({double initialPause = 0}) async {
    if (_running) return;
    _running = true;
    if (initialPause > 0) await _wait(initialPause);

    while (mounted && !state.battle.ended) {
      final b = state.battle;
      final cur = b.current;
      if (cur == null || !cur.alive) {
        final before = b.log;
        _apply(_engine.nextTurn(b));
        final next = state.battle.current;
        // Pausa larga si hubo daño de estados o perdió el turno.
        final eventful = state.battle.log != before &&
            (next == null || !next.isPlayer);
        if (eventful || state.lastEvents.any((e) => e is DamageEvent)) {
          await _wait(1.3);
        }
        continue;
      }
      if (!cur.isPlayer) {
        await _wait(0.5);
        if (!mounted) return;
        final step = _engine.enemyTurn(state.battle);
        if (step != null) _apply(step);
        await _wait(1.4);
        continue;
      }
      // Turno de un jugador: esperamos su comando.
      state = BattleView(b, lastEvents: state.lastEvents, waitingForPlayer: true);
      break;
    }
    _running = false;
  }
}
