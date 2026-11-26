import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/app/design/design.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/biome_npc_panel.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/life_skills_view.dart';
import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/farming_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/life_tree_rules.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../panel_test_harness.dart';

/// Previews of the Granjero reform (animals.md § 14). Written with
/// `PREVIEW=1 flutter test <this file>` to `docs/preview/granjero/`.
final _on = Platform.environment['PREVIEW'] != null;
const _out = 'docs/preview/granjero';
final _shot = GlobalKey();

PlayerProfile _farmer(int level) {
  final b = PlayerProfile(name: 'Ana', classId: 'guerrero', level: 20);
  var xp = 0;
  for (var l = 1; l < level; l++) {
    xp += FarmingRules.xpNeed(l);
  }
  return b.copyWith(
      credits: 5000,
      life: b.life.copyWith(farm: b.life.farm.copyWith(xp: xp)));
}

PlayerProfile _upTo(PlayerProfile p, String b, int tier) {
  for (var t = 1; t <= tier; t++) {
    p = LifeTreeRules.take(p, LifeSkillKind.cultivo, 'farm_$b$t') ?? p;
  }
  return p;
}

Future<void> _save(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final b =
        _shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await b.toImage();
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    Directory(_out).createSync(recursive: true);
    File('$_out/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('preview: Granjero tree with CULTIVOS and ANIMALES',
      (tester) async {
    if (!_on) return;
    var p = _farmer(30);
    p = _upTo(p, 'a', 5);
    p = _upTo(p, 'f', 10);
    await pumpPanel(tester,
        profile: p,
        build: (v, c) => RepaintBoundary(
              key: _shot,
              child: Container(
                color: DsColors.background,
                padding: const EdgeInsets.all(16),
                child: LifeSkillsView(
                    profile: v.me!.profile,
                    onTake: c.takeLifeNode,
                    onReset: c.resetLifeTree),
              ),
            ));
    tester.view.physicalSize = const Size(1280, 960);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('life-row-cultivo')));
    await tester.pump();
    expect(find.byKey(const ValueKey('life-node-farm_f10')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _save(tester, 'tree');
  });

  testWidgets('preview: Brann legendary animal forge', (tester) async {
    if (!_on) return;
    final b = _farmer(14);
    final p = b.copyWith(
        life: b.life.copyWith(
            farm: b.life.farm.copyWith(
                goods: const {'huevo_dorado@3': 1, 'vellon_eco@3': 1})));
    final brann = kBiomeNpcs.firstWhere((n) => n.id == 'brann');
    final c = await pumpPanel(tester,
        profile: p,
        build: (v, c) => RepaintBoundary(
            key: _shot, child: BiomeNpcPanel(view: v, controller: c)));
    c.session!.town = c.session!.town
        .withResident(const ResidentState('brann', invited: true, house: 1));
    c.openResident(brann);
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('ds-dialogue-text')),
        warnIfMissed: false);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('npc-choice-forja')));
    await tester.pump();
    final cell = find.byWidgetPredicate((w) =>
        w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.contains('brann-animal-huevo_dorado'));
    await tester.ensureVisible(cell.first);
    await tester.tap(cell.first);
    await tester.pump();
    expect(find.byKey(const ValueKey('brann-animal-go-huevo_dorado')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await _save(tester, 'legend_forge');
  });
}
