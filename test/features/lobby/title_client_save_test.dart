import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/features/characters/data/account_repository.dart';
import 'package:echos_del_tiempo/features/characters/data/account_store.dart';
import 'package:echos_del_tiempo/features/characters/domain/account.dart';
import 'package:echos_del_tiempo/features/characters/presentation/characters_providers.dart';
import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
import 'package:echos_del_tiempo/features/lobby/presentation/title_screen.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/features/world/presentation/world_screen.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/netcode/contracts/net_session.dart';
import 'package:echos_del_tiempo/netcode/contracts/net_session_factory.dart';
import 'package:echos_del_tiempo/netcode/loopback/loopback_net_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';

/// Regresión v0.4 ("cuando jugó solo el personaje no guardó lo jugado
/// conmigo"): el título, la sala como CLIENTE y después la partida solo
/// comparten la cuenta como en la app (docs/specs/characters.md § 1).
void main() {
  testWidgets('cliente: lo jugado en la sala sigue al jugar solo después',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late GameSprites sprites;
    await tester.runAsync(() async {
      sprites = await GameSprites.load(await SpriteCatalog.load());
    });
    final start = zoneProgression
        .normalize(PlayerProfile(name: 'Ana', classId: 'guerrero', level: 5));
    final disk = InMemoryAccountStore(Account().add(start));
    final repo = AccountRepository(disk);
    final hub = LoopbackHub();

    // El anfitrión (otra PC).
    final hn = LoopbackNetSession(hub);
    final hp = zoneProgression
        .normalize(PlayerProfile(name: 'Host', classId: 'guerrero'));
    await hn.connect(SessionConfig(profile: hp));
    final host = SessionController(
      engine: sessionEngine(zones: true),
      store: InMemoryProfileStore(hp),
      clock: const SessionClock(autoStart: false),
      net: hn,
    );
    await host.start();
    addTearDown(() {
      if (host.mounted) host.dispose();
    });

    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionEngineProvider.overrideWithValue(sessionEngine(zones: true)),
        accountRepositoryProvider.overrideWithValue(repo),
        // Como en la app: el store de la sesión es el elegido de la cuenta.
        profileStoreProvider
            .overrideWithValue(SelectedCharacterProfileStore(repo)),
        atlasStoreProvider.overrideWithValue(AccountAtlasStore(repo)),
        sessionClockProvider
            .overrideWithValue(const SessionClock(autoStart: false)),
        gameSpritesProvider.overrideWith((ref) => sprites),
        netSessionFactoryProvider.overrideWithValue(NetSessionFactory(
            label: 'LAN',
            codeHint: 'IP:PUERTO',
            create: () => LoopbackNetSession(hub))),
      ],
      child: MaterialApp(theme: RetroTheme.build(), home: const TitleScreen()),
    ));
    await tester.pump();
    await tester.pump();

    // Se une a la sala.
    await tester.enterText(
        find.byKey(const ValueKey('title-code')), hn.roomCode!);
    await tester.tap(find.text('UNIRSE'));
    for (var i = 0; i < 6; i++) {
      await tester.pump();
    }
    expect(find.byType(WorldScreen), findsOneWidget);
    SessionController client() => ProviderScope.containerOf(
            tester.element(find.byType(WorldScreen)))
        .read(sessionControllerProvider.notifier);
    final ana = client();
    expect(ana.isClient, isTrue);

    Future<void> net([double s = 0.05]) async {
      if (ana.mounted) ana.advance(0.05);
      await tester.pump();
      host.advance(s);
      await tester.pump();
    }

    await net();
    await net();
    expect(ana.allocate({Attribute.vit: start.points}), isTrue);
    for (var i = 0; i < 50; i++) {
      await net();
    }
    expect(host.session!.players[ana.localId]!.profile.points, 0);

    // Vuelve al título (SALIR AL TÍTULO) y juega solo.
    Navigator.of(tester.element(find.byType(WorldScreen))).pop();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byType(WorldScreen), findsNothing);
    expect(repo.current!.selected!.profile.points, 0,
        reason: 'la cuenta en memoria tiene lo jugado en la sala');

    await tester.tap(find.text('> JUGAR SOLO'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byType(WorldScreen), findsOneWidget);
    final solo = client();
    expect(solo.isClient, isFalse);
    final me = solo.session!.players[solo.localId]!.profile;
    expect(me.points, 0, reason: 'solo arranca con lo jugado en la sala');
    expect(me.attributes[Attribute.vit],
        start.attributes[Attribute.vit] + start.points * 3);

    // Y en "disco".
    final fresh = (await disk.load()).account.selected!.profile;
    expect(fresh.points, 0);

    Navigator.of(tester.element(find.byType(WorldScreen))).pop();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  });
}
