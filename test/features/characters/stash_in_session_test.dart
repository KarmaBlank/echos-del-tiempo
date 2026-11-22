import 'package:echos_del_tiempo/features/characters/data/account_repository.dart';
import 'package:echos_del_tiempo/features/characters/data/account_store.dart';
import 'package:echos_del_tiempo/features/characters/domain/account.dart';
import 'package:echos_del_tiempo/features/characters/domain/stash.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_view.dart';
import 'package:echos_del_tiempo/game_engine/models/eco.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/loot.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/rules/inventory_rules.dart';
import 'package:echos_del_tiempo/game_engine/serialization/action_json.dart';
import 'package:echos_del_tiempo/game_engine/serialization/session_json.dart';
import 'package:echos_del_tiempo/netcode/contracts/net_session.dart';
import 'package:echos_del_tiempo/netcode/loopback/loopback_net_session.dart';
import 'package:echos_del_tiempo/netcode/protocol/wire.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../game_engine/session_test_helpers.dart';
import '../inventory/loot_fixtures.dart';

/// Alijo en partida (docs/specs/characters.md § 3.2): `stashPut` /
/// `stashTake` validados por el host, confirmación `sk`, idempotencia y
/// lotes.
const _eco = EcoItem(
  uid: 'eco1',
  tier: 2,
  zone: 1,
  boss: 1,
  rarity: Rarity.magico,
  mods: [EcoModRoll('vida', 30)],
);

PlayerProfile _hero() {
  var p = newProfile('Ana', 'guerrero');
  p = InventoryRules.addItem(p, epicSword).$1;
  p = InventoryRules.addItem(p, rareAxe).$1;
  p = InventoryRules.addEco(p, _eco).$1;
  return InventoryRules.relayout(p.copyWith(
      materials: const {CraftMaterial.cristal: 10, CraftMaterial.ancla: 3}));
}

String _uid(PlayerProfile p, String base) =>
    p.items.firstWhere((i) => i.baseId == base).uid;

void main() {
  group('motor', () {
    final e = sessionEngine();
    GameSession room(PlayerProfile p) =>
        e.addPlayer(e.create(), 'p0', p)!.state;

    test('poner: sale del perfil y queda la confirmación', () {
      final p = _hero();
      final uid = _uid(p, 'espada_ignea');
      final s = act(e, room(p), 'p0', StashPutAction('op1', [StashPutItem(uid)]));
      final me = s.players['p0']!;
      expect(me.profile.itemByUid(uid), isNull);
      expect(me.stashAcks['op1']!.put, isTrue);
      expect(me.stashAcks['op1']!.drops.single!.item!.uid, uid);
    });

    test('idempotente: el mismo id no se aplica dos veces', () {
      final p = _hero();
      var s = act(e, room(p), 'p0',
          const StashPutAction('op1', [StashPutItem('mat:cristal', count: 4)]));
      expect(s.players['p0']!.profile.material(CraftMaterial.cristal), 6);
      expect(
          e.apply(s, 'p0',
              const StashPutAction('op1', [StashPutItem('mat:cristal', count: 4)])),
          isNull);
      s = act(e, s, 'p0',
          const StashTakeAction('op2', [LootDrop.stack(StackKind.cristal, 2)]));
      expect(e.apply(s, 'p0',
              const StashTakeAction('op2', [LootDrop.stack(StackKind.cristal, 2)])),
          isNull);
      expect(s.players['p0']!.profile.material(CraftMaterial.cristal), 8);
    });

    test('rechaza la equipada, el arma inicial y las pociones', () {
      final p = _hero();
      final s = room(p);
      for (final t in [p.equippedUid!, 'pot', 'eter']) {
        expect(e.apply(s, 'p0', StashPutAction('x$t', [StashPutItem(t)])),
            isNull, reason: t);
      }
    });

    test('lote: los protegidos nunca se mueven, el resto sí', () {
      final p = _hero();
      final s = act(e, room(p), 'p0', StashPutAction('lote', [
        StashPutItem(p.equippedUid!),
        StashPutItem(_uid(p, 'espada_ignea')),
        const StashPutItem('pot'),
        StashPutItem(p.ecos.first.uid),
      ]));
      final me = s.players['p0']!;
      final d = me.stashAcks['lote']!.drops;
      expect(d[0], isNull);
      expect(d[1], isNotNull);
      expect(d[2], isNull);
      expect(d[3]!.eco!.uid, p.ecos.first.uid);
      expect(me.profile.equippedUid, p.equippedUid);
      expect(me.profile.ecos, isEmpty);
    });

    test('sacar con el inventario lleno se rechaza', () {
      var p = newProfile('Ana', 'guerrero');
      while (InventoryRules.freeCells(p) > 0) {
        p = InventoryRules.addItem(p, rareAxe).$1;
      }
      expect(
          e.apply(room(p), 'p0', const StashTakeAction('t', [LootDrop.item(epicSword)])),
          isNull);
    });

    test('no se abre en batalla', () {
      final s = room(_hero())..mode = SessionMode.battle;
      expect(
          e.apply(s, 'p0', const StashPutAction('b', [StashPutItem('mat:cristal')])),
          isNull);
    });

    test('red: acciones y confirmaciones viajan', () {
      const a = StashPutAction('op', [StashPutItem('mat:ancla', count: 3)]);
      final back = ActionJson.fromJson(ActionJson.toJson(a)) as StashPutAction;
      expect(back.opId, 'op');
      expect(back.items.single.count, 3);
      const t = StashTakeAction('op2', [LootDrop.eco(_eco)]);
      final tb = ActionJson.fromJson(ActionJson.toJson(t)) as StashTakeAction;
      expect(tb.drops.single.eco!.uid, 'eco1');
      final s = act(e, room(_hero()), 'p0', a);
      final codec = SessionJson(e.catalog);
      final p = codec.playerFromJson(codec.playerToJson(s.players['p0']!));
      expect(p.stashAcks['op']!.drops.single!.count, 3);
      expect(kProtocolVersion, greaterThanOrEqualTo(22));
    });
  });

  group('tablero', () {
    final rules = StashRules(inventory: progression.inventory);

    test('Ecos y endgame van a la pestaña ECOS', () {
      final p = _hero();
      final b = rules.depositMany(p, Stash.empty(), [p.ecos.first.uid, 'mat:ancla', 'mat:cristal']);
      expect(b.moved.length, 3);
      final eco = b.stash.cells.indexWhere((c) => c?.eco != null);
      final anc = b.stash.cells.indexWhere((c) => c?.material == CraftMaterial.ancla);
      final cri = b.stash.cells.indexWhere((c) => c?.material == CraftMaterial.cristal);
      expect(eco ~/ Stash.perTab, Stash.ecoTab);
      expect(anc ~/ Stash.perTab, Stash.ecoTab);
      expect(cri ~/ Stash.perTab, isNot(Stash.ecoTab));
      // Un arma no entra a la pestaña ECOS.
      final w = rules.deposit(p, Stash.empty(), _uid(p, 'hacha_rompe'));
      final at = w.stash!.cells.indexWhere((c) => c != null);
      expect(StashRules.move(w.stash!, at, Stash.ecoTab * Stash.perTab), isNull);
    });

    test('MOVER TODO con el alijo casi lleno', () {
      final p = _hero();
      var s = Stash.empty();
      // Generales llenas salvo una casilla; ECOS llena.
      for (var i = 0; i < Stash.size - 1; i++) {
        s = s.put(i, const StashEntry.item(rareAxe));
      }
      final all = rules.movableTokens(p);
      expect(all, isNot(contains(p.equippedUid)));
      expect(all, isNot(contains('pot')));
      final b = rules.depositMany(p, s, all);
      expect(b.moved.length, 1);
      expect(b.left, all.length - 1);
      expect(b.summary(), startsWith('Movidos 1 · Quedaron '));
      expect(b.summary(), endsWith('alijo lleno'));
    });

    test('elegir 3 y moverlos', () {
      final p = _hero();
      final b = rules.depositMany(p, Stash.empty(),
          [_uid(p, 'espada_ignea'), p.ecos.first.uid, 'mat:cristal']);
      expect(b.moved.length, 3);
      expect(b.summary(), 'Movidos 3');
      final back = rules.withdrawMany(b.profile, b.stash, [
        for (var i = 0; i < Stash.size; i++)
          if (b.stash.cells[i] != null) i
      ]);
      expect(back.moved.length, 3);
      expect(back.stash.isEmpty, isTrue);
    });
  });

  group('controlador (loopback host + cliente)', () {
    final controllers = <SessionController>[];
    tearDown(() {
      for (final c in controllers) {
        if (c.mounted) c.dispose();
      }
      controllers.clear();
    });

    SessionController make(NetSession? net, ProfileStore store,
        [StashStore? stash]) {
      final c = SessionController(
        engine: sessionEngine(),
        store: store,
        stashStore: stash,
        clock: const SessionClock(autoStart: false),
        net: net,
      );
      controllers.add(c);
      return c;
    }

    Future<void> tick(SessionController host, List<SessionController> all,
        [double s = 0.05]) async {
      for (final c in all) {
        if (c != host && c.mounted) c.advance(0.05);
      }
      await pumpEventQueue();
      host.advance(s);
      await pumpEventQueue();
    }

    Future<(SessionController, SessionController, AccountRepository)>
        setup() async {
      final mine = progression.normalize(_hero());
      final repo = AccountRepository(InMemoryAccountStore(Account().add(mine)!));
      final hub = LoopbackHub();
      final hn = LoopbackNetSession(hub), cn = LoopbackNetSession(hub);
      final other =
          progression.normalize(PlayerProfile(name: 'Amigo', classId: 'maga'));
      await hn.connect(SessionConfig(profile: other));
      final host = make(hn, InMemoryProfileStore(other),
          AccountStashStore(AccountRepository(InMemoryAccountStore())));
      await host.start();
      await cn.connect(SessionConfig(profile: mine, roomCode: hn.roomCode));
      final me = make(cn, SelectedCharacterProfileStore(repo),
          AccountStashStore(repo));
      await me.start();
      for (var i = 0; i < 3; i++) {
        await tick(host, [host, me]);
      }
      return (host, me, repo);
    }

    Future<void> settle(SessionController host, SessionController me) async {
      for (var i = 0; i < 4; i++) {
        await tick(host, [host, me]);
      }
    }

    test('lobby: poner y sacar; el host no ve el alijo', () async {
      final (host, me, repo) = await setup();
      final p = me.view!.me!.profile;
      final uid = _uid(p, 'espada_ignea');
      expect(me.stashBlock, isNull);
      expect(me.stashPut([uid]), isNull);
      expect(me.stashBusy, isTrue);
      await settle(host, me);
      expect(me.stashBusy, isFalse);
      expect(me.stashNotice, 'Movidos 1');
      var a = await repo.load();
      expect(a.stash.used, 1);
      expect(a.selected!.profile.itemByUid(uid), isNull);
      expect(host.stash!.isEmpty, isTrue);
      // Sacar.
      final cell = a.stash.cells.indexWhere((c) => c != null);
      expect(me.stashTake([cell]), isNull);
      await settle(host, me);
      a = await repo.load();
      expect(a.stash.isEmpty, isTrue);
      expect(a.selected!.profile.items.any((i) => i.baseId == 'espada_ignea'),
          isTrue);
    });

    test('misión: poner un Eco (va a ECOS); en batalla no se abre', () async {
      final (host, me, repo) = await setup();
      expect(host.proposeMission('m1'), isTrue);
      await tick(host, [host, me]);
      me.vote(true);
      await tick(host, [host, me], 0.1);
      await tick(host, [host, me], 0.1);
      host.setReady(true);
      me.setReady(true);
      await tick(host, [host, me], 0.1);
      await tick(host, [host, me], 0.1);
      expect(me.session!.mode, SessionMode.field);
      expect(me.stashPut([me.view!.me!.profile.ecos.first.uid]), isNull);
      await settle(host, me);
      final a = await repo.load();
      final at = a.stash.cells.indexWhere((c) => c?.eco != null);
      expect(at ~/ Stash.perTab, Stash.ecoTab);
      // Batalla: el panel no se abre.
      await tick(host, [host, me], host.session!.graceLeft + 0.1);
      for (var i = 0; i < 400 && host.session!.mode != SessionMode.battle; i++) {
        final boss = host.session!.mission!.enemies.firstWhere((e) => e.boss);
        host.teleport(boss.x, boss.y);
        await tick(host, [host, me], 0.1);
      }
      expect(me.session!.mode, SessionMode.battle);
      expect(me.stashBlock, isNotNull);
      me.handleKey(LogicalKeyboardKey.keyB);
      expect(me.view!.panel, isNot(WorldPanel.stash));
      expect(me.stashPut(['mat:cristal']), isNotNull);
    });

    test('loot propio del piso: al cerrarse el mapa va al alijo del cliente '
        '(y lleno, a Objetos sin recoger)', () async {
      final (host, me, repo) = await setup();
      final id = me.localId;
      host.session!.ground
        ..add(GroundLoot(id: 500, drop: const LootDrop.item(epicSword), x: 0, y: 0,
            ownerId: id))
        ..add(GroundLoot(id: 501, drop: const LootDrop.item(rareAxe), x: 0, y: 0,
            ownerId: host.localId));
      expect(host.proposeMission('m1'), isTrue);
      await tick(host, [host, me]);
      me.vote(true);
      await tick(host, [host, me], 0.1);
      await tick(host, [host, me], 0.1);
      host.setReady(true);
      me.setReady(true);
      await tick(host, [host, me], 0.1);
      await settle(host, me);
      expect(me.session!.mode, SessionMode.field);
      final a = await repo.load();
      expect(a.stash.cells.any((c) => c?.item?.uid == epicSword.uid), isTrue);
      // Lo del host, en el alijo del host (no en el del cliente).
      expect(a.stash.cells.any((c) => c?.item?.uid == rareAxe.uid), isFalse);
      expect(host.stash!.cells.any((c) => c?.item?.uid == rareAxe.uid), isTrue);
      expect(me.view!.messages.join(' '), contains('se guardó en el alijo'));
    });

    test('Objetos sin recoger: TOMAR pasa por el host, DESCARTAR es local',
        () async {
      final (host, me, repo) = await setup();
      await repo.update((a) => a.withStash(Stash.empty().withUnclaimed([
            const StashEntry.item(epicSword),
            const StashEntry.material(CraftMaterial.prisma, 2),
          ])));
      // Recargar el alijo del controlador.
      final me2 = make(null, SelectedCharacterProfileStore(repo),
          AccountStashStore(repo));
      await me2.start();
      expect(me2.stash!.unclaimed, hasLength(2));
      final before = me2.view!.me!.profile.items.length;
      expect(me2.unclaimedTake(0), isNull);
      me2.advance(0.05);
      await pumpEventQueue();
      expect(me2.stash!.unclaimed, hasLength(1));
      expect(me2.view!.me!.profile.items.length, before + 1);
      expect(me2.unclaimedDiscard(0), isTrue);
      await pumpEventQueue();
      expect((await repo.load()).stash.unclaimed, isEmpty);
      expect(host.mounted && me.mounted, isTrue);
    });

    test('rechazo de la equipada y alijo lleno (no se manda nada)', () async {
      final (host, me, repo) = await setup();
      final p = me.view!.me!.profile;
      expect(me.stashPutReason(p.equippedUid!), 'Equipada');
      expect(me.stashPut([p.equippedUid!]), 'Equipada');
      expect(me.stashBusy, isFalse);
      var full = Stash.empty();
      for (var i = 0; i < Stash.size; i++) {
        full = full.put(i, const StashEntry.item(rareAxe));
      }
      await repo.update((a) => a.withStash(full));
      // Con el alijo lleno, desde una sesión nueva (solo).
      final c = make(null, SelectedCharacterProfileStore(repo),
          AccountStashStore(repo));
      await c.start();
      expect(c.stashPut([_uid(c.view!.me!.profile, 'espada_ignea')]),
          StashRules.stashFull);
    });

    test('inventario lleno: sacar no se manda', () async {
      var p = newProfile('Ana', 'guerrero');
      while (InventoryRules.freeCells(p) > 0) {
        p = InventoryRules.addItem(p, rareAxe).$1;
      }
      final repo = AccountRepository(InMemoryAccountStore(
          Account().add(p)!.withStash(
              Stash.empty().put(0, const StashEntry.item(epicSword)))));
      final c = make(null, SelectedCharacterProfileStore(repo),
          AccountStashStore(repo));
      await c.start();
      expect(c.stashTake([0]), 'Inventario lleno');
    });

    test('reintento con el mismo id no duplica', () async {
      final (host, me, repo) = await setup();
      expect(me.stashPut(['mat:cristal']), isNull);
      // El cliente reenvía (1 s sin confirmación) antes de leer el
      // snapshot: el host lo ignora.
      for (var i = 0; i < 25; i++) {
        me.advance(0.05);
      }
      await settle(host, me);
      final a = await repo.load();
      expect(a.stash.cells[a.stash.cellOf(CraftMaterial.cristal)!]!.count, 10);
      expect(a.selected!.profile.material(CraftMaterial.cristal), 0);
      expect(host.session!.players[me.localId]!.profile
          .material(CraftMaterial.cristal), 0);
    });

    test('desconexión a mitad: no se pierde ni se duplica', () async {
      final (host, me, repo) = await setup();
      final uid = _uid(me.view!.me!.profile, 'espada_ignea');
      expect(me.stashPut([uid]), isNull);
      // El host se cae antes de confirmar.
      host.dispose();
      await pumpEventQueue();
      await me.saveNow();
      await pumpEventQueue();
      expect(me.stashBusy, isFalse);
      final a = await repo.load();
      expect(a.stash.isEmpty, isTrue);
      expect(a.selected!.profile.itemByUid(uid), isNotNull);
    });
  });
}
