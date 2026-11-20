import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/models/achievement.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/game_engine/models/session_event.dart';
import 'package:echos_del_tiempo/netcode/contracts/net_session.dart';
import 'package:echos_del_tiempo/netcode/loopback/loopback_net_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../game_engine/session_test_helpers.dart';

/// Hazañas en co-op por el protocolo real (docs/specs/achievements.md §
/// 5): el cliente avisa la suya, el host la paga en el perfil de sesión
/// de ESE jugador y la emite; el toast es solo del que la logró; al
/// guardar queda en su perfil y no se vuelve a pagar.
void main() {
  late LoopbackHub hub;
  late SessionController host, ana;
  late InMemoryProfileStore anaStore;
  final controllers = <SessionController>[];

  Future<SessionController> make(NetSession net, ProfileStore store) async {
    final c = SessionController(
      engine: sessionEngine(achievements: true),
      store: store,
      clock: const SessionClock(autoStart: false),
      net: net,
    );
    controllers.add(c);
    await c.start();
    return c;
  }

  Future<void> net([double seconds = 0.05]) async {
    if (ana.mounted) ana.advance(0.05);
    await pumpEventQueue();
    host.advance(seconds);
    await pumpEventQueue();
    if (ana.mounted) ana.advance(0.05);
    await pumpEventQueue();
  }

  setUp(() async {
    hub = LoopbackHub();
    final hn = LoopbackNetSession(hub);
    await hn.connect(SessionConfig(profile: newProfile('Host', 'guerrero')));
    host = await make(hn, InMemoryProfileStore(newProfile('Host', 'guerrero')));
    final an = LoopbackNetSession(hub);
    anaStore = InMemoryProfileStore(newProfile('Ana', 'maga'));
    await an.connect(SessionConfig(
        profile: newProfile('Ana', 'maga'), roomCode: hn.roomCode));
    ana = await make(an, anaStore);
    await net();
  });

  tearDown(() async {
    for (final c in controllers) {
      if (c.mounted) c.dispose();
    }
    controllers.clear();
    await pumpEventQueue();
  });

  test('el cliente la avisa, el host paga solo a ese jugador', () async {
    final hostEvents = <SessionEvent>[];
    host.events.listen(hostEvents.add);
    final pot = ana.view!.me!.profile.potions;
    expect(ana.claimAchievement('inv_search'), isTrue);
    await net(0.1);
    await net(0.1);
    final me = ana.view!.me!.profile;
    expect(me.achievements.isDone('inv_search'), isTrue);
    expect(me.potions, pot + 2, reason: 'el host pagó en su perfil de sesión');
    expect(ana.achievementLog.map((e) => e.id), ['inv_search']);
    expect(host.achievementLog, isEmpty, reason: 'el toast es solo de Ana');
    expect(
        hostEvents.whereType<AchievementUnlockedEvent>().single.playerId,
        ana.localId);
    expect(host.view!.me!.profile.achievements.isEmpty, isTrue);
    // Ya lograda: no se vuelve a pedir ni a pagar.
    expect(ana.claimAchievement('inv_search'), isFalse);
    // Quedó en su perfil guardado (va a la cuenta al guardar).
    ana.dispose();
    await pumpEventQueue();
    final saved = await anaStore.load();
    expect(saved!.achievements.isDone('inv_search'), isTrue);
    expect(saved.achievements, isA<AchievementProgress>());
  });

  test('al reconectar con su perfil guardado no se paga de nuevo', () async {
    ana.claimAchievement('inv_search');
    await net(0.1);
    await net(0.1);
    ana.dispose();
    await pumpEventQueue();
    await net(0.1);
    final saved = (await anaStore.load())!;
    // Vuelve a entrar con lo que guardó.
    final an = LoopbackNetSession(hub);
    await an.connect(SessionConfig(profile: saved, roomCode: host.net!.roomCode));
    ana = await make(an, InMemoryProfileStore(saved));
    await net(0.1);
    final pot = ana.view!.me!.profile.potions;
    expect(ana.view!.me!.profile.achievements.isDone('inv_search'), isTrue);
    expect(ana.claimAchievement('inv_search'), isFalse);
    await net(0.1);
    expect(ana.view!.me!.profile.potions, pot);
    expect(ana.achievementLog, isEmpty);
  });
}
