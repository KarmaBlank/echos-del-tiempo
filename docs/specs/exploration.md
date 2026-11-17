# Spec: Exploración (mapa, HUD y flujo de sesión local)

Fuente de verdad: prototipo `ecos-del-tiempo.html`:
- constantes `TS=16`, `VW=480`, `VH=288` (línea 112) y `THEMES`
  (líneas 298-303);
- entrada del cliente `keydown`, `nearSeal`, `nearMerchant`, `nearArm`,
  `nearCounter`, `cycleTarget`, `updateMe` (líneas 907-953);
- cámara `cam`, `lerpPos` (956-963); `drawTile` (964-988); `drawHero`
  (989-1008); `drawEnemy` (1009-1017); `render` (1019-1091);
- HUD: `drawObjectives`, `drawMinimap`, `drawBadges`, `hud()` y los
  paneles `board`, `prep`, `char` y el resultado (1092-1360).

Las reglas del host (qué pasa al tocar un enemigo, votar, etc.) son de
docs/specs/missions.md, world.md y progression.md. Este spec cubre solo
al **cliente**: cómo se dibuja la sesión y cómo se traduce la entrada en
`SessionAction`.

Implementación Dart (feature `world` + piezas de `missions` y `combat`):

| Pieza | Archivo |
|---|---|
| Controlador de sesión (local, host o cliente) | `lib/features/world/presentation/session_controller.dart` |
| Vista inmutable para la UI | `lib/features/world/presentation/session_view.dart` |
| Jugador local (`me`) | `lib/features/world/presentation/local_player.dart` |
| Pantalla raíz del juego | `lib/features/world/presentation/world_screen.dart` |
| Juego Flame del mapa | `lib/features/world/presentation/map/map_game.dart` |
| Tiles y temas | `lib/features/world/presentation/map/tile_painter.dart`, `map_themes.dart` |
| Héroes, enemigos y objetos | `lib/features/world/presentation/map/actor_painter.dart` |
| HUD (overlays Flutter) | `lib/features/world/presentation/hud/*.dart` |
| Título (nombre, clase) | `lib/features/lobby/presentation/title_screen.dart` |
| Chat | `lib/features/world/presentation/hud/chat_box.dart` |
| Sonido (oyente de eventos) | `lib/features/world/presentation/session_sfx.dart` (docs/specs/audio.md) |
| Personaje (atributos, armas, árbol) | `lib/features/world/presentation/panels/character_panel.dart` (docs/specs/panels.md) |
| Armería, herrería, fusión | `lib/features/inventory/presentation/*.dart` (docs/specs/panels.md) |
| Árbol de pasivas | `lib/features/passive_tree/presentation/passive_tree_view.dart` |
| Marco de paneles, botón compacto, barras | `lib/app/theme/panel_frame.dart`, `retro_theme.dart`, `retro_bar.dart` |
| Mostrador, votación, preparación, resultado | `lib/features/missions/presentation/*.dart` |
| Batalla dirigida por la sesión | `lib/features/world/presentation/session_battle_screen.dart` + `lib/features/combat/presentation/battle_screen.dart` (`BattleView`) |
| Sprites ya decodificados | `lib/features/combat/presentation/game_sprites.dart` (+ `pixel_sprite.dart` para widgets) |
| Perfil en disco | `lib/features/lobby/data/json_file_profile_store.dart` |

Tests: `test/features/world/session_flow_test.dart`,
`test/features/world/session_controller_test.dart`,
`test/features/world/chat_input_test.dart`,
`test/features/lobby/title_screen_test.dart`,
`test/features/combat/battle_screen_test.dart`.

## Título (`#title` y `title()`, HTML 70-83 y líneas 1471-1490)

- `ECOS DEL TIEMPO` (32 px `gold`, sombra dura `red`), subtítulo y, si
  el perfil guardado es de nivel > 1, `· Tu nivel guardado: N`.
- `Nombre:` campo de 10 caracteres (`maxlength`), con el nombre guardado.
- Una tarjeta por clase permitida (`FeatureFlags`): sprite del héroe
  ×4, nombre, descripción (`ClassDef.description`, el `desc` del
  prototipo), atributos base y arma inicial. La elegida tiene borde
  `gold`. Elegir otra clase hace lo mismo que el prototipo:
  `classId = k`, `equipped = arma inicial` y `resetBuild` (el árbol que
  no sirva lo descarta `normalize` al entrar).
- `> COMENZAR` (`prep()`): nombre recortado (vacío → `Héroe`, máx. 10),
  guarda el perfil con `ProfileStore.save` y abre `WorldScreen`, que lo
  carga. **Agregado del puerto**: el prototipo solo tiene "Crear sala" /
  "Unirse".
- `CREAR SALA`, el campo de código y `UNIRSE` dependen de la
  `NetSessionFactory` que registró el composition root (docs/specs/netcode.md):
  - sin fábrica (tests, builds sin red): deshabilitados con
    `P2P: próximamente`;
  - fábrica no disponible (P2P sin Firebase): deshabilitados con su
    motivo (`P2P por internet: falta configurar Firebase`);
  - disponible: el campo muestra `codeHint` (`IP:PUERTO` en LAN,
    `CODIGO` en P2P) y una etiqueta con `label` (`LAN` / `P2P`).
    `CREAR SALA` guarda el perfil y conecta como host; `UNIRSE` exige un
    código (`Escribe el código de la sala.`), guarda el perfil y conecta
    como cliente. Mientras conecta se muestra `Creando sala…` /
    `Conectando a X…` y los botones se deshabilitan; un error de
    conexión (`NetException`) se muestra en rojo debajo.
  - Al conectar se abre `WorldScreen` con esa `NetSession`. Si la
    pantalla del juego se cierra por una desconexión, el título muestra
    el motivo (p. ej. `Se perdió la conexión con el host.`).
- La línea de ayuda de controles del prototipo.

## Flujo de pantallas

```
Título ("> COMENZAR", guarda nombre y clase) ──push──> WorldScreen
WorldScreen según SessionMode:
  lobby / prep / field / levelUp → mapa Flame + HUD + paneles
  battle                          → SessionBattleScreen (encima del mapa)
  result                          → ResultsPanel (encima del mapa)
```

`WorldScreen` no navega con rutas: dibuja lo que pide `session.mode`, así
el modo autoritativo del host es lo único que decide la pantalla (igual
que el prototipo, que es una sola página). "Volver" del resultado manda
`BackToLobbyAction`. El botón "< TITULO" del HUD (solo en el lobby)
vuelve al título; eso descarta el controlador (`autoDispose`), que
guarda el perfil. El `GameWidget` sigue montado (y dibujando) debajo de
la batalla y del resultado.

## Controlador de sesión (local, host o cliente)

`SessionController` (Riverpod `StateNotifier<SessionView?>`, `null`
mientras carga) tiene tres roles según la `NetSession` que recibe
(`activeNetSessionProvider`, que el título llena al crear/unirse):

| Rol | `net` | `localId` | Motor |
|---|---|---|---|
| Local | `null` | `local` | corre `SessionEngine` |
| Host | `isHost` | `net.localId` (`h`) | corre `SessionEngine` |
| Cliente | `!isHost` | `net.localId` (el del `welcome`) | **no** corre reglas |

Local y host (el host del prototipo corriendo en este dispositivo):

1. `start()`: `ProfileStore.load()`; si no hay perfil se crea
   `PlayerProfile(name: 'Héroe', classId: 'guerrero')`. `engine.create()`
   + `engine.addPlayer(s, localId, perfil)`. El host además dice
   `Sala creada. Comparte el código X con tus amigos.` (como el
   prototipo) y empieza a escuchar `net.events`.
2. **Tick fijo**: un `Timer.periodic` cada `SessionClock.interval`
   (50 ms, el `setInterval(hostTick, 50)` del prototipo) llama a
   `engine.tick(s, interval × timeScale)`. Los tests usan `timeScale`
   alto o `advance(seconds)` para ir rápido.
3. **Posición**: antes de cada tick, si el modo es lobby o campo, el
   jugador está vivo y no hay panel abierto, se aplica
   `MoveAction(x, y, dir, moving, epoch)` con la posición local (el
   `send({t:'pos'})` cada 50 ms del prototipo, redondeado a 0.1 px).
4. **Entrada**: cada acción de la UI pasa por `engine.apply`; si devuelve
   `null` la acción se ignora (como el host del prototipo).
5. **Red (solo host)**: `PeerJoinedEvent` → `engine.addPlayer(id,
   perfil)`; `PeerActionEvent` → `engine.apply(id, acción)` (con el id
   del enlace); `PeerLeftEvent` → `engine.removePlayer(id)`. Un segundo
   `Timer.periodic` de 66 ms hace `net.broadcast(estado, eventos
   pendientes)`; `advance` (tests) difunde después de cada tick.

Cliente:

1. `start()`: no crea sala ni agrega jugadores; la vista sigue en `null`
   (`CARGANDO...`) hasta el primer snapshot.
2. `SnapshotEvent(sesión, eventos)` pasa por el mismo `_step` que los
   pasos del motor (mensajes, chat, eventos de batalla, sonido,
   guardado), así la UI no distingue roles.
3. Un `Timer.periodic` de 50 ms manda la posición local con
   `net.sendAction(MoveAction(...))` (mismas condiciones que el punto 3
   del host).
4. Cada acción de la UI se manda con `net.sendAction` y devuelve `true`
   (enviada); el host decide. Nunca se infiere estado de una acción: se
   espera el snapshot.
5. `ConnectionLostEvent` → `SessionView.disconnected` con el motivo;
   `WorldScreen` vuelve al título y lo muestra.

Comunes:

6. **Eventos**: `SystemMessageEvent` se agrega al registro (últimos 50).
   `BattleStepEvent` reemplaza `battleEvents` (la batalla los usa para
   los números de daño) y sube `battleEventSeq`. Todos los eventos se
   publican además en `events` (un `Stream`) para sonido/animaciones.
7. **Guardado** (`saveProfile`): si el perfil del jugador local cambió
   (mismo objeto o, en el cliente, el mismo JSON), se guarda como mucho
   cada 2 s (`lastSave` del prototipo), y siempre al terminar una
   misión, al volver al lobby y al descartar el controlador. El cliente
   guarda el perfil que le manda el host (como el prototipo).
8. **Salida**: descartar el controlador cancela los timers y llama a
   `net.disconnect()`.

### Jugador local (`updateMe`)

`LocalPlayer` guarda `x, y, dir, moving, epoch` (el `me` del prototipo).
- Cada vez que la `epoch` del snapshot cambia, se adoptan `x, y` del
  snapshot (teletransportes del host: inicio de misión, fin de batalla,
  vuelta al lobby).
- `MapGame.update(dt)` llama a `controller.updateLocal(dt, ix, iy)` con
  `dt ≤ 0.05` s. En lobby/campo, vivo y sin panel: `WorldRules.stepPlayer`
  (78 px/s, diagonal normalizada) con `gateOpen` del snapshot; `dir`
  cambia solo con movimiento horizontal. Si no, `moving = false`.

### Paneles

Un solo panel abierto a la vez (`WorldPanel`: `missionBoard`, `armory`,
`character`, `prep`), igual que `panel` del prototipo. Reglas
automáticas (de `hud()`), evaluadas en cada estado nuevo:
- en `prep` sin panel (o con mostrador/armería) se abre `prep`;
- `prep` se cierra al salir de `prep`; mostrador y armería fuera del lobby;
- si `mustAllocate(localId)` se fuerza `character` (y se cierra solo
  cuando ya no hace falta);
- en batalla o resultado no hay paneles.

`closePanel` no cierra si hay que repartir puntos; en `prep` vuelve al
panel de preparación en vez de cerrar.

## Teclado

| Tecla | Dónde | Acción |
|---|---|---|
| WASD / flechas | lobby, campo | mover (se leen del estado del teclado cada frame) |
| E / Espacio | lobby, frente al mostrador | abre el mostrador de misiones |
| E / Espacio | lobby, frente a la armería | abre la armería |
| Enter | fuera de batalla y resultado (con el chat visible) | enfoca el campo de chat |
| Enter / Esc | escribiendo en el chat | manda el mensaje / sale sin mandar; el foco vuelve al juego |
| E / Espacio | campo, a < 26 px de un sello | `ActivateSealAction` |
| C | fuera de batalla | abre/cierra el panel de personaje |
| Esc | con panel | cierra el panel (salvo las reglas de arriba) |
| Y / N | lobby, votación pendiente | `VoteMissionAction(true/false)` |
| 1-9 | batalla, tu turno | el botón N del menú de comandos |
| Q / Tab | batalla | `cycleTarget`: siguiente enemigo vivo |
| Esc | batalla, submenú de poción | volver |

Zonas (`WorldRules`): mostrador `y < 4.6·TS` y `8.5·TS < x < 17.5·TS`;
armería `y < 4.6·TS` y `18.5·TS < x < 24.5·TS`; sello a `< 26 px`
(`WorldRules.sealPromptRange`). `nearMerchant` (40 px) está implementado
pero el mapa nunca tiene mercader (ver world.md).

Las teclas llegan a un `Focus` raíz de `WorldScreen` (que recupera el
foco si lo pierde); WASD, flechas, Tab y Espacio se marcan como
manejadas para que no muevan el foco entre botones.

## Chat (`#chatbox`, líneas 103-106, 582, 909-916 y 1376-1379)

- `ChatBox` (abajo a la izquierda, reemplaza al registro): las últimas 5
  líneas de `SessionView.chat` (sistema en `green` con `> `, jugadores
  `nombre:` en `gold` + texto) y el campo `Enter para chatear...` de
  120 caracteres.
- Enter en el mapa enfoca el campo. Mientras el campo tiene el foco, el
  `Focus` raíz de `WorldScreen` deja pasar **todas** las teclas
  (`ignored`) para que lleguen al texto, y `SessionController.typing`
  anula el movimiento (`updateLocal` usa entrada 0 aunque el teclado
  tenga WASD apretadas). Enter manda `ChatAction(texto)` (si no está
  vacío) y Esc sale sin mandar; en ambos casos el foco vuelve al juego.
- El host (`SessionEngine`, `case 'chat'`) recorta espacios y a 120
  caracteres, rechaza vacíos y emite `ChatMessageEvent(id, nombre,
  texto)` sin cambiar el estado: en la sesión local es el eco del
  prototipo (`broadcast(m); addChat(m)`). El controlador guarda chat y
  sistema mezclados (máx. 50); `messages` sigue teniendo solo los de
  sistema.
- **Desvío / pendiente**: en batalla y en el resultado el chat no se
  muestra (la pantalla de batalla ocupa todo); el prototipo lo tiene
  siempre debajo del canvas.

## Resolución virtual y escalado

- El mundo se dibuja a **480 × 288** px virtuales (`VW × VH`) en un
  `PictureRecorder` y se rasteriza (`toImageSync`). Esa imagen se escala
  al tamaño del `GameWidget` con `FilterQuality.none` (vecino más
  cercano), manteniendo la proporción (`min(w/480, h/288)`) y centrada,
  con bandas `#05060c`. Así el texto del mundo (nombres, `JEFE`) también
  queda pixelado como en el canvas del prototipo.
- Todo se dibuja en coordenadas enteras (`round`) dentro del lienzo
  virtual; los sprites con `SpriteCatalog.pixelPaint()`.

## Cámara (`render`, líneas 1021-1025)

Sin batalla, el foco es el jugador local. Con `mw = ancho·TS`,
`mh = alto·TS`:

```
tx = mw < VW ? (mw − VW)/2 : clamp(fx − VW/2, 0, mw − VW)
ty = mh < VH ? (mh − VH)/2 : clamp(fy − VH/2, 0, mh − VH)
cam += (t − cam) · 0.25        // por frame de 60 Hz
si |cam − t| > 200 en x o y → cam = t (salto)
```

El lobby (26×14 tiles = 416×224 px) es más chico que la pantalla: queda
centrado con `tx = −32`, `ty = −32`.

**Desvío**: el prototipo suaviza por frame (`requestAnimationFrame`). El
puerto usa el factor equivalente independiente del frame rate:
`k = 1 − (1 − 0.25)^(dt·60)`. Lo mismo para `lerpPos` (0.35, salto si
la distancia es > 60 px), que suaviza a los demás jugadores y a los
enemigos del campo (el jugador local se dibuja en su posición exacta).

## Capas del mapa (orden de dibujo)

1. Fondo `#05060c` en todo el lienzo virtual.
2. Traslado `−round(cam)`.
3. Tiles visibles: `x0 = max(0, floor(cam.x/TS))`,
   `x1 = min(w−1, x0 + VW/TS + 1)` (ídem `y`), con `drawTile`.
4. Carteles del lobby: `MOSTRADOR DE MISIONES` en `(13·TS, TS+10)`
   `#48dbfb` 7 px y `ARMERÍA` en `(21.5·TS, TS+10)` `#ff9f43` 7 px.
5. Entidades ordenadas por `y` (pies), de arriba hacia abajo:
   - jugadores (`drawHero` + nombre en `y−22`, dorado `#ffd166` el local);
   - en campo / subida de nivel: fragmentos y cofres sin recoger, sellos
     (activos o no);
   - en campo / subida de nivel: enemigos vivos del campo (`drawEnemy`
     con el primer tipo del grupo) con `*ÉLITE` (`y−34`), `!` de aggro
     (`y−22 + sin(t/90)·1.5`, rojo, 9 px) y `JEFE` (`y−48`, 7 px).
6. Fin del traslado. Los carteles en pantalla del prototipo (`[E] ...`,
   subida de nivel, barrera abierta), objetivos y minimapa son overlays
   Flutter del HUD (abajo).

Texto en el mundo (`txt`): Press Start 2P centrado, sombra negra +1/+1.
`★` no existe en la fuente: se usa `*`.

### Tiles (`drawTile`)

Hash por tile `h = ((tx·73856093) ^ (ty·19349663)) >>> 0` con la
aritmética de JS: el producto se lleva a int32, y los `h >> n` usan el
entero **con signo** (puede dar restos negativos con `%`, como en JS).

- `.` suelo: `g`; lobby: damero `g2` cuando `(tx+ty)` es par + línea
  superior `#ffffff08`. Fuera del lobby: punto 2×2 `g2` si `h%3==0` en
  `((h>>3)%12, (h>>7)%12)` y raya 1×3 si `h%5==0` en
  `((h>>11)%13, (h>>15)%13)`.
- `,` camino: `path` + punto 2×2 `p2` si `h%2==0` en
  `((h>>4)%13, (h>>9)%13)`; lobby: línea superior `#ffd16633`.
- `#` muro: lobby: `w` + franja `w2` en `y+12` de 2 px + ventanas
  `#48dbfb55` (6×8 en `+5,+3`) en la fila 0 cada 4 tiles. Pradera: suelo
  + tronco `#4a2f1a` (6,10,4,6) + copa círculo `w` (8,7) r8 + brillo `w2`
  (6,5) r4. Ruinas: suelo + bloque `w` (1,1,14,15) + tapa `w2` 3 px +
  junta `#00000055` en y+8 + grieta vertical en x 5 ó 10. Abismo: `w` +
  cristal triángulo `w2` (8,1)-(12,13)-(4,13) + brillo `#ffffff55`.
- `~` agua: `wat` + ola `#ffffff40` 5×1 en
  `(o·3, 4 + (ty%2)·6)` con `o = floor(t/250 + tx) % 4`.
- `G` barrera: abierta → `path`; cerrada → suelo + barrotes 2 px cada
  5 px en rojo `rgba(255,71,87, 0.5 + 0.3·sin(t/120 + ty))`.
- `C` mostrador, `A` armería, `M` mercader: suelo + mueble según el
  prototipo (madera `#6b4423`/`#c08a4a`, pantalla `#48dbfb` en los
  tiles 12-13; armería `#3d3d4a`/`#8395a7` con espada `#dfe6e9` o
  antorcha `#8a5a2b`/`#ff7b29` alternadas; toldo rojo/blanco del
  mercader).

**Decisión de color**: los colores de `THEMES` y de los muebles, objetos
y actores son **arte** (como los PNG de sprites), no chrome de UI: no
pasan por `RetroPalette`. Viven en `map_themes.dart` y en los pintores
del mapa con su hex del prototipo. Todo el chrome (HUD, paneles,
botones, textos de interfaz) sí usa `RetroPalette`/`RetroPanel`.

| Tema | g | g2 | w | w2 | path | p2 | wat |
|---|---|---|---|---|---|---|---|
| pradera | #3f8f3a | #57a84a | #1f5f2a | #2f7d37 | #b89a5a | #a3874c | #2e86de |
| ruinas | #5f5f68 | #6c6c76 | #34343c | #82828e | #8a7f6a | #776d5a | #1e6091 |
| abismo | #2c1f45 | #3a2a5a | #120a22 | #9b59ff | #4e3478 | #432c68 | #6c2bd9 |
| lobby | #2d3a55 | #34446a | #161d33 | #3d4d80 | #5a3a6a | #4a2f5a | #48dbfb |

### Actores

`drawHero` y `drawEnemy` siguen docs/specs/sprites.md § "Animaciones
procedurales" (sombra, bob de 140 ms, espejado, arma dibujada encima,
parpadeo de gracia de 110 ms en el campo, caído rotado 90°, flotación de
murciélagos y espectros, aura élite). La flotación se lee del manifest
(`enemies.<tipo>.float`, `SpriteCatalog.enemyFloats`), no de una lista
en código.

### Objetos (campo y subida de nivel)

- **Fragmento** (sin recoger): sombra 4×1.5; rombo `#48dbfb`
  `(0,−12)(4,−6)(0,0)(−4,−6)` + brillo `#dff9fb` 2×3 en `(−1,−9)`; flota
  `b = sin(t/250 + id)·2`; destello blanco 1×1 cuando
  `floor(t/400 + id) % 3 == 0`.
- **Sello**: sombra 7×2; pilar 10×18 (`#3d2c5a` apagado, `#2d6a4f`
  activo) y runa `#a29bfe` (apagado, alfa `0.5 + 0.3·sin(t/200)`) o
  `#7bed9f` (activo) + halo `#7bed9f` alfa 0.25 r12 cuando está activo.
- **Cofre** (sin abrir): sombra 8×2.5; cuerpo `#8a5a2b` 16×10, tapa
  `#b3781f` 16×5, cerradura `#ffd166`, borde `#5a3a1a`; bob
  `sin(t/300 + id)·1.5`; el destello `✦` del prototipo es un rombo de
  3 px `#ffd166` con alfa `0.5 + 0.3·sin(t/180)`.

## HUD (overlays Flutter sobre el `GameWidget`)

Todo con `RetroPanel` (padding 8) y texto de 8 px (`bodySmall`).

- **Barra de misión** (arriba al centro, `#mission` del prototipo):
  en misión `nombre · objetivos · mm:ss` (o `¡Derrota al jefe!` con la
  barrera abierta); en el lobby
  `Lobby · Mostrador [E] · Armería [E] · Personaje [C]`; en `prep`
  `Preparación de misión`.
- **Objetivos** (arriba a la izquierda, solo campo; `drawObjectives`):
  una línea por objetivo `Etiqueta n/goal` (verde si está cumplido) y
  la línea del jefe (`* ¡Ve por el JEFE!` / `Jefe: completa los
  objetivos`).
- **Minimapa** (arriba a la derecha, campo y subida de nivel, nunca en
  el lobby; `drawMinimap`): 1 tile = 2.5 px de pantalla (el doble del
  1.25 virtual del prototipo; los puntos también ×2); colores del
  prototipo (`#0b0e1a` muro/barrera, `#2e86de` agua, `#6c7a9c` camino,
  `#4b5878` suelo), barrera roja/verde, enemigos `#ff4757` (élite
  `#ffd166`, más grande), fragmentos `#48dbfb`, sellos `#a29bfe`/`#7bed9f`,
  cofres `#ffd166`, jefe `*` que alterna `#e84393`/`#ffd166` cada 300 ms,
  jugador local blanco y aliados `#48dbfb`. Son colores de arte (como el
  mapa).
- **Grupo** (abajo a la derecha, `#party`): una fila de `.pbox`
  (`PartyBox`, docs/specs/ui_style.md § "Caja de jugador"), una por
  jugador, con los colores de `hud()` (línea 1195): nombre +
  `Clase LvN` en `#9fb4ff`; arma en `#ff9f43` con `+N pts` en `#ffd166`;
  barra `#2ed573` + `HP ceil(hp)/max`; barra `#1e90ff` + `MP
  floor(mp)/max`; `XP n/xpNeed · ₵créditos` en `#7d8bc4`; `Pociones:`
  con `♥n` `#7bed9f` y `✦n` (`♦`) `#74b9ff`. El chat se achica para que
  la fila entre.
- **Chat** (abajo a la izquierda): ver § "Chat".
- **Aviso de interacción** (abajo al centro): `[E] Ver misiones`,
  `[E] Armería`, `[E] Activar sello`, `[E] Tienda y herrería`.
- **Barrera abierta**: `La barrera se abrió > busca al JEFE (* en el
  minimapa)` mientras el jugador está a más de 140 px del jefe.
- **Votación** (arriba al centro, en el lobby): `VotePanel`, ver
  docs/specs/panels.md § "Votación".
- **Subida de nivel**: `¡SUBIDA DE NIVEL!` + `Esperando a: nombres`.

## Paneles

El contenido y las reglas de cada panel (mostrador, votación,
preparación, armería, personaje y árbol) están en docs/specs/panels.md.
Resumen:

- **Mostrador** (`board`): misiones y `PROPONER` (cierra el panel), cambio
  de clase. Con un solo jugador la votación pasa sola en el siguiente
  tick (el que propone ya votó que sí).
- **Preparación** (`prep`): listos, `¡LISTO!`, `PERSONAJE / EQUIPAR
  [C]`, `CANCELAR MISIÓN` y la tienda completa (consumibles, herrería,
  fusión, armería).
- **Armería** (lobby): armas de su clase, consumibles, herrería (+
  equipar) y fusión.
- **Personaje**: pestañas `ATRIBUTOS` (reparto con vista previa
  antes > después, reiniciar, clase), `ARMAS` (equipar) y `ÁRBOL`.
  Cuando `mustAllocate` es cierto se abre solo en Atributos, sin
  pestañas, y no se puede cerrar.
- **Resultado**: `MISIÓN COMPLETADA`/`MISIÓN FALLIDA`, misión, rango
  grande, tiempo `m:ss`, K.O., XP, créditos de peleas, bonus de rango
  (`+₵ (n%)`), élites y sus armas, arma obtenida por cada jugador,
  `VOLVER AL LOBBY` (`BackToLobbyAction`) y `Regreso automático en Ns`.

## Batalla

`SessionBattleScreen` lee `session.battle`:
- `BattleView` dibuja la escena del prototipo **sobre el mapa de la
  misión**, en el lugar del enemigo del campo que empezó la batalla
  (grupo a un lado, enemigos al otro), con animaciones, efectos,
  cinemáticas de ultimate y la franja de turnos: todo en
  docs/specs/battle_presentation.md. `SessionBattleScreen` le pasa la
  arena (posición, lado, tamaño del mapa y un callback que dibuja tiles y
  enemigos lejanos con `TilePainter` / `ActorPainter`), `battleEvents`,
  `battleEventSeq` y el id de la batalla.
- El menú aparece solo si `battle.waitingForPlayer` y el turno es del
  jugador local; cada opción manda `BattleAction(cmd)` con el objetivo
  actual (`tgt` del prototipo: primer enemigo vivo si el elegido cayó;
  Q/Tab o clic sobre el enemigo en la escena lo cambian).
- Menú (`#menu`, líneas 1205-1223) solo en el turno del jugador local,
  centrado sobre la escena (máx. 900 px), borde 2 px `#ffd166`: cabecera
  `<b>` dorada `Ns · ¡Tu turno! (nombre) · ATQ · MAG · DEF · Crítico n%
  (×m)` (el tiempo en `#ff4757` con ≤ 10 s) y botones numerados en 3
  columnas (`button`; `.dual` = ULT y dúos a fila entera con borde
  `#ff9f1c` y texto `#ffd166`), con los textos coloreados del prototipo:
  daño estimado `#ffd166` y `(crít N)` `#7d8bc4`, estado `+N` + letra en
  su color, `+X% crít` `#ff6b81`, MP `#74b9ff`, curas `#7bed9f`, etc.
  Orden: `Atacar`, `★ ULTIMATE` (deshabilitada < 100%), técnicas
  (deshabilitadas sin MP), dúos, `Poción de vida xN ▸ elegir a quién`,
  `Poción de maná xN ▸ ...` (submenú `¿A quién le das ...?` con HP/MP en
  `#9fb4ff` y `+N` verde/celeste) y `Defender`. Al pasar el mouse, el
  `#tip` (`RetroTooltip`) con `descSkill` en markup.
- Cajas del grupo en batalla (`BattlePartyBox`): como las del mapa más
  barra de ULT de 5 px (`#a29bfe`, `#e84393` + `¡LISTA!` al 100%), la
  línea `DEF n [Protege] · VEL x.x` en `#9fb4ff` con los estados (letra +
  stacks en su color) y `Provoca n` `#ff7675`, y el turno: `▶ SU TURNO`
  dorado o `Turno en N` / `Fuera de combate` en `#7d8bc4` (índice en
  `predictTurns`). Sin menú, solo se ven las cajas.
- Tiempo de turno: `30 − turnTime` s (`TURN_LIMIT`), en la franja.

## Persistencia

`ProfileStore` (contrato en `game_engine/models/profile_store.dart`):
- `JsonFileProfileStore`: `profile.json` (`PlayerProfile.toJson`) en la
  carpeta de datos del usuario sin paquetes nuevos (`dart:io`):
  `%APPDATA%\EcosDelTiempo` en Windows,
  `~/Library/Application Support/EcosDelTiempo` en macOS,
  `$XDG_DATA_HOME` o `~/.local/share/ecos_del_tiempo` en Linux.
  Escritura atómica (archivo temporal + `rename`). Un JSON corrupto se
  trata como "sin perfil".
- En otras plataformas (Android, iOS, web) `InMemoryProfileStore`
  hasta que se agregue `path_provider`/`shared_preferences` como
  dependencia directa.

## Desvíos respecto del prototipo

- Suavizado de cámara y `lerpPos` independientes del frame rate.
- `★`, `✔`, `✦`, `🔒`, `₵` y las mayúsculas acentuadas no existen en
  Press Start 2P: `*`, color verde, rombo dibujado, texto plano, `$` y
  mayúsculas sin tilde (`retroText`).
- Las teclas de interacción usan el `Focus` de la pantalla; el
  `GameWidget` queda fuera del foco (`ExcludeFocus`) porque se tragaría
  todas las teclas.
- Batalla: el menú apunta al objetivo con Q/Tab o clic en el enemigo,
  sin submenú de "elegí un enemigo" (como el prototipo).
- Objetivos y minimapa son widgets (no se dibujan en el canvas) y usan
  píxeles de pantalla, no virtuales.
- Chat sin mostrarse en batalla ni en el resultado (ver § "Chat").
- Sonido sintetizado pero mudo hasta agregar un plugin de audio
  (docs/specs/audio.md).
