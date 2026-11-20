// Layout como datos (docs/specs/editor_layout.md § 2, § 4 "Tests"):
// parser, merge override → repo → defecto, validador estático,
// overrides en disco, publicar y paquete de arte.
import 'dart:io';

import 'package:echos_del_tiempo/core/layout/layout_catalog.dart';
import 'package:echos_del_tiempo/core/layout/layout_doc.dart';
import 'package:echos_del_tiempo/core/layout/layout_overrides_io.dart';
import 'package:echos_del_tiempo/core/layout/layout_validator.dart';
import 'package:echos_del_tiempo/features/admin/domain/sprites/art_pack.dart';
import 'package:echos_del_tiempo/features/characters/presentation/stash_layout.dart';
import 'package:flutter_test/flutter_test.dart';

class _Over implements LayoutOverrideSource {
  _Over(this.files);
  final Map<String, String> files;
  @override
  Future<String?> read(String screen) async => files[screen];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final spec = StashLayout.spec;
  final def = spec.defaults;

  test('el YAML del repo es el layout por defecto en código', () {
    final repo =
        LayoutDoc.parse(File('assets/layouts/stash.layout.yaml').readAsStringSync());
    expect(repo.sameAs(def), isTrue, reason: repo.encode());
    expect(LayoutValidator.validateStatic(repo, spec), isEmpty);
    final manifest = File(LayoutCatalog.manifestPath).readAsStringSync();
    expect(manifest, contains('stash: stash.layout.yaml'));
  });

  test('encode/parse es estable (ida y vuelta)', () {
    final moved = def
        .move(StashLayout.actions, 'header', 0)
        .move(StashLayout.pick, 'right', 1)
        .withRule(LayoutBreakpoint.narrow, StashLayout.actions,
            (r) => r.copyWith(axis: LayoutAxis.column, stretch: true))
        .withRule(null, StashLayout.title, (r) => r.copyWith(hide: true));
    final again = LayoutDoc.parse(moved.encode());
    expect(again.sameAs(moved), isTrue);
    expect(again.encode(), moved.encode());
  });

  test('resolve: base, reglas por corte y ocultos', () {
    final d = def
        .move(StashLayout.pick, 'right', 0, bp: LayoutBreakpoint.narrow)
        .withRule(LayoutBreakpoint.narrow, StashLayout.title,
            (r) => r.copyWith(hide: true));
    final base = d.resolve(null);
    expect(base.of(StashLayout.actions),
        [StashLayout.transfer, StashLayout.moveAll, StashLayout.pick]);
    final n = d.resolve(LayoutBreakpoint.narrow);
    expect(n.of('right').first, StashLayout.pick);
    expect(n.of(StashLayout.actions), [StashLayout.transfer, StashLayout.moveAll]);
    expect(n.containerOf(StashLayout.title), isNull);
    expect(d.resolve(LayoutBreakpoint.wide).of('left').first, StashLayout.title);
    // Cacheado: misma instancia por corte.
    expect(identical(d.resolve(null), d.resolve(null)), isTrue);
  });

  test('cortes globales en anchos de texto', () {
    expect(LayoutBreakpoints.of(30), LayoutBreakpoint.narrow);
    expect(LayoutBreakpoints.of(60), LayoutBreakpoint.medium);
    expect(LayoutBreakpoints.of(100), LayoutBreakpoint.wide);
    expect(LayoutBreakpoints.of(200), LayoutBreakpoint.ultra);
  });

  group('validador estático', () {
    List<String> errs(LayoutDoc d) => [
          for (final i in LayoutValidator.validateStatic(d, spec))
            if (i.error) '${i.slot}: ${i.message}',
        ];

    test('mover entre regiones permitidas valida', () {
      expect(
          errs(def
              .move(StashLayout.actions, 'header', 0)
              .move(StashLayout.pick, 'right', 0)),
          isEmpty);
    });

    test('un fijo no se mueve', () {
      expect(errs(def.move(StashLayout.stashGrid, 'left', 0)),
          contains(contains('fijo')));
    });

    test('allowedRegions: la línea de estado no va a un lado', () {
      expect(errs(def.move(StashLayout.status, 'left', 0)), isNotEmpty);
    });

    test('ocultar solo lo ocultable (nunca acciones únicas)', () {
      expect(
          errs(def.withRule(
              null, StashLayout.title, (r) => r.copyWith(hide: true))),
          isEmpty);
      expect(
          errs(def.withRule(LayoutBreakpoint.narrow, StashLayout.moveAll,
              (r) => r.copyWith(hide: true))),
          isNotEmpty);
    });

    test('ids desconocidos, repetidos, faltantes, regiones nuevas y ciclos', () {
      final d = LayoutDoc(screen: 'stash', slots: [
        ...def.slots.where((s) => s.id != StashLayout.ecoNote),
        const SlotPlacement('stash.nuevo', 'left', 9),
        const SlotPlacement(StashLayout.title, 'left', 10),
        const SlotPlacement(StashLayout.actions, 'sidebar', 0),
      ]);
      final e = errs(d).join('\n');
      expect(e, contains('stash.nuevo: Slot desconocido'));
      expect(e, contains('Slot repetido'));
      expect(e, contains('${StashLayout.ecoNote}: Falta'));
      expect(e, contains('Región desconocida "sidebar"'));
      final cyc = def.move(StashLayout.actions, StashLayout.actions, 0);
      expect(errs(cyc), isNotEmpty);
    });
  });

  test('geometría: fuera, solapes, clic mínimo y orden de foco', () {
    final issues = LayoutValidator.validateGeometry(
      where: 't',
      viewport: const LayoutRect(0, 0, 100, 100),
      slots: const {
        'a': LayoutRect(0, 0, 50, 40),
        'b': LayoutRect(40, 0, 50, 40),
        'c': LayoutRect(90, 50, 20, 20),
      },
      siblings: const [
        ['a', 'b'],
      ],
      targets: const {
        'c': [LayoutRect(90, 50, 20, 20)],
      },
      focusGroups: const [
        ['c', 'a'],
      ],
    ).map((i) => i.message).join('\n');
    expect(issues, contains('Fuera de la ventana'));
    expect(issues, contains('Se solapa con b'));
    expect(issues, contains('Objetivo de clic chico'));
    expect(issues, contains('Orden de foco'));
  });

  group('LayoutCatalog', () {
    test('override válido → repo → código; inválido se ignora', () async {
      final moved = def.move(StashLayout.actions, 'header', 0);
      final cat = LayoutCatalog(overrides: _Over({'stash': moved.encode()}));
      await cat.reload('stash');
      cat.setRepoText('stash', def.encode());
      expect(cat.docFor(spec).sameAs(moved), isTrue);
      expect(cat.sourceOf('stash'), 'override');

      final bad = def.move(StashLayout.stashGrid, 'left', 0);
      final cat2 = LayoutCatalog(overrides: _Over({'stash': bad.encode()}));
      await cat2.reload('stash');
      cat2.setRepoText('stash', moved.encode());
      expect(cat2.docFor(spec).sameAs(moved), isTrue);
      expect(cat2.sourceOf('stash'), 'repo');
      expect(cat2.log.join(), contains('inválido'));

      final cat3 = LayoutCatalog(overrides: _Over({'stash': 'no: [yaml'}));
      await cat3.reload('stash');
      expect(identical(cat3.docFor(spec), def), isTrue);
      expect(cat3.sourceOf('stash'), 'código');
    });

    test('carga el manifest y el YAML del bundle', () async {
      final cat = LayoutCatalog();
      await cat.load();
      expect(cat.screens, contains('stash'));
      expect(cat.docFor(spec).sameAs(def), isTrue);
      expect(cat.sourceOf('stash'), 'repo');
    });
  });

  test('overrides en disco, publicar al repo y paquete de arte', () async {
    final tmp = Directory.systemTemp.createTempSync('ecos_layout_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final repo = '${tmp.path}/repo';
    Directory('$repo/assets/layouts').createSync(recursive: true);
    File('$repo/assets/layouts/layout_manifest.yaml')
        .writeAsStringSync('# m\nscreens:\n  other: other.layout.yaml\n');
    final o = LocalLayoutOverrides('${tmp.path}/overrides');
    final moved = def.move(StashLayout.actions, 'header', 0);
    await o.put('stash', moved.encode());
    expect(await o.screens(), {'stash'});
    expect(LayoutDoc.parse((await o.read('stash'))!).sameAs(moved), isTrue);

    final pack = ArtPack(const {}, const {}, null, {'stash': moved.encode()});
    final back = ArtPack.decode(pack.encode());
    expect(back.layouts['stash'], moved.encode());

    expect(await o.publish(repo, 'stash'), isTrue);
    expect(await o.read('stash'), isNull);
    final pub = File('$repo/assets/layouts/stash.layout.yaml').readAsStringSync();
    expect(LayoutDoc.parse(pub).sameAs(moved), isTrue);
    final m = File('$repo/assets/layouts/layout_manifest.yaml').readAsStringSync();
    expect(m, contains('  other: other.layout.yaml'));
    expect(m, contains('  stash: stash.layout.yaml'));
    expect(addLayoutManifestEntry(m, 'stash', 'stash.layout.yaml'), m);
  });
}
