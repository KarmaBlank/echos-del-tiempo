import 'package:echos_del_tiempo/game_engine/data/exploration_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/game_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/trials_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/zones_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/models/zone_def.dart';
import 'package:echos_del_tiempo/game_engine/rules/map_generator.dart';
import 'package:echos_del_tiempo/game_engine/rules/trial_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/world_rules.dart';
import 'package:echos_del_tiempo/game_engine/data/tuning_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

/// BFS (pasos) desde [from] caminando sin caerse, con la barrera abierta.
Map<(int, int), int> _bfs(GameMap m, Iterable<(int, int)> from) {
  final d = <(int, int), int>{};
  final q = <(int, int)>[];
  for (final s in from) {
    if (d.containsKey(s)) continue;
    if (WorldRules.isSolid(m, s.$1, s.$2, gateOpen: true, blockVoid: true)) {
      continue;
    }
    d[s] = 0;
    q.add(s);
  }
  for (var i = 0; i < q.length; i++) {
    final (x, y) = q[i];
    for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
      final n = (x + dx, y + dy);
      if (d.containsKey(n)) continue;
      if (WorldRules.isSolid(m, n.$1, n.$2, gateOpen: true, blockVoid: true)) {
        continue;
      }
      d[n] = d[(x, y)]! + 1;
      q.add(n);
    }
  }
  return d;
}

(int, int) _t(WorldPoint p) => ((p.x / 16).floor(), (p.y / 16).floor());

/// Tiles caminables junto a cada PdI del piso (y los PdI pisables).
List<(int, int)> _sources(MapFloor f) => [
      _t(f.spawn),
      if (f.stairsUp != null) _t(f.stairsUp!),
      (f.arena!.cx, f.arena!.cy),
      ...f.chestMarks,
      ...f.eliteMarks,
      ...f.chestSpots,
      for (final p in f.pois)
        for (final (dx, dy) in const [(0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)])
          (p.tx + dx, p.ty + dy),
    ];

void main() {
  final seeds = [for (var i = 1; i <= 20; i++) i * 7919 + 3];

  group('densidad de interés (worldgen.md § 11.2)', () {
    // La densidad de PdI se mide con el área base del generador; el
    // recorte de v0.20.22 (worldgen.md § 6.8) la deja apenas por encima.
    setUpAll(() => kTuning[TuningId.mission] = const TuningDef(
        'Misiones', {'maxFloors': 3, 'groupScale': 0.7, 'areaScale': 1}));
    tearDownAll(() =>
        kTuning[TuningId.mission] = kTuningDefaults[TuningId.mission]!);
    for (final z in kZones) {
      test('${z.name}: PdI a ≤ gap de todo tile caminable', () {
        final gap = z.gen == ZoneGen.laberinto ? kMaxPoiGapMaze : kMaxPoiGap;
        var floors = 0, secrets = 0, quests = 0;
        for (final seed in seeds) {
          final m = MapGenerator.zone(z, seed);
          for (final f in m.floors) {
            floors++;
            final why = '${z.id} semilla $seed piso ${f.index}';
            final reach = _bfs(m, [_t(f.spawn)]);
            final d = _bfs(m, _sources(f));
            var worst = 0;
            for (final t in reach.keys) {
              final v = d[t];
              expect(v, isNotNull, reason: '$why: $t sin PdI alcanzable');
              if (v! > worst) worst = v;
            }
            expect(worst, lessThanOrEqualTo(gap), reason: why);
            final pois = f.chestSpots.length + f.chestMarks.length + f.pois.length;
            expect(pois * 220, greaterThanOrEqualTo(reach.length), reason: why);
            expect(f.chestSpots.length, greaterThanOrEqualTo(kMinChestSpots));
            secrets += f.pois.where((p) => p.kind == PoiKind.secret).length;
            quests += f.quests.length;
            expect(f.quests.length, inInclusiveRange(1, 2), reason: why);
          }
        }
        expect(secrets, greaterThan(floors ~/ 2), reason: 'salas secretas');
        expect(quests, greaterThanOrEqualTo(floors));
      });
    }
  });

  group('puntos de interés', () {
    test('ids únicos, en su piso, tiles correctos y salas cerradas', () {
      for (final z in kZones) {
        for (final seed in seeds.take(8)) {
          final m = MapGenerator.zone(z, seed);
          final ids = <int>{};
          for (final f in m.floors) {
            final reach = _bfs(m, [_t(f.spawn)]);
            for (final p in f.pois) {
              final why = '${z.id} $seed ${p.kind} ${p.id}';
              expect(ids.add(p.id), isTrue, reason: why);
              expect(p.floor, f.index);
              expect(p.id ~/ 100, f.index);
              expect(f.containsTile(p.tx, p.ty), isTrue, reason: why);
              final c = m.tileAt(p.tx, p.ty);
              switch (p.kind) {
                case PoiKind.secret:
                  expect(c, Tile.cracked, reason: why);
                  final ch = p.chest!;
                  expect(m.tileAt(ch.$1, ch.$2), Tile.secretFloor);
                  // Cerrada hasta abrir la pared; abierta, se llega.
                  expect(reach.containsKey(ch), isFalse, reason: why);
                  expect(f.spots.contains(ch), isFalse);
                case PoiKind.shrine:
                  expect(c, Tile.shrine, reason: why);
                case PoiKind.waystone:
                  expect(c, Tile.waystone, reason: why);
                case PoiKind.wind:
                  expect(c, Tile.wind, reason: why);
                case PoiKind.shortcut:
                  expect(c, Tile.shortcut, reason: why);
                  expect(reach.containsKey(p.side!), isTrue, reason: why);
                case PoiKind.brazier:
                  expect(c, Tile.brazier, reason: why);
                  expect(f.quests.any((q) => q.id == p.quest), isTrue);
                case PoiKind.relic:
                  expect(reach.containsKey((p.tx, p.ty)), isTrue, reason: why);
              }
              if (p.kind != PoiKind.relic && p.kind != PoiKind.secret &&
                  p.kind != PoiKind.shortcut) {
                // Objeto suelto: se llega a algún vecino.
                expect(
                    [(1, 0), (-1, 0), (0, 1), (0, -1)].any(
                        (o) => reach.containsKey((p.tx + o.$1, p.ty + o.$2))),
                    isTrue,
                    reason: why);
              }
            }
            for (final q in f.quests) {
              expect(ids.add(q.id), isTrue);
              expect(q.id ~/ 100, f.index);
              if (q.kind == QuestKind.guardian) expect(f.last, isFalse);
              if (q.kind == QuestKind.secreto) {
                expect(f.pois.any((p) => p.kind == PoiKind.secret), isTrue);
              }
              if (q.kind == QuestKind.braseros) {
                expect(
                    f.pois.where((p) => p.quest == q.id).length, kBraziers);
              }
            }
          }
        }
      }
    });

    test('determinístico por semilla', () {
      for (final z in kZones) {
        final a = MapGenerator.zone(z, 4242), b = MapGenerator.zone(z, 4242);
        for (var i = 0; i < a.floors.length; i++) {
          String sig(MapFloor f) => [
                for (final p in f.pois) '${p.id}${p.kind}${p.tx},${p.ty}${p.variant}',
                for (final q in f.quests) '${q.id}${q.kind}${q.reward}',
                ...f.chestSpots.map((c) => '$c'),
              ].join('|');
          expect(sig(a.floors[i]), sig(b.floors[i]));
        }
      }
    });

    test('laberinto: único recorte, más chico que antes y sin rodeos de 200', () {
      for (final seed in seeds) {
        final m = MapGenerator.zone(kZones[5], seed);
        for (final f in m.floors) {
          // v0.20.22: × √areaScale (worldgen.md § 6.8).
          expect(f.bounds.w, inInclusiveRange(53, 61));
          expect(f.bounds.h, inInclusiveRange(38, 44));
          final d = _bfs(m, [_t(f.spawn)]);
          expect(d[(f.arena!.cx, f.arena!.cy)], lessThanOrEqualTo(160));
        }
      }
      // El resto conserva su rango de siempre (con el mismo recorte).
      final pr = MapGenerator.zone(kZones[0], 7).floors.first.bounds;
      expect(pr.w, inInclusiveRange(49, 59)); // 58–70 × √0.7
    });
  });

  test('Pruebas: todas las trampas entran con los PdI', () {
    const rules = TrialRules(catalog: GameCatalog.standard);
    int count(GameMap m, MapFloor f, String tile) {
      var n = 0;
      for (var y = f.bounds.y; y < f.bounds.y + f.bounds.h; y++) {
        for (var x = f.bounds.x; x < f.bounds.x + f.bounds.w; x++) {
          if (m.tileAt(x, y) == tile) n++;
        }
      }
      return n;
    }

    for (final t in kTrials) {
      for (final seed in seeds.take(6)) {
        final m = rules.map(t, seed);
        for (final f in m.floors) {
          // Púas 2×2 y pulsos 3×3 (algún tile puede caer en pared).
          expect(count(m, f, Tile.spikes), greaterThanOrEqualTo(t.spikes * 2),
              reason: '${t.name} $seed');
          expect(count(m, f, Tile.pulse), greaterThanOrEqualTo(t.pulses * 3));
          for (final p in f.pois) {
            if (p.kind == PoiKind.relic) continue;
            expect(Tile.poiTiles.contains(m.tileAt(p.tx, p.ty)), isTrue);
          }
        }
      }
    }
  });
}
