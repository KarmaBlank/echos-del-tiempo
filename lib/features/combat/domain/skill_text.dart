import '../../../game_engine/models/battle_state.dart';
import '../../../game_engine/models/skill.dart';
import '../../../game_engine/models/status.dart';
import '../../../game_engine/rules/js_math.dart';

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
    };

/// `STATUS[k].desc`.
String statusDescriptionOf(StatusKind k) => switch (k) {
      StatusKind.burn =>
        'Stacks sin límite. Al inicio de su turno: 4% vida máx. por stack '
            '(máx 8 por stack). Luego los stacks se reducen a la mitad.',
      StatusKind.poison =>
        'Stacks sin límite. Al inicio de su turno: 3% vida máx. por stack '
            '(máx 5 por stack). Pierde 1 stack por turno.',
      StatusKind.freeze =>
        '-12% velocidad por stack. Con 5 stacks: CONGELADO, pierde su turno '
            'y se descongela. Pierde 1 stack por turno.',
      StatusKind.stun => 'Pierde su próximo turno.',
      StatusKind.holy =>
        '5 de daño por stack al inicio de su turno, dura 3 turnos (se renueva '
            'al aplicar).',
      StatusKind.regen =>
        'Recupera 5% de vida y maná máx. al inicio de su turno (3 turnos).',
    };

/// `<span style="color:#hex">texto</span>`.
String hexSpan(String hex, String text) =>
    '<span style="color:$hex">$text</span>';

/// Nombre del estado en su color.
String statusNameMarkup(StatusKind k) => hexSpan(statusHex(k), k.label);

/// Letra + stacks del estado en su color (`icon+n` del prototipo).
String statusBadgeMarkup(StatusKind k, int n) =>
    hexSpan(statusHex(k), '${statusLetterOf(k)}$n');

/// `stDesc(st, stc, bonus)`: "Aplica +N Estado (desc)" o "P% de aplicar
/// N Estado (desc)", con el nombre en el color del estado.
String statusApplicationMarkup(StatusApplication? st, {int bonus = 0}) {
  if (st == null) return '';
  final head = st.chance != null
      ? '${jsRound(st.chance! * 100)}% de aplicar '
      : 'Aplica +';
  return '$head${st.stacks + bonus} ${statusNameMarkup(st.kind)} '
      '(${statusDescriptionOf(st.kind)})';
}

/// `descSkill(tk, p, isUlt)`: líneas en markup unidas con `<br>`. Con
/// [user] muestra los números calculados en `<b>`. [nameColor] pinta el
/// nombre (el `weaponTip` pinta la ULT de `#e84393`).
String describeSkillMarkup(SkillDef tk, Combatant? user,
    {bool ultimate = false, String? nameColor}) {
  final p = user;
  final l = <String>[
    '<b${nameColor == null ? '' : ' style="color:$nameColor"'}>'
        '${ultimate ? '★ ULTIMATE: ' : ''}${tk.name}</b> '
        '<span class="k">${ultimate ? '(barra ULT al 100%)' : '${tk.mp} MP'}</span>',
  ];
  final mag = tk.kind == SkillKind.magical;
  switch (tk.kind) {
    case SkillKind.physical || SkillKind.magical:
      final v = p == null ? 0 : (mag ? p.magic : p.attack);
      l.add('Daño ${mag ? 'mágico' : 'físico'}: ${mag ? 'MAG' : 'ATQ'} × '
          '${fm(tk.power)}${p != null ? ' = <b>${jsRound(v * tk.power)}</b>' : ''}'
          '${tk.allTargets ? ' a TODOS los enemigos' : ' a 1 enemigo'}'
          '${p != null ? ' (crítico ${jsRound(v * tk.power * p.critMultiplier)})' : ''}');
      if (tk.critBonus > 0) {
        l.add('+${jsRound(tk.critBonus * 100)}% de probabilidad de crítico');
      }
      if (tk.delay > 0) {
        l.add('⏳ Retrasa al objetivo ${jsRound(tk.delay * 100)}% de un '
            'turno en la línea de tiempo');
      }
      final st = tk.status;
      if (st != null) {
        l.add(statusApplicationMarkup(st,
            bonus: p?.statusBonus[st.kind] ?? 0));
      }
    case SkillKind.heal:
      l.add('Cura MAG × ${fm(tk.power)} + 6'
          '${p != null ? ' = <b>${jsRound(p.magic * tk.power + 6)}</b>' : ''} a cada aliado'
          '${tk.cleanse <= 0 ? '' : tk.cleanse >= 5 ? ' y quita todos los estados' : ' y quita 1 stack de cada estado'}');
    case SkillKind.regen:
      l.add('Cura MAG × ${fm(tk.power)} + 4'
          '${p != null ? ' = <b>${jsRound(p.magic * tk.power + 4)}</b>' : ''} a cada aliado '
          'y les da Regeneración: 5% de vida y maná máx. al inicio de su '
          'turno, 3 turnos');
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
      break;
  }
  l.addAll(kitEffectLines(tk));
  return l.join('<br>');
}

/// Las líneas de los efectos del kit de ascensión (ascension.md § 4).
List<String> kitEffectLines(SkillDef tk) {
  String pct(double v) => '${jsRound(v * 100)}%';
  return [
    if (tk.hpCost > 0) hexSpan('#ff4757', 'Cuesta ${pct(tk.hpCost)} de tu vida máx.'),
    for (final x in tk.extraStatuses) statusApplicationMarkup(x),
    if (tk.detonate > 0)
      '+${pct(tk.detonate)} de daño por cada stack de Quemadura, '
          'Congelación y Veneno del objetivo (los consume)',
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
    if (tk.selfTurn < 1)
      'Tu próximo turno llega ${pct(1 - tk.selfTurn)} antes',
    if (tk.protect) 'Protección: recibís el daño dirigido a tus aliados',
  ];
}
