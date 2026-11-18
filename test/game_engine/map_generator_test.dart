import 'package:echos_del_tiempo/game_engine/data/missions_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/models/mission_def.dart';
import 'package:echos_del_tiempo/game_engine/rules/map_generator.dart';
import 'package:echos_del_tiempo/game_engine/rules/mulberry32.dart';
import 'package:flutter_test/flutter_test.dart';

// Los valores esperados salen de correr las funciones originales del
// prototipo (`rng`, `lobbyMap`, `genMap`) con node 20 sobre
// ecos-del-tiempo.html. `fnv` es FNV-1a de 32 bits sobre las filas del
// mapa unidas con '\n', calculado igual en JS.

MissionDef _mission(String id) => kPrototypeMissions.firstWhere((m) => m.id == id);

int _fnv(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h ^= c;
    h = imul32(h, 0x01000193);
  }
  return h;
}

void main() {
  group('mulberry32', () {
    test('misma secuencia que rng() del prototipo', () {
      final r = mulberry32(12345);
      expect([r(), r(), r(), r(), r()], [
        0.9797282677609473,
        0.3067522644996643,
        0.484205421525985,
        0.817934412509203,
        0.5094283693470061,
      ]);
    });

    test('semillas negativas como `s|=0` de JS', () {
      final r = mulberry32(-7);
      expect([r(), r(), r()],
          [0.43306733411736786, 0.32539576734416187, 0.5442695003002882]);
    });

    test('imul32 = Math.imul (en 32 bits sin signo)', () {
      expect(imul32(0xFFFFFFFF, 5), (-5) & 0xFFFFFFFF);
      expect(imul32(0x7FFFFFFF, 0x7FFFFFFF), 1);
      expect(imul32(123456789, 987654321), 0xFBFF5385);
    });
  });

  test('lobby: idéntico a lobbyMap()', () {
    final m = MapGenerator.lobby();
    expect(m.rows, [
      '##########################',
      '#,,,,,,,,,,,,,,,,,,,,,,,,#',
      // v0.4: Portal del Eco (P) a la izquierda del mostrador
      // (docs/specs/ecos_atlas.md § 1).
      '#..PPP...CCCCCCCC..AAAAA.#',
      '#...........,,...........#',
      '#...........,,...........#',
      '#...........,,...........#',
      '#...........,,...........#',
      '#..~~~......,,......~~~..#',
      '#..~~~......,,......~~~..#',
      '#...........,,...........#',
      // v0.5: Estatua del Tiempo (S) debajo de la fuente derecha
      // (docs/specs/ascension.md § 1).
      '#...........,,......SSS..#',
      '#...........,,...........#',
      '#...........,,...........#',
      '##########################',
    ]);
    expect(m.spawn, const WorldPoint(208, 144));
    expect(m.lobby, isTrue);
  });

  group('genMap', () {
    // (misión, semilla, ancho, alto, lado, arena x/y, salas, spawn, jefe,
    //  nº de spots, primer spot, último spot, fnv)
    const cases = [
      ('m1', 12345, 76, 47, 'W', 2, 26, 13, WorldPoint(1064, 120), WorldPoint(136, 520), 792, (21, 30), (57, 7), 2750669022),
      ('m2', 987654321, 76, 45, 'E', 61, 27, 13, WorldPoint(184, 184), WorldPoint(1080, 536), 625, (22, 15), (19, 22), 2025269396),
      ('m3', 42, 70, 48, 'S', 37, 33, 12, WorldPoint(216, 104), WorldPoint(696, 632), 571, (18, 15), (19, 28), 1391280857),
      ('m1', 7, 60, 44, 'S', 32, 29, 9, WorldPoint(248, 184), WorldPoint(616, 568), 348, (23, 6), (40, 12), 4243445394),
      ('m2', 2024, 73, 51, 'N', 40, 2, 13, WorldPoint(136, 568), WorldPoint(744, 136), 721, (23, 21), (38, 41), 728074629),
      ('m3', 555555, 61, 48, 'S', 21, 33, 12, WorldPoint(792, 120), WorldPoint(440, 632), 494, (21, 2), (18, 19), 342797600),
    ];
    for (final c in cases) {
      test('${c.$1} semilla ${c.$2}', () {
        final m = MapGenerator.generate(_mission(c.$1), c.$2);
        expect(m.width, c.$3);
        expect(m.height, c.$4);
        expect(m.rows.length, c.$4);
        expect(m.rows.every((r) => r.length == c.$3), isTrue);
        expect(m.side, c.$5);
        expect(m.arena!.x, c.$6);
        expect(m.arena!.y, c.$7);
        expect(m.rooms.length, c.$8);
        expect(m.spawn, c.$9);
        expect(m.boss, c.$10);
        expect(m.spots.length, c.$11);
        expect(m.spots.first, c.$12);
        expect(m.spots.last, c.$13);
        expect(_fnv(m.rows.join('\n')), c.$14);
        expect(m.theme, _mission(c.$1).theme);
        expect(m.merchant, isNull);
      });
    }

    test('filas 28-33 de m1/12345 (barrera del jefe al oeste)', () {
      final m = MapGenerator.generate(_mission('m1'), 12345);
      expect(m.rows.sublist(28, 34), [
        '##..#.......#..##########,,#################.......###..........#####,,#####',
        '##.............##########,,#################.......###..........#####,,#####',
        '##.............######.........#################,,#####..........##.......###',
        '##.............G#####.........#################,,#####..........##.......###',
        '##.............G,,,,,.........#################,,#########,,######.......###',
        '##.............G,,,,,.........#################,,#########,,######.......###',
      ]);
    });

    test('misma semilla, mismo mapa', () {
      final a = MapGenerator.generate(_mission('m2'), 31337);
      final b = MapGenerator.generate(_mission('m2'), 31337);
      expect(a.rows, b.rows);
    });
  });
}
