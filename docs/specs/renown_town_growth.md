# Spec: Renombre, crecimiento del pueblo y eventos de amistad

El mundo reacciona a lo que hace la party: jefes vencidos, zonas
abiertas, grietas cerradas, historias cumplidas y el pueblo que crece.
Todo es del **mundo** (vive en `TownState`, lo calcula el anfitrión, se
guarda con el mundo y viaja en el snapshot) y todo se edita en el Editor
(área **RENOMBRE**). Todos los textos de este spec son **BORRADOR**: el
dueño los reescribe en el editor.

Fases:

- **Fase A (implementada):** renombre y niveles, condición `renown` en la
  charla, fichas de hazañas (`{lastBoss}`, `{townName}`, …), frases de
  reconocimiento, renombre mínimo en eventos del mundo, nivel del pueblo
  con barra de progreso, página RENOMBRE del Editor.
- **Fase B (implementada en parte):** el **torneo** propuesto por un
  habitante amigo (programar, inscribirse, tres peleas, premio). El
  **festival** queda especificado (§ 6.3) para más adelante.
- **Fase C (pendiente):** cambios visuales por nivel del pueblo
  (estandartes, más faroles, plaza) y lo que desbloquea cada nivel (§ 5.2).

## 1. Hitos (`RenownState`, JSON `rn` en `TownState.farmJson`)

Lo que cuenta para el renombre. El anfitrión lo anota en el momento:

| hito | cuándo | campo |
|---|---|---|
| zona vencida | misión de zona ganada (jefe de la zona) | `z` (índices de zona) |
| jefe de bioma | la zona vencida es la última de su bioma | derivado de `z` |
| grieta cerrada | grieta de eco ganada (world_events.md § 3.3) | `r` (cantidad) |
| historia cumplida | historia de evento cumplida (§ 3.4) | `l` (cantidad) |
| torneo ganado | final del torneo ganada (§ 6.2) | `t` (cantidad) |
| habitantes | los que viven en el pueblo | derivado del pueblo |
| edificios | edificios del pueblo (`builds`) | derivado del pueblo |

Además guarda la última hazaña para las fichas: `lb` (nombre del último
jefe vencido) y `lp` (id del último bioma cuyo jefe cayó). Un save viejo
sin `rn` arranca en cero (los jefes ya vencidos antes no cuentan hasta
la próxima victoria: no hay forma fiable de reconstruirlos del mundo).

## 2. Renombre

`RenownRules.score(town, cfg)` = suma de cada fuente × su peso
(`RenownConfig.sources`, editables):

| fuente | id | peso por defecto |
|---|---|---|
| zona vencida | `zone` | 10 |
| jefe de bioma (extra) | `biomeBoss` | 25 |
| grieta cerrada | `rift` | 8 |
| historia cumplida | `lore` | 12 |
| torneo ganado | `tourney` | 15 |
| habitante | `resident` | 6 |
| edificio | `building` | 1 |

### 2.1 Niveles de renombre (`tiers`, BORRADOR)

| desde | es-AR | en | zh-Hans |
|---|---|---|---|
| 0 | Desconocidos | Unknown | 无名之辈 |
| 30 | Conocidos en la zona | Known around here | 小有名气 |
| 90 | Se habla de ustedes | People talk about you | 声名渐起 |
| 180 | Héroes del presente | Heroes of the present | 当世英雄 |
| 320 | Leyenda de los ecos | Legend of the echoes | 回声传奇 |

El primero tiene que empezar en 0; los umbrales suben estrictamente.
`RenownRules.tierOf(score)` es el índice del último umbral alcanzado.

## 3. Fichas de hazañas en los textos

`LocalizedText` reemplaza fichas `{nombre}` al mostrarse (`text`,
`resolve`). La capa de juego publica los valores en
`LocalizedText.tokens` (igual que el idioma activo) cada vez que llega el
pueblo. Una ficha desconocida queda tal cual. Fichas:

- `{lastBoss}`: último jefe vencido (o "un jefe" si no hay).
- `{lastBiome}`: bioma de ese jefe.
- `{townName}`: nombre del mundo (`GameSession.worldName`).
- `{renownTier}`: nombre del nivel de renombre.
- `{townTier}`: nombre del nivel del pueblo.

Sirven en cualquier texto: charla de habitantes, eventos del mundo y
frases de reconocimiento. El editor las muestra como ayuda en cada campo.

## 4. Quién te reconoce

### 4.1 Condición `renown` en la charla

`TalkTopic.renown` (JSON `renown`, se omite en 0): renombre mínimo para
que el tema se abra (npc_editor.md § 1). Se suma a `talks`, `orders`,
`rep`, `where` y `time`. `NpcTalkRules.progress` trae el renombre del
mundo. El editor NPC la muestra con las otras condiciones y PROBAR deja
elegir el renombre.

### 4.2 Frases de reconocimiento (`lines`)

`RecognitionLine`: `id`, `who`, `minRenown`, `text` (todos los idiomas).
`who`:

- `visitor`, `wanderer`, `caravan`: lo dice el actor del evento del
  mundo de esa categoría al abrir su panel (una línea extra arriba).
- id de un habitante (`ilda`, …): se suma a sus saludos al abrir.

Elegible = `minRenown <= renombre`. Entre las elegibles se elige la de
mayor `minRenown` (la más "nueva"); empates, la primera del archivo. Así
cada nivel nuevo cambia lo que dicen.

Catálogo inicial (BORRADOR, es-AR; en y zh-Hans en el archivo):

- visitante 30: "¡Ah! ¿Vos sos quien derrotó a {lastBoss}? Se habla de eso
  en otras partes."
- visitante 180: "En {townName} vive gente que pelea con ecos. Vine a
  verlo con mis ojos."
- viajero 30: "Escuché de {lastBoss}. El eco de esa pelea llegó hasta acá."
- caravana 90: "Nos dijeron que en {townName} se compra bien. Y que es
  seguro."
- dos por habitante (Ilda, Velda, Kael, Brann, Oren) en 30 y 180.

### 4.3 Eventos con renombre mínimo

`WorldEventDef.minRenown` (JSON `minRenown`, se omite en 0): el evento
solo entra en la tirada si el renombre del mundo llega
(`WorldEventContext.renown`). El editor EVENTOS lo muestra en FICHA.

## 5. Nivel del pueblo

### 5.1 Cálculo

Puntos del pueblo = habitantes × `town.resident` (def. 4) + edificios ×
`town.building` (def. 1) + renombre × `town.renown` (def. 0.1).
Niveles (`townTiers`, BORRADOR): caserío 0, aldea 15, pueblo 35, ciudad
70. `RenownRules.townTier` devuelve el nivel, el siguiente y la fracción
de avance.

En la FUENTE RÚNICA: "Pueblo: Aldea · Renombre: Conocidos en la zona
(42)" y una barra (`DsPercent`) hacia el próximo nivel del pueblo.

### 5.2 Fase C (pendiente)

- Cada nivel suma detalles: aldea = estandartes en la entrada, pueblo =
  más faroles en el camino, ciudad = plaza empedrada alrededor de la
  fuente. Solo arte nuevo en el manifest, sin cambiar el mapa jugable.
- Desbloqueos sugeridos: aldea = festival, pueblo = torneo (hoy el
  torneo pide renombre), ciudad = visitantes raros con más peso.

## 6. Eventos del pueblo propuestos por amistad

`TownEventDef` (lista `events` del archivo): `id`, `kind`
(`tournament` | `festival`), `proposer` (habitante), `minRep` (amistad
con él), `minRenown`, `delay` (días entre aceptar y el día del evento),
`cooldown` (días antes de poder proponerlo otra vez), textos (`title`,
`propose`, `accept`, `signup`), y para el torneo `rounds` (3 grupos de
ids de enemigo: los luchadores), `levelBonus` y `prize` (oro por
jugador).

### 6.1 Proponer y programar (fase B, implementado)

- Disponible si el habitante vive en el pueblo, su amistad ≥ `minRep`,
  el renombre ≥ `minRenown`, no está programado y pasó el `cooldown`
  desde la última vez.
- En su charla aparece una opción con `title`: muestra `propose` y
  ACEPTAR. Aceptar manda `ScheduleTownEventAction(id)` (`tev`); el
  anfitrión valida y guarda `scheduled[id] = día + delay`. Aviso en el
  chat con `accept`.
- El día llegó (`día >= scheduled`): el evento está **en curso** ese día.
  Si el día pasa sin jugarlo, se pierde (sale de `scheduled`, cuenta el
  `cooldown`).

### 6.2 Torneo (fase B, implementado)

- En curso, hablar con el habitante muestra INSCRIBIRSE (`signup`).
  Manda `ProposeTourneyAction(id)` (`tourney`): abre la votación de
  misión `tourney` igual que una grieta (convocatoria
  `GatherKind.tourney`; en coop entran todos los que se suman).
- Arena: un piso del tipo de la zona más alta vencida del mundo (zona 1
  si ninguna), nivel `maxLevel` de esa zona + `levelBonus`.
- Llave de 3 peleas: tres luchadores (`rounds`) en el campo; solo el
  primero está despierto. Ganarle despierta al siguiente; el tercero es
  el campeón (jefe): ganarle termina la misión.
- Al ganar: `prize` de oro para cada humano, `t++` en el renombre,
  el evento sale de `scheduled` y anota `held[id] = día`. Perder = se
  termina igual (sin premio) y se anota `held`.

### 6.3 Festival (especificado, pendiente)

- Día de fiesta: banderines y faroles extra en el pueblo (solo ese día),
  un puesto temporal (grilla del AGROPECUARIO con su propio stock) y dos
  actividades:
  - **Concurso de pesca:** el pez más pesado del día en el lago del
    pueblo; el anfitrión guarda el mejor por jugador.
  - **Concurso de cosecha:** la cosecha de mayor calidad entregada a la
    fuente ese día.
- Premios por puesto (oro y un objeto de decoración), `festival` suma al
  renombre (peso propio). Coop: cada jugador compite por su cuenta.

## 7. Red y guardado

- `RenownState` viaja en `TownState.farmJson` (`rn`: `z`, `r`, `l`, `t`,
  `lb`, `lp`, `sc` programados, `hd` celebrados). Session: `tourney`
  (id del torneo en curso). Acciones `tev` y `tourney`. Sube
  `kProtocolVersion` (70 → 71).
- El catálogo (`assets/data/renown/renown.json`) no viaja: cada par lee
  el mismo archivo; el anfitrión manda. Lector único `RenownLoader`
  (lib/core/data); archivo roto o ausente = `kRenownDefaults` y se loguea.

## 8. Editor → RENOMBRE

Mismo estilo que EVENTOS: barra de GUARDAR RENOMBRE / RECARGAR con el
primer problema a la vista, y subpestañas:

- **FUENTES:** el peso de cada fuente y los pesos del nivel del pueblo.
- **NIVELES:** grilla de niveles de renombre y del pueblo (filtro por
  tipo) con el detalle a la derecha: umbral y nombre en todos los idiomas.
- **FRASES:** grilla de frases (filtro por quién) con el detalle: quién,
  renombre mínimo y el texto en todos los idiomas (con las fichas de § 3
  como ayuda).
- **EVENTOS DEL PUEBLO:** grilla de torneos / festivales con el detalle:
  habitante, amistad, renombre, demora, enfriamiento, luchadores, premio
  y textos.

Validación (`RenownConfig.validate`): falta de idioma en cualquier texto,
niveles que no empiezan en 0 o no suben, pesos negativos, ids repetidos,
`who` desconocido, habitante o enemigo desconocido, torneo sin 3 rondas.

## 9. Tests

`test/game_engine/renown_test.dart`: renombre desde hitos, umbrales de
nivel, fichas, temas y eventos con renombre, nivel del pueblo, ida y
vuelta JSON (catálogo y estado), validación del editor.
`test/game_engine/tourney_session_test.dart`: proponer, programar,
inscribirse, tres peleas, premio.
