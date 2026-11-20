import 'dart:io';
import 'dart:ui';

import 'package:echos_del_tiempo/core/fx/fx_catalog.dart';
import 'package:echos_del_tiempo/features/admin/domain/sprites/art_pack.dart';
import 'package:echos_del_tiempo/features/admin/presentation/editor/fx_editor_controller.dart';
import 'package:echos_del_tiempo/features/combat/data/local_sprite_overrides_io.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/duo_cinematic.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/fx_bridge.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/fx_player.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/fx_style.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/particles.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/ult_cinematic.dart';
import 'package:echos_del_tiempo/game_engine/data/skills_catalog.dart';
import 'package:echos_del_tiempo/game_engine/fx/cinematic_durations.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_event.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bundle que lee del disco del repo (sin tocar el rootBundle).
class _DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final f = File(key);
    if (!f.existsSync()) throw StateError('no existe $key');
    return ByteData.sublistView(f.readAsBytesSync());
  }
}

/// Animaciones como datos (docs/specs/game_editor.md § 2 y § 7.2).
void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('ecos_fx_'));
  tearDown(() {
    FxCatalog.active = null;
    CinematicDurations.shared = const CinematicDurations();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Future<FxCatalog> load([FxOverrideSource? o]) => FxCatalog.load(
      bundle: _DiskBundle(), overrides: o, legacy: const LegacyFxAdapter());

  /// Las 13 ULT de arma (`kUltimates` + `kNewUltimates`).
  final ults = [
    for (final sk in [...kUltimates.values, ...kNewUltimates.values]) sk.id
  ];

  group('formato FXA', () {
    test('parse → toYaml → parse conserva todo', () {
      final raw = File('assets/fx/ult/ult_espada.fx.yaml').readAsStringSync();
      final a = FxTimeline.parse(raw);
      final b = FxTimeline.parse(a.toYaml());
      expect(b.toYaml(), a.toYaml());
      expect(b.duration, 2300);
      expect(b.impacts.single.t, 1400);
      expect(b.preHits, [1000, 1120, 1240]);
      expect(b.track('echo')!.n('count'), 3);
    });

    test('interpolación con curva y valores de texto escalonados', () {
      final tr = FxTrack('dim', keys: [
        FxKey(0, {'v': 0, 'focus': 'caster'}),
        FxKey(100, {'v': 1, 'focus': 'target'}, FxEase.linear),
      ]);
      expect(tr.numAt('v', 50), closeTo(0.5, 1e-9));
      expect(tr.numAt('v', 500), 1);
      expect(tr.textAt('focus', 40), 'caster');
      expect(tr.textAt('focus', 100), 'target');
    });

    test('roto o de un schema futuro: FormatException; pistas desconocidas avisan',
        () {
      expect(() => FxTimeline.parse('id: x'), throwsFormatException);
      expect(() => FxTimeline.parse('schema: 9\nid: x\nduration: 10'),
          throwsFormatException);
      final t = FxTimeline.parse(
          'id: x\nduration: 9000\ntracks:\n  - type: holograma\n');
      expect(t.duration, kFxMaxDurationMs);
      expect(t.warnings, hasLength(2));
      expect(t.tracks.single.known, isFalse);
    });
  });

  group('catálogo', () {
    test('carga todas las fx del manifest sin avisos', () async {
      final cat = await load();
      expect(cat.log, isEmpty);
      final manifest = File(FxCatalog.manifestPath).readAsStringSync();
      for (final id in cat.paths.keys) {
        expect(manifest, contains('$id:'));
        expect(cat.sourceOf(id), FxSource.data, reason: id);
        final t = cat.timeline(id)!;
        expect(t.legacy, isFalse);
        for (final tr in t.tracks) {
          expect(tr.known, isTrue, reason: '$id: ${tr.type}');
        }
        expect(t.phases.total, t.duration, reason: id);
      }
      // Las 13 ULT y el dúo tienen datos propios.
      expect(cat.paths.keys, containsAll([...ults, 'duo']));
      expect(ults, hasLength(13));
    });

    test('todas las ULT duran ≤ 2.6 s, con ecos e impacto dentro', () async {
      final cat = await load();
      for (final id in ults) {
        final t = cat.timeline(id)!;
        expect(t.duration, lessThanOrEqualTo(kUltMaxDurationMs), reason: id);
        expect(t.duration, greaterThanOrEqualTo(1800), reason: id);
        expect(t.ofType('echo'), isNotEmpty, reason: '$id: firma de ecos');
        expect(t.impacts, isNotEmpty, reason: id);
        for (final f in t.track('impact')!.fires) {
          expect(f.t, lessThan(t.duration), reason: id);
        }
        // Destellos legibles (§ 5.1).
        for (final tr in t.ofType('flash')) {
          for (final f in tr.fires) {
            expect(f.d('alpha', 0), lessThanOrEqualTo(0.7), reason: id);
          }
        }
      }
      expect(cat.timeline('duo')!.duration, lessThanOrEqualTo(kUltMaxDurationMs));
    });

    test('el override pisa al asset y se revierte', () async {
      final o = LocalSpriteOverrides('${tmp.path}/ov');
      final cat = await load(o);
      final base = cat.timeline('ult_espada')!;
      await o.putFx('ult_espada', base.copyWith(duration: 2000).toYaml());
      await cat.reload('ult_espada');
      expect(cat.timeline('ult_espada')!.duration, 2000);
      expect(cat.sourceOf('ult_espada'), FxSource.override);
      // El release no cambia (el host usa esta).
      expect(cat.assetTimeline('ult_espada')!.duration, 2300);
      expect(cat.releaseDurations().ultMs('ult_espada'), 2300);
      await o.removeFx('ult_espada');
      await cat.reload('ult_espada');
      expect(cat.timeline('ult_espada')!.duration, 2300);
      expect(cat.sourceOf('ult_espada'), FxSource.data);
      // Un override roto no rompe: se usa el asset.
      await o.putFx('ult_hacha', 'id: [');
      await cat.reload();
      expect(cat.timeline('ult_hacha')!.duration, 2400);
      expect(cat.log.last, contains('ult_hacha'));
    });

    test('edición en vivo: se reproduce hasta descartarla', () async {
      final cat = await load();
      final t = cat.timeline('ult_tomo')!;
      cat.setLive('ult_tomo', t.copyWith(duration: 1900));
      expect(cat.durationOf('ult_tomo'), 1900);
      cat.clearLive('ult_tomo');
      expect(cat.durationOf('ult_tomo'), 2500);
    });
  });

  group('adaptador legacy', () {
    test('cada guion del código tiene su timeline equivalente', () async {
      const a = LegacyFxAdapter();
      for (final id in [...kUltScripts.keys, ...kEnemyUltScripts.keys]) {
        final s = codeUltScriptFor(id);
        final t = a.build(id)!;
        expect(t.legacy, isTrue);
        expect(t.duration, s.totalMs, reason: id);
        expect(t.impacts.single.t, s.impactMs, reason: id);
        expect(t.preHits, s.preHitsMs, reason: id);
        expect(t.track('legacy')!.s('style'), s.style.name);
        // Ida y vuelta: el guion derivado coincide con el original (test
        // de oro de tiempos, § 2.3).
        final back = scriptFromTimeline(t, s.style);
        expect(back.buildMs, s.buildMs, reason: id);
        expect(back.returnAt, s.returnAt, reason: id);
        expect(back.totalMs, s.totalMs, reason: id);
        expect(back.staggerMs, s.staggerMs, reason: id);
        expect(back.hitStopMs, s.hitStopMs, reason: id);
        expect(back.shake, s.shake, reason: id);
        expect(back.focus, s.focus, reason: id);
      }
      expect(a.build('duo')!.duration, kDuoScript.totalMs);
      expect(a.build('nada'), isNull);
    });

    test('las ULT enemigas siguen en el código y aparecen en el catálogo', () async {
      final cat = await load();
      expect(cat.sourceOf('eult_diluvio'), FxSource.legacy);
      expect(cat.timeline('eult_diluvio')!.category, 'enemy_ult');
      expect(cat.ids, contains('eult_diluvio'));
    });
  });

  group('escena', () {
    test('con catálogo activo, la ULT y el dúo usan el guion de los datos',
        () async {
      expect(ultScriptFor('ult_espada').data, isNull, reason: 'sin catálogo');
      final cat = await installFx(bundle: _DiskBundle());
      final s = ultScriptFor('ult_espada');
      expect(s.data, same(cat.timeline('ult_espada')));
      expect(s.totalMs, 2300);
      expect(s.impactMs, 1400);
      expect(s.hitStopMs, 120);
      expect(s.focus, UltFocus.single);
      expect(s.style, UltStyle.finalSlash, reason: 'el sonido sigue igual');
      expect(duoScript('guerrero+maga').data, same(cat.timeline('duo')));
      // Las ULT enemigas no cambian.
      expect(ultScriptFor('eult_diluvio').data, isNull);
      // Y el motor recibe las duraciones del release.
      expect(CinematicDurations.shared.ultMs('ult_baculo'), 2600);
      expect(CinematicDurations.shared.duoMs('x+y'), 1600);
    });

    test('FxPlayer: dispara una vez, respeta el adelanto y dibuja sin errores',
        () async {
      final cat = await load();
      const st = FxStage(
        caster: Offset(60, 100),
        targets: [Offset(170, 95), Offset(190, 105)],
        color: Color(0xFFFF7B29),
        element: FxElement.burn,
        visible: Rect.fromLTWH(0, 0, 240, 135),
      );
      for (final id in [...ults, 'duo']) {
        final t = cat.timeline(id)!;
        final p = ParticleSystem();
        final done = <String>{};
        var stops = 0;
        for (var a = 0.0; a <= t.duration; a += 16) {
          FxPlayer.tick(t, a, st, p, done, hitStop: (_) => stops++);
          final rec = PictureRecorder();
          FxPlayer.paint(Canvas(rec), t, a, st);
          rec.endRecording().dispose();
        }
        expect(stops, t.track('hitstop')?.fires.length ?? 0, reason: id);
        final again = done.length;
        FxPlayer.tick(t, t.duration.toDouble(), st, p, done, hitStop: (_) {});
        expect(done.length, again, reason: 'una sola vez');
      }
    });
  });

  group('editor', () {
    test('editar un key recarga en caliente; guardar deja override', () async {
      final o = LocalSpriteOverrides('${tmp.path}/ov');
      final cat = await load(o);
      final c = FxEditorController(catalog: cat, overrides: o);
      c.setCategory('ult');
      expect(c.visible, containsAll(ults));
      c.setQuery('mil cortes');
      expect(c.visible, ['ult_dagas']);
      c.select('ult_dagas');
      final hit = cat.timeline('ult_dagas')!.tracks.indexWhere((t) => t.type == 'hitstop');
      final ref = (track: hit, fire: true, index: 0);
      c.setKeyField(ref, 'ms', 90);
      expect(cat.timeline('ult_dagas')!.track('hitstop')!.fires.single.n('ms'), 90,
          reason: 'en vivo');
      expect(c.dirty, isTrue);
      await c.save();
      expect(c.dirty, isFalse);
      expect(cat.sourceOf('ult_dagas'), FxSource.override);
      expect(await o.readFx('ult_dagas'), contains('ms: 90'));
      await c.discardOverride();
      expect(cat.timeline('ult_dagas')!.track('hitstop')!.fires.single.n('ms'), 130);
      // Lo legacy es de solo lectura.
      c.select('eult_diluvio');
      expect(c.readOnly, isTrue);
    });
  });

  group('paquete de arte y repo', () {
    test('exportar/importar ida y vuelta con fx', () async {
      final a = LocalSpriteOverrides('${tmp.path}/a');
      final yaml = File('assets/fx/ult/ult_arco.fx.yaml').readAsStringSync();
      await a.putFx('ult_arco', yaml);
      final zip = await a.exportPack();
      expect(ArtPack.decode(zip).fx.keys, ['ult_arco']);
      final b = LocalSpriteOverrides('${tmp.path}/b');
      final ids = await b.importPack(zip);
      expect(ids, ['ult_arco']);
      await b.refreshFx();
      expect(await b.readFx('ult_arco'), yaml);
    });

    test('publicar al repo copia el .fx.yaml y suma la entrada al manifest',
        () async {
      final repo = '${tmp.path}/repo';
      File('$repo/assets/fx/fx_manifest.yaml')
        ..createSync(recursive: true)
        ..writeAsStringSync('# índice\nschema: 1\nfx:\n  ult_espada: ult/ult_espada.fx.yaml\n');
      final o = LocalSpriteOverrides('${tmp.path}/ov');
      await o.putFx('ult_espada', 'id: ult_espada\nduration: 2000\n');
      await o.putFx('skill_nueva', 'id: skill_nueva\nduration: 500\n');
      final done = await o.publishFx(repo, {
        'ult_espada': 'ult/ult_espada.fx.yaml',
        'skill_nueva': 'skill/skill_nueva.fx.yaml',
      });
      expect(done.toSet(), {'ult_espada', 'skill_nueva'});
      final m = File('$repo/assets/fx/fx_manifest.yaml').readAsStringSync();
      expect(m, startsWith('# índice'));
      expect(m, contains('  skill_nueva: skill/skill_nueva.fx.yaml'));
      expect('ult_espada:'.allMatches(m), hasLength(1));
      expect(File('$repo/assets/fx/skill/skill_nueva.fx.yaml').existsSync(), isTrue);
      await o.refreshFx();
      expect(o.overriddenFx, isEmpty);
    });
  });

  test('CinematicDurations: datos, dúo por clave y valores históricos', () {
    const d = CinematicDurations({'ult_x': 2500, 'duo': 1600, 'duo_a+b': 1700});
    expect(d.holdFor(const ActionEvent('p0', BattleActionKind.ultimate, skillId: 'ult_x')), 2.5);
    expect(d.holdFor(const ActionEvent('p0', BattleActionKind.ultimate, skillId: 'otra')), 2.3);
    expect(d.holdFor(const ActionEvent('p0', BattleActionKind.dual, skillId: 'a+b')), 1.7);
    expect(d.holdFor(const ActionEvent('p0', BattleActionKind.dual, skillId: 'c+d')), 1.6);
    expect(const CinematicDurations().duoMs(null), 1500);
  });
}
