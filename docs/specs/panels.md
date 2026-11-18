# Spec: Paneles (mostrador, votación, preparación, armería, personaje, árbol)

Fuente de verdad: prototipo `ecos-del-tiempo.html`:
- `renderPanel`, `previewOf`, `reqHtml`, `skHtml`, `wPowTxt`, `itemsHtml`,
  `fuseHtml`, `upHtml`, `mustAlloc`, `alloc`, `openPanel`, `closePanel`
  y el `click` de `#board` (líneas 1255-1363);
- `renderVote` (1364-1375);
- `treeHtml` (363-376), `fxTxt` y `KEYS` (344-356), `EXCL` (352);
- `weaponTip`, `descSkill`, `stDesc` (1108-1131);
- constantes `STATN`/`STATD` (120-121), `UPSTATS`, `upCost`, `FUSE_COST`
  (243-267).

Las **reglas** (qué es válido) son de progression.md y missions.md y las
aplica solo el motor (`SessionEngine.apply`). Este spec dice qué muestra
cada panel, qué acción manda cada botón y cuándo el botón aparece
deshabilitado y con qué motivo. Todo pasa por el `SessionController`
(una acción `SessionAction` por botón); si el host la rechaza no cambia
nada.

Implementación:

| Pieza | Archivo |
|---|---|
| Motivos de bloqueo (espejo de las reglas) | `lib/features/inventory/domain/shop_guards.dart` |
| Textos de armas y habilidades (`reqHtml`, `wPowTxt`, `skHtml`, `descSkill`, `weaponTip`) | `lib/features/inventory/domain/weapon_text.dart` |
| Vistas previas (stats con otra arma / mejora, resultado de fusión) | `lib/features/inventory/domain/shop_preview.dart` |
| Pestañas de tienda (COMPRAR, FORJA, FUSIÓN, CONSUMIBLES) y ficha de arma | `lib/features/inventory/presentation/shop_sections.dart` |
| Armería | `lib/features/inventory/presentation/armory_panel.dart` |
| Personaje (pestañas Atributos / Inventario / Árbol / Filtro) | `lib/features/world/presentation/panels/character_panel.dart` |
| Textos de objetos (ficha / tooltip, requisitos) — loot v2 | `lib/features/inventory/domain/item_text.dart` |
| Colores de rareza, ícono de objeto, etiqueta de loot con el estilo del filtro | `lib/features/inventory/presentation/item_widgets.dart` |
| Inventario (grilla 8×5, equipada, dar / tirar, compañeros) | `lib/features/inventory/presentation/inventory_tab.dart` |
| Mesa de fusión en 3 pasos (pestaña FUSIÓN) | `lib/features/inventory/presentation/craft_bench.dart` |
| Editor del filtro de loot (pestaña FILTRO) | `lib/features/inventory/presentation/loot_filter_tab.dart` |
| Árbol (dibujo + info lateral) | `lib/features/passive_tree/presentation/passive_tree_view.dart` |
| Textos del árbol (`fxTxt`, `KEYS`) y estado de cada nodo | `lib/features/passive_tree/domain/passive_text.dart` |
| Mostrador, votación, preparación, tarjeta de misión | `lib/features/missions/presentation/*.dart` |
| Textos de objetivo y recompensas de una misión | `lib/features/missions/domain/mission_text.dart` |
| Marco (ayuda `?`, teclado), botones, filas y secciones | `lib/app/theme/panel_frame.dart` |
| Lista + detalle, fila elegible, antes → después, niveles, costo, línea "qué hace" | `lib/app/theme/panel_widgets.dart` |

Tests: `test/features/inventory/armory_panel_test.dart`,
`test/features/inventory/inventory_tab_test.dart`,
`test/features/inventory/craft_bench_test.dart`,
`test/features/inventory/loot_sinks_ui_test.dart`,
`test/features/inventory/loot_filter_tab_test.dart`,
`test/features/inventory/item_text_test.dart`,
`test/features/missions/mission_panels_test.dart`,
`test/app/panel_frame_test.dart`,
`test/features/world/character_panel_test.dart`,
`test/features/passive_tree/passive_tree_view_test.dart`,
`test/features/inventory/shop_guards_test.dart`.

## Botones con motivo

Un botón que el motor rechazaría se dibuja deshabilitado (`PanelButton`
con `reason`) y el motivo va en texto `muted` a su izquierda, para que se
entienda sin pasar el mouse. Los motivos (`shop_guards.dart`) replican
exactamente el orden de las comprobaciones del motor:

| Acción | Motivos posibles (en orden) |
|---|---|
| Comprar arma (`BuyWeaponAction`) | `Solo en el lobby o la preparación` (`canShop`), `No está a la venta`, `Ya la tienes`, `Faltan $N`, `Inventario lleno` |
| Comprar consumible (`BuyItemAction`) | `canShop`, `Máximo 9`, `Faltan $N` |
| Equipar (`EquipAction`) | `Solo en el lobby o la preparación` (`canShop`), `No la tienes`, `Equipada`, `Nivel N` (nivel de la base), `Confirma puntos` (cumple con el reparto pendiente pero no con los atributos actuales), `Requisitos: FUE 14 DES 8` (los que faltan). **Cualquier clase** equipa cualquier arma si cumple (loot.md § 0.2) |
| Forjar (`UpgradeAction(uid, stat)`) | `canShop`, y el `error` de `CraftRules.forge` (`MAX` = 5 por estadística, `Tope de forja (N)` = tope de la rareza leído de `Rarity.forgeCap`, `Faltan $N`) |
| Fusión libre (`CraftAction`) | `canShop`, y el `error` del `CraftResult` de la operación (loot.md § 19.5: `Está equipada`, `Arma inicial`, `Sin lugar (…)`, `Solo a un arma Épica`, `Pasiva única`, `Ya está en la rareza máxima`, `Falta Cristal de Era`, `Faltan $N`, ...) |
| Desarmar / vender (`CraftAction` `salvage` / `sell`, y en lote `salvageAll` / `sellAll`) | `canShop`, y el `error` del motor (loot.md § 21: `Está equipada`, `Arma inicial`, `No hay armas de rareza <R>`) |
| Reforjar base (`CraftAction.reforge`) | `canShop`, `Está equipada`, `Arma inicial`, `Un Legendario no cambia de base`, `Ya tiene esa base`, `Base de nivel N (el arma es de nivel M)`, `Falta <material>`, `Faltan $N` |
| Dar (`GiveItemAction`) | `No en batalla`, `No hay compañeros en la sala` (solo), el `error` de `InventoryRules.take` (`Equipada`, `Arma inicial`, `No tienes tantos`), `<nombre>: Inventario lleno` / `<nombre>: Máximo N` (`cannotReceive` del compañero) |
| Tirar al piso (`DropItemAction`) | `Solo en el lobby o en el campo`, `Estás K.O.`, el `error` de `take` |
| Mover casilla (`MoveInventoryAction`) | (siempre; el motor ignora un movimiento inválido) |
| Guardar filtro (`SetLootFilterAction`) | `Sin cambios`, `Máximo 8000 caracteres`, `Corrige N errores` (la UI no guarda un filtro con líneas que el parser ignoraría) |
| Proponer misión (`ProposeMissionAction`) | `Ya hay una votación` |
| Confirmar puntos (`AllocateStatsAction`) | `No en batalla`, `Reparte algún punto` |
| Cerrar el panel de personaje | `Reparte tus puntos` (mientras `mustAllocate`) |
| Reiniciar puntos (`RespecAction`) | `No en batalla` (gratis y en cualquier otro modo mientras `ProgressionRules.freeRespec`; el botón dice `REINICIAR PUNTOS (GRATIS)` y no se muestra en batalla; con `freeRespec = false`: `canShop`, como el prototipo) |
| Cambiar clase (`ChangeClassAction`) | `Solo en el lobby`, `Es tu clase` |
| Tomar nodo (`TakeNodeAction`) | `No en batalla`, `Ya lo tienes` / `Nodo inicial`, `Sin puntos de árbol`, `Excluye <keystone>`, `Necesita un nodo conectado` |
| Reiniciar árbol (`ResetTreeAction`) | `No en batalla` (o `canShop` sin `freeRespec`), `No hay nodos tomados` (el motor lo acepta igual; la UI no lo ofrece porque no hace nada) |

## Marco común (`PanelFrame`) — pasada de UX v3

Principio: docs/specs/ui_style.md § "Principio: menús minimalistas".
Todos los paneles comparten el mismo esqueleto:

```
TÍTULO [?]                                     (créditos / estado)
[PESTAÑA 1] [PESTAÑA 2] ...                    (si hay pestañas)
Una línea "qué hace" de la pestaña o sección   (dim)
+-- lista compacta --------+  +-- detalle / vista previa -------+
| fila elegida (borde oro) |  | qué es, antes > después, costo  |
| fila                     |  |              [motivo] [PRIMARIO]|
+--------------------------+  +---------------------------------+
[secundario izq.]                    [secundarios] [PRIMARIO / CERRAR]
```

- **`[?]`** (`PanelHelp`) junto al título: pasar el mouse muestra en un
  `RetroTooltip` la ayuda de la pantalla (2-4 líneas: para qué sirve y
  cómo se usa). Todos los paneles lo tienen.
- **Línea "qué hace"** (`PanelHint`, `dim`): debajo de las pestañas o del
  título de cada sección, una sola línea.
- **Lista + detalle** (`PanelSplit`): la lista a la izquierda (360 px)
  con filas compactas elegibles (`PanelListItem`: borde `gold` la
  elegida, `sky` con foco de teclado), el detalle a la derecha con su
  propio scroll y el botón de la acción abajo a la derecha
  (`PanelDetail`). La elección por defecto es la primera fila (o el arma
  equipada).
- **Antes → después** (`StatChange`): `ETIQUETA antes → después`, el
  después en verde si mejora y rojo si empeora; sin cambio solo
  `ETIQUETA valor`. **Niveles** con `LevelPips` (n cuadritos de 5).
- **Costo** (`CostLine`): `Costo $N · Te quedan $M` (si no alcanza,
  solo `Costo $N` y el botón dice `Faltan $X`).
- **Botones de abajo**: los secundarios a la izquierda del todo
  (`leading`: reiniciar, cancelar misión) y a la derecha los demás con el
  **primario último** (abajo a la derecha). En `prep`, los paneles que
  no son el de preparación tienen `< VOLVER A PREPARACIÓN`; fuera de
  `prep` los que no son el de personaje tienen `PERSONAJE [C]` y todos
  `CERRAR [ESC]` (deshabilitado con el motivo `Reparte tus puntos`
  mientras `mustAllocate`).
- **Teclado** (`PanelFrame`, foco atrapado en el panel con un
  `FocusScope`): `Esc` cierra (llama a `onClose`; sin `onClose` el `Esc`
  sigue al mapa), `Tab` / `Shift+Tab` recorren los botones y filas,
  las flechas mueven el foco en esa dirección (o al siguiente /
  anterior), `Enter` / `Espacio` activan el botón o la fila con foco.
  Con un campo de texto enfocado el panel no toca las teclas.

### Menú de pausa

No es un `WorldPanel`: es una capa aparte encima de todo (también de la
batalla) que se abre con `Esc` sin panel ni campo de texto activos o con
`≡ MENU [ESC]`. `Esc` con un panel abierto sigue cerrando el panel.
Contenido, pausa de grupo y ajustes: docs/specs/settings.md.

## Mostrador (`board`, 1271-1276)

Título `MOSTRADOR DE MISIONES` [?]; línea "qué hace": `Propón una
misión: cuando todos votan SÍ pasan a la preparación.` Una **tarjeta**
por misión (`MissionCard`, borde `panelBorder`):

- Fila 1: rango grande (`amber`, 16 px), nombre (negrita), `tipo` en
  `sky` y `Lv recomendado N` (en `red` con `· tu Lv M` si el jugador está
  por debajo).
- `Objetivo:` `Derrota N grupos para abrir la barrera y vence al jefe
  (<nombre del jefe>)` + `· +K objetivo(s) extra al azar (fragmentos,
  sellos o élite)` si `extra > 0`.
- `Rango S:` `< N min sin K.O.`.
- `Recompensas:` `XP y créditos por pelea · bonus S +50% / A +25% · arma
  de tier T al ganar (S 90% · A 70% · B 50%) · cofres nivel C` (T = nº de
  misión, C = `chestTier`). Textos en `missionObjectiveText` /
  `missionRewardText` (`lib/features/missions/domain/mission_text.dart`).
- Botón `PROPONER` abajo a la derecha de la tarjeta (`propose-<id>`,
  `ProposeMissionAction`, cierra el panel); deshabilitado con el motivo
  `Ya hay una votación`.

**Desvío** (un propósito por pantalla): el cambio de clase sale del
mostrador; queda en Personaje › Atributos.

**Zonas (v0.2.0, worldgen.md § 7.2)**: el mostrador lista las 10 zonas
de `ZoneRules.zoneList` en orden:
- Zonas con misión: la `MissionCard` con una línea de zona arriba
  `Zona N · <nombre> · Lv a-b · F pisos · Jefe: <jefe>` (en el color de
  la zona) y el objetivo por pisos `Derrota K grupos por piso (F pisos)
  y vence al jefe (<jefe>) en el último` (+ extras). Bloqueada: borde
  gris, la línea `Bloqueada: vencé a <jefe> en <zona>` en rojo y
  `PROPONER` deshabilitado con ese motivo (`Bloqueada`).
- Zonas "Próximamente" (sin misión): una fila compacta gris
  `Zona N · <nombre> · Lv a-b · Próximamente` (`zone-soon-<N>`), sin
  botón.
- La línea "qué hace" suma `También podés entrar por las puertas del
  mapa del mundo.`

**Resultado** (zonas): debajo del nombre de la misión, `Zona N ·
<nombre> · Piso P/F` (P = piso alcanzado, F en una victoria); si el
jugador local desbloqueó una zona (`MissionResult.unlocked[local]`):
`¡Zona M desbloqueada! <nombre>` en dorado (`results-unlocked`), y una
línea por los demás jugadores que también desbloquearon.

## Votación (`renderVote`, 1364-1375)

Caja arriba al centro (debajo de la barra de misión) en el lobby
mientras hay votación: `Votación · <quién> propone <misión> (rango R) ·
N/M sí`, la lista de jugadores con `>` verde si votó que sí o `...` gris
si no, y `SÍ [Y]` / `NO [N]` (`VoteMissionAction`) o, si ya votó,
`Esperando al resto...` + `CANCELAR` (`VoteMissionAction(false)`).
Reemplaza el aviso de una línea del HUD.

## Preparación (`prep`, 1341-1349)

Título `PREPARACIÓN · <misión>` [?]. Pestañas `MISIÓN · COMPRAR ·
FORJA · FUSIÓN · CONSUMIBLES` (las cuatro últimas son las de la
armería, ver abajo; en `prep` la armería del lobby no se abre).

- **MISIÓN** (por defecto): a la izquierda la `MissionCard` (sin botón);
  a la derecha `Grupo · N/M listos` con una fila por jugador (`LISTO` en
  verde o `preparando...` en `dim`, nombre, clase y nivel; el local en
  dorado), `Tu equipo` (arma equipada, pociones, éteres, créditos) y el
  aviso naranja `En la misión no hay tienda ni cambio de arma`.
- Abajo: `CANCELAR MISIÓN` a la izquierda (`CancelPrepAction`),
  `PERSONAJE [C]` y el primario `¡LISTO!` (verde) / `YA NO ESTOY LISTO`
  (`ReadyAction`) abajo a la derecha, visibles en todas las pestañas.
- `Esc` no cierra la preparación (no hay a dónde volver).

## Armería (`shop`, 1352-1358)

Título `ARMERÍA` [?], a la derecha `Créditos $N`. Pestañas `COMPRAR ·
FORJA · FUSIÓN · CONSUMIBLES` (`ArmoryTab`), cada una con su línea "qué
hace" y su lista + detalle. Las mismas pestañas van dentro de la
preparación. Abajo: `PERSONAJE [C]` y `CERRAR [ESC]`.

**Loot v2** (loot.md § 0, § 16, § 19, § 20): la armería trabaja sobre
instancias (`ItemInstance`, por `uid`) y ya no filtra por clase. Lo que
sigue reemplaza a las subsecciones viejas de COMPRAR, FORJA y FUSIÓN
donde difieren (esas quedan como referencia del prototipo).

- **COMPRAR** (`Bases Comunes por nivel. Cualquier clase puede equiparlas
  si cumple nivel y requisitos.`): filtro por familia arriba de la lista
  (`buy-family-<familia>`: TODAS / una por clase; por defecto la tuya),
  bases con precio > 0 ordenadas por nivel (`shop-row-<id>`): nombre,
  `Nv L · tipo`, y a la derecha `TIENES`, o `OK` verde (cumple nivel y
  requisitos) / `Req` rojo y el precio. Detalle: la ficha del arma Común
  (§ "Ficha de objeto"), `Si la equipas:` ATQ / MAG / VEL / CRÍT / DEF
  antes → después, `CostLine` y `COMPRAR $precio`.
- **FORJA** (`Sube 1 nivel una estadística (máx 5 c/u) hasta el tope de
  la rareza. Cada 2 niveles de forja, la pasiva del arma sube 1.`):
  lista de tus armas (`forge-row-<uid>`) con el nombre en el color de la
  rareza y `forja n/tope`. Detalle: nombre, `Forja n/tope` con
  `LevelPips` (tantos cuadritos como el tope de la rareza: Común 3 …
  Legendario 10, `Rarity.forgeCap`), la pasiva actual y **cuándo sube**
  (`Sube a <nombre nivel> en la próxima mejora` / `en N mejoras`, o
  `Pasiva al máximo (V)`; sin pasiva: `Sin pasiva (desde Épico)`); una
  fila por estadística (`forge-stat-<stat>`): pips n/5, `Bono` antes →
  después, efecto en el stat (ATQ/MAG, CRÍT, VEL, DEF) y, si esa mejora
  sube la pasiva, la línea violeta `¡La pasiva sube! <nombre> II → III:
  <efecto>` (`forge-passive-up-<stat>`). Botón `+1 $costo`
  (`up-<uid>-<stat>`) con el motivo del motor. `EQUIPAR`
  (`equip-<uid>`) abajo si no es la equipada.
- **FUSIÓN** = mesa de fusión (`craft_bench.dart`), rediseñada en
  v0.2.0 (pedido del dueño: "el menú de fusión es muy confuso") como un
  **asistente de 3 pasos**: `1 ARMA › 2 ACCIÓN › 3 CONFIRMAR`. Ver
  § "FUSIÓN (v0.2.0: 3 pasos)" abajo.

### COMPRAR

`Armas de tu clase (<clase>). Puedes comprarlas sin cumplir los
requisitos; para equiparlas sí.`

- Lista: las armas de su clase con precio `> 0`, en el orden del
  catálogo (`shop-row-<id>`): nombre, tipo, y a la derecha `TIENES`
  (verde) o `$precio`.
- Detalle: nombre y tipo, `Req:` coloreado (`reqHtml`), `Escala:`
  (`wPowTxt`), `Peso N (-vel.)`, `Habilidades:` con la descripción de
  cada una (`describeSkill`) y la ULT, y **comparación con la equipada**
  (`Si la equipas:` ATQ / MAG / VEL / CRÍT / DEF de la equipada → con
  esta, calculado con `StatsCalculator` sobre la build hipotética,
  `ShopPreview.statsWith`). Abajo `CostLine` y `COMPRAR $precio`
  (`buy-<id>`, `BuyWeaponAction`) con los motivos de la tabla, o
  `TIENES` si ya es suya.

### FORJA (herrería, `upHtml`)

`Cada mejora sube 1 nivel una estadística del arma (máx 5). Las mejoras
se quedan en el arma.`

- Lista: armas propias de su clase (`forge-row-<id>`): `wName` (`+N`) y
  `EQUIPADA` en dorado.
- Detalle: nombre y `EQUIPAR` (`equip-<id>`, **agregado del puerto**)
  si no es la equipada; luego una fila por estadística mejorable
  (`upgradeStatsFor`):
  `Poder ■■□□□ 2/5 · +24% → +36% · ATQ 30 → 33 · [+1 $costo]`
  (`up-<arma>-<stat>`, `UpgradeAction`), o `MAX` en verde. El efecto
  sobre los stats derivados se calcula con la build hipotética
  (`ShopPreview.upgrade`): Poder → ATQ (o MAG en armas mágicas),
  Crítico → CRÍT, Velocidad → VEL, Defensa → DEF. Si el arma no es la
  equipada, el efecto dice `(si la equipas)`. Valores: Poder y Crítico en
  `%` (`round(l × per × 100)`), Velocidad con un decimal, Defensa entero.

### FUSIÓN (`fuseHtml`, $200)

`La base aprende 1 habilidad de otra arma, que se destruye. Cada arma
guarda 1 habilidad fusionada: una nueva reemplaza a la anterior.`

- Lista en tres pasos (`1. Arma base`, `2. Arma a sacrificar`, `3.
  Habilidad a heredar`), filas elegibles `fuse-base-<id>`,
  `fuse-sac-<id>`, `fuse-skill-<id>`. Por defecto: base = la equipada,
  sacrificio = la primera válida, habilidad = la primera. Sacrificables:
  las demás salvo la inicial y la equipada; sin candidatas `(no hay
  armas disponibles)`.
- Detalle = **vista previa** (`ShopPreview.fuse`, que aplica
  `ProgressionRules.fuse` sobre el perfil): `RESULTADO: <base>`, `Ahora:`
  sus habilidades de hoy (en `dim`, la fusionada con `(fusión)`) y
  `Después:` la lista resultante (las del arma + la heredada en verde
  `(nueva)`), `Reemplaza <habilidad>` en naranja si la base ya tenía
  una fusión, la descripción de la habilidad heredada, `Se pierde:
  <sacrificio +N>` en rojo (con sus mejoras y su fusión), `CostLine` y
  `FUSIONAR` (`fuse`, `FuseAction`) con los motivos de la tabla.

### FUSIÓN (v0.2.0: 3 pasos)

Reemplaza a la mesa de loot v2 (fila de 7 operaciones + lista en 3
bloques + detalle). Pedido del dueño: "el menú de fusión es muy
confuso".

**Por qué un asistente de 3 pasos y no un panel de verbos**: la mesa
vieja mostraba a la vez 7 operaciones, dos listas de armas (destino y
sacrificio) y la de mods, y no quedaba claro cuál era "el arma que
mejoro" y cuál "la que se destruye". Con 1000 px de ancho y la fuente
pixel, un panel de verbos (slots a la izquierda + verbos a la derecha +
vista previa) vuelve a meter tres columnas en una pantalla. El
asistente cumple "una pantalla, un propósito" (ui_style.md): cada paso
hace **una** pregunta, las migas dejan volver a cualquier paso con un
clic, y el paso 2 muestra **de antemano** si cada acción se puede y, si
no, por qué. Un usuario que repite (p. ej. re-tirar varias veces) se
queda en el paso 3 y confirma de nuevo.

- **Arriba, siempre**: migas `1 ARMA › 2 ACCIÓN › 3 CONFIRMAR`
  (`bench-crumb-<0|1|2>`, la actual en dorado; clic = ir a ese paso), el
  arma elegida y la acción (`bench-summary`), y a la derecha `Tienes:
  Esquirla xN · Cristal xN · Prisma xN` (`craft-materials`; el tooltip
  explica cada material y que salen del loot o de desarmar).
- **Paso 1 — ¿Qué arma?** (línea `Paso 1 de 3: elige el arma que quieres
  mejorar o cambiar.`): lista de tus armas (`bench-weapon-<uid>`,
  `EQUIPADA` en dorado; por defecto la equipada) y a la derecha su ficha.
  Primario `ELEGIR ESTA ARMA ›` (`bench-next`).
- **Paso 2 — ¿Qué querés hacer?** (línea `Paso 2 de 3: ...`): lista
  ancha (560 px) de acciones agrupadas, cada una con nombre en negrita,
  **una línea** "qué hace" y a la derecha `Se puede` (verde) o el motivo
  (rojo) calculado con la elección por defecto (`bench-op-<op>`,
  `bench-op-why-<op>`). Para traer un mod / la pasiva, `Se puede` si
  **alguna** combinación arma × mod es válida. Clic = paso 3. A la
  derecha, `AHORA` con la ficha del arma.

| Grupo | Acción (`CraftOp`) | Línea "qué hace" |
|---|---|---|
| MEJORAR · con materiales | Re-tirar valores (`reroll`) | Nuevos valores para cada mod, dentro de su rango. Usa 1 Esquirla del Eco. |
| | Agregar un mod (`addAffix`) | Un mod al azar, si el arma tiene lugar. Usa 1 Cristal de Era. |
| | Subir rareza (`upgradeRarity`) | Común → Mágico → Raro → Épico: más lugar para mods (y pasiva en Épico). Usa Prismas Rotos. |
| TRASLADAR · de otra arma, que se destruye | Traer un mod (`transferAffix`) | Copia un mod de otra arma a esta. La otra arma se destruye. |
| | Traer la pasiva (`transferPassive`) | La pasiva de otra arma pasa a esta (las dos Épicas). La otra se destruye. |
| | Traer una habilidad (`transferSkill`) | Esta arma aprende una habilidad de otra, que se destruye. |
| QUITAR · para hacer lugar | Quitar un mod (`removeAffix`) | Borra un mod. Los mods fijos de un legendario no se quitan. |
| CAMBIAR · el tipo de arma | Reforjar base (`reforge`, loot.md § 21.3) | Cambia el tipo de arma (p. ej. arco → báculo) y conserva rareza, mods y forja. |

- **Paso 3 — Vista previa y confirmar** (línea `Paso 3 de 3 · <acción>:
  <qué hace>`). Izquierda = solo lo que hay que elegir:
  - traer: `¿De qué arma? (se destruye)` (`craft-source-<uid>`: solo
    las que sirven —con mods / con pasiva—, nunca la equipada ni la
    última inicial) y `¿Qué mod traer?` / `¿Qué habilidad?`
    (`craft-pick-<i>`);
  - quitar: `¿Qué mod quitar?` (`craft-pick-<i>`);
  - reforjar: `¿Qué base nueva?` con filtro de familia
    (`bench-family-<id>` / `bench-family-all`, por defecto la tuya) y
    las bases posibles (`bench-base-<id>`: nombre, `Nv · tipo`, `OK` /
    `Req` según tus requisitos);
  - mejorar (sin nada que elegir): `AHORA` con la ficha del arma.
  Derecha, siempre en este orden:
  1. `AHORA → DESPUÉS` (`(al azar)` en las aleatorias): nombre antes →
     después (`craft-name`), en reforjar `Base: X (tipo) → Y (tipo, Nv)`
     (`craft-base`) y los requisitos de la base nueva, rareza antes →
     después, `Mods n/max (lugar de un <rareza>)` (`craft-mods-title`)
     con `[¿T1–T5?]` (`craft-tier-help`: tooltip que explica los tiers y
     prefijos / sufijos sin jerga), la lista con `(nuevo)` en verde y
     `(se quita)` en rojo (`craft-mods`), pasiva y habilidades antes →
     después (`(traídas n/cupo)`); `PUEDE SALIR` (`craft-outcomes`) en
     las aleatorias.
  2. `GASTAS` (`craft-cost`): `$N (tienes $M) · 1 Cristal de Era
     (tienes K)`, en rojo lo que no alcanza; `Nada` si es gratis.
  3. `PIERDES` (`craft-lost`): el arma que se destruye (con sus mods,
     pasiva y forja), `Reemplaza X`, lo que `CraftResult.lost` lista
     (mods / pasiva / forja de Defensa al reforjar); `Nada` en verde.
  4. `No se puede: <motivo>` (`craft-error`) si hay error.
  5. `Tus stats si la equipas` (ATQ / MAG / VEL / CRÍT / DEF / HP antes →
     después) cuando hay resultado determinístico.
  Abajo: `‹ OTRA ACCIÓN` (`bench-back`) y el primario (`craft-confirm`,
  `RE-TIRAR`, `AGREGAR MOD`, `SUBIR RAREZA`, `TRAER MOD`, `TRAER
  PASIVA`, `TRAER HABILIDAD`, `QUITAR MOD`, `REFORJAR`) deshabilitado
  con el `error` del motor. Después de confirmar: `¡Listo! Ahora:` con
  los mods nuevos (`craft-last`) y se queda en el paso 3.

Tests: `test/features/inventory/craft_bench_test.dart`.

### CONSUMIBLES (`itemsHtml`)

`Se usan en batalla desde el menú. Máximo 9 de cada uno.` Una fila por
consumible: nombre, `tienes N/9`, descripción y `$precio` (`item-<key>`,
`BuyItemAction`).

La armería solo se abre en el lobby (frente al mueble); en `prep` sus
pestañas están dentro del panel de preparación.

## Ficha de objeto (tooltip, loot v2)

`itemTooltipMarkup` (`item_text.dart`), usada en el tooltip de cada
casilla y como ficha en los detalles:
- Nombre (`ItemRules.displayName`) en negrita del color de la rareza
  (`RarityColors`, los de `LootFilterRules.rarityColor`: Común blanco,
  Mágico azul, Raro amarillo, Épico violeta, Legendario naranja).
- `<Rareza> · <tipo> · nivel de objeto N` y la base si el nombre es
  generado.
- `Requiere: Nv L FUE 14 DES 8`, cada uno verde si lo cumplís y rojo si
  no (con el reparto pendiente si lo hay).
- `ATQ N · MAG M` con tus atributos si la equiparas (mods y forja
  incluidos).
- `Implícito:` (sky), cada mod con su tier (`+12% ATQ (T3)`; los fijos
  de un legendario `(único)` en naranja) y `Mods n/max`.
- `Pasiva: <nombre nivel>: <efecto>` en violeta (nivel efectivo I–V con
  la forja).
- `Forja +n/tope` con el detalle por estadística.
- Habilidades (base, y las trasladadas con `(trasladada)` en naranja) y
  la ULT en rosa.
- El texto del único (legendario) en dim.

## Inventario (pestaña INVENTARIO del personaje, tecla I)

Reemplaza a la pestaña ARMAS (equipar y comparar están acá). Línea "qué
hace": `Arrastra para mover · clic para ver · EQUIPAR, DAR A, TIRAR,
DESARMAR (materiales) o VENDER (créditos). LIMPIAR INVENTARIO: por
rareza.`

- Arriba de la grilla, pestañas de dueño (`inv-owner-<id>`): `TÚ` y una
  por compañero de sala (solo lectura: `Inventario de <nombre> (solo
  lectura)`, sin botones).
- Casilla de la **equipada** (`inv-equipped`, rótulo `EQUIPADA`) y la
  grilla de 8 × 5 (`InventoryRules.layout`), casillas de 44 px
  (`inv-cell-<i>`): ícono pixel del tipo de arma con el borde del color
  de la rareza, o la pila (poción, éter, materiales) con su cantidad.
  Pasar el mouse muestra la ficha (tooltip). Debajo: `Casillas N/40 ·
  $créditos` y lo que desborda.
- **Mover**: arrastrar una casilla sobre otra (`MoveInventoryAction`,
  intercambia), o elegirla, `MOVER` (`inv-move`) y clic en la casilla
  destino (la línea de ayuda dice `Elige la casilla destino`;
  `CANCELAR` lo anula).
- **Detalle** (derecha): ficha del objeto y, si es un arma propia no
  equipada, `Comparada con <equipada>` (ATQ / MAG / VEL / CRÍT / DEF,
  `StatChange`). Botones: `EQUIPAR` (`inv-equip`, motivos de la tabla),
  `TIRAR` (`inv-drop`) que pide confirmación (`inv-drop-confirm`:
  `¿Tirar X al piso? Lo puede levantar cualquiera.`), y `DAR A <nombre>`
  (`inv-give-<id>`) por compañero, o `DAR A...` deshabilitado con el
  motivo. Las pilas tienen cantidad (`inv-count-dec` / `inv-count-inc`,
  1..N) para dar o tirar.
- **DESARMAR / VENDER** (v0.2.0, loot.md § 21) en las armas:
  `DESARMAR` (`inv-salvage`) y `VENDER $N` (`inv-sell`, con el precio)
  piden confirmación en la misma fila (`inv-craft-question`: `¿Desarmar
  X? Recibes +2 Cristal de Era (puede salir: 35% de +1 Prisma Roto). El
  arma se destruye.` / `¿Vender X? Recibes +$N...`, más lo que se pierde
  por el tope de 99), `CANCELAR` (`inv-craft-cancel`) y el botón rojo
  (`inv-craft-confirm`). Deshabilitados con el motivo del motor
  (`Solo en el lobby o la preparación`, `Está equipada`, `Arma
  inicial`).
- **LIMPIAR INVENTARIO...** (`inv-clean`, debajo de la grilla, solo el
  tuyo): reemplaza el detalle por el limpiador (un propósito): línea
  `Desarma o vende de una vez todas las armas de una rareza. Nunca toca
  la equipada ni tu última arma inicial.`, verbo `DESARMAR (materiales)`
  / `VENDER (créditos)` (`inv-clean-salvage` / `inv-clean-sell`, por
  defecto desarmar), rareza `COMUNES (n) · MÁGICOS (n) · RAROS (n)`
  (`inv-clean-rarity-<rareza>`, con cuántas hay; Épicos y Legendarios
  no se ofrecen en lote), el **resumen** (`inv-clean-summary`: `Vas a
  desarmar 7 Comunes → +9 Esquirla del Eco` / `Vas a vender 7 Comunes →
  +$450`, con lo que puede salir) y la lista `Se destruyen:`
  (`inv-clean-list`, con el precio de cada una al vender). Abajo
  `CANCELAR` (`inv-clean-cancel`) y el primario rojo `DESARMAR 7
  COMUNES` (`inv-clean-confirm`, `CraftAction.batch`) con el motivo
  (`No hay armas de rareza Común`, `canShop`). Tests:
  `test/features/inventory/loot_sinks_ui_test.dart`.

## Filtro de loot (pestaña FILTRO del personaje)

Editor de **texto** para esta versión (decisión del dueño). El **editor
visual** (lista de reglas con ▲▼, agregar, duplicar, borrar; loot.md
§ 6) **queda para la próxima versión**.

- Línea "qué hace": `Reglas en orden: gana la primera que coincide.
  Ocultar no borra el loot: lo deja en el piso.`
- Izquierda: campo multilínea (`filter-text`) con el texto guardado
  (`profile.lootFilter`) o el por defecto.
- Derecha: `VALIDACIÓN` (`filter-status`): `Sin errores · N reglas` en
  verde o los errores del parser (`línea N: ...`) en rojo; `VISTA
  PREVIA`: objetos de muestra (Común de nivel bajo, Mágico, Raro, Épico
  con pasiva, Legendario y una pila de Prisma Roto) dibujados como
  etiquetas del mapa con el estilo del filtro (texto, borde, fondo,
  tamaño; `(oculto)` en dim, la regla que coincidió, sonido e ícono); y
  la gramática corta (también en el `[?]`).
- Botones: `RESTAURAR POR DEFECTO` (`filter-default`, abajo a la
  izquierda: pone el texto por defecto en el editor, sin guardar),
  `DESHACER` (`filter-revert`: vuelve al guardado) y el primario
  `GUARDAR` (`filter-save`, `SetLootFilterAction`; si el texto es el
  por defecto se guarda `null`).

## Resultado de misión: tus drops

`ResultsPanel` muestra `TUS DROPS` (los `LootDropEvent` del jugador
local desde el `MissionStartedEvent`, que el `SessionController` junta en
`SessionView.missionLoot`): una etiqueta por drop con el estilo de **tu
filtro** (`SessionEngine.lootVerdict`; color de rareza si ninguna regla
coincide) y, si el filtro lo oculta, `(oculto por tu filtro)` en dim.

## Personaje (`char`, 1298-1335)

Título `PERSONAJE` o `¡SUBISTE A NIVEL N! Reparte tus puntos` [?].
Línea `nombre · clase LvN · Puntos: P` (P = puntos menos el reparto
pendiente). Pestañas `ATRIBUTOS · INVENTARIO · ÁRBOL · FILTRO` (loot v2:
INVENTARIO reemplaza a ARMAS; la tecla `I` abre el personaje en
INVENTARIO, `WorldPanel.inventory`; ver § "Inventario" y § "Filtro de
loot"). Antes eran tres pestañas (**desvío**: el prototipo apila todo en una
columna con scroll; a 1280×720 con fuente de 8 px no entra).

### Atributos

`Reparte puntos con + y -; nada cambia hasta CONFIRMAR. Cada nivel da 3
puntos.`

- Izquierda: una fila por atributo (`STATN`): nombre, valor, `+n` verde
  pendiente, `-` / `+` (el `+` deshabilitado sin puntos, el `-` sin
  reparto) y `STATD` en `dim`. Debajo `Clase:` (cambio de clase, solo
  lobby; **agregado del puerto**) y el kit de Paladín.
- Derecha, **vista previa** (`previewOf`): `HP`, `MP`, `VEL` (un
  decimal, con la fórmula `(6 + AGI×0.5 + DES×0.1 - peso arma)`), `ATQ`,
  `MAG`, `DEF` (`(-N% daño)`) y `CRÍT` (`%`, `(daño crítico ×1.5)` o `×2`
  con Ojo de Halcón): `valor` o `valor → nuevo` (`StatChange`). Se
  calcula con `ProgressionRules.previewAllocation`. Debajo `Pendiente:
  +2 VIT +1 FUE` o `Sin cambios pendientes`.
- Botones de abajo: `REINICIAR PUNTOS (GRATIS)` a la izquierda (todo modo
  salvo batalla mientras `ProgressionRules.freeRespec`; si no, solo
  lobby/preparación) → `RespecAction`; `DESHACER` (borra el reparto
  pendiente), `CERRAR` y el primario `CONFIRMAR PUNTOS` (verde; con el
  motivo `Reparte algún punto` sin reparto) → `AllocateStatsAction`.
- Con `mustAllocate`: la ayuda "El equipo sigue cuando todos...".

### Armas

`Equipa un arma de tu clase. Comprar, mejorar y fusionar: en la
Armería.`

- Lista (`weapon-row-<id>`): cada arma del inventario de su clase con
  `EQUIPADA` en dorado o `Req` en rojo si no cumple (con el reparto
  pendiente). Debajo, `Pociones xN · Éteres xN · $N`.
- Detalle: la ficha del arma (req coloreado con el reparto pendiente,
  escala, peso, habilidades) y **comparación con la equipada**
  (`ATQ / MAG / VEL / CRÍT / DEF` equipada → esta). Abajo `EQUIPAR`
  (`equip-<id>`) con los motivos de la tabla (`Solo en preparación`,
  `Confirma puntos`, `Requisitos`) o `Es tu arma equipada`.

### Árbol (v2, passive_tree_v2.md § 7)

- `Puntos de árbol disponibles: N` (`treePts`) y `REINICIAR ÁRBOL
  (GRATIS)` (`ResetTreeAction`; se muestra en todo modo salvo batalla
  mientras `freeRespec`). La ayuda (arrastrar para mover, rueda para
  zoom, clic para tomar) va en la línea "qué hace" de la pestaña
  (`PassiveTreeView(showHelp: false)`; sola, la vista la dibuja ella).
- Visor de hasta 420 px de alto (`PassiveTreeView.height`: el panel lo
  ajusta al alto libre, mínimo 240; ancho flexible) con el lienzo de 680 × 680
  (30 px por unidad, centro 340) dentro de un `InteractiveViewer`
  (arrastre, rueda, zoom 0.5×–2.5×). Arranca a escala `min(ancho, alto) /
  544` (entre 0.6 y 1.2) y, si el árbol no entra, centrado hacia la zona
  de tu clase.
- Dibujo: aro tenue del anillo central; enlaces de 2 px (`green` si los
  dos extremos están tomados, dorado de 3 px si son del camino bajo el
  mouse, si no `panel`); nombre de cada camino más allá de su keystone
  (dorado si está resaltado). Nodos: chico círculo r 6, inicio y notable
  r 9, keystone hexágono r 12; notables y keystones con borde dorado.
  Relleno por estado: inicio `gold`, tomado `green` (keystone tomada
  roja), disponible `sky`, bloqueado `#3a4570` (incluye el excluido por
  la keystone opuesta). El camino bajo el mouse y el nodo enfocado llevan
  anillo dorado.
- Pasar el mouse: tooltip junto al nodo (nombre, `NOTABLE` / `KEYSTONE`
  / `INICIO DE CLASE`, `Camino X: tema`, efectos con el texto completo de
  la mecánica y el estado). Clic: lo selecciona y, si se puede tomar,
  manda `TakeNodeAction`.
- Panel lateral (352 px): el nodo elegido (o el del mouse) con nombre,
  tipo, camino, efectos, estado o el botón `TOMAR NODO` deshabilitado con
  el motivo de la tabla, y la leyenda.
- El motor permite tomar nodos en cualquier modo salvo batalla; el
  prototipo solo en lobby/preparación (`ed`). El puerto sigue al motor
  (**desvío**): se pueden tomar al subir de nivel en una misión.

## Fuera de alcance

Tienda ambulante (`merchant`): el mapa nunca genera mercader
(world.md); el panel existiría con consumibles y herrería. Rama de
Paladín (`branch`): código muerto en el prototipo.
