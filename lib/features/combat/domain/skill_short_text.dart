import '../../../core/text/plain_text.dart';
import '../../../game_engine/data/summoner_catalog.dart';
import '../../../game_engine/models/battle_state.dart';
import '../../../game_engine/models/passive_mechanic.dart' show BuffStat;
import '../../../game_engine/models/skill.dart';
import '../../../game_engine/models/status.dart';
import '../../../game_engine/rules/js_math.dart';
import 'skill_text.dart';
import 'summon_text.dart';

/// Textos RESUMIDOS de habilidades, ULT y estados (ui_minimal.md § 8):
/// salen de los datos de la habilidad (efecto + valor principal), no de
/// textos escritos a mano uno por uno. Dart puro.

String _pct(double v) => '${jsRound(v * 100)}%';
String _turns(int n) => '$n turno${n == 1 ? '' : 's'}';

/// Una línea por estado: qué hace, en palabras simples.
String statusShortOf(StatusKind k) => switch (k) {
      StatusKind.burn => 'Pierde vida al empezar cada turno.',
      StatusKind.poison => 'Pierde un poco de vida cada turno.',
      StatusKind.freeze => 'Lo frena; con 5 capas queda congelado.',
      StatusKind.stun => 'Pierde su próximo turno.',
      StatusKind.holy => 'Recibe daño de luz cada turno, 3 turnos.',
      StatusKind.regen => 'Recupera vida y maná cada turno, 3 turnos.',
      StatusKind.wet => 'Sin daño; Electro o Hielo lo detonan.',
      StatusKind.charged => 'Sin daño; Agua lo detona.',
    };

/// "Aplica 2 de Quemadura" / "40% de aplicar Veneno" (sin la regla).
String statusApplicationShort(StatusApplication st, {int bonus = 0}) => st
            .chance !=
        null
    ? '${jsRound(st.chance! * 100)}% de aplicar ${statusNameMarkup(st.kind)}'
    : 'Aplica ${st.stacks + bonus} de ${statusNameMarkup(st.kind)}';

/// Línea principal: qué hace la habilidad con su número principal.
String skillMainShort(SkillDef tk, Combatant? p) {
  final mag = tk.kind == SkillKind.magical;
  String dmg(double mult, {bool magic = false}) {
    if (p == null) {
      return '${_pct(mult)} de tu ${magic ? 'magia' : 'ataque'}';
    }
    return '<b>${jsRound((magic ? p.magic : p.attack) * mult)}</b> de daño';
  }

  String heal(double mult, int flat) => p == null
      ? 'según tu magia'
      : '<b>${jsRound(p.magic * mult + flat)}</b> de vida';
  final whoFoe = tk.allTargets ? 'a todos los enemigos' : 'a 1 enemigo';
  final whoAlly = tk.lowestAlly ? 'al aliado más herido' : 'al grupo';
  switch (tk.kind) {
    case SkillKind.physical || SkillKind.magical when tk.charge > 0:
      return 'Carga y pega en tu próximo turno: ${dmg(tk.charge)}.';
    case SkillKind.physical || SkillKind.magical:
      return 'Pega ${dmg(tk.power, magic: mag)} $whoFoe'
          '${tk.hits > 1 ? ', ${tk.hits} golpes' : ''}.';
    case SkillKind.heal:
      if (tk.revive > 0) {
        return 'Revive a un aliado caído con ${_pct(tk.revive)} de vida.';
      }
      return 'Cura ${heal(tk.power, 6)} $whoAlly'
          '${tk.cleanse > 0 ? ' y quita estados' : ''}.';
    case SkillKind.regen:
      return 'Cura ${heal(tk.power, 4)} $whoAlly y regenera 3 turnos.';
    case SkillKind.haste:
      return 'Adelanta el próximo turno de tus aliados.';
    case SkillKind.defenseUp:
      return 'Suma ${tk.amount} de defensa en este combate.';
    case SkillKind.protect:
      return 'Recibís el daño dirigido a tus aliados.';
    case SkillKind.bulwark:
      return 'Cura 30% de vida al grupo y lo protege.';
    case SkillKind.taunt:
      return 'Atrae los próximos ${tk.amount} ataques enemigos.';
    case SkillKind.guard:
      return 'Reduce a la mitad el daño al grupo.';
    case SkillKind.support:
      return _summonShort(tk, p);
  }
}

String _summonShort(SkillDef tk, Combatant? p) {
  final kind = kSummonSkillKind[tk.id];
  if (kind != null) {
    return 'Invoca un ${kSummons[kind]!.name} que pelea con vos.';
  }
  return switch (tk.id) {
    'sacrificio' => 'Sacrifica una invocación y daña a todos los enemigos.',
    'enjambre' => 'Invoca 2 elementales al azar.',
    'comandar' => 'Todas tus invocaciones actúan ya.',
    'ult_portal' => 'Invoca a los 4 elementales y atacan ya.',
    'ult_avatar' => 'Te fundís con tus invocaciones: más daño por un rato.',
    'ult_marea' => 'Invoca 3 aliados y da escudo al grupo.',
    _ => _supportShort(tk, p),
  };
}

/// Apoyo sin invocación: el primer efecto secundario hace de principal.
String _supportShort(SkillDef tk, Combatant? p) {
  final s = skillExtraShort(tk, p);
  if (s.isNotEmpty) return '${s.first}.';
  final lines = summonSkillLines(tk, p);
  return lines.isEmpty ? 'Ayuda al grupo.' : plainShort(lines.first);
}

/// Efectos secundarios, una frase corta cada uno (sin punto final).
List<String> skillExtraShort(SkillDef tk, Combatant? p) {
  final st = tk.status;
  return [
    if (st != null)
      statusApplicationShort(st, bonus: p?.statusBonus[st.kind] ?? 0),
    for (final x in tk.extraStatuses) statusApplicationShort(x),
    if (tk.hpCost > 0) 'Cuesta ${_pct(tk.hpCost)} de tu vida',
    if (tk.pierce > 0) 'Atraviesa a los de atrás',
    if (tk.bounces > 0)
      'Rebota ${tk.bounces} ${tk.bounces == 1 ? 'vez' : 'veces'}',
    if (tk.critBonus > 0) 'Más chance de crítico',
    if (tk.delay > 0) 'Retrasa al enemigo',
    if (tk.detonate > 0) 'Consume los estados del enemigo y pega más',
    if (tk.catalyst > 0) 'Detona los estados del enemigo',
    if (tk.execute > 0) 'Remata con menos de ${_pct(tk.execute)} de vida',
    if (tk.lifeSteal > 0) 'Te cura ${_pct(tk.lifeSteal)} del daño',
    if (tk.trap > 0) 'Deja una trampa',
    for (final b in tk.partyBuffs)
      '${b.value < 0 ? 'Baja' : 'Sube'} ${_pct(b.value.abs())} '
          '${_stat(b.stat)} del grupo',
    if (tk.partyShield > 0) 'Da escudo al grupo',
    if (tk.advanceAllies > 0) 'Adelanta a tus aliados',
    if (tk.selfBuff case final b?) 'Te sube ${_pct(b.value)} ${_stat(b.stat)}',
    if (tk.selfTurn < 1) 'Tu próximo turno llega antes',
    if (tk.protect) 'Recibís el daño de tus aliados',
    if (tk.overheal > 0) 'La cura que sobra se vuelve escudo',
    if (tk.drainHeal > 0) 'Parte del daño cura al aliado más herido',
    if (tk.allyShield > 0) 'Da escudo al aliado más herido',
    if (tk.selfShield > 0) 'Te da un escudo',
    if (tk.shieldReflect > 0) 'El escudo devuelve daño',
    if (tk.shieldBurst > 0) 'El escudo explota al romperse',
    if (tk.shieldGrow > 0) 'El escudo crece al parar golpes',
    for (final d in tk.debuffs)
      switch (d.stat) {
        BuffStat.damageTaken => 'Marca: recibe ${_pct(d.value)} más de daño',
        BuffStat.attack => 'Baja ${_pct(d.value.abs())} su ataque',
        BuffStat.speed => 'Baja ${_pct(d.value.abs())} su velocidad',
        _ => 'Lo debilita ${_turns(d.turns)}',
      },
    if (tk.breakBonus > 0) 'Llena más la barra de quiebre',
    if (tk.pureBreak)
      'Quiebra a un enemigo Fisurado'
    else if (tk.breaks)
      'Puede quebrar a un Fisurado',
    if (tk.pulse > 0) 'Usa ${tk.pulse} de Pulso',
    if (tk.instant) 'No termina tu turno',
    if (tk.requires.isNotEmpty)
      needsLine(tk.requires.map((r) => r.tr).join(', ')),
    if (tk.ultDrain > 0) 'Le baja la carga de ULT',
  ];
}

String _stat(BuffStat s) => switch (s) {
      BuffStat.attack => 'el ataque',
      BuffStat.speed => 'la velocidad',
      BuffStat.crit => 'el crítico',
      BuffStat.damage => 'el daño',
      BuffStat.guard => 'la defensa',
      _ => s.label,
    };

/// Las líneas RESUMIDAS (sin la cabecera): la principal y, si hay, una
/// segunda con hasta dos efectos secundarios.
List<String> skillShortLines(SkillDef tk, Combatant? p) {
  final main = skillMainShort(tk, p);
  final extra = skillExtraShort(tk, p);
  // El apoyo ya usó el primero como principal.
  final rest = tk.kind == SkillKind.support &&
          !kSummonSkillKind.containsKey(tk.id) &&
          extra.isNotEmpty &&
          main == '${extra.first}.'
      ? extra.skip(1).toList()
      : extra;
  return [
    main,
    if (rest.isNotEmpty) '${rest.take(2).join('. ')}.',
  ];
}
