# Spec: Sesión, misiones y recompensas

Fuente de verdad: prototipo `ecos-del-tiempo.html`, `MISSIONS` (líneas
290-297), la lógica del host (líneas 556-700: `onMsg`, `canShop`,
`addPlayer`, `spawnPos`, `curMission`, `OBJN`, `updateOpen`,
`startMission`, `hostTick`, `GRACE_MS`, `LEASH`, `calmEnemies`,
`openChest`, `fieldTick`), `battleTick` (759-768), `checkEnd` (750-757),
`finishBattle`, `missionEnd` y `toLobby` (872-905).

Implementación Dart:
- Datos: `lib/game_engine/data/missions_catalog.dart` (`kMissions`),
  modelo `lib/game_engine/models/mission_def.dart`.
- Estado: `lib/game_engine/models/game_session.dart` (`GameSession`).
- Acciones / eventos: `lib/game_engine/models/session_action.dart`,
  `lib/game_engine/models/session_event.dart`.
- Reglas: `lib/game_engine/rules/session_engine.dart` (`SessionEngine`).

Tests: `test/game_engine/session_engine_test.dart`,
`test/game_engine/mission_setup_test.dart`.

## Modelo

`GameSession` es el `S` del host: mutable por dentro pero el
`SessionEngine` siempre trabaja sobre una copia (`GameSession.copy`) y
devuelve un `SessionStep(estado nuevo, eventos)`, igual que `BattleEngine`.
El reloj es propio (`time`, en segundos, avanza con `tick(dt)`); no se usa
`Date.now()`, así todo es reproducible.

Modos (`SessionMode`): `lobby` → `prep` → `field` ⇄ `battle` → (`levelUp`)
→ `result` → `lobby`.

Jugadores: máximo 4, en orden de llegada (ese orden decide spawn, orden
en la batalla y desempates). Cada uno tiene su `PlayerProfile`
persistente (ver progression.md) más estado de sesión: posición,
dirección, época de posición (`epoch`), vida/maná actuales (fraccionarios
en el campo), carga de ULT y `levelUpPending`.

## Misiones (`kMissions`)

> v0.2.0: el mostrador ofrece las **misiones de zona** (`kMissions` =
> `kZoneMissions`, con pisos, escaleras, nivel de zona y desbloqueo por
> perfil): ver worldgen.md § 6. La tabla de abajo describe las 3 misiones
> del prototipo (`kPrototypeMissions`, un solo mapa), que siguen
> funcionando igual para los tests de paridad.

| id | nombre | tipo | rango | Lv rec. | tema | grupos a vencer | jefe | tiempo S | élite | objetivos extra |
|---|---|---|---|---|---|---|---|---|---|---|
| m1 | Pradera Esmeralda | Exterminio | C | 1 | pradera | 7 | reyLimo + 2 slime | 420 s | bat | 1 |
| m2 | Ruinas Cronales | Recuperación | B | 4 | ruinas | 8 | golemReloj + golem | 510 s | golem | 2 |
| m3 | Abismo del Tiempo | Urgente | A | 7 | abismo | 9 | devorador + 2 ghost | 600 s | ghost | 2 |

Grupos de enemigos posibles por misión: ver catálogo (copiados 1:1).

## Lobby: votación y preparación

- `ProposeMissionAction(id)`: en lobby, sin votación abierta y con una
  misión válida. Abre la votación con el voto a favor de quien propone.
- `VoteMissionAction(sí/no)`: sí suma el voto; no cancela la votación.
- `tick`: si todos los jugadores votaron que sí, pasa a `prep`.
- En `prep` cada jugador marca `ReadyAction(true/false)`; si todos están
  listos, `tick` arranca la misión. `CancelPrepAction` vuelve al lobby.
- Tienda, herrería, fusión, equipar, reiniciar puntos y reiniciar árbol
  solo se permiten en `lobby` o `prep` (`canShop`). Cambiar de clase solo
  en `lobby`. Repartir puntos y tomar nodos del árbol: en cualquier modo
  salvo `battle`.

## Inicio de misión (`startMission`)

Con una semilla nueva (inyectable, `SeedSource`; el prototipo usa
`Math.random() * 1e9 | 0`):

1. Se genera el mapa (world.md). Un segundo `mulberry32(semilla + 7)`
   ubica todo lo demás, en este orden:
2. `goal + 9` grupos normales: hasta 90 intentos cada uno de elegir un
   `spot` al azar que no sea sólido ni tenga sólido abajo, a la derecha
   o a la izquierda, y que quede a más de 96 px (intentos 0-39), 64 px
   (40-69) o 40 px (70-89) de otro enemigo. El grupo se elige al azar
   entre `groups` solo cuando el lugar sirve. El objetivo de grupos es
   `min(goal, grupos ubicados)`.
3. El jefe, en el centro de la arena.
4. Objetivos extra: se sacan `extra` al azar sin repetir de
   `[frag, seal, elite]`.
5. `freeSpot(minD)`: hasta 200 intentos de un spot no sólido a 120 px o
   más del spawn, a `minD` o más de otros objetos y a 40 px o más de los
   enemigos; si no hay, un spot cualquiera.
6. Con `frag`: 3 Fragmentos de tiempo (`freeSpot(90)`), objetivo 0/3.
   Con `seal`: 2 Sellos (`freeSpot(140)`), objetivo 0/2.
7. Élites: 2 si salió `elite` (y objetivo 0/1), si no 1 (opcional). Cada
   élite es `[enemigo élite de la misión, primer enemigo de un grupo al azar]`
   en `freeSpot(80)`.
8. Cofres: `2 + floor(r × 3)` en `freeSpot(70)`.
9. Jugadores al spawn (`spawnPos(i) = spawn + ((i % 2)*14 − 7, floor(i/2)*14 − 7)`),
   vida y maná llenos, ULT a 0, época de posición +1.
10. Gracia de 2.5 s (los enemigos no persiguen ni inician combate).

Objetivos: `kills` (Grupos derrotados), `frag` (Fragmentos de tiempo),
`seal` (Sellos activados), `elite` (Élite derrotado). Cuando todos
llegan a su meta se abre la barrera del jefe (`open`) — una sola vez.

## Campo (`tick` en modo `field`)

En este orden:
1. Fragmentos: un jugador vivo a menos de 14 px lo recoge (+1 al objetivo).
2. Cofres: un jugador vivo a menos de 14 px lo abre (ver abajo).
3. Regeneración y IA de enemigos (world.md). El contacto empieza una batalla.

`ActivateSealAction(id)`: el jugador debe estar a menos de 30 px del
sello (la UI lo ofrece a menos de 26 px).

`MoveAction(x, y, dir, moving, epoch)`: el host confía en la posición
del cliente (como el prototipo) pero solo en lobby/campo, con el jugador
vivo y si `epoch` coincide con la del jugador (cada teletransporte la
sube, así se descartan posiciones viejas). `x`/`y` en 0 o no finitos se
ignoran.

### Cofres (`openChest`)

`tier` = 3 (rango A), 2 (B) o 1 (C). En este orden de azar:
- Créditos: `20 + floor(azar × 31) + tier × 10`.
- `azar < 0.5`: +1 Poción de vida; si no, `azar < 0.6`: +1 Poción de maná
  (tope 9 de cada una).
- Loot v2 (loot.md § 14): el que lo abre tira el loot de cofre (35% de
  un arma, materiales ×2) con el nivel de zona de la misión.

## Batalla en la sesión

Contacto → `BattleEngine.start` con el grupo del enemigo, `elite` si es
élite, todos los jugadores (en orden) con su vida (`ceil`) y maná
actuales, ULT, pociones y habilidad fusionada, y `triggeredBy` = quien
tocó. Época de posición +1. Las posiciones de batalla son de la UI.

`tick` en modo `battle` reproduce los tiempos de `battleTick`:
- Pausa inicial 1.0 s.
- Si la batalla terminó: espera 2.0 s (victoria) o 2.2 s (derrota) y
  llama a `finishBattle`.
- Si hay pausa (`wait`), la descuenta y no hace nada más.
- Sin turno: `nextTurn`. Si hubo daño/cura de estados o perdió el turno,
  pausa 0.9 s; si el actor cae o pierde el turno, 1.1 s. Si le toca a un
  enemigo, pausa mínima 0.35 s.
- Turno de enemigo: `enemyTurn` y pausa 0.8 s.
- Turno de jugador: espera `BattleAction`. A los 30 s se defiende solo
  (`timeout`), pausa 0.8 s.
- `BattleAction` solo se acepta sin pausa, sin fin pendiente y en el turno
  de ese jugador. Pausa 0.8 s (2.3 s tras un ULT).
- Cada K.O. de un jugador suma 1 a `kos` de la misión.
- Un jugador que llega a mitad de batalla entra al timeline en
  `reloj + IV` (`BattleEngine.join`); uno que se va sale de ella
  (`BattleEngine.leave`).

### Al ganar (`checkEnd`)

Apenas cae el último enemigo: cada jugador recibe XP y créditos del
`BattleOutcome` (élite ×3, ver combat.md), se suman a los totales de la
misión, y se aplica la subida de nivel (progression.md: puede subir
varios niveles; cada uno 1 punto de atributo (+3) y 1 de árbol, progression_v2.md; +maxHp/+maxMp ganados a la vida y
maná actuales, `levelUpPending`). Vida, maná, ULT y pociones de la
batalla vuelven al jugador.

### `finishBattle` (tras la pausa final)

- Derrota → `missionEnd(false)`.
- El enemigo del campo muere.
- Élite: `elites + 1`, objetivo élite + 1, y cada jugador tira su loot
  de élite (loot.md § 14: 1 arma segura + 50% de otra, materiales ×3);
  `eliteDrops` guarda la base de la primera.
- Grupo normal: `kills + 1` y cada jugador tira su loot de batalla (30%
  de un arma, materiales). Jefe: loot de jefe (2 armas, materiales ×5).
- `updateOpen`. Los jugadores caídos quedan con 1 de vida; época +1.
- Si alguien subió de nivel y tiene puntos: modo `levelUp` (el reloj de la
  misión se detiene). Cuando todos los que subieron repartieron sus
  puntos: si era el jefe → `missionEnd(true)`; si no → campo con gracia
  3.5 s y `calmEnemies`.
- Si no: jefe → `missionEnd(true)`; si no → campo, gracia 3.5 s
  (`GRACE_MS`) y `calmEnemies`.

## Fin de misión (`missionEnd`)

- Rango: derrota `D`. Victoria: `S` si `tiempo ≤ sTime` y sin K.O.;
  `A` si `tiempo ≤ sTime × 1.5`; si no `B`. El tiempo cuenta solo en
  campo y batalla.
- Bonus de créditos para cada jugador: `round(créditos_misión × {S 0.5, A 0.25, B 0, D 0})`.
- Victoria: cada jugador tiene `{S 90%, A 70%, B 50%}` de recibir un
  arma de fin de misión (loot v2, nivel de zona + 1, bonus de rareza S
  +1 / A +0.5, siempre al inventario); `drops` guarda su base.
- Nivel de zona: `LootRules.zoneLevel` al empezar la misión
  (`MissionRun.zoneLevel`, loot.md § 14). El loot del piso se vacía al
  empezar la misión y al volver al lobby.
- Los caídos quedan con 1 de vida. Modo `result` por 25 s
  (`BackToLobbyAction` lo corta antes).

## Vuelta al lobby (`toLobby`)

Se borra misión, batalla, votación y preparación; jugadores al spawn del
lobby con vida y maná llenos (la ULT se conserva), época +1.

## Desvíos intencionales respecto del prototipo

- Reloj propio de la sesión en vez de `Date.now()` (determinístico).
- La vida entra a la batalla redondeada hacia arriba (`ceil`, lo que
  muestra el HUD); el combate trabaja con enteros.
- Los mensajes de sistema no usan emojis, `★` ni `₵` (la fuente 8 bits
  no los tiene): dicen "créditos".
- `addPlayer` además exige `puntos ≥ 0` al validar los atributos de un
  perfil (el prototipo aceptaba puntos negativos si cuadraba la suma).
- La acción `branch_old` (código muerto) no se porta.

## Chat (`case 'chat'`, línea 582)

`ChatAction(texto)`: en cualquier modo, de un jugador de la sala. El
host recorta espacios, rechaza el texto vacío y lo corta a 120
caracteres (`ChatAction.maxLength`). No cambia el estado: emite
`ChatMessageEvent(id, nombre, texto)` (el `broadcast` + `addChat` del
prototipo). Test: `test/game_engine/session_chat_test.dart`.

## Pausa de grupo (v0.2.1)

`PauseAction(true/false)` de cualquier jugador pausa o reanuda la sala
(`GameSession.pausedBy`, eventos `PausedEvent` / `ResumedEvent`). Con la
sala pausada `tick` no avanza nada (reloj, `mission.elapsed`, gracia,
campo, turnos, resultado) y `apply` solo acepta pausa, chat, filtro de
loot y mover en el inventario. Si quien pausó se va, sigue pausada.
Detalle: docs/specs/settings.md § 6. Test:
`test/game_engine/session_pause_test.dart`.

## Red

El transporte, el broadcast periódico del snapshot (66 ms) y la
serialización de `GameSession`, `SessionAction` y `SessionEvent`
(`lib/game_engine/serialization/`) están en docs/specs/netcode.md. Los
jugadores remotos entran con `addPlayer` (ids `p1`, `p2`...; el host es
`h`) y salen con `removePlayer` cuando se cae su conexión.

## Fuera de alcance (fases siguientes)

La UI de votación y preparación está
en docs/specs/panels.md, el sonido en audio.md y el chat del cliente en
exploration.md § "Chat".
