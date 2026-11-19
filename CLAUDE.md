# Ecos del Tiempo — contexto para Claude Code

Este proyecto es el puerto a Flutter de un prototipo JS single-file
(`ecos-del-tiempo.html`, un co-op JRPG táctico por turnos, P2P entre amigos). El scaffold inicial se armó en una
sesión de chat de Claude que **no tenía Flutter SDK disponible**, así
que todo el código se escribió a mano sin poder correr
`flutter pub get` / `flutter analyze` / `flutter test`. Esta es tu
primera tarea real acá: validar que compila y arreglar lo que falle.

## Decisiones de arquitectura (ya tomadas, no las reabras sin preguntar)

- **Clean Architecture + Feature-First.** `lib/features/<feature>/{domain,data,presentation}`.
- **Netcode agnóstico vía interfaz.** `lib/netcode/contracts/net_session.dart`
  (`NetSession`) es lo único que `game_engine/` y `features/*` conocen
  de la red. Implementación de hoy: `netcode/p2p_webrtc` (WebRTC +
  señalización por Firestore — Firestore NUNCA transporta el juego,
  solo arma la conexión inicial). `netcode/dedicated_server` y
  `netcode/rollback` son carpetas con README, todavía sin implementar
  a propósito — el dueño del proyecto quiere poder agregar esas
  variantes después sin tocar `features/*` ni `game_engine/`.
- **`game_engine/` es Dart puro**, sin Flutter ni red. Ahí vive toda la
  lógica que en el prototipo HTML era JS mezclado con el DOM: cálculo
  de stats, árbol de pasivas, (pendiente) motor de combate, generación
  de misiones. Todo debe quedar testeable con `flutter test` sin UI.
- **Composition roots en `lib/app/flavors/`** (`main_p2p.dart`,
  `main_dev.dart`, futuros `main_dedicated.dart` etc.) — cada uno
  decide qué implementación de `NetSession` y qué `FeatureFlags` se
  inyectan. Es así como se arman "versiones" distintas del mismo juego
  (roster restringido, features experimentales, etc.) sin ramificar
  el código fuente.
- **Sprites nunca hardcodeados.** `assets/sprites/sprite_manifest.yaml`
  mapea id lógico → archivo; `SpriteCatalog` es la única clase que lee
  ese archivo. El dueño quiere poder cambiar arte sin tocar Dart.
- **SDD:** cada sistema tiene su spec en `docs/specs/*.md` ANTES que el
  código, con el comportamiento de referencia tomado del prototipo
  HTML. Si algo no está claro, el spec manda; si el spec está
  incompleto, actualizalo vos al implementar (no lo dejes desactualizado).

## Estado real del código (sin verificar aún)

- `pubspec.yaml`: versiones de paquetes puestas "a ojo" (flame, riverpod,
  get_it, flutter_webrtc, cloud_firestore, firebase_core, yaml) — puede
  necesitar `flutter pub upgrade --major-versions` o bajar alguna versión
  si hay conflictos.
- `game_engine/rules/stats_calculator.dart` y `passive_tree_rules.dart`:
  escritos con cuidado de tipos (double vs int, clamp) pero sin compilar
  nunca — revisalos primero con `flutter analyze`.
- `netcode/p2p_webrtc/webrtc_net_session.dart`: esqueleto funcional en
  teoría, con un TODO explícito de portar la lógica de reglas del host
  (hoy vive conceptualmente en el prototipo HTML, función `hostTick`).
  Nunca se probó contra la API real de `flutter_webrtc` — puede haber
  nombres de métodos/clases desactualizados respecto a la versión que
  termine quedando en pubspec.lock.
- `features/*`: solo estructura de carpetas + un README por feature.
  Casi todo el contenido real (UI, casos de uso) está por escribir.
- Falta portar del prototipo HTML: motor de timeline de combate
  completo, catálogo real de armas/clases/habilidades/misiones
  (hoy solo hay ejemplos mínimos en los tests), generación de mapas,
  sistema de cofres, UI con Flame.

## Primer TODO sugerido

1. `flutter pub get` y arreglar lo que pub.dev se queje de versiones.
2. `flutter test` — arreglar cualquier error de tipos en `game_engine/`.
3. `flutter analyze` — limpiar lints.
4. Recién ahí seguir portando funcionalidad nueva (ver `docs/specs/`).

## Referencia original

El prototipo HTML completo (que fue la base de todo este puerto) no
está en este repo. Si lo necesitás para comparar comportamiento exacto,
pedíselo al dueño del proyecto — lo tiene guardado aparte.
