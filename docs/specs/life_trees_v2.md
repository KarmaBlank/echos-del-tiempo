# Spec: Árboles de oficios v2 (OFICIOS)

Estado: implementado (reemplaza las §§ 3–4 y el árbol de Herrería de
`life_skill_trees.md`, que queda como historia). Relacionadas:
`fishing.md`, `farming.md` (§ 17 Cocina), `mining_smithing.md`,
`roles.md` §§ 5–6.
Código: `data/life_tree_catalog.dart` (forma y valores por defecto),
`rules/life_tree_rules.dart`, `panels/life_skills_view.dart`.
Números: Editor → Balance → Oficios: árboles (`kTuning['lifeTree']`,
que incluye `kLifeTreeTuning`). Textos: `data.life_trees.*` (nombres de
nodo y de rama) y `ui.town.trades.fx.*` / `ui.town.trades.grant.*`
(líneas de efecto y de entrega), en es-AR, en y zh-Hans.

## 1. Idea
Los oficios **dan cosas**, no solo porcentajes chicos. Cada árbol tiene
una raíz gratis y **5 ramas de 10 escalones que se bifurcan** (71
nodos: § 2.1). Cada rama es
un estilo de juego; muchos nodos entregan objetos reales una sola vez
(armas de tu clase, cañas, cebos, materiales de forja, materiales de
Ecos, comidas con buff de combate, oro, materiales de oficio) y el
escalón 10 de cada rama es un **remate** notable.

## 2. Forma y reglas
- Raíz (escalón 0, gratis): +5 % XP del oficio. Une con el escalón 1 de
  las 5 ramas `a..e` (izquierda → derecha).
- Dentro de una rama, un nodo se toma con algún vecino tomado (las
  ramas no se cruzan entre sí).
- **Escalón por nivel:** el escalón `t` pide nivel del oficio ≥
  `tierLevelStep × (t − 1) + 1` (por defecto 3 → el remate a nivel 28;
  el máximo es 30).
- Costo: escalones 1–6 = 1 punto, 7–9 = 2, 10 = 3 (una rama entera = 15).
  Puntos ganados como hoy: `(nivel − 1) × pointsPerLevel` = 29 a nivel 30,
  así que se completan ~2 ramas: hay que elegir.
- **Un solo remate por árbol** (grupo excluyente `cap`).
- Reinicio gratis por oficio, como antes: devuelve todos los puntos.
- **Bifurcación (§ 2.1).**
- Mensajes de bloqueo, en orden: ya lo tenés, faltan puntos, nivel del
  oficio, no está conectado, ya elegiste otro remate, inventario lleno
  (solo si el nodo entrega un arma que todavía no recibiste).

## 3. Lienzo (UI)
Pestaña OFICIOS de PERSONAJE: tarjetas de oficio | árbol | detalle.
- El árbol se dibuja con el mismo organismo que el ÁRBOL de PERSONAJE
  (`SkillTreeCanvas`, `features/passive_tree/presentation/`): los mismos
  pintores (`PassiveTreePainter` para enlaces y nodos,
  `TreeLabelsPainter` para los nombres en px de pantalla), arrastre,
  rueda y botones de zoom (−, +, VER TODO). Al abrir y al cambiar de
  oficio encuadra el árbol entero.
- Forma de árbol (`lifeTreeCatalog`, `lifeNodePos`): la raíz abajo al
  centro y las 5 ramas que suben abriéndose como una copa
  (`0.7 + 1.15·√t` unidades entre ramas); en los escalones 4–7 cada rama
  se separa en sus dos sub-caminos (el segundo hacia afuera; la rama del
  medio, a la derecha) y se juntan en el 8. Escalón `t` a la altura
  `1 + 1.05·t`. Remates = hexágono (keystone), nodos mayores = notable
  (borde dorado), el resto = nodo chico. Sin el anillo central del
  árbol de clase.
- Compuertas de nivel discretas: una línea punteada tenue por escalón
  (más marcada si el oficio ya llegó a ese nivel) con su "Nv N" a la
  izquierda; el nombre de cada rama arriba de su remate.
- Estados iguales al árbol principal: tomado = verde (remate tomado =
  rojo keystone), disponible = celeste, bloqueado = gris azulado; enlace
  verde si ambos extremos están tomados. Al pasar el mouse (o con el
  nodo elegido) se resalta en dorado su rama y el nodo.
- Los nombres de los nodos NO van junto al nodo (no entran sin
  pisarse): van en el tooltip de ancho fijo (`DsTooltip`: nombre,
  efectos, entregas, estado) y en el detalle de la derecha: nombre,
  rama, escalón, costo, nivel pedido, efectos, entregas ("ya recibido"
  si se reclamó), estado, puntos, TOMAR y REINICIAR (GRATIS), todo en
  `DsText.body` (el tamaño del detalle del ÁRBOL). Botones
  deshabilitados en gris.
- Nada se trunca. Vista previa: `LIFE_TREE_PREVIEW=1 flutter test
  test/features/world/life_tree_view_test.dart` →
  `docs/preview/life_tree_view.png` y `life_tree_<oficio>.png`.
- Los árboles de ascensión (`ascension.md`) ya usan nodos sin etiqueta
  con tooltip; no cambian.

## 4. Entregas (una sola vez)
Al tomar un nodo con `grants`, el host entrega cada cosa y anota el nodo
en `life.lc` (reclamados). Reiniciar no quita lo recibido y volver a
tomar el nodo **no** vuelve a entregar (evita duplicar).
| Clave | Qué entrega |
|---|---|
| `gold` | oro (créditos) |
| `mat:<id>` | material de Ecos (`esquirla`, `cristal`, `prisma`, `ancla`) |
| `ore:<id>` | material de forja (`kSmithMaterials`, con el tope de pila) |
| `craft:<id>` | material de oficio (`fibra`, `cebo`, `tabla`) |
| `bait:<id>` | cebos |
| `rod:<id>` | una caña (si ya la tenés, no pasa nada) |
| `meal:<id>:<q>` | comidas a la bolsa (calidad 0 normal … 3 legendaria) |
| `weapon:<tier>` | un arma Común de **tu clase** del rango pedido (o el más alto menor) |
La cantidad es el valor del Balance del nodo.

## 5. Efectos continuos
Los mismos de v1 (`fishing.md` § 9, `farming.md` § 9, `roles.md` § 5–6):
`zone, bite, loot, legend, auto, grow, quality, extra, helper, seed,
water, forge, sell, xp, hp, atk`, más uno nuevo:
- `meal`: +N misiones que dura cada comida que comés o te sirven
  (suma de los tres árboles; `CookingRules.eat` / `serve`).
`hp` y `atk` (poder de aventurero) suman los tres árboles; `forge` tiene
tope `smithForgeCap`.

### 2.1 Bifurcaciones
Cada rama es un árbol, no una línea: escalones 1–3 = tronco; en los
escalones 4–7 (`kLifeForkFrom`..`kLifeForkTo`) se abre en **dos
sub-caminos** que se vuelven a unir en el escalón 8, que pasa a ser un
nodo mayor; 9 y el remate 10 siguen únicos.
- Sub-camino principal: los nodos de siempre (`<rama><t>`).
- Segundo sub-camino: `<rama><t>s` (p. ej. `fish_a4s`), nombres en
  `kLifeForkNames` + `data.life_trees.node.<id>.name`. Cada uno es la
  alternativa hermana del nodo principal de su escalón (mismo costo) con
  su propia mecánica (tabla de abajo); sin entregas salvo las recetas de
  Abono.
- Con un sub-camino alcanza para seguir; si sobran puntos se pueden
  tomar los dos. El poder total por punto es el mismo (los puntos
  ganados no cambian: siguen alcanzando ~2 ramas).
- Se arma en `growLifeTree` a partir de las tablas de 51 nodos: ningún
  id se borró ni cambió de escalón.

Efectos propios por sub-camino (árbol v2, `kLifeTreeVersion` = 2,
`kLifeForkFx`): los escalones 4–7 de **cada** sub-camino llevan su
propia mecánica (claves `<id>x` para A = principal, `<id>s` para B,
`<id>y` para el compañero de los escalones 5–6 de `kLifeForkCompanion`;
números en `kLifeTreeTuning`). Las entregas del camino principal se
conservan; la rama Abono suma las recetas de abono de brasa / miel /
escarcha (`kLifeForkGrants`). El nodo del escalón 8 es mayor.

| Oficio | Rama | A (principal) | B (segundo) |
|---|---|---|---|
| Pesca | Calma | `calm`: pesca tranquila / automática espera menos | `twin`: pesca doble |
| Pesca | Hondura | `chest`: más cofres y armas hundidas | `big`: peces más grandes |
| Pesca | Red | `sell`: el oficio se vende mejor | `net`: red de balsa (pesca al navegar) |
| Pesca | Arpón | `raft`: balsa más rápida | `harpoon`: arponear un pez grande |
| Pesca | Mesa | `fishMeal`: comidas de pescado curan / potencian más | `fishBuff`: + ATK / MAG |
| Cultivo | Tierra | `waterArea`: riego 3×3 (+ `water`) | `grow` |
| Cultivo | Semilla | `seedBack`: más semillas | `mutate`: variedades mutadas (semillas de arma) |
| Cultivo | Abono | `compost`: más bolsas (+ recetas) | `compostArea`: abono en área (+ `grow`) |
| Cultivo | Madera viva | `livingRarity`: calidad del arma viva | `livingAffix`: afijo extra |
| Cultivo | Cocina | `mealPower`: comidas potencian más | `meal`: buffs más largos |
| Herrería | Forja | `forge`: forjar más barato | `forgeAffix`: afijo extra / rareza más (+ `xp`) |
| Herrería | Veta | `veinArea`: pico en área con indicador | `rareOre`: mineral más raro |
| Herrería | Fundición | `smeltDouble`: lingote doble | `salvage`: desarmar devuelve más |
| Herrería | Pico | `mineSpeed`: picar más rápido | `detect`: vetas ocultas a la vista (radio) |
| Herrería | Encargos | `orderPay`: encargos pagan más | `orderChest`: cofre por encargo |

Nombres de rama renombrados: Cultivo = Tierra, Semilla, Abono, Madera
viva, Cocina; Herrería = Forja, Veta, Fundición, Pico, Encargos. En el
lienzo los rótulos de rama y "Nv N" se dibujan 1.6× (`labelScale`).

## 6. Migración
Los ids v1 (`p_*`, `c_*`, `h_*`) no existen en v2: al cargar el perfil se
descartan, lo que **devuelve todos los puntos** (los puntos se calculan
del nivel, no se guardan). `life.lc` vacío en saves viejos.
Red: el perfil viaja con `life.lc` → protocolo 82.
Bifurcaciones (§ 2.1): solo se **agregan** nodos y enlaces, el camino
principal de cada rama sigue entero, así que los saves v0.49 quedan
válidos tal cual: no hay devolución de puntos ni cambio de protocolo
(los ids viajan como texto).

**Árbol v2 (efectos por sub-camino, protocolo 92):** como cambiaron los
efectos de los escalones 4–7, al cargar un perfil sin `life.tv` ≥ 2 se
quitan todos los nodos de rama de escalón ≥ 4 (`lifeNodeRefunded`) de
los tres árboles: **se devuelven esos puntos** y `life.rf` = true
muestra el aviso en OFICIOS (`ui.town.trades.refunded`) hasta tomar un
nodo. Las entregas ya cobradas (`life.lc`) no se repiten.

## 7. Árboles (todos los nodos)
Valores: fracción (0.05 = 5 %) salvo `quality`, `auto` y `meal`
(números crudos). ★ = remate (excluyente).


### Pesca (`fish_*`, 51 nodos)

Raíz `fish_r` **Pescador** (gratis): xp 0.05.

| Rama | T | Id | Nodo | Costo | Efectos (fx valor) | Entrega (una vez) |
|---|---|---|---|---|---|---|
| a Calma | 1 | `fish_a1` | Muñeca firme | 1 | zone 0.04 | — |
| a Calma | 2 | `fish_a2` | Ojo de boya | 1 | bite 0.05 | — |
| a Calma | 3 | `fish_a3` | Respiración lenta | 1 | zone 0.04 | — |
| a Calma | 4 | `fish_a4` | Hilo tenso | 1 | bite 0.05 | bait:lombriz ×10 |
| a Calma | 5 | `fish_a5` | Agua quieta | 1 | zone 0.05 | — |
| a Calma | 6 | `fish_a6` | Paciencia vieja | 1 | bite 0.06 | — |
| a Calma | 7 | `fish_a7` | Pulso quieto | 2 | zone 0.06, bite 0.05 | — |
| a Calma | 8 | `fish_a8` | Escucha del lago | 2 | zone 0.06 | bait:larva_brillante ×8 |
| a Calma | 9 | `fish_a9` | Hora sin prisa | 2 | bite 0.08 | — |
| a Calma | 10 | `fish_a10` | Lago dormido ★ | 3 | zone 0.12, bite 0.12 | rod:cana_eco ×1 |
| b Hondura | 1 | `fish_b1` | Rastreador | 1 | loot 0.08 | — |
| b Hondura | 2 | `fish_b2` | Llamado del eco | 1 | legend 0.05 | — |
| b Hondura | 3 | `fish_b3` | Ojo de ruinas | 1 | loot 0.1 | — |
| b Hondura | 4 | `fish_b4` | Corriente vieja | 1 | legend 0.06 | — |
| b Hondura | 5 | `fish_b5` | Mareas del tiempo | 1 | legend 0.08 | mat:esquirla ×3 |
| b Hondura | 6 | `fish_b6` | Fondo de era | 1 | loot 0.12 | — |
| b Hondura | 7 | `fish_b7` | Lance del Mañana | 2 | legend 0.1 | — |
| b Hondura | 8 | `fish_b8` | Restos hundidos | 2 | loot 0.15 | mat:cristal ×2 |
| b Hondura | 9 | `fish_b9` | Voz del fondo | 2 | legend 0.12 | — |
| b Hondura | 10 | `fish_b10` | Lo que el agua guarda ★ | 3 | legend 0.2, loot 0.25 | mat:prisma ×2 |
| c Red y mercado | 1 | `fish_c1` | Regateo | 1 | sell 0.05 | — |
| c Red y mercado | 2 | `fish_c2` | Red remendada | 1 | auto 1 | — |
| c Red y mercado | 3 | `fish_c3` | Puesto del muelle | 1 | sell 0.05 | gold ×150 |
| c Red y mercado | 4 | `fish_c4` | Cebo prensado | 1 | — | craft:cebo ×6 |
| c Red y mercado | 5 | `fish_c5` | Pescadores del pueblo | 1 | xp 0.08 | — |
| c Red y mercado | 6 | `fish_c6` | Red de pescador | 1 | auto 1 | — |
| c Red y mercado | 7 | `fish_c7` | Lonja | 2 | sell 0.08 | gold ×400 |
| c Red y mercado | 8 | `fish_c8` | Oficio heredado | 2 | xp 0.1 | craft:cebo ×12 |
| c Red y mercado | 9 | `fish_c9` | Gremio del agua | 2 | sell 0.1 | — |
| c Red y mercado | 10 | `fish_c10` | Maestro del lago ★ | 3 | auto 2, sell 0.15 | gold ×1500 |
| d Arpón | 1 | `fish_d1` | Brazos de remo | 1 | hp 0.02 | — |
| d Arpón | 2 | `fish_d2` | Arpón del eco | 1 | atk 0.02 | — |
| d Arpón | 3 | `fish_d3` | Piel de sal | 1 | hp 0.02 | — |
| d Arpón | 4 | `fish_d4` | Anzuelo de hueso | 1 | atk 0.02 | weapon:1 ×1 |
| d Arpón | 5 | `fish_d5` | Marea en las venas | 1 | hp 0.03 | — |
| d Arpón | 6 | `fish_d6` | Filo mojado | 1 | atk 0.03 | — |
| d Arpón | 7 | `fish_d7` | Calma del lago | 2 | hp 0.03, atk 0.02 | — |
| d Arpón | 8 | `fish_d8` | Cazador de orillas | 2 | atk 0.03 | weapon:2 ×1 |
| d Arpón | 9 | `fish_d9` | Ancla del cuerpo | 2 | hp 0.04 | — |
| d Arpón | 10 | `fish_d10` | Arponero del Mañana ★ | 3 | hp 0.06, atk 0.06 | weapon:3 ×1 |
| e Mesa del pescador | 1 | `fish_e1` | Fuego de orilla | 1 | — | meal:mojarra_nabo:0 ×2 |
| e Mesa del pescador | 2 | `fish_e2` | Sal y humo | 1 | xp 0.05 | — |
| e Mesa del pescador | 3 | `fish_e3` | Caldo de espinas | 1 | — | meal:trucha_cebolla:0 ×2 |
| e Mesa del pescador | 4 | `fish_e4` | Mesa larga | 1 | meal 1 | — |
| e Mesa del pescador | 5 | `fish_e5` | Ahumadero | 1 | sell 0.05 | bait:cebo_escarcha ×6 |
| e Mesa del pescador | 6 | `fish_e6` | Receta de la abuela | 1 | — | meal:trucha_cebolla:2 ×2 |
| e Mesa del pescador | 7 | `fish_e7` | Banquete del muelle | 2 | meal 1 | — |
| e Mesa del pescador | 8 | `fish_e8` | Cebo de tormenta | 2 | — | bait:cebo_tormenta ×6 |
| e Mesa del pescador | 9 | `fish_e9` | Sabor del recuerdo | 2 | xp 0.1 | — |
| e Mesa del pescador | 10 | `fish_e10` | Mesa del último día ★ | 3 | meal 2 | meal:trucha_cebolla:3 ×3, bait:senuelo_eco ×5 |


### Cultivo (`farm_*`, 51 nodos)

Raíz `farm_r` **Granjero** (gratis): xp 0.05.

| Rama | T | Id | Nodo | Costo | Efectos (fx valor) | Entrega (una vez) |
|---|---|---|---|---|---|---|
| a Tierra | 1 | `farm_a1` | Surco parejo | 1 | grow 0.05 | — |
| a Tierra | 2 | `farm_a2` | Riego profundo | 1 | water 0.15 | — |
| a Tierra | 3 | `farm_a3` | Tierra viva | 1 | grow 0.06 | — |
| a Tierra | 4 | `farm_a4` | Abono viejo | 1 | water 0.15 | craft:fibra ×6 |
| a Tierra | 5 | `farm_a5` | Raíz del tiempo | 1 | grow 0.08 | — |
| a Tierra | 6 | `farm_a6` | Lluvia guardada | 1 | water 0.2 | — |
| a Tierra | 7 | `farm_a7` | Estación larga | 2 | grow 0.08, water 0.1 | — |
| a Tierra | 8 | `farm_a8` | Surco del ayer | 2 | grow 0.1 | craft:fibra ×12 |
| a Tierra | 9 | `farm_a9` | Savia lenta | 2 | water 0.25 | — |
| a Tierra | 10 | `farm_a10` | Tierra que recuerda ★ | 3 | grow 0.15, quality 0.2 | — |
| b Cosecha | 1 | `farm_b1` | Mano fina | 1 | quality 0.05 | — |
| b Cosecha | 2 | `farm_b2` | Doble surco | 1 | extra 0.05 | — |
| b Cosecha | 3 | `farm_b3` | Ojo de semilla | 1 | seed 0.1 | — |
| b Cosecha | 4 | `farm_b4` | Cesta llena | 1 | extra 0.05 | gold ×150 |
| b Cosecha | 5 | `farm_b5` | Cosecha del eco | 1 | quality 0.1 | — |
| b Cosecha | 6 | `farm_b6` | Hallazgo dorado | 1 | seed 0.15 | mat:esquirla ×3 |
| b Cosecha | 7 | `farm_b7` | Manos propias | 2 | extra 0.08 | — |
| b Cosecha | 8 | `farm_b8` | Grano antiguo | 2 | quality 0.1, seed 0.1 | — |
| b Cosecha | 9 | `farm_b9` | Granero lleno | 2 | extra 0.08 | — |
| b Cosecha | 10 | `farm_b10` | Cosecha de las eras ★ | 3 | quality 0.25, extra 0.12 | mat:cristal ×3 |
| c Capataz | 1 | `farm_c1` | Puesto propio | 1 | sell 0.05 | — |
| c Capataz | 2 | `farm_c2` | Mano derecha | 1 | helper 0.15 | — |
| c Capataz | 3 | `farm_c3` | Tabla tratada | 1 | — | craft:tabla ×6 |
| c Capataz | 4 | `farm_c4` | Mercado del pueblo | 1 | sell 0.05 | gold ×250 |
| c Capataz | 5 | `farm_c5` | Ayudante fiel | 1 | helper 0.15 | — |
| c Capataz | 6 | `farm_c6` | Oficio compartido | 1 | xp 0.08 | — |
| c Capataz | 7 | `farm_c7` | Cuadrilla | 2 | helper 0.2 | — |
| c Capataz | 8 | `farm_c8` | Feria de cosecha | 2 | sell 0.08 | gold ×600 |
| c Capataz | 9 | `farm_c9` | Libro de la granja | 2 | xp 0.1 | — |
| c Capataz | 10 | `farm_c10` | Señor de la huerta ★ | 3 | helper 0.3, sell 0.15 | craft:tabla ×20 |
| d Hoz | 1 | `farm_d1` | Espalda de surco | 1 | hp 0.02 | — |
| d Hoz | 2 | `farm_d2` | Hoz templada | 1 | atk 0.02 | — |
| d Hoz | 3 | `farm_d3` | Manos de tierra | 1 | hp 0.02 | — |
| d Hoz | 4 | `farm_d4` | Horquilla de guerra | 1 | atk 0.02 | weapon:1 ×1 |
| d Hoz | 5 | `farm_d5` | Raíz firme | 1 | hp 0.03 | — |
| d Hoz | 6 | `farm_d6` | Filo de siega | 1 | atk 0.03 | — |
| d Hoz | 7 | `farm_d7` | Cuerpo de estación | 2 | hp 0.03, atk 0.02 | — |
| d Hoz | 8 | `farm_d8` | Guardián del campo | 2 | atk 0.03 | weapon:2 ×1 |
| d Hoz | 9 | `farm_d9` | Tronco viejo | 2 | hp 0.04 | — |
| d Hoz | 10 | `farm_d10` | Segador del ocaso ★ | 3 | hp 0.06, atk 0.06 | weapon:3 ×1 |
| e Fogón | 1 | `farm_e1` | Primer fuego | 1 | — | meal:sopa_nabo:0 ×3 |
| e Fogón | 2 | `farm_e2` | Olla de hierro | 1 | xp 0.05 | — |
| e Fogón | 3 | `farm_e3` | Pan del alba | 1 | — | meal:pan_dorado:0 ×3 |
| e Fogón | 4 | `farm_e4` | Cocina lenta | 1 | meal 1 | — |
| e Fogón | 5 | `farm_e5` | Despensa | 1 | — | meal:guiso_calabaza:1 ×2 |
| e Fogón | 6 | `farm_e6` | Especias del camino | 1 | quality 0.05 | — |
| e Fogón | 7 | `farm_e7` | Mesa del pueblo | 2 | meal 1 | — |
| e Fogón | 8 | `farm_e8` | Recetario antiguo | 2 | — | meal:ensalada_runica:2 ×2 |
| e Fogón | 9 | `farm_e9` | Sobremesa | 2 | xp 0.1 | — |
| e Fogón | 10 | `farm_e10` | Banquete de la memoria ★ | 3 | meal 2 | meal:caldo_invierno:3 ×3 |


### Herreria (`smith_*`, 51 nodos)

Raíz `smith_r` **Aprendiz de fragua** (gratis): xp 0.05.

| Rama | T | Id | Nodo | Costo | Efectos (fx valor) | Entrega (una vez) |
|---|---|---|---|---|---|---|
| a Yunque | 1 | `smith_a1` | Martillo justo | 1 | forge 0.03 | — |
| a Yunque | 2 | `smith_a2` | Golpe medido | 1 | forge 0.03 | — |
| a Yunque | 3 | `smith_a3` | Fuelle viejo | 1 | forge 0.03 | ore:ore_copper ×10 |
| a Yunque | 4 | `smith_a4` | Yunque antiguo | 1 | forge 0.04 | — |
| a Yunque | 5 | `smith_a5` | Carbón de roble | 1 | forge 0.04 | ore:ingot_copper ×5 |
| a Yunque | 6 | `smith_a6` | Temple paciente | 1 | forge 0.04 | — |
| a Yunque | 7 | `smith_a7` | Brasa constante | 2 | forge 0.05 | — |
| a Yunque | 8 | `smith_a8` | Marca del maestro | 2 | forge 0.05 | ore:ingot_bronze ×5 |
| a Yunque | 9 | `smith_a9` | Ritmo del yunque | 2 | forge 0.05 | — |
| a Yunque | 10 | `smith_a10` | Fragua sin tiempo ★ | 3 | forge 0.08, xp 0.15 | — |
| b Veta | 1 | `smith_b1` | Ojo de veta | 1 | — | ore:ore_copper ×15 |
| b Veta | 2 | `smith_b2` | Lingotera | 1 | — | ore:ingot_copper ×8 |
| b Veta | 3 | `smith_b3` | Ámbar escondido | 1 | — | ore:rare_amber ×2 |
| b Veta | 4 | `smith_b4` | Mena de bronce | 1 | — | ore:ore_bronze ×12 |
| b Veta | 5 | `smith_b5` | Esquirla del pozo | 1 | — | mat:esquirla ×4 |
| b Veta | 6 | `smith_b6` | Escarcha en piedra | 1 | — | ore:ore_frost ×12 |
| b Veta | 7 | `smith_b7` | Engranaje perdido | 2 | — | ore:rare_cog ×2 |
| b Veta | 8 | `smith_b8` | Cristal del socavón | 2 | — | mat:cristal ×3 |
| b Veta | 9 | `smith_b9` | Brasa de la montaña | 2 | — | ore:ore_ember ×12 |
| b Veta | 10 | `smith_b10` | Corazón de la mina ★ | 3 | — | ore:ingot_echo ×6, mat:prisma ×3 |
| c Armería | 1 | `smith_c1` | Primera hoja | 1 | — | weapon:1 ×1 |
| c Armería | 2 | `smith_c2` | Filo del pasado | 1 | atk 0.02 | — |
| c Armería | 3 | `smith_c3` | Ojo de oficio | 1 | xp 0.05 | — |
| c Armería | 4 | `smith_c4` | Arma templada | 1 | — | weapon:2 ×1 |
| c Armería | 5 | `smith_c5` | Afilado | 1 | atk 0.02 | — |
| c Armería | 6 | `smith_c6` | Encargo del cuartel | 1 | — | gold ×600 |
| c Armería | 7 | `smith_c7` | Arma del eco | 2 | — | weapon:3 ×1 |
| c Armería | 8 | `smith_c8` | Acero recordado | 2 | atk 0.03 | — |
| c Armería | 9 | `smith_c9` | Prisma de taller | 2 | — | mat:prisma ×1 |
| c Armería | 10 | `smith_c10` | Obra maestra ★ | 3 | atk 0.05 | weapon:3 ×1, mat:prisma ×2 |
| d Mecanismo | 1 | `smith_d1` | Temple | 1 | hp 0.02 | — |
| d Mecanismo | 2 | `smith_d2` | Coraza de chispa | 1 | hp 0.02 | — |
| d Mecanismo | 3 | `smith_d3` | Mecanismo vivo | 1 | hp 0.02, atk 0.01 | — |
| d Mecanismo | 4 | `smith_d4` | Brazo de fragua | 1 | atk 0.02 | — |
| d Mecanismo | 5 | `smith_d5` | Resorte del tiempo | 1 | hp 0.03 | — |
| d Mecanismo | 6 | `smith_d6` | Engranaje del pecho | 1 | hp 0.03 | — |
| d Mecanismo | 7 | `smith_d7` | Pulso de hierro | 2 | atk 0.03 | — |
| d Mecanismo | 8 | `smith_d8` | Malla antigua | 2 | hp 0.03 | — |
| d Mecanismo | 9 | `smith_d9` | Fuerza remachada | 2 | atk 0.03 | — |
| d Mecanismo | 10 | `smith_d10` | Corazón de engranajes ★ | 3 | hp 0.07, atk 0.05 | — |
| e Taller | 1 | `smith_e1` | Taller abierto | 1 | xp 0.05 | — |
| e Taller | 2 | `smith_e2` | Clavos para el pueblo | 1 | — | craft:tabla ×6 |
| e Taller | 3 | `smith_e3` | Encargos menores | 1 | — | gold ×300 |
| e Taller | 4 | `smith_e4` | Aprendices | 1 | xp 0.08 | — |
| e Taller | 5 | `smith_e5` | Herramientas del pueblo | 1 | — | craft:fibra ×10, craft:cebo ×10 |
| e Taller | 6 | `smith_e6` | Fama de la fragua | 1 | — | gold ×800 |
| e Taller | 7 | `smith_e7` | Escuela de oficio | 2 | xp 0.1 | — |
| e Taller | 8 | `smith_e8` | Ancla de la fragua | 2 | — | mat:ancla ×1 |
| e Taller | 9 | `smith_e9` | Herrero del pueblo | 2 | forge 0.03 | gold ×1200 |
| e Taller | 10 | `smith_e10` | Legado de la fragua ★ | 3 | xp 0.2 | gold ×3000, mat:ancla ×2 |

## 8. Granjero: dos ramas, CULTIVOS y ANIMALES (v0.50, protocolo 101)

El árbol de Cultivo pasa a ser el del **GRANJERO** (`animals.md`,
`farming.md` § 21) y tiene **seis** ramas en vez de cinco:

- **CULTIVOS** (título sobre las cinco de siempre): Tierra, Semilla,
  Abono, Madera viva, Cocina (`farm_a*` … `farm_e*`, sin cambios).
- **ANIMALES** (título sobre la sexta): **Corral** (`farm_f*`).

Las demás profesiones siguen con cinco (`lifeBranchesOf(k)`,
`kLifeExtraBranches`). Corral tiene la misma forma que cualquier rama:
escalones 1–10, bifurcación en 4–7 (camino A `farm_f4..7`, camino B
`farm_f4s..7s`) que se une en el 8 (nodo mayor) y el remate `farm_f10`
en el grupo exclusivo `cap` (sigue habiendo un solo remate por árbol).

| Escalón | Nodo | Efecto (`LifeFx`) | Valor (Balance → Oficios: árboles) |
|---|---|---|---|
| 1 | Mano tibia | `petCare` × cariño por caricia | `farm_f1` 0.15 |
| 2 | Fardo ordenado | `haySilo` + fardos por depósito | `farm_f2` 20 |
| 3 | Ojo de pastor | `animalQuality` chance de +1 calidad | `farm_f3` 0.05 |
| 4–7 A | Pluma suelta, Rebaño que recuerda, Cepillo de cerda, Muda del eco | `partDrop` × chance de piezas | `farm_f4x..f7x` 0.15 / 0.15 / 0.2 / 0.25 |
| 4–7 B | Nido doble, Ubre generosa, Doble esquila, Corral que rinde | `animalDouble` chance de producto doble | `farm_f4s..f7s` 0.04 / 0.04 / 0.05 / 0.07 |
| 8 | Granero del ayer | `haySilo`, `petCare` | `farm_f8` 30, `farm_f8_2` 0.15 |
| 9 | Pastor del tiempo | `animalQuality` | `farm_f9` 0.08 |
| 10 | Corral de las eras | `animalLegend`, `animalQuality` | `farm_f10` 0.02, `farm_f10_2` 0.1 |

Lienzo: con seis ramas el abanico se centra en el medio (la rama
de índice `i` va a `i − (n − 1) / 2` × la apertura); sobre las ramas, los
títulos de cada rama y, más arriba, CULTIVOS sobre las cinco primeras y
ANIMALES sobre Corral. Puntos: los mismos por nivel; la rama nueva solo
abre más opciones.

Migración: ninguna. Los nodos `farm_f*` empiezan libres; el árbol
guardado de un perfil viejo carga igual (`kLifeTreeVersion` sin cambio).
