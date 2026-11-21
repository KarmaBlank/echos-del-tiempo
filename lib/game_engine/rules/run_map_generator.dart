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
/// antes de [RunTuning.firstEliteLayer]; nunca dos descansos seguidos en
/// un camino; la capa anterior al jefe es toda de descanso; cada línea
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
            final restOk = l < layers - 2 &&
                !preds[id]!.any((p) => types[p] == RunNodeType.descanso);
            types[id] = _pick(rnd,
                elite: l >= RunTuning.firstEliteLayer, rest: restOk);
          }
        }
      }
    }
    // Al menos una tienda y una armería por línea (cambian un combate).
    for (var lane = 0; lane < lanes; lane++) {
      for (final want in const [RunNodeType.tienda, RunNodeType.armeria]) {
        final inLane = [
          for (var l = 0; l < layers; l++) ...ids[l][lane],
        ];
        if (inLane.any((id) => types[id] == want)) continue;
        final options = [
          for (var l = 2; l <= layers - 3; l++)
            for (final id in ids[l][lane])
              if (types[id] == RunNodeType.combate) id,
        ];
        if (options.isEmpty) continue;
        types[options[(rnd() * options.length).floor()]] = want;
      }
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
      {required bool elite, required bool rest}) {
    final table = <(RunNodeType, int)>[
      (RunNodeType.combate, RunTuning.weightCombate),
      if (elite) (RunNodeType.elite, RunTuning.weightElite),
      (RunNodeType.tienda, RunTuning.weightTienda),
      (RunNodeType.armeria, RunTuning.weightArmeria),
      if (rest) (RunNodeType.descanso, RunTuning.weightDescanso),
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
