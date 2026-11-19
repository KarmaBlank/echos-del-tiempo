# Spec: Red (contrato, protocolo y transportes)

Fuente de verdad: prototipo `ecos-del-tiempo.html`, sección `RED`
(líneas 492-555: `send`, `broadcast`, `randCode`, `startHost`,
`startJoin`), `onMsg` y `addPlayer` (556-605), el envío de posición de
`updateMe` (línea 950) y el consumo de `view` en el cliente
(`d.t==='state'`, línea 545).

## Por qué existe esta capa

`features/*` y `game_engine` nunca importan `flutter_webrtc`,
`cloud_firestore`, `dart:io` ni ningún paquete de red. Todo pasa por
`NetSession` (`lib/netcode/contracts/net_session.dart`). Así se arman
varias "versiones" del mismo juego (LAN, P2P por internet, servidor
dedicado a futuro) cambiando solo qué implementación inyecta el
composition root (`lib/app/flavors/main_*.dart`).

`game_engine` no conoce la red; la red sí conoce los modelos de
`game_engine` (`GameSession`, `SessionAction`, `SessionEvent`,
`PlayerProfile`), que son Dart puro y viajan serializados a JSON
(`lib/game_engine/serialization/*`).

## Modelo (igual que el prototipo)

- **Host autoritativo.** El host corre `SessionEngine` (las reglas de
  `onMsg`/`hostTick`); los clientes nunca corren reglas.
- El cliente manda **acciones** (`SessionAction`) y **su propia
  posición** (`MoveAction`, cada 50 ms, redondeada a 0.1 px).
- El host avanza el mundo cada **50 ms** (`setInterval(hostTick, 50)`) y
  manda el **snapshot completo** de `GameSession` cada **66 ms**
  (`setInterval(broadcast({t:'state',s:S}), 66)`), junto con los
  eventos (`SessionEvent`) ocurridos desde el snapshot anterior.
- El cliente **adopta el snapshot entero salvo su propia posición**
  (regla de la época): mueve a su jugador localmente con
  `WorldRules.stepPlayer` y solo adopta `x, y` del snapshot cuando la
  `epoch` de su jugador cambió (teletransporte del host). El host
  descarta `MoveAction` con una época vieja.
- **Confianza:** el host confía en la posición que manda cada cliente
  (como el prototipo; no hay anti-trampas) y en el perfil que manda al
  unirse (lo valida con `ProgressionRules.normalize`, como `addPlayer`).
- Ids: el host es `h`; los clientes `p1`, `p2`... en orden de conexión
  (`'p'+(nextPid++)`). Sin red (sesión local de un jugador) el id es
  `local`.
- Máximo **4** jugadores contando al host (`MAXP`): el quinto recibe
  `reject full` y se le cierra la conexión.

## Contrato (`lib/netcode/contracts/`)

`NetSession` (un objeto por sala; no se reutiliza después de
`disconnect`):

| Miembro | Quién | Qué hace |
|---|---|---|
| `connect(SessionConfig)` | ambos | `roomCode == null` → crea sala (host); si no, se une. Completa cuando la sala está abierta (host) o cuando llegó `welcome` (cliente). Falla con `NetException(mensaje para el jugador)`. |
| `isHost`, `localId`, `roomCode` | ambos | Rol, id propio (`h` / el del `welcome`) y código de la sala. |
| `events` | ambos | `Stream<NetEvent>` de **una sola suscripción** (el controlador de la sesión): guarda lo que llega hasta que alguien escucha, así no se pierde nada entre `connect` y que se abra la pantalla del juego. |
| `sendAction(SessionAction)` | cliente | Manda una acción al host. |
| `broadcast(GameSession, List<SessionEvent>)` | host | Manda el snapshot + eventos a todos los clientes unidos. |
| `disconnect()` | ambos | Cierra todo (y limpia la señalización). Idempotente. |

`SessionConfig(profile, roomCode)`: el perfil viaja en el `hello`.

**Latencia (v0.5.1, capacidad opcional)**: `LatencyProbe`
(`contracts/net_latency.dart`) es una interfaz aparte de `NetSession`
para no obligar a cada implementación (ni a las falsas de los tests) a
medir ping. Quien la usa pregunta `net is LatencyProbe`. La implementa
`ProtocolNetSession`, así que la tienen loopback, LAN y P2P.

| Miembro | Qué hace |
|---|---|
| `latency` | La última medición (`NetLatency?`; `null` = todavía nada). |
| `latencyChanges` | `Stream<NetLatency>` **broadcast**. Mientras alguien escucha se manda un `ping` enseguida y después cada `pingInterval` (2 s); sin oyentes no se manda nada. |

`NetLatency`: `rtt` (cliente: ida y vuelta al host; host: el promedio
de sus clientes), `max` (host: el peor cliente; cliente: igual a `rtt`),
`peers` (cuántas mediciones entran: el host, sus clientes con ping; el
cliente, 1) e `isHost`. Host sin clientes medidos = `rtt == null`.
`NetLatency.aggregate(isHost, rtts)` arma el resumen (función pura).

`NetEvent` (sellado):

| Evento | Lo recibe | Cuándo |
|---|---|---|
| `PeerJoinedEvent(peerId, profile)` | host | Un cliente mandó un `hello` válido y recibió `welcome`. |
| `PeerActionEvent(peerId, action)` | host | Llegó una acción de ese cliente. |
| `PeerLeftEvent(peerId)` | host | Se cerró la conexión de un cliente unido. |
| `SnapshotEvent(session, events)` | cliente | Llegó un `state`. |
| `ConnectionLostEvent(reason)` | ambos | Se perdió la conexión con el host (cliente) o el transporte del host murió. |

`NetSessionFactory` (`net_session_factory.dart`): lo que el composition
root registra para que el título sepa si hay red: `label` (`LAN`, `P2P`),
`codeHint` (qué se escribe en el campo de código), `unavailableReason`
(`null` = disponible; si no, el texto que muestra el título, p. ej.
`P2P por internet: falta configurar Firebase`) y `create()` (una
`NetSession` nueva por sala).

## Protocolo (versión 15)

`kProtocolVersion` (`wire.dart`) = 18 desde v0.9.7 (perfil v4 con `nw`,
marca NUEVO, y acción `seen`; loot.md § 17.4; 16 y 17 en `wire.dart`).
15 desde v0.9.1 (armas con `nq`,
Quebrar reemplazado, loot.md § 16.3; afijo `quebrantador`; habilidades
que pueden quebrar, combo_balance.md § 5.3). 14 desde v0.9 (TUTORIAL:
`hello` con `tv` = `tutV` de la cuenta, sesión `tut` (`TutorialState`) y
`tutN`, jugador `tv`, combatiente `prac`, acciones `tut` `tutOk` `tutCtl`
y evento `tutDone`; docs/specs/combat_tutorial.md § 6; las versiones
9-13 están en `wire.dart`). Antes: 8 desde v0.7.0 (elementos y
reacciones: estados `wet` y `charged` en `sts`, eventos de batalla
`{"k":"react","id","rk","n","src"?,"cs"?,"sp"?}` (`ReactionEvent`) y
`{"k":"ice","id","ph"}` (`IceEvent`), combatiente `fam` (raza / familia
si no es la de su tipo), `brit` (Quebradizo) y `frzR` (resistencia a la
Congelación); docs/specs/elemental_reactions.md). Antes: 7 desde v0.6.0 (exploración: acción
`poi`, eventos `poi` y `quest`, campos de misión `pu` `ps` `qd` `qf` `bl`
`wind` y de cofre `tr` `gd` `sc`, `ChestOpenedEvent.tr`;
§ "Exploración"). Antes: 6 desde v0.5.1 (acción `wants`:
resumen del plan de build para la condición `Build` del filtro de loot;
§ "Build y filtro"). Antes: 5 desde la Ascensión v0.5.0
(acciones `trial`, `ascChoose`, `ascNode`, `ascReset`, `devTrial`;
eventos `trialDone`, `ascChosen`, `trap`; sesión `trial`; perfil y
build `asc`; combatiente `once`; docs/specs/ascension.md § 6). Antes: 4
desde el endgame v0.4.0 (Ecos,
Atlas y Maestría; docs/specs/ecos_atlas.md § 7); 3 desde la
pausa de grupo (v0.2.1). Un cliente de otra versión recibe
`reject version`. Los ejemplos de abajo muestran `"v":1` por historia.

Cada mensaje es **un texto JSON** con la clave `t` (como los objetos que
manda PeerJS en el prototipo). Lo implementa una sola vez
`ProtocolNetSession` (`lib/netcode/protocol/protocol_net_session.dart`)
sobre "enlaces" de texto (`PeerLink`); cada transporte solo abre
enlaces. Codificación de mensajes: `lib/netcode/protocol/wire.dart`.

### Apretón de manos

```
cliente → host  {"t":"hello","v":1,"p":<PlayerProfile>,"b":"base"|"b1-xxxxxxxx","tv":1}
host → cliente  {"t":"welcome","v":1,"id":"p1","code":"ABCDE"}
            o   {"t":"reject","why":"full"|"version"|"balance"}  (y cierra)
```

- `tv` (v14): la última versión del TUTORIAL que completó la cuenta
  (`tutV`, 0 = nunca). El sello del host la usa para bloquear las
  misiones (combat_tutorial.md § 2). Si falta, 0.
- `b` (opcional, sin cambiar `kProtocolVersion`): hash del parche de
  balance (`GameCatalog.balanceHash`, docs/specs/balance_admin.md § 4).
  Distinto al del host → `reject balance`; un cliente sin `b` (anterior
  a v0.5.x con balance por archivo) cuenta como `"base"` y, si el host
  tiene parche, recibe `reject version`.

- `p` es `PlayerProfile.toJson()` (las claves del prototipo: `name`,
  `cls`, `lvl`, `xp`, `cr`, `st`, `pts`, `inv`, `eq`, `pot`, `eter`,
  `up`, `fuse`, `tree`), el mismo objeto del `hello` original pero
  anidado en vez de plano.
- `v` distinta a la del host → `reject version`.
- Sala llena (host + 3 clientes) → `reject full` y se cierra a los
  300 ms (como el prototipo).
- Un enlace que no manda `hello` en 10 s se cierra.
- El cliente espera `welcome` hasta 15 s (el `setTimeout` de 15 s del
  prototipo); si no, `NetException`.

### Cliente → host: acciones

Las claves de `onMsg` del prototipo (`lib/game_engine/serialization/action_json.dart`):

| `SessionAction` | JSON |
|---|---|
| `MoveAction` | `{"t":"pos","x":12.3,"y":45.6,"dir":1,"mv":true,"ep":3}` |
| `ProposeMissionAction` | `{"t":"propose","id":"m1"}` |
| `VoteMissionAction` | `{"t":"vote","ok":true}` |
| `ReadyAction` | `{"t":"ready","ok":true}` |
| `CancelPrepAction` | `{"t":"cancelPrep"}` |
| `ActivateSealAction` | `{"t":"seal","id":12}` |
| `ChangeClassAction` | `{"t":"cls","cls":"maga"}` |
| `RespecAction` | `{"t":"respec"}` |
| `AllocateStatsAction` | `{"t":"stats","add":{"VIT":2,"FUE":1}}` |
| `EquipAction` | `{"t":"equip","w":"espada2"}` |
| `TakeNodeAction` | `{"t":"node","id":"g1"}` |
| `ResetTreeAction` | `{"t":"treeReset"}` |
| `FuseAction` | `{"t":"fuse","a":base,"b":sacrificada,"sk":habilidad}` |
| `UpgradeAction` | `{"t":"up","w":arma,"stat":"pow"\|"crit"\|"spd"\|"def"}` |
| `BuyItemAction` | `{"t":"buyItem","it":"pot"\|"eter"}` |
| `BuyWeaponAction` | `{"t":"buy","w":arma}` |
| `ChatAction` | `{"t":"chat","txt":"hola"}` |
| `BackToLobbyAction` | `{"t":"back"}` |
| `UseStairsAction` | `{"t":"stairs","down":true}` (worldgen.md § 6.7) |
| `PauseAction` | `{"t":"pause","on":true}` (pausa de grupo, settings.md § 6) |
| `SetBuildWantsAction` | `{"t":"wants","w":{...}}` (v0.5.1, § "Build y filtro") |
| `BattleAction` | `{"t":"cmd","a":...}` (abajo) |

`BattleCommand` dentro de `cmd` (las claves de `battleCmd`):

| Comando | JSON |
|---|---|
| `AttackCommand` | `{"t":"cmd","a":"atk","tg":"e1"}` |
| `SkillCommand` | `{"t":"cmd","a":"tech","tk":"corte","tg":"e1"}` |
| `UltimateCommand` | `{"t":"cmd","a":"ult","tg":"e1"}` |
| `DualCommand` | `{"t":"cmd","a":"dual","pt":"p2"}`; dúo de armas (v0.8.3, aditivo): `"du":"w_flechaArcana"` |
| `ItemCommand` | `{"t":"cmd","a":"item","it":"pot"\|"eter","to":"p2"}` |
| `DefendCommand` | `{"t":"cmd","a":"def"}` |

`tg` y `to` son opcionales (se omiten si son `null`). El host aplica la
acción con el id del enlace que la mandó (nunca con un id que venga en el
mensaje): un cliente solo puede actuar por sí mismo, y `BattleAction`
solo se acepta en **su** turno (`SessionEngine`). Un mensaje que no se
puede leer se ignora.

### Host → cliente: snapshot + eventos

```
{"t":"state","s":<GameSession>,"ev":[<SessionEvent>, ...]}
```

`s` es `GameSession` completo (`lib/game_engine/serialization/session_json.dart`):
modo, jugadores **en orden de llegada** (lista), misión (objetivos,
enemigos del campo, objetos, totales), batalla (`BattleState` con todos
los combatientes, reloj, turno actual, log, resultado y los tiempos del
host: `wait`, `turnTime`, `endTimer`), votación, preparación, resultado,
reloj, gracia, `afterLevelUp` y `seq`. Todo lo que la UI lee sale de
acá; el mapa no viaja (es función pura de la semilla, `mapFor`).

Claves principales:

| Objeto | Claves |
|---|---|
| `GameSession` | `mode`, `players` (lista), `mission`, `battle`, `vote`, `prep`, `result`, `time`, `grace`, `after`, `seq`, `ground`? (loot en el piso), `gseq`? |
| `SessionPlayer` | `id`, `p` (perfil), `x`, `y`, `dir`, `ep`, `mv`, `hp`, `mp`, `mhp`, `mmp`, `ult`, `lvup` |
| `MissionRun` | `id`, `seed`, `goal`, `kills`, `elapsed`, `kos`, `xp`, `cr`, `obj`, `open`, `elites`, `eliteDrops` (`{p, w, u?, r?}`), `fe`, `items`, `zl`? (nivel de zona), `zone`?, `floor`?, `floors`?, `fg`? (cuota por piso), `lv`? (nivel por piso), `opened`? (pisos con escalera abierta) |
| `FieldEnemy` | `id`, `x`, `y`, `hx`, `hy`, `g`, `boss`, `elite`, `alive`, `tm`, `vx`, `vy`, `dir`, `aggro`, `f`? (piso) |
| `MissionItem` | `id`, `k` (`fragment`/`seal`/`chest`), `x`, `y`, `done`, `f`? (piso) |
| `SessionBattle` | `id`, `st` (`BattleState`), `fe`, `boss`, `elite`, `wait`, `turn`, `end`, `lv`? (nivel de los enemigos) |
| `BattleState` | `party`, `enemies`, `clock`, `cur`, `log`, `out` (`{win, xp, cr}`), `boss`, `elite` |
| `Combatant` | todos los campos (stats, estados, cooldowns, ULT, pociones...; loot v2: `ls`, `rgn`, `sres`, `hrec` opcionales); `build` como `{cls, lvl, st, w, up, tree, bdef, item?}` (la base por id y la instancia equipada) |
| `GroundLoot` | `id`, `d` (`{it: <arma>}` o `{st: <token>, n}`), `x`, `y`, `own`? (dueño; sin `own` = compartido), `f`? (piso de la misión, v0.5.1; sin `f` = 0) |
| Perfil (`p`) | perfil v3 (loot.md § 15): `items` (`{u, b, r?, il?, a?, p?, pl?, f?, s?, q?, n?}`), `eq` (`uid`), `mats`, `grid`, `lf`, `seq`, `pv`, `zu` (zona desbloqueada) |
| `MissionResult` | `id`, `m`, `name`, `ok`, `rank`, `time`, `xp`, `cr`, `bonus`, `bonusPct`, `kos`, `elites`, `eliteDrops`, `drops`, `left`, `zone`?, `unl`? (jugador → zona desbloqueada) |

Los enums viajan por su nombre Dart (`lobby`, `burn`, `s`...).

`ev` son los `SessionEvent` del host desde el `state` anterior, en orden
(`lib/game_engine/serialization/event_json.dart`): `sys` (mensaje de
sistema), `chat`, `joined`, `left`, `missionStart`, `obj`, `gate`,
`floor` (`f`, `down`), `stairs` (`f`), `zoneUnlocked` (`id`, `z`),
`chest`, `battleStart`, `battleStep` (con los `BattleEvent` para animar:
`turn`, `dmg`, `act`, `heal`, `status`, `skip`, `delay`, `ko`, `revive`,
`ult`, `end`), `lvl`, `battleEnd`, `drop`, `missionEnd` (con el
resultado), `lobby` y, de loot v2, `loot` (`{id, d, src, g?, u?}`),
`picked`, `given` y `crafted`. Todos los eventos van a todos los clientes (el
prototipo también hace `broadcast` de todo el chat de sistema).

**Desvío respecto del prototipo:** allá los efectos de batalla vivían
dentro del estado (`S.battle.fx`, con ids que el cliente recordaba en
`fxSeen`) y el chat salía en un mensaje aparte e inmediato. Acá los
eventos viajan en el mismo mensaje que el snapshot que ya los refleja:
llegan en orden, sin duplicados, y el cliente nunca anima un número
sobre un estado que todavía no vio. El chat llega como mucho 66 ms
después.

**Tamaño:** el snapshot completo pesa del orden de 10-30 KB en una misión
(≈ 150-450 KB/s por cliente a 15 Hz), igual que el prototipo, que
también mandaba `S` entero. Desde v0.8.5 los perfiles viajan solo cuando
cambian (§ "Perfiles solo cuando cambian"); el resto sigue entero.

### Pausa de grupo (v0.2.1)

- Snapshot: clave opcional `"pause":{"id":"p1","name":"Ana"}` solo con la
  sala pausada (`GameSession.pausedBy` / `pausedName`).
- Eventos: `{"t":"paused","id","name"}` y `{"t":"resumed","id","name"}`.
- Con la sala pausada el host no avanza (`tick` sin cambios) y rechaza
  todo salvo `pause`, `chat`, el filtro de loot y mover en el inventario
  (los `pos` se ignoran). Sigue difundiendo el snapshot. Reglas:
  docs/specs/settings.md § 6.

### Loot instanciado (loot v2)

Decisión: **un solo snapshot para todos**, como hasta ahora (sin tocar
`NetSession` ni hacer proyecciones por cliente). El loot del piso viaja
completo en `GameSession.ground`, cada objeto con su dueño (`own`); el
cliente dibuja solo el suyo y el compartido del piso actual
(`GameSession.groundFor`; cada objeto lleva su piso `f`, loot.md § 14.1).
No es un secreto (co-op entre amigos): es una regla de presentación, y
el host igual valida que solo el dueño lo levante. Los inventarios viajan
dentro de los perfiles (los de los compañeros se ven en solo lectura).

Costo: un arma pesa ~60–200 bytes en JSON compacto; 4 jugadores con el
inventario lleno suman ~20–30 KB más por snapshot, y el piso tiene tope
de 80 objetos. Desde v0.8.5 los perfiles van aparte y solo cuando
cambian (sección siguiente); los deltas del piso siguen sin hacer.

### Perfiles solo cuando cambian (protocolo 11, v0.8.5)

Problema: el host mandaba a cada cliente el snapshot entero, con el
perfil (inventario incluido) de todos, 15 veces por segundo. Cada jugador
que entra suma su perfil a lo que reciben todos y un envío más a la
subida del host; con la subida llena, el `pong` espera detrás de los
`state` (canal ordenado) y el ping de todos sube.

- El `state` lleva los jugadores **sin** `p` y, aparte, `"pp":{id:perfil}`
  solo con los perfiles que ese cliente todavía no tiene en su versión
  actual: `{"t":"state","s":{...},"ev":[...],"pp":{"p1":{...}}}`.
- Host (`ProtocolNetSession.broadcast`): versión por perfil (sube si
  cambia su JSON; se recodifica solo si cambió el objeto, `PlayerProfile`
  es inmutable) y, por cliente, qué versión tiene. El cuerpo y los
  eventos se codifican una vez; cada cliente recibe además sus `pp`.
  Cliente nuevo = recibe todos. Respaldo: cada **10 s** se reenvían todos
  a cada cliente.
- Cliente: guarda los perfiles recibidos por id y completa con ellos a
  los jugadores sin `p`. Si falta uno, el `state` se descarta (no se
  adopta un estado incompleto).
- Medición (test `profile_delta_test.dart`, 3 jugadores con 40 armas):
  lobby 10.5 KB → 0.5 KB por envío (3.8 KB cuando cambia un perfil);
  misión 15 KB → 4.9 KB.
- Con FPS Y PING prendido, el host anota en la línea `Rendimiento:` de
  `ecos.log` el tamaño del último `state` (`red: state X KB a N
  clientes (M salteados por conexión lenta)`).

### Control de flujo (protocolo 12, v0.8.6)

Problema (captura del dueño en batalla, v0.8.5): `ping 39244 ms`. El
canal es ordenado y fiable y el host mandaba un `state` cada 66 ms sin
mirar si llegaban: con una conexión que no da abasto la cola crecía sin
fin y el `pong` esperaba detrás de toda la cola.

- Cada `state` lleva su número: `{"t":"state","q":12,...}` (contador del
  host, uno por `broadcast`).
- El cliente lo confirma apenas lo recibe: `{"t":"ack","q":12}` (no es
  una acción; el host no lo pasa al juego).
- Host, por cliente: los `q` mandados sin confirmar. Con
  **`maxInFlight` = 6** en vuelo (~400 ms de `state`) ese cliente se
  **saltea** en este envío: no se le manda nada, no cambia qué perfiles
  tiene (§ anterior) y los eventos de ese `state` se guardan
  (`maxPendingEvents` = 400, se pierden los más viejos) y viajan delante
  de los del próximo `state` que sí se le mande. Como cada `state` es la
  sala entera, saltear uno no pierde estado: el siguiente lo reemplaza.
- Un `ack` borra todos los `q` ≤ al confirmado. Con una conexión que
  alcanza, nunca hay 6 en vuelo y no se saltea nada (test).
- Resultado: la cola del canal queda acotada a ~6 `state`, así que el
  ping mide la latencia real más esa cola, no una cola infinita.
- Contador `NetTraffic.skippedStates` → línea de rendimiento.

Acciones nuevas (cliente → host): `craft` (`{op, w, src?, i?, sk?, rep?, us?}`; `rep` desde v0.5.1 = habilidad a reemplazar, loot.md § 16.2; `us` desde v0.5.1 = lista de `uid` de `salvageSelected` / `sellSelected`, loot.md § 21.5),
`give` (`{to, tok, n?}`), `drop` (`{tok, n?}`), `pick` (`{id}`),
`invMove` (`{a, b}`), `invSort` (`{k}`, v0.5.1: `rarity` / `itemLevel` /
`weaponType` / `name` / `recent`, loot.md § 17.2), `filter` (`{txt}`).
Todas las valida el host.

### Endgame (v0.4.0, protocolo 4)

Docs/specs/ecos_atlas.md. Todo aditivo y opcional en el JSON:

- Acciones: `eco` (`{u}`: abrir un Eco propio), `ecoCraft` (`{u, op}`;
  `op` = `reroll` / `addMod` / `rarity` / `tier`), `devEco` (`{tier}`;
  el host la rechaza salvo con `devTools`, solo `main_dev`).
- Eventos: `ecoDone` (`{ids, tier, z, b}`: cada cliente cuyo id está
  en `ids` anota las primeras veces en el Atlas de SU cuenta),
  `mastery` (`{id, m}`), `ecoUnlocked` (`{id}`).
- Snapshot: `eco` (el Eco que se vota / prepara / juega, con los mods
  gratis ya agregados), `ecoBy` (id de quien lo abrió), `atlas` (nodos
  del Atlas del anfitrión: valen para toda la sala; lo fija el host con
  `SessionEngine.setAtlas`, nunca un cliente).
- Drops (`LootDrop`): `{eco: {...}}` además de `{it}` y `{st, n}`.
- Perfil (`hello` y snapshot): `ecos`, `eco` (portal activado), `ms`
  (Maestría).

### Build y filtro (v0.5.1, protocolo 6)

Docs/specs/build_planner.md § 6. El filtro de loot de cada jugador lo
evalúa el host, que necesita saber qué pide el plan de build de cada uno
para la condición `Build`. Aditivo: una acción nueva, sin tocar
`NetSession`, el `hello` ni el snapshot.

- Acción `SetBuildWantsAction` → `{"t":"wants","w":{"types":["hacha"],
  "bases":["hacha_berserker"],"mods":[["feroz",3]],"wp":"sedDelArma",
  "skills":["hendir"]}}` (claves vacías se omiten; sin `w` = sin plan).
  Solo lo que hace falta para `itemFit` (nada de notas ni checklist).
  El host la lee acotada (`BuildWants.fromJson`: 24 por lista, ids ≤ 48).
- El cliente la manda tras el **primer snapshot** (ya está en la sala) y
  cada vez que cambia su plan (`SessionController.setBuildWants`). Si se
  pierde la conexión y vuelve a entrar, se manda de nuevo con el primer
  snapshot de la sala nueva.
- El host la guarda en `SessionPlayer.buildWants` (memoria): no viaja en
  el snapshot ni se persiste; los demás nunca ven el plan de otro.
- Se acepta con la sala pausada (no toca el mundo).

### Ping (v0.5.1, protocolo 6)

Para el indicador de FPS y ping (docs/specs/settings.md § 3.9). Aditivo
dentro del protocolo 6 (v0.5.1 aún no salió): dos mensajes de control
que **no son acciones** (nunca llegan a `PeerActionEvent`, no tocan el
estado autoritativo ni la pausa) y se ignoran antes del `hello` /
`welcome`.

- `{"t":"ping","ts":123456}` → el otro extremo responde enseguida
  `{"t":"pong","ts":123456}` con el mismo `ts`.
- `ts` = microsegundos del reloj **de quien manda el ping**
  (monótono, `Stopwatch`; los tests inyectan uno falso). Al llegar el
  `pong`, `rtt = ahora − ts`: no hace falta sincronizar relojes. Un
  `ts` del futuro o de hace más de 60 s se descarta.
- Mide cada extremo para sí: el cliente hace ping al host; el host a
  cada cliente unido (`rtt` por id; al irse un cliente se borra). Los dos
  responden siempre los `ping` del otro, midan o no.
- Solo se manda mientras hay un oyente de `latencyChanges` (el
  indicador prendido): con el indicador apagado no viaja nada.
- Un `t` desconocido (cliente viejo) se sigue ignorando: el `ping` no
  rompe a nadie, pero todos tienen que tener el protocolo 6 igual.

### Exploración (v0.6.0, protocolo 7)

docs/specs/worldgen.md § 11.9. Todo aditivo y host-autoritativo; los
puntos de interés salen del mapa (la semilla), así que solo viaja su
estado.
- Acción `InteractPoiAction` → `{"t":"poi","id":101}` (E frente a un
  punto de interés; el host valida campo, piso, distancia y que no esté
  usado). Se rechaza con la sala pausada.
- Eventos `{"t":"poi","id":"p1","poi":101,"k":"shrine","bl":"fuerza"}`
  (`to`: piedra de destino de un viaje rápido) y
  `{"t":"quest","q":150,"f":1,"k":"braseros"}` (misión opcional cumplida).
- Snapshot (`MissionRun`): `pu` (PdI usados), `ps` (descubiertos), `qd` /
  `qf` (misiones opcionales cumplidas / falladas), `bl` (bendición), `wind`
  (Viento del Eco hasta ese `time`); cofres (`MissionItem`): `tr`
  (calidad, se omite `madera`), `gd` (id del guardián), `sc` (PdI de su
  sala secreta). Sin las claves = nada usado.
- El viaje rápido sube la época del jugador (el cliente adopta la
  posición). El Viento del Eco lo aplica cada cliente a su propio
  movimiento (`ExplorationRules.speedMult`).

### Desconexiones

- **Cliente que se va** (cierra la ventana, se cae la red): el host
  recibe `PeerLeftEvent`, hace `SessionEngine.removePlayer` (sale de la
  batalla si había una, mensaje `X salió de la sala.`) y sigue jugando,
  como el `gone()` del prototipo.
- **Host que se va:** el cliente recibe `ConnectionLostEvent` y la
  pantalla del juego vuelve al título con `Se perdió la conexión con el
  host.` (el prototipo mostraba ese mismo mensaje). Antes cierra todo lo
  que haya encima de la partida (pausa, diálogos); si por algo no puede
  salir sola, la pantalla DESCONECTADO muestra el motivo y un botón
  **VOLVER AL TÍTULO** (v0.8.5).
- Salir al título (host o cliente) llama a `disconnect()`.

## Cómo la sesión usa la red (`SessionController`)

Ver docs/specs/exploration.md § "Controlador de sesión". Resumen:

| Rol | Corre `SessionEngine` | `localId` | Qué hace con la red |
|---|---|---|---|
| Local (sin `NetSession`) | sí | `local` | nada |
| Host | sí | `h` (de la `NetSession`) | agrega/quita jugadores remotos, aplica sus acciones con su id, `broadcast` cada 66 ms |
| Cliente | **no** | el del `welcome` | aplica snapshots, predice solo su movimiento, `sendAction` |

## Implementaciones

| Variante | Carpeta | Composition root | Estado |
|---|---|---|---|
| Loopback (memoria, tests) | `netcode/loopback` | — (tests) | Probado |
| LAN (WebSocket, `dart:io`) | `netcode/lan` | `main_lan.dart` | Probado con sockets reales en localhost |
| P2P por internet (WebRTC + señalización Firestore) | `netcode/p2p_webrtc` | `main_p2p.dart`, `main_dev.dart` | Señalización REST probada contra el proyecto real (`tool/p2p_signaling_smoke.dart`) y con servidor falso en tests; WebRTC de punta a punta pendiente de probar en dos PCs |
| Servidor dedicado | `netcode/dedicated_server` | — | No empezado (README) |
| Rollback | `netcode/rollback` | — | No empezado (README) |

### Loopback (`LoopbackNetSession` + `LoopbackHub`)

Un `LoopbackHub` en memoria hace de "internet": el host registra su sala
(códigos `LOOP1`, `LOOP2`...) y cada cliente abre un par de enlaces en
memoria. Pasa por el mismo protocolo y la misma codificación JSON que
los transportes reales: sirve para probar host + N clientes en un solo
proceso.

### LAN (`LanNetSession`)

- Host: `HttpServer` en `0.0.0.0`, puerto **47800** (si está ocupado, uno
  libre que elige el sistema), WebSocket en la ruta `/ecos`.
- **Código de sala = `IP:PUERTO`** del host (p. ej. `192.168.1.23:47800`),
  sin codificar. Se eligió así porque es legible, se puede dictar, no
  necesita tablas y sirve para depurar (`ping 192.168.1.23`). La IP es la
  primera IPv4 privada de las interfaces (prioridad `192.168.*`, `10.*`,
  `172.16-31.*`). Si la PC tiene varias (VPN, Hyper-V) puede elegir
  una que el otro no alcanza: en ese caso, unirse con la IP que muestra
  `ipconfig` en el host (pendiente: listar todas en el título).
- Cliente: `WebSocket.connect('ws://IP:PUERTO/ecos')`; acepta `IP` sola
  (puerto 47800) o `localhost`. Dos ventanas en la misma PC: unirse con
  `127.0.0.1:47800`.
- `pingInterval` de 5 s para detectar caídas.
- La primera vez Windows pregunta si deja pasar al juego por el firewall:
  hay que aceptar en **redes privadas** para que otra PC se conecte.

### P2P por internet (`WebRTCNetSession` + `SignalingService`)

Firestore **nunca** transporta el juego: solo los SDP/ICE para armar una
conexión WebRTC directa. Una vez abierto el `RTCDataChannel` (ordenado y
confiable, etiqueta `game`), todo el protocolo de arriba viaja por ahí.

- Estrella: el host tiene un `RTCPeerConnection` + un `DataChannel` por
  cliente (hasta 3).
- Código de sala: 5 caracteres de `ABCDEFGHJKLMNPQRSTUVWXYZ23456789`
  (`randCode` del prototipo); si ya existe se sortea otro (como
  `unavailable-id`).
- Documentos:

```
rooms/{CODIGO}                       {v, createdAt, expiresAt}       (host)
rooms/{CODIGO}/peers/{peerId}        {offer, answer?, createdAt, expiresAt}
rooms/{CODIGO}/peers/{peerId}/clientCandidates/{auto}   ICE del cliente
rooms/{CODIGO}/peers/{peerId}/hostCandidates/{auto}     ICE del host
```

- Cliente: verifica que la sala exista (si no, `Sala X no encontrada`),
  crea su `peers/{auto}` con la oferta, crea el `DataChannel`, escucha
  `answer` y `hostCandidates`. A los 20 s sin canal abierto falla.
- Host: escucha `peers` nuevos, responde cada oferta con su propio
  `RTCPeerConnection`, escucha `clientCandidates` y publica los suyos.
  Los candidatos remotos que llegan antes de la descripción remota se
  encolan.
- Limpieza: el cliente borra su documento (y candidatos) 5 s después de
  conectarse y al salir; el host borra la sala completa al salir.
  `expiresAt` (ahora + 6 h) permite una política TTL que limpie lo que
  quede de una caída.
- ICE: solo STUN (`stun:stun.l.google.com:19302`). Sin TURN, dos NAT
  simétricas no se conectan (fuera de alcance).
- Fin de la señalización: apenas abre el `DataChannel`, cada lado corta
  sus suscripciones de señalización de ese enlace (respuesta/candidatos).
  El host descarta una conexión que no abrió su canal a los 30 s (el
  cliente se rinde a los 20 s) o cuya oferta falló, para que no ocupe
  lugar ni siga escuchando.

#### Señalización: interfaz y dos implementaciones

`WebRTCNetSession` solo conoce `SignalingService`
(`netcode/p2p_webrtc/signaling_service.dart`: crear/consultar sala,
ofertas, respuesta, candidatos, limpieza). El composition root elige la
implementación según la plataforma (`resolveP2PSignaling` en
`app/flavors/firebase_bootstrap.dart` → `registerP2PNetcode(signaling:)`):

| Plataforma | Implementación | `Firebase.initializeApp` |
|---|---|---|
| Windows / Linux / macOS | `FirestoreRestSignaling` (API REST v1, `dart:io` `HttpClient`) | **No** se llama |
| Web / Android / iOS | `FirestoreSignalingService` (SDK `cloud_firestore`, listeners) | Sí |

Si `DefaultFirebaseOptions.currentPlatform` lanza (plataforma sin
configurar) o falta `projectId`/`apiKey`, o `initializeApp` falla, la
fábrica queda no disponible (`P2P por internet: falta configurar
Firebase`).

##### Señalización REST en escritorio

**Por qué:** el plugin `cloud_firestore` de escritorio envuelve el SDK
C++ de Firebase (oficialmente solo para desarrollo). En Windows sus
canales (`plugins.flutter.io/firebase_firestore/transaction/...` y
`.../query/...`) mandan mensajes de nativo a Flutter desde un hilo que no
es el de la plataforma (`shell.cc: ... non-platform thread ... may result
in data loss or crashes`). Se observó con dos ventanas en una PC: crear
la sala (transacción) funcionaba, pero el cliente que pulsaba UNIRSE se
quedaba esperando: los eventos de los listeners (`snapshots()` de la
respuesta y de los candidatos; del lado del host, de `peers`) se
perdían y la conexión nunca se armaba. Con REST no hay SDK nativo ni
listeners: solo pedidos HTTP desde Dart.

- Base `https://firestore.googleapis.com/v1/projects/{projectId}/databases/(default)/documents/...?key={apiKey}`
  (la `apiKey` y el `projectId` de `lib/firebase_options.dart`). Sin
  Firebase Auth: las reglas de `firestore.rules` se aplican igual.
- Sala: `POST rooms?documentId={CODIGO}` con `{v, createdAt, expiresAt}`.
  Si el código existe responde 409 (o 403, porque para las reglas sería
  un `update`; en ese caso se confirma con un `GET`) → se sortea otro.
- Unirse: `GET rooms/{CODIGO}` (404 = no existe; sin transacción), `POST
  rooms/{CODIGO}/peers` (id automático) con `{offer, createdAt,
  expiresAt}`.
- Respuesta: `PATCH peers/{id}?updateMask.fieldPaths=answer&currentDocument.exists=true`
  (las reglas solo dejan cambiar `answer`).
- Candidatos: `POST peers/{id}/clientCandidates|hostCandidates`
  (`candidate`, `sdpMid`, `sdpMLineIndex`, `expiresAt`).
- `createdAt` va con la hora local (`timestampValue`): las reglas solo
  limitan qué campos hay, no su valor. El SDK usa la hora del servidor.
- Limpieza: listar y `DELETE` uno por uno (candidatos, peer, sala).
- Valores tipados de Firestore (`stringValue`, `integerValue` como
  texto, `doubleValue`, `booleanValue`, `nullValue`, `timestampValue`,
  `mapValue`, `arrayValue`): `FirestoreRestCodec`.
- **"Escuchar" = consultar** mientras haya una suscripción, sin solapar
  pedidos, recordando los documentos ya vistos (cada oferta/candidato se
  emite una vez):
  - respuesta y candidatos: cada **500 ms**; la respuesta deja de
    consultarse apenas llega; los candidatos, cuando abre el canal;
  - ofertas nuevas (host): cada **1 s** mientras la sala está abierta
    (alguien puede unirse en cualquier momento).
  - 10 fallas seguidas de una consulta → el stream termina con error (en
    el host: `Se perdió la conexión con el servidor de salas.`); una
    falla suelta se ignora.
- Cada pedido tiene timeout de 10 s. Los errores salen como
  `SignalingException` con mensaje en castellano (sin internet, sin
  respuesta, permiso denegado/reglas, clave inválida, cuota, error del
  servidor) y la sesión los muestra como `NetException`.
- **Costo:** cada consulta es una lectura facturable (una lista vacía
  cuenta como 1). Durante el armado (unos segundos por cliente): ~2
  lecturas por segundo y por lado. El host con la sala abierta: ~1
  lectura/s (≈3600/h) por las ofertas. La cuota gratis de Firestore son
  50 000 lecturas/día: alcanza para jugar entre amigos; si molesta, subir
  `offerPollInterval`.
- `tool/p2p_signaling_smoke.dart` (`dart run tool/p2p_signaling_smoke.dart`)
  prueba todo esto contra el proyecto real y borra lo que crea.

#### Qué tiene que hacer el dueño para habilitarlo

Sin esto el título muestra `P2P por internet: falta configurar Firebase`
y el resto del juego funciona igual.

1. Crear un proyecto en <https://console.firebase.google.com>.
2. *Build → Firestore Database → Create database* (modo producción, la
   región más cercana).
3. *Firestore → Rules*: pegar las reglas de abajo y publicar.
4. (Recomendado) *Firestore → TTL*: crear políticas sobre el campo
   `expiresAt` para los grupos de colecciones `rooms`, `peers`,
   `clientCandidates` y `hostCandidates`.
5. Instalar las herramientas (una vez):
   `npm install -g firebase-tools`, `firebase login`,
   `dart pub global activate flutterfire_cli`.
6. En la raíz del repo: `flutterfire configure --project=<id-del-proyecto>`
   y elegir las plataformas (windows, android...). Eso **sobrescribe**
   `lib/firebase_options.dart`, que hoy es un stub que lanza
   `UnsupportedError` (por eso la app sabe que falta configurar).
7. `flutter run -d windows -t lib/app/flavors/main_p2p.dart`.

`main_p2p.dart` llama a `resolveP2PSignaling()` y pasa el resultado a
`registerP2PNetcode`: en escritorio solo lee `projectId`/`apiKey` de
`DefaultFirebaseOptions.currentPlatform` (sin `Firebase.initializeApp`);
en web/móvil llama a `Firebase.initializeApp` dentro de un `try`. Si el
stub lanza o la inicialización falla, la fábrica de red queda registrada
como no disponible con ese motivo.

Reglas de Firestore: archivo **`firestore.rules`** en la raíz del repo
(referenciado desde `firebase.json`). Sin autenticación: cualquiera con
la configuración del proyecto puede crear salas; alcanza para jugar entre
amigos — para algo público habría que agregar Firebase Auth anónima, que
es otra dependencia. Limitan la forma de cada documento (campos
permitidos, código de sala válido, candidatos ICE con ≤ 6 campos).
Para cargarlas o actualizarlas:

```
firebase deploy --only firestore:rules --project echos-del-tiempo
```

Proyecto configurado: `echos-del-tiempo` (apps web y Windows registradas
por `flutterfire configure`; `lib/firebase_options.dart` y
`firebase.json` versionados).

FlutterFire en Windows usa el SDK C++ de Firebase y la documentación
oficial lo considera apto para desarrollo; por eso en escritorio la
señalización no usa el SDK sino la API REST (ver arriba).

## Fuera de alcance

Servidor dedicado y rollback (ver sus README), TURN / NAT simétrica,
anti-trampas (el host confía en las posiciones y perfiles de los
clientes, como el prototipo), reconexión de un cliente caído (vuelve a
entrar como jugador nuevo con su perfil guardado) y migración de host.

## Protocolo 9 (v0.8.0, Jefes del Abismo)

Aditivo (docs/specs/abyss_bosses.md § 5): acciones `{"t":"abyss","n":1..5}`
y `{"t":"devAbyss","k":"frag"|"kills"}` (solo `devTools`); evento
`{"t":"abyssDone","n":..,"ids":[..]}` (cada cliente anota `x<n>` en el
Atlas de su cuenta); sesión `abyss`, `abyssBy`; perfil `aby` (vencidos);
combatiente `abT` `abE` `abS` `abSN` `abA` `abK` `abF` `abC`; fases de
`BossMechanicEvent` `abyssTelegraph` `enrage` `sealCast` `sealBroken`
`sealFade` `rewind` `timeWarp` `mirror` `devour` `aspect`; pilas
`mat:fragReloj` `mat:fragEco` `mat:fragCorona` `mat:fragEras`
`mat:esencia`; forja `essence`. El cliente suma los vencidos de su
cuenta al perfil antes del `hello` (`AbyssRules.withAccount`).


## Party jugando solo (v0.8.1)

Solo sin red: al crear o unirse a una sala no se cargan compañeros (un
personaje por humano). `SessionPlayer.leaderId` y el rastro del líder son
**solo del host** y no viajan en el snapshot; `SessionEngine.applyFor`
(actuar por un compañero) nunca se usa con red. Sin cambio de protocolo.
Ver solo_party.md § 1.
