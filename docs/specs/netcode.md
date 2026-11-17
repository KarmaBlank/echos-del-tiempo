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

## Protocolo (versión 1)

Cada mensaje es **un texto JSON** con la clave `t` (como los objetos que
manda PeerJS en el prototipo). Lo implementa una sola vez
`ProtocolNetSession` (`lib/netcode/protocol/protocol_net_session.dart`)
sobre "enlaces" de texto (`PeerLink`); cada transporte solo abre
enlaces. Codificación de mensajes: `lib/netcode/protocol/wire.dart`.

### Apretón de manos

```
cliente → host  {"t":"hello","v":1,"p":<PlayerProfile>}
host → cliente  {"t":"welcome","v":1,"id":"p1","code":"ABCDE"}
            o   {"t":"reject","why":"full"|"version"}  (y cierra)
```

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
| `BattleAction` | `{"t":"cmd","a":...}` (abajo) |

`BattleCommand` dentro de `cmd` (las claves de `battleCmd`):

| Comando | JSON |
|---|---|
| `AttackCommand` | `{"t":"cmd","a":"atk","tg":"e1"}` |
| `SkillCommand` | `{"t":"cmd","a":"tech","tk":"corte","tg":"e1"}` |
| `UltimateCommand` | `{"t":"cmd","a":"ult","tg":"e1"}` |
| `DualCommand` | `{"t":"cmd","a":"dual","pt":"p2"}` |
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
| `MissionRun` | `id`, `seed`, `goal`, `kills`, `elapsed`, `kos`, `xp`, `cr`, `obj`, `open`, `elites`, `eliteDrops` (`{p, w, u?, r?}`), `fe`, `items`, `zl`? (nivel de zona) |
| `FieldEnemy` | `id`, `x`, `y`, `hx`, `hy`, `g`, `boss`, `elite`, `alive`, `tm`, `vx`, `vy`, `dir`, `aggro` |
| `MissionItem` | `id`, `k` (`fragment`/`seal`/`chest`), `x`, `y`, `done` |
| `SessionBattle` | `id`, `st` (`BattleState`), `fe`, `boss`, `elite`, `wait`, `turn`, `end` |
| `BattleState` | `party`, `enemies`, `clock`, `cur`, `log`, `out` (`{win, xp, cr}`), `boss`, `elite` |
| `Combatant` | todos los campos (stats, estados, cooldowns, ULT, pociones...; loot v2: `ls`, `rgn`, `sres`, `hrec` opcionales); `build` como `{cls, lvl, st, w, up, tree, bdef, item?}` (la base por id y la instancia equipada) |
| `GroundLoot` | `id`, `d` (`{it: <arma>}` o `{st: <token>, n}`), `x`, `y`, `own`? (dueño; sin `own` = compartido) |
| Perfil (`p`) | perfil v3 (loot.md § 15): `items` (`{u, b, r?, il?, a?, p?, pl?, f?, s?, q?, n?}`), `eq` (`uid`), `mats`, `grid`, `lf`, `seq`, `pv` |
| `MissionResult` | `id`, `m`, `name`, `ok`, `rank`, `time`, `xp`, `cr`, `bonus`, `bonusPct`, `kos`, `elites`, `eliteDrops`, `drops`, `left` |

Los enums viajan por su nombre Dart (`lobby`, `burn`, `s`...).

`ev` son los `SessionEvent` del host desde el `state` anterior, en orden
(`lib/game_engine/serialization/event_json.dart`): `sys` (mensaje de
sistema), `chat`, `joined`, `left`, `missionStart`, `obj`, `gate`,
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
también mandaba `S` entero. Si hiciera falta, la optimización natural es
mandar deltas; no está hecha.

### Loot instanciado (loot v2)

Decisión: **un solo snapshot para todos**, como hasta ahora (sin tocar
`NetSession` ni hacer proyecciones por cliente). El loot del piso viaja
completo en `GameSession.ground`, cada objeto con su dueño (`own`); el
cliente dibuja solo el suyo y el compartido (`GameSession.groundFor`).
No es un secreto (co-op entre amigos): es una regla de presentación, y
el host igual valida que solo el dueño lo levante. Los inventarios viajan
dentro de los perfiles (los de los compañeros se ven en solo lectura).

Costo: un arma pesa ~60–200 bytes en JSON compacto; 4 jugadores con el
inventario lleno suman ~20–30 KB más por snapshot, y el piso tiene tope
de 80 objetos. Si pesa, la optimización natural (no hecha) es mandar el
perfil solo cuando cambia (hash por jugador) y deltas del piso.

Acciones nuevas (cliente → host): `craft` (`{op, w, src?, i?, sk?}`),
`give` (`{to, tok, n?}`), `drop` (`{tok, n?}`), `pick` (`{id}`),
`invMove` (`{a, b}`), `filter` (`{txt}`). Todas las valida el host.

### Desconexiones

- **Cliente que se va** (cierra la ventana, se cae la red): el host
  recibe `PeerLeftEvent`, hace `SessionEngine.removePlayer` (sale de la
  batalla si había una, mensaje `X salió de la sala.`) y sigue jugando,
  como el `gone()` del prototipo.
- **Host que se va:** el cliente recibe `ConnectionLostEvent` y la
  pantalla del juego vuelve al título con `Se perdió la conexión con el
  host.` (el prototipo mostraba ese mismo mensaje).
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
