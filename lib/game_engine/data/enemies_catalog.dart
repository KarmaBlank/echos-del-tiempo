import '../models/enemy_def.dart';
import '../models/status.dart';

/// `EN` del prototipo, 1:1. El sprite, color y escala de cada enemigo
/// son arte y se resuelven por id en `assets/sprites/sprite_manifest.yaml`.
/// `breakMax` y `ultId`: docs/specs/break_and_enemy_ults.md.
const Map<String, EnemyDef> kEnemies = {
  'slime': EnemyDef(id: 'slime', name: 'Limo', hp: 30, attack: 7, speed: 7, xp: 6, credits: 5,
      inflicts: StatusApplication(StatusKind.poison, 1), breakMax: 25),
  'bat': EnemyDef(id: 'bat', name: 'Murciélago', hp: 22, attack: 9, speed: 13, xp: 7, credits: 6,
      pierce: true, breakMax: 20),
  'golem': EnemyDef(id: 'golem', name: 'Gólem', hp: 70, attack: 12, speed: 5, xp: 14, credits: 12,
      breakMax: 50),
  'ghost': EnemyDef(id: 'ghost', name: 'Espectro', hp: 55, attack: 15, speed: 11, xp: 16, credits: 14,
      pierce: true, inflicts: StatusApplication(StatusKind.freeze, 1), breakMax: 40),
  'reyLimo': EnemyDef(id: 'reyLimo', name: 'Rey Limo', hp: 230, attack: 13, speed: 8, xp: 60, credits: 80,
      boss: true, inflicts: StatusApplication(StatusKind.poison, 2), breakMax: 80, ultId: 'eult_diluvio',
      title: 'Soberano de la Pradera'),
  'golemReloj': EnemyDef(id: 'golemReloj', name: 'Gólem Reloj', hp: 430, attack: 18, speed: 7, xp: 120, credits: 150,
      boss: true, inflicts: StatusApplication(StatusKind.freeze, 2), breakMax: 150, ultId: 'eult_engranaje',
      title: 'Guardián de las Ruinas Cronales'),
  'devorador': EnemyDef(id: 'devorador', name: 'Devorador de Eras', hp: 820, attack: 23, speed: 10, xp: 250, credits: 300,
      boss: true, areaAttack: true, inflicts: StatusApplication(StatusKind.burn, 2), breakMax: 280, ultId: 'eult_finEras',
      title: 'El hambre al final del tiempo'),

  // ---- v0.2.0 (docs/specs/bosses.md § "v0.2"): stats al nivel nativo de
  // `kEnemyBaseLevel` (comunes: mínimo de su zona; jefes: máximo). ----

  // Zona 2 · Bosque Hondo (comunes nivel 6, jefe nivel 10).
  'arana': EnemyDef(id: 'arana', name: 'Araña', hp: 52, attack: 11, speed: 10, xp: 8, credits: 7,
      inflicts: StatusApplication(StatusKind.poison, 1), breakMax: 42, feminine: true),
  'lobo': EnemyDef(id: 'lobo', name: 'Lobo', hp: 50, attack: 12, speed: 14, xp: 8, credits: 7,
      pierce: true, breakMax: 40),
  'matriarca': EnemyDef(id: 'matriarca', name: 'Matriarca Araña', hp: 480, attack: 21, speed: 9, xp: 90, credits: 110,
      boss: true, inflicts: StatusApplication(StatusKind.poison, 1), breakMax: 170, ultId: 'eult_nido',
      title: 'Reina del Bosque Hondo', mechanicId: 'telarana', legendaryId: 'susurroVibora', feminine: true),

  // Zona 4 · Cavernas Heladas (comunes nivel 16, jefe nivel 20).
  'murcielagoHielo': EnemyDef(id: 'murcielagoHielo', name: 'Murciélago de Hielo', hp: 80, attack: 22, speed: 14,
      xp: 10, credits: 9, inflicts: StatusApplication(StatusKind.freeze, 1), breakMax: 64),
  'elementalEscarcha': EnemyDef(id: 'elementalEscarcha', name: 'Elemental de Escarcha', hp: 170, attack: 23, speed: 5,
      xp: 16, credits: 15, inflicts: StatusApplication(StatusKind.freeze, 1), breakMax: 136, armor: 0.15),
  'sierpe': EnemyDef(id: 'sierpe', name: 'Sierpe de Escarcha', hp: 1050, attack: 33, speed: 8, xp: 150, credits: 190,
      boss: true, inflicts: StatusApplication(StatusKind.freeze, 1), breakMax: 370, ultId: 'eult_aliento',
      title: 'Aliento de las Cavernas Heladas', mechanicId: 'escarcha', legendaryId: 'inviernoPerpetuo',
      feminine: true),
  // Cristal de la Sierpe (invocación, nivel 20): no actúa.
  'cristalHielo': EnemyDef(id: 'cristalHielo', name: 'Cristal de Hielo', hp: 60, attack: 0, speed: 1, xp: 0, credits: 0,
      passive: true),

  // Zona 5 · Fortaleza Caída (comunes nivel 21, jefe nivel 25).
  'esqueleto': EnemyDef(id: 'esqueleto', name: 'Esqueleto', hp: 125, attack: 27, speed: 10, xp: 12, credits: 11,
      pierce: true, breakMax: 100),
  'caballeroCaido': EnemyDef(id: 'caballeroCaido', name: 'Caballero Caído', hp: 200, attack: 28, speed: 7, xp: 18, credits: 16,
      inflicts: StatusApplication(StatusKind.stun, 1, chance: 0.25), breakMax: 160, armor: 0.2),
  'caballeroHueco': EnemyDef(id: 'caballeroHueco', name: 'Caballero Hueco', hp: 1250, attack: 38, speed: 9, xp: 200, credits: 240,
      boss: true, breakMax: 440, ultId: 'eult_juicio',
      title: 'Juramento sin alma de la Fortaleza Caída', mechanicId: 'postura', legendaryId: 'egidaPrimerRey'),
};

/// Mecánicas propias de los jefes (docs/specs/bosses.md § "v0.2").
const Map<String, BossMechanicDef> kBossMechanics = {
  'telarana': BossMechanicDef(
    id: 'telarana',
    kind: BossMechanicKind.web,
    name: 'Telaraña',
    every: 3,
    value: 0.6,
    soloValue: 0.5,
    counter: 'Cada 3 acciones atrapa a un jugador: pierde su próximo turno. '
        '<b>Un aliado lo libera</b> usando <b>Atacar</b> sobre él (el menú '
        'muestra "Liberar"; cuesta medio turno). <span class="k">Solo: '
        'forcejea y pierde medio turno.</span>',
  ),
  'escarcha': BossMechanicDef(
    id: 'escarcha',
    kind: BossMechanicKind.frost,
    name: 'Campo Helado',
    value: 0.10,
    cap: 0.50,
    addType: 'cristalHielo',
    adds: 2,
    soloAdds: 1,
    counter: 'Mientras vivan sus <b>Cristales de Hielo</b>, cada turno de la '
        'Sierpe el grupo pierde 10% de velocidad (máx −50%). <b>Rompé los '
        'cristales</b> (o quebrá a la Sierpe: el quiebre rompe uno) para '
        'descongelar el campo. Aliento Glacial los vuelve a formar. '
        '<span class="k">Solo: 1 cristal.</span>',
  ),
  'postura': BossMechanicDef(
    id: 'postura',
    kind: BossMechanicKind.stance,
    name: 'Postura',
    every: 2,
    value: 0.70,
    soloValue: 0.50,
    counter: '<b>Escudo</b>: −70% al daño físico (ataques y habilidades '
        'físicas). <b>Espada</b>: −70% al daño mágico. Cambia cada 2 turnos '
        'suyos (avisa 1 turno antes). Pegale con lo que no bloquea; '
        '<b>quebrado</b> pierde la postura. <span class="k">Solo: −50%.</span>',
  ),
};

BossMechanicDef? bossMechanicOf(EnemyDef? d) =>
    d?.mechanicId == null ? null : kBossMechanics[d!.mechanicId];

/// ULT de los élites (cualquier tipo).
const kEliteUltId = 'eult_furia';

/// ULT enemigas por id (docs/specs/break_and_enemy_ults.md § 2).
const Map<String, EnemyUltDef> kEnemyUlts = {
  'eult_diluvio': EnemyUltDef(
    id: 'eult_diluvio',
    name: 'Diluvio Ácido',
    power: 1.2,
    allTargets: true,
    status: StatusApplication(StatusKind.poison, 2),
  ),
  'eult_engranaje': EnemyUltDef(
    id: 'eult_engranaje',
    name: 'Engranaje del Fin',
    power: 1.5,
    status: StatusApplication(StatusKind.freeze, 3),
    delayAll: 0.5,
  ),
  'eult_finEras': EnemyUltDef(
    id: 'eult_finEras',
    name: 'Fin de las Eras',
    power: 1.4,
    allTargets: true,
    status: StatusApplication(StatusKind.burn, 2),
    wipeBuffs: true,
  ),
  'eult_nido': EnemyUltDef(
    id: 'eult_nido',
    name: 'Nido Venenoso',
    power: 1.1,
    allTargets: true,
    status: StatusApplication(StatusKind.poison, 3),
    extra: EnemyUltExtra.web,
  ),
  'eult_aliento': EnemyUltDef(
    id: 'eult_aliento',
    name: 'Aliento Glacial',
    power: 1.2,
    allTargets: true,
    status: StatusApplication(StatusKind.freeze, 2),
    extra: EnemyUltExtra.reformCrystals,
  ),
  'eult_juicio': EnemyUltDef(
    id: 'eult_juicio',
    name: 'Juicio Hueco',
    power: 1.9,
    status: StatusApplication(StatusKind.stun, 1),
    extra: EnemyUltExtra.stanceShift,
  ),
  kEliteUltId: EnemyUltDef(
    id: kEliteUltId,
    name: 'Furia Élite',
    power: 2.0,
    guaranteedCrit: true,
  ),
};
