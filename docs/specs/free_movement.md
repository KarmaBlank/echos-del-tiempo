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
- **ENTRAR** en una entrada (o abrir un Eco, una Prueba, un Jefe del
  Abismo, el TUTORIAL) mete solo a ese jugador (y a sus compañeros de
  party de solitario). Sin votación ni LISTO de preparación.
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
  siempre) y la instancia se cierra.

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
  La UI muestra SALIR DE LA MAZMORRA ahí (`canLeaveDungeon`).
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
  pierde). Volver a ENTRAR arma una nueva.
- Sus compañeros de solitario salen con él.

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
  dónde]`, para la lista del grupo. Se recalcula solo cuando alguien se
  mueve, entra o sale.
- Protocolo 57: un cliente viejo no entiende salas partidas; hay que
  actualizar.

## 4. Cliente / UI

- El cliente dibuja lo que llega: su instancia. El anfitrión mira la suya
  (`SessionController.session` = la instancia del jugador local).
- El mapa de viaje: VIAJAR para todos (sin "Decide el anfitrión");
  gris solo si el bioma está cerrado para uno o si está en mazmorra.
- La lista del grupo en el HUD suma "En otro lugar: Nombre (Bosque)".
- Las acciones del pueblo (pesca, huerta, forraje, habitantes) ya miran
  el `mode` / `place` de la instancia del jugador, o sea su propio lugar.

## 5. Fuera de alcance (deuda)

- Sumarse a un Eco ajeno o a un TUTORIAL ajeno.
- La UI no muestra todavía un botón "unirse a ..." explícito: se entra
  por la misma entrada.
