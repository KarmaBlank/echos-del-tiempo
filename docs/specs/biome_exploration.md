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
| `giantLake` | Lago gigante (radio `giantLakeR*`), muelles; ocasional (`giantLakeChance`, a lo sumo 1). |
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
`town.daily` (`wx:<jugador>:<bioma>:c<i>:<día>`, se poda al cambiar el
día): mañana vuelven a llenarse.

### 3.4 Santuarios y fuentes
E da, una vez por jugador por día, `shrineGold` de oro y 1 del material
raro del bioma. Mismo guardado (`wx:<jugador>:<bioma>:s<i>:<día>`).

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
  bioma: `target: "@elite"`; se dibuja con el sprite de ese enemigo), **mercader con carreta**
  (`explore_merchant`, comerciar), **viajero con encargo**
  (`explore_traveler`, regalo + rumor), **suceso** (la grieta de siempre
  puede caer en lo profundo).
- Cofres y santuarios (§ 3.3–3.4) se rellenan cada día.

## 7. Versión de plano (migración)
- `BiomeLayout.version` (hoy 2). `TownState.layoutVersion` (JSON `lv`,
  0 si falta).
- En `setWorld`, `BiomeRegions.migrate`: si `lv` ≠ versión se borran las
  piedras activadas (`town.ws`; la de la entrada siempre está activa) y
  las matas recolectadas (`town.wild`), y se guarda `lv`. Construcciones del pueblo, estado de
  minas y todo lo demás no dependen del plano y quedan.

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
