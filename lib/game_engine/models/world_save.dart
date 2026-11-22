/// Mundos por cuenta (town_loop.md § 11c, v0.21.0). Un mundo guarda el
/// pueblo; los personajes siguen aparte y entran a cualquier mundo.
library;

import 'farm_plot.dart';

export 'farm_plot.dart';

/// Etiqueta del mundo: solo valor por defecto y agrupamiento de la lista.
/// **No bloquea nada**: un Solitario se abre como sala y un Cooperativo
/// se juega solo.
enum WorldLabel {
  solitario('Solitario'),
  cooperativo('Cooperativo');

  const WorldLabel(this.text);
  final String text;

  static WorldLabel fromName(Object? n) =>
      values.firstWhere((v) => v.name == n, orElse: () => cooperativo);
}

/// Estado del pueblo de un mundo.
class TownState {
  const TownState(
      {this.upgrades = const {},
      this.lostLoot = const [],
      this.cycle = 0,
      this.lake,
      this.expansions = 0,
      this.zones = const [],
      this.plots = const {},
      this.stock = const {},
      this.helper = 0,
      this.silo = const {}});

  /// Especies del lago del pueblo (fishing.md § 2.1); `null` = las de la
  /// zona 1 (`kTownLakeDefault`).
  final List<String>? lake;

  /// Mejoras del pueblo por id → nivel (fase 4: todavía sin efectos).
  final Map<String, int> upgrades;

  /// Pozo del Loot perdido (cada entrada: el JSON de `GroundLoot` de
  /// `SessionJson`, guardado tal cual).
  final List<Map<String, Object?>> lostLoot;

  /// Misiones completadas en el ciclo del pueblo (§ 7).
  final int cycle;

  /// Ampliaciones compradas en la fuente rúnica (farming.md § 6).
  final int expansions;

  /// Zona elegida para cada espacio de las ampliaciones, en orden (los
  /// espacios sin elegir no están).
  final List<TownZoneKind> zones;

  /// Parcelas aradas: `"x,y"` → parcela.
  final Map<String, FarmPlot> plots;

  /// Peces soltados en el lago: especie → cantidad (farming.md § 7).
  final Map<String, int> stock;

  /// Nivel del ayudante de la huerta (0 = sin contratar).
  final int helper;

  /// Granero del ayudante: `cropKey` → cantidad (lo recoge cualquiera).
  final Map<String, int> silo;

  int get stockTotal => stock.values.fold(0, (a, b) => a + b);
  int zoneCount(TownZoneKind k) => zones.where((z) => z == k).length;

  TownState copyWith({
    Map<String, int>? upgrades,
    List<Map<String, Object?>>? lostLoot,
    int? cycle,
    List<String>? lake,
    int? expansions,
    List<TownZoneKind>? zones,
    Map<String, FarmPlot>? plots,
    Map<String, int>? stock,
    int? helper,
    Map<String, int>? silo,
  }) =>
      TownState(
          upgrades: upgrades ?? this.upgrades,
          lostLoot: lostLoot ?? this.lostLoot,
          cycle: cycle ?? this.cycle,
          lake: lake ?? this.lake,
          expansions: expansions ?? this.expansions,
          zones: zones ?? this.zones,
          plots: plots ?? this.plots,
          stock: stock ?? this.stock,
          helper: helper ?? this.helper,
          silo: silo ?? this.silo);

  /// Lo del pueblo que ven todos en la sala (protocolo 44, `town` del
  /// estado): sin el pozo (viaja aparte) ni las mejoras sin efecto.
  Map<String, Object?> farmJson() => {
        if (lake != null) 'lake': lake,
        if (expansions > 0) 'exp': expansions,
        if (zones.isNotEmpty) 'zones': [for (final z in zones) z.name],
        if (plots.isNotEmpty)
          'plots': {for (final e in plots.entries) e.key: e.value.toJson()},
        if (stock.isNotEmpty) 'stock': stock,
        if (helper > 0) 'helper': helper,
        if (silo.isNotEmpty) 'silo': silo,
      };

  Map<String, Object?> toJson() => {
        if (upgrades.isNotEmpty) 'up': upgrades,
        if (lostLoot.isNotEmpty) 'lost': lostLoot,
        if (cycle != 0) 'cycle': cycle,
        ...farmJson(),
      };

  static Map<String, int> _ints(Object? v) => v is Map
      ? {
          for (final e in v.entries)
            if (e.value is num && (e.value as num) > 0)
              '${e.key}': (e.value as num).round(),
        }
      : const {};

  /// Tolerante: los saves de antes de v0.23.0 no tienen las claves de la
  /// huerta y quedan con el pueblo sin ampliar.
  static TownState fromJson(Object? raw) {
    if (raw is! Map) return const TownState();
    final up = raw['up'];
    final lost = raw['lost'];
    final plots = raw['plots'];
    final zones = raw['zones'];
    return TownState(
      upgrades: up is Map
          ? {
              for (final e in up.entries)
                if (e.value is num) '${e.key}': (e.value as num).round(),
            }
          : const {},
      lostLoot: lost is List
          ? [
              for (final g in lost)
                if (g is Map) g.cast<String, Object?>(),
            ]
          : const [],
      cycle: raw['cycle'] is num ? (raw['cycle'] as num).round() : 0,
      lake: raw['lake'] is List
          ? [for (final x in raw['lake'] as List) if (x is String) x]
          : null,
      expansions:
          raw['exp'] is num ? (raw['exp'] as num).round().clamp(0, 9) : 0,
      zones: zones is List
          ? [
              for (final z in zones)
                if (TownZoneKind.fromName(z) case final k?) k,
            ]
          : const [],
      plots: plots is Map
          ? {
              for (final e in plots.entries)
                if (parsePlotKey('${e.key}') != null)
                  '${e.key}': FarmPlot.fromJson(e.value),
            }
          : const {},
      stock: _ints(raw['stock']),
      helper: raw['helper'] is num ? (raw['helper'] as num).round() : 0,
      silo: _ints(raw['silo']),
    );
  }
}

/// Un mundo de la cuenta (`accounts/worlds/<id>.json`).
class WorldSave {
  const WorldSave({
    required this.id,
    required this.name,
    required this.label,
    required this.created,
    this.town = const TownState(),
  });

  static const maxName = 24;

  final String id;
  final String name;
  final WorldLabel label;
  final DateTime created;
  final TownState town;

  WorldSave copyWith({String? name, WorldLabel? label, TownState? town}) =>
      WorldSave(
          id: id,
          name: name ?? this.name,
          label: label ?? this.label,
          created: created,
          town: town ?? this.town);

  Map<String, Object?> toJson() => {
        'v': 1,
        'id': id,
        'name': name,
        'label': label.name,
        'created': created.toUtc().toIso8601String(),
        'town': town.toJson(),
      };

  /// `null` si [raw] no es un mundo (archivo ajeno o dañado).
  static WorldSave? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'], name = raw['name'];
    if (id is! String || id.isEmpty || name is! String) return null;
    return WorldSave(
      id: id,
      name: name,
      label: WorldLabel.fromName(raw['label']),
      created: DateTime.tryParse('${raw['created']}') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      town: TownState.fromJson(raw['town']),
    );
  }
}

/// Los mundos de la cuenta y el elegido. Reglas puras de la lista
/// (crear, renombrar, borrar, agrupar); el disco lo maneja `WorldStore`.
class WorldBook {
  WorldBook({List<WorldSave> worlds = const [], String? selectedId})
      : worlds = List.unmodifiable(worlds),
        selectedId = selectedId != null && worlds.any((w) => w.id == selectedId)
            ? selectedId
            : (worlds.isEmpty ? null : worlds.first.id);

  final List<WorldSave> worlds;
  final String? selectedId;

  /// Nombre del primer mundo al migrar (town_loop.md § 11c).
  static const firstWorldName = 'Mi mundo';

  WorldSave? get selected => byId(selectedId);

  WorldSave? byId(String? id) {
    for (final w in worlds) {
      if (w.id == id) return w;
    }
    return null;
  }

  /// La lista agrupada por etiqueta (Solitario, después Cooperativo), cada
  /// grupo por fecha de creación.
  Map<WorldLabel, List<WorldSave>> get grouped => {
        for (final l in WorldLabel.values)
          l: [
            for (final w in worlds)
              if (w.label == l) w,
          ]..sort((a, b) => a.created.compareTo(b.created)),
      };

  static String cleanName(String raw) {
    final t = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    return t.length > WorldSave.maxName ? t.substring(0, WorldSave.maxName) : t;
  }

  /// Agrega un mundo nuevo (y lo elige). Nombre vacío → "Mundo N".
  WorldBook create(String name, WorldLabel label,
      {required DateTime now, required String id}) {
    final n = cleanName(name);
    final w = WorldSave(
        id: id,
        name: n.isEmpty ? 'Mundo ${worlds.length + 1}' : n,
        label: label,
        created: now);
    return WorldBook(worlds: [...worlds, w], selectedId: id);
  }

  WorldBook rename(String id, String name) {
    final n = cleanName(name);
    if (n.isEmpty) return this;
    return WorldBook(worlds: [
      for (final w in worlds) w.id == id ? w.copyWith(name: n) : w,
    ], selectedId: selectedId);
  }

  WorldBook remove(String id) => WorldBook(worlds: [
        for (final w in worlds)
          if (w.id != id) w,
      ], selectedId: selectedId == id ? null : selectedId);

  WorldBook select(String id) => WorldBook(worlds: worlds, selectedId: id);

  WorldBook put(WorldSave world) => WorldBook(worlds: [
        for (final w in worlds) w.id == world.id ? world : w,
        if (!worlds.any((w) => w.id == world.id)) world,
      ], selectedId: selectedId);
}
