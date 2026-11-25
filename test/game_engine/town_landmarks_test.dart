import 'package:echos_del_tiempo/game_engine/data/town_layout.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/map_generator.dart';
import 'package:echos_del_tiempo/game_engine/rules/town_plan.dart';
import 'package:echos_del_tiempo/game_engine/rules/town_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/world_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lugares fijos movibles (docs/specs/town_editor.md § 3.3).
void main() {
  /// Desde la aparición, por tiles caminables: ¿llega al lado de [l]?
  bool reachable(GameMap m, TownLandmark l) {
    final (ox, oy) = m.townOrigin;
    final sx = (m.spawn.x / 16).floor(), sy = (m.spawn.y / 16).floor();
    final seen = <(int, int)>{(sx, sy)};
    final q = [(sx, sy)];
    while (q.isNotEmpty) {
      final (x, y) = q.removeLast();
      for (final (nx, ny) in [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]) {
        final inL = nx - ox >= l.x &&
            ny - oy >= l.y &&
            nx - ox < l.x + l.w &&
            ny - oy < l.y + l.h;
        if (inL) return true;
        if (WorldRules.isSolid(m, nx, ny) || !seen.add((nx, ny))) continue;
        q.add((nx, ny));
      }
    }
    return false;
  }

  test('sin marks: los lugares de siempre, la aparición de siempre', () {
    final s = TownState.fromJson(const {'builds': []});
    expect(s.marks, isEmpty);
    expect(TownPlan.landmarksOf(const TownState()), TownLayout.landmarks);
    final m = MapGenerator.townOf(const TownState());
    expect(m.spawn, TownLayout.spawn);
    final f = TownLayout.landmark(TownSpot.fountain);
    expect(TownLayout.spawnFor(f.x, f.y), TownLayout.spawn);
  });

  test('cada lugar se puede mover y queda alcanzable', () {
    const s = TownState();
    for (final l in TownLayout.landmarks) {
      (int, int)? to;
      for (var y = 2; y < 20 && to == null; y++) {
        for (var x = 2; x < 31; x++) {
          if ((x - l.x).abs() + (y - l.y).abs() < 4) continue;
          if (TownRules.moveLandmark(s, l.id, x, y).error == null) {
            to = (x, y);
            break;
          }
        }
      }
      expect(to, isNotNull, reason: l.id);
      final r = TownRules.move(s, l.id, to!.$1, to.$2);
      expect(r.error, isNull, reason: l.id);
      final t = r.town!;
      expect(t.marks[l.id], to);
      final m = MapGenerator.townOf(t);
      expect(m.tileAt(to.$1, to.$2), l.tile, reason: l.id);
      expect(TownPlan.of(t).unreached, isEmpty);
      for (final o in TownPlan.landmarksOf(t)) {
        expect(reachable(m, o), isTrue, reason: '${l.id} → ${o.id}');
      }
      for (final b in t.builds) {
        expect(TownPlan.of(t).unreached.contains(b.id), isFalse);
      }
    }
  });

  test('validación: no se pisa con otros lugares, construcciones ni borde',
      () {
    const s = TownState();
    // La forja encima del tablero.
    expect(TownRules.moveLandmark(s, '@forge', 11, 3).error, isNotNull);
    // El portal sobre el lago base.
    expect(TownRules.moveLandmark(s, '@portal', 4, 16).error, isNotNull);
    // La estatua en el borde de árboles.
    expect(TownRules.moveLandmark(s, '@statue', 32, 3).error, isNotNull);
    // La fuente sin lugar para su plaza al sur.
    expect(TownRules.moveLandmark(s, '@fountain', 16, 18).error, isNotNull);
    // Un lugar sobre la plaza de la fuente.
    expect(TownRules.moveLandmark(s, '@board', 14, 8).error, isNotNull);
    // Los lugares no se borran: remove no los conoce.
    expect(
        TownRules.remove(
            PlayerProfile(name: 'Ana', classId: 'guerrero'), s, '@forge'),
        isNull);
  });

  test('mover la forja rearma los caminos; volver la deja como siempre', () {
    const s = TownState();
    final r = TownRules.move(s, '@forge', 26, 8);
    expect(r.error, isNull);
    final t = r.town!;
    expect(TownPlan.rearranged(t), isTrue);
    final m = MapGenerator.townOf(t);
    // La fila de caminos del frente ya no es fija.
    expect(m.tileAt(20, 3), Tile.grass);
    // La forja tiene camino al lado.
    final near = [
      for (var x = 25; x <= 31; x++) ...[m.tileAt(x, 7), m.tileAt(x, 9)],
      m.tileAt(25, 8),
      m.tileAt(31, 8),
    ];
    expect(near, contains(Tile.path));
    // No se puede construir encima de la forja nueva.
    expect(TownRules.place(t, 'huerta_chica', 26, 8).error, isNotNull);
    final back = TownRules.move(t, '@forge', 19, 3).town!;
    expect(back.marks, isEmpty);
    expect(TownPlan.of(back).tiles, TownPlan.of(s).tiles);
  });

  test('la fuente movida lleva la aparición; E en la nueva posición', () {
    const s = TownState();
    final f = TownRules.move(s, '@fountain', 28, 9);
    expect(f.error, isNull);
    final m = MapGenerator.townOf(f.town!);
    expect(m.spawn, TownLayout.spawnFor(28, 9));
    expect(WorldRules.isSolid(m, 29, 13), isFalse);
    expect(WorldRules.townSpot(29 * 16, 8 * 16 + 8, map: m),
        TownSpot.fountain);
    // El comerciante movido: E donde está ahora, no donde estaba.
    final tr = TownRules.move(s, '@trader', 25, 2).town!;
    final tm = MapGenerator.townOf(tr);
    expect(WorldRules.townSpot(26 * 16, 3 * 16 + 4, map: tm), TownSpot.trader);
    expect(
        WorldRules.townSpot(13 * 16, 18 * 16 + 4, map: tm), isNot(TownSpot.trader));
  });

  test('JSON: marks ida y vuelta; ids desconocidos se ignoran', () {
    final t = TownRules.move(const TownState(), '@forge', 26, 8).town!;
    final j = t.toJson();
    expect(j['marks'], {
      '@forge': [26, 8]
    });
    final back = TownState.fromJson(j);
    expect(back.marks, {'@forge': (26, 8)});
    final odd = TownState.fromJson({
      ...j,
      'marks': {
        '@nada': [1, 1],
        '@forge': 'x'
      }
    });
    String pos(List<TownLandmark> ls) =>
        [for (final l in ls) '${l.id}:${l.x},${l.y}'].join(' ');
    expect(pos(TownPlan.landmarksOf(odd)), pos(TownLayout.landmarks));
    expect(TownPlan.rearranged(odd), isFalse);
  });

  group('estación de vagonetas (mining_smithing.md § 1.8)', () {
    /// Every rail tile of [s] is bare and off every build, plot,
    /// landmark, tree and light.
    void railClear(TownState s) {
      final plan = TownPlan.of(s);
      final (ox, oy) = s.origin;
      final st = TownPlan.landmarkOf(s, TownSpot.carts);
      final rail = plan.cartRail(st, s.lights);
      for (final (x, y) in rail) {
        final bx = x - ox, by = y - oy;
        expect(plan.at(x, y), Tile.grass, reason: '($x,$y)');
        for (final b in s.builds) {
          expect(b.contains(bx, by), isFalse, reason: '${b.id} ($bx,$by)');
        }
        expect(s.plots.containsKey('$bx,$by'), isFalse);
        for (final l in TownPlan.landmarksOf(s)) {
          expect(TownRect(l.x, l.y, l.w, l.h).contains(bx, by), isFalse,
              reason: l.id);
        }
        expect(TownLayout.trees.contains((bx, by)), isFalse);
        expect(s.lights.contains((bx, by)), isFalse);
      }
      expect(rail.length, lessThanOrEqualTo(TownPlan.cartRailMax * st.w));
    }

    test('chica y al lado de la salida, con un tramo corto de riel', () {
      const s = TownState();
      final st = TownPlan.landmarkOf(s, TownSpot.carts);
      final m = MapGenerator.townOf(s);
      // The exit: the south-axis path at the bottom edge.
      expect(m.tileAt(16, m.height - 1), Tile.path);
      expect(st.w * st.h, lessThanOrEqualTo(2));
      expect(st.x + st.w, 16, reason: 'right next to the exit path');
      expect(st.y + st.h, m.height - 2);
      // Its default spot is free: no late-spot relocation.
      expect((st.x, st.y), (TownLayout.landmark(TownSpot.carts).x,
          TownLayout.landmark(TownSpot.carts).y));
      final rail = TownPlan.of(s).cartRail(st);
      // One row, straight into the map edge.
      expect(rail, [(14, 20), (15, 20)]);
      railClear(s);
      // Reserved: nothing can be built on the station nor its rail.
      expect(TownRules.place(s, 'huerta_chica', 12, 18).error, isNotNull);
    });

    test('pueblo lleno de construcciones: el riel no pisa nada', () {
      var s = const TownState();
      for (final side in TownSide.values) {
        s = s.copyWith(sides: {...s.sides, side: 1});
      }
      for (final id in ['casa', 'huerta_chica', 'lago_chico', 'huerta']) {
        for (var y = -6; y < 30; y += 2) {
          for (var x = -6; x < 42; x += 2) {
            final r = TownRules.place(s, id, x, y);
            if (r.error == null) s = r.town!;
          }
        }
      }
      expect(s.builds.length, greaterThan(8));
      railClear(s);
    });

    test('pueblo guardado con una construcción ahí: la estación se corre',
        () {
      final s = const TownState().copyWith(builds: [
        ...kDefaultBuilds,
        const TownBuild('h9', BuildKind.huerta, [TownRect(12, 18, 4, 3)]),
      ]);
      final st = TownPlan.landmarkOf(s, TownSpot.carts);
      expect((st.x, st.y), isNot((14, 19)));
      expect(s.build('h9'), isNotNull);
      final r = TownRect(st.x, st.y, st.w, st.h);
      expect(s.build('h9')!.parts.single.overlaps(r), isFalse);
      railClear(s);
    });
  });
}
