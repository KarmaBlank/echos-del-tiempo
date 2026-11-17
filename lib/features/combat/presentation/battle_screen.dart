import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/retro_bar.dart';
import '../../../app/theme/retro_panel.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../game_engine/data/skills_catalog.dart';
import '../../../game_engine/models/battle_command.dart';
import '../../../game_engine/models/battle_event.dart';
import '../../../game_engine/models/battle_state.dart';
import '../../../game_engine/models/status.dart';
import 'game_sprites.dart';
import 'scene/battle_layout.dart';
import 'scene/battle_painter.dart';
import 'scene/battle_scene.dart';
import 'skill_info.dart';

/// Pantalla de batalla 8 bits: la escena del prototipo (grupo y enemigos
/// sobre el mapa, efectos, franja de turnos) con el log, el grupo y el
/// menú de comandos como overlays Flutter. Escena y efectos en
/// docs/specs/battle_presentation.md; menú y teclas en
/// docs/specs/exploration.md § "Batalla".
///
/// No tiene lógica de juego: dibuja el [battle] que recibe y entrega los
/// comandos del jugador local por [onCommand]. Quien la usa decide de
/// dónde sale el estado (hoy: la sesión, `SessionBattleScreen`).
class BattleView extends StatefulWidget {
  const BattleView({
    super.key,
    required this.battle,
    required this.onCommand,
    this.events = const [],
    this.eventSeq = 0,
    this.battleId = 0,
    this.canAct = false,
    this.turnTimeLeft,
    this.sprites,
    this.arena,
    this.localId,
    this.random,
  });

  final BattleState battle;

  /// Eventos del último paso del motor (se animan una vez por [eventSeq]).
  final List<BattleEvent> events;

  /// Sube con cada paso nuevo (`SessionView.battleEventSeq`).
  final int eventSeq;

  /// Identifica la batalla (`SessionBattle.id`): otra = escena limpia.
  final int battleId;

  /// Le toca al jugador de este dispositivo: se muestra el menú.
  final bool canAct;

  /// Segundos que le quedan al jugador de turno (`TURN_LIMIT − turnT`).
  final double? turnTimeLeft;

  /// Manda un comando del actor de turno. Devuelve si fue aceptado.
  final bool Function(BattleCommand command) onCommand;

  /// Sprites ya cargados; sin ellos se dibujan rectángulos.
  final GameSprites? sprites;

  /// Dónde ocurre la batalla en el mapa; sin arena, fondo liso.
  final BattleArena? arena;

  /// Jugador de este dispositivo (nombre dorado en la escena).
  final String? localId;

  /// Azar de las partículas (los tests lo fijan).
  final math.Random? random;

  @override
  State<BattleView> createState() => BattleViewState();
}

/// Una opción del menú plano numerado (`btn` del prototipo).
class _Option {
  const _Option(this.label, this.onSelect, {this.info});
  final String label;

  /// `null` = deshabilitada.
  final VoidCallback? onSelect;

  /// Ayuda (`descSkill`) al pasar el mouse.
  final List<String>? info;
}

class BattleViewState extends State<BattleView>
    with SingleTickerProviderStateMixin {
  /// Enemigo apuntado (`tgt` del prototipo).
  String? _target;

  /// Submenú de poción abierto (`potMode`).
  BattleItem? _potMode;

  /// Ayuda de la opción bajo el mouse.
  List<String>? _hoverInfo;

  late final BattleSceneController scene =
      BattleSceneController(random: widget.random);
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  /// Margen y alto de los paneles de abajo (px de pantalla).
  static const _margin = 8.0;

  List<Combatant> get _foes =>
      widget.battle.enemies.where((e) => e.alive).toList();

  /// El objetivo actual, o el primer enemigo vivo si cayó.
  String? get target {
    final foes = _foes;
    if (foes.isEmpty) return null;
    if (foes.any((e) => e.id == _target)) return _target;
    return foes.first.id;
  }

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final dt = (elapsed - _last).inMicroseconds / 1000;
      _last = elapsed;
      scene.advance(dt);
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    scene.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(BattleView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.canAct && _potMode != null) _potMode = null;
    if (!widget.canAct) _hoverInfo = null;
  }

  /// `cycleTarget`: el siguiente enemigo vivo.
  void cycleTarget() {
    final foes = _foes;
    if (foes.isEmpty) return;
    final i = foes.indexWhere((e) => e.id == target);
    setState(() => _target = foes[(i + 1) % foes.length].id);
  }

  void _send(BattleCommand cmd) {
    if (widget.onCommand(cmd)) {
      setState(() {
        _potMode = null;
        _hoverInfo = null;
      });
    }
  }

  /// Teclas de batalla: 1-9 eligen la opción N, Q/Tab cambian de
  /// objetivo, Esc sale del submenú. Devuelve si la tecla se usó.
  bool handleKey(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.keyQ || key == LogicalKeyboardKey.tab) {
      cycleTarget();
      return true;
    }
    if (key == LogicalKeyboardKey.escape && _potMode != null) {
      setState(() => _potMode = null);
      return true;
    }
    const digits = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
      LogicalKeyboardKey.digit7,
      LogicalKeyboardKey.digit8,
      LogicalKeyboardKey.digit9,
    ];
    final n = digits.indexOf(key);
    if (n < 0) return false;
    final cur = widget.battle.current;
    if (!widget.canAct || cur == null) return true;
    final opts = _options(cur);
    if (n < opts.length) opts[n].onSelect?.call();
    return true;
  }

  List<_Option> _options(Combatant cur) {
    final b = widget.battle;
    final item = _potMode;
    if (item != null) {
      final pot = item == BattleItem.potion;
      return [
        for (final q in b.party)
          if (pot || q.alive)
            _Option(
              '${q.id == cur.id ? 'Yo (${q.name})' : q.name} '
              '${pot ? '${q.hp}/${q.maxHp} HP' : '${q.mp.floor()}/${q.maxMp} MP'}'
              '${pot && !q.alive ? ' ¡revive!' : ''}',
              () => _send(ItemCommand(item, targetPlayerId: q.id)),
            ),
        _Option('< Volver', () => setState(() => _potMode = null)),
      ];
    }
    final tg = target;
    final ult = kUltimates[cur.weaponType];
    final allies = b.party.where((q) => q.alive && q.id != cur.id);
    return [
      _Option('Atacar', () => _send(AttackCommand(targetId: tg)),
          info: ['Atacar: ATQ ${cur.attack} a 1 enemigo '
              '(crítico ${(cur.critChance * 100).round()}%)']),
      if (ult != null)
        _Option('★ ULTIMATE: ${ult.name} [${cur.ult.floor()}%]',
            cur.ult >= 100 ? () => _send(UltimateCommand(targetId: tg)) : null,
            info: describeSkill(ult, cur, ultimate: true)),
      for (final id in cur.skillIds)
        if (kSkills[id] case final sk?)
          _Option('${sk.name} ${sk.mp}MP',
              cur.mp >= sk.mp ? () => _send(SkillCommand(id, targetId: tg)) : null,
              info: describeSkill(sk, cur)),
      for (final q in allies)
        _Option(
          '★ ${kDuals[dualKey(cur.classId ?? '', q.classId ?? '')]?.name ?? 'Dúo'}'
          ' (+${q.name}) 4MP c/u',
          cur.mp >= 4 && q.mp >= 4 ? () => _send(DualCommand(q.id)) : null,
          info: [
            'Ataque combinado con ${q.name} a TODOS los enemigos. '
                'Ambos gastan 4 MP; ${q.name} pierde su próximo turno.',
            if (kDuals[dualKey(cur.classId ?? '', q.classId ?? '')]
                case final du?)
              statusApplicationText(du.status),
          ],
        ),
      _Option('Poción de vida x${cur.potions} ▸',
          cur.potions > 0 ? () => setState(() => _potMode = BattleItem.potion) : null,
          info: const ['Cura 45% de la vida máx., revive y quita Quemadura y Veneno']),
      _Option('Poción de maná x${cur.ethers} ▸',
          cur.ethers > 0 ? () => setState(() => _potMode = BattleItem.ether) : null,
          info: const ['Restaura 50% del maná máx.']),
      _Option('Defender', () => _send(const DefendCommand()),
          info: const ['½ daño hasta tu próximo turno, que llega antes']),
    ];
  }

  /// Clic en la escena: elige al enemigo vivo bajo el puntero.
  void _tapScene(Offset local) {
    final f = scene.frame;
    if (f == null) return;
    final v = f.geometry.toVirtual(local);
    if (v.dy < SceneGeometry.stripHeight) return;
    final cam = scene.camera ?? Offset.zero;
    final wx = v.dx + cam.dx, wy = v.dy - SceneGeometry.stripHeight + cam.dy;
    for (final e in _foes) {
      final p = f.layout.of(e.id);
      final type = e.enemyType ?? '';
      final img = widget.sprites?.enemy(type);
      final sc = (widget.sprites?.enemyScale(type) ?? 1) * (e.elite ? 1.45 : 1);
      final w = (img?.width ?? 16) * sc, h = (img?.height ?? 14) * sc;
      if ((wx - p.dx).abs() <= w / 2 + 4 && wy >= p.dy - h - 4 && wy <= p.dy + 4) {
        setState(() => _target = e.id);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.battle;
    return ColoredBox(
      color: RetroPalette.night,
      child: LayoutBuilder(builder: (context, cons) {
        final size = cons.biggest;
        final g = SceneGeometry.fit(size);
        final panelH = math.min(260.0, size.height * 0.4);
        final layout =
            BattleLayout.compute(b, widget.arena, vw: g.virtualWidth);
        scene.frame = SceneFrame(
          battle: b,
          geometry: g,
          layout: layout,
          arena: widget.arena,
          sprites: widget.sprites,
          localId: widget.localId,
          targetId: widget.canAct ? target : null,
          turnTimeLeft: widget.turnTimeLeft,
          coverBottom: (panelH + _margin * 2) / g.scale,
        );
        scene.sync(
          battleId: widget.battleId,
          eventSeq: widget.eventSeq,
          events: widget.events,
          state: b,
          layout: layout,
        );
        final s = g.scale;
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) => _tapScene(d.localPosition),
                child: CustomPaint(painter: BattleScenePainter(scene)),
              ),
            ),
            Positioned(
              left: 0,
              top: (38 * s).roundToDouble(),
              width: (g.virtualWidth * s).roundToDouble(),
              height: (16 * s).roundToDouble(),
              child: _LogBand(battle: b, turnTimeLeft: widget.turnTimeLeft,
                  localId: widget.localId),
            ),
            Positioned(
              left: _margin,
              right: _margin,
              bottom: _margin,
              height: panelH,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 2,
                    child: _PartyPanel(battle: b, localId: widget.localId),
                  ),
                  const SizedBox(width: _margin),
                  Expanded(flex: 3, child: _commandPanel()),
                ],
              ),
            ),
            if (b.outcome != null) _EndOverlay(outcome: b.outcome!),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: BattleOverlayPainter(scene)),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _commandPanel() {
    final cur = widget.battle.current;
    if (cur == null || !cur.isPlayer) {
      return const RetroPanel(child: Center(child: Text('...')));
    }
    if (!widget.canAct) {
      return RetroPanel(
        child: Center(
          child: Text(retroText('TURNO DE ${cur.name.toUpperCase()}'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 8, color: RetroPalette.muted)),
        ),
      );
    }
    final options = _options(cur);
    final tg = target == null ? null : widget.battle.byId(target!);
    final small = Theme.of(context).textTheme.bodySmall;
    return RetroPanel(
      selected: true,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            retroText(_potMode == null
                ? '¡TU TURNO! ${cur.name.toUpperCase()}'
                : '¿A QUIÉN?'),
            style: const TextStyle(color: RetroPalette.gold),
          ),
          const SizedBox(height: 4),
          Text(
            retroText(tg == null
                ? 'Q/Tab: objetivo · 1-9: elegir'
                : 'Objetivo: ${tg.elite ? '★' : ''}${tg.name} ${tg.hp}/${tg.maxHp}'
                    ' · Q/Tab cambia · 1-9 elige'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: small?.copyWith(color: RetroPalette.muted),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LayoutBuilder(builder: (context, cons) {
              final colW = cons.maxWidth >= 520
                  ? (cons.maxWidth - 8) / 2
                  : cons.maxWidth;
              return SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (var i = 0; i < options.length; i++)
                      SizedBox(
                        width: colW,
                        child: _MenuOption(
                          '${i + 1}. ${options[i].label}',
                          onTap: options[i].onSelect,
                          onHover: (on) => setState(() =>
                              _hoverInfo = on ? options[i].info : null),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
          if (_hoverInfo case final info?)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                retroText(info.join('\n')),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: small?.copyWith(color: RetroPalette.muted, height: 1.4),
              ),
            ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------
// Piezas
// ----------------------------------------------------------------------

/// Banda del log (`txt(B.log, ...)`) y `drawTurnLabel`.
class _LogBand extends StatelessWidget {
  const _LogBand(
      {required this.battle, required this.turnTimeLeft, required this.localId});

  final BattleState battle;
  final double? turnTimeLeft;
  final String? localId;

  @override
  Widget build(BuildContext context) {
    final cur = battle.current;
    final left = turnTimeLeft;
    final showTimer = left != null && cur != null && cur.isPlayer;
    final who = cur == null
        ? ''
        : cur.id == localId
            ? 'TÚ'
            : (cur.name.length > 6 ? cur.name.substring(0, 6) : cur.name);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              retroText(battle.log),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 8, height: 1.25),
            ),
          ),
          if (showTimer) ...[
            const SizedBox(width: 8),
            Text(
              retroText('$who ${left.ceil().clamp(0, 99)}s'),
              style: TextStyle(
                fontSize: 8,
                color: left <= 10 ? RetroPalette.red : RetroPalette.gold,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Opción de menú estilo JRPG: '>' y dorado al pasar el mouse.
class _MenuOption extends StatefulWidget {
  const _MenuOption(this.label, {this.onTap, this.onHover});

  final String label;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onHover;

  @override
  State<_MenuOption> createState() => _MenuOptionState();
}

class _MenuOptionState extends State<_MenuOption> {
  bool _hover = false;

  void _setHover(bool on) {
    setState(() => _hover = on);
    widget.onHover?.call(on);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final color = !enabled
        ? RetroPalette.muted
        : _hover
            ? RetroPalette.gold
            : RetroPalette.ink;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => _setHover(true),
      onExit: (_) => _setHover(false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Text(
          retroText('${_hover && enabled ? '> ' : '  '}${widget.label}'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: color, fontSize: 8, height: 1.5),
        ),
      ),
    );
  }
}

/// Stacks de estado como letras (Q V C A S R), como el prototipo.
String _statusLine(Combatant c) {
  const letters = {
    StatusKind.burn: 'Q',
    StatusKind.poison: 'V',
    StatusKind.freeze: 'C',
    StatusKind.stun: 'A',
    StatusKind.holy: 'S',
    StatusKind.regen: 'R',
  };
  return [
    for (final k in StatusKind.values)
      if (c.stacks(k) > 0) '${letters[k]}${c.stacks(k)}',
    if (c.defending) 'DEF',
    if (c.protecting) 'PROT',
    if (c.taunt > 0) 'PROV',
  ].join(' ');
}

/// El grupo: vida, maná y ULT de cada jugador (las tarjetas del HTML).
class _PartyPanel extends StatelessWidget {
  const _PartyPanel({required this.battle, required this.localId});

  final BattleState battle;
  final String? localId;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;
    return RetroPanel(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final p in battle.party)
            Opacity(
              opacity: p.alive ? 1 : 0.5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    retroText('${battle.currentId == p.id ? '> ' : '  '}'
                        '${p.alive ? p.name : '${p.name} K.O.'}'
                        '   HP ${p.hp}/${p.maxHp}  MP ${p.mp.floor()}/${p.maxMp}'
                        '  ULT ${p.ult.floor()}%  ${_statusLine(p)}'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: small?.copyWith(
                      color: p.id == localId ? RetroPalette.gold : RetroPalette.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: RetroBar(
                            value: p.hp,
                            max: p.maxHp,
                            color: RetroPalette.green,
                            height: 10),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 2,
                        child: RetroBar(
                            value: p.mp,
                            max: p.maxMp,
                            color: RetroPalette.muted,
                            height: 10),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 2,
                        child: RetroBar(
                            value: p.ult,
                            max: 100,
                            color: RetroPalette.gold,
                            height: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _EndOverlay extends StatelessWidget {
  const _EndOverlay({required this.outcome});

  final BattleOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ColoredBox(
      color: RetroPalette.night.withValues(alpha: 0.35),
      child: Center(
        child: RetroPanel(
          selected: true,
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                outcome.victory ? '¡VICTORIA!' : 'DERROTA',
                style: text.displayLarge?.copyWith(
                  color: outcome.victory ? RetroPalette.gold : RetroPalette.red,
                ),
              ),
              if (outcome.victory) ...[
                const SizedBox(height: 24),
                Text('+${outcome.xp} XP   +${outcome.credits} CREDITOS'),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
