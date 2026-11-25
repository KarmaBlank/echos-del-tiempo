// Íconos de inventario de las armas: todas resuelven a un ícono legible
// (no un cuadradito), en especial las de espada+escudo. Con
// WEAPON_ICON_PREVIEW=1 escribe docs/preview/weapon_icons.png a 8×.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/core/procedural/item_icons.dart';
import 'package:echos_del_tiempo/core/procedural/weapon_look.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/item_widgets.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/elements.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/weapon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

const _accent = ui.Color(0xFFB57BFF);

Future<void> _loadManifestIcons() async {
  final doc = loadYaml(
      File('assets/sprites/sprite_manifest.yaml').readAsStringSync()) as Map;
  final items = doc['items'] as Map;
  for (final e in items.entries) {
    final key = e.key as String;
    final v = e.value;
    if (v is! Map || v['idle'] is! String) continue;
    if (!kItemIconRows.containsKey(
        key.replaceAll('_acento', '').replaceAll('baculo', 'báculo'))) {
      continue;
    }
    final f = File('assets/sprites/${v['idle']}');
    if (!f.existsSync()) continue;
    final codec = await ui.instantiateImageCodec(f.readAsBytesSync());
    ItemIconImages.put(key, (await codec.getNextFrame()).image);
  }
}

/// El ícono de inventario de [def] en [side] px (el mismo camino que
/// PixelIcon), en RGBA.
Future<(ui.Image, ByteData)> _render(WeaponDef def, double side,
    {WeaponLook? look}) async {
  final rec = ui.PictureRecorder();
  final canvas = ui.Canvas(rec);
  final key = iconKeyForType(def.type);
  final proc = procKeyForType(def.type);
  final painter = ItemIconPainter(
      kItemIconRows[key] ?? kItemIconRows['espada']!, _accent,
      proc == null ? 'items' : 'items.$proc',
      look: look)
    ..pngKey = ItemIconImages.keyOf(
        kItemIconRows.containsKey(key) ? key : 'espada');
  painter.paint(canvas, ui.Size.square(side));
  final img = await rec.endRecording().toImage(side.ceil(), side.ceil());
  return (img, (await img.toByteData())!);
}

int _opaque(ByteData d) {
  var n = 0;
  for (var i = 3; i < d.lengthInBytes; i += 4) {
    if (d.getUint8(i) > 128) n++;
  }
  return n;
}

void main() {
  testWidgets('cada arma del catálogo tiene un ícono de 16 px legible',
      (tester) async {
    await tester.runAsync(() async {
      await _loadManifestIcons();
      final bad = <String>[];
      for (final def in kWeapons.values) {
        for (final look in [
          null,
          WeaponLook.of(ItemInstance(
              uid: 'u-${def.id}',
              baseId: def.id,
              rarity: Rarity.legendario,
              ultId: 'x',
              element: GameElement.sagrado)),
        ]) {
          final (_, d) = await _render(def, 16, look: look);
          final n = _opaque(d);
          if (n < 40) bad.add('${def.id} ($n px)');
        }
      }
      expect(bad, isEmpty);
      // Las de espada+escudo usan su propia forma y su PNG del manifest.
      final sws = kWeapons.values.where((w) => w.type == 'espada+escudo');
      expect(sws, isNotEmpty);
      for (final w in sws) {
        expect(iconKeyForType(w.type), 'espada_escudo');
        expect(ItemIconImages.base('espada_escudo'), isNotNull);
      }
    });
  });

  testWidgets('hoja de muestra (WEAPON_ICON_PREVIEW=1)', (tester) async {
    if (Platform.environment['WEAPON_ICON_PREVIEW'] != '1') return;
    await tester.runAsync(() async {
      await _loadManifestIcons();
      final defs = [
        ...kWeapons.values.where((w) => w.type.contains('escudo')),
        for (final t in ['espada', 'hacha', 'lanza', 'arco', 'báculo', 'dagas'])
          if (kWeapons.values.where((w) => w.type == t).firstOrNull
              case final w?)
            w,
      ];
      const s = 16.0, k = 8.0, cols = 8;
      final looks = <WeaponLook?>[
        null,
        WeaponLook.of(const ItemInstance(
            uid: 'a', baseId: 'x', rarity: Rarity.raro,
            element: GameElement.hielo)),
        WeaponLook.of(const ItemInstance(
            uid: 'b', baseId: 'x', rarity: Rarity.legendario, ultId: 'u',
            element: GameElement.sagrado)),
      ];
      final n = defs.length * looks.length;
      final rows = (n / cols).ceil();
      final rec = ui.PictureRecorder();
      final c = ui.Canvas(rec);
      c.drawRect(ui.Rect.fromLTWH(0, 0, cols * 18 * k, rows * 18 * k),
          ui.Paint()..color = const ui.Color(0xFF2A2433));
      var i = 0;
      for (final d in defs) {
        for (final l in looks) {
          final (img, _) = await _render(d, s, look: l);
          final x = (i % cols) * 18 * k + k, y = (i ~/ cols) * 18 * k + k;
          c.drawImageRect(
              img,
              const ui.Rect.fromLTWH(0, 0, s, s),
              ui.Rect.fromLTWH(x, y, s * k, s * k),
              ui.Paint()..filterQuality = ui.FilterQuality.none);
          i++;
        }
      }
      final out = await rec
          .endRecording()
          .toImage((cols * 18 * k).toInt(), (rows * 18 * k).toInt());
      final png = await out.toByteData(format: ui.ImageByteFormat.png);
      Directory('docs/preview').createSync(recursive: true);
      File('docs/preview/weapon_icons.png')
          .writeAsBytesSync(png!.buffer.asUint8List());
    });
  });
}
