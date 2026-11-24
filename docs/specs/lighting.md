# Iluminación (v0.36.2)

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
  escala) se propaga tile a tile (relleno por inundación) por el camino
  más corto con 8 vecinos (paso recto 1, diagonal √2) desde el centro de
  su tile, hasta `radius + 1.5`. Eso decide a dónde llega (oclusión) y
  cuánto rodeo hace.
- Distancia de cada tile: `d = recta(posición exacta de la fuente,
  centro del tile) + rodeo`, con `rodeo = máx(0, camino − recta desde el
  centro del tile de la fuente × (1 + 0.0824))`. El 0.0824 es lo que un
  camino de 8 vecinos se pasa de la recta en el peor ángulo: así en campo
  abierto la luz es redonda (no octogonal) y solo cuentan los rodeos de
  verdad (muros, esquinas, árboles).
- La luz sigue a la fuente al instante: sin suavizado en el tiempo, sin
  estela. Como se mide desde la posición exacta (no desde el tile), al
  moverse dentro de un tile la luz se corre con ella en vez de quedarse
  atrás y saltar (eso era la "estela" de v0.32.0).
- Caída suave: brillo = `intensity × escala × (1 − d/r)²`, por el color
  de su `tint`: radial, sin borde duro (pendiente 0 en el radio).
- Tiles opacos (`kOpaqueTiles`: muros, rocas, paredes agrietadas, atajos,
  engranajes, barrera): se iluminan pero la luz no sigue. Por una
  diagonal entre dos opacos no se cuela.
- Tiles que atenúan (`kAttenuatingTiles`: árboles, lápidas): la luz pasa
  pero cuesta `kAttenuationCost` (2.5) tiles extra.

### 2.1 Sombras nítidas (v0.36.2)

- Además del camino, cada muestra tiene que verse desde la posición
  exacta de la fuente en línea recta (recorrido de celdas exacto contra
  los opacos; no cuentan la celda de partida ni la de llegada; por la
  esquina justa entre dos opacos en diagonal no pasa). Si no se ve, no
  recibe nada de esa luz: detrás de un muro queda la sombra, sin la
  mancha borrosa que dejaba la luz al "rodear" el muro.
- De un tile opaco solo se ilumina la mitad que da a la fuente (producto
  punto ≥ 0 respecto del centro del tile): la luz no se filtra al otro
  lado de un muro de un tile.
- Los rodeos del camino siguen sirviendo para los que atenúan (árboles).
- Si en la ventana local de una luz no hay ningún opaco, no se tiran
  rayos (camino rápido: pueblo abierto, praderas).
- Opacos desde v0.36.2: además de muros y rocas, los edificios y
  estructuras sólidas del pueblo y los biomas: casas, forja, armería,
  taller, tablero, puesto, fuente, estatua, portal y torre del loot. Los
  árboles y lápidas siguen atenuando. Agua, carteles, puntos de pesca y
  matas no tapan.

### 2.2 Luces sobre un edificio

Un emisor cuyo tile es opaco (ventana de una casa, brillo de la forja,
fuente, portal) lleva el rectángulo de su estructura (`LightSource.own*`,
tramo de fila y columna del mismo tile, `LightRules.structureOf`): para
esa luz el edificio es transparente, así alumbra hacia afuera por todos
los lados en vez de oscurecerse a sí mismo. Para las demás luces el
edificio tapa.
- Las luces se suman; cada canal se recorta a 1 al combinar con el
  ambiente; luz que sigue la posición exacta (sin estela) y caída redonda.
`test/game_engine/lantern_test.dart`: faroles solo en pisos oscuros,
sin cortar el paso ni pisar otros PdI, y [E] los enciende.
`test/game_engine/fog_of_war_test.dart`: explorado que se recuerda,
visible solo en el cuadro, reinicio por misión.
`test/features/world/light_layer_test.dart`: la malla cubre los bordes
del mapa (alineación de la ventana hacia abajo con negativos).

## 3. Emisores (datos)

`kLightDefs` (radio en tiles, intensidad, color, titileo) y
`kTileLights` (tile → luz). Nada de esto está en los pintores.

| Luz | Dónde | Radio | Intensidad | Titila |
|---|---|---|---|---|
| faro | faros del pueblo (`TownState.lights`; v0.40.1, antes 6 / 0.95: casi no se notaban) | 11 | 1.4 | 5 % |
| forja | tile de armería / forja | 5 | 0.9 | 12 % |
| fuente | fuente rúnica | 4 | 0.6 | no |
| portal | portal del eco | 5 | 0.75 | no |
| ventana | casas de los habitantes (una por casa) | 3 | 0.55 | 3 % |
| brasero | braseros encendidos de las misiones | 6 | 1 | 12 % |
| antorcha | paredes de mazmorras oscuras (una cada `kTorchEvery` = 29 paredes que dan a un piso) | 4.5 | 0.85 | 14 % |
| luciérnaga | luciérnagas de la noche (móviles; v0.36.2, antes 1.6 / 0.35) | 3 | 0.6 × parpadeo | no |
| flora | recolectables de los exteriores de bioma | 2.2 | 0.35 | no |
| pesca | puntos de pesca | 2 | 0.3 | no |
| botín | objetos legendarios en el piso | 2.5 | 0.5 | no |
| jugador_pueblo | cada jugador vivo, de noche al aire libre (v0.36.2, antes 3.5 / 0.5) | 4.5 | 0.6 | no |
| jugador_oscuro | cada jugador vivo en mazmorra oscura sin Llama errante (v0.41.3, antes 11; con la Llama: 11 / 1.5, § 3.1.1) | 5.5 | 1 | 4 % |
| hongo / cristal / magitec / fatuo / ascua / enjambre | luz natural del tema (§ 3.3) | 4–5 | 0.55–0.7 | ascua 10 % |
| guía | llegada y escaleras de cada piso (§ 3.3) | 6 | 0.9 | 5 % |
| farol | faroles encendidos de las mazmorras oscuras (§ 5.5; v0.36.2, antes 11) | 13 | 1 | 4 % |

### 3.1 Luz que lleva el jugador

`LightRules.carried(dark:, bonus:)`. `bonus` (tiles extra de radio) es el
gancho para linternas, pasivas o beneficios de habitantes: hoy siempre 0.

En la oscuridad, sin la Llama errante, el radio es 5.5 (v0.41.3; 11 en
v0.36.2, 9 en v0.32.2, 6 antes): se ve a un enemigo hasta ~3.6 tiles
(`r × (1 − √0.12)`). Con la Llama errante (§ 3.1.1) vuelve al radio 11 y
más brillante. De noche al aire libre: radio 4.5, intensidad 0.6.

### 3.1.1 Llama errante (v0.37.0, v0.37.2)

Una llamita que acompaña al jugador. Es el eco de una luz que todavía no
se encendió: alumbra más, pero en lo profundo también se deja ver.

- Cuándo está prendida: `LightRules.wispActive(toggled:, outdoor:, night:)`.
  Al aire libre (mundo y pueblo, `SkyRules.outdoor`) va sola de noche
  (`SkyRules.isNight`) y se apaga de día; L no hace nada ahí. En
  mazmorras nunca es automática: se prende y se apaga con L (fuera de
  batalla), como en v0.37.0.
- Luz en mazmorra oscura (v0.41.3): `carried(dark: true, wisp: true)`
  multiplica el radio por `wispDarkRadiusFactor` (2: 5.5 → 11) y sube la
  intensidad a `wispDarkIntensity` (1.5; sin la Llama, 1). Antes la Llama
  sumaba 5 tiles a un radio de 11 con la misma intensidad: lo cercano ya
  saturaba (mín(1, luz), § 4) y la ganancia quedaba fuera de pantalla o
  tras las paredes; prendida o apagada se veía igual.
- Luz al aire libre: `carried(dark: false, wisp: true)` suma
  `LightRules.wispBonus` (5 tiles) al radio y sube la intensidad a `wispIntensity` (1) como
  mínimo. v0.37.2: antes solo sumaba 3 tiles al radio con la misma
  intensidad; con la caída cuadrática la ganancia quedaba en la franja
  tenue, bajo el umbral de penumbra (`seenLum` = 0.12), y en el pueblo
  (intensidad 0.6) casi no se notaba. `visibleRadius(def)` mide hasta
  dónde se distingue algo; con la Llama crece más de 2.5 tiles.
- Contra: solo en mazmorra oscura (`isDark`) y prendida a mano, los
  enemigos lo detectan desde `SessionEngine.aggroRange ×
  LightRules.aggroFactor(wisp:, dark:, outdoor:)` (× 1.5). Al aire libre
  de noche no castiga: es automática y no se puede apagar. Lo calcula el
  host por jugador.
- Movimiento: flota sobre la cabeza del personaje (unos 24 px arriba)
  con un vaivén lento (senos de pocos ciclos por minuto) y lo sigue con
  retraso suave (acercamiento exponencial). Deja dos ecos tenues de sus
  posiciones recientes. Nada de órbitas rápidas.
- Dibujo: procedural (punto de luz con halo, `LightPalette.wispCore` /
  `wispHalo`). Sin sprite.
- Los demás la ven: el estado a mano (`wisp`) viaja en el snapshot (§ 8);
  la de la noche cada cliente la deduce del cielo.

### 3.2 Titileo

Las luces con `flicker > 0` (llamas) van a una capa aparte que se
multiplica por `LightRules.flicker(t)` (dos senos lentos, ±10 %). Con
REDUCIR MOVIMIENTO no titilan.

### 3.3 Luz natural (v0.36.2)

Todo lugar que puede quedar a oscuras (exteriores y mazmorras al aire
libre de noche, pisos oscuros) se tiene que poder jugar sin depender
solo de la luz del jugador. `LightRules.ambientEmitters`:

- `kAmbientLights` (catálogo, por tema): una luz temática en uno de cada
  `every` tiles caminables, elegidos por hash de la posición (el mapa
  sale de la semilla: determinista y igual en todos los clientes). Es
  solo luz: no cambia el mapa ni corta el paso. Pradera y mundo:
  enjambres de luciérnagas; bosque: hongos; ruinas, laberinto y corazón:
  lámparas magitec; cavernas y abismo: cristales; fortaleza y grieta:
  ascuas; cementerio: fuegos fatuos. El pueblo no tiene (tiene faros).
- Luz guía (`guia`, radio 6) en la llegada y las escaleras de cada piso,
  también en los pisos de faroles (§ 5.5): el arranque no es negro.
- Se ve la forma del lugar; los rincones lejos de todo quedan en
  penumbra. `test/game_engine/natural_light_test.dart` mide, sin
  jugadores, la fracción de tiles caminables a la vista (≥ 0.12) por
  tema y exige más del 20 % (y menos del 90 %). Hoy: pradera 44 %,
  bosque 62 %, ruinas 55 %, cavernas 61 %, fortaleza 51 %, laberinto
  52 %, grieta 58 %, cementerio 26 %, abismo 25 %, corazón 31 %,
  exterior del bosque 78 %.
- Pendiente: un dibujo propio para cada emisor (hoy es el brillo).

### 3.4 Luciérnagas y luces puestas (v0.40.1)

Las luciérnagas no se juntan donde hay luz puesta (hoy, los faros del
pueblo). `LightRules.fireflyFade(x, y, luces, radius:)`, con el radio del
faro: más allá del radio, brillo normal; dentro de `fireflyInner` (0.45)
× radio, nada; en el medio baja con smoothstep, así al acercarse a un
faro se van apagando de a poco y no de golpe. Una de cada
`fireflySurvivorEvery` (7, por el hash de su celda) sobrevive con brillo
mínimo `fireflySurvivorAlpha` (0.7): en una zona iluminada queda alguna
que otra suelta. En la oscuridad no cambia nada. Afecta el punto dibujado
y su luz móvil (`luciernaga`). Solo decorado: no viaja.

## 4. Dibujo y rendimiento

- La ventana de tiles = vista + margen (el radio más grande + 1),
  alineada a bloques de 16 tiles siempre hacia abajo (también con
  negativos: si no, en el borde de arriba o la izquierda la malla
  arrancaba en el centro del tile 0 y media fila quedaba sin oscurecer). Las luces fijas (tiles y faros) se
  calculan una vez por ventana y conjunto de luces; solo se recalculan
  si cambian (se cuentan en la línea de rendimiento: "luz N recálculos").
- Por cuadro: copia de la capa fija + capa de llamas × titileo + luces
  móviles (jugadores, luciérnagas, botín), que son pocas y de radio
  chico.
- Resolución: 2 × 2 muestras por tile (`MapLightLayer.sub`, v0.36.2;
  `LightGrid.sub`). El borde de una sombra se resuelve en medio tile en
  vez de uno. `LightGrid.lum(tx, ty)` (enemigos en la penumbra, niebla)
  devuelve el máximo de las muestras del tile: con verse un pedazo
  alcanza.
- Se dibuja como una malla (`Canvas.drawVertices`) con un vértice por
  muestra y su color: la GPU interpola (nada de bloques) y se multiplica
  sobre el mapa (`BlendMode.multiply`). Los índices son de 16 bits: la
  malla se parte en bandas de filas de < 65 536 vértices (un llamado por
  banda; casi siempre uno o dos). Las posiciones se guardan entre
  cuadros; el color se arma en un bucle sin closures.
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
- "A la vista" = brillo ≥ `MapGame.darkSeen` = 0.12 × `keep` (§ 7).
- Los enemigos que no están a la vista no se dibujan en el mapa; los
  jefes sí, siempre. En la batalla no hay oscuridad (deuda técnica).
- La luz no atraviesa muros (§ 2): por un pasillo se ve hasta la
  esquina y lo de atrás aparece recién al avanzar.

### 5.4 Niebla del minimapa

Solo en mazmorras oscuras (§ 5.3) y con OSCURIDAD distinta de APAGADA.
`FogOfWar` (`lib/game_engine/models/fog_of_war.dart`, Dart puro) vive en
el `SessionController`: es del cliente y del jugador local, no viaja por
la red ni se guarda.

- Cada cuadro, después de la luz, se marcan "a la vista" los tiles de la
  ventana de luz que llegan al umbral de § 5.3, y se suman a lo
  explorado. Los muros se iluminan (§ 2), así que el contorno queda.
- Lo explorado dura toda la misión (todos los pisos: el atlas los tiene
  en zonas distintas). Otra misión (`missionId` + `seed`) o salir de la
  mazmorra oscura lo borra.
- Minimapa y mapa grande (M): lo no explorado se tapa con el color del
  vacío (máscara de 1 px por tile, rehecha solo cuando se descubre algo).
  Rejas, cofres, objetivos, PdI e íconos de loot solo se marcan en lo
  explorado. Los enemigos (jefes incluidos) solo mientras están a la
  vista en ese cuadro: nunca en lo recordado. Los jefes no: se ven
  siempre, como en el mapa. Los aliados también, siempre.
- Los objetivos de la misión (fragmentos y sellos) se marcan siempre,
  aunque estén en la niebla: la niebla tapa el camino, no la meta.
- Vida de la niebla: toda la misión en curso (§ 5.6).

### 5.5 Faroles

- `PoiKind.lantern`, tiles `l` (apagado) y `n` (encendido), sólidos. Se
  dibujan como el faro del pueblo (poste y brasero).
- Solo en los pisos oscuros (§ 5.3) de los atlas de zona (también Ecos y
  Abismo). Los pone `MapGenerator.zone` después de armar el piso, con su
  propia tirada (`mulberry32(semilla_f ^ 0x1A7E)`): el resto del piso
  sale igual que antes.
- Lugar: un tile de piso con los 8 vecinos caminables (nunca corta un
  pasillo), fuera de la arena del jefe, de las salas secretas y a 3+
  tiles de la llegada, las escaleras y los otros PdI. Entre faroles,
  12+ tiles. Uno cada `kLanternArea` = 160 tiles caminables del piso
  (al menos 2, como mucho 12). El tile deja de ser lugar de enemigos.
- Ids: `piso × 100 + 99 − k` (los otros PdI usan los primeros números).
- [E] Encender el farol (`InteractPoiAction`, el host decide, como los
  braseros): pasa a `poiUsed`, el tile pasa a `n` y emite la luz `farol`
  (radio 13; siempre más que la luz del jugador) para siempre en la misión. Con todos los faroles de una
  zona prendidos, la zona queda casi a la luz.
- En el minimapa: como los braseros (apagado / encendido), detrás de la
  niebla.

### 5.6 Persistencia

- Faroles: en `MissionRun.poiUsed`, que ya viaja en el snapshot y se
  guarda con la run: compartidos por el grupo y del host.
- Niebla: del cliente, toda la misión (§ 5.4).
- v0.34.0 (persistent_dungeons.md): las mazmorras de zona tienen semilla
  fija por mundo y su `MissionRun` se guarda en el mundo, así que los
  faroles encendidos quedan para siempre en ese mundo (no se apagan con
  la reaparición). La niebla se guarda por jugador en su dispositivo
  (`FogOfWar.archive`, `accounts/fog.json`, § 2.3 de ese spec). Ecos,
  Pruebas y Abismo siguen siendo nuevos en cada entrada: faroles y
  niebla duran esa visita.

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

Todo se deduce del tema, el piso, el reloj y las posiciones que ya
viajan; la niebla es solo del cliente. Los faroles cambian el mapa que
sale de la semilla y agregan `PoiKind.lantern` a los eventos: protocolo
54.

Llama errante (§ 3.1.1): acción `wisp` (`on`) del jugador y campo `wi`
del jugador en el snapshot (solo si está prendida): protocolo 60
(v0.37.0). No se guarda en el perfil: al entrar arranca apagada.

## 9. Tests

`test/game_engine/light_rules_test.dart`: caída con la distancia, muros
que cortan, árboles que atenúan, mazmorras oscuras, luz del jugador y
ambiente.
v0.36.2: muro que deja oscuro el otro lado de un farol, borde de sombra
nítido en 2 × 2, edificio que tapa una antorcha y emisor sobre un
edificio que igual alumbra alrededor. `test/perf/light_perf_test.dart`
mide con 2 × 2 y `test/perf/town_soak_perf_test.dart` controla que el
pueblo no se ponga más lento.
v0.40.1: `fireflyFade` (lejos, adentro, medio suave y sobrevivientes) y faro más fuerte que la luz del jugador del pueblo.
