import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/features/achievements/presentation/achievement_feed.dart';
import 'package:echos_del_tiempo/features/achievements/presentation/achievements_view.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:echos_del_tiempo/game_engine/data/achievements_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/achievement.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/square_ui_audit.dart';
import '../../game_engine/session_test_helpers.dart';
import '../panel_test_harness.dart';

// Pestaña HAZAÑAS y toast (docs/specs/achievements.md § 7): filas de una
// línea, cómo se consigue en el tooltip, sin desbordes ni redondeos.

final _progress = AchievementProgress(
  done: {'forge_first': 1732000000, 'fuse_first': 1732000100},
  counters: {'forgeLevels': 7, 'fusions': 3, 'salvaged': 7},
);

PlayerProfile _profile() => progression.normalize(
    PlayerProfile(name: 'Ana', classId: 'guerrero', achievements: _progress));

void main() {
  for (final size in [TextSize.normal, TextSize.huge, TextSize.enormous]) {
    testWidgets('pestaña HAZAÑAS sin desbordes ni redondeos (${size.name})',
        (tester) async {
      await pumpPanel(tester,
          profile: _profile(),
          textSize: size,
          build: (v, c) => CharacterPanel(
              view: v, controller: c, initialTab: CharacterTab.achievements));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('achievements-view')), findsOneWidget);
      expect(roundedUi(tester), isEmpty);
      final count = tester
          .widget<Text>(find.byKey(const ValueKey('ach-count')))
          .textSpan!
          .toPlainText();
      expect(count, 'Logradas 2/${kAchievements.length}');
    });
  }

  testWidgets('filas: marca, progreso de contador y recompensa; tooltip con '
      'el cómo', (tester) async {
    await pumpPanel(tester,
        profile: _profile(),
        build: (v, c) => CharacterPanel(
            view: v, controller: c, initialTab: CharacterTab.achievements));
    await tester.pumpAndSettle();
    // Pendientes primero dentro de la sección.
    final first = tester.getTopLeft(find.byKey(const ValueKey('ach-row-forge_plus5')));
    final done = tester.getTopLeft(find.byKey(const ValueKey('ach-row-forge_first')));
    expect(first.dy, lessThan(done.dy));
    // Forjador II (contador 7/10) pendiente, con su progreso en la fila.
    final row = find.byKey(const ValueKey('ach-row-forge_10'));
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    expect(find.descendant(of: row, matching: find.text('7/10')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('ach-reward-forge_10')), findsOneWidget);
    // Altura mínima de fila (§ 7).
    expect(tester.getSize(row).height,
        greaterThanOrEqualTo(AchievementRow.minHeight));
    // Tooltip con el cómo se consigue.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(row));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('Subí 10 niveles de forja', findRichText: true),
        findsWidgets);
    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    // Filtro Logradas: solo las 2.
    await tester.tap(find.byKey(const ValueKey('ach-filter-done')));
    await tester.pumpAndSettle();
    expect(find.byType(AchievementRow), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  for (final size in [TextSize.normal, TextSize.enormous]) {
    testWidgets('toast de hazaña: chico, sin desbordes (${size.name})',
        (tester) async {
      await pumpPanel(tester,
          profile: _profile(),
          textSize: size,
          build: (v, c) => const Align(
              alignment: Alignment.topRight,
              child: AchievementToastBox(id: 'salvage_50')));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(roundedUi(tester), isEmpty);
      expect(achievementToastText('salvage_50'),
          'HAZAÑA · Desarmar 50 · +₵1000 +1 Cristal de Era +1 Prisma Roto');
      // Compacto (v0.19.1): ancho y alto acotados por la escala del texto.
      final box = tester.getSize(find.byKey(const ValueKey('ach-toast')));
      final k = size.factor;
      expect(box.width, lessThanOrEqualTo(300 * k + 0.5));
      expect(box.height, lessThanOrEqualTo(110 * k));
      // Recompensa en una fila con íconos (créditos + cristal + prisma).
      expect(find.byKey(const ValueKey('ach-toast-reward-credits')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('ach-toast-reward-cristal')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('ach-toast-reward-prisma')),
          findsOneWidget);
      expect(find.text('HAZAÑA LOGRADA'), findsOneWidget);
    });
  }

  for (final size in [TextSize.normal, TextSize.large, TextSize.enormous]) {
    testWidgets('filas de HAZAÑAS a la escala de BESTIARIO (${size.name})',
        (tester) async {
      double rowH(CharacterTab tab, Finder f) =>
          tester.getSize(f.first).height;
      await pumpPanel(tester,
          profile: _profile(),
          textSize: size,
          build: (v, c) => CharacterPanel(
              view: v, controller: c, initialTab: CharacterTab.bestiary));
      await tester.pumpAndSettle();
      final best = rowH(CharacterTab.bestiary,
          find.byWidgetPredicate((w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith('bestiary-card-')));
      await pumpPanel(tester,
          profile: _profile(),
          textSize: size,
          build: (v, c) => CharacterPanel(
              view: v, controller: c, initialTab: CharacterTab.achievements));
      await tester.pumpAndSettle();
      final ach = rowH(CharacterTab.achievements, find.byType(AchievementRow));
      expect(ach, lessThanOrEqualTo(best + 0.5));
      expect(tester.takeException(), isNull);
    });
  }

  test('la cola apila hasta 3, 4 s cada uno', () {
    var t = 0.0;
    final f = AchievementFeed(clock: () => t);
    f
      ..push('fuse_first')
      ..push('fuse_skill')
      ..push('sell_first')
      ..push('forge_first');
    expect(f.visible, ['fuse_first', 'fuse_skill', 'sell_first']);
    t = 4.1;
    expect(f.visible, ['forge_first']);
    f.dismissAt(0);
    expect(f.current, isNull);
  });

  testWidgets('el host paga y el toast sale para el jugador local',
      (tester) async {
    final c = await pumpPanel(tester,
        profile: _profile(),
        engine: sessionEngine(achievements: true),
        build: (v, c) => CharacterPanel(
            view: v, controller: c, initialTab: CharacterTab.achievements));
    expect(c.claimAchievement('inv_search'), isTrue);
    await tester.pumpAndSettle();
    expect(c.achievementLog.map((e) => e.id), ['inv_search']);
    expect(c.view!.me!.profile.achievements.isDone('inv_search'), isTrue);
    // La pestaña se actualiza con el perfil de sesión.
    expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('ach-count')))
            .textSpan!
            .toPlainText(),
        'Logradas 3/${kAchievements.length}');
  });
}
