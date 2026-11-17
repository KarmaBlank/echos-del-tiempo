# Spec: Contrato de red (`netcode/contracts`)

## Por qué existe esta capa

`features/*` y `game_engine` nunca deben importar `flutter_webrtc`,
`cloud_firestore`, ni ningún paquete de red directamente. Todo pasa
por `NetSession` (`lib/netcode/contracts/net_session.dart`). Esto es
lo que permite tener 3+ "versiones" del mismo juego (P2P, servidor
dedicado, experimental) sin tocar la lógica de juego ni la UI — solo
se cambia qué implementación se inyecta en el composition root
(`lib/app/flavors/main_*.dart`).

## Contrato

- `connect(SessionConfig)` — crea sala (host) o se une a una existente.
- `sendAction(GameAction)` — el jugador local propone una acción.
  Quién decide si es válida es la autoridad (host en P2P, servidor en
  la variante futura), nunca quien envía.
- `events` — stream de `GameEvent`. El más importante es
  `StateSnapshotEvent`: el estado completo y autoritativo, que
  `features/*` usa para reconstruir su UI. **Nunca** se infiere estado
  localmente a partir de una acción enviada — se espera el snapshot
  de vuelta (mismo modelo que el prototipo: host autoritativo).

## Implementaciones

| Variante | Carpeta | Estado |
|---|---|---|
| P2P (WebRTC + señalización Firestore) | `netcode/p2p_webrtc` | Esqueleto escrito, falta portar la lógica de reglas del host y probar en dispositivo real |
| Servidor dedicado | `netcode/dedicated_server` | No empezado — ver README de esa carpeta |
| Rollback | `netcode/rollback` | No empezado, y probablemente no haga falta para el combate por turnos — ver README de esa carpeta y `combat.md` |

## Por qué Firestore solo para señalización

Firestore NUNCA transporta el juego en sí — solo el SDP/ICE inicial
para armar la conexión WebRTC directa entre los dos peers. Una vez
conectados, todo el tráfico de `GameAction`/`GameEvent` va P2P por el
DataChannel. Elegir Firestore vs. otro broker de señalización no
afecta la latencia del juego, solo la confiabilidad del "apretón de
manos" inicial.
