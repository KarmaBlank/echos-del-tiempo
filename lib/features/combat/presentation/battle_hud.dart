import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../core/procedural/weapon_look.dart';
import '../../../app/design/design.dart';
import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/party_box.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../app/theme/retro_bar.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../app/theme/vision_palette.dart';
import '../../../game_engine/data/abyss_catalog.dart';
import '../../../game_engine/models/elements.dart';
import '../../../game_engine/rules/abyss_rules.dart';
import '../../../game_engine/data/ascension_catalog.dart';
import '../../../game_engine/data/ascension_mechanics.dart';
import '../../../game_engine/data/classes_catalog.dart';
import '../../../game_engine/data/skills_catalog.dart';
import '../../ascension/domain/ascension_text.dart';
import '../../../game_engine/data/enemies_catalog.dart';
import '../../../game_engine/models/enemy_def.dart';
import '../../../game_engine/data/passive_mechanics.dart';
import '../../../game_engine/models/battle_state.dart';
import '../../../game_engine/models/passive_mechanic.dart';
import '../../../game_engine/models/status.dart';
import '../../../game_engine/rules/battle_engine.dart';
import '../../../game_engine/rules/js_math.dart';
import '../domain/element_text.dart';
import '../domain/skill_text.dart';
import '../domain/turn_order.dart';
import 'game_sprites.dart';
import 'hero_figure.dart';
import 'status_icons.dart';
import 'summons_row.dart';

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
        style: TextStyle(
            fontFamily: RetroType.bodyFamily,
            letterSpacing: RetroType.letterSpacing,
            fontFamilyFallback: RetroType.bodyFallback,
            fontSize: RetroType.small,
            height: RetroType.line,
            color: ProtoColors.ink),
        child: child,
      ),
    );
  }
}

/// Un chip de estado o buff/debuff: [short] para la lista del grupo,
/// [long] para mis datos; [tip] en markup.
class StatusChip {
  const StatusChip(this.short, this.long, this.color, this.tip, {this.icon});

  final String short;
  final String long;
  final Color color;
  final String tip;

  /// Ícono pixel art delante del texto (`status_wet`, `status_charged`).
  final String? icon;
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
    // Mojado / Cargado: el valor son turnos que quedan, no stacks.
    final count = k.timed
        ? '$n ${n == 1 ? 'turno' : 'turnos'}'
        : '×$n${k == StatusKind.holy && p.holyTurns > 0 ? ' · ${p.holyTurns} turnos' : ''}';
    chips.add(StatusChip(
      '${statusLetterOf(k)}$n',
      '${k.label} $n',
      _hex(hex),
      '<b style="color:$hex">${k.label}</b> '
          '<span class="k">$count</span>'
          '<br>${statusDescriptionOf(k)}',
      icon: statusIconOf(k),
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
    chips.add(
        StatusChip('▼VEL', '▼VEL −$pct%', ProtoColors.ice, freezeSlowTip(ice)));
  }
  if (p.brittle && ice > 0 && p.alive) {
    chips.add(StatusChip(
        'Quebr.', 'Quebradizo', const Color(0xFF81ECEC), brittleTip()));
  }
  if (p.freezeResist > 0 && p.alive) {
    chips.add(StatusChip('▲HIELO', 'Resiste hielo ${p.freezeResist}',
        ProtoColors.ice, freezeResistTip(p.freezeResist)));
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
  if (p.voidMarked && p.alive) {
    chips.add(const StatusChip(
        'Marcado ×2',
        'Marca del Vacío ×2',
        Color(0xFFB57BFF),
        '<b style="color:#b57bff">Marca del Vacío</b><br>El próximo golpe del '
            'Centinela va contra él y pega <b>×2</b>, salvo que otro aliado lo '
            '<b>Proteja</b>. <span class="k">Solo: Defender también la '
            'contrarresta.</span>'));
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
        final n =
            b.enemies.where((c) => c.alive && c.enemyType == m.addType).length;
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
        final hex = e.broken
            ? '#7f8c8d'
            : shield
                ? '#74b9ff'
                : '#ff6b6b';
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

      // ---- v0.3 (docs/specs/bosses.md § "v0.3") ----
      case BossMechanicKind.echo || BossMechanicKind.summon:
        final echo = m.kind == BossMechanicKind.echo;
        final n =
            b.enemies.where((c) => c.alive && c.enemyType == m.addType).length;
        final max = b.party.length == 1 ? m.soloAdds : m.adds;
        final back = m.every - e.mechTurns;
        final when =
            n >= max ? '' : ' · vuelven en $back turno${back == 1 ? '' : 's'}';
        final (String short, String long, Color col, String hex) = echo
            ? (
                'Ecos $n',
                'Ecos: $n vivo${n == 1 ? '' : 's'} (×${fm(m.value)} daño)$when',
                const Color(0xFF7FF3FF),
                '#7ff3ff'
              )
            : n > 0
                ? (
                    'INMUNE ($n)',
                    'Séquito $n · INMUNE a estados$when',
                    const Color(0xFFB8C6FF),
                    '#b8c6ff'
                  )
                : (
                    'Séquito 0',
                    'Séquito 0 · los estados entran$when',
                    ProtoColors.green,
                    '#7bed9f'
                  );
        chips.add(StatusChip(
            short,
            long,
            col,
            '<b style="color:$hex">${m.name}</b> '
            '<span class="k">(${protoEsc(e.name)} · $n/$max)</span><br>${m.counter}'));
      case BossMechanicKind.lava:
        final up = e.lava > 0;
        final next = m.every - e.actions % m.every;
        chips.add(StatusChip(
            up ? 'LAVA ${e.lava}' : 'Lava en $next',
            up
                ? 'LAVA ${e.lava} turno${e.lava == 1 ? '' : 's'} · ¡no te defiendas!'
                : '${m.name}: sube en $next acci${next == 1 ? 'ón' : 'ones'}',
            up ? const Color(0xFFFF7B29) : const Color(0xFFFFB142),
            '<b style="color:#ff7b29">${m.name}</b> '
            '<span class="k">(${up ? 'activa ${e.lava} turnos' : 'sube en $next acciones'})</span>'
            '<br>${m.counter}'));
      case BossMechanicKind.mark:
        final marked =
            b.party.where((p) => p.alive && p.voidMarked).firstOrNull;
        final next = m.every - e.actions % m.every;
        final x = fm(b.party.length == 1 ? m.soloValue : m.value);
        chips.add(StatusChip(
            marked == null ? 'Marca en $next' : 'MARCA ×$x',
            marked == null
                ? '${m.name}: marca en $next acci${next == 1 ? 'ón' : 'ones'}'
                : '${m.name}: ${marked.name} ×$x · ¡protegelo!',
            const Color(0xFFB57BFF),
            '<b style="color:#b57bff">${m.name}</b> '
            '<span class="k">(${marked == null ? 'nadie marcado' : 'marcado: ${protoEsc(marked.name)}'})</span>'
            '<br>${m.counter}'));
      case BossMechanicKind.phases:
        final two = e.phase >= 2;
        final next = m.every - e.actions % m.every;
        chips.add(StatusChip(
            two ? 'FASE 2' : 'FASE 1',
            two
                ? 'FASE 2 · Colapso Temporal cada ${m.every} (en $next)'
                : 'FASE 1 · se transforma al ${jsRound(m.value * 100)}%',
            two ? ProtoColors.crimson : ProtoColors.pink,
            '<b style="color:#d63031">${m.name}</b> '
            '<span class="k">(${two ? 'fase 2' : 'fase 1'})</span><br>${m.counter}'));

      // ---- Jefes del Abismo v0.8 (docs/specs/abyss_bosses.md § 4) ----
      case BossMechanicKind.abyss:
        chips.addAll(abyssChips(b, e, m));
    }
  }
  return chips;
}

/// Chips de un Jefe del Abismo: fase, próximo movimiento, furia, sello,
/// aspecto, inmunidad y buffs comidos.
List<StatusChip> abyssChips(BattleState b, Combatant e, BossMechanicDef m) {
  final d = abyssBossOf(e.enemyType);
  if (d == null) return const [];
  final ph = AbyssRules.phaseOf(d, e);
  final n = AbyssRules.phaseIndex(d, e) + 1;
  final tip = '<b style="color:#c39bff">${protoEsc(d.name)}</b> '
      '<span class="k">(fase $n/${d.phases.length} · ${protoEsc(ph.name)})</span>'
      '<br>${m.counter}';
  const violet = Color(0xFFC39BFF);
  final next = AbyssRules.nextMove(d, e);
  final enrage = AbyssRules.enrageIn(d, e);
  final addsAlive = m.addType != null &&
      b.enemies.any((c) => c.alive && c.enemyType == m.addType);
  final solo = b.party.length == 1;
  final immune = ph.immuneWhileAdds && addsAlive;
  // Lo más urgente primero: la caja del detalle puede cortar los últimos.
  return [
    StatusChip(
        immune ? 'INMUNE' : 'FASE $n/${d.phases.length}',
        immune
            ? 'FASE $n/${d.phases.length} · INMUNE al daño · matá a sus invocaciones'
            : 'FASE $n/${d.phases.length} · ${ph.name}',
        immune
            ? const Color(0xFFB8C6FF)
            : n >= d.phases.length
                ? ProtoColors.crimson
                : ProtoColors.pink,
        tip),
    if (e.abyssEnraged)
      StatusChip('FURIA', 'FURIA: golpea a todos', ProtoColors.crimson, tip),
    if (!e.abyssEnraged && next.kind.telegraphed)
      StatusChip('PRÓX: ${next.label}', 'PRÓXIMO: ${next.label}', violet, tip),
    if (e.abyssSeal > 0)
      () {
        final r = ReactionKind
            .values[(e.abyssSeal - 1).clamp(0, ReactionKind.values.length - 1)];
        final need = solo ? 'cualquier reacción' : r.label;
        return StatusChip('SELLO ${e.abyssSealTurns}',
            'SELLO ${e.abyssSealTurns}t · rompelo con $need', violet, tip);
      }(),
    if (e.abyssAspect > 0)
      () {
        final el = GameElement.values[
            (e.abyssAspect - 1).clamp(0, GameElement.values.length - 1)];
        return StatusChip('Aspecto ${el.label}',
            'Aspecto ${el.label} · resiste ${el.label}', ProtoColors.ice, tip);
      }(),
    if (!e.abyssEnraged)
      StatusChip(
          'Furia en $enrage',
          'Furia en $enrage turno${enrage == 1 ? '' : 's'}',
          enrage <= 5 ? ProtoColors.crimson : ProtoColors.dim,
          tip),
    if (d.healHurts > 0)
      StatusChip(
          'Curas lo dañan',
          'Las curas lo dañan (${jsRound(d.healHurts * 100)}%)',
          ProtoColors.green,
          tip),
    if (e.abyssFeast > 0)
      StatusChip('Comió ${e.abyssFeast}', 'Buffs comidos: ${e.abyssFeast}',
          ProtoColors.orange, tip),
  ];
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
      kAscensionMechanics[e.sourceId]?.name ??
      kSkills[e.sourceId]?.name ??
      kAscensionUltimatesById[e.sourceId]?.name ??
      kBossMechanics[e.sourceId]?.name ??
      (e.sourceId == 'vigilancia' ? 'Vigilante del Vacío' : null) ??
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
                'Su turno llega más tarde.'
                '${kSkills.containsKey(e.sourceId) ? ' (${turns(e)})' : ' Rompé los cristales de hielo para quitarlo.'}'));
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
      // ---- ascensión (docs/specs/ascension.md) ----
      case BuffStat.guard:
        chips.add(StatusChip(
            '▼DAÑO',
            'Defensa −$pct%',
            ProtoColors.sky,
            '<b style="color:#74b9ff">Defensa: −$pct% de daño recibido</b> '
                '<span class="k">($from · ${turns(e)})</span>'));
      case BuffStat.crit:
        chips.add(StatusChip(
            '▲CRÍT',
            '▲CRÍT +$pct%',
            ProtoColors.pink,
            '<b style="color:#ff6b81">Crítico +$pct%</b> '
                '<span class="k">($from · ${turns(e)})</span>'));
      case BuffStat.critMulti:
        chips.add(StatusChip(
            '▲×CRÍT',
            '▲×CRÍT +${fm(e.value)}',
            ProtoColors.pink,
            '<b style="color:#ff6b81">Multiplicador de crítico +${fm(e.value)}</b> '
                '<span class="k">($from · ${turns(e)})</span>'));
      case BuffStat.trap:
        final n = e.value.round();
        chips.add(StatusChip(
            'Trampa',
            'Trampa $n',
            ProtoColors.green,
            '<b style="color:#7bed9f">Trampa $n</b> '
                '<span class="k">($from · ${turns(e)})</span><br>'
                'Salta al empezar su turno: $n de daño.'));
      case BuffStat.charge:
        final n = e.value.round();
        chips.add(StatusChip(
            'Carga',
            'Carga $n',
            ProtoColors.orange,
            '<b style="color:#ff9f43">Disparo cargado $n</b> '
                '<span class="k">($from)</span><br>'
                'Cae al empezar su próximo turno: $n de daño.'));
      case BuffStat.damage ||
            BuffStat.lifeSteal ||
            BuffStat.delayPower ||
            BuffStat.buffPower ||
            BuffStat.buffTurns ||
            BuffStat.trapPower ||
            BuffStat.trapTurns ||
            BuffStat.shieldPower ||
            BuffStat.shieldReflect ||
            BuffStat.holyPower ||
            BuffStat.shareDamage:
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
      // Tooltip corto: nombre y turnos; la explicación, plegada.
      foldAfter: 1,
      foldTitle: 'Qué hace',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        decoration: BoxDecoration(
          color: ProtoColors.bg,
          border: Border.all(color: chip.color),
        ),
        child: _withIcon(
          chip.icon,
          Text(
            retroText(long ? chip.long : chip.short),
            style: TextStyle(
                fontFamily: RetroType.bodyFamily,
                letterSpacing: RetroType.letterSpacing,
                fontFamilyFallback: RetroType.bodyFallback,
                fontSize: RetroType.small,
                height: RetroType.lineTight,
                color: chip.color),
          ),
        ),
      ),
    );
  }

  /// [text] con el ícono pixel art delante (si hay).
  static Widget _withIcon(String? icon, Widget text) {
    if (icon == null) return text;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      StatusIcon(icon),
      const SizedBox(width: 2),
      text,
    ]);
  }
}

Widget _chips(List<StatusChip> chips, {bool long = false}) => Wrap(
      spacing: 3,
      runSpacing: 3,
      children: [for (final c in chips) StatusChipView(c, long: long)],
    );

/// Barra con `n/m` a la derecha (y una etiqueta opcional a la izquierda).
/// Los anchos de la etiqueta y del valor van en caracteres ([labelChars],
/// `valueChars`) para que crezcan con el tamaño del texto.
class _BarRow extends StatelessWidget {
  const _BarRow(this.bar, this.value,
      {this.label,
      this.color = DsColors.textPrimary,
      this.valueChars = 8,
      this.stack = false});

  /// Apilada aunque el texto no sea ENORME (tarjetas angostas de un grupo
  /// de más de 8, v0.13).
  final bool stack;

  final Widget bar;
  final String value;
  final String? label;
  final Color color;
  final double valueChars;

  /// Ancho de la etiqueta (`ULT`) en caracteres.
  static const labelChars = 3.5;

  /// Con TAMAÑO DEL TEXTO ENORME (o más) la etiqueta y las cifras no
  /// dejan lugar a la barra: van arriba y la barra debajo. Por el factor
  /// del ajuste (sin la ventana) y no por el ancho: la tarjeta mide su
  /// alto intrínseco (sin `LayoutBuilder`).
  static bool stacked(BuildContext context) =>
      RetroType.settingFactor(context) >= 1.9; // ENORME

  @override
  Widget build(BuildContext context) {
    final labelW = label == null ? 0.0 : RetroType.em(context, labelChars);
    final valueW = RetroType.em(context, valueChars);
    final style = RetroType.style(RetroType.label, color: color);
    if (stack || stacked(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (label != null)
                Text(label!, maxLines: 1, softWrap: false, style: style),
              const Spacer(),
              Flexible(
                flex: 100,
                child: Text(value,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    textAlign: TextAlign.right,
                    style: style),
              ),
            ],
          ),
          bar,
        ],
      );
    }
    return Row(
      children: [
        if (label != null)
          SizedBox(
              width: labelW,
              child: Text(label!, maxLines: 1, softWrap: false, style: style)),
        Expanded(child: bar),
        SizedBox(
          width: valueW,
          // Si las cifras no entran ("1200/1200"), se achican en vez de
          // cortarse; las que entran quedan igual.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(value,
                maxLines: 1,
                softWrap: false,
                textAlign: TextAlign.right,
                // Cifras de las barras: Press Start 2P (monoespaciada).
                style: style),
          ),
        ),
      ],
    );
  }
}

/// Qué parte del HUD del grupo resalta el panel del TUTORIAL
/// (combat_tutorial.md § 4.1): la barra de MP y/o los pips de Pulso. El
/// resaltado es un borde naranja (énfasis por color, sin negritas).
class HudHighlight extends InheritedWidget {
  const HudHighlight({super.key, required this.parts, required super.child});

  static const mp = 'mp';
  static const pulse = 'pulse';

  /// [mp], [pulse].
  final Set<String> parts;

  static bool on(BuildContext context, String part) =>
      context
          .dependOnInheritedWidgetOfExactType<HudHighlight>()
          ?.parts
          .contains(part) ??
      false;

  /// [child] con borde si [part] está resaltado (la key va solo entonces).
  static Widget wrap(
      BuildContext context, String part, Key key, Widget child,
      {bool tight = false}) {
    if (!on(context, part)) return child;
    final box = Container(
      key: key,
      foregroundDecoration: BoxDecoration(
          border: Border.all(color: ProtoColors.orange, width: 1)),
      child: child,
    );
    return tight ? Align(alignment: Alignment.centerLeft, child: box) : box;
  }

  @override
  bool updateShouldNotify(HudHighlight old) =>
      old.parts.length != parts.length || !old.parts.containsAll(parts);
}

/// Pulso de [p] como pips (combo_balance.md § 5.2): llenos en oro, vacíos
/// en el borde del panel; con borde celeste si encadenó una Instante (le
/// queda una acción). El número va en el tooltip de la tarjeta.
class PulsePips extends StatelessWidget {
  const PulsePips(this.player, {super.key});

  final Combatant player;

  static const size = 9.0;
  static const gap = 3.0;

  @override
  Widget build(BuildContext context) {
    final n = player.pulse.clamp(0, BattleEngine.pulseMax);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < BattleEngine.pulseMax; i++) ...[
          if (i > 0) const SizedBox(width: gap),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: i < n ? ProtoColors.gold : ProtoColors.barBg,
              border: Border.all(
                  color: player.chained ? ProtoColors.sky : ProtoColors.panelBorder,
                  width: 1),
            ),
          ),
        ],
      ],
    );
  }
}

/// Fila `PULSO ■■□□□ 2/5` de la tarjeta: siempre una línea; los pips se
/// achican si la tarjeta es angosta.
class _PulseRow extends StatelessWidget {
  const _PulseRow(this.player);

  final Combatant player;

  @override
  Widget build(BuildContext context) {
    // Con texto ENORME la tarjeta no tiene alto para otra línea: solo los
    // pips (el número va en el tooltip).
    if (_BarRow.stacked(context)) {
      return Align(
          alignment: Alignment.centerLeft,
          child: PulsePips(player, key: ValueKey('pulse-${player.id}')));
    }
    final style = RetroType.style(RetroType.label, color: DsColors.pulse);
    final n = player.pulse.clamp(0, BattleEngine.pulseMax);
    return Row(
      children: [
        Text('PULSO', maxLines: 1, softWrap: false, style: style),
        const SizedBox(width: 4),
        Flexible(
          child: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: PulsePips(player, key: ValueKey('pulse-${player.id}')),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text('$n/${BattleEngine.pulseMax}',
            maxLines: 1, softWrap: false, style: style),
      ],
    );
  }
}

/// `<b>Ana</b>, Cronomante` con la ascensión en su color (ascension.md § 5).
String heroNameMarkup(Combatant p) {
  final a = ascensionFor(p.classId, p.ascensionId);
  final n = '<b>${protoEsc(p.name)}</b>';
  return a == null ? n : '$n, ${hexSpan(ascensionHex(a), protoEsc(a.name))}';
}

String _classLine(Combatant p) {
  final cls = kClasses[p.classId]?.name ?? p.classId ?? '';
  final lvl = p.build?.level;
  return '$cls${lvl == null ? '' : ' Lv$lvl'}';
}

/// Detalle de [p] para el tooltip de su tarjeta: ATQ, MAG, DEF, crítico,
/// velocidad y arma (lo que antes ocupaba el panel izquierdo).
String heroStatsMarkup(Combatant p, {int points = 0}) {
  final build = p.build;
  final up = build?.weaponUpgrades.total ?? 0;
  final weapon = build == null
      ? ''
      : '${build.equippedWeapon.name}${up > 0 ? ' +$up' : ''}';
  final speed = 100 / turnInterval(p);
  final pts = points > 0 ? ' ${hexSpan('#ffd166', '+$points pts')}' : '';
  return [
    '${heroNameMarkup(p)} <span class="k">${_classLine(p)}</span>',
    if (weapon.isNotEmpty) hexSpan('#ff9f43', '⚔ ${protoEsc(weapon)}$pts'),
    'HP ${p.hp}/${p.maxHp} · MP ${p.mp.floor()}/${p.maxMp} · '
        'ULT ${p.ult.floor()}% · '
        '${hexSpan('#ffb142', 'Pulso ${p.pulse}/${BattleEngine.pulseMax}')}'
        '${p.chained ? ' ${hexSpan('#9fe8ff', '+1 acción (Instante)')}' : ''}',
    '<span class="k">ATQ ${p.attack} · MAG ${p.magic} · '
        'DEF ${p.defense}</span>',
    '<span class="k">Crít ${jsRound(p.critChance * 100)}% '
        '(×${fm(p.critMultiplier)}) · VEL ${speed.toStringAsFixed(1)}</span>',
  ].join('<br>');
}

/// Barra del grupo (v0.5, battle_presentation.md § "Barra de batalla"):
/// una tarjeta por jugador, una al lado de la otra; la del turno con borde
/// dorado. La tarjeta propia (`my-panel-<id>`) lleva el detalle de stats en
/// su tooltip; las otras son `member-<id>`.
class BattlePartyBar extends StatelessWidget {
  const BattlePartyBar({
    super.key,
    required this.battle,
    required this.localId,
    this.sprites,
    this.turnTimeLeft,
    this.points = 0,
    this.companions = const {},
    this.auto = const {},
    this.onAuto,
    this.onlyLocal = false,
  });

  /// Solo la tarjeta propia (grupo compacto: los demás van en
  /// [BattleAllyList]).
  final bool onlyLocal;

  final BattleState battle;
  final String? localId;
  final GameSprites? sprites;
  final double? turnTimeLeft;
  final int points;

  /// Compañeros de la party de este dispositivo (docs/specs/
  /// solo_party.md § 4): su tarjeta muestra la ULT y el botón AUTO.
  final Set<String> companions;
  final Set<String> auto;
  final void Function(String id, bool on)? onAuto;

  @override
  Widget build(BuildContext context) {
    final order = predictTurns(battle, turnWindow(battle));
    // Lugares de 1/[perRow] del ancho, desde la izquierda (los vacíos
    // quedan vacíos): una tarjeta sola no se estira a toda la pantalla y
    // los números quedan junto a sus barras.
    final mine = battle.party.where((p) => p.id == localId).toList();
    final party = onlyLocal && mine.isNotEmpty ? mine : battle.party;
    final (rows, perRow) = gridFor(party.length);
    final compact = party.length > slotCount;
    // Cada fila: todas arriba y del mismo alto (el de la más alta: la
    // local con ULT o la que tiene estados).
    Widget row(int r) => IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var c = 0; c < perRow; c++) ...[
                if (c > 0) const SizedBox(width: gap),
                Expanded(
                  child: r * perRow + c >= party.length
                      ? const SizedBox.shrink()
                      : _card(party[r * perRow + c], order, compact,
                          narrow: perRow > slotCount),
                ),
              ],
            ],
          ),
        );
    return Column(
      key: const ValueKey('party-bar'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var r = 0; r < rows; r++) ...[
          if (r > 0) const SizedBox(height: gap),
          row(r),
        ],
      ],
    );
  }

  /// Lugares por fila con un grupo chico (y desde cuántos jugadores las
  /// tarjetas pasan a compactas).
  static const slotCount = 4;

  /// Filas y lugares por fila para un grupo de [n] (v0.13, cualquier n):
  /// 1 fila de [slotCount] hasta [slotCount]; después 2 filas, de
  /// [slotCount] por fila hasta el doble y más angostas si son más.
  static (int, int) gridFor(int n) {
    if (n <= slotCount) return (1, slotCount);
    return (2, math.max(slotCount, (n + 1) ~/ 2));
  }

  /// Separación entre tarjetas.
  static const gap = 6.0;

  Widget _card(Combatant p, List<String> order, bool compact,
          {bool narrow = false}) =>
      _PartyCard(
        compact: compact,
        narrow: narrow,
        key: ValueKey(p.id == localId ? 'my-panel-${p.id}' : 'member-${p.id}'),
        player: p,
        local: p.id == localId,
        current: battle.currentId == p.id,
        turnIndex: order.indexOf(p.id),
        sprites: sprites,
        turnTimeLeft: battle.currentId == p.id ? turnTimeLeft : null,
        points: p.id == localId ? points : 0,
        companion: companions.contains(p.id),
        auto: auto.contains(p.id),
        onAuto: companions.contains(p.id) && onAuto != null
            ? (on) => onAuto!(p.id, on)
            : null,
        summons: [
          for (final s in battle.summons)
            if (s.summonOwner == p.id) s,
        ],
      );
}

class _PartyCard extends StatelessWidget {
  const _PartyCard({
    super.key,
    required this.player,
    required this.local,
    required this.current,
    required this.turnIndex,
    this.sprites,
    this.turnTimeLeft,
    this.points = 0,
    this.companion = false,
    this.auto = false,
    this.onAuto,
    this.summons = const [],
    this.compact = false,
    this.narrow = false,
  });

  /// Más de [BattlePartyBar.slotCount] por fila: barras con las cifras
  /// arriba.
  final bool narrow;

  /// Grupo de más de [BattlePartyBar.slotCount] (v0.13): sin retrato,
  /// nombre en una línea y sin Pulso, invocaciones ni estados (siguen en
  /// el tooltip y en la escena) salvo en la tarjeta propia.
  final bool compact;

  /// Invocaciones de este jugador (summoner.md § 8).
  final List<Combatant> summons;

  /// Compañero de la party: ULT a la vista y botón AUTO.
  final bool companion;
  final bool auto;
  final ValueChanged<bool>? onAuto;

  final Combatant player;
  final bool local;
  final bool current;
  final int turnIndex;
  final GameSprites? sprites;
  final double? turnTimeLeft;
  final int points;

  static const _avatar = Size(32, 40);

  @override
  Widget build(BuildContext context) {
    final p = player;
    final img = sprites?.heroFor(p.classId, p.ascensionId);
    final chips = combatantChips(p);
    final left = turnTimeLeft;
    // Turno: corto para que el nombre no se corte ("T+3").
    // Sistema de diseño (design_system.md § 10.3): jerarquía por color.
    final String turn;
    final Color turnColor;
    if (current) {
      turn = '▶${left == null ? '' : ' ${left.ceil().clamp(0, 99)}s'}';
      turnColor = DsColors.selected;
    } else if (!p.alive) {
      turn = 'K.O.';
      turnColor = DsColors.textSecondary;
    } else {
      turn = turnIndex < 0 ? '' : 'T+$turnIndex';
      turnColor = DsColors.textSecondary;
    }
    final ultColor = ultReady(p) ? ProtoColors.pink : ProtoColors.violet;
    final card = Opacity(
      opacity: p.alive ? 1 : 0.55,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: local ? DsColors.surface : DsColors.surfaceSunken,
          border: Border.all(
            color: current
                ? DsColors.selected
                : local
                    ? DsColors.borderControl
                    : DsColors.border,
            width: 2,
          ),
        ),
        child: DefaultTextStyle.merge(
          style: DsText.detail(DsColors.textPrimary),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!compact) ...[
                Container(
                  width: _avatar.width,
                  height: _avatar.height,
                  color: DsColors.background,
                  alignment: Alignment.center,
                  child: img == null
                      ? const SizedBox.shrink()
                      : HeroFigure(img,
                          key: ValueKey('hud-figure-${p.id}'),
                          classId: p.classId ?? '',
                          weaponType: p.weaponType,
                          look: lookOfCombatant(p),
                          size: _avatar),
                ),
                const SizedBox(width: 5),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // El nombre baja de línea antes que cortarse.
                        Expanded(
                          child: Text.rich(
                              maxLines: compact ? 1 : null,
                              overflow: compact ? TextOverflow.ellipsis : null,
                              TextSpan(children: [
                            TextSpan(
                                text: p.name,
                                style: DsText.body(local
                                    ? DsColors.textTitle
                                    : DsColors.textPrimary)),
                            TextSpan(
                                text: ' Lv${p.build?.level ?? (p.level > 0 ? p.level : '?')}',
                                style: DsText.detail()),
                          ])),
                        ),
                        if (turn.isNotEmpty)
                          Text(turn, style: DsText.detail(turnColor)),
                      ],
                    ),
                    _BarRow(hpBar(p.hp, p.maxHp), '${p.hp}/${p.maxHp}',
                        label: 'HP', valueChars: 9, stack: narrow),
                    HudHighlight.wrap(
                        context,
                        HudHighlight.mp,
                        ValueKey('hl-mp-${p.id}'),
                        _BarRow(mpBar(p.mp, p.maxMp),
                            '${p.mp.floor()}/${p.maxMp}',
                            label: 'MP', valueChars: 9, stack: narrow)),
                    if (local || companion)
                      _BarRow(ultBar(p.ult),
                          ultReady(p) ? '¡LISTA!' : '${p.ult.floor()}%',
                          label: 'ULT',
                          color: ultColor,
                          valueChars: 9,
                          stack: narrow),
                    // Pulso (combo_balance.md § 5.2): una fila con nombre y
                    // cifras como HP y MP, con los pips en lugar de barra
                    // (pedido del dueño: "que se vea que tenés Pulso").
                    if (p.alive && (!compact || local))
                      HudHighlight.wrap(
                          context,
                          HudHighlight.pulse,
                          ValueKey('hl-pulse-${p.id}'),
                          _PulseRow(p)),
                    if (summons.isNotEmpty && (!compact || local)) ...[
                      const SizedBox(height: 2),
                      SummonsRow(summons: summons),
                    ],
                    if (onAuto case final toggle?) ...[
                      const SizedBox(height: 2),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: DsButton(
                          'AUTO: ${auto ? 'SÍ' : 'NO'}',
                          key: ValueKey('auto-toggle-${p.id}'),
                          size: DsButtonSize.compact,
                          selected: auto,
                          onPressed: () => toggle(!auto),
                        ),
                      ),
                    ],
                    if (chips.isNotEmpty && (!compact || local)) ...[
                      const SizedBox(height: 2),
                      _chips(chips),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return RetroTooltip(
        message: heroStatsMarkup(p, points: points), child: card);
  }
}

/// Barra del objetivo (arriba a la izquierda de la escena): nombre (con
/// la letra de repetidos), marca de élite o jefe, vida con números,
/// quiebre y si avisó su ULT.
class TargetBar extends StatelessWidget {
  const TargetBar({super.key, required this.enemy});

  final Combatant enemy;

  @override
  Widget build(BuildContext context) {
    final e = enemy;
    // Sigue al modo daltónico (accessibility.md § 3).
    const breakColor = VisionColor(VisionSlot.breakBar);
    final hpText = '${e.hp}/${e.maxHp}';
    final breakText =
        e.broken
            ? '¡ROTO!'
            : e.fissured
                ? 'FISURADO'
                : '${e.breakGauge.floor()}/${e.breakMax.round()}';
    // Jefes del Abismo: 5 cifras ("3300/10000") — la columna crece.
    final chars =
        math.max(9, math.max(hpText.length, breakText.length)).toDouble();
    return Container(
      key: const ValueKey('target-bar'),
      width: RetroType.width(context, 200 + (chars - 9) * 8.0),
      padding: const EdgeInsets.all(4),
      // Sistema de diseño: nombre en Cuerpo rojo, ¡ULT! como DsTag.
      decoration: BoxDecoration(
        color: DsColors.background.withValues(alpha: 0.9),
        // Élite y jefe: borde dorado, como su ícono en la franja de turnos.
        border: Border.all(
            color: e.elite || e.boss ? DsColors.reward : DsColors.danger,
            width: 2),
      ),
      child: DefaultTextStyle.merge(
        style: DsText.detail(DsColors.textPrimary),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Flexible(
                child: Text(e.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DsText.body(DsColors.danger)),
              ),
              if (e.elite || e.boss) ...[
                const SizedBox(width: 4),
                DsTag(e.boss ? 'JEFE' : '★ ÉLITE',
                    key: const ValueKey('target-rank'),
                    color: DsColors.reward),
              ],
              if (e.ultPending) ...[
                const SizedBox(width: 4),
                const DsTag('¡ULT!', color: DsColors.danger),
              ],
            ]),
            // ULT v2 (ultimates_v2.md § 4.1): el nombre de la que avisa;
            // la lanza en su próximo turno.
            if (e.ultPending && kEnemyUlts[e.ultId] != null)
              Text('Prepara ${kEnemyUlts[e.ultId]!.name}: la lanza en su turno',
                  key: const ValueKey('target-ult-name'),
                  maxLines: 2,
                  style: DsText.detail(DsColors.danger)),
            _BarRow(
                RetroBar(value: e.hp, max: e.maxHp, color: ProtoColors.crimson),
                hpText,
                label: 'HP',
                valueChars: chars),
            if (e.hasBreak)
              _BarRow(
                  RetroBar(
                      value: e.broken ? e.breakMax : e.breakGauge,
                      max: e.breakMax,
                      height: 4,
                      color: breakColor),
                  breakText,
                  label: 'QB',
                  color: breakColor,
                  valueChars: chars),
          ],
        ),
      ),
    );
  }
}

/// Lista compacta del grupo a la derecha de la arena (v0.13.1,
/// battle_presentation.md § "Grupo compacto"): sin compañeros propios
/// (`soloParty` apagado) los demás jugadores manejan su personaje, así que
/// abajo va solo la tarjeta propia y el resto, acá, de arriba hacia abajo:
/// avatar, nombre, vida, maná y `T+n` o estado. El de turno, con borde
/// dorado; el señalado con el mouse (acá, en la arena o en la franja),
/// con borde blanco. Se achica entera si no entra (cualquier n).
class BattleAllyList extends StatelessWidget {
  const BattleAllyList({
    super.key,
    required this.battle,
    required this.members,
    this.sprites,
    this.hoverId,
    this.onHover,
    this.maxRows = maxRowsDefault,
  });

  final BattleState battle;

  /// Los aliados de la lista (todos menos el propio), en orden.
  final List<Combatant> members;
  final GameSprites? sprites;
  final String? hoverId;

  /// Mouse sobre la fila de un aliado (`null` al salir).
  final ValueChanged<String?>? onHover;

  /// Filas antes de pasar a desplazarse (con más se achican hasta este
  /// número y después hay scroll).
  final int maxRows;

  static const maxRowsDefault = 12;

  /// Ancho de la lista a texto Normal (crece con el texto).
  static const width = 250.0;

  @override
  Widget build(BuildContext context) {
    final order = predictTurns(battle, turnWindow(battle));
    final f = RetroType.factorOf(context);
    final rows = [
      for (var i = 0; i < members.length; i++) ...[
        if (i > 0) const SizedBox(height: 3),
        _row(members[i], order),
      ],
    ];
    return LayoutBuilder(builder: (context, cons) {
      final w = width * (f < 1 ? 1 : f);
      final col = SizedBox(
        width: w,
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rows),
      );
      // Hasta [maxRows] se achica para entrar; con más, scroll.
      final Widget body = members.length > maxRows
          ? SingleChildScrollView(child: col)
          : FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topRight,
              child: col);
      return Align(
        key: const ValueKey('ally-list'),
        alignment: Alignment.topRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxWidth: math.min(w, cons.maxWidth),
              maxHeight: cons.maxHeight),
          child: body,
        ),
      );
    });
  }

  Widget _row(Combatant p, List<String> order) {
    final img = sprites?.heroFor(p.classId, p.ascensionId);
    final current = battle.currentId == p.id;
    final hovered = hoverId == p.id;
    final i = order.indexOf(p.id);
    final stunned = p.stacks(StatusKind.stun) > 0;
    final stunIcon = statusIconOf(StatusKind.stun);
    final Widget mark;
    if (!p.alive) {
      mark = Text('K.O.', style: DsText.detail(DsColors.danger));
    } else if (current) {
      mark = Text('▶', style: DsText.detail(DsColors.selected));
    } else {
      mark = Row(mainAxisSize: MainAxisSize.min, children: [
        if (stunned && stunIcon != null) ...[
          StatusIcon(stunIcon, px: 2),
          const SizedBox(width: 3),
        ],
        if (i >= 0) Text('T+$i', style: DsText.detail()),
      ]);
    }
    final row = Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: DsColors.surfaceSunken.withValues(alpha: 0.92),
        border: Border.all(
          color: hovered
              ? ProtoColors.white
              : current
                  ? DsColors.selected
                  : DsColors.border,
          width: current || hovered ? 2 : 1,
        ),
      ),
      child: Opacity(
        opacity: p.alive ? 1 : 0.55,
        child: Row(children: [
          Container(
            width: 32,
            height: 40,
            color: DsColors.background,
            alignment: Alignment.center,
            child: img == null
                ? null
                : HeroFigure(img,
                    classId: p.classId ?? '',
                    weaponType: p.weaponType,
                    look: lookOfCombatant(p),
                    size: const Size(32, 40)),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DsText.body(DsColors.textPrimary)),
                  ),
                  const SizedBox(width: 4),
                  mark,
                ]),
                const SizedBox(height: 2),
                RetroBar(
                    value: p.hp, max: p.maxHp, color: ProtoColors.hp, height: 6),
                const SizedBox(height: 2),
                RetroBar(
                    value: p.mp.floor(),
                    max: p.maxMp,
                    color: ProtoColors.mp,
                    height: 4),
              ],
            ),
          ),
        ]),
      ),
    );
    return MouseRegion(
      key: ValueKey('ally-row-${p.id}'),
      onEnter: (_) => onHover?.call(p.id),
      onExit: (_) => onHover?.call(null),
      child: RetroTooltip(message: heroStatsMarkup(p), child: row),
    );
  }
}
