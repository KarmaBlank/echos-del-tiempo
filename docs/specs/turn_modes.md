# Spec: Modos de turno del RPG

Estado: propuesta (sin código). Hoy `TurnRule` (battle_state.dart) tiene
`velocidad` (el Mundo) y `porBando` (la Travesía, roguelike.md § 6.1).
Esta spec agrega la elección en la sala del RPG y un tercer modo.

## 1. Opción en la sala

El anfitrión elige "Modo de combate" en la sala, antes de salir:

| opción | regla | por defecto |
|---|---|---|
| Línea de tiempo | `velocidad` con los topes de v0.20.20 | sí |
| Por fases | `porBando` con la presentación de § 3 | no |
| Por rondas | `porRonda` (nueva, § 4) | no |

Se guarda en la sala (como la dificultad) y vale para todas las peleas
de la sesión. Cambiarla en medio de una pelea no la afecta: rige desde
la próxima. Los que entran tarde reciben la regla con el estado.

## 2. Línea de tiempo

Sin cambios de regla: la de siempre más los límites de combat.md §
"Límites" (rendimiento decreciente sobre VEL 16 y como máximo 2 turnos
por turno del aliado vivo más lento).

## 3. Por fases

Es `porBando`, que ya existe, con estos agregados para el RPG:

- Banner "FASE ENEMIGA": actúan los enemigos de a uno, en orden de lista.
  Nada carga: ni barra ULT por turno propio de enemigos fuera de su
  acción, ni efectos con duración del grupo.
- Banner "FASE DE JUGADORES" y una pausa corta de planificación (ajuste
  `planPause`, 2 s; el primer comando la corta).
- Los jugadores actúan en cualquier orden (ya es así: actúa el primero
  que manda un comando).
- Cada jugador tiene un botón TERMINAR TURNO (hoy pasa con Pasar /
  Defender); la fase termina cuando todos terminaron o actuaron. El que
  terminó sin actuar no gana el Pulso de la acción.
- La barra ULT, los turnos de los efectos y las cargas cuentan en la
  fase de jugadores (al terminar cada jugador), no en la enemiga.
- Tiempo por jugador: el mismo temporizador de turno; al agotarse,
  Defender automático y terminado.

Lo que ya hace el motor: `groupPhase`, `acted`, `pendingGroup`,
`awaitingGroup`, `_nextBando` y el banner `_bandoBanner` (TURNO DEL
GRUPO / TURNO ENEMIGO). Falta: el comando `EndTurnCommand`, la pausa y
los textos nuevos del banner.

## 4. Por rondas (nuevo)

Cada combatiente actúa exactamente una vez por ronda. La velocidad decide
el orden, nunca la cantidad de turnos.

- Al empezar la ronda se ordena a todos los vivos por velocidad efectiva
  (con la curva de rendimiento decreciente), empate por id.
- Jugadores seguidos en el orden forman un bloque: dentro del bloque
  actúan en cualquier orden (el primero que manda), como una mini fase
  de jugadores.
- Acción nueva "Esperar": el combatiente pasa al final de la ronda (una
  vez por ronda). Si varios esperan, mantienen su orden relativo.
- Los efectos que hoy mueven el turno (`nextTurn` ± intervalo: Prisa,
  retrasos, Congelación) se traducen a posiciones: adelantar = sube un
  lugar en la ronda en curso; retrasar = baja un lugar; "pierde el
  turno" = salta esta ronda.
- Turno extra: actúa otra vez inmediatamente (una por ronda).
- Aguanta una ronda (combat.md § "Límites") usa esta misma ronda.

Motor: `TurnRule.porRonda`, una lista `roundOrder` en `BattleState` y un
`_nextRonda` paralelo a `_nextBando`. `cappedInterval` no se usa.

## 5. Netcode

- La regla viaja en el estado de batalla (`turnRule`, ya serializado) y
  en la sala; agregar `porRonda` y `roundOrder` sube `kProtocolVersion`.
- El host sigue siendo la única autoridad: decide el orden, valida "el
  primero que manda" dentro de un bloque y descarta el segundo comando
  con el mismo rechazo que hoy (`porBando`).
- TERMINAR TURNO y Esperar son comandos nuevos (`BattleCommand`), con su
  codec.
- Pausa de planificación: la lleva el host (marca de tiempo en el
  estado), para que todos vean el mismo conteo.
- `netcode/rollback` y `netcode/dedicated_server` no cambian: la regla es
  del motor (Dart puro), no de la red.

## 6. UI

- Línea de tiempo: la franja de turnos de siempre.
- Por fases: banner grande al cambiar de fase (FASE ENEMIGA / FASE DE
  JUGADORES), lista de quiénes faltan (ya existe) y el botón TERMINAR
  TURNO en la tarjeta de cada jugador.
- Por rondas: la franja muestra la ronda en curso en orden, con el
  bloque de jugadores agrupado y el número de ronda; "Esperar" en el
  menú de acción, en gris si ya esperó en esta ronda.
- Ayuda de la sala: una línea por modo ("Por rondas: todos actúan una
  vez por ronda; la velocidad decide quién va primero").
