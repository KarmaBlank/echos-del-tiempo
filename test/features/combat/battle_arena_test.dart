import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/combat/presentation/scene/arena/arena_painter.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/arena/arena_spec.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/arena/arena_transition.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/battle_layout.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/battle_painter.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/battle_scene.dart';
import 'package:echos_del_tiempo/game_engine/data/zones_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/passive_mechanic.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

// Arenas de batalla (docs/specs/battle_presentation.md § "Arenas").

Combatant _hero(String id, {List<TimedEffect>? effects}) => Combatant(
      id: id,
      name: id,
      isPlayer: true,
      hp: 100,
      maxHp: 100,
      speed: 10,
      attack: 10,
      critChance: 0,
      classId: 'guerrero',
      effects: effects,
    );

Combatant _foe(String id, String type,
        {bool boss = false, bool elite = false, int phase = 0, int lava = 0}) =>
    Combatant(
      id: id,
      name: type,
      isPlayer: false,
      hp: 100,
      maxHp: 100,
      speed: 5,
      attack: 5,
      critChance: 0,
      enemyType: type,
      boss: boss,
      elite: elite,
      phase: phase,
      lava: lava,
    );

BattleState _battle({
  int party = 4,
  int foes = 3,
  String? boss,
  int bossPhase = 0,
  List<String> adds = const [],
  bool elite = false,
  int lava = 0,
  List<TimedEffect>? partyEffects,
}) =>
    BattleState(
      boss: boss != null,
      elite: elite,
      party: [
        for (var i = 0; i < party; i++) _hero('p$i', effects: partyEffects),
      ],
      enemies: [
        if (boss != null)
          _foe('boss', boss, boss: true, phase: bossPhase, lava: lava),
        for (var i = 0; i < adds.length; i++) _foe('a$i', adds[i]),
        for (var i = 0; i < foes; i++)
          _foe('e$i', 'slime', elite: elite && i == 0),
      ],
    );

/// Tamaños realistas (sprite × escala × élite): el jefe más grande es el
/// Devorador en fase 2 (≈ 32×32 × 2.8).
Size _size(Combatant e) {
  if (e.boss) return e.phase >= 2 ? const Size(90, 90) : const Size(64, 56);
  if (e.enemyType == 'cristalHielo') return const Size(22, 22);
  final s = e.elite ? 1.45 * 1.8 : 1.8;
  return Size(16 * s, 14 * s);
}

void main() {
  group('selección de arena (pura)', () {
    test('cada zona 1–10 tiene su arena, por tema de mapa y por índice', () {
      const expected = [
        ArenaTheme.pradera,
        ArenaTheme.bosque,
        ArenaTheme.ruinas,
        ArenaTheme.cavernas,
        ArenaTheme.fortaleza,
        ArenaTheme.laberinto,
        ArenaTheme.grieta,
        ArenaTheme.cementerio,
        ArenaTheme.abismo,
        ArenaTheme.corazon,
      ];
      for (final z in kZones) {
        expect(arenaThemeFor(mapTheme: z.theme), expected[z.index - 1],
            reason: z.name);
        expect(arenaThemeFor(zone: z.index), expected[z.index - 1]);
      }
      // Las 10 son distintas.
      expect(expected.toSet(), hasLength(10));
    });

    test('Prueba del Tiempo manda; pueblo / mundo / desconocido', () {
      expect(arenaThemeFor(mapTheme: 'grieta', zone: 7, trial: true),
          ArenaTheme.prueba);
      expect(arenaThemeFor(mapTheme: 'lobby'), ArenaTheme.pueblo);
      expect(arenaThemeFor(mapTheme: 'mundo'), ArenaTheme.pradera);
      expect(arenaThemeFor(), ArenaTheme.pueblo);
      expect(arenaThemeFor(mapTheme: '??', zone: 99), ArenaTheme.pueblo);
    });

    test('tipo de encuentro: normal, élite y jefe (bandera o enemigos)', () {
      expect(encounterKindOf(_battle()), EncounterKind.normal);
      expect(encounterKindOf(_battle(elite: true)), EncounterKind.elite);
      // Sin la bandera de la batalla, por los enemigos.
      final eliteOnly = BattleState(
          party: [_hero('p')], enemies: [_foe('e', 'slime', elite: true)]);
      expect(encounterKindOf(eliteOnly), EncounterKind.elite);
      final bossOnly = BattleState(
          party: [_hero('p')], enemies: [_foe('b', 'sierpe', boss: true)]);
      expect(encounterKindOf(bossOnly), EncounterKind.boss);
      expect(encounterKindOf(_battle(boss: 'reyLimo', elite: true)),
          EncounterKind.boss);
    });

    test('jefe: set-piece por jefe y fase 2 del Devorador', () {
      final a = selectArena(battle: _battle(boss: 'bestiaMagma'), zone: 7);
      expect(a.theme, ArenaTheme.grieta);
      expect(a.kind, EncounterKind.boss);
      expect(a.bossType, 'bestiaMagma');
      expect(a.phase2, isFalse);
      final d1 = selectArena(
          battle: _battle(boss: 'devorador'), mapTheme: 'corazon');
      final d2 = selectArena(
          battle: _battle(boss: 'devorador', bossPhase: 2),
          mapTheme: 'corazon');
      expect(d2.phase2, isTrue);
      expect(d1.cacheKey, isNot(d2.cacheKey));
      expect(ArenaPainter.lightOf(d2), kDevoradorPhase2Light);
      // Eco: la escenografía de su zona + tinte de eco.
      final eco = selectArena(
          battle: _battle(boss: 'centinela'), mapTheme: 'bosque', eco: true);
      expect(eco.theme, ArenaTheme.bosque);
      expect(eco.eco, isTrue);
      expect(eco.bossType, 'centinela');
      // Misma entrada, misma arena.
      expect(selectArena(battle: _battle(), mapTheme: 'ruinas'),
          selectArena(battle: _battle(), mapTheme: 'ruinas'));
    });
  });

  group('formación del escenario', () {
    final configs = <String, (BattleState, EncounterKind)>{
      for (var p = 1; p <= 4; p++)
        for (var f = 1; f <= 6; f++)
          'normal $p vs $f': (_battle(party: p, foes: f), EncounterKind.normal),
      for (var p = 1; p <= 4; p++)
        'élite $p vs 3': (_battle(party: p, elite: true), EncounterKind.elite),
      for (var p = 1; p <= 4; p++) ...{
        'Sierpe + 2 cristales, $p': (
          _battle(party: p, foes: 0, boss: 'sierpe',
              adds: ['cristalHielo', 'cristalHielo']),
          EncounterKind.boss
        ),
        'Espectro + 2 siervos, $p': (
          _battle(party: p, foes: 0, boss: 'espectroCoronado',
              adds: ['siervoEspectral', 'siervoEspectral']),
          EncounterKind.boss
        ),
        'Devorador fase 2, $p': (
          _battle(party: p, foes: 0, boss: 'devorador', bossPhase: 2),
          EncounterKind.boss
        ),
      },
    };
    for (final c in configs.entries) {
      test('${c.key}: sin superposición, cada bando en su lado y adentro', () {
        final (s, kind) = c.value;
        final arena = BattleArena.stage(kind: kind);
        final l = BattleLayout.compute(s, arena, enemySize: _size);
        const stage =
            Rect.fromLTWH(0, 0, ArenaStage.width, ArenaStage.height);
        final ids = l.boxes.keys.toList();
        expect(ids, hasLength(s.party.length + s.enemies.length));
        for (var i = 0; i < ids.length; i++) {
          final a = l.boxOf(ids[i]);
          expect(stage.contains(a.topLeft) && stage.contains(a.bottomRight),
              isTrue,
              reason: '${ids[i]} $a');
          for (var j = i + 1; j < ids.length; j++) {
            expect(a.overlaps(l.boxOf(ids[j])), isFalse,
                reason: '${ids[i]} $a / ${ids[j]} ${l.boxOf(ids[j])}');
          }
        }
        final partyLeft = s.party
            .map((p) => l.boxOf(p.id).left)
            .reduce((a, b) => a < b ? a : b);
        final foesRight = s.enemies
            .map((e) => l.boxOf(e.id).right)
            .reduce((a, b) => a > b ? a : b);
        expect(partyLeft - foesRight, greaterThanOrEqualTo(60));
        // La pelea queda centrada en el escenario.
        expect((l.fightBox.center.dx - ArenaStage.centerX).abs(),
            lessThanOrEqualTo(1));
        // El grupo mira a los enemigos (lado fijo).
        expect(l.side, 1);
      });
    }

    for (final size in const [
      Size(1280, 418),
      Size(1280, 300), // barra de batalla más alta
      Size(1920, 780),
      Size(960, 400),
      Size(1280, 220),
    ]) {
      for (final kind in EncounterKind.values) {
        test('encuadre $kind en $size: todo a la vista, zoom entero', () {
          final s = kind == EncounterKind.boss
              ? _battle(foes: 2, boss: 'devorador', bossPhase: 2)
              : _battle(foes: 4, elite: kind == EncounterKind.elite);
          final arena = BattleArena.stage(kind: kind);
          final g = SceneGeometry.fit(size);
          final l = BattleLayout.compute(s, arena,
              vw: g.virtualWidth, enemySize: _size);
          final view = l.frame(g, arena);
          expect(view.zoom, view.zoom.roundToDouble());
          final vp = SceneViewport(g.worldRect, view);
          for (final id in l.boxes.keys) {
            final r = vp.rectToScreen(l.boxOf(id));
            expect(g.worldRect.inflate(0.5).contains(r.topLeft), isTrue,
                reason: '$id $r fuera de ${g.worldRect}');
            expect(g.worldRect.inflate(0.5).contains(r.bottomRight), isTrue,
                reason: '$id $r fuera de ${g.worldRect}');
          }
          final vis = vp.visible;
          if (vis.width <= ArenaStage.width) {
            expect(vis.left, greaterThanOrEqualTo(-1));
            expect(vis.right, lessThanOrEqualTo(ArenaStage.width + 1));
          }
        });
      }
    }

    test('más aire cuanto más importante el encuentro', () {
      final s = _battle(foes: 2);
      final g = SceneGeometry.fit(const Size(1920, 780));
      double zoom(EncounterKind k) {
        final a = BattleArena.stage(kind: k);
        return BattleLayout.compute(s, a, vw: g.virtualWidth, enemySize: _size)
            .frame(g, a)
            .zoom;
      }

      expect(zoom(EncounterKind.normal),
          greaterThanOrEqualTo(zoom(EncounterKind.elite)));
      expect(zoom(EncounterKind.elite),
          greaterThanOrEqualTo(zoom(EncounterKind.boss)));
      expect(zoom(EncounterKind.normal), greaterThan(zoom(EncounterKind.boss)));
    });
  });

  group('dibujo', () {
    testWidgets('todas las arenas (zona × tipo, Eco, Prueba, Devorador 2)',
        (tester) async {
      final painter = ArenaPainter();
      addTearDown(painter.dispose);
      final specs = [
        for (final t in ArenaTheme.values)
          for (final k in EncounterKind.values)
            ArenaSpec(
                theme: t,
                kind: k,
                bossType: k == EncounterKind.boss ? 'reyLimo' : null),
        for (final b in kBossArenaLight.keys)
          ArenaSpec(
              theme: ArenaTheme.corazon, kind: EncounterKind.boss, bossType: b),
        const ArenaSpec(
            theme: ArenaTheme.corazon,
            kind: EncounterKind.boss,
            bossType: 'devorador',
            phase2: true),
        const ArenaSpec(
            theme: ArenaTheme.bosque, kind: EncounterKind.elite, eco: true),
      ];
      for (final spec in specs) {
        final r = ui.PictureRecorder();
        final c = Canvas(r);
        painter.paint(c, const Rect.fromLTWH(-100, 100, 1200, 400), 1234, spec,
            density: 0.3);
        r.endRecording().dispose();
      }
      // La capa estática se cachea (pocas a la vez).
      expect(painter.cachedLayers, lessThanOrEqualTo(3));
      final a = painter.layer(specs.first);
      expect(identical(painter.layer(specs.first), a), isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('las mecánicas de jefe se siguen dibujando sobre la arena',
        (tester) async {
      Future<List<int>> render(BattleState s, {bool sync = false}) async {
        final scene = BattleSceneController();
        addTearDown(scene.dispose);
        final arena = BattleArena.stage(
          kind: EncounterKind.boss,
          // Arena de prueba lisa: negro puro.
          paintWorld: (c, v, t) => c.drawRect(
              v, Paint()..color = const Color(0xFF000000)),
        );
        const size = Size(1280, 418);
        final g = SceneGeometry.fit(size);
        final l = BattleLayout.compute(s, arena, vw: g.virtualWidth);
        scene.frame =
            SceneFrame(battle: s, geometry: g, layout: l, arena: arena);
        if (sync) {
          scene.sync(
              battleId: 1, eventSeq: 0, events: const [], state: s, layout: l);
        }
        scene.advance(sync ? 16 : 600);
        final r = ui.PictureRecorder();
        BattleScenePainter(scene).paint(Canvas(r), size);
        final img = r.endRecording().toImageSync(1280, 418);
        final data = await tester.runAsync(
            () => img.toByteData(format: ui.ImageByteFormat.rawRgba));
        img.dispose();
        final vp = SceneViewport(g.worldRect, scene.viewFor(scene.frame!));
        // Píxeles de muestra: una esquina del mundo y el pie del héroe p0.
        final corner = g.worldRect.topLeft + const Offset(6, 6);
        final foot = vp.toScreen(l.of('p0') + const Offset(13, 1));
        int at(Offset o) {
          final i = (o.dy.floor() * 1280 + o.dx.floor()) * 4;
          return data!.getUint32(i); // RGBA
        }

        return [at(corner), at(foot)];
      }

      int red(int rgba) => (rgba >> 24) & 0xFF;
      int blue(int rgba) => (rgba >> 8) & 0xFF;

      final plain = await render(_battle(boss: 'sierpe', foes: 0));
      expect(red(plain[0]) + blue(plain[0]), lessThan(30));
      // Campo Helado: el mundo (la arena) se tiñe de celeste.
      final frost = await render(_battle(
          boss: 'sierpe',
          foes: 0,
          partyEffects: const [
            TimedEffect(
                sourceId: 'escarcha',
                stat: BuffStat.speed,
                value: -0.5,
                turns: 2),
          ]));
      expect(blue(frost[0]), greaterThan(40));
      // Lava: charco naranja bajo el grupo.
      final lava = await render(_battle(boss: 'bestiaMagma', foes: 0, lava: 2));
      expect(red(lava[1]), greaterThan(150));
      expect(red(lava[1]), greaterThan(blue(lava[1]) + 60));
      // Transición de entrada: recién empezada, la escena está tapada.
      final enter = await render(_battle(), sync: true);
      expect(red(enter[0]) + blue(enter[0]), lessThan(60));
      expect(tester.takeException(), isNull);
    });
  });

  group('transición', () {
    test('los bloques se van de a poco y terminan en ArenaWipe.ms', () {
      const cols = 40, rows = 20;
      int covered(double p) {
        var n = 0;
        for (var r = 0; r < rows; r++) {
          for (var c = 0; c < cols; c++) {
            if (ArenaWipe.covered(p, c, r, cols)) n++;
          }
        }
        return n;
      }

      expect(covered(0), cols * rows);
      expect(covered(1), 0);
      final half = covered(0.5);
      expect(half, inExclusiveRange(cols * rows * 0.2, cols * rows * 0.8));
      expect(covered(0.25), greaterThan(half));
      expect(ArenaWipe.ms, inInclusiveRange(300, 500));
    });

    testWidgets('vuelta al mapa: tapa al salir de la batalla y se va',
        (tester) async {
      Widget wipe(bool b) => Directionality(
          textDirection: TextDirection.ltr,
          child: BattleExitWipe(inBattle: b));
      await tester.pumpWidget(wipe(true));
      expect(find.byType(CustomPaint), findsNothing);
      await tester.pumpWidget(wipe(false));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
          find.descendant(
              of: find.byType(BattleExitWipe),
              matching: find.byType(CustomPaint)),
          findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
      expect(
          find.descendant(
              of: find.byType(BattleExitWipe),
              matching: find.byType(CustomPaint)),
          findsNothing);
    });
  });
}
