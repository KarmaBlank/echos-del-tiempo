# Identidad de las armas — BORRADOR (análisis, sin implementar)

Estado: propuesta para el dueño. Nada de esto está en el código salvo
lo marcado como "hoy". El arma en mano por tipo ya existe (v0.19.1,
sprites.md § "Armas en mano").

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
