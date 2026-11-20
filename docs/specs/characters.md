# Spec: Personajes de la cuenta y alijo compartido

Pedido del dueño: "lo de tener perfil de personajes" (endgame.md § 5,
decisión 3). La cuenta local tiene **varios personajes** y un **alijo
compartido** entre ellos, para pasarle objetos a un personaje nuevo y
probar otras builds. Todo pasa **fuera de la sesión** (pantalla de
título): no cambia el protocolo de red ni el motor.

Código: `lib/features/characters/` (domain / data / presentation) y la
pantalla de título `lib/features/lobby/presentation/title_screen.dart`.
Tests: `test/features/characters/*`, `test/features/lobby/*`.

## 1. Cuenta (`account.json`)

Un archivo por instalación, en la misma carpeta de datos que el perfil
de antes (`%APPDATA%\EcosDelTiempo`, exploration.md § "Persistencia"):

```json
{"v":1,"sel":"c2","seq":3,
 "chars":[{"id":"c1","new":"2026-11-01T18:00:00.000","last":"2026-11-17T21:05:00.000",
           "p":{ ...PlayerProfile.toJson() (perfil v3)... }},
          {"id":"c2", ...}],
 "stash":{"cells":[{"i":0,"it":{ ...ItemInstance.toJson()... }},
                   {"i":5,"m":"cristal","n":120}]}}
```

- `chars`: hasta **8 personajes** (`Account.maxCharacters`), en orden de
  creación. Cada uno es un `PlayerProfile` completo (sin cambios de
  formato: la sesión y la red lo siguen viendo igual) + `id` estable
  (`c<n>`, del contador `seq`; nunca se reusa), fecha de creación y
  fecha de la última partida (`last`, `null` = nunca jugó).
- `plan` (opcional, v0.5): el plan de build del personaje
  (build_planner.md § 1). Una cuenta sin `plan` carga igual; guardar el
  perfil desde la sesión lo conserva.
- `sel`: el personaje elegido. Si no existe, se toma el primero.
- `stash`: el alijo (§ 3).
- Lectura tolerante: lo que falta toma su valor por defecto; una
  entrada de `chars` que no es un objeto se descarta. Los perfiles se
  guardan tal como vienen y `ProgressionRules.normalize` los valida al
  usarlos (igual que antes con `profile.json`).

### Sesión: `ProfileStore` = el personaje elegido

`ProfileStore` (contrato de `game_engine`) no cambia. El composition
root registra `SelectedCharacterProfileStore`, que lee y escribe el
**personaje elegido** de la cuenta:
- `load()` → el perfil del elegido (`null` si la cuenta no tiene
  personajes: la sesión arranca con `Héroe` como siempre).
- `save(p)` → reemplaza el perfil del elegido y anota `last = ahora`. Si
  la cuenta no tiene personajes (caso borde), lo agrega como personaje
  nuevo si hay lugar.

Así `SessionController`, `WorldScreen` y el netcode no cambian: el
título elige el personaje, y la sala carga y guarda ese.

`AccountRepository` es el único que toca el `AccountStore`: guarda la
cuenta en memoria (una sola lectura del disco), aplica los cambios en
orden (`update`) y avisa por `changes` (el título se refresca cuando la
sesión guarda). Cada cambio escribe la cuenta entera.

### Escritura atómica

Igual que el perfil: `account.json.tmp` + `rename`. Mover un objeto
entre un personaje y el alijo es **un solo** guardado de la cuenta (el
objeto nunca queda duplicado ni perdido si se corta a la mitad).

Desde v0.5 (endurecido tras el bug de v0.4, § 1.4):
- Leer, escribir la copia y renombrar se **reintentan** (100 / 300 /
  800 ms) ante un `FileSystemException`: en Windows un antivirus o el
  indexador pueden tener el archivo abierto un instante.
- Si renombrar sigue fallando (Windows no deja reemplazar un archivo
  abierto por otro proceso), **plan B**: se escribe el JSON directo sobre
  `account.json`. La copia `.tmp` queda completa hasta que eso termina.
- Al leer: si `account.json` falta o está dañado y hay un
  `account.json.tmp` completo, se usa la copia (se cortó entre escribirla
  y reemplazar). Si los dos son válidos y la copia es **más nueva**, gana
  la copia (el reemplazo y el plan B fallaron).

### Migración desde `profile.json`

Al leer la cuenta:
1. Si existe `account.json`, se usa (y `profile.json` se ignora).
2. Si no, y existe un `profile.json` legible, ese perfil pasa a ser el
   **personaje #1** (`c1`, elegido, `last` = fecha de modificación de
   `profile.json`) y se escribe `account.json` enseguida. **`profile.json`
   no se borra ni se modifica**: queda como copia de seguridad.
3. Si no hay ninguno (o `profile.json` está corrupto, como antes: "sin
   perfil"), la cuenta empieza vacía y el título pide crear un personaje.
   Nada se escribe hasta crear uno.

### Archivo corrupto

Si `account.json` existe pero no se puede leer como JSON (o no es un
objeto):
- se **copia** a `account.corrupt-AAAAMMDD-HHMMSS.json` en la misma
  carpeta (nunca se borra en silencio);
- se escribe una cuenta vacía y el título muestra en rojo:
  `No se pudo leer la cuenta (archivo dañado). Se guardó una copia en
  account.corrupt-….json y se empezó una cuenta nueva.`
- Si ni siquiera se puede hacer la copia (disco, permisos), la cuenta
  queda **solo en memoria** para esa ejecución (no se escribe nada, para
  no pisar el archivo) y el título lo avisa.

### 1.4 Invariante: el progreso se mantiene juegues donde juegues

> "No importa dónde juegues, el progreso del personaje se mantiene."

- **Un solo personaje, un solo archivo.** Solo, anfitrión, cliente LAN o
  cliente P2P leen y escriben **el mismo** personaje elegido del mismo
  `account.json`, por el mismo `AccountRepository`
  (`SelectedCharacterProfileStore`). Ningún flavor ni modo registra otro
  `ProfileStore`: `registerSharedDependencies` es el único que lo hace y
  los `register*Netcode` solo agregan la red. El cliente guarda el
  perfil que le manda el host en cada snapshot (cada 2 s si cambió,
  siempre al terminar la misión, al volver al pueblo y al salir).
- El perfil que viaja al unirse (`hello`) y el que recibe la sesión salen
  de la cuenta **en memoria** (`AccountRepository.current`), nunca de una
  copia de la pantalla de título que pudiera haber quedado vieja.
- **Nunca en silencio.** Una escritura fallida:
  - no se da por guardada: la sesión vuelve a intentar a los 2 s y el
    repositorio reintenta solo la cuenta entera (1, 2, 5, 10, 30 s…)
    hasta que sale;
  - se muestra: en el HUD, arriba al centro y en rojo,
    `No se pudo guardar (ver ecos.log)` (`SessionView.saveError`) y en el
    título el error del repositorio (`saveError`) junto al aviso de carga;
    los dos se borran solos cuando un reintento sale bien;
  - queda en `ecos.log` (§ 1.5).
- **Al salir se guarda.** `ExitGuard` junta lo pendiente: la sesión en
  curso (`saveNow`) y después la cuenta (`AccountRepository.flush`, que
  reintenta una vez si quedó algo sin escribir), con un tope de 4 s. Lo
  llaman: cerrar la ventana (`installExitOnClose`, `AppLifecycleListener
  .onExitRequested`: Windows le pregunta al framework antes de cerrar),
  SALIR DEL JUEGO y el auto-actualizador (antes de lanzar el instalador,
  que puede cerrar el juego enseguida).
- **Una sola ventana dueña de la cuenta.** Al cargar, la app toma un
  candado exclusivo sobre `ecos.lock` (lo suelta el sistema al cerrarse
  el proceso). Una segunda ventana (doble clic, el instalador que abre
  el juego mientras ya estaba abierto, un proceso colgado) **no escribe
  nada** y el título avisa: `Ecos del Tiempo ya está abierto en otra
  ventana: esta no guarda nada para no pisar tu progreso…`. Sin esto,
  cada ventana pisaba lo de la otra con su copia vieja de la cuenta.
- Pruebas: `test/features/characters/progress_everywhere_test.dart`
  (solo / host / cliente por loopback: XP, nivel, compras y materiales
  siguen al reabrir desde disco; lo ganado solo viaja a la sala; el
  cableado de LAN y P2P usa una sola cuenta),
  `test/features/lobby/title_client_save_test.dart` (título → sala como
  cliente → título → solo) y `save_hardening_test.dart`.

**Bug de v0.4 ("a un amigo no se le guardaba el progreso").** Jugó como
cliente en la sala del dueño; después, solo, el personaje no tenía lo
jugado en grupo. El camino del cliente en sí guarda bien (las pruebas de
arriba pasan contra el código de v0.4.0, que en esa parte no cambió);
no hay forma de reproducirlo dentro del juego, así que las causas
probables son lo que v0.4 no cubría: (1) dos ventanas del juego abiertas a la vez,
cada una con su copia de la cuenta (la que se usó para jugar solo pisaba
lo que había guardado la del grupo), (2) una carga fallida (archivo
trabado) que dejaba esa ejecución sin guardar nada con solo un aviso en
el título que en una partida en red nadie mira, y (3) escrituras
fallidas tragadas en silencio sin reintento (`_lastSaved` se marcaba
antes de escribir) más la ventana cerrada sin guardar lo pendiente.

### 1.5 Registro `ecos.log`

En la carpeta de datos (`%APPDATA%\EcosDelTiempo\ecos.log`): una línea
por evento con fecha (`INFO` / `ERROR`): inicio del juego, cuenta
cargada (cuántos personajes, si se migró), avisos de carga, otra ventana
con la cuenta, cada guardado fallido (y cuándo se pudo de nuevo),
guardados al salir que fallaron o se pasaron de tiempo. Pasados 256 KB
el archivo pasa a `ecos.log.1` (se pisa el anterior) y se empieza otro.
Nunca rompe el juego. Si un jugador dice que perdió progreso, pedirle
`ecos.log`, `ecos.log.1`, `account.json` y cualquier
`account.corrupt-*.json`.

## 2. Selección de personaje (pantalla de título)

Reemplaza al editor de nombre + clase de un solo perfil; mismo estilo
(`RetroPanel`, tarjetas de clase de siempre).

- Arriba, igual que antes: `ECOS DEL TIEMPO`, subtítulo y aviso de
  versión.
- **Lista de personajes**: una tarjeta por personaje (hasta 4 por fila):
  sprite `idle` de su clase, nombre, `Clase · Nv N`, `Zona N` (la más
  alta desbloqueada) y `Jugado: DD/MM/AAAA` (o `Nunca jugado`). El
  elegido tiene borde dorado. Clic = elegirlo (se guarda); doble clic =
  jugar. Si hay lugar, una tarjeta `+ NUEVO PERSONAJE`. Cada dato va en
  **una línea** (se corta con "…", sin interlineado fijo): con texto
  Grande / Muy grande la tarjeta no se parte en palabras sueltas; su
  ancho crece con el texto hasta 300 px (siempre 4 por fila a 1280).
- Botones: `> JUGAR` (con el elegido), `CREAR PERSONAJE`
  (deshabilitado con `Máximo 8 personajes` si está lleno), `RENOMBRAR`,
  `BORRAR` y `ALIJO`.
- Debajo, la sala de red de siempre (`CREAR SALA` / código / `UNIRSE`),
  que entra con el personaje elegido, `CONFIGURACIÓN` y la ayuda.
- `> JUGAR` / `CREAR SALA` / `UNIRSE`: anotan `last = ahora` en el
  elegido, lo pasan al `ProfileStore` de la sesión y abren el juego.
  Al volver, la lista se refresca (nivel, zona, fecha).

### Crear personaje

- `CREAR PERSONAJE` (o la tarjeta `+`) muestra el creador: `Nombre:`
  (10 caracteres, vacío → `Héroe`) y las **tarjetas de clase de
  siempre** (las 4 iniciales permitidas por `FeatureFlags`, con sprite,
  descripción, atributos base y arma inicial). `CREAR` lo agrega como
  perfil nuevo normalizado (nivel 1, atributos base, arma inicial
  equipada, 3 pociones de vida y 1 de maná), lo elige y vuelve a la
  lista. `CANCELAR` vuelve sin crear (no aparece si no hay personajes).
- Sin personajes (primera vez, o después de borrar el último) el título
  abre directo el creador (`Crea tu primer personaje`).
- Los nombres pueden repetirse (el `id` es lo que distingue).

### Renombrar

Diálogo con el nombre actual: mismo recorte (10, vacío → `Héroe`).

### Borrar

Destructivo, por eso pide **escribir el nombre**:
- Diálogo `BORRAR PERSONAJE`: `Vas a borrar a NOMBRE (Clase, nivel N).
  No se puede deshacer.` y `Sus armas, materiales, pociones y créditos
  se pierden. Si quieres conservar algo, pásalo antes al ALIJO.`
- `BORRAR` (rojo) solo se habilita cuando el texto escrito coincide con
  el nombre (sin distinguir mayúsculas ni espacios de los extremos).
- El elegido pasa al primero que quede; si no queda ninguno, el
  creador.
- El alijo no se toca.

## 3. Alijo compartido

- **3 pestañas de 8 × 6** casillas (`Stash.tabs`, `columns`, `rows`: 144
  casillas), compartidas por todos los personajes de la cuenta:
  `GENERAL I`, `GENERAL II` (cualquier cosa que vaya al alijo) y `ECOS`
  (`Stash.ecoTab`, v0.11.1): solo Ecos y materiales de endgame (Ancla
  Temporal, Fragmentos del Abismo, Esencia del Abismo:
  `Stash.isEndgame`). Capacidad total 144: 96 generales + 48 de endgame
  (un Eco por casilla; los materiales apilan hasta 999 en una casilla).
  Las cuentas viejas (2 pestañas) cargan igual: sus casillas 0–95 son las
  mismas.
- Se abre **fuera de la sesión** con `ALIJO` desde la lista de personajes
  (pantalla `ALIJO COMPARTIDO`) y **dentro de la partida** (§ 3.2). Las
  dos usan el mismo tablero (`StashBoard`): a la izquierda el inventario
  del personaje (equipada aparte, grilla 8 × 5, barra de pilas), a la
  derecha el alijo con sus pestañas (`DsTabBar`, insignia `usadas/48`).
  Cada lado tiene su buscador (`DsSearchField`): lo que no coincide se ve
  atenuado. Mismas casillas, íconos, colores y fichas que el inventario.
- Mover: clic elige (borde dorado) y el botón de abajo lo pasa al otro
  lado (`AL ALIJO >` / `< AL INVENTARIO`); doble clic = mover directo;
  clic derecho = menú con `Guardar en alijo` / `Sacar al inventario`.
  Con algo del alijo elegido, clic en una casilla vacía del alijo lo
  cambia de lugar (nada que no sea endgame entra a la pestaña ECOS); lo
  mismo dentro de la grilla del personaje (`InventoryRules.move`).
- Motivos de bloqueo: el botón desactivado lleva el motivo en su
  tooltip y la línea de estado lo dice en rojo; la ficha de una casilla
  que no puede ir al alijo suma `No va al alijo: <motivo>`.
- Fichas del mouse de las armas (v0.13.1): **las mismas que el
  inventario** (`itemHoverTip`, ui_style.md § "Tooltips cortos"): una
  columna `HoverCompareCard` (la que usás: resumen + plegables),
  atravesable, Alt detalle, Shift la equipada, clic fija. Cada grilla
  tiene su `RetroTipArea`: desde su borde de arriba hasta el pie de las
  dos grillas y de ancho todo su lado sin llegar a la otra grilla (nunca
  tapa la otra grilla ni los botones).
- `MOVER TODO AL ALIJO` (siempre visible): lleva en **una** operación
  todo lo movible (`StashRules.movableTokens`: armas no protegidas, Ecos
  y pilas de materiales; nunca la equipada, la última arma inicial ni las
  pociones), respetando la capacidad. Resultado en una línea:
  `Movidos N` o `Movidos N · Quedaron M: alijo lleno`.
- Modo `ELEGIR`: clic marca / desmarca casillas de **un** lado (marcar en
  el otro lado limpia las marcas), contador `N elegidos`, `MOVER
  ELEGIDOS` (del inventario) o `SACAR ELEGIDOS` (del alijo) y `CANCELAR`.
  Misma línea de resultado (`StashRules.depositMany` / `withdrawMany`).
- Qué se puede guardar:
  - **Armas**: una casilla cada una. No se pueden guardar la **equipada**
    ni la **última arma inicial** de la clase (`InventoryRules.isProtected`,
    motivo `Equipada` / `Arma inicial`). Van a la primera casilla libre de
    la pestaña general a la vista (si no hay, la otra general); `Alijo
    lleno` si no hay lugar.
  - **Materiales**: se apilan en **una casilla por tipo**, hasta **999**
    (el personaje sigue con su tope de 99). Guardar mueve toda la pila
    (lo que entre). Sacar mueve lo que entre en el personaje; el resto
    queda en el alijo. Los de endgame van primero a la pestaña ECOS.
  - **Ecos**: una casilla cada uno, sin protecciones; primero a la
    pestaña ECOS y, si está llena, a las generales. Al cargar pasan por
    `EcoRules.sanitize`.
  - **Pociones** de vida y de maná: **no** (`Las pociones no van al
    alijo`).
  - **Créditos**: siguen siendo **de cada personaje**.
- Sacar del alijo valida con `InventoryRules.cannotReceive`: `Inventario
  lleno`, `Máximo 99`. El arma recibe un `uid` nuevo del personaje. No se
  miran requisitos de nivel ni de atributos.
- Cada movimiento guarda la cuenta (personaje + alijo juntos, una
  escritura).
- Al cargar, los objetos del alijo pasan por `ItemRules.sanitize`; los
  inválidos se descartan y dos pilas del mismo material se juntan.

### 3.1 Responsivo (v0.13.1)

Con texto Grande / Enorme a 1280 px el tablero se salía del panel a lo
ancho. Como el inventario (panels.md § Inventario, "Cambios v0.12.0"):
- Un `LayoutBuilder` elige con `stashLayout(ancho, sideMin)` (`sideMin`
  = 300 px por el factor de texto): **lado a lado** si entran las dos
  grillas a escala 1 y cada lado mide al menos `sideMin`; si no,
  **apilado** (inventario arriba, alijo abajo).
- La casilla es 44 × k (k en cuartos hasta ×2; por debajo de 1, la que
  entre). Cada lado mide lo que su grilla; el buscador, la fila
  Equipada / Créditos, el encabezado ALIJO y las pestañas (un `Wrap`,
  ya no el `TabBar` desplazable) bajan de línea dentro de ese ancho. La
  barra de botones (MOVER TODO, ELEGIR...) es un `Wrap`.
- Nunca más ancho que el panel: sin scroll horizontal; a lo alto, el
  scroll del panel.
- Zona de tooltip por grilla: lado a lado, como antes (su lado sin
  llegar a la otra grilla); apilado, todo el ancho, del borde de arriba
  de su grilla hasta antes de la grilla del alijo (inventario) o hasta
  el pie (alijo).
- Test: `test/features/characters/stash_responsive_test.dart`
  (1024×600 a 1920×1080, texto Normal / Grande / Enorme, dentro y fuera
  de partida).

### 3.2 Alijo en partida (v0.12.1, protocolo 22)

- Se abre en el **lobby y en misión, fuera de batalla** (modos `lobby` y
  `field`; nunca en batalla, preparación ni resultado: si el modo cambia,
  el panel se cierra). Accesos: botón `ALIJO [B]` del HUD (junto a
  `MENÚ`), tecla **B**, botón `ALIJO` en la barra de PERSONAJE →
  INVENTARIO y `Guardar en alijo` en el menú de clic derecho de cada
  objeto del inventario. Panel `WorldPanel.stash` con el mismo
  `StashBoard`.
- El alijo es **local de la cuenta** de cada jugador: solo su dueño lo ve
  y lo toca; nunca viaja por la red (el host no lo conoce). Lo que viaja
  es la parte del **perfil**, que en partida es del host.
- Acciones (cliente → host), una por operación, también en lote:
  - `{"t":"stashPut","op":<id>,"it":[{"tok":<token>,"n":<cant>}...]}`:
    sacar del perfil en la sesión esas piezas (uid de arma / Eco o
    `mat:<m>`; `n` solo en pilas, por defecto 1).
  - `{"t":"stashTake","op":<id>,"d":[<LootDrop>...]}`: sumar al perfil
    lo que el cliente saca de su alijo.
  - Hasta `StashPutAction.maxItems` (160) piezas. `op` es único por
    operación (`<jugador>-<n>-<µs>`, ≤ 48 caracteres).
- El host valida cada pieza: modo `lobby`/`field`, humano (no un
  compañero), el objeto existe, no es la equipada ni la última arma
  inicial (`InventoryRules.take`), no es poción ni el Eco que se está
  votando; para sacar, cada pieza se sanea (`ItemRules.sanitize`,
  `EcoRules.sanitize`) y tiene que entrar entera (`cannotReceive`). Las
  piezas válidas se aplican, las otras quedan `null`. La capacidad del
  alijo la valida el cliente antes de mandar (es el único que lo
  conoce): solo manda lo que entra (`depositMany` como ensayo).
- Confirmación: el host anota `op` en `SessionPlayer.stashAcks` (últimas
  32) con lo que se movió por pieza; viaja en el snapshot como
  `sk: [{"id","put"?,"d":[drop|null...]}]`, **en el mismo mensaje** que el
  perfil ya cambiado.
- Orden de escritura (sin duplicados ni pérdidas): el cliente no toca su
  alijo al mandar. Al ver su `op` en `sk`, aplica al alijo lo confirmado
  (`StashRules.store` / `unstore`) y escribe **alijo + perfil del
  snapshot en una sola escritura** de la cuenta (`StashStore.commit`),
  antes de cualquier otro guardado de ese paso.
- Idempotencia: un `op` ya anotado no se vuelve a aplicar (el host lo
  ignora). El cliente reenvía la operación sin confirmar cada 1 s (hasta
  5 veces, mismo `op`); después la da por no hecha. Una sola operación
  en curso por vez (los botones dicen `Esperando...`).
- Desconexión a mitad: la operación pendiente se descarta. Lo guardado
  en disco es siempre el último snapshot recibido: si no llegó la
  confirmación, tampoco llegó el perfil cambiado, así que el objeto sigue
  en el inventario y no en el alijo (lo que cambió en la copia del host
  se pierde con la sala, como siempre al caerse).
- Jugando solo o como host, el mismo camino corre local (la confirmación
  está en el estado al instante).
## 4. Desvíos / pendientes

- Sin arrastrar y soltar entre grillas (clic + botón, doble clic o clic
  derecho).
- Sin elegir cuántos materiales mover (se mueve la pila, lo que entre).
- El Atlas del Tiempo (endgame.md § 2) va a vivir en la cuenta junto al
  alijo cuando se implemente.

## 5. Atlas del Tiempo (v0.4.0)

`Account.atlas` (JSON `atlas`, opcional: una cuenta v0.3 carga con el
Atlas vacío y no lo escribe hasta tener algo) guarda el Atlas del Tiempo
compartido por todos los personajes: nodos tomados y primeras veces.
Al leer pasa por `AtlasRules.sanitize`. La sesión lo usa a través de
`AtlasStore` (`AccountAtlasStore`); ver docs/specs/ecos_atlas.md § 5.


## 6. Party jugando solo (v0.8.1)

Spec completo: `solo_party.md`. Resumen de lo que toca a la cuenta:
- Clave opcional `party` en `account.json`: `{"c": ["c2","c4"], "auto":
  ["c4"]}` (compañeros en orden y los que tienen AUTO). Una cuenta sin
  ella carga igual (sin party). `Account.companions` la sanea: ranuras que
  existen, sin repetir, **nunca el elegido**, hasta 3. Elegir como líder
  a un compañero lo saca de la party; borrar un personaje también.
- Título: debajo de los botones, `PARTY: tú + N` con un botón por cada
  otro personaje (`Nombre · Clase · Nv X`); se guarda al tocar.
- Guardado (invariante § 1.4 para **cada** miembro): `AccountPartyStore`
  (`PartyStore`) sobre el mismo `AccountRepository`; cada compañero se
  escribe en **su** ranura (`replace(slotId, …)` + `last`), nunca en la
  del elegido, con las mismas reglas que el líder (cada 2 s si cambió, fin
  de misión, pueblo, al sacarlo de la party, `saveNow` al salir, error
  visible y reintento). Pruebas:
  `test/features/characters/party_persistence_test.dart`.
