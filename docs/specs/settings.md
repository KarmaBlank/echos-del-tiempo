# Spec: Menú de pausa / configuración y ajustes (v0.2.1)

Pedido del dueño: "es necesario un menú de pausa para configuración del
juego y poder controlar música, sonidos, FX, etc." y, después, **pausa de
grupo**: cualquiera pausa la sala para todos y cualquiera la reanuda.

Un solo lugar para todos los ajustes: el mismo `SettingsMenu`
(`lib/features/settings/presentation/settings_menu.dart`) se abre

- en el juego (lobby, campo, subida de nivel, resultado **y batalla**)
  como **PAUSA**, con `Esc` o el botón `≡ MENU [ESC]`, y
- en el título como **CONFIGURACIÓN** (botón debajo de las salas), sin
  las salidas del juego.

Reemplaza al panel suelto `SONIDO` de v0.2.0 (título y HUD): ese botón y
`AudioSettingsPanel` ya no existen; los providers de audio quedaron en
`lib/core/audio/presentation/audio_providers.dart`.

Estilo: docs/specs/ui_style.md § "Principio: menús minimalistas"
(`PanelFrame` con `[?]`, `PanelTabs`, una línea "qué hace" por pestaña,
teclado común).

## 1. Estructura

```
PAUSA [?]                              Juego en pausa | El juego sigue corriendo en multijugador | Grupo en pausa
[SONIDO] [PANTALLA] [ACCESIBILIDAD] [JUEGO] [CONTROLES]
Una línea "qué hace" de la pestaña                                    (dim)
NOMBRE DEL AJUSTE        [control]
                         qué hace, en una línea                       (dim)
...
[SALIR AL TÍTULO] [SALIR DEL JUEGO]      [PAUSAR AL GRUPO] [CONTINUAR [ESC]]
```

- Cada ajuste es una fila: nombre (200 px) + control + una línea `dim`
  que explica qué hace. Controles: slider en % (20 pasos) para volúmenes
  y botones excluyentes (`PanelButton`, el elegido con borde y texto
  `gold`) para el resto (`SÍ / NO`, `NORMALES / SUAVES / NO`,
  `APAGADO / SUAVE / NORMAL / FUERTE`, `VENTANA / PANTALLA COMPLETA`).
- Botones de abajo: a la izquierda las salidas (solo en el juego); a la
  derecha `PAUSAR AL GRUPO` / `REANUDAR AL GRUPO` (solo con red) y el
  primario `CONTINUAR [ESC]` (en el título `CERRAR [ESC]`).
- Las salidas piden confirmación en la misma fila de botones:
  `¿Volver al título?` / `¿Salir del juego?` + la consecuencia en naranja
  (`Dejas la sala; tus compañeros siguen sin ti.` con red, `La misión en
  curso se abandona.` en una misión, si no `Tu personaje queda
  guardado.`) + `CANCELAR` y el botón rojo que confirma. `Esc` cancela la
  confirmación (no cierra el menú).
- Todo se aplica en vivo y se guarda solo (no hay "aceptar").

## 2. SONIDO

| Ajuste | Control | Efecto |
|---|---|---|
| VOLUMEN GENERAL | slider 0-100% (por defecto 100%) | multiplica música y efectos; suena una muestra al moverlo |
| MÚSICA | slider (60%) | `MusicService.volume = general × música` |
| EFECTOS (FX) | slider (80%) | `SfxService.volume = general × efectos`; **muestra en vivo**: al arrastrar suena `Sfx.hit` con el volumen nuevo (como mucho una cada 120 ms) |
| SILENCIAR TODO | SÍ / NO | silencia música y efectos sin perder los volúmenes |

Los sliders aplican al arrastrar y guardan al soltar; el silencio se
guarda al tocarlo (`AudioSettingsController`).

**Sonidos de menú / UI**: no se ofrecen. El juego no tiene sonidos de
interfaz (todos los efectos son de batalla, loot y jingles), así que no
hay nada que separar. Si se agregan, van como una cuarta fila aquí.

## 3. PANTALLA y ACCESIBILIDAD

Desde v0.5.1 la accesibilidad tiene su pestaña (ACCESIBILIDAD, entre
PANTALLA y JUEGO): TAMAÑO DEL TEXTO, FUENTE DE LECTURA, MODO DALTÓNICO,
REDUCIR MOVIMIENTO, SACUDIDA y DESTELLOS (§ 3.8). Las claves de los
botones no cambiaron (`display-text-*`, `display-font-*`,
`display-shake-*`, `display-flashes-*`).

| Ajuste | Opciones | Efecto |
|---|---|---|
| TEMA DE INTERFAZ (ACCESIBILIDAD, v0.8.1) | AZUL / OSCURO / **ALTO CONTRASTE** (por defecto desde v0.8.2) | colores de paneles, botones, bordes y texto de toda la UI; el arte no cambia. `game.json`: `uiTheme` (accessibility.md § 8.1) |
| COLORES DEL TEXTO (ACCESIBILIDAD, v0.8.1) | COMPLETO / **REDUCIDO** | REDUCIDO pinta el markup por roles (título, cuerpo, atenuado, acento, mejora / empeora; rarezas y estados igual). Fijo en REDUCIDO con ALTO CONTRASTE. `textColors` (§ 8.2) |
| ESPACIADO (ACCESIBILIDAD, v0.8.1) | **NORMAL** / AMPLIO | más interlineado, párrafos y separadores en las fichas, más aire en filas y tarjetas. `spacing` (§ 8.3). Vista previa en vivo debajo |
| TAMAÑO DEL TEXTO (ACCESIBILIDAD › TEXTO) | **NORMAL** / GRANDE / MUY GRANDE / ENORME | accesibilidad: agranda el texto de toda la UI (tooltips, fichas, comparación, paneles, chat, HUD, menú y log de batalla, árbol, etiquetas de la escena) ×1 / ×1.25 / ×1.5 / ×2 (los títulos crecen menos; ENORME v0.8.1, accessibility.md § 9.3), siempre en la grilla nítida de cada fuente (§ 3.6). Se aplica en vivo |
| MODO (solo Windows) | VENTANA / PANTALLA COMPLETA | pantalla completa sin bordes en el monitor de la ventana; al volver, la ventana recupera su estilo y su posición. Se aplica al arrancar si quedó guardada |
| FUENTE DE LECTURA (ACCESIBILIDAD › TEXTO) | **VT323** / CLÁSICA / ATKINSON | accesibilidad: fuente del texto de lectura (fichas, chat, menús, batalla). CLÁSICA = Press Start 2P como en v0.4; ATKINSON = Atkinson Hyperlegible (v0.8.1, baja visión, no pixel). Cada botón se escribe en su fuente (vista previa). Títulos y botones no cambian salvo con la fila de abajo (§ 3.7) |
| TÍTULOS CON LA FUENTE DE LECTURA (ACCESIBILIDAD › TEXTO, v0.8.1) | SÍ / **NO** | títulos, botones y pestañas en la fuente de lectura en vez de Press Start 2P. `readingTitles` (accessibility.md § 9.2) |
| ESPACIADO ENTRE LETRAS (ACCESIBILIDAD › TEXTO, v0.8.1) | **NORMAL** / AMPLIO | +0.08 em en el texto de lectura. `letterSpacing` (§ 9.4) |
| DURACIÓN DE LOS AVISOS (ACCESIBILIDAD › TEXTO, v0.8.1) | **NORMAL** / LARGA / HASTA CERRAR | avisos de loot, build, chat plegado, puntos sin usar y misión opcional ×1 / ×2 / hasta cerrarlos (× en cada uno, Retroceso cierra todos). `noticeDuration` (§ 9.5) |
| FONDO DEL TEXTO EN EL MAPA (ACCESIBILIDAD › TEXTO, v0.8.1) | **NINGUNO** / SOMBREADO / CAJA OPACA | detrás de nombres, carteles, avisos y loot del mapa. `mapLabelBackdrop` (§ 9.6) |
| REGISTRO DE BATALLA (ACCESIBILIDAD › TEXTO, v0.8.1) | **NORMAL** / EXTENDIDO | EXTENDIDO: las 3 últimas líneas del log arriba de la escena, 10 s cada una. `battleLog` (§ 9.7) |
| ESCALADO | PIXEL PERFECT / **AJUSTAR** | cómo se agranda el mundo pixelado (§ 3.1) |
| FILTRO CRT | APAGADO / SUAVE / NORMAL / **FUERTE** (por defecto desde v0.8.2) | post-proceso retro sobre toda la pantalla (§ 3.2) |
| PARTÍCULAS | BAJA / MEDIA / **ALTA** | cantidad de partículas: ×0.3 / ×0.6 / ×1 (§ 3.3) |
| LÍMITE DE FPS | 30 / **60** / SIN LÍMITE | tope de cuadros por segundo de toda la app (§ 3.4) |
| FPS Y PING (v0.5.1) | SÍ / **NO** | indicador chico en una esquina con los cuadros por segundo y, en una sala, el ping (§ 3.9) |
| ESQUINA (v0.5.1) | **ARRIBA DER.** / ARRIBA IZQ. / ABAJO DER. / ABAJO IZQ. | dónde va el indicador; deshabilitada con FPS Y PING en NO (§ 3.9) |
| MODO DALTÓNICO (ACCESIBILIDAD) | **NO** / DEUTERANOPÍA / PROTANOPÍA / TRITANOPÍA | paleta de los colores con significado (§ 3.8) |
| REDUCIR MOVIMIENTO (ACCESIBILIDAD) | SÍ / **NO** | sin sacudida, destellos a lo sumo SUAVES, sin parpadeos ni zoom de cámara (§ 3.8) |
| SACUDIDA (ACCESIBILIDAD) | SÍ / NO | la escena de batalla tiembla con los golpes fuertes (`ParticleSystem.shake`). Con NO la escena la anula en cada frame. Con REDUCIR MOVIMIENTO se ve en NO y deshabilitada (el valor propio se guarda igual) |
| DESTELLOS (ACCESIBILIDAD) | NORMALES / SUAVES / NO | multiplica el alfa de los destellos de pantalla completa de la batalla por 1 / 0.35 / 0: el rojo de "te pegaron fuerte" (`hurtFlash`), los blancos de golpe brutal y quiebre (`FxKind.flash`), el tinte de "tiempo detenido" (`timeStop`), el blanco del impacto de una ULT, el de la entrada a la arena y el de la cinemática de ascensión. Con REDUCIR MOVIMIENTO, NORMALES vale como SUAVES |

Pantalla completa sin paquetes nuevos: el runner de Windows
(`windows/runner/flutter_window.cpp`) atiende el canal `ecos/window`
(`setFullscreen(bool)`, `isFullscreen`): guarda estilo y
`WINDOWPLACEMENT`, saca `WS_OVERLAPPEDWINDOW` y ocupa `rcMonitor`; al
salir los restaura. `WindowMode` (`lib/core/settings/window_mode.dart`)
es la puerta Dart; en otras plataformas (web, móvil, macOS, Linux) la
fila no aparece.

**Escala de la UI** (v0.5.1): no es un ajuste. La UI está armada para
1280×720 lógicos; en una ventana más grande en las dos direcciones el
texto (y las cajas que usan `RetroType.width` / `em`) crece en la misma
proporción, de a 0.25 y hasta ×2 (`RetroTextScale.windowFactor`:
1600×900 → ×1.25, 1920×1080 → ×1.5, 2560×1440 → ×2), multiplicado por
TAMAÑO DEL TEXTO. Así 1920×1080 se arma igual que 1280×720 y no queda
diminuto (accessibility.md § 1).

Las animaciones propias de las ULT (rayos, círculos, partículas) no son
destellos de pantalla completa y no cambian.

### 3.1 ESCALADO (`ScaleMode`, `lib/core/settings/graphics.dart`)

El mapa se dibuja a 480×288 px virtuales (exploration.md § "Resolución
virtual y escalado") y la batalla en px del mundo × `zoom`
(battle_presentation.md § "Cámara y encuadre"). Siempre con vecino más
cercano; lo que cambia es el factor. La UI (HUD, paneles, franja de
turnos, barra de batalla) no se toca.

- **PIXEL PERFECT**: factor **entero**. Mapa: el mayor entero que entra
  (`floor(min(w/480, h/288))`, mínimo 1), centrado con barras negras
  (`mapViewRect`). Batalla: el encuadre base ya es entero; además el zoom
  de las transiciones de cámara y de las cinemáticas de ULT se redondea
  al entero más cercano (`BattleSceneController.viewFor`), así ningún
  píxel del mundo sale más ancho que otro (el acercamiento de las ULT va
  "a saltos").
- **AJUSTAR** (por defecto): llena lo más posible manteniendo la
  proporción (`min(w/480, h/288)`, fraccional) — el comportamiento de
  v0.2.1. En batalla, encuadre base entero y zoom continuo en las
  transiciones y las ULT.
- **ESTIRAR**: no se ofrece. Deforma los píxeles y en batalla rompería
  la conversión pantalla ↔ mundo (los clics a enemigos y las etiquetas).

Por qué AJUSTAR por defecto: la ventana por defecto es 1280×720 (área
útil ≈ 1264×681); con PIXEL PERFECT el mapa queda ×2 = 960×576, con
barras de 152 px a los costados y 52 px arriba y abajo: se pierde ~35%
del área y el HUD queda flotando sobre las barras. Con AJUSTAR queda
×2.36 (≈ 1135×681). En 1920×1080 PIXEL PERFECT da ×3 (1440×864); en
2560×1440, ×5 exacto (sin barras). Quien quiera el píxel exacto lo
elige.

### 3.2 FILTRO CRT (`CrtLevel`, `lib/core/settings/crt_filter.dart`)

Post-proceso sobre **toda** la pantalla (título, mapa, batalla, HUD y
menús: `MaterialApp.builder` envuelve el `Navigator` en `CrtFilter`),
como los filtros retro de los emuladores. Prendido por defecto en
FUERTE desde v0.8.2 (antes NORMAL; ver "Por defecto FUERTE" abajo). Shader de fragmento propio (`shaders/crt.frag` y
`shaders/crt_overlay.frag`, en `flutter: shaders:` del pubspec), sin
paquetes nuevos.

| Nivel | Scanlines | Máscara RGB | Brillo (bloom) | Viñeta | Curvatura | Bisel |
|---|---|---|---|---|---|---|
| APAGADO | — | — | — | — | — | — |
| SUAVE | 0.14 | 0.05 | 0.15 | 0.15 | 0 | 0 |
| NORMAL | 0.24 | 0.09 | 0.25 | 0.25 | 0 | 0 |
| FUERTE | 0.38 | 0.16 | 0.40 | 0.40 | 0 (era 0.05) | 0.035 |

- Scanlines: una línea oscura cada `round(alto físico / 240)` px (≥ 2;
  3 px en 720p), con forma de seno para que no titile. Máscara: rejilla
  de apertura de 3 columnas R/G/B que atenúa los otros dos canales.
  Bloom: los píxeles claros (> 0.55) de un entorno de 8 muestras a 1.5 y
  3 px se suman suaves (el texto blanco "brilla" sin desenfocarse: el
  píxel central no se mezcla). Viñeta: oscurece hacia las esquinas.
  Curvatura: barril leve (`uv' = 0.5 + c·(1 + k·|c|²)`), negro fuera
  (hoy 0 en todos los niveles; el código queda por si vuelve). Bisel
  (v0.8.2, uniforme `uBezel`, el último): esquinas redondeadas negras de
  radio `bezel × lado menor` (~25 px en 720p) con 1.5 px de borde suave
  y un sombreado de hasta 30 % en los últimos `0.6 × radio` px. Solo
  multiplica: no mueve ningún píxel, así que está en los dos caminos
  (también en `crt_overlay.frag`).
- **Dos caminos** según el motor de render:
  - Con Impeller (`ImageFilter.isShaderFilterSupported`): `ImageFiltered`
    con `ImageFilter.shader(crt.frag)` — todo lo de arriba, muestreando
    la imagen. Con curvatura, los clics se corrigen con la misma
    deformación (`CrtFilter` desplaza el hit-test al punto que se ve
    bajo el puntero), así los botones de las esquinas siguen andando.
  - Sin Impeller (Skia, `flutter test`): `crt_overlay.frag` dibujado
    encima con `BlendMode.multiply` (scanlines + máscara + viñeta, sin
    curvatura ni bloom porque no puede leer la imagen).
  - Si el shader no carga (plataforma sin soporte, error), no hay
    filtro: el juego se ve igual que con APAGADO.
- Legibilidad (v0.5, "hay fonts que se ven súper mal, como baja
  resolución"): la curvatura remuestrea **toda** la UI (también el
  texto): con vecino más cercano duplica y saltea columnas de la fuente
  pixel, y con bilineal la desenfoca. Por eso **NORMAL ya no curva**
  (curvatura 0, era 0.02): sin curva el shader lee cada píxel en su
  lugar (vecino más cercano, identidad) y el texto queda igual de nítido
  que sin filtro; scanlines, máscara, bloom (sin mezclar el píxel
  central) y viñeta se mantienen. Hasta v0.8.1 FUERTE curvaba (0.05,
  bilineal), con el texto apenas más suave.
- **Por defecto FUERTE (v0.8.2)**: pedido del dueño ("el filtro CRT que
  venga FUERTE por defecto"). Como ahora es lo que ve todo jugador nuevo,
  FUERTE **ya no remuestrea**: curvatura 0 y vecino más cercano (cada
  píxel en su lugar, texto igual de nítido que sin filtro); el look de
  "tubo curvo" lo dan el bisel de esquinas redondeadas y la viñeta
  fuerte, y scanlines / máscara / bloom siguen siendo los fuertes
  (0.38 / 0.16 / 0.40). Se descartó curvar solo la escena de juego: el
  filtro es uno solo sobre toda la app (`MaterialApp.builder`) y partirlo
  en capas costaba dos pasadas de shader y bordes raros entre HUD y
  mapa. Captura de referencia: un tooltip con CRT FUERTE + ALTO
  CONTRASTE a 1280×720 (release notes v0.8.2).
- Costo: ver § 3.5.

### 3.3 PARTÍCULAS (`ParticleLevel`)

`BAJA` ×0.3, `MEDIA` ×0.6, `ALTA` ×1 (por defecto, como v0.2.1). Escala
la cantidad (no el tamaño ni la vida) con `scaledCount(n, k)` =
`max(1, round(n·k))` si `n > 0` (una ráfaga nunca desaparece del todo):

- `ParticleSystem.burstWith` (todas las ráfagas de golpes, procs del
  árbol y ULT) y su tope (600 × k).
- Nieve del Campo Helado en batalla (`_snow`).
- Motas de las ULT que son "lluvia" de partículas (lluvia de ácido,
  goteo del Nido de Veneno, copos del Aliento Glacial). Las formas de
  las ULT (rayos, círculos, flechas, lanzas) no cambian: son la
  coreografía.
- Mapa: motas que suben en el haz de los Legendarios y chispas de las
  entradas de zona abiertas. El mapa no tiene clima (nieve/lluvia):
  no hay nada más que escalar.

### 3.4 LÍMITE DE FPS (`FpsLimit`, `lib/core/settings/frame_limiter.dart`)

`30` / `60` (por defecto) / `SIN LÍMITE`. Flutter dibuja sincronizado
con la pantalla (el motor pide cada cuadro al vsync del monitor), así
que el tope real es la frecuencia del monitor: `SIN LÍMITE` = lo que dé
el monitor (60, 144...). El límite lo pone `EcosBinding` (el binding de
la app, `lib/core/settings/frame_limiter.dart`): en cada vsync
pregunta a `FrameLimiter.shouldDraw(t)`; si es muy pronto, salta el
cuadro entero (sin build, layout, paint ni raster: tampoco corre el
filtro CRT) y pide el siguiente vsync. Los relojes (Flame, la escena de
batalla) ven el `dt` real, así que nada se acelera ni se frena.

- `FrameLimiter`: acumula la hora del próximo cuadro (`next += 1/fps`);
  dibuja si `t ≥ next − medio vsync`; si quedó atrás más de un período
  (la app estuvo quieta) se re-sincroniza. Si el tope es ≥ 95% de la
  frecuencia medida del monitor, no limita (60 en un monitor de 60 Hz no
  pierde cuadros por el jitter del vsync).

**VSync**: no se ofrece. Flutter en Windows no deja apagarlo: el motor
arma cada cuadro al vsync (DWM) y presenta con el intervalo de swap que
elige el embedder; ni el runner (`FlutterViewController`) ni el canal
`ecos/window` tienen acceso a la superficie (ANGLE/D3D) para cambiar el
swap interval, y aunque lo tuvieran, el framework no produce más
cuadros que vsyncs. Una opción "VSYNC: NO" no haría nada, así que no se
muestra.

### 3.5 Rendimiento

Medido en Windows 11 (RTX 5070, monitor de 60 Hz, ventana 1264×681 de
área útil), build debug de `main_dev.dart`, pantalla de título forzada
a redibujar en cada vsync, 5 s por caso (`FrameTiming` + contador de
Windows "GPU Engine 3D" del proceso). El motor usa **Impeller
(OpenGLES)**, así que va el camino completo (`ImageFilter.shader`).

| Caso | FPS | Raster CPU prom. / p90 | GPU 3D |
|---|---|---|---|
| CRT APAGADO, 60 | 60.2 | 1.18 / 1.41 ms | 0.8% |
| CRT SUAVE, 60 | 60.0 | 1.13 / 1.32 ms | 1.1% |
| CRT NORMAL, 60 | 60.2 | 1.13 / 1.34 ms | 1.1% |
| CRT FUERTE, 60 | 60.2 | 1.13 / 1.34 ms | 1.1% |
| CRT APAGADO, sin límite | 61.0 | 1.12 / 1.38 ms | 0.9% |
| CRT NORMAL, sin límite | 60.0 | 1.27 / 1.62 ms | 1.1% |
| CRT NORMAL, 30 | 30.4 | 1.43 / 1.76 ms | 0.6% |

- El filtro no cambia el tiempo de raster del CPU (está dentro del
  ruido, ±0.15 ms) y suma ~0.3 puntos de uso de la GPU: una pasada de
  pantalla completa con 9 lecturas de textura por píxel. En una GPU
  integrada costará más; APAGADO lo saca del todo.
- `SIN LÍMITE` en un monitor de 60 Hz = 60 (Flutter va al vsync). El
  tope de 30 da 30.4 FPS y baja la GPU a la mitad: sirve para notebooks
  a batería.
- Los números de `flutter test` no sirven para esto: ahí no hay
  Impeller y el filtro va por la capa de `crt_overlay.frag`.

### 3.6 TAMAÑO DEL TEXTO (`TextSize`, `RetroTextScaler`)

`TextSize.normal` (por defecto) / `large` / `huge` / `enormous` (factor
1 / 1.25 / 1.5 / 2; ENORME desde v0.8.1, accessibility.md § 9.3). Accesibilidad; ver también docs/specs/accessibility.md.

- Un solo punto: `EcosApp` (`MaterialApp.builder`) envuelve todo en
  `RetroTextScale(factor)`, que pone `RetroTextScaler` en el
  `MediaQuery` (reemplaza la escala de texto del sistema). Llega a todo
  el texto Flutter, overlays (tooltips) y los nombres del árbol de
  pasivas incluidos; el texto pintado en los canvas del mundo no cambia.
- **Tamaños**: el texto de lectura (VT323) va a 20 / 25 / 30 px en px
  físicos enteros; Press Start 2P en múltiplos de 8 px físicos según la
  escala de Windows (docs/specs/ui_style.md § "Tamaño del texto y
  nitidez").
- Las cajas con texto crecen con él (`RetroType.width` / `em`): ancho de
  paneles (hasta la pantalla), lista de `PanelSplit` (hasta la mitad),
  `PartyBox`, tooltips, comparación de armas (a 2 columnas con factor
  ≥ 1.5), columna de etiquetas de los ajustes, cifras de la batalla. El
  alto de los paneles no cambia: el contenido scrollea.
- Nada se sale de 1280×720 en los tres tamaños, a 100 % y 150 % (tests
  con las fuentes reales).

### 3.8 MODO DALTÓNICO y REDUCIR MOVIMIENTO (v0.5.1)

**MODO DALTÓNICO** (`ColorVision.off` / `deuteranopia` / `protanopia` /
`tritanopia`; `game.json` `"colorVision"`). `EcosApp` →
`ColorVisionScope(mode)` pone `VisionPalette.mode`; los tokens con
significado (`ProtoColors.green/red/crimson/hp/mp`, rarezas, barras y
números de la batalla) son `VisionColor` y se pintan con la paleta del
modo. Al cambiar, la app se reconstruye sin perder estado y el texto se
vuelve a medir. Detalle y paletas: accessibility.md § 3.

**REDUCIR MOVIMIENTO** (`reduceMotion`, `game.json` `"reduceMotion"`).
Un solo interruptor que unifica los de movimiento: no pisa SACUDIDA ni
DESTELLOS (se guardan igual), pero los efectivos son
`GameSettings.shakeOn` (= SACUDIDA y no REDUCIR) y
`GameSettings.flashFactor` (a lo sumo SUAVES). Además:
`SceneOptions.reduceMotion` → la cámara de batalla siempre en el
encuadre base (sin zoom/paneo de ULT ni de entrada), la arena quieta (se
pinta con `t = 0`), nada parpadea (quiebre, VULNERABLE, carga de ULT,
aviso de ULT enemiga, `! JEFE !`, reloj ≤ 10 s, marcadores que flotan),
las franjas del tiempo detenido y del aviso no corren, y la entrada /
salida de la arena es un fundido de 200 ms (`ArenaWipe.fadeMs`) en vez
del barrido de bloques y su destello. La cinemática de ascensión no
tiembla y su destello va × DESTELLOS. Las cinemáticas siguen siendo
cortas y se saltan como antes.

### 3.9 FPS Y PING (v0.5.1, `PerfOverlay`)

Pedido del dueño: "en las opciones de pantalla, que te permita activar
que te salga en alguna esquina los FPS y el ping". Pestaña PANTALLA
(pausa y CONFIGURACIÓN del título: es el mismo menú), apagado por
defecto, con la esquina aparte.

- **Dónde**: `EcosApp` (`MaterialApp.builder`) lo pone sobre toda la
  app (título, mapa, batalla, menús), por encima del filtro CRT (no se
  curva ni se oscurece con la viñeta) y dentro de TAMAÑO DEL TEXTO y
  MODO DALTÓNICO. `IgnorePointer`: nunca tapa un clic.
- **Una sola línea, pegada al borde** (`PerfOverlay.edge` = 1 px,
  `side` = 8 px): `▮▮▮ 60 FPS (máx 60)  ▮▮▮ ping 23 ms (máx 41)` en la
  letra de los botones (`RetroType.label`, Press Start 2P, crece con
  TAMAÑO DEL TEXTO, sin negrita ni subrayado) sobre una franja oscura
  translúcida de 14 px de alto. Así entra en la franja libre de 16 px
  que deja el HUD del mapa arriba (`≡ MENU [ESC]`, `Sala: CODIGO
  [COPIAR]`, minimapa, objetivos) y abajo (chat, ficha): no tapa nada.
  En batalla, arriba a la derecha queda sobre la parte vacía de la
  franja de turnos; arriba a la izquierda pisa los primeros retratos de
  TURNOS y abajo, con 4 jugadores, el borde inferior de la última
  tarjeta del grupo (por eso el valor por defecto es ARRIBA DER.). Con
  GRANDE / MUY GRANDE la línea crece y puede rozar el HUD.
- **FPS**: cuadros dibujados de verdad (`SchedulerBinding.addTimingsCallback`,
  hora de vsync de cada `FrameTiming`; los cuadros que salta el
  `FrameLimiter` no cuentan). `FpsMeter` (puro,
  `lib/core/perf/fps_meter.dart`): ventana de ~1 s hacia atrás desde el
  último cuadro; FPS = cantidad de intervalos ÷ su suma, contando solo
  intervalos < 100 ms (una pausa sin cuadros —un menú quieto— no baja
  el número: Flutter no redibuja lo que no cambia). Sin cuadros
  medidos: `-- FPS`. Con LÍMITE DE FPS en 30 / 60 se agrega el tope:
  `60 FPS (máx 60)`.
- **Ping**: solo en una sala (`activeNetSessionProvider` con un
  `LatencyProbe`, netcode.md § "Ping"); jugando solo la línea no
  aparece. Cliente: `ping 23 ms` (ida y vuelta al host). Host: el
  promedio de sus clientes y el peor, `ping 23 ms (máx 41)` (con un
  solo cliente, sin el máximo); sin clientes, `ping --`. Siempre `ms`
  abreviado; menos de 1 ms se ve `<1 ms` (LAN). Antes de la primera medición, `ping --`.
- **Color + barras** (no depende solo del color): cada dato lleva 3
  barritas tipo señal. Ping < 80 ms: verde, 3 barras; < 150 ms: dorado,
  2; ≥ 150 ms: rojo, 1. FPS ≥ 90 % del objetivo (el tope, o 60 sin
  tope): verde, 3; ≥ 50 %: dorado, 2; menos: rojo, 1. Verde y rojo son
  los de `VisionPalette` (cambian con MODO DALTÓNICO).
- El indicador solo existe con el ajuste en SÍ: apagado no se escuchan
  los `FrameTiming` ni se manda ningún `ping`.

### 3.7 FUENTE DE LECTURA (`ReadingFont`)

`ReadingFont.vt323` (por defecto) / `classic` / `atkinson` (v0.8.1,
accessibility.md § 9.1). `game.json`:
`"readingFont": "vt323" | "classic" | "atkinson"`; un archivo viejo sin la clave (o
con un valor inválido) carga VT323.

- `EcosApp` → `RetroTextScale(classic:)`: pone `RetroType.classic` (la
  familia de `RetroType.bodyFamily` / `smallStyle`) y el escalador.
  Al cambiar, la app se reconstruye entera sin perder estado
  (`WidgetsBinding.reassembleApplication`), así todo estilo de lectura
  toma la fuente nueva en vivo.
- Tamaños: VT323 20 / 25 / 30 px (§ 3.6); CLÁSICA en la grilla de 8 de
  Press Start 2P: 8 / 16 / 16 a 100 % (como v0.4).
- Tests: `test/app/text_size_test.dart` (JSON y tamaños; desbordes a
  1280×720 con las dos fuentes en los tres tamaños, VT323 también a
  150 %), `test/features/settings_menu_test.dart` (vista previa y
  guardado). Las fuentes reales en tests: `loadRealFonts()`
  (`test/real_fonts.dart`, también en `pumpPanel`).

## 4. JUEGO

| Ajuste | Opciones | Efecto |
|---|---|---|
| NÚMEROS FLOTANTES | SÍ / NO | dibujar o no los números flotantes de daño/cura (`FxKind.num`). Los textos (`¡CRÍTICO!`, estados) se mantienen |
| CONFIRMAR AL TIRAR | SÍ / NO | con NO, `TIRAR` del inventario tira enseguida. `VENDER` y `DESARMAR` siempre confirman (destruyen el arma) |
| TIEMPO DE TURNO | **NORMAL (30 S)** / LARGO (60 S) / SIN LÍMITE | cuánto espera la batalla a que elija el jugador de turno antes de pasarlo solo (`TurnTimer`). Jugando solo vale este; en co-op, el del **anfitrión** (la sala lo lleva en `GameSession.turnTimer`; el del cliente no cuenta). En el pueblo y la preparación la barra de misión dice `Turnos: sin límite (anfitrión)` si no es el normal. Con SIN LÍMITE no hay reloj ni cuenta regresiva |
| AVISOS DE BUILD | SÍ / NO | con NO no hay carteles ni líneas de chat cuando avanza una meta del plan de build (build_planner.md § 5). La pestaña BUILD y las ★ siguen |
| CHAT (v0.8.1) | **OCULTO** / SIEMPRE VISIBLE | OCULTO: el chat queda plegado en la píldora `CHAT [ENTER]` con contador `+N`; Enter o clic lo abre (exploration.md § "Chat"). SIEMPRE VISIBLE: registro + campo como antes |
| AVISOS DEL CHAT (v0.8.1) | **SÍ** / NO | con el chat plegado, las líneas de sistema importantes (misión aceptada, piso despejado, subida de nivel…) aparecen 4 s encima de la píldora. Sin efecto con SIEMPRE VISIBLE |

**Auto-recoger loot**: no se ofrece. Levantar caminando encima lo decide
el host (`SessionEngine.pickupRange`) igual para todos; no es un ajuste
del cliente.

## 5. CONTROLES

Lista de solo lectura (exploration.md § "Teclado"): MAPA (WASD/flechas,
E/Espacio, Alt, C, I, J, H (v0.8.2), M, rueda sobre el minimapa, Y/N), BATALLA (1-9/clic, Q/Tab/clic, P pasar
turno (v0.8.3), Esc del submenú), MENÚS (Esc, Tab/flechas, Enter/Espacio) y CHAT (Enter, Esc).
No se pueden reasignar (fuera de alcance).

## 6. Pausa

### Abrir y cerrar (teclado)

`Esc` en `WorldScreen`, en este orden:
1. Escribiendo (chat o un campo de un panel): es del campo; nada más.
2. En batalla con el submenú de pociones abierto: vuelve del submenú.
3. Fuera de batalla con un panel abierto: lo cierra (reglas de
   `closePanel`).
4. Si no: abre la pausa.

Con la pausa abierta, `Esc` (o `CONTINUAR`) la cierra; ninguna otra
tecla llega al juego (ni 1-9 de batalla) y el jugador local no camina
(`SessionController.menuOpen` anula la entrada de movimiento). El menú
toma el foco al abrirse (`Tab` / flechas / `Enter` como en todo panel).
Botón `≡ MENU [ESC]`: arriba a la izquierda del HUD del mapa (junto a
`< TITULO` en el lobby) y arriba a la izquierda de la batalla.

### Solo vs. multijugador

- **Solo (sin red)**: abrir el menú pausa la partida de verdad
  (`PauseAction(true)`); cerrarlo la reanuda. Se ve `Juego en pausa`.
- **Con red**: abrir el menú **no** pausa (`El juego sigue corriendo en
  multijugador`, naranja). `PAUSAR AL GRUPO` manda `PauseAction(true)`;
  con la sala pausada el botón es `REANUDAR AL GRUPO` y el estado
  `Grupo en pausa`.

### Pausa de grupo (host)

- `PauseAction(paused)` (`{"t":"pause","on":true}`): cualquier jugador
  pausa o reanuda; repetir el mismo estado se rechaza.
- `GameSession.pausedBy` / `pausedName`: quién pausó (`null` = corriendo).
- Mientras está pausada, `SessionEngine.tick` devuelve el estado sin
  tocar: no corren el reloj, el tiempo de misión, la gracia, la IA ni el
  movimiento de los enemigos del campo, el tiempo de turno ni el
  auto-defender, las pausas entre pasos de batalla ni la cuenta del
  resultado.
- `apply` solo acepta `PauseAction`, `ChatAction`,
  `SetLootFilterAction` y `MoveInventoryAction` (lo que no toca el
  mundo); el resto (moverse, comandos de batalla, proponer, comprar...)
  se rechaza. Entrar y salir de la sala sigue funcionando.
- Si quien pausó se va, **sigue pausada**; cualquiera reanuda.
- Eventos `PausedEvent(id, nombre)` / `ResumedEvent(id, nombre)`; con
  red, el chat muestra `<nombre> pausó el juego` / `<nombre> reanudó el
  juego` (sistema).

### Cartel

`PauseBanner` (`lib/features/world/presentation/hud/pause_banner.dart`),
para todos, encima del mapa o la batalla, mientras el menú propio no
está abierto:
- pausada: caja centrada con borde dorado `<nombre> pausó el juego`
  (16 px, `gold`), `Cualquier jugador puede reanudar.` (`dim`) y
  `REANUDAR` (verde); un velo `#0b0e1a66` bloquea los clics al juego.
- al reanudar (solo con red): `<nombre> reanudó el juego` en verde 2.5 s,
  sin bloquear.

## 7. SALIR

- **SALIR AL TÍTULO**: cierra `WorldScreen`; el controlador guarda el
  perfil y deja la sala al descartarse (en una misión, la misión se
  abandona para este jugador; con red, el resto sigue).
- **SALIR DEL JUEGO**: guarda el perfil (`SessionController.saveNow`),
  deja la sala y pide al motor cerrar la app
  (`ServicesBinding.exitApplication(AppExitType.required)`,
  `appExitProvider`).
- **SALIR DEL JUEGO en el título** (v0.8.2): botón junto a
  CONFIGURACIÓN (`title-quit`). Abre la confirmación `¿Salir del juego?`
  (`showQuitGameDialog`: CANCELAR con el foco al abrir, `Esc` / clic
  afuera = cancelar; SALIR DEL JUEGO en rojo). Confirmado, llama a
  `appExitProvider` (guarda todo con `ExitGuard.flushAll` —la cuenta— y
  cierra la ventana).

## 8. Persistencia

- `audio.json` (como en v0.2.0, music.md § 7) + la clave nueva `master`.
  Un `audio.json` viejo sin `master` carga con el general al 100%: no se
  pierden los volúmenes guardados (no hace falta migrar).
- `game.json` (misma carpeta que el perfil, escritura atómica):
  `{"fullscreen":false,"shake":true,"flashes":"normal",
  "damageNumbers":true,"confirmDrop":true,"scale":"fit","crt":"normal",
  "particles":"high","fpsLimit":60,"textSize":"normal",
  "readingFont":"vt323","buildNotices":true,"colorVision":"off",
  "reduceMotion":false,"turnTimer":"normal","perfOverlay":false,
  "perfCorner":"topRight"}` (`fpsLimit` 0 = sin límite; `textSize`
  `normal` / `large` / `huge`; `readingFont` `vt323` / `classic`).
  Valores inválidos o ausentes = por defecto. Corrupto = por defecto.
- **v0.8.1 (TEXTO)**: `readingTitles` (por defecto `false`),
  `letterSpacing` (`normal` / `wide`), `noticeDuration` (`normal` /
  `long` / `untilDismissed`), `mapLabelBackdrop` (`none` / `shaded` /
  `box`) y `battleLog` (`normal` / `extended`) son aditivos; también los
  valores nuevos `textSize: "enormous"` y `readingFont: "atkinson"`. Un
  `game.json` sin ellos (o con basura) se ve como antes.
- **v0.8.2**: `partyExpanded` (por defecto `false`: cajas del grupo
  compactas; aditivo). Los **valores por defecto** de `crt` (`normal` →
  `strong`) y `uiTheme` (`dark` → `highContrast`) cambian. `game.json`
  se escribe **siempre entero** (`toJson`, todas las claves) en cuanto
  se cambia cualquier ajuste —también al plegar los objetivos o tocar el
  zoom del minimapa—, así que: un jugador con `game.json` ya guardado
  **conserva** su CRT y su tema (los que tenía, aunque fueran los de por
  defecto de antes); un jugador sin `game.json` (instalación nueva o que
  nunca tocó nada) arranca en FUERTE + ALTO CONTRASTE. No hay migración
  forzada: los dos se cambian en PANTALLA y ACCESIBILIDAD.
- **v0.8.1 (HUD)**: `chat` (`hidden` / `always`, por defecto `hidden`),
  `chatNotices` (por defecto `true`) y `objectivesCollapsed` (por
  defecto `false`) son nuevos y aditivos: un `game.json` sin ellos carga
  OCULTO / SÍ / desplegada. `minimapZoom` (entero 1..3, por defecto 3;
  fuera de rango = 3) guarda el zoom del minimapa.
- **v0.5.1**: `colorVision`, `reduceMotion`, `turnTimer`, `perfOverlay`
  y `perfCorner` son nuevos; un `game.json` sin ellos (o con valores
  inválidos) carga NO / NO / NORMAL / NO / ARRIBA DER. (`perfCorner`:
  `topRight` / `topLeft` / `bottomRight` / `bottomLeft`).
- **v0.5**: `textSize` es nuevo; un `game.json` sin la clave (o con un
  valor inválido) carga en NORMAL.
- **Migración v0.2.1 → v0.3**: la velocidad de animaciones de batalla se
  quitó (era solo visual y en co-op confundía: tu escena iba más rápido
  que los turnos de la sala). Un `game.json` viejo con `battleSpeed` carga
  igual (la clave se ignora) y al guardar ya no se escribe. Los ajustes
  gráficos nuevos toman su valor por defecto (CRT NORMAL incluido).
- `GameSettingsController` (`lib/core/settings/game_settings.dart`):
  carga al arrancar (el título lo pide) y aplica pantalla completa y el
  límite de FPS (`FrameLimiter.fps`); cada cambio se aplica y se guarda.
  Provider: `gameSettingsProvider` (`lib/core/settings/settings_providers.dart`).

## 9. Cómo llegan los ajustes al juego

- Batalla: `WorldScreen` arma `SceneOptions(shake: shakeOn, flash:
  flashFactor, damageNumbers, pixelPerfect, particles, reduceMotion)` de
  `gameSettingsProvider` →
  `SessionBattleScreen` → `BattleView.sceneOptions` →
  `BattleSceneController.options` (leído por `advance`, `viewFor` y
  `BattleScenePainter`). Solo cambia el dibujo.
- Mapa: `WorldScreen` pone `MapGame.scaleMode` y
  `MapGame.particleDensity` en cada build (y desde v0.8.1
  `MapGame.noticeFactor` y `MapGame.labelBackdrop`).
- Texto (v0.8.1): `EcosApp` → `RetroTextScale(font:, readingTitles:,
  wideLetters:)` (estáticos de `RetroType`; al cambiar, la app se
  vuelve a armar). Avisos: `noticeDuration` lo leen `lootFeedProvider`,
  `buildFeedProvider`, `ChatBox` y `UnusedPointsToast` (HUD);
  `Retroceso` en `WorldScreen` → `noticeDismissProvider`. Registro de
  batalla: `SceneOptions.extendedLog`.
- CRT: `EcosApp` (`MaterialApp.builder`) → `CrtFilter(level)`.
- Tamaño del texto: `EcosApp` (`MaterialApp.builder`) →
  `RetroTextScale(textSize.factor)` → `MediaQuery.textScaler`.
- FPS: `GameSettingsController` → `FrameLimiter.shared.fps` →
  `EcosBinding` (los `main_*.dart` usan `EcosBinding.ensureInitialized()`).
- Inventario: `InventoryTab` lee `confirmDrop` al tocar `TIRAR`.
- Modo daltónico: `EcosApp` → `ColorVisionScope(colorVision)` →
  `VisionPalette.mode`.
- FPS y ping: `EcosApp` → `PerfOverlay(perfOverlay, perfCorner)`; lee
  `frameRateProvider` (FPS) y `activeNetSessionProvider` (ping).
- REDUCIR MOVIMIENTO fuera de la escena: `BattleExitWipe(fade:)` y
  `AscensionCinematic(flash:, reduceMotion:)` en `WorldScreen`.
- Tiempo de turno: `sessionControllerProvider` crea el controlador con
  `turnTimer` y escucha el ajuste (`SessionController.setTurnTimer`); solo
  o anfitrión → `SessionEngine.setTurnTimer` (la sala); cliente → nada.

## 10. Tests

- v0.5.1 FPS y ping: `test/core/perf/fps_meter_test.dart` (ventana de
  1 s, pausas ignoradas, sin datos), `test/app/perf_overlay_test.dart`
  (oculto por defecto, aparece y se ubica en cada esquina, `máx 60`,
  ping solo en sala, host con promedio y máximo, barras),
  `test/core/settings/game_settings_test.dart` (claves nuevas, `game.json`
  viejo), `test/netcode/loopback_ping_test.dart` (ida y vuelta con reloj
  falso, host agrega, sin oyentes no hay ping, no son acciones),
  `test/features/settings_menu_test.dart` (FPS Y PING y ESQUINA).
- v0.5.1: `test/app/color_vision_test.dart` (paletas simuladas,
  markup y rarezas), `test/app/contrast_test.dart` (AA en cada modo),
  `test/features/combat/reduce_motion_test.dart` (fundido, sin destello,
  sin sacudida, barras sin color, tarjetas del grupo a 1/4),
  `test/game_engine/turn_timer_test.dart` (30 / 60 / sin límite, cambio a
  mitad de turno, JSON `tt`, solo y co-op con el anfitrión),
  `test/app/label_scale_test.dart`, `test/app/hit_target_audit.dart`.
- `test/core/settings/game_settings_test.dart`: JSON, controlador
  (guardar, ventana, cargar en pantalla completa, límite de FPS),
  `game.json` (incluido uno viejo con `battleSpeed`), `audio.json`
  viejo sin `master`, volumen general, muestra de FX.
- `test/core/settings/graphics_test.dart`: `mapViewRect` entero / ajustar
  para varias ventanas, `scaledCount`, ráfagas de partículas por nivel,
  `FrameLimiter` (30 / 60 / sin límite en monitores de 60, 120 y 144 Hz,
  re-sincronizar), zoom entero de la batalla en PIXEL PERFECT.
- `test/core/settings/crt_filter_test.dart`: CRT en FUERTE por defecto
  (v0.8.2; ningún nivel curva, FUERTE con bisel),
  APAGADO no envuelve nada, uniformes de cada nivel, corrección del
  hit-test con curvatura.
- `test/app/text_size_test.dart`: `textSize` por defecto, JSON (viejo
  sin la clave, inválido), controlador; tabla de tamaños nítidos por DPR
  (todo múltiplo de 8 físicos, Muy grande > Normal, títulos ≥ texto
  chico); `protoSplitLines`; con la fuente real, a 1280×720 y DPR 1 y
  1.5, en los tres tamaños: ficha de un Legendario (dentro de la
  pantalla), comparación del inventario al pasar el mouse, panel de
  personaje (atributos, inventario, filtro), menú de batalla con mis
  datos y el grupo (y su tip), chat con líneas largas — sin desbordes.
- `test/features/settings_menu_test.dart`: TAMAÑO DEL TEXTO se aplica
  en vivo y se guarda; cada pestaña aplica y guarda
  (stores en memoria, ventana falsa), muestra de FX al mover el slider,
  pantalla completa oculta sin soporte, `CONFIGURACIÓN` del título,
  PANTALLA con ESCALADO / FILTRO CRT / PARTÍCULAS / LÍMITE DE FPS (y sin
  VSync ni velocidad de animaciones).
- `test/features/world/pause_menu_test.dart`: `Esc` abre/cierra (no con
  panel ni escribiendo), solo = reloj detenido y sin caminar, batalla
  (submenú primero, 1-9 bloqueadas, ajustes en la escena), salidas con
  confirmación, cartel y `REANUDAR`, multijugador (`PAUSAR AL GRUPO`).
- `test/game_engine/session_pause_test.dart`: pausar/reanudar cualquiera,
  acciones rechazadas, campo y batalla congelados, quien pausó se va,
  JSON de estado, acción y eventos.
- `test/netcode/loopback_session_flow_test.dart`: un cliente pausa, todos
  lo ven, el host no avanza, se va y otro reanuda.
- `test/features/inventory/inventory_tab_test.dart`: `CONFIRMAR AL TIRAR`
  en NO.
