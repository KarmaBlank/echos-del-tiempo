import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../game_engine/models/battle_command.dart';
import '../../../game_engine/models/game_session.dart';
import '../../../game_engine/rules/session_engine.dart';
import '../../combat/presentation/battle_screen.dart';
import '../../combat/presentation/game_sprites.dart';
import '../../combat/presentation/scene/battle_layout.dart';
import 'map/actor_painter.dart';
import 'map/tile_painter.dart';
import 'session_view.dart';

/// La batalla de la sesión (`S.battle`): dibuja `session.battle.state`
/// con [BattleView] sobre el mapa de la misión (en el lugar del enemigo
/// que la empezó) y manda los comandos del jugador local como
/// `BattleAction` cuando el host espera su turno. Ver
/// docs/specs/exploration.md § "Batalla" y
/// docs/specs/battle_presentation.md.
class SessionBattleScreen extends StatefulWidget {
  const SessionBattleScreen({
    super.key,
    required this.view,
    required this.onCommand,
    this.sprites,
    this.battleKey,
  });

  final SessionView view;
  final bool Function(BattleCommand command) onCommand;
  final GameSprites? sprites;

  /// Para mandarle las teclas de batalla (1-9, Q/Tab, Esc).
  final GlobalKey<BattleViewState>? battleKey;

  @override
  State<SessionBattleScreen> createState() => _SessionBattleScreenState();
}

class _SessionBattleScreenState extends State<SessionBattleScreen> {
  final _tiles = TilePainter();
  ActorPainter? _actors;

  /// Arena calculada una vez por batalla (`SessionBattle.id`).
  int? _arenaBattle;
  BattleArena? _arena;

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    final b = view.session.battle;
    if (b == null) return const SizedBox.shrink();
    if (_arenaBattle != b.id) {
      _arenaBattle = b.id;
      _arena = _buildArena(view, b);
    }
    return BattleView(
      key: widget.battleKey,
      battle: b.state,
      events: view.battleEvents,
      eventSeq: view.battleEventSeq,
      battleId: b.id,
      canAct: view.myTurn,
      turnTimeLeft:
          b.waitingForPlayer ? SessionEngine.turnLimit - b.turnTime : null,
      sprites: widget.sprites,
      arena: _arena,
      localId: view.localId,
      pendingPoints: {
        for (final p in view.session.playerList) p.id: p.profile.points,
      },
      onCommand: widget.onCommand,
    );
  }

  /// `startBattle`: la batalla se dibuja donde está el enemigo del campo;
  /// el lado lo decide el jugador más cercano (el motor no guarda quién
  /// lo tocó; las posiciones del campo no cambian durante la batalla).
  BattleArena? _buildArena(SessionView view, SessionBattle b) {
    final s = view.session;
    final mission = s.mission;
    FieldEnemy? en;
    for (final e in mission?.enemies ?? const <FieldEnemy>[]) {
      if (e.id == b.fieldEnemyId) en = e;
    }
    if (en == null) return null;
    final map = view.map;
    const ts = TilePainter.ts;
    final mw = map.width * ts, mh = map.height * ts;
    SessionPlayer? trig;
    var best = double.infinity;
    for (final p in s.playerList) {
      final d = math.sqrt(math.pow(p.x - en.x, 2) + math.pow(p.y - en.y, 2));
      if (d < best) {
        best = d;
        trig = p;
      }
    }
    final side = BattleArena.sideFor(
        enemyX: en.x, triggerX: trig?.x, worldWidth: mw);
    final me = s.players[view.localId];
    final cx = en.x + side * 34, cy = en.y;
    final battleEnemyId = en.id;
    final sprites = widget.sprites;
    if (sprites != null) _actors ??= ActorPainter(sprites);

    void paintWorld(Canvas c, Rect visible, double t) {
      // `widget.view` es siempre el último snapshot de la sesión.
      final cur = widget.view;
      final m = cur.map;
      final x0 = math.max(0, (visible.left / ts).floor());
      final y0 = math.max(0, (visible.top / ts).floor());
      final x1 = math.min(m.width - 1, (visible.right / ts).floor() + 1);
      final y1 = math.min(m.height - 1, (visible.bottom / ts).floor() + 1);
      for (var y = y0; y <= y1; y++) {
        for (var x = x0; x <= x1; x++) {
          _tiles.draw(c, m.tileAt(x, y), x * ts, y * ts, m.theme, x, y,
              t: t, gateOpen: cur.session.gateOpen, lobby: m.lobby);
        }
      }
      final actors = _actors;
      if (actors == null) return;
      final merchant = m.merchant;
      if (merchant != null) {
        actors.text(c, 'TIENDA', merchant.x, merchant.y - 34,
            const Color(0xFFFFD166), 6);
      }
      // Enemigos del campo lejos de la batalla (> 130 px del centro).
      for (final e in cur.session.mission?.enemies ?? const <FieldEnemy>[]) {
        if (!e.alive || e.id == battleEnemyId) continue;
        if (math.sqrt(math.pow(e.x - cx, 2) + math.pow(e.y - cy, 2)) < 130) {
          continue;
        }
        actors.enemy(c,
            type: e.group.first, x: e.x, y: e.y, dir: e.dir, t: t, elite: e.elite);
        if (e.elite) {
          actors.text(c, '★ÉLITE', e.x, e.y - 34, const Color(0xFFFFD166), 6);
        }
        if (e.boss) {
          actors.text(c, 'JEFE', e.x, e.y - 48, const Color(0xFFFF4757), 7);
        }
      }
    }

    return BattleArena(
      anchorX: en.x,
      anchorY: en.y,
      side: side,
      worldWidth: mw,
      worldHeight: mh,
      fieldFocusX: me?.x,
      fieldFocusY: me?.y,
      paintWorld: paintWorld,
    );
  }
}
