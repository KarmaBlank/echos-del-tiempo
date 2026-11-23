// Capturas de día, noche y clima y de las mejoras de los ayudantes
// (v0.27.0, docs/specs/day_night_weather.md, farming.md § 8.5). NO es
// parte de la suite. Correr con
//   flutter test tool/shots/v0270_dia_noche_shots_test.dart
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/game_engine/models/life_skills.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/town_rules.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/features/world/fishing_map_harness.dart';
import '../../test/real_fonts.dart';

const _out = 'docs/release_shots/v0.27.0';

Future<void> _shot(WidgetTester tester, String name, Size size) async {
  final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  await tester.runAsync(() async {
    final img = await layer.toImage(Offset.zero & size);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final f = File('$_out/$name.png');
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes!.buffer.asUint8List());
  });
}

SkyState _sky(double clock, Weather w, Weather tomorrow) => SkyState(
    day: 3, clock: clock, weather: w, from: 0, to: 1, tomorrow: tomorrow);

Future<void> _run(WidgetTester tester, Size size) async {
  await loadRealFonts(tester);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await FishingMapHarness.pump(tester,
      profile: PlayerProfile(
          name: 'Ana',
          classId: 'guerrero',
          unlockedZone: 1,
          credits: 9000,
          life: LifeSkills(
              fishXp: 4000,
              crafts: const {'fibra': 20, 'cebo': 12, 'tabla': 4},
              farm: FarmSkills(
                  xp: 4000, seeds: const {'nabo_claro': 14}))));
  final c = h.c;
  expect(c.hireHelper('h0'), isTrue);
  c.giveSeeds('h0', 'nabo_claro', 10);
  // Faros alrededor de la huerta base (19, 18).
  final lights = <(int, int)>[];
  for (final (x, y) in const [(17, 17), (24, 17), (17, 22), (24, 21), (14, 19)]) {
    if (TownRules.lightError(c.town, x, y) == null) lights.add((x, y));
  }
  c.debugTown((t) => t.copyWith(
      lights: lights,
      sky: _sky(460, Weather.despejado, Weather.lluvia)));
  final (ox, oy) = c.town.origin;
  c.teleport((19.0 + ox) * 16 - 24, (19.0 + oy) * 16);
  await h.frames(40);
  await _shot(tester, '01_noche_faros_luciernagas', size);
  await _shot(tester, '02_pronostico', size);

  c.debugTown((t) => t.copyWith(sky: _sky(120, Weather.lluvia, Weather.despejado)));
  await h.frames(20);
  await _shot(tester, '03_lluvia', size);

  c.debugTown(
      (t) => t.copyWith(sky: _sky(150, Weather.tormenta, Weather.despejado)));
  await h.frames(6);
  h.game.sky.addBolt(20 + ox, 19 + oy, h.game.t);
  await h.frames(3);
  await _shot(tester, '04_tormenta_rayo', size);

  c.debugTown(
      (t) => t.copyWith(sky: _sky(120, Weather.despejado, Weather.despejado)));
  c.openHelper('h0', 0);
  await h.frames(4);
  await tester.tap(find.byKey(const ValueKey('helper-tab-mejoras')));
  await h.frames(4);
  await _shot(tester, '05_mejoras_ayudante', size);
}

void main() {
  testWidgets('1280x720', (t) => _run(t, const Size(1280, 720)));
}
