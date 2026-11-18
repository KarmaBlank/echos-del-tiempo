import 'item.dart';

// Ecos: mapas de endgame que caen como loot. Ver docs/specs/ecos_atlas.md.

/// Un modificador de dificultad de un Eco (`kEcoMods`, § 2.1).
class EcoModDef {
  const EcoModDef({
    required this.id,
    required this.name,
    required this.min,
    required this.max,
    required this.quantity,
    required this.rarity,
  });

  final String id;

  /// Texto con `X` donde va el valor (`Enemigos con +X% de vida`).
  final String name;
  final int min;
  final int max;

  /// +% cantidad y +% rareza de loot que suma.
  final int quantity;
  final int rarity;

  /// Sin valor (p. ej. `sequia`).
  bool get flag => min == max;

  String text(int value) => name.replaceAll('X', '$value');
}

/// Un mod tirado en un Eco.
class EcoModRoll {
  const EcoModRoll(this.id, this.value);

  final String id;
  final int value;

  List<Object> toJson() => [id, value];

  static EcoModRoll? fromJson(Object? raw) {
    if (raw is! List || raw.length != 2) return null;
    final id = raw[0], v = raw[1];
    if (id is! String || v is! num) return null;
    return EcoModRoll(id, v.toInt());
  }

  @override
  bool operator ==(Object other) =>
      other is EcoModRoll && other.id == id && other.value == value;

  @override
  int get hashCode => Object.hash(id, value);
}

/// Un Eco en el inventario (§ 2). Inmutable.
class EcoItem {
  const EcoItem({
    required this.uid,
    required this.tier,
    required this.zone,
    required this.boss,
    this.rarity = Rarity.comun,
    this.mods = const [],
    this.floors = 1,
    this.seed = 0,
    this.name,
  });

  static const minTier = 1;
  static const maxTier = 16;
  static const maxFloors = 3;

  final String uid;

  /// 1–16.
  final int tier;

  /// Tipo de zona (1–10): generador, tema, enemigos y música.
  final int zone;

  /// Zona del jefe del final (1–10).
  final int boss;
  final Rarity rarity;
  final List<EcoModRoll> mods;

  /// 1–3.
  final int floors;

  /// Semilla del mapa (mismo Eco → misma mazmorra).
  final int seed;

  /// Nombre generado (raros o mejores).
  final String? name;

  /// Nivel de los monstruos: `48 + 2 × tier` (T1 = 50 … T16 = 80).
  int get monsterLevel => monsterLevelFor(tier);

  static int monsterLevelFor(int tier) => 48 + 2 * tier.clamp(minTier, maxTier);

  /// Clave de "primera vez" del Atlas.
  String get tierKey => 't$tier';
  String get zoneKey => 'z$zone';
  String get bossKey => 'b$boss';

  bool hasMod(String id) => mods.any((m) => m.id == id);

  int modValue(String id) {
    for (final m in mods) {
      if (m.id == id) return m.value;
    }
    return 0;
  }

  EcoItem copyWith({
    String? uid,
    int? tier,
    int? zone,
    int? boss,
    Rarity? rarity,
    List<EcoModRoll>? mods,
    int? floors,
    int? seed,
    String? name,
  }) =>
      EcoItem(
        uid: uid ?? this.uid,
        tier: tier ?? this.tier,
        zone: zone ?? this.zone,
        boss: boss ?? this.boss,
        rarity: rarity ?? this.rarity,
        mods: mods ?? this.mods,
        floors: floors ?? this.floors,
        seed: seed ?? this.seed,
        name: name ?? this.name,
      );

  Map<String, Object?> toJson() => {
        'u': uid,
        't': tier,
        'z': zone,
        'b': boss,
        if (rarity != Rarity.comun) 'r': rarity.name,
        if (mods.isNotEmpty) 'm': [for (final m in mods) m.toJson()],
        'f': floors,
        's': seed,
        if (name != null) 'n': name,
      };

  /// Lectura tolerante: `null` si falta lo esencial. Recorta tier, zona,
  /// jefe y pisos a sus rangos; los mods se validan con `EcoRules.sanitize`.
  static EcoItem? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final uid = raw['u'], t = raw['t'], z = raw['z'], b = raw['b'];
    if (uid is! String || uid.isEmpty || t is! num || z is! num || b is! num) {
      return null;
    }
    final m = raw['m'], f = raw['f'], s = raw['s'];
    return EcoItem(
      uid: uid,
      tier: t.toInt().clamp(minTier, maxTier),
      zone: z.toInt().clamp(1, 10),
      boss: b.toInt().clamp(1, 10),
      rarity: raw['r'] is String
          ? Rarity.byName(raw['r'] as String) ?? Rarity.comun
          : Rarity.comun,
      mods: m is List
          ? [
              for (final x in m)
                if (EcoModRoll.fromJson(x) case final r?) r
            ]
          : const [],
      floors: f is num ? f.toInt().clamp(1, maxFloors) : 1,
      seed: s is num ? s.toInt() : 0,
      name: raw['n'] is String ? raw['n'] as String : null,
    );
  }

  @override
  bool operator ==(Object other) {
    if (other is! EcoItem ||
        other.uid != uid ||
        other.tier != tier ||
        other.zone != zone ||
        other.boss != boss ||
        other.rarity != rarity ||
        other.floors != floors ||
        other.seed != seed ||
        other.name != name ||
        other.mods.length != mods.length) {
      return false;
    }
    for (var i = 0; i < mods.length; i++) {
      if (other.mods[i] != mods[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
      uid, tier, zone, boss, rarity, Object.hashAll(mods), floors, seed, name);
}

/// Operaciones de crafteo de un Eco (ecos_atlas.md § 4.1).
enum EcoCraftOp {
  /// Esquirla del Eco: vuelve a tirar los mods.
  reroll,

  /// Cristal de Era: agrega un mod.
  addMod,

  /// Prisma Roto: sube la rareza (hasta Épico).
  rarity,

  /// Ancla Temporal: tier +1.
  tier;

  static EcoCraftOp? byName(String n) {
    for (final o in values) {
      if (o.name == n) return o;
    }
    return null;
  }
}
