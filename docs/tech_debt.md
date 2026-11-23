# Deuda técnica

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
