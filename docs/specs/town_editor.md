# Spec: Edición del pueblo (v0.24.0)

El dueño del mundo arma su pueblo a mano: amplía hacia cualquier lado,
pone lagos y huertas donde quiere, los mueve, funde lagos y suelta
peces en cada uno. Reemplaza a las franjas al este con espacios LAGO /
HUERTA de v0.23 (`farming.md` § 6). Código: `TownState` (modelo),
`TownRules` (reglas), `TownPlan` (el mapa), `ConstructionDef`
(catálogo), `TownEdit` + `TownEditOverlay` + `TownEditLayer` (UI).

## 1. Modo edición

### 1.1 Entrar y salir
- FUENTE RÚNICA (v0.25.7): panel chico con una grilla de acciones
  grandes (`DsButton` con una línea de detalle cada una; bloqueada = gris
  con el motivo en esa línea): EDITAR PUEBLO, CONTRATAR GRANJERO,
  CONTRATAR PESCADOR (farming.md § 8.1), TABLERO DE ENCARGOS, y CERRAR
  abajo. Sin contador de ampliaciones.
- EDITAR PUEBLO (v0.28.0): cualquiera de la sala, de a uno (§ 1.3).
  Mientras otro edita, el botón (y CONTRATAR GRANJERO / PESCADOR) sale
  gris con "Está editando <nombre>" en su línea y en el tooltip.
- El personaje se queda donde está (no camina, no pesca, E no hace
  nada). La cámara queda libre: WASD / flechas, arrastrar con el mouse,
  rueda para zoom (1×, 1,5×, 2×). Puede salirse del mapa hasta una
  franja por lado para ver las ampliaciones fantasma.
- Esc vuelve un paso (cierra el menú, suelta la pieza elegida o cancela lo que se mueve); en el
  paso base sale. LISTO [ESC] sale siempre.
- Los demás siguen jugando. Cada cambio es una acción al anfitrión, que
  lo valida y lo manda en el estado: todos ven el pueblo nuevo al toque.

### 1.3 Candado de edición (v0.28.0, protocolo 50)
- El anfitrión guarda quién edita (`GameSession.townEditor`, `ted`).
  Entrar manda `town lock`: lo da si está libre (o ya es tuyo). Salir
  (LISTO / Esc) manda `unlock`.
- Se suelta solo si quien lo tiene se va de la sala, deja el pueblo
  (mazmorra, viaje) o deja de estar en la sala del pueblo (lo revisa el
  tick del anfitrión).
- `expand`, `place`, `move`, `remove` y las acciones de ayudantes se
  validan contra quien tiene el candado; sin candado, contra el dueño.
  Si el candado es de otro, la edición local se cierra.

### 1.2 Pasos (clic sin arrastrar)

v0.40.1: primero se elige QUÉ poner y después DÓNDE (antes era al
revés: clic en un tile libre y después la lista).

- Al entrar se abre la ventana CONSTRUIR (v0.42.7): una ventana GRANDE
  centrada en la pantalla, como el INVENTARIO, con la PALETA
  (`TownBuildPalette`): todo lo que se puede poner (`kConstructions` +
  el faro) en una grilla de casillas amplias (`DsItemCell` + nombre) a
  la izquierda y el detalle (`DsDetailPane`, ~42 % del ancho, 280–460 px)
  a la derecha. Casillas de 80 px (miniatura + nombre en Cuerpo). El
  detalle usa la tipografía del sistema: nombre en Título, tamaño y costo
  en Detalle, descripción en Cuerpo; entra sin scroll desde 1280×720 a
  escala 1.0 (el scroll queda solo de reserva para escalas enormes).
  Categorías con filtros arriba (TODO · CULTIVO · AGUA · HOGAR · LUZ),
  nunca secciones apiladas. Tamaño: ancho de la pantalla − 64
  (320–1100) por alto − 48 (240–680).
- Elegir → detalle → acción fija (v0.46.1, design_system.md § "Grilla +
  detalle"): un clic ELIGE la pieza (casilla marcada) y NO cierra la
  ventana; el detalle muestra la elegida y queda fijo (mover el mouse a
  otras casillas o a la barra del detalle no lo cambia). El hover solo
  previsualiza mientras no hay nada elegido. Se coloca con el botón
  primario COLOCAR fijo abajo del detalle; atajos: doble clic en la
  casilla o Enter. Flechas mueven la elección, Esc cierra. Si no se
  puede pagar, COLOCAR queda gris y el motivo va en el detalle.
- Miniaturas (`TownPiecePreview`): nunca dibujan fuera de su caja
  (recorte), con margen, sin deformar y a escala entera si es ≥ 1; el
  faro (brasero + resplandor 11 px sobre su tile) se achica para entrar.
- COLOCAR CIERRA la ventana: el mapa queda libre para poner la pieza.
  En el borde derecho, arriba, queda un botón fijo `CONSTRUIR ▸` (con la
  pieza en curso: `CONSTRUIR ▸ Huerta chica`) que la vuelve a abrir. El
  jugador la abre o cierra cuando quiere: el botón, CERRAR, un clic
  fuera de la ventana o Esc (Esc cierra primero la ventana; con la
  ventana cerrada vuelve un paso o sale, como siempre).
- El botón va arriba de la columna de la derecha: el menú del paso y
  el panel de info van debajo, así nunca lo tapan ni lo corren. LISTO
  sigue en la barra; contratar y elegir casa no muestran ni ventana ni
  botón. Poniendo, la columna no muestra menú (la ayuda y el motivo
  del rojo van en la barra; se suelta con Esc o clic en la casilla).
- Cada casilla muestra la MINIATURA de la pieza (v0.42.9,
  `TownPiecePreview`) con el mismo arte del mapa: la casa es su sprite
  del manifest (`items.vida_casa_1`); huertas y lagos se dibujan con los
  pintores del mapa (`TilePainter`: tierra con parcelas aradas, agua con
  las esquinas de pasto) y el faro con `TilePainter.faro`, todo escalado
  a la casilla. Sin poder pagar, la miniatura va atenuada. El tamaño
  (p. ej. `6×4`) es una etiqueta chica en la esquina de arriba a la
  derecha. El detalle muestra arriba la misma miniatura en grande
  (96 px) de la pieza bajo el mouse o elegida.
- Debajo de la casilla va el nombre completo
  en hasta dos renglones, cortando solo entre palabras; si no entra se
  acorta con "…" y el nombre va en un tooltip (ancho y letra fijos del
  DS) que no recibe el mouse.
- Sin parpadeo (v0.42.6): casillas y grilla + detalle tienen tamaño
  FIJO; pasar el mouse cambia solo el contenido del detalle, nunca el
  tamaño de la ventana ni la posición de una casilla, así el clic
  siempre elige la pieza.
- Casilla que no se puede pagar: gris (sin tooltip: el motivo es común
  y el detalle ya muestra el costo en rojo).
- Clic en una casilla habilitada → paso `placing`: el fantasma sigue al
  mouse, verde si entra y rojo (con el motivo en la barra y en el
  detalle) si no. Clic en el mapa donde es válido lo pone; donde no,
  no hace nada. La pieza SIGUE elegida para poner otra igual; se suelta
  con Esc o un clic en la misma casilla. Elegir otra casilla
  cambia la pieza.
- Sin pieza elegida, el clic en el mapa elige lo que ya está puesto:

| Clic en | Abre |
|---|---|
| Franja fantasma de un lado | AMPLIAR AL <LADO> con el costo (pasar el mouse ya lo muestra en el panel de info) |
| Lago (o su cartel) | AGREGAR ESPECIES · MOVER · BORRAR LAGO |
| Huerta (o su cartel) | MOVER · BORRAR |
| Faro | MOVER · BORRAR |
| Lugar fijo (fuente, portal, tablero, forja, estatua, comerciante, loot perdido, taller de oficios, armería) | MOVER (no se borran; § 3.3) |
| Tile libre | nada (la paleta sigue a la derecha) |

MOVER deja un fantasma que sigue al mouse (verde si entra, rojo con el
motivo en la barra si no); un clic lo deja ahí (esa es la confirmación)
y CANCELAR / Esc lo descarta. La esquina superior izquierda del
fantasma va en el tile del mouse.

### 1.3 Dibujo (legible desde v0.24.2)
- Mientras se edita se oculta el HUD normal (TITULO, MENÚ, ALIJO,
  pociones, chat, ficha del personaje, barra de herramientas y los
  tooltips flotantes de los carteles). Solo queda la barra de edición
  arriba, a todo el ancho y con fondo opaco: EDICIÓN DEL PUEBLO, una
  ayuda corta de una línea (se corta con "…") y LISTO [ESC].
- Franjas fantasma celestes. Encima, en px de pantalla
  (`TownStripCards`), una tarjeta centrada en la parte visible de cada
  franja (debajo de la barra y a la izquierda de la columna derecha):
  AMPLIAR y el costo de a un recurso por renglón, "Oro 1500 (tenés
  60000)", verde si alcanza y rojo si no (`TownRules.costLines`). Se
  achica para entrar en la franja; si la parte visible es muy chica no
  se muestra. Borde dorado con el mouse encima o elegida.
- Lado al tope (v0.25.7, `TownRules.sideFull`): la franja sale gris y su
  tarjeta dice AMPLIAR en gris con "Límite de ampliación alcanzado" (tope
  total) o "Límite de este lado" (tope por lado), sin costo; el clic no
  hace nada. Ningún contador "n/6" (ni en la fuente ni en AMPLIAR AL
  <LADO>).
- Contorno de cada construcción (dorado la elegida) y fantasma verde /
  rojo. Colores en `TownEditPalette`.
- Debajo de la barra, a la derecha, una sola columna (30 % del ancho,
  entre 240 y 320 px): arriba el botón CONSTRUIR (§ 1.2) si la ventana
  está cerrada, el menú del paso y, debajo, el panel de info de la construcción bajo
  el mouse (su cartel). Con otro menú abierto no aparece. La barra: ayuda corta en hasta dos renglones, sin "…".
- Validación de MOVER (§ 3.2): el borde del pueblo es de un tile (la
  fila de árboles), así cada construcción puede volver a su propio lugar
  o correrse pisando el que deja.

### 1.4 Etiquetas del mapa
- Con zoom las etiquetas se achican con el mapa (la unidad de letra sale
  de la escala dividida por el zoom).
- Lugares del pueblo y carteles de construcciones tienen prioridad
  (lugares primero, en el orden de `TownLayout.landmarks`) y no se pisan
  entre sí, también jugando: cada una, en orden, prueba quedarse, subir
  uno o dos renglones o bajar uno, con un margen a los costados; si no
  entra, se oculta (`placeLabels`, función pura). Nunca se cortan en el
  borde de la pantalla: se corren hacia adentro. Nombres de jugadores y
  avisos no participan.

## 2. Ampliaciones por lado
- Cada ampliación suma una franja de `kTownStrip` (8) tiles al norte,
  sur, este u oeste. Tope total `maxExpansions` (6) y por lado
  `maxPerSide` (3), Editor → Balance → Pueblo. Costo de la n-ésima (en
  total, sin importar el lado): el de `farming.md` § 6.
- La franja es terreno libre: no trae nada puesto.
- 2.2 Coordenadas: todo se guarda en coordenadas del pueblo base. El
  mapa pone el origen del pueblo base en (8 × oeste, 8 × norte)
  (`GameMap.townOrigin`). Al ampliar al norte o al oeste, el anfitrión
  corre a todos los del pueblo y les sube el `epoch` (así el cliente
  toma la posición nueva) y la cámara de la edición acompaña.

## 3. Construcciones
### 3.1 Catálogo (`kConstructions`)
| id | Tipo | Huella |
|---|---|---|
| `huerta` | HUERTA | 6 × 4 (24 parcelas) |
| `huerta_chica` | HUERTA | 4 × 3 (12) |
| `lago` | LAGO | 6 × 6 |
| `lago_chico` | LAGO | 4 × 4 |

Para sumar un tipo: valor en `BuildKind`, entrada en el catálogo y cómo
se dibuja en `TownPlan`. Poner es gratis: lo que se paga es el terreno.

### 3.2 Validación (anfitrión, `TownRules.place` / `move`)
- Dentro del pueblo (sin tocar los dos tiles de bosque del borde), con
  su cartel adentro.
- Sin pisar los caminos fijos (frente de los edificios, eje norte-sur
  hasta el borde sur, anillo de la fuente, ramal del lago y la torre)
  ni los lugares con un tile de margen.
- Sin pisar otra construcción ni un cartel. Huertas pegadas sí. Un lago
  que toca o pisa otro lago se funde (§ 4.2).
- Alcanzable: después del cambio, toda construcción tiene camino (§ 4.1).
- Los árboles sueltos debajo de una construcción desaparecen.

### 3.3 Lugares fijos (v0.25.2)
Todos los lugares de `TownLayout.landmarks` (FUENTE RÚNICA, PORTAL,
TABLERO DE ENCARGOS, FORJA, ESTATUA DEL TIEMPO, el puesto del
comerciante, LOOT PERDIDO y, desde v0.32.3, TALLER DE OFICIOS y ARMERÍA) se pueden
mover; nunca borrar. Id de
edición: `@` + el `TownSpot` (`@forge`, `@fountain`, …). Mismo fantasma
verde / rojo; la esquina va en el tile del mouse.
- Posición: `TownPlan.landmarksOf(town)` (los movidos donde quedaron,
  el resto en su lugar de siempre). Pueblos guardados antes de v0.32.3:
  el TALLER DE OFICIOS sin marca va a (6, 6) y la ARMERÍA a (26, 6)
  (`TownLayout.lateSpots`, en ese orden); si ahí ya hay algo (una
  construcción a menos de 2 tiles, un faro, un árbol, un camino fijo u
  otro lugar movido a menos de 1), va al hueco libre más cercano
  (distancia Manhattan) sin guardar marca, hasta que el dueño lo mueva. De ahí salen el dibujo, las
  etiquetas, los E (`WorldRules.townSpot` con `GameMap.townMarks`), los
  lugares reservados para construir y la aparición. El minimapa sale de
  los tiles, así que acompaña solo.
- Centro de la red: la FUENTE (la plaza). Mientras todos están en su
  lugar, los caminos fijos son los de siempre. Si alguno se movió,
  quedan fijos solo el anillo de la fuente (6 × 6 alrededor) y su eje al
  sur hasta el borde; cada otro lugar, en el orden de la lista, se
  conecta con un camino procedural (§ 4.1) a la red, y después las
  construcciones.
- Aparición: en el eje, 4,5 tiles debajo de la esquina de la fuente
  (`TownLayout.spawnFor`; la de siempre es (17, 14,5)). Quien queda
  dentro de algo sólido tras mover un lugar vuelve ahí.
- Validación (`TownRules.moveLandmark`, revisa todo el pueblo porque los
  caminos fijos cambian): dentro del pueblo (sin la fila de árboles);
  sin pisar otro lugar con un tile de margen; ningún lugar sobre el
  anillo o el eje de la fuente; la fuente necesita su anillo y el tile
  de aparición adentro; ninguna construcción ni cartel sobre un lugar o
  un camino fijo; todo alcanzable (lugares y construcciones). Lo que
  deja el propio lugar no lo bloquea (se valida el pueblo ya movido).
- Volver un lugar a su posición de siempre lo saca de `marks`; con
  todos en su lugar el plano vuelve a ser el de siempre.

### 3.4 Casas de habitantes (v0.30.0)

- Construcción CASA (`resHouseGold` de oro + `resHouseMat` tablas;
  gris con el motivo si no alcanza), 3 × 3 de tile sólido (`Tile.house`,
  pasto debajo y el sprite encima), con 3 niveles (el sprite cambia por
  nivel). Se pone, mueve y borra como lagos y huertas, con el candado de
  § 1.3; no se funde con otras ni tiene cofre. Sus opciones: ASIGNAR A
  <habitante> (los invitados), MOVER, BORRAR (quien vivía queda sin
  casa). Subir de nivel la casa (desde la pantalla del habitante) es el
  pedido más común del habitante y abre mejores servicios.
  JSON de la construcción: `k: casa`, `lv`, `rs` (habitante).
- v0.42.6: también se asigna desde el diálogo del habitante sin casa
  (ASIGNAR CASA, overworld_biomes.md § 10.1.1): modo de elegir con la
  cámara de la edición, sin paleta ni franjas; las CASAS libres en
  verde, las ocupadas en gris; clic elige y el panel de la derecha
  confirma "Asignar casa a <NPC>" (Esc deselecciona / sale). Una CASA
  habitada muestra junto a la puerta el prop del campamento del oficio
  de quien vive ahí.
- Los pedidos de camino, faro, huerta o muelle se cumplen construyendo
  eso a menos de 6 tiles de su casa.

## 4. Mapa (`TownPlan`, determinista)
### 4.1 Caminos procedurales
Con lugares movidos, primero cada lugar (§ 3.3) y después cada
construcción (en orden): Dijkstra desde los tiles de pasto al
lado de su huella hasta el camino más cercano (fijo o ya generado),
con costo 4 + ruido por tile (0–2) para que serpenteen. Se pinta el
recorrido. Si un lado ya toca un camino, no se agrega nada. Se regenera
con cada cambio; el plano se cachea por la clave de lados y huellas
(las parcelas y los peces no lo rehacen).

### 4.2 Lagos que se funden
Un lago puede tener varias partes (rectángulos). Al poner o mover un
lago (o huerta) que pisa otro del mismo tipo o comparte un lado con él
(tiles ortogonalmente vecinos), quedan uno solo; tocarse solo por una
esquina (diagonal) o dejar un hueco de 1 tile o más los deja separados.
El resultado conserva el id (y con él el cartel) del más grande (empate:
el que estaba antes en la lista), todas las partes y la suma de peces,
cofre, semillas y ayudantes (v0.31.2). El editor dibuja el contorno de la
unión (no de cada parte) y, en el fantasma, el contorno del resultado
fundido antes de confirmar. Orilla: las
esquinas exteriores de cada parte son pasto; en un lago fundido, la
mitad de esas esquinas (según un hash del tile) muerde también los dos
tiles vecinos. Muelles: en cada parte, (derecha, fila 2), (derecha,
anteúltima fila) y (columna 4, arriba) si quedan en la orilla; para el
lago base dan los mismos tres de antes.

### 4.3 Carteles
Cada construcción tiene un cartel con su nombre (LAGO / HUERTA) encima,
que se mueve con ella (`TownPlan.signOf`). Huerta: 2 tiles a la
izquierda de su esquina superior izquierda; si ahí hay un camino fijo,
un lugar u otra construcción, prueba una fila más abajo, después 1 tile
a la izquierda (dos filas) y por último a la derecha. Lago: dos tiles a
la derecha de su borde, en la segunda fila (alternativas: pegado a la
derecha, una fila más abajo, a la izquierda). El del lago base queda en
(12, 15) como antes; el de la huerta base, en (18, 18) (los dos tiles a
la izquierda son el eje de caminos).

## 5. Lagos y huertas
- 5.1 Capacidad de un lago: `max(lakeMin, tiles × lakePerTile)` (2;
  0,2: el base tiene 10, uno de 6 × 6, 7). Rareza: `lakeZoneRare` por
  cada 36 tiles por encima de 48 + cría (`farming.md` § 7).
- 5.2 Se pesca en el lago más cercano: su tabla (las especies del
  pueblo + sus soltados) y su rareza. La pesca automática usa los
  soltados de todos.
- 5.3 Borrar: un lago pierde sus peces (la confirmación lo dice). Una
  huerta devuelve una semilla por parcela plantada a quien la borra (la
  opción amable: el cultivo se pierde, la semilla no). Lo arado vacío
  se pierde.
- Mover una huerta conserva sus parcelas (van relativas a su esquina).
- AGREGAR ESPECIES (en las opciones del lago) suelta peces de la bolsa
  en ese lago. La pestaña PESCA Y CULTIVO sigue con SOLTAR EN EL LAGO:
  va al lago más cercano. Soltar lo puede hacer cualquiera (son sus
  peces); construir, mover, borrar y ampliar, quien tiene el candado (§ 1.3).

- Huertas pegadas también se funden (v0.25.5): una huerta más grande con
  las parcelas, semillas, ayudantes y cofre de las dos.
- Opciones de una huerta o un lago: GRANJEROS / PESCADORES con CONTRATAR
  AYUDANTE y DESPEDIR (farming.md § 8.1). Cada construcción tiene un cofre
  al lado del cartel, en la misma fila (nunca arriba ni abajo): del lado
  de afuera y, si ahí no entra (borde, construcción, cartel o camino
  fijo), del otro (`TownRules.chestOf`, v0.32.2). AGREGAR ESPECIES es una grilla: elegís el pez, ves
  el detalle y SOLTAR EN EL LAGO.

## 6. Carteles con el mouse
Solo el mouse sobre un cartel (jugando o editando) muestra un tooltip
de tamaño fijo: LAGO con cada especie una vez y "N/M soltados"; HUERTA
con cada cultivo plantado una vez y "6 de 12 parcelas" (plantadas /
tiles de la huerta). Los dos suman la línea de ayudantes ("Granjeros 1 /
2 · cada uno atiende 8 parcelas", con las semillas del granjero) y el
cofre. Las parcelas y el agua no tienen tooltip.

## 7. Datos
### 7.1 `TownState`
`sides` (lado → ampliaciones), `builds` (lista de `TownBuild`: `id`,
`kind`, `parts` en coordenadas del pueblo base, `stock` si es lago,
`plots` relativas a la esquina si es huerta). `plots` y `stock` del
pueblo son vistas calculadas (todas las parcelas en coordenadas del
mapa; los peces de todos los lagos). Mundo nuevo: el lago base `l0`
(3, 14, 8 × 6) y la huerta base `h0` (19, 18, 4 × 3).

`marks`: lugar movido (`@forge`) → esquina en coordenadas del pueblo
base; solo los que no están en su lugar de siempre.

JSON: `sides {n,s,e,o}`, `builds [{id, k, p: [[x,y,w,h]], st?, pl?}]`,
`marks? {"@forge": [x, y]}` (sin `marks`, todo en su lugar: los saves
viejos no cambian).

### 7.2 Migración de v0.23
Sin `builds`: `exp` pasa a ser ampliaciones al ESTE; cada zona i de
`zones` una construcción en el mismo lugar (franja i ÷ 2, norte si es
par): LAGO 6 × 6 en (33 + 8·franja, 7 | 14), HUERTA 6 × 4 una fila más
abajo; `stock` al lago base; las parcelas a la huerta que las contiene.

## 8. Red (protocolo 46; candado en 50, § 1.3)
`town {o: expand|place|move|remove|stock|hireHelper, id?, tg?, x?, y?}`:
`expand` con `id` = lado (`n`/`s`/`e`/`o`); `place` con `id` = la del
catálogo y (x, y) la esquina en tiles del mapa; `move` con `tg` y (x,
y) (`tg` = `@<lugar>` mueve un lugar fijo, § 3.3; v0.25.2, protocolo 46); `remove` con `tg`; `stock` con `id` = especie y `tg` = lago. El
anfitrión valida todo (pueblo, candado, reglas de § 3.2) y el pueblo
viaja en el estado.

## 8.1 Faros (v0.27.0)

CONSTRUIR suma FARO: 1×1, `faroCost` de oro, en pasto o camino, no es
sólido ni corta caminos; MOVER y BORRAR como lo demás
(day_night_weather.md § 5). `TownState.lights` (`lt`).

## 9. Pendiente
- Otros tipos de construcción (decorado, corrales).
- Rotar construcciones y achicar lagos.
