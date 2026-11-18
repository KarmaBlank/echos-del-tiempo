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

**Loot v2** (docs/specs/loot.md, Parte 2): las armas son instancias
(`ItemInstance`) con rareza, afijos, pasiva, forja y habilidades
trasladadas; cualquier clase equipa cualquier arma si cumple nivel y
requisitos; nivel máximo 50. Lo que sigue describe la regla vieja donde
no cambió; donde cambió, manda loot.md.

Todas las reglas son funciones puras: reciben un `PlayerProfile` y
devuelven el perfil nuevo, o `null` si la acción no es válida (el perfil
no cambia). La sesión (missions.md) decide además en qué modo se permite
cada una y ajusta vida/maná.

## Perfil persistente

Lo que guarda `saveProfile`: nombre, clase, nivel, XP, créditos,
atributos, puntos sin repartir, armas (instancias, perfil v3: loot.md
§ 15), arma equipada (`uid`), pociones de vida y de maná, materiales,
grilla del inventario, filtro de loot y nodos del árbol (en orden). Un
perfil v1/v2 (el formato del prototipo, abajo) se migra al cargarlo:
cada id de `inv` → arma Común con sus mejoras y su fusión:

```json
{"name":"Ana","cls":"maga","lvl":3,"xp":12,"cr":250,
 "st":{"VIT":6,"ESP":19,"AGI":7,"FUE":4,"DES":6},"pts":0,
 "inv":["baculo_aprendiz"],"eq":"baculo_aprendiz","pot":3,"eter":1,
 "up":{"baculo_aprendiz":{"pow":2}},"fuse":{},"tree":["brasa_1"],"tv":2}
```

`tv` es la versión del árbol (hoy 2, `kPassiveTreeVersion`). Un perfil
sin `tv` o con una versión vieja que tenía nodos se carga con el árbol
vacío y recuerda cuántos devolvió (`treeRefunded`, clave `tvRef` solo
hasta normalizar); al entrar a la sala el sistema avisa una vez
(passive_tree_v2.md § 6).

`fromJson` es tolerante (campos faltantes o de otro tipo toman su valor
por defecto). Después `ProgressionRules.normalize` aplica la validación
de `addPlayer`:
- Clase desconocida → `guerrero`. Nombre recortado a 10 (vacío → "Héroe"
  al entrar a una sala). XP y créditos `≥ 0`, pociones
  `0..9` (por defecto 3 de vida y 1 de maná). Nivel `1..50`.
- Armas: solo bases que existen, instancias saneadas (`ItemRules.sanitize`:
  afijos válidos para el tipo y la rareza, valores en su rango, pasiva
  solo en Épico / Legendario), `uid` sin repetir, máx. 80; materiales
  `0..99`; la grilla se rearma (`InventoryRules.layout`).
- Árbol: se recorre en orden y se acepta cada nodo si existe, no está
  repetido, quedan puntos (`nivel − 1`), está conectado a uno ya tomado
  (o al inicio de la clase) y no lo excluye otro tomado.
- Fusiones: solo arma existente → habilidad existente.
- Mejoras: estadísticas válidas para esa arma, cada nivel `0..5` (la
  suma no se recorta: las armas migradas conservan su forja aunque pase
  el tope de su rareza).
- Atributos válidos si cada uno es `≥` al base de la clase, los puntos
  son `≥ 0` y `Σ atributos + puntos = Σ base + (nivel − 1) × 3`; si no,
  `resetBuild`. Siempre tiene el arma inicial de su clase.
- Arma equipada que no existe o no puede equipar → la inicial.

Desde v0.3 cada `PlayerProfile` es **un personaje** de la cuenta
(`account.json`, hasta 8, docs/specs/characters.md): la sesión carga y
guarda el personaje elegido. Créditos, pociones, nivel, árbol y filtro
de loot son de cada personaje; las armas y los materiales se pueden
pasar entre personajes por el **alijo compartido** (los créditos no:
cada personaje hace su propia economía).

La persistencia es una interfaz (`ProfileStore`: `load` / `save`); la
implementación con disco o `shared_preferences` vive fuera de
`game_engine`. `InMemoryProfileStore` sirve para tests.

## Niveles

- Nivel máximo **50** (`ProgressionRules.maxLevel`).
- XP para pasar del nivel `l` al siguiente (`xpNeed`):
  - `l ≤ 10`: `10 + l² × 8` (la curva del prototipo: 18, 42, …, 810).
  - `l ≥ 11`: `round(32 × xpFactor(l) × (11 + 0.36 × (l − 10)))`, con
    `xpFactor(n) = 1 + 0.15 × (n − 1)`: la XP por batalla esperada en
    una zona de nivel `l` (grupo típico de 32 XP, escalado por el nivel
    de los enemigos) por ~11 batallas en el 11 hasta ~25 en el 49.
    Ejemplos: 909 (11), 3116 (30), 6570 (49).
  - Ritmo: del 10 al 50 son ~700 batallas (~70 misiones de 10 grupos).
  - Mundo por zonas (v0.2.0): la XP de cada batalla se multiplica por
    `ZoneRules.xpMult(nivel) = xpFactor(nivel) × bonus del mundo`
    (worldgen.md § 6.3); ~nivel 25 en unas 10 misiones de zona.
- `gainXp`: suma la XP y mientras alcance resta `xpNeed(nivel)`, sube
  1 nivel y da `+3` puntos de atributo (`PTS_LVL`), hasta el 50 (la XP
  sobrante se guarda). El árbol gana 1 punto por nivel (passive_tree.md).
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
deja de cumplir requisitos, equipa la inicial. En la sesión, en lobby o
preparación llena vida y maná; en otro modo solo recorta al máximo nuevo.

### Reiniciar (decisión temporal del dueño)

"Reiniciar puntos gratis siempre (por ahora)": con
`ProgressionRules.freeRespec = true` (hoy) reiniciar los puntos de
atributo (`RespecAction`) y el árbol (`ResetTreeAction`) no cuesta nada y
se puede en cualquier modo **salvo en batalla** (para no cambiar los
stats en medio del estado de combate): `ProgressionRules.canRespec`. Los
botones dicen `(GRATIS)`. Con `false` vuelve la regla del prototipo:
solo en lobby / preparación.

`changeClass`: árbol vacío, arma inicial de la nueva clase y
`resetBuild` (mantiene nivel, XP, créditos e inventario).

## Armas

- `canEquip`: **cualquier clase** (loot.md § 0.2), nivel `≥` al de la
  base y cada atributo `≥` al requisito. La clase define atributos base,
  kit, inicio del árbol y arma inicial; las habilidades y la ULT vienen
  del arma.
- `equip`: debe tenerla (`uid` o base) y poder equiparla.
- `buyWeapon`: cualquier base con precio `> 0` que no tenga, si le
  alcanzan los créditos y hay una casilla libre; llega Común. Se puede
  comprar sin cumplir requisitos.
- Consumibles (`buyItem`): Poción de vida 30, Poción de maná 40; máx. 9
  de cada una.

## Herrería (`upgrade`)

Estadísticas mejorables (`upgradeStatsFor`): Poder (+12% ATQ y MAG por
nivel), Crítico (+2%), Velocidad (+0.3) y, si el arma tiene escudo,
Defensa (+1). Máx. nivel 5 por estadística y tope total según la
rareza (Común 3, Mágico 5, Raro 6, Épico 8, Legendario 10); cada 2
niveles totales sube la pasiva del arma. Cualquier arma propia. Costo
del nivel `l → l+1`:

```
upCost(arma, l) = round(max(precio, 200) × 0.22 × (l + 1) × rareza)
```
(factor de rareza: 1 / 1.2 / 1.5 / 2 / 3; Común = el del prototipo).

Nombre con mejoras (`weaponDisplayName`): `"Nombre +N"` con `N` = suma
de niveles.

## Fusión (`fuse`, ₵200)

Ahora es la operación "trasladar habilidad" de la fusión libre
(loot.md § 16): el arma `a` aprende una habilidad `sk` de `b`, que se
consume. Requisitos: `a ≠ b`, ambas propias, `b` no es la equipada ni la
última del arma inicial, `sk` es de `b` (de su base o trasladada) y le
alcanzan los créditos (₵200 × rareza de `a`). Con los cupos llenos (1
hasta Raro, 2 en Épico / Legendario) reemplaza a la más vieja.
Habilidades de un arma en combate (`weaponSkills`): kit de clase +
habilidades del arma + las trasladadas (si no estaban).

## Árbol de pasivas

`takeNode` (`PassiveTreeRules.canTake`) y `resetTree` (vacía la lista;
gratis, ver § "Reiniciar").
Al tomar un nodo, vida y maná actuales suben lo que suba el máximo; al
reiniciar se recortan al máximo nuevo. Ver passive_tree.md.

## UI

Los paneles y botones que mandan estas acciones están en
docs/specs/panels.md; el autoguardado cada 2 s lo hace
`SessionController` (exploration.md § "Controlador de sesión").
