import 'dart:math' as math;

import '../data/game_catalog.dart';
import '../data/items_catalog.dart';
import '../models/attributes.dart';
import '../models/battle_command.dart';
import '../models/passive_tree.dart';
import '../models/player_profile.dart';
import '../models/player_state.dart';
import '../models/upgrade_stat.dart';
import '../models/weapon.dart';
import 'js_math.dart';
import 'passive_tree_rules.dart';
import 'stats_calculator.dart';

/// Resultado de [ProgressionRules.gainXp].
typedef XpGain = ({PlayerProfile profile, int levelsGained});

/// Progresión y economía de un jugador — puerto de `xpNeed`, `resetBuild`,
/// `canEquip`, `upCost`, `wSkills`, `wName` y de las acciones del host
/// `cls`, `respec`, `stats`, `equip`, `node`, `treeReset`, `fuse`, `up`,
/// `buyItem`, `buy`, más la validación de `addPlayer`. Ver
/// docs/specs/progression.md.
///
/// Funciones puras: las acciones devuelven el perfil nuevo, o `null` si
/// no son válidas (el perfil no cambia). En qué modo de la sesión se
/// permite cada una lo decide `SessionEngine`.
class ProgressionRules {
  const ProgressionRules({
    required this.stats,
    this.catalog = GameCatalog.standard,
  });

  final StatsCalculator stats;
  final GameCatalog catalog;

  PassiveTreeRules get treeRules => stats.treeRules;

  static const pointsPerLevel = 3;
  static const upgradeMax = WeaponUpgradeLevels.upMax;
  static const fuseCost = 200;
  static const maxLevel = 99;
  static const maxInventory = 40;
  static const maxNameLength = 10;
  static const maxItems = kMaxItemStack;

  // ------------------------------------------------------------------
  // Consultas
  // ------------------------------------------------------------------

  /// XP para pasar del nivel [level] al siguiente.
  static int xpNeed(int level) => 10 + level * level * 8;

  int baseAttributeSum(String classId) =>
      catalog.classes[classId]!.baseAttributes.values.fold(0, (a, b) => a + b);

  static int attributeSum(PlayerAttributes a) =>
      Attribute.values.fold(0, (s, k) => s + a[k]);

  /// `canEquip`: arma de su clase y requisitos cumplidos con [attributes]
  /// (por defecto, los del perfil).
  bool canEquip(PlayerProfile p, String weaponId,
      {PlayerAttributes? attributes}) {
    final w = catalog.weapons[weaponId];
    return w != null &&
        w.classId == p.classId &&
        w.meetsRequirements(attributes ?? p.attributes);
  }

  /// El arma que realmente usa: la equipada si puede, si no la inicial
  /// (como `stats(p)`).
  WeaponDef equippedWeapon(PlayerProfile p) {
    final eq = p.equipped;
    if (eq != null && canEquip(p, eq)) return catalog.weapons[eq]!;
    return catalog.weapons[catalog.classes[p.classId]!.startWeaponId]!;
  }

  PlayerBuild buildOf(PlayerProfile p, {PlayerAttributes? attributes}) {
    final w = equippedWeapon(p);
    return PlayerBuild(
      classId: p.classId,
      level: p.level,
      attributes: attributes ?? p.attributes,
      equippedWeapon: w,
      weaponUpgrades: p.upgradesFor(w.id),
      passiveProgress: p.passiveProgress,
    );
  }

  DerivedStats derivedStats(PlayerProfile p) => stats.calculate(buildOf(p));

  /// `previewOf`: los stats si se confirmara el reparto [add].
  DerivedStats previewAllocation(PlayerProfile p, Map<Attribute, int> add) =>
      stats.calculate(buildOf(p, attributes: p.attributes.add(add)));

  /// `wSkills`: kit de clase + habilidades del arma + la fusionada.
  List<String> weaponSkills(PlayerProfile p, [String? weaponId]) {
    final w = weaponId == null
        ? equippedWeapon(p)
        : catalog.weapons[weaponId];
    if (w == null) return const [];
    final l = [...catalog.classes[p.classId]!.kitSkillIds, ...w.skillIds];
    final f = p.fused[w.id];
    if (f != null && catalog.skills.containsKey(f) && !l.contains(f)) l.add(f);
    return l;
  }

  /// `upStatsFor`: Defensa solo en armas con escudo.
  List<UpgradeStat> upgradeStatsFor(WeaponDef w) => [
        UpgradeStat.pow,
        UpgradeStat.crit,
        UpgradeStat.spd,
        if (w.shieldDefense > 0) UpgradeStat.def,
      ];

  /// `upCost`: costo de subir de [level] a `level + 1`.
  int upgradeCost(String weaponId, int level) =>
      jsRound(math.max(catalog.weapons[weaponId]!.price, 200) * 0.22 * (level + 1));

  /// `wName`: "Nombre +N" con N = suma de mejoras.
  String weaponDisplayName(PlayerProfile p, String weaponId) {
    final t = p.upgradesFor(weaponId).total;
    return '${catalog.weapons[weaponId]!.name}${t > 0 ? ' +$t' : ''}';
  }

  // ------------------------------------------------------------------
  // Validación de perfiles (`loadProfile` + `addPlayer`)
  // ------------------------------------------------------------------

  /// Deja un perfil (leído de disco o recibido por red) en un estado
  /// válido. Nunca falla: lo inválido se corrige o se descarta.
  PlayerProfile normalize(PlayerProfile raw) {
    final cls = catalog.classes.containsKey(raw.classId) ? raw.classId : 'guerrero';
    final level = raw.level.clamp(1, maxLevel);
    final weapons = catalog.weapons;

    // Árbol: en orden, solo nodos que se podrían haber tomado.
    final tree = <String>[];
    for (final id in raw.tree) {
      if (treeRules.canTake(cls, level, PlayerPassiveProgress(tree), id)) {
        tree.add(id);
      }
    }

    final fused = <String, String>{
      for (final e in raw.fused.entries)
        if (weapons.containsKey(e.key) && catalog.skills.containsKey(e.value))
          e.key: e.value,
    };

    final upgrades = <String, WeaponUpgradeLevels>{};
    raw.upgrades.forEach((id, levels) {
      final w = weapons[id];
      if (w == null) return;
      var clean = const WeaponUpgradeLevels();
      for (final s in upgradeStatsFor(w)) {
        clean = clean.withLevel(s, levels.level(s).clamp(0, upgradeMax));
      }
      upgrades[id] = clean;
    });

    var p = PlayerProfile(
      name: raw.name.length > maxNameLength
          ? raw.name.substring(0, maxNameLength)
          : raw.name,
      classId: cls,
      level: level,
      xp: math.max(0, raw.xp),
      credits: math.max(0, raw.credits),
      attributes: raw.attributes,
      points: raw.points,
      inventory: raw.inventory
          .where(weapons.containsKey)
          .take(maxInventory)
          .toList(),
      equipped: weapons.containsKey(raw.equipped) ? raw.equipped : null,
      potions: raw.potions.clamp(0, maxItems),
      ethers: raw.ethers.clamp(0, maxItems),
      upgrades: upgrades,
      fused: fused,
      tree: tree,
    );

    final base = catalog.classes[cls]!.baseAttributes;
    final okAttributes = Attribute.values.every((k) => p.attributes[k] >= (base[k] ?? 0)) &&
        p.points >= 0 &&
        attributeSum(p.attributes) + p.points ==
            baseAttributeSum(cls) + (level - 1) * pointsPerLevel;
    if (okAttributes) {
      p = _withStartWeapon(p);
    } else {
      p = resetBuild(p);
    }
    final eq = p.equipped;
    if (eq == null || !canEquip(p, eq)) {
      p = p.copyWith(equipped: catalog.classes[cls]!.startWeaponId);
    }
    return p;
  }

  PlayerProfile _withStartWeapon(PlayerProfile p) {
    final start = catalog.classes[p.classId]!.startWeaponId;
    return p.inventory.contains(start)
        ? p
        : p.copyWith(inventory: [...p.inventory, start]);
  }

  // ------------------------------------------------------------------
  // Acciones
  // ------------------------------------------------------------------

  /// `resetBuild`: atributos al base de la clase y todos los puntos para
  /// repartir. También es la acción "Reiniciar puntos" (`respec`).
  PlayerProfile resetBuild(PlayerProfile p) {
    final c = catalog.classes[p.classId]!;
    var next = _withStartWeapon(p.copyWith(
      attributes: PlayerAttributes.base(c.baseAttributes),
      points: (p.level - 1) * pointsPerLevel,
    ));
    final eq = next.equipped;
    if (eq == null || !canEquip(next, eq)) {
      next = next.copyWith(equipped: c.startWeaponId);
    }
    return next;
  }

  /// Suma XP y sube los niveles que alcance (+3 puntos cada uno).
  XpGain gainXp(PlayerProfile p, int xp) {
    var level = p.level, rest = p.xp + xp, points = p.points, gained = 0;
    while (rest >= xpNeed(level)) {
      rest -= xpNeed(level);
      level++;
      points += pointsPerLevel;
      gained++;
    }
    return (
      profile: p.copyWith(xp: rest, level: level, points: points),
      levelsGained: gained,
    );
  }

  /// `stats`: reparte puntos. Negativos cuentan como 0; el total debe
  /// ser > 0 y alcanzar.
  PlayerProfile? allocate(PlayerProfile p, Map<Attribute, int> add) {
    final clean = {for (final k in Attribute.values) k: math.max(0, add[k] ?? 0)};
    final total = clean.values.fold(0, (a, b) => a + b);
    if (total <= 0 || total > p.points) return null;
    return p.copyWith(
      attributes: p.attributes.add(clean),
      points: p.points - total,
    );
  }

  /// `cls`: cambia de clase (árbol vacío, arma inicial, `resetBuild`).
  PlayerProfile? changeClass(PlayerProfile p, String classId) {
    final c = catalog.classes[classId];
    if (c == null || classId == p.classId) return null;
    return resetBuild(p.copyWith(
      classId: classId,
      tree: const [],
      equipped: c.startWeaponId,
    ));
  }

  /// `equip`.
  PlayerProfile? equip(PlayerProfile p, String weaponId) {
    if (!p.inventory.contains(weaponId) || !canEquip(p, weaponId)) return null;
    return p.copyWith(equipped: weaponId);
  }

  /// `buy`: arma de su clase, a la venta, que no tenga y pueda pagar
  /// (no hace falta cumplir requisitos).
  PlayerProfile? buyWeapon(PlayerProfile p, String weaponId) {
    final w = catalog.weapons[weaponId];
    if (w == null ||
        w.classId != p.classId ||
        w.price <= 0 ||
        p.inventory.contains(weaponId) ||
        p.credits < w.price) {
      return null;
    }
    return p.copyWith(
      credits: p.credits - w.price,
      inventory: [...p.inventory, weaponId],
    );
  }

  /// `buyItem`.
  PlayerProfile? buyItem(PlayerProfile p, BattleItem item) {
    final def = kItems[item]!;
    final have = item == BattleItem.potion ? p.potions : p.ethers;
    if (have >= maxItems || p.credits < def.price) return null;
    return p.copyWith(
      credits: p.credits - def.price,
      potions: item == BattleItem.potion ? have + 1 : null,
      ethers: item == BattleItem.ether ? have + 1 : null,
    );
  }

  /// `up`: sube 1 nivel una estadística de un arma propia de su clase.
  PlayerProfile? upgrade(PlayerProfile p, String weaponId, UpgradeStat stat) {
    final w = catalog.weapons[weaponId];
    if (w == null ||
        !upgradeStatsFor(w).contains(stat) ||
        !p.inventory.contains(weaponId) ||
        w.classId != p.classId) {
      return null;
    }
    final levels = p.upgradesFor(weaponId);
    final l = levels.level(stat);
    if (l >= upgradeMax) return null;
    final cost = upgradeCost(weaponId, l);
    if (p.credits < cost) return null;
    return p.copyWith(
      credits: p.credits - cost,
      upgrades: {...p.upgrades, weaponId: levels.withLevel(stat, l + 1)},
    );
  }

  /// `fuse`: [baseId] hereda [skillId] de [sacrificeId], que se consume.
  PlayerProfile? fuse(
      PlayerProfile p, String baseId, String sacrificeId, String skillId) {
    final a = catalog.weapons[baseId];
    final b = catalog.weapons[sacrificeId];
    if (a == null ||
        b == null ||
        baseId == sacrificeId ||
        !p.inventory.contains(baseId) ||
        !p.inventory.contains(sacrificeId) ||
        a.classId != p.classId ||
        b.classId != p.classId ||
        sacrificeId == catalog.classes[p.classId]!.startWeaponId ||
        sacrificeId == p.equipped ||
        !b.skillIds.contains(skillId) ||
        p.credits < fuseCost) {
      return null;
    }
    final fused = {...p.fused, baseId: skillId}..remove(sacrificeId);
    final upgrades = {...p.upgrades}..remove(sacrificeId);
    return p.copyWith(
      credits: p.credits - fuseCost,
      fused: fused,
      upgrades: upgrades,
      inventory: p.inventory.where((x) => x != sacrificeId).toList(),
    );
  }

  /// `node`: toma un nodo del árbol de pasivas.
  PlayerProfile? takeNode(PlayerProfile p, String nodeId) {
    if (!treeRules.canTake(p.classId, p.level, p.passiveProgress, nodeId)) {
      return null;
    }
    return p.copyWith(tree: [...p.tree, nodeId]);
  }

  /// `treeReset`.
  PlayerProfile resetTree(PlayerProfile p) => p.copyWith(tree: const []);

  /// Agrega un arma ganada (cofre, élite, fin de misión).
  PlayerProfile grantWeapon(PlayerProfile p, String weaponId) =>
      p.copyWith(inventory: [...p.inventory, weaponId]);
}
