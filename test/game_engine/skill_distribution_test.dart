import 'package:echos_del_tiempo/game_engine/data/ascension_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/skill_variants_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/skills_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/skill.dart';
import 'package:flutter_test/flutter_test.dart';

// Reparto de las variantes v0.5 en las bases (loot.md § 8.2 nota ²).

void main() {
  test('las variantes están en kSkills (120+ habilidades)', () {
    for (final id in kSkillVariants.keys) {
      expect(kSkills[id], same(kSkillVariants[id]), reason: id);
    }
    expect(kSkills.length, greaterThanOrEqualTo(120));
  });

  test('toda habilidad la da un arma o un kit de ascensión', () {
    final given = {
      for (final w in kWeapons.values) ...w.skillIds,
      for (final a in kAscensions.values) ...a.skillIds,
      for (final c in kClasses.values) ...c.kitSkillIds,
    };
    // La Quebrar base la trae toda arma (combo_balance.md § 5.1) y el
    // combo de clase, toda clase (§ 5.2): las agrega el motor.
    for (final id in kSkills.keys.where((k) => !kEngineSkillIds.contains(k))) {
      expect(given, contains(id), reason: '$id no la da nadie');
    }
  });

  test('ninguna base pasa de 3 habilidades; las iniciales no cambian', () {
    for (final w in kWeapons.values) {
      expect(w.skillIds.length, inInclusiveRange(1, 3), reason: w.id);
      expect(w.skillIds.toSet().length, w.skillIds.length, reason: w.id);
    }
    expect(kWeapons['espada_bronce']!.skillIds, ['giro', 'embestida']);
    expect(kWeapons['baculo_aprendiz']!.skillIds, ['chispa', 'cura']);
    expect(kWeapons['arco_corto']!.skillIds, ['venenosa', 'rafaga', 'certero']);
  });

  test('cada tipo de arma tiene alguna opción de apoyo o defensa', () {
    bool support(SkillDef s) =>
        !s.dealsDamage ||
        s.drainHeal > 0 ||
        s.debuffs.isNotEmpty ||
        s.ultDrain > 0 ||
        s.shields;
    final types = {for (final w in kWeapons.values) w.type};
    for (final t in types) {
      if (t == 'martillo+escudo') continue; // línea de daño a propósito
      expect(
          kWeapons.values.any((w) =>
              w.type == t && w.skillIds.any((s) => support(kSkills[s]!))),
          isTrue,
          reason: t);
    }
  });

  test('menú: arma (≤3) + fusión + kit de ascensión (≤3) entra en 2 páginas', () {
    final maxAsc =
        kAscensions.values.map((a) => a.skillIds.length).reduce((a, b) => a > b ? a : b);
    // Atacar + ULT + técnicas + 2 pociones + Defender; cada página ≤ 9
    // (battleMenuPage, battle_menu_paging_test).
    expect(3 + 1 + maxAsc, lessThanOrEqualTo(7));
  });
}
