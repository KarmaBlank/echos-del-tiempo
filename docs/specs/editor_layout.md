# Spec (APROBADO): Layout editable desde el Editor

Pedido: en el Editor (admin) poder ver TODAS las pantallas y mover su
disposición: una fila entera de botones (p. ej. en el ALIJO, la fila
`AL ALIJO > · MOVER TODO AL ALIJO · ELEGIR` bajo consumibles/materiales)
o un botón suelto, a otra región/posición, sin perder nunca lo
responsivo. Se aplica a todas las pantallas.

Estado: **APROBADO** por el dueño con las 6 recomendaciones de § 5
(ver § 5, "Decisiones"). Fases 1–3 implementadas en v0.20.0 (§ 6).

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

## 5. Decisiones del dueño (antes "preguntas abiertas")

1. **Solo regiones y orden**, más reglas por corte. Nada de píxeles.
2. **Solo publicar** (para todos, como sprites/fx). Sin preferencias por
   jugador en esta etapa.
3. **El editor no crea regiones**: usa las que declara cada pantalla;
   una región nueva se pide y se agrega en código.
4. **Orden tras el ALIJO**: INVENTARIO y fusión/forja/condensar, luego
   PERSONAJE.
5. **Ocultar** solo lo marcado `hideable`; nunca acciones únicas.
6. **Cuatro cortes globales** en anchos de texto (`narrow < 60 tx ≤
   medium < 90 tx ≤ wide < 140 tx ≤ ultra`; 1 tx = 10 px lógicos al
   100 % y crece con el tamaño de letra). Se mide el ancho de la raíz de
   la pantalla, no la ventana.

## 6. Implementación (v0.20.0, fases 1–3)

- **Dart puro** en `lib/core/layout/`: `layout_doc.dart` (`LayoutDoc`,
  `SlotPlacement`, `SlotRule`, `LayoutBreakpoints`; `parse`/`encode`
  estables, `resolve(bp)` cacheado, `move`/`withRule` inmutables),
  `layout_spec.dart` (`LayoutScreenSpec`, `LayoutRegionSpec`,
  `LayoutSlotSpec` con `movable`, `hideable`, `allowedRegions`,
  `group`, `interactive`, `gap`), `layout_validator.dart`
  (`validateStatic` y `validateGeometry`: fuera de la ventana, solapes
  entre hermanos, clic ≥ 32, orden de foco = orden visual por
  contenedor).
- **Grupos como contenedores**: un hijo de grupo tiene `region: <id del
  grupo>`; sacarlo del grupo es moverlo a una región. En el YAML los
  hijos van en `children:` (forma corta).
- **`LayoutCatalog`** (`layout_catalog.dart`): único lector. Override
  local válido → YAML del repo válido → defecto en código; lo inválido
  se ignora con log. `reload(screen)` = recarga en caliente (avisa a
  los `DsLayoutHost`). Lo cargan `main_p2p`, `main_lan` y `main_dev`
  (este con `overrides/layouts/`); el Editor usa su propio catálogo que
  lee el repo en disco.
- **Overrides** (`layout_overrides_io.dart`, stub web):
  `overrides/layouts/<screen>.layout.yaml`; PUBLICAR AL REPO escribe
  `assets/layouts/<screen>.layout.yaml` y la entrada en
  `layout_manifest.yaml` (carpeta registrada entera en pubspec). El
  **paquete de arte** lleva `layouts:` (EXPORTAR/IMPORTAR de Visuales).
- **`DsLayoutHost`** (`lib/app/design/ds_layout_host.dart`, template):
  `frame(context, box, regions)` lo da la pantalla (su lógica de
  apilado/escala) y pide `regions.region('left')`; el host arma cada
  región/grupo según eje y `gap` del slot. `DsLayoutHooks` (solo el
  Editor) envuelve slots y contenedores; en el juego es `null`.
- **ALIJO** (`stash_layout.dart` + `stash_board.dart`): regiones
  `header/left/right/footer`; slots `stash.title`, `.equipped`,
  `.inventory_label`, `.search_char`, `.inventory_grid` (fijo),
  `.stacks`, `.stash_header`, `.stash_tabs`, `.search_stash`,
  `.stash_grid` (fijo), `.eco_note`, `.actions(.transfer|.move_all|
  .pick)`, `.status` (solo `header`/`footer`). El árbol manual se borró;
  el golden `test/features/characters/goldens/stash_default_*.png`
  (generado con el árbol viejo) confirma píxel a píxel que el YAML por
  defecto reproduce la pantalla. En modo ELEGIR, `transfer` muestra la
  cuenta + MOVER ELEGIDOS y `move_all` CANCELAR.
- **Editor → LAYOUT** (`layout_page.dart`, `layout_editor_controller.dart`,
  `layout_previews.dart`): galería de todas las pantallas (las no
  migradas, "sin vista previa"), datos de ejemplo sin red; ventana
  1280×720 / 1920×1080 / 2560×1440 / 800×600 / 600×900 / personalizada,
  texto 100/125/150/200 %; selección, arrastre con guías (línea verde
  de inserción, región verde o roja tachada), teclado (flechas, Tab,
  Esc, Ctrl+Z/Ctrl+Y), propiedades por corte (BASE o un corte; HEREDA /
  SOBRESCRITO), árbol con FIJO, validación en vivo y VALIDAR TODO,
  GUARDAR (no con errores), RESTAURAR, RECARGAR, PUBLICAR AL REPO.
  Sin tickers: se reconstruye solo por cambios del controlador; el
  arrastre solo repinta las guías (`ValueNotifier`).
- **Desbordes en el Editor**: además de "fuera de la ventana", un slot
  que se sale del rectángulo de su región cuenta como desborde. En los
  tests, además, `takeException` atrapa los `RenderFlex overflowed`.
- **INVENTARIO (fase 4, v0.20.1)** (`inventory_layout.dart`,
  `InventoryTabLayout` + `inventory_tab.dart`): regiones `toolbar`
  (wrap, separación xs), `head` (arriba de la grilla; en ancho, arriba
  de la columna del costado), `grid` (fija) y `foot` (debajo de la
  grilla; en ancho, debajo de `head`). Slots `inv.owners`, `inv.search`,
  `inv.search_clear`, grupo `inv.tools(.sort|.clean|.stash)`,
  `inv.equipped`, `inv.stacks`, `inv.summary`, `inv.selection`,
  `inv.clean_menu`; fijos `inv.notes` y `inv.grid`. La lógica de modos
  (ancho / medio / angosto), la escala de las casillas y la franja de
  CAMBIOS quedan en el template. La barra y el cuerpo son dos
  `DsLayoutHost` sobre el mismo doc (el cuerpo mide su propio ancho).
  Golden `test/features/inventory/goldens/inventory_default_*.png`
  (árbol viejo) == YAML por defecto; árbol manual borrado. Vista previa
  en el Editor con una sesión local de ejemplo (perfil en memoria, sin
  reloj ni red).
- **Host, agregados de fase 4**: `LayoutRegionSpec.spacing` (separación
  de una región wrap), `LayoutSlotSpec.lead` (espacio extra antes del
  slot en un wrap: separadores de barra), `groupGap` (entre hijos de un
  grupo en fila/wrap), `gap` acepta `none` o píxeles (`'6'`). En el
  juego, un grupo sin hijos visibles no ocupa lugar.
- **FUSIÓN / FORJA / CONDENSAR (fase 4, v0.20.2)** (`craft_layout.dart`):
  - `craft.fuse` (`FuseLayout` + `craft_bench.dart`): regiones `crumbs`,
    `summary`, `materials` (barra de arriba: en fila, o apiladas con
    texto ENORME o poco ancho) y `footer` (pie del detalle del paso 1
    ARMA, wrap a la derecha). Slots `fuse.crumbs`, `fuse.summary`,
    `fuse.materials`, `fuse.keys`, grupo `fuse.actions(.condense|.next)`.
    Grillas y tarjetas de los 3 pasos son del template (fijas).
  - `craft.forge` (`ForgeLayout` + `ForgeTab` en `shop_sections.dart`):
    regiones `detail` y `footer`; slots `forge.title`, `forge.skills`,
    fijo `forge.upgrades` (tarjetas de forja) y grupo
    `forge.actions(.keys|.equipped|.equip)`. EQUIPADA (aviso) y EQUIPAR
    (botón) son dos slots: solo se ve uno, y el aviso no cuenta como
    objetivo de clic.
  - `craft.condense` (`CondenseLayout` + `condense_panel.dart`): regiones
    `head`, `recipes` (fija) y `confirm` (dentro de la tarjeta de
    confirmación; solo con una elección pendiente, o siempre en el
    Editor). Slots `condense.title` (con ‹ VOLVER), `condense.intro`,
    `condense.summary`, `condense.error`, grupo
    `condense.actions(.go|.cancel)`.
  - Goldens `test/features/inventory/goldens/craft_*_default_*.png`
    (árbol viejo) == YAML por defecto; árboles manuales borrados.
    Matriz 5 tamaños × 3 textos por pantalla (por defecto y con grupo +
    botón suelto movidos) en `craft_layout_matrix_test.dart`. Arreglos
    que destapó la matriz: la barra de la mesa ya no desborda con texto
    grande o ventana angosta (los materiales se parten en líneas) y la
    fila de nivel de las tarjetas de forja tampoco.
- **Host, agregados (v0.20.2)**: `LayoutRegionSpec.align` y
  `runSpacing` (un pie a la derecha como el de `PanelDetail`),
  `LayoutSlotSpec.groupRunSpacing`. Una región cuyos slots son grupos
  sin hijos visibles cuenta como vacía (`isEmpty`).
- **PUBLICAR AL REPO**: el manifest se edita con
  `core/data/manifest_text.dart` (robusto a CRLF y a comentarios tras
  la sección; une secciones repetidas en una; idempotente). Lo usan
  layouts, fx, sfx y sprites. Al publicar un layout se conserva el
  comentario de cabecera que ya tenía el YAML del repo.
- **ATRIBUTOS sin desbordes (v0.20.3)**: la fila de atributo deja los
  anchos fijos cuando no entran (sigla, valor y ★ en un wrap; botones a
  la derecha o debajo), con poco ancho la VISTA PREVIA va debajo y
  `DsSectionHeader` achica la línea en vez de desbordar
  (`attributes_overflow_test.dart`: 5 tamaños × 4 textos).
- **PERSONAJE (fase 5, v0.20.3)** (`character_layout.dart`,
  `CharacterLayout` + `character_panel.dart`): regiones `toolbar` (wrap,
  barra de arriba del contenido; hoy solo ATRIBUTOS) y `actions` (pie
  del marco, wrap a la derecha como `PanelFrame.actions`). Slots
  `char.points`, grupo `char.attr_actions(.respec|.undo|.confirm)`,
  `char.attr_reason` y `char.close`. Dos `DsLayoutHost` sobre el mismo
  doc (barra y pie). Con muy poco alto la barra se desplaza (hasta la
  mitad del alto). Golden `test/features/characters/goldens/
  character_attributes_*.png` (árbol viejo) == YAML por defecto; matriz
  en `character_layout_matrix_test.dart`; vista previa en el Editor con
  la sesión de ejemplo.
- **Pendiente (fase 5+)**: el título, la fila de pestañas (con la barra
  de miembros) y el contenido de las pestañas ÁRBOL (árbol fijo; la
  columna del hito como grupo), ULT (con su vista previa, sin
  reconstruir por frame), HAZAÑAS, BESTIARIO y BUILD siguen siendo
  template; después, el resto de las pantallas.
