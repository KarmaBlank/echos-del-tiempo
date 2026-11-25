# Spec: Roles del pueblo (v0.30.0)

## 0. Principio de diseño: el pueblo es 100 % opcional

Un grupo puede terminar el juego entero solo con mazmorras, botín y
fusiones, sin pescar, cultivar, construir ni reclutar habitantes. Los
roles del pueblo son un camino alternativo, nunca un requisito:

- Nada del camino crítico (abrir zonas, jefes, niveles necesarios, poder
  de equipo necesario) depende de los sistemas del pueblo.
- Los bonus del pueblo (habitantes, nodos de poder de los oficios,
  Herrería, encargos de forja) no se cuentan en el balance: el balance de
  solo mazmorras sigue como hoy, y lo del pueblo es un extra.

## 1. Visión

Quien prefiere la vida del pueblo (pescar, cultivar, forjar) tiene que
poder hacerse fuerte sin bajar a las mazmorras todo el tiempo, y llegar a
las últimas mazmorras de cada zona con el nivel y un equipo decente para
sumarse al grupo en el jefe.

- **Paridad de XP:** hasta los hitos de nivel de cada zona (10, 20, 30,
  40, 50), la XP de un rol del pueblo (subir el oficio, órdenes y
  encargos de los habitantes) tiene que ir a la misma velocidad que la de
  las mazmorras.
- **Los jefes siguen siendo la llave:** una zona nueva nunca se abre
  pescando o cultivando. Alguien tiene que pelear al jefe (worldgen.md
  § 6.4).
- **Simple de jugar, con profundidad para quien la quiera:** entregar
  una orden es un botón; elegir qué pescar o plantar para la próxima,
  subir la relación y juntar el encargo de forja es la profundidad.

## 2. XP de los oficios

- Subir de nivel Pesca o Cultivo da XP de personaje: `lifeLevelCharXp`
  × nivel nuevo, sin el tope por estadía (`charXpCap`, que sigue para la
  XP de cada captura o cosecha).

## 3. Órdenes de los habitantes

Cada habitante que vive en el pueblo pide una orden por día del mundo
(`orderEveryDays`), además de su cadena de encargos
(overworld_biomes.md § 10.2):

- Un día un pescado, otro algo de la tierra (producto silvestre o
  cultivo). Todos piden cosas de los oficios, no solo de su rol.
- Más difícil cuanto más alto el oficio más alto de la sala: rarezas
  hasta `nivel / orderRarityLevels`; desde `orderAnyBiomeLevel`, de
  cualquier bioma; con Cultivo en `orderQualityLevel`, a veces calidad
  rara o mejor.
- Entregar (en el pueblo): XP de personaje = valor × `orderXpPerValue`
  (tope `orderXpDayCap` por jugador y día, aparte del tope de captura),
  oro = valor × `orderGoldPerValue`, `orderRep` de relación y, cada
  `orderSkillEvery` órdenes del habitante, +1 punto de árbol
  (`PlayerProfile.treeBonus`, JSON `tb`). El detalle de la orden muestra
  todo eso antes de entregar.
- Nombre del ítem pedido (encargo u orden, también en el diario y el
  HUD): pescado, cultivo / silvestre, o material de minería y forja
  (mena, lingote, raro, herramienta, insumo: `data.materials.smith.<id>.name`).
  Nunca se muestra el id crudo; un id sin texto se muestra legible
  (`ingot_x` → "Ingot x"). Ícono: el `vida_<id>` de minería si es de
  forja. `residentItemName` / `QuestTrackRules.itemName`.
- Valor = precio de venta × cantidad × (1 + calidad pedida).
- Herrería (mining_smithing.md § 2.2): con Herrería en la sala, antes
  que todo lo demás puede pedir un arma forjada (tipo, rareza y nivel
  mínimos; desde `forgeOrderLevel`) y si no, un lote de lingotes. El
  arma la elige el jugador entre las que sirven; nunca la equipada. Da
  además XP de Herrería (`forgeOrderXp` × (rareza + 1)).
- Pescados con tamaño (v0.31.0): desde `orderSizeLevel` de Pesca, a veces
  piden "de N cm o más" (un cuarto, la mitad o tres cuartos del rango).
  La bolsa no guarda tamaños: vale el récord del bestiario.
- Los topes del día (XP de órdenes, encargo de forja, pedido del pescador
  nativo) se guardan en el mundo (`town.dy`).

## 4. Encargos de forja (Brann)

"Si me conseguís esto, te hago un arma de tu clase." Con Brann viviendo
en una casa:

- Costo: `comGold` × nivel del personaje, `comMat` tablas, fibras y
  cebos, `comLoot` del producto silvestre de la Grieta.
- Un arma de la familia de tu clase, de nivel de objeto = tu nivel −
  `comIlGap` (las mejores siguen saliendo de las mazmorras).
- Rareza: mágica; rara con oficio + relación × 2 ≥ `comRareScore`;
  épica desde `comEpicScore`; legendaria (un único de tu familia) solo
  con Brann arraigado, su objeto único y el oficio en `comLegendLevel`:
  la cadena larga.
- Uno por jugador y día del mundo. Lo valida el anfitrión.
- v0.44.0 (mining_smithing.md § 5): además, con Brann en su casa, la
  FORJA → HERRERÍA → BRANN arma un arma de la base que elijas con tus
  lingotes y materiales, por oro; la rareza tope es la de este encargo.

Además, con Brann en casa su menú tiene **Encargar arma** (la forja de
mining_smithing.md § 5.1), y su tienda vende materiales de Herrería
según la relación (overworld_biomes.md § 9.1.1).

## 5. Poder de aventurero en los oficios (v0.31.0)

Cada árbol de oficio suma nodos de poder que valen dentro y fuera de las
mazmorras (se suman al árbol de pasivas en `StatsCalculator` vía
`PlayerBuild.lifeHp` / `lifeAtk`):
- Pesca: Brazos de remo (vida +4 %), Arpón del eco (ATQ y MAG +4 %),
  Calma del lago (ambos +4 %, desde Maestro del lago).
- Cultivo: Espalda de surco, Hoz templada y Raíz firme (mismos números).
- Herrería: Temple, Filo del pasado y Mecanismo vivo.
Números en Balance → Oficios: árboles. Son un extra (§ 0): el balance de
solo mazmorras no los cuenta.

## 6. Herrería (v0.31.0)

Tercer oficio con árbol chico (8 nodos), en la pestaña OFICIOS.
- XP: `smithXpForge` por cada forja de estadística, `smithXpCommission`
  por encargo de forja de Brann, `smithXpCondense` por condensar (fuera
  de la Travesía). Curva `smithXpBase` × nivel^`smithXpExp`, tope
  `smithMaxLevel`.
- Cada nivel da XP de personaje (`lifeLevelCharXp` × nivel, § 2).
- Árbol: Aprendiz de fragua (raíz, XP), Martillo justo / Yunque antiguo /
  Maestro de la fragua (la forja cuesta menos, tope `smithForgeCap`),
  Ojo de oficio (XP; excluyente con Yunque antiguo), Temple / Filo del
  pasado / Mecanismo vivo (poder de aventurero).
- Descuento de forja total = Brann + Herrería (`ResidentRules
  .forgeDiscount`, tope 75 %); la forja lo muestra y valida igual que el
  anfitrión.
- El nivel de Herrería cuenta para la rareza del encargo de Brann.
- v0.44.0 (mining_smithing.md): la Herrería es un oficio de jugador
  completo. XP también por picar vetas (`mineXp`), fundir (`smeltXp`) y
  forjar armas desde cero (`craftXp`); misma curva y misma XP de
  personaje por nivel que los otros oficios (§ 2), así sube igual de
  rápido. El nivel abre rarezas (Mágico 4, Raro 10, Épico 18,
  Legendario 25).

## 7. Roles de exploración (v0.31.0)

- Pescador explorador: bestiario de pesca, primera captura, agua
  brillante y pescador nativo de cada bioma (fishing.md § 10 a § 12).
- Granjero y animales: especificado en farming.md § 13, sin implementar.
- Pendiente: que el pescador se quede afuera mientras el grupo baja a la
  mazmorra (party dividida, town_loop.md § 11b).

## 8. Encargos seguidos, DIARIO y marcas (v0.32.0)

### 8.1 Revelación

Un paso nuevo de la cadena de un habitante no aparece en ENCARGOS ni en
el DIARIO hasta que él lo pide en el diálogo (con el texto del paso).
Los pasos futuros nunca se listan. Al abrir el diálogo el cliente manda
`TownAction(seen, id)`; el anfitrión guarda en el perfil
`npcSeen[npc] = QuestTrackRules.newsKey(r)` (paso de la cadena, pedido y
orden). Si hay pedido u orden nuevos, el diálogo los menciona.

### 8.2 SEGUIR y DIARIO

Todo encargo, pedido u orden activo tiene SEGUIR / DEJAR DE SEGUIR
(`TownAction(track, target: '<tipo>:<npc>')`, validado por el anfitrión;
como mucho 5; JSON `trk` del perfil). El DIARIO (J en el pueblo o en el
campo, fuera de batalla y nunca mientras se escribe en el chat; botón
`DIARIO [J]` de la barra de arriba, clic en el recuadro del HUD o la
FUENTE) tiene la subpestaña SEGUIDOS y una por habitante conocido,
grilla con detalle a la derecha y avance "Tenés 1/2 X". Conocido = ya
habló con él al menos una vez (`QuestTrackRules.met`: tiene entrada en
`npcSeen`, que el diálogo siempre escribe); los demás no tienen pestaña
y la ganan al hablarles por primera vez (v0.32.2). Sin cambio de
guardado ni de protocolo. En el campo los objetivos se pliegan con O.

### 8.3 HUD y avisos

Debajo del reloj, un recuadro compacto con cada seguido (nombre y
avance). Cuando sube lo que tenés de algo que pide un encargo activo,
aparece unos segundos "Para: Ilda · encargo 3 (1/2)".

### 8.4 Marcas sobre la cabeza

Por jugador, en el pueblo y en los biomas: "!" dorado
(`TownPalette.request`, con rebote chico) si tiene algo nuevo que todavía
no te contó; "?" si tenés listo lo que pide; nada si no. Reemplaza el
"!" genérico. Las subpestañas del DIARIO llevan la misma marca.

## 8.5 Editor

Las reglas de órdenes, pedidos y encargos de forja se ven y ajustan por
habitante en el Editor → NPC → PEDIDOS (npc_editor.md § 4), con
ejemplos generados para un nivel elegido.

## 9. Pendiente

Ver tech_debt.md v0.31.0 (paridad de XP sin simular, animales, party
dividida).
