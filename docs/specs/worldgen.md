# Spec (aprobada; v0.2.0 implementada): Generación de mundo estilo roguelike de zonas

Pedido del dueño: "la generación de mundo que sea como Tales of Maj'Eyal
(ToME)". Se toman las **mecánicas** del género (mapa del mundo con zonas,
cada zona con varios pisos y su propio generador según el tipo de lugar,
salas pre-diseñadas incrustadas); los lugares, nombres y arte son propios
de Ecos del Tiempo.

Estado: diseño aprobado por el dueño (decisiones en § 4); la v0.2.0 (§ 5–7)
está implementada. Reemplaza a `world.md` § "genMap"
(el generador actual queda como generador "ruinas clásicas").

## 1. Mapa del mundo

- Un mapa grande de tiles (pradera, bosque, montaña, agua, caminos)
  generado una vez por partida/sala con semilla, con las **entradas de
  zona** ubicadas por reglas (cerca de caminos, separadas entre sí).
- El grupo se mueve junto por el mapa del mundo (el host decide; los
  clientes ven el movimiento). Sin combate en el mapa del mundo, salvo
  encuentros aleatorios opcionales **[?]**.
- El lobby actual pasa a ser el **pueblo** inicial dentro del mapa.

## 2. Zonas

Cada zona tiene: tipo, rango de nivel, cantidad de pisos (2–5), generador
por piso, tabla de enemigos por piso y jefe en el último.

| Tipo | Generador | Idea |
|---|---|---|
| Bosque / pradera | ruido + caminos | campo abierto con arboledas que forman pasillos naturales |
| Cavernas | autómata celular | cuevas orgánicas, conectividad asegurada por flood fill |
| Ruinas | salas + pasillos (el `genMap` actual) | el generador del prototipo, intacto |
| Laberinto temporal | laberinto (backtracker) con salas | pasillos de 1–2 tiles, trampas de tiempo |
| Abismo | islas sobre vacío unidas por puentes | caer = volver al inicio del piso |

- **Vaults**: salas diseñadas a mano (archivo de texto con tiles) que el
  generador incrusta con cierta probabilidad; traen cofres/élites.
- Escaleras para bajar de piso; volver a subir permitido.
- Los mapas se generan por semilla y son idénticos para todos los
  jugadores (el host manda la semilla, como hoy).

## 3. Relación con las misiones

Se mantienen mostrador, votación y objetivos; una misión = "andá a la
zona X y cumplí el objetivo en sus pisos". Los objetivos actuales
(grupos, sellos, fragmentos) se reparten entre los pisos y el jefe queda
en el último.

## 4. Decisiones del dueño

1. **Mapa del mundo + zonas con pisos** (§ 1 y § 2).
2. **Se mantienen las misiones**, dentro de las zonas (§ 3).

Valores por defecto (cambiables): sin encuentros aleatorios en el mapa
del mundo; si el grupo cae, la misión falla como hoy (rango D, vuelta al
pueblo).

## 5. Alcance de la v0.2.0

Primer corte jugable del mundo (se publica en la tarde; el resto llega en
las versiones siguientes):
- **Mapa del mundo** completo con el pueblo (el lobby actual: mostrador,
  armería) y las **10 entradas de zona** dibujadas; en la v0.2.0 se
  pueden jugar las **zonas 1–5** (niveles 1–25); las 6–10 se ven
  bloqueadas ("Próximamente").

| # | Zona | Tipo / generador | Niveles | Pisos | Jefe |
|---|---|---|---|---|---|
| 1 | Pradera Esmeralda | bosque / pradera | 1–5 | 2 | Rey Limo |
| 2 | Bosque Hondo | bosque | 6–10 | 3 | Matriarca Araña (nuevo) |
| 3 | Ruinas Cronales | ruinas (genMap actual) | 11–15 | 3 | Gólem Reloj |
| 4 | Cavernas Heladas | cavernas (autómata celular) | 16–20 | 3 | Sierpe de Escarcha (nuevo) |
| 5 | Fortaleza Caída | ruinas + laberinto | 21–25 | 4 | Caballero Hueco (nuevo) |

- **Enemigos comunes por zona** (los existentes + nuevos con sprite
  propio): zona 2 araña y lobo; zona 4 murciélago de hielo y elemental de
  escarcha; zona 5 esqueleto y caballero caído. Stats escalan con el nivel
  de la zona.
- **XP y loot por nivel de zona**: la XP de cada enemigo escala con el
  nivel de la zona para que subir 1–25 lleve una tarde de juego en grupo,
  no días. El nivel de zona reemplaza el "nivel de zona provisorio" de
  loot.md § 20.
- **Misiones**: el mostrador ofrece misiones de las zonas desbloqueadas
  (se desbloquea la siguiente al vencer al jefe de la anterior, por
  perfil); cada misión = la zona completa con sus pisos y el jefe al
  final. Las 3 misiones del prototipo se convierten en las zonas 1, 3 y
  el abismo queda para la zona 10.
- Vaults: 3–4 salas diseñadas a mano por tipo de zona.
- Abismo (islas) y el resto de los generadores llegan con las zonas 6–10.

## 6. Diseño detallado de la v0.2.0 (implementación)

Implementación Dart:
- Zonas: `lib/game_engine/models/zone_def.dart` (`ZoneDef`, `ZoneGen`),
  `lib/game_engine/data/zones_catalog.dart` (`kZones`, misiones de zona
  `kZoneMissions` = `kMissions`; `kPrototypeMissions` = las 3 del
  prototipo, solo para tests de paridad).
- Generadores: `lib/game_engine/rules/map_generator.dart`
  (`MapGenerator.overworld`, `MapGenerator.zone`) y
  `lib/game_engine/rules/zone_generators.dart` (pisos, vaults, arena).
- Vaults: `lib/game_engine/data/vaults_catalog.dart` (`kVaults`).
- Reglas de zona (nivel, escalado, XP, desbloqueo):
  `lib/game_engine/rules/zone_rules.dart` (`ZoneRules`).
- Sesión: `SessionEngine` (pisos, escaleras, desbloqueo).

Tests: `test/game_engine/worldgen_test.dart`,
`test/game_engine/zone_rules_test.dart`,
`test/game_engine/zone_mission_test.dart`.

### 6.1 Las 10 zonas (`kZones`)

| # | id | Nombre | Generador | Niveles | Pisos | Jefe | Misión | Tema |
|---|---|---|---|---|---|---|---|---|
| 1 | z1 | Pradera Esmeralda | `pradera` | 1–5 | 2 | reyLimo | `m1` | `pradera` |
| 2 | z2 | Bosque Hondo | `bosque` | 6–10 | 3 | matriarca | `z2` | `bosque` |
| 3 | z3 | Ruinas Cronales | `ruinas` | 11–15 | 3 | golemReloj | `m2` | `ruinas` |
| 4 | z4 | Cavernas Heladas | `cavernas` | 16–20 | 3 | sierpe | `z4` | `cavernas` |
| 5 | z5 | Fortaleza Caída | `fortaleza` | 21–25 | 4 | caballeroHueco | `z5` | `fortaleza` |
| 6 | z6 | Laberinto Temporal | `laberinto` | 26–30 | 4 | hechicera | — | `laberinto` |
| 7 | z7 | Grieta Ígnea | `cavernas` | 31–35 | 4 | bestiaMagma | — | `grieta` |
| 8 | z8 | Cementerio de Eras | `abismo` | 36–40 | 4 | espectroCoronado | — | `cementerio` |
| 9 | z9 | Abismo del Tiempo | `abismo` | 41–45 | 5 | centinela | — | `abismo` |
| 10 | z10 | Corazón del Tiempo | `abismo` | 46–50 | 5 | devorador | — | `corazon` |

- Las zonas sin misión (6–10) son "Próximamente": se ven en el mapa del
  mundo con nombre y niveles y no se pueden proponer.
- Ids de misión: `m1` y `m2` conservan el id del prototipo (Pradera
  Esmeralda y Ruinas Cronales); las nuevas usan el id de la zona. La
  misión `m3` (Abismo del Tiempo) sale del mostrador: vuelve con las
  zonas 9–10.
- Los ids de jefes de las zonas 6–10 son tentativos (solo texto).

### 6.2 Misiones de zona (`kMissions`)

Cada misión de zona es un `MissionDef` con `zone` (1..10), `floors`,
`floorGoal` (grupos a vencer por piso) y `floorGroups` (grupos posibles
por piso). `goal = floorGoal × floors` (lo muestra el mostrador);
`recommendedLevel` = nivel mínimo de la zona.

| Misión | Tipo | Rango | `floorGoal` | Tiempo S | Élite | Extra | Jefe |
|---|---|---|---|---|---|---|---|
| m1 | Exterminio | C | 4 | 600 s | bat | 1 | reyLimo + 2 slime |
| z2 | Exterminio | B | 4 | 900 s | lobo | 1 | matriarca + 2 arana |
| m2 | Recuperación | B | 4 | 900 s | golem | 2 | golemReloj + golem |
| z4 | Recuperación | A | 4 | 960 s | elementalEscarcha | 2 | sierpe + elementalEscarcha |
| z5 | Urgente | A | 4 | 1260 s | caballeroCaido | 2 | caballeroHueco + 2 esqueleto |

Grupos por piso (cada piso suma grupos más duros a los del anterior):
- m1: piso 1 `[slime,slime] [slime,bat] [bat,bat]`; piso 2 además
  `[slime,slime,slime] [slime,bat,bat]`.
- z2: piso 1 `[arana,arana] [lobo] [arana,bat]`; piso 2 además
  `[lobo,arana]`; piso 3 además `[lobo,lobo] [arana,arana,lobo]`.
- m2: piso 1 `[golem] [bat,bat,slime] [golem,slime]`; piso 2 además
  `[golem,bat]`; piso 3 además `[golem,golem] [golem,bat,bat]`.
- z4: piso 1 `[murcielagoHielo,murcielagoHielo] [elementalEscarcha]
  [ghost,murcielagoHielo]`; piso 2 además
  `[elementalEscarcha,murcielagoHielo]`; piso 3 además
  `[elementalEscarcha,elementalEscarcha] [ghost,ghost]`.
- z5: piso 1 `[esqueleto,esqueleto] [caballeroCaido] [esqueleto,ghost]`;
  piso 2 además `[esqueleto,caballeroCaido]`; piso 3 además
  `[esqueleto,esqueleto,esqueleto]`; piso 4 además
  `[caballeroCaido,caballeroCaido] [caballeroCaido,ghost]`.

**Ids de enemigos nuevos** (los define el catálogo de enemigos, no este
módulo): `arana`, `lobo`, `matriarca` (zona 2), `murcielagoHielo`,
`elementalEscarcha`, `sierpe` (zona 4), `esqueleto`, `caballeroCaido`,
`caballeroHueco` (zona 5). Si un id todavía no existe en
`GameCatalog.enemies`, `ZoneRules.resolveEnemy` usa un **reemplazo
provisorio** (`kEnemyFallback`: arana/lobo/murcielagoHielo → bat,
elementalEscarcha/caballeroCaido → ghost, esqueleto → golem, matriarca →
reyLimo, sierpe → golemReloj, caballeroHueco → devorador). Se aplica al
armar la misión (el snapshot ya lleva el id resuelto) y desaparece solo
cuando el id existe.

### 6.3 Nivel de zona, escalado y XP (`ZoneRules`)

- **Nivel de piso** (`f` desde 0, `F` pisos):
  `min + floor((max − min) × (f + 1) / (F + 1))`. Élites: piso + 1
  (tope `max`). Jefe (y su grupo): `max`. Ej. zona 1: pisos 2 y 3, jefe
  5; zona 5: pisos 21, 22, 23, 24, jefe 25.
- **Nivel de loot** = nivel de la batalla (piso / élite / jefe); cofres
  = nivel del piso; arma de fin de misión = `max` de la zona (+1 por la
  fuente, como antes). `MissionRun.zoneLevel` = nivel del piso actual.
  Reemplaza al nivel de zona provisorio de loot.md § 14/§ 20 para las
  misiones de zona (`LootRules.zoneLevel` queda solo para misiones sin
  zona).
- **Stats de enemigos**: cada id tiene un nivel nativo
  (`kEnemyBaseLevel`: el nivel para el que están pensados sus stats del
  catálogo; sin dato, 1). En una batalla de nivel `L`:
  vida y quiebre `× hpScale(L) / hpScale(nativo)` con
  `hpScale(n) = 1 + 0.15 × (n − 1)`;
  ATQ `× atkScale(L) / atkScale(nativo)` con
  `atkScale(n) = 1 + 0.08 × (n − 1)`; nunca baja de los stats del
  catálogo (factor mínimo 1); la velocidad no cambia. Lo aplica la sesión
  justo después de `BattleEngine.start` (`ZoneRules.scaleBattle`); los
  enemigos invocados a mitad de batalla no se escalan.
- **XP**: `round(XP_batalla × xpMult(L))` con
  `xpMult(L) = xpFactor(L) × (1 + 0.75 × clamp((L − 5) / 10, 0, 1))` y
  `xpFactor(L) = 1 + 0.15 × (L − 1)` (progression.md). Créditos sin
  escalar. Simulación (`zone_rules_test`: 5 grupos por piso, media élite
  por piso y el jefe, 2 pasadas por zona, grupos de 14/18/19/24/30 XP
  base y jefes de 72/106/134/180/220): niveles 5, 6 · 9, 10 · 13, 15 ·
  18, 20 · 24, 27 → ~nivel 25 en unas 10 misiones (una tarde).
- Misiones sin zona (`zone == 0`, solo tests): sin escalado ni XP extra
  (nivel de batalla 0), exactamente como el prototipo.

### 6.4 Desbloqueo por perfil

- `PlayerProfile.unlockedZone` (JSON `zu`, 1..10): la zona más alta que
  el jugador puede proponer. Perfil nuevo: 1.
- **Migración** (perfil guardado sin `zu`): `min(5, (nivel − 1) ~/ 5 + 1)`
  (un nivel 8 viejo arranca con las zonas 1–2).
- Al ganar la misión de la zona `z` (jefe vencido), cada jugador de la
  sala con `unlockedZone == z` pasa a `z + 1` (tope 10):
  `ZoneUnlockedEvent(jugador, z + 1)` y mensaje de sistema. El resultado
  guarda `unlocked` (jugador → zona nueva).
- `ProposeMissionAction` de una misión de zona se rechaza si quien
  propone no la tiene desbloqueada o la zona no es jugable. Votar que sí
  no exige desbloqueo (un amigo puede llevar al grupo).

### 6.5 Mapa del mundo (`MapGenerator.overworld()`)

- 80 × 56 tiles, semilla fija `MapGenerator.worldSeed = 20261117`
  (mismo mapa para todos; no viaja por red). Tema `mundo`, `lobby = true`.
- El **pueblo** es el lobby de siempre en las mismas coordenadas (tiles
  0..25 × 0..13: mostrador, armería, estanques, spawn `(13×16, 9×16)`),
  así `WorldRules.nearCounter/nearArmory` no cambian. El muro sur se
  abre en `x = 12..13` (salida del pueblo).
- Afuera: pasto `g`, árboles `T` (ruido de valor), rocas `^` en el borde
  y en manchas, lagos `~`. Entradas de zona en tiles fijos (el jugador
  se para en el tile de abajo, el "frente"):

  | Zona | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
  |---|---|---|---|---|---|---|---|---|---|---|
  | tile | 8,22 | 24,30 | 40,22 | 56,14 | 70,24 | 64,38 | 46,44 | 30,48 | 12,44 | 72,50 |

- Un camino `,` de 2 de ancho sale del pueblo y une las entradas en
  orden (1 → 2 → … → 10); cruza árboles, rocas y agua (puentes). Claro
  de 5 × 3 de pasto alrededor de cada entrada. Flood fill desde el spawn:
  el pasto inalcanzable se vuelve árbol.
- Entrar a una zona = la UI, con E frente a la entrada, propone la misión
  de esa zona (o vota que sí si ya hay una votación por esa misión); el
  resto es la votación y preparación de siempre.

### 6.6 Mapa de una zona: atlas de pisos (`MapGenerator.zone(zona, semilla)`)

- **Un solo `GameMap` por misión** con todos los pisos uno al lado del
  otro (de izquierda a derecha, separados por 18 columnas de muro). Así
  los enemigos de cada piso tienen coordenadas propias, la cámara y la
  colisión no cambian, y lo único que viaja sigue siendo la semilla.
  `GameMap.floors[f]` describe cada piso (rectángulo, spawn, escaleras,
  arena, spots, vaults).
- El piso `f` de la zona `z` se genera con
  `semilla_f = (semilla + 7919 × f + 104729 × z) | 0`.
- Todos los pisos tienen la **arena** de 13 × 13 con barrera `G` como el
  `genMap` (lado `E/W/N/S` al azar, franja reservada de 16): en el último
  piso está el jefe; en los demás la **escalera de bajada `>`** en el
  centro de la arena. La barrera de cada piso se abre cuando el piso está
  despejado (§ 6.7). Desde el piso 2, una **escalera de subida `<`** a 2
  tiles del spawn.
- Generadores (todos llenan la zona fuera de la franja de la arena):
  - `pradera` / `bosque` (ruido + caminos): ruido de valor (celdas de 7
    tiles + detalle de 3) → árbol `#` si supera 0.60 (pradera) / 0.53
    (bosque); lagos `~` en pradera; 5 puntos de paso unidos por caminos
    `,` de 2 de ancho.
  - `cavernas` (autómata celular): 46% muro al azar, 5 pasadas (muro si
    ≥ 5 de sus 8 vecinos son muro), charcos `~` en las cuevas grandes.
  - `ruinas`: el `genMap` actual, intacto (salas + pasillos + arena).
  - `fortaleza` (ruinas + laberinto): laberinto por backtracker con celdas
    de 3 tiles (pasillos `,` de 2 de ancho), 5–7 salas `.` encima y un 10%
    de muros extra abiertos (bucles).
- **Vaults** (`kVaults`, 4 por tipo: `bosque` (zonas 1–2), `ruinas`,
  `cavernas`, `fortaleza`): bloques de texto. Caracteres: `#` muro, `:`
  suelo de vault, `,` camino, `~` agua, `+` abertura (camino), `c` cofre
  (suelo de vault + cofre), `e` élite (suelo de vault + grupo élite
  opcional). Cada piso estampa 1 vault (y otro con 40%) donde no pisa la
  arena ni el spawn (en ruinas, solo sobre muro macizo).
- **Conectividad**: se borran los huecos de menos de 8 tiles; cada
  componente suelto se une al del spawn con un túnel de 1 tile (BFS por
  el camino más corto que no toca la arena). Al final, flood fill desde
  el spawn: lo inalcanzable se vuelve muro. Todo determinístico.
- **Spawn** (pisos no-ruinas): el tile abierto (con sus 8 vecinos
  abiertos, fuera de vaults) más lejano al centro de la arena.
- **Spots**: tiles de suelo alcanzables a más de 10 tiles del spawn, fuera
  de la arena y de los vaults (en ruinas: los del `genMap` menos los
  pisados por vaults).

### 6.7 Misión por pisos (sesión)

- `startMission` de una misión de zona (con `mulberry32(semilla + 7)`):
  por piso, `floorGoal + 3` grupos normales (mismo algoritmo de lugar que
  hoy, con los `floorGroups` del piso), 1 élite opcional por piso (en la
  marca `e` de un vault si hay, si no en un lugar libre) y cofres
  `1 + azar(0..1)` más las marcas `c` de los vaults. El jefe en la arena
  del último piso. Extras (`frag`, `seal`, `elite`) como hoy: fragmentos
  y sellos se reparten entre los pisos (`i % pisos`); `elite` agrega una
  élite más en el último piso.
- Objetivos de la misión: `kills = Σ min(floorGoal, grupos ubicados)` y
  los extras. **Piso despejado**: grupos normales vencidos en ese piso ≥
  su cuota y fragmentos/sellos de ese piso hechos → se abre la barrera de
  la escalera (`StairsOpenedEvent(piso)` + `GateOpenedEvent`). En el
  último piso la barrera del jefe se abre con todos los objetivos (como
  hoy).
- **Escaleras**: tocar `>` (a menos de 10 px del centro) baja a todo el
  grupo al piso siguiente (spawn del piso, posiciones `spawnPos`). Con E
  (`UseStairsAction(down)`, a menos de 24 px): baja en `>` o sube en `<`
  (al volver se aparece 2 tiles debajo de la `>` del piso de arriba).
  Todos cambian de piso juntos, época +1, gracia 2.5 s,
  `FloorChangedEvent`. El host no exige el piso despejado (confía en la
  posición, igual que con la barrera del jefe: la barrera la frena).
- Solo el piso actual tiene IA, contacto, fragmentos y cofres; los
  enemigos de otros pisos esperan quietos.
- Rango S/A/B con el `sTime` de la zona; si el grupo cae, misión fallida
  (rango D) como hoy.

## 7. API para la UI

Nombres estables (la UI puede programar contra esto ya).

### 7.1 Mapas

- `engine.mapFor(session)`: en `lobby`/`prep` (y sin misión) devuelve el
  **mapa del mundo** (`MapGenerator.overworld()`, `map.lobby == true`,
  tema `mundo`); con misión, el **atlas de la zona** (todos los pisos).
  Sigue siendo determinístico por semilla, sin red.
- `GameMap.floors` (`List<MapFloor>`, vacía en el mundo):
  - `index`, `bounds` (`TileRect` del piso dentro del atlas), `level`,
  - `spawn` (`WorldPoint`, llegada bajando), `stairsDown` / `stairsUp`
    (`WorldPoint?`, centro en px del tile `>` / `<`), `returnPoint`
    (llegada subiendo, 2 tiles debajo de `>`), `arena`, `side`, `boss`
    (solo último piso), `spots`, `vaults` (`List<TileRect>`), `last`.
- `GameMap.floorAt(x, y)` (px) → `MapFloor?`; `GameMap.floor(i)`.
- **Minimapa / cámara**: recortar al `bounds` del piso actual
  (`session.mission!.floor`) para no mostrar los otros pisos del atlas.
- `GameMap.entrances` (`List<ZoneEntrance>`, solo el mundo): `zone`
  (1..10), `tx`, `ty` (tile de la entrada), `center` (px), `front` (px
  del tile de abajo, donde se para el jugador).
- `GameMap.zone`: índice de zona del atlas (0 en el mundo / misiones
  viejas).

### 7.2 Zonas y desbloqueo

- `catalog.zones` (`List<ZoneDef>`, las 10 en orden) y
  `catalog.zone(index)`, `catalog.zoneOfMission(missionId)`.
- `ZoneDef`: `index`, `id`, `name`, `gen`, `minLevel`, `maxLevel`,
  `floors`, `bossId`, `theme`, `missionId` (`null` = "Próximamente"),
  `playable`, `levelText` (`"Lv 1-5"`).
- `ZoneRules.zoneList(catalog, profile)` → `List<ZoneStatus>` con
  `zone`, `mission` (`MissionDef?`), `unlocked`, `playable` y
  `label` (`"Próximamente"`, `"Bloqueada: vencé a <jefe> en <zona>"` o
  `""`).
- `ZoneRules.canPropose(catalog, profile, missionId)` → `bool` (lo que
  valida el host). `ZoneRules.unlockedZone(profile)`.
- `PlayerProfile.unlockedZone` (1..10).
- Mostrador: sigue listando `catalog.missions` (ahora las 5 misiones de
  zona, en orden de zona); usar `zoneList` para marcar las bloqueadas.

### 7.3 Interacción en el mapa

- `WorldRules.nearEntrance(map, x, y)` → `ZoneEntrance?` (a menos de
  `WorldRules.entranceRange = 28` px del centro de la entrada). Con E:
  si la zona es jugable y está desbloqueada, `ProposeMissionAction(
  zone.missionId)`; si ya hay votación por esa misión, votar que sí; si
  no, mostrar el cartel (nombre, niveles, "Próximamente"/bloqueada).
- `WorldRules.nearStairs(map, x, y)` → `StairsKind?` (`down` / `up`, a
  menos de `WorldRules.stairsRange = 24` px). Con E:
  `UseStairsAction(down: true/false)`. Bajar también pasa solo al tocar
  `>` (a menos de `SessionEngine.stairsTouch = 10` px).
- `session.gateOpen` ahora es la barrera **del piso actual** (escalera o
  jefe). `session.mission!.floorOpen(f)`.

### 7.4 Estado nuevo de la sesión (todo serializa)

- `MissionRun`: `floor` (piso actual, desde 0), `floors`, `floorGoals`
  (cuota por piso), `levels` (nivel por piso), `opened` (pisos con la
  barrera abierta), `zone`; métodos `enemiesOn(f)`, `itemsOn(f)`,
  `floorKills(f)`, `floorCleared(f)`, `floorOpen(f)`; `isLastFloor`.
- `FieldEnemy.floor`, `MissionItem.floor` (dibujar solo los del piso
  actual; están en coordenadas del atlas, así que dibujar todos tampoco
  rompe).
- `SessionBattle.level` (nivel de los enemigos de la batalla; 0 = sin
  escalar) para mostrar "Lv N" en la batalla.
- `MissionResult.zone`, `MissionResult.unlocked` (`Map<jugador, zona>`).

### 7.5 Acciones y eventos nuevos

- Acción `UseStairsAction(down)` (JSON `{'t':'stairs','down':bool}`).
- `FloorChangedEvent(floor, down)` (JSON `floor`): el grupo cambió de
  piso (sonido de escalera, cartel "Piso 2/3").
- `StairsOpenedEvent(floor)` (JSON `stairs`): se despejó el piso (viene
  junto con `GateOpenedEvent`).
- `ZoneUnlockedEvent(playerId, zone)` (JSON `zoneUnlocked`).

### 7.6 Tiles nuevos (`Tile`)

| Char | Constante | Dónde | Sólido | Cómo se ve |
|---|---|---|---|---|
| `g` | `Tile.grass` | mundo | no | pasto: verde claro con matas, sin cuadriculado de lobby |
| `T` | `Tile.tree` | mundo | sí | árbol (como el `#` de pradera: copa redonda y tronco) |
| `^` | `Tile.rock` | mundo | sí | roca / montaña gris con nieve arriba |
| `1`..`9`, `0` | `Tile.entrance(z)` / `Tile.entranceZone(ch)` | mundo | sí | portal/arco de piedra de la zona (`0` = zona 10); color por zona; bloqueada: gris con candado |
| `>` | `Tile.stairsDown` | pisos | no | escalera que baja (agujero oscuro con peldaños) |
| `<` | `Tile.stairsUp` | pisos 2+ | no | escalera que sube (peldaños claros) |
| `:` | `Tile.vaultFloor` | vaults | no | baldosa de bóveda: suelo del tema con borde dorado tenue |

Temas nuevos (`GameMap.theme`, la UI los resuelve; sin color propio usa
pradera): `mundo` (pasto, árboles, rocas; el pueblo con `.`/`,`/`#` en
estilo lobby), `bosque` (verde oscuro, árboles densos), `cavernas`
(hielo: suelo azul grisáceo, muros de roca helada, agua cian),
`fortaleza` (piedra oscura, caminos de losa). Los de zonas 6–10
(`laberinto`, `grieta`, `cementerio`, `corazon`) todavía no se usan.
