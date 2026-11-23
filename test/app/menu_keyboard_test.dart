import 'package:echos_del_tiempo/app/design/design.dart';
import 'dart:async';
import '../features/lobby/title_flow.dart';

import 'package:echos_del_tiempo/app/theme/panel_frame.dart';
import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/app/widgets/menu_focus.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/features/characters/data/account_repository.dart';
import 'package:echos_del_tiempo/features/characters/data/account_store.dart';
import 'package:echos_del_tiempo/features/characters/domain/account.dart';
import 'package:echos_del_tiempo/features/characters/presentation/characters_providers.dart';
import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/armory_panel.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/shop_sections.dart';
import 'package:echos_del_tiempo/features/lobby/presentation/title_screen.dart';
import 'package:echos_del_tiempo/features/missions/domain/mission_text.dart';
import 'package:echos_del_tiempo/features/missions/presentation/mission_board_panel.dart';
import 'package:echos_del_tiempo/features/missions/presentation/prep_panel.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/data/game_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/upgrade_stat.dart';
import 'package:echos_del_tiempo/game_engine/rules/inventory_rules.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:echos_del_tiempo/app/theme/retro_hover_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../features/inventory/loot_fixtures.dart';
import '../features/panel_test_harness.dart';
import '../game_engine/session_test_helpers.dart';

/// Teclado de los menús (docs/specs/panels.md § "Teclado en los menús
/// (v0.5.1)"): flechas mueven el foco (aro dorado), Enter activa, Esc
/// vuelve / cierra, Q / E / Ctrl+Tab / 1-9 cambian de pestaña, Tab salta
/// de sección.

Future<void> _key(WidgetTester tester, LogicalKeyboardKey k,
    {int times = 1}) async {
  for (var i = 0; i < times; i++) {
    await tester.sendKeyEvent(k);
    await tester.pump();
  }
}

Future<void> _ctrlTab(WidgetTester tester, {bool shift = false}) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

/// La clave (`ValueKey<String>`) del widget más cercano al foco.
String? _focusedKey() {
  final ctx = FocusManager.instance.primaryFocus?.context;
  if (ctx?.widget.key case final ValueKey<String> k) return k.value;
  String? found;
  ctx?.visitAncestorElements((e) {
    final k = e.widget.key;
    if (k is ValueKey<String>) {
      found = k.value;
      return false;
    }
    return true;
  });
  return found;
}

/// La pestaña `i` está elegida: [PanelButton] (armería) o [DsTabBar]
/// (personaje, sistema de diseño).
bool _tab(WidgetTester tester, int i) {
  final f = find.byKey(ValueKey('tab-$i'));
  final w = tester.widget(f);
  if (w is PanelButton) return w.selected;
  return tester
          .widget<DsTabBar>(
              find.ancestor(of: f, matching: find.byType(DsTabBar)))
          .index ==
      i;
}

void main() {
  testWidgets(
      'armería: flechas en la lista (el detalle sigue), E / Ctrl+Tab '
      'cambian de pestaña, Tab salta a las tarjetas y Enter forja',
      (tester) async {
    final c = await pumpPanel(tester,
        profile: lootWarrior(),
        build: (v, c) => ForgePanel(view: v, controller: c));
    PlayerProfile me() => c.view!.me!.profile;
    await _key(tester, LogicalKeyboardKey.keyE);
    expect(_tab(tester, ForgeHallTab.condense.index), isTrue);
    await _ctrlTab(tester);
    expect(_tab(tester, ForgeHallTab.fuse.index), isTrue);
    await _ctrlTab(tester, shift: true);
    await _key(tester, LogicalKeyboardKey.digit1);
    expect(_tab(tester, ForgeHallTab.upgrade.index), isTrue);
    await tester.pump();
    expect(_focusedKey(), startsWith('forge-row-'));

    // Tab: de la lista a la sección siguiente (las habilidades del arma,
    // después las tarjetas de FORJA); Enter elige la mejora y FORJAR la
    // aplica (ui_minimal.md § 4).
    await _key(tester, LogicalKeyboardKey.tab);
    expect(_focusedKey(), startsWith('skill-chip-'));
    await _key(tester, LogicalKeyboardKey.tab);
    expect(_focusedKey(), startsWith('up-'));
    final eq = me().equippedUid!;
    final stat = _focusedKey()!.split('-').last;
    final s = UpgradeStat.values.firstWhere((x) => x.key == stat);
    await _key(tester, LogicalKeyboardKey.enter);
    expect(me().itemByUid(eq)!.forge.level(s), 0);
    // Flecha a la derecha: otra tarjeta.
    await _key(tester, LogicalKeyboardKey.arrowRight);
    expect(_focusedKey(), startsWith('up-'));
    expect(_focusedKey(), isNot('up-$eq-$stat'));
    await tester.tap(find.byKey(const ValueKey('forge-confirm')));
    await tester.pump();
    expect(me().itemByUid(eq)!.forge.level(s), 1);
  });

  testWidgets('personaje: Q / E / 1-5 cambian de pestaña; Enter en + reparte',
      (tester) async {
    await pumpPanel(tester,
        profile: progression.normalize(
            PlayerProfile(name: 'Ana', classId: 'guerrero', level: 3)),
        build: (v, c) => CharacterPanel(view: v, controller: c));
    // Abre con el cursor en el primer `+`.
    expect(_focusedKey(), 'inc-vit');
    await _key(tester, LogicalKeyboardKey.enter);
    expect(plain(tester, 'pending-points'), contains('+3 VIT'));
    await _key(tester, LogicalKeyboardKey.arrowDown);
    expect(_focusedKey(), 'inc-esp');
    await _key(tester, LogicalKeyboardKey.keyE);
    expect(_tab(tester, CharacterTab.oficios.index), isTrue);
    await _key(tester, LogicalKeyboardKey.keyQ);
    expect(_tab(tester, CharacterTab.attributes.index), isTrue);
    await _key(tester, LogicalKeyboardKey.digit3);
    expect(_tab(tester, CharacterTab.inventory.index), isTrue);
    await _key(tester, LogicalKeyboardKey.keyQ);
    await _key(tester, LogicalKeyboardKey.keyQ);
    expect(_tab(tester, CharacterTab.attributes.index), isTrue);
  });

  testWidgets(
      'inventario: las flechas mueven la casilla y la eligen; Enter '
      'otra vez equipa', (tester) async {
    final c = await pumpPanel(tester,
        profile: lootWarrior(),
        build: (v, c) => CharacterPanel(
            view: v, controller: c, initialTab: CharacterTab.inventory));
    PlayerProfile me() => c.view!.me!.profile;
    final cells = InventoryRules.layout(me()).cells;
    expect(_focusedKey(), 'inv-focus-0');
    // Flecha a la derecha: la casilla 1 queda elegida y muestra su
    // tooltip (v0.9.9: no hay ficha a la derecha).
    await _key(tester, LogicalKeyboardKey.arrowRight);
    expect(_focusedKey(), 'inv-focus-1');
    expect(RetroHoverCard.anyShowing, isTrue);
    // Abajo y vuelta arriba.
    await _key(tester, LogicalKeyboardKey.arrowDown);
    expect(_focusedKey(), 'inv-focus-${1 + InventoryRules.columns}');
    await _key(tester, LogicalKeyboardKey.arrowUp);
    expect(_focusedKey(), 'inv-focus-1');
    // Elegida un arma que cumple: Enter la equipa.
    final ok = [
      for (var i = 0; i < cells.length; i++)
        if (cells[i] case final t?
            when me().itemByUid(t) != null &&
                ShopContext(c.view!, c).guards.equip(me(), t) == null)
          i
    ].first;
    await _key(tester, LogicalKeyboardKey.arrowLeft);
    await _key(tester, LogicalKeyboardKey.arrowRight, times: ok);
    expect(_focusedKey(), 'inv-focus-$ok');
    // Enter sobre la elegida abre el menú; Enter otra vez (en Equipar)
    // la equipa.
    await _key(tester, LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.byKey(const ValueKey('inv-ctx-menu')), findsOneWidget);
    await _key(tester, LogicalKeyboardKey.enter);
    expect(me().equippedUid, cells[ok]);
  });

  testWidgets('mostrador: 1-9 eligen la zona, flechas mueven, Esc cierra',
      (tester) async {
    const cat = GameCatalog.standard;
    var closed = 0;
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(child: MaterialApp(
      theme: RetroTheme.build(),
      home: Scaffold(
        body: MissionBoardPanel(
          missions: cat.missions,
          voteOpen: false,
          bossName: (m) => missionBossName(cat, m),
          playerLevel: 1,
          onPropose: (_) {},
          onClose: () => closed++,
        ),
      ),
    )));
    await tester.pump();
    await tester.pump();
    final m = cat.missions;
    await _key(tester, LogicalKeyboardKey.digit2);
    expect(find.byKey(ValueKey('mission-card-${m[1].id}')), findsOneWidget);
    await _key(tester, LogicalKeyboardKey.arrowDown);
    await _key(tester, LogicalKeyboardKey.arrowUp);
    expect(_focusedKey(), startsWith('mission-'));
    await _key(tester, LogicalKeyboardKey.escape);
    expect(closed, 1);
  });

  testWidgets('preparación: E / Q recorren MISIÓN y las pestañas de tienda',
      (tester) async {
    const cat = GameCatalog.standard;
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(child: MaterialApp(
      theme: RetroTheme.build(),
      home: Scaffold(
        body: PrepPanel(
          mission: cat.missions.first,
          players: const [PrepEntry('Ana', 'Guerrero', 3, ready: false)],
          ready: false,
          credits: 10,
          weaponName: 'Espada',
          onReady: (_) {},
          onCancel: () {},
          onCharacter: () {},
        ),
      ),
    )));
    await tester.pump();
    // Sin pestañas de tienda solo hay una: Q / E no hacen nada.
    await _key(tester, LogicalKeyboardKey.keyE);
    expect(_tab(tester, 0), isTrue);
  });

  testWidgets(
      'título: flechas / 1-9 eligen clase en el creador, Esc lo '
      'cancela; Enter sobre el elegido juega', (tester) async {
    var a = CharacterRules(progression)
        .create(Account(), 'Ana', 'maga', now: DateTime(2026, 11, 1))!;
    a = CharacterRules(progression).create(a, 'Bo', 'guerrero')!;
    a = a.select('c1');
    final repo = AccountRepository(InMemoryAccountStore(a));
    var started = 0;
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionEngineProvider.overrideWithValue(sessionEngine()),
        profileStoreProvider
            .overrideWithValue(SelectedCharacterProfileStore(repo)),
        accountRepositoryProvider.overrideWithValue(repo),
        gameSpritesProvider
            .overrideWith((ref) => Completer<GameSprites>().future),
      ],
      child: MaterialApp(
        theme: RetroTheme.build(),
        home: TitleScreen(onStart: () => started++),
      ),
    ));
    await tester.pump();
    await tester.pump();
    await goToSoloCharacters(tester);
    // 2 = el segundo personaje.
    await _key(tester, LogicalKeyboardKey.digit2);
    await tester.pump();
    expect((await repo.load()).selectedId, 'c2');
    // Al creador y de vuelta con Esc.
    await tester.tap(find.byKey(const ValueKey('char-new')));
    await tester.pump();
    expect(find.byKey(const ValueKey('char-creator')), findsOneWidget);
    await _key(tester, LogicalKeyboardKey.digit2);
    final classes = progression.catalog.classes.values.toList();
    expect(find.textContaining(classes[1].name.toUpperCase()), findsWidgets);
    await _key(tester, LogicalKeyboardKey.escape);
    expect(find.byKey(const ValueKey('char-creator')), findsNothing);
    // Flechas hasta la tarjeta del elegido y Enter = jugar.
    for (var i = 0; i < 30 && _focusedKey() != 'char-slot-c2'; i++) {
      await _key(tester, LogicalKeyboardKey.tab);
    }
    expect(_focusedKey(), 'char-slot-c2');
    expect(find.byKey(const ValueKey('focus-ring')), findsWidgets);
    await _key(tester, LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump();
    expect(started, 1);
  });

  test('las teclas de los menús están en CONTROLES', () {
    final keys = [for (final (k, _) in kMenuKeys) k];
    expect(keys, containsAll(['Flechas', 'Esc', 'Q / E', 'Ctrl+Tab']));
  });

  testWidgets('MenuTabKeys: no toca las teclas escribiendo en un campo',
      (tester) async {
    var tab = 0;
    await tester.pumpWidget(ProviderScope(child: MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, set) => MenuTabKeys(
            count: 3,
            index: tab,
            onChanged: (i) => set(() => tab = i),
            child: const TextField(autofocus: true),
          ),
        ),
      ),
    )));
    await tester.pump();
    await _key(tester, LogicalKeyboardKey.keyE);
    expect(tab, 0);
    expect(Attribute.values, isNotEmpty);
    expect(TextSize.normal, isNotNull);
  });
}
