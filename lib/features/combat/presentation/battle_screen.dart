import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../app/theme/retro_panel.dart';
import '../../../app/theme/retro_text.dart';
import '../../../game_engine/data/skills_catalog.dart';
import '../../../game_engine/models/battle_command.dart';
import '../../../game_engine/models/battle_event.dart';
import '../../../game_engine/models/battle_state.dart';
import '../../../game_engine/models/skill.dart';
import '../../../game_engine/models/status.dart';
import '../../../game_engine/rules/js_math.dart';
import '../domain/skill_text.dart';
import '../domain/turn_order.dart';
import 'battle_hud.dart';
import 'game_sprites.dart';
import 'scene/battle_layout.dart';
import 'scene/battle_painter.dart';
import 'scene/battle_scene.dart';

/// Pantalla de batalla pixel art: arriba la escena del prototipo (grupo
/// y enemigos sobre el mapa, efectos, franja de turnos y log) y abajo una
/// barra fija que nunca la tapa: mis datos (solo el jugador local), el
/// menú de comandos (`#menu`) y el resto del grupo en filas compactas,
/// con los textos y colores del prototipo. Escena y efectos en
/// docs/specs/battle_presentation.md; barra, menú y teclas en
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
    this.pendingPoints = const {},
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

  /// Jugador de este dispositivo (nombre dorado en la escena, `.pbox.me`).
  final String? localId;

  /// Azar de las partículas (los tests lo fijan).
  final math.Random? random;

  /// Puntos de atributo sin repartir por jugador (`+N pts` de la caja).
  final Map<String, int> pendingPoints;

  @override
  State<BattleView> createState() => BattleViewState();
}

/// Una opción del menú plano numerado (`btn(lab, act, dis, cls, tip)` del
/// prototipo). [label] y [tip] son markup.
class _Option {
  const _Option(this.label, this.onSelect, {this.tip, this.dual = false});
  final String label;

  /// `null` = deshabilitada.
  final VoidCallback? onSelect;

  /// `data-tip`: el `#tip` al pasar el mouse.
  final String? tip;

  /// `button.dual`: borde `#ff9f1c`, texto `#ffd166` (ULT y dúos).
  final bool dual;
}

class BattleViewState extends State<BattleView>
    with SingleTickerProviderStateMixin {
  /// Enemigo apuntado (`tgt` del prototipo).
  String? _target;

  /// Submenú de poción abierto (`potMode`).
  BattleItem? _potMode;

  late final BattleSceneController scene =
      BattleSceneController(random: widget.random);
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  /// Margen y separación de la barra de abajo (px de pantalla).
  static const _margin = 6.0;

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
  }

  /// `cycleTarget`: el siguiente enemigo vivo.
  void cycleTarget() {
    final foes = _foes;
    if (foes.isEmpty) return;
    final i = foes.indexWhere((e) => e.id == target);
    setState(() => _target = foes[(i + 1) % foes.length].id);
  }

  void _send(BattleCommand cmd) {
    if (widget.onCommand(cmd)) setState(() => _potMode = null);
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

  // ---------------- menú (`hud()`, líneas 1205-1223) ----------------

  /// `Quiebre n/m` del enemigo [e] (docs/specs/break_and_enemy_ults.md
  /// § 1), con `¡VULNERABLE!` si está quebrado y `¡ULT!` si la avisó.
  static String breakInfoMarkup(Combatant e) {
    if (!e.hasBreak && !e.ultPending) return '';
    final parts = <String>[
      if (e.hasBreak)
        e.broken
            ? hexSpan('#ffe14d', '¡VULNERABLE! ×1.5')
            : hexSpan('#ffe14d',
                'Quiebre ${e.breakGauge.floor()}/${e.breakMax.round()}'),
      if (e.ultPending) hexSpan('#ff3355', '¡ULT!'),
    ];
    return ' · ${parts.join(' ')}';
  }

  /// `est(v, all)`: daño estimado en dorado y el crítico en `#7d8bc4`.
  static String _est(Combatant p, num v, {bool all = false}) =>
      ' <span style="color:#ffd166">${jsRound(v)}${all ? ' c/u' : ''}</span>'
      '<span style="color:#7d8bc4"> (crít ${jsRound(v * p.critMultiplier)})</span>';

  /// `+N` / `P%` y la letra del estado en su color.
  static String _stTag(StatusApplication st) => hexSpan(
      statusHex(st.kind),
      '${st.chance != null ? '${jsRound(st.chance! * 100)}% ' : '+${st.stacks}'}'
      '${statusLetterOf(st.kind)}');

  /// Lo que se agrega al nombre de una técnica (`info`, línea 1217).
  static String _skillInfo(SkillDef tk, Combatant p) {
    switch (tk.kind) {
      case SkillKind.heal:
        return ' ${hexSpan('#7bed9f', '+${jsRound(p.magic * tk.power + 6)} c/u')}';
      case SkillKind.haste:
        return ' ${hexSpan('#ffd166', 'adelanta aliados')}';
      case SkillKind.taunt:
        return ' ${hexSpan('#ff7675', 'te atacan a ti ×${tk.amount}')}';
      case SkillKind.guard:
        return ' ${hexSpan('#74b9ff', 'equipo recibe ½')}';
      case SkillKind.regen:
        return ' ${hexSpan('#7bed9f', '+${jsRound(p.magic * tk.power + 4)} c/u + regen 5%×3')}';
      case SkillKind.defenseUp:
        return ' ${hexSpan('#74b9ff', 'DEF +${tk.amount} (ahora ${p.defense})')}';
      case SkillKind.protect:
        return ' ${hexSpan('#ffeaa7', 'absorbe el daño de aliados')}';
      case SkillKind.bulwark:
        return ' ${hexSpan('#74b9ff', 'cura 30%, defensa y protección')}';
      case SkillKind.physical || SkillKind.magical:
        final st = tk.status;
        return _est(p,
                (tk.kind == SkillKind.magical ? p.magic : p.attack) * tk.power,
                all: tk.allTargets) +
            (st != null ? ' ${_stTag(st)}' : '') +
            (tk.critBonus > 0
                ? hexSpan('#ff6b81', ' +${jsRound(tk.critBonus * 100)}% crít')
                : '');
    }
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
              '${q.id == cur.id ? 'Yo (${protoEsc(q.name)})' : protoEsc(q.name)} '
              '<span style="color:#9fb4ff">'
              '${pot ? '${q.hp}/${q.maxHp} HP' : '${q.mp.floor()}/${q.maxMp} MP'}'
              '</span> '
              '${hexSpan(pot ? '#7bed9f' : '#74b9ff', '+${pot ? jsRound(q.maxHp * 0.45) : jsRound(q.maxMp * 0.5)}${!q.alive ? ' ¡revive!' : ''}')}',
              () => _send(ItemCommand(item, targetPlayerId: q.id)),
            ),
        _Option('← Volver', () => setState(() => _potMode = null)),
      ];
    }
    final tg = target;
    final ult = kAllUltimates[cur.weaponType];
    final allies = b.party.where((q) => q.alive && q.id != cur.id);
    return [
      _Option(
        'Atacar${_est(cur, cur.attack)}'
        '${cur.stunOnAttackChance > 0 ? ' ${hexSpan('#ffeaa7', '${jsRound(cur.stunOnAttackChance * 100)}%A')}' : ''}'
        '${cur.branch == 'creyente' ? ' ${hexSpan('#7bed9f', '25% cura 2%')}' : cur.branch == 'inherente' ? ' ${hexSpan('#fff3b0', '25% S')}' : ''}',
        () => _send(AttackCommand(targetId: tg)),
      ),
      if (ult != null)
        _Option(
          '★ ULTIMATE: ${ult.name} ${hexSpan('#ffd166', '[${cur.ult.floor()}%]')}'
          '${ult.dealsDamage ? _est(cur, (ult.kind == SkillKind.magical ? cur.magic : cur.attack) * ult.power, all: ult.allTargets) : ' ${hexSpan('#74b9ff', 'cura 30%, defensa y protección')}'}',
          cur.ult >= 100 ? () => _send(UltimateCommand(targetId: tg)) : null,
          tip: describeSkillMarkup(ult, cur, ultimate: true),
          dual: true,
        ),
      for (final id in cur.skillIds)
        if (kSkills[id] case final sk?)
          _Option(
            '${sk.name}${sk.delay > 0 ? ' ⏳' : ''}${_skillInfo(sk, cur)} '
            '${hexSpan('#74b9ff', '${sk.mp}MP')}',
            cur.mp >= sk.mp
                ? () => _send(SkillCommand(id, targetId: tg))
                : null,
            tip: describeSkillMarkup(sk, cur),
          ),
      for (final q in allies)
        if (kDuals[dualKey(cur.classId ?? '', q.classId ?? '')] case final du?)
          _Option(
            '★ ${du.name} (+${protoEsc(q.name)})'
            '${_est(cur, (math.max(cur.attack, cur.magic) + math.max(q.attack, q.magic)) * du.power, all: true)}'
            ' ${_stTag(du.status)} ${hexSpan('#74b9ff', '4MP c/u')}',
            cur.mp >= 4 && q.mp >= 4 ? () => _send(DualCommand(q.id)) : null,
            // Lo que no entra en la fila de la barra va al `#tip`.
            tip: '<b>★ ${du.name}</b> <span class="k">dúo con '
                '${protoEsc(q.name)}</span><br>'
                '(máx(ATQ, MAG) tuyo + suyo) × ${fm(du.power)} = <b>'
                '${jsRound((math.max(cur.attack, cur.magic) + math.max(q.attack, q.magic)) * du.power)}</b>'
                ' a TODOS los enemigos<br>'
                '${statusApplicationMarkup(du.status)}<br>'
                '4 MP cada uno · ${protoEsc(q.name)} pierde su próximo turno',
            dual: true,
          ),
      _Option(
        'Poción de vida x${cur.potions} ▸ ${hexSpan('#7bed9f', 'elegir a quién')}',
        cur.potions > 0
            ? () => setState(() => _potMode = BattleItem.potion)
            : null,
        tip: 'Cura 45% de la vida máx. del aliado que elijas (o a ti). '
            'Revive a un aliado caído y quita quemadura y veneno.',
      ),
      _Option(
        'Poción de maná x${cur.ethers} ▸ ${hexSpan('#74b9ff', 'elegir a quién')}',
        cur.ethers > 0
            ? () => setState(() => _potMode = BattleItem.ether)
            : null,
        tip: 'Restaura 50% del maná máx. del aliado que elijas (o a ti).',
      ),
      _Option(
        'Defender (½ daño, vuelves antes)',
        () => _send(const DefendCommand()),
        tip: 'Recibes la mitad del daño hasta tu próximo turno, y tu '
            'siguiente turno llega 30% antes.',
      ),
    ];
  }

  /// Clic en la escena: elige al enemigo vivo bajo el puntero.
  void _tapScene(Offset local) {
    final f = scene.frame;
    if (f == null) return;
    final vp = SceneViewport(f.geometry.worldRect, scene.viewFor(f));
    if (!vp.area.contains(local)) return;
    final w = vp.toWorld(local);
    final wx = w.dx, wy = w.dy;
    for (final e in _foes) {
      final p = f.layout.of(e.id);
      final type = e.enemyType ?? '';
      final img = widget.sprites?.enemy(type);
      final sc = (widget.sprites?.enemyScale(type) ?? 1) * (e.elite ? 1.45 : 1);
      final w = (img?.width ?? 16) * sc, h = (img?.height ?? 14) * sc;
      if ((wx - p.dx).abs() <= w / 2 + 4 &&
          wy >= p.dy - h - 4 &&
          wy <= p.dy + 4) {
        setState(() => _target = e.id);
        return;
      }
    }
  }

  /// El jugador de este dispositivo: [BattleView.localId]; sin él
  /// (tests, previsualización), el de turno si puede actuar o el primero.
  Combatant? get _me {
    final party = widget.battle.party;
    for (final p in party) {
      if (p.id == widget.localId) return p;
    }
    final cur = widget.battle.current;
    if (widget.localId == null &&
        widget.canAct &&
        cur != null &&
        cur.isPlayer) {
      return cur;
    }
    return party.isEmpty ? null : party.first;
  }

  /// Alto de la barra de batalla para una pantalla de alto [h].
  static double barHeight(double h) => (h * 0.42).clamp(200.0, 300.0);

  @override
  Widget build(BuildContext context) {
    final b = widget.battle;
    return ColoredBox(
      color: ProtoColors.bg,
      child: LayoutBuilder(builder: (context, cons) {
        final size = cons.biggest;
        final barH = math.min(barHeight(size.height), size.height * 0.6);
        final me = _me;
        return Stack(
          children: [
            Column(
              children: [
                // La escena usa solo el alto que deja la barra: nunca
                // queda tapada.
                Expanded(child: _scene(b)),
                SizedBox(
                  height: barH,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        _margin, _margin, _margin, _margin),
                    child: _bar(b, me, size.width),
                  ),
                ),
              ],
            ),
            // La parte de pantalla de la ULT, encima también de la barra.
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: BattleOverlayPainter(scene)),
              ),
            ),
            // El cartel final espera a que termine la cinemática.
            if (b.outcome != null)
              ListenableBuilder(
                listenable: scene,
                builder: (context, _) => scene.ult != null || scene.holding
                    ? const SizedBox.shrink()
                    : _EndOverlay(outcome: b.outcome!),
              ),
          ],
        );
      }),
    );
  }

  Widget _scene(BattleState b) {
    return LayoutBuilder(builder: (context, cons) {
      final g = SceneGeometry.fit(cons.biggest);
      final sprites = widget.sprites;
      final layout = BattleLayout.compute(b, widget.arena,
          vw: g.virtualWidth,
          enemySize: (e) {
            final type = e.enemyType ?? '';
            final img = sprites?.enemy(type);
            final sc = (sprites?.enemyScale(type) ?? 1) * (e.elite ? 1.45 : 1);
            return Size((img?.width ?? 16) * sc, (img?.height ?? 14) * sc);
          });
      scene.frame = SceneFrame(
        battle: b,
        geometry: g,
        layout: layout,
        arena: widget.arena,
        sprites: widget.sprites,
        localId: widget.localId,
        targetId: widget.canAct ? target : null,
        turnTimeLeft: widget.turnTimeLeft,
      );
      scene.sync(
        battleId: widget.battleId,
        eventSeq: widget.eventSeq,
        events: widget.events,
        state: b,
        layout: layout,
      );
      final s = g.scale;
      return ClipRect(
        child: Stack(
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
              child: _LogBand(
                battle: b,
                turnTimeLeft: widget.turnTimeLeft,
                localId: widget.localId,
                scale: s,
              ),
            ),
          ],
        ),
      );
    });
  }

  /// La barra de abajo: mis datos · acciones · resto del grupo.
  Widget _bar(BattleState b, Combatant? me, double width) {
    final leftW = (width * 0.21).clamp(250.0, 360.0);
    final rightW = (width * 0.25).clamp(270.0, 400.0);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: leftW,
          child: me == null
              ? const BattleBarPanel(child: SizedBox.shrink())
              : MyBattlePanel(
                  battle: b,
                  player: me,
                  turnTimeLeft: widget.turnTimeLeft,
                  points: widget.pendingPoints[me.id] ?? 0,
                ),
        ),
        const SizedBox(width: _margin),
        Expanded(child: _actions(b, me)),
        const SizedBox(width: _margin),
        SizedBox(
          width: rightW,
          child: PartyListPanel(
            battle: b,
            localId: me?.id,
            sprites: widget.sprites,
          ),
        ),
      ],
    );
  }

  /// Panel del medio: el menú en mi turno; si no, de quién es el turno.
  Widget _actions(BattleState b, Combatant? me) {
    final menu = _menu();
    if (menu != null) return menu;
    final cur = b.current;
    final String who;
    if (cur == null) {
      who = hexSpan('#7d8bc4', '…');
    } else if (cur.id == me?.id) {
      who = '<b>Tu turno</b>';
    } else if (cur.isPlayer) {
      who = '<b>Turno de ${protoEsc(cur.name)}</b>';
    } else {
      who = '<b style="color:#ff6b81">Turno de ${protoEsc(cur.name)}</b>';
    }
    var mine = '';
    if (me != null && cur?.id != me.id) {
      final i = predictTurns(b, 10).indexOf(me.id);
      if (!me.alive) {
        mine = hexSpan('#7d8bc4', 'Estás fuera de combate');
      } else if (i >= 0) {
        mine = hexSpan('#7d8bc4', 'Tu turno en $i');
      }
    }
    return BattleBarPanel(
      key: const ValueKey('battle-waiting'),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ProtoText(who,
                style: const TextStyle(fontSize: 16, height: 1.5),
                textAlign: TextAlign.center),
            if (mine.isNotEmpty) ...[
              const SizedBox(height: 8),
              ProtoText(mine, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }

  /// `#menu`: solo en el turno del jugador local (el prototipo lo oculta
  /// en cualquier otro momento). Cabecera `<b>` dorada con el objetivo y
  /// botones numerados en 2 columnas (3 si hay lugar).
  Widget? _menu() {
    final cur = widget.battle.current;
    if (!widget.canAct || cur == null || !cur.isPlayer) return null;
    final options = _options(cur);
    final String header;
    if (_potMode == null) {
      final tg = _foes.where((e) => e.id == target).firstOrNull;
      header = '<b>¡Tu turno! (${protoEsc(cur.name)})'
          '${tg == null ? '' : ' · Objetivo: ${protoEsc(tg.name)}'}</b>'
          '${tg == null ? '' : breakInfoMarkup(tg)}'
          ' <span class="k">Q/Tab cambia</span>';
    } else if (_potMode == BattleItem.potion) {
      header = '<b>¿A quién le das la Poción de vida (+45% vida, revive, '
          'quita ${statusNameMarkup(StatusKind.burn)} y '
          '${statusNameMarkup(StatusKind.poison)})?</b>';
    } else {
      header = '<b>¿A quién le das la Poción de maná (+50% maná)?</b>';
    }
    return BattleBarPanel(
      key: const ValueKey('battle-menu'),
      highlight: true,
      child: LayoutBuilder(builder: (context, box) {
        const gap = 4.0;
        final cols = box.maxWidth >= 840 ? 3 : 2;
        // Grilla pareja (también ULT y dúos, con su borde `.dual`): en la
        // barra no hay lugar para filas enteras. Cada fila toma el alto de
        // su botón más alto.
        final rows = <Widget>[];
        for (var r = 0; r < options.length; r += cols) {
          rows.add(Padding(
            padding: EdgeInsets.only(top: r == 0 ? 0 : gap),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var c = 0; c < cols; c++) ...[
                    if (c > 0) const SizedBox(width: gap),
                    Expanded(
                      child: r + c < options.length
                          ? _MenuButton(
                              '${r + c + 1}. ${options[r + c].label}',
                              onTap: options[r + c].onSelect,
                              tip: options[r + c].tip,
                              dual: options[r + c].dual,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          ));
        }
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ProtoText(header,
                  style: const TextStyle(fontSize: 8, height: 1.5),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              ...rows,
            ],
          ),
        );
      }),
    );
  }
}

// ----------------------------------------------------------------------
// Piezas
// ----------------------------------------------------------------------

/// Banda del log (`txt(B.log, ...)` en blanco) y `drawTurnLabel` (caja
/// negra a la derecha con `TÚ 25s`, dorado o `#ff6b81` con ≤ 10 s).
class _LogBand extends StatelessWidget {
  const _LogBand({
    required this.battle,
    required this.turnTimeLeft,
    required this.localId,
    required this.scale,
  });

  final BattleState battle;
  final double? turnTimeLeft;
  final String? localId;
  final double scale;

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
    return LayoutBuilder(builder: (context, box) {
      final log = retroText(battle.log);
      final labelW = showTimer ? 84 * scale : 0.0;
      // 6 px virtuales del prototipo (5 si el log es largo), redondeado a
      // la grilla de la fuente: 16 si entra en una línea, si no 8.
      final big = 6 * scale >= 12 &&
          log.length <= 52 &&
          log.length * 16 <= box.maxWidth - labelW - 16;
      return Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Text(
                  log,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: big ? 16 : 8,
                      height: 1.25,
                      color: ProtoColors.white),
                ),
              ),
            ),
          ),
          if (showTimer)
            Container(
              width: 82 * scale,
              margin: EdgeInsets.only(
                  right: 2 * scale, top: scale, bottom: 2 * scale),
              color: const Color(0xFF000000),
              alignment: Alignment.center,
              child: Text(
                retroText('$who ${left.ceil().clamp(0, 99)}s'),
                style: TextStyle(
                  fontSize: 8,
                  color: left <= 10 ? ProtoColors.red : ProtoColors.gold,
                ),
              ),
            ),
        ],
      );
    });
  }
}

/// `#menu button`: fondo `#22305a`, borde 2 px `#5b74c9` (hover `#2e4280`
/// / `#9fb4ff`), texto blanco alineado a la izquierda, 35% de opacidad
/// deshabilitado; `.dual` con borde `#ff9f1c` y texto `#ffd166`. El
/// [tip] se muestra en el `#tip` al pasar el mouse.
class _MenuButton extends StatefulWidget {
  const _MenuButton(this.label, {this.onTap, this.tip, this.dual = false});

  final String label;
  final VoidCallback? onTap;
  final String? tip;
  final bool dual;

  @override
  State<_MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<_MenuButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final hot = enabled && _hover;
    final border = widget.dual
        ? ProtoColors.amber
        : hot
            ? ProtoColors.buttonHoverBorder
            : ProtoColors.buttonBorder;
    Widget button = MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Opacity(
          opacity: enabled ? 1 : 0.35,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: hot ? ProtoColors.buttonHover : ProtoColors.button,
              border: Border.all(color: border, width: 2),
            ),
            child: ProtoText(
              widget.label,
              style: TextStyle(
                  fontSize: 8,
                  height: 1.5,
                  color: widget.dual ? ProtoColors.gold : ProtoColors.white),
            ),
          ),
        ),
      ),
    );
    if (widget.tip case final tip?) {
      button = RetroTooltip(message: tip, child: button);
    }
    return button;
  }
}

class _EndOverlay extends StatelessWidget {
  const _EndOverlay({required this.outcome});

  final BattleOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ColoredBox(
      color: ProtoColors.bg.withValues(alpha: 0.35),
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
                  color: outcome.victory ? ProtoColors.gold : ProtoColors.red,
                  shadows: const [
                    Shadow(
                        color: ProtoColors.titleShadow, offset: Offset(3, 3)),
                  ],
                ),
              ),
              if (outcome.victory) ...[
                const SizedBox(height: 24),
                Text(
                    retroText(
                        '+${outcome.xp} XP · +₵${outcome.credits} para cada uno'),
                    style: const TextStyle(color: ProtoColors.gold)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
