# Rollback netcode (futuro, opcional)

**Nota honesta de arquitectura:** el combate por turnos (timeline tipo
por turnos) NO necesita rollback — es lockstep discreto, no hay nada
continuo que predecir/revertir entre turnos. Un modelo autoritativo
simple (host o servidor dedicado) alcanza y sobra ahí.

Donde el rollback SÍ podría justificarse es en la **exploración de campo
en tiempo real** (mover al personaje por el mapa antes de que arranque
una batalla), si esa parte evoluciona a algo más "twitch"/MMO con
muchos jugadores moviéndose a la vez y la latencia importa de verdad.

Si se llega a ese punto, esto implementa `NetSession` con predicción de
input local + reconciliación cuando llega el estado autoritativo
(patrón GGPO). Hasta entonces, queda como carpeta vacía con este README
para que el lugar ya exista en la arquitectura.
