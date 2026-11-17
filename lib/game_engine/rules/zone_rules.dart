import 'dart:math' as math;

import '../data/game_catalog.dart';
import '../data/zones_catalog.dart';
import '../models/battle_state.dart';
import '../models/mission_def.dart';
import '../models/player_profile.dart';
import '../models/zone_def.dart';
import 'js_math.dart';
import 'progression_rules.dart';

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

  static double hpScale(int level) => 1 + 0.15 * (level - 1);
  static double atkScale(int level) => 1 + 0.08 * (level - 1);

  /// Nivel nativo de los stats del catálogo de [enemyId].
  static int baseLevel(String enemyId) => kEnemyBaseLevel[enemyId] ?? 1;

  /// Escala la vida, el quiebre y el ATQ de los enemigos de una batalla
  /// recién creada a nivel [level] (0 = sin escalar). Muta [state].
  static void scaleBattle(BattleState state, int level) {
    if (level <= 0) return;
    for (final e in state.enemies) {
      final base = baseLevel(e.enemyType ?? '');
      final hf = math.max(1.0, hpScale(level) / hpScale(base));
      final af = math.max(1.0, atkScale(level) / atkScale(base));
      final hp = jsRound(e.maxHp * hf);
      e
        ..maxHp = hp
        ..hp = hp
        ..attack = jsRound(e.attack * af)
        ..breakBase = e.breakBase * hf;
    }
  }

  /// Bonus de XP del mundo nuevo (sube de 1 a 1.75 entre el nivel 5 y 15).
  static double worldBonus(int level) =>
      1 + 0.75 * ((level - 5) / 10).clamp(0.0, 1.0);

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
