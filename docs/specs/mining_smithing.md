# Spec: Minería y herrería (v0.44.0 → minas v2, protocolo 72)

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
- Clima y estaciones (otra rama): cada material tiene `seasons` (vacío =
  todo el año). Hoy no se mira; el gancho de temporada filtra o pondera
  por ese campo sin tocar las reglas.

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

### 1.2 Niveles (`mineLevels`, 3–5)

`MineGenerator.generate(bioma, i, nivel, semilla, params)`:
`mineW` × `mineH` tiles (72 × 48), determinista (mulberry32; semilla
FNV de `<mundo>|<bioma>|<i>|<nivel>`; **ya no cambia por semana**).

- Roca maciza que se cava tile por tile; bolsones naturales por autómata
  celular (`caveDensity`), entrada en una cámara arriba al medio con la
  salida, el lugar de la estación de vagonetas (`Z`) y el punto de
  aparición.
- Borde de **roca madre** de 2 tiles (`X`, irrompible) y formaciones
  irrompibles sueltas (`formations`).
- Arroyos (`streamChance`, agua), grutas de cristal (`grottoChance`,
  `c`, brillan), pozo natural al nivel siguiente en un bolsón lejano
  (si queda encerrado, hay que cavar hasta él; el último nivel no tiene).
- Vetas en la roca, en racimos (`veinClusters` + 3 por nivel, tamaño
  `veinSizeMin..Max`): común `r`, rica `d`, profunda `e`, gema `a`; los
  pesos (`wCommon`, `wRich…`, `wDeep…`, `wGem…`, más por nivel) hacen
  que lo hondo sea más rico.
- **Hallazgos ocultos**: gruta secreta sellada (`secretChance`) con gemas
  y, con `relicChance`, un **cofre reliquia magitec** (`U`); cofres
  comunes (`$`, `chestRate`); hongos (`y`, `mushroomChance`, dan fibra);
  **piedra con inscripción** (`&`, `loreChance`; frases
  `ui.world.mine.lore.<n>`, **BORRADOR**).
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

### 1.8 Vagonetas

Vagoneta llena (`cartCap`) sale por riel al pueblo (`cartTravelSec`),
llega a la **estación de vagonetas del pueblo** (landmark `VAGONETAS`,
junto a la salida), rotulada con mina, nivel y bioma. E la descarga
(todo al que descarga) y vuelve vacía (`cartBackSec`). Todo lo decide el
anfitrión; en cooperativo cualquiera descarga.

### 1.9 Sensación

Golpe animado, chispas, grietas, escombros, mena volando al jugador,
sacudida de bomba, ganchos de sonido (`Sfx`). Todo cliente (`MineLayer`).

### 1.10 Guardado

`TownState.mines` (`mn` en el bloque del pueblo, también sincronizado a
los clientes): por nivel, tiles cavados, antorchas, hallazgos abiertos,
vetas que volvieron y sus relojes, estación, mineros y vagoneta.

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

### 2.1 Colección de materiales (datos; UI pendiente)

Para OFICIOS → Herrería → COLECCIÓN (la plantilla de grilla compartida
la arma otra rama; el integrador la conecta). Por jugador,
`LifeSkills.oreLog` (JSON `ol`: `{id: [día, origen, total]}`): primer
hallazgo, origen (`mine:<bioma>`, `dungeon:<zona>`, `boss`, `smelt`) y
cuántos se encontraron en total. Usos por material, sacados de los datos
(`SmithCollection.usesOf`: `smelt`, `forge`, `rare`, `legend`).
`SmithCollection.entries(perfil)` devuelve cada material (id, ícono del
manifest, clave del nombre, descubierto y filas como clave i18n +
argumentos `ui.inventory.smith.col.*`); los no descubiertos van sin
filas (la UI los muestra como "?" gris).

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

- Protocolo 69: `ore` y `ol` en `LifeSkills`, acciones `mine` y `smith`
  (`o`, `b`, `g`, `r`, `n`), `PoiKind.ore`, lugares `mine:<bioma>:<i>`.
- Protocolo 72 (minas v2): `mn` en el bloque del pueblo; `mine` con
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
- Estaciones (§ 0).
