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

Tiempos y tamaños (medidos, ver § 8): 1.4–2.7 MB por bucle de 33–63 s,
0.1–0.35 MB por jingle; render de 125–460 ms por bucle en el VM de debug
(JIT), siempre en un isolate.

## 4. Repertorio

| Id | Pieza | Clima | Tono | Tempo | Largo |
|---|---|---|---|---|---|
| `title` | Título · "Ecos del Tiempo" | épico-pastoral andino (yaraví → heroico) | Re dórico | 80, 3/4 (fusas) | 26 compases |
| `town` | Pueblo | cálido, vals | Sol mayor | 132, 3/4 | 24 compases |
| `overworld` | Mapa del mundo | campo tranquilo, cálido, sin apuro | Sol mayor (jónico) | 72 (negra con punto), 6/8 (semicorcheas) | 34 compases |
| `zone1` | Pradera Esmeralda | luminoso, pastoral | Fa mayor | 76 (negra con punto), 6/8 | 32 compases |
| `zone2` | Bosque Hondo | misterioso, neblina, eco | Mi menor (bII frigio) | 92, 4/4 | 16 compases |
| `zone3` | Ruinas Cronales | antiguo, de reloj (tic-tac) | La menor armónica | 104, 4/4 | 20 compases |
| `zone4` | Cavernas Heladas | frío, escaso, campanitas y eco | Si menor | 72, 4/4 | 12 compases |
| `zone5` | Fortaleza Caída | sombrío, marcial (redobles) | Do menor | 96, 4/4 | 16 compases |
| `zone6` | Laberinto Temporal | desorientador, de reloj, canon con eco | Sol menor + tonos enteros | 116, 4/4 | 20 compases |
| `zone7` | Grieta Ígnea | caliente, pesado, bordón y ostinato, bombo | Mi frigio (dominante) | 88, 4/4 | 16 compases |
| `zone8` | Cementerio de Eras | melancólico, escaso, campanas | Fa menor (eólico) | 66, 3/4 | 20 compases |
| `zone9` | Abismo del Tiempo | inmenso, flotando, ecos largos, suspendido | La lidio | 76, 4/4 | 16 compases |
| `zone10` | Corazón del Tiempo | solemne, ominoso, crece; cita el título | Re menor (Mi♭ napolitano) | 76, 4/4 | 20 compases |
| `battle` | Batalla | enérgico, ostinato | Mi menor | 152, 4/4 | 32 compases |
| `boss` | Jefe | intenso, frigio y cromático | Re menor | 168, 4/4 | 32 compases |
| `bossFinal` | Jefe final · Devorador de Eras | épico → desatado (2 fases); el título transformado | Re menor → frigio | 160, 4/4 | 32 compases |
| `jingle.victory` | Victoria | fanfarria | Do mayor | 140 | 3 compases, sin bucle |
| `jingle.defeat` | Derrota | descendente, suspendido | La menor | 76 | 2 compases, sin bucle |
| `jingle.levelUp` | Subida de nivel | arpegio que sube | Re mayor | 160 | 24 pasos, sin bucle |
| `jingle.zoneUnlocked` | Zona desbloqueada | revelación, lidio | Mi♭ mayor | 96 | 2 compases, sin bucle |

### 4.1 Título y mapa del mundo: épico-folk con ocarina andina

Pedido del dueño: que el título y el mapa del mundo suenen a fantasía
épica clásica y "algo andino con la ocarina". Se toma como **estilo**:
música de cine de fantasía épica/pastoral (modos dórico y mixolidio,
frases largas en arco, un tema dicho simple y después repetido más
grande, acordes abiertos —quintas, sus2, sus4—, armonía lenta) mezclada
con música andina (giros pentatónicos, ritmo de huayno corta–larga,
adornos de quena, charango rasgueado, bombo legüero, zampoñas en
hoquetus). La ocarina lleva siempre la melodía.

**Melodías originales — sin citas.** No reproducen ni imitan de cerca
ningún tema existente: ni bandas sonoras de películas o juegos de
fantasía ni canciones andinas conocidas. Los rasgos de estilo
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

**`overworld` · Mapa del mundo** — pedido del dueño (segunda vuelta):
la versión huayno de 104 bpm era "muy animada"; tiene que tener el
**clima** de la música pastoral de las películas de fantasía: campo tranquilo,
cálido, pastoral, la alegría sin apuro de estar en casa. Solo se toma
el clima: **la melodía, el ritmo y la armonía son originales y no citan
ni parafrasean ningún tema existente** (esta pieza está en Sol, abre
bajando por grados desde el Re, y su cifrado y forma son propios).

Sol mayor (jónico), 72 bpm (negra con punto), 6/8 con balanceo suave
(negra–corchea), grilla de semicorcheas (`stepsPerBeat = 6`) para
adornos leves de una semicorchea, 34 compases = 56.7 s. La ocarina
canta como un silbato de lata: por grados conjuntos, cantable, sin
corridas. Armonía simple I–IV–V–vi con cadencias suaves. Lo andino
queda en toques: charango **punteado** (arpegio de una cuerda por vez,
sin rasgueo) y una zampoña que contesta al final de A y de B. Sin bombo
ni platillos: a lo sumo un pandero (tambor de marco, tom grave `t`)
liviano.

| Parte | Compases | Cifrado | Qué pasa |
|---|---|---|---|
| intro | 1–2 | G G | arpa y colchón |
| A | 3–10 | G C G D G C D G | el tema baja por grados desde el Re y vuelve al Sol (semicadencia en Re en el 6); ocarina, arpa en corcheas, colchón, bajo en negras con punto; la zampoña contesta en el último compás y lleva al Re |
| A' | 11–18 | G C G D Em C D G | empieza igual, después sube y cierra en el Sol agudo; entran cuerdas tibias (nota de arriba del acorde, tenida) y el pandero |
| B | 19–26 | Em C G D C G Am D | casera y suave, más grave, por Mi menor y La menor; charango punteado; pandero solo en el 1; semicadencia en Re con la respuesta de la zampoña |
| A'' | 27–34 | como A' | el tema de A' con todo: cuerdas, charango punteado, pandero |

Pistas: ocarina, zampoña, arpa (`Inst.arp`), colchón, cuerdas (pulso
25 % con ataque lento, propio de la pieza), charango (`Inst.charango`
con `strum: 0`), bajo, pandero (`t`).

`tool/print_scores.dart` escribe 6/8 para cualquier pulso divisible por
3 (`stepsPerBeat` 3, 6, …).

### 4.2 Zonas 6–10 y jefe final (v0.3.0)

Las cinco zonas nuevas (worldgen.md § 8) y el Devorador de Eras tienen
pieza propia. Mismas reglas: la ocarina lleva siempre la melodía,
melodías **originales** (la zona 10 y el jefe final solo citan el tema
del propio juego, `title`), bucles de 30–75 s con costura exacta, pico
−6 dBFS. Lo andino queda donde va (zampoña, bombo legüero, charango);
las zonas del abismo son más "de cine" que folclóricas.

**`zone6` · Laberinto Temporal** — desorientador y mecánico. Sol menor
con toques de tonos enteros, 116 bpm, 4/4, 20 compases = 41.4 s.

| Parte | Compases | Cifrado | Qué pasa |
|---|---|---|---|
| A | 1–8 | (Sol m · Mi♭ aum Re7) × 4 | la ocarina en Sol menor; el Si natural del Mi♭ aumentado contra el Si♭; una zampoña con eco la imita **en canon** 2 compases después y una 8va abajo (canon circular: como la armonía se repite cada 2 compases, la imitación cae siempre sobre el mismo acorde) |
| B | 9–16 | (Do aum · Re aum) × 4 | **escala de tonos enteros** (Do Re Mi Fa# Sol# La#): sin tónica, el laberinto; mismo canon circular |
| C | 17–20 | Do m Re7 Mi♭ aum Re7 | vuelve el Si♭; la zampoña solo contesta; Re7 → Sol m |

Reloj en 3+3+2 (`r`/`q` con bombo) contra el 4/4, engranajes de pulso
12.5 % de a 3 notas sobre semicorcheas (nunca coinciden con el compás),
bajo staccato en 3+3+2 con semitono de aproximación. Pistas: ocarina,
eco (`Inst.zamponaEcho`), engranajes, colchón, bajo, reloj.

**`zone7` · Grieta Ígnea** — caliente y pesado. Mi frigio con la
tercera mayor en la tónica (frigio dominante), 88 bpm, 4/4, 16
compases = 43.6 s.

| Parte | Compases | Cifrado | Qué pasa |
|---|---|---|---|
| A | 1–8 | Mi Mi Fa Mi Re m Fa Mi Mi | bordón Mi + Si (cuadrada filtrada a 900 Hz) que no se mueve nunca; ostinato de bajo que machaca Mi con el Fa frigio; bombo legüero + bombo + aro; golpes secos de "metal" |
| B | 9–16 | La m Fa Sol Fa Re m Fa Mi Mi | la ocarina sube (hasta Mi6); zampoña en octavas abajo; toms; redoble y platillo para volver |

Pistas: ocarina, zampoña, bordón, metales, bajo, bombo.

**`zone8` · Cementerio de Eras** — melancólico y escaso. Fa menor
natural (eólico; la dominante es Do m, salvo el Do mayor de la cadencia
de B), 66 bpm, 3/4, 20 compases = 54.5 s.

| Parte | Compases | Cifrado | Qué pasa |
|---|---|---|---|
| A | 1–8 | Fa m Re♭ Si♭m Do m Fa m La♭ Mi♭ Fa m | vals lento: frases cortas de la ocarina que se apagan; campanitas sueltas (2 por compás, con eco) |
| B | 9–16 | Re♭ La♭ Si♭m Fa m Re♭ Mi♭ Do sus4 Do | sube al La♭ agudo; cadencia con el Mi natural |
| coda | 17–20 | Fa m Re♭ Si♭m Do m | baja y queda en Do |

Una zampoña con eco contesta en los silencios de los compases 8, 16 y
20; bombo legüero lejano cada 2 compases (campana de duelo). Pistas:
ocarina, zampoña (`Inst.zamponaEcho`), campanas (`Inst.chime`),
colchón, bajo, campana de duelo.

**`zone9` · Abismo del Tiempo** — inmenso y flotando. La lidio (el Si
mayor sobre el pedal de La, II/I), 76 bpm, 4/4, 16 compases = 50.5 s.

| Parte | Compases | Cifrado | Qué pasa |
|---|---|---|---|
| A | 1–8 | La sus2 Si/La La maj7 Si/La Do#m7 Si Mi sus4 Mi | ocarina en notas largas con eco largo (6 pasos, g = 0.45: casi una reverberación), colchón de ataque 0.9 s y release 1.2 s |
| B | 9–16 | Fa#m7 Mi sus2 La maj7 Si/La Fa#m7 Do#m7 Si sus4 Si | sube al Mi6; el II mayor del final vuelve al La sus2 sin cadencia (nunca "aterriza") |

Sin batería: un platillo suave cada 4 compases (respira). Pistas:
ocarina (`Inst.ocarinaEcho` con eco largo), colchón, cuerdas (pulso
25 % de ataque lento, nota de arriba), estrellas (campanitas con eco),
bajo (redondas; pedal de La en Si/La), aire.

**`zone10` · Corazón del Tiempo** — solemne y ominoso, la tensión crece
en tres capas. Re menor (con Mi♭ napolitano y La mayor de dominante),
76 bpm, 4/4, 20 compases = 63.2 s. **Autocita del título**: la cabeza
Re–Mi–Fa en corta–larga, el giro Mi–Do–Re, el grupeto de quena y la
corta–larga hacia la sensible, ahora con Si♭ y Mi♭: el tema de la
leyenda, amenazado.

| Parte | Compases | Cifrado | Qué pasa |
|---|---|---|---|
| A | 1–8 | Re m Si♭ Sol m La Re m Mi♭ Sol m La | el tema del título, solemne; latido (lub-dub de bombo legüero) por compás, bajo en redondas, órgano |
| B | 9–16 | Re m Si♭ Sol m Mi♭ Re m Si♭ Mi♭ La | sube; zampoña una 8va abajo; el latido se duplica, entra el reloj en negras, bajo en negras |
| C | 17–20 | Sol m Mi♭ La7(♭9) La | clímax: la cabeza una 8va arriba y transformada (Mi♭–Do–Re en lugar de Mi–Do–Re), arpegio en semicorcheas, quintas de metal, bajo y reloj en corcheas, redoble; queda en La |

Pistas: ocarina, zampoña, órgano, arpa, metal, bajo, latido, reloj.

**`bossFinal` · Devorador de Eras** — variante del tema de jefe (misma
plantilla: ocarina + doble 8va abajo + riff de pulso + bajo staccato +
batería) con el **tema del título transformado** encima. Re menor
(eólico → frigio), 160 bpm, 4/4, 32 compases = 48 s. Dos secciones con
sensación de fase:

| Parte | Compases | Cifrado | Qué pasa |
|---|---|---|---|
| Fase 1 | 1–16 | Re m Si♭ Do Re m · Re m Si♭ Sol m La · Re m Fa Do Sol m · Si♭ Do La La | épica: la cabeza del título como himno de batalla (después una 8va arriba), charango rasgueado en corcheas, bombo legüero + kit a medio tiempo, quintas de metal, bajo galopando; semicadencia en La |
| Fase 2 | 17–32 | Re m Mi♭ Re m Mi♭ Si♭ La Si♭ La · Sol m Mi♭ La7(♭9) Re m Sol m Mi♭ La La | desatada: el tema en **disminución** (mitad de largo) que **muta** (Re–Mi–Fa → Re–Mi♭–Fa, frigio); riff martillado en semicorcheas, doble bombo, el charango calla; termina en La para volver a la fase 1 |

Es un solo bucle (fase 1 → fase 2 → fase 1…). La fase 2 del Devorador
**no** salta a la sección B: el reproductor no busca posiciones y el
motor todavía no expone la fase (opcional, para más adelante).

## 5. Qué suena (`SessionMusic` + título)

Pista según el estado (función pura `MusicSelector.trackFor`):

| Estado | Pista |
|---|---|
| Pantalla de título | `title` |
| `lobby` dentro del pueblo (tiles `0..25 × 0..13`, `inTown`) | `town` |
| `lobby` en el mapa del mundo | `overworld` |
| `prep` | `town` |
| `field` / `levelUp` en una misión de zona `z` (1–10) | `zone<z>` |
| `field` / `levelUp` en una misión sin zona: por tema del mapa | `pradera`→1, `bosque`→2, `ruinas`→3, `cavernas`→4, `fortaleza`→5, `laberinto`→6, `grieta`→7, `cementerio`→8, `abismo`→9, `corazon`→10, otro → 3 |
| `battle` de jefe contra el Devorador (el enemigo jefe tiene `enemyType == 'devorador'`, `MusicSelector.finalBossId`; `MusicSelector.bossIdOf`) | `bossFinal` |
| `battle` | `boss` si `SessionBattle.boss`, si no `battle` |
| `battle` con desenlace (`battle.state.outcome`, la pausa final de ~2 s) | la pieza de la zona, como en `field` (§ 5.1) |
| `result` | `town` (de fondo bajo el jingle, § 5.1) |

Histéresis del pueblo: se entra al pueblo con `tx < 26 && ty < 14` y se
sale recién con `tx ≥ 28 || ty ≥ 16` (no alterna en el borde).

Jingles (todo derivado de las vistas, así funciona igual en host y
cliente):

- La batalla termina (`battle.state.outcome` aparece, una vez por
  batalla): `jingle.victory` o `jingle.defeat` (§ 5.1).
- Aparece un resultado nuevo (`session.result.id`): si el último jingle
  de batalla no era el mismo desenlace (p. ej. misión ganada sin batalla
  final), `jingle.victory` / `jingle.defeat`; si el jugador local
  desbloqueó una zona (`result.unlocked[localId]`), después
  `jingle.zoneUnlocked`.
- El nivel (o la maestría) del jugador local sube: `jingle.levelUp`.
  Si sube en una batalla (el XP se reparte con el desenlace), el jingle
  **espera** a que se cierre la batalla: si aparece la pantalla de
  subida de nivel (`SessionMode.levelUp`) **corta** el jingle de
  victoria y suena enseguida; si se vuelve al campo / resultado sin
  pantalla (maestría, nivel sin puntos que repartir) va en cola detrás.
- Alguien de la sala asciende: `jingle.ascension` (en cola).

Los jingles van en cola (uno detrás del otro) y siempre suenan enteros:
cambiar de bucle o de modo (resultado → campo, campo → lobby…) nunca
los corta. Solo los corta otro jingle pedido con `interrupt` (hoy, solo
el de subida de nivel al abrirse su pantalla), silenciar la música o
cerrar la sesión. Mientras suena un jingle el bucle queda **de fondo**
a `jingleBedLevel` = 0.3 (baja en 0.25 s) y vuelve a 1 en 1 s cuando no
queda jingle ni retención.

### 5.1 Fin de batalla, subida de nivel y resultados

Pedido del dueño (v0.5.1): "la música a veces no da chance a que suene
la música de victoria ni la de subida de nivel". Antes el bucle bajaba a
0 bajo el jingle, la pieza de batalla seguía (tapada) hasta el cambio de
modo y el jingle de nivel quedaba en cola detrás de la victoria
(arrancaba ~5 s después, con la pantalla de nivel ya abierta o cerrada).
Ahora:

1. **Desenlace** (aparece `battle.state.outcome`, todavía en `battle`):
   la pieza de batalla / jefe / jefe final se **corta** en
   `battleCutSeconds` = 0.15 s; suena `jingle.victory` o
   `jingle.defeat` **entero**; la pieza de la zona actual entra ya
   (fundido de 1.2 s) **de fondo** a 0.3.
2. **Pantalla de subida de nivel** (`levelUp`): si el jugador local
   subió, `jingle.levelUp` corta la victoria y suena entero. La zona
   sigue de fondo.
3. **Resultados** (`result`): la pieza pasa a `town` (crossfade normal),
   también de fondo. `jingle.zoneUnlocked` (y el de Atlas del Eco) van en
   cola detrás de lo que suene.
4. La música vuelve a 1 (en 1 s) recién cuando **no suena ningún jingle
   y no hay pantalla** de fin de batalla, subida de nivel ni resultados:
   `MusicService.bedHeld` = `battle con desenlace || levelUp || result`.

Derrota: igual que la victoria (corte, jingle entero, zona de fondo,
después `town` de fondo en el resultado hasta volver al lobby).
Ascensión y zona desbloqueada: nunca cortan ni se cortan por el estado,
van en cola; la música de fondo queda a 0.3 mientras suenan.

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
- `playTrack(id, fade:, fadeOut:)`: `fadeOut` es el fundido de la
  pieza que sale (por defecto igual a `fade`); `SessionMusic` usa
  `battleCutSeconds` = 0.15 s al salir de una pieza de batalla.
- `playJingle(id, interrupt:)`: en cola, o cortando el que suena con
  `interrupt` (la cola sigue después). `bedHeld` retiene el bucle a
  `jingleBedLevel` (0.3) sin jingle; al soltarlo (y sin jingle) vuelve a
  1 en `jingleReturnSeconds` = 1 s.
- Volumen efectivo de un deck = `fundido × duck(ULT) × duck(jingle /
  retención) × volumenMúsica` (0 si silenciado). Se manda al reproductor
  solo si cambió (> 0.004).
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
| overworld | 56.7 s | 302 ms | 2441 KB | −6.0 | −17.3 |
| zone1 | 50.5 s | 211 ms | 2176 KB | −6.0 | −17.2 |
| zone2 | 41.7 s | 188 ms | 1798 KB | −6.0 | −17.2 |
| zone3 | 46.1 s | 164 ms | 1988 KB | −6.0 | −16.7 |
| zone4 | 40.0 s | 197 ms | 1723 KB | −6.0 | −17.6 |
| zone5 | 40.0 s | 165 ms | 1723 KB | −6.0 | −19.0 |
| battle | 50.5 s | 226 ms | 2176 KB | −6.0 | −18.5 |
| boss | 45.7 s | 225 ms | 1969 KB | −6.0 | −17.6 |
| zone6 | 41.4 s | 270 ms | 1782 KB | −6.0 | −17.7 |
| zone7 | 43.6 s | 292 ms | 1880 KB | −6.0 | −18.9 |
| zone8 | 54.5 s | 302 ms | 2349 KB | −6.0 | −16.0 |
| zone9 | 50.5 s | 271 ms | 2176 KB | −6.0 | −17.1 |
| zone10 | 63.2 s | 381 ms | 2720 KB | −6.0 | −18.7 |
| bossFinal | 48.0 s | 330 ms | 2067 KB | −6.0 | −19.1 |
| jingle.victory | 5.1 s | 31 ms | 221 KB | −6.0 | −17.5 |
| jingle.defeat | 8.1 s (con la cola del eco) | 33 ms | 350 KB | −6.0 | −17.3 |
| jingle.levelUp | 2.3 s | 8 ms | 97 KB | −6.0 | −15.7 |
| jingle.zoneUnlocked | 6.7 s (con la cola del eco) | 31 ms | 291 KB | −6.0 | −17.9 |

Los tests piden RMS entre −22 y −14 dBFS en todas las piezas.

Tests de la costura: el bucle plegado es idéntico (diferencia < 1e-9) a
la segunda vuelta de un render de dos vueltas seguidas, y el salto
`|s[fin] − s[0]|` nunca supera el mayor salto entre muestras del bucle.

## Jefes del Abismo (v0.8.0)

Dos piezas nuevas (docs/specs/abyss_bosses.md § 4), mismas reglas del
repertorio (bucle 30–75 s, ocarina al frente, RMS −22…−14 dBFS):
- `bossAbyss` · **Jefe del Abismo** (Gólem, Hechicera, Espectro y
  Devorador del Abismo): Mi menor frigio con el tritono como color, 172
  bpm, 32 compases; riff en 3+3+2.
- `bossSecret` · **Eco Primordial**: Do menor con acordes aumentados, 156
  bpm, 32 compases en tres texturas (Origen, Reflejo, Primordial).
`MusicSelector.trackFor` elige por el jefe de la batalla
(`MusicSelector.abyssTrack`); las dos cuentan como pieza de batalla.