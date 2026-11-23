// Barra de herramienta abajo al centro (farming.md § 2.5, v0.24.4): a
// tamaño completo y sin tapar pociones, grupo ni chat a 1280×720 y
// 1024×640. Con HUD_SHOTS=<carpeta> guarda hud_huerta.png y hud_pesca.png:
//   $env:HUD_SHOTS = "docs\release_shots\v0.24.4"; flutter test test/features/world/tool_hud_layout_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/world/presentation/hud/chat_box.dart';
import 'package:echos_del_tiempo/features/world/presentation/hud/tool_hud.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/data/town_layout.dart';
import 'package:echos_del_tiempo/game_engine/models/life_skills.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../real_fonts.dart';
import 'fishing_map_harness.dart';

final _out = Platform.environment['HUD_SHOTS'];

PlayerProfile _profile() => PlayerProfile(
      name: 'Ana',
      classId: 'guerrero',
      unlockedZone: 1,
      life: LifeSkills(
        farm: FarmSkills(
          seeds: const {
            'nabo_claro': 6,
            'trigo_dorado': 4,
            'calabaza_sendero': 2,
          },
          hoes: const ['azada_rama'],
          cans: const ['regadera_lata'],
        ),
      ),
    );

void main() {
  for (final size in const [Size(1280, 720), Size(1024, 640)]) {
    for (final farm in [true, false]) {
      final name = farm ? 'hud_huerta' : 'hud_pesca';
      testWidgets('$name a ${size.width.toInt()}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        // Fuentes reales: el ancho de los rótulos depende de los glifos.
        await loadRealFonts(tester);
        final h = await FishingMapHarness.pump(tester, profile: _profile());
        final c = h.c;
        if (farm) {
          const bf = TownLayout.baseFarm;
          // ignore: invalid_use_of_visible_for_testing_member
          c.teleport((bf.x + 1.5) * 16, (bf.y + 1.5) * 16);
          await h.frames(6);
          expect(c.activeTool, ActiveTool.hoe);
        } else {
          expect(c.activeTool, ActiveTool.rod);
        }
        final hud = tester.getRect(find.byKey(const ValueKey('hud-tool')));
        // Sin achicar: los íconos se ven a 32/40 px.
        expect(hud.width, closeTo(ToolHud.width, 0.5));
        expect(hud.bottom, greaterThan(size.height - 40));
        for (final f in [
          find.byKey(const ValueKey('hud-potions')),
          find.byKey(const ValueKey('hud-party-boxes')),
          find.byType(ChatBox),
        ]) {
          for (final e in f.evaluate()) {
            final r = tester.getRect(find.byWidget(e.widget));
            expect(r.overlaps(hud), isFalse, reason: '$f');
          }
        }
        expect(tester.takeException(), isNull);
        final out = _out;
        if (out == null || size.width != 1280) return;
        await tester.runAsync(() async {
          final b = tester.renderObject<RenderRepaintBoundary>(
              find.byType(RepaintBoundary).first);
          final img = await b.toImage();
          final png = await img.toByteData(format: ui.ImageByteFormat.png);
          Directory(out).createSync(recursive: true);
          File('$out/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
        });
      });
    }
  }
}
