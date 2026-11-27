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
`SleptEvent` (`slept`). Un par en 101 los perdería. 102–104 los usan
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
