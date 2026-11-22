# Spec (PROPUESTA, sin implementar): Pueblo y expediciones — el Mundo como mazmorra co-op con vida de pueblo

Estado: visión del dueño pasada a spec. **Solo diseño, no hay código.**
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
| **Comerciante** | Compra/venta | Viajero del presente; único que compra pescado y cosecha |
| **Torre de loot perdido** | Revelar botín, pool de objetos sin recoger (`loot.md` § 4b.2) | Ruina magitec que atrae ecos de objetos perdidos |
| **Forja / Posada** | Crafteo y mejora de equipo, descanso | Edificios mejorables (§ 4) |
| **Caminos de tierra** | Navegación; uno lleva a la salida de expedición | — |

Nombres finales de lugares y NPCs: **propuesta, esperan OK del dueño**.

---

## 3. Actividades y qué produce cada una (solo ella)

Regla de diseño: **la mazmorra y el pueblo se necesitan entre sí**.
Ninguno alcanza solo → interdependencia co-op natural (unos bajan, otros
se quedan, o todos alternan).

| Fuente | Produce SOLO ahí | Por qué lo necesita el que va a la mazmorra |
|---|---|---|
| **Mazmorra** | Armas, oro, materiales base, **semillas raras** | — (es la fuente de equipo) |
| **Pesca** | Pescado (por bioma y calidad) | Se **vende** a comerciantes por oro o materiales para mejoras del pueblo y de armas/equipo |
| **Huerta** | Cosechas (por bioma y calidad) | Igual: **comercio** por oro o materiales de mejora |
| **Mejoras del pueblo** | Ventajas permanentes | Más espacio, mejor forja, posada, automatización |
| **Comercio** | Oro y materiales a cambio de pescado/cosecha (solo los comerciantes del pueblo compran eso) | Financia mejoras de pueblo y de equipo |

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
- Los comerciantes compran pescado y cosecha por **oro o materiales**
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

- **Caravana**: comerciante con ofertas raras por 1 ciclo.
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
   misiones (drop raro) o por el comerciante (precio alto), con tasa
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

### Fase 3 — Pesca + comerciante
- Datos: tablas de peces, cebos, precios.
- Tunables: `fishing.*`, precios de venta.
- Tests: tablas con semilla, pity, validación del host.

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

## 12. Decisiones del dueño (mandan sobre el resto)

- Se elimina el overworld caminable.
- El botín se **revela automáticamente** al volver.
- Peso por ausente: **0.6**.
- Los que se quedan en el pueblo **no** reciben botín de mazmorra.
- Stash **personal**.
- Eventos cada **5 misiones**, solo por ciclo (sin fechas reales).
- El nivel de arma **se suma** a la mejora actual.
- Las mejoras del pueblo son **del host**.
- Pesca: **minijuego de barra simple**.
- Solo: **todas las actividades**, rendimiento ajustado.
- Auto-pesca: **sin legendarios**.
- Sin cocina; pescado y cosecha son para comercio.

## 12b. Preguntas originales (resueltas arriba salvo 2 y 8)

1. ¿Se elimina el overworld del todo o queda alguna zona caminable
   (p. ej. la Torre del Tiempo / Prueba del Tiempo)?
2. Nombres del pueblo, del comerciante y de los lugares (§ 2.1).
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
