import 'dart:convert';
import 'dart:io';

import 'package:echos_del_tiempo/core/procedural/npc_variants.dart';
import 'package:echos_del_tiempo/features/admin/presentation/editor/npc_variants_controller.dart';
import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/smithing_catalog.dart';
import 'package:echos_del_tiempo/game_engine/rules/biome_fisher_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cuerpo de prueba 6×6: fila 0 vacía, pelo, piel, ropa, pantalón.
Rgba testBody() {
  const rows = [
    '......',
    '.oHHo.',
    '.oSSo.',
    'oCCCCo',
    '.oPPo.',
    '.oPPo.',
  ];
  const colors = {
    'o': 0x1a1420,
    'H': 0xe0c060,
    'S': 0xe8b890,
    'C': 0x6a8a3a,
    'P': 0x4a5a8a,
  };
  final img = Rgba(6, 6);
  for (var y = 0; y < 6; y++) {
    for (var x = 0; x < 6; x++) {
      final c = colors[rows[y][x]];
      if (c != null) img.set(x, y, c);
    }
  }
  return img;
}

final testDoc = NpcVariantsDoc.parse('''
schema: 1
bases:
  b:
    sprite: x
    regions: { '#e0c060': hair, '#e8b890': skin, '#6a8a3a': clothes, '#4a5a8a': pants }
palettes:
  p:
    hair: ['#3a2418', '#6b4226', '#a8743a', '#d8b060', '#8a8a86']
    skin: ['#f2c29b', '#e8b890', '#d9a07a', '#b07850']
    clothes: ['#6a8a3a', '#8a4a3a', '#4a6a8a', '#9a7a3a', '#5a4a6a']
    pants: ['#4a3a2a', '#3a4a6a', '#5a5a4a']
parts:
  cap: { slot: head, anchor: top, pivot: [1, 1], rows: ['ooo', 'aaa'] }
variants:
  v: { base: b, seed: 7, palette: p, parts: [cap] }
''');

void main() {
  test('el documento del repo parsea y cada variante tiene base, paleta y partes', () {
    final doc = NpcVariantsDoc.parse(
        File('assets/sprites/npc_variants.yaml').readAsStringSync());
    expect(doc.variants, isNotEmpty);
    for (final v in doc.variants.values) {
      expect(doc.bases, contains(v.base), reason: v.id);
      expect(doc.palettes, contains(v.palette), reason: v.id);
      for (final p in v.parts) {
        expect(doc.parts, contains(p), reason: '${v.id}: $p');
      }
    }
    // encode → parse conserva todo.
    final again = NpcVariantsDoc.parse(doc.encode());
    expect(again.variants.keys, doc.variants.keys);
    expect(again.parts.keys, doc.parts.keys);
    expect(again.encode(), doc.encode());
  });

  test('NPCs de eventos, mina y campamentos tienen variante propia y distinta', () {
    final doc = NpcVariantsDoc.parse(
        File('assets/sprites/npc_variants.yaml').readAsStringSync());
    final events = jsonDecode(
        File('assets/data/events/world_events.json').readAsStringSync());
    final ids = <String>{};
    void walk(Object? n) {
      if (n is Map) {
        if (n['sprite'] case final String s when s.isNotEmpty) ids.add(s);
        n.values.forEach(walk);
      } else if (n is List) {
        n.forEach(walk);
      }
    }

    walk(events);
    ids.addAll([for (final id in kMineNpcs) 'npc_mina_$id']);
    ids.addAll([for (final f in kBiomeFishers.values) f.sprite]);
    for (final id in ids) {
      expect(doc.variants, contains(id), reason: id);
    }
    final looks = {
      for (final v in doc.variants.values) '${v.base}/${v.seed}/${v.palette}'
    };
    expect(looks.length, doc.variants.length);
  });

  test('misma semilla → misma imagen (determinismo)', () {
    final g = NpcVariantGenerator(testDoc);
    final spec = testDoc.variants['v']!;
    expect(g.generate(testBody(), spec), g.generate(testBody(), spec));
    expect(SeededRng(42).next(), SeededRng(42).next());
  });

  test('semillas distintas → imágenes distintas', () {
    final g = NpcVariantGenerator(testDoc);
    final spec = testDoc.variants['v']!;
    final imgs = {
      for (var s = 1; s <= 12; s++) g.generate(testBody(), spec.copyWith(seed: s)),
    };
    expect(imgs.length, greaterThanOrEqualTo(10));
    expect(g.generate(testBody(), spec.copyWith(seed: 1)),
        isNot(g.generate(testBody(), spec.copyWith(seed: 2))));
  });

  test('el recoloreo conserva la transparencia y lo no mapeado', () {
    final base = testBody();
    final out = NpcVariantGenerator.recolor(
        base, testDoc.bases['b']!.regions, {'hair': 0x112233, 'clothes': 0x445566});
    for (var y = 0; y < 6; y++) {
      for (var x = 0; x < 6; x++) {
        expect(out.alpha(x, y), base.alpha(x, y));
        if (base.alpha(x, y) == 0) {
          expect(out.rgb(x, y), base.rgb(x, y));
        }
      }
    }
    expect(out.rgb(2, 1), 0x112233); // pelo
    expect(out.rgb(1, 3), 0x445566); // ropa
    expect(out.rgb(0, 3), 0x1a1420); // contorno intacto
    expect(out.rgb(2, 2), 0xe8b890); // piel sin color elegido
  });

  test('el retoque de silueta mantiene tamaño y pies', () {
    final base = testBody();
    final out = NpcVariantGenerator.stretch(base, testDoc.bases['b']!.regions);
    expect(out.width, base.width);
    expect(out.height, base.height);
    for (var x = 0; x < 6; x++) {
      expect(out.rgb(x, 5), base.rgb(x, 5));
      expect(out.rgb(x, 0), base.rgb(x, 1)); // la cabeza subió
    }
  });

  testWidgets('todas las variantes del repo resuelven y cargan dentro del presupuesto',
      (tester) async {
    await tester.runAsync(() async {
      final catalog = await SpriteCatalog.load();
      final sw = Stopwatch()..start();
      final imgs = await catalog.npcVariantImages();
      sw.stop();
      expect(imgs.keys.toSet(), catalog.npcVariants.variants.keys.toSet());
      for (final MapEntry(:key, :value) in imgs.entries) {
        final base = catalog.npcVariants.bases[catalog.npcVariants.variants[key]!.base]!;
        final e = catalog.entry('items.${base.sprite}.idle')!;
        final b = (await catalog.image(e))!;
        expect((value.width, value.height), (b.width, b.height), reason: key);
      }
      // Generar todo una vez al cargar: muy por debajo de un frame largo.
      expect(sw.elapsedMilliseconds, lessThan(1500));
      // Cacheado: la segunda llamada devuelve las mismas imágenes.
      final again = await catalog.npcVariantImages();
      expect(identical(again['npc_ev_visitante'], imgs['npc_ev_visitante']), isTrue);
    });
  }, tags: 'perf');

  test('aspecto fijo: ignora la semilla y sobrevive encode/parse', () {
    final g = NpcVariantGenerator(testDoc);
    final spec = testDoc.variants['v']!;
    final fixed = spec.copyWith(fixed: g.roll(spec));
    expect(g.generate(testBody(), fixed.copyWith(seed: 999)),
        g.generate(testBody(), spec));
    final doc = NpcVariantsDoc.parse(testDoc.encode())..variants['v'] = fixed;
    final again = NpcVariantsDoc.parse(doc.encode());
    expect(again.variants['v']!.fixed, isNotNull);
    expect(NpcVariantGenerator(again).generate(testBody(), again.variants['v']!),
        g.generate(testBody(), spec));
  });

  testWidgets('Editor: re-roll, guardar como fijo y NPC nuevo', (tester) async {
    await tester.runAsync(() async {
      final catalog = await SpriteCatalog.load();
      final store = _MemStore();
      final c = NpcVariantsController(catalog: catalog, store: store);
      final seed = c.selected!.seed;
      c.reroll();
      expect(c.selected!.seed, isNot(seed));
      await c.saveFixed();
      expect(c.selected!.fixed, isNotNull);
      expect(NpcVariantsDoc.parse(store.yaml).variants[c.selectedId]!.fixed,
          isNotNull);
      expect(c.createFrom('npc_nuevo_test'), isTrue);
      expect(c.createFrom('npc_nuevo_test'), isFalse);
      await c.save();
      expect(NpcVariantsDoc.parse(store.yaml).variants, contains('npc_nuevo_test'));
      c.dispose();
    });
  });
}

class _MemStore implements NpcVariantsOverrideSource {
  String? yaml;
  @override
  Future<String?> readNpcVariants() async => yaml;
  @override
  Future<void> putNpcVariants(String y) async => yaml = y;
}
