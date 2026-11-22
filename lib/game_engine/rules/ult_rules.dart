import '../data/ascension_catalog.dart';
import '../data/tuning_catalog.dart';
import '../data/branch_ults_catalog.dart'
    show kBranchUltWeaponTypes, kWeaponUltSkills, ownWeaponUlt;
import '../data/game_catalog.dart';
import '../data/summoner_catalog.dart' show kWeaponUltOf;
import '../data/ults_v2_catalog.dart';
import '../data/weapons_catalog.dart' show kWeapons;
import '../models/ascension.dart';
import '../models/item.dart';
import '../models/player_profile.dart';
import '../models/player_state.dart';
import '../models/skill.dart';
import '../models/ult_def.dart';
import '../models/weapon.dart';

/// De dónde sale una opción del selector de ULT activa.
enum UltOptionKind {
  /// La de la ascensión elegida.
  ascension,

  /// La ULT base de la clase (la del tipo de su arma inicial; siempre
  /// disponible y la activa por defecto, ultimates_v2.md § 2.1).
  weaponType,

  /// Una del repertorio (aprendida: árbol, hazaña, Ecos, jefe, o sacada
  /// de un arma con mod "ULT" / legendario).
  learned,
}

/// Una ULT que se puede elegir como activa (o que se ve gris porque el
/// tipo de arma o la clase no son compatibles).
class UltOption {
  const UltOption(this.skill, this.kind,
      {this.def, this.reason, this.level = 1});

  final SkillDef skill;
  final UltOptionKind kind;

  /// Su entrada v2 (fuente, compatibilidad), si es una ULT v2.
  final UltDef? def;

  /// Por qué no se puede usar ahora (`null` = disponible).
  final String? reason;

  /// Nivel de mejora (1-5).
  final int level;

  bool get available => reason == null;
  String get id => skill.id;
}

/// Costo de subir una ULT de un nivel al siguiente.
class UltUpgradeCost {
  const UltUpgradeCost(this.credits, this.materials);
  final int credits;
  final Map<CraftMaterial, int> materials;

  String get text => [
        '₵$credits',
        for (final e in materials.entries) '${e.value} ${e.key.label}',
      ].join(' · ');
}

/// Repertorio, ULT activa y mejora (docs/specs/ultimates_v2.md § 2.1 y
/// § 2.4). Dart puro.
///
/// Las ULT NUNCA se pierden: toda ULT que el personaje consigue (también
/// las de mod de arma o legendario) entra a `uk` apenas la tiene; el arma
/// es solo la fuente. Se usa con cualquier arma del tipo compatible.
abstract final class UltRules {
  /// Puntos del árbol de la clase que dan cada hito (§ 3.3).
  static const treeMilestones = [20, 40];

  /// Nivel máximo de una ULT (§ 2.4).
  static const maxLevel = 5;

  /// +poder (y efectos numéricos) por nivel sobre el 1.
  static double get perLevel => tuning(TuningId.ultLevel).d('perLevel');

  /// Factor de la ULT a nivel [level].
  static double levelFactor(int level) =>
      1 + perLevel * (level.clamp(1, maxLevel) - 1);

  /// Fragmento de Abismo que piden los niveles 4 y 5 de las ULT de jefe.
  static const _bossFragment = {
    'golemReloj': CraftMaterial.fragReloj,
    'hechicera': CraftMaterial.fragEco,
    'espectroCoronado': CraftMaterial.fragCorona,
    'devorador': CraftMaterial.fragEras,
  };

  /// Costo de subir [id] desde [level] (1..4) al siguiente. Pesos de la
  /// economía v0.15 (materials_economy.md § 6): créditos, Cristales de
  /// Era y, desde el nivel 3, Prismas Rotos; las de jefe con versión del
  /// Abismo piden además 1 Fragmento de ese jefe desde el nivel 3.
  static UltUpgradeCost? upgradeCost(String id, int level) {
    if (level < 1 || level >= maxLevel) return null;
    final frag = kUltV2[id]?.source == UltSource.boss
        ? _bossFragment[kUltV2[id]!.ref]
        : null;
    final t = tuning(TuningId.ultUpgrade);
    final pf = t.i('prismaFrom');
    return UltUpgradeCost(t.i('credits') * level, {
      if (t.i('cristal') > 0) CraftMaterial.cristal: t.i('cristal') * level,
      if (level >= pf) CraftMaterial.prisma: level - pf + 1,
      if (frag != null && level >= t.i('fragFrom')) frag: 1,
    });
  }

  /// Nivel de [id] en [p] (1 si no lo subió).
  static int levelOf(PlayerProfile p, String id) =>
      (p.ultLevels[id] ?? 1).clamp(1, maxLevel);

  /// Sube [id] un nivel pagando su costo; `null` si no se puede (no la
  /// tiene, ya está al máximo o le faltan fondos). Lo valida el host.
  static PlayerProfile? upgrade(PlayerProfile p, String id) {
    final known = {...p.ultKnown, ...earned(p)};
    if (!known.contains(id)) return null;
    final lv = levelOf(p, id);
    final cost = upgradeCost(id, lv);
    if (cost == null || p.credits < cost.credits) return null;
    for (final e in cost.materials.entries) {
      if (p.material(e.key) < e.value) return null;
    }
    return p.copyWith(
      credits: p.credits - cost.credits,
      materials: {
        ...p.materials,
        for (final e in cost.materials.entries)
          e.key: p.material(e.key) - e.value,
      },
      ultKnown: known,
      ultLevels: {...p.ultLevels, id: lv + 1},
    );
  }

  /// Tipos de arma con los que se usa la ULT de repertorio [id] (vacío =
  /// cualquiera).
  static List<String> weaponsOf(String id) {
    final v2 = kUltV2[id];
    if (v2 != null) return v2.weapons;
    final branch = kBranchUltWeaponTypes[id];
    if (branch != null) return branch;
    // ULT de base del Invocador: el tipo de las armas que la traen.
    return {
      for (final e in kWeaponUltOf.entries)
        if (e.value == id) kWeapons[e.key]?.type,
    }.whereType<String>().toList();
  }

  /// La ULT propia de un arma (mod, legendario o base), si tiene.
  static String? itemUltId(ItemInstance i) => ownWeaponUlt(i.baseId, i)?.id;

  /// Las ULT que enseña el arma [i] al conseguirla (ultimates_v2.md
  /// § 2.1): la propia (mod, legendario, tomo) y la de su tipo.
  static Set<String> taughtBy(ItemInstance i,
          [GameCatalog catalog = GameCatalog.standard]) =>
      {
        if (itemUltId(i) case final id?) id,
        if (catalog.ultimates[kWeapons[i.baseId]?.type] case final u?) u.id,
      };

  /// Id de la ULT base de [classId]: la que traía su arma inicial (la
  /// propia del tomo o la de su tipo). Siempre en el repertorio y la
  /// activa por defecto (ultimates_v2.md § 2.1).
  static String? baseUltId(String classId,
      [GameCatalog catalog = GameCatalog.standard]) {
    final start = catalog.classes[classId]?.startWeaponId;
    if (start == null) return null;
    return ownWeaponUlt(start, null)?.id ??
        catalog.ultimates[catalog.weapons[start]?.type]?.id;
  }

  /// La ULT base de [classId] (sin nivel aplicado).
  static SkillDef? baseUlt(String classId,
      [GameCatalog catalog = GameCatalog.standard]) {
    final id = baseUltId(classId, catalog);
    return id == null ? null : _skill(id, catalog);
  }

  /// La ULT base de [classId] lista para el combate, con su nivel.
  static SkillDef? baseUltLeveled(String classId, int level,
      [GameCatalog catalog = GameCatalog.standard]) {
    final sk = baseUlt(classId, catalog);
    if (sk == null) return null;
    if (catalog.ultimates.values.any((u) => u.id == sk.id)) return sk;
    return leveled(sk, level);
  }

  /// ULT que [p] ya ganó y quizá no estén anotadas en `uk`: la base de la
  /// clase, hitos del árbol, Maestría y las que enseñan las armas que
  /// tiene (propia y de tipo).
  static Set<String> earned(PlayerProfile p,
          [GameCatalog catalog = GameCatalog.standard]) =>
      {
        if (baseUltId(p.classId, catalog) case final id?) id,
        for (final u in kUltV2List)
          if (_earned(u, p)) u.id,
        for (final i in p.items) ...taughtBy(i, catalog),
      };

  static bool _earned(UltDef u, PlayerProfile p) {
    final parts = u.ref.split(':');
    return switch (u.source) {
      UltSource.tree => parts.length == 2 &&
          parts.first == p.classId &&
          p.tree.length >= (int.tryParse(parts.last) ?? 1 << 30),
      UltSource.eco => parts.first == 'mastery' &&
          parts.length == 2 &&
          p.mastery >= (int.tryParse(parts.last) ?? 1 << 30),
      _ => false,
    };
  }

  /// Anota en `uk` lo ganado (idempotente: devuelve [p] si no hay nada
  /// nuevo). Con [markNew] lo nuevo (salvo la base) queda con la marca
  /// NUEVA (`un`); la migración del perfil lo llama sin marca.
  static PlayerProfile absorb(PlayerProfile p, {bool markNew = true}) {
    final e = earned(p);
    if (p.ultKnown.containsAll(e)) return p;
    final added = e.difference(p.ultKnown);
    final base = baseUltId(p.classId);
    return p.copyWith(
        ultKnown: {...p.ultKnown, ...e},
        ultNew: markNew
            ? {...p.ultNew, ...added.where((id) => id != base)}
            : null);
  }

  /// Aprende [id] (marca NUEVA con [markNew]). Sin cambios si ya la tenía
  /// o no existe.
  static PlayerProfile learn(PlayerProfile p, String id,
      {bool markNew = true}) {
    if (!isLearnable(id) || p.ultKnown.contains(id)) return p;
    return p.copyWith(
        ultKnown: {...p.ultKnown, id},
        ultNew: markNew ? {...p.ultNew, id} : null);
  }

  /// Prefijo de los ids de `SeenItemsAction` que desmarcan una ULT NUEVA.
  static const seenPrefix = 'ult:';

  /// Quita la marca NUEVA de las ULT de [ids] (`ult:<id>`); `null` si no
  /// cambia nada.
  static PlayerProfile? markSeen(PlayerProfile p, Iterable<String> ids) {
    final next = {...p.ultNew}..removeAll(ids
        .where((u) => u.startsWith(seenPrefix))
        .map((u) => u.substring(seenPrefix.length)));
    return next.length == p.ultNew.length ? null : p.copyWith(ultNew: next);
  }

  /// [id] puede estar en el repertorio (v2, de camino o de arma).
  static bool isLearnable(String id) =>
      kUltV2.containsKey(id) ||
      kWeaponUltSkills.containsKey(id) ||
      // Las de tipo de arma también (v0.20.13): una elegida queda en el
      // repertorio aunque después el arma se venda, se funda o se guarde.
      GameCatalog.standard.ultimates.values.any((u) => u.id == id);

  /// [id] es alguna ULT de jugador que existe (ascensión, arma, tipo de
  /// arma o v2).
  static bool isUltId(String? id,
      [GameCatalog catalog = GameCatalog.standard]) {
    if (id == null) return false;
    return kWeaponUltSkills.containsKey(id) ||
        catalog.playerUlts.containsKey(id) ||
        catalog.ultimates.values.any((u) => u.id == id) ||
        kAscensionUltimates.values.any((u) => u.id == id);
  }

  /// La ULT aprendible de fuente [source] con referencia [ref].
  static UltDef? bySource(UltSource source, String ref) {
    for (final u in kUltV2List) {
      if (u.source == source && u.ref == ref) return u;
    }
    return null;
  }

  static SkillDef? _skill(String id, GameCatalog catalog) =>
      catalog.playerUlts[id] ??
      kWeaponUltSkills[id] ??
      catalog.ultimates.values.where((u) => u.id == id).firstOrNull;

  /// Las ULT que [classId] con un arma de tipo [weapon] puede elegir:
  /// ascensión, tipo de arma y el repertorio ([known]); las
  /// incompatibles salen con [UltOption.reason].
  static List<UltOption> options({
    required String classId,
    required WeaponDef weapon,
    AscensionProgress ascension = AscensionProgress.empty,
    Set<String> known = const {},
    Map<String, int> levels = const {},
    GameCatalog catalog = GameCatalog.standard,
  }) {
    final out = <UltOption>[];
    final seen = <String>{};
    void add(UltOption o) {
      if (seen.add(o.id)) out.add(o);
    }

    final asc = kAscensions[ascension.id];
    if (asc != null && asc.classId == classId) {
      final u = kAscensionUltimates[asc.id];
      if (u != null) add(UltOption(u, UltOptionKind.ascension));
    }
    // La ULT base de la clase (nunca la del arma equipada).
    final base = baseUlt(classId, catalog);
    if (base != null) {
      add(UltOption(base, UltOptionKind.weaponType,
          def: kUltV2[base.id],
          level: (levels[base.id] ?? 1).clamp(1, maxLevel)));
    }
    final ids = known.toList()..sort();
    for (final id in ids) {
      final sk = _skill(id, catalog);
      if (sk == null) continue;
      final def = kUltV2[id];
      // v0.20.9: la ULT elegida vale con cualquier arma; solo la clase
      // la puede restringir.
      final cls = def?.classes ?? const <String>[];
      final reason =
          cls.isNotEmpty && !cls.contains(classId) ? 'Solo ${cls.join(', ')}' : null;
      add(UltOption(sk, UltOptionKind.learned,
          def: def, reason: reason, level: (levels[id] ?? 1).clamp(1, maxLevel)));
    }
    return out;
  }

  /// Opciones de [p] con el arma equipada [weapon].
  static List<UltOption> optionsOf(
          PlayerProfile p, WeaponDef weapon, ItemInstance? item,
          [GameCatalog catalog = GameCatalog.standard]) =>
      options(
          classId: p.classId,
          weapon: weapon,
          ascension: p.ascension,
          known: {...p.ultKnown, ...earned(p, catalog)},
          levels: p.ultLevels,
          catalog: catalog);

  /// La ULT activa de [p] si es válida con su arma actual; si no, `null`
  /// (el motor cae al orden de siempre, § 2.1).
  static String? validSel(PlayerProfile p, WeaponDef weapon, ItemInstance? item,
      [GameCatalog catalog = GameCatalog.standard]) {
    final sel = p.ultSel;
    if (sel == null) return null;
    for (final o in optionsOf(p, weapon, item, catalog)) {
      if (o.id == sel) return o.available ? sel : null;
    }
    return null;
  }

  /// El host acepta elegir [id] como activa: `null` (volver al orden de
  /// siempre) o una opción que [p] tiene (aunque hoy esté gris por el
  /// arma). Rechaza ids desconocidos (§ 5.2).
  static bool canSelect(PlayerProfile p, String? id, WeaponDef weapon,
      ItemInstance? item,
      [GameCatalog catalog = GameCatalog.standard]) {
    if (id == null) return true;
    return optionsOf(p, weapon, item, catalog).any((o) => o.id == id);
  }

  /// La ULT que resuelve la selección [b.ultSel] (`null` = no hay o no
  /// es compatible), ya con su nivel: la usa `ultimateOf` antes del
  /// orden de siempre.
  static SkillDef? selected(PlayerBuild b,
      [GameCatalog catalog = GameCatalog.standard]) {
    final sel = b.ultSel;
    if (sel == null) return null;
    final asc = kAscensions[b.ascension.id];
    if (asc != null && asc.classId == b.classId) {
      final u = kAscensionUltimates[asc.id];
      if (u != null && u.id == sel) return u;
    }
    // La elegida manda con cualquier arma (v0.20.9): ni el arma equipada
    // ni el árbol la pisan; solo la clase la puede invalidar.
    final sk = _skill(sel, catalog);
    if (sk == null) return null;
    final cls = kUltV2[sel]?.classes ?? const <String>[];
    if (cls.isNotEmpty && !cls.contains(b.classId)) return null;
    if (catalog.ultimates.values.any((u) => u.id == sel)) return sk;
    return leveled(sk, b.ultLevel);
  }

  /// [sk] a nivel [level] (1 = sin cambios).
  static SkillDef leveled(SkillDef sk, int level) =>
      level <= 1 ? sk : sk.scaled(levelFactor(level), keepCosts: true);
}
