/// Mundos por cuenta (town_loop.md § 11c, v0.21.0). Un mundo guarda el
/// pueblo; los personajes siguen aparte y entran a cualquier mundo.
library;

import 'farm_plot.dart';
import 'town_build.dart';

export 'farm_plot.dart';
export 'town_build.dart';

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

//// Lago y huerta del pueblo base (town_editor.md § 7): los mismos
/// lugares que antes de v0.24.0, ahora construcciones movibles.
const kBaseLake = TownBuild('l0', BuildKind.lago, [TownRect(3, 14, 8, 6)]);
const kBaseFarm = TownBuild('h0', BuildKind.huerta, [TownRect(19, 18, 4, 3)]);
const kDefaultBuilds = [kBaseLake, kBaseFarm];

/// Estado del pueblo de un mundo.
class TownState {
  const TownState(
      {this.upgrades = const {},
      this.lostLoot = const [],
      this.cycle = 0,
      this.lake,
      this.sides = const {},
      this.builds = kDefaultBuilds,
      this.helper = 0,
      this.silo = const {},
      this.marks = const {}});

  /// Lugares fijos movidos (town_editor.md § 3.3): id del lugar (`@forge`,
  /// …) → esquina en coordenadas del pueblo base. Los que no están, en su
  /// lugar de siempre (`TownLayout.landmarks`).
  final Map<String, (int, int)> marks;

  /// Especies del lago del pueblo (fishing.md § 2.1); `null` = las de la
  /// zona 1 (`kTownLakeDefault`). Valen para todos los lagos.
  final List<String>? lake;

  /// Mejoras del pueblo por id → nivel (fase 4: todavía sin efectos).
  final Map<String, int> upgrades;

  /// Pozo del Loot perdido (cada entrada: el JSON de `GroundLoot` de
  /// `SessionJson`, guardado tal cual).
  final List<Map<String, Object?>> lostLoot;

  /// Misiones completadas en el ciclo del pueblo (§ 7).
  final int cycle;

  /// Ampliaciones compradas por lado (town_editor.md § 2).
  final Map<TownSide, int> sides;

  /// Construcciones puestas (lagos y huertas; town_editor.md § 7), en
  /// coordenadas del pueblo base.
  final List<TownBuild> builds;

  /// Nivel del ayudante de la huerta (0 = sin contratar).
  final int helper;

  /// Granero del ayudante: `cropKey` → cantidad (lo recoge cualquiera).
  final Map<String, int> silo;

  int side(TownSide s) => sides[s] ?? 0;

  /// Ampliaciones compradas en total.
  int get expansions => sides.values.fold(0, (a, b) => a + b);

  /// Dónde cae el tile (0, 0) del pueblo base en el mapa.
  (int, int) get origin =>
      (side(TownSide.oeste) * kTownStrip, side(TownSide.norte) * kTownStrip);

  Iterable<TownBuild> get lakes =>
      builds.where((b) => b.kind == BuildKind.lago);
  Iterable<TownBuild> get farms =>
      builds.where((b) => b.kind == BuildKind.huerta);

  TownBuild? build(String id) => builds.where((b) => b.id == id).firstOrNull;

  /// Peces soltados en todos los lagos juntos.
  Map<String, int> get stock {
    final out = <String, int>{};
    for (final l in lakes) {
      for (final e in l.stock.entries) {
        out[e.key] = (out[e.key] ?? 0) + e.value;
      }
    }
    return out;
  }

  int get stockTotal => lakes.fold(0, (a, l) => a + l.stockTotal);

  static final _plotCache = Expando<Map<String, FarmPlot>>();

  /// Todas las parcelas en coordenadas del mapa (`"x,y"`).
  Map<String, FarmPlot> get plots => _plotCache[this] ??= Map.unmodifiable({
        for (final f in farms)
          for (final e in f.plots.entries)
            if (parsePlotKey(e.key) case (final dx, final dy))
              plotKey(f.anchor.$1 + dx + origin.$1,
                  f.anchor.$2 + dy + origin.$2): e.value,
      });

  /// Reparte parcelas del mapa entre las huertas (las que no caen en
  /// ninguna se descartan).
  List<TownBuild> _withPlots(Map<String, FarmPlot> plots) {
    final per = <String, Map<String, FarmPlot>>{
      for (final f in farms) f.id: {}
    };
    final (ox, oy) = origin;
    for (final e in plots.entries) {
      final xy = parsePlotKey(e.key);
      if (xy == null) continue;
      final tx = xy.$1 - ox, ty = xy.$2 - oy;
      for (final f in farms) {
        if (!f.contains(tx, ty)) continue;
        per[f.id]![plotKey(tx - f.anchor.$1, ty - f.anchor.$2)] = e.value;
        break;
      }
    }
    return [
      for (final b in builds)
        b.kind == BuildKind.huerta ? b.copyWith(plots: per[b.id]) : b
    ];
  }

  TownState copyWith({
    Map<String, int>? upgrades,
    List<Map<String, Object?>>? lostLoot,
    int? cycle,
    List<String>? lake,
    Map<TownSide, int>? sides,
    List<TownBuild>? builds,
    Map<String, FarmPlot>? plots,
    int? helper,
    Map<String, int>? silo,
    Map<String, (int, int)>? marks,
  }) {
    final next = TownState(
        upgrades: upgrades ?? this.upgrades,
        lostLoot: lostLoot ?? this.lostLoot,
        cycle: cycle ?? this.cycle,
        lake: lake ?? this.lake,
        sides: sides ?? this.sides,
        builds: builds ?? this.builds,
        helper: helper ?? this.helper,
        silo: silo ?? this.silo,
        marks: marks ?? this.marks);
    return plots == null
        ? next
        : next.copyWith(builds: next._withPlots(plots));
  }

  /// Lo del pueblo que ven todos en la sala (protocolo 46, `town` del
  /// estado): sin el pozo (viaja aparte) ni las mejoras sin efecto.
  Map<String, Object?> farmJson() => {
        if (lake != null) 'lake': lake,
        if (expansions > 0)
          'sides': {
            for (final e in sides.entries)
              if (e.value > 0) e.key.code: e.value
          },
        'builds': [for (final b in builds) b.toJson()],
        if (helper > 0) 'helper': helper,
        if (silo.isNotEmpty) 'silo': silo,
        if (marks.isNotEmpty)
          'marks': {
            for (final e in marks.entries) e.key: [e.value.$1, e.value.$2]
          },
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

  static Map<String, (int, int)> _marks(Object? v) => v is Map
      ? {
          for (final e in v.entries)
            if (e.value case [final num x, final num y, ...])
              '${e.key}': (x.round(), y.round()),
        }
      : const {};

  /// Tolerante. Saves de v0.23 (`exp`, `zones`, `plots`, `stock`): las
  /// franjas al este pasan a ser ampliaciones al ESTE, cada zona una
  /// construcción en el mismo lugar, las parcelas van a su huerta y los
  /// peces soltados al primer lago (town_editor.md § 7.2).
  static TownState fromJson(Object? raw) {
    if (raw is! Map) return const TownState();
    final up = raw['up'];
    final lost = raw['lost'];
    final base = TownState(
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
      helper: raw['helper'] is num ? (raw['helper'] as num).round() : 0,
      silo: _ints(raw['silo']),
      marks: _marks(raw['marks']),
    );
    final bs = raw['builds'];
    if (bs is List) {
      final sides = raw['sides'];
      final builds = <TownBuild>[];
      for (final b in bs) {
        final tb = TownBuild.fromJson(b);
        if (tb != null && !builds.any((o) => o.id == tb.id)) builds.add(tb);
      }
      return base.copyWith(
        sides: sides is Map
            ? {
                for (final e in sides.entries)
                  if (TownSide.fromCode(e.key) case final s?)
                    if (e.value is num) s: (e.value as num).round().clamp(0, 9),
              }
            : const {},
        builds: builds,
      );
    }
    return _migrate(base, raw);
  }

  static TownState _migrate(TownState base, Map<dynamic, dynamic> raw) {
    final exp =
        raw['exp'] is num ? (raw['exp'] as num).round().clamp(0, 9) : 0;
    final zones = raw['zones'];
    final kinds = zones is List
        ? [
            for (final z in zones)
              if (TownZoneKind.fromName(z) case final k?) k,
          ]
        : const <TownZoneKind>[];
    final builds = [...kDefaultBuilds];
    for (var i = 0; i < kinds.length && i < exp * 2; i++) {
      // Espacio i de v0.23: franja i ~/ 2, norte (par) o sur (impar).
      final x = 33 + kTownStrip * (i ~/ 2), y = i.isEven ? 7 : 14;
      builds.add(kinds[i] == TownZoneKind.lago
          ? TownBuild('l${i + 1}', BuildKind.lago, [TownRect(x, y, 6, 6)])
          : TownBuild(
              'h${i + 1}', BuildKind.huerta, [TownRect(x, y + 1, 6, 4)]));
    }
    builds[0] = builds[0].copyWith(stock: _ints(raw['stock']));
    final plots = raw['plots'];
    return base.copyWith(
      sides: exp > 0 ? {TownSide.este: exp} : const {},
      builds: builds,
      plots: plots is Map
          ? {
              for (final e in plots.entries)
                if (parsePlotKey('${e.key}') != null)
                  '${e.key}': FarmPlot.fromJson(e.value),
            }
          : const {},
    );
  }
}

// Un mundo de la cuenta (`accounts/worlds/<id>.json`).
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
