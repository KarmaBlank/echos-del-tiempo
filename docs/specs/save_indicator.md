# Guardado del pueblo al editar y aviso de guardado (v0.37.3)

## 1. Guardado del pueblo al editar

- Antes solo se escribía el pueblo del mundo al terminar una misión, al
  volver al lobby y al salir. Una edición (poner, mover, ampliar, faros)
  se perdía si el juego se cerraba antes.
- Solo guarda quien corre el motor (anfitrión o solo); el cliente nunca
  escribe el pueblo (igual que antes).
- El anfitrión vigila el pueblo después de cada paso del motor
  (`SessionController._watchTown`), así cuenta igual la edición propia
  que la de un cliente aplicada en el host por `TownAction`:
  - al soltarse el candado de edición (`townEditor` pasa a `null`: se
    terminó de editar) se guarda en el momento;
  - si el pueblo cambió (otro objeto `TownState`) mientras sigue la
    edición, se programa un guardado a los 2 s (`townSaveDelay`); los
    cambios dentro de esa ventana se juntan en una sola escritura.
- Avanzar sin cambios no escribe nada.

## 2. Aviso de guardado en el HUD

- Abajo a la izquierda del HUD del mundo, justo debajo del chat (o del
  registro de mensajes si el chat está oculto): ícono que gira en bucle +
  `Guardando… no cierres el juego`.
- Se ve mientras haya cualquier escritura a disco en curso: pueblo del
  mundo, perfil del jugador local, compañeros de la party y niebla.
  Queda a la vista al menos 1,5 s (`savingMinVisible`) para poder leerlo.
- El cliente lo muestra cuando se guarda su propio perfil.
- Ícono: `items.eco` del manifest (cargado por `SpriteCatalog` con los
  íconos de ítems), rotado en bucle; con REDUCIR MOVIMIENTO queda quieto.
  Texto con `DsText.detail`, sin negrita ni bordes redondeados, no toma
  el mouse.
- `SessionView.saving` lleva el estado a la UI.
