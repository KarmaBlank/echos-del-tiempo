import 'dart:io';

import 'package:echos_del_tiempo/game_engine/data/game_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/tuning_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

import 'run_sim_harness.dart';

/// Full balance report for Paradoja (roguelike.md § 12.3). Slow, so it
/// only runs on demand: `PARADOJA_SIM_SEEDS=40 flutter test
/// test/game_engine/run_balance_report_test.dart`. The CI guard with the
/// targets is run_balance_sim_test.dart.
void main() {
  final seeds = int.tryParse(Platform.environment['PARADOJA_SIM_SEEDS'] ?? '');
  final diffs = (Platform.environment['PARADOJA_SIM_DIFFS'] ?? '0,2,5')
      .split(',')
      .map(int.parse);
  // Optional overrides of the «Travesía» group: `key=value,key=value`.
  final tune = Platform.environment['PARADOJA_SIM_TUNE'] ?? '';
  // A key may name its group: `combatLimits.pBreakOn=0`.
  setUp(() {
    for (final kv in tune.split(',').where((x) => x.contains('='))) {
      final k = kv.split('=')[0].trim();
      final group = k.contains('.') ? k.split('.')[0] : TuningId.travesia;
      final key = k.contains('.') ? k.split('.')[1] : k;
      final d = kTuning[group]!;
      kTuning[group] =
          TuningDef(d.name, {...d.values, key: num.parse(kv.split('=')[1])});
    }
  });
  tearDown(() => kTuning
    ..clear()
    ..addAll(kTuningDefaults));
  test('Paradoja balance report', () {
    final out = StringBuffer(RunSimStats.header)..writeln();
    final deaths = StringBuffer();
    for (final d in diffs) {
      for (final cls in GameCatalog.standard.classes.keys) {
        final st = simulateMany(cls, d, [for (var i = 1; i <= seeds!; i++) i]);
        out.writeln(st.row());
        deaths.writeln('$cls d$d deaths: ${st.deathsByType}');
      }
    }
    // ignore: avoid_print
    print('$out\n$deaths');
  }, skip: seeds == null, timeout: const Timeout(Duration(minutes: 60)));
}
