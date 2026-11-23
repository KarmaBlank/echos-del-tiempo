# Deuda técnica

## v0.26.0 (mapa de viaje y Bosque, primera pasada)

Tests salteados (prioridad del dueño: salir rápido). Solo hay tests de
reglas en `test/game_engine/overworld_biomes_test.dart`:

- Sin test de widget del MAPA DE VIAJE (botón gris para el no anfitrión,
  PRÓXIMAMENTE, ACÁ). Se ve en `tool/shots/v0260_bosque_shots_test.dart`.
- Sin test de red con dos peers viajando (cliente que ve el cambio de
  mapa por snapshot) ni de `forage` por cable más allá del round-trip de
  `SessionJson`.
- Sin test de pesca en el lago del Bosque (tabla `kForestFish`, basura del
  Bosque); la tirada es la misma de siempre con otra lista.
- Sin test de plantar y cosechar las semillas del Bosque en la huerta
  (son `CropDef` comunes: pasan por el mismo camino que las del pueblo).
- Sin test de que la huerta, la edición del pueblo y los carteles del
  pueblo no se dibujan en el exterior (`map_game.dart`).
- Sin test del prompt `[E] Mapa de viaje` / `[E] Recolectar` ni del
  botón MAPA DE VIAJE de la fuente.

Funcionalidad pendiente:

- Party dividida (unos en el pueblo, otros en un bioma o en la
  mazmorra) y ubicación por jugador (town_loop.md § 11b). Hoy viajan
  todos juntos y decide el anfitrión.
- Con la party dividida, `roomExtra` de la dificultad por sala: hoy es
  siempre 0 porque todos bajan.
- Demora del refuerzo en los modos por ronda / por bando: solo está
  probada en la línea de tiempo (`nextTurn`).
- "Pedir ayuda" y el viaje del refuerzo (§ 11b): no hay.
- XP de personaje por recolectar; respawn por misiones
  (`biome.nodeRespawnMissions`): solo por tiempo.
- Cinemática de viaje y música propia del Bosque.
- Arte procedural de las matas (`ForagePalette`): sin entrada en
  `sprite_manifest.yaml` todavía.
- Los demás biomas (Ruinas, Cavernas, Grieta) se ven en gris.
