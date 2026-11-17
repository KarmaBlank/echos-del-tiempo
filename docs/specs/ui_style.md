# Spec: Estilo visual 8 bits

Implementación: `lib/app/theme/retro_theme.dart` (tema global) y
`lib/app/theme/retro_panel.dart` (caja de diálogo estilo JRPG).
Todo widget de `features/*/presentation` usa el tema en vez de colores,
fuentes o bordes propios.

## Tipografía

- Fuente única: **Press Start 2P** (`assets/fonts/PressStart2P-Regular.ttf`,
  licencia SIL OFL 1.1 en `assets/fonts/OFL.txt`). Familia en Dart:
  `RetroTheme.fontFamily`.
- La fuente está dibujada en una grilla de 8 px: los tamaños son siempre
  múltiplos de 8 (8, 16, 24, 32) para que no se vea borrosa.
  - 8 px: texto chico (stats secundarios, etiquetas).
  - 16 px: texto normal, botones, diálogos.
  - 24 px: títulos de pantalla.
  - 32 px: títulos grandes (pantalla de inicio).
- Interlineado 1.5 para que el texto pixelado respire.
- Cambiar de fuente = reemplazar el `.ttf` y el bloque `fonts:` de
  `pubspec.yaml`; ningún widget nombra la fuente directamente.

## Paleta

Paleta corta de 8 colores. Ningún widget usa colores fuera de esta lista
(`RetroPalette`).

| Nombre      | Hex       | Uso                                   |
|-------------|-----------|---------------------------------------|
| `night`     | `#0F0F1B` | Fondo de pantalla                     |
| `panel`     | `#1D2B53` | Fondo de cajas, paneles y botones     |
| `panelDark` | `#111A33` | Sombra dura / botón presionado        |
| `ink`       | `#FFF1E8` | Texto y bordes                        |
| `muted`     | `#8B93AF` | Texto deshabilitado o secundario      |
| `gold`      | `#FFCC33` | Acento: selección, foco, oro, crítico |
| `red`       | `#E43B44` | Vida, daño, peligro                   |
| `green`     | `#63C74D` | Curación, éxito                       |

## Formas

- Sin esquinas redondeadas (radio 0) y sin elevación ni sombras suaves.
- Bordes sólidos de 4 px en color `ink` para cajas y botones (2 px en
  elementos chicos como campos de texto).
- Profundidad con **sombra dura**: un bloque `panelDark` desplazado 4 px
  abajo-derecha, nunca difuminado.
- Selección y foco: el borde pasa a `gold`.
- Sin animaciones de ondas (ripple) de Material: el feedback al tocar
  es el cambio instantáneo de color.

## Caja de diálogo (`RetroPanel`)

La caja estilo JRPG clásico para menús, diálogos y paneles de stats:
fondo `panel`, borde exterior `ink` de 4 px, línea interior `night` de
2 px y sombra dura. Padding interno de 16 px.

## Texto y la fuente

Press Start 2P no tiene flechas, `★`, `₵` ni las MAYÚSCULAS acentuadas
(dibuja "MISIÓN" como "MISIóN"). Todo texto de UI que pueda traerlas pasa
por `retroText` (`lib/app/theme/retro_text.dart`), que las cambia por
equivalentes (`>`, `*`, `$`, `A E I O U`). Las minúsculas acentuadas, `ñ`
y `¡ ¿` sí existen.

## Botón compacto (`RetroTheme.compactButton`)

Para paneles y HUD, donde el botón de 16 px ocupa demasiado: texto de
8 px, padding 8 px, alto mínimo 32 px y borde de 2 px (`ink`, `gold` con
foco/hover, `muted` deshabilitado). `PanelButton`
(`lib/app/theme/panel_frame.dart`) lo aplica y acepta un color de acento
(p. ej. `green` para "¡LISTO!").

## Barras (`RetroBar`)

`lib/app/theme/retro_bar.dart`: fondo `night`, borde `ink` de 2 px y
relleno sólido. Vida `green` (enemigos `red`, jefes/élites `gold`), maná
`muted`, ULT `gold`. Alto 16 px en batalla y 10 px en el HUD.

## Panel sobre el mapa (`PanelFrame`)

`lib/app/theme/panel_frame.dart`: `RetroPanel` con borde `gold`,
centrado, ancho máximo 760 px (o el que se pida) y alto máximo 86% de la
pantalla, título de 16 px en `gold`, contenido de 8 px con scroll y los
botones compactos abajo a la derecha. Lo usan el mostrador, la
preparación, el personaje, la armería y el resultado. `ComingSoon`
muestra "X: próximamente." en `muted` para lo que todavía no existe.

## HUD

Overlays Flutter sobre el mapa con `RetroPanel` de padding 8 y texto de
8 px; el jugador local tiene el borde `gold`. Los avisos de interacción
(`[E] ...`) van en 16 px `gold`. Detalle de qué va dónde:
docs/specs/exploration.md § "HUD".

## Arte vs. chrome

Los colores de tiles, muebles, objetos, minimapa y actores del mapa
vienen del prototipo (`THEMES`, `drawTile`, ...) y son **arte**: no pasan
por `RetroPalette` (como los PNG de sprites). La regla de "solo 8
colores" aplica al chrome (paneles, botones, textos de interfaz).
