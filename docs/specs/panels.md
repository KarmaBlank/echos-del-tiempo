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
| Secciones de tienda (armas, consumibles, herrería, fusión, armas propias) | `lib/features/inventory/presentation/shop_sections.dart` |
| Armería | `lib/features/inventory/presentation/armory_panel.dart` |
| Personaje (pestañas Atributos / Armas / Árbol) | `lib/features/world/presentation/panels/character_panel.dart` |
| Árbol (dibujo + info lateral) | `lib/features/passive_tree/presentation/passive_tree_view.dart` |
| Textos del árbol (`fxTxt`, `KEYS`) y estado de cada nodo | `lib/features/passive_tree/domain/passive_text.dart` |
| Mostrador, votación, preparación | `lib/features/missions/presentation/*.dart` |
| Marco, botones, filas y secciones | `lib/app/theme/panel_frame.dart` |

Tests: `test/features/inventory/armory_panel_test.dart`,
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
| Comprar arma (`BuyWeaponAction`) | `Solo en el lobby o la preparación` (`canShop`), `Ya la tienes`, `Faltan $N` |
| Comprar consumible (`BuyItemAction`) | `canShop`, `Máximo 9`, `Faltan $N` |
| Equipar (`EquipAction`) | `Solo en preparación` (texto del prototipo, fuera de `canShop`), `Confirma puntos` (cumple con el reparto pendiente pero no con los atributos actuales), `Requisitos` |
| Mejorar (`UpgradeAction`) | `canShop`, `MAX` (nivel 5), `Faltan $N` |
| Fusionar (`FuseAction`) | `canShop`, `Elige un arma a sacrificar`, `Faltan $N` |
| Reiniciar puntos (`RespecAction`) | `canShop` (el botón solo se muestra en lobby/preparación, como el prototipo) |
| Cambiar clase (`ChangeClassAction`) | `Solo en el lobby`, `Es tu clase` |
| Tomar nodo (`TakeNodeAction`) | `No en batalla`, `Ya lo tienes` / `Nodo inicial`, `Sin puntos de árbol`, `Excluye <keystone>`, `Necesita un nodo conectado` |
| Reiniciar árbol (`ResetTreeAction`) | `canShop`, `No hay nodos tomados` (el motor lo acepta igual; la UI no lo ofrece porque no hace nada) |

## Marco común (`PanelFrame`)

Botones de abajo (línea 1360): en `prep`, los paneles que no son el de
preparación tienen `< VOLVER A PREPARACIÓN`; fuera de `prep`, los que no
son el de personaje tienen `PERSONAJE [C]` y todos `CERRAR [ESC]`
(deshabilitado mientras `mustAllocate`).

## Mostrador (`board`, 1271-1276)

Una fila por misión: rango grande, nombre, `tipo · Lv recomendado N ·
Elimina N grupos y vence al jefe · S: < N min sin K.O. · Jefe suelta
armas`, botón `PROPONER` (deshabilitado si ya hay votación) →
`ProposeMissionAction` y cierra el panel. Debajo, `Clase:` con un botón
por clase permitida por `FeatureFlags` (la actual deshabilitada) →
`ChangeClassAction`, y la ayuda del prototipo.

## Votación (`renderVote`, 1364-1375)

Caja arriba al centro (debajo de la barra de misión) en el lobby
mientras hay votación: `Votación · <quién> propone <misión> (rango R)`,
la lista de jugadores con `>` verde si votó que sí o `...` gris si no, y
`SÍ [Y]` / `NO [N]` (`VoteMissionAction`) o, si ya votó,
`Esperando al resto...` + `CANCELAR` (`VoteMissionAction(false)`).
Reemplaza el aviso de una línea del HUD.

## Preparación (`prep`, 1341-1349)

Título `PREPARACIÓN · <misión> (rango R)`, aviso de que en la misión no
hay tienda, jugadores con su estado de ¡Listo!, botones `¡LISTO!` /
`YA NO ESTOY LISTO` (`ReadyAction`), `PERSONAJE / EQUIPAR [C]`,
`CANCELAR MISIÓN` (`CancelPrepAction`), `Créditos · Arma` y luego, en el
orden del prototipo: consumibles, herrería, fusión y la armería de su
clase (las mismas secciones que la armería).

## Armería (`shop`, 1352-1358)

`Créditos: $N · Solo armas de tu clase (<clase>)` y, en orden:

1. **Armas a la venta**: las armas de su clase con precio `> 0`, en el
   orden del catálogo. Por arma: nombre, tipo, `Req:` con cada atributo
   en verde si lo cumple y en rojo si no (`reqHtml`, atributos actuales),
   `Escala:` (`wPowTxt`: por atributo de la fórmula de poder, `A` si el
   coeficiente es `≥ 0.8`, `B ≥ 0.6`, `C ≥ 0.4`, si no `D`), `Peso N
   (-vel.)` y `Habilidades:` (`skHtml`: nombres, `(retrasa)` si demora,
   el estado que aplica, `(fusión)` para la fusionada, `ULT: <nombre>` y
   `DEF +N` si tiene escudo). A la derecha `TIENES` (verde) o el botón
   `$precio` → `BuyWeaponAction`. Pasar el mouse por la fila muestra el
   detalle (`weaponTip`).
2. **Consumibles** (`itemsHtml`, máx. 9 de cada uno): nombre, `tienes N`,
   descripción y botón `$precio` → `BuyItemAction`.
3. **Herrería** (`upHtml`): una caja por arma propia de su clase con el
   nombre (`wName`, `+N`), `EQUIPADA` o el botón `EQUIPAR`
   (`EquipAction`; **agregado del puerto**: en el prototipo se equipa
   solo desde Personaje), y por cada estadística mejorable
   (`upgradeStatsFor`): `Nombre +valor (l/5)` y el botón `+1 $costo`
   (`UpgradeAction`) o `MAX`. Valores: Poder y Crítico en `%`
   (`round(l × per × 100)`), Velocidad con un decimal, Defensa entero.
4. **Fusión** (`fuseHtml`, $200): `Base` = cualquier arma propia de su
   clase (por defecto la equipada); `Sacrificar` = las demás salvo la
   inicial y la equipada (por defecto la primera); `Habilidad a heredar`
   = las habilidades propias de la sacrificada (por defecto la primera).
   El prototipo usa `<select>`; el puerto usa una fila de botones por
   lista (el elegido con borde dorado). `FUSIONAR` → `FuseAction`;
   `(reemplaza <habilidad>)` en `gold` (naranja en el prototipo) si la
   base ya tenía una fusión. Sin candidatas: `(no hay armas disponibles)`.
5. Ayuda: se puede comprar sin cumplir requisitos.

La armería solo se abre en el lobby (frente al mueble); en `prep` se
cierra y su contenido está dentro del panel de preparación.

## Personaje (`char`, 1298-1335)

Título `PERSONAJE` o `¡SUBISTE A NIVEL N! Reparte tus puntos`. Línea
`nombre · clase LvN · Puntos: P` (P = puntos menos el reparto
pendiente). Tres pestañas (**desvío**: el prototipo apila todo en una
columna con scroll; a 1280×720 con fuente de 8 px no entra):

### Atributos

- Una fila por atributo (`STATN`): valor, `+n` verde pendiente, `-` / `+`
  (el `+` deshabilitado sin puntos, el `-` sin reparto) y `STATD`.
- **Vista previa** (`previewOf`): `HP`, `MP`, `VEL` (un decimal, con la
  fórmula `(6 + AGI×0.5 + DES×0.1 - peso arma)`), `ATQ`, `MAG`, `DEF`
  (`(-N% daño)`) y `CRÍT` (`%`, `(daño crítico ×1.5)` o `×2` con Ojo de
  Halcón): `valor` o `valor > nuevo` (el nuevo en verde) si el reparto
  lo cambia. Se calcula con `ProgressionRules.previewAllocation`.
- `CONFIRMAR PUNTOS` (deshabilitado sin reparto) → `AllocateStatsAction`;
  `REINICIAR PUNTOS` (solo lobby/preparación) → `RespecAction`.
- `Clase:` (cambio de clase, solo lobby; **agregado del puerto**, el
  prototipo lo tiene solo en el mostrador).
- Paladín: el texto del kit (`Kit de Paladín`).
- Con `mustAllocate`: la ayuda "El equipo sigue cuando todos...".

### Armas

`Armas (tipos de su clase)`: cada arma del inventario de su clase con
`Req` coloreado según los atributos **con el reparto pendiente**
(`q.st`), escala, peso, habilidades y `EQUIPADA` o `EQUIPAR` con los
motivos de la tabla (`Solo en preparación`, `Confirma puntos`). Debajo,
`Consumibles: Poción de vida xN · Poción de maná xN`.

### Árbol (`treeHtml`)

- `Puntos de árbol disponibles: N` (`treePts`) y `REINICIAR ÁRBOL` (solo
  lobby/preparación, `ResetTreeAction`).
- Lienzo cuadrado de 400 px (el prototipo usa 320 con `SC = 34`; acá
  `SC = 42.5`, centro en 200): fondo `night`, enlaces de 2 px (`green`
  si los dos extremos están tomados, si no `panel`), nodos con radio 9
  (keystone), 8 (inicio) o 6 (resto) × 1.25, borde `night`:
  - inicio de la clase: `gold`;
  - tomado: `green` (keystone tomada: `red`);
  - disponible (se puede tomar ahora): `ink`;
  - bloqueado: `panel` con borde `muted` (incluye el excluido por la
    keystone opuesta, p. ej. Creyente con Inherente tomada).
  - el nodo seleccionado o bajo el mouse lleva un anillo `gold`.
- **Desvío**: los colores del prototipo (`#ffd166`, `#7bed9f`, `#ff6b6b`,
  `#9fb4ff`, `#3a4570`) se cambian por la paleta de 8 colores (el árbol
  es interfaz, no arte del mundo).
- Clic en un nodo: lo selecciona y, si se puede tomar, manda
  `TakeNodeAction` (como el prototipo). Pasar el mouse muestra su info.
- Info lateral (el tooltip del prototipo): nombre, efectos (`fxTxt`: una
  línea por efecto, `KEYS` para las keystones; sin emojis, la fuente no
  los tiene), `Nodo inicial` y el estado: `Tomado`, `Disponible: clic
  para tomar` o, si está bloqueado, el botón `TOMAR NODO` deshabilitado
  con el motivo de la tabla a su lado.
- El motor permite tomar nodos en cualquier modo salvo batalla; el
  prototipo solo en lobby/preparación (`ed`). El puerto sigue al motor
  (**desvío**): se pueden tomar al subir de nivel en una misión.

## Fuera de alcance

Tienda ambulante (`merchant`): el mapa nunca genera mercader
(world.md); el panel existiría con consumibles y herrería. Rama de
Paladín (`branch`): código muerto en el prototipo.
