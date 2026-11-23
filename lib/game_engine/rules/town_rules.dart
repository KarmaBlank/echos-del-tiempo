import 'dart:math' as math;

import '../data/construction_catalog.dart';
import '../data/fishing_catalog.dart';
import '../data/tuning_catalog.dart';
import '../models/item.dart' show CraftMaterial;
import '../models/player_profile.dart';
import '../models/world_save.dart';
import 'farming_rules.dart';
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
        '${c.gold} de oro',
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
    if (s.expansions >= maxExpansions) return 'El pueblo ya está al máximo';
    if (s.side(side) >= maxPerSide) {
      return 'No se puede ampliar más al ${side.label.toLowerCase()}';
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
    return '${k == BuildKind.lago ? 'l' : 'h'}$n';
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
        seeds: _sum(a.seeds, b.seeds));
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
          if (o.kind != b.kind) continue;
          final touch = o.parts
              .any((p) => merged.parts.any((q) => p.touches(q)));
          if (!touch) continue;
          final first = rest.indexOf(o) < index;
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
    final b = s.build(id);
    if (b == null) return (town: null, id: null, error: 'No existe');
    final (ox, oy) = s.origin;
    final (next, nid) = _put(s, b.movedTo(mx - ox, my - oy));
    final err = _invalid(next, nid);
    return err == null
        ? (town: next, id: nid, error: null)
        : (town: null, id: null, error: err);
  }

  /// Borrar [id]. Lago: se pierden sus peces. Huerta: cada parcela
  /// plantada le devuelve su semilla a [p] (la opción amable, § 5.3).
  static (PlayerProfile, TownState)? remove(
      PlayerProfile p, TownState s, String id) {
    final b = s.build(id);
    if (b == null) return null;
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

  // ---------------- ayudantes (farming.md § 8, v0.25.4) ----------------

  static int get helperCost => t.i('helperCost');

  /// Cuántos ayudantes entran en [b]: uno cada `helperPlots` tiles de
  /// huerta o cada `fisherTiles` tiles de lago (redondeo para arriba).
  static int helperCap(TownBuild b) {
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
  static List<(int, int)> helperArea(TownBuild b, int i) {
    final all = farmTiles(b);
    final n = math.max(1, t.i('helperPlots'));
    final a = (i * n).clamp(0, all.length);
    final z = ((i + 1) * n).clamp(0, all.length);
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

  /// El lugar de pesca del pescador [i] de [b] (repartidos por la orilla).
  static (int, int) fisherSpot(TownBuild b, int i) {
    final ring = shoreTiles(b);
    final cap = math.max(1, helperCap(b));
    return ring[(i * ring.length ~/ cap) % ring.length];
  }

  /// Dónde está el ayudante [i] de [b] en el segundo [time] de la sala
  /// (px del mapa). Igual en todos los clientes: el granjero camina por
  /// su área, parcela por parcela; el pescador se queda en su lugar de la
  /// orilla. `work`: está trabajando (riega o tira la caña).
  static ({double x, double y, bool work}) helperPos(
      TownState s, TownBuild b, int i, double time) {
    final (ox, oy) = s.origin;
    final (ax, ay) = b.anchor;
    if (b.kind == BuildKind.lago) {
      final (x, y) = fisherSpot(b, i);
      return (x: (x + ox + 0.5) * 16, y: (y + oy + 0.5) * 16, work: true);
    }
    final area = helperArea(b, i);
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

  /// El tile del cofre de [b] (coordenadas del pueblo base): al lado del
  /// cartel, donde no haya otra construcción ni otro cartel.
  static (int, int) chestOf(TownState s, TownBuild b) {
    final (sx, sy) = TownPlan.signOf(s, b);
    for (final (dx, dy) in const [(0, 1), (1, 0), (-1, 0), (0, -1)]) {
      final x = sx + dx, y = sy + dy;
      if (s.builds.any((o) => o.contains(x, y))) continue;
      if (s.builds.any((o) => TownPlan.signOf(s, o) == (x, y))) continue;
      return (x, y);
    }
    return (sx, sy + 1);
  }

  /// La construcción cuyo cofre está a [r] px o menos de ([x], [y]).
  static TownBuild? chestNear(TownState s, double x, double y,
      {double r = 18}) {
    final (ox, oy) = s.origin;
    for (final b in s.builds) {
      final (cx, cy) = chestOf(s, b);
      final px = (cx + ox + 0.5) * 16, py = (cy + oy + 0.5) * 16;
      if ((px - x).abs() <= r && (py - y).abs() <= r) return b;
    }
    return null;
  }

  /// "Ayudantes 1 / 3 · cada uno atiende 8 parcelas" (cartel y opciones).
  static String helperLine(TownBuild b) => b.kind == BuildKind.huerta
      ? 'Granjeros ${b.helper} / ${helperCap(b)} · cada uno atiende '
          '${t.i('helperPlots')} parcelas'
      : 'Pescadores ${b.helper} / ${helperCap(b)} · uno cada '
          '${t.i('fisherTiles')} tiles de lago';

  /// Por qué [p] no puede contratar otro ayudante en [id] (o `null`).
  static String? cannotHire(PlayerProfile p, TownState s, String id) {
    final b = s.build(id);
    if (b == null) return 'No existe';
    final farm = b.kind == BuildKind.huerta;
    if (b.helper >= helperCap(b)) {
      return 'No hay más lugar: agrandá ${farm ? 'la huerta' : 'el lago'}';
    }
    final lvl = farm ? FarmingRules.level(p) : FishingRules.level(p);
    final need = t.i('helperLevel');
    if (lvl < need) return 'Necesitás ${farm ? 'Cultivo' : 'Pesca'} nivel $need';
    if (p.credits < helperCost) return 'Falta oro (${p.credits}/$helperCost)';
    return null;
  }

  static (PlayerProfile, TownState)? hire(
      PlayerProfile p, TownState s, String id) {
    if (cannotHire(p, s, id) != null) return null;
    final b = s.build(id)!;
    return (
      p.copyWith(credits: p.credits - helperCost),
      s.withBuild(b.copyWith(helper: b.helper + 1)),
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
            : b.tasks));
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
  static HelperTask? farmerNext(TownBuild b, int i) {
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
        plots.any((p) => p != null && p.planted && FarmingRules.ripe(p))) {
      return HelperTask.cosechar;
    }
    return null;
  }

  /// Una vuelta del granjero [i] de [b]: hace solo la tarea de
  /// [farmerNext] en todas las parcelas de su área. Planta de sus
  /// semillas, riega con `waterRateMin` y cosecha al cofre con [harvest].
  /// Devuelve la huerta y las cosechas (tile relativo, cosecha).
  static (TownBuild, List<(int, int, Harvest)>) farmerCycle(
      TownBuild b0, int i, Harvest Function(FarmPlot) harvest) {
    final task = farmerNext(b0, i);
    var b = b0;
    final out = <(int, int, Harvest)>[];
    if (task == null) return (b, out);
    final plots = {...b.plots};
    final seeds = {...b.seeds};
    final ft = FarmingRules.t;
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
        case HelperTask.regar:
          if (pl == null || !pl.planted || pl.watered || FarmingRules.ripe(pl)) {
            continue;
          }
          plots[key] = pl.copyWith(
              wet: ft.d('waterSec'),
              waterRate: ft.d('waterRateMin'),
              waterer: 'Granjero');
        case HelperTask.cosechar:
          if (pl == null || !pl.planted || !FarmingRules.ripe(pl)) continue;
          if (chestFull(b)) break;
          final h = harvest(pl);
          b = addToChest(b, cropKey(h.crop.id, h.quality), h.count);
          plots[key] = FarmPlot(wet: pl.wet, waterRate: pl.waterRate);
          out.add((x, y, h));
      }
    }
    return (b.copyWith(plots: plots, seeds: seeds), out);
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
    if (b.kind == BuildKind.huerta) {
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
