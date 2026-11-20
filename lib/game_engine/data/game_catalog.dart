import '../models/class_def.dart';
import '../models/enemy_def.dart';
import '../models/mission_def.dart';
import '../models/skill.dart';
import '../models/status.dart';
import '../models/weapon.dart';
import '../models/zone_def.dart';
import 'abyss_catalog.dart';
import 'classes_catalog.dart';
import 'elements_catalog.dart';
import 'enemy_families.dart'
    show ComboRulesDef, HitCapDef, kComboRules, kHitCaps;
import 'enemies_catalog.dart';
import 'missions_catalog.dart';
import 'skills_catalog.dart';
import 'ults_v2_catalog.dart' show kUltV2Skills;
import 'weapon_duals_catalog.dart';
import 'weapons_catalog.dart';
import 'zone_curve.dart';
import 'zones_catalog.dart';

/// Todos los datos de juego juntos, para inyectarlos en el motor. Los
/// tests pueden pasar un catálogo reducido; el juego usa [standard].
class GameCatalog {
  final Map<String, ClassDef> classes;
  final Map<String, WeaponDef> weapons;
  final Map<String, SkillDef> skills;
  final Map<String, SkillDef> ultimates; // por tipo de arma
  /// Dúos: los de clase por `dualKey(claseA, claseB)` y los de armas
  /// por su id `w_...` (weapon_duals_catalog.dart).
  final Map<String, DualDef> duals;
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
    this.reactions = kReactions,
    this.elementStatuses = kElementStatuses,
    this.abyssBosses = kAbyssBosses,
    this.fragmentDrops = kFragmentDrops,
    this.hitCaps = kHitCaps,
    this.comboRules = kComboRules,
    this.curves = kCurves,
    Map<String, SkillDef>? playerUlts,
  }) : _playerUlts = playerUlts;

  final Map<String, SkillDef>? _playerUlts;

  /// Las 50 ULT v2 de jugador por id (docs/specs/ultimates_v2.md): las
  /// del código o las del parche de balance / datos.
  Map<String, SkillDef> get playerUlts => _playerUlts ?? kUltV2Skills;

  /// Jefes del Abismo por número (docs/specs/abyss_bosses.md § 2).
  final Map<int, AbyssBossDef> abyssBosses;

  /// Números del drop de Fragmentos (una sola entrada, `fragmentos`).
  final Map<String, FragmentDropDef> fragmentDrops;

  /// Tope por golpe sin debilidad (combo_balance.md § 3.2), una entrada.
  final Map<String, HitCapDef> hitCaps;

  HitCapDef get hitCap => hitCaps['tope'] ?? const HitCapDef();

  /// Reglas de combos y quiebre (combo_balance.md § 4-5), una entrada.
  final Map<String, ComboRulesDef> comboRules;

  ComboRulesDef get combo => comboRules['combos'] ?? const ComboRulesDef();

  /// Curva por tramos y reglas de grupo (combo_balance.md § 1 y § 3.3),
  /// una entrada.
  final Map<String, CurveDef> curves;

  CurveDef get curve => curves['curva'] ?? const CurveDef();

  FragmentDropDef get fragmentDrop =>
      fragmentDrops['fragmentos'] ?? const FragmentDropDef();

  /// El Jefe del Abismo del enemigo [enemyId] (o `null`).
  AbyssBossDef? abyssOf(String? enemyId) => abyssBossOf(enemyId, abyssBosses);

  /// Números de las reacciones elementales por `ReactionKind.name`
  /// (docs/specs/elemental_reactions.md § 2).
  final Map<String, ReactionDef> reactions;

  /// Reglas de Mojado, Cargado y Congelación por `StatusKind.name` (§ 7).
  final Map<String, ElementStatusDef> elementStatuses;

  /// La reacción [k] (siempre hay: si falta, la del código).
  ReactionDef reaction(ReactionKind k) =>
      reactions[k.name] ?? kReactions[k.name]!;

  /// Reglas del estado elemental [k] (wet, charged, freeze).
  ElementStatusDef elementStatus(StatusKind k) =>
      elementStatuses[k.name] ?? kElementStatuses[k.name]!;

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

  /// Copia con otras ULT (datos YAML, ultimates_v2.md § 5.1).
  GameCatalog withUlts(
          {Map<String, SkillDef>? playerUlts,
          Map<String, EnemyUltDef>? enemyUlts}) =>
      GameCatalog(
        classes: classes,
        weapons: weapons,
        skills: skills,
        ultimates: ultimates,
        duals: duals,
        enemies: enemies,
        enemyUlts: enemyUlts ?? this.enemyUlts,
        missions: missions,
        zones: zones,
        balanceHash: balanceHash,
        reactions: reactions,
        elementStatuses: elementStatuses,
        abyssBosses: abyssBosses,
        fragmentDrops: fragmentDrops,
        hitCaps: hitCaps,
        comboRules: comboRules,
        curves: curves,
        playerUlts: playerUlts ?? _playerUlts,
      );

  static const standard = GameCatalog(
    classes: kClasses,
    weapons: kWeapons,
    skills: kSkills,
    ultimates: kAllUltimates,
    duals: kAllDuals,
    enemies: kEnemies,
  );

  MissionDef? mission(String id) {
    for (final m in missions) {
      if (m.id == id) return m;
    }
    return null;
  }
}
