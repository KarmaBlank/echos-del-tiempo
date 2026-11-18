import '../../../game_engine/models/battle_state.dart';
import '../../../game_engine/models/player_state.dart';
import '../../../game_engine/models/skill.dart';
import '../../../game_engine/rules/js_math.dart';
import '../../combat/domain/skill_text.dart';

/// Ficha de una habilidad fuera de la batalla (fusión, forja, tienda,
/// inventario, ascensión, plan de build): el **mismo texto** que la
/// descripción del menú de batalla (`describeSkillMarkup`, con sus
/// variantes y efectos del kit) más una línea de tipo. Con [stats] (los
/// del jugador que mira) los números salen calculados (`= 31`). Ver
/// docs/specs/panels.md § "Ficha de habilidad (v0.5.1)".

/// `Físico` / `Mágico` / `Curación` / `Apoyo`.
String skillKindLabel(SkillDef s) => switch (s.kind) {
      SkillKind.physical => 'Físico',
      SkillKind.magical => 'Mágico',
      SkillKind.heal || SkillKind.regen => 'Curación',
      _ => 'Apoyo',
    };

/// A quién apunta (una palabra o dos).
String skillTargetLabel(SkillDef s) => switch (s.kind) {
      SkillKind.physical ||
      SkillKind.magical =>
        s.allTargets ? 'todos los enemigos' : '1 enemigo',
      SkillKind.heal ||
      SkillKind.regen =>
        s.lowestAlly ? 'el aliado más herido' : 'todo el grupo',
      SkillKind.taunt || SkillKind.protect => 'tú',
      _ => 'el grupo',
    };

/// Un combatiente "de mentira" con los stats de quien mira, para que
/// `describeSkillMarkup` calcule los números.
Combatant? tipUser(DerivedStats? s) => s == null
    ? null
    : Combatant(
        id: '_tip',
        name: '',
        isPlayer: true,
        hp: s.maxHp,
        maxHp: s.maxHp,
        mp: s.maxMp.toDouble(),
        maxMp: s.maxMp,
        speed: s.speed,
        attack: s.attack,
        magic: s.magic,
        critChance: s.critChance,
        critMultiplier: s.critMultiplier,
        defense: s.defense,
        statusBonus: s.statusBonus,
      );

/// Ficha completa (markup): la de batalla + `Tipo · Objetivo · Crítico`.
String skillTipMarkup(SkillDef s,
    {DerivedStats? stats, bool ultimate = false, String? note}) {
  final d = describeSkillMarkup(s, tipUser(stats),
      ultimate: ultimate, nameColor: ultimate ? '#e84393' : null);
  final i = d.indexOf('<br>');
  final head = i < 0 ? d : d.substring(0, i);
  final rest = i < 0 ? '' : d.substring(i);
  final crit = stats != null &&
          (s.kind == SkillKind.physical || s.kind == SkillKind.magical)
      ? ' · crítico ${jsRound(stats.critChance * 100 + s.critBonus * 100)}%'
      : '';
  return '$head<br><span class="k">${skillKindLabel(s)} · a '
      '${skillTargetLabel(s)}$crit</span>'
      '${note == null ? '' : '<br>$note'}$rest';
}

/// Una línea (para tooltips de objetos y listas): `Nombre (8 MP · Físico):
/// efecto · efecto`.
String skillOneLineMarkup(SkillDef s,
    {DerivedStats? stats, bool ultimate = false}) {
  final lines = describeSkillMarkup(s, tipUser(stats), ultimate: ultimate)
      .split('<br>')
      .skip(1)
      .toList();
  final name = ultimate
      ? '<b style="color:#e84393">ULT ${s.name}</b>'
      : '<b>${s.name}</b>';
  final cost = ultimate ? 'barra ULT' : '${s.mp} MP';
  return '$name <span class="k">($cost · ${skillKindLabel(s)})</span>'
      '${lines.isEmpty ? '' : ': ${lines.join(' · ')}'}';
}
