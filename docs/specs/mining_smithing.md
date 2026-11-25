# Spec: Minería y herrería (v0.44.0 → minas v2, protocolo 77)

Pedido del dueño: minas tranquilas en cada exterior de bioma, vetas que
se pican con un pico, materiales de herrería con sentido (mena → lingote
→ arma) y la Herrería como oficio de jugador, con Brann como camino para
quien no forja. Todo mínimo.

Código: datos en `lib/game_engine/data/smithing_catalog.dart`; minas en
`lib/game_engine/rules/mine_generator.dart`; reglas puras en
`lib/game_engine/rules/mining_rules.dart` (`MiningRules`,
`SmithCraftRules`); sala en `session_engine_mining.dart`. Tunables:
Editor → Balance → **Minería y herrería** (`TuningId.smithing`).

## 0. Lo que no cambia

- Esquirlas, Cristales y Prismas siguen siendo los materiales de
  **mejora de armas encontradas** (materials_economy.md). La herrería no
  los usa ni los da.
- Pueblo 100 % opcional (roles.md § 0): nada del camino crítico depende
  de minar o forjar; el balance de solo mazmorras no cuenta las armas
  forjadas.
- Clima y estaciones (weather_seasons.md): cada material tiene `seasons`
  (vacío = todo el año). `MiningRules.inSeason` lo aplica con
  `WeatherRules.season(día)`: un material fuera de temporada no sale de
  vetas de mina ni de mazmorra. Hoy todos los materiales tienen
  `seasons` vacío (sin cambio de balance).

## 1. Minas (v2, protocolo 72)

Código v2: catálogo de tiles y herramientas en
`lib/game_engine/data/mine_catalog.dart`; estado persistente en
`lib/game_engine/models/mine_state.dart`; generación en
`mine_generator.dart`; reglas puras en `mining_rules.dart` (niveles,
picar, bombas) y `mine_work_rules.dart` (vetas que vuelven, mineros,
vagonetas); sala en `session_engine_mining.dart`; dibujo en
`presentation/map/mine_layer.dart` y `map/mine_tiles.dart`.

### 1.1 Entradas

Cada exterior de bioma tiene bocas de mina (`Tile.mineEntrance`, `m`) con
el cartel `MINA` (encima de la boca; se oculta mientras un jugador está
parado frente a ella, para no tapar su nombre). **Único punto de
entrada para ubicarlas:** `MiningRules.entrances(lay)` →
`mineEntrances(lay)` en `mine_catalog.dart` (hoy devuelve
`BiomeLayout.mines`; otra rama puede cambiar las posiciones candidatas
ahí sin tocar el resto). El layout del exterior no cambia.

Lugares: nivel 0 = `mine:<bioma>:<i>`; nivel L > 0 =
`mine:<bioma>:<i>:<L>`. Se viaja del bioma al nivel 0 y entre niveles
vecinos (±1) (`MiningRules.canTravel`). E frente a la salida (`<`) sube
(o sale al bioma, frente a la misma boca); E frente al **pozo** (`>`)
baja.

**Prioridad de E (v0.48.1):** la piedra de paso de cada mina
(`WaystoneSite.mine`) queda a un tile de la boca y su alcance
(`waystoneReach`, 26 px) cubre todo el frente de la boca. Por eso
`nearMineEntrance` va **antes** que `nearWaystone`, tanto en `interact`
como en el texto del prompt: frente a la boca, E entra a la mina; la
piedra se usa parada frente a ella (su tile de acceso queda fuera del
alcance de la boca). Antes (v0.47.0–v0.48.0) la piedra ganaba y E solo
la activaba: nunca se podía entrar. El layout no cambia (sale de la
semilla del mundo), así que partidas viejas no necesitan migración.
Cubierto por `test/features/world/mine_entry_test.dart`.

### 1.2 Niveles (`mineLevels`, 3–5)

`MineGenerator.generate(bioma, i, nivel, semilla, params)`:
`mineW` × `mineH` tiles (72 × 48), determinista (mulberry32; semilla
FNV de `<mundo>|<bioma>|<i>|<nivel>`; **ya no cambia por semana**).

- **Primero cavar**: todo es roca maciza salvo la cámara de entrada
  (arriba al medio, con la salida, el lugar de la estación `Z` y la
  aparición), el lugar del pozo y unas pocas **cámaras chicas selladas**
  (`chambers`, radio `chamberMin..chamberMax`) a las que se llega
  cavando: cuarto con cofre (`chestRate`), hongos (`mushroomChance`),
  piedra con inscripción (`loreChance`), charco (`lakeChance`) o gruta de
  cristal (`grottoChance`). No hay pasillos ni redes de cuevas abiertas
  (`caveDensity` = 0; si se sube, aparecen bolsones abiertos).
- Roca madre de 2 tiles en el borde (`X`, irrompible) y formaciones
  irrompibles sueltas (`formations`).
- Arroyos chicos de decorado (`streamChance`): agua sellada en la roca,
  sin orillas abiertas, nunca un camino.
- Pozo al nivel siguiente siempre sellado en la roca, lejos de la entrada
  (el último nivel no tiene).
- Vetas en las paredes, visibles: brillan apenas a través de la roca
  (luz `veta`, escala `veinGlow` × `veinGlowRich/Deep/Gem`; más las
  raras, siempre tenue), así el jugador elige hacia dónde cavar.
- Vetas en la roca, en racimos (`veinClusters` + 3 por nivel, tamaño
  `veinSizeMin..Max`): común `r`, rica `d`, profunda `e`, gema `a`; los
  pesos (`wCommon`, `wRich…`, `wDeep…`, `wGem…`, más por nivel) hacen
  que lo hondo sea más rico.
- **Hallazgos ocultos**: gruta secreta sellada (`secretChance`) con gemas
  y, con `relicChance`, un **cofre reliquia magitec** (`U`); en las
  cámaras, cofres (`$`), hongos (`y`, dan fibra) y la **piedra con
  inscripción** (`&`; frases `ui.world.mine.lore.<n>`, **BORRADOR**).
- PNJ ocasional como en v1. **Sin enemigos**: la mina es un mapa lobby.
- Arte: tiles auto-ajustados (borde según vecinos) en
  `mine_tiles.dart`, colores de `MinePalette`; íconos de menas,
  lingotes, herramientas e insumos en el manifest (`vida_mine_*`,
  placeholders generados por `tool/export_mine_icons.dart`).

Más hondo es más difícil: golpes por roca `rockHits` +
`rockHitsPerLevel` × nivel (vetas × `veinHitMult`, cristal la mitad) y
pico mínimo `reqTierLv<n>`.

### 1.3 Picar

Con la mano PICO, E (o clic) sobre el tile al frente/apuntado manda
`MineAction(dig, x, y)`; mantener E sigue picando. El anfitrión valida
alcance (`mineReach`), ritmo (`tool<n>Swing`), roca madre y nivel de
pico; acumula golpes (`fuerza` del pico) hasta romper. Romper:

- Abre el tile para todos (persistente, § 1.10) y manda `MineDugEvent`.
- Veta: menas del bioma (`veinYield`: rica +`richOreBonus`, profunda y
  gema con raros); cristal con `crystalRareChance`; XP de Herrería
  `digXp`.
- Al cliente: chispas, 3 grietas según el daño, escombros, la mena
  "salta" hacia el jugador, sonido (`Sfx`).
- Con `mineBaitChance` (0.05), al romper una veta sale un cebo
  (`BaitRules.foundBait`, los comunes más seguido; weather_seasons.md).
- Los materiales fuera de temporada no salen (`inSeason`, § 0).

### 1.4 Vetas raras en mazmorras y jefes

Sin cambios (v1): `PoiKind.ore` en pisos de mazmorra y `bossCore` de los
jefes.

### 1.5 Vetas que vuelven (reemplaza el cambio semanal)

Los túneles quedan abiertos para siempre. Una veta original picada
"hace eco" y vuelve: tras `regrowSec` aparece en roca intacta a
≤ `regrowRadius` tiles de donde estaba, **solo donde nadie la ve**: fuera
de la pantalla de cada jugador del nivel (`regrowSafeTiles`) y de la luz
de cada antorcha. Si no hay lugar oculto, espera. (Lore: el futuro
inmutable "recuerda" la veta.) La roca no se vuelve a cerrar.

### 1.6 Herramientas, luz e insumos

Barra de herramientas de la mina (`ToolHud`, como ABONO/CEBO; 1–4 o
rueda/R): **PICO/TALADRO**, **ANTORCHA**, **BOMBA**, **ACEITE**.

- Picos (`kMineTools`): `pico` (inicial, nivel 0), `pick_copper` (1),
  `pick_frost` (2), `pick_ember` (3), `drill_echo` (4, **taladro**:
  mantener pica continuo). Cada uno: fuerza, ritmo, bonus de rendimiento,
  precio (`tool<n>Gold`) y lingotes (`tool<n>Ingots`). Se usa siempre el
  mejor que se tenga.
- **Oscuridad**: las minas son oscuras; el jugador lleva una luz chica
  (`LightId.minero`). **Antorchas** (`mine_torch`) se clavan en piso o
  pared; persisten por nivel y se recuperan al picar su roca. La luz
  fija se cachea por mapa (el mapa del nivel es el mismo objeto mientras
  no cambie un tile ni una antorcha) y solo se dibuja lo visible.
- **Bomba** (`mine_bomb`): mecha `bombFuse` s, rompe en radio
  `bombRadius` (redondo; nunca roca madre), sacude la pantalla.
- **Aceite de veta** (`vein_oil`): `boostSec` s con más mineral
  (`boostYield`) y raros (`boostRare`).
- Venta: AGROPECUARIO › MINERÍA. Fabricación: HERRERÍA › MINERÍA
  (lingotes; antorchas/bombas/aceite en tandas `…Batch`).

### 1.7 Mineros

En la estación del nivel (`Z`, se arma por `stationGold` + `stationIngots`
lingotes de cobre) se contratan hasta `minerMax` mineros (`minerCost`; G
contrata, Shift+G despide; usan `HelperStat` del sistema de ayudantes).
Cada `minerStepSec` cada minero va a la veta más cercana por la ruta más
barata (caminar 1, cavar según golpes): si no hay camino, **cava túnel**
(más lento, `minerPower`), pone una antorcha cada `minerTorchEvery`
tiles, y lo picado va a la vagoneta. Corre en la sala del mundo, aunque
nadie esté en la mina; se ven trabajando.

- **Pico del minero** (`MinerState.tier`, 0–4, JSON `pt`): solo rompe la
  roca o la veta cuyo nivel pedido (`MiningRules.reqTierOf`: el del
  nivel de la mina, +1 para vetas profundas y de gema) sea ≤ su pico; lo
  demás lo rodea o lo saltea. Mejorar un pico cuesta
  `minerUpGold` × nivel de oro y `minerUpIngots` × nivel lingotes del
  pico de ese nivel (`MineOp.upgrade` con el índice del minero; lo valida
  el anfitrión). Al máximo pica todo.
- **Panel MINEROS** (`WorldPanel.miners`): E sobre la estación armada, o
  G al lado de un minero (como cualquier ayudante), lo abre. Grilla de
  los mineros del nivel (ícono del pico, `N<nivel>`) con el detalle a la
  derecha: pico actual y nivel, si rompe la roca/vetas de este nivel y
  las vetas profundas/gemas (con el nivel que piden), rinde `minerYield`
  en % contra un jugador, el siguiente pico y su costo (chip de costo:
  oro y lingotes, en rojo lo que falta) y MEJORAR (gris si no alcanza;
  MÁXIMO al tope). U en la estación queda como atajo: mejora el pico más
  bajo con la misma operación.
- **Rinde menos que un jugador**: cada veta da `minerYield` (< 1) de lo
  normal, sin bonus de herramienta, aceite de veta, pasivas ni nodos de
  oficio.

### 1.8 Vagonetas

Vagoneta llena (`cartCap`) sale por riel al pueblo (`cartTravelSec`),
llega a la **estación de vagonetas del pueblo** (landmark `VAGONETAS`,
junto a la salida), rotulada con mina, nivel y bioma. E la descarga
(todo al que descarga) y vuelve vacía (`cartBackSec`). Todo lo decide el
anfitrión; en cooperativo cualquiera descarga.

- **Estación chica junto a la salida**: 2 × 1 tiles en (14, 19) del
  pueblo base, pegada al oeste del camino de salida sur (el eje de la
  fuente). Es un lugar fijo tardío (`TownLayout.lateSpots`): reservado
  con 1 tile de margen para construir, y en un pueblo guardado con algo
  ahí va al hueco libre más cercano sin romper construcciones
  (town_editor.md § 3.3).
- **Riel corto**: `TownPlan.cartRail` da el tramo recto al sur de la
  estación, a lo sumo `cartRailMax` (2) filas, cortado en la primera
  fila que no sea pasto pelado (parcelas, construcciones, lagos, casas,
  árboles, faros, caminos). En el pueblo base es una fila, hasta el
  borde del mapa. Nunca se dibuja riel fuera de ese tramo.
- **Animación**: la vagoneta entra desde el borde por el tramo hasta la
  estación (y sale por ahí); estacionadas, una al lado de la otra sobre
  la estación, con su rótulo apilado encima. Vista previa:
  `docs/preview/mining_v2/05_town_cart_station.png`
  (`MINING_PREVIEW=1 flutter test test/features/world/town_cart_preview_test.dart`).

### 1.9 Sensación

Golpe animado, chispas, grietas, escombros, mena volando al jugador,
sacudida de bomba, ganchos de sonido (`Sfx`). Todo cliente (`MineLayer`).

### 1.10 Guardado

`TownState.mines` (`mn` en el bloque del pueblo, también sincronizado a
los clientes): por nivel, tiles cavados, antorchas, hallazgos abiertos,
vetas que volvieron y sus relojes, estación, mineros, vagoneta y vetas
descubiertas por jugador.

### 1.11 Vetas descubiertas en el minimapa

El anfitrión, dos veces por segundo, marca como descubiertas para cada
jugador (por nombre de perfil, `MineLevelState.known`, JSON `k`) las
vetas a ≤ `discoverLit` tiles (su brillo se ve) y las que asoman en la
cara de un túnel (vecinas de suelo caminable) a ≤ `discoverView` tiles.
El minimapa de ese jugador las pinta del color de la veta mientras sigan
siendo veta; en la base del minimapa la roca, las vetas y los hallazgos
sellados se ven como roca. Una veta que vuelve (§ 1.5) aparece en otro
tile: hay que redescubrirla.

### 1.12 Controles

Con PICO o TALADRO, E pica el tile al frente y el clic izquierdo el tile
clicado si está al lado del jugador (si no, el de al frente);
mantener E o el clic sigue picando al ritmo del pico (el taladro, sin
pausa); clics o toques repetidos también pican (el ritmo lo limita el
pico, y el anfitrión lo valida). Si el pico no alcanza, rebota y avisa
«Necesitás un pico mejor (nivel N)» (`ui.world.mine.need_tier`, como
mucho cada 2 s).

## 2. Materiales de herrería

Guardados en el perfil, `LifeSkills.ores` (JSON `ore`, tope 999 por
material). Ids en inglés; nombres en `data.materials.smith.<id>.name`.

| Bioma | Mena (nivel) | Lingote | Raro del bioma |
|---|---|---|---|
| Bosque | `ore_copper` Mena de cobre (1) | `ingot_copper` | `rare_amber` Ámbar de raíz |
| Ruinas | `ore_bronze` Mena de bronce rúnico (2) | `ingot_bronze` | `rare_cog` Engranaje antiguo |
| Cavernas | `ore_frost` Mena de hierro helado (3) | `ingot_frost` | `rare_rime` Cristal de escarcha |
| Grieta | `ore_ember` Mena de acero ígneo (4) | `ingot_ember` | `rare_magma` Corazón de magma |
| Abismo | `ore_echo` Mena de plata del eco (5) | `ingot_echo` | `rare_sand` Arena detenida |

Especiales: `schematic` Plano antiguo (receta, vetas de mazmorra) y
`guardian_core` Núcleo de guardián (jefes).

### 2.1 Colección de materiales

OFICIOS → Herrería → COLECCIÓN, sobre la plantilla compartida
`DsCollectionTemplate` (design_system.md § 6.1;
`lib/features/world/presentation/panels/smith_collection.dart`). Por
jugador,
`LifeSkills.oreLog` (JSON `ol`: `{id: [día, origen, total]}`): primer
hallazgo, origen (`mine:<bioma>`, `dungeon:<zona>`, `boss`, `smelt`) y
cuántos se encontraron en total. Usos por material, sacados de los datos
(`SmithCollection.usesOf`: `smelt`, `forge`, `rare`, `legend`).
`SmithCollection.entries(perfil)` devuelve cada material (id, ícono del
manifest, clave del nombre, descubierto y filas como clave i18n +
argumentos `ui.inventory.smith.col.*`); los no descubiertos van sin
filas (la UI los muestra como "?" gris, sin pistas).

UI: subtabs TODOS / MENAS / LINGOTES / RAROS / ESPECIALES y contador
descubiertos/total. Material descubierto: dónde se encontró (mina de un
bioma, veta de mazmorra con su bioma y zona, fundido en la forja o
guardián de zona), primer día, usos, rareza (color y etiqueta), total
encontrado y cuántos tenés. Tipografía por rol del sistema de diseño,
sin cortes; test de overflow en
`test/features/world/smith_collection_test.dart`.

### 2.2 Ingresos del herrero

- AGROPECUARIO › MINERÍA › VENDER: menas `orePricePerTier` × nivel,
  lingotes `ingotPricePerTier` × nivel (un lingote vale más que sus
  `smeltOre` menas + la fundición), raros `rarePricePerTier` × nivel,
  especiales `specialPrice` (`SmithCraftRules.sellPrice`). Lo que trae
  una vagoneta se vende igual.
- Armas forjadas: marca `smith-` en el uid; venden × (`forgedSellMult` +
  `forgedSellPerRarity` × rareza) sobre el botín de igual rareza.
- Pedidos de herrería: con la infraestructura de pedidos de vecinos, si
  alguien de la sala tiene Herrería, con `smithOrderChance` el pedido es
  un lote de lingotes (`smithOrderMin..Max`, nivel ≤ 1 + Herrería / 5),
  pagado × `smithOrderPay`. (Pedidos de un arma forjada: pendiente.)

## 3. Fundir

En la FORJA del pueblo, pestaña HERRERÍA → FUNDIR: `smeltOre` menas +
`smeltGoldPerTier` × nivel de oro → 1 lingote. XP `smeltXp` × nivel por
lingote. Lotes ×1 / ×5. Cualquiera puede fundir.

## 4. Forjar un arma

HERRERÍA → FORJAR: grilla de bases del catálogo de armas (las de nivel ≤
el nivel de objeto posible), detalle a la derecha con lingote, rareza y
costo. `SmithAction(forge, base, ingot, rareza)`.

- Nivel de objeto = mín(nivel del personaje − `craftIlGap`, `ingotIlPerTier`
  × nivel del lingote). Las mejores armas siguen saliendo de las mazmorras.
- Costo: lingotes por rareza (`ingots<Rareza>`), materiales raros del
  bioma del lingote (`rare<Rareza>`, desde Raro) y `craftGoldPerIl` × nivel
  de objeto.
- Rareza por nivel de Herrería:

| Rareza | Nivel | Lingotes | Raros | Extra |
|---|---|---|---|---|
| Común | 1 | 3 | 0 | |
| Mágico | `lvMagico` 4 | 4 | 0 | |
| Raro | `lvRaro` 10 | 6 | 1 | |
| Épico | `lvEpico` 18 | 8 | 2 | |
| Legendario | `lvLegend` 25 | 10 | 3 | 1 Plano antiguo **o** 1 Núcleo de guardián |

- Legendario = un único (`LootRules.pickUnique`) con preferencia por la
  familia de la base elegida; usa el Plano si hay, si no el Núcleo.
- Mods, elemento y pasiva salen como un arma de cofre de esa rareza.
- XP: `craftXp` × (rareza + 1).

## 5. Encargo a Brann

HERRERÍA → BRANN (solo con Brann viviendo en una casa, roles.md § 4):
la misma receta, pero Brann pone el oficio. Paga `brannGoldPerIl` × nivel
de objeto en vez de `craftGoldPerIl`. Rareza máxima = la del encargo de
forja (`ResidentRules.commissionRarity`: oficio más alto + relación;
legendaria solo arraigado, con su objeto y el oficio en
`comLegendLevel`), y el legendario igual pide el Plano o el Núcleo. Da
`smithXpCommission` / 2 de Herrería a quien lo pide. Es la extensión
del encargo de forja de siempre, que sigue igual.

## 6. Red

- Protocolo 71: `ore` y `ol` en `LifeSkills`, acciones `mine` y `smith`
  (`o`, `b`, `g`, `r`, `n`), `PoiKind.ore`, lugares `mine:<bioma>:<i>`.
- Protocolo 77 (minas v2, sobre las regiones de bioma del 76): `mn` en el bloque del pueblo; `mine` con
  `o` (op: dig, bomb, torch, boost, use, hire, fire, unload, buy, craft,
  sell), `x`, `y`, `i`, `g`, `n`; eventos `mDug`, `mBomb`, `mBlast`;
  lugares `mine:<bioma>:<i>:<nivel>`.
- Todo lo valida el anfitrión (distancia, veta lista, pueblo, costo,
  nivel, Brann). La Travesía rechaza todo.

## 7. Balance

Números en `kTuning[TuningId.smithing]` con etiqueta en Balance. Prueba
`test/game_engine/mining_smithing_test.dart`: el nivel de objeto
forjado queda debajo del personaje, la rareza respeta el nivel y un
Épico forjado cuesta al menos `ingotsEpico` × `smeltOre` menas.

## 8. Pendiente

- Arte final (tiles de mina, vagonetas, mineros, íconos: placeholders).
- Pedidos de vecinos de un arma forjada (hoy solo lotes de lingotes).
- Roca que se vuelve a cerrar (opcional).
- Frases de las piedras con inscripción: **BORRADOR**.
- Materiales de temporada: el gancho existe (§ 0) pero ningún material
  tiene `seasons` todavía.
