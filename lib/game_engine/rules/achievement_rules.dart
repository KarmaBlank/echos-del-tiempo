import '../data/achievements_catalog.dart';
import '../models/achievement.dart';
import '../models/attributes.dart';
import '../models/battle_event.dart';
import '../models/item.dart';
import '../models/player_profile.dart';
import '../models/session_action.dart';
import '../models/session_event.dart';
import '../models/skill.dart';
import '../models/status.dart';
import 'item_rules.dart';
import 'loot_filter_rules.dart';
import 'progression_rules.dart';

/// Lo que un jugador hizo en un paso: hazañas de una vez y sumas a los
/// contadores (docs/specs/achievements.md § 5.1).
class AchievementHits {
  final ids = <String>{};
  final counters = <String, int>{};

  bool get isEmpty => ids.isEmpty && counters.isEmpty;

  void add(String id) => ids.add(id);

  void count(String counter, [int n = 1]) {
    if (n <= 0) return;
    counters[counter] = (counters[counter] ?? 0) + n;
  }
}

/// Seguimiento de una batalla para las hazañas de combate que necesitan
/// más de un paso (quién preparó una Convergencia, Instante del turno).
/// Lo lleva el host; no viaja ni se guarda.
class AchievementBattleTracker {
  /// Objetivo → estado → último jugador que se lo puso.
  final _primers = <String, Map<StatusKind, String>>{};

  /// Jugadores que ya usaron una INSTANTE en su turno actual.
  final _instant = <String>{};

  void reset() {
    _primers.clear();
    _instant.clear();
  }
}

/// Reglas de las Hazañas: detectan con los eventos del motor (en el
/// host) y pagan una sola vez (§ 5). Dart puro.
class AchievementRules {
  const AchievementRules({this.catalog = kAchievements});

  final List<AchievementDef> catalog;

  /// Operaciones que cuentan como fusión (§ 2.2).
  static const fusionOps = {
    CraftOp.transferAffix,
    CraftOp.transferPassive,
    CraftOp.transferSkill,
    CraftOp.removeAffix,
    CraftOp.addAffix,
    CraftOp.reroll,
    CraftOp.upgradeRarity,
  };

  static const _salvageOps = {
    CraftOp.salvage,
    CraftOp.salvageAll,
    CraftOp.salvageSelected,
  };


  /// Algún atributo crudo pasa su tope blando (§ 2.6, `attr_cap`).
  static bool overSoftCap(PlayerProfile p) => Attribute.values
      .any((a) => p.attributes[a] > (kAttrSoftCap[a] ?? 1 << 30));

  /// Hazañas de una acción ya aplicada (OK) de un jugador: [before] y
  /// [after] son su perfil antes y después.
  void fromAction(AchievementHits h, SessionAction a, PlayerProfile before,
      PlayerProfile after) {
    switch (a) {
      case UpgradeAction(:final weaponId):
        h
          ..add('forge_first')
          ..count(AchievementCounter.forgeLevels);
        final w = after.item(weaponId);
        if (w != null) {
          if (w.forge.total >= 5) h.add('forge_plus5');
          if (w.rarity.index >= Rarity.raro.index &&
              w.forge.total >= ItemRules.forgeCapOf(w)) {
            h.add('forge_cap');
          }
        }
      case CraftAction(:final op, :final targetUid):
        if (fusionOps.contains(op)) h.count(AchievementCounter.fusions);
        switch (op) {
          case CraftOp.transferSkill:
            h.add('fuse_skill');
            final b = before.itemByUid(targetUid);
            final t = after.itemByUid(targetUid);
            if (t != null && t.quebrarReplaced && !(b?.quebrarReplaced ?? false)) {
              h.add('fuse_break_slot');
            }
          case CraftOp.transferPassive:
            h.add('fuse_passive');
          case CraftOp.transferAffix:
            h.add('fuse_affix');
          case CraftOp.upgradeRarity:
            h.add('fuse_rarity');
          case CraftOp.reroll:
            h.add('fuse_reroll');
          case CraftOp.reforge:
            h.add('reforge_first');
          default:
            if (_salvageOps.contains(op)) {
              h.count(AchievementCounter.salvaged,
                  before.items.length - after.items.length);
            } else if (op.sells) {
              h.add('sell_first');
            }
        }
      case EquipAction():
        if (after.equippedItem?.rarity == Rarity.legendario) {
          h.add('equip_legendary');
        }
      case ChooseMilestoneAction():
        h.add('tree_milestone');
      case SetLootFilterAction(:final text):
        if (text != null &&
            text.trim().isNotEmpty &&
            text.trim() != LootFilterRules.defaultText.trim()) {
          h.add('filter_rule');
        }
      case StashPutAction():
        if (!identical(before, after)) h.add('stash_store');
      case ClaimAchievementAction(:final id):
        if (kClientClaimableAchievements.contains(id)) h.add(id);
      default:
        break;
    }
    if (overSoftCap(after) && !overSoftCap(before)) h.add('attr_cap');
  }

  /// Hazañas de combate de los eventos de un paso de batalla (§ 2.5).
  /// [isPlayer]: id de un jugador de la sala (no compañero). [isBoss]:
  /// el combatiente es un jefe. [skill]: la definición de una habilidad.
  void fromBattle(
    Map<String, AchievementHits> out,
    List<BattleEvent> events,
    AchievementBattleTracker t, {
    required bool Function(String id) isPlayer,
    required bool Function(String id) isBoss,
    required SkillDef? Function(String id) skill,
  }) {
    AchievementHits hits(String id) => out.putIfAbsent(id, AchievementHits.new);
    String? actor;
    for (final e in events) {
      switch (e) {
        case TurnStartedEvent(:final actorId):
          t._instant.remove(actorId);
          actor = null;
        case ActionEvent(:final actorId, :final kind, :final skillId):
          actor = isPlayer(actorId) ? actorId : null;
          if (actor == null) break;
          if (t._instant.contains(actor)) {
            hits(actor).add('combat_instant_chain');
          }
          if (kind == BattleActionKind.skill &&
              skillId != null &&
              (skill(skillId)?.instant ?? false)) {
            t._instant.add(actor);
          }
        case EnemyUltEvent():
          actor = null;
        case StatusAppliedEvent(:final targetId, :final kind):
          if (actor != null) {
            t._primers.putIfAbsent(targetId, () => {})[kind] = actor;
          }
        case ReactionEvent(:final targetId, :final kind, :final sourceId):
          if (!kind.convergence) break;
          final det = sourceId != null && isPlayer(sourceId) ? sourceId : actor;
          if (det != null) hits(det).add('combat_convergence');
          final prep = t._primers[targetId]?[kind.primer];
          if (prep != null && isPlayer(prep)) {
            hits(prep).add('combat_convergence');
          }
        case BreakEvent(:final targetId, :final phase, :final cancelledUlt):
          if (phase != BreakPhase.broken || actor == null) break;
          hits(actor).add('combat_break');
          if (cancelledUlt && isBoss(targetId)) {
            hits(actor).add('combat_cancel_ult');
          }
        default:
          break;
      }
    }
  }

  /// Hazañas de fin de Eco y de Jefe del Abismo (§ 2.7).
  void fromSession(Map<String, AchievementHits> out, SessionEvent e) {
    AchievementHits hits(String id) => out.putIfAbsent(id, AchievementHits.new);
    switch (e) {
      case EcoCompletedEvent(:final playerIds):
        for (final p in playerIds) {
          hits(p).add('eco_first');
        }
      case AbyssDefeatedEvent(:final playerIds):
        for (final p in playerIds) {
          hits(p).add('abyss_boss');
        }
      default:
        break;
    }
  }

  /// Aplica [h] al perfil: suma contadores, marca lo nuevo con la fecha
  /// [nowS] (segundos) y paga cada hazaña una sola vez. Lo ya logrado no
  /// se vuelve a pagar (idempotente, § 5.1).
  (PlayerProfile, List<AchievementUnlock>) grant(
      PlayerProfile p, AchievementHits h, int nowS) {
    if (h.isEmpty) return (p, const []);
    final ach = p.achievements;
    final counters = {...ach.counters};
    h.counters.forEach((k, v) => counters[k] = (counters[k] ?? 0) + v);
    final done = {...ach.done};
    final unlocks = <AchievementUnlock>[];
    var prof = p;
    for (final def in catalog) {
      if (done.containsKey(def.id)) continue;
      final c = def.counter;
      final hit = c != null
          ? (counters[c] ?? 0) >= def.goal
          : h.ids.contains(def.id);
      if (!hit) continue;
      done[def.id] = nowS;
      final (next, lost) = pay(prof, def.reward);
      prof = next;
      unlocks.add(AchievementUnlock(def.id, def.reward, lost: lost));
    }
    final nextAch = AchievementProgress(done: done, counters: counters);
    return (prof.copyWith(achievements: nextAch), unlocks);
  }

  /// Suma [r] a [p] respetando la pila 99 de materiales y el tope de
  /// pociones; lo que no entra se pierde (como el desarmado) y se
  /// devuelve para avisarlo.
  static (PlayerProfile, Map<String, int>) pay(
      PlayerProfile p, AchievementReward r) {
    final lost = <String, int>{};
    final mats = {...p.materials};
    r.materials.forEach((m, n) {
      final cur = mats[m] ?? 0;
      final room = CraftMaterial.maxStack - cur;
      final got = n < room ? n : (room < 0 ? 0 : room);
      if (got < n) lost[m.label] = n - got;
      mats[m] = cur + got;
    });
    int cap(int cur, int add, String label) {
      const max = ProgressionRules.maxItems;
      final room = max - cur;
      final got = add < room ? add : (room < 0 ? 0 : room);
      if (got < add) lost[label] = add - got;
      return cur + got;
    }

    return (
      p.copyWith(
        credits: p.credits + r.credits,
        materials: mats,
        potions: r.potions > 0 ? cap(p.potions, r.potions, 'Poción de vida') : null,
        ethers: r.ethers > 0 ? cap(p.ethers, r.ethers, 'Poción de maná') : null,
      ),
      lost,
    );
  }

  // ------------------------------------------------------------------
  // Migración de cuentas existentes (§ 6.1)
  // ------------------------------------------------------------------

  /// Lo que se puede inferir de los personajes ([profiles], con sus
  /// armas) y del alijo ([stashItems]) de una cuenta sin `ach`, más los
  /// datos de cuenta ([atlasNodes], [atlasDone]).
  AchievementHits infer({
    required Iterable<PlayerProfile> profiles,
    Iterable<ItemInstance> stashItems = const [],
    bool atlasNodes = false,
    Iterable<String> atlasDone = const [],
  }) {
    final h = AchievementHits();
    var forged = 0;
    void weapon(ItemInstance w) {
      final f = w.forge.total;
      forged += f;
      if (f >= 1) h.add('forge_first');
      if (f >= 5) h.add('forge_plus5');
      if (w.rarity.index >= Rarity.raro.index &&
          f > 0 &&
          f >= ItemRules.forgeCapOf(w)) {
        h.add('forge_cap');
      }
      if (w.extraSkills.isNotEmpty) h.add('fuse_skill');
      if (w.quebrarReplaced) h.add('fuse_break_slot');
    }

    for (final p in profiles) {
      p.items.forEach(weapon);
      if (p.equippedItem?.rarity == Rarity.legendario) h.add('equip_legendary');
      if (p.milestone10 != null || p.milestone20 != null) {
        h.add('tree_milestone');
      }
      if (overSoftCap(p)) h.add('attr_cap');
      if (p.abyssKills.isNotEmpty) h.add('abyss_boss');
      if (p.lootFilter != null &&
          p.lootFilter!.trim().isNotEmpty &&
          p.lootFilter!.trim() != LootFilterRules.defaultText.trim()) {
        h.add('filter_rule');
      }
    }
    stashItems.forEach(weapon);
    if (atlasNodes) h.add('atlas_node');
    for (final d in atlasDone) {
      if (d.startsWith('x')) h.add('abyss_boss');
      if (d.startsWith('t')) h.add('eco_first');
    }
    h.count(AchievementCounter.forgeLevels, forged);
    return h;
  }
}
