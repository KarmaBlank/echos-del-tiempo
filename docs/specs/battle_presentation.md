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
| Pantalla de batalla (menú, log, grupo, overlays) | `lib/features/combat/presentation/battle_screen.dart` (`BattleView`) |
| Escena (ticker + pintor) | `lib/features/combat/presentation/scene/battle_scene.dart` |
| Dibujo de actores, efectos, cinemática y timeline | `lib/features/combat/presentation/scene/battle_painter.dart` |
| Geometría, posiciones y cámara | `lib/features/combat/presentation/scene/battle_layout.dart` |
| Eventos → efectos (puro) | `lib/features/combat/presentation/scene/battle_fx.dart` |
| Partículas, sacudida, destello rojo | `lib/features/combat/presentation/scene/particles.dart` |
| Colores, elementos, `ELFX`, letras de estado | `lib/features/combat/presentation/scene/fx_style.dart` |
| Textos de ayuda (`descSkill` / `stDesc`) | `lib/features/combat/presentation/skill_info.dart` |
| Predicción de turnos (`predictTurns`, puro) | `lib/features/combat/domain/turn_order.dart` |
| Mapa de fondo de la sesión | `lib/features/world/presentation/session_battle_screen.dart` |

Tests: `test/features/combat/battle_fx_test.dart`,
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
- Los overlays Flutter usan esa misma escala para ubicarse: el log va en
  la banda `y ∈ [38, 54)` de la franja, el grupo y el menú abajo,
  encima de la escena.

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
- Centro de cámara `(bx + s·34, by)`. Objetivo de cámara (con `VW` el
  ancho virtual): `tx = clamp(cx − VW/2, −40, mw − VW + 40)`,
  `ty = clamp(cy − 288/2 + 40, −70, mh − 288 + 30 + extra)` (si el mapa
  es más chico que la vista, centrado). `extra` = alto de escena que
  queda debajo de los 288 px nominales más el que tapan los paneles,
  para que el grupo nunca quede debajo del menú. La cámara arranca en la
  del campo (centrada en el jugador local) y se mueve con suavizado
  `0.12` por frame de 60 Hz (`cam += (t − cam)·k`), salto directo si la
  distancia es > 200.
- Sin mapa (tests, previsualización): `(bx, by) = (VW/2 − 34, 104)`,
  `s = 1`, fondo `#05060c`.

## Escena

Orden de dibujo: fondo `#05060c`, tiles (los de `drawTile`, vía el
callback del mapa), enemigos lejanos del campo (> 130 px del centro;
el de la batalla nunca), actores ordenados por `y`, efectos del mundo,
`ultWorld`, partículas; después, ya sin sacudida: `ultScreen`, destello
rojo de daño (`hurtFlash`) y destellos `flash`. La sacudida traslada
todo el mundo `round((azar − 0.5)·sh·2)` en x e y.

### Héroes

Como `drawHero` (docs/specs/sprites.md § "Héroe") en batalla: sin bob,
sombra 6×2, mira a `−s`, arma dibujada en código, muerto acostado con
alfa 0.55. Además:
- estocada de 6 px hacia donde mira mientras un `act` suyo tenga edad
  < 260 ms (la sombra no se mueve);
- defendiendo: círculo `#74b9ffaa` radio 11 en `(0, −8)`;
- nombre (6 px, `#ffd166` el local, `#ffffff` el resto) en `y − 22`;
- insignias de estado en `y − 50`;
- turno: triángulo `#ffd166` de `(x−4, y−36+b)`, `(x+4, y−36+b)`,
  `(x, y−30+b)` con `b = sin(t/130)·2`.

### Enemigos

Como `drawEnemy` (sprites.md § "Enemigo") con `dir = s`, flotación,
aura élite y:
- estocada de `6·dir` px con un `act` < 260 ms;
- destello blanco (brillo ×3) con un `slash` sobre él de edad
  `[0, 120)` ms;
- muerte: alfa `max(0.15, 1 − (t − t_muerte − (ulti ? 900 : 0)) / 350)`,
  deja de dibujarse a los 350 ms (1250 ms con una ultimate en curso);
  `t_muerte` es el primer frame en que la escena lo ve con vida 0;
- barra de vida de ancho 40 (jefe o élite) o 20, alto 3 en
  `y − hh − 3`: fondo `#000000aa`, relleno `#ff4757` (jefe), `#ffd166`
  (élite) o `#ff9f43`;
- vida `hp/máx` en 6 px `#ffd8a8` en `y − hh − 6`; insignias en
  `y − hh − 32`;
- turno: barra `#ff4757` de 20×2 en `(x − 10, y + 3)`;
- objetivo (solo si es el turno del jugador local): triángulo `#ffd166`
  con punta en `y − hh − 13 + b`, `b = sin(t/120)·2`.

Clic/toque sobre un enemigo vivo (caja de su sprite + 4 px) lo elige como
objetivo.

### Insignias (`drawBadges`)

Por estado activo, en el orden Quemadura, Veneno, Congelación, Aturdido,
Sagrado, Regeneración: caja `12×9` `#000000cc`, franja de color 2×9 y
`letra + stacks` en 6 px del color; ancho 13 por insignia, centradas.

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
`proj`; 1150 (`ULT_DL`) en una ultimate de daño; 300 en un dúo; 0 si no.

| Evento | Efectos (`addFx` del prototipo) |
|---|---|
| `ActionEvent` ataque | `act`; a distancia: `proj` blanco `phys`; Golpe Imparable (todos): `ring` blanco en el atacante |
| `ActionEvent` habilidad / ULT | `act`; daño a todos sin ULT: `ring` del color de la habilidad; a distancia o mágica: `proj` por objetivo |
| `UltimateUsedEvent` | `ult` (cinemática) con nombre, color y elemento de la ULT del arma |
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
| `ult` | 2200 | cinemática (abajo) |

Al activarse (edad 0, después de `dl`) cada efecto dispara lo de
`fxVisual`:
- `slash`: `burst(x, y, el)`; `aura`: `burst(x, y−8, el)`;
  `poof`: `burst(x, y, arc, 0.8)`;
- `num` grande: sacudida `max(sh, hurt ? 7 : 5)`, con `hurt` además
  `hurtFlash = 0.45`, y `burst(x, y+10, phys, 1.5)`; `num` con `hurt`:
  sacudida `max(sh, 2)`;
- `flash`: sacudida `max(sh, 6)`; `ult`: sacudida `max(sh, 4)`.

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

### Cinemática de ultimate (`ultWorld` / `ultScreen`)

Edad `a` desde que se activa el `ult`; dura 2200 ms. Objetivos:
enemigos vivos o muertos hace < 1500 ms; con Baluarte, los jugadores.
- Aura en el lanzador (`a < 1100`): elipse de radios `r × (r/2 + 6)`,
  `r = 14 + sin(a/60)·3`, centro `(x, y−8)`, trazo 2 del color, alfa
  0.5; ráfagas `burst(x, y−6, el o lvl, 0.3)` cuando `a mod 90 < 20`.
- Fase `ph = (a − 300)/800` en `(0, 1.15)`, por objetivo `i`:
  `lp = clamp(ph·1.25 − 0.1i, 0, 1)`:
  - `burn`: meteoro desde `(x+70, y−160)` hasta `(x, y−10)`: 6 círculos
    (radio `6 − 0.7k`, `#fff3b0` los 2 primeros, si no `#ff7b29`, alfa
    `1 − k/6`, desplazados `(5k, −11k)`); al llegar: `burst burn ×3`,
    `burst phys ×1.5`, sacudida 7.
  - `frz`: 5 picos de hielo (`#81ecec` / `#dff9fb`) de alto
    `min(1, lp·1.6)·34·(1 − 0.22|k|)`; al llegar: `burst frz ×3`,
    sacudida 6.
  - `poi`: 7 trazos de lluvia `#badc58` de 1.5 px; al llegar
    `burst poi ×2.5`.
  - `holy`: columna de luz de 200 px de alto y ancho `10 + 8·lp`
    (gradiente a `rgba(255,243,176, 0.85·min(1, 2lp))`, núcleo blanco de
    un tercio); al llegar: `burst holy ×3`, sacudida 5.
  - `arc`: 10 cuadrados 4×4 girando a radio `40·(1 − lp) + 4`; al
    llegar `burst arc ×3`.
  - resto (`phys`, `stun`): dos tajos gigantes blancos de 3 px; al
    llegar `burst phys ×3`, sacudida 8.
- A los 1150 ms (`ULT_DL`): `burst(x, y−10, el o lvl, 1.5)` en cada
  objetivo (una vez). Es cuando aparecen los números (su `dl`).
- Pantalla: oscurecido `rgba(5,5,15, 0.55·d)` con `d` subiendo en 250
  ms, 1 hasta 1050 y bajando hasta 1500; banda diagonal del color (alfa
  0.85) en `by = VH − 58` que entra desde la izquierda en 220 ms y sale a
  la derecha de 1000 a 1300 ms, con 14 líneas de velocidad blancas
  (alfa 0.35), `* ULTIMATE · nombre *` (7 px) y el nombre de la ULT en
  mayúsculas (15 px); destello blanco `0.7·(1 − (a − 1110)/200)` entre
  1110 y 1310 ms.

## Ritmo y repetición

- La sesión decide los tiempos (`wait`); la escena nunca la frena.
- `BattleView` recibe `events` + `eventSeq` (`SessionView.battleEvents`
  / `battleEventSeq`). Cada vez que `eventSeq` cambia, los eventos se
  traducen **una vez** con la hora actual como inicio. Si llegan varios
  pasos seguidos, los efectos se superponen (cada uno con su hora). Al
  crear la vista, el `eventSeq` actual se marca como visto (no se
  repiten efectos viejos). Otra batalla (`battleId`) limpia efectos,
  partículas y muertes vistas.
- Máximo 70 efectos vivos (como `B.fx`): se descartan los más viejos.

## Menú y ayudas

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
- La cámara puede bajar más que en el prototipo (`extra`) porque el
  menú tapa la parte de abajo de la escena (en el prototipo está fuera
  del canvas).
- Log y etiqueta de tiempo son texto Flutter de 8 px (en el prototipo,
  5-6 px dentro del canvas): se lee mejor con Press Start 2P.
- Los emojis de los textos flotantes (`🔥+2`, `💫`, `🛡`) se cambian por
  la letra del estado (`Q+2`), el texto `¡ATURDIDO!` y `ESCUDO`: la
  fuente no tiene emojis.
- Lado de la batalla: el jugador más cercano al enemigo en vez de "el
  que lo tocó" (el motor no lo guarda).
- Los textos de subida de nivel (`¡NIVEL n!`) no se dibujan en la
  batalla: los muestra la sesión al terminar (progression.md).
- Sin sonido en esta capa (`beep` de `onNewFx` es de otro módulo).
