# Bolsas de oficio y la pestaña OFICIOS (v0.32.4)

Reemplaza la pestaña PESCA Y CULTIVO de PERSONAJE (farming.md § 11,
fishing.md § 9). Código: `lib/game_engine/rules/oficio_storage_rules.dart`
(reglas, Dart puro), `lib/features/world/presentation/panels/oficios_view.dart`
y `life_items_view.dart` (UI).

## 1. Pestañas de PERSONAJE

`ATRIBUTOS · OFICIOS · EQUIPAMIENTO · ÁRBOL · ULT · FILTRO · BUILD ·
BESTIARIO · HAZAÑAS`. EQUIPAMIENTO es el inventario de siempre (antes
INVENTARIO; la tecla `I` abre ahí). OFICIOS tiene dos subpestañas
(`DsTabBar`, una por vez, nunca apiladas):

- **HABILIDADES** (`oficios-sub-habilidades`): los árboles de Pesca,
  Cultivo y Herrería (life_skill_trees.md § 5), sin cambios.
- **INVENTARIO** (`oficios-sub-inventario`, solo en el pueblo): una
  bolsa por oficio en pestañas `PESCA n/40 · CULTIVO n/40 · HERRERÍA n/40`
  (`oficio-bag-<bolsa>`), buscador, filtros por tipo
  (`oficio-filter-<id>`, botones compactos) y la grilla de casillas con
  borde de rareza, cantidad y el detalle a la derecha (`LifeItemGrid`).

## 2. Qué va en cada bolsa

Una **casilla** es una pila; la cantidad de una pila no tiene tope.

| Bolsa | Casillas | Filtros |
|---|---|---|
| PESCA | cañas propias, cada especie de pescado y de basura del agua | TODO · CAÑAS · PESCADOS · BASURA · BESTIARIO |
| CULTIVO | azadas y regaderas, cada semilla, cada abono, cada cosecha por calidad | TODO · HERRAMIENTAS · SEMILLAS · ABONOS · COSECHAS |
| HERRERÍA | materiales de oficio (fibra vegetal, cebo prensado, tabla tratada); también lista menas y lingotes (no ocupan casillas) | TODO · MATERIALES · MINERALES · COLECCIÓN |

El BESTIARIO DE PESCA es un filtro de PESCA (registro, no ocupa
casillas), con sus botones de bioma y franja (fishing.md § 10). Los
materiales de forja de armas (Esquirla, Cristal, Prisma...) siguen en
EQUIPAMIENTO.

## 3. Tope de 40 casillas (host)

`OficioStorageRules.cap = 40` por bolsa. Lo aplica el host en
`SessionEngine.apply` y `tick`, comparando cada perfil antes y después
del paso:

- **Compras** (`BuyRodAction`, `FarmShopAction` buySeed / buyTool /
  buyAbono, `TownAction.takeSeeds`) que dejarían una bolsa por encima de
  su lugar: la acción se rechaza (no se cobra nada).
- **Lo demás** (capturas, cosechas, hallazgos, cofres de ayudantes): las
  pilas **nuevas** que no entran se venden solas al momento, la última
  primero: pescado a su precio, cosecha al precio de venta con calidad,
  semillas y abonos a la mitad de su precio. Aviso en el chat:
  `Bolsa de oficio llena: <nombre> vendió <items> (+N de oro).`
- Sumar a una pila existente siempre entra.
- Las herramientas y los materiales de oficio nunca se venden solos.

## 4. Saves viejos

No hay migración que mueva nada: el lugar de una bolsa es
`max(40, casillas que ya tenía)`. Un save con más de 40 pilas las
conserva todas (el alijo de la cuenta no guarda ítems de oficio) y no
admite pilas nuevas hasta bajar de 40. El JSON del perfil no cambia.

## 5. Red

Sin cambios en el protocolo: no hay acciones ni campos nuevos; el host
valida y el estado llega como siempre. `kProtocolVersion` queda igual.

## 5b. Dar a un compañero

Cada pila (salvo herramientas) tiene DAR A <compañero> en su detalle:
ver share_materials.md (protocolo 78).

## 6. Teclas (v0.32.4)

- `Tab` (y `C`, de alias) abre y cierra PERSONAJE; con PERSONAJE
  abierto, `Tab` lo cierra y el foco se mueve con flechas y `Shift+Tab`.
- `I` abre PERSONAJE en EQUIPAMIENTO. `J` DIARIO y `O` objetivos, igual.
- Escribiendo en el chat o en un campo, `Tab` no es atajo.
- La herramienta de la huerta pasa de `Tab` a `R` (o la rueda).

## 7. Dónde se compra cada cosa (v0.48.5)

- AGROPECUARIO: consumibles e insumos (semillas, abonos, cebos, insumos
  de mina) y la venta de lo producido.
- TALLER DE OFICIOS (casa de los oficios): CRAFTEO de materiales de
  oficio y HERRAMIENTAS (cañas, azadas, regaderas, picos). Ver
  town_loop.md § 2.1. Las herramientas no ocupan casillas de bolsa.
