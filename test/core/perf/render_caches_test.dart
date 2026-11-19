import 'package:echos_del_tiempo/app/theme/pixel_label.dart';
import 'package:echos_del_tiempo/app/theme/proto_colors.dart';
import 'package:echos_del_tiempo/app/theme/proto_markup.dart';
import 'package:echos_del_tiempo/app/theme/ui_theme.dart';
import 'package:echos_del_tiempo/app/theme/vision_palette.dart';
import 'package:echos_del_tiempo/app/widgets/memo.dart';
import 'package:echos_del_tiempo/core/perf/frame_stats.dart';
import 'package:echos_del_tiempo/core/perf/perf_log.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Cachés de dibujo del overworld (docs/specs/exploration.md §
/// "Rendimiento"): etiquetas del mapa, markup del HUD, `Memo` y el
/// registro de rendimiento.
void main() {
  group('PixelLabelPen (etiquetas del mapa)', () {
    test('mide una vez por texto, color y tamaño', () {
      final pen = PixelLabelPen();
      final a = pen.layout('Ana', const Color(0xFFFFFFFF), 8);
      expect((pen.hits, pen.misses), (0, 1));
      expect(identical(pen.layout('Ana', const Color(0xFFFFFFFF), 8), a),
          isTrue);
      expect((pen.hits, pen.misses), (1, 1));
      // Otro tamaño (otra escala de la ventana) u otro color: se mide.
      pen.layout('Ana', const Color(0xFFFFFFFF), 16);
      pen.layout('Ana', const Color(0xFFFFD166), 8);
      expect((pen.hits, pen.misses), (1, 3));
      expect(pen.cached, 3);
    });

    test('al llenarse tira el menos usado (no todo)', () {
      final pen = PixelLabelPen();
      const white = Color(0xFFFFFFFF);
      pen.layout('nombre', white, 8);
      for (var i = 0; i < PixelLabelPen.maxCached - 1; i++) {
        pen.layout('aviso $i', white, 8);
        // El nombre se usa en cada cuadro: queda entre los recientes.
        if (i % 50 == 0) pen.layout('nombre', white, 8);
      }
      expect(pen.cached, PixelLabelPen.maxCached);
      // Un aviso que se desvanece: un color nuevo por cuadro.
      for (var a = 0; a < 40; a++) {
        pen.layout('¡Caíste!', white.withValues(alpha: a / 40), 16);
        pen.layout('nombre', white, 8);
      }
      expect(pen.cached, PixelLabelPen.maxCached);
      final misses = pen.misses;
      pen.layout('nombre', white, 8);
      expect(pen.misses, misses, reason: 'el nombre sigue medido');
      pen.clear();
      expect(pen.cached, 0);
    });
  });

  group('protoSpan (markup del HUD)', () {
    setUp(() {
      ProtoSpanCache.clear();
      ProtoSpanCache.hits = 0;
      ProtoSpanCache.misses = 0;
      UiTheme.reset();
      VisionPalette.mode = ColorVision.off;
    });
    tearDown(() {
      UiTheme.reset();
      VisionPalette.mode = ColorVision.off;
    });

    const markup = '<b>Ana</b> <span class="k">Guerrero Lv3</span>';

    test('interpreta una vez el mismo markup', () {
      final a = protoSpan(markup);
      expect(ProtoSpanCache.misses, 1);
      expect(identical(protoSpan(markup), a), isTrue);
      expect(ProtoSpanCache.hits, 1);
      // Otro estilo: otra entrada.
      protoSpan(markup, style: const TextStyle(color: Color(0xFF000000)));
      expect(ProtoSpanCache.misses, 2);
      expect(a.toPlainText(), 'Ana Guerrero Lv3');
    });

    test('cambiar el tema, los colores del texto o el modo daltónico no '
        'reutiliza lo de antes', () {
      final blue = protoSpan(markup);
      UiTheme.kind = InterfaceTheme.highContrast;
      final hc = protoSpan(markup);
      expect(identical(hc, blue), isFalse);
      expect(ProtoSpanCache.misses, 2);
      // Mismo resultado que sin caché.
      ProtoSpanCache.clear();
      expect(protoSpan(markup), hc);
      UiTheme.textColors = TextColorMode.reduced;
      protoSpan(markup);
      VisionPalette.mode = ColorVision.values.last;
      protoSpan(markup);
      expect(ProtoSpanCache.misses, 5);
      // Volver al tema de antes: lo de antes sigue guardado.
      UiTheme.reset();
      VisionPalette.mode = ColorVision.off;
      ProtoSpanCache.hits = 0;
      protoSpan(markup);
      expect(ProtoSpanCache.hits, 0, reason: 'se vació con clear()');
    });

    test('estilos con colores del tema (hash según el tema): no se cuelga '
        'al llenarse después de cambiar de tema', () {
      const style = TextStyle(color: ProtoColors.sky);
      for (var i = 0; i < ProtoSpanCache.max; i++) {
        protoSpan('<b>$i</b>', style: style, boldColor: ProtoColors.gold);
      }
      UiTheme.kind = InterfaceTheme.highContrast;
      for (var i = 0; i < ProtoSpanCache.max + 10; i++) {
        protoSpan('<b>$i</b>', style: style, boldColor: ProtoColors.gold);
      }
      UiTheme.kind = InterfaceTheme.blue;
      expect(protoSpan('<b>1</b>', style: style).toPlainText(), '1');
    });

    test('LRU acotado', () {
      for (var i = 0; i < ProtoSpanCache.max + 20; i++) {
        protoSpan('<b>$i</b>');
      }
      final misses = ProtoSpanCache.misses;
      protoSpan('<b>${ProtoSpanCache.max + 19}</b>');
      expect(ProtoSpanCache.misses, misses);
      protoSpan('<b>0</b>');
      expect(ProtoSpanCache.misses, misses + 1, reason: 'el más viejo se fue');
    });
  });

  group('Memo', () {
    testWidgets('no vuelve a armar con las mismas deps; sí si cambian o '
        'cambia algo heredado', (tester) async {
      var builds = 0;
      Widget app(List<Object?> deps, double scale) => MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Memo(
                deps: deps,
                builder: (context) {
                  builds++;
                  return Text(
                      '${deps.first} ${MediaQuery.textScalerOf(context).scale(10)}');
                },
              ),
            ),
          );
      await tester.pumpWidget(app([1, 'a'], 1));
      await tester.pumpWidget(app([1, 'a'], 1));
      expect(builds, 1);
      await tester.pumpWidget(app([2, 'a'], 1));
      expect(builds, 2);
      expect(find.text('2 10.0'), findsOneWidget);
      // Texto más grande (heredado): se vuelve a armar.
      await tester.pumpWidget(app([2, 'a'], 2));
      expect(builds, 3);
      expect(find.text('2 20.0'), findsOneWidget);
    });
  });

  group('registro de rendimiento', () {
    test('percentiles', () {
      final s = FrameStats([for (var i = 1; i <= 100; i++) i * 1000]);
      expect(s.p50, closeTo(50, 1));
      expect(s.p90, closeTo(90, 1));
      expect(s.max, 100);
      expect(FrameStats(const []).p99, 0);
    });

    test('una línea cada 10 s de cuadros, con las sondas', () {
      final out = <String>[];
      final log = PerfLog(sink: out.add);
      PerfLog.probes['mapa'] = () => 'tiles en caché';
      addTearDown(() => PerfLog.probes.remove('mapa'));
      const ms = Duration(milliseconds: 1);
      for (var i = 0; i < 600; i++) {
        log.add(ms * 4, ms * 6, ms * 12, i * 16667);
      }
      expect(out, isEmpty, reason: 'menos de 10 s');
      log.add(ms * 4, ms * 30, ms * 40, 601 * 16667);
      expect(out, hasLength(1));
      expect(out.single, startsWith('Rendimiento: 601 cuadros (60.0 fps)'));
      expect(out.single, contains('build p50 4.00'));
      expect(out.single, contains('raster p50 6.00'));
      expect(out.single, contains('máx 30.00'));
      expect(out.single, contains('mapa: tiles en caché'));
    });
  });
}
