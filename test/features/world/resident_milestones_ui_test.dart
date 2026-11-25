import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/world/presentation/panels/biome_npc_panel.dart';
import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/resident_milestone_rules.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../panel_test_harness.dart';

// Milestone row of a resident (roles.md § 9.5). The PNG is written only
// with RESIDENT_MS_PREVIEW set.

final _preview = Platform.environment['RESIDENT_MS_PREVIEW'] != null;
final _shot = GlobalKey();

int _idx(MilestoneReward r) =>
    kResidentMilestones.firstWhere((m) => m.reward == r).index;

void main() {
  testWidgets('milestone row: states and claim', (tester) async {
    final ilda = kBiomeNpcs.firstWhere((n) => n.id == 'ilda');
    final wood = _idx(MilestoneReward.chestWood);
    final c = await pumpPanel(tester,
        profile: progression.normalize(PlayerProfile(
            name: 'Ana',
            classId: 'guerrero',
            level: 20,
            resClaims: {'ilda': 1 << wood})),
        build: (v, c) => RepaintBoundary(
            key: _shot, child: BiomeNpcPanel(view: v, controller: c)));
    c.session!.town = c.session!.town
        .withResident(const ResidentState('ilda', invited: true, house: 1, rep: 15));
    c.openResident(ilda);
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('ds-dialogue-text')),
        warnIfMissed: false);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('npc-choice-comprar')));
    await tester.pump();

    expect(find.byKey(const ValueKey('npc-milestones')), findsOneWidget);
    for (final m in kResidentMilestones) {
      expect(find.byKey(ValueKey('npc-ms-${m.index}')), findsOneWidget);
    }
    expect(tester.takeException(), isNull);

    if (_preview) {
      await tester.runAsync(() async {
        final b = _shot.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
        final img = await b.toImage();
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        Directory('docs/preview').createSync(recursive: true);
        File('docs/preview/resident_milestones.png')
            .writeAsBytesSync(png!.buffer.asUint8List());
      });
    }

    // Material milestone is claimable: tapping it claims it.
    final mat = _idx(MilestoneReward.material);
    await tester.tap(find.byKey(ValueKey('npc-ms-$mat')));
    await tester.pump();
    final me = c.session!.players.values.first.profile;
    expect(ResidentMilestoneRules.isClaimed(me, 'ilda', mat), isTrue);
    // The claimed chest cannot be claimed again.
    expect(ResidentMilestoneRules.isClaimed(me, 'ilda', wood), isTrue);
  });
}
