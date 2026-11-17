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
- Pendiente: una pasada dedicada de UX de menús (mostrador, preparación,
  armería, herrería/fusión, personaje) aplicará este principio; hasta
  entonces los paneles conservan su estructura actual.

## Tipografía

- Fuente única: **Press Start 2P** (`assets/fonts/PressStart2P-Regular.ttf`,
  licencia SIL OFL 1.1 en `assets/fonts/OFL.txt`). Familia en Dart:
  `RetroTheme.fontFamily`.
- Tamaños múltiplos de 8 (8, 16, 24, 32) para que no se vea borrosa. El
  prototipo usa 7-10 px en el HUD: el puerto usa 8 (los 7 px del HTML
  también van en 8).
- `<b>` del prototipo = `FontWeight.bold` (el navegador también lo
  sintetiza: la fuente no trae negrita).
- Interlineado: `.pbox` 1.6, `#tip` 1.8, paneles 1.8; el resto 1.5.
- Cambiar de fuente = reemplazar el `.ttf` y el bloque `fonts:` de
  `pubspec.yaml`; ningún widget nombra la fuente directamente.

## Paleta (`ProtoColors`, `lib/app/theme/proto_colors.dart`)

Todos los hex que usa el prototipo en la UI HTML:

| Constante | Hex | Dónde (prototipo) |
|---|---|---|
| `bg` | `#0B0E1A` | fondo de `body`, `#tip` (`f5` de alfa) |
| `ink` | `#E8ECFF` | texto base |
| `panel` | `#121936` | `.pbox`, `.panel`/`#menu` (`ee` de alfa) |
| `panelBorder` | `#2E3B6B` | borde de `.pbox`, `.mrow`, canvas |
| `button` | `#22305A` | fondo de `button` |
| `buttonBorder` | `#5B74C9` | borde de `button` y `.panel`, líneas |
| `buttonHover` / `buttonHoverBorder` | `#2E4280` / `#9FB4FF` | `button:hover` |
| `input` / `inputBorder` | `#0F1530` / `#3A4A85` | `input` |
| `gold` | `#FFD166` | `<b>` del tip y menú, créditos, `.me`, `▶ SU TURNO`, títulos `h2` |
| `sky` | `#9FB4FF` | `.k` del tip, clase/nivel, DEF/VEL, `small` |
| `dim` | `#7D8BC4` | `.help`, XP/créditos, "Turno en N", crítico estimado |
| `chat` | `#C8D2FF` | `#chatlog` |
| `green` | `#7BED9F` | `.sys`, misión, curas, requisitos ok, `TIENES`, ♥ pociones |
| `hp` | `#2ED573` | relleno `.hp` |
| `mp` | `#1E90FF` | relleno `.mp` |
| `barBg` | `#222A48` | fondo `.bar` |
| `ice` | `#74B9FF` | MP de técnicas, DEF de escudo, ✦ éter, Congelación |
| `red` | `#FF6B81` | `#err`, requisitos que faltan, `+% crít`, tiempo ≤ 10 s |
| `crimson` | `#FF4757` | timer ≤ 10 s del menú, crítico recibido |
| `orange` | `#FF9F43` | arma (`⚔`), `(fusión)`, avisos naranjas |
| `amber` | `#FF9F1C` | borde de `button.dual` |
| `pink` | `#E84393` | ULT lista, nombre de ULT en tips |
| `violet` | `#A29BFE` | barra/texto ULT cargando |
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
`#9FB4FF`; deshabilitado al 35% de opacidad. Botón grande: texto 16 px,
padding 16. Botón compacto (`RetroTheme.compactButton`, paneles y HUD):
texto 8 px, padding 8, alto mínimo 32. `PanelButton` acepta un color de
acento (p. ej. `green` para "¡LISTO!", como el borde/texto verde del
prototipo).

## Caja (`RetroPanel`)

`.panel` del prototipo: fondo `panel` con alfa `ee`, borde 3 px
`#5B74C9` (dorado `#FFD166` si está seleccionada / es el menú de
batalla). Padding interno de 16 px por defecto.

## Caja de jugador (`PartyBox`, `.pbox`)

`lib/app/theme/party_box.dart`: fondo `#121936`, borde 2 px `#2E3B6B`
(`#FFD166` el jugador local), padding 6, ancho 200 (170 en el HTML a
7-8 px), interlineado 1.6, opacidad 0.5 si está K.O. Contenido en
docs/specs/exploration.md § "HUD" y § "Batalla".

## Barras (`RetroBar`)

`.bar`: fondo `#222A48`, sin borde, alto 6 px (ULT 5 px), relleno sólido:
vida `#2ED573`, maná `#1E90FF`, ULT `#A29BFE` (`#E84393` al 100%).

## Panel sobre el mapa (`PanelFrame`)

`RetroPanel` (borde `#5B74C9`), centrado, ancho máximo 760 px (o el que
se pida) y alto máximo 86%, título `h2` de 16 px en `#FFD166`, contenido
de 8 px (interlineado 1.8) con scroll y los botones compactos abajo a la
derecha. `header` es una fila fija entre el título y el scroll.

Piezas (mismo archivo):
- `PanelButton(reason: ...)`: deshabilitado con el motivo en `dim` a la
  izquierda; `selected` pinta el borde `gold`.
- `PanelTabs`: fila de `PanelButton`, la pestaña activa en `gold`.
- `PanelSection`: `h2` chico, 8 px `gold`.
- `PanelRow`: `.mrow`, borde 2 px `#2E3B6B`, padding 8; `tooltip` en
  markup.
- `RetroTooltip`: el `#tip`: fondo `#0B0E1A` (alfa `f5`), borde 2 px
  `#FFD166`, padding 8×10, texto 8 px `#E8ECFF` interlineado 1.8, ancho
  máximo 360, sombra `0 4 18 #000a`; `<b>` dorado y `.k` `#9FB4FF`.
  Aparece sin espera al pasar el mouse.

## Campos de texto

`input`: relleno `#0F1530`, borde 2 px `#3A4A85` (`#FFD166` con foco),
sin radio, texto 8 px, pista en `dim`, `counterText` vacío.

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
