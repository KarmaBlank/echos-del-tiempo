# Reflejos en el agua (v0.50.0)

Reflejos pixel art en el agua del mapa (pueblo, exteriores de bioma,
mazmorras con agua). Diseñados desde cero para el presupuesto de cuadro:
muchos actores, árboles, nubes y luces a la vez sin bajar FPS.

Código: reglas puras en `lib/game_engine/rules/reflection_rules.dart`
(qué se refleja, ondas, pasos de alfa, estela, tope de actores, tipo de
agua); dibujo en `lib/features/world/presentation/map/water_reflection_layer.dart`;
números en `kTuning[TuningId.regions]` (claves `refl*`, editables en
Balance › Regiones de bioma); ajuste del jugador en Opciones › Pantalla ›
REFLEJOS (`ReflectionLevel`: NO / BAJA / ALTA).

Estilo: 8-bit minimalista. Sin desenfoque, sin degradés suaves: todo
desplazamiento es de píxeles enteros y todo desvanecido es en 2-3 pasos
discretos.

## 1. Qué se refleja

1. **Actores** (jugadores, enemigos, PNJ, balsa) a ≤ `reflActorReach`
   tiles por encima del agua de su columna: sprite volteado en vertical
   con los pies en la línea del agua (el borde superior del primer tile
   de agua de esa columna). Sobre el agua (balsa) la línea es el pie + `reflFloatDrop` px, así el
   reflejo de la balsa y su jinete se lee debajo. Se
   reflejan como mucho `reflActorsHigh` (ALTA) o `reflActorsLow` (BAJA),
   los más cercanos al centro de la vista.
2. **Orilla**: los tiles de tierra de las `reflRows` filas sobre el agua
   (árboles y matas procedurales, casas, faroles, piedras de paso,
   rocas, y la propia orilla), volteados respecto de la línea del agua
   de su columna. Cada columna se recorta a sí misma (con sus vecinas
   dibujadas para que las copas que sobresalen también aparezcan).
3. **Cielo**: un velo del color del cielo y las nubes como manchas más
   claras: son LAS MISMAS nubes que dan sombra en tierra
   (`RegionLightLayer.cloudCells`, una sola generación): misma forma,
   posición, deriva y velocidad. Sobre tierra la celda es sombra; sobre
   agua que refleja el cielo, la misma celda es un reflejo claro (y no
   hay sombra): la nube pasa de sombra a reflejo justo en la orilla.
   Color según
   la hora: día celeste, atardecer/amanecer rosa anaranjado, noche azul
   oscuro. Al atardecer la superficie del agua además se tiñe de rosa
   cálido (`reflDuskTint`, encima de la luz, sin multiplicar).
4. **Noche**: cada luz (faroles, braseros, hogueras, la luz que lleva el
   jugador / el fuego errante) a ≤ `reflActorReach` tiles del agua deja
   un brillo compacto justo bajo su punto espejado (además del farol
   volteado de la orilla): un núcleo de 2 px y 2-4 trazos horizontales
   cortos, rotos por la onda, en 3 pasos duros de opacidad
   (`reflGlowAlpha`), de `reflGlowLen` px como mucho (≤ 1 tile). Sobre
   agua abierta, destellos de estrellas (`reflStars`) y un brillo de luna.
5. **Onda**: el reflejo se corta en tiras horizontales de 1 px (ALTA) o
   2 px (BAJA); cada tira se corre de costado un número entero de píxeles
   según una onda lenta (`reflWaveAmp`, `reflWaveSpeed`, `reflWaveRows`).
   Se tiñe hacia el color del agua del tema (`reflTint`) y se desvanece
   con la distancia a su línea de agua en 3 pasos (`reflFade1`,
   `reflFade2` px). Alrededor de un actor que se mueve sobre o junto al
   agua (o de la balsa) las tiras se rompen: más desplazamiento
   (`reflWakeAmp`) dentro de `reflWakeRadius` px, más espuma de 1 px en
   la estela de la balsa.

## 2. Tipos de agua

| Tipo | Dónde | Reflejo |
|---|---|---|
| agua | `~` / `f` al aire libre | todo, alfa `reflAlpha` |
| pantano | temas de `ReflectionRules.murkyThemes` | todo, alfa `reflMurkyAlpha` (más débil) |
| cueva | agua bajo techo de región, minas, mazmorras oscuras | solo estelas de luz |
| lava | `%` | nada (se queda su brillo) |

## 3. Arquitectura de rendimiento

- **Solo lo visible.** Una *ventana* alineada a 8 tiles alrededor de la
  vista (+ margen). La máscara de agua (segmentos horizontales de agua
  contigua por fila, tipo por segmento, línea de agua por columna) se
  arma solo cuando la ventana cambia (como la caché de niebla del cielo)
  o cambia el mapa. Sin agua en la ventana: costo cero.
- **Orilla en textura.** Los reflejos estáticos de la orilla se graban
  una vez por ventana en una imagen (ya volteados, desvanecidos y
  teñidos); cada cuadro solo se vuelven a ondular.
- **Un solo offscreen por cuadro.** Cada cuadro se graba UN `Picture`
  del tamaño del agua visible (la caja de los segmentos dentro de la
  vista, no la vista entera): la parte visible de la textura de la
  orilla (un `drawImageRect`), los actores volteados, el desvanecido por
  pasos (rects `srcATop` del ancho del actor) y el cielo y las nubes
  detrás (`dstOver`, un `drawRawPoints` por paso). Se convierte en
  imagen (`toImageSync`) y se dibuja con UN `drawRawAtlas` por tipo de
  agua: una entrada por tira de cada segmento de agua, con el origen
  corrido por la onda. El tinte hacia el color del agua es el
  `ColorFilter` de esa pintura (sin otra pasada). El recorte al agua
  sale gratis (las tiras solo cubren agua); no hay `saveLayer` ni
  `clipPath` por sprite.
- **Brillos de luz, destellos y el tinte del atardecer** se dibujan después del mapa de luz (si
  no, la noche las apaga), como rects sueltos con el mismo
  desplazamiento de onda (un `drawRawPoints` por paso).
- **Tope de actores** (`reflActorsHigh` / `reflActorsLow`).
- **Calidad automática**: con ALTA, si la media de los últimos 60
  cuadros pasa de `reflAutoLowMs` ms, se dibuja como BAJA hasta que baje.
- `reduceMotion`: la onda queda quieta (t = 0).

## 4. Orden de dibujo

Después de los tiles, el viento y las marcas del suelo, el loot y las
sombras de peces; antes de los actores (los reflejos quedan debajo de
todo lo que está parado). Los brillos de luz van después de la capa de
luz y antes del cielo (lluvia, niebla).

## 5. Rendimiento medido

`test/perf/reflection_perf_test.dart`: lago de 48 × 26 tiles que llena
una vista de 720 × 405 px, 24 actores (tope 16, uno en balsa), orilla
con árboles, rocas, faroles y piedras de paso, nubes al máximo y 12
luces de noche. Imprime el costo por cuadro sin y con reflejos,
separado en hilo de UI (grabar) e imagen (en los tests es raster por
software; en el juego es trabajo de GPU en el hilo de raster), y el de
armar una ventana nueva. Presupuesto igual que `light_perf`: < 4 ms por
cuadro de UI (medido: ~0.6-0.7 ms en ALTA, ~0.55 ms en BAJA; ventana
nueva ~10 ms, una vez cada 8 tiles de cámara).

## 6. Ajuste del jugador

`game.json` → `"reflections": "off" | "low" | "high"` (por defecto
`high`). NO: no se dibuja nada ni se arma ninguna caché.
BAJA: tiras de 2 px, `reflActorsLow` actores, sin estrellas.

## 7. Tests

- `test/game_engine/reflection_rules_test.dart`: onda entera y acotada,
  pasos de alfa, tipo de agua, ancla de actores, tope, estela.
- `test/features/world/water_reflection_layer_test.dart`: la máscara se
  arma una vez por ventana, sin agua no graba nada, NO no dibuja; una
  nube sobre la orilla es sombra en tierra y reflejo en el agua con las
  mismas celdas; sin costuras de tinte al cruzar el borde de una ventana.
- `test/perf/reflection_perf_test.dart`: presupuesto de cuadro.
- `test/features/world/water_reflection_preview_test.dart` con
  `REFLECT_PREVIEW=1`: `docs/preview/reflections/*.png` (día con
  actores, árboles y nubes; atardecer; noche con luces; estela de la
  balsa).
