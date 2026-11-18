import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/models/atlas.dart';
import 'package:echos_del_tiempo/game_engine/models/atlas_store.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/eco.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/game_engine/rules/inventory_rules.dart';
import 'package:echos_del_tiempo/netcode/contracts/net_session.dart';
import 'package:echos_del_tiempo/netcode/loopback/loopback_net_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../game_engine/session_test_helpers.dart';

/// Un Eco en co-op por el protocolo real (docs/specs/ecos_atlas.md § 7):
/// el Atlas del anfitrión pone los mods gratis y cada jugador gana los
/// puntos en el Atlas de SU cuenta.
const _eco = EcoItem(
  uid: 'x',
  tier: 3,
  zone: 2,
  boss: 1,
  rarity: Rarity.magico,
  mods: [EcoModRoll('vida', 20)],
  floors: 1,
  seed: 99,
);

PlayerProfile _endgamer(String name, {List<EcoItem> ecos = const []}) {
  final p = zoneProgression
      .normalize(PlayerProfile(name: name, classId: 'guerrero', level: 50));
  var q = zoneProgression.allocate(p, {Attribute.vit: p.points})!.copyWith(
      ecosUnlocked: true, unlockedZone: 10);
  for (final e in ecos) {
    q = InventoryRules.addEco(q, e).$1;
  }
  return q;
}

void main() {
  late LoopbackHub hub;
  late SessionController host, ana;
  late InMemoryAtlasStore hostAtlas, anaAtlas;
  final controllers = <SessionController>[];

  Future<SessionController> make(
      NetSession net, ProfileStore store, AtlasStore atlas) async {
    final c = SessionController(
      engine: sessionEngine(zones: true),
      store: store,
      atlasStore: atlas,
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
  }

  setUp(() async {
    hub = LoopbackHub();
    // El anfitrión ya tiene 2 puntos gastados en "Modificador Gratis".
    hostAtlas = InMemoryAtlasStore(
        AtlasProgress(nodes: ['gratis'], done: ['z5', 'b5']));
    anaAtlas = InMemoryAtlasStore(AtlasProgress(done: ['t3']));
    final hp = _endgamer('Host', ecos: [_eco]);
    final hn = LoopbackNetSession(hub);
    await hn.connect(SessionConfig(profile: hp));
    host = await make(hn, InMemoryProfileStore(hp), hostAtlas);
    final an = LoopbackNetSession(hub);
    final ap = _endgamer('Ana');
    await an.connect(SessionConfig(profile: ap, roomCode: hn.roomCode));
    ana = await make(an, InMemoryProfileStore(ap), anaAtlas);
    await net();
  });

  tearDown(() async {
    for (final c in controllers) {
      if (c.mounted) c.dispose();
    }
    controllers.clear();
    await pumpEventQueue();
  });

  test('Eco en grupo: mods del host, +10% y puntos para cada cuenta', () async {
    expect(host.session!.atlas, ['gratis']);
    await net();
    expect(ana.view!.session.atlas, ['gratis'],
        reason: 'el cliente ve el Atlas de la sala');
    final uid = host.session!.players['h']!.profile.ecos.single.uid;
    expect(host.proposeEco(uid), isTrue);
    await net();
    ana.vote(true);
    await net();
    await net();
    expect(host.session!.mode, SessionMode.prep);
    host.setReady(true);
    ana.setReady(true);
    await net();
    await net();
    final s = host.session!;
    expect(s.mode, SessionMode.field);
    expect(s.eco!.mods, hasLength(2), reason: 'mod gratis del Atlas del host');
    expect(s.players['h']!.profile.ecos, isEmpty, reason: 'consumido');
    expect(ana.view!.session.mission!.missionId, 'eco');

    // Al jefe; enemigos a 1 de vida y el grupo sin caer.
    await net(3);
    final boss = s.mission!.enemies.singleWhere((x) => x.boss);
    host.teleport(boss.x, boss.y);
    for (var i = 0; i < 3000 && host.session!.mode != SessionMode.result; i++) {
      final b = host.session!.battle;
      if (b != null) {
        for (final en in b.state.enemies) {
          if (en.hp > 1) en.hp = 1;
        }
        for (final c in b.state.party) {
          if (c.alive) c.hp = c.maxHp;
        }
        final alive = b.state.enemies.where((x) => x.alive).toList()
          ..sort((x, y) => (x.boss ? 1 : 0) - (y.boss ? 1 : 0));
        final cmd = AttackCommand(targetId: alive.firstOrNull?.id);
        if (host.view!.myTurn) host.battleCommand(cmd);
        if (ana.view!.myTurn) ana.battleCommand(cmd);
      }
      await net();
    }
    expect(host.session!.result!.success, isTrue);
    await net();

    // Cada uno, en su cuenta: tier 3 (Ana ya lo tenía), zona 2, jefe 1.
    final h = await hostAtlas.load();
    expect(h.done, containsAll(['t3', 'z2', 'b1', 'z5', 'b5']));
    expect(h.nodes, ['gratis'], reason: 'no toca los nodos');
    expect(host.view!.atlasGain!.points, 3);
    final a = await anaAtlas.load();
    expect(a.done, {'t3', 'z2', 'b1'});
    expect(ana.view!.atlasGain!.points, 2);
    expect(ana.view!.atlasGain!.keys, ['z2', 'b1']);
    // Y los dos se llevan un Eco nuevo.
    expect(host.session!.players['h']!.profile.ecos, hasLength(1));
    expect(host.session!.players['p1']!.profile.ecos, hasLength(1));
  });

  test('el Atlas se edita solo en el pueblo y el host lo comparte', () async {
    expect(host.canEditAtlas, isTrue);
    expect(host.resetAtlas(), isTrue);
    expect(host.session!.atlas, isEmpty);
    expect(host.takeAtlasNode('brillo'), isTrue);
    await net();
    expect(ana.view!.session.atlas, ['brillo']);
    // El cliente edita el suyo, pero la sala sigue con el del host.
    expect(ana.takeAtlasNode('rutas'), isFalse, reason: 'sin puntos');
    expect((await hostAtlas.load()).nodes, ['brillo']);
  });
}
