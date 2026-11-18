import 'package:echos_del_tiempo/features/combat/domain/skill_text.dart';
import 'package:echos_del_tiempo/game_engine/data/skill_variants_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

// Tooltips y etiquetas del menú de las variantes (combat.md § "Variantes
// de habilidades"): cada mecánica se nombra en castellano y con color.

void main() {
  test('cada variante explica su mecánica en el tooltip', () {
    for (final sk in kSkillVariants.values) {
      final tip = describeSkillMarkup(sk, null);
      expect(tip, contains(sk.name), reason: sk.id);
      final want = <String>[
        if (sk.revive > 0) 'Revive',
        if (sk.lowestAlly) 'más herido',
        if (sk.overheal > 0) 'Desborde',
        if (sk.drainHeal > 0) 'Drena',
        if (sk.allyShield > 0 || sk.selfShield > 0) 'Escudo del',
        if (sk.shieldReflect > 0) 'Espinoso',
        if (sk.shieldBurst > 0) 'Volátil',
        if (sk.shieldGrow > 0) 'Creciente',
        if (sk.charge > 0) 'Disparo cargado',
        if (sk.hits > 1) '${sk.hits} golpes',
        if (sk.pierce > 0) 'Atraviesa',
        if (sk.bounces > 0) 'Rebota',
        if (sk.breakBonus > 0) 'Quiebre',
        if (sk.ultDrain > 0) 'Silencio',
        for (final _ in sk.debuffs) '(',
      ];
      for (final w in want) {
        expect(tip, contains(w), reason: '${sk.id}: $w');
      }
      if (variantEffectLines(sk).isNotEmpty) {
        expect(tip, contains('<span style="color:'), reason: sk.id);
      }
    }
  });

  test('las variantes llevan etiqueta corta en el menú', () {
    for (final sk in kSkillVariants.values) {
      final tag = variantTagMarkup(sk);
      final plain = sk.debuffs.isEmpty &&
          sk.revive == 0 &&
          !sk.lowestAlly &&
          sk.overheal == 0 &&
          sk.drainHeal == 0 &&
          sk.allyShield == 0 &&
          sk.selfShield == 0 &&
          sk.shieldReflect == 0 &&
          sk.shieldBurst == 0 &&
          sk.shieldGrow == 0 &&
          sk.charge == 0 &&
          sk.hits == 1 &&
          sk.pierce == 0 &&
          sk.bounces == 0 &&
          sk.breakBonus == 0 &&
          sk.ultDrain == 0;
      expect(tag.isEmpty, plain, reason: sk.id);
    }
  });
}
