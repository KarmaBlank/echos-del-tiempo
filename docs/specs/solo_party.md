# Spec: Party jugando solo (v0.8.1)

Pedido del dueño: "si jugás solo, que puedas tener una party, que
decidas de cuántos". Jugando **solo** (sin sala de red) podés llevar
de **1 a 3 compañeros**: tus **otros personajes de la cuenta**
(characters.md § 1). La party queda de 1 a 4. Los controlás vos, estilo
JRPG clásico: en el turno de cada compañero elegís su acción, o le
prendés **AUTO** y actúa solo. Ganan XP y loot propio como si los
jugaras, y todo se guarda en **su** ranura de la cuenta.

Código: `lib/game_engine/rules/session_engine.dart` (compañeros en la
sala, seguir al líder, validación de quién actúa),
`lib/game_engine/rules/companion_ai.dart` (AUTO),
`lib/game_engine/models/party_store.dart` (contrato de guardado),
`lib/features/characters/domain/account.dart` (`party`),
`lib/features/characters/data/account_repository.dart`
(`AccountPartyStore`), `lib/features/characters/presentation/party_picker.dart`
(selector), `lib/features/world/presentation/session_controller.dart`,
`lib/features/world/presentation/panels/party_panel.dart` y la batalla
(`battle_screen.dart`, `battle_hud.dart`).
Tests: `test/game_engine/solo_party_test.dart`,
`test/game_engine/companion_ai_test.dart`,
`test/features/characters/party_persistence_test.dart`,
`test/features/world/solo_party_ui_test.dart`.

## 1. Solo, nunca en salas

- Los compañeros existen **solo en la sesión local** (`net == null`).
  Al crear o unirse a una sala la party se ignora: cada humano lleva un
  personaje, como siempre (netcode.md). El título lo dice debajo del
  selector cuando hay compañeros elegidos.
- No cambia el protocolo de red (`kProtocolVersion` igual): lo nuevo de
  `SessionPlayer` (`leaderId`, el rastro del líder) es **solo del host**
  y no viaja en el snapshot.

## 2. Armar la party

### 2.1 Cuenta (`account.json`, clave `party`, opcional)

```json
"party": {"c": ["c2", "c4"], "auto": ["c4"]}
```

- `c`: ids de los compañeros, en orden (orden de turno empatado, de la
  fila en el mapa y de las tarjetas). `auto`: los que tienen AUTO
  prendido (se recuerda entre partidas).
- Se sanea al leer y al usar (`Account.companions`): solo ids que
  existen, sin repetir, **nunca el elegido** (un personaje no puede ser
  líder y compañero a la vez) y como mucho `Account.maxCompanions` = 3.
- Elegir como líder a alguien que estaba en la party lo saca de la
  party. Borrar un personaje lo saca también.
- Una cuenta sin `party` (todas las de antes) = jugar solo, como antes.

### 2.2 Título

Debajo de los botones de personaje: `PARTY: tú + N` y una fila con los
demás personajes de la cuenta (`Nombre · Clase · Nv X`). Clic / Enter
en uno lo agrega o lo saca (botón marcado = en la party). Con 3
elegidos, los demás quedan deshabilitados con el motivo `Máximo 3
compañeros`. `> JUGAR` entra con esa party.

### 2.3 Pueblo: panel PARTY

En el pueblo (modo `lobby`, sin votación), jugando solo, el HUD muestra
`PARTY [P]` (tecla **P**) que abre el panel con el mismo selector y la
casilla AUTO de cada compañero. Los cambios se aplican al instante: el
compañero que sale se guarda y deja la sala; el que entra carga su
perfil de la cuenta y aparece junto al líder. Fuera del pueblo (votación,
preparación, misión, batalla) el panel no se abre y el motor rechaza los
cambios.

## 3. Motor (`SessionEngine`)

### 3.1 Compañeros en la sala

- `addCompanion(session, id, profile, leaderId:)`: entra como un jugador
  más (mismo `addPlayer`: perfil normalizado, spawn junto al grupo) con
  `SessionPlayer.leaderId = leaderId`. `null` si la sala está llena
  (`maxPlayers` = 4), el id existe, el líder no está o es a su vez un
  compañero, o no es el pueblo (`lobby`) sin votación ni preparación
  (al crear la sala el modo ya es `lobby`).
- `removeCompanion(session, id)`: mismo control de modo; solo saca
  compañeros.
- Ids: `<idLocal>-<idRanura>` (`local-c2`): estables, uno por ranura.
- Mensaje: `Leo se unió a la party.` / `Leo dejó la party.`

### 3.2 Quién actúa

- `applyFor(session, senderId, actorId, action)`: el remitente
  `senderId` actúa como `actorId` solo si es él mismo o si
  `players[actorId].leaderId == senderId`. Si no, `null`.
- Un compañero solo acepta: `BattleAction` (su turno),
  `SetBuildWantsAction` y `SetLootFilterAction`. Moverse, votar,
  interactuar, comprar, etc. son del líder.
- La red sigue igual: un `PeerActionEvent` aplica con el id del par, que
  nunca es líder de nadie (en una sala no hay compañeros).

### 3.3 Votos, preparación y subida de nivel

Solo esperan a los **humanos** (`leaderId == null`): proponer una misión
solo con compañeros la acepta enseguida; la preparación arranca cuando
el líder está listo; la pausa de subida de nivel espera solo a los
humanos (el compañero guarda sus puntos sin repartir: se reparten
jugándolo como líder). El panel de preparación muestra a los compañeros
como listos.

### 3.4 Escalado

Todo lo que escala con el tamaño del grupo usa la party entera (1–4):
vida de los enemigos (`0.55 + 0.45 × n`), adds de jefes (`soloAdds` solo
con 1), bonus de loot de los Ecos, "Quedan N objetos de X" al cambiar de
piso. Igual que en co-op.

### 3.5 Mapa: siguen al líder en fila

- Solo el líder camina. El host guarda el **rastro** del líder (puntos
  cada 4 px, hasta 96, solo host) y cada compañero k (1..3) se para en
  el punto del rastro a `k × 18` px de camino detrás del líder (una
  fila "conga"). Si el rastro es más corto, se queda donde está. Mira
  hacia donde se movió y `moving` refleja si se movió en ese tick.
- El rastro se vacía cuando el líder se teletransporta (sube su `epoch`:
  piso nuevo, misión, vuelta al pueblo, caída al vacío, batalla).
- Corre en `lobby` y `field`.
- **Interacciones, solo el líder**: fragmentos, cofres, escaleras,
  reliquias, descubrir POIs y sellos se tocan con el líder, no con los
  compañeros. Los enemigos sí pueden chocar a un compañero (empieza la
  batalla igual).

### 3.6 Loot y XP

- XP, créditos, subida de nivel y Maestría: igual que cualquier jugador
  (`_onBattleOver` recorre a todos).
- Tiradas: por jugador, con la familia de **su** clase (loot por
  jugador, loot.md). Filtro: el **suyo** (`profile.lootFilter`) y su plan
  de build (`SetBuildWantsAction` con el plan de su ranura).
- Entrega: lo que su filtro muestra va **directo a su inventario**
  (no camina por el piso); si no entra, cae al piso como suyo y lo
  levanta solo cuando el **líder** (o él) pasa encima. Lo oculto por su
  filtro queda en el piso, invisible, y se pierde al cambiar de mapa
  (como siempre).
- Cofres, legendario de jefe, recompensas de fin de misión, Ecos,
  Fragmentos del Abismo: las mismas reglas por jugador.
- Dar objetos (`GiveItemAction`) del líder a un compañero funciona como
  entre jugadores.

## 4. Batalla

- El compañero es un miembro más de `BattleState.party` (orden de la
  sala). El tiempo de turno de la sala vale para cada turno (también el
  de un compañero): si vence, el turno se pierde como siempre.
- Turno de un compañero **sin AUTO**: la ventana de comandos se abre
  para él con `Turno de Leo (compañero)` en lugar de `¡Tu turno!`.
  Teclado y mouse iguales. El comando viaja como `applyFor(local, Leo)`.
- Turno de un compañero **con AUTO**: la barra muestra `Turno de Leo
  (AUTO)` y a los 0.5 s de juego el controlador elige con
  `CompanionAi` y lo manda.
- Tarjetas del grupo: los compañeros muestran la barra de ULT y un botón
  `AUTO` (prendido / apagado) que cambia en cualquier momento, también
  en medio del turno (prenderlo en su turno actúa enseguida).

### 4.1 `CompanionAi.choose` (determinística)

En orden:
1. Algún aliado (él incluido) por debajo del **40 %** de vida o caído:
   - una habilidad `heal` suya con maná → esa habilidad;
   - si no, si tiene Poción de vida → poción al aliado con menos % de vida
     (caído = 0 %).
2. ULT al 100 % (y con ULT) → ULT al enemigo vivo con **menos vida**.
3. Atacar al enemigo vivo con menos vida (empate: el primero).

Si el motor rechaza el comando elegido (p. ej. una mecánica de jefe),
se prueba Atacar y después Defender.

## 5. Guardado (characters.md § 1.4)

- Contrato `PartyStore` (`game_engine/models/party_store.dart`):
  `load()` (los compañeros de la party del elegido: ranura, perfil, AUTO
  y plan), `save(slotId, profile)`, `setCompanions(ids)` y
  `setAuto(id, on)`. En la app, `AccountPartyStore` sobre el mismo
  `AccountRepository` (una sola cuenta, un solo archivo).
- El controlador guarda a **cada miembro** con las mismas reglas que al
  líder: cada 2 s si cambió, siempre al terminar la misión, al volver al
  pueblo, al sacar a un compañero de la party, al salir (`saveNow` de
  `ExitGuard`) y al cerrar la sesión; una escritura fallida no se da por
  guardada (se reintenta) y prende el aviso rojo del HUD.
- El alijo es de la cuenta (compartido), sin cambios. Bestiario, Atlas y
  planes de build: de la cuenta / de cada ranura, sin cambios.
- Cada compañero guarda en **su** ranura (`replace(slotId, …)`), nunca en
  la del líder, y anota `last`.

## 6. Pendiente

- Repartir los puntos de un compañero (atributos, árbol, ascensión),
  equiparlo o comprarle se hace jugándolo como líder.
- AUTO no usa dúos ni objetos de maná.
