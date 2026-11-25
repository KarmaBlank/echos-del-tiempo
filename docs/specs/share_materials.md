# Dar materiales de oficio a un compañero (protocolo 78)

Pedido del dueño: si un jugador tiene tablas trabajadas, lingotes o
cosechas que le sirven a otro (por ejemplo para construir o contratar
ayudantes), se las puede pasar. Código: reglas en
`lib/game_engine/rules/life_give_rules.dart` (Dart puro), host en
`SessionEngine._giveLife`, UI en
`lib/features/world/presentation/panels/life_items_view.dart`.

## 1. Qué se puede dar

Cada pila de las bolsas de oficio (oficio_storage.md § 2) salvo las
herramientas, más los materiales de herrería:

| Celda | Qué es |
|---|---|
| `fish:<especie>` | pescado y basura del agua (bolsa de pesca) |
| `crop:<cultivo>@<índice de calidad>` | cosecha de una calidad |
| `seed:<cultivo>` | semillas |
| `fert:<abono>` | abonos |
| `craft:<id>` | materiales de oficio: fibra, cebo prensado, tabla tratada |
| `ore:<id>` | menas, lingotes y hallazgos raros de minería |

Las cañas, azadas y regaderas nunca se pasan (son equipo de oficio). Las
comidas cocinadas tienen su propio DAR A en COCINA (farming.md § 19.2).
Los materiales de forja de armas de EQUIPAMIENTO se siguen dando con
`GiveItemAction` (`mat:<material>`).

## 2. Validación del host

Acción `GiveLifeAction(toPlayerId, cell, count)` (JSON `giveLife`, campos
`to`, `c`, `n`). El host la acepta solo si:

- **Los dos están en el pueblo**: sala en el lobby, sin travesía activa,
  y ambos son humanos (no compañeros de party). Se eligió así porque las
  bolsas de oficio solo se abren en el pueblo y la misma regla rige DAR A
  de comidas; en una misión no hay entregas de oficio.
- El destinatario existe y no es quien da.
- `count ≥ 1` y quien da tiene al menos `count` de esa celda.
- La celda es de un tipo conocido y su id existe en el catálogo (un id
  inválido no se crea en el perfil del otro).
- **Entra en la bolsa del otro**: si crearía una pila nueva en una bolsa
  llena (oficio_storage.md § 3) se rechaza; sumar a una pila que ya tiene
  siempre entra. Los materiales de herrería (`ore:`) respetan el tope de
  pila `stackCap` de Balance (grupo Minería y herrería).

Si algo falla, nada cambia. Si pasa: se descuenta al que da (la pila
desaparece al llegar a 0), se suma al otro y el chat anuncia
`<A> le dio N × <material> a <B>`.

## 3. UI

En OFICIOS → INVENTARIO, el detalle (a la derecha de la grilla) de cada
pila que se puede dar suma:

- Selector de cantidad `×1 · ×giveStep · TODO` (`life-give-amt-<celda>-<i>`),
  botones compactos con el elegido marcado. `giveStep` = 5 (Balance,
  grupo Pueblo). `×giveStep` se ve gris si no alcanza.
- Un botón `DAR A <NOMBRE>` por compañero humano en la sala
  (`life-give-<celda>-<id>`). Gris si no se puede; con tooltip solo
  cuando el motivo es raro (el otro no tiene lugar).
- Sin compañeros: un solo `DAR A...` gris con tooltip.

HERRERÍA suma los filtros MATERIALES (fibra, cebo, tabla) y MINERALES
(menas y lingotes, que no ocupan casillas de la bolsa; solo se listan
para poder darlos).

## 4. Construir en el pueblo: pozo personal

No hay un pozo compartido de materiales. En el editor del pueblo, poner
una casa (`ResidentRules.placeCost`), contratar o mejorar ayudantes
(farming.md § 8) y los faros cobran oro y materiales de oficio **del
jugador que lo hace**; lagos, huertas y mover piezas no cuestan
materiales. Por eso pasar tablas o fibra a quien va a construir es la
forma de juntar recursos entre varios.

## 5. Red

`kProtocolVersion` 77 → 78 por la acción nueva `giveLife`.

Vista previa: `SHARE_PREVIEW=1 flutter test
test/features/world/share_materials_ui_test.dart` escribe
`docs/preview/share_materials.png`.
