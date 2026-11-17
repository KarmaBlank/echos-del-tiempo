# Dedicated Server (futuro)

Implementación prevista de `NetSession` donde la autoridad del estado
es un servidor (no un peer). Candidatos razonables cuando se arme:

- WebSocket + un backend Dart (`shelf_web_socket`) reusando **el mismo**
  `game_engine` que hoy corre en el cliente host P2P — la resolución de
  reglas (stats, daño, árbol de pasivas, generación de misión) es Dart puro
  y no sabe de transporte, así que corre igual en un server.
- `isHost` siempre `false` desde la perspectiva de todos los clientes;
  el servidor usa su propia instancia de `game_engine` + una variante de
  `NetSession` "server-side" que transmite el snapshot (`SnapshotEvent`, ver
  docs/specs/netcode.md) a N clientes, reusando `ProtocolNetSession`.

Nada en `features/*` cambia al agregar esto: solo se escribe esta clase
y se la registra en un nuevo `app/flavors/main_dedicated.dart`.
