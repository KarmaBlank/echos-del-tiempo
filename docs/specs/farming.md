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
  árbol). Arar, plantar y regar dan `workXp` (1). XP de personaje por
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
  riego (`waterRate`), seca a `dryRate` (0.35). Cada riego dura
  `waterSec` (240 s, más con la regadera y el árbol).
- Cada misión ganada suma `missionGrowSec` (420 s) a todo lo plantado.
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
  `seedDropChance` (40 %; no las legendarias).
- Hallazgo: `lootChance` (7 %) × (1 + `lootLevelBonus` × (nivel − 1)) ×
  árbol. Pesos: semilla rara o épica 60, Esquirlas 35
  (`lootMatMin`..`lootMatMax`), semilla legendaria 5.
- Pity: `farm.dry` cosechas sin hallazgo → a las `lootPityAfter` (40),
  semilla rara o Esquirlas seguras. `farm.pity` cosechas sin semilla
  legendaria → a las `legendPityAfter` (150), una segura.
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
- Tope por tamaño: huerta `ceil(parcelas / helperPlots)` (8), lago
  `ceil(tiles / fisherTiles)` (18). Huertas pegadas se funden en una
  (como los lagos): suman parcelas, ayudantes, semillas y cofre, y crece
  el tope. El cartel y las opciones dicen "Granjeros 1 / 2 · cada uno
  atiende 8 parcelas".
- Áreas automáticas sin pisarse: el granjero i atiende las parcelas
  i·8 … i·8+7 de la huerta, fila por fila. El pescador i, un lugar de la
  orilla repartido por el borde.
- NPC visibles con sprite propio (`items.vida_npc_granjero[_trabajo]`,
  `vida_npc_pescador[_trabajo]`, `tool/export_life_icons.dart`). El
  granjero va de parcela en parcela de su área (trabaja 60 % del paso,
  camina el resto); el pescador tira la línea en su lugar. La posición
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
  con la construcción, no es sólido) con el número de cosas encima. E al
  lado: RECOGER todo a la bolsa PESCA Y CULTIVO, con `helperXpShare`
  (10 %) de la XP. Tope `chestMax` (200): lleno, no cosechan ni pescan.
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
