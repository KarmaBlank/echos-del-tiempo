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

Lugar **MI PUESTO** del pueblo (`TownSpot.stall`, mostrador de 2 tiles
sobre el camino sur, en (19, 15) del pueblo base; lugar tardío:
en un pueblo guardado antes va al hueco libre más cercano). Cerca
aparece `[E] Mi puesto` y E abre `WorldPanel.stall`. Desde v0.49.12 el
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
