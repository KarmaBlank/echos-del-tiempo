import '../data/achievements_catalog.dart';
import '../data/affixes_catalog.dart';
import '../data/tuning_catalog.dart';
import '../models/achievement.dart';
import '../data/ascension_mechanics.dart';
import '../data/game_catalog.dart';
import '../data/passive_mechanics.dart';
import '../data/passive_tree_catalog.dart';
import '../models/item.dart';
import '../models/passive_mechanic.dart';
import '../models/passive_tree.dart';
import 'balance_codecs.dart';
import 'balance_fields.dart';

/// Los registros globales mutables que el motor consulta directo
/// (`kAffixes`, `kMechanics`, `kAscensionMechanics`, `kPassiveTree.nodes`).
/// Un parche se instala **en el lugar** (docs/specs/balance_admin.md § 3):
/// la primera vez se guardan los originales, cada [install] parte de
/// ellos y [restore] los devuelve.
abstract final class BalanceRegistries {
  static Map<String, AffixDef>? _affixes;
  static Map<String, PassiveMechanic>? _mechanics;
  static Map<String, PassiveMechanic>? _ascMechanics;
  static Map<String, PassiveNode>? _nodes;

  static void _snapshot() {
    _affixes ??= Map.of(kAffixes);
    _mechanics ??= Map.of(kMechanics);
    _ascMechanics ??= Map.of(kAscensionMechanics);
    _nodes ??= Map.of(kPassiveTree.nodes);
  }

  static Map<String, AffixDef> get originalAffixes {
    _snapshot();
    return Map.unmodifiable(_affixes!);
  }

  static Map<String, PassiveNode> get originalNodes {
    _snapshot();
    return Map.unmodifiable(_nodes!);
  }

  /// Mecánicas del árbol y de la ascensión, juntas.
  static Map<String, PassiveMechanic> get originalMechanics {
    _snapshot();
    return Map.unmodifiable({..._ascMechanics!, ..._mechanics!});
  }

  /// Vuelve los registros a los valores del código.
  static void restore() {
    if (_affixes == null) return;
    _affixes!.forEach((k, v) => kAffixes[k] = v);
    _mechanics!.forEach((k, v) => kMechanics[k] = v);
    _ascMechanics!.forEach((k, v) => kAscensionMechanics[k] = v);
    _nodes!.forEach((k, v) => kPassiveTree.nodes[k] = v);
    kTuning
      ..clear()
      ..addAll(kTuningDefaults);
    kAchievementRewardOverrides.clear();
  }

  /// Instala los overrides de afijos, nodos y mecánicas de [overrides]
  /// (ya validados) sobre los originales.
  static void install(
      Map<BalanceKind, Map<String, Map<String, Object?>>> overrides) {
    _snapshot();
    restore();
    void each(BalanceKind kind, Map<String, Object> originals,
        void Function(String id, Object value) put) {
      final codec = codecOf(kind);
      for (final e in (overrides[kind] ?? const {}).entries) {
        final base = originals[e.key];
        if (base == null || e.value.isEmpty) continue;
        final merged = {...codec.read(base), ...e.value};
        put(e.key, codec.write(base, BalanceFieldReader(merged)));
      }
    }

    each(BalanceKind.affix, _affixes!,
        (id, v) => kAffixes[id] = v as AffixDef);
    each(BalanceKind.passiveNode, _nodes!,
        (id, v) => kPassiveTree.nodes[id] = v as PassiveNode);
    each(BalanceKind.mechanic, {..._ascMechanics!, ..._mechanics!}, (id, v) {
      final m = v as PassiveMechanic;
      if (_mechanics!.containsKey(id)) kMechanics[id] = m;
      if (_ascMechanics!.containsKey(id)) kAscensionMechanics[id] = m;
    });
    for (final kind in kTuningKinds) {
      final id = kind.jsonKey;
      final o = overrides[kind]?[id];
      final base = kTuningDefaults[id];
      if (o == null || o.isEmpty || base == null) continue;
      final codec = codecOf(kind);
      kTuning[id] = codec.write(
          base, BalanceFieldReader({...codec.read(base), ...o})) as TuningDef;
    }
    for (final e in (overrides[BalanceKind.featReward] ?? const {}).entries) {
      final def = kAchievementsById[e.key];
      if (def == null || e.value.isEmpty) continue;
      final codec = codecOf(BalanceKind.featReward);
      kAchievementRewardOverrides[e.key] = codec.write(
              def, BalanceFieldReader({...codec.read(def), ...e.value}))
          as AchievementReward;
    }
  }
}

/// Los datos "del código" contra los que se valida y se aplica un parche.
class BalanceBase {
  BalanceBase({
    required this.catalog,
    required this.affixes,
    required this.nodes,
    required this.mechanics,
  });

  /// El catálogo del código + los registros originales.
  factory BalanceBase.standard() => BalanceBase(
        catalog: GameCatalog.standard,
        affixes: BalanceRegistries.originalAffixes,
        nodes: BalanceRegistries.originalNodes,
        mechanics: BalanceRegistries.originalMechanics,
      );

  final GameCatalog catalog;
  final Map<String, AffixDef> affixes;
  final Map<String, PassiveNode> nodes;
  final Map<String, PassiveMechanic> mechanics;

  /// Las entidades base de un tipo, por id.
  Map<String, Object> entities(BalanceKind k) => switch (k) {
        BalanceKind.skill => catalog.skills,
        // Las 13 de tipo de arma (por tipo) y las 50 v2 (por id).
        BalanceKind.ultimate => {...catalog.ultimates, ...catalog.playerUlts},
        BalanceKind.dual => catalog.duals,
        BalanceKind.weapon => catalog.weapons,
        BalanceKind.enemy => catalog.enemies,
        BalanceKind.enemyUlt => catalog.enemyUlts,
        BalanceKind.classDef => catalog.classes,
        BalanceKind.affix => affixes,
        BalanceKind.passiveNode => nodes,
        BalanceKind.mechanic => mechanics,
        BalanceKind.reaction => catalog.reactions,
        BalanceKind.elementStatus => catalog.elementStatuses,
        // Por número de jefe como texto (`1`..`5`).
        BalanceKind.abyssBoss => {
            for (final e in catalog.abyssBosses.entries) '${e.key}': e.value,
          },
        BalanceKind.fragmentDrop => catalog.fragmentDrops,
        BalanceKind.hitCap => catalog.hitCaps,
        BalanceKind.combo => catalog.comboRules,
        BalanceKind.curve => catalog.curves,
        BalanceKind.ultLevel ||
        BalanceKind.ultUpgrade ||
        BalanceKind.ultCharge ||
        BalanceKind.condense ||
        BalanceKind.materials ||
        BalanceKind.ecoTier ||
        BalanceKind.consumables ||
        BalanceKind.travesia ||
        BalanceKind.combatLimits ||
        BalanceKind.exploration ||
        BalanceKind.farming ||
        BalanceKind.animals ||
        BalanceKind.town ||
        BalanceKind.fishing ||
        BalanceKind.lifeTree ||
        BalanceKind.smithing ||
        BalanceKind.regions ||
        BalanceKind.ascension =>
          {k.jsonKey: kTuningDefaults[k.jsonKey]!},
        BalanceKind.featReward => kAchievementsById,
      };

  late final BalanceContext context = BalanceContext(
    skillIds: catalog.skills.keys.toSet(),
    nodeEffectKeys: {
      'hp', 'mp', 'atk', 'mag', 'crit', 'spd', 'def', 'ult', 'heal', //
      'burn', 'poi', 'frz', 'key',
      for (final n in nodes.values) ...n.effects.keys,
    },
  );
}
