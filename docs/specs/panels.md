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
| Pestaña ULT (repertorio + vista previa animada en loop; docs/specs/ultimates_v2.md § 2.4–2.5) | `lib/features/characters/presentation/ult_repertoire_view.dart`, `ult_preview_panel.dart`, `lib/features/combat/presentation/scene/ult_preview_scene.dart` |
| Pestaña BESTIARIO (personaje y título; docs/specs/bestiary.md § 4) | `lib/features/bestiary/presentation/bestiary_view.dart`, `bestiary_screen.dart` |
| Pestaña HAZAÑAS (personaje y título; docs/specs/achievements.md § 7) y su toast | `lib/features/achievements/presentation/achievements_view.dart`, `achievements_screen.dart`, `achievement_feed.dart` |
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

Cambios v0.12 (design_system.md § 10.3): lista de `DsListRow` de una
línea (rango, zona, `Lv N` / `Bloqueada`), TUTORIAL primero; detalle
con `DsSectionHeader` (OBJETIVO, RECOMPENSAS) y RANGO S en `DsFold`;
PROPONER principal con el motivo en el tooltip y en una línea roja al
lado; la línea "Propón…" pasó al "?". Preparación: `¡LISTO!`
principal y GRUPO con una línea por jugador.


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

**Lista + detalle (v0.5)**: el mostrador ya no apila tarjetas (con 10
zonas había que bajar mucho). Izquierda (`PanelSplit`, 340 px): una fila
de una línea por zona / misión (`mission-<id>`, `MenuRow`): rango en
`amber`, `N · <zona>` (o el nombre de la misión) y a la derecha `Lv N`
(verde, rojo si estás por debajo) o `Bloqueada` (fila en `dim`); las
"Próximamente" siguen como línea gris (`zone-soon-<N>`). Por defecto la
última zona abierta. Derecha: la `MissionCard` de la elegida
(`mission-card-<id>`, sin botón) y abajo `Enter Elegir · Esc Cerrar` y
el único `PROPONER` (`propose-<id>` de la elegida, con el motivo
`Bloqueada` / `Ya hay una votación`). Línea: `Propón una zona: cuando
todos votan SÍ, a prepararse.` (lo de las puertas del mapa pasó al
`[?]`).

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

**Zonas 6–10 (v0.3.0)**: las tarjetas `z6`..`z10` son iguales a las de
la v0.2 (línea de zona en el color de la zona, objetivo por pisos,
bloqueo con motivo). El desbloqueo llega hasta la zona 10
(`¡Zona 10 desbloqueada! Corazón del Tiempo`).

**Final (v0.3.0)**: si la misión ganada es la de la zona 10 (el jefe es
el Devorador de Eras; `MissionResult.zone == 10 && success` — el motor
no tiene una señal aparte), el resultado muestra arriba el cartel
`¡Venciste al Devorador de Eras!` (`results-final`, 14 px dorado con
sombra dura y borde de 3 px dorado sobre `#1a0f2a`) y debajo `El tiempo
vuelve a fluir. Gracias por jugar.` en `sky`.

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

- **COMPRAR** (`Armas base para cualquier clase.`; v0.20.21: buscador
  y equipada fija, ui_minimal.md § 3): selector `Familia ‹ GUERRERO ›`
  (`ChoiceCycler`, `buy-family-prev` / `-next` / `-value`: TODAS / una
  por clase; por defecto la tuya), bases con precio > 0 ordenadas por
  nivel (`shop-row-<id>`, `MenuRow` de una línea): nombre y tipo (`dim`)
  y a la derecha `Nv L` y `TIENES`, o `Req` rojo (si no cumple) y el
  precio. Detalle: primero `Si la equipas:` ATQ / MAG / VEL / CRÍT /
  DEF antes → después, después la ficha del arma Común (§ "Ficha de
  objeto"); abajo `CostLine` y `COMPRAR $precio`.
- **FORJA** (`Sube una estadística del arma; cada 2 niveles sube su
  pasiva.`): lista de tus armas (`forge-row-<uid>`, una línea) con el
  nombre en el color de la rareza y a la derecha `forja n/tope` (o
  `EQUIPADA`). Detalle: nombre, `Forja n/tope` con
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
  catálogo (`shop-row-<id>`): nombre, tipo, la categoría de peso
  (`Ligera` / `Media` / `Pesada`, v0.8.4) y a la derecha `TIENES`
  (verde) o `$precio`.
- Detalle: nombre, tipo y categoría de peso, `Req:` coloreado (`reqHtml`), `Escala:`
  (`wPowTxt`), la línea de peso (§ "Peso del arma"), `Habilidades:` con la descripción de
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
  mejorar o cambiar.`): tus armas en la grilla de ítems (`DsItemGrid`,
  v0.14.0: la misma casilla, ficha del mouse y buscador que el
  INVENTARIO; `bench-weapon-<uid>`, ★ si cumple tu build; por defecto la
  equipada, con borde dorado) y a la derecha su ficha. Tocar la ya
  elegida avanza al paso 2.
  Primario `ELEGIR ESTA ARMA ›` (`bench-next`).
- Buscador (v0.11.x, pedido del dueño): siempre hay un `DsSearchField`
  arriba de cada grilla donde se elige un arma: arma destino en el paso 1
  (`bench-weapon-search`), arma de origen que se destruye en el paso 3
  (`craft-source-search`) y base nueva al reforjar (`bench-base-search`,
  por nombre y tipo). Las armas se filtran con `inventoryMatches` (mismo
  criterio que el inventario: nombre, tipo, rareza, mods, pasiva y
  habilidades; todas las palabras, sin acentos). Lo que no coincide se
  oculta (grillas de elección, sin posiciones fijas), salvo el arma ya
  elegida, que queda a la vista; si nada coincide, `Ninguna arma coincide
  con la búsqueda.`. Esc con texto limpia el buscador; sin texto vuelve
  de paso como siempre. El texto del paso 1 se mantiene al volver a él;
  los del paso 3 se borran al elegir otra acción. Las habilidades / mods a
  traer salen del arma de origen elegida (lista corta debajo de la
  grilla, sin buscador propio): el buscador de origen ya encuentra armas
  por habilidad o mod. Arma de origen (`craft-source-<uid>`) y base
  nueva (`bench-base-<id>`, casilla de una Común de esa base) también van
  en grilla (v0.14.0); la ficha del origen lleva al pie qué te llevás y
  qué se destruye (`craft-source-tip-<uid>`); la de la base, nombre,
  tipo, peso, nivel y si cumplís los requisitos.
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

### FUSIÓN (v0.5: sin bajar para elegir)

Pedido del dueño: "mucho texto y tenés que bajar para ver qué habilidad
elegir". Mismo asistente de 3 pasos y mismas reglas / motivos
(`ShopGuards`); cambia la presentación (ui_style.md § "Menús: lista +
detalle"). Donde difiere de la sección v0.2.0, manda esta:

- **Arriba**: la línea de la pestaña (`Destino, acción, vista previa,
  confirmar.`; v0.20.21, ui_minimal.md § 4) y en una fila las migas
  (`StepCrumbs`, `bench-crumb-<0|1|2>`) con los materiales a la derecha
  (`Esquirla x2 · Cristal x1 · Prisma x0 · Ancla x0`, `craft-materials`,
  tooltip igual). Sin líneas `Paso N de 3`. El arma y la acción elegidas
  (`bench-summary`) van arriba del detalle de los pasos 2 y 3.
- **Paso 1**: filas de una línea (`bench-weapon-<uid>`): nombre en color
  de rareza y a la derecha `EQUIPADA` o `<rareza> · Nv N`. Clic en otra
  fila la elige; clic en la ya elegida (o `Enter` con la mesa enfocada, o
  `ELEGIR ›` `bench-next`) pasa al paso 2.
- **Tarjetas (v0.5, pedido del dueño: "separaciones bien bien de cada
  acción")**. Piezas en `lib/app/widgets/`: `SectionPanel` (sección
  enmarcada con franja de ícono + título + explicación), `ActionCard`
  (tarjeta con ícono pixel, título, 1-2 líneas, pie y hueco `badge` para
  el `BuildFitBadge` del Build Planner; mouse/foco = se levanta 2 px con
  borde `sky` y muestra el efecto; elegida = borde `gold`; bloqueada =
  atenuada con candado), `CostChip` (moneda y materiales con su ícono, en
  verde si alcanza y rojo si no; `blocked` = candado + motivo completo),
  `PixelIcon` (íconos 8×8 pintados: dado, +, gema, flecha, estrella,
  tacho, yunque, candado, moneda, espada, esquirla, prisma, ancla, ✓),
  `CardGrid` y `ConfirmButton`.
- **Paso 1**: grilla de tarjetas de arma (`bench-weapon-<uid>`): franja
  del color de la rareza con su letra, espada pixel del mismo color,
  nombre, `<rareza> · Nv N · Mods n/max`, `EQUIPADA`. A la derecha la
  ficha y `ELEGIR ›`.
- **Paso 2** (todo el ancho, panel de 1200 px): una `SectionPanel` por
  grupo (`bench-group-<grupo>`: MEJORAR — cambia los mods de esta arma
  (con materiales) · TRASLADAR — trae algo de otra arma (esa arma se
  destruye) · QUITAR — saca un mod para hacer lugar · CAMBIAR — cambia la
  base del arma) y una `ActionCard` por acción (`bench-op-<op>`): ícono
  (dado, +, gema, flecha, esquirla, estrella, tacho, yunque), nombre,
  `CraftOpText.short`, con el mouse el efecto (`Mods 4/6 → 5/6`) y el
  pie (`bench-op-why-<op>`): `CostChip` con el costo de la elección por
  defecto, `Se puede · eliges en el paso 3`, o candado + motivo
  completo. Columnas: 3 a 1280 en Normal (MEJORAR │ TRASLADAR │ QUITAR +
  CAMBIAR, entran las 8 sin bajar), 2 en Grande, 1 si no entran (con
  scroll). Flechas mueven el foco entre tarjetas, `Enter` elige, `Esc`
  vuelve.
- **Paso 3**: a la izquierda la línea "qué hace" (`dim`) y solo las
  elecciones de esa acción, en filas de una línea:
  - traer: `¿De qué arma? (se destruye)` (`craft-source-<uid>`, a la
    derecha `<rareza> · Nv N`) y, **justo debajo de la elegida** y con
    sangría, sus mods / habilidades (`craft-pick-<i>`); la pasiva no
    tiene sub-elección;
  - quitar: `¿Qué mod quitar?` (`craft-pick-<i>`);
  - reforjar: `¿Qué base nueva?`, `Familia ‹ TODAS ›` (`ChoiceCycler`,
    `bench-family-prev` / `-next` / `-value`) y las bases
    (`bench-base-<id>`: nombre y tipo, a la derecha `Nv N OK/Req`);
  - mejorar: `AHORA` con la ficha.
  El detalle: `Gastas` (`craft-cost`) y `Pierdes` (`craft-lost`) arriba,
  `No se puede` (`craft-error`) y una tabla **ANTES │ DESPUÉS** de dos
  columnas: Arma (`craft-name`), Base (`craft-base`, al reforjar),
  Rareza, Pasiva (`craft-passive`), Habilidades (`craft-skills`, la
  nueva en verde con ▲), Mods (`craft-mods-title` con `[?]`
  `craft-tier-help`; lista `craft-mods` con `(nuevo)` / `(se quita)`;
  `=` si no cambia) y ATQ / MAG / VEL / CRÍT / DEF / HP con ▲ / ▼;
  `PUEDE SALIR` (`craft-outcomes`) en las al azar. Abajo `‹ OTRA ACCIÓN`
  y el `ConfirmButton` grande (`craft-confirm`: ✓ + verbo + chip de
  costo; deshabilitado con candado y `No se puede: <motivo>` arriba).
  `Enter Confirmar · Esc Volver` va debajo de la lista.
- **Teclado**: con el foco en la mesa (se toma al tocar una fila o
  cambiar de paso) `Esc` vuelve un paso (en el paso 1 cierra el panel) y
  `Enter` avanza / confirma si se puede.

### FUSIÓN (v0.8.3: tooltips)

Pedido del dueño: "que haya tooltip en cada opción de la fusión porque no
se entiende". Los textos viven en `lib/features/inventory/domain/
craft_help.dart` (`CraftHelp`), armados con los datos de `CraftRules` /
`Rarity` / `LootRules` (ningún número copiado); las líneas en pantalla no
cambian.

- **Acciones del paso 2** (`RetroHoverCard` al costado, con mouse o foco
  de teclado; contenido `bench-op-tip-<op>`): título y una línea por
  parte (`CraftOpHelp`): `Qué hace:` · `En tu arma:` (con los números del
  arma elegida: `Mods 2/4 → 3/4`, `Raro → Épico: lugar de mods 4 → 6
  (+2), +3 mods al azar..., tope de forja 6 → 8, y gana una pasiva`) ·
  `Cuesta:` (exacto de la vista previa por defecto, o el rango por tier
  `₵100 (T5) a ₵800 (T1)`; con `(tienes N)`) · `Pierdes:` (traslados: el
  arma de origen con mods, pasiva, forja y habilidades) · `Bloqueada:`
  (solo si lo está: el mismo motivo que el pie / `ShopGuards`, más una
  pista para `Falta <material>`, `Faltan $N`, `Está equipada`, `Arma
  inicial`) · `Ejemplo:`.
- **Secciones** (`SectionPanel.tooltip`): una línea por grupo
  (`CraftHelp.groups`). **Migas** (`StepCrumbs.tips`,
  `bench-crumb-tip-<i>`): `CraftHelp.steps`.
- **Materiales**: un tooltip por contador (`craft-mat-<material>`, dentro
  de `craft-materials`): `Para qué:` (acciones y cantidades) · `Dónde:`
  (chance de loot de `LootRules.materialChance`, qué rarezas lo dan al
  desarmar según `CraftRules.salvageYield`; Ancla solo en Ecos, Esencia de
  los Jefes del Abismo) · `Tienes: N (máximo 99)`.
- **Paso 3**: cada fila de `¿De qué arma? (se destruye)`
  (`craft-source-tip-<uid>`): `Te llevas:` y `Se destruye` con rareza,
  nivel, mods, pasiva, forja y habilidades. Las tarjetas de `¿Qué
  habilidad reemplazas?` (`craft-replace-tip-<id>`) suman arriba de la
  ficha de la habilidad si es base (no se reemplaza), trasladada o la que
  se reemplaza.

Tests: `test/features/inventory/craft_help_test.dart`.

### FUSIÓN (v0.15: CONDENSAR)

materials_economy.md § 4.3. En el paso 1 (ARMA), al pie de la ficha:
`CONDENSAR` (`bench-condense`, solo en el Mundo: en una armería de la
Travesía no aparece) abre el panel `CondensePanel`
(`condense_panel.dart`, en lugar del paso 1; `‹ VOLVER` =
`condense-back`):

- Una tarjeta `DsCard` por receta (`condense-card-<material>`):
  `20 Esquirla + ₵100 → 1 Cristal de Era` y `8 Cristal + ₵500 → 1 Prisma
  Roto` (v0.20.8; los números salen del grupo Condensar del balance); debajo lo que tienes y cuántos alcanzan (`condense-have-<m>`:
  `Tienes 25 Esquirla · 0 Cristal · ₵1000 — alcanza para 2`,
  `CraftRules.condenseMax`: materiales, créditos y lugar hasta 99). Aviso
  dorado si la pila de origen está llena ("condensa para no perder lo que
  caiga") y rojo si la de destino está en 99.
- Botones `×1` / `×5` / `MÁX (N)` (`condense-<m>-1|5|all`, v0.20.8; antes
  `x1` / `x5` / `TODO (N)`), grises si no alcanzan.
- Confirmación (`condense-confirm`): `Gastas 40 Esquirla del Eco y ₵200.
  Obtienes 2 Cristal de Era. No se puede deshacer.` (`condense-summary`),
  el motivo si el host lo rechazaría (`condense-error`, `ShopGuards.craft`)
  y `CONDENSAR` (`condense-go`) / `CANCELAR` (`condense-cancel`).
- Manda `CraftAction(CraftOp.condense, '<material>', index: N)`; el host
  valida fondos y tope (`CraftRules.condense`).

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
- Peso, **siempre** (v0.8.4, § "Peso del arma"): `Ligera · sin
  penalización de velocidad`, `Media: −0.5 vel. · algo más lenta a cambio
  de poder` o `Pesada: −1.3 vel. · suele dar más ATQ`; con tus stats, además
  `Por el peso tu turno llega cada 11.8 de tiempo en vez de 10 (≈15% más
  lento)`. Reemplaza al viejo `Peso N (−N vel.)` del final.
- `Implícito:` (sky), cada mod con su tier (`+12% ATQ (T3)`; los fijos
  de un legendario `(único)` en naranja) y `Mods n/max`.
- `Pasiva: <nombre nivel>: <efecto>` en violeta (nivel efectivo I–V con
  la forja).
- `Forja +n/tope` con el detalle por estadística.
- Habilidades (base, y las trasladadas con `(trasladada)` en naranja) y
  la ULT en rosa.
- El texto del único (legendario) en dim.

## Inventario (pestaña INVENTARIO del personaje, tecla I)

Cambios v0.12.0 (responsivo, pedido del dueño): en 1750×1040 con texto
Grande la columna de al lado se salía del panel (la cuarta pila de
MATERIALES quedaba cortada). Reemplaza a `inventoryScale`,
`inventoryScaleWide` e `inventorySideWidth`:
- Un `LayoutBuilder` elige la disposición con `inventoryLayout(ancho,
  alto, stripWidth, sideMin)` (`sideMin` = 240 px por el factor de
  texto), por puntos de quiebre del ancho del panel:
  - ancha (`InventoryLayoutMode.wide`): si entran la franja de CAMBIOS,
    la grilla a k = 1 y la columna de al lado: franja | grilla |
    columna (`inv-side`: EQUIPADA, consumibles, materiales,
    casillas / créditos). La columna pide 4 pilas por fila al tamaño
    de la casilla; si no entran, la grilla baja de escala (hasta 1).
  - media: si entran la franja y la grilla: la columna va debajo de la
    grilla (EQUIPADA arriba de ella).
  - angosta: todo apilado (la franja arriba, achicada con
    `FittedBox(scaleDown)` si hace falta).
- La casilla sale del espacio que queda (44 × k; entera desde k = 2, en
  cuartos entre 1 y 2, y por debajo de 1 la que entre a lo ancho);
  siempre `InventoryRules.columns` columnas. El bloque nunca es más
  ancho que el panel: sin scroll horizontal; a lo alto, scroll.
- Pilas (`InventoryStacksBar`): cada grupo mide su ancho con un
  `LayoutBuilder` y usa tantas columnas como entren; las demás bajan
  de línea (nunca se cortan). El menú de LIMPIAR y la confirmación
  toman como mucho el ancho de la grilla.
- Test: `test/features/inventory/inventory_responsive_test.dart`
  (1024×600 a 2560×1440, texto Normal / Grande / Enorme, con todas las
  pilas). Capturas: `docs/release_shots/v0.12.0/inventario_responsivo_*`.

Cambios v0.11 (sistema de diseño, design_system.md § 10):
- Barra de herramientas arriba, en una fila (`inv-toolbar`): de quién es
  el inventario (`TÚ` / compañeros, `inv-owner-<id>`), búsqueda
  (`DsSearchField`, `inv-search`; × `inv-search-clear` para borrarla),
  `ORDENAR ▼` (`inv-sort`) y `LIMPIAR` (`inv-clean`). Con texto ENORME
  la barra baja de línea y ocupa como mucho el 40 % del alto (scroll).
  La escala de la grilla ya no descuenta esa barra (desde v0.12.0,
  `inventoryLayout`).
- Botones `DsButton` (compactos); deshabilitados con el motivo en el
  tooltip (antes al lado). Confirmaciones (TIRAR, VENDER, DESARMAR) con
  franja roja a la izquierda en vez de caja con candado.
- Menú de acciones (clic derecho / Enter) y menú de LIMPIAR: filas
  `DsListRow` de una línea (sin borde; fondo con hover / foco; la
  desactivada atenuada con el motivo corto al lado en Detalle y el
  completo en el tooltip).
- Franja de CAMBIOS: `ACTUAL` / `CAMBIOS` en Subtítulo y una
  `DsStatLine` por stat (`ATQ  15 → 50  ▲35`; sin arma mirada, solo el
  valor actual en Detalle). `EQUIPADA`, `CONSUMIBLES`, `MATERIALES` en
  Subtítulo; el resumen (`inv-summary`) en Detalle con los créditos en
  dorado. Sin negritas.
- LIMPIAR INVENTARIO: `DsSectionHeader`, `DESARMAR` / `VENDER` (qué se
  recibe en el tooltip); el plegable "Cómo funciona" pasó al "?".

Cambios v0.20.21 (ui_minimal.md § 5): `LIMPIAR ▼` es un `DsMenuButton`
(`inv-clean`, menú `inv-clean-menu`) y el único lugar de las acciones en
lote: `Elegir a mano` y `Desarmar / Vender Comunes / Mágicos / Raros (N)`
(gris sin armas). Elegir abre la confirmación al costado, sin selector
de modo ni de rareza repetido. Ya no hay caja de LIMPIAR debajo de la
grilla (`inv.clean_menu`).

Cambios v0.9.13 (pedido del dueño):
- Ficha del mouse de un arma no equipada (`HoverCompareCard`): una sola
  columna angosta (`cardWidth` 180 × factor de texto, ~32 letras), puede
  ser más alta. Ya no lleva al lado `EQUIPADA / Si la equipas:`.
- Mantener Shift suma al lado la columna de la equipada (v0.10.1: su
  ficha completa, ver "Cambios v0.10.1"). Tooltip atravesable, Alt y clic para fijar: ver ui_style.md
  § "Tooltips cortos".
- Franja de cambios (`ChangeStrip`, `inv-strip`) a la izquierda de la
  grilla, en el espacio libre (si no entra, la grilla se corre lo justo):
  siempre visible; con el mouse o el cursor de teclado sobre un arma no
  equipada muestra una línea corta por stat (`ATQ 19→28 ▲9`, verde ▲ /
  rojo ▼; sin cambio en gris) en orden ATQ, MAG, CRÍT, VEL, Vida, Maná,
  DEF, Peso (`stripStats`); sin arma mirada, `ACTUAL` con los valores de
  hoy en gris.
- COMPARAR del clic derecho (A vs B en grande) no cambia.

Cambios v0.10.1 (pedido del dueño):
- La caja del tooltip mide su contenido con un máximo de una columna
  (`HoverCompareCard.cardWidth` escalado), con o sin la línea `★ Tu
  build` (antes iba en una `Column` con `stretch` y tomaba todo el ancho)
  y con cualquier tamaño de texto. La línea de ayuda (`Alt: detalle ·
  …`) se parte al ancho del contenido: nunca ensancha la caja.
- Zona de los tooltips del inventario (`RetroTipArea`): solo la columna
  de la grilla, desde su borde de arriba hasta el pie del panel (si eso
  queda muy bajo, todo el alto). Nunca tapan la franja de CAMBIOS ni la
  EQUIPADA / pilas. Si no entran al costado de la casilla, abajo o
  arriba, dentro de esa zona; si el contenido no entra en el alto,
  scrollea.
- Shift: al lado va la ficha completa de la EQUIPADA (la misma de una
  columna: nombre, rareza, requisitos, resumen y plegables), con el
  rótulo `EQUIPADA` y el mismo ancho que la del arma mirada. Ya no lleva
  `Si la equipas:`: los cambios están en la franja de CAMBIOS.
- Franja de CAMBIOS: una línea por stat (`ATQ 15→50 ▲35`), nunca
  partida; el ancho se mide con el texto actual (`ChangeStrip.widthOf`)
  y la grilla se corre lo justo si no entra. Va en fila con la grilla
  (no flotando), así suma su alto y scrollea con el panel en vez de
  cortarse abajo.

Reemplaza a la pestaña ARMAS (equipar y comparar están acá). Línea "qué
hace": `Arrastra para mover · clic para ver · clic derecho (o Enter):
acciones. ORDENAR · LIMPIAR INVENTARIO: por rareza o elegidas a mano.`
(v0.9.9).

**Sin panel derecho (v0.9.10).** ESTADÍSTICAS (`inv-stats`, v0.9.9)
se sacó: la ficha del mouse de un arma ya compara con la equipada
(`Si la equipas:` con Vida, Maná, VEL, ATQ, MAG, DEF, Crítico y peso,
`antes → después` en verde ▲ si mejora y rojo ▼ si empeora; clave
`cmp-stat-<stat>`). El inventario ocupa todo el ancho: la columna
(`inv-main`) va centrada y la grilla, la EQUIPADA, las pilas, el
buscador, el menú de LIMPIAR y la confirmación escalan juntos (desde
v0.12.0 con `inventoryLayout`, ver "Cambios v0.12.0"): la mayor escala k (casillas de 44 × k
px, íconos proporcionales) con la que la grilla entra a lo ancho y sus
5 filas, la EQUIPADA y las pilas (más ~200 px de textos y botones) a lo
alto, así LIMPIAR queda a la vista sin scroll; entera desde k = 2
(nitidez del pixel art) y en cuartos entre 1 y 2; si ni k = 1 entra a
lo ancho, la que entre (sin scroll horizontal; a lo alto, la columna
tiene scroll). Si hay lugar a lo ancho (`inventoryScaleWide`), la
EQUIPADA, CONSUMIBLES / MATERIALES, el resumen y LIMPIAR van en una
columna al lado de la grilla (`inv-side`) y a lo alto solo cuentan
ORDENAR, el buscador y las 5 filas: se usa el modo que dé la grilla más
grande (en 1280×720, k = 1,25 con la columna al lado). Con LIMPIAR INVENTARIO abierto se vuelve a
k = 1 y el detalle de LIMPIAR va a la derecha (`PanelSplit`). En el
inventario de un compañero, abajo a la derecha: `Solo lectura` y
`COMPARAR`.

- Arriba de la grilla, pestañas de dueño (`inv-owner-<id>`): `TÚ` y una
  por compañero de sala (solo lectura: `Inventario de <nombre> (solo
  lectura)`, sin botones).
- Casilla de la **equipada** (`inv-equipped`, rótulo `EQUIPADA`) y la
  grilla de 8 × 5 (`InventoryRules.layout`), casillas de 44 px × la
  escala (`inv-cell-<i>`): ícono pixel del tipo de arma con el borde del color
  de la rareza, o la pila (poción, éter, materiales) con su cantidad.
  Pasar el mouse muestra la ficha (tooltip; en las armas, comparada con
  la equipada: § "Comparar armas"). Debajo: `Casillas N/40 ·
  $créditos` y lo que desborda (N = armas y Ecos).
- **Secciones de pilas** (v0.5.1, loot.md § 17.1; `consumables_bar.dart`,
  `inv-stacks`): debajo de la grilla, dos filas de casillas fijas de
  44 px con rótulo: `CONSUMIBLES` (Poción de vida, Poción de maná) y
  `MATERIALES` (Esquirla, Cristal, Prisma, Ancla), cada una con su
  cantidad (en 0: atenuada, no se elige). Clave `inv-stack-<token>`
  (`inv-stack-pot`, `inv-stack-mat:cristal`). Clic, o el cursor con las
  flechas, la elige; clic derecho (o `Enter` sobre la ya elegida) abre
  el menú de acciones (DAR A, TIRAR). Con una pila de más de 1 elegida,
  debajo de la grilla aparece la cantidad (`inv-count-dec` /
  `inv-count-inc`, 1..N) para dar o tirar. Las flechas pasan de la grilla a las secciones (abajo) y entre
  las dos filas. No se mueven ni se ordenan (lugar fijo). En el alijo
  (`stash_screen.dart`) la misma fila de MATERIALES está debajo de la
  grilla del personaje para guardarlos.
- **Buscador** (v0.9.7, `inv-search`, arriba de la grilla): filtra por
  texto (nombre, base, tipo, rareza, mods, pasiva, habilidades; sin
  tildes ni mayúsculas, todas las palabras). Lo que no coincide queda
  atenuado (25 %) en su casilla: la grilla no se reordena.
  `inventoryMatches` (`domain/inventory_menu.dart`).
- **NUEVO** (v0.9.7, loot.md § 17.4): las armas y los Ecos recién
  levantados llevan una franja `NUEVO` (`gold`) abajo de la casilla
  (`inv-new-<i>`); pasar el mouse la saca (`SeenItemsAction`).
- **ORDENAR ▼** (v0.5.1, loot.md § 17.2; `inventory_sort_button.dart`,
  `inv-sort`, en la fila de arriba de la grilla, solo el tuyo): abre un
  menú con `Rareza`, `Nivel de objeto`, `Tipo de arma`, `Nombre` y
  `Últimos levantados` (`inv-sort-<clave>`); elegir una manda
  `SortInventoryAction` y cierra el menú (`Esc` o clic afuera lo
  cierran sin ordenar; flechas y `Enter` recorren las opciones). La
  equipada sigue en su casilla EQUIPADA (siempre primero).
- **Mover**: arrastrar una casilla sobre otra (`MoveInventoryAction`,
  intercambia), o elegirla, `MOVER` (`inv-move`) y clic en la casilla
  destino (la línea de ayuda dice `Elige la casilla destino`;
  `CANCELAR` lo anula).
- **Menú de acciones (v0.9.9, `inventory_action_menu.dart`)**: el único
  lugar de las acciones. Clic derecho en una casilla propia (grilla,
  EQUIPADA o pila) la elige y abre el menú junto al cursor
  (`inv-ctx-menu`); con el teclado, `Enter` sobre la casilla ya elegida
  lo abre junto a ella y el cursor arranca en la primera acción
  disponible (`Enter` otra vez sobre Equipar la equipa). `Esc`, clic
  afuera o elegir una acción lo cierran. Al abrirse cierra el tooltip y,
  mientras está abierto, no se abre ninguno (nunca los dos a la vez;
  `RetroHoverCard.suppressed`). Caja compacta: título (nombre del
  objeto) y **una línea por acción** (`inv-<acción>`: `inv-equip`,
  `inv-compare`, `inv-move`, `inv-give` / `inv-give-<id>`, `inv-drop`,
  `inv-salvage`, `inv-sell`), ancho ajustado al contenido (máx. 360 px),
  sin salirse de la pantalla: si no entra abajo se abre hacia arriba y
  si no entra a la derecha, hacia la izquierda. El de la EQUIPADA no tapa el
  buscador: se abre debajo de él (si no entra, a su derecha). Los
  tooltips del inventario nunca se salen de la pantalla (desde v0.10.1,
  dentro de la zona de la grilla: ver "Cambios v0.10.1"). Orden: Equipar, Comparar,
  Mover (`· o arrastrá`), Dar a <nombre> (una por compañero; si dos se
  llaman igual, `Dar a Héroe (Maga, Nv 6)`; sin compañeros `Dar a...`),
  Tirar (`· queda en el piso`), Desarmar (`· +2 Cristal de Era` o
  `· sin materiales`; v0.9.11), Vender ₵N. Filas con aspecto de botón:
  ui_style.md § "Filas de menú clickeables". Las que no se pueden, en gris con el
  **motivo corto en la misma línea** y atenuado (`inventoryReasonShort`):
  `Tirar · equipada`, `Dar a... · sin compañeros`, `Equipar · ya
  equipada`, `Vender ₵N · arma inicial`, `Equipar · Requisitos: ESP 14`;
  el motivo completo (`inventoryReasonLine`: `No podés desarmar el arma
  equipada`, `No podés dársela a otro jugador: está equipada`...) va en
  el tooltip de la fila. Las pilas no tienen Mover (lugar fijo). En el
  inventario de un compañero no hay menú.
- **Confirmaciones** (debajo de la grilla, `inv-confirm`): TIRAR (si
  CONFIRMAR AL TIRAR está en SÍ) muestra `¿Tirar X al piso? Lo puede
  levantar cualquiera.` (`inv-drop-question`) con `CANCELAR`
  (`inv-drop-cancel`) y `TIRAR` rojo (`inv-drop-confirm`).
- **DESARMAR / VENDER** (v0.2.0, loot.md § 21) en las armas:
  `DESARMAR` (`inv-salvage`) y `VENDER $N` (`inv-sell`, con el precio)
  piden confirmación debajo de la grilla (`inv-craft-question`: `¿Desarmar
  X? Recibes +1 Cristal de Era (puede salir: 15% de +1 Prisma Roto). El
  arma se destruye.` / `¿Vender X? Recibes +$N...`, más lo que se pierde
  por el tope de 99), `CANCELAR` (`inv-craft-cancel`) y el botón rojo
  (`inv-craft-confirm`). Deshabilitados con el motivo del motor
  (`Solo en el lobby o la preparación`, `Está equipada`, `Arma
  inicial`).
- **LIMPIAR INVENTARIO...** (`inv-clean`, debajo de la grilla, solo el
  tuyo): abre debajo del botón un **menú** (v0.9.7, `inv-clean-menu`):
  `Elegir a mano` (`inv-clean-menu-pick`), `Desarmar todos los Comunes
  / Mágicos / Raros (n)` y `Vender todos los ... (n)`
  (`inv-clean-menu-<salvage|sell>-<rareza>`; en gris `No tenés comunes
  para vender` si no hay). Elegir una opción deja el limpiador del
  detalle listo para confirmar. El limpiador: la ayuda plegada en
  `▸ Cómo funciona` (`Desarma o vende de una vez todas las armas de una
  rareza. Nunca toca la equipada ni tu última arma inicial.`), verbo `DESARMAR (materiales)`
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
- **ELEGIR A MANO** (v0.5.1, loot.md § 21.5; `clean_selection.dart`):
  en el limpiador, el modo `POR RAREZA` / `ELEGIR A MANO`
  (`inv-clean-mode-rarity` / `inv-clean-mode-pick`). En ELEGIR A MANO la
  grilla pasa a modo selección: clic o `Espacio` / `Enter` sobre un arma
  la marca o desmarca (casilla con el ícono pixel de check verde y borde verde,
  `clean-check`); las protegidas (equipada, última inicial; también la
  segunda inicial si ya elegiste la otra) muestran un candado
  (`clean-lock`) y no se marcan. Los Ecos no se marcan. Atajos
  `+ COMUNES (n)` / `+ MÁGICOS (n)` / `+ RAROS (n)` / `+ ÉPICOS (n)`
  (`inv-clean-add-<rareza>`: "seleccionar todo de esta rareza", suma a
  lo elegido) y `NINGUNA` (`inv-clean-none`). El detalle muestra
  `Elegidas: N` (`inv-clean-count`), el resumen con lo que recibes
  (`inv-clean-summary`, misma vista previa que el motor) y la lista
  `Se destruyen:`; abajo `CANCELAR` y el rojo `DESARMAR N SELECCIONADAS`
  / `VENDER N SELECCIONADAS` (`inv-clean-confirm`,
  `CraftAction.selected`) con el motivo (`Elige armas`). Al confirmar
  se vacía la elección. Tests:
  `test/features/inventory/inventory_v051_ui_test.dart`.

La **equipada no ocupa casilla**: va en su ranura EQUIPADA y `Casillas
N/40` no la cuenta (`InventoryRules.tokens` la saca desde v0.5.1; loot
§ 17). Tests de todo lo de v0.9.7:
`test/features/inventory/inventory_ux_test.dart`.

### Comparar armas (v0.3.0)

Pedido del dueño: "agregar lo de comparar armas en el inventario". Dos
formas, las dos con los mismos números del motor (nada de reglas en la
UI):

- **Comparación** (`compareWeapons`, `domain/weapon_compare.dart`):
  dada el arma de partida A (la equipada, o cualquiera) y la candidata
  B, para el **jugador local** y su reparto pendiente:
  - stats finales si usara A y si usara B (`ShopPreview.withItem`: el
    `StatsCalculator` sobre una build hipotética, como
    `ProgressionRules.previewEquip`; con A = la equipada que realmente
    usa, `ShopPreview.current` = `derivedStats`). Se muestran en este
    orden: `ATQ`, `MAG`, `Crítico` (%), `VEL` (1 decimal), `Vida`,
    `Maná`, `DEF`, como `ATQ 21 → 30 +9` con el después y la diferencia
    en verde si mejora y en rojo si empeora (sin cambio: `ATQ 21` en
    dim, sin flecha);
  - qué cambia, solo las líneas que no están vacías: `+ Habilidad:` /
    `- Habilidad:` (`ItemRules.skillsOf`, el kit de clase no cambia),
    `+ Mod:` / `- Mod:` con su tier (`ItemRules.affixText`, multiconjunto
    por texto: el mismo mod con otro valor cuenta como perdido y ganado),
    `+ Pasiva:` / `- Pasiva:` (`passiveText`, nivel efectivo con la
    forja), `ULT: X → Y` si cambia el tipo de ULT;
  - requisitos de B (`Requiere:` en verde/rojo) y, si no los cumple,
    `No cumples los requisitos: hoy no podrías equiparla.` en rojo.
  - Mismo objeto en A y B → `Es la misma arma.` sin diferencias.
- **Ficha comparada al pasar el mouse** (v0.9.11: corta; ver
  ui_style.md § "Tooltips cortos" — ficha del arma a la izquierda y, a
  la derecha, `EQUIPADA <nombre>` + solo las stats que cambian + `▸
  Cambios`; lo que sigue describe la versión anterior) (`inv-cmp-tip`, tooltip de
  widgets `RetroHoverCard` en `lib/app/theme/`): sobre un arma de la
  grilla (tuya o de un compañero) que no sea la que usás, la ficha del
  objeto a la izquierda y la de la equipada a la derecha con el rótulo
  `EQUIPADA` (fichas de 296 px), y debajo `Si la equipas:` con la
  comparación (A = equipada, B = la del mouse). Aparece al lado de la
  casilla (a la derecha; si no entra, a la izquierda) y nunca se sale de
  la pantalla (se corre hacia adentro, margen 8 px). Sobre la equipada o
  una pila: la ficha simple de siempre. La armería (COMPRAR / FORJA /
  FUSIÓN) sigue con su `Si la equipas:` del detalle.
- **COMPARAR** (`inv-compare`, en el detalle de cualquier arma, también
  en la pestaña de un compañero): esa arma queda como **A** y la línea
  de ayuda dice `Elige el arma B para comparar con <A>`
  (`inv-compare-pick`, con `CANCELAR`, `inv-compare-cancel`; se puede
  cambiar de pestaña de dueño). El clic en otra arma (o en la equipada)
  la toma como **B** y abre la **vista COMPARAR** (`cmp-view`), que
  reemplaza lista + detalle:
  - título `COMPARAR` y `Si equiparas B en vez de A`;
  - dos columnas (`cmp-card-a` / `cmp-card-b`) con la letra, el dueño si
    no es tuya (`de <nombre>`), `EQUIPADA` si la usás, la ficha y, solo
    en las tuyas, `EQUIPAR` (`cmp-equip-a/b`, motivo de `ShopGuards`),
    `DESARMAR` (`cmp-salvage-a/b`) y `VENDER $N` (`cmp-sell-a/b`); las
    ajenas dicen `Solo lectura`;
  - debajo, la comparación de A → B (`cmp-delta`);
  - abajo `INTERCAMBIAR A/B` (`cmp-swap`) y `CERRAR COMPARACIÓN [ESC]`
    (`cmp-close`). DESARMAR / VENDER piden la misma confirmación que
    el detalle (`cmp-craft-question`, `cmp-craft-cancel`,
    `cmp-craft-confirm` rojo); si el arma deja de existir (vendida,
    desarmada, dada) la vista se cierra y vuelve al inventario.
  - `Esc` (o `CERRAR COMPARACIÓN`) vuelve al inventario sin cerrar el
    panel; `Esc` en el modo "elige B" lo cancela.
  Tests: `test/features/inventory/weapon_compare_test.dart`.

### Peso del arma (v0.8.4)

Pedido del dueño: los jugadores no entendían por qué algunas armas
tienen peso. Dos cosas: el peso se muestra **siempre** (también en las
ligeras) y en **tres categorías** (`weightClassOf`, loot.md § 1.1), con
el trade-off y su efecto real en turnos. Nada de números duplicados en la
UI: el tag sale de `weightClassOf` y el turno de `BattleEngine.interval`
(helpers de `battle_impact.dart`: `turnChange`, `turnIntervalLine`,
`weightTurnLine`). Textos en `item_text.dart`: `weightTagMarkup`
(etiqueta en su color: Ligera verde, Media amarilla, Pesada naranja),
`weightTradeoffText`, `weightLinesMarkup`.

- **Ficha** (`itemTooltipMarkup`): debajo de `ATQ · MAG`, § "Ficha de
  objeto". Cubre tooltip de la grilla, detalle del inventario, FICHA de
  COMPRAR, columnas A / B de COMPARAR, alijo y filtro.
- **COMPRAR**: la categoría en cada fila y en el título del detalle.
- **Comparar armas** (`compareWeapons`): stat `Peso` (1 decimal) después
  de `VEL`, con ▲ verde si **baja** y ▼ rojo si sube
  (`StatDelta.higherIsBetter = false`); `WeaponComparison.weightBefore /
  weightAfter` y `weightClassBefore / After`. En `ComparisonDelta`
  (`cmp-weight`): `Peso: Ligera → Pesada` si cambia la categoría y, si
  cambia la VEL, `Tu turno llega cada 10 → 11.8 de tiempo (≈15% más
  lento)` (la misma línea que "En batalla").
- **FUSIÓN → Reforjar base**: cada base de la lista lleva su categoría;
  la vista previa suma la fila `Peso` (`craft-weight`): categoría y peso
  antes → después con ▲/▼, el trade-off de la base nueva y lo que cuesta
  en turnos con ella.
- **Filtro de loot**: condición `Peso Ligera|Media|Pesada` (loot.md § 13),
  también en la ayuda de la pestaña FILTRO.
- **Balance**: el peso ya era editable por arma (`Peso (−velocidad)`); la
  categoría se recalcula sola.
- Bestiario / drops: sin cambios.

Tests: `test/features/inventory/weapon_weight_test.dart`.

## Filtro de loot (pestaña FILTRO del personaje)

Cambios v0.11 (sistema de diseño, minimalista; design_system.md § 10):
- Barra de herramientas arriba, en una fila: `CASILLAS` / `TEXTO`, el
  estado (`filter-status`, Detalle: `Sin errores · N reglas · por
  defecto` en verde o el primer error en rojo con `(+N)` y todos en el
  tooltip), `RESTAURAR POR DEFECTO` (fantasma), `DESHACER` y `GUARDAR`
  (principal; el motivo si no se puede, en el tooltip).
- Sin párrafos de ayuda fijos: las ayudas de OCULTAR RÁPIDO, TUS REGLAS,
  ★ MI BUILD y la gramática viven en el "?" (`kFilterHelp`).
- OCULTAR RÁPIDO y TUS REGLAS con `DsSectionHeader`; las casillas en
  grilla compacta (rótulo del grupo a la izquierda en Detalle; con texto
  grande, arriba). Cada regla es una `DsListRow` de una línea: casilla,
  `Mostrar · nombre` en verde u `Ocultar · nombre` en rojo (atenuada si
  está apagada), las condiciones en Detalle, × fantasma para borrarla y
  la regla completa en el tooltip.
- Derecha: `★ MI BUILD` (qué busca tu plan en una línea, botones de qué
  cumplir, la línea y los atajos `+ AL CURSOR`, `+ RESALTAR`,
  `+ OCULTAR FUERA`, con su explicación en el tooltip) y `VISTA PREVIA ·
  NV N` (una línea por muestra: etiqueta y, al lado, la regla que la
  toma). Lo que sigue describe el comportamiento, que no cambió.

Desde v0.8.6 la izquierda tiene dos vistas sobre **el mismo texto**,
conmutables con `CASILLAS` (`filter-view-checks`, la de entrada) y
`TEXTO` (`filter-view-text`). Todo lo que cambian las casillas es texto:
la vista previa y la validación se actualizan en vivo y nada se aplica
hasta `GUARDAR`. Lógica pura en
`lib/features/inventory/domain/filter_quick.dart` (`FilterDoc`,
`quickOptions`); reglas del texto en loot.md § 13.1. Pendiente (loot.md
§ 6): reordenar con ▲▼ y duplicar.

- Línea "qué hace" (la de la pestaña): `Reglas en orden: gana la primera
  que coincide. Ocultar no borra el loot: lo deja en el piso.`
- **CASILLAS** (`filter-checks`, con scroll):
  - `OCULTAR RÁPIDO` y una ayuda corta. Una fila por grupo (`QuickGroup`:
    Excepción, Armas por rareza, Armas por peso, Armas por tipo, Otras
    armas, Materiales y pociones) con casillas `[x]`/`[ ]`
    (`FilterCheck`, `filter-quick-<id>`; marcada en dorado, la ★ en el
    violeta del plan). Los tipos salen del catálogo de armas. Marcar
    agrega la regla `# rápido: …`; desmarcar la saca. Al abrir, cada
    casilla se lee del texto (marcada si su regla está tal cual y
    prendida).
  - `TUS REGLAS (N)` (`filter-rules-title`) y una ayuda; una fila por
    regla del texto, en orden (`filter-rule-<i>`): casilla prender /
    apagar (`filter-rule-on-<i>`; apagada = `#OFF`), `Mostrar` en verde
    u `Ocultar` en rojo (dim si está apagada), el nombre o, sin nombre,
    las condiciones, y las condiciones en dim; `· con errores` en rojo si
    la regla tiene líneas que no se entienden; tooltip con la regla
    completa; `✕` (`filter-rule-del-<i>`) la borra. Sin reglas: `Sin
    reglas: todo se ve con el color de su rareza.`
- **TEXTO**: campo multilínea (`filter-text`) con el texto guardado
  (`profile.lootFilter`) o el por defecto.
- El editor es **por miembro** (`LootFilterTab` con clave
  `filter-tab-<actorId>`): al cambiar de miembro en el selector arranca
  con el filtro de ese miembro (antes de v0.8.6 quedaba el texto del
  anterior y `GUARDAR` se lo pisaba al nuevo).
- Derecha: `VALIDACIÓN` (`filter-status`): `Sin errores · N reglas` en
  verde o los errores del parser (`línea N: ...`) en rojo; `VISTA
  PREVIA`: objetos de muestra (Común de nivel bajo, Mágico, Raro, Épico
  con pasiva, Legendario y una pila de Prisma Roto) dibujados como
  etiquetas del mapa con el estilo del filtro (texto, borde, fondo,
  tamaño; `(oculto)` en dim, la regla que coincidió, sonido e ícono); y
  la gramática corta (también en el `[?]`).
- Derecha, entre VALIDACIÓN y VISTA PREVIA (v0.5.1): `★ COINCIDE CON MI
  BUILD` (condición `Build`; build_planner.md § 6.4): botones de qué
  tiene que cumplir (`filter-build-kind-any/base/mod/pasiva/habilidad`),
  la línea resultante (`filter-build-line`), los atajos
  `+ A LA REGLA DEL CURSOR` (`filter-build-insert`), `+ REGLA: RESALTAR`
  (`filter-build-highlight`) y `+ REGLA: OCULTAR COMUNES FUERA DEL PLAN`
  (`filter-build-hide`), y qué busca tu plan (`filter-build-plan`). La
  vista previa usa tu plan: ★ y "★ tu build: mod" en la muestra.
- Botones: `RESTAURAR POR DEFECTO` (`filter-default`, abajo a la
  izquierda: pone el texto por defecto en el editor, sin guardar),
  `DESHACER` (`filter-revert`: vuelve al guardado) y el primario
  `GUARDAR` (`filter-save`, `SetLootFilterAction`; si el texto es el
  por defecto se guarda `null`).

Tests: `test/features/inventory/filter_quick_test.dart`,
`test/features/inventory/loot_filter_tab_test.dart`,
`test/features/inventory/loot_filter_build_test.dart`.

## Resultado de misión: tus drops

`ResultsPanel` muestra `TUS DROPS` (los `LootDropEvent` del jugador
local desde el `MissionStartedEvent`, que el `SessionController` junta en
`SessionView.missionLoot`): una etiqueta por drop con el estilo de **tu
filtro** (`SessionEngine.lootVerdict`; color de rareza si ninguna regla
coincide) y, si el filtro lo oculta, `(oculto por tu filtro)` en dim.

## Personaje (`char`, 1298-1335)

**v0.11 (sistema de diseño, design_system.md § 10).** Pestañas `DsTabBar`
(`tab-N`) con la insignia de puntos adentro (`tab-badge-N`); la línea
fija de ayuda de cada pestaña pasó al "?" del título. La línea del título
va por color (nombre en Cuerpo, clase en Subtítulo, XP en Detalle) y ya
no repite los puntos: ATRIBUTOS tiene su barra arriba (`Puntos: P` ·
REINICIAR fantasma · DESHACER · CONFIRMAR PUNTOS principal + motivo en
Detalle); el pie solo lleva CERRAR. Secciones con `DsSectionHeader`
(ATRIBUTOS, SUGERENCIA, CLASE, VISTA PREVIA, PENDIENTE); las razones de
la sugerencia y los rasgos de Paladín, plegados (`DsFold`).

Título `PERSONAJE` o `¡SUBISTE A NIVEL N! Reparte tus puntos` [?].
Línea `nombre · clase LvN · Puntos: P` (P = puntos menos el reparto
pendiente). Pestañas `ATRIBUTOS · INVENTARIO · ÁRBOL · FILTRO` (loot v2:
INVENTARIO reemplaza a ARMAS; la tecla `I` abre el personaje en
INVENTARIO, `WorldPanel.inventory`; ver § "Inventario" y § "Filtro de
loot"). Antes eran tres pestañas (**desvío**: el prototipo apila todo en una
columna con scroll; a 1280×720 con fuente de 8 px no entra).

**Selector de miembro (v0.8.3, solo_party.md § 6).** Jugando solo con
compañeros, arriba de las pestañas va la fila `PartyMemberBar`
(`Ana (vos) · Leo · Mia · Cid`, cada uno con su insignia `+N` de puntos
sin usar; `member-<id>`). El elegido es el **miembro activo**: todo el
panel (título, atributos, clase, inventario, árbol, filtro, BUILD) lo
muestra y actúa sobre él. `Ctrl+←` / `Ctrl+→` cambian de miembro. La
misma fila está en la armería, la preparación, el Portal del Eco y la
Estatua del Tiempo. Durante el reparto obligatorio de la subida de
nivel no aparece (es siempre el líder).

### Atributos

`Reparte puntos con + y -; nada cambia hasta CONFIRMAR. Cada nivel da 3
puntos.`

- Izquierda: una fila por atributo (`STATN`): nombre, valor, `+n` verde
  pendiente, `-` / `+` (el `+` deshabilitado sin puntos, el `-` sin
  reparto) y `STATD` en `dim`. Debajo `Clase:` (cambio de clase, solo
  lobby; **agregado del puerto**) y, para el Paladín, sus rasgos de clase
  (`Rasgos de Paladín`: 3% de aturdir, débil a perforante y a estados; su
  kit clásico ahora es del Guardián).
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

### Árbol (v3, passive_tree_v3.md § 13)

- `Puntos de árbol disponibles: N` (`treePts`) y `REINICIAR ÁRBOL
  (GRATIS)` (`ResetTreeAction`; se muestra en todo modo salvo batalla
  mientras `freeRespec`). La ayuda (arrastrar para mover, rueda o +/− para
  zoom, clic para tomar) va en la línea "qué hace" de la pestaña
  (`PassiveTreeView(showHelp: false)`; sola, la vista la dibuja ella).
- Barra: buscador (`tree-search`, resalta con aro celeste los nodos cuyo
  nombre, cluster, tema, efectos o mecánica contienen el texto, sin
  tildes ni mayúsculas, desde 2 letras; dice `N coincidencias` o `Sin
  coincidencias`; `Enter` centra el visor en la primera) y botones `−`,
  `+` (zoom ×1.25 sobre el centro), `TODO` (el árbol entero) y `MI CLASE`
  (tu zona).
- Visor de hasta 420 px de alto (`PassiveTreeView.height`: el panel lo
  ajusta al alto libre, mínimo 240; ancho flexible) con el lienzo de
  1080 × 1080 (30 px por unidad, centro 540) dentro de un
  `InteractiveViewer` (arrastre, rueda, zoom 0.3×–2.5×). Arranca en `MI
  CLASE`: centrado a 7.5 unidades del centro hacia tu clase, a escala
  `min(ancho, alto) / 510` (entre 0.5 y 1.2).
- Dibujo: aro tenue del anillo central; enlaces de 2 px (`green` si los
  dos extremos están tomados; dorado de 4 px si son del **camino que
  falta** hasta el nodo enfocado; dorado tenue si son del cluster bajo el
  mouse; si no `panel`); nombre de cada cluster más allá de su keystone
  (puentes y grupos en celeste). Nodos: chico círculo r 5, notable r 8,
  inicio r 9, keystone hexágono r 11; notables y keystones con borde
  dorado. Relleno por estado: inicio `gold`, tomado `green` (keystone
  tomada roja), disponible `sky`, bloqueado `#3a4570` (incluye el
  excluido por la keystone opuesta). Camino y nodo enfocado con anillo
  dorado; coincidencias de búsqueda con anillo celeste.
- Pasar el mouse: tooltip en la esquina del visor opuesta al nodo
  (nombre, `NOTABLE` / `KEYSTONE` / `INICIO DE CLASE`, `Cluster X: tema`
  / `Puente X` / `Grupo X`, efectos con el texto completo de la mecánica
  —las keystones con su contra—, `Costo: N puntos` si no lo tenés, y el
  estado). Clic: lo selecciona y, si se puede tomar, manda
  `TakeNodeAction`.
- Panel lateral (352 px): el nodo elegido (o el del mouse) con nombre,
  tipo, cluster, efectos, costo, estado o el botón `TOMAR NODO`
  deshabilitado con el motivo de la tabla, y la leyenda.
- El motor permite tomar nodos en cualquier modo salvo batalla; el
  prototipo solo en lobby/preparación (`ed`). El puerto sigue al motor
  (**desvío**): se pueden tomar al subir de nivel en una misión.

## Portal del Eco (v0.4.0)

`EcoPortalPanel` (`lib/features/endgame/presentation`), con E frente al
portal del pueblo (`WorldPanel.ecoPortal`, aviso `[E] Portal del Eco`).
Título `PORTAL DEL ECO` con `[?]`, a la derecha `Atlas: N puntos libres`,
pestañas ECOS y ATLAS. Spec: docs/specs/ecos_atlas.md.

- Sin el portal activado: línea naranja `Portal apagado: vencé al
  Devorador de Eras...` (las pestañas se ven igual).
- **ECOS**: lista (380 px) de los Ecos del inventario (nombre en color
  de rareza + `T<n>`, zona · jefe · mods, la casilla a la derecha) y la
  ficha (`ecoTooltipMarkup`): tier y nivel de monstruos, zona y pisos,
  jefe, `Modificadores n/max` (rojo, cada uno con su `+% cant. +% rar.`)
  y `Botín: +Q% cantidad · +R% rareza` con el Atlas de la sala y el
  grupo. Abajo: los 4 crafteos (`MODS NUEVOS`, `+1 MOD`, `RAREZA`,
  `+1 TIER`, cada uno con su material y el motivo si no se puede) y
  `ABRIR ECO` (verde; propone al grupo y cierra el panel). En `main_dev`:
  `DEV: +ECO T1 / T8 / T16`.
- **ATLAS** (`AtlasView`): grilla 9 × 7 de nodos (cuadrados del color de
  su rama; lleno = tomado, borde grueso = se puede tomar, `?` = próxima-
  mente, el número = costo; notables más grandes) unidos por líneas; a
  la derecha (340 px) puntos libres y ganados, primeras veces, el nodo
  elegido con `TOMAR` (o el motivo), la leyenda y `REINICIAR (gratis)`.
  Solo se edita en el pueblo. Un cliente ve la nota `En grupo vale el
  Atlas del anfitrión...`.
- **v0.5 (lista + detalle)**: líneas cortas (`Elegí un Eco: ABRIR lo
  propone al grupo; los materiales lo mejoran.` / `Árbol de la cuenta:
  ganás puntos al completar algo por primera vez.`). ECOS: filas de una
  línea (`eco-row-<uid>`: nombre + `T<n>`, a la derecha la zona; sin la
  casilla). Debajo de la lista, `MEJORAR · tienes Esquirla n · ...` y
  una fila por crafteo: `Mods nuevos 1 Esquirla` (`+1 mod`, `Rareza`,
  `+1 tier`; `ecoCraftRowMarkup`) con `USAR` (`eco-craft-<op>`) y el
  motivo al lado: se ven sin bajar. El detalle queda para la ficha y
  `ABRIR ECO` (con `Enter Elegir · Esc Cerrar`). ATLAS: el lateral
  crece con el texto (hasta 45 % de la pantalla) y muestra primero el
  nodo elegido, después `Puntos libres · ganados`, la nota de grupo y
  `[? Leyenda]` (tooltip `atlas-legend` con primeras veces, la leyenda
  y las ramas); abajo `REINICIAR` y `TOMAR`.
- Inventario: los Ecos se ven en la grilla (ícono de portal y `T<n>`
  abajo a la derecha); la ficha es la misma. Acciones: MOVER, DAR A,
  TIRAR (sin COMPARAR, EQUIPAR, DESARMAR ni VENDER).
- HUD: con nivel 50, barra violeta de Maestría y `MAESTRÍA m · XP x/y`
  (`MAESTRÍA MÁX`); el título del panel de personaje la suma junto al
  nivel. Resultado de un Eco: `Eco T<n> · zona · jefe · Piso` y la línea
  turquesa con los puntos de Atlas ganados.

## Pasada de UX de menús (v0.5.1)

Pedido del dueño: tarjetas con "separaciones bien bien de cada acción"
(la FUSIÓN de v0.5 es la referencia), nada de listas densas con texto
cortado, y todo usable con teclado. Piezas en `lib/app/widgets/`
(`SectionPanel` ahora es también una `NavSection`, `ActionCard` con
`reason` = candado + motivo entero en el pie, `CostChip`, `MenuRow` con
`onFocus` / `autofocus`).

- **COMPRAR**: filas de la lista enteras (`wrap`, sin "…"). Detalle:
  encabezado (`shop-title`: nombre, tipo, Nv, Común) con `BuildFitBadge`
  ("★ TU BUILD", tooltip con lo que cumple), y secciones `SI LA EQUIPAS`
  (antes → después; aviso si no cumplís requisitos), `COSTO` (`CostLine`
  o "Ya tienes una") y `FICHA` (ficha + chips de habilidades + "QUÉ
  HACEN" con la ficha completa de cada habilidad y la ULT, con tus stats
  si la equiparas). Abajo `Enter Elegir · Esc Cerrar` y el
  `ConfirmButton` `COMPRAR` (`buy-<id>`) con el chip de costo; sin
  créditos, `No se puede: Faltan $N` arriba.
- **FORJA**: encabezado con `BuildFitBadge` y las habilidades del arma
  (chips); sección `FORJA` (`forge-cap`, pasiva, `forge-passive-note`) y
  una `ActionCard` por estadística (`up-<uid>-<stat>`, dentro de
  `forge-stat-<stat>`): ícono (espada / estrella / flecha / ancla),
  nombre, qué hace, cuadritos n/5, `Bono` y el stat antes → después, la
  línea violeta si sube la pasiva y el pie `CostChip` `+1 · $N` (o `MAX`,
  o candado + motivo, p. ej. `Tope de forja (3)`). Clic / `Enter` = +1.
  Grilla de 3 columnas a 1280 en Normal.
- **Inventario (derecha)**: desde v0.9.10 sin panel derecho (ver §
  "Inventario"; la grilla ocupa todo el ancho); la ficha (con habilidades, pasiva, mods, peso y forja,
  plegadas) es el tooltip de la casilla y las acciones, el menú
  contextual. Las confirmaciones (`CONFIRMAR` en rojo) y la cantidad de
  una pila van debajo de la grilla.
- **ATRIBUTOS**: sección `ATRIBUTOS · Puntos libres: N` con una tarjeta
  por atributo (`attr-row-<attr>`: sigla, nombre, valor `+n`, `★ n/meta`
  del plan, `-` / `+` y qué hace, entero, debajo; borde verde si tiene
  reparto pendiente), `★ Según tu build: ...` arriba; secciones `CLASE`
  (botones + motivo en el subtítulo) y `RASGOS DE PALADÍN`. Derecha:
  `VISTA PREVIA` (cómo cambian tus stats) y `PENDIENTE`.
- **Preparación › MISIÓN**: sección `MISIÓN` (la tarjeta) y a la derecha
  `GRUPO · n/m listos` (una fila enmarcada por jugador, verde si está
  listo), `TU EQUIPO` (`Arma`, `Consumibles`, `Créditos` en columna) y
  `AVISO` (naranja).
- **Resultado**: 900 px. Nombre y zona arriba; `RANGO` (letra grande
  `display`, tiempo y K.O.) │ `RECOMPENSAS` (XP, créditos, bonus en
  columna); `PROGRESO` (zona desbloqueada, Prueba, Atlas) y `BOTÍN`
  (obtuviste, drops del grupo, élites, TUS DROPS). Abre con el foco en
  `VOLVER AL LOBBY` (`Enter` vuelve). Sin tamaños a mano (`title` /
  `display`).
- **Creador de clase (título)**: `1 · CLASE` (tarjetas: sprite, nombre,
  arma inicial y su atajo `[n]`; flechas o `1`..`9` la eligen) │
  `DETALLE` (descripción entera, atributos base en barras, arma inicial
  con los chips de sus habilidades) y `2 · NOMBRE` (campo, `Enter
  Crear · Esc Cancelar`, `CANCELAR`, `> CREAR`). Tarjetas de personaje y
  `+ NUEVO PERSONAJE` con foco y aro.
- **Paneles opacos**: `RetroPanel` sin el alfa `ee` del prototipo (se
  leía el texto del mapa detrás de las tablas).

### Teclado en los menús (v0.5.1)

Sistema común (`lib/app/widgets/menu_focus.dart`; la tabla `kMenuKeys`
es la de CONTROLES › MENÚS):

| Tecla | Qué hace |
|---|---|
| Flechas | Mueven el foco en esa dirección (o al siguiente / anterior). En listas, el detalle **sigue al cursor** (`MenuRow.onFocus`). Al abrir, el foco ya está en la primera fila / tarjeta (`InitialFocus`) |
| `Tab` / `Shift+Tab` | Saltan a la **sección** siguiente / anterior (`NavSection`: lista, cada `SectionPanel`, los chips de habilidades; los botones sueltos cuentan como una) en orden de lectura |
| `Enter` / `Espacio` | Activan lo que tiene el foco (fila, tarjeta, botón) |
| `Esc` | Vuelve un paso (fusión, comparar, "elige B", creador) o cierra el panel; sin panel, la pausa |
| `Q` / `E`, `RePág` / `AvPág` | Pestaña anterior / siguiente (en círculo) |
| `Ctrl+Tab` / `Ctrl+Shift+Tab` | Pestaña siguiente / anterior |
| `1`..`9` | Pestaña N; en el mostrador la zona N; en el título el personaje N o (en el creador) la clase N |
| `Ctrl+←` / `Ctrl+→` | Party jugando solo (v0.8.3): miembro anterior / siguiente en los paneles con selector de miembro (solo_party.md § 6.2). `PanelFrame` y `FocusGrid` no usan las flechas con `Ctrl` |

- **Foco visible**: aro dorado de 2 px por fuera del elemento
  (`FocusRing`, no cambia el tamaño) y, en filas, el cursor ▶ a la
  izquierda; los botones con foco, borde dorado. Solo con el teclado
  (con el mouse, el resaltado de siempre). Un tooltip (`RetroHoverCard`)
  también aparece mientras su objetivo tiene el foco de teclado.
- **Dónde**: título y creador (`MenuKeyScope`), pausa / configuración
  (pestañas), mostrador, preparación, armería (COMPRAR / FORJA / FUSIÓN /
  CONSUMIBLES; la fusión conserva su `Enter` avanza / `Esc` vuelve un
  paso), Portal del Eco, Estatua, personaje (pestañas bloqueadas mientras
  hay que repartir), inventario y alijo.
- **Grillas** (`FocusGrid`: inventario `inv-focus-<i>`, alijo): las
  flechas mueven el cursor casilla por casilla (en el borde salen de la
  grilla) y en el inventario **eligen** la casilla y muestran su
  tooltip (`RetroHoverCard.keyboardFocus`; abierto por teclado no toma
  el mouse); `Enter` sobre la casilla ya elegida abre el **menú de
  acciones** (v0.9.9; `Enter` en Equipar la equipa); en MOVER / "elige
  B" `Enter` es el clic. Clic también mueve el cursor.
- Con un campo de texto enfocado nada de esto toca las teclas (en el
  título, `Esc` sale del campo). La batalla tiene su propio teclado
  (sin cambios).

### Ficha de habilidad (v0.5.1)

Pedido del dueño: "que haya tooltip de qué es la habilidad, porque no sé
qué hace la habilidad solo por el nombre". Fuera de la batalla, cada
nombre de habilidad / ULT es un **chip** (`SkillChip` / `SkillChips`,
`lib/features/inventory/presentation/skill_chip.dart`; borde fino, `?`
celeste) con su ficha en un `RetroTooltip` (mouse o foco de teclado):
`skillTipMarkup` (`lib/features/inventory/domain/skill_tip.dart`) = el
mismo texto de la batalla (`describeSkillMarkup`: MP, daño con tus stats
`= N` y crítico, objetivos, estados, escudos, marcas, carga, efectos de
kit y variantes) + la línea `Tipo · a <objetivo> · crítico N%`
(Físico / Mágico / Curación / Apoyo). Dónde: FICHA de COMPRAR (más "QUÉ
HACEN" en línea), FORJA, detalle del inventario, COMPARAR, tarjetas del
paso 1 de la fusión, `Qué hacen:` debajo de Habilidades en ANTES │
DESPUÉS (la nueva en verde), y el creador. Los tooltips de las casillas
(inventario y alijo) usan `itemTooltipMarkup(skillDetails: true)`: una
línea por habilidad `• Nombre (N MP · Tipo): efecto · ...` y la ULT
(v0.9.7: en el inventario, plegadas en `▸ Habilidades`; ui_style.md §
"Tooltips cortos").
En el paso 3 de la fusión (traer habilidad) cada fila lleva `(N MP ·
Tipo)` y, debajo de la elegida, la ficha entera (`craft-pick-desc`), así
se lee sin mouse. v0.9.7: sin tooltip en esas filas (repetía la ficha
de abajo).

**Reemplazo y restricciones (traer habilidad)**: las habilidades del
origen que el arma no puede recibir (`ItemRules.canReceiveSkill`: físicas
cuerpo a cuerpo / a distancia) se ven atenuadas con el motivo en rojo
(`Solo armas a distancia`); con los cupos de trasladadas llenos
(`needsReplaceChoice`) aparece `¿Qué habilidad reemplazas?`
(`craft-replace-title`, en rojo hasta elegir) **justo debajo de la
habilidad elegida y antes de su ficha** (v0.8.6; antes iba al final de la
lista y no se veía sin bajar), con `craft-replace`: una `ActionCard` por habilidad del arma
(`craft-replace-<id>`, con su ficha en el tooltip): las trasladadas se
eligen (`Trasladada` / `Se reemplaza`; Quebrar desde v0.9.1 también,
como `Ranura de Quebrar`, loot.md § 16.3), las de la base bloqueadas
(`Habilidad base`). La acción lleva `replaceSkillId`; ANTES │ DESPUÉS
muestra el resultado con esa elección y el botón queda bloqueado con el
motivo del motor (`Elegí qué habilidad reemplazar`) hasta elegir.

### En batalla (v0.5.1)

Pedido del dueño: ver qué cambia en la pelea al forjar o repartir, no
solo un número. `battleImpactLines` / `battleImpactMarkup`
(`lib/features/inventory/domain/battle_impact.dart`) compara dos
`DerivedStats` con el código de la batalla y escribe solo lo que cambia,
con tus números: turno (`BattleEngine.interval`: `Tu turno llega cada
10.4 → 9.9 de tiempo (≈5% más seguido; +1 turno cada ~19)`), daño
(`Atacar 19 → 21 · Corte Giratorio 19 → 21 c/u`, las mágicas y curas
con MAG), crítico (`15% → 17% de chance (daño ×1.5)`), defensa
(`Daño recibido −9% → −12%: un golpe de 20 te saca 18 → 18`), vida y
maná (usos de la primera habilidad con MP). Dónde: cada tarjeta de FORJA
(`forge-impact-<stat>`, en línea, "si la equipas" para otra arma) y el
tooltip de cada atributo en ATRIBUTOS (`attr-row-<attr>`: `+1 Agilidad:
... En batalla: ...`, también con el foco en `-` / `+`).

Tests: `test/app/menu_keyboard_test.dart`,
`test/features/inventory/skill_tips_test.dart`.

## Fuera de alcance

Tienda ambulante (`merchant`): el mapa nunca genera mercader
(world.md); el panel existiría con consumibles y herrería. Rama de
Paladín (`branch`): código muerto en el prototipo.

## Pestaña ULT (v0.32.5)

Pedido del dueño: que nada se corte y no haya que scrollear para leer
la descripción. `UltRepertoireView`:

- **Arriba**: `ULT EQUIPADA` (estado: Automática / Elegida / No
  disponible) y la fila compacta de la equipada.
- **REPERTORIO**: contadores (`Las 50: x/50`, `Jefes vencidos: x/10`) y
  la barra BUSCAR · ARMA · ORIGEN · ESTADO · ORDEN a **todo el ancho**,
  en un `Wrap`: lo que no entra baja de línea, nunca se recorta.
- **Tabla** `DsColumnsTemplate` (ui_minimal.md § 9.3), 4 columnas de
  25 % con encabezado y línea entre columnas; cada una scrollea sola:
  1. **LISTA**: nombre y `Nv n · Origen` (o `Falta · cómo`), el texto
     baja de línea; la elegida resaltada; NUEVA / EQUIPADA a la derecha.
  2. **DESCRIPCIÓN**: nombre, origen y armas, motivo si no está
     disponible, cómo conseguirla si falta, descripción corta (RESUMIDO)
     y `VER DETALLE` / `OCULTAR DETALLE` con el texto largo (DETALLADO).
  3. **ACCIONES**: EQUIPAR (o la insignia EQUIPADA) y MEJORAR →
     CONFIRMAR / CANCELAR (gris si no alcanza o en combate); abajo,
     apilado: `Nivel n/5: poder ×f`, `AL MEJORAR: NIVEL n → n+1`, poder
     antes → después, daño y curación +%, escudos/trampas/golpes
     diferidos +%, y `COSTO` con créditos y cada material (rojo si no
     alcanza, con lo que tenés).
  4. **PREVISUALIZACIÓN**: la mini escena (ultimates_v2.md § 2.5) con
     solo PAUSA/REPRODUCIR y SONIDO; sin leyenda. No scrollea.
- La tabla toma el alto que queda (mínimo 300 px); si el panel es muy
  bajo, scrollea la pestaña entera.
