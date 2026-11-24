# Spec: Cultivo, huerta compartida y ampliaciones del pueblo

Estado: implementado en v0.23.0 (protocolo 44). Visión: `town_loop.md`
§ 3.2, § 3.4, § 4 y § 11c; la profundidad toma como referencia la pesca
(`fishing.md`). Árboles de talentos de los oficios:
`life_skill_trees.md`. Lore: solo `docs/lore.md` (tiempo, ecos, futuro
inmutable, pasado magitec).

Todo número de esta spec está en Editor → Balance → Cultivo
(`kTuning['farming']`), → Pueblo (`kTuning['town']`) o → Oficios:
árboles (`kTuning['lifeTree']`), salvo los datos de catálogo (cultivos,
herramientas, abonos), que viven en `lib/game_engine/data/farming_catalog.dart`.

Código: `farming_catalog.dart`, `models/farm_skills.dart`,
`models/farm_plot.dart`, `rules/farming_rules.dart`,
`rules/town_rules.dart`, `rules/session_engine_farming.dart`,
`map/farm_layer.dart`, `panels/fountain_panel.dart`,
`panels/trader_panel.dart`, `panels/life_items_view.dart`.

---

## 1. Cultivo (habilidad de vida)

- XP y nivel por personaje, como Pesca: `xpBase × l^xpExp` por nivel,
  tope `maxLevel` (30). JSON `life.farm.xp`.
- Se ve donde se ve Pesca: PERSONAJE (línea OFICIOS y pestaña OFICIOS),
  el agropecuario y la pestaña PESCA Y CULTIVO.
- XP por cosecha: `xp base × xp<Rareza> × qualityMult<Calidad>` (+ el
  árbol). Arar, plantar y regar dan `workXp` (3 desde v0.45.0; antes 1). Los
  cultivos de la zona 1 dan × 1.5 de XP base desde v0.45.0 (nabo 9,
  trigo 11, … raíz de la Era 263). XP de personaje por
  cosecha `charXp<Rareza>` con tope `charXpCap` por estadía en el pueblo
  (aparte del de la pesca).

## 2. Huerta en el mapa (sin ventanas)

### 2.1 Dónde
- Tile nuevo `u` (tierra, caminable). Huerta del pueblo base: x 19–22,
  y 18–20 (12 parcelas, al sur del camino de la torre). Desde v0.24.0
  cada huerta es una construcción que se pone, mueve y borra en la
  edición del pueblo (`town_editor.md`): HUERTA 6 × 4 o 4 × 3.
- Se trabaja el tile de enfrente (a 10 px en la dirección que mira) o
  el que se pisa. El host acepta labores a ≤ `reachPx` (30 px) del centro
  del tile y como mucho una cada `minWorkSec`.

### 2.2 Labores (tecla E, según la herramienta en la mano, v0.24.1)
| Herramienta en la mano | Sirve en | Si no sirve, el aviso dice |
|---|---|---|
| Azada | Tierra sin arar (área según azada, § 4) | "Ya está arada" |
| Semilla (la del carrusel) | Arada vacía | "Primero arala" / "Ya está plantada" / "Sin semillas: comprá en el agropecuario" |
| Regadera | Plantada, creciendo (área según regadera) | "Primero arala" / "Primero plantá" |
| Cualquiera | Madura: cosechar (pop + aviso + chat) | — |

Con una herramienta que no sirve, E / clic no hacen nada (el aviso dice
por qué). La cosecha funciona con cualquier herramienta elegida: así no
hay que cambiar de mano para levantar lo maduro.

F abona la parcela de enfrente con el mejor abono que tengas. E o el
clic izquierdo sobre el mapa hacen la labor (igual que la pesca).

### 2.5 HUD de herramienta (v0.23.2, herramienta activa desde v0.24.1)
- A 2 tiles o menos de cualquier tierra de huerta (todas las zonas,
  también las que suma ampliar el pueblo, porque se mira el tile `soil`
  del mapa) aparece el HUD de herramienta. Desde v0.24.4 es una barra
  abajo al centro de la pantalla (372 px), entre el chat (abajo a la
  izquierda) y las pociones y la tarjeta del grupo (abajo a la derecha),
  sin tapar ninguno a 1280×720 ni a 1024×640: con una herramienta en la
  mano el chat se angosta para dejarle lugar. Cerca de la orilla manda la
  caña (fishing.md § 4.0), en el mismo lugar: ícono de la caña (32 px) y
  el botón con su nombre.
- Justo arriba de la barra, centrado, el aviso en una línea (nunca se
  parte; si no entra, termina en "…"): "[E o clic] Arar", "[E o clic]
  Plantar Nabo del claro", "[E o clic] Regar · 45 %", "[E o clic]
  Cosechar · 3 % legendaria" o el motivo si la herramienta elegida no
  sirve ("Primero arala").
- La barra: tres casilleros de ancho fijo, Azada | Semilla | Regadera.
  Íconos de herramienta de 32 px; carrusel de semillas con la elegida de
  40 px al medio y la anterior y la siguiente de 24 px a los costados, y
  abajo el nombre de la semilla y la cantidad. Los rótulos se ven enteros
  (bajan de línea antes que cortarse). El nombre completo de la
  herramienta va en el tooltip (tamaño fijo). El
  elegido lleva el borde dorado de selección. Clic en un casillero lo deja
  en la mano (no hace la labor).
- Cuarto casillero ABONO (v0.24.4; la barra pasa a 480 px): ícono del
  abono elegido, rótulo "Abono [F]" y la cantidad. Por defecto el mejor
  abono que tengas; clic en el ícono pasa al siguiente propio (elección
  local, no se guarda). Con ABONO en la mano, E / clic abona la parcela
  de enfrente con ese abono (`FarmTileAction` con el id del abono en
  `seed`, como ya aceptaba el host: sin cambio de protocolo). Motivos si
  no sirve: "Primero arala", "Primero plantá", "Ya tiene abono", "Sin
  abono: comprá en el agropecuario". F sigue abonando con el abono
  elegido sin cambiar de herramienta, y frente a una parcela plantada sin
  abono el aviso suma "· [F] Abonar".
- Controles: Tab (Mayús+Tab al revés) o la rueda del mouse cambian de
  herramienta; Q o ] la semilla siguiente, [ la anterior (también clic en
  las semillas de los costados); E o clic izquierdo en el mapa hacen la
  labor; F abona. Los números quedan para las pociones.
- Elección por defecto: mientras no elijas a mano, la herramienta sigue lo
  que pide la parcela de enfrente (sin arar → azada, arada → semilla,
  plantada → regadera). Una elección manual se respeta hasta que te alejás
  de la huerta; al volver, otra vez sugiere.
- Objetivo: el tile (o los tiles, con el área de la azada o la regadera)
  que va a tocar el próximo E / clic se marca con un recuadro: verde si la
  herramienta sirve, naranja si no. Solo lo ve el jugador local; colores
  en `FarmPalette`.
- En la mano se ve la herramienta elegida (azada, bolsita de semillas con
  el color del fruto o regadera) y no el arma. Igual con la caña cerca del
  agua. Los demás jugadores ven sin arma a quien tiene la línea afuera o
  está cerca de la huerta (se deduce de la posición, con la azada; sin
  protocolo nuevo).
- Solo en el pueblo; nunca en misiones.
- Se equipan desde PERSONAJE → PESCA Y CULTIVO (§ 11) o el agropecuario:
  EQUIPAR en cada azada / regadera (`farmShop` `equipTool`, ya autoritativo
  del anfitrión; no hace falta protocolo nuevo).

### 2.3 Crecimiento (elegido para co-op y para jugar afuera)
- La huerta crece mientras la sala está abierta, en el pueblo y también
  durante las misiones (el host la avanza de a 1 s): regada a ritmo del
  riego (`waterRate`), seca a `dryRate` (0.5 desde v0.45.0; antes 0.35). Cada riego dura
  `waterSec` (240 s, más con la regadera y el árbol).
- Cada misión ganada suma `missionGrowSec` (600 s desde v0.45.0; antes
  420) a todo lo plantado (× `seasonGrowMult` si es de estación, § 16).
  Así una expedición de 10–12 min deja la huerta lista aunque nadie
  riegue.
- Con el juego cerrado no crece nada (sin reloj real: nadie pierde ni
  gana por no conectarse, town_loop.md § 1).
- Etapas visibles: semilla (< 20 %), brote, crecido (≥ 55 %), maduro
  (100 %, con brillo). Arado con surcos; regado, tierra oscura y una gota;
  abonado, granitos claros. Dibujado en `MapFarmLayer` (colores en
  `FarmPalette`); registrado como procedural.
- Aspecto por cultivo (v0.25.3): la semilla es un puntito del color de
  su tipo en un punto al azar del tile, determinista por parcela, cultivo
  y quien plantó (`MapFarmLayer.seedOffset`), así todos los clientes lo
  ven igual y no salta. El brote y la planta crecen desde ese punto; al
  madurar muestran el fruto con forma y color propios (`CropPalette` en
  `map_themes.dart`: semilla, planta, fruto, acento y forma `CropShape`):
  nabo (raíz blanca con cuello violeta), trigo dorado (espigas doradas),
  papa (tubérculos grises al pie), calabaza (naranja con gajos), frutilla
  (bayas rojas), cebolla de cobre (bulbo cobrizo con tallos), flor rúnica
  (flor azul), melón engranaje (melón verde rayado), trigo del Mañana
  (espigas claras), rosa del Reloj Quieto (rosa roja) y raíz de la Era
  Antigua (cristal turquesa). Los legendarios destellan; el brillo de lo
  maduro se mantiene. Pixel art procedural, sin cambios de protocolo.
- La cosecha "salta" del tile hacia quien cosechó con chispas (como el
  pez) y el nombre con la calidad arriba del personaje.

### 2.6 Cartel de subida de nivel de oficio (v0.25.3)
- Al subir Pesca o Cultivo aparece un cartel pixel arriba del personaje
  (encima del nombre): "¡Subiste de nivel!" (los demás ven "<nombre>
  subió de nivel") y "Pescador N" / "Granjero N". Sube y se desvanece en
  2,5 s, con el sonido de subida de nivel.
- Sin evento nuevo: cada cliente compara el nivel de oficio del perfil
  que manda el host con el último que vio (`MapLifeLevelLayer`), así lo
  ven todos y el protocolo no cambia.

### 2.4 Huerta compartida: cada labor usa a quien la hace
Cualquiera planta, riega, abona o cosecha cualquier parcela. Cada parcela
guarda los aportes (JSON de la parcela):

| Aporte | Guarda | Efecto |
|---|---|---|
| Plantar | `pq` potencial (puntaje de quien plantó con su azada), `b` velocidad del árbol, `pb` nombre | potencial base de la calidad |
| Regar | `wq` calidad media de los riegos, `wn` cantidad, `wr` ritmo del último riego, `wb` nombre | un regador de nivel bajo riega más lento (`waterRateMin` 0.6 con nivel 1, 1 desde el 10) |
| Abonar | `f` abono, `fb` nombre | sesgo de calidad del abono y × crecimiento |
| Cosechar | — | el puntaje de quien cosecha pesa más (`sHarvest`) |

Puntaje de una persona: `pBase + (nivel − 1) × pPerLevel + calidad de
la herramienta (azada o regadera, con su efectividad) + «calidad» del
árbol`.

Puntaje S de la cosecha:
`S = pq × sPlant + wq × fracción regada × sWater + sesgo del abono +
puntaje de quien cosecha × sHarvest`.

Calidad (normal / rara / épica / legendaria): pesos `wQNormal`,
`wQRaro`, `wQEpico`, `wQLegendario` (70/22/7/1), multiplicados por
`(1 + S)^0..3`. Con nivel bajo casi todo sale normal; con nivel alto,
abono del Eco y buenos nodos la legendaria sube muchísimo (el test de
reglas compara cosechador bajo y alto sobre la misma parcela).

Desde v0.24.0 las parcelas no tienen tooltip: el cartel de cada huerta
dice qué hay plantado (`town_editor.md` § 6). El aviso de abajo sigue
mostrando las chances de la parcela de enfrente.

## 3. Semillas, cultivos y calidad

### 3.1 Zona 1 (11 cultivos)
| Cultivo | Rareza | Crece | Precio | Semilla |
|---|---|---|---|---|
| Nabo del claro | común | 2.5 min | 10 | 4 |
| Trigo dorado | común | 3.3 min | 13 | 5 |
| Papa de piedra | común | 4 min | 16 | 6 |
| Calabaza del sendero | común | 5 min | 20 | 8 |
| Frutilla de rocío | rara | 7 min | 42 | 25 |
| Cebolla de cobre | rara | 8 min | 50 | 30 |
| Flor rúnica | épica | 14 min | 130 | no se vende |
| Melón engranaje | épica | 15 min | 150 | no se vende |
| Trigo del Mañana | legendaria | 25 min | 850 | no se vende |
| Rosa del Reloj Quieto | legendaria | 27.5 min | 950 | no se vende |
| Raíz de la Era Antigua | legendaria | 30 min | 1100 | no se vende |

Los legendarios son ecos (futuro inmutable, reloj quieto, pasado
magitec): nombres y textos esperan el OK del dueño. Todo personaje
arranca con 6 semillas de nabo, azada de rama y regadera de lata.

### 3.1b Bosque (v0.26.0)

Tres semillas exclusivas que salen solo de recolectar en el exterior del
Bosque (`forageSeedChance`): Helecho dulce, Arándano de sombra y Seta del
reloj. Se plantan en la huerta del pueblo; no se venden. Los productos
silvestres (Moras del bosque, Hierba de rocío, Hongo ámbar) son cosechas
de calidad normal que no se plantan. Recolectar da XP de Cultivo. Ver
`overworld_biomes.md` § 3.2 y § 3.3.

### 3.1c Biomas de v0.29.0

Tres semillas exclusivas por bioma (Ruinas, Cavernas, Grieta, Abismo;
lista en overworld_biomes.md § 3.5) y tres productos silvestres. Salen de
recolectar; la común y la rara también las vende el habitante del bioma
(overworld_biomes.md § 9.1). Cada una tiene su `CropLook`.

### 3.2 Abonos
| Abono | Precio | Sesgo (`fert<K>Bias`) | Crecimiento (`fert<K>Speed`) |
|---|---|---|---|
| Abono | 20 | +0.4 | × 1.15 |
| Abono rúnico | 120 | +1 | × 1.3 |
| Abono del Eco | 600 | +2 | × 1.5 |

Tooltip: "Mejora las chances: normal / rara / épica / legendaria".

### 3.3 Precio por calidad
`qualityMult<Calidad>`: normal 1, rara 1.3, épica 1.8, legendaria 3
(precio y XP).

## 4. Herramientas (como las cañas)
Espacio de herramienta aparte de las armas; se compran en el agropecuario
y rinden según `efectividad = piso + (1 − piso) × (nivel/requerido)^curva`
(town_loop.md § 11c).

| Herramienta | Nivel | Calidad | Área | Extra | Precio |
|---|---|---|---|---|---|
| Azada de rama | 1 | 0 | 1 tile | — | inicial |
| Azada de hierro | 5 | 0.15 | cruz | 10 % cosecha doble | 350 |
| Azada de bronce rúnico | 12 | 0.3 | 3 × 3 | 20 % | 1400 |
| Azada del Eco | 22 | 0.5 | 3 × 3 | 35 % | 4800 |
| Regadera de lata | 1 | 0 | 1 tile | — | inicial |
| Regadera de cobre | 5 | 0.1 | cruz | riego + 25 % | 300 |
| Regadera de bronce rúnico | 12 | 0.2 | 3 × 3 | + 50 % | 1300 |
| Regadera del Eco | 22 | 0.35 | 3 × 3 | + 100 % | 4500 |

El área efectiva es `floor(área × efectividad)`: con nivel bajo, una
herramienta de área trabaja menos tiles.

## 5. Hallazgos de la huerta (como el botín del agua, más chico)
- Cada cosecha devuelve una semilla del mismo cultivo con
  `seedDropChance` (55 % desde v0.45.0; antes 40 %; no las legendarias).
- Hallazgo: `lootChance` (12 % desde v0.45.0; antes 7 %) × (1 + `lootLevelBonus` × (nivel − 1)) ×
  árbol. Pesos: semilla rara o épica 60, Esquirlas 35
  (`lootMatMin`..`lootMatMax`), semilla legendaria 5.
- Pity: `farm.dry` cosechas sin hallazgo → a las `lootPityAfter` (40),
  semilla rara o Esquirlas seguras. `farm.pity` cosechas sin semilla
  legendaria → a las `legendPityAfter` (100 desde v0.45.0; antes 150),
  una segura.
- Aviso "encontró en la tierra: …", chat y un pop con el color de la
  rareza.

## 6. Ampliaciones del pueblo (fuente rúnica)
- E en la fuente abre FUENTE RÚNICA (el tablero es un botón del panel)
  con EDITAR PUEBLO para el dueño del mundo.
- Desde v0.24.0 se amplía por lado (norte, sur, este, oeste) en la
  edición del pueblo y lo que se construye se elige tile a tile:
  `town_editor.md` § 2 y § 3. Ya no hay espacios LAGO / HUERTA por
  franja ni la regla de solo al este.
- Costo de la n-ésima (en total): oro `expGoldBase × expGoldMult^(n−1)`
  (1500, 3750, 9375...), Esquirlas `expEsquirlas × n`, Cristales de Era
  `expCristales × (n − 1)` desde la segunda. Topes `maxExpansions` (6)
  y `maxPerSide` (3).
- El mapa del pueblo sale de `MapGenerator.townOf(TownState)` vía
  `TownPlan` (determinístico): todos lo ven igual.

## 7. Peces en el lago
- Cada lago tiene sus peces (v0.24.0, `town_editor.md` § 5): se
  sueltan desde AGREGAR ESPECIES en la edición del pueblo o desde la
  pestaña PESCA Y CULTIVO (al lago más cercano); no la basura.
  Capacidad por lago `max(lakeMin, tiles × lakePerTile)`.
- Sesgo: cada pez soltado agrega su especie `stockWeight` veces más a la
  tirada (tope `stockWeightCap` por especie). Una especie que no era del
  lago pasa a estar (así se traen especies de otros biomas).
- Cría: al ganar una misión, cada especie con 2 o más cría (+1) con
  `breedChance`, hasta la capacidad de su lago. Rareza extra del lago
  donde se pesca: `lakeZoneRare` por cada 36 tiles por encima de 48 +
  `breedRare` por especie criando (tope `breedRareCap`).

## 8. Ayudantes: granjeros y pescadores (v0.25.5)
### 8.1 Contratar
- En EDITAR PUEBLO (solo el dueño): clic en una huerta o un lago →
  GRANJEROS / PESCADORES "1 / 3" → CONTRATAR AYUDANTE (`helperCost`, 800
  de oro; pide Cultivo o Pesca `helperLevel`, 5) o DESPEDIR (el último;
  sin devolver oro).
- Atajo desde la FUENTE RÚNICA (v0.25.7): CONTRATAR GRANJERO / CONTRATAR
  PESCADOR cierra el panel y entra a la cámara libre de la edición en
  modo elegir (`TownEdit.hire`): barra "Elegí una huerta para contratar
  un granjero" / "¿En qué lago querés el pescador?" con CANCELAR [ESC];
  solo se resaltan las huertas (o los lagos), verdes si se puede y grises
  si no, cada una con su tarjeta "Granjeros n / max" y el costo o el
  motivo (lleno, falta oro, falta nivel de Cultivo o Pesca). Clic en una
  habilitada = la misma acción `TownOp.hireHelper` y sale. Solo el dueño;
  sin huertas (o lagos) el botón sale gris con el motivo. Sin cambio de
  protocolo.
- Tope por tamaño: huerta `ceil(parcelas / helperPlots)` (12 desde v0.45.0; antes 8), lago
  `ceil(tiles / fisherTiles)` (18). Huertas pegadas se funden en una
  (como los lagos): suman parcelas, ayudantes, semillas y cofre, y crece
  el tope. El cartel y las opciones dicen "Granjeros 1 / 2 · cada uno
  atiende 12 parcelas".
- Áreas automáticas sin pisarse: el granjero i atiende las parcelas
  i·12 … i·12+11 de la huerta, fila por fila. El pescador i (v0.28.0), un tile de
  la orilla pegado al agua por un lado (nunca la esquina en diagonal),
  libre del cartel, el cofre y otras construcciones: el primero, el más
  cerca del cartel; los demás, cada vez más lejos (`fisherSpot`).
- NPC visibles con sprite propio (`items.vida_npc_granjero[_trabajo]`,
  `vida_npc_pescador[_trabajo]`, `tool/export_life_icons.dart`). El
  granjero va de parcela en parcela de su área (trabaja 60 % del paso,
  camina el resto); el pescador tira la línea en su lugar: mira al tile
  de agua pegado a su lugar (`fisherFacing`: derecha/izquierda, después
  abajo, después arriba; el sprite se espeja si mira a la izquierda) y,
  trabajando, se dibujan caña, línea y boya en ese tile, con un vaivén
  suave según el tiempo de animación (`MapFishingLayer.drawHelperLine`).
  Se deriva en cada cliente; no viaja por la red. La posición
  sale del reloj de la sala (igual en todos). No son sólidos y nunca
  tapan la huerta: E / clic en una parcela sigue siendo del jugador.
- Mouse encima de un ayudante (jugando o editando): contorno de su área
  y tooltip fijo (nombre, parcelas, semillas, tareas, "Próximo ciclo:
  regar · 12 s").
- G al lado de un ayudante ("[G] Ayudante" en el aviso): su pantalla.

### 8.2 Vuelta del granjero
- Cada `helperEverySec` (45 s, ÷ (1 + «Capataz»)), alineado al reloj de
  la sala, cada granjero hace UNA sola tarea en toda su área: la
  primera prendida que tenga algo para hacer, en orden fijo: (1) PLANTAR
  tiles vacíos si tiene semillas, (2) REGAR las plantadas secas, (3)
  COSECHAR las maduras al cofre. Si ninguna aplica, descansa.
- Riego automático (v0.45.0): además de su tarea, en cada vuelta riega
  solo toda parcela plantada, seca y sin madurar de su área (ritmo
  `waterRateMin`), aunque tenga REGAR apagado (`TownRules.autoWater`).
  Por eso un granjero con COSECHAR prendido nunca queda bloqueado por
  falta de riego (§ 8.6).
- Las tareas se prenden y apagan por granjero (pestaña TAREAS); se
  guardan en `tk`. Con una sola prendida, solo hace esa.
- Solo planta de SU inventario de semillas (el de la huerta, compartido
  por sus granjeros): sin semillas solo riega y cosecha. Cosecha
  calidad normal, sin hallazgos; deja la parcela arada para la próxima
  vuelta de plantar. Los jugadores trabajan cualquier parcela cuando
  quieren con sus propias stats; el granjero sigue con lo que encuentra.
- Pantalla del granjero (G): SEMILLAS (grilla tipo inventario: tus
  semillas y las de la huerta, filtro por rareza y buscador, detalle con
  PASAR 1 / 10 / TODO → o ← DEVOLVER), TAREAS y COFRE.

### 8.3 Cofre
- Cada huerta y cada lago tiene un cofre al lado del cartel (se mueve
  con la construcción, no es sólido) (sin número encima desde v0.38.1). E al
  lado: RECOGER todo a la bolsa PESCA Y CULTIVO, con `helperXpShare`
  (10 %) de la XP. Tope `chestMax` (200): lleno, no cosechan ni pescan.
- Estado a la vista (v0.33.1): vacío se dibuja apagado
  (`FarmPalette.chestEmpty`, multiplicado sobre el sprite y opaco; desde
  v0.36.4 sin transparencia, que lo fundía con el pasto); con cosas, con un brillo atrás
  (`chestGlow`); lleno, con marco en `chestFull`. Sin número (v0.38.1).
  Mouse encima: tooltip del mapa "Cofre vacío", "Cofre: N objetos" o
  "Cofre lleno" (`HelperRules.chestText`). Sale del pueblo del estado,
  sin cambio de protocolo.
- Pescador: cada vuelta saca `fisherCatch` (2) peces de la tabla de su
  lago (+ «Red de pescador») al cofre; nunca legendarios; XP como la
  vieja red (× `autoMult`) para quien recoge.
- Borrar la construcción: el cofre va a quien borra y las semillas de
  los granjeros vuelven.

### 8.4 Datos y migración
`TownBuild` suma `hp` (ayudantes), `ch` (cofre), `sd` (semillas), `tk`
(tareas por granjero). Saves viejos: `town.helper > 0` → un granjero en
la primera huerta; `town.silo` → el cofre de esa huerta. El granero del
agropecuario (RECOGER) ya no existe.

### 8.5 Progresión de cada ayudante (v0.27.0)

Ser granjero o pescador es una dedicación: cada ayudante contratado es
alguien con su nivel y sus mejoras. Números en Editor → Balance →
Pueblo.

- Nivel 1 a `helperMaxLevel` (10). XP por trabajo: 1 por parcela que
  planta, riega o cosecha; 1 por pez que saca. Del nivel l al siguiente:
  `helperXpBase` × l^`helperXpExp` (30 × l^1.4).
- Contratar cuesta `helperCost` (800) de oro + `hireMat` (5) de fibra
  vegetal (granjero) o cebo prensado (pescador), además del nivel del
  oficio de siempre.
- Pestaña MEJORAS en su pantalla (G): grilla tipo inventario, una
  casilla por mejora con rango, efecto, costo y MEJORAR. El rango r
  cuesta `upGold`·r de oro + `upMat`·r de fibra / cebo + `upTabla`·(r−1)
  tablas y pide nivel 1 + (r−1)·`upRankLevels` del ayudante. Tope
  `upMaxRank` (4) por mejora.
  - Granjero: PARCELAS (+`upPlots` parcelas que atiende; las áreas se
    corren una detrás de la otra), RITMO (+`upRitmo` de chance de una
    vuelta extra), CALIDAD (+`upCalidad` de chance de subir un escalón
    la cosecha), HALLAZGO (+`upRareSeed` de chance de una semilla rara
    para la huerta al cosechar).
  - Pescador: RED (+`upPeces` pez por vuelta), RITMO (igual), RAREZA
    (+`upRareza` de chance de tirar otra vez y quedarse con el pez más
    raro; nunca legendarios).
- Materiales de oficio: se hacen en el TALLER DE OFICIOS del pueblo
  (materials_economy.md § 4.4; v0.32.3). Viven en `life.cf` del perfil.
- Datos: `TownBuild.crew` (`cr`: `x` XP, `u` rangos por mejora). Los
  ayudantes de antes quedan en nivel 1 sin mejoras; fundir dos
  construcciones junta sus ayudantes con su progreso; despedir saca el
  último con lo suyo.
- Clima (day_night_weather.md § 3): con lluvia no hay nada que regar; con
  tormenta los pescadores sacan `stormFisher` de lo de siempre y los
  rayos pueden pegarle a una parcela.

### 8.6 Ayudante bloqueado (v0.33.1)

Un ayudante está BLOQUEADO cuando no puede hacer ninguna de sus tareas
ni ahora ni en ninguna vuelta futura sin que un jugador cambie algo
(`HelperRules.blockers(b, i)`: lista de motivos; vacía = no bloqueado).
- Granjero: sin área (`No hay parcelas asignadas`); sin tareas prendidas
  (`No tiene tareas prendidas`); si no, no está bloqueado mientras
  pueda (a) PLANTAR: tiene semillas y hay parcelas vacías, o se van a
  vaciar porque él cosecha; (b) REGAR: hay plantas creciendo; (c)
  COSECHAR: cofre con lugar y alguna planta madura o que va a madurar
  sola (regada, `dryRate` > 0 o él la riega). Bloqueado, los motivos:
  `Sin semillas para plantar`, `El cofre está lleno`, `Todas sus
  parcelas están plantadas` o, si ninguno aplica, `No tiene nada para
  hacer con sus tareas`.
- Pescador: no usa cebo y siempre tiene su lago; solo se bloquea con el
  cofre lleno (`El cofre está lleno`).
- Esperar NO es bloqueo: plantas creciendo, una parcela que se va a
  secar, la próxima vuelta: camina normal y sin marca.
- Bloqueado: se queda quieto en su primera parcela (el pescador deja la
  caña) y muestra el "!" dorado de los habitantes sobre la cabeza. Su
  pantalla (G) arranca con un aviso "!" y los motivos.
- Sin cambio de protocolo: host y clientes lo calculan del pueblo que ya
  viaja en el estado.

## 9. Agropecuario (vista CULTIVO)
Estructura en fishing.md § 5.3 (COMPRAR / VENDER → PESCA / CULTIVO →
categoría).
- COMPRAR: Semillas (×1 y ×5), Abonos (tooltip con lo que sesgan),
  Azadas y Regaderas (EQUIPAR / EQUIPADA).
- VENDER: Cultivos (el granero y cada cosecha por calidad) y
  Legendarios (VENDER o CANJEAR por `legendCristales` Cristales de Era y
  `legendPrismas` Prisma Roto). VENDER TODO no incluye las legendarias.
  Cobrar en oro o materiales (`matRate`, `matValue`), igual que la pesca.

## 10. Red y persistencia (protocolo 44; 45 desde v0.24.0)
- `GameSession.town` viaja en el estado (`town`: `lake`, `sides`,
  `builds` con sus parcelas y peces, `helper`, `silo`;
  `town_editor.md` § 7); el cliente arma el mapa con eso. El host lo guarda en el mundo (`accounts/worlds/<id>.json`,
  `town`) al volver de misión y al salir.
- Acciones: `farm {o: till|plant|water|fert|harvest, x, y, sd?}`,
  `farmShop {o, id?, n?, mat?}`, `town {o: expand|place|move|remove|
  stock|hireHelper, id?, tg?, x?, y?}` (`town_editor.md` § 8), `lifeTree {k, n?}`. Eventos: `cHarv {id, c, q,
  n, x, y, h?}`, `cLoot {id, l, r, x, y}`.
- Todo lo valida el host (pueblo, tile de tierra, alcance, cadencia,
  semillas y abonos propios, dueño para ampliar).
- Perfil: `life.farm {xp, hoes, hoe, cans, can, seeds, crops, sd,
  ferts, pity, dry, tree}`. Saves de antes de v0.23.0: sin `farm` →
  inicial (azada, regadera, 6 nabos). Mundo viejo: sin claves nuevas →
  pueblo sin ampliar y sin parcelas.

## 11. Pestaña PESCA Y CULTIVO (PERSONAJE)

> **v0.32.4:** reemplazada por PERSONAJE → OFICIOS → INVENTARIO, con
> bolsas de 40 casillas por oficio. Ver docs/specs/oficio_storage.md.
Desde v0.24.4 cada categoría es una grilla de casillas como el
inventario (`LifeItemGrid`, la misma del agropecuario): ícono de 32 px
con borde del color de la rareza o calidad, cantidad, marca "E" si está
equipada o elegida para plantar y un dato chico abajo. Clic en una
casilla la muestra en el panel de detalle (nombre en el color de la
rareza, etiquetas, datos completos y acciones). Nada se corta con "…".
Solo en el pueblo (en una misión dice "Disponible en el pueblo."). No
usa casilleros del inventario. Secciones: HERRAMIENTAS (cañas, azadas y
regaderas, la equipada con EQUIPADA y las otras con EQUIPAR), PESCADOS
(con SOLTAR EN EL LAGO, al lago más cercano), basura del agua, SEMILLAS (ELEGIR / PARA
PLANTAR), abonos y COSECHAS por calidad.

## 12. Pendiente
- Semillas de otros biomas en sus mazmorras (hoy solo zona 1).
- Arte en PNG (hoy procedural, como la pesca).
- Ciclo de eventos del pueblo (town_loop.md § 7).

## 13. Animales del bioma y CORRAL (especificado en v0.31.0, sin código)

Visión del dueño; nombres propuestos, esperan su OK (lore.md):
- Un animal por bioma: Bosque ciervo de musgo (leche de musgo), Ruinas
  gallina de engranaje (huevo de cobre), Cavernas cabra de escarcha (lana
  de escarcha), Grieta lagarto de brasa (escama tibia), Abismo polilla
  del eco (seda del eco).
- Se captura en su bioma con pienso hecho de cultivos (CONDENSAR) y se
  lleva al pueblo.
- CORRAL en EDITAR PUEBLO (candado y costo, como la CASA). Cada animal da
  un bien por día del mundo si se lo alimentó con cultivos; la felicidad
  sube la calidad.
- Los bienes entran en cocina, pociones, encargos de forja y órdenes.

## 14. Afinidad de los cultivos (v0.31.0)

- Cada cultivo crece más de día, de noche, con lluvia o parejo
  (`LifeTimeRules.cropAffinity`, primera pasada por id). En su franja
  crece × (1 + `affinityBonus`); fuera, × (1 − `affinityMalus`). Lo aplica
  el anfitrión en `farmTick` con el reloj del mundo.
- SEMILLAS muestra origen, tiempo de crecimiento, afinidad y rinde.
- Pendiente: registro de cultivos descubiertos ("???" hasta la primera
  cosecha) y filtros por bioma y hora en SEMILLAS / COSECHAS.

## 15. Estaciones de los cultivos (protocolo 69)

- `CropDef.seasons` (por defecto primavera, verano, otoño). nabo_escarcha,
  flor_cristal y lirio_eco crecen todo el año.
- Fuera de estación el cultivo **se frena** (crecimiento × 0): no muere ni
  pierde lo crecido. Vuelve a crecer al volver su estación.
- Solo de invierno (`winterOnly`): rabano_nieve (común, semilla 7),
  col_invierno (común, semilla 10), puerro_helado (raro, semilla 40).
  Solo se cosechan en invierno (`FarmingRules.harvestable`), también por
  el granjero.
- Las semillas muestran sus estaciones en la tienda y en los tooltips.
- Offline: solo crece mientras el host corre la sesión.
- COLECCIÓN de cultivos: weather_seasons.md § 7.

## 16. Bonus de estación (v0.45.0)

- Un cultivo **de estación** (sus estaciones no son las cuatro) en una
  de sus estaciones (`WeatherRules.season(sky.day)`):
  - se vende × `seasonPriceMult` (1.3) en el agropecuario
    (`FarmingRules.unitPrice(..., season)` / `sell(season:)`); el
    detalle muestra "De estación: +30 % de precio";
  - crece × `seasonGrowMult` (1.2): en el reloj de la huerta
    (`LifeTimeRules.cropGrowth`) y en el salto de cada misión ganada
    (`missionGrow(season:)`).
- Los cultivos de todo el año (nabo de escarcha, flor de cristal, lirio
  del eco) no tienen bonus. Fuera de estación sigue § 15 (se frena).
- Helpers: `LifeTimeRules.cropSeasonal`, `seasonGrow`, `seasonPrice`.

## 17. Cocina (v0.45.0, protocolo 73)

La olla del pueblo convierte cosechas (y a veces pescado) en comidas que
dan un buff para las próximas misiones.

- Dónde: OFICIOS → INVENTARIO → CULTIVO → COCINA (solo en el pueblo; el
  host valida `_inTown`). Subtabs RECETAS / COMIDAS / COLECCIÓN; RECETAS
  y COMIDAS usan la plantilla TALLER (`DsCraftGridTemplate`: grilla con
  el detalle a la derecha) con filtros TODAS / VIDA / ATAQUE /
  RESISTENCIA; COLECCIÓN usa `DsCollectionTemplate`. Arriba, la comida
  activa (o "Sin comida activa").
- Recetas (`kMeals`, `lib/game_engine/data/cooking_catalog.dart`):

  | id | Comida | Ingredientes | Efecto | Poder |
  |---|---|---|---|---|
  | sopa_nabo | Sopa de nabo | 3 nabo del claro | + vida | 1 |
  | pan_dorado | Pan dorado | 3 trigo dorado | + ATQ/MAG | 1 |
  | guiso_calabaza | Guiso de calabaza | 2 calabaza, 1 papa | resiste agua | 1 |
  | tarta_frutilla | Tarta de frutilla | 2 frutilla, 1 trigo | resiste fuego | 1 |
  | sopa_cebolla | Sopa de cebolla de cobre | 2 cebolla, 1 nabo | resiste electro | 1 |
  | caldo_invierno | Caldo de invierno | 2 col de invierno, 1 rábano de nieve | resiste hielo | 1 |
  | melon_glaseado | Melón engranaje glaseado | 1 melón engranaje, 2 trigo | + vida | 2 |
  | ensalada_runica | Ensalada rúnica | 1 flor rúnica, 1 frutilla | + ATQ/MAG | 2 |
  | mojarra_nabo | Mojarra con nabo | 2 nabo + 1 mojarra del claro | + vida | 1 |
  | trucha_cebolla | Trucha a la cebolla | 1 cebolla + 1 trucha de cobre | + ATQ/MAG | 1.5 |

- Cocinar (`FarmShopOp.cook`, `id` = receta, `n` = índice de calidad):
  gasta los cultivos de **esa** calidad (y el pescado de cualquier
  tamaño). La comida sale con esa calidad. Bolsa `farm.ml`
  (`<comida>@<calidad>` → cantidad); colección `farm.mlg` (mejor
  calidad cocinada). Las comidas no ocupan casillas de la bolsa de
  oficio.
- Buff = (`mealBuffBase` (0.05) × `qualityMult<Calidad>` +
  `mealBuffPerQuality` (0.03) × índice de calidad) × poder. Normal 5 %,
  rara 9.5 %, épica 15 %, legendaria 24 % (× poder). La resistencia se
  topa en 90 %.
- Comer (`FarmShopOp.eat`, `id` = clave de la bolsa) reemplaza la comida
  activa (`farm.mb {m, q, n}`); dura `mealMissions` (2) misiones, +1 si
  la receta lleva pescado (de 1 a 3 con los valores por defecto).
- Efecto: + vida máx. o + ATQ y MAG entran en `StatsCalculator` (como el
  poder de los oficios) vía `PlayerBuild.meal`; la resistencia reduce el
  daño de golpes con ese elemento al jugador en `BattleEngine` (modificador
  COMIDA en el desglose).
- Duración: cada fin de misión (ganada o perdida; no Travesía ni
  tutorial) resta una (`CookingRules.afterMission`).
- Co-op: cada perfil tiene su comida; el host aplica cocinar, comer y
  el vencimiento (host-authoritative). `PlayerBuild.meal` viaja en el
  build del combatiente (`meal`) para el HUD.
- HUD: chip COMIDA en la tarjeta de batalla (tooltip: comida, efecto y
  misiones que quedan) y línea "Comida: … (n)" con tooltip en el recuadro
  del jugador en el mundo.
- Balance (Editor → Balance → Cultivo): `mealBuffBase`,
  `mealBuffPerQuality`, `mealMissions`, `seasonPriceMult`,
  `seasonGrowMult`.

## 18. XP de Cultivo frente a Pesca (v0.45.0)

Objetivo: ~70 % de la XP por minuto de Pesca. Cuenta a mano (sin sim
automática): Pesca en zona 1 ronda 55–65 XP/min (≈ 6 capturas/min de
~9 XP). Cultivo con 12 parcelas de nabo (plantar + regar = 6 XP,
cosecha 9 XP) y ciclos de ~3.5–4 min (125 s de crecimiento de estación
más el recorrido) da ≈ 45 XP/min, más con calidad y cultivos raros.
Ajustable con `workXp`, `xp<Rareza>` y el XP base de cada cultivo.
