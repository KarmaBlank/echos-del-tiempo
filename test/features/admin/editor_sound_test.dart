// Editor → Animaciones con sonido y tooltips (docs/specs/game_editor.md
// § 7.6). Overrides en carpetas temporales (nunca %APPDATA% ni el repo).
import 'dart:io';
import 'dart:typed_data';

import 'package:echos_del_tiempo/app/design/design.dart';
import 'package:echos_del_tiempo/core/audio/sfx_catalog.dart';
import 'package:echos_del_tiempo/core/audio/sfx_files.dart';
import 'package:echos_del_tiempo/core/audio/sfx_service.dart';
import 'package:echos_del_tiempo/core/audio/wav_synth.dart';
import 'package:echos_del_tiempo/core/fx/fx_catalog.dart';
import 'package:echos_del_tiempo/features/admin/domain/sprites/art_pack.dart';
import 'package:echos_del_tiempo/features/admin/presentation/admin_app.dart';
import 'package:echos_del_tiempo/features/admin/presentation/admin_controller.dart';
import 'package:echos_del_tiempo/features/admin/presentation/editor/animations_page.dart';
import 'package:echos_del_tiempo/features/admin/presentation/editor/fx_editor_controller.dart';
import 'package:echos_del_tiempo/features/admin/presentation/editor/sprite_editor_controller.dart';
import 'package:echos_del_tiempo/features/admin/presentation/editor/sprites_page.dart';
import 'package:echos_del_tiempo/features/admin/presentation/field_editors.dart';
import 'package:echos_del_tiempo/features/combat/data/local_sprite_overrides_io.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/fx_bridge.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/ult_cinematic.dart';
import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_sfx.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'fake_admin_host.dart';

class _DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());
}

class _Rec implements SfxPlayer {
  final played = <(Uint8List, double)>[];
  @override
  Future<void> play(Uint8List wav, {double volume = 1}) async =>
      played.add((wav, volume));
}

const _manifest = 'fx:\n  ult_espada: ult/ult_espada.fx.yaml\n';
const _fx = '''
schema: 1
id: ult_espada
category: ult
name: Prueba
duration: 1000
phases: { build: 400, release: 400, recover: 200 }
tracks:
  - type: sound
    fire:
      - { t: 0, cue: build }
      - { t: 400, cue: release, vol: 0.5, pitch: 1.5 }
      - { t: 700, cue: hit }
''';

Uint8List _wav(int n) {
  final s = Float64List(n);
  for (var i = 0; i < n; i++) {
    s[i] = (i % 20) / 20 - 0.5;
  }
  return const WavSynth().encode(s);
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('ecos_sfx_ed_'));
  tearDown(() {
    SfxFiles.active = null;
    tmp.deleteSync(recursive: true);
  });

  FxEditorController make(_Rec rec, {LocalSpriteOverrides? o}) {
    final c = FxEditorController(
        catalog: FxCatalog.fromFiles(_manifest, {'ult/ult_espada.fx.yaml': _fx}),
        overrides: o,
        sfx: SfxService(player: rec, files: () => SfxFiles.active));
    c.select('ult_espada');
    return c;
  }

  test('la pista sound suena en su momento al reproducir, no en scrub', () {
    final rec = _Rec();
    final c = make(rec);
    c.togglePlay();
    c.advance(10);
    expect(c.firedSounds, [('ult_espada.build', 0)]);
    c.advance(380); // 390 ms
    expect(c.firedSounds.length, 1);
    c.advance(20); // 410 ms
    expect(c.firedSounds.last, ('ult_espada.release', 400));
    expect(rec.played.last.$2, closeTo(0.5, 1e-9)); // vol del disparo
    // Scrub (pausa) por encima de 700: no suena.
    c.seek(800);
    c.seek(650);
    expect(c.firedSounds.length, 2);
    // Retoma desde 650: suena 700 una sola vez.
    c.togglePlay();
    c.advance(100);
    expect(c.firedSounds.last, ('hit', 700));
    expect(c.firedSounds.length, 3);
    // SILENCIO: se sigue la pista pero no se toca nada.
    final before = rec.played.length;
    c.setMuted(true);
    c.seek(0);
    c.togglePlay();
    c.advance(10);
    expect(c.firedSounds.length, 4);
    expect(rec.played.length, before);
  });

  test('velocidad: a ×0.25 el disparo de 400 ms llega más tarde', () {
    final c = make(_Rec())..setSpeed(0.25);
    c.togglePlay();
    for (var i = 0; i < 50; i++) {
      c.advance(30); // 1500 ms reales = 375 ms de animación
    }
    expect(c.firedSounds.map((e) => e.$2), [0]);
    c.advance(200);
    expect(c.firedSounds.map((e) => e.$2), [0, 400]);
  });

  test('override de sfx pisa y revierte, y viaja en el paquete', () async {
    final o = LocalSpriteOverrides('${tmp.path}/ov');
    SfxFiles.active = SfxFiles.fromMaps({}, overrides: o);
    final rec = _Rec();
    final c = make(rec, o: o);
    final service = c.sfx!;
    final synth = service.wav(Sfx.hit);
    final file = _wav(400);
    await c.putSound(Sfx.hit, file);
    expect(c.soundOverridden(Sfx.hit), isTrue);
    expect(service.wav(Sfx.hit), file);
    // Tono: un WAV PCM16 a ×2 dura la mitad.
    expect(service.tunedWav(Sfx.hit, 2).length, lessThan(file.length));
    // Un sonido nuevo por archivo también se puede elegir.
    await c.putSound('mio.campana', _wav(200));
    expect(c.soundChoices, contains('mio.campana'));
    expect(service.knows('mio.campana'), isTrue);

    // Paquete de arte: ida y vuelta.
    final zip = await o.exportPack();
    expect(ArtPack.decode(zip).sfx.keys, containsAll([Sfx.hit, 'mio.campana']));
    final o2 = LocalSpriteOverrides('${tmp.path}/ov2');
    final got = await o2.importPack(zip);
    expect(got, contains(Sfx.hit));
    expect(await o2.readSfx(Sfx.hit), file);

    await c.revertSound(Sfx.hit);
    expect(c.soundOverridden(Sfx.hit), isFalse);
    expect(service.wav(Sfx.hit), synth);
    // No WAV/OGG: aviso, sin override.
    await c.putSound('x', Uint8List.fromList([1, 2, 3]));
    expect(c.notice!.error, isTrue);
  });

  test('publicar sonidos al repo: archivo + sfx_manifest', () async {
    final repo = Directory('${tmp.path}/repo/assets/sfx')..createSync(recursive: true);
    File('${repo.path}/sfx_manifest.yaml').writeAsStringSync('# x\nsfx: {}\n');
    final o = LocalSpriteOverrides('${tmp.path}/ov');
    await o.putSfx('hit', _wav(100));
    final done = await o.publishSfx('${tmp.path}/repo');
    expect(done, ['hit']);
    expect(File('${repo.path}/hit.wav').existsSync(), isTrue);
    expect(File('${repo.path}/sfx_manifest.yaml').readAsStringSync(),
        contains('  hit: hit.wav'));
    expect(o.overriddenSfx, isEmpty);
  });

  test('las ULT del repo traen la pista sound con el mismo resultado que '
      'el código', () async {
    await installFx(bundle: _DiskBundle());
    final service = SfxService();
    final sfx = SessionSfx(service, localId: 'yo');
    final ids = [
      for (final f in [
        ...Directory('assets/fx/ult').listSync(),
        ...Directory('assets/fx/enemy_ult').listSync(),
      ])
        f.uri.pathSegments.last.replaceAll('.fx.yaml', ''),
    ];
    expect(ids.length, greaterThan(100));
    for (final id in ids) {
      final script = ultScriptFor(id);
      final data = script.data!;
      expect(data.track('sound'), isNotNull, reason: id);
      // Lo que hacía el código antes de pasarlo a datos.
      final code = service.catalog.containsKey(Sfx.ult(id, Sfx.ultBuild))
          ? [
              (id: Sfx.ult(id, Sfx.ultBuild), delayMs: 0),
              (id: Sfx.ult(id, Sfx.ultRelease), delayMs: script.buildMs),
            ]
          : [(id: Sfx.ultimate, delayMs: 0)];
      expect(sfx.dataSoundCues(data, id), code, reason: id);
    }
  });

  testWidgets('ningún control de Animaciones ni de Sprites queda sin tooltip',
      (tester) async {
    tester.view.physicalSize = const Size(1800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final o = LocalSpriteOverrides('${tmp.path}/overrides');
    final cat = SpriteCatalog.fromYaml(
        File(SpriteCatalog.manifestPath).readAsStringSync(),
        bundle: _DiskBundle(),
        overrides: o);
    final s = SpriteEditorController(catalog: cat, overrides: o);
    final c = AdminController(
        host: FakeAdminHost(files: {
      'repo/pubspec.yaml': File('pubspec.yaml').readAsStringSync(),
      'repo/assets/balance/balance.json':
          File('assets/balance/balance.json').readAsStringSync(),
    }));
    late FxEditorController fx;
    await tester.runAsync(() async {
      await c.load();
      fx = FxEditorController(
          catalog: await installFx(bundle: _DiskBundle(), overrides: o),
          overrides: o,
          sfx: SfxService(player: _Rec()));
    });
    await tester.pumpWidget(AdminApp(
        controller: c,
        sprites: s,
        animations: fx,
        initialArea: EditorArea.visuals,
        initialVisualTab: 1));
    await tester.pump();

    void expectAllTipped(String where, Type page) {
      Finder inPage(Type t) =>
          find.descendant(of: find.byType(page), matching: find.byType(t));
      for (final b in tester.widgetList<DsButton>(inPage(DsButton))) {
        expect(b.tooltip, isNotNull,
            reason: '$where: botón "${b.label}" sin tooltip');
      }
      for (final r in tester.widgetList<DsListRow>(inPage(DsListRow))) {
        expect(r.tooltip, isNotNull, reason: '$where: fila "${r.title}" sin tooltip');
      }
      for (final type in [NumberStepper, DsSearchField]) {
        for (final e in inPage(type).evaluate()) {
          bool tipped(Type t) => find
              .ancestor(of: find.byWidget(e.widget), matching: find.byType(t))
              .evaluate()
              .isNotEmpty;
          expect(tipped(Tooltip) || tipped(DsTooltip), isTrue,
              reason: '$where: $type sin tooltip');
        }
      }
    }

    // Animación de datos con un disparo de sonido elegido.
    fx.select('ult_espada');
    final t = fx.edit!;
    final track = t.tracks.indexWhere((tr) => tr.type == 'sound');
    fx.selectKey((track: track, fire: true, index: 1));
    await tester.pump();
    expect(find.byKey(const ValueKey('fx-sound-listen')), findsOneWidget);
    expectAllTipped('Animaciones / sonido', AnimationsPage);
    // Un key con curva (pista de keys).
    final dim = t.tracks.indexWhere((tr) => tr.keys.isNotEmpty);
    fx.selectKey((track: dim, fire: false, index: 0));
    await tester.pump();
    expectAllTipped('Animaciones / key', AnimationsPage);
    // Legacy (CONVERTIR A DATOS), si queda alguna.
    final legacy = fx.ids.where((id) => fx.timelineOf(id)?.legacy ?? false);
    if (legacy.isNotEmpty) {
      fx.select(legacy.first);
      await tester.pump();
      expectAllTipped('Animaciones / legacy', AnimationsPage);
    }

    // Sprites, con un procedural de perillas elegido.
    await tester.tap(find.text('SPRITES'));
    await tester.pump();
    for (final e in s.visible) {
      s.select(e);
      if (s.hasKnobs) break;
    }
    await tester.pump();
    expectAllTipped('Sprites', SpritesPage);
    await tester.pumpWidget(const SizedBox());
  });
}
