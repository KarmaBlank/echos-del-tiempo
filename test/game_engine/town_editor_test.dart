import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/map_generator.dart';
import 'package:echos_del_tiempo/game_engine/rules/town_plan.dart';
import 'package:echos_del_tiempo/game_engine/rules/town_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// Edición del pueblo (docs/specs/town_editor.md): ampliar por lado,
/// validar lo que se pone, fundir lagos, migrar saves de v0.23 y
/// caminos procedurales.
void main() {
  final rich = PlayerProfile(name: 'Ana', classId: 'guerrero').copyWith(
      credits: 10000000,
      materials: {CraftMaterial.esquirla: 999, CraftMaterial.cristal: 999});

  TownState expand(TownState s, TownSide side) =>
      TownRules.expand(rich, s, side)!.$2;

  test('ampliar por lado: tope por lado y total, y el origen se corre', () {
    var s = const TownState();
    s = expand(s, TownSide.norte);
    s = expand(s, TownSide.oeste);
    expect(s.origin, (kTownStrip, kTownStrip));
    expect(TownPlan.widthOf(s), 34 + kTownStrip);
    expect(TownPlan.heightOf(s), 22 + kTownStrip);
    for (var i = 0; i < TownRules.maxPerSide; i++) {
      s = expand(s, TownSide.este);
    }
    expect(TownRules.cannotExpand(rich, s, TownSide.este), isNotNull);
    while (s.expansions < TownRules.maxExpansions) {
      s = expand(s, TownSide.sur);
    }
    expect(TownRules.cannotExpand(rich, s, TownSide.sur), isNotNull);
    // La huerta base queda en el mismo lugar del pueblo, corrida en el mapa.
    final m = MapGenerator.townOf(s);
    expect(m.townOrigin, s.origin);
    expect(m.tileAt(19 + s.origin.$1, 18 + s.origin.$2), Tile.soil);
  });

  test('poner: valida caminos, otras construcciones y bordes', () {
    final s = expand(const TownState(), TownSide.este);
    // Terreno libre de la franja nueva.
    final ok = TownRules.place(s, 'huerta', 34, 8);
    expect(ok.error, isNull);
    expect(ok.town!.farms.length, 2);
    // Sobre el eje de caminos fijo.
    expect(TownRules.place(s, 'huerta', 15, 15).error, isNotNull);
    // Encima de la huerta base.
    expect(TownRules.place(s, 'lago', 18, 17).error, isNotNull);
    // Fuera del pueblo.
    expect(TownRules.place(s, 'lago', 40, 8).error, isNotNull);
    // Huertas pegadas sí.
    final two = TownRules.place(ok.town!, 'huerta_chica', 34, 12);
    expect(two.error, isNull);
  });

  test('lagos pegados se funden y suman sus peces', () {
    var s = expand(const TownState(), TownSide.este);
    final a = TownRules.place(s, 'lago', 32, 7);
    expect(a.error, isNull);
    s = a.town!;
    s = s.copyWith(builds: [
      for (final b in s.builds)
        b.id == a.id ? b.copyWith(stock: {'trucha_cobre': 2}) : b
    ]);
    final b = TownRules.place(s, 'lago_chico', 32, 13);
    expect(b.error, isNull);
    s = b.town!;
    expect(s.lakes.length, 2, reason: 'base + fundido');
    final merged = s.build(a.id!)!;
    expect(merged.parts.length, 2);
    expect(merged.stock['trucha_cobre'], 2);
    // Mover el lago base contra el fundido: uno solo con todo.
    final base = s.copyWith(builds: [
      for (final x in s.builds)
        x.id == 'l0' ? x.copyWith(stock: {'carpa_musgo': 1}) : x
    ]);
    final moved = TownRules.move(base, 'l0', 30, 13);
    expect(moved.error, isNull, reason: '${moved.error}');
    final one = moved.town!;
    expect(one.lakes.length, 1);
    expect(one.lakes.single.stock, {'trucha_cobre': 2, 'carpa_musgo': 1});
    expect(TownRules.lakeCapacity(one.lakes.single),
        greaterThan(TownRules.lakeCapacity(kBaseLake)));
  });

  test('migración de v0.23: franjas al este, zonas, parcelas y peces', () {
    final old = {
      'exp': 1,
      'zones': ['lago', 'huerta'],
      'stock': {'trucha_cobre': 3},
      'plots': {
        '20,19': {'sd': 'nabo_claro'},
        '34,16': {'sd': 'trigo_dorado'},
      },
    };
    final s = TownState.fromJson(old);
    expect(s.side(TownSide.este), 1);
    expect(s.builds.map((b) => b.id), ['l0', 'h0', 'l1', 'h2']);
    expect(s.build('l1')!.parts.single, const TownRect(33, 7, 6, 6));
    expect(s.build('h2')!.parts.single, const TownRect(33, 15, 6, 4));
    expect(s.build('l0')!.stock, {'trucha_cobre': 3});
    expect(s.plots.keys.toSet(), {'20,19', '34,16'});
    expect(s.build('h2')!.plots.keys, ['1,1']);
    // Ida y vuelta con el formato nuevo.
    final back = TownState.fromJson(s.toJson());
    expect(TownPlan.keyOf(back), TownPlan.keyOf(s));
    expect(back.plots.keys.toSet(), s.plots.keys.toSet());
    // Mover la huerta conserva sus cultivos.
    final mv = TownRules.move(s, 'h2', 33, 16);
    expect(mv.error, isNull, reason: '${mv.error}');
    expect(mv.town!.plots.containsKey('34,17'), isTrue);
  });

  test('caminos procedurales llegan a todo; encerrado no vale', () {
    var s = expand(expand(const TownState(), TownSide.este), TownSide.sur);
    for (final (id, x, y) in [
      ('huerta', 34, 8),
      ('lago', 30, 22),
      ('huerta_chica', 4, 22),
    ]) {
      final r = TownRules.place(s, id, x, y);
      expect(r.error, isNull, reason: '$id: ${r.error}');
      s = r.town!;
    }
    final plan = TownPlan.of(s);
    expect(plan.unreached, isEmpty);
    final map = MapGenerator.townOf(s);
    // Desde la plaza se llega caminando por camino a un tile al lado de
    // cada construcción.
    final (ox, oy) = s.origin;
    final seen = <int>{};
    final todo = [(16 + ox) + (10 + oy) * map.width];
    bool walk(int x, int y) =>
        x >= 0 &&
        y >= 0 &&
        x < map.width &&
        y < map.height &&
        map.tileAt(x, y) == Tile.path;
    while (todo.isNotEmpty) {
      final i = todo.removeLast();
      if (!seen.add(i)) continue;
      final x = i % map.width, y = i ~/ map.width;
      for (final (nx, ny) in [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]) {
        if (walk(nx, ny)) todo.add(nx + ny * map.width);
      }
    }
    for (final b in s.builds) {
      final r = b.bounds;
      var near = false;
      for (var y = r.y - 1; y <= r.bottom && !near; y++) {
        for (var x = r.x - 1; x <= r.right; x++) {
          if (seen.contains((x + ox) + (y + oy) * map.width)) near = true;
        }
      }
      expect(near, isTrue, reason: 'sin camino a ${b.id}');
    }
  });

  test('mover una construcción sobre su propio lugar es válido', () {
    const s = TownState();
    final (ox, oy) = s.origin;
    for (final b in s.builds) {
      final bb = b.bounds;
      final x = bb.x + ox, y = bb.y + oy;
      final back = TownRules.move(s, b.id, x, y);
      expect(back.error, isNull, reason: '${b.id} en su lugar');
      final ok = [
        for (final (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)])
          TownRules.move(s, b.id, x + dx, y + dy).error
      ];
      expect(ok.contains(null), isTrue,
          reason: '${b.id} a un tile pisando su lugar viejo: $ok');
    }
  });
}
