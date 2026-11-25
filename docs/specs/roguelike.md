# Modo Travesía (roguelike) — spec

Estado: **borrador v3** (decisiones del dueño incorporadas). MVP jugable
implementado (§ 12).

Segunda versión del juego, armada con las mismas piezas que el modo actual
(desde ahora **modo Mundo**: overworld libre, misiones, XP). La Travesía es
una partida corta y descartable: elegir personaje → mapa ramificado →
pelea tras pelea → jefe. Es **mucho más compacta** que el Mundo: menos
atributos, menos sistemas, catálogo reducido. La progresión permanente
vive **fuera** de la run.

## 1. Flujo

1. **Pantalla de preparación** (fuera de la run): elegir personaje, gastar
   progreso permanente (§ 8), elegir loadout. No hay hub caminable.
2. **Run**: 3 pisos. Cada piso = un mapa ramificado (§ 2). Se elige nodo,
   se resuelve, se vuelve al mapa.
3. **Fin**: ganar al jefe del piso 3 o morir. Se cobra lo ganado para el
   progreso permanente y la run se borra.

No se camina con el personaje en ningún momento.

## 2. Mapa del piso

- Grafo por capas: **nodo inicial → 3 líneas principales → ~15 capas →
  jefe**. Las líneas se bifurcan y se vuelven a unir, pero siempre se
  reconocen 3 corrientes principales.
- **Semilla compartida** (host e invitados ven el mismo mapa; `mulberry32`).
- Tipos de nodo, **solo estos**: `combate`, `elite`, `jefe`, `tienda`,
  `armeria` (fusión, forja, condensar), `descanso`. No hay eventos, cofres
  ni nodos especiales.
- Reglas de generación (Editor de la Travesía, grupo «Mapa»): cantidad
  mín./máx. de cada tipo por piso, capa mínima de la primera élite, sin dos
  paradas (tienda / armería / descanso) seguidas en un camino (§ 12.2), descanso antes del jefe, al menos una
  tienda y una armería por línea.
- **Zona del piso**: cada piso toma un bioma entre las zonas
  **desbloqueadas** (§ 8.3) según su profundidad. Enemigos y jefe salen
  del pool de esa zona.
- El nivel de los enemigos lo da la capa y el piso (curva en el Editor),
  no el jugador.

## 3. Co-op

- **Camino por votación**: cada jugador marca un nodo, todos ven las marcas
  de todos; con todos los votos gana la mayoría; empate → sorteo con la
  semilla (igual en todos). El host no desempata.
- Combate/élite/jefe: pelean todos juntos.
- Tienda/armería/descanso: cada uno resuelve lo suyo en su pantalla; se
  avanza cuando todos confirman «LISTO».

## 4. Recompensas por pelea

Al ganar, **cada jugador** ve su propia pantalla. Elige 1 de cada fila
(o salta):

- **Objetos** (de la run; antes «Árbol», § 12.2): 3 nodos de **cualquier** parte de las ramas de su clase, sin
  importar si están conectados a lo que ya tomó. Se respetan las
  exclusiones entre keystones. La idea es experimentar.
- **Arma**: 3 armas de los tipos permitidos para su clase.
- **Extra**: 3 opciones entre oro, consumible, **atributo** (+N a uno) o
  **mejora directa** (p. ej. «tus hechizos hacen +10 % de daño», «tu ataque
  básico +15 %»). Catálogo propio de mejoras en el Editor.

Cantidades y rarezas por tipo de nodo (combate / élite / jefe) en el
Editor. El jefe ofrece keystones o ULT de rama.

### 4.1 Algoritmo de ofertas (tendencia)

- **Tendencia** del jugador: peso por rama según lo tomado (más peso a
  notables y keystones) y por etiquetas de sinergia (elemento, estado,
  combo, convergencia, tipo de arma, atributo dominante).
- De cada 3: normalmente **1 sigue la tendencia**, 1 tiene sinergia con lo
  que ya tiene, 1 es libre. Proporciones en el Editor.
- Nunca ofrece algo inútil: nodo que pide un arma que su clase no usa,
  keystone excluida por otra tomada, duplicados.
- **Racha**: tras N ofertas sin nada de su rama principal, la siguiente
  garantiza una (N en el Editor).
- Reutiliza `build_guide_rules.dart` y las etiquetas de `build_wants`.

Objetivo: casi cualquier combinación funciona (combos y convergencias
sobre todo) y cada elección se nota al instante.

## 5. Identidad de clase y atributos

- Cada clase de la Travesía define `runWeaponTypes` (armas que le salen) y
  `runPaths` (ramas que le ofrecen; mezcla libre entre ellas; los puentes
  cuentan si una de sus clases es la propia).
- **Atributos reducidos**: sin Agilidad (no hay velocidad en combate) ni
  velocidad de ataque. Quedan **Vitalidad, Fuerza, Espíritu (magia) y
  Destreza** (ver § 10, pregunta 1).
- Cada clase arranca con sus atributos base fijos; se suben solo con
  recompensas de «atributo». Así un guerrero puede girar a una build
  mágica si le salen hechizos y espíritu.

## 6. Combate

- Mismo `BattleEngine` (dúos, ULT, estados, quiebre, familias, combos).
- **Regla de turnos** inyectable, detrás de flag para probar ambas:
  - `velocidad` (la de hoy);
  - `porBando`: **turno del grupo** → cada jugador actúa en el orden que
    quiera (el primero que tira, tira); cuando todos terminaron →
    **turno de los enemigos**. Es la regla de la Travesía desde v0.1.1
    (ver § 6.1); el Mundo sigue con `velocidad`.
- Inventario dentro de la run: equipar, cambiar, llevar a la armería.

### 6.1 Regla `porBando` (implementada, v0.1.1)

`TurnRule` en `BattleState` (`battle_state.dart`); la elige quien arma la
pelea: `BattleEngine.start(turnRule:)`. La Travesía pasa
`TurnRule.porBando` (`session_engine_run.dart`); el Mundo y el tutorial
usan el valor por defecto `velocidad` y no cambian.

- **Ronda.** Empieza siempre con el turno del grupo (`groupPhase`,
  `round` +1, `acted` vacío). Al empezar, a **todos** los jugadores vivos
  se les corre el inicio de turno de siempre, en orden de lista: Pulso +1,
  fin de Defender, estados (veneno, quemadura... con sus ticks), quiebre,
  telaraña, regeneración, disparadores `onTurnStart`. El que lo pierde
  (aturdido, quebrado, telaraña) queda marcado como que ya actuó. Los
  muertos al empezar la ronda también.
- **Turno del grupo.** Nadie tiene el turno (`currentId = null`,
  `awaitingGroup`). El primer jugador pendiente que manda un comando toma
  el turno y actúa; al terminar queda en `acted`. Un jugador no actúa dos
  veces por ronda. Instante: sigue con el turno hasta su segunda acción.
  Turno extra (Danza de Cuchillas): vuelve a quedar pendiente una vez.
  Dúo: el compañero tiene que estar pendiente y gasta su acción.
  Revivido a mitad del turno del grupo: puede actuar en ese mismo turno.
- **Reloj de turno.** Corre para el grupo entero y se reinicia cada vez
  que alguien actúa. Si se agota, todos los que faltaban se defienden
  solos (Defender automático de siempre).
- **Turno enemigo.** Con todos los jugadores hechos: actúan las
  invocaciones del grupo y después cada enemigo vivo, de a uno, en orden
  de lista (con su inicio de turno: estados, quiebre, trampas, ULT
  enemiga). Después, ronda nueva.
- **Velocidad.** No cuenta: `nextTurn` y los adelantos / retrasos de
  turno (Prisa, retrasos de ULT, ralentizar) no tienen efecto en el
  orden. ULT, estados, quiebre, combos y consumibles funcionan igual
  (todo lo que contaba "por turno" sigue contando por turno de cada uno).
- **Red.** El snapshot suma `tr` / `gp` / `act` / `rd` solo si la regla
  es `porBando` (el Mundo manda lo mismo que en el protocolo 31).
- **Pantalla.** Sin franja de turnos: arriba se lee TURNO DEL GRUPO (con
  quiénes faltan) o TURNO ENEMIGO. El cliente muestra el menú del primer
  pendiente que maneja (el local primero).
- Grupo entero muerto = run perdida. Éter y revivir funcionan igual.

## 7. Datos separados por versión

**Regla dura**: lo que se edita en una versión no cambia la otra. Si se
toca una habilidad o una ULT en la Travesía, el Mundo no se entera, y al
revés.

- Cada modo tiene **su propio catálogo de contenido y su propio parche de
  balance**: `assets/balance/mundo.json` (el actual `balance.json`
  renombrado) y `assets/balance/travesia.json`.
- El catálogo de la Travesía es una **copia reducida e independiente**
  (subconjunto de clases, ramas, armas, habilidades, enemigos, zonas), no
  una referencia al del Mundo. Se crea una vez copiando y desde ahí vive
  solo.
- Lo único compartido es el **código** (motor, reglas, UI) y el arte.
- **Editor**: al abrir, lo primero es elegir **qué versión editar**
  (MUNDO / TRAVESÍA). Todo lo que se ve y guarda después es de esa
  versión. El selector de versión se puede hacer en la última fase.

## 8. Progreso permanente (fuera de la run)

### 8.1 Árbol de afuera y loadout

- **Árbol propio por personaje**, distinto del de la run. Se compra con una
  moneda que se gana en cada run (más si se llega lejos, jefes, hazañas).
- **Loadout** (decisión del dueño): antes de cada run el jugador elige
  **exactamente 2** habilidades de arranque de un pool de **~5 por clase**,
  distintas y que definan la build. Algunas pueden empezar cerradas y
  abrirse con el árbol de afuera, hazañas o jefes, pero cada clase tiene
  **al menos 3 abiertas desde el inicio**. Solo se cambia en la pantalla de
  preparación, entre runs; durante la run las habilidades salen solo de
  las recompensas. Nodos del árbol de afuera potencian habilidades del
  loadout o pares («si arrancás con X, +Y»).
- Reutiliza el dibujo y los organismos del árbol existente (v0.2.0: lista
  simple, ver § 12.1).

### 8.2 Dificultad

Niveles de dificultad por personaje que se desbloquean ganando (modelo de
modificadores acumulativos tomado de `ascension`).

### 8.3 Zonas y enemigos que se desbloquean

- Al inicio solo algunas zonas entran en el sorteo de pisos. Se desbloquean
  más **al terminar runs** (ganar, o llegar a cierto piso; condición en el
  Editor). Poco grindeo.
- **Pool de élites** por zona que crece: al vencer a una élite se suman
  nuevas al pool. Una élite ya vencida puede volver a salir, pero **en una
  versión de nivel más alto**.

### 8.4 Hazañas

Descartado en v0.3.0 (decisión del dueño): la Travesía no tiene hazañas
(§ 12.2).

### 8.5 Guardado

- Archivos propios (`travesia_*.json`); **nunca** pisan el personaje del
  Mundo.
- La run en curso se guarda al entrar a cada nodo; al terminar se borra.
  Implementado en v0.2.0 (§ 12.1).

## 9. Arquitectura

Contrato nuevo `GameMode` (inyectado por el composition root, igual que
`NetSession`):

| Pieza | Mundo | Travesía |
|---|---|---|
| estructura | overworld (`session_engine`) | mapa de piso (`run_engine`, nuevo) |
| progresión | XP + árbol libre | recompensas por nodo |
| turnos | velocidad | velocidad / porBando |
| clases | sin restricción | `runWeaponTypes`, `runPaths` |
| atributos | 5 | 4 (sin Agilidad) |
| persistencia | personaje permanente | run descartable + cuenta |
| catálogo + balance | `mundo.json` | `travesia.json` (independiente) |

- Composition root: `lib/app/flavors/main_roguelike.dart`.
- `release.ps1` puede empaquetar cada flavor como instalador propio.
- Reglas nuevas en `game_engine/` (Dart puro): `run_map_generator.dart`,
  `run_rules.dart`, `reward_offer_rules.dart`, `meta_progress_rules.dart`.

### 9.1 Acoples detectados

- `BattleEngine` ya es independiente del overworld: **reutilizable
  directo**.
- `session_engine.dart` (~3300 líneas) mezcla overworld, misiones, cofres,
  estatuas, tutorial y arranque de batalla. La Travesía no lo extiende:
  `run_engine` nuevo usa el mismo combate, tienda, crafteo e inventario.
  Lo compartido (armado de combatientes, botín, fin de batalla) se extrae
  a reglas comunes.
- `SessionPlayer` mezcla estado de overworld (posición, rastro) con el de
  combate; la Travesía usa solo el de combate/inventario.
- `GameCatalog` hoy es único (`GameCatalog.standard`); pasa a resolverse
  por modo.
- Red: voto, elección de recompensa y LISTO → sube `kProtocolVersion`.

## 10. Preguntas abiertas

1. Atributos: ¿quedan Vitalidad, Fuerza, Espíritu y Destreza, o se funde
   Destreza en Fuerza y quedan solo 3?
2. Nombre de la moneda y del árbol de afuera (desde docs/lore.md).
   Decidido (OK del dueño, 2026-11-22): moneda **Ecos**, árbol
   **Legado del viajero**.

## 11. Fases

1. Spec + barrido de acoples. ✅
2. `GameMode` + catálogo y balance por modo; el Mundo se comporta igual.
3. Extraer reglas compartidas; `run_engine` + mapa + combate/élite/jefe,
   jugable solo.
4. Recompensas + tendencia + identidad de clase + atributos reducidos.
5. Tienda, armería, descanso.
6. Co-op: votación y pantallas individuales.
7. Progreso permanente: árbol de afuera, loadout, zonas, élites, hazañas.
8. Turnos `porBando` ✅ (v0.1.1, regla fija de la Travesía; § 6.1).
9. Editor: selector de versión.

## 12. MVP implementado (rama `feat/travesia-mvp`)

Primer corte jugable para probar la idea cuanto antes. Lo que hay y en qué
se aparta de lo de arriba:

**Arranque.** Flavor propio `lib/app/flavors/main_roguelike.dart` (misma
red P2P que `main_p2p.dart`). El composition root pasa
`GameModeKind.travesia` a `registerSharedDependencies`; de ahí lo toman
`SessionEngine.gameMode` y el `SessionController`. El Mundo
(`main_p2p`, `main_dev`, `main_lan`) usa `GameModeKind.mundo` por
defecto y no cambia. Nadie mira el nombre del flavor.

**Desvío de arquitectura (§ 9).** La run **vive dentro de
`session_engine` por ahora** (`session_engine_run.dart`, `part of`), como
`SessionMode.run` + `GameSession.run` (`RunState`). Así se reusan tal cual
la red autoritativa del host, el combate, la pantalla de batalla, el
inventario, la tienda y el crafteo. El `run_engine` separado y el
contrato `GameMode` completo quedan para la fase 3. Reglas puras nuevas:
`run_map_generator.dart`, `run_rules.dart`, `reward_offer_rules.dart` y
`run_tuning.dart` (todas las perillas juntas, para pasarlas al Editor).

**Flujo.** Título como siempre (se elige un personaje de la cuenta) →
sala de la Travesía (EMPEZAR TRAVESÍA) → mapa → nodo → … → jefe del piso 3
o grupo caído → pantalla de fin (NUEVA TRAVESÍA / VOLVER AL TÍTULO).

**Personaje de la run (v0.1.1).** PERSONAJE abre una vista propia de la
Travesía (`run_character_panel.dart`) con solo lo que se consiguió: los 4
atributos (con lo ganado en la run), arma equipada y sus habilidades,
bolso y consumibles, ULT ganadas (la activa y las que se pueden usar; se
cambia fuera de combate) y los nodos tomados agrupados por rama (nombre +
efecto). Nada del árbol en sí, ni reparto de puntos, ni pestañas del
Mundo. Pestaña INVENTARIO: la de siempre (equipar, mover, usar).
Las armas de la run se equipan **sin nivel ni atributos mínimos**
(`ProgressionRules.ignoreRequirements`, lo inyecta el composition root).
En la sala previa ya se puede abrir PERSONAJE (equipar, elegir ULT).

**Personaje de la run.** (Desde v0.3.0 sin niveles: § 12.2.) Al entrar a la sala y al empezar cada run, cada
jugador recibe un perfil descartable de su clase: arma inicial, atributos
base, árbol vacío, `RunTuning.startGold` de oro. El nivel sigue al de los
enemigos (sin puntos de atributo ni de árbol; solo para poder equipar lo
que sale) con tope 9, antes de los hitos del árbol del Mundo. **Nunca se
guarda**: el flavor registra un `ReadOnlyProfileStore` y el controlador no
escribe perfil, compañeros, alijo, Atlas, bestiario ni tutorial en modo
Travesía. Sin guardado de la run (cerrar la pierde; § 8.5 pendiente).

**Mapa (§ 2).** 3 pisos × 15 capas + jefe. 3 líneas fijas; en cada capa
una línea puede abrirse en dos nodos (25 %) que se vuelven a juntar en la
siguiente, y entre capas hay cruces ocasionales a la línea vecina. La
"entrada" del piso no es un nodo: desde ella se elige uno de los 3 de la
capa 0. Reglas cumplidas: capa 0 de combate, primera élite desde la capa
4, nunca dos descansos seguidos en un camino, la capa 14 es toda de
descanso (antes del jefe), al menos una tienda y una armería por línea.
Zona de cada piso: las zonas jugables ordenadas por `minLevel`, la más
difícil cuyo mínimo no pasa el nivel de entrada del piso (desde v0.2.0,
solo entre las zonas desbloqueadas, § 12.1). Nivel de enemigos: `1 +
levelPerFloor × piso + levelPerLayer × capa` (+1 élite, +2 jefe; valores
en § 12.1).

**Co-op (§ 3).** Votación: cada humano marca un nodo alcanzable, todos ven
las iniciales; con todos los votos gana la mayoría y el empate se sortea
con la semilla de la run, el piso y el nodo de partida. Solo: inmediato.
Tienda / armería / descanso: cada uno da LISTO.

**Peleas.** Mismo inicio de batalla del Mundo con un grupo sintético del
pool de la zona del piso (élite = élite de la misión + uno común; jefe =
grupo del jefe de la zona). Sin XP, sin créditos ni botín del Mundo: oro
fijo por pelea (`goldCombate/Elite/Jefe`) y la recompensa.

**Recompensas (§ 4).** Por jugador: Árbol (3 nodos de cualquier rama de
su clase o puente que la incluya, sin adyacencia, sin repetidos, con
exclusiones), Arma (3 bases de sus `allowedWeaponTypes` hasta 2 niveles
por encima) y Extra (oro, pociones, Éter o +3 a Vitalidad / Fuerza /
Espíritu / Destreza). Tendencia: rama principal = la de más peso en lo
tomado (notable 2, keystone 3); la primera opción la sigue con 75 %, la
segunda sale de una rama vecina en el árbol con 60 %, el resto libre.
Racha: con 2 ofertas seguidas sin la rama principal, la siguiente la
garantiza. **Fila ULT (v0.1.1):** tras un jefe siempre y tras una élite
con `RunTuning.eliteUltChance` (35 %), 3 ULT de rama de las ramas de su
clase, usables con algún tipo de arma de la clase y que todavía no
aprendió; la elegida se aprende y queda activa. La run empieza con la ULT
por defecto de la clase (la del tipo del arma inicial). El nodo elegido entra directo al árbol (`RunRules.grantNode`,
sin puntos ni adyacencia) y vale por los calculadores de siempre.

**Tienda / armería / descanso.** Tienda: la pestaña COMPRAR filtra a los
tipos de arma de la clase; pociones y Éter; vender desde el inventario.
Armería: el banco de forja y fusión de siempre (abre en FORJA). El host
solo deja comprar en la tienda y forjar / fusionar en la armería.
Descanso: cura el 60 % de vida y maná al entrar.

**No implementado todavía.** Catálogo y balance propios de la Travesía
(§ 7: se usa el del Mundo; datos separados por versión), quitar la
Agilidad del modelo (la vista de la run y las recompensas ya no la
muestran ni la dan; el valor base sigue en el perfil), keystones en el
jefe, sinergia por etiquetas de `build_wants`, armas que pide un nodo,
hazañas propias (§ 8.4), dibujo del árbol de afuera con los organismos
del árbol, habilidades de loadout que se abren con hazañas o jefes, y el
selector de versión en el Editor. Mejoras directas, guardado de la run y
progreso entre runs: § 12.1.
Las acciones de puntos del árbol, respec, misiones, pueblo y alijo se
rechazan en la Travesía. Cada partida usa el protocolo propio de Travesía, versión 3 desde v0.2.0 (§ 12.1; versión 2 en v0.1.1:
turnos porBando y fila ULT) (netcode.md § "Un protocolo por juego").

## 12.1 Travesía v0.2.0 (rama `feat/travesia-v0.2`)

Protocolo Travesía **3** (`kTravesiaProtocolVersion`): el snapshot de la
run suma mejoras, loadout, dificultad, élites y crecimiento; la oferta
Extra suma `mejora`; `RunStartAction` lleva zonas / dificultad / élites
del anfitrión y hay una acción nueva `RunPrepAction`. El Mundo no manda
ni lee nada de esto.

Todos los números nuevos están en el grupo de ajustes **«Travesía»**
(`TuningId.travesia`, Editor → Balance → Travesía); el Mundo no lo lee.

**Mejoras directas (§ 4).** `RunBoon` (`run_boons.dart`): hechizos (+%
MAG), ataque (+% ATQ), curas (+% curación), crítico, carga de ULT, élites
(+% ATQ y MAG solo en élites y jefes), Pulso al empezar la pelea, DEF y
robo de vida. La fila Extra suma `boonsInExtra` (2) mejoras al sorteo. Se
apilan y viven en `RunState.boons` (por jugador); en la pelea entran como
modificadores del arma (`ExplorationRules.withMods`, el mismo gancho de
las bendiciones del Mundo) y el Pulso se suma al arrancar. PERSONAJE las
lista en MEJORAS.

**Guardado (§ 8.5).** `RunSave` (`run_save.dart`) en
`travesia_run.json` de la carpeta de la Travesía (`JsonFileRunSaveStore`;
solo lo registra la Travesía). Lo escribe quien corre el motor (solo o el
anfitrión) al entrar a cada nodo y al volver al mapa; se borra al
terminar. En la sala: CONTINUAR TRAVESÍA / ABANDONAR. Al retomar
(`SessionEngine.resumeRun`): una pelea se vuelve a empezar, tienda /
armería / descanso quedan como estaban, una recompensa sin elegir se
pierde (se vuelve al mapa). Co-op: cada jugador guardado se reconoce por
**nombre y clase**; el anfitrión toma el suyo (o el primero de su clase).
Los que faltan **quedan esperando** (`runParked`, solo en el anfitrión) y
siguen en el guardado: si entran con el mismo nombre y clase recuperan su
personaje, vida, mejoras y loadout; si nunca vuelven, la run sigue sin
ellos.

**Progreso entre runs (§ 8), versión compacta.** `TravesiaMeta`
(`travesia_meta.dart`) en `travesia_meta.json` (`JsonFileTravesiaMetaStore`),
por dispositivo; reglas en `meta_progress_rules.dart`. Se ve y se gasta en
la sala y en la pantalla de fin (`RunPrepView`).

- **Moneda (Ecos):** `coinPerFloor` × piso alcanzado + `coinElite` por
  élite + `coinBoss` por jefe + `coinWin` al ganar. Cada dispositivo cobra
  la run una vez (por semilla) al verla terminada.
- **Árbol de afuera (Legado del viajero):** 14 nodos iguales para todas las
  clases, comprados por personaje (`nombre|clase`): oro, poción, Éter,
  +2 a un atributo, Repertorio (abre la 4.ª y la 5.ª habilidad del pool),
  mejora con la que se arranca y sinergias de loadout (dos físicas →
  mejora Ataque; dos mágicas → Hechizos; una física y una de cura →
  Curas). Algunos piden otro antes.
- **Loadout:** pool de 5 por clase sacado de las habilidades de las armas
  tempranas de sus tipos (hasta nivel 9, sin las del arma inicial ni
  provocaciones), 3 abiertas. Se eligen 2; entran a la pelea como
  habilidades extra (`BattlePartyMember.extraSkills`) toda la run,
  aunque se cambie de arma. Cada jugador lo manda con `RunPrepAction`
  (junto con los bonos del árbol) desde su propio progreso.
- **Zonas:** al principio entran las primeras `zonesStart` (3) zonas
  jugables por nivel; cada run que llega al piso `zoneUnlockFloor` (2)
  suma una. La zona de cada piso sigue la regla de § 12 dentro de ese
  subconjunto.
- **Élites:** el pool de una élite = la de la zona + las ya vencidas
  (de cualquier zona). Cada victoria previa contra esa élite le suma
  `eliteRepeatLevel` (2) niveles.
- **Dificultad:** ganar en la más alta abierta abre la siguiente (hasta
  `diffMax`, 5). Cada nivel suma `diffHp` (10 %) de vida y `diffAtk`
  (8 %) de ATQ enemigos, acumulativo. La elige el anfitrión.
- En co-op las zonas, élites y dificultad son las del anfitrión; Ecos,
  Legado y loadout son de cada uno.

**Balance.** Antes: el personaje de la run quedaba en nivel 9 sin puntos
y los enemigos llegaban a ~20; un jugador solo caía casi siempre en el
piso 1. Ahora (todo en el grupo «Travesía»):

| perilla | antes | ahora |
|---|---|---|
| nivel enemigo + por piso (`levelPerFloor`) | 6 | 5 |
| nivel enemigo + por capa (`levelPerLayer`) | 0.35 | 0.3 |
| vida enemiga × (`enemyHp`) | 1.0 | 0.7 |
| ATQ enemigo × (`enemyAtk`) | 1.0 | 0.45 |
| atributos por nivel de enemigos, a los cuatro (`attrPerLevel`) | 0 | 2 |

Jefe del piso 3: nivel 17 (antes 20). El grupo crece con los enemigos
(`RunState.grownTo`): cada nivel nuevo suma `attrPerLevel` a Vitalidad,
Fuerza, Espíritu y Destreza de todos (y a quien entra a mitad de la run).

Simulación sin UI (`test/game_engine/run_balance_sim_test.dart`): un
jugador solo de cada clase, 10 semillas, ULT cuando está llena, poción
con poca vida, cura propia por debajo de la mitad, la habilidad de daño
más fuerte que pueda pagar, equipa el arma más fuerte, primera opción de
cada fila de recompensa, pociones en la tienda. Llegan al jefe del piso 3
(y lo ganan): guerrero 9/10, maga 7/10, paladín 6/10, tirador 7/10. El
test exige al menos 5/10 por clase.

## 12.2 Travesía v0.3.0 (rama `feat/travesia-v0.3`)

Protocolo Travesía **4** (`kTravesiaProtocolVersion`). El snapshot de la
run ya no manda `gl` (crecimiento por nivel) y suma `sk` (habilidades
libres sin equipar) y `su` (mejoras de habilidad); la oferta Extra puede
traer `sk` (habilidad); `runReward` suma `d` (habilidad que se
sacrifica); acciones nuevas `runBuyUlt`, `runSkill` y `runSkillUp`. El
Mundo no manda ni lee nada de esto. Perillas nuevas, todas en el grupo
**«Travesía»** (Editor → Balance → Travesía).

**Sin niveles ni XP (§ 5).** El personaje de la run queda en nivel 1 toda
la travesía: no gana XP, no sube de nivel, no reparte puntos y el nivel
no se muestra (sala, mapa, paradas, PERSONAJE). Los atributos son la base
de la clase al empezar más lo que sumen las recompensas de atributo.
Lo que antes hacía el nivel y cómo se reemplazó:

| antes (v0.2.0) | ahora |
|---|---|
| el nivel seguía al de los enemigos (tope 9) para poder equipar | armas sin requisitos (abajo) |
| cada nivel de enemigos sumaba `attrPerLevel` (2) a los cuatro atributos | se quitó; solo crecen con recompensas (`attrReward`, 5 por recompensa) |
| nivel 1→9 sumaba +2 de vida y +1 de maná por nivel | se compensa con enemigos más blandos (tabla de balance) |
| la fila Arma ofrecía hasta 2 niveles sobre el del personaje | hasta `weaponLevelAhead` (2) sobre el nivel de enemigos de la entrada del piso |
| el pool de arranque usaba el tope de nivel (9) | `MetaProgressRules.loadoutMaxLevel` (9), fijo |

**Armas sin requisitos (§ 12).** Ya se equipaban sin nivel ni atributos
(`ProgressionRules.ignoreRequirements`); ahora tampoco se muestran: las
fichas, la comparación, la tienda y la fusión no dicen «Requiere» ni
«Nv» de base cuando las reglas ignoran requisitos. Se mejoran en la
armería.

**Maná por pelea (§ 6).** Al empezar cada pelea el maná vuelve al máximo;
la vida y la carga de ULT siguen como quedaron.

**Recompensas.** La fila de nodos del árbol se llama **OBJETOS** (objetos
de la run); en PERSONAJE, **OBJETOS DE LA RUN**. MEJORAS queda solo para
las mejoras directas. Cada objeto muestra el nombre una vez (título) y
abajo el efecto, sin repetir el nombre (`passiveEffectsClean`); la rama
va como etiqueta del tooltip o como agrupador discreto. Cada tarjeta
tiene tooltip (objeto, arma con su ficha, ULT, extra).

**ULT como recompensa rara.** La fila ULT sale con
`ultChanceCombate` (5 %), `ultChanceElite` (30 %) o `ultChanceJefe`
(100 %) y trae 1 (50 %), 2 (30 %) o 3 (20 %) opciones. La elegida se
aprende y queda activa; se cambia en PERSONAJE. **Tienda:** cada tienda
vende `shopUlts` (2) ULT de las ramas de la clase (surtido fijo por run,
piso y nodo) a `ultPrice` (260) de oro.

**Habilidades libres.** Tope total `maxSkills` (6) contando ATACAR y
DEFENDER: 4 lugares libres. Las del arma no cuentan (vienen con el arma).
Libres = las de arranque (loadout) + las ganadas en la run. La fila Extra
suma `skillsInExtra` (1) habilidad nueva de las armas de la clase (hasta
el nivel de la fila Arma, sin provocaciones ni las que ya tiene). Al
tomarla con los lugares llenos aparece «TENÉS QUE SACRIFICAR UNA
HABILIDAD» con las libres equipadas (nunca las del arma); CANCELAR deja
la recompensa abierta. `RunState.loadout` = equipadas; `RunState.skills`
= las que tiene y no equipó; en PERSONAJE → HABILIDADES se equipan y se
guardan (fuera de combate, respetando el tope).

**Armería.** Dos cosas: (a) ABRIR ARMERÍA → FORJA mejora el arma con oro
(y con ella sus habilidades, como siempre); (b) MEJORAR HABILIDADES sube
de nivel una habilidad libre: cuesta `skillUpCost` (60) × nivel siguiente,
suma `skillUpPower` (15 %) de poder por nivel, hasta `skillUpMax` (3). En
la pelea entra como `BattlePartyMember.skillScale` (poder × al usarla).
**Arreglo:** la ARMERÍA (y la TIENDA) del mapa no abrían: el controlador
cerraba el panel `armory` en cualquier modo que no fuera el pueblo, y en
la Travesía las paradas son `SessionMode.run`. Ahora queda abierto
mientras el grupo esté parado en una tienda o una armería.

**Mapa.** Menos caminos: `splitChance` 0.25 → 0.12 y `crossChance` 0.18
→ 0.09 (la mitad de bifurcaciones y cruces). Regla nueva: **nunca dos
paradas seguidas** (tienda, armería o descanso) en un camino, ni una
parada justo antes de la capa de descanso; el relleno de «una tienda y
una armería por línea» solo cambia combates sin paradas al lado.

**Sin hazañas, alijo ni opciones del Mundo.** La Travesía no detecta ni
paga hazañas. Se quitaron de la Travesía: HAZAÑAS, ALIJO, BUILD y
BESTIARIO del título; el botón ALIJO y «Guardar en alijo» del
inventario, y la tecla B; en CONFIGURACIÓN, CONFIRMAR AL TIRAR, AVISOS DE
BUILD, CHAT, AVISOS DEL CHAT y FONDO DEL TEXTO EN EL MAPA; la ayuda de
teclas del título ya no habla de moverse ni del chat.

**Teclas.** C abre PERSONAJE e I el INVENTARIO, igual que en el Mundo;
las pantallas de la run muestran PERSONAJE [C] e INVENTARIO [I].

**Tooltips.** Nodos del mapa y leyenda (qué hace cada tipo), tarjetas de
recompensa, atributos, habilidades del arma y libres, mejoras, botones
de la sala y de las paradas.

**Balance.** Sin crecimiento por nivel el grupo quedaba muy corto. Ahora:

| perilla | v0.2.0 | v0.3.0 |
|---|---|---|
| `levelPerFloor` | 5 | 4 |
| `levelPerLayer` | 0.3 | 0.25 |
| `enemyHp` | 0.7 | 0.4 |
| `enemyAtk` | 0.45 | 0.3 |
| `attrPerLevel` | 2 | (quitada) |
| `attrReward` (antes fijo 3) | 3 | 5 |

Simulación (`run_balance_sim_test.dart`, ahora con armas sin requisitos
y exigiendo ganarle al jefe del piso 3): guerrero 9/10, maga 9/10, paladín 5/10, tirador 6/10 (el test exige al menos 5/10 por clase).

## 12.3 Pasada de balance con datos (rama `fix/paradoja-balance`)

**Arnés.** `test/game_engine/run_sim_harness.dart` simula runs solas con
semilla y una IA simple (ULT llena, poción < 35 %, cura < 50 %, la
habilidad de daño más fuerte; descansa con < 50 % de vida; primera opción
de cada fila de recompensa; equipa el arma más fuerte) y mide piso
alcanzado, muertes por piso y por tipo de pelea, victorias contra cada
jefe, oro ganado, peleas y segundos de combate. Informe completo bajo
pedido: `PARADOJA_SIM_SEEDS=120 PARADOJA_SIM_DIFFS=0,5 flutter test
test/game_engine/run_balance_report_test.dart` (`PARADOJA_SIM_TUNE=clave=valor,...`
prueba valores del grupo «Travesía» sin tocar código; `grupo.clave=valor`
para otros grupos). El guard de CI es `run_balance_sim_test.dart`
(30 semillas × 4 clases × dificultad 0 y 5, ~12 s). Con el quiebre del
jugador activo (desde v0.48.5 los enemigos solo llenan la barra).

**Objetivos** (los exige el guard):

- Dificultad 0: mediana de victorias por clase entre 65 % y 85 %; la
  mediana de las runs llega al piso 3.
- Dificultad 5: mediana entre 25 % y 45 %; cada clase gana menos que en
  dificultad 0.
- Cada clase a ±15 puntos de la mediana, en ambas dificultades.
- Jefes: chequeo, no muro — al menos 80 % (dif. 0) y 60 % (dif. 5) de
  victorias entre las runs que llegan a cada jefe.

**Hallazgos.**

- El tope por golpe (combo_balance.md § 3.2, regla compartida con el
  Mundo) hace que en peleas comunes casi todo golpe pegue el tope: el %
  de daño de clase no mueve nada (se probó +400 %). Lo que decide es el
  daño recibido.
- El paladín moría en el piso 1 por veneno de los limos (su
  `statusWeakness` suma pilas; la DEF no lo frena). La maga y el tirador,
  por poca vida / DEF.
- La dificultad casi no afectaba al guerrero: `diffHp` no cambia cuántos
  golpes hacen falta (el tope es fracción de la vida), solo `diffAtk`.
- Los jefes ganaban ~100 %: hay un descanso antes; las muertes se
  amontonaban en el piso 1 (curva cargada al principio).
- Sin pozos de recompensa sin salida: el oro crece con el piso en todas
  las clases (columna «oro»).

**Perillas nuevas** (grupo «Travesía», editables en Editor → Balance; el
Mundo no las lee, así que su combate no cambia): `bossHp`, `bossAtk`
(× del jefe) y el kit de clase `classDmg<Clase>` (% daño),
`classDef<Clase>` (DEF) y `classResist<Clase>` (pilas de estados
resistidas).

| perilla | antes | después |
|---|---|---|
| `levelPerFloor` | 4 | 6 |
| `enemyAtk` | 0.3 | 0.36 |
| `diffAtk` | 0.08 | 0.12 |
| `bossHp` / `bossAtk` | — | 1.6 / 1.3 |
| `classDef` maga / paladín / tirador | — | 10 / −8 / 13 |
| `classResist` maga / paladín | — | 1 / 1 |

**Antes / después** (120 semillas por fila; antes: 60):

| clase | dif. | victorias antes | después | piso medio antes | después | muertes f1/f2/f3 antes | después | jefes f1/f2/f3 después |
|---|---|---|---|---|---|---|---|---|
| guerrero | 0 | 83 % | 78 % | 2.85 | 2.82 | 0/9/1 | 3/16/7 | 100/100/100 |
| maga | 0 | 80 % | 76 % | 2.77 | 2.73 | 4/6/2 | 8/17/4 | 100/100/99 |
| paladín | 0 | 47 % | 84 % | 2.17 | 2.76 | 19/12/1 | 12/5/2 | 99/100/100 |
| tirador | 0 | 50 % | 66 % | 2.30 | 2.48 | 15/12/3 | 22/18/1 | 100/100/100 |
| guerrero | 5 | 77 % | 37 % | 2.78 | 2.23 | 0/13/1 | 21/51/4 | 100/100/100 |
| maga | 5 | 43 % | 27 % | 2.18 | 2.12 | 20/9/5 | 38/30/20 | 99/98/82 |
| paladín | 5 | 30 % | 47 % | 1.77 | 2.12 | 33/8/1 | 43/20/1 | 84/100/100 |
| tirador | 5 | 28 % | 33 % | 1.75 | 1.98 | 32/11/0 | 46/30/4 | 94/100/100 |

Medianas: dif. 0 de 65 % (rango 47–83, guerrero +18, paladín −18) a 77 %
(66–84); dif. 5 de 36 % (28–77, guerrero +41) a 35 % (27–47).

**Pendiente.** Los jefes de los pisos 2 y 3 siguen casi seguros (el
descanso previo cura); un × por piso para el jefe es la próxima perilla
si se quiere que sean un chequeo real. La IA no usa tienda más allá de
pociones ni elige recompensas: los números son para una jugada promedio.
