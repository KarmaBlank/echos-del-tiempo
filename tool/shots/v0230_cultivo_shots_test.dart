// Capturas de la huerta, el pueblo ampliado, el comerciante y OFICIOS
// (v0.23.0, docs/specs/farming.md y life_skill_trees.md). NO es parte de
// la suite. Correr con
//   flutter test tool/shots/v0230_cultivo_shots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/world/presentation/session_view.dart';
import 'package:echos_del_tiempo/game_engine/data/town_layout.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/life_skills.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/rules/farming_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/fishing_rules.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../test/features/world/fishing_map_harness.dart';
import '../../test/real_fonts.dart';

const _out = 'docs/release_shots/v0.23.0';
const _size = Size(1280, 720);

Future<void> _shot(WidgetTester tester, String name) async {
  final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  await tester.runAsync(() async {
    final img = await layer.toImage(Offset.zero & _size);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final f = File('$_out/$name.png');
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes!.buffer.asUint8List());
  });
}

int _xp(int level, int Function(int) need) {
  var xp = 0;
  for (var l = 1; l < level; l++) {
    xp += need(l);
  }
  return xp;
}

PlayerProfile _profile() => PlayerProfile(
      name: 'Ana',
      classId: 'guerrero',
      unlockedZone: 1,
      credits: 30000,
      materials: const {CraftMaterial.esquirla: 60, CraftMaterial.cristal: 20},
      life: LifeSkills(
        fishXp: _xp(8, FishingRules.xpNeed),
        bag: const {'carpa_musgo': 3, 'trucha_cobre': 2},
        fishTree: const ['p_a1', 'p_a3'],
        farm: FarmSkills(
          xp: _xp(12, FarmingRules.xpNeed),
          seeds: const {'nabo_claro': 6, 'trigo_dorado': 4, 'frutilla_rocio': 2},
          crops: const {
            'nabo_claro@0': 5,
            'trigo_dorado@1': 2,
            'frutilla_rocio@2': 1,
            'trigo_manana@3': 1,
          },
          ferts: const {'abono': 3, 'abono_runico': 1},
          tree: const ['c_b1', 'c_m'],
        ),
      ),
    );

void main() {
  testWidgets('huerta, pueblo ampliado, comerciante y OFICIOS',
      (tester) async {
    await loadRealFonts(tester);
    tester.view.physicalSize = _size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await FishingMapHarness.pump(tester, profile: _profile());
    final c = h.c;
    const bf = TownLayout.baseFarm;

    // ---- arar y plantar con E ----
    // ignore: invalid_use_of_visible_for_testing_member
    c.teleport((bf.x + 0.5) * 16, (bf.y + 1.5) * 16);
    await h.frames(6);
    final (tx, ty) = c.farmTile!;
    expect(c.handleKey(LogicalKeyboardKey.keyE), isTrue); // arar
    await h.frames(8);
    await _shot(tester, 'cultivo_arado');

    // ---- etapas: semilla, brote, crecido y maduro, una al lado de otra ----
    final s = c.session!;
    final grow = FarmingRules.growSec('trigo_dorado');
    FarmPlot at(double r, {bool wet = true}) => FarmPlot(
        seed: 'trigo_dorado',
        grow: grow * r,
        wetGrow: grow * r,
        wet: wet ? 200 : 0,
        waterRate: 1,
        planter: 'Ana',
        waterer: 'Ana',
        waterings: 2,
        waterQ: 0.4);
    s.town = s.town.copyWith(plots: {
      ...s.town.plots,
      plotKey(tx, ty): at(1.2),
      plotKey(bf.x + 1, bf.y): at(0.05),
      plotKey(bf.x + 2, bf.y): at(0.35),
      plotKey(bf.x + 3, bf.y): at(0.75, wet: false),
      plotKey(bf.x + 1, bf.y + 1): at(1.2),
      plotKey(bf.x + 2, bf.y + 2): const FarmPlot(),
      plotKey(bf.x + 3, bf.y + 2):
          at(0.6).copyWith(fert: 'abono_runico', fertBy: 'Ana'),
    });
    await h.frames(6);
    await _shot(tester, 'cultivo_etapas');

    // ---- cosecha: el fruto salta hacia quien cosechó (desde la fila de
    // abajo, para que nada tape el salto) ----
    // ignore: invalid_use_of_visible_for_testing_member
    c.teleport((bf.x + 0.5) * 16, (bf.y + 2.5) * 16);
    await h.frames(4);
    final (hx, hy) = c.farmTile!;
    final s2 = c.session!;
    s2.town = s2.town
        .copyWith(plots: {...s2.town.plots, plotKey(hx, hy): at(1.2)});
    await h.frames(3);
    expect(c.farmOp, FarmOp.harvest);
    expect(c.handleKey(LogicalKeyboardKey.keyE), isTrue);
    await h.frames(9);
    await _shot(tester, 'cultivo_cosecha');
    await h.frames(40);

    // ---- fuente rúnica: ampliar y elegir LAGO / HUERTA ----
    // ignore: invalid_use_of_visible_for_testing_member
    c.teleport(17.0 * 16, 12.4 * 16);
    await h.frames(6);
    expect(c.handleKey(LogicalKeyboardKey.keyE), isTrue);
    await h.frames(2);
    expect(c.expandTown(), isTrue);
    await h.frames(3);
    await _shot(tester, 'pueblo_fuente_eleccion');
    expect(c.assignZone(TownZoneKind.lago), isTrue);
    expect(c.assignZone(TownZoneKind.huerta), isTrue);
    expect(c.expandTown(), isTrue);
    expect(c.assignZone(TownZoneKind.huerta), isTrue);
    expect(c.assignZone(TownZoneKind.lago), isTrue);
    c.closePanel();
    await h.frames(3);

    // ---- el pueblo ampliado con lago y huerta ----
    // En el camino de la primera franja, entre sus dos espacios.
    // ignore: invalid_use_of_visible_for_testing_member
    c.teleport((TownLayout.stripX(0) + 0.5) * 16.0, 13.5 * 16.0);
    await h.frames(10);
    await _shot(tester, 'pueblo_ampliado');

    // ---- comerciante: PESCA y CULTIVO ----
    c.openPanel(WorldPanel.trader);
    await h.frames(3);
    await _shot(tester, 'comerciante_pesca');
    await tester.tap(find.byKey(const ValueKey('trade-tab-cultivo')));
    await h.frames(3);
    await _shot(tester, 'comerciante_cultivo');
    c.closePanel();
    await h.frames(2);

    // ---- PERSONAJE → OFICIOS ----
    c.openPanel(WorldPanel.character);
    await h.frames(2);
    await tester.tap(find.byKey(const ValueKey('tab-1')));
    await h.frames(2);
    await tester.tap(find.byKey(const ValueKey('life-row-cultivo')));
    await h.frames(2);
    await _shot(tester, 'personaje_oficios');
    await tester.tap(find.byKey(const ValueKey('tab-3')));
    await h.frames(2);
    await _shot(tester, 'personaje_pesca_y_cultivo');
  });
}
