# Spec: Movimiento libre por jugador (v0.33.0, protocolo 57)

Estado: implementado en v0.33.0. Reemplaza "todos viajan juntos"
(overworld_biomes.md § 4) y la votación / preparación para entrar a una
mazmorra del Mundo (missions.md). La Travesía (roguelike.md) no cambia:
ahí la sala sigue siendo una sola.

## 1. Regla

Cada jugador decide solo dónde está:

- **Pueblo**, **exterior de un bioma** (mapa de viaje) o **una mazmorra**.
- Viajar por el mapa de viaje es instantáneo y de a uno: sin votación,
  sin "decide el anfitrión", sin pantalla de espera. Cada uno usa su
  propia zona desbloqueada para saber qué biomas puede abrir.
- **PROPONER** en el mostrador (o abrir un Eco en el portal de su zona,
  ecos_zone.md § 4, una Prueba, un Jefe del
  Abismo, el TUTORIAL) mete solo a ese jugador (y a sus compañeros de
  party de solitario). Sin votación ni LISTO de preparación. Con amigos
  en el mundo, antes abre una convocatoria para entrar juntos (§ 2.1.1).
- Si ya hay amigos jugando esa misma misión (o esa misma Prueba / ese
  mismo Jefe del Abismo), el que entra se suma a su instancia: aparece en
  la entrada del piso actual, y si están peleando entra a la pelea como
  refuerzo (overworld_biomes.md § 5). No se suma a una instancia que ya
  terminó (resultado, vuelta de victoria) ni a un Eco (es de quien lo
  abrió) ni al TUTORIAL.
- Una pelea solo involucra a los jugadores de **esa** instancia. El que
  pesca en el pueblo o recolecta en el bosque nunca entra a una pelea
  ajena.
- Al terminar una mazmorra sus jugadores vuelven al **pueblo** (como
  siempre) y la instancia se cierra. Desde v0.34.0 una mazmorra de zona
  queda **guardada en el mundo** al cerrarse (persistent_dungeons.md).

## 2. Modelo (host)

`game_engine` sigue siendo Dart puro. Una "sala" (`GameSession`) ahora es
una **instancia**: un lugar con solo los jugadores que están ahí.

- `SessionWorld` (`lib/game_engine/models/session_world.dart`): las
  instancias por clave, en orden. Claves: `pueblo` (siempre existe), el
  id del bioma (`bosque`...) y `d1`, `d2`... para las mazmorras. Cada
  jugador está en exactamente una.
- `WorldEngine` (`lib/game_engine/rules/world_engine.dart`) envuelve a
  `SessionEngine`: enruta cada acción a la instancia del jugador, corre
  `tick` en todas, mueve jugadores entre instancias y comparte lo común.
  `SessionEngine` sigue trabajando sobre una `GameSession` como siempre.
- Lo común se copia de la instancia que cambió a las demás después de
  cada paso (en orden: nunca se pisan dos cambios): el pueblo
  (`TownState`), el pozo Loot perdido, el Atlas, el modo de combate, el
  tiempo de turno, el mundo, la pausa y `ownerId`.
- El reloj del pueblo (crecimiento, cielo, ayudantes, habitantes) corre
  una sola vez por tick: en la instancia `pueblo`
  (`SessionEngine.tick(..., world: true)`); las demás llaman con
  `world: false`. Todas avanzan el mismo `dt`, así que los relojes
  (`GameSession.time`) siguen iguales; una instancia nueva copia el del
  pueblo.
- `GameSession.ownerId`: el dueño del mundo (el primer jugador, el
  anfitrión). Editar el pueblo y lo que antes miraba "primer humano de la
  sala" mira esto: el anfitrión sigue siendo el dueño aunque esté en una
  mazmorra. Viaja como `own` (protocolo 57) para que la UI oculte lo del dueño. Las hazañas de combate llevan un seguimiento por instancia (`GameSession.instance`, solo host).
- Estado del host por jugador (pesca pendiente, XP por estadía): se
  limpia solo para los jugadores que vuelven, no para todo el mundo.

### 2.1 Entrar (enrutado)

Una acción de inicio (`ProposeMissionAction`, `ProposeEcoAction`,
`ProposeTrialAction`, `ProposeAbyssAction`, `StartTutorialAction`) de
alguien en el pueblo o en un exterior:

1. Si es una misión / Prueba / Jefe del Abismo y hay una instancia de
   mazmorra jugando lo mismo en `field` o `battle` sin resultado: el
   jugador (y sus compañeros) pasan a esa instancia.
2. Si no, se crea `dN` (copia de lo común del pueblo, sin jugadores), se
   pasa el jugador, se aplica la acción ahí y se resuelve sola la
   votación y la preparación (es el único humano). Si la acción no vale,
   vuelve a donde estaba y la instancia se descarta.

### 2.1.1 Convocatoria (v0.42.0, protocolo 63)

Con **otros humanos** en el mundo, una `ProposeMissionAction` /
`ProposeTrialAction` / `ProposeAbyssAction` desde el pueblo o un exterior
no entra: abre una **convocatoria** (`Gathering`: quién, qué, quiénes se
sumaron). Una sola por mundo, igual en todas las instancias (`gat` en el
snapshot). Chat a todos: `X convoca a <misión> — UNIRSE para ir juntos.`
(la línea avisa con el chat plegado).

- Quien propone ve una tarjeta en el HUD: `Esperando a que alguien se
  una…` (o la lista de los que se sumaron), la cuenta regresiva, **ENTRAR
  YA** (habilitado al instante, sin espera mínima) y **CANCELAR**.
- Los demás ven la tarjeta con **UNIRSE** / **IGNORAR** (o **SALIR** si ya
  se sumaron; desde el pueblo o un exterior, desde una mazmorra no). La
  tarjeta no se cierra sola: solo cuando la convocatoria termina o con
  IGNORAR (local, solo oculta esa convocatoria en ese dispositivo). En el
  mostrador la misión dice `UNIRSE (nombre)`. Proponer lo mismo que está
  convocado = UNIRSE.
- **Cuenta regresiva (v0.48.5, protocolo 82):** la convocatoria espera
  `mission.gatherSeconds` (tuning, 20 s por defecto). El reloj lo corre el
  anfitrión en `WorldEngine.tick`; viaja en `gat.lf` (segundos enteros).
  Al llegar a 0 pasa lo mismo que con ENTRAR YA; si ya no se puede entrar
  (quien propone se alejó del portal, salió del lobby...) la convocatoria
  se cierra con aviso a todos.
- Los portales de Ecos (`ProposeEcoAction`, tipo `eco`) también convocan
  (antes entraban directo: el resto veía el aviso un instante y quien
  proponía ya estaba adentro).
- `GatherAction(join | leave | go | cancel)`. IR: quien propone entra
  como en § 2.1 y, en el mismo paso, todos los sumados que siguen en el
  pueblo o un exterior (en lobby) pasan a esa misma instancia. La
  convocatoria se cierra.
- Si nadie se suma, IR entra igual. Los que no se sumaron pueden entrar
  después cuando quieran (se suman a la instancia, § 1) o con **UNIRSE**
  en la tarjeta de ese jugador abajo a la derecha (`JoinPlayerAction`,
  § 2.5). Si la instancia no lo admite ahora (en batalla, con resultado,
  Travesía / TUTORIAL) el botón queda gris con el motivo en el tooltip.
- Sin convocatoria (entra directo): jugando solo (un humano), si ya hay
  amigos jugando eso (se suma a su instancia), si hay otra convocatoria
  abierta de otra cosa, y para el TUTORIAL.
- Se cierra sola si quien propone se va de la sala o entra a una
  mazmorra; los sumados que se van salen de la lista.
- Fuera del Mundo con movimiento libre (Travesía) se sigue votando
  (`¡Voten!`).

`VoteMissionAction`, `ReadyAction` y `CancelPrepAction` quedan sin uso
en el Mundo (el motor las sigue aceptando dentro de una instancia).

### 2.2 Viajar

`TravelAction(lugar)`: lo valida el host con el perfil de quien viaja
(`BiomeRules.canTravelTo`), solo desde el pueblo o un exterior, sin
compañero. Pasa al jugador (y sus compañeros) a la instancia del lugar
(se crea si no existe; un exterior vacío se cierra). Aparece en el punto
de entrada del mapa, guarda la caña.

### 2.4 Salir solo de una mazmorra

`LeaveDungeonAction` (`leaveD`, `{i: poiId}` opcional). Cualquiera sale
solo; los demás siguen adentro.

- Dónde: caminando a la entrada del piso 1 (a `exitReach` = 28 px del
  punto de llegada del piso 0) o junto a una piedra de paso activada del
  piso actual (la misma mecánica de viaje rápido, worldgen.md § 11.4).
  La UI muestra SALIR DE LA MAZMORRA ahí (`canLeaveDungeon`), arriba al
  centro del HUD, sin pisar nada (exploration.md § "HUD").
- Se ve en el mapa (v0.41.3): un portal de salida en la llegada del piso
  1 (`MapGame.dungeonExitAt`), sprite `items.vida_salida_mazmorra` del
  manifest (placeholder de píxeles, se cambia desde el editor), y una
  marca de escalera en el minimapa. Solo con movimiento libre, fuera del
  TUTORIAL y de la Travesía.
- Cuándo: solo en el campo (`field`), vivo, sin resultado. **No en
  batalla** ni repartiendo puntos (`levelUp`): primero se termina la
  pelea. Tampoco en el TUTORIAL ni en la Travesía.
- A dónde: al lugar desde donde se entró (`place` de la instancia: el
  exterior del bioma, o el pueblo), frente a la entrada de esa zona si el
  mapa la tiene. Desde ahí viaja libre (al pueblo, etc.).
- Se lleva todo lo que tiene en el perfil (armas, materiales, XP). Lo
  suyo que quedó en el piso de la mazmorra se queda ahí (deuda).
- La instancia sigue para los que quedan. Si sale el último, **la
  instancia se cierra** (sin resultado ni rango; el loot del piso se
  pierde). Desde v0.34.0, si es una mazmorra de zona, antes de cerrarse
  se **estaciona** en el mundo (persistent_dungeons.md § 2.1) y volver a
  ENTRAR la restaura; Ecos, Pruebas y Abismo arman una nueva.
- Sus compañeros de solitario salen con él.

### 2.5 IR CON otro jugador (v0.41.3, protocolo 63)

`JoinPlayerAction` (`joinP`, `{p: id}`): pasa al jugador (y sus
compañeros) a la instancia de otro jugador humano, a su misma posición.
Pueblo, bioma o mazmorra, sin revisar zonas desbloqueadas (es ir con un
amigo). Solo si las dos instancias están en `lobby` o `field`, sin
resultado, fuera del TUTORIAL y de la Travesía
(`WorldEngine.canJoin`); si no, se rechaza. El cliente lo sabe por
`AwayPlayer.busy`.

### 2.3 Cerrar

Una instancia de mazmorra que vuelve a `lobby` sin misión (`toLobby`)
manda a sus jugadores al `pueblo` y se cierra. Un exterior sin jugadores
se cierra. El `pueblo` nunca.

## 3. Red

- Cada cliente recibe **solo su instancia** (`NetSession.broadcast(state,
  events, only: {...})`, una llamada por instancia) y solo los eventos de
  ella. Los perfiles que van en `pp` son solo los de esa instancia. El
  ancho de banda es el de una sala con los que están en el mismo lugar.
- `GameSession.away` (`aw`): los que están en otro lugar, `[id, nombre,
  dónde, clave, ocupado?]`, para la lista del grupo. `clave` (protocolo
  63): `pueblo`, el id del bioma o `m:<misión>` (vacía en el TUTORIAL);
  `ocupado` (`1`, se omite si no): su instancia no admite IR CON. Se recalcula solo cuando alguien se
  mueve, entra o sale.
- Protocolo 57: un cliente viejo no entiende salas partidas; hay que
  actualizar.

## 4. Cliente / UI

- El cliente dibuja lo que llega: su instancia. El anfitrión mira la suya
  (`SessionController.session` = la instancia del jugador local).
- El mapa de viaje: VIAJAR para todos (sin "Decide el anfitrión");
  gris solo si el bioma está cerrado para uno o si está en mazmorra.
- Cajas del grupo (v0.41.3): siempre están todos. Los que están en otro
  lugar salen con una caja atenuada con su nombre, dónde está y
  `UNIRSE` (§ 2.5; gris con el motivo en el tooltip si no se puede).
  Desde v0.49.21 todo el grupo va en UNA fila de cajas del mismo ancho
  y alto (compactas): el que está en otro lugar usa la misma caja,
  atenuada, con nombre, lugar y un UNIRSE chico adentro. La fila nunca
  pasa a dos renglones: si no entra, se achica entera. Los nombres nunca
  se cortan (se achican). Los atajos de pociones van arriba con ancho
  fijo, así nada se corre cuando alguien entra, sale o cambia de lugar.

### 4.1 Dónde están los demás (v0.41.3)

`playersByPlace` (`features/world/domain/player_locations.dart`) junta
los de la propia instancia y `away` por clave de destino. En el
MOSTRADOR, cada fila de zona / misión con gente muestra una insignia
(ícono de persona + cantidad, `PlayersHereBadge`) y en el MAPA DE VIAJE
cada bioma igual; al pasar el mouse, un tooltip de tamaño fijo con
"Jugadores acá" y los nombres. Sin datos nuevos en la red aparte de la
clave del § 3.
- Los botones de inicio dicen **ENTRAR** (`ui.missions.enter` en el
  Mostrador, `ui.ascension.enter` en PRUEBAS de la Estatua del Tiempo),
  nunca PROPONER: no hay nada que proponer, el jugador entra directo
  como por el portal. Las acciones de red no cambian (siguen siendo
  `Propose*Action`, el host las resuelve solas, § 2.1).
- Las acciones del pueblo (pesca, huerta, forraje, habitantes) ya miran
  el `mode` / `place` de la instancia del jugador, o sea su propio lugar.

## 5. Fuera de alcance (deuda)

- Sumarse a un Eco ajeno o a un TUTORIAL ajeno.
- La UI no muestra todavía un botón "unirse a ..." explícito: se entra
  por la misma entrada.
