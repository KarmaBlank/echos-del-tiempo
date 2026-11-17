import 'package:material_ui/material_ui.dart';

import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/party_box.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../app/theme/retro_text.dart';
import '../../../game_engine/data/classes_catalog.dart';
import '../../../game_engine/data/enemies_catalog.dart';
import '../../../game_engine/models/enemy_def.dart';
import '../../../game_engine/data/passive_mechanics.dart';
import '../../../game_engine/models/battle_state.dart';
import '../../../game_engine/models/passive_mechanic.dart';
import '../../../game_engine/models/status.dart';
import '../../../game_engine/rules/battle_engine.dart';
import '../../../game_engine/rules/js_math.dart';
import '../domain/skill_text.dart';
import '../domain/turn_order.dart';
import 'game_sprites.dart';
import 'pixel_sprite.dart';

/// Piezas de la barra de batalla (docs/specs/exploration.md § "Batalla"):
/// el panel "Mis datos" del jugador local, la lista compacta del resto
/// del grupo y los chips de estados y buffs/debuffs.

/// Fondo y borde de un panel de la barra (`.pbox` / `.panel`).
class BattleBarPanel extends StatelessWidget {
  const BattleBarPanel({
    super.key,
    required this.child,
    this.highlight = false,
    this.padding = const EdgeInsets.all(6),
  });

  final Widget child;

  /// Borde dorado (`.me` / el menú de mi turno).
  final bool highlight;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: ProtoColors.panel,
        border: Border.all(
          color: highlight ? ProtoColors.gold : ProtoColors.panelBorder,
          width: 2,
        ),
      ),
      child: DefaultTextStyle.merge(
        style:
            const TextStyle(fontSize: 8, height: 1.6, color: ProtoColors.ink),
        child: child,
      ),
    );
  }
}

/// Un chip de estado o buff/debuff: [short] para la lista del grupo,
/// [long] para mis datos; [tip] en markup.
class StatusChip {
  const StatusChip(this.short, this.long, this.color, this.tip);

  final String short;
  final String long;
  final Color color;
  final String tip;
}

Color _hex(String hex) =>
    Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));

/// Estados (con stacks) y buffs/debuffs que se derivan del [Combatant]:
/// K.O., `defending`, `protecting`, `taunt`, `bonusDefense` (Fortaleza /
/// Baluarte), la lentitud de Congelación y los efectos del árbol v2
/// (buffs con duración, marcas, escudos, Último Aliento activo).
List<StatusChip> combatantChips(Combatant p) {
  final chips = <StatusChip>[];
  if (!p.alive) {
    chips.add(const StatusChip(
        'K.O.',
        'K.O.',
        ProtoColors.crimson,
        '<b style="color:#ff4757">Fuera de combate</b><br>No actúa hasta que '
            'un aliado lo reviva con una Poción de vida.'));
  }
  for (final k in StatusKind.values) {
    final n = p.stacks(k);
    if (n <= 0) continue;
    final hex = statusHex(k);
    chips.add(StatusChip(
      '${statusLetterOf(k)}$n',
      '${k.label} $n',
      _hex(hex),
      '<b style="color:$hex">${k.label}</b> '
          '<span class="k">×$n${k == StatusKind.holy && p.holyTurns > 0 ? ' · ${p.holyTurns} turnos' : ''}</span>'
          '<br>${statusDescriptionOf(k)}',
    ));
  }
  if (p.defending) {
    chips.add(const StatusChip(
        'Defiende',
        'Defiende ½',
        ProtoColors.ice,
        '<b style="color:#74b9ff">Defendiendo</b><br>Recibe la mitad del daño '
            'hasta su próximo turno.'));
  }
  if (p.protecting) {
    chips.add(const StatusChip(
        'Protege',
        'Protege',
        ProtoColors.cream,
        '<b style="color:#ffeaa7">Protección</b><br>Hasta su próximo turno, '
            'TODO el daño dirigido a sus aliados lo recibe él.'));
  }
  if (p.taunt > 0) {
    chips.add(StatusChip(
        'Provoca ${p.taunt}',
        'Provoca ${p.taunt}',
        ProtoColors.taunt,
        '<b style="color:#ff7675">Provoca</b><br>Los próximos ${p.taunt} '
            'ataques enemigos van contra él.'));
  }
  if (p.bonusDefense > 0) {
    chips.add(StatusChip(
        '▲DEF+${p.bonusDefense}',
        '▲DEF +${p.bonusDefense}',
        ProtoColors.ice,
        '<b style="color:#74b9ff">▲ Defensa +${p.bonusDefense}</b> '
            '<span class="k">(Fortaleza / Baluarte)</span><br>'
            '+${p.bonusDefense} DEF durante el combate (cada punto = −3% de '
            'daño recibido, máx −60%). DEF total ${p.defense}.'));
  }
  final ice = p.stacks(StatusKind.freeze);
  if (ice > 0) {
    final pct = jsRound(BattleEngine.freezeSlowPerStack * ice * 100);
    chips.add(StatusChip(
        '▼VEL',
        '▼VEL −$pct%',
        ProtoColors.ice,
        '<b style="color:#74b9ff">▼ Velocidad −$pct%</b> '
            '<span class="k">(Congelación ×$ice)</span><br>'
            '−12% velocidad por stack: su turno llega más tarde.'));
  }
  if (p.webbed && p.alive) {
    chips.add(const StatusChip(
        'Telaraña',
        'Atrapado (telaraña)',
        Color(0xFFEDEFF5),
        '<b style="color:#edeff5">Atrapado en la telaraña</b>'
        '<br>Pierde su próximo turno salvo que un aliado lo '
        'libere usando <b>Atacar</b> sobre él (opción "Liberar" del menú). '
        '<span class="k">Solo: forcejea y pierde medio turno.</span>'));
  }
  chips.addAll(treeEffectChips(p));
  return chips;
}

/// Chips de las mecánicas de los jefes vivos (docs/specs/bosses.md
/// § "v0.2"): qué hacen ahora y cómo contrarrestarlas.
List<StatusChip> bossMechanicChips(BattleState b) {
  final chips = <StatusChip>[];
  for (final e in b.enemies) {
    if (!e.alive) continue;
    final m = bossMechanicOf(kEnemies[e.enemyType]);
    if (m == null) continue;
    switch (m.kind) {
      case BossMechanicKind.web:
        final n = b.party.where((p) => p.alive && p.webbed).length;
        chips.add(StatusChip(
            '${m.name}${n > 0 ? ' ×$n' : ''}',
            '${m.name}${n > 0 ? ' · $n atrapado${n == 1 ? '' : 's'}' : ''}',
            const Color(0xFFEDEFF5),
            '<b style="color:#edeff5">${m.name}</b> '
            '<span class="k">(${protoEsc(e.name)})</span><br>${m.counter}'));
      case BossMechanicKind.frost:
        final n = b.enemies.where((c) => c.alive && c.enemyType == m.addType).length;
        var slow = 0.0;
        for (final p in b.party) {
          final fx = p.effectFrom(m.id, BuffStat.speed);
          if (fx != null && -fx.value > slow) slow = -fx.value;
        }
        chips.add(StatusChip(
            'Cristales $n${slow > 0 ? ' −${jsRound(slow * 100)}%' : ''}',
            '${m.name}: $n cristal${n == 1 ? '' : 'es'}'
                '${slow > 0 ? ' · VEL −${jsRound(slow * 100)}%' : ''}',
            const Color(0xFF9FE3F0),
            '<b style="color:#9fe3f0">${m.name}</b> '
            '<span class="k">($n cristal${n == 1 ? '' : 'es'} vivo${n == 1 ? '' : 's'})</span>'
            '<br>${m.counter}'));
      case BossMechanicKind.stance:
        final shield = e.stance == 1;
        final pct = jsRound(m.value * 100);
        final hex = e.broken ? '#7f8c8d' : shield ? '#74b9ff' : '#ff6b6b';
        final when = e.broken
            ? 'rota (quebrado)'
            : e.stanceTurns <= 1
                ? 'cambia en su próximo turno'
                : 'cambia en ${e.stanceTurns} turnos';
        chips.add(StatusChip(
            shield ? 'ESCUDO' : 'ESPADA',
            'Postura ${shield ? 'ESCUDO −$pct% físico' : 'ESPADA −$pct% mágico'} · $when',
            e.broken
                ? const Color(0xFF7F8C8D)
                : shield
                    ? ProtoColors.ice
                    : const Color(0xFFFF6B6B),
            '<b style="color:$hex">Postura de ${shield ? 'escudo' : 'espada'}</b> '
            '<span class="k">($when)</span><br>${m.counter}'));
    }
  }
  return chips;
}

/// La fila de chips de las mecánicas de jefe (vacía si no hay).
Widget bossMechanicRow(BattleState b) {
  final chips = bossMechanicChips(b);
  if (chips.isEmpty) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Wrap(
      spacing: 3,
      runSpacing: 3,
      children: [for (final c in chips) StatusChipView(c, long: true)],
    ),
  );
}

/// Chips de los efectos del árbol de pasivas v2 (passive_tree_v2.md § 7):
/// cada uno dice su origen y los turnos que le quedan.
List<StatusChip> treeEffectChips(Combatant p) {
  final chips = <StatusChip>[];
  String src(TimedEffect e) =>
      kMechanics[e.sourceId]?.name ??
      kBossMechanics[e.sourceId]?.name ??
      e.sourceId;
  String turns(TimedEffect e) => '${e.turns} turno${e.turns == 1 ? '' : 's'}';
  for (final e in p.effects) {
    final pct = jsRound(e.value.abs() * 100);
    final from = src(e);
    switch (e.stat) {
      case BuffStat.speed when e.value < 0:
        chips.add(StatusChip(
            '▼VEL',
            '▼VEL −$pct%',
            ProtoColors.ice,
            '<b style="color:#74b9ff">▼ Velocidad −$pct%</b> '
                '<span class="k">($from)</span><br>'
                'Su turno llega más tarde. Rompé los cristales de hielo para '
                'quitarlo.'));
      case BuffStat.speed:
        chips.add(StatusChip(
            '▲VEL',
            '▲VEL +$pct%',
            ProtoColors.green,
            '<b style="color:#7bed9f">▲ Velocidad +$pct%</b> '
                '<span class="k">($from · ${turns(e)})</span><br>'
                'Su próximo turno llega antes.'));
      case BuffStat.attack:
        final up = e.value >= 0;
        chips.add(StatusChip(
            up ? '▲ATQ' : '▼ATQ',
            '${up ? '▲' : '▼'}ATQ ${up ? '+' : '−'}$pct%',
            up ? ProtoColors.orange : ProtoColors.ice,
            '<b style="color:${up ? '#ff9f43' : '#74b9ff'}">'
                '${up ? '▲' : '▼'} Ataque ${up ? '+' : '−'}$pct%</b> '
                '<span class="k">($from · ${turns(e)})</span><br>'
                '${up ? 'Pega más fuerte.' : 'Pega más débil.'}'));
      case BuffStat.damageTaken:
        chips.add(StatusChip(
            'Marca',
            'Marca +$pct%',
            ProtoColors.red,
            '<b style="color:#ff6b81">Marcado</b> '
                '<span class="k">($from · ${turns(e)})</span><br>'
                'Recibe +$pct% de daño de todos.'));
      case BuffStat.shield:
        final n = e.value.round();
        chips.add(StatusChip(
            'Escudo $n',
            'Escudo $n',
            ProtoColors.cream,
            '<b style="color:#ffeaa7">Escudo $n</b> '
                '<span class="k">($from · ${turns(e)})</span><br>'
                'Absorbe $n de daño de golpes enemigos antes que la vida.'));
      case BuffStat.stunLock:
        chips.add(StatusChip(
            'Aturd+1',
            'Aturdido +1',
            ProtoColors.cream,
            '<b style="color:#ffeaa7">Aturdimiento extendido</b> '
                '<span class="k">($from)</span><br>'
                'Su aturdimiento dura 1 turno más.'));
      case BuffStat.crit:
      case BuffStat.damage:
        break;
    }
  }
  // Último Aliento activo (condición, no tiene duración).
  for (final id in p.mechanics) {
    final m = kMechanics[id];
    if (m == null ||
        m.trigger != ProcTrigger.whileLowHealth ||
        !p.alive ||
        p.hp >= p.maxHp * m.threshold) {
      continue;
    }
    chips.add(StatusChip(
        m.name,
        m.name,
        ProtoColors.crimson,
        '<b style="color:#ff4757">${m.name}</b> '
        '<span class="k">(vida &lt; ${jsRound(m.threshold * 100)}%)</span>'
        '<br>${m.description}'));
  }
  return chips;
}

/// Caja de un chip: borde 1 px y texto del color, fondo oscuro, con su
/// `#tip` al pasar el mouse.
class StatusChipView extends StatelessWidget {
  const StatusChipView(this.chip, {super.key, this.long = false});

  final StatusChip chip;
  final bool long;

  @override
  Widget build(BuildContext context) {
    return RetroTooltip(
      message: chip.tip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        decoration: BoxDecoration(
          color: ProtoColors.bg,
          border: Border.all(color: chip.color),
        ),
        child: Text(
          retroText(long ? chip.long : chip.short),
          style: TextStyle(fontSize: 8, height: 1.25, color: chip.color),
        ),
      ),
    );
  }
}

Widget _chips(List<StatusChip> chips, {bool long = false}) => Wrap(
      spacing: 3,
      runSpacing: 3,
      children: [for (final c in chips) StatusChipView(c, long: long)],
    );

/// Barra con `n/m` a la derecha (y una etiqueta opcional a la izquierda).
Widget _barRow(Widget bar, String value,
        {String? label, Color color = ProtoColors.ink, double valueWidth = 64}) =>
    Row(
      children: [
        if (label != null)
          SizedBox(
              width: 30,
              child: Text(label, style: TextStyle(color: color))),
        Expanded(child: bar),
        SizedBox(
          width: valueWidth,
          child: Text(value,
              textAlign: TextAlign.right, style: TextStyle(color: color)),
        ),
      ],
    );

String _classLine(Combatant p) {
  final cls = kClasses[p.classId]?.name ?? p.classId ?? '';
  final lvl = p.build?.level;
  return '$cls${lvl == null ? '' : ' Lv$lvl'}';
}

/// Panel izquierdo: los datos completos del jugador local.
class MyBattlePanel extends StatelessWidget {
  const MyBattlePanel({
    super.key,
    required this.battle,
    required this.player,
    this.turnTimeLeft,
    this.points = 0,
  });

  final BattleState battle;
  final Combatant player;
  final double? turnTimeLeft;
  final int points;

  @override
  Widget build(BuildContext context) {
    final p = player;
    final build = p.build;
    final up = build?.weaponUpgrades.total ?? 0;
    final weapon = build == null
        ? ''
        : '${build.equippedWeapon.name}${up > 0 ? ' +$up' : ''}';
    final ult = p.ult;
    final ultColor = ult >= 100 ? ProtoColors.pink : ProtoColors.violet;
    final speed = 100 / turnInterval(p);
    final chips = combatantChips(p);
    final String turn;
    if (battle.currentId == p.id) {
      final left = turnTimeLeft;
      turn = '<b>▶ TU TURNO</b>'
          '${left == null ? '' : '  ${hexSpan(left <= 10 ? '#ff4757' : '#ffd166', '${left.ceil().clamp(0, 99)}s')}'}';
    } else if (!p.alive) {
      turn = hexSpan('#7d8bc4', 'Fuera de combate');
    } else {
      final i = predictTurns(battle, 10).indexOf(p.id);
      turn = hexSpan('#7d8bc4', i < 0 ? 'Turno: —' : 'Turno en $i');
    }
    return BattleBarPanel(
      key: ValueKey('my-panel-${p.id}'),
      highlight: true,
      child: Opacity(
        opacity: p.alive ? 1 : 0.5,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              ProtoText(
                '<b>${protoEsc(p.name)}</b> '
                '<span class="k">${_classLine(p)}</span>',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (weapon.isNotEmpty)
                ProtoText(
                  hexSpan(
                      '#ff9f43',
                      '⚔ ${protoEsc(weapon)}'
                          '${points > 0 ? ' ${hexSpan('#ffd166', '+$points pts')}' : ''}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              _barRow(hpBar(p.hp, p.maxHp), '${p.hp}/${p.maxHp}',
                  label: 'HP', valueWidth: 72),
              _barRow(mpBar(p.mp, p.maxMp), '${p.mp.floor()}/${p.maxMp}',
                  label: 'MP', valueWidth: 72),
              _barRow(ultBar(ult),
                  ult >= 100 ? '¡LISTA!' : '${ult.floor()}%',
                  label: 'ULT', color: ultColor, valueWidth: 72),
              ProtoText(
                'ATQ ${p.attack} · MAG ${p.magic} · DEF ${p.defense}',
                style: const TextStyle(color: ProtoColors.sky),
              ),
              ProtoText(
                'Crít ${jsRound(p.critChance * 100)}% '
                '(×${fm(p.critMultiplier)}) · VEL ${speed.toStringAsFixed(1)}',
                style: const TextStyle(color: ProtoColors.sky),
              ),
              if (chips.isNotEmpty) ...[
                const SizedBox(height: 2),
                _chips(chips, long: true),
                const SizedBox(height: 2),
              ],
              ProtoText(turn),
            ],
          ),
        ),
      ),
    );
  }
}

/// Panel derecho: una fila compacta por cada otro jugador del grupo.
class PartyListPanel extends StatelessWidget {
  const PartyListPanel({
    super.key,
    required this.battle,
    required this.localId,
    this.sprites,
  });

  final BattleState battle;
  final String? localId;
  final GameSprites? sprites;

  @override
  Widget build(BuildContext context) {
    final others = [
      for (final p in battle.party)
        if (p.id != localId) p,
    ];
    final order = predictTurns(battle, 10);
    return BattleBarPanel(
      key: const ValueKey('party-list'),
      padding: const EdgeInsets.all(4),
      child: others.isEmpty
          ? const Center(
              child: Text('Solo', style: TextStyle(color: ProtoColors.dim)),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (i, p) in others.indexed) ...[
                    if (i > 0) const SizedBox(height: 4),
                    _MemberRow(
                      player: p,
                      current: battle.currentId == p.id,
                      turnIndex: order.indexOf(p.id),
                      sprites: sprites,
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.player,
    required this.current,
    required this.turnIndex,
    this.sprites,
  });

  final Combatant player;
  final bool current;
  final int turnIndex;
  final GameSprites? sprites;

  static const _avatar = Size(32, 40);

  @override
  Widget build(BuildContext context) {
    final p = player;
    final img = sprites?.hero(p.classId ?? '');
    final chips = combatantChips(p);
    final turn = current
        ? hexSpan('#ffd166', '▶ SU TURNO')
        : hexSpan(
            '#7d8bc4',
            !p.alive
                ? ''
                : turnIndex < 0
                    ? '—'
                    : 'Turno en $turnIndex');
    return Opacity(
      key: ValueKey('member-${p.id}'),
      opacity: p.alive ? 1 : 0.5,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: ProtoColors.input,
          border: Border.all(
            color: current ? ProtoColors.gold : ProtoColors.panelBorder,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: _avatar.width,
              height: _avatar.height,
              color: ProtoColors.bg,
              alignment: Alignment.center,
              child: img == null
                  ? const SizedBox.shrink()
                  : PixelSprite(img, scale: 2),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ProtoText(
                          '${protoEsc(p.name)} '
                          '<span class="k">${_classLine(p)}</span>',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ProtoText(turn),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _barRow(
                            hpBar(p.hp, p.maxHp), '${p.hp}/${p.maxHp}',
                            valueWidth: 60),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _barRow(mpBar(p.mp, p.maxMp),
                            '${p.mp.floor()}/${p.maxMp}',
                            valueWidth: 52),
                      ),
                    ],
                  ),
                  if (chips.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    _chips(chips),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
