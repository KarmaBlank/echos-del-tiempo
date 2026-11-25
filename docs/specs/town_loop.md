# Spec: Pueblo y expediciones — el Mundo como mazmorra co-op con vida de pueblo

Estado: visión del dueño pasada a spec. **Fase 2 implementada en
v0.21.0** (pueblo nuevo, sin overworld, mundos por cuenta; ver § 11.2);
el resto sigue siendo diseño.
Lore: únicamente `docs/lore.md` (tiempo, ecos, futuro inmutable, pasado
magitec). Specs relacionadas que esta no reemplaza sino que reordena:
`world.md`, `missions.md`, `loot.md`, `materials_economy.md`,
`ascension.md`, `ultimates_v2.md`, `balance_admin.md`, `netcode.md`.

Todo número de esta spec es **tunable** y vive en Editor → Balance
(`balance_admin.md`), salvo que diga lo contrario.

---

## 1. Loop principal

```
Pueblo tranquilo ──► Expedición corta y épica ──► Vuelta con botín
      ▲                                                 │
      │                                                 ▼
El pueblo cambia ◄── Invertir en el pueblo ◄── Revelar/ajustar botín
(por misiones)
```

1. **Pueblo**: zona segura, sin combate, ritmo lento. Se prepara la
   party, se pesca, se cultiva y se comercia.
2. **Expedición**: máximo **3 pisos**, duración objetivo **10–12 min**.
   Peleas de **2–3 rondas** de timeline en promedio (contra comunes);
   jefe de piso final más largo pero acotado.
3. **Botín**: lo que se junta en la mazmorra vuelve como "botín sin
   revelar" (eco sin fijar). Se **revela y ajusta** en el pueblo
   (torre de loot perdido / forja). La mazmorra no frena para menús.
4. **Invertir**: oro, materiales y productos del pueblo van a mejoras
   permanentes de la sala y del personaje.
5. **El pueblo cambia**: el ciclo avanza **por misiones completadas**,
   nunca por tiempo real. Nadie "pierde" nada por no conectarse.

Tunables: `expedition.maxFloors` (3), `expedition.targetMinutes` (11),
`combat.targetRoundsCommon` (2.5), `combat.maxRoundsSoftCap`.

---

## 2. Mundo: sin overworld caminable

- Se **quita el overworld** como zona de juego. El presente se vive en
  el pueblo; el peligro está en las expediciones.
- **Estructura**: el pueblo es el **hub**; desde ahí, **viaje rápido**
  por un **mapa de viaje con biomas** (viajes cortos). Cada bioma tiene
  sus **mazmorras, recursos, semillas y peces** propios.
- **Selección de zona**: tablero de encargos + mapa de biomas (zonas
  desbloqueadas, con dificultad y botín esperado). La votación de
  `missions.md` se mantiene, ahora sobre el tablero.
- **Cinemática de partida corta** (≤ 4 s, saltable cuando todos están
  listos): la party sale por el camino de tierra hacia la zona.
- `MapGenerator.lobby` se reemplaza por el mapa del pueblo;
  `MapGenerator.generate` sigue para los pisos de expedición.

### 2.1 El pueblo (claro de bosque)

Fantasía de bosque, medieval (lore: el presente es medieval), con
restos del pasado magitec:

| Lugar | Función | Lore |
|---|---|---|
| **Fuente rúnica** (centro) | Punto de reunión, partida al tablero, curación | Mecanismo antiguo que todavía funciona; guarda ecos del pasado |
| **Lago** | Pesca | Sus aguas reflejan ecos del pasado y del futuro |
| **Huerta** | Cultivo | Tierra cerca de raíces de ruinas antiguas |
| **Agropecuario** | Compra/venta | Viajero del presente; único que compra pescado y cosecha |
| **Torre de loot perdido** | Revelar botín, pool de objetos sin recoger (`loot.md` § 4b.2) | Ruina magitec que atrae ecos de objetos perdidos |
| **Forja / Posada** | Mejorar, condensar y fusionar armas (v0.32.3: panel FORJA propio), descanso | Edificios mejorables (§ 4) |
| **Armería** (v0.32.3) | Comprar y vender armas | Edificio propio, aparte de la forja |
| **Taller de oficios** (v0.32.3) | Condensar y fabricar lo de los oficios: materiales de cultivo y pesca (fibra, cebo, tabla); más adelante semillas y herramientas de oficio | Banco de trabajo del presente para lo que dan el lago y la huerta |
| **Caminos de tierra** | Navegación; uno lleva a la salida de expedición | — |

Nombres finales de lugares y NPCs: **propuesta, esperan OK del dueño**.

#### TALLER DE OFICIOS (v0.32.3)

- Nombre genérico y neutral de lore: **el dueño puede renombrarlo**
  (cambia solo `TownLayout.landmarks` y los textos del panel).
- Las armas quedan en dos lugares (panels.md § "Armería y Forja"): la
  ARMERÍA compra y vende; la FORJA mejora, condensa materiales de arma y
  fusiona. Todo lo de oficio (plantas,
  pescados, semillas, herramientas de oficio y materiales de cultivo y
  pesca) se hace en el taller.
- Lugar fijo `TownSpot.workshop` (`@workshop`), tile `O` (sólido; se
  dibuja pasto y encima el sprite `items.vida_taller_oficios` del
  manifest, hoy arte provisorio de la casa de nivel 3). 3 × 3 en (6, 6)
  del pueblo base, al sur del camino norte, entre el portal y el lago.
  Sin cartel ni cofre (es un lugar, no una construcción).
- `[E] Taller de oficios` abre `WorldPanel.workshop` (`WorkshopPanel`):
  plantilla `DsCraftGridTemplate` (ui_minimal.md § 4.1). Hoy las
  recetas son las de materials_economy.md § 4.4; las recetas nuevas de
  oficio van acá, nunca en la armería.

##### Casa de los oficios: CRAFTEO y HERRAMIENTAS (v0.48.5)

Pedido del dueño: el AGROPECUARIO vende solo consumibles e insumos de
oficio; las herramientas se compran en el taller (la casa de los
oficios), al lado del crafteo.

- El panel tiene dos subpestañas (nunca secciones apiladas):
  **CRAFTEO** (`workshop-tab-craft`) y **HERRAMIENTAS**
  (`workshop-tab-tools`).
- **CRAFTEO**: grilla de casillas de INVENTARIO (44 px,
  `LifeItemCell`, ficha estándar al pasar el mouse) en una columna
  angosta de ancho fijo y el detalle ocupando TODO el resto a la
  derecha (`workshop-detail`): ícono grande (64 px), nombre, NIVEL
  (`LifeMaterialDef.tier`: fibra y cebo 1, tabla 2), descripción,
  INGREDIENTES como grilla de costo (`DsCostGrid`, tenés/necesitás por
  la cantidad elegida; nunca texto plano), resultado ("Obtenés N ×"),
  selector de cantidad (− / + / ×1 / ×5 / MÁX, `workshop-qty-*`) y
  **CRAFTEAR** (`workshop-craft`), gris con motivo si no alcanza o fuera
  del Mundo. Chips TODOS / CULTIVO / PESCA filtran la grilla.
  Ingredientes genéricos: "cosechas" (cualquiera no legendaria, primero
  las de menos valor), "pescados" (ídem), fibra, Esquirlas y oro.
- **HERRAMIENTAS**: grilla con chips CAÑAS / AZADAS / REGADERAS / PICOS
  y el detalle a la derecha (rinde, comparación con la equipada,
  COMPRAR / EQUIPAR). Las mismas acciones de siempre (`BuyRodAction`,
  `FarmToolAction`, `MineAction` de compra): el host no mira en qué
  puesto se compró (no hay op por vendedor), así que no cambia el
  protocolo.
- Toda referencia a un objeto (ingrediente, resultado, herramienta) es
  una casilla con la ficha estándar: qué es, dónde se consigue
  (`itemSourceLines`, item_sources.md) y MÁS DETALLE plegado.
- Las herramientas figuran en item_sources.md como
  `ItemSourceKind.toolShop` ("Se compra en el TALLER DE OFICIOS").
- Capturas: `docs/preview/oficio_house_craft.png`,
  `oficio_house_tools.png`, `agropecuario.png` (con `PREVIEW_SHOTS=1`).

#### Carteles en el mundo (v0.37.3)

- Todas las etiquetas del mundo en el pueblo y los exteriores (lugares,
  carteles, zonas de la huerta, cofres, entradas de zona, nombres de NPC
  y de jugadores) van un paso más chicas (7 → 6, 6 → 5; piso 5).
- Sobre cada jugador se ve solo su nombre (sin ascensión ni título).
- Los carteles de lugares (edificios, lago, carteles, hitos, zonas de la
  huerta, entradas de zona, TIENDA) solo se ven cerca del jugador local:
  opacidad plena hasta `MapGame.placeLabelRange` (4,5 tiles) y fundido
  hasta apagarse en `MapGame.placeLabelFade` (1 tile) más. Así no se
  amontonan cuando el pueblo crece. Los nombres de NPC y jugadores se
  ven siempre.

---

## 3. Actividades y qué produce cada una (solo ella)

Regla de diseño: **la mazmorra y el pueblo se necesitan entre sí**.
Ninguno alcanza solo → interdependencia co-op natural (unos bajan, otros
se quedan, o todos alternan).

| Fuente | Produce SOLO ahí | Por qué lo necesita el que va a la mazmorra |
|---|---|---|
| **Mazmorra** | Armas, oro, materiales base, **semillas raras** | — (es la fuente de equipo) |
| **Pesca** | Pescado (por bioma y calidad) | Se **vende** a agropecuarios por oro o materiales para mejoras del pueblo y de armas/equipo |
| **Huerta** | Cosechas (por bioma y calidad) | Igual: **comercio** por oro o materiales de mejora |
| **Mejoras del pueblo** | Ventajas permanentes | Más espacio, mejor forja, posada, automatización |
| **Comercio** | Oro y materiales a cambio de pescado/cosecha (solo los agropecuarios del pueblo compran eso) | Financia mejoras de pueblo y de equipo |

**Sin sistema de cocina** (decisión del dueño). Opcional más adelante:
unos pocos peces/cultivos **especiales** como insumo raro (p. ej. forja
de mods de tier alto o descuento de mejora de ULT), sin recetas.

### 3.1 Pesca
- **Minijuego de barra simple** (mantener el pez dentro de la zona),
  ~15–30 s por pez, local al jugador (§ 10). Tiene que sentirse bien:
  tirón con sacudida leve, salpicadura y sonido al sacar.
- Cebos: se compran o se hacen con materiales base de mazmorra.
- Tablas por bioma/lago/cebo; peces legendarios con chance baja y pity.
- Tunables: `fishing.legendaryChance`, `fishing.pityAfter`,
  `fishing.barSpeed`, `fishing.baitTiers`.

### 3.2 Huerta (manual y satisfactoria)
- **Parcelas por tiles**: arar → plantar → regar, con **etapas de
  crecimiento visibles** por cultivo (brote, crecido, maduro).
- Crece **por misiones completadas** (no tiempo real):
  `crop.missionsToGrow`; regar sube la calidad.
- **Calidad por tiers** (normal / buena / excelente / eco) que sube el
  precio de venta.
- **Cosecha con "pop"**: partícula chica + sonido. Estaciones opcionales
  (más adelante).
- Semillas comunes se compran; las de cada bioma caen en sus mazmorras.
- Arte: sprites pixel **mínimos pero lindos**, vía `sprite_manifest.yaml`.

### 3.3 Comercio
- Los agropecuarios compran pescado y cosecha por **oro o materiales**
  (mejoras del pueblo, mejora de armas/equipo). Venden cebos, semillas
  comunes y ofertas rotativas por ciclo.
- Tunables: `trade.prices`, `trade.qualityMult`, `trade.materialRates`.

### 3.4 Automatización (progresión ganada)
- Se **contratan ayudantes NPC con oro**. Arrancan **lentos y con poco
  rendimiento**; se mejoran: velocidad, rendimiento, más parcelas,
  **regadores automáticos**, **redes de auto-pesca**.
- En endgame la automatización es **buena pero cara**: se la gana.
- Los ayudantes trabajan mientras la party está en misión.
- Tunables: `helper.hireCost`, `helper.upgradeCosts`,
  `helper.yieldMult` (inicial 0.3), `helper.speed`,
  `autoNet.yieldMult`, `autoWater.cost`.

---

## 4. Mejoras del pueblo (permanentes, de sala)

| Mejora | Efecto | Niveles |
|---|---|---|
| Almacén | + espacio de stash compartido/por jugador | 1–5 |
| Forja | Desbloquea tiers de mod, abarata condensar (`materials_economy.md` § 4.3) | 1–5 |
| Ayudantes | Contratar y mejorar automatización (§ 3.4) | 1–5 |
| Posada | Descanso: buff menor de inicio, más espacio de huéspedes | 1–3 |
| Muelle / Huerta | Más parcelas, mejores lagos | 1–3 |

Costos: oro + materiales de mazmorra + productos del pueblo (siempre
mezcla de ambas fuentes). Tabla en `assets/balance` / YAML de datos.

---

## 5. Oficios

- **Pescador, granjero**: XP propia por actividad.
- Niveles dan: mejor rendimiento y calidad, cosméticos/títulos, y una
  pequeña parte de XP de personaje para que quedarse en el pueblo no
  atrase a nadie (`trade.charXpShare`).
- **Nadie queda encerrado en un rol**: cualquier jugador hace cualquier
  oficio, sin elegir clase de oficio ni exclusividades.
- Desde v0.23.0: árboles de talentos por oficio en PERSONAJE → OFICIOS
  (`life_skill_trees.md`); la huerta y el ayudante están en
  `farming.md`; desde v0.24.0 las ampliaciones por lado, los lagos y
  huertas que se ponen y mueven y los peces de cada lago, en
  `town_editor.md` (EDITAR PUEBLO en la fuente rúnica).

---

## 6. Dificultad por tamaño de SALA

- La misión se dimensiona para **todos los jugadores de la sala**, no
  para los que bajan.
- Bajar con menos = **más difícil, más botín por cabeza** (el botín
  total de la misión se reparte entre los presentes).
- Sala de 1 = dificultad solo (`solo_party.md`).
- Peso por ausente tunable: `room.absentDifficultyWeight` (1.0 = cuenta
  como presente, 0 = no cuenta). Propuesta inicial 0.6.
- Feedback claro en el tablero: "Sala de 4 · bajan 2 · dificultad
  ×N · botín por cabeza ×M".

---

## 7. Ciclo del pueblo (eventos)

Cada `cycle.missionsPerEvent` misiones (propuesta: 5) llega un evento:

- **Caravana**: agropecuario con ofertas raras por 1 ciclo.
- **Visitante con encargo**: pide productos del pueblo + algo de
  mazmorra; recompensa única.
- **Evento de temporada**: zona temporal con **jefe especial** (eco del
  futuro o del pasado; los del futuro "tienen que pasar", lore).

Los eventos son estado de sala (§ 9). No hay temporizadores reales.

---

## 8. Simplificación

- **Menos menús de primer nivel** (meta: ≤ 5 en el pueblo, p. ej.
  PERSONAJE, EQUIPO, PUEBLO, TABLERO, OPCIONES).
- **Fusionar monedas/materiales** que hacen lo mismo; cada recurso debe
  tener un uso que ningún otro cubra. Inventario a revisar en fase 7.
- **"Modo simple" por defecto**: auto-equipar sugerido, árbol en
  caminos grandes, comparaciones con flecha arriba/abajo. Modo avanzado
  opcional.
- Árbol de pasivas: se muestra primero como **caminos grandes**; el
  detalle nodo a nodo se abre a pedido.

---

## 9. Nivel de arma y muro de endgame

- **Subir nivel de arma** sacrificando duplicados u otras armas
  (+ reactivos de la huerta en niveles altos).
- **Early rápido**: los primeros niveles suben casi solos. Al cerrar el
  tramo inicial, momento explícito "**Terminaste el aprendizaje**"
  (pantalla corta que explica resistencias y nivel de arma).
- **Muro de endgame** legible: enemigos con resistencias y requisito de
  nivel de arma. Feedback textual en combate: "Resiste Fuego", "Tu arma
  es de nivel bajo". Nunca un muro sin explicación.
- Tunables: `weaponLevel.xpPerSacrifice`, `weaponLevel.curve`,
  `weaponLevel.tutorialCap`, `enemy.lowLevelPenalty`.

---

## 10. Red

- Actividades del pueblo (pesca, huerta individual) corren
  **localmente** en cada jugador; el cliente manda el **resultado** y el
  **host valida** (rango posible, semilla, cebo consumido) y otorga la
  recompensa. Sin desconfianza extrema: co-op entre amigos.
- **Estado compartido de sala** (en el snapshot del host): parcelas de
  huerta, mejoras del pueblo, pool de loot perdido, evento de ciclo
  activo, contador de misiones del ciclo.
- Sube versión de protocolo; actualizar `netcode.md` al implementar.
- Contrato: solo vía `NetSession`; nada de esto toca transporte.

---

## 10b. Jugar solo y pocos clics

1. **Solo progresa bien.** Las actividades del pueblo son
   **aceleradores opcionales, nunca puertas obligatorias**. Todo lo que
   en § 3 es "solo del pueblo" también se consigue **lento** por
   misiones (drop raro) o por el agropecuario (precio alto), con tasa
   peor: `town.fallbackRateMult` (propuesta 0.35).
2. **Producción pasiva.** La huerta es manual y satisfactoria (§ 3.2),
   con atajos "plantar todo" / "cosechar todo". La automatización viene
   de ayudantes contratados y mejorados (§ 3.4).
3. **Pesca:** minijuego de barra por pez, **~15–30 s**; las redes de
   auto-pesca dan recompensa reducida y **nunca legendarios**.
4. Sin cocina (eliminada por el dueño).
5. **Presupuesto de tiempo:** el loop del pueblo entre misiones
   entra en **≤ 2–3 min** si se quiere, y es **saltable del todo**
   (ir directo al tablero sin perder nada obligatorio).
6. **Sala de 1 = dificultad solo** (§ 6).

**Alcance acotado:** solo **pesca + huerta + comercio + mejoras**.
Cualquier actividad nueva
tiene que justificar algo que ninguna otra cubra.

---

## 11. Plan por fases

Cada fase: alcance, datos, tunables, tests (`game_engine/` puro) y
preguntas abiertas.

### Fase 1 — Base (en curso)
- Alcance: misiones cortas, límites de combate, UI limpia.
- Datos: `expedition.*`, `combat.*`.
- Tests: duración simulada de misión, rondas promedio por pelea.

### Fase 2 — Pueblo nuevo + quitar overworld
- Alcance: mapa del pueblo (§ 2.1), tablero/mapa de viaje, cinemática.
- Datos: layout del pueblo en YAML; sprites vía `sprite_manifest.yaml`.
- Tunables: duración de cinemática.
- Tests: transición pueblo → tablero → expedición → pueblo; dificultad
  por sala (§ 6).

### 11.2 Fase 2 tal como quedó (v0.21.0)

Pueblo (`MapGenerator.town()`, datos en
`lib/game_engine/data/town_layout.dart`, `TownLayout`):

- 34 × 22 tiles, tema `pueblo` (al aire libre), `lobby = true`, sin
  entradas de zona. Borde de árboles (dos de grosor a los lados), pasto
  y matas sueltas; spawn en el camino al sur de la fuente
  `(17×16, 14.5×16)`.
- Caminos de tierra: el de los edificios (y = 5), el eje norte-sur
  (x = 16..17) que llega al borde sur (salida de expedición), el anillo
  de la fuente y el ramal y = 16 al lago y a la torre.
- Lugares (todos sólidos; E a menos de `WorldRules.townRange` = 12 px
  del borde, `WorldRules.townSpot`):

| Lugar | Tile | Tiles | E |
|---|---|---|---|
| Portal del Eco | `P` | x 3–5, y 3 | panel del Portal |
| Tablero de encargos | `C` | x 10–15, y 3 | tablero = mapa de viaje |
| Forja | `A` | x 19–23, y 3 | armería |
| Estatua del Tiempo | `S` | x 28–30, y 3 | ASCENSIÓN |
| Fuente rúnica | `F` (nuevo) | x 16–17, y 10–11 | abre el tablero |
| Cartel del lago | `Y` (nuevo) | (12, 15) | aviso del lago (v0.22.0); desde v0.24.0 cada lago y huerta tiene el suyo (`town_editor.md` § 4.3) |
| Puntos de pesca | `f` (nuevo) | (10,15) (10,18) (6,14) | pesca en el mapa desde cualquier orilla (v0.22.2; muelles con bonus) |
| Agropecuario (puesto) | `M` | x 12–13, y 17 | AGROPECUARIO (v0.22.0) |
| Torre del Loot perdido | `L` | x 24–26, y 15 | pozo Loot perdido |

- Lago `~` en x 3–10, y 14–19 (esquinas de pasto). Desde v0.24.0 el
  lago y la huerta base son construcciones movibles y todo se corre con
  el origen si se amplía al norte o al oeste (`town_editor.md` § 2.2). Pesca y comercio
  son de la fase 3: el aviso es solo local (no viaja por red).
- Arte: procedural en `TilePainter` (colores en `TownPalette` y el tema
  `pueblo` de `map_themes.dart`), registrado en `sprite_manifest.yaml`
  (`tiles: fuente_runica, punto_pesca, cartel_lago,
  puesto_agropecuario`, `procedural: true`) para reemplazarlo por PNG
  desde el Editor sin tocar Dart.
- El layout queda en Dart puro (const) y no en YAML: el motor no lee
  assets. Pasarlo a YAML queda pendiente para cuando el Editor lo edite.

Sin overworld:

- `MapGenerator.overworld()` y las 10 entradas de zona se fueron. Las
  zonas se eligen en el tablero (que ya listaba las zonas con su estado
  de desbloqueo); el voto es el de siempre. Qué se movió del overworld:
  - Entradas de zona (E en la puerta → proponer / votar sí) → tablero
    de encargos (y la fuente rúnica, que lo abre).
  - Mapa en grande (M) del mundo → ya no hay mapa en el pueblo; el
    tablero es el mapa de viaje. En los pisos M sigue igual.
  - Piedras de paso, PdI, Prueba del Tiempo, Abismo, Portal del Eco,
    Estatua y Loot perdido: no dependían del overworld (las piedras son
    de los pisos; el resto ya estaba en el pueblo o en sus paneles).
  - Música: el pueblo siempre suena con la pieza del pueblo (la del
    overworld queda sin uso en el Mundo).
- Cinemática de partida al pasar de preparación al campo: el camino de
  tierra entre árboles con la party caminando y "Rumbo a <misión>".
  `exploration.departureSec` (Editor → Balance → Exploración, 3 s, tope
  4). Cualquier tecla o clic la salta (y sigue de largo); REDUCIR
  MOVIMIENTO la omite. Local de cada jugador.

Mundos por cuenta (§ 11c):

- `WorldSave {id, name, label: Solitario|Cooperativo, created, town}` y
  `TownState {upgrades (placeholder de la fase 4), lostLoot, cycle}` en
  `lib/game_engine/models/world_save.dart`; la lista (`WorldBook`) crea,
  renombra, borra, elige y agrupa por etiqueta.
- Disco: `<carpeta de la edición>/accounts/worlds/<id>.json` (uno por
  mundo) y el elegido en `accounts/world_selected.json`
  (`JsonFileWorldStore`). Solo en el Mundo (la Travesía no tiene mundos).
- Migración: si no hay ningún mundo (save de antes de v0.21.0) se arma
  "Mi mundo", **Cooperativo**, con el estado del pueblo de hoy (vacío:
  el pozo del Loot perdido no se guardaba) y se escribe. La cuenta y los
  personajes no se tocan.
- Título: arriba el MUNDO (agrupado por etiqueta, CREAR MUNDO /
  RENOMBRAR MUNDO / BORRAR MUNDO con confirmación), abajo el personaje;
  después JUGAR SOLO o ABRIR SALA (o UNIRSE con código). La etiqueta no
  bloquea nada.
- Sala: quien corre el motor pone `worldId` / `worldName` y carga el pozo
  del Loot perdido del mundo (`SessionEngine.setWorld`); viaja en el
  estado (`wid` / `wname`, protocolo 41). Al terminar una misión (si se
  ganó, `cycle + 1`), al volver al pueblo y al salir, el anfitrión guarda
  el pueblo en su mundo. El cliente no guarda nada del pueblo.

### Fase 3 — Pesca + agropecuario (hecha en v0.22.0)
- Ver **docs/specs/fishing.md** (manda sobre el detalle). Peces por
  bioma y lago del pueblo por mundo (`TownState.lake`), Pesca por
  personaje, cañas, minijuego local, agropecuario (oro o materiales,
  canje de legendarios, cañas) y auto-pesca sin legendarios.
- Tunables: Editor → Balance → Pesca (`fishing.*` + precios/canje).
- Pendiente: cebos y ofertas rotativas del agropecuario; "Cría de <pez>"
  para sumar especies de otros biomas al lago.

### Fase 4 — Mejoras del pueblo
- Datos: tabla de mejoras y costos.
- Tests: aplicar efectos (stash, forja), persistencia en sala.

### Fase 5 — Huerta + ayudantes + ciclo de eventos
- Datos: cultivos por bioma, etapas, calidades, ayudantes, eventos.
- Tunables: `crop.*`, `helper.*`, `cycle.*`.
- Tests: crecimiento por misión, calidad, rendimiento de ayudantes,
  disparo de evento.

### Fase 6 — Oficios
- Datos: curvas de XP por oficio, recompensas.
- Tests: XP, que nadie quede bloqueado de ninguna actividad.

### Fase 7 — Simplificación general
- Alcance: menús, fusión de recursos, modo simple, árbol en caminos.
- Tests: migración de saves (recursos fusionados se convierten 1:1 o
  por tabla).

---

## 11b. Exteriores de bioma y refuerzos

### Exteriores de bioma
- **v0.26.0, primera pasada:** mapa de viaje (camino del borde sur o la
  fuente) y el exterior del Bosque con lago, matas y dos entradas; todos
  viajan juntos. Detalle en `docs/specs/overworld_biomes.md` (manda sobre
  esta sección en lo implementado).
- Se pesca **en el pueblo y en cada bioma**. Cada bioma tiene una
  **zona exterior** (antes de sus mazmorras) con recolectables:
  semillas, puntos de pesca, recursos. Sin combate obligatorio.
- Se puede viajar a un bioma **solo a recolectar/pescar** y volver al
  pueblo. La party puede **dividirse**: unos en el pueblo, otros en el
  exterior de un bioma, otros en la mazmorra.
- Tunables: `biome.gatherNodes`, `biome.nodeRespawnMissions`.

### Refuerzos (unirse a una misión en curso)
- v0.26.0: el refuerzo entra a la batalla en curso con
  `reinforceDelay` intervalos de espera (overworld_biomes.md § 5).
- Quien no está en la misión (pueblo o bioma) puede **unirse a mitad**:
  prepararse → viajar al bioma → entrar a la mazmorra.
- **Si la party está en batalla:** el refuerzo entra a esa batalla con
  **penalidad de turno**: recién actúa tras un retraso
  (`reinforce.battleDelay`: fin de la ronda actual o N ticks, tunable).
- **Si la party está explorando:** aparece en la **entrada de la
  mazmorra**.
- La dificultad no cambia: ya está dimensionada para la sala (§ 6). El
  botín por cabeza se recalcula con los presentes al cerrar la misión
  (`reinforce.lootShare` tunable para el que llega tarde).
- **"Pedir ayuda"**: ping de la party en mazmorra a toda la sala
  (aviso + botón "Ir a ayudar" que arma el viaje). Cooldown
  `reinforce.helpPingCooldown`.

### Red
- **Host autoritativo**: el host acepta el ingreso, ubica al refuerzo
  (entrada o batalla) y lo agrega al snapshot.
- Unirse a batalla = **agregar un combatiente a mitad de pelea**: el
  host lo inserta en el timeline con el retraso; los clientes lo ven
  por evento, sin reiniciar la batalla. Requiere subir versión de
  protocolo (`netcode.md`).
- Cada jugador tiene una **ubicación** en el estado de sala:
  `pueblo | bioma:<id> | mazmorra:<id>:<piso>`.

### UI
- Indicador de **quién está dónde** (pueblo / bioma / mazmorra, con
  piso y "en batalla") en el panel de sala y en el tablero.
- Aviso visible del ping "pedir ayuda" y estado del refuerzo en viaje.

## 11c. Habilidades de vida, herramientas y propiedad del mundo

Tono: **pueblo de fantasía tranquilo; mazmorras épicas.** Quedarse en
el pueblo también hace progresar. Esta sección precisa § 5 (Oficios).

### XP de personaje
- Pescar y cultivar dan **un poco de XP de personaje** (el combate
  sigue siendo la fuente principal). Monto según **rareza/calidad** de
  lo pescado o cosechado: `life.charXp[rareza|calidad]`, con tope por
  misión del ciclo `life.charXpCapPerCycle`.

### Niveles de Pesca y Cultivo
- Progresión **por personaje**, independiente de clase, armas y combate.
  Cualquier clase pesca y cultiva.
- La XP va **solo al jugador que hizo la acción**. Producción automática
  de ayudantes: **propuesta** 10 % de la XP normal al dueño del
  ayudante (`life.helperXpShare` = 0.1; 0 la apaga).
- Curva: `life.levelCurve` (Pesca y Cultivo, máx. `life.maxLevel`,
  propuesta 30).

### Herramientas como equipo
- **Cañas** y **herramientas** (regadera, azada, …) con tiers/rareza
  como las armas. Mejores herramientas: más velocidad, más chance de
  peces épicos/legendarios, riego en área, etc.
- **Se pueden intercambiar** entre jugadores, pero el **rendimiento
  escala con el nivel de habilidad de quien la usa**.
- Fórmula (tunables):
  - `ratio = clamp(nivelHabilidad / nivelRequerido(herramienta), 0, 1)`
  - `bonusEfectivo = bonusBase × (piso + (1 − piso) × ratio^curva)`
    con `tool.bonusFloor` (propuesta 0.4) y `tool.bonusCurve` (1.5).
  - Tiempo de carga de efectos de área:
    `carga = tool.chargeMaxSec × (1 − ratio)`; con ratio 1 es **clic
    instantáneo**, con nivel bajo hay que **mantener para cargar**.
  - Ejemplos: regadera de área con Cultivo máximo = clic instantáneo;
    caña legendaria con Pesca baja funciona, pero con bonus reducidos.

### Propiedad: mundo del host, personaje propio
- **Los mundos son por CUENTA**, no por personaje. Un mundo guarda:
  pueblo, mejoras, estado de biomas, parcelas, eventos del ciclo y pool
  de loot perdido.
- **Los personajes** guardan nivel, habilidades de vida, inventario,
  stash y herramientas, y **pueden entrar a cualquier mundo**.
- **Varios mundos por cuenta**: "Crear mundo" con etiqueta
  **Solitario** o **Cooperativo**. La etiqueta es solo el **valor por
  defecto** y el **agrupamiento de la lista**: **no bloquea nada**.
  - Cada vez que abrís un mundo elegís **"Jugar solo"** o **"Abrir
    sala"** (lo hosteás y los amigos entran con sus propios
    personajes). Un mundo Solitario se puede abrir como sala y uno
    Cooperativo se puede jugar solo.
  - La dificultad sigue al tamaño de la sala (§ 6), no a la etiqueta.
  - Se puede seleccionar, renombrar y borrar mundos (borrar pide
    confirmación). Al jugar se elige **mundo + personaje**.
- Lo que ganes en el mundo de otro (XP, objetos, herramientas) se va
  con tu personaje; lo que construyas en su pueblo queda en su mundo.
- **Guardado**: en la carpeta de datos de cada edición,
  `accounts/worlds/<id>.json` (un archivo por mundo; los personajes
  siguen donde están hoy). **Migración compatible**: el estado actual
  del pueblo se convierte en el **primer mundo** de la cuenta (etiqueta
  por defecto a confirmar con el dueño); los saves viejos se leen sin
  pérdida.
- Red: **el mundo seleccionado por el host es el mundo de la sala**. El
  host valida XP y resultados (§ 10); el perfil del personaje viaja
  como hoy (`netcode.md`, perfiles).

## 12. Decisiones del dueño (mandan sobre el resto)

- Se elimina el overworld caminable.
- El botín se **revela automáticamente** al volver.
- Peso por ausente: **0.6**.
- Los que se quedan en el pueblo **no** reciben botín de mazmorra.
- Stash **personal**.
- Eventos cada **5 misiones**, solo por ciclo (sin fechas reales).
- El nivel de arma **se suma** a la mejora actual.
- Las mejoras del pueblo son **del mundo** (de la cuenta del host; § 11c).
- Pesca: **minijuego de barra simple**.
- Solo: **todas las actividades**, rendimiento ajustado.
- Auto-pesca: **sin legendarios**.
- Sin cocina; pescado y cosecha son para comercio.

## 12b. Preguntas originales (resueltas arriba salvo 2 y 8)

1. ¿Se elimina el overworld del todo o queda alguna zona caminable
   (p. ej. la Torre del Tiempo / Prueba del Tiempo)?
2. Nombres del pueblo, del agropecuario y de los lugares (§ 2.1).
3. ¿El botín se revela automáticamente al volver o hay que llevarlo a
   la torre? ¿Qué se puede "ajustar" (reroll, elegir afijo)?
4. Peso inicial por jugador ausente (`room.absentDifficultyWeight`):
   ¿0.6 está bien?
5. Si bajan menos jugadores, ¿los que se quedan reciben algo del botín
   de la mazmorra o solo lo de sus oficios?
6. ¿Stash compartido entre jugadores de la sala o solo personal?
7. ¿Cada cuántas misiones hay evento (propuesta 5)? ¿Los eventos de
   temporada tienen fecha real o solo por ciclo?
8. ¿Qué monedas/materiales actuales se fusionan primero (fase 7)?
9. Nivel de arma: ¿reemplaza parte de la mejora actual de armas o se
   suma?
10. ¿Las mejoras del pueblo son de la sala (se pierden al cambiar de
    host) o del jugador anfitrión que las lleva a cualquier sala?
11. Minijuego de pesca: ¿timing simple o algo más elaborado?
12. Pueblo en solo: ¿todas las actividades disponibles igual, con
    rendimiento ajustado?
