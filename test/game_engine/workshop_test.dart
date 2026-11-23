import 'package:echos_del_tiempo/game_engine/data/town_layout.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/town_plan.dart';
import 'package:flutter_test/flutter_test.dart';

TownLandmark _ws(TownState s) =>
    TownPlan.landmarkOf(s, TownSpot.workshop);

void main() {
  test('el taller está en el pueblo base, en pasto libre', () {
    const s = TownState();
    final l = _ws(s);
    expect((l.x, l.y, l.w, l.h), (6, 6, 3, 3));
    final plan = TownPlan.of(s);
    final (ox, oy) = s.origin;
    for (var y = l.y; y < l.y + l.h; y++) {
      for (var x = l.x; x < l.x + l.w; x++) {
        expect(plan.at(x + ox, y + oy), Tile.workshop);
      }
    }
    expect(Tile.solidTiles, contains(Tile.workshop));
  });

  test('pueblo guardado con algo en el lugar del taller: va a un hueco', () {
    const s = TownState(builds: [
      ...kDefaultBuilds,
      TownBuild('h9', BuildKind.huerta, [TownRect(6, 7, 3, 2)]),
    ]);
    final l = _ws(s);
    expect((l.x, l.y), isNot((6, 6)));
    final r = TownRect(l.x, l.y, l.w, l.h);
    for (final b in s.builds) {
      expect(b.parts.any((p) => p.overlaps(r)), isFalse);
    }
    for (final o in TownPlan.landmarksOf(s)) {
      if (o.spot == TownSpot.workshop) continue;
      expect(TownRect(o.x, o.y, o.w, o.h).overlaps(r), isFalse);
    }
  });

  test('se puede mover como los otros lugares', () {
    expect(TownLayout.byId('@workshop')?.name, 'TALLER DE OFICIOS');
  });

  test('la ARMERÍA tiene su propio lugar, aparte de la FORJA', () {
    const s = TownState();
    final a = TownPlan.landmarkOf(s, TownSpot.armory);
    final f = TownPlan.landmarkOf(s, TownSpot.forge);
    expect((a.x, a.y, a.w, a.h), (26, 6, 3, 3));
    expect(a.name, 'ARMERÍA');
    expect(f.name, 'FORJA');
    final (ox, oy) = s.origin;
    expect(TownPlan.of(s).at(a.x + ox, a.y + oy), Tile.shop);
  });

  test('armería guardada con un faro encima: va al hueco más cercano', () {
    const s = TownState(lights: [(27, 7)]);
    final a = TownPlan.landmarkOf(s, TownSpot.armory);
    expect(TownRect(a.x, a.y, a.w, a.h).contains(27, 7), isFalse);
  });
}
