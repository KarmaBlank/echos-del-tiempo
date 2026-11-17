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
