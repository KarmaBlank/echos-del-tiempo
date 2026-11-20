// Padding de los botones (docs/specs/ui_style.md § "Botón compacto",
// `RetroTheme.minButtonInset`): en las pantallas principales, entre el
// borde de cada botón y su texto / ícono hay por lo menos 8 px.
import 'dart:async';

import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/app/theme/ui_theme.dart';
import 'package:echos_del_tiempo/app/widgets/pixel_icon.dart';
import 'package:echos_del_tiempo/features/characters/data/account_repository.dart';
import 'package:echos_del_tiempo/features/characters/data/account_store.dart';
import 'package:echos_del_tiempo/features/characters/presentation/characters_providers.dart';
import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/lobby/presentation/title_screen.dart';
import 'package:echos_del_tiempo/features/missions/presentation/mission_board_panel.dart';
import 'package:echos_del_tiempo/features/settings/presentation/settings_menu.dart';
import 'package:echos_del_tiempo/features/tutorial/presentation/tutorial_widgets.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/data/game_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/rules/tutorial_rules.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../features/passive_tree/passive_tree_view_test.dart' show tapNode;
import '../features/panel_test_harness.dart';
import '../game_engine/session_test_helpers.dart';
import '../real_fonts.dart';

/// Cada botón visible: el contenido (textos e íconos) queda a ≥ 8 px del
/// borde, que se pinta dentro del rect del botón.
void expectButtonInsets(WidgetTester tester, String screen) {
  final min = RetroTheme.minButtonInset + UiTheme.buttonBorderWidth - 0.5;
  final screenRect = Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio;
  var checked = 0;
  for (final el in find.byWidgetPredicate((w) => w is ButtonStyleButton).evaluate()) {
    final box = el.renderObject;
    if (box is! RenderBox || !box.hasSize || !box.attached) continue;
    final b = box.localToGlobal(Offset.zero) & box.size;
    if (!screenRect.overlaps(b) || b.isEmpty) continue;
    Rect? content;
    for (final c in find
        .descendant(
            of: find.byElementPredicate((e) => e == el),
            matching: find.byWidgetPredicate((w) => w is RichText || w is Icon || w is PixelIcon))
        .evaluate()) {
      final r = c.renderObject;
      if (r is! RenderBox || !r.hasSize) continue;
      final rect = r.localToGlobal(Offset.zero) & r.size;
      content = content == null ? rect : content.expandToInclude(rect);
    }
    if (content == null) continue;
    final label = find
        .descendant(
            of: find.byElementPredicate((e) => e == el),
            matching: find.byType(RichText))
        .evaluate()
        .map((e) => (e.widget as RichText).text.toPlainText())
        .join(' ');
    final gaps = [
      content.left - b.left,
      b.right - content.right,
      content.top - b.top,
      b.bottom - content.bottom,
    ];
    expect(gaps.every((g) => g >= min), isTrue,
        reason: '$screen: "$label" tiene $gaps px (mín. $min)');
    checked++;
  }
  expect(checked, greaterThan(0), reason: '$screen: sin botones');
}

Future<void> _pumpPlain(WidgetTester tester, Widget child,
    {List<Override> overrides = const []}) async {
  await loadRealFonts(tester);
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: overrides,
    child: MaterialApp(theme: RetroTheme.build(), home: Scaffold(body: child)),
  ));
  await tester.pump();
  await tester.pump();
}

/// En escritorio (Windows) Flutter usa densidad compacta por defecto,
/// que le restaba 8 px al padding de los botones: se prueba ahí.
final _desktop = TargetPlatformVariant.only(TargetPlatform.windows);

void main() {
  testWidgets('título', (tester) async {
    final repo = AccountRepository(InMemoryAccountStore());
    await _pumpPlain(tester, TitleScreen(onStart: () {}), overrides: [
      sessionEngineProvider.overrideWithValue(sessionEngine()),
      profileStoreProvider
          .overrideWithValue(SelectedCharacterProfileStore(repo)),
      accountRepositoryProvider.overrideWithValue(repo),
      gameSpritesProvider
          .overrideWith((ref) => Completer<GameSprites>().future),
    ]);
    expectButtonInsets(tester, 'título');
  }, variant: _desktop);

  for (final tab in [
    CharacterTab.attributes,
    CharacterTab.inventory,
    CharacterTab.tree,
  ]) {
    testWidgets('personaje: ${tab.name}', (tester) async {
      await pumpPanel(tester,
          profile: progression.normalize(
              PlayerProfile(name: 'Ana', classId: 'maga', level: 12)),
          build: (v, c) =>
              CharacterPanel(view: v, controller: c, initialTab: tab));
      expectButtonInsets(tester, tab.name);
    }, variant: _desktop);
  }

  testWidgets('árbol: tarjetas de hito y tooltip fijado', (tester) async {
    await pumpPanel(tester,
        profile: progression.normalize(
            PlayerProfile(name: 'Ana', classId: 'maga', level: 10)),
        build: (v, c) => CharacterPanel(
            view: v, controller: c, initialTab: CharacterTab.tree));
    expect(find.byKey(const ValueKey('milestone-banner-10')), findsOneWidget);
    expectButtonInsets(tester, 'hito');
    await tapNode(tester, 'marea_nb');
    expect(find.byKey(const ValueKey('tree-take-path')), findsOneWidget);
    expectButtonInsets(tester, 'tooltip');
  }, variant: _desktop);

  testWidgets('sello', (tester) async {
    const cat = GameCatalog.standard;
    await _pumpPlain(
        tester,
        MissionBoardPanel(
          missions: cat.missions,
          voteOpen: false,
          onPropose: (_) {},
          onClose: () {},
          tutorialDone: false,
          tutorial: TutorialSealDetail(
            rules: const TutorialRules(),
            done: false,
            humans: 1,
            companions: 2,
            isHost: true,
            onStart: (_) {},
          ),
        ));
    expectButtonInsets(tester, 'sello');
  }, variant: _desktop);

  testWidgets('pausa', (tester) async {
    await _pumpPlain(
        tester,
        SettingsMenu(
            onClose: () {}, inGame: true, onExitToTitle: () {}));
    expectButtonInsets(tester, 'pausa');
  }, variant: _desktop);
}
