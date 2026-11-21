# Modo Travesía (roguelike) — spec

Estado: **borrador v2** (decisiones del dueño incorporadas). MVP jugable
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
  descansos seguidos en una línea, descanso antes del jefe, al menos una
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

- **Árbol**: 3 nodos de **cualquier** parte de las ramas de su clase, sin
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
    **turno de los enemigos**. La línea de tiempo queda como vista de
    orden y ventanas de combo.
- Inventario dentro de la run: equipar, cambiar, llevar a la armería.
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
- **Loadout**: antes de empezar se eligen habilidades iniciales (casilleros
  limitados). Nodos del árbol de afuera potencian habilidades del loadout
  o combinaciones («si llevás X, +Y»).
- Reutiliza el dibujo y los organismos del árbol existente.

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

Hazañas propias de la Travesía que dan moneda o nodos del árbol de afuera,
y avanzan junto con las zonas desbloqueadas.

### 8.5 Guardado

- Archivos propios (`travesia_*.json`); **nunca** pisan el personaje del
  Mundo.
- La run en curso se guarda al entrar a cada nodo; al terminar se borra.

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

## 11. Fases

1. Spec + barrido de acoples. ✅
2. `GameMode` + catálogo y balance por modo; el Mundo se comporta igual.
3. Extraer reglas compartidas; `run_engine` + mapa + combate/élite/jefe,
   jugable solo.
4. Recompensas + tendencia + identidad de clase + atributos reducidos.
5. Tienda, armería, descanso.
6. Co-op: votación y pantallas individuales.
7. Progreso permanente: árbol de afuera, loadout, zonas, élites, hazañas.
8. Turnos `porBando` detrás de flag.
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

**Personaje de la run.** Al entrar a la sala y al empezar cada run, cada
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
difícil cuyo mínimo no pasa el nivel de entrada del piso (todavía no hay
zonas desbloqueables, § 8.3). Nivel de enemigos: `1 + 6 × piso +
0.35 × capa` (+1 élite, +2 jefe).

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
garantiza. El nodo elegido entra directo al árbol (`RunRules.grantNode`,
sin puntos ni adyacencia) y vale por los calculadores de siempre.

**Tienda / armería / descanso.** Tienda: la pestaña COMPRAR filtra a los
tipos de arma de la clase; pociones y Éter; vender desde el inventario.
Armería: el banco de forja y fusión de siempre (abre en FORJA). El host
solo deja comprar en la tienda y forjar / fusionar en la armería.
Descanso: cura el 60 % de vida y maná al entrar.

**No implementado todavía.** Catálogo y balance propios de la Travesía
(§ 7: se usa el del Mundo), atributos reducidos en la UI (la Agilidad sigue
existiendo; solo las recompensas la evitan), mejoras directas en Extra,
keystones / ULT de rama en el jefe, sinergia por etiquetas de
`build_wants`, armas que pide un nodo, progreso permanente (§ 8), turnos
`porBando` (§ 6), selector de versión en el Editor y guardado de la run.
Las acciones de puntos del árbol, respec, misiones, pueblo y alijo se
rechazan en la Travesía. Cada partida usa el protocolo propio de Travesía, versión 1 (netcode.md § "Un protocolo por juego").
