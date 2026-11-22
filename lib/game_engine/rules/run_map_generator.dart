import '../models/run_state.dart';
import 'battle_engine.dart' show RandomSource;
import 'mulberry32.dart';
import 'run_tuning.dart';

/// Mapa ramificado de la Travesía (docs/specs/roguelike.md § 2): por piso,
/// una entrada → 3 líneas principales que se abren y se vuelven a juntar a
/// lo largo de [RunTuning.layers] capas → jefe. Misma semilla, mismo mapa
/// en todos los dispositivos (`mulberry32`).
///
/// Reglas: la primera capa es de combate; la primera élite no aparece
/// antes de [RunTuning.firstEliteLayer]; nunca dos paradas seguidas
/// (tienda, armería o descanso) en un camino; la capa anterior al jefe es toda de descanso; cada línea
/// tiene al menos una tienda y una armería.
class RunMapGenerator {
  const RunMapGenerator();

  RunMap generate(int seed) => RunMap(seed, [
        for (var f = 0; f < RunTuning.floors; f++) floor(seed, f),
      ]);

  RunFloor floor(int seed, int index) {
    final rnd = mulberry32((seed + index * 0x9E3779B1) & 0xFFFFFFFF);
    const lanes = RunTuning.lanes, layers = RunTuning.layers;

    // 1. Cuántos nodos tiene cada línea en cada capa (1, o 2 si se abre).
    final counts = <List<int>>[];
    for (var l = 0; l < layers; l++) {
      counts.add([
        for (var lane = 0; lane < lanes; lane++)
          l >= 1 &&
                  l <= layers - 3 &&
                  counts[l - 1][lane] == 1 &&
                  rnd() < RunTuning.splitChance
              ? 2
              : 1,
      ]);
    }

    // 2. Ids por capa y línea.
    final ids = <List<List<int>>>[];
    var next = 0;
    for (var l = 0; l < layers; l++) {
      ids.add([
        for (var lane = 0; lane < lanes; lane++)
          [for (var k = 0; k < counts[l][lane]; k++) next++],
      ]);
    }
    final bossId = next;

    // 3. Aristas: dentro de la línea y algún cruce a la vecina.
    final edges = <int, Set<int>>{for (var i = 0; i <= bossId; i++) i: {}};
    for (var l = 0; l < layers - 1; l++) {
      for (var lane = 0; lane < lanes; lane++) {
        final a = ids[l][lane], b = ids[l + 1][lane];
        if (a.length == b.length) {
          for (var k = 0; k < a.length; k++) {
            edges[a[k]]!.add(b[k]);
          }
        } else {
          for (final x in a) {
            for (final y in b) {
              edges[x]!.add(y);
            }
          }
        }
      }
      for (var lane = 0; lane < lanes - 1; lane++) {
        if (rnd() >= RunTuning.crossChance) continue;
        if (rnd() < 0.5) {
          edges[ids[l][lane].last]!.add(ids[l + 1][lane + 1].first);
        } else {
          edges[ids[l][lane + 1].first]!.add(ids[l + 1][lane].last);
        }
      }
    }
    for (final lane in ids[layers - 1]) {
      for (final x in lane) {
        edges[x]!.add(bossId);
      }
    }

    // 4. Tipos, capa por capa (los predecesores ya tienen el suyo).
    final types = List<RunNodeType>.filled(bossId + 1, RunNodeType.combate);
    types[bossId] = RunNodeType.jefe;
    final preds = <int, List<int>>{for (var i = 0; i <= bossId; i++) i: []};
    for (final e in edges.entries) {
      for (final t in e.value) {
        preds[t]!.add(e.key);
      }
    }
    for (var l = 0; l < layers; l++) {
      for (final lane in ids[l]) {
        for (final id in lane) {
          if (l == 0) {
            types[id] = RunNodeType.combate;
          } else if (l == layers - 1) {
            types[id] = RunNodeType.descanso;
          } else {
            // Nunca dos paradas seguidas (tienda / armería / descanso),
            // ni una parada justo antes de la capa de descanso.
            final stopOk = l < layers - 2 &&
                !preds[id]!.any((p) => types[p].isStop);
            types[id] = _pick(rnd,
                elite: l >= RunTuning.firstEliteLayer, stop: stopOk);
          }
        }
      }
    }
    // Al menos una tienda y una armería por línea (cambian un combate sin
    // paradas al lado; si no hay, uno sin parada antes y lo que le siga
    // vuelve a combate). Varias pasadas: un arreglo puede romper otra línea.
    final layerOf = <int, int>{
      for (var l = 0; l < layers; l++)
        for (final lane in ids[l])
          for (final id in lane) id: l,
    };
    for (var pass = 0; pass < 8; pass++) {
      var changed = false;
      for (var lane = 0; lane < lanes; lane++) {
        for (final want in const [RunNodeType.tienda, RunNodeType.armeria]) {
          final inLane = [
            for (var l = 0; l < layers; l++) ...ids[l][lane],
          ];
          if (inLane.any((id) => types[id] == want)) continue;
          bool predsOk(int id) => !preds[id]!.any((p) => types[p].isStop);
          bool calm(int id) =>
              predsOk(id) && !edges[id]!.any((n) => types[n].isStop);
          List<int> pick(bool Function(int) ok) => [
                for (var l = 2; l <= layers - 3; l++)
                  for (final id in ids[l][lane])
                    if (types[id] == RunNodeType.combate && ok(id)) id,
              ];
          var options = pick(calm);
          if (options.isEmpty) options = pick(predsOk);
          if (options.isEmpty) options = pick((_) => true);
          if (options.isEmpty) continue;
          final id = options[(rnd() * options.length).floor()];
          types[id] = want;
          for (final n in preds[id]!) {
            if (types[n].isStop) types[n] = RunNodeType.combate;
          }
          for (final n in edges[id]!) {
            if (types[n].isStop && layerOf[n] != layers - 1) {
              types[n] = RunNodeType.combate;
            }
          }
          changed = true;
        }
      }
      if (!changed) break;
    }

    // 5. Nodos.
    final nodes = <RunNode>[];
    for (var l = 0; l < layers; l++) {
      for (var lane = 0; lane < lanes; lane++) {
        final group = ids[l][lane];
        for (var k = 0; k < group.length; k++) {
          final id = group[k];
          nodes.add(RunNode(
            id: id,
            layer: l,
            lane: lane,
            x: lane + (group.length == 1 ? 0.0 : (k == 0 ? -0.22 : 0.22)),
            type: types[id],
            next: List.unmodifiable(edges[id]!.toList()..sort()),
          ));
        }
      }
    }
    nodes.add(RunNode(
      id: bossId,
      layer: layers,
      lane: 1,
      x: 1,
      type: RunNodeType.jefe,
      next: const [],
    ));
    return RunFloor(index, List.unmodifiable(nodes));
  }

  static RunNodeType _pick(RandomSource rnd,
      {required bool elite, required bool stop}) {
    final table = <(RunNodeType, int)>[
      (RunNodeType.combate, RunTuning.weightCombate),
      if (elite) (RunNodeType.elite, RunTuning.weightElite),
      if (stop) (RunNodeType.tienda, RunTuning.weightTienda),
      if (stop) (RunNodeType.armeria, RunTuning.weightArmeria),
      if (stop) (RunNodeType.descanso, RunTuning.weightDescanso),
    ];
    final total = table.fold<int>(0, (a, e) => a + e.$2);
    var r = rnd() * total;
    for (final (t, w) in table) {
      if (r < w) return t;
      r -= w;
    }
    return RunNodeType.combate;
  }
}
