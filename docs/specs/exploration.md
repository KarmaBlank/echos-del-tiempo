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
| Título (selección de personaje) | `lib/features/lobby/presentation/title_screen.dart` |
| Personajes y alijo (cuenta) | `lib/features/characters/` (characters.md) |
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

- `ECOS DEL TIEMPO` (32 px `gold`, sombra dura `red`) y subtítulo.
- **Selección de personaje** (v0.3, docs/specs/characters.md § 2): la
  cuenta tiene hasta 8 personajes; el título los lista (sprite, nombre,
  clase, nivel, zona, última partida) con `> JUGAR`, `CREAR PERSONAJE`,
  `RENOMBRAR`, `BORRAR` (con el nombre escrito como confirmación) y
  `ALIJO`. Sin personajes abre el creador.
- Creador (lo que antes era el título entero): `Nombre:` de 10
  caracteres (`maxlength`, vacío → `Héroe`) y una tarjeta por clase
  permitida (`FeatureFlags`): sprite del héroe ×4, nombre, descripción
  (`ClassDef.description`, el `desc` del prototipo), atributos base y
  arma inicial. La elegida tiene borde `gold`. `CREAR` arma el perfil
  nuevo normalizado (clase, arma inicial, atributos base).
- `> JUGAR`: anota la fecha en el personaje elegido, lo guarda con
  `ProfileStore.save` (que en la app es el personaje elegido de la
  cuenta) y abre `WorldScreen`, que lo carga. **Agregado del puerto**:
  el prototipo solo tiene "Crear sala" / "Unirse".
- `CREAR SALA`, el campo de código y `UNIRSE` dependen de la
  `NetSessionFactory` que registró el composition root (docs/specs/netcode.md):
  - sin fábrica (tests, builds sin red): deshabilitados con
    `P2P: próximamente`;
  - fábrica no disponible (P2P sin Firebase): deshabilitados con su
    motivo (`P2P por internet: falta configurar Firebase`);
  - disponible: el campo muestra `codeHint` (`IP:PUERTO` en LAN,
    `CODIGO` en P2P) y una etiqueta con `label` (`LAN` / `P2P`).
    `CREAR SALA` guarda el personaje elegido y conecta como host; `UNIRSE`
    exige un código (`Escribe el código de la sala.`), lo guarda y conecta
    como cliente. Mientras conecta se muestra `Creando sala…` /
    `Conectando a X…` y los botones se deshabilitan; un error de
    conexión (`NetException`) se muestra en rojo debajo.
  - Al conectar se abre `WorldScreen` con esa `NetSession`. Si la
    pantalla del juego se cierra por una desconexión, el título muestra
    el motivo (p. ej. `Se perdió la conexión con el host.`).
- La línea de ayuda de controles del prototipo.

## Flujo de pantallas

```
Título ("> JUGAR" con el personaje elegido) ──push──> WorldScreen
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
   guarda el perfil que le manda el host (como el prototipo). Un
   guardado solo cuenta si la escritura salió bien: si falla se
   reintenta (2 s) y la vista lleva `saveError` (aviso rojo en el HUD).
   Al iniciar, el controlador se registra en `ExitGuard` para guardar
   si se cierra la ventana o se actualiza a mitad de partida. El
   cliente carga el Atlas de su cuenta antes del primer snapshot
   (un Eco completado suma a ese, no a uno vacío). Ver
   characters.md § 1.4.
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
| Enter | fuera de batalla y resultado | despliega el chat (si está oculto) y enfoca el campo |
| J | campo, sin panel | pliega / despliega la caja de objetivos (v0.8.1) |
| M | campo o mapa del mundo (con o sin el mapa abierto) | abre / cierra el mapa en grande (v0.8.1) |
| Flechas / WASD, `+` `-`, C | mapa en grande | mover, zoom, centrar en el jugador |
| Rueda | sobre el minimapa | zoom del minimapa (1..3, se recuerda) |
| Enter / Esc | escribiendo en el chat | manda el mensaje / sale sin mandar; el foco vuelve al juego |
| E / Espacio | campo, a < 26 px de un sello | `ActivateSealAction` |
| E / Espacio | lobby o campo, sin otro aviso a mano, a ≤ 24 px de loot dibujado | `PickUpAction` del más cercano (`MapGame.tryPickUp`, se lee del teclado en cada frame: solo el flanco de bajada) |
| Alt (mantener) | lobby o campo | muestra también el loot que el filtro oculta (etiqueta a media opacidad; se puede levantar con E) |
| C | fuera de batalla | abre/cierra el panel de personaje |
| Esc | con panel | cierra el panel (salvo las reglas de arriba) |
| Esc | sin panel ni campo de texto (lobby, campo, subida de nivel, resultado) | abre / cierra el menú de pausa (docs/specs/settings.md § 6) |
| Y / N | lobby, votación pendiente | `VoteMissionAction(true/false)` |
| 1-9 | batalla, tu turno | el botón N del menú de comandos |
| Q / Tab | batalla | `cycleTarget`: siguiente enemigo vivo |
| P | batalla, tu turno (v0.8.3) | va a PASAR; con PASAR elegida, `PassCommand` (combat.md § "Pasar turno") |
| Esc | batalla, submenú de poción | volver |
| Esc | batalla, sin submenú | abre / cierra el menú de pausa |

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
- **v0.8.1, chat oculto por defecto** (ajuste JUEGO › CHAT, settings.md
  § 4). Con **OCULTO** el chat se muestra plegado: una píldora
  `CHAT [ENTER]` (clave `chat-pill`) en la misma esquina, con el
  contador `+N` en `gold` (clave `chat-unread`) de los mensajes de
  **otros jugadores** llegados mientras estaba plegado (los de sistema
  no suman: ya van al registro y, los importantes, como aviso; los
  propios tampoco). Enter en el mapa o clic en la píldora lo despliega
  (registro + campo) con el foco en el campo y el contador a 0; Esc,
  Enter con el campo vacío o mandar un mensaje lo vuelven a plegar (el
  foco vuelve al juego). Perder el foco del campo (clic en el mapa)
  también lo pliega. El campo existe siempre (fuera de escena mientras
  está plegado), así que la regla de foco de arriba no cambia.
  - **Avisos del chat** (JUEGO › AVISOS DEL CHAT, SÍ por defecto): con
    el chat plegado, cada línea de sistema **importante** aparece 4 s
    encima de la píldora (claves `chat-toast-N`, máximo 3 a la vez; sin
    animación). Importante = empieza con `¡` (misión aceptada, todos
    listos, piso despejado, objetivos cumplidos, subida de nivel, Eco
    completado, jefe vencido, ascensión, opcional cumplida…), empieza
    con `Misión opcional` (fallida) o termina en `¡Voten!` (propuestas).
    El resto (compras, mejoras, loot, sellos) solo queda en el registro.
  - Con **SIEMPRE VISIBLE** se ve como antes de v0.8.1 (5 líneas +
    campo) y no hay píldora ni avisos.
- **Desvío / pendiente**: en batalla y en el resultado el chat no se
  muestra (la pantalla de batalla ocupa todo); el prototipo lo tiene
  siempre debajo del canvas.

## Resolución virtual y escalado

- El mundo se dibuja a **480 × 288** px virtuales (`VW × VH`) en un
  `PictureRecorder` y se rasteriza (`toImageSync`). Esa imagen se escala
  al tamaño del `GameWidget` con `FilterQuality.none` (vecino más
  cercano), manteniendo la proporción (`min(w/480, h/288)`) y centrada,
  con bandas `#05060c`. Con el ajuste ESCALADO en PIXEL PERFECT el
  factor es el mayor entero que entra (`mapViewRect`, settings.md
  § 3.1). Así el texto del mundo (nombres, `JEFE`) también
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
   `x1 = min(w−1, x0 + VW/TS + 1)` (ídem `y`), con `drawTile`. Desde
   v0.8.3 los estáticos salen de la caché por bloques (ver
   § "Rendimiento"); el resultado es el mismo.
4. Carteles del lobby: `MOSTRADOR DE MISIONES` en `(13·TS, TS+10)`
   `#48dbfb` 7 px y `ARMERÍA` en `(21.5·TS, TS+10)` `#ff9f43` 7 px.
5. Entidades ordenadas por `y` (pies), de arriba hacia abajo:
   - jugadores (`drawHero` + nombre en `y−22`, dorado `#ffd166` el local);
   - en campo / subida de nivel: fragmentos y cofres sin recoger, sellos
     (activos o no);
   - en campo / subida de nivel: enemigos vivos del campo (`drawEnemy`
     con el primer tipo del grupo) con `*ÉLITE` (`y−34`), `!` de aggro
     (`y−22 + sin(t/90)·1.5`, rojo, 9 px) y `JEFE` (`y−48`, 7 px).
   - debajo de todas las entidades, después de los tiles: el **loot del
     piso** (§ "Loot en el piso"); encima de todas: los haces de los
     Legendarios y las etiquetas del loot.
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

### Loot en el piso (loot.md § 4, § 19.6)

`MapGame` dibuja `session.groundFor(local)` (lo suyo + lo compartido) en
lobby, campo y subida de nivel (`map/loot_painter.dart`):
- **Qué**: lo que el filtro del jugador local muestra
  (`engine.lootVerdict`); con **Alt** también lo oculto (a 45 % el ícono,
  50 % la etiqueta).
- **Ícono** (~9×6 px, tirado en diagonal) por tipo de arma (espada, hacha,
  maza, martillo, báculo, tomo, arco, rifle, lanza, dagas, varita,
  ballesta; las de escudo con el escudo al lado) o por pila (poción
  roja/azul, Esquirla celeste, Cristal azul, Prisma triangular con tres
  colores). Debajo, un **brillo** elíptico 16×6 del color de la rareza
  (alfa 0.12 Común … 0.5 Legendario, late `sin(t/260)`); Épicos y
  Legendarios con destello 1×3 cada 900 ms.
- **Etiqueta** encima (centrada, 12 px sobre el objeto): texto del nombre
  (`ItemRules.displayName`; pilas `N Material`) con el color del filtro
  (o el de la rareza), fondo del filtro (o `#000000b3`) y borde del
  filtro (sin borde si no trae); tamaño `round(5 + (Tamaño − 18)/13.5)`
  px virtuales (18 → 5, 32 → 6, 45 → 7). Las etiquetas que se pisan se
  apilan hacia arriba (de abajo hacia arriba por `y`) y no se salen de la
  pantalla por los costados.
- **Haz de luz** de los Legendarios: columna naranja `#ff8c28` de 9×90 px
  con degradé, núcleo crema y motas que suben; los primeros 1.5 s después
  de aparecer, más ancho y alto con un anillo que se cierra. Si un
  Legendario fue directo al inventario (`groundLoot = false`), el haz sale
  del jugador local durante 2.6 s.
- **Levantar**: caminando encima (el host levanta lo propio y visible a
  < 14 px, `SessionEngine.pickupRange`) o con E / Espacio a ≤ 24 px
  (`SessionEngine.pickReach`) sin otro aviso; el HUD muestra
  `[E] Recoger <nombre>`.
- `SessionEngine.groundLoot`: con `false` (hoy) el loot visible va directo
  al inventario y al piso solo cae lo oculto o lo que no entra; la UI
  funciona igual en los dos casos.

## HUD (overlays Flutter sobre el `GameWidget`)

Todo con `RetroPanel` (padding 8) y texto de 8 px (`bodySmall`).

- **Barra de misión** (arriba al centro, `#mission` del prototipo):
  en misión `nombre · objetivos · mm:ss` (o `¡Derrota al jefe!` con la
  barrera abierta); en el lobby
  `Lobby · Mostrador [E] · Armería [E] · Personaje [C]`; en `prep`
  `Preparación de misión`.
- **Objetivos** (arriba a la izquierda, solo campo; `drawObjectives`):
  una línea por objetivo `Etiqueta n/goal` y la línea del jefe
  (`* ¡Ve por el JEFE!` / `Jefe: completa los objetivos`).
  **v0.8.1, plegable y compacta** (`_Objectives` en `hud/world_hud.dart`):
  - Cabecera (desplegada): nombre de la zona/misión (con pisos, `<zona> · Piso N/F ·
    Lv L`, clave `hud-floor`) y a la derecha el botón `[-]` (desplegada)
    / `[+]` (plegada), clave `hud-objectives-toggle`. Clic en la
    cabecera o la tecla **J** (fuera de batalla, sin panel ni campo de
    texto) pliega / despliega.
  - **Plegada**: UNA sola fila: el resumen (clave
    `hud-objectives-summary`; el nombre ya está en la barra de misión) y
    `[+]`, ancho máximo `RetroType.width(context, 520)`, p. ej. `Piso 1/4 · Grupos 4/4 ·
    Opcional 1/2`: piso (si hay pisos), grupos del piso (o el objetivo
    de grupos), el resto de objetivos `Etiqueta n/goal` (primera
    palabra), `Opcional hechas/total` (si el piso tiene opcionales) y
    `★ JEFE` con la barrera abierta.
  - **Desplegada**: las líneas con interlineado apretado (2 px entre
    líneas), ancho máximo `RetroType.width(context, 380)` (crece con el
    tamaño del texto) y texto que se parte en varias líneas en vez de
    estirar la caja. Las misiones opcionales van bajo una sub-cabecera
    `Opcional` (sin repetir el prefijo). Las líneas cumplidas se ven
    atenuadas (`dim`) con la marca `>` en `green`; las pendientes llevan
    `•`; una opcional fallida, `x` en `dim`.
  - El estado se recuerda en `game.json` (`objectivesCollapsed`, por
    defecto `false`: desplegada).
  - Va a `16 + RetroType.width(context, 48)` px del borde de arriba
    (debajo de la barra de misión, que crece con el texto). A 1280×720,
    con cualquier tamaño de texto, no pisa el minimapa (arriba a la
    derecha), la barra de misión, el chat ni las cajas del grupo.
- **Minimapa** (arriba a la derecha, campo y subida de nivel, nunca en
  el lobby; `drawMinimap`): 1 tile = 2.5 px de pantalla (el doble del
  1.25 virtual del prototipo; los puntos también ×2); colores del
  prototipo (`#0b0e1a` muro/barrera, `#2e86de` agua, `#6c7a9c` camino,
  `#4b5878` suelo), barrera roja/verde, enemigos `#ff4757` (élite
  `#ffd166`, más grande), fragmentos `#48dbfb`, sellos `#a29bfe`/`#7bed9f`,
  cofres `#ffd166`, jefe `*` que alterna `#e84393`/`#ffd166` cada 300 ms,
  jugador local blanco y aliados `#48dbfb`. Son colores de arte (como el
  mapa).
  **v0.8.1, zoom** (`Minimap.cell` / `view` / `center`,
  `hudMinimap` en `hud/world_hud.dart`): ajuste `minimapZoom` (1..3,
  por defecto **3**, en `game.json`). Zoom 1 = el piso entero a 2.5 px
  por tile (como antes). Zoom 2 y 3 = 5 y 7.5 px por tile en una ventana
  de 300×210 px (a zoom 3, 40×28 tiles) centrada en el jugador local,
  que se corre al caminar y se recorta a los bordes del piso
  (`Minimap.viewRect`; un piso más chico que la ventana se ve entero).
  Los puntos crecen con la raíz del zoom (no tapan el mapa). Rueda del
  mouse sobre el minimapa o los botones `-` / `+` debajo cambian el zoom
  (se recuerda). Las reglas de qué se ve no cambian: PdI solo
  descubiertos (`minimapPois`, `poiSeen`), cofres de sala secreta solo
  con la sala abierta, reliquia levantada sin punto.
- **Mapa en grande** (v0.8.1, `hud/full_map.dart`, panel
  `WorldPanel.map`): tecla **M** o el botón `MAPA [M]` debajo del
  minimapa, donde hay minimapa (piso de misión o mapa del mundo; no en
  batalla, preparación ni resultado). Panel centrado (`PanelFrame`
  ancho 1100, del tema) `MAPA · <zona> · Piso N/F` (o `Mapa del mundo`)
  con el mismo dibujo que el minimapa, ajustado para que el piso entre
  entero; zoom ×1..×6 (rueda, `+` / `-` con teclado o botones, paso
  ×1.5) y paneo (arrastrar, flechas o WASD, 4 tiles por tecla) siempre
  dentro del piso; `CENTRAR [C]` vuelve al jugador. Leyenda: Tú,
  Aliados, Escalera, Jefe, Cofre, Secreto, Santuario, Piedra de paso,
  Enemigos (cuadros de color de arte que crecen con el texto). Esc, M o
  `CERRAR [M]` lo cierran (Esc no abre la pausa). Como todo panel, el
  jugador local no camina mientras está abierto y en co-op el mundo
  sigue. **Pendiente**: viajar a una piedra de paso con clic desde el
  mapa (no entra en v0.8.1).
- **Grupo** (abajo a la derecha, `#party`): una fila de `.pbox`
  (`PartyBox`, docs/specs/ui_style.md § "Caja de jugador"), una por
  jugador, con los colores de `hud()` (línea 1195): nombre +
  `Clase LvN` en `#9fb4ff`; arma en `#ff9f43` con `+N pts` en `#ffd166`;
  barra `#2ed573` + `HP ceil(hp)/max`; barra `#1e90ff` + `MP
  floor(mp)/max`; `XP n/xpNeed · ₵créditos` en `#7d8bc4`; `Pociones:`
  con `♥n` `#7bed9f` y `✦n` (`♦`) `#74b9ff`. El chat se achica para que
  la fila entre.
  - **Compactas por defecto (v0.8.2)**. Pedido del dueño: "tapa mucho
    eso abajo; pudieran ir compactos y que se puedan abrir si uno quiere
    ver más detalle". Cada miembro (humanos en co-op y compañeros de la
    party) es una caja `CompactPlayerBox` de 200 px base
    (`PartyBox.compactWidthOf`, crece con el texto) y **dos líneas**:
    `Nombre[, Ascensión] Clase` (nombre en `title`, ascensión en su
    color, clase en `sky`; con elipsis) + `LvN` (siempre visible) +
    chips de texto (`K.O.` carmesí, `+N` dorado con puntos sin usar; sin
    caja, para no agrandar la línea) + `[+]`; debajo, barras finas de HP
    y MP lado a lado con `hp/max` y `mp/max` (el número toma a lo sumo
    el 65 % de su mitad: se recorta antes que desbordar). Misma fila
    abajo a la derecha: a 1280×720 Normal, 4 miembros ocupan **50 px**
    de alto en vez de ~200; con texto Muy grande / Enorme pasan a dos
    filas (el chat cede hasta 200 px base en vez de 240, porque es una
    píldora) sin pisar objetivos, minimapa ni chat (test).
  - **Desplegar**: `H` (fuera de batalla, sin panel abierto; no choca
    con `kMenuKeys` ni con las teclas del mapa) o clic en cualquier caja
    despliega **todas** a la caja completa de siempre (arma + pts, XP ·
    ₵, pociones); otra vez `H` / clic las compacta. Se recuerda en
    `game.json` (`partyExpanded`, por defecto `false`).
  - **XP para subir (v0.8.6)**. Pedido del dueño: "¿dónde se ve cuánta
    XP me hace falta para el siguiente nivel?" (antes solo había un
    `XP n/max` gris en la caja desplegada). Texto común en
    `features/characters/domain/xp_text.dart` (`xpProgress`,
    `xpProgressText`): `XP 120/300 · faltan 180` (con `next`: `… para
    el nivel 13`); en el nivel 50 cuenta la Maestría (`para la Maestría
    N`, barra violeta); con la Maestría completa no hay barra.
    - Compacta: barra fina de XP (2 px, dorada) debajo de HP/MP
      (`hud-compact-xp-<id>`); al pasar el mouse, `XP … · faltan … para
      el nivel N`.
    - Desplegada: barra de XP (4 px, `hud-xp-bar-<id>`) y `XP n/max ·
      faltan N · ₵créditos` (`hud-xp-<id>`).
    - Panel PERSONAJE: el encabezado suma `· XP n/max · faltan N` entre
      el nivel y los puntos.
- **Chat** (abajo a la izquierda): ver § "Chat".
- **Menú** (arriba a la izquierda, junto a `< TITULO` en el lobby):
  `≡ MENU [ESC]` abre la pausa / configuración (docs/specs/settings.md);
  reemplaza al botón `SONIDO` de v0.2.0. En batalla el mismo botón va
  arriba a la izquierda de la escena.
- **Pausa de grupo**: con la sala pausada, el cartel centrado
  `<nombre> pausó el juego` + `REANUDAR` (settings.md § 6 "Cartel").
- **Aviso de interacción** (abajo al centro): `[E] Ver misiones`,
  `[E] Armería`, `[E] Activar sello`, `[E] Tienda y herrería`.
- **Barrera abierta**: `La barrera se abrió > busca al JEFE (* en el
  minimapa)` mientras el jugador está a más de 140 px del jefe.
- **Votación** (arriba al centro, en el lobby): `VotePanel`, ver
  docs/specs/panels.md § "Votación".
- **Subida de nivel**: `¡SUBIDA DE NIVEL!` + `Esperando a: nombres`.
- **Registro de loot** (encima del chat, `hud/loot_feed.dart`): las
  últimas 4 líneas `Ana encontró: <objeto>` (prefijo gris, objeto en el
  color de su rareza; materiales `#78e6dc`), de cualquier jugador, solo
  lo que el filtro de ESE jugador muestra; `A le dio a B: <objeto>` al
  dar. Cada línea dura 14 s y se desvanece el último.
- **Avisos de loot** (abajo al centro, encima del aviso de `[E]`): lo que
  el jugador local levanta (`+ <objeto>`), lo que le entra directo al
  inventario, lo que le dan (`Te dio Ana:`) y cada Legendario propio
  (`¡LEGENDARIO!` en naranja, borde naranja de 3 px, 5 s). Estilo del
  filtro: fondo (o `#000000cc`), borde, color del texto (o el de la
  rareza) y tamaño `round(6 + Tamaño/6)` px de pantalla (18 → 9, 45 →
  14). Duran 3 s, 3 a la vez como máximo. El registro vive mientras la
  pantalla del juego vive (también en batalla: el loot de una pelea llega
  con su fin).
- **Minimapa**: además, el ícono del filtro (`Icono forma color`) de cada
  objeto visible del piso (círculo, cuadrado, triángulo, diamante o
  estrella de 6 px con contorno negro; blanco `#ffffff`, rojo `#ff4757`,
  verde `#7bed9f`, azul `#4b7bec`, amarillo `#ffd166`, naranja
  `#ff8c28`, violeta `#be6eff`, celeste `#48dbfb`).

## Mundo y pisos (v0.2.0, worldgen.md § 7)

Implementación: `map/tile_painter.dart` + `map/map_themes.dart` (tiles y
temas), `map/map_game.dart` (carteles de entradas, cámara por piso,
fundido), `hud/minimap.dart`, `hud/world_hud.dart`,
`session_controller.dart` (avisos y E), `world_text.dart` (textos).
Tests: `test/features/world/world_ui_test.dart`.

### Tiles nuevos

Mismo estilo que `drawTile` (rects enteros, hash por tile, sin
antialias). Colores = arte (`map_themes.dart`).

| Char | Dibujo |
|---|---|
| `g` | pasto `#4fa046` con matas `#67b85a` (`h%3`), punto 2×2 (`h%5`) y flor amarilla/rosa (`h%17`); sin damero |
| `T` | pasto + árbol redondo (tronco `#4a2f1a`, copa `#1f5f2a` r8, brillo `#2f7d37` r4) |
| `^` | pasto + montaña triangular gris (`rock`/`rock2`, la mitad izquierda más clara) con nieve `#e8f0ff` arriba |
| `1`..`9`, `0` | pasto + base de piedra; encima de los tiles `MapGame` dibuja el **arco** (`TilePainter.entrance`, 32×40 px con la base en el borde de abajo del tile): escalón, dos pilares `#8a8e9a`/`#44474f` con juntas, dintel con piedra clave del color de la zona; abierta: portal del color de la zona que late (`0.55 + 0.25·sin(t/220 + z)`) con chispas que suben; bloqueada o "Próximamente": interior `#1c1e25` con candado gris |
| `>` | suelo + agujero `#07070c` con borde `w2` y 3 peldaños que se oscurecen hacia abajo |
| `<` | suelo + 4 peldaños claros (`#dde0e8` → `#8a8e9a`) con barandas `w2` |
| `:` | suelo + borde dorado tenue `#ffd16640` arriba e izquierda (grilla de baldosas) y un punto dorado (`h%7`) |

Un código desconocido se pinta magenta (`TilePainter.handles` lista los
conocidos; el test recorre el mundo y los atlas de las zonas 1–5).

Temas nuevos (`g/g2/w/w2/path/p2/wat`):

| Tema | g | g2 | w | w2 | path | p2 | wat | `#` |
|---|---|---|---|---|---|---|---|---|
| mundo | #4fa046 | #67b85a | #1f5f2a | #2f7d37 | #c2a266 | #a88b52 | #2e86de | árbol |
| bosque | #2a5a2c | #356e36 | #113a1c | #1d5a2a | #6e5a3a | #5c4a2e | #1e5f74 | pino o copa (por hash) sobre `#0e2a14` |
| cavernas | #4a5a70 | #5b6e86 | #26304a | #9fdcf5 | #6e8299 | #5e7188 | #3fc4e6 | roca con facetas y cristal de hielo (`h%3`); agua con placas de hielo |
| fortaleza | #3a3642 | #47424f | #221e2a | #55505f | #5f5967 | #4c4755 | #2a4a6a | ladrillo con juntas desfasadas, musgo (`h%9`), grieta (`h%7`) |

En el tema `mundo` el pueblo (tiles `0..25 × 0..13`) se dibuja con el
tema y el estilo del `lobby` (damero, ventanas, mostrador, armería); el
resto al aire libre (`lobby = false`).

### Mapa del mundo

- **Carteles de entrada** (en el mundo, encima de las entidades): nombre
  de la zona (7 px) con la línea base a 47 px sobre el centro de la
  entrada y `Lv a-b` (6 px, a 38 px); abierta en el color de la zona, bloqueada en gris
  `#9aa0ac` con `PRÓXIMAMENTE` o `BLOQUEADA` (6 px) encima. El estado
  sale de `ZoneRules.zoneList(catalog, perfil local)`.
- **Aviso** (abajo al centro) a < `WorldRules.entranceRange` de una
  entrada:
  - abierta: `[E] Entrar: <zona> (Lv a-b)`; si hay una votación por esa
    misión y el jugador no votó: `[E] Votar SÍ: <zona>`; si hay otra
    votación: `<zona> · Ya hay una votación`;
  - bloqueada: `<zona> · Lv a-b · Bloqueada: vencé a <jefe> en <zona>`;
  - próximamente: `<zona> · Lv a-b · Próximamente`.
- **E en una entrada abierta** propone la misión de la zona
  (`ProposeMissionAction`) o vota que sí si ya hay votación por ella; lo
  demás es la votación y preparación de siempre. **Decisión de UX**: se
  propone directo (no se abre el mostrador filtrado) porque la entrada ya
  es la elección de zona y la votación que aparece arriba es la
  confirmación (se puede cancelar con N). El mostrador sigue en el pueblo
  con todas las zonas.
- **Barra de misión** en el mundo: `Lobby · Mostrador [E] · Armería [E]
  · Zonas: puertas [E] · Personaje [C]`.
- **Minimapa** también en el mundo (antes nunca en el lobby): tiles
  (pasto como suelo, árbol/roca como muro), el pueblo en su color de
  suelo, las entradas como cuadros de 3 tiles del color de la zona (gris
  si está bloqueada) y los jugadores.

### Pisos de una zona

- **Cámara**: se limita al `bounds` del piso actual
  (`session.mission!.floor`), no al atlas entero; el minimapa también se
  recorta a ese rectángulo. Se dibujan solo los enemigos y objetos de ese
  piso (`FieldEnemy.floor`, `MissionItem.floor`).
- **Escaleras** a < `WorldRules.stairsRange`: aviso `[E] Bajar al piso
  N` / `[E] Subir al piso N` (N desde 1). E manda
  `UseStairsAction(down: true/false)`. Pisar `>` también baja (host).
- **Fundido**: con `FloorChangedEvent` el mapa se cubre de negro y se
  aclara en 700 ms (`MapGame.fadeMs`) con el cartel `<zona> · Piso N/F`
  centrado (8 px dorado). La cámara salta al piso nuevo.
- **HUD**: arriba de los objetivos, `<zona> · Piso N/F` (dorado) y
  `Lv L` del piso; en el último piso `¡Piso del JEFE!` en rojo. Objetivos
  del piso: `Grupos del piso k/cuota` y, en pisos con escalera,
  `Escalera: despejá el piso` / `> Escalera abierta: bajá [E]`; en el
  último piso la línea del jefe de siempre. Los objetivos de la misión
  (fragmentos, sellos, élite) siguen debajo.
- **Barra de misión** en una zona: `<zona> · Piso N/F · objetivos ·
  mm:ss`.
- El aviso de barrera abierta (`busca al JEFE`) solo en el último piso;
  en los demás: `La escalera se abrió → bajá al piso N` mientras el
  jugador está a más de 140 px de la `>`.

## Zonas 6–10 (v0.3.0, worldgen.md § 8 y § 9)

Implementación: `map/tile_painter.dart` (tiles y vecinos),
`map/void_painter.dart` (fondo del vacío), `map/map_themes.dart`,
`map/map_game.dart` (caída), `hud/minimap.dart`. Tests:
`test/features/world/world_v03_ui_test.dart`.

### Temas nuevos

| Tema | g | g2 | w | w2 | path | p2 | `#` |
|---|---|---|---|---|---|---|---|
| laberinto | #3b4a63 | #46577a | #222c3f | #b08a3a | #56647e | #4a5770 | sillar pizarra con remaches y ribete de bronce |
| grieta | #2f2a2c | #3d3537 | #1a1618 | #ff7b29 | #4a3e3a | #3e3431 | columna de basalto con grietas que brillan (`0.5 + 0.35·sin`) |
| cementerio | #5a5d5a | #6c706a | #2e2c35 | #7e8a5a | #6e6a5e | #5e5a50 | roca flotante gris |
| abismo | #4a5372 | #5a6488 | #262b40 | #8a96c0 | #5e6890 | #50597c | roca flotante azul |
| corazon | #d9c58a | #efe2b0 | #6b5a2a | #fff3c4 | #c9b06a | #b89c56 | cristal dorado con brillo |

Suelos: laberinto losas con junta y marca de engranaje (`h%11`);
grieta ceniza con brasas que laten (`h%7`); cementerio tierra gris con
pasto seco y musgo (`h%5`, `h%9`) y **niebla** (bandas `#ffffff`
α ≤ 0.10 que derivan en x con `sin(t/1800 + ty·0.7)`); abismo roca con
vetas; corazón cristal con faceta diagonal clara (`h%4==1`), reloj
tallado dorado (aro de 7 px con dos agujas, `h%10`) y destello.

### Tiles nuevos (v0.3)

`TilePainter.draw` recibe además `at(tx, ty)` (tile vecino; `null` =
fuera del mapa) para bordes y orientación. Sin vecinos se dibuja igual.

| Char | Dibujo |
|---|---|
| `_` vacío | fondo del vacío (abajo) + **canto de la isla**: si el tile de arriba no es vacío, roca que cuelga 4–8 px (por hash, borde dentado de a 2 px) en el tono `w` con una franja `rock` de 3 px arriba, línea `g2` de 1 px y sombra `#00000066` de 4 px debajo; bajo un puente, una viga de 2 px; si a izquierda/derecha hay isla, sombra lateral de 2 px |
| `=` puente | abismo/cementerio: tablones de madera `#8a6a3a`/`#6e5230` con juntas y **barandas de cuerda** `#c8a86a` con postes en el lado que da al vacío/lava; corazón: losas de piedra rúnica `#cfc6a8` con runa `#ffd166` que late; grieta: basalto enfriado `#3a3436` con vetas naranjas tenues. La dirección sale de los vecinos: vacío/lava arriba o abajo → puente horizontal (tablones verticales); a los lados → vertical |
| `%` lava | base `#c0391b`, corriente `#ff6b1f` (bandas que se desplazan con `t/180`), brillo `#ffd166` que late; **burbujas** que crecen y revientan, en los tiles con `h%3==0` (ALTA), `h%5==0` (MEDIA) o `h%9==0` (BAJA); borde de costra oscura `#4a1a10` contra suelo |
| `t` lápida | suelo + sombra + lápida gris `#8a8e96`/`#5e626a` de tapa redonda con cruz o `RIP` (por hash) y musgo `#6b8a4a` |
| `o` engranaje | suelo + engranaje de bronce `#b08a3a`/`#7a5a22` de 8 dientes que gira lento (`t/1600` rad; 4 en zigzag por paridad de tx+ty) con eje oscuro |
| `#` en abismo/cementerio/corazón | pilar de roca flotante (o cristal en corazón) sobre el vacío con su canto |

Los bordes de isla en los tiles caminables (suelo/camino/vault junto al
vacío) llevan un reborde claro de 1 px y pixeles desmoronados (por hash)
del lado del vacío: así las islas se ven flotando.

### Fondo del vacío (`VoidPainter`)

Si el piso tiene vacío, `MapGame` pinta antes de los tiles un fondo en
pantalla (no por tile): degradado vertical por tema (abismo `#04061a →
#0c1838`, cementerio `#0a0614 → #22123a`, corazón `#0a0818 → #2a1c3a`),
estrellas por hash en una grilla de 24 px con **paralaje** 0.35 de la
cámara y titileo `sin(t/400 + h)`, y motas de tiempo que derivan
(`scaledCount(14, PARTÍCULAS)`). Los tiles `_` sobre ese fondo solo
dibujan el canto. Sin fondo (tests), el `_` pinta el degradado plano y 1
estrella por hash.

### Caída al vacío

- Con `FellIntoVoidEvent(id, floor)` el mapa anima la caída de **ese**
  jugador: 450 ms en el lugar donde estaba (el sprite se achica a 0.2 y
  se desvanece, con un remolino de motas) y después 450 ms de aparición
  en el punto de llegada (`MapFloor.spawn`: anillo dorado que se cierra
  y el sprite que pasa de α 0 a 1). `MapGame.fallMs = 900`.
- Mientras el jugador local se achica, la cámara se queda en el lugar de
  la caída; después salta a la llegada.
- Jugador local: además, el cartel `¡Caíste al vacío!` (8 px, `#a29bfe`)
  sobre el mapa durante la animación; la línea del registro es el mensaje
  de sistema `<nombre> cayó al vacío.` del host (en el chat de todos).
- Los demás jugadores ven el mensaje de sistema en el chat y la misma
  animación sobre ese héroe.

### Minimapa (v0.3)

Vacío `#05060c` (como el fondo), puente `#a07a44`, lava `#ff5a1f`,
lápida `#6c707a`, engranaje `#b08a3a` (`minimapTileColor`).

### Exploración (v0.6, worldgen.md § 11)

Tiles nuevos (todos sólidos; `TilePainter`, procedurales como el resto
de los tiles: no son sprites del manifiesto):

| Char | Constante | Cómo se ve |
|---|---|---|
| `K` | `Tile.cracked` | el muro del tema con grietas en zigzag y un halo violeta que late |
| `k` | `Tile.secretFloor` | el muro del tema (sala secreta sin abrir; abierta pasa a `:`) |
| `J` | `Tile.shortcut` | muro con reja de hierro y palanca roja (abierto: `,`) |
| `H` / `h` | `Tile.shrine` / `shrineUsed` | pedestal con cristal turquesa que flota y brilla / apagado gris |
| `W` / `w` | `Tile.waystone` / `waystoneOn` | menhir con runa apagada / runa dorada que late y halo |
| `V` | `Tile.wind` | arco bajo con remolinos celestes |
| `B` / `b` | `Tile.brazier` / `brazierLit` | brasero de piedra / con llama animada |

- **Cofres** (`ActorPainter.item`): madera (marrón, como antes), reforzado
  (azul acero con banda plateada) y dorado (oro con halo que late). Con el
  guardián vivo: candado, sin destello ni rebote. El de una sala secreta no
  se dibuja hasta abrirla.
- **Reliquia** (`ActorPainter.relic`): rombo ámbar que flota con halo.
- **Cartel de E** (`WorldPrompt.poi`, texto en `promptText`): `[E] Romper
  la pared agrietada`, `[E] Abrir el atajo`, `[E] Santuario: <bendición>
  (<efecto>)`, `[E] Activar la piedra de paso` / `[E] Viajar a la piedra
  2/3`, `[E] Viento del Eco: +40% velocidad 60 s`, `[E] Encender el
  brasero`. Prioridad: sello > PdI > escalera.
- **Cartel de misión opcional cumplida**: `¡Misión opcional cumplida!` +
  el texto de la misión, arriba al centro, 2.8 s (`MapGame.questToastMs`),
  con la fanfarria.
- **Caja de objetivos**: `Cofres a/b · Secretos c/d`, `♦ <bendición>`,
  `» Viento del Eco N s` y `• Opcional: <misión> a/b` (cumplida `>` en
  verde, fallida `x` en gris).
- **Minimapa**: § 11.7 de worldgen.md (los PdI no se ven hasta
  descubrirlos).
- **Movimiento**: con el Viento del Eco activo el jugador local camina
  ×1.4 (`LocalPlayer.step(speedMult:)`).

### Mapa del mundo

Las entradas 6–10 usan el mismo arco; el estado (abierta / bloqueada)
sale de `ZoneRules.zoneList` como en la v0.2 (ya no hay
"Próximamente").

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
- `BattleView` dibuja la escena en una **arena temática propia** (v0.5,
  pedido del dueño: ya no sobre el mapa), elegida por zona, Eco / Prueba
  y tipo de encuentro (normal, élite, jefe), con el grupo a la derecha y
  los enemigos a la izquierda, animaciones, efectos, cinemáticas de
  ultimate y la franja de turnos: todo en
  docs/specs/battle_presentation.md § "Arenas". `SessionBattleScreen` le
  pasa `BattleArena.stage` (tipo de encuentro + un callback que dibuja la
  arena con `ArenaPainter`), `battleEvents`, `battleEventSeq` y el id de
  la batalla. Al entrar y al volver al mapa hay un fundido de bloques de
  420 ms.
- El menú aparece solo si `battle.waitingForPlayer` y el turno es del
  jugador local; cada opción manda `BattleAction(cmd)` con el objetivo
  actual (`tgt` del prototipo: primer enemigo vivo si el elegido cayó;
  Q/Tab o clic sobre el enemigo en la escena lo cambian).
- **Barra de batalla** (pedido del dueño; reemplaza el `#menu`
  flotante y la fila de `.pbox` del prototipo): una barra fija abajo,
  de alto `clamp(alto × 0.42, 200, 300)` px (302 px con 720 de alto), que **nunca tapa la escena**:
  la escena y la franja de turnos usan solo el alto que queda arriba
  (docs/specs/battle_presentation.md § "Geometría"). Tres paneles
  (`#121936`, borde 2 px), separados 6 px:

  ```
  ┌ MIS DATOS ──────┬ ACCIONES ───────────────┬ GRUPO ──────────────┐
  │ nombre Clase Lv │ ¡Tu turno! · Objetivo   │ [sprite] nombre ▶   │
  │ arma +pts       │ 1. Atacar   2. Técnica  │ HP ▬▬ n/m  MP ▬▬ n/m│
  │ HP/MP/ULT barras│ ★ ULT / dúos (fila)     │ chips de estado     │
  │ ATQ MAG DEF     │ 5. Poción…  6. Defender │ (una fila por cada  │
  │ Crít · VEL      │ (fuera de turno:        │  OTRO jugador)      │
  │ chips · turno   │  "Turno de X")          │                     │
  └─────────────────┴─────────────────────────┴─────────────────────┘
  ```

  - **Mis datos** (izq., ancho `clamp(ancho × 0.21, 250, 360)`, borde
    `#ffd166`): **solo el jugador de este dispositivo** (`localId` de la
    sesión; sin `localId` —tests, previsualización— el de turno si puede
    actuar, si no el primero del grupo). Nombre y `Clase LvN`, arma
    `#ff9f43` (+`+N pts` dorado), barras HP / MP / ULT con `n/m` a la
    derecha (ULT `#a29bfe`, `#e84393` + `¡LISTA!`), `ATQ · MAG · DEF` y
    `Crít n% (×m) · VEL x.x` en `#9fb4ff`, los chips de estado y
    buffs/debuffs con nombre completo, y el turno: `▶ TU TURNO  Ns`
    (dorado; el tiempo en `#ff4757` con ≤ 10 s), `Turno en N`
    (`#7d8bc4`, índice en `predictTurns`) o `Fuera de combate`. A 50% de
    opacidad si está K.O.
  - **Acciones** (centro, el resto del ancho, borde `#ffd166` en mi
    turno): el menú del prototipo (`#menu`, líneas 1205-1223) solo si
    `battle.waitingForPlayer` y el turno es del jugador local. Cabecera
    `<b>` dorada `¡Tu turno! (nombre) · Objetivo: <enemigo>` + `Q/Tab
    cambia` en `#9fb4ff`, o la pregunta del submenú de pociones; botones
    numerados en una grilla pareja de 2 columnas (3 si el panel mide
    ≥ 840 px; cada fila toma el alto de su botón más alto). `.dual` (ULT
    y dúos) conserva borde `#ff9f1c` y texto `#ffd166` pero ocupa una
    celda, no la fila entera: en la barra no hay lugar. Los dúos dicen
    `★ Nombre (+aliado) N c/u (crít M) +nX 4MP c/u`; "aliado pierde su
    próximo turno" y la fórmula van a su `#tip`. Con los textos coloreados del
    prototipo: daño estimado `#ffd166` y `(crít N)` `#7d8bc4`, estado
    `+N` + letra en su color, `+X% crít` `#ff6b81`, MP `#74b9ff`, curas
    `#7bed9f`, etc. Orden: `Atacar`, `★ ULTIMATE` (deshabilitada < 100%),
    técnicas (deshabilitadas sin MP), dúos, `Poción de vida xN ▸ elegir a
    quién`, `Poción de maná xN ▸ ...` (submenú `¿A quién le das ...?` con
    HP/MP en `#9fb4ff` y `+N` verde/celeste) y `Defender`. Al pasar el
    mouse, el `#tip` (`RetroTooltip`) con `descSkill` en markup. Si no
    hay lugar, el panel se desplaza (scroll) en vez de desbordar.
    **Más de 9 opciones** (teclas 1-9; p. ej. Guardián con 3 habilidades
    de arma, 2 trasladadas y su kit = 13, más dúos en grupo): el menú se
    pagina (`battleMenuPage`). La página 1 siempre tiene `Atacar`, los
    `Liberar`, la ULT, las pociones y `Defender`; las técnicas y dúos que
    entran, y en el lugar 9 − (pociones + Defender) `Más ▸ +N`. Las
    páginas siguientes muestran el resto (hasta 8, o 7 + `Más ▸`) y
    `← Volver` al final. `Esc` (o usar cualquier acción, o un turno
    nuevo) vuelve a la página 1. Nunca hay más de 9 botones numerados. Fuera
    de mi turno, en vez de botones: `Turno de <nombre>` (dorado; `Turno
    de <enemigo>` en `#ff6b81`) y `Tu turno en N` / `Estás fuera de
    combate` en `#7d8bc4`.
  - **Grupo** (der., ancho `clamp(ancho × 0.25, 270, 400)`): una fila
    compacta por cada **otro** jugador (el local no se repite): su sprite
    `idle` ×2 (`PixelSprite`, vecino más cercano) como avatar, nombre y
    `Clase LvN`, a la derecha `▶ SU TURNO` (dorado, y la fila con borde
    dorado) o `Turno en N`; barras HP y MP lado a lado con `n/m`; y los
    chips con letra + stacks. K.O. al 50%. En solitario: `Solo` en
    `#7d8bc4`.
  - **Chips** (`combatantChips`, caja con borde 1 px y texto del color):
    estados `Quemadura/Veneno/Congelación/Aturdido/Sagrado/Regeneración`
    con stacks en su color (`STATUS[k].col`); buffs/debuffs derivados del
    `Combatant`: `Defiende` (`defending`, `#74b9ff`), `Protege`
    (`protecting`, `#ffeaa7`), `Provoca N` (`taunt`, `#ff7675`), `▲DEF +N`
    (`bonusDefense` de Fortaleza / Baluarte, `#74b9ff`), `▼VEL −N%`
    (12% por stack de Congelación, `#74b9ff`) y `K.O.` (`#ff4757`). Al
    pasar el mouse, `RetroTooltip` con el nombre y la descripción
    (`statusDescriptionOf` / textos de `skill_text.dart`).
- Tiempo de turno: `30 − turnTime` s (`TURN_LIMIT`), en la franja.

## Persistencia

`ProfileStore` (contrato en `game_engine/models/profile_store.dart`):
- **Desde v0.3** la app registra `SelectedCharacterProfileStore`: lee y
  escribe el personaje elegido de la cuenta `account.json` (varios
  personajes + alijo, escritura atómica, migración desde `profile.json`
  y manejo de archivo corrupto: docs/specs/characters.md § 1).
- `JsonFileProfileStore` (formato de antes, hoy solo se lee para migrar):
  `profile.json` (`PlayerProfile.toJson`) en la
  carpeta de datos del usuario sin paquetes nuevos (`dart:io`):
  `%APPDATA%\EcosDelTiempo` en Windows,
  `~/Library/Application Support/EcosDelTiempo` en macOS,
  `$XDG_DATA_HOME` o `~/.local/share/ecos_del_tiempo` en Linux.
  Escritura atómica (archivo temporal + `rename`). Un JSON corrupto se
  trata como "sin perfil".
- En otras plataformas (Android, iOS, web) `InMemoryProfileStore`
  hasta que se agregue `path_provider`/`shared_preferences` como
  dependencia directa.

## Rendimiento (v0.8.3)

Caso reportado: 60 FPS quieto, ~40 caminando y ~30 al entrar a una parte
del mapa que no estaba en pantalla, con o sin CRT. Causas y arreglos
(sin cambiar lo que se ve):

- **Tiles dibujados uno por uno en cada cuadro.** ~600 tiles a la vista,
  cada uno de 3 a 20 rectángulos, y los muros de bosque, las rocas, los
  árboles y los cristales son `Path`s / círculos que el motor tesela de
  nuevo en cada cuadro (por eso las zonas con mucho bosque o montaña
  caían más). **`TileLayerCache`** (`map/tile_cache.dart`):
  - Los tiles **estáticos** (`TilePainter.animated` = `false`) se graban
    una vez en **bloques de 16×16 tiles** (256 px) con `toImageSync`; en
    cada cuadro se dibujan 2–6 imágenes. LRU de 64 bloques (~16 MB).
  - Los **animados** (agua, lava, barrera, portal, estatua, púas, Pulso,
    engranajes, PdI, brasas de la grieta, destellos del corazón, puentes
    de grieta / corazón, vacío sin fondo, todo lo del cementerio por la
    niebla) se repintan encima en cada cuadro: el tramo de la fila (celda
    + lo que sobresale, `TilePainter.overflow`) se borra en una capa
    propia (`saveLayer` + `BlendMode.clear`) y se vuelve a pintar con
    **todos** los tiles que lo tocan, en el orden de siempre. Fuera de
    esos tramos solo hay estáticos: el resultado es idéntico al dibujo
    directo (salvo algún píxel del borde de un círculo sin suavizado,
    que ya cambiaba al mover la cámara).
  - Con más de **40 %** de animados a la vista (un mar de lava, el
    cementerio) dibuja directo como antes.
  - Un PdI que cambia el mapa (sala abierta, brasero encendido) solo tira
    los bloques que tocan el tile cambiado (y sus vecinos: bordes,
    orillas, puentes). Otro mapa (otra zona) empieza de cero.
  - **Sin tirones al caminar**: en cada `update` se graba de antemano UN
    bloque que falte a un bloque de distancia de la vista, así al llegar
    a una zona nueva ya está listo.
  - Lo que sobresale cada tile (las motas del suelo usan el `%` con signo
    de JS: hasta 12 px a la izquierda y arriba; portal 14, estatua 20) y
    qué es estático lo verifica `tile_cache_test.dart` dibujando cada
    tile × tema con relojes y estados distintos.
- **HUD reconstruido entero 20 veces por segundo.** El controlador emite
  una `SessionView` nueva en cada tick (cambia el reloj) y `WorldHud` se
  armaba completo (cajas del grupo, chat, botones, avisos: ~370 widgets
  por tick). Ahora:
  - **`Memo`** (`app/widgets/memo.dart`) devuelve el MISMO widget mientras
    sus `deps` no cambien (y se rearma si cambia algo heredado o se
    reensambla la app). Cada caja del grupo depende solo de lo que
    muestra (HP, MP, nivel, puntos...), el chat de sus líneas, la barra de
    misión de su texto, los botones de arriba del modo / puntos sin usar,
    los avisos de sus datos; los `Consumer` de adentro siguen escuchando
    sus providers.
  - `SessionController` reutiliza las listas de la vista anterior
    (`messages`, `chat`, `missionLoot`, `companions`, `auto`) si no
    cambiaron, para poder compararlas por identidad.
  - Resultado: ~123 → ~28 reconstrucciones por cuadro en promedio (el
    minimapa, los objetivos y los avisos de una línea sí siguen al
    jugador).
- **Etiquetas del mapa** (`PixelLabelPen`): ya guardaba los párrafos
  medidos por (texto, color, tamaño en pantalla); al pasar de 300 los
  tiraba TODOS (un aviso que se desvanece crea un color por cuadro) y
  había que volver a medir cada nombre y cartel. Ahora es un LRU.
- **Markup del HUD** (`protoSpan`): se guarda el `TextSpan` interpretado
  (LRU de 256) por markup, estilo, color de `<b>` y tema / colores del
  texto / modo daltónico (cambiar cualquiera no reutiliza lo anterior).
- **CRT y limitador**: el CRT no era la causa (el dueño probó con NORMAL
  y APAGADO). El tope por defecto es 60 (`FpsLimit.fps60`) y con un
  monitor de 60 Hz el limitador no saltea cuadros (el tope ≥ 95 % de la
  frecuencia medida no limita).

**Medir.** `flutter test test/perf/overworld_perf_test.dart` arma la
`WorldScreen` real dentro de `EcosApp` (ajustes por defecto: ALTO
CONTRASTE, CRT FUERTE, partículas ALTAS), party de 4 en la zona 1 con
loot en el piso, e imprime para quieto y caminando, sin y con caché:
percentiles del `render` del mapa, del cuadro entero (`pump`) y
reconstrucciones por cuadro (CPU en modo JIT: sirve para comparar, no
como número absoluto). El mismo archivo comprueba que el HUD no
reconstruye las cajas, el chat ni los botones en ticks sin cambios.

**En el juego real**: con **FPS Y PING** prendido, cada 10 s se escribe
en `ecos.log` una línea `Rendimiento: N cuadros (X fps) · build p50 …
· raster p50 … · total … · mapa: tiles en caché (B bloques, G grabados)
· etiquetas …` (`PerfLog`, `core/perf/perf_log.dart`). `build` es el hilo
de la UI (Dart), `raster` la GPU.

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


## Party jugando solo (v0.8.1, solo_party.md)

- HUD del pueblo (solo, sin votación): botón `PARTY (N) [P]`; la tecla
  **P** abre / cierra el panel PARTY (`WorldPanel.party`): agregar o sacar
  compañeros y su AUTO. Se cierra solo fuera del pueblo.
- Mapa: solo el líder camina; los compañeros lo siguen en fila por su
  rastro (18 px de camino entre cada uno; el host los mueve). Se dibujan
  como los demás jugadores.
- Interacciones (E, objetos, cofres, escaleras, PdI) son del líder; un
  enemigo que choca a un compañero sí arranca la batalla.
- Preparación: los compañeros figuran como listos.
