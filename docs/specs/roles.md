# Spec: Roles del pueblo (v0.30.0)

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
- Valor = precio de venta × cantidad × (1 + calidad pedida).

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

## 5. Encargos seguidos, DIARIO y marcas (v0.32.0)

### 5.1 Revelación

Un paso nuevo de la cadena de un habitante no aparece en ENCARGOS ni en
el DIARIO hasta que él lo pide en el diálogo (con el texto del paso).
Los pasos futuros nunca se listan. Al abrir el diálogo el cliente manda
`TownAction(seen, id)`; el anfitrión guarda en el perfil
`npcSeen[npc] = QuestTrackRules.newsKey(r)` (paso de la cadena, pedido y
orden). Si hay pedido u orden nuevos, el diálogo los menciona.

### 5.2 SEGUIR y DIARIO

Todo encargo, pedido u orden activo tiene SEGUIR / DEJAR DE SEGUIR
(`TownAction(track, target: '<tipo>:<npc>')`, validado por el anfitrión;
como mucho 5; JSON `trk` del perfil). El DIARIO (J en el pueblo, clic en
el recuadro del HUD o la FUENTE) tiene la subpestaña SEGUIDOS y una por
habitante, grilla con detalle a la derecha y avance "Tenés 1/2 X".

### 5.3 HUD y avisos

Debajo del reloj, un recuadro compacto con cada seguido (nombre y
avance). Cuando sube lo que tenés de algo que pide un encargo activo,
aparece unos segundos "Para: Ilda · encargo 3 (1/2)".

### 5.4 Marcas sobre la cabeza

Por jugador, en el pueblo y en los biomas: "!" dorado
(`TownPalette.request`, con rebote chico) si tiene algo nuevo que todavía
no te contó; "?" si tenés listo lo que pide; nada si no. Reemplaza el
"!" genérico. Las subpestañas del DIARIO llevan la misma marca.

## 6. Pendiente

Ver tech_debt.md v0.30.0 (tamaños en las órdenes, nodos de poder de
aventurero en los árboles de oficio, rol de Herrería, verificación de la
paridad de XP).
