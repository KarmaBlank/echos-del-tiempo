import 'package:echos_del_tiempo/game_engine/data/tuning_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

/// Desde v0.31.0 el modo por defecto en solitario es "Por rondas". Estos
/// tests se escribieron con la línea de tiempo: la fijan para su grupo.
void useTimelineSoloDefault() {
  setUp(() {
    final d = kTuningDefaults[TuningId.combatLimits]!;
    kTuning[TuningId.combatLimits] =
        TuningDef(d.name, {...d.values, 'modeSolo': 0});
  });
  tearDown(() =>
      kTuning[TuningId.combatLimits] = kTuningDefaults[TuningId.combatLimits]!);
}
