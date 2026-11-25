import 'dart:math' as math;

import '../data/bait_catalog.dart';
import '../data/biomes_catalog.dart';
import '../data/farming_catalog.dart';
import '../data/smithing_catalog.dart';
import '../data/enemies_catalog.dart';
import '../data/town_layout.dart';
import '../data/world_events_catalog.dart';
import '../data/tuning_catalog.dart';
import '../data/zones_catalog.dart';
import '../models/battle_state.dart';
import '../models/localized_text.dart';
import '../models/mission_def.dart';
import '../models/player_profile.dart';
import '../models/world_save.dart';
import '../models/zone_def.dart';
import 'js_math.dart';
import 'mulberry32.dart';
import 'quest_track_rules.dart' show NpcMark;
import 'weather_rules.dart';

/// What the roll needs to know about the world (world_events.md § 2).
class WorldEventContext {
  const WorldEventContext(
      {this.residents = const {},
      this.openBiomes,
      this.extraCondition,
      this.renown = 0});

  /// World renown (renown_town_growth.md § 4.3): events with a higher
  /// `minRenown` stay out of the roll.
  final int renown;

  /// Residents living in town.
  final Set<String> residents;

  /// Biomes an event may pick (null = every open biome but the town).
  final List<String>? openBiomes;

  /// Hook (§ 1): an extra per-event condition. The host passes
  /// [WorldEventRules.climateCondition] (the event's `season` /
  /// `weather`). `null` = no condition.
  final bool Function(WorldEventDef def)? extraCondition;

  List<String> get biomes =>
      openBiomes ??
      [for (final b in kBiomes) if (b.open && b.id != kPueblo) b.id];
}

/// The stronger boss behind an echo rift (§ 3.3).
class EchoRiftBoss {
  const EchoRiftBoss(
      {required this.bossId,
      required this.zone,
      required this.missionId,
      required this.hpMult,
      required this.atkMult,
      required this.levelBonus,
      required this.rewardMult});
  final String bossId;
  final int zone;
  final String missionId;
  final double hpMult, atkMult, rewardMult;
  final int levelBonus;

  /// (hp, attack) of a boss with [hp] and [attack] once scaled.
  (int, int) scale(int hp, int attack) => (
        math.max(1, jsRound(hp * hpMult)),
        math.max(1, jsRound(attack * atkMult)),
      );
}

/// The story quest a lore event unlocks (§ 3.4). Never a fetch quest.
class LoreQuest {
  const LoreQuest(
      {required this.npc,
      required this.objective,
      required this.target,
      required this.n,
      required this.text,
      required this.gold,
      required this.rep});
  final String npc;
  final LoreObjective objective;
  final String target;
  final int n;
  final LocalizedText text;
  final int gold, rep;

  /// Always false: [LoreObjective] has no fetch/gather kind.
  bool get isFetch => false;
}

/// World events (docs/specs/world_events.md). Pure.
abstract final class WorldEventRules {
  static int _mix(int seed, int day) =>
      (seed * 0x9E3779B1 + day * 0x85EBCA77 + 0x165667B1) & 0xFFFFFFFF;

  /// The climate condition of events (§ 1, weather_seasons.md): an
  /// event with `season` only rolls in that season of [day], one with
  /// `weather` only when the town weather of [day] (sky [skySeed]) is
  /// that one.
  static bool Function(WorldEventDef) climateCondition(int skySeed, int day) {
    final season = WeatherRules.season(day).name;
    final weather = WeatherRules.dayWeather(skySeed, day, null).name;
    return (d) =>
        (d.season == null || d.season == season) &&
        (d.weather == null || d.weather == weather);
  }

  /// A roll is due on [day] (§ 2).
  static bool due(WorldEventsState s, int day, WorldEventsConfig cfg) =>
      day > 0 && day - s.last >= math.max(1, cfg.interval);

  static bool _eligible(WorldEventDef d, int day, WorldEventsState s,
      WorldEventContext ctx) {
    if (!d.enabled || d.weight <= 0 || d.minDay > day) return false;
    // Deep exploration actors have their own daily roll (exploreRoll).
    if (isDeep(d)) return false;
    if (d.minRenown > ctx.renown) return false;
    if (d.resident != null && !ctx.residents.contains(d.resident)) return false;
    if (s.active.any((a) => a.def == d.id)) return false;
    if (d.category == WorldEventCategory.lore && s.seen.contains(d.id)) {
      return false;
    }
    if (ctx.extraCondition case final f? when !f(d)) return false;
    return true;
  }

  /// The events that start on [day]: deterministic from [seed] and
  /// [day] (§ 2). Does not touch the state.
  static List<ActiveWorldEvent> roll(int seed, int day, WorldEventsConfig cfg,
      {WorldEventsState state = const WorldEventsState(),
      WorldEventContext ctx = const WorldEventContext()}) {
    final rng = mulberry32(_mix(seed, day));
    if (rng() >= cfg.chance) return const [];
    final lo = math.max(0, cfg.minPerRoll);
    final hi = math.max(lo, cfg.maxPerRoll);
    final count = lo + (rng() * (hi - lo + 1)).floor().clamp(0, hi - lo);
    final pool = [
      for (final d in cfg.events)
        if (_eligible(d, day, state, ctx)) d
    ];
    final out = <ActiveWorldEvent>[];
    final rifts = {
      for (final a in state.active)
        if (cfg.def(a.def)?.category == WorldEventCategory.echoPortal) a.biome
    };
    while (out.length < count && pool.isNotEmpty) {
      final total = pool.fold<int>(0, (a, d) => a + d.weight);
      var r = rng() * total;
      var pick = pool.last;
      for (final d in pool) {
        r -= d.weight;
        if (r < 0) {
          pick = d;
          break;
        }
      }
      pool.remove(pick);
      final biome = _biome(pick, rng, ctx, rifts);
      if (biome == null) continue;
      if (pick.category == WorldEventCategory.echoPortal) rifts.add(biome);
      out.add(ActiveWorldEvent(pick.id,
          biome: biome, start: day, end: day + math.max(1, pick.duration)));
    }
    return out;
  }

  static String? _biome(WorldEventDef d, double Function() rng,
      WorldEventContext ctx, Set<String> rifts) {
    if (d.category.inTown) return kPueblo;
    if (d.category == WorldEventCategory.lore) {
      return biomeNpc(d.resident ?? '')?.biome ?? kPueblo;
    }
    var opts = d.biomes.isNotEmpty ? d.biomes : ctx.biomes;
    if (d.category == WorldEventCategory.echoPortal) {
      opts = [for (final b in opts) if (!rifts.contains(b)) b];
    }
    if (opts.isEmpty) return null;
    return opts[(rng() * opts.length).floor().clamp(0, opts.length - 1)];
  }

  // ---------------- exploration content (biome_exploration.md § 6) ----

  /// Stands deep in the wilds and rolls daily per biome ([exploreRoll]).
  static bool isDeep(WorldEventDef d) =>
      d.param('deep') > 0 && d.category == WorldEventCategory.overworldNpc;

  static int _hash(String s) {
    var x = 0x811c9dc5;
    for (final c in s.codeUnits) {
      x = ((x ^ c) * 0x01000193) & 0x7fffffff;
    }
    return x;
  }

  /// The deep actors that start on [day]: per open biome, from
  /// `(seed, biome, day)`, at most `exploreMax` each; a def stands in one
  /// biome per day (its uid is `def@day`). Does not touch the state.
  static List<ActiveWorldEvent> exploreRoll(
      int seed, int day, WorldEventsConfig cfg,
      {WorldEventsState state = const WorldEventsState(),
      WorldEventContext ctx = const WorldEventContext()}) {
    final t = tuning(TuningId.regions);
    final used = {
      for (final a in state.active)
        if (a.start == day) a.def
    };
    final out = <ActiveWorldEvent>[];
    final biomes = [...ctx.biomes]..sort();
    for (final biome in biomes) {
      final rng = mulberry32(_mix(seed ^ _hash(biome), day));
      if (rng() >= t.d('exploreChance')) continue;
      final pool = [
        for (final d in cfg.events)
          if (isDeep(d) &&
              d.enabled &&
              d.weight > 0 &&
              d.minDay <= day &&
              d.minRenown <= ctx.renown &&
              (d.biomes.isEmpty || d.biomes.contains(biome)) &&
              !used.contains(d.id) &&
              (ctx.extraCondition?.call(d) ?? true))
            d
      ];
      final n = 1 + (rng() * math.max(1, t.i('exploreMax'))).floor();
      for (var k = 0; k < n && pool.isNotEmpty; k++) {
        final total = pool.fold<int>(0, (a, d) => a + d.weight);
        var r = rng() * total;
        var pick = pool.last;
        for (final d in pool) {
          r -= d.weight;
          if (r < 0) {
            pick = d;
            break;
          }
        }
        pool.remove(pick);
        used.add(pick.id);
        out.add(ActiveWorldEvent(pick.id,
            biome: biome, start: day, end: day + math.max(1, pick.duration)));
      }
    }
    return out;
  }

  /// The biome elite a `@elite` duel fights at [biome]: the elite of the
  /// mission of one of its zones, picked by [salt].
  static String? biomeElite(String biome, int salt) {
    final zones = biomeDef(biome)?.zones ?? const <int>[];
    if (zones.isEmpty) return null;
    final z = zones[salt.abs() % zones.length];
    for (final m in kZoneMissions) {
      if (m.zone == z && m.elite.isNotEmpty) return m.elite;
    }
    return null;
  }

  /// Drops the events that ended by [day].
  static WorldEventsState expire(WorldEventsState s, int day) {
    final keep = [for (final a in s.active) if (day < a.end) a];
    return keep.length == s.active.length ? s : s.copyWith(active: keep);
  }

  /// A new world day (§ 2): expiry, then the roll if due. Returns the new
  /// state and the events that started.
  static (WorldEventsState, List<ActiveWorldEvent>) onDay(
      WorldEventsState s0, int day, WorldEventsConfig cfg,
      {WorldEventContext ctx = const WorldEventContext()}) {
    var s = expire(s0, day);
    // The wilds get their deep actors every day (biome_exploration.md § 6).
    final deep = s.active.any((a) => a.start == day)
        ? const <ActiveWorldEvent>[]
        : exploreRoll(s.seed, day, cfg, state: s, ctx: ctx);
    if (deep.isNotEmpty) s = s.copyWith(active: [...s.active, ...deep]);
    if (!due(s, day, cfg)) return (s, deep);
    final started = [...deep, ...roll(s.seed, day, cfg, state: s, ctx: ctx)];
    s = s.copyWith(
      last: day,
      active: [...s.active, ...started.skip(deep.length)],
      seen: {
        ...s.seen,
        for (final a in started)
          if (cfg.def(a.def)?.category == WorldEventCategory.lore) a.def
      },
    );
    return (s, started);
  }

  /// The boss behind a rift at [biome] (§ 3.3): the boss of the last
  /// zone of that biome, scaled by [d].
  static EchoRiftBoss? rift(WorldEventDef d, String biome) {
    final zones = biomeDef(biome)?.zones ?? const <int>[];
    if (zones.isEmpty) return null;
    final z = kZones.where((k) => k.index == zones.last).firstOrNull;
    if (z == null) return null;
    return EchoRiftBoss(
        bossId: z.bossId,
        zone: z.index,
        missionId: z.missionId ?? z.id,
        hpMult: d.param('hpMult'),
        atkMult: d.param('atkMult'),
        levelBonus: d.param('levelBonus').round(),
        rewardMult: d.param('rewardMult'));
  }

  /// Scales the bosses of a freshly created battle (like
  /// `EcoRules.applyBattle`). Mutates [state].
  static void applyRiftBattle(BattleState state, EchoRiftBoss r) {
    for (final en in state.enemies) {
      // A duel foe (§ 3.6) may not be a boss type: match it by id too.
      if (!en.boss && en.enemyType != r.bossId) continue;
      final (hp, atk) = r.scale(en.maxHp, en.attack);
      en
        ..maxHp = hp
        ..hp = hp
        ..attack = atk;
    }
  }

  /// The story quest of a lore event (§ 3.4), or `null`.
  static LoreQuest? loreQuest(WorldEventDef d) {
    if (d.category != WorldEventCategory.lore ||
        d.objective == null ||
        d.resident == null) {
      return null;
    }
    return LoreQuest(
        npc: d.resident!,
        objective: d.objective!,
        target: d.target,
        n: math.max(1, d.n),
        text: d.body,
        gold: d.param('gold').round(),
        rep: d.param('rep').round());
  }

  // ---------------- actors on the map (§ 3) ----------------

  /// Mission id of a rift fight (§ 3.3).
  static const riftMissionId = 'rift';

  /// Talk / use range (px), like the residents.
  static const range = 26.0;

  /// Event NPCs and rift portals have a place to stand.
  static bool hasActor(WorldEventCategory c) => c != WorldEventCategory.lore;

  static const _townSlots = [(-2, 3), (3, 3), (-2, -1), (3, -1)];

  /// Where the actor of [a] stands (px), or `null` (§ 3): town events
  /// around the fountain, biome events on free grass by the path. The
  /// slot is the event's order among the actors of its place.
  static (double, double)? spot(TownState town, ActiveWorldEvent a,
      [WorldEventsConfig? cfg]) {
    final c = cfg ?? kWorldEvents;
    final here = [
      for (final o in town.events.at(a.biome))
        if (hasActor(c.def(o.def)?.category ?? WorldEventCategory.lore)) o
    ];
    final i = here.indexWhere((o) => o.uid == a.uid);
    if (i < 0) return null;
    if (a.biome == kPueblo) {
      final f = TownLayout.landmark(TownSpot.fountain);
      final (fx, fy) = town.marks[f.id] ?? (f.x, f.y);
      final (ox, oy) = town.origin;
      final (dx, dy) = _townSlots[i % _townSlots.length];
      return ((fx + ox + dx + 0.5) * 16, (fy + oy + dy + 0.5) * 16);
    }
    final lay = biomeLayout(a.biome);
    if (lay == null) return null;
    // Deep actors stand in the wilds (biome_exploration.md § 6).
    final d = c.def(a.def);
    if (d != null && isDeep(d) && lay.exploreSpots.isNotEmpty) {
      final (x, y) =
          lay.exploreSpots[_hash('${a.uid}|${a.biome}') % lay.exploreSpots.length];
      return ((x + 0.5) * 16, (y + 0.5) * 16);
    }
    // Free ground by the main path (biome_regions.md § 2.4).
    final free = lay.eventSpots;
    if (free.isEmpty) return null;
    final (x, y) = free[i % free.length];
    return ((x + 0.5) * 16, (y + 0.5) * 16);
  }

  /// The event actor in reach of ([x], [y]) at [place] (`pueblo` for the
  /// town), or `null`. Rift portals a player already beat are closed for
  /// them ([player]).
  static ActiveWorldEvent? near(TownState town, String place, double x,
      double y,
      {String? player, WorldEventsConfig? cfg}) {
    final c = cfg ?? kWorldEvents;
    for (final a in town.events.at(place)) {
      final d = c.def(a.def);
      if (d == null || !hasActor(d.category)) continue;
      if (d.category == WorldEventCategory.echoPortal &&
          player != null &&
          town.events.clearedBy(a.uid, player)) {
        continue;
      }
      final p = spot(town, a, c);
      if (p == null) continue;
      final dx = p.$1 - x, dy = p.$2 - y;
      if (math.sqrt(dx * dx + dy * dy) <= range) return a;
    }
    return null;
  }

  // ---------------- rift fight (§ 3.3) ----------------

  /// The zone of a rift fight: the biome boss's zone, one floor, the
  /// level raised by `levelBonus`.
  static ZoneDef riftZone(EchoRiftBoss r) {
    final z = kZones.firstWhere((k) => k.index == r.zone);
    final lv = z.maxLevel + r.levelBonus;
    return ZoneDef(
      index: z.index,
      id: riftMissionId,
      name: z.bossName,
      gen: z.gen,
      minLevel: lv,
      maxLevel: lv,
      floors: 1,
      bossId: r.bossId,
      bossName: z.bossName,
      theme: z.theme,
      missionId: riftMissionId,
    );
  }

  /// The mission of a rift: only the boss.
  static MissionDef riftMission(EchoRiftBoss r) {
    final z = riftZone(r);
    return MissionDef(
      id: riftMissionId,
      name: z.bossName,
      type: 'Grieta',
      rank: 'A',
      recommendedLevel: z.maxLevel,
      theme: z.theme,
      goal: 0,
      groups: [
        [r.bossId]
      ],
      boss: [r.bossId],
      sTime: 300,
      elite: r.bossId,
      extra: 0,
      zone: z.index,
      floors: 1,
      floorGoal: 0,
    );
  }

  /// The active rift [uid] and its boss, or `null`.
  static (ActiveWorldEvent, EchoRiftBoss)? riftOf(
      WorldEventsState s, String? uid,
      [WorldEventsConfig? cfg]) {
    if (uid == null) return null;
    final a = s.active.where((x) => x.uid == uid).firstOrNull;
    final d = a == null ? null : (cfg ?? kWorldEvents).def(a.def);
    if (a == null || d == null) return null;
    final r = switch (d.category) {
      WorldEventCategory.echoPortal => rift(d, a.biome),
      WorldEventCategory.overworldNpc => duel(d, a.biome),
      _ => null,
    };
    return r == null ? null : (a, r);
  }

  // ---------------- event NPCs (§ 3.6) ----------------

  /// The duel of a wanderer at [biome] (§ 3.6): its enemy in the arena
  /// of the biome's last zone, scaled like a rift. `null` = no duel.
  static EchoRiftBoss? duel(WorldEventDef d, String biome) {
    final a = d.actions
        .where((x) => x.kind == EventActionKind.duel && x.target.isNotEmpty)
        .firstOrNull;
    final zones = biomeDef(biome)?.zones ?? const <int>[];
    final target = a?.target == EventNpcAction.elite
        ? biomeElite(biome, _hash(d.id))
        : a?.target;
    if (a == null || zones.isEmpty || !kEnemies.containsKey(target)) {
      return null;
    }
    final z = kZones.where((k) => k.index == zones.last).firstOrNull;
    if (z == null) return null;
    return EchoRiftBoss(
        bossId: target!,
        zone: z.index,
        missionId: z.missionId ?? z.id,
        hpMult: a.param('hpMult'),
        atkMult: a.param('atkMult'),
        levelBonus: a.param('levelBonus').round(),
        rewardMult: a.param('rewardMult'));
  }

  /// Every item id a gift can carry: smithing materials, baits, seeds.
  static Set<String> get giftItems =>
      {...kSmithMaterials.keys, ...kBaits.keys, ...kCrops.keys};

  /// [action] (a gift) given to [p]; `null` if the item is unknown.
  static PlayerProfile? gift(PlayerProfile p, EventNpcAction action) {
    var out = p;
    final id = action.item;
    if (id.isNotEmpty) {
      final n = math.max(1, action.param('qty').round());
      final life = p.life;
      if (kSmithMaterials.containsKey(id)) {
        out = out.copyWith(life: life.addOres({id: n}));
      } else if (kBaits.containsKey(id)) {
        out = out.copyWith(life: life.addBait(id, n));
      } else if (kCrops.containsKey(id)) {
        out = out.copyWith(life: life.copyWith(farm: life.farm.addSeed(id, n)));
      } else {
        return null;
      }
    }
    final gold = action.param('gold').round();
    if (gold > 0) out = out.copyWith(credits: out.credits + gold);
    return out;
  }

  /// Whether [player] already did action [i] of the event [a] (§ 3.6):
  /// gift taken / rumor heard (`done`), duel won (`cleared`). Trade is
  /// never "done".
  static bool actionDone(
      WorldEventsState s, ActiveWorldEvent a, WorldEventDef d, int i,
      String player) {
    if (i < 0 || i >= d.actions.length) return false;
    return switch (d.actions[i].kind) {
      EventActionKind.gift || EventActionKind.rumor =>
        s.doneBy(a.uid, i, player),
      EventActionKind.duel => s.clearedBy(a.uid, player),
      EventActionKind.trade => false,
    };
  }

  /// The event NPC [a] still has something for [player] (§ 3.6).
  static bool pending(WorldEventsState s, ActiveWorldEvent a,
      WorldEventDef d, String player) {
    if (!d.isNpc) return false;
    for (var i = 0; i < d.actions.length; i++) {
      final k = d.actions[i].kind;
      if (!k.once) continue;
      if (k == EventActionKind.duel && duel(d, a.biome) == null) continue;
      if (!actionDone(s, a, d, i, player)) return true;
    }
    return false;
  }

  /// The mark over the event NPC [a] for [player] (same as residents).
  static NpcMark mark(WorldEventsState s, ActiveWorldEvent a,
          WorldEventDef d, String player) =>
      pending(s, a, d, player) ? NpcMark.news : NpcMark.none;

  /// Where a rumor points now (§ 3.6): a biome id, or `null` (no rift
  /// open for `rift`).
  static String? rumorPlace(WorldEventsState s, EventNpcAction action,
      [WorldEventsConfig? cfg]) {
    if (action.kind != EventActionKind.rumor) return null;
    if (action.target != EventNpcAction.rift) {
      return action.target.isEmpty ? null : action.target;
    }
    final c = cfg ?? kWorldEvents;
    return s.active
        .where((x) => c.def(x.def)?.category == WorldEventCategory.echoPortal)
        .firstOrNull
        ?.biome;
  }

  /// Places marked on the travel map for [player]: the rumors they heard
  /// from events still running (§ 3.6).
  static Set<String> rumorMarks(WorldEventsState s, String player,
      [WorldEventsConfig? cfg]) {
    final c = cfg ?? kWorldEvents;
    return {
      for (final a in s.active)
        if (c.def(a.def) case final d?)
          for (var i = 0; i < d.actions.length; i++)
            if (d.actions[i].kind == EventActionKind.rumor &&
                s.doneBy(a.uid, i, player))
              if (rumorPlace(s, d.actions[i], c) case final p?) p
    };
  }


  /// Gold per player for a rift win: the boss's gold times
  /// `rewardMult`.
  static int riftGold(EchoRiftBoss r) =>
      jsRound((kEnemies[r.bossId]?.credits ?? 0) * r.rewardMult);

  /// Rift [uid] beaten by [players]: its portal closes for them.
  static WorldEventsState riftCleared(
          WorldEventsState s, String uid, Iterable<String> players) =>
      s.copyWith(cleared: {
        ...s.cleared,
        uid: {...?s.cleared[uid], ...players},
      });

  // ---------------- lore quests (§ 3.4) ----------------

  /// Lore events whose quest uses [o], with their def.
  static List<(ActiveWorldEvent, WorldEventDef)> loreOf(
      WorldEventsState s, LoreObjective o,
      [WorldEventsConfig? cfg]) {
    final c = cfg ?? kWorldEvents;
    return [
      for (final a in s.active)
        if (c.def(a.def) case final d?
            when d.category == WorldEventCategory.lore && d.objective == o)
          (a, d)
    ];
  }

  /// Progress of the lore quest [a] (0..n).
  static int progressOf(WorldEventsState s, ActiveWorldEvent a) =>
      s.progress[a.uid] ?? 0;

  /// Adds [k] to the quest [a]; returns the new state and whether it is
  /// done now (then the event leaves the active list).
  static (WorldEventsState, bool) advance(
      WorldEventsState s, ActiveWorldEvent a, WorldEventDef d, int k) {
    if (k <= 0) return (s, false);
    final n = math.max(1, d.n);
    final v = math.min(n, progressOf(s, a) + k);
    if (v >= n) return (s.without(a.uid), true);
    return (s.copyWith(progress: {...s.progress, a.uid: v}), false);
  }

  /// Best price discount of the town events running (0–0.9).
  static double townDiscount(WorldEventsState s, WorldEventsConfig cfg) {
    var best = 0.0;
    for (final a in s.at(kPueblo)) {
      best = math.max(best, cfg.def(a.def)?.param('discount') ?? 0);
    }
    return best.clamp(0.0, 0.9);
  }
}
