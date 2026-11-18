import '../models/class_def.dart';
import '../models/enemy_def.dart';
import '../models/mission_def.dart';
import '../models/skill.dart';
import '../models/weapon.dart';
import '../models/zone_def.dart';
import 'classes_catalog.dart';
import 'enemies_catalog.dart';
import 'missions_catalog.dart';
import 'skills_catalog.dart';
import 'weapons_catalog.dart';
import 'zones_catalog.dart';

/// Todos los datos de juego juntos, para inyectarlos en el motor. Los
/// tests pueden pasar un catálogo reducido; el juego usa [standard].
class GameCatalog {
  final Map<String, ClassDef> classes;
  final Map<String, WeaponDef> weapons;
  final Map<String, SkillDef> skills;
  final Map<String, SkillDef> ultimates; // por tipo de arma
  final Map<String, DualDef> duals; // por dualKey(claseA, claseB)
  final Map<String, EnemyDef> enemies;

  /// ULT enemigas por id (jefes y élites).
  final Map<String, EnemyUltDef> enemyUlts;

  /// Misiones del mostrador, en orden (índice + 1 = tier de sus drops).
  final List<MissionDef> missions;

  const GameCatalog({
    required this.classes,
    required this.weapons,
    required this.skills,
    required this.ultimates,
    required this.duals,
    required this.enemies,
    this.enemyUlts = kEnemyUlts,
    this.missions = kMissions,
    this.zones = kZones,
    this.balanceHash = baseBalanceHash,
  });

  /// Hash del parche de balance aplicado (docs/specs/balance_admin.md
  /// § 4); viaja en el `hello` para que host y clientes coincidan.
  final String balanceHash;

  /// [balanceHash] sin parche de balance.
  static const baseBalanceHash = 'base';

  /// Las 10 zonas del mapa del mundo, en orden (worldgen.md § 6.1).
  final List<ZoneDef> zones;

  /// La zona [index] (1..10), o `null`.
  ZoneDef? zone(int index) {
    for (final z in zones) {
      if (z.index == index) return z;
    }
    return null;
  }

  /// La zona de una misión (`null` si es una misión sin zona).
  ZoneDef? zoneOfMission(String missionId) {
    final m = mission(missionId);
    return m == null || m.zone == 0 ? null : zone(m.zone);
  }

  static const standard = GameCatalog(
    classes: kClasses,
    weapons: kWeapons,
    skills: kSkills,
    ultimates: kAllUltimates,
    duals: kDuals,
    enemies: kEnemies,
  );

  MissionDef? mission(String id) {
    for (final m in missions) {
      if (m.id == id) return m;
    }
    return null;
  }
}
