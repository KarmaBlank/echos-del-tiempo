import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/app/design/design.dart';
import 'package:echos_del_tiempo/features/endgame/presentation/eco_portal_panel.dart';
import 'package:echos_del_tiempo/features/endgame/presentation/eco_zone_portal_panel.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/eco.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/tutorial_store.dart';
import 'package:echos_del_tiempo/game_engine/rules/inventory_rules.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/rendering.dart' show OffsetLayer;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../inventory/loot_fixtures.dart';
import '../panel_test_harness.dart';

/// Town ECOS tab clarity (docs/specs/ecos_atlas.md § 4.1): status of each
/// Eco (ready / locked with the reason), MEJORAR grid + detail, APLICAR,
/// and the biome portal's tutorial-lock reason (ecos_zone.md § 4).

EcoItem _eco(int tier, int zone, Rarity r, {List<EcoModRoll> mods = const []}) =>
    EcoItem(
        uid: 'x',
        tier: tier,
        zone: zone,
        boss: 1,
        rarity: r,
        mods: mods,
        floors: 1,
        seed: 1);

PlayerProfile _hero(List<EcoItem> ecos,
    {int unlockedZone = 10, Map<CraftMaterial, int> materials = const {}}) {
  final p = zoneProgression
      .normalize(PlayerProfile(name: 'Ana', classId: 'guerrero', level: 50));
  var q = zoneProgression.allocate(p, {Attribute.vit: p.points})!.copyWith(
      ecosUnlocked: true,
      unlockedZone: unlockedZone,
      ecoTiers: {2: 4},
      materials: materials);
  for (final e in ecos) {
    q = InventoryRules.addEco(q, e).$1;
  }
  return q;
}

Future<SessionController> _ecos(WidgetTester tester, PlayerProfile p) =>
    pumpPanel(tester,
        profile: p,
        engine: sessionEngine(zones: true),
        build: (v, c) => EcoPortalPanel(
            view: v, controller: c, initialTab: EcoPortalTab.ecos));

DsButton _btn(WidgetTester t, String k) =>
    t.widget<DsButton>(find.byKey(ValueKey(k)));

String _status(WidgetTester t) =>
    t.widget<Text>(find.byKey(const ValueKey('eco-status'))).data!;

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  await tester.runAsync(() async {
    final img = await layer.toImage(const Rect.fromLTWH(0, 0, 1280, 720));
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    Directory('docs/preview').createSync(recursive: true);
    File('docs/preview/$name').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('ready Eco: green status with the biome portal and IR AL '
      'PORTAL enabled', (tester) async {
    final c = await _ecos(tester, _hero([_eco(5, 2, Rarity.raro)]));
    expect(_status(tester), startsWith('Listo para abrir en '));
    expect(_status(tester), contains('portal de la zona 2'));
    expect(
        tester.widget<Text>(find.byKey(const ValueKey('eco-status'))).style!
            .color,
        DsColors.success);
    expect(find.byKey(const ValueKey('eco-opens-at')), findsOneWidget);
    expect(_btn(tester, 'eco-go').onPressed, isNotNull);
    await tapVisible(tester, find.byKey(const ValueKey('eco-go')));
    expect(c.nearEcoPortal, 2);
  });

  testWidgets('locked Eco: grey status with the reason (tier / boss)',
      (tester) async {
    await _ecos(
        tester, _hero([_eco(7, 2, Rarity.comun), _eco(1, 8, Rarity.comun)],
            unlockedZone: 5));
    final ecos = [
      for (final e in find
          .byWidgetPredicate((w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith('eco-row-'))
          .evaluate())
        e.widget.key! as ValueKey<String>
    ];
    expect(ecos, hasLength(2));
    // First cell: T7 of zone 2 (T1–T5 open).
    expect(_status(tester),
        'Bloqueado: Completá un Eco T6 de esta zona para abrir el T7.');
    expect(
        tester.widget<Text>(find.byKey(const ValueKey('eco-status'))).style!
            .color,
        DsColors.textSecondary);
    // Second: zone 8 with its boss still alive.
    await tapVisible(tester, find.byKey(ecos[1]));
    expect(_status(tester), startsWith('Bloqueado: Vencé al jefe de '));
  });

  testWidgets('MEJORAR grid: tapping a cell shows its detail', (tester) async {
    final c = await _ecos(
        tester, _hero([_eco(3, 2, Rarity.comun), _eco(9, 2, Rarity.raro)]));
    final ecos = c.view!.me!.profile.ecos;
    expect(find.byKey(const ValueKey('eco-upgrade')), findsOneWidget);
    String detail() => plain(tester, 'eco-detail');
    final first = detail();
    await tapVisible(
        tester, find.byKey(ValueKey('eco-row-${ecos.last.uid}')));
    expect(detail(), isNot(first));
    expect(detail(), contains('Tier ${ecos.last.tier}'));
    // T9 is locked (T1–T5 open).
    expect(_status(tester), startsWith('Bloqueado: '));
    // No more dense text rows nor USAR.
    expect(find.text('USAR'), findsNothing);
    expect(find.text('APLICAR'), findsNWidgets(4));
  });

  testWidgets('APLICAR: enabled with materials, grey with the reason',
      (tester) async {
    final c = await _ecos(
        tester,
        _hero([
          _eco(5, 2, Rarity.raro, mods: const [EcoModRoll('vida', 30)])
        ], materials: {
          CraftMaterial.esquirla: 2,
        }));
    // Material cells with have/need.
    expect(find.byKey(const ValueKey('cost-esquirla')), findsOneWidget);
    expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('cost-esquirla-count')))
            .data,
        '2/1');
    expect(_btn(tester, 'eco-craft-reroll').onPressed, isNotNull);
    expect(_btn(tester, 'eco-craft-reroll').tooltip, isNull);
    expect(_btn(tester, 'eco-craft-tier').onPressed, isNull);
    expect(_btn(tester, 'eco-craft-tier').tooltip, 'Falta Ancla Temporal');
    await tapVisible(tester, find.byKey(const ValueKey('eco-craft-reroll')));
    expect(c.view!.me!.profile.material(CraftMaterial.esquirla), 1);
  });

  testWidgets('biome portal: the tutorial lock shows its reason',
      (tester) async {
    final c = await pumpPanel(tester,
        profile: _hero([_eco(5, 2, Rarity.raro)]),
        engine: sessionEngine(zones: true),
        extraOverrides: [
          tutorialStoreProvider.overrideWithValue(InMemoryTutorialStore(0)),
        ],
        build: (v, c) => EcoZonePortalPanel(view: v, controller: c));
    expect(c.travelToEcoPortal(2, tier: 5), isTrue);
    c.ecoZone = 2;
    await tester.pump();
    expect(button(tester, 'eco-zone-open').reason,
        'Primero, todos tienen que hacer el TUTORIAL. Falta: Ana');
  });

  // `ECO_MENU_PREVIEW=1 flutter test <this file>` writes
  // docs/preview/eco_mejorar.png, eco_fusionar.png and
  // eco_zone_portal_locked.png (1280×720, real UI).
  testWidgets('preview: MEJORAR', (tester) async {
    if (Platform.environment['ECO_MENU_PREVIEW'] == null) return;
    await _ecos(
        tester,
        _hero([
          _eco(5, 2, Rarity.raro,
              mods: const [EcoModRoll('vida', 30), EcoModRoll('horda', 2)]),
          _eco(7, 2, Rarity.magico),
          _eco(3, 1, Rarity.comun),
          _eco(9, 7, Rarity.epico),
          _eco(6, 4, Rarity.raro),
        ], materials: {
          CraftMaterial.esquirla: 3,
          CraftMaterial.cristal: 1,
        }));
    await _shot(tester, 'eco_mejorar.png');
  });

  testWidgets('preview: FUSIONAR', (tester) async {
    if (Platform.environment['ECO_MENU_PREVIEW'] == null) return;
    final c = await _ecos(
        tester,
        _hero([
          _eco(6, 1, Rarity.magico),
          _eco(6, 4, Rarity.raro),
          _eco(6, 1, Rarity.comun),
          _eco(3, 2, Rarity.epico),
          _eco(9, 7, Rarity.raro),
        ]));
    await tapVisible(tester, find.byKey(const ValueKey('eco-sub-fuse')));
    for (final e in c.view!.me!.profile.ecos.where((e) => e.tier == 6)) {
      await tapVisible(tester, find.byKey(ValueKey('eco-fuse-cell-${e.uid}')));
    }
    await _shot(tester, 'eco_fusionar.png');
  });

  testWidgets('preview: biome portal locked by the tutorial', (tester) async {
    if (Platform.environment['ECO_MENU_PREVIEW'] == null) return;
    final c = await pumpPanel(tester,
        profile: _hero([_eco(5, 2, Rarity.raro)]),
        engine: sessionEngine(zones: true),
        extraOverrides: [
          tutorialStoreProvider.overrideWithValue(InMemoryTutorialStore(0)),
        ],
        build: (v, c) => EcoZonePortalPanel(view: v, controller: c));
    c.travelToEcoPortal(2, tier: 5);
    c.ecoZone = 2;
    await tester.pump();
    // Hover ABRIR so its reason tooltip shows.
    final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await g.addPointer(location: Offset.zero);
    addTearDown(g.removePointer);
    await g.moveTo(
        tester.getCenter(find.byKey(const ValueKey('eco-zone-open'))));
    await tester.pump(const Duration(seconds: 1));
    await _shot(tester, 'eco_zone_portal_locked.png');
  });
}
