/// Mundos por cuenta (town_loop.md § 11c, v0.21.0). Un mundo guarda el
/// pueblo; los personajes siguen aparte y entran a cualquier mundo.
library;

import 'dungeon_save.dart';
import 'mine_state.dart';
import 'farm_plot.dart';
import 'npc_bond.dart';
import 'resident.dart';
import 'sky.dart';
import 'town_build.dart';
import 'renown.dart';
import 'world_event.dart';

export 'dungeon_save.dart';
export 'farm_plot.dart';
export 'npc_bond.dart';
export 'resident.dart';
export 'sky.dart';
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
      this.marks = const {},
      this.wild = const {},
      this.waystones = const {},
      this.layoutVersion = 0,
      this.discovery = const {},
      this.lights = const [],
      this.decor = const [],
      this.paths = const {},
      this.sky = const SkyState(),
      this.residents = const {},
      this.daily = const {},
      this.bonds = const {},
      this.dungeons = const {},
      this.events = const WorldEventsState(),
      this.renown = const RenownState(),
      this.mines = const {}});

  /// Mine levels dug, lit and worked in this world (mining_smithing.md
  /// § 1.5). Travel with the town (`mn`) and are saved.
  final MinesState mines;

  /// The state of mine level [place] (empty if nothing changed there).
  MineLevelState mine(String place) =>
      mines[place] ?? const MineLevelState();

  /// [m] saved for [place].
  TownState withMine(String place, MineLevelState m) =>
      copyWith(mines: {...mines, place: m});

  /// World events (world_events.md § 1): travel and are saved (`wev`).
  final WorldEventsState events;

  /// Renown milestones and town events (renown_town_growth.md § 1):
  /// travel and are saved (`rn`).
  final RenownState renown;

  /// Mazmorras de zona del mundo (persistent_dungeons.md), por id de
  /// misión. Solo del anfitrión: se guarda (`dg`) pero no viaja en
  /// `farmJson`.
  final Map<String, DungeonSave> dungeons;

  /// [d] guardada (por su misión).
  TownState withDungeon(DungeonSave d) =>
      copyWith(dungeons: {...dungeons, d.missionId: d});

  /// Lazos con los habitantes (overworld_biomes.md § 12): charlas y,
  /// para los arraigados, amistad y pedidos. JSON `nat`.
  final Map<String, NpcBond> bonds;

  /// El lazo con [npc] (vacío si todavía no hay nada).
  NpcBond bond(String npc) => bonds[npc] ?? NpcBond(npc);

  /// [b] guardado (por su id).
  TownState withBond(NpcBond b) => copyWith(bonds: {...bonds, b.npc: b});

  /// Topes del día del mundo (roles.md § 3 y § 4), guardados en el mundo
  /// para que reabrir la sala no los reinicie: `<jugador>:<día>` → XP de
  /// órdenes dada; `com:<jugador>:<día>` → encargo de forja pedido.
  final Map<String, int> daily;

  /// Habitantes de bioma (overworld_biomes.md § 10): relación, encargos,
  /// pedidos y si viven en el pueblo. Por id del habitante.
  final Map<String, ResidentState> residents;

  /// El estado de [npc] (vacío si todavía no hay nada).
  ResidentState resident(String npc) =>
      residents[npc] ?? ResidentState(npc);

  /// La casa donde vive [npc], o `null`.
  TownBuild? houseOf(String npc) => builds
      .where((b) => b.kind == BuildKind.casa && b.resident == npc)
      .firstOrNull;

  Iterable<TownBuild> get houses =>
      builds.where((b) => b.kind == BuildKind.casa);

  /// Faros puestos en EDITAR PUEBLO (day_night_weather.md § 5): tiles de
  /// 1×1 en coordenadas del pueblo base. No son sólidos ni cortan caminos.
  final List<(int, int)> lights;

  /// Farm decorations (cozy_life.md § 2): `(id of kFarmDecos, x, y)` in
  /// base-town coordinates, 1×1, not solid. JSON `dc`.
  final List<(String, int, int)> decor;

  /// Hand-drawn town paths (town_editor.md § 4.6): base-town tile →
  /// material id (`kTownPaths`). Auto paths are not stored: `TownPlan`
  /// routes them every build and reuses these. JSON `pth`.
  final Map<(int, int), String> paths;

  /// Stable id of the decoration at ([x], [y]).
  static String decorId(int x, int y) => 'deco@$x,$y';

  static (int, int)? parseDecorId(String? id) {
    if (id == null || !id.startsWith('deco@')) return null;
    final p = id.substring(5).split(',');
    if (p.length != 2) return null;
    final x = int.tryParse(p[0]), y = int.tryParse(p[1]);
    return x == null || y == null ? null : (x, y);
  }

  /// Reloj y clima del mundo (day_night_weather.md § 1).
  final SkyState sky;

  /// Id estable del faro en ([x], [y]) (coordenadas del pueblo base).
  static String lightId((int, int) l) => 'faro@${l.$1},${l.$2}';

  static (int, int)? parseLightId(String? id) {
    if (id == null || !id.startsWith('faro@')) return null;
    final p = id.substring(5).split(',');
    if (p.length != 2) return null;
    final x = int.tryParse(p[0]), y = int.tryParse(p[1]);
    return x == null || y == null ? null : (x, y);
  }

  /// Lugares fijos movidos (town_editor.md § 3.3): id del lugar (`@forge`,
  /// …) → esquina en coordenadas del pueblo base. Los que no están, en su
  /// lugar de siempre (`TownLayout.landmarks`).
  final Map<String, (int, int)> marks;

  /// Recolectables de los exteriores ya usados (overworld_biomes.md § 3.2):
  /// `<bioma>:<índice>` → segundo de la sala en que vuelve a crecer.
  /// Al cargar el mundo se recorta al tiempo de rebrote (`setWorld`).
  final Map<String, int> wild;

  /// Activated region waystones (biome_regions.md § 4):
  /// `<player>|<biome>:<index>`, per player. JSON `ws`.
  final Set<String> waystones;

  /// Biome layout generator version the layout-indexed state above
  /// (`wild`, `waystones`) belongs to (biome_exploration.md § 7). JSON `lv`;
  /// 0 = before v2.
  final int layoutVersion;

  /// Overworld map discovery shared by the party (biome_exploration.md
  /// § 11.4): biome id → `w,h,base64` cell bits. JSON `md`.
  final Map<String, String> discovery;

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
    Map<String, (int, int)>? marks,
    List<(int, int)>? lights,
    List<(String, int, int)>? decor,
    Map<(int, int), String>? paths,
    SkyState? sky,
    Map<String, int>? wild,
    Set<String>? waystones,
    int? layoutVersion,
    Map<String, String>? discovery,
    Map<String, ResidentState>? residents,
    Map<String, int>? daily,
    Map<String, NpcBond>? bonds,
    Map<String, DungeonSave>? dungeons,
    WorldEventsState? events,
    RenownState? renown,
    MinesState? mines,
  }) {
    final next = TownState(
        upgrades: upgrades ?? this.upgrades,
        lostLoot: lostLoot ?? this.lostLoot,
        cycle: cycle ?? this.cycle,
        lake: lake ?? this.lake,
        sides: sides ?? this.sides,
        builds: builds ?? this.builds,
        marks: marks ?? this.marks,
        lights: lights ?? this.lights,
        decor: decor ?? this.decor,
        paths: paths ?? this.paths,
        sky: sky ?? this.sky,
        wild: wild ?? this.wild,
        waystones: waystones ?? this.waystones,
        layoutVersion: layoutVersion ?? this.layoutVersion,
        discovery: discovery ?? this.discovery,
        residents: residents ?? this.residents,
        daily: daily ?? this.daily,
        bonds: bonds ?? this.bonds,
        dungeons: dungeons ?? this.dungeons,
        events: events ?? this.events,
        renown: renown ?? this.renown,
        mines: mines ?? this.mines);
    return plots == null
        ? next
        : next.copyWith(builds: next._withPlots(plots));
  }

  /// Lo del pueblo que ven todos en la sala (protocolo 46, `town` del
  /// estado): sin el pozo (viaja aparte) ni las mejoras sin efecto.
  ///
  /// [allMaps] false: only the discovery of [place] (the room snapshot,
  /// biome_exploration.md § 11.4); the save keeps every biome.
  Map<String, Object?> farmJson({String? place, bool allMaps = true}) => {
        if (lake != null) 'lake': lake,
        if (expansions > 0)
          'sides': {
            for (final e in sides.entries)
              if (e.value > 0) e.key.code: e.value
          },
        'builds': [for (final b in builds) b.toJson()],
        if (wild.isNotEmpty) 'wild': wild,
        if (waystones.isNotEmpty) 'ws': (waystones.toList()..sort()),
        if (layoutVersion != 0) 'lv': layoutVersion,
        if (allMaps && discovery.isNotEmpty)
          'md': discovery
        else if (!allMaps && place != null && discovery.containsKey(place))
          'md': {place: discovery[place]},
        if (marks.isNotEmpty)
          'marks': {
            for (final e in marks.entries) e.key: [e.value.$1, e.value.$2]
          },
        if (lights.isNotEmpty) 'lt': [for (final l in lights) [l.$1, l.$2]],
        if (decor.isNotEmpty)
          'dc': [for (final d in decor) [d.$1, d.$2, d.$3]],
        if (paths.isNotEmpty)
          'pth': [
            for (final e in (paths.entries.toList()
              ..sort((a, b) => a.key.$2 != b.key.$2
                  ? a.key.$2 - b.key.$2
                  : a.key.$1 - b.key.$1)))
              [e.value, e.key.$1, e.key.$2]
          ],
        if (sky.started) 'sky': sky.toJson(),
        if (residents.isNotEmpty)
          'res': [
            for (final k in (residents.keys.toList()..sort()))
              residents[k]!.toJson()
          ],
        if (daily.isNotEmpty) 'dy': daily,
        if (!events.isEmpty) 'wev': events.toJson(),
        if (!renown.isEmpty) 'rn': renown.toJson(),
        if (minesToJson(mines) case final mn when mn.isNotEmpty) 'mn': mn,
        if (bonds.isNotEmpty)
          'nat': [
            for (final k in (bonds.keys.toList()..sort())) bonds[k]!.toJson()
          ],
      };

  /// [r] guardado (por su id).
  TownState withResident(ResidentState r) =>
      copyWith(residents: {...residents, r.npc: r});

  /// Una construcción cambiada (por id).
  TownState withBuild(TownBuild b) =>
      copyWith(builds: [for (final o in builds) o.id == b.id ? b : o]);

  Map<String, Object?> toJson() => {
        if (upgrades.isNotEmpty) 'up': upgrades,
        if (lostLoot.isNotEmpty) 'lost': lostLoot,
        if (cycle != 0) 'cycle': cycle,
        ...farmJson(),
        if (dungeons.isNotEmpty)
          'dg': [
            for (final k in (dungeons.keys.toList()..sort()))
              dungeons[k]!.toJson()
          ],
      };

  static Map<String, int> _ints(Object? v) => TownBuild.ints(v);

  /// Saves de antes de v0.25.5 (farming.md § 8.4): el ayudante del pueblo
  /// (`helper`) pasa a ser un granjero de la primera huerta y el granero
  /// (`silo`), el cofre de esa huerta.
  static TownState _legacyHelper(TownState s, Map<dynamic, dynamic> raw) {
    final lvl = raw['helper'] is num ? (raw['helper'] as num).round() : 0;
    final silo = _ints(raw['silo']);
    final f = s.farms.firstOrNull;
    if (f == null || (lvl <= 0 && silo.isEmpty)) return s;
    final chest = {...f.chest};
    for (final e in silo.entries) {
      chest[e.key] = (chest[e.key] ?? 0) + e.value;
    }
    return s.withBuild(f.copyWith(
        helper: f.helper > 0 ? f.helper : (lvl > 0 ? 1 : 0), chest: chest));
  }

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
    return _legacyHelper(_fromJson(raw), raw);
  }

  static TownState _fromJson(Map<dynamic, dynamic> raw) {
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
      wild: _ints(raw['wild']),
      waystones: raw['ws'] is List
          ? {for (final v in raw['ws'] as List) if (v is String) v}
          : const {},
      layoutVersion: raw['lv'] is num ? (raw['lv'] as num).round() : 0,
      discovery: raw['md'] is Map
          ? {
              for (final e in (raw['md'] as Map).entries)
                if (e.value is String) '${e.key}': e.value as String,
            }
          : const {},
      marks: _marks(raw['marks']),
      lights: raw['lt'] is List
          ? {
              for (final v in raw['lt'] as List)
                if (v case [final num x, final num y, ...]) (x.round(), y.round()),
            }.toList()
          : const [],
      // The old 1×1 'stone_path' decoration became a stone path tile
      // (town_editor.md § 4.6).
      decor: raw['dc'] is List
          ? [
              for (final v in raw['dc'] as List)
                if (v case [final String id, final num x, final num y, ...])
                  if (id != 'stone_path') (id, x.round(), y.round()),
            ]
          : const [],
      paths: {
        if (raw['dc'] is List)
          for (final v in raw['dc'] as List)
            if (v case ['stone_path', final num x, final num y, ...])
              (x.round(), y.round()): 'stone',
        if (raw['pth'] is List)
          for (final v in raw['pth'] as List)
            if (v case [final String id, final num x, final num y, ...])
              (x.round(), y.round()): id,
      },
      sky: SkyState.fromJson(raw['sky']),
      events: WorldEventsState.fromJson(raw['wev']),
      renown: RenownState.fromJson(raw['rn']),
      mines: minesFromJson(raw['mn']),
      residents: raw['res'] is List
          ? {
              for (final v in raw['res'] as List)
                if (ResidentState.fromJson(v) case final r?) r.npc: r,
            }
          : const {},
      daily: raw['dy'] is Map
          ? {
              for (final e in (raw['dy'] as Map).entries)
                if (e.value is num) '${e.key}': (e.value as num).round(),
            }
          : const {},
      bonds: raw['nat'] is List
          ? {
              for (final v in raw['nat'] as List)
                if (NpcBond.fromJson(v) case final b?) b.npc: b,
            }
          : const {},
      dungeons: raw['dg'] is List
          ? {
              for (final v in raw['dg'] as List)
                if (DungeonSave.fromJson(v) case final d?) d.missionId: d,
            }
          : const {},
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
