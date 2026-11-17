# Spec: Sonido (efectos chiptune)

Fuente de verdad del **origen**: prototipo `ecos-del-tiempo.html`,
`sfxInit` y `beep` (líneas 1392-1395) y cada llamada a `beep(`:
- 1200: empieza tu turno (`myTurn` con un `B.bid:B.clock` nuevo);
- 1231: cuenta regresiva del turno (`left ≤ 5`, una vez por segundo);
- 1461: cinemática de ULT (`fxVisual`, `k:'ult'`);
- 1469: `onNewFx` — números de daño/cura, destello (`flash`) y
  `¡NIVEL N!`.

El prototipo hace sonar el mismo `beep` para todos los ataques. El
dueño pidió **un sonido para cada ataque** y **un "clink" satisfactorio
en cada crítico**: el diseño de abajo (§ "Diseño de sonido de combate")
reemplaza los `beep` de los números de batalla por sonidos por
habilidad / arma / elemento / enemigo. Los sonidos de turno, cuenta
regresiva, nivel y destello siguen siendo los del prototipo. Las ULT
tienen sonido propio por ULT (§ "Ultimates"); el `ultimate` del
prototipo queda solo como respaldo (arma desconocida).

Implementación:

| Pieza | Archivo |
|---|---|
| Modelo de voz y efecto (`SfxTone`, `SfxDef`, `Waveform`) | `lib/core/audio/sfx_catalog.dart` |
| Catálogo (`Sfx` ids, `kSfxCatalog`, recetas por habilidad / enemigo) | `lib/core/audio/sfx_catalog.dart`, `lib/core/audio/sfx_recipes.dart` |
| Sintetizador a WAV PCM 16 bits | `lib/core/audio/wav_synth.dart` |
| Servicio y reproductor (`SfxService`, `SfxPlayer`, `NoopSfxPlayer`) | `lib/core/audio/sfx_service.dart` |
| Traducción de eventos de la sesión a sonidos | `lib/features/world/presentation/session_sfx.dart` |
| Registro en el service locator | `lib/core/di/service_locator.dart` |

Tests: `test/core/audio/wav_synth_test.dart`,
`test/core/audio/sfx_catalog_test.dart`,
`test/features/world/session_sfx_test.dart`.

## `beep(f, d, type, vol)` (prototipo)

Un oscilador `type` (por defecto `square`) a `f` Hz con ganancia inicial
`vol` (por defecto `0.05`) y una rampa exponencial hasta `0.0001` en `d`
segundos; se corta en `d`. Varios `beep` encadenados con `setTimeout` son
un mismo efecto con tonos desplazados. El puerto lo modela como una
`SfxTone` con los parámetros nuevos en su valor por defecto.

## Sintetizador (`WavSynth`)

Dart puro, sin plugins, **determinista** (el ruido sale de un LFSR con
semilla fija, no de `Random`). Mezcla las voces (`SfxTone`) de un efecto
en un buffer mono de 22050 Hz (configurable).

Cada voz:

| Parámetro | Por defecto | Qué hace |
|---|---|---|
| `frequency` | — | Hz. En `noise`, la frecuencia de reloj del LFSR (más alta = más brillante). |
| `duration` | — | segundos que dura la voz |
| `wave` | `square` | `square`, `pulse` (25 %), `sawtooth`, `triangle`, `sine`, `noise` |
| `volume` | 0.05 | ganancia pico de la voz |
| `delay` | 0 | segundos desde el inicio del efecto |
| `endFrequency` | = `frequency` | barrido exponencial `f(t) = f0·(f1/f0)^(t/d)` (sube o baja) |
| `attack` | 0 | subida lineal 0 → 1 (s) |
| `hold` | 0 | meseta a volumen pleno después del ataque (s) |
| `vibratoRate`, `vibratoDepth` | 0 | `f(t)·(1 + depth·sin(2π·rate·t))` |
| `lowpass` | 0 (apagado) | filtro de un polo (Hz) sobre la onda: ruido "filtrado" |
| `crush` | 0 (apagado) | bits del envolvente×onda cuantizado (sonido "4 bits") |
| `seed` | 1 | semilla del LFSR (variantes de ruido) |

Envolvente (ADSR simplificado: ataque, meseta, caída exponencial):

```
env(t) = t/attack                                   t < attack
       = 1                                          t < attack + hold
       = (0.0001/vol)^((t − attack − hold)/(d − attack − hold))   después
muestra(t) = onda(fase(t)) × env(t) × vol
```

Con `attack = hold = 0` y frecuencia constante es exactamente el `beep`
del prototipo (`fase = f·t`). Con barrido o vibrato la fase se acumula
muestra a muestra. Ruido: LFSR de 15 bits estilo NES (`bit = b0 ⊕ b1`),
avanza una vez por cada ciclo de la fase; salida ±1.

Mezcla y nivel (`SfxDef`):
- las voces se suman sin recortar;
- si el efecto tiene `peak`, la mezcla se **normaliza** para que su pico
  sea exactamente `peak` (nunca recorta; las voces son "recetas" y el
  nivel final lo fija la categoría, ver § "Niveles");
- recién ahí se recorta a `[-1, 1]` (sin `peak`, como el prototipo);
- se escriben como PCM con signo de 16 bits little-endian
  (`round(x × 32767)`) detrás de una cabecera RIFF/WAVE de 44 bytes
  (`fmt ` PCM = 1, 1 canal, `byteRate = rate × 2`, `blockAlign = 2`).

Largo = `max(retraso + duración)` del efecto. `SfxService` cachea los
bytes de cada id.

## Niveles

Los picos se fijan por categoría (normalización) para que nada recorte
y queden márgenes cuando varios suenan juntos:

| Categoría | Pico |
|---|---|
| Interfaz (`myTurn`, `turnTick`, `levelUp`) | 0.28 |
| Números del prototipo (`hit`, `hurt`, `heal`), `flash` | 0.30 |
| Estados (aplicación y tic), curas, maná, ítems | 0.30 |
| Arranque de acción (golpe/disparo/conjuro, firma de habilidad, enemigo) | 0.36 |
| Impactos | 0.38 |
| Golpe pesado de jefe, K.O. | 0.42 |
| `crit.clink` (tiene que oírse sobre el impacto) | 0.45 |
| `ultimate` (prototipo), preparación de ULT | 0.45 |
| descarga de ULT | 0.46 |
| impacto de ULT | 0.50 |

## Diseño de sonido de combate

Ids de sonido = `String` (`Sfx.*` para los fijos, `skill.<id>` y
`enemy.<tipo>` para las familias). "Ruido" = `noise` (LFSR); `a→b` =
barrido; `+` = capas; `@t` = retraso.

### Arranque por arma (ataque normal y debajo de las habilidades físicas)

| Sonido | Receta | Armas |
|---|---|---|
| `swing.blade` | ruido 9 k→3 k Hz 0.12 s, ataque 20 ms, lowpass 6 k (silbido de hoja) + pulse 1400→700 0.05 | `espada`, `espada+escudo` |
| `swing.heavy` | ruido 4 k→1.2 k 0.2 s, ataque 50 ms, lowpass 2.2 k + triangle 160→90 0.16 | `hacha`, `maza+escudo`, `martillo+escudo` |
| `shot.bow` | triangle 330→240 0.14 vibrato 18 Hz (cuerda) + ruido 5 k→9 k 0.22 @0.02 lowpass 5 k (flecha) | `arco` |
| `shot.rifle` | ruido 20 k 0.03 (fogonazo) + ruido 3 k→700 0.28 lowpass 2.5 k (eco) + square 140→55 0.10 | `rifle` |
| `shot.staff` | square 520→1250 0.18 vibrato 22 Hz + triangle 1040→2500 0.16 | `báculo` |
| `shot.tome` | pulse 300→900 0.2 crush 4 + sine 1200 0.18 vibrato 9 Hz | `tomo` |

Sin arma conocida: `swing.blade`.

### Impactos

| Sonido | Receta | Cuándo |
|---|---|---|
| `impact.slash` | ruido 12 k 0.06 + square 900→280 0.06 | físico, arma de hoja |
| `impact.blunt` | sine 150→45 0.2 + ruido 2.5 k 0.09 lowpass 1.2 k + triangle 90→40 0.14 | físico, arma pesada |
| `impact.arrow` | ruido 7 k 0.04 + square 620→180 0.05 ("toc") | físico, arco |
| `impact.bullet` | ruido 16 k 0.05 + triangle 1500→900 0.08 | físico, rifle |
| `impact.arcane` | pulse 1200→380 0.14 crush 4 + ruido 8 k 0.05 | arcano (mágico sin estado), báculo/tomo |
| `impact.fire` | ruido 2.6 k 0.28 lowpass 2.2 k ataque 10 ms + ruido 11 k 0.18 crush 3 (chisporroteo) | elemento Quemadura |
| `impact.ice` | triangle 3136 0.3 + triangle 2349 0.34 @0.02 + ruido 14 k 0.05 (cristal) | elemento Congelación |
| `impact.poison` | sine 520→260 0.07, 440→220 @0.06, 600→300 @0.12 (burbujas) + ruido 1.5 k 0.2 lowpass 700 | elemento Veneno |
| `impact.holy` | sine 1047 + 1568 @0.02 + 2093 @0.04 con vibrato 7 Hz, 0.35 | elemento Sagrado |
| `impact.hurt` | square 190→85 0.13 + ruido 3 k 0.08 lowpass 1.8 k | un jugador recibe daño |
| `crit.clink` | sine 2093→2030 0.26 + sine 5267→5110 0.18 (parciales inarmónicos ×2.52) + triangle 3140→3050 0.12 muy suave, ataque 2 ms, + ruido 18 k 0.012 (transitorio) | **cada** golpe crítico, encima del impacto |

Elemento de un golpe = el del efecto visual (`skillElement` de
`fx_style.dart`): Sagrado si la habilidad es sagrada, si no el estado
que aplica, si no arcano (mágica) o físico. Físico → impacto según el
arma del atacante (hoja/pesada/arco/rifle/arcano). Aturdido → impacto
físico del arma (el mareo lo pone el sonido del estado).

### Firma de cada habilidad (`skill.<id>`)

Una por cada id de `kSkills` (cubierto por test). Se toca al arrancar la
acción; si la habilidad es física, encima del arranque del arma. Cada
una es una variante de la base de su elemento con su propia altura y
largo, para que se reconozca:

| Familia (base) | Receta base | Habilidades (altura × / largo ×) |
|---|---|---|
| Corte | ruido barrido 10 k→3 k + pulse descendente | `giro` (dos cortes, 1.0/1.0), `embestida` (pasos + corte 0.8/1.2), `estocada` (estocada aguda 1.4/0.6), `tajoT` (+ warble temporal 0.7/1.6), `sagrado` (+ campana sagrada 1.2/1.0), `golpeEscudo` (+ "clank" de escudo 1.0/0.8) |
| Corte elemental | corte + capa del elemento | `ignea` (+ fuego), `tajoCarmesi` (+ fuego grave, 0.85), `corteGlacial` (+ cristal), `tajoOcaso` (+ burbujas graves, 0.7), `hendir` (+ burbujas) |
| Pesado | triangle grave + retumbo de ruido lowpass | `sismo` (retumbo largo 1.0/1.4), `temblor` (temblor con vibrato 0.9/1.2), `aplastar` (golpe seco 1.1/0.8), `juicio` (+ campanas sagradas 1.0/1.3), `erupcion` (+ fuego, 0.8/1.3), `vendaval` (viento helado: ruido largo + cristal 1.0/1.5) |
| Flecha / disparo | silbido + cola | `rafaga` (3 silbidos cortos), `lluvia` (5 silbidos descendentes), `certero` (silbido agudo y tenso), `aturdir` (+ warble), `rayoF` (+ zap eléctrico), `venenosa` (+ burbujas), `saeta` (+ cristal), `ceroAbs` (+ cristal grave), `sombra` (silbido grave + pulso oscuro), `flechaSolar` (+ campana), `metralla` (ráfaga de 4 chasquidos + burbujas), `perfora` (silbido largo + estampido) |
| Fuego | ruido que sube (whoosh) + sawtooth grave | `chispa` (corto, agudo 1.4/0.6), `bola` (1.0/1.0), `llamarada` (1.0/1.4 + chisporroteo), `infierno` (0.7/1.8, dos capas), `consagrar` (fuego + campana sagrada) |
| Hielo | campanitas triangle + barrido agudo | `lanzaH` (1.0/1.0), `ventisca` (viento + campanas, 1.0/1.6) |
| Veneno | burbujas square + ruido lowpass | `dardo` (1.2/0.7), `niebla` (0.9/1.4), `plaga` (0.7/1.8) |
| Arcano / tiempo | pulse con vibrato + crush | `detener` (reloj que se frena: tics + barrido descendente), `descarga` (zap eléctrico: ruido 20 k + square 2 k↔1.5 k) |
| Sagrado | sines en quinta con vibrato | `lanzaLuz` (barrido ascendente + campana) |
| Cura | arpegio triangle ascendente | `cura` (4 notas), `curaM` (6 notas, una 8va arriba al final), `sanar` (3 notas suaves), `bendicion` (arpegio + campana) |
| Mejora / escudo | arpegio square / barrido + anillo metálico | `prisa` (arpegio rápido ascendente ×2), `fortaleza` (dos notas graves + anillo), `proteccion` (barrido + acorde sagrado), `escudoFe` (anillo de escudo + campana), `aura` (acorde sostenido con vibrato lento) |
| Provocar | sawtooth 150 Hz con vibrato 30 Hz (zumbido "grito") + square 300 | `provocar` |

### Otros sonidos

| Sonido | Receta | Cuándo |
|---|---|---|
| `heal.sparkle` | triangle 1319, 1568, 2093, 2637 de 0.08 cada 0.04 | cada jugador curado por una acción |
| `mana.up` | sine 600→1200 0.2 vibrato 8 Hz + triangle 1800 @0.1 | `+N MP` |
| `item.potion` | sine 300→520 0.07, 280→500 @0.09 (tragos) + burbuja | poción |
| `item.ether` | sine 900→1800 0.22 vibrato + triangle 2400 @0.12 | éter |
| `defend` | square 220 0.05 + ruido 8 k 0.05 + triangle 1500 0.22 (anillo) | defender |
| `dual.cast` | acorde square 392/494/587 → una 8va arriba, 0.35 | dúo (junto al `flash`) |
| `status.burn` | ruido 9 k 0.22 crush 3 + sawtooth 220→330 0.12 | aplica Quemadura |
| `status.poison` | 3 burbujas square descendentes | aplica Veneno |
| `status.freeze` | triangle 2637, 3520 @0.03, 4186 @0.06 | aplica Congelación |
| `status.stun` | triangle 1200→700 0.4 vibrato 9 Hz (mareo) | aplica Aturdido |
| `status.holy` | sine 1568 + 2349 0.3 | aplica Sagrado |
| `status.regen` | triangle 784→1175 0.25 | aplica Regeneración |
| `tick.burn` | ruido 3 k 0.16 lowpass 2 k + ruido 10 k 0.1 crush 3 | Quemadura al empezar el turno |
| `tick.poison` | 2 burbujas sine graves | Veneno al empezar el turno |
| `tick.holy` | sine 1319 0.18 | Sagrado al empezar el turno |
| `tick.regen` | triangle 1047, 1319 @0.05 | Regeneración al empezar el turno |
| `skip.freeze` | ruido 16 k 0.12 + triangle 2637, 3520, 1760 cortos escalonados (hielo que se quiebra) | `TurnSkippedEvent` por Congelación |
| `skip.stun` | triangle 1000↔ vibrato 10 Hz 0.45 + square 1500 tics | `TurnSkippedEvent` por Aturdido |
| `ko.enemy` | ruido 6 k→400 0.35 lowpass 3 k + square 400→80 0.3 | `KnockedOutEvent` de un enemigo |
| `ko.player` | square 392, 330, 262, 196 de 0.12 en cadena | `KnockedOutEvent` de un jugador |
| `revive` | triangle 262→1047 0.3 + arpegio corto | `RevivedEvent` |
| `delay` | sawtooth 800→200 0.35 vibrato 6 Hz | `DelayedEvent` (una vez por acción) |

### Disparadores del árbol (procs)

Cada notable / keystone que se nota en batalla tiene un sonido corto
(pico 0.34; los "golpes" — estallido, campana, metal, vidrio — 0.38;
el turno extra 0.40). Ids `proc.*` y `echo.<skill>`:

| Sonido | Receta | Mecánica |
|---|---|---|
| `proc.zip.0` / `.1` / `.2` | square 600→2400 0.09 vibrato 30 Hz + ruido 14 k crush 2, ×1, ×1.26, ×1.5 de altura (sube con cada salto) | Rebote, Corte en Cadena, Arco Voltaico, Cadena Infinita: uno por salto (hasta 3) |
| `proc.whump` | sine 90→40 0.35 + ruido 900 lowpass 500 + triangle 60 crush 3 + chisporroteo @0.06 | Combustión |
| `proc.clang` | square 1760 0.02 + sines inarmónicas 1320 / 2980 / 4410 que decaen + ruido 12 k 0.02 + triangle 220 (cuerpo) | Contraataque |
| `proc.bell` | sine 523 + 1047 (vibrato leve) + parciales 2890 y 5650 de campana, 0.9 s | Castigo Divino |
| `echo.<skill>` | la firma de la habilidad ×0.7 + copias @0.12 ×0.4 y @0.24 ×0.2 (eco) | Eco Arcano |
| `proc.whoosh` | dos silbidos de ruido agudos y cortos | Frenesí |
| `proc.flare` | sawtooth 180→360 0.25 lowpass 2 k + ruido 3 k→6 k | Represalia |
| `proc.mark` | tics square 2400 y 3200 + sine 1600 (fijado) | Marca del Cazador |
| `proc.weaken` | triangle 600→220 0.3 + sine 300→150 vibrato 6 Hz | Debilitar |
| `proc.shield` | triangle 400→1200 0.18 + sines 1568 / 2093 @0.12 con vibrato (vidrio que se arma) | `ShieldEvent` gana (Mano Sanadora, Desafío, Égida) |
| `proc.shieldBreak` | ruido 16 k 0.06 + triangle 3136 / 4186 / 2637 cortos escalonados + square 220 (golpe sordo) | `ShieldEvent` absorbe |
| `proc.extraTurn` | sine 400→1600 0.25 con ataque (al revés) + 2 tics de reloj + arpegio 1568 / 2093 / 3136 @0.22 | Danza de Cuchillas |
| `proc.heartbeat` | dos latidos sine 70→45 + triangle 140→90 @0 y @0.2 | Sed de Sangre |
| `proc.plague` | 4 burbujas graves + sawtooth 90 vibrato 5 Hz | Plaga Contagiosa |
| `proc.steam` | ruido 6 k→9 k 0.45 lowpass 7 k (siseo) + ruido 2 k grave | Choque Térmico |
| `proc.ultCharge` | arpegio square 1319 / 1760 / 2349 + sine 2637 @0.1 | Guardián |
| `proc.anvil` | square 1100 0.02 + triangle 880 vibrato 9 Hz (mareo) + sine 2200 | Martillo Bendito |
| `proc.wind` | ráfaga de viento corta | Viento a Favor |

Plegaria y Tiempo Gélido usan los sonidos de siempre (`tick.regen` de
la cura sin acción, `delay`); Último Aliento, Punto Débil, Fractura y
Alma de Hielo no tienen evento ni sonido.

### Enemigos (`enemy.<tipo>`, uno por id de `kEnemies`, cubierto por test)

| Sonido | Receta |
|---|---|
| `enemy.slime` | triangle 180→420 0.12 + ruido 1.5 k 0.1 lowpass 800 (húmedo) + triangle 420→160 @0.1 (squish) |
| `enemy.bat` | square 2400→3400 0.12 vibrato 40 Hz + square 2800→3800 @0.1 (chillido) |
| `enemy.golem` | sine 70→40 0.3 + ruido 1.2 k 0.2 lowpass 400 + triangle 110→55 crush 3 (pisotón) |
| `enemy.ghost` | sine 520→340 0.6 ataque 0.15 vibrato 6 Hz + triangle 780→510 (lamento) |
| `enemy.reyLimo` | squish del limo una 5ta abajo, más largo, con capa grave |
| `enemy.golemReloj` | pisotón del gólem + 4 tics de reloj square 2 k |
| `enemy.devorador` | sawtooth 80→50 0.6 vibrato + ruido 800 lowpass (rugido) + sine 45 |
| `enemy.generic` | ruido 5 k→2 k 0.12 + square 300→150 (tipo desconocido) |
| `enemy.heavy` | sine 60→30 0.4 + ruido 2 k 0.3 lowpass 600 (golpe brutal, encima del sonido del enemigo) |

## Ultimates

Cada ULT tiene **tres sonidos propios**, alineados con las fases de su
cinemática (docs/specs/battle_presentation.md § "Ultimates"; los tiempos
salen del mismo guion `UltScript`, así sonido e imagen no se separan):

| Id | Cuándo | Pico |
|---|---|---|
| `<ultId>.build` | preparación, @0 (dura ≤ `build`) | 0.45 |
| `<ultId>.release` | descarga, @`build` (incluye silbidos, tajos previos, disparo…) | 0.46 |
| `<ultId>.impact` | cada impacto, @`impactFor(i)`, 3 objetivos como máximo | 0.50 |

`<ultId>` = `SkillDef.id` de `kUltimates` (`ult_espada`, `ult_hacha`, …).
El `crit.clink` sigue sonando encima en cada crítico de la ULT.

Recetas ("@t" relativo al inicio de ESE sonido):

| ULT | Preparación | Descarga | Impacto |
|---|---|---|---|
| Tajo Final | viento que sube (ruido 2 k→7 k, ataque 0.5 s) + "shing" de la hoja @0.62 (triangle 2637 + sine 3951, vibrato) | tres tajos rápidos @0.2, 0.32, 0.44 (silbido de hoja agudo) + inhalación de ruido que sube hacia el final | tajo pesado (ruido 12 k→2 k) + golpe sine 110→35 + campanazo metálico inarmónico + cola de ruido grave |
| Cataclismo | retumbo que crece (sine 38 Hz + ruido 700 lowpass 300, ataque 0.7) + tics de piedras crush | golpe al piso @0.05 (sine 90→30 + ruido) + crujidos (ruido crush 3) @0.12-0.4 | estallido: ruido 1.2 k lowpass 900 largo + sine 60→22 + escombros (ruido 6 k crush 3 en ráfagas) |
| Meteoro | dron ominoso (sawtooth 55→110 vibrato 5 Hz, lowpass 900) + crepitar de fuego | silbido que baja (sine 1800→300, 0.45 s) + rugido de fuego que sube | explosión: ruido 1.5 k lowpass 1.2 k + sine 70→28 + chisporroteo |
| Paradoja | tic-tac que se acelera (square 2 k, 8 tics) + barrido pulse 900→150 crush 4 "al revés" | oleaje inverso (ruido 600→6 k con ataque largo 0.5 s) + arpegio descendente de campanitas | congelado: racimo de cristal (triangle 3136, 3951, 4699) + estallido de hielo (ruido 16 k) + sine 2093 con vibrato |
| Tormenta de Flechas | cuerda que cruje (triangle 220 vibrato) + 5 silbidos que suben (andanada al cielo) | lluvia: 14 golpecitos de ruido cortos repartidos en 1.1 s + silbido largo de fondo | ráfaga de 4 impactos de flecha + burbujas de veneno |
| Disparo Letal | carga que sube (sine 300→2400 vibrato 9 Hz, 0.8 s) + "clac" del cerrojo @0.72 | estampido @0.05 (ruido 20 k + ruido 2 k lowpass + square 120→40) + vuelo en cámara lenta (ruido 4 k→800 lowpass, 0.4 s) | impacto: crack (ruido 18 k) + ping metálico (sine 1760 + 4435) + golpe grave |
| Baluarte | acorde que se hincha (sawtooth 196/247/294 lowpass 1.2 k, ataque 0.6) | "clang" de escudo + zumbido de cúpula (sines 392/587/784 con vibrato lento) | campanas de cura (arpegio sine 1047, 1319, 1568, 2093) + brillo |
| Juicio Divino | coro (sines 523/659/784 con vibrato, ataque 0.5) + campanita | campana que baja + zumbido de puntería que sube | pilar: campanas sagradas + ruido 3 k→9 k (whoosh) + sine 80→30 |
| Martillo Celestial | trueno lejano (ruido 400 lowpass 250) + chispas eléctricas (ruido 20 k crush 2) + tono que sube | caída: ruido 6 k→600 que baja @0.1-0.4 | golpe brutal: sine 80→22 largo + ruido 1 k lowpass 700 + "clang" inarmónico + mareo (triangle 1000 vibrato 9 Hz) |


## Qué evento suena (`SessionSfx`)

Un oyente fuera del motor (el motor no sabe de sonido) escucha
`SessionController.events` y las vistas nuevas. De la vista guarda el
último `BattleState` (arma de cada jugador, tipo de cada enemigo) — el
motor no cambia. Cada sonido de batalla es un `SfxCue(id, delayMs)`:
`SfxService.play(id, delayMs:)` lo programa con un `Timer`.

### Tiempos (los de `battle_fx.dart`)

- Retraso del impacto en un objetivo (`hitDelay`): proyectil 280 ms
  (ataque normal a distancia a un objetivo; habilidad que hace daño y es
  mágica o de un arma a distancia), dúo 300 ms, ULT `impactFor(i)` de
  su guion (docs/specs/battle_presentation.md § "Ultimates"; ya incluye
  la separación por objetivo), si no 0.
- Cuerpo a cuerpo (sin proyectil): el impacto suena 50 ms después del
  arranque, para que el silbido se oiga antes del golpe.
- Varios objetivos: el impacto suena en los **3 primeros** con 70 ms de
  separación; los demás no suenan (sin cacofonía). Los clinks de crítico
  no tienen tope: uno por cada golpe crítico, en el tiempo de su impacto
  (con la misma separación por objetivo).
- Estados aplicados: una vez por estado y por acción, 90 ms después del
  impacto en su objetivo.
- K.O.: 100 ms después del impacto en ese objetivo.
- Tope global: 12 sonidos por paso (el pool de voces).

### Mapeo

- `TurnStartedEvent` cierra la acción en curso.
- `ActionEvent` (arranque, @0):
  - `attack`: arranque del arma del actor;
  - `skill`: física → arranque del arma + `skill.<id>`; el resto →
    `skill.<id>`;
  - `ultimate`: **nada** (lo cubre `UltimateUsedEvent` →
    `ultimateCues`);
  - `dual`: `flash` (prototipo) + `dual.cast`;
  - `potion` → `item.potion`; `ether` → `item.ether`; `defend` →
    `defend`;
  - `enemyAttack`: `enemy.<tipo>`; `enemyHeavy`: `enemy.<tipo>` +
    `enemy.heavy` @80 ms; `enemyArea`: `flash` (prototipo) +
    `enemy.<tipo>`.
- `DamageEvent`:
  - de estado (`fromStatus`, sin acción): `tick.<statusSource>` (una vez
    por estado y por paso);
  - dentro de una ULT: `<ult>.impact` en `impactFor(i)` del guion
    (§ "Ultimates"), en los 3 primeros objetivos; si es crítico además
    `crit.clink` en ese mismo tiempo (sin tope);
  - a un jugador: `impact.hurt`;
  - a un enemigo: impacto del elemento (§ "Impactos"); dentro de
    Aura Restauradora (luz de la rama creyente) → `impact.holy`;
  - sin acción y sin estado: `hit` (prototipo);
  - crítico: además `crit.clink` en el tiempo del impacto.
- `HealEvent`: maná dentro de una acción → `mana.up`; maná sin acción →
  nada; vida sin acción (Regeneración) → `tick.regen`; vida dentro de
  una ULT (Baluarte) → `<ult>.impact` una vez, en `impactFor(0)`; vida dentro de una acción →
  `heal.sparkle` (@120 ms; poción @200 ms, después del trago), tope 3
  con separación.
- `StatusAppliedEvent` → `status.<kind>`.
- `TurnSkippedEvent` → `skip.freeze` / `skip.stun`.
- `DelayedEvent` → `delay`.
- `KnockedOutEvent` → `ko.enemy` / `ko.player`.
- `RevivedEvent` → `revive`.
- `UltimateUsedEvent` → `ultimateCues`: `<ult>.build` @0 y
  `<ult>.release` @`build` del guion; con arma desconocida, `ultimate`
  (prototipo).
- `LevelUpEvent` → `levelUp` (una vez por evento).
- Vista: `myTurn` cuando `view.myTurn` y cambió `(battle.id,
  state.clock)`; `turnTick` cuando, con `myTurn`, `ceil(30 − turnTime)`
  es `≤ 5` y distinto del último.

### Procs del árbol (tiempos de `ProcTiming`)

Los procs suenan con los tiempos de su efecto visual
(docs/specs/battle_presentation.md § "Disparadores del árbol (procs)"):
`base` = 0 sin acción, el regreso del guion en una ULT (después de sus
impactos), si no el retraso del golpe de la acción (`hitDelay`) +
120 ms.

- `ProcEvent`: zip del salto `h` en `base + h × 130` (hasta 3 saltos);
  `proc.whump` y `proc.bell` en `base`; `proc.clang` en `base + 80`;
  `echo.<skill>` en `base + 220` (si la habilidad no tiene eco, nada);
  Danza, Sed de Sangre, Plaga, Choque Térmico, Guardián, Martillo
  Bendito y Viento a Favor en `base`. Cada sonido de proc (salvo los
  zips) suena **una vez por paso**.
- `BuffAppliedEvent`: Frenesí `proc.whoosh`, Represalia `proc.flare`,
  Marca `proc.mark`, Debilitar `proc.weaken`, en `base`.
- `ShieldEvent`: gana → `proc.shield` en `base` (una vez por paso);
  absorbe → `proc.shieldBreak` en el tiempo del golpe enemigo
  (cuerpo a cuerpo: 50 ms).
- `DamageEvent` con `sourceId` (daño secundario): **no** suena el
  impacto normal (el proc ya tiene su sonido); su K.O. suena 100 ms
  después del golpe secundario.
- Sed de Sangre y Plaga usan la base tardía (después del último golpe
  secundario del paso + 60 ms), como la escena; la cura de Sed de
  Sangre: `heal.sparkle` 100 ms después del latido.
- Viento a Favor: los sonidos del ataque gratis se corren a `base`.
- Tope: los procs suman como mucho **4** sonidos por paso y entran en
  el tope global de 12: si hace falta, se recortan los últimos sonidos
  primarios para dejarles lugar.

El chat, los pasos y los menús no suenan (el prototipo tampoco).

## Reproducción

`SfxPlayer` es la interfaz (`play(Uint8List wav)`). El juego registra
`AudioplayersSfxPlayer` (`lib/core/audio/audioplayers_sfx_player.dart`,
paquete `audioplayers`):

- Cada WAV se escribe **una sola vez** a un archivo temporal y se
  reproduce con `DeviceFileSource`, que funciona igual en todas las
  plataformas de escritorio (no depende del soporte de `BytesSource`).
- Pool de 12 `AudioPlayer`: cada sonido va al primer reproductor libre
  (desde la posición de la rotación) y, si están todos sonando, al más
  viejo. Con 4 se cortaba la ULT (1.75 s) cuando un golpe a TODOS + sus
  estados sonaban en el mismo paso; el prototipo suma osciladores sin
  límite.
- `NoopSfxPlayer` queda para tests y plataformas sin audio.

`sfxInit` (crear el `AudioContext` con el primer clic) no hace falta en
escritorio.

## Muestras

Para escuchar una muestra representativa sin abrir el juego:
`SFX_SAMPLES_DIR=<carpeta> flutter test test/core/audio/sfx_catalog_test.dart`
escribe ahí un WAV por sonido de la lista `_samples` del test (nombres
descriptivos, p. ej. `crit_clink.wav`, `enemy_bat_screech.wav`) y, por
cada ULT, `ult_<nombre>.wav` con la secuencia completa (preparación +
descarga + impactos en 3 objetivos, en los tiempos del guion). Los
procs del árbol escriben `proc_<nombre>.wav` (uno por sonido) y tres
secuencias en sus tiempos: `proc_chain_3_hops.wav`,
`proc_shield_absorb_hit.wav` y `proc_combustion_full.wav`. Sin la
variable, el test no escribe nada.
