# Spec: Party jugando solo (v0.8.1)

## 0. Disponibilidad por build (v0.9.14)

**Apagado en la build principal desde v0.9.14 (`FeatureFlags.soloParty`);
se mantiene en dev.** Decisión del dueño: manejar la progresión de 4
personajes es demasiado pesado. `main_p2p` deja el flag en `false`;
`main_dev` lo prende.

Con el flag apagado:

- El título no muestra la sección PARTY ni el selector de compañeros;
  JUGAR arranca solo con el personaje elegido. Los demás personajes de
  la cuenta siguen existiendo y se pueden elegir para jugar.
- `sessionControllerProvider` no recibe `PartyStore`: la sesión no
  carga compañeros, así que no hay PARTY [P], selector de miembro
  (Ctrl+←/→), "Dar a..." a compañeros, filtro de compañeros, opción
  "con compañeros" en el sello del tutorial ni compañeros en ENTRENAR.
- La party guardada en la cuenta (`party.c` / `party.auto`) **no se
  borra ni se toca**: se ignora mientras el flag esté apagado y vuelve
  a valer al prenderlo. Cargar una cuenta con party guardada no rompe
  nada.
- El motor (`game_engine/`) no cambia.

Tests: `test/features/world/solo_party_ui_test.dart` (grupo "sin
FeatureFlags.soloParty"); los tests de party existentes corren con el
flag prendido.

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
- Un compañero acepta (`SessionEngine.companionAction`, v0.8.3):
  - batalla y loot: `BattleAction` (su turno), `SetBuildWantsAction`,
    `SetLootFilterAction`;
  - **su personaje** (lo manda el cliente del líder desde el selector de
    miembro, § 6): `AllocateStatsAction`, `RespecAction`,
    `ChangeClassAction`, `TakeNodeAction`, `ResetTreeAction`,
    `ChooseAscensionAction`, `TakeAscensionNodeAction`,
    `ResetAscensionAction`;
  - **su inventario y tiendas**: `EquipAction`, `MoveInventoryAction`,
    `SortInventoryAction`, `CraftAction` (desarmar / vender / limpiar
    donde se puede descartar; forja y fusión solo en el pueblo),
    `FuseAction`, `UpgradeAction`, `BuyWeaponAction`, `BuyItemAction`,
    `EcoCraftAction`, `GiveItemAction` (a cualquiera de la sala: el
    líder u otro compañero) y `DropItemAction`.
  - Cada una con **las mismas reglas que para el líder** (modo, pueblo,
    batalla, pausa: el motor no distingue). Moverse, votar, interactuar,
    levantar del piso, proponer misiones / Ecos / Pruebas / Abismo,
    preparación, pausa, chat y las de desarrollo siguen siendo del líder.
  - Nunca vía `apply` directo con el id del compañero desde la red: un
    `PeerActionEvent` usa el id del par, que en una sala nunca es líder
    de nadie (`applyFor` rechaza ids que no son suyos).
- La red sigue igual: un `PeerActionEvent` aplica con el id del par, que
  nunca es líder de nadie (en una sala no hay compañeros).

### 3.3 Votos, preparación y subida de nivel

Solo esperan a los **humanos** (`leaderId == null`): proponer una misión
solo con compañeros la acepta enseguida; la preparación arranca cuando
el líder está listo; la pausa de subida de nivel espera solo a los
humanos (el compañero guarda sus puntos sin repartir: se reparten
desde el selector de miembro, § 6). El panel de preparación muestra a los compañeros
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
  entre jugadores; desde v0.8.3 también de un compañero al líder o a
  otro compañero (selector de miembro, § 6).

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
3. Combos (v0.9, combo_balance.md § 5.2; `ComboPlanner`, la misma IA que
   el simulador de balance), solo con habilidades que pasan MP, Pulso y
   precondiciones (`SkillRequirements`):
   - un enemigo **Fisurado** → su habilidad con Quebrar sobre él;
   - un enemigo con **5+ stacks** de Quemadura o Veneno → la habilidad
     que detona esa Convergencia (Veneno: golpe de Fuego; Quemadura: golpe
     de Veneno); entre iguales, la que tiene precondición (el detonador de
     su clase);
   - si todavía no encadenó en este turno → una habilidad **Instante** que
     prepara (Quemadura o Veneno donde ya hay más del mismo, sin tocar a
     un enemigo con stacks del otro, que los detonaría con pocos; si no,
     Marca a uno sin Marca). El turno sigue y vuelve a elegir.
4. Atacar al enemigo vivo con menos vida (empate: el primero).

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

## 6. Elegir a qué personaje manejás (v0.8.3)

Pedido del dueño: "si estoy solo, que me dé a elegir qué personaje voy"
(subirle puntos, el árbol, equiparlo, comprarle).

### 6.1 Miembro activo

- El controlador guarda el **miembro activo** (`SessionController.
  actingId`, por defecto el líder; `SessionView.actorId` / `actor`).
  Solo existe con compañeros: sin party (o con red) es siempre el
  jugador local.
- Todas las acciones de personaje del controlador (`allocate`, `respec`,
  `changeClass`, `takeNode`, `resetTree`, `equip`, `moveInventory`,
  `sortInventory`, `craft`, `give`, `dropItem`, `setLootFilter`,
  `buyWeapon`, `buyItem`, `upgrade`, `fuse`, `ecoCraft`,
  `chooseAscension`, `takeAscensionNode`, `resetAscension`) van como
  `applyFor(local, actingId)`. Las de grupo (votar, proponer, listo,
  levantar, pausa, chat, dev) siguen siendo del líder.
- Vuelve al líder cuando: hay que repartir la subida de nivel del líder
  (`mustAllocate`), el compañero activo deja la party o se cierra la
  sesión. Si no, se recuerda entre paneles (abrir la armería después del
  personaje sigue con Leo).

### 6.2 Selector (`PartyMemberBar`)

- Fila arriba de las pestañas en: personaje (todas sus pestañas),
  armería, preparación (sus pestañas de tienda), Portal del Eco y
  Estatua del Tiempo. Solo jugando solo con compañeros.
- Un botón por miembro en orden de la sala: `Ana (vos)`, `Leo`, `Mia`,
  `Cid`; el activo con borde dorado. Al lado de cada uno, la insignia
  `+N` con sus puntos sin usar (atributos + árbol + ascensión,
  `UnusedPoints`). Clic / Enter lo elige.
- Teclado: **`Ctrl+←` / `Ctrl+→`** miembro anterior / siguiente (en
  círculo). Los números ya cambian de pestaña (`MenuTabKeys`), por eso
  no se usan para esto. `PanelFrame` y `FocusGrid` dejan pasar las
  flechas con `Ctrl`. Está en CONTROLES (`kMenuKeys`).
- El panel entero muestra y actúa sobre el miembro activo: título
  (`nombre · clase · Puntos`), reparto de atributos (el pendiente se
  borra al cambiar de miembro), clase, árbol, inventario (`DAR A`
  lista a los demás de la sala, también el líder), filtro, BUILD (el plan
  de **su** ranura; al guardarlo se manda su `SetBuildWantsAction`),
  créditos y tiendas, ascensión.
- Excepciones del líder: el Portal del Eco abre Ecos solo con el líder
  (`ABRIR ECO` con el motivo `Los Ecos los abre el líder`; DAR A le pasa
  el Eco), la pestaña ABISMO y la pestaña PRUEBAS de la Estatua usan
  siempre al líder (son propuestas de grupo).

### 6.3 Puntos sin usar en el HUD

- La insignia `PERSONAJE [C] +N` suma los puntos de todos los miembros;
  el tooltip los separa (`Leo: 3 puntos de atributos`).
- El aviso al subir de nivel agrega una parte por compañero con puntos:
  `Leo tiene 3 puntos sin usar`. Sale también si solo subieron los
  puntos de un compañero.

### 6.4 Guardado

Sin cambios de formato: lo que cambia en el compañero se guarda en
**su** ranura con las reglas de § 5 (cada 2 s si cambió, etc.).

## 7. Pendiente

- AUTO no usa dúos ni objetos de maná.
