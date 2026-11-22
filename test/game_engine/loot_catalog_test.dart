import 'package:echos_del_tiempo/game_engine/data/affixes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_mechanics.dart';
import 'package:echos_del_tiempo/game_engine/data/skills_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/uniques_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapon_passives.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/weapon_passive.dart';
import 'package:flutter_test/flutter_test.dart';

/// Datos de loot v2 (docs/specs/loot.md § 8–11).
void main() {
  test('89 bases (80 + 9 de Agua y Electro v0.7), niveles 1–50 y las 32 del '
      'prototipo', () {
    expect(kWeapons, hasLength(99)); // + 5 tomos del Invocador v0.8.1 + 5 de soporte v0.21
    const perFamily = {'guerrero': 23, 'maga': 31, 'tirador': 23, 'paladin': 22};
    for (final cls in kClasses.keys) {
      expect(kWeapons.values.where((w) => w.classId == cls),
          hasLength(perFamily[cls]),
          reason: cls);
    }
    expect(kWeapons.values.map((w) => w.level).reduce((a, b) => a < b ? a : b),
        1);
    expect(kWeapons.values.map((w) => w.level).reduce((a, b) => a > b ? a : b),
        50);
    // Las del prototipo conservan sus números (tier → nivel 1/2/4/7).
    const levels = {0: 1, 1: 2, 2: 4, 3: 7};
    for (final id in ['espada_bronce', 'espada_ignea', 'hacha_rompe', 'tomo_tiempo']) {
      final w = kWeapons[id]!;
      expect(w.level, levels[w.tier], reason: id);
      expect(w.implicit, isEmpty, reason: id);
    }
    expect(kWeapons['espada_ignea']!.price, 300);
    // Cada arma inicial es de nivel 1.
    for (final c in kClasses.values) {
      expect(kWeapons[c.startWeaponId]!.level, 1, reason: c.id);
    }
  });

  test('cada base: habilidades existentes, ULT de su tipo y pool de pasivas',
      () {
    for (final w in kWeapons.values) {
      expect(w.skillIds, isNotEmpty, reason: w.id);
      for (final s in w.skillIds) {
        expect(kSkills, contains(s), reason: '${w.id}: $s');
      }
      expect(kAllUltimates, contains(w.type), reason: w.id);
      expect(weaponPassivePool(w.type).length, greaterThanOrEqualTo(3),
          reason: w.type);
      expect(w.requirements, isNotEmpty, reason: w.id);
    }
    // Los 4 tipos nuevos y sus ULT (aparte de kUltimates hasta la UI).
    for (final t in ['lanza', 'varita', 'ballesta', 'dagas']) {
      expect(kUltimates.containsKey(t), isFalse);
      expect(kNewUltimates.containsKey(t), isTrue);
      expect(kWeapons.values.where((w) => w.type == t), isNotEmpty);
    }
    // Las 10 habilidades nuevas las usa alguna base.
    for (final s in ['perforar', 'barrido', 'empalar', 'misil', 'escarchaFugaz',
        'rayoArcano', 'virote', 'viroteIgneo', 'tajoGemelo', 'abanico']) {
      expect(kWeapons.values.any((w) => w.skillIds.contains(s)), isTrue,
          reason: s);
    }
  });

  test('afijos: tiers bien formados y restricciones por tipo', () {
    // + Evocador y del Pacto (v0.8.1), + Rompedor (v0.9), + Quebrantador
    // (v0.9.1).
    expect(kAffixes.length, 28);
    for (final a in kAffixes.values) {
      expect(a.tiers, isNotEmpty, reason: a.id);
      for (final t in a.tiers) {
        expect(t.min, lessThanOrEqualTo(t.max), reason: '${a.id} T${t.tier}');
        expect(t.weight, greaterThan(0));
      }
      // Mejor tier = más nivel y más valor.
      final byTier = [...a.tiers]..sort((x, y) => x.tier.compareTo(y.tier));
      for (var i = 1; i < byTier.length; i++) {
        expect(byTier[i - 1].minLevel, greaterThan(byTier[i].minLevel));
        expect(byTier[i - 1].min, greaterThanOrEqualTo(byTier[i].max));
      }
      if (a.types != null) {
        for (final t in a.types!) {
          expect(kWeapons.values.any((w) => w.type == t), isTrue,
              reason: '${a.id}: $t');
        }
      }
    }
    expect(kAffixes['gelido']!.types, {'báculo', 'tomo', 'varita', 'rifle'});
    expect(kAffixes['del_baluarte']!.types, kShieldWeaponTypes);
  });

  test('pasivas: 5 niveles crecientes y mecánicas resolubles', () {
    for (final p in kWeaponPassives.values) {
      expect(p.values, hasLength(5), reason: p.id);
      for (var i = 1; i < 5; i++) {
        expect(p.values[i], greaterThanOrEqualTo(p.values[i - 1]),
            reason: p.id);
      }
      for (var l = 1; l <= 5; l++) {
        final mechs = p.mechanicsAt(l);
        expect(mechs, isNotEmpty);
        expect(mechs.first.id, WeaponPassiveDef.mechanicId(p.id, l));
        for (final m in mechs) {
          expect(mechanicById(m.id)?.id, m.id, reason: m.id);
          expect(m.effects, isNotEmpty, reason: m.id);
        }
      }
      expect(p.unique, p.types.isEmpty, reason: p.id);
    }
    expect(kWeaponPassives.values.where((p) => !p.unique), hasLength(21));
    expect(mechanicById('wp:noExiste:1'), isNull);
    expect(mechanicById('frenesi')?.name, 'Frenesí');
  });

  test('legendarios: base, mods fijos válidos y pasiva única', () {
    // v0.8: + 6 exclusivos de los Jefes del Abismo.
    // v0.22.2: + 3 exclusivos del agua (fishing.md § 8.3).
    expect(kUniques.length, inInclusiveRange(25, 29));
    expect(kUniques.values.where((u) => u.exclusive), hasLength(9));
    final perFamily = <String, int>{};
    for (final u in kUniques.values) {
      final w = kWeapons[u.baseId];
      expect(w, isNotNull, reason: u.id);
      perFamily[w!.classId] = (perFamily[w.classId] ?? 0) + 1;
      final p = kWeaponPassives[u.passiveId];
      expect(p?.unique, isTrue, reason: u.id);
      expect(u.fixed.length + u.randomMax, lessThanOrEqualTo(Rarity.legendario.maxMods));
      final ids = <String>{};
      for (final m in u.fixed) {
        final a = kAffixes[m.affixId];
        expect(a, isNotNull, reason: '${u.id}: ${m.affixId}');
        expect(a!.allows(w.type), isTrue, reason: '${u.id}: ${m.affixId}');
        expect(ids.add(m.affixId), isTrue);
        expect(m.min, lessThanOrEqualTo(m.max));
      }
    }
    for (final cls in kClasses.keys) {
      expect(perFamily[cls], greaterThanOrEqualTo(2), reason: cls);
    }
    // Cada pasiva única la usa exactamente un legendario.
    final used = kUniques.values.map((u) => u.passiveId).toList();
    expect(used.toSet(), hasLength(used.length));
  });
}
