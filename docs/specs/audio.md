# Spec: Sonido (efectos 8 bits)

Fuente de verdad: prototipo `ecos-del-tiempo.html`, `sfxInit` y `beep`
(líneas 1392-1395) y cada llamada a `beep(`:
- 1200: empieza tu turno (`myTurn` con un `B.bid:B.clock` nuevo);
- 1231: cuenta regresiva del turno (`left ≤ 5`, una vez por segundo);
- 1461: cinemática de ULT (`fxVisual`, `k:'ult'`);
- 1469: `onNewFx` — números de daño/cura, destello (`flash`) y
  `¡NIVEL N!`.

Implementación:

| Pieza | Archivo |
|---|---|
| Catálogo (`Sfx`, `SfxTone`, `kSfxCatalog`) | `lib/core/audio/sfx_catalog.dart` |
| Sintetizador a WAV PCM 16 bits | `lib/core/audio/wav_synth.dart` |
| Servicio y reproductor (`SfxService`, `SfxPlayer`, `NoopSfxPlayer`) | `lib/core/audio/sfx_service.dart` |
| Traducción de eventos de la sesión a sonidos | `lib/features/world/presentation/session_sfx.dart` |
| Registro en el service locator | `lib/core/di/service_locator.dart` |

Tests: `test/core/audio/wav_synth_test.dart`,
`test/features/world/session_sfx_test.dart`.

## `beep(f, d, type, vol)`

Un oscilador `type` (por defecto `square`) a `f` Hz con ganancia inicial
`vol` (por defecto `0.05`) y una rampa exponencial hasta `0.0001` en `d`
segundos; se corta en `d`. Varios `beep` encadenados con `setTimeout` son
un mismo efecto con tonos desplazados.

El puerto lo modela como un `Sfx` = lista de `SfxTone(frecuencia,
duración, onda, volumen, retraso)`.

## Catálogo

| `Sfx` | Tonos (Hz, s, onda, vol, retraso) | Cuándo (prototipo) |
|---|---|---|
| `myTurn` | 523 0.08 square 0.05 @0; 784 0.12 square 0.05 @0.09 | empieza tu turno (1200) |
| `turnTick` | 1200 0.04 square 0.05 | cada segundo con ≤ 5 s de turno (1231) |
| `ultimate` | 196 0.5 sawtooth 0.05 @0; 392 0.4 square 0.04 @0.3; 98 0.6 sawtooth 0.07 @1.15 (`ULT_DL`) | ULT (1461) |
| `heal` | 880 0.08 square 0.05 | número verde `#7bed9f` (1469) |
| `hurt` | 160 0.08 square 0.05 | número `#ff6b81`: daño normal a un jugador (1469) |
| `hit` | 420 0.08 square 0.05 | cualquier otro número: daño a enemigos, crítico a un jugador, maná, estados (1469) |
| `flash` | 220 0.3 sawtooth 0.04 | destello (área de jefe, dúo) (1469) |
| `levelUp` | 660 0.1 square 0.05 @0; 990 0.15 square 0.05 @0.1 | texto `¡NIVEL N!` (1469) |

## Qué evento suena (`SessionSfx`)

Un oyente fuera del motor (el motor no sabe de sonido) escucha
`SessionController.events` y las vistas nuevas:
- `BattleStepEvent`: por cada `BattleEvent`, en orden:
  - `HealEvent` de vida → `heal`; de maná → `hit`;
  - `DamageEvent` de estado (`fromStatus`): `hit` si el estado que manda
    es Quemadura (número naranja), si no `heal` (número verde: el
    prototipo pinta así el daño de Veneno/Sagrado, línea 737, y por eso
    suena a 880 Hz);
  - `DamageEvent` a un jugador, no crítico → `hurt`;
  - cualquier otro `DamageEvent` → `hit`;
  - `UltimateUsedEvent` → `ultimate`;
  - `ActionEvent` de un dúo o del Colapso Temporal de un jefe
    (`enemyArea`) → `flash` (los `addFx({k:'flash'})` de las líneas 781
    y 853).
  Como cada `addFx` del prototipo, todos los números de un paso suenan
  (el reproductor decide si se superponen).
- `LevelUpEvent` → `levelUp` (una vez por evento).
- Vista: `myTurn` cuando `view.myTurn` y cambió `(battle.id,
  state.clock)`; `turnTick` cuando, con `myTurn`, `ceil(30 − turnTime)`
  es `≤ 5` y distinto del último.

Igual que en `onNewFx`, el sonido de un número suena al llegar el evento
aunque la animación espere al proyectil (`f.dl`). El chat, los pasos y
los menús no suenan (el prototipo tampoco).

## Sintetizador (`WavSynth`)

Dart puro, sin plugins. Mezcla los tonos de un `Sfx` en un buffer mono
de 22050 Hz (configurable):

```
muestra(t) = onda(2π·f·t) × vol × (0.0001 / vol)^(t / d)   para 0 ≤ t < d
onda: square = signo(sin), sawtooth = 2·frac(f·t) − 1,
      triangle = 1 − 4·|frac(f·t) − 0.5|, sine = sin
```

Las muestras de tonos superpuestos se suman y se recortan a `[-1, 1]`;
se escriben como PCM con signo de 16 bits little-endian
(`round(x × 32767)`) detrás de una cabecera RIFF/WAVE de 44 bytes
(`fmt ` PCM = 1, 1 canal, `byteRate = rate × 2`, `blockAlign = 2`).
Largo = `max(retraso + duración)` del efecto. `SfxService` cachea los
bytes de cada `Sfx`.

## Reproducción

`SfxPlayer` es la interfaz (`play(Uint8List wav)`). El juego registra
`AudioplayersSfxPlayer` (`lib/core/audio/audioplayers_sfx_player.dart`,
paquete `audioplayers`):

- Cada WAV se escribe **una sola vez** a un archivo temporal y se
  reproduce con `DeviceFileSource`, que funciona igual en todas las
  plataformas de escritorio (no depende del soporte de `BytesSource`).
- Pool de 4 `AudioPlayer` en rotación: hasta 4 sonidos a la vez; el
  quinto corta al más viejo.
- `NoopSfxPlayer` queda para tests y plataformas sin audio.

`sfxInit` (crear el `AudioContext` con el primer clic) no hace falta en
escritorio.
