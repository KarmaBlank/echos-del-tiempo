# Spec: Eventos del mundo (fase 1 del camino a la tienda de jugadores)

Cada N días del mundo (por defecto 5) el anfitrión tira uno o más
**eventos del mundo** al azar. La frecuencia y el azar se editan en el
Editor (área EVENTOS). Esta fase arma el modelo, el catálogo, la tirada
determinista, el guardado, la red, la UI de aviso y el editor; los
efectos de juego de cada categoría se conectan de a poco (§ 7).

## 1. Modelo

- `WorldEventCategory`: `visitor` (visitante en el pueblo),
  `overworldNpc` (alguien aparece en un bioma), `echoPortal` (grieta de
  eco con el jefe del bioma reforzado), `lore` (historia de un
  habitante), `caravan` (caravana de mercaderes en el pueblo).
- **Clima y estaciones (weather_seasons.md):** son un sistema propio.
  Este catálogo no tiene eventos de clima ni anomalía y no toca tablas
  de pesca, cultivos ni la forja/minería. Un evento puede pedir una
  estación o un clima con los campos opcionales `season` / `weather`
  (abajo). El anfitrión los aplica con
  `WorldEventContext.extraCondition` =
  `WorldEventRules.climateCondition(seed del cielo, día)`: estación del
  día (`WeatherRules.season`) y clima del pueblo ese día
  (`WeatherRules.dayWeather`). Los eventos del catálogo actual no los
  usan.
- `WorldEventDef` (una entrada del catálogo):
  - `id`, `category`, `enabled`, `weight` (≥ 0; 0 = nunca sale),
    `duration` (días, ≥ 1).
  - Condiciones: `minDay` (día mínimo del mundo), `minRenown` (renombre
    mínimo del mundo, renown_town_growth.md § 4.3), `biomes` (lista de
    biomas donde puede aparecer; vacía = cualquiera abierto; las
    categorías del pueblo siempre van al pueblo), `resident` (habitante
    que tiene que vivir en el pueblo; vacío = ninguno), `season`
    (`Season.name`: `spring`, `summer`, `autumn`, `winter`; vacío =
    cualquiera) y `weather` (`Weather.name`: `despejado`, `lluvia`,
    `tormenta`, `fog`, `snow`; vacío = cualquiera).
  - Textos (`LocalizedText`, todos los idiomas obligatorios, igual que el
    editor NPC): `title`, `notice` (la línea del chat al empezar),
    `body` (el detalle de la sección EVENTOS).
  - `params` (números): `hpMult`, `atkMult`, `levelBonus`, `rewardMult`
    (grieta), `gold`, `rep` (historia), `discount` (visitante y caravana). Los que faltan valen su
    neutro (1 para multiplicadores, 0 el resto).
  - Solo `lore`: `objective` (`LoreObjective`) y `target` / `n`.
  - `sprite`: id del NPC del evento en el manifest (`items.vida_<sprite>`;
    visitante, campo y caravana). Arte provisorio: `vida_npc_ev_*`.
- `WorldEventsConfig`: `interval` (días entre tiradas, ≥ 1, def. 5),
  `minPerRoll` / `maxPerRoll` (def. 1 / 2), `chance` (0–1, def. 1: si
  la tirada pasa) y la lista de `events`.
- `ActiveWorldEvent`: `def` (id), `biome` (dónde aplica; `pueblo` para
  las del pueblo), `start`, `end` (días del mundo; termina al llegar a
  `end`). Uid estable `<def>@<start>`.
- `WorldEventsState` (en `TownState`, JSON `wev`): `seed` (semilla del
  mundo para los eventos, la pone el anfitrión la primera vez y queda
  guardada), `last` (día de la última tirada), `active`, `seen` (ids de
  historias que ya salieron: cada historia sale una sola vez por mundo),
  `progress` (avance de cada historia por uid, JSON `pg`) y `cleared`
  (grietas ya ganadas: uid → jugadores, JSON `cl`).

## 2. Tirada (determinista)

- La tira solo el anfitrión, en el cambio de día del mundo (el mismo
  punto donde los habitantes piden cosas, `_skyTick`).
- Orden: primero vencen los eventos con `day >= end`; después, si
  `day − last >= interval`, se tira y `last = day`.
- Todo sale de `mulberry32(mix(seed, day))`: misma semilla y mismo día =
  mismos eventos (reproducible en tests y entre partidas).
- Pasos: si `rng() >= chance` no hay eventos ese día. Si no, la cantidad
  es `minPerRoll + floor(rng() × (max − min + 1))`. Se eligen por peso
  **sin repetir** entre los elegibles: habilitados, `weight > 0`,
  `minDay <= day`, habitante requerido viviendo en el pueblo, que no esté
  ya activo, historias no vistas. Grietas: nunca dos en el mismo bioma.
- Bioma: `biomes` del evento o, si está vacía, uno de los biomas
  abiertos (sin el pueblo) elegido con el mismo rng. Historias: el bioma
  de origen del habitante. Pueblo: `pueblo`.

## 3. Categorías

### 3.0 Actores en el mapa
Visitantes, gente del campo, caravanas y grietas tienen un lugar
(`WorldEventRules.spot`): en el pueblo, alrededor de la FUENTE RÚNICA
(sigue a la fuente si se mueve en EDITAR PUEBLO); en un exterior, en
pasto libre junto al camino. El orden entre los actores del mismo lugar
da el lugar. Se dibujan mientras dura el evento y con E (a menos de 26 px,
`WorldEventRules.near`) se abre su panel (`WorldEventPanel`): lo que dice
(aviso y detalle del catálogo) y, según la categoría, COMERCIAR o ENTRAR.

### 3.1 Visitante (pueblo)
Un viajero llega al pueblo unos días. COMERCIAR abre el puesto de
siempre (la grilla del AGROPECUARIO) con un cartel del descuento.
`discount` (`WorldEventRules.townDiscount`, el mayor de los eventos del
pueblo) lo aplica el anfitrión: en cada compra del puesto (cañas,
semillas, herramientas, abonos) devuelve `floor(oro gastado × discount)`.
No toca precios de las tablas.

### 3.2 Habitante en el campo
Alguien aparece en un bioma unos días (peregrinos, un autómata errante)
y se puede hablar con él (sus textos del catálogo).

### 3.3 Grieta de eco
Una grieta en el exterior del bioma lleva a una versión más fuerte del
jefe del bioma: el jefe de la **última zona** de ese exterior
(`BiomeDef.zones.last`, `ZoneDef.bossId`), con su misión de zona.
Escala: `WorldEventRules.rift` devuelve `EchoRiftBoss` (jefe, zona,
misión, `hpMult`, `atkMult`, `levelBonus`, `rewardMult`);
`applyRiftBattle` multiplica vida y ataque de los jefes de una batalla
recién creada (como `EcoRules.applyBattle`). Dura pocos días (def. 3).

- Portal visible en el exterior del bioma (§ 3.0). ENTRAR manda
  `ProposeRiftAction(uid)` (`rift`): el anfitrión valida lobby del
  bioma, frente al portal y que el jugador no la haya ganado; abre la
  votación de misión `rift` (con amigos en el mundo, convocatoria
  `GatherKind.rift`, igual que las misiones; `_joinable` suma a quien
  entre a una grieta en curso).
- Pelea directa con el jefe (como el Jefe del Abismo): arena de un piso
  del tipo de la zona, nivel `maxLevel` de la zona + `levelBonus`,
  `applyRiftBattle` al crear la batalla. No desbloquea zonas.
- Al ganar: cada jugador recibe `riftGold` = oro del jefe × `rewardMult`,
  el loot de fin de misión suma `rewardMult − 1` al bonus de rareza, y
  el portal se cierra para todos los que pelearon (`cleared`). Los
  demás lo siguen viendo hasta que vence.

### 3.4 Historia de un habitante
Atada al lore de un habitante que vive en el pueblo: desbloquea una
misión de historia nueva para él (`LoreQuest`). **Nunca es de traer
cosas.** Se basa en docs/lore.md: ecos que llegan del futuro o del
pasado, futuro que no se puede cambiar, pasado magitec.

Objetivos que hoy se siguen (`LoreObjective`):

- `defeat`: vencer `n` enemigos de tipo `target` (id de `kEnemies`). Lo
  cuenta el anfitrión en cada batalla ganada (`_loreDefeat`).
- `explore`: llegar al exterior `target` (id de bioma). Se cumple cuando
  un humano está en el lobby de ese bioma (`_loreExplore`, en el tick).

Escoltar, hablar, resistir y resolver quedan para cuando existan sus
sistemas: se sacaron del enum y del catálogo.

Al cumplirse: `gold` de oro para cada humano de la instancia, `rep` de
relación con el habitante, aviso en el chat y el evento sale de la
lista. El avance se ve en DIARIO → EVENTOS (`Progreso: x/n`).

### 3.5 Caravana
Mercaderes con restos del pasado magitec en el pueblo; `discount` como
el visitante.

### 3.6 NPCs de evento: diálogo y acciones

Visitantes, viajeros del campo y caravanas hablan en el cuadro de
diálogo de siempre (`DsDialogueBox`: escribe letra a letra, Saltar y
VOLVER, ui_minimal.md § 10.1) dentro de `EventNpcDialogue`. La grieta
sigue con su panel y ENTRAR.

- **Datos** (en `WorldEventDef`, todos `LocalizedText` con todos los
  idiomas obligatorios): `greeting` (primera línea; vacío = `notice`),
  `topics` (`id`, `label` = la pregunta, `line` = la respuesta) y
  `actions` (1–2, `EventNpcAction`: `kind`, `label`, `line`, `item`,
  `target`, `params`).
- **Saludo:** si aplica el reconocimiento por renombre
  (renown_town_growth.md § 4.2), esa línea reemplaza al saludo. Lugar y
  días que quedan van en la línea chica bajo el nombre.
- **Temas:** pila de nodos; la respuesta tiene solo VOLVER; los temas ya
  preguntados se ven atenuados.
- **Acciones** (lista fija, `EventActionKind`):
  - `gift` (REGALO): una vez por jugador, `item` × `qty` (material de
    forja, cebo o semilla; `WorldEventRules.giftItems`) y/o `gold`.
  - `rumor`: la respuesta del NPC y una insignia RUMOR en el mapa de
    viaje (`WorldEventRules.rumorMarks`) sobre `target`: `rift` = el
    bioma de la grieta activa, o un id de bioma. Dura lo que el evento.
  - `duel` (DUELO, solo viajeros del campo): pelea única contra el
    enemigo `target` por el camino de la grieta (`ProposeRiftAction`
    con el uid del evento; `WorldEventRules.duel` arma el `EchoRiftBoss`
    con la arena de la última zona del bioma y `hpMult`, `atkMult`,
    `levelBonus`, `rewardMult`). Cooperativo igual que la grieta. Al
    ganar: oro × `rewardMult`, +1 grieta de renombre y queda ganado en
    `cleared`.
  - `trade` (COMERCIAR, solo pueblo): el puesto con el descuento.
  - Pedidos (mostrar un arma, vencer al jefe) quedan para cuando haya
    seguimiento con sistemas existentes.
- **Estado por jugador** (anfitrión manda): `WorldEventsState.done`
  (JSON `dn`, `<uid>#<índice>` → jugadores) para regalo y rumor; el
  duelo usa `cleared`. Lo hecho se ve atenuado con "(hecho)".
  `EventNpcActAction(uid, índice)` (`wevAct`): el anfitrión valida
  lobby, lugar, frente al NPC y que no lo haya hecho.
- **Marca:** "!" sobre el NPC (mismo `NpcMark` y lugar que los
  habitantes) mientras le quede un regalo, rumor o duelo por hacer
  (`WorldEventRules.mark`). Comerciar no cuenta.

Valores del catálogo (BORRADOR es-AR, en, zh-Hans):

| evento | acciones |
|---|---|
| `visitor_clockmaker` | COMERCIAR + rumor `rift` |
| `visitor_chronicler` | rumor `cavernas` (una veta escondida) |
| `wanderer_forest` | regalo 3 × `larva_brillante` + rumor `rift` |
| `wanderer_automaton` | regalo 1 × `rare_cog` + duelo `guardianReloj` (vida ×1.4, ataque ×1.2, +2 niv, premio ×1.5); su tema habla de la mina de las ruinas |
| `caravan_relics` | COMERCIAR + rumor `ruinas` (reliquia magitec en la mina) |

## 4. Catálogo inicial (BORRADOR: textos del dueño pendientes)

Todos los textos de abajo son **BORRADOR**: es-AR, en y zh-Hans
escritos como borrador para que el archivo sea válido; el dueño los
reescribe.

| id | categoría | peso | días | condiciones | parámetros |
|---|---|---|---|---|---|
| `visitor_clockmaker` | visitante | 3 | 3 | — | discount 0.1 |
| `visitor_chronicler` | visitante | 2 | 2 | día ≥ 5 | — |
| `wanderer_forest` | campo | 3 | 3 | bosque | — |
| `wanderer_automaton` | campo | 2 | 3 | ruinas, día ≥ 10 | — |
| `echo_rift` | grieta | 3 | 3 | día ≥ 5 | hp ×1.6, atk ×1.3, +3 niv, premio ×1.75 |
| `lore_ilda_roots` | historia | 2 | 6 | vive Ilda | defeat `arana` ×3, 120 oro, +2 rel |
| `lore_velda_order` | historia | 2 | 6 | vive Velda | defeat `guardianReloj` ×1, 150 oro, +2 rel |
| `lore_kael_guardian` | historia | 2 | 6 | vive Kael | defeat `elementalEscarcha` ×2, 180 oro, +2 rel |
| `lore_brann_forge` | historia | 2 | 6 | vive Brann | explore `grieta`, 200 oro, +2 rel |
| `lore_oren_future` | historia | 1 | 6 | vive Oren, día ≥ 15 | explore `abismo`, 250 oro, +3 rel |
| `caravan_relics` | caravana | 2 | 3 | día ≥ 10 | discount 0.15 |

Líneas es-AR (BORRADOR):

- Relojera ambulante: "Llegó una relojera ambulante al pueblo: arregla
  lo que el tiempo rompió."
- Cronista de paso: "Un cronista de paso anota lo que todavía no pasó."
- Peregrina del eco: "Una peregrina camina por el bosque siguiendo un eco
  que nadie más oye."
- Autómata errante: "Un autómata viejo anda por las ruinas buscando a
  quien lo dio cuerda."
- Grieta de eco: "Se abrió una grieta de eco: del otro lado espera un
  jefe que ya ganó una vez."
- Ilda: "Las moras de Ilda recuerdan un invierno que todavía no llegó."
  / "Algo vino del futuro a buscarlas: arañas que tejen con hilo de
  mañana. Vencé a tres."
- Velda: "Velda encontró el orden que esperan los autómatas." / "Un
  Guardián de Reloj no respeta el orden: vencelo y Velda podrá leer su
  mecanismo."
- Kael: "El guardián que pelea antes de que llegues dejó un mensaje:
  aguantá." / "Dos elementales de escarcha llegaron antes que vos.
  Aguantá y vencelos."
- Brann: "Un autómata salió de la Grieta caminando hacia la fragua de
  Brann." / "Andá a la Grieta a ver de dónde salió: la fragua vieja
  sigue encendida."
- Oren: "Oren vio el final. No se puede cambiar." / "Hay que llegar
  hasta ahí: andá al Abismo, donde llegan los ecos del futuro."
- Caravana: "Llegó una caravana con restos del pasado magitec."

## 5. Red y guardado

- `WorldEventsState` viaja en `TownState.farmJson` (`wev`): todos ven los
  mismos eventos. Sube `kProtocolVersion` (69 → 70): `wev` (con
  `pg` / `cl`), la acción `rift` y `rift` en la sala. 73 → 74: `dn` en
  `wev` y la acción `wevAct` (§ 3.6).
- Se guarda con el mundo (`TownState.toJson`). Un save viejo sin `wev`
  arranca vacío.
- El catálogo (`assets/data/events/world_events.json`) no viaja: cada par
  lee el mismo archivo (igual que npcs.json); el anfitrión manda.

## 6. UI

- **Aviso:** cuando aparece un evento nuevo en el pueblo recibido, cada
  par agrega al chat su `notice` en su idioma.
- **Mapa de viaje:** en cada lugar con eventos activos, una marca
  compacta `!` dorada (átomo `DsMark`, el mismo aviso de los NPC con
  novedades) con tooltip de los títulos (uno o varios, separados por
  ` · `). Ya no se muestra el texto `EVENTO`/`EVENTOS ×n`.
- **DIARIO → EVENTOS:** subpestaña nueva del DIARIO (J): grilla de los
  eventos activos con el detalle a la derecha (título, categoría, lugar,
  días que quedan, cuerpo y, si corresponde, la grieta, la misión con su
  progreso o el descuento).
- **Actores:** NPCs y portales en el mapa (§ 3.0) con su prompt de E y
  `WorldEventPanel`. El portal ganado se ve apagado para quien lo ganó.
- **Puesto:** cartel verde con el descuento mientras hay visitante o
  caravana.

## 7. Editor → EVENTOS

- Área nueva del Editor, mismo estilo que NPC: grilla de eventos a la
  izquierda con filtro por categoría (subpestañas, nunca secciones
  apiladas) y el detalle a la derecha.
- FICHA incluye el renombre mínimo (renown_town_growth.md § 4.3).
- Botón GENERAL arriba de la grilla: intervalo, mínimo y máximo por
  tirada y probabilidad.
- Detalle con subpestañas FICHA (habilitado, peso, duración, día mínimo,
  biomas, estación, clima del pueblo, habitante, objetivo de historia:
  solo vencer o explorar),
  TEXTOS (una subpestaña por campo: TÍTULO, AVISO, DETALLE; cada una con
  todos los idiomas y un ! si le falta alguno), PARÁMETROS (números de
  § 1) y, en visitantes, viajeros y caravanas, DIÁLOGO con subpestañas
  SALUDO, TEMAS y ACCIONES (§ 3.6: hasta 2, de la lista fija; regalo
  con objeto, cantidad y oro; rumor con lugar; duelo con enemigo y
  escala). Valida idiomas, que el objeto, bioma o enemigo existan, el
  máximo de 2, duelo solo en el campo y comerciar solo en el pueblo.
 Valida también que el enemigo o el bioma del objetivo existan y
  que `season` / `weather` sean una estación o un clima conocidos.
- GUARDAR EVENTOS escribe `assets/data/events/world_events.json` y lo
  aplica. Bloqueado si falta un idioma o el archivo no valida
  (`WorldEventsConfig.validate`).
- Lector único: `WorldEventsLoader` (lib/core/data) al arrancar; archivo
  roto o ausente = `kWorldEventsDefaults` del código, y se loguea.

## 8. Tests

`test/game_engine/world_events_test.dart`: tirada determinista por
semilla y día, intervalo y pesos, vencimiento, escala de la grieta,
historia sin traer cosas, ida y vuelta JSON (catálogo y estado), y
validación de idiomas faltantes.
