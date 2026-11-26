# Spec: Loot con modificadores y filtros (loot v2)

Pedido del dueño: "que el loot sea como en los ARPG, que se puedan crear filtros,
que las armas tengan modificadores". Se toman las **mecánicas** del género
(bases + afijos aleatorios por rareza, filtros de loot editables); nombres,
textos y contenido son propios de Ecos del Tiempo.

Estado: diseño aprobado por el dueño (decisiones en § 7 y § 0). Motor
implementado (Parte 2, § 8–20: datos exactos, reglas, API). Paneles
implementados (panels.md § "Inventario", "Armería" loot v2, "Filtro de
loot", "Resultado de misión"); el loot en el mapa es de la fase del
mapa. El filtro se edita como **texto** en esta versión; el **editor
visual** de reglas (§ 6: lista con ▲▼, agregar, duplicar, borrar) queda
para la **próxima versión**.

## 0. Revisión 2 (decisiones del dueño, mandan sobre el resto)

Pedido: nivel máximo 50, muchas más armas, armas con pasivas que crecen
al mejorarlas, fusión libre, "que cada uno se arme como quiera, sin
tanta restricción, como en los ARPG de loot".

1. **Nivel máximo 50** (`ProgressionRules.maxLevel = 50`). El contenido
   1–50 lo dan las zonas del mundo nuevo (worldgen.md: cada zona con su
   rango de nivel; las misiones del mostrador se generan según el nivel
   del grupo). La curva de XP se recalibra para llegar a 50.
2. **Armas libres por requisitos**: cualquier clase equipa cualquier arma
   si cumple sus requisitos de atributos. La clase define atributos base,
   kit de habilidades, ULT preferida (no: la ULT sigue al tipo de arma) y
   dónde arranca en el árbol. Las habilidades vienen del arma.
3. **~80 bases** (unas 20 por "familia" de clase, repartidas en los
   niveles 1–50): las 32 actuales se conservan y se agregan bases nuevas
   y tipos nuevos donde haga falta (p. ej. lanza, dagas, varita,
   ballesta pesada). Cada base: nivel requerido, requisitos, fórmula
   ATQ/MAG, peso, habilidades, **implícito** y, desde Épico, **pasiva de
   arma**.
4. **5 rarezas** (reemplaza la tabla de § 2):

| Rareza | Mods | Pasiva de arma | Color |
|---|---|---|---|
| Común | 0 | — | blanco |
| Mágico | 1–2 | — | azul |
| Raro | 3–4 | — | amarillo |
| Épico | 5–6 | 1 pasiva aleatoria del pool del tipo de arma | violeta |
| Legendario | fijos + 1–2 aleatorios | pasiva única diseñada a mano | naranja |

   Probabilidad base al soltar: Común 60%, Mágico 27%, Raro 10%, Épico
   2.7%, Legendario 0.3%, modificada por nivel de zona, élites y jefes.
   Fuera de un Eco el Épico pesa 1.5 en vez de 2.7 (v0.15,
   materials_economy.md § 4.1).
5. **Pasivas de arma**: efectos mecánicos usando el mismo sistema de
   disparadores del árbol v2 (`PassiveMechanic`), p. ej. "al atacar
   golpea también a un 2.º enemigo al 40%", "al aplicar Congelación,
   +1 stack", "al curar, el objetivo gana un escudo", "golpear a un
   enemigo congelado lo quiebra un 20% más". Tienen **niveles** (I–V).
6. **Mejorar armas (forja)**: cada mejora sube stats (como hoy) **y**,
   cada 2 niveles de forja, sube un nivel la pasiva del arma si tiene.
   Tope de forja según rareza (Común 3 … Legendario 10).
7. **Fusión libre** (reemplaza la fusión de habilidades actual y amplía
   § 5): en la mesa de fusión se puede
   - **trasladar** un mod, una pasiva o una habilidad de un arma
     (que se destruye) a otra;
   - **quitar** un mod que no se quiere;
   - **agregar** un mod con materiales;
   - **subir rareza** (amplía los cupos de mods).
   El arma destino respeta los cupos de su rareza; el costo crece con el
   nivel del mod y la rareza. Vista previa del resultado antes de
   confirmar (principio de UX de ui_style.md).

## 1. Bases

- Las 32 armas actuales (`WEAPONS`) pasan a ser **bases** (ver § 0.3
  para las nuevas): tipo, requisitos, fórmula ATQ/MAG, peso, escudo y
  habilidades se conservan; el campo de clase deja de restringir.
- Cada base tiene **nivel requerido** y puede traer un **implícito** fijo
  (p. ej. escudos: +DEF; arcos: +crítico).
- Una instancia de arma (`ItemInstance`) guarda: base, rareza, nivel de
  objeto, lista de afijos con sus valores tirados, pasiva y su nivel,
  mejoras de forja y habilidades trasladadas. El inventario pasa de
  lista de ids a lista de instancias (el perfil viejo se migra: cada id
  → instancia Común).

### 1.1 Peso y categorías de peso (v0.8.4)

- `WeaponDef.weight` resta velocidad 1:1: `VEL = 6 + AGI×0.5 + DES×0.1 −
  peso` (+ forja, afijos y árbol; `StatsCalculator`). Menos VEL = el turno
  llega más tarde (`BattleEngine.interval` = 100 / VEL). Se edita en el
  balance (`Peso (−velocidad)`, 0–10, paso 0.1).
- **Categoría** (`WeightClass`, `weightClassOf(weapon)` en
  `game_engine/rules/weapon_weight.dart`), derivada del peso, nunca
  guardada ni enviada por red (un cambio de balance la mueve sola):

  | Categoría | Peso | Trade-off (ficha) |
  |---|---|---|
  | **Ligera** | 0 | `sin penalización de velocidad` |
  | **Media** | 0 < peso < 0.8 | `−N vel. · algo más lenta a cambio de poder` |
  | **Pesada** | ≥ 0.8 (`kHeavyWeightFrom`) | `−N vel. · suele dar más ATQ` |

- Cortes elegidos sobre el catálogo v0.8.4 (94 bases): 42 con peso 0
  (espadas cortas, báculos, arcos, varitas, dagas, espada+escudo); 30
  entre 0.3 y 0.6 (Espada Ígnea, tomos 0.4–0.5, lanzas 0.5, maza+escudo
  0.4–0.6, rifles 0.5–0.6); 22 de 0.8 a 1.5 (rifles 0.8–0.9, mandobles
  1.0, martillo+escudo 1.0–1.4, ballestas 1.1–1.3, hachas 1.3–1.5). No hay
  bases entre 0.6 y 0.8: el corte cae en ese hueco.
- Dónde se ve: panels.md § "Peso del arma (v0.8.4)". Filtro de loot:
  condición `Peso Ligera|Media|Pesada` (§ 13).

## 2. Rarezas

Ver § 0.4 (5 rarezas).

## 3. Afijos

- **Prefijos** (ofensivos/base): % ATQ, % MAG, daño plano, % crítico,
  multiplicador de crítico, velocidad, stacks extra de Quemadura /
  Veneno / Congelación al aplicar, carga de ULT.
- **Sufijos** (atributos/defensa): +VIT/ESP/AGI/FUE/DES, +vida, +maná,
  +DEF, % curación recibida, regeneración por turno, resistencia a
  estados (menos stacks recibidos), robo de vida.
- Cada afijo tiene **tiers** por nivel de objeto (p. ej. % ATQ: T5 5–9%
  nivel 1, ..., T1 35–40% nivel 30) y un **peso** de aparición; algunos
  solo salen en ciertos tipos de arma (stacks de Congelación: báculos,
  tomos, rifles; DEF: escudos).

### 3.1 Cómo se muestran (v0.20.19)

En toda ficha de arma (tooltip del inventario, ficha completa) y en la
forja / fusión los mods van agrupados por lado, con el mismo texto
(`affixGroupsMarkup`, `lib/features/inventory/domain/item_text.dart`):

- Línea `PREFIJOS (ataque) n/tope` y debajo sus mods; después
  `SUFIJOS (atributos y defensa) n/tope`. `tope` =
  `Rarity.affixSideCap` (la mitad del cupo, redondeado arriba). Si la
  rareza no lleva mods y no tiene ninguno, no hay título.
- En las listas de la forja (traer mod, quitar mod) cada mod lleva
  delante su etiqueta `PREFIJO ·` / `SUFIJO ·`.
- El `[?]` de los mods de la forja explica, en castellano llano, qué va
  en cada lado, cuántos entran según la rareza y que al agregar o traer
  un mod tiene que quedar lugar de su lado (`affixSidesHelp`).
- Traer mod: en la lista de mods del arma de origen, los que no se pueden
  traer a esta arma van en gris (`CraftRules.transferAffixBlock`: fijo
  de un legendario, no sale en ese tipo de arma, ya lo tiene, sin lugar
  en total o de su lado). El motivo sale en tooltip salvo el obvio (ya
  lo tiene). Se pueden elegir igual para ver el motivo en el paso de
  confirmar.
- Los afijos se aplican en `StatsCalculator` en un paso nuevo, **antes**
  del árbol de pasivas, y aparecen en el desglose del log de combate
  ("ATQ 21 = base 15 + 40% arma").

## 4. Fuentes de loot

- Enemigos al morir (por grupo), cofres, élites y jefes.
- **Loot por jugador** (instanciado): cada jugador ve y recoge su propio
  loot, sin peleas en co-op.
- El loot cae en el mapa como objeto con su nombre visible (según el
  filtro), se recoge caminando encima o con E.

## 4b. Inventario y dar objetos a otros jugadores

Inventario de casillas por personaje, al estilo de los RPG de grupo
donde cada miembro carga lo suyo y se lo puede pasar a otro:
- Grilla de casillas (p. ej. 8×5) por jugador; cada objeto ocupa 1
  casilla; materiales de crafteo y pociones se apilan.
- Panel de inventario con el propio a la izquierda y, con pestañas, el
  de cada compañero de sala a la derecha.
- **Dar**: arrastrar un objeto del propio inventario al de un compañero
  (o botón "Dar a..."). Llega al instante si el otro tiene lugar; si no,
  se rechaza con el motivo. No hace falta estar cerca.
- Solo se puede dar fuera de batalla. El host valida (`GiveItemAction`),
  como todas las acciones.
- Se puede soltar un objeto al piso; queda visible para todos y lo
  levanta cualquiera (única forma de loot compartido).
- Ver el inventario de un compañero es solo lectura: no se le puede
  sacar nada.

### 4b.1 Nada propio se pierde (v0.20.11, protocolo 33)

Bug corregido: un Legendario de jefe con el inventario lleno caía al
piso; la misión terminaba, se volvía al pueblo y el piso se vaciaba con
el arma adentro. Regla: **un jugador nunca pierde loot que era suyo**.

- Al cerrarse el mapa (empezar misión / Eco / Prueba / Abismo desde el
  pueblo, volver al pueblo al terminar o abandonar), antes de vaciar el
  piso, el host recorre **todos los pisos** (`SessionEngine._recoverGround`):
  - lo **propio** (`GroundLoot.ownerId`) que el filtro del dueño muestra
    vuelve a ese jugador;
  - lo **compartido** que alguien soltó (`GroundLoot.byId`, quién lo
    soltó) y nadie levantó vuelve a quien lo soltó;
  - lo oculto por el filtro del dueño también vuelve (v0.20.17, protocolo
    37), pero directo a **Objetos sin recoger** (`StashAck.box`, `bx` en
    el JSON) para no llenar el alijo de cosas que eligió no ver;
  - solo lo de alguien que ya no está en la sala se descarta en el host
    (su dispositivo ya lo guardó al salir, ver abajo).
- v0.20.22 (protocolo 39): al **volver al pueblo** (`toLobby`) ya no se
  recupera nada al alijo de cada uno: todo lo del piso va al pozo
  compartido Loot perdido de la sala (missions.md § "Loot perdido"),
  que se borra al empezar la próxima misión. Lo de arriba sigue valiendo
  al empezar una misión desde el pueblo (lo tirado en el pueblo), en el
  tope del piso y al salir de la sala. Se mantienen el botín valioso de
  jefe / élite directo al alijo con el inventario lleno (§ 14.3) y la
  caja Objetos sin recoger.
- Cambiar de piso por la escalera no pierde nada: cada objeto queda en su
  piso (§ 14.1) y lo que quede se recupera al cerrarse el mapa.
- Si el piso llega a su tope (80), el objeto más viejo sale y, si era de
  alguien, también vuelve a él.
- "Vuelve" = confirmación del host `rec:N` en `SessionPlayer.stashAcks`
  (`StashAck.recoverPrefix`, `put: true`, las piezas): viaja en el
  snapshot (`sk`) como las del alijo en partida (characters.md § 3.2).
  El dispositivo que controla a ese jugador (él mismo, o el líder de un
  compañero, solo_party.md) la guarda en **su** alijo de cuenta
  (`StashRules.recover`): al alijo si entra (pestaña según el tipo); si
  no, a **Objetos sin recoger**. Aviso local por pieza: `<objeto> se
  guardó en el alijo` / `… en Objetos sin recoger`.
- Bug corregido en v0.20.17: hasta v0.20.16 un arma o Eco cuyo uid ya
  estaba en el alijo o en la caja se tomaba como duplicado y se
  descartaba en silencio. Pero el loot tirado trae el uid provisorio
  `nuevo` (`LootRules.newUid`, el perfil asigna el real al recibirlo) y
  los uid `i<n>` se repiten entre personajes: la segunda arma recuperada
  (y todas las siguientes) se perdía. Ahora `StashRules.recover` nunca
  descarta: si el uid ya está, la pieza se guarda con uno nuevo (`r<n>`).
  No hace falta deduplicar: el host saca del piso lo que recupera en el
  mismo snapshot que lleva la confirmación, y al salir el host saca lo
  del que se fue (`removePlayer`), así que nunca se guarda dos veces.
- Desconexión / salir de la sala / cerrar el juego: el dispositivo que
  sale guarda en su cuenta lo suyo que estaba en el piso según el último
  estado (`SessionController._recoverLocalGround`, incluido lo que su
  filtro oculta, a Objetos sin recoger); el host, al ver la
  salida, saca ese loot del piso (`removePlayer`), así no queda doble.
- Travesía: no hay alijo ni piso (las acciones de piso están cerradas,
  `runGate`); `_recover` no hace nada con una run activa y la entrega de
  recompensas de la run no cambia.

### 4b.2 Objetos sin recoger

Caja por cuenta (`Stash.unclaimed`, JSON aditivo `uncl` dentro del
alijo: un alijo viejo sin el campo carga con la caja vacía). Sin tope.
Se ve en el ALIJO (en partida y fuera de ella) debajo del tablero, solo
si tiene algo, con el título `OBJETOS SIN RECOGER` y la cantidad. Cada
fila: `TOMAR` (al inventario; en partida pasa por el host como
`stashTake`, entera o, un material, lo que entre) y `DESCARTAR`
(solo local). Con una operación en curso los botones quedan grises.

## 4c. Botín en el piso fuera de las mazmorras (protocolo 96, 104)

Los exteriores (biomas, minas) y el pueblo usan el **mismo** sistema de
piso que las mazmorras: `GroundLoot` instanciado (`ownerId` = quien lo
ganó: solo él lo ve y lo levanta), auto-levantar al pasar encima
(`pickupRange`) o `pickUp` con E (`pickReach`), y `LootPickedEvent` →
aviso `+` a la izquierda. El host decide todo.

- **Bienes** (`LootDrop.goods`, JSON `{gd, n}`; `GoodsRules`): lo que no
  ocupa casilla del inventario: `gold` (oro), `ore:<id>` (menas,
  lingotes, raros), `crop:<id@calidad>`, `seed:<id>`, `wseed:<id>`,
  `bait:<id>`, `fert:<id>`. Siempre entran (cada uno a su bolsa) y el
  filtro nunca los oculta; color dorado.
- **Quién derrama**: cofre de bioma (sobre el cofre), santuario/fuente
  (una casilla delante), cofre y cofre reliquia de mina (sobre el
  cofre), cofre hundido pescado desde tierra (a los pies; desde una
  balsa entra directo con aviso), matas recolectadas y búsqueda en árboles (sobre la mata / árbol). Armas
  y pilas pasan por `_deliver` con `LootSource.chest` (filtro y topes de
  siempre).
- **El cultivo no derrama** (protocolo 104): todo lo que sale de sembrar
  y cosechar (cultivo, semillas, semillas de arma, armas vivas, ecos,
  materiales, rarezas) entra directo al inventario del que cosechó, donde
  sea que se cultive (`_Op._farming`). Inventario lleno: la regla que ya
  existía para el botín del pueblo (`stashOverflow`, fishing.md § 8.4):
  lo que ocupa casilla va al alijo y, si no entra, a Objetos sin recoger
  (§ 4b.1 / 4b.2); nunca al piso. Los bienes siempre entran. La cosecha
  automática de los ayudantes sigue yendo a su cofre.
- **Imán**: los bienes recolectados (todo menos `gold` y `ore`) se
  levantan solos dentro de `magnetRange` (40 px); el oro y el mineral
  esperan en el piso como el botín de un cofre.
- Un compañero (o un motor sin `groundLoot`) los recibe directo, con
  aviso.
- **Cerrar el mapa** (viajar a otro lugar, empezar una misión, volver de
  una misión): lo no levantado vuelve a su dueño como siempre (§ 4b.1);
  los bienes no tienen lugar en el alijo y entran directo a sus bolsas.

## 4d. Avisos de lo que entra solo

Dos lugares anuncian loot: el **registro** encima del chat
(`Ana encontró: <objeto>`, todos los `LootDropEvent` visibles) y los
**avisos del filtro** (abajo al centro, con el estilo del filtro).

- **Entra solo** (`GoodsRules.autoPickup`, única regla): un bien
  (`LootDrop.goods`: cosechas, semillas, menas, cebos, abono, oro…) que
  entra directo al inventario (sin `groundId`: compañero, balsa, motor
  sin `groundLoot`) o que, en el piso, levanta el imán (todo menos
  `gold` y `ore`). Solo sale en el registro; **nunca** con aviso del
  filtro, ni al caer ni al levantarse.
- **Botín silencioso** (`GoodsRules.quiet`, protocolo 104): en el
  **pueblo** (incluido el interior de la tienda) no hay avisos del
  filtro para nada, ni el Legendario: solo el registro. Lo mismo para
  todo lo que da el **cultivo**, donde sea. El host lo decide y lo marca
  en el evento (`LootDropEvent.quiet` / `LootPickedEvent.quiet`, JSON
  `q`); `GoodsRules.toast` es la única regla que usa el registro.
- Mazmorras y exteriores no cambian: lo que es loot sigue siendo loot
  (piso con su aviso del filtro).
- Lo demás sigue igual: armas, equipo, ecos y pilas que entran directo
  tienen su aviso `+`; el Legendario siempre su aviso; el oro y el
  mineral que esperan en el piso tienen su `+` al levantarlos; dar un
  objeto avisa al que lo recibe.
- Las menas picadas en la mina (`MineDugEvent`) no pasan por el loot.
- Multijugador: cada cliente aplica la misma regla a los mismos eventos
  del host (`groundId`, el drop y `q` viajan).

## 5. Crafteo

Tres materiales que también caen como loot.
- **Esquirla del Eco**: vuelve a tirar los valores de los afijos.
- **Cristal de Era**: agrega un afijo (si hay lugar).
- **Prisma Roto**: sube la rareza un nivel (Común → Mágico → Raro →
  Épico, ver § 16).
- **Condensar** (solo Mundo, mesa de fusión, materials_economy.md §
  4.3): 20 Esquirlas + ₵100 → 1 Cristal; 8 Cristales + ₵500 → 1 Prisma.
  Solo hacia arriba, sin azar, por lotes (×1 / ×5 / MÁX), ajustable en
  el Editor → Balance (grupo Condensar).

La forja (mejoras por stat) se mantiene con tope por rareza; la fusión de
habilidades pasa a ser una operación de la fusión libre (§ 16).

## 6. Filtros de loot

- El jugador crea **reglas** en orden; gana la primera que coincide.
- Condiciones: rareza, clase/tipo de arma, base, nivel de objeto ≥ / ≤,
  "tiene afijo X (tier ≤ N)", cantidad de afijos, material de crafteo,
  "sirve para mi clase".
- Acciones: **mostrar / ocultar**, color del texto, color del borde, color
  de fondo, tamaño del texto, sonido (de un catálogo) y un ícono en el
  minimapa.
- Se editan en un panel del juego (lista de reglas con ▲▼, agregar,
  duplicar, borrar) y se guardan en el perfil.
- Formato de texto exportable/importable para compartirlo, p. ej.:

```
Mostrar
  Rareza >= Rara
  Clase Guerrero
  Color 255 210 60
  Sonido alerta
Ocultar
  Rareza Normal
  NivelObjeto < 10
```

- Filtro por defecto incluido (oculta Normales de nivel bajo, resalta
  raras y únicas).

## 7. Decisiones del dueño

1. Loot **por jugador**, con inventario de casillas por personaje y la
   posibilidad de **dar objetos** a otros jugadores (§ 4b).
2. Crafteo **sí**, con los 3 materiales de § 5.

Valores por defecto (cambiables): la tienda sigue vendiendo bases
Normales; 2 únicas por clase para empezar.

---

# Parte 2: datos exactos e implementación del motor (loot v2)

Implementado en `lib/game_engine/` (UI pendiente). Lo que sigue manda
sobre los ejemplos de § 1–6 cuando difieren.

Código:
- Modelos: `models/item.dart` (`ModStat`, `ItemMod`, `AffixDef`,
  `AffixTier`, `Rarity`, `AffixRoll`, `ItemInstance`, `UniqueDef`,
  `CraftMaterial`, `CraftOp`), `models/loot.dart` (`LootSource`,
  `StackKind`, `LootDrop`, `GroundLoot`), `models/loot_filter.dart`,
  `models/weapon_passive.dart`, `models/weapon.dart` (`level`,
  `implicit`).
- Datos: `data/weapons_catalog.dart` (80 bases), `data/skills_catalog.dart`
  (10 habilidades y 4 ULT nuevas), `data/affixes_catalog.dart`,
  `data/weapon_passives.dart`, `data/uniques_catalog.dart`.
- Reglas: `rules/item_rules.dart`, `rules/loot_rules.dart`,
  `rules/inventory_rules.dart`, `rules/craft_rules.dart`,
  `rules/loot_filter_rules.dart`, `rules/stats_calculator.dart`,
  `rules/progression_rules.dart`, `rules/session_engine.dart`.
- Tests: `test/game_engine/loot_*_test.dart`.

## 8. Bases

80 bases, 20 por familia (`classId` = familia; **no restringe**):
las 32 del prototipo con su nivel (tier 0 → 1, 1 → 2, 2 → 4, 3 → 7) y
48 nuevas entre los niveles 2 y 50. Requisito para equipar: nivel de
personaje ≥ nivel de la base y atributos ≥ requisitos (los atributos que
da el propio arma no cuentan). La tienda vende cualquier base con precio
> 0 que no se tenga (Común, sin pedir requisitos ni nivel).

Fórmulas de las bases nuevas (nivel `L`, redondeos al entero):
- Requisito principal `8 + 1.05·L`, secundario `5 + 0.5·L`.
- Físicas: ATQ `6 + 0.95·L` (+10% hacha, +5% rifle, +15% ballesta, −10%
  dagas) `+ (0.6 + 0.01·L)·principal` (+0.15 hacha, +0.05 arco, +0.1
  rifle, −0.05 dagas) `+ 0.2–0.35·secundario`.
- Mágicas: ATQ `3 + 0.1·L + 0.3–0.4·FUE`; MAG `5 + 0.95·L` (+10% tomo,
  −10% varita) `+ (0.75 + 0.01·L)·ESP` (−0.05 varita).
- Escudos: ATQ bajo, MAG `4 + 0.7–0.75·L`, DEF de escudo 1–8.
- Precio `100·L + 4·L²`.
- Implícito por tipo (nivel < 25 / ≥ 25): espada +3/5% crítico, hacha
  +6/10% ATQ, lanza +0.3/0.5 velocidad, báculo +6/10% MAG, tomo +8/12%
  carga de ULT, varita +8/15 maná, arco +3/5% crítico, rifle +10/15%
  daño crítico, ballesta +15/22% daño crítico, dagas +5/7% crítico. Las
  armas con escudo tienen su DEF de escudo como implícito. Las 32 del
  prototipo no traen implícito extra (sus números no cambian).

### 8.1 Tipos nuevos, habilidades y ULT

| Tipo | Familia | Rol | ULT |
|---|---|---|---|
| lanza | guerrero | rápida (+vel), alcance | Lluvia de Lanzas: físico ×1.7 a todos, retrasa 0.4 |
| varita | maga | liviana, MP | Tormenta Arcana: mágico ×1.9 a todos, +20% crítico |
| ballesta | tirador | pesada, golpe único | Andanada: físico ×3.2, Aturdido 1 |
| dagas | tirador | crítico | Danza de Mil Cortes: físico ×2.8, +50% crítico |

Habilidades nuevas (`kSkills`): Lanza Perforante (4 MP, físico ×1.7,
+20% crít.), Barrido de Lanza (5, físico ×1.0 a todos, retrasa 0.2),
Empalar (6, físico ×2.1, 25% Aturdido), Misil Arcano (2, mágico ×1.4,
+15% crít.), Escarcha Fugaz (4, mágico ×1.2, Congelación 1, retrasa 0.2),
Rayo Arcano (6, mágico ×2.2), Virote Pesado (5, físico ×2.2, retrasa 0.4),
Virote Ígneo (5, físico ×1.8, Quemadura 2), Tajo Gemelo (3, físico ×1.3,
+30% crít.), Abanico de Dagas (6, físico ×0.8 a todos, Veneno 2). Las
demás bases nuevas reusan habilidades del catálogo. Cada habilidad nueva
tiene su firma de sonido (`lib/core/audio/sfx_recipes.dart`).

Las 4 ULT nuevas viven en `kNewUltimates`; el motor usa `kAllUltimates`
(= `kUltimates` + nuevas). **UI**: el menú de batalla, la cinemática
(`kUltScripts`), los colores y el sonido (`kUltVoices`) leen
`kAllUltimates`, así que las 4 ya funcionan (docs/specs/
battle_presentation.md § "Guiones"). Moverlas a `kUltimates` es solo
orden (no cambia nada en la UI).

### 8.2 Tabla de bases

| id | Nombre | Familia | Tipo | Nv | Requisitos | ATQ | MAG | Peso | DEF | Habilidades | Implícito | Precio |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `espada_bronce` | Espada de Bronce | guerrero | espada | 1 | FUE 8 | 6.0 + 0.6·FUE + 0.2·DES | — | — | — | Corte Giratorio, Embestida | — | 0 |
| `espada_ignea` | Espada Ígnea | guerrero | espada | 2 | FUE 14, DES 8 | 10.0 + 0.6·FUE + 0.3·DES | — | 0.3 | — | Golpe Ígneo, Corte Giratorio | — | 300 |
| `hacha_rompe` | Hacha Rompeturnos | guerrero | hacha | 4 | FUE 18 | 16.0 + 0.85·FUE | — | 1.5 | — | Golpe Sísmico, Rompearmaduras | — | 650 |
| `mandoble_eco` | Mandoble del Eco | guerrero | espada | 7 | FUE 22, DES 12 | 22.0 + 0.8·FUE + 0.4·DES | — | 1.0 | — | Tajo Temporal, Corte Giratorio, Reto Escudado | — | 1400 |
| `espada_carmesi` | Espada Carmesí | guerrero | espada | 4 | FUE 15, DES 12 | 13.0 + 0.55·FUE + 0.4·DES | — | — | — | Tajo Carmesí, Sifón Vital | — | 660 |
| `hacha_tormenta` | Hacha de la Tormenta | guerrero | hacha | 7 | FUE 21 | 21.0 + 0.85·FUE | — | 1.4 | — | Vendaval Helado, Rugido Intimidante | — | 1450 |
| `mandoble_ocaso` | Mandoble del Ocaso | guerrero | espada | 7 | FUE 20, DES 14 | 22.0 + 0.7·FUE + 0.4·DES | — | 1.0 | — | Tajo del Ocaso, Embestida | — | 1500 |
| `katana_escarcha` | Katana de Escarcha | guerrero | espada | 2 | FUE 12, DES 10 | 9.0 + 0.5·FUE + 0.4·DES | — | — | — | Corte Glacial, Embestida | — | 350 |
| `hacha_volcanica` | Hacha Volcánica | guerrero | hacha | 4 | FUE 17, ESP 8 | 15.0 + 0.8·FUE | — | 1.3 | — | Erupción, Golpe Debilitante | — | 720 |
| `baculo_aprendiz` | Báculo de Aprendiz | maga | báculo | 1 | ESP 8 | 3.0 + 0.4·FUE | 5.0 + 0.75·ESP | — | — | Chispa, Cura | — | 0 |
| `baculo_fuego` | Báculo de Fuego | maga | báculo | 2 | ESP 14 | 4.0 + 0.4·FUE | 7.0 + 0.8·ESP | — | — | Bola de Fuego, Llamarada | — | 300 |
| `baculo_escarcha` | Báculo de Escarcha | maga | báculo | 4 | ESP 16, AGI 9 | 4.0 + 0.4·FUE | 10.0 + 0.85·ESP | — | — | Lanza de Hielo, Brotes de Vida | — | 650 |
| `tomo_tiempo` | Tomo del Tiempo | maga | tomo | 7 | ESP 22 | 3.0 + 0.3·FUE | 14.0 + 1.0·ESP | 0.5 | — | Detener, Impulso Temporal | — | 1400 |
| `baculo_rayo` | Báculo del Rayo | maga | báculo | 4 | ESP 16, DES 10 | 3.0 + 0.4·FUE | 11.0 + 0.85·ESP | — | — | Descarga, Semilla Vital | — | 680 |
| `tomo_plaga` | Tomo de la Plaga | maga | tomo | 4 | ESP 17 | 3.0 + 0.3·FUE | 10.0 + 0.85·ESP | 0.4 | — | Plaga, Lentitud | — | 700 |
| `baculo_ponzona` | Báculo de Ponzoña | maga | báculo | 2 | ESP 12, DES 8 | 3.0 + 0.4·FUE | 7.0 + 0.8·ESP | — | — | Drenar Vida, Rocío Sanador | — | 350 |
| `tomo_infernal` | Tomo Infernal | maga | tomo | 7 | ESP 21 | 3.0 + 0.3·FUE | 14.0 + 1.0·ESP | 0.5 | — | Infierno, Maldición | — | 1500 |
| `arco_corto` | Arco Corto | tirador | arco | 1 | DES 8 | 5.0 + 0.6·DES + 0.2·FUE | — | — | — | Flecha Venenosa, Ráfaga, Disparo Certero | — | 0 |
| `rifle_aturdidor` | Rifle Aturdidor | tirador | rifle | 2 | DES 12, FUE 8 | 9.0 + 0.55·DES + 0.3·FUE | — | 0.5 | — | Disparo Aturdidor, Ráfaga Triple | — | 300 |
| `arco_tormenta` | Arco Tormenta | tirador | arco | 4 | DES 16, AGI 12 | 12.0 + 0.7·DES + 0.2·AGI | — | — | — | Flecha Rayo, Lluvia de Flechas, Flecha Marcadora | — | 650 |
| `rifle_ocaso` | Rifle del Ocaso | tirador | rifle | 7 | DES 22 | 20.0 + 0.85·DES | — | 0.8 | — | Tiro Perforante, Bala Traspasante, Cadencia Letal | — | 1400 |
| `arco_sombra` | Arco de Sombra | tirador | arco | 4 | DES 16 | 12.0 + 0.65·DES | — | — | — | Flecha Sombría, Flecha Sanadora | — | 680 |
| `rifle_glacial` | Rifle Glacial | tirador | rifle | 7 | DES 21, FUE 10 | 19.0 + 0.8·DES | — | 0.9 | — | Cero Absoluto, Disparo Cargado | — | 1450 |
| `arco_solar` | Arco Solar | tirador | arco | 7 | DES 20, AGI 14 | 18.0 + 0.75·DES | — | — | — | Flecha Solar, Ojo de Águila | — | 1450 |
| `ballesta_glacial` | Ballesta Glacial | tirador | arco | 2 | DES 12, AGI 10 | 9.0 + 0.6·DES | — | — | — | Saeta Glacial, Flecha de Escarcha | — | 350 |
| `rifle_pestilente` | Rifle Pestilente | tirador | rifle | 4 | DES 15, FUE 9 | 12.0 + 0.6·DES + 0.2·FUE | — | 0.6 | — | Metralla Tóxica, Bala Corrosiva, Disparo Certero | — | 720 |
| `espada_escudo_novato` | Espada y Escudo de Novicio | paladin | espada+escudo | 1 | FUE 5 | 6.0 + 0.4·FUE ³ | 4.0 + 0.6·ESP | — | — | Estocada Firme, Golpe de Escudo, Sanación ¹ | — | 0 |
| `maza_escudo_roble` | Maza y Escudo de Roble | paladin | maza+escudo | 2 | FUE 7, VIT 16 | 4.0 + 0.3·FUE ³ | 5.0 + 0.65·ESP | 0.4 | 3 | Golpe de Escudo, Sanación | — | 320 |
| `martillo_escudo_hierro` | Martillo y Escudo de Hierro | paladin | martillo+escudo | 2 | FUE 10 | 6.0 + 0.4·FUE | 4.0 + 0.5·ESP | 1.0 | — | Aplastar, Conmoción | — | 340 |
| `espada_escudo_alba` | Espada y Escudo del Alba | paladin | espada+escudo | 4 | FUE 9, ESP 13 | 5.0 + 0.3·FUE | 8.0 + 0.8·ESP | — | 1 | Lanza de Luz, Égida Espinosa | — | 680 |
| `maza_escudo_bastion` | Maza y Escudo Bastión | paladin | maza+escudo | 4 | VIT 20, ESP 11 | 3.0 + 0.2·FUE | 7.0 + 0.75·ESP | 0.6 | 5 | Provocar, Escudo de Fe | — | 700 |
| `martillo_escudo_juicio` | Martillo y Escudo del Juicio | paladin | martillo+escudo | 7 | FUE 16, VIT 18 | 12.0 + 0.6·FUE | 6.0 + 0.6·ESP | 1.4 | — | Martillo del Juicio, Golpe Sagrado, Golpe Debilitante | — | 1450 |
| `lanza_hierro` | Lanza de Hierro | guerrero | lanza | 4 | FUE 12, AGI 7 | 10.0 + 0.64·FUE + 0.25·AGI | — | 0.5 | — | Lanza Perforante, Barrido de Lanza | +0.3 velocidad | 464 |
| `lanza_escarcha` | Lanza de Escarcha | guerrero | lanza | 12 | FUE 21, AGI 11 | 17.0 + 0.72·FUE + 0.25·AGI | — | 0.5 | — | Corte Glacial, Barrido de Lanza, Lanza Perforante | +0.3 velocidad | 1776 |
| `espada_templada` | Espada Templada | guerrero | espada | 14 | FUE 23, DES 12 | 19.0 + 0.74·FUE + 0.3·DES | — | — | — | Corte Giratorio, Bastión Creciente | +3% crítico | 2184 |
| `hacha_berserker` | Hacha Berserker | guerrero | hacha | 17 | FUE 27 | 24.0 + 0.92·FUE | — | 1.3 | — | Hendidura Tóxica, Sifón Vital | +6% ATQ | 2856 |
| `lanza_dragon` | Lanza del Dragón | guerrero | lanza | 20 | FUE 29, AGI 15 | 25.0 + 0.8·FUE + 0.25·AGI | — | 0.5 | — | Empalar, Golpe Ígneo | +0.3 velocidad | 3600 |
| `espada_runica` | Espada Rúnica | guerrero | espada | 24 | FUE 33, DES 17 | 29.0 + 0.84·FUE + 0.3·DES | — | — | — | Tajo Temporal, Inspirar | +3% crítico | 4704 |
| `hacha_glaciar` | Hacha del Glaciar | guerrero | hacha | 28 | FUE 39 | 36.0 + 1.03·FUE | — | 1.3 | — | Vendaval Helado, Rompearmaduras | +10% ATQ | 5936 |
| `lanza_tormenta` | Lanza de la Tormenta | guerrero | lanza | 32 | FUE 42, AGI 21 | 36.0 + 0.92·FUE + 0.25·AGI | — | 0.5 | — | Empalar, Barrido de Lanza, Viento de Prisa | +0.5 velocidad | 7296 |
| `mandoble_eras` | Mandoble de las Eras | guerrero | espada | 37 | FUE 47, DES 24 | 41.0 + 0.97·FUE + 0.3·DES | — | 0.3 | — | Tajo del Ocaso, Corte Giratorio, Reto Escudado | +5% crítico | 9176 |
| `hacha_cataclismo` | Hacha del Cataclismo | guerrero | hacha | 43 | FUE 56 | 52.0 + 1.18·FUE | — | 1.5 | — | Erupción, Rugido Intimidante | +10% ATQ | 11696 |
| `espada_cronos` | Espada de Cronos | guerrero | espada | 50 | FUE 60, DES 30 | 54.0 + 1.1·FUE + 0.3·DES | — | 0.3 | — | Tajo Temporal, Tajo Carmesí, Impulso Temporal | +5% crítico | 15000 |
| `varita_sauce` | Varita de Sauce | maga | varita | 2 | ESP 10, DES 6 | 3.0 + 0.3·FUE | 6.0 + 0.72·ESP | — | — | Misil Arcano, Silencio | +8 maná | 216 |
| `varita_hielo` | Varita de Hielo | maga | varita | 8 | ESP 16, DES 9 | 4.0 + 0.3·FUE | 11.0 + 0.78·ESP | — | — | Escarcha Fugaz, Escudo Arcano | +8 maná | 1056 |
| `baculo_roble` | Báculo de Roble Antiguo | maga | báculo | 13 | ESP 22, AGI 12 | 4.0 + 0.4·FUE | 17.0 + 0.88·ESP | — | — | Bola de Fuego, Cura Focalizada, Llamarada | +6% MAG | 1976 |
| `tomo_escarcha` | Tomo de Escarcha | maga | tomo | 16 | ESP 26 | 5.0 + 0.3·FUE | 22.0 + 0.91·ESP | 0.4 | — | Ventisca, Cúpula Arcana | +8% carga de ULT | 2624 |
| `varita_rayo` | Varita del Rayo | maga | varita | 19 | ESP 28, DES 14 | 5.0 + 0.3·FUE | 21.0 + 0.89·ESP | — | — | Rayo Arcano, Prisa (aliados) | +8 maná | 3344 |
| `baculo_ambar` | Báculo de Ámbar | maga | báculo | 23 | ESP 32, AGI 16 | 5.0 + 0.4·FUE | 27.0 + 0.98·ESP | — | — | Purificación, Cura Mayor | +6% MAG | 4416 |
| `tomo_cienaga` | Tomo de la Ciénaga | maga | tomo | 27 | ESP 38 | 6.0 + 0.3·FUE | 34.0 + 1.02·ESP | 0.4 | — | Niebla Tóxica, Dardo Tóxico | +12% carga de ULT | 5616 |
| `varita_estelar` | Varita Estelar | maga | varita | 31 | ESP 41, DES 20 | 6.0 + 0.3·FUE | 31.0 + 1.01·ESP | — | — | Rayo Arcano, Misil Arcano, Ola de Retroceso | +15 maná | 6944 |
| `baculo_eclipse` | Báculo del Eclipse | maga | báculo | 35 | ESP 45, AGI 22 | 6.0 + 0.4·FUE | 38.0 + 1.1·ESP | — | — | Infierno, Marea Vital | +10% MAG | 8400 |
| `tomo_eternidad` | Tomo de la Eternidad | maga | tomo | 40 | ESP 52 | 7.0 + 0.3·FUE | 47.0 + 1.15·ESP | 0.5 | — | Peso del Tiempo, Resurrección, Plaga | +12% carga de ULT | 10400 |
| `varita_vacio` | Varita del Vacío | maga | varita | 45 | ESP 55, DES 28 | 8.0 + 0.3·FUE | 43.0 + 1.15·ESP | — | — | Rayo Arcano, Silencio | +15 maná | 12600 |
| `baculo_origen` | Báculo del Origen | maga | báculo | 50 | ESP 60 | 8.0 + 0.4·FUE | 52.0 + 1.25·ESP | — | — | Ventisca, Llama Fénix, Gracia Desbordante | +10% MAG | 15000 |
| `dagas_cobre` | Dagas de Cobre | tirador | dagas | 2 | DES 10, AGI 6 | 7.0 + 0.57·DES + 0.35·AGI | — | — | — | Tajo Gemelo, Daga Saltarina | +5% crítico | 216 |
| `ballesta_pesada` | Ballesta Pesada | tirador | ballesta | 7 | DES 15, FUE 8 | 15.0 + 0.67·DES + 0.25·FUE | — | 1.1 | — | Virote Pesado, Bala Corrosiva | +15% daño crítico | 896 |
| `arco_compuesto` | Arco Compuesto | tirador | arco | 13 | DES 22, AGI 12 | 18.0 + 0.78·DES + 0.2·AGI | — | — | — | Flecha Perforante, Disparo Certero, Lluvia de Flechas | +3% crítico | 1976 |
| `dagas_sombra` | Dagas Sombrías | tirador | dagas | 16 | DES 25, AGI 13 | 19.0 + 0.71·DES + 0.35·AGI | — | — | — | Abanico de Dagas, Señalar Presa | +5% crítico | 2624 |
| `rifle_precision` | Rifle de Precisión | tirador | rifle | 20 | DES 29, FUE 15 | 26.0 + 0.9·DES | — | 0.8 | — | Tiro Perforante, Tiro Quebrantador | +10% daño crítico | 3600 |
| `ballesta_ignea` | Ballesta Ígnea | tirador | ballesta | 24 | DES 33, FUE 17 | 33.0 + 0.84·DES + 0.25·FUE | — | 1.1 | — | Virote Ígneo, Flecha Incendiaria | +15% daño crítico | 4704 |
| `arco_viento` | Arco del Viento | tirador | arco | 28 | DES 37, AGI 19 | 33.0 + 0.93·DES + 0.2·AGI | — | — | — | Flecha Rayo, Viento de Prisa, Tiro de Rebote | +5% crítico | 5936 |
| `dagas_vibora` | Dagas de la Víbora | tirador | dagas | 32 | DES 42, AGI 21 | 33.0 + 0.87·DES + 0.35·AGI | — | — | — | Abanico de Dagas, Daga Saltarina, Flecha Venenosa | +7% crítico | 7296 |
| `rifle_cronal` | Rifle Cronal | tirador | rifle | 37 | DES 47, FUE 24 | 43.0 + 1.07·DES | — | 0.8 | — | Cero Absoluto, Disparo Cargado, Cadencia Letal | +15% daño crítico | 9176 |
| `ballesta_asedio` | Ballesta de Asedio | tirador | ballesta | 43 | DES 53, FUE 26 | 54.0 + 1.03·DES + 0.25·FUE | — | 1.3 | — | Virote de Asedio, Virote Ígneo, Disparo Aturdidor | +22% daño crítico | 11696 |
| `arco_eterno` | Arco Eterno | tirador | arco | 50 | DES 60, AGI 30 | 54.0 + 1.15·DES + 0.2·AGI | — | — | — | Flecha Solar, Flecha Sanadora, Ojo de Águila | +5% crítico | 15000 |
| `espada_escudo_cruzado` | Espada y Escudo del Cruzado | paladin | espada+escudo | 13 | FUE 9, ESP 22 | 7.0 + 0.3·FUE | 14.0 + 0.8·ESP | — | 2 | Estocada Firme, Lanza de Luz, Sanación ¹ | — | 1976 |
| `maza_escudo_plata` | Maza y Escudo de Plata | paladin | maza+escudo | 15 | VIT 24, ESP 12 | 6.0 + 0.2·FUE | 14.0 + 0.8·ESP | 0.6 | 4 | Barrera, Bendición | — | 2400 |
| `martillo_escudo_forja` | Martillo y Escudo de Forja | paladin | martillo+escudo | 17 | FUE 26, VIT 14 | 16.0 + 0.62·FUE | 11.0 + 0.55·ESP | 1.0 | 1 | Aplastar, Temblor | — | 2856 |
| `espada_escudo_vigia` | Espada y Escudo del Vigía | paladin | espada+escudo | 20 | FUE 11, ESP 29 | 9.0 + 0.3·FUE | 19.0 + 0.86·ESP | — | 2 | Reto Escudado, Consagrar | — | 3600 |
| `maza_escudo_sagrada` | Maza y Escudo Sagrados | paladin | maza+escudo | 23 | VIT 32, ESP 16 | 8.0 + 0.2·FUE | 20.0 + 0.86·ESP | 0.6 | 5 | Sanación, Escudo de Fe, Golpe de Escudo | — | 4416 |
| `martillo_escudo_trueno` | Martillo y Escudo del Trueno | paladin | martillo+escudo | 26 | FUE 35, VIT 18 | 22.0 + 0.71·FUE | 14.0 + 0.55·ESP | 1.0 | 1 | Martillo del Juicio, Rompearmaduras | — | 5304 |
| `espada_escudo_aurora` | Espada y Escudo de la Aurora | paladin | espada+escudo | 29 | FUE 14, ESP 38 | 12.0 + 0.3·FUE | 26.0 + 0.93·ESP | — | 3 | Lanza de Luz, Escudo Volátil, Estocada Firme | — | 6264 |
| `maza_escudo_custodio` | Maza y Escudo del Custodio | paladin | maza+escudo | 32 | VIT 42, ESP 21 | 10.0 + 0.2·FUE | 26.0 + 0.94·ESP | 0.6 | 6 | Provocar, Muralla de Fe | — | 7296 |
| `martillo_escudo_titan` | Martillo y Escudo del Titán | paladin | martillo+escudo | 35 | FUE 45, VIT 22 | 28.0 + 0.8·FUE | 18.0 + 0.55·ESP | 1.3 | 2 | Martillo del Juicio, Temblor, Golpe Sagrado | — | 8400 |
| `espada_escudo_juramento` | Espada y Escudo del Juramento | paladin | espada+escudo | 39 | FUE 17, ESP 49 | 16.0 + 0.3·FUE | 33.0 + 1.01·ESP | — | 4 | Estocada Firme, Bastión Creciente, Lanza de Luz | — | 9984 |
| `maza_escudo_bendita` | Maza y Escudo Benditos | paladin | maza+escudo | 42 | VIT 52, ESP 26 | 12.0 + 0.2·FUE | 33.0 + 1.02·ESP | 0.6 | 7 | Bendición, Resurrección, Sello Sagrado | — | 11256 |
| `martillo_escudo_ocaso` | Martillo y Escudo del Ocaso | paladin | martillo+escudo | 45 | FUE 55, VIT 28 | 36.0 + 0.9·FUE | 22.0 + 0.55·ESP | 1.3 | 3 | Aplastar, Martillo del Juicio, Conmoción | — | 12600 |
| `espada_escudo_alba_eterna` | Espada y Escudo del Alba Eterna | paladin | espada+escudo | 48 | FUE 19, ESP 58 | 19.0 + 0.3·FUE | 40.0 + 1.08·ESP | — | 5 | Lanza de Luz, Muralla de Fe, Golpe Sagrado | — | 14016 |
| `maza_escudo_eterna` | Maza y Escudo de la Eternidad | paladin | maza+escudo | 50 | VIT 60, ESP 30 | 14.0 + 0.2·FUE | 39.0 + 1.08·ESP | 0.6 | 8 | Marea Vital, Bendición, Escudo de Fe | — | 15000 |

¹ **v0.5 (rework del Paladín, ascension.md § 4):** el Paladín perdió su
kit de clase fijo (Aura Restauradora, Fortaleza, Protección: ahora kit
del Guardián) y juega con las habilidades del arma, como las demás
clases. Para que el arma inicial y la línea espada+escudo no queden sin
apoyo, **Sanación** (`sanar`) se sumó a `espada_escudo_novato` (nivel 1)
y a `espada_escudo_cruzado` (nivel 13). Cobertura de apoyo/defensa del
Paladín por base (con las variantes v0.5, ver ²): Sanación (Novicio 1,
Roble 2, Cruzado 13, Sagrados 23), Resurrección (Benditos
42), Marea Vital (Eternidad 50), Bendición (Plata 15, Benditos 42,
Eternidad 50), Provocar (Bastión 4, Custodio 32), Reto Escudado (Vigía
20), Escudo de Fe (Bastión 4, Sagrados 23, Eternidad 50), Barrera (Plata 15), Égida
Espinosa (Alba 4), Escudo Volátil (Aurora 29), Muralla de Fe (Custodio
32, Alba Eterna 48), Bastión Creciente (Juramento 39). La línea
martillo+escudo queda de daño a propósito (sus variantes son de daño /
debuff / control: Conmoción, Golpe Debilitante, Rompearmaduras).
Ninguna base pasa de 3 habilidades.

² **v0.5 (variantes de habilidades, combat.md § "Variantes de
habilidades"):** las 48 variantes se repartieron cambiando habilidades
repetidas de 61 bases, sin subir ninguna de su número de habilidades
(siguen ≤ 3). Criterio: cada tipo de arma suma opciones de apoyo o
defensa además de daño — arcos: flechas que curan (Flecha Sanadora),
marcan (Flecha Marcadora), atraviesan y buffs de grupo (Ojo de Águila,
Viento de Prisa); rifles: Ráfaga Triple, Bala Traspasante, Cadencia
Letal, Disparo Cargado, Tiro Quebrantador, Bala Corrosiva; ballestas:
Bala Corrosiva, Flecha Incendiaria, Virote de Asedio; dagas: Daga
Saltarina, Señalar Presa; báculos: curas (Rocío, Brotes, Semilla, Cura
Focalizada, Purificación, Marea, Fénix, Gracia Desbordante) y Drenar Vida;
tomos: tiempo, buffs y debuffs (Impulso, Lentitud, Maldición, Cúpula,
Peso del Tiempo, Resurrección); varitas: control (Silencio, Ola de
Retroceso, Escudo Arcano); hachas: debuffs (Rompearmaduras, Rugido, Golpe
Debilitante, Sifón); espadas: Inspirar, Reto Escudado, Bastión Creciente,
Impulso; lanzas: Viento de Prisa. Las bases raras / de nivel alto llevan
las variantes más vistosas (Fénix, Gracia Desbordante, Muralla de Fe,
Virote de Asedio, Cadencia Letal). Las armas iniciales no cambian. Toda
habilidad de `kSkills` la da al menos un arma o un kit de ascensión.

³ **v0.20.4:** el ataque del Novicio (2 + 0.15·FUE, ~3 al empezar) era un
quinto del de las otras clases. Pasa a 6 + 0.4·FUE (~9, 65 % del Guerrero)
y la Maza de Roble a 4 + 0.3·FUE (~6). Sigue siendo el que menos pega.

Conteo por tipo y banda de nivel:

| Tipo | 1–10 | 11–20 | 21–30 | 31–40 | 41–50 | Total |
|---|---|---|---|---|---|---|
| espada | 6 | 1 | 1 | 1 | 1 | 10 |
| hacha | 3 | 1 | 1 | 0 | 1 | 6 |
| báculo | 5 | 1 | 1 | 1 | 1 | 9 |
| tomo | 3 | 1 | 1 | 1 | 0 | 6 |
| arco | 5 | 1 | 1 | 0 | 1 | 8 |
| rifle | 4 | 1 | 0 | 1 | 0 | 6 |
| espada+escudo | 2 | 2 | 1 | 1 | 1 | 7 |
| maza+escudo | 2 | 1 | 1 | 1 | 2 | 7 |
| martillo+escudo | 2 | 1 | 1 | 1 | 1 | 6 |
| lanza | 1 | 2 | 0 | 1 | 0 | 4 |
| varita | 2 | 1 | 0 | 1 | 1 | 5 |
| dagas | 1 | 1 | 0 | 1 | 0 | 3 |
| ballesta | 1 | 0 | 1 | 0 | 1 | 3 |

### 8.7 Bases de Agua y Electro (v0.7)

9 bases nuevas (89 en total: guerrero 23, maga 24, tirador 22, paladín
20) con las habilidades de Agua y Electro (combat.md § "Elementos y
reacciones"; docs/specs/elemental_reactions.md). Mismas fórmulas que § 8
(precio `100·L + 4·L²`, implícito por tipo); tier 2 hasta nivel 10, 3
después. Cada habilidad nueva la da al menos una base; ninguna pasa de 3;
las de golpe cuerpo a cuerpo van en armas melee y las de disparo en armas
a distancia (`kSkillDelivery`, § 16.1).

| id | Nombre | familia | tipo | nivel | requisitos | ATQ | MAG | peso | habilidades | implícito | precio |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `espada_coral` | Espada de Coral | guerrero | espada | 9 | FUE 17, DES 10 | 15.0 + 0.69·FUE + 0.3·DES | — | — | Tajo de Marea, Escudo de Agua | +3% crítico | 1224 |
| `varita_voltaica` | Varita Voltaica | maga | varita | 10 | ESP 19, DES 10 | 4.0 + 0.3·FUE | 13.0 + 0.8·ESP | — | Chispazo, Corriente | +8 maná | 1400 |
| `baculo_marea` | Báculo de Marea | maga | báculo | 18 | ESP 27, AGI 14 | 5.0 + 0.4·FUE | 22.0 + 0.93·ESP | — | Chorro de Agua, Oleada, Escudo de Agua | +6% MAG | 3096 |
| `lanza_mareas` | Tridente de las Mareas | guerrero | lanza | 21 | FUE 30, AGI 16 | 26.0 + 0.81·FUE + 0.25·AGI | — | 0.5 | Lanza de las Mareas, Remolino | +0.3 velocidad | 3864 |
| `arco_relampago` | Arco de Relámpago | tirador | arco | 22 | DES 31, AGI 16 | 27.0 + 0.87·DES + 0.2·AGI | — | — | Flecha Voltaica, Relámpago, Flecha Acuática | +3% crítico | 4136 |
| `dagas_electricas` | Dagas Eléctricas | tirador | dagas | 25 | DES 34, AGI 18 | 27.0 + 0.8·DES + 0.35·AGI | — | — | Puñalada Eléctrica, Campo Estático | +7% crítico | 5000 |
| `tomo_tormentas` | Tomo de Tormentas | maga | tomo | 30 | ESP 40 | 6.0 + 0.3·FUE | 37.0 + 1.05·ESP | 0.4 | Tormenta Eléctrica, Cadena de Rayos, Descarga Estática | +12% carga de ULT | 6600 |
| `hacha_tronante` | Hacha Tronante | guerrero | hacha | 34 | FUE 44 | 42.0 + 1.09·FUE | — | 1.3 | Golpe de Trueno, Remolino | +10% ATQ | 8024 |
| `tomo_mareas` | Tomo de las Mareas Profundas | maga | tomo | 41 | ESP 51 | 7.0 + 0.3·FUE | 48.0 + 1.16·ESP | 0.5 | Torrente, Bruma Densa, Géiser | +12% carga de ULT | 10824 |

Las bases existentes no cambian (Flecha Rayo y Descarga pasan a ser de
Electro, Marea Vital de Agua).

### 8.8 Soporte de nivel bajo y revivir raro (v0.21)

Pedido del dueño: más armas de apoyo en los primeros niveles y alguna
que revive, rara. Antes, revivir con habilidad recién llegaba en el
nivel 40 (Tomo de la Eternidad, Resurrección), 42 (Maza y Escudo
Benditos) y 50 (Báculo del Origen, Llama Fénix); el Paladín además tenía
un hueco de apoyo entre el 7 y el 13.

Mismas fórmulas que § 8 (precio `100·L + 4·L²`). Bases nuevas:

| id | Nombre | familia | tipo | nivel | requisitos | ATQ | MAG | habilidades | precio | peso de loot |
|---|---|---|---|---|---|---|---|---|---|---|
| `baculo_rocio` | Báculo del Rocío | maga | báculo | 3 | ESP 15 | 4 + 0.4·FUE | 8 + 0.8·ESP | Rocío Sanador, Semilla Vital | 336 | 1 |
| `maza_escudo_vigilia` | Maza y Escudo de la Vigilia | paladín | maza+escudo | 5 | VIT 21, ESP 12 | 4 + 0.2·FUE | 8 + 0.75·ESP | Sanación, Barrera (DEF escudo 4) | 600 | 1 |
| `arco_alivio` | Arco del Alivio | tirador | arco | 6 | DES 13, ESP 8 | 10 + 0.6·DES + 0.2·AGI | — | Flecha Sanadora, Disparo Certero | 744 | 1 |
| `maza_escudo_retorno` | Maza y Escudo del Retorno | paladín | maza+escudo | 10 | VIT 22, ESP 17 | 5 + 0.2·FUE | 11 + 0.78·ESP | Sanación, Eco de Regreso (DEF escudo 4) | no se vende | 0.25 |
| `tomo_regreso` | Tomo del Regreso | maga | tomo | 11 | ESP 20 | 3 + 0.3·FUE | 12 + 0.9·ESP | Cura Focalizada, Eco de Regreso | no se vende | 0.25 |

Rareza del revivir: Eco de Regreso solo está en esas 2 bases, que no se
venden (precio 0) y salen de loot con `WeaponDef.dropWeight` 0.25 (×0.25
sobre el peso normal de `LootRules.pickBase`). `dropWeight` es editable
en Editor → Balance → Armas ("Peso al salir de loot").

Eco de Regreso (`ecoRegreso`, Sagrado, familia curación): 10 MP, revive
al primer caído con el 25% de la vida (más la sinergia de combat.md §
"Revivir y el árbol"); sin caídos cura MAG × 0.8 + 6 al más herido. Es
más débil que Resurrección (35%, 9 MP, nivel 40) para no romper la
progresión.

### 8.3 Afijos

| id | Nombre | Lado | Estadística | Peso | Solo en | Tiers (nivel: rango) |
|---|---|---|---|---|---|---|
| `feroz` | Feroz | prefijo | atkPct | 1000 | todas | T1 nv40: 33–40 (p20) · T2 nv30: 25–32 (p40) · T3 nv20: 17–24 (p60) · T4 nv10: 10–16 (p80) · T5 nv1: 5–9 (p100) |
| `arcano` | Arcano | prefijo | magPct | 1000 | báculo, tomo, varita, espada+escudo, maza+escudo, martillo+escudo | T1 nv40: 33–40 (p20) · T2 nv30: 25–32 (p40) · T3 nv20: 17–24 (p60) · T4 nv10: 10–16 (p80) · T5 nv1: 5–9 (p100) |
| `afilado` | Afilado | prefijo | flatAtk | 800 | todas | T1 nv40: 16–22 (p20) · T2 nv30: 11–15 (p40) · T3 nv20: 7–10 (p60) · T4 nv10: 4–6 (p80) · T5 nv1: 1–3 (p100) |
| `runico` | Rúnico | prefijo | flatMag | 800 | báculo, tomo, varita, espada+escudo, maza+escudo, martillo+escudo | T1 nv40: 16–22 (p20) · T2 nv30: 11–15 (p40) · T3 nv20: 7–10 (p60) · T4 nv10: 4–6 (p80) · T5 nv1: 1–3 (p100) |
| `certero` | Certero | prefijo | critChance | 700 | todas | T1 nv40: 10–12 (p20) · T2 nv30: 8–9 (p40) · T3 nv20: 6–7 (p60) · T4 nv10: 4–5 (p80) · T5 nv1: 2–3 (p100) |
| `letal` | Letal | prefijo | critMulti | 500 | todas | T1 nv40: 34–42 (p20) · T2 nv30: 26–33 (p40) · T3 nv20: 19–25 (p60) · T4 nv10: 13–18 (p80) · T5 nv1: 8–12 (p100) |
| `veloz` | Veloz | prefijo | speed | 600 | todas | T1 nv40: 9–11 (p20) · T2 nv30: 7–8 (p40) · T3 nv20: 5–6 (p60) · T4 nv10: 3–4 (p80) · T5 nv1: 1–2 (p100) |
| `abrasador` | Abrasador | prefijo | burnStacks | 300 | espada, hacha, lanza, báculo, varita, arco, ballesta | T1 nv36: 2–2 (p40) · T2 nv12: 1–1 (p100) |
| `ponzonoso` | Ponzoñoso | prefijo | poisonStacks | 300 | hacha, tomo, arco, rifle, dagas, ballesta | T1 nv36: 2–2 (p40) · T2 nv12: 1–1 (p100) |
| `gelido` | Gélido | prefijo | freezeStacks | 300 | báculo, tomo, varita, rifle | T1 nv36: 2–2 (p40) · T2 nv12: 1–1 (p100) |
| `impetuoso` | Impetuoso | prefijo | ultCharge | 500 | todas | T1 nv40: 18–22 (p20) · T2 nv30: 14–17 (p40) · T3 nv20: 10–13 (p60) · T4 nv10: 7–9 (p80) · T5 nv1: 4–6 (p100) |
| `del_oso` | del Oso | sufijo | vit | 900 | todas | T1 nv40: 16–20 (p20) · T2 nv30: 12–15 (p40) · T3 nv20: 8–11 (p60) · T4 nv10: 5–7 (p80) · T5 nv1: 2–4 (p100) |
| `del_sabio` | del Sabio | sufijo | esp | 900 | todas | T1 nv40: 16–20 (p20) · T2 nv30: 12–15 (p40) · T3 nv20: 8–11 (p60) · T4 nv10: 5–7 (p80) · T5 nv1: 2–4 (p100) |
| `del_zorro` | del Zorro | sufijo | agi | 900 | todas | T1 nv40: 16–20 (p20) · T2 nv30: 12–15 (p40) · T3 nv20: 8–11 (p60) · T4 nv10: 5–7 (p80) · T5 nv1: 2–4 (p100) |
| `del_toro` | del Toro | sufijo | fue | 900 | todas | T1 nv40: 16–20 (p20) · T2 nv30: 12–15 (p40) · T3 nv20: 8–11 (p60) · T4 nv10: 5–7 (p80) · T5 nv1: 2–4 (p100) |
| `del_halcon` | del Halcón | sufijo | des | 900 | todas | T1 nv40: 16–20 (p20) · T2 nv30: 12–15 (p40) · T3 nv20: 8–11 (p60) · T4 nv10: 5–7 (p80) · T5 nv1: 2–4 (p100) |
| `de_la_vida` | de la Vida | sufijo | maxHp | 1000 | todas | T1 nv40: 66–90 (p20) · T2 nv30: 46–65 (p40) · T3 nv20: 29–45 (p60) · T4 nv10: 16–28 (p80) · T5 nv1: 8–15 (p100) |
| `del_eter` | del Éter | sufijo | maxMp | 800 | todas | T1 nv40: 21–28 (p20) · T2 nv30: 15–20 (p40) · T3 nv20: 10–14 (p60) · T4 nv10: 6–9 (p80) · T5 nv1: 3–5 (p100) |
| `del_baluarte` | del Baluarte | sufijo | defense | 800 | espada+escudo, maza+escudo, martillo+escudo | T1 nv40: 6–7 (p20) · T2 nv30: 4–5 (p40) · T3 nv20: 3–3 (p60) · T4 nv10: 2–2 (p80) · T5 nv1: 1–1 (p100) |
| `de_la_gracia` | de la Gracia | sufijo | healReceived | 500 | todas | T1 nv40: 23–28 (p20) · T2 nv30: 18–22 (p40) · T3 nv20: 13–17 (p60) · T4 nv10: 9–12 (p80) · T5 nv1: 5–8 (p100) |
| `del_renacer` | del Renacer | sufijo | regen | 300 | todas | T1 nv40: 3–3 (p30) · T2 nv25: 2–2 (p60) · T3 nv10: 1–1 (p100) |
| `de_la_pureza` | de la Pureza | sufijo | statusResist | 300 | todas | T1 nv40: 2–2 (p40) · T2 nv15: 1–1 (p100) |
| `del_vampiro` | del Vampiro | sufijo | lifeSteal | 400 | todas | T1 nv40: 5–6 (p20) · T2 nv25: 4–4 (p40) · T3 nv15: 3–3 (p60) · T4 nv5: 1–2 (p100) |
| `de_la_fe` | de la Fe | sufijo | healPower | 600 | báculo, tomo, varita, espada+escudo, maza+escudo, martillo+escudo | T1 nv40: 25–30 (p20) · T2 nv30: 19–24 (p40) · T3 nv20: 14–18 (p60) · T4 nv10: 9–13 (p80) · T5 nv1: 5–8 (p100) |

### 8.4 Pasivas de arma (pool de Épicos)

| id | Nombre | Tipos | I | II | III | IV | V | Efecto (nivel I) |
|---|---|---|---|---|---|---|---|---|
| `filoResonante` | Filo Resonante | espada, lanza, dagas, espada+escudo | 25% | 30% | 35% | 40% | 45% | Tus golpes a un solo objetivo golpean también a un 2.º enemigo con el 25% del daño. |
| `impetu` | Ímpetu | espada, dagas, arco | 10% | 12% | 15% | 17% | 20% | Al hacer crítico: +10% velocidad por 2 turnos. |
| `rompehielos` | Rompehielos | hacha, martillo+escudo, lanza, rifle | 20% | 25% | 30% | 35% | 40% | Golpear a un enemigo congelado llena su quiebre un 20% más. |
| `escarchaViva` | Escarcha Viva | báculo, tomo, varita, rifle | 40% | 50% | 60% | 70% | 80% | Al aplicar Congelación: 40% de sumar +1 stack más. |
| `brasaAvivada` | Brasa Avivada | báculo, varita, espada, arco | 40% | 50% | 60% | 70% | 80% | Al aplicar Quemadura: 40% de sumar +1 stack más. |
| `toxinaPersistente` | Toxina Persistente | tomo, arco, dagas, ballesta | 40% | 50% | 60% | 70% | 80% | Al aplicar Veneno: 40% de sumar +1 stack más. |
| `egidaSanadora` | Égida Sanadora | báculo, tomo, maza+escudo, espada+escudo | 10% | 15% | 20% | 25% | 30% | Al curar a un aliado, gana un escudo del 10% de lo curado por 2 turnos. |
| `sedDelArma` | Sed del Arma | hacha, espada, lanza, dagas | 4% | 6% | 8% | 10% | 12% | Al matar: te curás 4% de tu vida máx. |
| `conmocion` | Golpe Conmocionante | maza+escudo, martillo+escudo, hacha, ballesta | 6% | 8% | 10% | 12% | 15% | Tus golpes a un solo objetivo tienen 6% de aturdirlo. |
| `marcaPresa` | Marca de la Presa | arco, ballesta, rifle, lanza | 6% | 8% | 10% | 12% | 14% | Tu primer golpe a un enemigo sin marca lo marca: recibe +6% de daño de todos por 2 turnos. |
| `vientoDeCola` | Viento de Cola | arco, varita, tomo, hacha | 10% | 15% | 20% | 25% | 30% | Después de una habilidad de daño a todos: tu próximo turno llega 10% antes. |
| `ecoMistico` | Eco Místico | varita, báculo, tomo | 6% | 8% | 10% | 12% | 14% | 6% de que una habilidad mágica se repita gratis al 50% del daño base. |
| `cargaHeroica` | Carga Heroica | rifle, ballesta, espada, martillo+escudo | 3 | 4 | 5 | 6 | 7 | Al hacer crítico: +3 carga de ULT. |
| `espinas` | Espinas | espada+escudo, maza+escudo, martillo+escudo, hacha | 15% | 20% | 25% | 30% | 35% | Al recibir un golpe: devolvés el 15% del daño al atacante. |
| `bastionVivo` | Bastión Vivo | espada+escudo, maza+escudo, martillo+escudo | 6% | 8% | 10% | 12% | 14% | Al usar Provocar, Protección o Escudo de Fe: escudo del 6% de tu vida máx. por 2 turnos. |
| `filoDesesperado` | Filo Desesperado | hacha, dagas, lanza, espada | 10% | 15% | 20% | 25% | 30% | Con menos de 35% de vida: +10% ATQ. |
| `cazadorGelido` | Cazador Gélido | rifle, ballesta, arco, varita | 8% | 12% | 16% | 20% | 24% | Tus golpes a enemigos con Congelación hacen +8% de daño. |
| `fuegoHambriento` | Fuego Hambriento | báculo, varita, espada, ballesta | 8% | 12% | 16% | 20% | 24% | Tus golpes a enemigos con Quemadura hacen +8% de daño. |
| `plegariaAcero` | Plegaria del Acero | maza+escudo, tomo, espada+escudo | 2% | 3% | 4% | 5% | 6% | Al empezar tu turno: el aliado con menor % de vida se cura 2% de su vida máx. |
| `pesoDelTiempo` | Peso del Tiempo | martillo+escudo, tomo, ballesta, lanza | 8% | 11% | 14% | 17% | 20% | Tus golpes a un solo objetivo lo retrasan un 8% de su espera. |
| `ojoCertero` | Ojo Certero | arco, rifle, dagas | 6% | 9% | 12% | 15% | 18% | +6% crítico contra enemigos marcados. |

Pool por tipo:

- **espada**: Filo Resonante, Ímpetu, Brasa Avivada, Sed del Arma, Carga Heroica, Filo Desesperado, Fuego Hambriento
- **hacha**: Rompehielos, Sed del Arma, Golpe Conmocionante, Viento de Cola, Espinas, Filo Desesperado
- **báculo**: Escarcha Viva, Brasa Avivada, Égida Sanadora, Eco Místico, Fuego Hambriento
- **tomo**: Escarcha Viva, Toxina Persistente, Égida Sanadora, Viento de Cola, Eco Místico, Plegaria del Acero, Peso del Tiempo
- **arco**: Ímpetu, Brasa Avivada, Toxina Persistente, Marca de la Presa, Viento de Cola, Cazador Gélido, Ojo Certero
- **rifle**: Rompehielos, Escarcha Viva, Marca de la Presa, Carga Heroica, Cazador Gélido, Ojo Certero
- **espada+escudo**: Filo Resonante, Égida Sanadora, Espinas, Bastión Vivo, Plegaria del Acero
- **maza+escudo**: Égida Sanadora, Golpe Conmocionante, Espinas, Bastión Vivo, Plegaria del Acero
- **martillo+escudo**: Rompehielos, Golpe Conmocionante, Carga Heroica, Espinas, Bastión Vivo, Peso del Tiempo
- **lanza**: Filo Resonante, Rompehielos, Sed del Arma, Marca de la Presa, Filo Desesperado, Peso del Tiempo
- **varita**: Escarcha Viva, Brasa Avivada, Viento de Cola, Eco Místico, Cazador Gélido, Fuego Hambriento
- **dagas**: Filo Resonante, Ímpetu, Toxina Persistente, Sed del Arma, Filo Desesperado, Ojo Certero
- **ballesta**: Toxina Persistente, Golpe Conmocionante, Marca de la Presa, Carga Heroica, Cazador Gélido, Fuego Hambriento, Peso del Tiempo

### 8.5 Legendarios

| id | Nombre | Base (nv) | Mods fijos | Aleatorios | Pasiva única (I → V) |
|---|---|---|---|---|---|
| `juramentoAlba` | Juramento del Alba | Espada Templada (14) | +20% ATQ–30, +5% crítico–8 | 1–2 | **Alba Implacable**: Al hacer crítico: +15% ATQ por 2 turnos. → Al hacer crítico: +35% ATQ por 2 turnos. |
| `segadoraEras` | Segadora de Eras | Mandoble de las Eras (37) | +35% ATQ–45, 3% de robo de vida–5 | 1–2 | **Cosecha**: Al matar: tu próximo turno llega 20% antes y te curás 3% de tu vida máx. → Al matar: tu próximo turno llega 60% antes y te curás 10% de tu vida máx. |
| `fauceVolcan` | Fauce del Volcán | Hacha Volcánica (4) | +4 ATQ–7, +1 stack de Quemadura al aplicar | 1–2 | **Erupción Interna**: Al golpear a un enemigo con 3+ Quemadura: explota y hace el 30% de ese golpe a cada otro enemigo. → Al golpear a un enemigo con 3+ Quemadura: explota y hace el 60% de ese golpe a cada otro enemigo. |
| `rompemundos` | Rompemundos | Hacha del Cataclismo (43) | +30% ATQ–40, +10 FUE–15, +40 vida–60 | 1–2 | **Grieta**: Todos tus golpes llenan el quiebre un 25% más. → Todos tus golpes llenan el quiebre un 65% más. |
| `lanzaHorizonte` | Lanza del Horizonte | Lanza de la Tormenta (32) | +0.5 velocidad–8, +6% crítico–10 | 1–2 | **Horizonte**: Tus golpes a un solo objetivo rebotan a otro enemigo con el 45% del daño. → Tus golpes a un solo objetivo rebotan a otro enemigo con el 65% del daño. |
| `corazonAscua` | Corazón de Ascua | Báculo de Fuego (2) | +15% MAG–25, +1 stack de Quemadura al aplicar | 1–2 | **Ascua Eterna**: Al aplicar Quemadura: 50% de sumar +1 stack más. → Al aplicar Quemadura: 100% de sumar +1 stack más. |
| `inviernoPerpetuo` | Invierno Perpetuo | Báculo de Ámbar (23) | +25% MAG–35, +1 stack de Congelación al aplicar, +12 maná–18 | 1–2 | **Escarcha Perpetua**: Al congelar a un enemigo: se retrasa un 15% de su espera. → Al congelar a un enemigo: se retrasa un 35% de su espera. |
| `codiceUltimoDia` | Códice del Último Día | Tomo de la Eternidad (40) | +35% MAG–45, +15% carga de ULT–22 | 1–2 | **Paradoja Viva**: 15% de que una habilidad mágica se repita gratis al 60% del daño base. → 35% de que una habilidad mágica se repita gratis al 60% del daño base. |
| `relampagoDormido` | Relámpago Dormido | Varita del Rayo (19) | +20% MAG–30, +20% daño crítico–30 | 1–2 | **Arco Dormido**: Tus habilidades mágicas a un solo objetivo rebotan a otro enemigo con el 35% del daño. → Tus habilidades mágicas a un solo objetivo rebotan a otro enemigo con el 55% del daño. |
| `susurroVibora` | Susurro de la Víbora | Dagas de la Víbora (32) | +1 stack de Veneno al aplicar–2, +6% crítico–10 | 1–2 | **Mordida**: Al hacer crítico: +2 Veneno al objetivo. → Al hacer crítico: +4 Veneno al objetivo. |
| `ojoHalconSolar` | Ojo del Halcón Solar | Arco Solar (7) | +20% ATQ–30, +20% daño crítico–30 | 1–2 | **Sol Cenital**: Tus golpes marcan al enemigo (+10% de daño recibido, 2 turnos) y tenés +10% crítico contra marcados. → Tus golpes marcan al enemigo (+10% de daño recibido, 2 turnos) y tenés +30% crítico contra marcados. |
| `truenoBronce` | Trueno de Bronce | Rifle de Precisión (20) | +25% ATQ–35, +6 ATQ–10 | 1–2 | **Estampido**: Al hacer crítico: 25% de aturdir al objetivo. → Al hacer crítico: 65% de aturdir al objetivo. |
| `ballestaJuicio` | Ballesta del Juicio Final | Ballesta de Asedio (43) | +35% ATQ–40, +26% daño crítico–40 | 1–2 | **Virote Final**: Al matar: +10 carga de ULT. → Al matar: +30 carga de ULT. |
| `primaveraRota` | Arco de la Primavera Rota | Arco Eterno (50) | +35% ATQ–40, +12 DES–18, Regenera 2% de vida por turno–3 | 1–2 | **Florecer**: Después de una habilidad de daño a todos: ataque básico gratis al enemigo con menos vida y tu próximo turno llega 10% antes. → Después de una habilidad de daño a todos: ataque básico gratis al enemigo con menos vida y tu próximo turno llega 30% antes. |
| `egidaPrimerRey` | Égida del Primer Rey | Espada y Escudo del Cruzado (13) | +3 DEF–5, +30 vida–50 | 1–2 | **Corona de Escudos**: Al empezar tu turno: escudo del 4% de tu vida máx. por 1 turno. → Al empezar tu turno: escudo del 12% de tu vida máx. por 1 turno. |
| `martilloOcasoSagrado` | Martillo del Ocaso Sagrado | Martillo y Escudo del Titán (35) | +25% ATQ–35, +7 MAG–12 | 1–2 | **Juicio Final**: Al aturdir a un enemigo: daño sagrado MAG × 0.50. → Al aturdir a un enemigo: daño sagrado MAG × 1.10. |
| `relicarioMisericordia` | Relicario de la Misericordia | Maza y Escudo Sagrados (23) | +15% curación–25, +8 ESP–12 | 1–2 | **Misericordia**: Al empezar tu turno: el aliado con menor % de vida se cura 4% de su vida máx. → Al empezar tu turno: el aliado con menor % de vida se cura 10% de su vida máx. |
| `bastionMilEras` | Bastión de las Mil Eras | Maza y Escudo de la Eternidad (50) | +6 DEF–7, −1 stacks de estados recibidos, +60 vida–90 | 1–2 | **Mil Eras**: Al recibir un golpe: devolvés el 30% del daño al atacante. → Al recibir un golpe: devolvés el 70% del daño al atacante. |

### 8.6 Pasivas únicas (valores I–V)

| id | Nombre | I | II | III | IV | V |
|---|---|---|---|---|---|---|
| `albaImplacable` | Alba Implacable | 15% | 20% | 25% | 30% | 35% |
| `cosecha` | Cosecha | 20% | 30% | 40% | 50% | 60% |
| `erupcionInterna` | Erupción Interna | 30% | 38% | 45% | 53% | 60% |
| `grieta` | Grieta | 25% | 35% | 45% | 55% | 65% |
| `horizonte` | Horizonte | 45% | 50% | 55% | 60% | 65% |
| `ascuaEterna` | Ascua Eterna | 50% | 63% | 75% | 88% | 1 |
| `escarchaPerpetua` | Escarcha Perpetua | 15% | 20% | 25% | 30% | 35% |
| `paradojaViva` | Paradoja Viva | 15% | 20% | 25% | 30% | 35% |
| `arcoDormido` | Arco Dormido | 35% | 40% | 45% | 50% | 55% |
| `mordida` | Mordida | 2 | 2 | 3 | 3 | 4 |
| `solCenital` | Sol Cenital | 10% | 15% | 20% | 25% | 30% |
| `estampido` | Estampido | 25% | 35% | 45% | 55% | 65% |
| `viroteFinal` | Virote Final | 10 | 15 | 20 | 25 | 30 |
| `florecer` | Florecer | 10% | 15% | 20% | 25% | 30% |
| `coronaEscudos` | Corona de Escudos | 4% | 6% | 8% | 10% | 12% |
| `juicioFinal` | Juicio Final | 50% | 65% | 80% | 95% | 1 |
| `misericordia` | Misericordia | 4% | 6% | 7% | 9% | 10% |
| `milEras` | Mil Eras | 30% | 40% | 50% | 60% | 70% |

## 9. Rarezas y afijos

| Rareza | Mods al generar | Cupo | Prefijos / sufijos | Pasiva | Forja (tope total) | Costo × | Habilidades trasladadas |
|---|---|---|---|---|---|---|---|
| Común | 0 | 0 | 0 / 0 | — | 3 | 1.0 | 1 |
| Mágico | 1–2 | 2 | 1 / 1 | — | 5 | 1.2 | 1 |
| Raro | 3–4 | 4 | 2 / 2 | — | 6 | 1.5 | 1 |
| Épico | 5–6 | 6 | 3 / 3 | 1 aleatoria del pool del tipo | 8 | 2.0 | 2 |
| Legendario | fijos + 1–2 | 6 | 3 / 3 | única | 10 | 3.0 | 2 |

- 24 afijos (11 prefijos, 13 sufijos), tabla en § 8.3. Valores
  enteros: % en puntos (`feroz` 12 = +12% ATQ), velocidad en décimas,
  `del_renacer` en % de vida por turno, `de_la_pureza` en stacks.
- Tiers por nivel de objeto: T5 desde 1, T4 10, T3 20, T2 30, T1 40
  (los de stacks: T2 desde 12, T1 desde 36). El ejemplo de § 3 (T1 en el
  nivel 30) se corrió a 40 porque el máximo ahora es 50.
- Generación (determinística con `RandomSource`, sin bucles de rechazo):
  se elige el afijo entre los que entran (tipo de arma, no repetido,
  lado con cupo, algún tier ≤ nivel de objeto) por su peso; el tier entre
  los permitidos por su peso; el valor uniforme en el rango del tier.
- Nombres: Mágico = "Base Prefijo Sufijo" ("Espada de Bronce Feroz del
  Oso"); Raro / Épico = nombre generado ("Eco Voraz") guardado en la
  instancia; Legendario = el nombre del único. Forja: `+N` al final.

## 10. Pasivas de arma

Mecánicas del sistema de disparadores del árbol v2 (`PassiveMechanic`)
con 5 niveles. El motor las mete en las mecánicas del combatiente con id
`wp:<pasiva>:<nivel>` (y `#2`... si la pasiva tiene varias mecánicas);
`mechanicById` las resuelve. Nivel efectivo = nivel base (1) + 1 cada 2
niveles de forja, tope V. Tabla en § 8.4 (únicas: § 8.6).

Efectos nuevos del motor para las pasivas (`ProcEffectKind`):
`extraStacks` (al aplicar un estado, +N stacks del mismo), `inflict`
(aplica un estado secundario, no dispara nada), `breakBonus`
(modificador de condición: +% al llenado de quiebre); disparador nuevo
`always` (condición siempre cierta). Las reglas anti-bucle de
passive_tree_v2.md § 5 valen igual (lo que generan es secundario).

## 11. Legendarios

18 únicos (5 guerrero, 4 maga, 5 tirador, 4 paladín), tabla en § 8.5. Cada
uno: base fija, 2–3 mods fijos (`AffixRoll` con tier 0 y rango propio),
1–2 afijos aleatorios y una pasiva única a nivel I. Los mods fijos no se
quitan ni se trasladan; la Esquirla los vuelve a tirar dentro de su
rango. Un Legendario cae solo si hay un único con base de nivel ≤ nivel
de objeto (si no, sale Épico).

## 12. Stats (orden de aplicación)

`StatsCalculator.calculate` (`PlayerBuild.item` = instancia equipada):
1. Atributos + atributos de los afijos.
2. Base del arma (fórmulas ATQ/MAG con esos atributos).
3. Implícito y afijos: `(base + plano) × (1 + %)`; vida/maná/DEF/vel/
   crítico suman plano; crítico tope 60% antes del árbol.
4. Forja: ×(1 + 0.12·Poder), +2% crítico, +0.3 vel., +1 DEF por nivel.
5. Árbol de pasivas (como antes).
- Sin fórmula de MAG, la magia copia al ataque (también sus mods).
- `DerivedStats` nuevos: `lifeSteal`, `regenPerTurn`, `statusResist`,
  `healReceived`, `breakdown` (`ATQ`, `MAG`, `HP`, `MP`, `VEL`, `CRIT`,
  `DEF` → "ATQ 21 = base 15 × 1.40 afijos × 1.12 forja"). Carga de ULT,
  curación y stacks de estados suman a los del árbol.
- Combate: robo de vida = % del daño de la acción; regeneración al
  empezar el turno; resistencia = −N stacks de Quemadura / Veneno /
  Congelación recibidos (mín. 1); curación recibida multiplica toda cura.
  Se serializan en el `Combatant` (`ls`, `rgn`, `sres`, `hrec`).
- Sin arma con mods, los números son exactamente los de antes.

## 13. Filtros de loot: gramática

```
# comentario (también al final de una línea)
Mostrar|Ocultar [# nombre de la regla]
  <condición>        (todas deben cumplirse)
  <acción>
```
Palabras clave sin distinguir mayúsculas ni tildes. Condiciones:

| Condición | Ejemplo | Nota |
|---|---|---|
| `Rareza [op] <rareza>` | `Rareza >= Raro` | Común/Normal, Mágico, Raro, Épico, Legendario/Único (también femenino) |
| `Tipo <tipo>...` | `Tipo espada lanza` | cualquiera |
| `Base <id>...` | `Base espada_ignea` | ids de base |
| `Clase <familia>...` | `Clase guerrero` | familia de la base |
| `NivelObjeto <op> N` | `NivelObjeto < 10` | |
| `NivelRelativo <op> N` | `NivelRelativo <= -6` | nivel del objeto − tu nivel |
| `Mods <op> N` | `Mods >= 3` | cantidad de afijos |
| `TieneMod <afijo> [<op> tier]` | `TieneMod feroz <= 2` | T1 es el mejor; mod fijo = T1 |
| `Pasiva [Si/No]` | `Pasiva` | |
| `Material <material>...` | `Material prisma` | esquirla, cristal, prisma |
| `Objeto <clase>...` | `Objeto Material` | Arma, Material, Pocion |
| `Utilizable [Si/No]` | `Utilizable` | cumplís nivel y requisitos ahora |
| `Peso <categoría>...` | `Peso Media Pesada` | categoría de peso de la base (§ 1.1): Ligera, Media, Pesada; cualquiera de esas (v0.8.4) |
| `Build [Base/Mod/Pasiva/Habilidad...]` | `Build Mod Pasiva` | "Coincide con mi build" (v0.5.1): el arma cumple algo de tu plan de build; con clases, alguna de esas (`Base` = base o tipo; también `Tipo`/`Arma`); sin clases, cualquiera. `MiBuild` es sinónimo |
| `Build No` | `Build No` | el arma no cumple nada de tu plan |
| `BuildMejora` | `BuildMejora` / `BuildMejora No` | el arma sube el % de tu mejor candidata del arma objetivo principal (build_planner_v2.md § 1.4); sin objetivo v2 no coincide nunca |

`op`: `=` (por defecto), `!=`, `<`, `<=`, `>`, `>=`. Acciones: `Color R G
B [A]` (texto), `Borde R G B [A]`, `Fondo R G B [A]`, `Tamaño N`
(18–45, defecto 32), `Sonido <id>` (`alerta`, `campana`, `gema`,
`legendario`, `material`, `suave`), `Icono <forma> [color]` (formas
`circulo`, `estrella`, `triangulo`, `cuadrado`, `diamante`; colores
`blanco`, `rojo`, `verde`, `azul`, `amarillo`, `naranja`, `violeta`,
`celeste`). Gana la primera regla que coincide; sin ninguna se muestra
con el color de la rareza. Las líneas que no se entienden se ignoran y
se reportan ("línea N: ..."). `serialize` escribe el texto canónico (la
ida y vuelta conserva el filtro). El perfil guarda el texto (`lf`); sin
texto, el filtro por defecto (`LootFilterRules.defaultText`): resalta
legendarios, épicos, raros y materiales; oculta Comunes con
`NivelRelativo <= -6` y Mágicos con `<= -10`. Desde v0.5.1 también
resalta en violeta (regla **Tu build**, después de Ecos y Legendarios) las
armas Mágicas o mejores que cumplen tu plan de build.

`Build` usa el plan de build de **quien mira** (`FilterContext.wants`,
el resumen `BuildWants`; build_planner.md § 6): el anfitrión lo conoce
porque cada cliente se lo manda (netcode.md § "Build y filtro"). Solo
armas; sin plan no coincide nunca (ni `Build No`). Misma regla que el
planificador (`itemFit`): base o tipo del plan, mod del plan con tier
suficiente (fijos siempre), la pasiva del plan, una habilidad del plan.
Lo que cumple tu plan lleva **★** delante del nombre (piso, vista previa,
resultado, registro de loot), lo use una regla o no.

Los ids de `Material` se comparan sin mayúsculas ni tildes, como el
resto (v0.8.6: antes `Material fragReloj`, que es lo que escribe
`serialize`, daba "material desconocido"). El host lee el filtro con el
catálogo de la sesión (el mismo que la vista previa del editor).

### 13.1 Casillas y reglas apagadas (v0.8.6)

El editor por casillas (panels.md § "Filtro de loot") escribe y lee
**este mismo texto**; no hay otro formato guardado.

- **Regla** del texto = su línea `Mostrar`/`Ocultar` y las que siguen
  hasta la próxima regla. Las líneas antes de la primera regla
  (comentarios) no son de ninguna.
- **Regla apagada**: cada una de sus líneas (no vacías) lleva delante
  `#OFF ` (por ejemplo `#OFF Ocultar # Comunes de nivel bajo`). Para el
  parser es un comentario: sigue en el texto pero no aplica. Prenderla
  saca ese prefijo; el resto de la línea queda igual.
- **Reglas rápidas**: cada casilla de OCULTAR RÁPIDO agrega una regla con
  nombre `# rápido: …` y un texto fijo (`quickOptions`). Una casilla
  está marcada si su regla está **tal cual** (sin contar sangría ni
  líneas vacías) y prendida. Si el jugador la edita a mano, la casilla
  queda desmarcada y la regla queda como una regla suya, intacta.
- **Orden**: al marcar o desmarcar, las reglas rápidas prendidas se
  vuelven a escribir juntas, **antes de la primera de las demás reglas**
  (debajo de los comentarios de arriba), en este orden: primero la
  excepción ★ y después los Ocultar rápidos. Gana la primera regla que
  coincide, así que la ★ le gana a los rápidos y los rápidos a las reglas
  del jugador (marcar "Raras" oculta los Raros aunque más abajo haya un
  `Mostrar # Raros`). Las reglas del jugador y las rápidas apagadas no
  se mueven ni se tocan.
- **Qué agrega cada casilla**:

| Casilla | Regla |
|---|---|
| Mostrar siempre lo de mi build (★) | `Mostrar` · `Build` · `Rareza <= Épico` con el estilo violeta de **Tu build** (los Legendarios siguen con su regla) |
| Armas por rareza: Comunes / Mágicas / Raras / Épicas | `Ocultar` · `Objeto Arma` · `Rareza <rareza>` (`Objeto Arma`: un Eco también tiene rareza) |
| Armas por peso: Ligeras / Medias / Pesadas | `Ocultar` · `Peso <categoría>` · `Rareza <= Raro` |
| Armas por tipo (los tipos del catálogo) | `Ocultar` · `Tipo <tipo>` · `Rareza <= Raro` |
| Que no podés usar | `Ocultar` · `Utilizable No` · `Rareza <= Raro` |
| De nivel bajo | `Ocultar` · `NivelRelativo <= -6` · `Rareza <= Raro` |
| Esquirla / Cristal / Prisma / Ancla | `Ocultar` · `Material <id>` |
| Fragmentos | `Ocultar` · `Material fragReloj fragEco fragCorona fragEras` |
| Pociones y éter | `Ocultar` · `Objeto Pocion` |

  Por tipo, peso, uso y nivel nunca se ocultan Épicas ni Legendarias
  (decisión de esta versión: es fácil perder un buen drop por una
  casilla de tipo); para ocultar Épicas está su casilla de rareza.
- **✕** borra las líneas de esa regla y nada más.

## 14. Drops

**Nivel de zona**: en las misiones de zona (v0.2.0) es el nivel de la
batalla (piso, élite o jefe), el del piso para cofres y el máximo de la
zona para el arma de fin de misión (worldgen.md § 6.3). En misiones sin
zona (`LootRules.zoneLevel`, solo tests de paridad): `max(nivel recomendado de la misión + rango (C 0,
B 1, A 2), promedio de nivel del grupo)`, tope 50; se fija al empezar la
misión (`MissionRun.zoneLevel`). El mundo nuevo pasará el nivel de su
zona. **Nivel de objeto**: zona (+1 élite y fin de misión, +2 jefe),
tope 50. **Base**: nivel ≤ nivel de objeto, peso ×3 si está en los
últimos 10 niveles y ×2 si es de la familia del jugador.

**Rareza**: pesos base 60 / 27 / 10 / 2.7 / 0.3 (dentro de un Eco; en
zonas, cofres y misiones el Épico pesa `LootRules.zoneEpicWeight` = 1.5
desde v0.15 — la tabla de abajo es la del Eco), cada uno
`× (1 + k·b)` con `k` = 0 / 0.5 / 1 / 1.5 / 2 y `b` = bonus de zona
(`0.5 × (zona − 1) / 49`) + fuente (batalla 0, cofre 0.5, élite 1, fin de
misión 1 + rango (S +1, A +0.5), jefe 2). Ejemplos:

| Zona / fuente | Común | Mágico | Raro | Épico | Legendario |
|---|---|---|---|---|---|
| 1, batalla | 60.0 | 27.0 | 10.0 | 2.7 | 0.3 |
| 1, jefe | 38.4 | 34.5 | 19.2 | 6.9 | 1.0 |
| 25, élite | 44.4 | 32.4 | 16.6 | 5.7 | 0.8 |
| 50, batalla | 52.6 | 29.6 | 13.1 | 4.1 | 0.5 |
| 50, jefe | 35.2 | 35.7 | 20.5 | 7.5 | 1.1 |

**Por jugador y fuente** (loot instanciado; cada uno tira lo suyo):

| Fuente | Armas | Materiales (× base) |
|---|---|---|
| Grupo normal | 30% de 1 | ×1 |
| Cofre (quien lo abre) | 35% de 1 (+ créditos y poción como antes) | ×2 |
| Élite | 1 segura + 50% de otra | ×3 |
| Jefe | 2 seguras | ×5 + 1 Esquirla segura |
| Fin de misión | S 90%, A 70%, B 50% de 1 | ×2 |

Materiales: una tirada por material, `chance × fuente × (1 + bonus de
zona)`, tope 95%: Esquirla del Eco 8%, Cristal de Era 2.5%, Prisma Roto
0.6% (v0.15; antes 10 / 4 / 1.5). Pila máx. 99 de cada uno; lo que sobra
se puede condensar (§ 16, Condensar).

**Entrega** (`SessionEngine.groundLoot`): con `true`, todo cae al piso
del mapa con dueño (lo ve y lo levanta solo él: caminando encima si su
filtro lo muestra, o con E / `PickUpAction` a ≤ 24 px). Con `false` (hoy,
hasta que la UI dibuje el loot en el mapa) va directo al inventario lo
que el filtro del dueño muestra; lo oculto y lo que no entra queda en el
piso con dueño. El arma de fin de misión siempre va al inventario. El
suelo se vacía al cambiar de mapa (empezar misión / volver al pueblo);
dentro de una misión de varios pisos cada objeto queda en su piso
(§ 14.1). Tope 80 objetos en total, sumando todos los pisos: salen los
más viejos. Desde v0.20.11 lo propio que queda en el piso al cerrarse el
mapa (o al salir por el tope) vuelve al alijo del dueño (§ 4b.1). Eventos: `LootDropEvent`, `LootPickedEvent`; se siguen
emitiendo `WeaponDropEvent` (élite y fin de misión) y
`ChestOpenedEvent.weaponId` con la base, y `MissionResult.drops` /
`eliteDrops` guardan la base de la primera arma.

### 14.2 Materiales al tope (v0.8.5)

Bug corregido: con una pila de material en 99 (las Esquirlas se llenan
rápido), cada material nuevo quedaba en el piso porque "no entraba", y
nunca se podía levantar. Se acumulaban hasta el tope de 80 objetos del
piso y todo eso viajaba en cada snapshot (más ping).

- El loot **propio** de un material con la pila llena se toma igual:
  llena hasta 99 y lo que sobra se descarta. Nunca cae al piso, ni al
  entregarse ni al levantarlo (`SessionEngine._grantLoot`).
- Mensaje: `X obtuvo: … (Esquirla del Eco al tope de 99: lo que sobra se
  descarta)`. Si el filtro lo ocultaba, se descarta sin mensaje.
- Lo **compartido** (lo que alguien soltó) no se descarta: si no entra,
  queda en el piso para otro. Dar materiales (`give`) sigue rechazándose
  si el otro no tiene lugar.
- Pociones y éter no cambian.

### 14.3 Botín valioso con el inventario lleno (v0.20.11)

- Un arma o Eco **Épico o Legendario** de un **jefe o un élite**
  (`LootSource.boss` / `elite`) que no entra en el inventario no cae al
  piso: va directo al alijo (§ 4b.1). Mensaje: `X obtuvo: … (inventario
  lleno: <objeto> se guardó en el alijo)`; el dispositivo del dueño avisa
  si terminó en Objetos sin recoger.
- Lo demás que no entra sigue cayendo al piso con dueño (`inventario
  lleno: quedó en el piso`) y se recupera al cerrarse el mapa (§ 4b.1).
- Materiales al tope: sin cambios (§ 14.2, lo que sobra se descarta y el
  mensaje lo dice).

### 14.1 Loot por piso (v0.5.1)

Bug corregido: al bajar de piso, las etiquetas del loot del piso
anterior se seguían dibujando en el piso nuevo (en sus coordenadas
viejas) y no se podían levantar. Los pisos de una zona / Eco / Prueba
se pueden **volver a visitar** (escalera de subida, worldgen.md § 6.7),
y enemigos, cofres y sellos ya son por piso; el loot del suelo también:

- `GroundLoot.floor` = piso de la misión donde cayó (0 en el pueblo y
  en mapas de un solo piso). Lo pone el host al crearlo.
- `GameSession.groundHere` = solo lo del piso actual
  (`groundFloor` = `mission.floor`, o 0); `groundFor(id)` filtra sobre
  eso. Todo lo que dibuja o usa el cliente (etiquetas, haz, minimapa,
  `[E] Recoger`) pasa por `groundFor`, así que al cambiar de piso no
  queda nada del anterior en pantalla, sin cachés que limpiar.
- `PickUpAction` y el auto-levantar solo toman objetos del piso actual
  (un id de otro piso se rechaza aunque el jugador esté en esas
  coordenadas).
- Lo de los otros pisos sigue en `GameSession.ground` (y en el
  snapshot, con `f`): al volver a ese piso reaparece y se levanta.
- Al cambiar de piso, después de `Bajaron/Subieron al piso N/M.`, un
  aviso por jugador con lo que dejó atrás y su filtro muestra (suyo o
  compartido): `Quedan 2 objetos en el piso 1.` (`Queda 1 objeto …`;
  con más de un jugador `… objetos de Ana en el piso 1.`). Lo oculto por
  el filtro no cuenta. La escalera de bajada se toca sin confirmar, por
  eso el loot no se pierde: el aviso solo recuerda que quedó ahí.

## 15. Perfil v3 y migración

`PlayerProfile` guarda `items` (instancias), `eq` = `uid` equipado,
`mats` (materiales), `grid` (casillas), `lf` (filtro, texto), `seq`
(contador de `uid`: las armas nuevas son `i<n>`) y `pv: 3`. JSON
compacto de una instancia: `{u, b, r?, il?, a?: [[afijo, tier, valor]],
p?, pl?, f?: {pow, crit, spd, def}, s?: [habilidades], q?: único, n?:
nombre}`.

Migración (perfil sin `items`, v1/v2): cada id de `inv` → instancia
Común con `uid` = id de la base (`id#2`... si se repite), con sus
mejoras (`up`) y su fusión (`fuse`) como habilidad trasladada; `eq` (id
de base) → esa instancia. El árbol sigue con su propia migración (`tv`).
Las mejoras viejas se conservan aunque pasen el tope de forja de Común
(no se puede seguir forjando hasta bajar del tope).

Compatibilidad con la UI vieja: `inventory` (ids de base sin repetir),
`equipped` (base equipada), `upgrades`, `fused` y `upgradesFor` son
vistas derivadas; el constructor y `copyWith` aceptan la forma vieja.
Todas las acciones que reciben un `weaponId` aceptan `uid` o id de base
(instancia principal de esa base: la equipada si es de esa base, si no
la primera).

## 16. Forja y fusión

**Forja** (`CraftRules.forge`, `UpgradeAction`): sube 1 nivel una
estadística (Poder, Crítico, Velocidad; Defensa solo con escudo), tope 5
por estadística y tope total por rareza (§ 9). Costo del nivel `l → l+1`:
`round(max(precio, 200) × 0.22 × (l + 1) × factor de rareza)`. Cada 2
niveles totales la pasiva sube 1 (I → V).

**Fusión libre** (`CraftAction`, solo en lobby / preparación). El arma
que se sacrifica no puede ser la equipada ni la última del arma inicial
de la clase. Todas devuelven `CraftResult` (vista previa = resultado).
Desarmar, vender y reforjar base: § 21.

| Operación | Regla | Costo |
|---|---|---|
| Trasladar afijo | el destino tiene cupo (total y lado), el tipo lo admite y no lo tiene; no mods fijos | ₵100 × tier × rareza destino |
| Trasladar pasiva | de un Épico (no única) a un Épico; reemplaza la que tenía; conserva el nivel base | ₵300 × rareza |
| Trasladar habilidad | de las del arma sacrificada (base o trasladadas); el arma destino tiene que poder usarla (§ 16.1); con los cupos llenos el jugador **elige** cuál trasladada reemplaza (§ 16.2) | ₵200 × rareza (Común = la fusión vieja, ₵200) + **2 Cristales** si el destino es Raro o mejor (v0.15) |
| Quitar afijo | no mods fijos | ₵50 × tier × rareza |
| Agregar afijo (Cristal de Era) | no en Común; si hay lugar; afijo aleatorio del pool al nivel del objeto | 1 Cristal + ₵50 × rareza |
| Volver a tirar (Esquirla del Eco) | valores nuevos en el rango de cada tier (o del único) | 1 Esquirla + ₵25 × rareza |
| Subir rareza (Prisma Roto) | Común → Mágico → Raro → Épico, tira los afijos que falten para el mínimo y, al llegar a Épico, nombre y pasiva | 1 / 3 / 6 Prismas + ₵100 / 300 / 800 (v0.15; antes 1 / 2 / 4) |
| Condensar (v0.15, sin arma) | 10 Esquirlas → 1 Cristal; 10 Cristales → 1 Prisma; sin azar ni vuelta atrás; no pasa del tope de 99 (`CraftOp.condense`, `targetUid` = material que sale, `index` = cuántos) | ₵100 / ₵500 por unidad |

`tier` en los costos: T5 1, T4 2, T3 3, T2 5, T1 8. Las aleatorias sin
`RandomSource` devuelven solo costo, motivo y `outcomes` (qué puede
salir); el host las aplica con su azar. La fusión vieja (`FuseAction`)
es "trasladar habilidad".

### 16.1 Restricción por arma (v0.5.1)

Cada habilidad de arma tiene una **forma de entrega** explícita
(`kSkillDelivery`, `data/skills_catalog.dart`; `SkillDelivery`):

- `melee`: físicas de armas cuerpo a cuerpo (cortes, golpes, estocadas,
  dagas, incluida la Daga Saltarina y el Abanico de Dagas).
- `ranged`: físicas de arcos, ballestas y rifles (Flecha…, Disparo…,
  Bala…, Virote…, Tiro…, Ráfaga, Cadencia, Metralla, Lluvia de Flechas,
  Cero Absoluto, Saeta Glacial).
- `any`: todo lo que no es un golpe con el arma: mágicas, curas, regen,
  escudos, provocar, buffs y debuffs sin golpe (`SkillKind != physical`).

Cada tipo de arma tiene una **categoría** (`kWeaponTypeCategory`,
`data/weapons_catalog.dart`; `WeaponCategory`):

- `melee`: espada, hacha, lanza, dagas, espada+escudo, maza+escudo,
  martillo+escudo.
- `ranged`: arco, ballesta, rifle.
- `caster`: báculo, varita, tomo.

Regla: `melee` solo a armas `melee` ("Solo armas cuerpo a cuerpo"),
`ranged` solo a armas `ranged` ("Solo armas a distancia"), `any` a
cualquiera. Los casters no golpean ni disparan, así que solo reciben
habilidades `any` (el motivo dice qué arma necesita la habilidad). Las
habilidades **base** del arma no cambian. Los kits de ascensión nunca se
trasladan (no tienen entrega). Las partidas guardadas con habilidades
ya trasladadas que violan la regla **las conservan** (`sanitize` no las
toca): solo se valida el traslado nuevo.

### 16.2 Elegir qué habilidad se reemplaza (v0.5.1)

Con los cupos de trasladadas llenos (`rarity.skillSlots`) ya no se
reemplaza la más vieja sola: `CraftAction` lleva `replaceSkillId`
(JSON `rep`, aditivo). Sin elegir → "Elegí qué habilidad reemplazar".
`replaceSkillId` tiene que ser una de las **trasladadas** del destino
(`ItemRules.replaceableSkills`): una base → "Las habilidades base no se
reemplazan"; otra → "No tiene esa habilidad". Con cupo libre también se
respeta (el jugador eligió soltarla). Volver a traer una que ya está
trasladada no ocupa cupo. La vista previa dice lo que se pierde en
`CraftResult.replaced` (nombre) y `replacedSkillId`. La fusión vieja
(`FuseAction`) no elige: con los cupos llenos falla.

### 16.3 Ranura base de Quebrar (v0.9.1)

Pedido del dueño: Quebrar viene de base pero se puede quitar.
- Toda arma tiene una **ranura base de Quebrar** (Quebrar o Quebrar
  arcano según el tipo, `quebrarSkillFor`). `ItemRules.skillsOf` la
  lista al final (base, trasladadas, Quebrar), igual que el kit de
  batalla.
- `ItemRules.replaceableSkills` = trasladadas + Quebrar (si sigue). Al
  traer una habilidad con el arma llena, Quebrar se puede elegir
  (`replaceSkillId: 'quebrar'`): la trasladada **ocupa la ranura de
  Quebrar** y el arma queda sin Quebrar (`ItemInstance.quebrarReplaced`,
  JSON `nq: 1`). El cupo de trasladadas pasa a ser
  `skillCapacity = rarity.skillSlots + 1`. Mismo costo que un traslado.
- Quebrar **no se traslada** de otra arma (`canReceiveSkill`). Desde
  v0.20.12 el motivo es "Solo podés restaurar el Quebrar propio de esta
  arma" (Quebrar de otro tipo, o el arma no lo perdió) o "Usá Restaurar
  Quebrar: no hace falta sacrificar un arma" (es el suyo y lo perdió).
  Para recuperarlo: § 16.3.1.
- `sanitize` conserva `nq` y nunca deja Quebrar en `extraSkills`.
- **Migración versionada:** `kBalanceVersion` 1 → 2. Sin `nq` el arma
  tiene Quebrar, así que las armas viejas quedan con Quebrar en su
  ranura y no pierden nada; la migración solo sube `bv` (con su copia
  `account.pre-bv2-*.json`).
- En la mesa de fusión la tarjeta de Quebrar dice `Ranura de Quebrar` y
  el título `elegí una de las traídas o Quebrar`.
- Red: protocolo 15.

### 16.3.1 Restaurar Quebrar (v0.20.12)

Pedido del dueño: si se puede quitar Quebrar, se tiene que poder volver a
poner.
- Operación `CraftOp.restoreQuebrar` (mesa de fusión, grupo CAMBIAR,
  "Restaurar Quebrar"), sobre un arma con `quebrarReplaced`. Pone de
  nuevo **el Quebrar de su propio tipo** (`quebrarSkillFor(type)`: el
  arcano en lanzadores); nunca el de otro tipo. Sin arma sacrificada.
- Costo: `restoreQuebrarCredits` × `costFactor` de la rareza (por
  defecto ₵100 × factor; sin materiales). Editor → Balance → Materiales
  ("Restaurar Quebrar: créditos × rareza").
- Ranura: `quebrarReplaced` vuelve a `false` y el cupo de trasladadas
  vuelve a `rarity.skillSlots`. Si hay más trasladadas que ese cupo, el
  jugador elige cuál deja la ranura (`replaceSkillId`), que **se
  pierde** (como al reemplazar en § 16.2; sale en "Pierdes"). Sin
  elegir: "Elegí qué habilidad deja su ranura". Si entran todas, no se
  pierde nada.
- Sin `quebrarReplaced`: "Ya tiene su Quebrar".
- En batalla el arma vuelve a traer su Quebrar (`battle_engine`).
- Validado por el host (`CraftRules.apply`). Red: Mundo protocolo 33.

### 16.3.2 Quebrantador nombra su habilidad (v0.20.12)

Con un arma conocida, el afijo `ModStat.breakSkill` se muestra como
"<Habilidad> puede quebrar (T1)" (`ItemRules.affixText(r, on: item)`,
habilidad = `BreakRules.modSkillOf(base)`); si la base no tiene
habilidad de daño: "Sin habilidad que pueda quebrar". Sin arma, el texto
genérico. Las fichas agregan la línea "Quebrantador: la primera
habilidad de daño a un objetivo del arma que todavía no quiebra pasa a
poder quebrar".

## 17. Inventario y acciones

Grilla de 8 × 5 casillas por personaje (`InventoryRules.layout`): cada
arma no equipada y cada Eco ocupa 1. La grilla guarda las posiciones que
eligió el jugador; lo nuevo entra en la primera libre; lo que no entra
(perfiles viejos con más de 40 armas) queda en `overflow` y bloquea
recibir más. Tope de armas guardadas 80.

### 17.1 Secciones de pilas (v0.5.1)

Pedido del dueño: "que las pociones y consumibles estén en otra sección
del inventario". Desde v0.5.1 las **pilas no ocupan casilla**: van en
dos secciones fijas debajo de la grilla.
- **CONSUMIBLES** (`InventoryRules.consumables`): Poción de vida
  (`pot`) y Poción de maná (`eter`), tope 9.
- **MATERIALES** (`InventoryRules.materials`): Esquirla, Cristal, Prisma
  y Ancla (`mat:<material>`), tope 99.

Cada pila tiene su lugar fijo aunque esté en 0. Consecuencias:
- `tokens` / `cellsUsed` / `freeCells` cuentan **solo armas y Ecos**.
- `cannotReceive` de una pila mira solo el tope (`Máximo N`): con la
  grilla llena se sigue levantando, recibiendo (dar), comprando
  (`buyItem`, `ShopGuards.buyItem`) y sacando del alijo cualquier pila.
  Las armas y los Ecos siguen pidiendo casilla (`Inventario lleno`).
- El alijo no cambia: los materiales se apilan en una casilla del alijo
  (tope 999) y las pociones no van al alijo.
- **Migración**: un `grid` guardado con tokens de pila (`pot`, `eter`,
  `mat:...`) no pierde nada (las cantidades viven en `pot`, `eter`,
  `mats`); `layout` ignora esos tokens (la casilla queda libre) y
  `relayout` / `normalize` los borran del `grid`. Sin cambio de formato.

### 17.2 Ordenar (v0.5.1)

`SortInventoryAction(InventorySortKey)` (red: `{t: 'invSort', k:
<nombre>}`) reescribe la grilla en el orden de `InventoryRules.sortOrder`
desde la casilla 0 (`InventoryRules.sort`). Claves
(`models/inventory_sort.dart`):

| Clave | Orden (desempates en orden) |
|---|---|
| `rarity` Rareza | rareza ↓, nivel de objeto ↓, nombre |
| `itemLevel` Nivel de objeto | nivel ↓, rareza ↓, nombre |
| `weaponType` Tipo de arma | tipo (alfabético), rareza ↓, nivel ↓, nombre |
| `name` Nombre | nombre, rareza ↓, nivel ↓ |
| `recent` Últimos levantados | número del `uid` (`i<n>` / `eco<n>`) ↓; sin número, el orden de llegada al revés |

- **La equipada siempre primero**: `sortOrder` la devuelve en la
  posición 0; como no ocupa casilla (va en EQUIPADA, antes de la
  grilla), `sort` la deja fuera.
- Salvo en `recent`, primero todas las armas y después los Ecos (rareza
  ↓, tier ↓, más nuevo). En `recent` armas y Ecos van juntos.
- Nombre = `ItemRules.displayName` en minúsculas y sin tildes.
- **Determinístico**: el último desempate es el `uid`; no depende del
  orden de `items` (salvo `recent` sin número, que es el orden de
  llegada). Ordenar dos veces da lo mismo.
- El host la aplica como `MoveInventoryAction`: en cualquier modo y
  también con la sala en pausa (no toca el mundo).

### 17.3 La equipada no ocupa casilla

La equipada vive en su ranura EQUIPADA, fuera de la grilla: `tokens`,
`cellsUsed`, `freeCells` y `cannotReceive` no la cuentan (40 casillas
libres para lo demás). El tope de armas guardadas (80) sí la incluye.
Cambiar de arma intercambia: la que se deja entra en la grilla (si no
hay lugar, queda en `overflow` hasta liberar una casilla). Sin cambio
de formato (ya era así desde v0.5.1; v0.9.7 lo documenta y lo testea).

### 17.4 Marca NUEVO (v0.9.7)

- Perfil **v4** (`pv: 4`): `fresh` (JSON `nw`, opcional, lista ordenada
  de `uid`) = armas y Ecos recién levantados sin mirar. Un perfil v3 se
  lee igual (sin marcas): no hace falta migrar.
- `InventoryRules.receive` marca lo que entra (armas y Ecos; no las
  pilas). El alijo (`stash.dart`) recibe con `markNew: false`.
- `SeenItemsAction(uids)` (red: `{t: 'seen', u: [...]}`): saca la marca;
  la UI la manda al pasar el mouse por la casilla. Se aplica en
  cualquier modo y con la sala en pausa, como ordenar.
- `relayout` borra las marcas de lo que ya no está; `normalize` solo
  deja las de `uid` existentes.
- Protocolo **18** (`kProtocolVersion`, netcode.md).

Acciones nuevas (el host valida todo):
- `GiveItemAction(a, token, count)`: fuera de batalla, a otro jugador
  de la sala con lugar; token = `uid`, `pot`, `eter` o `mat:<material>`.
  No se da la equipada ni la última arma inicial.
- `DropItemAction(token, count)`: al piso compartido (lobby o campo).
- `PickUpAction(id)`: levantar del piso (propio o compartido, ≤ 24 px).
- `MoveInventoryAction(de, a)`: intercambiar casillas.
- `SortInventoryAction(clave)`: ordenar la grilla (§ 17.2).
- `SeenItemsAction(uids)`: sacar la marca NUEVO (§ 17.4).
- `CraftAction(op, uid, …)`: forja / fusión (§ 16).
- `SetLootFilterAction(texto | null)`: guardar el filtro (máx. 8000
  caracteres).

### 17.5 Pociones fuera de batalla (v0.12.2)

Pedido del dueño: poder usar las pociones en el lobby y en misión, no
solo en batalla. Mismo efecto que en combate, sobre el propio jugador:
- Poción de vida: +45% de la vida máx. (`jsRound`, sin pasar del máximo).
- Poción de maná: +50% del maná máx.

Acción `useItem` (`UseItemAction`, `{t:'useItem', it:'pot'|'eter'}`),
validada por el host con `ConsumableRules.blockReason`
(`rules/consumable_rules.dart`), que también usa la UI para el motivo de
desactivado:
- `En batalla, usa su menú` (modo batalla: ahí está el submenú de
  pociones de combat.md).
- `No te quedan` (pila en 0).
- `Vida llena` / `Maná lleno`.

Si pasa, el host descuenta la pila del perfil en la sesión y cura; el
snapshot lo lleva al cliente. Dónde se usa:
- Inventario, sección CONSUMIBLES: clic sobre la poción ya elegida, o
  clic derecho / `Enter` y la entrada `Usar` del menú de acciones
  (desactivada con el motivo).
- HUD del mundo: dos botones compactos encima de las cajas del grupo,
  `[1] Vida ×N` y `[2] Maná ×N` (motivo en el tooltip), y las teclas 1 y
  2 sin panel abierto. No se muestran en batalla.

Protocolo 23.

### 17.6 Éter (v0.21)

Consumible nuevo (`BattleItem.aether`, clave `eterV`, pila `StackKind.aether`
en CONSUMIBLES, tope 9 como las pociones; `PlayerProfile.aethers`,
`Combatant.aethers`, snapshot `eterV`). No confundir con la Poción de maná,
cuya clave histórica es `eter`.

- Efecto (solo en batalla): revive a un aliado caído con el 100% de su
  vida máx., quita Quemadura y Veneno, `RevivedEvent`, su próximo turno es
  `reloj + IV`. Objetivo: el caído elegido; sin objetivo válido, el primer
  caído del grupo. Sin caídos la acción no vale y no se gasta. Usa el
  flujo de pociones (`ItemCommand(BattleItem.aether, targetPlayerId)`),
  así que en co-op lo resuelve el host como cualquier acción.
- Fuera de batalla: `ConsumableRules.blockReason` devuelve `Solo en
  batalla, sobre un aliado caído`.
- Tienda: precio = `aetherMult` (5) × precio de la Poción de vida (30) =
  150 créditos.
- Cofres: del consumible de un cofre, la cola alta de la misma tirada
  (`r ≥ 1 − aetherChestChance`, 5%) da Éter en vez de Poción de maná
  (pociones de vida 60%, maná 35%, Éter 5%). No consume RNG extra.
- Compañero automático: si no tiene pociones de vida y hay un caído,
  usa Éter.

Números editables en Editor → Balance → Apoyo (`kTuning['consumables']`, junto con la sinergia de revivir):
`potionPrice` 30, `etherPrice` 40, `aetherMult` 5, `aetherChestChance` 0.05.

Protocolo 31.

## 18. Red

Ver netcode.md § "Loot instanciado". Decisión: el snapshot sigue siendo
uno solo para todos (sin cambiar `NetSession`): el loot del piso viaja
completo con su `ownerId` y cada cliente dibuja solo el suyo y el
compartido (`GameSession.groundFor`). No es un secreto (co-op entre
amigos): es una regla de presentación. Los inventarios viajan en los
perfiles (también los de los compañeros: se ven en solo lectura).

## 19. API para la UI

Estable (los nombres no cambian sin avisar). Todo en `lib/game_engine/`.
Acceso: `final rules = controller.engine.progression;` (`ProgressionRules`)
y `controller.engine` (`SessionEngine`). Las reglas son puras; para
**aplicar** algo la UI manda una `SessionAction` (el host valida). La UI
agrega en `SessionController` los atajos que quiera, p. ej.
`craft(CraftAction a) => _apply(a)`, `give(...)`, `dropItem(...)`,
`pickUp(id)`, `moveInventory(a, b)`, `setLootFilter(text)` (ninguno
existe todavía: `lib/features` es de la fase UI).

### 19.1 Modelo de arma — `models/item.dart`

```dart
enum Rarity { comun, magico, raro, epico, legendario }
  // .label ('Común'…), .minMods, .maxMods, .forgeCap (3/5/6/8/10),
  // .costFactor, .affixSideCap, .hasPassive, .skillSlots
enum ModStat { atkPct, magPct, flatAtk, flatMag, critChance, critMulti, speed,
  burnStacks, poisonStacks, freezeStacks, ultCharge, vit, esp, agi, fue, des,
  maxHp, maxMp, defense, healReceived, regen, statusResist, lifeSteal, healPower }
  // .label, .scale, String format(int value)  → '+12% ATQ'
class ItemMod { final ModStat stat; final int value; String get text; }
enum AffixSlot { prefix, suffix }
class AffixDef { id, name, slot, stat, tiers, weight, types; bool allows(String type); }
class AffixRoll { final String affixId; final int tier; /* 0 = fijo */ final int value; bool get fixed; }
class ItemInstance {
  final String uid, baseId; final Rarity rarity; final int itemLevel;
  final List<AffixRoll> affixes; final String? passiveId; final int passiveLevel;
  final WeaponUpgradeLevels forge; final List<String> extraSkills;
  final String? uniqueId, name;
  int get forgeLevel; int get effectivePassiveLevel; int get modCount;
}
enum CraftMaterial { esquirla, cristal, prisma } // .label, .description, maxStack = 99
enum CraftOp { transferAffix, transferPassive, transferSkill, removeAffix,
  addAffix, reroll, upgradeRarity, salvage, sell, reforge, salvageAll,
  sellAll }   // las 5 últimas: § 21
```
Base: `rules.catalog.weapons[item.baseId]` (`WeaponDef`: `name`, `type`,
`level`, `requirements`, `implicit`, `shieldDefense`, `skillIds`,
`classId` = familia). Desde v0.20.15 el arma no muestra ULT: conseguirla la enseña al
repertorio (`UltRules.taughtBy`, ultimates_v2.md § 2.1).

Textos — `ItemRules` (`rules/item_rules.dart`, `rules.items`):
```dart
String displayName(ItemInstance i)            // 'Espada Ígnea Feroz del Oso +2'
String affixText(AffixRoll r)                 // '+12% ATQ (T3)' / '(único)'
ItemMod? modOf(AffixRoll r); AffixDef? affixOf(AffixRoll r)
List<ItemMod> implicitMods(WeaponDef w)
(int, int)? rangeOf(ItemInstance i, AffixRoll r)
List<String> skillsOf(ItemInstance i)          // base + trasladadas
String? passiveText(ItemInstance i)            // 'Ímpetu II: Al hacer crítico…'
WeaponPassiveDef? passiveOf(ItemInstance i)    // .nameAt(l), .descriptionAt(l)
UniqueDef? uniqueOf(ItemInstance i)            // .flavor
int prefixCount(ItemInstance i); int suffixCount(ItemInstance i)
```
Colores por rareza: `LootFilterRules.rarityColor(Rarity)` (`FilterColor`).

### 19.2 Perfil — `models/player_profile.dart`

`p.items`, `p.equippedUid`, `p.equippedItem`, `p.itemByUid(uid)`,
`p.item(uidOrBase)`, `p.materials` / `p.material(CraftMaterial)`,
`p.potions`, `p.ethers`, `p.lootFilter` (texto o `null`). Vistas viejas:
`inventory`, `equipped`, `upgrades`, `fused`, `upgradesFor`.

### 19.3 Equipar y stats — `rules/progression_rules.dart`

```dart
bool canEquip(PlayerProfile p, String uidOrBase, {PlayerAttributes? attributes})
bool meetsRequirements(PlayerProfile p, WeaponDef w, {PlayerAttributes? attributes})
WeaponDef? baseFor(PlayerProfile p, String uidOrBase)
ItemInstance? equippedItem(PlayerProfile p)    // la que realmente usa
DerivedStats derivedStats(PlayerProfile p)     // .breakdown['ATQ'|'MAG'|'HP'|'MP'|'VEL'|'CRIT'|'DEF'].text
DerivedStats previewEquip(PlayerProfile p, String uidOrBase)   // antes → después
List<String> weaponSkills(PlayerProfile p, [String? uidOrBase])
String weaponDisplayName(PlayerProfile p, String uidOrBase)
```
Motivo de no poder equipar (la UI lo arma): `p.level < w.level` →
"Nivel N"; atributo `< requisito` → "Requisitos". Acción:
`EquipAction(uid)` (lobby / preparación).

### 19.4 Inventario — `rules/inventory_rules.dart` (estáticos salvo indicado)

```dart
static const columns = 8, rows = 5, cells = 40;
static ({List<String?> cells, List<String> overflow}) layout(PlayerProfile p)
  // token por casilla: uid de arma | uid de Eco (v0.5.1: las pilas no)
static int freeCells(PlayerProfile p); static int cellsUsed(PlayerProfile p)  // solo armas y Ecos
static const consumables = [StackKind.potion, StackKind.ether]   // v0.5.1
static final materials   // esquirla, cristal, prisma, ancla      // v0.5.1
List<String> sortOrder(PlayerProfile p, InventorySortKey k)       // equipada primero
PlayerProfile sort(PlayerProfile p, InventorySortKey k)          // instancia: rules.inventory
static int stackCount(PlayerProfile p, StackKind k)
static String? cannotReceive(PlayerProfile p, LootDrop d)   // motivo o null
bool isProtected(PlayerProfile p, String uid)            // instancia: rules.inventory
({PlayerProfile? profile, LootDrop? drop, String? error}) take(PlayerProfile p, String token, {int count = 1})
  // vista previa de dar / soltar; error = motivo ('Equipada', 'Arma inicial', 'No tienes tantos')
```
`StackKind` (`models/loot.dart`): `potion`, `ether`, `esquirla`,
`cristal`, `prisma` (`.token`, `.label`, `.maxStack`, `.material`,
`byToken`). Acciones:
```dart
MoveInventoryAction(int from, int to)               // intercambia casillas
SortInventoryAction(InventorySortKey key)           // v0.5.1, § 17.2
GiveItemAction(String toPlayerId, String token, {int count = 1})  // fuera de batalla
DropItemAction(String token, {int count = 1})       // lobby / campo, piso compartido
PickUpAction(int groundId)                          // E, ≤ SessionEngine.pickReach (24 px)
```
Ver el inventario de un compañero: `session.players[id].profile` (solo
lectura).

### 19.5 Forja y fusión — `rules/craft_rules.dart` (`rules.crafting`)

Todas devuelven `CraftResult` = vista previa y resultado:
```dart
class CraftResult { String? error /* motivo */; bool get ok;
  PlayerProfile? profile; ItemInstance? before, after; int credits;
  Map<CraftMaterial, int> materials; List<String> consumed /* uids destruidos */;
  String? replaced; List<String> outcomes /* aleatorias: qué puede salir */; }
CraftResult forge(PlayerProfile p, String uid, UpgradeStat stat)
CraftResult transferAffix(PlayerProfile p, String targetUid, String sourceUid, int index)
CraftResult transferPassive(PlayerProfile p, String targetUid, String sourceUid)
CraftResult transferSkill(PlayerProfile p, String targetUid, String sourceUid, String skillId, {String? replaceSkillId})
CraftResult removeAffix(PlayerProfile p, String uid, int index)
CraftResult addAffix(PlayerProfile p, String uid, {RandomSource? random})       // Cristal
CraftResult reroll(PlayerProfile p, String uid, {RandomSource? random})         // Esquirla
CraftResult upgradeRarity(PlayerProfile p, String uid, {RandomSource? random})  // Prisma
List<UpgradeStat> forgeStatsFor(WeaponDef w)
String? passiveAt(ItemInstance i, int forgeLevels)   // texto de la pasiva con N niveles de forja
static int forgeCost(WeaponDef w, Rarity r, int level)
static int transferAffixCost(AffixRoll a, Rarity target) / removeAffixCost / transferPassiveCost(Rarity)
static int transferSkillCost(Rarity) / addAffixCost(Rarity) / rerollCost(Rarity)
static (int prisms, int credits)? upgradeRarityCost(Rarity from)
```
Las aleatorias sin `random` devuelven `after == null`, `profile == null`
y `outcomes`; con `error` si no alcanza. Aplicar: `UpgradeAction(uid,
stat)` para la forja y `CraftAction(CraftOp op, String targetUid,
{String? sourceUid, int index = 0, String? skillId, String? replaceSkillId})` para el resto (solo
lobby / preparación). Odds del Cristal: `rules.loot.affixOdds(item)`.
Motivos posibles: 'No la tienes', 'MAX', 'Tope de forja (N)', 'Elige
otra arma', 'Está equipada', 'Arma inicial', 'Elige un afijo', 'Mod fijo
de un legendario', 'No sale en este tipo de arma', 'Ya tiene ese afijo',
'Sin lugar (…)', 'No tiene pasiva', 'Pasiva única', 'Solo a un arma
Épica', 'Elige una habilidad', 'Solo armas cuerpo a cuerpo', 'Solo armas
a distancia', 'Elegí qué habilidad reemplazar', 'Las habilidades base no
se reemplazan', 'No tiene esa habilidad', 'Un arma Común no lleva afijos', 'No tiene
afijos', 'Ya está en la rareza máxima', 'Falta <material>', 'Faltan $N'.
Desarmar, vender y reforjar: § 21 (con sus motivos).
Habilidades (§ 16.1–16.2), en `rules.items` (`ItemRules`):
`SkillDelivery? skillCategory(String id)` (`null` = no trasladable),
`WeaponCategory? weaponCategoryOf(ItemInstance)`, `String?
canReceiveSkill(ItemInstance weapon, String skillId)` (motivo o `null`),
`List<String> replaceableSkills(ItemInstance)` (las trasladadas) y
`bool needsReplaceChoice(ItemInstance target, String skillId)`.

### 19.6 Loot en el piso

`GameSession.ground` (`List<GroundLoot>`, todos los pisos),
`session.groundHere` (solo el piso actual), `session.groundFor(myId)`
(lo que ve cada jugador en el piso actual: el suyo + el compartido).
`GroundLoot`: `id`, `drop` (`LootDrop`: `item` o `stack` + `count`,
`isItem`), `x`, `y`, `ownerId` (`null` = compartido), `floor` (§ 14.1). Etiqueta: `engine.lootVerdict(profile,
drop)` → `FilterVerdict` (`visible`, `style`). Hoy
`SessionEngine.groundLoot == false` (loot directo al inventario; al piso
solo lo oculto por el filtro o lo que no entra); la fase de UI lo prende
en el composition root al dibujar el loot en el mapa. Eventos:
`LootDropEvent(playerId, drop, source, {groundId, uid})`,
`LootPickedEvent(playerId, groundId, drop)`, `ItemGivenEvent(fromId,
toId, drop)`, `CraftedEvent(playerId, op, uid)`.

### 19.7 Filtros — `models/loot_filter.dart`, `rules/loot_filter_rules.dart`

```dart
class LootFilter { final List<FilterRule> rules; }
class FilterRule { final bool show; final String? name;
  final List<FilterCondition> conditions; final FilterStyle style; }
sealed class FilterCondition { String get keyword; String get args; String get text; }
  // RarityCondition(FilterOp, Rarity), TypeCondition(List<String>), BaseCondition(List<String>),
  // FamilyCondition(List<String>), ItemLevelCondition(FilterOp, int), RelativeLevelCondition(FilterOp, int),
  // ModCountCondition(FilterOp, int), HasModCondition(String affixId, {FilterOp? op, int? tier}),
  // PassiveCondition(bool), MaterialCondition(List<CraftMaterial>), KindCondition(List<LootKind>),
  // UsableCondition(bool), BuildCondition({List<BuildMatch> kinds, bool has})
enum BuildMatch { base, mod, pasiva, habilidad }   // models/build_wants.dart
enum FilterOp { eq, ne, lt, le, gt, ge }   enum LootKind { arma, material, pocion }
class FilterStyle { FilterColor? textColor, borderColor, backgroundColor; int? size;
  String? sound; MapIcon? icon; }   // minSize 18, maxSize 45, defaultSize 32
class FilterColor { int r, g, b, a; }   class MapIcon { MapIconShape shape; MapIconColor color; }
const kLootFilterSounds = ['alerta','campana','gema','legendario','material','suave'];
class FilterVerdict { bool visible; FilterStyle style; int? ruleIndex;
  Set<BuildMatch> build; bool get buildMatch; }   // build: qué cumple de tu plan (★)

class LootFilterRules {           // const LootFilterRules({GameCatalog catalog})
  FilterParseResult parse(String text)          // .filter, .errors ('línea N: …'), .ok
  String serialize(LootFilter f)
  FilterVerdict evaluate(LootFilter f, LootDrop d, FilterContext ctx)
  LootFilter fromProfileText(String? text)
  static const String defaultText; static final LootFilter defaultFilter;
  static FilterColor rarityColor(Rarity r); static FilterStyle defaultStyle(LootDrop d);
}
class FilterContext { FilterContext({required int level, required PlayerAttributes attributes, String classId,
  BuildWants? wants}); }   // wants: resumen del plan de quien mira (null = sin plan)
// SessionEngine.lootVerdict(profile, drop, {BuildWants? wants})
```
Guardar: `SetLootFilterAction(String? text)` (`null` = por defecto).

**Provisorio**: nada de esta sección está marcado como provisorio salvo
el flag `groundLoot` (se prende en la fase de UI) y el lugar de las 4 ULT
nuevas (`kNewUltimates`, ver § 8.1).

## 20. Decisiones de la implementación (para revisar con el dueño)

1. Tiers de afijos hasta el nivel 40 (T1), no 30 (§ 9).
2. Prisma Roto sube hasta Épico (no solo Normal → Mágico → Raro);
   Legendario solo se encuentra.
3. Trasladar pasiva: solo a un Épico y no las únicas (los legendarios
   conservan su identidad).
4. Cupos de habilidades trasladadas: 1 (Común–Raro) / 2 (Épico,
   Legendario); llenos, el jugador elige cuál reemplaza (v0.5.1, § 16.2;
   antes era la más vieja).
5. Con el inventario lleno el loot cae al piso con dueño (no se pierde
   hasta cambiar de mapa).
6. Sin loot en el mapa todavía (`groundLoot = false`), lo oculto por el
   filtro no entra al inventario (sirve de "auto-descarte").
7. ~~La XP de las misiones actuales no escala con el nivel de zona~~
   v0.2.0: las misiones de zona usan el nivel real de la zona para el
   loot y la XP (worldgen.md § 6.3); `LootRules.zoneLevel` queda solo
   para misiones sin zona.
8. (v0.2.0) Sumideros de loot (§ 21): desarmar y vender destruyen; el
   tope de 99 por material se respeta y lo que sobra se pierde (avisado
   en la vista previa). Reforjar: cualquier tipo de base con nivel ≤
   nivel de objeto; no Legendarios. La equipada y la última arma inicial
   no se desarman, venden ni reforjan.

## 21. Sumideros de loot (v0.2.0)

Pedido del dueño: "qué hacer con el loot que no sirve para mi
personaje". Aprobado: **Desarmar en materiales**, **Vender por
créditos** y **Reforjar base** (no "loot inteligente"). Todo vive en
`CraftRules` (`rules/craft_rules.dart`) como operaciones nuevas de
`CraftOp`, se manda con `CraftAction` y devuelve `CraftResult` (vista previa = resultado). **Dónde** (v0.5): Desarmar, Vender y
Limpiar inventario (en lote) se pueden hacer en el pueblo, la
preparación **y durante la aventura** fuera de batalla
(`GameSession.canDiscard`); Reforjar base, como la fusión, sigue siendo
solo lobby / preparación (`canShop`). Ninguna se
puede hacer sobre la **equipada** (`Está equipada`) ni sobre la **última
instancia del arma inicial** de la clase (`Arma inicial`). UI: panels.md
§ "Inventario" (DESARMAR, VENDER, LIMPIAR INVENTARIO) y § "FUSIÓN"
(REFORJAR BASE).

### 21.1 Desarmar (`CraftOp.salvage`, `CraftOp.salvageAll`)

El arma se destruye y da materiales. Seguro, por rareza (`+1` = desde
nivel de objeto 25, `CraftRules.salvageHighLevel`), más **+1 Esquirla
cada 2 niveles de forja**; y una tirada extra:

| Rareza | Seguro | Puede salir |
|---|---|---|
| Común | 1 Esquirla (+1) | — |
| Mágico | 2 Esquirlas (+1) | 25% de +1 Cristal |
| Raro | 2 Esquirlas (+1) | 50% de +1 Cristal, 5% de +1 Prisma |
| Épico | 1 Cristal (+1) | 15% de +1 Prisma |
| Legendario | 1 Prisma + 2 Cristales (+1) | — |

`CraftRules.salvageYield(item)` → `SalvageYield(guaranteed, chances)`.
Sin tirada (Común, Legendario) el resultado es completo aun sin azar;
con tirada y sin `RandomSource`, vista previa: `gainedMaterials` = lo
seguro, `chances` / `outcomes` = lo que puede salir (`25% de +1 Cristal
de Era`). El host tira con su azar. Pila máx. 99: lo que pasa del tope
se pierde y va en `lost` (`2 Esquirla del Eco (tope 99)`).

**Lote** (`salvageAll`, `CraftAction.batch(op, rareza)`: `targetUid =
'*'`, `index = Rarity.index`): todas las armas de esa rareza menos la
equipada y la última inicial (`CraftRules.batchTargets`: si hay dos
iniciales, se va una). Las tiradas se agrupan (`25% de +1 Cristal de
Era (×3 armas)`). Sin armas: `No hay armas de rareza <R>`.

### 21.2 Vender (`CraftOp.sell`, `CraftOp.sellAll`)

El arma se destruye y da créditos: `max(10, round(valor(nivel de
objeto) × fracción + 25% de lo gastado en forja))`, con `valor(L) =
100·L + 4·L²` (la fórmula de precio de las bases) y fracción Común 10%,
Mágico 15%, Raro 25%, Épico 40%, Legendario 60%. Lo gastado en forja es
la suma de `forgeCost` de cada nivel que tiene. No hay arbitraje con la
tienda (una base Común se compra a `valor(L)` y se vende al 10%).
Ejemplos: Común nv 1 ₵10, Común nv 30 ₵660, Mágico nv 10 ₵210, Épico
nv 20 ₵1440, Legendario nv 50 ₵9000. Lote `sellAll` como en § 21.1.
Determinístico.

### 21.3 Reforjar base (`CraftOp.reforge`)

Cambia la base de un arma por **otra de cualquier tipo** con **nivel de
base ≤ nivel de objeto** (la misma regla con la que cae el loot) y
distinta de la actual. Así un Épico de arco que cayó para una maga se
vuelve báculo sin perder lo invertido. Se conservan rareza, nivel de
objeto, nombre generado, mods, pasiva, forja y habilidades traídas. Se
pierden (y la vista previa lo lista en `lost`):
- los mods que no salen en el tipo nuevo (`Mod +1 stack de Veneno al
  aplicar (T2) (no sale en espada)`);
- la pasiva si no está en el pool del tipo nuevo (§ 8.4; `Pasiva Ímpetu
  (no sale en báculo)`): el Épico queda sin pasiva hasta que se le
  traiga otra (determinístico: no se tira una nueva);
- la forja de Defensa si la base nueva no tiene escudo.

Costo (`CraftRules.reforgeCost`): créditos `round((100 + 25·nivel de
objeto) × factor de rareza)` y Común 1 Esquirla, Mágico / Raro 1
Cristal, Épico 1 Cristal + 1 Prisma (p. ej. Épico nv 20: ₵1200 + 1
Cristal + 1 Prisma). Legendario: no (`Un Legendario no cambia de base`:
la base es parte del único). `CraftAction.reforge(uid, baseId)` (la base
nueva viaja en `sourceUid`). Bases posibles:
`CraftRules.reforgeBases(item)` (de la más alta a la más baja). Motivos,
en orden: `No la tienes`, `Está equipada`, `Arma inicial`, `Un
Legendario no cambia de base`, `Elige una base`, `Ya tiene esa base`,
`Base de nivel N (el arma es de nivel M)`, `Falta <material>`, `Faltan
$N`.

### 21.4 API

```dart
enum CraftOp { …, salvage, sell, reforge, salvageAll, sellAll }
  // .destroys, .isBatch
class CraftResult { …; int gainedCredits; Map<CraftMaterial, int> gainedMaterials;
  List<MaterialChance> chances; List<String> lost; }
class MaterialChance { CraftMaterial material; double chance; int count, rolls; String text; }
static SalvageYield CraftRules.salvageYield(ItemInstance i)
CraftResult salvage(PlayerProfile p, String uid, {RandomSource? random})
CraftResult salvageAll(PlayerProfile p, Rarity r, {RandomSource? random})
CraftResult sell(PlayerProfile p, String uid) / sellAll(PlayerProfile p, Rarity r)
int sellPrice(ItemInstance i); int forgeSpent(ItemInstance i); static int itemValue(int itemLevel)
CraftResult reforge(PlayerProfile p, String uid, String baseId)
List<WeaponDef> reforgeBases(ItemInstance i)
static (int, Map<CraftMaterial, int>)? reforgeCost(ItemInstance i)
List<ItemInstance> batchTargets(PlayerProfile p, Rarity r)
const CraftAction.reforge(String uid, String baseId)
CraftAction.batch(CraftOp op, Rarity r)   // salvageAll / sellAll
ItemInstance.copyWith(baseId: …)          // nuevo parámetro
```
Red: `CraftAction` ya serializa `op` por nombre (`{'t': 'craft', 'op':
'sellAll', 'w': '*', 'i': 0}`); no cambia el formato. `SessionEngine`
solo suma el verbo del log de `reforge` (las que destruyen no tienen
`after` y no se anuncian). Tests: `test/game_engine/loot_sinks_test.dart`.

### 21.5 Elegir a mano (v0.5.1)

Pedido del dueño: "en limpiar inventario que haya una opción de
seleccionar". Además del lote por rareza, LIMPIAR INVENTARIO deja elegir
armas sueltas: `CraftOp.salvageSelected` / `CraftOp.sellSelected` con
`CraftAction.selected(op, uids)` (`targetUid = '*'`, la lista en
`CraftAction.uids`; red: clave `us`, aditiva en el protocolo 6 — sin
`us` el formato de siempre). Reglas (`CraftRules`):
- `selectedTargets(p, uids)`: en orden, sin repetir; **todas o
  ninguna**: si una no se puede, falla entera con el motivo de la
  primera (`No la tienes`, `Está equipada`, `Arma inicial`). Vacía →
  `Elige armas`; más de `maxSelected` (80) → `Máximo 80 armas`.
- Con dos armas iniciales se puede elegir una sola: la otra pasa a ser
  la última (`selectionBlock(p, uid, others: elegidas)` dice por qué no
  se puede elegir una casilla con las demás ya elegidas; la UI la
  muestra con candado).
- Resultado = el del lote con esa lista: `salvageSelected` agrupa las
  tiradas como `salvageAll` (vista previa sin azar = seguro + lo que
  puede salir) y `sellSelected` suma `sellPrice`. Vista previa =
  resultado. `CraftOp.isSelection`, `isBatch` y `destroys` son `true`;
  se puede donde `canDiscard` (no en batalla).

## 22. Ecos y Ancla Temporal (v0.4.0)

Spec propia: docs/specs/ecos_atlas.md. Lo que toca al loot:
- **Ecos** como objetos: `EcoItem` en `PlayerProfile.ecos` (JSON
  `ecos`), 1 casilla de la grilla cada uno (token = `uid`, `eco<n>`),
  `LootDrop.eco` (`{eco: {...}}`), se pueden dar, tirar y guardar en el
  alijo; no se equipan, venden ni desarman. Caen de enemigos de nivel
  ≥ 45 (batalla 2%, cofre 4%, élite 10%, jefe 30%) con su propio azar
  (`SessionEngine.ecoRandom`) para no cambiar el orden de las tiradas de
  siempre.
- **Dentro de un Eco** cada tirada de loot se repite `⌊1+Q⌋` (+1 con
  `frac`) veces y suma `R/100` al bonus de rareza (§ 2.2 del spec).
- **Ancla Temporal** (`CraftMaterial.ancla`, token `mat:ancla`): solo
  cae dentro de los Ecos; no entra en `materialChance` ni en el
  desarmado. Sube el tier de un Eco.
- **Filtro**: `Objeto Eco` (`LootKind.eco`), `Tier <op> n`
  (`TierCondition`), y `Rareza` / `Mods` también miran Ecos. El filtro
  por defecto tiene primero `Mostrar # Ecos` (turquesa, `gema`,
  `cuadrado celeste`).
- **Fortuna de Eras** (Atlas) multiplica el peso del Legendario:
  `LootRules.rarityOdds(..., legendaryMult)`.

## 23. Cofres y premios de la exploración (v0.6)

Pedido del dueño: "los cofres a veces dan cosas pero siempre solo dinero
o pociones". Dónde salen los cofres y las misiones: worldgen.md § 11.
Números en `lib/game_engine/data/exploration_catalog.dart`
(`kChestTiers`, `kThemeBaseWords`, `kQuest*`); tiradas en
`SessionEngine.openChest` / `_questReward`.

### 23.1 Calidad de los cofres (`ChestTier`, `MissionItem.tier`)

Quien toca el cofre lo abre, pero **cada jugador** tira lo suyo (loot
instanciado como las batallas; antes solo el que lo abría). El filtro de
loot de cada uno (con la condición `Build`) decide qué ve, como siempre
(`_deliver`); el loot va al piso actual (`GroundLoot.floor`).

| Calidad | Dónde | Créditos | Consumible | Armas | Materiales extra | Endgame |
|---|---|---|---|---|---|---|
| `madera` (un cofre) | lugares de cofre, 70% | 20–50 + 10 × rango | 30% | 45% (rareza de cofre) | — | — |
| `plata` (un cofre reforzado) | lugares de cofre 24%, marcas `c` de vault, salas secretas 60% | ×1.5 | 15% | 85%: la mitad de las veces una **base temática** de la zona; rareza +0.75 | 1 tirada más + 1 Esquirla | Eco 8% (nivel ≥ 46), Ancla 10% (en Ecos) |
| `oro` (un cofre dorado) | lugares 6%, custodiados por la élite, salas secretas 40% | ×2 | 10% | **1 Rara o mejor segura** (50% temática, rareza +1.5) + 30% de otra | 2 tiradas más + 2 Esquirlas | Eco 20% (≥ 46), Ancla 30% (en Ecos) |

- Consumible: 60% Poción de vida, 40% de maná. Las pociones/créditos
  pasan a ser lo de menos: la mayoría de los cofres reforzados y todos los
  dorados traen un arma.
- **Bases temáticas** (`kThemeBaseWords`): palabras del id de la base por
  generador (cavernas: escarcha/glacial/hielo/glaciar; grieta: ígnea/
  volcánica/infernal/fuego/dragón; laberinto: tiempo/eco/cronal…), de
  nivel ≤ nivel de objeto, con el peso de siempre (últimos 10 niveles ×3,
  familia del jugador ×2). Un Legendario rolado no usa base temática (sale
  su único).
- La calidad de cada cofre sale de `mulberry32(semilla + 13)` al empezar
  la misión (no mueve las tiradas de siempre); el contenido, del azar del
  host al abrirlo. Ecos y Anclas con `ecoRandom`.
- `ChestOpenedEvent.tier` (JSON `tr`).

### 23.2 Bendición de Fortuna

Mientras está activa (worldgen.md § 11.5), cada tirada de loot (`_rollFor`:
batallas, élites, jefe, cofres) suma +0.5 al bonus de rareza y tiene 30%
de una tirada extra.

### 23.3 Premio de las misiones opcionales

Por jugador (worldgen.md § 11.8), siempre al inventario (fuente
`mission`, como el arma de fin de misión):
- **Principal** (`QuestReward`, de la semilla del piso):
  - `arma` (55%): **Rara** (70%) o **Épica** (30%), nivel de objeto del
    piso como una élite (+1). Con plan de build, 60% de una base o tipo
    de arma del plan (`BuildWants.weaponBases` ×3 / `weaponTypes`); si no,
    base temática de la zona.
  - `eco` (25%): un Eco (tier como los drops: el del Eco actual o 1). Bajo
    nivel 45 pasa a `arma`.
  - `bendicion` (20%): una bendición de santuario distinta de la activa
    para el grupo (además del paquete de abajo).
- **Siempre**: 3 Esquirlas del Eco + 1 Cristal de Era (+50% de 1 Prisma
  Roto desde nivel 30, `kQuestPrismaChance`; +1 Ancla dentro de un Eco) y `60 + 6 × nivel del piso`
  créditos.

## v0.8.0: legendarios exclusivos y Esencia del Abismo

- `UniqueDef.exclusive`: los 6 legendarios de los Jefes del Abismo
  (Manecilla del Abismo, Espejo sin Fondo, Corona Invertida, Fauce de las
  Eras, Prisma Primordial, Filo Primordial) nunca salen de
  `LootRules.pickUnique`; los suelta su jefe (docs/specs/abyss_bosses.md
  § 3). Sin texto de ambientación.
- Materiales nuevos (`CraftMaterial`, pila 99): los 4 Fragmentos y la
  **Esencia del Abismo**. En el inventario y el alijo van en su propia
  sección **ABISMO**, que aparece recién cuando hay alguno.
- `CraftOp.essence` (MEJORAR): solo legendarios; cada mod fijo se tira 2
  veces dentro de su rango y queda el mayor, nunca por debajo del actual.
  1 Esencia, sin créditos.

## 20. Elemento de base del arma (v0.20.0)

Ver weapon_identity.md § 6. Resumen: `ItemInstance.element` (JSON `el`).
Legendario siempre (el de su tema, `kUniqueWeaponElement`); Épico 40 %;
Raro 15 %; Común y Mágico nunca. Bases con elemento en el nombre: desde
Raro siempre el suyo. Se tira antes que los mods (consume una tirada
desde Raro) y un Épico con elemento rueda 1 mod menos. Es una pasiva
fija: no se quita ni se cambia. `sanitize` migra los legendarios viejos
y descarta el elemento en Común/Mágico.

## 24. Equipo de oficios (v0.50)
Armas únicas de cada oficio, con marca de uid `gear-<id>-` que el
inventario conserva: profession_gear.md. Son armas normales (base por
tipo y nivel, afijos y pasiva legendaria por las reglas de siempre) con
una firma fija (`UniqueMod`) y nombre propio.
