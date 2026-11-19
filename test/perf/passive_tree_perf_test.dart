import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/passive_tree/presentation/passive_tree_view.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/features/passive_tree/domain/passive_text.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Benchmark del árbol de pasivas (docs/specs/passive_tree_v6.md § 9):
/// graba y RASTERIZA (`toImage`, CPU) N cuadros del visor (1000×420) con
/// zoom mínimo (todo el árbol a la vista), medio y máximo, con el
/// resaltado de un cluster y el camino como al pasar el mouse, más los
/// nombres de los clusters. Los números sirven para comparar (rasterizado
/// por software en `flutter test`), no como tiempo absoluto de la GPU.
void main() {
  const view = Size(1000, 420);
  const frames = 40;

  Future<String> bench(WidgetTester tester, double zoom) async {
    final cat = kPassiveTree;
    final start = cat.startNodeByClass['tirador'];
    final states = {
      for (final id in cat.nodes.keys)
        id: id == start ? TreeNodeState.start : TreeNodeState.locked,
    };
    final focus = cat.nodes.keys.elementAt(cat.nodes.length ~/ 3);
    const c = PassiveTreeView.size / 2;
    final m = Matrix4.diagonal3Values(zoom, zoom, 1)
      ..setTranslationRaw(
          view.width / 2 - c * zoom, view.height / 2 - c * zoom, 0);
    final times = <double>[];
    await tester.runAsync(() async {
      for (var i = 0; i < frames + 5; i++) {
        final sw = Stopwatch()..start();
        final painter = PassiveTreePainter(
          catalog: cat,
          startId: start,
          states: states,
          focus: focus,
          highlightPath: cat.nodes[focus]!.pathId,
          zoom: zoom,
        );
        final rec = ui.PictureRecorder();
        final canvas = Canvas(rec)
          ..clipRect(Offset.zero & view)
          ..save()
          ..transform(m.storage);
        painter.paint(canvas, const Size.square(PassiveTreeView.size));
        canvas.restore();
        TreeLabelsPainter(
          catalog: cat,
          transform: m,
          textScaler: TextScaler.noScaling,
          highlightPath: cat.nodes[focus]!.pathId,
        ).paint(canvas, view);
        final pic = rec.endRecording();
        final img = await pic.toImage(view.width.toInt(), view.height.toInt());
        sw.stop();
        img.dispose();
        pic.dispose();
        if (i >= 5) times.add(sw.elapsedMicroseconds / 1000);
      }
    });
    times.sort();
    double p(double q) => times[((times.length - 1) * q).round()];
    final mean = times.reduce((a, b) => a + b) / times.length;
    return 'zoom ${zoom.toStringAsFixed(2)}: p50 ${p(.5).toStringAsFixed(2)} · '
        'p90 ${p(.9).toStringAsFixed(2)} · máx ${times.last.toStringAsFixed(2)} ms '
        '(media ${mean.toStringAsFixed(2)})';
  }

  testWidgets('árbol de pasivas: tiempo de cuadro por zoom', (tester) async {
    final out = <String>[
      '=== Árbol de pasivas ($frames cuadros, ${view.width.toInt()}×${view.height.toInt()}) ==='
    ];
    for (final cache in [false, true]) {
      PassiveTreePainter.farCache = cache;
      out.add(cache
          ? '[con capa rasterizada + nivel de detalle]'
          : '[vectorial, como antes]');
      for (final z in [
        PassiveTreeView.minZoom,
        0.35,
        0.6,
        1.0,
        PassiveTreeView.maxZoom
      ]) {
        out.add(await bench(tester, z));
      }
    }
    PassiveTreePainter.farCache = true;
    // ignore: avoid_print
    print(out.join('\n'));
  });
}
