import '../data/passive_tree_catalog.dart';
import 'attributes.dart';
import 'passive_tree.dart';
import 'upgrade_stat.dart';
import 'weapon.dart';

/// Progreso persistente de un jugador: lo que el prototipo guardaba en
/// `localStorage` (`saveProfile`) y mandaba al host en `hello`.
/// Inmutable: las reglas de `ProgressionRules` devuelven perfiles nuevos.
/// Ver docs/specs/progression.md § "Perfil persistente".
class PlayerProfile {
  PlayerProfile({
    this.name = '',
    this.classId = 'guerrero',
    this.level = 1,
    this.xp = 0,
    this.credits = 0,
    PlayerAttributes? attributes,
    this.points = 0,
    List<String> inventory = const [],
    this.equipped,
    this.potions = defaultPotions,
    this.ethers = defaultEthers,
    Map<String, WeaponUpgradeLevels> upgrades = const {},
    Map<String, String> fused = const {},
    List<String> tree = const [],
    this.treeRefunded = 0,
  })  : attributes = attributes ?? const PlayerAttributes({}),
        inventory = List.unmodifiable(inventory),
        upgrades = Map.unmodifiable(upgrades),
        fused = Map.unmodifiable(fused),
        tree = List.unmodifiable(tree);

  /// Pociones con las que arranca un perfil nuevo (`d.pot ?? 3`, `d.eter ?? 1`).
  static const defaultPotions = 3;
  static const defaultEthers = 1;

  final String name;
  final String classId;
  final int level;
  final int xp;
  final int credits;
  final PlayerAttributes attributes;

  /// Puntos de atributo sin repartir (`pts`).
  final int points;

  /// Armas que tiene (`inv`), en orden de obtención.
  final List<String> inventory;

  /// Arma equipada (`eq`). `null` solo antes de `ProgressionRules.normalize`.
  final String? equipped;
  final int potions;
  final int ethers;

  /// Mejoras por arma (`up`).
  final Map<String, WeaponUpgradeLevels> upgrades;

  /// Habilidad fusionada por arma (`fuse`).
  final Map<String, String> fused;

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

  WeaponUpgradeLevels upgradesFor(String weaponId) =>
      upgrades[weaponId] ?? const WeaponUpgradeLevels();

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
    List<String>? tree,
  }) =>
      PlayerProfile(
        name: name ?? this.name,
        classId: classId ?? this.classId,
        level: level ?? this.level,
        xp: xp ?? this.xp,
        credits: credits ?? this.credits,
        attributes: attributes ?? this.attributes,
        points: points ?? this.points,
        inventory: inventory ?? this.inventory,
        equipped: equipped ?? this.equipped,
        potions: potions ?? this.potions,
        ethers: ethers ?? this.ethers,
        upgrades: upgrades ?? this.upgrades,
        fused: fused ?? this.fused,
        tree: tree ?? this.tree,
      );

  // ------------------------------------------------------------------
  // JSON (mismas claves que el prototipo)
  // ------------------------------------------------------------------

  static String attributeKey(Attribute a) => a.name.toUpperCase();

  Map<String, Object?> toJson() => {
        'name': name,
        'cls': classId,
        'lvl': level,
        'xp': xp,
        'cr': credits,
        'st': {
          for (final a in Attribute.values) attributeKey(a): attributes[a],
        },
        'pts': points,
        'inv': inventory,
        'eq': equipped,
        'pot': potions,
        'eter': ethers,
        'up': {
          for (final e in upgrades.entries)
            if (e.value.total > 0) e.key: e.value.toJson(),
        },
        'fuse': fused,
        'tree': tree,
        'tv': treeVersion,
        if (treeRefunded > 0) 'tvRef': treeRefunded,
      };

  /// Lectura tolerante: lo que falta o tiene otro tipo toma su valor por
  /// defecto. No valida contra los catálogos: eso lo hace
  /// `ProgressionRules.normalize` (como `addPlayer` en el prototipo).
  factory PlayerProfile.fromJson(Map<String, Object?> json) {
    final st = json['st'];
    final attrs = <Attribute, int>{};
    if (st is Map) {
      for (final a in Attribute.values) {
        attrs[a] = _int(st[attributeKey(a)]);
      }
    }
    final up = <String, WeaponUpgradeLevels>{};
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
    final fused = <String, String>{};
    final rawFuse = json['fuse'];
    if (rawFuse is Map) {
      rawFuse.forEach((k, v) {
        if (k is String && v is String) fused[k] = v;
      });
    }
    // Árbol de otra versión: se reinicia gratis (passive_tree_v2.md § 6).
    var tree = _strings(json['tree']);
    var refunded = _int(json['tvRef']);
    if (_int(json['tv'], 1) < treeVersion && tree.isNotEmpty) {
      refunded += tree.length;
      tree = const [];
    }
    return PlayerProfile(
      name: json['name'] is String ? json['name'] as String : '',
      classId: json['cls'] is String ? json['cls'] as String : 'guerrero',
      level: _int(json['lvl'], 1),
      xp: _int(json['xp']),
      credits: _int(json['cr']),
      attributes: st is Map ? PlayerAttributes(Map.unmodifiable(attrs)) : null,
      points: _int(json['pts']),
      inventory: _strings(json['inv']),
      equipped: json['eq'] is String ? json['eq'] as String : null,
      potions: _int(json['pot'], defaultPotions),
      ethers: _int(json['eter'], defaultEthers),
      upgrades: up,
      fused: fused,
      tree: tree,
      treeRefunded: refunded,
    );
  }

  /// `x|0` de JS para números; cualquier otra cosa → [fallback].
  static int _int(Object? v, [int fallback = 0]) =>
      v is num && v.isFinite ? v.truncate() : fallback;

  static List<String> _strings(Object? v) =>
      v is List ? [for (final e in v) if (e is String) e] : const [];
}
