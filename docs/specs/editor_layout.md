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

### 2.8 Perillas de pantalla (v0.20.6)

Algunas pantallas tienen números de presentación que no son slots
(cámara, márgenes). Las declara el código en
`LayoutScreenSpec.params` (`LayoutParamSpec`: clave, etiqueta, defecto,
mínimo, máximo, paso, ayuda) y el YAML guarda solo las que pisan el
defecto:

```yaml
params:
  camera_zoom_out: 1
  float_top_margin: 8
```

`LayoutScreenSpec.param(doc, clave)` devuelve el valor acotado a su
rango (claves desconocidas o fuera de rango nunca rompen). En Editor →
LAYOUT, la sección PERILLAS del panel derecho muestra `-` valor `+` y
DEFECTO; volver al defecto la saca del YAML. Guardar / publicar /
deshacer funcionan igual que con los slots. Hoy: BATALLA
(`camera_zoom_out`, `float_top_margin`; battle_presentation.md
§ "Textos flotantes").

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
  `inv.equipped`, `inv.stacks`, `inv.summary`, `inv.selection`
  (v0.20.21: sin `inv.clean_menu`, LIMPIAR es un `DsMenuButton`); fijos `inv.notes` y `inv.grid`. La lógica de modos
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
- **BATALLA (fase 6, v0.20.6)** (`battle_bar_layout.dart`,
  `BattleBarLayout` + `BattleBarRow`): la barra de abajo en una fila,
  lugares `top`, `card`, `categories`, `actions`, `description` (el
  template fija anchos y pesos; dos slots en un lugar se apilan). Slots
  `battle.card`, `battle.categories`, `battle.actions`,
  `battle.description`, `battle.waiting`. Corte `narrow`: la tarjeta a
  `top`. Vista previa: la batalla entera con una pelea de ejemplo (motor
  puro). La escena y la barra del grupo con compañeros son template.
  Matriz en `battle_bar_layout_test.dart`; detalle en
  battle_presentation.md § "Barra de abajo (v0.20.6)".
- **Perillas (§ 2.8, v0.20.6)**: ver abajo.
- **Pendiente (fase 5+)**: el título, la fila de pestañas (con la barra
  de miembros) y el contenido de las pestañas ÁRBOL (árbol fijo; la
  columna del hito como grupo), ULT (con su vista previa, sin
  reconstruir por frame), HAZAÑAS, BESTIARIO y BUILD siguen siendo
  template; después, el resto de las pantallas.


---

# Parte II (PROPUESTA): editor visual de composición con datos

Estado: **PROPUESTA**, pendiente de las decisiones del dueño (§ II.12).
Maqueta: `docs/preview/layout_editor_mockup.png` (generada por
`test/design/layout_editor_mockup_test.dart` con `LAYOUT_MOCKUP=1`; es
una maqueta estática con los componentes Ds reales, no el editor).

Pedido: en el Editor, armar pantallas arrastrando componentes del
sistema de diseño (Átomos / Moléculas / Organismos / Templates) a la
pantalla, configurar sus perillas y **de dónde salen sus datos**
("inventario del jugador", "encargos del NPC", "stock de la tienda"),
guardar el resultado como datos por pantalla y que el juego dibuje esas
pantallas desde el archivo, con la pantalla en código como respaldo.
Por juego del monorepo (Mundo y Travesía por separado).

## II.1 De dónde partimos (no se reabre)

Hoy conviven dos editores, y esta Parte II los **une**, no agrega un
tercero:

| | Parte I (LAYOUT, slots) | screen_editor.md (PANTALLAS) |
|---|---|---|
| Modelo | `LayoutDoc`: slots en regiones, sin x/y | `ScreenLayout`: elementos con x/y/anclas |
| Componentes | slots que arma el código | `DsRegistry` (paleta por nivel) |
| Datos | ninguno (el slot ya los trae) | `ScreenBindingSpec`: acciones, fuentes (sin tipo), huecos |
| Uso | ALIJO, INVENTARIO, forja, PERSONAJE, batalla | TÍTULO |

Lo que falta para la visión del dueño: (a) árbol anidado (templates con
hijos), (b) fuentes de datos **tipadas** con validación, (c) acciones
con argumentos (comprar *este* ítem), (d) perillas por componente
declaradas como esquema, (e) un formato único por pantalla y por juego.

Decisión de diseño: el modelo nuevo es un **árbol de nodos con flujo
(sin x/y)** como la Parte I, porque lo responsivo y el tamaño de texto
ya están resueltos ahí. Las anclas de screen_editor.md quedan como un
tipo de contenedor más (`stage`) para pantallas tipo póster (TÍTULO).

## II.2 Modelo de datos

Dart puro en `lib/core/ui_layout/` (sin Flutter: testeable con
`flutter test` sin UI).

### II.2.1 `LayoutNode`

```yaml
# assets/layouts/<game>/<screen>.ui.yaml
schema: 1                 # versión del formato (§ II.7)
game: world               # world (Mundo) | voyage (Travesía)
screen: npc_shop
template: transfer        # de qué template partió (solo informativo)
root:
  id: root
  component: DsTransferTemplate
  knobs: {split: 0.5, gap: md}
  slots:                  # huecos con nombre del componente padre
    left:
      - id: inv_search
        component: DsSearchField
        knobs: {hint: ui.common.search, width: 24tx}
      - id: inv_grid
        component: DsGridDetailLayout
        knobs: {columns: 6, cell: normal}
        bind:
          items: player.inventory | filter(search: inv_search.text)
        on:
          activate: shop.sell(item: $item, qty: 1)
    right:
      - id: stock_tabs
        component: DsTabBar
        bind: {tabs: shop.categories}
      - id: stock_grid
        component: DsGridDetailLayout
        bind: {items: shop.stock | where(category: stock_tabs.value)}
        on: {activate: shop.buy(item: $item, qty: 1)}
    footer:
      - id: actions
        component: DsActionRow
        children:
          - {id: buy,  component: DsButton, knobs: {label: ui.shop.buy, kind: primary},
             on: {press: shop.buy(item: stock_grid.selected, qty: 1)}}
          - {id: sell, component: DsButton, knobs: {label: ui.shop.sell},
             on: {press: shop.sell(item: inv_grid.selected, qty: 1)}}
breakpoints:              # mismos 4 cortes globales de la Parte I (§ 5.6)
  narrow:
    root: {knobs: {stack: true}}
```

- `id`: estable, único en la pantalla, `snake_case`. Es lo que usan los
  tests (`ValueKey('ui.<screen>.<id>')`), el foco y los bindings.
- `component`: id del registro (§ II.2.2). Desconocido = el nodo se
  dibuja como `DsMissing` en el editor y se **omite** en el juego (log).
- `slots` vs `children`: un componente declara si tiene huecos con
  nombre (`left`, `right`, `footer`, `detail`) o una lista simple.
- `knobs`: solo claves del esquema del componente.
- `bind`: entrada → expresión de datos (§ II.2.3).
- `on`: evento del componente → acción (§ II.2.4).
- `breakpoints`: parches por corte (solo `knobs`, `hide`, orden).

### II.2.2 Registro de componentes con esquema de perillas

Se extiende `DsComponentSpec` (`lib/app/design/registry/ds_registry.dart`)
en lugar de crear otro registro:

```dart
class DsComponentSpec {
  final String id;                 // 'DsGridDetailLayout'
  final DsLevel level;             // atom | molecule | organism | template
  final List<DsKnob> knobs;        // esquema
  final List<DsInput> inputs;      // entradas ligables, tipadas
  final List<DsEvent> events;      // eventos que emite, con su payload
  final DsChildren children;       // none | list | slots(['left','right'])
  final Widget Function(DsBuildCtx) build;
  final String? galleryExample;    // el mismo ejemplo de ds_examples.dart
}
```

Tipos de perilla (`DsKnob`), cerrados, sin valores libres:

| Tipo | Ejemplo | Valores |
|---|---|---|
| `enumKnob` | `kind`, `size`, `variant` | los del componente |
| `colorToken` | `accent`, `border` | solo nombres de `DsColors` (`selected`, `danger`, `success`, ...) |
| `textStyle` | `style` | `DsTextStyleId` (display/title/subtitle/body/detail) |
| `space` | `gap`, `padding` | `DsSpace` (xs/sm/md/lg/xl) |
| `intRange` | `columns` | min/max/paso del componente |
| `width` | `width` | anchos de texto (`24tx`) o `fill`; nunca px |
| `textKey` | `label`, `hint` | clave i18n existente (§ II.9) |
| `bool` | `stack`, `hideable` | |

El esquema vive al lado del componente (`ds_registry_defaults.dart`) y
lo usan a la vez la paleta, el panel de propiedades, el validador y el
parser. Un componente nuevo que se registre aparece solo en la paleta.

### II.2.3 Fuentes de datos tipadas y expresiones de binding

Cada pantalla (por juego) registra un `ScreenContract` (reemplaza y
amplía `ScreenBindingSpec`):

```dart
ScreenContract(
  game: Game.world, screen: 'npc_shop', label: 'Tienda de NPC',
  params: {'npc': UiType.npcId},
  sources: [
    DataSource('player.inventory', UiType.list(UiType.itemStack), label: 'Inventario del jugador'),
    DataSource('shop.stock',       UiType.list(UiType.itemStack), label: 'Stock de la tienda'),
    DataSource('shop.categories',  UiType.list(UiType.tab)),
    DataSource('player.gold',      UiType.int),
  ],
  actions: [
    ActionSpec('shop.buy',  {'item': UiType.itemStack, 'qty': UiType.int}, label: 'Comprar'),
    ActionSpec('shop.sell', {'item': UiType.itemStack, 'qty': UiType.int}, label: 'Vender'),
  ],
  sample: npcShopSample,          // datos de ejemplo para el editor y la verificación
)
```

- **Tipos** (`UiType`): un conjunto chico y cerrado: `int`, `text`,
  `bool`, `itemStack`, `quest`, `recipe`, `npc`, `tab`, `cost`,
  `list<T>`. Cada componente declara el tipo de sus entradas
  (`DsGridDetailLayout.items: list<itemStack | recipe | quest>`).
- **Fuentes**: implementadas en `features/<x>/presentation` como
  `ValueListenable<T>` (o `Stream`) sobre los casos de uso existentes;
  el layout nunca llama al dominio directo.
- **Expresiones**: gramática mínima, **no** un lenguaje:
  `fuente[.campo] ( | operador(args) )*`. Operadores cerrados:
  `filter(search:)`, `where(campo: valor)`, `sort(campo)`, `take(n)`,
  `count`, `sum(campo)`. Referencias a otros nodos por id
  (`stock_tabs.value`, `inv_grid.selected`). Sin aritmética libre, sin
  condicionales: lo que no entra en esto es lógica y va en código como
  fuente nueva.
- **Validación de tipos** al editar y al cargar: `list<itemStack>` en
  una entrada `int` = error; `count` convierte `list<T>` en `int`.

### II.2.4 Acciones

`on: {evento: accion(args)}`. Los args son expresiones del § II.2.3 o
`$payload` del evento (`$item` en `activate` de una grilla). El
contrato dice el tipo de cada arg; el validador los chequea. En el
juego, la pantalla entrega `ActionHandler`s por nombre (como hoy
`ScreenAction`); el handler decide si está habilitado y por qué
(`enabledWhen` + motivo → botón gris con tooltip, regla de botones
deshabilitados). Ejemplos por pantalla: `shop.buy/sell`,
`quest.accept/deliver/abandon`, `stash.deposit/withdraw`,
`craft.fuse`, `npc.talk(topic:)`.

En P2P el handler sigue mandando la intención por `NetSession` como
hoy: el layout **no** cambia quién valida (el host).

## II.3 Templates como punto de partida

Cada template es un componente de nivel `template` con huecos con
nombre y un **layout semilla** (YAML) que el editor copia al crear una
pantalla:

| Template | Componente | Huecos | Pantallas típicas |
|---|---|---|---|
| Colección | `DsCollectionTemplate` / `DsGridDetailLayout` | `toolbar`, `grid`, `detail`, `footer` | inventario, bestiario, hazañas |
| Traspaso | `DsTransferTemplate` | `left`, `right`, `footer` | alijo, tienda, entregas |
| Taller | `DsCraftGridTemplate` | `recipes`, `detail`, `costs`, `footer` | forja, fusión, cocina |
| Lista + detalle | `DsColumnsTemplate` | `list`, `detail`, `footer` | encargos de NPC, misiones |
| Escenario | `stage` (anclas, screen_editor.md § 2.1) | libre | título, pausa |

Una pantalla elige template al crearse; cambiar de template después
mueve los nodos a huecos con el mismo nombre y deja los demás en
"sin ubicar" (el editor los muestra para reubicar).

## II.4 UX del editor (Editor → PANTALLAS)

Ver la maqueta. Tres columnas:

1. **Árbol** (izquierda): nodos con su binding resumido
   (`DsGridDetailLayout ← player.inventory`, `DsButton → shop.buy`),
   reordenable por arrastre y teclado. Candado en nodos fijos del
   template.
2. **Lienzo** (centro): la pantalla real dibujada con los componentes
   Ds y los **datos de ejemplo** del contrato (sin red, sin Firestore,
   como la Parte I). Selector de resolución (1280×720, 1920×1080,
   2560×1440, 800×600, 600×900, personalizada) y tamaño de texto
   (100/125/150/200 %).
3. **Paleta + Propiedades** (derecha): subpestañas ÁTOMOS / MOLÉCULAS /
   ORGANISMOS / TEMPLATES con buscador (por nombre, nivel y etiqueta);
   ítems en grilla con la vista previa del registro. Debajo,
   PROPIEDADES del nodo elegido en tres secciones: PERILLAS (del
   esquema), DATOS (fuente + expresión, con selector que solo ofrece
   fuentes de tipo compatible y vista de los ítems de ejemplo), ACCIONES
   (evento → acción con args).

Interacción:

- **Selección**: clic = nodo más interno; `Esc` / Alt+clic = padre.
  Contorno `DsColors.editSelection` y nombre.
- **Arrastrar y soltar**: desde la paleta o el árbol. Guías iguales a
  la Parte I (línea verde de inserción; hueco verde si acepta, rojo
  tachado si no: un hueco declara qué niveles/tipos acepta).
- **Teclado**: flechas reordenan, `Tab` cambia de hueco, `Supr` borra,
  `Ctrl+D` duplica, `Ctrl+Z / Ctrl+Y`.
- **Deshacer/rehacer**: pila de comandos sobre el árbol inmutable
  (`LayoutCommand`: insertar, mover, borrar, setKnob, setBind, setOn);
  sin límite práctico (los árboles son chicos).
- **VERIFICAR** (barra de problemas abajo, en vivo): reúne lo de
  screen_editor.md § 6 y la Parte I § 2.5 más: tipo de binding,
  acción inexistente, arg faltante o de tipo incorrecto, referencia a
  un id que no existe, clave i18n inexistente, perilla fuera de rango,
  hueco obligatorio vacío, acción única oculta. Clic en un problema =
  selecciona el nodo. Con errores no se guarda ni publica.
- **GUARDAR** (override local) / **PUBLICAR AL REPO** / RESTAURAR /
  RECARGAR, mismo circuito que sprites y la Parte I.

## II.5 Render en el juego y respaldo

- `UiLayoutCatalog` (única clase que lee `assets/layouts/<game>/*.ui.yaml`,
  como `SpriteCatalog`): override local válido → asset del repo válido
  → **`null`**.
- `DsLayoutScreen(screen:, contract:, handlers:, fallback:)`: si el
  catálogo da un layout válido para el juego actual, lo dibuja; si no,
  dibuja `fallback` (la pantalla armada en código de hoy). Así una
  pantalla se migra sin riesgo y siempre hay respaldo.
- Un layout que en runtime falla (fuente que no llega, excepción en un
  `build`) cae al respaldo con log, nunca pantalla roja.
- El juego activo sale del flavor (`main_*.dart` inyecta `Game.world` o
  `Game.voyage`); cada juego tiene su carpeta y su lista de contratos.
  Componentes Ds compartidos; contratos y layouts no.

## II.6 Rendimiento

- Parseo y validación **una vez** al cargar → `ResolvedLayout`
  inmutable con los builders ya resueltos (id de componente → fábrica,
  expresión → función compilada). Por frame solo se elige corte.
- Cada nodo ligado escucha solo su fuente (`ValueListenableBuilder` por
  nodo), no reconstruye la pantalla entera.
- Grillas grandes usan las vistas perezosas que ya usan los
  componentes; el layout no agrega envoltorios por ítem.
- Meta: abrir una pantalla por layout ≤ 1 ms más que la de código
  (medido en test con 200 ítems).

## II.7 Versionado y migración

- `schema:` entero en cada archivo. `UiLayoutMigrations` encadena
  `v1→v2→…` en Dart puro; el editor guarda siempre la última.
- Componente renombrado: tabla de alias en el registro
  (`aliases: ['DsGridDetail']`). Perilla renombrada: alias por perilla.
- Contrato que pierde una fuente o acción: el layout carga, el nodo
  queda con error de VERIFICAR y en el juego se usa el respaldo.
- Tests: cada layout del repo se carga, migra y valida en `flutter test`
  (un test por juego que recorre la carpeta).

## II.8 Reglas atómicas

- **Sin duplicar**: el editor no tiene widgets propios para dibujar la
  pantalla; usa los Ds reales vía registro. La galería
  (`ds_gallery_screen.dart`) y la paleta comparten ejemplos.
- **Solo tokens**: colores = nombres de `DsColors`; texto =
  `DsTextStyleId`; espacios = `DsSpace`. Nada de hex, px o negritas en
  los YAML; el parser rechaza lo demás.
- **Visual agnóstico a la lógica**: los componentes reciben datos y
  callbacks; la lógica queda en contratos y handlers.
- Ítems en grilla con detalle a la derecha y categorías con subpestañas
  (nunca secciones apiladas): los templates de Colección y Lista+detalle
  ya lo traen; VERIFICAR avisa si se apilan 2+ `DsSectionHeader` con
  colecciones en el mismo hueco.

## II.9 i18n

Los textos del layout son **claves** (`ui.shop.buy`), nunca texto
suelto; el panel de propiedades busca y ofrece claves existentes y
permite crear una nueva (va al archivo de textos base con el texto en
castellano). VERIFICAR marca clave inexistente. Los datos ligados
(nombres de ítems, encargos) ya vienen traducidos de su fuente.

## II.10 Plan por fases

| Fase | Contenido | Estimado |
|---|---|---|
| 0 | Decisiones del dueño (§ II.12) | — |
| 1 | Núcleo puro: `LayoutNode`, parser/encode, `UiType`, expresiones, `ScreenContract`, validador, migraciones v1; tests | 4–5 días |
| 2 | Registro con esquema de perillas/entradas/eventos para ~15 componentes (botón, texto, buscador, pestañas, fila de lista, grilla+detalle, fila de acciones, costos, diálogo, oro, 3 templates) | 3–4 días |
| 3 | Runtime: `UiLayoutCatalog`, `DsLayoutScreen` con respaldo, por juego | 2–3 días |
| 4 | **MVP de punta a punta: Tienda de NPC (Mundo)**: contrato con fuentes y `shop.buy/sell`, layout por defecto que reproduce la de hoy (golden igual), editor: árbol, lienzo, paleta con buscador, propiedades (perillas + datos + acciones), arrastrar/soltar, deshacer, VERIFICAR, guardar/publicar | 6–8 días |
| 5 | Encargos de NPC (Lista + detalle) y entrega (`quest.deliver`) | 3 días |
| 6 | Unificar: TÍTULO (`stage`) y pantallas de la Parte I pasan al formato nuevo con migración automática | 4–5 días |
| 7 | Travesía: contratos propios y primera pantalla | 3 días |

MVP (fases 1–4): **3 a 4 semanas** de trabajo efectivo. Total hasta
fase 7: 6 a 7 semanas.

## II.11 Riesgos

- **Dos/tres formatos a la vez** (Parte I, `.screen.json`, `.ui.yaml`)
  hasta la fase 6: deuda explícita; regla: ninguna pantalla nueva en
  formatos viejos.
- **Expresiones que crecen hasta ser un lenguaje**: lista cerrada de
  operadores; pedir uno nuevo es un cambio de código con test.
- **Pantallas acopladas a animación o geometría** (batalla, mapa, árbol
  de pasivas): siguen como huecos fijos que arma el código.
- **Datos de ejemplo desactualizados** respecto del dominio real: los
  fixtures salen de los catálogos reales con semilla fija.
- **Layouts válidos pero feos**: VERIFICAR garantiza "no roto"; lo
  lindo sigue siendo criterio del dueño.

## II.12 Decisiones del dueño

1. ¿El MVP es la **Tienda de NPC** (recomendado: ejercita traspaso,
   dos fuentes y dos acciones) o los **Encargos de NPC**?
2. ¿Formato del archivo: **YAML** (recomendado, igual que sprites y la
   Parte I, comentable) o JSON (como el TÍTULO de hoy)?
3. ¿Se **unifican** los editores LAYOUT y PANTALLAS en uno (fase 6,
   recomendado) o conviven?
4. ¿Hasta dónde llegan las **expresiones**: solo la lista cerrada del
   § II.2.3 (recomendado) o también condiciones simples de visibilidad
   (`visible: player.gold > 0`)?
5. ¿Los layouts publicados son **iguales para todos** (recomendado,
   como la Parte I § 5.2) o se permiten overrides por jugador/servidor?
