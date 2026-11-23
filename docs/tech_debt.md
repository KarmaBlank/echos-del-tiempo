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
## v0.25.7

- test/features/world/farming_world_test.dart: CONTRATAR GRANJERO desde la fuente con nivel y oro: clic en la huerta contrata (helper +1, se cobra) y sale del modo elegir; no dueño ve los botones grises con el motivo.
- test/features/world/town_strip_cards_test.dart: lado al tope muestra la tarjeta gris "Límite de ampliación alcanzado" / "Límite de este lado" y el clic en la franja no abre AMPLIAR (solo se vio en la captura).

## v0.25.5

- test/features/world/helper_panel_test.dart: pantalla del granjero (G al lado del NPC): PASAR 1 / 10 / TODO y DEVOLVER entre las dos grillas, filtro por rareza y buscador, TAREAS cambia los bits, RECOGER TODO del cofre.
- test/features/world/helper_map_test.dart: hover de un ayudante (contorno del área y tooltip "Próximo ciclo"), E en el cofre recoge, aviso "[G] Ayudante" sumado al de la huerta, NPC no tapa las labores.
- test/game_engine/helpers_session_test.dart: vuelta en la sala (anfitrión): granjero y pescador alineados al reloj, cofre lleno frena, hire / fire / giveSeeds / takeSeeds / helperTasks / collectChest validan dueño y huerta; JSON de las acciones nuevas.
- test/game_engine/town_editor_test.dart: dos huertas pegadas se funden y pasan las parcelas a la esquina nueva.
- test/features/world/life_items_view_test.dart: sub-filtro de HERRAMIENTAS y elegir lago al soltar.

## v0.25.1

- test/features/world/tool_hud_test.dart: abonar con el casillero ABONO
  (E con abono propio sobre parcela plantada → `fert` puesto y el abono
  elegido descontado; "Ya tiene abono" después; clic en `hud-fert-pick`
  cambia de abono con dos o más propios; aviso "· [F] Abonar").
- test/features/world/tool_hud_layout_test.dart: la barra de 4 casilleros
  (480 px) sin tapar chat ni pociones con texto grande (TextSize huge).
- test/features/world/life_grid_shots_test.dart: VENDER pesca (CANJEAR
  de un legendario en el detalle) y la grilla angosta (detalle arriba,
  ancho < 560).

## v0.25.6

- Sin test propio: ficha RESUMIDA del arma (`itemTipSummaryParts`), el
  ejemplo de TEXTOS en Ajustes y los textos y la comparación de
  herramientas de oficio (`life_tool_text.dart`); verificados con
  tool/shots/v0256_textos_ult_shots_test.dart y a mano.
- tool/shots/v0256: `pumpPanel` fija su propio tamaño, así que la
  captura de 1024×640 de la ULT sale igual a la de 1280×720; falta una
  captura real a 1024×640.
