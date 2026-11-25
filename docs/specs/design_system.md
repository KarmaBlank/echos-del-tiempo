# Spec: Sistema de diseño (v0.11, borrador para revisar)

Estado: propuesta. Los componentes viven en `lib/app/design/` y se ven en la
GALERÍA (flavor dev: `flutter run -t lib/app/flavors/main_gallery.dart`).
Ninguna pantalla real los usa todavía: la migración se hace pantalla por
pantalla después de que el dueño apruebe esto.

Complementa (no reemplaza) docs/specs/ui_style.md (estilo pixel, fuentes,
botones del tema) y docs/specs/accessibility.md (tamaño del texto, temas,
espaciado AMPLIO, alto contraste).

## 1. Problemas que resuelve

- Padding de botones distinto en cada pantalla.
- Insignias (contadores, "NUEVO") encima del texto de la pestaña.
- Todo el texto en el mismo blanco: no se ve qué es título, qué es dato y
  qué es ayuda.
- Párrafos largos en los paneles.
- Cada pantalla arma sus filas, chips y tooltips a mano.

## 2. Principios

0. Minimalista (directiva del dueño, manda sobre todo lo demás):
   - una línea por fila; la información secundaria solo en tooltip;
   - nada de textos de ayuda fijos (van al "?");
   - un dato se muestra solo cuando cambia algo: el tope de un atributo
     aparece recién cuando lo estás pasando (`+3 → +1.5` en naranja);
   - menos bordes y cajas anidadas: separar por espacio y color; borde
     solo en controles y en lo elegido;
   - íconos en vez de palabras cuando el significado es obvio (−, +, ×,
     ★, ?), siempre con tooltip;
   - como máximo 2 niveles de jerarquía visibles a la vez (Título +
     Texto, o Subtítulo + Texto).
1. Jerarquía clara: cada bloque tiene a lo sumo un Título; lo importante
   se distingue por color y tamaño, nunca por negrita (no hay pesos).
2. Poco texto: una línea por dato. Lo que no entra en una línea va al
   tooltip; lo que es explicación, al "?".
3. Toda acción es botón: si se clickea, se ve como botón (o como fila
   clickeable, o como pestaña). Nunca texto suelto clickeable.
4. Ayuda en "?": la leyenda y las reglas del panel viven en un botón "?"
   de la barra superior, no en párrafos fijos.
5. Un componente por problema: si dos pantallas necesitan lo mismo, usan
   el mismo `Ds*`.
6. Accesible siempre: sigue TAMAÑO DEL TEXTO, ESPACIADO AMPLIO y ALTO
   CONTRASTE; foco de teclado visible; cursor de mano en lo clickeable.
7. Todo cuadrado / pixel (regla del dueño, v0.13.3): en la interfaz no
   hay formas redondeadas ni circulares. Botones, chips, insignias,
   tarjetas, tooltips, toasts, campos, scrollbars, checkboxes y radios
   usan esquinas rectas (radio 0); el tema Material
   (`RetroTheme.build`) pone formas rectangulares por defecto. Solo el
   arte de escena que dibuja algo intencionalmente redondo (painters: anillo y
   nodos del árbol de pasivas, efectos de batalla, minimapa; nodos y aura de
   la constelación de Ascensión) queda fuera. Lo vigila
   `test/app/square_ui_audit.dart` (`roundedUi`) en título, HUD,
   pestañas de PERSONAJE, inventario y batalla.

## 3. Escalas

### 3.1 Espaciado (`DsSpace`)

| token | px (NORMAL) | AMPLIO (×1.5) | uso |
|---|---|---|---|
| `xs` | 4 | 6 | entre ícono y texto, dentro de una pastilla |
| `sm` | 8 | 12 | padding mínimo de botón compacto, entre filas |
| `md` | 16 | 24 | padding de tarjeta y de panel, entre grupos |
| `lg` | 24 | 36 | entre secciones de un panel |
| `xl` | 32 | 48 | márgenes de pantalla |

Nunca un número suelto: siempre `DsSpace.*` (pasa por `UiTheme.space`).

### 3.2 Tipografía (`DsText`)

Cuatro estilos con nombre, sobre los tokens de `RetroType` (escalan con
TAMAÑO DEL TEXTO por `RetroTextScaler`; a 1920×1080 todo ×1.5):

| nombre | fuente | nominal | real a 1280×720 / 1920×1080 | color |
|---|---|---|---|---|
| Título | Press Start 2P | `RetroType.title` 16 | 16 / 24 px | dorado claro |
| Subtítulo | Press Start 2P | `RetroType.label` 9 | 8 / 16 px | celeste |
| Cuerpo (Texto) | VT323 (fuente de lectura) | `RetroType.body` 11 | 20 / 30 px | blanco tinta |
| Detalle | VT323 (fuente de lectura) | `RetroType.small` 10 | 20 / 30 px | lavanda |

Jerarquía por COLOR (respuesta del dueño, v0.11): las fuentes pixel no
tienen pesos y la regla del juego es sin negritas, así que cada nivel
tiene su propio tono (no "el mismo blanco más apagado"). Cuerpo y
Detalle tienen el mismo tamaño porque VT323 por debajo de 20 px no se
lee; los separa el color. Los estilos respetan "Fuente de lectura"
(CLÁSICA / ATKINSON) y "Títulos con la fuente de lectura".

Colores de texto (`DsTextColor`, siguen al tema):

| rol | AZUL | OSCURO | ALTO CONTRASTE |
|---|---|---|---|
| Título | #FFE3A8 | #F5D99A | #FFF1A8 |
| Subtítulo | #8FD3F4 | #8EC5E6 | #9FE7FF |
| Cuerpo | #E8ECFF | #EDEDED | #FFFFFF |
| Detalle | #B3ACE6 | #B8B2DC | #D4CCFF |

Todos ≥ 7:1 sobre el fondo de su tema. Desactivado: Detalle al 55 %.

### 3.3 Roles de color (`DsColors`)

Todos son tokens de `ProtoColors` (siguen al tema y al modo daltónico).

| rol | token | AZUL | ALTO CONTRASTE |
|---|---|---|---|
| superficie | `panel` | #121936 | #000000 |
| superficie elevada | `button` | #22305A | #000000 (+ borde blanco) |
| superficie hundida | `input` | #0F1530 | #000000 |
| borde | `panelBorder` | #2E3B6B | #BDBDBD |
| borde de control | `buttonBorder` | #5B74C9 | #FFFFFF |
| Título / Subtítulo / Cuerpo / Detalle | `DsTextColor` (§ 3.2) | | |
| texto desactivado | Detalle al 55 % | — | — |
| acción principal | caja `button`, borde y texto `gold` | #D3AC4F | #FFE600 |
| acción secundaria | `button` + `buttonBorder` | | |
| foco | `gold` (aro de 2 px por fuera) | #D3AC4F | #FFE600 |
| peligro | `red` | VisionColor | VisionColor |
| éxito | `green` | VisionColor | VisionColor |
| recompensa | `gold` | | |
| Pulso | `gold` | | |
| MP | `ice` | #77A7D7 | #B8DCFF |
| Instante | celeste fijo #81ECEC (el de Congelación súbita, ya en `UiTheme.keep`) | igual | igual |

Regla: el color dice qué es (MP, Pulso, peligro) y también qué nivel de
jerarquía es (Título, Subtítulo, Cuerpo, Detalle).

## 4. Disposición de un panel

```
┌ barra superior (DsToolbar) ───────────────────────────────┐
│ TÍTULO   [pestañas con insignia]       [buscar] [acción] [?]│
├────────────────────────────────────────────────────────────┤
│ contenido principal: lista de DsListRow / tarjetas         │
│ (el detalle de cada elemento aparece en DsTooltipCard)     │
└────────────────────────────────────────────────────────────┘
```

- Barra superior: título a la izquierda, pestañas, y a la derecha
  búsqueda, acciones y "?" (siempre el último).
- Contenido: listas o grillas; sin párrafos explicativos.
- Detalle: en tooltip (hover / foco), una sola columna.
- Leyenda y reglas: en el "?" (abre un DsTooltipCard o un panel).

## 5. Estados comunes

| estado | fondo | borde | texto | otros |
|---|---|---|---|---|
| normal | superficie elevada | borde de control | principal | |
| hover | `buttonHover` | `buttonHoverBorder` | principal | cursor de mano |
| foco (teclado) | como hover | aro `gold` 2 px por fuera, separado 2 px | principal | |
| presionado | `buttonHover` | `gold` | principal | desplazado 1 px abajo |
| elegido | superficie elevada | `gold` | `gold` | pestañas: subrayado `gold` 3 px |
| desactivado | transparente | `panelBorder` fino | desactivado | cursor normal; motivo en rojo si aplica |

Filas y tarjetas no llevan borde en normal (separación por espacio): el
fondo aparece con hover / foco y el borde dorado solo al elegirlas.

ALTO CONTRASTE: bordes de 3 px en controles (`UiTheme.buttonBorderWidth`),
foco amarillo #FFE600.

## 6. Catálogo

Medidas en px nominales (Normal, 1280×720); todo escala.

- DsButton: variantes principal (misma caja que el resto, borde y texto
  dorados; decisión del dueño: nada de relleno dorado), secundario (caja
  del tema), fantasma (sin caja hasta hover), ícono (cuadrado, con
  tooltip obligatorio). Padding (estilo Material 3, horizontal mayor que
  vertical, ≥ 8 libres en todos los lados, sin contar el borde): normal
  16 h × 8 v, compacto 12 h × 8 v, ícono 8 en los cuatro lados. Sin alto
  mínimo forzado (el alto sale del texto + padding). Texto en Subtítulo.
  Base: `FilledButton` / `OutlinedButton` / `TextButton` / `IconButton`.
- DsTab / DsTabBar: pestaña con texto y, opcional, insignia DsBadge
  adentro, a la derecha del texto, separada `xs` (nunca encima). Elegida:
  texto `gold` + subrayado 3 px. Base: `TabBar` + `DsBadge`.
- DsBadge: rectángulo de esquinas rectas (no pastilla) con número o
  palabra corta; fondo `gold`, borde de 1 px, texto `bg`, padding `xs`
  horizontal; variante neutra (borde, texto
  secundario).
- DsToolbar: fila superior con título, contenido flexible (pestañas) y
  acciones a la derecha; padding `sm`/`md`, borde inferior.
- DsCard: superficie sin borde, padding `md`; elegida borde `gold`;
  clickeable con hover. Nunca una tarjeta dentro de otra.
- DsDetailPane (organismo, v0.42.3): la columna de detalle de toda
  grilla + detalle. `body` (información) y `actions` (cantidad, total,
  botón principal). Llena el alto que recibe; `actions` queda fija abajo
  y siempre visible, solo `body` scrollea (barra visible). Sin alto
  acotado (dentro de otro scroll) se apila natural. `sunken`: superficie
  hundida con borde (TIENDA). Solo visual: no sabe de ítems ni precios.
- Grilla + detalle: elegir → detalle → acción fija (v0.46.1). En toda
  grilla con `DsDetailPane` (INVENTARIO, tiendas de NPC, HERRERÍA,
  CONSTRUIR): un clic ELIGE (casilla marcada) y nunca actúa solo; el
  detalle sigue a la elegida y es fijo: el hover solo previsualiza si no
  hay nada elegido, y mover el mouse hacia el detalle (su barra) no lo
  cambia. La acción va en un botón primario fijo en `actions` (gris
  con el motivo en el detalle si no se puede); doble clic y Enter son
  atajos; flechas mueven la elección, Esc cierra. El detalle se
  dimensiona para que el contenido normal entre sin scroll.
- DsToast (aviso): caja con franja izquierda de 4 px del color del tipo
  (info `ice`, éxito, peligro, recompensa), una línea de texto, botón ×
  opcional.
- DsSearchField: campo hundido con borde de control, foco `gold`, alto
  40, padding `sm`; base `SearchBar` cuadrada.
- DsListRow: fila clickeable de UNA línea: nombre (Texto, principal),
  un dato corto opcional en secundario en la misma línea y a la derecha
  un valor / insignia / acciones de ícono; lo demás va en el tooltip
  (`tooltip:`). Sin borde; hover / foco con fondo; elegida borde `gold`;
  desactivada texto desactivado. Padding `sm` vertical, `md` horizontal.
- DsAttributeRow: fila de ATRIBUTOS en una línea: nombre, valor, ★ de
  plan (si está en el plan), botón −, botón "+3 VIT". Al pasar el tope
  blando el botón muestra `+3 → +1.5` en naranja (solo entonces).
  El − quita solo el reparto sin confirmar; sin pendiente se ve apagado
  (texto desactivado) y su tooltip dice que los confirmados se reasignan
  con REINICIAR PUNTOS.
- DsStatLine: `ATQ  15 → 50  ▲35`: etiqueta secundaria, antes
  secundario, después principal, diferencia verde ▲ / roja ▼ (con
  flecha: nunca solo el color).
- DsCost: costo MP (`ice`, sufijo "MP"), Pulso (`gold`, sufijo "P"),
  carga de ULT (`DsCost.ult`, `45%` en secundario, naranja al 100 %) o
  cantidad (`DsCost.count`, `x3`); si no alcanza, en rojo. Siempre en
  Cuerpo: es el único formato de costo de las listas de acciones de
  batalla (HABILIDADES, DÚOS, ULTIMATE, OBJETOS); nunca dentro del título.
- DsTag: etiqueta en mayúsculas, Subtítulo chico dentro de borde del
  color del tipo: INSTANTE (celeste), PUEDE QUEBRAR (naranja), NUEVO
  (dorado).
- DsSectionHeader: Subtítulo en secundario + línea fina hasta el borde;
  acción opcional a la derecha.
- DsFold: "▸ Más" / "▾ Menos" como botón fantasma; despliega el hijo.
- DsTooltipCard: una sola columna, ancho máximo 360 (escala con el
  texto), alto máximo 60 % de la pantalla con scroll, título + cuerpo +
  pie de atajos (`[E] equipar  [Supr] tirar`) en Detalle.

## 6 bis. Estructura atómica (v0.14.0)

Directiva del dueño: el sistema de diseño es atómico y la parte visual
es totalmente agnóstica de la lógica. Los widgets reciben datos ya
calculados (qué hay, si está elegido, si coincide con la búsqueda, el
texto de la ficha) y callbacks; la lógica de juego (qué se puede, qué
cuesta, qué pasa al tocar) queda en la pantalla o su controlador.
Layout, claridad y accesibilidad siguen los principios de Material
Design 3 (áreas de toque, foco visible, jerarquía por tipografía y
espacio), con estilo pixel art y sin redondeos.

Niveles:

- Átomos: piezas sin estado propio ni composición. `DsCost`, `DsTag`,
  `DsBadge`, `DsButton`, `PixelIcon` (ícono de ítem), la letra de rareza
  y la ★ de tu build, `NewItemTag` (marca NUEVO), colores de rareza
  (`RarityColors`).
- Moléculas: un átomo con su contexto mínimo. `ItemCell` / `ItemSlot`
  (casilla de ítem: borde y letra de rareza, ícono, ★, NUEVO, atenuada si
  no coincide con la búsqueda, `✓` o candado de selección múltiple, borde
  dorado de elegida), `DsStatLine` (fila de stat), `DsSearchField` (campo
  de búsqueda), `DsListRow`, `DsAttributeRow`.
- Organismos: secciones completas reutilizables.
  - `DsItemGrid` (`lib/features/inventory/presentation/item_grid.dart`):
    grilla de casillas de ítem con buscador opcional (`ItemGridSearch`,
    Esc con texto lo limpia), cursor de teclado (flechas, Enter /
    Espacio), clic, clic derecho para el menú contextual opcional
    (`onMenu`), ficha estándar (`tip:`, normalmente `itemHoverTip`) y
    selección simple (`selected`) o múltiple (`picked` / `locked`). El
    filtro (`inventoryMatches`) lo aplica la pantalla: o atenúa
    (`dimmed`, grillas con posiciones fijas) o pasa solo lo que
    coincide (grillas de elección). `decorate:` deja a la pantalla
    agregar arrastre u otros envoltorios sin tocar la grilla.
  - Ficha de arma (`ItemCard`, `HoverCompareCard`) y lista de
    habilidades (`SkillChips`).
- Templates: el layout de un panel: barra arriba (`DsToolbar`, pestañas,
  migas) + contenido (lista o grilla) + detalle (`PanelSplit` /
  `PanelDetail`, con los botones al pie).

Regla: todo lo de los cuatro niveles es presentacional; cero lógica de
juego adentro. Una misma cosa se ve igual en todas las pantallas: un
arma es siempre la misma casilla, con los mismos colores de rareza, la
misma ficha, el mismo buscador y las mismas marcas.

Dónde se usa `DsItemGrid`: INVENTARIO (grilla 8 × 5 con arrastre), ALIJO
(los dos lados), FUSIÓN (arma destino, arma de origen y base nueva al
reforjar) y FORJA (arma a forjar). COMPRAR sigue en lista: elige bases
del catálogo con precio y "TIENES" a la vista, no ítems propios.

### 6.1 `DsCollectionTemplate` (colecciones)

Plantilla única para colecciones (pesca, cultivo y herrería):
- `DsCollectionEntry`: id, ícono, descubierto, título, color, borde,
  etiquetas, filas del detalle y grupos (para los filtros).
- Subtabs de filtro (`(id, label)`, `all` = todos) y contador
  descubiertos/total (`DsBadge`, key `<prefijo>-progress`).
- Grilla y detalle: el layout compartido de § 6.2; sin descubrir: "?"
  gris sin pistas (key `<prefijo>-unknown-<id>`).
- Tipografía por rol (`DsText.title/body/detail`), sin cortes; tooltips
  de ancho fijo.
- Test de overflow a 1024×640 y 1920×1080 con escala 1.0 y 2.0.

### 6.2 Grilla de ítems (`DsGridDetailLayout`, v0.49.9)

Regla del dueño: INVENTARIO es la base; TODA pantalla que muestra ítems
se ve igual. Un solo organismo, `DsGridDetailLayout`
(`ds_collection_template.dart`), es el cuerpo de las plantillas
`DsCollectionTemplate`, `DsCraftGridTemplate` (TALLER), de
`LifeItemGrid` (oficios y tiendas de NPC) y de `EcoGridLayout`
(MEJORAR / FUSIONAR). Medidas en tokens (`DsSizes`):

- `itemCell` 44, `itemGap` 4, `itemIcon` 32: la casilla base de
  INVENTARIO. La casilla escala con los mismos pasos que INVENTARIO
  (enteros desde ×2, cuartos entre ×1 y ×2; `DsSizes.itemScale`): el
  mayor paso en que entran 6 columnas + el detalle a lo ancho y 5 filas
  a lo alto. El ícono escala con la casilla.
- `gridColumns` 6: la grilla mide exactamente 6 columnas; las filas
  crecen hacia abajo con barra de scroll visible si no entran.
- `detailPaneWidth` 340: ancho fijo del detalle a la derecha (entra
  "Precio: 4 de oro c/u" y los nombres sin cortes raros); misma fuente
  de siempre, acciones fijas abajo (`DsDetailPane`). Los pares
  clave/valor del detalle nunca cortan: el valor se ajusta en líneas.
- Grilla + detalle se centran en el panel: el sobrante de los pasos de
  escala queda repartido, nunca un gran vacío de un lado.
- Angosto (< `gridDetailWideFrom`) o dentro de otro scroll: detalle
  arriba, grilla debajo a ×1.
- `leading` opcional: columna a la izquierda de la grilla (ARMERÍA).
- Claves: `<prefijo>-grid`, `<prefijo>-pane`, `<prefijo>-scroll`.
- `DsItemCell` (átomo de casilla de TALLER y TRASPASO) mide `itemCell`.

Pantallas: caravana / tiendas de NPC de bioma (COMPRAR), AGROPECUARIO,
PESCA Y CULTIVO, menús de NPC, minero, MI PUESTO, ayudantes, diarios de
oficio, registro de misiones, tienda de herramientas, ARMERÍA y
HERRERÍA (TALLER), cocina, ofrendas, colecciones, ECOS MEJORAR /
FUSIONAR. Pendientes (layout propio todavía): INVENTARIO y ALIJO
(grilla 8 × 5 / tablero con arrastre), FORJA y COMPRAR de Brann
(`craft_bench`, `shop_sections` sobre `PanelSplit`), botín perdido,
decoración de balsa, paleta de construcción y casas.

Galería: página GRILLAS (`GridTemplatesMockup`).

## 7. Tema (`DsTheme`)

`DsTheme.extension()` es una `ThemeExtension` con los roles de color y
los estilos de texto; `DsTheme.apply(ThemeData)` la agrega al tema retro
y configura `TabBarTheme`, `TooltipTheme`, `SearchBarTheme` y
`BadgeTheme`. Los componentes leen `DsColors` / `DsText` directo (los
tokens ya siguen al tema activo).

## 8. Galería

Pantalla `DsGalleryScreen`: botón GALERÍA en la pantalla de título solo
con `FeatureFlags.devTools` (flavor dev), o directo con
`main_gallery.dart`. Arriba: selector de TAMAÑO DEL TEXTO, TEMA
(AZUL / OSCURO / ALTO CONTRASTE) y ESPACIADO. Secciones: Paleta,
Tipografía, Botones, Pestañas y barra, Campos y filas, Valores,
Superficies, Ejemplos (mockups: barra de PERSONAJE, fila de inventario
con tooltip, menú de habilidades de batalla, plantilla TRASPASO con datos de ejemplo
— ver ui_minimal.md § 9).

Capturas: `docs/design/*.png` (1920×1080, fuentes reales, tema por
defecto del jugador: ALTO CONTRASTE + colores REDUCIDOS), generadas por
`test/design/ds_screenshots_test.dart` con `DS_SHOTS=1`.

## 9. Tests

- `test/design/ds_components_test.dart`: estados, foco, cursor, padding
  ≥ 8 libres, insignia sin superponer, TAMAÑO DEL TEXTO ENORME sin
  desbordes.
- `test/design/ds_golden_test.dart`: goldens de cada componente.

## 10. Migración (v0.11)

### 10.1 PERSONAJE

Hecho: pestañas `DsTabBar` con insignia (`DsTab` acepta `key` / `badgeKey`;
el padding va dentro de la pestaña, así toda la pestaña es clickeable y la
insignia queda dentro con aire), ayuda de cada pestaña en el "?", línea del
título por color, ATRIBUTOS completo (barra de herramientas arriba,
`DsSectionHeader`, `DsButton` principal / secundario / fantasma / ícono,
`DsFold` para razones y rasgos, filas de una línea sin borde).
`DsSectionHeader`: título y acción con tope de 45 % del ancho cada uno
(con texto ENORME no desbordan).

Hecho también (v0.11, rama `feat/personaje-ds-arbol`):

- ÁRBOL (`passive_tree_view.dart`): barra `DsToolbar` sin título (puntos
  en Cuerpo dorado, `DsTag` HITO N en naranja, `DsSearchField`, zoom con
  `DsButton.icon` y REINICIAR como fantasma con el motivo en el tooltip);
  tarjetas de hito `DsCard` (elegida con borde dorado); tooltip del nodo
  `DsTooltipCard` (marca de hito y "★ EN TU BUILD" como `DsTag`; TOMAR
  NODO principal, motivo en el tooltip del botón); leyenda en una fila en
  Detalle.
- BUILD (`build_planner_view.dart`): barra arriba (★ nombre, metas, %,
  PLANTILLA / RENOMBRAR / BORRAR PLAN), secciones con `DsSectionHeader`
  (+ AGREGAR fantasma a la derecha), metas en `DsListRow` (marca, nombre,
  `actual/objetivo` o motivo en rojo; la pista en el tooltip; −5 / +5 y ×
  como `DsButton.icon`), APLICAR SUGERENCIA principal, selectores con
  `DsSearchField` + `DsListRow` y confirmaciones Sí / No con `DsButton`
  (Sí principal). Los textos de "sección vacía" pasaron al "?".
- BESTIARIO (`bestiary_view.dart`): búsqueda y `Descubiertos N/M` en la
  barra de arriba; filtros por familia como `DsButton` fantasma; lista
  por zona (`DsSectionHeader`) de `DsListRow` (sprite chico, nombre o
  `???`, código de familia); flechas arriba / abajo eligen; ficha con
  `DsSectionHeader` FICHA y `DsFold` ZONA Y BOTÍN.
- Componentes: `DsToolbar` acepta `title: ''` (barra de una pestaña),
  `DsSearchField.onSubmitted`, `DsListRow.focusNode` y el dato corto de
  `DsListRow` se corta con "…".

INVENTARIO (panels.md § Inventario, "Cambios v0.11"): barra de
herramientas arriba (`TÚ` / compañeros, `DsSearchField`, ORDENAR,
LIMPIAR), `DsButton` en todo (motivo en el tooltip), menús de acciones
y de LIMPIAR con filas `DsListRow`, franja de CAMBIOS con `DsStatLine`,
COMPARAR A / B con superficies sin borde, rótulos en Subtítulo.

FILTRO (panels.md § Filtro de loot, "Cambios v0.11"): barra con vista
CASILLAS / TEXTO, estado, RESTAURAR, DESHACER y GUARDAR (principal);
reglas en `DsListRow` de una línea con on / off y ×; casillas en grilla
compacta; ayudas al "?".

Cambios de componentes por esta migración:
- `DsStatLine`: `format` / `diffFormat` (decimales, %), `higherIsBetter`
  (el peso: menos es mejor) y `showChange`; sin cambio muestra solo
  `ATQ  15` en Detalle (principio 0: el dato aparece cuando cambia).
- `DsListRow`: el dato corto se recorta con "…" (con texto ENORME no
  desborda) y `autofocus` (primera fila de un menú).

Las seis pestañas de PERSONAJE quedan migradas (v0.11.0); `CharacterStatRows`
se migró en v0.12 (§ 10.3).

Capturas antes / después (1920×1080): `docs/release_shots/v0.11.0/`,
generadas por `tool/shots/personaje_ds_shots_test.dart` (`SHOT_SUFFIX`).

### 10.2 Contraste medido

`test/design/ds_text_contrast_test.dart` (WCAG 2.x) contra fondo, panel,
campo y botón de cada tema; mínimo pedido 4.5:1 (Cuerpo, Detalle) y 3:1
(Título, Subtítulo). Peor caso por rol (siempre sobre botón):

| rol | AZUL | OSCURO | ALTO CONTRASTE |
|---|---|---|---|
| Título | 10.26 | 11.99 | 18.40 |
| Subtítulo | 7.81 | 8.85 | 15.35 |
| Cuerpo | 10.91 | 14.08 | 21.00 |
| Detalle | 6.08 | 8.19 | 13.88 |

Ningún token necesitó ajuste. Nota: Detalle sobre botón en AZUL es 6.08:1
(no "≥ 7:1" como decía § 3.2; sobre fondo y panel sí pasa de 8).

### 10.3 Batalla (v0.12)

Hecho (rama `feat/ds-batalla`), sin tocar la escena (painter, arena, fx)
ni las reglas:

- Ventana de comandos (`battle_command_window.dart`): categorías y
  acciones en `DsListRow` compactas de una línea (`compact: true`, nuevo:
  aire vertical mínimo para que las 7 categorías entren sin scroll).
  Acción: tecla 1-9 en Detalle, nombre en Cuerpo (dúos y ULT en naranja,
  desactivada en el color desactivado), dato corto en Detalle (Atacar,
  pociones, Defender) y a la derecha `DsTag.instant`, el alcance como
  `DsTag` (`1 ENEMIGO`, `TODOS`, `ALIADO`, `GRUPO`, `VOS`, en el color del
  alcance) y el costo con `DsCost` (MP azul, Pulso `2 P` dorado, rojo si no
  alcanza). Las etiquetas se achican (FittedBox, tope 55 % del ancho) con
  texto ENORME; el costo va aparte, al borde derecho y al mismo tamaño en
  todas las categorías. Dúos: `DsCost.mp(4)` + `TODOS` y resumen
  `A TODOS · elemento · daño c/u · estado · 4 MP cada uno`; ULTIMATE:
  `DsCost.ult` + alcance + `skillSummaryMarkup`; pociones: `DsCost.count`
  + `ALIADO` y resumen de una línea. Costos que no son recurso (`½ turno`,
  `próximo ×½`, HP del aliado al dar poción) en Cuerpo en el mismo lugar. El separador de las Instante en Detalle celeste. Las filas
  no toman el foco (`ExcludeFocus`): Enter y 1-9 siguen siendo de la
  batalla.
- Detalle: quién actúa en Subtítulo Título, recursos en Detalle, motivos
  de la desactivada en Cuerpo rojo arriba, resumen de una línea
  (habilidades: `skillSummaryMarkup`; el resto: las dos primeras líneas) y
  lo demás en `DsFold` (MÁS / MENOS). Objetivo y teclas en Detalle.
- `BattleAction` suma `instant`, `reach`, `mpCost`, `pulseCost` y
  `summary`; la ventana recibe `mp` / `pulse` para el rojo de `DsCost`.
- Tarjetas del grupo (`battle_hud.dart`): superficie / superficie hundida,
  borde de selección en la del turno; nombre en Cuerpo (el propio en
  Título), `Lv` y turno (`▶ 25s` dorado, `T+3` / `K.O.` en Detalle). Las
  barras (HP / MP / ULT con cifras en Press Start) y la fila PULSO (en el
  dorado de Pulso) quedan igual. AUTO: `DsButton` compacto.
- Caja del objetivo: nombre en Cuerpo rojo, `¡ULT!` como `DsTag` rojo,
  borde de peligro. Banda del log en Cuerpo y reloj en
  selección / peligro; REGISTRO EXTENDIDO en Cuerpo / Detalle; "Turno de"
  en Título.
- Panel lateral del tutorial (`tutorial_widgets.dart`): `DsCard`,
  secciones con `DsSectionHeader` (AHORA, LO QUE PASO, VOTACION...), ≡
  como `DsButton.icon`, opciones de la votación como `DsButton`
  (elegida = `selected`) y SIGUIENTE principal.

Pendiente: el menú ≡ del tutorial (modal) y el cartel final siguen con
`RetroPanel` / `PanelButton`.

Capturas antes / después (1920×1080): `docs/release_shots/v0.12.0/`,
generadas por `tool/shots/ds_batalla_shots_test.dart` (`SHOT_SUFFIX`).
En las capturas de prueba los íconos de Material salen como cuadrado
(la fuente de íconos no se carga en `flutter test`).

### 10.3 HUD, título, sello, pausa y VISTA PREVIA (v0.12)

Hecho (rama `feat/ds-hud`), sin cambiar reglas ni funcionalidad; las
claves de test se mantienen:

- HUD del mundo (exploration.md § "HUD"): fila de arriba con `DsButton`
  compactos (`< TITULO`, `MENU [ESC]` con el ≡ como `leading`, `PARTY`,
  `PERSONAJE [C]` con la insignia `+N` como `trailing`, `COPIAR` con
  tooltip); zoom del minimapa con `DsButton.icon` (− / +, tooltip) y
  `MAPA [M]`. `_TopRowLayout` sin cambios (nada superpuesto). Línea de
  misión, objetivos y registro sin borde (superficie, principio 0),
  misión en Cuerpo, tiempo de turno en Detalle, título de objetivos en
  Título, `[+]` / `[-]` en Detalle. Cajas del grupo con colores del
  sistema (nombre Título, clase Detalle, nivel Cuerpo, K.O. peligro,
  `+N` recompensa). Avisos con `DsToast`: barrera / escalera abierta
  (recompensa), puntos sin usar (▲ + franja dorada), avances del plan
  (★ + franja violeta o verde), avisos del chat plegado (una línea). La
  píldora `CHAT [ENTER]` es `DsButton` con `DsBadge` de no leídos. Los
  avisos de loot conservan el estilo del filtro del jugador.
- Título (exploration.md § "Título"): tarjetas de personaje y `+ NUEVO
  PERSONAJE` como `DsCard` (elegida con borde dorado; `hot` sigue al
  foco de `MenuFocusable`); `> JUGAR` y `> CREAR` principales; el resto
  `DsButton` (GALERÍA de dev, fantasma); el motivo de CREAR PERSONAJE
  deshabilitado (cuenta llena) va al tooltip. Las dos líneas de atajos
  pasaron al botón "?" (`title-help`).
- Sello / mostrador (panels.md § "Mostrador"): lista de `DsListRow` de
  una línea (rango, zona, `Lv N` / `Bloqueada`), TUTORIAL primero; el
  foco de teclado sigue eligiendo (el detalle sigue al cursor). Detalle
  (`MissionCard`, también en la preparación): rango y nombre en Título,
  `tipo · Lv`, zona y bloqueo en una línea; OBJETIVO y RECOMPENSAS con
  `DsSectionHeader`; RANGO S en `DsFold`. ENTRAR principal, con el
  motivo en su tooltip y en una línea roja al lado. La línea "Propón…"
  pasó al "?". Preparación: `¡LISTO!` principal, GRUPO con
  `DsSectionHeader` y una línea por jugador.
- Pausa / CONFIGURACIÓN (settings.md § 1): `DsTabBar` (claves `tab-N`);
  la línea de cada pestaña pasó al "?"; filas de ajuste en UNA línea
  (nombre + control) con la ayuda en el tooltip del nombre, marcado
  con "?"; opciones como `DsButton` compactos (`selected`);
  CONTINUAR / CERRAR principal; confirmaciones con `DsButton`.
- `CharacterStatRows` (ATRIBUTOS › VISTA PREVIA e INVENTARIO ›
  ESTADÍSTICAS): `DsStatLine` por stat; DEF y CRÍT con su sufijo; VEL
  con `peso N` (o `N → M`) y la fórmula en el tooltip (`stat-weight`).

Cambios de componentes:
- `DsStatLine.suffix`: dato derivado al final, en Detalle, recortado con
  "…".
- `DsButton.trailing`: a la derecha del texto (insignias).
- `DsCard.hot` (hover / foco manejado afuera) y `DsCard.padding`.
- `DsToast`: `content` (marcado), `leading` (marca de forma), `color`,
  `textColor`, `closeKey` y `closeFocusable` (la × del HUD no toma el
  foco; `Retroceso` sigue cerrando todos).

Capturas antes / después (1920×1080): `docs/release_shots/v0.12.0/`,
generadas por `tool/shots/ds_hud_shots_test.dart` (`SHOT_SUFFIX`).
