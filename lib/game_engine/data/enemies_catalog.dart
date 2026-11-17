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
      boss: true, inflicts: StatusApplication(StatusKind.poison, 2), breakMax: 80, ultId: 'eult_diluvio'),
  'golemReloj': EnemyDef(id: 'golemReloj', name: 'Gólem Reloj', hp: 430, attack: 18, speed: 7, xp: 120, credits: 150,
      boss: true, inflicts: StatusApplication(StatusKind.freeze, 2), breakMax: 150, ultId: 'eult_engranaje'),
  'devorador': EnemyDef(id: 'devorador', name: 'Devorador de Eras', hp: 820, attack: 23, speed: 10, xp: 250, credits: 300,
      boss: true, areaAttack: true, inflicts: StatusApplication(StatusKind.burn, 2), breakMax: 280, ultId: 'eult_finEras'),
};

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
  kEliteUltId: EnemyUltDef(
    id: kEliteUltId,
    name: 'Furia Élite',
    power: 2.0,
    guaranteedCrit: true,
  ),
};
