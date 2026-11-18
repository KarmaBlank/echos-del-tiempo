import 'dart:math' as math;

import '../data/exploration_catalog.dart';
import '../models/game_map.dart';
import '../models/game_session.dart';
import '../models/item.dart' show ItemMod;
import '../models/player_state.dart';
import '../models/weapon.dart';

/// Resumen de cofres y salas secretas del piso (HUD, worldgen.md § 11.7).
class FloorSummary {
  const FloorSummary(this.chestsOpen, this.chests, this.secretsOpen, this.secrets);
  final int chestsOpen, chests, secretsOpen, secrets;

  String get text => secrets == 0
      ? 'Cofres $chestsOpen/$chests'
      : 'Cofres $chestsOpen/$chests · Secretos $secretsOpen/$secrets';
}

/// Reglas puras de la exploración v0.6 (docs/specs/worldgen.md § 11).
abstract final class ExplorationRules {
  /// E a menos de esto (px, al centro del tile) usa un PdI.
  static const poiRange = 26.0;

  /// Atajo: hay que estar a menos de esto (px) del tile del lado lejano.
  static const shortcutRange = 22.0;

  /// Un PdI a menos de esto (px) de un jugador vivo queda descubierto.
  static const discoverRange = 80.0;

  /// Tocar una reliquia (px).
  static const relicRange = 14.0;

  static double _d(double ax, double ay, double bx, double by) {
    final dx = ax - bx, dy = ay - by;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// El mapa con el estado de la misión: PdI usados (`K` y su sala `k`→`:`,
  /// `H`→`h`,
  /// `W`→`w`, `J`→`,`, `B`→`b`). Sin cambios devuelve [base].
  static GameMap withState(GameMap base, MissionRun? m) {
    if (m == null || m.poiUsed.isEmpty || base.floors.isEmpty) return base;
    final rows = [for (final r in base.rows) r.split('')];
    var changed = false;
    for (final f in base.floors) {
      for (final p in f.pois) {
        if (!m.poiUsed.contains(p.id)) continue;
        final to = switch (p.kind) {
          PoiKind.secret => Tile.vaultFloor,
          PoiKind.shrine => Tile.shrineUsed,
          PoiKind.waystone => Tile.waystoneOn,
          PoiKind.shortcut => Tile.path,
          PoiKind.brazier => Tile.brazierLit,
          PoiKind.wind || PoiKind.relic => null,
        };
        if (to == null) continue;
        rows[p.ty][p.tx] = to;
        final room = p.room;
        if (p.kind == PoiKind.secret && room != null) {
          for (var y = room.y; y < room.y + room.h; y++) {
            for (var x = room.x; x < room.x + room.w; x++) {
              if (rows[y][x] == Tile.secretFloor) rows[y][x] = Tile.vaultFloor;
            }
          }
        }
        changed = true;
      }
    }
    if (!changed) return base;
    return GameMap(
      width: base.width,
      height: base.height,
      rows: [for (final r in rows) r.join()],
      theme: base.theme,
      spawn: base.spawn,
      lobby: base.lobby,
      side: base.side,
      arena: base.arena,
      rooms: base.rooms,
      boss: base.boss,
      spots: base.spots,
      merchant: base.merchant,
      floors: base.floors,
      entrances: base.entrances,
      zone: base.zone,
    );
  }

  /// Clave del estado que cambia el mapa (para la caché).
  static String stateKey(MissionRun? m) {
    if (m == null || m.poiUsed.isEmpty) return '';
    return (m.poiUsed.toList()..sort()).join(',');
  }

  /// El PdI de [f] que [x], [y] (px) puede usar con E, o `null`. Las
  /// reliquias se levantan tocándolas y no cuentan; la inscripción no
  /// existe todavía (lore del dueño pendiente).
  static MapPoi? usable(MapFloor f, MissionRun m, double x, double y) {
    MapPoi? best;
    var bd = double.infinity;
    for (final p in f.pois) {
      if (!canUse(p, m)) continue;
      final c = p.kind == PoiKind.shortcut ? _sideCenter(p) : p.center;
      final range = p.kind == PoiKind.shortcut ? shortcutRange : poiRange;
      final d = _d(x, y, c.x, c.y);
      if (d < range && d < bd) {
        bd = d;
        best = p;
      }
    }
    return best;
  }

  static WorldPoint _sideCenter(MapPoi p) =>
      WorldPoint(p.side!.$1 * 16 + 8.0, p.side!.$2 * 16 + 8.0);

  /// Se puede usar [p] ahora: sin usar, o una piedra activada con otra
  /// activada a donde viajar, o el viento (reusable cuando se acaba).
  static bool canUse(MapPoi p, MissionRun m, {double time = 0}) =>
      switch (p.kind) {
        PoiKind.relic => false,
        PoiKind.wind => true,
        PoiKind.waystone => true,
        _ => !m.poiUsed.contains(p.id),
      };

  /// Viaje rápido: la siguiente piedra activada después de [from] (en el
  /// orden del piso), o `null` si no hay otra.
  static MapPoi? nextWaystone(MapFloor f, MissionRun m, MapPoi from) {
    final on = [
      for (final p in f.pois)
        if (p.kind == PoiKind.waystone && m.poiUsed.contains(p.id)) p,
    ];
    if (on.length < 2 || !on.contains(from)) return null;
    return on[(on.indexOf(from) + 1) % on.length];
  }

  /// Velocidad del jugador con el Viento del Eco activo.
  static double speedMult(MissionRun? m, double time) =>
      m != null && time < m.windUntil ? kWindSpeed : 1;

  /// Cofres y salas del piso [f] de [m].
  static FloorSummary floorSummary(MissionRun m, MapFloor f) {
    var co = 0, c = 0;
    for (final it in m.itemsOn(f.index)) {
      if (it.kind != MissionItemKind.chest || it.secret != null) continue;
      c++;
      if (it.done) co++;
    }
    var so = 0, s = 0;
    for (final p in f.pois) {
      if (p.kind != PoiKind.secret) continue;
      s++;
      if (m.poiUsed.contains(p.id)) so++;
    }
    return FloorSummary(co, c, so, s);
  }

  /// Progreso de [q] (`(hecho, total)`).
  static (int, int) questProgress(FloorQuest q, MissionRun m, MapFloor f) {
    switch (q.kind) {
      case QuestKind.braseros || QuestKind.reliquia:
        final mine = [for (final p in f.pois) if (p.quest == q.id) p];
        return (mine.where((p) => m.poiUsed.contains(p.id)).length, mine.length);
      case QuestKind.guardian:
        final g = m.enemiesOn(f.index).where((e) => e.elite).firstOrNull;
        return (g != null && !g.alive ? 1 : 0, 1);
      case QuestKind.limpieza:
        final n = m.enemiesOn(f.index).where((e) => !e.boss && !e.elite);
        return (n.where((e) => !e.alive).length, n.length);
      case QuestKind.secreto:
        final s = [for (final p in f.pois) if (p.kind == PoiKind.secret) p];
        return (s.where((p) => m.poiUsed.contains(p.id)).length, s.length);
      case QuestKind.cofres:
        final c = m.itemsOn(f.index).where((i) => i.kind == MissionItemKind.chest);
        return (c.where((i) => i.done).length, c.length);
    }
  }

  /// La misión opcional quedó cumplida (y no fallada).
  static bool questComplete(FloorQuest q, MissionRun m, MapFloor f) {
    if (m.questsFailed.contains(q.id)) return false;
    final (a, b) = questProgress(q, m, f);
    return b > 0 && a >= b;
  }

  /// Texto del rastreador: `Encendé los braseros 1/3`.
  static String questLine(FloorQuest q, MissionRun m, MapFloor f) {
    final (a, b) = questProgress(q, m, f);
    return '${questText(q.kind)} ${math.min(a, b)}/$b';
  }

  /// La build de batalla con la bendición [k] (implícitos extra del arma).
  static PlayerBuild blessedBuild(PlayerBuild b, BlessingKind? k) {
    final mods = k == null ? const <ItemMod>[] : kBlessings[k]!.mods;
    if (mods.isEmpty) return b;
    final w = b.equippedWeapon;
    final blessed = WeaponDef(
      id: w.id,
      name: w.name,
      classId: w.classId,
      type: w.type,
      tier: w.tier,
      level: w.level,
      price: w.price,
      requirements: w.requirements,
      atk: w.atk,
      mag: w.mag,
      skillIds: w.skillIds,
      weight: w.weight,
      shieldDefense: w.shieldDefense,
      implicit: [...w.implicit, ...mods],
    );
    return PlayerBuild(
      classId: b.classId,
      level: b.level,
      attributes: b.attributes,
      equippedWeapon: blessed,
      weaponUpgrades: b.weaponUpgrades,
      passiveProgress: b.passiveProgress,
      item: b.item,
      bonusDefense: b.bonusDefense,
      ascension: b.ascension,
    );
  }
}
