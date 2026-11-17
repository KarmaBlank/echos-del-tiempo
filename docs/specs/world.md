# Spec: Mundo (mapas, colisión, IA de campo)

Fuente de verdad: prototipo `ecos-del-tiempo.html`, constantes de la
línea 112 (`TS`), `rng` (línea 115), `lobbyMap`, `genMap`, `solidT`,
`hit`, `moveEnt` (líneas 412-491), `fieldTick` y `calmEnemies`
(líneas 659-694) y los helpers de interacción del cliente
(`nearSeal`, `nearArm`, `nearCounter`, líneas 929-932).

Implementación Dart:
- Azar con semilla: `lib/game_engine/rules/mulberry32.dart`
- Modelo de mapa: `lib/game_engine/models/game_map.dart`
- Generación: `lib/game_engine/rules/map_generator.dart`
- Colisión, movimiento y zonas: `lib/game_engine/rules/world_rules.dart`
- IA de campo: `SessionEngine.tick` en `lib/game_engine/rules/session_engine.dart`

Tests: `test/game_engine/map_generator_test.dart`,
`test/game_engine/world_rules_test.dart`,
`test/game_engine/session_engine_test.dart`.

## Unidades

- `TS = 16`: un tile mide 16 px. Las posiciones de jugadores, enemigos y
  objetos están en px del mundo; los tiles en coordenadas enteras.
- El centro de un tile `(tx, ty)` es `(tx*16 + 8, ty*16 + 8)`.

## Azar con semilla (`mulberry32`)

`rng(seed)` del prototipo es mulberry32. El puerto reproduce **bit a bit**
la aritmética de 32 bits de JS (`Math.imul`, `>>>`, `|0`), así que la
misma semilla da exactamente la misma secuencia que el navegador:

```
s = s + 0x6D2B79F5 (mod 2^32)
t = imul(s ^ s>>>15, 1 | s)
t = (t + imul(t ^ t>>>7, 61 | t)) ^ t
devuelve ((t ^ t>>>14) >>> 0) / 2^32
```

Semillas negativas o mayores a 32 bits se reducen con `|0` como en JS.
`imul` se calcula partiendo en mitades de 16 bits, así que funciona igual
en la VM y en web.

## Tiles

| Char | Significado | Sólido |
|---|---|---|
| `#` | muro / árbol / roca | sí |
| `.` | suelo | no |
| `,` | camino / pasillo | no |
| `~` | agua | sí |
| `C` | mostrador de misiones (lobby) | sí |
| `A` | armería (lobby) | sí |
| `M` | mercader ambulante (desactivado en el prototipo, nunca aparece) | sí |
| `G` | barrera del jefe | sí mientras la barrera esté cerrada |

Fuera del mapa todo es sólido.

## Lobby (`MapGenerator.lobby`)

26 × 14, borde de muros, fila 1 de camino, mostrador `C` en `x = 9..16`
de la fila 2, armería `A` en `x = 19..23` de la fila 2, dos estanques
`~` (x 3..5 y 20..22, filas 7..8), camino vertical en x 12..13 desde la
fila 3. Spawn en `(13*16, 9*16)`. Tema `lobby`.

Zonas de interacción (cliente, `WorldRules`):
- Mostrador: `y < 4.6*TS` y `8.5*TS < x < 17.5*TS`.
- Armería: `y < 4.6*TS` y `18.5*TS < x < 24.5*TS`.

## Mapa de misión (`MapGenerator.generate(misión, semilla)`)

Determinístico: misma misión + misma semilla = mismo mapa (lo único que
viaja por red es la semilla). Pasos, todos con `ri(a, b) = a + floor(r() * (b - a + 1))`
sobre `mulberry32(semilla)`, **en este orden** (cambiar el orden de las
llamadas al azar cambia el mapa):

1. Tamaño `W = ri(60, 76)`, `H = ri(44, 54)`, todo muro.
2. Lado de la arena del jefe: `['E','W','N','S'][ri(0,3)]`. La arena mide
   13 × 13 y reserva una franja de 16 tiles en ese lado (las salas no la
   usan). Su `y` (E/W) o `x` (N/S) sale de `ri(3, H-3-13)` / `ri(3, W-3-13)`.
3. Hasta 13 salas en 600 intentos: `w = ri(6,12)`, `h = ri(5,9)`,
   `x = ri(rx0, rx1-w)`, `y = ri(ry0, ry1-h)` (siempre las 4 llamadas);
   se descarta si se sale de la zona o queda a menos de 2 tiles de otra.
   Sin salas: una sala de 5 × 4 en la esquina. Las salas se pintan `.`.
4. Árbol mínimo (Prim con distancia Manhattan entre centros, el primer
   mínimo gana) uniendo salas con pasillos de 2 de ancho en L; cada
   pasillo elige con `r() < 0.5` si va primero en horizontal. Los
   pasillos solo convierten muros `#` (no tocan el borde) en `,`.
5. Dos bucles extra (si hay más de 3 salas): `i = ri`, `j = ri`, y si son
   distintos un pasillo más (con su `r()`).
6. Arena: 13 × 13 de suelo con 4 pilares en `(2,2)`, `(10,2)`, `(2,10)`,
   `(10,10)`. Pasillo desde la sala más cercana a la arena y una
   barrera `G` de 4 tiles en la única entrada.
7. Sala inicial (spawn): la más lejana a la arena (primera en empate).
8. Decoración: en cada sala que no es la inicial, `k = ri(0,3)` intentos
   de `x = ri`, `y = ri`; si no cae en la cruz central (a ±1 del centro
   ni en `centro+2`) se pone agua (`r() < 0.3`) o muro.
9. Flood fill desde el centro de la sala inicial (atravesando todo lo que
   no sea `#`, `~` ni `M`); el suelo inalcanzable se convierte en muro.
10. `spots`: tiles `.` alcanzables dentro de salas que no son la inicial
    (en orden de sala, fila, columna). Ahí aparecen enemigos y objetos.

Salida: tamaño, tiles, tema de la misión, lado, arena, salas, spawn
(centro de la sala inicial, en px), posición del jefe (centro de la
arena, en px), `spots` y `merchant` (siempre `null`: el mercader ambulante
está desactivado en el prototipo).

## Colisión y movimiento (`WorldRules`)

- `isSolid(map, tx, ty, gateOpen)`: fuera del mapa, `#`, `~`, `C`, `A`,
  `M` o `G` con la barrera cerrada.
- `collides(map, x, y, gateOpen)`: la caja del personaje toca algún tile
  sólido. Se prueban 4 puntos: `(x-5, y-3)`, `(x+5, y-3)`, `(x-5, y+4)`,
  `(x+5, y+4)`.
- `move(map, x, y, dx, dy, gateOpen)`: primero intenta mover en X, después
  en Y (desde la X ya resuelta), cada eje por separado. Así el personaje
  se desliza contra las paredes.
- Velocidad del jugador: 78 px/s, entrada normalizada en diagonal
  (`WorldRules.playerSpeed`, `WorldRules.stepPlayer`). La barrera solo se
  abre para jugadores; los enemigos siempre la ven cerrada.

## IA de enemigos en el campo (`SessionEngine.tick`, modo `field`)

Para cada enemigo vivo que no es jefe (el jefe no se mueve):
- Calma: mientras dure la gracia (`graceUntil`), nunca persigue.
- Jugador más cercano vivo (el primero en empate).
- **Persigue** si no está calmo, el jugador está a menos de 64 px y ese
  jugador está a menos de `LEASH = 110` px de la casa del enemigo:
  velocidad 34 px/s hacia él.
- Si no persigue y está a más de `LEASH × 0.6 = 66` px de su casa,
  **vuelve** a 36 px/s.
- Si no, **deambula**: resta `dt` a su temporizador; al llegar a 0 lo
  reinicia a `1 + azar × 1.5` s y con `azar < 0.4` se queda quieto, si no
  elige un ángulo al azar y camina a 18 px/s.
- Se mueve con `move` y la barrera cerrada. Mira a la derecha/izquierda
  según `vx` si `|vx| > 1`.
- **Contacto**: terminada la gracia (estrictamente después), si un
  jugador vivo está a menos de 14 px (26 px si es el jefe) empieza una
  batalla contra ese grupo (ver missions.md) y el tick termina ahí.

`calmEnemies` (después de cada batalla ganada y al salir de la subida
de nivel): todo enemigo vivo no-jefe con un jugador a menos de 120 px
vuelve a su casa, se detiene y espera 1.5 s.

Regeneración en el campo, por segundo: `MP + 0.4`, `HP + 0.8% de la vida
máx.` (sin pasar el máximo). La vida en el campo es fraccionaria; la UI
la muestra con `ceil` y entra a la batalla redondeada hacia arriba.

## Fuera de alcance (fases siguientes)

Render de tiles y temas (`THEMES`, `drawTile`), cámara, minimapa,
sprites, partículas, sonidos, teclado y el envío periódico de posición
por red (el cliente mueve a su jugador con `WorldRules.stepPlayer` y manda
`MoveAction`; ver missions.md).
