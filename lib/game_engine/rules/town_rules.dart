import 'dart:math' as math;

import '../data/construction_catalog.dart';
import '../data/fishing_catalog.dart';
import '../data/tuning_catalog.dart';
import '../models/item.dart' show CraftMaterial;
import '../models/player_profile.dart';
import '../models/world_save.dart';
import 'farming_rules.dart';
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

  /// Pone [b] en el pueblo; si es un lago y toca otros lagos, se funden
  /// en uno (se queda con el id del primero y suma los peces; § 4.2).
  static (TownState, String) _put(TownState s, TownBuild b) {
    final rest = [...s.builds.where((o) => o.id != b.id)];
    var merged = b;
    final at = s.builds.indexWhere((o) => o.id == b.id);
    var index = at < 0 ? rest.length : at;
    if (b.kind == BuildKind.lago) {
      var grew = true;
      while (grew) {
        grew = false;
        for (final o in [...rest]) {
          if (o.kind != BuildKind.lago) continue;
          final touch = o.parts
              .any((p) => merged.parts.any((q) => p.touches(q)));
          if (!touch) continue;
          final first = rest.indexOf(o) < index;
          final stock = {...o.stock};
          for (final e in merged.stock.entries) {
            stock[e.key] = (stock[e.key] ?? 0) + e.value;
          }
          merged = TownBuild(first ? o.id : merged.id, BuildKind.lago,
              first ? [...o.parts, ...merged.parts] : [...merged.parts, ...o.parts],
              stock: stock);
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
    var prof = p;
    if (b.kind == BuildKind.huerta) {
      final seeds = {...p.life.farm.seeds};
      for (final pl in b.plots.values) {
        final sd = pl.seed;
        if (sd != null) seeds[sd] = (seeds[sd] ?? 0) + 1;
      }
      prof = p.copyWith(
          life: p.life.copyWith(farm: p.life.farm.copyWith(seeds: seeds)));
    }
    return (prof, s.copyWith(builds: [...s.builds.where((o) => o.id != id)]));
  }

  /// Semillas que vuelven al borrar la huerta [b].
  static int seedsBack(TownBuild b) =>
      b.plots.values.where((p) => p.planted).length;

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
        '$planted de ${f.area} parcelas';
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
        'soltados';
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

  // ---------------- ayudante ----------------

  static int helperCost(int nextLevel) => t.i('helperCost') * nextLevel;

  static String? cannotHire(PlayerProfile p, TownState s) {
    if (s.helper >= t.i('helperMax')) return 'El ayudante ya está al máximo';
    final need = t.i('helperLevel') * (s.helper + 1);
    final lvl = FarmingRules.level(p);
    if (lvl < need) return 'Necesitás Cultivo nivel $need';
    final c = helperCost(s.helper + 1);
    if (p.credits < c) return 'Falta oro (${p.credits}/$c)';
    return null;
  }

  static (PlayerProfile, TownState)? hire(PlayerProfile p, TownState s) {
    if (cannotHire(p, s) != null) return null;
    return (
      p.copyWith(credits: p.credits - helperCost(s.helper + 1)),
      s.copyWith(helper: s.helper + 1),
    );
  }

  /// Parcelas que atiende el ayudante; [boost]: el mejor «Capataz» de los
  /// que están en el pueblo.
  static int helperPlots(TownState s, {double boost = 0}) =>
      (t.i('helperPlots') * s.helper * (1 + boost)).round();

  /// El mejor efecto de ayudante de [ps] (árbol de Cultivo).
  static double helperBoost(Iterable<PlayerProfile> ps) => ps.fold(
      0.0, (a, p) => math.max(a, LifeTreeRules.farm(p, LifeFx.helper)));

  /// Recoge el granero en la bolsa de [p] (con un poco de XP).
  static (PlayerProfile, TownState)? collectSilo(PlayerProfile p, TownState s) {
    if (s.silo.isEmpty) return null;
    var f = p.life.farm;
    var xp = 0;
    for (final e in s.silo.entries) {
      f = f.addCrop(e.key, e.value);
      final c = parseCropKey(e.key);
      if (c != null) {
        xp += (FarmingRules.cropXp(c.$1, c.$2) * e.value * t.d('helperXpShare'))
            .round();
      }
    }
    return (
      p.copyWith(life: p.life.copyWith(farm: f.copyWith(xp: f.xp + xp))),
      s.copyWith(silo: const {}),
    );
  }
}
