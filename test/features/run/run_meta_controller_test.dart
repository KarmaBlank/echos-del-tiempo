import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/models/game_mode.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/game_engine/models/run_save.dart';
import 'package:echos_del_tiempo/game_engine/models/travesia_meta.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/mulberry32.dart';
import 'package:echos_del_tiempo/game_engine/rules/run_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/session_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../game_engine/session_test_helpers.dart';

/// Travesía v0.2.0 en el controlador: guarda la run, la retoma, cobra el
/// progreso al terminar y manda el loadout (roguelike.md § 12.1).
void main() {
  SessionEngine engine() => SessionEngine(
        battles: BattleEngine(stats: statsCalc, random: () => 0.5),
        progression: zoneProgression,
        random: mulberry32(3),
        seeds: () => 777,
        achievementsEnabled: false,
        gameMode: GameModeKind.travesia,
      );

  SessionController controller(
          InMemoryRunSaveStore saves, InMemoryTravesiaMetaStore meta) =>
      SessionController(
        engine: engine(),
        store: InMemoryProfileStore(zoneProgression
            .normalize(PlayerProfile(name: 'Ana', classId: 'guerrero'))),
        clock: const SessionClock(autoStart: false),
        runSaveStore: saves,
        metaStore: meta,
      );

  test('guarda al entrar al nodo, retoma y cobra al terminar', () async {
    final saves = InMemoryRunSaveStore();
    final meta = InMemoryTravesiaMetaStore(const TravesiaMeta(coins: 50));
    final c = controller(saves, meta);
    addTearDown(c.dispose);
    await c.start();
    expect(c.hasRunSave, isFalse);
    // Legado y loadout, antes de empezar.
    expect(c.buyMetaNode('bolsa'), isTrue);
    expect(c.meta.coins, 40);
    expect(c.setLoadout([c.loadoutPool.first]), isTrue);
    expect(c.startRun(), isTrue);
    expect(c.session!.run!.loadout[c.localId], [c.loadoutPool.first]);
    expect(c.voteRunNode(RunRules.reachable(c.session!.run!).first), isTrue);
    c.advance(0.05);
    expect(c.session!.mode, SessionMode.battle);
    await Future<void>.delayed(Duration.zero);
    expect(saves.value, isNotNull);

    // Otra sesión: ofrece continuar y retoma la pelea.
    final c2 = controller(saves, meta);
    addTearDown(c2.dispose);
    await c2.start();
    expect(c2.hasRunSave, isTrue);
    expect(c2.continueRun(), isTrue);
    expect(c2.session!.mode, SessionMode.battle);

    // Cae el grupo: se borra el guardado y se cobran los Ecos.
    for (final p in c2.session!.battle!.state.party) {
      p.hp = 0;
    }
    c2.session!.battle!.state.currentId = null;
    for (var i = 0; i < 200 && c2.session!.run!.phase != RunPhase.over; i++) {
      c2.advance(0.05);
    }
    expect(c2.session!.run!.phase, RunPhase.over);
    await Future<void>.delayed(Duration.zero);
    expect(saves.value, isNull);
    expect(meta.value.coins, greaterThan(40));
    expect(meta.value.runs, 1);
  });
}
