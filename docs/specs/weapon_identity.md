# Identidad de las armas — APROBADO (implementado en v0.20.0)

Estado: **aprobado** por el dueño con las 6 recomendaciones de § 5 e
implementado (ver § 6, que manda sobre §§ 3-4 donde difieran). El arma
en mano por tipo ya existía (v0.19.1, sprites.md § "Armas en mano").

## 1. Qué diferencia hoy a un arma

| Eje | Dónde | Notas |
|---|---|---|
| Tipo (13) | `WeaponDef.type`, `lib/game_engine/models/weapon.dart:34-77` | decide arte en mano, categoría (melee/ranged/caster, :29), dúos y pool de pasivas/ULT |
| Base | `kWeapons`, `data/weapons_catalog.dart` | `atk`/`mag` (PowerFormula), `weight`, `shieldDefense`, `skillIds`, `implicit` |
| Rareza | `Rarity`, `models/item.dart:160-199` | nº de mods, tope de forja, pasiva desde Épico (:188), 2 ranuras de habilidad desde Épico (:191) |
| Mods (afijos) | `AffixRoll`, `item.dart:202`; `data/affixes_catalog.dart` | 25 `ModStat` (incluye pilas de quemadura/veneno/congelación, carga de ULT, quiebre) |
| Pasiva | `data/weapon_passives.dart:57-63`; `rules/loot_rules.dart:216` | Épico: aleatoria del tipo; Legendario: la única |
| Forja | `WeaponUpgradeLevels`, `weapon.dart:81-92` | pow/crit/spd/def; sube la pasiva (item.dart:473) |
| ULT | `ownWeaponUlt`, `data/branch_ults_catalog.dart:369-375` | propia > legendaria > por base > por tipo; mod "ULT: X" en Raro 8 % / Épico 20 % (:354) |
| Legendario/único | `UniqueDef`, `item.dart:316-350`; `loot_rules.dart:306-330` | mods fijos, pasiva única, texto, ULT fija opcional |
| Habilidades transferidas | `ItemInstance.extraSkills`, `item.dart:401-467` | por fusión |
| Nombre | `loot_rules.dart:219-233` | Raro/Épico "A B" de dos listas; Legendario el suyo; Común/Mágico el de la base |

Visual hoy: solo el color de rareza en el ícono de inventario
(`LootFilterRules.rarityColor`, `rules/loot_filter_rules.dart:118-124`;
`features/inventory/presentation/item_widgets.dart:22-39`) y la letra
M/R/E/L. En la mano, todas las armas del mismo tipo se ven iguales.

## 2. Elementos: armas vs habilidades (hoy)

- **El arma no tiene elemento.** `WeaponDef` no tiene ese campo.
- El elemento de un golpe (`rules/battle_engine.dart:1769-1779`):
  1. el que pase quien llama;
  2. si no, el que reacciona con el objetivo (Catalizador, `_catalystElement`, :2160);
  3. si no, `elementOf(skill.id)` (`data/elements_catalog.dart:222-224`).
- El **ataque básico es siempre físico**.
- Cada ULT trae su propio `element` (`models/ult_def.dart:71`). El de un
  dúo sale de su estado (`elementOfDual`, `elements_catalog.dart:227`).
- **La Convergencia** es una reacción que consume pilas de estados
  (`models/elements.dart:58-62`, :150). No es algo que dé el arma.
- La "afinidad" es solo débil/resiste del enemigo (`battle_event.dart:54`).
- Por eso la identidad elemental del arma hoy es indirecta: viene de sus
  habilidades, su ULT y sus afijos de pilas. No existe "elemento heredado".

## 3. Propuesta visual (sin un diseño por arma)

Capas que se suman sobre el ícono procedural del tipo, todas derivadas
de datos que ya existen o de un único campo nuevo:

1. **Aura de elemento**. Solo si el arma tiene elemento de base (§ 4):
   un halo de 1 px con el color del elemento (`ELFX`) y 2-3 partículas
   lentas de la forma del elemento. Sin elemento, sin aura. Es lo que
   pidió el dueño.
2. **Tinte por rareza**. El acento `g` del ícono (gema, púas, borde del
   escudo) toma el color de la rareza, que es la misma regla que el
   inventario. Común no tiene brillo; Épico suma la perilla `highlight`.
3. **Destello de legendario**. Un píxel blanco que recorre el filo cada
   ~2 s y una partícula dorada ocasional. Así se reconoce a distancia.
4. **Marca de ULT**. Si el arma trae ULT propia o el mod "ULT: X", un
   píxel rosa fijo en el pomo o el mango. Late cuando la ULT está lista.
5. **Variación por semilla del `uid`**. Dentro de la familia, un hash del
   uid elige entre 2-3 variantes de las perillas: matiz del metal ±,
   largo del mango ±1 celda, gema sí/no, y `mirror` en las dagas. Dos
   espadas raras se ven parecidas pero no idénticas. No hace falta red:
   el uid ya viaja en el perfil y el hash es determinista.
6. **Mods de pila**. Sin marca propia: ya los cubre el aura si el
   elemento coincide. Así se evita el ruido visual.

Costo: todo vive en `WeaponOverlay`/`paintItemIcon` y en las perillas del
Editor (§ 7.5). No hay sprites nuevos.

### 3.1 Ícono de las armas con escudo (v0.20.6)

En inventario, alijo, fusión, forja, tienda y tooltips, `espada+escudo`,
`maza+escudo` y `martillo+escudo` ya no comparten el escudo solo: cada
una tiene su forma 8 × 8 combinada en `kItemIconRows`
(`espada_escudo`, `maza_escudo`, `martillo_escudo`), igual que el
personaje en el mapa y la batalla (escudo en un brazo, arma en el otro).

- Escudo de 4 × 5 celdas a la izquierda (borde `m`, centro `g` = color
  de la rareza), una columna libre y el arma de pie a la derecha: espada
  con guarda, maza de cabeza redonda con púas `g`, martillo de cabeza
  ancha y plana. Se distinguen a 32 px por la silueta de la cabeza.
- `iconKeyForType` elige la forma combinada; `kItemEntryShapes` asigna
  cada entrada `items.<tipo>_escudo` a su forma, así que las perillas
  del Editor (metal, mango, brillo, contorno, espejo, escala, aura...)
  ajustan el ícono nuevo.
- Las capas de § 3 se aplican igual: aura en el contorno de ambas
  piezas, tinte de rareza en el escudo y las púas, destello del
  legendario sobre el metal, marca de ULT en el pomo (la última celda
  del mango) y variación por uid.
- El arma en mano (`WeaponOverlay`) no cambia: sigue dibujando
  `escudo` y el arma por separado.

## 4. Propuesta mecánica: "elemento de base" del arma

- Campo nuevo `ItemInstance.element` (o en `UniqueDef` para los
  legendarios). Es una **pasiva fija que no se puede quitar**: la fusión
  y el condensado no la mueven.
- Origen:
  - Legendarios: siempre fijo.
  - Épico: 40 %, elegido del pool del tipo (por ejemplo, báculo de fuego
    o hielo, arco de rayo).
  - Raro: 15 %.
  - Común y Mágico: nunca.
  - Algunas bases ya lo sugieren por el nombre (`baculo_fuego`,
    `lanza_escarcha`, `rifle_glacial`). Para esas, el elemento sería el
    de la base.
- Efecto propuesto, sencillo y legible:
  - **El ataque básico pasa a ser del elemento** y aplica 1 pila del
    estado cada 2 golpes. Las habilidades conservan su propio elemento.
  - **Sinergia**: las habilidades del mismo elemento que el arma hacen
    +8 % de daño. Con elemento distinto no hay penalidad, porque el arma
    sirve para *preparar* la reacción y la habilidad para detonarla.
  - **Convergencia**: el arma no la provoca sola. Sus pilas de básico
    sí cuentan, así que un arma de fuego más una habilidad de veneno
    prepara la reacción sin gastar maná.
  - **Afinidad enemiga**: el básico elemental respeta débil/resiste. Un
    enemigo que resiste castiga quedarse con un solo elemento.
- Balance:
  - Reemplaza parte del presupuesto de mods. Un Épico con elemento rueda
    1 mod menos.
  - El básico elemental no aplica pilas más rápido que la habilidad más
    barata del elemento.
  - Va en el `Combatant` del snapshot (`el` del arma). **Cambia la red y
    el esquema de guardado**: requiere subir `kProtocolVersion`.

## 5. Preguntas para el dueño

1. **¿El elemento de base solo cambia el ataque básico más un +8 % de
   sinergia, o también debería teñir las habilidades físicas del arma?**
   Recomiendo solo el básico más la sinergia: es simple y no pisa la
   identidad de las habilidades.
2. **¿Qué rarezas pueden traer elemento?** Recomiendo Legendario
   siempre, Épico 40 %, Raro 15 %, y Común y Mágico nunca, además de las
   bases con elemento en el nombre.
3. **¿El elemento se puede cambiar con la forja o algún material?**
   Recomiendo que no: "no se puede quitar". A lo sumo, un material muy
   raro del endgame que lo re-tire.
4. **¿El aura se ve siempre o solo en batalla?** Recomiendo siempre, en
   mapa, batalla y retratos, porque así se lee el arma de los
   compañeros en co-op. Que sea tenue para no tapar el sprite.
5. **¿Querés la variación por semilla del uid (dos armas iguales que se
   ven algo distintas), o preferís que el tipo + rareza sea idéntico
   para todos?** Recomiendo una variación suave: 2-3 variantes por
   familia y sin tocar la silueta.
6. **¿Marcamos la ULT del arma en el sprite (píxel rosa en el pomo) o
   alcanza con el inventario?** Recomiendo marcarla: ayuda a planear dúos
   en co-op.

## 6. Decisiones e implementación (v0.20.0)

Respuestas del dueño (las 6 recomendaciones):

1. El elemento de base cambia **solo el ataque básico** (+1 pila cada 2
   golpes, respeta débil/resiste y reacciona) y da **+8 %** a las
   habilidades del mismo elemento. Las habilidades físicas no se tiñen.
2. Legendario siempre; Épico 40 %; Raro 15 %; Común y Mágico nunca. Las
   bases con elemento en el nombre (`kBaseWeaponElement`) llevan siempre
   el suyo desde Raro. Un Épico con elemento rueda **1 mod menos**.
3. No se puede cambiar ni quitar (fusión, condensado, Prisma y forja lo
   conservan). Pendiente (fuera de alcance): un material muy raro de
   endgame que lo vuelva a tirar.
4. Aura siempre visible y tenue: mapa, batalla, retratos (HUD, PERSONAJE,
   ULT) e ícono de inventario. Así se lee el arma del compañero.
5. Variación suave por semilla del uid: 3 variantes (FNV-1a del uid % 3):
   0 = normal, 1 = metal más claro, 2 = metal más oscuro + gema. Misma
   silueta. Sin red nueva.
6. Marca de ULT: un píxel rosa en el pomo (última celda del mango) si el
   arma trae el mod "ULT: X" o es un legendario con ULT propia.

Además: el acento `g` toma el color de la rareza en la mano (mismo que
el inventario), los Épicos suman el reflejo y los Legendarios un
destello (un píxel blanco que recorre metal y gema, con una pausa
dorada).

Implementación:

| Pieza | Dónde |
|---|---|
| Campo | `ItemInstance.element` (JSON `el`, opcional) |
| Datos | `data/weapon_elements_catalog.dart`: chances, sinergia, pilas, `kBaseWeaponElement`, `kUniqueWeaponElement`, pools por tipo, `weaponElementOf` |
| Botín | `LootRules.rollElement` (antes de los mods), `generateUnique` |
| Migración | `ItemRules.sanitize`: el legendario recibe el elemento de su tema; Raro/Épico conservan el suyo; Común/Mágico lo pierden. Las armas viejas no legendarias quedan sin elemento |
| Motor | `BattleEngine._attack` (básico con `element:` y `_weaponElementStack`), sinergia en `_damageEnemy`; contador `Combatant.basicHits` (snapshot `bh`) |
| UI | tooltip: línea/sección "Elemento X (fijo)"; comparación: "Elemento: A → B" |
| Visual | `core/procedural/weapon_look.dart` (`WeaponLook`), `paintItemIcon(look:, time:)`, perillas `aura`, `aura_particles`, `sparkle`, `ult_mark`, `variation` del generador `item_icon` |

Red y guardado: el campo `el` del arma y `bh` del combatiente son
**aditivos** (un cliente viejo los ignora; un arma sin `el` se lee sin
elemento). No se subió `kProtocolVersion`, pero host y cliente deben ir
en la misma versión para que el básico elemental (que corre solo en el
host) y el aura coincidan. Los números (40 %, 15 %, +8 %, cada 2 golpes)
son constantes en el catálogo; hacerlos editables en Editor → Balance
queda pendiente (el parche de balance hoy solo cubre afijos, nodos y
mecánicas).
