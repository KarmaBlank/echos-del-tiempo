import 'package:echos_del_tiempo/game_engine/data/game_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

import 'run_sim_harness.dart';

/// Paradoja balance guard (roguelike.md § 12.3): seeded solo runs of every
/// class at difficulty 0 and 5 with the simple AI of [simulateRun] must
/// hit the targets of the spec. Deterministic (fixed seeds). The full
/// report with more seeds is run_balance_report_test.dart.
void main() {
  const seeds = 30;
  final classes = GameCatalog.standard.classes.keys.toList();

  double median(List<double> v) {
    final s = [...v]..sort();
    return s.length.isOdd
        ? s[s.length ~/ 2]
        : (s[s.length ~/ 2 - 1] + s[s.length ~/ 2]) / 2;
  }

  test('Paradoja hits the balance targets', () {
    final stats = {
      for (final d in [0, 5])
        d: [
          for (final c in classes)
            simulateMany(c, d, [for (var i = 1; i <= seeds; i++) i]),
        ],
    };
    final report = StringBuffer(RunSimStats.header)..writeln();
    for (final l in stats.values) {
      for (final st in l) {
        report.writeln(st.row());
      }
    }
    // ignore: avoid_print
    print(report);
    final why = '$report';

    final m0 = median([for (final s in stats[0]!) s.winRate]);
    final m5 = median([for (final s in stats[5]!) s.winRate]);
    // Normal: most runs are won; top difficulty: a minority.
    expect(m0, inInclusiveRange(0.65, 0.85), reason: why);
    expect(m5, inInclusiveRange(0.25, 0.45), reason: why);
    // Median run at normal reaches the last floor.
    final floors0 = [for (final s in stats[0]!) s.medianFloor]..sort();
    expect(floors0[floors0.length ~/ 2], 3, reason: why);
    for (final d in [0, 5]) {
      final m = d == 0 ? m0 : m5;
      for (final st in stats[d]!) {
        // Every class within ±15 points of the median win rate.
        expect((st.winRate - m).abs(), lessThanOrEqualTo(0.15),
            reason: '${st.classId} d$d\n$why');
        // Bosses are a check, not a wall.
        for (final f in [1, 2, 3]) {
          final b = st.bossRate(f);
          if (b == null) continue;
          expect(b, greaterThanOrEqualTo(d == 0 ? 0.8 : 0.6),
              reason: '${st.classId} d$d boss f$f\n$why');
        }
      }
    }
    // Difficulty bites every class.
    for (var i = 0; i < classes.length; i++) {
      expect(stats[5]![i].winRate, lessThan(stats[0]![i].winRate),
          reason: '${classes[i]}\n$why');
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}
