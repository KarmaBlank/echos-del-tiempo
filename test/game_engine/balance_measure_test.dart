// Medición de balance (docs/specs/combo_balance.md § 7, paso 1). No es un
// test de comportamiento: imprime una tabla con el simulador de balance
// (balance_admin.md § 5) y nunca falla. Se corre a mano:
//
//   flutter test test/game_engine/balance_measure_test.dart
//
// Escenarios: personaje al nivel de la zona con loot normal (Raro, forja
// +2) o con una legendaria forjada (+10); zona del principio de un tramo
// (A) y del final (C); 1 y 4 jugadores; comunes, élite y jefe. Pasos 3-4:
// quiebres por batalla, jefe quebrado antes de su ULT y grupo mixto (una
// de cada clase).

import 'package:echos_del_tiempo/features/admin/domain/impact_preview.dart';
import 'package:echos_del_tiempo/game_engine/data/game_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/uniques_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/weapon.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/rules/item_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/loot_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/mulberry32.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('medición de balance (imprime, no falla)', () {
    const catalog = GameCatalog.standard;
    final sim = ImpactSimulator(catalog);
    const loot = LootRules();

    // (zona, etiqueta del tramo, nivel)
    const zones = [
      (1, 'T1 A', 1),
      (2, 'T1 C', 10),
      (5, 'T3 A', 21),
      (6, 'T3 C', 30),
    ];
    const classes = [
      ('guerrero', 'Guerrero', 'espada'),
      ('maga', 'Maga', 'báculo'),
    ];

    final rows = <String>[
      '| Zona | Clase | Loot | Jug. | Pelea | Victorias | Acciones | '
          'Acc./jug. | Daño/acción | Mayor golpe | Quiebres | Jefe quebrado '
          'antes de su ULT | Vida al ganar |',
      '|---|---|---|---|---|---|---|---|---|---|---|---|---|',
    ];

    for (final (zi, tag, level) in zones) {
      final z = catalog.zone(zi)!;
      final m = catalog.mission(z.missionId!)!;
      final fights = <(String, List<String>, bool)>[
        ('comunes', m.groups.length > 1 ? m.groups[1] : m.groups.first, false),
        if (m.elite.isNotEmpty) ('élite', [m.elite], true),
        ('jefe', m.boss, false),
      ];
      for (final (cls, clsName, type) in classes) {
        WeaponDef? base;
        for (final w in catalog.weapons.values) {
          if (w.classId == cls && w.type == type && w.level <= level &&
              (base == null || w.level >= base.level)) {
            base = w;
          }
        }
        if (base == null) continue;
        final rng = mulberry32(level * 31 + cls.length);
        final normal = loot
            .generate(rng,
                itemLevel: level, rarity: Rarity.raro, baseId: base.id)
            .copyWith(forge: const WeaponUpgradeLevels(pow: 2));
        // La legendaria de la familia con la base más alta que entra.
        UniqueDef? u;
        for (final x in kUniques.values) {
          final b = catalog.weapons[x.baseId];
          if (x.exclusive || b == null || b.classId != cls || b.level > level) {
            continue;
          }
          if (u == null || b.level > catalog.weapons[u.baseId]!.level) u = x;
        }
        // Paso 6: forja hasta el tope por nivel de objeto
        // (`min(tope de rareza, 2 + nivel/5)`), mitad POT y mitad CRÍT.
        final legend0 = u == null ? null : loot.generateUnique(rng, u, level);
        final legend = legend0?.copyWith(
            forge: WeaponUpgradeLevels(
                pow: (ItemRules.forgeCapOf(legend0) + 1) ~/ 2,
                crit: ItemRules.forgeCapOf(legend0) ~/ 2));
        final items = [
          ('Raro +2', normal),
          if (legend != null) ('Leg. +${legend.forgeLevel}', legend),
        ];
        for (final (lootName, item) in items) {
          final w = catalog.weapons[item.baseId]!;
          final l = SimLoadout(
            classId: cls,
            level: level,
            weaponId: w.id,
            skillId: w.skillIds.isEmpty ? null : w.skillIds.first,
            item: item,
            potions: PlayerProfile.defaultPotions,
          );
          for (final n in const [1, 4]) {
            for (final (fight, enemies, elite) in fights) {
              final r = sim.simulate(l,
                  enemies: enemies,
                  enemyLevel: level,
                  elite: elite,
                  partySize: n,
                  runs: 16);
              rows.add('| ${z.name} ($tag, nv $level) | $clsName | $lootName '
                  '| $n | $fight | ${r.wins}/${r.runs} '
                  '| ${r.avgActions.toStringAsFixed(1)} '
                  '| ${(r.avgActions / n).toStringAsFixed(1)} '
                  '| ${r.avgDamagePerAction.toStringAsFixed(0)} '
                  '| ${(r.avgBestHit * 100).toStringAsFixed(0)}% '
                  '| ${r.avgBreaks.toStringAsFixed(1)} | ${_early(r)} '
                  '| ${(r.avgHpLeft * 100).toStringAsFixed(0)}% |');
            }
          }
        }
      }
    }
    // Grupo mixto (combo_balance.md § 5: "grupo al azar"): una de cada
    // clase con su arma inicial de nivel ≤ zona, Raro +2.
    const mixed = [
      ('guerrero', 'espada'),
      ('maga', 'báculo'),
      ('tirador', 'arco'),
      ('paladin', 'espada+escudo'),
    ];
    // Paso 7: el grupo mixto lleva la columna de Convergencias por pelea.
    final mixedRows = <String>[
      '| Zona | Clase | Loot | Jug. | Pelea | Victorias | Acciones | '
          'Acc./jug. | Daño/acción | Mayor golpe | Quiebres | Jefe quebrado '
          'antes de su ULT | Vida al ganar | Convergencias |',
      '|---|---|---|---|---|---|---|---|---|---|---|---|---|---|',
    ];
    for (final (zi, tag, level) in zones) {
      final z = catalog.zone(zi)!;
      final m = catalog.mission(z.missionId!)!;
      final party = <SimLoadout>[];
      for (final (cls, type) in mixed) {
        WeaponDef? base;
        for (final w in catalog.weapons.values) {
          if (w.classId == cls && w.type == type && w.level <= level &&
              (base == null || w.level >= base.level)) {
            base = w;
          }
        }
        if (base == null) continue;
        final rng = mulberry32(level * 53 + cls.length);
        final item = loot
            .generate(rng,
                itemLevel: level, rarity: Rarity.raro, baseId: base.id)
            .copyWith(forge: const WeaponUpgradeLevels(pow: 2));
        party.add(SimLoadout(
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
       for (final combos in const [false, true]) {
        final r = sim.simulate(party.first,
            enemies: enemies,
            enemyLevel: level,
            elite: elite,
            party: party,
            runs: 32,
            combos: combos);
        final n = party.length;
        mixedRows.add('| ${z.name} ($tag, nv $level) | Mixto${combos ? ' + combos' : ''} | Raro +2 | $n '
            '| $fight | ${r.wins}/${r.runs} '
            '| ${r.avgActions.toStringAsFixed(1)} '
            '| ${(r.avgActions / n).toStringAsFixed(1)} '
            '| ${r.avgDamagePerAction.toStringAsFixed(0)} '
            '| ${(r.avgBestHit * 100).toStringAsFixed(0)}% '
            '| ${r.avgBreaks.toStringAsFixed(1)} | ${_early(r)} '
            '| ${(r.avgHpLeft * 100).toStringAsFixed(0)}% '
            '| ${r.avgConvergences.toStringAsFixed(1)} |');
       }
      }
    }
    // ignore: avoid_print
    print(rows.join('\n'));
    // ignore: avoid_print
    print(mixedRows.join('\n'));
  }, timeout: const Timeout(Duration(minutes: 10)));
}

/// "3/16 (19%)" de jefes quebrados antes de su primera ULT, o "—".
String _early(BattleSimResult r) => r.bossRuns == 0
    ? '—'
    : '${r.bossEarlyBreaks}/${r.bossRuns} '
        '(${(r.bossEarlyBreakRate * 100).toStringAsFixed(0)}%)';
