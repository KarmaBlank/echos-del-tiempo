// Capturas de v0.25.7: íconos de armas e ítems en PNG (estilo de los de
// oficio). NO es parte de la suite. Correr con
//   flutter test tool/shots/v0257_iconos_armas_shots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/core/procedural/item_icons.dart';
import 'package:echos_del_tiempo/core/procedural/weapon_look.dart';
import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/item_widgets.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_view.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/life_skills.dart';
import 'package:echos_del_tiempo/game_engine/models/loot.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../test/features/world/fishing_map_harness.dart';
import '../../test/real_fonts.dart';

const _out = 'docs/release_shots/v0.25.7';

Future<void> _shot(WidgetTester t, String name, Size size) async {
  final layer = t.binding.renderViews.first.debugLayer! as OffsetLayer;
  await t.runAsync(() async {
    final img = await layer.toImage(Offset.zero & size);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final f = File('$_out/$name.png');
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('grilla de armas', (t) async {
    await loadRealFonts(t);
    const size = Size(900, 560);
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final sprites = (await t.runAsync(
        () async => GameSprites.load(await SpriteCatalog.load())))!;
    final types = {for (final w in kWeapons.values) w.type}.toList();
    Widget cell(Widget child, Color border) => Container(
        width: 44,
        height: 44,
        margin: const EdgeInsets.all(3),
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: const Color(0xFF1E2130),
            border: Border.all(color: border, width: 2)),
        child: child);
    Widget weapon(String type, Rarity r) {
      final w = kWeapons.values.firstWhere((w) => w.type == type);
      final look = WeaponLook.of(
          ItemInstance(uid: 'shot-$type-${r.name}', baseId: w.id, rarity: r));
      return cell(
          PixelIcon(iconKeyForType(type),
              accent: look.rarityAccent,
              size: 32,
              procKey: procKeyForType(type),
              look: look),
          RarityColors.of(r));
    }

    await t.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: const Color(0xFF14161F),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(children: [
            for (final r in Rarity.values)
              for (final ty in types) weapon(ty, r),
            for (final k in StackKind.values)
              cell(
                  PixelIcon(iconForStack(k).$1,
                      accent: iconForStack(k).$2, size: 32),
                  RarityColors.stack),
            cell(const PixelIcon('eco', accent: kEcoColor, size: 32), kEcoColor),
            for (final id in ['cana_rama', 'azada_hierro', 'carpa_musgo'])
              cell(
                  RawImage(
                      image: sprites.lifeIcon(id, 'herramienta'),
                      width: 32,
                      height: 32,
                      filterQuality: FilterQuality.none),
                  RarityColors.of(Rarity.comun)),
          ]),
        ),
      ),
    ));
    await _shot(t, 'inventario_armas', size);
  });

  testWidgets('comerciante', (t) async {
    await loadRealFonts(t);
    const size = Size(1280, 720);
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final h = await FishingMapHarness.pump(t,
        profile: PlayerProfile(
          name: 'Ana',
          classId: 'guerrero',
          unlockedZone: 3,
          credits: 5000,
          materials: const {CraftMaterial.esquirla: 10},
          life: LifeSkills(bag: const {'carpa_musgo': 3}),
        ));
    h.c.openPanel(WorldPanel.armory);
    await h.frames(3);
    await _shot(t, 'armeria', size);
    h.c.openPanel(WorldPanel.trader);
    await h.frames(3);
    await _shot(t, 'comerciante', size);
    for (final tab in ['ARMAS', 'COMPRAR', 'VENDER']) {
      final f = find.text(tab);
      if (f.evaluate().isEmpty) continue;
      await t.tap(f.first);
      await h.frames(3);
      await _shot(t, 'comerciante_${tab.toLowerCase()}', size);
    }
  });
}
