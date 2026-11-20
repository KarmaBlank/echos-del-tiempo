import 'dart:math' as math;

import '../data/game_catalog.dart';
import '../data/items_catalog.dart';
import '../models/attributes.dart';
import '../models/battle_command.dart';
import '../models/eco.dart';
import '../models/game_session.dart';
import '../models/item.dart';
import '../models/loot.dart';
import '../models/passive_tree.dart';
import '../models/player_profile.dart';
import '../models/player_state.dart';
import '../models/upgrade_stat.dart';
import '../models/weapon.dart';
import 'ascension_rules.dart';
import 'craft_rules.dart';
import 'eco_rules.dart';
import 'inventory_rules.dart';
import 'item_rules.dart';
import 'js_math.dart';
import 'loot_rules.dart';
import 'passive_tree_rules.dart';
import 'stats_calculator.dart';
import 'trial_rules.dart';
import 'ult_rules.dart';

/// Resultado de [ProgressionRules.gainXp].
typedef XpGain = ({
  PlayerProfile profile,
  int levelsGained,
  int masteryGained,
});

/// Progresión y economía de un jugador — puerto de `xpNeed`, `resetBuild`,
/// `canEquip`, `upCost`, `wSkills`, `wName` y de las acciones del host
/// `cls`, `respec`, `stats`, `equip`, `node`, `treeReset`, `fuse`, `up`,
/// `buyItem`, `buy`, más la validación de `addPlayer`. Ver
/// docs/specs/progression.md y loot.md (loot v2: armas como instancias).
///
/// Funciones puras: las acciones devuelven el perfil nuevo, o `null` si
/// no son válidas (el perfil no cambia). En qué modo de la sesión se
/// permite cada una lo decide `SessionEngine`.
///
/// Las acciones que reciben un `weaponId` aceptan el `uid` de una
/// instancia o el id de una base (usa la instancia principal de esa
/// base): así la UI anterior a loot v2 sigue funcionando.
class ProgressionRules {
  const ProgressionRules({
    required this.stats,
    this.catalog = GameCatalog.standard,
  });

  final StatsCalculator stats;
  final GameCatalog catalog;

  PassiveTreeRules get treeRules => stats.treeRules;

  ItemRules get items => ItemRules(catalog: catalog);
  LootRules get loot => LootRules(items: items);
  InventoryRules get inventory => InventoryRules(items: items);
  CraftRules get crafting => CraftRules(loot: loot);
  EcoRules get ecos => EcoRules(catalog: catalog);
  AscensionRules get ascensions => const AscensionRules();
  TrialRules get trials => TrialRules(catalog: catalog);

  /// Puntos de atributo por nivel ganado (progresión v2: 1, que suma
  /// [kAttrPerPoint] = +3 al atributo elegido; antes 3 de +1).
  static const pointsPerLevel = 1;
  static const upgradeMax = WeaponUpgradeLevels.upMax;

  /// Costo de la fusión vieja (trasladar una habilidad a un arma Común).
  static const fuseCost = 200;
  static const maxLevel = 50;

  /// Casillas del inventario (antes: tope de armas).
  static const maxInventory = InventoryRules.cells;
  static const maxNameLength = 10;
  static const maxItems = kMaxItemStack;

  /// Decisión temporal del dueño ("reiniciar puntos gratis siempre, por
  /// ahora"): reiniciar el árbol y los puntos de atributo no cuesta nada
  /// y se puede en cualquier modo salvo en batalla. Con `false` vuelve la
  /// regla del prototipo: solo en lobby / preparación. Ver
  /// docs/specs/progression.md § "Reiniciar".
  static const freeRespec = true;

  /// Si se puede reiniciar puntos o árbol en el modo [mode].
  bool canRespec(SessionMode mode) => freeRespec
      ? mode != SessionMode.battle
      : mode == SessionMode.lobby || mode == SessionMode.prep;

  // ------------------------------------------------------------------
  // Consultas
  // ------------------------------------------------------------------

  /// XP para pasar del nivel [level] al siguiente (progression.md
  /// § "Niveles"): hasta el 10 la curva del prototipo (`10 + l² × 8`);
  /// después `32 × xpFactor(l) × batallas(l)`, con
  /// `batallas(l) = 11 + 0.36 × (l − 10)` (~11 batallas por nivel en el
  /// 11, ~25 en el 49) a la XP por batalla esperada de una zona de nivel
  /// `l`.
  static int xpNeed(int level) => level <= 10
      ? 10 + level * level * 8
      : jsRound(32 * xpFactor(level) * (11 + 0.36 * (level - 10)));

  /// Multiplicador de XP de un enemigo de nivel [monsterLevel]
  /// (`1 + 0.15 × (nivel − 1)`). Gancho para el mundo nuevo: las misiones
  /// de hoy no lo aplican (sus enemigos no tienen nivel).
  static double xpFactor(int monsterLevel) => 1 + 0.15 * (monsterLevel - 1);

  /// XP total para llegar a [level] desde el 1.
  static int totalXpTo(int level) {
    var t = 0;
    for (var l = 1; l < level; l++) {
      t += xpNeed(l);
    }
    return t;
  }

  int baseAttributeSum(String classId) =>
      catalog.classes[classId]!.baseAttributes.values.fold(0, (a, b) => a + b);

  static int attributeSum(PlayerAttributes a) =>
      Attribute.values.fold(0, (s, k) => s + a[k]);

  /// La base de [weaponId] (`uid` de una instancia propia o id de base).
  WeaponDef? baseFor(PlayerProfile p, String weaponId) =>
      catalog.weapons[p.item(weaponId)?.baseId ?? weaponId];

  /// `canEquip`: cualquier clase, con el nivel de la base y sus
  /// requisitos de atributos cumplidos con [attributes] (por defecto, los
  /// del perfil). loot.md § 0.2.
  bool canEquip(PlayerProfile p, String weaponId,
      {PlayerAttributes? attributes}) {
    final w = baseFor(p, weaponId);
    return w != null && meetsRequirements(p, w, attributes: attributes);
  }

  bool meetsRequirements(PlayerProfile p, WeaponDef w,
          {PlayerAttributes? attributes}) =>
      p.level >= w.level && w.meetsRequirements(attributes ?? p.attributes);

  /// La instancia que realmente usa: la equipada si puede, si no la del
  /// arma inicial de su clase (como `stats(p)`). `null` si no tiene
  /// ninguna (perfil sin normalizar).
  ItemInstance? equippedItem(PlayerProfile p) {
    final eq = p.equippedItem;
    if (eq != null && canEquip(p, eq.uid)) return eq;
    return p.item(catalog.classes[p.classId]!.startWeaponId);
  }

  /// La base que realmente usa.
  WeaponDef equippedWeapon(PlayerProfile p) {
    final it = equippedItem(p);
    return catalog.weapons[it?.baseId] ??
        catalog.weapons[catalog.classes[p.classId]!.startWeaponId]!;
  }

  PlayerBuild buildOf(PlayerProfile p, {PlayerAttributes? attributes}) {
    final it = equippedItem(p);
    final w = equippedWeapon(p);
    final item = it != null && it.baseId == w.id ? it : null;
    final sel = UltRules.validSel(p, w, item, catalog);
    return PlayerBuild(
      classId: p.classId,
      level: p.level,
      attributes: attributes ?? p.attributes,
      equippedWeapon: w,
      weaponUpgrades: item?.forge ?? const WeaponUpgradeLevels(),
      passiveProgress: p.passiveProgress,
      item: item,
      ascension: p.ascension,
      ultSel: sel,
      ultLevel: UltRules.levelOf(
          p, sel ?? (item == null ? null : UltRules.itemUltId(item)) ?? ''),
    );
  }

  DerivedStats derivedStats(PlayerProfile p) => stats.calculate(buildOf(p));

  /// `previewOf`: los stats si se confirmara el reparto [add] (en puntos,
  /// como [allocate]; ya con el tope blando).
  DerivedStats previewAllocation(PlayerProfile p, Map<Attribute, int> add) =>
      stats.calculate(buildOf(p, attributes: p.attributes.add(rawOf(add))));

  /// Stats si [p] equipara el arma [weaponId] (vista previa de equipar).
  DerivedStats previewEquip(PlayerProfile p, String weaponId) {
    final it = p.item(weaponId);
    final w = baseFor(p, weaponId) ?? equippedWeapon(p);
    return stats.calculate(PlayerBuild(
      classId: p.classId,
      level: p.level,
      attributes: p.attributes,
      equippedWeapon: w,
      weaponUpgrades: it?.forge ?? const WeaponUpgradeLevels(),
      passiveProgress: p.passiveProgress,
      item: it,
      ascension: p.ascension,
    ));
  }

  /// `wSkills`: kit de clase + habilidades del arma + las trasladadas.
  List<String> weaponSkills(PlayerProfile p, [String? weaponId]) {
    final it = weaponId == null ? equippedItem(p) : p.item(weaponId);
    final w = weaponId == null ? equippedWeapon(p) : baseFor(p, weaponId);
    if (w == null) return const [];
    final l = [...catalog.classes[p.classId]!.kitSkillIds, ...w.skillIds];
    for (final f in it?.extraSkills ?? const <String>[]) {
      if (catalog.skills.containsKey(f) && !l.contains(f)) l.add(f);
    }
    return l;
  }

  /// `upStatsFor`: Defensa solo en armas con escudo.
  List<UpgradeStat> upgradeStatsFor(WeaponDef w) => crafting.forgeStatsFor(w);

  /// `upCost`: costo de subir de [level] a `level + 1` (rareza de la
  /// instancia principal de esa base si la tiene, si no Común).
  int upgradeCost(String weaponId, int level, [PlayerProfile? p]) {
    final it = p?.item(weaponId);
    final w = catalog.weapons[it?.baseId ?? weaponId]!;
    return CraftRules.forgeCost(w, it?.rarity ?? Rarity.comun, level);
  }

  /// `wName`: nombre de la instancia (con `+N` de forja).
  String weaponDisplayName(PlayerProfile p, String weaponId) {
    final it = p.item(weaponId);
    if (it == null) return catalog.weapons[weaponId]?.name ?? weaponId;
    return items.displayName(it);
  }

  // ------------------------------------------------------------------
  // Validación de perfiles (`loadProfile` + `addPlayer`)
  // ------------------------------------------------------------------

  /// Deja un perfil (leído de disco o recibido por red) en un estado
  /// válido. Nunca falla: lo inválido se corrige o se descarta.
  PlayerProfile normalize(PlayerProfile raw) {
    final cls = catalog.classes.containsKey(raw.classId) ? raw.classId : 'guerrero';
    final level = raw.level.clamp(1, maxLevel);
    // La Maestría solo existe en el nivel 50.
    final mastery = level >= maxLevel ? raw.mastery : 0;

    // Árbol: en orden, solo nodos que se podrían haber tomado (la
    // Maestría suma puntos).
    // Hitos (progression_v2.md § 5): solo keystones elegibles y con el
    // nivel alcanzado.
    final manual = PassiveTreeRules.milestoneTaken(
        raw.tree, raw.milestone10, raw.milestone20);
    String? ms(int m, String? id) => id != null &&
            level >= m &&
            treeRules.milestoneOptions(cls, m, taken: manual).contains(id)
        ? id
        : null;
    final ms10 = ms(10, raw.milestone10), ms20 = ms(20, raw.milestone20);
    final asc = ascensions.sanitize(cls, level, raw.ascension);
    final earned = PassiveTreeRules.pointsEarned(level + mastery,
        trials: asc.trials.length, ms10: ms10 != null, ms20: ms20 != null);
    final tree = <String>[];
    for (final id in raw.tree) {
      if (treeRules.canTake(cls, earned, PlayerPassiveProgress(tree), id)) {
        tree.add(id);
      }
    }

    // Armas: válidas contra los catálogos, `uid` sin repetir.
    final list = <ItemInstance>[];
    final uids = <String>{};
    for (final r in raw.items) {
      if (list.length >= InventoryRules.maxItems) break;
      final it = items.sanitize(r);
      if (it == null) continue;
      var uid = it.uid;
      var n = 2;
      while (uids.contains(uid)) {
        uid = '${it.uid}#${n++}';
      }
      uids.add(uid);
      list.add(uid == it.uid ? it : it.copyWith(uid: uid));
    }

    // Ecos: válidos y con `uid` que no choque con nada de la grilla.
    final ecos = <EcoItem>[];
    for (final e in raw.ecos) {
      if (ecos.length >= InventoryRules.cells) break;
      var uid = e.uid;
      while (uids.contains(uid)) {
        uid = '$uid#';
      }
      uids.add(uid);
      ecos.add(EcoRules.sanitize(uid == e.uid ? e : e.copyWith(uid: uid)));
    }

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
      items: list,
      equipped: raw.equippedUid,
      potions: raw.potions.clamp(0, maxItems),
      ethers: raw.ethers.clamp(0, maxItems),
      materials: {
        for (final e in raw.materials.entries)
          e.key: e.value.clamp(0, CraftMaterial.maxStack),
      },
      grid: raw.grid,
      lootFilter: raw.lootFilter,
      itemSeq: math.max(0, raw.itemSeq),
      tree: tree,
      unlockedZone: raw.unlockedZone,
      ecos: ecos,
      ecosUnlocked: raw.ecosUnlocked,
      mastery: mastery,
      ascension: asc,
      milestone10: ms10,
      milestone20: ms20,
      achievements: raw.achievements,
      // ULT v2 (ultimates_v2.md § 5.2): solo ids que existen.
      ultKnown: {
        for (final id in raw.ultKnown)
          if (UltRules.isLearnable(id)) id
      },
      ultSel: UltRules.isUltId(raw.ultSel, catalog) ? raw.ultSel : null,
      ultLevels: {
        for (final e in raw.ultLevels.entries)
          if (UltRules.isLearnable(e.key) && e.value > 1)
            e.key: e.value.clamp(1, UltRules.maxLevel),
      },
      // Jefes del Abismo vencidos (v0.8): solo 1..5.
      abyssKills: {
        for (final n in raw.abyssKills)
          if (n >= 1 && n <= 5) n
      },
      // Marca NUEVO (perfil v4): solo de lo que existe.
      fresh: {
        for (final u in raw.fresh)
          if (uids.contains(u)) u
      },
    );

    final base = catalog.classes[cls]!.baseAttributes;
    // Progresión v2: cada atributo = base + 3 × k, con Σ k + puntos =
    // nivel − 1 (progression_v2.md § 2.1).
    var spentUnits = 0;
    var okAttributes = p.points >= 0;
    for (final k in Attribute.values) {
      final d = p.attributes[k] - (base[k] ?? 0);
      if (d < 0 || d % kAttrPerPoint != 0) okAttributes = false;
      spentUnits += d ~/ kAttrPerPoint;
    }
    okAttributes = okAttributes &&
        spentUnits + p.points == (level - 1) * pointsPerLevel;
    if (okAttributes) {
      p = _withStartWeapon(p);
    } else {
      p = resetBuild(p);
    }
    final eq = p.equippedItem;
    if (eq == null || !canEquip(p, eq.uid)) {
      p = p.copyWith(equipped: catalog.classes[cls]!.startWeaponId);
    }
    return InventoryRules.relayout(p);
  }

  PlayerProfile _withStartWeapon(PlayerProfile p) {
    final start = catalog.classes[p.classId]!.startWeaponId;
    if (p.items.any((i) => i.baseId == start)) return p;
    final free = p.itemByUid(start) == null;
    if (free) {
      return p.copyWith(items: [...p.items, ItemInstance.common(start, start)]);
    }
    return InventoryRules.addItem(p, ItemInstance.common(start, start)).$1;
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
    final eq = next.equippedItem;
    if (eq == null || !canEquip(next, eq.uid)) {
      next = next.copyWith(equipped: c.startWeaponId);
    }
    return InventoryRules.relayout(next);
  }

  /// Suma XP y sube los niveles que alcance (+1 punto de atributo y 1 de árbol cada uno), hasta
  /// el nivel máximo; en el 50 la XP llena la Maestría (+1 punto de árbol
  /// cada nivel, tope 20; docs/specs/ecos_atlas.md § 6). Con la Maestría
  /// al tope la XP deja de acumularse.
  XpGain gainXp(PlayerProfile p, int xp) {
    var level = p.level, rest = p.xp + xp, points = p.points, gained = 0;
    while (level < maxLevel && rest >= xpNeed(level)) {
      rest -= xpNeed(level);
      level++;
      points += pointsPerLevel;
      gained++;
    }
    var mastery = p.mastery, mGained = 0;
    if (level >= maxLevel) {
      while (mastery < PlayerProfile.maxMastery &&
          rest >= masteryNeed(mastery)) {
        rest -= masteryNeed(mastery);
        mastery++;
        mGained++;
      }
      if (mastery >= PlayerProfile.maxMastery) rest = 0;
    }
    return (
      profile: p.copyWith(
          xp: rest, level: level, points: points, mastery: mastery),
      levelsGained: gained,
      masteryGained: mGained,
    );
  }

  /// XP para pasar de la Maestría [m] a la siguiente: `12 000 + 3 000 m`.
  static int masteryNeed(int m) => 12000 + 3000 * m;

  /// XP total de la Maestría 0 a la 20.
  static int get totalMasteryXp {
    var t = 0;
    for (var m = 0; m < PlayerProfile.maxMastery; m++) {
      t += masteryNeed(m);
    }
    return t;
  }

  /// `stats`: reparte puntos. [add] cuenta puntos (cada uno suma
  /// [kAttrPerPoint] al atributo; progression_v2.md § 2.1). Negativos
  /// cuentan como 0; el total debe ser > 0 y alcanzar.
  PlayerProfile? allocate(PlayerProfile p, Map<Attribute, int> add) {
    final clean = {for (final k in Attribute.values) k: math.max(0, add[k] ?? 0)};
    final total = clean.values.fold(0, (a, b) => a + b);
    if (total <= 0 || total > p.points) return null;
    return p.copyWith(
      attributes: p.attributes.add(rawOf(clean)),
      points: p.points - total,
    );
  }

  /// Puntos por atributo → suma cruda (× [kAttrPerPoint]).
  static Map<Attribute, int> rawOf(Map<Attribute, int> units) =>
      {for (final e in units.entries) e.key: e.value * kAttrPerPoint};

  /// `cls`: cambia de clase (árbol vacío, arma inicial, `resetBuild`).
  PlayerProfile? changeClass(PlayerProfile p, String classId) {
    final c = catalog.classes[classId];
    if (c == null || classId == p.classId) return null;
    // La ascensión es de la clase: se saca (las Pruebas hechas quedan).
    final next = _withStartWeapon(p.copyWith(
        classId: classId,
        tree: const [],
        milestone10: () => null,
        milestone20: () => null,
        ascension: ascensions.reset(p, full: true).ascension));
    return resetBuild(next.copyWith(equipped: c.startWeaponId));
  }

  /// `equip`: [weaponId] es un `uid` propio o una base que tenga.
  PlayerProfile? equip(PlayerProfile p, String weaponId) {
    final it = p.item(weaponId);
    if (it == null || !canEquip(p, it.uid)) return null;
    return InventoryRules.relayout(p.copyWith(equipped: it.uid));
  }

  /// `buy`: una base a la venta (precio > 0) que no tenga, Común. Se puede
  /// comprar sin cumplir requisitos; necesita una casilla libre.
  PlayerProfile? buyWeapon(PlayerProfile p, String weaponId) {
    final w = catalog.weapons[weaponId];
    if (w == null ||
        w.price <= 0 ||
        p.items.any((i) => i.baseId == weaponId) ||
        p.credits < w.price ||
        InventoryRules.freeCells(p) <= 0) {
      return null;
    }
    final (next, _) = InventoryRules.addItem(
        p.copyWith(credits: p.credits - w.price),
        ItemInstance.common(LootRules.newUid, weaponId, itemLevel: w.level));
    return next;
  }

  /// `buyItem`.
  PlayerProfile? buyItem(PlayerProfile p, BattleItem item) {
    final def = kItems[item]!;
    final have = item == BattleItem.potion ? p.potions : p.ethers;
    if (have >= maxItems || p.credits < def.price) return null;
    return InventoryRules.relayout(p.copyWith(
      credits: p.credits - def.price,
      potions: item == BattleItem.potion ? have + 1 : null,
      ethers: item == BattleItem.ether ? have + 1 : null,
    ));
  }

  /// `up`: forja 1 nivel de una estadística (`CraftRules.forge`).
  PlayerProfile? upgrade(PlayerProfile p, String weaponId, UpgradeStat stat) {
    final it = p.item(weaponId);
    if (it == null) return null;
    return crafting.forge(p, it.uid, stat).profile;
  }

  /// `fuse` (compatibilidad): [baseId] hereda [skillId] de [sacrificeId],
  /// que se consume (`CraftRules.transferSkill`). No elige reemplazo: con
  /// los cupos llenos falla (loot.md § 16.2).
  PlayerProfile? fuse(
      PlayerProfile p, String baseId, String sacrificeId, String skillId) {
    final a = p.item(baseId), b = p.item(sacrificeId);
    if (a == null || b == null) return null;
    return crafting.transferSkill(p, a.uid, b.uid, skillId).profile;
  }

  /// `node`: toma un nodo del árbol de pasivas. Con un hito pendiente se
  /// rechaza: primero se elige el hito (progression_v2.md § 5.1).
  PlayerProfile? takeNode(PlayerProfile p, String nodeId) =>
      p.pendingMilestones.isNotEmpty ? null : _takeNode(p, nodeId);

  /// Toma [nodeId] sin mirar los hitos pendientes (camino del hito).
  PlayerProfile? _takeNode(PlayerProfile p, String nodeId) {
    if (!treeRules.canTake(
        p.classId, p.treePoints, p.passiveProgress, nodeId)) {
      return null;
    }
    return p.copyWith(tree: [...p.tree, nodeId]);
  }

  /// Perfil tras quitar [nodeId] del árbol, sin validar: 1 punto vuelve
  /// al pool y, si era la keystone de un hito, ese hito queda pendiente
  /// (progression_v2.md § 6.1).
  PlayerProfile _without(PlayerProfile p, String nodeId) {
    var next = p.copyWith(tree: [...p.tree]..remove(nodeId));
    if (p.milestone10 == nodeId) next = next.copyWith(milestone10: () => null);
    if (p.milestone20 == nodeId) next = next.copyWith(milestone20: () => null);
    return next;
  }

  /// Motivo por el que no se puede quitar [nodeId] (`null` = se puede;
  /// progression_v2.md § 6.1).
  String? untakeReason(PlayerProfile p, String nodeId) {
    if (!p.tree.contains(nodeId)) return 'No está tomado';
    final next = _without(p, nodeId);
    if (!treeRules.allConnected(p.classId, next.tree)) {
      return 'Otros nodos dependen de este';
    }
    final over = next.tree.length - next.treePoints;
    if (over > 0) {
      return 'Quitá antes $over nodo${over == 1 ? '' : 's'}: '
          'los puntos del hito están en uso';
    }
    return null;
  }

  /// `untake`: quita un nodo tomado (reembolso gratis). `null` si no se
  /// puede ([untakeReason]).
  PlayerProfile? untakeNode(PlayerProfile p, String nodeId) =>
      untakeReason(p, nodeId) == null ? _without(p, nodeId) : null;

  /// Camino en un clic (progression_v2.md § 4): toma [ids] en orden hasta
  /// el primero que no se pueda. Devuelve el perfil y cuántos tomó
  /// (`null` si ninguno).
  /// Con un hito pendiente se rechaza, como [takeNode].
  (PlayerProfile, int)? takeNodes(PlayerProfile p, List<String> ids) =>
      p.pendingMilestones.isNotEmpty ? null : _takeNodes(p, ids);

  (PlayerProfile, int)? _takeNodes(PlayerProfile p, List<String> ids) {
    var next = p;
    var n = 0;
    for (final id in ids) {
      final t = _takeNode(next, id);
      if (t == null) break;
      next = t;
      n++;
    }
    return n == 0 ? null : (next, n);
  }

  /// Hito del nivel [milestone] (10 o 20, progression_v2.md § 5): elige
  /// [keystoneId] entre `milestoneOptions` y toma con los puntos del hito
  /// el camino más corto hacia ella (hasta donde alcancen; lo que sobra
  /// queda libre). `null` si no se puede.
  PlayerProfile? chooseMilestone(
      PlayerProfile p, int milestone, String keystoneId) {
    final bound = PassiveTreeRules.milestonePoints[milestone];
    if (bound == null || p.level < milestone) return null;
    final current = milestone == 10 ? p.milestone10 : p.milestone20;
    if (current != null) return null;
    // El host valida igual que el cliente: nunca una keystone ya tomada.
    if (p.tree.contains(keystoneId)) return null;
    final manual =
        PassiveTreeRules.milestoneTaken(p.tree, p.milestone10, p.milestone20);
    if (!treeRules
        .milestoneOptions(p.classId, milestone, taken: manual)
        .contains(keystoneId)) {
      return null;
    }
    final path = treeRules.pathTo(p.classId, p.passiveProgress, keystoneId);
    if (path == null) return null;
    var next = milestone == 10
        ? p.copyWith(milestone10: () => keystoneId)
        : p.copyWith(milestone20: () => keystoneId);
    // `pathTo` ya trae solo los nodos que faltan: los puntos del hito no
    // se gastan en nodos tomados.
    final take = path.take(bound).toList();
    next = _takeNodes(next, take)?.$1 ?? next;
    return next;
  }

  /// `treeReset`: árbol vacío y los hitos vuelven a quedar pendientes
  /// (sus puntos se recuperan al volver a elegir; no se duplican).
  PlayerProfile resetTree(PlayerProfile p) => p.copyWith(
      tree: const [], milestone10: () => null, milestone20: () => null);

  /// Agrega un arma Común de [weaponId] (compatibilidad; sin mirar el
  /// lugar).
  PlayerProfile grantWeapon(PlayerProfile p, String weaponId) =>
      InventoryRules.addItem(
              p,
              ItemInstance.common(LootRules.newUid, weaponId,
                  itemLevel: catalog.weapons[weaponId]?.level ?? 1))
          .$1;

  /// Recibe un drop si hay lugar (`null` si no).
  PlayerProfile? grant(PlayerProfile p, LootDrop d) =>
      InventoryRules.receive(p, d);
}
