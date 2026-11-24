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
- **Sin clima ni estaciones:** el clima y las estaciones son un sistema
  propio (rama aparte). Este catálogo no tiene eventos de clima,
  anomalía ni estación, y no toca tablas de pesca, cultivos ni la
  forja/minería. Gancho: `WorldEventContext.extraCondition` (una
  condición extra por evento, `null` = sin condición) queda para que un
  evento futuro dependa del clima o la estación; hoy nadie lo usa.
- `WorldEventDef` (una entrada del catálogo):
  - `id`, `category`, `enabled`, `weight` (≥ 0; 0 = nunca sale),
    `duration` (días, ≥ 1).
  - Condiciones: `minDay` (día mínimo del mundo), `biomes` (lista de
    biomas donde puede aparecer; vacía = cualquiera abierto; las
    categorías del pueblo siempre van al pueblo), `resident` (habitante
    que tiene que vivir en el pueblo; vacío = ninguno).
  - Textos (`LocalizedText`, todos los idiomas obligatorios, igual que el
    editor NPC): `title`, `notice` (la línea del chat al empezar),
    `body` (el detalle de la sección EVENTOS).
  - `params` (números): `hpMult`, `atkMult`, `levelBonus`, `rewardMult`
    (grieta), `gold`, `rep` (historia), `discount` (visitante y caravana). Los que faltan valen su
    neutro (1 para multiplicadores, 0 el resto).
  - Solo `lore`: `objective` (`LoreObjective`) y `target` / `n`.
- `WorldEventsConfig`: `interval` (días entre tiradas, ≥ 1, def. 5),
  `minPerRoll` / `maxPerRoll` (def. 1 / 2), `chance` (0–1, def. 1: si
  la tirada pasa) y la lista de `events`.
- `ActiveWorldEvent`: `def` (id), `biome` (dónde aplica; `pueblo` para
  las del pueblo), `start`, `end` (días del mundo; termina al llegar a
  `end`). Uid estable `<def>@<start>`.
- `WorldEventsState` (en `TownState`, JSON `wev`): `seed` (semilla del
  mundo para los eventos, la pone el anfitrión la primera vez y queda
  guardada), `last` (día de la última tirada), `active` y `seen` (ids de
  historias que ya salieron: cada historia sale una sola vez por mundo).

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

### 3.1 Visitante (pueblo)
Un viajero llega al pueblo unos días. Usa el comerciante de siempre:
`discount` (expuesto en `WorldEventRules.townDiscount`) va a bajar los precios del puesto mientras está (fase 2: conectarlo al comerciante, y actor en el
pueblo con su charla del archivo NPC).

### 3.2 Habitante en el campo
Alguien aparece en un bioma unos días (peregrinos, un autómata errante).
Fase 2: actor en el exterior con su charla.

### 3.3 Grieta de eco
Una grieta en el exterior del bioma lleva a una versión más fuerte del
jefe del bioma: el jefe de la **última zona** de ese exterior
(`BiomeDef.zones.last`, `ZoneDef.bossId`), con su misión de zona.
Escala: `WorldEventRules.rift` devuelve `EchoRiftBoss` (jefe, zona,
misión, `hpMult`, `atkMult`, `levelBonus`, `rewardMult`);
`applyRiftBattle` multiplica vida y ataque de los jefes de una batalla
recién creada (como `EcoRules.applyBattle`). Dura pocos días (def. 3) y
la recompensa se multiplica por `rewardMult`. Fase 2: el portal en el
exterior y la entrada a la misión (hoy están las reglas y la escala).

### 3.4 Historia de un habitante
Atada al lore de un habitante que vive en el pueblo: desbloquea una
misión de historia nueva para él (`LoreQuest`). **Nunca es de traer
cosas.** Objetivos permitidos (`LoreObjective`): `defeat` (vencer a un
eco concreto), `explore` (llegar o explorar un lugar), `escort`
(escoltar), `talk` (hablar con alguien), `survive` (resistir o defender),
`puzzle` (resolver algo en una mazmorra). Se basa en docs/lore.md: ecos
que llegan del futuro o del pasado, futuro que no se puede cambiar,
pasado magitec. Fase 2: el seguimiento del objetivo en el DIARIO y la
entrega.

### 3.5 Caravana
Mercaderes con restos del pasado magitec en el pueblo; `discount` como
el visitante.

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
| `lore_ilda_roots` | historia | 2 | 6 | vive Ilda | defeat `eco_raiz` ×1, 120 oro, +2 rel |
| `lore_velda_order` | historia | 2 | 6 | vive Velda | puzzle zona 3, 150 oro, +2 rel |
| `lore_kael_guardian` | historia | 2 | 6 | vive Kael | survive 5 oleadas, 180 oro, +2 rel |
| `lore_brann_forge` | historia | 2 | 6 | vive Brann | escort `autómata` a la fragua, 200 oro, +2 rel |
| `lore_oren_future` | historia | 1 | 6 | vive Oren, día ≥ 15 | explore `abismo` + talk, 250 oro, +3 rel |
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
- Ilda: "Las moras de Ilda recuerdan un invierno que todavía no llegó.
  Algo vino del futuro a buscarlas." (vencer al Eco de Raíz)
- Velda: "Velda encontró el orden que esperan los autómatas. Falta
  probarlo abajo." (resolver el mecanismo en las Ruinas Cronales)
- Kael: "El guardián que pelea antes de que llegues dejó un mensaje:
  aguantá." (resistir 5 oleadas)
- Brann: "Un autómata salió de la Grieta caminando hacia la fragua de
  Brann. Hay que acompañarlo." (escoltar)
- Oren: "Oren vio el final. No se puede cambiar, pero hay que llegar
  hasta ahí." (llegar al fondo del Abismo y hablar con Oren)
- Caravana: "Llegó una caravana con restos del pasado magitec."

## 5. Red y guardado

- `WorldEventsState` viaja en `TownState.farmJson` (`wev`): todos ven los
  mismos eventos. Sube `kProtocolVersion` (68 → 69).
- Se guarda con el mundo (`TownState.toJson`). Un save viejo sin `wev`
  arranca vacío.
- El catálogo (`assets/data/events/world_events.json`) no viaja: cada par
  lee el mismo archivo (igual que npcs.json); el anfitrión manda.

## 6. UI

- **Aviso:** cuando aparece un evento nuevo en el pueblo recibido, cada
  par agrega al chat su `notice` en su idioma.
- **Mapa de viaje:** en cada lugar con eventos activos, una insignia
  `EVENTO` (o `EVENTOS ×n`) con tooltip de los títulos.
- **DIARIO → EVENTOS:** subpestaña nueva del DIARIO (J): grilla de los
  eventos activos con el detalle a la derecha (título, categoría, lugar,
  días que quedan, cuerpo y, si corresponde, la grieta o la misión).

## 7. Editor → EVENTOS

- Área nueva del Editor, mismo estilo que NPC: grilla de eventos a la
  izquierda con filtro por categoría (subpestañas, nunca secciones
  apiladas) y el detalle a la derecha.
- Botón GENERAL arriba de la grilla: intervalo, mínimo y máximo por
  tirada y probabilidad.
- Detalle con subpestañas FICHA (habilitado, peso, duración, día mínimo,
  biomas, habitante, objetivo de historia), TEXTOS (título, aviso,
  cuerpo en todos los idiomas) y PARÁMETROS (números de § 1).
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
