// Arte procedural con perillas (docs/specs/game_editor.md § 7.5).
// Overrides en carpetas temporales (nunca %APPDATA% ni el repo).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/core/procedural/item_icons.dart';
import 'package:echos_del_tiempo/core/procedural/procedural_art.dart';
import 'package:echos_del_tiempo/features/admin/domain/sprites/art_pack.dart';
import 'package:echos_del_tiempo/features/admin/presentation/editor/sprite_editor_controller.dart';
import 'package:echos_del_tiempo/features/combat/data/local_sprite_overrides_io.dart';
import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/item_widgets.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final f = File(key);
    if (!f.existsSync()) throw StateError('no existe $key');
    return ByteData.sublistView(f.readAsBytesSync());
  }
}

/// Copia fiel del pintor anterior a § 7.5 (referencia de "sin cambio
/// visual" con los valores por defecto).
void _legacyPaint(Canvas canvas, Size size, List<String> rows, Color accent) {
  const metal = Color(0xFFC8D2FF);
  const handle = Color(0xFFA0703C);
  const string = Color(0xFFE8ECFF);
  const paper = Color(0xFFE8DCC0);
  const cover = Color(0xFF8E3B46);
  const glass = Color(0xFFDDE6FF);
  final px = size.width / 8;
  final paint = Paint()..isAntiAlias = false;
  for (var y = 0; y < rows.length; y++) {
    for (var x = 0; x < rows[y].length; x++) {
      final color = switch (rows[y][x]) {
        'm' => metal,
        'h' => handle,
        'g' => accent,
        's' => string,
        'p' => paper,
        'c' => cover,
        'w' => glass,
        _ => null,
      };
      if (color == null) continue;
      paint.color = color;
      canvas.drawRect(Rect.fromLTWH(x * px, y * px, px, px), paint);
    }
  }
}

Future<Uint8List> _render(void Function(Canvas c, Size s) draw) async {
  const size = Size(64, 64);
  final rec = ui.PictureRecorder();
  draw(Canvas(rec), size);
  final img = await rec.endRecording().toImage(64, 64);
  final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  img.dispose();
  return data!.buffer.asUint8List();
}

Future<Uint8List> _icon(String shape, String entryId,
        [Color accent = const Color(0xFF55EFC4)]) =>
    _render((c, s) => paintItemIcon(c, Offset.zero & s, kItemIconRows[shape]!,
        accent, ProceduralArt.instance.resolve(entryId)));

void main() {
  final art = ProceduralArt.instance;
  setUp(art.reset);
  tearDown(art.reset);

  testWidgets('por defecto: píxeles idénticos al pintor anterior', (t) async {
    await t.runAsync(() async {
      for (final MapEntry(key: shape, value: rows) in kItemIconRows.entries) {
        const accent = Color(0xFFFF7B29);
        final before =
            await _render((c, s) => _legacyPaint(c, s, rows, accent));
        final now = await _icon(shape, 'items.$shape', accent);
        expect(now, before, reason: shape);
      }
    });
  });

  testWidgets('un override cambia el dibujo y al descartarlo vuelve', (t) async {
    await t.runAsync(() async {
      final base = await _icon('espada', 'items.espada');
      for (final p in <String, Object>{
        'metal': '#ff0000',
        'shine': 0.3,
        'outline': true,
        'gem': true,
        'mirror': true,
        'scale': 0.75,
        'highlight': true,
      }.entries) {
        art.setOverride(ProcDoc(entries: {
          'items.espada': {p.key: p.value}
        }));
        expect(await _icon('espada', 'items.espada'), isNot(base), reason: p.key);
      }
      art.setOverride(ProcDoc());
      expect(await _icon('espada', 'items.espada'), base);
    });
  });

  testWidgets('entrada vs familia', (t) async {
    await t.runAsync(() async {
      final espada = await _icon('espada', 'items.espada');
      final hacha = await _icon('hacha', 'items.hacha');
      art.setOverride(ProcDoc(entries: {
        'items.espada': {'metal': '#ff0000'}
      }));
      expect(await _icon('espada', 'items.espada'), isNot(espada));
      expect(await _icon('hacha', 'items.hacha'), hacha);
      // Familia: todas; la entrada sigue pisando a la familia.
      art.setOverride(ProcDoc(families: {
        'items': {'metal': '#00ff00'}
      }, entries: {
        'items.espada': {'metal': '#ff0000'}
      }));
      expect(await _icon('hacha', 'items.hacha'), isNot(hacha));
      expect(art.resolve('items.espada').color('metal'), '#ff0000');
      expect(art.resolve('items.hacha').color('metal'), '#00ff00');
    });
  });

  test('YAML: ida y vuelta, perillas inválidas se ignoran', () {
    final d = ProcDoc.parse('''
schema: 1
families:
  items: { shine: 0.2, foo: 3 }
entries:
  items.espada: { metal: '#FFD166', gem: true, scale: 9 }
  tiles.suelo: { metal: '#ffffff' }
''');
    expect(d.families['items'], {'shine': 0.2});
    expect(d.entries['items.espada'],
        {'metal': '#ffd166', 'gem': true, 'scale': 1.0});
    expect(d.entries.containsKey('tiles.suelo'), isFalse);
    final again = ProcDoc.parse(d.encode());
    expect(again.encode(), d.encode());
    expect(ProcDoc.parse(File(SpriteCatalog.proceduralPath).readAsStringSync()).isEmpty,
        isTrue);
  });

  test('procKeyForType: cada arma pide sus perillas', () {
    expect(procKeyForType('espada+escudo'), 'espada_escudo');
    expect(procKeyForType('báculo'), 'baculo');
    expect(procKeyForType('espada'), 'espada');
    expect(procKeyForType('xyz'), isNull);
  });

  test('armas con escudo: ícono propio arma + escudo, distinto por tipo', () {
    final keys = [
      for (final t in ['espada+escudo', 'maza+escudo', 'martillo+escudo'])
        iconKeyForType(t)
    ];
    expect(keys, ['espada_escudo', 'maza_escudo', 'martillo_escudo']);
    for (final k in keys) {
      final rows = kItemIconRows[k]!;
      expect(rows, isNot(kItemIconRows['escudo']), reason: k);
      expect(rows.join().contains('h'), isTrue, reason: '$k: pomo para la ULT');
      expect(kItemEntryShapes[k], k, reason: 'perillas del Editor');
    }
    expect(keys.map((k) => kItemIconRows[k]!.join()).toSet(), hasLength(3));
    expect(iconKeyForType('escudo'), 'escudo');
    expect(iconKeyForType('hacha'), 'hacha');
  });

  group('overrides en disco', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('ecos_proc_'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('paquete de arte: ida y vuelta con perillas', () async {
      final a = LocalSpriteOverrides('${tmp.path}/a');
      final doc = ProcDoc(families: {
        'items': {'shine': 0.1}
      }, entries: {
        'items.hacha': {'metal': '#123456', 'outline': true}
      });
      await a.putProcedural(doc.encode());
      final zip = await a.exportPack();
      expect(ArtPack.decode(zip).procedural, isNotNull);

      final b = LocalSpriteOverrides('${tmp.path}/b');
      await b.putProcedural(ProcDoc(entries: {
        'items.espada': {'gem': true}
      }).encode());
      final ids = await b.importPack(zip);
      expect(ids, contains(ArtPack.proceduralName));
      final got = ProcDoc.parse(await b.readProcedural());
      expect(got.entries['items.hacha'], {'metal': '#123456', 'outline': true});
      expect(got.entries['items.espada'], {'gem': true});
      expect(got.families['items'], {'shine': 0.1});
    });

    test('publicar al repo fusiona y borra el override', () async {
      final repo = Directory('${tmp.path}/repo')..createSync();
      File('${repo.path}/assets/sprites/procedural.yaml')
        ..createSync(recursive: true)
        ..writeAsStringSync(ProcDoc(entries: {
          'items.arco': {'gem': true}
        }).encode());
      final o = LocalSpriteOverrides('${tmp.path}/o');
      await o.putProcedural(ProcDoc(entries: {
        'items.lanza': {'mirror': true}
      }).encode());
      expect(await o.publishProcedural(repo.path), isTrue);
      expect(await o.readProcedural(), isNull);
      final out = ProcDoc.parse(
          File('${repo.path}/assets/sprites/procedural.yaml').readAsStringSync());
      expect(out.entries.keys, containsAll(['items.arco', 'items.lanza']));
    });

    testWidgets('Editor: perillas con vista previa, guardar y descartar',
        (t) async {
      final o = LocalSpriteOverrides('${tmp.path}/overrides');
      // La espada es PNG desde v0.25.8: las perillas siguen valiendo
      // para las entradas procedurales (y para el dibujo de respaldo).
      final cat = SpriteCatalog.fromYaml(
          File(SpriteCatalog.manifestPath).readAsStringSync().replaceFirst(
              'espada: { idle: items/espada.png, size: [16, 16] }',
              'espada: { procedural: true, size: [16, 16] }'),
          bundle: _DiskBundle(),
          overrides: o);
      final s = SpriteEditorController(catalog: cat, overrides: o);
      final espada = s.entries.firstWhere((e) => e.id == 'items.espada.idle');
      await t.runAsync(() => s.select(espada));
      expect(s.hasKnobs, isTrue);
      expect(s.procParams.color('metal'), '#c8d2ff');

      // Vista previa en tiempo real (sin guardar).
      s.setKnob('metal', '#ff0000');
      expect(s.procDirty, isTrue);
      expect(art.resolve('items.espada').color('metal'), '#ff0000');
      s.revertProc();
      expect(art.resolve('items.espada').color('metal'), '#c8d2ff');

      // Guardar por entrada: no toca a la hacha.
      s.setKnob('metal', '#ff0000');
      await t.runAsync(s.saveProc);
      expect(art.resolve('items.espada').color('metal'), '#ff0000');
      expect(art.resolve('items.hacha').color('metal'), '#c8d2ff');
      expect(File('${o.root}/procedural.yaml').existsSync(), isTrue);

      // Familia: aplica a todas.
      s.setProcFamily(true);
      s.setKnob('outline', true);
      await t.runAsync(s.saveProc);
      expect(art.resolve('items.hacha').flag('outline'), isTrue);

      // Recarga en caliente: el catálogo vuelve a leer el override.
      art.reset();
      await t.runAsync(cat.reload);
      expect(art.resolve('items.espada').color('metal'), '#ff0000');

      // Descartar familia y entrada: vuelve todo al defecto.
      await t.runAsync(s.discardProc);
      s.setProcFamily(false);
      await t.runAsync(s.discardProc);
      expect(art.resolve('items.espada').color('metal'), '#c8d2ff');
      expect(art.resolve('items.hacha').flag('outline'), isFalse);
      expect(File('${o.root}/procedural.yaml').existsSync(), isFalse);
    });
  });
}
