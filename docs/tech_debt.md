# Deuda técnica

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

## v0.25.7

- Sin test nuevo: que `PixelIcon` use el PNG de `items.<forma>` cuando
  está cargado y el dibujo procedural cuando falta (se verificó solo con
  las capturas de tool/shots/v0257_iconos_armas_shots_test.dart).
- No se corrió la suite completa: solo test/features/admin,
  inventory, combat (sprite_catalog, held_weapon) y world (ground_loot,
  life_grid_shots).
- Las armas en mano (weapon_overlay.dart) siguen con el dibujo procedural.
