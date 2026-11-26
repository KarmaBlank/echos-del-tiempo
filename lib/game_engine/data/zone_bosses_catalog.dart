// Phased zone bosses (docs/specs/bosses.md § v0.50). They reuse the phase
// and move machinery of the Abyss bosses (`AbyssBossDef`): every number
// comes from `kTuning[TuningId.bosses]`, so the defs are built on demand
// and follow the Balance patch.

import '../models/abyss.dart';
import '../models/battle_state.dart';
import '../models/enemy_def.dart';
import 'enemies_catalog.dart';
import '../models/elements.dart';
import '../models/status.dart';
import 'tuning_catalog.dart';

/// Zone of each phased zone boss (enemy id → zone index).
const kZoneBossZones = <String, int>{'reyLimo': 1};

/// Boss material each zone boss drops (enemy id → smithing material).
const kBossMaterials = <String, String>{'reyLimo': 'boss_gelcrown'};

/// Mechanic of each phased zone boss (enemy id → `kBossMechanics` id).
/// Not on the enemy def: Travesía and the prototype missions keep the
/// plain boss. Mundo turns it on by starting the boss in phase 1
/// (`BossRules.applyBattle`).
const kZoneBossMechanics = <String, String>{'reyLimo': 'mareaReal'};

/// The phase def of [e] when it fights as a phased zone boss.
AbyssBossDef? zonePhasesOf(Combatant e) =>
    e.isPlayer || e.phase < 1 ? null : zoneBossOf(e.enemyType);

/// The boss mechanic of [e]: its own, or the phased zone one.
BossMechanicDef? combatMechanicOf(Combatant e, [EnemyDef? def]) {
  if (e.isPlayer) return null;
  return bossMechanicOf(def ?? kEnemies[e.enemyType]) ??
      (zonePhasesOf(e) == null
          ? null
          : kBossMechanics[kZoneBossMechanics[e.enemyType]]);
}

/// Turn count used when `enrageTurns` is 0 (no fury).
const _noEnrage = 1 << 30;

/// The phase definition of the zone boss [enemyId], or `null`.
AbyssBossDef? zoneBossOf(String? enemyId) => switch (enemyId) {
      'reyLimo' => _reyLimo(),
      _ => null,
    };

AbyssBossDef _reyLimo() {
  final t = tuning(TuningId.bosses);
  final wave = AbyssMoveDef(AbyssMoveKind.strike,
      name: 'Ola Ácida',
      power: t.d('wavePower'),
      element: GameElement.veneno,
      status: StatusApplication(StatusKind.poison, t.i('wavePoison')));
  final tide = AbyssMoveDef(AbyssMoveKind.strike,
      name: 'Marea Real',
      power: t.d('tidePower'),
      element: GameElement.agua,
      status: const StatusApplication(StatusKind.wet, 1),
      delay: t.d('tideDelay'));
  const attack = AbyssMoveDef(AbyssMoveKind.attack);
  const split = AbyssMoveDef(AbyssMoveKind.summon, name: 'División');
  final enrage = t.i('enrageTurns');
  return AbyssBossDef(
    number: 0,
    enemyId: 'reyLimo',
    name: 'Rey Limo',
    level: 5,
    arenaZone: 1,
    legendaryIds: const [],
    enrageTurns: enrage <= 0 ? _noEnrage : enrage,
    enragePower: t.d('enragePower'),
    phases: [
      AbyssPhaseDef(
          name: 'Corte de Gel', gate: 1, moves: [attack, attack, wave, attack]),
      AbyssPhaseDef(
          name: 'División',
          gate: t.d('p2Gate'),
          attackMult: t.d('p2Atk'),
          summon: true,
          moves: [attack, wave, attack, split]),
      AbyssPhaseDef(
          name: 'Marea Real',
          gate: t.d('p3Gate'),
          attackMult: t.d('p3Atk'),
          moves: [tide, attack, wave, attack]),
    ],
  );
}
