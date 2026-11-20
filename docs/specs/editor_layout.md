# Spec (BORRADOR, para revisar con el dueño): Layout editable desde el Editor

Pedido: en el Editor (admin) poder ver TODAS las pantallas y mover su
disposición: una fila entera de botones (p. ej. en el ALIJO, la fila
`AL ALIJO > · MOVER TODO AL ALIJO · ELEGIR` bajo consumibles/materiales)
o un botón suelto, a otra región/posición, sin perder nunca lo
responsivo. Se aplica a todas las pantallas.

Este documento es solo spec: no cambia el juego.

## 1. Estado actual

- **Atómico** (design_system.md § 6 bis): átomos `ds_tokens.dart`
  (`DsSpace`, `DsText`, `DsColors`), `ds_button.dart`, `ds_focus.dart`;
  moléculas/organismos en `lib/app/design/ds_components.dart`
  (`DsTabBar`, `DsToolbar`, `DsCard`, `DsSearchField`, `DsListRow`,
  `DsSectionHeader`, `DsFold`, ...); marco de panel en
  `lib/app/theme/panel_frame.dart` (`PanelFrame`, con `LayoutBuilder`).
  No hay "templates" como clase: cada pantalla compone a mano su árbol.
- **Disposición en código.** Cada pantalla decide con `Row`/`Column`/
  `Wrap` + `LayoutBuilder` y una función pura de breakpoint:
  - ALIJO: `stashLayout(w, sideMin)` en
    `lib/features/characters/presentation/stash_board.dart` (lado a
    lado si entran las dos grillas a escala 1, si no apilado; escala de
    casilla en cuartos hasta ×2). La fila de acciones es un `Wrap` fijo
    al pie (`_actions()`, claves `stash-deposit` / `stash-withdraw`,
    `stash-move-all`, `stash-pick`).
  - INVENTARIO: `inventoryLayout` + `_withToolbar` en
    `lib/features/inventory/presentation/inventory_tab.dart`.
  - HUD del mapa: `world_hud.dart` (`LayoutBuilder` raíz, línea ~120).
  - Batalla: `battle_screen.dart` (3 `LayoutBuilder`),
    `battle_command_window.dart`, `battle_hud.dart`.
  - BUILD: `build_planner_view.dart`, `template_view.dart`.
  - Otros: `title_screen.dart`, `achievements_screen.dart`,
    `bestiary_screen.dart`, `craft_bench.dart`, `consumables_bar.dart`,
    `loot_filter_tab.dart`, `character_panel.dart`, `atlas_view.dart`.
- **Breakpoints**: no hay escala global; cada pantalla usa umbrales
  propios derivados del ancho real y de `RetroType.width(context, n)`
  (que escala con el tamaño de texto). Es correcto (responde al tamaño
  de letra), pero no es configurable.
- **Galería** `lib/app/design/gallery/ds_gallery_screen.dart` muestra
  componentes sueltos con ejemplos (`ds_examples.dart`), no pantallas.
- **Editor** (game_editor.md § 3, § 7): áreas Sprites y Animaciones con
  overrides locales (§ 4.2), recarga en caliente, paquete de arte y
  PUBLICAR AL REPO. Ese circuito es el que se reutiliza acá.

Consecuencia: mover un botón hoy es editar Dart en la pantalla; no hay
ids estables de "grupo" ni de "slot", solo `ValueKey` de test.

## 2. Modelo propuesto: layout como datos

### 2.1 Conceptos

- **Pantalla** (`screen id`): `stash`, `inventory`, `world_hud`,
  `battle`, `character.*` (una por pestaña), `title`, `lobby`,
  `craft.fuse|forge|condense`, `shop`, `settings`, `achievements`,
  `build`, ...
- **Región**: contenedor con nombre que la pantalla expone (p. ej.
  `stash`: `left`, `right`, `footer`, `header`). La región define su
  eje (`row`/`column`/`wrap`/`grid`) y su comportamiento responsivo.
  Las regiones son parte del **template** y las declara el código.
- **Slot**: unidad movible con id estable `pantalla.grupo[.elemento]`
  (p. ej. `stash.actions`, `stash.actions.move_all`). Un slot es un
  organismo, molécula o átomo ya existente: el layout solo decide
  **dónde** va, nunca **qué hace**.
- **Grupo**: slot que contiene slots (la fila de acciones). Se puede
  mover entero o sacarle un hijo a otra región.

### 2.2 Archivo

`assets/layouts/<screen>.layout.yaml` (uno por pantalla, declarado en
`assets/layouts/layout_manifest.yaml`, igual que sprites/fx):

```yaml
screen: stash
version: 1
regions:
  header: {axis: row, wrap: true}
  sides:  {axis: row, stackBelow: 2 * stash.gridSide + gap}   # apila en angosto
  left:   {parent: sides}
  right:  {parent: sides}
  footer: {axis: wrap, align: start}
slots:
  - {id: stash.inventory_grid, region: left,  order: 0}
  - {id: stash.stash_tabs,     region: right, order: 0}
  - {id: stash.stash_grid,     region: right, order: 1}
  - id: stash.actions
    region: footer
    order: 0
    children: [stash.actions.transfer, stash.actions.move_all, stash.actions.pick]
breakpoints:            # en "anchos de texto" (escalan con el tamaño de letra)
  narrow:               # < 60 tx
    stash.actions: {region: footer, axis: column, stretch: true}
    stash.actions.pick: {hide: false}
```

Unidades: nunca píxeles absolutos; tamaños en `DsSpace`/anchos de
texto (`RetroType.width`) para que escalen con la letra.

### 2.3 Reglas responsivas permitidas

Por slot o región y por breakpoint (`narrow`, `medium`, `wide`,
`ultra`; umbrales en anchos de texto, globales en `ds_tokens.dart`):
`region`/`order`, `axis` (row/column/wrap), `stack` (apilar hijos),
`hide` (solo si `hideable: true` en el catálogo), `minWidth`,
`stretch`, `align`. Nada de `x/y`.

### 2.4 Qué se puede mover y qué no

El código registra cada slot en un **catálogo de slots** por pantalla
(`LayoutSlotSpec`: id, widget builder, `movable`, `hideable`,
`allowedRegions`, `minSize`, `focusOrderHint`):

- **Movibles**: filas de botones, botones sueltos, barras de búsqueda,
  encabezados, paneles de detalle, consumibles, leyendas.
- **Fijos (`movable: false`)**: lo atado a lógica o a geometría del
  juego: grilla del tablero de batalla, timeline de turnos, el mapa,
  grillas de casillas cuyo tamaño calcula `stashLayout`, el árbol de
  pasivas, diálogos de confirmación, toasts. Se ven en el árbol pero
  bloqueados.
- **Restricción por región**: `allowedRegions` evita absurdos (el
  botón ELEGIR no puede ir al HUD de otra pantalla; los slots no
  cruzan pantallas).

### 2.5 Validación (nunca se rompe)

`LayoutValidator` (Dart puro, en `game_engine/`-estilo, testeable):

1. Estático: ids existen, sin duplicados, regiones válidas,
   `allowedRegions`, ningún `movable: false` desplazado, ningún slot
   obligatorio oculto.
2. Geométrico: se renderiza la pantalla con datos de ejemplo en cada
   tamaño de la matriz (§ 3) y tamaño de texto (100 %/150 %/200 %) y se
   comprueba: sin overflow (`RenderFlex overflowed` = error), nada fuera
   de la ventana, sin solapes entre slots hermanos, objetivo de clic
   ≥ 32×32 lógicos (accessibility.md), orden de foco = orden visual
   (lectura izq→der, arriba→abajo) y todo alcanzable por teclado.
3. Un layout que no valida **no se puede guardar ni publicar**; al
   cargar un override inválido en el juego se ignora y se usa el del
   repo (con log).

### 2.6 Carga, overrides, distribución

Igual que sprites/fx (game_editor.md § 4): prioridad override local
(`overrides/layouts/<screen>.layout.yaml`, solo flavor admin/dev) →
asset del repo → **layout por defecto en código** (el que hoy existe,
reexpresado como datos; si falta el YAML, la pantalla se ve igual que
hoy). `LayoutCatalog` es la única clase que lee los archivos;
`LayoutCatalog.reload(screen)` = recarga en caliente. Entra en el
paquete de arte (EXPORTAR/IMPORTAR) y en PUBLICAR AL REPO.

### 2.7 Render

Organismo nuevo `DsLayoutHost(screen:, slots:)` (template): recibe el
catálogo de slots de la pantalla + el `LayoutDoc` resuelto, y dentro
de un `LayoutBuilder` elige breakpoint y arma `Row`/`Column`/`Wrap`.
La pantalla deja de componer a mano su árbol y solo entrega builders.
Sin lógica de juego en el host; sin redondeos (estilo DS).

## 3. Editor: área LAYOUT

Nueva pestaña junto a Sprites/Animaciones
(`lib/features/admin/presentation/editor/layout_page.dart` +
`layout_editor_controller.dart`).

- **Galería de pantallas**: lista de TODAS las pantallas del manifest,
  cada una renderizada con **estado falso** (fixtures en
  `test/fixtures`-estilo: perfil, alijo, batalla en curso, mapa) y
  `NetSession` falso: sin red, sin Firestore. Una pantalla sin fixture
  aparece "sin vista previa" (cuenta como deuda de migración).
- **Lienzo**: la pantalla dentro de un marco de tamaño elegido:
  1280×720, 1920×1080, 2560×1440, angosto (≈ 800×600 y 600 ancho) y
  personalizado; tamaño de texto 100/125/150/200 %.
- **Selección**: clic = slot más interno; clic de nuevo/Alt+clic o
  tecla `Esc` = sube al grupo padre. Contorno y nombre del slot.
- **Arrastrar**: a otra región o posición; guías de inserción (línea
  entre hermanos, región resaltada si es destino permitido, tachada si
  no). Teclado: flechas reordenan, `Tab` cambia región.
- **Panel de propiedades** del slot por breakpoint (eje, apilar,
  ocultar, mínimo) con indicador "hereda / sobrescrito".
- **Árbol de slots** (regiones → slots), con candado en los fijos.
- **Validación en vivo**: lista de errores/avisos por tamaño de la
  matriz; "VALIDAR TODO" corre la matriz completa.
- **Deshacer/rehacer**, RESTAURAR (volver al del repo), RECARGAR,
  guardar override, EXPORTAR/IMPORTAR, PUBLICAR AL REPO (mismo diálogo
  que sprites).

## 4. Migración

Orden propuesto (una pantalla por PR, cada una con su fixture):

1. **Infra**: `LayoutDoc` + parser + `LayoutValidator` + `LayoutCatalog`
   + `DsLayoutHost` + tests. (~2–3 días)
2. **ALIJO (piloto)**: regiones `header/left/right/footer`, slots
   `stash.actions(.transfer|.move_all|.pick)`, buscador, pestañas. El
   YAML por defecto reproduce exactamente lo de hoy (golden igual).
   Área LAYOUT mínima: galería con 1 pantalla, selección, mover entre
   regiones, validar, override. (~3–4 días)
3. Resto del editor LAYOUT (árbol, propiedades por breakpoint,
   deshacer, paquete/publicar). (~3 días)
4. Pantallas de menú: inventario, fusión/forja/condensar, tienda,
   PERSONAJE y pestañas, hazañas, ajustes, build. (~0,5–1 día c/u)
5. Título, lobby, HUD del mapa. (~1 día c/u)
6. Batalla al final (más acoplada a la animación; solo HUD/comandos
   movibles, tablero y timeline fijos). (~2 días)

Total orientativo: 4–5 semanas de trabajo efectivo.

Riesgos:
- **Rendimiento**: resolver YAML por frame. Mitigación: `LayoutDoc`
  inmutable resuelto al cargar; por build solo se elige breakpoint.
- **Duplicación**: convivir pantalla "a mano" y "por datos". Regla:
  al migrar una pantalla, se borra su árbol manual en el mismo PR.
- **Tests de layout frágiles**: los tests actuales buscan por
  `ValueKey`; los slots conservan esas claves.
- **Flexibilidad excesiva**: un layout válido puede ser feo. La
  validación garantiza "no roto", no "lindo"; por eso solo regiones y
  orden (§ 5, P1).
- **Lógica escondida en la disposición** (p. ej. `_wide` del alijo se
  usa para escalar casillas): esa lógica queda en el slot/región, no
  en el YAML.

Tests:
- Unit: parser, merge override→repo→defecto, validador estático.
- Widget: por pantalla migrada, matriz tamaños × texto sin overflow,
  sin solapes, objetivos mínimos, orden de foco.
- Golden: layout por defecto == pantalla actual antes de migrar.
- Editor: mover `stash.actions` a `header` y `stash.actions.pick` a
  `right` → valida, se guarda, recarga en caliente, deshacer vuelve.

## 5. Preguntas abiertas para el dueño

1. **¿Mover libre por píxeles o solo entre regiones/orden?**
   Recomiendo regiones + orden + reglas por breakpoint. Por píxeles
   rompe lo responsivo y el tamaño de texto.
2. **¿Cambios para todos (publicar) o también preferencia del
   jugador?** Recomiendo solo publicar (como sprites/fx) en esta
   etapa; preferencia por jugador más adelante, limitada a ocultar o
   reordenar dentro de la misma región.
3. **¿Puede el editor crear regiones nuevas o solo usar las que
   declara cada pantalla?** Recomiendo solo las declaradas; si hace
   falta una región nueva, se pide y se agrega en código.
4. **¿Qué pantallas primero tras el ALIJO?** Recomiendo INVENTARIO y
   fusión/forja/condensar (mismo patrón grilla + fila de acciones),
   luego PERSONAJE.
5. **¿Se permite ocultar elementos?** Recomiendo solo los marcados
   `hideable` y nunca acciones únicas (sin otra forma de hacerlas).
6. **¿Breakpoints globales o por pantalla?** Recomiendo cuatro
   globales en anchos de texto, con ajuste fino por región si la
   validación lo exige.
