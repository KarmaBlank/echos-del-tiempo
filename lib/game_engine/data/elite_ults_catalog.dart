import '../models/enemy_def.dart';
import '../models/passive_mechanic.dart' show BuffStat;
import '../models/skill.dart' show PartyBuff;
import '../models/status.dart';

// ULT de élite (docs/specs/ultimates_v2.md § 4.3): una por cada tipo
// común que puede salir élite (`EnemyDef.eliteUltId`). Más chicas que la
// Furia Élite (poder 1.2-2.0) y cada una con su firma. Las invocaciones
// no salen élite y no tienen.

const _burn = StatusKind.burn;
const _poi = StatusKind.poison;
const _frz = StatusKind.freeze;
const _stun = StatusKind.stun;
const _wet = StatusKind.wet;
const _chg = StatusKind.charged;

/// ULT de élite → ULT de jefe cuyo guion de código y sonido toma
/// prestados (con otro tono). La animación propia vive en datos
/// (`assets/fx/enemy_ult/<id>.fx.yaml`).
const Map<String, String> kEliteUltLooks = {
  'eult_e_slime': 'eult_diluvio',
  'eult_e_bat': 'eult_coro',
  'eult_e_golem': 'eult_juicio',
  'eult_e_ghost': 'eult_lamento',
  'eult_e_arana': 'eult_nido',
  'eult_e_lobo': 'eult_furia',
  'eult_e_murcielagoHielo': 'eult_aliento',
  'eult_e_elementalEscarcha': 'eult_aliento',
  'eult_e_esqueleto': 'eult_furia',
  'eult_e_caballeroCaido': 'eult_juicio',
  'eult_e_ecoSombra': 'eult_coro',
  'eult_e_guardianReloj': 'eult_engranaje',
  'eult_e_salamandra': 'eult_erupcion',
  'eult_e_golemMagma': 'eult_erupcion',
  'eult_e_necrofago': 'eult_furia',
  'eult_e_almaErrante': 'eult_lamento',
  'eult_e_vigilanteVacio': 'eult_colapsoVacio',
  'eult_e_ojoAbismo': 'eult_colapsoVacio',
  'eult_e_heraldoEras': 'eult_finEras',
  'eult_e_fragmentoTiempo': 'eult_engranaje',
};

/// Las 20 ULT de élite por id.
const Map<String, EnemyUltDef> kEliteUlts = {
  'eult_e_slime': EnemyUltDef(
      id: 'eult_e_slime',
      name: 'Masa Pegajosa',
      power: 1.4,
      allTargets: true,
      debuffs: [PartyBuff(BuffStat.speed, -0.20, 2)]),
  'eult_e_bat': EnemyUltDef(
      id: 'eult_e_bat',
      name: 'Chillido Antiguo',
      power: 1.4,
      allTargets: true,
      delayAll: 0.3),
  'eult_e_golem': EnemyUltDef(
      id: 'eult_e_golem',
      name: 'Puño de Piedra',
      power: 2.0,
      status: StatusApplication(_stun, 1)),
  'eult_e_ghost': EnemyUltDef(
      id: 'eult_e_ghost',
      name: 'Toque Frío',
      power: 1.6,
      status: StatusApplication(_frz, 2)),
  'eult_e_arana': EnemyUltDef(
      id: 'eult_e_arana',
      name: 'Red Envenenada',
      power: 1.4,
      allTargets: true,
      status: StatusApplication(_poi, 2)),
  'eult_e_lobo': EnemyUltDef(
      id: 'eult_e_lobo', name: 'Manada Fantasma', power: 0.7, hits: 3),
  'eult_e_murcielagoHielo': EnemyUltDef(
      id: 'eult_e_murcielagoHielo',
      name: 'Ventisca Alada',
      power: 1.4,
      allTargets: true,
      status: StatusApplication(_frz, 1)),
  'eult_e_elementalEscarcha': EnemyUltDef(
      id: 'eult_e_elementalEscarcha',
      name: 'Prisión de Hielo',
      power: 1.8,
      status: StatusApplication(_frz, 3)),
  'eult_e_esqueleto': EnemyUltDef(
      id: 'eult_e_esqueleto',
      name: 'Carga de Huesos',
      power: 2.0,
      guaranteedCrit: true),
  'eult_e_caballeroCaido': EnemyUltDef(
      id: 'eult_e_caballeroCaido',
      name: 'Último Juramento',
      power: 1.8,
      selfShield: 0.20,
      selfShieldTurns: 2),
  'eult_e_ecoSombra': EnemyUltDef(
      id: 'eult_e_ecoSombra',
      name: 'Paso Doble',
      power: 1.0,
      hits: 2,
      delayTarget: 0.3),
  'eult_e_guardianReloj': EnemyUltDef(
      id: 'eult_e_guardianReloj',
      name: 'Campanada',
      power: 1.2,
      allTargets: true,
      delayAll: 0.5),
  'eult_e_salamandra': EnemyUltDef(
      id: 'eult_e_salamandra',
      name: 'Escupitajo Ígneo',
      power: 1.5,
      allTargets: true,
      status: StatusApplication(_burn, 2)),
  'eult_e_golemMagma': EnemyUltDef(
      id: 'eult_e_golemMagma',
      name: 'Corazón Fundido',
      power: 1.6,
      allTargets: true,
      status: StatusApplication(_burn, 1)),
  'eult_e_necrofago': EnemyUltDef(
      id: 'eult_e_necrofago', name: 'Festín', power: 1.8, drainHeal: 0.5),
  'eult_e_almaErrante': EnemyUltDef(
      id: 'eult_e_almaErrante',
      name: 'Llanto Errante',
      power: 1.3,
      allTargets: true,
      status: StatusApplication(_frz, 1)),
  'eult_e_vigilanteVacio': EnemyUltDef(
      id: 'eult_e_vigilanteVacio',
      name: 'Ojo que Inunda',
      power: 1.4,
      allTargets: true,
      status: StatusApplication(_wet, 2)),
  'eult_e_ojoAbismo': EnemyUltDef(
      id: 'eult_e_ojoAbismo',
      name: 'Mirada Eléctrica',
      power: 1.8,
      status: StatusApplication(_chg, 1),
      extraStatuses: [StatusApplication(_stun, 1, chance: 0.3)]),
  'eult_e_heraldoEras': EnemyUltDef(
      id: 'eult_e_heraldoEras',
      name: 'Anuncio de las Eras',
      power: 1.5,
      allTargets: true,
      cycleStatus: true),
  'eult_e_fragmentoTiempo': EnemyUltDef(
      id: 'eult_e_fragmentoTiempo',
      name: 'Esquirla Desfasada',
      power: 1.6,
      delayTarget: 0.6),
};
