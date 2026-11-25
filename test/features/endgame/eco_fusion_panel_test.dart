import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/app/design/design.dart';
import 'package:flutter/rendering.dart' show OffsetLayer;
import 'package:echos_del_tiempo/features/endgame/presentation/eco_portal_panel.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/eco.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/rules/inventory_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../panel_test_harness.dart';

/// Subpestaña FUSIONAR del Portal (docs/specs/ecos_atlas.md § 4.2).

EcoItem _eco(int tier, int zone, Rarity r) => EcoItem(
    uid: 'x',
    tier: tier,
    zone: zone,
    boss: 1,
    rarity: r,
    mods: const [],
    floors: 1,
    seed: 1);

PlayerProfile _hero(List<EcoItem> ecos) {
  final p = zoneProgression
      .normalize(PlayerProfile(name: 'Ana', classId: 'guerrero', level: 50));
  var q = zoneProgression
      .allocate(p, {Attribute.vit: p.points})!
      .copyWith(ecosUnlocked: true, unlockedZone: 10);
  for (final e in ecos) {
    q = InventoryRules.addEco(q, e).$1;
  }
  return q;
}

DsButton _btn(WidgetTester t, String k) =>
    t.widget<DsButton>(find.byKey(ValueKey(k)));

void main() {
  testWidgets('elegir 3 del mismo tier habilita FUSIONAR y el resultado '
      'queda elegido en MEJORAR', (tester) async {
    final c = await pumpPanel(tester,
        profile: _hero([
          _eco(4, 1, Rarity.comun),
          _eco(4, 2, Rarity.raro),
          _eco(5, 2, Rarity.comun),
          _eco(4, 1, Rarity.magico),
        ]),
        engine: sessionEngine(zones: true),
        build: (v, c) => EcoPortalPanel(
            view: v, controller: c, initialTab: EcoPortalTab.ecos));
    await tapVisible(tester, find.byKey(const ValueKey('eco-sub-fuse')));
    expect(find.byKey(const ValueKey('eco-fusion')), findsOneWidget);
    expect(_btn(tester, 'eco-fuse-go').onPressed, isNull);
    // Sin elegir no hay motivo: es lo normal.
    expect(_btn(tester, 'eco-fuse-go').tooltip, isNull);

    final ecos = c.view!.me!.profile.ecos;
    String uid(int tier, int zone) =>
        ecos.firstWhere((e) => e.tier == tier && e.zone == zone).uid;
    final t4 = [for (final e in ecos) if (e.tier == 4) e.uid];
    await tapVisible(tester, find.byKey(ValueKey('eco-fuse-cell-${t4[0]}')));
    await tapVisible(tester, find.byKey(ValueKey('eco-fuse-cell-${t4[1]}')));
    expect(_btn(tester, 'eco-fuse-go').onPressed, isNull);
    // Otro tier: empieza de nuevo con ese.
    await tapVisible(
        tester, find.byKey(ValueKey('eco-fuse-cell-${uid(5, 2)}')));
    await tapVisible(tester, find.byKey(ValueKey('eco-fuse-cell-${t4[0]}')));
    expect(_btn(tester, 'eco-fuse-go').onPressed, isNull);
    for (final u in t4.skip(1)) {
      await tapVisible(tester, find.byKey(ValueKey('eco-fuse-cell-$u')));
    }
    expect(_btn(tester, 'eco-fuse-go').onPressed, isNotNull);
    final result = tester
        .widgetList<Text>(find.descendant(
            of: find.byKey(const ValueKey('eco-fuse-result')),
            matching: find.byType(Text)))
        .map((t) => t.data)
        .join('\n');
    expect(result, contains('Tier 5'));
    expect(result, contains('Zona al azar'));
    expect(result, contains('Raro'));
    expect(result, contains('Costo: solo los Ecos'));

    await tapVisible(tester, find.byKey(const ValueKey('eco-fuse-go')));
    final after = c.view!.me!.profile.ecos;
    expect(after.length, 2);
    expect(after.where((e) => e.tier == 5).length, 2);
    expect(find.byKey(const ValueKey('eco-fusion')), findsNothing);
    expect(find.byKey(const ValueKey('eco-fuse-after')), findsOneWidget);
    final fused = after.firstWhere((e) => !ecos.any((o) => o.uid == e.uid));
    expect(find.byKey(ValueKey('eco-row-${fused.uid}')), findsOneWidget);
    expect(find.byKey(const ValueKey('eco-craft-tier')), findsOneWidget);
  });

  // `ECO_FUSION_PREVIEW=1 flutter test <este archivo>` escribe
  // docs/preview/eco_fusion.png (1280×720, UI real).
  testWidgets('preview: FUSIONAR con 3 elegidos', (tester) async {
    if (Platform.environment['ECO_FUSION_PREVIEW'] == null) return;
    final c = await pumpPanel(tester,
        profile: _hero([
          _eco(6, 1, Rarity.magico),
          _eco(6, 4, Rarity.raro),
          _eco(6, 1, Rarity.comun),
          _eco(3, 2, Rarity.epico),
          _eco(9, 7, Rarity.legendario),
          _eco(6, 8, Rarity.comun),
        ]),
        engine: sessionEngine(zones: true),
        build: (v, c) => EcoPortalPanel(
            view: v, controller: c, initialTab: EcoPortalTab.ecos));
    await tapVisible(tester, find.byKey(const ValueKey('eco-sub-fuse')));
    for (final e in c.view!.me!.profile.ecos
        .where((e) => e.tier == 6 && e.zone != 8)) {
      await tapVisible(tester, find.byKey(ValueKey('eco-fuse-cell-${e.uid}')));
    }
    await tester.pumpAndSettle();
    final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
    await tester.runAsync(() async {
      final img = await layer.toImage(const Rect.fromLTWH(0, 0, 1280, 720));
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      Directory('docs/preview').createSync(recursive: true);
      File('docs/preview/eco_fusion.png')
          .writeAsBytesSync(png!.buffer.asUint8List());
    });
  });

  testWidgets('tier 16: FUSIONAR gris con el motivo', (tester) async {
    final c = await pumpPanel(tester,
        profile: _hero([for (var i = 0; i < 3; i++) _eco(16, 1, Rarity.comun)]),
        engine: sessionEngine(zones: true),
        build: (v, c) => EcoPortalPanel(
            view: v, controller: c, initialTab: EcoPortalTab.ecos));
    await tapVisible(tester, find.byKey(const ValueKey('eco-sub-fuse')));
    for (final e in c.view!.me!.profile.ecos) {
      await tapVisible(tester, find.byKey(ValueKey('eco-fuse-cell-${e.uid}')));
    }
    expect(_btn(tester, 'eco-fuse-go').onPressed, isNull);
    expect(_btn(tester, 'eco-fuse-go').tooltip, 'Tier máximo (16)');
  });
}
