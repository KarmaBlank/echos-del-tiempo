# Iluminación (v0.32.0)

Sistema de luz por tile para el mapa (pueblo, exteriores y mazmorras).
La batalla no cambia. Código: reglas puras en
`lib/game_engine/rules/light_rules.dart`, datos en
`lib/game_engine/data/light_catalog.dart`, dibujo en
`lib/features/world/presentation/map/light_layer.dart`, colores en
`LightPalette` (`map_themes.dart`).

## 1. Idea

Cada cuadro el mapa se multiplica por un "mapa de luz": por tile, un
color = ambiente + suma de las luces cercanas (recortado a 1). Donde no
llega ninguna luz queda el ambiente (de día, blanco: no cambia nada).

## 2. Propagación

- Cada luz (`LightSource`: posición en tiles con fracción, `LightDef`,
  escala) se propaga tile a tile por el camino más corto con 8 vecinos
  (paso recto 1, diagonal √2) hasta su `radius`.
- Caída suave: brillo = `intensity × escala × (1 − d/r)²`, por el color
  de su `tint`.
- Tiles opacos (`kOpaqueTiles`: muros, rocas, paredes agrietadas, atajos,
  engranajes, barrera): se iluminan pero la luz no sigue. Por una
  diagonal entre dos opacos no se cuela.
- Tiles que atenúan (`kAttenuatingTiles`: árboles, lápidas): la luz pasa
  pero cuesta `kAttenuationCost` (2.5) tiles extra.
- Las luces se suman; cada canal se recorta a 1 al combinar con el
  ambiente.

## 3. Emisores (datos)

`kLightDefs` (radio en tiles, intensidad, color, titileo) y
`kTileLights` (tile → luz). Nada de esto está en los pintores.

| Luz | Dónde | Radio | Intensidad | Titila |
|---|---|---|---|---|
| faro | faros del pueblo (`TownState.lights`) | 6 | 0.95 | 5 % |
| forja | tile de armería / forja | 5 | 0.9 | 12 % |
| fuente | fuente rúnica | 4 | 0.6 | no |
| portal | portal del eco | 5 | 0.75 | no |
| ventana | casas de los habitantes (una por casa) | 3 | 0.55 | 3 % |
| brasero | braseros encendidos de las misiones | 6 | 1 | 12 % |
| antorcha | paredes de mazmorras oscuras (una cada `kTorchEvery` = 29 paredes que dan a un piso) | 4.5 | 0.85 | 14 % |
| luciérnaga | luciérnagas de la noche (móviles) | 1.6 | 0.35 × parpadeo | no |
| flora | recolectables de los exteriores de bioma | 2.2 | 0.35 | no |
| pesca | puntos de pesca | 2 | 0.3 | no |
| botín | objetos legendarios en el piso | 2.5 | 0.5 | no |
| jugador_pueblo | cada jugador vivo, de noche al aire libre | 3.5 | 0.5 | no |
| jugador_oscuro | cada jugador vivo en mazmorra oscura | 6 | 1 | 4 % |

### 3.1 Luz que lleva el jugador

`LightRules.carried(dark:, bonus:)`. `bonus` (tiles extra de radio) es el
gancho para linternas, pasivas o beneficios de habitantes: hoy siempre 0.

### 3.2 Titileo

Las luces con `flicker > 0` (llamas) van a una capa aparte que se
multiplica por `LightRules.flicker(t)` (dos senos lentos, ±10 %). Con
REDUCIR MOVIMIENTO no titilan.

## 4. Dibujo y rendimiento

- La ventana de tiles = vista + margen (el radio más grande + 1),
  alineada a bloques de 16 tiles. Las luces fijas (tiles y faros) se
  calculan una vez por ventana y conjunto de luces; solo se recalculan
  si cambian (se cuentan en la línea de rendimiento: "luz N recálculos").
- Por cuadro: copia de la capa fija + capa de llamas × titileo + luces
  móviles (jugadores, luciérnagas, botín), que son pocas y de radio
  chico.
- Se dibuja como una malla (`Canvas.drawVertices`) con un vértice en el
  centro de cada tile y su color: la GPU interpola entre tiles (nada de
  bloques) y se multiplica sobre el mapa (`BlendMode.multiply`). Un solo
  llamado de dibujo, sin texturas ni shaders.
- Si el ambiente es blanco (de día, sin tormenta) la capa no se dibuja.

## 5. Ambiente

### 5.1 Aire libre

`LightRules.ambient`: de día blanco; con la oscuridad del reloj
(`SkyRules.darkness`) pasa por el color del atardecer (`LightPalette.dusk`)
hasta el azul oscuro de la noche (`LightPalette.night`). Lluvia y
tormenta lo oscurecen (hasta −45 % con tormenta).

### 5.2 Rayos

Mientras dura el destello de un rayo el ambiente vuelve al blanco
(× el factor de destellos de accesibilidad: con destellos apagados no
aclara).

### 5.3 Mazmorras oscuras

- `LightRules.isDark(theme, floor:)`: el tema `cavernas` siempre; el tema
  `abismo` en los pisos impares (0-based: el 2.º, 4.º...). Sale del tema y
  el piso, que todos los clientes ya tienen: no hay dato nuevo en la red.
- Ambiente casi negro (`LightPalette.darkDungeon`); se ve lo que alumbran
  los jugadores, las antorchas de pared y los braseros.
- Los enemigos fuera de la luz (brillo < `MapGame.darkSeen` = 0.12 × `keep`
  de § 7) no se dibujan; los jefes sí, siempre. En la batalla no hay
  oscuridad (deuda técnica).
- El mapa no tiene niebla de exploración hoy; el minimapa no se oscurece
  (deuda técnica).

## 6. Colores

En `LightPalette` (`map_themes.dart`). Las luces se distinguen sobre
todo por brillo y radio, no por matiz: se leen igual con cualquier modo
daltónico.

## 7. Accesibilidad: OSCURIDAD

Ajustes → PANTALLA → OSCURIDAD: NORMAL / SUAVE / APAGADA
(`DarknessLevel`, guardado como `darkness`). Cada canal final =
`1 − keep + keep × color`, con `keep` 1 / 0.45 / 0. APAGADA deja todo
como de día, también las mazmorras oscuras. El umbral para esconder
enemigos en la penumbra se multiplica por `keep`: con SUAVE se esconden
menos y con APAGADA se ven todos. Es solo visual: no cambia nada del
juego ni de la red.

## 8. Red

Sin cambios: todo se deduce del tema, el piso, el reloj y las
posiciones que ya viajan. Protocolo igual (51).

## 9. Tests

`test/game_engine/light_rules_test.dart`: caída con la distancia, muros
que cortan, árboles que atenúan, mazmorras oscuras, luz del jugador y
ambiente.
