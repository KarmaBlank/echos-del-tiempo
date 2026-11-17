import 'dart:math' as math;

import '../data/game_catalog.dart';
import '../data/items_catalog.dart';
import '../models/battle_command.dart';
import '../models/battle_event.dart';
import '../models/battle_state.dart';
import '../models/game_map.dart';
import '../models/game_session.dart';
import '../models/mission_def.dart';
import '../models/player_profile.dart';
import '../models/session_action.dart';
import '../models/session_event.dart';
import 'battle_engine.dart';
import 'js_math.dart';
import 'map_generator.dart';
import 'mulberry32.dart';
import 'progression_rules.dart';
import 'world_rules.dart';

/// Genera la semilla de cada misión (`(Math.random() * 1e9) | 0`).
typedef SeedSource = int Function();

/// Resultado de un paso de la sesión: el estado nuevo y lo que pasó.
class SessionStep {
  final GameSession state;
  final List<SessionEvent> events;
  const SessionStep(this.state, this.events);
}

/// Reglas del host — puerto de `onMsg`, `addPlayer`, `hostTick`,
/// `fieldTick`, `battleTick`, `startMission`, `openChest`, `updateOpen`,
/// `calmEnemies`, `finishBattle`, `missionEnd` y `toLobby` del prototipo.
/// Specs: docs/specs/missions.md, world.md y progression.md.
///
/// Sin estado de juego propio (solo un caché de mapas, que son función
/// pura de la semilla): cada método recibe un [GameSession], trabaja
/// sobre una copia y devuelve un [SessionStep]. Orden de uso:
/// 1. [create] la sala y [addPlayer] por cada jugador que entra.
/// 2. [apply] con cada acción que llega de un jugador (`null` = rechazada).
/// 3. [tick] a ritmo fijo (el prototipo usa 50 ms) para avanzar el mundo,
///    la batalla y las transiciones de modo.
class SessionEngine {
  SessionEngine({
    required this.battles,
    required this.progression,
    RandomSource? random,
    SeedSource? seeds,
  })  : _random = random ?? math.Random().nextDouble,
        _seeds = seeds ?? (() => math.Random().nextInt(1000000000));

  final BattleEngine battles;
  final ProgressionRules progression;
  final RandomSource _random;
  final SeedSource _seeds;

  GameCatalog get catalog => progression.catalog;

  // ---- constantes del prototipo ----
  static const maxPlayers = 4;
  static const missionStartGrace = 2.5;
  static const battleGrace = 3.5; // GRACE_MS
  static const leash = 110.0; // LEASH
  static const aggroRange = 64.0;
  static const chaseSpeed = 34.0;
  static const returnSpeed = 36.0;
  static const wanderSpeed = 18.0;
  static const contactRange = 14.0;
  static const bossContactRange = 26.0;
  static const pickupRange = 14.0;
  static const sealRange = 30.0;
  static const calmRange = 120.0;
  static const turnLimit = 30.0; // TURN_LIMIT
  static const resultSeconds = 25.0;

  final Map<int, GameMap> _maps = {};
  GameMap? _lobby;

  // ------------------------------------------------------------------
  // API pública
  // ------------------------------------------------------------------

  /// Una sala vacía en el lobby.
  GameSession create() => GameSession();

  /// El mapa donde está la sesión (`mapFor`): el de la misión si hay
  /// una en curso, si no el lobby. Determinístico por semilla.
  GameMap mapFor(GameSession s) {
    final m = s.mission;
    if (m == null || s.mode == SessionMode.lobby) {
      return _lobby ??= MapGenerator.lobby();
    }
    return _missionMap(catalog.mission(m.missionId)!, m.seed);
  }

  GameMap _missionMap(MissionDef def, int seed) =>
      _maps[seed] ??= MapGenerator.generate(def, seed);

  /// `addPlayer`: entra un jugador con su perfil (se valida con
  /// `ProgressionRules.normalize`). `null` si la sala está llena o el id
  /// ya existe.
  SessionStep? addPlayer(GameSession session, String id, PlayerProfile profile) {
    if (session.players.length >= maxPlayers ||
        session.players.containsKey(id)) {
      return null;
    }
    final op = _Op(this, session.copy());
    op.addPlayer(id, profile);
    return op.result;
  }

  /// Un jugador se va de la sala. `null` si no estaba.
  SessionStep? removePlayer(GameSession session, String id) {
    if (!session.players.containsKey(id)) return null;
    final op = _Op(this, session.copy());
    op.removePlayer(id);
    return op.result;
  }

  /// `onMsg`: aplica la acción de [playerId]. `null` si no es válida en
  /// este momento (el estado no cambia).
  SessionStep? apply(GameSession session, String playerId, SessionAction action) {
    if (!session.players.containsKey(playerId)) return null;
    final op = _Op(this, session.copy());
    return op.apply(op.s.players[playerId]!, action) ? op.result : null;
  }

  /// `hostTick`: avanza [dt] segundos.
  SessionStep tick(GameSession session, double dt) {
    final op = _Op(this, session.copy());
    op.tick(dt);
    return op.result;
  }

  /// La entrada de un jugador al `BattleEngine` (vida en el campo
  /// redondeada hacia arriba, como la muestra el HUD).
  BattlePartyMember partyMember(SessionPlayer p) {
    final build = progression.buildOf(p.profile);
    return BattlePartyMember(
      id: p.id,
      name: p.name,
      build: build,
      hp: p.hp.ceil(),
      mp: p.mp,
      ult: p.ult,
      potions: p.profile.potions,
      ethers: p.profile.ethers,
      fusedSkillId: p.profile.fused[build.equippedWeapon.id],
    );
  }
}

/// Un paso de la sesión sobre una copia del estado (como `_Turn` en
/// `BattleEngine`).
class _Op {
  _Op(this.e, this.s);

  final SessionEngine e;
  final GameSession s;
  final events = <SessionEvent>[];

  SessionStep get result => SessionStep(s, List.unmodifiable(events));

  ProgressionRules get rules => e.progression;
  GameCatalog get catalog => e.catalog;
  double _rand() => e._random();
  Iterable<SessionPlayer> get players => s.players.values;

  void say(String text) => events.add(SystemMessageEvent(text));

  static double _dist(double ax, double ay, double bx, double by) =>
      WorldRules.distance(ax, ay, bx, by);

  // ---------------- jugadores ----------------

  WorldPoint spawnPos(int i) {
    final sp = e.mapFor(s).spawn;
    return WorldPoint(sp.x + (i % 2) * 14 - 7, sp.y + (i ~/ 2) * 14 - 7);
  }

  /// `stats(p)`: recalcula máximos. Con [gain], la vida y el maná actuales
  /// suben lo que subió el máximo; siempre se recortan al máximo nuevo.
  void refresh(SessionPlayer p, {bool gain = false}) {
    final oh = p.maxHp, om = p.maxMp;
    final d = rules.derivedStats(p.profile);
    p.maxHp = d.maxHp;
    p.maxMp = d.maxMp;
    p.hp = math.min(p.hp, d.maxHp.toDouble());
    p.mp = math.min(p.mp, d.maxMp.toDouble());
    if (gain) {
      p.hp += math.max(0, d.maxHp - oh);
      p.mp += math.max(0, d.maxMp - om);
    }
  }

  void fill(SessionPlayer p) {
    p.hp = p.maxHp.toDouble();
    p.mp = p.maxMp.toDouble();
  }

  void addPlayer(String id, PlayerProfile raw) {
    var profile = rules.normalize(raw);
    if (profile.name.isEmpty) profile = profile.copyWith(name: 'Héroe');
    final d = rules.derivedStats(profile);
    final sp = spawnPos(s.players.length);
    final p = SessionPlayer(
      id: id,
      profile: profile,
      x: sp.x,
      y: sp.y,
      hp: d.maxHp.toDouble(),
      mp: d.maxMp.toDouble(),
      maxHp: d.maxHp,
      maxMp: d.maxMp,
    );
    final b = s.battle;
    if (s.mode == SessionMode.battle && b != null) {
      b.state = e.battles.join(b.state, e.partyMember(p)).state;
    }
    s.players[id] = p;
    events.add(PlayerJoinedEvent(id));
    say('${profile.name} se unió a la sala.');
    if (raw.treeRefunded > 0) {
      // Migración del árbol (passive_tree_v2.md § 6): aviso único.
      say('${profile.name}: el árbol de pasivas cambió; se reinició gratis '
          'y recuperaste ${raw.treeRefunded} '
          'punto${raw.treeRefunded == 1 ? '' : 's'}.');
    }
  }

  void removePlayer(String id) {
    final p = s.players.remove(id)!;
    final b = s.battle;
    if (b != null) b.state = e.battles.leave(b.state, id).state;
    events.add(PlayerLeftEvent(id));
    say('${p.name} salió de la sala.');
  }

  // ---------------- acciones (`onMsg`) ----------------

  bool apply(SessionPlayer p, SessionAction a) {
    switch (a) {
      case MoveAction():
        if (a.epoch != p.epoch ||
            !(s.mode == SessionMode.lobby || s.mode == SessionMode.field) ||
            !p.alive) {
          return false;
        }
        if (a.x.isFinite && a.x != 0) p.x = a.x;
        if (a.y.isFinite && a.y != 0) p.y = a.y;
        p.dir = a.dir > 0 ? 1 : -1;
        p.moving = a.moving;
        return true;

      case ProposeMissionAction():
        final m = catalog.mission(a.missionId);
        if (s.mode != SessionMode.lobby || s.vote != null || m == null) {
          return false;
        }
        s.vote = MissionVote(m.id, p.name, {p.id});
        say('${p.name} propone: ${m.name}. ¡Voten!');
        return true;

      case VoteMissionAction():
        final v = s.vote;
        if (s.mode != SessionMode.lobby || v == null) return false;
        if (a.yes) {
          v.yes.add(p.id);
        } else {
          say('${p.name} rechazó la misión.');
          s.vote = null;
        }
        return true;

      case ReadyAction():
        final prep = s.prep;
        if (s.mode != SessionMode.prep || prep == null) return false;
        prep.ready[p.id] = a.ready;
        return true;

      case CancelPrepAction():
        if (s.mode != SessionMode.prep) return false;
        s.prep = null;
        s.mode = SessionMode.lobby;
        say('${p.name} canceló la preparación.');
        return true;

      case ActivateSealAction():
        return _activateSeal(p, a.itemId);

      case ChangeClassAction():
        if (s.mode != SessionMode.lobby) return false;
        return _profileChange(p, rules.changeClass(p.profile, a.classId),
            refill: true);

      case RespecAction():
        if (!rules.canRespec(s.mode)) return false;
        // Fuera del lobby / preparación no llena vida y maná.
        return _profileChange(p, rules.resetBuild(p.profile),
            refill: s.canShop);

      case AllocateStatsAction():
        if (s.mode == SessionMode.battle) return false;
        if (!_profileChange(p, rules.allocate(p.profile, a.add), gain: true)) {
          return false;
        }
        if (p.profile.points == 0) p.levelUpPending = false;
        return true;

      case EquipAction():
        if (!s.canShop) return false;
        return _profileChange(p, rules.equip(p.profile, a.weaponId));

      case TakeNodeAction():
        if (s.mode == SessionMode.battle) return false;
        if (!_profileChange(p, rules.takeNode(p.profile, a.nodeId),
            gain: true)) {
          return false;
        }
        final node = rules.treeRules.catalog.nodes[a.nodeId]!;
        if (node.kind == 'k') say('${p.name} tomó la keystone ${node.name}');
        return true;

      case ResetTreeAction():
        if (!rules.canRespec(s.mode)) return false;
        return _profileChange(p, rules.resetTree(p.profile));

      case FuseAction():
        if (!s.canShop) return false;
        if (!_profileChange(
            p,
            rules.fuse(p.profile, a.baseWeaponId, a.sacrificeWeaponId,
                a.skillId))) {
          return false;
        }
        say('${p.name} fusionó ${catalog.weapons[a.sacrificeWeaponId]!.name} '
            'en ${catalog.weapons[a.baseWeaponId]!.name}: hereda '
            '${catalog.skills[a.skillId]!.name}');
        return true;

      case UpgradeAction():
        if (!s.canShop) return false;
        if (!_profileChange(p, rules.upgrade(p.profile, a.weaponId, a.stat))) {
          return false;
        }
        say('${p.name} mejoró ${a.stat.label} de '
            '${rules.weaponDisplayName(p.profile, a.weaponId)}');
        return true;

      case BuyItemAction():
        if (!s.canShop) return false;
        return _profileChange(p, rules.buyItem(p.profile, a.item));

      case BuyWeaponAction():
        if (!s.canShop) return false;
        if (!_profileChange(p, rules.buyWeapon(p.profile, a.weaponId))) {
          return false;
        }
        say('${p.name} compró ${catalog.weapons[a.weaponId]!.name}');
        return true;

      case BattleAction():
        return _battleCommand(p, a.command);

      case ChatAction():
        // `case 'chat'`: en cualquier modo; el estado no cambia.
        final text = a.text.trim();
        if (text.isEmpty) return false;
        events.add(ChatMessageEvent(
            p.id,
            p.name,
            text.length > ChatAction.maxLength
                ? text.substring(0, ChatAction.maxLength)
                : text));
        return true;

      case BackToLobbyAction():
        if (s.mode != SessionMode.result) return false;
        toLobby();
        return true;
    }
  }

  bool _profileChange(SessionPlayer p, PlayerProfile? next,
      {bool gain = false, bool refill = false}) {
    if (next == null) return false;
    p.profile = next;
    refresh(p, gain: gain);
    if (refill) fill(p);
    return true;
  }

  bool _activateSeal(SessionPlayer p, int itemId) {
    final m = s.mission;
    if (s.mode != SessionMode.field || m == null) return false;
    final it = m.items
        .where((i) => i.id == itemId && i.kind == MissionItemKind.seal)
        .firstOrNull;
    if (it == null ||
        it.done ||
        _dist(p.x, p.y, it.x, it.y) >= SessionEngine.sealRange) {
      return false;
    }
    it.done = true;
    final o = _bump(ObjectiveKind.seals);
    say('${p.name} activó un sello (${o?.count ?? 0}/2)');
    updateOpen();
    return true;
  }

  MissionObjective? _bump(ObjectiveKind k) {
    final o = s.mission?.objective(k);
    if (o != null) {
      o.count++;
      events.add(ObjectiveProgressEvent(k, o.count, o.goal));
    }
    return o;
  }

  // ---------------- tick (`hostTick`) ----------------

  void tick(double dt) {
    s.time += dt;
    final m = s.mission;
    if (m != null &&
        (s.mode == SessionMode.field || s.mode == SessionMode.battle)) {
      m.elapsed += dt;
    }
    switch (s.mode) {
      case SessionMode.field:
        fieldTick(dt);
      case SessionMode.battle:
        battleTick(dt);
      case SessionMode.result:
        final r = s.result!;
        r.timeLeft -= dt;
        if (r.timeLeft <= 0) toLobby();
      case SessionMode.lobby:
        final v = s.vote;
        if (v != null &&
            s.players.isNotEmpty &&
            players.every((p) => v.yes.contains(p.id))) {
          s.prep = MissionPrep(v.missionId);
          s.vote = null;
          s.mode = SessionMode.prep;
          say('¡Misión aceptada! Fase de preparación: compren, mejoren y '
              'equípense. Empieza cuando todos estén listos.');
        }
      case SessionMode.prep:
        final prep = s.prep!;
        if (s.players.isNotEmpty &&
            players.every((p) => prep.ready[p.id] ?? false)) {
          s.prep = null;
          startMission(prep.missionId);
        }
      case SessionMode.levelUp:
        if (players.every((p) => !p.levelUpPending || p.profile.points <= 0)) {
          for (final p in players) {
            p.levelUpPending = false;
          }
          if (s.afterLevelUp == AfterLevelUp.result) {
            missionEnd(true);
          } else {
            _backToField();
          }
        }
    }
  }

  void _backToField() {
    s.mode = SessionMode.field;
    s.graceUntil = s.time + SessionEngine.battleGrace;
    calmEnemies();
  }

  // ---------------- misiones ----------------

  void startMission(String missionId) {
    s.vote = null;
    final m = catalog.mission(missionId);
    if (m == null) return;
    final seed = e._seeds();
    final map = e._missionMap(m, seed);
    final r = mulberry32(seed + 7);
    int pick(int n) => (r() * n).floor();
    bool solid(int tx, int ty) => WorldRules.isSolid(map, tx, ty);
    final spots = map.spots;

    final enemies = <FieldEnemy>[];
    var id = 0;
    for (var i = 0; i < m.goal + 9; i++) {
      for (var tries = 0; tries < 90; tries++) {
        if (spots.isEmpty) break;
        final (tx, ty) = spots[pick(spots.length)];
        final x = tx * 16 + 8.0, y = ty * 16 + 8.0;
        final minD = tries < 40
            ? 96
            : tries < 70
                ? 64
                : 40;
        if (!solid(tx, ty) &&
            !solid(tx, ty + 1) &&
            !solid(tx + 1, ty) &&
            !solid(tx - 1, ty) &&
            !enemies.any((o) => _dist(o.x, o.y, x, y) < minD)) {
          enemies.add(FieldEnemy(
            id: id++,
            x: x,
            y: y,
            homeX: x,
            homeY: y,
            group: m.groups[pick(m.groups.length)],
          ));
          break;
        }
      }
    }
    final goal = math.min(m.goal, enemies.length);
    final boss = map.boss!;
    enemies.add(FieldEnemy(
      id: id++,
      x: boss.x,
      y: boss.y,
      homeX: boss.x,
      homeY: boss.y,
      group: m.boss,
      boss: true,
    ));

    final pool = ['frag', 'seal', 'elite'];
    final extras = <String>[];
    while (extras.length < m.extra) {
      extras.add(pool.removeAt(pick(pool.length)));
    }

    final items = <MissionItem>[];
    final sp = map.spawn;
    WorldPoint freeSpot(double minD) {
      for (var t = 0; t < 200; t++) {
        final (tx, ty) = spots[pick(spots.length)];
        final x = tx * 16 + 8.0, y = ty * 16 + 8.0;
        if (solid(tx, ty) || _dist(x, y, sp.x, sp.y) < 120) continue;
        if (items.any((it) => _dist(it.x, it.y, x, y) < minD) ||
            enemies.any((o) => _dist(o.x, o.y, x, y) < 40)) {
          continue;
        }
        return WorldPoint(x, y);
      }
      final (tx, ty) = spots[pick(spots.length)];
      return WorldPoint(tx * 16 + 8.0, ty * 16 + 8.0);
    }

    var iid = 0;
    void place(MissionItemKind k, int n, double minD) {
      for (var i = 0; i < n; i++) {
        final q = freeSpot(minD);
        items.add(MissionItem(id: iid++, kind: k, x: q.x, y: q.y));
      }
    }

    final objectives = [MissionObjective(ObjectiveKind.kills, goal)];
    if (extras.contains('frag')) {
      place(MissionItemKind.fragment, 3, 90);
      objectives.add(MissionObjective(ObjectiveKind.fragments, 3));
    }
    if (extras.contains('seal')) {
      place(MissionItemKind.seal, 2, 140);
      objectives.add(MissionObjective(ObjectiveKind.seals, 2));
    }
    final nElite = extras.contains('elite') ? 2 : 1;
    for (var i = 0; i < nElite; i++) {
      final q = freeSpot(80);
      enemies.add(FieldEnemy(
        id: id++,
        x: q.x,
        y: q.y,
        homeX: q.x,
        homeY: q.y,
        group: [m.elite, m.groups[pick(m.groups.length)].first],
        elite: true,
      ));
    }
    if (extras.contains('elite')) {
      objectives.add(MissionObjective(ObjectiveKind.elite, 1));
    }
    place(MissionItemKind.chest, 2 + pick(3), 70);

    s.mission = MissionRun(
      missionId: m.id,
      seed: seed,
      goal: goal,
      objectives: objectives,
      enemies: enemies,
      items: items,
    );
    s.mode = SessionMode.field;
    var i = 0;
    for (final p in players) {
      final pos = spawnPos(i++);
      p
        ..x = pos.x
        ..y = pos.y
        ..epoch += 1
        ..ult = 0
        ..moving = false;
      fill(p);
    }
    s.graceUntil = s.time + SessionEngine.missionStartGrace;
    events.add(MissionStartedEvent(m.id, seed));
    say('¡Todos listos! Misión: ${m.name} [${m.type}]');
  }

  /// `updateOpen`: abre la barrera cuando se cumplen todos los objetivos.
  void updateOpen() {
    final m = s.mission;
    if (m == null || m.open) return;
    final k = m.objective(ObjectiveKind.kills);
    if (k != null) k.count = m.kills;
    if (m.objectives.every((o) => o.done)) {
      m.open = true;
      events.add(const GateOpenedEvent());
      say('¡Objetivos cumplidos! La barrera del jefe se abrió.');
    }
  }

  MissionDef get _missionDef => catalog.mission(s.mission!.missionId)!;

  int get _missionTier => catalog.missions.indexOf(_missionDef) + 1;

  /// Armas de la clase de [p] que no tiene y cumplen [tierOk], en el
  /// orden del catálogo (`Object.keys(WEAPONS)`).
  List<String> _weaponPool(SessionPlayer p, bool Function(int tier) tierOk) => [
        for (final w in catalog.weapons.values)
          if (w.classId == p.profile.classId &&
              tierOk(w.tier) &&
              !p.profile.inventory.contains(w.id))
            w.id,
      ];

  void _grantWeapon(SessionPlayer p, String weaponId) {
    p.profile = rules.grantWeapon(p.profile, weaponId);
  }

  /// `openChest`.
  void openChest(SessionPlayer p) {
    final tier = _missionDef.chestTier;
    final cr = 20 + (_rand() * 31).floor() + tier * 10;
    var prof = p.profile.copyWith(credits: p.profile.credits + cr);
    var msg = '${p.name} abrió un cofre: +$cr créditos';
    BattleItem? item;
    String? weapon;
    if (_rand() < 0.5) {
      prof = prof.copyWith(
          potions: math.min(ProgressionRules.maxItems, prof.potions + 1));
      item = BattleItem.potion;
    } else if (_rand() < 0.6) {
      prof = prof.copyWith(
          ethers: math.min(ProgressionRules.maxItems, prof.ethers + 1));
      item = BattleItem.ether;
    }
    if (item != null) msg += ' · +1 ${kItems[item]!.name}';
    p.profile = prof;
    if (_rand() < 0.12) {
      final pool = _weaponPool(p, (t) => t <= tier);
      if (pool.isNotEmpty) {
        weapon = pool[(_rand() * pool.length).floor()];
        _grantWeapon(p, weapon);
        msg += ' · ¡${catalog.weapons[weapon]!.name}!';
      }
    }
    events.add(ChestOpenedEvent(p.id, cr, item: item, weaponId: weapon));
    say(msg);
  }

  /// `calmEnemies`.
  void calmEnemies() {
    final m = s.mission;
    if (m == null) return;
    for (final en in m.enemies) {
      if (!en.alive || en.boss) continue;
      if (players.any((p) =>
          _dist(p.x, p.y, en.x, en.y) < SessionEngine.calmRange)) {
        en
          ..x = en.homeX
          ..y = en.homeY
          ..vx = 0
          ..vy = 0
          ..timer = 1.5;
      }
    }
  }

  // ---------------- campo (`fieldTick`) ----------------

  SessionPlayer? _touching(double x, double y, double range) => players
      .where((p) => p.alive && _dist(p.x, p.y, x, y) < range)
      .firstOrNull;

  void fieldTick(double dt) {
    final m = s.mission!;
    for (final it in m.items) {
      if (it.done || it.kind != MissionItemKind.fragment) continue;
      final pl = _touching(it.x, it.y, SessionEngine.pickupRange);
      if (pl == null) continue;
      it.done = true;
      final o = _bump(ObjectiveKind.fragments);
      say('${pl.name} recogió un Fragmento de tiempo (${o?.count ?? 0}/3)');
      updateOpen();
    }
    for (final it in m.items) {
      if (it.done || it.kind != MissionItemKind.chest) continue;
      final pl = _touching(it.x, it.y, SessionEngine.pickupRange);
      if (pl == null) continue;
      it.done = true;
      openChest(pl);
    }

    final map = e.mapFor(s);
    for (final p in players) {
      p.mp = math.min(p.maxMp.toDouble(), p.mp + dt * 0.4);
      p.hp = math.min(p.maxHp.toDouble(), p.hp + p.maxHp * 0.008 * dt);
    }
    for (final en in m.enemies) {
      if (!en.alive) continue;
      if (!en.boss) _enemyAi(en, map, dt);
      if (s.time > s.graceUntil) {
        final range =
            en.boss ? SessionEngine.bossContactRange : SessionEngine.contactRange;
        final p = _touching(en.x, en.y, range);
        if (p != null) {
          startBattle(en, p);
          return;
        }
      }
    }
  }

  void _enemyAi(FieldEnemy en, GameMap map, double dt) {
    final calm = s.time < s.graceUntil;
    final dh = _dist(en.x, en.y, en.homeX, en.homeY);
    SessionPlayer? near;
    var nd = double.infinity;
    for (final p in players) {
      if (!p.alive) continue;
      final d = _dist(p.x, p.y, en.x, en.y);
      if (d < nd) {
        nd = d;
        near = p;
      }
    }
    en.aggro = !calm &&
        near != null &&
        nd < SessionEngine.aggroRange &&
        _dist(near.x, near.y, en.homeX, en.homeY) < SessionEngine.leash;
    if (en.aggro) {
      final a = math.atan2(near!.y - en.y, near.x - en.x);
      en.vx = math.cos(a) * SessionEngine.chaseSpeed;
      en.vy = math.sin(a) * SessionEngine.chaseSpeed;
    } else if (dh > SessionEngine.leash * 0.6) {
      final a = math.atan2(en.homeY - en.y, en.homeX - en.x);
      en.vx = math.cos(a) * SessionEngine.returnSpeed;
      en.vy = math.sin(a) * SessionEngine.returnSpeed;
    } else {
      en.timer -= dt;
      if (en.timer <= 0) {
        en.timer = 1 + _rand() * 1.5;
        if (_rand() < 0.4) {
          en.vx = 0;
          en.vy = 0;
        } else {
          final a = _rand() * math.pi * 2;
          en.vx = math.cos(a) * SessionEngine.wanderSpeed;
          en.vy = math.sin(a) * SessionEngine.wanderSpeed;
        }
      }
    }
    final pos = WorldRules.move(map, en.x, en.y, en.vx * dt, en.vy * dt);
    en
      ..x = pos.x
      ..y = pos.y;
    if (en.vx.abs() > 1) en.dir = en.vx > 0 ? 1 : -1;
  }

  // ---------------- batalla ----------------

  void startBattle(FieldEnemy en, SessionPlayer trigger) {
    s.seq++;
    final step = e.battles.start(
      party: [for (final p in players) e.partyMember(p)],
      enemyTypes: en.group,
      elite: en.elite,
      triggeredBy: trigger.id,
    );
    s.battle = SessionBattle(
      id: s.seq,
      state: step.state,
      fieldEnemyId: en.id,
      boss: en.boss,
      elite: en.elite,
    );
    for (final p in players) {
      p
        ..epoch += 1
        ..moving = false;
    }
    s.mode = SessionMode.battle;
    events.add(BattleStartedEvent(s.seq, en.id, boss: en.boss, elite: en.elite));
  }

  bool _battleCommand(SessionPlayer p, BattleCommand cmd) {
    final b = s.battle;
    if (s.mode != SessionMode.battle ||
        b == null ||
        b.endTimer != null ||
        b.wait > 0) {
      return false;
    }
    final step = e.battles.command(b.state, p.id, cmd);
    if (step == null) return false;
    _applyBattleStep(b, step);
    if (b.endTimer == null) b.wait = cmd is UltimateCommand ? 2.3 : 0.8;
    return true;
  }

  /// Guarda el paso del motor, cuenta K.O. y detecta el fin.
  void _applyBattleStep(SessionBattle b, BattleStep step) {
    b.state = step.state;
    if (step.events.isNotEmpty) events.add(BattleStepEvent(step.events));
    final m = s.mission;
    final partyIds = {for (final c in step.state.party) c.id};
    for (final ev in step.events) {
      if (ev is KnockedOutEvent && partyIds.contains(ev.targetId) && m != null) {
        m.kos++;
      }
    }
    final outcome = step.state.outcome;
    if (outcome != null && b.endTimer == null) _onBattleOver(b, outcome);
  }

  /// `checkEnd`: reparto inmediato de XP/créditos y subida de nivel.
  void _onBattleOver(SessionBattle b, BattleOutcome outcome) {
    b.endTimer = outcome.victory ? 2.0 : 2.2;
    // Lo que cambió en la batalla vuelve a cada jugador.
    for (final p in players) {
      final c = b.state.party.where((c) => c.id == p.id).firstOrNull;
      if (c == null) continue;
      p
        ..hp = c.hp.toDouble()
        ..mp = c.mp
        ..ult = c.ult
        ..profile = p.profile.copyWith(potions: c.potions, ethers: c.ethers);
    }
    if (!outcome.victory) return;
    final m = s.mission;
    if (m != null) {
      m.xp += outcome.xp;
      m.credits += outcome.credits;
    }
    for (final p in players) {
      final g = rules.gainXp(
          p.profile.copyWith(credits: p.profile.credits + outcome.credits),
          outcome.xp);
      final oldLevel = p.profile.level;
      p.profile = g.profile;
      if (g.levelsGained > 0) {
        p.levelUpPending = true;
        refresh(p, gain: true);
        for (var l = oldLevel + 1; l <= g.profile.level; l++) {
          events.add(LevelUpEvent(p.id, l));
        }
      }
    }
  }

  /// `battleTick`.
  void battleTick(double dt) {
    final b = s.battle!;
    final end = b.endTimer;
    if (end != null) {
      b.endTimer = end - dt;
      if (b.endTimer! <= 0) finishBattle();
      return;
    }
    if (b.wait > 0) {
      b.wait -= dt;
      return;
    }
    final cur = b.state.current;
    if (cur != null && cur.isPlayer && !cur.alive) b.state.currentId = null;

    if (b.state.currentId == null) {
      final step = e.battles.nextTurn(b.state);
      _applyBattleStep(b, step);
      if (b.endTimer != null) return;
      b.turnTime = 0;
      final statusText = step.events.any((ev) =>
          (ev is DamageEvent && ev.fromStatus) ||
          ev is HealEvent ||
          ev is TurnSkippedEvent);
      if (statusText) b.wait = 0.9;
      final next = b.state.current;
      if (step.events.isNotEmpty && next == null) b.wait = 1.1;
      if (next != null && !next.isPlayer) b.wait = math.max(b.wait, 0.35);
      return;
    }

    if (!b.state.current!.isPlayer) {
      final step = e.battles.enemyTurn(b.state);
      if (step != null) _applyBattleStep(b, step);
      // ULT enemiga: la pausa de una ULT (cinemática); aviso: tiempo para
      // leer el cartel (docs/specs/break_and_enemy_ults.md § 2).
      final evs = step?.events ?? const <BattleEvent>[];
      if (b.endTimer == null) {
        b.wait = evs.any((ev) => ev is EnemyUltEvent)
            ? 2.3
            : evs.any((ev) => ev is EnemyUltWarningEvent)
                ? 1.4
                : 0.8;
      }
      return;
    }

    b.turnTime += dt;
    if (b.turnTime > SessionEngine.turnLimit) {
      final step = e.battles.timeout(b.state);
      if (step != null) _applyBattleStep(b, step);
      if (b.endTimer == null) b.wait = 0.8;
    }
  }

  /// `finishBattle`.
  void finishBattle() {
    final b = s.battle!;
    final victory = b.state.outcome?.victory ?? false;
    events.add(BattleFinishedEvent(victory));
    if (!victory) {
      missionEnd(false);
      return;
    }
    final m = s.mission!;
    m.enemy(b.fieldEnemyId)?.alive = false;
    if (b.elite) {
      m.elites++;
      _bump(ObjectiveKind.elite);
      final tier = math.min(3, _missionTier);
      for (final p in players) {
        final pool = _weaponPool(p, (t) => t >= 1 && t <= tier);
        if (pool.isEmpty || _rand() >= 0.6) continue;
        final w = pool[(_rand() * pool.length).floor()];
        _grantWeapon(p, w);
        m.eliteDrops.add(WeaponDrop(p.id, w));
        events.add(WeaponDropEvent(p.id, w, 'elite'));
        say('${p.name} obtuvo ${catalog.weapons[w]!.name} del élite');
      }
    } else if (!b.boss) {
      m.kills++;
      final k = m.objective(ObjectiveKind.kills);
      if (k != null) {
        events.add(ObjectiveProgressEvent(ObjectiveKind.kills, m.kills, k.goal));
      }
    }
    updateOpen();
    for (final p in players) {
      p.epoch++;
      if (p.hp <= 0) p.hp = 1;
      refresh(p);
    }
    s.battle = null;

    final pending =
        players.where((p) => p.levelUpPending && p.profile.points > 0).toList();
    if (pending.isNotEmpty) {
      s.mode = SessionMode.levelUp;
      s.afterLevelUp = b.boss ? AfterLevelUp.result : AfterLevelUp.field;
      say('¡Subida de nivel! Esperando a: '
          '${pending.map((p) => p.name).join(', ')}');
      return;
    }
    for (final p in players) {
      p.levelUpPending = false;
    }
    if (b.boss) {
      missionEnd(true);
      return;
    }
    _backToField();
  }

  /// `missionEnd`.
  void missionEnd(bool ok) {
    final def = _missionDef;
    final m = s.mission!;
    final t = m.elapsed;
    var rank = MissionRank.d;
    if (ok) {
      rank = t <= def.sTime && m.kos == 0
          ? MissionRank.s
          : t <= def.sTime * 1.5
              ? MissionRank.a
              : MissionRank.b;
    }
    const bonusPct = {
      MissionRank.s: 0.5,
      MissionRank.a: 0.25,
      MissionRank.b: 0.0,
      MissionRank.d: 0.0,
    };
    const dropChance = {MissionRank.s: 0.9, MissionRank.a: 0.7, MissionRank.b: 0.5};
    final pct = bonusPct[rank]!;
    final bonus = jsRound(m.credits * pct);
    final tier = _missionTier;
    final drops = <String, String>{};
    for (final p in players) {
      p.profile = p.profile.copyWith(credits: p.profile.credits + bonus);
      if (p.hp <= 0) p.hp = 1;
      if (!ok) continue;
      final pool = _weaponPool(p, (t) => t == tier);
      if (pool.isEmpty || _rand() >= (dropChance[rank] ?? 0)) continue;
      final w = pool[(_rand() * pool.length).floor()];
      _grantWeapon(p, w);
      drops[p.id] = w;
      events.add(WeaponDropEvent(p.id, w, 'mission'));
    }
    s.seq++;
    final result = MissionResult(
      id: s.seq,
      missionId: def.id,
      missionName: def.name,
      success: ok,
      rank: rank,
      time: t,
      xp: m.xp,
      credits: m.credits,
      bonus: bonus,
      bonusPercent: pct,
      kos: m.kos,
      elites: m.elites,
      eliteDrops: List.unmodifiable(m.eliteDrops),
      drops: Map.unmodifiable(drops),
      timeLeft: SessionEngine.resultSeconds,
    );
    s
      ..result = result
      ..battle = null
      ..mode = SessionMode.result;
    events.add(MissionEndedEvent(result));
  }

  /// `toLobby`.
  void toLobby() {
    s
      ..mode = SessionMode.lobby
      ..mission = null
      ..result = null
      ..battle = null
      ..vote = null
      ..prep = null
      ..afterLevelUp = null;
    var i = 0;
    for (final p in players) {
      final pos = spawnPos(i++);
      p
        ..levelUpPending = false
        ..x = pos.x
        ..y = pos.y
        ..epoch += 1;
      fill(p);
    }
    events.add(const ReturnedToLobbyEvent());
  }
}
