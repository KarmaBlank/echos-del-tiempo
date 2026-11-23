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
- Fuera de la edición el pueblo cambia solo (cielo, ayudantes, cultivos):
  eso no dispara guardados; se escribe una vez por día de juego (v0.39.1;
  antes salía el aviso cada 2 s).

## 2. Aviso de guardado en el HUD

- Abajo a la izquierda del HUD del mundo, justo debajo del chat (o del
  registro de mensajes si el chat está oculto): ícono que gira en bucle +
  `Guardando… no cierres el juego`.
- Se ve en todos los guardados del perfil (ya son pocos, ver § 3), del
  pueblo del mundo y de la niebla. Queda a la vista al menos 1,5 s
  (`savingMinVisible`) para poder leerlo; sin timers, se recalcula en
  cada paso del juego.
- El cliente lo muestra cuando se guarda su propio perfil.
- Ícono: `items.eco` del manifest (cargado por `SpriteCatalog` con los
  íconos de ítems), rotado en bucle; con REDUCIR MOVIMIENTO queda quieto.
  Texto con `DsText.detail`, sin negrita ni bordes redondeados, no toma
  el mouse.
- `SessionView.saving` lleva el estado a la UI.

## 3. Cuándo se guarda el perfil (v0.38.3)

`SessionController._save`. Ya no hay autoguardado cada 2 s.

- **Una vez por día de juego**: al cambiar `town.sky.day` (el reloj del
  cielo). El paso del día 0 al 1 (el cielo arrancando) no cuenta.
- **Al cerrar un menú o pantalla** (personaje, inventario, tiendas,
  forja, diario, party, alijo, mapa…): `_emit` ve que `panel` deja de
  ser el que estaba abierto y marca un guardado; durante los 2 s
  siguientes (`saveSoonWindow`) se escribe todo lo que cambió, así al
  cliente le da tiempo a recibir su perfil nuevo en un snapshot.
  Mientras el menú sigue abierto no se guarda nada (comprar, vender,
  equipar, forjar… se guardan al cerrarlo).
- **Forzados** (como antes): fin de misión, volver al lobby, hazañas,
  sacar a un compañero de la party, salir (`ExitGuard` / `dispose`).
- **Pueblo**: al terminar la edición (§ 1).
- Si una escritura falla se reintenta cada `saveEvery` (2 s) hasta
  que entra.
- El cliente guarda su propio perfil con las mismas reglas.
- Riesgo aceptado: si el juego se cae (sin pasar por salir) se pierde
  lo hecho fuera de menús desde el último guardado (como mucho un día
  de juego).