import 'dart:math' as math;

import '../data/tuning_catalog.dart';
import '../data/branch_ults_catalog.dart';
import '../data/ults_v2_catalog.dart' show ultV2ModsForType;

import '../data/affixes_catalog.dart';
import '../data/game_catalog.dart';
import '../data/uniques_catalog.dart';
import '../data/weapon_passives.dart';
import '../models/item.dart';
import '../models/loot.dart';
import '../models/mission_def.dart';
import '../models/weapon.dart';
import 'battle_engine.dart' show RandomSource;
import 'item_rules.dart';

/// Generación de loot (loot.md § 2, § 4, § 6, § 14): rareza, base,
/// afijos, pasiva, legendarios, materiales y drops por fuente.
/// Determinística con la [RandomSource] que se le pasa; sin bucles de
/// rechazo (cada elección saca de un pool ya filtrado).
class LootRules {
  const LootRules({this.items = const ItemRules()});

  final ItemRules items;

  GameCatalog get catalog => items.catalog;

  /// Uid provisorio de lo generado: el perfil asigna el real al recibirlo.
  static const newUid = 'nuevo';

  // ------------------------------------------------------------------
  // Nivel de zona y de objeto
  // ------------------------------------------------------------------

  static const maxLevel = ItemRules.maxItemLevel;

  /// Nivel de zona mientras no exista el mundo nuevo (worldgen.md): el
  /// mayor entre el nivel de la misión (recomendado + rango: C 0, B 1,
  /// A 2) y el promedio del grupo. Gancho: `SessionEngine` lo usa para
  /// todo el loot; el mundo nuevo pasará el nivel de su zona.
  static int zoneLevel(MissionDef m, Iterable<int> partyLevels) {
    final rank = switch (m.rank) {
      'A' => 2,
      'B' => 1,
      _ => 0,
    };
    final base = m.recommendedLevel + rank;
    final list = partyLevels.toList();
    final party = list.isEmpty
        ? 1
        : (list.fold(0, (a, b) => a + b) / list.length).round();
    return math.max(base, party).clamp(1, maxLevel);
  }

  /// Nivel de objeto: el de la zona, +1 élites y fin de misión, +2 jefes,
  /// nunca por encima de [cap], el nivel tope de la zona
  /// (combo_balance.md § 2: el loot no se adelanta a la zona).
  static int itemLevelFor(int zoneLevel, LootSource source, {int? cap}) {
    final il = zoneLevel +
        switch (source) {
          LootSource.elite || LootSource.mission => 1,
          LootSource.boss => 2,
          _ => 0,
        };
    return (cap == null ? il : math.min(il, cap)).clamp(1, maxLevel);
  }

  // ------------------------------------------------------------------
  // Rareza
  // ------------------------------------------------------------------

  /// Peso base (Común 60, Mágico 27, Raro 10, Épico 2.7, Legendario
  /// 0.3). Es el de los Ecos; en zonas el Épico pesa [zoneEpicWeight]
  /// (materials_economy.md § 4.1).
  static Map<Rarity, double> get baseRarityWeights {
    final t = tuning(TuningId.materials);
    return {
      Rarity.comun: t.d('weightComun'),
      Rarity.magico: t.d('weightMagico'),
      Rarity.raro: t.d('weightRaro'),
      Rarity.epico: t.d('weightEpico'),
      Rarity.legendario: t.d('weightLegendario'),
    };
  }

  /// Peso base del Épico fuera de un Eco (campaña, cofres, misiones):
  /// 1.5 en vez de 2.7, para que el Épico crafteado valga
  /// (materials_economy.md § 4.1).
  static double get zoneEpicWeight => tuning(TuningId.materials).d('zoneEpicWeight');

  /// Cuánto multiplica el bonus de rareza a cada rareza (`× (1 + k·b)`).
  static const rarityBonusScale = {
    Rarity.comun: 0.0,
    Rarity.magico: 0.5,
    Rarity.raro: 1.0,
    Rarity.epico: 1.5,
    Rarity.legendario: 2.0,
  };

  /// Bonus de rareza de la fuente.
  static double sourceBonus(LootSource s) => switch (s) {
        LootSource.battle => 0,
        LootSource.chest => 0.5,
        LootSource.elite => 1.0,
        LootSource.mission => 1.0,
        LootSource.boss => 2.0,
      };

  /// Bonus de rareza por nivel de zona: 0 en el 1, +0.5 en el 50.
  static double zoneBonus(int zoneLevel) =>
      (zoneLevel.clamp(1, maxLevel) - 1) / (maxLevel - 1) * 0.5;

  /// Probabilidades normalizadas de cada rareza.
  /// [legendaryMult] multiplica el peso del Legendario (Atlas: Fortuna
  /// de Eras, ecos_atlas.md § 5.3). [eco] = dentro de un Eco (peso de
  /// Épico de [baseRarityWeights]; si no, [zoneEpicWeight]).
  static Map<Rarity, double> rarityOdds(int zoneLevel, LootSource source,
      {double extraBonus = 0, double legendaryMult = 1, bool eco = false}) {
    final b = zoneBonus(zoneLevel) + sourceBonus(source) + extraBonus;
    final w = {
      for (final r in Rarity.values)
        r: (r == Rarity.epico && !eco
                ? zoneEpicWeight
                : baseRarityWeights[r]!) *
            (1 + rarityBonusScale[r]! * b) *
            (r == Rarity.legendario ? legendaryMult : 1),
    };
    final total = w.values.fold(0.0, (a, x) => a + x);
    return {for (final e in w.entries) e.key: e.value / total};
  }

  Rarity rollRarity(RandomSource rng, int zoneLevel, LootSource source,
      {double extraBonus = 0, double legendaryMult = 1, bool eco = false}) {
    final odds = rarityOdds(zoneLevel, source,
        extraBonus: extraBonus, legendaryMult: legendaryMult, eco: eco);
    var r = rng();
    for (final e in odds.entries) {
      if (r < e.value) return e.key;
      r -= e.value;
    }
    return Rarity.legendario;
  }

  // ------------------------------------------------------------------
  // Elecciones con peso
  // ------------------------------------------------------------------

  static T? pickWeighted<T>(
      RandomSource rng, List<T> list, double Function(T) weight) {
    if (list.isEmpty) return null;
    final total = list.fold(0.0, (a, x) => a + weight(x));
    var r = rng() * total;
    for (final x in list) {
      r -= weight(x);
      if (r < 0) return x;
    }
    return list.last;
  }

  /// Base con nivel ≤ [itemLevel]: las de los últimos 10 niveles pesan
  /// ×3 y las de la [family] del jugador ×2.
  WeaponDef pickBase(RandomSource rng, int itemLevel, {String? family}) {
    final pool = [
      for (final w in catalog.weapons.values)
        if (w.level <= itemLevel) w,
    ];
    return pickWeighted(
        rng,
        pool,
        (w) =>
            (w.level >= itemLevel - 10 ? 3.0 : 1.0) *
            (family != null && w.family == family ? 2.0 : 1.0))!;
  }

  /// Legendario que puede salir a [itemLevel] (base de nivel ≤), con
  /// las de la [family] ×2. `null` si no hay ninguno.
  UniqueDef? pickUnique(RandomSource rng, int itemLevel, {String? family}) {
    final pool = [
      for (final u in kUniques.values)
        // Los exclusivos del Abismo nunca salen del pool (v0.8).
        if (!u.exclusive &&
            (catalog.weapons[u.baseId]?.level ?? 99) <= itemLevel)
          u,
    ];
    return pickWeighted(
        rng,
        pool,
        (u) =>
            family != null && catalog.weapons[u.baseId]?.family == family
                ? 2.0
                : 1.0);
  }

  static int rollValue(RandomSource rng, int min, int max) =>
      min + (rng() * (max - min + 1)).floor().clamp(0, max - min);

  /// Un afijo nuevo para [i] (tipo, cupo, lado y nivel), o `null` si no
  /// entra ninguno.
  AffixRoll? rollAffix(RandomSource rng, ItemInstance i) {
    final cands = items.candidateAffixes(i);
    final a = pickWeighted(rng, cands, (x) => x.weight.toDouble());
    if (a == null) return null;
    final t = pickWeighted(
        rng, a.tiersFor(i.itemLevel), (x) => x.weight.toDouble())!;
    return AffixRoll(a.id, t.tier, rollValue(rng, t.min, t.max));
  }

  ItemInstance addRandomAffixes(RandomSource rng, ItemInstance i, int n) {
    var out = i;
    for (var k = 0; k < n; k++) {
      final a = rollAffix(rng, out);
      if (a == null) break;
      out = out.copyWith(affixes: [...out.affixes, a]);
    }
    return out;
  }

  /// Pasiva aleatoria del pool del tipo de arma (Épicos).
  String? rollPassiveId(RandomSource rng, String weaponType) =>
      pickWeighted(rng, weaponPassivePool(weaponType), (_) => 1.0)?.id;

  static const _rareA = [
    'Aullido', 'Ceniza', 'Eco', 'Ruina', 'Alba', 'Tormenta', 'Sombra',
    'Escarcha', 'Ocaso', 'Furia', 'Vigilia', 'Lamento', 'Hambre', 'Destino',
    'Brasa', 'Grieta', 'Marea', 'Espina',
  ];
  static const _rareB = [
    'Errante', 'Quebrado', 'Eterno', 'Silente', 'Voraz', 'Carmesí',
    'Antiguo', 'Sagrado', 'Maldito', 'Abismal', 'Dorado', 'Helado', 'Sin Fin',
    'Feroz', 'Lejano', 'Oculto',
  ];

  /// Nombre de un Raro / Épico ("Eco Voraz").
  static String rareName(RandomSource rng) =>
      '${_rareA[(rng() * _rareA.length).floor().clamp(0, _rareA.length - 1)]} '
      '${_rareB[(rng() * _rareB.length).floor().clamp(0, _rareB.length - 1)]}';

  /// Mods aleatorios al generar: Mágico 1–2, Raro 3–4, Épico 5–6.
  static int rollModCount(RandomSource rng, Rarity r) => switch (r) {
        Rarity.comun => 0,
        Rarity.legendario => 0,
        _ => r.minMods + (rng() * 2).floor().clamp(0, 1),
      };

  // ------------------------------------------------------------------
  // Generación
  // ------------------------------------------------------------------

  /// Un arma nueva. Sin [rarity] la tira (con [source] y la zona =
  /// [itemLevel]); sin [baseId] elige una base. Un Legendario sin único
  /// disponible sale Épico.
  ItemInstance generate(
    RandomSource rng, {
    required int itemLevel,
    Rarity? rarity,
    String? baseId,
    String? family,
    LootSource source = LootSource.battle,
    double extraBonus = 0,
    double legendaryMult = 1,
    bool eco = false,
    String uid = newUid,
  }) {
    final il = itemLevel.clamp(1, maxLevel);
    var r = rarity ??
        rollRarity(rng, il, source,
            extraBonus: extraBonus, legendaryMult: legendaryMult, eco: eco);
    if (r == Rarity.legendario && baseId == null) {
      final u = pickUnique(rng, il, family: family);
      if (u != null) return generateUnique(rng, u, il, uid: uid);
      r = Rarity.epico;
    }
    if (r == Rarity.legendario) r = Rarity.epico;
    final w = baseId != null
        ? catalog.weapons[baseId]!
        : pickBase(rng, il, family: family);
    var item = ItemInstance(uid: uid, baseId: w.id, rarity: r, itemLevel: il);
    item = addRandomAffixes(rng, item, rollModCount(rng, r));
    if (r == Rarity.raro || r == Rarity.epico) {
      item = item.copyWith(name: rareName(rng));
    }
    if (r == Rarity.epico) {
      item = item.copyWith(passiveId: rollPassiveId(rng, w.type));
    }
    if (rollUltMod(rng, r, w.type) case final u?) {
      item = item.copyWith(ultId: u);
    }
    return item;
  }

  /// Mod especial "ULT: <nombre>" (docs/specs/branch_ults.md): Raro 8%,
  /// Épico 20%. Desde v0.17 (ultimates_v2.md § 6, respuesta 1) el pool
  /// son las ULT v2 de mod del tipo [type]; las de camino ya no caen.
  /// `null` = no sale.
  String? rollUltMod(RandomSource rng, Rarity r, String type) {
    final chance = switch (r) {
      Rarity.raro => kBranchUltChanceRare,
      Rarity.epico => kBranchUltChanceEpic,
      _ => 0.0,
    };
    if (chance <= 0 || rng() >= chance) return null;
    final pool = ultV2ModsForType(type);
    if (pool.isEmpty) return null;
    return pool[(rng() * pool.length).floor().clamp(0, pool.length - 1)];
  }

  /// Un legendario: mods fijos con su rango + 1–2 aleatorios + pasiva
  /// única al nivel I.
  ItemInstance generateUnique(RandomSource rng, UniqueDef u, int itemLevel,
      {String uid = newUid}) {
    final w = catalog.weapons[u.baseId]!;
    var item = ItemInstance(
      uid: uid,
      baseId: u.baseId,
      rarity: Rarity.legendario,
      itemLevel: math.max(itemLevel, w.level).clamp(1, maxLevel),
      uniqueId: u.id,
      passiveId: u.passiveId,
      affixes: const [],
    );
    // Mods fijos al nivel del objeto (combo_balance.md § 2).
    item = item.copyWith(affixes: [
      for (final f in u.fixed)
        if (ItemRules.fixedRangeAt(f, item.itemLevel) case (final lo, final hi))
          AffixRoll(f.affixId, 0, rollValue(rng, lo, hi)),
    ]);
    final n = u.randomMin +
        (rng() * (u.randomMax - u.randomMin + 1))
            .floor()
            .clamp(0, u.randomMax - u.randomMin);
    item = addRandomAffixes(rng, item, n);
    return item;
  }

  /// Vuelve a tirar los valores de todos los afijos dentro de su tier
  /// (o del rango del único). Esquirla del Eco.
  ItemInstance rerollValues(RandomSource rng, ItemInstance i) => i.copyWith(
        affixes: [
          for (final a in i.affixes)
            if (items.rangeOf(i, a) case (final lo, final hi))
              a.withValue(rollValue(rng, lo, hi))
            else
              a,
        ],
      );

  // ------------------------------------------------------------------
  // Drops por fuente (por jugador: loot instanciado)
  // ------------------------------------------------------------------

  /// Probabilidad de que caiga un arma (por jugador).
  static double weaponChance(LootSource s) => switch (s) {
        LootSource.battle => 0.30,
        LootSource.chest => 0.35,
        LootSource.elite => 1.0,
        LootSource.boss => 1.0,
        LootSource.mission => 0.0, // la decide el rango (SessionEngine)
      };

  /// Armas extra garantizadas / probables: élite 50% de una 2.ª, jefe 2.
  static (int, double) extraWeapons(LootSource s) => switch (s) {
        LootSource.elite => (0, 0.5),
        LootSource.boss => (1, 0.0),
        _ => (0, 0.0),
      };

  /// Probabilidad base de cada material por drop (× fuente × zona;
  /// materials_economy.md § 4.1).
  static Map<CraftMaterial, double> get materialChance {
    final t = tuning(TuningId.materials);
    return {
      CraftMaterial.esquirla: t.d('chanceEsquirla'),
      CraftMaterial.cristal: t.d('chanceCristal'),
      CraftMaterial.prisma: t.d('chancePrisma'),
    };
  }

  static double materialMultiplier(LootSource s) {
    final t = tuning(TuningId.materials);
    return switch (s) {
      LootSource.battle => t.d('multBattle'),
      LootSource.chest => t.d('multChest'),
      LootSource.mission => t.d('multMission'),
      LootSource.elite => t.d('multElite'),
      LootSource.boss => t.d('multBoss'),
    };
  }

  /// Materiales de un drop: una tirada por material (`chance × fuente ×
  /// (1 + bonus de zona)`, tope 95%); el jefe además deja 1 Esquirla.
  Map<CraftMaterial, int> rollMaterials(
      RandomSource rng, int zoneLevel, LootSource source) {
    final out = <CraftMaterial, int>{};
    final mult = materialMultiplier(source) * (1 + zoneBonus(zoneLevel));
    for (final e in materialChance.entries) {
      if (rng() < math.min(0.95, e.value * mult)) out[e.key] = 1;
    }
    if (source == LootSource.boss) {
      out[CraftMaterial.esquirla] = (out[CraftMaterial.esquirla] ?? 0) + 1;
    }
    return out;
  }

  /// Todo lo que le toca a un jugador de una fuente: armas (con
  /// [weaponChance] o [chance] si se pasa) y materiales.
  List<LootDrop> rollDrops(
    RandomSource rng, {
    required int zoneLevel,
    required LootSource source,
    String? family,
    double? chance,
    double extraBonus = 0,
    double legendaryMult = 1,
    bool eco = false,
    int? levelCap,
  }) {
    final il = itemLevelFor(zoneLevel, source, cap: levelCap);
    final out = <LootDrop>[];
    ItemInstance gen() => generate(rng,
        itemLevel: il,
        family: family,
        source: source,
        extraBonus: extraBonus,
        legendaryMult: legendaryMult,
        eco: eco);
    if (rng() < (chance ?? weaponChance(source))) {
      out.add(LootDrop.item(gen()));
      final (more, maybe) = extraWeapons(source);
      for (var i = 0; i < more; i++) {
        out.add(LootDrop.item(gen()));
      }
      if (maybe > 0 && rng() < maybe) out.add(LootDrop.item(gen()));
    }
    for (final e in rollMaterials(rng, zoneLevel, source).entries) {
      out.add(LootDrop.stack(StackKind.of(e.key), e.value));
    }
    return out;
  }

  /// Afijos posibles con su peso (vista previa de Cristal de Era).
  List<(AffixDef, double)> affixOdds(ItemInstance i) {
    final c = items.candidateAffixes(i);
    final total = c.fold(0.0, (a, x) => a + x.weight);
    return [for (final a in c) (a, total == 0 ? 0 : a.weight / total)];
  }

  /// Bases que pueden salir a [itemLevel] (para la UI / tests).
  List<WeaponDef> basesUpTo(int itemLevel) =>
      [for (final w in catalog.weapons.values) if (w.level <= itemLevel) w];

  /// Afijos por id (atajo para la UI).
  static Map<String, AffixDef> get affixes => kAffixes;
}
