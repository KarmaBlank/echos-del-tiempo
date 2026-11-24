part of 'session_engine.dart';

// Mines, veins, smelting and forging weapons
// (docs/specs/mining_smithing.md). Everything is decided by the host.

extension _MiningOp on _Op {
  bool miningAction(SessionPlayer p, SessionAction a) {
    switch (a) {
      case MineAction(:final vein):
        return _mineVein(p, vein);
      case SmithAction():
        return _smith(p, a);
      default:
        return false;
    }
  }

  bool _mineVein(SessionPlayer p, int vein) {
    if (s.mode != SessionMode.lobby || s.run != null || p.isCompanion) {
      return false;
    }
    final place = s.place;
    final lay = MiningRules.layout(place,
        worldId: s.worldId, day: s.town.sky.day);
    if (place == null || lay == null || vein < 0 || vein >= lay.nodes.length) {
      return false;
    }
    final (tx, ty) = lay.nodes[vein];
    if (WorldRules.distance(p.x, p.y, (tx + 0.5) * 16, (ty + 0.5) * 16) >
        MiningRules.t.d('mineReach')) {
      return false;
    }
    if (MiningRules.regrowIn(s.town, place, vein, s.time) > 0) return false;
    s.town = MiningRules.spend(s.town, place, vein, s.time);
    final got = MiningRules.veinYield(_rand, lay.biome);
    _profileChange(
        p,
        MiningRules.give(p.profile, got,
            source: MiningRules.mineSource(lay.biome), day: s.town.sky.day),
        gain: true);
    say('${p.name} picó una veta (${_oreText(got)}).');
    smithXp(p, MiningRules.veinXp(lay.biome));
    return true;
  }

  String _oreText(Map<String, int> got) => [
        for (final e in got.entries)
          '${e.value} ${kSmithMaterials[e.key]?.name ?? e.key}'
      ].join(', ');

  bool _smith(SessionPlayer p, SmithAction a) {
    // At the town FORGE only (not the Travesía, not a biome or a mine).
    if (!_inTown(p) || s.place != null) return false;
    switch (a.op) {
      case SmithOp.smelt:
        final next = SmithCraftRules.smelt(p.profile, a.material, a.n,
            day: s.town.sky.day);
        if (next == null) return false;
        _profileChange(p, next);
        say('${p.name} fundió ${a.n} '
            '${kSmithMaterials[ingotOf(a.material)]?.name ?? a.material}.');
        smithXp(p, SmithCraftRules.smeltXp(a.material, a.n));
        return true;
      case SmithOp.forge || SmithOp.brann:
        if (a.rarity < 0 || a.rarity >= Rarity.values.length) return false;
        final r = Rarity.values[a.rarity];
        final brann = a.op == SmithOp.brann;
        final b = s.town.resident('brann');
        final cap = brann
            ? Rarity.values[ResidentRules.commissionRarity(b,
                fishLv: FishingRules.level(p.profile),
                farmLv: FarmingRules.level(p.profile),
                smithLv: SmithRules.level(p.profile))]
            : SmithCraftRules.maxRarity(SmithRules.level(p.profile));
        final base = a.base == null ? null : catalog.weapons[a.base];
        if (SmithCraftRules.cannotForge(p.profile, base, a.material, r,
                maxRarity: cap,
                brann: brann,
                brannHome: b.invited && b.house > 0) !=
            null) {
          return false;
        }
        final c = SmithCraftRules.cost(p.profile.level, a.material, r,
            brann: brann)!;
        final paid =
            SmithCraftRules.pay(p.profile, a.material, r, brann: brann);
        if (paid == null) return false;
        _profileChange(p, paid);
        final item =
            SmithCraftRules.make(rules.loot, _rand, base!, r, c.itemLevel);
        say('${brann ? 'Brann' : p.name} forjó para ${p.name}: '
            '${item.rarity.label.toLowerCase()} de nivel ${item.itemLevel}.');
        smithXp(
            p,
            brann
                ? SmithRules.t.i('smithXpCommission') ~/ 2
                : SmithCraftRules.forgeXp(r));
        _deliver(p, [LootDrop.item(item)], LootSource.mission, p.x, p.y,
            stashOverflow: true);
        return true;
    }
  }

  /// A rare dungeon vein (mining_smithing.md § 1.4).
  void _mineDungeonVein(SessionPlayer p, int zone) {
    if (p.isCompanion) return;
    final got = MiningRules.dungeonYield(_rand, zone);
    _profileChange(
        p,
        MiningRules.give(p.profile, got,
            source: MiningRules.dungeonSource(zone), day: s.town.sky.day),
        gain: true);
    say('${p.name} picó una veta rara (${_oreText(got)}).');
    smithXp(p, MiningRules.t.i('mineXp') * 2);
  }

  /// Guardian cores for everyone who beat a zone boss (§ 1.5).
  void _bossCores() {
    final n = MiningRules.t.i('bossCore');
    if (n <= 0 || s.run != null || s.tutorial != null) return;
    for (final q in players) {
      if (q.isCompanion) continue;
      _profileChange(q, MiningRules.give(q.profile, {kGuardianCore: n},
              source: 'boss', day: s.town.sky.day),
          gain: true);
    }
    say('El guardián dejó $n ${kSmithMaterials[kGuardianCore]!.name}.');
  }
}
