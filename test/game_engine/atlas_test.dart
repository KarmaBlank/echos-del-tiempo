import 'package:echos_del_tiempo/game_engine/data/eco_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/atlas.dart';
import 'package:echos_del_tiempo/game_engine/rules/atlas_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// Atlas del Tiempo (docs/specs/ecos_atlas.md § 5).
const rules = AtlasRules();

/// Un Atlas con [points] puntos ganados (primeras veces de zona y jefe).
AtlasProgress withPoints(int points, {List<String> nodes = const []}) {
  final done = <String>[];
  for (var i = 1; done.length < points && i <= 10; i++) {
    done.add('z$i');
  }
  for (var i = 1; done.length < points && i <= 10; i++) {
    done.add('b$i');
  }
  return AtlasProgress(nodes: nodes, done: done);
}

void main() {
  test('catálogo: ~25 nodos, ids únicos, uniones válidas, 51 de costo', () {
    expect(kAtlasNodes.length, inInclusiveRange(20, 30));
    expect(kAtlasById, hasLength(kAtlasNodes.length));
    final cells = <(int, int)>{};
    for (final n in kAtlasNodes) {
      expect(cells.add((n.x, n.y)), isTrue, reason: 'celda repetida ${n.id}');
      expect(n.x, inInclusiveRange(-4, 4));
      expect(n.y, inInclusiveRange(-3, 3));
      for (final l in n.links) {
        expect(kAtlasById.containsKey(l), isTrue, reason: '${n.id} → $l');
      }
    }
    final cost =
        kAtlasNodes.where((n) => !n.locked).fold(0, (a, n) => a + n.cost);
    expect(cost, 51);
    expect(AtlasRules.maxPoints, 44, reason: 'no alcanza para todo');
    expect(kAtlasNodes.where((n) => n.locked).map((n) => n.id),
        ['grieta', 'grietamayor']);
  });

  test('puntos: primera vez de cada tier, zona y jefe', () {
    var p = AtlasProgress();
    var g = rules.complete(p, tier: 1, zone: 3, boss: 7);
    expect(g.points, 3);
    expect(g.keys, ['t1', 'z3', 'b7']);
    p = g.progress;
    g = rules.complete(p, tier: 1, zone: 3, boss: 7);
    expect(g.points, 0, reason: 'repetido');
    expect(identical(g.progress, p), isTrue);
    g = rules.complete(p, tier: 9, zone: 3, boss: 2);
    expect(g.points, 3, reason: 'tier 9 vale 2 + jefe nuevo');
    expect(rules.earned(g.progress), 6);
    expect(AtlasRules.pointsFor('t8'), 1);
    expect(AtlasRules.pointsFor('t16'), 2);
  });

  test('tomar: unido, con puntos y no bloqueado', () {
    var p = withPoints(4);
    expect(rules.cannotTake(p, 'potencia'), 'No está unido a tu Atlas');
    expect(rules.cannotTake(p, 'grieta'), 'Próximamente');
    expect(rules.cannotTake(p, 'nada'), 'Nodo desconocido');
    p = rules.take(p, 'gratis')!;
    p = rules.take(p, 'potencia')!;
    expect(rules.free(p), 0);
    expect(rules.cannotTake(p, 'brillo'), 'Faltan puntos (2)');
    expect(rules.cannotTake(p, 'gratis'), 'Ya lo tenés');
    expect(rules.has(p, AtlasRules.rootId), isTrue);
  });

  test('reiniciar es gratis y conserva las primeras veces', () {
    final p = withPoints(6, nodes: ['rutas', 'helada']);
    final r = rules.reset(p);
    expect(r.nodes, isEmpty);
    expect(r.done, p.done);
    expect(rules.free(r), 6);
  });

  test('sanitize: ordena, saca inválidos y corta lo que no alcanza', () {
    final p =
        withPoints(5, nodes: ['helada', 'nada', 'rutas', 'grieta', 'brillo']);
    final s = rules.sanitize(p);
    // Helada queda sin puntos: rutas y brillo se tomaron antes.
    expect(s.nodes, ['rutas', 'brillo']);
    expect(s.done, p.done);
  });

  test('efectos suman por clave', () {
    final fx = rules.effects([
      'rutas',
      'verde',
      'abundancia',
      'cornucopia',
      'brillo',
      'destello',
      'gratis',
      'gratis2',
      'potencia',
      'templado',
      'maestro',
      'fortuna',
      'trofeo',
      'codicia',
      'anclas',
      'corona',
      'ecojefe',
      'cofres',
      'resonancia',
      'grieta',
      'nada',
    ]);
    expect(fx.ecoDrop, 0.25);
    expect(fx.zones, {1, 2});
    expect(fx.quantity, closeTo(0.20, 1e-9));
    expect(fx.rarity, closeTo(0.16, 1e-9));
    expect(fx.freeMods, 2);
    expect(fx.modPower, 0.2);
    expect(fx.tempered, 0.25);
    expect(fx.xp, 0.2);
    expect(fx.legendary, 0.5);
    expect(fx.bossWeapons, 1);
    expect(fx.eliteWeapons, 1);
    expect(fx.anchor, 0.5);
    expect(fx.bossUnique, 0.1);
    expect(fx.bossEcos, 1);
    expect(fx.chests, 1);
    expect(fx.extraEco, 0.3);
    expect(fx.tierUp, 0.15);
    expect(rules.effects(const []).freeMods, 0);
  });

  test('JSON: ida y vuelta, tolerante', () {
    final p = withPoints(4, nodes: ['gratis', 'potencia']);
    final back = AtlasProgress.fromJson(p.toJson());
    expect(back, p);
    expect(AtlasProgress.fromJson(null), AtlasProgress());
    expect(
        AtlasProgress.fromJson({
          'n': ['a', 'a', 3],
          'd': 'x'
        }).nodes,
        ['a']);
  });
}
