// Pantallas clave en inglés (docs/specs/i18n.md): título, INVENTARIO y
// HUD de combate con `en` activo, fuentes reales, sin desbordes; la
// captura queda como golden para mirarla a ojo.
import 'dart:async';

import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/core/edition/game_edition.dart';
import 'package:echos_del_tiempo/core/i18n/i18n_providers.dart';
import 'package:echos_del_tiempo/features/characters/data/account_repository.dart';
import 'package:echos_del_tiempo/features/characters/data/account_store.dart';
import 'package:echos_del_tiempo/features/characters/presentation/characters_providers.dart';
import 'package:echos_del_tiempo/features/combat/presentation/battle_screen.dart';
import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/inventory_tab.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/shop_sections.dart';
import 'package:echos_del_tiempo/features/lobby/presentation/title_screen.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/player_state.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../features/inventory/loot_fixtures.dart';
import '../features/panel_test_harness.dart';
import '../game_engine/session_test_helpers.dart';
import '../real_fonts.dart';

final _en = activeLocaleProvider.overrideWithValue(LocaleId.en);

BattlePartyMember _member(String classId) {
  final cls = kClasses[classId]!;
  return BattlePartyMember(
    id: classId,
    name: cls.name,
    potions: 2,
    ethers: 1,
    build: PlayerBuild(
      classId: classId,
      level: 6,
      attributes: PlayerAttributes.base(cls.baseAttributes),
      equippedWeapon: kWeapons[cls.startWeaponId]!,
    ),
  );
}

BattleState _battle() {
  final engine = BattleEngine(
    stats: StatsCalculator(
        classes: kClasses, treeRules: PassiveTreeRules(kPassiveTree)),
    random: () => 0.99,
  );
  final start = engine.start(
    party: [_member('guerrero'), _member('maga'), _member('paladin')],
    enemyTypes: const ['slime', 'bat'],
    triggeredBy: 'guerrero',
  );
  return engine.nextTurn(start.state).state;
}

Future<void> _pumpPlain(WidgetTester tester, Widget child,
    {List<Override> overrides = const []}) async {
  await loadRealFonts(tester);
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [_en, ...overrides],
    child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: RetroTheme.build(),
        home: Scaffold(body: child)),
  ));
  await tester.pump();
  await tester.pump();
}

void main() {
  // La versión se dibuja en el título: fija para que el golden no cambie
  // con cada release.
  setUpAll(() => GameEdition.install(GameEdition(
        mode: GameEdition.mundo.mode,
        title: GameEdition.mundo.title,
        version: '0.0.0',
        dataFolder: GameEdition.mundo.dataFolder,
        linuxDataFolder: GameEdition.mundo.linuxDataFolder,
        releases: GameEdition.mundo.releases,
        wire: GameEdition.mundo.wire,
      )));
  tearDownAll(() => GameEdition.install(GameEdition.mundo));
  testWidgets('título en inglés', (tester) async {
    final repo = AccountRepository(InMemoryAccountStore());
    await _pumpPlain(tester, TitleScreen(onStart: () {}), overrides: [
      sessionEngineProvider.overrideWithValue(sessionEngine()),
      profileStoreProvider
          .overrideWithValue(SelectedCharacterProfileStore(repo)),
      accountRepositoryProvider.overrideWithValue(repo),
      gameSpritesProvider
          .overrideWith((ref) => Completer<GameSprites>().future),
    ]);
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/en_title.png'));
  });

  testWidgets('INVENTARIO en inglés', (tester) async {
    await pumpPanel(tester,
        profile: lootWarrior(),
        extraOverrides: [_en],
        build: (v, c) => InventoryTab(shop: ShopContext(v, c)));
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/en_inventory.png'));
  });

  testWidgets('HUD de combate en inglés', (tester) async {
    final b = _battle();
    await _pumpPlain(
        tester,
        BattleView(
            battle: b,
            canAct: true,
            localId: b.currentId,
            onCommand: (_) => true));
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/en_battle.png'));
  });
}
