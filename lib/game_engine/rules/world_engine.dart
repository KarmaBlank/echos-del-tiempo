import '../data/biomes_catalog.dart';
import '../models/game_mode.dart';
import '../models/game_session.dart';
import '../models/player_profile.dart';
import '../models/session_action.dart';
import '../models/session_event.dart';
import '../models/session_world.dart';
import '../models/tutorial.dart' show kTutorialVersion;
import '../models/world_save.dart' show TownState;
import 'abyss_rules.dart';
import 'biome_rules.dart';
import 'dungeon_rules.dart';
import 'eco_portal_rules.dart';
import 'session_engine.dart';
import 'trial_rules.dart';
import 'zone_rules.dart';

export '../models/session_world.dart';

/// Lo que dejó un paso del mundo: los eventos de cada jugador (los de su
/// instancia, más los de la que dejó si se movió).
class WorldStep {
  WorldStep(this.events);
  final Map<String, List<SessionEvent>> events;

  List<SessionEvent> eventsFor(String playerId) => events[playerId] ?? const [];
}

/// Movimiento libre por jugador (docs/specs/free_movement.md): enruta las
/// acciones a la instancia de cada uno, corre todas, mueve jugadores entre
/// instancias y comparte lo común. Reglas del host; Dart puro.
///
/// Trabaja sobre [SessionWorld] en el lugar (es del host); cada
/// [GameSession] de adentro se reemplaza por la que devuelve
/// [SessionEngine].
class WorldEngine {
  WorldEngine(this.engine);

  final SessionEngine engine;

  /// La Travesía es una sola sala: sin instancias.
  bool get split =>
      engine.freeMovement && engine.gameMode == GameModeKind.mundo;

  /// Arma el mundo con [town] como pueblo.
  SessionWorld create(GameSession town) =>
      SessionWorld(town.copy()..instance = kTownRoom);

  // ---------------- entradas ----------------

  /// Entra un jugador (al pueblo). `null` si la sala está llena o ya está.
  WorldStep? addPlayer(SessionWorld w, String id, PlayerProfile profile,
      {int tutorialVersion = kTutorialVersion}) {
    if (w.allPlayers.length >= engine.maxPlayers || w.roomOf(id) != null) {
      return null;
    }
    final step =
        engine.addPlayer(w.town, id, profile, tutorialVersion: tutorialVersion);
    if (step == null) return null;
    final op = _W(this, w);
    step.state.ownerId ??= id;
    op.put(kTownRoom, step);
    return op.finish();
  }

  /// Un jugador se fue de la sala.
  WorldStep? removePlayer(SessionWorld w, String id) {
    final key = w.roomOf(id);
    if (key == null) return null;
    final step = engine.removePlayer(w.rooms[key]!, id);
    if (step == null) return null;
    final op = _W(this, w)..put(key, step);
    return op.finish();
  }

  /// [senderId] manda [action] (como [actorId], él o un compañero suyo).
  /// `null` = rechazada (nada cambia).
  WorldStep? apply(SessionWorld w, String senderId, SessionAction action,
      {String? actorId}) {
    final key = w.roomOf(senderId);
    if (key == null) return null;
    final s = w.rooms[key]!;
    final op = _W(this, w);
    final actor = actorId ?? senderId;
    if (split && actor == senderId) {
      final p = s.players[senderId]!;
      if (action is LeaveDungeonAction) {
        return op.leave(key, p, action.poiId) ? op.finish() : null;
      }
      if (action is JoinPlayerAction) {
        return op.join(key, p, action.targetId) ? op.finish() : null;
      }
      if (action is TravelAction) {
        return op.travel(key, p, action.place, ecoZone: action.ecoZone)
            ? op.finish()
            : null;
      }
      if (_starts(action) &&
          !SessionWorld.isDungeon(key) &&
          s.mode == SessionMode.lobby &&
          s.run == null &&
          !p.isCompanion) {
        return op.enter(key, p, action) ? op.finish() : null;
      }
    }
    final step = actor == senderId
        ? engine.apply(s, senderId, action)
        : engine.applyFor(s, senderId, actor, action);
    if (step == null) return null;
    op.put(key, step);
    return op.finish();
  }

  /// Aplica [step] (calculado afuera sobre la instancia [key], p. ej.
  /// sumar un compañero) y comparte lo común.
  WorldStep commit(SessionWorld w, String key, SessionStep step) {
    final op = _W(this, w)..put(key, step);
    return op.finish();
  }

  /// Cambia lo común en todas las instancias (Atlas, tiempo de turno...).
  void setAll(SessionWorld w, GameSession Function(GameSession) f) {
    for (final k in [...w.rooms.keys]) {
      w.rooms[k] = f(w.rooms[k]!);
    }
  }

  /// `hostTick` de todas las instancias. El reloj del pueblo corre una
  /// sola vez (en `pueblo`).
  WorldStep tick(SessionWorld w, double dt) {
    final op = _W(this, w);
    for (final k in [...w.rooms.keys]) {
      final s = w.rooms[k];
      if (s == null) continue;
      op.put(k, engine.tick(s, dt, world: k == kTownRoom || !split));
    }
    return op.finish();
  }

  /// El pueblo para guardar el mundo: con las mazmorras de zona que
  /// siguen abiertas guardadas tal como están (persistent_dungeons.md § 2).
  TownState savedTown(SessionWorld w) {
    var t = w.town.town;
    for (final e in w.rooms.entries) {
      if (!SessionWorld.isDungeon(e.key) || e.value.mission == null) continue;
      t = DungeonRules.park(e.value.copy()..town = t, engine.catalog);
    }
    return t;
  }

  static bool _starts(SessionAction a) =>
      a is ProposeMissionAction ||
      a is ProposeEcoAction ||
      a is ProposeTrialAction ||
      a is ProposeAbyssAction ||
      a is StartTutorialAction;

  /// IR CON (free_movement.md § 2.5): desde [from] a [to] solo fuera de
  /// batalla y de la Travesía / TUTORIAL; a una mazmorra, solo si está en
  /// el campo sin resultado.
  static bool canJoin(GameSession from, GameSession to) {
    bool calm(GameSession s) =>
        (s.mode == SessionMode.lobby || s.mode == SessionMode.field) &&
        s.result == null &&
        s.run == null &&
        s.tutorial == null;
    return calm(from) && calm(to);
  }

  /// Dónde está la instancia [key], listo para mostrar.
  String placeLabel(SessionWorld w, String key) {
    if (key == kTownRoom) return 'Pueblo';
    final r = w.rooms[key];
    if (!SessionWorld.isDungeon(key)) return biomeDef(key)?.name ?? key;
    if (r == null) return 'Mazmorra';
    if (r.tutorial != null) return 'Tutorial';
    final id = r.mission?.missionId ?? r.vote?.missionId ?? r.prep?.missionId;
    return (id == null ? null : engine.missionOf(r, id)?.name) ?? 'Mazmorra';
  }

  /// Clave de destino de la instancia [key] (free_movement.md § 3):
  /// `pueblo`, el id del bioma o `m:<misión>`; vacía si no hay misión.
  String placeId(SessionWorld w, String key) {
    if (!SessionWorld.isDungeon(key)) return key;
    final r = w.rooms[key];
    if (r == null || r.tutorial != null) return '';
    final id = r.mission?.missionId ?? r.vote?.missionId ?? r.prep?.missionId;
    return id == null ? '' : 'm:$id';
  }
}

/// Un paso del mundo en curso.
class _W {
  _W(this.we, this.w);
  final WorldEngine we;
  final SessionWorld w;
  final out = <String, List<SessionEvent>>{};

  SessionEngine get engine => we.engine;

  void _emit(Iterable<String> ids, List<SessionEvent> evs) {
    if (evs.isEmpty) return;
    for (final id in ids) {
      out.putIfAbsent(id, () => []).addAll(evs);
    }
  }

  /// Guarda el resultado de [key] y comparte lo común con las demás.
  void put(String key, SessionStep step, {Iterable<String> also = const []}) {
    w.rooms[key] = step.state;
    _emit({...step.state.players.keys, ...also}, step.events);
    _share(key);
  }

  void _share(String from) {
    final src = w.rooms[from]!;
    for (final k in [...w.rooms.keys]) {
      if (k == from) continue;
      final o = w.rooms[k]!;
      final lost = !_same(o.lostLoot, src.lostLoot);
      if (identical(o.town, src.town) &&
          !lost &&
          identical(o.atlas, src.atlas) &&
          o.combatMode == src.combatMode &&
          o.turnTimer == src.turnTimer &&
          o.worldId == src.worldId &&
          o.worldName == src.worldName &&
          o.pausedBy == src.pausedBy &&
          o.pausedName == src.pausedName &&
          o.ownerId == src.ownerId) {
        continue;
      }
      final n = o.copy()
        ..town = src.town
        ..atlas = src.atlas
        ..combatMode = src.combatMode
        ..turnTimer = src.turnTimer
        ..worldId = src.worldId
        ..worldName = src.worldName
        ..pausedBy = src.pausedBy
        ..pausedName = src.pausedName
        ..ownerId = src.ownerId;
      if (lost) {
        n.lostLoot
          ..clear()
          ..addAll(src.lostLoot);
      }
      w.rooms[k] = n;
    }
  }

  static bool _same<T>(List<T> a, List<T> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i])) return false;
    }
    return true;
  }

  /// Una instancia nueva, vacía, con lo común del pueblo.
  GameSession _fresh(String? place) {
    var seq = 0;
    for (final r in w.rooms.values) {
      if (r.seq > seq) seq = r.seq;
    }
    final n = w.town.copy()
      ..mode = SessionMode.lobby
      ..mission = null
      ..battle = null
      ..vote = null
      ..prep = null
      ..result = null
      ..afterLevelUp = null
      ..eco = null
      ..ecoOwner = null
      ..trial = null
      ..abyss = null
      ..abyssOwner = null
      ..tutorial = null
      ..townEditor = null
      ..place = place
      ..seq = seq + 1;
    n.players.clear();
    n.ground.clear();
    n.leaveReady.clear();
    return n;
  }

  /// Pasa [p] y sus compañeros de [from] a [to].
  void _move(SessionPlayer p, String from, String to,
      {String? leave, String? arrive}) {
    final src = w.rooms[from]!;
    final group = [
      p,
      ...src.playerList.where((q) => q.leaderId == p.id),
    ];
    for (final q in group) {
      final first = identical(q, p);
      final r =
          engine.release(w.rooms[from]!, q.id, text: first ? leave : null);
      if (r != null) put(from, r, also: [q.id]);
      var dst = w.rooms[to]!;
      if (dst.seq < src.seq) dst = dst.copy()..seq = src.seq;
      final a = engine.admit(dst, q, text: first ? arrive : null);
      if (a != null) put(to, a);
    }
    _dropEmpty(from);
  }

  void _dropEmpty(String key) {
    if (key == kTownRoom) return;
    final r = w.rooms[key];
    if (r == null || r.players.isNotEmpty) return;
    // Sale el último: la mazmorra de zona queda guardada en el mundo
    // (persistent_dungeons.md § 2), no se descarta.
    if (SessionWorld.isDungeon(key) && r.mission != null) {
      w.rooms[key] = engine.parkDungeon(r);
      _share(key);
    }
    w.rooms.remove(key);
  }

  /// Sale solo de la mazmorra al exterior donde está su entrada (o al
  /// pueblo); la instancia sigue para los demás y se cierra si queda vacía.
  bool leave(String key, SessionPlayer p, int? poiId) {
    final s = w.rooms[key]!;
    if (!SessionWorld.isDungeon(key) ||
        !engine.canLeave(s, p.id, poiId: poiId)) {
      return false;
    }
    final place = s.place;
    final to = place ?? kTownRoom;
    w.rooms.putIfAbsent(to, () => _fresh(place)..instance = to);
    final zone = s.mission?.zone ?? 0;
    final label = we.placeLabel(w, to);
    _move(p, key, to,
        leave: '${p.name} salió de la mazmorra.',
        arrive: '${p.name} salió de la mazmorra.');
    // Aparece frente a la entrada de esa zona (si el lugar la tiene).
    final dst = w.rooms[to]!;
    final ent =
        engine.mapFor(dst).entrances.where((e) => e.zone == zone).firstOrNull;
    final q = dst.players[p.id];
    if (ent != null && q != null) {
      final n = dst.copy();
      n.players[p.id]!
        ..x = ent.front.x
        ..y = ent.front.y;
      w.rooms[to] = n;
    }
    _emit([p.id], [SystemMessageEvent('Volviste a $label.')]);
    return true;
  }

  /// IR CON [targetId] (free_movement.md § 2.5): pasa a [p] (y sus
  /// compañeros) a la instancia del otro, a su posición.
  bool join(String key, SessionPlayer p, String targetId) {
    final to = w.roomOf(targetId);
    if (to == null || to == key || p.isCompanion) return false;
    if (!WorldEngine.canJoin(w.rooms[key]!, w.rooms[to]!)) return false;
    final target = w.rooms[to]!.players[targetId];
    if (target == null || target.isCompanion) return false;
    _move(p, key, to,
        leave: '${p.name} fue con ${target.name}.', arrive: '${p.name} llegó.');
    final dst = w.rooms[to]!;
    if (!dst.players.containsKey(p.id)) return false;
    final n = dst.copy();
    for (final q in n.playerList) {
      if (q.id != p.id && q.leaderId != p.id) continue;
      q
        ..x = target.x
        ..y = target.y;
    }
    w.rooms[to] = n;
    return true;
  }

  bool travel(String key, SessionPlayer p, String place, {int? ecoZone}) {
    final s = w.rooms[key]!;
    final portal = ecoZone == null ? null : EcoPortalRules.of(ecoZone);
    if (ecoZone != null && portal?.biome != place) return false;
    if (s.mode != SessionMode.lobby ||
        s.run != null ||
        p.isCompanion ||
        SessionWorld.isDungeon(key) ||
        !BiomeRules.canTravelTo(place,
            unlockedZone: ZoneRules.unlockedZone(p.profile))) {
      return false;
    }
    final to = place == kPueblo ? kTownRoom : place;
    if (to == key && portal == null) return false;
    if (to != key) {
      w.rooms.putIfAbsent(
          to, () => _fresh(to == kTownRoom ? null : to)..instance = to);
      final name = biomeDef(place)?.name ?? place;
      _move(p, key, to,
          leave: '${p.name} viajó a $name.', arrive: '${p.name} llegó.');
    }
    // ECOS: frente al portal de esa zona (ecos_zone.md § 5).
    if (portal != null && w.rooms[to]!.players.containsKey(p.id)) {
      final n = w.rooms[to]!.copy();
      final f = portal.front;
      for (final q in n.playerList) {
        if (q.id != p.id && q.leaderId != p.id) continue;
        q
          ..x = f.x
          ..y = f.y
          ..moving = false;
      }
      w.rooms[to] = n;
    }
    return true;
  }

  /// ENTRAR: a la instancia de amigos que juegan lo mismo, o a una nueva.
  bool enter(String key, SessionPlayer p, SessionAction a) {
    final s = w.rooms[key]!;
    // Valida como si propusiera acá (sin guardar nada).
    final probe = engine.apply(s, p.id, a);
    if (probe == null) return false;
    final join = _joinable(a);
    if (join != null) {
      _move(p, key, join,
          leave: '${p.name} entró a ${we.placeLabel(w, join)}.',
          arrive: '${p.name} se sumó.');
      return true;
    }
    final to = 'd${w.nextDungeon++}';
    w.rooms[to] = _fresh(s.place)..instance = to;
    final (px, py) = (p.x, p.y);
    _move(p, key, to, leave: null);
    // Mismo lugar (p. ej. frente al portal de Ecos, ecos_zone.md § 4).
    if (w.rooms[to]!.players[p.id] case final q?) {
      q
        ..x = px
        ..y = py;
    }
    final ok = _start(to, p.id, a);
    if (!ok) {
      final back = w.rooms[to]!.players[p.id];
      if (back != null) _move(back, to, key);
      w.rooms.remove(to);
      return false;
    }
    if (w.rooms[key] case final src?) {
      _emit(src.players.keys,
          [SystemMessageEvent('${p.name} entró a ${we.placeLabel(w, to)}.')]);
    }
    return true;
  }

  /// Aplica la acción en la instancia nueva y resuelve sola la votación y
  /// el LISTO (es el único humano).
  bool _start(String key, String id, SessionAction a) {
    final s = w.rooms[key]!;
    final step = engine.apply(s, id, a);
    if (step == null) return false;
    put(key, step);
    for (var i = 0; i < 3; i++) {
      final r = w.rooms[key]!;
      if (r.mode == SessionMode.prep) {
        for (final h in r.playerList.where((q) => !q.isCompanion)) {
          final ready =
              engine.apply(w.rooms[key]!, h.id, const ReadyAction(true));
          if (ready != null) put(key, ready);
        }
      }
      if (r.mode != SessionMode.lobby && r.mode != SessionMode.prep) break;
      put(key, engine.tick(w.rooms[key]!, 0, world: false));
    }
    final r = w.rooms[key]!;
    return r.mode != SessionMode.lobby && r.mode != SessionMode.prep;
  }

  /// La instancia de mazmorra a la que se suma quien hace [a], o `null`.
  String? _joinable(SessionAction a) {
    for (final e in w.rooms.entries) {
      if (!SessionWorld.isDungeon(e.key)) continue;
      final r = e.value;
      final m = r.mission;
      if (m == null ||
          r.result != null ||
          r.tutorial != null ||
          r.run != null ||
          r.players.length >= engine.maxPlayers ||
          !(r.mode == SessionMode.field || r.mode == SessionMode.battle)) {
        continue;
      }
      final hit = switch (a) {
        ProposeMissionAction(:final missionId) =>
          m.missionId == missionId && r.eco == null,
        ProposeTrialAction(:final trial) =>
          m.missionId == TrialRules.missionId && r.trial == trial,
        ProposeAbyssAction(:final boss) =>
          m.missionId == AbyssRules.missionId && r.abyss == boss,
        _ => false,
      };
      if (hit) return e.key;
    }
    return null;
  }

  /// Cierra las mazmorras que volvieron al pueblo y los lugares vacíos;
  /// recalcula quién está en otro lado.
  WorldStep finish() {
    for (final k in [...w.rooms.keys]) {
      final r = w.rooms[k];
      if (r == null || k == kTownRoom) continue;
      if (SessionWorld.isDungeon(k) &&
          r.mode == SessionMode.lobby &&
          r.mission == null &&
          r.vote == null &&
          r.prep == null &&
          r.run == null) {
        for (final p in [...r.playerList.where((q) => !q.isCompanion)]) {
          if (!(w.rooms[k]?.players.containsKey(p.id) ?? false)) continue;
          _move(w.rooms[k]!.players[p.id]!, k, kTownRoom,
              arrive: '${p.name} volvió al pueblo.');
        }
        // Compañeros sueltos (sin líder en la instancia).
        for (final p in [...?w.rooms[k]?.playerList]) {
          if (!w.rooms.containsKey(k)) break;
          _move(p, k, kTownRoom);
        }
        w.rooms.remove(k);
        continue;
      }
      _dropEmpty(k);
    }
    _away();
    return WorldStep(out);
  }

  void _away() {
    if (!we.split) return;
    final where = <String, String>{};
    final ids = <String, String>{};
    final busy = <String, bool>{};
    final sig = StringBuffer();
    for (final e in w.rooms.entries) {
      final label = we.placeLabel(w, e.key);
      where[e.key] = label;
      ids[e.key] = we.placeId(w, e.key);
      busy[e.key] = !WorldEngine.canJoin(e.value, e.value);
      for (final p in e.value.playerList) {
        if (p.isCompanion) continue;
        sig.write(
            '${p.id}\u0001${p.name}\u0001$label\u0001${ids[e.key]}\u0001${busy[e.key]}\u0002');
      }
    }
    final key = sig.toString();
    if (key == w.awaySig) return;
    w.awaySig = key;
    for (final k in [...w.rooms.keys]) {
      final r = w.rooms[k]!;
      final away = [
        for (final e in w.rooms.entries)
          if (e.key != k)
            for (final p in e.value.playerList)
              if (!p.isCompanion)
                AwayPlayer(
                    p.id, p.name, where[e.key]!, ids[e.key]!, busy[e.key]!),
      ];
      w.rooms[k] = r.copy()..away = away;
    }
  }
}
