# Spec: Casa propia y dormir (protocolo 105)

Pedido del dueño: una casa para el jugador, un lugar donde pasar el
tiempo entre el día y la noche, y que el mundo siga su lógica mientras
tanto (habitantes, cultivos, animales, clima, temporizadores).

Código: `HomeInteriorRules` (reglas puras), `session_engine_home.dart`
(`_HomeOp`: acostarse, despertar, adelantar el tiempo),
`WorldEngine._sleep` (co-op con instancias), `HomeInteriorLayer` (la
sala), `tool/export_player_house_sprites.dart` (arte).

## 1. La pieza en EDITAR PUEBLO

- `kPlayerHouseId = 'player_house'`, `BuildKind.home`, 4 × 3 tiles, en la
  categoría HOGAR de la paleta CONSTRUIR (`TownBuildPalette`).
- Cuesta oro: `kTuning[town].playerHouseGold` (1500). Cuántas por
  pueblo: `playerHouseMax` (1). Los dos se editan en Editor → Balance →
  Pueblo (`balance_codecs`).
- COLOCAR gris con el motivo en el tooltip: sin personaje, ya hay una
  casa propia (`ui.town.home.only_one`) o falta oro
  (`ui.town.edit.missing_gold`).
- Como toda construcción, nunca se pisa con otra cosa (caminos fijos,
  lugares, otras construcciones, carteles) y no deja nada sin camino
  (`TownRules._invalid`). No se funde con otras.
- En el mapa: tiles `Tile.house` (sólidos) y la puerta `Tile.homeDoor`
  (`D`, sólida) en el medio de la fila de abajo. El sprite es
  `items.vida_home_exterior` del manifest (64 × 48); la miniatura de la
  paleta usa el mismo.
- BORRAR: como las demás construcciones (sin devolver el oro).

## 2. El interior

- Lugar `home` (`GameSession.place`), como el interior de la TIENDA
  (player_shop.md § 6): E frente a la puerta (`TownSpot.home`) entra; E
  frente a la puerta de adentro vuelve al pueblo, delante de la puerta
  de la casa (`HomeInteriorRules.townFront`, con `safeLanding`).
- Sala de 12 × 8 tiles (`HomeInteriorRules.rows`), cuatro camas de 1 × 2
  (`bedTiles`), sólidas. Sprite `items.vida_home_room` (192 × 128); sin
  él se dibuja con formas planas.
- Sin cielo adentro: el tema del mapa es `interior`
  (`SkyRules.indoorThemes`), así que no hay nubes, lluvia, rayos ni
  oscuridad de la noche (`SkyRules.outdoor` = false).
- Con instancias (free_movement.md) cada jugador entra solo; sin ellas
  viaja el grupo, como en la tienda.

## 3. La cama

- E frente a una cama (`TownSpot.bed`, a 12 px o menos) ofrece
  `[E] DORMIR hasta la mañana` de noche o `[E] DORMIR hasta la noche` de
  día. Manda `SleepAction(true)` (`{"t":"sleep","on":true}`).
- Acostado, E dice `[E] Levantarse` (`SleepAction(false)`).
- El anfitrión valida: adentro de la casa, en el lobby, en alcance de una
  cama, sin ser compañero. Lo marca en `SessionPlayer.inBed` (`bd` en el
  snapshot).
- Salir de la casa o alejarse de la cama levanta al jugador (tick del
  anfitrión, `leaveBedsOutside`).

## 4. Dormir: el tiempo pasa de verdad

- El anfitrión manda. El tiempo salta solo cuando TODOS los jugadores
  conectados (humanos, en cualquier instancia) están acostados.
- Mientras tanto, quien está acostado ve arriba al centro un `DsToast`:
  "Esperando a los demás (x/n)" (`GameSession.sleepWait`, `slp`).
- Destino: de noche (o antes del amanecer) hasta la mañana, con el reloj
  en `duskSec` (ya de día pleno); de día hasta la noche, en
  `daySec + duskSec` (noche cerrada). `HomeInteriorRules.skipSeconds`.
- El salto NUNCA toca el reloj a mano: corre el paso normal del mundo
  (`_Op.tick`) de a 1 s todos los segundos que faltan
  (`SessionEngine.fastForward`). Así pasa todo lo que pasaría:
  - cielo y clima del día siguiente, pronóstico y rayos;
  - cultivos que crecen (con riego y afinidad), ayudantes que trabajan;
  - animales: el cambio de día da sus productos (`animalsDay`);
  - habitantes: pedidos, ánimo y órdenes del día nuevo
    (`ResidentRules.onDayAll`); su lugar en el mapa sale del reloj, así
    que de noche están en su casa (o en su salida nocturna, § 10.1.1 de
    overworld_biomes.md) y de día afuera;
  - eventos del mundo, puesto de la tienda, temporizadores de la sala.
- Con instancias, el salto corre en la sala del pueblo
  (`WorldEngine._sleep`) y lo común se comparte a las demás.
- Al terminar: todos se levantan, se borra la espera y llega
  `SleptEvent` (`{"t":"slept","m":true}` a la mañana): aviso local
  "Dormiste como un tronco. Ya amaneció." o "Una buena siesta. Ya cayó la
  noche." — textos BORRADOR (`status: draft` en en / zh-Hans).

## 5. Red (protocolo 105)

`player_house` y `BuildKind.home` en el pueblo, el lugar `home`,
`SleepAction` (`sleep`), `bd` del jugador, `slp` de la sala y
`SleptEvent` (`slept`), `HomeEditAction` (`hEd`) y el `hl` del perfil
(§ 8). Un par en 101 los perdería. 102–104 los usan
otras ramas; esta usa el siguiente libre.

## 6. Pruebas

`test/game_engine/player_house_test.dart`: la pieza y su puerta, costo y
una por pueblo, nada encima, entrar y salir sin cielo, dormir de noche
hasta la mañana (cultivos crecen, día siguiente), de día hasta la noche,
habitantes según la hora, animales que producen, co-op entre instancias
que espera a todos (x/n), snapshot (`bd`, `slp`), levantarse al
alejarse. Vistas previas en `docs/preview/player_house/`
(`test/features/world/player_house_preview_test.dart`).

## 7. Fase 2: EDITAR CASA

Ver § 8 (editor del interior), en commits separados de esta rama.

## 8. EDITAR CASA (editor del interior)

### 8.1 Dueño y distribución

La distribución (`HomeLayout`: muebles, pared, piso, pintura) vive en el
perfil de cada jugador (`PlayerProfile.home`, JSON `hl`, se omite si es
la de fábrica) y viaja en el snapshot como el resto del perfil. La sala
muestra la del **dueño**: quien la abrió si sigue adentro; si no, el
primer humano por id (`HomeInteriorRules.layoutOwner`). Solo el dueño
edita, y solo en el lobby (fuera de peleas y votos). El host valida cada
`HomeEditAction` (`hEd`); los demás ven el cambio en el snapshot. Los
muebles sólidos son `C` en el mapa de la sala (`rowsOf`), así que nadie
camina a través de ellos. La distribución de fábrica: 4 camas simples y
una ventana.

### 8.2 Muebles

`kHomeFurniture` (`lib/game_engine/data/home_furniture_catalog.dart`),
cada uno con nivel del pueblo (`home_<id>_lvl`) y oro (`home_<id>_gold`)
en `kTuning` (Editor → Balance → Pueblo). Nivel del pueblo = escalón de
renombre del pueblo + 1.

- **Camas** (simple, acolchada, con dosel 2x2): DORMIR como en § 3.
  Siempre queda al menos una.
- **Cuadros y reloj**, **ventanas**: van en la pared del fondo (fila 0).
- **Armero** (2x1): muestra hasta 3 armas propias del dueño; E abre la
  grilla para elegirlas.
- **Cofre del alijo**: E abre el mismo alijo que B; lleva la placa ALIJO.
- **Cocina** (2x1): E abre la misma pantalla de cocina que el edificio COCINA (`SessionController.openKitchen()`, farming.md § 17).
- **Decoración**: biblioteca, maniquí de armadura, alfombra (se pisa),
  planta, candelabro, mesa.

Sprites `items.vida_home_<id>` del manifiesto, generados por
`tool/export_player_house_sprites.dart`; las piezas altas crecen hacia
arriba desde su huella (como mucho 4 px).

### 8.3 Interfaz

Botón EDITAR CASA arriba a la izquierda siempre que estés en la casa
(gris con el motivo si no sos el dueño o hay pelea). Al editar se oculta
el HUD y aparece una barra: título, ayuda, AMUEBLAR (abre la paleta) y
LISTO [ESC]. La paleta es una grilla tipo INVENTARIO con el detalle a la
derecha y subtabs TODO / CAMAS / PARED / ÚTILES / DECORACIÓN / PAREDES Y
PISOS; el detalle muestra tamaño, nivel, costo y COLOCAR / APLICAR (gris
con el motivo). Colocar deja un fantasma verde o rojo bajo el mouse con
el motivo; clic coloca y la pieza sigue elegida mientras se pueda pagar.
Clic en un mueble lo selecciona: MOVER · BORRAR · CANCELAR. Esc va
soltando pieza → selección → paleta → sale. Borrar no devuelve el oro.

Reglas de colocación (`cannotPlace`): adentro; las de pared en la fila
0; las de piso no tapan el frente de la puerta; **nada se pisa** con
otra pieza de su misma capa; y todo el piso libre sigue alcanzable desde
la puerta (la alfombra no cuenta).

### 8.4 Paredes, pisos y pintura

`kHomeSurfaces`: revoque, madera, piedra, ladrillo; tablas, piedra,
baldosas, alfombrado. Cada uno con nivel, oro y material de oficio
(`home_<id>_mat` unidades de `tabla` o `fibra`). Pintura: 6 colores
(`kHomePaints`, 0 = el color del material) por `homePaintGold` de oro,
aplicada como multiplicación sobre la pared.

### 8.5 Ventanas y luz de día

De día cada ventana deja un parche de luz en el piso debajo, que se
inclina con la hora; de noche nada. La intensidad sale de
`LightRules.daylight` (1 − oscuridad del cielo).

### 8.6 Pruebas

`test/game_engine/home_editor_test.dart`: costos y niveles, distribución
de fábrica válida, colocación (adentro, puerta, pared, superposición,
rincón sin paso), compra con nivel y oro, mover / borrar / la última
cama / superficie / pintura / armero, JSON (`hl`, `hEd`), solo el dueño
adentro edita por el motor, luz de día. Vistas previas
`house_interior.png`, `house_furnished_day.png`,
`house_furnished_night.png` en `docs/preview/player_house/`.
