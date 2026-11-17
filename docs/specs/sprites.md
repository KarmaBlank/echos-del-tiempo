# Spec: Sprites pixel art

Fuente de verdad: prototipo `ecos-del-tiempo.html`, tablas `CLASSES`
(campo `pal`), `EN` (campos `spr`, `col`, `sc`, `boss`), `HERO`, `SPR`, y
las funciones `shade`, `makeSprite`, `heroSpr`, `enSpr`, `drawHero`,
`drawEnemy` (y el bucle de dibujo que las llama).

Implementación Dart:
- Generador de PNG: `tool/export_sprites.dart` (Dart puro, sin paquetes).
- Mapa id lógico → archivo: `assets/sprites/sprite_manifest.yaml`.
- Carga en runtime: `lib/features/combat/presentation/sprite_catalog.dart`
  (`SpriteCatalog`, la ÚNICA clase que lee el manifest).

Tests: `test/tool/export_sprites_test.dart` (puerto de píxeles y PNG),
`test/features/combat/sprite_catalog_test.dart` (manifest ↔ archivos y
carga real desde el bundle).

## Formato de los archivos

- PNG RGBA de 8 bits, **1 píxel del PNG = 1 píxel del sprite** (sin
  escalar). El escalado se hace al dibujar.
- Fondo transparente (alfa 0); todo píxel pintado es opaco (alfa 255).
- Un solo frame por sprite (`idle.png`). El prototipo NO tiene frames de
  caminar/atacar: todas sus animaciones son procedurales (ver abajo).
- Rutas:
  - Héroes: `assets/sprites/characters/<clase>/idle.png` para
    `guerrero`, `maga`, `paladin`, `tirador`.
  - Enemigos: `assets/sprites/enemies/<tipo>/idle.png` para `slime`,
    `bat`, `golem`, `ghost`, `reyLimo`, `golemReloj`, `devorador`.
- Cada carpeta nueva bajo `assets/sprites/` tiene que figurar en
  `flutter: assets:` de `pubspec.yaml` (los directorios de assets de
  Flutter NO son recursivos).

### Tamaños (incluye 1 px de contorno a cada lado)

| Sprite base | Grilla | PNG     |
|-------------|--------|---------|
| héroe       | 12×16  | 14×18   |
| `slime`     | 16×12  | 18×14   |
| `bat`       | 16×10  | 18×12   |
| `golem`     | 16×15  | 18×17   |
| `ghost`     | 14×14  | 16×16   |

## Construcción del sprite (`makeSprite`)

Entrada: filas de texto (`HERO` o `SPR[spr]`) y una paleta carácter → color.
`.` es transparente.

1. Lienzo de `(columnas + 2) × (filas + 2)`; la celda `(i, j)` de la grilla
   va al píxel `(i + 1, j + 1)`.
2. **Contorno**: para cada celda `(i, j)` con `i ∈ [-1, columnas]`,
   `j ∈ [-1, filas]` que NO esté llena, si alguno de sus 4 vecinos
   ortogonales está lleno se pinta `#0d0d14`. (Las diagonales no cuentan.)
3. **Relleno**: cada celda llena toma `pal[ch]` (si falta: `#ff00ff`).
   Solo para el carácter `X` (color base del enemigo):
   - si `j > filas * 0.6` → `shade(color, 0.78)` (mitad inferior más oscura);
   - si `j < 2` → `shade(color, 1.2)` (las dos filas de arriba con brillo).
   El héroe no usa `X`, así que no recibe sombreado.
4. `shade(hex, f)`: por canal `clamp(Math.round(c * f), 0, 255)`, con el
   `Math.round` de JS (`floor(x + 0.5)`).

Los colores hex de 3 dígitos (`#111`) se expanden como en CSS (`#111111`).

### Paletas de héroe (`CLASSES[...].pal`)

| Clase      | H (pelo)  | S (piel)  | O (ojos)  | B (ropa)  | L (piernas) | D (botas) |
|------------|-----------|-----------|-----------|-----------|-------------|-----------|
| `guerrero` | `#6b3a1e` | `#f2c29b` | `#1b1b1b` | `#c0392b` | `#3b2f2f`   | `#5a3d1e` |
| `maga`     | `#9b59b6` | `#f2c29b` | `#1b1b1b` | `#2e5aac` | `#24478a`   | `#3b2a55` |
| `paladin`  | `#d4af37` | `#f2c29b` | `#1b1b1b` | `#bdc3c7` | `#34495e`   | `#7f8c8d` |
| `tirador`  | `#f1c40f` | `#f2c29b` | `#1b1b1b` | `#27ae60` | `#34495e`   | `#2c3e50` |

### Paleta de enemigos (`enSpr`)

`{X: EN[tipo].col, W: #ffffff, O: #111111, R: #ff3b3b}`.

| Tipo         | Sprite base | `col`     | Escala (`sc`) | Jefe |
|--------------|-------------|-----------|---------------|------|
| `slime`      | `slime`     | `#4cd137` | 1             | no   |
| `bat`        | `bat`       | `#8e44ad` | 1             | no   |
| `golem`      | `golem`     | `#95a5a6` | 1             | no   |
| `ghost`      | `ghost`     | `#a29bfe` | 1             | no   |
| `reyLimo`    | `slime`     | `#e1b12c` | 2             | sí   |
| `golemReloj` | `golem`     | `#d4a017` | 2             | sí   |
| `devorador`  | `ghost`     | `#e84393` | 2.4           | sí   |

La escala vive en el manifest (`enemies.<tipo>.scale`, por defecto 1) y se
lee con `SpriteCatalog.enemyScale`. Si el enemigo flota (los de forma
base `bat` o `ghost`: `bat`, `ghost`, `devorador`) el manifest lo marca
con `enemies.<tipo>.float: true` (`SpriteCatalog.enemyFloats`). Los jefes reusan la forma base con su
propio color: son PNG propios, no un tinte en runtime.

## Regenerar los PNG

Desde la raíz del proyecto, con el `dart` del SDK de Flutter:

```
dart run tool/export_sprites.dart
```

Sobrescribe los 11 PNG listados arriba. El script no toca el manifest.

## Reemplazar el arte por PNG hechos a mano

1. Dibujar el PNG (Aseprite, Piskel, …) a 1 px por píxel, con fondo
   transparente. Puede tener otro tamaño: el pie del sprite se alinea por
   el borde inferior (ver anclas abajo).
2. Guardarlo en la misma ruta (`characters/<clase>/idle.png` o
   `enemies/<tipo>/idle.png`) o en otra y actualizar la ruta en
   `sprite_manifest.yaml`. Si se usa una carpeta nueva, agregarla a
   `pubspec.yaml`.
3. NO volver a correr `tool/export_sprites.dart` (pisaría el arte manual).
4. `flutter test` verifica que toda entrada del manifest apunte a un
   archivo existente.

## Dibujo: filtrado

El prototipo dibuja con `imageSmoothingEnabled = false`. En Flutter/Flame
todo sprite se dibuja con **`FilterQuality.none`** (vecino más cercano),
incluso con escalas no enteras (2.4). `SpriteCatalog` ya entrega los
`Sprite` con `paint.filterQuality = FilterQuality.none`; si se dibuja el
`ui.Image` a mano, usar `SpriteCatalog.pixelPaint()` o equivalente. Las
posiciones se redondean a píxel entero (`Math.round`) antes de dibujar.

## Animaciones procedurales (para la fase Flame)

Tiempo `t` en milisegundos. Coordenadas en píxeles del mundo lógico del
prototipo (pantalla 480×288, tile 16 px), con `(x, y)` = pies del actor.

### Héroe (`drawHero`)

- **Ancla**: el sprite (14×18) se dibuja en `(-7, -17)` respecto de
  `(round(x), round(y))`; la última fila (contorno inferior) queda 1 px
  bajo los pies.
- **Sombra**: elipse centro `(0, +1)`, radios `6 × 2`, color `#000000` con
  alfa `0x66` (0.4). No se ve afectada por el bob ni la estocada.
- **Orientación**: el arte mira a la derecha; si `dir < 0` se espeja
  horizontalmente (`scale(-1, 1)`), lo que también espeja armas y estocada.
- **Bob al caminar** (solo si `mv`, es decir, moviéndose en el mapa):
  `bob = floor(t / 140) % 2` → el sprite sube 0 ó 1 px, alternando cada
  140 ms (ciclo de 280 ms). Quieto o en batalla: sin bob.
- **Estocada al actuar** (`act`): desplazamiento de **+6 px** en x local
  (hacia donde mira) mientras exista un evento `act` del héroe con edad
  `< 260 ms`. Es un salto, no una interpolación.
- **Muerto** (`hp <= 0`): alfa 0.55, rotado 90° (`π/2`) y luego trasladado
  `(-6, -4)` en el sistema rotado (queda acostado).
- **Parpadeo de invulnerabilidad** (solo en el mapa, `graceL > 0`): alfa
  0.35 cuando `floor(t / 110) % 2 == 1` (ciclo de 220 ms).
- **Defendiendo** (`def`): círculo sin relleno centro `(0, -8)`, radio 11,
  color `#74b9ffaa`.
- **Armas** (dibujadas en código encima del sprite, coordenadas locales ya
  con bob/estocada; rectángulos `x, y, ancho, alto`):
  - `guerrero` y `paladin` con espada: hoja `#dfe6e9` `(5,-17,2,9)`,
    guarda `#ffd166` `(3,-9,6,1)`.
  - `maga`: vara `#8a5a2b` `(6,-15,1,15)`, orbe `#74b9ff` círculo centro
    `(6.5,-16)` radio 2.2.
  - `paladin` + martillo: mango `#8a5a2b` `(6,-14,1,11)`, cabeza `#95a5a6`
    `(3,-18,7,5)`, filo `#636e72` `(3,-14,7,1)`.
  - `paladin` + maza: mango `#8a5a2b` `(6,-13,1,9)`, cabeza `#b2bec3`
    círculo centro `(6.5,-15)` radio 2.6, púas `#dfe6e9` 1×1 en
    `(4,-16)`, `(8,-16)`, `(6,-18)`.
  - `paladin` (siempre) escudo: `#2c3e50` `(-10,-13,6,9)`, `#ecf0f1`
    `(-9,-12,4,7)`, cruz `#d4af37` `(-8,-11,2,5)` y `(-9,-9,4,1)`.
  - `tirador`: arma `#636e72` `(5,-8,6,2)` y `(5,-7,2,3)`.

  **Loot v2** (cualquier clase equipa cualquier arma): el arma se elige
  por **tipo** (`WeaponOverlay`, `lib/features/combat/presentation/
  weapon_overlay.dart`, la misma en el mapa y en batalla). Los tipos del
  prototipo usan el arte de la clase que los traía (`espada`/`hacha` →
  espada, `báculo`/`tomo` → vara, `arco`/`rifle` → arma de tirador,
  `martillo+escudo`, `maza+escudo`, `espada+escudo` → los de paladín con
  escudo); sin tipo, el de la clase. Tipos nuevos:
  - `lanza`: asta `#8a5a2b` `(6,-20,1,21)`, punta `#dfe6e9` `(6,-25,1,5)`
    y `(5,-23,3,2)` con brillo blanco `(6,-24)`, borla `#d63031`
    `(5,-19,3,1)` y `(5,-18,1,2)`.
  - `dagas`: una en cada mano — atrás hoja `#b2bec3` `(-8,-12,1,4)` y
    guarda `#6c5ce7` `(-9,-8,3,1)`; adelante hoja `#dfe6e9` `(6,-12,1,5)`,
    guarda `#6c5ce7` `(5,-7,3,1)`, mango `#2d3436` `(6,-6,1,2)`.
  - `varita`: vara `#5a3a1a` `(6,-11,1,7)`, virola `#ffd166` `(5,-12,3,1)`,
    gema `#a29bfe` `(5,-15,3,3)` con centro `#e84393`, destello blanco
    `(8,-16)`.
  - `ballesta`: culata `#6b4423` `(3,-9,8,2)` y `(3,-7,2,2)`, arco
    `#95a5a6` `(11,-13,1,10)` con puntas `#636e72`, virote `#dfe6e9`
    `(8,-10,6,1)` con punta `#ff7b29`.
- **Etiquetas**: nombre en `y - 22`; marcador de turno (triángulo
  `#ffd166`) en `y - 36 + sin(t / 130) * 2`.

### Enemigo (`drawEnemy`)

- **Escala**: `sc = scale_manifest × (élite ? 1.45 : 1)`;
  `w = ancho_png × sc`, `h = alto_png × sc`.
- **Ancla**: el sprite se dibuja en `(-w/2, -h + 2)` respecto del punto
  trasladado: queda centrado en x y 2 px bajo los pies.
- **Flotación** (solo sprites base `bat` y `ghost`, o sea también
  `devorador`; en Dart, `float: true` del manifest): `fl = sin(t / 200 + x) * 2 − 4` px en y (amplitud 2 px,
  período `2π·200 ≈ 1257 ms`, elevado 4 px). La fase depende de `x` para
  que no floten sincronizados. El resto: `fl = 0`.
- **Sombra**: elipse centro `(x, y + 1)`, radios `w * 0.35 × 2.5 * sc`,
  `#000000` alfa 0.4; no flota.
- **Aura élite** (detrás del sprite): elipse centro `(x, y − h/2 + 2)`,
  radios `w * 0.62 × h * 0.6`, color `#ffd166`, alfa
  `0.35 + 0.2 * sin(t / 180)`.
- **Traslado**: `(round(x + (act ? 6 * dir : 0)), round(y + fl))`.
  Estocada de **6 px** en la dirección `dir` (mundo), mientras haya un
  evento `act` del enemigo con edad `< 260 ms`. En batalla
  `dir = side || −1`.
- **Orientación**: el arte se considera mirando a la izquierda; si
  `dir > 0` se espeja horizontalmente.
- **Flash de golpe**: filtro `brightness(3)` (multiplicar RGB × 3 con
  saturación) mientras haya un evento `slash` a menos de 4 px de
  `(e.x, e.y − 8)` con edad en `[0, 120) ms`.
- **Muerte**: alfa `max(0.15, 1 − (t − t_muerte − (ulti ? 900 : 0)) / 350)`;
  deja de dibujarse a los 350 ms (1250 ms si hay una ultimate en curso).
- **Barra de vida**: ancho 40 (jefe o élite) o 20, alto 3, en
  `y − hh − 3` con `hh = alto_png × sc`; fondo `#000000aa`, relleno
  `#ff4757` (jefe), `#ffd166` (élite) o `#ff9f43`.
- **Etiquetas en el mapa**: `★ÉLITE` en `y − 34`, `!` (aggro) en
  `y − 22 + sin(t / 90) * 1.5`, `JEFE` en `y − 48`.

### Efectos

Las partículas (`burst`/`ELFX`), destellos de pantalla y ultimates del
prototipo son primitivas dibujadas en código (cuadrados, rayos, burbujas),
no imágenes: no hay PNG de efectos y el manifest no tiene sección
`effects`. Si en el futuro se dibujan efectos a mano, se agregan como
sección nueva del manifest + carpeta en `pubspec.yaml`.
