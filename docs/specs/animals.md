# Spec: Animales de granja (oficio GRANJERO, rama ANIMALES)

Estado: implementado en feat/farm-animals (protocolo **101**). Extiende
`farming.md` (huerta, ayudantes) y reemplaza la idea vieja del CORRAL de
`farming.md` § 13. Principios: `design_pillars.md` (partes simples, nada
obligatorio, calma real, todo en Balance). Lore: solo `docs/lore.md`.

**Reforma del Granjero (v0.50, aprobada por el dueño):** el oficio
Cultivo pasa a llamarse **GRANJERO** y tiene dos ramas, **CULTIVOS** (la
huerta de siempre) y **ANIMALES** (esta spec). Hacer solo cultivos, solo
animales o las dos cosas rinde la misma XP y el mismo oro por hora (§ 7).
Los animales tienen su rama de árbol (§ 8), dejan piezas de forja por
cuidado, nunca por daño (§ 9), a cinco corazones a veces un producto
legendario que Brann forja en un arma única (§ 10), y el TALLER DE
OFICIOS suma la quesera y la mayonesera (§ 11).

Todo número de esta spec está en Editor → Balance → **Granjero:
animales** (`kTuning['animals']`, valores en
`lib/game_engine/data/animals_catalog.dart`) salvo el modelo de paridad
(Balance → Oficios: equipo, claves `income*`) y los nodos del árbol
(Balance → Oficios: árboles, `farm_f*`). El catálogo (qué animales, qué
construcción, qué producto, qué herramienta, qué pieza, qué sprite) son
datos en `animals_catalog.dart`: cada entrada solo dice ids y claves;
precios, días y XP los lee del Balance por clave (`<id>Price`,
`<id>Every`, …).

Código: `animals_catalog.dart`, `models/farm_animal.dart`,
`rules/animal_rules.dart`, `rules/session_engine_animals.dart` (parte del
motor), `GearRules.animalForge` (`profession_gear_rules.dart`),
`map/animal_layer.dart`, `panels/animal_panel.dart`, la pestaña GRANJA de
`panels/trader_panel.dart`, la pestaña MÁQUINAS del TALLER DE OFICIOS
(`workshop_panel.dart`) y la forja de Brann. Sprites:
`tool/export_animal_sprites.dart` → `items.vida_*` del manifiesto (nunca
un archivo nombrado en Dart).

---

## 1. Idea (una tecla, nada obligatorio)

- Comprás un GALLINERO o un ESTABLO en EDITAR PUEBLO (oro), comprás
  animales en el agropecuario (pestaña GRANJA) y van solos a su casa.
- Cada día del mundo: le das de comer (heno) y lo acariciás (E). Al día
  siguiente deja su producto: huevos en el piso del gallinero, leche y
  lana se sacan con E y la herramienta (Cubeta, Tijeras).
- El cariño (0 a 5 corazones) sube la calidad del producto, con las
  mismas calidades de la huerta (normal, rara = "plata", épica = "oro"),
  y la frecuencia y la calidad de las piezas (§ 9).
- **Nada se pierde y nadie sufre:** los animales nunca mueren, nunca se
  van y nunca se los lastima. Sin comida no producen y el cariño baja
  despacio; con comida vuelven a producir al día siguiente.

## 2. Catálogo

| Construcción | Huella | Casa | Cupo | Precio | Nivel de Granjero |
|---|---|---|---|---|---|
| GALLINERO (`gallinero`) | 5 × 4 | 2 × 2 arriba a la izquierda | 6 | 600 oro (`coopPrice`) | 3 (`coopLevel`) |
| ESTABLO (`establo`) | 7 × 5 | 3 × 3 arriba a la izquierda | 6 | 1500 oro (`barnPrice`) | 6 (`barnLevel`) |

El resto de la huella es el patio: pasto con cerco (los cercos con
autotile del taller), con un portón abajo al medio. El patio se camina;
la casa es sólida.

| Animal | Vive en | Precio | Nivel | Producto | Cada | Herramienta | Piezas (§ 9) | Afinidad |
|---|---|---|---|---|---|---|---|---|
| Gallina | gallinero | 150 | 3 | Huevo | 1 día | — (al piso, imán) | Pluma | fuego |
| Pato | gallinero | 300 | 5 | Huevo de pato | 2 días | — (al piso, imán) | Pluma | agua |
| Vaca | establo | 800 | 6 | Leche | 1 día | Cubeta | Cuerno y pelaje mudados | físico |
| Cabra | establo | 600 | 8 | Leche de cabra | 2 días | Cubeta | Cuerno y pelaje mudados | electro |
| Oveja | establo | 700 | 10 | Lana | 3 días | Tijeras | Lana fina | sagrado |

| Producto | Precio normal | XP de Granjero |
|---|---|---|
| Huevo | 13 | 10 |
| Huevo de pato | 26 | 20 |
| Leche | 13 | 10 |
| Leche de cabra | 26 | 20 |
| Lana | 39 | 30 |

Todos rinden lo mismo por día (producto ÷ días): un gallinero de
gallinas, uno de patos o un establo mezclado pagan igual (test
`granjero_parity_test`, ±25 % por especie). El precio y la XP suben con
la calidad con `qualityMult<Calidad>` de Cultivo (× 1, × 1.3, × 1.8).

Herramientas (una vez, quedan para siempre): Cubeta 400 oro, Tijeras 600
oro (`cubetaPrice`, `tijerasPrice`). Heno: 4 oro el fardo (`hayPrice`), o
PICAR FARDOS en la GRANJA: cada cultivo (cualquiera, cualquier calidad)
da `hayPerCrop` (2) fardos.

**Más adelante (solo spec, sin código):** Cerdo (establo) que busca
trufas en el patio en vez de dar un producto fijo.

## 3. Construcciones (EDITAR PUEBLO)

- Salen en la paleta CONSTRUIR con su precio en oro y el nivel de
  Granjero pedido. Sin el nivel o sin oro, el botón gris con el motivo
  ("Necesitás Granjero nivel 6", "Falta oro (120/1500)").
- En la paleta (v0.49.39) la casilla y el detalle muestran el sprite de
  la casa (`items.vida_gallinero`, `items.vida_establo`, de
  `tool/export_animal_sprites.dart`), nunca la tierra arada. Detalle:
  su huella real (gallinero 5×4, establo 7×5), costo `₵{precio}` y sin
  rasgos de luz (town_editor.md § 1.2).
- El cerco del patio es sólido; se entra por la tranquera de abajo
  (town_editor.md § 5.1).
- Se mueven como las demás: los animales, el heno y el cofre viajan con
  la construcción. No se funden entre sí (como las casas).
- **Borrar** una construcción con animales no se puede (botón gris:
  "Tiene animales: no se pueden echar"). Vacía, se borra sin devolver oro
  (como la huerta).

## 4. Animales

### 4.1 Comprar
- Pestaña GRANJA del agropecuario, filtro ANIMALES: grilla tipo
  INVENTARIO con el detalle a la derecha (precio, producto, cada cuántos
  días, herramienta, dónde vive). COMPRAR lo manda a la primera
  construcción de su tipo con lugar. Gris con motivo: sin gallinero /
  establo, sin lugar, sin nivel, sin oro.
- Nombre: uno de una lista corta por especie (i18n), según el número del
  animal; no se escribe.

### 4.2 El día de un animal
Cada animal guarda (`models/farm_animal.dart`): especie, cariño (0 a
`affMax` = 500 puntos, 100 por corazón), el último día en que comió, el
último día en que lo acariciaron, días de ciclo acumulados, el producto
listo (calidad) si hay y lo que dejó en el piso (`d`, hasta
`kMaxAnimalDrops` = 4: piezas y productos legendarios, § 9–10).

Durante el día del mundo `d`:
- **Comer:** E sobre el animal con heno en la bolsa (o desde el depósito
  de heno de su construcción) → comió hoy (+`feedGain` de cariño, XP
  `feedXp`). Una vez por día.
- **Acariciar:** E sobre un animal que ya comió (o sin heno a mano) →
  +`petGain` × (1 + Mano tibia, § 8) de cariño, XP `petXp`. Una vez por
  día. A la vaca y a la cabra se las **cepilla** al acariciarlas: a
  veces dejan pelaje mudado (§ 9).
- **Juntar:** E junta el producto y todo lo que haya en el piso: el
  producto salta al piso y el imán lo trae (como la cosecha); las piezas
  van a los materiales de herrería. Leche y lana piden Cubeta o Tijeras
  ("Necesitás una cubeta: comprala en la GRANJA"); lo del piso se junta
  siempre. XP del producto × calidad. Al esquilar una oveja con
  `woolHearts` (3) corazones o más, a veces sale lana fina (§ 9).

La tecla E hace lo primero que falte en ese orden: juntar → comer →
acariciar. El cursor de acción marca al animal (verde: hay algo para
hacer; naranja: ya está todo hecho hoy).

Al cambiar el día del mundo (anfitrión, `AnimalRules.onDay`):
- Comió ayer → suma un día de ciclo; al llegar a `<especie>Every` el
  producto queda listo con la calidad de su cariño (si ya había uno sin
  juntar, no se apila). A cinco corazones, a veces deja además un
  producto legendario en el piso (§ 10).
- Comió ayer → a veces deja una pieza en el piso de su casa: plumas en
  el gallinero, cuerno mudado en el establo (§ 9).
- No comió ayer → no suma ciclo y pierde `unfedDecay` de cariño.
- No lo acariciaron ayer → pierde `unpetDecay` de cariño.
- El cariño nunca baja de 0 y el animal nunca se va.
- Los bonos del árbol que actúan sin un jugador (piezas, calidad,
  legendarios) toman el mejor de los jugadores de la sala.

### 4.3 Calidad por cariño
Con `h` corazones (cariño ÷ 100, hacia abajo):
- rara: `qRaroPerHeart` × h (0.10 por corazón);
- épica: `qEpicoPerHeart` × max(0, h − 2) (0.08 por corazón desde el 3.º);
- el resto, normal.

A 5 corazones: 50 % rara, 24 % épica. Ojo de pastor (§ 8) da una chance
de subir un escalón al juntar (nunca a legendaria).

### 4.4 Noche
Los animales duermen dentro de su casa de noche (`SkyRules.isNight`):
no se dibujan en el patio y E sobre la casa abre el panel del
corral. Igual se los puede atender desde el panel.

## 5. Panel del corral (E sobre la casa o con un animal)

Organismo `AnimalPanel` sobre `DsGridDetailLayout` (la misma grilla +
detalle de INVENTARIO y `DsCollectionTemplate`), solo con `DsColors`:
- Encabezado en una fila: contadores con ícono (animales / capacidad,
  heno en el depósito / tope con el árbol, heno en la bolsa) y
  DEPOSITAR HENO (todo el heno de la bolsa, hasta el tope).
- Grilla de 6 columnas anclada arriba a la izquierda, casillas del
  tamaño de INVENTARIO con solo el sprite (borde del color de calidad si
  tiene producto listo; un punto en la esquina si dejó algo en el
  piso). Nada de texto abajo: nombre, especie, corazones, estado y lo del
  piso van en el tooltip.
- Panel derecho con todo el ancho restante (mínimo 340 px): retrato
  grande, nombre (Título), especie (etiqueta), cinco corazones, una
  lista de tildes (comió hoy, lo acariciaron hoy, listo para juntar o en
  cuántos días), la línea de calidad (odds de plata y oro) y **EN EL
  PISO**: una fila de casillas de INVENTARIO con lo que dejó (pieza o
  legendario; nombre y calidad en el tooltip).
- Botones en una sola fila fija abajo del panel derecho: DAR DE COMER,
  ACARICIAR, JUNTAR; grises con el motivo en el tooltip si no se puede.
- Nada truncado: los textos largos bajan de línea.

## 6. Ayudantes (granjero de corral)

- Se contratan en la FUENTE RÚNICA con CONTRATAR GRANJERO DE CORRAL (y
  después se elige la construcción en el mapa, como los demás). Uno por
  construcción (`helperPerHome`). Requisito en el botón:
  "Necesitás subir tu oficio de Granjero a nivel 8" (`helperLevel`).
  Costo igual al granjero de huerta (`town.helperCost`).
- Cada vuelta de ayudantes (`helperEverySec` del pueblo) atiende a todos
  los animales de su construcción que falten:
  - come del **depósito de heno** de la construcción (no de la bolsa de
    nadie); sin heno, no come;
  - acaricia con `helperPetGain` (15) y nunca sube el cariño por encima
    de `helperHeartCap` (2 corazones): lo demás es del cariño a mano;
  - junta los productos listos al **cofre** de la construcción (con
    `town.helperXpShare` de la XP al recogerlo, como la huerta). **Las
    piezas y los legendarios del piso no los junta:** son de quien cuida.
- **Paridad:** a mano rinde ≥ `gearV2.parityManualEdge` (1.15) × el
  ayudante en valor por día (test `animal_parity_test`: 30 días desde 0
  corazones y en régimen; hoy × 1.17–1.19 en 30 días y × 1.26 en régimen).

## 7. XP, oro y paridad con los otros oficios

- Toda la XP va al Granjero (`life.farm.xp`; el id interno sigue siendo
  el de Cultivo) con el bono de XP del árbol, como la cosecha. **Sin tope
  diario** (`xpDayCap` = 0): el día del mundo ya limita el cuidado.
- **Paridad por hora** (test `granjero_parity_test`): una hora de solo
  cultivos, solo animales o mitad y mitad rinde la misma XP y el mismo oro
  ± `incomeBand` (15 %). Modelo (Balance → Oficios: equipo):
  - Cultivos: `incomePlots` (12) parcelas de los cultivos comunes del
    pueblo, una vuelta cada crecimiento + `incomeCropLoopSec` (75 s);
    plantar y regar dan `workXp`, la cosecha su XP y precio (calidad
    esperada sin bonos) menos la semilla.
  - Animales: `incomeAnimalCareSec` (30 s) de cuidado por animal y día
    (caminar, dar de comer, acariciar, juntar, heno) → 120 días de animal
    por hora; animales en régimen (`incomeHearts` = 5), heno comprado.
  - Pesca y minería + herrería se informan al lado
    (`incomeCatchesPerHour`, `incomeVeinsPerHour`, `incomeDigPerHour`).

| Por hora (v0.50) | XP | Oro |
|---|---|---|
| Granjero: cultivos | ≈ 2 770 | ≈ 1 590 |
| Granjero: animales | ≈ 2 770 | ≈ 1 560 |
| Granjero: ambos | ≈ 2 770 | ≈ 1 570 |
| Pesca (pueblo) | ≈ 3 370 | ≈ 2 620 |
| Minería + herrería (Bosque) | ≈ 1 300 | ≈ 1 460 |

Pesca y minería quedan como estaban: entre esos oficios la paridad que
se mide es de equipo (`profession_parity_sim_test`), no de XP ni oro por
hora; emparejar los tres en XP/oro es otro ajuste, a decidir por el
dueño. Por animal y día (cualquier especie): ≈ 23 XP y ≈ 13 oro neto de
heno.

## 8. Árbol del Granjero: rama ANIMALES

El árbol del Granjero tiene seis ramas: las cinco de siempre bajo el
título **CULTIVOS** (Tierra, Semilla, Abono, Madera viva, Cocina) y una
nueva bajo **ANIMALES** (`farm_f*`, rama Corral, a la derecha). Misma
forma que las demás (life_trees_v2.md): 10 escalones, la bifurcación de
los escalones 4–7 y el remate exclusivo `cap`. Efectos (`LifeFx`):

| Nodo | Nombre | Efecto | Valor |
|---|---|---|---|
| f1 | Mano tibia | `petCare`: × cariño por caricia | +15 % |
| f2 | Fardo ordenado | `haySilo`: + fardos en cada depósito | +20 |
| f3 | Ojo de pastor | `animalQuality`: chance de +1 calidad al juntar | 5 % |
| f4–f7 (camino A) | Pluma suelta, Rebaño que recuerda, Cepillo de cerda, Muda del eco | `partDrop`: × chance de piezas | +15/15/20/25 % |
| f4s–f7s (camino B) | Nido doble, Ubre generosa, Doble esquila, Corral que rinde | `animalDouble`: chance de producto doble | 4/4/5/7 % |
| f8 | Granero del ayer | `haySilo` y `petCare` | +30, +15 % |
| f9 | Pastor del tiempo | `animalQuality` | 8 % |
| f10 | Corral de las eras | `animalLegend` (legendarios y forja) y `animalQuality` | +2 %, 10 % |

Los números están en Balance → Oficios: árboles (`farm_f*`). La paridad
de § 7 se mide sin árbol: la rama ANIMALES suma lo mismo que las de
CULTIVOS a su lado (calidad, dobles, piezas).

## 9. Piezas de animal (forja por piezas)

Los animales **nunca se matan**: las piezas salen del cuidado. No hay
cuero.

| Pieza | Quién | Cómo | Encaja en |
|---|---|---|---|
| Pluma | gallina, pato | se muda: aparece en el piso del gallinero al día siguiente de comer | engaste |
| Cuerno mudado | vaca, cabra | se muda: aparece en el piso del establo | cabeza o engaste |
| Pelaje mudado | vaca, cabra | al cepillarlas (acariciar) | mango o engaste |
| Lana fina | oveja | al esquilar con ≥ `woolHearts` corazones | mango o engaste |

- **Frecuencia:** por evento, `partBase` + `partPerHeart` × corazones
  (6 % + 4 % por corazón: 26 % a cinco), × (1 + `partDrop` del árbol).
- **Calidad:** la del producto según los corazones (§ 4.3, + Ojo de
  pastor): normal, rara o épica. Id de material
  `ap_<especie>_<pieza>_<q>` (q = 0, 1, 2), nivel 3 / 4 / 5; como
  material de forja vale `partQNormal/Raro/Epico` (0.6 / 0.8 / 1).
- Se guardan en los materiales de herrería (como las escamas y huesos de
  pez) y se usan en la forja por piezas (profession_gear_v2.md § 3).
  **En el engaste dan la afinidad del animal** (pato agua, oveja sagrado,
  gallina fuego, cabra electro, vaca físico). En cabeza y mango dan
  color y calidad (cuerno marfil, pelaje castaño, lana crema).
- Origen en los tooltips: "Lo deja un animal de la granja si lo
  cuidás" (`ItemSourceKind.ranch`).

## 10. Productos legendarios y la forja de Brann

- A cinco corazones (`maxHearts`), cada vez que un animal completa su
  producto hay `legendChance` (3 %) + `animalLegend` del árbol de que
  deje además un **producto legendario** en el piso:

| Animal | Legendario | Arma que forja Brann | Firma |
|---|---|---|---|
| Gallina | Huevo dorado | Varita | abrasador |
| Pato | Huevo de la marea quieta | Arco | impetuoso |
| Vaca | Cuerno ancestral | Hacha | feroz |
| Cabra | Cuerno del risco eterno | Lanza | rúnico |
| Oveja | Vellón del eco | Báculo | de la vida |

- Se guardan en la bolsa de granja con calidad legendaria (`<id>@3`);
  **no se venden**.
- En la forja de Brann, al lado de la forja de peces legendarios:
  FORJAR cuesta el producto y `animalForgeGold` (1500) oro y pide
  Granjero `animalForgeLevel` (12). Sale Épica, o Legendaria con
  `animalForgeLegend` (30 %) + `animalForgeLegendTree` × `animalLegend`
  del árbol. Afinidad del animal, calidad de ayudante (la hace Brann),
  `pt = ['ranch', <especie>]`, colores de cabeza y mango de sus piezas.
  `SmithOp.animalForge`.
- Lore (BORRADOR): el animal que confía del todo guarda un eco de lo que
  fue su especie antes del Mañana; Brann lo templa sin romperlo.

## 11. Máquinas del TALLER DE OFICIOS

- Pestaña nueva **MÁQUINAS** en el TALLER DE OFICIOS (al lado de
  CRAFTEO y HERRAMIENTAS): grilla de 6 columnas tipo INVENTARIO con los
  productos de animal que se pueden procesar; el detalle a la derecha
  muestra entrada → salida, la calidad (se conserva), el precio antes y
  después, y PROCESAR (1) / PROCESAR TODO.
- **Quesera** (900 oro, `queseraPrice`): leche → queso, leche de cabra →
  queso de cabra. **Mayonesera** (700 oro, `mayoneseraPrice`): huevo →
  mayonesa, huevo de pato → mayonesa de pato. Se compran una vez en la
  misma pestaña (botón gris con motivo: falta oro, falta nivel
  `machineLevel` 7). Se guardan en `farm.at` como las herramientas.
- 1 a 1, al instante, misma calidad. Precio normal: queso / mayonesa 22,
  de cabra / de pato 44 (≈ × 1.7 del crudo). XP `processXp` (2) por
  unidad.
- Lo procesado se vende en GRANJA → VENDER como cualquier producto.
- Como la cocina de la huerta, las máquinas quedan fuera del modelo de
  paridad: suman valor a quien invierte en ellas.

## 12. Renombre y migración

- En la UI y en los tres idiomas: Cultivo → **Granjero** (es-AR),
  Farming → **Farmer** (en), 种植 → **农夫** (zh-Hans) cuando nombra al
  oficio. "Cultivo/cultivos" sigue nombrando a las plantas.
- Ids internos sin cambios: `LifeSkillKind.cultivo`, `life.farm`,
  `farm_*` del árbol. Los guardados viejos cargan igual: sin `d` el
  animal no tiene nada en el piso; los nodos `farm_f*` empiezan libres;
  las máquinas y los productos nuevos simplemente no están.

## 13. Red y guardado

- **Protocolo 100** (`wire.dart`): `TownBuild` suma `an` (animales) y `hy`
  (heno en el depósito); `FarmSkills` suma `ag` (productos por clave
  `<producto>@<calidad>`), `at` (herramientas de granja) y `hy` (heno);
  acciones `TownOp.buyAnimal / animalFeed / animalPet / animalCollect /
  depositHay` y `FarmShopOp.buyHay / buyRanchTool / makeHay / sellGoods`.
- **Protocolo 101** (reforma del Granjero): `FarmAnimal.d` (lo del piso),
  las piezas `ap_*` en los materiales (`ore`), los nodos `farm_f*`, las
  máquinas en `at`, los productos procesados y legendarios en `ag`,
  `FarmShopOp.processGoods` (`id` clave, `n` cantidad) y
  `SmithOp.animalForge` (`g` = id del legendario).
- Todo lo valida el anfitrión (co-op host-authoritative); el corral viaja
  en el pueblo del snapshot.
- **Guardado:** aditivo y tolerante. Las claves de especie, producto o
  pieza que no existan se descartan al cargar.

## 14. Previews

`docs/preview/animals/*.png` y `docs/preview/granjero/*.png` (con
`PREVIEW=1`, tests `test/features/world/animal_preview_test.dart` y
`granjero_preview_test.dart`): árbol del Granjero con sus dos ramas,
corral con una pieza en el piso, forja por piezas con piezas de animal,
forja legendaria de animales y la máquina de queso / mayonesa.

### 7.1 Paridad entre todos los oficios (aprobada por el dueño)

Pesca y Minería + herrería se reajustaron solo con `kTuning` para rendir
lo mismo que el Granjero (± `incomeBand`, `granjero_parity_test` cubre
los cuatro caminos): Pesca `xpComun/Raro/Epico/Legendario` 0.82 / 2.05 /
4.9 / 12.3 y `sellMult` 0.6 (precio de venta = catálogo × `sellMult`);
Herrería `mineXp` 17, `digXp` 2, `smeltXp` 9; `incomeHearts` 5.

| Camino | XP/h | Oro/h |
|---|---|---|
| Granjero: cultivos | 2774 | 1591 |
| Granjero: animales | 2767 | 1559 |
| Granjero: ambos | 2771 | 1575 |
| Pesca | 2759 | 1578 |
| Minería + herrería | 2749 | 1461 |
