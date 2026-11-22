import 'elements.dart';
import 'upgrade_stat.dart';
import 'weapon.dart';

// Objetos con rareza, afijos y pasivas (loot v2). Ver docs/specs/loot.md.

/// Estadística que toca un modificador (implícito, afijo o mod fijo de
/// un legendario). Los valores son enteros; [scale] dice cuánto vale
/// cada punto al aplicarlo (p. ej. `critChance` 7 → +0.07 de crítico).
enum ModStat {
  atkPct('% ATQ', 0.01),
  magPct('% MAG', 0.01),
  flatAtk('ATQ', 1),
  flatMag('MAG', 1),
  critChance('% crítico', 0.01),
  critMulti('% daño crítico', 0.01),
  speed('velocidad', 0.1),
  burnStacks('Quemadura al aplicar', 1),
  poisonStacks('Veneno al aplicar', 1),
  freezeStacks('Congelación al aplicar', 1),
  ultCharge('% carga de ULT', 0.01),
  vit('VIT', 1),
  esp('ESP', 1),
  agi('AGI', 1),
  fue('FUE', 1),
  des('DES', 1),
  maxHp('vida', 1),
  maxMp('maná', 1),
  defense('DEF', 1),
  healReceived('% curación recibida', 0.01),
  regen('% de vida por turno', 0.01),
  statusResist('stacks de estados recibidos', 1),
  lifeSteal('% de robo de vida', 0.01),
  healPower('% curación', 0.01),

  /// Invocador (docs/specs/summoner.md § 2): daño y duración de las
  /// invocaciones. Solo tomos.
  summonDamage('% daño de invocaciones', 0.01),
  summonTurns('turno de duración de invocaciones', 1),

  /// Afijo Rompedor (combo_balance.md § 5): +% de puntos de quiebre.
  breakPower('% de quiebre', 0.01),

  /// Afijo Quebrantador (combo_balance.md § 5.3): la habilidad principal
  /// del arma (`BreakRules.modSkillOf`) puede quebrar. Valor fijo 1.
  breakSkill('puede quebrar', 1);

  const ModStat(this.label, this.scale);

  final String label;

  /// Valor real de 1 punto.
  final double scale;

  /// Texto del modificador con [value] puntos, p. ej. `+12% ATQ`,
  /// `+0.3 velocidad`, `−1 stacks de estados recibidos`.
  String format(int value) => switch (this) {
        ModStat.atkPct ||
        ModStat.magPct ||
        ModStat.critChance ||
        ModStat.critMulti ||
        ModStat.ultCharge ||
        ModStat.healReceived ||
        ModStat.healPower ||
        ModStat.summonDamage ||
        ModStat.breakPower =>
          '+$value$label',
        ModStat.speed => '+${(value / 10).toStringAsFixed(1)} $label',
        ModStat.burnStacks ||
        ModStat.poisonStacks ||
        ModStat.freezeStacks =>
          '+$value stack${value == 1 ? '' : 's'} de $label',
        ModStat.regen => 'Regenera $value$label',
        ModStat.statusResist => '−$value $label',
        ModStat.lifeSteal => '$value$label',
        ModStat.breakSkill => 'Habilidad principal: $label',
        _ => '+$value $label',
      };

  static ModStat? byName(String name) {
    for (final s in values) {
      if (s.name == name) return s;
    }
    return null;
  }
}

/// Un modificador ya resuelto (estadística + puntos).
class ItemMod {
  final ModStat stat;
  final int value;
  const ItemMod(this.stat, this.value);

  String get text => stat.format(value);

  @override
  bool operator ==(Object other) =>
      other is ItemMod && other.stat == stat && other.value == value;

  @override
  int get hashCode => Object.hash(stat, value);
}

/// Prefijo (ofensivo) o sufijo (atributos / defensa).
enum AffixSlot { prefix, suffix }

/// Un tier de un afijo: desde qué nivel de objeto sale, su rango y su
/// peso dentro del afijo. T1 es el mejor.
class AffixTier {
  final int tier;
  final int minLevel;
  final int min;
  final int max;
  final int weight;
  const AffixTier(this.tier, this.minLevel, this.min, this.max, this.weight);
}

/// Un afijo del pool (`kAffixes`).
class AffixDef {
  final String id;

  /// Nombre corto para los objetos mágicos ("Feroz", "del Oso").
  final String name;
  final AffixSlot slot;
  final ModStat stat;

  /// Tiers de mejor (T1) a peor; cada uno con su nivel mínimo.
  final List<AffixTier> tiers;

  /// Peso de aparición del afijo.
  final int weight;

  /// Tipos de arma donde puede salir; `null` = en todas.
  final Set<String>? types;

  const AffixDef({
    required this.id,
    required this.name,
    required this.slot,
    required this.stat,
    required this.tiers,
    required this.weight,
    this.types,
  });

  bool allows(String weaponType) => types == null || types!.contains(weaponType);

  AffixTier? tier(int t) {
    for (final x in tiers) {
      if (x.tier == t) return x;
    }
    return null;
  }

  /// Tiers que pueden salir en un objeto de nivel [itemLevel].
  List<AffixTier> tiersFor(int itemLevel) =>
      [for (final t in tiers) if (t.minLevel <= itemLevel) t];
}

/// Rareza de un objeto (loot.md § 0.4).
enum Rarity {
  comun('Común', 0, 0, 3, 1.0),
  magico('Mágico', 1, 2, 5, 1.2),
  raro('Raro', 3, 4, 6, 1.5),
  epico('Épico', 5, 6, 8, 2.0),
  legendario('Legendario', 1, 6, 10, 3.0);

  const Rarity(
      this.label, this.minMods, this.maxMods, this.forgeCap, this.costFactor);

  final String label;

  /// Mods al generarse (los legendarios: fijos + 1–2 aleatorios).
  final int minMods;

  /// Cupo total de mods.
  final int maxMods;

  /// Tope de niveles de forja (suma de las mejoras por estadística).
  final int forgeCap;

  /// Multiplicador de los costos de forja y fusión.
  final double costFactor;

  /// Cupo de prefijos (y de sufijos): la mitad del total, redondeado arriba.
  int get affixSideCap => (maxMods + 1) ~/ 2;

  /// Tiene pasiva de arma (aleatoria en Épico, única en Legendario).
  bool get hasPassive => this == epico || this == legendario;

  /// Habilidades trasladadas que puede llevar.
  int get skillSlots => index >= Rarity.epico.index ? 2 : 1;

  static Rarity? byName(String name) {
    for (final r in values) {
      if (r.name == name) return r;
    }
    return null;
  }
}

/// Un afijo tirado en un objeto. `tier` 0 = mod fijo de un legendario.
class AffixRoll {
  final String affixId;
  final int tier;
  final int value;
  const AffixRoll(this.affixId, this.tier, this.value);

  bool get fixed => tier == 0;

  AffixRoll withValue(int v) => AffixRoll(affixId, tier, v);

  List<Object> toJson() => [affixId, tier, value];

  static AffixRoll? fromJson(Object? raw) {
    if (raw is! List || raw.length != 3) return null;
    final id = raw[0], t = raw[1], v = raw[2];
    if (id is! String || t is! num || v is! num) return null;
    return AffixRoll(id, t.toInt(), v.toInt());
  }

  @override
  bool operator ==(Object other) =>
      other is AffixRoll &&
      other.affixId == affixId &&
      other.tier == tier &&
      other.value == value;

  @override
  int get hashCode => Object.hash(affixId, tier, value);
}

/// Operaciones de la forja y la mesa de fusión (`CraftRules`, loot.md
/// § 0.7, § 5, § 16).
enum CraftOp {
  /// Trasladar un afijo de un arma (que se destruye) a otra.
  transferAffix,

  /// Trasladar la pasiva de un arma (que se destruye) a otra.
  transferPassive,

  /// Trasladar una habilidad de un arma (que se destruye) a otra.
  transferSkill,

  /// Quitar un afijo.
  removeAffix,

  /// Agregar un afijo aleatorio (Cristal de Era).
  addAffix,

  /// Volver a tirar los valores de los afijos (Esquirla del Eco).
  reroll,

  /// Subir la rareza un nivel (Prisma Roto).
  upgradeRarity,

  /// Desarmar un arma (se destruye) en materiales (loot.md § 21.1).
  salvage,

  /// Vender un arma (se destruye) por créditos (loot.md § 21.2).
  sell,

  /// Cambiar la base de un arma conservando rareza, mods, pasiva y forja
  /// (loot.md § 21.3). `sourceUid` = id de la base nueva.
  reforge,

  /// Desarmar todas las armas de una rareza (`index` = `Rarity.index`)
  /// que no estén equipadas ni protegidas.
  salvageAll,

  /// Vender todas las armas de una rareza (`index` = `Rarity.index`).
  sellAll,

  /// Desarmar las armas elegidas a mano (`CraftAction.uids`, v0.5.1).
  salvageSelected,

  /// Vender las armas elegidas a mano (`CraftAction.uids`, v0.5.1).
  sellSelected,

  /// Esencia del Abismo (v0.8): re-tira con ventaja los mods fijos de un
  /// legendario (docs/specs/abyss_bosses.md § 3.1).
  essence,

  /// Condensar materiales bajos en uno alto (v0.15,
  /// materials_economy.md § 4.3): `targetUid` = nombre del material que
  /// se obtiene (`cristal` / `prisma`), `index` = cuántos. Sin azar.
  condense,

  /// Restaurar el Quebrar propio de un arma que lo reemplazó por fusión
  /// (v0.20.12, loot.md § 16.3.1). `replaceSkillId` = trasladada que se
  /// pierde si sobran (cupos llenos). Protocolo Mundo 33.
  restoreQuebrar;

  /// Destruye el arma (o las armas) en vez de cambiarla.
  bool get destroys =>
      this == salvage ||
      this == sell ||
      this == salvageAll ||
      this == sellAll ||
      isSelection;

  /// Opera sobre varias armas a la vez (`targetUid` se ignora).
  bool get isBatch => this == salvageAll || this == sellAll || isSelection;

  /// Opera sobre la lista de `uid` elegidos (`CraftAction.uids`).
  bool get isSelection => this == salvageSelected || this == sellSelected;

  /// Da créditos (vender) en vez de materiales.
  bool get sells => this == sell || this == sellAll || this == sellSelected;
}

/// Mod fijo de un legendario: afijo del pool con un rango propio.
class UniqueMod {
  final String affixId;
  final int min;
  final int max;
  const UniqueMod(this.affixId, this.min, this.max);
}

/// Un legendario diseñado a mano (`kUniques`, loot.md § 11): base, mods
/// fijos, 1–2 mods aleatorios y pasiva única.
class UniqueDef {
  final String id;
  final String name;
  final String baseId;
  final List<UniqueMod> fixed;
  final int randomMin;
  final int randomMax;

  /// Pasiva única (`kWeaponPassives`, `unique: true`).
  final String passiveId;

  /// Texto de ambientación.
  final String flavor;

  const UniqueDef({
    required this.id,
    required this.name,
    required this.baseId,
    required this.fixed,
    required this.passiveId,
    this.randomMin = 1,
    this.randomMax = 2,
    this.flavor = '',
    this.exclusive = false,
    this.ultId,
  });

  /// ULT propia fija del legendario (`kBranchUltSkills`), reemplaza la del
  /// tipo de arma (docs/specs/branch_ults.md). `null` = la del tipo.
  final String? ultId;

  /// Exclusivo de un Jefe del Abismo (v0.8): nunca sale del pool normal
  /// (docs/specs/abyss_bosses.md § 3).
  final bool exclusive;
}

/// Material de crafteo (loot.md § 5). Se apila hasta [maxStack].
enum CraftMaterial {
  esquirla('Esquirla del Eco', 'Vuelve a tirar los valores de los afijos.'),
  cristal('Cristal de Era', 'Agrega un afijo si hay lugar.'),
  prisma('Prisma Roto', 'Sube la rareza del arma un nivel (hasta Épico).'),

  /// Solo cae dentro de los Ecos (docs/specs/ecos_atlas.md § 3).
  ancla('Ancla Temporal', 'Sube el tier de un Eco en 1 (hasta 16).'),

  // ---- Jefes del Abismo v0.8 (docs/specs/abyss_bosses.md § 1) ----

  /// Fragmentos: caen en Ecos de tier 10+; 5 abren su Jefe del Abismo.
  fragReloj('Fragmento del Reloj',
      'Caen en Ecos de tier 10+. 5 abren al Gólem Reloj del Abismo.'),
  fragEco('Fragmento del Eco',
      'Caen en Ecos de tier 10+. 5 abren a la Hechicera del Eco del Abismo.'),
  fragCorona('Fragmento de la Corona',
      'Caen en Ecos de tier 10+. 5 abren al Espectro Coronado del Abismo.'),
  fragEras('Fragmento de las Eras',
      'Caen en Ecos de tier 10+. 5 abren al Devorador de Eras del Abismo.'),

  /// Cae de los Jefes del Abismo: re-tira con ventaja los mods fijos de
  /// un legendario (`CraftOp.essence`).
  esencia('Esencia del Abismo',
      'Re-tira con ventaja los mods fijos de un legendario (nunca bajan).');

  const CraftMaterial(this.label, this.description);
  final String label;
  final String description;

  /// Fragmento de un Jefe del Abismo.
  bool get isFragment =>
      this == fragReloj ||
      this == fragEco ||
      this == fragCorona ||
      this == fragEras;

  static const maxStack = 99;

  static CraftMaterial? byName(String name) {
    for (final m in values) {
      if (m.name == name) return m;
    }
    return null;
  }
}

/// Una instancia concreta de un arma (base + rareza + afijos + pasiva +
/// forja + habilidades trasladadas). Inmutable.
class ItemInstance {
  const ItemInstance({
    required this.uid,
    required this.baseId,
    this.rarity = Rarity.comun,
    this.itemLevel = 1,
    this.affixes = const [],
    this.passiveId,
    this.passiveLevel = 1,
    this.forge = const WeaponUpgradeLevels(),
    this.extraSkills = const [],
    this.quebrarReplaced = false,
    this.uniqueId,
    this.name,
    this.ultId,
    this.element,
  });

  /// Común sin nada: lo que era un id de arma en el inventario viejo.
  factory ItemInstance.common(String uid, String baseId,
          {int itemLevel = 1,
          WeaponUpgradeLevels forge = const WeaponUpgradeLevels(),
          List<String> extraSkills = const []}) =>
      ItemInstance(
          uid: uid,
          baseId: baseId,
          itemLevel: itemLevel,
          forge: forge,
          extraSkills: extraSkills);

  /// Id único dentro del perfil (los migrados usan el id de la base).
  final String uid;
  final String baseId;
  final Rarity rarity;
  final int itemLevel;
  final List<AffixRoll> affixes;

  /// Pasiva de arma (`kWeaponPassives`) y su nivel base (1–5). El nivel
  /// efectivo suma 1 cada 2 niveles de forja ([effectivePassiveLevel]).
  final String? passiveId;
  final int passiveLevel;

  /// Niveles de forja por estadística.
  final WeaponUpgradeLevels forge;

  /// Habilidades trasladadas por fusión (además de las de la base).
  final List<String> extraSkills;

  /// Ranura base de Quebrar (loot.md § 16.3): `false` = el arma trae
  /// Quebrar (o Quebrar arcano); `true` = el jugador la reemplazó por una
  /// habilidad trasladada, que ocupa esa ranura (un cupo más en
  /// [extraSkills]). JSON `nq`; sin el campo, el arma tiene Quebrar.
  final bool quebrarReplaced;

  /// Cupo de habilidades trasladadas: el de la rareza, +1 si la ranura de
  /// Quebrar quedó ocupada por una trasladada.
  int get skillCapacity => rarity.skillSlots + (quebrarReplaced ? 1 : 0);

  /// Legendario: id de `kUniques`.
  final String? uniqueId;

  /// Nombre generado (raros y épicos).
  final String? name;

  /// Mod especial "ULT: <nombre>" (docs/specs/branch_ults.md): una ULT de
  /// camino (`kBranchUltSkills`) que reemplaza la del tipo de arma. Es
  /// del objeto: no se traslada por fusión.
  final String? ultId;

  /// Elemento de base del arma (weapon_identity.md § 4): pasiva fija que
  /// no se puede quitar (la fusión y el condensado no la mueven). `null`
  /// = sin elemento. Los legendarios lo derivan de su único
  /// (`weaponElementOf`). JSON `el`.
  final GameElement? element;

  static const maxPassiveLevel = 5;

  int get forgeLevel => forge.total;

  int get effectivePassiveLevel =>
      (passiveLevel + forgeLevel ~/ 2).clamp(1, maxPassiveLevel);

  int get modCount => affixes.length;

  ItemInstance copyWith({
    String? uid,
    String? baseId,
    Rarity? rarity,
    int? itemLevel,
    List<AffixRoll>? affixes,
    String? passiveId,
    bool clearPassive = false,
    int? passiveLevel,
    WeaponUpgradeLevels? forge,
    List<String>? extraSkills,
    bool? quebrarReplaced,
    String? name,
    String? ultId,
    bool clearUlt = false,
    GameElement? element,
    bool clearElement = false,
  }) =>
      ItemInstance(
        uid: uid ?? this.uid,
        baseId: baseId ?? this.baseId,
        rarity: rarity ?? this.rarity,
        itemLevel: itemLevel ?? this.itemLevel,
        affixes: affixes ?? this.affixes,
        passiveId: clearPassive ? null : passiveId ?? this.passiveId,
        passiveLevel: passiveLevel ?? this.passiveLevel,
        forge: forge ?? this.forge,
        extraSkills: extraSkills ?? this.extraSkills,
        quebrarReplaced: quebrarReplaced ?? this.quebrarReplaced,
        uniqueId: uniqueId,
        name: name ?? this.name,
        ultId: clearUlt ? null : ultId ?? this.ultId,
        element: clearElement ? null : element ?? this.element,
      );

  // ------------------------------------------------------------------
  // JSON compacto (perfil y red)
  // ------------------------------------------------------------------

  Map<String, Object?> toJson() => {
        'u': uid,
        'b': baseId,
        if (rarity != Rarity.comun) 'r': rarity.name,
        if (itemLevel != 1) 'il': itemLevel,
        if (affixes.isNotEmpty) 'a': [for (final a in affixes) a.toJson()],
        if (passiveId != null) 'p': passiveId,
        if (passiveId != null && passiveLevel != 1) 'pl': passiveLevel,
        if (forge.total > 0) 'f': forge.toJson(),
        if (extraSkills.isNotEmpty) 's': extraSkills,
        if (quebrarReplaced) 'nq': 1,
        if (uniqueId != null) 'q': uniqueId,
        if (name != null) 'n': name,
        if (ultId != null) 'ul': ultId,
        if (element != null) 'el': element!.name,
      };

  /// Lectura tolerante: `null` si falta lo esencial (uid y base). No
  /// valida contra los catálogos (eso es `ItemRules.sanitize`).
  static ItemInstance? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final uid = raw['u'], base = raw['b'];
    if (uid is! String || base is! String || uid.isEmpty) return null;
    var forge = const WeaponUpgradeLevels();
    final f = raw['f'];
    if (f is Map) {
      f.forEach((k, v) {
        final s = k is String ? UpgradeStat.fromKey(k) : null;
        if (s != null && v is num) forge = forge.withLevel(s, v.toInt());
      });
    }
    final a = raw['a'];
    final s = raw['s'];
    final il = raw['il'], pl = raw['pl'];
    return ItemInstance(
      uid: uid,
      baseId: base,
      rarity: raw['r'] is String
          ? Rarity.byName(raw['r'] as String) ?? Rarity.comun
          : Rarity.comun,
      itemLevel: il is num ? il.toInt() : 1,
      affixes: a is List
          ? [
              for (final x in a)
                if (AffixRoll.fromJson(x) case final r?) r
            ]
          : const [],
      passiveId: raw['p'] is String ? raw['p'] as String : null,
      passiveLevel: pl is num ? pl.toInt() : 1,
      forge: forge,
      extraSkills: s is List ? [for (final x in s) if (x is String) x] : const [],
      quebrarReplaced: raw['nq'] == 1 || raw['nq'] == true,
      uniqueId: raw['q'] is String ? raw['q'] as String : null,
      name: raw['n'] is String ? raw['n'] as String : null,
      ultId: raw['ul'] is String ? raw['ul'] as String : null,
      element: _elementByName(raw['el']),
    );
  }

  static GameElement? _elementByName(Object? n) {
    if (n is! String) return null;
    for (final e in GameElement.values) {
      if (e.name == n && e != GameElement.fisico) return e;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is ItemInstance &&
      other.uid == uid &&
      other.baseId == baseId &&
      other.rarity == rarity &&
      other.itemLevel == itemLevel &&
      _listEq(other.affixes, affixes) &&
      other.passiveId == passiveId &&
      other.passiveLevel == passiveLevel &&
      other.forge.pow == forge.pow &&
      other.forge.crit == forge.crit &&
      other.forge.spd == forge.spd &&
      other.forge.def == forge.def &&
      _listEq(other.extraSkills, extraSkills) &&
      other.quebrarReplaced == quebrarReplaced &&
      other.uniqueId == uniqueId &&
      other.name == name &&
      other.ultId == ultId &&
      other.element == element;

  @override
  int get hashCode => Object.hash(uid, baseId, rarity, itemLevel,
      Object.hashAll(affixes), passiveId, passiveLevel, forge.total, uniqueId);

  static bool _listEq<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
