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
| Quiebre y ULT enemigas: colores (`breakColor`, `kEnemyUltColors`), guiones (`kEnemyUltScripts`) | `scene/fx_style.dart`, `scene/ult_cinematic.dart`, `scene/ult_fx.dart` |
| Predicción de turnos (`predictTurns`, puro) | `lib/features/combat/domain/turn_order.dart` |
| Arena de la sesión (elige la arena y le pasa el pintor) | `lib/features/world/presentation/session_battle_screen.dart` |
| Selección de arena (pura): zona, Eco, Prueba, tipo de encuentro | `lib/features/combat/presentation/scene/arena/arena_spec.dart` |
| Dibujo de las arenas (capa estática cacheada + capa animada) | `lib/features/combat/presentation/scene/arena/arena_painter.dart` |
| Transición mapa ↔ arena | `lib/features/combat/presentation/scene/arena/arena_transition.dart` |

Tests: `test/features/combat/battle_fx_test.dart`,
`test/features/combat/break_fx_test.dart`,
`test/features/combat/proc_fx_test.dart`,
`test/features/combat/ult_cinematic_test.dart`,
`test/features/combat/battle_framing_test.dart`,
`test/features/combat/battle_arena_test.dart`,
`test/features/combat/turn_order_test.dart`,
`test/features/combat/battle_screen_test.dart`,
`test/game_engine/battle_engine_test.dart` (eventos `ActionEvent`).

## Arenas

Pedido del dueño (v0.5): que las peleas no sean "ahí mismo en el mapa"
sino en una arena temática por zona y por tipo de enemigo (normal, élite
o jefe), para que el posicionamiento de los personajes no se vea
comprometido. Cada batalla de la sesión se dibuja en un **escenario
propio**, independiente del terreno del mapa.

### Escenario

- `BattleArena.stage(kind, paintWorld)`: un mundo fijo de `960 × 540`
  px del mundo (`ArenaStage`), centro `(480, 300)` (`300` = línea de
  los pies), lado `s = 1` siempre (grupo a la derecha, mirando a la
  izquierda). Mismo sistema de coordenadas que el resto de la escena:
  cámara, clic sobre enemigos, números, ULT (`UltDirector.paintWorld`),
  partículas y mecánicas de jefe no cambian.
- La cámara usa el mismo encuadre (§ "Cámara y encuadre") con la caja
  de la pelea agrandada por el aire del tipo de encuentro
  (`ArenaStage.padFor`: normal `8 × 4`, élite `20 × 8`, jefe `44 × 16`
  px del mundo): más escenario a la vista cuanto más importante. El
  centro se lleva adentro del escenario; si la vista es más grande que
  el escenario, afuera se pinta el cielo arriba y el piso oscuro abajo.
  La arena se adapta a cualquier alto del área del mundo (la barra de
  batalla puede crecer).
- En un escenario la cámara arranca ya encuadrada (no hay deslizamiento
  desde el jugador del campo: lo tapa la transición).

### Formación

`BattleLayout.compute` con un escenario, simétrica y sin superposición:
- `gap` del centro al borde interno de cada bando: normal 40, élite 46,
  jefe 52 (`ArenaStage.gapFor`).
- Grupo: jugador `i` en `x = cx + gap + 10 + (i mod 2)·14`,
  `y = 300 + (i − (n−1)/2)·24` (la columna escalonada de siempre) hasta
  4. Con 5 o más (v0.13, `BattleLayout.partyOffset`): dos columnas, la
  de adelante con `ceil(n/2)` y la de atrás 32 px más afuera y 12 más
  abajo, cada una con paso 24 y escalonada 10.
- Enemigos en columnas desde el centro hacia afuera: invocaciones
  pasivas (cristales), comunes (de a 3 por columna, en orden) y el jefe
  atrás. Cada columna se centra en el centro de las cajas del grupo
  (`300 − 8.5`) con paso `max(alto máx + 4 + 4, 26)`; las filas impares
  se corren 14 px hacia afuera (espejo del grupo); entre columnas 10 px.
- Al final todo se corre en `x` para que la caja de la pelea quede
  centrada en el escenario (`x = 480`).
- Garantías (tests): sin cajas superpuestas con 1–4 jugadores (y con
  1, 2, 4, 6, 8 y 12 sin arena, `big_party_ui_test.dart`) y hasta 6
  enemigos, jefe + 2 cristales / 2 siervos, Devorador fase 2 (≈ 90 × 90);
  ≥ 60 px entre bandos; todo adentro del escenario y a la vista con
  1280×418, 1280×300, 1280×220, 960×400 y 1920×780.

### Selección (`selectArena`, pura)

- Escenografía (`ArenaTheme`): la Prueba del Tiempo (`missionId ==
  'trial'`) tiene la suya; si no, el tema del mapa (`GameMap.theme`; un
  Eco usa el de su zona porque su mapa lleva ese tema); si no, la zona
  (1–10); si no, `pueblo`.

  | Arena | Tema / zona | Look |
  |---|---|---|
  | `pradera` | `pradera`, `mundo` · 1 | cielo, nubes, colinas, línea de árboles; pasto con flores; arbustos |
  | `bosque` | `bosque` · 2 | troncos, copas y haces de luz; musgo con raíces; tocones |
  | `ruinas` | `ruinas` · 3 | columnas rotas y un arco; losas partidas con arena |
  | `cavernas` | `cavernas` · 4 | pared de hielo y carámbanos; baldosas heladas con brillo; cristales |
  | `fortaleza` | `fortaleza` · 5 | muro de ladrillo con almenas y troneras; losas; armeros |
  | `laberinto` | `laberinto` · 6 | muro con filetes de bronce y engranajes; losas con bronce |
  | `grieta` | `grieta` · 7 | cielo rojo, agujas de basalto y cascadas de lava; vetas de lava |
  | `cementerio` | `cementerio` · 8 | vacío violeta, luna, lápidas y árboles secos; tierra gris |
  | `abismo` | `abismo` · 9 | vacío con estrellas e islotes; el piso es una isla flotante |
  | `corazon` | `corazon` · 10 | vacío con cristales dorados; losas doradas |
  | `prueba` | Prueba del Tiempo | muro violeta, pilares de plata con relojes de arena; damero |
  | `pueblo` | `lobby` / sin datos | casas con ventanas encendidas; empedrado; faroles |

- Tipo de encuentro (`encounterKindOf`): jefe si `BattleState.boss` o
  algún enemigo es jefe; élite si `BattleState.elite` o algún enemigo es
  élite; si no, normal (además, `SessionBattle.boss` / `.elite`). Son
  datos que ya viajan por la red: **sin cambios de protocolo**.
- Jefe: `bossType` = `enemyType` del primer enemigo jefe; `phase2` si
  su `phase ≥ 2` (el Devorador cambia de arena al transformarse).
- Eco: `missionId == 'eco'` → tinte espectral (cian `#48dbfb` 10% +
  líneas cada 6 px) y motas cian que suben.

### Tipos

- **Normal**: el piso temático con un claro / desgaste elíptico bajo la
  pelea (`300 × 104`); props a los costados.
- **Élite**: tarima rectangular `356 × 124` con borde claro, sombra,
  filete y esquineros dorados; 4 estandartes (color de la zona, ribete
  dorado) en el fondo; 2 braseros con fuego animado en las esquinas de
  atrás; luz de la zona que respira sobre la tarima; viñeta más fuerte.
- **Jefe**: estrado elíptico `470 × 164` con 3 anillos rúnicos y 16
  runas (se encienden de a 3 en ronda cada 160 ms), resplandor de fondo,
  2 pilares con luz, viñeta fuerte y la luz del jefe
  (`kBossArenaLight`). Set-piece por jefe: Rey Limo (chorreaduras y
  charcos de limo), Matriarca (telarañas y sacos de huevos), Gólem Reloj
  (reloj gigante), Sierpe (cristales enormes y cascada helada), Caballero
  Hueco (trono vacío y estandartes rotos), Hechicera (espejos arcanos),
  Bestia de Magma (4 cascadas de lava y foso de lava al frente), Espectro
  Coronado (corona espectral y velas), Centinela (monolito con ojo),
  **Devorador** (vórtice de anillos dorados/violetas con relojes
  flotando y partículas que giran) y **Devorador fase 2** (todo carmesí
  `#d63031`: vórtice rojo más rápido, grietas en el cielo, estrado
  negro-rojo con 9 grietas incandescentes y núcleo que late).
- Las mecánicas de jefe (Campo Helado, lava, cristales, ecos, siervos,
  marca) se dibujan encima de la arena igual que antes sobre el mapa.

### Dibujo y rendimiento

- Todo procedural con `Canvas`, sin antialias y en píxeles enteros del
  mundo (pixel art), con las paletas de tiles de cada zona copiadas en
  `kArenaPalettes` (arte, no `RetroPalette`). Sin assets nuevos (no pasa
  por `SpriteCatalog`).
- **Capa estática** (fondo, piso, tarima/estrado, set-piece, props,
  tinte de Eco, viñeta): se graba una vez por `ArenaSpec.cacheKey` y se
  rasteriza a una imagen `960 × 540` (`toImageSync`); se guardan las 3
  más recientes. Cada frame solo se copia la imagen.
- **Capa animada** (barata): motas del ambiente (hojas, copos, brasas,
  polvo, motas del vacío…; 8–26 + 8 en jefes) × el ajuste
  "Partículas" (`scaledCount`), fuego de braseros, runas, vórtice del
  Devorador y engranaje que gira (laberinto élite/jefe).

### Transición

- **Entrada** (escena de batalla): al empezar cada batalla
  (`BattleSceneController.enteredAt`), destello blanco 120 ms (alfa
  0.55 × ajuste "Destellos") y un fundido de bloques `#05060c` de
  `round(8·s)` px (6–24) que se van en 420 ms (`easeOut`; umbral por
  bloque: 65% ruido fijo + 35% barrido de izquierda a derecha), encima
  de todo (franja, mundo y HUD).
- **Vuelta al mapa** (`BattleExitWipe` en `WorldScreen`): cuando la
  sesión sale de `SessionMode.battle`, los mismos bloques tapan la
  pantalla y se van en 420 ms descubriendo el mapa. No toma clics.

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
     las cinemáticas: píxel perfecto; con ESCALADO en PIXEL PERFECT
     también en transiciones y cinemáticas, settings.md § 3.1);
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
- **En la sesión ya no se usa el mapa**: la batalla va en una arena
  propia con su formación (§ "Arenas" → "Formación"). Las reglas de
  arriba quedan para `BattleArena` sobre un mapa (tests, herramientas).
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
  antes), arriba del sprite; debajo, la **barra de quiebre** (§
  "Quiebre"), la **carga de ULT** (jefes y élites) y, quebrado, el chip
  `VULNERABLE`; alto `(15 + 4 + 3 + 12)·u` según tenga cada parte;
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
- turno: barra `#ff4757` de 20×2 en `(x − 10, y + 3)`;
- avisó su ULT (`ultPending`): aura roja `#ff3355` que late detrás y
  dos anillos que suben, y el sprite teñido de rojo (latiendo);
- quebrado (`broken` o `breakSkip`): 3 estrellitas (amarilla / blanca)
  que giran sobre la cabeza;
- `windup`: se echa 3 px hacia atrás y se tiñe de rojo hasta lanzarse.

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

### Identificador de repetidos, élite y vínculo con la arena (v0.13.1)

Con dos o más combatientes del mismo tipo no se sabía qué ícono era cuál.

- Letra estable por batalla (`Combatant.tag`, asignada por el motor con
  `assignCombatantTags`, ver combat.md § "Inicio de batalla"): A, B, C…
  (más de 26: números). Enemigos por tipo (`enemyType`, el élite cuenta
  como de su tipo), aliados por nombre, invocaciones por tipo. Si el
  tipo no se repite, sin letra. El nombre lleva la letra al final
  ("Lobo B", "Lobo Élite A", "Héroe B"), así aparece igual en la arena,
  la caja del objetivo, los logs y las tarjetas.
- Arena: la vida del enemigo va precedida por su letra en blanco
  (`B 60/60`).
- Franja: la letra, en blanco 6 px sobre un cuadro negro 8×8 en la
  esquina de abajo a la derecha del ícono.
- Élite: borde `#ffd166` y un segundo filete dorado 1 px por fuera, con
  `★` 6 px dorada arriba a la izquierda. Jefe: mismo borde con una
  corona dorada de tres puntas arriba a la izquierda.
- Mouse: sobre un ícono de la franja o sobre un enemigo de la arena, ese
  actor queda señalado en las dos (`SceneFrame.hoverId`): en la franja
  con un filete blanco por fuera del ícono; en la arena con el
  marcador del objetivo (se suma a `highlightIds`; aliados, con el
  marcador de turno). El objetivo elegido y los que tocaría la
  habilidad llevan una raya roja 2 px bajo su ícono (salvo el primero,
  que ya tiene el triángulo). Los cuadros salen de
  `BattleScenePainter.timelineSlots`, que la pantalla usa también para
  saber qué ícono está bajo el mouse.
- Caja del objetivo (`TargetBar`): el élite o el jefe llevan borde
  dorado (`DsColors.reward`) y `DsTag` `★ ÉLITE` / `JEFE`.

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
en los eventos de la acción); en un dúo, el impacto de su guion
(`kDuoScript.impactFor(i)`, § "Dúos"); 0 si no.

| Evento | Efectos (`addFx` del prototipo) |
|---|---|
| `ActionEvent` ataque | `act`; a distancia: `proj` blanco `phys`; Golpe Imparable (todos): `ring` blanco en el atacante |
| `ActionEvent` habilidad / ULT | `act`; daño a todos sin ULT: `ring` del color de la habilidad; a distancia o mágica: `proj` por objetivo |
| `UltimateUsedEvent` | `ult` (cinemática) con nombre, color, elemento y guion de la ULT del arma, y la lista de objetivos (ids de los `DamageEvent` de la acción en orden; en Baluarte, los de los `HealEvent`) |
| `ActionEvent` ULT | `act` con retraso = fin de la preparación (el lanzador se lanza al descargar); ni anillo ni proyectiles |
| `DamageEvent` en una ULT | como un golpe a enemigo, con el `dl` del impacto, `num` **pesado** (`heavy`: grande y con rebote); crítico: además `flash` blanco con el mismo `dl` |
| `HealEvent` en una ULT (Baluarte) | `num` `+n` pesado y `aura` sagrada con el `dl` del impacto en ese aliado |
| `KnockedOutEvent` de enemigo en una ULT | `poof` con el `dl` del impacto en él |
| `ActionEvent` dúo | v0.8.3: `ult` (cinemática de dúo, § "Dúos") con nombre, color y elemento del dúo, compañero y armas; `act` de los dos al descargar (el compañero +40 ms); `ring` grande en el punto medio al descargar. Sin `proj`: las estelas son de la cinemática |
| `DamageEvent` en un dúo | como en una ULT (`num` pesado en el impacto del guion) + `txt` `×2 DÚO` del color del dúo sobre cada golpeado |
| `ActionEvent` Fortaleza | `txt` `DEF +n` `#74b9ff` en `y−30`, `aura` maná |
| `ActionEvent` Protección | `ring` grande `#ffeaa7`, `aura` sagrada en los otros aliados vivos |
| `ActionEvent` Provocar | `txt` `¡PROVOCA!` `#ff7675` en `y−30`, `ring` grande `#ff7675` |
| `ActionEvent` Escudo de Fe | por aliado vivo: `txt` `ESCUDO` `#74b9ff` en `y−30`, `aura` sagrada |
| `ActionEvent` Prisa | por otro aliado vivo: `txt` `¡PRISA!` `#ffd166` en `y−26` |
| `ActionEvent` enemigo | `windup` (se echa atrás, § "Ataque enemigo") y `act` a los 100 ms; Colapso Temporal: `flash` `#e84393` y `ring` grande `#e84393` en `(x, y−10)` en el golpe (160 ms) |
| `DamageEvent` a enemigo | `num` en `y−20` (`#ffd166` 12 px si crítico, si no `#ffffff` 8 px) con `dl`; crítico: `txt` `¡CRÍTICO ×cm!` `#ffd166` en `y−34`; `slash` en `(x, y−8)` del color y elemento de la acción |
| `DamageEvent` a jugador | con el golpe del enemigo (`dl` = 160 ms; en su ULT, el impacto del guion): `num` en `y−18` (`#ff4757` 12 px crítico, si no `#ff6b81`; pesado en una ULT), `hurt`; `slash` `#ff6b81` (en una ULT, de su color) con el elemento del estado que inflige el enemigo; crítico: `txt` `¡CRÍTICO ×1.5!` `#ff4757` en `y−34`; perforante: `txt` `¡PERFORANTE ×m!` `#ff9f43` en `y−44`. Sus estados, `K.O.` y el escudo que absorbe usan ese mismo `dl` |
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
| `slash` | 220 | dos trazos de 2 px: `(x−10+4p, y−10)→(x+10−4p, y+10)` y `(x+10, y−10+4p)→(x−10, y+10−4p)`, `p = a/220`. Según el arma del atacante (`slashStyleFor`): `lanza` = estocada horizontal de `14 + 10p` px a cada lado, trazo `3 − 2p`, con punta blanca 3×3; `dagas` = dos cortes paralelos de 18 px, el segundo 0.4 después |
| `proj` | 280 | de `(x, y−10)` del atacante a `(x, y−10)` del objetivo, arco de 10 px (`− sin(pπ)·10`); `phys`: trazo blanco de 1.5 px y 7 de largo; otro elemento: 5 círculos de estela (radio `3.5 − 0.5i`, alfa `(1 − i/5)·0.8`, retraso `0.05i`) + núcleo blanco radio 1.5. Según el arma (`projStyleFor`): `ballesta` = virote recto (sin arco) `#dfe6e9` de 2 px y 9 de largo, punta `#ff9f43`, plumas `#d63031`; `varita` = misil arcano: rombo `#a29bfe` de 3×4 que zigzaguea (`sin(18p)·3` px) con 3 chispas del color |
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
viejas). El ajuste PARTÍCULAS (settings.md § 3.3) multiplica `n` y el
máximo por 0.3 / 0.6 / 1 (`ParticleSystem.density`, al menos 1). Cada frame (`dt` ≤ 0.05 s): `vy += g·dt`, `x += vx·dt`,
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

## Saltos (rebote, atraviesa, ráfaga)

Pedido del dueño (v0.5.1): que se vea que las habilidades saltan de un
enemigo a otro, golpe por golpe, rápido pero notorio. Código:
`lib/features/combat/presentation/scene/chain_fx.dart` (`ChainPlanner`
puro + `ChainFxPainter`); tests `test/features/combat/chain_fx_test.dart`.

- **Eventos** (aditivo, sin cambiar `kProtocolVersion`): el
  `DamageEvent` lleva `hitIndex` (golpe `i` de una ráfaga `SkillDef.hits`,
  0 = el primero; JSON `hi`), `chainFrom` (rebote `SkillDef.bounces`: de
  quién salta; JSON `cf`) y `pierced` (atraviesa `SkillDef.pierce`; JSON
  `pc`). Solo viajan si no son el valor por defecto; un cliente viejo
  los ignora. El motor ya emitía los golpes en orden: primario, ráfaga,
  atraviesa (fila de atrás) y rebotes.
- **Rebote**: cada salto es un `hop` de `ChainTiming.hopMs = 140` ms que
  sale del enemigo anterior cuando le llega el golpe y vuela en arco
  (alto 14–28 px) con estela del color de la habilidad: daga que gira
  (dagas y otras armas físicas), flecha (arco, ballesta, rifle) o rayo de
  energía (magia). Al llegar: número, tajo y contador `×2`, `×3`… dorado
  (`y − 40`). Con "Reducir movimiento" la daga no gira y el rayo no late.
- **Atraviesa**: `streak` (línea blanca con halo, 90 ms de avance,
  visible 220 ms) del objetivo al de atrás y de ahí al siguiente; el
  número de cada uno cae al llegar la estela, con su `×N`.
- **Ráfaga**: los golpes `i ≥ 1` al mismo objetivo caen cada
  `min(90, 600 / (hits − 1))` ms y cada número sale 7 px más arriba que
  el anterior (no se pisan).
- Todo lo encadenado termina a más tardar `ChainTiming.maxMs = 600` ms
  después del golpe primario. Los rebotados ya no reciben un proyectil
  propio desde el lanzador. La estela respeta "Partículas"
  (`scaledCount(8)`).
- Los rebotes del árbol (`rebote`, `corteCadena`, `arcoVoltaico`) ya
  saltaban con `arc` (§ "Disparadores del árbol"); **Arco Dormido**
  (pasiva única de la varita) se suma a `kChainMechanics` (violeta
  `#a29bfe`, arcano).

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
| Lluvia de Lanzas | `lanza` | 800 | 1100 | 400 | 2300 | 1300 + 80·i | 90 | 10 |
| Tormenta Arcana | `varita` | 800 | 1200 | 400 | 2400 | 1350 + 60·i | 90 | 9 |
| Andanada | `ballesta` | 900 | 900 | 400 | 2200 | 1300 (virotes chicos 1130-1310, solo visuales) | 150 | 13 |
| Danza de Mil Cortes | `dagas` | 700 | 1100 | 400 | 2200 | 1500 (cortes previos 950, 1030, …, 1420) | 130 | 11 |

Las 4 ULT de los tipos de loot v2 viven en `kNewUltimates`; la UI (menú,
cinemática, colores, sonido) lee `kAllUltimates`, así que funcionan sin
moverlas a `kUltimates`. Cámara: Andanada en la línea lanzador–objetivo
(como Disparo Letal), Danza de Mil Cortes en el objetivo (zoom base + 1),
las otras dos en los objetivos.

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

- **Lluvia de Lanzas** (rosa `#ff6b81`): preparación — líneas que
  convergen, la lanza gira sobre la cabeza del lanzador cada vez más
  rápido (anillo rosa), y a los 520 ms siete lanzas salen al cielo en
  abanico (sacudida 3). Descarga — cada 90 ms una lanza decorativa cae en
  diagonal alrededor de los objetivos y queda clavada (polvo, sacudida
  1.5); en el impacto de cada objetivo llegan tres lanzas grandes (40 ms
  entre sí, con estela rosa) que quedan clavadas hasta el regreso, anillo
  rosa en el piso y destello blanco; `burst phys ×3` + escombros + polvo.
- **Tormenta Arcana** (magenta `#e84393`): preparación — sello arcano que
  gira bajo el lanzador (dos elipses y 6 runas cuadradas), runas que
  suben, estrella creciente en la punta de la varita; en los últimos
  250 ms se forma una nube violeta oscura con arcos que giran sobre los
  objetivos. Descarga — cada 90 ms un rayo quebrado violeta cae de la
  nube cerca de un objetivo (`burst arc ×0.5`, sacudida 1.5); en cada
  impacto un rayo grueso magenta + anillo, `burst arc ×4`, chispas y
  destello.
- **Andanada** (naranja `#ff9f43`): preparación — mira de cuatro
  esquinas que se cierra sobre el objetivo (250 ms → fin), brillo en el
  virote tenso. Descarga — fogonazo (sacudida 6), cuatro virotes chicos
  en abanico que convergen (impactan a 1130, 1190, 1250, 1310: chispas y
  sacudida 3), el virote grande acelera hasta el impacto con estela y
  ondas, y en 1300 explosión (disco crema + anillo naranja), virote
  clavado y tres estrellitas de mareo que giran (Aturdido).
- **Danza de Mil Cortes** (menta `#55efc4`): preparación — viento menta
  que se arremolina alrededor del lanzador, destello de las dos hojas al
  desenvainar (420-660). Descarga — embestida con 6 imágenes hasta el
  objetivo, siete cortes finos en ángulos distintos (950-1420, chispas y
  sacudida 3 cada uno), remolino de hojas verdes alrededor del objetivo
  y el final en 1500: un tajo horizontal que cruza la vista + estrella de
  ocho cortes y anillo blanco.

### Nuevos pasos durante la cinemática

La escena nunca frena a la sesión. Si llega un paso nuevo con la
cinemática en preparación o descarga, sus efectos **esperan en cola** y
arrancan al empezar el regreso (con la hora de ese momento). Si se juntan
2 o más pasos en cola, la cinemática se **adelanta**: salta al regreso y
los efectos pendientes de la ULT (números, etc.) arrancan ya. Otra
batalla limpia todo. El cartel de victoria/derrota espera a que termine
la cinemática.

## Dúos (v0.8.3)

Todos los dúos (de clase y de armas, combat.md § "Dúos") tienen una
cinemática corta que usa la tubería de las ULT (`FxKind.ult`,
`UltCinematic`, cámara, oscurecido, hit-stop, cola de pasos) con el
estilo `UltStyle.duo` y su guion (`duo_cinematic.dart`):

| Guion `kDuoScript` | ms |
|---|---|
| Preparación (`buildMs`): entran los dos retratos y el cartel | 0–650 |
| Descarga (`releaseMs`): dos estelas convergen | 650–1300 |
| Impacto en el objetivo `i` (`impactFor(i)`) | 1000 + 50·i |
| Hit-stop en el último impacto | 90 |
| Sacudida (`shake`) | 9 (×0.6 en los demás) |
| Regreso (`returnMs`) | 1300–1600 |
| Total | 1600 |

**Tarjeta partida** (`BattleOverlayPainter._duoCard`, capa pixelada
2u, `duoCardPose(a, reduceMotion)`): banda de arriba con quien hace el
dúo (entra desde la izquierda en 260 ms, sprite ×2.5, nombre y tipo de
arma), banda de abajo con el compañero (desde la derecha, 60 ms más
tarde, sprite espejado mirando al centro) y, entre las dos, el cartel
`DÚO · <NOMBRE>` (fondo negro, filetes del color del dúo, texto dorado
16, aparece de 180 a 360 ms). La tarjeta se va con un fundido de 200 ms
y desaparece a los 800 ms.

**Mundo** (`UltDirector._duo`): carga (`_gather`) en los dos; desde la
descarga, dos estelas (curvas cuadráticas: la de quien lo hace arquea
hacia arriba, la del compañero hacia abajo) con cabeza blanca + estrella
del color del dúo, que avanzan con `duoTrailProgress` (aceleran) y
llegan al centro de los objetivos en el impacto; ahí, cruz de luz (un
brazo blanco y otro del color), anillos que crecen 360 ms y estrella en
cada objetivo; después, un óvalo del color del elemento bajo cada
objetivo que se apaga hasta el fin del regreso. Partículas del elemento
del dúo (las de su estado) en las cargas y en cada impacto.

**Pantalla**: barras de cine y oscurecido como una ULT; destello del
impacto blanco teñido 35 % del color del dúo (× DESTELLOS). Números de
daño pesados + `×2 DÚO`.

**Ajustes**: REDUCIR MOVIMIENTO → la tarjeta no se desliza (las dos
mitades ya están en su lugar, fundido de 150 ms, sin líneas de
velocidad) y la cámara no hace zoom (como en las ULT). SACUDIDA apagada
→ sin sacudida; DESTELLOS escala el destello; PARTÍCULAS escala las
motas.

**Saltear**: un clic / toque en la escena durante la preparación o la
descarga la saltea (`BattleSceneController.skipDuo`: salta al regreso,
los golpes pendientes caen ya, sin hit-stop). Con 2 pasos en cola se
adelanta sola (§ "Nuevos pasos durante la cinemática").

**Sonido**: `dual.rise` al empezar, `flash` + `dual.cast` al descargar,
`dual.clash` en el impacto (audio.md).

**Menú DÚOS**: una fila por dúo disponible (por aliado vivo: el de clase
si lo hay y los de armas de su par): `★ <dúo> (+<aliado>)`, la etiqueta
del par (`[Guerrero + Maga]` azul para los de clase, `[arco + báculo]`
dorada para los de armas), daño estimado a todos y el estado; costo
`4 MP c/u`. La descripción dice si es de clase o de armas, los dos
nombres, el par, el elemento, la fórmula y el estado. Ids:
`duo-<aliado>` el de clase (como antes) y `duo-<aliado>-<id>` los de
armas.

| Dúos de armas | Armas | Elemento |
|---|---|---|
| Flecha Arcana Gemela | arco + báculo | Electro |
| Bastión Rúnico | espada+escudo + tomo | Sagrado |
| Fuego Cruzado Letal | dagas + rifle | Fuego |
| Terremoto Doble | hacha + martillo+escudo | Físico |
| Saeta Voltaica | varita + ballesta | Electro |
| Juicio Perforante | lanza + maza+escudo | Sagrado |
| Filo Ígneo Arcano | espada + varita | Fuego |
| Hoja Maldita | tomo + dagas | Veneno |
| Tajo Glaciar | hacha + báculo | Hielo |
| Diluvio de Astas | lanza + arco | Agua |

## Ataque enemigo (wind-up)

Pedido del dueño: ataques enemigos con más peso. Cada `ActionEvent`
enemigo (`enemyAttack`, `enemyHeavy`, `enemyArea`) arranca con un
`windup` de 160 ms (el enemigo se echa 3 px atrás y se tiñe de rojo),
el `act` (estocada) a los 100 ms y el **golpe a los 160 ms**
(`BattleFx.enemyStrikeMs`): números, tajos, estados, `K.O.`, la grieta
del escudo y el sonido del impacto (docs/specs/audio.md) caen ahí. Los
procs de una acción enemiga usan esa hora como golpe (`base` = 160 +
120).

## Quiebre

(docs/specs/break_and_enemy_ults.md § 1.)

- **Barras** (HUD, bajo la vida del enemigo, mismo ancho): quiebre
  amarillo `#ffe14d` de 3·u (brillo `#fff7c2` de 1·u arriba) sobre
  `#000000cc`; quebrado queda llena y **parpadea** blanco / amarillo
  cada 110 ms. Carga de ULT (solo jefes y élites): 5 segmentos rojos
  `#ff3355` de 2·u (se distingue de la vida roja del jefe), que
  parpadean en blanco cada 150 ms con la ULT avisada.
- **Chip `VULNERABLE`** (8·u) centrado bajo las barras mientras está
  quebrado: caja negra con filetes amarillos y el texto que alterna
  amarillo / blanco cada 220 ms.
- `BreakEvent(broken)`, en el `dl` del golpe que lo quebró (o del
  efecto secundario): `shatter` (650 ms: destello `#fff7c2` 110 ms,
  8 grietas en zigzag que se abren en 120 ms, 12 esquirlas triangulares
  amarillas / blancas que salen girando y caen, anillo `100p × 50p`);
  al activarse astillas de cristal (`kBreakShardFx` × 2.2), sacudida 7
  y **hit-stop de 80 ms**; `flash` de pantalla `#fff7c2`; cartel grande
  `¡QUIEBRE!` (`tag` big, `#ffe14d`, pop y contorno) sobre el cuerpo 60
  ms después; si canceló la ULT avisada, `txt` `ULT CANCELADA`
  `#ff4757` en `y−60` 250 ms después.
- Golpes a un quebrado (`DamageEvent.vulnerable`): número amarillo
  grande y tajo amarillo; `QUIEBRE ×1.5` en `y−44` la primera vez en el
  paso.
- `BreakEvent(skipped)`: `txt` `¡QUEBRADO!` amarillo en `y−34` + `aura`
  de aturdido. `recovered`: `txt` `SE RECUPERA` gris en `y−40`. `fill`
  y `decay` no dibujan nada (las barras ya lo muestran).
- Barra de batalla: la cabecera del menú dice `Objetivo: Rey Limo ·
  Quiebre 31/80` (o `¡VULNERABLE! ×1.5`, y `¡ULT!` si la avisó).

## ULT enemigas

(docs/specs/break_and_enemy_ults.md § 2.)

- `EnemyUltWarningEvent` → `warn` (2000 ms, pantalla): banda negra a
  todo el ancho arriba del área del mundo con filetes rojos y franjas
  de peligro que corren, triángulos `!` que titilan a los costados y el
  texto `¡El Rey Limo se prepara para Diluvio Ácido!` (16·u con
  contorno si entra, si no 8·u); entra desde la izquierda en 180 ms y
  se apaga los últimos 300 ms. Además `pulse` rojo doble en el enemigo
  (el aura persistente la dibuja el estado).
- `EnemyUltEvent` → la misma cinemática que las ULT del grupo (`ult`
  con `UltFx.enemyType`): oscurecido, tiempo congelado, barras de cine,
  cámara al lanzador y después al grupo, hit-stop y destello (rojo
  `rgba(255,70,80)` 0.55 en vez de blanco). Tarjeta: banda roja oscura,
  el sprite del enemigo (× `min(3, 40/alto)`), `! ULTIMATE ENEMIGA ·
  Rey Limo` en amarillo y el nombre. Los golpes al grupo son números
  pesados en `impactFor(i)` (orden de los eventos); estados, `RETRASO`
  (Engranaje del Fin) y `K.O.` con ellos; `BUFFS BORRADOS` violeta en
  `y−56` de cada aliado 120 ms después del último impacto (Fin de las
  Eras). El enemigo se lanza al descargar.

| ULT | Prep. | Descarga | Total | Impacto `i` | Hit-stop | Sacudida | Cámara |
|---|---|---|---|---|---|---|---|
| Diluvio Ácido | 900 | 1100 | 2400 | 1380 + 70·i | 90 | 10 | `group` |
| Engranaje del Fin | 900 | 1000 | 2300 | 1400 | 130 | 12 | `single` |
| Fin de las Eras | 1000 | 1100 | 2500 | 1500 + 60·i | 140 | 14 | `group` |
| Furia Élite | 700 | 900 | 2000 | 1150 (zarpazos previos 1000, 1070) | 120 | 12 | `single` |

Cámara `group` (ULT a todo el grupo, que está en columna): en la
descarga, centro `(x del centro de los objetivos, y de la base)` y zoom
`base − 1` (mínimo 1), para que entren todos con sus números entre las
barras de cine.

- **Diluvio Ácido** (verde `#7bed9f`): preparación — el limo se hincha
  (membrana translúcida que tiembla), burbujas que suben, cielo verdoso.
  Descarga — escupe una bola de ácido en arco hasta arriba del grupo
  (900-1150), revienta en una nube oscura sobre todos, llueve ácido
  (36 gotas) y en cada impacto salpicón + charco que queda.
- **Engranaje del Fin** (bronce `#e1b12c`): preparación — un engranaje
  gigante (12 dientes) gira a saltos de reloj detrás del gólem.
  Descarga — sale rodando en arco con estela de hielo y aplasta al
  objetivo (1400): cristales de hielo lo encierran, anillo; después una
  onda de tiempo (anillos celestes) pasa por todo el grupo (retraso).
- **Fin de las Eras** (carmesí `#d63031` / violeta `#6c5ce7`):
  preparación — un vórtice negro con arcos que giran se forma delante
  del Devorador, polvo y brasas caen en espiral hacia él, el cielo se
  pone rojo, temblor creciente. Descarga — viaja sobre el grupo y crece,
  colapsa con un destello y bajo cada objetivo (grietas incandescentes
  antes) estalla una columna de fuego; astillas violetas (los buffs que
  se rompen) salen volando.
- **Furia Élite** (rojo `#ff4757`): preparación — llamas rojas alrededor
  del cuerpo y brillo en los ojos. Descarga — embestida con imágenes
  rojas hasta el objetivo, dos zarpazos (3 trazos paralelos) y el final
  enorme con anillo en el impacto (crítico garantizado).

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

## Barra de batalla (v0.5)

Pedido del dueño (captura a Muy grande: "el layout de la UI de las
habilidades como que no mucho") y bugs de jugadores de v0.4 ("se corta
la letra", "el tooltip a veces se abre el de otra habilidad"). Estructura
tomada de una referencia de JRPG (no su arte): ventana de comandos de 3
columnas + barra del grupo. Reemplaza al panel "mis datos" de la
izquierda, al menú numerado 1-9 en grilla de 2-3 columnas con "Más ▸" y
a la lista compacta del grupo de la derecha.

**Alto**: `BattleViewState.barHeight(h, factor)` = 42 % del alto (+8 %
por cada punto de agrandamiento del texto, hasta 62 %); la escena usa
el resto (los sprites son chicos). En 1280×720 Normal: 302 px.

**Ventana de comandos** (`BattleCommandWindow`,
`lib/features/combat/presentation/battle_command_window.dart`), solo en
el turno propio (co-op: cada uno ve sus comandos):

1. **Categorías**: ATACAR (Atacar + "Liberar a
   X" si hay telaraña) · HABILIDADES (técnicas, con la cantidad) · DÚOS
   (si hay) · ULTIMATE (gris hasta el 100 %, con el %) · OBJETOS (las dos
   pociones; elegir una abre "¿A quién le das...?" con el grupo) ·
   DEFENDER · PASAR (v0.8.3, siempre la última: una acción "Pasar turno"
   con costo `próximo ×½` y la descripción "Terminás el turno sin actuar;
   tu próximo turno llega antes..."; combat.md § "Pasar turno"). Vale
   igual en el turno manual de un compañero (solo_party.md); el AUTO
   nunca pasa.
2. **Acciones** de la categoría: una fila por acción — tecla (1-9), nombre,
   la cifra principal (daño estimado, cura) y el costo a la derecha
   (`4 MP`, `x2`, `45%`). El crítico y los efectos van a la descripción.
   Desde v0.12 (design_system.md § 10.3) las filas son `DsListRow` de una
   línea: en las habilidades la cifra pasa al resumen del detalle y la
   fila lleva `INSTANTE`, el alcance (`1 ENEMIGO`, `TODOS`...) y el costo
   `DsCost` (`4 MP` azul, `2 P` dorado, rojo si no alcanza). En el detalle
   se ve el resumen de una línea; el resto, plegado en MÁS.
   El nombre baja de línea antes que cortarse (nunca se recorta). Con más
   de 9 acciones en una categoría se pagina (`battleMenuPage`, "Más ▸" /
   "← Volver"); con las pociones en OBJETOS ningún kit actual pagina.
3. **Descripción** de la acción elegida (`describeSkillMarkup` /
   `variantEffectLines` de la técnica), el motivo si está deshabilitada,
   `Objetivo: Limo 71/71 HP · Quiebre 0/59`, las mecánicas del jefe y las
   teclas; arriba, en una sola fila, quién actúa a la izquierda
   (`¡Tu turno! <nombre>` / `Turno de <nombre> (compañero)`,
   `ValueKey('battle-actor')`) y `MP 22/22 · ULT 45%` a la derecha. Desde
   v0.8.3 el nombre ya no va arriba de las categorías: con PASAR son 7 y a
   1280×720 Normal no entraban (un nombre de compañero en dos líneas
   dejaba PASAR fuera de la vista).

**Teclado**: 1-9 eligen la acción N de la lista que se ve; ↑/↓ mueven la
elegida; ←/→ cambian de categoría; Enter/Espacio confirman; Q/Tab
cambian de objetivo (y clic en el enemigo); **P** (v0.8.3) va a PASAR y,
con PASAR ya elegida, otra P pasa el turno (dos toques: una tecla suelta
no hace perder el turno; Retroceso no se usa porque cierra los avisos del
HUD, y la P del panel PARTY solo vale fuera de batalla); Esc sale de "¿a
quién?" o de una página > 1 (si no, abre la pausa). El mouse sobre una
fila la elige. Las teclas de la descripción terminan en `· P: pasar`.

**Tooltip equivocado (bug de v0.4)**: las filas ya no tienen tooltip; la
descripción sale de la acción elegida en el momento. Cada fila se arma
con `ValueKey('battle-act-<id>')` (id estable: `skill-<id>`, `duo-<aliado>`
y `duo-<aliado>-<dúo de armas>` (v0.8.3),
`attack`, `potion`, `give-<id>`...), así Flutter nunca reutiliza la fila
de una técnica para otra, y el menú vuelve a ATACAR con la primera acción
elegida en cada turno nuevo, al actuar o al perder el turno. Los
tooltips (`RetroTooltip`) leen su mensaje del widget actual al dibujarse.

**Barra del grupo** (`BattlePartyBar`, `battle_hud.dart`): una tarjeta
por jugador, lado a lado: sprite, nombre y `Lv` (baja de línea, no se
corta), turno corto (`▶ 25s` el que actúa, `T+3`, `K.O.`), HP y MP con
números (ULT en la propia) y los chips de estado. Borde dorado la del
turno. La propia (`my-panel-<id>`) tiene en su tooltip el detalle que
antes ocupaba el panel izquierdo (arma, ATQ/MAG/DEF, crítico, VEL); las
demás son `member-<id>`.

**Objetivo** (`TargetBar`): arriba a la izquierda de la escena, nombre,
HP con números y quiebre (`QB`, `¡ROTO!`), `¡ULT!` si la avisó.

**Banda del log** (`TÚ 25s` y el log): queda en la escena con su tamaño
(no crece con el ajuste: es parte del encuadre de 16 px virtuales). La
franja de turnos del canvas no cambia.

Tests: `test/features/combat/battle_screen_test.dart` (categorías, ←/→
↑/↓ Enter, pociones a quién, la descripción nunca es la de otra técnica
cuando el menú cambia bajo el mouse, tarjetas del grupo, PASAR: clic,
P + P, Enter, sin turno no hace nada), `test/features/world/
solo_party_ui_test.dart` (el compañero manual pasa: `IV × 0.5`, sin ULT),
`battle_menu_paging_test.dart` (paginado puro y Guardián de 8 técnicas
sin paginar), `test/app/text_size_test.dart` (cada categoría, a quién y
las técnicas de nombre más largo sin desbordes en los tres tamaños).

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

## Mecánicas de jefe

(docs/specs/bosses.md § "v0.2".)

- **Cartel de entrada** (`BossIntro`, 2600 ms, capa de pantalla
  `BattleOverlayPainter`): al abrir una batalla de jefe, banda negra a
  todo el ancho al 30% del alto del mundo con filetes dorados, el sprite
  del jefe (× `min(2, 50/alto)`) que entra deslizándose, `! JEFE !`
  (rojo/dorado alternando cada 160 ms), el nombre en 16·u con contorno y
  el título (`EnemyDef.title`) en crema. Entra en 260 ms y se apaga los
  últimos 400. Con su sonido `boss.intro` (`BattleStartedEvent` de jefe).
- **Telaraña**: el héroe atrapado lleva una tela radial (6 rayos + 3
  anillos), un capullo blanco que late y el hilo que cuelga. `webCast` →
  `¡TELARAÑA!` blanco en `y−50` y anillo, con el golpe (`enemyStrikeMs +
  60`; en Nido Venenoso, después del último impacto); `webFreed` →
  `¡LIBRE!` verde + anillo + aura; `webSkip` → `¡ATRAPADO!` + aura de
  aturdido; `webStruggle` → `FORCEJEA ½`.
- **Campo Helado**: con el grupo ralentizado el mapa se tiñe de celeste
  (`0.10 + 0.30 × lentitud`) y caen copos (20 + 60 × lentitud); de cada
  cristal vivo sube un hilo de partículas de escarcha a la Sierpe; los
  cristales tienen un brillo celeste. Los cristales se ubican delante del
  jefe, entre él y el grupo (`BattleLayout`, `(30, −22)`, `(30, 24)`).
  `frost` → `VEL −N%` celeste en cada aliado + aura de hielo y pulso en
  la Sierpe; `thaw` → `DESHIELO` verde; `shatter` → estallido de
  cristal + `CRISTAL ROTO`; `reform` → aura de hielo + `SE REFORMA`.
- **Postura**: aura del color de la postura detrás del Caballero (azul
  `#74b9ff` escudo, rojo `#ff6b6b` espada, gris quebrado) e ícono 7×9
  (escudo o espada) arriba a la derecha; con `stanceTurns` 1 titila un
  `!` del color de la próxima postura. `stanceShift` → cartel grande
  `POSTURA: ESPADA` en su color + pulso; `resisted` → `BLOQUEA −70%` gris
  con el golpe.
- **HUD**: fila de chips de mecánica arriba del menú y del panel de
  espera (`bossMechanicChips`): `Telaraña · N atrapados`, `Campo Helado:
  N cristales · VEL −X%`, `Postura ESCUDO −70% físico · cambia en N
  turnos` (gris "rota" si está quebrado), cada uno con tooltip de cómo
  contrarrestarla (`BossMechanicDef.counter`). Chip `Telaraña` en el
  atrapado y `▼VEL −X%` (Campo Helado) en los ralentizados. El menú
  agrega `Liberar a X (telaraña, ½ turno)` por cada aliado atrapado. La
  franja de turnos no muestra los cristales y cuenta los efectos de
  velocidad.

### ULT de los jefes v0.2

| ULT | Prep. | Descarga | Total | Impacto `i` | Hit-stop | Sacudida | Cámara |
|---|---|---|---|---|---|---|---|
| Nido Venenoso | 900 | 1100 | 2400 | 1350 + 70·i | 100 | 10 | `group` |
| Aliento Glacial | 1000 | 1100 | 2500 | 1420 + 60·i | 120 | 12 | `group` |
| Juicio Hueco | 900 | 1000 | 2300 | 1400 | 160 | 15 | `single` |

- **Nido Venenoso** (violeta `#9b59b6` / verde): preparación — hilos
  tendidos desde la Matriarca, sacos de huevos verdes que laten, bosque
  violáceo. Descarga — escupe una telaraña que vuela en arco girando y
  abriéndose, cae sobre todo el grupo y gotea veneno; en cada impacto
  charco y anillos verde/violeta.
- **Aliento Glacial** (cian `#9ff3ff`): preparación — copos que entran en
  espiral a las fauces y un núcleo blanco que crece, niebla fría.
  Descarga — cono de aliento de las fauces al grupo con vetas blancas;
  cristales que encierran a cada objetivo y anillo.
- **Juicio Hueco** (cian `#6ff7ff`): preparación — runas que giran
  alrededor del Caballero y destello en los ojos. Descarga — una espada
  espectral se forma sobre el objetivo y cae; cruz de luz, onda y grietas
  en el piso.

## Mecánicas de jefe v0.3

(docs/specs/bosses.md § "v0.3".) Tests:
`test/features/combat/boss_mechanics_v03_fx_test.dart`.

- **Ecos** (Hechicera): cada `Eco de la Hechicera` se dibuja
  translúcido (alfa `0.55 + 0.3·sin`), con dos copias cian corridas ±2 px
  que se abren y cierran (se desdobla) y una franja de luz que lo
  recorre de arriba abajo. `echoSummon` → arco cian del jefe al eco,
  `poof`, anillo y `¡ECO!`; `echoResist` → `ECO ×0.5` cian con el golpe.
  Quebrarla: `shatter` sobre el eco (como el cristal).
- **Lava** (Bestia): con `Combatant.lava > 0`, charcos de lava (corteza
  oscura, borde naranja `#ff7b29`, centro amarillo que late) bajo cada
  aliado y tres chicos entre el jefe y el grupo, con burbujas que
  revientan y brasas que suben; brillo de lava bajo la Bestia.
  `lavaRise` → `lavaBurst` (columna de lava que sube y cae en gotas, 700
  ms, partículas de escoria y sacudida 3) bajo cada aliado después del
  golpe (`enemyStrikeMs + 220`; en Erupción Total, después del último
  impacto) y cartel grande `¡LAVA N TURNOS!`; `lavaBurn` → `lavaBurst`
  en el que se defendía, aura de fuego y `¡LAVA! Q+2`; `lavaFade` → `LA
  LAVA SE ENFRÍA` gris.
- **Séquito** (Espectro Coronado): mientras viva un siervo, el Espectro
  lleva un escudo de inmunidad (óvalo `#b8c6ff` que titila y 6 runas
  doradas que giran) y de cada siervo sube un hilo de motas doradas
  pálidas al jefe (como los cristales). `summon` → arco, `poof`, anillo y
  `¡SIERVO!`; `immune` → pulso y `INMUNE` sobre el jefe con el golpe.
- **Marca del Vacío** (Centinela): el héroe marcado lleva una columna
  violeta tenue y una retícula `#b57bff` que gira sobre la cabeza.
  `markCast` → arco violeta del Centinela, `reticle` y `¡MARCADO!`;
  `markHit` → estallido violeta (`shatter`) y `MARCA ×2` con el golpe;
  `markGuarded` → anillo verde y `¡PROTEGE LA MARCA!` (o `MARCA ANULADA`
  en solo) sobre quien la contrarresta.
- **Fases** (Devorador): `phaseShift` → cinemática `transform` (1800
  ms, en el mundo) 120 ms después del golpe: una esfera de vacío crece
  sobre el jefe con 3 anillos carmesí que se cierran y rayos que
  convergen; a los 900 ms destello de pantalla `#d63031`, onda doble que
  se abre y 8 grietas incandescentes en el piso; cartel grande `FASE 2`.
  Partículas de fuego y arcanas, sacudida 10. Hasta el destello se
  dibuja el sprite de la fase 1; después `devoradorFase2` (escala 2.8)
  con aura carmesí suave que late y brasas que suben. La tarjeta de su
  ULT usa el sprite de su fase.
- **Comunes**: `evaded` → `¡ESQUIVA!` gris con el golpe.
- **HUD**: chips `Ecos: N vivos (×0.5 daño) · vuelven en N turnos`,
  `LAVA N turnos · ¡no te defiendas!` / `Charcos de Lava: sube en N
  acciones`, `Séquito N · INMUNE a estados` / `Séquito 0 · los estados
  entran`, `Marca del Vacío: X ×2 · ¡protegelo!` / `marca en N acciones`,
  `FASE 1 · se transforma al 50%` / `FASE 2 · Colapso Temporal cada 2 (en
  N)`; cada uno con su `counter`. Chip `Marcado ×2` en el marcado y
  `Marca +20%` (Vigilante del Vacío) en los golpeados por el Vigilante.
  Los ecos y siervos tienen turno: aparecen en la franja de turnos.

### ULT de los jefes v0.3

| ULT | Prep. | Descarga | Total | Impacto `i` | Hit-stop | Sacudida | Cámara |
|---|---|---|---|---|---|---|---|
| Coro de Ecos | 1000 | 1100 | 2500 | 1450 + 80·i | 110 | 11 | `group` |
| Erupción Total | 1000 | 1100 | 2500 | 1400 + 70·i | 130 | 15 | `group` |
| Lamento Eterno | 1000 | 1100 | 2500 | 1450 + 70·i | 120 | 12 | `group` |
| Colapso del Vacío | 1000 | 1100 | 2500 | 1500 + 60·i | 150 | 15 | `group` |

- **Coro de Ecos** (cian `#7ff3ff` / lila): preparación — seis siluetas
  de la Hechicera giran a su alrededor titilando y ondas del canto salen
  de ella. Descarga — arcos de onda en abanico viajan al grupo; en cada
  impacto, tres anillos de resonancia y notas que suben.
- **Erupción Total** (naranja `#ff7b29`): preparación — grietas
  incandescentes avanzan de la Bestia a cada objetivo, la melena de fuego
  crece, el cielo enrojece y tiembla. Descarga — llueven rocas; bajo cada
  objetivo se abre un charco y revienta una columna de lava con anillo.
- **Lamento Eterno** (azul pálido `#b8c6ff`): preparación — siete
  rostros que gimen giran en espiral hacia el Espectro y su corona
  destella. Descarga — una ola espectral barre de él al grupo; en cada
  impacto, manos de escarcha suben del piso y anillo.
- **Colapso del Vacío** (violeta `#9b59ff`): preparación — un agujero
  negro con disco de acreción crece sobre el Centinela y curva la luz
  hacia él. Descarga — viaja sobre el grupo y colapsa (onda doble); un
  rayo del vacío baja a cada objetivo y saltan esquirlas violetas/negras.

## Reacciones elementales (v0.7)

Fuente: docs/specs/elemental_reactions.md § 3. Código:
`lib/features/combat/presentation/scene/reaction_fx.dart` (plan puro +
dibujo), `status_icons.dart` (íconos), textos en
`lib/features/combat/domain/element_text.dart`.

- **Cartel** sobre el objetivo (`y − 34` del mundo, dibujado en px de
  pantalla con la unidad de las etiquetas `u`): banda negra `#000000`
  85% con franjas de 1·u arriba y abajo del color del **estado
  consumido** (`statusColor`: Mojado `#3fa9f5`, Cargado `#c77dff`,
  Congelación `#74b9ff`; en la Explosión tóxica, el naranja del fuego), texto Press Start 2P 12·u del color de la reacción con
  contorno negro. Dura **600 ms**: entra a escala 1.5 → 1 en 90 ms, sube
  6·u y se apaga en los últimos 160 ms. Golpe blanco 55% en los primeros
  80 ms × `flashFactor` (DESTELLOS apagados: sin golpe). REDUCIR
  MOVIMIENTO: sin escala de entrada ni subida.

| Reacción | Cartel | Color | Extra |
|---|---|---|---|
| Electrocución | `¡ELECTROCUCIÓN!` | `#c77dff` | 2 rayos quebrados que cruzan al objetivo (@0 y @40 ms) |
| Explosión tóxica | `¡EXPLOSIÓN TÓXICA!` | `#badc58` | anillo grande (radio 4 → 26) en el objetivo + anillo chico (→ 14) en cada salpicado a `+90 + 40·i` ms |
| Congelación súbita | `¡CONGELACIÓN SÚBITA!` | `#81ecec` | anillo chico |
| Derretir | `¡DERRETIR!` | `#ff9f43` | anillo chico |
| Cortocircuito | `¡CORTOCIRCUITO!` | `#c77dff` | rayo del objetivo al segundo enemigo (llega a los 140 ms: ahí cae su número) |

- **Anillo** (420 ms): trazo 2 px (3 el grande) del color + anillo
  interior 60% del color del estado; gotas de 2 px alrededor
  (`scaledCount(12 | 6, PARTÍCULAS)`). REDUCIR MOVIMIENTO: aparece ya
  abierto y solo se apaga.
- **Rayo** (260 ms): 6 tramos quebrados (amplitud `12%` del largo, 2–6
  px) que cambian cada 40 ms (fijos con REDUCIR MOVIMIENTO), trazo de
  color 2.5 px + núcleo blanco 1 px; llega al destino en el 40% y se
  apaga desde el 60%; chispas en la punta (`scaledCount(4, PARTÍCULAS)`).
- **Eventos → efectos** (`battle_fx.dart`): `ReactionEvent` (llega
  después del `DamageEvent` que la detona) → piezas `FxKind.reaction` a
  la hora de ese golpe + 30 ms. El daño extra (`DamageEvent` con
  `sourceId` `reaction.<kind>`) sale como número del color de la reacción
  en `(x + 14, y − 8)` (al costado del número del golpe, debajo del
  cartel) con su tajo: en el
  objetivo con el cartel; en cada salpicado a `+90 + 40·i`; el salto del
  Cortocircuito a `+140`. Partículas del elemento al abrir el anillo /
  llegar el rayo; el anillo grande sacude 4 (si la sacudida está
  activa).
- **Hielo** (`IceEvent`): `brittle` → `¡QUEBRADIZO!` `#81ecec` en
  `y − 46`; `shattered` → `shatter` cian + `¡SE ROMPE! ×1.5` con el
  golpe; `thawed` → `DESCONGELADO` (salvo que lo haya derretido una
  reacción en el paso); `resisted` → `RESISTE HIELO` gris.
- **Chips** (`battle_hud.dart`): Mojado / Cargado con ícono, letra y
  turnos que quedan (`M2` / `Mojado 2`, tooltip "2 turnos"); `▼VEL` con
  la lentitud y el quiebre extra; `Quebradizo`; `Resiste hielo N`.
- **Íconos de estado** (8×8, `status_wet` gota, `status_charged` rayo):
  contorno `#0b0e1a`, relleno del color del estado, brillo blanco. Los
  chips de Mojado / Cargado llevan ícono + letra (`M`, `E`) + stacks: la
  forma y la letra los distinguen sin color (accessibility.md § 3).

## Jefes del Abismo (v0.8.0)

Ver docs/specs/abyss_bosses.md § 4. `ArenaSpec.abyss`: la arena del jefe
base (Ruinas, Laberinto, Cementerio, Corazón; `AbyssBossDef.arenaZone`)
con la variante del Abismo (`_abyssTint`: velo violeta, grietas de luz
fría en el piso, bordes comidos por el vacío y motas que suben) y el
set-piece del jefe base (`kAbyssBaseBoss`). El secreto usa
`ArenaTheme.primordial` (vacío con cristales de los cinco elementos). Luz
de jefe `#c39bff`. Eventos: `FASE n` (todas las fases, también el
Devorador), `PRÓXIMO: <movimiento>` sobre el jefe, `¡FURIA!` con
destello, `SELLO · <reacción>` / `¡SELLO ROTO!` / `EL SELLO SE APAGA`,
`REBOBINA +N`, `RETRASO` en el grupo, arco del `REFLEJO`, `DEVORA N
BUFFS` y `ASPECTO: <elemento>`. Chips del jefe (por prioridad, la caja
corta los últimos): FASE (o INMUNE), PRÓX, SELLO, Aspecto, Furia,
Curas lo dañan, Comió N. ULT: los estilos de su jefe base, a todo el
grupo (`kEnemyUltScripts`). Sprites: forma del jefe base con paleta del
vacío; el Devorador del Abismo usa `devoradorAbismoFase2` desde la
fase 2; el Eco Primordial, arte propio (24 × 22, escala 2.6).

## Grupos grandes (v0.13)

- Barra del grupo (`BattlePartyBar.gridFor`): 1 fila de 4 lugares hasta
  4; con más, 2 filas de 4 hasta 8 y de `ceil(n/2)` si son más. Con más
  de 4 las tarjetas son compactas: sin retrato, nombre en una línea, y
  Pulso, invocaciones y estados solo en la propia (el resto, en el
  tooltip y la escena). Con más de 4 por fila las barras van con las
  cifras arriba.
- Alto de la barra (`barHeight`): + 6 % de la pantalla con más de 4
  (hasta 68 %).
- `T+n` de cada tarjeta y "te toca en" miran `turnWindow` turnos
  (10, o grupo + enemigos + 2 si es más), así todos aparecen.
- Tests: `big_party_ui_test.dart` (1280×720 y 1920×1080, los cuatro
  tamaños de texto, n = 1, 2, 4, 6, 8, 12, todas las categorías) y
  capturas en `docs/release_shots/v0.13.0/`.
