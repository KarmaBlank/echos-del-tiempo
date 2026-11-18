import 'dart:ui' as ui;

import 'package:echos_del_tiempo/core/audio/reaction_sfx.dart';
import 'package:echos_del_tiempo/core/audio/sfx_catalog.dart';
import 'package:echos_del_tiempo/core/audio/wav_synth.dart';
import 'package:echos_del_tiempo/features/combat/domain/element_text.dart';
import 'package:echos_del_tiempo/features/combat/presentation/battle_hud.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/battle_fx.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/reaction_fx.dart';
import 'package:echos_del_tiempo/features/combat/presentation/status_icons.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_sfx.dart';
import 'package:echos_del_tiempo/core/audio/sfx_service.dart';
import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/elements_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/game_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_event.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/status.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Presentación de las reacciones (docs/specs/elemental_reactions.md § 3;
/// battle_presentation.md § "Reacciones elementales"): plan, dibujo,
/// sonido, íconos, chips y eventos del motor → efectos / sonidos.

Combatant _hero(String skill) => Combatant(
      id: 'p1',
      name: 'Ana',
      isPlayer: true,
      hp: 100,
      maxHp: 100,
      speed: 10,
      attack: 20,
      magic: 20,
      critChance: 0,
      mp: 50,
      maxMp: 50,
      skillIds: [skill],
      classId: 'maga',
      weaponType: 'baculo',
    );

Combatant _foe(String id, {Map<StatusKind, int>? st}) => Combatant(
      id: id,
      name: 'Limo $id',
      isPlayer: false,
      hp: 500,
      maxHp: 500,
      speed: 5,
      attack: 10,
      critChance: 0,
      enemyType: 'slime',
      statuses: st,
      nextTurn: 50,
    );

/// [skill] de la Maga sobre `e0`, con [foes] (sus estados).
BattleStep _use(String skill, List<Map<StatusKind, int>> foes) {
  final s = BattleState(party: [
    _hero(skill)
  ], enemies: [
    for (var i = 0; i < foes.length; i++) _foe('e$i', st: foes[i])
  ], currentId: 'p1');
  final e = BattleEngine(
      stats: StatsCalculator(
          classes: kClasses, treeRules: PassiveTreeRules(kPassiveTree)),
      catalog: GameCatalog.standard,
      random: () => 0.99,
      breakEnabled: false);
  return e.command(s, 'p1', SkillCommand(skill, targetId: 'e0'))!;
}

Offset _pos(String id) => switch (id) {
      'p1' => const Offset(300, 200),
      'e0' => const Offset(100, 200),
      'e1' => const Offset(80, 170),
      _ => const Offset(60, 230),
    };

void main() {
  const target = Offset(100, 200);

  group('plan', () {
    test('cada reacción: un cartel sobre el objetivo, ≤ 600 ms', () {
      for (final k in ReactionKind.values) {
        final fx = planReactionFx(k,
            target: target, at: 120, jumpTo: const Offset(40, 220));
        final b = fx.where((f) => f.part == ReactionPart.banner).toList();
        expect(b, hasLength(1), reason: k.name);
        expect(b.single.delayMs, 120);
        expect(b.single.durationMs, lessThanOrEqualTo(600));
        expect(b.single.x, target.dx);
        expect(b.single.y, lessThan(target.dy));
        expect(b.single.look.banner, reactionBanner(k));
        for (final f in fx) {
          expect(f.delayMs + f.durationMs, lessThanOrEqualTo(120 + 600),
              reason: k.name);
        }
      }
    });

    test('Explosión tóxica: anillo grande y uno por salpicado, escalonados',
        () {
      final fx = planReactionFx(ReactionKind.explosionToxica,
          target: target, splash: const [Offset(60, 180), Offset(40, 220)]);
      final rings = fx.where((f) => f.part == ReactionPart.ring).toList();
      expect(rings, hasLength(3));
      expect(rings.first.big, isTrue);
      expect(rings[1].delayMs, ReactionTiming.splashAt(0, 0));
      expect(rings[2].delayMs, greaterThan(rings[1].delayMs));
      expect(fx.where((f) => f.part == ReactionPart.zap), isEmpty);
    });

    test('Electrocución: rayos sobre el objetivo; Cortocircuito: al otro', () {
      final e = planReactionFx(ReactionKind.electrocucion, target: target);
      expect(e.where((f) => f.part == ReactionPart.zap), hasLength(2));
      final c = planReactionFx(ReactionKind.cortocircuito,
          target: target, jumpTo: const Offset(40, 220));
      final z = c.where((f) => f.part == ReactionPart.zap).single;
      expect((z.x, z.tx), (target.dx, 40.0));
      // Sin a quién saltar: solo el cartel.
      expect(planReactionFx(ReactionKind.cortocircuito, target: target),
          hasLength(1));
    });

    test('colores: de la reacción; franjas del estado consumido', () {
      final cols = {for (final k in ReactionKind.values) reactionLook(k).color};
      expect(cols.length, 4); // Electro: Electrocución y Cortocircuito
      expect(reactionLook(ReactionKind.electrocucion).accent,
          const Color(0xFF3FA9F5));
    });
  });

  group('dibujo', () {
    test('cartel: entra, se asienta y se apaga; quieto con REDUCIR', () {
      expect(ReactionFxPainter.bannerScale(0), greaterThan(1.4));
      expect(ReactionFxPainter.bannerScale(ReactionTiming.popMs + 1.0), 1);
      expect(ReactionFxPainter.bannerScale(0, still: true), 1);
      expect(ReactionFxPainter.bannerAlpha(100), 1);
      expect(ReactionFxPainter.bannerAlpha(590), lessThan(0.1));
      expect(ReactionFxPainter.bannerAlpha(600), 0);
    });

    test('rayo: titila cada 40 ms; fijo con REDUCIR; empieza y termina en '
        'sus puntos', () {
      final z = planReactionFx(ReactionKind.cortocircuito,
              target: target, jumpTo: const Offset(20, 200))
          .firstWhere((f) => f.part == ReactionPart.zap);
      final a = ReactionFxPainter.zapPoints(z, 0);
      expect(a, isNot(ReactionFxPainter.zapPoints(z, 45)));
      expect(ReactionFxPainter.zapPoints(z, 0, still: true),
          ReactionFxPainter.zapPoints(z, 200, still: true));
      expect(a.first, Offset(z.x, z.y));
      expect(a.last, Offset(z.tx, z.ty));
    });

    test('todo se dibuja con y sin movimiento, destellos y partículas', () {
      final r = ui.PictureRecorder();
      final c = ui.Canvas(r);
      for (final k in ReactionKind.values) {
        for (final o in const [
          ReactionFxOptions(),
          ReactionFxOptions(still: true, flash: 0.35, density: 0.3),
          ReactionFxOptions(flash: 0),
        ]) {
          for (final f in planReactionFx(k,
              target: target,
              splash: const [Offset(60, 180)],
              jumpTo: const Offset(60, 180))) {
            for (var a = -20.0; a < 700; a += 30) {
              ReactionFxPainter.paintWorld(c, f, a, o: o);
              if (f.part == ReactionPart.banner) {
                ReactionFxPainter.paintBanner(
                    c, f, const Offset(200, 100), a, 2,
                    o: o);
              }
            }
          }
        }
      }
      for (final id in kStatusIconRows.keys) {
        paintStatusIcon(c, id, 0, 0, 2);
      }
      r.endRecording().dispose();
      expect(ReactionFxPainter.bannerWidth(ReactionKind.cortocircuito, 1),
          greaterThan(0));
    });
  });

  group('eventos del motor → efectos', () {
    List<BattleFx> reactionFx(List<BattleFx> fx) =>
        [for (final f in fx) if (f.kind == FxKind.reaction) f];

    test('Electrocución: cartel después del golpe, sin número extra', () {
      final step = _use('chispazo', [
        {StatusKind.wet: 2}
      ]);
      expect(step.events.whereType<ReactionEvent>(), hasLength(1));
      final fx = mapBattleEvents(step.events, step.state, _pos);
      final r = reactionFx(fx);
      final banner =
          r.firstWhere((f) => f.reaction!.part == ReactionPart.banner);
      final hit = fx.firstWhere(
          (f) => f.kind == FxKind.num && f.x == _pos('e0').dx);
      expect(banner.delayMs, hit.delayMs + ReactionTiming.afterHitMs);
      expect(banner.reaction!.look.kind, ReactionKind.electrocucion);
      expect(r.where((f) => f.reaction!.part == ReactionPart.zap),
          hasLength(2));
      expect(banner.durationMs, ReactionTiming.bannerMs);
    });

    test('Explosión tóxica: número extra en el objetivo y en cada salpicado',
        () {
      final step = _use('bola', [
        {StatusKind.poison: 3},
        {},
        {},
      ]);
      final fx = mapBattleEvents(step.events, step.state, _pos);
      final rings = reactionFx(fx)
          .where((f) => f.reaction!.part == ReactionPart.ring)
          .toList();
      expect(rings, hasLength(3));
      final color = reactionLook(ReactionKind.explosionToxica).color;
      final extra = [
        for (final f in fx)
          if (f.kind == FxKind.num && f.color == color) f
      ];
      final r = step.events.whereType<ReactionEvent>().single;
      expect(extra.map((f) => f.text),
          ['${r.amount}', for (final v in r.splash.values) '$v']);
      final banner = reactionFx(fx)
          .firstWhere((f) => f.reaction!.part == ReactionPart.banner);
      expect(extra.first.delayMs, banner.delayMs);
      expect(extra[1].delayMs, ReactionTiming.splashAt(banner.delayMs, 0));
    });

    test('sonido: la reacción suena con el golpe, su daño extra no aparte',
        () {
      final step = _use('bola', [
        {StatusKind.poison: 3},
        {},
      ]);
      final sfx = SessionSfx(SfxService(), localId: 'p1');
      final cues = sfx.battleSounds(step.events);
      final r = cues.where((c) => c.id == ReactionKind.explosionToxica.sfxId);
      expect(r, hasLength(1));
      expect(r.single.delayMs, greaterThan(0));
    });
  });

  group('sonido', () {
    const synth = WavSynth();
    test('cada reacción tiene su sonido sfx.reaction.<kind>, distinto, '
        'corto y normalizado', () {
      final sigs = <String>{};
      for (final k in ReactionKind.values) {
        expect(k.sfxId, Sfx.reaction(k.name));
        final def = kSfxCatalog[k.sfxId];
        expect(def, isNotNull, reason: k.sfxId);
        expect(def!.peak, kReactionPeak);
        expect(def.peak!, lessThanOrEqualTo(SfxLevel.crit));
        expect(def.length, inInclusiveRange(0.2, 0.8), reason: k.sfxId);
        final s = synth.samplesOf(def);
        final peak = s.fold<double>(0, (m, x) => x.abs() > m ? x.abs() : m);
        expect(peak, closeTo(def.peak!, 1e-6), reason: k.sfxId);
        sigs.add(def.voices
            .map((v) => '${v.wave}:${v.frequency}:${v.delay}')
            .join(','));
      }
      expect(sigs, hasLength(ReactionKind.values.length));
    });

    test('aplicar Mojado / Cargado suena', () {
      for (final k in [StatusKind.wet, StatusKind.charged]) {
        final def = kSfxCatalog[Sfx.status(k.name)];
        expect(def, isNotNull, reason: k.name);
        expect(def!.peak, SfxLevel.status);
      }
    });
  });

  group('íconos y chips de estado', () {
    test('gota y rayo: 8×8, contorno y forma distinta', () {
      expect(kStatusIconRows.keys,
          {StatusKind.wet.iconId, StatusKind.charged.iconId});
      for (final rows in kStatusIconRows.values) {
        expect(rows, hasLength(kStatusIconCells));
        for (final r in rows) {
          expect(r.length, kStatusIconCells);
          expect(r, matches(RegExp(r'^[XCL.]+$')));
        }
      }
      expect(kStatusIconRows['status_wet'],
          isNot(kStatusIconRows['status_charged']));
      expect(statusIconOf(StatusKind.wet), 'status_wet');
      expect(statusIconOf(StatusKind.burn), isNull);
    });

    test('chips: Mojado / Cargado con ícono y turnos; Quebradizo y '
        'resistencia', () {
      final c = _foe('e0', st: {
        StatusKind.wet: 2,
        StatusKind.charged: 1,
        StatusKind.freeze: 5,
      })
        ..brittle = true
        ..freezeResist = 0;
      final chips = combatantChips(c);
      final wet = chips.firstWhere((x) => x.short == 'M2');
      expect(wet.icon, 'status_wet');
      expect(wet.tip, contains('2 turnos'));
      expect(chips.firstWhere((x) => x.short == 'E1').icon, 'status_charged');
      expect(chips.firstWhere((x) => x.long.startsWith('▼VEL')).long,
          '▼VEL −30%');
      expect(chips.map((x) => x.long), contains('Quebradizo'));
      c
        ..brittle = false
        ..statuses[StatusKind.freeze] = 0
        ..freezeResist = 2;
      expect(combatantChips(c).map((x) => x.long), contains('Resiste hielo 2'));
    });

    testWidgets('StatusChipView dibuja el ícono delante de la letra',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Row(children: [
            StatusChipView(StatusChip('M2', 'Mojado 2', Color(0xFF3FA9F5), 'x',
                icon: 'status_wet')),
            StatusChipView(StatusChip('Q3', 'Quemadura 3', Color(0xFFFF7B29),
                'x')),
          ]),
        ),
      ));
      expect(find.text('M2'), findsOneWidget);
      expect(find.byType(StatusIcon), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
