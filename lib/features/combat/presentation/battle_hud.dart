import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

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
import 'pixel_sprite.dart';
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
      {this.label, this.color = ProtoColors.ink, this.valueChars = 8});

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
    if (stacked(context)) {
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

/// Pulso de [p] como pips (combo_balance.md § 5.2): llenos en oro, vacíos
/// en el borde del panel; con borde celeste si encadenó una Instante (le
/// queda una acción). El número va en el tooltip de la tarjeta.
class PulsePips extends StatelessWidget {
  const PulsePips(this.player, {super.key});

  final Combatant player;

  static const size = 6.0;
  static const gap = 2.0;

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
  });

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
    final order = predictTurns(battle, 10);
    // Siempre 4 lugares de 1/4 del ancho, desde la izquierda (los vacíos
    // quedan vacíos): una tarjeta sola no se estira a toda la pantalla y
    // los números quedan junto a sus barras.
    final party = battle.party;
    final slots = math.max(slotCount, party.length);
    // Una fila, todas arriba y del mismo alto (el de la más alta: la
    // local con ULT o la que tiene estados).
    return IntrinsicHeight(
      child: Row(
        key: const ValueKey('party-bar'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < slots; i++) ...[
            if (i > 0) const SizedBox(width: gap),
            Expanded(
              child: i >= party.length
                  ? const SizedBox.shrink()
                  : _card(party[i], order),
            ),
          ],
        ],
      ),
    );
  }

  /// Lugares de la barra (el máximo del grupo).
  static const slotCount = 4;

  /// Separación entre tarjetas.
  static const gap = 6.0;

  Widget _card(Combatant p, List<String> order) => _PartyCard(
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
  });

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
    final String turn;
    if (current) {
      turn = hexSpan(
          '#ffd166', '▶${left == null ? '' : ' ${left.ceil().clamp(0, 99)}s'}');
    } else if (!p.alive) {
      turn = hexSpan('#7d8bc4', 'K.O.');
    } else {
      turn = turnIndex < 0 ? '' : hexSpan('#7d8bc4', 'T+$turnIndex');
    }
    final ultColor = p.ult >= 100 ? ProtoColors.pink : ProtoColors.violet;
    final nameColor = local ? ' style="color:#ffd166"' : '';
    final card = Opacity(
      opacity: p.alive ? 1 : 0.55,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: local ? ProtoColors.panel : ProtoColors.input,
          border: Border.all(
            color: current
                ? ProtoColors.gold
                : local
                    ? ProtoColors.buttonBorder
                    : ProtoColors.panelBorder,
            width: 2,
          ),
        ),
        child: DefaultTextStyle.merge(
          style: RetroType.smallStyle.copyWith(color: ProtoColors.ink),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // El nombre baja de línea antes que cortarse.
                        Expanded(
                          child: ProtoText('<b$nameColor>${protoEsc(p.name)}'
                              '</b> <span class="k">'
                              'Lv${p.build?.level ?? (p.level > 0 ? p.level : '?')}</span>'),
                        ),
                        if (turn.isNotEmpty) ProtoText(turn),
                      ],
                    ),
                    _BarRow(hpBar(p.hp, p.maxHp), '${p.hp}/${p.maxHp}',
                        label: 'HP', valueChars: 9),
                    _BarRow(mpBar(p.mp, p.maxMp), '${p.mp.floor()}/${p.maxMp}',
                        label: 'MP', valueChars: 9),
                    if (local || companion)
                      _BarRow(ultBar(p.ult),
                          p.ult >= 100 ? '¡LISTA!' : '${p.ult.floor()}%',
                          label: 'ULT', color: ultColor, valueChars: 9),
                    // Pulso (combo_balance.md § 5.2): pips llenos y vacíos,
                    // de alto fijo (no crece con el tamaño del texto).
                    if (p.alive) ...[
                      const SizedBox(height: 2),
                      PulsePips(p, key: ValueKey('pulse-${p.id}')),
                    ],
                    if (summons.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      SummonsRow(summons: summons),
                    ],
                    if (onAuto case final toggle?) ...[
                      const SizedBox(height: 2),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: PanelButton(
                          'AUTO: ${auto ? 'SÍ' : 'NO'}',
                          key: ValueKey('auto-toggle-${p.id}'),
                          selected: auto,
                          onPressed: () => toggle(!auto),
                        ),
                      ),
                    ],
                    if (chips.isNotEmpty) ...[
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

/// Barra del objetivo (arriba a la izquierda de la escena): nombre, vida
/// con números, quiebre y si avisó su ULT.
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
      decoration: BoxDecoration(
        color: ProtoColors.bg.withValues(alpha: 0.9),
        border: Border.all(color: ProtoColors.crimson, width: 2),
      ),
      child: DefaultTextStyle.merge(
        style: RetroType.smallStyle.copyWith(color: ProtoColors.ink),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            ProtoText('<b style="color:#ff6b81">${protoEsc(e.name)}</b>'
                '${e.ultPending ? ' ${hexSpan('#ff3355', '¡ULT!')}' : ''}'),
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
