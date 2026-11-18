import 'package:echos_del_tiempo/core/settings/crt_filter.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/core/settings/settings_providers.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('CrtParams', () {
    test('APAGADO no tiene parámetros; el resto sube de SUAVE a FUERTE', () {
      expect(CrtParams.of(CrtLevel.off), isNull);
      final s = CrtParams.of(CrtLevel.soft)!;
      final n = CrtParams.of(CrtLevel.normal)!;
      final f = CrtParams.of(CrtLevel.strong)!;
      for (final (a, b) in [(s, n), (n, f)]) {
        expect(b.scan, greaterThan(a.scan));
        expect(b.mask, greaterThan(a.mask));
        expect(b.bloom, greaterThan(a.bloom));
        expect(b.vignette, greaterThan(a.vignette));
        expect(b.curve, greaterThanOrEqualTo(a.curve));
      }
      expect(s.curve, 0, reason: 'SUAVE no curva');
      // La curva remuestrea la UI y ensucia la fuente pixel: solo FUERTE.
      expect(n.curve, 0, reason: 'NORMAL (por defecto) no curva');
      expect(f.curve, greaterThan(0));
      // Legible: la scanline de NORMAL oscurece como mucho un 24%.
      expect(n.scan, lessThanOrEqualTo(0.25));
    });

    test('scanline cada ~1/240 del alto, al menos 2 px', () {
      expect(CrtParams.lineFor(720), 3);
      expect(CrtParams.lineFor(1080), 5);
      expect(CrtParams.lineFor(2160), 9);
      expect(CrtParams.lineFor(300), 2);
      expect(CrtParams.maskWidthFor(1), 1);
      expect(CrtParams.maskWidthFor(2), 2);
      expect(CrtParams.of(CrtLevel.normal)!.uniforms(3, 1), hasLength(7));
    });
  });

  group('crtWarp (clics con curvatura)', () {
    const size = Size(1280, 720);

    test('sin curvatura, el centro y los ejes no se mueven', () {
      expect(crtWarp(const Offset(37, 500), size, 0), const Offset(37, 500));
      expect(crtWarp(const Offset(640, 360), size, 0.05),
          const Offset(640, 360));
    });

    test('con curvatura, una esquina se ve más hacia afuera del contenido',
        () {
      final w = crtWarp(const Offset(20, 20), size, 0.02);
      expect(w.dx, lessThan(20));
      expect(w.dy, lessThan(20));
      // NORMAL: a lo sumo unos pocos px en la esquina.
      expect((w - const Offset(20, 20)).distance, lessThan(8));
      final far = crtWarp(const Offset(1260, 700), size, 0.05);
      expect(far.dx, greaterThan(1260));
      expect(far.dy, greaterThan(700));
    });

    test('el hit-test va al punto deformado', () {
      final box = RenderCrtHitWarp(0.05);
      final child = _RecordingBox();
      box.child = child;
      box.layout(BoxConstraints.tight(size));
      final result = BoxHitTestResult();
      box.hitTest(result, position: const Offset(40, 40));
      final expected = crtWarp(const Offset(40, 40), size, 0.05);
      expect(child.last!.dx, closeTo(expected.dx, 1e-9));
      expect(child.last!.dy, closeTo(expected.dy, 1e-9));
      box.curve = 0;
      box.hitTest(BoxHitTestResult(), position: const Offset(40, 40));
      expect(child.last, const Offset(40, 40));
    });
  });

  group('CrtFilter en la app', () {
    testWidgets('prendido por defecto (NORMAL) y se apaga en vivo',
        (tester) async {
      final settings = GameSettingsController(store: InMemoryGameSettingsStore());
      await tester.pumpWidget(ProviderScope(
        overrides: [gameSettingsProvider.overrideWith((ref) => settings)],
        child: MaterialApp(
          builder: (context, child) => Consumer(
            builder: (context, ref, _) => CrtFilter(
              level: ref.watch(gameSettingsProvider.select((s) => s.crt)),
              child: child!,
            ),
          ),
          home: const _Counter(),
        ),
      ));
      // Carga de los shaders (asíncrona).
      await tester.runAsync(() => CrtShaders.load());
      await tester.pump();
      final state = tester.state<CrtFilterState>(find.byType(CrtFilter));
      expect(state.widget.level, CrtLevel.normal);
      expect(state.mode, isNot('off'));
      expect(state.mode, 'overlay', reason: 'flutter test no usa Impeller');
      // Sin Impeller (flutter test): capa encima, o nada si no cargó.
      expect(['overlay', 'filter', 'none'], contains(state.mode));

      // Un contador dentro: apagar y prender no reconstruye lo de abajo.
      await tester.tap(find.byKey(const ValueKey('inc')));
      await tester.pump();
      expect(find.text('1'), findsOneWidget);
      await settings.update(settings.state.copyWith(crt: CrtLevel.off));
      await tester.pump();
      expect(state.mode, 'off');
      expect(find.text('1'), findsOneWidget, reason: 'no perdió el estado');
      await settings.update(settings.state.copyWith(crt: CrtLevel.strong));
      await tester.pump();
      expect(state.mode, isNot('off'));
      expect(find.text('1'), findsOneWidget);
    });
  });
}

class _RecordingBox extends RenderProxyBox {
  Offset? last;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    last = position;
    return true;
  }
}

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int n = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Column(children: [
          Text('$n'),
          ElevatedButton(
              key: const ValueKey('inc'),
              onPressed: () => setState(() => n++),
              child: const Text('+')),
        ]),
      );
}
