# Ecos del Tiempo (Flutter)

Co-op JRPG táctico por turnos, P2P entre amigos. Puerto a Flutter del
prototipo original (`ecos-del-tiempo.html`, single-file JS) con Clean
Architecture + Feature-First, y un netcode agnóstico pensado para poder
evolucionar sin reescribir el juego.

## Cómo correrlo

```
fvm flutter pub get
fvm flutter run -t lib/app/flavors/main_p2p.dart   # build normal P2P
fvm flutter run -t lib/app/flavors/main_dev.dart   # build de desarrollo (roster completo, debug)
fvm flutter test                                    # tests de game_engine (puro Dart, sin UI)
```

(Reemplazá `fvm flutter` por `flutter` si no usás Flutter Version Manager.)

## Arquitectura

```
lib/
  core/           # DI (get_it), utils, errores
  game_engine/    # Lógica de juego PURA — sin Flutter, sin red.
                  # 100% testeable con `flutter test` solo.
  features/       # Feature-First: combat, passive_tree, missions, inventory, lobby
                  #   cada una con domain/ (reglas+casos de uso), data/, presentation/
  netcode/
    contracts/        # NetSession — la interfaz que TODO lo demás usa
    p2p_webrtc/        # implementación de HOY (WebRTC + señalización Firestore)
    dedicated_server/  # implementación futura (ver README ahí)
    rollback/          # implementación futura, opcional (ver README ahí)
  app/
    flavors/       # composition roots: main_p2p.dart, main_dev.dart, (futuros main_dedicated.dart, etc.)
    feature_flags.dart
```

**Regla de oro:** `features/*` y `game_engine/` nunca importan nada de
`netcode/p2p_webrtc` (ni WebRTC, ni Firestore) directamente — solo la
interfaz `NetSession`. Cambiar de netcode es escribir una clase nueva
en `netcode/` y registrarla en un `main_*.dart` nuevo.

## Estado de la migración

Ya portado a Dart puro y testeado (`game_engine/`):
- Cálculo de stats (`StatsCalculator`, puerto de `stats(p)`)
- Reglas del árbol de pasivas (`PassiveTreeRules`)

Todavía en el prototipo HTML, pendiente de portar (ver `docs/specs/`):
- Motor de timeline de combate (`battleTick`/`dmgEnemy`/`battleCmd`)
- Generación de mapas y misiones
- Catálogo completo de armas/clases/habilidades (hoy solo hay ejemplos
  mínimos en los tests)
- UI real con Flame (hoy solo hay un placeholder en `app/app.dart`)
- `WebRTCNetSession` sin probar en dispositivo real

## Specs (SDD)

Cada sistema tiene su spec en `docs/specs/*.md` **antes** de la
implementación — describe el comportamiento de referencia (tomado del
prototipo HTML) que el código Dart debe cumplir. Los tests en
`test/game_engine/` verifican contra esos specs.

## Sprites / arte

Nunca se hardcodea un nombre de archivo de sprite en el código.
`assets/sprites/sprite_manifest.yaml` mapea id lógico → archivo; para
cambiar un sprite alcanza con reemplazar el PNG (y esa línea del
manifest si cambia el path). Recomendado: Aseprite (`flame_aseprite`)
o Piskel (gratis, web) para exportar PNG + atlas.
