import '../../../core/i18n/data_text.dart';
import '../../../core/i18n/strings.dart';
import '../../../game_engine/data/game_catalog.dart';
import '../../../game_engine/models/game_session.dart';
import '../../../game_engine/models/mission_def.dart';
import '../../../game_engine/models/zone_def.dart';
import '../../../game_engine/rules/zone_rules.dart';

/// Textos de una misión para el mostrador y la preparación (tarjeta de
/// misión). Solo describen las reglas de docs/specs/missions.md, que
/// aplica `SessionEngine`. Ver docs/specs/panels.md § "Mostrador".
/// Texto en el idioma de [Strings] (docs/specs/i18n.md § 3.4).

/// Bonus de créditos por rango (`missionEnd`).
const kRankBonusText = 'S +50% / A +25%';

/// Probabilidad de arma al ganar por rango (`missionEnd`).
const kRankDropText = 'S 90% · A 70% · B 50%';

/// Nombre de la misión ([MissionDef.name] en es-AR).
String missionNameText(Strings s, MissionDef m) =>
    s.data(DataKeys.missionName(m.id), m.name);

/// Tipo de la misión (`Exterminio`…).
String missionTypeText(Strings s, MissionDef m) =>
    s.data(DataKeys.missionType(m.type), m.type);

/// Nombre de la zona ([ZoneDef.name] en es-AR).
String zoneNameText(Strings s, ZoneDef z) =>
    s.data(DataKeys.zoneName(z.id), z.name);

/// Nombre de un enemigo por id ([fallback] si no está en la tabla).
String enemyNameText(Strings s, String id, String fallback) =>
    s.data(DataKeys.enemyName(id), fallback);

/// Rótulo corto de un objetivo (`Grupos 3/8`).
String objectiveShortText(Strings s, ObjectiveKind k) =>
    s.t('ui.missions.objective.${k.name}.short');

/// Rótulo largo de un objetivo (`Grupos derrotados`).
String objectiveLongText(Strings s, ObjectiveKind k) =>
    s.t('ui.missions.objective.${k.name}.long');

/// `Derrota N grupos para abrir la barrera y vence al jefe (X)` + extras.
String missionObjectiveText(Strings s, MissionDef m, {String? bossName}) {
  final boss = bossName == null
      ? ''
      : s.t('ui.missions.text.boss_suffix', {'name': bossName});
  final extra =
      m.extra <= 0 ? '' : s.t('ui.missions.text.extra', {'n': m.extra});
  final floors = ZoneRules.capFloors(m.floors);
  if (floors > 1 && m.floorGoal > 0) {
    return s.t('ui.missions.text.objective_floors', {
      'goal': m.floorGoal,
      'floors': floors,
      'boss': boss,
      'extra': extra,
    });
  }
  return s.t('ui.missions.text.objective',
      {'goal': m.goal, 'boss': boss, 'extra': extra});
}

/// `Zona 2 · Bosque Hondo · Lv 6-10 · 3 pisos · Jefe: Matriarca Araña`.
String zoneLineText(Strings s, ZoneDef z) => s.t('ui.missions.text.zone_line', {
      'index': z.index,
      'name': zoneNameText(s, z),
      'min': z.minLevel,
      'max': z.maxLevel,
      'n': ZoneRules.missionFloors(z),
      'boss': enemyNameText(s, z.bossId, z.bossName),
    });

/// `Bosque Hondo · Piso 2/3` ([floor] desde 0).
String floorLabelText(Strings s, String zoneName, int floor, int floors) =>
    s.t('ui.missions.text.floor_label',
        {'zone': zoneName, 'floor': floor + 1, 'floors': floors});

/// `¡Zona 3 desbloqueada! Ruinas Cronales`.
String zoneUnlockedText(Strings s, int zone, String? name) =>
    '${s.t('ui.missions.text.zone_unlocked', {'zone': zone})}'
    '${name == null ? '' : ' $name'}';

/// `< N min sin K.O.`
String missionSRankText(Strings s, MissionDef m) {
  final min = m.sTime ~/ 60, sec = m.sTime % 60;
  return sec == 0
      ? s.t('ui.missions.text.s_rank_min', {'min': min})
      : s.t('ui.missions.text.s_rank_clock',
          {'clock': '$min:${sec.toString().padLeft(2, '0')}'});
}

/// Recompensas: [tier] es el nº de misión (tier de las armas que suelta).
String missionRewardText(Strings s, MissionDef m, int tier) =>
    s.t('ui.missions.text.reward', {
      'bonus': kRankBonusText,
      'tier': tier,
      'drop': kRankDropText,
      'chest': m.chestTier,
    });

/// Nombre del jefe (el primero del grupo `boss`).
String? missionBossName(Strings s, GameCatalog c, MissionDef m) {
  if (m.boss.isEmpty) return null;
  final e = c.enemies[m.boss.first];
  return e == null ? null : enemyNameText(s, e.id, e.name);
}

/// Nº de misión en el catálogo (`_missionTier` del motor).
int missionTier(GameCatalog c, MissionDef m) => c.missions.indexOf(m) + 1;
