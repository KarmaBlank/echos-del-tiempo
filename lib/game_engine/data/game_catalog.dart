import '../models/class_def.dart';
import '../models/enemy_def.dart';
import '../models/mission_def.dart';
import '../models/skill.dart';
import '../models/weapon.dart';
import 'classes_catalog.dart';
import 'enemies_catalog.dart';
import 'missions_catalog.dart';
import 'skills_catalog.dart';
import 'weapons_catalog.dart';

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
  });

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
