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

### 2.1c Lagos de los biomas (v0.29.0)

Ruinas, Cavernas, Grieta y Abismo tienen su lago y su tabla (5 peces y 2
basuras cada uno): ver overworld_biomes.md § 3.5. Misma pesca que el
Bosque (`BiomeLayout.fish` / `junk`).

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
  pelea, mantener sube la zona. R con la caña afuera (sin lance o con la
  boya esperando): prende / apaga la auto-pesca (§ 6). Con la caña
  guardada, R sigue siendo "otra mano" en la huerta.
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
(0.4, 1.5). Se compran en el TALLER DE OFICIOS › HERRAMIENTAS (v0.48.5;
antes en el agropecuario) y se equipan ahí o en OFICIOS.

### 5.2 Venta
- Por especie (VENDER) o VENDER TODO (no incluye legendarios).
- Cobrar en ORO (precio base) o en MATERIALES (se elige en cada venta):
  valor × `matRate` (1.2) en Esquirlas del Eco, una cada `matValue` (25)
  de oro; el resto se paga en oro.
- Legendario: CANJEAR → `legendCristales` (3) Cristales de Era +
  `legendPrismas` (1) Prisma Roto.
- Cebos: ver § 14. Ofertas rotativas: más adelante.

### 5.3 Puesto del agropecuario (v0.23.2)
- Desde v0.24.4: grilla de casillas por categoría (farming.md § 11) con
  el detalle de la elegida a la derecha (tipo, rareza, nivel, rinde,
  rareza extra, precio y acciones). El nombre ya no repite el tipo.
- Desde v0.41.9: la casilla es la misma de INVENTARIO (44 px, solo
  ícono y marco de rareza, cantidad abajo, E de equipada); nada de texto
  debajo del ícono. Al pasar el mouse, la ficha estándar (`DsTooltip`,
  ancho y fuente tope) con nombre, tipo, rareza y datos: semillas →
  tiempo de crecimiento, bioma de origen, afinidad horaria, precio;
  herramientas → rinde y comparación con la equipada; peces/cultivos →
  cantidad y valor. Una sola grilla (nunca secciones apiladas), en orden
  de categoría; las semillas ordenadas por tiempo de crecimiento.
- Filtros de semillas (COMPRAR · CULTIVO · SEMILLAS), en una sola fila
  de chips: BIOMA (TODO + cada bioma con semillas a la venta) y
  CRECIMIENTO (TODO, CORTO < 5 min, MEDIO 5–15 min, LARGO ≥ 15 min).
- Primer nivel: COMPRAR o VENDER. Segundo: PESCA o CULTIVO. Tercero:
  categorías (chips arriba de la grilla que filtran; con TODO salen
  todas en la misma grilla, en orden de categoría).
  - COMPRAR · PESCA: Cebos (desde v0.48.5 las cañas se compran en el
    TALLER DE OFICIOS › HERRAMIENTAS, town_loop.md § 2.1).
  - COMPRAR · CULTIVO: Semillas, Abonos (azadas y regaderas: TALLER).
  - COMPRAR · MINERÍA: solo insumos (los picos: TALLER).
  - Regla: el agropecuario vende solo consumibles e insumos, nunca
    herramientas.
  - VENDER · PESCA: Peces, Basura, Legendarios (VENDER o CANJEAR).
  - VENDER · CULTIVO: Cultivos, Legendarios.
- Buscador siempre visible en los dos modos, sin importar cuántos ítems
  haya.
- "Cobrar en" (ORO / MATERIALES) y VENDER TODO solo en VENDER.

### 5.4 Tormenta (v0.27.0)

Con tormenta (day_night_weather.md § 3.3) cada lance pica con chance
`stormBite` (0.3, Pueblo en Editor → Balance); si no, se pierde al llegar
la hora de la picada con "Con la tormenta no pica nada".

## 6. Auto-pesca (vuelve, protocolo 67)

Se fue en v0.25.5 (la reemplazó el PESCADOR de cada lago, farming.md
§ 8, que sigue igual). Vuelve como modo del jugador:

- **Cuándo.** Con la caña afuera en una orilla (donde anda la pesca a
  mano: lago del pueblo o agua de un bioma), sin lance o con la boya
  esperando, R la prende. El personaje pesca solo mientras esté quieto.
- **Qué la corta.** Caminar, abrir un menú o panel, entrar en pelea,
  alejarse del agua / salir del pueblo, guardar la caña (Esc) o R de
  nuevo. Con la caña guardada R no hace nada de pesca (cerca de la
  huerta es "otra mano", farming.md § 4): sin conflicto, la caña afuera
  tiene prioridad.
- **Castigo** (Editor → Balance → Pueblo):
  - `autoWaitMult` (2.0): × la espera de la picada (`biteDelay`).
  - `autoPassiveMult` (0.5): × los bonus de la caña y del árbol de Pesca
    (picada, rareza, XP del árbol). Muelle, lago y agua brillante igual.
  - Nunca legendarios; `autoEpicMult` (0.25) × el peso de épico.
  - `autoXpMult` (0.5): × XP de Pesca y de personaje (con el tope por
    estadía de siempre). La primera captura de una especie da su extra.
  - No suma ni consume pity (ni el de legendario ni el del botín).
  - Solo peces: sin botín del agua (§ 8). Tamaño normal.
  - Tormenta: cada picada pasa por `stormBite` como a mano (§ 5.4).
- **Botín.** Cada pez va a la bolsa del jugador como a mano (y al
  bestiario). La bolsa no tiene tope; si algún día lo tiene, la
  auto-pesca para con aviso.
- **HUD.** Arriba del personaje "AUTO-PESCA · N" (N = peces de esta
  tanda) para uno; los demás ven "AUTO-PESCA". El aviso de abajo dice
  que pesca sola y R para parar. Al cortarse, una línea en el registro
  con el motivo y los peces.
- **Red.** El anfitrión decide todo: `fAuto {on}` la prende si hay
  `fl` (caña afuera), está en el pueblo / bioma, cerca del agua y no la
  tenía; marca `fl` con auto y tira las picadas en su tick. El cliente
  manda `fAuto {r}` (motivo) al cortarla; el anfitrión manda
  `fAutoOff {id, r, n}` siempre (también cuando la corta él: pelea,
  caminar, `fLn` vacío). Cada uno de la sala tiene la suya.
- Estado no persistido (`FishingHostState.auto`).

## 7. Red (protocolo 43; auto-pesca en 67)

- Acciones: `fBite {pw}` (clavó; carga del lance), `fRes {ok}`,
  `fAuto {on?, r?}` (§ 6; `r` = motivo al apagarla: 0 R, 1 caminó,
  2 menú, 3 pelea, 4 se fue), `fSell {sp?, mat?}`, `fSwap {sp}`,
  `rodBuy {r}`, `rodEq {r}`.
- Eventos: `fBite {id, sp, cm}` (el pez que tiró el anfitrión),
  `fCaught {id, sp, cm, auto?}`, `fAutoOff {id, r, n}` (§ 6).
- `fl` lleva un 4.º campo `1` con la auto-pesca prendida (con `bx, by`
  aunque no haya boya).
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

> **v0.32.4:** PESCA Y CULTIVO pasó a PERSONAJE → OFICIOS → INVENTARIO
> → PESCA (docs/specs/oficio_storage.md).

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

## 10. Bestiario de pesca (v0.31.0)

- `life.lg`: especie → récord en cm. Toda captura de pez (no basura)
  anota el récord.
- Primera captura de una especie: XP de Pesca extra (`firstCatchFishXp` ×
  la de la captura) y XP de personaje (`firstCatchCharXp` × la de la
  captura, sin el tope por estadía). Se anuncia en el chat.
- (Reemplazado: los peces viven en OFICIOS → Pesca → COLECCIÓN,
  weather_seasons.md § 7; el BESTIARIO es solo de enemigos.)
- Antes: PERSONAJE → PESCA Y CULTIVO → BESTIARIO DE PESCA: grilla como el
  inventario, filtro por bioma (botones con descubiertos / total, nunca
  secciones apiladas); descubiertas con ícono y récord, sin descubrir en
  silueta gris con "?"; detalle a la derecha.

## 11. Agua brillante (v0.31.0)

- Un tile de agua con orilla por bioma, elegido por bioma y día del mundo
  (`FishingCast.hiddenSpot`, cambia cada día), dibujado con destellos.
- Pescando a `spotRadius` tiles o menos: rareza + `spotRare` y botín del
  agua con suerte + `spotLoot`. Solo en exteriores de bioma.

## 12. Pescador nativo del bioma (v0.31.0)

- Uno por bioma (`kBiomeFishers`): Nera de la Orilla (Bosque), Tadeo
  Engranaje (Ruinas), Sila Escarcha (Cavernas), Bruno Brasa (Grieta), Eco
  Viejo (Abismo). Camina por la orilla de su lago; es arraigado: no se
  muda al pueblo (overworld_biomes.md § 12: diálogo, HABLAR, invitación
  con regalo único y PUESTO). Sprite `items.vida_npc_pesc_<bioma>` (provisorio).
- E cerca o clic: el cuadro de diálogo; PEDIDO DEL DÍA abre el pedido (grilla, detalle a la
  derecha, ENTREGAR gris con el motivo). Pide 1 a 3 de un pez de SU lago,
  rareza hasta Pesca / `fisherRarityLevels`, tamaño mínimo que sube con el
  nivel (hasta tres cuartos del rango; vale el récord del bestiario).
- Entregar (`town {o: fisherReq, id: bioma}`, una vez por jugador y día,
  en `town.dy`): XP de Pesca `fisherXpBase` + `fisherXpStep` × nivel, XP
  de personaje = valor × `fisherCharXpPerValue`, oro = valor ×
  `fisherGoldPerValue`.

## 13. Horarios y clima de los peces (v0.31.0)

- Cada especie tiene franja (`LifeTimeRules.fishTime`): comunes siempre;
  raros de día o de noche; épicos al amanecer o al atardecer; legendarios
  de noche. Algunos épicos piden lluvia y los legendarios de la Grieta y
  el Abismo, tormenta (`fishWeather`). Primera pasada derivada por
  rareza; el dueño puede fijarla por especie.
- El anfitrión filtra la tabla del lago con el reloj del mundo: fuera de
  su franja un pez entra solo con chance `offHoursChance` (nunca queda el
  lago vacío).
- BESTIARIO: cada pez muestra bioma, tamaño, "Pica: <franja> · <clima>",
  récord; sin descubrir muestra "Pica: ???". Filtros por bioma y por hora
  (botones, no secciones).

### 13.1 Estaciones y clima (protocolo 69)

- `FishDef.seasons` (por defecto todo el año) y `FishDef.weather`
  (estricto). Fuera de estación no pica. Overrides en climate.json.
- Etiquetas: carpa_musgo y dorado_igneo cálidas; trucha_cobre otoño,
  invierno, primavera; salmon_eco y pez_invierno otoño e invierno;
  medusa_manana primavera y verano.
- Visitantes (`visitor`, se suman a la tabla del bioma):
  mojarra_primavera (pueblo, primavera), carpa_nevada (pueblo, invierno),
  pez_copo (pueblo, invierno + nieve), pez_bruma (pueblo, niebla),
  perca_hojas (bosque, otoño), trucha_tormenta (bosque, tormenta),
  anguila_niebla (ruinas, niebla), dorado_estival (grieta, verano),
  raya_relampago (abismo, tormenta).

## 14. Cebos (protocolo 69)

### 14.1 Catálogo

| id | atrae | receta (cebo prensado + extra → n) |
|---|---|---|
| lombriz | comunes | 1 → 4 |
| larva_brillante | niebla | 1 + hongo ámbar → 2 |
| cebo_escarcha | invierno + nieve | 1 + cristal de escarcha → 2 |
| cebo_tormenta | tormenta | 2 + pez ceniza → 2 |
| senuelo_eco | legendarios | 3 + pez eco → 1 |

"Cebo prensado" sigue siendo el material base de la receta.

### 14.2 Efectos

`bait<Id>{Bite,Rare,Size,Price,Gold}` en tuning `fishing`: picada,
rareza, tamaño (empuja hacia el máximo), precio y oro de la receta. Los
peces que atrae pesan × `baitAffinity` (4) en la tirada.

### 14.3 Consumo

Uno por pez (no por basura ni botín), igual en pesca manual y auto.

### 14.4 Fuentes

Comerciante (CEBOS, de a 1 o 5), fabricar en OFICIOS → Pesca → CEBOS,
botín del agua (`baitWaterChance`) y minas (`BaitRules.foundBait`).

### 14.5 HUD

Con la caña afuera, casillero CEBO junto a la caña: ícono, "Cebo [F]",
cantidad. Clic o F pasa al siguiente; por defecto el mejor que tengas.
La COLECCIÓN muestra el mejor cebo de cada pez.

## 15. Balsas de los lagos grandes (protocolo 83)

Código: `lib/game_engine/rules/raft_rules.dart` (`RaftRules`, puro),
`BiomeLayout.raftDocks`, `SessionEngine._raft` (anfitrión), dibujo en
`map_game.dart` (`vida_balsa`, `vida_muelle_balsa` del manifest, salen
de `tool/export_life_icons.dart`). Tunables en `kTuning[TuningId.fishing]`.

### 15.1 Qué lago tiene muelle

- Un lago es **grande** si es gigante (`BiomeLake.giant`, el `giantLake`
  de las tierras salvajes: siempre) o si su agua (tiles `~` conectados
  desde el centro) llega a `raftMinLakeTiles` (70).
- Cada lago grande tiene **un** muelle de balsas, determinista (mismo
  layout = mismo muelle en todos los pares): el tile de tierra caminable
  de la orilla más cercano al final del camino del lago (`approach`), que
  no sea ese tile ni esté pegado a un muelle de pesca (`f`), y cuyo tile
  de agua de enfrente tenga dos tiles más de agua detrás. Empates: fila,
  después columna. No cambia tiles: el muelle es un adorno sobre tierra y
  hay una balsa amarrada en el agua de enfrente.

### 15.2 Subir, manejar, bajar

- **E** a `raftDockReach` (1.5) tiles del muelle, a pie: acción
  `raft {on: true}`. El anfitrión pone al jugador en el centro del tile de
  agua de enfrente (teletransporte: época nueva) y guarda esa época en
  `SessionPlayer.raftEpoch`. Está en balsa (`rafting`) mientras su época
  sea esa: cualquier otro teletransporte (viaje, misión, piedra de paso)
  lo deja a pie solo.
- Cada jugador tiene su propia balsa: varios a la vez, sin límite.
- En balsa se mueve con las teclas de siempre a `raftSpeed` (0.8) × la
  velocidad de caminar, solo sobre agua (`RaftRules.step`: caja un poco
  más chica que un tile, se desliza contra la orilla; los muelles de
  pesca cuentan como orilla).
- Posición: igual que a pie (el cliente la manda, `MoveAction`); en balsa
  el anfitrión rechaza la que deja el centro fuera del agua.
- **E** en balsa: si hay tierra libre a `raftShoreReach` (1.2) tiles o
  menos (cualquier orilla, también el muelle) baja ahí: `raft {on:
  false}`, el anfitrión lo pone en el centro del tile libre más cercano
  (`RaftRules.landing`). Si no hay orilla cerca, E pesca.
- Indicaciones: "[E] Subir a la balsa", "[E] Bajar a la orilla", "[E]
  Pescar desde la balsa" (`ui.world.raft.*`).
- Snapshot: `rf` (la época de la balsa) en el jugador, solo si está en
  balsa; todos lo ven sobre su balsa.

### 15.3 Aguas abiertas

- La pesca desde la balsa es la de siempre (caña, lance, minijuego,
  auto-pesca) y anda en cualquier parte del lago.
- **Profundidad** = tiles (8 direcciones) del tile de la boya (o de la
  balsa si todavía no hay boya) al tile más cercano que no es agua
  (`RaftRules.depth`, cacheado por mapa). Solo en exteriores de bioma.
- Cada tile después del primero suma `deepRarePerTile` (0.08) de rareza
  (tope `deepRareMax`, 0.5) y `deepSizePerTile` (0.05) de tamaño (tope
  `deepSizeMax`, 0.3).
- **Especies de aguas abiertas** (`FishDef.minDepth`): no están en la
  lista del lago; se suman a la tabla del bioma con la boya a esa
  profundidad o más (`deepFishOf`). Los lagos comunes llegan a 3 de
  profundidad; los gigantes a 4–6, así que solo ahí aparecen. Los ayudantes y el pescador nativo no
  las ven (no cambian).

| Bioma | Especie | Rareza | Prof. | cm | Precio | XP |
|---|---|---|---|---|---|---|
| bosque | Lucio de la hondura | épico | 4 | 70–150 | 260 | 70 |
| bosque | Carpa del Olvido | legendario | 5 | 110–200 | 1500 | 230 |
| ruinas | Barbo de la campana hundida | épico | 4 | 60–130 | 380 | 85 |
| ruinas | Pez del Archivo Ahogado | legendario | 5 | 100–210 | 2100 | 290 |
| cavernas | Lucio del silencio | épico | 4 | 70–150 | 500 | 110 |
| cavernas | Esturión de la Escarcha Eterna | legendario | 5 | 140–260 | 2800 | 350 |
| grieta | Dorado del rescoldo | épico | 4 | 65–140 | 650 | 130 |
| grieta | Pez de la Forja Muda | legendario | 5 | 120–230 | 3600 | 420 |
| abismo | Raya del adiós | épico | 4 | 80–170 | 850 | 150 |
| abismo | Ballena del Último Eco | legendario | 5 | 200–400 | 4800 | 500 |

### 15.4 Tests

`test/game_engine/lake_raft_test.dart` (muelle determinista, subir,
manejar, bordes, bajar, profundidad → especies),
`test/netcode/lake_raft_sync_test.dart` (loopback: dos balsas a la vez),
`test/features/world/lake_raft_prompt_test.dart` (indicación y E). Con
`RAFT_PREVIEW=1` escribe `docs/preview/lake_raft.png`.
