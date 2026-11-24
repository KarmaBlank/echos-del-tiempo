# Spec: Modos de turno del RPG

Estado: implementado en v0.20.23 (protocolo Mundo 40). `TurnRule`
(battle_state.dart) tiene `velocidad` (Línea de tiempo), `porBando` (la
Travesía, roguelike.md § 6.1, sin cambios), `porRonda` (Por rondas) y
`porFases` (Por fases). `BattleState.porBando` vale para `porBando` y
`porFases` (comparten la fase de grupo); `grouped` es "cualquiera que no
sea la línea de tiempo".

## 1. Opción en la sala

> v0.33.0: "cooperativo" se mide en la instancia de la pelea
> (free_movement.md): solo cuentan los humanos que están en esa mazmorra.

El anfitrión elige "Modo de combate" en la preparación de la misión
(`PrepPanel`, selector con flechas; el resto lo ve con "lo elige el
anfitrión"). Cada opción tiene un tooltip de una línea (`CombatMode.tip`).

| opción | regla | por defecto |
|---|---|---|
| Línea de tiempo | `velocidad` con los topes de v0.20.20 | no (en prueba) |
| Por rondas (recomendado) | `porRonda` (§ 4) | solo y cooperativo |
| Por fases | `porFases` (§ 3) | no |

Desde v0.41.5 vuelve "Por rondas (recomendado)" por defecto (v0.41.2 a v0.41.4 fue "Por fases") en solitario
y en cooperativo (`modeSolo` = `modeCoop` = 1). Se elige en OPCIONES → JUEGO → MODO DE COMBATE (la preparación de misión ya no se abre). Las otras dos dicen en su
tooltip por qué están en prueba. Un `GameSettings.combatMode` ya guardado
se respeta; solo cambia el de por defecto de los ajustes sin valor.

Los defaults son ajustes de Balance (Editor → Balance → Límites de
combate): `modeCoop` y `modeSolo` (0 línea de tiempo, 1 por rondas, 2 por
fases). Cooperativo = más de un jugador humano (los compañeros de la party
en solitario no cuentan).

Se guarda en la sala (`GameSession.combatMode`, `null` = el de por
defecto; `effectiveCombatMode` resuelve) y en el ajuste local del
anfitrión (`GameSettings.combatMode`, persistido). Vale para todas las
peleas del Mundo de la sesión. Cambiarla en medio de una pelea no la
afecta: rige desde la próxima. Los que entran tarde reciben la regla con
el estado. El TUTORIAL y la Travesía no la usan.

## 2. Línea de tiempo

Sin cambios de regla: la de siempre más los límites de combat.md §
"Límites" (rendimiento decreciente sobre VEL 16 y como máximo 2 turnos
por turno del aliado vivo más lento).

## 3. Por fases

Es la fase de grupo de `porBando` con los enemigos primero:

- "FASE ENEMIGA" (franja de turnos): actúan los enemigos de a uno, en
  orden de lista.
- "FASE DE JUGADORES": arrancan los turnos de todos los jugadores (estados,
  Pulso, aturdidos que pierden la fase) y actúan en cualquier orden (el
  primero que manda un comando).
- Pausa de planificación: al abrir la fase de jugadores el reloj de turno
  arranca en `-planPause` (Balance, 2 s): esos segundos no cuentan para
  el tiempo de turno. El primer comando la corta (el reloj vuelve a 0).
- Cada jugador tiene TERMINAR TURNO (`EndTurnCommand`): cierra su parte
  sin actuar. El que terminó sin actuar no gana el Pulso de una acción.
  La fase termina cuando todos los vivos actuaron o terminaron; después
  actúan las invocaciones y empieza la ronda siguiente (fase enemiga).
- Nada del grupo cuenta en la fase enemiga: la barra ULT por turno, los
  efectos con duración y las cargas del grupo cuentan en los turnos de
  cada jugador. (La ULT por daño recibido sigue como siempre.)
- Tiempo agotado: los que faltan se defienden solos.

## 4. Por rondas

Cada combatiente vivo (jugadores, invocaciones, enemigos) actúa
exactamente una vez por ronda. La velocidad decide el orden, nunca la
cantidad de turnos.

- Al empezar la ronda se ordena a todos los vivos (no pasivos) por
  velocidad efectiva (`BattleEngine.interval`, con la curva de rendimiento
  decreciente); empate estable en orden de lista: grupo, invocaciones,
  enemigos. El orden queda en `BattleState.roundOrder`.
- Los cambios de velocidad (buffs, Congelación) rigen desde la ronda
  siguiente. Los que llegan a mitad de ronda (invocaciones, jugadores que
  entran) actúan desde la siguiente.
- Jugadores seguidos al frente de lo que falta forman un bloque: arrancan
  sus turnos juntos y actúan en cualquier orden (el primero que manda),
  cada uno una vez. El bloque termina cuando todos actuaron o terminaron
  (TERMINAR TURNO también vale acá). Las invocaciones actúan solas, con su
  IA, como un enemigo.
- ESPERAR (`WaitCommand`): el jugador del bloque pasa al final de la ronda.
  Una vez por ronda, antes de actuar, y solo si queda alguien detrás
  suyo; si varios esperan, mantienen su orden relativo. Su turno ya
  arrancó: al volver no se repiten estados ni Pulso.
- Turno extra (Danza de Cuchillas y otros): una acción extra dentro del
  mismo turno (igual en Por fases).
- Duraciones: cuentan en rondas (cada efecto baja 1 al final del turno de
  su dueño, que es una vez por ronda).
- Efectos que mueven el turno en la línea de tiempo (`nextTurn`: Prisa,
  retrasos, Pasar ×½): no cambian el orden de la ronda. "Pierde el turno"
  (aturdido, quebrado, telaraña) salta su lugar en esta ronda.
- Aguanta una ronda (combat.md § "Límites") usa esta misma ronda (y en
  Por fases, la ronda = fase enemiga + fase de jugadores).
- Nadie solo en una fase (combat.md § "Nadie solo en una fase") cuenta el
  daño de cada personaje en su turno dentro de la fase de jugadores.

## 5. Netcode

- La regla viaja en el estado de batalla (`tr`, `gp`, `act`, `rd`; Por
  rondas suma `ro` y `wt`) y el modo en la sala (`cm`). Protocolo Mundo 40.
- La iniciativa del encuentro (combat.md § "Iniciativa del encuentro")
  solo ajusta esos mismos campos al empezar: no cambia el protocolo.
- El host es la única autoridad: decide el orden, valida "el primero que
  manda" dentro del bloque o la fase y descarta el segundo comando.
- ESPERAR y TERMINAR TURNO viajan como `{"a":"wait"}` y `{"a":"end"}`.
- La pausa de planificación la lleva el host (reloj de turno negativo).
- `netcode/rollback` y `netcode/dedicated_server` no cambian.

## 6. UI

- Línea de tiempo: la franja de turnos de siempre.
- Por fases: la franja muestra FASE ENEMIGA / FASE DE JUGADORES y quiénes
  faltan.
- Por rondas: la franja muestra lo que falta de la ronda en orden, con el
  número de ronda y el bloque activo resaltado (íconos grandes).
- En el menú de acción (categoría Pasar): TERMINAR TURNO en Por rondas y
  Por fases; ESPERAR en Por rondas, en gris si ya esperó en esta ronda.
- La IA de los compañeros con AUTO y la de los enemigos funcionan igual en
  los tres modos (actúa el primero con AUTO que falta del bloque o fase).
