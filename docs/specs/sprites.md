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
    `bat`, `golem`, `ghost`, `reyLimo`, `golemReloj`, `devorador` (del
    prototipo) y, desde v0.2, `arana`, `lobo`, `murcielagoHielo`,
    `elementalEscarcha`, `esqueleto`, `caballeroCaido`, `cristalHielo`,
    `matriarca`, `sierpe`, `caballeroHueco` (arte propio, mismo pipeline);
    desde v0.3, `ecoSombra`, `guardianReloj`, `hechicera`, `ecoHechicera`
    (misma grilla que la Hechicera, paleta cian), `salamandra`,
    `golemMagma`, `bestiaMagma`, `necrofago`, `almaErrante`,
    `espectroCoronado`, `siervoEspectral`, `vigilanteVacio`, `ojoAbismo`,
    `centinela`, `heraldoEras`, `fragmentoTiempo` y `devoradorFase2` (el
    Devorador transformado: no es un tipo de enemigo, la escena lo usa con
    `Combatant.phase == 2` vía `enemySpriteId`). Grillas, paletas y
    escalas: docs/specs/bosses.md § "v0.3" › "Sprites".
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
| `arana`             | 18×13 | 20×15 |
| `lobo`              | 18×12 | 20×14 |
| `murcielagoHielo`   | 18×10 | 20×12 |
| `elementalEscarcha` | 16×15 | 18×17 |
| `esqueleto`         | 15×16 | 17×18 |
| `caballeroCaido`    | 16×15 | 18×17 |
| `cristalHielo`      | 9×13  | 11×15 |
| `matriarca`         | 28×19 | 30×21 |
| `sierpe`            | 24×20 | 26×22 |
| `caballeroHueco`    | 22×21 | 24×23 |

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

`{X: EN[tipo].col, W: #ffffff, O: #111111, R: #ff3b3b}`, más los colores
extra de `enemyExtraPalettes` (solo enemigos v0.2). Los extra se pintan
planos: solo `X` recibe el brillo/sombra de `makeSprite`.

| Tipo         | Sprite base | `col`     | Escala (`sc`) | Jefe |
|--------------|-------------|-----------|---------------|------|
| `slime`      | `slime`     | `#4cd137` | 1             | no   |
| `bat`        | `bat`       | `#8e44ad` | 1             | no   |
| `golem`      | `golem`     | `#95a5a6` | 1             | no   |
| `ghost`      | `ghost`     | `#a29bfe` | 1             | no   |
| `reyLimo`    | `slime`     | `#e1b12c` | 2             | sí   |
| `golemReloj` | `golem`     | `#d4a017` | 2             | sí   |
| `devorador`  | `ghost`     | `#e84393` | 2.4           | sí   |
| `arana`             | propio | `#6a3d66` | 1   | no |
| `lobo`              | propio | `#7f8fa6` | 1   | no |
| `murcielagoHielo`   | propio | `#9fe3f0` | 1   | no |
| `elementalEscarcha` | propio | `#6cb4e4` | 1   | no |
| `esqueleto`         | propio | `#e8e2cf` | 1   | no |
| `caballeroCaido`    | propio | `#5d6673` | 1   | no |
| `cristalHielo`      | propio | `#86d8ff` | 1   | no (add) |
| `matriarca`         | propio | `#4e2b55` | 1.8 | sí |
| `sierpe`            | propio | `#4fb9d8` | 1.8 | sí |
| `caballeroHueco`    | propio | `#4a4f5a` | 1.7 | sí |

Colores extra v0.2 (`enemyExtraPalettes`):

| Tipo                | Letras extra |
|---------------------|--------------|
| `arana`             | D patas `#5c4033`, A marcas `#a8679a`, G veneno `#7bed3f` (+ R ojos) |
| `lobo`              | D sombra `#4b5568`, L pecho `#d2dae2`, E ojo `#f9ca24` (+ W colmillos, O nariz) |
| `murcielagoHielo`   | D cuerpo `#3f8fb3`, L escarcha `#f4fdff`, E ojos `#0b2e59` (+ W colmillos) |
| `elementalEscarcha` | D faceta `#2c6aa0`, L brillo `#d4f1ff`, A halo `#9ff3ff` (+ W núcleo/ojos) |
| `esqueleto`         | D sombra `#9c9583`, S hoja `#a39c90`, T óxido `#b5562a`, H empuñadura `#5a3d22` (+ O cuencas, R pupilas) |
| `caballeroCaido`    | D escudo `#2f3540`, L borde `#9aa5b1`, P capa `#6c3483`, G visor `#9effd8` |
| `cristalHielo`      | D faceta `#2e6fb5`, L brillo `#f2fdff`, A núcleo `#c4f1ff` (+ W) |
| `matriarca`         | D vientre `#2e1834`, K patas `#6e4a7c`, A marcas `#9a5fa8`, G veneno `#7bed3f`, C corona `#e0c068` (+ R ojos/reloj de arena, W colmillos) |
| `sierpe`            | D escamas `#1f4f8a`, B vientre/brillo `#b5ecf5`, L crin/aliento `#e8fbff`, E ojo `#f6e58d` (+ W dientes, O pupila) |
| `caballeroHueco`    | D visor/escudo `#22252c`, Y oro `#b8963e`, E ojos `#6ff7ff`, P capa `#4a3550`, S hoja `#c8d0d8` |

La escala vive en el manifest (`enemies.<tipo>.scale`, por defecto 1) y se
lee con `SpriteCatalog.enemyScale`. Si el enemigo flota (los de forma
base `bat` o `ghost`: `bat`, `ghost`, `devorador`; en v0.2,
`murcielagoHielo`; en v0.3, `ecoSombra`, `almaErrante`, `espectroCoronado`,
`siervoEspectral`, `ojoAbismo`, `fragmentoTiempo`, `devoradorFase2`) el manifest lo marca
con `enemies.<tipo>.float: true` (`SpriteCatalog.enemyFloats`). Los jefes reusan la forma base con su
propio color: son PNG propios, no un tinte en runtime.

## Ascensiones (v0.5)

Arte propio (no está en el prototipo), mismo pipeline (`makeSprite`).
Datos en `tool/export_sprites.dart`: `ascensionRows`, `ascensionPalettes`,
`auraRows`, `auraPalettes`.

### Sprite de la ascensión

- Id lógico (sección `characters:` del manifest) = `<clase>_<ascensión>`,
  el mismo id que usa el gameplay. Archivo en la carpeta de la clase base
  (ya listada en `pubspec.yaml`): `characters/<clase>/<ascensión>.png`.
- **Misma grilla 12×16 → PNG 14×18, mismo ancla `(-7, -17)`, misma
  orientación (mira a la derecha) y mismos frames que el héroe base**: un
  solo frame `idle`; bob, estocada, muerte, parpadeo y círculo de defensa
  siguen siendo procedurales. Se reemplaza 1:1: donde se dibujaba
  `hero(clase)` se dibuja `hero('<clase>_<ascensión>')`.
- El arma sigue siendo el overlay en código (`WeaponOverlay`) del tipo de
  arma / clase BASE: quien dibuje tiene que pasarle la clase base
  (`guerrero`), no el id de la ascensión.
- Filas 14 (botas) y 15 (vacía) iguales en espíritu al héroe: los pies
  quedan en el mismo píxel.

| Id | Archivo | Rasgos | Letras propias |
|----|---------|--------|----------------|
| `guerrero_berserker` | `characters/guerrero/berserker.png` | pelo rojo oscuro revuelto, ojos rojos brillantes, pintura de guerra, hombreras de hierro, correas negras cruzadas, capa negra desgarrada | E ojos `#ff2b2b`, K negro `#1f1520`, R rojo vivo `#ff4d3a`, C capa `#3a1c24`, M hierro `#5a5560` |
| `guerrero_senorGuerra` | `characters/guerrero/senorGuerra.png` | yelmo dorado con penacho carmesí, hombreras de oro, peto carmesí con emblema, capa carmesí, cuerno de guerra al cinto | P penacho `#e63946`, G oro `#d4af37`, Y oro claro `#ffe27a`, C capa `#7d0f1f`, W cuerno `#f1e4c3` |
| `maga_cronomante` | `characters/maga/cronomante.png` | capucha verde azulada con broche plateado, esfera de reloj en el pecho, cinto plata/oro, túnica larga hasta los pies con ribete | M plata `#cfd8dc`, W esfera `#f5fbff`, K agujas `#1b2b34`, G oro `#e1b12c` |
| `maga_elementalista` | `characters/maga/elementalista.png` | pelo de fuego, túnica tricolor fuego/hielo/veneno, cinto con una gema por elemento | F pelo `#e8432b`, Y puntas `#ffd166`, Q fuego `#f07a1a`, I hielo `#3cc8ec`, V veneno `#38b24a`, K cinto `#2b2440` |
| `tirador_francotirador` | `characters/tirador/francotirador.png` | capucha y capa verde oscuro, rifle largo a la espalda, mira con destello sobre el ojo, máscara y correa grises | G rifle `#5b646a`, K capucha `#24382b`, E lente `#9ff3ff`, W destello `#ffffff`, M gris `#6b7a80` |
| `tirador_trampero` | `characters/tirador/trampero.png` | gorro de piel con cola, manto de piel, pelo ámbar, correas ámbar cruzadas, cepo abierto colgando atrás del cinto, polainas de piel | F piel `#8a5a32`, U piel oscura `#4f321b`, P puntas `#d9c3a0`, A ámbar `#f0a830`, T acero `#a4adb3` |
| `paladin_templario` | `characters/paladin/templario.png` | pelo dorado claro con diadema y gema, tabardo blanco con sol, hombreras y cinto dorados, capa crema, grebas plateadas y botas de oro | Y oro `#f1c40f`, R gema `#ff6b3d`, Z núcleo del sol `#ff9f1a`, W tabardo `#fbf9f2`, G oro `#d4af37`, C capa `#efe6cf` |
| `paladin_guardian` | `characters/paladin/guardian.png` | yelmo cerrado con cresta azul y visor de ojos cian, hombreras anchas (ocupan las 12 columnas), tabardo azul con emblema, brazos y escarpes de placa | M acero `#9aa5b1`, N azul `#2e5aac`, P plata `#dfe6e9`, K visor `#141a24`, E ojos `#6ff7ff`, W emblema `#ffffff` |

Las letras base (`H`, `S`, `O`, `B`, `L`, `D`) conservan su rol con colores
propios de cada ascensión (ver `ascensionPalettes`). Ninguna grilla usa `X`,
así que no hay sombreado automático.

### Aura de la ascensión (overlay opcional)

- Id lógico `aura_<ascensión>` (también en `characters:`, para que
  `GameSprites.hero('aura_<ascensión>')` lo devuelva sin cambiar código),
  frame `idle`, archivo `characters/<clase>/aura_<ascensión>.png`.
- PNG **24×26**, sin contorno ni sombreado (`auraSprite`), fondo
  transparente, píxeles opacos.
- **Ancla**: se dibuja DETRÁS del héroe en `(-12, -25)` respecto de
  `(round(x), round(y))` (centrado en x, última fila a la altura de los
  pies). Píxel del héroe `(px, py)` ↔ píxel del aura `(px + 5, py + 8)`.
- Sugerido (no obligatorio): alfa pulsante `0.65 + 0.25 * sin(t / 220)`,
  sin bob ni estocada (como la sombra); espejar con el héroe si `dir < 0`.
  Ocultarla con el héroe muerto.

| Id | Archivo | Dibujo |
|----|---------|--------|
| `aura_berserker` | `characters/guerrero/aura_berserker.png` | lenguas de fuego rojo/naranja por los costados y sobre la cabeza, brasas sueltas |
| `aura_senorGuerra` | `characters/guerrero/aura_senorGuerra.png` | estandarte carmesí con corona dorada en un asta a la espalda + destellos dorados |
| `aura_cronomante` | `characters/maga/aura_cronomante.png` | 12 marcas de reloj en anillo (las 4 cardinales blancas) y dos agujas flotando sobre la cabeza |
| `aura_elementalista` | `characters/maga/aura_elementalista.png` | tres orbes con estela: fuego (atrás), hielo (sobre la cabeza), veneno (adelante, abajo) |
| `aura_francotirador` | `characters/tirador/aura_francotirador.png` | cuatro esquineros de retícula verde, marca superior y destello cian frente a la mira |
| `aura_trampero` | `characters/tirador/aura_trampero.png` | luciérnagas ámbar y dientes de cepo en el suelo a ambos lados |
| `aura_templario` | `characters/paladin/aura_templario.png` | halo solar dorado detrás de la cabeza con 8 rayos |
| `aura_guardian` | `characters/paladin/aura_guardian.png` | cúpula de escudo azul con remaches celestes que envuelve al guardián |

## Exploración (v0.6)

Los tiles y objetos nuevos de la exploración (pared agrietada, sala
secreta, atajo, santuarios, piedras de paso, Viento del Eco, braseros,
cofres reforzado y dorado, reliquia) se dibujan **procedurales** en
`TilePainter` / `ActorPainter`, como el resto de los tiles del mapa:
no hay PNG ni ids nuevos en `sprite_manifest.yaml`. Detalle en
exploration.md § "Exploración (v0.6)". Si el dueño quiere arte a mano,
se agregan como ids de manifiesto y el painter los usa cuando existan.

## Regenerar los PNG

Desde la raíz del proyecto, con el `dart` del SDK de Flutter:

```
dart run tool/export_sprites.dart
```

Sobrescribe todos los PNG listados en este spec (54 desde v0.5: 4 héroes,
34 enemigos, 8 ascensiones y 8 auras). El script no toca el manifest.

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

## Íconos de armas e ítems: procedural vs PNG (v0.25.7)

Dos maneras de que exista un sprite en el manifest:

- `procedural: true`: se dibuja en código, no hay archivo. El Editor lo
  muestra como "procedural" y sus perillas (`procedural.yaml`, § 7.5 de
  game_editor.md) cambian el dibujo.
- Ruta a un PNG: el archivo manda. Se generó una sola vez con una
  herramienta y desde ahí es la fuente de verdad: se reemplaza o se edita
  el PNG, sin tocar Dart.

Los íconos de armas, escudos, pociones, materiales, Ecos y cofre (las 25
formas de `lib/core/procedural/item_icon_rows.dart`) son PNG desde v0.25.7,
con el mismo estilo que los de oficio (`# vida:inicio/fin`): 16 × 16,
contorno oscuro, luz arriba a la izquierda, sombra abajo a la derecha y
brillo en el metal. Cada forma tiene dos archivos en
`assets/sprites/items/`:

- `<forma>.png`: todo menos el acento (metal, mango, cuerda, papel…).
- `<forma>_acento.png`: solo el acento (gema, color de rareza o del
  material) en grises. El juego lo tiñe con el color que corresponde en
  ese momento (rareza, tema, modo daltónico), así que un solo PNG sirve
  para las cinco rarezas. Pintarlo en grises: blanco = color pleno.

Las entradas están en el manifest entre `# items:inicio` y `# items:fin`.
Encima del PNG el juego sigue dibujando la identidad del arma concreta
(aura del elemento, destello del legendario, marca de ULT).

Respaldo: si falta un PNG (o no carga), `PixelIcon` vuelve al dibujo
procedural con las perillas de siempre. Las perillas de `items` ya no
cambian lo que se ve mientras exista el PNG.

Para cambiar un ícono: reemplazar el PNG (misma ruta y tamaño 16 × 16,
fondo transparente) o importarlo desde el Editor de sprites, que lo
guarda como override local y lo puede publicar al repo. Para volver a
generarlos todos desde las formas:

```
dart run tool/export_item_icons.dart
```

Ojo: PISA todos los `items/<forma>.png` y `_acento.png` (también los
editados a mano) y reescribe el bloque `# items:inicio/fin`.

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
- **Armas en mano** (v0.19.1; `WeaponOverlay`,
  `lib/features/combat/presentation/weapon_overlay.dart`). Reemplaza los
  rectángulos del prototipo. Se dibuja **el tipo de arma equipada**
  (loot v2: cualquier clase equipa cualquier arma); sin tipo conocido,
  el arma de siempre de la clase (`guerrero` espada, `maga` báculo,
  `paladin` espada+escudo, `tirador` rifle).
  - **Dibujo**: el ícono procedural 8×8 del tipo (`kItemIconRows`,
    `lib/core/procedural/item_icons.dart`) pintado con las perillas de su
    entrada del Editor (`items.<tipo>`, game_editor.md § 7.5): recolorear
    un arma en el Editor cambia también el arma en mano. Ningún arte por
    arma individual. `maza` y `martillo` son formas solo-en-mano. El
    ícono de inventario de las familias con escudo es la forma combinada
    `espada_escudo` / `maza_escudo` / `martillo_escudo` (escudo a la
    izquierda, arma de pie a la derecha; weapon_identity.md § 3.1); en
    la mano se siguen dibujando por separado.
  - **Agarre** (`WeaponOverlay.kGrips`): por arte, forma, tamaño de celda
    (px del héroe), celda del ícono que cae en la mano, posición de la
    mano respecto de los pies, espejo y giro:

    | Tipo | Forma | Celda | Agarre (ícono) | Mano | Extra |
    |---|---|---|---|---|---|
    | `espada`, `espada+escudo` | espada | 1.25 | (3,5) | (5,-7) | |
    | `hacha` | hacha | 1.25 | (4,5) | (5,-7) | espejada (cabeza adelante) |
    | `báculo` | báculo | 1.5 | (3,4) | (5,-7) | |
    | `tomo` | tomo | 1 | (3.5,6) | (6,-5) | sostenido abierto al frente |
    | `arco` | arco | 1.25 | (0,4) | (10,-8) | espejado (cuerda hacia el cuerpo) |
    | `rifle` | rifle | 1.25 | (3,4) | (4,-6) | cañón hacia adelante |
    | `maza+escudo` | maza | 1.25 | (3,6) | (5,-6) | |
    | `martillo+escudo` | martillo | 1.25 | (3,6) | (5,-6) | |
    | `lanza` | lanza | 1.5 | (3,4) | (5,-7) | |
    | `dagas` | dagas | 1 | (3.5,4) | (7,-6) | |
    | `varita` | varita | 1 | (3,5) | (5,-7) | |
    | `ballesta` | ballesta | 1.25 | (3,5) | (5,-7) | girada 90° (apunta adelante) |

  - **Mano**: un cuadro 2×2 `#e8b890` centrado en la mano, encima del
    mango: el arma se ve agarrada.
  - **Escudo** (`*+escudo`): ícono `escudo` 8×8 a celda 1 en
    `(-11,-13)` (brazo de atrás), con las mismas perillas que el arma.
  - **Caja**: con cualquier arma la figura entra en
    `WeaponOverlay.bounds = (-11,-18, 24×20)` (test).
  - **Dónde**: mapa (`ActorPainter.hero`), batalla (`BattlePainter`),
    ULT solo y dúo (retrato grande a la escala del sprite) y retratos de
    UI (`HeroFigure`: tarjeta de personaje y de clase, HUD de batalla y
    lista de turnos), que escalan sprite+arma para entrar en su caja sin
    desbordar. Las ULT y los ataques ya eligen proyectil/tajo por tipo
    (`projStyleFor`, `slashStyleFor`).
  - **Red**: sin cambios. El tipo viaja en el snapshot de batalla
    (`Combatant.weaponType`, clave `wt`) y en el perfil (`eq`) en mapa y
    sala; cada cliente dibuja el arma de los demás.
  - Pendiente (borrador weapon_identity.md): aura por elemento y
    diferenciación por rareza/semilla.
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

## Identidad del arma (v0.20.0)

weapon_identity.md § 6. Sobre el ícono procedural del tipo, en la mano
(mapa, batalla, retratos, ULT) y en el inventario, `paintItemIcon` con
un `WeaponLook` suma: acento por rareza, reflejo en Épicos, variante por
uid (tono del metal ± y gema; la silueta no cambia), aura de 1 celda
del color del elemento con 2 partículas lentas, destello que recorre el
metal en Legendarios y un píxel rosa en el pomo si el arma tiene ULT.
Todo se regula con perillas del generador `item_icon` en el Editor:
`aura` (intensidad 0–1, 0.5 por defecto), `aura_particles`, `sparkle`,
`ult_mark` y `variation`. El aspecto sale de datos del arma que ya
viajan (perfil y build del snapshot): el compañero se ve igual en todos
los clientes.
