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
[SONIDO] [PANTALLA] [JUEGO] [CONTROLES]
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

## 3. PANTALLA

| Ajuste | Opciones | Efecto |
|---|---|---|
| MODO (solo Windows) | VENTANA / PANTALLA COMPLETA | pantalla completa sin bordes en el monitor de la ventana; al volver, la ventana recupera su estilo y su posición. Se aplica al arrancar si quedó guardada |
| ESCALADO | PIXEL PERFECT / **AJUSTAR** | cómo se agranda el mundo pixelado (§ 3.1) |
| FILTRO CRT | APAGADO / SUAVE / **NORMAL** / FUERTE | post-proceso retro sobre toda la pantalla (§ 3.2) |
| PARTÍCULAS | BAJA / MEDIA / **ALTA** | cantidad de partículas: ×0.3 / ×0.6 / ×1 (§ 3.3) |
| LÍMITE DE FPS | 30 / **60** / SIN LÍMITE | tope de cuadros por segundo de toda la app (§ 3.4) |
| SACUDIDA | SÍ / NO | la escena de batalla tiembla con los golpes fuertes (`ParticleSystem.shake`). Con NO la escena la anula en cada frame |
| DESTELLOS | NORMALES / SUAVES / NO | multiplica el alfa de los destellos de pantalla completa de la batalla por 1 / 0.35 / 0: el rojo de "te pegaron fuerte" (`hurtFlash`), los blancos de golpe brutal y quiebre (`FxKind.flash`) y el tinte de "tiempo detenido" (`timeStop`). Accesibilidad |

Pantalla completa sin paquetes nuevos: el runner de Windows
(`windows/runner/flutter_window.cpp`) atiende el canal `ecos/window`
(`setFullscreen(bool)`, `isFullscreen`): guarda estilo y
`WINDOWPLACEMENT`, saca `WS_OVERLAPPEDWINDOW` y ocupa `rcMonitor`; al
salir los restaura. `WindowMode` (`lib/core/settings/window_mode.dart`)
es la puerta Dart; en otras plataformas (web, móvil, macOS, Linux) la
fila no aparece.

**Escala de la UI**: no se ofrece. La UI está armada para 1280×720 con
la fuente pixel en múltiplos de 8; escalar a valores intermedios la
desenfoca y los paneles de lista + detalle no entran. Queda pendiente.

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
NORMAL. Shader de fragmento propio (`shaders/crt.frag` y
`shaders/crt_overlay.frag`, en `flutter: shaders:` del pubspec), sin
paquetes nuevos.

| Nivel | Scanlines | Máscara RGB | Brillo (bloom) | Viñeta | Curvatura |
|---|---|---|---|---|---|
| APAGADO | — | — | — | — | — |
| SUAVE | 0.14 | 0.05 | 0.15 | 0.15 | 0 |
| NORMAL | 0.24 | 0.09 | 0.25 | 0.25 | 0.02 |
| FUERTE | 0.38 | 0.16 | 0.40 | 0.40 | 0.05 |

- Scanlines: una línea oscura cada `round(alto físico / 240)` px (≥ 2;
  3 px en 720p), con forma de seno para que no titile. Máscara: rejilla
  de apertura de 3 columnas R/G/B que atenúa los otros dos canales.
  Bloom: los píxeles claros (> 0.55) de un entorno de 8 muestras a 1.5 y
  3 px se suman suaves (el texto blanco "brilla" sin desenfocarse: el
  píxel central no se mezcla). Viñeta: oscurece hacia las esquinas.
  Curvatura: barril leve (`uv' = 0.5 + c·(1 + k·|c|²)`), negro fuera.
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
- Legibilidad: la fuente pixel de 8 px se lee en SUAVE y NORMAL (la
  scanline oscurece 1 de cada 3 filas físicas como mucho al 24%) y se
  muestrea con vecino más cercano (nítida). FUERTE es para quien quiere
  el look marcado: con curvatura 0.05 el vecino más cercano duplica y
  saltea columnas de la fuente, así que muestrea bilineal (bordes rectos,
  texto apenas más suave).
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

## 4. JUEGO

| Ajuste | Opciones | Efecto |
|---|---|---|
| NÚMEROS FLOTANTES | SÍ / NO | dibujar o no los números flotantes de daño/cura (`FxKind.num`). Los textos (`¡CRÍTICO!`, estados) se mantienen |
| CONFIRMAR AL TIRAR | SÍ / NO | con NO, `TIRAR` del inventario tira enseguida. `VENDER` y `DESARMAR` siempre confirman (destruyen el arma) |

**Auto-recoger loot**: no se ofrece. Levantar caminando encima lo decide
el host (`SessionEngine.pickupRange`) igual para todos; no es un ajuste
del cliente.

## 5. CONTROLES

Lista de solo lectura (exploration.md § "Teclado"): MAPA (WASD/flechas,
E/Espacio, Alt, C, I, Y/N), BATALLA (1-9/clic, Q/Tab/clic, Esc del
submenú), MENÚS (Esc, Tab/flechas, Enter/Espacio) y CHAT (Enter, Esc).
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

## 8. Persistencia

- `audio.json` (como en v0.2.0, music.md § 7) + la clave nueva `master`.
  Un `audio.json` viejo sin `master` carga con el general al 100%: no se
  pierden los volúmenes guardados (no hace falta migrar).
- `game.json` (misma carpeta que el perfil, escritura atómica):
  `{"fullscreen":false,"shake":true,"flashes":"normal",
  "damageNumbers":true,"confirmDrop":true,"scale":"fit","crt":"normal",
  "particles":"high","fpsLimit":60}` (`fpsLimit` 0 = sin límite).
  Valores inválidos o ausentes = por defecto. Corrupto = por defecto.
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

- Batalla: `WorldScreen` arma `SceneOptions(shake, flash, damageNumbers,
  pixelPerfect, particles)` de `gameSettingsProvider` →
  `SessionBattleScreen` → `BattleView.sceneOptions` →
  `BattleSceneController.options` (leído por `advance`, `viewFor` y
  `BattleScenePainter`). Solo cambia el dibujo.
- Mapa: `WorldScreen` pone `MapGame.scaleMode` y
  `MapGame.particleDensity` en cada build.
- CRT: `EcosApp` (`MaterialApp.builder`) → `CrtFilter(level)`.
- FPS: `GameSettingsController` → `FrameLimiter.shared.fps` →
  `EcosBinding` (los `main_*.dart` usan `EcosBinding.ensureInitialized()`).
- Inventario: `InventoryTab` lee `confirmDrop` al tocar `TIRAR`.

## 10. Tests

- `test/core/settings/game_settings_test.dart`: JSON, controlador
  (guardar, ventana, cargar en pantalla completa, límite de FPS),
  `game.json` (incluido uno viejo con `battleSpeed`), `audio.json`
  viejo sin `master`, volumen general, muestra de FX.
- `test/core/settings/graphics_test.dart`: `mapViewRect` entero / ajustar
  para varias ventanas, `scaledCount`, ráfagas de partículas por nivel,
  `FrameLimiter` (30 / 60 / sin límite en monitores de 60, 120 y 144 Hz,
  re-sincronizar), zoom entero de la batalla en PIXEL PERFECT.
- `test/core/settings/crt_filter_test.dart`: CRT en NORMAL por defecto,
  APAGADO no envuelve nada, uniformes de cada nivel, corrección del
  hit-test con curvatura.
- `test/features/settings_menu_test.dart`: cada pestaña aplica y guarda
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
