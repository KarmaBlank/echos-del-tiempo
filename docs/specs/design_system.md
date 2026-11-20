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

| nombre | fuente | nominal | real a 1280×720 Normal | color por defecto |
|---|---|---|---|---|
| Título | Press Start 2P | `RetroType.title` 16 | 16 px | texto principal |
| Subtítulo | Press Start 2P | `RetroType.label` 9 | 10→8 px de grilla (8 / 16 físicos) | texto secundario |
| Texto | VT323 (fuente de lectura) | `RetroType.body` 11 | 20 px | texto |
| Detalle | VT323 (fuente de lectura) | `RetroType.small` 10 | 20 px | texto secundario |

Texto y Detalle tienen el mismo tamaño (VT323 por debajo de 20 px no se
lee): la diferencia es el color. Los estilos respetan "Fuente de lectura"
(CLÁSICA / ATKINSON) y "Títulos con la fuente de lectura".

### 3.3 Roles de color (`DsColors`)

Todos son tokens de `ProtoColors` (siguen al tema y al modo daltónico).

| rol | token | AZUL | ALTO CONTRASTE |
|---|---|---|---|
| superficie | `panel` | #121936 | #000000 |
| superficie elevada | `button` | #22305A | #000000 (+ borde blanco) |
| superficie hundida | `input` | #0F1530 | #000000 |
| borde | `panelBorder` | #2E3B6B | #BDBDBD |
| borde de control | `buttonBorder` | #5B74C9 | #FFFFFF |
| texto principal | `title` | #E8ECFF | #FFFFFF |
| texto | `ink` | #B0BAE5 | #F0F0F0 |
| texto secundario | `dim` | #929ABA | #C8C8C8 |
| texto desactivado | `dim` al 60 % | — | — |
| acción principal | relleno `gold`, texto `bg` | #D3AC4F | #FFE600 |
| acción secundaria | `button` + `buttonBorder` | | |
| foco | `gold` (aro de 2 px por fuera) | #D3AC4F | #FFE600 |
| peligro | `red` | VisionColor | VisionColor |
| éxito | `green` | VisionColor | VisionColor |
| recompensa | `gold` | | |
| Pulso | `gold` | | |
| MP | `ice` | #77A7D7 | #B8DCFF |
| Instante | celeste fijo #81ECEC (el de Congelación súbita, ya en `UiTheme.keep`) | igual | igual |

Regla: el color dice qué es (MP, Pulso, peligro); la jerarquía la da el
brillo (principal > texto > secundario > desactivado).

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

- DsButton: variantes principal (relleno dorado, texto oscuro),
  secundario (caja del tema), fantasma (sin caja hasta hover), ícono
  (cuadrado, con tooltip obligatorio). Tamaños normal (8 libres + borde,
  alto mín. 40, Subtítulo) y compacto (8 libres + borde, alto mín. 32,
  Subtítulo). Ícono: cuadrado de alto igual al botón. Base:
  `FilledButton` / `OutlinedButton` / `TextButton` / `IconButton`.
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

Pantalla `DsGalleryScreen` (solo flavor `main_gallery.dart`, que arma
los FeatureFlags de dev). Arriba: selector de TAMAÑO DEL TEXTO, TEMA
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
