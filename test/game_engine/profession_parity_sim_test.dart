import 'package:echos_del_tiempo/game_engine/rules/life_tree_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'profession_parity_sim.dart';

/// profession_gear.md § 7: equivalent effort, equivalent gear. One hour
/// of dedicated manual play of each profession yields a gear score (rate
/// × rarity weight) within ±15 % of the mean of the three, at profession
/// levels 10, 20 and 30. Deterministic (seeded); tune with the `parity*`
/// and gear keys of the Balance (Oficios: equipo).
void main() {
  test('the three professions yield equivalent gear per hour', () {
    final report = StringBuffer();
    final fails = <String>[];
    for (final level in const [10, 20, 30]) {
      final rows = [
        for (final k in LifeSkillKind.values) simulateParity(k, level),
      ];
      final mean = rows.fold(0.0, (a, r) => a + r.score) / rows.length;
      for (final r in rows) {
        report.writeln('${r.row()}  (${(r.score / mean * 100 - 100).toStringAsFixed(1)} %)');
      }
      for (final r in rows) {
        if (r.score <= 0 || (r.score - mean).abs() / mean > 0.15) {
          fails.add(r.row());
        }
      }
    }
    // ignore: avoid_print
    print(report);
    expect(fails, isEmpty, reason: '$report');
  });

  test('a dedicated path reaches legendary gear in every profession', () {
    for (final k in LifeSkillKind.values) {
      final r = simulateParity(k, 30, hours: 120);
      final leg = r.perHour.entries
          .where((e) => e.key.name == 'legendario' || e.key.name == 'epico')
          .fold(0.0, (a, e) => a + e.value);
      expect(leg, greaterThan(0), reason: r.row());
    }
  });
}
