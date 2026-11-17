import '../../../game_engine/models/battle_state.dart';
import '../../../game_engine/models/skill.dart';
import '../../../game_engine/models/status.dart';
import '../../../game_engine/rules/js_math.dart';
import 'scene/fx_style.dart';

/// `stDesc(st, stc, bonus)` del prototipo, en texto plano.
String statusApplicationText(StatusApplication? st, {int bonus = 0}) {
  if (st == null) return '';
  final head = st.chance != null
      ? '${jsRound(st.chance! * 100)}% de aplicar '
      : 'Aplica +';
  return '$head${st.stacks + bonus} ${st.kind.label} (${statusDescription(st.kind)})';
}

/// `descSkill(tk, p, isUlt)` del prototipo, en líneas de texto plano
/// (sin HTML). Con [user] muestra los números calculados.
List<String> describeSkill(SkillDef tk, Combatant? user, {bool ultimate = false}) {
  final l = <String>[
    '${ultimate ? '★ ULTIMATE: ' : ''}${tk.name} '
        '${ultimate ? '(barra ULT al 100%)' : '${tk.mp} MP'}',
  ];
  final p = user;
  final mag = tk.kind == SkillKind.magical;
  switch (tk.kind) {
    case SkillKind.physical || SkillKind.magical:
      final v = p == null ? 0 : (mag ? p.magic : p.attack);
      final dmg = jsRound(v * tk.power);
      l.add('Daño ${mag ? 'mágico' : 'físico'}: ${mag ? 'MAG' : 'ATQ'} × '
          '${fm(tk.power)}${p != null ? ' = $dmg' : ''}'
          '${tk.allTargets ? ' a TODOS los enemigos' : ' a 1 enemigo'}'
          '${p != null ? ' (crítico ${jsRound(v * tk.power * p.critMultiplier)})' : ''}');
      if (tk.critBonus > 0) {
        l.add('+${jsRound(tk.critBonus * 100)}% de probabilidad de crítico');
      }
      if (tk.delay > 0) {
        l.add('Retrasa al objetivo ${jsRound(tk.delay * 100)}% de un turno '
            'en la línea de tiempo');
      }
      final st = tk.status;
      if (st != null) {
        l.add(statusApplicationText(st,
            bonus: p?.statusBonus[st.kind] ?? 0));
      }
    case SkillKind.heal:
      l.add('Cura MAG × ${fm(tk.power)} + 6'
          '${p != null ? ' = ${jsRound(p.magic * tk.power + 6)}' : ''} a cada aliado'
          '${tk.cleanse <= 0 ? '' : tk.cleanse >= 5 ? ' y quita todos los estados' : ' y quita 1 stack de cada estado'}');
    case SkillKind.regen:
      l.add('Cura MAG × ${fm(tk.power)} + 4'
          '${p != null ? ' = ${jsRound(p.magic * tk.power + 4)}' : ''} a cada aliado '
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
  }
  return l;
}

