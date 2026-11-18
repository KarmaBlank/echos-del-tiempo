import 'package:echos_del_tiempo/app/app.dart';
import 'package:echos_del_tiempo/features/characters/data/account_repository.dart';
import 'package:echos_del_tiempo/features/characters/data/account_store.dart';
import 'package:echos_del_tiempo/features/characters/domain/account.dart';
import 'package:echos_del_tiempo/features/characters/presentation/characters_providers.dart';
import 'package:echos_del_tiempo/features/combat/presentation/battle_screen.dart';
import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
import 'package:echos_del_tiempo/features/missions/presentation/results_panel.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/map_game.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_view.dart';
import 'package:echos_del_tiempo/features/world/presentation/world_screen.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import 'world_test_helpers.dart';

void main() {
  testWidgets('título → lobby → misión → batalla → resultado → lobby',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // Decodificar imágenes necesita el reloj real.
    late GameSprites sprites;
    await tester.runAsync(() async {
      sprites = await GameSprites.load(await SpriteCatalog.load());
    });
    // La cuenta con un personaje; la sesión juega con el elegido
    // (docs/specs/characters.md § 1).
    final accounts = AccountRepository(InMemoryAccountStore(
        CharacterRules(progression).create(Account(), '', 'guerrero')));
    final store = SelectedCharacterProfileStore(accounts);

    await tester.pumpWidget(EcosApp(overrides: [
      sessionEngineProvider.overrideWithValue(sessionEngine()),
      profileStoreProvider.overrideWithValue(store),
      accountRepositoryProvider.overrideWithValue(accounts),
      gameSpritesProvider.overrideWith((ref) => sprites),
    ]));

    // ---- título → lobby ----
    await tester.pump(); // carga la cuenta
    await tester.tap(find.text('> JUGAR'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(WorldScreen), findsOneWidget);
    expect(find.byType(GameWidget<MapGame>), findsOneWidget);
    final c = ProviderScope.containerOf(tester.element(find.byType(WorldScreen)))
        .read(sessionControllerProvider.notifier);
    expect(c.view!.mode, SessionMode.lobby);
    expect(find.textContaining('Lobby · Mostrador [E]'), findsOneWidget);

    // ---- caminar con las flechas hasta el mostrador ----
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowUp);
    for (var i = 0; i < 90; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump(const Duration(milliseconds: 100));
    expect(c.view!.prompt, WorldPrompt.missionBoard);
    expect(find.text('[E] Ver misiones'), findsOneWidget);

    // ---- E abre el mostrador; proponer la misión ----
    await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
    await tester.pump();
    expect(find.text('MOSTRADOR DE MISIONES'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('propose-m1')));
    await tester.pump(const Duration(milliseconds: 100));

    // Con un solo jugador la votación pasa sola → preparación.
    expect(c.view!.mode, SessionMode.prep);
    expect(find.textContaining('PREPARACION'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('prep-ready')));
    await tester.pump(const Duration(milliseconds: 100));

    // ---- el mapa de la misión con su HUD ----
    expect(c.view!.mode, SessionMode.field);
    expect(find.byType(GameWidget<MapGame>), findsOneWidget);
    expect(find.textContaining('Grupos derrotados 0/'), findsOneWidget);
    expect(find.textContaining('Pradera Esmeralda · Grupos'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));

    // ---- batalla: el comando con la tecla 1 se acepta ----
    startBattleWithFirstGroup(c);
    await tester.pump();
    expect(find.byType(BattleView), findsOneWidget);
    waitForMyTurn(c);
    await tester.pump();
    expect(find.byKey(const ValueKey('battle-act-attack')), findsOneWidget);
    final seq = c.view!.battleEventSeq;
    final hp = c.view!.session.battle!.state.enemies.first.hp;
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.pump();
    expect(c.view!.battleEventSeq, greaterThan(seq));
    expect(c.view!.session.battle!.state.enemies.first.hp, lessThan(hp));

    // ---- jugar hasta el resultado (subida de nivel por la UI) ----
    var allocatedInUi = false;
    for (var i = 0; i < 40000 && c.view!.mode != SessionMode.result; i++) {
      final v = c.view!;
      if (v.mode == SessionMode.levelUp && v.mustAllocate) {
        await tester.pump();
        expect(find.textContaining('¡SUBISTE A NIVEL'), findsOneWidget);
        for (var p = 0; p < v.me!.profile.points; p++) {
          await tester.tap(find.byKey(const ValueKey('inc-vit')));
          await tester.pump();
        }
        await tester.tap(find.text('CONFIRMAR PUNTOS'));
        await tester.pump();
        allocatedInUi = true;
        continue;
      }
      if (v.mode == SessionMode.battle && v.myTurn) {
        c.battleCommand(const AttackCommand());
      } else if (v.mode == SessionMode.field && v.session.graceLeft <= 0) {
        // Grupos normales hasta subir de nivel; después, directo al jefe
        // (bajando por las escaleras si está en otro piso).
        if (allocatedInUi) {
          final (x, y) = bossOrStairs(c);
          c.teleport(x, y);
        } else {
          final m = v.session.mission!;
          final target = m.enemies.firstWhere((e) =>
              e.alive && !e.boss && !e.elite && e.floor == m.floor);
          c.teleport(target.x, target.y);
        }
      }
      c.advance(0.05);
    }
    await tester.pump();
    expect(c.view!.mode, SessionMode.result);
    expect(find.byType(ResultsPanel), findsOneWidget);
    expect(
        find.text('MISION COMPLETADA').evaluate().length +
            find.text('MISION FALLIDA').evaluate().length,
        1);
    expect(allocatedInUi, isTrue);

    // ---- volver al lobby ----
    await tester.tap(find.byKey(const ValueKey('results-back')));
    await tester.pump();
    expect(c.view!.mode, SessionMode.lobby);
    expect(find.textContaining('Lobby · Mostrador [E]'), findsOneWidget);

    // ---- salir al título: se descarta la sesión y se guarda ----
    await tester.tap(find.text('< TITULO'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('> JUGAR'), findsOneWidget);
    final saved = await store.load();
    expect(saved!.level, greaterThan(1));
    // La lista del título se refrescó con el progreso guardado.
    expect(find.text('Guerrero · Nv ${saved.level}'), findsOneWidget);
  });
}
