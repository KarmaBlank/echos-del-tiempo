import 'dart:convert';

import 'package:echos_del_tiempo/game_engine/data/exploration_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/zones_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/session_event.dart';
import 'package:echos_del_tiempo/game_engine/rules/exploration_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/map_generator.dart';
import 'package:echos_del_tiempo/game_engine/rules/session_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/world_rules.dart';
import 'package:echos_del_tiempo/game_engine/serialization/action_json.dart';
import 'package:echos_del_tiempo/game_engine/serialization/event_json.dart';
import 'package:echos_del_tiempo/game_engine/serialization/json_read.dart';
import 'package:echos_del_tiempo/game_engine/serialization/session_json.dart';
import 'package:echos_del_tiempo/game_engine/data/tuning_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// Una semilla cuyo piso 1 de la zona [zone] cumple [ok].
int seedWith(int zone, bool Function(MapFloor f) ok) {
  for (var seed = 1; seed < 4000; seed++) {
    if (ok(MapGenerator.zone(kZones[zone - 1], seed).floors.first)) return seed;
  }
  throw StateError('sin semilla');
}

MapPoi poiOf(MapFloor f, PoiKind k) => f.pois.firstWhere((p) => p.kind == k);

/// Un centro caminable junto al tile del PdI.
WorldPoint beside(GameMap m, int tx, int ty) {
  for (final (dx, dy) in const [(0, 1), (1, 0), (-1, 0), (0, -1)]) {
    final x = (tx + dx) * 16 + 8.0, y = (ty + dy) * 16 + 8.0;
    if (!WorldRules.collides(m, x, y, blockVoid: true)) return WorldPoint(x, y);
  }
  throw StateError('sin lugar junto a $tx,$ty');
}

void main() {
  ({SessionEngine e, GameSession s, MapFloor f}) start(
      int zone, bool Function(MapFloor f) ok,
      {List<double> rolls = const [], int players = 1}) {
    final seed = seedWith(zone, ok);
    final e = sessionEngine(zones: true, seed: seed, fieldRolls: rolls);
    final s = inField(e, kZones[zone - 1].missionId!,
        profiles: [
          for (var i = 0; i < players; i++)
            newProfile('J$i', 'guerrero').copyWith(unlockedZone: 10),
        ]);
    return (e: e, s: s, f: e.mapFor(s).floor(0)!);
  }

  GameSession use(SessionEngine e, GameSession s, MapPoi p, {String id = 'p0'}) {
    final at = p.kind == PoiKind.shortcut
        ? WorldPoint(p.side!.$1 * 16 + 8.0, p.side!.$2 * 16 + 8.0)
        : beside(e.mapFor(s), p.tx, p.ty);
    s = moveTo(e, s, id, at.x, at.y);
    return act(e, s, id, InteractPoiAction(p.id));
  }

  test('sala secreta: cerrada hasta E; abierta se camina y tiene su cofre', () {
    final r = start(1, (f) => f.pois.any((p) => p.kind == PoiKind.secret));
    var s = r.s;
    final e = r.e;
    final sec = poiOf(r.f, PoiKind.secret);
    final chest = s.mission!.items.firstWhere((i) => i.secret == sec.id);
    expect(chest.tier, isNot(ChestTier.madera));
    expect(WorldRules.isSolid(e.mapFor(s), sec.tx, sec.ty), isTrue);
    // Lejos: rechazado.
    expect(e.apply(s, 'p0', InteractPoiAction(sec.id)), isNull);
    s = use(e, s, sec);
    expect(s.mission!.poiUsed, contains(sec.id));
    final m = e.mapFor(s);
    expect(m.tileAt(sec.tx, sec.ty), Tile.vaultFloor);
    expect(WorldRules.isSolid(m, sec.tx, sec.ty), isFalse);
    expect(m.tileAt(sec.chest!.$1, sec.chest!.$2), Tile.vaultFloor);
    expect(WorldRules.isSolid(m, sec.chest!.$1, sec.chest!.$2), isFalse);
    expect(identical(e.mapFor(s), m), isTrue, reason: 'caché');
    // Usada: ya no.
    expect(e.apply(s, 'p0', InteractPoiAction(sec.id)), isNull);
    expect(ExplorationRules.floorSummary(s.mission!, r.f).secretsOpen, 1);
  });

  test('santuario: bendición del grupo, implícito en batalla, uno por misión', () {
    final r = start(1, (f) => f.pois.any((p) => p.kind == PoiKind.shrine),
        players: 2);
    var s = r.s;
    final e = r.e;
    final sh = poiOf(r.f, PoiKind.shrine);
    s = use(e, s, sh, id: 'p1');
    final k = BlessingKind.values[sh.variant];
    expect(s.mission!.blessing, k);
    expect(e.mapFor(s).tileAt(sh.tx, sh.ty), Tile.shrineUsed);
    final w = e.partyMember(s.players['p0']!, blessing: k).build.equippedWeapon;
    expect(w.implicit, containsAll(kBlessings[k]!.mods));
    // ATQ +10% con Fuerza.
    final p = s.players['p0']!;
    final base = e.progression.derivedStats(p.profile).attack;
    final blessed = e.progression.stats
        .calculate(e.partyMember(p, blessing: BlessingKind.fuerza).build)
        .attack;
    expect(blessed, greaterThan(base));
  });

  test('piedras de paso: activar y viajar (solo quien la usa)', () {
    final r = start(6, (f) =>
        f.pois.where((p) => p.kind == PoiKind.waystone).length >= 2,
        players: 2);
    var s = r.s;
    final e = r.e;
    final stones = r.f.pois.where((p) => p.kind == PoiKind.waystone).toList();
    s = use(e, s, stones[0]);
    // Una sola activada: no hay a dónde viajar.
    expect(e.apply(s, 'p0', InteractPoiAction(stones[0].id)), isNull);
    s = use(e, s, stones[1]);
    expect(e.mapFor(s).tileAt(stones[1].tx, stones[1].ty), Tile.waystoneOn);
    final other = (s.players['p1']!.x, s.players['p1']!.y);
    final ep = s.players['p0']!.epoch;
    final step = e.apply(s, 'p0', InteractPoiAction(stones[1].id))!;
    s = step.state;
    final p0 = s.players['p0']!;
    expect(p0.epoch, ep + 1);
    expect(WorldRules.distance(p0.x, p0.y, stones[0].center.x, stones[0].center.y),
        lessThan(20));
    expect((s.players['p1']!.x, s.players['p1']!.y), other);
    expect(step.events.whereType<PoiUsedEvent>().single.toPoi, stones[0].id);
  });

  test('piedras de paso: elegir cualquier destino activado (mapa)', () {
    // Con el área de antes (v0.20.22 achica los pisos): hace falta un
    // piso con 3 piedras.
    kTuning[TuningId.mission] =
        const TuningDef('Misiones', {'maxFloors': 3, 'groupScale': 0.7, 'areaScale': 1});
    addTearDown(() => kTuning[TuningId.mission] = kTuningDefaults[TuningId.mission]!);
    final r = start(
        6, (f) => f.pois.where((p) => p.kind == PoiKind.waystone).length >= 3,
        players: 2);
    var s = r.s;
    final e = r.e;
    final stones = r.f.pois.where((p) => p.kind == PoiKind.waystone).toList();
    s = use(e, s, stones[2]);
    s = use(e, s, stones[1]);
    // stones[0] sin activar: no es destino válido.
    expect(
        e.apply(s, 'p0', InteractPoiAction(stones[1].id, toPoi: stones[0].id)),
        isNull);
    // La misma piedra ni un PdI que no es piedra tampoco.
    expect(
        e.apply(s, 'p0', InteractPoiAction(stones[1].id, toPoi: stones[1].id)),
        isNull);
    expect(e.apply(s, 'p0', InteractPoiAction(stones[1].id, toPoi: 999999)),
        isNull);
    s = use(e, s, stones[0]);
    expect(
        ExplorationRules.waystoneDestinations(r.f, s.mission!, stones[0])
            .map((p) => p.id),
        [stones[1].id, stones[2].id]);
    // Desde la 1 a la 3 (no es "la siguiente"): vale.
    s = moveTo(e, s, 'p0', beside(e.mapFor(s), stones[0].tx, stones[0].ty).x,
        beside(e.mapFor(s), stones[0].tx, stones[0].ty).y);
    final other = (s.players['p1']!.x, s.players['p1']!.y);
    final step =
        e.apply(s, 'p0', InteractPoiAction(stones[0].id, toPoi: stones[2].id))!;
    s = step.state;
    final p0 = s.players['p0']!;
    expect(
        WorldRules.distance(p0.x, p0.y, stones[2].center.x, stones[2].center.y),
        lessThan(20));
    expect((s.players['p1']!.x, s.players['p1']!.y), other);
    expect(step.events.whereType<PoiUsedEvent>().single.toPoi, stones[2].id);
    // Lejos de una piedra el host lo rechaza (abrir el mapa con M desde
    // cualquier lado no permite viajar).
    s = moveTo(e, s, 'p0', r.s.players['p0']!.x, r.s.players['p0']!.y);
    expect(
        e.apply(s, 'p0', InteractPoiAction(stones[0].id, toPoi: stones[1].id)),
        isNull);
  });

  test('InteractPoiAction con destino viaja por la red', () {
    const a = InteractPoiAction(101, toPoi: 103);
    final b = ActionJson.fromJson(ActionJson.toJson(a)) as InteractPoiAction;
    expect((b.poiId, b.toPoi), (101, 103));
    expect(
        (ActionJson.fromJson(ActionJson.toJson(const InteractPoiAction(5)))
                as InteractPoiAction)
            .toPoi,
        isNull);
  });

  test('viento del eco: +40% de velocidad un rato, reusable', () {
    final r = start(1, (f) => f.pois.any((p) => p.kind == PoiKind.wind));
    var s = r.s;
    final e = r.e;
    s = use(e, s, poiOf(r.f, PoiKind.wind));
    expect(ExplorationRules.speedMult(s.mission, s.time), kWindSpeed);
    expect(ExplorationRules.speedMult(s.mission, s.time + kWindSeconds + 1), 1);
    s = use(e, s, poiOf(r.f, PoiKind.wind));
  });

  test('atajo: se abre desde el lado lejano', () {
    final r = start(5, (f) => f.pois.any((p) => p.kind == PoiKind.shortcut));
    var s = r.s;
    final e = r.e;
    final sc = poiOf(r.f, PoiKind.shortcut);
    // Del lado cercano no.
    final near = (sc.tx * 2 - sc.side!.$1, sc.ty * 2 - sc.side!.$2);
    s = moveTo(e, s, 'p0', near.$1 * 16 + 8.0, near.$2 * 16 + 8.0);
    expect(e.apply(s, 'p0', InteractPoiAction(sc.id)), isNull);
    s = use(e, s, sc);
    expect(e.mapFor(s).tileAt(sc.tx, sc.ty), Tile.path);
  });

  test('braseros: progreso compartido, fanfarria y premio para cada uno', () {
    final r = start(1, (f) => f.quests.any((q) => q.kind == QuestKind.braseros),
        players: 2);
    var s = r.s;
    final e = r.e;
    final q = r.f.quests.firstWhere((q) => q.kind == QuestKind.braseros);
    final br = r.f.pois.where((p) => p.quest == q.id).toList();
    s = use(e, s, br[0], id: 'p0');
    s = use(e, s, br[1], id: 'p1');
    expect(ExplorationRules.questLine(q, s.mission!, r.f),
        'Encendé los braseros 2/3');
    final before = {
      for (final id in ['p0', 'p1']) id: s.players[id]!.profile.credits,
    };
    final bp = s.players['p0']!.profile;
    final step = e.apply(
        moveTo(e, s, 'p0', beside(e.mapFor(s), br[2].tx, br[2].ty).x,
            beside(e.mapFor(s), br[2].tx, br[2].ty).y),
        'p0',
        InteractPoiAction(br[2].id))!;
    s = step.state;
    expect(s.mission!.questsDone, contains(q.id));
    expect(step.events.whereType<QuestDoneEvent>().single.questId, q.id);
    for (final id in ['p0', 'p1']) {
      final p = s.players[id]!.profile;
      expect(p.credits, greaterThan(before[id]!), reason: id);
      expect(p.materials[CraftMaterial.esquirla] ?? 0,
          greaterThanOrEqualTo(kQuestEsquirlas));
    }
    final loot = step.events.whereType<LootDropEvent>().toList();
    expect(loot.map((l) => l.playerId).toSet(), {'p0', 'p1'});
    if (q.reward == QuestReward.arma) {
      final w = s.players['p0']!.profile.items.length;
      expect(w, bp.items.length + 1);
      expect(s.players['p0']!.profile.items.last.rarity.index,
          greaterThanOrEqualTo(Rarity.raro.index));
    }
    // No se cumple dos veces.
    expect(e.tick(s, 0.05).events.whereType<QuestDoneEvent>(), isEmpty);
  });

  test('guardián: su cofre dorado no se abre vivo; bajar sin vencerlo falla', () {
    final r = start(1, (f) => f.quests.any((q) => q.kind == QuestKind.guardian));
    var s = r.s;
    final e = r.e;
    final m = s.mission!;
    final g = m.enemiesOn(0).firstWhere((en) => en.elite);
    final chest = m.items.firstWhere((i) => i.guard == g.id);
    expect(chest.tier, ChestTier.oro);
    // Tocarlo con el guardián vivo: nada (sin tick de contacto: lejos).
    s.graceUntil = 1e9;
    s = moveTo(e, s, 'p0', chest.x, chest.y);
    s = e.tick(s, 0.05).state;
    expect(s.mission!.items.firstWhere((i) => i.id == chest.id).done, isFalse);
    // Bajar con el guardián vivo: la misión opcional falla.
    final q = r.f.quests.firstWhere((q) => q.kind == QuestKind.guardian);
    s.mission!.opened.add(0);
    final down = r.f.stairsDown!;
    s = moveTo(e, s, 'p0', down.x, down.y - 8);
    s = act(e, s, 'p0', const UseStairsAction(down: true));
    expect(s.mission!.questsFailed, contains(q.id));
    expect(ExplorationRules.questComplete(q, s.mission!, r.f), isFalse);
  });

  test('cofre dorado: arma Rara o mejor para cada jugador', () {
    final r = start(1, (f) => true, players: 2);
    var s = r.s;
    final e = r.e;
    final chest = s.mission!.items.firstWhere(
        (i) => i.tier == ChestTier.oro && i.guard == null && i.floor == 0,
        orElse: () => s.mission!.items.firstWhere((i) => i.tier == ChestTier.oro));
    // Sin guardián (o ya vencido) para probar solo el contenido.
    for (final en in s.mission!.enemies) {
      if (en.id == chest.guard) en.alive = false;
    }
    s.graceUntil = 1e9;
    final n = {for (final id in ['p0', 'p1']) id: s.players[id]!.profile.items.length};
    s = moveTo(e, s, 'p0', chest.x, chest.y);
    final step = e.tick(s, 0.05);
    s = step.state;
    expect(step.events.whereType<ChestOpenedEvent>().single.tier, ChestTier.oro);
    for (final id in ['p0', 'p1']) {
      final items = s.players[id]!.profile.items;
      expect(items.length, greaterThan(n[id]!), reason: id);
      expect(items.skip(n[id]!).any((i) => i.rarity.index >= Rarity.raro.index),
          isTrue, reason: id);
    }
  });

  test('descubrir: los PdI cercanos pasan a vistos', () {
    final r = start(1, (f) => f.pois.any((p) => p.kind == PoiKind.shrine));
    var s = r.s;
    final e = r.e;
    final sh = poiOf(r.f, PoiKind.shrine);
    expect(s.mission!.poiSeen, isNot(contains(sh.id)));
    s.graceUntil = 1e9;
    final at = beside(e.mapFor(s), sh.tx, sh.ty);
    s = moveTo(e, s, 'p0', at.x, at.y);
    s = e.tick(s, 0.05).state;
    expect(s.mission!.poiSeen, contains(sh.id));
  });

  test('red: estado, acción y eventos de ida y vuelta (protocolo 7)', () {
    const codec = SessionJson();
    final m = MissionRun(
      missionId: 'z2',
      seed: 1,
      goal: 3,
      objectives: [MissionObjective(ObjectiveKind.kills, 3)],
      enemies: const [],
      items: [
        MissionItem(
            id: 4, kind: MissionItemKind.chest, x: 1, y: 2,
            tier: ChestTier.oro, guard: 7, secret: 101),
        MissionItem(id: 5, kind: MissionItemKind.chest, x: 1, y: 2),
      ],
      poiUsed: {101, 3},
      poiSeen: {101},
      questsDone: {50},
      questsFailed: {151},
      blessing: BlessingKind.fortuna,
      windUntil: 12.5,
    );
    final j = jsonDecode(jsonEncode(codec.missionToJson(m))) as Json;
    final back = codec.missionFromJson(j);
    expect(back.poiUsed, {3, 101});
    expect(back.poiSeen, {101});
    expect(back.questsDone, {50});
    expect(back.questsFailed, {151});
    expect(back.blessing, BlessingKind.fortuna);
    expect(back.windUntil, 12.5);
    expect(back.items.first.tier, ChestTier.oro);
    expect(back.items.first.guard, 7);
    expect(back.items.first.secret, 101);
    expect(back.items.last.tier, ChestTier.madera);
    expect(back.items.last.guard, isNull);
    // Snapshot viejo (sin claves): nada usado.
    final old = codec.missionFromJson(
        jsonDecode(jsonEncode(codec.missionToJson(MissionRun(
            missionId: 'z2', seed: 1, goal: 3, objectives: const [],
            enemies: const [], items: const []))))
            as Json);
    expect(old.poiUsed, isEmpty);
    expect(old.blessing, isNull);

    const a = InteractPoiAction(101);
    expect(ActionJson.toJson(a), {'t': 'poi', 'id': 101});
    expect((ActionJson.fromJson(ActionJson.toJson(a)) as InteractPoiAction).poiId,
        101);
    for (final ev in <SessionEvent>[
      const PoiUsedEvent('p1', 101, PoiKind.shrine, blessing: BlessingKind.vigor),
      const PoiUsedEvent('p1', 3, PoiKind.waystone, toPoi: 4),
      const QuestDoneEvent(150, 1, QuestKind.braseros),
      const ChestOpenedEvent('p0', 40, tier: ChestTier.plata),
    ]) {
      const ej = EventJson();
      final again = ej.fromJson(
          jsonDecode(jsonEncode(ej.toJson(ev))) as Json);
      expect(ej.toJson(again), ej.toJson(ev));
    }
  });
}
