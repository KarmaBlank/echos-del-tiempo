import 'dart:math' as math;

import '../data/game_catalog.dart';
import '../data/zone_curve.dart';
import '../data/zones_catalog.dart';
import '../models/battle_state.dart';
import '../models/mission_def.dart';
import '../models/player_profile.dart';
import '../models/zone_def.dart';
import 'js_math.dart';
import 'progression_rules.dart';

export '../data/zone_curve.dart' show CurveDef, TramoPart;

/// Reglas del mundo por zonas: nivel de piso, escalado de enemigos, XP y
/// desbloqueo por perfil. Ver docs/specs/worldgen.md § 6.3 y § 6.4.
abstract final class ZoneRules {
  static const maxZone = 10;

  // ---------------- niveles ----------------

  /// Nivel de los enemigos del piso [floor] (desde 0).
  static int floorLevel(ZoneDef z, int floor) =>
      z.minLevel + (z.maxLevel - z.minLevel) * (floor + 1) ~/ (z.floors + 1);

  /// Nivel de los élites del piso [floor].
  static int eliteLevel(ZoneDef z, int floor) =>
      math.min(z.maxLevel, floorLevel(z, floor) + 1);

  /// Nivel del jefe (y su grupo).
  static int bossLevel(ZoneDef z) => z.maxLevel;

  // ---------------- escalado ----------------

  /// Vida por nivel: curva por tramos (serrucho, combo_balance.md § 1).
  /// Antes, +15% parejo por nivel.
  static double hpScale(int level, [CurveDef curve = const CurveDef()]) =>
      curve.hpScale(level);
  static double atkScale(int level, [CurveDef curve = const CurveDef()]) =>
      curve.atkScale(level);

  /// Parte del tramo (A, B o C) del nivel [level].
  static TramoPart tramoPart(int level, [CurveDef curve = const CurveDef()]) =>
      curve.partOf(level);

  /// Nivel en la parte C de su tramo (los niveles que cuestan).
  static bool isZoneC(int level, [CurveDef curve = const CurveDef()]) =>
      curve.isZoneC(level);

  /// Nivel nativo de los stats del catálogo de [enemyId].
  static int baseLevel(String enemyId) => kEnemyBaseLevel[enemyId] ?? 1;

  /// Escala la vida y el ATQ (el quiebre va en puntos y no escala,
  /// combo_balance.md § 5) de los enemigos de una batalla
  /// recién creada a nivel [level] (0 = sin escalar). En la parte C del
  /// tramo, los comunes pegan `commonAtkC` más (§ 1). Muta [state].
  static void scaleBattle(BattleState state, int level,
      {CurveDef curve = const CurveDef()}) {
    if (level <= 0) return;
    final zoneC = curve.isZoneC(level);
    for (final e in state.enemies) {
      final base = baseLevel(e.enemyType ?? '');
      final hf = math.max(1.0, hpScale(level, curve) / hpScale(base, curve));
      var af = math.max(1.0, atkScale(level, curve) / atkScale(base, curve));
      if (zoneC && !e.boss && !e.elite) af *= 1 + curve.commonAtkC;
      final hp = jsRound(e.maxHp * hf);
      e
        ..maxHp = hp
        ..hp = hp
        ..attack = jsRound(e.attack * af)
        ..level = level;
    }
  }

  /// Bonus de XP del mundo nuevo: sube de 1 a 1.75 entre el nivel 5 y 15
  /// y, desde el 30, baja hasta [lateBonus] en el 50 (v0.3.0, § 8.1: así
  /// el nivel 50 llega con el Corazón del Tiempo y no antes).
  static double worldBonus(int level) =>
      1 +
      0.75 * ((level - 5) / 10).clamp(0.0, 1.0) -
      (1.75 - lateBonus) * ((level - 30) / 20).clamp(0.0, 1.0);

  /// Bonus de XP en el nivel 50.
  static const lateBonus = 1.3;

  /// Multiplicador de la XP de una batalla de nivel [level] (0 = 1).
  static double xpMult(int level) => level <= 0
      ? 1
      : ProgressionRules.xpFactor(level) * worldBonus(level);

  /// XP de una batalla de nivel [level] con [rawXp] del catálogo.
  static int battleXp(int rawXp, int level) => jsRound(rawXp * xpMult(level));

  // ---------------- enemigos ----------------

  /// El id de enemigo a usar: [id] si existe en el catálogo; si no, su
  /// reemplazo provisorio (`kEnemyFallback`), y si tampoco, `slime`.
  static String resolveEnemy(String id, GameCatalog catalog) {
    if (catalog.enemies.containsKey(id)) return id;
    final f = kEnemyFallback[id];
    if (f != null && catalog.enemies.containsKey(f)) return f;
    return catalog.enemies.containsKey('slime') ? 'slime' : catalog.enemies.keys.first;
  }

  static List<String> resolveGroup(List<String> g, GameCatalog catalog) =>
      List.unmodifiable([for (final id in g) resolveEnemy(id, catalog)]);

  // ---------------- desbloqueo ----------------

  /// Zona desbloqueada de un perfil viejo sin el dato (§ 6.4).
  static int migratedZone(int level) => PlayerProfile.migratedZone(level);

  static int unlockedZone(PlayerProfile p) =>
      p.unlockedZone.clamp(1, maxZone);

  static bool isUnlocked(PlayerProfile p, int zone) =>
      zone <= unlockedZone(p);

  /// Lo que valida el host para `ProposeMissionAction`.
  static bool canPropose(
      GameCatalog catalog, PlayerProfile p, String missionId) {
    final m = catalog.mission(missionId);
    if (m == null) return false;
    if (m.zone == 0) return true;
    final z = catalog.zone(m.zone);
    return z != null && z.playable && isUnlocked(p, m.zone);
  }

  /// Las 10 zonas con su estado para [p].
  static List<ZoneStatus> zoneList(GameCatalog catalog, PlayerProfile p) => [
        for (final z in catalog.zones)
          ZoneStatus(
            zone: z,
            mission: z.missionId == null ? null : catalog.mission(z.missionId!),
            unlocked: isUnlocked(p, z.index),
            label: _label(catalog, z, p),
          ),
      ];

  static String _label(GameCatalog catalog, ZoneDef z, PlayerProfile p) {
    if (!z.playable) return 'Próximamente';
    if (isUnlocked(p, z.index)) return '';
    final prev = catalog.zone(z.index - 1);
    return prev == null
        ? 'Bloqueada'
        : 'Bloqueada: vencé a ${prev.bossName} en ${prev.name}';
  }
}

/// Una zona vista por un jugador (para el mostrador y el mapa del mundo).
class ZoneStatus {
  final ZoneDef zone;

  /// La misión de la zona (`null` = "Próximamente").
  final MissionDef? mission;
  final bool unlocked;

  /// `"Próximamente"`, `"Bloqueada: vencé a <jefe> en <zona>"` o `""`.
  final String label;

  const ZoneStatus({
    required this.zone,
    required this.mission,
    required this.unlocked,
    required this.label,
  });

  bool get playable => mission != null;

  /// Se puede proponer.
  bool get open => playable && unlocked;
}
