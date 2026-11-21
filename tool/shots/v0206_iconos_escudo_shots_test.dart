// Capturas de v0.20.6: íconos de las armas con escudo (arma + escudo).
// NO es parte de la suite. Correr con
//   flutter test tool/shots/v0206_iconos_escudo_shots_test.dart --dart-define=SHOT=despues
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/core/procedural/item_icons.dart';
import 'package:echos_del_tiempo/core/procedural/weapon_look.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/item_widgets.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/elements.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../test/real_fonts.dart';

const _tag = String.fromEnvironment('SHOT', defaultValue: 'despues');
const _out = 'docs/release_shots/v0.20.6/iconos';
const _size = Size(900, 420);
const _types = ['espada+escudo', 'maza+escudo', 'martillo+escudo'];
const _looks = <(Rarity, GameElement?, String?)>[
  (Rarity.comun, null, null),
  (Rarity.raro, GameElement.fuego, null),
  (Rarity.epico, GameElement.hielo, 'ult'),
  (Rarity.legendario, GameElement.sagrado, 'ult'),
];

void main() {
  testWidgets('íconos con escudo', (t) async {
    await loadRealFonts(t);
    t.view.physicalSize = _size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    Widget icon(String type, int i, double s) {
      final (r, el, ult) = _looks[i];
      final w = kWeapons.values.firstWhere((w) => w.type == type);
      final it = ItemInstance(
          uid: 'shot-$type-$i', baseId: w.id, rarity: r, element: el, ultId: ult);
      final look = WeaponLook.of(it);
      return PixelIcon(iconKeyForType(type),
          accent: look.rarityAccent,
          size: s,
          procKey: procKeyForType(type),
          look: look);
    }

    await t.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: const Color(0xFF14161F),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final type in _types)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(children: [
                  SizedBox(
                      width: 150,
                      child: Text(type,
                          style: const TextStyle(
                              color: Color(0xFFE8ECFF), fontSize: 16))),
                  for (var i = 0; i < _looks.length; i++) ...[
                    icon(type, i, 32),
                    const SizedBox(width: 12),
                  ],
                  const SizedBox(width: 24),
                  for (var i = 0; i < _looks.length; i++) ...[
                    icon(type, i, 96),
                    const SizedBox(width: 12),
                  ],
                ]),
              ),
          ]),
        ),
      ),
    ));
    final layer = t.binding.renderViews.first.debugLayer! as OffsetLayer;
    await t.runAsync(() async {
      final img = await layer.toImage(Offset.zero & _size);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      final f = File('$_out/$_tag.png');
      await f.parent.create(recursive: true);
      await f.writeAsBytes(bytes!.buffer.asUint8List());
    });
  });
}
