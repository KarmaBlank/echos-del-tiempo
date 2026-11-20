# Spec: Ecos, Atlas del Tiempo y Maestría (v0.4.0)

Primera entrega del endgame (docs/specs/endgame.md § 1, § 2, § 4 primer
punto y las reglas co-op de § 7 que les tocan). Lo que **no** entra en
esta versión está en § 9 con sus ganchos.

Código: `lib/game_engine/models/eco.dart` (modelo), `models/atlas.dart`,
`data/eco_catalog.dart` (modificadores, nodos del Atlas),
`rules/eco_rules.dart` (generación, drops, dungeon, crafteo),
`rules/atlas_rules.dart`, `rules/progression_rules.dart` (maestría),
`rules/session_engine.dart` (flujo en la sala). UI:
`lib/features/endgame/presentation/` (Portal del Eco y Atlas).

## 1. Desbloqueo: el Portal del Eco

- Tile nuevo `Tile.portal` (`'P'`, sólido) en el pueblo: x 3–5, y 2 (a
  la izquierda del mostrador). Frente a él: `[E] Portal del Eco`
  (`WorldRules.nearPortal`: `y < 4.6 tiles`, `2.5 < x < 6.5 tiles`).
- Se **activa** por personaje al vencer al **Devorador de Eras** (misión
  de la zona 10 completada): `PlayerProfile.ecosUnlocked` (JSON `eco`,
  `true`). Ese mismo final da a cada jugador que lo desbloquea **un Eco de
  tier 1 garantizado** (para arrancar el ciclo) y el aviso
  `X activó el Portal del Eco`.
- Sin activar, el portal abre igual el panel con el texto
  "Vencé al Devorador de Eras (Corazón del Tiempo) para activar el
  portal". Los Ecos pueden caer antes (desde nivel 45): se guardan.
- Perfiles v0.3 que ya vencieron al Devorador: no hay registro, tienen
  que vencerlo de nuevo (zona 10 sigue abierta) — la v0.3 no guardaba
  ese dato.

## 2. El objeto Eco

`EcoItem` (inmutable) vive en el inventario como cualquier objeto: 1
casilla, se puede mover, dar, tirar, guardar en el alijo y lo evalúa el
filtro de loot. No se equipa ni se vende/desarma. En el alijo van primero a la
pestaña ECOS (con el Ancla y los materiales del Abismo), también desde la
partida con `ALIJO [B]` (characters.md § 3 y § 3.2).

| Campo | JSON | Valores |
|---|---|---|
| uid | `u` | `eco<n>` (mismo contador `seq` del perfil; no choca con ningún token de la grilla) |
| tier | `t` | 1–16 |
| zona | `z` | 1–10: el **tipo de zona** = generador, tema, enemigos y música de esa zona |
| jefe | `b` | 1–10: el jefe de esa zona (con su grupo y su mecánica) |
| rareza | `r` | las 5 rarezas de siempre |
| mods | `m` | `[[id, valor], ...]` |
| pisos | `f` | 1–3 |
| semilla | `s` | int: el mapa del Eco (mismo Eco → misma mazmorra) |

- **Nivel de monstruos** del Eco: `48 + 2 × tier` (T1 = 50 … T16 = 80).
  Todos los pisos, élites y jefe usan ese nivel; el jugador sigue con
  tope 50. Los enemigos escalan con `ZoneRules.scaleBattle` (vida
  `1 + 0.15 (L−1)`, ATQ `1 + 0.08 (L−1)`): T16 ≈ +54% vida y +49% ATQ
  sobre nivel 50, antes de los modificadores. El escalado por grupo
  (1–4 jugadores) de la batalla se aplica igual que en todo el juego.
- **Nombre**: `Eco de <zona> · T<tier>` (raros o mejores: nombre
  generado `"<A> <B>"` como las armas, p. ej. "Eco Hueco del Olvido").
- **Mods por rareza** (al generarse = el mínimo; Cristal de Era agrega
  hasta el máximo): Común 0, Mágico 1–2, Raro 2–3, Épico 3–4,
  Legendario 4–5. Nunca dos mods iguales.

### 2.1 Modificadores (`kEcoMods`)

Cada uno sube la dificultad y suma **+% cantidad** y **+% rareza** de
loot (fijo por mod; el valor tirado solo cambia la dificultad).

| id | Texto | Valor | Cant. | Rareza |
|---|---|---|---|---|
| `vida` | Enemigos con +X% de vida | 20–40 | 8 | 4 |
| `furia` | Enemigos con +X% de ATQ | 10–25 | 8 | 4 |
| `prisa` | Enemigos X% más rápidos | 10–20 | 6 | 6 |
| `coraza` | Barra de quiebre +X% | 25–50 | 5 | 5 |
| `brasas` | Los enemigos aplican X stack(s) de Quemadura (30%) | 1–2 | 6 | 6 |
| `herida` | Jugadores con −X% de curación recibida | 20–40 | 5 | 8 |
| `sequia` | Sin regeneración fuera de batalla | — | 4 | 6 |
| `horda` | +X grupos por piso | 1–2 | 10 | 2 |
| `tirano` | El jefe tiene +X% de vida | 25–50 | 4 | 8 |

Aplicación: `vida/furia/prisa/coraza/tirano` multiplican al crear la
batalla (después de `scaleBattle`); `brasas` da a los enemigos sin estado
propio `Quemadura ×X al 30%`; `herida` resta a `healReceived` de los
jugadores; `sequia` apaga la regeneración del campo; `horda` sube los
grupos por piso.

### 2.2 Bonus de loot dentro del Eco

- `Q = Σ cantidad de los mods × (1 + Potencia) + Atlas + 10% × (jugadores − 1)`.
- `R = Σ rareza de los mods × (1 + Potencia) + Atlas`.
- Cada tirada de loot dentro del Eco (batalla, élite, jefe, cofre, fin)
  se repite `⌊1 + Q⌋` veces y una más con probabilidad `frac(1 + Q)`.
- La rareza suma `R / 100` al bonus de rareza (`extraBonus`; un jefe ya
  da 2.0).
- El tooltip muestra la suma: `Botín: +34% cantidad · +22% rareza`.

## 3. Drops de Ecos y del Ancla Temporal

Azar propio (`SessionEngine.ecoRandom`), así las tiradas de siempre no
cambian de orden.

- **Ecos** (por jugador, enemigos de nivel ≥ 45, dentro o fuera de un
  Eco): batalla 2%, cofre 4%, élite 10%, jefe 30%; × (1 + Rutas del Eco).
  - Fuera de un Eco: tier 1. Dentro de un Eco de tier t: 70% t, 20%
    t+1, 10% t−1 (1–16).
  - Rareza: la de las armas (`LootRules.rollRarity`, nivel 50, por fuente).
  - Zona: peso 1 cada una; las del Atlas (§ 5) ×3. Jefe: al azar (10).
    Pisos: 1–3 al azar. Semilla: al azar.
- **Fin de un Eco completado**: cada jugador recibe 1 Eco (65% mismo
  tier, 35% tier+1; Resonancia: +15% de subir y 30% de un 2.º Eco).
- **Ancla Temporal** (material nuevo, `mat:ancla`, pila 99, alijo 999):
  solo dentro de Ecos: batalla 3%, cofre 6%, élite 12%, jefe 40%, fin del
  Eco 25%; × (1 + Anclas del Atlas).
- Filtro de loot: `Objeto Eco` (nuevo `LootKind.eco`), `Rareza` y
  `Mods` sirven también para Ecos, y `Tier <op> n` (nuevo). El filtro por
  defecto suma la regla `Mostrar # Ecos` (turquesa, sonido `gema`,
  ícono `cuadrado celeste`) primera.

## 4. Abrir, completar y fallar

1. En el pueblo, en el Portal (panel ECOS), el jugador elige un Eco suyo
   y **ABRIR**: `ProposeEcoAction(uid)`. El host valida: modo lobby, sin
   votación, portal activado, el Eco existe en su inventario.
2. Votación y preparación como cualquier misión (`MissionVote` con
   `missionId = 'eco'`; el Eco en `GameSession.eco` y su dueño en
   `GameSession.ecoOwner`). Rechazar / cancelar no consume nada.
3. Al empezar se **consume** el Eco del inventario del dueño. Si el dueño
   ya no está o ya no lo tiene, se cancela (`El Eco ya no está`). Los
   modificadores gratis del Atlas del host se agregan ahí (no al objeto).
4. Mazmorra: `MapGenerator.zone` con un `ZoneDef` sintético
   (`EcoRules.zoneDef`) del generador de la zona del Eco, `pisos` del
   Eco y semilla del Eco. Grupos: los del último piso de la misión de esa
   zona; jefe: el grupo del jefe de la misión de su zona. Por piso
   `4 + horda` grupos; cofres de siempre + Cofres Olvidados. Sin
   objetivos extra (fragmentos / sellos).
5. **Completar** = vencer al jefe. Rango por tiempo como las zonas
   (`sTime = 300 × pisos`). Evento `EcoCompletedEvent(jugadores, tier,
   zona, jefe)`: cada jugador presente recibe sus puntos de Atlas en su
   cuenta (§ 5.1) y el loot de fin (§ 3).
6. **Fallar** (todo el grupo cae o el grupo vuelve al pueblo): el Eco ya
   se consumió; no da puntos ni loot de fin.

### 4.1 Crafteo de Ecos (panel ECOS, en el pueblo)

`EcoCraftAction(uid, op)` — solo lobby / preparación, sobre un Eco del
inventario.

| Op | Material | Efecto |
|---|---|---|
| `reroll` | 1 Esquirla del Eco | vuelve a tirar todos los mods (misma cantidad) |
| `addMod` | 1 Cristal de Era | agrega un mod si no llegó al máximo de su rareza |
| `rarity` | Prisma Roto ×1 / ×2 / ×3 (a Mágico / Raro / Épico) | sube la rareza (hasta Épico) y agrega mods hasta el mínimo nuevo |
| `tier` | 1 Ancla Temporal | tier +1 (hasta 16) |

## 5. Atlas del Tiempo

Compartido por **todos los personajes de la cuenta** (`account.json`,
clave `atlas`, aditiva: una cuenta v0.3 carga con el Atlas vacío).
`AtlasProgress { nodes, done }`: nodos tomados y "primeras veces".

### 5.1 Puntos

Primera vez **de la cuenta** que se completa un Eco de:
- cada **tier** `t`: 1 punto (T1–T8) o 2 (T9–T16) → clave `t<n>`;
- cada **tipo de zona**: 1 → `z<n>`;
- cada **jefe**: 1 → `b<n>`.

Un Eco nuevo puede dar hasta 4 puntos. Máximo total 44 (8 + 16 + 10 +
10); los nodos cuestan 51 → no se puede tomar todo. **v0.8**: los Jefes
del Abismo suman sus primeras veces `x1`…`x5` (1 punto cada uno, 2 el
secreto; abyss_bosses.md § 1.3): máximo 50, todavía menos que 51. Se aplica en el
cliente de cada jugador al recibir `EcoCompletedEvent` (si su id está
en la lista), sobre su propia cuenta.

### 5.2 Reglas

- Nodo de inicio `origen` gratis. Un nodo se toma si hay puntos libres
  (`ganados − gastados ≥ costo`) y está unido a uno tomado.
- **Reinicio gratis** siempre (regla del dueño, como el árbol de
  pasivas). Solo se edita en el pueblo (lobby).
- En grupo se usa el **Atlas del anfitrión** (`GameSession.atlas`, lo
  manda el host al crear la sala y cada vez que lo cambia). Cada jugador
  igual gana puntos en el suyo. Solo: el propio.

### 5.3 Nodos (`kAtlasNodes`, costo normal 2, notable 3)

| id | Rama | Nombre | Costo | Efecto |
|---|---|---|---|---|
| `origen` | — | Origen del Atlas | 0 | inicio |
| `rutas` | Cartografía | Rutas del Eco | 2 | +25% chance de que caigan Ecos |
| `verde` | Cartografía | Tierras Verdes | 2 | Ecos de Pradera y Bosque ×3 |
| `piedra` | Cartografía | Piedra Antigua | 2 | Ruinas y Fortaleza ×3 |
| `helada` | Cartografía | Hielo y Fuego | 2 | Cavernas y Grieta Ígnea ×3 |
| `tiempo` | Cartografía | Tiempo Roto | 2 | Laberinto y Corazón ×3 |
| `vacio` | Cartografía | Orillas del Vacío | 2 | Cementerio y Abismo ×3 |
| `resonancia` | Cartografía | Resonancia (notable) | 3 | fin del Eco: +30% de un 2.º Eco y +15% de subir de tier |
| `brillo` | Tesoro | Brillo | 2 | +8% rareza en Ecos |
| `abundancia` | Tesoro | Abundancia | 2 | +10% cantidad en Ecos |
| `cofres` | Tesoro | Cofres Olvidados | 2 | +1 cofre por piso |
| `destello` | Tesoro | Destello | 2 | +8% rareza en Ecos |
| `cornucopia` | Tesoro | Cornucopia | 2 | +10% cantidad en Ecos |
| `fortuna` | Tesoro | Fortuna de Eras (notable) | 3 | +50% chance de Legendario en Ecos |
| `trofeo` | Caza | Trofeo | 2 | el jefe del Eco suelta 1 arma extra |
| `codicia` | Caza | Élites Codiciosas | 2 | los élites del Eco sueltan 1 arma extra |
| `anclas` | Caza | Anclas | 2 | +50% chance de Ancla Temporal |
| `corona` | Caza | Corona del Jefe | 2 | +10% chance del legendario propio del jefe |
| `ecojefe` | Caza | Eco del Jefe (notable) | 3 | el jefe del Eco suelta 1 Eco extra |
| `gratis` | Dominio | Modificador Gratis | 2 | +1 mod al azar al abrir (con su bonus) |
| `potencia` | Dominio | Potencia | 2 | los mods dan +20% de bonus de loot |
| `templado` | Dominio | Templado | 2 | la dificultad de los mods ×0.75 |
| `gratis2` | Dominio | Otro Modificador (notable) | 3 | +1 mod más al abrir |
| `maestro` | Dominio | Maestro del Eco (notable) | 3 | +20% XP en Ecos |
| `grieta` | — | Grieta del Tiempo | — | **Próximamente** (bloqueado) |
| `grietamayor` | — | Grieta Mayor | — | **Próximamente** (bloqueado) |

Posiciones en una grilla 9 × 7 (centro `origen`; Cartografía arriba,
Tesoro a la derecha, Caza abajo, Dominio a la izquierda): ver
`kAtlasNodes`.

## 6. Maestría

- Con nivel 50 la XP llena la **Maestría** (perfil `ms`, 0–20, por
  personaje). XP para pasar de la maestría m a m+1:
  `12 000 + 3 000 × m` (12 000 … 69 000; 810 000 en total, ~100+ Ecos).
- Cada nivel de maestría da **1 punto de árbol** (`treeLevel = nivel +
  maestría`; **2 desde la v0.8**, passive_tree_v6.md § 7). No da puntos de atributo ni pausa la sala.
- Evento `MasteryUpEvent(id, m)` y aviso `X alcanzó Maestría m`.
- Con 20 la XP deja de acumularse (`xp = 0`).
- HUD: con nivel 50 la barra de XP muestra `MAESTRÍA m · x/y`
  (`MAESTRÍA MÁX`); el panel del personaje la muestra junto al nivel.
- Perfiles v0.3 de nivel 50 con XP sobrante: se convierte en maestría
  con la próxima XP que ganen.

## 7. Co-op (endgame.md § 7)

- Escalado 1–4: el de siempre (vida, quiebre y ULT enemigas por grupo).
- +10% cantidad de loot por jugador extra dentro del Eco (§ 2.2).
- Atlas del host para modificadores y efectos; puntos para cada uno.
- Solo: todo es jugable; el escalado por grupo baja vida y quiebre.
- Protocolo: `kProtocolVersion` 4 (acciones `eco`, `ecoCraft`,
  `devEco`; eventos `ecoDone`, `mastery`; sesión `eco`, `ecoBy`,
  `atlas`; drop `eco`).

## 7.1 Sonido y música

- Dentro de un Eco suena la música de la zona de su tipo (`MissionRun.zone`)
  y la de jefe / jefe final de siempre.
- Jingle `zoneUnlocked` al ver el resultado de un Eco que dio puntos de
  Atlas; `levelUp` (jingle y SFX) al subir de Maestría.

## 8. Desarrollo (solo `main_dev`)

`FeatureFlags.devTools` (solo en `main_dev`) → el motor acepta
`DevGrantEcoAction(tier)` (activa el portal y da un Eco Raro del tier
pedido) y el panel ECOS muestra `DEV: +ECO T1 / T8 / T16`. En
`main_p2p` / `main_lan` el motor la rechaza.

## 9. Ganchos para lo que sigue (no implementado)

- **Grietas** (Atlas): nodos `grieta`/`grietamayor` bloqueados; el
  evento iría como un `MissionItemKind` nuevo dentro del Eco.
- **Jefes del Abismo / Fragmentos** (endgame.md § 3): **implementado en
  v0.8.0** (abyss_bosses.md): desde T10, con su propio azar
  (`SessionEngine.abyssRandom`) en vez de `ecoRandom`, en `AbyssRules`.
- **Ascensión / Prueba del Tiempo** (§ 4, § 8): la Prueba puede usar el
  mismo camino `ProposeEcoAction` con un `EcoItem` especial.
- **Temporadas** (§ 6): el Atlas es por cuenta; una temporada usaría un
  `AtlasProgress` propio.
