# Spec (APROBADO por el dueño): Editor del juego

Estado: **pasos 1 y 2 implementados** (§ 7.1 y § 7.2). Respuestas del
dueño a las preguntas abiertas en § 8.

Pedido del dueño: convertir la herramienta de admin/monitoreo
(docs/specs/balance_admin.md, flavor `lib/app/flavors/main_admin.dart`,
`lib/features/admin/`) en un **editor completo del juego**, con tres
áreas:

1. **Monitorización**: lo que ya existe (`monitoring_page.dart`).
2. **Balance**: lo que ya existe (`balance_page.dart`, `changes_page.dart`,
   `patch_page.dart`, `impact_panel.dart`), ordenado por categoría y con
   buscador.
3. **Visual**: cambiar **sprites** de todo y **animaciones** de todo,
   categorizado, con buscador, con vista previa ahí mismo. Además: que
   **las ULT se vean muchísimo mejor** y se puedan iterar desde el editor.

Nada de esto cambia reglas del juego (el motor en `game_engine/` no se
toca); es datos + presentación + herramienta.

## 1. Estado actual (punto de partida)

- **Sprites**: ya son datos. `assets/sprites/sprite_manifest.yaml`
  (`characters:`, `enemies:`, …, un frame `idle` por sprite) y
  `SpriteCatalog` es la única clase que lo lee. Lo que falta es UI para
  verlos/reemplazarlos y categorías para lo que todavía se dibuja en
  código (íconos de armas/ítems, tiles, partes de UI, efectos).
- **Animaciones**: son **código Dart**. Las ULT son guiones
  semi-declarativos (`UltScript`, `kUltScripts` en
  `scene/ult_cinematic.dart`) pero los efectos se dibujan a mano por
  `UltStyle` en `scene/ult_fx.dart` (`UltDirector`) y en
  `battle_painter.dart`; los efectos comunes en `scene/battle_fx.dart`
  (`BattleFx`, `FxKind`); caminar/estocada/flotación son procedurales
  (docs/specs/sprites.md). Tiempos repartidos en tablas del spec
  (battle_presentation.md § "Guiones").
- **Fin de batalla**: `battleCinematicHold` usa valores fijos (ULT 2.3 s,
  dúo 1.5 s; battle_presentation.md § "Fin de batalla (v0.13.4)"). Si una
  cinemática se alarga, la espera queda corta.

## 2. Arquitectura

### 2.1 Animaciones como datos: formato FXA ("efecto animado")

Archivos **YAML** (mismo lector `yaml` que el manifest; legible y
comentable a mano; el editor lo escribe ordenado y estable para que los
diffs de git sean chicos). Un archivo por animación en
`assets/fx/<categoría>/<id>.fx.yaml` y un índice
`assets/fx/fx_manifest.yaml` (id lógico → archivo, como el de sprites).

Una animación es una **línea de tiempo** con duración y **pistas**; cada
pista tiene **keyframes** `(t en ms, valor, curva)` o **disparos**
(eventos puntuales en `t`).

```yaml
schema: 1
id: ult_tajo_final
category: ult            # ult | duo | skill | attack | enemy_ult | status | death | map_move | ui
name: Tajo Final
tags: [espada, un_objetivo, físico]
duration: 2200           # ms; la fuente de verdad para esperas (§ 4.3)
phases: { build: 800, release: 1000, recover: 400 }   # opcional, para la cámara/tarjeta
targets: single          # single | all | self | allies | line
anchors: [caster, target, targets_center, screen]
tracks:
  - type: camera
    keys:
      - { t: 0,    focus: caster, zoom: +1, ease: smooth }
      - { t: 800,  focus: target, zoom: +1, ease: snap }
      - { t: 1800, focus: base,   zoom: 0,  ease: smooth }
  - type: dim          # oscurecido de fondo 0..1
    keys: [ { t: 0, v: 0 }, { t: 200, v: 0.85 }, { t: 1800, v: 0.85 }, { t: 2200, v: 0 } ]
  - type: letterbox
    keys: [ { t: 0, v: 0 }, { t: 200, v: 0.09 }, { t: 1800, v: 0.09 }, { t: 2200, v: 0 } ]
  - type: title_card   # tarjeta con nombre (la actual)
    at: 80
    until: 740
  - type: actor        # mover/posar un actor
    who: caster
    keys:
      - { t: 0,    pose: charge }
      - { t: 950,  move: { to: target, offset: [-14, 0] }, ease: out }
      - { t: 1380, pose: strike }
      - { t: 1800, move: { to: home } }
  - type: sprite       # sprite/frames del catálogo de sprites (nunca rutas)
    sprite: fx.slash_big
    anchor: target
    keys: [ { t: 1000, frame: 0 }, { t: 1060, frame: 1 }, { t: 1120, frame: 2 } ]
  - type: particles
    fire:
      - { t: 1380, preset: burst, anchor: target, element: auto, count: 40, speed: 1.4 }
  - type: shake
    fire: [ { t: 1380, amp: 10, ms: 260 } ]
  - type: flash        # destello de pantalla
    fire: [ { t: 1360, color: white, alpha: 0.7, ms: 160 } ]
  - type: hitstop
    fire: [ { t: 1380, ms: 110 } ]
  - type: impact       # dónde caen números/estado/sonido de golpe del objetivo i
    fire: [ { t: 1380, stagger: 0 } ]
  - type: sound
    fire: [ { t: 0, cue: ult_charge }, { t: 1380, cue: ult_hit_heavy } ]
```

Reglas del formato:
- **Tiempos en ms** desde el inicio. Valores entre keyframes se
  interpolan con `ease` (`linear`, `smooth`, `in`, `out`, `snap`,
  `back` = rebote).
- `element: auto` toma el elemento de la acción (battle_presentation.md
  § "Elemento y color de cada acción"); colores por nombre de rol, nunca
  hex sueltos salvo `color: '#rrggbb'` explícito.
- `sprite:` y `cue:` son **ids lógicos** del sprite_manifest y del
  catálogo de audio (docs/specs/audio.md). El FX nunca nombra archivos.
- `impact` es lo único que conecta con la lógica: los números, textos de
  estado, `poof` y el sonido de golpe del objetivo `i` caen en
  `t + stagger·min(i, 3)` (misma regla que hoy).
- Pistas desconocidas se ignoran con aviso (compatibilidad hacia
  adelante); `schema` mayor al soportado → se usa la animación vieja
  (adaptador, § 2.3).
- Tipos de pista v1: `camera`, `dim`, `letterbox`, `title_card`,
  `actor`, `sprite`, `particles`, `trail` (estela entre dos anclas),
  `shape` (anillo/rayo/columna/onda parametrizables), `shake`, `flash`,
  `hitstop`, `tint` (color de la escena), `impact`, `damage_style`
  (pesado/rebote/crítico), `sound`.

### 2.2 Carga y render

- **`FxCatalog`** (`lib/core/fx/fx_catalog.dart`): única clase que lee
  `fx_manifest.yaml` + los `.fx.yaml` (como `SpriteCatalog`). Parsea a un
  modelo inmutable Dart puro (`FxTimeline`, `FxTrack`, `FxKey`) en
  `lib/game_engine/fx/` (sin Flutter: testeable con `flutter test`).
  Nunca lanza: archivo roto → aviso en log y se usa el adaptador.
- **`FxPlayer`** (presentación): dado un `FxTimeline`, el reloj de la
  escena (respeta hit-stop y congelado) y las anclas resueltas
  (posiciones de lanzador/objetivos), evalúa cada pista en `a` ms y le
  pasa a los painters existentes valores ya calculados (cámara, dim,
  partículas a disparar, sprites a dibujar). El **render no cambia de
  tecnología**: `CustomPainter` + `Ticker` como hoy (battle_presentation
  § "Arquitectura"); Flame sigue siendo opcional donde ya se usa.
- Las primitivas visuales (`shape`, `particles`, `trail`) son painters
  parametrizados que hoy están mezclados dentro de `UltDirector` por
  `UltStyle`; se extraen como funciones reutilizables.
- Consulta por acción: `FxCatalog.forAction(kind, id)` (p. ej.
  `ult/espada`, `duo/guerrero+maga`, `skill/sismo`, `status/veneno`),
  con caída a una genérica de la categoría.

### 2.3 Compatibilidad: adaptador

- **`LegacyFxAdapter`**: para cada animación que todavía no tiene
  `.fx.yaml`, construye un `FxTimeline` equivalente desde el código
  actual (`kUltScripts` → pistas `camera/dim/letterbox/title_card/
  impact/hitstop/shake/flash`, más una pista `legacy` que delega el
  dibujo en `UltDirector` con el `UltStyle` de siempre). Así **todas**
  las animaciones aparecen en el editor desde el día 1 (en solo lectura
  las partes `legacy`, con botón "Convertir a datos").
- Prioridad de resolución: override local (§ 4.2) → asset `.fx.yaml` →
  adaptador. Un test de oro compara, para cada ULT migrada, duración,
  impactos y hit-stop contra la tabla actual hasta que el dueño apruebe
  el cambio de look.
- **Orden de migración**: (1) las 13 ULT y los dúos; (2) habilidades y
  ataques básicos; (3) ULT enemigas y quiebre; (4) estados, muertes,
  procs; (5) movimiento en el mapa. `UltDirector` se borra cuando no
  quede ninguna pista `legacy`.

## 3. Área Visual del editor

### 3.1 Sprites

- **Catálogo navegable**: árbol por categoría — Personajes (clase →
  ascensiones), Enemigos (familia/bioma), Armas e ítems, Tiles y mapa,
  UI (íconos, marcos), Efectos (frames usados por pistas `sprite`).
  Buscador por id, nombre visible y etiqueta; filtro "sin arte propio"
  (todavía el exportado procedural) y "con override".
- Lo que hoy se dibuja en código (íconos de armas, tiles, partes de UI)
  se agrega al manifest con nuevas secciones (`items:`, `tiles:`, `ui:`,
  `fx:`); el catálogo muestra el render procedural como "por defecto"
  hasta que haya PNG.
- **Ficha del sprite**: imagen a ×1/×2/×4/×8 en grilla de píxeles, ancla
  marcada, tamaño, ruta; y **vista en contexto**: mini escena de batalla
  (arena real, formación de prueba, `idle` + estocada + flash de golpe)
  o mini mapa de prueba según la categoría. Comparar antes/después
  (deslizador).
- **Reemplazar**: arrastrar un PNG o elegir archivo. Validación:
  PNG con alfa; tamaño igual al original (si difiere: aviso, opción de
  aceptar si es múltiplo/divisor exacto o de reajustar el ancla); sin
  píxeles semitransparentes en bordes (aviso, no error: pixel art);
  peso máx. 1 MB; paleta: aviso si supera N colores (informativo).
- **Guardado**: copia el PNG a la carpeta de **overrides** (§ 4.2) y
  escribe la entrada en `sprite_overrides.yaml`; "Publicar en el repo"
  lo mueve a `assets/sprites/...` y actualiza `sprite_manifest.yaml`.
- **Recarga en caliente**: `SpriteCatalog.reload(id)` invalida la caché
  de esa imagen; la vista previa y cualquier escena abierta en el editor
  se repintan sin reiniciar.

### 3.2 Animaciones

- **Lista por categoría** (ULT, Dúos, Habilidades, Ataques, ULT
  enemigas, Estados, Muertes, Procs, Mapa, UI) + buscador por nombre,
  id, arma, clase, elemento y etiqueta. Marca: datos / legacy / override.
- **Editor de línea de tiempo simple**:
  - regla en ms con zoom; una fila por pista (ícono + nombre);
    keyframes como rombos, disparos como marcas;
  - clic en un keyframe → panel de valores tipado (números con
    deslizador, anclas como menú, sprite/sonido con selector del
    catálogo, color por rol);
  - arrastrar para mover en el tiempo (imán a 10 ms y a otros keys);
    agregar/quitar pista y key; mostrar/ocultar y "solo" por pista;
  - cabezal de reproducción arrastrable (scrub) y lectura cuadro a cuadro.
- **Vista previa**: mini-arena con personajes de prueba (lanzador
  elegible por clase/arma, 1–4 enemigos de prueba), en **loop**,
  velocidad 0.25×/0.5×/1×, con sonido opcional. Muestra la duración y
  marca impactos y hit-stop en la regla.
- **Plantillas** para arrancar: "ULT de golpe único", "ULT a todos",
  "ULT de varios golpes", "Proyectil", "Curación grupal", "Dúo
  combinado", "Estado (bucle)", "Muerte".
- **Duplicar / renombrar / borrar override**; **deshacer/rehacer**
  (pila por documento, Ctrl+Z / Ctrl+Y); guardado explícito con aviso de
  cambios sin guardar; validación al guardar (`impact` dentro de
  `duration`, anclas válidas para el `targets`, ids de sprite/sonido
  existentes).

## 4. Distribución de los cambios

### 4.1 En el repo (release)

`assets/fx/**` y `assets/sprites/**` son la fuente de verdad del juego
publicado: entran al instalador como cualquier asset (pubspec.yaml lista
las carpetas; docs/specs/distribution.md sin cambios de proceso). El
botón "Publicar en el repo" del editor escribe ahí; el commit y el
release siguen el flujo de `patch_page.dart` (las notas de parche pueden
listar "cambios visuales").

### 4.2 Overrides locales

Carpeta `overrides/` junto al ejecutable del editor (no se empaqueta en
el juego): `overrides/sprites/…png`, `overrides/sprite_overrides.yaml`,
`overrides/fx/<id>.fx.yaml`. Solo el flavor admin (y `main_dev`, si el
flag `useLocalOverrides` está activo) los lee. Sirve para probar sin
tocar el repo. Los datos visuales **no** viajan por red ni afectan el
handshake de balance (cada cliente ve su arte; el resultado del combate
no depende de lo visual).

### 4.3 La duración sale de los datos

- `FxCatalog.durationOf(action)` = `duration` del `.fx.yaml` (o del
  adaptador). Reemplaza los fijos de `battleCinematicHold` (2.3 s ULT /
  1.5 s dúo) y la pausa `wait` tras una ULT (missions.md).
- El host necesita esa duración para `SessionBattle.endHold`: como los
  clientes pueden tener overrides distintos, el host usa la del **asset
  del release** (no la del override) y la manda en el snapshot como hoy
  (`hold`); además el cartel local ya espera a su propia escena
  (`ult == null && !holding`), así un override más largo en un cliente
  solo demora su cartel, nunca el estado compartido.
- Tope de seguridad: `duration` ≤ 6000 ms (validación del editor y
  clamp al cargar).

## 5. ULTs muchísimo mejores

### 5.1 Principios

1. **Anticipación**: una carga legible (pose, energía que converge,
   sonido que sube) antes del golpe; el jugador debe sentir el "ya viene".
2. **Impacto**: un instante claro de contacto — hit-stop, destello,
   sacudida, número pesado — todo en el mismo ms (`impact`).
3. **Cámara con intención**: acercar en la carga, cortar/girar al
   objetivo, empujón en el impacto, volver suave. Nunca mover sin motivo.
4. **Partículas con forma**: pocas y grandes > muchas y chicas; siguen
   la dirección del golpe; restos que caen después (secuela).
5. **Contraste y silencio**: el oscurecido y un corte de sonido de
   ~80 ms antes del golpe hacen que el golpe pese.
6. **Legibilidad**: siempre se ve quién golpea a quién y cuánto; nada
   tapa los números; flashes ≤ 0.7 alfa y respetando la opción de
   reducir destellos (docs/specs/accessibility.md).
7. **Firma propia por arma** coherente con el lore (eco temporal: la
   ULT "repite" golpes del pasado como ecos translúcidos).
8. **Duración** 1.8–2.6 s; saltable como hoy.

### 5.2 Ejemplos en el formato nuevo

**Tajo Final (espada, un objetivo)** — ecos del espadachín:

```yaml
id: ult_espada
category: ult
duration: 2300
targets: single
tracks:
  - { type: dim, keys: [ {t: 0, v: 0}, {t: 200, v: 0.9}, {t: 1900, v: 0.9}, {t: 2300, v: 0} ] }
  - { type: letterbox, keys: [ {t: 0, v: 0}, {t: 200, v: 0.1}, {t: 1900, v: 0.1}, {t: 2300, v: 0} ] }
  - { type: title_card, at: 80, until: 700 }
  - type: camera
    keys:
      - { t: 0,    focus: caster, zoom: +1, ease: smooth }
      - { t: 820,  focus: target, zoom: +1, ease: snap }
      - { t: 1400, zoom: +1.2, ease: out }        # empujón
      - { t: 1600, zoom: +1, ease: smooth }
      - { t: 1900, focus: base, zoom: 0, ease: smooth }
  - type: actor
    who: caster
    keys:
      - { t: 0,   pose: charge }
      - { t: 820, move: { to: target, offset: [-16, 0] }, ease: out }
      - { t: 1400, pose: strike }
      - { t: 1900, move: { to: home } }
  - type: actor          # 3 ecos translúcidos que repiten el corte antes del real
    who: caster_echo
    count: 3
    alpha: 0.4
    keys: [ { t: 1000, pose: strike }, { t: 1120, pose: strike }, { t: 1240, pose: strike } ]
  - type: shape
    fire:
      - { t: 1000, shape: slash_arc, anchor: target, angle: -30, color: element, ms: 160 }
      - { t: 1120, shape: slash_arc, anchor: target, angle: 25,  color: element, ms: 160 }
      - { t: 1240, shape: slash_arc, anchor: target, angle: -70, color: element, ms: 160 }
      - { t: 1400, shape: slash_cross, anchor: target, scale: 2.2, color: white, ms: 260 }
  - { type: sound, fire: [ {t: 0, cue: ult_charge}, {t: 1320, cue: silence_80}, {t: 1400, cue: ult_hit_heavy} ] }
  - { type: flash, fire: [ {t: 1395, color: white, alpha: 0.7, ms: 160} ] }
  - { type: hitstop, fire: [ {t: 1400, ms: 130} ] }
  - { type: shake, fire: [ {t: 1400, amp: 11, ms: 280} ] }
  - type: particles
    fire:
      - { t: 1400, preset: shards, anchor: target, element: auto, count: 28, dir: 0, spread: 50 }
      - { t: 1500, preset: embers_fall, anchor: target, count: 16 }
  - { type: impact, fire: [ {t: 1400, stagger: 0} ] }
```

**Meteoro (báculo, a todos)** — anticipación larga, lluvia escalonada:

```yaml
id: ult_baculo
category: ult
duration: 2600
targets: all
tracks:
  - { type: dim, keys: [ {t: 0, v: 0}, {t: 250, v: 0.9}, {t: 2200, v: 0.9}, {t: 2600, v: 0} ] }
  - { type: title_card, at: 80, until: 760 }
  - type: camera
    keys:
      - { t: 0,    focus: caster, zoom: +1, ease: smooth }
      - { t: 900,  focus: targets_center, zoom: 0, offset: [0, -30], ease: smooth }  # mirar al cielo
      - { t: 1250, focus: targets_center, zoom: 0, ease: smooth }
      - { t: 2200, focus: base, zoom: 0 }
  - { type: tint, keys: [ {t: 900, color: '#ff8a3c', v: 0}, {t: 1200, v: 0.25}, {t: 2000, v: 0} ] }
  - type: shape
    fire:
      - { t: 300, shape: rune_circle, anchor: caster, ms: 600, color: element }
      - { t: 950, shape: sky_crack, anchor: targets_center, ms: 300 }
  - type: trail          # un meteoro por objetivo, 120 ms entre sí
    each_target: true
    stagger: 120
    fire: [ { t: 1100, from: sky, to: target, sprite: fx.meteor, ms: 250, ease: in } ]
  - type: particles
    each_target: true
    stagger: 120
    fire: [ { t: 1350, preset: burst, element: auto, count: 36 }, { t: 1380, preset: smoke_ring, count: 12 } ]
  - { type: shake, each_target: true, stagger: 120, fire: [ {t: 1350, amp: 9, ms: 200} ] }
  - { type: hitstop, fire: [ {t: 1710, ms: 100} ] }      # solo en el último
  - { type: flash, fire: [ {t: 1700, color: white, alpha: 0.6, ms: 150} ] }
  - { type: impact, fire: [ {t: 1350, stagger: 120} ] }
```

**Baluarte (espada+escudo, aliados)** — sin hit-stop, peso en el escudo:

```yaml
id: ult_espada_escudo
category: ult
duration: 2200
targets: allies
tracks:
  - { type: dim, keys: [ {t: 0, v: 0}, {t: 200, v: 0.8}, {t: 1800, v: 0.8}, {t: 2200, v: 0} ] }
  - { type: title_card, at: 80, until: 700 }
  - { type: camera, keys: [ {t: 0, focus: caster, zoom: +1}, {t: 800, focus: allies_center, zoom: 0}, {t: 1800, focus: base} ] }
  - { type: actor, who: caster, keys: [ {t: 0, pose: charge}, {t: 800, pose: guard} ] }
  - type: shape
    fire:
      - { t: 820, shape: shield_dome, anchor: allies_center, color: gold, ms: 900, scale: 1.4 }
      - { t: 820, shape: shockwave, anchor: caster, color: gold, ms: 400 }
  - { type: particles, each_target: true, stagger: 60, fire: [ {t: 1150, preset: rise_sparkles, color: gold, count: 14} ] }
  - { type: flash, fire: [ {t: 820, color: gold, alpha: 0.35, ms: 200} ] }
  - { type: shake, fire: [ {t: 820, amp: 4, ms: 160} ] }
  - { type: impact, fire: [ {t: 1150, stagger: 60} ] }
```

Las 13 ULT se rediseñan una por una con estos principios en el paso 2;
cada una pasa por OK del dueño en la vista previa antes de reemplazar a
la vieja.

## 6. UI del editor (sistema de diseño)

Todo con los componentes de docs/specs/design_system.md:

- Raíz: `DsToolbar` con título "Editor" y `DsTabBar` de tres pestañas:
  **Monitoreo · Balance · Visual** (Balance con sub-pestañas actuales:
  Entidades, Cambios, Parche). `DsBadge` en la pestaña con cambios sin
  guardar/publicar.
- Patrón de cada área: columna izquierda = `DsSearchField` + árbol de
  categorías + lista de `DsListRow` (insignia "override"/"legacy");
  centro = vista previa; derecha = panel de propiedades (`DsCard`
  única, sin tarjetas anidadas).
- Visual tiene sub-pestañas **Sprites · Animaciones**. En Animaciones,
  la línea de tiempo ocupa la franja inferior (alto redimensionable).
- Acciones con `DsButton`: principal "Guardar", secundario "Publicar en
  el repo", fantasma "Descartar override", íconos con tooltip
  (duplicar, renombrar, deshacer, rehacer, reproducir/pausa, loop).
- Avisos con `DsToast` (validación de PNG, errores de YAML).
- Balance gana el buscador global (por nombre/id/campo) y orden por
  categoría (`admin_index.dart` ya indexa las entidades).

## 7. Plan de implementación

1. **Visor y edición de sprites**: reorganizar admin en 3 pestañas;
   `SpriteCatalog.reload`; catálogo por categoría + buscador; ficha con
   zoom y vista en contexto; reemplazo con validación; overrides
   locales; "Publicar en el repo". Nuevas secciones del manifest para lo
   que hoy se dibuja en código (con fallback procedural). Tests:
   validador de PNG, lectura de overrides.
2. **Formato FXA + adaptador + ULT**: modelo Dart puro y parser
   (`game_engine/fx/`), `FxCatalog`, `FxPlayer`, primitivas extraídas de
   `UltDirector`, `LegacyFxAdapter`, test de oro de tiempos. Duración
   desde datos (`battleCinematicHold`, `wait`, `endHold`). Migrar y
   rediseñar las 13 ULT y los dúos (vista previa de solo lectura en el
   editor para aprobar).
3. **Editor de línea de tiempo**: pistas/keyframes, panel de valores,
   scrub, mini-arena en loop, plantillas, duplicar/renombrar,
   deshacer/rehacer, validación al guardar.
4. **Resto de animaciones**: habilidades, ataques, ULT enemigas y
   quiebre, estados, muertes, procs, movimiento en el mapa; borrar
   `UltDirector` y los fx hardcodeados cuando no quede ninguno `legacy`.
   Actualizar battle_presentation.md y sprites.md para que apunten a
   los datos.

### 7.1 Paso 1 tal como quedó (implementado)

- **Editor** (`main_admin`): `DsToolbar` "EDITOR" + `DsTabBar`
  **MONITOREO · BALANCE · VISUALES** (`lib/features/admin/presentation/
  admin_app.dart`, `EditorArea`). Arranca en Balance. Buscador global en
  la barra: filtra el área activa (Balance → entidades por nombre/id/
  campo, vuelve a la sub-pestaña Entidades; Visuales → sprites). Balance
  conserva sus sub-pestañas Entidades · Cambios · Parche; insignias con
  cambios sin guardar (Balance) y cantidad de overrides (Visuales).
- **Visuales → Sprites** (`editor/sprites_page.dart`,
  `editor/sprite_editor_controller.dart`): columna izquierda con
  buscador, categorías (TODO, PERSONAJES, ENEMIGOS, JEFES, ARMAS E ÍTEMS,
  TILES, UI, EFECTOS) con conteo, filtro "con override" y lista con
  miniatura e insignia OVERRIDE; centro con zoom ×1/×2/×4/×8 sobre
  damero con grilla de píxeles y ancla, ANTES / AHORA cuando hay
  override, y **escena de contexto** (batalla: héroe/enemigo de prueba,
  ítem en mano, efecto sobre el enemigo, ícono en un panel; mapa: tile
  repetido con el héroe encima); derecha, ficha (`DsCard` única) con
  REEMPLAZAR PNG, DESCARTAR OVERRIDE, validación, RECARGAR ARTE,
  paquete de arte (EXPORTAR / IMPORTAR) y PUBLICAR AL REPO (con diálogo
  de confirmación que lista lo que se copia). Animaciones: pestaña
  reservada para el paso 2.
- **Categorías**: personajes = `characters:`; enemigos/jefes =
  `enemies:` partido por `EnemyDef.boss` (y las `…Fase2`); el manifest
  gana `items:`, `tiles:`, `ui:` y `fx:` con entradas
  `{ procedural: true, size: [w, h] }` (lo que hoy se dibuja en código).
  Una procedural se muestra rayada como "dibujo en código" hasta que
  tenga PNG. **Pendiente**: que el juego lea esos PNG nuevos (hoy el
  render de ítems/tiles/UI/fx sigue siendo procedural aunque se
  publique uno); se hace al migrar cada painter.
- **Ids de sprite**: `<sección>.<clave>.<frame>` (`characters.maga.idle`,
  `items.espada.idle`). `SpriteEntry` / `SpriteCategory`
  (`lib/features/combat/domain/sprite_entry.dart`).
- **`SpriteCatalog`** sigue siendo el único lector del manifest: suma
  `entries`, `entry(id)`, `bytes`/`assetBytes`/`image`, `hasOverride`,
  `reload([id])` y la capa `overrides` (`SpriteOverrideSource`), que se
  consulta antes que el asset. `SpriteCatalog.defaultOverrides` la pone
  el composition root.
- **Overrides locales** (`lib/features/combat/data/
  local_sprite_overrides_io.dart`, stub en web): `<root>/sprites/<id>.png`
  + `<root>/sprite_overrides.yaml` (`sprites: { <id>: sprites/<id>.png }`).
  Root: `<repo>/overrides` en el Editor; `overrides/` del directorio
  actual (o `--dart-define=ECOS_OVERRIDES=<ruta>`) en `main_dev`.
  Ignorado por git. Lanza si se intenta dentro de
  `%APPDATA%\EcosDelTiempo`.
- **`main_dev`**: `FeatureFlags.useLocalOverrides` → lee los overrides y
  el título muestra **RECARGAR ARTE** (relee la carpeta e invalida
  `gameSpritesProvider`).
- **Validación** (`domain/sprites/png_validator.dart`, Dart puro):
  error si no es PNG, sin alfa (tipo 4/6 o `tRNS`), > 1 MB, o tamaño
  distinto que no sea múltiplo/divisor entero exacto del original;
  aviso si es múltiplo/divisor (se acepta), si hay píxeles
  semitransparentes o más de 32 colores. Tamaño esperado: el PNG del
  repo, o `size:` del manifest para las procedurales.
- **Paquete de arte** (`domain/sprites/art_pack.dart`): zip con
  `art_pack.yaml` (`schema: 1`, `sprites: { <id>: sprites/<id>.png }`) +
  los PNG. Importar pisa overrides con el mismo id. Reservado `fx:` para
  el paso 2.
- **Publicar al repo**: copia cada override a `assets/sprites/<ruta>`
  (la del manifest; las procedurales van a `items/`, `tiles/`, `ui/` o
  `effects/<clave>.png`), reescribe solo esa entrada de
  `sprite_manifest.yaml` conservando comentarios (`setManifestPath`) y
  borra el override. El commit queda a mano. El catálogo en memoria del
  Editor ve el manifest nuevo al reiniciar.
- Capturas: `tool/shots/editor_shots_test.dart` →
  `docs/release_shots/editor/`.

### 7.2 Paso 2 tal como quedó (implementado, v0.16.0)

- **Modelo y parser** (`lib/game_engine/fx/fx_timeline.dart`, Dart
  puro): `FxTimeline` / `FxTrack` / `FxKey` / `FxPhases` / `FxEase`.
  Cada key o disparo guarda `t`, `ease` y el resto como mapa (el modelo
  no conoce los campos de cada pista; los interpreta el `FxPlayer`).
  `numAt` interpola con la curva del key de llegada; `textAt` es
  escalonado. `toYaml()` escribe ordenado y estable (ida y vuelta
  exacta). `duration` se recorta a 6000 ms con aviso; `schema` mayor →
  `FormatException`; pistas desconocidas se conservan con aviso.
- **Formato, agregados al § 2.1**:
  - `impact` con `pre: true` = golpe previo (solo visual/sonido; los
    `preHitsMs` del guion). El primero sin `pre` es el impacto real
    (`stagger` incluido).
  - Pista **`echo`** (la firma de las ULT): `who: caster|partner`,
    `count`, `lag` (ms entre copias), `alpha`, `color` (rol), `fade`,
    `spacing: [dx, dy]` (abanico por copia) y `orbit` (radio alrededor
    del destino). Los keys son el camino `{ t, at: <ancla>, dx, dy, ease }`;
    la copia *i* lo recorre `i·lag` ms más tarde y más tenue. Se dibuja
    con el sprite real del actor: silueta luminosa sumada + halo ±1 px +
    el sprite tenue encima.
  - `camera`: en este paso solo cuenta `focus` (caster, target, line,
    targets, allies, group); el movimiento lo sigue haciendo
    `ultCameraAt` con ese foco (empujón en el impacto incluido).
  - Anclas: `caster`, `partner`, `target` (el *i* con `each_target`),
    `targets_center`, `allies_center`, `sky` / `sky_center` /
    `sky_caster`, `screen`. `dx` es relativo a hacia dónde mira el
    lanzador.
  - Colores por rol: `element` (color de la acción), `light`, `dark`,
    `echo` (el de la acción llevado al cian temporal), `white`, `gold`
    o `'#rrggbb'`.
  - Formas (`shape`): `gather`, `slash_arc`, `slash_cross`, `ring`
    (`implode`), `rune_circle`, `shockwave`, `quake`, `pillar`, `beam`,
    `shield_dome`, `sky_crack`, `bolt`, `clock`, `cross`, `rain`,
    `shards`, `reticle`. Estelas (`trail`): `from`/`to`, `ms`, `head`
    (`dot`, `arrow`, `spear`, `hammer`, `meteor`, `bolt`), `echoes` +
    `lag` (cabezas fantasma). Partículas: `burst` (`element`), `sparks`,
    `shards`, `sparkles`, `embers`, `dust`, `debris`, `frost`.
  - `actor`, `sprite`, `damage_style` y `tint` con color por key quedan
    reservados: se leen y se guardan. (`title_card`, `letterbox` y
    `sound` se reproducen desde v0.18.0, § 7.3.) Formas, estelas y
    tinte se dibujan sumando luz (brillan sobre el oscurecido sin tapar).
- **Archivos**: `assets/fx/fx_manifest.yaml` (`fx: { <id>: <ruta> }`),
  `assets/fx/ult/<id>.fx.yaml` (las 13 ULT de arma) y
  `assets/fx/duo/duo.fx.yaml` (dúo genérico; `duo_<clave>` lo pisa por
  dúo). Desde v0.18.0 pubspec registra la carpeta de cada categoría de
  `kFxCategories` (§ 7.4): publicar no requiere tocarlo.
- **`FxCatalog`** (`lib/core/fx/fx_catalog.dart`): único lector; capas
  edición en vivo (Editor) → override local → asset → `LegacyFxSource`.
  `forAction('duo', clave)`, `durationOf`, `releaseDurations()` (asset
  + legacy, nunca overrides), `reload([id])`, `setLive/clearLive`,
  `sourceOf` (override / datos / legacy), `log` de avisos. Nunca lanza.
  Overrides: `FxOverrideSource` / `EditableFxOverrides`
  (`lib/core/fx/fx_overrides.dart`), implementados por
  `LocalSpriteOverrides` en la misma carpeta: `<root>/fx/<id>.fx.yaml`
  + `<root>/fx_overrides.yaml` (`fx: { <id>: fx/<id>.fx.yaml }`).
- **`LegacyFxAdapter`** (`scene/fx_bridge.dart`): timeline de solo
  lectura desde cada `UltScript` del código (ULT de ascensión, ULT
  enemigas, dúo viejo): fases, cámara, oscurecido, impactos, hit-stop,
  sacudida y una pista `legacy` con el `UltStyle`. Test de oro: el
  guion derivado de ese timeline coincide en fases, impactos, hit-stop,
  sacudida y foco con el original.
- **Escena**: `installFx()` (composition roots p2p, lan, dev, admin)
  carga el catálogo, lo deja en `FxCatalog.active` y llena
  `CinematicDurations.shared`. `ultScriptFor(id)` / `duoScript(clave)`
  devuelven el guion **derivado de los datos** (`scriptFromTimeline`:
  fases, primer impacto + `stagger`, golpes previos, hit-stop y
  sacudida mayores, foco) con `data` = el timeline; el estilo del
  código se conserva (sonido y elemento de partículas). Con `data`,
  `UltDirector.tick/paintWorld/worldDim` delegan en **`FxPlayer`**
  (`scene/fx_player.dart`: `tick` dispara partículas/sacudidas/hit-stop
  una vez por clave, sin sacudida ni hit-stop si se adelantó; `paint`
  dibuja tinte, formas, estelas, ecos y destellos ≤ 0.7 × el factor de
  destellos del jugador). Sin catálogo (tests de escena/sonido) todo
  sigue con el código. Las ULT de ascensión, de camino (`kBranchUltLooks`
  usa los datos de la ULT a la que se parece) y enemigas siguen legacy.
- **Duración desde datos** (§ 4.3): `CinematicDurations`
  (`game_engine/fx/`, Dart puro) mapea id → ms; `battleCinematicHold`
  la usa (inyectable en `SessionEngine(cinematics:)`, si no
  `CinematicDurations.shared`). Sin datos: 2.3 s / 1.5 s históricos. El
  host usa la del release; el snapshot lleva `hold` como antes (**sin
  cambio de protocolo**). La pausa `wait` del cliente
  (`session_music`, `session_sfx`) sale del mismo guion derivado.
- **Las 13 ULT rediseñadas** (≤ 2.6 s, todas con ecos):
  Tajo Final (3 ecos que se adelantan al corte real), Cataclismo (ecos
  que saltan y caen, onda + grietas + columnas), Meteoro (círculo
  rúnico, grieta en el cielo, meteoros con cabezas fantasma), Paradoja
  (reloj que gira hacia atrás, 5 ecos del pasado que convergen, anillo
  que implota), Tormenta de Flechas (ecos en abanico disparando al
  cielo, lluvia), Disparo Letal (retícula que se cierra, bala con 5
  ecos, rayo que queda), Baluarte (ecos dorados que cubren al grupo,
  cúpula), Juicio Divino (ecos que ascienden en oración, columnas y
  cruces), Martillo Celestial (salto con estela de ecos, martillo
  fantasma, columna + onda), Lluvia de Lanzas (ecos en el aire, lanzas
  dobles), Tormenta Arcana (ecos en unísono, rayos de aviso y rayos
  reales), Andanada (tres virotes y el grande con 5 ecos), Danza de Mil
  Cortes (7 ecos en órbita que cortan uno tras otro). Dúo: los ecos de
  los dos convergen con sus estelas, cruz + anillo por objetivo.
- **Editor → Visuales → Animaciones** (`editor/animations_page.dart`,
  `fx_editor_controller.dart`, `fx_preview.dart`): lista por categoría
  (ULT, DÚOS, ULT ENEMIGAS… con conteo) + buscador (nombre, id,
  etiqueta; también el buscador global), insignia DATOS / LEGACY /
  OVERRIDE; mini escena de batalla (240 × 135 px del mundo, sprites
  reales, 1–4 enemigos, cámara de la cinemática opcional, oscurecido)
  con REPRODUCIR/PAUSA, ×0.25/×0.5/×1, LOOP; línea de tiempo con fases,
  rombos (keys), marcas (disparos), impactos y cabezal: clic/arrastre =
  scrub, clic en un rombo = elegirlo. Ficha: duración y valores
  numéricos del key elegido (`t` y cada campo numérico) con
  `NumberStepper`; cada cambio se reproduce al instante
  (`FxCatalog.setLive`); validación (tope de ULT, impactos fuera de la
  duración); GUARDAR (override), DESHACER CAMBIOS, DESCARTAR OVERRIDE,
  RECARGAR, EXPORTAR / IMPORTAR paquete y PUBLICAR AL REPO
  (copia a `assets/fx/<ruta>` y suma la entrada a `fx_manifest.yaml` con
  `addFxManifestEntry`). Lo legacy es de solo lectura. El paquete de
  arte (`art_pack.yaml` gana `fx: { <id>: fx/<id>.fx.yaml }`) y
  PUBLICAR AL REPO de Sprites también llevan las fx.
- **Pendiente (paso 3)**: agregar/quitar pistas y keys, arrastrar keys
  en el tiempo, plantillas, duplicar/renombrar, deshacer/rehacer,
  convertir legacy a datos, hojas de sprites por cuadro en la pista
  `sprite` (el formato ya las admite). → Hecho en v0.18.0 salvo lo que
  lista § 7.3 como pendiente.
- Capturas: `tool/shots/fx_shots_test.dart` →
  `docs/release_shots/v0.16.0/`.

### 7.3 Paso 3 tal como quedó (implementado, v0.18.0)

- **Edición visual** (`fx_editor_controller.dart`, `animations_page.dart`):
  - **Keys**: doble clic en una fila vacía agrega un key (o un disparo en
    las pistas de disparos: `particles`, `shape`, `trail`, `shake`,
    `flash`, `hitstop`, `impact`, `sound`, `prim`) que copia los valores
    del key anterior (o una plantilla del tipo); `+ KEY` lo agrega en el
    cabezal de la pista elegida; `BORRAR KEY` o la tecla Supr lo borra.
  - **Arrastrar** un rombo/marca lo mueve en el tiempo (una sola entrada
    de deshacer por arrastre); arrastrar en vacío sigue siendo scrub.
  - **Imán** (`IMÁN`, encendido por defecto): se pega a cualquier otro
    key/disparo a menos de 25 ms; si no, redondea a 10 ms.
  - **Curvas**: el key elegido muestra LINEAL · SUAVE · ENTRA · SALE ·
    CORTE · REBOTE (`FxEase`, la curva de llegada). Los campos de texto
    conocidos (ancla, foco, color por rol, forma, partículas, cabeza de
    estela: `kFxFieldOptions`) se eligen con botones.
  - **Pistas**: `DUPLICAR PISTA` (queda debajo), `BORRAR PISTA`, `NUEVA
    PISTA` (plegable con los tipos, cada uno con un key de ejemplo) y
    `CAPA DE ECOS` (pista `echo` de 3 copias del lanzador que llegan al
    objetivo justo antes del primer impacto).
  - **Deshacer/rehacer**: pila por documento (200 pasos), `DESHACER` /
    `REHACER` y Ctrl+Z / Ctrl+Y (Ctrl+Mayús+Z). Elegir otra animación,
    DESHACER CAMBIOS o guardar la vacían.
  - **Convertir a datos** (solo legacy): la copia pierde la pista
    `legacy` y gana capa de ecos + anillo + partículas en el impacto;
    GUARDAR crea el override.
  - **Validación**: además de lo del paso 2, keys fuera de la duración y
    ecos sin camino. **Bloquean el guardado** (`blocking`): ULT de más de
    2600 ms e impactos después del final (aviso de error, no se escribe).
  - La vista previa dibuja también las primitivas `prim` (aproximadas),
    las barras de cine (`letterbox`) y la tarjeta (`title_card`).
- **El juego reproduce desde los datos** (cinemáticas ULT/dúo/enemigas):
  - `letterbox`: alto de las barras = `v` × alto del área del mundo
    (0.09 = el de siempre), tope 0.25. Sin la pista, como antes.
  - `title_card`: `at` / `until` (ms) = entra en `at` (180 ms) y sale en
    los 200 ms que empiezan en `until − 140`; `hidden: true` = sin
    tarjeta. Sin la pista: `at` 80, `until` = fin de la preparación.
    El dúo mantiene su tarjeta partida.
  - `sound`: cada disparo `{ t, cue }` suena en `t`; `cue: build |
    release | impact` = los sonidos propios de la ULT (`Sfx.ult(id, …)`),
    cualquier otro = id del catálogo de sonido (los que no existen se
    ignoran). Si la pista existe, reemplaza a la carga/descarga del
    código; el impacto de cada golpe sigue sonando con su golpe (no hace
    falta ponerlo en la pista). Hoy ninguna ULT del repo trae la pista
    (sin cambio de sonido).
- **Pendiente**: plantillas de animación nueva, duplicar/renombrar una
  animación entera, mostrar/ocultar y "solo" por pista, zoom de la regla,
  hojas de sprites por cuadro en `sprite`, pistas `actor` y
  `damage_style`.

### 7.4 Paso 4 tal como quedó (implementado, v0.18.0)

- **ULT de ascensión en datos**: `assets/fx/ult/ult_<ascensión>.fx.yaml`
  (berserker, señor de la guerra, cronomante, elementalista,
  francotirador, trampero, templario, guardián). Parten del diseño de
  datos de la ULT de arma con el mismo estilo (Danza de Mil Cortes,
  Cataclismo, Paradoja, Meteoro, Disparo Letal, Tormenta de Flechas,
  Juicio Divino, Baluarte) retimado a los tiempos del guion del código:
  misma duración, preparación, impacto, `stagger`, golpes previos y
  hit-stop (test), así que el host espera lo mismo que antes. Todas con
  ecos. Con esto todo lo que arma `LegacyFxAdapter` tiene datos: el
  adaptador queda solo como respaldo (sin asset o con un archivo roto).
- **Momentos de batalla** (`kBattleFxMoments` en `battle_fx.dart`, 41
  archivos en `assets/fx/{attack,skill,proc,status,death}/`): ataque,
  ataque a todos, proyectil, golpe a enemigo / a aliado, golpe y golpe en
  área de enemigo; habilidad, a todos, defensa, proteger, provocar,
  escudo del grupo, prisa, apoyo y grito de ascensión, **Pulso del
  Tiempo** e **Instante**; **quiebre**, quebrado, **Fisurado**,
  quebradizo que se rompe, **Convergencia**; estado aplicado, tics de
  quemadura/veneno, aturdido, congelado, buffs (velocidad, ataque ±,
  marca), curación (normal, sagrada, regeneración, maná), escudo y
  escudo que absorbe; **muerte**, **aparición** (invocación) y revivir.
- **Pista `prim`** (nueva en el formato): disparos `{ t, kind, at, to,
  dx, dy, color, el, big, up, heavy, ghost, who, weapon }` = una
  primitiva del pintor de batalla (`FxKind`: `ring`, `slash`, `aura`,
  `proj`, `poof`, `shatter`, `bubble`, `crack`, `pulse`, `arrow`,
  `reticle`, `afterimage`, `arc`, `act`, `windup`, `flash`…). `at`:
  `caster` (quien actúa), `target`, `allies`, `allies_others`; `color`
  por rol: `action` (el de la acción), `status`, `white`, `gold`,
  `hurt`, `crit`, `heal`, `regen`, `mana`, `holy`, `orange`, `violet`,
  `gray`, `break`, `break_flash`, `brittle`, `shield`, `echo` o
  `'#rrggbb'`; `el`: elemento o `action`; `weapon: true` usa el estilo
  del arma de quien actúa; `who: true` asocia el efecto al actor. Así los
  momentos se ven **igual que el código** (test que juega batallas
  enteras con y sin datos y compara cada efecto).
- Las demás pistas visuales de un momento (`shape`, `particles`,
  `echo`, `trail`, `flash`, `shake`, `hitstop`, `tint`) van en un efecto
  `FxKind.data` que la escena reproduce con el mismo `FxPlayer` (anclas:
  `caster` = quien actúa, `target` = el objetivo). Mejoras con ecos donde
  aportan (nuevas, no estaban en el código): Pulso del Tiempo (reloj y
  anillo de eco, destellos), Instante (estela + anillo de eco), Fisurado
  (pulso + astillas), Convergencia (onda, anillo que implota, estallido
  y sacudida sobre las piezas de la reacción), estado aplicado (aura del
  elemento del estado), aturdido (aura), prisa (pulso dorado en los
  aliados) y revivir (anillo, aura y columna de luz).
- **Respaldo**: sin catálogo (tests del motor/escena) o sin el archivo,
  cada momento usa el código de siempre en `mapBattleEvents`. Los
  números, textos y carteles (contenido que depende del evento) y la
  geometría de reacciones, rebotes, procs del árbol y mecánicas de jefe
  siguen en código (pendiente).
- **Carpetas**: pubspec registra `assets/fx/<categoría>/` para cada una
  de `kFxCategories` (`map_move/` y `ui/` reservadas con un README);
  test de que estén todas. PUBLICAR AL REPO ya no pide tocar pubspec.
- **Red**: sin cambios (los datos visuales no viajan; `kProtocolVersion`
  igual; las duraciones de las ULT de ascensión no cambian).
- **Pendiente**: movimiento en el mapa y UI; borrar `UltDirector` y el
  código de respaldo cuando el dueño apruebe (hoy queda como red de
  seguridad); actualizar battle_presentation.md y sprites.md en detalle
  (por ahora apuntan acá).
- Capturas: `tool/shots/v0180_editor_fx_shots_test.dart` →
  `docs/release_shots/v0.18.0/` (las capturas cargan las fuentes de
  Material del SDK: `loadMaterialFonts`).

### 7.5 Paso 5: arte procedural con perillas (v0.19.0)

**Bug previo (Animaciones congela la app).** El reloj de la vista previa
llamaba `notifyListeners()` del controlador en cada frame; el shell del
Editor escucha ese controlador (`Listenable.merge`) y reconstruía TODA
la página (lista, ficha, barra de pestañas, el cálculo de la lista de
animaciones) 60 veces por segundo. Con el catálogo completo cada frame
tardaba más que el intervalo y los clics no llegaban a procesarse.
Arreglo:
- La animación **arranca en PAUSA** (al abrir y al elegir otra).
- El reloj vive en un `ValueNotifier` aparte (`FxEditorController.clock`):
  avanzar el tiempo NO notifica al controlador. Solo se repintan el
  lienzo (`CustomPainter(repaint: clock)` dentro de un
  `RepaintBoundary`), la línea de tiempo y el contador de ms.
- El `Ticker` corre solo mientras se reproduce (se detiene en pausa y se
  libera con la página).
- Sprites no tiene reloj (la escena de contexto es estática); su lienzo
  también va en `RepaintBoundary`.
- Test de widget: con la animación reproduciendo, cambiar de pestaña y
  usar botones responde, y el controlador no notifica por frame.

**Arte procedural real en Visuales → Sprites.** Las entradas
`procedural: true` dejan de verse rayadas cuando hay un generador para
ellas: se ve el dibujo que usa el juego (miniatura, zoom y escena de
contexto). Lo que todavía no tiene generador expuesto (tiles, UI, fx)
sigue rayado (pendiente). Reemplazar por PNG sigue igual y gana sobre el
procedural.

**Generador `item_icon` (armas e ítems).** Es el ícono pixel 8×8 del
inventario (`ItemCell`/`PixelIcon`): un bitmap por forma con letras de
material (`m` metal, `h` mango, `g` acento, `s` cuerda, `p` papel,
`c` tapa, `w` vidrio). Los bitmaps viven en un catálogo único
(`lib/core/procedural/item_icons.dart`); el pintor lee sus parámetros
de datos. Perillas (valor por defecto = aspecto actual, sin cambio
visual si no hay override):

| perilla | tipo | defecto | efecto |
|---|---|---|---|
| `metal`, `handle`, `string`, `paper`, `cover`, `glass` | color `'#rrggbb'` | los de siempre | paleta por material |
| `accent` | color o `''` | `''` (rareza/material) | fija el acento |
| `shine` | -0.5..0.5 | 0 | aclara (+) u oscurece (−) toda la paleta |
| `highlight` | bool | false | brillo: el primer pixel de metal de cada fila, más claro |
| `outline` | bool | false | contorno de 1 px alrededor del dibujo |
| `outline_color` | color | `#14101E` | color del contorno |
| `gem` | bool | false | adorno: gema de acento en el primer pixel de mango |
| `mirror` | bool | false | variante espejada (horizontal) |
| `scale` | 0.5..1 | 1 | proporción: tamaño del dibujo dentro de la casilla |

Entradas del manifest → forma: `espada`, `hacha`, `lanza`, `dagas`,
`arco`, `ballesta`, `rifle`, `varita`, `tomo`, `pocion` (iguales),
`baculo` → `báculo`, `espada_escudo`/`maza_escudo`/`martillo_escudo` →
`escudo`, `cofre` → `cofre` (forma nueva, solo editor por ahora). El
juego pide el ícono con la clave de la entrada (`procKeyForType`:
`espada+escudo` → `espada_escudo`, `báculo` → `baculo`), así que un
override por entrada afecta SOLO a esa arma.

**Alcance: entrada o familia.** El generador es por familia (la sección
del manifest: `items`). Al guardar se elige ENTRADA (`items.espada`) o
FAMILIA (`items`, todas las armas e ítems). Resolución: defecto ←
familia (repo) ← entrada (repo) ← familia (override) ← entrada
(override); cada capa pisa solo las perillas que declara.

**Datos (`procedural.yaml`).**
```yaml
schema: 1
families:
  items: { shine: 0.2 }
entries:
  items.espada: { metal: '#ffd166', gem: true }
```
- Repo: `assets/sprites/procedural.yaml` (lo carga `SpriteCatalog.load`;
  sin archivo = todo por defecto).
- Override local: `overrides/procedural.yaml` (misma carpeta que los
  PNG y fx). GUARDAR escribe; DESCARTAR borra la entrada/familia del
  override; DESHACER CAMBIOS vuelve al guardado. La vista previa es en
  tiempo real (borrador en memoria) y la recarga en caliente aplica al
  guardar.
- Paquete de arte: `procedural.yaml` en la raíz del zip, declarado en
  `art_pack.yaml` como `procedural: procedural.yaml` (schema sigue en 1:
  campo opcional). Importar fusiona con el override existente.
- PUBLICAR AL REPO fusiona el override en
  `assets/sprites/procedural.yaml` y lo borra de la carpeta local.
- **Red**: sin cambios (arte local; `kProtocolVersion` igual).
- Tests: defecto = píxeles idénticos al pintor anterior; override cambia
  el dibujo y DESCARTAR lo revierte; entrada vs familia; ida y vuelta
  del paquete con params.
- Capturas: `tool/shots/v0190_editor_procedural_shots_test.dart` →
  `docs/release_shots/v0.19.0/editor/`.
- **Pendiente**: generadores con perillas para tiles (`arena_painter`),
  UI e íconos de fx; el ícono del piso del mapa (`loot_painter`) todavía
  usa su propio dibujo.

## 8. Preguntas abiertas (respondidas por el dueño)

Respuestas:
1. **YAML**, como está.
2. **Sí**: exportar/importar un **paquete de arte** (zip con overrides
   de sprites, y de fx desde el paso 2) para que un amigo lo pruebe sin
   publicar.
3. Seguir con **1 frame `idle` + animación procedural**, pero el formato
   queda listo para hojas de sprites cuadro por cuadro (el manifest ya
   admite varios frames por entrada: cada clave que no sea `scale`,
   `float`, `size` o `procedural` es un frame; el id incluye el frame).
4. **Aprobado** el tope de **~2.6 s** por ULT y los **"ecos"
   translúcidos** como firma visual común.

Preguntas originales:

1. ¿YAML está bien como formato (editable a mano y por el editor) o
   preferís JSON para alinear con `balance.json`?
2. Los overrides locales: ¿alcanza con que los vea el editor/`main_dev`,
   o querés poder pasarle a un amigo un paquete de arte/animaciones para
   que lo pruebe en su juego antes del release?
3. ¿Querés animaciones por frames de verdad (caminar, ataque) en los
   sprites, o seguimos con 1 frame `idle` + animación procedural y los
   frames solo para efectos?
4. Rediseño de ULT: ¿aprobás el tope de ~2.6 s (hoy 2.2–2.5 s) y la idea
   de "ecos" translúcidos como firma visual común?

## v0.17.0: FXA de las ULT v2

86 animaciones nuevas en datos (ultimates_v2.md): 50 de jugador en
`assets/fx/ult/ult2_*.fx.yaml` y 36 enemigas (jefes, élites y Furia
Élite) en `assets/fx/enemy_ult/` (carpeta nueva en pubspec). Las ULT
enemigas dejan de ser legacy en el Editor; las de ascensión siguen en
el código. Todas con pista `echo` y ≤ 2600 ms (test
`ult_data_test.dart`).