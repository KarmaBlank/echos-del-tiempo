import '../data/game_catalog.dart';
import '../data/tuning_catalog.dart';
import '../models/world_save.dart' show DungeonSave, TownState;
import '../serialization/session_json.dart';
import '../models/game_session.dart';
import '../models/item.dart' show CraftMaterial;
import '../models/player_profile.dart';

/// Mazmorras de zona persistentes por mundo
/// (docs/specs/persistent_dungeons.md). Reglas puras del host.
abstract final class DungeonRules {
  static TuningDef get _t => tuning(TuningId.dungeon);

  /// Días del mundo vacía para que reaparezcan los enemigos.
  static int get respawnDays => _t.i('respawnDays').clamp(1, 999);

  /// Distancia (px) al altar de la Ofrenda para usarlo.
  static double get altarReach => _t.d('altarReach');

  /// Semilla fija de la mazmorra [missionId] en el mundo [worldId]
  /// (FNV-1a de 32 bits, positiva y < 10⁹ como las de `_seeds`).
  static int seedFor(String worldId, String missionId) {
    var h = 0x811c9dc5;
    for (final c in '$worldId|$missionId'.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h % 1000000000;
  }

  /// La mazmorra de zona se guarda (no Ecos, Pruebas, Abismo, Travesía ni
  /// TUTORIAL; sin mundo, como en los tests viejos, tampoco).
  static bool persistent(GameSession s, {required int zone}) =>
      zone != 0 &&
      s.worldId != null &&
      s.eco == null &&
      s.trial == null &&
      s.abyss == null &&
      s.run == null &&
      s.tutorial == null;

  /// Al volver a entrar: si estuvo vacía [respawnDays] días o más, los
  /// enemigos normales y élite vencidos reviven en su lugar. El jefe no
  /// (se revive con la Ofrenda). Devuelve cuántos revivieron.
  static int respawn(MissionRun m, {required int parkedDay, required int today}) {
    if (today - parkedDay < respawnDays) return 0;
    var n = 0;
    for (final e in m.enemies) {
      if (e.alive || e.boss) continue;
      e
        ..alive = true
        ..x = e.homeX
        ..y = e.homeY
        ..aggro = false;
      n++;
    }
    return n;
  }

  /// Lo de cada visita vuelve a cero (rango, XP, élites de la visita) y
  /// las misiones opcionales falladas se pueden volver a intentar.
  static void newVisit(MissionRun m) {
    m
      ..elapsed = 0
      ..kos = 0
      ..xp = 0
      ..credits = 0
      ..elites = 0
      ..blessing = null
      ..windUntil = 0;
    m.eliteDrops.clear();
    m.questsFailed.clear();
  }

  /// El jefe de la mazmorra, o `null`.
  static FieldEnemy? boss(MissionRun m) =>
      m.enemies.where((e) => e.boss).firstOrNull;

  /// El altar de la Ofrenda está activo: jefe vencido.
  static bool altarActive(MissionRun? m) {
    final b = m == null ? null : boss(m);
    return b != null && !b.alive;
  }

  /// Costo de la Ofrenda en la zona [zone] (solo lo que es > 0).
  static Map<CraftMaterial, int> offeringCost(int zone) {
    final t = _t;
    final z = zone < 1 ? 1 : zone;
    int from(String k, String per) =>
        z < t.i(k) ? 0 : t.i(per) * (z - t.i(k) + 1);
    final out = {
      CraftMaterial.esquirla: t.i('esqBase') + t.i('esqPerZone') * z,
      CraftMaterial.cristal: from('crisFrom', 'crisPerZone'),
      CraftMaterial.prisma: from('prismaFrom', 'prismaPerZone'),
    };
    out.removeWhere((_, v) => v <= 0);
    return out;
  }

  /// Por qué [p] no puede ofrendar, o `null`.
  static String? cannotOffer(PlayerProfile p, int zone) {
    for (final e in offeringCost(zone).entries) {
      if (p.material(e.key) < e.value) return 'Faltan ${e.key.label}';
    }
    return null;
  }

  /// [p] con el costo pagado, o `null` si no le alcanza.
  static PlayerProfile? pay(PlayerProfile p, int zone) {
    if (cannotOffer(p, zone) != null) return null;
    final mats = {...p.materials};
    for (final e in offeringCost(zone).entries) {
      mats[e.key] = mats[e.key]! - e.value;
    }
    return p.copyWith(materials: mats);
  }

  /// El pueblo de [s] con su mazmorra de zona guardada (si es una), al
  /// día de hoy. Sin cambios si no hay mazmorra persistente en curso.
  static TownState park(GameSession s, GameCatalog catalog) {
    final m = s.mission;
    if (m == null ||
        !persistent(s, zone: m.zone) ||
        catalog.mission(m.missionId) == null) {
      return s.town;
    }
    return s.town.withDungeon(DungeonSave(
        missionId: m.missionId,
        run: SessionJson(catalog).missionToJson(m),
        parkedDay: s.town.sky.day));
  }

  /// La mazmorra guardada de [missionId] lista para jugar, o `null` (no
  /// hay o el guardado está dañado). Aplica la reaparición y la visita
  /// nueva; devuelve también cuántos enemigos revivieron.
  static (MissionRun, int)? restore(
      TownState town, String missionId, GameCatalog catalog) {
    final d = town.dungeons[missionId];
    if (d == null) return null;
    final MissionRun m;
    try {
      m = SessionJson(catalog).missionFromJson(d.run);
    } catch (_) {
      return null;
    }
    if (m.missionId != missionId) return null;
    newVisit(m);
    final n = respawn(m, parkedDay: d.parkedDay, today: town.sky.day);
    return (m, n);
  }
}
