import 'package:echos_del_tiempo/features/world/presentation/map/farm_layer.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/map_themes.dart';
import 'package:echos_del_tiempo/game_engine/data/farming_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la semilla cae en un punto determinista dentro del tile', () {
    for (var x = -5; x < 20; x++) {
      for (var y = 0; y < 12; y++) {
        for (final id in kCrops.keys) {
          final a = MapFarmLayer.seedOffset(x, y, id, 'p1');
          expect(MapFarmLayer.seedOffset(x, y, id, 'p1'), a);
          expect(a.dx, inInclusiveRange(1, MapFarmLayer.ts - 1));
          expect(a.dy, inInclusiveRange(1, MapFarmLayer.ts - 1));
        }
      }
    }
    final spots = {
      for (var x = 0; x < 10; x++) MapFarmLayer.seedOffset(x, 3, 'nabo_claro', 'p1')
    };
    expect(spots.length, greaterThan(3), reason: 'no siempre en el mismo lugar');
  });

  test('cada cultivo tiene su aspecto, y todos son distintos', () {
    for (final id in kCrops.keys) {
      expect(CropPalette.looks.containsKey(id), isTrue, reason: id);
    }
    final sigs = {
      for (final l in CropPalette.looks.values) '${l.shape}|${l.fruit}'
    };
    expect(sigs.length, kCrops.length);
  });
}
