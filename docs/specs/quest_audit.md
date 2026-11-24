# Auditoría de encargos (recadero o no)

Lista de todo encargo, pedido u orden que existe hoy y si es de **traer
cosas** (recadero: juntar, pescar o cultivar algo y entregarlo). **No se
borra nada**: para cada uno de traer cosas hay una alternativa propuesta;
decide el dueño. Las alternativas usan los objetivos de las historias de
eventos (world_events.md § 3.4): vencer, llegar/explorar, escoltar,
hablar, resistir/defender, resolver. Los textos de las alternativas son
BORRADOR.

Fuente: `assets/data/npcs/npcs.json` (cadenas), `ResidentRules`
(pedidos del pueblo, órdenes de entrega, encargos de forja) y
`BiomeFisherRules` (pedido del día del pescador).

## 1. Cadenas de encargos de los habitantes (`quests`)

| # | Habitante | Tipo | Objetivo | ¿Recadero? | Alternativa propuesta |
|---|---|---|---|---|---|
| 1 | Ilda | recolectar | 3 hierbas de rocío | Sí | **Explorar:** acompañar a Ilda al amanecer al claro donde crece la hierba y vencer al eco que la marchita antes de que salga el sol. |
| 2 | Ilda | pescar | 1 trucha musgosa | Sí | **Hablar:** la trucha "guarda el agua de un río más viejo": hablar con la peregrina del lago (evento de campo) para que cuente qué río era. |
| 3 | Ilda | cultivar | 2 helechos dulces | Sí | **Defender:** proteger la huerta del pueblo una noche de un eco que viene a comerse el helecho. |
| 4 | Ilda | mazmorra | Bosque Hondo (z2) | No | — |
| 5 | Velda | recolectar | 3 musgos de cobre | Sí | **Resolver:** el musgo crece sobre un mecanismo de las ruinas; ponerlo en marcha en el orden correcto. |
| 6 | Velda | pescar | 1 pez piñón | Sí | **Explorar:** seguir al pez piñón por el estanque de engranajes hasta la compuerta que abre (un lugar nuevo del exterior). |
| 7 | Velda | mazmorra | Ruinas Cronales (z3) | No | — |
| 8 | Kael | recolectar | 3 cristales de escarcha | Sí | **Resistir:** entrenamiento con Kael en las cavernas: aguantar oleadas de ecos helados sin retroceder. |
| 9 | Kael | pescar | 1 trucha de hielo | Sí (con lección) | **Hablar:** la lección es la paciencia: esperar con Kael en el lago helado hasta que aparezca el guardián y escuchar lo que dice. |
| 10 | Kael | élite | guardián del Laberinto (z6) | No | — |
| 11 | Brann | recolectar | 3 raíces ígneas | Sí | **Escoltar:** acompañar a Brann a la grieta a ver la fragua vieja que encontró abajo, sin que lo ataquen. |
| 12 | Brann | cultivar | 2 chiles de volcán | Sí | **Defender:** cuidar la fragua del pueblo mientras Brann templa una pieza (oleadas cortas en el pueblo). |
| 13 | Brann | mazmorra | Grieta Ígnea (z7) | No | — |
| 14 | Oren | recolectar | 3 polvos de eco | Sí | **Vencer:** el polvo es lo que deja el futuro al pasar: vencer al eco que lo deja en el mar de ecos. |
| 15 | Oren | pescar | 1 pez eco | Sí | **Hablar:** "ya lo pescaste; todavía no lo sabés": hablar con Oren después de pescar cualquier pez en el mar de ecos (el pez llega solo). |
| 16 | Oren | cultivar | 2 espigas de trigo del eco | Sí | **Explorar:** llegar al borde del abismo donde el trigo del eco crece del futuro y volver a contarlo. |
| 17 | Oren | mazmorra | Abismo (z9) | No | — |

Resumen: 17 pasos; **12 son recadero** (recolectar, pescar, cultivar) y
5 no (mazmorra, élite).

## 2. Pedidos del pueblo (`ResidentRequest`)

| Pedido | ¿Recadero? | Nota |
|---|---|---|
| Subir mi casa de nivel | No | Construir en el pueblo. |
| Un camino hasta mi puerta | No | Construir. |
| Un faro cerca de mi casa | No | Construir. |
| Una huerta cerca de mi casa | No | Construir. |
| Un lago con muelle cerca de mi casa | No | Construir. |

Ninguno es recadero: son de construcción (town_editor.md § 3.4).

## 3. Órdenes de entrega (`ResidentRules.newOrder`)

| Orden | ¿Recadero? | Alternativa propuesta |
|---|---|---|
| 2 a 4 cultivos o 1 a 2 pescados de su bioma (con calidad o tamaño mínimo), cada `orderEveryDays` | Sí (es el recadero puro) | **Pedido de oficio con momento:** en lugar de traer N cosas, "vení a pescar conmigo al amanecer" (pescar junto al habitante en su lago en una franja del día) o "ayudame a cosechar antes de la tormenta" (cosechar en la huerta del pueblo con el habitante presente). Mismo XP de oficio, pero es una escena y no una entrega. |

## 4. Encargos de forja de Brann (`commission*`)

| Encargo | ¿Recadero? | Nota / alternativa |
|---|---|---|
| Arma a pedido: oro + materiales condensados + botín de su bioma | Parcial (paga con materiales, no es una misión de juntar) | Es una compra con costo en materiales, no un encargo. Alternativa opcional: que el arma legendaria pida además **vencer** al jefe de la grieta de eco de la Grieta (evento) para templarla. |

## 5. Pedido del día del pescador nativo (`BiomeFisherRules.request`)

| Pedido | ¿Recadero? | Alternativa propuesta |
|---|---|---|
| 1 a 3 peces del lago del bioma con tamaño mínimo, uno por día | Sí | **Desafío en la orilla:** pescar junto al pescador y ganarle (el pez más grande en N tiros, o el primero en sacar uno de cierta rareza). Es pesca, pero es una competencia y no una entrega. |

## 6. Resumen

| Fuente | Total | Recadero | No |
|---|---|---|---|
| Cadenas de habitantes | 17 | 12 | 5 |
| Pedidos del pueblo | 5 | 0 | 5 |
| Órdenes de entrega | 1 generador | 1 | 0 |
| Encargos de forja | 1 generador | 0 (compra) | 1 |
| Pedido del pescador | 1 generador | 1 | 0 |

Las historias de los eventos del mundo (world_events.md) ya nacen sin
recadero: el editor solo ofrece objetivos de vencer, explorar, escoltar,
hablar, resistir o resolver.
