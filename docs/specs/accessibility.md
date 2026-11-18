# Spec: Accesibilidad (v0.5)

Pedido del dueño: "esto tiene problema de accesibilidad, muy pequeñas",
"hay fonts que se ven súper mal, como baja resolución" y "trabajá la
accesibilidad más que todo". Prioridad de v0.5; lo que no entra queda en
§ 7 (próximo).

## 1. Texto legible y nítido

- **Segunda fuente pixel** para el texto de lectura (VT323, OFL; elegida
  por el dueño entre 8 candidatas) y Press Start 2P para títulos,
  botones y cifras. Por qué y tabla de
  candidatas: docs/specs/ui_style.md § "Tipografía".
- **Escala en tokens** (`RetroType`): ningún widget escribe tamaños; el
  mínimo de lectura es VT323 a 20 px (mayúsculas de 11 px) a 100 %
  (antes Press Start a 8: mayúsculas de 7).
- **Nitidez**: `RetroTextScaler` lleva cada tamaño a la grilla de su
  fuente según la escala de Windows (VT323: px físicos enteros;
  Press Start: múltiplo de 8 px físicos). Las cajas de tooltip caen en
  px físicos enteros.
- **"Tamaño del texto"** (Pausa / CONFIGURACIÓN → PANTALLA): Normal /
  Grande / Muy grande; settings.md § 3.6.
- **Filtro CRT**: NORMAL (por defecto) sin curvatura; la curva remuestrea
  la UI y ensucia la fuente (settings.md § 3.2).
- **Tooltips** que nunca se salen de la pantalla: columnas si son más
  altos que ella (ui_style.md § "Tooltips").
- **Árbol de pasivas**: los nombres de clusters se dibujan en px de
  pantalla con el texto de lectura (siguen el ajuste) y se ocultan con
  zoom < 0.55 (ahí serían ilegibles); si dos se pisan, queda uno
  (`TreeLabelsPainter`). Tooltip y buscador del árbol en `RetroType`.

## 2. Contraste y colores suavizados

Pedido del dueño: "los colores ... hacen que se vea muy fosforescente el
texto". Los colores de **texto** de `ProtoColors` se suavizaron (≈ mitad
de saturación, mismo tono) y todos siguen en **AA (≥ 4.5:1)** sobre los
fondos donde va texto: `bg` `#0B0E1A`, `panel` `#121936`, `input`
`#0F1530` y `button` `#22305A` (el más claro). El estilo azul de paneles
y tooltips no cambia.

| Token | Prototipo | Ahora | Sobre panel / botón |
|---|---|---|---|
| `ink` | `#E8ECFF` | `#B0BAE5` | 9.0 / 6.7 |
| `gold` | `#FFD166` | `#D3AC4F` | 8.0 / 6.0 |
| `sky` | `#9FB4FF` | `#8FA1DF` | 6.8 / 5.1 |
| `dim` | `#7D8BC4` | `#929ABA` | 6.2 / 4.6 |
| `green` | `#7BED9F` | `#5EB77A` | 7.0 / 5.2 |
| `red` | `#FF6B81` | `#DB828F` | 6.2 / 4.6 |
| `crimson` | `#FF4757` | `#DB8289` | 6.2 / 4.6 |
| `orange` | `#FF9F43` | `#D1975F` | 6.8 / 5.1 |
| `violet` | `#A29BFE` | `#9E99E0` | 6.6 / 4.9 |
| `pink` | `#E84393` | `#CF85A8` | 6.2 / 4.6 |
| `ice` | `#74B9FF` | `#77A7D7` | 6.8 / 5.1 |

El markup que todavía escribe el hex viejo se pinta con el token nuevo
(`ProtoColors.legacy` en `ProtoColors.parse`). Excepciones: texto
deshabilitado (opacidad baja, WCAG lo exime) y el arte del mundo
(canvas, que usa sus propios hex). Test: `test/app/contrast_test.dart`.
Pendiente: estilo de tooltip "PoE" (caja negra neutra, banda de rareza,
separadores; hoja "2-E") si el dueño lo pide.

## 3. Daltonismo: nunca solo el color

- **Mejora / empeora**: `StatChange` y la comparación de armas agregan
  ▲ (mejora) / ▼ (empeora) además del verde/rojo; la diferencia lleva
  su signo (`+9`, `-1.3`).
- **Rareza**: cada casilla de arma o Eco lleva la letra de la rareza
  arriba a la izquierda (C Común, M Mágico, R Raro, E Épico, L
  Legendario; `RarityColors.letter`) además del color del borde; la
  ficha dice la rareza en texto (`Legendario · varita · ...`).
- **Estados**: chips con texto (`Q3`, `Quemadura 3`, `Defiende`...) y en
  el canvas la letra del estado (`STLET`), no solo el color.
- **Requisitos**: el texto dice qué falta (`No cumples los requisitos`),
  no solo el rojo.

## 4. Movimiento y destellos (ya existentes)

SACUDIDA (sí/no) y DESTELLOS (normales/suaves/no) en PANTALLA
(settings.md § 3). Cubren la sacudida de golpes fuertes, el rojo de
"te pegaron fuerte", los blancos de golpe brutal y quiebre y el tinte
de "tiempo detenido". El CRT ya no curva en NORMAL y no parpadea (las
scanlines son fijas).

## 5. Tests

- `test/app/text_size_test.dart`: ajuste y JSON; tabla de grilla por
  escala (VT323 en px enteros, Press Start en múltiplos de 8),
  familia de cada token; nombres del árbol según el zoom;
  `protoSplitLines`; con las fuentes reales, a 1280×720 y DPR 1 y 1.5 en
  los tres tamaños: ficha de un Legendario, comparación del inventario,
  panel de personaje (atributos, inventario, árbol, filtro), menú de
  batalla y su tip, chat — sin desbordes y dentro de la pantalla.
- `test/app/contrast_test.dart`: AA de los tokens de texto.
- `test/features/settings_menu_test.dart`: TAMAÑO DEL TEXTO en vivo.

## 6. Batalla

Rediseño de la barra de batalla para legibilidad: docs/specs/
battle_presentation.md § "Barra de batalla (v0.5)".

## 7. Próximo (v0.5.1)

- Paletas para daltonismo (deuteranopía / protanopía / tritanopía) por
  tokens.
- Navegación por teclado completa de título, pausa y paneles (hoy:
  `Tab` / flechas / `Enter` en los paneles con `PanelFrame`).
- "Reducir movimiento": cinemáticas de ULT y de ascensión, zoom de
  cámara de las ULT.
- Opción de tiempo de turno (más largo / sin tiempo en solo; en co-op,
  el de la sala).
- Auditoría de tamaño mínimo de los objetivos clicables.
- Barras de vida y de quiebre de enemigos distinguibles sin color
  (patrón), etiquetas de loot en el mapa con letra de rareza.
