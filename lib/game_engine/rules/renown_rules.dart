import 'dart:math' as math;

import '../data/biomes_catalog.dart';
import '../data/renown_catalog.dart';
import '../data/zones_catalog.dart';
import '../models/localized_text.dart';
import '../models/mission_def.dart';
import '../models/world_save.dart';
import '../models/zone_def.dart';

/// Where a value stands on a ladder of tiers (§ 2.1, § 5.1).
typedef TierProgress = ({
  int index,
  RenownTier? tier,
  RenownTier? next,
  double fraction,
});

/// Renown, town tier and friendship town events
/// (docs/specs/renown_town_growth.md). Pure; the host applies.
abstract final class RenownRules {
  // ---------------- renown (§ 1–§ 2) ----------------

  /// Residents living in town.
  static int residents(TownState t) =>
      t.residents.values.where((r) => r.invited).length;

  /// Zones won that are the last zone of their biome.
  static int biomeBosses(RenownState r) => [
        for (final b in kBiomes)
          if (b.zones.isNotEmpty && r.zones.contains(b.zones.last)) b
      ].length;

  /// The world's renown.
  static int score(TownState t, [RenownConfig? cfg]) {
    final c = cfg ?? kRenown;
    final r = t.renown;
    final v = r.zones.length * c.weight(RenownSource.zone) +
        biomeBosses(r) * c.weight(RenownSource.biomeBoss) +
        r.rifts * c.weight(RenownSource.rift) +
        r.lore * c.weight(RenownSource.lore) +
        r.tourneys * c.weight(RenownSource.tourney) +
        residents(t) * c.weight(RenownSource.resident) +
        t.builds.length * c.weight(RenownSource.building);
    return v.floor();
  }

  /// Where [value] stands on [ladder] (sorted by `min`).
  static TierProgress ladder(List<RenownTier> ladder, num value) {
    var i = -1;
    for (var k = 0; k < ladder.length; k++) {
      if (value >= ladder[k].min) i = k;
    }
    final cur = i < 0 ? null : ladder[i];
    final next = i + 1 < ladder.length ? ladder[i + 1] : null;
    final from = cur?.min ?? 0;
    final f = next == null
        ? 1.0
        : ((value - from) / math.max(1, next.min - from)).clamp(0.0, 1.0);
    return (index: i, tier: cur, next: next, fraction: f.toDouble());
  }

  /// The renown tier of [t].
  static TierProgress tier(TownState t, [RenownConfig? cfg]) {
    final c = cfg ?? kRenown;
    return ladder(c.tiers, score(t, c));
  }

  // ---------------- town tier (§ 5) ----------------

  /// Town points: residents, buildings and renown, each by its weight.
  static double townPoints(TownState t, [RenownConfig? cfg]) {
    final c = cfg ?? kRenown;
    return residents(t) * c.townWeight(TownWeight.resident) +
        t.builds.length * c.townWeight(TownWeight.building) +
        score(t, c) * c.townWeight(TownWeight.renown);
  }

  static TierProgress townTier(TownState t, [RenownConfig? cfg]) {
    final c = cfg ?? kRenown;
    return ladder(c.townTiers, townPoints(t, c));
  }

  // ---------------- milestones (§ 1) ----------------

  /// A zone mission won: the zone, and its boss as the last deed.
  static RenownState zoneWon(RenownState r, int zone) {
    final z = kZones.where((k) => k.index == zone).firstOrNull;
    final biome =
        kBiomes.where((b) => b.zones.contains(zone)).firstOrNull?.id ?? '';
    return r.copyWith(
        zones: {...r.zones, zone},
        lastBoss: z?.bossName ?? r.lastBoss,
        lastBiome: biome.isEmpty ? r.lastBiome : biome);
  }

  static RenownState riftWon(RenownState r) => r.copyWith(rifts: r.rifts + 1);

  static RenownState loreDone(RenownState r) => r.copyWith(lore: r.lore + 1);

  // ---------------- tokens (§ 3) ----------------

  /// The deed tokens of [t] in the active language.
  static Map<String, String> tokens(TownState t,
      {String? worldName, RenownConfig? cfg}) {
    final c = cfg ?? kRenown;
    final r = t.renown;
    return {
      'lastBoss': r.lastBoss.isEmpty ? '…' : r.lastBoss,
      'lastBiome': biomeDef(r.lastBiome)?.name ?? '…',
      'townName': (worldName ?? '').trim().isEmpty ? '…' : worldName!.trim(),
      'renownTier': tier(t, c).tier?.name.resolve(_tag) ?? '',
      'townTier': townTier(t, c).tier?.name.resolve(_tag) ?? '',
    };
  }

  static String get _tag => LocalizedText.activeTag;

  // ---------------- recognition (§ 4.2) ----------------

  /// The line [who] says at [renown]: the eligible one with the highest
  /// `minRenown` (first of the file on ties), or `null`.
  static RecognitionLine? recognition(String who, int renown,
      [RenownConfig? cfg]) {
    RecognitionLine? best;
    for (final l in (cfg ?? kRenown).lines) {
      if (l.who != who || l.minRenown > renown) continue;
      if (best == null || l.minRenown > best.minRenown) best = l;
    }
    return best;
  }

  // ---------------- town events (§ 6) ----------------

  /// Why [d] cannot be proposed now (`null` = it can).
  static String? cannotPropose(TownState t, TownEventDef d, int day,
      [RenownConfig? cfg]) {
    final r = t.resident(d.proposer);
    if (!r.invited) return 'No vive en el pueblo';
    if (t.renown.scheduled.containsKey(d.id)) return 'Ya está programado';
    final last = t.renown.held[d.id];
    if (last != null && day - last < d.cooldown) {
      return 'Faltan ${d.cooldown - (day - last)} días';
    }
    if (r.rep < d.minRep) return 'Amistad ${r.rep}/${d.minRep}';
    final s = score(t, cfg);
    if (s < d.minRenown) return 'Renombre $s/${d.minRenown}';
    return null;
  }

  /// Events [npc] can propose now (only implemented kinds).
  static List<TownEventDef> proposals(TownState t, String npc, int day,
          [RenownConfig? cfg]) =>
      [
        for (final d in (cfg ?? kRenown).events)
          if (d.proposer == npc &&
              d.kind == TownEventKind.tournament &&
              cannotPropose(t, d, day, cfg) == null)
            d
      ];

  /// Accepting [id] on [day] (`null` if not possible).
  static TownState? schedule(TownState t, String id, int day,
      [RenownConfig? cfg]) {
    final d = (cfg ?? kRenown).event(id);
    if (d == null || cannotPropose(t, d, day, cfg) != null) return null;
    return t.copyWith(
        renown: t.renown.copyWith(scheduled: {
      ...t.renown.scheduled,
      id: day + math.max(1, d.delay),
    }));
  }

  /// The event [npc] holds today (`day == scheduled day`), or `null`.
  static TownEventDef? live(TownState t, String npc, int day,
      [RenownConfig? cfg]) {
    for (final d in (cfg ?? kRenown).events) {
      if (d.proposer == npc && t.renown.scheduled[d.id] == day) return d;
    }
    return null;
  }

  /// Scheduled events whose day passed are missed: held, not scheduled.
  static RenownState expire(RenownState r, int day) {
    final gone = {
      for (final e in r.scheduled.entries)
        if (e.value < day) e.key: e.value
    };
    if (gone.isEmpty) return r;
    return r.copyWith(
        scheduled: {...r.scheduled}..removeWhere((k, _) => gone.containsKey(k)),
        held: {...r.held, ...gone});
  }

  /// The tournament [id] ended (won or lost) on [day].
  static RenownState held(RenownState r, String id, int day,
      {required bool won}) {
    return r.copyWith(
        scheduled: {...r.scheduled}..remove(id),
        held: {...r.held, id: day},
        tourneys: won ? r.tourneys + 1 : r.tourneys);
  }

  // ---------------- tournament fight (§ 6.2) ----------------

  static const tourneyMissionId = 'tourney';

  /// Arena zone: the highest zone won in the world (zone 1 if none),
  /// one floor, level `maxLevel + levelBonus`.
  static ZoneDef tourneyZone(TownState t, TownEventDef d) {
    final top = t.renown.zones.isEmpty ? 1 : t.renown.zones.reduce(math.max);
    final z = kZones.where((k) => k.index == top).firstOrNull ?? kZones.first;
    final lv = z.maxLevel + d.levelBonus;
    return ZoneDef(
      index: z.index,
      id: tourneyMissionId,
      name: d.title.text,
      gen: z.gen,
      minLevel: lv,
      maxLevel: lv,
      floors: 1,
      bossId: d.rounds.isEmpty ? z.bossId : d.rounds.last.first,
      bossName: d.title.text,
      theme: z.theme,
      missionId: tourneyMissionId,
    );
  }

  static MissionDef tourneyMission(TownState t, TownEventDef d) {
    final z = tourneyZone(t, d);
    return MissionDef(
      id: tourneyMissionId,
      name: d.title.text,
      type: 'Torneo',
      rank: 'B',
      recommendedLevel: z.maxLevel,
      theme: z.theme,
      goal: 0,
      groups: [for (final r in d.rounds) r],
      boss: d.rounds.isEmpty ? [z.bossId] : d.rounds.last,
      sTime: 400,
      elite: z.bossId,
      extra: 0,
      zone: z.index,
      floors: 1,
      floorGoal: 0,
    );
  }
}
