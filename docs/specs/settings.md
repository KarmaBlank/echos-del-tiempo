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
  `gold`) para el resto (`SÍ / NO`, `NORMALES / SUAVES / NO`, `x1 / x1.5
  / x2`, `VENTANA / PANTALLA COMPLETA`).
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

## 4. JUEGO

| Ajuste | Opciones | Efecto |
|---|---|---|
| ANIMACIONES DE BATALLA | x1 / x1.5 / x2 | multiplica el reloj de la escena de batalla (`BattleSceneController.advance`) y divide los retrasos de los sonidos de cada paso (`SessionSfx.animSpeed`) para que sigan alineados. **Solo en tu pantalla**: el ritmo de los turnos lo marca el host (`SessionBattle.wait`), así que no se acorta la batalla, solo la espera visual |
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
- `game.json` (nuevo, misma carpeta que el perfil, escritura atómica):
  `{"fullscreen":false,"shake":true,"flashes":"normal","battleSpeed":1,
  "damageNumbers":true,"confirmDrop":true}`. Valores inválidos o
  ausentes = por defecto; la velocidad se ajusta a la ofrecida más
  cercana. Corrupto = por defecto.
- `GameSettingsController` (`lib/core/settings/game_settings.dart`):
  carga al arrancar (el título lo pide) y aplica pantalla completa;
  cada cambio se aplica y se guarda. Provider: `gameSettingsProvider`
  (`lib/core/settings/settings_providers.dart`).

## 9. Cómo llegan los ajustes al juego

- Batalla: `WorldScreen` arma `SceneOptions(shake, flash, damageNumbers,
  speed)` de `gameSettingsProvider` → `SessionBattleScreen` →
  `BattleView.sceneOptions` → `BattleSceneController.options` (leído por
  `advance` y `BattleScenePainter`). Solo cambia el dibujo.
- Sonidos de batalla: `sessionSfxProvider` escucha `gameSettingsProvider`
  y pone `SessionSfx.animSpeed`.
- Inventario: `InventoryTab` lee `confirmDrop` al tocar `TIRAR`.

## 10. Tests

- `test/core/settings/game_settings_test.dart`: JSON, controlador
  (guardar, ventana, cargar en pantalla completa), `game.json`, `audio.json`
  viejo sin `master`, volumen general, muestra de FX.
- `test/features/settings_menu_test.dart`: cada pestaña aplica y guarda
  (stores en memoria, ventana falsa), muestra de FX al mover el slider,
  pantalla completa oculta sin soporte, `CONFIGURACIÓN` del título.
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
