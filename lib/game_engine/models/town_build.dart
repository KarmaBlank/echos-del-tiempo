import 'dart:math' as math;

import 'farm_animal.dart';
import 'farm_plot.dart';

/// Filas o columnas que suma cada ampliación del pueblo (town_editor.md
/// § 2): igual en los cuatro lados.
const kTownStrip = 8;

/// Lado del pueblo por el que se amplía (town_editor.md § 2).
enum TownSide {
  norte('n', 'NORTE'),
  sur('s', 'SUR'),
  este('e', 'ESTE'),
  oeste('o', 'OESTE');

  const TownSide(this.code, this.label);
  final String code;
  final String label;

  static TownSide? fromCode(Object? c) {
    for (final v in values) {
      if (v.code == c || v.name == c) return v;
    }
    return null;
  }
}

/// Tipo de construcción del pueblo (town_editor.md § 3). Lista abierta:
/// cada tipo nuevo suma su entrada en `kConstructions`.
enum BuildKind {
  lago('LAGO'),
  huerta('HUERTA'),

  /// Casa de un habitante (town_editor.md § 3.4, v0.30.0): 3 × 3, con
  /// nivel (1 a `resMaxHouse`) y el habitante que vive ahí.
  casa('CASA'),

  /// Coop and barn (animals.md § 3): a house and a fenced yard with farm
  /// animals.
  gallinero('GALLINERO'),
  establo('ESTABLO'),

  /// The town kitchen (farming.md § 17): one per town, bought with gold
  /// from the CONSTRUIR palette; E at it opens the cooking screen.
  cocina('COCINA'),

  /// The players' own house (player_house.md § 1): a door to an interior
  /// with beds to sleep in.
  home('CASA PROPIA');

  /// Coop or barn.
  bool get ranch => this == gallinero || this == establo;

  /// A solid house with no chest, sign or helpers (resident house,
  /// kitchen or player house).
  bool get house => this == casa || this == cocina || this == home;

  const BuildKind(this.label);
  final String label;

  static BuildKind? fromName(Object? n) {
    for (final v in values) {
      if (v.name == n) return v;
    }
    return null;
  }
}

/// Tarea de un granjero (farming.md § 8.2). Cada vuelta hace una sola: la
/// primera de este orden que tenga algo para hacer en su área.
enum HelperTask {
  plantar('Plantar'),
  regar('Regar'),
  cosechar('Cosechar');

  const HelperTask(this.label);
  final String label;
  int get bit => 1 << index;
}

const kAllHelperTasks = 7;

/// Mejora de un ayudante (farming.md § 8.5, v0.27.0). Cada una es de
/// granjero o de pescador y sube por rangos.
enum HelperUpgrade {
  parcelas('Parcelas', true),
  ritmo('Ritmo', true),
  calidad('Calidad', true),
  hallazgo('Hallazgo', true),
  red('Red', false),
  ritmoRed('Ritmo', false),
  rareza('Rareza', false);

  const HelperUpgrade(this.label, this.farmer);
  final String label;

  /// De granjero (`true`) o de pescador.
  final bool farmer;

  static HelperUpgrade? fromName(Object? n) {
    for (final v in values) {
      if (v.name == n) return v;
    }
    return null;
  }
}

/// Lo de un ayudante en particular (farming.md § 8.5): su XP de trabajo y
/// los rangos de cada mejora. Los ayudantes de antes de v0.27.0 quedan en
/// nivel 1 sin mejoras.
class HelperStat {
  const HelperStat({this.xp = 0, this.ups = const {}});

  final int xp;
  final Map<HelperUpgrade, int> ups;

  int rank(HelperUpgrade u) => ups[u] ?? 0;

  HelperStat copyWith({int? xp, Map<HelperUpgrade, int>? ups}) =>
      HelperStat(xp: xp ?? this.xp, ups: ups ?? this.ups);

  Map<String, Object?> toJson() => {
        if (xp > 0) 'x': xp,
        if (ups.isNotEmpty) 'u': {for (final e in ups.entries) e.key.name: e.value},
      };

  static HelperStat fromJson(Object? raw) {
    if (raw is! Map) return const HelperStat();
    final u = raw['u'];
    return HelperStat(
      xp: raw['x'] is num ? (raw['x'] as num).round().clamp(0, 1 << 30) : 0,
      ups: u is Map
          ? {
              for (final e in u.entries)
                if (HelperUpgrade.fromName(e.key) case final k?)
                  if (e.value is num && (e.value as num) > 0)
                    k: (e.value as num).round().clamp(0, 20),
            }
          : const {},
    );
  }
}

/// Rectángulo de tiles en coordenadas del pueblo base (el origen del
/// pueblo sin ampliar; las ampliaciones al norte y al oeste dan valores
/// negativos).
class TownRect {
  const TownRect(this.x, this.y, this.w, this.h);
  final int x, y, w, h;

  int get right => x + w;
  int get bottom => y + h;

  bool contains(int tx, int ty) =>
      tx >= x && ty >= y && tx < right && ty < bottom;

  bool overlaps(TownRect o) =>
      x < o.right && o.x < right && y < o.bottom && o.y < bottom;

  /// Se tocan o se pisan (lado con lado cuenta; esquina sola no).
  bool touches(TownRect o) {
    final ox = x < o.right && o.x < right;
    final oy = y < o.bottom && o.y < bottom;
    if (ox && oy) return true;
    if (ox && (bottom == o.y || o.bottom == y)) return true;
    if (oy && (right == o.x || o.right == x)) return true;
    return false;
  }

  /// Contorno de la unión de [parts] como segmentos de un tile
  /// `(x0, y0, x1, y1)` en coordenadas de tile: solo los bordes que dan
  /// afuera, así una construcción fundida se ve como una sola (v0.31.2).
  static List<(int, int, int, int)> outline(List<TownRect> parts) {
    bool inside(int x, int y) => parts.any((p) => p.contains(x, y));
    final out = <(int, int, int, int)>[];
    final seen = <(int, int)>{};
    for (final p in parts) {
      for (var y = p.y; y < p.bottom; y++) {
        for (var x = p.x; x < p.right; x++) {
          if (!seen.add((x, y))) continue;
          if (!inside(x, y - 1)) out.add((x, y, x + 1, y));
          if (!inside(x, y + 1)) out.add((x, y + 1, x + 1, y + 1));
          if (!inside(x - 1, y)) out.add((x, y, x, y + 1));
          if (!inside(x + 1, y)) out.add((x + 1, y, x + 1, y + 1));
        }
      }
    }
    return out;
  }

  TownRect inflate(int n) => TownRect(x - n, y - n, w + 2 * n, h + 2 * n);
  TownRect shift(int dx, int dy) => TownRect(x + dx, y + dy, w, h);

  List<int> toJson() => [x, y, w, h];

  static TownRect? fromJson(Object? v) {
    if (v is! List || v.length != 4 || v.any((e) => e is! num)) return null;
    final n = [for (final e in v) (e as num).round()];
    if (n[2] <= 0 || n[3] <= 0 || n[2] > 40 || n[3] > 40) return null;
    return TownRect(n[0], n[1], n[2], n[3]);
  }

  @override
  bool operator ==(Object other) =>
      other is TownRect &&
      other.x == x &&
      other.y == y &&
      other.w == w &&
      other.h == h;

  @override
  int get hashCode => Object.hash(x, y, w, h);

  @override
  String toString() => 'TownRect($x, $y, $w×$h)';
}

/// Una construcción puesta en el pueblo (town_editor.md § 7): un lago
/// (una o más partes, si se fusionó) con sus peces soltados, o una
/// huerta con sus parcelas. Las parcelas van relativas a la esquina
/// [anchor]: al mover la huerta conservan sus cultivos.
class TownBuild {
  const TownBuild(this.id, this.kind, this.parts,
      {this.stock = const {},
      this.plots = const {},
      this.helper = 0,
      this.chest = const {},
      this.seeds = const {},
      this.tasks = const [],
      this.crew = const [],
      this.level = 1,
      this.animals = const [],
      this.hay = 0,
      this.resident});

  /// Farm animals (coops and barns only; animals.md § 4).
  final List<FarmAnimal> animals;

  /// Hay bales in the building's store (coops and barns; animals.md § 6).
  final int hay;

  FarmAnimal? animal(int uid) =>
      animals.where((a) => a.uid == uid).firstOrNull;

  /// Nivel de la casa (solo casas; 1 a `resMaxHouse`).
  final int level;

  /// Habitante que vive en la casa (solo casas; `null` = vacía).
  final String? resident;

  final String id;
  final BuildKind kind;
  final List<TownRect> parts;

  /// Peces soltados (solo lagos): especie → cantidad.
  final Map<String, int> stock;

  /// Parcelas (solo huertas): `"dx,dy"` desde [anchor] → parcela.
  final Map<String, FarmPlot> plots;

  /// Ayudantes contratados en esta construcción (farming.md § 8): los
  /// GRANJEROS de una huerta o los PESCADORES de un lago. Cada uno
  /// atiende su área (`TownRules.helperArea`).
  final int helper;

  /// Cofre al lado del cartel: lo que juntaron los ayudantes. Huerta:
  /// `cropKey` → cantidad; lago: especie → cantidad.
  final Map<String, int> chest;

  /// Semillas que le dieron a los granjeros (solo huertas): cultivo →
  /// cantidad. Plantan solo de acá.
  final Map<String, int> seeds;

  /// Tareas de cada granjero (bits de [HelperTask]); falta = todas.
  final List<int> tasks;

  int taskMask(int i) => i < tasks.length ? tasks[i] : kAllHelperTasks;

  /// Nivel y mejoras de cada ayudante (farming.md § 8.5); falta = nivel 1
  /// sin mejoras.
  final List<HelperStat> crew;

  HelperStat stat(int i) => i < crew.length ? crew[i] : const HelperStat();

  /// [crew] con el ayudante [i] cambiado (rellena hasta [helper]).
  List<HelperStat> crewWith(int i, HelperStat st) => [
        for (var k = 0; k < math.max(helper, i + 1); k++) k == i ? st : stat(k)
      ];

  int get chestTotal => chest.values.fold(0, (a, b) => a + b);
  int get seedTotal => seeds.values.fold(0, (a, b) => a + b);

  /// Rectángulo que encierra todas las partes.
  TownRect get bounds {
    var x0 = parts.first.x, y0 = parts.first.y;
    var x1 = parts.first.right, y1 = parts.first.bottom;
    for (final p in parts.skip(1)) {
      if (p.x < x0) x0 = p.x;
      if (p.y < y0) y0 = p.y;
      if (p.right > x1) x1 = p.right;
      if (p.bottom > y1) y1 = p.bottom;
    }
    return TownRect(x0, y0, x1 - x0, y1 - y0);
  }

  (int, int) get anchor => (bounds.x, bounds.y);

  bool contains(int tx, int ty) => parts.any((p) => p.contains(tx, ty));

  /// Tiles distintos que ocupa (las partes de un lago fusionado se pisan).
  int get area {
    final b = bounds;
    var n = 0;
    for (var y = b.y; y < b.bottom; y++) {
      for (var x = b.x; x < b.right; x++) {
        if (contains(x, y)) n++;
      }
    }
    return n;
  }

  int get stockTotal => stock.values.fold(0, (a, b) => a + b);

  /// Lugares para el cartel, en orden de preferencia (coordenadas del
  /// pueblo; town_editor.md § 4.3): lago a la derecha, huerta 2 tiles a
  /// la izquierda de su esquina. `TownPlan.signOf` elige el primero libre.
  List<(int, int)> get signSpots {
    final b = bounds;
    return kind == BuildKind.lago
        ? [
            (b.right + 1, b.y + 1),
            (b.right, b.y + 1),
            (b.right + 1, b.y + 2),
            (b.x - 2, b.y + 1),
          ]
        : [
            (b.x - 2, b.y),
            (b.x - 2, b.y + 1),
            (b.x - 1, b.y),
            (b.x - 1, b.y + 1),
            (b.right + 1, b.y),
          ];
  }

  TownBuild copyWith(
          {List<TownRect>? parts,
          Map<String, int>? stock,
          Map<String, FarmPlot>? plots,
          int? helper,
          Map<String, int>? chest,
          Map<String, int>? seeds,
          List<int>? tasks,
          List<HelperStat>? crew,
          int? level,
          List<FarmAnimal>? animals,
          int? hay,
          String? resident,
          bool clearResident = false}) =>
      TownBuild(id, kind, parts ?? this.parts,
          level: level ?? this.level,
          animals: animals ?? this.animals,
          hay: hay ?? this.hay,
          resident: clearResident ? null : (resident ?? this.resident),
          stock: stock ?? this.stock,
          plots: plots ?? this.plots,
          helper: helper ?? this.helper,
          chest: chest ?? this.chest,
          seeds: seeds ?? this.seeds,
          tasks: tasks ?? this.tasks,
          crew: crew ?? this.crew);

  /// Movida para que su esquina quede en ([x], [y]).
  TownBuild movedTo(int x, int y) {
    final (ax, ay) = anchor;
    return copyWith(parts: [for (final p in parts) p.shift(x - ax, y - ay)]);
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'k': kind.name,
        'p': [for (final p in parts) p.toJson()],
        if (stock.isNotEmpty) 'st': stock,
        if (plots.isNotEmpty)
          'pl': {for (final e in plots.entries) e.key: e.value.toJson()},
        if (helper > 0) 'hp': helper,
        if (chest.isNotEmpty) 'ch': chest,
        if (seeds.isNotEmpty) 'sd': seeds,
        if (tasks.any((m) => m != kAllHelperTasks)) 'tk': tasks,
        if (crew.any((c) => c.xp > 0 || c.ups.isNotEmpty))
          'cr': [for (final c in crew) c.toJson()],
        if (level > 1) 'lv': level,
        if (resident != null) 'rs': resident,
        if (animals.isNotEmpty) 'an': [for (final a in animals) a.toJson()],
        if (hay > 0) 'hy': hay,
      };

  static Map<String, int> ints(Object? v) => v is Map
      ? {
          for (final e in v.entries)
            if (e.value is num && (e.value as num) > 0)
              '${e.key}': (e.value as num).round(),
        }
      : const {};

  static TownBuild? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final kind = BuildKind.fromName(raw['k']);
    final id = raw['id'];
    final ps = raw['p'];
    if (kind == null || id is! String || ps is! List) return null;
    final parts = [
      for (final p in ps)
        if (TownRect.fromJson(p) case final r?) r,
    ];
    if (parts.isEmpty) return null;
    final st = raw['st'];
    final pl = raw['pl'];
    return TownBuild(id, kind, parts,
        level: raw['lv'] is num ? (raw['lv'] as num).round().clamp(1, 9) : 1,
        resident: raw['rs'] is String ? raw['rs'] as String : null,
        animals: raw['an'] is List
            ? [
                for (final a in raw['an'] as List)
                  if (FarmAnimal.fromJson(a) case final v?) v
              ]
            : const [],
        hay: raw['hy'] is num ? (raw['hy'] as num).round().clamp(0, 9999) : 0,
        stock: ints(st),
        helper: raw['hp'] is num ? (raw['hp'] as num).round().clamp(0, 99) : 0,
        chest: ints(raw['ch']),
        seeds: ints(raw['sd']),
        tasks: raw['tk'] is List
            ? [
                for (final m in raw['tk'] as List)
                  m is num ? m.round() & kAllHelperTasks : kAllHelperTasks
              ]
            : const [],
        crew: raw['cr'] is List
            ? [for (final c in raw['cr'] as List) HelperStat.fromJson(c)]
            : const [],
        plots: pl is Map
            ? {
                for (final e in pl.entries)
                  if (parsePlotKey('${e.key}') != null)
                    '${e.key}': FarmPlot.fromJson(e.value),
              }
            : const {});
  }
}
