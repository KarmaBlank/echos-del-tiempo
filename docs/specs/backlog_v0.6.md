# Backlog v0.6 — "Exploración y Bestiario" (pedido del dueño, sin diseñar)

Pedido tal cual llegó, para convertirlo en specs antes de codificar.

## 1. Mapas más chicos y con cosas para explorar
- Los mapas son muy grandes (ej.: Laberinto Temporal). Achicarlos.
- Que haya algo que incentive explorar: hoy los cofres casi siempre dan
  créditos o pociones. Ideas a diseñar: cofres con armas / materiales /
  Ecos según zona, salas secretas, santuarios con bendiciones
  temporales, mini-eventos, élites opcionales con mejor botín, lore.

## 2. Árbol de pasivas: más notables que cambien la jugabilidad
- Gusta el árbol, pero hay pocos notables (2 por cluster) y hay que
  avanzar mucho; los nodos chicos se sienten como "subir atributos"
  (para eso ya está subir de nivel).
- Más notables de cambio de jugabilidad por rama, menos relleno.

## 3. Aviso de puntos sin usar
- Notificación visible pero no invasiva cuando hay puntos de árbol (y de
  atributos / ascensión) sin usar.

## SALIR DEL JUEGO en el título — hecho en v0.8.2
- Botón **SALIR DEL JUEGO** en el menú principal (pantalla de título),
  con confirmación "¿Salir del juego?" y el mismo cierre seguro que la
  pausa (`appExitProvider` → `ExitGuard.flushAll` antes de cerrar).
  Ver settings.md § "Pausa" y docs/release_notes/v0.8.2.md.

## ULTs de rama — hecho en v0.8.1 (en armas)
- Decisión del dueño: las ULTs nuevas van **en armas**, no en el árbol.
  144 ULTs (3 por camino) como mod "ULT: X" en armas Raras/Épicas del
  tipo compatible y fijas en 17 legendarios: docs/specs/branch_ults.md.

## Invocador (Maga) — pedido del dueño, arranca después de la party en solitario
- Línea de **Invocador** en el árbol de la Maga (clusters nuevos) y
  **tomos** con habilidades de invocación; **máximo 4 invocaciones**
  activas. "Hacé magia con eso, que sea divertido": invocaciones con
  identidad (elementales, golem, espíritus), sinergias con reacciones,
  sacrificar/detonar invocaciones, notables que las potencian.
- Reusa la infraestructura de aliados controlados por IA de la party
  en solitario (AUTO).
- **Hecho en v0.8.1**: docs/specs/summoner.md (6 invocaciones, 9
  habilidades, 5 tomos con 3 ULT propias, cluster Invocador de 13 nodos).

## v0.7 — Elementos y reacciones
- Borrador para aprobar: docs/specs/elemental_reactions.md (Agua +
  Electro = Electrocución, Veneno + Fuego = Explosión tóxica, etc.).

## Lore — pendiente del dueño
- No hay historia aprobada. Los objetos de historia en los mapas quedan
  desactivados hasta que el dueño pase el lore (decisión del dueño:
  "sin historia por ahora"). Nada de texto narrativo inventado.

## 5. Integración con Discord — PRIORIDAD BAJA (roadmap, después de v0.6)
- Rich Presence (zona, nivel, "en sala X/4").
- Si alguien crea una sala, a sus amigos de Discord les aparece la
  opción **Unirse** y el juego entra directo a esa sala.
- Requiere una aplicación propia en el Discord Developer Portal (la
  crea el dueño; su Application ID va en la config) y registrar el
  juego para que Discord lo abra al unirse (instalador).

## 4. Tipos de enemigo, debilidades y Bestiario (builds tipo D&D)
- Clasificar enemigos por tipo (ej.: no muertos, bestias, constructos,
  elementales…) con debilidades y resistencias que habiliten builds: ej.
  las curas dañan a los no muertos → build "full curas" que también
  pega.
- Al pasar el mouse sobre un enemigo: su tipo, debilidades y
  resistencias, **solo si ya lo mataste alguna vez**; si no, "?" y "Matá
  a este enemigo para agregarlo al bestiario".
- **Bestiario**: pestaña de información en el juego con los enemigos
  descubiertos.
