# Spec: Progresión, economía y perfil

Fuente de verdad: prototipo `ecos-del-tiempo.html`, `ITEMS`/`MAX_ITEM`
(118-125), `UP_MAX`/`UPSTATS`/`upStatsFor`/`FUSE_COST`/`wSkills`/`upLvl`/
`upTot`/`upCost`/`wName`/`meetsReq`/`canEquip`/`sumSt`/`resetBuild`
(243-267), `xpNeed` (304), `checkEnd` (750-757), las acciones del host
`cls`, `respec`, `stats`, `equip`, `node`, `treeReset`, `fuse`, `up`,
`buyItem`, `buy` (567-579), `addPlayer` (590-604), `loadProfile` /
`saveProfile` (496-501) y los paneles (1255-1391: `alloc`, `mustAlloc`,
`previewOf`).

Implementación Dart:
- Perfil: `lib/game_engine/models/player_profile.dart` (`PlayerProfile`,
  `toJson` / `fromJson`).
- Persistencia (solo interfaz): `lib/game_engine/models/profile_store.dart`.
- Reglas: `lib/game_engine/rules/progression_rules.dart` (`ProgressionRules`).
- Mejoras: `lib/game_engine/models/upgrade_stat.dart`.
- Consumibles: `lib/game_engine/data/items_catalog.dart`.

Tests: `test/game_engine/progression_rules_test.dart`,
`test/game_engine/player_profile_test.dart`.

Todas las reglas son funciones puras: reciben un `PlayerProfile` y
devuelven el perfil nuevo, o `null` si la acción no es válida (el perfil
no cambia). La sesión (missions.md) decide además en qué modo se permite
cada una y ajusta vida/maná.

## Perfil persistente

Lo que guarda `saveProfile`: nombre, clase, nivel, XP, créditos,
atributos, puntos sin repartir, inventario de armas, arma equipada,
pociones de vida y de maná, mejoras por arma, habilidad fusionada por
arma y nodos del árbol (en orden). El JSON usa las mismas claves que el
prototipo, para poder importar un perfil viejo:

```json
{"name":"Ana","cls":"maga","lvl":3,"xp":12,"cr":250,
 "st":{"VIT":6,"ESP":19,"AGI":7,"FUE":4,"DES":6},"pts":0,
 "inv":["baculo_aprendiz"],"eq":"baculo_aprendiz","pot":3,"eter":1,
 "up":{"baculo_aprendiz":{"pow":2}},"fuse":{},"tree":["mag_a0"]}
```

`fromJson` es tolerante (campos faltantes o de otro tipo toman su valor
por defecto). Después `ProgressionRules.normalize` aplica la validación
de `addPlayer`:
- Clase desconocida → `guerrero`. Nombre recortado a 10 (vacío → "Héroe"
  al entrar a una sala). Nivel `1..99`, XP y créditos `≥ 0`, pociones
  `0..9` (por defecto 3 de vida y 1 de maná).
- Inventario: solo armas que existen, máx. 40.
- Árbol: se recorre en orden y se acepta cada nodo si existe, no está
  repetido, quedan puntos (`nivel − 1`), está conectado a uno ya tomado
  (o al inicio de la clase) y no lo excluye otro tomado.
- Fusiones: solo arma existente → habilidad existente.
- Mejoras: solo armas existentes y estadísticas válidas para esa arma,
  cada nivel `0..5`.
- Atributos válidos si cada uno es `≥` al base de la clase, los puntos
  son `≥ 0` y `Σ atributos + puntos = Σ base + (nivel − 1) × 3`; si no,
  `resetBuild`. Siempre tiene el arma inicial de su clase.
- Arma equipada que no existe o no puede equipar → la inicial.

La persistencia es una interfaz (`ProfileStore`: `load` / `save`); la
implementación con disco o `shared_preferences` vive fuera de
`game_engine`. `InMemoryProfileStore` sirve para tests.

## Niveles

- XP para pasar del nivel `l` al siguiente: `xpNeed(l) = 10 + l² × 8`.
- `gainXp`: suma la XP y mientras alcance resta `xpNeed(nivel)`, sube
  1 nivel y da `+3` puntos de atributo (`PTS_LVL`). El árbol gana 1
  punto por nivel (passive_tree.md).
- Al subir, la vida y el maná actuales suben lo mismo que el máximo
  (lo hace la sesión).

## Atributos (`allocate`)

`alloc` del panel: cuánto se suma a cada atributo. Valores negativos
cuentan como 0. Se acepta si el total es `> 0` y `≤` puntos disponibles.
Vida y maná actuales suben lo que suba el máximo.
`previewAllocation` calcula los stats con el reparto sin aplicarlo
(`previewOf`). `mustAllocate` (sesión): en modo `levelUp`, el jugador
subió y tiene puntos.

`respec` / `resetBuild`: atributos al base de la clase, puntos
`(nivel − 1) × 3`, agrega el arma inicial si falta y, si el arma equipada
deja de cumplir requisitos, equipa la inicial. En la sesión llena vida y maná.

`changeClass`: árbol vacío, arma inicial de la nueva clase y
`resetBuild` (mantiene nivel, XP, créditos e inventario).

## Armas

- `meetsRequirements` / `canEquip`: arma de su clase y cada atributo
  `≥` al requisito.
- `equip`: debe tenerla y poder equiparla.
- `buyWeapon`: de su clase, precio `> 0`, que no la tenga y le alcancen
  los créditos. Se puede comprar sin cumplir requisitos.
- Consumibles (`buyItem`): Poción de vida 30, Poción de maná 40; máx. 9
  de cada una.

## Herrería (`upgrade`)

Estadísticas mejorables (`upgradeStatsFor`): Poder (+12% ATQ y MAG por
nivel), Crítico (+2%), Velocidad (+0.3) y, si el arma tiene escudo,
Defensa (+1). Máx. nivel 5 por estadística. Arma de su clase y en el
inventario. Costo del nivel `l → l+1`:

```
upCost(arma, l) = round(max(precio, 200) × 0.22 × (l + 1))
```

Nombre con mejoras (`weaponDisplayName`): `"Nombre +N"` con `N` = suma
de niveles.

## Fusión (`fuse`, ₵200)

El arma base `a` hereda una habilidad `sk` del arma `b`, que se consume.
Requisitos: `a ≠ b`, ambas en el inventario y de su clase, `b` no es el
arma inicial ni la equipada, `sk` es una habilidad propia de `b` y le
alcanzan los créditos. Efecto: `fuse[a] = sk` (reemplaza la anterior),
`b` sale del inventario y pierde sus mejoras y su fusión.
Habilidades de un arma en combate (`weaponSkills`): kit de clase +
habilidades del arma + la fusionada (si no estaba).

## Árbol de pasivas

`takeNode` (`PassiveTreeRules.canTake`) y `resetTree` (vacía la lista).
Al tomar un nodo, vida y maná actuales suben lo que suba el máximo; al
reiniciar se recortan al máximo nuevo. Ver passive_tree.md.

## Fuera de alcance (fases siguientes)

Paneles y botones (UI), tooltips, el autoguardado cada 2 s del cliente
(lo hará la capa `features`/`data` llamando a `ProfileStore.save` con
`SessionPlayer.profile`).
