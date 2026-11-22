import 'package:echos_del_tiempo/game_engine/data/town_layout.dart';
import 'package:echos_del_tiempo/game_engine/data/vaults_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/zones_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/models/zone_def.dart';
import 'package:echos_del_tiempo/game_engine/rules/map_generator.dart';
import 'package:echos_del_tiempo/game_engine/rules/world_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/zone_generators.dart';
import 'package:echos_del_tiempo/game_engine/rules/zone_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tiles alcanzables desde ([sx], [sy]) caminando (colisión de
/// `WorldRules`, con la barrera abierta o cerrada).
Set<(int, int)> _reach(GameMap m, int sx, int sy, {required bool gateOpen}) {
  final seen = <(int, int)>{(sx, sy)};
  final stack = [(sx, sy)];
  while (stack.isNotEmpty) {
    final (x, y) = stack.removeLast();
    for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
      final n = (x + dx, y + dy);
      // Sin pisar el vacío (caminar sin caerse). Las paredes agrietadas y
      // los atajos (v0.6) cuentan como abiertos.
      final c = m.contains(n.$1, n.$2) ? m.tileAt(n.$1, n.$2) : Tile.wall;
      if (c == Tile.cracked || c == Tile.shortcut) {
        if (seen.add(n)) stack.add(n);
        continue;
      }
      if (WorldRules.isSolid(m, n.$1, n.$2, gateOpen: gateOpen, blockVoid: true)) {
        continue;
      }
      if (seen.add(n)) stack.add(n);
    }
  }
  return seen;
}

(int, int) _tile(WorldPoint p) => ((p.x / 16).floor(), (p.y / 16).floor());

final _seeds = [
  1, 42, 7777, 500000000, 987654321, -123456,
  for (var i = 0; i < 30; i++) i * 104723 + 17,
];

void main() {
  group('pueblo (sin overworld, town_loop.md § 2.1)', () {
    final w = MapGenerator.town();

    test('tamaño, tema, sin entradas de zona y siempre el mismo', () {
      expect(w.width, TownLayout.width);
      expect(w.height, TownLayout.height);
      expect(w.rows.every((r) => r.length == w.width), isTrue);
      expect(w.theme, 'pueblo');
      expect(w.lobby, isTrue);
      expect(w.entrances, isEmpty);
      expect(identical(MapGenerator.town(), w), isTrue);
    });

    test('lugares en su tile, alcanzables y detectables con E', () {
      final sp = _tile(w.spawn);
      final reach = _reach(w, sp.$1, sp.$2, gateOpen: false);
      for (final l in TownLayout.landmarks) {
        for (var y = l.y; y < l.y + l.h; y++) {
          for (var x = l.x; x < l.x + l.w; x++) {
            expect(w.tileAt(x, y), l.tile, reason: l.name);
            expect(WorldRules.isSolid(w, x, y), isTrue, reason: l.name);
          }
        }
        // Algún vecino caminable alcanzable, y E desde ahí da el lugar.
        var ok = false;
        for (var y = l.y - 1; y <= l.y + l.h && !ok; y++) {
          for (var x = l.x - 1; x <= l.x + l.w && !ok; x++) {
            if (!reach.contains((x, y))) continue;
            final px = x * 16 + 8.0, py = y * 16 + 8.0;
            if (WorldRules.collides(w, px, py)) continue;
            ok = WorldRules.townSpot(px, py) == l.spot;
          }
        }
        expect(ok, isTrue, reason: '${l.name} inalcanzable');
      }
      for (final (x, y) in TownLayout.fishingSpots) {
        expect(w.tileAt(x, y), Tile.fishing);
      }
      expect(WorldRules.townSpot(w.spawn.x, w.spawn.y), isNull);
    });

    test('lago con agua, camino al sur y solo tiles conocidos', () {
      const known = {',', '~', 'C', 'A', 'P', 'S', 'L', 'M', 'g', 'T', 'F',
        'f', 'Y', 'u'};
      for (final r in w.rows) {
        for (final c in r.split('')) {
          expect(known.contains(c), isTrue, reason: 'tile $c');
        }
      }
      expect(w.rows.join().split('').where((c) => c == Tile.water).length,
          greaterThan(30));
      // Salida de expedición: el camino de tierra llega al borde sur.
      expect(w.tileAt(16, w.height - 1), Tile.path);
      final sp = _tile(w.spawn);
      final reach = _reach(w, sp.$1, sp.$2, gateOpen: false);
      expect(reach.contains((16, w.height - 2)), isTrue);
      for (final (x, y) in reach) {
        expect(Tile.isWalkable(w.tileAt(x, y)), isTrue);
      }
    });
  });

  group('vaults', () {
    test('3–4 por tipo, filas parejas, borde de muro o abertura, con cofre', () {
      const old = ['bosque', 'ruinas', 'cavernas', 'fortaleza'];
      for (final type in [...old, 'laberinto', 'grieta', 'abismo', 'cementerio']) {
        final list = kVaults[type]!;
        final v3 = !old.contains(type);
        expect(list.length, inInclusiveRange(3, 4), reason: type);
        for (final v in list) {
          expect(v.rows.every((r) => r.length == v.width), isTrue, reason: v.id);
          for (var y = 0; y < v.height; y++) {
            for (var x = 0; x < v.width; x++) {
              final c = v.rows[y][x];
              expect((v3 ? '#:,~+ce_=%to' : '#:,~+ce').contains(c), isTrue,
                  reason: '${v.id} "$c"');
              final edge = x == 0 || y == 0 || x == v.width - 1 || y == v.height - 1;
              if (edge) {
                expect((v3 ? '#+_' : '#+').contains(c), isTrue,
                    reason: '${v.id} borde');
              }
            }
          }
          expect(v.rows.join().contains('c'), isTrue, reason: v.id);
          expect(v.rows.join().contains('+'), isTrue, reason: v.id);
        }
      }
    });

    test('cada generador usa su tipo de vault', () {
      expect(ZoneGenerators.vaultType(ZoneGen.pradera), 'bosque');
      expect(ZoneGenerators.vaultType(ZoneGen.bosque), 'bosque');
      expect(ZoneGenerators.vaultType(ZoneGen.ruinas), 'ruinas');
      expect(ZoneGenerators.vaultType(ZoneGen.cavernas), 'cavernas');
      expect(ZoneGenerators.vaultType(ZoneGen.fortaleza), 'fortaleza');
      expect(ZoneGenerators.vaultType(ZoneGen.laberinto), 'laberinto');
      expect(ZoneGenerators.vaultType(ZoneGen.grieta), 'grieta');
      expect(ZoneGenerators.vaultType(ZoneGen.abismo), 'abismo');
      expect(ZoneGenerators.vaultType(ZoneGen.corazon), 'abismo');
      expect(ZoneGenerators.vaultType(ZoneGen.cementerio), 'cementerio');
    });
  });

  group('atlas de zona', () {
    for (final z in kZones.where((z) => z.playable)) {
      test('${z.name}: determinístico, pisos conectados, escaleras y arena', () {
        var vaults = 0;
        for (final seed in _seeds) {
          final m = MapGenerator.zone(z, seed);
          final again = MapGenerator.zone(z, seed);
          expect(again.rows, m.rows, reason: 'misma semilla, mismo mapa');
          expect(m.zone, z.index);
          expect(m.theme, z.theme);
          expect(m.rows.every((r) => r.length == m.width), isTrue);
          expect(m.floors, hasLength(ZoneRules.missionFloors(z)));
          expect(m.spawn, m.floors.first.spawn);
          expect(m.boss, m.floors.last.boss);
          for (final f in m.floors) {
            final why = '${z.id} semilla $seed piso ${f.index}';
            final last = f.index == ZoneRules.missionFloors(z) - 1;
            expect(f.last, last);
            final sp = _tile(f.spawn);
            expect(f.containsTile(sp.$1, sp.$2), isTrue, reason: why);
            expect(WorldRules.collides(m, f.spawn.x, f.spawn.y), isFalse, reason: why);
            final closed = _reach(m, sp.$1, sp.$2, gateOpen: false);
            final open = _reach(m, sp.$1, sp.$2, gateOpen: true);
            // Todo lo caminable del piso se alcanza (con la barrera abierta).
            for (var y = f.bounds.y; y < f.bounds.y + f.bounds.h; y++) {
              for (var x = f.bounds.x; x < f.bounds.x + f.bounds.w; x++) {
                if (!WorldRules.isSolid(m, x, y, gateOpen: true, blockVoid: true)) {
                  expect(open.contains((x, y)), isTrue,
                      reason: '$why: ($x,$y) aislado');
                }
              }
            }
            expect(open.every((t) => f.containsTile(t.$1, t.$2)), isTrue,
                reason: '$why: se escapa del piso');
            // Barrera: la arena solo se alcanza abriéndola.
            final ar = f.arena!;
            expect(closed.contains((ar.cx, ar.cy)), isFalse, reason: why);
            expect(open.contains((ar.cx, ar.cy)), isTrue, reason: why);
            expect(m.rows.sublist(f.bounds.y, f.bounds.y + f.bounds.h)
                .any((r) => r.substring(f.bounds.x, f.bounds.x + f.bounds.w).contains('G')),
                isTrue, reason: why);
            // Escaleras.
            if (last) {
              expect(f.stairsDown, isNull);
              expect(f.boss, WorldPoint(ar.cx * 16 + 8.0, ar.cy * 16 + 8.0));
            } else {
              final d = _tile(f.stairsDown!);
              expect(m.tileAt(d.$1, d.$2), Tile.stairsDown, reason: why);
              expect((d.$1, d.$2), (ar.cx, ar.cy));
              expect(WorldRules.collides(m, f.returnPoint!.x, f.returnPoint!.y,
                  gateOpen: true), isFalse, reason: why);
              expect(WorldRules.nearStairs(m, f.stairsDown!.x, f.stairsDown!.y),
                  StairsKind.down);
            }
            if (f.index == 0) {
              expect(f.stairsUp, isNull);
            } else {
              final u = _tile(f.stairsUp!);
              expect(m.tileAt(u.$1, u.$2), Tile.stairsUp, reason: why);
              expect(closed.contains(u), isTrue, reason: why);
              expect(WorldRules.nearStairs(m, f.stairsUp!.x, f.stairsUp!.y),
                  StairsKind.up);
            }
            // Spots: suficientes, caminables y sin pasar la barrera.
            // v0.20.22: pisos más chicos (worldgen.md § 6.8).
            expect(f.spots.length, greaterThan(40), reason: why);
            for (final s in f.spots) {
              expect(closed.contains(s), isTrue, reason: '$why spot $s');
            }
            // Vaults: marcas dentro de su vault y alcanzables.
            vaults += f.vaults.length;
            for (final c in [...f.chestMarks, ...f.eliteMarks]) {
              expect(m.tileAt(c.$1, c.$2), Tile.vaultFloor, reason: why);
              expect(f.vaults.any((v) =>
                  c.$1 >= v.x && c.$2 >= v.y && c.$1 < v.x + v.w && c.$2 < v.y + v.h),
                  isTrue, reason: why);
              expect(closed.contains(c), isTrue, reason: '$why marca $c');
            }
            expect(m.floorAt(f.spawn.x, f.spawn.y), same(f));
          }
        }
        expect(vaults, greaterThanOrEqualTo(_seeds.length * ZoneRules.missionFloors(z)),
            reason: 'al menos un vault por piso');
      });
    }

    test('semillas distintas, mapas distintos', () {
      final z = kZones[3];
      expect(MapGenerator.zone(z, 1).rows, isNot(MapGenerator.zone(z, 2).rows));
    });

    test('ruinas: cada piso es el genMap de su semilla (arena y lado)', () {
      final z = kZones[2];
      const seed = 31337;
      final m = MapGenerator.zone(z, seed);
      var ox = 0;
      for (final f in m.floors) {
        final g = MapGenerator.ruins(
            'ruinas', (seed + 7919 * f.index + 104729 * z.index).toSigned(32));
        expect(f.side, g.side);
        expect(f.arena!.x, g.arena!.x + ox);
        expect(f.arena!.y, g.arena!.y);
        expect(f.spawn, WorldPoint(g.spawn.x + ox * 16, g.spawn.y));
        ox += g.width + MapGenerator.floorGap;
      }
    });

    test('v0.3: tiles de cada generador y vacío/lava donde corresponde', () {
      const v2 = {'#', '.', ',', '~', 'G', '>', '<', ':', ...Tile.poiTiles};
      final want = <int, Set<String>>{
        6: {...v2, 'o'},
        7: {...v2, '%', '='},
        8: {...v2, '_', '=', 't'},
        9: {...v2, '_', '='},
        10: {...v2, '_', '='},
      };
      for (final zi in [6, 7, 8, 9, 10]) {
        final z = kZones[zi - 1];
        final seen = <String>{};
        for (final seed in _seeds.take(12)) {
          final m = MapGenerator.zone(z, seed);
          for (final f in m.floors) {
            for (var y = f.bounds.y; y < f.bounds.y + f.bounds.h; y++) {
              seen.addAll(m.rows[y]
                  .substring(f.bounds.x, f.bounds.x + f.bounds.w)
                  .split(''));
            }
          }
        }
        expect(want[zi]!.containsAll(seen), isTrue,
            reason: 'zona $zi: ${seen.difference(want[zi]!)}');
      }
      // Lo característico aparece.
      String all(int zi) => [
            for (final s in _seeds.take(6)) ...MapGenerator.zone(kZones[zi - 1], s).rows,
          ].join();
      expect(all(7).contains(Tile.lava), isTrue);
      expect(all(7).contains(Tile.bridge), isTrue);
      expect(all(8).contains(Tile.tombstone), isTrue);
      for (final zi in [8, 9, 10]) {
        expect(all(zi).contains(Tile.voidTile), isTrue, reason: 'zona $zi');
        expect(all(zi).contains(Tile.bridge), isTrue, reason: 'zona $zi');
      }
      expect(all(6).contains(Tile.voidTile), isFalse);
      expect(all(7).contains(Tile.voidTile), isFalse);
    });

    test('abismo: la arena es una isla (vacío alrededor) y el vacío se pisa', () {
      for (final zi in [8, 9, 10]) {
        final m = MapGenerator.zone(kZones[zi - 1], 4242);
        for (final f in m.floors) {
          final ar = f.arena!;
          // Fuera de la barrera y el tramo de entrada, el anillo es vacío.
          var voids = 0, ring = 0;
          for (var x = ar.x - 1; x <= ar.x + ar.w; x++) {
            for (final y in [ar.y - 1, ar.y + ar.h]) {
              ring++;
              if (m.tileAt(x, y) == Tile.voidTile) voids++;
            }
          }
          expect(voids, greaterThan(ring ~/ 2), reason: 'zona $zi piso ${f.index}');
          final sp = _tile(f.spawn);
          expect(m.tileAt(sp.$1, sp.$2), isNot(Tile.voidTile));
        }
        // Vacío: caminable para el jugador, sólido para enemigos.
        final f0 = m.floors.first;
        (int, int)? v;
        for (var y = f0.bounds.y; y < f0.bounds.h && v == null; y++) {
          final x = m.rows[y].indexOf(Tile.voidTile);
          if (x >= 0 && x < f0.bounds.w) v = (x, y);
        }
        expect(v, isNotNull);
        expect(WorldRules.isSolid(m, v!.$1, v.$2), isFalse);
        expect(WorldRules.isSolid(m, v.$1, v.$2, blockVoid: true), isTrue);
        expect(WorldRules.isVoid(m, v.$1, v.$2), isTrue);
        expect(WorldRules.overVoid(m, v.$1 * 16 + 8.0, v.$2 * 16 + 8.0), isTrue);
        expect(WorldRules.overVoid(m, f0.spawn.x, f0.spawn.y), isFalse);
      }
    });

    test('corazón: la arena está en el centro del piso', () {
      final m = MapGenerator.zone(kZones[9], 99);
      for (final f in m.floors) {
        final ar = f.arena!;
        expect((ar.cx - (f.bounds.x + f.bounds.w ~/ 2)).abs(), lessThanOrEqualTo(1));
        expect((ar.cy - f.bounds.h ~/ 2).abs(), lessThanOrEqualTo(1));
      }
    });

    test('laberinto: el único recorte de v0.6 (worldgen.md § 11.1)', () {
      final lab = MapGenerator.zone(kZones[5], 7);
      for (final f in lab.floors) {
        // v0.20.22: × √areaScale (worldgen.md § 6.8).
        expect(f.bounds.w, inInclusiveRange(53, 61));
        expect(f.bounds.h, inInclusiveRange(38, 44));
      }
    });

    test('tiles nuevos: escaleras y suelo de vault caminables', () {
      final m = MapGenerator.zone(kZones[0], 42);
      final d = _tile(m.floors.first.stairsDown!);
      final u = _tile(m.floors.last.stairsUp!);
      expect(WorldRules.isSolid(m, d.$1, d.$2, gateOpen: true), isFalse);
      expect(WorldRules.isSolid(m, u.$1, u.$2), isFalse);
      expect(Tile.vaultFloor, ':');
    });
  });
}
