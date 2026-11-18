import '../models/abyss.dart';
import '../models/elements.dart';
import '../models/item.dart';
import '../models/status.dart';

export '../models/abyss.dart';

// Jefes del Abismo v0.8 (docs/specs/abyss_bosses.md § 2). Los números
// generales (costo, furia, curas que dañan, chance del exclusivo) los
// edita el admin de balance (`BalanceKind.abyssBoss`); los del drop de
// Fragmentos, `BalanceKind.fragmentDrop`.

const _fuego = GameElement.fuego;
const _hielo = GameElement.hielo;
const _veneno = GameElement.veneno;
const _agua = GameElement.agua;
const _electro = GameElement.electro;

const _attack = AbyssMoveDef(AbyssMoveKind.attack);
const _summon = AbyssMoveDef(AbyssMoveKind.summon);
const _timeWarp =
    AbyssMoveDef(AbyssMoveKind.timeWarp, value: 0.5, soloValue: 0.3);

const _diluvio = AbyssMoveDef(AbyssMoveKind.strike,
    name: 'Diluvio',
    power: 0.6,
    element: _agua,
    status: StatusApplication(StatusKind.wet, 1));
const _descarga = AbyssMoveDef(AbyssMoveKind.strike,
    name: 'Descarga',
    power: 0.9,
    element: _electro,
    status: StatusApplication(StatusKind.charged, 1));
const _lamento = AbyssMoveDef(AbyssMoveKind.strike,
    name: 'Lamento',
    power: 0.8,
    element: _hielo,
    status: StatusApplication(StatusKind.freeze, 1));
const _colapso = AbyssMoveDef(AbyssMoveKind.strike,
    name: 'Colapso Temporal', power: 0.7, delay: 0.4);
const _era = AbyssMoveDef(AbyssMoveKind.strike, name: 'Era', power: 0.9);
const _devour =
    AbyssMoveDef(AbyssMoveKind.devour, value: 0.05, soloValue: 0.05, cap: 0.5);

/// Los 5 por número (1..4 los jefes, 5 el secreto).
const Map<int, AbyssBossDef> kAbyssBosses = {
  1: AbyssBossDef(
    number: 1,
    enemyId: 'golemAbismo',
    name: 'Gólem Reloj del Abismo',
    level: 85,
    arenaZone: 3,
    fragment: CraftMaterial.fragReloj,
    matchBoss: 3,
    legendaryIds: ['manecillaAbismo'],
    phases: [
      AbyssPhaseDef(name: 'Engranajes', gate: 1, moves: [
        _attack,
        _attack,
        _timeWarp,
        _attack,
        AbyssMoveDef(AbyssMoveKind.rewind, value: 1.0, soloValue: 0.5),
      ]),
      AbyssPhaseDef(
          name: 'Sobrecarga',
          gate: 0.6,
          attackMult: 1.15,
          aspects: [_electro],
          moves: [
            _diluvio,
            _attack,
            _descarga,
            _timeWarp,
            AbyssMoveDef(AbyssMoveKind.rewind, value: 1.0, soloValue: 0.5),
          ]),
      AbyssPhaseDef(
          name: 'Cuenta Final',
          gate: 0.25,
          attackMult: 1.3,
          aspects: [_electro],
          moves: [
            _descarga,
            _timeWarp,
            AbyssMoveDef(AbyssMoveKind.rewind, value: 1.0, soloValue: 0.5),
            _attack,
          ]),
    ],
  ),
  2: AbyssBossDef(
    number: 2,
    enemyId: 'hechiceraAbismo',
    name: 'Hechicera del Eco del Abismo',
    level: 86,
    arenaZone: 6,
    fragment: CraftMaterial.fragEco,
    matchBoss: 6,
    legendaryIds: ['espejoSinFondo'],
    phases: [
      AbyssPhaseDef(name: 'Voces', gate: 1, summon: true, moves: [
        _attack,
        AbyssMoveDef(AbyssMoveKind.mirror, power: 0.8),
        _attack,
        AbyssMoveDef(AbyssMoveKind.seal,
            value: 0.75,
            soloValue: 0.6,
            turns: 3,
            reaction: ReactionKind.electrocucion),
      ]),
      AbyssPhaseDef(
          name: 'Coro Roto',
          gate: 0.55,
          attackMult: 1.15,
          summon: true,
          moves: [
            AbyssMoveDef(AbyssMoveKind.mirror, power: 0.8),
            AbyssMoveDef(AbyssMoveKind.seal,
                value: 0.75,
                soloValue: 0.6,
                turns: 3,
                reaction: ReactionKind.derretir),
            AbyssMoveDef(AbyssMoveKind.strike,
                name: 'Nova',
                power: 0.8,
                element: _hielo,
                status: StatusApplication(StatusKind.freeze, 2)),
            _summon,
          ]),
    ],
  ),
  3: AbyssBossDef(
    number: 3,
    enemyId: 'espectroAbismo',
    name: 'Espectro Coronado del Abismo',
    level: 88,
    arenaZone: 8,
    fragment: CraftMaterial.fragCorona,
    matchBoss: 8,
    healHurts: 0.6,
    legendaryIds: ['coronaInvertida'],
    phases: [
      AbyssPhaseDef(
          name: 'Séquito',
          gate: 1,
          summon: true,
          statusImmuneWhileAdds: true,
          moves: [_attack, _lamento, _attack, _summon]),
      AbyssPhaseDef(
          name: 'Corona Inmune',
          gate: 0.6,
          attackMult: 1.1,
          summon: true,
          immuneWhileAdds: true,
          statusImmuneWhileAdds: true,
          moves: [
            AbyssMoveDef(AbyssMoveKind.strike,
                name: 'Llanto',
                power: 0.7,
                element: _agua,
                status: StatusApplication(StatusKind.wet, 1)),
            _attack,
            _summon,
            _attack,
          ]),
      AbyssPhaseDef(
          name: 'Último Lamento',
          gate: 0.25,
          attackMult: 1.2,
          statusImmuneWhileAdds: true,
          moves: [
            AbyssMoveDef(AbyssMoveKind.strike,
                name: 'Lamento',
                power: 1.0,
                element: _hielo,
                status: StatusApplication(StatusKind.freeze, 1)),
            _attack,
            _attack,
            _summon,
          ]),
    ],
  ),
  4: AbyssBossDef(
    number: 4,
    enemyId: 'devoradorAbismo',
    name: 'Devorador de Eras del Abismo',
    level: 90,
    arenaZone: 10,
    fragment: CraftMaterial.fragEras,
    matchBoss: 10,
    legendaryIds: ['fauceEras'],
    phases: [
      AbyssPhaseDef(
          name: 'Eras',
          gate: 1,
          moves: [_attack, _attack, _devour, _colapso]),
      AbyssPhaseDef(
          name: 'Hambre',
          gate: 0.66,
          attackMult: 1.15,
          moves: [
            _devour,
            AbyssMoveDef(AbyssMoveKind.strike,
                name: 'Colapso Temporal', power: 0.8, delay: 0.4),
            _attack,
            _attack,
          ]),
      AbyssPhaseDef(
          name: 'Ciclo de las Eras',
          gate: 0.33,
          attackMult: 1.3,
          aspects: [_fuego, _agua, _electro, _hielo],
          moves: [_era, _devour, _attack, _era]),
    ],
  ),
  5: AbyssBossDef(
    number: 5,
    enemyId: 'ecoPrimordial',
    name: 'Eco Primordial',
    level: 90,
    arenaZone: 0,
    secret: true,
    enrageTurns: 45,
    healHurts: 0.4,
    legendaryChance: 0.20,
    essence: 3,
    essenceExtra: 0,
    atlasPoints: 2,
    legendaryIds: ['prismaPrimordial', 'filoPrimordial'],
    phases: [
      AbyssPhaseDef(
          name: 'Origen',
          gate: 1,
          aspects: [_fuego, _agua, _electro, _hielo, _veneno],
          moves: [
            AbyssMoveDef(AbyssMoveKind.strike, name: 'Era', power: 0.8),
            AbyssMoveDef(AbyssMoveKind.seal,
                value: 0.75,
                soloValue: 0.6,
                turns: 3,
                reaction: ReactionKind.explosionToxica),
            _attack,
            _timeWarp,
          ]),
      AbyssPhaseDef(
          name: 'Reflejo',
          gate: 0.66,
          attackMult: 1.15,
          summon: true,
          aspects: [_fuego, _agua, _electro, _hielo, _veneno],
          moves: [
            AbyssMoveDef(AbyssMoveKind.mirror, power: 0.8),
            _devour,
            _era,
            AbyssMoveDef(AbyssMoveKind.rewind, value: 0.6, soloValue: 0.4),
          ]),
      AbyssPhaseDef(
          name: 'Primordial',
          gate: 0.33,
          attackMult: 1.25,
          immuneWhileAdds: true,
          aspects: [_fuego, _agua, _electro, _hielo, _veneno],
          moves: [
            AbyssMoveDef(AbyssMoveKind.strike, name: 'Era', power: 1.0),
            _summon,
            _devour,
            AbyssMoveDef(AbyssMoveKind.seal,
                value: 0.75,
                soloValue: 0.6,
                turns: 3,
                reaction: ReactionKind.electrocucion),
            _timeWarp,
          ]),
    ],
  ),
};

/// El Jefe del Abismo de un tipo de enemigo (o `null`).
AbyssBossDef? abyssBossOf(String? enemyId,
    [Map<int, AbyssBossDef> bosses = kAbyssBosses]) {
  if (enemyId == null) return null;
  for (final d in bosses.values) {
    if (d.enemyId == enemyId) return d;
  }
  return null;
}

/// Números del drop de Fragmentos (§ 1.1).
const kFragmentDrops = {'fragmentos': FragmentDropDef()};

/// Los 4 Fragmentos en orden de jefe.
const kFragments = [
  CraftMaterial.fragReloj,
  CraftMaterial.fragEco,
  CraftMaterial.fragCorona,
  CraftMaterial.fragEras,
];
