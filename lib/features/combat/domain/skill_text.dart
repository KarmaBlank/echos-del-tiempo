import '../../../core/i18n/catalog_text.dart';
import '../../../game_engine/data/elements_catalog.dart';
import '../../../game_engine/models/battle_state.dart';
import '../../../game_engine/models/passive_mechanic.dart' show BuffStat;
import '../../../game_engine/models/skill.dart';
import '../../../game_engine/models/status.dart';
import '../../../game_engine/rules/js_math.dart';
import '../../../game_engine/rules/revive_rules.dart';
import '../../../game_engine/rules/skill_requirements.dart';
import '../../../core/i18n/catalog_names.dart';
import '../../../core/text/text_detail.dart';
import 'element_text.dart';
import 'skill_short_text.dart';
import 'summon_text.dart';

/// Textos de estados y habilidades en el markup del prototipo (el HTML
/// chico que entiende `ProtoMarkup`, docs/specs/ui_style.md § "Texto
/// rico"): `stDesc` y `descSkill` (líneas 1108-1121), con los mismos
/// `<b>`, `<span class="k">` y colores. Dart puro (sin Flutter).

/// `STATUS[k].col` como `#rrggbb`.
String statusHex(StatusKind k) => switch (k) {
      StatusKind.burn => '#ff7b29',
      StatusKind.poison => '#7bed9f',
      StatusKind.freeze => '#74b9ff',
      StatusKind.stun => '#ffeaa7',
      StatusKind.holy => '#fff3b0',
      StatusKind.regen => '#55efc4',
      StatusKind.wet => '#3fa9f5',
      StatusKind.charged => '#c77dff',
    };

/// `STLET[k]`: letra del estado (los emojis del prototipo no están en la
/// fuente; el canvas del prototipo ya usa estas letras).
String statusLetterOf(StatusKind k) => switch (k) {
      StatusKind.burn => 'Q',
      StatusKind.poison => 'V',
      StatusKind.freeze => 'C',
      StatusKind.stun => 'A',
      StatusKind.holy => 'S',
      StatusKind.regen => 'R',
      StatusKind.wet => 'M',
      StatusKind.charged => 'E',
    };

/// `STATUS[k].desc`.
String statusDescriptionOf(StatusKind k) =>
    TextDetail.isSummary ? statusShortOf(k) : statusFullDescriptionOf(k);

/// `STATUS[k].desc` en DETALLADO (las reglas completas).
String statusFullDescriptionOf(StatusKind k) => switch (k) {
      StatusKind.burn =>
        'Stacks sin límite. Al inicio de su turno: 4% vida máx. por stack '
            '(máx 8 por stack). Luego los stacks se reducen a la mitad.',
      StatusKind.poison =>
        'Stacks sin límite. Al inicio de su turno: 3% vida máx. por stack '
            '(máx 5 por stack). Pierde 1 stack por turno.',
      StatusKind.freeze ||
      StatusKind.wet ||
      StatusKind.charged =>
        elementalStatusDescription(k)!,
      StatusKind.stun => 'Pierde su próximo turno.',
      StatusKind.holy =>
        '5 de daño por stack al inicio de su turno, dura 3 turnos (se renueva '
            'al aplicar).',
      StatusKind.regen =>
        'Recupera 5% de vida y maná máx. al inicio de su turno (3 turnos).',
    };

/// Color del MP (azul) y del Pulso (dorado) en los costos.
const kMpHex = '#74b9ff';

/// Mismo dorado que la fila PULSO de la tarjeta (`ProtoColors.gold`).
const kPulseHex = '#ffd166';

/// Celeste propio de las Instante.
const kInstantHex = '#9fe8ff';

/// Separador de las Instante en ARMA (debajo de Atacar y Defender).
const kInstantSeparator = 'Instante — no terminan tu turno';

/// Marca de las Instante en el menú: INSTANTE en celeste.
String instantTagMarkup() => hexSpan(kInstantHex,
    '[${CatalogText.of('ui.combat.tag.instant', 'INSTANTE')}]');

/// Costo de una habilidad para la fila del menú (combat_tutorial.md § 3,
/// pedido del dueño v0.9.6): el Pulso se ve igual que el MP pero en
/// dorado, "4 MP", "P2" o "3 MP  P2".
String skillCostMarkup(SkillDef sk) => [
      if (sk.mp > 0 || sk.pulse == 0) hexSpan(kMpHex, '${sk.mp} MP'),
      if (sk.pulse > 0) hexSpan(kPulseHex, 'P${sk.pulse}'),
    ].join('  ');

/// Costo en el detalle/tooltip: "3 MP · 2 Pulso".
String skillCostLongMarkup(SkillDef sk) => [
      if (sk.mp > 0 || sk.pulse == 0) hexSpan(kMpHex, '${sk.mp} MP'),
      if (sk.pulse > 0) hexSpan(kPulseHex, '${sk.pulse} Pulso'),
    ].join(' · ');

/// `<span style="color:#hex">texto</span>`.
String hexSpan(String hex, String text) =>
    '<span style="color:$hex">$text</span>';

/// Nombre del estado en su color.
String statusNameMarkup(StatusKind k) => hexSpan(statusHex(k), k.tr);

/// Letra + stacks del estado en su color (`icon+n` del prototipo).
String statusBadgeMarkup(StatusKind k, int n) =>
    hexSpan(statusHex(k), '${statusLetterOf(k)}$n');

/// `stDesc(st, stc, bonus)`: "Aplica +N Estado (desc)" o "P% de aplicar
/// N Estado (desc)", con el nombre en el color del estado.
String statusApplicationMarkup(StatusApplication? st, {int bonus = 0}) {
  if (st == null) return '';
  if (TextDetail.isSummary) return statusApplicationShort(st, bonus: bonus);
  final head = st.chance != null
      ? '${jsRound(st.chance! * 100)}% de aplicar '
      : 'Aplica +';
  return '$head${st.stacks + bonus} ${statusNameMarkup(st.kind)} '
      '(${statusDescriptionOf(st.kind)})';
}

/// `descSkill(tk, p, isUlt)`: líneas en markup unidas con `<br>`. Con
/// [user] muestra los números calculados en `<b>`. [nameColor] pinta el
/// nombre (el `weaponTip` pinta la ULT de `#e84393`).
///
/// Con [element] (por defecto) suma la línea del elemento y sus
/// reacciones (elemental_reactions.md § 3) si no es Físico.
/// "Crítico 18%: 245" con la probabilidad efectiva de [p] (base +
/// [bonus] de la técnica, tope 100 %) y el daño [v] por golpe × su
/// multiplicador. Con [hits] > 1 suma el total; con [all], "c/u".
String critLineMarkup(Combatant p, num v,
    {double bonus = 0, int hits = 1, bool all = false}) {
  final pct = jsRound(((p.critChance + bonus).clamp(0.0, 1.0)) * 100);
  final c = jsRound(v * p.critMultiplier);
  return hexSpan(
      '#7d8bc4',
      'Crítico $pct%: $c${all ? ' c/u' : ''}'
          '${hits > 1 ? ' por golpe · ${c * hits} en total' : ''}');
}

String describeSkillMarkup(SkillDef tk, Combatant? user,
    {bool ultimate = false, String? nameColor, bool element = true}) {
  final p = user;
  final el = elementOf(tk.id);
  final l = <String>[
    '<b${nameColor == null ? '' : ' style="color:$nameColor"'}>'
        '${ultimate ? '★ ULTIMATE: ' : ''}${tk.tr}</b> '
        '${ultimate ? '<span class="k">(barra ULT llena)</span>' : skillCostLongMarkup(tk)}',
    if (element && el != GameElement.fisico) elementReactionMarkup(el),
  ];
  // RESUMIDO (ui_minimal.md § 8): la cabecera y una o dos líneas
  // cortas generadas de los datos; el elemento va solo en DETALLADO.
  if (TextDetail.isSummary) {
    return [l.first, ...skillShortLines(tk, p)].join('<br>');
  }
  final mag = tk.kind == SkillKind.magical;
  switch (tk.kind) {
    case SkillKind.physical || SkillKind.magical when tk.charge > 0:
      final v = p?.attack ?? 0;
      l.add('${hexSpan('#ff9f43', 'Disparo cargado')}: no pega ahora. Al '
          'empezar tu próximo turno cae ATQ × ${fm(tk.charge)}'
          '${p != null ? ' = <b>${jsRound(v * tk.charge)}</b>' : ''} sobre el '
          'objetivo (si cayó, sobre el primer enemigo en pie)'
          '${p != null ? ' · ${critLineMarkup(p, v * tk.charge, bonus: tk.critBonus)}' : ''}');
      final st = tk.status;
      if (st != null) {
        l.add(statusApplicationMarkup(st, bonus: p?.statusBonus[st.kind] ?? 0));
      }
    case SkillKind.physical || SkillKind.magical:
      final v = p == null ? 0 : (mag ? p.magic : p.attack);
      l.add('Daño ${mag ? 'mágico' : 'físico'}: ${mag ? 'MAG' : 'ATQ'} × '
          '${fm(tk.power)}${p != null ? ' = <b>${jsRound(v * tk.power)}</b>' : ''}'
          '${tk.allTargets ? ' a TODOS los enemigos' : ' a 1 enemigo'}'
          '${tk.hits > 1 ? ', <b>${tk.hits} golpes</b> seguidos' : ''}'
          '${p != null ? ' · ${critLineMarkup(p, v * tk.power, bonus: tk.critBonus, hits: tk.hits, all: tk.allTargets)}' : ''}');
      if (tk.pierce > 0) {
        l.add('${hexSpan('#dfe6e9', 'Atraviesa')}: también golpea a los '
            'enemigos detrás del objetivo con el ${jsRound(tk.pierce * 100)}% '
            'del daño');
      }
      if (tk.bounces > 0) {
        l.add('${hexSpan('#fdcb6e', 'Rebota')} ${tk.bounces} '
            '${tk.bounces == 1 ? 'vez' : 'veces'} a otro enemigo al azar '
            '(−30% por rebote; solo hay uno: vuelve a él)');
      }
      if (tk.critBonus > 0) {
        l.add('+${jsRound(tk.critBonus * 100)}% de probabilidad de crítico');
      }
      if (tk.delay > 0) {
        l.add('⏳ Retrasa al objetivo ${jsRound(tk.delay * 100)}% de un '
            'turno en la línea de tiempo');
      }
      final st = tk.status;
      if (st != null) {
        l.add(statusApplicationMarkup(st, bonus: p?.statusBonus[st.kind] ?? 0));
      }
    case SkillKind.heal:
      if (tk.revive > 0) l.addAll(reviveLinesMarkup(tk, p));
      l.add('Cura MAG × ${fm(tk.power)} + 6'
          '${p != null ? ' = <b>${jsRound(p.magic * tk.power + 6)}</b>' : ''} '
          '${tk.lowestAlly ? 'al aliado más herido' : 'a cada aliado'}'
          '${tk.cleanse <= 0 ? '' : tk.cleanse >= 5 ? ' y quita todos los estados' : ' y quita 1 stack de cada estado'}');
    case SkillKind.regen:
      l.add('Cura MAG × ${fm(tk.power)} + 4'
          '${p != null ? ' = <b>${jsRound(p.magic * tk.power + 4)}</b>' : ''} '
          '${tk.lowestAlly ? 'al aliado más herido' : 'a cada aliado'} '
          'y ${tk.lowestAlly ? 'le' : 'les'} da Regeneración: 5% de vida y '
          'maná máx. al inicio de su turno, 3 turnos');
    case SkillKind.haste:
      l.add('Adelanta el próximo turno de tus aliados 50% de un turno');
    case SkillKind.defenseUp:
      l.add('+${tk.amount} DEF durante el combate (cada punto = −3% de daño '
          'recibido, máx −60%)');
    case SkillKind.protect:
      l.add('Hasta tu próximo turno, TODO el daño dirigido a tus aliados lo '
          'recibes tú');
    case SkillKind.bulwark:
      l.add('Cura 30% de vida a todos, todos defienden (½ daño), activas '
          'Protección y +4 DEF');
    case SkillKind.taunt:
      l.add('Los próximos ${tk.amount} ataques enemigos van contra ti');
    case SkillKind.guard:
      l.add('Todo el equipo recibe ½ daño hasta su próximo turno');
    case SkillKind.support:
      // Invocador (summoner.md § 8).
      l.addAll(summonSkillLines(tk, p));
      break;
  }
  l.addAll(kitEffectLines(tk));
  return l.join('<br>');
}

/// Las líneas de los efectos del kit de ascensión (ascension.md § 4).
List<String> kitEffectLines(SkillDef tk) {
  String pct(double v) => '${jsRound(v * 100)}%';
  return [
    if (tk.hpCost > 0)
      hexSpan('#ff4757', 'Cuesta ${pct(tk.hpCost)} de tu vida máx.'),
    for (final x in tk.extraStatuses) statusApplicationMarkup(x),
    if (tk.detonate > 0)
      '+${pct(tk.detonate)} de daño por cada stack de Quemadura, '
          'Congelación y Veneno del objetivo (los consume)',
    if (tk.catalyst > 0)
      'Catalizador: detona lo que tenga el objetivo (Mojado, Veneno, '
          'Congelación o Cargado) con el elemento justo y hace '
          '×${fm(1 + tk.catalyst)} si reacciona',
    if (tk.execute > 0)
      'Remata (no jefes ni élites) si queda con menos de ${pct(tk.execute)} '
          'de vida',
    if (tk.lifeSteal > 0) 'Roba ${pct(tk.lifeSteal)} del daño que hace',
    if (tk.trap > 0)
      'Deja una trampa de ATQ × ${fm(tk.trap)} en '
          '${tk.allTargets ? 'cada enemigo' : 'el objetivo'}: salta al '
          'empezar su turno',
    for (final b in tk.partyBuffs)
      'Grupo: ${b.value < 0 ? '−' : '+'}${pct(b.value.abs())} ${b.stat.label} '
          '(${b.turns} turno${b.turns == 1 ? '' : 's'})',
    if (tk.partyShield > 0)
      'Escudo del ${pct(tk.partyShield)} de tu vida máx. a cada aliado '
          '(${tk.partyShieldTurns} turnos)',
    if (tk.advanceAllies > 0)
      'Adelanta a tus aliados ${pct(tk.advanceAllies)} de su espera (solo: '
          'a vos)',
    if (tk.selfBuff case final b?)
      '+${pct(b.value)} ${b.stat.label} (${b.turns} turno${b.turns == 1 ? '' : 's'})',
    if (tk.selfTurn < 1) 'Tu próximo turno llega ${pct(1 - tk.selfTurn)} antes',
    if (tk.protect) 'Protección: recibís el daño dirigido a tus aliados',
    ...variantEffectLines(tk),
  ];
}

/// Las líneas de las variantes de habilidades (combat.md § "Variantes de
/// habilidades"), con el color de su familia.
List<String> variantEffectLines(SkillDef tk) {
  String pct(double v) => '${jsRound(v * 100)}%';
  String t(int n) => '$n turno${n == 1 ? '' : 's'}';
  const heal = '#7bed9f', shield = '#ffeaa7', debuff = '#ff6b81';
  return [
    if (tk.overheal > 0)
      hexSpan(
          heal,
          'Desborde: ${pct(tk.overheal)} de la cura que sobra '
          '(vida llena) se vuelve escudo (${t(tk.shieldTurns)})'),
    if (tk.drainHeal > 0)
      hexSpan(
          heal,
          'Drena: ${pct(tk.drainHeal)} del daño cura al aliado '
          'más herido'),
    if (tk.allyShield > 0)
      hexSpan(
          shield,
          'Escudo del ${pct(tk.allyShield)} de tu vida máx. al '
          'aliado más herido (${t(tk.shieldTurns)})'),
    if (tk.selfShield > 0)
      hexSpan(
          shield,
          'Escudo del ${pct(tk.selfShield)} de tu vida máx. '
          'para vos (${t(tk.shieldTurns)})'),
    if (tk.shieldReflect > 0)
      hexSpan(
          shield,
          'Espinoso: el escudo devuelve ${pct(tk.shieldReflect)} '
          'de lo que absorbe al enemigo que pega'),
    if (tk.shieldBurst > 0)
      hexSpan(
          shield,
          'Volátil: al romperse explota, ATQ × '
          '${fm(tk.shieldBurst)} a todos los enemigos'),
    if (tk.shieldGrow > 0)
      hexSpan(
          shield,
          'Creciente: cada golpe que para lo agranda '
          '${pct(tk.shieldGrow)} de lo absorbido (máx. 50% de la vida)'),
    for (final d in tk.debuffs)
      hexSpan(
          debuff,
          switch (d.stat) {
            BuffStat.damageTaken =>
              'Marca: recibe +${pct(d.value)} de daño de todos (${t(d.turns)})',
            BuffStat.attack =>
              'Debilita: −${pct(d.value.abs())} de ataque (${t(d.turns)})',
            BuffStat.speed =>
              'Lentitud: −${pct(d.value.abs())} de velocidad (${t(d.turns)})',
            _ => '${d.stat.label} ${pct(d.value)} (${t(d.turns)})',
          }),
    if (tk.breakBonus > 0)
      hexSpan(
          '#ffe14d', 'Quiebre: +${pct(tk.breakBonus)} de puntos de quiebre'),
    if (tk.pureBreak)
      hexSpan(
          '#ffe14d',
          'Quebrar: no hace daño; quiebra a un enemigo '
              'FISURADO (barra llena). Se puede reemplazar por fusión')
    else if (tk.breaks)
      hexSpan(
          '#ffe14d',
          'Puede quebrar: si el objetivo está FISURADO, lo '
              'quiebra; si no, pega normal'),
    // Pulso, Instante y precondiciones (combo_balance.md § 5.2).
    if (tk.pulse > 0)
      hexSpan(
          '#ffb142',
          'Cuesta ${tk.pulse} de Pulso (+1 al empezar tu '
              'turno, por ataque básico, por golpe a una debilidad o reacción y '
              'al defender; máx. 5)'),
    if (tk.instant)
      hexSpan(
          '#9fe8ff',
          'Instante: no termina el turno; después podés hacer '
              'una acción más (una Instante por turno)'),
    if (tk.requires.isNotEmpty)
      hexSpan('#ff9f43',
          needsLine(tk.requires.map((r) => r.tr).join(' · '))),
    if (tk.ultDrain > 0)
      hexSpan(
          '#a29bfe',
          'Silencio: le quita ${jsRound(tk.ultDrain)} de '
              'carga de ULT'),
  ];
}

/// Etiqueta corta de una variante para la fila del menú de batalla
/// (vacía si la habilidad no es una variante).
String variantTagMarkup(SkillDef tk) {
  final tags = <String>[
    if (tk.revive > 0) hexSpan('#ffd166', 'revive'),
    if (tk.lowestAlly) hexSpan('#7bed9f', 'al más herido'),
    if (tk.overheal > 0) hexSpan('#ffeaa7', 'sobra→escudo'),
    if (tk.drainHeal > 0) hexSpan('#7bed9f', 'drena'),
    if (tk.allyShield > 0 || tk.selfShield > 0) hexSpan('#ffeaa7', 'escudo'),
    if (tk.shieldReflect > 0) hexSpan('#ffeaa7', 'refleja'),
    if (tk.shieldBurst > 0) hexSpan('#ffeaa7', 'explota'),
    if (tk.shieldGrow > 0) hexSpan('#ffeaa7', 'crece'),
    if (tk.charge > 0) hexSpan('#ff9f43', 'carga 1 turno'),
    if (tk.hits > 1) hexSpan('#fdcb6e', '×${tk.hits}'),
    if (tk.pierce > 0) hexSpan('#dfe6e9', 'atraviesa'),
    if (tk.bounces > 0) hexSpan('#fdcb6e', 'rebota ×${tk.bounces}'),
    for (final d in tk.debuffs)
      hexSpan(
          '#ff6b81',
          switch (d.stat) {
            BuffStat.damageTaken => 'marca',
            BuffStat.attack => '▼ATQ',
            BuffStat.speed => '▼VEL',
            _ => d.stat.label,
          }),
    if (tk.breakBonus > 0) hexSpan('#ffe14d', 'quiebre+'),
    if (tk.pureBreak)
      hexSpan('#ffe14d', 'quebrar')
    else if (tk.breaks)
      hexSpan('#ffe14d', 'puede quebrar'),
    if (tk.ultDrain > 0) hexSpan('#a29bfe', 'silencio'),
  ];
  return tags.isEmpty ? '' : ' ${tags.join(' ')}';
}

/// A quién afecta una habilidad (etiqueta corta del menú de batalla).
enum SkillReach {
  oneFoe('1 enemigo', '#ff6b81'),
  allFoes('TODOS', '#ff9f43'),
  ally('aliado', '#7bed9f'),
  party('grupo', '#7bed9f'),
  self('vos', '#9fb4ff');

  const SkillReach(this.label, this.hex);
  final String label;
  final String hex;

  /// Si apunta a enemigos (se resaltan en la escena).
  bool get foes => this == oneFoe || this == allFoes;

  String get _key => switch (this) {
        oneFoe => 'one_foe',
        allFoes => 'all_foes',
        ally => 'ally',
        party => 'party',
        self => 'self',
      };

  /// [label] en el idioma activo (docs/specs/i18n.md § 3.8).
  String get tr => CatalogText.of('ui.combat.reach.$_key', label);

  /// "A 1 enemigo", "A TODOS"... (resumen del detalle).
  String get toTr => CatalogText.of(
      'ui.combat.reach.to.$_key',
      switch (this) {
        oneFoe => 'A 1 enemigo',
        allFoes => 'A TODOS',
        ally => 'A un aliado',
        party => 'Al grupo',
        self => 'A vos',
      });
}

/// El objetivo real de [sk] según su tipo, `allTargets` y sus efectos.
SkillReach skillReach(SkillDef sk) {
  final foe = sk.allTargets ? SkillReach.allFoes : SkillReach.oneFoe;
  switch (sk.kind) {
    case SkillKind.physical || SkillKind.magical:
      return foe;
    case SkillKind.heal || SkillKind.regen:
      return sk.lowestAlly ? SkillReach.ally : SkillReach.party;
    case SkillKind.haste || SkillKind.guard || SkillKind.protect:
      return SkillReach.party;
    case SkillKind.taunt || SkillKind.bulwark:
      return SkillReach.self;
    case SkillKind.defenseUp:
      return sk.partyShield > 0 ? SkillReach.party : SkillReach.self;
    case SkillKind.support:
      if (sk.debuffs.isNotEmpty || sk.power > 0) return foe;
      if (sk.lowestAlly || sk.allyShield > 0) return SkillReach.ally;
      if (sk.partyBuffs.isNotEmpty ||
          sk.partyShield > 0 ||
          sk.advanceAllies > 0) {
        return SkillReach.party;
      }
      return SkillReach.self;
  }
}

/// Etiqueta del objetivo en su color: `[1 enemigo]`, `[TODOS]`...
String skillReachMarkup(SkillDef sk) {
  final r = skillReach(sk);
  return hexSpan(r.hex, '[${r.tr}]');
}

/// Resumen de una línea, arriba del detalle: "A TODOS · Fuego · 32 c/u ·
/// +2 Quemadura".
String skillSummaryMarkup(SkillDef sk, Combatant p) {
  final r = skillReach(sk);
  final dmg = sk.kind == SkillKind.physical || sk.kind == SkillKind.magical;
  final v = sk.charge > 0
      ? p.attack * sk.charge
      : (sk.kind == SkillKind.magical ? p.magic : p.attack) * sk.power;
  final st = sk.status;
  return [
    hexSpan(
        r.hex,
        r.toTr),
    if (dmg) elementOf(sk.id).tr,
    if (dmg) hexSpan('#ffd166', '${jsRound(v)}${sk.allTargets ? ' c/u' : ''}'),
    if (st != null)
      hexSpan(statusHex(st.kind),
          '${st.chance != null ? '${jsRound(st.chance! * 100)}%' : '+${st.stacks}'} ${st.kind.tr}'),
  ].join(' · ');
}

/// Líneas de revivir con la sinergia del árbol (combat.md § Revivir):
/// con [p] muestra los números del lanzador; sin él, la regla.
List<String> reviveLinesMarkup(SkillDef tk, Combatant? p) {
  String pct(double v) => '${(v * 1000).round() / 10}%';
  final base = '${hexSpan('#ffd166', 'Revive')} al primer aliado caído';
  final tail = '${tk.cleanse > 0 ? ' y sin estados' : ''}. Si no hay caídos:';
  if (p == null) {
    return [
      '$base con el ${pct(tk.revive)} de su vida máx.$tail',
      '${hexSpan('#ffd166', 'Sinergia')}: +${pct(ReviveRules.espPer)} de '
          'vida por punto de ESP y + Curación × ${ReviveRules.healScale} '
          '(tope 100%). La Curación además le da el Velo del Retorno: '
          'escudo de Curación × ${ReviveRules.shieldScale} de su vida '
          '(tope ${pct(ReviveRules.shieldCap)}, '
          '${ReviveRules.shieldTurns} turnos).',
    ];
  }
  final frac = ReviveRules.lifeFor(p, tk.revive);
  final sf = ReviveRules.shieldFraction(p.healBonus);
  return [
    '$base con el ${hexSpan('#7bed9f', pct(frac))} de su vida máx. '
        '(base ${pct(tk.revive)} + ESP ${ReviveRules.espOf(p)} + Curación '
        '${pct(p.healBonus)})$tail',
    sf > 0
        ? '${hexSpan('#ffd166', 'Velo del Retorno')}: escudo del '
            '${pct(sf)} de su vida por ${ReviveRules.shieldTurns} turnos.'
        : '${hexSpan('#ffd166', 'Velo del Retorno')}: sin Curación del '
            'árbol no hay escudo.',
  ];
}

extension SkillReqText on SkillReq {
  /// [SkillReq.label] in the active language (`ui.build.req.*`).
  String get tr => CatalogText.of(
      'ui.build.req.${kind.name}',
      label,
      {
        'n': amount,
        'status': status?.tr ?? '',
        'pct': (fraction * 100).round(),
      });
}

/// "Necesita: [list]" in the active language.
String needsLine(String list) =>
    CatalogText.of('ui.build.needs', 'Necesita: $list', {'list': list});

/// The condition lines of [SkillRequirements.missingLines] in the active
/// language: `Falta: 3 MP (tenés 1)`, `Necesita: objetivo Fisurado`...
/// [needs] are only the `Necesita` ones (the special conditions).
({List<String> all, List<String> needs}) localMissingLines(
    SkillDef sk, Combatant user, Combatant? target,
    {Iterable<Combatant> foes = const []}) {
  final needs = [
    for (final r in sk.requires)
      if (!SkillRequirements.met(r, sk, user, target, foes)) needsLine(r.tr),
  ];
  return (
    all: [
      if (SkillRequirements.silencedFor(sk, user))
        CatalogText.of('ui.combat.missing.silenced', 'Silenciado'),
      if (user.mp < sk.mp)
        CatalogText.of('ui.combat.missing.mp',
            'Falta: ${sk.mp} MP (tenés ${user.mp})', {'n': sk.mp, 'have': user.mp}),
      if (user.pulse < sk.pulse)
        CatalogText.of(
            'ui.combat.missing.pulse',
            'Falta: Pulso ${sk.pulse} (tenés ${user.pulse})',
            {'n': sk.pulse, 'have': user.pulse}),
      ...needs,
    ],
    needs: needs,
  );
}
