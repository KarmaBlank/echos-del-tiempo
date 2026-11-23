# Monorepo de juegos Ecos del Tiempo (Melos)

Estado: **spec + plan de migración**; PR 1 (workspace + Melos) hecho,
el resto pendiente. Base: `main` en v0.33.1 (Mundo) / Travesía
v0.3.x.

## 0. Decisión del dueño

El repo deja de ser "una app con dos flavors" y pasa a ser un **monorepo
de juegos Ecos del Tiempo** que comparten paquetes:

- `games/` — una app Flutter por juego (`echoes` y `paradox`, § 0.1). Cada
  juego es un composition root con sus flavors (p2p, dev, lan…) y elige
  qué paquetes y qué lógica cablea. Los paquetes son un "recetario".
- `apps/` — herramientas: un editor por juego (`echoes_editor`,
  `paradox_editor`). Sumar un juego suma su editor.
- `packages/` — paquetes compartidos, Dart puro o Flutter.

Las decisiones de `CLAUDE.md` siguen vigentes (Clean Architecture,
Feature-First, `NetSession` como única puerta a la red, motor en Dart
puro, sprites por manifest, SDD). El monorepo las convierte en límites
que el compilador hace cumplir: un paquete Dart puro no puede importar
Flutter porque no lo declara.

### 0.1 Nombres y convención (decisión del dueño, 2026-11-23)

| | RPG (hoy "Mundo") | Roguelike (hoy "Travesía") |
|---|---|---|
| Nombre (inglés) | Echoes of Time | Echoes of Time: Paradox |
| Nombre (español, al jugador) | Ecos del Tiempo | Ecos del Tiempo: Paradoja |
| Carpeta | `games/echoes` | `games/paradox` |
| Editor | `apps/echoes_editor` | `apps/paradox_editor` |
| Reglas | `packages/echoes_rules` | `packages/paradox_rules` |
| Tags | `vX.Y.Z` | `paradox-vX.Y.Z` |
| Ejecutable | `echos_del_tiempo.exe` (sin cambio) | `echoes_paradox.exe` |

- **Todo el monorepo se nombra en inglés**: carpetas, paquetes,
  identificadores, tags, scripts. Los identificadores en español que ya
  existen (`mundo`, `travesia`, `session_engine_run`, `Juego`, …) son
  deuda técnica que se migra de a poco, cuando se toca el código
  (registrada en `docs/tech_debt.md`). El texto que ve el jugador sigue
  en español.
- Prefijo de paquetes: `echoes_` (no `ecos_`).
- En este spec "Mundo" y "Travesía" siguen apareciendo al describir el
  código de hoy; el destino usa siempre los nombres nuevos.

### 0.2 Preguntas abiertas resueltas por defecto

El dueño puede cambiarlas después; mientras tanto rigen estas
(*decididas por defecto*, 2026-11-23):

1. **Tags**: pasan al prefijo por juego (`v*`, `paradox-v*`).
   El actualizador de echoes acepta además el viejo `v*` durante la
   transición, y el release de echoes sigue marcado `--latest`.
2. **Assets**: un solo paquete compartido `echoes_assets` + overlays por
   juego (`games/<game>/assets`, con prioridad en `SpriteCatalog`).
3. **Catálogo de Paradox**: se separa en el PR 3 (copia independiente,
   roguelike.md § 7).
4. **Ejecutable de Paradox**: `echoes_paradox.exe`.
5. **Sala (lobby)**: base compartida en `echoes_features`, personalizada
   por juego.
6. **Editores**: solo internos, se corren desde el repo; sin instalador
   ni tag.
7. **CI**: sin GitHub Actions por ahora; las verificaciones siguen locales
   en `tool/release.ps1` y en los scripts de Melos.
8. **Prefijo**: `echoes_`.

## 1. Herramienta: Melos 8 + pub workspaces

Verificado en pub.dev el 2026-11-23: **melos 8.10.1** (SDK `^3.9.0`).
Desde Melos 7 la configuración vive en el `pubspec.yaml` raíz (clave
`melos:`, ya no hay `melos.yaml`) y se apoya en **pub workspaces**
nativos de Dart (`workspace:` en el pubspec raíz, `resolution: workspace`
en cada miembro). Consecuencias:

- Un solo `pubspec.lock` y un solo `.dart_tool/` en la raíz: todas las
  apps y paquetes resuelven las mismas versiones (se acaba la deriva).
- `flutter pub get` en la raíz resuelve todo; `melos bootstrap` sigue
  existiendo (enlaza y corre hooks) pero ya no hace `pubspec_overrides`.
- Dart ≥ 3.11 acepta globs en `workspace:` (`packages/*`). El Flutter
  local (3.50) los trae; usarlos.
- En Git Bash de Windows `melos` es `melos.bat` (ver § 6); los scripts
  del repo se invocan desde PowerShell. Sin activación global alcanza con
  `dart run melos <cmd>` (melos es dev_dependency de la raíz). Ojo: usar
  el `dart` de `C:	oolslutterin`; un `dart` viejo en el PATH
  rompe la resolución.
- Pub workspaces exige SDK ≥ 3.6 en la raíz: el PR 1 sube el mínimo de
  `>=3.4.0` a `>=3.6.0` (sigue en estilo de formato corto; el formato
  "tall" llega con 3.7 y se decide aparte).
- Melos 8 cambió la sintaxis de scripts: el comando de un `exec` va en
  `exec.command`, no en `run` (si se mezclan, Melos rechaza el pubspec).

Pubspec raíz (solo configuración, no es una app):

```yaml
name: echoes_workspace   # PR 10; hasta entonces la raíz es la app
publish_to: none
environment:
  sdk: ^3.11.0
workspace:
  - games/*
  - apps/*
  - packages/*
dev_dependencies:
  melos: ^8.10.1
melos:
  repository: https://github.com/KarmaBlank/echos-del-tiempo
  scripts: { ... }   # § 6
```

## 2. Árbol objetivo

```
echos-del-tiempo/
├─ pubspec.yaml               # workspace + melos (sin app)
├─ analysis_options.yaml      # base común; cada miembro hace include
├─ games/
│  ├─ echoes/                  # app Flutter: lib/main_p2p.dart, main_dev,
│  │  ├─ lib/                 #   main_lan, (main_gallery queda en echoes_ui)
│  │  ├─ windows/             # runner propio (nombre exe, icono, AppId)
│  │  ├─ installer/           # ecos_del_tiempo.iss
│  │  ├─ assets/              # balance/echoes.json, datos propios del Mundo
│  │  └─ test/                # widget/integración del juego
│  └─ paradox/               # ídem: main_p2p (ex main_roguelike), main_dev
├─ apps/
│  ├─ echoes_editor/           # ex main_admin con edición Mundo
│  └─ paradox_editor/        # editor con catálogo/tuning de Travesía
├─ packages/
│  ├─ echoes_engine/            # Dart puro: modelos, reglas comunes, balance
│  ├─ echoes_combat/            # Dart puro: BattleEngine y satélites
│  ├─ echoes_worldgen/          # Dart puro: mapas, zonas, biomas
│  ├─ echoes_rules/            # Dart puro: session_engine y sistemas del Mundo
│  ├─ paradox_rules/         # Dart puro: run_engine, mapa de piso, ofertas
│  ├─ echoes_net/               # Dart puro: contratos + protocolo + loopback
│  ├─ echoes_net_lan/           # Dart (dart:io): LanNetSession
│  ├─ echoes_net_p2p/           # Flutter: WebRTC + señalización Firestore
│  ├─ echoes_platform/          # Flutter: settings, audio, persistencia, update, DI base
│  ├─ echoes_ui/                # Flutter: design system (design + theme + widgets) + galería
│  ├─ echoes_assets/            # Flutter: SpriteCatalog, Fx/Layout/Sfx catalogs + assets compartidos
│  ├─ echoes_features/          # Flutter: features compartidas (combat UI, inventory, …)
│  └─ echoes_editor_kit/        # Flutter: núcleo del editor (balance, sprites, fx, layouts)
└─ tool/                      # release.ps1 y utilidades (scripts del workspace)
```

Nombres con prefijo `echoes_` para que no choquen con paquetes de pub.dev.

## 3. Paquetes: responsabilidad y dependencias

| Paquete | Tipo | Responsabilidad | Depende de |
|---|---|---|---|
| `echoes_engine` | Dart | `game_engine/models`, `balance/`, `serialization/` comunes, `data/` compartida (elementos, armas, clases, skills, items, ULT, árbol de pasivas), `rules/` comunes (stats, pasivas, ítems, inventario, crafteo, progresión, `js_math`), `GameModeKind`, `GameCatalog`, `TuningCatalog` | `equatable`, `yaml`, `meta` |
| `echoes_combat` | Dart | `battle_engine*`, break, summons, ult, combo, companion AI, status, reacciones, `fx/cinematic_durations` | `echoes_engine` |
| `echoes_worldgen` | Dart | `world_engine`, `world_rules`, `zone_generators`, `biome_rules`, `light/sky/lantern`, `fog_of_war`, `game_map` | `echoes_engine` |
| `echoes_rules` | Dart | `session_engine*` (overworld, misiones, cofres, estatuas, tutorial, pesca, granja, bioma), pueblo, oficios, abismo, ascensión, atlas, hazañas | `echoes_engine`, `echoes_combat`, `echoes_worldgen` |
| `paradox_rules` | Dart | `run_engine` (hoy `session_engine_run`), `run_map_generator`, `run_rules`, `run_tuning`, `reward_offer_rules`, `run_boons`, `travesia_meta`, `run_save`, `run_json` | `echoes_engine`, `echoes_combat` |
| `echoes_net` | Dart | `netcode/contracts`, `protocol/` (`wire.dart`, `WireGame`, `ProtocolNetSession`), `loopback` | `echoes_engine` (DTO de acciones/eventos) |
| `echoes_net_lan` | Dart | `netcode/lan` | `echoes_net` |
| `echoes_net_p2p` | Flutter | `netcode/p2p_webrtc` (+ `firebase_bootstrap`) | `echoes_net`, `flutter_webrtc`, `cloud_firestore`, `firebase_core` |
| `echoes_platform` | Flutter | `core/settings`, `core/audio`, `core/persistence`, `core/perf`, `core/update`, `core/text`, `core/edition` (`GameEdition`, `ReleaseChannel` como **datos**; cada juego crea la suya), `service_locator` base (`registerSharedDependencies` sin conocer juegos), `FeatureFlags` | `echoes_engine`, `echoes_net`, `get_it`, `flutter_riverpod`, `audioplayers` |
| `echoes_assets` | Flutter | `SpriteCatalog`, `core/procedural`, `core/fx`, `core/layout`, `core/data` loaders, `BalanceAssetLoader` (ruta inyectada), y los assets **compartidos** (sprites, fx, sfx, layouts, fuentes, shaders) | `echoes_engine`, `yaml`, `flame` |
| `echoes_ui` | Flutter | `app/design`, `app/theme`, `app/widgets`, galería del DS | `echoes_assets`, `echoes_platform` (solo `text_detail`, `layout`) |
| `echoes_features` | Flutter | features compartidas: `combat`, `inventory`, `characters`, `passive_tree`, `build_planner`, `bestiary`, `achievements`, `settings`, `lobby` (sala genérica), `tutorial` | `echoes_ui`, `echoes_engine`, `echoes_combat`, `echoes_net`, `echoes_platform` |
| `echoes_editor_kit` | Flutter | `features/admin` sin lo específico de juego: balance, diff, impacto, sprites, fx, layouts, plantillas, monitoreo, release plan | `echoes_ui`, `echoes_engine`, `echoes_assets`, `archive`, `file_selector` |
| `games/echoes` | app | flavors, `world`, `missions`, `endgame`, `ascension` (UI del Mundo), cableado | todo lo anterior salvo `paradox_rules` |
| `games/paradox` | app | flavors, `features/run`, cableado | todo salvo `echoes_rules`, `echoes_worldgen` (si la run no usa mapas de mundo) |
| `apps/*_editor` | app | registra catálogo + tuning + balance de su juego en el kit | `echoes_editor_kit` + `<juego>_rules` |

Grafo (sin ciclos; las flechas apuntan a la dependencia):

```
echoes_engine ◄─ echoes_combat ◄─┬─ echoes_rules ◄──────────── games/echoes, apps/echoes_editor
     ▲   ▲        ▲          └─ paradox_rules ◄───────── games/paradox, apps/paradox_editor
     │   └─ echoes_worldgen ◄─ echoes_rules
     ├─ echoes_net ◄─ echoes_net_lan, echoes_net_p2p ◄─ games/*
     ├─ echoes_platform ◄─ echoes_assets ◄─ echoes_ui ◄─ echoes_features ◄─ games/*
     │                                      ▲
     └──────────────────────────────── echoes_editor_kit ◄─ apps/*
```

Reglas duras:

1. `echoes_engine`, `echoes_combat`, `echoes_worldgen`, `echoes_rules`,
   `paradox_rules`, `echoes_net` no declaran `flutter` (hoy ya se cumple:
   `lib/game_engine` no importa Flutter ni nada fuera de sí).
2. Ningún paquete importa `games/*` ni `apps/*`.
3. `echoes_rules` y `paradox_rules` no se importan entre sí. Lo que ambos
   necesiten baja a `echoes_engine`/`echoes_combat`.
4. Un test de arquitectura en `echoes_engine` (o un script melos) recorre
   los pubspec y falla si aparece una arista prohibida.

## 4. Qué va adónde (mapa desde `lib/`)

| Hoy | Destino |
|---|---|
| `lib/game_engine/models/*` (salvo los de abajo) | `echoes_engine` |
| `models/run_save`, `run_state`, `travesia_meta` | `paradox_rules` |
| `models/session_world`, `world_save`, `town_build`, `resident`, `farm_*`, `fish_line`, `atlas*`, `abyss`, `ascension`, `exploration` | `echoes_rules` |
| `models/game_map`, `fog_of_war`, `sky`, `zone_def` | `echoes_worldgen` |
| `game_engine/balance/*` | `echoes_engine` (el registro de juego se inyecta, § 5.2) |
| `game_engine/data/*` comunes | `echoes_engine` |
| `data/run_boons`, sección `TuningId.travesia` | `paradox_rules` |
| `data/abyss_*`, `ascension_*`, `construction`, `farming`, `fishing`, `life_tree`, `town_layout`, `npc_talk`, `missions`, `trials`, `vaults`, `exploration`, `biomes`, `zones`, `zone_curve`, `eco` | `echoes_rules` (o `echoes_worldgen` si es generación) |
| `game_engine/rules/battle_engine*`, `break`, `summon`, `ult`, `combo_planner`, `companion_ai`, `revive`, `weapon_target*`, `consumable` | `echoes_combat` |
| `rules/session_engine*` (salvo `_run`), pueblo, granja, pesca, oficios, misiones, abismo, ascensión, atlas, tutorial | `echoes_rules` |
| `rules/session_engine_run`, `run_*`, `reward_offer_rules` | `paradox_rules` |
| `rules/world_*`, `zone_*`, `biome_*`, `light_*`, `sky_*`, `lantern_*` | `echoes_worldgen` |
| resto de `rules/` (stats, pasivas, items, inventario, progresión, build*) | `echoes_engine` |
| `game_engine/serialization/*` | `echoes_engine`; `run_json` → `paradox_rules`; partes de mundo de `session_json` → `echoes_rules` |
| `game_engine/fx` | `echoes_combat` (duraciones) / `echoes_engine` (timeline) |
| `lib/netcode/contracts`, `protocol`, `loopback` | `echoes_net` |
| `lib/netcode/lan` | `echoes_net_lan` |
| `lib/netcode/p2p_webrtc` + `app/flavors/firebase_bootstrap.dart` + `firebase_options.dart` | `echoes_net_p2p` |
| `lib/netcode/dedicated_server`, `rollback` (README) | `packages/echoes_net_dedicated/`, `echoes_net_rollback/` cuando existan; hoy los README van a `docs/` |
| `lib/core/{settings,audio,persistence,perf,update,text,edition,di}` | `echoes_platform` |
| `lib/core/{procedural,fx,layout,data,balance}` | `echoes_assets` |
| `lib/app/{design,theme,widgets}` | `echoes_ui` |
| `lib/app/app.dart` (`EcosApp`) | `echoes_features` como `EchoesShell` parametrizable (home por juego) |
| `lib/app/feature_flags.dart` | `echoes_platform` |
| `lib/app/app_version.dart`, `travesia_version.dart` | `games/echoes/lib/version.dart`, `games/paradox/lib/version.dart` |
| `lib/app/flavors/main_p2p|dev|lan.dart` | `games/echoes/lib/` |
| `lib/app/flavors/main_roguelike.dart` | `games/paradox/lib/main_p2p.dart` (+ `main_dev`, `main_lan` nuevos) |
| `lib/app/flavors/main_admin.dart` | `apps/echoes_editor/lib/main.dart` y `apps/paradox_editor/lib/main.dart` |
| `lib/app/flavors/main_gallery.dart` | `packages/echoes_ui/example/` (galería del DS) |
| `lib/features/{combat,inventory,characters,passive_tree,build_planner,bestiary,achievements,settings,lobby,tutorial}` | `echoes_features` |
| `lib/features/{world,missions,endgame,ascension}` | `games/echoes` |
| `lib/features/run` | `games/paradox` |
| `lib/features/admin` | `echoes_editor_kit` (+ lo de cada juego en su editor) |
| `assets/sprites,fx,sfx,layouts,fonts`, `shaders/` | `packages/echoes_assets/assets/` (se cargan como `packages/echoes_assets/...`) |
| `assets/balance/balance.json` | `games/echoes/assets/balance/echoes.json`; Travesía estrena `paradox.json` |
| `assets/data/ults`, `enemy_ults`, `build_templates*` | `echoes_assets` mientras sean compartidos; copia por juego cuando § 7 de roguelike.md se aplique |
| `windows/`, `installer/` | uno por juego (`games/<game>/windows`, `games/<game>/installer`) y por editor |
| `test/game_engine/*` | junto a su paquete (`packages/<p>/test`) |
| `test/netcode`, `test/core`, `test/design`, `test/features`, `test/app` | junto al paquete o juego dueño del código |
| `test/helpers`, `test/support`, `test/real_fonts.dart` | `packages/echoes_test_support/` (dev_dependency, `publish_to: none`) |
| `tool/*.dart` | `tool/` raíz (paquete `echoes_tools` en el workspace si necesita imports) |
| `docs/` | se queda en la raíz |

## 5. Acoples encontrados

### 5.1 La run de Travesía vive dentro de `session_engine`

`session_engine.dart` tiene 4 097 líneas y `session_engine_run.dart`
(622) es un `part`/extensión del mismo motor: la run usa el estado, el
despacho de acciones y el arranque de batalla del Mundo. Para que
`paradox_rules` no dependa de `echoes_rules` hay que, **antes de mover
nada**, extraer lo común (armado de combatientes, botín, fin de batalla,
tienda, inventario, despacho de acciones de combate) a un
`CombatSessionCore` en `echoes_combat`/`echoes_engine`, y que
`session_engine` (Mundo) y un `RunEngine` (Travesía) lo compongan. Es lo
que ya pedía roguelike.md § 9.1 y es el paso más caro del plan.
`SessionPlayer` mezcla overworld y combate: se parte en
`CombatantState` (común) + `OverworldPlayerState` (Mundo).

### 5.2 Catálogos y balance compartidos

- `GameCatalog.standard` es único; `TuningCatalog` tiene una sección
  `TuningId.travesia` al lado de las del Mundo; hay **un** `balance.json`
  y `BalanceKind` mezcla tipos de ambos juegos. roguelike.md § 7 (datos
  separados por versión) **no está implementado**.
- Destino: `echoes_engine` define los tipos y un `CatalogRegistry`; cada
  `<juego>_rules` aporta su catálogo (`echoesCatalog`, `paradoxCatalog`)
  y sus `TuningId`; el composition root inyecta catálogo + tuning +
  balance. Ningún paquete compartido lee `GameCatalog.standard` global.
- `BalanceAssetLoader.assetPath` y `ReleasePlan.balancePath` están
  hardcodeados a `assets/balance/balance.json`: pasan a parámetro.

### 5.3 Edición, versión y canal resueltos en código común

`core/edition/game_edition.dart` importa `app_version.dart` **y**
`travesia_version.dart` y define las dos ediciones como constantes;
`wire.dart` define `WireGame.mundo` y `.travesia`; `ReleaseChannel`
también conoce ambos. En el monorepo el paquete común solo define la
clase; cada juego declara su `GameEdition`, su `WireGame` y su canal.
`service_locator.dart` importa `features/run`, `features/lobby`,
`features/characters` y elige stores según `GameModeKind`: se parte en
`registerPlatform()` (común) + `registerEchoes()` / `registerParadox()`
en cada juego.

### 5.4 `core` ↔ `app` ↔ `features`

- `app/design` importa `core/text` y `core/layout` (por eso `echoes_ui`
  depende de `echoes_platform`/`echoes_assets`).
- `core/di` importa `features/*` (invertido: lo resuelve 5.3).
- `features/admin/presentation/admin_controller.dart` e
  `impact_panel.dart` conocen `BalanceKind.travesia` y el filtro de tags
  de Mundo: se vuelven parámetros del editor de cada juego.

### 5.5 Assets

Flutter no comparte assets entre paquetes sin prefijo: dentro de
`echoes_assets` se leen como `packages/echoes_assets/assets/...`. Hay que
pasar todas las rutas por una sola constante (`EchoesAssets.root`), y el
`sprite_manifest.yaml`, `fx_manifest.yaml`, layouts y fuentes (familia
con `package:`) se cargan por esa ruta. El Editor **escribe** en esas
carpetas: su "ruta del repo" cambia a `packages/echoes_assets/assets/` (o
`games/<game>/assets/` para datos del juego). La lista de ~50 carpetas
de sprites del pubspec se muda al pubspec de `echoes_assets`.
Shaders (`crt.frag`) también se declaran en el paquete.

### 5.6 Runner de Windows y plugin registrants

`windows/` y `generated_plugin_registrant.*` son por app: cada app de
`games/` y `apps/` tiene su `windows/` (se generan con
`flutter create --platforms=windows .` y se copian los cambios del
runner actual: nombre del exe, icono, `Runner.rc`, manifest). El
registrant se regenera solo; los plugins (`flutter_webrtc`,
`audioplayers`, `file_selector`) solo aparecen en las apps que los
dependen. Hoy ambos juegos instalan `echos_del_tiempo.exe`; se puede
mantener o pasar a `echoes_paradox.exe` (pregunta § 10).

### 5.7 Goldens y tests

- 35 goldens en `test/design/goldens`, `test/features/{build_planner,
  characters,inventory}/goldens` dependen de las fuentes reales
  (`test/real_fonts.dart`) cargadas por ruta: tras mover fuentes a
  `echoes_assets` hay que actualizar el loader y **regenerar** con
  `--update-goldens` en el mismo PR, revisando el diff visual.
- Hay 72 PNG en `test/features/inventory/failures/` versionados (salida
  de goldens fallidos): borrar y agregar `**/failures/` al `.gitignore`.
- `tool/*_measure_test.dart` son mediciones, no tests: se excluyen del
  `melos run test` y van a un script aparte.
- 344 archivos de test; se reparten con el código. `echoes_test_support`
  da helpers comunes.

### 5.8 Firebase

`firebase_options.dart`, `firebase.json` y `firestore.rules` son del
proyecto de señalización compartido; van con `echoes_net_p2p` (opciones) y
la raíz (`firebase.json`, reglas). Las salas ya se separan por
`WireGame.id`.

## 6. Scripts de Melos

En `pubspec.yaml` raíz, clave `melos.scripts`, con la sintaxis de Melos 8
(`exec.command`). Lo que está hoy (PR 1, raíz = app con
`useRootAsPackage: true`):

| Script | Qué hace |
|---|---|
| `analyze` | `flutter analyze` en cada paquete |
| `format` / `format:fix` | `dart format` de `lib test tool` (chequeo / arreglo) |
| `test` | `flutter test` en cada paquete con `test/` (los `tool/*_measure_test` quedan fuera) |
| `goldens:update` | regenera goldens (`--tags golden`) |
| `measure` | corre las mediciones de `tool/*_measure_test.dart` |
| `arch` | `dart run tool/check_deps.dart`: **stub** hasta el PR 2 |

Ejemplo de forma:

```yaml
melos:
  useRootAsPackage: true          # se quita en el PR 10
  scripts:
    test:
      exec:
        command: flutter test
        concurrency: 1
        failFast: true
      packageFilters: { dirExists: test }
```

Se suman cuando haya paquetes: `test:dart` (`dart test`,
`packageFilters: { flutter: false }`), `test:flutter`, `test:pkg`,
`build:echoes` / `build:paradox` (`flutter build windows --release
-t lib/main_p2p.dart` con `scope`).

`format` hoy falla: 650 de 1015 archivos no están formateados en `main`
(deuda previa, ver `docs/tech_debt.md`). Formatear todo de una vez se
hace en un PR propio cuando no haya ramas abiertas.

Por paquete: `melos exec --scope=echoes_combat -- flutter test` o
`melos run test:flutter --scope=...`. Tests de un solo paquete se
pueden seguir corriendo con `flutter test` dentro de su carpeta.

Los tests Dart puros pasan a `package:test` (más rápido, sin binding de
Flutter); mientras tanto `flutter test` también funciona en paquetes sin
Flutter.

## 7. CI y releases

- **CI**: sin GitHub Actions por ahora (§ 0.2). Las verificaciones son
  locales: `tool/release.ps1` (analyze + test) y `melos run analyze`,
  `melos run arch`, `melos run test`. Si más adelante se suma CI, usar
  `--diff=origin/main` para correr solo lo afectado.
- **`tool/release.ps1`**: ya acepta `-Juego Mundo|Travesia` con prefijo
  de tag, `.iss`, archivo de versión y capturas propios. Cambios:
  - `-Juego` se resuelve a `games/<game>`: versión en
    `games/<game>/pubspec.yaml` (`version:` propio de cada juego, se
    termina el `travesia_version.dart` paralelo) y en
    `games/<game>/lib/version.dart` (generado).
  - `flutter build windows` corre **dentro** de `games/<game>`; la
    salida queda en `games/<game>/build/windows/x64/runner/Release`.
  - Tags: `vX.Y.Z` y `paradox-vX.Y.Z`. Mundo hoy usa `vX.Y.Z`:
    el actualizador del Mundo debe aceptar **ambos** prefijos durante la
    transición (instalaciones viejas buscan `releases/latest`), ver § 9.
  - Capturas: `docs/release_shots/<juego>-vX.Y.Z` y `<juego>-base`.
  - `-Juego` para editores: no se publican (uso interno); opcional
    `-Herramienta` más adelante.
  - Tabla de juegos en un `tool/games.json` (`id`, carpeta, prefijo de
    tag, `.iss`, setup, `--latest`) para que sumar un juego no toque el
    script.

## 8. Guardado, protocolo y versión por juego

Ya separado (distribution.md § "Dos juegos, un repo") y se conserva:

| | Mundo | Travesía |
|---|---|---|
| Versión | `games/echoes/pubspec.yaml` | `games/paradox/pubspec.yaml` |
| Tag | `vX.Y.Z` (antes `vX.Y.Z`) | `paradox-vX.Y.Z` |
| Datos | `%APPDATA%\EcosDelTiempo` | `%APPDATA%\EcosDelTiempo-Travesia` |
| Protocolo | `WireGame('mundo', kMundoProtocol)` en `games/echoes` | `WireGame('travesia', kTravesiaProtocol)` en `games/paradox` |
| Balance | `echoes.json` | `paradox.json` |
| AppId instalador | sin cambio | sin cambio |

- `echoes_net` define `WireGame` y el handshake (`g` + versión); cada juego
  define su constante de protocolo. Un cambio de protocolo de un paquete
  compartido (p. ej. DTO de combate) **sube ambas**: el test de
  protocolo vive en `echoes_net` y cada juego tiene un test que fija su
  número esperado.
- Guardados: el formato serializado de lo común (personaje, inventario)
  lleva `schema` por juego; los migradores viven en `<juego>_rules`.
  Mover código no cambia el JSON (test de ida y vuelta con fixtures
  actuales antes y después de cada PR de movimiento).
- Las rutas de datos, el `ExitGuard` y el `GameDataGuard` las configura
  la `GameEdition` del juego; el paquete común no conoce nombres.

## 9. Migración en PRs pequeños

Cada PR deja `flutter build windows` de ambos juegos y todos los tests
verdes. Hasta el PR 10 la app sigue en la raíz; los paquetes se agregan
como miembros del workspace y la app raíz los consume.

| # | PR | Contenido | Estimación |
|---|---|---|---|
| 0 | Esperar al motor | Arranca cuando termine el trabajo en curso sobre el motor; congelar `session_engine` mientras dura el PR 3 | — |
| 1 | Workspace (**hecho**, rama `chore/monorepo-step1`) | Pubspec raíz con `workspace: []` + `melos:` (`useRootAsPackage: true`, la app no se mueve hasta el PR 10); SDK mínimo 3.6; scripts analyze/format/test/goldens/measure/arch (stub); borrar `test/**/failures` y `**/failures/` al `.gitignore`. Sin CI (§ 0.2) | 0,5 d |
| 2 | `echoes_engine` + `echoes_net` (copia literal) | Mover `game_engine/` y `netcode/{contracts,protocol,loopback}` tal cual a paquetes; reemplazar imports relativos por `package:`; sin cambios de lógica. Script `arch` | 1–1,5 d |
| 3 | Desacople del Mundo/Travesía en el motor | `CombatSessionCore` extraído de `session_engine`; `RunEngine` propio; `SessionPlayer` partido; catálogo y tuning por juego inyectados (§ 5.2). Tests de ida y vuelta de saves y protocolo sin cambios | 4–6 d (el grande; se puede partir en 3a combate común, 3b run engine, 3c catálogos) |
| 4 | Partir el motor | `echoes_engine` → `echoes_engine` + `echoes_combat` + `echoes_worldgen` + `echoes_rules` + `paradox_rules` según § 4 | 1–1,5 d |
| 5 | Red concreta | `echoes_net_lan`, `echoes_net_p2p` (+ firebase) | 0,5 d |
| 6 | `echoes_platform` | `core/` sin assets; `GameEdition`, `WireGame` y `ReleaseChannel` dejan de nombrar juegos; `service_locator` partido | 1–1,5 d |
| 7 | `echoes_assets` | Catálogos de sprites/fx/layouts/sfx + carpetas de assets + fuentes + shaders con prefijo `packages/echoes_assets`; Editor escribe en la ruta nueva; regenerar goldens | 1,5–2 d |
| 8 | `echoes_ui` | design + theme + widgets + galería como `example/` | 1 d |
| 9 | `echoes_features` | features compartidas + `EchoesShell` | 1,5–2 d |
| 10 | `games/echoes` y `games/paradox` | Mover la app raíz a `games/echoes` (con `windows/`, `installer/`, flavors, features propias); crear `games/paradox` con su runner e instalador; balance `echoes.json`/`paradox.json`; raíz queda solo workspace | 1,5–2 d |
| 11 | Editores | `echoes_editor_kit` + `apps/echoes_editor` + `apps/paradox_editor` (selector de versión de roguelike.md § 11.9 resuelto por app) | 1,5–2 d |
| 12 | Release | `release.ps1` por carpeta de juego + `tool/games.json`, tags `v*`, actualizador del Mundo acepta `v*` y `v*`, sin CI (§ 0.2); ensayo `-DryRun` de los dos | 1 d |
| 13 | Limpieza | `CLAUDE.md`, distribution.md, netcode.md, roguelike.md § 9 actualizados; `dart test` para paquetes puros | 0,5 d |

Total estimado: **17–23 días de trabajo** de un agente/persona, en ~13
PRs. Los PR 2, 4–9 son mecánicos (mover + imports) y conviene hacerlos
sin otra rama tocando las mismas carpetas; el 3 es el único con riesgo
de lógica.

## 10. Riesgos y preguntas abiertas para el dueño

Riesgos:

- **Conflictos de merge**: cada PR de movimiento toca cientos de imports.
  Mitigación: PRs cortos, mergear rápido, avisar antes y no tener ramas
  de features largas en paralelo.
- **PR 3** cambia la estructura del motor más grande; un error rompe
  guardados o el protocolo. Mitigación: fixtures de saves y trazas de
  red actuales como tests de regresión antes de empezar.
- **Assets con prefijo de paquete**: cualquier ruta hardcodeada que se
  escape falla en ejecución, no en compilación. Mitigación: una sola
  constante + test que carga todos los manifests.
- **Actualizador del Mundo**: cambiar el tag a `v*` puede dejar a
  instalaciones viejas sin ver releases nuevos si `/releases/latest` deja
  de apuntar al Mundo. Mitigación: seguir marcando el release del Mundo
  como `latest` y aceptar ambos prefijos.
- **Builds de Windows**: dos runners para mantener; los cambios al
  runner (ventana, cierre con guardado) hay que replicarlos o
  generarlos desde una plantilla.
- **Tiempo de verificación local**: 344 tests + 2 builds; si se suma CI, usar `--diff` en PRs.

Preguntas: resueltas por defecto en § 0.2 (el dueño puede cambiarlas).
