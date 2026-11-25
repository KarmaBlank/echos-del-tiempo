import 'dart:math' as math;

import '../data/biomes_catalog.dart';
import '../data/cooking_catalog.dart' show kMeals, mealKey;
import '../data/farming_catalog.dart';
import '../data/tuning_catalog.dart';
import '../models/item.dart' show CraftMaterial;
import '../models/player_profile.dart';
import '../models/world_save.dart';
import 'resident_rules.dart';

/// What a relationship milestone of a resident pays (roles.md § 9).
enum MilestoneReward {
  /// Wooden / silver / golden chest: gold plus loot rolls.
  chestWood,
  chestSilver,

  /// Golden chest before the endgame; an Eco once Ecos are unlocked.
  ecoOrGold,

  /// Wild product of the resident's biome.
  material,

  /// A cooked meal (rare quality).
  meal,

  /// An epic weapon of the player's class family.
  weapon,

  /// A unique (legendary) weapon of the player's class family.
  unique,

  /// Stage perk (Settled / Rooted): the % benefit goes up. Not claimed.
  perk;

  /// Paid by the claim op (perks apply by themselves).
  bool get claimable => this != perk;
}

/// One step of the milestone track: relationship needed and reward.
class MilestoneDef {
  const MilestoneDef(this.index, this.reward, this.repKey, [this.amountKey]);
  final int index;
  final MilestoneReward reward;

  /// Tuning key (`kTuning[town]`) with the relationship needed.
  final String repKey;

  /// Tuning key with how many (materials, meals); `null` = one.
  final String? amountKey;

  int get rep => ResidentRules.t.i(repKey);
  int get amount => amountKey == null ? 1 : ResidentRules.t.i(amountKey!);
}

/// The track, the same for every resident with a house and a job. The
/// numbers live in `kTuning[TuningId.town]` (`ms*`), editable in Balance.
const kResidentMilestones = <MilestoneDef>[
  MilestoneDef(0, MilestoneReward.chestWood, 'msRepChest'),
  MilestoneDef(1, MilestoneReward.material, 'msRepMaterial', 'msMaterialN'),
  MilestoneDef(2, MilestoneReward.perk, 'resSettledRep'),
  MilestoneDef(3, MilestoneReward.meal, 'msRepMeal', 'msMealN'),
  MilestoneDef(4, MilestoneReward.perk, 'resRootedRep'),
  MilestoneDef(5, MilestoneReward.chestSilver, 'msRepSilver'),
  MilestoneDef(6, MilestoneReward.weapon, 'msRepWeapon'),
  MilestoneDef(7, MilestoneReward.ecoOrGold, 'msRepEco'),
  MilestoneDef(8, MilestoneReward.unique, 'msRepUnique'),
];

/// State of a milestone cell for one player.
enum MilestoneState { claimed, claimable, reached, next, locked }

/// Endgame extra paid with a milestone (Ecos unlocked).
typedef EndgameExtra = ({CraftMaterial? material, int n});

/// Resident milestone track (roles.md § 9). Pure: what is claimable, the
/// static part of the payment and the save migration.
abstract final class ResidentMilestoneRules {
  static TuningDef get t => ResidentRules.t;

  /// Milestones sorted by relationship (the tuning may reorder them).
  static List<MilestoneDef> get track =>
      [...kResidentMilestones]..sort((a, b) => a.rep.compareTo(b.rep));

  /// Claimed bit mask of [npc] for [p].
  static int claimedMask(PlayerProfile p, String npc) => p.resClaims[npc] ?? 0;

  static bool isClaimed(PlayerProfile p, String npc, int i) =>
      claimedMask(p, npc) & (1 << i) != 0;

  /// Only residents living in a house in town pay milestones.
  static bool eligible(ResidentState r) => r.invited && r.house > 0;

  static MilestoneState state(
      PlayerProfile? p, ResidentState r, MilestoneDef m) {
    final reached = r.rep >= m.rep;
    if (!m.reward.claimable) {
      return reached ? MilestoneState.reached : _nextOr(r, m);
    }
    if (p != null && isClaimed(p, r.npc, m.index)) return MilestoneState.claimed;
    if (reached) {
      return eligible(r) ? MilestoneState.claimable : MilestoneState.reached;
    }
    return _nextOr(r, m);
  }

  static MilestoneState _nextOr(ResidentState r, MilestoneDef m) {
    final next = track.where((x) => r.rep < x.rep).firstOrNull;
    return next?.index == m.index ? MilestoneState.next : MilestoneState.locked;
  }

  /// How many milestones [p] can claim from [r] now (the badge).
  static int claimableCount(PlayerProfile? p, ResidentState r) => p == null
      ? 0
      : kResidentMilestones
          .where((m) => state(p, r, m) == MilestoneState.claimable)
          .length;

  /// Why [p] cannot claim milestone [i] of [npc] (or `null`).
  static String? cannotClaim(PlayerProfile p, TownState s, String npc, int i) {
    if (i < 0 || i >= kResidentMilestones.length) return 'No existe';
    final m = kResidentMilestones[i];
    final r = s.resident(npc);
    if (biomeNpc(npc) == null) return 'No existe';
    if (!m.reward.claimable) return 'Mejora automática';
    if (isClaimed(p, npc, i)) return 'Ya reclamado';
    if (!eligible(r)) return 'Necesita casa en el pueblo';
    if (r.rep < m.rep) return 'Relación ${r.rep}/${m.rep}';
    return null;
  }

  /// Marks [i] as claimed and pays the static part (materials, meals and
  /// the endgame extra). Chests, weapons and Ecos need the host's dice:
  /// the engine rolls them from [MilestoneDef.reward].
  static PlayerProfile? claim(
      PlayerProfile p, TownState s, String npc, int i) {
    if (cannotClaim(p, s, npc, i) != null) return null;
    final m = kResidentMilestones[i];
    final n = biomeNpc(npc)!;
    var prof = p.copyWith(resClaims: {
      ...p.resClaims,
      npc: claimedMask(p, npc) | (1 << i),
    });
    switch (m.reward) {
      case MilestoneReward.material:
        final k = cropKey(ResidentRules.lootOf(n), CropQuality.normal);
        final crops = {...prof.life.farm.crops};
        crops[k] = (crops[k] ?? 0) + m.amount;
        prof = prof.copyWith(
            life: prof.life
                .copyWith(farm: prof.life.farm.copyWith(crops: crops)));
      case MilestoneReward.meal:
        final k = mealKey(mealOf(npc), CropQuality.raro);
        final meals = {...prof.life.farm.meals};
        meals[k] = (meals[k] ?? 0) + m.amount;
        prof = prof.copyWith(
            life: prof.life
                .copyWith(farm: prof.life.farm.copyWith(meals: meals)));
      default:
        break;
    }
    final e = endgameExtra(prof, m);
    if (e.material != null && e.n > 0) {
      final mats = {...prof.materials};
      mats[e.material!] =
          math.min(CraftMaterial.maxStack, (mats[e.material!] ?? 0) + e.n);
      prof = prof.copyWith(materials: mats);
    }
    return prof;
  }

  /// The meal a resident gives: fixed per resident, from the catalog.
  static String mealOf(String npc) {
    final ids = kMeals.keys.toList();
    return ids[npc.codeUnits.fold(0, (a, c) => a + c) % ids.length];
  }

  /// Endgame currency added to a milestone once Ecos are unlocked
  /// (`msEnd*`): chests pay Esquirlas del Eco, materials and meals
  /// Cristales de Era, weapons and uniques Anclas Temporales (the Eco
  /// milestone pays the Eco itself).
  static EndgameExtra endgameExtra(PlayerProfile p, MilestoneDef m) {
    if (!p.ecosUnlocked) return (material: null, n: 0);
    return switch (m.reward) {
      MilestoneReward.chestWood ||
      MilestoneReward.chestSilver =>
        (material: CraftMaterial.esquirla, n: t.i('msEndShards')),
      MilestoneReward.material ||
      MilestoneReward.meal =>
        (material: CraftMaterial.cristal, n: t.i('msEndCrystals')),
      MilestoneReward.weapon ||
      MilestoneReward.unique =>
        (material: CraftMaterial.ancla, n: t.i('msEndAnchors')),
      _ => (material: null, n: 0),
    };
  }

  /// Chance that a delivered order also rolls a bonus chest.
  static double get orderChestChance => t.d('orderChestChance');
}
