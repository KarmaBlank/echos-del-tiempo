import 'dart:math' as math;

import '../data/game_catalog.dart';
import '../data/items_catalog.dart';
import '../models/battle_command.dart';
import '../models/battle_event.dart';
import '../models/battle_state.dart';
import '../models/game_map.dart';
import '../models/game_session.dart';
import '../models/item.dart';
import '../models/loot.dart';
import '../models/loot_filter.dart';
import '../models/mission_def.dart';
import '../models/player_profile.dart';
import '../models/session_action.dart';
import '../models/session_event.dart';
import '../models/zone_def.dart';
import 'battle_engine.dart';
import 'inventory_rules.dart';
import 'js_math.dart';
import 'loot_filter_rules.dart';
import 'loot_rules.dart';
import 'map_generator.dart';
import 'mulberry32.dart';
import 'progression_rules.dart';
import 'world_rules.dart';
import 'zone_rules.dart';

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
    this.groundLoot = false,
  })  : _random = random ?? math.Random().nextDouble,
        _seeds = seeds ?? (() => math.Random().nextInt(1000000000));

  final BattleEngine battles;
  final ProgressionRules progression;
  final RandomSource _random;
  final SeedSource _seeds;

  /// Loot v2: con `true` el loot cae al piso del mapa (instanciado por
  /// jugador) y se levanta caminando encima o con E (`PickUpAction`).
  /// Con `false` (hoy, hasta que la UI dibuje el loot en el mapa) va
  /// directo al inventario y solo cae al piso si no hay lugar. Ver
  /// loot.md § 4.
  final bool groundLoot;

  GameCatalog get catalog => progression.catalog;

  final _filters = <String?, LootFilter>{};

  /// El filtro de loot de un perfil (texto → filtro, con caché).
  LootFilter filterOf(PlayerProfile p) => _filters.putIfAbsent(
      p.lootFilter, () => const LootFilterRules().fromProfileText(p.lootFilter));

  /// Cómo ve [p] un drop según su filtro (para la UI y el auto-levantar).
  FilterVerdict lootVerdict(PlayerProfile p, LootDrop d) =>
      LootFilterRules(catalog: catalog).evaluate(filterOf(p), d,
          FilterContext(
              level: p.level, attributes: p.attributes, classId: p.classId));

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

  /// Tocar la escalera de bajada (a menos de esto, px) baja al grupo.
  static const stairsTouch = 10.0;

  /// Distancia para levantar con E (`PickUpAction`).
  static const pickReach = 24.0;

  /// Tope de objetos en el piso (se pierden los más viejos).
  static const maxGround = 80;

  final Map<String, GameMap> _maps = {};

  // ------------------------------------------------------------------
  // API pública
  // ------------------------------------------------------------------

  /// Una sala vacía en el lobby.
  GameSession create() => GameSession();

  /// El mapa donde está la sesión (`mapFor`): el de la misión si hay
  /// una en curso (el atlas de pisos en misiones de zona), si no el mapa
  /// del mundo con el pueblo. Determinístico por semilla.
  GameMap mapFor(GameSession s) {
    final m = s.mission;
    if (m == null || s.mode == SessionMode.lobby) {
      return MapGenerator.overworld();
    }
    return _missionMap(catalog.mission(m.missionId)!, m.seed);
  }

  GameMap _missionMap(MissionDef def, int seed) {
    final key = '${def.id}:$seed';
    final hit = _maps[key];
    if (hit != null) return hit;
    if (_maps.length > 8) _maps.clear();
    return _maps[key] = def.zone == 0
        ? MapGenerator.generate(def, seed)
        : MapGenerator.zone(catalog.zone(def.zone)!, seed);
  }

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
    // Pausada: solo reanudar, chatear y lo que no toca el mundo (filtro de
    // loot, ordenar el inventario). Ver docs/specs/settings.md § "Pausa".
    if (session.paused &&
        action is! PauseAction &&
        action is! ChatAction &&
        action is! SetLootFilterAction &&
        action is! MoveInventoryAction) {
      return null;
    }
    final op = _Op(this, session.copy());
    return op.apply(op.s.players[playerId]!, action) ? op.result : null;
  }

  /// `hostTick`: avanza [dt] segundos. Con la sala pausada no avanza
  /// nada (ni reloj, ni misión, ni campo, ni turnos).
  SessionStep tick(GameSession session, double dt) {
    if (session.paused) return SessionStep(session, const []);
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
    final map = e.mapFor(s);
    final m = s.mission;
    final f = m == null ? null : map.floor(m.floor);
    return _around(f?.spawn ?? map.spawn, i);
  }

  static WorldPoint _around(WorldPoint sp, int i) =>
      WorldPoint(sp.x + (i % 2) * 14 - 7, sp.y + (i ~/ 2) * 14 - 7);

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
        if (s.mode != SessionMode.lobby ||
            s.vote != null ||
            m == null ||
            !ZoneRules.canPropose(catalog, p.profile, m.id)) {
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
        final before = p.profile;
        if (!_profileChange(
            p,
            rules.fuse(p.profile, a.baseWeaponId, a.sacrificeWeaponId,
                a.skillId))) {
          return false;
        }
        say('${p.name} fusionó '
            '${rules.weaponDisplayName(before, a.sacrificeWeaponId)} en '
            '${rules.weaponDisplayName(before, a.baseWeaponId)}: hereda '
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

      case CraftAction():
        return _craft(p, a);

      case GiveItemAction():
        return _give(p, a);

      case DropItemAction():
        return _drop(p, a);

      case PickUpAction():
        return _pickUp(p, a.groundId);

      case MoveInventoryAction():
        return _profileChange(
            p, InventoryRules.move(p.profile, a.from, a.to));

      case SetLootFilterAction():
        final t = a.text;
        if (t != null && t.length > SetLootFilterAction.maxLength) {
          return false;
        }
        p.profile = p.profile.copyWith(lootFilter: t, clearLootFilter: t == null);
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

      case PauseAction():
        // Pausa de grupo: cualquiera pausa, cualquiera reanuda.
        if (a.paused == s.paused) return false;
        if (a.paused) {
          s.pausedBy = p.id;
          s.pausedName = p.name;
          events.add(PausedEvent(p.id, p.name));
        } else {
          s.pausedBy = null;
          s.pausedName = null;
          events.add(ResumedEvent(p.id, p.name));
        }
        return true;

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

      case UseStairsAction():
        return _useStairs(p, a.down);
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

  // ---------------- loot v2: forja, inventario y piso ----------------

  String _dropText(LootDrop d) {
    final it = d.item;
    if (it == null) return '${d.count} ${d.stack!.label}';
    return '${rules.items.displayName(it)} (${it.rarity.label})';
  }

  bool _craft(SessionPlayer p, CraftAction a) {
    if (!s.canShop) return false;
    final before = p.profile;
    final r = rules.crafting.apply(before, a.op, a.targetUid,
        sourceUid: a.sourceUid,
        index: a.index,
        skillId: a.skillId,
        random: _rand);
    if (!_profileChange(p, r.profile)) return false;
    events.add(CraftedEvent(p.id, a.op, a.targetUid));
    final after = r.after;
    if (after != null) {
      say('${p.name}: ${rules.items.displayName(after)} '
          '(${_craftVerb(a.op)})');
    }
    return true;
  }

  static String _craftVerb(CraftOp op) => switch (op) {
        CraftOp.transferAffix => 'afijo trasladado',
        CraftOp.transferPassive => 'pasiva trasladada',
        CraftOp.transferSkill => 'habilidad trasladada',
        CraftOp.removeAffix => 'afijo quitado',
        CraftOp.addAffix => 'Cristal de Era: afijo nuevo',
        CraftOp.reroll => 'Esquirla del Eco: valores nuevos',
        CraftOp.upgradeRarity => 'Prisma Roto: rareza mejorada',
        CraftOp.reforge => 'base reforjada',
        _ => 'desarmada / vendida', // destruyen: sin `after`, no se anuncia
      };

  /// `GiveItemAction`: fuera de batalla, a otro jugador de la sala con
  /// lugar. El host valida todo; si no se puede, nada cambia.
  bool _give(SessionPlayer p, GiveItemAction a) {
    if (s.mode == SessionMode.battle) return false;
    final to = s.players[a.toPlayerId];
    if (to == null || to.id == p.id) return false;
    final t = rules.inventory.take(p.profile, a.token, count: a.count);
    final drop = t.drop;
    if (drop == null) return false;
    final got = rules.grant(to.profile, drop);
    if (got == null) return false;
    _profileChange(p, t.profile);
    _profileChange(to, got);
    events.add(ItemGivenEvent(p.id, to.id, drop));
    say('${p.name} le dio ${_dropText(drop)} a ${to.name}');
    return true;
  }

  bool get _onMap =>
      s.mode == SessionMode.lobby || s.mode == SessionMode.field;

  /// `DropItemAction`: al piso, compartido, donde está el jugador.
  bool _drop(SessionPlayer p, DropItemAction a) {
    if (!_onMap || !p.alive) return false;
    final t = rules.inventory.take(p.profile, a.token, count: a.count);
    final drop = t.drop;
    if (drop == null) return false;
    _profileChange(p, t.profile);
    _toGround(drop, p.x, p.y);
    say('${p.name} soltó ${_dropText(drop)}');
    return true;
  }

  /// `PickUpAction` (E): propio o compartido, cerca y con lugar.
  bool _pickUp(SessionPlayer p, int groundId) {
    if (!_onMap || !p.alive) return false;
    final g = s.ground.where((x) => x.id == groundId).firstOrNull;
    if (g == null ||
        !g.visibleTo(p.id) ||
        _dist(p.x, p.y, g.x, g.y) > SessionEngine.pickReach) {
      return false;
    }
    return _take(p, g);
  }

  bool _take(SessionPlayer p, GroundLoot g) {
    final next = rules.grant(p.profile, g.drop);
    if (next == null) return false;
    _profileChange(p, next);
    s.ground.remove(g);
    events.add(LootPickedEvent(p.id, g.id, g.drop));
    return true;
  }

  /// Deja [d] en el piso cerca de ([x], [y]); [owner] = loot instanciado.
  GroundLoot _toGround(LootDrop d, double x, double y, {String? owner}) {
    final id = ++s.groundSeq;
    // Desparramado en espiral, sin azar (determinístico).
    final ang = id * 2.4;
    final r = 6.0 + (id % 3) * 4;
    final g = GroundLoot(
      id: id,
      drop: d,
      x: x + math.cos(ang) * r,
      y: y + math.sin(ang) * r,
      ownerId: owner,
    );
    s.ground.add(g);
    if (s.ground.length > SessionEngine.maxGround) s.ground.removeAt(0);
    return g;
  }

  /// Entrega el loot de [p] (instanciado). Con `groundLoot` todo cae al
  /// piso; sin él va al inventario lo que su filtro muestra (lo oculto
  /// queda en el piso, invisible, y se pierde al cambiar de mapa) y lo
  /// que no entra cae al piso. El de fin de misión va siempre al
  /// inventario (el mapa se cierra). Un mensaje por jugador con lo visible.
  void _deliver(SessionPlayer p, List<LootDrop> drops, LootSource src,
      double x, double y) {
    if (drops.isEmpty) return;
    var full = false;
    final shown = <LootDrop>[];
    for (final d in drops) {
      final mission = src == LootSource.mission;
      final visible = mission || e.lootVerdict(p.profile, d).visible;
      if (visible) shown.add(d);
      if ((!e.groundLoot || mission) && visible) {
        final next = rules.grant(p.profile, d);
        if (next != null) {
          p.profile = next;
          events.add(LootDropEvent(p.id, d, src,
              uid: d.isItem ? next.items.last.uid : null));
          continue;
        }
        full = true;
      }
      final g = _toGround(d, x, y, owner: p.id);
      events.add(LootDropEvent(p.id, d, src, groundId: g.id));
    }
    if (shown.isEmpty) return;
    say('${p.name} obtuvo: ${shown.map(_dropText).join(', ')}'
        '${full ? ' (inventario lleno: quedó en el piso)' : ''}');
  }

  /// Tira y entrega el loot de [src] a cada jugador (loot por jugador),
  /// en ([x], [y]) o, sin posición, donde está cada uno. Devuelve la
  /// primera arma de cada uno (para los resultados).
  Map<String, LootDrop> _lootAll(LootSource src, double? x, double? y,
      {double? chance, double extraBonus = 0, int? level}) {
    final firsts = <String, LootDrop>{};
    final zone = level ?? s.mission?.zoneLevel ?? 1;
    for (final p in players) {
      final drops = rules.loot.rollDrops(_rand,
          zoneLevel: zone,
          source: src,
          family: p.profile.classId,
          chance: chance,
          extraBonus: extraBonus);
      final w = drops.where((d) => d.isItem).firstOrNull;
      if (w != null) firsts[p.id] = w;
      _deliver(p, drops, src, x ?? p.x, y ?? p.y);
    }
    return firsts;
  }

  /// Auto-levantar: cada jugador levanta su loot (no el compartido) al
  /// pasar encima, si su filtro lo muestra y tiene lugar.
  void _autoPickup() {
    if (s.ground.isEmpty) return;
    for (final g in [...s.ground]) {
      final owner = g.ownerId == null ? null : s.players[g.ownerId];
      if (owner == null ||
          !owner.alive ||
          _dist(owner.x, owner.y, g.x, g.y) >= SessionEngine.pickupRange ||
          !e.lootVerdict(owner.profile, g.drop).visible) {
        continue;
      }
      _take(owner, g);
    }
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

  // ---------------- pisos (worldgen.md § 6.7) ----------------

  bool _useStairs(SessionPlayer p, bool down) {
    final m = s.mission;
    if (s.mode != SessionMode.field || m == null || !p.alive) return false;
    final f = e.mapFor(s).floor(m.floor);
    final at = f == null ? null : (down ? f.stairsDown : f.stairsUp);
    if (at == null ||
        _dist(p.x, p.y, at.x, at.y) >= WorldRules.stairsRange) {
      return false;
    }
    changeFloor(m.floor + (down ? 1 : -1), down: down);
    return true;
  }

  /// Todo el grupo pasa al piso [to].
  void changeFloor(int to, {required bool down}) {
    final m = s.mission!;
    final f = e.mapFor(s).floor(to);
    if (f == null) return;
    m.floor = to;
    if (to < m.levels.length) m.zoneLevel = m.levels[to];
    final base = down ? f.spawn : (f.returnPoint ?? f.spawn);
    var i = 0;
    for (final p in players) {
      final pos = _around(base, i++);
      p
        ..x = pos.x
        ..y = pos.y
        ..epoch += 1
        ..moving = false;
      if (p.hp <= 0) p.hp = 1;
    }
    s.graceUntil = s.time + SessionEngine.missionStartGrace;
    events.add(FloorChangedEvent(to, down: down));
    final verb = down ? 'Bajaron' : 'Subieron';
    final boss = to == m.floors - 1 ? ' El jefe espera tras la barrera.' : '';
    say('$verb al piso ${to + 1}/${m.floors}.$boss');
  }

  /// Nivel de los enemigos de [en] (0 = misión sin zona).
  int _levelFor(FieldEnemy en) {
    final m = s.mission;
    final z = m == null || m.zone == 0 ? null : catalog.zone(m.zone);
    if (z == null) return 0;
    if (en.boss) return ZoneRules.bossLevel(z);
    if (en.elite) return ZoneRules.eliteLevel(z, en.floor);
    return ZoneRules.floorLevel(z, en.floor);
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
    final z = m.zone == 0 ? null : catalog.zone(m.zone);
    if (z != null) {
      _startZoneMission(m, z);
      return;
    }
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
      zoneLevel: LootRules.zoneLevel(m, [for (final p in players) p.profile.level]),
    );
    _enterField(m, seed);
  }

  /// `startMission` de una misión de zona: todos los pisos del atlas se
  /// pueblan al empezar (worldgen.md § 6.7).
  void _startZoneMission(MissionDef m, ZoneDef z) {
    final seed = e._seeds();
    final map = e._missionMap(m, seed);
    final r = mulberry32(seed + 7);
    int pick(int n) => (r() * n).floor();
    bool solid(int tx, int ty) => WorldRules.isSolid(map, tx, ty);
    List<String> res(List<String> g) => ZoneRules.resolveGroup(g, catalog);
    WorldPoint px((int, int) t) => WorldPoint(t.$1 * 16 + 8.0, t.$2 * 16 + 8.0);

    final enemies = <FieldEnemy>[];
    final goals = <int>[];
    var id = 0;
    for (final fl in map.floors) {
      final spots = fl.spots;
      final groups = m.groupsFor(fl.index);
      var placed = 0;
      for (var i = 0; i < m.floorGoal + 3; i++) {
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
              group: res(groups[pick(groups.length)]),
              floor: fl.index,
            ));
            placed++;
            break;
          }
        }
      }
      goals.add(math.min(m.floorGoal, placed));
    }
    final last = map.floors.last;
    final boss = last.boss!;
    enemies.add(FieldEnemy(
      id: id++,
      x: boss.x,
      y: boss.y,
      homeX: boss.x,
      homeY: boss.y,
      group: res(m.boss),
      boss: true,
      floor: last.index,
    ));

    final pool = ['frag', 'seal', 'elite'];
    final extras = <String>[];
    while (extras.length < m.extra) {
      extras.add(pool.removeAt(pick(pool.length)));
    }

    final items = <MissionItem>[];
    WorldPoint freeSpot(MapFloor fl, double minD) {
      final spots =
          fl.spots.isEmpty ? [(fl.bounds.cx, fl.bounds.cy)] : fl.spots;
      final sp = fl.spawn;
      for (var t = 0; t < 200; t++) {
        final q = px(spots[pick(spots.length)]);
        if (solid((q.x / 16).floor(), (q.y / 16).floor()) ||
            _dist(q.x, q.y, sp.x, sp.y) < 120) {
          continue;
        }
        if (items.any((it) => _dist(it.x, it.y, q.x, q.y) < minD) ||
            enemies.any((o) => _dist(o.x, o.y, q.x, q.y) < 40)) {
          continue;
        }
        return q;
      }
      return px(spots[pick(spots.length)]);
    }

    var iid = 0;
    void place(MissionItemKind k, int n, double minD) {
      for (var i = 0; i < n; i++) {
        final fl = map.floors[i % map.floors.length];
        final q = freeSpot(fl, minD);
        items.add(
            MissionItem(id: iid++, kind: k, x: q.x, y: q.y, floor: fl.index));
      }
    }

    final goal = goals.fold(0, (a, b) => a + b);
    final objectives = [MissionObjective(ObjectiveKind.kills, goal)];
    if (extras.contains('frag')) {
      place(MissionItemKind.fragment, 3, 90);
      objectives.add(MissionObjective(ObjectiveKind.fragments, 3));
    }
    if (extras.contains('seal')) {
      place(MissionItemKind.seal, 2, 140);
      objectives.add(MissionObjective(ObjectiveKind.seals, 2));
    }
    // Élites: uno opcional por piso (en la marca `e` de un vault si hay)
    // y otro en el último piso si salió el objetivo `elite`.
    void elite(MapFloor fl, int mark) {
      final q = mark < fl.eliteMarks.length
          ? px(fl.eliteMarks[mark])
          : freeSpot(fl, 80);
      final groups = m.groupsFor(fl.index);
      enemies.add(FieldEnemy(
        id: id++,
        x: q.x,
        y: q.y,
        homeX: q.x,
        homeY: q.y,
        group: res([m.elite, groups[pick(groups.length)].first]),
        elite: true,
        floor: fl.index,
      ));
    }

    for (final fl in map.floors) {
      elite(fl, 0);
    }
    if (extras.contains('elite')) {
      elite(last, 1);
      objectives.add(MissionObjective(ObjectiveKind.elite, 1));
    }
    for (final fl in map.floors) {
      for (final c in fl.chestMarks) {
        final q = px(c);
        items.add(MissionItem(
            id: iid++,
            kind: MissionItemKind.chest,
            x: q.x,
            y: q.y,
            floor: fl.index));
      }
      final n = 1 + pick(2);
      for (var i = 0; i < n; i++) {
        final q = freeSpot(fl, 70);
        items.add(MissionItem(
            id: iid++,
            kind: MissionItemKind.chest,
            x: q.x,
            y: q.y,
            floor: fl.index));
      }
    }

    s.mission = MissionRun(
      missionId: m.id,
      seed: seed,
      goal: goal,
      objectives: objectives,
      enemies: enemies,
      items: items,
      zoneLevel: map.floors.first.level,
      zone: z.index,
      floors: map.floors.length,
      floorGoals: goals,
      levels: [for (final fl in map.floors) fl.level],
    );
    _enterField(m, seed);
  }

  /// Fin común de `startMission`: jugadores al spawn, gracia y avisos.
  void _enterField(MissionDef m, int seed) {
    s.ground.clear();
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

  /// `updateOpen`: abre la barrera de cada piso despejado (escalera) y la
  /// del jefe cuando se cumplen todos los objetivos.
  void updateOpen() {
    final m = s.mission;
    if (m == null) return;
    for (var f = 0; f < m.floors - 1; f++) {
      if (m.opened.contains(f) || !m.floorCleared(f)) continue;
      m.opened.add(f);
      events
        ..add(StairsOpenedEvent(f))
        ..add(const GateOpenedEvent());
      say('¡Piso ${f + 1} despejado! Se abrió el paso a la escalera.');
    }
    if (m.open) return;
    final k = m.objective(ObjectiveKind.kills);
    if (k != null) k.count = m.kills;
    if (m.objectives.every((o) => o.done)) {
      m.open = true;
      events.add(const GateOpenedEvent());
      say('¡Objetivos cumplidos! La barrera del jefe se abrió.');
    }
  }

  MissionDef get _missionDef => catalog.mission(s.mission!.missionId)!;

  /// `openChest`: créditos y poción como el prototipo; el arma y los
  /// materiales salen del loot v2 (fuente `chest`, solo para quien lo
  /// abre).
  void openChest(SessionPlayer p, MissionItem chest) {
    final tier = _missionDef.chestTier;
    final cr = 20 + (_rand() * 31).floor() + tier * 10;
    var prof = p.profile.copyWith(credits: p.profile.credits + cr);
    var msg = '${p.name} abrió un cofre: +$cr créditos';
    BattleItem? item;
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
    p.profile = InventoryRules.relayout(prof);
    final drops = rules.loot.rollDrops(_rand,
        zoneLevel: s.mission!.zoneLevel,
        source: LootSource.chest,
        family: p.profile.classId);
    final weapon = drops.where((d) => d.isItem).firstOrNull?.item;
    events.add(
        ChestOpenedEvent(p.id, cr, item: item, weaponId: weapon?.baseId));
    say(msg);
    _deliver(p, drops, LootSource.chest, chest.x, chest.y);
  }

  /// `calmEnemies`.
  void calmEnemies() {
    final m = s.mission;
    if (m == null) return;
    for (final en in m.enemies) {
      if (!en.alive || en.boss || en.floor != m.floor) continue;
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
      if (it.done ||
          it.kind != MissionItemKind.fragment ||
          it.floor != m.floor) {
        continue;
      }
      final pl = _touching(it.x, it.y, SessionEngine.pickupRange);
      if (pl == null) continue;
      it.done = true;
      final o = _bump(ObjectiveKind.fragments);
      say('${pl.name} recogió un Fragmento de tiempo (${o?.count ?? 0}/3)');
      updateOpen();
    }
    for (final it in m.items) {
      if (it.done || it.kind != MissionItemKind.chest || it.floor != m.floor) {
        continue;
      }
      final pl = _touching(it.x, it.y, SessionEngine.pickupRange);
      if (pl == null) continue;
      it.done = true;
      openChest(pl, it);
    }
    _autoPickup();

    final map = e.mapFor(s);
    // Escalera de bajada: tocarla baja a todo el grupo.
    final down = map.floor(m.floor)?.stairsDown;
    if (down != null &&
        _touching(down.x, down.y, SessionEngine.stairsTouch) != null) {
      changeFloor(m.floor + 1, down: true);
      return;
    }
    for (final p in players) {
      p.mp = math.min(p.maxMp.toDouble(), p.mp + dt * 0.4);
      p.hp = math.min(p.maxHp.toDouble(), p.hp + p.maxHp * 0.008 * dt);
    }
    for (final en in m.enemies) {
      if (!en.alive || en.floor != m.floor) continue;
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
    final level = _levelFor(en);
    ZoneRules.scaleBattle(step.state, level);
    s.battle = SessionBattle(
      id: s.seq,
      state: step.state,
      fieldEnemyId: en.id,
      boss: en.boss,
      elite: en.elite,
      level: level,
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
    var evs = step.events;
    final won = step.state.outcome;
    if (b.level > 0 && won != null && won.victory && b.endTimer == null) {
      // XP por nivel de zona (worldgen.md § 6.3).
      final xp = ZoneRules.battleXp(won.xp, b.level);
      step.state
        ..outcome = BattleOutcome(victory: true, xp: xp, credits: won.credits)
        ..log = '¡Victoria! +$xp XP · +${won.credits} créditos para cada uno';
      evs = [
        for (final ev in evs)
          ev is BattleEndedEvent && ev.victory
              ? BattleEndedEvent(true, xp, won.credits)
              : ev,
      ];
    }
    b.state = step.state;
    if (evs.isNotEmpty) events.add(BattleStepEvent(evs));
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
    final fe = m.enemy(b.fieldEnemyId);
    fe?.alive = false;
    final lx = fe?.x ?? 0, ly = fe?.y ?? 0;
    final lootLevel = b.level > 0 ? b.level : null;
    if (b.elite) {
      m.elites++;
      _bump(ObjectiveKind.elite);
      final firsts = _lootAll(LootSource.elite, lx, ly, level: lootLevel);
      for (final d in firsts.entries) {
        final it = d.value.item!;
        m.eliteDrops.add(WeaponDrop(d.key, it.baseId, rarity: it.rarity));
        events.add(WeaponDropEvent(d.key, it.baseId, 'elite'));
      }
    } else if (b.boss) {
      _lootAll(LootSource.boss, lx, ly, level: lootLevel);
    } else {
      m.kills++;
      final k = m.objective(ObjectiveKind.kills);
      if (k != null) {
        events.add(ObjectiveProgressEvent(ObjectiveKind.kills, m.kills, k.goal));
      }
      _lootAll(LootSource.battle, lx, ly, level: lootLevel);
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
    // Bonus de rareza del arma de fin de misión según el rango.
    const rankBonus = {MissionRank.s: 1.0, MissionRank.a: 0.5};
    final pct = bonusPct[rank]!;
    final bonus = jsRound(m.credits * pct);
    final drops = <String, String>{};
    for (final p in players) {
      p.profile = p.profile.copyWith(credits: p.profile.credits + bonus);
      if (p.hp <= 0) p.hp = 1;
    }
    final zone = def.zone == 0 ? null : catalog.zone(def.zone);
    final unlocked = <String, int>{};
    if (ok) {
      final firsts = _lootAll(LootSource.mission, null, null,
          chance: dropChance[rank] ?? 0,
          extraBonus: rankBonus[rank] ?? 0,
          level: zone?.maxLevel);
      for (final d in firsts.entries) {
        drops[d.key] = d.value.item!.baseId;
        events.add(WeaponDropEvent(d.key, d.value.item!.baseId, 'mission'));
      }
      // Desbloqueo de la zona siguiente (worldgen.md § 6.4).
      if (zone != null && zone.index < ZoneRules.maxZone) {
        final next = catalog.zone(zone.index + 1);
        for (final p in players) {
          if (ZoneRules.unlockedZone(p.profile) != zone.index) continue;
          p.profile = p.profile.copyWith(unlockedZone: zone.index + 1);
          unlocked[p.id] = zone.index + 1;
          events.add(ZoneUnlockedEvent(p.id, zone.index + 1));
          if (next != null) {
            final soon = next.playable ? '' : ' · Próximamente';
            say('${p.name} desbloqueó ${next.name} (${next.levelText})$soon');
          }
        }
      }
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
      zone: def.zone,
      unlocked: Map.unmodifiable(unlocked),
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
    s.ground.clear();
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
