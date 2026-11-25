# Exploración de biomas v2 (protocolo 82)

Los exteriores de bioma (biome_regions.md) crecen: lo de siempre (llegada,
plaza, las dos entradas y sus portales, a ~5 s de caminata) queda igual
en el **frente**, y alrededor se abren las **tierras salvajes**: secciones
grandes donde uno se puede perder, con contenido nuevo cada día.

Código: `lib/game_engine/rules/biome_wilds.dart` (generador de las
secciones), `biome_regions.dart` (`BiomeLayout`, ahora con `sections`,
`caverns`, `beams`, `shrines`, `exploreSpots`, `chestSpots`),
`world_event_rules.dart` (`exploreRoll`, contenido por día),
`wild_loot_rules.dart` (cofres y santuarios), `region_light_layer.dart`
(luz en grutas). Tunables en
`kTuning[TuningId.regions]` (prefijo `wild*`, `explore*`).

## 0. Diagnóstico de "los biomas siguen igual de chicos"

El plano **no se guarda** en el mundo: sale de `(bioma, town.sky.seed)` en
cada carga (biome_regions.md § 1). Seguía chico porque el lienzo era fijo
(60 × 34) y la v0.45 solo cambió la forma, no el tamaño. Lo único del
mundo que apunta al plano son índices: piedras de paso activadas
(`town.ws`), matas recolectadas y el índice de mina. Por eso hay una
**versión de plano** (§ 6): al cargar un mundo con otra versión se
regenera solo y se limpian esos índices, y el dueño ve el bioma nuevo en su
mundo actual.

## 1. Plano

- Lienzo `BiomeLayout.width × height` = **150 × 112** (tunable solo en
  código: cambia la red).
- El **frente** (el plano de antes, 60 × 34) va abajo al centro: la
  llegada sigue en el borde sur y el camino aparición → portal más lejano
  sigue bajo `mainPathMax`.
- Del frente salen **senderos** (2–3) por los costados y por arriba de los
  portales hacia las secciones.

## 2. Secciones

El resto del lienzo se parte en celdas (`wildCell` tiles) y se agrupa en
**secciones** de 2–4 celdas; cada sección tiene un **centro** (claro con
piedra de paso, § 5) y un tipo:

| Tipo | Qué es |
|---|---|
| `forest` | Bosque denso (árboles casi pegados), senderos que serpentean (A* con mucho ruido), **recovecos** (claros chicos al costado). |
| `cavern` | Gruta chica: piso bajo techo, anillo de roca, con lago (`cavernLakeChance`) o seca; algunas con haces de luz (§ 4.2). |
| `giantLake` | Lago gigante (radio `giantLakeR*`: 16–20 × 10–12, unos 32–42 × 19–26 tiles de agua; antes ~24×14), muelles y siempre un muelle de balsas (fishing.md § 15); ocasional (`giantLakeChance`, a lo sumo 1). Es más grande que una celda de sección, así que se ubica **antes** que las demás secciones: el centro más lejano cuyo rectángulo (radios × 1,25 + 3, más 2 de margen) quede todo en pasto libre y fuera del frente. Las secciones cuyo propio rectángulo tocaría ese lago se descartan, y la orilla (todo tile pegado al agua) queda reservada y transitable, así ningún árbol, roca o gruta corta el acceso a los muelles. |
| `shrine` | Fuente especial (tile `F`) o santuario (tile `H`): una vez por día da una bendición (§ 3.4). |
| `meadow` | Pradera abierta con matas. |

- Los senderos unen los centros en un árbol (más alguna vuelta extra) y
  serpentean. Todo lo caminable es alcanzable desde la llegada.
- **Zonas ocultas**: algunos recovecos y cuevas quedan **fuera del
  sendero**: se llega por un paso angosto entre árboles (pasto, no camino)
  o por una cueva; ahí hay cofres, minas o matas raras.

## 3. Lugares

### 3.1 Minas
- **1 a 3** por bioma (`minesMin..minesMax`, tope duro 1..3; hoy 2..3
  para no dejar huérfano el estado `mine:<bioma>:<i>` de mundos viejos,
  que tenían 2). La 0 está
  junto a un portal (como antes); las otras en lo profundo, a veces dentro
  de una gruta (§ 2) a la que se llega fuera del sendero.

### 3.2 Recolección
Las matas del frente siguen primero (mismos tipos); las salvajes se
agregan después (más matas por sección, `wildForagePerSection`).

### 3.3 Cofres
Cofres en grutas y zonas ocultas (`chestSpots`, tile `$` de las minas,
sólido). E abre: oro y botín de cofre de madera (como los de mina) más 2
del mineral del bioma; uno por jugador por día. Se anota en
`town.daily` (`wx:<jugador>:<bioma>:v<versión de plano>:c<i>:<día>`, se
poda al cambiar el día): mañana vuelven a llenarse. `<i>` es el índice del
plano generado, por eso la clave lleva `BiomeLayout.version`: al
regenerarse el plano, una marca vieja no cae sobre un cofre nuevo.

**Botín en el piso (protocolo 96, loot.md § 4c).** Abrir el cofre ya no
entrega en silencio: el oro, el mineral y el botín **caen al piso sobre
el cofre** como en las mazmorras (instanciado: solo quien lo abrió lo ve
y lo levanta, caminando encima o con E), y cada cosa levantada muestra
el aviso de la izquierda. Prompt: `[E/Clic] Abrir el cofre`; clic sobre
el cofre en alcance = E.

### 3.4 Santuarios y fuentes
E (o clic) da, una vez por jugador por día, `shrineGold` de oro y 1 del
material raro del bioma, que **caen al piso delante del santuario** (una
casilla abajo) como botín instanciado (loot.md § 4c). Mismo guardado
(`wx:<jugador>:<bioma>:v<versión>:s<i>:<día>`).

- Prompt disponible: `[E/Clic] Recibir bendición (oro + material raro)`.
- Usado hoy (cofre o santuario): línea **gris** sin tecla
  `Ya lo usaste hoy · se renueva mañana` (`WorldPrompt.spent`).

## 4. Luz en grutas

### 4.1 La luz del jugador corta la oscuridad
Antes la sombra de las grutas (`drawCaveShade`) se pintaba encima de todo
y de día no había luz propia: la Llama errante no iluminaba. Ahora:
- Dentro de una gruta (tile techado) el jugador lleva luz siempre (la de
  mazmorra oscura; con la Llama errante prendida, la de la llama), de día
  o de noche (`LightRules.wispActive(..., cave: true)`).
- La sombra se dibuja en una capa y cada luz que se mueve (jugadores,
  llama, antorchas) le **recorta** un círculo suave (`dstOut`), como en
  las minas. Solo las luces dentro de la vista.

### 4.2 Haces de luz
Algunas grutas (`cavernShaftChance`) tienen haces que caen del techo: se
dibujan con el haz de las minas (`drawShafts`) además de los charcos de
luz.

## 5. Piedras de paso
- Se conservan las del frente (entrada, lagos del frente, mina junto al
  portal).
- Una más en cada **punto de interés** de lo profundo: cada mina
  profunda, lago gigante, santuario, boca de gruta y cada centro de
  sección que es un **cruce** (3 senderos o más).
- Se **descubren al tocarlas**: pasar a `waystoneReach` las activa para
  ese jugador (el anfitrión lo mira cada tick); E sigue abriendo el menú.
- `WaystoneSite`: `entrance, lake, mine, section, shrine, cavern`.

## 6. Contenido de exploración (por bioma y por día)

Sembrado por `(semilla del mundo, bioma, día)`; se reusan los eventos del
mundo (world_events.md § 3.6), no se duplica nada:
- Eventos con `params.deep = 1` no entran a la tirada general: los tira
  `WorldEventRules.exploreRoll` cada día, por bioma abierto, con
  `exploreChance` y `exploreMax`.
- Se paran en un `exploreSpot` de lo profundo (no junto al camino
  principal), elegido por hash del uid.
- No se anuncian en el chat (se encuentran explorando). Descubrir una
  piedra al tocarla tampoco escribe en el chat.
- Defaults (también en `assets/data/events/world_events.json`):
  **élite errante** (`explore_elite`, duelo con el élite de una zona del
  bioma: `target: "@elite"`; se dibuja con el sprite de ese enemigo — el mismo `duel()` elige el enemigo del mapa y el del combate. No habla: con E/clic cerca arranca la pelea directo, por la misma regla que una grieta (`ProposeRiftAction`, junta al grupo como una misión), y el cartel es `[E/Clic] Enfrentar · Élite errante` solo al estar cerca. `WorldEventDef.talks` (`null` por defecto = `WorldEventRules.talks`: un enemigo errante — profundo y con duelo — no habla, el resto sí); un futuro enemigo que habla pone `"talks": true` y vuelve a abrir el diálogo), **mercader con carreta**
  (`explore_merchant`, comerciar), **viajero con encargo**
  (`explore_traveler`, regalo + rumor), **suceso** (la grieta de siempre
  puede caer en lo profundo).
- Cofres y santuarios (§ 3.3–3.4) se rellenan cada día.

## 7. Versión de plano (migración)
- `BiomeLayout.version` (hoy 4: v0.49.9 regenera todos los exteriores de todo mundo por pedido del dueño; 3: v0.49.3 agrandó el lago gigante). `TownState.layoutVersion` (JSON `lv`,
  0 si falta).
- En `setWorld`, `BiomeRegions.migrate`: si `lv` ≠ versión se borran las
  piedras activadas (`town.ws`; la de la entrada siempre está activa) y
  las matas recolectadas (`town.wild`) y las marcas de cofres / santuarios
  del día (claves `wx:` de `town.daily`, también las búsquedas en árboles), el descubrimiento del mapa
  (niebla, `town.md`), y se guarda `lv`. Si al cargar el grupo estaba en un
  exterior (no mina ni mazmorra), todos pasan al punto de llegada del bioma. Las marcas sin
  versión de guardados previos a v0.49.5 ya no coinciden con ninguna clave. Construcciones del pueblo (no se regenera), estado de
  minas, zonas, jefes, tiers y portales Eco, misiones, historia,
  inventario y todo lo demás no dependen del plano y quedan.

## 8. Mapa y rendimiento
- Minimapa: ya recorta una ventana alrededor del jugador y cachea la base
  como imagen (1 px por tile); funciona igual con el lienzo grande.
- Capas estáticas por bloques: la sombra y el brillo de grutas se graban
  en bloques de 16 × 16 tiles y solo se dibujan los de la vista; la
  niebla de los lagos de gruta se descarta fuera de la vista. Los tiles
  ya iban por bloques (`TileLayerCache`).
- Tests de rendimiento existentes pasan con el lienzo grande.

## 9. Red y guardado (protocolo 82)
- El plano cambia para todos: sube el protocolo.
- Nuevo en el snapshot/guardado: `town.lv`; cofres y santuarios en
  `town.dy` (ya existía).
- Acción `wx {i, s?}` (`s: 1` = santuario).

## 10. Tests
`test/game_engine/biome_exploration_test.dart`: tamaño y secciones,
alcanzable, minas 1..3 (una junto al portal), piedras en puntos de
interés y descubiertas al tocarlas, contenido sembrado por día, cofres y
santuarios una vez por día, migración de versión, llama en grutas.
`test/features/world/biome_v2_preview_test.dart`: la luz recorta la
sombra (siempre) y, con `BIOME_PREVIEW=1`, las vistas
`docs/preview/biomes_v2/biome_<id>.png` y `cavern_light.png`.

## 11. Mapa del exterior: leyenda propia, objetivos y descubrimiento (protocolo 90)

El mapa grande (M, y el de PIEDRAS DE PASO) y el minimapa se comportan
distinto en un **exterior de bioma** que en una mazmorra. En mazmorras no
cambia nada (leyenda, niebla de mazmorra oscura y PdI siguen igual).

Código: `lib/game_engine/rules/map_discovery_rules.dart` (Dart puro:
celdas, revelado, marcas del exterior), `TownState.discovery`,
`hud/full_map.dart` (`FullMapMode`), `hud/minimap.dart`
(`OverworldOverlay`).

### 11.1 Leyenda por modo
- `FullMap.legendFor(mode)`: cada modo tiene su leyenda y solo lista lo
  que ese modo dibuja.
- **Mazmorra** (como siempre): Tú, Aliados, Escalera, Jefe, Cofre,
  Secreto, Santuario, Piedra de paso, Enemigo.
- **Exterior**, en dos grupos con título:
  - **OBJETIVOS**: Portal de mazmorra, Portal de Eco (los dos de cada
    tipo que piden la historia y el final).
  - **OPCIONAL**: Piedra de paso, Santuario, Cofre, Mina, Muelle,
    Habitante (el puesto del habitante del bioma).
  - Además Tú y Aliados.
  Élites y mercaderes de exploración son eventos del día y no se dibujan
  en el mapa (se encuentran explorando, § 6), así que no van en la leyenda.
- `FullMap.overworldLegendFor(overlay)`: en el exterior la leyenda se
  recorta a lo que hay dibujado (un tipo opcional aparece cuando hay uno
  descubierto; Aliados solo con grupo; grupos vacíos no se muestran).
- Texto de la leyenda (títulos de grupo y etiquetas) con `DsText.subtitle`,
  el mismo tamaño que los botones del panel; en filas si no entra.
- El título del panel en el exterior es el nombre del bioma
  (`MAPA · BOSQUE`); en mazmorras sigue el nombre de la misión/piso.

### 11.2 Objetivos vs. opcional
- Objetivos (entradas de mazmorra y portales de Eco): cuadro de 3 tiles
  con **marco dorado** (`MapMark.goal`), siempre visibles aunque estén en
  la niebla; la entrada lleva el color de su zona (gris si está cerrada),
  el Eco su color (`MapMark.echo`).
- Opcional: punto chico de su color, solo en lo descubierto.

### 11.3 Minimapa más chico
- La ventana del minimapa con zoom 2–3 pasa de 200 × 140 a **168 × 118**
  px (`kMinimapWindow`).
- Con zoom 1 (el piso entero) el piso se encoge para caber en esa misma
  ventana (antes, el lienzo de 150 × 112 ocupaba 375 × 280 px).
- **Zoom por defecto en el exterior** (v0.49.9): cerca. La caja que va
  de la llegada a los portales de zona (+ 3 tiles de margen) llena la
  ventana (`biomeMinimapCell`), entre el zoom de todo el bioma y el
  zoom 3; centrado en el jugador como siempre. No se aleja solo al
  descubrir más: el jugador ve los senderos que salen de la ventana y
  aleja con `-` si quiere. El zoom que elige en los exteriores se
  recuerda durante la sesión (`biomeMinimapZoomProvider`, aparte del
  zoom guardado de las mazmorras, que no cambia).

### 11.4 Descubrimiento (niebla del exterior)
- El exterior se parte en **celdas** de `mapCell` = 4 × 4 tiles
  (38 × 28 celdas; constante de código porque cambia el formato).
- Al entrar a un bioma **no** se ve el plano: solo se conocen las celdas a
  `mapStartRadius` tiles de la llegada y de cada objetivo (§ 11.2). Eso no
  se guarda: se calcula del plano.
- El anfitrión, cada tick del exterior, marca como descubiertas las
  celdas cuyo centro está a `mapRevealRadius` tiles de algún jugador (no
  compañeros). Solo cambia el estado si hay celda nueva.
- Lo no descubierto se tapa en el minimapa y el mapa grande con el color
  del vacío (máscara de 1 px por celda, cacheada por versión). Los
  jugadores y los objetivos se ven igual.
- **Compartido por el grupo**: está en el mundo (`TownState.discovery`,
  JSON `md`: bioma → `w,h,base64` de 1 bit por celda, como `FogOfWar.pack`)
  y viaja en el `town` del estado. El snapshot de la sala solo manda el
  bioma donde está el grupo (`farmJson(place:)`); el guardado, todos.
- **Versión de plano** (§ 7): `migrate` también borra `discovery`; un
  valor con otro tamaño de celdas se descarta al leerlo.
- Piedras de paso: el mapa de PIEDRAS DE PASO y el mapa grande solo
  muestran las activadas y las que están en lo descubierto (estas en gris
  "sin encontrar"); solo se viaja a las activadas (como antes).

### 11.5 Tunables (`kTuning[TuningId.regions]`, editables en Balance)
| Clave | Default | Qué |
|---|---|---|
| `mapRevealRadius` | 9 | Radio (tiles) que revela cada jugador al caminar. |
| `mapStartRadius` | 5 | Radio (tiles) conocido desde el inicio alrededor de la llegada y de cada objetivo. |

### 11.6 Rendimiento
- El tick no decodifica el base64 cada vez: hay un caché por bioma
  (cadena → bits). Con todo ya descubierto alrededor no se crea estado
  nuevo.
- La máscara de niebla del exterior se graba como `Picture` (1 px por
  celda) y se rehace solo cuando cambia la cadena del bioma.

### 11.7 Tests
`test/game_engine/map_discovery_test.dart` (inicio solo con objetivos,
revelado al caminar, sin cambio si ya estaba, empaquetado, migración,
snapshot solo del bioma actual), `test/features/world/overworld_map_test.dart`
(leyenda por modo, minimapa dentro de la ventana, piedras sin descubrir
ocultas) y la vista `docs/preview/overworld_map_fog.png` con
`OVERWORLD_MAP_PREVIEW=1`.

### 11.8 Mapa de mazmorra por descubrir (protocolo 95)
Lo mismo que § 11.4, igualito, en **todo mapa de mazmorra**: pisos de
misión, mazmorras persistentes, Ecos, Atlas, Pruebas, Jefes del Abismo y
la Travesía (todo lo que tiene `MissionRun`).

- **Celdas**: las mismas de 4 × 4 tiles (`MapDiscoveryRules.cell`), sobre
  el mapa entero de la misión (en un atlas cada piso es su rectángulo, así
  que la máscara ya es "por piso"). `DungeonDiscoveryRules` reusa
  `MapDiscoveryRules.revealCells`: no hay otra lógica de revelado.
- **Al llegar** solo se conoce el área a `dungeonMapStartRadius` tiles de
  la llegada de cada piso (y del punto de vuelta subiendo) y de sus
  **objetivos**: la escalera de bajada (`stairsDown`) y la sala del jefe
  (el jefe del último piso, centro de su arena). No se guarda: sale del mapa.
- **Objetivos siempre visibles**: cuadro de 3 tiles con el marco dorado de
  los objetivos del exterior (§ 11.2), color escalera / jefe. Fragmentos,
  sellos, la estrella del jefe y la salida de la mazmorra se ven siempre,
  como antes.
- **El resto se descubre caminando**: el anfitrión, en cada tick de campo
  (`_explorationTick`), marca las celdas a `dungeonMapRevealRadius` tiles
  de cada jugador (no compañeros). Lo no descubierto se tapa con el color
  del vacío; salas, rejas, cofres, PdI, enemigos y loot solo se dibujan en
  lo descubierto. **Secretos**: siguen las reglas de antes (PdI solo si
  `poiSeen`, cofres de sala secreta solo con la sala abierta) **y** además
  la celda tiene que estar descubierta.
- Convive con la niebla de mazmorra oscura (lighting.md § 5.4, local del
  cliente): se dibuja solo lo que pasa las dos.
- **Compartido**: va en la misión (`MissionRun.discovery`, JSON `md` =
  `FogOfWar.pack` de 1 bit por celda como `n,1,base64`, y `mdr` = revisión
  que sube con cada celda nueva). Viaja en cada snapshot de la sala; lo que
  descubre cualquiera se dibuja para todos.
- **Guardado**: mazmorras persistentes (persistent_dungeons.md § 2) lo
  guardan con el `run` de `DungeonSave` (por piso, en su rectángulo); el
  resto vive solo en la misión en curso.
- **Leyenda**: sigue siendo la de mazmorra, pero solo lista lo que se
  dibuja: yo siempre, aliados con compañía, escalera y jefe (objetivos, con
  marco dorado) y el resto solo si hay uno descubierto en el piso.
- **Minimapa**: misma niebla. Con zoom 1 (por defecto) se ve el piso
  entero, que encuadra la llegada y los objetivos.
- **Rendimiento**: la unión inicio ∪ descubierto se cachea por mapa y
  revisión; la máscara se graba como `Picture` y se rehace solo cuando
  cambia la revisión (misma caché que el exterior).

| Clave (`TuningId.regions`) | Default | Qué |
|---|---|---|
| `dungeonMapRevealRadius` | 7 | Radio (tiles) que revela cada jugador en la mazmorra. |
| `dungeonMapStartRadius` | 4 | Radio (tiles) conocido al llegar alrededor de la llegada y de cada objetivo del piso. |

Tests: `test/game_engine/dungeon_map_discovery_test.dart` (inicio,
objetivos siempre, secretos ocultos, revelado, persistencia JSON, sync
cooperativo), `test/features/world/dungeon_map_fog_test.dart` (leyenda
recortada, minimapa) y la vista `docs/preview/dungeon_map_fog.png` con
`DUNGEON_MAP_PREVIEW=1`.
