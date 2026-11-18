import '../data/passive_tree_catalog.dart';
import '../rules/passive_tree_migration.dart';
import 'ascension.dart';
import 'attributes.dart';
import 'eco.dart';
import 'item.dart';
import 'passive_tree.dart';
import 'upgrade_stat.dart';
import 'weapon.dart';

/// Progreso persistente de un jugador: lo que el prototipo guardaba en
/// `localStorage` (`saveProfile`) y mandaba al host en `hello`.
/// Inmutable: las reglas de `ProgressionRules` devuelven perfiles nuevos.
/// Ver docs/specs/progression.md § "Perfil persistente" y loot.md § 15
/// (perfil v3: armas como instancias, materiales, grilla y filtro).
///
/// Compatibilidad: el constructor y [copyWith] siguen aceptando la forma
/// vieja (`inventory` = ids de base, `equipped` = id de base, `upgrades` y
/// `fused` por id de base) y la traducen a instancias; los getters
/// [inventory], [equipped], [upgrades] y [fused] la devuelven derivada de
/// [items]. Un arma migrada usa el id de su base como `uid`.
class PlayerProfile {
  factory PlayerProfile({
    String name = '',
    String classId = 'guerrero',
    int level = 1,
    int xp = 0,
    int credits = 0,
    PlayerAttributes? attributes,
    int points = 0,
    List<String> inventory = const [],
    String? equipped,
    int potions = defaultPotions,
    int ethers = defaultEthers,
    Map<String, WeaponUpgradeLevels> upgrades = const {},
    Map<String, String> fused = const {},
    List<ItemInstance>? items,
    Map<CraftMaterial, int> materials = const {},
    List<String?> grid = const [],
    String? lootFilter,
    int itemSeq = 0,
    List<String> tree = const [],
    int treeRefunded = 0,
    int unlockedZone = 1,
    List<EcoItem> ecos = const [],
    bool ecosUnlocked = false,
    int mastery = 0,
    AscensionProgress ascension = AscensionProgress.empty,
  }) {
    final list = items ?? _legacyItems(inventory, upgrades, fused);
    return PlayerProfile._(
      name: name,
      classId: classId,
      level: level,
      xp: xp,
      credits: credits,
      attributes: attributes ?? const PlayerAttributes({}),
      points: points,
      items: List.unmodifiable(list),
      equippedUid: _resolve(list, equipped),
      potions: potions,
      ethers: ethers,
      materials: Map.unmodifiable({
        for (final e in materials.entries)
          if (e.value > 0) e.key: e.value,
      }),
      grid: List.unmodifiable(grid),
      lootFilter: lootFilter,
      itemSeq: itemSeq,
      tree: List.unmodifiable(tree),
      treeRefunded: treeRefunded,
      unlockedZone: unlockedZone.clamp(1, maxZone),
      ecos: List.unmodifiable(ecos),
      ecosUnlocked: ecosUnlocked,
      mastery: mastery.clamp(0, maxMastery),
      ascension: ascension,
    );
  }

  const PlayerProfile._({
    required this.ascension,
    required this.ecos,
    required this.ecosUnlocked,
    required this.mastery,
    required this.name,
    required this.classId,
    required this.level,
    required this.xp,
    required this.credits,
    required this.attributes,
    required this.points,
    required this.items,
    required this.equippedUid,
    required this.potions,
    required this.ethers,
    required this.materials,
    required this.grid,
    required this.lootFilter,
    required this.itemSeq,
    required this.tree,
    required this.treeRefunded,
    required this.unlockedZone,
  });

  /// Zonas del mapa del mundo (docs/specs/worldgen.md § 6.4).
  static const maxZone = 10;

  /// Tope de la Maestría (docs/specs/ecos_atlas.md § 6).
  static const maxMastery = 20;

  /// Ecos en el inventario (ocupan casilla; JSON `ecos`).
  final List<EcoItem> ecos;

  /// Portal del Eco activado (venció al Devorador; JSON `eco`).
  final bool ecosUnlocked;

  /// Nivel de Maestría 0–20 (JSON `ms`): con nivel 50 la XP la llena.
  final int mastery;

  /// Nivel para los puntos del árbol: cada maestría da 1 punto más.
  int get treeLevel => level + mastery;

  /// Pruebas del Tiempo, ascensión y sus nodos (JSON `asc`,
  /// docs/specs/ascension.md).
  final AscensionProgress ascension;

  EcoItem? ecoByUid(String uid) {
    for (final e in ecos) {
      if (e.uid == uid) return e;
    }
    return null;
  }

  /// Zona más alta que puede proponer (1..10, JSON `zu`). Sube al vencer
  /// al jefe de la zona anterior.
  final int unlockedZone;

  /// Zona desbloqueada de un perfil guardado sin `zu` (migración):
  /// `min(5, (nivel − 1) ~/ 5 + 1)`.
  static int migratedZone(int level) {
    final z = ((level < 1 ? 1 : level) - 1) ~/ 5 + 1;
    return z > 5 ? 5 : z;
  }

  /// Pociones con las que arranca un perfil nuevo (`d.pot ?? 3`, `d.eter ?? 1`).
  static const defaultPotions = 3;
  static const defaultEthers = 1;

  /// Versión del formato del perfil (`pv`). 3 = loot v2.
  static const formatVersion = 3;

  final String name;
  final String classId;
  final int level;
  final int xp;
  final int credits;
  final PlayerAttributes attributes;

  /// Puntos de atributo sin repartir (`pts`).
  final int points;

  /// Armas (instancias), en orden de obtención. Incluye la equipada.
  final List<ItemInstance> items;

  /// `uid` del arma equipada. `null` solo antes de `ProgressionRules.normalize`.
  final String? equippedUid;
  final int potions;
  final int ethers;

  /// Materiales de crafteo (solo los > 0).
  final Map<CraftMaterial, int> materials;

  /// Grilla del inventario tal como la ordenó el jugador (tokens: `uid`,
  /// `pot`, `eter`, `mat:<material>`; `null` = casilla vacía). La forma
  /// final la da `InventoryRules.layout`.
  final List<String?> grid;

  /// Filtro de loot en el formato de texto de loot.md § 13; `null` = el
  /// filtro por defecto.
  final String? lootFilter;

  /// Contador para los `uid` de las armas nuevas (`i<n>`).
  final int itemSeq;

  /// Nodos del árbol tomados, en orden (`tree`).
  final List<String> tree;

  /// Versión del árbol con la que se guardó `tree` (`tv`).
  static const treeVersion = kPassiveTreeVersion;

  /// Nodos del árbol viejo que se devolvieron al cargar este perfil (la
  /// migración a una versión nueva del árbol lo reinicia gratis). Solo
  /// vive hasta que la sala lo avisa: `ProgressionRules.normalize` lo
  /// deja en 0. Ver passive_tree_v2.md § 6.
  final int treeRefunded;

  PlayerPassiveProgress get passiveProgress => PlayerPassiveProgress(tree);

  // ------------------------------------------------------------------
  // Vista vieja (por id de base), para la UI anterior a loot v2
  // ------------------------------------------------------------------

  /// Ids de base de las armas que tiene, sin repetir, en orden (`inv`).
  List<String> get inventory {
    final seen = <String>{};
    return List.unmodifiable(
        [for (final i in items) if (seen.add(i.baseId)) i.baseId]);
  }

  /// Id de base del arma equipada (`eq`).
  String? get equipped => equippedItem?.baseId ?? equippedUid;

  ItemInstance? get equippedItem =>
      equippedUid == null ? null : itemByUid(equippedUid!);

  ItemInstance? itemByUid(String uid) {
    for (final i in items) {
      if (i.uid == uid) return i;
    }
    return null;
  }

  /// El arma con ese `uid` o, si no hay, la "principal" de esa base: la
  /// equipada si es de esa base, si no la primera.
  ItemInstance? item(String uidOrBase) {
    final byUid = itemByUid(uidOrBase);
    if (byUid != null) return byUid;
    final eq = equippedItem;
    if (eq != null && eq.baseId == uidOrBase) return eq;
    for (final i in items) {
      if (i.baseId == uidOrBase) return i;
    }
    return null;
  }

  /// Mejoras por base (`up`) de las armas principales con alguna mejora.
  Map<String, WeaponUpgradeLevels> get upgrades => Map.unmodifiable({
        for (final base in inventory)
          if (item(base) case final i? when i.forge.total > 0) base: i.forge,
      });

  /// Habilidad trasladada por base (`fuse`): la última de cada arma
  /// principal.
  Map<String, String> get fused => Map.unmodifiable({
        for (final base in inventory)
          if (item(base) case final i? when i.extraSkills.isNotEmpty)
            base: i.extraSkills.last,
      });

  WeaponUpgradeLevels upgradesFor(String weaponId) =>
      item(weaponId)?.forge ?? const WeaponUpgradeLevels();

  int material(CraftMaterial m) => materials[m] ?? 0;

  PlayerProfile copyWith({
    String? name,
    String? classId,
    int? level,
    int? xp,
    int? credits,
    PlayerAttributes? attributes,
    int? points,
    List<String>? inventory,
    String? equipped,
    int? potions,
    int? ethers,
    Map<String, WeaponUpgradeLevels>? upgrades,
    Map<String, String>? fused,
    List<ItemInstance>? items,
    Map<CraftMaterial, int>? materials,
    List<String?>? grid,
    String? lootFilter,
    bool clearLootFilter = false,
    int? itemSeq,
    List<String>? tree,
    int? unlockedZone,
    List<EcoItem>? ecos,
    bool? ecosUnlocked,
    int? mastery,
    AscensionProgress? ascension,
  }) {
    var list = items ?? this.items;
    if (inventory != null) list = _fromIds(list, inventory);
    if (upgrades != null) {
      list = _applyByBase(list, equippedUid, upgrades,
          (i, v) => i.copyWith(forge: v ?? const WeaponUpgradeLevels()));
    }
    if (fused != null) {
      list = _applyByBase(list, equippedUid, fused,
          (i, v) => i.copyWith(extraSkills: [if (v != null) v]));
    }
    final eq = equipped == null ? equippedUid : _resolve(list, equipped);
    return PlayerProfile._(
      name: name ?? this.name,
      classId: classId ?? this.classId,
      level: level ?? this.level,
      xp: xp ?? this.xp,
      credits: credits ?? this.credits,
      attributes: attributes ?? this.attributes,
      points: points ?? this.points,
      items: List.unmodifiable(list),
      equippedUid: eq,
      potions: potions ?? this.potions,
      ethers: ethers ?? this.ethers,
      materials: materials == null
          ? this.materials
          : Map.unmodifiable({
              for (final e in materials.entries)
                if (e.value > 0) e.key: e.value,
            }),
      grid: grid == null ? this.grid : List.unmodifiable(grid),
      lootFilter: clearLootFilter ? null : lootFilter ?? this.lootFilter,
      itemSeq: itemSeq ?? this.itemSeq,
      tree: tree == null ? this.tree : List.unmodifiable(tree),
      treeRefunded: treeRefunded,
      unlockedZone: (unlockedZone ?? this.unlockedZone).clamp(1, maxZone),
      ecos: ecos == null ? this.ecos : List.unmodifiable(ecos),
      ecosUnlocked: ecosUnlocked ?? this.ecosUnlocked,
      mastery: (mastery ?? this.mastery).clamp(0, maxMastery),
      ascension: ascension ?? this.ascension,
    );
  }

  // ------------------------------------------------------------------
  // Traducción desde la forma vieja
  // ------------------------------------------------------------------

  /// Cada id → instancia Común con `uid` = id (`id#2`, `id#3`... si se
  /// repite), con las mejoras y la fusión de esa base en la primera.
  static List<ItemInstance> _legacyItems(List<String> ids,
      Map<String, WeaponUpgradeLevels> upgrades, Map<String, String> fused) {
    final out = <ItemInstance>[];
    final count = <String, int>{};
    for (final id in ids) {
      final n = (count[id] ?? 0) + 1;
      count[id] = n;
      final f = n == 1 ? fused[id] : null;
      out.add(ItemInstance.common(n == 1 ? id : '$id#$n', id,
          forge: n == 1
              ? upgrades[id] ?? const WeaponUpgradeLevels()
              : const WeaponUpgradeLevels(),
          extraSkills: [if (f != null) f]));
    }
    return out;
  }

  /// Rehace la lista según [ids] (de base o `uid`), reusando instancias.
  static List<ItemInstance> _fromIds(List<ItemInstance> from, List<String> ids) {
    final pool = [...from];
    final out = <ItemInstance>[];
    for (final id in ids) {
      var k = pool.indexWhere((i) => i.uid == id);
      if (k < 0) k = pool.indexWhere((i) => i.baseId == id);
      if (k >= 0) {
        out.add(pool.removeAt(k));
      } else {
        final taken = {for (final i in [...out, ...pool]) i.uid};
        var uid = id, n = 2;
        while (taken.contains(uid)) {
          uid = '$id#${n++}';
        }
        out.add(ItemInstance.common(uid, id));
      }
    }
    return out;
  }

  /// Aplica un mapa por base (o `uid`) a la instancia principal de cada
  /// base (la equipada si es de esa base, si no la primera); las demás
  /// principales quedan sin ese dato ([f] con `null`).
  static List<ItemInstance> _applyByBase<V>(List<ItemInstance> list,
      String? equippedUid, Map<String, V> byId,
      ItemInstance Function(ItemInstance, V?) f) {
    final principal = <String, String>{};
    for (final i in list) {
      if (i.uid == equippedUid) principal[i.baseId] = i.uid;
    }
    for (final i in list) {
      principal.putIfAbsent(i.baseId, () => i.uid);
    }
    return [
      for (final i in list)
        if (byId.containsKey(i.uid))
          f(i, byId[i.uid])
        else if (principal[i.baseId] == i.uid)
          f(i, byId[i.baseId])
        else
          i,
    ];
  }

  static String? _resolve(List<ItemInstance> list, String? id) {
    if (id == null) return null;
    for (final i in list) {
      if (i.uid == id) return id;
    }
    for (final i in list) {
      if (i.baseId == id) return i.uid;
    }
    return id;
  }

  // ------------------------------------------------------------------
  // JSON (claves del prototipo + v3)
  // ------------------------------------------------------------------

  static String attributeKey(Attribute a) => a.name.toUpperCase();

  Map<String, Object?> toJson() => {
        'pv': formatVersion,
        'name': name,
        'cls': classId,
        'lvl': level,
        'xp': xp,
        'cr': credits,
        'st': {
          for (final a in Attribute.values) attributeKey(a): attributes[a],
        },
        'pts': points,
        'items': [for (final i in items) i.toJson()],
        'eq': equippedUid,
        'pot': potions,
        'eter': ethers,
        if (materials.isNotEmpty)
          'mats': {for (final e in materials.entries) e.key.name: e.value},
        if (grid.isNotEmpty) 'grid': grid,
        if (lootFilter != null) 'lf': lootFilter,
        if (itemSeq > 0) 'seq': itemSeq,
        'tree': tree,
        'tv': treeVersion,
        if (treeRefunded > 0) 'tvRef': treeRefunded,
        'zu': unlockedZone,
        // Endgame v0.4 (ecos_atlas.md): opcionales.
        if (ecos.isNotEmpty) 'ecos': [for (final e in ecos) e.toJson()],
        if (ecosUnlocked) 'eco': true,
        if (mastery > 0) 'ms': mastery,
        // Ascensión v0.5 (ascension.md § 2): opcional.
        if (!ascension.isEmpty) 'asc': ascension.toJson(),
      };

  /// Lectura tolerante: lo que falta o tiene otro tipo toma su valor por
  /// defecto. No valida contra los catálogos: eso lo hace
  /// `ProgressionRules.normalize` (como `addPlayer` en el prototipo).
  /// Un perfil sin `items` (v1/v2) se migra: cada id de `inv` → arma
  /// Común con sus mejoras (`up`) y su fusión (`fuse`).
  factory PlayerProfile.fromJson(Map<String, Object?> json) {
    final st = json['st'];
    final attrs = <Attribute, int>{};
    if (st is Map) {
      for (final a in Attribute.values) {
        attrs[a] = _int(st[attributeKey(a)]);
      }
    }
    // Árbol de otra versión: se migra y lo que no sigue igual se devuelve
    // gratis (passive_tree_v3.md § 11).
    var tree = _strings(json['tree']);
    var refunded = _int(json['tvRef']);
    final tv = _int(json['tv'], 1);
    if (tv < treeVersion && tree.isNotEmpty) {
      final kept = migrateTreeIds(
          json['cls'] is String ? json['cls'] as String : 'guerrero', tree, tv);
      refunded += tree.length - kept.length;
      tree = kept;
    }
    final rawItems = json['items'];
    List<ItemInstance>? items;
    var inventory = const <String>[];
    final up = <String, WeaponUpgradeLevels>{};
    final fused = <String, String>{};
    if (rawItems is List) {
      items = [
        for (final r in rawItems)
          if (ItemInstance.fromJson(r) case final i?) i
      ];
    } else {
      inventory = _strings(json['inv']);
      final rawUp = json['up'];
      if (rawUp is Map) {
        rawUp.forEach((k, v) {
          if (k is! String || v is! Map) return;
          var levels = const WeaponUpgradeLevels();
          v.forEach((sk, sv) {
            final s = sk is String ? UpgradeStat.fromKey(sk) : null;
            if (s != null) levels = levels.withLevel(s, _int(sv));
          });
          up[k] = levels;
        });
      }
      final rawFuse = json['fuse'];
      if (rawFuse is Map) {
        rawFuse.forEach((k, v) {
          if (k is String && v is String) fused[k] = v;
        });
      }
    }
    final mats = <CraftMaterial, int>{};
    final rawMats = json['mats'];
    if (rawMats is Map) {
      rawMats.forEach((k, v) {
        final m = k is String ? CraftMaterial.byName(k) : null;
        if (m != null) mats[m] = _int(v);
      });
    }
    final rawGrid = json['grid'];
    return PlayerProfile(
      name: json['name'] is String ? json['name'] as String : '',
      classId: json['cls'] is String ? json['cls'] as String : 'guerrero',
      level: _int(json['lvl'], 1),
      xp: _int(json['xp']),
      credits: _int(json['cr']),
      attributes: st is Map ? PlayerAttributes(Map.unmodifiable(attrs)) : null,
      points: _int(json['pts']),
      inventory: inventory,
      items: items,
      equipped: json['eq'] is String ? json['eq'] as String : null,
      potions: _int(json['pot'], defaultPotions),
      ethers: _int(json['eter'], defaultEthers),
      upgrades: up,
      fused: fused,
      materials: mats,
      grid: rawGrid is List
          ? [for (final g in rawGrid) g is String ? g : null]
          : const [],
      lootFilter: json['lf'] is String ? json['lf'] as String : null,
      itemSeq: _int(json['seq']),
      tree: tree,
      treeRefunded: refunded,
      unlockedZone: json['zu'] is num
          ? _int(json['zu'], 1)
          : migratedZone(_int(json['lvl'], 1)),
      ecos: json['ecos'] is List
          ? [
              for (final r in json['ecos'] as List)
                if (EcoItem.fromJson(r) case final e?) e
            ]
          : const [],
      ecosUnlocked: json['eco'] == true,
      mastery: _int(json['ms']),
      ascension: AscensionProgress.fromJson(json['asc']),
    );
  }

  /// `x|0` de JS para números; cualquier otra cosa → [fallback].
  static int _int(Object? v, [int fallback = 0]) =>
      v is num && v.isFinite ? v.truncate() : fallback;

  static List<String> _strings(Object? v) =>
      v is List ? [for (final e in v) if (e is String) e] : const [];
}
