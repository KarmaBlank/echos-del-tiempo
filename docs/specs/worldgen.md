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
| 6 | z6 | Laberinto Temporal | `laberinto` | 26–30 | 4 | hechicera | `z6` | `laberinto` |
| 7 | z7 | Grieta Ígnea | `grieta` | 31–35 | 4 | bestiaMagma | `z7` | `grieta` |
| 8 | z8 | Cementerio de Eras | `cementerio` | 36–40 | 4 | espectroCoronado | `z8` | `cementerio` |
| 9 | z9 | Abismo del Tiempo | `abismo` | 41–45 | 5 | centinela | `z9` | `abismo` |
| 10 | z10 | Corazón del Tiempo | `corazon` | 46–50 | 5 | devorador | `z10` | `corazon` |

- (v0.2.0; desde la v0.3.0 las 10 son jugables, § 8.1) Las zonas sin misión (6–10) son "Próximamente": se ven en el mapa del
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
  vida `× hpScale(L) / hpScale(nativo)` con la curva por tramos de
  combo_balance.md § 1 (v0.9; antes `hpScale(n) = 1 + 0.15 × (n − 1)`,
  y el quiebre ya no escala: va en puntos, combo_balance.md § 5);
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

> Retirado en v0.21.0: el lobby es el pueblo (`MapGenerator.town()`) y las
> zonas se eligen en el tablero (town_loop.md § 11.2). Lo que sigue queda
> como historia.

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

### 6.8 Misiones cortas (v0.20.22)

Pedido del dueño: una misión dura unos 10 a 12 minutos. Tres números de
Editor → Balance (grupo `Misiones`, `TuningId.mission`):

- `maxFloors` (3): tope de pisos que se juegan por misión
  (`ZoneRules.missionFloors`). Las zonas de 4 y 5 pisos juegan 3; el
  nivel de cada piso se reparte con ese número (§ 6.3) y cada piso jugado
  usa los `floorGroups` de un piso de la definición
  (`ZoneRules.sourceFloor`: el primero, el último y los del medio
  repartidos). Jefe, élites guardianes y sellos no cambian de regla (los
  sellos y fragmentos se reparten entre los pisos jugados).
- `groupScale` (0.7): grupos normales por piso
  `max(floorGoal, round((floorGoal + 3) × groupScale))` en vez de
  `floorGoal + 3` (`ZoneRules.groupsPerFloor`). La cuota del piso no cambia.
- `areaScale` (0.7): el área de los pisos orgánicos (todos menos ruinas)
  se multiplica por la escala (cada lado × raíz de la escala, mínimo 44 ×
  32). Las mismas tiradas del azar: la semilla sigue armando el mismo
  estilo de mapa, más chico.

- Rango S (missions.md): el `sTime` de la misión se multiplica por
  `(pisos jugados / pisos definidos) × (grupos por piso / (floorGoal + 3))`
  (tope 1; `ZoneRules.sTimeFor`), así S no es más fácil. A = 1.5 × eso.

- Densidad de PdI (§ 11.2) en pisos chicos: los lugares de cofre ya no
  paran en el tope por área (`área ÷ 100`); siguen (hasta 3× el tope)
  mientras haya un tile a más del `gap` o falte un PdI cada 220 tiles
  (`kPoiDensityArea`). Si el lugar cómodo más cercano queda lejos, vale
  uno de pasillo (1 vecino caminable) o sobre un puente.

Ecos, Pruebas y Jefes del Abismo usan el mismo atlas y también se
achican. La Travesía tiene su propio generador y no cambia.

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
- **Loot del suelo por piso** (v0.5.1, loot.md § 14.1): cada objeto
  queda en el piso donde cayó (`GroundLoot.floor`); solo el del piso
  actual se ve y se levanta, y reaparece al volver. Al cambiar de piso,
  aviso en el chat con lo que cada uno dejó atrás y su filtro muestra
  (`Quedan N objetos en el piso K.`).
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

## 8. Alcance de la v0.3.0 (zonas 6–10)

Completa el mundo: las zonas 6–10 pasan a jugables y el Devorador de
Eras queda como jefe final (2 fases).

| # | Zona | Tipo / generador | Niveles | Pisos | Jefe (id) |
|---|---|---|---|---|---|
| 6 | Laberinto Temporal | laberinto (backtracker con salas) | 26–30 | 4 | Hechicera del Eco (`hechicera`) |
| 7 | Grieta Ígnea | cavernas de lava (autómata + ríos de lava) | 31–35 | 4 | Bestia de Magma (`bestiaMagma`) |
| 8 | Cementerio de Eras | abismo (islas + puentes) con lápidas | 36–40 | 4 | Espectro Coronado (`espectroCoronado`) |
| 9 | Abismo del Tiempo | abismo (islas flotantes, caídas) | 41–45 | 5 | Centinela del Vacío (`centinela`) |
| 10 | Corazón del Tiempo | abismo final (islas + arena central) | 46–50 | 5 | Devorador de Eras (`devorador`, 2 fases) |

Enemigos comunes nuevos (ids fijos; stats a nivel mínimo de su zona,
jefes a nivel máximo):
- Zona 6: `ecoSombra` (copia sombría, esquiva), `guardianReloj`
  (constructo, retrasa).
- Zona 7: `salamandra` (Quemadura), `golemMagma` (tanque, Quemadura).
- Zona 8: `necrofago` (Veneno, perforante), `almaErrante` (Congelación,
  flota).
- Zona 9: `vigilanteVacio` (marca objetivos), `ojoAbismo` (flota,
  aturde).
- Zona 10: `heraldoEras` (élite natural, mezcla de estados) y
  `fragmentoTiempo` (rápido, retrasa).

Caer al vacío en las zonas de abismo devuelve al punto de llegada del
piso (sin daño en esta versión). Cada zona tiene música propia y el
jefe final su variante del tema de jefe.

### 8.1 Diseño detallado de la v0.3.0 (implementación)

- **Generadores** (`ZoneGen`, se agregan `grieta`, `cementerio`,
  `corazon`; los demás no cambian y la v0.2 sigue generando los mismos
  mapas con la misma semilla):

  | Zona | `gen` | Tamaño de piso | Qué hace |
  |---|---|---|---|
  | 6 | `laberinto` | 70–80 × 50–56 | backtracker de celdas de 3 (pasillos `,` de 2), solo 4% de bucles y 2–3 cámaras `.`; vaults de relojería |
  | 7 | `grieta` | 58–70 × 42–50 | autómata celular de cavernas; charcos de **lava** `%` en vez de agua y 1–2 **ríos de lava** de 2 de ancho que cruzan la región; los cruza un **puente** `=` (los túneles de conexión sobre lava son puentes) |
  | 8 | `cementerio` | 58–70 × 42–50 | abismo (como 9) + **lápidas** `t` sueltas en las islas (nunca dos juntas: no cortan caminos) |
  | 9 | `abismo` | 58–70 × 42–50 | **islas** (elipses irregulares, una por celda de una grilla ~13 × 11) sobre **vacío** `_`, unidas por **puentes** `=` de 2 de ancho (árbol mínimo entre centros) |
  | 10 | `corazon` | 70–80 × 50–56 | abismo con la **arena en el centro** del piso (isla de 13 × 13 rodeada de vacío; barrera hacia un lado al azar); en el último piso, el Devorador |

- En los pisos de abismo (`abismo`, `cementerio`, `corazon`) todo el muro
  `#` fuera de vaults y de los pilares de la arena se vuelve vacío `_`: la
  arena es una isla rodeada de vacío con la única entrada por la barrera.
  Los túneles de conexión del § 6.6 son puentes `=` (de 2 de ancho).
- **Conectividad** igual que § 6.6, contando el vacío y la lava como no
  caminables: desde el spawn se llega a todo suelo/puente sin pisar vacío.
- **Caída** (§ 8): pisar el vacío (el tile bajo el centro del personaje es
  `_`) devuelve a ese jugador al **spawn del piso actual** (`MapFloor.spawn`,
  la llegada bajando), sin daño. Lo resuelve el host en cada tick de campo.
  Los enemigos nunca entran al vacío (para ellos es sólido).
- **Vaults nuevos** (`kVaults`): `laberinto` (relojería: engranajes `o`),
  `grieta` (lava `%` y puentes `=`), `abismo` (islotes; también para
  `corazon`) y `cementerio` (lápidas `t`). Caracteres extra en vaults: `_`
  vacío, `=` puente, `%` lava, `t` lápida, `o` engranaje; el borde de un
  vault puede ser `#`, `+` o `_`.
- **Misiones** `z6`..`z10` (id = zona; la `m3` del prototipo no vuelve:
  el Abismo del Tiempo es `z9`). Rango A, `floorGoal` 4, `extra` 2, `sTime`
  1320 / 1380 / 1440 / 1680 / 1800 s. Grupos por piso con los comunes `A`/`B`
  de la zona (z6 ecoSombra/guardianReloj, z7 salamandra/golemMagma, z8
  necrofago/almaErrante, z9 ojoAbismo/vigilanteVacio, z10
  fragmentoTiempo/heraldoEras): piso 1 `[A,A] [B] [A,B]`; piso 2 además
  `[B,B]`; piso 3 además `[A,A,A]`; piso 4 además `[B,A,A] [B,B,A]`; piso 5
  además `[B,B,B]`. Élite: guardianReloj, golemMagma, necrofago,
  vigilanteVacio, heraldoEras. Jefe + 2 comunes (hechicera + 2 ecoSombra,
  bestiaMagma + 2 salamandra, espectroCoronado + 2 almaErrante,
  centinela + 2 ojoAbismo, devorador + 2 fragmentoTiempo).
- **Niveles nativos** (`kEnemyBaseLevel`): comunes 26 / 31 / 36 / 41 / 46,
  jefes 30 / 35 / 40 / 45 / 50 (el Devorador pasa de 9 a 50: sus stats del
  catálogo ahora son de nivel 50). Invocaciones de jefe `ecoHechicera` 30 y
  `siervoEspectral` 40 (nunca en el campo). `kEnemyFallback` cubre los ids
  nuevos por si un catálogo reducido no los tiene.
- **XP**: el bonus del mundo (§ 6.3) baja desde el nivel 30 hasta 1.3 en el
  50: `worldBonus(L) = 1 + 0.75 × clamp((L − 5)/10) − 0.45 × clamp((L − 30)/20)`.
  Simulación (`zones_v03_test`: 2 pasadas por zona, 5 grupos por piso con
  la XP del catálogo, media élite por piso ×3 y el jefe con su grupo):
  niveles al terminar cada pasada 5, 6 · 8, 10 · 13, 15 · 17, 20 · 23, 26 ·
  29, 32 · 34, 37 · 39, 41 · 43, 46 · 48, **50** → el 50 llega con la segunda
  pasada del Corazón del Tiempo (~20 misiones).
- **Legendario del jefe**: al vencer a un jefe con `EnemyDef.legendaryId`,
  cada jugador tiene `SessionEngine.bossLegendaryChance = 0.10` de recibir
  además ese único (nivel de la batalla; `LootDropEvent` con fuente
  `boss`), aparte del botín normal del jefe.

## 9. API v0.3 para la UI

Nombres estables (la UI puede programar contra esto ya).

### 9.1 Tiles nuevos (`Tile`)

| Char | Constante | Dónde | Sólido | Cómo se ve |
|---|---|---|---|---|
| `_` | `Tile.voidTile` | abismo, cementerio, corazón | **no** (se cae) | vacío: negro azulado con estrellas / motas de tiempo que derivan; borde de las islas con canto de roca que cuelga |
| `=` | `Tile.bridge` | abismo* y grieta | no | puente: tablones con cuerdas (abismo, cementerio), piedra rúnica (corazón), basalto enfriado (grieta) |
| `%` | `Tile.lava` | grieta | sí | lava animada naranja/roja con brillo (ríos y charcos) |
| `t` | `Tile.tombstone` | cementerio (pisos y vaults) | sí | lápida gris con musgo / cruz |
| `o` | `Tile.gear` | vaults del laberinto | sí | engranaje / reloj de pie de bronce |

- `Tile.solidTiles` (`Set<String>`) y `Tile.isWalkable(c)`; el vacío es
  caminable para el jugador y sólido para los enemigos.
- En los temas de abismo el `#` que queda es pilar / muro de vault /
  pilares de la arena: dibujarlo como roca flotante.

### 9.2 Temas (`GameMap.theme`)

`laberinto` (piedra azul pizarra, bronce, pasillos de losa), `grieta`
(basalto oscuro, suelo de ceniza, lava), `cementerio` (islas de tierra
gris con pasto seco sobre vacío violeta), `abismo` (islas de roca
flotante sobre vacío azul profundo), `corazon` (cristal dorado / blanco
sobre vacío, arena central con círculo rúnico). Sin color propio, la UI
puede usar el de `fortaleza` (laberinto), `cavernas` (grieta) o `abismo`.

### 9.3 Vacío y caída

- `WorldRules.isVoid(map, tx, ty)` y `WorldRules.overVoid(map, x, y)`
  (px; el tile bajo el centro es `_`): para animar la caída en el cliente
  si se quiere. `WorldRules.stepPlayer` deja caminar sobre el vacío (no
  hay que cambiar el movimiento del cliente).
- `WorldRules.isSolid/collides/move(..., blockVoid: true)`: el vacío
  como sólido (lo usan los enemigos y los tests).
- El host, al ver a un jugador vivo en campo sobre el vacío, lo lleva al
  spawn del piso actual (época +1, como al cambiar de piso: el cliente
  adopta la posición nueva) y emite
  **`FellIntoVoidEvent(playerId, floor)`** (JSON
  `{'t':'fall','id':…,'f':…}`) + mensaje de sistema
  `"<nombre> cayó al vacío."`. Sin daño. Sugerido: sonido de caída y
  fundido corto.

### 9.4 Zonas

- Las 10 zonas son jugables (`ZoneDef.playable`); el mostrador lista
  `m1, z2, m2, z4, z5, z6, z7, z8, z9, z10`. Desbloqueo igual que § 6.4
  hasta la zona 10. `ZoneDef.gen` de 7–10: `grieta`, `cementerio`,
  `abismo`, `corazon`.

## 10. Ecos (v0.4.0)

Los Ecos reusan los generadores de zona (docs/specs/ecos_atlas.md § 4):
`EcoRules.zoneDef` arma un `ZoneDef` sintético con el generador y el
tema de la zona del Eco, sus pisos (1–3) y el nivel de monstruo del
tier (`48 + 2 × tier`) en todos los pisos; `MapGenerator.zone` con la
semilla del Eco. La misión (`EcoRules.missionDef`, id `eco`) usa los
grupos del último piso de la misión de esa zona y el grupo del jefe de
la zona del jefe del Eco. `MissionRun.zone` = la zona del Eco (música y
tema), pero un Eco **no** desbloquea zonas. Vencer la zona 10 activa el
Portal del Eco (§ 1 del spec).

## 11. Exploración v0.6 (densidad de interés, traversal y misiones opcionales)

Pedido del dueño (backlog_v0.6.md § 1): "los mapas son muy grandes, por
ejemplo el Laberinto del Tiempo. Me gustaría que en los mapas haya cosas,
algo que te incentive a explorar; los cofres a veces dan cosas pero
siempre solo dinero o pociones". Aclaraciones del dueño durante el
diseño:
- "Los mapas no necesariamente más chicos": el problema es el espacio
  **vacío**, no el tamaño. Se mantienen los tamaños (único recorte
  justificado: el Laberinto, § 11.1) y se reparte contenido.
- "Pueden ser grandes, pero que haya algo que ayude al traversal, o que
  el mapa esté más lleno de cosas, o quests opcionales, pero que sean
  buenas para que el jugador sienta recompensa buena" → § 11.4 y § 11.8.
- "Sin historia por ahora": **no hay lore**. Ningún texto de historia en
  el código; las misiones y los PdI tienen descripciones solo
  funcionales. *Pendiente: lore del dueño* (objetos de inscripción, se
  agregan cuando haya textos aprobados).

Implementación: números en `lib/game_engine/data/exploration_catalog.dart`;
generación en `lib/game_engine/rules/poi_generator.dart`
(`PoiGenerator.place`, lo llama `ZoneGenerators` en cada piso); reglas
puras en `lib/game_engine/rules/exploration_rules.dart`
(`ExplorationRules`); estado y premios en `SessionEngine`. Tests:
`test/game_engine/exploration_test.dart` (densidad, PdI, determinismo,
recorte del laberinto, Pruebas) y
`test/game_engine/exploration_session_test.dart` (interacción, premios,
guardianes, red).

### 11.1 Tamaño de los pisos (medido) y único recorte

Medido con 20 semillas por zona antes de v0.6 (BFS desde el spawn con la
barrera abierta; jugador a 78 px/s ≈ 4.9 tiles/s):

| Zona | Piso medio | Área caminable media (máx.) | Spawn → arena media (máx.) | Tile más lejano |
|---|---|---|---|---|
| 1 pradera | 64 × 46 | 1312 (1684) | 74 (96) | 89 |
| 2 bosque | 64 × 46 | 1144 (1469) | 79 (108) | 94 |
| 3 ruinas | 67 × 49 | 1052 (1208) | 75 (99) | 90 |
| 4 cavernas | 63 × 45 | 1018 (1450) | 77 (97) | 91 |
| 5 fortaleza | 64 × 46 | 1186 (1510) | 77 (135) | 95 |
| 6 laberinto | 74 × 53 | 1630 (1931) | 97 (218) | **163** |
| 7 grieta | 64 × 46 | 1056 (1367) | 81 (121) | 101 |
| 8 cementerio | 65 × 46 | 775 (927) | 80 (109) | 95 |
| 9 abismo | 64 × 45 | 684 (868) | 73 (111) | 90 |
| 10 corazón | 74 × 53 | 1258 (1489) | 86 (206) | 144 |

Todos los tamaños quedan igual **menos el Laberinto Temporal**, el único
claramente sobredimensionado y vacío (tile más lejano a 163 pasos,
callejones sin salida de 30+ tiles con 4% de bucles):
- Tamaño 64–72 × 46–52 (antes 70–80 × 50–56): ~15% menos de área.
- Bucles 12% (antes 4%) y 3–4 cámaras (antes 2–3): menos callejones; el
  camino al jefe ya no da vueltas de 200 tiles (test: ≤ 160).
- Las Pruebas I (laberinto) y III (corazón) siguen ubicando todas sus
  trampas (test).

### 11.2 Densidad de interés (objetivo medible)

Un **punto de interés** (PdI) es lo que premia ir hasta ahí: un cofre
(lugar de cofre o marca `c`), una sala secreta, un santuario, una piedra
de paso, el Viento del Eco, un atajo, un brasero o la reliquia de una
misión opcional, la marca `e` de un vault (élite guardián), la escalera
o la barrera. Objetivos (test, 20 semillas por zona, todos los pisos):
- Desde **cualquier tile caminable** hay un PdI a ≤ `kMaxPoiGap` = **18
  pasos** (BFS, ~3.7 s caminando); en el laberinto ≤ `kMaxPoiGapMaze` =
  **22** (pasillos de 2). Antes había rincones a 60+ pasos de todo.
- ≥ 1 PdI cada 220 tiles caminables, ≥ 2 lugares de cofre y 1–2 misiones
  opcionales por piso; más de medio piso con sala secreta en promedio.

Medido después (promedio por piso): lugares de cofre 3–7 (más en los
pisos grandes: fortaleza 6.8, laberinto 6.2, corazón 6.3; abismo 3),
PdI del mapa 2.3–6.8, misiones 1–2, piedras de paso 0–2.4, salas
secretas 0.8–1.8.

Cómo se logra (todo en el generador del piso con su propio azar
`mulberry32(semilla_f ^ 0x9E37)`: el mapa sigue saliendo de la semilla,
no viaja nada por red):
1. Salas secretas, atajo, santuario, piedras, viento y misiones (§ 11.3,
   § 11.4, § 11.8) con cantidad según el área.
2. **Lugares de cofre** (`MapFloor.chestSpots`) por muestreo del punto
   más lejano: mientras el tile caminable más lejano (BFS) a todo PdI
   esté a más del objetivo, se pone un lugar de cofre ahí (o en el tile
   más cercano a él que sirva: suelo/camino fuera de arena y vaults con 3
   de 4 vecinos libres). Mínimo 2, tope `área ÷ 100`.
3. La sesión pone un cofre en cada lugar (reemplaza a los `1 + azar(0..1)`
   cofres al azar de § 6.7; los extra del Atlas siguen al azar).

### 11.3 Puntos de interés del mapa

`MapFloor.pois` (`List<MapPoi>`): `id` (único en el atlas: `piso × 100 +
k`), `kind` (`PoiKind`), `tx`, `ty` (tile del objeto), `floor`, `variant`
(bendición), `room` y `chest` (sala secreta), `side` (atajo), `quest`
(brasero / reliquia). Todos los objetos son tiles sólidos (no cortan
caminos: un tile rodeado de suelo, ≥ 6 de otro objeto, ≥ 8 del spawn y
≥ 4 de las escaleras), salvo la reliquia (se pisa).

| PdI | Cantidad por piso | Tile |
|---|---|---|
| Sala secreta | 1 + 1 si el área ≥ 1100 (cada una 80%) | pared `K`, interior `k` (se ve y colisiona como muro) |
| Atajo | 0–1 (no en abismo) | `J` (cerrado); abierto `,` |
| Santuario de bendición | 0–1 (60%) | `H`; usado `h` |
| Piedra de paso | 2 desde área 900, 3 desde 1300 | `W`; activada `w` |
| Viento del Eco | 0–1 (70%) desde área 1000 | `V` |
| Brasero / reliquia | los de su misión opcional (§ 11.8) | `B` / encendido `b`; reliquia sin tile |

- **Sala secreta**: se prueban (en orden aleatorio) muros con un solo
  vecino caminable (4 direcciones), a ≥ 6 del spawn y de las escaleras,
  con la sala de 4 × 3 + 1 de margen entera sobre muro macizo `#` (en
  abismo también vale el vacío: queda un bloque de roca flotante pegado a
  la isla y no se vuelve vacío). Fuera de la arena (+2) y de los vaults
  (+1). La pared es `K`; el interior `k` se dibuja como muro hasta abrirla
  (no se delata); el cofre (reforzado 60% / dorado 40%) va en el centro y
  no se dibuja hasta abrirla. Sin spots adentro (ni enemigos, ni trampas).
- **Atajo**: el muro de 1 tile de grosor (vecinos opuestos caminables,
  los otros dos muro) que más camino ahorra entre sus dos lados, si
  ahorra ≥ `kShortcutMinSaving` = 40 pasos (en la práctica: fortaleza y
  laberinto). Se abre con E **desde el lado lejano** (`MapPoi.side`, a
  menos de 22 px de ese tile): un "atajo de vuelta" que conecta lo
  explorado con el inicio.
- **Usar** (E a menos de `ExplorationRules.poiRange = 26` px del centro
  del tile): `InteractPoiAction(poiId)`. El host valida campo, piso
  actual, jugador vivo y que sea el PdI usable más cercano.
- **Mapa con estado** (`SessionEngine.mapFor`): mapa base de la semilla +
  PdI usados (`K`/`k` → `:`, `J` → `,`, `H` → `h`, `W` → `w`, `B` → `b`),
  con caché por mapa base y conjunto usado. Cliente y host colisionan y
  dibujan sobre ese mapa, sin tocar `WorldRules`.

### 11.4 Traversal: piedras de paso, Viento del Eco y atajos

- **Piedras de paso**: la primera a ≤ 5 tiles del spawn, las otras por
  punto más lejano (≥ 25 pasos entre ellas). E sobre una sin activar la
  **activa** (para todos). E sobre una activada con al menos otra
  activada abre el **mapa en grande en modo "elegir destino"** (v0.20.6,
  exploration.md § "Mapa en grande"): se puede viajar a **cualquiera** de
  las otras piedras **activadas** del piso (`ExplorationRules.
  waystoneDestinations`, en el orden del piso), no solo a la siguiente.
  El cartel dice `[E] Elegir destino en el mapa` (o `Piedra de paso:
  activá otra para viajar` si es la única activada).
  - Acción: `InteractPoiAction(poiId, toPoi:)` (en red `{'t':'poi',
    'id', 'to'}`, protocolo 31). Sin `toPoi` viaja a la siguiente activada
    (`nextWaystone`, como antes).
  - El **host valida**: modo campo (no en batalla, preparación ni
    resultado), jugador vivo, piso actual, que `poiId` sea el PdI usable
    más cercano al jugador (está junto a la piedra de origen), que el
    origen esté activado y que `toPoi` sea otra piedra activada del mismo
    piso. Si algo falla, no pasa nada.
  - **Solo viaja quien la usa** (sin votación; en co-op cada uno va y
    vuelve; el compañero se queda donde está): el host lo pone al lado de
    la piedra de destino, época +1, y todos lo ven moverse por el estado.
    Evento `PoiUsedEvent(..., toPoi)`.
- **Viento del Eco**: santuario reusable. E → todo el grupo camina un
  **+40%** (`kWindSpeed = 1.4`) por **60 s** (`MissionRun.windUntil`, reloj
  de la sala). Lo aplica el cliente al moverse
  (`ExplorationRules.speedMult` → `WorldRules.stepPlayer(speedMult:)`); el
  host ya confía en la posición. Usarlo de nuevo renueva los 60 s. HUD:
  `» Viento del Eco 42 s`.
- **Atajos**: § 11.3.
- **Minimapa**: los PdI se marcan al **descubrirlos** (a menos de
  `ExplorationRules.discoverRange = 80` px de un jugador vivo;
  `MissionRun.poiSeen`), sin revelar el resto (§ 11.7).

### 11.5 Bendiciones de santuario

Una sola activa por misión (`MissionRun.blessing`): un santuario nuevo la
reemplaza. Dura hasta el final de la misión. Todo el grupo.

| `BlessingKind` | Nombre | Efecto |
|---|---|---|
| `fuerza` | Bendición de Fuerza | +10% ATQ y +10% MAG en batalla |
| `vigor` | Bendición de Vigor | cura vida y maná del grupo al activarla; +3% de vida por turno en batalla y regeneración ×3 en el campo |
| `fortuna` | Bendición de Fortuna | +0.5 al bonus de rareza del loot y 30% de una tirada extra por fuente |
| `reloj` | Bendición del Reloj | +25% carga de ULT y +5% crítico en batalla |

- En batalla, implícito extra del arma equipada
  (`ExplorationRules.blessedBuild`, desde `SessionEngine.partyMember(p,
  blessing:)`): sale en el desglose y no toca el motor de combate.
- El tipo es parte del mapa (`MapPoi.variant`): el cartel
  `[E] Santuario: Bendición de Fuerza (+10% ATQ y MAG)` lo dice antes.
- HUD: `♦ Bendición de Fuerza` en la caja de objetivos.

### 11.6 Élites guardianes

- La élite opcional de cada piso (§ 6.7) **custodia un tesoro**: los
  cofres del vault de su marca `e` quedan con `guard` = su id y pasan a
  **dorados**. Si ningún cofre quedó custodiado, se agrega un cofre
  dorado a 1–2 tiles de su lugar.
- Un cofre custodiado no se abre mientras su guardián vive (se dibuja con
  candado y sin destello); al vencerlo se abre tocándolo.

### 11.7 Minimapa y HUD

- El minimapa sigue mostrando el piso entero, pero los PdI **no** se ven
  hasta descubrirlos: `K`/`k`/`J` se pintan como muro y los objetos como
  suelo. Descubiertos (un punto): sala secreta violeta (gris abierta),
  santuario turquesa (gris usado), piedra gris (dorada activada), viento
  celeste, atajo naranja (gris abierto), brasero beige (naranja
  encendido), reliquia ámbar. Cofres dorados: punto más grande; el de
  una sala secreta, recién al abrirla.
- Caja de objetivos (debajo de lo de siempre): resumen del piso
  `Cofres 2/4 · Secretos 0/1` (cofres abiertos / cofres del piso fuera de
  salas secretas; salas abiertas / salas del piso; sin salas, solo
  `Cofres a/b`), la bendición, el Viento y las misiones opcionales
  (§ 11.8). `ExplorationRules.floorSummary`.

### 11.8 Misiones opcionales de piso

1 por piso, 2 desde área 1000 (`kSecondQuestArea`). Las elige el
generador del piso (sin repetir) entre las que el piso permite; su
premio principal también sale de la semilla. Progreso **compartido**
(se calcula del estado de la misión: `ExplorationRules.questProgress`);
al cumplirse, **cada jugador** recibe su propio premio.

| `QuestKind` | Texto (HUD) | Meta | Se puede si… |
|---|---|---|---|
| `braseros` | Encendé los braseros | 3 braseros (E) a ≥ 10 tiles entre sí | entran los 3 |
| `reliquia` | Encontrá la reliquia perdida | tocar la reliquia (en el 20% de tiles más lejanos del spawn) | siempre |
| `guardian` | Derrotá al guardián antes de bajar | vencer a la élite del piso; **falla** si el grupo baja con ella viva | no es el último piso |
| `limpieza` | Derrotá a todos los grupos del piso | todos los grupos normales del piso | siempre |
| `secreto` | Abrí la sala secreta | abrir las salas del piso | hay sala |
| `cofres` | Abrí todos los cofres del piso | todos los cofres del piso (secretos incluidos) | siempre |

- HUD: `• Opcional: Encendé los braseros 1/3`; cumplida en verde con `>`;
  fallida en gris con `x`. Al cumplirse: `QuestDoneEvent(questId, floor,
  kind)` → fanfarria (el jingle de subir de nivel) y cartel
  `¡Misión opcional cumplida!` con el texto; en el chat
  `¡Misión opcional cumplida: …!` y lo que recibió cada uno.
- **Premio** (loot.md § 23.3), por jugador: el principal (`QuestReward`:
  arma 55% / Eco 25% / bendición 20%; el Eco cae a arma bajo nivel 45) +
  materiales + créditos. Siempre al inventario (fuente `mission`).
- Las descripciones son funcionales (sin historia).

### 11.9 Estado en la sesión y red (host autoritativo)

- `MissionRun`: `poiUsed` (`Set<int>`, JSON `pu`), `poiSeen` (`ps`),
  `questsDone` (`qd`), `questsFailed` (`qf`), `blessing` (`bl`),
  `windUntil` (`wind`). Aditivos: sin las claves = nada usado.
- `MissionItem`: `tier` (`ChestTier`, `tr`, se omite `madera`), `guard`
  (`gd`), `secret` (id del PdI de su sala, `sc`).
- Acción `InteractPoiAction(poiId)` → `{"t":"poi","id":101}`.
- Eventos `PoiUsedEvent(playerId, poiId, kind, blessing?, toPoi?)` →
  `{"t":"poi","id":"p1","poi":101,"k":"shrine","bl":"fuerza","to":3}` y
  `QuestDoneEvent` → `{"t":"quest","q":150,"f":1,"k":"braseros"}`.
  `ChestOpenedEvent` suma `tr`.
- `kProtocolVersion` = **7** (`wire.dart`).
- Sonidos (reusa los que hay): fanfarria `levelUp` al cumplir una misión;
  romper pared / atajo `boss.crystal`, santuario `heal.sparkle`, viento
  `proc.wind`, piedra `asc.reveal`, brasero `proc.flare`, reliquia
  `loot.pickup`.
- Pendiente (no v0.6): lore del dueño (inscripciones); atajos de un solo
  sentido "de caída" entre pisos; exponer estos números en el admin de
  balance (hoy viven en el catálogo).
