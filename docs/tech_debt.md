# Deuda técnica

## v0.30.0 (habitantes en el pueblo y roles)

Tests salteados (prioridad: salir rápido). Hay tests de reglas en
`test/game_engine/residents_v030_test.dart` y `biomes_v029_test.dart`.

- Sin test de sesión de las acciones `town` nuevas (invite / assign /
  gift / turnIn / fulfil / invest / order / commission), de la CASA con
  candado y cobro, ni de los beneficios aplicados (poción, XP, forja,
  PdI revelados, vida máxima y vida llena al volver).
- Sin test de widget de la pantalla del habitante (pestañas), del
  REGISTRO DE ENCARGOS, de las opciones de la CASA en EDITAR PUEBLO ni
  del resumen de la FUENTE. Sin capturas de los habitantes caminando.
- La forja muestra y valida en el cliente el costo sin el descuento de
  Brann (el anfitrión cobra con descuento); la tienda no sabe del pueblo.
- Brann descuenta solo la forja de estadísticas (no reforja, afijos ni
  "tiradas").
- Velda revela los primeros N PdI de cada piso (no salas del mapa).
- Los habitantes del pueblo se hablan con E; el clic sobre ellos no abre
  su pantalla todavía.
- Las órdenes piden especie y calidad, todavía no tamaño de pez.
- El tope diario de XP por órdenes y el encargo de forja de "uno por día"
  viven en memoria del anfitrión (se reinician al reabrir la sala).
- Paridad de XP pueblo / mazmorras (roles.md § 1): los números
  (`orderXpPerValue`, `orderXpDayCap`, `lifeLevelCharXp`) son una primera
  pasada sin medir; falta una simulación por hito de zona.
- Árboles de oficio sin nodos de poder de aventurero; sin oficio de
  Herrería (roles.md § 5).
- Sprites: casas por nivel y habitantes son arte provisorio (los
  habitantes reusan granjero y pescador).
- El habitante sigue también en su bioma después de mudarse.

## v0.27.0

- test/game_engine/sky_session_test.dart: en la sala (anfitrión) el reloj avanza con `farmTick`, el día nuevo toma el pronóstico, la lluvia riega las parcelas de `s.town` y la tormenta tira `LightningEvent` (JSON `bolt` ida y vuelta).
- test/game_engine/helpers_session_test.dart: `helperUpgrade` valida dueño, oficio, nivel y pago; vuelta con RITMO / RED / RAREZA / HALLAZGO; pescadores con tormenta sacan `stormFisher`; hire cobra fibra / cebo.
- test/features/world/helper_panel_test.dart: pestaña MEJORAS (MEJORAR gris con el motivo, sube el rango) en granjero y pescador.
- test/features/inventory/condense_life_test.dart: sección OFICIOS de CONDENSAR (×1 / ×5 / MÁX, gris sin materiales, "Solo en el Mundo" en la Travesía).
- test/features/world/town_edit_faro_test.dart: CONSTRUIR → FARO (gris sin oro), fantasma 1×1, MOVER y BORRAR un faro; hover con la info.
- test/features/world/sky_layer_test.dart: noche y luces no se dibujan en mazmorras ni en EDITAR PUEBLO; destello del rayo 0 con destellos apagados; cartel del pronóstico.
- test/features/world/session_music_test.dart: crossfade real a `townNight` al cruzar el atardecer con `SessionMusic` (solo está el de `trackFor`).
- El cielo arranca en el día 1 en mundos viejos; no hay forma de ver la hora fuera del tinte (un reloj en el HUD queda pendiente).

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

## v0.25.8

- Sin test nuevo: que `PixelIcon` use el PNG de `items.<forma>` cuando
  está cargado y el dibujo procedural cuando falta (se verificó solo con
  las capturas de tool/shots/v0257_iconos_armas_shots_test.dart).
- No se corrió la suite completa: solo test/features/admin,
  inventory, combat (sprite_catalog, held_weapon) y world (ground_loot,
  life_grid_shots).
- Las armas en mano (weapon_overlay.dart) siguen con el dibujo procedural.
## v0.25.6

- Sin test propio: ficha RESUMIDA del arma (`itemTipSummaryParts`), el
  ejemplo de TEXTOS en Ajustes y los textos y la comparación de
  herramientas de oficio (`life_tool_text.dart`); verificados con
  tool/shots/v0256_textos_ult_shots_test.dart y a mano.
- tool/shots/v0256: `pumpPanel` fija su propio tamaño, así que la
  captura de 1024×640 de la ULT sale igual a la de 1280×720; falta una
  captura real a 1024×640.

## v0.29.0

- (Hecho en v0.30.0.) Habitantes en el pueblo (overworld_biomes.md § 10, town_editor.md
  § 3.4): solo estaban las reglas puras y el modelo (`ResidentRules`,
  `ResidentState`, cadena de encargos de Ilda) con test. Falta: guardar
  `ResidentState` en `TownState` / mundo, acciones de red (invitar,
  asignar casa, entregar encargo; subiría el protocolo a 51), la
  construcción CASA en `kConstructions` con sprites por nivel, el
  habitante caminando en el pueblo con rutina de día y noche, el "!" de
  pedido, el registro de encargos, aplicar los beneficios (pociones,
  salas reveladas, XP, forja, vida), el resumen en la fuente y las
  cadenas de Velda, Kael, Brann y Oren. Ningún habitante está completo
  de punta a punta en el juego todavía.
- La relación con el habitante todavía no sube con nada.
- Exteriores nuevos: mismo esqueleto que el Bosque; sin capturas ni test
  de UI de la pantalla del habitante ni del botón "ZONA N" del mapa de
  viaje.
- Peces y semillas nuevos usan el ícono genérico de su tipo.

## v0.32.0 (diálogo de habitantes y encargos seguidos)

- Marca de encargo en las casillas de inventario / baúl ("Lo pide Ilda
  (encargo 3)") y la marca de habitantes en el minimapa: sin hacer.
- DIARIO desde PERSONAJE: sin botón todavía (J, HUD y FUENTE sí).
- El avance "Tenés" cuenta la bolsa de oficios, no el baúl.
- Sin test de UI de la pantalla del habitante ni del DIARIO ni del HUD
  de seguidos; sin capturas nuevas.
- La tienda del habitante no tiene filtros (una sola categoría).
