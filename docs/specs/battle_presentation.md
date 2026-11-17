# Spec: Presentación de la batalla (escena, efectos, timeline)

Fuente de verdad: prototipo `ecos-del-tiempo.html`:
- posiciones de batalla: `startBattle` (líneas 696-708);
- `addFx` en la lógica de batalla (709-871): `num`, `txt`, `slash`,
  `proj`, `ring`, `aura`, `flash`, `poof`, `act`, `ult`;
- dibujo: `drawHero` / `drawEnemy` (989-1017), `render` (1019-1091,
  partes de batalla);
- HUD de batalla: `predictTurns` (1095-1103), `stDesc` / `descSkill`
  (1108-1121), `drawBadges` (1155-1161), `drawTurnLabel` (1162),
  `drawTimeline` (1164-1184);
- efectos: `ELFX`, `burst`, `ultWorld`, `ultScreen`, `drawParts`,
  `fxVisual`, `onNewFx` (1396-1470).

Las reglas (daño, turnos, estados) son de docs/specs/combat.md; el ritmo
(pausas) de docs/specs/missions.md § "Batalla en la sesión". Esta capa
**solo dibuja**: nunca cambia el estado ni frena a la sesión.

Implementación Dart:

| Pieza | Archivo |
|---|---|
| Pantalla de batalla (escena, log, barra, menú, overlays) | `lib/features/combat/presentation/battle_screen.dart` (`BattleView`) |
| Barra: mis datos, lista del grupo, chips de estado | `lib/features/combat/presentation/battle_hud.dart` |
| Escena (ticker + pintor) | `lib/features/combat/presentation/scene/battle_scene.dart` |
| Dibujo de actores, efectos, cinemática y timeline | `lib/features/combat/presentation/scene/battle_painter.dart` |
| Geometría, posiciones y cámara | `lib/features/combat/presentation/scene/battle_layout.dart` |
| Guiones de las ULT y cámara de la cinemática (puro) | `lib/features/combat/presentation/scene/ult_cinematic.dart` |
| Disparos y dibujo del mundo de cada ULT | `lib/features/combat/presentation/scene/ult_fx.dart` |
| Ubicación de etiquetas sin superposición (puro) | `lib/features/combat/presentation/scene/battle_labels.dart` |
| Eventos → efectos (puro) | `lib/features/combat/presentation/scene/battle_fx.dart` |
| Partículas, sacudida, destello rojo | `lib/features/combat/presentation/scene/particles.dart` |
| Colores, elementos, `ELFX`, letras de estado | `lib/features/combat/presentation/scene/fx_style.dart` |
| Textos de ayuda (`descSkill` / `stDesc`) | `lib/features/combat/presentation/skill_info.dart` |
| Disparadores del árbol: tiempos, nombres y colores (puro) | `lib/features/combat/presentation/scene/proc_fx.dart` |
| Predicción de turnos (`predictTurns`, puro) | `lib/features/combat/domain/turn_order.dart` |
| Mapa de fondo de la sesión | `lib/features/world/presentation/session_battle_screen.dart` |

Tests: `test/features/combat/battle_fx_test.dart`,
`test/features/combat/proc_fx_test.dart`,
`test/features/combat/ult_cinematic_test.dart`,
`test/features/combat/battle_framing_test.dart`,
`test/features/combat/turn_order_test.dart`,
`test/features/combat/battle_screen_test.dart`,
`test/game_engine/battle_engine_test.dart` (eventos `ActionEvent`).

## Arquitectura: `CustomPainter` + `Ticker` (no Flame)

La escena es un widget Flutter (`BattleScene`) con un `Ticker` que avanza
un reloj en ms y un `CustomPainter` que dibuja en un lienzo virtual y lo
escala con vecino más cercano — exactamente lo que ya hace `MapGame`
(que es un `Game` de Flame sin componentes: solo `render(Canvas)`).
Motivos para no usar un segundo `GameWidget`:
- el menú, el log y el grupo son widgets Flutter que tienen que quedar
  encima y responder al teclado de `WorldScreen`; con un `CustomPaint`
  dentro del mismo árbol no hay foco ni overlays de Flame que coordinar;
- los tests de widgets avanzan el reloj con `tester.pump(duración)` y
  leen el estado de la escena sin el ciclo de vida asíncrono de Flame
  (`onLoad`, `GameWidget` montando un `Game`);
- no hay componentes ni colisiones: todo es dibujo inmediato como en el
  prototipo (un `ctx` y un bucle).

Los efectos son **datos** (`BattleFx`, el objeto de `addFx`) que produce
una función pura a partir de los `BattleEvent` del motor; la escena solo
les pone hora de inicio y los dibuja según su edad.

## Geometría

- Lienzo virtual: franja de turnos `480 × 54` arriba (el `<canvas id=tl>`
  del prototipo) + escena de `288` px de alto (`VH`). Escala
  `s = min(ancho / 480, alto / 342)`; el ancho virtual se estira a
  `floor(ancho / s)` (≥ 480) y el alto de la escena a
  `floor(alto / s) − 54` para llenar la pantalla (el prototipo deja
  barras negras). Todo se dibuja en píxeles enteros del lienzo virtual,
  que se rasteriza y se escala con `FilterQuality.none`.
- La escena ocupa solo el área **encima de la barra de batalla** (alto
  `clamp(alto × 0.42, 200, 300)`, docs/specs/exploration.md § "Batalla"):
  `ancho × (alto − barra)`. La barra nunca se superpone a la escena ni a
  la franja; con 1280×720 la escena queda en 1280×418 (`s ≈ 1.22`, ancho
  virtual ≈ 1047); con 1920×1080, 1920×780 (`s ≈ 2.28`).
- El log usa esa misma escala para ubicarse: va en la banda
  `y ∈ [38, 54)` de la franja.
- **Solo la franja** usa ese lienzo virtual. Debajo de ella, el **área
  del mundo** (`ancho × (alto − 54·s)` px de pantalla; 1280×352 con
  1280×720) se dibuja en tres capas (ver § "Cámara y encuadre"):
  1. **mundo** (tiles, actores, efectos, partículas, cinemática) en
     píxeles del mundo, rasterizado a `ceil(ancho/zoom) × ceil(alto/zoom)`
     y escalado ×`zoom` con vecino más cercano (`zoom` entero fuera de
     las cinemáticas: píxel perfecto);
  2. destellos de pantalla (`hurtFlash`, `flash`);
  3. **HUD de la escena** en píxeles de pantalla (texto nítido de la
     fuente en múltiplos de 8 px): nombres, vida, insignias, marcas de
     turno/objetivo, números y textos flotantes (§ "Etiquetas").
- Unidad del HUD `u = escala < 2 ? 1 : 2` (1 con 1280×720, 2 con
  1920×1080): nombres y textos 8·u px, números 16·u (crítico 24·u),
  números de ULT 24·u (crítico 32·u).

## Posiciones (`startBattle`)

Con `(bx, by)` = posición del enemigo del campo que empezó la batalla y
`n` jugadores:
- Lado `s = trig.x > bx ? 1 : −1`; si `bx + s·86 < 12` → `s = 1`; si
  `bx + s·86 > ancho_mapa − 12` → `s = −1`. `trig` = el jugador que tocó
  al enemigo; como el motor no lo guarda, se usa el jugador más cercano
  a `(bx, by)` al empezar (las posiciones del campo no cambian en
  batalla). Se calcula una vez por batalla (`SessionBattle.id`).
- Jugador `i`: `x = bx + s·(72 + (i mod 2)·14)`,
  `y = by + (i − (n−1)/2)·24`, mira a `−s`.
- Enemigo `i`, con `offs = [(0,0), (22,−26), (22,26), (40,0)]`:
  `x = bx − s·(offs[i].x + (i > 0 y el primero es jefe ? 18 : 0))`,
  `y = by + offs[i].y`. Miran a `s` (`dir = side`).
- Sin mapa (tests, previsualización): `(bx, by) = (VW/2 − 34, 104)`,
  `s = 1`, fondo `#05060c`.
- La cámara ya no es la del prototipo (`tx`/`ty` con la vista de
  480×288 a escala ≈ 1.2, que dejaba a los combatientes chiquitos en el
  medio de una escena de 1280×418): ver § "Cámara y encuadre".

## Cámara y encuadre

Pedido del dueño: los combatientes tienen que **llenar** el área del
mundo, con el pixel art nítido.

- Caja de cada actor (px del mundo, `(x, y)` = pies): héroe
  `(x − 10, y − 19, 20, 22)`; enemigo `(x − w/2, y − h, w, h + 4)` con
  `w × h` = sprite × `enemyScale` × (1.45 si élite) (sin sprites 16×14).
- **Caja de la pelea** = unión de las cajas de todos los actores (vivos
  y caídos) + margen de 16 px del mundo a los lados, 6 arriba y 6
  abajo.
- **Zoom base** (entero, vecino más cercano):
  `zoom = clamp(floor(min(W / cw, (H − 22·u) / ch)), 1, 6)` con `W × H` el
  área del mundo en px de pantalla y `cw × ch` la caja de la pelea; los
  `22·u` px quedan para las etiquetas de la fila de arriba. Con
  1280×720 y 4 contra 4 da ×3 (antes ≈ ×1.22).
- **Centro**: el de la caja, corrido `11·u / zoom` px hacia arriba (lugar
  para las etiquetas). La vista mide `W/zoom × H/zoom` px del mundo. Si
  hay mapa se prefiere no mostrar fuera de él: el centro se lleva hacia
  `[vista/2, mapa − vista/2]` **solo mientras la caja de la pelea siga
  entera adentro** (el fondo del mapa se conserva; si el mapa es más
  chico que la vista se ve el negro de alrededor).
- La cámara (centro + zoom) arranca en la del campo (centro = jugador
  local, mismo zoom) y se mueve hacia la base con suavizado `0.12` por
  frame de 60 Hz (centro y zoom), salto directo si la distancia es
  > 200 px del mundo.
- Durante una cinemática de ULT la cámara la maneja el guion de la ULT
  (§ "Ultimates"); al terminar vuelve exactamente a la base.
- La esquina de la vista se redondea a píxeles enteros del mundo
  (sin medio píxel). Sacudida: `round((azar − 0.5)·sh·2)·s` px de
  pantalla (la misma amplitud en pantalla que antes, con `s` la escala
  de la franja), al mundo y al HUD.
- Clic/toque: pantalla → mundo con `cámara + (p − origen del área) /
  zoom`.

## Etiquetas (HUD de la escena)

En px de pantalla, encima del mundo (nunca escaladas ni pixeladas):
- héroe: `nombre` (8·u, dorado el local, blanco el resto) con la base
  en el pie de la caja del héroe menos 2·u px (arriba de la cabeza),
  seguido de las insignias compactas en la misma línea;
- enemigo: `vida/máx` (8·u, `#ffd8a8`) + insignias en una línea y debajo
  la barra de vida de `(jefe o élite ? 48 : 28)·u × 3·u` (colores de
  antes), arriba del sprite;
- insignia compacta: caja `#000000cc` de `(4 + ancho(letra+stacks))·u`
  × 10·u con franja de color de 2·u a la izquierda;
- **sin superposición**: cada etiqueta es un rectángulo; se ubican de
  arriba hacia abajo (por `y` del ancla) con la primera posición libre
  entre: la preferida, corrida 1, 2, 3 líneas hacia arriba, y corrida
  media etiqueta a la izquierda/derecha; siempre dentro del área del
  mundo (`placeLabels`, puro y con test de 4 contra 4);
- turno de un jugador: triángulo `#ffd166` de `8·u` arriba de su
  etiqueta (con el rebote `sin(t/130)·2·u`); objetivo: triángulo igual
  arriba de la etiqueta del enemigo; turno de enemigo: barra `#ff4757`
  bajo sus pies (en el mundo, como antes);
- durante las fases de preparación y descarga de una ULT las etiquetas
  se desvanecen (alfa `1 − oscurecido`); los números y textos flotantes
  siguen.
- Números y textos flotantes (`num`, `txt`): su ancla del mundo pasada
  a pantalla, suben `edad/40 · 1.5·u` px; los de ULT (`heavy`) entran
  con un rebote: escala `1 + 0.6·(1 − p)` con `p = min(1, edad/140)` y
  saltito `|sin(edad/80)|·6·u·e^(−edad/260)`, y duran 1400 ms.

## Escena

Orden de dibujo (capa del mundo): fondo `#05060c`, tiles (los de
`drawTile`, vía el callback del mapa), enemigos lejanos del campo
(> 130 px del centro; el de la batalla nunca), el **oscurecido** de la
ULT (solo sobre el fondo), actores ordenados por `y`, efectos del mundo,
lo del mundo de la ULT, partículas. Después, en pantalla: destello rojo
de daño (`hurtFlash`), destellos `flash`, el HUD de la escena y, en una
capa aparte encima de toda la batalla (también de la barra), la parte de
pantalla de la ULT (§ "Ultimates").

### Héroes

Como `drawHero` (docs/specs/sprites.md § "Héroe") en batalla: sin bob,
sombra 6×2, mira a `−s`, arma dibujada en código, muerto acostado con
alfa 0.55. Además:
- estocada de 6 px hacia donde mira mientras un `act` suyo tenga edad
  < 260 ms (la sombra no se mueve);
- defendiendo: círculo `#74b9ffaa` radio 11 en `(0, −8)`;
- nombre, insignias y marca de turno: en el HUD (§ "Etiquetas");
- "tiempo congelado": durante la preparación y la descarga de una ULT
  la flotación y los rebotes usan un reloj de pose que no avanza.

### Enemigos

Como `drawEnemy` (sprites.md § "Enemigo") con `dir = s`, flotación,
aura élite y:
- estocada de `6·dir` px con un `act` < 260 ms;
- destello blanco (brillo ×3) con un `slash` sobre él de edad
  `[0, 120)` ms;
- muerte: alfa `max(0.15, 1 − (t − t_muerte) / 350)`, deja de
  dibujarse a los 350 ms; `t_muerte` es el primer frame en que la escena
  lo ve con vida 0. Si es objetivo de la ULT en curso, `t_muerte` pasa
  a ser el impacto de la ULT en él + 120 ms (sigue entero hasta que le
  pega);
- barra de vida, `hp/máx`, insignias y marca de objetivo: en el HUD
  (§ "Etiquetas"); barra de vida: fondo `#000000aa`, relleno `#ff4757`
  (jefe), `#ffd166` (élite) o `#ff9f43`;
- turno: barra `#ff4757` de 20×2 en `(x − 10, y + 3)`.

Clic/toque sobre un enemigo vivo (caja de su sprite + 4 px) lo elige como
objetivo.

### Insignias (`drawBadges`)

Por estado activo, en el orden Quemadura, Veneno, Congelación, Aturdido,
Sagrado, Regeneración: la insignia compacta de § "Etiquetas" (`letra +
stacks` del color del estado), en la línea del nombre / de la vida.

| Estado | Letra | Color | Nombre |
|---|---|---|---|
| Quemadura | Q | `#ff7b29` | Quemadura |
| Veneno | V | `#7bed9f` | Veneno |
| Congelación | C | `#74b9ff` | Congelación |
| Aturdido | A | `#ffeaa7` | Aturdido |
| Sagrado | S | `#fff3b0` | Sagrado |
| Regeneración | R | `#55efc4` | Regeneración |

## Franja de turnos (`drawTimeline`)

- Fondo `#0b0e1a`; banda `0..32` `#0b0e1acc`; línea `#5b74c9` en `y=32`.
- Barra de tiempo (turno de un jugador y la sesión esperando): fondo
  `#000000aa` `0..VW × 33..37`, relleno `VW · left/30`; `#ffd166`, o
  si `left ≤ 10` alterna `#ff4757` / `#ff6b81` cada 250 ms.
- `TURNOS` 6 px `#9fb4ff` centrado en `(26, 19)`.
- Los próximos 10 turnos de `predictTurns` desde `x = 52`: el primero de
  28 px en `y = 2`, el resto de 22 px en `y = 6`; fondo `#1d2a5a`
  (jugador) o `#4a1820` (enemigo); borde `#ffd166` de 2 px el primero,
  si no 1 px `#ffd166aa` (jugador local), `#5b74c9` (otro jugador) o
  `#ff4757` (enemigo). Sprite escalado a `min((sz−4)/w, (sz−4)/h)`,
  centrado. Puntos de estado 3×3 de su color en `(x+2+4k, y+sz−4)`.
  Triángulo `#ffd166` bajo el primero (`b = sin(t/150)·1.5`) y una
  flecha `#5b74c9` 3×2 entre el primero y el segundo. Separación 8 px
  tras el primero, 4 tras el resto.
- Banda del log `y ∈ [38, 54)` negra: log de batalla y, en el turno de
  un jugador, `TÚ` o su nombre (6 letras) + segundos restantes a la
  derecha, `#ffd166` o `#ff6b81` con ≤ 10 s (`drawTurnLabel`). Son
  textos Flutter de 8 px (ver desvíos).

### `predictTurns(estado, n)`

Actores vivos (jugadores primero, en orden; después enemigos) con
`nt = nextTurn` e `iv = 100 / (vel × (1 − 0.12 × congelación))`. Si hay
actor de turno, va primero y su `nt` pasa a `max(nt, reloj) + iv`.
Después, hasta tener `n`: el de menor `nt` (en empate, el primero de la
lista), y su `nt += iv`.

## Eventos → efectos

El motor emite `BattleEvent` sin coordenadas ni colores (combat.md
§ "Eventos para la UI"); `BattleFxMapper` los traduce con las posiciones
de la escena. Un `ActionEvent` abre el contexto de la acción (quién,
qué habilidad, retraso del impacto); los eventos siguientes del mismo
paso se interpretan dentro de él.

`dl` = retraso del impacto en ms: 280 si el ataque/habilidad es mágico o
el arma es a distancia (`arco`, `rifle`, `báculo`, `tomo`) y lleva un
`proj`; en una ultimate, el impacto de su guion en ese objetivo
(`impactFor(i)`, § "Ultimates"; `i` = orden de aparición del objetivo
en los eventos de la acción); 300 en un dúo; 0 si no.

| Evento | Efectos (`addFx` del prototipo) |
|---|---|
| `ActionEvent` ataque | `act`; a distancia: `proj` blanco `phys`; Golpe Imparable (todos): `ring` blanco en el atacante |
| `ActionEvent` habilidad / ULT | `act`; daño a todos sin ULT: `ring` del color de la habilidad; a distancia o mágica: `proj` por objetivo |
| `UltimateUsedEvent` | `ult` (cinemática) con nombre, color, elemento y guion de la ULT del arma, y la lista de objetivos (ids de los `DamageEvent` de la acción en orden; en Baluarte, los de los `HealEvent`) |
| `ActionEvent` ULT | `act` con retraso = fin de la preparación (el lanzador se lanza al descargar); ni anillo ni proyectiles |
| `DamageEvent` en una ULT | como un golpe a enemigo, con el `dl` del impacto, `num` **pesado** (`heavy`: grande y con rebote); crítico: además `flash` blanco con el mismo `dl` |
| `HealEvent` en una ULT (Baluarte) | `num` `+n` pesado y `aura` sagrada con el `dl` del impacto en ese aliado |
| `KnockedOutEvent` de enemigo en una ULT | `poof` con el `dl` del impacto en él |
| `ActionEvent` dúo | `act` de ambos, `flash` del color del dúo, `ring` grande en el punto medio, `proj` de cada uno a cada enemigo |
| `ActionEvent` Fortaleza | `txt` `DEF +n` `#74b9ff` en `y−30`, `aura` maná |
| `ActionEvent` Protección | `ring` grande `#ffeaa7`, `aura` sagrada en los otros aliados vivos |
| `ActionEvent` Provocar | `txt` `¡PROVOCA!` `#ff7675` en `y−30`, `ring` grande `#ff7675` |
| `ActionEvent` Escudo de Fe | por aliado vivo: `txt` `ESCUDO` `#74b9ff` en `y−30`, `aura` sagrada |
| `ActionEvent` Prisa | por otro aliado vivo: `txt` `¡PRISA!` `#ffd166` en `y−26` |
| `ActionEvent` enemigo | `act`; Colapso Temporal: `flash` `#e84393` y `ring` grande `#e84393` en `(x, y−10)` |
| `DamageEvent` a enemigo | `num` en `y−20` (`#ffd166` 12 px si crítico, si no `#ffffff` 8 px) con `dl`; crítico: `txt` `¡CRÍTICO ×cm!` `#ffd166` en `y−34`; `slash` en `(x, y−8)` del color y elemento de la acción |
| `DamageEvent` a jugador | `num` en `y−18` (`#ff4757` 12 px crítico, si no `#ff6b81`), `hurt`; `slash` `#ff6b81` con el elemento del estado que inflige el enemigo; crítico: `txt` `¡CRÍTICO ×1.5!` `#ff4757` en `y−34`; perforante: `txt` `¡PERFORANTE ×m!` `#ff9f43` en `y−44` |
| `DamageEvent` de estado | `aura` (quemadura o veneno) y `num` en `y−20` `#ff9f43` (quemadura) / `#7bed9f` (resto) |
| `HealEvent` en una acción | `num` `+n` `#7bed9f` en `y−18` (`y−26` y aura sagrada en la cura de Fe); `aura` de curación (sagrada en Baluarte); maná: `+n MP` `#74b9ff` y `aura` maná |
| `HealEvent` de Regeneración | `num` `+n` `#55efc4` en `y−30`, `aura` de curación |
| `StatusAppliedEvent` | `txt` `letra+n` (+ ` (débil)`) del color del estado en `y−46`, con el `dl` del golpe |
| `DelayedEvent` (enemigo) | `txt` `RETRASO` `#a29bfe` en `y−44` |
| `TurnSkippedEvent` | aturdido: `txt` `¡ATURDIDO!` `#ffeaa7`; congelado: `txt` `¡CONGELADO!` `#74b9ff` + `aura` hielo; en `y−34` |
| `KnockedOutEvent` | jugador: `txt` `K.O.` `#ff4757` en `y−28`; enemigo: `poof` en `y−6` |
| `BattleEndedEvent` victoria | `txt` `+$créditos` `#ffd166` en `y−40` de cada jugador |

### Catálogo de efectos (edad `a` en ms, desde `inicio + dl`)

| Tipo | Duración | Dibujo |
|---|---|---|
| `num` | 1100 | texto con sombra en `y − a/40`; 12 px si `big`, si no 8 |
| `txt` | 1400 | texto 7 px en `y − a/60` |
| `slash` | 220 | dos trazos de 2 px: `(x−10+4p, y−10)→(x+10−4p, y+10)` y `(x+10, y−10+4p)→(x−10, y+10−4p)`, `p = a/220` |
| `proj` | 280 | de `(x, y−10)` del atacante a `(x, y−10)` del objetivo, arco de 10 px (`− sin(pπ)·10`); `phys`: trazo blanco de 1.5 px y 7 de largo; otro elemento: 5 círculos de estela (radio `3.5 − 0.5i`, alfa `(1 − i/5)·0.8`, retraso `0.05i`) + núcleo blanco radio 1.5 |
| `ring` | 450 | elipse sin relleno de radios `(big ? 60 : 34)·p × (big ? 30 : 17)·p`, trazo `big ? 3 : 2`, alfa `1 − p` |
| `poof` | 500 | 8 cuadrados 3×3 blancos en círculo de radio `a/25`, alfa `1 − a/500` |
| `flash` | 350 | rectángulo de toda la escena del color, alfa `0.35·(1 − a/350)` |
| `act` | 260 | sin dibujo: activa la estocada |
| `aura` | — | sin dibujo: al activarse, `burst(x, y−8, el)` |
| `ult` | guion (2200-2500) | cinemática (§ "Ultimates") |

Al activarse (edad 0, después de `dl`) cada efecto dispara lo de
`fxVisual`:
- `slash`: `burst(x, y, el)`; `aura`: `burst(x, y−8, el)`;
  `poof`: `burst(x, y, arc, 0.8)`;
- `num` grande: sacudida `max(sh, hurt ? 7 : 5)`, con `hurt` además
  `hurtFlash = 0.45`, y `burst(x, y+10, phys, 1.5)`; `num` con `hurt`:
  sacudida `max(sh, 2)`;
- `flash`: sacudida `max(sh, 6)`; `ult`: empieza la cinemática.

### Partículas (`ELFX` / `burst` / `drawParts`)

`burst(x, y, el, mult)` crea `round(n·mult)` partículas: ángulo al azar,
velocidad `sp·(0.35 + azar·0.85)`, posición `x ± 9` (rayo/cruz) o
`x ± 2.5`, `y ± 3`; `vx = cos·v`, `vy = sin·v·(g < 0 ? 0.4 : 1) −
(g < 0 ? 8 : 0)`; vida `life·(0.6 + azar·0.6)`; tamaño `1 + azar·1.8`;
color al azar de la lista. Máximo 600 partículas (se descartan las más
viejas). Cada frame (`dt` ≤ 0.05 s): `vy += g·dt`, `x += vx·dt`,
`y += vy·dt`, `vx ×= 0.98`; alfa `min(1, vida/vida_máx·1.4)`.

| Elemento | Colores | n | sp | g | vida | Forma |
|---|---|---|---|---|---|---|
| `phys` | `#ffffff #ffeaa7 #dfe6e9` | 9 | 80 | 160 | 0.35 | cuadrado |
| `burn` | `#ff7b29 #ffd166 #e17055 #d63031` | 18 | 35 | −70 | 0.75 | cuadrado |
| `frz` | `#74b9ff #dff9fb #81ecec #ffffff` | 14 | 65 | 40 | 0.65 | astilla 6×1.5 rotada según la velocidad |
| `poi` | `#7bed9f #badc58 #55efc4 #20bf6b` | 12 | 22 | −28 | 1.0 | burbuja (círculo sin relleno, radio `s+0.5`) |
| `arc` | `#a29bfe #e84393 #ffffff #6c5ce7` | 16 | 75 | 0 | 0.5 | cuadrado |
| `holy` | `#fff3b0 #ffeaa7 #ffffff` | 12 | 12 | −45 | 0.85 | rayo 1.5 × (6+2s) |
| `heal` | `#7bed9f #55efc4 #ffffff` | 10 | 14 | −38 | 1.0 | cruz 5×2 + 2×5 |
| `mana` | `#74b9ff #a29bfe #ffffff` | 10 | 14 | −38 | 1.0 | cuadrado |
| `lvl` | `#ffd166 #fff3b0 #ffffff` | 30 | 22 | −85 | 1.3 | rayo |

Sacudida: baja `22/s`; `hurtFlash` baja `0.9/s` y se dibuja como
gradiente radial de `0.3·VH` (transparente) a `0.65·VW`
(`rgba(255,40,60, hurtFlash·1.6)`), centrado.

### Elemento y color de cada acción

`elemento = el de la habilidad ?? estado que aplica ?? (mágica ? arc :
phys)`. Los colores (`col`) y `el` son de `SK` / `ULTS` / `DUALS` del
prototipo y viven en `fx_style.dart` (el motor no los conoce).
Golpe Sagrado, Lanza de Luz, Martillo del Juicio, Juicio Divino y
Martillo Celestial son `holy`. El daño de "Luz" (Aura Restauradora con
`creyente`) es `holy` color `#fff3b0`. Ataque normal: blanco, `phys`.
Dúo: el estado del dúo y su color. Enemigo: el estado que inflige o
`phys`.

## Disparadores del árbol (procs)

Pedido del dueño: que las notables y keystones del árbol v2 "se sientan
bien y se lean". El motor emite `ProcEvent` (actor + mecánica + objetivo
opcional) antes de lo que la mecánica produce, `BuffAppliedEvent`,
`ShieldEvent` (gana / absorbe) y `DamageEvent.sourceId` en el daño
secundario (combat.md § "Disparadores del árbol (v2)"). `battle_fx.dart`
los traduce con los mismos principios que el resto: cada efecto corto
(≤ 0.7 s salvo el cartel del nombre), legible, y **después** del golpe
que lo causó. No se agregan datos al motor: el "de dónde viene" de un
rebote o de un contagio lo deduce el mapeo (último enemigo golpeado por
la acción / último enemigo caído en el paso).

### Tiempos (`ProcTiming`, compartidos con el sonido)

- `base` del paso: sin acción (inicio de turno: Plegaria, Égida) 0; en
  una ULT, el **regreso** de su guion (`returnAt`, después de todos los
  impactos: los procs de una ULT nunca pisan la cinemática); si no, el
  mayor `dl` de golpe de la acción + **120 ms** (`afterMs`). En una
  acción enemiga (Contraataque, Represalia, escudos) el golpe es a 0 →
  120.
- Cartel con el nombre: por actor y mecánica **una vez por paso**; el
  `k`-ésimo cartel del mismo actor (`slot = k` mod 4) sale `k × 180 ms`
  después y se apila encima del anterior, así varios procs no se pisan.
- Rebote / Corte en Cadena / Arco Voltaico (y Cadena Infinita, que
  usa los mismos ids): salto `h` (0, 1, ...) en `base + h × 130`; el
  número y el tajo del salto caen 60 ms después del arco.
- Combustión: estallido en `base`; los demás enemigos reciben la bola
  de fuego (un `proj` de 280 ms) en `base + 280 + i × 50`.
- Eco Arcano: la habilidad se repite fantasma desde `base + 220`
  (`+ i × 60` por objetivo); el golpe llega con el proyectil (+280).
- Contraataque: el héroe se lanza en `base`; el tajo cae en `base + 80`.
- Castigo Divino: el rayo baja en `base`; el daño en `base + 180`.
- Plaga Contagiosa: el chorro sale en `base` y llega en `base + 450`.
- Sed de Sangre y Plaga Contagiosa se disparan al final de la acción:
  usan la **base tardía** = `max(base, último efecto secundario
  programado en el paso + 60)` (si el que mata es un rebote, el latido
  va después de ese rebote). Sed de Sangre: latido en esa base, la cura
  100 ms después.
- Viento a Favor: el ataque gratis (su `ActionEvent` y todo lo que
  sigue hasta la próxima acción) se corre a `base`.
- Escudo que absorbe: en el mismo ms del golpe enemigo (0).
- Los estados, `RETRASO` y `poof` de un objetivo tocado por un efecto
  secundario usan el `dl` de ese efecto (no el del golpe primario).

### Eventos → efectos de procs

| Evento / mecánica | Efectos |
|---|---|
| `ProcEvent` (toda mecánica) | `tag` con el nombre (`kMechanics[id].name`) **sobre la etiqueta del actor**: **dorado `#ffd166` las notables, rojo `#ff4757` las keystones** (Danza de Cuchillas, Cadena Infinita, Égida Eterna, Alma de Hielo); caja negra 75% con barra del color a la izquierda; 1300 ms. Si el proc le da un buff o escudo **al mismo actor**, el valor va en el cartel (`Frenesí · VEL +20%`, `Égida Eterna · ESCUDO +10`, `Guardián · +8 ULT`); si cae sobre otro, va como `txt` sobre ese otro en `y−30` |
| Rebote | `arc` `#81ecec` `phys` (estela curva, celeste de viento) del objetivo anterior al nuevo; número `#81ecec` + tajo |
| Corte en Cadena | `arc` `#ff6b81` `phys`; número `#ff6b81` + tajo |
| Arco Voltaico | `arc` `#74b9ff` `mana` (rayo quebrado que titila); número `#74b9ff` + tajo |
| Combustión | `blast` en el centro (disco de fuego + anillo de 70 px, partículas de fuego ×2.2, sacudida 5); `proj` de fuego del centro a cada otro enemigo; número `#ff7b29` + tajo `burn` |
| Choque Térmico | `puff` de vapor en el objetivo + `txt` `¡ATURDIDO!` `#ffeaa7` en `y−34` |
| Eco Arcano | `ring` fantasma (50% alfa) del color de la habilidad en el lanzador; por objetivo `proj` y `slash` fantasma del color y elemento de la habilidad; número del color de la habilidad |
| Contraataque | `act` del héroe, `arc` blanco héroe → enemigo, `slash` blanco; número blanco |
| Castigo Divino | `beam` dorado desde arriba; número `#ffd166` + tajo `holy` |
| Tiempo Gélido | `aura` de hielo en el objetivo; `RETRASO` con ese `dl` |
| Martillo Bendito | `aura` de aturdido + `txt` `ATURDIDO +1` `#ffeaa7` en `y−40` |
| Plaga Contagiosa | `stream` verde del enemigo caído al nuevo huésped; el `V+n` cae al llegar |
| Sed de Sangre | `pulse` doble (latido) `#d63031` en el actor; la cura `+n` con aura de curación |
| Plegaria | la cura (sin acción) con aura sagrada en vez de la de Regeneración |
| Guardián | `spark` (chispas doradas) en el actor + `· +8 ULT` en su cartel (en la escena, no en la barra) |
| Viento a Favor | solo el cartel (el ataque gratis se anima como un ataque normal, corrido a `base`) |
| Danza de Cuchillas | `timeStop`: congela el reloj de la escena 90 ms (hit-stop) y tiñe la escena de celeste pálido; cartel grande `¡OTRA VEZ!` rojo con contorno **sobre el cuerpo** del actor (`y−10`) 150 ms después |
| Desafío, Égida Eterna, Mano Sanadora | solo el cartel; el escudo lo dibuja el `ShieldEvent` |
| `BuffAppliedEvent` Frenesí (velocidad) | `afterimage`: dos copias rojas `#ff6b81` del héroe detrás de él; `VEL +20%` en el cartel |
| `BuffAppliedEvent` Represalia (ATQ +) | `pulse` naranja `#ff9f43` + `arrow` arriba naranja; `ATQ +30%` en el cartel |
| `BuffAppliedEvent` Debilitar (ATQ −) | `arrow` abajo verde `#7bed9f` + `txt` `ATQ −15%` verde sobre el enemigo |
| `BuffAppliedEvent` Marca del Cazador | `reticle` rojo `#ff4757` que se cierra sobre el enemigo + `txt` `+15% DAÑO` |
| `BuffAppliedEvent` Martillo Bendito | `txt` `ATURDIDO +1` (ver arriba) |
| `BuffAppliedEvent` otro | `txt` con el stat y el % |
| `ShieldEvent` gana | `bubble` crema `#ffeaa7` alrededor; `ESCUDO +n` en el cartel si es propio, si no `txt` sobre el aliado en `y−30` |
| `ShieldEvent` absorbe | `crack` con el golpe enemigo (destello y grietas en el borde de la burbuja + astillas crema, sacudida 2) + `txt` `ABSORBE n` en `y−30`; si absorbió todo (`DamageEvent` de 0) la grieta **es** el golpe: sin número, tajo ni sacudida de daño |

Persistentes (del estado, sin evento):
- Escudo activo (`hasEffect(shield)`): burbuja crema tenue que late
  alrededor del héroe.
- Marca del Cazador (`hasEffect(damageTaken)`): retícula roja chica
  sobre la cabeza del enemigo mientras dure.
- Último Aliento (mecánica `ultimoAliento` y vida < 30%): resplandor
  rojo que late a los pies y alrededor del héroe.
- Punto Débil, Fractura y Alma de Hielo no tienen evento ni efecto
  propio (son modificadores; se leen en el log).

### Catálogo de efectos de procs (edad `a`, `p = a / duración`)

| Tipo | Duración | Dibujo |
|---|---|---|
| `tag` | 1300 | caja negra + barra de color + nombre (8 px de HUD) con la base 4 px de HUD arriba de la etiqueta del actor, `slot × (alto + 6)` más arriba, sube `a/160`; si no entra arriba del área del mundo se apila hacia abajo desde el borde; nunca se sale de los costados; se apaga los últimos 250 ms. `big`: 16 px con contorno y pop (×1.5 → ×1 en 110 ms) en `(x, y)` |
| `arc` | 240 | alfa 1 hasta `p = 0.6`, después se apaga; `phys`: estela curva (bezier con 10 px de comba al costado) que llega al destino en `p = 0.4`, más tenue hacia el origen, con cabeza blanca; otro elemento: rayo quebrado de 7 tramos que titila cada 40 ms, trazo de color 2.5 px + núcleo blanco; al activarse, partículas del elemento en el destino |
| `blast` | 520 | disco `6 + 18p` de fuego con núcleo blanco al principio, anillo `70p × 35p` naranja de 3 px, alfa `1 − p` |
| `beam` | 480 | columna dorada desde 160 px arriba hasta los pies, ancho `2 + 6(1 − p)`, núcleo blanco, óvalo de luz abajo |
| `bubble` | 650 | círculo de radio 6 → 12 en 150 ms alrededor de `(x, y−8)`, relleno crema 25% y borde que se apaga, brillo arriba a la izquierda |
| `crack` | 420 | destello crema 35% los primeros 90 ms; círculo de radio 13 que se abre 2 px con 4 grietas cortas en zigzag hacia adentro desde el borde, alfa `1 − p`; al activarse 7 astillas y sacudida 2 |
| `pulse` | 520 (doble: 700) | óvalo de 8 → 20 px, trazo y relleno 25% del color, alfa `1 − p`; doble: otro latido a los 220 ms |
| `reticle` | 500 | círculo de radio 16 → 6 en 300 ms con 4 marcas, luego se queda y se apaga |
| `arrow` | 900 | flecha pixel de 7 px arriba/abajo sobre el actor, se mueve 6 px en su dirección |
| `stream` | 520 | 12 partículas del color sobre una curva ondulada que avanzan de origen a destino |
| `timeStop` | 420 | tinte celeste pálido de toda la escena `0.3(1 − p)` + 2 franjas blancas que barren; al activarse, hit-stop de 90 ms |
| `afterimage` | 650 | (en el héroe) 2 copias del sprite teñidas del color, 5 y 10 px detrás, alfa `0.45(1 − p)` |
| `puff`, `spark` | — | sin dibujo: partículas de vapor / chispas doradas al activarse |
| `proj`, `slash`, `ring` con `ghost` | igual | a 50% de alfa y la mitad de partículas (Eco Arcano) |

## Ultimates (cinemáticas)

Pedido del dueño: "que las ultis tengan impacto", con la **sensación**
de los súper ataques de los JRPG clásicos de fines de los 90 (dramáticos,
cinematográficos, con peso). No se copia ninguna animación, nombre, arte
ni música de otro juego: los nombres y efectos son los de este juego
(`kUltimates`). Reemplaza el `ultWorld` / `ultScreen` del prototipo.

Implementación: guiones (datos puros) en
`lib/features/combat/presentation/scene/ult_cinematic.dart`
(`UltScript`, `kUltScripts`, `ultScriptFor`, `ultCameraAt`); disparos
(partículas, sacudida, hit-stop) y dibujo del mundo en
`scene/ult_fx.dart` (`UltDirector`); la parte de pantalla en
`BattleOverlayPainter` (`battle_painter.dart`).

### Fases

Edad `a` (ms) desde que se activa el `ult`:

1. **Preparación** `[0, build)`: todo lo demás se oscurece casi a negro
   (el fondo del mundo `rgba(4,4,12, 0.85·d)`, la franja y la barra
   `0.75·d`; `d` sube en 200 ms), el **tiempo se congela** (reloj de
   pose quieto: sin flotación ni rebotes), barras de cine (letterbox) de
   `9 %` del alto del área del mundo entran arriba y abajo, la cámara
   hace zoom y paneo al lanzador, un aura/carga propia de la ULT se junta
   en él (líneas que convergen, anillo, y cada 120 ms partículas del
   elemento **a los costados** del lanzador, alternando, para que con el
   zoom se lo siga viendo), y la **tarjeta con el nombre**: banda a todo
   el ancho, arriba del área del mundo justo debajo de la barra de cine
   (el lanzador queda en el centro), que entra cortando de izquierda a
   derecha (`[80, 260)` ms, borde blanco de 2 px adelante), con el sprite
   del lanzador grande (×3 de la unidad de la tarjeta) a la izquierda,
   `★ ULTIMATE · lanzador` (8 px) y debajo el nombre de la ULT en
   mayúsculas (16 px, con contorno) — la tarjeta se dibuja en una capa
   pixelada (unidad `2·u`) — y sale hacia la derecha desvaneciéndose en
   `[build − 140, build + 60)`.
2. **Descarga** `[build, build + release)`: la cámara gira a los
   objetivos, el efecto grande propio de la ULT, sacudidas fuertes,
   partículas, **hit-stop** (el reloj de la escena se detiene `hitStop`
   ms) en el **último** impacto, destello blanco de pantalla en el
   último impacto (`0.7·k`, `k` baja de 1 a 0 en `[imp − 20, imp + 140)`;
   dorado `0.35·k` en Baluarte; se mantiene durante el hit-stop), números pesados con rebote (los críticos además un
   `flash` blanco). Oscurecido `0.6·d`.
3. **Regreso** `[build + release, total)`: la cámara vuelve a la base,
   el oscurecido y las barras de cine se van, los colores vuelven.

Impacto en el objetivo `i` (orden de los eventos):
`impactFor(i) = impact + stagger·min(i, 3)`. Los números, textos de
estado, `poof` y el destello de crítico usan ese retraso (`dl`), y el
sonido de impacto también (docs/specs/audio.md § "Ultimates"): todo
cae en el mismo ms.

### Cámara de la cinemática (`ultCameraAt`)

Con la base `(centro, zoom)` del encuadre:
- `[0, min(350, 0.45·build))`: interpolación suave (smoothstep) al
  lanzador: centro `(x, y − 12)`, zoom `base + max(1, round(0.6·base))`
  (entero: nítido en la pausa); se mantiene hasta `build`;
- `[build, build + 250)`: al foco de la descarga: objetivos (centro de
  sus pies, `y − 10`) con zoom `base` (a todos, Disparo Letal: punto
  medio lanzador–objetivo) o `base + 1` (un objetivo: Tajo Final,
  Martillo Celestial); Baluarte: el grupo, zoom `base`;
- al impacto principal un "empujón" de `+0.15` de zoom que vuelve en
  180 ms;
- `[build + release, total)`: de vuelta a la base.

### Guiones (ms; objetivo `i`)

| ULT | Arma | Prep. | Descarga | Regreso | Total | Impacto `i` | Hit-stop | Sacudida |
|---|---|---|---|---|---|---|---|---|
| Tajo Final | `espada` | 800 | 1000 | 400 | 2200 | 1380 (tajos previos 1000, 1120, 1240) | 110 | 10 |
| Cataclismo | `hacha` | 900 | 1100 | 400 | 2400 | 1300 + 60·i | 100 | 12 |
| Meteoro | `báculo` | 900 | 1200 | 400 | 2500 | 1350 + 120·i | 100 | 11 |
| Paradoja | `tomo` | 900 | 1100 | 400 | 2400 | 1450 + 50·i | 120 | 8 |
| Tormenta de Flechas | `arco` | 700 | 1200 | 400 | 2300 | 1300 + 70·i | 80 | 8 |
| Disparo Letal | `rifle` | 900 | 900 | 400 | 2200 | 1350 | 140 | 12 |
| Baluarte | `espada+escudo` | 800 | 1100 | 400 | 2300 | 1150 + 60·i (curas) | 0 | 4 |
| Juicio Divino | `maza+escudo` | 900 | 1100 | 400 | 2400 | 1300 + 90·i | 90 | 9 |
| Martillo Celestial | `martillo+escudo` | 900 | 1000 | 400 | 2300 | 1300 | 150 | 14 |

La descarga termina como mucho a los 2100 ms: antes de la pausa de 2.3 s
de la sesión tras una ULT (docs/specs/missions.md), así el paso
siguiente casi nunca llega con la cinemática en curso.

### Diseño de cada ULT

Colores del arte (`kSkillColors`); "lanzador" `(x, y)` y objetivo
`(gx, gy)` en px del mundo.

- **Tajo Final** (blanco acero): preparación — líneas de velocidad que
  convergen hacia el lanzador, aura blanca, destello en forma de
  estrella en la punta de la hoja a los 650 ms. Descarga — el lanzador
  deja una estela de imágenes fantasma hasta el objetivo (800-950), tres
  tajos que cruzan toda la vista en diagonales distintas (1000, 1120,
  1240: trazo de 3 px blanco con borde del color, se abren y se
  desvanecen en 160 ms, chispas y sacudida 5 cada uno), y el final: una
  X gigante + destello blanco a 1380.
- **Cataclismo** (ocre `#e1b12c`): preparación — polvo que sube a los
  pies del lanzador, temblor continuo (sacudida 1.5), grietas que brillan
  naranja debajo. Descarga — golpe al piso a 950; grietas en zigzag
  corren por el suelo del lanzador a cada enemigo (950-1300, brillo
  naranja), el suelo estalla bajo todos: columna de escombros (cuadrados
  marrón/gris con gravedad) y destello de lava; quedan las grietas hasta
  el final.
- **Meteoro** (naranja `#ff7b29`): preparación — círculo mágico girando
  bajo el lanzador (elipse con runas), el cielo se tiñe de rojo. Descarga
  — un meteoro grande por objetivo (radio 9, estela de 8 círculos, desde
  `(gx + 110, gy − 230)`, cae en 420 ms hasta su impacto) más 3 meteoritos
  decorativos; al impactar: explosión (anillo naranja + `burst burn ×4` +
  `phys ×2`), cráter (elipse oscura con borde naranja que queda hasta el
  final), sacudida.
- **Paradoja** (violeta `#a29bfe`): preparación — un reloj (círculo con 12
  marcas) detrás del lanzador con las agujas girando hacia atrás,
  distorsión de "rebobinado" (franjas horizontales corridas). Descarga —
  un reloj gigante sobre los enemigos cuyas agujas barren, ecos
  fantasma de cada enemigo corridos en el tiempo, cristales de hielo que
  crecen encerrándolos (1000-1450) y se rompen en el impacto (`burst
  frz ×4`, `arc ×2`).
- **Tormenta de Flechas** (`#fdcb6e`): preparación — el arquero apunta
  al cielo y suelta una andanada de trazos hacia arriba (350-700).
  Descarga — el cielo se llena de flechas (40 trazos diagonales que caen
  sobre la zona de los objetivos durante toda la descarga), cada una
  que llega queda clavada (trazo corto), impactos con nube de veneno.
- **Disparo Letal** (rojo `#ff4757`): preparación — mira láser roja del
  lanzador al objetivo que se afina (400-900), carga que brilla en el
  cañón. Descarga — fogonazo enorme (estrella blanca + destello) a 950,
  bala en cámara lenta del lanzador al objetivo (950-1350) con anillos
  de onda a lo largo del recorrido, en el impacto anillo de impacto que
  se expande + destello blanco.
- **Baluarte** (azul `#74b9ff`): preparación — el escudo en alto, rayos
  dorados que convergen. Descarga — una **burbuja de escudo** enorme
  (elipse translúcida con paralelos y meridianos, radio vertical = media
  altura del grupo + 30, horizontal ≥ 0.9 del vertical) crece del
  lanzador hasta cubrir a todo el grupo (800-1100), con un brillo que
  recorre el borde y chispas sagradas; curas a 1150 + 60·i. Se
  desvanece en el regreso.
- **Juicio Divino** (`#ffeaa7`): preparación — halo sobre el lanzador y
  haces de luz que barren el cielo. Descarga — una línea fina de
  puntería baja sobre cada enemigo (950-1150) y después el **pilar de
  luz** (columna ancha con degradé dorado, núcleo blanco, anillo en el
  piso, rayos que suben) en su impacto.
- **Martillo Celestial** (dorado `#ffd166`): preparación — chispas
  eléctricas alrededor del lanzador, la sombra de un martillo gigante
  aparece y crece sobre el objetivo. Descarga — un martillo gigante
  (cabeza 44×26, mango) baja acelerando desde arriba de la vista
  (1000-1300), en el impacto ondas expansivas (3 elipses), polvo,
  destello y la sacudida más fuerte; queda incrustado y se desvanece.

### Nuevos pasos durante la cinemática

La escena nunca frena a la sesión. Si llega un paso nuevo con la
cinemática en preparación o descarga, sus efectos **esperan en cola** y
arrancan al empezar el regreso (con la hora de ese momento). Si se juntan
2 o más pasos en cola, la cinemática se **adelanta**: salta al regreso y
los efectos pendientes de la ULT (números, etc.) arrancan ya. Otra
batalla limpia todo. El cartel de victoria/derrota espera a que termine
la cinemática.

## Ritmo y repetición

- La sesión decide los tiempos (`wait`); la escena nunca la frena.
- `BattleView` recibe `events` + `eventSeq` (`SessionView.battleEvents`
  / `battleEventSeq`). Cada vez que `eventSeq` cambia, los eventos se
  traducen **una vez** con la hora actual como inicio. Si llegan varios
  pasos seguidos, los efectos se superponen (cada uno con su hora). Al
  crear la vista, el `eventSeq` actual se marca como visto (no se
  repiten efectos viejos). Otra batalla (`battleId`) limpia efectos,
  partículas y muertes vistas.
- Excepción: con una cinemática de ULT en preparación o descarga, los
  pasos nuevos esperan en cola (§ "Ultimates" → "Nuevos pasos durante la
  cinemática").
- Máximo 70 efectos vivos (como `B.fx`): se descartan los más viejos.

## Menú y ayudas

(Actualizado: el menú, los paneles de la barra y el `#tip` siguen 1:1 los
colores del prototipo; ver docs/specs/exploration.md § "Batalla" y
docs/specs/ui_style.md. La ayuda ya no va al pie del panel sino en el
tooltip, y los textos salen de `lib/features/combat/domain/skill_text.dart`
en markup.)

El menú plano numerado, Q/Tab y el submenú de pociones siguen como en
docs/specs/exploration.md § "Batalla". El panel muestra el objetivo
actual. Al pasar el mouse por una técnica o la ULT se muestra su
`descSkill` (texto plano) al pie del panel:
- daño: `Daño físico|mágico: ATQ|MAG × pow = N a 1 enemigo|a TODOS los
  enemigos (crítico M)`, `+X% de probabilidad de crítico`,
  `Retrasa al objetivo X% de un turno en la línea de tiempo`, y
  `stDesc`: `Aplica +n Nombre (desc)` o `X% de aplicar n Nombre (desc)`;
- curación: `Cura MAG × pow + 6 = N a cada aliado` (+ limpieza);
- regen, prisa, Fortaleza, Protección, Baluarte, Provocar, Escudo de Fe:
  las frases del prototipo.

## Desvíos respecto del prototipo

- El lienzo se estira al ancho/alto de la ventana (más mapa visible) en
  vez de barras negras; la escala no es entera (como `MapGame`).
- El menú y el grupo van en una barra fija debajo de la escena (como
  en el prototipo, fuera del canvas), pero con el layout pedido por el
  dueño: mis datos / acciones / resto del grupo (exploration.md §
  "Batalla").
- Log (blanco) y etiqueta de tiempo (caja negra, dorado / `#ff6b81`)
  son texto Flutter: el log va en 16 px si entra en una línea (≈ 6 px
  virtuales escalados), si no en 8 px.
- Los emojis de los textos flotantes (`🔥+2`, `💫`, `🛡`) se cambian por
  la letra del estado (`Q+2`), el texto `¡ATURDIDO!` y `ESCUDO`: la
  fuente no tiene emojis.
- Lado de la batalla: el jugador más cercano al enemigo en vez de "el
  que lo tocó" (el motor no lo guarda).
- Los textos de subida de nivel (`¡NIVEL n!`) no se dibujan en la
  batalla: los muestra la sesión al terminar (progression.md).
- Sin sonido en esta capa (`beep` de `onNewFx` es de otro módulo).
- Cinemáticas de ULT, cámara con zoom entero y etiquetas en pantalla:
  rediseño pedido por el dueño (§ "Ultimates", § "Cámara y encuadre",
  § "Etiquetas"); los tiempos de ULT ya no son los 1150 / 2200 ms del
  prototipo.
