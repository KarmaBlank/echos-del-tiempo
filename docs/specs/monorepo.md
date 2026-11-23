# Monorepo de juegos Ecos del Tiempo (Melos)

Estado: **spec + plan de migración**. Nada se mueve todavía (otro trabajo
está cambiando el motor). Base: `main` en v0.33.1 (Mundo) / Travesía
v0.3.x.

## 0. Decisión del dueño

El repo deja de ser "una app con dos flavors" y pasa a ser un **monorepo
de juegos Ecos del Tiempo** que comparten paquetes:

- `games/` — una app Flutter por juego (hoy `mundo` y `travesia`). Cada
  juego es un composition root con sus flavors (p2p, dev, lan…) y elige
  qué paquetes y qué lógica cablea. Los paquetes son un "recetario".
- `apps/` — herramientas: un editor por juego (`mundo_editor`,
  `travesia_editor`). Sumar un juego suma su editor.
- `packages/` — paquetes compartidos, Dart puro o Flutter.

Las decisiones de `CLAUDE.md` siguen vigentes (Clean Architecture,
Feature-First, `NetSession` como única puerta a la red, motor en Dart
puro, sprites por manifest, SDD). El monorepo las convierte en límites
que el compilador hace cumplir: un paquete Dart puro no puede importar
Flutter porque no lo declara.

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
  del repo se invocan desde PowerShell.

Pubspec raíz (solo configuración, no es una app):

```yaml
name: ecos_workspace
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
│  ├─ mundo/                  # app Flutter: lib/main_p2p.dart, main_dev,
│  │  ├─ lib/                 #   main_lan, (main_gallery queda en ecos_ui)
│  │  ├─ windows/             # runner propio (nombre exe, icono, AppId)
│  │  ├─ installer/           # ecos_del_tiempo.iss
│  │  ├─ assets/              # balance/mundo.json, datos propios del Mundo
│  │  └─ test/                # widget/integración del juego
│  └─ travesia/               # ídem: main_p2p (ex main_roguelike), main_dev
├─ apps/
│  ├─ mundo_editor/           # ex main_admin con edición Mundo
│  └─ travesia_editor/        # editor con catálogo/tuning de Travesía
├─ packages/
│  ├─ ecos_engine/            # Dart puro: modelos, reglas comunes, balance
│  ├─ ecos_combat/            # Dart puro: BattleEngine y satélites
│  ├─ ecos_worldgen/          # Dart puro: mapas, zonas, biomas
│  ├─ mundo_rules/            # Dart puro: session_engine y sistemas del Mundo
│  ├─ travesia_rules/         # Dart puro: run_engine, mapa de piso, ofertas
│  ├─ ecos_net/               # Dart puro: contratos + protocolo + loopback
│  ├─ ecos_net_lan/           # Dart (dart:io): LanNetSession
│  ├─ ecos_net_p2p/           # Flutter: WebRTC + señalización Firestore
│  ├─ ecos_platform/          # Flutter: settings, audio, persistencia, update, DI base
│  ├─ ecos_ui/                # Flutter: design system (design + theme + widgets) + galería
│  ├─ ecos_assets/            # Flutter: SpriteCatalog, Fx/Layout/Sfx catalogs + assets compartidos
│  ├─ ecos_features/          # Flutter: features compartidas (combat UI, inventory, …)
│  └─ ecos_editor_kit/        # Flutter: núcleo del editor (balance, sprites, fx, layouts)
└─ tool/                      # release.ps1 y utilidades (scripts del workspace)
```

Nombres con prefijo `ecos_` para que no choquen con paquetes de pub.dev.

## 3. Paquetes: responsabilidad y dependencias

| Paquete | Tipo | Responsabilidad | Depende de |
|---|---|---|---|
| `ecos_engine` | Dart | `game_engine/models`, `balance/`, `serialization/` comunes, `data/` compartida (elementos, armas, clases, skills, items, ULT, árbol de pasivas), `rules/` comunes (stats, pasivas, ítems, inventario, crafteo, progresión, `js_math`), `GameModeKind`, `GameCatalog`, `TuningCatalog` | `equatable`, `yaml`, `meta` |
| `ecos_combat` | Dart | `battle_engine*`, break, summons, ult, combo, companion AI, status, reacciones, `fx/cinematic_durations` | `ecos_engine` |
| `ecos_worldgen` | Dart | `world_engine`, `world_rules`, `zone_generators`, `biome_rules`, `light/sky/lantern`, `fog_of_war`, `game_map` | `ecos_engine` |
| `mundo_rules` | Dart | `session_engine*` (overworld, misiones, cofres, estatuas, tutorial, pesca, granja, bioma), pueblo, oficios, abismo, ascensión, atlas, hazañas | `ecos_engine`, `ecos_combat`, `ecos_worldgen` |
| `travesia_rules` | Dart | `run_engine` (hoy `session_engine_run`), `run_map_generator`, `run_rules`, `run_tuning`, `reward_offer_rules`, `run_boons`, `travesia_meta`, `run_save`, `run_json` | `ecos_engine`, `ecos_combat` |
| `ecos_net` | Dart | `netcode/contracts`, `protocol/` (`wire.dart`, `WireGame`, `ProtocolNetSession`), `loopback` | `ecos_engine` (DTO de acciones/eventos) |
| `ecos_net_lan` | Dart | `netcode/lan` | `ecos_net` |
| `ecos_net_p2p` | Flutter | `netcode/p2p_webrtc` (+ `firebase_bootstrap`) | `ecos_net`, `flutter_webrtc`, `cloud_firestore`, `firebase_core` |
| `ecos_platform` | Flutter | `core/settings`, `core/audio`, `core/persistence`, `core/perf`, `core/update`, `core/text`, `core/edition` (`GameEdition`, `ReleaseChannel` como **datos**; cada juego crea la suya), `service_locator` base (`registerSharedDependencies` sin conocer juegos), `FeatureFlags` | `ecos_engine`, `ecos_net`, `get_it`, `flutter_riverpod`, `audioplayers` |
| `ecos_assets` | Flutter | `SpriteCatalog`, `core/procedural`, `core/fx`, `core/layout`, `core/data` loaders, `BalanceAssetLoader` (ruta inyectada), y los assets **compartidos** (sprites, fx, sfx, layouts, fuentes, shaders) | `ecos_engine`, `yaml`, `flame` |
| `ecos_ui` | Flutter | `app/design`, `app/theme`, `app/widgets`, galería del DS | `ecos_assets`, `ecos_platform` (solo `text_detail`, `layout`) |
| `ecos_features` | Flutter | features compartidas: `combat`, `inventory`, `characters`, `passive_tree`, `build_planner`, `bestiary`, `achievements`, `settings`, `lobby` (sala genérica), `tutorial` | `ecos_ui`, `ecos_engine`, `ecos_combat`, `ecos_net`, `ecos_platform` |
| `ecos_editor_kit` | Flutter | `features/admin` sin lo específico de juego: balance, diff, impacto, sprites, fx, layouts, plantillas, monitoreo, release plan | `ecos_ui`, `ecos_engine`, `ecos_assets`, `archive`, `file_selector` |
| `games/mundo` | app | flavors, `world`, `missions`, `endgame`, `ascension` (UI del Mundo), cableado | todo lo anterior salvo `travesia_rules` |
| `games/travesia` | app | flavors, `features/run`, cableado | todo salvo `mundo_rules`, `ecos_worldgen` (si la run no usa mapas de mundo) |
| `apps/*_editor` | app | registra catálogo + tuning + balance de su juego en el kit | `ecos_editor_kit` + `<juego>_rules` |

Grafo (sin ciclos; las flechas apuntan a la dependencia):

```
ecos_engine ◄─ ecos_combat ◄─┬─ mundo_rules ◄──────────── games/mundo, apps/mundo_editor
     ▲   ▲        ▲          └─ travesia_rules ◄───────── games/travesia, apps/travesia_editor
     │   └─ ecos_worldgen ◄─ mundo_rules
     ├─ ecos_net ◄─ ecos_net_lan, ecos_net_p2p ◄─ games/*
     ├─ ecos_platform ◄─ ecos_assets ◄─ ecos_ui ◄─ ecos_features ◄─ games/*
     │                                      ▲
     └──────────────────────────────── ecos_editor_kit ◄─ apps/*
```

Reglas duras:

1. `ecos_engine`, `ecos_combat`, `ecos_worldgen`, `mundo_rules`,
   `travesia_rules`, `ecos_net` no declaran `flutter` (hoy ya se cumple:
   `lib/game_engine` no importa Flutter ni nada fuera de sí).
2. Ningún paquete importa `games/*` ni `apps/*`.
3. `mundo_rules` y `travesia_rules` no se importan entre sí. Lo que ambos
   necesiten baja a `ecos_engine`/`ecos_combat`.
4. Un test de arquitectura en `ecos_engine` (o un script melos) recorre
   los pubspec y falla si aparece una arista prohibida.

## 4. Qué va adónde (mapa desde `lib/`)

| Hoy | Destino |
|---|---|
| `lib/game_engine/models/*` (salvo los de abajo) | `ecos_engine` |
| `models/run_save`, `run_state`, `travesia_meta` | `travesia_rules` |
| `models/session_world`, `world_save`, `town_build`, `resident`, `farm_*`, `fish_line`, `atlas*`, `abyss`, `ascension`, `exploration` | `mundo_rules` |
| `models/game_map`, `fog_of_war`, `sky`, `zone_def` | `ecos_worldgen` |
| `game_engine/balance/*` | `ecos_engine` (el registro de juego se inyecta, § 5.2) |
| `game_engine/data/*` comunes | `ecos_engine` |
| `data/run_boons`, sección `TuningId.travesia` | `travesia_rules` |
| `data/abyss_*`, `ascension_*`, `construction`, `farming`, `fishing`, `life_tree`, `town_layout`, `npc_talk`, `missions`, `trials`, `vaults`, `exploration`, `biomes`, `zones`, `zone_curve`, `eco` | `mundo_rules` (o `ecos_worldgen` si es generación) |
| `game_engine/rules/battle_engine*`, `break`, `summon`, `ult`, `combo_planner`, `companion_ai`, `revive`, `weapon_target*`, `consumable` | `ecos_combat` |
| `rules/session_engine*` (salvo `_run`), pueblo, granja, pesca, oficios, misiones, abismo, ascensión, atlas, tutorial | `mundo_rules` |
| `rules/session_engine_run`, `run_*`, `reward_offer_rules` | `travesia_rules` |
| `rules/world_*`, `zone_*`, `biome_*`, `light_*`, `sky_*`, `lantern_*` | `ecos_worldgen` |
| resto de `rules/` (stats, pasivas, items, inventario, progresión, build*) | `ecos_engine` |
| `game_engine/serialization/*` | `ecos_engine`; `run_json` → `travesia_rules`; partes de mundo de `session_json` → `mundo_rules` |
| `game_engine/fx` | `ecos_combat` (duraciones) / `ecos_engine` (timeline) |
| `lib/netcode/contracts`, `protocol`, `loopback` | `ecos_net` |
| `lib/netcode/lan` | `ecos_net_lan` |
| `lib/netcode/p2p_webrtc` + `app/flavors/firebase_bootstrap.dart` + `firebase_options.dart` | `ecos_net_p2p` |
| `lib/netcode/dedicated_server`, `rollback` (README) | `packages/ecos_net_dedicated/`, `ecos_net_rollback/` cuando existan; hoy los README van a `docs/` |
| `lib/core/{settings,audio,persistence,perf,update,text,edition,di}` | `ecos_platform` |
| `lib/core/{procedural,fx,layout,data,balance}` | `ecos_assets` |
| `lib/app/{design,theme,widgets}` | `ecos_ui` |
| `lib/app/app.dart` (`EcosApp`) | `ecos_features` como `EcosShell` parametrizable (home por juego) |
| `lib/app/feature_flags.dart` | `ecos_platform` |
| `lib/app/app_version.dart`, `travesia_version.dart` | `games/mundo/lib/version.dart`, `games/travesia/lib/version.dart` |
| `lib/app/flavors/main_p2p|dev|lan.dart` | `games/mundo/lib/` |
| `lib/app/flavors/main_roguelike.dart` | `games/travesia/lib/main_p2p.dart` (+ `main_dev`, `main_lan` nuevos) |
| `lib/app/flavors/main_admin.dart` | `apps/mundo_editor/lib/main.dart` y `apps/travesia_editor/lib/main.dart` |
| `lib/app/flavors/main_gallery.dart` | `packages/ecos_ui/example/` (galería del DS) |
| `lib/features/{combat,inventory,characters,passive_tree,build_planner,bestiary,achievements,settings,lobby,tutorial}` | `ecos_features` |
| `lib/features/{world,missions,endgame,ascension}` | `games/mundo` |
| `lib/features/run` | `games/travesia` |
| `lib/features/admin` | `ecos_editor_kit` (+ lo de cada juego en su editor) |
| `assets/sprites,fx,sfx,layouts,fonts`, `shaders/` | `packages/ecos_assets/assets/` (se cargan como `packages/ecos_assets/...`) |
| `assets/balance/balance.json` | `games/mundo/assets/balance/mundo.json`; Travesía estrena `travesia.json` |
| `assets/data/ults`, `enemy_ults`, `build_templates*` | `ecos_assets` mientras sean compartidos; copia por juego cuando § 7 de roguelike.md se aplique |
| `windows/`, `installer/` | uno por juego (`games/<juego>/windows`, `games/<juego>/installer`) y por editor |
| `test/game_engine/*` | junto a su paquete (`packages/<p>/test`) |
| `test/netcode`, `test/core`, `test/design`, `test/features`, `test/app` | junto al paquete o juego dueño del código |
| `test/helpers`, `test/support`, `test/real_fonts.dart` | `packages/ecos_test_support/` (dev_dependency, `publish_to: none`) |
| `tool/*.dart` | `tool/` raíz (paquete `ecos_tools` en el workspace si necesita imports) |
| `docs/` | se queda en la raíz |

## 5. Acoples encontrados

### 5.1 La run de Travesía vive dentro de `session_engine`

`session_engine.dart` tiene 4 097 líneas y `session_engine_run.dart`
(622) es un `part`/extensión del mismo motor: la run usa el estado, el
despacho de acciones y el arranque de batalla del Mundo. Para que
`travesia_rules` no dependa de `mundo_rules` hay que, **antes de mover
nada**, extraer lo común (armado de combatientes, botín, fin de batalla,
tienda, inventario, despacho de acciones de combate) a un
`CombatSessionCore` en `ecos_combat`/`ecos_engine`, y que
`session_engine` (Mundo) y un `RunEngine` (Travesía) lo compongan. Es lo
que ya pedía roguelike.md § 9.1 y es el paso más caro del plan.
`SessionPlayer` mezcla overworld y combate: se parte en
`CombatantState` (común) + `OverworldPlayerState` (Mundo).

### 5.2 Catálogos y balance compartidos

- `GameCatalog.standard` es único; `TuningCatalog` tiene una sección
  `TuningId.travesia` al lado de las del Mundo; hay **un** `balance.json`
  y `BalanceKind` mezcla tipos de ambos juegos. roguelike.md § 7 (datos
  separados por versión) **no está implementado**.
- Destino: `ecos_engine` define los tipos y un `CatalogRegistry`; cada
  `<juego>_rules` aporta su catálogo (`mundoCatalog`, `travesiaCatalog`)
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
`registerPlatform()` (común) + `registerMundo()` / `registerTravesia()`
en cada juego.

### 5.4 `core` ↔ `app` ↔ `features`

- `app/design` importa `core/text` y `core/layout` (por eso `ecos_ui`
  depende de `ecos_platform`/`ecos_assets`).
- `core/di` importa `features/*` (invertido: lo resuelve 5.3).
- `features/admin/presentation/admin_controller.dart` e
  `impact_panel.dart` conocen `BalanceKind.travesia` y el filtro de tags
  de Mundo: se vuelven parámetros del editor de cada juego.

### 5.5 Assets

Flutter no comparte assets entre paquetes sin prefijo: dentro de
`ecos_assets` se leen como `packages/ecos_assets/assets/...`. Hay que
pasar todas las rutas por una sola constante (`EcosAssets.root`), y el
`sprite_manifest.yaml`, `fx_manifest.yaml`, layouts y fuentes (familia
con `package:`) se cargan por esa ruta. El Editor **escribe** en esas
carpetas: su "ruta del repo" cambia a `packages/ecos_assets/assets/` (o
`games/<juego>/assets/` para datos del juego). La lista de ~50 carpetas
de sprites del pubspec se muda al pubspec de `ecos_assets`.
Shaders (`crt.frag`) también se declaran en el paquete.

### 5.6 Runner de Windows y plugin registrants

`windows/` y `generated_plugin_registrant.*` son por app: cada app de
`games/` y `apps/` tiene su `windows/` (se generan con
`flutter create --platforms=windows .` y se copian los cambios del
runner actual: nombre del exe, icono, `Runner.rc`, manifest). El
registrant se regenera solo; los plugins (`flutter_webrtc`,
`audioplayers`, `file_selector`) solo aparecen en las apps que los
dependen. Hoy ambos juegos instalan `echos_del_tiempo.exe`; se puede
mantener o pasar a `ecos_travesia.exe` (pregunta § 10).

### 5.7 Goldens y tests

- 35 goldens en `test/design/goldens`, `test/features/{build_planner,
  characters,inventory}/goldens` dependen de las fuentes reales
  (`test/real_fonts.dart`) cargadas por ruta: tras mover fuentes a
  `ecos_assets` hay que actualizar el loader y **regenerar** con
  `--update-goldens` en el mismo PR, revisando el diff visual.
- Hay 72 PNG en `test/features/inventory/failures/` versionados (salida
  de goldens fallidos): borrar y agregar `**/failures/` al `.gitignore`.
- `tool/*_measure_test.dart` son mediciones, no tests: se excluyen del
  `melos run test` y van a un script aparte.
- 344 archivos de test; se reparten con el código. `ecos_test_support`
  da helpers comunes.

### 5.8 Firebase

`firebase_options.dart`, `firebase.json` y `firestore.rules` son del
proyecto de señalización compartido; van con `ecos_net_p2p` (opciones) y
la raíz (`firebase.json`, reglas). Las salas ya se separan por
`WireGame.id`.

## 6. Scripts de Melos

En `pubspec.yaml` raíz, clave `melos.scripts`:

```yaml
melos:
  scripts:
    analyze:
      run: dart analyze --fatal-infos .
      exec: { concurrency: 4 }
    format:
      run: dart format --set-exit-if-changed .
    format:fix:
      run: dart format .
    test:
      description: Tests de todo el workspace (Dart puro con dart test, Flutter con flutter test).
      run: melos run test:dart && melos run test:flutter
    test:dart:
      run: dart test
      exec: { concurrency: 4, failFast: true }
      packageFilters: { flutter: false, dirExists: test }
    test:flutter:
      run: flutter test
      exec: { concurrency: 2, failFast: true }
      packageFilters: { flutter: true, dirExists: test }
    test:pkg:
      description: "melos run test:pkg -- <paquete>  (vía --scope)"
      run: flutter test
      exec: { concurrency: 1 }
    goldens:update:
      run: flutter test --update-goldens --tags golden
      exec: { concurrency: 1 }
      packageFilters: { dirExists: test }
    arch:
      description: Falla si el grafo de dependencias rompe § 3.
      run: dart run tool/check_deps.dart
    build:mundo:
      run: flutter build windows --release -t lib/main_p2p.dart
      exec: { concurrency: 1 }
      packageFilters: { scope: mundo }
    build:travesia:
      run: flutter build windows --release -t lib/main_p2p.dart
      exec: { concurrency: 1 }
      packageFilters: { scope: travesia }
```

Por paquete: `melos exec --scope=ecos_combat -- flutter test` o
`melos run test:flutter --scope=...`. Tests de un solo paquete se
pueden seguir corriendo con `flutter test` dentro de su carpeta.

Los tests Dart puros pasan a `package:test` (más rápido, sin binding de
Flutter); mientras tanto `flutter test` también funciona en paquetes sin
Flutter.

## 7. CI y releases

- **CI** (nuevo `.github/workflows/ci.yml`, hoy no hay): runner Windows,
  `flutter pub get`, `dart pub global activate melos`, `melos run
  format`, `melos run analyze`, `melos run arch`, `melos run test`. Con
  `--diff=origin/main` (filtro de Melos) para correr solo lo afectado en
  PRs y todo en `main`.
- **`tool/release.ps1`**: ya acepta `-Juego Mundo|Travesia` con prefijo
  de tag, `.iss`, archivo de versión y capturas propios. Cambios:
  - `-Juego` se resuelve a `games/<juego>`: versión en
    `games/<juego>/pubspec.yaml` (`version:` propio de cada juego, se
    termina el `travesia_version.dart` paralelo) y en
    `games/<juego>/lib/version.dart` (generado).
  - `flutter build windows` corre **dentro** de `games/<juego>`; la
    salida queda en `games/<juego>/build/windows/x64/runner/Release`.
  - Tags: `mundo-vX.Y.Z` y `travesia-vX.Y.Z`. Mundo hoy usa `vX.Y.Z`:
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
| Versión | `games/mundo/pubspec.yaml` | `games/travesia/pubspec.yaml` |
| Tag | `mundo-vX.Y.Z` (antes `vX.Y.Z`) | `travesia-vX.Y.Z` |
| Datos | `%APPDATA%\EcosDelTiempo` | `%APPDATA%\EcosDelTiempo-Travesia` |
| Protocolo | `WireGame('mundo', kMundoProtocol)` en `games/mundo` | `WireGame('travesia', kTravesiaProtocol)` en `games/travesia` |
| Balance | `mundo.json` | `travesia.json` |
| AppId instalador | sin cambio | sin cambio |

- `ecos_net` define `WireGame` y el handshake (`g` + versión); cada juego
  define su constante de protocolo. Un cambio de protocolo de un paquete
  compartido (p. ej. DTO de combate) **sube ambas**: el test de
  protocolo vive en `ecos_net` y cada juego tiene un test que fija su
  número esperado.
- Guardados: el formato serializado de lo común (personaje, inventario)
  lleva `schema` por juego; los migradores viven en `<juego>_rules`.
  Mover código no cambia el JSON (test de ida y vuelta con fixtures
  actuales antes y después de cada PR de movimiento).
- Las rutas de datos, el `ExitGuard` y el `GameDataGuard` las configura
  la `GameEdition` del juego; el paquete común no conoce nombres.

## 9. Migración en PRs pequeños

Cada PR deja `flutter build windows` de ambos juegos y todos los tests
verdes. Hasta el PR 4 la app sigue en la raíz; los paquetes se agregan
como miembros del workspace y la app raíz los consume.

| # | PR | Contenido | Estimación |
|---|---|---|---|
| 0 | Esperar al motor | Arranca cuando termine el trabajo en curso sobre el motor; congelar `session_engine` mientras dura el PR 3 | — |
| 1 | Workspace | Pubspec raíz con `workspace:` + `melos:`, la app actual pasa a ser miembro **sin moverla** (`useRootAsPackage` o mover a `games/mundo` en el PR 4); scripts analyze/test/format; CI básico; borrar `test/**/failures` | 0,5 d |
| 2 | `ecos_engine` + `ecos_net` (copia literal) | Mover `game_engine/` y `netcode/{contracts,protocol,loopback}` tal cual a paquetes; reemplazar imports relativos por `package:`; sin cambios de lógica. Script `arch` | 1–1,5 d |
| 3 | Desacople del Mundo/Travesía en el motor | `CombatSessionCore` extraído de `session_engine`; `RunEngine` propio; `SessionPlayer` partido; catálogo y tuning por juego inyectados (§ 5.2). Tests de ida y vuelta de saves y protocolo sin cambios | 4–6 d (el grande; se puede partir en 3a combate común, 3b run engine, 3c catálogos) |
| 4 | Partir el motor | `ecos_engine` → `ecos_engine` + `ecos_combat` + `ecos_worldgen` + `mundo_rules` + `travesia_rules` según § 4 | 1–1,5 d |
| 5 | Red concreta | `ecos_net_lan`, `ecos_net_p2p` (+ firebase) | 0,5 d |
| 6 | `ecos_platform` | `core/` sin assets; `GameEdition`, `WireGame` y `ReleaseChannel` dejan de nombrar juegos; `service_locator` partido | 1–1,5 d |
| 7 | `ecos_assets` | Catálogos de sprites/fx/layouts/sfx + carpetas de assets + fuentes + shaders con prefijo `packages/ecos_assets`; Editor escribe en la ruta nueva; regenerar goldens | 1,5–2 d |
| 8 | `ecos_ui` | design + theme + widgets + galería como `example/` | 1 d |
| 9 | `ecos_features` | features compartidas + `EcosShell` | 1,5–2 d |
| 10 | `games/mundo` y `games/travesia` | Mover la app raíz a `games/mundo` (con `windows/`, `installer/`, flavors, features propias); crear `games/travesia` con su runner e instalador; balance `mundo.json`/`travesia.json`; raíz queda solo workspace | 1,5–2 d |
| 11 | Editores | `ecos_editor_kit` + `apps/mundo_editor` + `apps/travesia_editor` (selector de versión de roguelike.md § 11.9 resuelto por app) | 1,5–2 d |
| 12 | Release y CI | `release.ps1` por carpeta de juego + `tool/games.json`, tags `mundo-v*`, actualizador del Mundo acepta `v*` y `mundo-v*`, CI con builds de ambos juegos; ensayo `-DryRun` de los dos | 1 d |
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
- **Actualizador del Mundo**: cambiar el tag a `mundo-v*` puede dejar a
  instalaciones viejas sin ver releases nuevos si `/releases/latest` deja
  de apuntar al Mundo. Mitigación: seguir marcando el release del Mundo
  como `latest` y aceptar ambos prefijos.
- **Builds de Windows**: dos runners para mantener; los cambios al
  runner (ventana, cierre con guardado) hay que replicarlos o
  generarlos desde una plantilla.
- **Tiempo de CI**: 344 tests + 2 builds; usar `--diff` en PRs.

Preguntas:

1. ¿Tag del Mundo pasa a `mundo-vX.Y.Z` o se queda en `vX.Y.Z` para no
   tocar el actualizador de las instalaciones existentes?
2. ¿Los arts (sprites, fx, sfx) quedan **un solo** `ecos_assets`
   compartido, o cada juego puede tener sprites propios encima
   (`games/<juego>/assets` con prioridad en `SpriteCatalog`)?
3. ¿Catálogo de Travesía como copia independiente ya en el PR 3
   (roguelike.md § 7) o primero se separa la estructura y la copia va
   después?
4. ¿Nombre del ejecutable de Travesía: se queda `echos_del_tiempo.exe` o
   pasa a `ecos_travesia.exe`?
5. ¿`lobby` (sala) es compartido o cada juego tiene su pantalla de sala?
6. ¿Los editores se publican (instalador/tag propio) o son solo internos
   y se corren desde el repo?
7. ¿Se crea CI en GitHub Actions (runner Windows, minutos de pago en
   privados) o se mantiene la verificación local en `release.ps1`?
8. ¿Prefijo de paquetes `ecos_` OK, o otro?
