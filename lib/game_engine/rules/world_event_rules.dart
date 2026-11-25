import 'dart:math' as math;

import '../data/biomes_catalog.dart';
import '../data/enemies_catalog.dart';
import '../data/town_layout.dart';
import '../data/world_events_catalog.dart';
import '../data/zones_catalog.dart';
import '../models/battle_state.dart';
import '../models/localized_text.dart';
import '../models/mission_def.dart';
import '../models/world_save.dart';
import '../models/zone_def.dart';
import 'js_math.dart';
import 'mulberry32.dart';

/// What the roll needs to know about the world (world_events.md § 2).
class WorldEventContext {
  const WorldEventContext(
      {this.residents = const {}, this.openBiomes, this.extraCondition});

  /// Residents living in town.
  final Set<String> residents;

  /// Biomes an event may pick (null = every open biome but the town).
  final List<String>? openBiomes;

  /// Hook (§ 1): an extra per-event condition, e.g. a future event that
  /// depends on the current weather or season. `null` = no condition.
  /// Not used yet on purpose.
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

  /// A roll is due on [day] (§ 2).
  static bool due(WorldEventsState s, int day, WorldEventsConfig cfg) =>
      day > 0 && day - s.last >= math.max(1, cfg.interval);

  static bool _eligible(WorldEventDef d, int day, WorldEventsState s,
      WorldEventContext ctx) {
    if (!d.enabled || d.weight <= 0 || d.minDay > day) return false;
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
    if (!due(s, day, cfg)) return (s, const []);
    final started = roll(s.seed, day, cfg, state: s, ctx: ctx);
    s = s.copyWith(
      last: day,
      active: [...s.active, ...started],
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
      if (!en.boss) continue;
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
    if (a == null || d == null || d.category != WorldEventCategory.echoPortal) {
      return null;
    }
    final r = rift(d, a.biome);
    return r == null ? null : (a, r);
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
