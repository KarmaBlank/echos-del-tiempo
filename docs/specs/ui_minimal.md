# Spec: UI mínima (v0.20.21)

Pedido del dueño: una UI accesible, tranquila y minimalista, con menos
texto en pantalla. La profundidad sigue estando, pero no se impone: se
pide (mouse, `[?]`, "Más detalle"). Este spec manda sobre ui_style.md y
panels.md donde difieran. Se mantienen el estilo pixel / retro, sin
negrita en la UI de juego, sin esquinas redondeadas, los tooltips con
ancho y fuente máximos fijos y los botones deshabilitados en gris.

## 1. Tres niveles de información

| Nivel | Dónde | Qué |
|---|---|---|
| 1. Siempre visible | la fila / casilla / tarjeta | nombre + ícono + una línea corta (≤ 6 palabras) |
| 2. Al pasar el mouse / foco | tooltip o panel de detalle | el detalle con números (valores, costo, antes → después) |
| 3. "Más detalle" | `[?]` del panel o el botón `MÁS DETALLE` | fórmulas, escalado, reglas finas |

Regla: si un texto explica *cómo funciona* algo, va al nivel 2 o 3. En
el nivel 1 solo queda *qué es* y, si aplica, *cuánto cuesta*.

## 2. Presupuesto de texto por pantalla

- Una sola línea de ayuda arriba de la pestaña (`PanelHint`), de
  ≤ 6 palabras (p. ej. FUSIÓN: `Destino, acción, vista previa, confirmar.`).
- Ningún párrafo fijo en el cuerpo: las explicaciones largas viven en
  el `[?]`.
- Por fila: etiqueta + un valor a la derecha (costo, `EQUIPADA`, motivo).
- Una acción = un lugar (§ 5). No se repite el mismo botón en dos zonas.

## 3. Plantilla de listas de armas (DsWeaponList)

Toda pantalla que lista armas usa el mismo organismo `DsWeaponList`
(`lib/features/inventory/presentation/item_grid.dart`), un `DsItemGrid`
con:

- **Buscador siempre presente** arriba (`ItemGridSearch`, mismo criterio
  que el inventario: `inventoryMatches`). `Esc` con texto lo limpia.
- **La equipada fija arriba** (`PinnedEquippedRow`): su casilla y la
  marca `EQUIPADA`, siempre visible aunque no coincida con la búsqueda.
  Si la lista no puede usarla (p. ej. el origen de FUSIÓN, que se
  destruye) se muestra igual, con candado, y tocarla no hace nada.
- Clave de la fila fijada: `<prefijo>pinned` (`bench-weapon-pinned`,
  `craft-source-pinned`, `forge-pinned`).

Pantallas:

| Pantalla | Organismo |
|---|---|
| FUSIÓN paso 1 (destino) | `DsWeaponList` (`bench-weapon-`) |
| FUSIÓN paso 3 (origen que se trae) | `DsWeaponList` (`craft-source-`) |
| FORJA | `DsWeaponList` (`forge-`, buscador `forge-search`) |
| COMPRAR (catálogo de bases) | buscador `buy-search` + `PinnedEquippedRow` (`buy-pinned`) arriba de las filas `MenuRow` |
| INVENTARIO y ALIJO (grillas de casillas fijas) | buscador + casilla `EQUIPADA` fija al costado (las casillas son posiciones, no se reordenan) |

## 4. Asistentes por pasos (FUSIÓN y FORJA)

Mismo esqueleto en las dos: migas `StepCrumbs` arriba, lista a la
izquierda, detalle / vista previa a la derecha, botón primario abajo a
la derecha.

- **FUSIÓN**: `1 DESTINO › 2 ACCIÓN › 3 PREVIA` y el botón de
  confirmar (el verbo de la acción) en el paso 3. El costo se ve en cada
  fila del paso 2 y otra vez junto al botón. Las acciones que no se
  pueden quedan grises con el motivo.
- **FORJA**: `1 ARMA › 2 MEJORA › 3 CONFIRMAR` (`forge-crumb-<n>`).
  Tocar una tarjeta de mejora solo la elige (borde dorado, ANTES →
  DESPUÉS y costo en la tarjeta); `FORJAR` (`forge-confirm`) la aplica.
  Sin elegir, `FORJAR` está gris con el motivo `Elegí una mejora`.

## 5. Acciones en lote del inventario: un solo lugar

`LIMPIAR ▼` (`InventoryCleanButton`, un `DsMenuButton`; clave
`inv-clean`, menú `inv-clean-menu`) es el único lugar de las acciones en
lote. Opciones (`inv-clean-menu-<id>`):

- `Elegir a mano` (`pick`)
- `Desarmar Comunes / Mágicos / Raros (N)` (`salvage-<rareza>`)
- `Vender Comunes / Mágicos / Raros (N)` (`sell-<rareza>`)

Las opciones sin armas quedan grises (`optionReason` del
`DsMenuButton`) con el motivo de tooltip. Elegir una abre al costado la
confirmación (resumen, `Se destruyen:`, `CANCELAR` y el botón rojo); no
hay otro selector de modo ni de rareza en el detalle. En `Elegir a mano`
el detalle conserva DESARMAR / VENDER y los atajos `+ RAREZA`, con
componentes del sistema de diseño (`DsButton`).

Se quitó el slot `inv.clean_menu` (la caja con el menú debajo de la
grilla).

## Tests

- `test/features/inventory/ui_minimal_test.dart`: buscador + equipada
  fija en FUSIÓN (destino y origen), FORJA y COMPRAR; flujo de pasos de
  FUSIÓN y FORJA; LIMPIAR como único lugar de lotes.
