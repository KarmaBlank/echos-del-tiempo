# Spec: Jefes del Abismo (v0.8.0)

Implementa docs/specs/endgame.md § 3 (aprobada) con las reglas co-op de
§ 7. Regla del dueño: **sin lore** (no hay textos de historia ni epítetos
nuevos): solo nombres y textos funcionales de las mecánicas.

Código: `lib/game_engine/data/abyss_catalog.dart` (jefes, fases,
movimientos, drops de Fragmentos), `lib/game_engine/models/abyss.dart`
(modelos), `lib/game_engine/rules/abyss_rules.dart` (drops, abrir,
consumir, recompensas), `lib/game_engine/rules/battle_engine_abyss.dart`
(`part` del motor: mecánicas en batalla), `rules/session_engine.dart`
(flujo en la sala). UI: `lib/features/endgame/presentation/abyss_view.dart`
(pestaña ABISMO del Portal del Eco), chips en `battle_hud.dart`.

## 1. Fragmentos

Cuatro materiales nuevos (`CraftMaterial`, pila 99 como los demás, en la
sección MATERIALES del inventario y del alijo, filtro de loot por
`Material`):

| Material | Token | Abre |
|---|---|---|
| Fragmento del Reloj | `mat:fragReloj` | Gólem Reloj del Abismo (1) |
| Fragmento del Eco | `mat:fragEco` | Hechicera del Eco del Abismo (2) |
| Fragmento de la Corona | `mat:fragCorona` | Espectro Coronado del Abismo (3) |
| Fragmento de las Eras | `mat:fragEras` | Devorador de Eras del Abismo (4) |

### 1.1 Drops (`kFragmentDrop`, editable: `BalanceKind.fragmentDrop`)

Solo **dentro de Ecos de tier ≥ 10**, **por jugador** (cada uno tira lo
suyo), en cada tirada de loot del Eco (batalla, élite, jefe, cofre y fin
del Eco). Azar propio (`SessionEngine.abyssRandom`): no mueve ninguna
tirada de antes.

- Chance base por fuente: batalla 2%, cofre 4%, élite 8%, jefe 20%, fin
  del Eco 30%.
- × tier: `1 + 0.15 × (tier − 10)` (T10 ×1 … T16 ×1.9).
- × rareza y mods del Eco: `1 + 0.10 × (rareza − Común) + 0.05 × mods`
  (Legendario con 5 mods: ×1.65).
- Jefe del Eco que coincide con un jefe del Abismo (Gólem Reloj = jefe 3,
  Hechicera = 6, Espectro = 8, Devorador = 10): en el jefe y en el fin del
  Eco la chance va ×1.5, y ese Fragmento pesa ×4 al elegir cuál cae.
- Tope 95%. Qué Fragmento: peso 1 cada uno (×4 el que coincide).

### 1.2 Abrir (pestaña ABISMO del Portal)

- Jefes 1–4: **5 Fragmentos** de su tipo (`fragmentCost`, editable).
- Jefe secreto (5): **1 Fragmento de cada tipo** y haber vencido a los 4
  Jefes del Abismo.
- Validación del host (`AbyssRules.cannotOpen`): portal activado, en el
  pueblo, sin votación, el costo en el inventario de quien abre.
- Votación y preparación como un Eco (`missionId = 'abismo'`,
  `GameSession.abyss` y `abyssBy`). Rechazar / cancelar no consume nada.
- Se **consume al empezar** (como los Ecos); si quien lo abrió se fue o ya
  no tiene el costo, se cancela (`Faltan los Fragmentos`).

### 1.3 Vencidos (cuenta y personaje)

- La cuenta guarda los Jefes del Abismo vencidos en el Atlas como
  "primeras veces" `x1`…`x5` (1 punto de Atlas cada uno, 2 el secreto:
  6 puntos más; máximo total del Atlas 50, que sigue sin alcanzar para los 51 de costo).
- Como el host valida con el perfil, el personaje lleva la misma marca
  (`PlayerProfile.abyssKills`, JSON `aby`). Al entrar a jugar se le suman
  las de la cuenta (`AbyssRules.withAccount`): así un personaje nuevo de
  una cuenta que ya los venció puede abrir el secreto.

## 2. Las peleas

- **Sin mazmorra**: al empezar, el grupo entra directo a la batalla contra
  el jefe (la sala arma una misión de 1 piso con el jefe solo, para el
  rango y el resultado de siempre).
- Nivel de monstruo 85–90 (stats del catálogo ya a ese nivel,
  `kEnemyBaseLevel`). Escalado 1–4 de siempre (vida y quiebre
  `0.55 + 0.45 × jugadores`, ULT con el grupo).
- Mecánica `BossMechanicKind.abyss`: la definición vive en
  `kAbyssBosses` (`AbyssBossDef`): fases con umbral de vida, ATQ, una
  **rotación de movimientos** (cada acción usa `moves[acciones % n]`),
  aspecto elemental, invocaciones e inmunidades.
- **Fases**: el golpe que cruza el umbral deja la vida justo en él (como
  el Devorador). Al entrar: pierde sus estados, la barra de quiebre vuelve
  a 0 (si no está quebrado), ATQ × el de la fase, acciones a 0, se rompe
  el sello e invoca lo que pida la fase. `BossMechanicEvent(phaseShift,
  value: fase)` y cartel `FASE n`.
- **Aviso** (telégrafo): al terminar cada acción, si la próxima es un
  movimiento especial, `BossMechanicEvent(abyssTelegraph, value: índice)`
  y el chip `PRÓXIMO: <movimiento>`. La ULT tiene su chip de carga como
  siempre.
- **Furia** (enrage): al empezar su turno n.º `enrageTurns` (40; 45 el
  secreto) pega × `enragePower` (2.0) y desde ahí cada acción es un golpe a
  todos (`BossMechanicEvent(enrage)`). El chip muestra `FURIA en N`.

### 2.1 Movimientos (`AbyssMoveKind`)

| Movimiento | Qué hace | Contrarrestar |
|---|---|---|
| `attack` | ataque normal (Golpe Brutal cada 4) | — |
| `strike` | golpe a todos: ATQ × poder, elemento (o el aspecto), estado y retraso | **Defender**: ½ daño y no reacciona (el golpe llega físico) |
| `rewind` | se cura `value` × el daño recibido desde su acción anterior (solo `soloValue`) | quebrarlo antes (quebrado no rebobina) o guardar el daño para después |
| `timeWarp` | retrasa al grupo `IV × value` (solo `soloValue`) y su próximo turno llega 30% antes | — |
| `mirror` | cada eco vivo (o el jefe, sin ecos) copia **la última habilidad** que usó el grupo: golpe del elemento de esa habilidad a un jugador | matar a los ecos; variar los elementos (un Mojado que recibe tu Electro se electrocuta) |
| `seal` | **Sello**: recibe × (1 − `value`) del daño hasta que lo rompa una **reacción** del tipo pedido (en solo, cualquier reacción) o un **quiebre**; dura `turns` turnos suyos | detonar la reacción pedida (co-op: uno prepara, otro detona) |
| `summon` | completa sus invocaciones | — |
| `devour` | **come los buffs** del grupo (efectos positivos y escudos): +`value` de ATQ por cada uno (tope +`cap`) | no acumular buffs antes del aviso |

Valores con grupo / en solo en cada movimiento (`AbyssMoveDef`).

### 2.2 Jefes

Familias (bestiary.md): Gólem constructo, Hechicera y Devorador
temporales, Espectro espectro, Eco Primordial aberración del Vacío.
Invocación nueva: **Eco del Abismo** (`ecoAbismo`, temporal, actúa, recibe
×0.5 como los ecos de la Hechicera).

| # | Id | Nombre | Nivel | Vida | ATQ | VEL | Quiebre |
|---|---|---|---|---|---|---|---|
| 1 | `golemAbismo` | Gólem Reloj del Abismo | 85 | 6400 | 98 | 8 | 2240 |
| 2 | `hechiceraAbismo` | Hechicera del Eco del Abismo | 86 | 6600 | 100 | 10 | 2310 |
| 3 | `espectroAbismo` | Espectro Coronado del Abismo | 88 | 7200 | 104 | 11 | 2520 |
| 4 | `devoradorAbismo` | Devorador de Eras del Abismo | 90 | 8400 | 110 | 10 | 2940 |
| 5 | `ecoPrimordial` | Eco Primordial (secreto) | 90 | 10000 | 112 | 11 | 3500 |

**1. Gólem Reloj del Abismo** — manipulación del timeline y electro.
- F1 (100%): `attack · attack · timeWarp (0.5 / solo 0.3) · attack ·
  rewind (100% / solo 50%)`; golpes de hielo (Congelación 1).
- F2 «Sobrecarga» (60%, ATQ ×1.15): aspecto Electro (sus golpes dejan
  Cargado); `strike Diluvio (Agua, ×0.6, Mojado) · attack · strike
  Descarga (Electro, ×0.9) · timeWarp · rewind`. Diluvio + Descarga =
  Electrocución sobre el grupo salvo que se defiendan.
- F3 «Cuenta Final» (25%, ATQ ×1.3): `strike Descarga · timeWarp ·
  rewind · attack`.

**2. Hechicera del Eco del Abismo** — ecos que copian y sellos.
- F1: 2 Ecos del Abismo (1 en solo); `attack · mirror (×0.8) · attack ·
  seal (Electrocución, ×0.25 / solo ×0.4, 3 turnos)`.
- F2 «Coro Roto» (55%, ATQ ×1.15): vuelve a llenar los ecos; `mirror ·
  seal (Derretir) · strike Nova (Hielo, ×0.8, Congelación 2) · summon`.
- Sin ecos no hay copia del eco: copia la propia Hechicera.

**3. Espectro Coronado del Abismo** — séquito, fases inmunes y curas que
dañan.
- Siempre: las **curas del grupo lo dañan** (60% de lo curado, también
  pociones; `healHurts`).
- F1: 2 Siervos (1 en solo), inmune a estados mientras vivan; `attack ·
  strike Lamento (Hielo, ×0.8, Congelación 1) · attack · summon`.
- F2 «Corona Inmune» (60%, ATQ ×1.1): invoca el séquito y es **inmune al
  daño mientras viva algún siervo** (solo las curas lo dañan);
  `strike Llanto (Agua, ×0.7, Mojado) · attack · summon · attack`.
- F3 «Último Lamento» (25%, ATQ ×1.2): inmune a estados con siervos;
  `strike Lamento (×1.0) · attack · attack · summon`.

**4. Devorador de Eras del Abismo** — 3 fases, come buffs, ciclo
elemental.
- F1: `attack · attack · devour (+5% ATQ por buff, tope +50%) · strike
  Colapso Temporal (×0.7, retrasa 0.4)`; golpes de fuego (Quemadura 2).
- F2 «Hambre» (66%, ATQ ×1.15): `devour · strike Colapso (×0.8) ·
  attack · attack`.
- F3 «Ciclo de las Eras» (33%, ATQ ×1.3): **aspecto en ciclo** Fuego →
  Agua → Electro → Hielo (cambia al empezar cada turno suyo; sus golpes
  llevan ese elemento y su estado; recibe ×0.5 del mismo elemento);
  `strike Era (×0.9) · devour · attack · strike Era`.

**5. Eco Primordial** (secreto) — todos los elementos y todo lo anterior.
- Siempre: aspecto en ciclo Fuego → Agua → Electro → Hielo → Veneno, y
  las curas del grupo lo dañan (40%).
- F1: `strike Era (×0.8) · seal (Explosión tóxica) · attack · timeWarp`.
- F2 «Reflejo» (66%, ATQ ×1.15): 2 Ecos del Abismo (1 en solo);
  `mirror · devour · strike Era · rewind (60% / solo 40%)`.
- F3 «Primordial» (33%, ATQ ×1.25): inmune al daño con ecos vivos; `strike Era (×1.0) · summon · devour · seal
  (Electrocución) · timeWarp`.

ULT (nombres): Engranaje del Fin, Coro de Ecos, Lamento Eterno, Fin de las
Eras y **Todas las Eras** (secreto: a todos ×1.6, Mojado, borra buffs).

### 2.3 Solo

Todo es resoluble por un jugador: vida y quiebre bajan con el escalado,
1 invocación, valores `solo` de rebobinar / retrasar / sellar, el sello se
rompe con cualquier reacción o con un quiebre, Defender anula las
reacciones de los golpes a todos.

## 3. Recompensas (cada jugador tira lo suyo)

- El loot de jefe y de fin de misión de siempre, a nivel 85–90.
- **Legendario exclusivo** (`UniqueDef.exclusive`: nunca sale del pool
  normal): la primera vez que el personaje vence a ese jefe, seguro; las
  siguientes 25% (secreto 20%), uno al azar entre los suyos.
- **Esencia del Abismo** (`mat:esencia`): 1–2 por jugador (secreto 3).
- Puntos de Atlas en la cuenta (§ 1.3) y entrada en el bestiario.

| Jefe | Legendario | Base | Pasiva única |
|---|---|---|---|
| Gólem | Manecilla del Abismo | Báculo del Origen | **Tiempo Prestado**: al detonar una reacción, tu próximo turno llega 25–45% antes |
| Hechicera | Espejo sin Fondo | Varita del Vacío | **Preparación Compartida**: si otro detona lo que preparaste, +8–16 ULT a todo el grupo |
| Espectro | Corona Invertida | Maza y Escudo de la Eternidad | **Luz Invertida**: al curar a un aliado, escudo del 40–80% de lo curado (2 turnos) |
| Devorador | Fauce de las Eras | Espada de Cronos | **Hambre Eterna**: cuando el grupo quiebra a un enemigo, +20–40% ATQ (3 turnos) |
| Secreto | Prisma Primordial | Arco Eterno | **Todas las Reacciones**: +40–80% al golpe que detona una reacción |
| Secreto | Filo Primordial | Hacha del Cataclismo | **Eco del Golpe**: al detonar una reacción, 15–35% de un turno extra |

Sin texto de ambientación (`flavor` vacío).

### 3.1 Esencia del Abismo (crafteo)

`CraftOp.essence` (forja, MEJORAR): sobre un **legendario**, vuelve a
tirar los valores de sus **mods fijos** dentro de su rango con ventaja:
dos tiradas por mod, se queda con la mayor y **nunca baja** del valor
actual. Cuesta 1 Esencia. No se puede si no es legendario o si todos los
fijos ya están al máximo.

## 4. Interfaz

- Portal del Eco: pestaña **ABISMO** (tarjetas `ActionCard`, navegación
  con teclado de `menu_focus`): los Fragmentos que tenés, una tarjeta por
  jefe (silueta y "???" hasta la primera victoria de la cuenta; el
  secreto, oculto hasta vencer a los 4), requisitos, costo y ABRIR con
  confirmación (`Se consumen 5 Fragmentos del Reloj`).
- Batalla: chips del jefe (fase, `PRÓXIMO`, `FURIA en N`, sello, aspecto,
  inmune, buffs comidos), cartel `FASE n`, avisos en el registro.
- Resultado: sección **EXCLUSIVO DEL ABISMO** con el legendario destacado
  y la línea del Atlas (`Jefe del Abismo vencido: +1 punto de Atlas`).
- Arenas: la del jefe base (Ruinas, Laberinto, Cementerio, Corazón) con
  la **variante del Abismo** (vacío violeta, grietas, luz fría) y una
  propia para el secreto (`ArenaTheme.primordial`).
- Música: `bossAbyss` (jefes 1–4) y `bossSecret` (secreto), DSL del
  tracker.
- Tipografía `RetroType`, sin negrita, respeta los ajustes de
  accesibilidad (tamaño de texto, reducir movimiento).

## 5. Red

Host autoritativo. Protocolo **9**: acciones `abyss` (`n`), `devAbyss`
(`k`); evento `abyssDone` (`ids`, `n`); sesión `abyss`, `abyssBy`;
perfil `aby`; combatiente `abT` `abE` `abS` `abSN` `abA` `abK` `abF`
`abC`; fases de `BossMechanicEvent` `abyssTelegraph`, `enrage`,
`sealCast`, `sealBroken`, `sealFade`, `rewind`, `timeWarp`, `mirror`,
`devour`, `aspect`; materiales `mat:frag*` y `mat:esencia`.

## 6. Desarrollo

Solo `main_dev` (`FeatureFlags.devTools`): `DevAbyssAction('frag')` da 5
de cada Fragmento y 3 Esencias (y activa el portal);
`DevAbyssAction('kills')` marca los 4 jefes como vencidos. La pestaña
ABISMO muestra `DEV: +FRAGMENTOS` y `DEV: 4 VENCIDOS`.
