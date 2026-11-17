# Feature: world

La sesión de juego del lado del cliente/host local: mapa Flame, HUD,
paneles del mapa y el controlador que corre `SessionEngine`.
Spec: docs/specs/exploration.md.

- presentation/session_controller.dart — host local (Riverpod): tick
  fijo, entrada → `SessionAction`, eventos, guardado del perfil.
- presentation/world_screen.dart — pantalla raíz: elige qué dibujar
  según `SessionMode` y reparte el teclado.
- presentation/map/ — juego Flame del mapa (tiles, actores, cámara).
- presentation/hud/, presentation/panels/ — overlays Flutter.

domain/ y data/ todavía no tienen nada propio: las reglas viven en
`game_engine/` y el perfil se guarda con `features/lobby/data`.
