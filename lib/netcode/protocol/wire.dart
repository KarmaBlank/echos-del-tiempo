import 'dart:convert';

import '../../game_engine/data/game_catalog.dart';
import '../../game_engine/models/game_session.dart';
import '../../game_engine/models/player_profile.dart';
import '../../game_engine/models/session_action.dart';
import '../../game_engine/models/session_event.dart';
import '../../game_engine/models/tutorial.dart' show kTutorialVersion;
import '../../game_engine/serialization/action_json.dart';
import '../../game_engine/serialization/event_json.dart';
import '../../game_engine/serialization/json_read.dart';
import '../../game_engine/serialization/session_json.dart';

/// Versión del protocolo (`v` del `hello` / `welcome`). 10 desde v0.8.1
/// (Invocador: batalla `sum`, combatiente `smO` `smK` `smT` `smN`;
/// docs/specs/summoner.md § 6). 9 desde v0.8.0
/// (Jefes del Abismo: acciones `abyss` y `devAbyss`, evento `abyssDone`,
/// sesión `abyss` `abyssBy`, perfil `aby`, combatiente `abT` `abE` `abS`
/// `abSN` `abA` `abK` `abF` `abC`, materiales `mat:frag*` y
/// `mat:esencia`, operación de forja `essence`;
/// docs/specs/abyss_bosses.md § 5). 8 desde v0.7.0
/// (elementos y reacciones: estados `wet` / `charged`, eventos de
/// batalla `react` e `ice`, combatiente `fam` `brit` `frzR`;
/// docs/specs/elemental_reactions.md). 7 desde v0.6.0
/// (exploración: acción `poi`, eventos `poi` y `quest`, campos de misión
/// `pu` `ps` `qd` `qf` `bl` `wind` y de cofre `tr` `gd` `sc`;
/// docs/specs/worldgen.md § 11.6). 6 desde v0.5.1:
/// acción `wants` (resumen del plan de build para la condición `Build`
/// del filtro de loot; docs/specs/netcode.md § "Build y filtro").
/// 11 desde v0.8.5: el `state` lleva los perfiles aparte (`pp`) y solo
/// cuando cambian (netcode.md § "Perfiles solo cuando cambian").
/// 12 desde v0.8.6: el `state` lleva su número (`q`) y el cliente lo
/// confirma con `ack`; el host no manda más si hay muchos sin confirmar
/// (netcode.md § "Control de flujo").
/// 13 desde v0.9: combatiente `lv` (nivel del enemigo, para el tope por
/// golpe sin debilidad; combo_balance.md § 3.2).
/// 14 desde v0.9: `hello` con `tv` (`tutV` de la cuenta) y sesión con
/// `tut` / `tutN`, jugador `tv`, combatiente `prac`, acciones `tut`,
/// `tutOk`, `tutCtl` y evento `tutDone` (combat_tutorial.md § 6).
/// 15 desde v0.9.1: armas con `nq` (Quebrar reemplazado, loot.md
/// § 16.3), afijo `quebrantador` y habilidades con "Puede quebrar".
/// 16 desde v0.9.2: TUTORIAL con votación SIGUIENTE (`tutOk` = voto de
/// cada humano); `tut` lleva `v` (votos), `la` (último cartel) y `sd`
/// (conceptos explicados), sin `cl` (combat_tutorial.md § 4.1).
/// 17 desde v0.9.6: TUTORIAL rehecho: `tut` lleva `ph` (fase), `pk`
/// (votos de la votación abierta), `as` (roles elegidos), `nr`
/// (narrador de ENTRENAR) y `pr`; cartel con `h`; acción `tutPick`; sin
/// `f` (combat_tutorial.md § 4.4).
/// 18 desde v0.9.7: TUTORIAL sin roles: `tut` sin `as`; voto `repeat`
/// en vez de `roles`/`role:*` (combat_tutorial.md § 4.3).
/// 19 desde v0.9.8: perfil v4 con `nw` (marca NUEVO del inventario) y
/// acción `seen` (loot.md § 17.4).
/// 21 desde v0.12: acción `untake` (quitar un nodo del árbol;
/// progression_v2.md § 6.1).

/// 22 desde v0.12.1: acciones `stashPut` / `stashTake` y confirmaciones
/// `sk` del jugador en el snapshot (alijo en partida, characters.md § 3.2).
/// 23 desde v0.13: máximo de jugadores configurable (8 por defecto),
/// `mx` en `welcome` / `reject`, y balance de grupo para n > 4 con
/// topes (combo_balance.md § 3.3).

/// También en 23: acción `useItem` (pociones fuera de pelea, loot.md § 17.5).
/// 24 desde v0.14: Hazañas (achievements.md § 5.3): `ach` en el perfil,
/// acción `ach` (las que detecta el cliente) y evento `ach` `{p, id}`.
///
/// Es la secuencia de Ecos del Tiempo (Mundo). Travesía tiene la suya
/// ([kTravesiaProtocolVersion]); cada composition root elige [WireGame]
/// (docs/specs/netcode.md § "Un protocolo por juego"). El `g` del `hello`
/// es aditivo: un host 31 viejo lo ignora, así que Mundo sigue en 31.
/// 32 desde v0.20.8: Condensar con recetas nuevas (20 Esquirlas → 1
/// Cristal, 8 Cristales → 1 Prisma, materials_economy.md § 4.3) y el host
/// lo rechaza en la Travesía; un host 31 cobraría otra receta.
/// 33 desde v0.20.11: el loot propio que quedó en el piso vuelve al
/// alijo al cerrarse el mapa (confirmaciones `rec:N` en `sk`) y el piso
/// lleva `by` (quién soltó lo compartido); un cliente 32 lo perdería.
/// 34 desde v0.20.12: operación de fusión `restoreQuebrar` (loot.md
/// § 16.3.1); un host 33 no la conoce.
/// 35 desde v0.20.14: `tech` de una cura puede llevar `tg` = un enemigo
/// no muerto / espectro (bestiary.md § 1.4.1); un host 34 curaría.
/// 36 desde v0.20.15: ULT libres del arma (perfil `un`, `seen` con
/// `ult:<id>`, `ultimateOf` sin el arma; ultimates_v2.md § 2.1).
/// 37 desde v0.20.17: la confirmación `rec:N` puede llevar `bx` (lo que
/// el filtro oculta va a Objetos sin recoger, loot.md § 4b.1); un cliente
/// 36 lo mandaría al alijo y deduplicaría por uid, perdiendo armas.
/// 38 desde v0.20.20: el combatiente lleva `ubt` (carga de ULT extra del
/// turno, con tope) y la ronda (`act` / `rd`) cuenta también en la línea
/// de tiempo (aguanta una ronda, combat.md § "Límites").
/// 39 desde v0.20.22: tras la victoria el grupo sigue en el campo hasta
/// el LISTO de todos (`lr`, `leave`) y el pozo Loot perdido (`lost`).
/// 40 desde v0.20.23: modos de turno del RPG (turn_modes.md): `tr` puede
/// ser `porRonda` / `porFases` (con `ro` / `wt` en Por rondas), comandos
/// `wait` y `end`, y `cm` (modo de combate) en la sala. (El 39 es de
/// v0.20.22.)
/// 41 desde v0.21.0: pueblo nuevo sin overworld y mundos por cuenta
/// (town_loop.md § 2 y § 11c): la sala suma `wid` / `wname` (el mundo del
/// anfitrión) y el lobby es el mapa del pueblo (otros tiles, sin entradas
/// de zona: un cliente 40 dibujaría el mundo viejo y caminaría a puertas
/// que ya no existen).
/// 42 desde v0.22.0: pesca y agropecuario (fishing.md § 6): acciones
/// `fBite` / `fRes` / `fAuto` / `fSell` / `fSwap` / `rodBuy` / `rodEq`,
/// eventos `fBite` / `fCaught` y `life` en el perfil.
/// 43 desde v0.22.2: pesca en el mapa (fishing.md § 7): acción `fLn`
/// (caña, línea y boya a la vista) y `fl` en cada jugador del snapshot.
/// 44 (v0.23.0): huerta, ampliaciones del pueblo y árboles de oficios.
/// 45 (v0.24.0): edición del pueblo (town_editor.md § 8): `town` con
/// lados, construcciones y lagos propios.
/// 46 (v0.25.2): lugares fijos movibles (town_editor.md § 3.3): `town`
/// suma `marks` y `move` acepta `tg` = `@<lugar>`; un cliente 45 armaría
/// el pueblo con los lugares en su sitio de siempre.
/// 47 (v0.25.5): granjeros y pescadores con cofre por construcción
/// (farming.md § 8); se va la auto-pesca.
/// 48 (v0.26.0): mapa de viaje y exteriores de bioma (overworld_biomes.md):
/// `place` en el snapshot, `town.wild` y acciones `travel` / `forage`.
/// 49 (v0.27.0): día, noche y clima (`town.sky`), faros (`town.lt`),
/// nivel y mejoras de cada ayudante (`cr`), `helperUpgrade`, evento
/// `bolt` y materiales de oficio en el perfil (`life.cf`).
/// 50 (v0.28.0): candado de la edición del pueblo (town_editor.md § 1.3):
/// `ted` en el snapshot y `town` con `lock` / `unlock`.
/// 51 (v0.30.0): habitantes en el pueblo (overworld_biomes.md § 10):
/// `town.res`, casas (`k: casa`, `lv`, `rs`) y `town` con `invite` /
/// `assign` / `gift` / `turnIn` / `fulfil` / `invest` / `order`.
/// 52 (v0.31.0): roles de exploración: `town` con `fisherReq`, topes del
/// día en `town.dy`, Herrería y bestiario de pesca en el perfil
/// (`life.sx` / `life.st` / `life.lg`).
/// 53 (v0.32.0): encargos seguidos y vistos en el perfil (`trk`, `seen`)
/// y `town` con `track` / `seen` (roles.md § 8).
/// 54 (v0.32.2): faroles de las mazmorras oscuras (`PoiKind.lantern`,
/// tiles `l` / `n`): el mapa que sale de la semilla cambia.
/// 55 (v0.32.3): TALLER DE OFICIOS en el pueblo (landmark `@workshop`,
/// tile `O`) y ARMERÍA aparte de la FORJA (`@armory`, tile `R`): cambia
/// el plano del pueblo que arma cada par.
/// 56 (v0.32.6): lazos con los habitantes (`town.nat`) y `town` con
/// `talk` / `nativeInvite` / `nativeTrade` (overworld_biomes.md § 12).

/// 57 (v0.33.0): movimiento libre por jugador (free_movement.md): cada
/// cliente recibe solo su instancia, `aw` con los que están en otro lugar.
/// 58 (v0.34.0): mazmorras de zona persistentes por mundo y la acción
/// `offer` (Ofrenda del jefe; persistent_dungeons.md).
/// 59 (v0.35.0): Ecos por zona (ecos_zone.md): portales de Ecos en los
/// exteriores (cambia el plano de cada bioma), `travel` con `ez` y perfil
/// con `ezt` (tier completado por zona).
/// 60 (v0.37.0): Llama errante (lighting.md § 3.1.1): acción `wisp` y
/// `wi` en el jugador del snapshot.
/// 61 (v0.40.0): the battle log travels structured (`log` = key + args,
/// docs/specs/i18n.md § 3.5) so each player reads it in their language.
/// 62 (v0.41.0): boss/summon/support battle-log lines become keys
/// (i18n phase 4) and `NetException` carries a key.
/// 63 (v0.41.3): `aw` lleva la clave del destino (4.º campo) para marcar
/// dónde están los demás en el mostrador y el mapa de viaje
/// (free_movement.md § 3), si se puede IR CON él (5.º) y la acción
/// `joinP` (IR CON otro jugador, § 2.5).
/// 64 (v0.41.4): mission gatherings (free_movement.md § 2.1): `gat` in
/// the snapshot and the `gather` action (join / leave / go / cancel).
/// Also tank wards and per-phase damage on enemies (`wrd`, `phd`;
/// combat.md § "Tanques" and § "Nadie solo en una fase").
/// 65: action queue (turn_modes.md § 3.1): `q` in the battle snapshot
/// and the `uncmd` action.
/// 66: enemy Silence and player break (combat.md § "Silencio",
/// combo_balance.md § 5.4): `sil` on combatants; players carry `brk`,
/// `brkN`, `vul`, `brkS`.
/// 67: auto-fishing is back (fishing.md § 6): `fAuto {on?, r?}` action,
/// `fAutoOff {id, r, n}` event and the auto flag (4th field) in `fl`.
/// 68: residents move in (overworld_biomes.md § 10.1): `la` (walk-out
/// start on the room clock) in each resident.
/// 69: Prisa in the round modes (turn_modes.md § 4.2): `hn` in the
/// battle snapshot; Por fases may send `ro`.
/// 70: world events (world_events.md § 5): `wev` in the town, the
/// `riftGo` action and lore quest progress.
/// 71: mining and smithing (mining_smithing.md § 6): `ore` in the
/// profile life skills, `mine` and `smith` actions, `PoiKind.ore` and
/// mine places `mine:<biome>:<i>`.
/// 72: weather and seasons (weather_seasons.md): sky seed `sd`, baits,
/// crop log `cl`, bait actions.
/// 73: renown and town tier (renown_town_growth.md): `rn` in the town,
/// `tourney` session state, `tev`/`tourney` actions.
/// 74: cooking and meals (farming.md § 17): `ml`/`mlg`/`mb` in the farm
/// profile, `meal` in the battle build, FarmShopOp.cook/eat.
/// 75: event NPCs (world_events.md § 3.6): `dn` in `wev` and the
/// `wevAct` action.
/// 76: generated biome regions (biome_regions.md): the exterior layout
/// comes from the world seed, `town.ws` (activated waystones), the
/// `way` action and region forage kinds.
/// 77: mining v2 (mining_smithing.md § 1): dig-first levels (`mn` in the
/// town farm block), `mine` action ops, `mDug`/`mBomb`/`mBlast` events,
/// discovered veins and miner pick tiers.
/// 78: shared meals (farming.md § 19): `farmShop` ops `giveMeal` (with
/// `to`) and `feast`; meal orders and legendary meal extras.
/// 79: co-op action queue agreement (turn_modes.md § 3.1): the block's
/// commands wait until every pending human agrees the order (`qok`),
/// `qmv` reorders, `qr` in the battle snapshot.
/// 80: Echo fusion (ecos_atlas.md § 4.2): the `ecoFuse` action.
/// 81: profession-material gifts (share_materials.md): `giveLife` action.
/// 82: resident milestones (roles.md § 9): `town` op `claimMilestone`
/// and the `rcl` claimed mask in the profile.
/// 83: dungeon-entry gatherings (free_movement.md § 2.1.1): `lf` countdown
/// in `gat`, gathering kind `eco`.
/// 84: life trees v2 (life_trees_v2.md): new node ids, claimed rewards
/// `life.lc` in the profile.
/// 85: ascension tree v2 (ascension.md § 3): build `ms` (Echoes Mastery)
/// and the tree version `v` in `asc`.
/// 86: biome exploration v2 (biome_exploration.md): 150 × 112 regions with
/// wilds, `town.lv`, the `wx` action and deep exploration events.
/// 87: lake rafts (fishing.md § 15): the `raft` action and `rf` in the
/// player snapshot.
/// 88: player stall (player_shop.md): `stall` action (StallAction) and
/// `life.ps` in the profile.
/// 89: wilds loot `town.daily` keys carry the layout version
/// (`wx:<player>:<biome>:v<n>:<c|s><i>:<day>`); an 88 peer would read
/// the marks of a regenerated layout on the wrong spots.
/// 90: overworld map discovery (biome_exploration.md § 11.4): `town.md`
/// (biome → cell bits; the room snapshot carries only the current biome).
/// 91: cozy life (cozy_life.md): the `cozy` action (tree search, raft
/// decorations, compost), `town.dc` farm decorations and `life.rd` /
/// `life.ro` / `life.ff` / `life.farm.rc` in the profile.
/// 92: profession gear (profession_gear.md): `SmithOp.fishForge`, living
/// weapon plots (`cp` composts, `it` held item), `farm.ws` weapon seeds,
/// meal `b` / `a` boosts, `gear-` uid marks and life tree v2 forks
/// (`life.tv`, `life.rf` refund notice).
/// 93: profession gear v2 (profession_gear_v2.md § 7): `SmithOp.forgeParts`
/// (`b` type, `g` base ingot, `p` parts) and `SmithOp.fishSplit`; items
/// carry `pt` (parts) and `mw` (masterwork); fish parts `fp_*` in `ore`;
/// living weapon seeds for every type but the rifle.
/// 94: biome layout v4 (biome_exploration.md § 7): every world's exteriors
/// regenerate; wilds / tree-search keys carry `v4`, so a 92 peer would
/// read today's marks under `v3` and see used spots as fresh.
/// 95: dungeon map discovery (biome_exploration.md § 11.8): `mission.md`
/// (packed cell bits of the mission map) and `mission.mdr` (revision).
/// 96: overworld ground loot (loot.md § 4c): `LootDrop` goods (`gd` +
/// `n`: gold, ore, crops, seeds…) on the floor of biomes, mines and the
/// town; wilds chests, shrines, mine and sunken chests and harvests
/// spill them instead of granting silently.
/// 97: no mission gathering (v0.49.20, free_movement.md § 2.1): the
/// `gather` action and `gat` in the snapshot are gone; PROPONER enters at
/// once and friends join with UNIRSE on the player's card.
/// 98: rune fountain onboarding (town_editor.md § 1.5): `TownOp.seen`
/// with id `~fountain` stores the first visit in `npcSeen`.
const kProtocolVersion = 98;

/// Protocolo de Ecos del Tiempo: Travesía (secuencia propia). 1: `run` en
/// el snapshot, acciones `runStart` / `runVote` / `runReward` /
/// `runReady` y eventos `runNode` / `runEnd` (roguelike.md). 2: turnos
/// porBando en la batalla (`tr` / `gp` / `act` / `rd`) y fila ULT en la
/// recompensa (`u` en la oferta y en `runReward`). 3: mejoras, loadout,
/// dificultad y élites (roguelike.md § 12.1). 4: sin niveles en la run
/// (el snapshot ya no manda `gl`; maná lleno al empezar cada pelea),
/// roguelike.md § 12.2. 5: structured battle log (`log` = key + args,
/// i18n.md § 3.5). 6: remaining battle-log lines keyed (i18n phase 4).
const kTravesiaProtocolVersion = 6;

/// Qué juego habla por la red y con qué versión de protocolo. Lo decide
/// el composition root (`GameEdition.wire`); la sesión nunca mira el
/// nombre del flavor.
class WireGame {
  const WireGame(this.id, this.protocol, this.title);

  /// `g` del `hello` / `reject`.
  final String id;

  /// `v` del `hello` / `welcome`.
  final int protocol;

  /// Nombre para el jugador.
  final String title;

  static const mundo = WireGame('mundo', kProtocolVersion, 'Ecos del Tiempo');
  static const travesia = WireGame(
      'travesia', kTravesiaProtocolVersion, 'Ecos del Tiempo: Travesía');

  /// Título de un id recibido (desconocido: el id tal cual).
  static String titleOf(String id) => switch (id) {
        'mundo' => mundo.title,
        'travesia' => travesia.title,
        _ => id,
      };
}

/// Un mensaje del protocolo (docs/specs/netcode.md § "Protocolo").
sealed class WireMessage {
  const WireMessage();
}

/// cliente → host: `{"t":"hello","v":1,"p":<perfil>,"b":<hash>}`.
class HelloMessage extends WireMessage {
  const HelloMessage(this.profile,
      {this.version = kProtocolVersion,
      this.balance,
      this.tutorialVersion = kTutorialVersion,
      this.game = 'mundo'});
  final PlayerProfile profile;
  final int version;

  /// `g`: id del juego del cliente ([WireGame.id]). `null` = cliente
  /// anterior a la separación de juegos (siempre Mundo, y no conoce el
  /// motivo `game` del `reject`).
  final String? game;

  /// Hash del parche de balance del cliente (`GameCatalog.balanceHash`,
  /// docs/specs/balance_admin.md § 4). `null` = cliente anterior al
  /// balance por archivo (equivale a sin parche).
  final String? balance;

  /// `tv`: la `tutV` de la cuenta (docs/specs/combat_tutorial.md § 2).
  final int tutorialVersion;
}

/// host → cliente: `{"t":"welcome","v":1,"id":"p1","code":"ABCDE"}`.
class WelcomeMessage extends WireMessage {
  const WelcomeMessage(this.id, this.code,
      {this.version = kProtocolVersion, this.max});
  final String id;

  /// `mx`: máximo de jugadores de la sala (v0.13, protocolo 23).
  final int? max;
  final String code;
  final int version;
}

/// Por qué el host rechaza a un cliente.
enum RejectReason {
  full('La sala está llena.'),
  version('El host usa otra versión del juego.'),
  balance('El host tiene otro parche de balance: actualizá el juego.'),
  game('Esa sala es de otro juego.');

  const RejectReason(this.message);
  final String message;
}

/// Si el host rechaza a un cliente por el parche de balance (§ 4 de
/// docs/specs/balance_admin.md). Un cliente sin hash ([client] `null`,
/// versión anterior) cuenta como sin parche y se le contesta `version`
/// (no conoce el motivo `balance`).
RejectReason? balanceReject(String? client, String host) {
  final mine = client ?? GameCatalog.baseBalanceHash;
  if (mine == host) return null;
  return client == null ? RejectReason.version : RejectReason.balance;
}

/// host → cliente: `{"t":"reject","why":"full"}` (y cierra).
class RejectMessage extends WireMessage {
  const RejectMessage(this.reason, {this.max, this.game});
  final RejectReason reason;

  /// `g`: juego del host, para el texto del motivo `game`.
  final String? game;

  /// `mx`: máximo de la sala (v0.13), para el texto de sala llena.
  final int? max;

  /// Lo que ve el jugador rechazado.
  String get text => reason == RejectReason.full && max != null
      ? 'La sala está llena (máx. $max jugadores).'
      : reason == RejectReason.game && game != null
          ? 'Esa sala es de «${WireGame.titleOf(game!)}»; desde este juego '
              'no se puede entrar.'
          : reason.message;
}

/// cliente → host: cualquier `SessionAction` (`{"t":"pos",...}`...).
class ActionMessage extends WireMessage {
  const ActionMessage(this.action);
  final SessionAction action;
}

/// host → cliente: `{"t":"state","s":<GameSession>,"ev":[...]}`.
class StateMessage extends WireMessage {
  const StateMessage(this.session, this.events, {this.seq});
  final GameSession session;
  final List<SessionEvent> events;

  /// Número del `state` (`q`); el cliente lo devuelve en un [AckMessage].
  final int? seq;
}

/// cliente → host: `{"t":"ack","q":12}`: llegó el `state` número [seq]
/// (control de flujo, netcode.md § "Control de flujo"). No es una acción.
class AckMessage extends WireMessage {
  const AckMessage(this.seq);
  final int seq;
}

/// Cualquiera de los dos lados: `{"t":"ping","ts":123456}`. [ts] son
/// microsegundos del reloj de quien lo manda; el otro lo devuelve igual
/// en un [PongMessage] (docs/specs/netcode.md § "Ping"). No es una
/// acción: nunca toca el estado de la sala.
class PingMessage extends WireMessage {
  const PingMessage(this.ts);
  final int ts;
}

/// Respuesta a un [PingMessage]: `{"t":"pong","ts":123456}`.
class PongMessage extends WireMessage {
  const PongMessage(this.ts);
  final int ts;
}

/// Codifica / decodifica mensajes del protocolo como texto JSON.
class WireCodec {
  WireCodec([GameCatalog catalog = GameCatalog.standard])
      : session = SessionJson(catalog),
        events = EventJson(SessionJson(catalog));

  final SessionJson session;
  final EventJson events;

  String encode(WireMessage m) => jsonEncode(switch (m) {
        HelloMessage() => {
            't': 'hello',
            'v': m.version,
            'p': m.profile.toJson(),
            if (m.balance != null) 'b': m.balance,
            'tv': m.tutorialVersion,
            if (m.game != null) 'g': m.game,
          },
        WelcomeMessage() => {
            't': 'welcome',
            'v': m.version,
            'id': m.id,
            'code': m.code,
            if (m.max != null) 'mx': m.max,
          },
        RejectMessage() => {
            't': 'reject',
            'why': m.reason.name,
            if (m.max != null) 'mx': m.max,
            if (m.game != null) 'g': m.game,
          },
        PingMessage() => {'t': 'ping', 'ts': m.ts},
        PongMessage() => {'t': 'pong', 'ts': m.ts},
        AckMessage() => {'t': 'ack', 'q': m.seq},
        ActionMessage() => ActionJson.toJson(m.action),
        StateMessage() => {
            't': 'state',
            if (m.seq != null) 'q': m.seq,
            's': session.toJson(m.session),
            'ev': [for (final e in m.events) events.toJson(e)],
          },
      });

  /// El `state` que manda el host desde el protocolo 11: los jugadores
  /// sin su perfil y, aparte en `pp`, solo los perfiles de [profiles]
  /// (id → perfil ya en JSON) que este cliente todavía no tiene. [body] y
  /// [events] se codifican una vez con [stateBody] / [stateEvents] y se
  /// reusan para todos los clientes.
  static String stateText(
      String body, String events, Map<String, String> profiles,
      {int? seq}) {
    final b = StringBuffer('{"t":"state",')
      ..write(seq == null ? '' : '"q":$seq,')
      ..write('"s":')
      ..write(body)
      ..write(',"ev":')
      ..write(events);
    if (profiles.isNotEmpty) {
      b.write(',"pp":{');
      var first = true;
      for (final e in profiles.entries) {
        if (!first) b.write(',');
        first = false;
        b
          ..write(jsonEncode(e.key))
          ..write(':')
          ..write(e.value);
      }
      b.write('}');
    }
    b.write('}');
    return b.toString();
  }

  /// La sesión sin los perfiles de los jugadores, ya en texto.
  String stateBody(GameSession s) => jsonEncode(session.toJson(s, profiles: false));

  /// Los eventos del `state`, ya en texto.
  String stateEvents(List<SessionEvent> ev) =>
      jsonEncode([for (final e in ev) events.toJson(e)]);

  /// `null` si el texto no es un mensaje válido (se ignora, como hace el
  /// `switch` de `onMsg` con un `t` desconocido).
  ///
  /// [profiles]: el cache de perfiles del cliente (id → perfil en JSON).
  /// Un `state` suma ahí los de su `pp`, y un jugador que viene sin `p`
  /// toma el del cache; si no está, el mensaje es inválido (`null`).
  WireMessage? decode(String text, {Map<String, Object?>? profiles}) {
    try {
      final j = asJson(jsonDecode(text));
      switch (j.str('t')) {
        case 'hello':
          return HelloMessage(PlayerProfile.fromJson(j.obj('p')),
              version: j.integer('v'),
              balance: j.strOrNull('b'),
              tutorialVersion: j.intOrNull('tv') ?? 0,
              game: j.strOrNull('g'));
        case 'welcome':
          return WelcomeMessage(j.str('id'), j.str('code'),
              version: j.integer('v'), max: j.intOrNull('mx'));
        case 'reject':
          return RejectMessage(j.enumByName('why', RejectReason.values),
              max: j.intOrNull('mx'), game: j.strOrNull('g'));
        case 'ping':
          return PingMessage(j.integer('ts'));
        case 'pong':
          return PongMessage(j.integer('ts'));
        case 'ack':
          return AckMessage(j.integer('q'));
        case 'state':
          final s = j.obj('s');
          final known = profiles ?? <String, Object?>{};
          final pp = j.objOrNull('pp');
          if (pp != null) known.addAll(pp);
          for (final raw in s.list('players')) {
            final p = asJson(raw);
            if (p['p'] != null) continue;
            final cached = known[p.str('id')];
            if (cached == null) return null;
            p['p'] = cached;
          }
          return StateMessage(
            session.fromJson(s),
            List.unmodifiable([
              for (final raw in j.list('ev')) events.fromJson(asJson(raw)),
            ]),
            seq: j.intOrNull('q'),
          );
        default:
          return ActionMessage(ActionJson.fromJson(j));
      }
    } on Object {
      return null;
    }
  }
}
