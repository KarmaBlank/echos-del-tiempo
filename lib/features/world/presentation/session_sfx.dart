import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/sfx_catalog.dart';
import '../../../core/audio/sfx_service.dart';
import '../../../core/di/service_locator.dart';
import '../../../game_engine/models/battle_event.dart';
import '../../../game_engine/models/session_event.dart';
import '../../../game_engine/models/status.dart';
import '../../../game_engine/rules/session_engine.dart';
import 'session_controller.dart';
import 'session_view.dart';

/// El servicio de sonido (el del service locator; en tests, uno mudo).
final sfxServiceProvider = Provider<SfxService>((ref) =>
    sl.isRegistered<SfxService>() ? sl<SfxService>() : SfxService());

/// Conecta la sesión local con el sonido mientras `WorldScreen` está
/// montada.
final sessionSfxProvider = Provider.autoDispose<SessionSfx>((ref) {
  final controller = ref.watch(sessionControllerProvider.notifier);
  final sfx = SessionSfx(ref.watch(sfxServiceProvider),
      localId: controller.localId);
  final sub = controller.events.listen(sfx.onEvent);
  final removeView = controller.addListener(sfx.onView);
  ref.onDispose(() {
    unawaited(sub.cancel());
    removeView();
  });
  return sfx;
});

/// Traduce eventos y vistas de la sesión a efectos de sonido, fuera del
/// motor. Ver docs/specs/audio.md § "Qué evento suena".
class SessionSfx {
  SessionSfx(this.service, {required this.localId});

  final SfxService service;
  final String localId;

  String? _lastTurn;
  int? _lastTick;

  /// Un evento de `SessionController.events`.
  void onEvent(SessionEvent e) {
    switch (e) {
      case BattleStepEvent(:final events):
        for (final b in events) {
          final sfx = battleSfx(b);
          if (sfx != null) service.play(sfx);
        }
      case LevelUpEvent():
        service.play(Sfx.levelUp);
      default:
        break;
    }
  }

  /// El número flotante de `onNewFx` (línea 1469) según su color.
  Sfx? battleSfx(BattleEvent b) => switch (b) {
        HealEvent(:final mana) => mana ? Sfx.hit : Sfx.heal,
        // Daño de estados: naranja con Quemadura (420 Hz), si no verde
        // (880 Hz, como una cura: así lo hace el prototipo, línea 737).
        DamageEvent(fromStatus: true, :final statusSource) =>
          statusSource == StatusKind.burn ? Sfx.hit : Sfx.heal,
        DamageEvent(:final targetId, :final critical) =>
          !critical && _isPlayer(targetId) ? Sfx.hurt : Sfx.hit,
        UltimateUsedEvent() => Sfx.ultimate,
        // `addFx({k:'flash'})`: dúos y Colapso Temporal (líneas 781, 853).
        ActionEvent(kind: BattleActionKind.dual || BattleActionKind.enemyArea) =>
          Sfx.flash,
        _ => null,
      };

  // Los ids de jugador son los de la sala; los enemigos usan `e<uid>`.
  bool _isPlayer(String id) => _players.contains(id);
  Set<String> _players = const {};

  /// Cada vista nueva: inicio de tu turno y la cuenta regresiva.
  void onView(SessionView? view) {
    if (view == null) return;
    _players = view.session.players.keys.toSet();
    final b = view.session.battle;
    if (b == null || !view.myTurn) {
      _lastTick = null;
      return;
    }
    final turn = '${b.id}:${b.state.clock}';
    if (turn != _lastTurn) {
      _lastTurn = turn;
      _lastTick = null;
      service.play(Sfx.myTurn);
    }
    final left = (SessionEngine.turnLimit - b.turnTime).ceil();
    if (left <= 5 && left != _lastTick) {
      _lastTick = left;
      service.play(Sfx.turnTick);
    }
  }
}
