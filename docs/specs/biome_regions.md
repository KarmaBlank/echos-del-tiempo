# Regiones de bioma (v0.45.0, protocolo 76)

Los exteriores de bioma dejan de ser un plano fijo de 34 × 22: cada uno
es una **región chica explorable** generada por semilla. El camino a los
portales sigue siendo corto y directo; todo lo demás es opcional.

Código: `lib/game_engine/rules/biome_regions.dart` (generador y
`BiomeLayout`), `waystone_rules.dart`, `light_shaft_rules.dart`,
`biome_rules.dart` (recolección); datos en `biomes_catalog.dart`
(`BiomeBase`, `BiomeRegionStyle`), `light_catalog.dart`
(`kLightShaftThemes`) y `kTuning[TuningId.regions]` (Editor → Balance →
Regiones de bioma). Dibujo: `region_light_layer.dart`,
`ambient_life_layer.dart`, `panels/waystone_panel.dart`.

## 1. Semilla y determinismo

- La región sale de `(bioma, semilla del mundo)`. La semilla es la del
  cielo del mundo (`town.sky.seed`, weather_seasons.md § 3), que viaja en
  el snapshot: todos los pares arman las mismas tiles. El layout nunca
  viaja.
- `BiomeRegions.bind(seed)` fija la semilla activa (el motor la fija al
  armar cada mapa y en `setWorld`); `biomeLayout(id)` devuelve la región
  generada (cacheada por semilla).
- PRNG propio (xorshift), igual en VM y web. Mismo par (bioma, semilla) ⇒
  mismas filas, lagos, piedras, matas y puntos.
- Sin semilla (mundos viejos, tests) se usa 0.
- Un mundo nuevo elige su cielo (y su semilla) en `setWorld`, así el
  layout no cambia con el primer tick del cielo.

## 2. Plano

Este plano (60 × 34) es ahora el **frente** de la región; desde la v2
(protocolo 82) va abajo al centro de un lienzo de 150 × 112 con las
**tierras salvajes** alrededor: ver `biome_exploration.md`. Borde de
árboles de 2 tiles, salida al pueblo por el sur.

### 2.1 Camino principal
- Del borde sur (aparición, `spawn`) sube serpenteando 2 tiles de ancho
  hasta una **plaza** en la fila 16. Se corre ±1 cada 3 filas (máximo ±3).
- Dos entradas de mazmorra (las zonas del bioma), una a cada lado,
  algo irregulares: x = plaza − 11..−9 / plaza + 5..+7, y = 6..8. A la
  derecha de cada una, su **portal de Ecos** (3 tiles, como siempre,
  ecos_zone.md § 2).
- Caminos de la plaza a cada entrada y a cada portal (A* con ruido).
- **Corto:** el recorrido aparición → entrada/portal más lejano no pasa de
  `mainPathMax` (34) pasos; hoy ronda 25–30, como el plano viejo.

### 2.2 Caminos laterales
- Salen del camino principal (el tile más cercano) hacia cada lugar
  opcional; A* sobre pasto con costo con ruido, así serpentean, y
  reutilizan caminos ya hechos.
- Con `style.grove` un camino largo cruza una **arboleda** (árboles a
  ambos lados en su tercio central); con `style.tunnel`, una **cueva
  corta** (piso bajo techo, paredes de roca a los lados).

### 2.3 Lugares
- **Lagos** (§ 3): 1, y un 2.º con `secondLakeChance`, en los cuadrantes
  sur (oeste / este).
- **Bocas de mina**: una (v2; antes dos), en una esquina del norte del
  frente; las otras, en lo profundo (biome_exploration.md § 3.1), con roca alrededor y
  camino desde la entrada de su lado. Gancho para minería:
  `BiomeRegions.mineHook` (si está, elige las entradas con el layout;
  si no, `lay.mines` = `lay.mineSites`, las bocas generadas). Minería
  usa `lay.mines` como antes (`mine:<bioma>:<i>`).
- **Campamento** del habitante (overworld_biomes.md § 9.2): claro de 7 × 5
  en un cuadrante libre, con camino; `BiomeNpcDef.tile` sale de acá
  (`npc.at(...)`).
- **Rincón del eco**: un claro rodeado de árboles en otro cuadrante libre
  con la **Flor del eco** (§ 5).
- **Puntos de eventos** (`eventSpots`): pasto libre a 1 tile del camino
  principal; ahí paran visitantes, errantes y grietas de eventos del
  mundo (world_events.md § 3). Siempre en suelo válido.

### 2.4 Decoración
- Árboles sueltos (`treeDensity` cada 100 tiles libres), nunca pegados a
  un camino ni sobre lugares reservados; nada sólido aísla un lugar.

## 3. Lagos

Elipse con borde irregular (dos armónicos), radios entre
`lakeRx/RyMin..Max`. Variantes por bioma (`style.lakes`, pesos):

| Variante | Qué es |
|---|---|
| `open` | Orilla libre; dos muelles (el del lado del camino y uno al sur). |
| `glowShore` | Se pesca de un solo lado: alrededor, **plantas luminosas** (tile `v`, sólido, brilla de noche) salvo un arco frente al camino; un muelle. |
| `cave` | Dentro de una **gruta**: anillo de roca, piso bajo techo, boca hacia el camino; luz que cae por aberturas (§ 7) si `style.caveOpenings`. |

- Muelle = tile `f` en el borde del agua; `approach` = el tile de tierra
  frente al muelle, donde termina el camino.
- Tablas de peces y basura del bioma (las de siempre); el primer lago
  lleva el nombre del bioma, los otros el de su variante.
- **Agua brillante** (fishing.md § 11): sigue saliendo de
  `FishingCast.hiddenSpot`, ahora solo entre aguas con un vecino
  **caminable** (no cuenta roca ni plantas): siempre se puede llegar.
- **Pescador nativo** (fishing.md § 12): va y viene por los últimos 6
  tiles del camino al primer lago (`fisherWalk`).

| Bioma | Variantes (peso) | Arboleda / cueva | Bichos |
|---|---|---|---|
| Bosque | open .5, glow .3, cave .2 | .7 / .2 | mariposas |
| Ruinas | open .5, glow .2, cave .3 | .3 / .4 | chispas |
| Cavernas | cave .6, glow .4 | .1 / .6 | escarcha |
| Grieta | open .6, cave .4 (grutas sin aberturas) | .2 / .5 | brasas |
| Abismo | glow .6, open .4 | .3 / .3 | ecos |

## 4. Piedras de paso

> v0.49.9: `BiomeLayout.version` 4 regenera los exteriores de todo mundo
> guardado; las piedras activadas se pierden (ver biome_exploration.md § 7).

- Una en la **entrada** (junto al camino principal, cerca de la llegada),
  una por **lago** (junto a su `approach`) y una por **boca de mina**.
  Tile `W` de siempre; activada se le prende la runa (solo para quien la
  activó).
- Desde la v2 se activan también **al tocarlas** (pasar a
  `waystoneReach`), y hay más en lo profundo (biome_exploration.md § 5).
- E frente a una (a `waystoneReach` px): si no está activa, se activa
  (acción `way {i}`) y se abre el menú **PIEDRAS DE PASO**. La de la
  entrada está activa siempre.
- Menú (v0.48.5; v0.49.11 sin detalle ni botón): el **mapa grande de
  la región** (`FullMap`, el mismo de las piedras de paso de las
  mazmorras, worldgen.md § 11.4) con `FullMapPick` (solo da el nombre):
  las piedras sin número (activas en cian, las otras activas laten y la
  de acá queda fija con marco dorado: exploration.md § Piedras de paso
  en el mapa; desde el protocolo 90 las no activadas solo aparecen, en
  gris "Sin descubrir", si están en terreno ya descubierto:
  biome_exploration.md § 11.4). Pasar el mouse muestra su nombre
  (tooltip). **Clic en otra piedra activa viaja enseguida** (no hay paso
  de elegir y después VIAJAR, ni panel de detalle); clic en la de acá o
  en una sin descubrir no hace nada; Tab rota el resaltado y Enter
  viaja. Vista previa: `docs/preview/waystone_map.png`
  (`WAYSTONE_MAP_PREVIEW=1`). El clic manda (como antes VIAJAR)
  `way {i: desde, to: hasta}`; el anfitrión valida que estés junto a una
  piedra activa y que el destino esté activo, y mueve **solo a ese
  jugador** al camino junto a la piedra destino.
- Por jugador y por mundo: `TownState.waystones`
  (`<jugador>|<bioma>:<i>`, JSON `ws`), se guarda con el mundo.

## 5. Recolección

Complementa la de siempre (overworld_biomes.md § 3.2). Clases
(`ForageClass`, en `kForageKinds`):

- **Matas del bioma** (`plantSpots`): sus 3 productos silvestres, con la
  chance de semilla de siempre. Las primeras tres son una de cada tipo.
- **Matas de semillas** (`seedBushes`): siempre una semilla del bioma;
  las raras (las que solo se consiguen silvestres) pesan
  `seedBushRareMul` × más.
- **Brotes de estación** (`seasonalSpots`): dan el producto de la
  estación (`WeatherRules.season`): Brote de primavera, Fresa estival,
  Castaña de otoño, Baya de invierno. XP × `seasonalXpMul`.
- **Flor del eco**: una, en el rincón opcional; épica, rebrota en
  `echoBloomRespawnSec`, XP × `echoBloomXpMul`.
- Todas dan XP de Cultivo (`forageXp × (rareza + 1) × mult.`).
- Matas al lado de un camino lateral, nunca sobre el camino principal.

### 5.1 Rebrote fuera de la vista
- Al vencer su tiempo, una mata solo rebrota si **ningún jugador** de la
  instancia está a `forageHideRadius` px; si alguien mira, espera
  `forageRecheckSec` más. Las que rebrotan salen de `TownState.wild`.
  Lo corre el anfitrión en cada tick del lobby
  (`BiomeRules.holdInView`).

## 6. Vida

- Bichos de ambiente por bioma (`style.critter`): una posible criatura
  por celda de 96 px de la vista, fija en el mundo (no sigue a la
  cámara), según la densidad de partículas. Las mariposas no salen de
  noche. Sin estado ni red.

## 7. Luz: nubes y haces

### 7.1 Sombras de nubes
- Al aire libre con cielo (`WeatherRules.hasSky`) y de día: sombras
  suaves que derivan despacio. Más gruesas con lluvia y tormenta
  (`LightShaftRules.cloudCover`); nada de noche.
- v0.48.3: con cielo despejado la cobertura es 0.5 y cada disco llega a
  alfa 0.18 × cobertura (antes 0.055: no se veían). El centro de una nube
  oscurece ~25% en un día despejado.

### 7.2 Haces de luz
- Interiores: grutas de lago, cuevas cortas, exteriores sin cielo,
  pisos de mazmorra y niveles de mina. Haz inclinado, mancha en el piso,
  motas que bajan y moteado alrededor.
- **Dónde** (datos): en los exteriores, las aberturas de las grutas
  (`lay.skylights`); para temas, `kLightShaftThemes` (tema → cada
  cuántos tiles de piso abierto cae uno). Un tema que no está ahí **no
  tiene aberturas y queda oscuro** (p. ej. `laberinto`, `corazon`,
  `mina_cavernas`, `mina_abismo`); una gruta de un bioma con
  `caveOpenings: false` tampoco.
- En mazmorras oscuras cada haz además ilumina (`LightId.shaft`, también
  de día).
- Bajo techo en una región de día: sombra de cueva (imagen cacheada).

### 7.2.1 Grutas techadas (exteriores)

- (v0.49.9) En un exterior de región solo hay haces en los tragaluces
  bajo techo (`skylights` con `isIndoor`); las aberturas por hash del
  tema (`kLightShaftThemes`, p. ej. `cavernas_ext`) ya no se aplican a
  las regiones: ponían luces de haz sobre pasto abierto y de noche un
  punto del claro se iluminaba "como una cueva".
- **Caverna del lago de cueva** (v0.48.2): el sitio del lago se une con
  el sitio del medio de arriba; la caverna es una mancha orgánica (tres
  armónicos + ruido por tile) de `caveScaleX/Y` × los radios del lago,
  con un borde de roca de `caveWallTiles` tiles y **una sola boca**
  (tallada hasta salir del borde). Aberturas de luz: 0..`caveSkylightsMax`.
- Roca natural (bloques irregulares en tonos, facetas, grietas; pie roto
  contra el piso), piso oscuro, orilla de piedra mojada junto al agua,
  estalagmitas contra la pared y hongos con brillo (`caveSpecks`).
  Paleta por bioma (`CavePalette.of(tema)`).
- Oscuridad `caveDark` + viñeta hacia las paredes (`caveVignette`,
  `caveVignetteTiles`) en celdas de 8 px (imagen cacheada). Encima: brillo
  frío del agua (`caveWaterGlow`) y de los hongos (cacheado), niebla baja con
  el estilo de la niebla del clima (celdas de 8 px ancladas al mundo,
  ruido suave, alfa cuantizada; `caveMistBands` capas, deriva
  `caveMistSpeed` px/s) y ondas de gotas (`caveDripSec`).
- La boca: alero irregular con estalactitas, encima de los personajes.
- Toda la gruta de un lago de cueva (y las cuevas cortas) es una **zona
  techada**: la roca que la rodea (roca a ≤ 2 tiles de un tile techado,
  `RegionAmbienceRules.caveWall`) se dibuja como **pared de cueva**
  (bloques de roca con grietas), no como picos de montaña; el piso
  techado es piedra oscura.
- En la boca (lados de un tile techado que dan a suelo abierto,
  `RegionAmbienceRules.roofEdges`) se dibuja el **borde del techo**: un
  alero de roca con dientes, encima de los personajes.
- Se mantiene el filtro oscuro "bajo techo" (sombra de cueva).
- En los exteriores, las aberturas **no** dibujan un haz/cono: dejan
  **charcos de luz** tenues y pixelados en el piso (rects cuantizados que
  respiran muy despacio) y unas pocas **motas de polvo** que derivan. Las
  mazmorras y minas conservan el haz.
- Números (`kTuning[TuningId.regions]`): `caveRoofLip` (px del alero),
  `cavePoolAlpha`, `cavePoolSize` (px), `cavePoolPixel` (paso del
  pixelado), `caveMotes` (motas por charco), `caveMoteSpeed`.

### 7.2.2 Viento en la vegetación
- Pasto, arbustos y copas de árboles se mecen apenas: un subconjunto de
  tiles visibles (`swayDensity`, por hash) dibuja un mechón / brillo de
  copa desplazado `RegionAmbienceRules.sway` px (fase por tile, ráfaga
  que viaja en x). Números: `swayAmp`, `swaySpeed`, `swayDensity`.
- Con movimiento reducido no se mece.

### 7.2.3 Ambiente al pescar
- Mientras el jugador local pesca fuera del pueblo, la música del bioma
  baja casi a silencio (`ambMusicLevel`, en `ambDuckSec`) y vuelve al
  terminar. En el pueblo sigue la pieza de pesca. **Desde cozy_life.md
  § 1:** fuera del pueblo (pescando o en balsa) suena `Music.cozy` a
  `cozyMusicLevel` en vez del silencio; se suman agua, pájaros, grillos y
  luciérnagas.
- Suenan cada tanto (`ambGapMinSec`–`ambGapMaxSec`, volumen `ambVolume`)
  sonidos muy suaves según el lugar (`BiomeRegionStyle.fishingAmbience`):
  brisa (`amb.breeze`) al aire libre, goteo (`amb.drip`) bajo techo y en
  cavernas / minas, nada en la grieta y el abismo. Todos los números en
  `kTuning[TuningId.fishing]`; los sonidos son del sintetizador y se
  pueden reemplazar por archivo en `assets/sfx/sfx_manifest.yaml`.

### 7.3 Rendimiento
- Solo lo visible: haces filtrados por la ventana, nubes descartadas si
  no tocan la vista, bichos por celdas de la vista.
- Lo estático cacheado: la sombra de cuevas es una `Picture` por layout;
  los haces de un mapa se calculan una vez (`Expando` por filas).
- Sin asignaciones por cuadro en el dibujo: pinturas, trazado del haz y
  rectángulos son fijos; la lista de visibles se reutiliza.
- Test de rendimiento: `test/features/world/region_light_perf_test.dart`.

## 8. Red y guardado (protocolo 76)
- El plano sale de la semilla: cambia el mapa de todos los exteriores.
- `town.ws` (piedras activas) viaja en el snapshot y se guarda.
- Acción `way {i, to?}`.
- Nuevas clases de recolección y productos silvestres (`flor_eco`, brotes
  de estación).

## 9. Tests
`test/game_engine/biome_regions_test.dart`: layout determinista; camino
principal alcanzable y corto; lagos, minas, piedras, matas, campamento y
puntos de eventos alcanzables; variantes de lago con agua brillante
válida; activar y viajar entre piedras; rebrote fuera de la vista;
recolección de estación; haces solo donde hay aberturas.
`test/features/world/region_light_perf_test.dart`: rendimiento.

- **Sombras de nubes pixeladas (v0.48.4):** cada nube es una grilla de celdas de 8 px con borde irregular (ruido que viaja con la nube) y 4 escalones de alfa hacia el borde; se dibujan en lotes de puntos, una llamada por escalón.
