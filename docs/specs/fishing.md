# Spec: Pesca y agropecuario (fase 3 de town_loop.md, v0.22.0; en el mapa y botín del agua desde v0.22.2)

Precisa town_loop.md § 3.1 (pesca), § 3.3 (comercio), § 10 (red), § 10b
(solo y pocos clics), § 11c (habilidades de vida y herramientas) y § 12.
Solo el Mundo: la Travesía no tiene pueblo (rechaza todas las acciones).

Código: datos en `lib/game_engine/data/fishing_catalog.dart`, reglas
puras en `lib/game_engine/rules/fishing_rules.dart`, minijuego puro en
`lib/game_engine/rules/fishing_minigame.dart`, sala en
`session_engine_fishing.dart`; lance en el mapa en
`lib/game_engine/rules/map_fishing.dart` (`FishingCast`, `MapFishing`);
dibujo en `map/fishing_layer.dart`; agropecuario en
`panels/trader_panel.dart`. Tunables: Editor → Balance → **Pesca**
(`TuningId.fishing`).

## 1. Dónde

- Desde v0.22.2 **no hay ventana de pesca**: se pesca en el mapa, desde
  cualquier tile de la orilla del lago mirando al agua (o al costado si
  hay agua; `FishingCast.castDir`). Los tres muelles (`f`,
  `TownLayout.fishingSpots`) dan `dockBonus` (0.1) de rareza.
- El cartel del lago (`Y`): aviso local con la cantidad de especies del
  lago y tu nivel de Pesca.
- El puesto del agropecuario (`M`): E abre AGROPECUARIO.
- Se quitaron los avisos "Pronto".

## 2. Peces

`FishDef {id, name, rarity, biome, minCm, maxCm, price, xp, lore}`.
Rarezas: común, raro, épico, legendario.

### 2.1 Biomas y el lago del pueblo
- Cada especie tiene `biome` (`zona1` … `zona10`). Hoy solo existen las
  de `zona1`.
- El lago del pueblo es **del mundo**: `TownState.lake` (lista de ids;
  `null` = las de `zona1`, `kTownLakeDefault`). El anfitrión lo carga con
  `SessionEngine.setWorld(lake:)` y tira los peces solo de esa lista.
- Desde v0.24.0 el pueblo puede tener varios lagos (`town_editor.md`
  § 5): la lista de especies vale para todos, pero cada lago suma sus
  propios peces soltados, su tamaño y su cría; se pesca en el más
  cercano. Al fundirse dos lagos se juntan sus peces.
- **Futuro (no implementado):** cada bioma tendrá su exterior con lagos
  y especies propias. Un pez de otro bioma se podrá convertir en
  "Cría de <pez>", un objeto que suma esa especie a `TownState.lake`.
  No hace falta tocar reglas: solo agregar la especie a la lista.

### 2.1b Lago del Bosque (v0.26.0)

El exterior del Bosque tiene su lago con tabla propia (`kForestFish`):
Mojarra de sombra, Bagre de raíz, Trucha musgosa, Lucio rúnico y el
legendario Salmón del Eco Quieto; basura propia (Hojarasca mojada). Sin
bonus de lago del pueblo. Ver `overworld_biomes.md` § 3.1.

### 2.2 Tirada (anfitrión)
- Rareza por pesos `weightComun/Raro/Epico/Legendario` (70/22/7/1). Los
  no comunes × (1 + bonus de rareza), con bonus = rareza efectiva de la
  caña + `distanceBonus` (0.3) × carga del lance.
- Especie al azar entre las del lago de esa rareza (si no hay, baja una
  rareza). Tamaño uniforme en `[minCm, maxCm]`.
- Pity: `pityAfter` (200) capturas sin legendario → legendario seguro.
  La auto-pesca no suma ni consume pity.

### 2.3 Legendarios (tema de ecos)
Carpa del Mañana (eco del futuro), Esturión de la Era Antigua (del
pasado avanzado) y Pez del Reloj Quieto. Nombres propuestos; esperan el
OK del dueño (lore.md).

## 3. Pesca del personaje

`PlayerProfile.life` (`LifeSkills`, JSON `life`): `fx` XP total de
Pesca, `rods` cañas propias, `rod` la equipada, `bag` bolsa de Pescados
(especie → cantidad, apilable, aparte del inventario de armas), `pity`.

- Nivel: XP para pasar del nivel l = `xpBase` × l^`xpExp` (40, 1.5);
  tope `maxLevel` (30).
- XP de Pesca por captura = `xp` de la especie × `xp<Rareza>` (1 / 2.5 /
  6 / 15) × tamaño relativo (cm / promedio, entre 0.5 y 1.6).
- XP de personaje: `charXp<Rareza>` (2 / 5 / 12 / 30) con tope
  `charXpCap` (60) **por estadía en el pueblo** (se reinicia al volver de
  una misión: "por misión del ciclo" de town_loop.md § 11c).
- PERSONAJE (pestaña ATRIBUTOS) muestra una línea OFICIOS: nivel, XP,
  caña y cantidad de pescados.
- Migración: un perfil sin `life` recibe la Caña de rama equipada.

## 4. Minijuego (local, puro) y pesca en el mapa

### 4.0 En el mapa (v0.22.2)

- Controles: E (o Espacio) en la orilla saca la caña (caña en la mano).
  Mantener E o el clic carga (medidor sobre el personaje); soltar tira.
  La boya vuela 1 .. `maxCastTiles` (5) tiles en la dirección que mira y
  cae en ese tile del lago; si el tile no es agua (pasó el lago) el lance
  se pierde ("Cayó en la orilla."). E / clic clava la picada y, en la
  pelea, mantener sube la zona. R: auto-pesca con la caña afuera.
  Caminar o Esc guarda la caña (en plena pelea cuenta como escapado).
- En el mapa: sombras de peces que nadan solo por tiles de agua (las
  cercanas se acercan a la boya), la boya tiembla con los señuelos, en la
  picada "!" sobre el personaje y sonido, la barra vertical chica al lado
  del personaje (no es un modal: el mundo sigue a la vista), y al sacarlo
  el pez (o el hallazgo) salta del agua hacia el jugador con el texto
  "Pescaste X (N cm)".
- Los demás ven la caña, la línea, la boya, el "!" y el salto (`fLn`,
  `fl`; § 7). El anfitrión sigue tirando el pez y validando.
- HUD de herramienta (v0.23.2): con la orilla al lado o pescando, arriba
  de las pociones aparece la caña equipada (clic: la siguiente caña
  propia, si tenés más de una; todavía no hay carnada) y el aviso
  compacto ("[E o clic] Pescar" y las fases: cargando, picada, pelea).
  Reemplaza al cartel de abajo. Solo en el pueblo, nunca en misiones.
  Clic izquierdo en el mapa con la orilla al lado saca la caña, como E.
- La lógica es `MapFishing` (pura, testeable): envuelve al minijuego de
  abajo y suma el lugar (orilla, dirección, tile de caída).

### 4.1 Fases

Fases: listo → carga (mantener; 1.2 s al máximo) → vuelo (0.5 s) →
espera (señuelos) → picada → clavado → barra → sacado / escapado.

- Espera hasta la picada: entre `biteMinSec` y `biteMaxSec` (2.5 / 7)
  × (1 − bonus de picada de la caña). Hasta `nibblesMax` (3) señuelos
  antes: la boya tiembla pero no es la picada.
- Reaccionar antes de la picada real la pierde. La picada dura
  `biteWindowSec` (1.1 s).
- Al clavar, el cliente manda `fBite` y espera el pez del anfitrión
  (3 s sin respuesta = se escapa).
- Barra vertical: la zona sube mientras se mantiene y cae al soltar
  (con inercia); tamaño `zoneBase` (0.24) × (1 + bonus de zona). El pez
  se mueve hacia objetivos al azar, más rápido y más seguido según
  `barSpeed` × `diff<Rareza>` (0.6 / 0.9 / 1.25 / 1.6). El progreso
  arranca en `progressStart` (0.25), sube `progressGain` (0.1/s) con el
  pez adentro y baja `progressDrain` (0.12/s) afuera. Lleno = sacado;
  vacío = escapado. Unos 15–30 s por pez contando la espera.
- Sensación: boya que tiembla y se hunde, anillo en la picada,
  salpicadura de partículas al caer y al sacar, sacudida de la escena
  con el pez afuera, sonidos del banco (lance, caída, señuelo, picada,
  tirón, sacado, escapado).
- Arte procedural en el mapa (`MapFishingLayer`); colores en
  `FishingPalette` (map_themes.dart).

## 5. Cañas y agropecuario

### 5.1 Cañas (espacio de herramienta, aparte de las armas)
| Caña | Rareza | Nivel | Picada | Zona | Rareza+ | Precio |
|---|---|---|---|---|---|---|
| Caña de rama | común | 1 | 0 | 0 | 0 | inicial |
| Caña de roble | raro | 5 | 15 % | 15 % | 20 % | 400 |
| Caña de bronce rúnico | épico | 12 | 30 % | 30 % | 45 % | 1500 |
| Caña del Eco | legendario | 22 | 45 % | 50 % | 80 % | 5000 |

Efectividad (town_loop.md § 11c): `ratio = clamp(nivel / requerido, 0,
1)`, `bonus = base × (bonusFloor + (1 − bonusFloor) × ratio^bonusCurve)`
(0.4, 1.5). Se compran en el agropecuario y se equipan ahí.

### 5.2 Venta
- Por especie (VENDER) o VENDER TODO (no incluye legendarios).
- Cobrar en ORO (precio base) o en MATERIALES (se elige en cada venta):
  valor × `matRate` (1.2) en Esquirlas del Eco, una cada `matValue` (25)
  de oro; el resto se paga en oro.
- Legendario: CANJEAR → `legendCristales` (3) Cristales de Era +
  `legendPrismas` (1) Prisma Roto.
- Cebos y ofertas rotativas: más adelante (la tabla de cañas ya tiene
  precio, el panel lista lo que está en el catálogo).

### 5.3 Puesto del agropecuario (v0.23.2)
- Desde v0.24.4: grilla de casillas por categoría (farming.md § 11) con
  el detalle de la elegida a la derecha (tipo, rareza, nivel, rinde,
  rareza extra, precio y acciones). El nombre ya no repite el tipo.
- Primer nivel: COMPRAR o VENDER. Segundo: PESCA o CULTIVO. Tercero:
  categorías (botones arriba de la lista, que también filtran; con TODO
  la lista sale agrupada con un encabezado por categoría, nunca mezclada).
  - COMPRAR · PESCA: Cañas (Carnada cuando exista).
  - COMPRAR · CULTIVO: Semillas, Abonos, Azadas, Regaderas.
  - VENDER · PESCA: Peces, Basura, Legendarios (VENDER o CANJEAR).
  - VENDER · CULTIVO: Cultivos, Legendarios.
- Buscador siempre visible en los dos modos, sin importar cuántos ítems
  haya.
- "Cobrar en" (ORO / MATERIALES) y VENDER TODO solo en VENDER.

## 6. Auto-pesca (se fue en v0.25.5)

Ya no hay botón AUTO-PESCA ni tecla R: la reemplaza el PESCADOR de cada
lago (farming.md § 8): saca peces solo, al cofre del lago, con la tabla
de ese lago, nunca legendarios y poca XP para quien recoge.

## 7. Red (protocolo 43)

- Acciones: `fBite {pw}` (clavó; carga del lance), `fRes {ok}`,
  `fAuto`, `fSell {sp?, mat?}`, `fSwap {sp}`, `rodBuy {r}`, `rodEq {r}`.
- Eventos: `fBite {id, sp, cm}` (el pez que tiró el anfitrión),
  `fCaught {id, sp, cm, auto?}`.
- `fLn {l?}` (v0.22.2): lo que se ve de la pesca (`FishLine`: etapa
  caña / carga / boya / picada / pelea y la boya en px). El host lo
  valida (pueblo, agua cerca, boya en un tile del lago al alcance) y lo
  guarda en el jugador (`fl` del snapshot); caminar lo borra.
- Evento `fLoot {id, l, r}` (§ 8): un hallazgo del agua.
- El anfitrión valida: en el pueblo, no compañero, a menos de 22 px del
  agua (cualquier orilla), caña equipada propia, `minCastSec` (2 s) entre picadas, una
  picada pendiente por jugador y `minReelSec` (1.5 s) mínimos de pelea.
  El cliente solo dice si lo sacó; especie, tamaño y rareza los decide
  el anfitrión. Estado no persistido (`SessionEngine.fishing`).
- Chat: "X se puso a pescar." (una vez por estadía), "X pescó <pez> (N
  cm, rareza)." y subidas de nivel de Pesca.
- El perfil lleva `life`; viaja como siempre en `hello` y en el estado.

## 8. Botín del agua (v0.22.2)

El anfitrión decide al clavar (como el pez) si la captura es un pez o
un hallazgo (`FishingRules.rollLoot`). Tunables en Editor → Balance →
Pesca.

### 8.1 Tipos y chances
- `lootChance` (0.15) × (1 + `lootLevelBonus` (0.03) × (nivel − 1)) de
  que no sea un pez. Pesos: basura `lootBasura` 60, materiales
  `lootMateriales` 28, cofre hundido `lootCofre` 9, arma `lootArma` 3;
  los tres buenos × (1 + bonus de nivel + suerte). Suerte = rareza
  efectiva de la caña (+ muelle). Las mazmorras siguen siendo la fuente
  principal de armas: la chance de arma queda baja.
- Basura (Botas viejas, Rama empapada): va a la bolsa como un pez y se
  vende por casi nada.
- Materiales: `lootMatMin`..`lootMatMax` (1..3) Esquirlas del Eco, o 1
  Cristal de Era (25 %).
- Cofre hundido: oro + la tirada de un cofre de madera (o plata, 15 %)
  con las reglas de cofres de siempre al nivel del personaje.
- Arma: el generador de armas de siempre (cualquier rareza).
- En la línea se ve "Algo pesado" (`bulto_hundido`, rareza rara para la
  barra) hasta sacarlo.
- Todo va al inventario con las reglas de siempre (lo que no entra, al
  piso / alijo / Loot perdido). Aviso "Pescaste X", chat y el salto en
  el mapa. +10 XP de Pesca por hallazgo.

### 8.2 Pity
`LifeSkills.dry` (JSON `dry`): capturas sin cofre ni arma. Al llegar a
`lootPityAfter` (80): cofre (80 %) o arma seguro; cofre o arma lo
reinician. La auto-pesca no lo toca.

### 8.3 Legendarios del agua (exclusivos)
Filo Hundido (espada), Báculo del Reloj Ahogado (báculo) y Arco de la
Orilla Antigua (arco), con pasivas únicas propias. Solo cuando sale un
arma, con Pesca nivel `lootLegendLevel` (15) o más y una caña de rareza
`lootLegendRod` (2 = épica) o mejor: `lootLegendChance` (1 %). Nombres
y textos con el lore base (ecos, pasado magitec); esperan el OK del
dueño.

## 9. v0.23.0: agropecuario con pestañas, PESCA Y CULTIVO y árbol

- El agropecuario tiene pestañas PESCA y CULTIVO (desde v0.23.2, primero
  COMPRAR / VENDER: § 5.3). Lo de cultivo: farming.md § 9.
- PERSONAJE → PESCA Y CULTIVO (solo en el pueblo): cañas, pescados (con
  SOLTAR EN EL LAGO), basura del agua y lo de la huerta; no usa
  casilleros del inventario (farming.md § 11).
- Botín del agua que no entra (equipo con la mochila llena): va al alijo
  por el camino de recuperación (`StashAck`), no se pierde. Los
  materiales al tope siguen la regla de siempre.
- Árbol de talentos de Pesca: `life_skill_trees.md` § 3. Peces soltados
  en el lago y cría: farming.md § 7.
