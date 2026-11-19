# Spec: Estilo visual pixel art (UI 1:1 con el prototipo)

Fuente de verdad: el `<style>` y el DOM del prototipo
`ecos-del-tiempo.html` (líneas 1-108) y los textos HTML que arma el JS
(`hud()`, `descSkill`, `weaponTip`, `renderPanel`, `addChat`, ...).

Implementación: `lib/app/theme/retro_theme.dart` (tema global y
`RetroPalette`), `lib/app/theme/proto_colors.dart` (paleta del
prototipo), `lib/app/theme/proto_markup.dart` (HTML chico → `TextSpan`),
`lib/app/theme/retro_panel.dart`, `retro_bar.dart`, `panel_frame.dart`.

## Regla general

**La UI es pixel art y copia 1:1 colores, pesos y estilos del
prototipo.** No hay límite de colores: donde el prototipo pinta un texto,
un borde o una barra de un color, el puerto usa ese mismo hex
(`ProtoColors`). Se mantienen la fuente pixel (Press Start 2P) y el
dibujo nítido (sin difuminados ni ripples, `FilterQuality.none` en los
sprites).

`RetroPalette` queda como constantes de conveniencia para el chrome
neutro, con los valores del prototipo (ver § "Paleta"); no es una regla.

## Principio: menús minimalistas y que se entiendan

Pedido del dueño: "todos los menús minimalistas, con UX/UI cómoda, que
se entienda bien qué es cada cosa y cómo funcionan las fusiones, las
mejoras, etc." Se concilia con el 1:1 así:

- Se mantiene el lenguaje visual del prototipo (colores, barras, texto
  coloreado, fuente pixel).
- Cada pantalla tiene un solo propósito claro.
- Cada mecánica lleva una explicación corta en línea (una línea "qué
  hace" bajo el título de la sección): qué hace la fusión, la herrería,
  las mejoras, cuánto cuesta y una vista previa del resultado antes de
  confirmar.
- Toda acción deshabilitada dice por qué (`PanelButton(reason: ...)`).
- Lista compacta a un lado y detalle / vista previa al otro; costo y
  resultado (antes → después) visibles antes de confirmar.
- Un `[?]` junto al título de cada panel con la ayuda de la pantalla.
- Botón primario abajo a la derecha; secundarios a su izquierda; los
  que reinician o cancelan, abajo a la izquierda.
- Teclado igual en todos los paneles: `Esc` cierra, `Tab` / flechas
  mueven el foco, `Enter` confirma.
- Esqueleto y piezas: docs/specs/panels.md § "Marco común".

## Menús: lista + detalle (v0.5)

Pedido del dueño (v0.5): "la accesibilidad y experiencia aplica para
todos los menús, como por ejemplo el de la fusión, que mucho texto y
tenés que bajar para ver qué habilidad elegir". Mismos principios que
el menú de batalla aprobado (lista de categorías │ acciones de una línea
con el costo a la derecha │ descripción corta + `Enter Confirmar · Esc
Volver`):

- **No bajar para encontrar la elección.** Las opciones son filas de
  **una línea** (`MenuRow`, `lib/app/widgets/menu_widgets.dart`):
  etiqueta a la izquierda (se corta con "…") y el valor alineado a la
  derecha (costo, nivel, `EQUIPADA`, o el motivo en rojo si no se
  puede; nunca más de la mitad de la fila). Los grupos llevan la
  etiqueta en una columna al costado (`MenuGroup`), no en una línea
  propia. Las elecciones que dependen de otra van **justo debajo** de
  la elegida, con sangría (p. ej. las habilidades del arma origen).
- **Detalle al costado, no párrafos arriba.** La explicación de la fila
  con mouse / foco / elegida va en el panel de detalle
  (`PanelDetail`); arriba de la lista, como mucho, **una** línea
  (`PanelHint`). El texto largo vive en el `[?]`.
- **Pasos.** Los asistentes muestran las migas (`StepCrumbs`), solo las
  opciones del paso actual y el resumen de lo elegido arriba del
  detalle; el resultado (`ANTES → DESPUÉS`, lo que gastás y lo que
  perdés) se ve siempre, y lo primero que se lee es lo que cuesta.
- **Filtros de una línea.** Un filtro de N opciones es un selector
  `Familia ‹ MAGA ›` (`ChoiceCycler`), no una fila de N botones.
- **Teclas iguales.** `Enter` / clic elige o confirma, `Esc` vuelve (un
  paso en los asistentes; cierra el panel si no hay paso atrás); la
  línea `KeyHints` lo recuerda al pie del detalle. Toda acción
  deshabilitada dice su motivo en una línea (`PanelButton(reason:)`).
- **Tamaño del texto.** Nada de tamaños de fuente a mano: tokens
  `RetroType`; anchos que dependen del texto con `RetroType.width` /
  `RetroType.em`; alturas de una línea con `RetroType.line` × el tamaño
  escalado. A 1280×720 nada desborda en Normal / Grande / Muy grande.
- Piezas (`lib/app/widgets/menu_widgets.dart`): `MenuRow`, `MenuGroup`,
  `MenuHeader`, `StepCrumbs`, `ChoiceCycler`, `KeyHints`, `InfoLine`
  (`Etiqueta  valor` con la etiqueta en columna).

## Tipografía

Dos fuentes pixel, las dos SIL OFL 1.1:

| Fuente | Archivo | Licencia | Para |
|---|---|---|---|
| **VT323** (`RetroType.bodyFamily`) | `assets/fonts/VT323-Regular.ttf` (google/fonts `ofl/vt323`) | `assets/fonts/OFL-VT323.txt` | texto de lectura: tooltips, fichas, chat, descripciones, ayudas (`PanelHint`), filas de menús, ventana de comandos y log de batalla, tarjetas del grupo, HUD |
| **Press Start 2P** (`RetroType.pixelFamily` = `RetroTheme.fontFamily`) | `assets/fonts/PressStart2P-Regular.ttf` | `assets/fonts/OFL.txt` | títulos, botones, pestañas, encabezados, cifras de las barras, etiquetas cortas |

- `<b>` del prototipo = `FontWeight.bold` (negrita sintetizada).
- Ningún widget nombra el `.ttf`: familias en `pubspec.yaml` (`fonts:`).
- Lo que VT323 no tiene (`→ ← ★ ♥ ▶ ▲ ▼ ♦`) sale de Press Start 2P
  (`RetroType.bodyFallback`); en el markup (`protoSpan`) esos símbolos
  van en `RetroType.label` para no salir más grandes que el texto.

### Por qué VT323 (v0.5)

El dueño pidió letra más grande ("muy pequeñas") y nítida ("como baja
resolución"); la primera prueba (Jersey 10) le pareció "muy gorda" y
"fosforescente". Se compararon con el mismo tooltip, a Normal y 100 %,
Press Start 8, Jersey 10, Pixelify Sans, Silkscreen, VT323, Micro 5,
DotGothic16 y Handjet Light; el dueño eligió **VT323** (hoja "1-E":
estilo azul actual + VT323):

- Trazos finos de terminal, monoespaciada (0.4 em por letra: 8 px a
  20 px, el mismo ancho por letra que Press Start a 8: los layouts
  entran), mayúsculas de 11 px a 20 px, acentos, ñ, ¿ ¡ completos.
- Filas de 40/1000 em (exacta a 25 px) y columnas "corridas" a propósito
  (imita el haz del CRT): no tiene grilla horizontal exacta; se usa en px
  enteros.
- Descartadas: Jersey 10 (pesada), Silkscreen (todo mayúsculas), Micro 5
  (fina e ilegible), Pixelify Sans (redondeada, fuera de grilla),
  DotGothic16 (2 MB por los glifos japoneses), Handjet (borrosa).

### Escala (tokens `RetroType`, `lib/app/theme/retro_type.dart`)

Los widgets **no escriben tamaños a mano**. Tamaños **nominales**: el
real lo pone `RetroTextScaler` (abajo). El tamaño nominal decide la
fuente (`RetroType.style(size)`, `familyFor`).

| Token | Nominal | Fuente | Real a 100 % (Normal / Grande / Muy grande) | Uso |
|---|---|---|---|---|
| `small` | 10 | VT323 | 20 / 25 / 30 | texto de lectura (`bodySmall` / `labelSmall` del tema, `smallStyle`) |
| `body` | 11 | VT323 | 20 / 25 / 30 | lectura destacada |
| `label` | 9 | Press Start 2P | 8 / 16 / 16 | botón compacto, cifras de barras, `?` de ayuda, letras de casillas |
| `title` | 16 | Press Start 2P | 16 / 16 / 16 (24 a 150 %) | `h2` de panel, botón grande, avisos `[E]` |
| `heading` | 24 | Press Start 2P | 24 | encabezados |
| `display` | 32 | Press Start 2P | 32 | `¡VICTORIA!`, título |

Interlineado de lectura `RetroType.line` = 1 (ascenso + descenso de
VT323); Press Start 1.5. Para anchos: `RetroType.em(context, n, size:)`
(Press Start: 1 em por glifo; VT323: 0.4 em) y
`RetroType.width(context, base)` (`base` para Normal a 100 %, agrandado
como el texto, nunca achicado). Texto en casillas de tamaño fijo:
`textScaler: RetroType.fixedScaler(context)`.

### Tamaño del texto y nitidez (`RetroTextScaler`)

Un solo `TextScaler` (`MaterialApp.builder` → `RetroTextScale`, overlays
incluidos) con el ajuste "Tamaño del texto" y la escala de Windows (la UI
no se agranda con la ventana, solo el mundo: settings.md § 3.1).

- **VT323** (lectura): 20 × factor (20 / 25 / 30 px lógicos) llevado a px
  físicos enteros (a 150 %: 30 / 38 / 45 físicos).
- **Press Start 2P** (resto): tamaño buscado (texto < 16 × factor,
  títulos + 8 × (factor − 1)) llevado al múltiplo de 8 px físicos de
  arriba (2 px de tolerancia, mínimo 8): su grilla es de 8 × 8.

Las cajas de los tooltips caen en px físicos enteros (si no, la fuente se
ve corrida medio píxel).

### Tooltips (`RetroTooltip` / `RetroHoverCard`)

Una sola caja (`lib/app/theme/retro_hover_card.dart`): `RetroTooltip`
(texto en markup) aparece debajo del objetivo, centrada (arriba si no
entra); `RetroHoverCard` (widgets, p. ej. la comparación de armas) a la
derecha. Nunca se sale de la pantalla. Si el texto es más alto que la
pantalla, `RetroTipText` lo reparte en columnas cortando en los `<br>`
(`protoSplitLines` cierra y reabre las etiquetas abiertas); como último
recurso la caja se achica lo justo para entrar (nunca recorta). Ancho
máximo del texto: `RetroHoverCard.textWidth` (400 en Normal) agrandado
con el texto. La comparación del inventario, con factor ≥ 1.5, pasa a
dos columnas (arma | qué cambia, con el nombre de la equipada).

**Uno solo a la vez (v0.9.7).** Había un bug: si cambiaba la pantalla
con el mouse quieto (termina una pelea y aparece otra pantalla) quedaba
la caja vieja y al mover el mouse aparecía otra: se veían dos. Ahora
`RetroHoverCard` guarda la caja visible (`_active`): abrir una cierra la
anterior; una caja se cierra cuando su widget sale del árbol
(`deactivate`) y cuando su ruta deja de ser la de arriba
(`ModalRoute.isCurrent`, no se abre en una ruta tapada).
`RetroHoverCard.dismissAll()` la cierra a mano (el menú contextual lo
usa). Test: `test/app/retro_hover_card_test.dart`.

### Tooltips cortos con detalle desplegable (v0.9.7)

Pedido del dueño: "hay demasiado texto". Por defecto un tooltip muestra
**lo esencial** (nombre, números clave) y las explicaciones largas van
**plegadas** en líneas `▸ Título` (`sky`; `▼` abierta) que se despliegan
de a una, como los plegables de misiones, chat y tarjetas. Nada se borra:
se pliega.
- `RetroTipFold` (una sección) y `RetroTipFolds` (resumen + secciones;
  las vacías no se dibujan), en `retro_hover_card.dart`. Clic, `Enter` o
  `Espacio` (enfocables) despliegan.
- **Caja fija**: para poder hacer clic, una caja con plegables es
  `interactive`: toma el mouse y, al salir del objetivo, espera
  `RetroHoverCard.pinDelay` (220 ms) por si el mouse va a la caja;
  mientras el mouse está encima queda fija. Se cierra al salir de las
  dos. Las cajas sin plegables siguen sin tomar el mouse.
- `RetroTooltip(foldAfter: n, foldTitle: ...)`: las primeras `n` líneas
  (`<br>`) a la vista y el resto en `▸ Más detalle`.
- Dónde (primero donde más pesa): ficha de arma del inventario
  (`itemTipParts`: nombre, rareza · tipo · nivel, requisitos, ATQ / MAG
  y la línea `Mods 2/4 · Pasiva · 3 habilidades · Pesada`; plegadas
  `Mods`, `Pasiva`, `Habilidades`, `Peso y forja`, `Historia`), las dos
  fichas de la comparación del mouse (la diferencia `Si la equipas:`
  queda a la vista), chips de habilidad (`foldAfter: 3`: nombre, tipo y
  el primer efecto) y estados de batalla (`foldAfter: 1`, `▸ Qué hace`).
- Las líneas de ayuda de los paneles (`PanelHint`) largas (≥ 160 letras)
  muestran la primera oración y el resto en `▸ Más`.

Interlineado: paneles, tooltips, `.pbox` y chat `RetroType.line`.

## Paleta (`ProtoColors`, `lib/app/theme/proto_colors.dart`)

**v0.8.1:** los valores de abajo son los del tema AZUL. Los tokens de
interfaz son `ThemeColor` y cambian con TEMA DE INTERFAZ (AZUL / OSCURO
/ ALTO CONTRASTE); con COLORES DEL TEXTO REDUCIDO el markup se pinta por
roles (`title`, `body`, `muted`, `accent`, `positive` / `negative`) y
ESPACIADO AMPLIO suma aire y separadores. Tablas y reglas:
docs/specs/accessibility.md § 8.

Todos los hex que usa el prototipo en la UI HTML:

| Constante | Hex | Dónde (prototipo) |
|---|---|---|
| `bg` | `#0B0E1A` | fondo de `body`, `#tip` (`f5` de alfa) |
| `ink` | `#B0BAE5` (prototipo `#E8ECFF`, suavizado) | texto base |
| `panel` | `#121936` | `.pbox`, `.panel`/`#menu` (`ee` de alfa) |
| `panelBorder` | `#2E3B6B` | borde de `.pbox`, `.mrow`, canvas |
| `button` | `#22305A` | fondo de `button` |
| `buttonBorder` | `#5B74C9` | borde de `button` y `.panel`, líneas |
| `buttonHover` / `buttonHoverBorder` | `#2E4280` / `#9FB4FF` | `button:hover` |
| `input` / `inputBorder` | `#0F1530` / `#3A4A85` | `input` |
| `gold` | `#D3AC4F` (prototipo `#FFD166`, suavizado) | `<b>` del tip y menú, créditos, `.me`, `▶ SU TURNO`, títulos `h2` |
| `sky` | `#8FA1DF` (prototipo `#9FB4FF`, suavizado) | `.k` del tip, clase/nivel, DEF/VEL, `small` |
| `dim` | `#929ABA` (prototipo `#7D8BC4`, suavizado AA) | `.help`, XP/créditos, "Turno en N", crítico estimado |
| `chat` | `#C8D2FF` | `#chatlog` |
| `green` | `#5EB77A` (prototipo `#7BED9F`, suavizado) | `.sys`, misión, curas, requisitos ok, `TIENES`, ♥ pociones |
| `hp` | `#2ED573` | relleno `.hp` |
| `mp` | `#1E90FF` | relleno `.mp` |
| `barBg` | `#222A48` | fondo `.bar` |
| `ice` | `#77A7D7` (prototipo `#74B9FF`, suavizado) | MP de técnicas, DEF de escudo, ✦ éter, Congelación |
| `red` | `#DB828F` (prototipo `#FF6B81`, suavizado) | `#err`, requisitos que faltan, `+% crít`, tiempo ≤ 10 s |
| `crimson` | `#DB8289` (prototipo `#FF4757`, suavizado AA) | timer ≤ 10 s del menú, crítico recibido |
| `orange` | `#D1975F` (prototipo `#FF9F43`, suavizado) | arma (`⚔`), `(fusión)`, avisos naranjas |
| `amber` | `#FF9F1C` | borde de `button.dual` |
| `pink` | `#CF85A8` (prototipo `#E84393`, suavizado AA) | ULT lista, nombre de ULT en tips |
| `violet` | `#9E99E0` (prototipo `#A29BFE`, suavizado) | barra/texto ULT cargando |
| `cream` | `#FFEAA7` | Protege, aturdir del Paladín |
| `holy` | `#FFF3B0` | Sagrado |
| `mint` | `#55EFC4` | Regeneración |
| `burn` | `#FF7B29` | Quemadura |
| `taunt` | `#FF7675` | Provoca |
| `titleShadow` | `#A3471D` | sombra del título y del rango |

Colores de estado (`STATUS[k].col`): Quemadura `#FF7B29`, Veneno
`#7BED9F`, Congelación `#74B9FF`, Aturdido `#FFEAA7`, Sagrado `#FFF3B0`,
Regeneración `#55EFC4` (`statusColor` en
`features/combat/presentation/scene/fx_style.dart`). Colores de cada
habilidad (`SK[].col`) en `kSkillColors` del mismo archivo.

`RetroPalette` (conveniencia, mismos valores): `night` = `bg`, `panel` =
`panel`, `panelDark` = `input`, `ink` = `ink`, `muted` = `dim`, `gold` =
`gold`, `red` = `red`, `green` = `green`.

## Texto rico (`ProtoMarkup` / `ProtoText`)

`lib/app/theme/proto_markup.dart` convierte el subconjunto de HTML que
arma el prototipo en `TextSpan`, para copiar los textos tal cual:

- `<b>` → negrita (y el color de negrita del contexto: dorado en el tip y
  el menú); `<b style="color:#hex">`.
- `<span style="color:#hex">`, `<span class="k">` (= `sky`),
  `<span class="sys">` (= `green`), `<small>` (= `sky`).
- `<br>` → salto de línea; `&nbsp; &amp; &lt; &gt; &quot; &#39;`.
- Cada trozo de texto pasa por `retroText`. Los nombres de jugadores se
  escapan con `protoEsc` (como `esc` del prototipo).

`ProtoText(markup)` es el widget (`Text.rich`); `protoSpan(markup)` da el
`TextSpan`. Lo usan tooltips, menú de batalla, cajas del grupo, chat y
paneles.

## Sin pesos (v0.5.1)

Nada va en negrita: las fuentes pixel no tienen negrita y la sintética
las "engorda". `<b>` del markup resalta **solo con color** (el
`boldColor` del widget o `gold`); ningún `TextStyle` pide `FontWeight`
mayor que 400. Por si alguno se escapa, el pubspec registra el peso 700
de las dos familias con el mismo archivo regular (sin negrita sintética).
Test: `test/app/label_scale_test.dart`.

## Etiquetas en el mundo (v0.5.1)

Nombres sobre los personajes, carteles del pueblo (`MOSTRADOR DE
MISIONES`, `ARMERÍA`, `PORTAL`, `ESTATUA DEL TIEMPO`, `TIENDA`), puertas
de zona, `★ÉLITE` / `JEFE` / `!`, avisos (`floor`, caída) y las
etiquetas del loot del piso: se anotan al dibujar el mundo
(`ActorPainter.labelSink`, `MapLabel`) y se dibujan después en px de
**pantalla** con `PixelLabelPen` (`lib/app/theme/pixel_label.dart`): Press
Start 2P a 8·u (u = 1 hasta ×2 del mundo, 2 desde ahí; 16·u los de 8 px
o más), sombra negra de 1 px (2 desde 16 px), posición redondeada. Es el
mismo estilo de los nombres de la batalla. Nunca en el lienzo virtual
que se agranda (eso las hacía gordas y borrosas). La caja del loot se
arma alrededor del texto nítido, centrada donde la ubicó el mundo.

## Texto y la fuente

Press Start 2P tiene `★ → ← ♥ ▶ ♦ • — … · × ½` pero no emojis, `✦ ⚔ ⏱
⏳ ✔ ✘ ₵ ✝ 🛡`, ni dibuja bien las MAYÚSCULAS acentuadas ("MISIóN").
`retroText` (`lib/app/theme/retro_text.dart`) cambia lo que falta:
`₵` → `$`, `✦` → `♦`, `⏳` → `(retrasa)`, `✔` → `ok`, `✘` → `x`,
`⚔ ⏱ 🛡` se quitan, `▸` → `>`, `−` → `-`, y las mayúsculas acentuadas →
sin acento. Los iconos de estado (`🔥 ☠ ❄ 💫 ✝ ✚`) se escriben con la
letra del estado (`STLET`: `Q V C A S R`) en su color, igual que las
insignias del canvas.

## Formas

- Bordes y fondos del prototipo; esquinas rectas (radio 0) para que el
  borde se vea pixelado (el prototipo usa 3-6 px de radio: es el único
  desvío visual).
- Sin elevación ni sombras suaves salvo la del `#tip` (`0 4 18 #000a`).
- Sin animaciones de ondas (ripple) de Material: el feedback es el cambio
  instantáneo de color.

## Botones (`RetroTheme`)

`button` del prototipo: fondo `button` `#22305A`, borde 2 px
`buttonBorder` `#5B74C9`, texto blanco; hover fondo `#2E4280` y borde
`#9FB4FF`; deshabilitado al 35% de opacidad. Botón grande: texto `title` (16 px),
padding 16. Botón compacto (`RetroTheme.compactButton`, paneles y HUD):
texto `small`, padding 8, alto mínimo 32. `PanelButton` acepta un color de
acento (p. ej. `green` para "¡LISTO!", como el borde/texto verde del
prototipo).

### Padding de botones (regla mínima, v0.9.7)

Pedido del dueño: "los textos pegan al borde". Todo botón deja **al
menos 8 px libres entre el borde y el texto**, en los cuatro lados
(`RetroTheme.minButtonInset`). Material pinta el borde encima del
padding, así que el padding real es `RetroTheme.buttonPadding(inset)` =
`max(inset, 8) + UiTheme.buttonBorderWidth` (2 px; 3 en ALTO CONTRASTE).
Valores: compacto 8 libres (10 / 11 px de padding), grande 14 libres,
`ConfirmButton` 10 libres. Un botón nuevo con estilo propio usa
`buttonPadding`, nunca un `EdgeInsets` suelto menor. Los menús de
acciones (`InventoryActionList`) usan el mismo aire a los lados.
Verificado con `test/app/text_size_test.dart` en los cuatro tamaños de
texto (la vista CASILLAS del filtro de loot pasa a scroll cuando el alto
no alcanza).

## Caja (`RetroPanel`)

`.panel` del prototipo: fondo `panel` **opaco** (v0.5.1; el prototipo usa alfa `ee` y se leía el mapa detrás), borde 3 px
`#5B74C9` (dorado `#FFD166` si está seleccionada / es el menú de
batalla). Padding interno de 16 px por defecto.

## Caja de jugador (`PartyBox`, `.pbox`)

`lib/app/theme/party_box.dart`: fondo `#121936`, borde 2 px `#2E3B6B`
(`#FFD166` el jugador local), padding 6, ancho 230 en Normal (170 en el
HTML a 7-8 px; crece con el texto, `PartyBox.widthOf`), texto `small`,
interlineado 1.6, opacidad 0.5 si está K.O. En el HUD del mapa, si con
texto grande no entran en una fila sin pisar el chat, pasan a dos. Contenido en
docs/specs/exploration.md § "HUD" y § "Batalla".

## Barras (`RetroBar`)

`.bar`: fondo `#222A48`, sin borde, alto 6 px (ULT 5 px), relleno sólido:
vida `#2ED573`, maná `#1E90FF`, ULT `#A29BFE` (`#E84393` al 100%).

## Panel sobre el mapa (`PanelFrame`)

`RetroPanel` (borde `#5B74C9`), centrado, ancho máximo 760 px (o el que
se pida, agrandado con el tamaño del texto hasta la pantalla) y alto
máximo 86%, título `h2` `title` en `#FFD166`, contenido `small`
(interlineado 1.6) con scroll y los botones compactos abajo a la
derecha. `header` es una fila fija entre el título y el scroll.

`help` agrega el `[?]` (`PanelHelp`) al lado del título; `onClose` hace
que `Esc` cierre; `leading` son los botones de abajo a la izquierda;
`fill` hace que el panel ocupe el alto máximo y el contenido no tenga
scroll propio (para lista + detalle). El marco atrapa el foco del
teclado (docs/specs/panels.md § "Marco común").

Piezas (mismo archivo):
- `PanelButton(reason: ...)`: deshabilitado con el motivo en `dim` a la
  izquierda; `selected` pinta el borde `gold`.
- `PanelTabs`: fila de `PanelButton`, la pestaña activa en `gold`.
- `PanelSection`: `h2` chico, `small` `gold`.
- `PanelRow`: `.mrow`, borde 2 px `#2E3B6B`, padding 8; `tooltip` en
  markup.
- `RetroTooltip`: el `#tip`: fondo `#0B0E1A` (alfa `f5`), borde 2 px
  `#FFD166`, padding 8×10, texto `small` `#E8ECFF` interlineado 1.6, ancho
  máximo 400 (crece con el texto), sombra `0 4 18 #000a`; `<b>` dorado y
  `.k` `#9FB4FF`. Aparece sin espera al pasar el mouse (§ "Tooltips").

Piezas de `lib/app/theme/panel_widgets.dart`:
- `PanelHelp`: cajita `?` de 2 px `buttonBorder` con texto `sky`; al
  pasar el mouse, `RetroTooltip` con la ayuda.
- `PanelHint`: la línea "qué hace", `small` `dim` (markup).
- `PanelSplit`: lista (360 px, crece con el texto hasta la mitad del
  panel salvo `scaleList: false`; scroll propio) + detalle (`Expanded`).
- `PanelDetail`: caja del detalle (borde 2 px `panelBorder`, padding 8)
  con scroll y una fila fija abajo a la derecha (`footer`).
- `PanelListItem`: fila elegible (`.mrow`); borde `gold` si está elegida,
  `sky` con foco o mouse; se activa con clic, `Enter` o `Espacio`.
- `StatChange`: `ETIQUETA antes → después`, después en `green` si mejora
  y `red` si empeora (negrita).
- `LevelPips`: n cuadritos de 6 px (`gold` llenos, `barBg` vacíos).
- `CostLine`: `Costo $N · Te quedan $M` (si no alcanza, solo `Costo $N`:
  el `Faltan $X` lo dice el motivo del botón).

## Campos de texto

`input`: relleno `#0F1530`, borde 2 px `#3A4A85` (`#FFD166` con foco),
sin radio, texto `small`, pista en `dim`, `counterText` vacío.

## Árbol de pasivas

Usa los colores del `treeHtml` del prototipo (docs/specs/panels.md §
"Árbol").

## HUD

Overlays Flutter sobre el mapa; qué va dónde y en qué color:
docs/specs/exploration.md § "HUD". El menú y las cajas del grupo en
batalla: § "Batalla".

## Arte

Los colores de tiles, muebles, objetos, minimapa, actores y efectos
vienen del prototipo (`THEMES`, `drawTile`, `ELFX`, ...), igual que los
PNG de sprites.

## Historial de decisiones

- **v1** (scaffold): estilo "8 bits" con una paleta cerrada de 8 colores
  (`RetroPalette`, valores tipo PICO-8) para todo el chrome; los colores
  del prototipo solo para arte.
- **v2** (pedido del dueño: "la UI está rara, no es 1:1 como la de la
  web ... las letras ya no destacan de color"; "el estilo es pixel art,
  no te limites a 8 bits"): se elimina el límite de 8 colores. La UI
  copia 1:1 la paleta, los pesos y los textos coloreados del prototipo
  (`ProtoColors`, `ProtoMarkup`); `RetroPalette` pasa a ser conveniencia
  con los valores del prototipo. Se mantienen la fuente pixel y el
  dibujo nítido. Los bordes gruesos de 4 px con sombra dura del v1 se
  reemplazan por los bordes del prototipo (2-3 px, sin sombra).
- **v2.1** (dueño): principio de menús minimalistas y autoexplicativos
  (§ "Principio: menús minimalistas"), con el lenguaje visual del
  prototipo. La pasada de UX de menús queda como tarea aparte.
- **v3** (pasada de UX de menús): armería y preparación en pestañas
  (COMPRAR · FORJA · FUSIÓN · CONSUMIBLES) con lista + detalle; vista
  previa de fusión (habilidades resultantes, qué se pierde, costo) y de
  herrería (valor y stats antes → después); personaje con vista previa
  al costado y comparación de armas; mostrador con tarjetas de misión
  (objetivo y recompensas); `[?]` de ayuda, teclado y botón primario
  abajo a la derecha en todos los paneles.
- **v4** (v0.5, accesibilidad): escala tipográfica en tokens
  (`RetroType`, mínimo 10 px buscados en vez de 8), ajuste "Tamaño del
  texto" y tamaños llevados a la grilla de 8 px físicos para que la
  fuente pixel se vea nítida en cualquier escala de Windows; tooltips
  propios que nunca se salen de la pantalla (columnas). Segunda fuente
  pixel (VT323) para el texto de lectura (§
  "Tipografía"); colores de texto a contraste AA y señales que no son
  solo color (docs/specs/accessibility.md).
