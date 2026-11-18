# Spec: Accesibilidad (v0.5, v0.5.1, v0.8.1)

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
- **Ventanas grandes** (v0.5.1): la UI crece con la ventana
  (`RetroTextScale.windowFactor`, de a 0.25 hasta ×2: 1920×1080 → ×1.5,
  VT323 a 30 px) × TAMAÑO DEL TEXTO; settings.md § 3.
- **Etiquetas de la escena de batalla** (nombres, vida, estados,
  números flotantes, barras): Press Start a 8·u px de pantalla con
  `u = SceneGeometry.labelUnit` = máx(unidad de la escena, 2 × factor del
  texto): 16 px a 1280×720 Normal, 24 a 1920×1080; crecen con TAMAÑO DEL
  TEXTO. El log de arriba ("Turno de X") y su reloj van al múltiplo de 8
  más grande que entra en la banda.
- **Etiquetas del mundo** (v0.5.1): nombres sobre los personajes,
  carteles del pueblo, puertas de zona, avisos y loot del piso se dibujan
  en px de pantalla con `PixelLabelPen` (el estilo de los nombres de la
  batalla: fino, sombra de 1 px), no en el lienzo virtual agrandado
  (ui_style.md § "Etiquetas en el mundo").
- **Sin negritas**: las fuentes pixel no tienen negrita y la sintética
  las engorda; `<b>` resalta solo con color y una negrita que se escape
  usa la misma fuente (pubspec: peso 700 = el archivo regular).
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
Hecho en v0.8.1 como tema OSCURO + REDUCIDO + AMPLIO (§ 8).

## 3. Daltonismo: nunca solo el color

### MODO DALTÓNICO (v0.5.1)

ACCESIBILIDAD → MODO DALTÓNICO: NO / DEUTERANOPÍA / PROTANOPÍA /
TRITANOPÍA (`ColorVision`, settings.md § 3.8). Cambia por tokens
(`VisionPalette`, `lib/app/theme/vision_palette.dart`) los colores que
dicen algo, en toda la app:

| Slot (`VisionSlot`) | Dónde | NO | Deuter. | Protan. | Tritan. |
|---|---|---|---|---|---|
| `good` (`ProtoColors.green`) | mejora, cura, requisito, sistema | `#5EB77A` | `#6FA8E0` | `#6FA8E0` | `#4FBFB8` |
| `bad` / `crimson` (`red`, `crimson`) | empeora, error, falta | `#DB828F` | `#D9A24A` | `#D9A24A` | `#DB7F8A` |
| `hp` / `mp` | barras del grupo | `#2ED573` / `#1E90FF` | `#3D9BF0` / `#E0C341` | igual | `#2EC4B0` / `#E65FA8` |
| `heal` / `hurt` / `critHurt` | números flotantes | `#7BED9F` / `#FF6B81` / `#FF4757` | `#7CC4FF` / `#FFA94D` / `#FFD23C` | `#7CC4FF` / `#FFB347` / `#FFE14A` | `#5FE3D8` / `#FF6B81` / `#FF3D3D` |
| `enemyHp*` | vida de enemigos (normal, élite, jefe) | naranja / dorado / rojo | naranjas | ámbar | rojos |
| `breakBar` | barra y textos de QUIEBRE | `#FFE14D` | `#8FD8FF` | `#8FD8FF` | `#9FF0F0` |
| `enemyUlt` | carga y aviso de ULT enemiga | `#FF3355` | `#D040FF` | `#D040FF` | `#D040FF` |
| `magic` / `rare` / `epic` / `legendary` | rarezas (bordes, mapa, markup) | `#7896FF` / `#FFD23C` / `#BE6EFF` / `#FF8C28` | `#5C9AFF` / `#FFE14A` / `#F0B8FF` / `#E8782E` | … / `#D08A3A` | `#2FB8D8` / `#FFA0B4` / `#C77DFF` / `#FF6A4A` |

- `VisionColor` es `const` (los `const TextStyle(color: ProtoColors.red)`
  siguen compilando) y lee sus canales del modo activo al pintar. El
  markup y los colores de datos (rarezas del filtro de loot) que traen el
  hex por defecto pasan por `VisionPalette.remap` (en `ProtoColors.parse`,
  `RarityColors.filterColor` y `filterColor` del mapa). Un color propio
  del filtro del jugador no cambia.
- Cómo se eligieron: cada par que se tiene que distinguir (bien/mal,
  HP/MP, cura/daño, vida/quiebre, quiebre/ULT, las rarezas entre sí) tiene
  ΔE ≥ 20 con la simulación de Machado 2009 (severidad 1) de ese tipo de
  visión, y también con visión normal. La paleta normal no llega (p. ej.
  Mágico/Épico ΔE 1 en deuteranopía): por eso existe el modo. Los tokens
  de texto siguen en AA en todos los modos.
- Siguen siempre las señales que no son color: ▲/▼, letras de rareza,
  letras de estado, `+` en las curas, etiquetas `HP` / `QB`.
- Estados (Quemadura, Veneno…) no cambian de color: van con su letra.

### Barras de los enemigos sin color (v0.5.1)

En la escena, debajo del nombre: la **vida** es una barra lisa; la de
**quiebre** va rayada (un corte oscuro cada 3·u) y con un rombo de
cristal a la izquierda; la **carga de ULT** son 5 bloques separados. La
tarjeta del objetivo dice `HP` y `QB`.

### Señales que ya había (v0.5)

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

## 4. Movimiento y destellos

SACUDIDA (sí/no) y DESTELLOS (normales/suaves/no), ahora en
ACCESIBILIDAD (settings.md § 3). Cubren la sacudida de golpes fuertes,
el rojo de "te pegaron fuerte", los blancos de golpe brutal y quiebre,
el tinte de "tiempo detenido" y (v0.5.1) el blanco del impacto de una
ULT, el de la entrada a la arena y el de la ascensión. El CRT ya no curva
en NORMAL y no parpadea (las scanlines son fijas).

**REDUCIR MOVIMIENTO** (v0.5.1, settings.md § 3.8): apaga la sacudida,
deja los destellos a lo sumo SUAVES, saca parpadeos y zoom/paneo de
cámara, deja la arena quieta y cambia el barrido de bloques por un
fundido corto. El paso adelante (6 px) del que actúa se mantiene: dice
quién actúa. Los mapas del mundo (pulsos suaves de tiles y loot) no
cambian.

## 4.1 Tiempo de turno (v0.5.1)

JUEGO → TIEMPO DE TURNO: NORMAL (30 s) / LARGO (60 s) / SIN LÍMITE
(`TurnTimer`, `lib/game_engine/models/turn_timer.dart`). Lo aplica el
motor que corre la sala (`SessionEngine.battleTick` usa
`GameSession.turnLimit`; `null` = nunca pasa el turno por tiempo). Solo:
el ajuste local. Co-op: el del anfitrión (`SessionEngine.setTurnTimer` al
crear la sala y al cambiar el ajuste); viaja en el snapshot como `tt`
(opcional, solo si no es `normal`; un cliente viejo lo ignora). La barra
de tiempo de la batalla se llena con el límite de la sala; sin límite no
hay reloj ni tic-tac. Pueblo y preparación: `Turnos: sin límite
(anfitrión)`.

## 4.2 Objetivos clicables (v0.5.1)

Mínimo **24 × 24 px lógicos** a texto Normal (`MinHitTarget`,
`lib/app/theme/min_hit_target.dart`; auditoría en tests:
`smallHitTargets` de `test/app/hit_target_audit.dart`). Arreglados:
filas de la ventana de comandos de la batalla (20 → 25 px: el clic toma
también el hueco), sliders de volumen (12 → 28 px), `×` / `−5` / `+5` del
planificador de build (16×20 → 24×24), nodos del árbol de pasivas (el
área de clic es de ≥ 12 px de radio en pantalla con cualquier zoom; gana
el más cercano). Ya cumplían: botones (32 px), pestañas, casillas del
inventario, nodos del Atlas y del mini-árbol de ascensión, tarjetas del
pueblo.

## 5. Tests

- `test/app/text_size_test.dart`: ajuste y JSON; tabla de grilla por
  escala (VT323 en px enteros, Press Start en múltiplos de 8),
  familia de cada token; nombres del árbol según el zoom;
  `protoSplitLines`; con las fuentes reales, a 1280×720 y DPR 1 y 1.5 en
  los tres tamaños: ficha de un Legendario, comparación del inventario,
  panel de personaje (atributos, inventario, árbol, filtro), menú de
  batalla y su tip, chat — sin desbordes y dentro de la pantalla.
- `test/app/contrast_test.dart`: AA de los tokens de texto y de las
  rarezas en cada modo daltónico.
- `test/app/color_vision_test.dart`: pares distinguibles con la
  simulación de cada tipo de daltonismo, `VisionColor`, markup / rarezas.
- `test/features/combat/reduce_motion_test.dart`, `test/game_engine/
  turn_timer_test.dart`, `test/app/label_scale_test.dart` (ventana,
  etiquetas, sin pesos), auditoría de objetivos en
  `settings_menu_test.dart`.
- `test/features/settings_menu_test.dart`: TAMAÑO DEL TEXTO en vivo.
- `test/app/ui_theme_test.dart` (v0.8.1): ajustes y `game.json`; tokens
  de cada tema; contraste de cada tema × colores × modo daltónico;
  jerarquía título > cuerpo > atenuado; mapeo por roles del markup;
  ESPACIADO AMPLIO (interlineado, párrafos, separadores, aire); la pestaña
  ACCESIBILIDAD; sin desbordes en 3 temas × 2 espaciados × Normal / Muy
  grande (ficha de un Legendario, FUSIÓN pasos 2 y 3, ATRIBUTOS, detalle
  del bestiario, ventana de comandos de la batalla).

## 6. Batalla

Rediseño de la barra de batalla para legibilidad: docs/specs/
battle_presentation.md § "Barra de batalla (v0.5)".

## 8. Temas y legibilidad (v0.8.1)

Pedido del dueño: "el fondo y el morado no mucho: colores disonantes
entre el fondo, y todos los menús están con mucho texto y los colores
hacen que se lea como todo un texto unido"; y sobre un tooltip de
keystone: "más contraste entre título y descripción: son escalas de
grises, amarillo, naranja, se ven muy iguales. Agarrá una paleta de
colores de design system. Los colores de estado alterado dejalos así,
pero texto, título, descripción, que se vean bien. Usá blancos sobre
negros."

Tres ajustes nuevos en ACCESIBILIDAD (arriba de todo, con vista previa en
vivo: un tip de keystone y dos filas de menú) que se guardan en
`game.json` (claves aditivas `uiTheme`, `textColors`, `spacing`; una
clave que falta o no se entiende toma el valor por defecto). Se aplican a
toda la UI (menús, tooltips, HUD, batalla) con `UiThemeScope`
(`lib/app/theme/ui_theme.dart`, en `MaterialApp.builder` como
`ColorVisionScope`): al cambiar, la app se reconstruye sin perder estado.
El arte (arenas, mapa, sprites, lienzo del árbol) no cambia.

**Por defecto (decisión v0.8.1): OSCURO + REDUCIDO + NORMAL**, porque es
lo que pidió el dueño. AZUL + COMPLETO es el aspecto de v0.8.0 y sigue a
un clic. Los estáticos de `UiTheme` arrancan en AZUL + COMPLETO + NORMAL
(lo que esperan los tests existentes, que no montan el scope); el valor
del jugador sale de `GameSettings`.

### 8.1 TEMA DE INTERFAZ: AZUL / OSCURO / ALTO CONTRASTE

Los tokens de interfaz de `ProtoColors` (`bg`, `ink`, `title`, `panel`,
`panelBorder`, `button*`, `input*`, `gold`, `sky`, `dim`, `chat`,
`barBg`, `ice`, `orange`, `violet`, `pink`) son `ThemeColor` (const, como
`VisionColor`: leen el tema activo al pintar). Tabla en
`UiTheme.table`. Los de estados (`cream`, `holy`, `mint`, `burn`,
`taunt`, `amber`) y los con significado (`VisionColor`) no cambian con el
tema.

| Rol / token | AZUL | OSCURO | ALTO CONTRASTE |
|---|---|---|---|
| fondo `bg` | `#0B0E1A` | `#0A0A0A` | `#000000` |
| panel `panel` | `#121936` | `#141414` | `#000000` |
| elevado `button` | `#22305A` | `#1F1F1F` | `#000000` |
| hover `buttonHover` | `#2E4280` | `#2A2A2A` | `#262626` |
| hundido `input` | `#0F1530` | `#0F0F0F` | `#000000` |
| borde `panelBorder` | `#2E3B6B` | `#2E2E2E` | `#BDBDBD` |
| borde de botón / caja | `#5B74C9` | `#525252` | `#FFFFFF` |
| borde hover | `#9FB4FF` | `#8A8A8A` | `#FFE600` |
| `text.title` (`title`) | dorado / `#E8ECFF` | `#F5F5F5` | `#FFFFFF` |
| `text.body` (`ink`) | `#B0BAE5` | `#D4D4D4` | `#F0F0F0` |
| `text.muted` (`dim`, `sky`) | `#929ABA` / `#8FA1DF` | `#A3A3A3` | `#C8C8C8` / `#E0E0E0` |
| `text.accent` + foco (`gold`) | `#D3AC4F` | `#F5C451` | `#FFE600` |
| `text.positive` / `negative` | `VisionSlot.good` / `bad` (igual en los tres) |||
| chat | `#C8D2FF` | `#E5E5E5` | `#FFFFFF` |
| `ice` / `orange` / `violet` / `pink` | suavizados § 2 | `#8DB4D9` / `#E0A262` / `#B4AEDD` / `#D696B5` | `#B8DCFF` / `#FFD0A0` / `#E2DDFF` / `#FFD1E6` |

- OSCURO: escala neutra (tipo Tailwind *neutral*) + un acento ámbar; la
  jerarquía va por brillo (título > cuerpo > atenuado), no por tono. El
  dorado queda para selección, foco y valores; la caja de los tooltips y
  de la ficha de enemigo usa el borde gris (`RetroHoverCard.borderColor`;
  en AZUL sigue dorada).
- ALTO CONTRASTE: negro / blanco, foco amarillo, bordes gruesos (paneles
  4 px, botones y tooltips 3 px: `UiTheme.panelBorderWidth` /
  `buttonBorderWidth`) y siempre los colores por roles (§ 8.2; el ajuste
  COLORES DEL TEXTO queda fijo en REDUCIDO).
- Contraste (test): todo token de texto ≥ 4.5:1 sobre `bg`, `panel`,
  `input` y `button` en cada tema × colores × modo daltónico; rarezas ≥
  4.5:1 sobre fondo / panel / campo y ≥ 3:1 sobre botón; dorado de foco ≥
  3:1 contra panel y botón; en ALTO CONTRASTE bordes y foco ≥ 7:1.
- El markup que arma `protoColor(token, …)` escribe el hex canónico (el
  de AZUL; los `VisionColor`, el del modo apagado) y `ProtoColors.parse`
  lo vuelve a leer como el token: sigue al tema, al modo daltónico y a
  los roles al pintarse.

### 8.2 COLORES DEL TEXTO: COMPLETO / REDUCIDO (por roles)

COMPLETO: cada markup con sus colores (v0.8.0). REDUCIDO: el markup se
pinta por **roles** en un solo lugar (`protoSpan` → `UiTheme.role`), sin
tocar el markup de cada pantalla:

| Lo que trae el markup | Rol |
|---|---|
| `<b>` (o dorado) que abre la línea (nombre de nodo, de habilidad, de enemigo, título de tarjeta) | `title` |
| otro `<b>`, el dorado, avisos naranja (`EQUIPADA`, `(trasladada)`) | `accent` (`gold`) |
| `class="k"`, `<small>`, `sky`, `dim` (tipo · nivel · cluster, etiquetas) | `muted` |
| verde / rojo / carmesí (▲▼, alcanza / no alcanza, requisitos, "Necesita un nodo conectado") | `positive` / `negative` (sin cambio) |
| rarezas (también Común `#DCDCDC`) | sin cambio |
| estados y elementos (`statusHex`, `elementHex`, `reactionHex`, `ice`, `cream`…) | sin cambio |
| el resto (violeta de pasivas, celeste de mods, turquesa de Ecos, rosa de ULT, `ink`) | `body` |

`title` con COMPLETO es el dorado (AZUL se ve como siempre); por roles,
casi blanco. Además de los markups, usan `ProtoColors.title`: título de
`PanelFrame`, `PanelSection`, `SectionPanel`, `MenuHeader`, nombre del
tooltip y de la ficha del árbol, nombre del que actúa en la ventana de
comandos.

### 8.3 ESPACIADO: NORMAL / AMPLIO

AMPLIO:
- interlineado del texto de lectura 1.0 → 1.25 (VT323) y 1.6 → 1.9
  (CLÁSICA) (`RetroType.line`);
- cada `<br>` de un `ProtoText` sin `maxLines` es un párrafo con 4 px
  entre medio (`UiTheme.paragraphGap`);
- tooltips (`RetroTipText`): un párrafo por línea y un separador de 1 px
  (`panelBorder`) antes de cada sección (línea que empieza con
  `<span class="k">`: Implícito, Mods, Habilidades…); siguen pasando a
  columnas si no entran;
- ×1.5 de aire (`UiTheme.space`) en `SectionPanel`, `PanelRow`,
  `PanelSection` (con separador arriba), `MenuRow`, `ActionCard`,
  `InfoLine`, el padding de los tooltips y del tooltip del árbol y las
  filas de CONFIGURACIÓN.

Sin desbordes a 1280×720 en Normal y Muy grande (los paneles scrollean).
Arreglado de paso (ya pasaba en v0.8.0 con Muy grande): el botón
`CONFIRMAR` del paso 3 de FUSIÓN y las partes del `CostChip` se cortan en
dos líneas en vez de desbordar.

## 7. Próximo

Hecho en v0.5.1: paletas para daltonismo, REDUCIR MOVIMIENTO, tiempo de
turno, auditoría de objetivos clicables, barras de enemigos sin color,
etiquetas del mundo nítidas, UI que crece con la ventana.

- Navegación por teclado completa (otra parte de v0.5.1).
- Etiquetas de loot en el mapa con letra de rareza.
- Colores de estado (Quemadura / Veneno / Regeneración) por paleta
  daltónica (hoy van con su letra).
- La franja de turnos (`TURNOS`) se dibuja en el lienzo virtual: pasarla
  a px de pantalla como las etiquetas.
- REDUCIR MOVIMIENTO en el mapa (pulsos de tiles y loot).
