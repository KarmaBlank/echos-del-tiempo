import '../../../game_engine/data/game_catalog.dart';
import '../../../game_engine/models/attributes.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/models/skill.dart';
import '../../../game_engine/models/status.dart';
import '../../../game_engine/models/upgrade_stat.dart';
import '../../../game_engine/models/weapon.dart';
import '../../../game_engine/rules/progression_rules.dart';

/// Textos de armas y habilidades de los paneles — puerto de `reqHtml`,
/// `wPowTxt`, `skHtml` (líneas 1262-1266) y `stDesc`, `descSkill`,
/// `weaponTip` (1108-1131), sin HTML ni emojis. Ver docs/specs/panels.md.

/// `VIT`, `ESP`, `AGI`, `FUE`, `DES`.
String attributeShort(Attribute a) => a.name.toUpperCase();

/// Número sin `.0` sobrante (`fm` del prototipo).
String fmtNum(num v) {
  final r = (v * 100).roundToDouble() / 100;
  return r == r.roundToDouble() ? r.round().toString() : r.toString();
}

/// `reqHtml`: cada requisito y si [attributes] lo cumple.
List<({String text, bool ok})> requirementParts(
        WeaponDef w, PlayerAttributes attributes) =>
    [
      for (final e in w.requirements.entries)
        (
          text: '${attributeShort(e.key)} ${e.value}',
          ok: attributes[e.key] >= e.value,
        ),
    ];

/// `wPowTxt`: letra de escala por atributo de la fórmula de poder.
String weaponScaleText(WeaponDef w) {
  final f = w.mag ?? w.atk;
  return f.coefficients.entries.map((e) {
    final c = e.value;
    final grade = c >= 0.8
        ? 'A'
        : c >= 0.6
            ? 'B'
            : c >= 0.4
                ? 'C'
                : 'D';
    return '${attributeShort(e.key)} $grade';
  }).join(' ');
}

/// `skHtml`: habilidades del arma (+ la fusionada), su ULT y el escudo.
String skillListText(GameCatalog catalog, WeaponDef w, {String? fusedId}) {
  final ids = [...w.skillIds];
  if (fusedId != null && !ids.contains(fusedId)) ids.add(fusedId);
  final names = ids.map((id) {
    final s = catalog.skills[id];
    if (s == null) return id;
    return '${s.name}'
        '${s.delay > 0 ? ' (retrasa)' : ''}'
        '${s.status != null ? ' ${s.status!.kind.label}' : ''}'
        '${id == fusedId ? ' (fusión)' : ''}';
  }).join(' · ');
  final ult = catalog.ultimates[w.type]?.name ?? '-';
  return '${names.isEmpty ? '-' : names} · ULT: $ult'
      '${w.shieldDefense > 0 ? ' · DEF +${w.shieldDefense}' : ''}';
}

/// `stDesc`: "Aplica +N Estado" o "P% de aplicar N Estado".
String statusText(StatusApplication st) => st.chance != null
    ? '${(st.chance! * 100).round()}% de aplicar ${st.stacks} ${st.kind.label}'
    : 'Aplica +${st.stacks} ${st.kind.label}';

/// `descSkill(tk, null)`: qué hace una habilidad (o la ULT).
List<String> skillDescription(SkillDef tk, {bool ult = false}) {
  final l = <String>[
    '${ult ? '* ULTIMATE: ' : ''}${tk.name} '
        '(${ult ? 'barra ULT al 100%' : '${tk.mp} MP'})',
  ];
  switch (tk.kind) {
    case SkillKind.physical || SkillKind.magical:
      final mag = tk.kind == SkillKind.magical;
      l.add('Daño ${mag ? 'mágico' : 'físico'}: ${mag ? 'MAG' : 'ATQ'} × '
          '${fmtNum(tk.power)}'
          '${tk.allTargets ? ' a TODOS los enemigos' : ' a 1 enemigo'}');
      if (tk.critBonus > 0) {
        l.add('+${(tk.critBonus * 100).round()}% de probabilidad de crítico');
      }
      if (tk.delay > 0) {
        l.add('Retrasa al objetivo ${(tk.delay * 100).round()}% de un turno '
            'en la línea de tiempo');
      }
      if (tk.status case final st?) l.add(statusText(st));
    case SkillKind.heal:
      l.add('Cura MAG × ${fmtNum(tk.power)} + 6 a cada aliado'
          '${tk.cleanse > 0 ? (tk.cleanse >= 5 ? ' y quita todos los estados' : ' y quita 1 stack de cada estado') : ''}');
    case SkillKind.regen:
      l.add('Cura MAG × ${fmtNum(tk.power)} + 4 a cada aliado y les da '
          'Regeneración: 5% de vida y maná máx. al inicio de su turno, 3 turnos');
    case SkillKind.haste:
      l.add('Adelanta el próximo turno de tus aliados 50% de un turno');
    case SkillKind.defenseUp:
      l.add('+${tk.amount} DEF durante el combate (cada punto = -3% de daño '
          'recibido, máx -60%)');
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

/// `weaponTip`: el detalle de un arma (requisitos con el perfil, poder
/// calculado, mejoras, habilidades y ULT).
String weaponTooltip(ProgressionRules rules, PlayerProfile p, WeaponDef w) {
  final cat = rules.catalog;
  final owned = p.inventory.contains(w.id);
  final up = p.upgradesFor(w.id);
  final f = w.mag ?? w.atk;
  final power = f.evaluate(p.attributes) *
      (1 + WeaponUpgradeLevels.powPer * (owned ? up.pow : 0));
  final l = <String>[
    '${owned ? rules.weaponDisplayName(p, w.id) : w.name} · ${w.type} · tier ${w.tier}',
    'Requisitos: ${w.requirements.entries.map((e) => '${attributeShort(e.key)} ${e.value}${p.attributes[e.key] >= e.value ? ' (ok)' : ' (falta)'}').join(', ')}',
    '${w.mag != null ? 'Poder mágico' : 'Poder físico'}: ${fmtNum(f.base)} + '
        '${f.coefficients.entries.map((e) => '${attributeShort(e.key)}×${fmtNum(e.value)}').join(' + ')}'
        ' = ${power.round()}',
  ];
  if (owned && up.total > 0) {
    l.add('Mejoras: ${UpgradeStat.values.where((s) => up.level(s) > 0).map((s) => '${s.label} +${up.level(s)}').join(', ')}');
  }
  if (w.shieldDefense > 0) l.add('DEF +${w.shieldDefense}');
  if (w.weight > 0) l.add('Peso ${fmtNum(w.weight)} (-${fmtNum(w.weight)} velocidad)');
  l.add('');
  l.add('HABILIDADES');
  final fused = owned ? p.fused[w.id] : null;
  final ids = [...w.skillIds];
  if (fused != null && !ids.contains(fused)) ids.add(fused);
  for (final id in ids) {
    final s = cat.skills[id];
    if (s == null) continue;
    final d = skillDescription(s);
    if (id == fused) d[0] = '${d[0]} (fusión)';
    l.addAll(d);
  }
  if (cat.ultimates[w.type] case final u?) {
    l.add('');
    l.addAll(skillDescription(u, ult: true));
  }
  l.add('');
  l.add('Herrería: sube Poder, Crítico o Velocidad por separado '
      '(máx nivel ${ProgressionRules.upgradeMax} c/u)');
  return l.join('\n');
}
