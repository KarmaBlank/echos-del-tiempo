# Día, noche y clima (v0.27.0)

El mundo tiene reloj propio: el día pasa, cae la noche y cada día trae
su clima. Lo lleva el anfitrión y todos ven la misma hora y el mismo
cielo. Números en Editor → Balance → Pueblo (`kTuning[town]`).

## 1. Reloj

- Un día dura `daySec` (300 s) de luz y `nightSec` (300 s) de noche: 10
  minutos reales. `SkyState.clock` = segundos desde el amanecer.
- Atardecer y amanecer suaves: la oscuridad (`SkyRules.darkness`, 0 = pleno
  día, 1 = noche cerrada) sube o baja con una curva suave de `duskSec`
  (40 s) centrada en el cambio. Es de noche con oscuridad ≥ 0.5.
- Anfitrión: `farmTick` avanza el reloj de a 1 s (también en misiones y
  batalla; no en la Travesía). El cielo viaja en `town.sky` (snapshot y
  mundo guardado): al volver a abrir el mundo sigue en la misma hora.
- Primer día de un mundo sin reloj (saves viejos): arranca a media mañana,
  despejado, con pronóstico.

### 1.3 Dónde se ve

Pueblo y mapas al aire libre (temas `pradera`, `bosque`, `mundo`,
`lobby`, `pueblo`; `SkyRules.outdoorThemes`). No en mazmorras, ruinas,
cavernas ni el abismo. En EDITAR PUEBLO no se dibuja el cielo (se edita
con luz).

## 2. Luces

- De noche el mapa se tiñe (`SkyPalette.night`, alfa hasta 0.72) y cada
  luz "come" la noche con un círculo suave: faros del pueblo (§ 5),
  braseros encendidos de las misiones (`Tile.brazierLit`) y luciérnagas.
- Luciérnagas: con oscuridad > 0.3, una cada tanto por celda de 5×5
  tiles, flotando y titilando, con un halito propio. Respetan la
  densidad de partículas.

## 3. Clima

### 3.1 Tirada

- Cada día nuevo usa el pronóstico de la víspera y tira el del día
  siguiente: tormenta `stormChance` (0.06), lluvia `rainChance` (0.25),
  si no despejado.
- El clima no dura todo el día: un tramo al azar de entre
  `weatherMinFrac` y `weatherMaxFrac` (20–45 %) del día completo
  (`SkyState.from` / `to`). Afuera del tramo, despejado.

### 3.2 Lluvia

- Mientras llueve (lluvia o tormenta) toda parcela plantada sin madurar
  queda regada a ritmo pleno (`FarmingRules.rain`, regador "Lluvia"), sin
  tocar la calidad de los riegos de la gente. Los granjeros no tienen
  nada para regar y siguen con lo demás.
- Se ve: gotas que caen (más con tormenta), cielo encapotado.

### 3.3 Tormenta

- Llueve igual. Cada `boltEverySec` (12 s) se tira un rayo con chance
  `boltChance` (0.4) sobre una parcela al azar de las huertas: vuelve a
  pasto sin arar y se pierde lo plantado (`TownRules.strike`). Evento
  `LightningEvent` (`bolt`): rayo dibujado, destello de pantalla (con el
  factor de destellos de accesibilidad; 0 = sin destello) y sonido.
- Pesca: cada lance pica con chance `stormBite` (0.3); si no, "Con la
  tormenta no pica nada" al llegar la hora de la picada
  (`FishingMinigame.biteChance`). Los pescadores sacan `stormFisher`
  (35 %) de lo de siempre.

### 3.4 Pronóstico

De noche, un cartel chico arriba: "Noche · Mañana: lluvia". De día con
lluvia o tormenta, "Llueve" / "Tormenta".

## 4. Accesibilidad

- Destello del rayo × `GameSettings.flashFactor` (reducir destellos y
  reducir movimiento lo bajan o lo apagan).
- Reducir movimiento: lluvia más lenta, sin parpadeo de las luces.

## 5. Faros del pueblo

- EDITAR PUEBLO → tile libre → CONSTRUIR → FARO (`faroCost`, 300 de oro).
  1×1; va en pasto o camino (no corta caminos ni es sólido); no pisa
  lugares, construcciones, carteles, cofres ni otro faro.
- Clic en un faro: MOVER o BORRAR (sin devolver el oro).
- Mismo dibujo que los braseros de las misiones sobre un poste; de noche
  se prenden y alumbran alrededor.
- Datos: `TownState.lights` (`lt`, tiles del pueblo base). Acciones: `town`
  `place` con `id = faro`, `move` / `remove` con `tg = faro@x,y`.

## 6. Música

De noche en el pueblo suena `townNight` (music.md § 5.3), con el
crossfade normal al atardecer y al amanecer. La pesca sigue ganando.

## 7. Red

Protocolo 49 (netcode.md): `town.sky`, `town.lt`, evento `bolt`.
