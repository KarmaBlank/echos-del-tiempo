# Spec (APROBADO, v0.14.0): Hazañas

Pedido del dueño: incentivar que se usen las mecánicas (sobre todo
**FUSIÓN** y **FORJA**; también inventario, filtro, alijo, combate,
progresión y endgame) con recompensas. Sin texto de ambientación: los
nombres son mecánicos o de tema tiempo / ecos.

Relacionados: loot.md § 16 (forja y fusión), § 21 (desarmar, vender,
reforjar), § 23 (cofres y premios); progression.md; characters.md § 1
(cuenta) y alijo; bestiary.md (precedente de dato de cuenta + pestaña);
build_planner.md; combo_balance.md § 4–5; break_and_enemy_ults.md;
ecos_atlas.md; abyss_bosses.md; design_system.md (`DsToast`, `DsTabBar`);
netcode.md; audio.md.

## 1. Reglas

- Cada hazaña se logra **una vez por cuenta** (no por personaje). La
  recompensa va al **personaje con el que se logró**.
- La recompensa es útil a la misma mecánica: créditos, materiales de
  fusión/forja (Esquirla del Eco, Cristal de Era, Prisma Roto) o
  pociones. Las mecánicas menos usadas (fusión, forja, reforja) pagan
  más.
- Las de contador (tiers I / II / III) cuentan desde que existe el
  sistema (o desde la migración, § 6); cada tier es una hazaña aparte.
- Al lograrla: toast compacto + sonido `ach.unlock` (§ 7).
- Pestaña **HAZAÑAS** con logradas y pendientes y cómo se consigue cada
  una: funciona como guía de las mecánicas.

Abreviaturas de recompensa: `E` Esquirla del Eco, `C` Cristal de Era,
`P` Prisma Roto, `PV` Poción de vida, `PM` Poción de maná. Los
materiales respetan la pila 99: lo que pasa del tope se pierde (igual
que el desarmado) y el toast lo dice.

## 2. Lista (33)

Condición = evento del motor que la dispara (en el host, § 5). "OK" =
`CraftResult` sin motivo de rechazo y aplicado (no vista previa).

### 2.1 Forja (5)

| id | Nombre | Condición | Recompensa |
|---|---|---|---|
| `forge_first` | Primera forja | `UpgradeAction` OK | ₵400 + 2E |
| `forge_plus5` | Forjar a +5 | un arma propia llega a 5 niveles totales de forja tras `UpgradeAction` OK | ₵800 + 1C |
| `forge_cap` | Al tope | un arma Rara o mejor llega a su tope total de forja (loot.md § 9) | ₵1800 + 1P |
| `forge_10` | Forjador II | contador `forgeLevels` ≥ 10 (cada `UpgradeAction` OK suma 1) | ₵1000 + 1C |
| `forge_30` | Forjador III | `forgeLevels` ≥ 30 | ₵2400 + 1P |

(`forge_first` hace de Forjador I.)

### 2.2 Fusión (9)

"Fusión" = cualquier `CraftAction` OK de la fusión libre (loot.md § 16:
trasladar afijo / pasiva / habilidad, quitar afijo, agregar con Cristal,
volver a tirar, subir rareza). Reforjar, desarmar y vender **no** cuentan.

| id | Nombre | Condición | Recompensa |
|---|---|---|---|
| `fuse_first` | Primera fusión | contador `fusions` ≥ 1 | ₵600 + 2E + 1C |
| `fuse_5` | Fusionador II | `fusions` ≥ 5 | ₵1200 + 1C + 1P |
| `fuse_20` | Fusionador III | `fusions` ≥ 20 | ₵3000 + 2P |
| `fuse_skill` | Traer habilidad | trasladar habilidad OK | ₵600 + 1C |
| `fuse_passive` | Traer pasiva | trasladar pasiva OK (Épico → Épico) | ₵1000 + 1P |
| `fuse_affix` | Traer afijo | trasladar afijo OK | ₵400 + 2E |
| `fuse_break_slot` | Reemplazar Quebrar | trasladar habilidad a la **Ranura de Quebrar** (loot.md § 16.3) | ₵600 + 1C |
| `fuse_rarity` | Subir de rareza | subir rareza (Prisma Roto) OK | ₵600 + 1P |
| `fuse_reroll` | Volver a tirar | volver a tirar (Esquirla) OK | ₵200 + 3E |

### 2.3 Reforja, desarme y venta (4)

| id | Nombre | Condición | Recompensa |
|---|---|---|---|
| `reforge_first` | Reforjar | `CraftOp.reforge` OK | ₵1000 + 1C |
| `salvage_10` | Desarmar 10 | contador `salvaged` ≥ 10 (el lote suma cada arma) | ₵400 + 3E |
| `salvage_50` | Desarmar 50 | `salvaged` ≥ 50 | ₵1000 + 1C + 1P |
| `sell_first` | Primera venta | `CraftOp.sell` / `sellAll` OK | ₵100 + 1PV |

### 2.4 Inventario, filtro y alijo (4)

| id | Nombre | Condición | Recompensa |
|---|---|---|---|
| `inv_search` | Usar buscador | el buscador del inventario o del alijo deja ≥ 1 resultado con texto no vacío (evento local del cliente, § 5.2) | 2PV |
| `filter_rule` | Primera regla de filtro | se guarda un filtro con una regla creada o editada por el jugador (no el filtro por defecto) | ₵200 + 2E |
| `stash_store` | Guardar en alijo | mover un objeto del inventario al alijo compartido | ₵200 + 1PM |
| `stash_move_all` | Mover todo | usar **Mover todo** (inventario ↔ alijo) con ≥ 1 objeto movido | ₵200 + 2E |

### 2.5 Combate (4)

| id | Nombre | Condición | Recompensa |
|---|---|---|---|
| `combat_break` | Primer quiebre | un enemigo queda Quebrado por una acción del jugador (combo_balance.md § 5) | 2PV |
| `combat_convergence` | Primera Convergencia | el jugador detona una Convergencia (combo_balance.md § 4; cuenta para quien detona y quien preparó) | ₵200 + 1PV + 1PM |
| `combat_instant_chain` | Encadenar Instante | en un mismo turno propio, usar una habilidad `INSTANTE` y otra acción después | ₵200 + 2PM |
| `combat_cancel_ult` | Cancelar ULT de jefe | quebrar a un jefe mientras carga su ULT y que la ULT se cancele (break_and_enemy_ults.md) | ₵800 + 1C |

### 2.6 Progresión (4)

| id | Nombre | Condición | Recompensa |
|---|---|---|---|
| `equip_legendary` | Equipar legendaria | equipar un arma Legendaria | ₵600 + 1C |
| `tree_milestone` | Primer hito | `chooseMilestone` OK (hito 10 ó 20) | ₵600 + 2PV |
| `build_plan_done` | Completar plan de BUILD | todos los objetivos del plan de build activo quedan cumplidos (build_planner.md) | ₵1200 + 1P |
| `attr_cap` | Pasar tope de atributo | un atributo pasa el punto desde el que rinde menos (`StatsCalculator`) | ₵400 + 2E |

### 2.7 Endgame (3)

| id | Nombre | Condición | Recompensa |
|---|---|---|---|
| `eco_first` | Primer Eco | completar una misión dentro de un Eco | ₵1200 + 1P |
| `atlas_node` | Nodo del Atlas | tomar el primer nodo del Atlas | ₵1000 + 1C |
| `abyss_boss` | Fondo del Abismo | vencer a cualquier Jefe del Abismo | ₵2400 + 1P |

## 3. Totales

Créditos ya ajustados (×2) con la medición de § 4.

| Categoría | Créditos | E | C | P | Pociones |
|---|---|---|---|---|---|
| Forja | 6400 | 2 | 2 | 2 | — |
| Fusión | 8200 | 7 | 4 | 5 | — |
| Reforja / desarme / venta | 2500 | 3 | 2 | 1 | 1 |
| Inventario / filtro / alijo | 600 | 4 | — | — | 3 |
| Combate | 1200 | — | 1 | — | 6 |
| Progresión | 2800 | 2 | 1 | 1 | 2 |
| Endgame | 4600 | — | 1 | 2 | — |
| Total | ₵26 300 | 18 | 11 | 11 | 12 |

Forja + fusión + reforja = ₵17 100 (65%) y casi todos los materiales. (El
borrador decía 13 pociones: la suma real de la lista es 12; combate da 6.)

## 4. Economía

Números de referencia (loot.md § 9, § 16, § 21, § 23; missions.md;
worldgen.md; enemies_catalog):

- Forja nivel `l → l+1`: `round(max(precio,200) × 0.22 × (l+1) × factor)`,
  precio `100·L + 4·L²`. Arma Rara nv 20 (precio 3600): primer nivel
  ₵1188; las 6 mejoras ≈ ₵24 950. Común nv 1: ₵44 el primero.
- Fusión: habilidad ₵200 × rareza; pasiva ₵300 × rareza (Épico ₵600);
  subir rareza 1/2/4 Prismas + ₵100/300/800.
- Reforjar Épico nv 20: ₵1200 + 1C + 1P.
- Una misión (créditos sin escalar por nivel): enemigos ₵5–18 cada uno,
  jefe ₵80–280, cofres 20–50 + 10 × rango, misión opcional `60 + 6 ×
  nivel`, bonus por nota. El borrador estimaba ₵800–1200 por misión.
- Medición (v0.14.0, `tool/hazanas_economia_measure_test.dart`): arma cada
  misión de zona con el motor real (5 semillas) y suma las batallas que
  pide el objetivo (promedio de los grupos del mapa × objetivo + jefe, el
  élite ×3), la mitad de los cofres del mapa, la misión opcional y el bonus
  de rango A. Mediana por misión: m1 ₵755, z2 ₵1293, m2 ₵1570, z4 ₵1777,
  z5 ₵2962, z6 ₵3196, z7 ₵2789, z8 ₵2732, z9 ₵3000, z10 ₵4345. **Mitad de
  juego ≈ ₵2400 por misión** (el doble del estimado).
- Materiales por misión: la opcional da 3E + 1C (+1P desde nivel 30);
  desarmar un Raro da 1C + 1E.

Comparación:
- Con ₵2400 por misión, el total del borrador (₵13 150) eran ~5,5
  misiones, la mitad de lo buscado. Se duplicaron los créditos de cada
  hazaña (materiales y pociones sin cambio): total ₵26 300 ≈ **11
  misiones** a mitad de juego, repartido en toda la vida de la cuenta.
  Equivale a un Raro nv 20 forjado entero: alcanza para *probar* la
  mecánica, no para saltearse la economía.
- Cada primera vez cubre la primera operación de esa mecánica a
  rareza baja (Primera fusión ₵600 ≥ trasladar habilidad en Común/Mágico
  ₵200–240; Primera forja ₵400 ≥ primeros niveles de un Común/Mágico).
- Materiales: 11 Prismas ≈ lo que da la opcional en 11 misiones de
  nivel ≥ 30; 18 Esquirlas ≈ 6 misiones. Sumados son un empujón al
  primer "subir rareza" (1+2+4 = 7 Prismas para llegar a Épico).
- Las pociones son baratas a propósito: van a combate e inventario, que
  ya se usan solos.

## 5. Detección y entrega

### 5.1 En partida (host)

- El host ya aplica `CraftAction`, `UpgradeAction`, movimientos de alijo,
  combate y misiones. `AchievementRules` (Dart puro,
  `game_engine/rules/achievement_rules.dart`) recibe los eventos del
  motor que ya existen (`CraftResult`, `BattleEndedEvent`, eventos de
  quiebre / Convergencia / ULT cancelada, fin de misión, equipar) y el
  estado de hazañas del jugador, y devuelve `AchievementUnlock(id,
  reward)` + los contadores nuevos.
- **Cada jugador gana la suya** en coop: el evento se atribuye al
  `playerId` que hizo la acción (Convergencia: los dos que participan;
  quiebre: el que da el golpe que llena la barra; Eco / jefe / misión:
  todos los presentes).
- La recompensa la entrega **el host en el perfil de sesión** del jugador
  (créditos, materiales, pociones), igual que el loot de misión, y emite
  `AchievementUnlockedEvent(playerId, id)` (JSON `ach`: `{p, id}`). El
  cliente lo muestra (§ 7) y lo guarda en su cuenta al guardar.
- **Idempotente**: el host lleva por jugador el set `done` que el cliente
  mandó al unirse (en el perfil de sesión, clave `ach`); un id ya en
  `done` no se vuelve a pagar aunque el evento se repita o llegue por
  reconexión. El cliente, al guardar en la cuenta, hace unión de sets y
  máximo de contadores (como `AccountBestiaryStore`), así dos sesiones o
  dos personajes no se pisan ni pagan doble al sincronizar.
- Fuera de sesión (lobby, preparación): las mismas reglas corren en local
  con el perfil propio (el lobby ya es local en P2P).

### 5.2 Eventos solo del cliente

`inv_search` y `stash_move_all` / `stash_store` cuando se hacen fuera de
sesión no pasan por el host: el cliente aplica la regla en local. En
sesión, mover al alijo ya es una acción del host y se detecta ahí.
`inv_search` paga solo pociones y es local siempre (aceptable: no hay
nada que ganar haciendo trampa).

### 5.3 Qué viaja (netcode.md)

- Cliente → host al unirse: `ach.done` (ids) y `ach.c` (contadores),
  dentro del perfil de sesión.
- Host → todos: `AchievementUnlockedEvent` (el toast lo ven solo el
  jugador; los demás nada, para no llenar la pantalla).
- Nada nuevo por tick. Protocolo: +1 (sube `kProtocolVersion`).

## 6. Datos

- `account.json`, clave `ach` (opcional; sin clave = vacío):
  `{"v": 1, "done": {"fuse_first": 1732000000, ...}, "c": {"forgeLevels":
  12, "fusions": 3, "salvaged": 27}}` (fecha en segundos). `v` es la
  versión del catálogo de hazañas; ids nuevos se agregan sin migración,
  ids que se quitan se ignoran al leer.
- Catálogo en `game_engine/data/achievements_catalog.dart` (id, nombre,
  categoría, texto de cómo se consigue, condición, recompensa). Números
  editables en el admin de balance.
- Repositorio: `AccountRepository` (misma escritura `.tmp` + `rename`).

### 6.1 Migración de cuentas existentes

Al leer una cuenta sin `ach`, se infieren las que se pueden mirando los
personajes y el alijo:
- `forge_first`, `forge_plus5`, `forge_cap`: algún arma con forja ≥ 1 /
  ≥ 5 / al tope; `forgeLevels` = suma de forja de todas las armas.
- `fuse_skill`: algún arma con habilidad trasladada; `fuse_passive`: algún
  Épico con pasiva no original (si se puede saber; si no, no se infiere).
- `equip_legendary`: alguna Legendaria equipada; `tree_milestone`: algún
  hito elegido; `atlas_node`: algún nodo del Atlas; `eco_first` /
  `abyss_boss`: datos del Atlas / Abismo.
- Contadores de fusión, desarme y venta: no se pueden inferir, arrancan
  en 0.

Decidido (pregunta 1): las inferidas se marcan logradas **con** su
recompensa, en un solo paquete para el personaje elegido de la cuenta (el
primero que se abre). El aviso `Hazañas recuperadas: N (+₵… +…)` sale en
el aviso de carga del título. También se infieren `fuse_break_slot` (arma
con la Ranura de Quebrar reemplazada), `attr_cap` (atributo crudo sobre el
tope blando), `filter_rule` (filtro propio guardado) y `forge_10` /
`forge_30` por el contador `forgeLevels` inferido. La cuenta queda con
`ach` (aunque vacío): la migración corre una sola vez.

## 7. UI (design_system.md)

- **Dónde**: pestaña **HAZAÑAS** del panel de personaje (siguiente a
  BESTIARIO, `CharacterTab.achievements`), porque es de la cuenta como el
  Bestiario y la guía se lee al lado del inventario y la fusión. También
  se abre desde el menú principal (mismo panel, como el Bestiario).
- **Toast** (v0.19.1): tarjeta compacta arriba a la derecha, franja
  dorada; `★ HAZAÑA LOGRADA` (Subtítulo), el nombre en una línea (Cuerpo,
  con "…") y la recompensa en una fila en Detalle: `+₵300` y un ícono
  procedural por material/poción con `xN` (`+ULT` si enseña una). Ancho
  máx. 300 px × factor del texto. Entra deslizando desde la derecha con
  destello y un eco translúcido (360 ms; sin animación con reducir
  movimiento), dura 4 s × DURACIÓN DE LOS AVISOS y se desvanece. Se apilan
  hasta 3 (mismo ancho); los demás esperan lugar. Clic: lo descarta.
  Sonido `ach.unlock` (audio.md: arpegio corto, distinto del de subir de
  nivel). Antes (≤ v0.19.0) era una línea en Cuerpo de hasta 520 px fijos
  que se partía en dos y se veía gigante.
- **Pestaña**: encabezado con `logradas/33` y filtros `Todas · Pendientes
  · Logradas` (`DsTabBar` chico) y categorías como secciones (FORJA,
  FUSIÓN, REFORJA Y DESARME, INVENTARIO, COMBATE, PROGRESIÓN, ENDGAME).
  Orden: pendientes primero dentro de cada sección.
- **Fila de una línea**: marca (✓ dorado lograda / ○ gris pendiente),
  nombre, recompensa a la derecha; las de contador muestran `7/10`.
- **Detalle en tooltip** (hover / mantener apretado): cómo se consigue
  (texto de guía, p. ej. "En FUSIÓN, elegí un arma para sacrificar y
  trasladá una de sus habilidades"), recompensa, fecha si está lograda.
- Accesibilidad: no depende solo del color (marca ✓ / ○ + texto
  `Lograda` / `Pendiente` para lector), filas de 32 px mínimo.

## 8. Tests

- `achievement_rules_test`: cada condición dispara con su evento y no con
  la vista previa; contadores y tiers; idempotencia (mismo evento 2 veces
  = 1 pago); unión de sets / máximo de contadores al guardar.
- Migración: cuenta vieja con armas forjadas → marca las inferidas.
- Coop: dos jugadores, Convergencia → los dos ganan; quiebre → solo el
  que lo hace.

## 9. Implementación (v0.14.0)

- Dart puro: `game_engine/models/achievement.dart` (progreso, recompensa,
  definición), `game_engine/data/achievements_catalog.dart` (las 33) y
  `game_engine/rules/achievement_rules.dart` (detección y pago).
- Host: `SessionEngine.apply` / `tick` corren las reglas después de cada
  acción aceptada y con los eventos del paso (`BattleStepEvent`,
  `EcoCompletedEvent`, `AbyssDefeatedEvent`). Lo que dura más de un paso
  (quién preparó una Convergencia, la INSTANTE del turno) lo lleva
  `AchievementBattleTracker` en el host. El quiebre se atribuye al actor
  del último `ActionEvent` antes del `BreakEvent` roto. En batalla, las
  pociones de la recompensa se suman también al combatiente (la batalla
  las devuelve al perfil al terminar).
- Una vez por cuenta también en la sala: el líder y sus compañeros de
  party (otras ranuras de la misma cuenta) comparten lo logrado; gane quien
  gane, el pago es uno y va a ese personaje.
- El TUTORIAL no cuenta (práctica guionada).
- Las que detecta el cliente (`kClientClaimableAchievements`):
  `inv_search`, `stash_move_all`, `atlas_node` (el Atlas es local de la
  cuenta) y `build_plan_done` (el plan de BUILD no viaja). Van como acción
  `ach` `{id}`; el host acepta solo esas y paga una vez. `stash_store` en
  sesión la detecta el host (`StashPutAction` aceptada); fuera de sesión
  (ALIJO del título), `stash_store` y `stash_move_all` se pagan en local
  sobre la cuenta (`Account.grantAchievements`).
- Datos: `PlayerProfile.achievements` (JSON `ach`) viaja en el `hello` y en
  el estado; en disco vive solo en la cuenta (`Account.replace` / `add`
  unen y lo sacan del personaje). `AccountRepository` migra al cargar.
- Contadores ya pasados de una meta (p. ej. de otra sesión) pagan esa tier
  en el próximo pago de hazañas.
- El toast del cliente no dice lo perdido por la pila 99 (el host lo sabe;
  el evento no lo lleva). Fuera de sesión, el aviso del ALIJO sí lo
  muestra como recompensa entregada.
- Protocolo 24 (`kProtocolVersion`).

## 10. Respuestas del dueño (APROBADO)

1. Cuentas existentes: las hazañas inferibles del perfil / cuenta se
   marcan logradas **con** recompensa (§ 6.1).
2. La recompensa va al **personaje que la logró**.
3. Verificar con la medición los créditos por misión y ajustar el total:
   medido ≈ ₵2400 por misión a mitad de juego; créditos ×2, total ₵26 300
   ≈ 11 misiones (§ 4).
4. `attr_cap` ("pasar el punto de rendimiento decreciente": un atributo
   crudo pasa su tope blando) y `combat_instant_chain` ("INSTANTE + otra
   acción en el mismo turno propio"): como están.

## 11. Preguntas abiertas (resueltas, ver § 10)

1. Migración: ¿las hazañas inferidas de cuentas existentes se pagan o se
   marcan logradas sin recompensa?
2. ¿La recompensa va al personaje que la logró (propuesta) o al alijo
   compartido (créditos no pueden ir al alijo)?
3. ¿Validamos el estimado de ₵800–1200 por misión con el admin de balance
   y ajustamos el total (hoy ≈ 11–16 misiones)?
4. `attr_cap` y `combat_instant_chain`: ¿la definición propuesta ("pasar
   el punto de rendimiento decreciente" / "INSTANTE + otra acción en el
   mismo turno") es la que buscabas?

## v0.17.0: hazañas de ULT (ultimates_v2.md § 3.4)

Seis hazañas nuevas pagan una ULT (`AchievementReward.ult`) y créditos:
Primer Golpe (25 peleas sin daño antes de tu segundo turno), Cadena de
Eras (100 quiebres), Silencio del Tiempo (20 ULT de jefe canceladas),
Custodio (50 escudos a aliados), Forjado en el Ayer (10 armas a +10),
Remate (200 golpes finales). Contadores nuevos: `flawlessWins`,
`breaks`, `bossUltCancels`, `allyShields`, `weaponsPlus10`,
`finishers`. Total: 39 hazañas.