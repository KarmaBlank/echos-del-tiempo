# Spec (APROBADA por el dueño): Elementos y reacciones — v0.7

Pedido del dueño: "la siguiente evolución, tanto para el árbol como para
la batalla, serían elementos. Si tirás fuego y agua no pasa nada; fuego
y rayo, nada. Pero agua y luego electro: electrocuta, queda en shock
(parálisis o más daño). Veneno y luego fuego: explota, consume los
stacks de veneno pero hace mucho daño (por ejemplo 3× el daño de la
habilidad de fuego)."

## 1. Elementos

| Elemento | Estado que deja | Hoy existe |
|---|---|---|
| Fuego | Quemadura | sí |
| Hielo | Congelación | sí |
| Veneno | Veneno | sí |
| Sagrado | Sagrado | sí |
| **Agua** | **Mojado** (nuevo, 2 turnos, no hace daño) | no |
| **Electro** | **Cargado** (nuevo, 1 turno, no hace daño) | no |
| Físico | — | sí |

Cada habilidad, ULT, pasiva o proc tiene **un** elemento (tabla en el
catálogo, como `kSkillDelivery`). Las magias de la Maga y la
Elementalista se reparten entre Fuego, Hielo, Agua y Electro; las armas
de veneno (dagas, ballestas) llevan Veneno.

## 2. Reacciones (el segundo elemento "detona" al primero)

| Primero (estado en el enemigo) | Después (golpe) | Reacción | Efecto (valores a ajustar con el admin de balance) |
|---|---|---|---|
| Mojado | Electro | **Electrocución** | aturde 1 turno y el golpe hace ×1.5; consume Mojado |
| Veneno | Fuego | **Explosión tóxica** | consume todos los stacks de Veneno; daño extra = daño del golpe de fuego × (1 por stack, máx. ×3) a ese enemigo, y 50% de eso a los demás |
| Mojado | Hielo | **Congelación súbita** | Congelación completa al instante (pierde el turno); consume Mojado |
| Congelación | Fuego | **Derretir** | el golpe hace ×1.5 y quita la Congelación |
| Cargado | Agua | **Cortocircuito** | el golpe salta a 1 enemigo más con 50% (como rebote) |
| Fuego + Agua, Fuego + Electro, Hielo + Electro… | — | **ninguna** | no pasa nada (pedido del dueño) |

- Una reacción por golpe; la consume el elemento que detona.
- En grupo, el estado lo puede dejar un jugador y detonarlo otro: premia
  coordinarse (foco co-op).
- Familias de enemigos (bestiary.md): un Elemental ígneo es inmune a
  Quemadura, así que con él no hay Explosión tóxica por fuego; los
  Constructos no se envenenan. Se respeta la tabla de familias.

## 3. Interfaz

- Íconos de estado nuevos (gota = Mojado, rayo = Cargado).
- Cartel de reacción sobre el enemigo ("¡ELECTROCUCIÓN!") + sonido propio,
  y línea en el registro con el cálculo.
- En el tooltip de una habilidad: "Elemento: Agua · reacciona con Electro
  (Electrocución) y Hielo (Congelación súbita)".
- Ficha del enemigo / bestiario: muestra si es inmune a algún estado que
  corta una reacción.

## 4. Árbol y builds

- Notables por reacción en los clusters de Maga (Brasa, Escarcha,
  Prisma) y en los de veneno del Tirador (Toxina), p. ej.: "Tus
  Electrocuciones aturden 2 turnos", "La Explosión tóxica deja
  Quemadura", "Mojar a un enemigo te da +10% de ULT".
- Ascensión Elementalista: su kit pasa a ser el de reacciones.

## 5. Decisiones del dueño

1. **Agua y Electro entran como elementos nuevos**, con habilidades y
   armas nuevas. Hielo sigue siendo Hielo.
2. **Explosión tóxica: ×1 por stack, sin tope.** Quemadura y Veneno se
   pueden acumular sin límite, para que acumular sirva de algo.
3. **Las reglas son simétricas**: todo lo que aplica a los enemigos
   aplica a los jugadores (estilo Divinity: Original Sin 2). Los
   enemigos pueden mojarte, electrocutarte o detonar tu veneno, y las
   reglas de familia valen para ambos lados.
4. **Más adelante: razas de personaje** con las mismas reglas que las
   familias de enemigos (p. ej. un personaje no muerto recibe daño de
   las curas). El motor debe tratar "familia/raza" igual para jugadores
   y enemigos desde la v0.7 aunque las razas lleguen después.

## 6. Stacks sin tope (Quemadura y Veneno)

- Se quita el máximo de stacks de Quemadura y Veneno.
- El daño por turno de cada stack sigue igual que hoy, así que acumular
  ya rinde solo; la reacción lo multiplica.
- Explosión tóxica: daño extra = daño del golpe de fuego × stacks de
  Veneno consumidos (×1 por stack, sin tope); 50% de salpicadura a los
  demás enemigos.
- Para que un jefe no se borre de un golpe: contra jefes, la explosión
  hace como máximo un % de su vida máxima por detonación (propuesta: 25%),
  ajustable desde el admin de balance.
- Todos los valores quedan en el catálogo, editables desde el admin.

## 7. Qué es el Hielo (propuesta)

Hoy la Congelación se acumula y, al llegar a 5, el enemigo pierde el
turno: en la práctica es un aturdimiento lento. Propuesta para que el
Hielo tenga identidad propia, distinta del aturdimiento:

- **Ralentiza:** cada stack de Congelación baja la velocidad del enemigo
  (−6% por stack): sus turnos llegan más tarde y tu grupo actúa más
  seguido. Es control del timeline, no un turno perdido.
- **Quebradizo:** un enemigo con Congelación recibe más quiebre
  (+10% por stack). El Hielo prepara el quiebre del grupo.
- **Congelado (5 stacks):** pierde el turno y queda **Quebradizo**: el
  próximo golpe físico hace ×1.5 y consume la Congelación. Así el Hielo
  "arma" el golpe fuerte de un guerrero o tirador (combo de grupo).
- **Después de descongelarse**, 2 turnos de resistencia (no se vuelve a
  congelar enseguida), para que no se pueda encadenar.
- Reacciones con Hielo: Mojado + Hielo = Congelación súbita; Congelado +
  Fuego = Derretir (×1.5).

Aturdimiento, en cambio, sigue siendo el control "por probabilidad":
corta un turno ya, sin preparación.

## 8. Contrato para la implementación (v0.7)

Nombres fijos para que motor, contenido y presentación trabajen en
paralelo:

- `enum GameElement { fisico, fuego, hielo, veneno, sagrado, agua, electro }`
  en `lib/game_engine/models/elements.dart` (se llama `GameElement` y no
  `Element` para no chocar con la clase `Element` de Flutter);
  `elementOf(skillId)` (tabla `kSkillElement` en
  `lib/game_engine/data/elements_catalog.dart`, como `kSkillDelivery`).
- `StatusKind.wet` ("Mojado", 2 turnos, sin daño) y
  `StatusKind.charged` ("Cargado", 1 turno, sin daño).
- `enum ReactionKind { electrocucion, explosionToxica,
  congelacionSubita, derretir, cortocircuito }`.
- Evento `ReactionEvent(targetId, kind, amount, {sourceId,
  consumedStacks, splash})`, serializado como evento de batalla
  `{"k":"react", ...}` (los eventos de batalla usan la clave `k`; `t` es
  la del mensaje). `splash` es `Map<id, daño>`.
- Ids de sonido: `sfx.reaction.<kind>`; ids de ícono de estado:
  `status_wet`, `status_charged`.
- Familia/raza simétrica: `Combatant.family` vale para jugadores y
  enemigos (jugadores: `null` hasta que existan razas).

## 9. Implementación (v0.7.0)

Lo que quedó en el código (el resto del spec sigue mandando):

- **Elemento de un golpe.** Habilidades / ULT: `elementOf(id)`. Ataque
  normal y golpes sin elemento: `fisico` (no reacciona). Dúo: el de su
  estado. Enemigos: `kEnemyElement[tipo]`, si no el elemento del estado
  que aplica ese golpe, si no físico; ULT enemigas igual
  (`kEnemyUltElement`). El daño de las mecánicas (rebotes del árbol,
  Combustión, trampas, Eco Arcano) y los ticks de estados **no**
  reaccionan; los rebotes / atraviesa de las variantes sí (son golpes de
  la habilidad).
- **Cuándo.** La reacción se decide antes de calcular el golpe (el ×1.5
  entra en el golpe, log `× 1.5 ELECTROCUCIÓN`), se resuelve después de
  su `DamageEvent` y **antes** de que el golpe aplique su propio estado
  (Chorro sobre un Cargado: Cortocircuito y después Mojado). Una por
  golpe; prioridad = orden de la tabla de § 2.
- **Números (catálogo `kReactions`, editables: `BalanceKind.reaction`):**
  Electrocución ×1.5 + 1 turno de Aturdido; Explosión tóxica `golpe × 1 ×
  stacks` al objetivo, 50% de eso a cada otro del **bando del objetivo**,
  tope contra jefes 25% de su vida máx. por objetivo; Congelación súbita
  lleva la Congelación a 5 (pierde su próximo turno; no reacciona si no se
  puede congelar: resistencia, inmunidad, ya congelado); Derretir ×1.5 y
  quita la Congelación (si estaba Congelado, resistencia); Cortocircuito
  50% al siguiente vivo de la formación y le lleva el estado del golpe.
  El daño extra es directo (`DamageEvent.sourceId = reaction.<kind>`,
  sin crítico ni Marca; a un jugador lo absorben sus escudos).
- **Mojado / Cargado** (`kElementStatuses`, `BalanceKind.elementStatus`):
  su valor son turnos (no se acumulan, se renuevan a 2 / 1); bajan 1 al
  empezar el turno del afectado.
- **Hielo** (§ 7): `ElementStatusDef freeze`: −6% velocidad y +10%
  quiebre por stack, Quebradizo ×1.5, resistencia 2 turnos propios
  (`Combatant.brittle`, `Combatant.freezeResist`, `IceEvent`). Con 5
  stacks pierde el turno y queda Quebradizo (la Congelación sigue en 5);
  el próximo golpe **físico** (ataque, habilidad física o golpe enemigo)
  hace ×1.5 y lo descongela; si nadie lo rompe, al empezar su turno
  siguiente se descongela solo (con Alma de Hielo, no). Choque Térmico
  sigue aturdiendo cuando el fuego derrite (Derretir le quitó la
  Congelación antes).
- **Simetría** (§ 5.3–5.4): `Combatant.family` (enemigos: la de su tipo;
  jugadores: `null`). Inmunidades, stacks, daño por tipo (los golpes
  enemigos son físicos + su elemento), Sagrado por turno y "las curas
  dañan" (Cura, Regeneración y su tick) valen igual para un jugador con
  raza. Las reacciones también le pasan a los jugadores.
- **Elementalista (v0.7, ascension.md § 4.1):** kit de reacciones.
  Prisma (neutro) deja Mojado + Cargado; Detonar y Trinidad son
  **catalizadores** (`SkillDef.catalyst`: el golpe toma el elemento que
  reacciona con lo que tenga el objetivo y, si detona, ×1.3).
  `kElementalStatuses` (Contagio, Detonación de la v0.5) sigue siendo
  Quemadura / Congelación / Veneno.
- **Árbol (§ 4):** 15 notables de reacción y de familia en el árbol v5
  (passive_tree_v4.md § 8), con los disparadores `onReaction`,
  `onPrimedReaction` (quién preparó: `Combatant.primedBy`, JSON `prim`)
  y `onPartyReaction`.
