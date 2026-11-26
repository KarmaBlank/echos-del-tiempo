// Phased zone boss UI (docs/specs/bosses.md § v0.50 § 3): the boss bar
// over the real battle view and the zone unlock. With PREVIEW=1 writes
// docs/preview/bosses/*.png with the real sprites.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/app/design/design.dart';
import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/features/combat/presentation/battle_screen.dart';
import 'package:echos_del_tiempo/features/combat/presentation/combat_strings.dart';
import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
import 'package:echos_del_tiempo/features/missions/domain/mission_text.dart';
import 'package:echos_del_tiempo/features/missions/presentation/results_panel.dart';
import 'package:echos_del_tiempo/game_engine/data/tuning_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/rules/session_engine.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../../real_fonts.dart';

final _preview = Platform.environment['PREVIEW'] == '1';

PlayerProfile _strong(String name) {
  final p = zoneProgression
      .normalize(PlayerProfile(name: name, classId: 'guerrero', level: 50));
  final half = p.points ~/ 2;
  return zoneProgression
      .allocate(p, {Attribute.vit: half, Attribute.fue: p.points - half})!
      .copyWith(unlockedZone: 1);
}

/// A two-player room in front of Rey Limo, the battle just started.
(SessionEngine, GameSession) _bossFight() {
  final e = sessionEngine(zones: true);
  var s = inField(e, 'm1', profiles: [_strong('Ana'), _strong('Beto')]);
  final boss = s.mission!.enemies.singleWhere((x) => x.boss);
  s = e.tick(s, 0.05).state;
  final map = e.mapFor(s);
  s = act(e, s, 'p0', MoveAction(map.floor(0)!.stairsDown!.x,
      map.floor(0)!.stairsDown!.y, epoch: s.players['p0']!.epoch));
  s = e.tick(s, 0.05).state;
  s = wait(e, s, s.graceLeft + 0.1);
  s = moveTo(e, s, 'p0', boss.x, boss.y);
  s = e.tick(s, 0.05).state;
  expect(s.mode, SessionMode.battle);
  return (e, s);
}

/// [b] with the boss in [phase] at [frac] life, [actions] taken.
BattleState _at(BattleState b, int phase, double frac, int actions) {
  final c = b.copy();
  final boss = c.enemies.first
    ..phase = phase
    ..actions = actions;
  boss.hp = (boss.maxHp * frac).round();
  if (phase >= 2) {
    for (final e in c.enemies.skip(1)) {
      e.hp = e.maxHp;
    }
  }
  return c;
}

Future<void> _shot(WidgetTester tester, String name) async {
  if (!_preview) return;
  await tester.runAsync(() async {
    final rb = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('shot')));
    final img = await rb.toImage();
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    Directory('docs/preview/bosses').createSync(recursive: true);
    File('docs/preview/bosses/$name.png')
        .writeAsBytesSync(png!.buffer.asUint8List());
  });
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: RetroTheme.build(),
      home: Scaffold(
          body: RepaintBoundary(
              key: const ValueKey('shot'),
              child: ColoredBox(color: DsColors.background, child: child))),
    ),
  ));
  // Past the battle intro (banner and dither transition).
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('boss bar: phases, telegraph, ECO; then the zone unlock',
      (tester) async {
    await loadRealFonts(tester);
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final sprites = _preview
        ? await tester.runAsync(() async {
            final cat = await SpriteCatalog.load();
            await cat.loadProcedural();
            return GameSprites.load(cat);
          })
        : null;
    final (e, s) = _bossFight();
    final b = s.battle!.state;
    final t = tuning(TuningId.bosses);
    final shots = [
      ('phase1', _at(b, 1, 0.92, 2), false, 'FASE 1/3', 'PRÓX: Ola Ácida'),
      ('phase2', _at(b, 2, t.d('p2Gate') - 0.08, 1), false, 'FASE 2/3',
          'PRÓX: Ola Ácida'),
      ('phase3', _at(b, 3, t.d('p3Gate') - 0.05, 0), false, 'FASE 3/3',
          'PRÓX: Marea Real'),
      ('phase3_eco', _at(b, 3, 0.2, 0), true, 'FASE 3/3', 'ECO'),
    ];
    for (final (name, state, eco, phase, extra) in shots) {
      await _pump(
          tester,
          BattleView(
            battle: state,
            battleId: 1,
            onCommand: (_) => false,
            sprites: sprites,
            localId: 'p0',
            bossEco: eco,
          ));
      expect(find.byKey(const ValueKey('zone-boss-bar')), findsOneWidget);
      final bar = tester.widget<DsBossHealthBar>(
          find.byKey(const ValueKey('zone-boss-bar')));
      expect(bar.phaseText, startsWith(phase), reason: name);
      expect('${bar.nextText} ${bar.tag}', contains(extra), reason: name);
      await _shot(tester, name);
    }

    // ---- victory: zone 2 opens ----
    final won = runBattle(e, s, until: (x) => x.result != null);
    var r = won;
    for (var i = 0; i < 5 && r.mode == SessionMode.levelUp; i++) {
      for (final p in r.playerList) {
        if (p.profile.points > 0) {
          r = act(e, r, p.id,
              AllocateStatsAction({Attribute.vit: p.profile.points}));
        }
      }
      r = runBattle(e, r, until: (x) => x.result != null);
    }
    final res = r.result!;
    expect(res.unlocked['p0'], 2);
    await _pump(
        tester,
        Builder(builder: (context) {
          final st = combatStrings(context);
          final z = e.catalog.zone(2)!;
          return ResultsPanel(
            result: res,
            localId: 'p0',
            playerName: (id) => r.players[id]?.name ?? '?',
            weaponName: (id) => e.catalog.weapons[id]?.name ?? id,
            onBack: () {},
            unlocked: zoneUnlockedText(st, 2, zoneNameText(st, z)),
          );
        }));
    await _shot(tester, 'unlock');
    expect(r.players['p0']!.profile.life.ore('boss_gelcrown'), 1);
  });
}
