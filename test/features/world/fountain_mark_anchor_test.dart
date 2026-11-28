import 'package:echos_del_tiempo/features/world/presentation/map/farm_layer.dart';
import 'package:echos_del_tiempo/game_engine/data/town_layout.dart';
import 'package:flutter_test/flutter_test.dart';

/// town_editor.md § 1.5: the fountain "!" sits on top of the basin.
void main() {
  final fountain =
      TownLayout.landmarks.firstWhere((l) => l.spot == TownSpot.fountain);

  test('mark is centred on the fountain footprint', () {
    final (x, _) = footprintMarkAnchor(fountain, 0, 0);
    expect(x, (fountain.x + fountain.w / 2) * 16);
    expect(x, fountain.center.x);
  });

  test('mark baseline touches the fountain top edge', () {
    final (_, y) = footprintMarkAnchor(fountain, 0, 0);
    final top = fountain.y * 16.0;
    expect(y, lessThan(top));
    expect(top - y, lessThanOrEqualTo(2));
  });

  test('anchor follows the town origin and a moved fountain', () {
    final moved = fountain.at(4, 6);
    final (x, y) = footprintMarkAnchor(moved, 3, 2);
    expect(x, (4 + 3 + moved.w / 2) * 16);
    expect(y, (6 + 2) * 16 - kFootprintMarkGap);
  });

  test('name lifts clear above the mark box', () {
    // Mark glyph is 7 px plus a 2 px box pad each side: the lifted name
    // baseline (top - 8 - lift) must be above the mark's box top.
    const markBoxTop = kFootprintMarkGap + 7 + 2;
    expect(8 + kFootprintNameLift - 6, greaterThan(markBoxTop));
  });
}
