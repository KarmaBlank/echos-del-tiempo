import '../../../game_engine/data/game_catalog.dart';
import '../../../game_engine/models/mission_def.dart';
import '../../../game_engine/models/zone_def.dart';
import '../../../game_engine/rules/zone_rules.dart';

/// Textos de una misión para el mostrador y la preparación (tarjeta de
/// misión). Solo describen las reglas de docs/specs/missions.md, que
/// aplica `SessionEngine`. Ver docs/specs/panels.md § "Mostrador".

/// Bonus de créditos por rango (`missionEnd`).
const kRankBonusText = 'S +50% / A +25%';

/// Probabilidad de arma al ganar por rango (`missionEnd`).
const kRankDropText = 'S 90% · A 70% · B 50%';

/// `Derrota N grupos para abrir la barrera y vence al jefe (X)` + extras.
String missionObjectiveText(MissionDef m, {String? bossName}) {
  final boss = bossName == null ? '' : ' ($bossName)';
  final extra = m.extra <= 0
      ? ''
      : ' · +${m.extra} objetivo${m.extra == 1 ? '' : 's'} extra al azar '
          '(fragmentos, sellos o élite)';
  final floors = ZoneRules.capFloors(m.floors);
  if (floors > 1 && m.floorGoal > 0) {
    return 'Derrota ${m.floorGoal} grupos por piso ($floors pisos) y '
        'vence al jefe$boss en el último$extra';
  }
  return 'Derrota ${m.goal} grupos para abrir la barrera y vence al '
      'jefe$boss$extra';
}

/// `Zona 2 · Bosque Hondo · Lv 6-10 · 3 pisos · Jefe: Matriarca Araña`.
String zoneLineText(ZoneDef z) {
  final n = ZoneRules.missionFloors(z);
  return 'Zona ${z.index} · ${z.name} · ${z.levelText} · '
      '$n piso${n == 1 ? '' : 's'} · Jefe: ${z.bossName}';
}

/// `Bosque Hondo · Piso 2/3` ([floor] desde 0).
String floorLabelText(String zoneName, int floor, int floors) =>
    '$zoneName · Piso ${floor + 1}/$floors';

/// `¡Zona 3 desbloqueada! Ruinas Cronales`.
String zoneUnlockedText(int zone, String? name) =>
    '¡Zona $zone desbloqueada!${name == null ? '' : ' $name'}';

/// `< N min sin K.O.`
String missionSRankText(MissionDef m) {
  final min = m.sTime ~/ 60, s = m.sTime % 60;
  return '< ${s == 0 ? '$min min' : '$min:${s.toString().padLeft(2, '0')}'} '
      'sin K.O.';
}

/// Recompensas: [tier] es el nº de misión (tier de las armas que suelta).
String missionRewardText(MissionDef m, int tier) =>
    'XP y créditos por pelea · bonus $kRankBonusText · arma de tier $tier '
    'al ganar ($kRankDropText) · cofres nivel ${m.chestTier}';

/// Nombre del jefe (el primero del grupo `boss`).
String? missionBossName(GameCatalog c, MissionDef m) =>
    m.boss.isEmpty ? null : c.enemies[m.boss.first]?.name;

/// Nº de misión en el catálogo (`_missionTier` del motor).
int missionTier(GameCatalog c, MissionDef m) => c.missions.indexOf(m) + 1;
