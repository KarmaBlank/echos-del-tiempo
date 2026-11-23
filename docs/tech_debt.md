# Deuda técnica

## v0.27.0

- test/game_engine/sky_session_test.dart: en la sala (anfitrión) el reloj avanza con `farmTick`, el día nuevo toma el pronóstico, la lluvia riega las parcelas de `s.town` y la tormenta tira `LightningEvent` (JSON `bolt` ida y vuelta).
- test/game_engine/helpers_session_test.dart: `helperUpgrade` valida dueño, oficio, nivel y pago; vuelta con RITMO / RED / RAREZA / HALLAZGO; pescadores con tormenta sacan `stormFisher`; hire cobra fibra / cebo.
- test/features/world/helper_panel_test.dart: pestaña MEJORAS (MEJORAR gris con el motivo, sube el rango) en granjero y pescador.
- test/features/inventory/condense_life_test.dart: sección OFICIOS de CONDENSAR (×1 / ×5 / MÁX, gris sin materiales, "Solo en el Mundo" en la Travesía).
- test/features/world/town_edit_faro_test.dart: CONSTRUIR → FARO (gris sin oro), fantasma 1×1, MOVER y BORRAR un faro; hover con la info.
- test/features/world/sky_layer_test.dart: noche y luces no se dibujan en mazmorras ni en EDITAR PUEBLO; destello del rayo 0 con destellos apagados; cartel del pronóstico.
- test/features/world/session_music_test.dart: crossfade real a `townNight` al cruzar el atardecer con `SessionMusic` (solo está el de `trackFor`).
- El cielo arranca en el día 1 en mundos viejos; no hay forma de ver la hora fuera del tinte (un reloj en el HUD queda pendiente).

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
