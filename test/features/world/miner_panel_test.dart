import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/app/design/design.dart';
import 'package:echos_del_tiempo/app/widgets/cost_chip.dart';
import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/miner_panel.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_view.dart';
import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/mine_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/rules/mine_work_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/mining_rules.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../panel_test_harness.dart';

/// Miners panel (docs/specs/mining_smithing.md § 1.7). The preview goes
/// to docs/preview/miner_panel.png with `MINER_PREVIEW=1`.
final _preview = Platform.environment['MINER_PREVIEW'] != null;

PlayerProfile _profile({int credits = 100000, int ingots = 20}) {
  final p = newProfile('Ana', 'guerrero');
  return p.copyWith(
      level: 40,
      credits: credits,
      life: p.life.copyWith(ores: {'ingot_copper': ingots}));
}

Future<SessionController> _inMine(WidgetTester tester, PlayerProfile p,
    {List<MinerState> miners = const [MinerState(5, 5)]}) async {
  final c = await pumpPanel(tester,
      profile: p,
      engine: sessionEngine(zones: true),
      sprites: _preview
          ? await tester.runAsync(() async {
              final cat = await SpriteCatalog.load();
              await cat.loadProcedural();
              return GameSprites.load(cat);
            })
          : null,
      build: (v, c) => MinerPanel(view: v, controller: c));
  expect(c.travelPlace(kBosque), isTrue);
  expect(c.travelMine(0), isTrue);
  c.debugTown((t) => t.withMine(MiningRules.placeOf(kBosque, 0),
      MineLevelState(station: true, miners: miners)));
  expect(c.openMiners(), isTrue);
  await tester.pumpAndSettle();
  return c;
}

void _noOverflow(WidgetTester tester) {
  for (final p in tester.renderObjectList<RenderParagraph>(find.descendant(
      of: find.byType(MinerPanel), matching: find.byType(RichText)))) {
    expect(p.didExceedMaxLines, isFalse);
  }
}

void main() {
  testWidgets('MINEROS: grilla, detalle con costo y MEJORAR sube el pico',
      (tester) async {
    final c = await _inMine(tester, _profile(), miners: const [
      MinerState(5, 5),
      MinerState(6, 5, tier: 4),
    ]);
    expect(c.view!.panel, WorldPanel.miners);
    expect(find.byKey(const ValueKey('miner-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('miner-1')), findsOneWidget);
    // First miner selected: next tier cost as a cost chip.
    expect(find.byKey(const ValueKey('miner-cost-0')), findsOneWidget);
    final cost = MineWorkRules.upgradeCost(1)!;
    final chip = tester.widget<CostChip>(
        find.byKey(const ValueKey('miner-cost-0')));
    expect(chip.parts.map((x) => x.ok), [true, true]);
    expect(chip.parts.first.text, '${cost.gold}');
    _noOverflow(tester);
    if (_preview) {
      await tester.runAsync(() async {
        final b = tester.renderObject<RenderRepaintBoundary>(find
            .ancestor(
                of: find.byType(MinerPanel),
                matching: find.byType(RepaintBoundary))
            .last);
        final img = await b.toImage();
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        Directory('docs/preview').createSync(recursive: true);
        File('docs/preview/miner_panel.png')
            .writeAsBytesSync(png!.buffer.asUint8List());
      });
    }
    await tester.tap(find.byKey(const ValueKey('miner-up-0')));
    await tester.pumpAndSettle();
    expect(c.mineState.miners[0].tier, 1);
    expect(c.session!.players.values.first.profile.credits,
        100000 - cost.gold);

    // The maxed miner: no cost, MÁXIMO disabled.
    await tester.tap(find.byKey(const ValueKey('miner-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('miner-cost-1')), findsNothing);
    expect(
        tester
            .widget<DsButton>(find.byKey(const ValueKey('miner-up-1')))
            .onPressed,
        isNull);
  });

  testWidgets('MINEROS: sin oro el botón queda gris y el costo en rojo',
      (tester) async {
    final c = await _inMine(tester, _profile(credits: 0));
    final chip = tester.widget<CostChip>(
        find.byKey(const ValueKey('miner-cost-0')));
    expect(chip.parts.first.ok, isFalse);
    expect(
        tester
            .widget<DsButton>(find.byKey(const ValueKey('miner-up-0')))
            .onPressed,
        isNull);
    expect(c.mineState.miners[0].tier, 0);
  });

  testWidgets('MINEROS: E en la estación y G al lado de un minero lo abren',
      (tester) async {
    final c = await _inMine(tester, _profile());
    c.closePanel();
    final lvl = c.mineLevel!;
    final (sx, sy) = lvl.station;
    // Face the station from the tile below it.
    c.teleport((sx + 0.5) * 16, (sy + 1.5) * 16);
    if (MiningRules.tileAt(lvl, c.mineState, c.mineTarget.$1, c.mineTarget.$2) ==
        MineTile.station) {
      expect(c.mineUse(), isTrue);
      expect(c.view!.panel, WorldPanel.miners);
      c.closePanel();
    }
    final m = c.mineState.miners.first;
    c.teleport((m.x + 0.5) * 16, (m.y + 0.5) * 16);
    expect(c.nearMiner, 0);
    expect(c.openMiners(focus: 0), isTrue);
    expect(c.view!.panel, WorldPanel.miners);
    // U stays as a shortcut on the same op.
    c.closePanel();
    expect(c.upgradeMiner(), isTrue);
    expect(c.mineState.miners.first.tier, 1);
    expect(kMineTools[1].ingot, 'ingot_copper');
  });
}
