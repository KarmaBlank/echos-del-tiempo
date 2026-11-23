# Spec: UI mínima (v0.20.21, BUILD simple v0.20.24, armería v0.20.25)

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
- **FUSIÓN paso 2 (ACCIÓN)**: los grupos son `DsSectionHeader` (título
  + línea fina, sin marco; tooltip con qué hace el grupo, clave
  `bench-group-<grupo>`) y cada acción una `DsActionRow`
  (`bench-op-<op>`): ícono, nombre, una línea de qué hace y el costo a la
  derecha (`bench-op-why-<op>`). Las bloqueadas, grises con candado y el
  motivo en la línea; se pueden tocar igual (el paso 3 da el motivo
  completo). Ya no hay botón CONDENSAR en FUSIÓN.
- **FORJA**: `1 ARMA › 2 MEJORA › 3 CONFIRMAR` (`forge-crumb-<n>`).
  - Cabecera: nombre del arma (Título, color de rareza) + `DsTag` de
    rareza; `Forja n/tope` con cuadritos (`forge-cap`, tooltip con el
    tope); la pasiva en una línea (`forge-passive-note`: nombre en color
    de pasiva + cuándo sube; la descripción, con el mouse).
  - Habilidades: `SkillChips` como etiquetas (sin "?"); la ficha con el
    mouse o el foco.
  - Mejoras: `DsSectionHeader('Mejoras')` y una `DsActionRow` por
    estadística (`up-<uid>-<stat>`): ícono, nombre, la línea clave
    (`MAG 29 → 32`, `DsStatLine`: verde / rojo solo en los números),
    cuadritos n/5 y el costo (`forge-cost-<stat>`, `DsTag` dorado; rojo
    si no alcanza; `MAX` gris al tope). Tocarla solo la elige (borde
    dorado); bloqueada no se elige.
  - Nivel 2 / 3: el tooltip de la fila y `MÁS DETALLE` (`forge-more`, un
    `DsFold`, solo con una elegida) muestran bono, la pasiva que sube
    (`forge-passive-up-<stat>`) y qué cambia en batalla
    (`forge-impact-<stat>`).
  - Pie: `FORJAR` (`forge-confirm`, `DsButton` primario) gris con el
    motivo `Elegí una mejora` hasta elegir; `EQUIPAR` (`DsButton`) o la
    etiqueta `EQUIPADA`; teclas mínimas (`Enter Forjar`).
- **CONDENSAR** (pestaña propia desde v0.20.25, entre FUSIÓN y
  CONSUMIBLES): izquierda "Elegí material" (`DsActionRow` por receta,
  `condense-pick-<resultado>`, con lo que tenés), flecha, derecha "Se
  condensa en" (`condense-result`); con poco ancho, una debajo de la
  otra. Abajo: cantidad `×1` / `MÁX (n)` (`condense-<resultado>-1` /
  `-all`), la receta (`condense-summary`: `20 Esquirla + ₵100 → 1
  Cristal`), `Alcanza para n` (`condense-have-<resultado>`) y
  `CONDENSAR` (`condense-go`), gris con el motivo si no alcanza o en la
  Travesía.

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

## 6. Componentes de la ARMERÍA (mismo patrón en todas las pestañas)

| Qué | Componente |
|---|---|
| Acción elegible (mejora, acción de fusión, receta) | `DsActionRow` (sobre `DsListRow`): sin marco propio; elegida = borde dorado |
| Sección / grupo | `DsSectionHeader` (título Subtítulo + línea fina), nunca un panel enmarcado |
| Costo | `DsActionRow.costTag` (`DsTag`): dorado si alcanza, rojo si no, gris bloqueada |
| Bloqueada | gris (`DsColors.textDisabled`), candado como ícono y el motivo en la segunda línea (sin caja) |
| Cambio de un número | `DsStatLine` (flecha + verde / rojo solo en el número) |
| Detalle | tooltip `DsTooltipCard` (nivel 2) y `DsFold` `MÁS DETALLE` (nivel 3) |
| Botones del pie | `DsButton` (primario para la acción, compacto para EQUIPAR) |

## Tests

- `test/features/inventory/ui_minimal_test.dart`: buscador + equipada
  fija en FUSIÓN (destino y origen), FORJA y COMPRAR; flujo de pasos de
  FUSIÓN y FORJA; LIMPIAR como único lugar de lotes.
- `test/features/inventory/armory_panel_test.dart`: FORJA elegir / costo
  / bloqueada; `craft_bench_test.dart`: CONDENSAR como pestaña.
- Goldens: `test/features/inventory/goldens/craft_*_default_*.png`
  (FUSIÓN, FUSIÓN paso 2, FORJA, FORJA con una elegida, CONDENSAR).

## 7. BUILD: vista simple (v0.20.24)

La pestaña BUILD sigue los tres niveles (build_planner.md § 10):

| Nivel | Qué |
|---|---|
| 1 | Elegí una plantilla (nombre, una línea, dificultad, arma, APLICAR) o "Tu plan" + Qué hacer ahora (máximo 3 pasos, un botón cada uno) |
| 2 | Áreas plegables con medidor; los % y motivos de las armas en tooltip |
| 3 | EDITAR PLAN (avanzado): agregar y quitar metas, −5 / +5, ×, notas |

Reglas: palabras completas (la sigla solo entre paréntesis: "Fuerza
(FUE)"); verde = listo y dorado = falta, explicado por una leyenda de
una línea; nada se corta con "…" (`DsInfoRow` baja de línea). Piezas en
`lib/app/design/ds_guide.dart`: `DsStatusMark`, `DsLegend`, `DsInfoRow`,
`DsProgressFold`. Los pasos de habilidad, mod y tipo de arma pliegan
"DÓNDE LA CONSEGUÍS" con `DsFold`; el de ULT lleva IR A ULT (v0.22.1).

Tests: `test/game_engine/build_coach_where_test.dart`,
`test/features/build_planner/build_coach_ui_test.dart` (APLICAR,
pasos, controles escondidos, siglas, goldens `build_simple_*`).

## 8. TEXTOS: RESUMIDO y DETALLADO (v0.25.0)

Pedido del dueño: un ajuste global `TEXTOS` (settings.md § 3.10) con
dos modos para todas las descripciones del juego. Es local (no viaja
por la red ni cambia el protocolo).

| Modo | Qué se ve |
|---|---|
| RESUMIDO (por defecto) | una o dos líneas cortas, en palabras simples, con el número principal de cada efecto |
| DETALLADO | el texto de siempre: números, escalado, fórmulas y reglas finas |

### 8.1 Dónde aplica

Habilidades y ULT (`describeSkillMarkup` y lo que lo usa: menú de
batalla, fichas, ULT, Travesía), estados (`statusDescriptionOf`), mods
y afijos, implícitos y pasivas de arma (`modShort`), peso del arma,
nodos del árbol de pasivas (`passiveEffectsText`, keystones y
mecánicas), nodos de los árboles de oficios (`lifeNodeText`), pilas
(pociones, éteres, materiales) y los abonos del comerciante.

### 8.2 Reglas del RESUMIDO

- Como mucho 2 líneas cortas (≈ 90 letras cada una; `kShortMaxChars`).
- Empieza con el verbo: `Pega…`, `Cura…`, `Aplica…`, `Revive…`.
- Un número por efecto, el que importa (daño o cura con tus stats, o el
  % de tu ataque / magia si no hay stats; capas de un estado; turnos).
- Sin fórmulas ni jerga: nada de `×`, `=`, `ATQ`, `MAG`, `DEF`,
  `stack`, `máx.`, `c/u` (`kFormulaTokens`). Se dice `ataque`, `magia`,
  `defensa`, `capas`.
- Sin paréntesis con reglas: la regla va al DETALLADO.
- Mismas palabras para lo mismo en todo el juego (`a 1 enemigo`, `a
  todos los enemigos`, `al grupo`, `al aliado más herido`).
- La cabecera (nombre y costo) no cambia.

Cómo se arma: se genera desde los datos (efecto + valor principal,
`lib/features/combat/domain/skill_short_text.dart`), no se escribe a
mano habilidad por habilidad. Los textos que ya vienen escritos (mods,
mecánicas, keystones, oficios) pasan por `plainShort`
(`lib/core/text/plain_text.dart`): saca paréntesis y fórmulas, cambia
abreviaturas por palabras y se queda con la primera oración. Donde eso
lee mal se escribe a mano (estados, invocaciones, peso, abonos).

### 8.3 MÁS DETALLE en RESUMIDO

Un tooltip en RESUMIDO puede traer el texto DETALLADO de ese mismo
objeto plegado al pie: `▸ MÁS DETALLE` (`RetroTooltip.detail`,
`DsTooltipCard.detail`). Se abre con clic sobre el tooltip fijado o
manteniendo Alt (como los demás plegables). En DETALLADO no aparece.

### 8.4 Implementación

- `TextDetail` (`lib/core/text/text_detail.dart`, Dart puro):
  `summary` / `full`, `TextDetail.current` (el modo vigente),
  `TextDetail.run(modo, f)` y `fullIfSummary(f)` para el MÁS DETALLE.
- `TextDetailScope` (arriba de la app, en `EcosApp`) pone el ajuste en
  `TextDetail.current`; al cambiar, la app se vuelve a armar entera.
- Fuera de la app (tests de dominio) el modo es DETALLADO: los textos
  de siempre.

### 8.5 Quedan solo en DETALLADO (por ahora)

- Textos escritos en el menú de batalla que no salen de un armador
  (Defender, Atacar, Liberar, dúos, Éter, Pasar turno).
- Plan de build y asistente (build_planner.md): ya usan palabras
  completas.
- Bestiario, misiones, ascensión (kit y requisitos), XP, logros, la
  ayuda de prefijos y sufijos y los textos de la Travesía fuera de las
  habilidades y pasivas.
- El panel de detalle del menú de batalla no tiene MÁS DETALLE (no es
  un tooltip): en RESUMIDO muestra el texto corto.

Tests: `test/features/settings/text_detail_test.dart` (todas las
habilidades y ULT del catálogo, estados, pasivas, mecánicas y mods
cumplen § 8.2; el tooltip de una habilidad cambia al cambiar el
ajuste; `game.json` viejo carga RESUMIDO y se guarda).
