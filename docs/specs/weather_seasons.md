# Estaciones y clima (protocolo 72)

Estado: implementado en `feat/weather-seasons`. Textos en es-AR
definitivos; **en y zh-Hans son borradores** (revisar con quien traduce).

## 1. Estaciones

- Cuatro: primavera, verano, otoño, invierno (`Season`), en ese orden.
- Salen del día del mundo: `season(day) = Season.values[((day-1) ~/ seasonDays) % 4]`.
  Día 1 = primer día de primavera.
- `seasonDays` (tuning `town`, 7 por defecto) se edita en Balance o en
  CLIMA → ESTACIONES.
- `seasonDay(day)` (1..seasonDays) y `daysToNextSeason(day)` para el HUD.

## 2. Clima por bioma y día

- Climas: despejado, lluvia, tormenta, niebla, nieve (`Weather`).
  Mojados (`wet`): lluvia y tormenta. Niebla y nieve no riegan.
- Tirada determinista: `WeatherRules.dayWeather(seed, day, biome)` con un
  hash de 32 bits que da los mismos bits en web y VM. `seed` vive en
  `SkyState` (JSON `sd`); el host la elige al arrancar el cielo. Partidas
  viejas tienen seed 0 y siguen siendo deterministas.
- Pesos: `w<Estación><Clima>` (tuning `town`) × `bio<Bioma><Clima>`
  (multiplicador por bioma, 1 si falta). Nieve solo con peso en invierno.
- El pueblo usa el clima guardado en `SkyState`; el resto de los biomas
  se calcula al vuelo con seed + día + bioma (`SkyRules.nowIn`).
- Reemplaza `rainChance` / `stormChance`; `stormBite` sigue, y se suman
  `fogBite`, `snowBite`, `fogFisher`, `snowFisher`.

### 2.1 Exposición por bioma

| Bioma | Exposición | Climas permitidos | Nieve se vuelve | Marcas en el suelo |
|---|---|---|---|---|
| pueblo | exterior | todos | — | nieve, charcos, hojas, flores |
| bosque | exterior | todos | — | nieve, charcos, hojas, flores |
| ruinas | exterior | todos | — | nieve, charcos, hojas, flores |
| abismo | exterior | todos | — | nieve, charcos, hojas, flores |
| cavernas | bajo techo | solo despejado | — | ninguna |
| grieta | volcánico | despejado, tormenta, niebla | niebla (vapor) | ninguna |

- Bajo techo: sin clima, sin partículas, sin marcas; la pesca y los
  cultivos lo ven como despejado.
- Volcánico: nunca nieva; el peso de la nieve pasa a `snowMelt`.
- Mazmorras y minas no tienen clima ni marcas.
- Un clima no permitido pasa su peso a despejado.

## 3. Visuales

- Lluvia y nieve: partículas solo del área visible (`snowFlakes(view…)`,
  `maxFlakes` = 140), buffers `Float32List` reservados una vez,
  `drawRawPoints`; sin asignaciones por cuadro.
- Tormenta: tinte más oscuro (overcast). Niebla: velo (overcast .35).
  Nieve: overcast .25.
- Solo donde `climateOf(place).showsPrecipitation`.

## 4. Pesca y cultivos

- Peces con estaciones (`FishDef.seasons`) y clima estricto opcional
  (`FishDef.weather`); fuera de estación no pican. Visitantes
  (`visitor`) se suman a la tabla del bioma en su estación / clima.
  Ver fishing.md § 13–14.
- Cultivos con estaciones (`CropDef.seasons`, por defecto las cálidas).
  Fuera de estación **se frenan** (crecimiento × 0), no mueren.
  Cultivos solo de invierno (`winterOnly`) solo se cosechan en invierno.
  Ver farming.md § 15.
- Justo con el tiempo offline: los cultivos solo crecen mientras el host
  corre la sesión, así que estar desconectado no salta estaciones.

## 5. Marcas en el suelo

`MapGroundLayer` en el pueblo y los exteriores de bioma (lobbies):
nieve / escarcha en invierno o con nieve, charcos o tinte mojado con
lluvia / tormenta, hojas en otoño, flores en primavera. Un rect de tinte
más puntos con `drawRawPoints`. Respeta `BiomeClimate.groundShown`.

## 6. HUD

### 6.1 Reloj

El reloj de la derecha tiene dos filas:
- ícono de clima + "Día N · HH:MM";
- ícono de estación + "Invierno · faltan 3 días" (`ui.world.clock.season_left`,
  plural ICU).

Íconos de píxel con formas distintas (no solo color): sol, luna, nube,
rayo, niebla, copo; brote, sol, hoja, copo. Cada uno con tooltip de ancho
fijo (clima + pronóstico; día de la estación + la siguiente).

### 6.2 Sin cortes

Test de layout a 1024×640 y 1920×1080 con escala 1.0 y 2.0: sin overflow
ni líneas cortadas.

## 7. COLECCIÓN

- OFICIOS → Pesca → COLECCIÓN y OFICIOS → Cultivo → COLECCIÓN, sobre
  `DsCollectionTemplate` (design_system.md § 6.1).
- Los peces no están en el BESTIARIO (que es solo de enemigos). El
  filtro viejo de Pesca "BESTIARIO" se reemplaza por COLECCIÓN; el
  descubrimiento usa el mismo `life.lg` (no hace falta migrar).
- Cultivos: `farm.cropLog` (JSON `cl`, mejor calidad por cultivo). Las
  partidas viejas lo arman con la bolsa de cosechas.
- Subtabs por estación (TODOS + las cuatro), contador descubiertos/total.
- Pez descubierto: dónde (bioma y tipo de agua), horario/clima, estación,
  rareza, récord, mejor cebo. Cultivo descubierto: estaciones (y solo
  invierno), tiempo de crecimiento, de dónde salen las semillas, bioma,
  usos, mejor calidad. Sin descubrir: "?" gris y ninguna pista.

## 8. Datos de clima y Editor CLIMA

- `assets/data/climate/climate.json` (`ClimateData`), leído al arrancar
  por `ClimateDataLoader` en cada flavor; los valores del código son el
  respaldo.
- Contiene: por bioma exposición, climas permitidos, `snowMelt` y marcas;
  estaciones de peces y cultivos (overrides); nombres de climas y
  estaciones en todos los idiomas.
- Editor → CLIMA: subtabs BIOMAS, ESTACIONES, PECES, CULTIVOS, CEBOS,
  TEXTOS; grilla a la izquierda, detalle a la derecha. Los números
  (`seasonDays`, pesos, multiplicadores, cebos) van al borrador del
  Balance. GUARDAR CLIMA se bloquea mientras `issues()` no esté vacío
  (idiomas faltantes, ids desconocidos, estaciones vacías).

## 9. Red

- `kProtocolVersion` = 72 (seed `sd` en `SkyState`, cebos en
  `LifeSkills`, `cropLog` `cl`, acciones de cebo en `FarmShopOp`). Se
  integró después de eventos del mundo (70) y minería/herrería (71).

## 10. API para otros sistemas

- `WeatherRules.season(day)`, `seasonDay(day)`, `daysToNextSeason(day)`.
- `WeatherRules.dayWeather(seed, day, biome)`, `window(seed, day, biome)`,
  `current(SkyState, {biome})`.
- `WeatherRules.hasSky(biome)`, `allows(biome, w)`, `biteChance(w)`,
  `fisherFactor(w)`.
- `SkyRules.nowIn(sky, place)`; `climateOf(biome)` (exposición, marcas).
- Minas: `BaitRules.foundBait(roll)` devuelve el cebo a dar como botín;
  cada veta picada da uno con `mineBaitChance` (tuning de herrería, 0.05;
  `MiningRules.veinBait`). Ver mining_smithing.md § 1.3.
- Herrería: `SmithMaterialDef.seasons` (vacío = todo el año) se aplica
  con `MiningRules.inSeason(def, día)` usando `WeatherRules.season`.
- Eventos del mundo: `season` / `weather` opcionales en cada evento,
  aplicados con `WorldEventRules.climateCondition(seed, día)` (clima del
  pueblo ese día) vía `WorldEventContext.extraCondition`
  (world_events.md § 1).
- OFICIOS → Herrería → COLECCIÓN usa la misma plantilla
  (`DsCollectionTemplate`, mining_smithing.md § 2.1).

### 6.2.1 Reloj de estación y anuncios (v0.46.2)

- La fila de estación muestra solo la estación actual. El último día dice
  "Último día de {estación} · mañana {siguiente}".
- ▸/▾ despliega: "{estación} · día X de Y", "Sigue: {siguiente} mañana / en N
  días" y "Después: {la otra}".
- El cartel de clima/pronóstico arriba del mapa aparece al cambiar y dura 3 s
  (como un snackbar), con fundido en el último medio segundo.
- Niebla: velo muy leve más dos capas de manchas pixeladas (celdas de 8 px
  ancladas al mundo, ruido suave, alfa cuantizado) que derivan lento; nunca
  bandas sólidas.
- Cada construcción del pueblo dibuja el poste de su cartel en el tile que
  responde al mouse.
