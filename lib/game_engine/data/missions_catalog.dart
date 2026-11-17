import '../models/mission_def.dart';
import 'zones_catalog.dart';

/// Misiones del mostrador: las de las zonas jugables, en orden de zona
/// (el índice + 1 es el "tier" de los drops). Ver docs/specs/worldgen.md
/// § 6.2.
const List<MissionDef> kMissions = kZoneMissions;

/// `MISSIONS` del prototipo, 1:1 y en el mismo orden: un solo mapa
/// (`genMap`), sin zona. Ya no están en el mostrador; quedan para los
/// tests de paridad con el prototipo (docs/specs/missions.md).
const List<MissionDef> kPrototypeMissions = [
  MissionDef(
    id: 'm1',
    name: 'Pradera Esmeralda',
    type: 'Exterminio',
    rank: 'C',
    recommendedLevel: 1,
    theme: 'pradera',
    goal: 7,
    groups: [
      ['slime', 'slime'],
      ['slime', 'bat'],
      ['bat', 'bat'],
      ['slime', 'slime', 'slime'],
    ],
    boss: ['reyLimo', 'slime', 'slime'],
    sTime: 420,
    elite: 'bat',
    extra: 1,
  ),
  MissionDef(
    id: 'm2',
    name: 'Ruinas Cronales',
    type: 'Recuperación',
    rank: 'B',
    recommendedLevel: 4,
    theme: 'ruinas',
    goal: 8,
    groups: [
      ['golem'],
      ['golem', 'bat'],
      ['bat', 'bat', 'slime'],
      ['golem', 'slime'],
    ],
    boss: ['golemReloj', 'golem'],
    sTime: 510,
    elite: 'golem',
    extra: 2,
  ),
  MissionDef(
    id: 'm3',
    name: 'Abismo del Tiempo',
    type: 'Urgente',
    rank: 'A',
    recommendedLevel: 7,
    theme: 'abismo',
    goal: 9,
    groups: [
      ['ghost', 'ghost'],
      ['ghost', 'golem'],
      ['golem', 'golem'],
      ['ghost', 'bat', 'bat'],
    ],
    boss: ['devorador', 'ghost', 'ghost'],
    sTime: 600,
    elite: 'ghost',
    extra: 2,
  ),
];
