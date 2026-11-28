import 'dart:math' as math;

import '../data/construction_catalog.dart';
import '../data/fishing_catalog.dart';
import '../data/town_layout.dart';
import '../data/tuning_catalog.dart';
import '../models/game_map.dart' show Tile;
import '../models/item.dart' show CraftMaterial;
import '../models/player_profile.dart';
import '../models/world_save.dart';
import 'animal_rules.dart';
import 'farming_rules.dart';
import 'helper_rules.dart';
import 'fishing_rules.dart';
import 'life_tree_rules.dart';
import 'town_plan.dart';

//// Costo de una ampliación del pueblo.
typedef ExpansionCost = ({int gold, int esquirlas, int cristales});

/// Reglas del pueblo del mundo (docs/specs/town_editor.md y farming.md
/// § 7–8): ampliaciones por lado, construcciones (poner, mover, fusionar
/// lagos, borrar), peces soltados por lago (capacidad, sesgo de la
/// tabla, cría) y el ayudante de la huerta. Puras; los números en
/// `kTuning[TuningId.town]` (Editor → Balance → Pueblo).
abstract final class TownRules {
  static TuningDef get t => tuning(TuningId.town);

  static int get maxExpansions => t.i('maxExpansions').clamp(0, 16);
  static int get maxPerSide => t.i('maxPerSide').clamp(0, 6);

  /// Costo de la ampliación número [n] (1 = la primera).
  static ExpansionCost cost(int n) => (
        gold: (t.d('expGoldBase') * math.pow(t.d('expGoldMult'), n - 1))
            .round(),
        esquirlas: t.i('expEsquirlas') * n,
        cristales: n >= 2 ? t.i('expCristales') * (n - 1) : 0,
      );

  static String costText(ExpansionCost c) => [
        '₵${c.gold}',
        if (c.esquirlas > 0) '${c.esquirlas} Esquirlas',
        if (c.cristales > 0) '${c.cristales} Cristales de Era',
      ].join(' · ');

  /// Renglones del costo con lo que [p] tiene: (recurso, hace falta,
  /// tiene). Solo los que la ampliación pide (town_editor.md § 1.3).
  static List<({String name, int need, int have})> costLines(
          PlayerProfile p, ExpansionCost c) =>
      [
        (name: 'Oro', need: c.gold, have: p.credits),
        if (c.esquirlas > 0)
          (
            name: 'Esquirlas',
            need: c.esquirlas,
            have: p.materials[CraftMaterial.esquirla] ?? 0
          ),
        if (c.cristales > 0)
          (
            name: 'Cristales de Era',
            need: c.cristales,
            have: p.materials[CraftMaterial.cristal] ?? 0
          ),
      ];

  /// Por qué el pueblo no se puede ampliar más hacia [side] (o `null`).
  static String? sideFull(TownState s, TownSide side) {
    if (s.expansions >= maxExpansions) return 'Límite de ampliación alcanzado';
    if (s.side(side) >= maxPerSide) {
      return 'Límite de este lado';
    }
    return null;
  }

  /// Por qué [p] no puede pagar la próxima ampliación hacia [side].
  static String? cannotExpand(PlayerProfile p, TownState s, TownSide side) {
    final full = sideFull(s, side);
    if (full != null) return full;
    final c = cost(s.expansions + 1);
    if (p.credits < c.gold) return 'Falta oro (${p.credits}/${c.gold})';
    final esq = p.materials[CraftMaterial.esquirla] ?? 0;
    if (esq < c.esquirlas) return 'Faltan Esquirlas ($esq/${c.esquirlas})';
    final cr = p.materials[CraftMaterial.cristal] ?? 0;
    if (cr < c.cristales) return 'Faltan Cristales de Era ($cr/${c.cristales})';
    return null;
  }

  static (PlayerProfile, TownState)? expand(
      PlayerProfile p, TownState s, TownSide side) {
    if (cannotExpand(p, s, side) != null) return null;
    final c = cost(s.expansions + 1);
    final mats = {...p.materials};
    mats[CraftMaterial.esquirla] =
        (mats[CraftMaterial.esquirla] ?? 0) - c.esquirlas;
    mats[CraftMaterial.cristal] =
        (mats[CraftMaterial.cristal] ?? 0) - c.cristales;
    return (
      p.copyWith(credits: p.credits - c.gold, materials: mats),
      s.copyWith(sides: {...s.sides, side: s.side(side) + 1}),
    );
  }

  // ---------------- construcciones ----------------

  /// La construcción que ocupa el tile del mapa ([mx], [my]).
  static TownBuild? buildAt(TownState s, int mx, int my) {
    final (ox, oy) = s.origin;
    return s.builds.where((b) => b.contains(mx - ox, my - oy)).firstOrNull;
  }

  /// La construcción cuyo cartel está en el tile del mapa ([mx], [my]).
  static TownBuild? buildAtSign(TownState s, int mx, int my) {
    final (ox, oy) = s.origin;
    return s.builds
        .where((b) => TownPlan.signOf(s, b) == (mx - ox, my - oy))
        .firstOrNull;
  }

  static String _newId(TownState s, BuildKind k) {
    var n = 0;
    for (final b in s.builds) {
      final v = int.tryParse(b.id.substring(1)) ?? 0;
      if (v >= n) n = v + 1;
    }
    return '${switch (k) {
      BuildKind.lago => 'l',
      BuildKind.huerta => 'h',
      BuildKind.casa => 'c',
      BuildKind.gallinero => 'g',
      BuildKind.establo => 'e',
      BuildKind.home => 'p',
    }}$n';
  }

  static Map<String, int> _sum(Map<String, int> a, Map<String, int> b) {
    final out = {...a};
    for (final e in b.entries) {
      out[e.key] = (out[e.key] ?? 0) + e.value;
    }
    return out;
  }

  /// [a] y [b] fundidos en uno con el id de [a] (partes de [a] primero):
  /// suma peces, ayudantes, cofres y semillas; las parcelas de una huerta
  /// se pasan a la esquina nueva y conservan sus cultivos (§ 4.2).
  static TownBuild _merge(TownBuild a, TownBuild b) {
    final parts = [...a.parts, ...b.parts];
    var out = TownBuild(a.id, a.kind, parts,
        stock: _sum(a.stock, b.stock),
        helper: a.helper + b.helper,
        chest: _sum(a.chest, b.chest),
        seeds: _sum(a.seeds, b.seeds),
        tasks: [
          for (var k = 0; k < a.helper; k++) a.taskMask(k),
          for (var k = 0; k < b.helper; k++) b.taskMask(k),
        ],
        crew: [
          for (var k = 0; k < a.helper; k++) a.stat(k),
          for (var k = 0; k < b.helper; k++) b.stat(k),
        ]);
    if (a.kind == BuildKind.huerta) {
      final (nx, ny) = out.anchor;
      final plots = <String, FarmPlot>{};
      for (final src in [a, b]) {
        final (sx, sy) = src.anchor;
        for (final e in src.plots.entries) {
          final xy = parsePlotKey(e.key);
          if (xy == null) continue;
          plots[plotKey(xy.$1 + sx - nx, xy.$2 + sy - ny)] = e.value;
        }
      }
      out = out.copyWith(plots: plots);
    }
    return out;
  }

  /// Pone [b] en el pueblo; si toca otras construcciones del mismo tipo
  /// (lagos o huertas), se funden en una (se queda con el id de la
  /// primera; § 4.2).
  static (TownState, String) _put(TownState s, TownBuild b) {
    final rest = [...s.builds.where((o) => o.id != b.id)];
    var merged = b;
    final at = s.builds.indexWhere((o) => o.id == b.id);
    var index = at < 0 ? rest.length : at;
    {
      var grew = true;
      while (grew) {
        grew = false;
        for (final o in [...rest]) {
          if (o.kind != b.kind ||
              b.kind == BuildKind.casa ||
              b.kind == BuildKind.home ||
              b.kind.ranch) {
            continue;
          }
          final touch = o.parts
              .any((p) => merged.parts.any((q) => p.touches(q)));
          if (!touch) continue;
          // La más grande se queda con id, cartel y cofre (empate: la
          // que estaba antes en la lista).
          final first = o.area > merged.area ||
              (o.area == merged.area && rest.indexOf(o) < index);
          merged = first ? _merge(o, merged) : _merge(merged, o);
          final oi = rest.indexOf(o);
          rest.removeAt(oi);
          if (oi < index) index = oi;
          grew = true;
        }
      }
    }
    rest.insert(index.clamp(0, rest.length), merged);
    return (s.copyWith(builds: rest), merged.id);
  }

  /// Por qué [next] no es un pueblo válido tras cambiar [id] (o `null`):
  /// dentro del pueblo, sin pisar caminos fijos, lugares, otras
  /// construcciones ni carteles, y con camino a todo (§ 3.2).
  static String? _invalid(TownState next, String id) {
    final b = next.build(id);
    if (b == null) return 'No existe';
    final w = TownPlan.widthOf(next), h = TownPlan.heightOf(next);
    final (ox, oy) = next.origin;
    // Un tile de borde (la fila de árboles); la huerta base llega hasta
    // la anteúltima fila, así que con dos de margen no podía volver a su
    // propio lugar (v0.24.2).
    bool inside(int x, int y) =>
        x + ox >= 1 && y + oy >= 1 && x + ox < w - 1 && y + oy < h - 1;
    final bb = b.bounds;
    final (sx, sy) = TownPlan.signOf(next, b);
    if (!inside(bb.x, bb.y) ||
        !inside(bb.right - 1, bb.bottom - 1) ||
        !inside(sx, sy)) {
      return 'Fuera del pueblo: ampliá hacia ese lado';
    }
    final sign = TownRect(sx, sy, 1, 1);
    for (final r in TownPlan.reserved(next)) {
      if (b.parts.any((p) => p.overlaps(r)) || sign.overlaps(r)) {
        return 'Ahí hay un camino o un lugar del pueblo';
      }
    }
    for (final o in next.builds) {
      if (o.id == id) continue;
      final os = TownPlan.signOf(next, o);
      if (o.parts.any((p) => b.parts.any((q) => p.overlaps(q)))) {
        return 'Se pisa con otra construcción';
      }
      if (o.contains(sx, sy) || b.contains(os.$1, os.$2) || os == (sx, sy)) {
        return 'Se pisa con un cartel';
      }
    }
    if (TownPlan.of(next).unreached.isNotEmpty) {
      return 'Así queda algo sin camino';
    }
    return null;
  }

  /// Poner una construcción del catálogo con su esquina en el tile del
  /// mapa ([mx], [my]). Devuelve el pueblo nuevo y el id, o el motivo.
  static ({TownState? town, String? id, String? error}) place(
      TownState s, String defId, int mx, int my) {
    final def = construction(defId);
    if (def == null) return (town: null, id: null, error: 'No existe');
    final (ox, oy) = s.origin;
    final b = TownBuild(_newId(s, def.kind), def.kind,
        [TownRect(mx - ox, my - oy, def.w, def.h)]);
    final (next, id) = _put(s, b);
    final err = _invalid(next, id);
    return err == null
        ? (town: next, id: id, error: null)
        : (town: null, id: null, error: err);
  }

  /// Mover [id] para que su esquina quede en el tile del mapa ([mx],
  /// [my]); las parcelas viajan con la huerta.
  static ({TownState? town, String? id, String? error}) move(
      TownState s, String id, int mx, int my) {
    if (TownLayout.byId(id) != null) return moveLandmark(s, id, mx, my);
    final b = s.build(id);
    if (b == null) return (town: null, id: null, error: 'No existe');
    final (ox, oy) = s.origin;
    final (next, nid) = _put(s, b.movedTo(mx - ox, my - oy));
    final err = _invalid(next, nid);
    return err == null
        ? (town: next, id: nid, error: null)
        : (town: null, id: null, error: err);
  }

  /// Un rayo en la parcela [key] (tile del mapa): vuelve a pasto sin arar
  /// y se pierde lo plantado (day_night_weather.md § 3.3).
  static TownState strike(TownState s, String key) {
    if (!s.plots.containsKey(key)) return s;
    return s.copyWith(plots: {...s.plots}..remove(key));
  }

  // ---------------- faros (day_night_weather.md § 5) ----------------

  static int get faroCost => t.i('faroCost');

  /// El faro en el tile del mapa ([mx], [my]), o `null`.
  static (int, int)? lightAt(TownState s, int mx, int my) {
    final (ox, oy) = s.origin;
    final l = (mx - ox, my - oy);
    return s.lights.contains(l) ? l : null;
  }

  /// Por qué no entra un faro en el tile del pueblo base ([x], [y])
  /// (o `null`). Va en pasto o camino: no pisa lugares, construcciones,
  /// carteles, cofres ni otro faro; no es sólido, así que no corta nada.
  static String? lightError(TownState s, int x, int y, {(int, int)? ignore}) {
    final w = TownPlan.widthOf(s), h = TownPlan.heightOf(s);
    final (ox, oy) = s.origin;
    if (x + ox < 2 || y + oy < 2 || x + ox >= w - 2 || y + oy >= h - 2) {
      return 'Fuera del pueblo';
    }
    for (final l in TownPlan.landmarksOf(s)) {
      if (TownRect(l.x, l.y, l.w, l.h).contains(x, y)) {
        return 'Ahí hay un lugar del pueblo';
      }
    }
    for (final b in s.builds) {
      if (b.contains(x, y)) return 'Se pisa con una construcción';
      if (TownPlan.signOf(s, b) == (x, y) || chestOf(s, b) == (x, y)) {
        return 'Se pisa con un cartel o un cofre';
      }
    }
    if (s.lights.any((l) => l != ignore && l == (x, y))) {
      return 'Ya hay un faro';
    }
    if (ignore == null && s.decor.any((d) => d.$2 == x && d.$3 == y)) {
      return 'Ya hay una decoración';
    }
    final tile = TownPlan.of(s).at(x + ox, y + oy);
    if (tile != Tile.grass && tile != Tile.path) return 'Ahí no entra';
    return null;
  }

  /// Comprar y poner un faro en el tile del mapa ([mx], [my]).
  static (PlayerProfile, TownState)? placeLight(
      PlayerProfile p, TownState s, int mx, int my) {
    final (ox, oy) = s.origin;
    if (lightError(s, mx - ox, my - oy) != null) return null;
    if (p.credits < faroCost) return null;
    return (
      p.copyWith(credits: p.credits - faroCost),
      s.copyWith(lights: [...s.lights, (mx - ox, my - oy)]),
    );
  }

  static TownState? moveLight(TownState s, String id, int mx, int my) {
    final from = TownState.parseLightId(id);
    if (from == null || !s.lights.contains(from)) return null;
    final (ox, oy) = s.origin;
    final to = (mx - ox, my - oy);
    if (lightError(s, to.$1, to.$2, ignore: from) != null) return null;
    return s.copyWith(
        lights: [for (final l in s.lights) l == from ? to : l]);
  }

  /// Borrar un faro (sin devolver el oro).
  static TownState? removeLight(TownState s, String id) {
    final l = TownState.parseLightId(id);
    if (l == null || !s.lights.contains(l)) return null;
    return s.copyWith(lights: [...s.lights.where((o) => o != l)]);
  }

  // ---------------- lugares fijos ----------------

  /// El lugar del pueblo que ocupa el tile del mapa ([mx], [my]).
  static TownLandmark? landmarkAt(TownState s, int mx, int my) {
    final (ox, oy) = s.origin;
    final tx = mx - ox, ty = my - oy;
    return TownPlan.landmarksOf(s)
        .where((l) => tx >= l.x && ty >= l.y && tx < l.x + l.w && ty < l.y + l.h)
        .firstOrNull;
  }

  /// Mover el lugar [id] (`@forge`, …) con su esquina en el tile del mapa
  /// ([mx], [my]) (town_editor.md § 3.3). Los lugares no se borran.
  static ({TownState? town, String? id, String? error}) moveLandmark(
      TownState s, String id, int mx, int my) {
    final def = TownLayout.byId(id);
    if (def == null) return (town: null, id: null, error: 'No existe');
    final (ox, oy) = s.origin;
    final x = mx - ox, y = my - oy;
    final marks = {...s.marks}..remove(id);
    if ((x, y) != (def.x, def.y)) marks[id] = (x, y);
    final next = s.copyWith(marks: marks);
    final err = _invalidLandmarks(next, id);
    return err == null
        ? (town: next, id: id, error: null)
        : (town: null, id: null, error: err);
  }

  /// Por qué [next] no es válido tras mover el lugar [id] (o `null`).
  /// Revisa todo el pueblo: al mover un lugar cambian los caminos fijos.
  static String? _invalidLandmarks(TownState next, String id) {
    final w = TownPlan.widthOf(next), h = TownPlan.heightOf(next);
    final (ox, oy) = next.origin;
    bool inside(TownRect r) =>
        r.x + ox >= 1 &&
        r.y + oy >= 1 &&
        r.right + ox <= w - 1 &&
        r.bottom + oy <= h - 1;
    final marks = TownPlan.landmarksOf(next);
    final l = marks.firstWhere((m) => m.id == id);
    final lr = TownRect(l.x, l.y, l.w, l.h);
    if (!inside(lr)) return 'Fuera del pueblo: ampliá hacia ese lado';
    final fixed = TownPlan.fixedPaths(next);
    if (l.spot == TownSpot.fountain) {
      // El anillo y el tile de aparición al sur tienen que entrar.
      if (!inside(fixed.first) ||
          !inside(TownRect(l.x, l.y + 4, 2, 1))) {
        return 'La plaza de la fuente no entra ahí';
      }
    }
    for (final o in marks) {
      final or = TownRect(o.x, o.y, o.w, o.h);
      if (o.id != id && or.inflate(1).overlaps(lr)) {
        return 'Se pisa con otro lugar del pueblo';
      }
      if (o.spot != TownSpot.fountain && fixed.any(or.overlaps)) {
        return o.id == id
            ? 'Ahí está la plaza de la fuente'
            : 'La plaza de la fuente pisa otro lugar';
      }
    }
    final res = TownPlan.reserved(next);
    for (final b in next.builds) {
      final (sx, sy) = TownPlan.signOf(next, b);
      final sign = TownRect(sx, sy, 1, 1);
      for (final r in res) {
        if (b.parts.any((p) => p.overlaps(r)) || sign.overlaps(r)) {
          return 'Se pisa con una construcción o su cartel';
        }
      }
    }
    if (TownPlan.of(next).unreached.isNotEmpty) {
      return 'Así queda algo sin camino';
    }
    return null;
  }

  /// Borrar [id]. Lago: se pierden sus peces. Huerta: cada parcela
  /// plantada le devuelve su semilla a [p] (la opción amable, § 5.3).
  static (PlayerProfile, TownState)? remove(
      PlayerProfile p, TownState s, String id) {
    final b = s.build(id);
    if (b == null || AnimalRules.cannotRemove(b) != null) return null;
    // Lo del cofre va a quien borra.
    var prof = collectChest(p, s, id)?.$1 ?? p;
    if (b.kind == BuildKind.huerta) {
      // Las parcelas plantadas y las semillas de los granjeros vuelven.
      final seeds = _sum(prof.life.farm.seeds, b.seeds);
      for (final pl in b.plots.values) {
        final sd = pl.seed;
        if (sd != null) seeds[sd] = (seeds[sd] ?? 0) + 1;
      }
      prof = prof.copyWith(
          life: prof.life.copyWith(farm: prof.life.farm.copyWith(seeds: seeds)));
    }
    return (prof, s.copyWith(builds: [...s.builds.where((o) => o.id != id)]));
  }

  /// Semillas que vuelven al borrar la huerta [b].
  static int seedsBack(TownBuild b) =>
      b.plots.values.where((p) => p.planted).length + b.seedTotal;

  /// Texto del cartel de una huerta (§ 6): cada cultivo plantado una
  /// vez y «6 de 12 parcelas».
  static String farmSignText(TownBuild f) {
    final seeds = <String>{};
    var planted = 0;
    for (final pl in f.plots.values) {
      final sd = pl.seed;
      if (sd == null) continue;
      seeds.add(sd);
      planted++;
    }
    final crops = [for (final id in seeds) kCrops[id]?.name ?? id];
    return '${crops.isEmpty ? 'Sin cultivos' : crops.join(', ')} · '
        '$planted de ${f.area} parcelas\n${helperLine(f)}'
        '${f.helper > 0 ? ' · ${f.seedTotal} semillas para plantar' : ''}'
        '\nCofre: ${f.chestTotal}';
  }

  /// Texto del cartel de un lago (§ 6): cada especie una vez y los
  /// soltados.
  static String lakeSignText(TownState s, TownBuild l) {
    final base = s.lake ?? kTownLakeDefault;
    final names = [
      for (final id in {...base, ...l.stock.keys})
        if (kFish[id] case final f?) f.name,
    ];
    return '${names.join(', ')} · ${l.stockTotal}/${lakeCapacity(l)} '
        'soltados\n${helperLine(l)}\nCofre: ${l.chestTotal}';
  }

  // ---------------- lagos ----------------

  static int lakeCapacity(TownBuild l) => math.max(
      t.i('lakeMin'), (l.area * t.d('lakePerTile')).round());

  /// El lago más cercano al punto del mapa ([px], [py]) en px.
  static TownBuild? lakeNear(TownState s, double px, double py) {
    final (ox, oy) = s.origin;
    final tx = px / 16 - ox, ty = py / 16 - oy;
    TownBuild? best;
    var bd = double.infinity;
    for (final l in s.lakes) {
      for (final p in l.parts) {
        final dx = math.max(math.max(p.x - tx, 0.0), tx - p.right);
        final dy = math.max(math.max(p.y - ty, 0.0), ty - p.bottom);
        final d = dx * dx + dy * dy;
        if (d < bd) (bd, best) = (d, l);
      }
    }
    return best;
  }

  /// Suelta un [species] de la bolsa de [p] en el lago [lakeId] (o el
  /// primero).
  static (PlayerProfile, TownState)? stock(
      PlayerProfile p, TownState s, String species, [String? lakeId]) {
    final f = kFish[species];
    if (f == null || f.biome == kWaterJunkBiome || p.life.count(species) < 1) {
      return null;
    }
    final l = lakeId == null ? s.lakes.firstOrNull : s.build(lakeId);
    if (l == null || l.kind != BuildKind.lago) return null;
    if (l.stockTotal >= lakeCapacity(l)) return null;
    final nl = l.copyWith(stock: {...l.stock, species: (l.stock[species] ?? 0) + 1});
    return (
      p.copyWith(
          life: p.life
              .copyWith(bag: {...p.life.bag, species: p.life.count(species) - 1})),
      s.copyWith(builds: [for (final b in s.builds) b.id == l.id ? nl : b]),
    );
  }

  /// Las especies para la tirada en [lake] (o con los peces de todos los
  /// lagos): las del pueblo más las soltadas, y cada soltada repetida.
  static List<String> lakeRoll(TownState s, [TownBuild? lake]) {
    final base = s.lake ?? kTownLakeDefault;
    final w = t.i('stockWeight');
    final cap = t.i('stockWeightCap');
    final stock = lake?.stock ?? s.stock;
    return [
      ...base,
      for (final e in stock.entries)
        if (kFish.containsKey(e.key)) ...[
          if (!base.contains(e.key)) e.key,
          for (var i = 0; i < math.min(cap, e.value * w); i++) e.key,
        ],
    ];
  }

  /// Bonus de rareza de [lake] (o del más grande): tamaño por encima del
  /// lago base y especies criando (≥ 2).
  static double lakeRare(TownState s, [TownBuild? lake]) {
    final l = lake ??
        s.lakes.fold<TownBuild?>(
            null, (a, b) => a == null || b.area > a.area ? b : a);
    if (l == null) return 0;
    final breeding = l.stock.values.where((n) => n >= 2).length;
    return t.d('lakeZoneRare') * math.max(0, l.area - 48) / 36 +
        math.min(t.d('breedRareCap'), t.d('breedRare') * breeding);
  }

  /// Misión ganada: en cada lago, las especies con pareja pueden criar.
  static TownState breed(double Function() rand, TownState s) {
    return s.copyWith(builds: [
      for (final b in s.builds)
        if (b.kind != BuildKind.lago)
          b
        else
          () {
            final out = {...b.stock};
            var total = b.stockTotal;
            final cap = lakeCapacity(b);
            for (final e in b.stock.entries) {
              if (e.value < 2 || total >= cap) continue;
              if (rand() < t.d('breedChance')) {
                out[e.key] = e.value + 1;
                total++;
              }
            }
            return b.copyWith(stock: out);
          }(),
    ]);
  }

  // ---------------- ayudantes (farming.md § 8, v0.25.5) ----------------

  static int get helperCost => t.i('helperCost');

  /// Cuántos ayudantes entran en [b]: uno cada `helperPlots` tiles de
  /// huerta o cada `fisherTiles` tiles de lago (redondeo para arriba).
  static int helperCap(TownBuild b) {
    if (b.kind.ranch) return AnimalRules.helperCap;
    final per = math.max(1,
        b.kind == BuildKind.huerta ? t.i('helperPlots') : t.i('fisherTiles'));
    return (b.area + per - 1) ~/ per;
  }

  /// Tiles de la huerta en orden (fila por fila), relativos a la esquina.
  static List<(int, int)> farmTiles(TownBuild b) {
    final bb = b.bounds;
    return [
      for (var y = bb.y; y < bb.bottom; y++)
        for (var x = bb.x; x < bb.right; x++)
          if (b.contains(x, y)) (x - bb.x, y - bb.y),
    ];
  }

  /// El área del granjero [i] de [b]: `helperPlots` tiles seguidos (fila
  /// por fila), sin pisarse con los demás. Relativos a la esquina.
  /// Con la mejora Parcelas (§ 8.5) cada uno atiende más: las áreas
  /// siguen una detrás de la otra.
  static List<(int, int)> helperArea(TownBuild b, int i) {
    final all = farmTiles(b);
    var a = 0;
    for (var k = 0; k < i; k++) {
      a += HelperRules.plotsOf(b, k);
    }
    a = a.clamp(0, all.length);
    final z = (a + HelperRules.plotsOf(b, i)).clamp(0, all.length);
    return all.sublist(a, z);
  }

  /// La orilla de [b] (tiles de afuera pegados al lago, en coordenadas
  /// del pueblo base), en el orden del borde.
  static List<(int, int)> shoreTiles(TownBuild b) {
    final r = b.bounds.inflate(1);
    final ring = <(int, int)>[
      for (var x = r.x; x < r.right; x++) (x, r.y),
      for (var y = r.y + 1; y < r.bottom; y++) (r.right - 1, y),
      for (var x = r.right - 2; x >= r.x; x--) (x, r.bottom - 1),
      for (var y = r.bottom - 2; y > r.y; y--) (r.x, y),
    ];
    return [
      for (final p in ring)
        if (!b.contains(p.$1, p.$2)) p
    ];
  }

  /// El lugar de pesca del pescador [i] de [b] (farming.md § 8.1): un
  /// tile de la orilla pegado al agua (de lado, nunca en diagonal), libre
  /// de otras construcciones, del cartel y del cofre; el primero, el más
  /// cercano al cartel y su cofre, los demás cada vez más lejos.
  static (int, int) fisherSpot(TownState s, TownBuild b, int i) {
    final ring = fisherSpots(s, b);
    if (ring.isEmpty) return shoreTiles(b).first;
    return ring[i % ring.length];
  }

  /// Todos los lugares de pesca válidos de [b] (ver [fisherSpot]),
  /// ordenados del más cercano al cartel al más lejano.
  static List<(int, int)> fisherSpots(TownState s, TownBuild b) {
    final sign = TownPlan.signOf(s, b), chest = chestOf(s, b);
    bool wet(int x, int y) => b.contains(x, y);
    final ring = [
      for (final (x, y) in shoreTiles(b))
        if ((wet(x + 1, y) || wet(x - 1, y) || wet(x, y + 1) || wet(x, y - 1)) &&
            (x, y) != sign &&
            (x, y) != chest &&
            !s.builds.any((o) => o.contains(x, y)))
          (x, y)
    ];
    int d((int, int) p) =>
        (p.$1 - sign.$1).abs() + (p.$2 - sign.$2).abs();
    ring.sort((a, z) {
      final c = d(a).compareTo(d(z));
      if (c != 0) return c;
      final cy = a.$2.compareTo(z.$2);
      return cy != 0 ? cy : a.$1.compareTo(z.$1);
    });
    return ring;
  }

  /// Tramo de lugares del segundo [time] (farming.md § 8.1): cada
  /// `fisherMoveSec` los pescadores cambian de lugar en la orilla.
  static int fisherSegment(double time) =>
      (time / math.max(1.0, t.d('fisherMoveSec'))).floor();

  /// El lugar del pescador [i] de [b] en el tramo [seg]: todos se corren
  /// el mismo salto por la lista de [fisherSpots], así nunca comparten
  /// lugar (si entran). Determinista: igual en todos los clientes.
  static (int, int) fisherSpotAt(TownState s, TownBuild b, int i, int seg) {
    final ring = fisherSpots(s, b);
    if (ring.isEmpty) return shoreTiles(b).first;
    final n = ring.length;
    final step = n > 2 ? (n ~/ 3).clamp(1, n - 1) : 1;
    return ring[(i + seg * step) % n];
  }

  /// Camino por la orilla (en el orden del borde) de [a] a [z], por el
  /// lado más corto; incluye los dos extremos.
  static List<(int, int)> shorePath(TownBuild b, (int, int) a, (int, int) z) {
    final ring = shoreTiles(b);
    final ia = ring.indexOf(a), iz = ring.indexOf(z);
    if (ia < 0 || iz < 0 || ia == iz) return [a, z];
    final n = ring.length;
    final fwd = (iz - ia) % n, back = (ia - iz) % n;
    final dir = fwd <= back ? 1 : -1;
    final len = math.min(fwd, back);
    return [for (var k = 0; k <= len; k++) ring[(ia + dir * k) % n]];
  }

  /// Dónde está el pescador [i] de [b] en el segundo [time] (tiles del
  /// pueblo base, con decimales): quieto en su lugar del tramo o, al
  /// empezar un tramo nuevo, caminando por la orilla desde el anterior
  /// (`fisherWalkTileSec` por tile). `walk`: va caminando; `dx`: hacia
  /// dónde camina (-1, 0, 1).
  static ({double x, double y, bool walk, int dx}) fisherAt(
      TownState s, TownBuild b, int i, double time) {
    final seg = fisherSegment(time);
    final z = fisherSpotAt(s, b, i, seg);
    if (seg > 0) {
      final a = fisherSpotAt(s, b, i, seg - 1);
      if (a != z) {
        final path = shorePath(b, a, z);
        final per = math.max(0.05, t.d('fisherWalkTileSec'));
        final local = time - seg * math.max(1.0, t.d('fisherMoveSec'));
        final k = local / per;
        if (k < path.length - 1) {
          final j = k.floor().clamp(0, path.length - 2);
          final f = k - j;
          final p = path[j], q = path[j + 1];
          return (
            x: p.$1 + (q.$1 - p.$1) * f,
            y: p.$2 + (q.$2 - p.$2) * f,
            walk: true,
            dx: (q.$1 - p.$1).sign,
          );
        }
      }
    }
    return (x: z.$1.toDouble(), y: z.$2.toDouble(), walk: false, dx: 0);
  }

  /// El pescador está en su momento de pesca (farming.md § 8.1): los
  /// primeros `fisherCatchSec` después de cada vuelta de los ayudantes
  /// (la misma vuelta del motor, alineada al reloj de la sala con
  /// [period] = [helperPeriod]).
  static bool fisherCatching(double time, double period) =>
      time >= period && time % period < t.d('fisherCatchSec');

  /// Desplazamiento de respiración del pescador quieto en px (0 o -1)
  /// según el reloj de animación [ms].
  static double fisherBreath(double ms) =>
      (ms / (math.max(0.1, t.d('fisherBreathSec')) * 1000)).floor() % 2 == 0
          ? 0
          : -1;

  /// Hacia dónde mira el pescador [i] de [b] (farming.md § 8.1): el paso
  /// (dx, dy) de su lugar al tile de agua pegado por un lado (primero
  /// izquierda/derecha, después abajo, después arriba). Se calcula en cada
  /// cliente, no viaja por la red.
  static (int, int) fisherFacing(TownState s, TownBuild b, int i,
      [double? time]) {
    final (x, y) = time == null
        ? fisherSpot(s, b, i)
        : fisherSpotAt(s, b, i, fisherSegment(time));
    for (final d in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
      if (b.contains(x + d.$1, y + d.$2)) return d;
    }
    // Sin agua al lado (no debería pasar): hacia el centro del lago.
    final bb = b.bounds;
    final cx = bb.x + bb.w / 2, cy = bb.y + bb.h / 2;
    final dx = cx - (x + 0.5), dy = cy - (y + 0.5);
    if (dx.abs() >= dy.abs()) return (dx < 0 ? -1 : 1, 0);
    return (0, dy < 0 ? -1 : 1);
  }

  /// Dónde está el ayudante [i] de [b] en el segundo [time] de la sala
  /// (px del mapa). Igual en todos los clientes: el granjero camina por
  /// su área, parcela por parcela; el pescador se queda en su lugar de la
  /// orilla. `work`: está trabajando (riega o tira la caña).
  static ({double x, double y, bool work}) helperPos(
      TownState s, TownBuild b, int i, double time) {
    final (ox, oy) = s.origin;
    final (ax, ay) = b.anchor;
    // Bloqueado (§ 8.6): se queda quieto, sin trabajar.
    final stuck = HelperRules.blocked(b, i);
    if (b.kind.ranch) {
      // Ranch helper (animals.md § 6): strolls the yard tile by tile.
      final yard = AnimalRules.pastureTiles(b);
      if (yard.isEmpty) {
        return (x: (ax + ox + 0.5) * 16, y: (ay + oy + 0.5) * 16, work: false);
      }
      final k = time / 5 + i * 2.3;
      final n = yard.length;
      final a = yard[(k.floor() * 7) % n], z = yard[((k.floor() + 1) * 7) % n];
      final f = k - k.floor();
      final m = f < 0.6 ? 0.0 : (f - 0.6) / 0.4;
      return (
        x: (a.$1 + (z.$1 - a.$1) * m + ox + 0.5) * 16,
        y: (a.$2 + (z.$2 - a.$2) * m + oy + 0.5) * 16,
        work: f < 0.6
      );
    }
    if (b.kind == BuildKind.lago) {
      final p = fisherAt(s, b, i, time);
      return (
        x: (p.x + ox + 0.5) * 16,
        y: (p.y + oy + 0.5) * 16,
        work: !stuck && !p.walk
      );
    }
    final area = helperArea(b, i);
    if (stuck && area.isNotEmpty) {
      final (x, y) = area.first;
      return (x: (ax + x + ox + 0.5) * 16, y: (ay + y + oy + 0.5) * 16, work: false);
    }
    if (area.isEmpty) {
      return (x: (ax + ox - 0.5) * 16, y: (ay + oy + 0.5) * 16, work: false);
    }
    const step = 4.0;
    final k = time / step + i * 1.7;
    final n = area.length;
    final a = area[k.floor() % n], z = area[(k.floor() + 1) % n];
    final f = k - k.floor();
    // Primero trabaja (60 %), después camina a la próxima parcela.
    final m = f < 0.6 ? 0.0 : (f - 0.6) / 0.4;
    final x = a.$1 + (z.$1 - a.$1) * m, y = a.$2 + (z.$2 - a.$2) * m;
    return (
      x: (ax + x + ox + 0.5) * 16,
      y: (ay + y + oy + 0.5) * 16,
      work: f < 0.6
    );
  }

  /// El ayudante a [r] px o menos de ([x], [y]), o `null`.
  static ({TownBuild build, int index})? helperNear(
      TownState s, double x, double y, double time,
      {double r = 14}) {
    for (final b in s.builds) {
      for (var i = 0; i < b.helper; i++) {
        final p = helperPos(s, b, i, time);
        if ((p.x - x).abs() <= r && (p.y - 4 - y).abs() <= r + 4) {
          return (build: b, index: i);
        }
      }
    }
    return null;
  }

  /// El tile del cofre de [b] (coordenadas del pueblo base): siempre al
  /// lado del cartel, en la misma fila (nunca arriba ni abajo; v0.32.2).
  /// Primero del lado que no mira a la construcción; si ese lado sale del
  /// pueblo, pisa otra construcción, otro cartel o un camino fijo, el
  /// otro. Si los dos están tomados, el primero libre de construcciones y
  /// carteles (aunque sea camino) y, en último caso, el de afuera.
  static (int, int) chestOf(TownState s, TownBuild b) {
    final (sx, sy) = TownPlan.signOf(s, b);
    final bb = b.bounds;
    // Lado de afuera: lejos del centro de la construcción.
    final out = sx * 2 >= bb.x + bb.right - 1 ? 1 : -1;
    final sides = [(sx + out, sy), (sx - out, sy)];
    final w = TownPlan.widthOf(s), h = TownPlan.heightOf(s);
    final (ox, oy) = s.origin;
    bool inside(int x, int y) =>
        x + ox >= 1 && y + oy >= 1 && x + ox < w - 1 && y + oy < h - 1;
    bool free(int x, int y) =>
        inside(x, y) &&
        !s.builds.any((o) => o.contains(x, y)) &&
        !s.builds.any((o) => TownPlan.signOf(s, o) == (x, y));
    final res = TownPlan.reserved(s);
    for (final (x, y) in sides) {
      if (!free(x, y)) continue;
      final r = TownRect(x, y, 1, 1);
      if (res.any((o) => o.overlaps(r))) continue;
      return (x, y);
    }
    for (final (x, y) in sides) {
      if (free(x, y)) return (x, y);
    }
    return sides.first;
  }

  /// La construcción cuyo cofre está a [r] px o menos de ([x], [y]).
  static TownBuild? chestNear(TownState s, double x, double y,
      {double r = 18}) {
    final (ox, oy) = s.origin;
    for (final b in s.builds) {
      if (b.kind == BuildKind.casa || b.kind == BuildKind.home) continue;
      final (cx, cy) = chestOf(s, b);
      final px = (cx + ox + 0.5) * 16, py = (cy + oy + 0.5) * 16;
      if ((px - x).abs() <= r && (py - y).abs() <= r) return b;
    }
    return null;
  }

  /// "Ayudantes 1 / 3 · cada uno atiende 8 parcelas" (cartel y opciones).
  static String helperLine(TownBuild b) => b.kind.ranch
      ? 'Granjeros de corral ${b.helper} / ${helperCap(b)} · '
          'dan de comer, acarician y juntan'
      : b.kind == BuildKind.huerta
      ? 'Granjeros ${b.helper} / ${helperCap(b)} · cada uno atiende '
          '${t.i('helperPlots')} parcelas'
      : 'Pescadores ${b.helper} / ${helperCap(b)} · uno cada '
          '${t.i('fisherTiles')} tiles de lago';

  /// Por qué [p] no puede contratar otro ayudante en [id] (o `null`).
  static String? cannotHire(PlayerProfile p, TownState s, String id) {
    final b = s.build(id);
    if (b == null) return 'No existe';
    final farm = b.kind == BuildKind.huerta || b.kind.ranch;
    if (b.kind == BuildKind.casa || b.kind == BuildKind.home) {
      return 'No es una huerta ni un lago';
    }
    if (b.helper >= helperCap(b)) {
      if (b.kind.ranch) return 'Ya tiene su granjero de corral';
      return 'No hay más lugar: agrandá ${farm ? 'la huerta' : 'el lago'}';
    }
    final lvl = farm ? FarmingRules.level(p) : FishingRules.level(p);
    final c = HelperRules.hireCost(b.kind);
    if (lvl < c.level) {
      return 'Necesitás subir tu oficio de ${farm ? 'Granjero' : 'Pesca'} a nivel '
          '${c.level} (ahora: nivel $lvl)';
    }
    return HelperRules.cannotPay(p, c);
  }

  static (PlayerProfile, TownState)? hire(
      PlayerProfile p, TownState s, String id) {
    if (cannotHire(p, s, id) != null) return null;
    final b = s.build(id)!;
    final paid = HelperRules.pay(p, HelperRules.hireCost(b.kind));
    if (paid == null) return null;
    return (
      paid,
      s.withBuild(b.copyWith(
          helper: b.helper + 1,
          crew: b.crewWith(b.helper, const HelperStat()))),
    );
  }

  /// Despide al último ayudante de [id] (sin devolver el oro; las
  /// semillas y el cofre quedan).
  static TownState? fire(TownState s, String id) {
    final b = s.build(id);
    if (b == null || b.helper <= 0) return null;
    return s.withBuild(b.copyWith(
        helper: b.helper - 1,
        tasks: b.tasks.length >= b.helper
            ? b.tasks.sublist(0, b.helper - 1)
            : b.tasks,
        crew: b.crew.length >= b.helper
            ? b.crew.sublist(0, b.helper - 1)
            : b.crew));
  }

  /// Prende o apaga tareas del granjero [i] de [id] ([mask]: bits de
  /// [HelperTask]).
  static TownState? setTasks(TownState s, String id, int i, int mask) {
    final b = s.build(id);
    if (b == null || b.kind != BuildKind.huerta || i < 0 || i >= b.helper) {
      return null;
    }
    final tasks = [for (var k = 0; k < b.helper; k++) b.taskMask(k)];
    tasks[i] = mask & kAllHelperTasks;
    return s.withBuild(b.copyWith(tasks: tasks));
  }

  /// Lo que hará el granjero [i] de [b] en la próxima vuelta: la primera
  /// tarea prendida, en orden fijo (plantar, regar, cosechar), que tenga
  /// algo para hacer en su área. `null` = descansa.
  static HelperTask? farmerNext(TownBuild b, int i, {Season? season}) {
    final m = b.taskMask(i);
    bool on(HelperTask t) => m & t.bit != 0;
    final plots = [
      for (final (x, y) in helperArea(b, i)) b.plots[plotKey(x, y)]
    ];
    if (on(HelperTask.plantar) &&
        b.seedTotal > 0 &&
        plots.any((p) => p == null || !p.planted)) {
      return HelperTask.plantar;
    }
    if (on(HelperTask.regar) &&
        plots.any((p) => p != null && p.planted && !p.watered && !FarmingRules.ripe(p))) {
      return HelperTask.regar;
    }
    if (on(HelperTask.cosechar) &&
        !chestFull(b) &&
        plots.any((p) =>
            p != null && p.planted && FarmingRules.helperHarvestable(p, season))) {
      return HelperTask.cosechar;
    }
    return null;
  }

  /// Una vuelta del granjero [i] de [b]: hace solo la tarea de
  /// [farmerNext] en todas las parcelas de su área. Planta de sus
  /// semillas, riega con `waterRateMin` y cosecha al cofre con [harvest].
  /// Devuelve la huerta y las cosechas (tile relativo, cosecha).
  /// Gana 1 de XP por parcela atendida; con las mejoras (§ 8.5) la
  /// cosecha puede subir de calidad ([rand]) y aparecer una semilla rara
  /// ([rareSeed]) para la huerta.
  static (TownBuild, List<(int, int, Harvest)>) farmerCycle(
      TownBuild b0, int i, Harvest? Function(FarmPlot) harvest,
      {double Function()? rand,
      String Function()? rareSeed,
      Season? season}) {
    final task = farmerNext(b0, i, season: season);
    var b = b0;
    final out = <(int, int, Harvest)>[];
    if (task == null) {
      return (autoWater(b0, i) ?? b, out);
    }
    final plots = {...b.plots};
    final seeds = {...b.seeds};
    final ft = FarmingRules.t;
    var worked = 0;
    final qChance = HelperRules.qualityChance(b0, i);
    final sChance = HelperRules.rareSeedChance(b0, i);
    for (final (x, y) in helperArea(b0, i)) {
      final key = plotKey(x, y);
      final pl = plots[key];
      switch (task) {
        case HelperTask.plantar:
          if (pl != null && pl.planted) continue;
          final sd = helperSeed(b.copyWith(seeds: seeds));
          if (sd == null) break;
          seeds[sd] = seeds[sd]! - 1;
          if (seeds[sd]! <= 0) seeds.remove(sd);
          final base = pl ?? FarmingRules.till();
          plots[key] = FarmPlot(
              seed: sd, wet: base.wet, waterRate: base.waterRate);
          worked++;
        case HelperTask.regar:
          if (pl == null || !pl.planted || pl.watered || FarmingRules.ripe(pl)) {
            continue;
          }
          plots[key] = pl.copyWith(
              wet: ft.d('waterSec'),
              waterRate: ft.d('waterRateMin'),
              waterer: 'Granjero');
          worked++;
        case HelperTask.cosechar:
          if (pl == null ||
              !pl.planted ||
              !FarmingRules.helperHarvestable(pl, season)) {
            continue;
          }
          if (chestFull(b)) break;
          final h = harvest(pl);
          if (h == null) continue;
          var q = h.quality;
          if (rand != null && qChance > 0 && rand() < qChance &&
              q.index < CropQuality.values.length - 1) {
            q = CropQuality.values[q.index + 1];
          }
          b = addToChest(b, cropKey(h.crop.id, q), h.count);
          plots[key] = FarmPlot(wet: pl.wet, waterRate: pl.waterRate);
          out.add((x, y, h));
          worked++;
          if (rand != null && rareSeed != null && sChance > 0 &&
              rand() < sChance) {
            final id = rareSeed();
            seeds[id] = (seeds[id] ?? 0) + 1;
          }
      }
    }
    b = b.copyWith(plots: plots, seeds: seeds);
    b = autoWater(b, i) ?? b;
    return (HelperRules.gainXp(b, i, worked), out);
  }

  /// The farmer [i] waters on their own (farming.md § 8.2, v0.45.0):
  /// every round, besides their task, every planted, unripe, dry plot of
  /// their area gets a `waterRateMin` watering. `null` = nothing to water.
  static TownBuild? autoWater(TownBuild b, int i) {
    final ft = FarmingRules.t;
    Map<String, FarmPlot>? plots;
    for (final (x, y) in helperArea(b, i)) {
      final key = plotKey(x, y);
      final pl = b.plots[key];
      if (pl == null || !pl.planted || pl.watered || FarmingRules.ripe(pl)) {
        continue;
      }
      (plots ??= {...b.plots})[key] = pl.copyWith(
          wet: ft.d('waterSec'),
          waterRate: ft.d('waterRateMin'),
          waterer: 'Granjero');
    }
    return plots == null ? null : b.copyWith(plots: plots);
  }

  /// Pasa [n] semillas de [seed] de [p] a los granjeros de [id] (`n <= 0`
  /// = todas).
  static (PlayerProfile, TownState)? giveSeeds(
      PlayerProfile p, TownState s, String id, String seed, int n) {
    final b = s.build(id);
    final f = p.life.farm;
    final have = f.seedCount(seed);
    if (b == null || b.kind != BuildKind.huerta || have <= 0) return null;
    if (!kCrops.containsKey(seed)) return null;
    final k = n <= 0 ? have : math.min(n, have);
    final left = {...f.seeds, seed: have - k}..removeWhere((_, v) => v <= 0);
    return (
      p.copyWith(life: p.life.copyWith(farm: f.copyWith(seeds: left))),
      s.withBuild(
          b.copyWith(seeds: {...b.seeds, seed: (b.seeds[seed] ?? 0) + k})),
    );
  }

  /// Devuelve [n] semillas de [seed] de los granjeros de [id] a [p].
  static (PlayerProfile, TownState)? takeSeeds(
      PlayerProfile p, TownState s, String id, String seed, int n) {
    final b = s.build(id);
    final have = b?.seeds[seed] ?? 0;
    if (b == null || have <= 0) return null;
    final k = n <= 0 ? have : math.min(n, have);
    final left = {...b.seeds, seed: have - k}..removeWhere((_, v) => v <= 0);
    return (
      p.copyWith(life: p.life.copyWith(farm: p.life.farm.addSeed(seed, k))),
      s.withBuild(b.copyWith(seeds: left)),
    );
  }

  /// La semilla que planta el granjero: [prefer] si queda, si no la que
  /// más tiene. `null` = no le quedan.
  static String? helperSeed(TownBuild b, [String? prefer]) {
    if (prefer != null && (b.seeds[prefer] ?? 0) > 0) return prefer;
    String? best;
    var n = 0;
    for (final e in b.seeds.entries) {
      if (e.value > n && kCrops.containsKey(e.key)) {
        best = e.key;
        n = e.value;
      }
    }
    return best;
  }

  /// Segundos entre vueltas de los ayudantes con los de [ps] en la sala.
  static double helperPeriod(Iterable<PlayerProfile> ps) =>
      math.max(1, t.d('helperEverySec') / (1 + helperBoost(ps)));

  /// Segundos hasta la próxima vuelta en el segundo [time] de la sala.
  static double nextRoundIn(double time, Iterable<PlayerProfile> ps) {
    final p = helperPeriod(ps);
    return p - time % p;
  }

  /// El mejor efecto de ayudante de [ps] (árbol de Cultivo): acorta la
  /// espera entre vueltas.
  static double helperBoost(Iterable<PlayerProfile> ps) => ps.fold(
      0.0, (a, p) => math.max(a, LifeTreeRules.farm(p, LifeFx.helper)));

  /// Recoge el cofre de [id] en la bolsa PESCA Y CULTIVO de [p] (con
  /// `helperXpShare` de la XP).
  static (PlayerProfile, TownState)? collectChest(
      PlayerProfile p, TownState s, String id) {
    final b = s.build(id);
    if (b == null || b.chest.isEmpty) return null;
    var prof = p;
    if (b.kind.ranch) {
      // Animal products (animals.md § 6): the bag and a share of the XP.
      var f = p.life.farm;
      var xp = 0;
      for (final e in b.chest.entries) {
        final pk = parseAnimalGoodsKey(e.key);
        if (pk == null) continue;
        f = f.addGoods(e.key, e.value);
        xp += (pk.$1.xp *
                AnimalRules.qualityMult(pk.$2) *
                e.value *
                t.d('helperXpShare'))
            .round();
      }
      prof = p.copyWith(life: p.life.copyWith(farm: f.copyWith(xp: f.xp + xp)));
    } else if (b.kind == BuildKind.huerta) {
      var f = p.life.farm;
      var xp = 0;
      for (final e in b.chest.entries) {
        f = f.addCrop(e.key, e.value);
        final c = parseCropKey(e.key);
        if (c != null) {
          xp += (FarmingRules.cropXp(c.$1, c.$2) *
                  e.value *
                  t.d('helperXpShare'))
              .round();
        }
      }
      prof = p.copyWith(life: p.life.copyWith(farm: f.copyWith(xp: f.xp + xp)));
    } else {
      for (final e in b.chest.entries) {
        final d = kFish[e.key];
        if (d == null) continue;
        for (var i = 0; i < e.value; i++) {
          prof = FishingRules.addCatch(prof, FishCatch(e.key, d.minCm),
              auto: true);
        }
      }
    }
    return (prof, s.withBuild(b.copyWith(chest: const {})));
  }

  /// Suma [n] de [key] al cofre de [b] hasta `chestMax`.
  static TownBuild addToChest(TownBuild b, String key, int n) {
    final room = math.max(0, t.i('chestMax') - b.chestTotal);
    final k = math.min(room, n);
    if (k <= 0) return b;
    return b.copyWith(chest: {...b.chest, key: (b.chest[key] ?? 0) + k});
  }

  static bool chestFull(TownBuild b) => b.chestTotal >= t.i('chestMax');
}
