import 'dart:io';
import 'dart:typed_data';

import 'package:echos_del_tiempo/features/admin/domain/sprites/art_pack.dart';
import 'package:echos_del_tiempo/features/admin/domain/sprites/png_validator.dart';
import 'package:echos_del_tiempo/features/admin/presentation/admin_app.dart';
import 'package:echos_del_tiempo/features/admin/presentation/admin_controller.dart';
import 'package:echos_del_tiempo/features/admin/presentation/editor/sprite_editor_controller.dart';
import 'package:echos_del_tiempo/features/combat/data/local_sprite_overrides_io.dart';
import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/enemies_catalog.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show ValueKey;
import 'package:yaml/yaml.dart';

import 'fake_admin_host.dart';

/// Bundle que lee del disco del repo (sin tocar el rootBundle).
class _DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final f = File(key);
    if (!f.existsSync()) throw StateError('no existe $key');
    return ByteData.sublistView(f.readAsBytesSync());
  }
}

/// PNG mínimo (firma + IHDR + IEND): alcanza para el validador.
Uint8List fakePng(int w, int h, {int colorType = 6, int extra = 0}) {
  final b = BytesBuilder()
    ..add([137, 80, 78, 71, 13, 10, 26, 10])
    ..add([0, 0, 0, 13])
    ..add('IHDR'.codeUnits);
  final d = ByteData(13)
    ..setUint32(0, w)
    ..setUint32(4, h)
    ..setUint8(8, 8)
    ..setUint8(9, colorType);
  b
    ..add(d.buffer.asUint8List())
    ..add([0, 0, 0, 0])
    ..add([0, 0, 0, 0])
    ..add('IEND'.codeUnits)
    ..add([0, 0, 0, 0])
    ..add(Uint8List(extra));
  return b.toBytes();
}

void main() {
  final manifestText = File(SpriteCatalog.manifestPath).readAsStringSync();
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('ecos_editor_'));
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  group('catálogo', () {
    final cat = SpriteCatalog.fromYaml(manifestText, bundle: _DiskBundle());

    test('lista todo lo del manifest, por categoría', () {
      final manifest = loadYaml(manifestText) as YamlMap;
      var expected = 0;
      for (final s in SpriteCatalog.sections) {
        for (final v in (manifest[s] as YamlMap).values) {
          final m = v as YamlMap;
          expected += m['procedural'] == true
              ? 1
              : m.values.whereType<String>().where((p) => p.endsWith('.png')).length;
        }
      }
      final entries = cat.entries;
      expect(entries.length, expected);
      expect(entries.map((e) => e.id).toSet().length, expected, reason: 'ids únicos');
      for (final c in SpriteCategory.values) {
        expect(entries.where((e) => e.category == c), isNotEmpty, reason: c.label);
      }
      for (final e in entries.where((e) => e.category == SpriteCategory.bosses)) {
        expect(kEnemies[e.key]?.boss == true || e.key.contains('Fase2'), isTrue, reason: e.id);
      }
      expect(cat.entry('characters.guerrero.idle')!.path, 'characters/guerrero/idle.png');
      // Desde v0.25.8 los íconos de armas son PNG (tool/export_item_icons.dart).
      expect(cat.entry('items.espada.idle')!.path, 'items/espada.png');
      expect(cat.entry('tiles.suelo.idle')!.procedural, isTrue);
      expect(cat.entry('items.espada.idle')!.expectedSize, (16, 16));
      expect(cat.entry('fx.tajo.idle')!.publishPath, 'effects/tajo.png');
    });

    test('búsqueda por id, ruta y categoría, sin tildes ni mayúsculas', () {
      List<String> find(String q) =>
          [for (final e in cat.entries) if (e.matches(q)) e.id];
      expect(find('guerrero'), contains('characters.guerrero.idle'));
      expect(find('GUERRERO berserker'),
          ['characters.guerrero_berserker.idle', 'characters.aura_berserker.idle']);
      expect(find('ÁRBOL'), isEmpty);
      expect(find('baculo'), contains('items.baculo.idle'));
      expect(find('efectos'), everyElement(startsWith('fx.')));
      expect(find(''), hasLength(cat.entries.length));
    });
  });

  group('overrides', () {
    test('el override pisa al asset y se revierte', () async {
      final o = LocalSpriteOverrides('${tmp.path}/overrides');
      await o.refresh();
      final cat = SpriteCatalog.fromYaml(manifestText, bundle: _DiskBundle(), overrides: o);
      final e = cat.entry('characters.guerrero.idle')!;
      final asset = await cat.bytes(e);
      expect(asset, isNotNull);
      expect(cat.hasOverride(e.id), isFalse);

      final mine = File('assets/sprites/characters/maga/idle.png').readAsBytesSync();
      await o.put(e.id, mine);
      await cat.reload(e.id);
      expect(cat.hasOverride(e.id), isTrue);
      expect(await cat.bytes(e), mine);
      expect(await cat.assetBytes(e), asset, reason: 'el asset queda intacto');
      // Otro catálogo (p. ej. main_dev) lo ve al releer el disco.
      final o2 = LocalSpriteOverrides('${tmp.path}/overrides');
      await o2.refresh();
      expect(o2.overriddenIds, {e.id});

      await o.remove(e.id);
      await cat.reload(e.id);
      expect(cat.hasOverride(e.id), isFalse);
      expect(await cat.bytes(e), asset);
      // Las procedurales: sin imagen hasta que hay override.
      final p = cat.entry('tiles.suelo.idle')!;
      expect(await cat.bytes(p), isNull);
      await o.put(p.id, mine);
      expect(await cat.bytes(p), mine);
    });

    test('nunca en la carpeta de datos del juego', () {
      final appData = Platform.environment['APPDATA'];
      if (appData == null) return;
      expect(() => LocalSpriteOverrides('$appData\\EcosDelTiempo\\overrides'),
          throwsStateError);
    });

    test('exportar/importar paquete de arte ida y vuelta', () async {
      final a = LocalSpriteOverrides('${tmp.path}/a');
      final png1 = fakePng(16, 16);
      final png2 = File('assets/sprites/characters/maga/idle.png').readAsBytesSync();
      await a.put('items.espada.idle', png1);
      await a.put('characters.maga.idle', png2);
      final zip = await a.exportPack();

      final b = LocalSpriteOverrides('${tmp.path}/b');
      final ids = await b.importPack(zip);
      expect(ids.toSet(), {'items.espada.idle', 'characters.maga.idle'});
      expect(await b.read('items.espada.idle'), png1);
      expect(await b.read('characters.maga.idle'), png2);
      expect(() => ArtPack.decode(Uint8List.fromList([1, 2, 3])), throwsFormatException);
    });

    test('publicar al repo copia el PNG y actualiza el manifest', () async {
      final repo = '${tmp.path}/repo';
      File('$repo/assets/sprites/sprite_manifest.yaml')
        ..createSync(recursive: true)
        ..writeAsStringSync(manifestText);
      final o = LocalSpriteOverrides('${tmp.path}/ov');
      final cat = SpriteCatalog.fromYaml(manifestText, bundle: _DiskBundle(), overrides: o);
      final espada = cat.entry('items.espada.idle')!;
      final guerrero = cat.entry('characters.guerrero.idle')!;
      final png = fakePng(16, 16);
      await o.put(espada.id, png);
      await o.put(guerrero.id, png);

      final done = await o.publish(repo, [espada, guerrero]);
      expect(done, [espada.id, guerrero.id]);
      expect(File('$repo/assets/sprites/items/espada.png').readAsBytesSync(), png);
      expect(File('$repo/assets/sprites/characters/guerrero/idle.png').readAsBytesSync(), png);
      expect(o.overriddenIds, isEmpty);
      final after = SpriteCatalog.fromYaml(
          File('$repo/assets/sprites/sprite_manifest.yaml').readAsStringSync());
      expect(after.entry(espada.id)!.path, 'items/espada.png');
      expect(after.entries.length, cat.entries.length);
      expect(after.enemyScale('golem'), cat.enemyScale('golem'));
    });
  });

  group('validación de PNG', () {
    test('rechaza tamaños incorrectos y acepta múltiplos con aviso', () {
      expect(validateSpritePng(fakePng(16, 16), expected: (16, 16)).ok, isTrue);
      final wrong = validateSpritePng(fakePng(20, 16), expected: (16, 16));
      expect(wrong.ok, isFalse);
      expect(wrong.errors.single, contains('20x16'));
      final x2 = validateSpritePng(fakePng(32, 32), expected: (16, 16));
      expect(x2.ok, isTrue);
      expect(x2.warnings.single, contains('×2'));
      expect(validateSpritePng(fakePng(32, 16), expected: (16, 16)).ok, isFalse);
    });

    test('exige PNG con alfa y ≤ 1 MB; avisa semitransparencia y paleta', () {
      expect(validateSpritePng(Uint8List.fromList([1, 2, 3])).ok, isFalse);
      expect(validateSpritePng(fakePng(16, 16, colorType: 2)).ok, isFalse);
      expect(validateSpritePng(fakePng(16, 16, extra: kMaxSpriteBytes)).ok, isFalse);
      final rgba = Uint8List(4 * 40);
      for (var i = 0; i < 40; i++) {
        rgba.setAll(i * 4, [i * 6, 0, 0, i == 0 ? 128 : 255]);
      }
      final v = validateSpritePng(fakePng(40, 1),
          expected: (40, 1), pixels: RgbaPixels(40, 1, rgba));
      expect(v.ok, isTrue);
      expect(v.warnings, hasLength(2));
    });

    test('el PNG real del repo pasa', () {
      final png = File('assets/sprites/characters/guerrero/idle.png').readAsBytesSync();
      final info = PngInfo.parse(png)!;
      expect(validateSpritePng(png, expected: (info.width, info.height)).ok, isTrue);
    });
  });

  testWidgets('Editor: Visuales → Sprites, reemplazar y ver el override', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final o = LocalSpriteOverrides('${tmp.path}/ov');
    final cat = SpriteCatalog.fromYaml(manifestText, bundle: _DiskBundle(), overrides: o);
    final files = _FakeFiles();
    final s = SpriteEditorController(catalog: cat, overrides: o, files: files, repoPath: tmp.path);
    final c = AdminController(host: FakeAdminHost(files: {
      'repo/pubspec.yaml': File('pubspec.yaml').readAsStringSync(),
      'repo/assets/balance/balance.json':
          File('assets/balance/balance.json').readAsStringSync(),
    }));
    await tester.runAsync(() async {
      await c.load();
      await s.loadAll();
    });
    await tester.pumpWidget(AdminApp(controller: c, sprites: s, initialArea: EditorArea.visuals));
    expect(find.text('SPRITES'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('sprite-search')).last, 'maga');
    await tester.pump();
    expect(s.visible.every((e) => e.matches('maga')), isTrue);
    final e = cat.entry('characters.maga.idle')!;
    await tester.runAsync(() => s.select(e));
    await tester.pump();
    // Tamaño incorrecto: no guarda.
    files.png = fakePng(3, 5);
    await tester.runAsync(s.pickAndReplace);
    await tester.pump();
    expect(cat.hasOverride(e.id), isFalse);
    expect(s.notice!.error, isTrue);
    // Mismo tamaño: guarda, recarga y muestra la insignia.
    files.png = File('assets/sprites/characters/maga/elementalista.png').readAsBytesSync();
    await tester.runAsync(s.pickAndReplace);
    await tester.pump();
    expect(cat.hasOverride(e.id), isTrue);
    expect(find.text('OVERRIDE'), findsWidgets);
    expect(find.text('AHORA (OVERRIDE)'), findsOneWidget);
    await tester.runAsync(s.discard);
    await tester.pump();
    expect(cat.hasOverride(e.id), isFalse);
  });
}

class _FakeFiles implements EditorFiles {
  Uint8List? png;
  @override
  Future<Uint8List?> pickPng() async => png;
  @override
  Future<Uint8List?> pickZip() async => null;
  @override
  Future<bool> saveZip(Uint8List bytes, String suggestedName) async => false;
}
