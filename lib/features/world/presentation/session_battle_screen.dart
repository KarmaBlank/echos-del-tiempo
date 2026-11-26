import 'package:material_ui/material_ui.dart';

import '../../../game_engine/models/battle_command.dart';
import '../../../game_engine/models/bestiary.dart';
import '../../../game_engine/models/game_session.dart';
import '../../../game_engine/rules/eco_rules.dart';
import '../../../game_engine/rules/trial_rules.dart';
import '../../combat/presentation/battle_screen.dart';
import '../../combat/presentation/game_sprites.dart';
import '../../combat/presentation/scene/arena/arena_painter.dart';
import '../../combat/presentation/scene/arena/arena_spec.dart';
import '../../combat/presentation/scene/battle_layout.dart';
import '../../combat/presentation/scene/battle_scene.dart';
import 'session_view.dart';

/// La batalla de la sesión (`S.battle`): dibuja `session.battle.state`
/// con [BattleView] en una **arena temática** propia (por zona y por tipo
/// de encuentro, nunca sobre el mapa) y manda los comandos del jugador
/// local como `BattleAction` cuando el host espera su turno. Ver
/// docs/specs/exploration.md § "Batalla" y
/// docs/specs/battle_presentation.md § "Arenas".
class SessionBattleScreen extends StatefulWidget {
  const SessionBattleScreen({
    super.key,
    required this.view,
    required this.onCommand,
    this.sprites,
    this.battleKey,
    this.sceneOptions = const SceneOptions(),
    this.onAuto,
    this.actionGate,
    this.onCancelQueued,
    this.onMoveQueued,
    this.onConfirmQueue,
  });

  /// Moves a queued command to another position (turn_modes.md § 3.1).
  final void Function(String id, int to)? onMoveQueued;

  /// The local player agrees the queue order (turn_modes.md § 3.1).
  final void Function()? onConfirmQueue;

  /// Withdraws a queued command (turn_modes.md § 3.1).
  final void Function(String id)? onCancelQueued;

  /// Prende / apaga el AUTO de un compañero (docs/specs/solo_party.md § 4).
  final void Function(String id, bool on)? onAuto;

  /// TUTORIAL: lo que no es del paso sale desactivado con el motivo
  /// (combat_tutorial.md § 4.1).
  final String? Function(String actionId)? actionGate;

  final SessionView view;
  final bool Function(BattleCommand command) onCommand;
  final GameSprites? sprites;

  /// Para mandarle las teclas de batalla (1-9, Q/Tab, Esc).
  final GlobalKey<BattleViewState>? battleKey;

  /// Ajustes del jugador para la escena (docs/specs/settings.md).
  final SceneOptions sceneOptions;

  @override
  State<SessionBattleScreen> createState() => _SessionBattleScreenState();
}

class _SessionBattleScreenState extends State<SessionBattleScreen> {
  final _arenas = ArenaPainter();

  /// Arena calculada una vez por batalla (`SessionBattle.id`).
  int? _arenaBattle;
  BattleArena? _arena;

  @override
  void dispose() {
    _arenas.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    final b = view.session.battle;
    if (b == null) return const SizedBox.shrink();
    if (_arenaBattle != b.id) {
      _arenaBattle = b.id;
      _arena = BattleArena.stage(kind: kindOf(b), paintWorld: _paintArena);
    }
    return BattleView(
      key: widget.battleKey,
      battle: view.shownBattle ?? b.state,
      events: view.battleEvents,
      eventSeq: view.battleEventSeq,
      battleId: b.id,
      // Con el cartel del tutorial abierto no se actúa (§ 4.1).
      canAct: view.myTurn && view.session.tutorial?.card == null,
      // Sin límite (tiempo de turno de la sala): sin reloj.
      // El TUTORIAL no tiene límite de 30 s (combat_tutorial.md § 4.1).
      turnTimeLeft: b.waitingForPlayer &&
              view.session.turnLimit != null &&
              view.session.tutorial == null
          ? view.session.turnLimit! - b.turnTime
          : null,
      turnLimit: view.session.turnLimit ?? 30,
      sprites: widget.sprites,
      arena: _arena,
      localId: view.localId,
      pendingPoints: {
        for (final p in view.session.playerList) p.id: p.profile.points,
      },
      onCommand: widget.onCommand,
      sceneOptions: widget.sceneOptions,
      bestiary: view.bestiary ?? BestiaryProgress.empty,
      enemyLevel: b.level > 0 ? b.level : null,
      companions: view.companions.toSet(),
      auto: view.auto,
      onAuto: widget.onAuto,
      actionGate: widget.actionGate,
      queue: [
        for (final q in view.battleQueue)
          BattleQueueEntry(
            q.playerId,
            b.state.byId(q.playerId)?.name ?? q.playerId,
            battleQueueGlyph(q.command),
            mine: view.controls(q.playerId),
          ),
      ],
      onCancelQueued: widget.onCancelQueued,
      onMoveQueued: view.canAgreeQueue ? widget.onMoveQueued : null,
      onConfirmQueue: view.canAgreeQueue &&
              !b.queueReady.contains(view.localId)
          ? widget.onConfirmQueue
          : null,
      queueAgreed: view.queueAgreement,
      bossEco: view.session.mission?.bossEco ?? false,
    );
  }

  /// Tipo de encuentro de la batalla de la sesión (las banderas de
  /// `SessionBattle` y, si faltan, las del estado).
  static EncounterKind kindOf(SessionBattle b) {
    if (b.boss) return EncounterKind.boss;
    final k = encounterKindOf(b.state);
    if (k == EncounterKind.normal && b.elite) return EncounterKind.elite;
    return k;
  }

  /// Arena de la batalla en curso según la zona, si es Eco / Prueba y el
  /// tipo de encuentro (la fase del jefe puede cambiarla en la pelea).
  static ArenaSpec specOf(SessionView view) {
    final s = view.session;
    final b = s.battle;
    final mission = s.mission;
    final base = b == null
        ? const ArenaSpec(theme: ArenaTheme.pueblo, kind: EncounterKind.normal)
        : selectArena(
            battle: b.state,
            mapTheme: view.map.theme,
            zone: mission?.zone ?? view.map.zone,
            trial: mission?.missionId == TrialRules.missionId,
            eco: mission?.missionId == EcoRules.missionId,
          );
    if (b == null) return base;
    final kind = kindOf(b);
    return kind == base.kind
        ? base
        : ArenaSpec(
            theme: base.theme,
            kind: kind,
            bossType: base.bossType,
            phase2: base.phase2,
            eco: base.eco,
            abyss: base.abyss);
  }

  void _paintArena(Canvas c, Rect visible, double t) {
    // `widget.view` es siempre el último snapshot de la sesión.
    _arenas.paint(c, visible, t, specOf(widget.view),
        density: widget.sceneOptions.particles);
  }
}
