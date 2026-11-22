import '../data/branch_ults_catalog.dart' show kBranchUltWeaponTypes;
import '../data/game_catalog.dart';
import '../data/summoner_catalog.dart' show kWeaponUltOf;
import '../data/ults_v2_catalog.dart';
import '../models/item.dart';
import '../models/player_profile.dart';
import '../models/skill.dart';
import '../models/ult_def.dart';
import '../models/weapon.dart';
import 'ult_rules.dart';

/// De dónde sale una ULT para el filtro "Origen" de PERSONAJE → ULT
/// (docs/specs/ultimates_v2.md § 2.1.1). Se deriva de los catálogos.
enum UltOrigin {
  classBase('ULT base de la clase'),
  weaponType('Tipo de arma'),
  weaponMod('Arma Rara / Épica'),
  branch('Camino'),
  legendary('Legendario'),
  tome('Tomo'),
  ascension('Ascensión'),
  tree('Hito del árbol'),
  feat('Hazaña'),
  eco('Ecos y Atlas'),
  boss('Botín de jefe');

  const UltOrigin(this.label);
  final String label;

  static UltOrigin? byName(Object? v) =>
      values.where((o) => o.name == v).firstOrNull;
}

/// Orden de la lista de ULT.
enum UltSort {
  newest('Más nuevas'),
  alpha('Alfabético'),
  level('Por nivel'),
  origin('Por origen'),
  weapon('Por tipo de arma');

  const UltSort(this.label);
  final String label;

  static UltSort byName(Object? v) =>
      values.where((o) => o.name == v).firstOrNull ?? newest;
}

/// Filtro de estado: todas, las que tenés o las que faltan.
enum UltOwnedFilter {
  all('Todas'),
  owned('Obtenidas'),
  missing('Faltan');

  const UltOwnedFilter(this.label);
  final String label;

  static UltOwnedFilter byName(Object? v) =>
      values.where((o) => o.name == v).firstOrNull ?? all;
}

/// Filtros y orden de la lista (sin el texto de búsqueda). Se recuerdan
/// por equipo en los ajustes (`game.json`, clave `ultBrowse`).
class UltBrowsePrefs {
  const UltBrowsePrefs(
      {this.sort = UltSort.newest,
      this.weapon,
      this.origin,
      this.owned = UltOwnedFilter.all});

  final UltSort sort;

  /// Tipo de arma (`null` = todos).
  final String? weapon;

  /// Origen (`null` = todos).
  final UltOrigin? origin;
  final UltOwnedFilter owned;

  UltBrowsePrefs copyWith(
          {UltSort? sort,
          String? Function()? weapon,
          UltOrigin? Function()? origin,
          UltOwnedFilter? owned}) =>
      UltBrowsePrefs(
          sort: sort ?? this.sort,
          weapon: weapon == null ? this.weapon : weapon(),
          origin: origin == null ? this.origin : origin(),
          owned: owned ?? this.owned);

  Map<String, Object?> toJson() => {
        'sort': sort.name,
        if (weapon != null) 'weapon': weapon,
        if (origin != null) 'origin': origin!.name,
        'owned': owned.name,
      };

  factory UltBrowsePrefs.fromJson(Object? json) {
    if (json is! Map) return const UltBrowsePrefs();
    return UltBrowsePrefs(
        sort: UltSort.byName(json['sort']),
        weapon: json['weapon'] is String ? json['weapon'] as String : null,
        origin: UltOrigin.byName(json['origin']),
        owned: UltOwnedFilter.byName(json['owned']));
  }

  @override
  bool operator ==(Object other) =>
      other is UltBrowsePrefs &&
      other.sort == sort &&
      other.weapon == weapon &&
      other.origin == origin &&
      other.owned == owned;

  @override
  int get hashCode => Object.hash(sort, weapon, origin, owned);
}

/// Una fila de la lista: una opción del repertorio o una ULT de las 50
/// que todavía falta.
class UltEntry {
  const UltEntry({
    required this.skill,
    required this.origin,
    required this.weapons,
    required this.owned,
    this.option,
    this.def,
    this.level = 1,
    this.acquired = -1,
  });

  final SkillDef skill;
  final UltOrigin origin;

  /// Tipos de arma con los que se asocia (vacío = cualquiera).
  final List<String> weapons;

  /// Está en el repertorio (se puede equipar si [available]).
  final bool owned;

  /// La opción del selector (`null` si falta).
  final UltOption? option;
  final UltDef? def;
  final int level;

  /// Posición en el orden de obtención (más alto = más nueva; -1 = sin
  /// dato, partida vieja o no obtenida).
  final int acquired;

  String get id => skill.id;
  String get name => skill.name;
  bool get available => owned && (option?.available ?? false);
}

/// Armado, filtro y orden de la lista de PERSONAJE → ULT
/// (ultimates_v2.md § 2.1.1). Puro: sin UI.
abstract final class UltBrowseRules {
  /// Todas las filas de [p]: su repertorio y las ULT v2 que le faltan.
  static List<UltEntry> entries(
      PlayerProfile p, WeaponDef weapon, ItemInstance? item,
      [GameCatalog catalog = GameCatalog.standard]) {
    final order = {
      for (final (i, id) in p.ultOrder.indexed) id: i,
    };
    final out = <UltEntry>[];
    for (final o in UltRules.optionsOf(p, weapon, item, catalog)) {
      out.add(UltEntry(
          skill: o.skill,
          origin: originOf(o.id, p.classId,
              ascension: o.kind == UltOptionKind.ascension, catalog: catalog),
          weapons: weaponsOf(o.id, catalog),
          owned: true,
          option: o,
          def: o.def,
          level: o.level,
          acquired: order[o.id] ?? -1));
    }
    final have = {for (final e in out) e.id};
    for (final u in kUltV2List) {
      if (have.contains(u.id)) continue;
      out.add(UltEntry(
          skill: u.skill,
          origin: originOf(u.id, p.classId, catalog: catalog),
          weapons: u.weapons,
          owned: false,
          def: u));
    }
    return out;
  }

  /// El origen de la ULT [id] para un personaje de [classId].
  static UltOrigin originOf(String id, String classId,
      {bool ascension = false, GameCatalog catalog = GameCatalog.standard}) {
    if (ascension) return UltOrigin.ascension;
    if (id == UltRules.baseUltId(classId, catalog)) return UltOrigin.classBase;
    if (kUltV2[id] case final u?) {
      return switch (u.source) {
        UltSource.weaponMod => UltOrigin.weaponMod,
        UltSource.unique => UltOrigin.legendary,
        UltSource.tree => UltOrigin.tree,
        UltSource.feat => UltOrigin.feat,
        UltSource.eco => UltOrigin.eco,
        UltSource.boss => UltOrigin.boss,
      };
    }
    if (kWeaponUltOf.containsValue(id)) return UltOrigin.tome;
    if (kBranchUltWeaponTypes.containsKey(id)) return UltOrigin.branch;
    if (catalog.ultimates.values.any((u) => u.id == id)) {
      return UltOrigin.weaponType;
    }
    return UltOrigin.weaponMod;
  }

  /// Tipos de arma de la ULT [id]: los de repertorio y, para las de tipo
  /// de arma, ese tipo.
  static List<String> weaponsOf(String id,
      [GameCatalog catalog = GameCatalog.standard]) {
    final w = UltRules.weaponsOf(id);
    if (w.isNotEmpty) return w;
    return [
      for (final e in catalog.ultimates.entries)
        if (e.value.id == id) e.key,
    ];
  }

  /// Tipos de arma presentes en [list] (para el filtro), ordenados.
  static List<String> weaponTypes(Iterable<UltEntry> list) =>
      {for (final e in list) ...e.weapons}.toList()..sort();

  /// Orígenes presentes en [list], en el orden de [UltOrigin].
  static List<UltOrigin> origins(Iterable<UltEntry> list) {
    final have = {for (final e in list) e.origin};
    return [for (final o in UltOrigin.values) if (have.contains(o)) o];
  }

  /// [list] filtrada por [text] (nombre, sin distinguir mayúsculas ni
  /// tildes) y [prefs], y ordenada.
  static List<UltEntry> apply(List<UltEntry> list, UltBrowsePrefs prefs,
      {String text = ''}) {
    final q = fold(text.trim());
    final out = [
      for (final e in list)
        if ((q.isEmpty || fold(e.name).contains(q)) &&
            (prefs.weapon == null || e.weapons.contains(prefs.weapon)) &&
            (prefs.origin == null || e.origin == prefs.origin) &&
            switch (prefs.owned) {
              UltOwnedFilter.all => true,
              UltOwnedFilter.owned => e.owned,
              UltOwnedFilter.missing => !e.owned,
            })
          e,
    ];
    int alpha(UltEntry a, UltEntry b) => fold(a.name).compareTo(fold(b.name));
    int ownedFirst(UltEntry a, UltEntry b) =>
        (b.owned ? 1 : 0) - (a.owned ? 1 : 0);
    int then(int c, UltEntry a, UltEntry b) => c != 0 ? c : alpha(a, b);
    out.sort((a, b) => switch (prefs.sort) {
          UltSort.newest => then(
              ownedFirst(a, b) != 0
                  ? ownedFirst(a, b)
                  : b.acquired.compareTo(a.acquired),
              a,
              b),
          UltSort.alpha => alpha(a, b),
          UltSort.level => then(
              ownedFirst(a, b) != 0
                  ? ownedFirst(a, b)
                  : b.level.compareTo(a.level),
              a,
              b),
          UltSort.origin => then(a.origin.index.compareTo(b.origin.index), a, b),
          UltSort.weapon => then(
              (a.weapons.isEmpty ? '~' : a.weapons.first)
                  .compareTo(b.weapons.isEmpty ? '~' : b.weapons.first),
              a,
              b),
        });
    return out;
  }

  static const _accents = {
    'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n',
  };

  /// [s] en minúsculas y sin tildes.
  static String fold(String s) =>
      s.toLowerCase().split('').map((c) => _accents[c] ?? c).join();
}
