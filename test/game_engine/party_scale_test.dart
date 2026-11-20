// Balance por tamaño de grupo para n > 4 (combo_balance.md § 3.3, v0.13):
// fórmulas con topes y medición con el simulador del admin.
import 'package:echos_del_tiempo/features/admin/domain/impact_preview.dart';
import 'package:echos_del_tiempo/game_engine/data/enemy_families.dart';
import 'package:echos_del_tiempo/game_engine/data/game_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/zone_curve.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/weapon.dart';
import 'package:echos_del_tiempo/game_engine/rules/loot_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/mulberry32.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('fórmulas de grupo: funciones de n con topes', () {
    const c = CurveDef();
    const h = HitCapDef();
    const combo = ComboRulesDef();

    test('hasta 4 no cambia nada', () {
      expect(c.groupHp(4), closeTo(1.8, 1e-9));
      expect(c.groupMitigationMult(4), closeTo(0.76, 1e-9));
      expect(c.groupAtk(4), closeTo(2.2, 1e-9));
      expect(combo.groupBreak(4), closeTo(1.8, 1e-9));
      expect(h.fraction(elite: false, boss: true, partySize: 4),
          closeTo(0.15, 1e-9));
    });

    test('5-8: vida hasta ×3.0, mitigación −40%, ATQ ×3.0', () {
      expect(c.groupHp(8), closeTo(3.0, 1e-9));
      expect(c.groupMitigationMult(6), closeTo(0.60, 1e-9));
      expect(c.groupMitigationMult(8), closeTo(0.60, 1e-9));
      expect(c.groupAtk(5), closeTo(2.6, 1e-9));
      expect(c.groupAtk(6), closeTo(3.0, 1e-9));
      expect(c.groupAtk(8), closeTo(3.0, 1e-9));
      expect(combo.groupBreak(8), closeTo(3.0, 1e-9));
      // Tope por golpe: sigue bajando a la mitad del ritmo, con piso.
      expect(h.fraction(elite: false, boss: true, partySize: 8),
          closeTo(0.09, 1e-9));
      expect(h.fraction(elite: true, boss: false, partySize: 8),
          closeTo(0.35 - 4 * 0.10 / 6, 1e-9));
    });

    test('n = 12 (máximo configurado mayor): todo acotado y monótono', () {
      for (var n = 1; n <= 12; n++) {
        expect(c.groupHp(n), lessThanOrEqualTo(c.groupHpMax));
        expect(c.groupMitigationMult(n), greaterThanOrEqualTo(0.6 - 1e-9));
        expect(c.groupAtk(n), lessThanOrEqualTo(c.groupAtkMax));
        final b = h.fraction(elite: false, boss: true, partySize: n);
        expect(b, greaterThanOrEqualTo(h.boss * HitCapDef.bigPartyFloor - 1e-9));
        if (n > 1) {
          expect(c.groupHp(n), greaterThanOrEqualTo(c.groupHp(n - 1)));
          expect(b,
              lessThanOrEqualTo(
                  h.fraction(elite: false, boss: true, partySize: n - 1)));
        }
      }
    });
  });

  test('simulador: grupo mixto sin combos con n = 1, 2, 4, 6, 8', () {
    const catalog = GameCatalog.standard;
    final sim = ImpactSimulator(catalog);
    const loot = LootRules();
    const mixed = [
      ('guerrero', 'espada'),
      ('maga', 'báculo'),
      ('tirador', 'arco'),
      ('paladin', 'espada+escudo'),
    ];
    const zones = [(1, 1), (2, 10), (5, 21), (6, 30)];
    final rows = <String>[];
    final eight = <(String, String, int, double)>[];
    for (final (zi, level) in zones) {
      final z = catalog.zone(zi)!;
      final m = catalog.mission(z.missionId!)!;
      final four = <SimLoadout>[];
      for (final (cls, type) in mixed) {
        WeaponDef? base;
        for (final w in catalog.weapons.values) {
          if (w.classId == cls &&
              w.type == type &&
              w.level <= level &&
              (base == null || w.level >= base.level)) {
            base = w;
          }
        }
        if (base == null) continue;
        final item = loot
            .generate(mulberry32(level * 53 + cls.length),
                itemLevel: level, rarity: Rarity.raro, baseId: base.id)
            .copyWith(forge: const WeaponUpgradeLevels(pow: 2));
        four.add(SimLoadout(
          classId: cls,
          level: level,
          weaponId: base.id,
          skillId: base.skillIds.isEmpty ? null : base.skillIds.first,
          item: item,
          potions: PlayerProfile.defaultPotions,
        ));
      }
      final fights = <(String, List<String>, bool)>[
        ('comunes', m.groups.length > 1 ? m.groups[1] : m.groups.first, false),
        if (m.elite.isNotEmpty) ('élite', [m.elite], true),
        ('jefe', m.boss, false),
      ];
      for (final (fight, enemies, elite) in fights) {
        for (final n in const [1, 2, 4, 6, 8]) {
          final party = [for (var k = 0; k < n; k++) four[k % four.length]];
          final r = sim.simulate(party.first,
              enemies: enemies,
              enemyLevel: level,
              elite: elite,
              party: party,
              runs: 16);
          rows.add('| ${z.name} (nv $level) | $fight | $n '
              '| ${r.wins}/${r.runs} '
              '| ${(r.avgActions / n).toStringAsFixed(1)} '
              '| ${(r.avgHpLeft * 100).toStringAsFixed(0)}% |');
          if (n == 8) {
            // Ni arrasa (todos actúan al menos una vez de promedio) ni
            // muere siempre.
            eight.add((z.name, fight, r.wins, r.avgActions / n));
          }
        }
      }
    }
    // ignore: avoid_print
    print(['| Zona | Pelea | Jug. | Victorias | Acc./jug. | Vida al ganar |',
      '|---|---|---|---|---|---|', ...rows].join('\n'));
  }, timeout: const Timeout(Duration(minutes: 10)));
}
