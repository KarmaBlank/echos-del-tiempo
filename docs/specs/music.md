# Spec: Música de fondo (chiptune con lead "ocarina")

Pedido del dueño: "música de fondo por zonas, combate, jefes, todo 8 bits
tipo ocarina". El prototipo HTML no tiene música: este spec es la fuente
de verdad. Todo es **original** (no reproduce ni imita de cerca temas de
otros juegos).

Implementación:

| Pieza | Archivo |
|---|---|
| Formato de partitura (`Song`, `Track`, `Instrument`, notación) | `lib/core/audio/music/music_score.dart` |
| Ayudas para componer (acordes, arpegios, bajos, compases) | `lib/core/audio/music/music_dsl.dart` |
| Instrumentos (ocarina, pulsos, triángulo, batería, charango, zampoña) | `lib/core/audio/music/instruments.dart` |
| Secuenciador / sintetizador a WAV | `lib/core/audio/music/music_renderer.dart` |
| Composiciones (una por archivo, con comentario de clima/tono/tempo) | `lib/core/audio/music/tracks/*.dart` |
| Ids y catálogo (`Music`, `kMusicCatalog`) | `lib/core/audio/music/music_catalog.dart` |
| Servicio (crossfade, jingles, duck) y reproductor abstracto | `lib/core/audio/music/music_service.dart` |
| Reproductor real (audioplayers, render en isolate, caché en disco) | `lib/core/audio/audioplayers_music_player.dart` |
| Ajustes de audio (volúmenes, silencio, persistencia) | `lib/core/audio/audio_settings.dart` |
| Panel de ajustes y providers | `lib/core/audio/presentation/audio_settings_panel.dart` |
| Estado de la sesión → pista | `lib/features/world/presentation/session_music.dart` |

Tests: `test/core/audio/music_score_test.dart`,
`test/core/audio/music_renderer_test.dart`,
`test/core/audio/music_catalog_test.dart`,
`test/core/audio/music_service_test.dart`,
`test/core/audio/audio_settings_test.dart`,
`test/core/audio/audio_settings_panel_test.dart`,
`test/features/world/session_music_test.dart` (reproductor falso:
`test/core/audio/fake_music_player.dart`).

## 1. Voces (estilo consola de 8 bits)

Cada pista (`Track`) es un canal monofónico (una nota corta a la
anterior, con un fundido de 4 ms para no hacer clic) con un
`Instrument`:

| Voz | Onda | Uso |
|---|---|---|
| `ocarina` | seno puro + 15 % de 2.º armónico, cuantizado a 5 bits (escalón "8 bits"), ataque suave (~30 ms), "scoop" de afinación (entra ¼ de tono abajo y sube en 50 ms), vibrato retrasado (empieza a los ~180 ms y entra en 200 ms, 5.3 Hz, ±0.6 %), soplo: ruido LFSR filtrado (pasabajos ~2.5 kHz) proporcional a la envolvente + un "chiff" corto al atacar | melodía principal de TODAS las piezas |
| `pulse25` / `pulse12` / `square` | pulso 25 %, 12.5 %, 50 % con pasabajos opcional | armonía, arpegios, contracantos |
| `triangle` | triángulo cuantizado a 16 niveles (como el canal triángulo del NES) | bajo |
| `sine` | seno | campanitas (con caída rápida) |
| `drums` | kit: ruido LFSR de 15 bits y barridos de triángulo | percusión |

Presets andinos (`Inst.charango`, `Inst.zampona`, `Inst.zamponaEcho`),
hechos con las mismas voces:

| Preset | Voz | Uso |
|---|---|---|
| `charango` | pulso 25 % corto y brillante (pasabajos 5.6 kHz), acordes de 4 notas **rasgueados** (`strum` 11 ms) | rasgueo del título y del mapa del mundo |
| `zampona` | ocarina sin vibrato, soplo ×3 (0.16), scoop corto | zampoña / sikus: dobla el tema 8va abajo, notas tenidas |
| `zamponaEcho` | igual, con eco de 6 pasos (g = 0.35) | llamadas y respuestas lejanas (hoquetus) |

Envolvente ADSR lineal (`attack`, `decay`, `sustain`, `release` en s);
`gate` (0..1) acorta la parte sostenida para articular notas repetidas.
`echoSteps` / `echoGain`: eco de 3 repeticiones (`g`, `g²`, `g³`) a
múltiplos del paso (bosque y cavernas). `strum` (s): las notas
simultáneas de un paso (`C5+E5+G5+A5`) entran escalonadas cada `strum`
s, un golpe hacia abajo (grave → agudo) y el siguiente hacia arriba,
como un charango; 0 (por defecto) = todas juntas. Solo entra en la
firma del instrumento si es > 0 (las firmas de las otras piezas no
cambian).

Kit de batería (token → golpe): `k` bombo (triángulo 120→40 Hz + clic),
`s` caja (ruido + cuerpo), `h` hi-hat cerrado, `o` abierto, `t`/`T` tom
grave/agudo, `c` platillo, `r` "tic" de reloj (pulso agudo corto), `q`
"tac" (triángulo grave corto), `b` **bombo legüero** (seno 92→50 Hz
con caída larga de ~0.4 s + golpe sordo de ruido filtrado a 700 Hz), `a`
**aro** del bombo (la baqueta sobre la madera: "tac" seco a ~760 Hz).
Varios a la vez con `+` (`k+h`, `b+c`).

## 2. Notación (tracker de texto)

Una pista es un texto de **pasos** separados por espacios; `|` se
ignora (marca compases):

| Token | Significado |
|---|---|
| `C5`, `F#4`, `Bb3` | nota (C4 = do central, MIDI 60) de 1 paso |
| `E5:4` | nota de 4 pasos |
| `.` / `.:8` | silencio (1 / 8 pasos) |
| `-` / `-:3` | liga: alarga la nota anterior |
| `C4+E4` | varias notas a la vez (díada en un canal de pulso) |
| `k`, `k+h`, `s:2` | golpes de batería (en una pista `drums`) |

Paso = `60 / bpm / stepsPerBeat` s (en 4/4 `stepsPerBeat = 4`:
semicorcheas; en 6/8 y 3/4 se usa 3 / 2). Para que los bucles sean
exactos, el paso se redondea a un número entero de muestras
(`samplesPerStep`); el desvío de tempo es < 0.05 %.

Todas las pistas de una `Song` deben medir lo mismo (lo verifica el
constructor y los tests). `music_dsl.dart` arma las pistas de
acompañamiento a partir de un cifrado (`'Dm:16 Bb:16 C:16 A:16'`):
`arp` (arpegio con forma y ritmo), `bassLine` (patrón `R 3 5 7 8 b w`
sobre la fundamental), `comp` (acordes/díadas con ritmo), `bar` (un
compás validado), `rep`, `shift` (transporta un texto de partitura
N semitonos: doblar el tema una 8va abajo en otra pista).

Los adornos de quena (apoyaturas, grupetos) se escriben como notas de
un paso en una grilla fina: el título y el mapa del mundo usan
`stepsPerBeat = 8` (fusas), así `G5:1 E5:11` es una apoyatura de ~1/32
y `A5:1 G5:1 A5:6` un grupeto.

## 3. Render

`MusicRenderer` (Dart puro, sin Flutter, **determinista**: ruido LFSR
de semilla fija, sin `Random`), mono, 22050 Hz, PCM 16 bits (el mismo
`WavSynth.encode` de los efectos).

1. Cada nota se sintetiza en el buffer de su pista (largo del bucle +
   cola: release, eco y golpes de batería).
2. Eco de la pista.
3. **Bucles: la cola se pliega al principio** (`buf[i mod L] += cola`):
   lo que suena después del final del bucle (releases, eco) se suma al
   comienzo, exactamente como sonaría al repetirse. La última nota de una
   pista se corta con la primera de la vuelta siguiente (monofonía
   cíclica). Así el bucle repetido es **idéntico, muestra a muestra,**
   a renderizar dos vueltas seguidas (test) y la costura no hace clic.
4. Mezcla de pistas × `gain`, normalización al pico de la pieza
   (`peak`, 0.5 = −6 dBFS: nunca recorta y deja lugar a los efectos).
5. Jingles (sin bucle): cola completa, se recorta el silencio final y
   se aplica un fundido de 20 ms.

Tiempos y tamaños (medidos, ver § 8): 1.4–2.5 MB por bucle de 33–59 s,
0.1–0.35 MB por jingle; render de 125–460 ms por bucle en el VM de debug
(JIT), siempre en un isolate.

## 4. Repertorio

| Id | Pieza | Clima | Tono | Tempo | Largo |
|---|---|---|---|---|---|
| `title` | Título · "Ecos del Tiempo" | épico-pastoral andino (yaraví → heroico) | Re dórico | 80, 3/4 (fusas) | 26 compases |
| `town` | Pueblo | cálido, vals | Sol mayor | 132, 3/4 | 24 compases |
| `overworld` | Mapa del mundo | salir de viaje, huayno a paso de caminata | Sol mixolidio / Mi menor pentatónica | 104, 2/4 (fusas) | 44 compases |
| `zone1` | Pradera Esmeralda | luminoso, pastoral | Fa mayor | 76 (negra con punto), 6/8 | 32 compases |
| `zone2` | Bosque Hondo | misterioso, neblina, eco | Mi menor (bII frigio) | 92, 4/4 | 16 compases |
| `zone3` | Ruinas Cronales | antiguo, de reloj (tic-tac) | La menor armónica | 104, 4/4 | 20 compases |
| `zone4` | Cavernas Heladas | frío, escaso, campanitas y eco | Si menor | 72, 4/4 | 12 compases |
| `zone5` | Fortaleza Caída | sombrío, marcial (redobles) | Do menor | 96, 4/4 | 16 compases |
| `battle` | Batalla | enérgico, ostinato | Mi menor | 152, 4/4 | 32 compases |
| `boss` | Jefe | intenso, frigio y cromático | Re menor | 168, 4/4 | 32 compases |
| `jingle.victory` | Victoria | fanfarria | Do mayor | 140 | 3 compases, sin bucle |
| `jingle.defeat` | Derrota | descendente, suspendido | La menor | 76 | 2 compases, sin bucle |
| `jingle.levelUp` | Subida de nivel | arpegio que sube | Re mayor | 160 | 24 pasos, sin bucle |
| `jingle.zoneUnlocked` | Zona desbloqueada | revelación, lidio | Mi♭ mayor | 96 | 2 compases, sin bucle |

### 4.1 Título y mapa del mundo: épico-folk con ocarina andina

Pedido del dueño: que el título y el mapa del mundo sean "tipo Señor de
los Anillos" y "algo andino con la ocarina". Se toma como **estilo**:
música de cine de fantasía épica/pastoral (modos dórico y mixolidio,
frases largas en arco, un tema dicho simple y después repetido más
grande, acordes abiertos —quintas, sus2, sus4—, armonía lenta) mezclada
con música andina (giros pentatónicos, ritmo de huayno corta–larga,
adornos de quena, charango rasgueado, bombo legüero, zampoñas en
hoquetus). La ocarina lleva siempre la melodía.

**Melodías originales — sin citas.** No reproducen ni imitan de cerca
ningún tema existente: ni los de Howard Shore para El Señor de los
Anillos (la Comarca, la Comunidad, Gondor…) ni canciones andinas
conocidas ("El Cóndor Pasa" y similares). Los rasgos de estilo
(modos, ritmos, instrumentación) no son citas.

**`title` · "Ecos del Tiempo"** — Re dórico (Re menor con Si natural;
el Sol mayor del IV es el color "de leyenda"), 80 bpm, 3/4, grilla de
fusas, 26 compases = 58.5 s.

| Parte | Compases | Cifrado | Qué pasa |
|---|---|---|---|
| A | 1–8 | Dm Csus2 F G Dm Am G Dm | tema tierno tipo yaraví: la ocarina sola sobre un arpa (arpegio de pulso en corcheas), colchón y un golpe de bombo por compás; apoyatura y grupeto de quena, Si dórico en corta–larga; cadencia plagal Sol → Re m |
| A' | 9–16 | Dm Csus2 F G Dm Am G Asus4 | el mismo tema más grande: zampoña (sikus) que lo dobla 8va abajo, charango rasgueado, arpa en semicorcheas, bombo + aro; queda abierto en La sus4 |
| B | 17–24 | F C Dm G F C G Asus4 | heroica: saltos por los arpegios de Fa y Sol mayor hasta el Re agudo, rasgueo lleno, "metal" de pulso en quintas, zampoña tenida, chajchas, platillo al entrar; semicadencia en La sus4 |
| coda | 25–26 | Dsus2 Dm | la ocarina baja por la pentatónica y la zampoña contesta (hoquetus) dejando La para volver a empezar |

Pistas: ocarina, zampoña, arpa (`Inst.arp`), charango, metal
(`Inst.brass`), colchón, bajo (triángulo), bombo (`b`/`a`/`c`),
chajchas (`h`).

**`overworld` · Mapa del mundo** — Sol mixolidio (Fa mayor = VII: la
cadencia Fa → Sol le da el aire épico) que pasa a su relativa Mi menor
pentatónica en la B, a la manera andina; 104 bpm, 2/4, grilla de fusas,
44 compases = 50.8 s. Paso de caminata con balanceo de huayno
(semicorchea + corchea con punto en la melodía; rasgueo "ta-taka"
`x:4 x:2 x:2` del charango; bombo `b a a b a`), esperanzado y con
sensación de distancia (zampoña lejana con eco).

| Parte | Compases | Cifrado | Qué pasa |
|---|---|---|---|
| intro | 1–4 | G F G G | charango, bombo y la llamada de una zampoña lejana con eco; el bajo entra en el 3 |
| A | 5–20 | G G C G F F G D · G G C Em C F G G | tema de viaje en dos frases de 8 (semicadencia en Re; cierre Fa → Sol), adornos de quena |
| B | 21–28 | Em D Em D C G D Em | Mi menor pentatónica: la ocarina canta un compás y la zampoña le contesta el siguiente (hoquetus de sikus); entran arpa y chajchas; patrón de bombo más cortado |
| A' | 29–44 | como A | el tema otra vez, más grande: sikus doblándolo 8va abajo, arpa, rasgueo lleno, platillo al entrar |

Pistas: ocarina, zampoña (con eco), sikus, charango, arpa, colchón,
bajo, bombo, chajchas.

Las zonas 6–10 (todavía "Próximamente") no tienen pieza propia: usan la
de su tema más cercano (§ 5). Una variante del jefe final queda para
cuando exista la zona 10.

## 5. Qué suena (`SessionMusic` + título)

Pista según el estado (función pura `MusicSelector.trackFor`):

| Estado | Pista |
|---|---|
| Pantalla de título | `title` |
| `lobby` dentro del pueblo (tiles `0..25 × 0..13`, `inTown`) | `town` |
| `lobby` en el mapa del mundo | `overworld` |
| `prep` | `town` |
| `field` / `levelUp` en una misión de zona `z` (1–5) | `zone<z>` |
| `field` / `levelUp` en una misión sin zona: por tema del mapa | `pradera`→1, `bosque`→2, `ruinas`→3, `cavernas`→4, `fortaleza`→5, otro → 3 |
| `battle` | `boss` si `SessionBattle.boss`, si no `battle` |
| `result` | `town` (después del jingle) |

Histéresis del pueblo: se entra al pueblo con `tx < 26 && ty < 14` y se
sale recién con `tx ≥ 28 || ty ≥ 16` (no alterna en el borde).

Jingles (todo derivado de las vistas, así funciona igual en host y
cliente):

- La batalla termina (`battle.state.outcome` aparece, una vez por
  batalla): `jingle.victory` o `jingle.defeat`.
- Aparece un resultado nuevo (`session.result.id`): si el último jingle
  de batalla no era el mismo desenlace (p. ej. misión ganada sin batalla
  final), `jingle.victory` / `jingle.defeat`; si el jugador local
  desbloqueó una zona (`result.unlocked[localId]`), después
  `jingle.zoneUnlocked`.
- El nivel del jugador local sube: `jingle.levelUp`.

Los jingles van en cola (uno detrás del otro); mientras suenan, la
música de bucle baja a 0 en 0.25 s y vuelve en 1 s al terminar (la pista
nueva ya se fundió debajo).

ULT (propia o enemiga): al llegar un paso de batalla nuevo
(`battleEventSeq`) con una acción `ultimate` o un `EnemyUltEvent`, la
música baja a 0.3 durante `UltScript.totalMs` de esa ULT y vuelve en
0.6 s.

## 6. `MusicService`

- `MusicPlayer` (interfaz): `play(deck, source, loop, volume)`,
  `setVolume(deck, v)`, `stop(deck)`, `preload(source)`. Decks 0 y 1 =
  bucles (crossfade), deck 2 = jingles. `NoopMusicPlayer` para tests y
  plataformas sin audio (nunca pide el WAV, así que nada se renderiza).
- `playTrack(id)`: si ya suena, nada. Si el otro deck tiene esa pista y
  todavía se oye (se estaba yendo), se da vuelta el fundido sin
  reiniciar. Si no, la pista empieza en el deck libre a volumen 0 y se
  funden: entrada y salida en 1.2 s (0.4 s al entrar a una batalla).
  `null` = fundido a silencio. Un deck que llega a 0 se detiene.
- Volumen efectivo de un deck = `fundido × duck(ULT) × duck(jingle) ×
  volumenMúsica` (0 si silenciado). Se manda al reproductor solo si
  cambió (> 0.004).
- Reloj: `tick(dt)` (Dart puro, testeable). En el juego un
  `Timer.periodic` de 40 ms corre solo mientras hay algo animándose; con
  el reproductor no-op no se crea ningún timer (los tests de widgets no
  quedan con timers pendientes).
- Duración de un jingle para saber cuándo devolver la música: largo de
  la partitura + 0.3 s.

Reproductor real (`AudioplayersMusicPlayer`): 3 `AudioPlayer`
(`ReleaseMode.loop` en los decks de bucle). Cada pieza se renderiza **una
sola vez, en un isolate** (`Isolate.run`, fuera del hilo de UI) y se
guarda en `%TEMP%/ecos_music/<id>_<firma>.wav`; la firma es un hash de
la partitura, así que en la siguiente ejecución se reutiliza el archivo
sin volver a renderizar (y un cambio en la partitura genera otro
archivo). Un número de generación por deck descarta un `play` cuyo
render terminó tarde (la pista ya cambió). Al arrancar se precargan en
segundo plano pueblo, mapa del mundo, batalla, victoria, subida de
nivel, jefe y zona 1 (en la build de debug quedan todas en disco ~1 s
después de abrir el título).

## 7. Ajustes de audio

`AudioSettings`: `musicVolume` (0..1, por defecto 0.6), `sfxVolume`
(0..1, por defecto 0.8), `muted` (silencia todo). `SfxService.volume`
escala cada efecto (`SfxPlayer.play(wav, volume:)`).

Persistencia: `audio.json` en la misma carpeta de datos que el perfil
(`JsonFileProfileStore.dataDirectory()`, escritura atómica); en memoria
donde no hay carpeta conocida. `AudioSettingsController` carga al
arrancar, aplica a `MusicService` y `SfxService` en cada cambio y guarda
al soltar un slider o al tocar el silencio.

UI: desde v0.2.1 es la pestaña SONIDO del menú de pausa /
configuración (docs/specs/settings.md § 2): volumen general (`master`,
multiplica a los otros dos), MÚSICA, EFECTOS (con muestra en vivo) y
SILENCIAR TODO. El panel suelto `SONIDO` de v0.2.0 ya no existe.

## 8. Muestras y mediciones

`MUSIC_SAMPLES_DIR=<carpeta> flutter test test/core/audio/music_catalog_test.dart`
escribe `<id>.wav` por pieza (los jingles como `jingle_<nombre>.wav`) e
imprime tiempo de render, tamaño, pico y RMS por pieza. Sin la variable
no escribe nada.

Medición (VM de debug, Windows):

| Pieza | Largo | Render | Tamaño | Pico | RMS |
|---|---|---|---|---|---|
| title | 58.5 s | 456 ms | 2519 KB | −6.0 dBFS | −18.8 dBFS |
| town | 32.7 s | 126 ms | 1409 KB | −6.0 | −15.9 |
| overworld | 50.8 s | 387 ms | 2186 KB | −6.0 | −18.3 |
| zone1 | 50.5 s | 211 ms | 2176 KB | −6.0 | −17.2 |
| zone2 | 41.7 s | 188 ms | 1798 KB | −6.0 | −17.2 |
| zone3 | 46.1 s | 164 ms | 1988 KB | −6.0 | −16.7 |
| zone4 | 40.0 s | 197 ms | 1723 KB | −6.0 | −17.6 |
| zone5 | 40.0 s | 165 ms | 1723 KB | −6.0 | −19.0 |
| battle | 50.5 s | 226 ms | 2176 KB | −6.0 | −18.5 |
| boss | 45.7 s | 225 ms | 1969 KB | −6.0 | −17.6 |
| jingle.victory | 5.1 s | 31 ms | 221 KB | −6.0 | −17.5 |
| jingle.defeat | 8.1 s (con la cola del eco) | 33 ms | 350 KB | −6.0 | −17.3 |
| jingle.levelUp | 2.3 s | 8 ms | 97 KB | −6.0 | −15.7 |
| jingle.zoneUnlocked | 6.7 s (con la cola del eco) | 31 ms | 291 KB | −6.0 | −17.9 |

Tests de la costura: el bucle plegado es idéntico (diferencia < 1e-9) a
la segunda vuelta de un render de dos vueltas seguidas, y el salto
`|s[fin] − s[0]|` nunca supera el mayor salto entre muestras del bucle.
