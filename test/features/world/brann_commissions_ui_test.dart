import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/world/presentation/panels/biome_npc_panel.dart';
import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/life_skills.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../panel_test_harness.dart';

// Brann's ENCARGOS DE FORJA menu (mining_smithing.md § 5.1) and his
// trade goods (overworld_biomes.md § 9.1.1). With `BRANN_PREVIEW=1` it
// also writes docs/preview/brann_commissions.png.

final _preview = Platform.environment['BRANN_PREVIEW'] != null;
final _shot = GlobalKey();

Future<void> _save(WidgetTester tester, String name) async {
  if (!_preview) return;
  await tester.runAsync(() async {
    final b =
        _shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await b.toImage();
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    Directory('docs/preview').createSync(recursive: true);
    File('docs/preview/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

PlayerProfile _profile() => progression.normalize(PlayerProfile(
      name: 'Ana',
      classId: 'guerrero',
      level: 20,
      credits: 5000,
      life: LifeSkills(ores: const {'ingot_copper': 10}),
    ));

Future<void> _open(WidgetTester tester, String choice,
    {bool housed = true}) async {
  final brann = kBiomeNpcs.firstWhere((n) => n.id == 'brann');
  final c = await pumpPanel(tester,
      profile: _profile(),
      build: (v, c) => RepaintBoundary(
          key: _shot, child: BiomeNpcPanel(view: v, controller: c)));
  if (housed) {
    c.session!.town = c.session!.town
        .withResident(const ResidentState('brann', invited: true, house: 1));
  }
  c.openResident(brann);
  await tester.pump();
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('ds-dialogue-text')),
      warnIfMissed: false);
  await tester.pump();
  final opt = find.byKey(ValueKey('npc-choice-$choice'));
  if (!housed) {
    expect(opt, findsNothing);
    return;
  }
  await tester.tap(opt);
  await tester.pump();
}

void main() {
  testWidgets('ENCARGOS DE FORJA: grilla de bases y detalle', (tester) async {
    await _open(tester, 'forja');
    final cells = find.byWidgetPredicate((w) =>
        w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.startsWith('brann-com-go-'));
    expect(cells, findsOneWidget, reason: 'detail of the selected base');
    expect(find.textContaining('al azar'), findsWidgets);
    expect(tester.takeException(), isNull);
    await _save(tester, 'brann_commissions');
  });

  testWidgets('sin casa, no hay encargos de forja', (tester) async {
    await _open(tester, 'forja', housed: false);
  });

  testWidgets('la tienda de Brann muestra lingotes', (tester) async {
    await _open(tester, 'comprar');
    expect(find.byKey(const ValueKey('npc-seed-ingot_copper')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
