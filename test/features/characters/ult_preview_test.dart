import 'dart:ui' as ui;

import 'package:echos_del_tiempo/core/fx/fx_catalog.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/features/characters/domain/ult_preview_samples.dart';
import 'package:echos_del_tiempo/features/characters/presentation/ult_preview_panel.dart';
import 'package:echos_del_tiempo/features/characters/presentation/ult_repertoire_view.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/fx_bridge.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/fx_style.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/ult_preview_scene.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:echos_del_tiempo/game_engine/data/ults_v2_catalog.dart';
import 'package:echos_del_tiempo/game_engine/rules/ult_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/square_ui_audit.dart';
import '../../game_engine/session_test_helpers.dart';
import '../panel_test_harness.dart';

/// Vista previa de ULT (docs/specs/ultimates_v2.md § 2.5).
void main() {
  final ultTab = CharacterTab.values.indexOf(CharacterTab.ults);

  void paintAll() {
    for (final u in kUltV2List) {
      for (final lv in [1, UltRules.maxLevel]) {
        final sk = UltRules.leveled(u.skill, lv);
        final samples =
            ultPreviewSamples(sk, attack: 40, magic: 35, maxHp: 300);
        expect(samples, isNotEmpty, reason: u.id);
        final t = ultPreviewTimeline(u.id);
        final reach = ultPreviewReach(sk);
        final clock = UltPreviewClock();
        final painter = UltPreviewPainter(
          timeline: t,
          clock: clock,
          sim: UltPreviewSim(),
          foes: reach.foes,
          count: reach.count,
          color: skillColor(u.id),
          element: skillElement(sk),
          labels: [
            for (final s in samples)
              (text: s.text, color: const Color(0xFFFFFFFF))
          ],
          weaponType: u.weapons.firstOrNull,
        );
        for (var ms = 0.0;
            ms <= t.duration + UltPreviewPanel.loopGap;
            ms += 40) {
          clock.ms = ms;
          final rec = ui.PictureRecorder();
          painter.paint(Canvas(rec), const Size(320, 180));
          rec.endRecording().dispose();
        }
      }
    }
  }

  test('las 50 ULT tienen vista previa sin excepciones (sin catálogo)', () {
    expect(kUltV2List, hasLength(50));
    FxCatalog.active = null;
    paintAll();
  });

  testWidgets('las 50 ULT con la animación de datos real', (tester) async {
    await tester.runAsync(() => installFx());
    addTearDown(() => FxCatalog.active = null);
    var data = 0;
    for (final u in kUltV2List) {
      if (ultPreviewTimeline(u.id).id != 'ult_preview_generic') {
        data++;
      }
    }
    expect(data, greaterThan(40), reason: 'casi todas tienen datos');
    paintAll();
  });

  test('números de ejemplo según la ULT y el nivel', () {
    final dmg = kUltV2List.firstWhere((u) =>
        u.skill.power > 0 &&
        u.skill.charge == 0 &&
        u.skill.hits <= 1 &&
        u.skill.kind.name == 'physical');
    final a = ultPreviewSamples(UltRules.leveled(dmg.skill, 1),
        attack: 100, magic: 10, maxHp: 100);
    final b = ultPreviewSamples(UltRules.leveled(dmg.skill, 2),
        attack: 100, magic: 10, maxHp: 100);
    final da = a.firstWhere((s) => s.kind == UltSampleKind.damage);
    final db = b.firstWhere((s) => s.kind == UltSampleKind.damage);
    expect(int.parse(db.text), greaterThan(int.parse(da.text)));
  });

  testWidgets('la UI responde durante la vista previa', (tester) async {
    UltPreviewPanel.autoplayOverride = true;
    addTearDown(() => UltPreviewPanel.autoplayOverride = null);
    final c = await pumpPanel(tester,
        profile: newProfile('Ana', 'guerrero'),
        build: (v, c) => CharacterPanel(view: v, controller: c));
    var notes = 0;
    final remove = c.addListener((_) => notes++, fireImmediately: false);
    addTearDown(remove);
    await tester.ensureVisible(find.byKey(ValueKey('tab-$ultTab')));
    await tester.pump();
    await tester.tap(find.byKey(ValueKey('tab-$ultTab')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byKey(const ValueKey('ult-preview')), findsOneWidget);
    expect(roundedUi(tester), isEmpty);
    UltPreviewPainter painter() => tester
        .widget<CustomPaint>(find.byKey(const ValueKey('ult-preview-canvas')))
        .painter! as UltPreviewPainter;
    final builds = UltRepertoireView.debugBuilds;
    final paints = painter().sim.paints;
    notes = 0;
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    // El lienzo se mueve, la página no se reconstruye ni se notifica.
    expect(painter().sim.paints, greaterThan(paints + 30));
    expect(UltRepertoireView.debugBuilds, builds);
    expect(notes, 0);
    // PAUSA: el lienzo se queda quieto.
    await tester.tap(find.byKey(const ValueKey('ult-preview-play')));
    await tester.pump();
    final still = painter().sim.paints;
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(painter().sim.paints, still);
    expect(find.text('REPRODUCIR'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ult-preview-play')));
    await tester.pump();
    // Sonido apagado por defecto.
    expect(find.text('SONIDO: NO'), findsOneWidget);
    // Ventana sin foco: pausa.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    final away = painter().sim.paints;
    await tester.pump(const Duration(milliseconds: 100));
    expect(painter().sim.paints, away);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    // Cambiar de pestaña con la vista previa corriendo.
    await tester.tap(find.byKey(const ValueKey('tab-0')));
    await tester.pump();
    // La barra de pestañas se desliza hasta la elegida (v0.23.0: más
    // pestañas que el ancho).
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const ValueKey('ult-preview')), findsNothing);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  for (final size in TextSize.values) {
    testWidgets('sin desbordes: texto ${size.name}', (tester) async {
      await pumpPanel(tester,
          profile: newProfile('Ana', 'maga'),
          textSize: size,
          build: (v, c) => CharacterPanel(view: v, controller: c));
      await tester.ensureVisible(find.byKey(ValueKey('tab-$ultTab')));
      await tester.pump();
      await tester.tap(find.byKey(ValueKey('tab-$ultTab')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ult-preview')), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(roundedUi(tester), isEmpty);
    });
  }

  testWidgets('ventana angosta: la vista previa va arriba de la lista',
      (tester) async {
    for (final (w, narrow) in [(520.0, true), (1000.0, false)]) {
      await pumpPanel(tester,
          profile: newProfile('Ana', 'guerrero'),
          textSize: TextSize.huge, build: (v, c) {
        final rules = c.engine.progression;
        final p = v.actor!.profile;
        return Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
                width: w,
                height: 700,
                child: UltRepertoireView(
                    profile: p,
                    weapon: rules.equippedWeapon(p),
                    item: rules.equippedItem(p),
                    editable: true,
                    stats: rules.derivedStats(p),
                    onSelect: (_) => true,
                    onUpgrade: (_) => true)));
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$w');
      final preview = tester.getRect(find.byKey(const ValueKey('ult-preview')));
      final header = tester.getRect(find.text('ULT EQUIPADA'));
      if (narrow) {
        expect(preview.bottom, lessThanOrEqualTo(header.top));
      } else {
        expect(preview.left, greaterThanOrEqualTo(header.right));
      }
    }
  });

  test('el genérico existe para una ULT sin animación', () {
    FxCatalog.active = null;
    expect(ultPreviewTimeline('no_existe').id, 'ult_preview_generic');
  });
}
