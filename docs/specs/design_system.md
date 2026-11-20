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
  texto `gold` + subrayado 3 px. Base: `TabBar` + `Badge` sin hijo.
- DsBadge: pastilla con número o palabra corta; fondo `gold`, texto
  `bg`, padding `xs` horizontal; variante neutra (borde, texto
  secundario).
- DsToolbar: fila superior con título, contenido flexible (pestañas) y
  acciones a la derecha; padding `sm`/`md`, borde inferior.
- DsCard: superficie sin borde, padding `md`; elegida borde `gold`;
  clickeable con hover. Nunca una tarjeta dentro de otra.
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
- DsStatLine: `ATQ  15 → 50  ▲35`: etiqueta secundaria, antes
  secundario, después principal, diferencia verde ▲ / roja ▼ (con
  flecha: nunca solo el color).
- DsCost: costo MP (`ice`, sufijo "MP") o Pulso (`gold`, sufijo "P");
  si no alcanza, en rojo.
- DsTag: etiqueta en mayúsculas, Subtítulo chico dentro de borde del
  color del tipo: INSTANTE (celeste), PUEDE QUEBRAR (naranja), NUEVO
  (dorado).
- DsSectionHeader: Subtítulo en secundario + línea fina hasta el borde;
  acción opcional a la derecha.
- DsFold: "▸ Más" / "▾ Menos" como botón fantasma; despliega el hijo.
- DsTooltipCard: una sola columna, ancho máximo 360 (escala con el
  texto), alto máximo 60 % de la pantalla con scroll, título + cuerpo +
  pie de atajos (`[E] equipar  [Supr] tirar`) en Detalle.

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
con tooltip, menú de habilidades de batalla).

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

Pendiente: el contenido de INVENTARIO, ÁRBOL, FILTRO, BUILD y BESTIARIO
(sus vistas en `lib/features/inventory`, `passive_tree`, `build_planner`,
`bestiary`) sigue con `PanelButton` / `SectionPanel` y sus textos fijos
propios; se migran vista por vista.

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
