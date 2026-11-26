# Tienda del jugador (puesto propio)

Estado: **fase 2 implementada** (protocolo 85). Código:
`lib/game_engine/models/player_stall.dart`,
`lib/game_engine/rules/stall_rules.dart`, el caso `StallAction` de
`SessionEngine` y `lib/features/world/presentation/panels/player_stall_panel.dart`.

## 1. Fases

- **Fase 1 (ya existente):** vender lo de los oficios al AGROPECUARIO a
  precio fijo (`FishingRules.sell`, `FarmingRules.sell`,
  `SmithCraftRules.sellPrice`), cobrando en oro o materiales. No cambia.
- **Fase 2 (esta):** un **puesto propio** en el pueblo. El jugador pone
  a la venta lo que quiera de su bolsa de oficios **al precio que elija**;
  los vecinos (visitantes NPC) compran a lo largo de los días del mundo
  según la demanda, y los compañeros de la sala pueden comprar del puesto
  de otro. Todo lo valida el anfitrión.
- **Fase 3 (pendiente):** puesto visible en el mapa del pueblo (mueble
  propio en el editor), pedidos de los vecinos con precio ofrecido,
  armas forjadas a la venta.

## 2. Qué se puede poner

Celdas de oficio con el mismo formato que dar materiales
(`share_materials.md`): `fish:<especie>`, `crop:<clave de cosecha>` y
`ore:<material de herrería>`. Las herramientas, semillas, abonos y
materiales de oficio no se venden en el puesto.

Precio de referencia (`StallRules.refPrice`): el mismo que paga el
AGROPECUARIO sin bonos del árbol (pez: `price`; cosecha: `price ×
qualityMult<calidad>`; mineral: `SmithCraftRules.sellPrice`). Lo que no tiene
precio de referencia (≤ 0) no se puede poner.

## 3. Reglas del puesto

- **Lugares:** `stallSlots` (6) publicaciones. Una por celda: volver a
  poner la misma celda suma la cantidad y cambia el precio.
- **Precio:** entero de 1 a `ref × stallMaxMarkup` (3). La UI ofrece los
  pasos fijos `StallRules.priceSteps` (×0.8, ×1, ×1.25, ×1.5, ×2) sobre
  la referencia.
- **Depósito:** lo publicado **sale de la bolsa** al ponerlo (no se puede
  vender dos veces ni darlo). RETIRAR devuelve lo que quede.
- **Visitantes (NPC):** en cada día nuevo del mundo (el mismo cambio de
  día que los habitantes, `_skyTick`) cada humano de la sala recibe
  `stallVisitors` (3) visitantes. Cada uno elige una publicación al azar
  (generador del anfitrión) y compra con chance
  `clamp(stallBaseChance × (ref × demanda / precio)^stallElasticity, 0,
  stallMaxChance)`; si compra, se lleva `1 + ⌊azar × stallMaxBuy⌋`
  unidades (tope: lo que haya).
- **Demanda:** cosechas, `LifeTimeRules.seasonPrice(cultivo, estación)`
  (el mismo × de estación que paga el AGROPECUARIO); peces y minerales, 1. Más caro que la referencia → menos ventas; más barato →
  casi seguro.
- **Un día se cobra una vez:** el puesto guarda `day` (último día
  atendido); un día ≤ ese no vuelve a vender (volver a entrar no repite).
  Un puesto vacío no se marca (el perfil no cambia).
- **Compañeros:** otro humano de la sala, en el pueblo, compra `n`
  unidades al precio publicado. Paga en oro; el dueño cobra al instante.
  Se rechaza si no alcanza el oro, si pide más de lo publicado, si es su
  propio puesto o si no le entra en la bolsa (mismas reglas que dar).
- **Registro:** cada venta queda en el registro del puesto (día, celda,
  cantidad, oro, comprador: vacío = vecino, si no el nombre del
  compañero), los últimos `stallLogCap` (20). `earned` suma todo lo
  cobrado.

Todos los números están en el grupo de ajustes `town` (`stall*`), que el
parche de balance puede tocar.

## 4. Datos y red

- `LifeSkills.stall` (`PlayerStall`), JSON `ps` dentro de `life`:
  `{l: [[celda, cant, precio]…], g: [[día, celda, cant, oro, comprador]…],
  e: ganado, d: día}`. Tolerante: lo inválido se descarta.
- Acción `StallAction` (`stall`): `o` (`list`, `unlist`, `buy`), `c`
  celda, `n` cantidad, `p` precio, `ow` dueño (al comprar). Solo en el
  pueblo, fuera de expedición. Protocolo **85**.

## 5. UI

El puesto ya no es un mostrador suelto en el pueblo: es un mostrador
dentro de la **TIENDA** (§ 6). Frente a tu mostrador aparece
`[E] Mi puesto` y E abre `WorldPanel.stall`. Desde v0.49.12 el
panel del vendedor ya no tiene botón MI PUESTO (salía con cualquier
vendedor y confundía). Panel
con pestañas (nunca secciones apiladas):

- **MI PUESTO:** grilla con lo publicado (cantidad y precio) y, con un
  filtro, la bolsa para poner. El detalle de la derecha muestra la
  referencia, la demanda de la estación, los pasos de precio (chips) y
  PONER 1 / PONER TODO / CAMBIAR PRECIO / RETIRAR. Sin lugar libre o sin
  nada en la bolsa, PONER se ve gris (con motivo si faltan lugares).
- **PUESTOS DEL GRUPO:** las publicaciones de los compañeros; COMPRAR 1
  / COMPRAR TODO (gris si no alcanza el oro).
- **REGISTRO:** las ventas como casillas (ícono de lo vendido, oro abajo)
  con el detalle (día, comprador, cantidad) y el total ganado.

Captura: `docs/preview/player_shop.png` (test con `PREVIEW=1`).

## 6. La TIENDA (casa e interior)

- **Afuera:** casa de 3 × 3 tiles en el pueblo (`TownSpot.shop`,
  `Tile.shop`, esquina (20, 13) del pueblo base, justo al norte del
  camino sur), mismo estilo que la ARMERÍA: sprite `items.vida_tienda`
  (madera, toldo a rayas, emblema de monedas; lo pinta
  `tool/export_building_sprites.dart`). Frente a la puerta:
  `[E] Entrar a la tienda`.
- **Interior:** otro mapa, como una mina: `GameSession.place = 'shop'`
  (`ShopInteriorRules`), mapa de lobby de 16 × 11 sin enemigos, con su
  cámara. Se entra solo desde el pueblo y se sale solo al pueblo
  (`TravelAction`; el anfitrión valida `ShopInteriorRules.canTravel`).
  Se aparece adentro junto a la puerta; al salir, frente a la puerta de
  la casa (donde esté la casa en ese pueblo). En co-op con salas
  separadas, la tienda es una sala más: los que entran se ven adentro.
- **Mostradores:** uno por jugador de la sala (sin compañeros), en orden
  de id para que todos vean lo mismo; hasta `shopCounters` (Balance,
  tuning `town`, 4 por defecto, máx. 4). Cada uno muestra el nombre del
  dueño y hasta 4 íconos de lo que tiene publicado; los que sobran dicen
  LIBRE. Estantes con mercadería, alfombra y la puerta de salida son
  decorado.
- **E en un mostrador:** el propio abre `WorldPanel.stall` (MI PUESTO);
  el de otro jugador (`[E] Puesto de <nombre>`) abre el mismo panel en
  PUESTOS DEL GRUPO filtrado a ese jugador, con la regla de compra de
  siempre (§ 3). E en la puerta: `[E] Salir al pueblo`.
- **Visitantes:** la simulación diaria (§ 3) no cambia; no hay NPC
  visibles adentro.
- **Migración:** el viejo mostrador al aire libre desaparece. La casa es
  un lugar tardío (`TownLayout.lateSpots`): en un pueblo guardado con
  algo en su lugar va al hueco libre más cercano. Una marca vieja
  `@stall` se ignora. Los datos del puesto viven en el perfil y no se
  tocan.
- **Red:** protocolo Mundo 98 (`place` puede ser `shop`).

Capturas: `docs/preview/shop_exterior.png` y
`docs/preview/shop_interior.png` (test `shop_preview_test.dart` con
`PREVIEW=1`).

### 6.4 Llegada segura (v0.49.31)

- La llegada al pueblo (`ShopInteriorRules.townFront`) está en px del
  mapa: suma el origen del pueblo base (`TownState.origin`), así en un
  pueblo ampliado se sale frente a la puerta y no corrido.
- Red de seguridad: al entrar o salir, si la caja del personaje choca
  con algo sólido en el punto de llegada (con el reparto del grupo), va
  al centro del tile libre más cercano (`WorldRules.safeLanding`).
- El frente de la puerta nunca tiene árboles (town_editor.md § 4.5).

### 6.1 Arte del interior (v0.49.26)

Lo pinta `tool/export_shop_interior_sprites.dart`; el juego solo nombra
ids del manifest. Sin esos sprites (tests) se dibuja el decorado plano de
antes. La jugabilidad no cambia: mismas filas, mostradores, puerta y
llegada.

- **Sala** (`items.vida_shop_room`, 256 × 176, la sala entera): piso de
  tablas con veta y nudos, sombra al pie de las paredes; pared del fondo
  con viga, yeso y zócalo de madera; dos estanterías (columnas 1-4 y
  11-14) con frascos, botellas, cajas, bolsas y telas; en el nicho del
  fondo un cartel con monedas y el mostrador de caja (campanilla, libro
  de cuentas, pilas de monedas, balanza); paredes laterales con dos
  ventanas cada una que dejan manchas de luz en el piso; alfombra
  central con borde dorado y medallón; macetas junto a las estanterías,
  un arbolito en maceta, barril con manzanas, caja y bolsa junto a la
  puerta; felpudo adentro de la puerta y luz de afuera en el umbral.
- **Lámparas:** cuatro faroles de pared (dos en el nicho, uno en cada
  pared lateral) en `ShopInteriorRules.lamps`. De noche las prende el
  sistema de luces (`LightId.lamparaTienda`, radio 5, cálida).
- **Mesas de exhibición:** una por mostrador, autotile por piezas
  (`items.vida_shop_table_<pieza>_<tela>`: `l` / `m` / `r` o `s` sola;
  `ShopInteriorLayer.tablePieces`), 16 × 22 con la base 3 px bajo el
  tile. Tela por lugar (0 roja, 1 azul, 2 verde, 3 ciruela) con faldón,
  pliegues y ribete dorado; un mostrador LIBRE es una mesa de madera sin
  tela (`bare`). Lo publicado se apoya sobre la mesa y cuelga una
  etiqueta de precio dorada (`items.vida_shop_tag`) en el faldón.

Capturas: `docs/preview/shop_interior_v2.png` (con los sprites de los
personajes) y `docs/preview/shop_interior_before_after.png` (test
`shop_interior_art_test.dart` con `PREVIEW=1`).
