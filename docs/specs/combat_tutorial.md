# Spec: Tutorial de combate — v0.9.7 (implementado, ver § 8; falta OK del dueño)

Pedido del dueño: un tutorial de verdad en el overworld, junto a la
armería, con un jefe de práctica. Tiene que explicar todo **en base a lo
que pasa en la pelea**, no con paredes de texto, y se juega en
cooperativo o, si estás solo, solo o con compañeros. Todos ven el mismo
paso al mismo tiempo. Es obligatorio antes de la primera misión.
Depende de combo_balance.md (Pulso, precondiciones, encadenar, quiebre,
Convergencias).

## 1. Dónde y cómo se entra

- Corrección del dueño: es una **misión más** del sello del lobby (el de
  la Torre del Tiempo y el portal), llamada **TUTORIAL: Ecos de práctica**, primera en la
  lista de misiones. No hay cartel aparte.
- Al elegirla, el sello ofrece:
  - **En grupo:** si hay más jugadores en la sala, solo el host puede
    iniciarlo y entran todos los de la sala.
  - **Solo**, o **Solo con compañeros** (los de la party, solo_party.md).
  - **Repetir**, que siempre está disponible, también después de
    completarlo.
  - **Glosario**, que abre el § 5 sin pelear.
- Es texto mecánico, sin lore.

## 2. Obligatorio antes de la primera misión

- **Por cuenta, no por personaje** (corrección del dueño): la cuenta
  guarda `tutV`, la última versión del tutorial que completó (en el
  archivo de cuenta, account_store, no en `PlayerProfile`). Crear un
  personaje nuevo no lo vuelve a pedir.
- **Etapas versionadas.** Cada etapa del § 4.2 tiene `desde: N`, la
  versión del combate en que apareció o cambió de verdad. La versión
  vigente es `kTutorialVersion`, el máximo de esas `desde`.
  - **Cuenta nueva** (`tutV = 0`): hace el tutorial **completo**, con
    todo lo de la última versión.
  - **Cuenta con `tutV` viejo:** hace un **tutorial de cambios**, solo
    con las etapas cuya `desde` sea mayor que su `tutV`, más la etapa
    libre. Arranca con "Ya hiciste el tutorial. Esta pelea de prueba
    muestra lo que cambió en vX: …".
  - Solo se sube `desde` cuando cambia el combate **básico** (algo que de
    verdad hay que volver a ver). Un ajuste de números no lo cambia.
- **En grupo** se juegan las etapas que le faltan a **alguno**. Los que
  ya las sabían las hacen igual (cada etapa la prueba cada jugador y las
  parejas los necesitan).
- Para **elegir una misión en el sello**, todos los de la sala tienen
  que tener `tut` vigente. Si falta alguno:
  - todas las misiones salen desactivadas menos **TUTORIAL: Ecos de práctica**, con el
    aviso "Primero, todos tienen que hacer el TUTORIAL. Falta: Ana,
    Beto".
- Los que ya lo hicieron entran igual al tutorial grupal, porque hacen
  falta para los combos. Para ellos la bandera no cambia.
- Lo completa **cada cuenta** que llega al final (pasa a
  `tutV = kTutorialVersion`). Si alguien se desconecta antes del final,
  no lo completa.
- El sello sabe el `tutV` de cada jugador porque viaja en el `hello`
  (cambio de protocolo).

## 3. La pelea de práctica

- **Autómata de entrenamiento** (jefe dummy): mucha vida y, en las etapas
  con guion, su vida nunca baja de 1 (no muere, el log dice "el autómata
  se recompone"). En ENTRENAR (§ 4.4) sí puede caer. Tiene barra de
  quiebre y una ULT de práctica que pega poco y nunca mata (deja en 1 de
  vida).
- Afinidades fijas para enseñar: débil al Fuego, resistente a lo físico.
  Al lado tiene 2 **Autómatas chicos** para mostrar las habilidades de
  área; se reponen solos.
- **Dentro del tutorial la build del jugador no existe** (v0.9, pedido del
  dueño). Cada personaje, humano o compañero IA, recibe un **kit de
  práctica** que *reemplaza* todo: clase, arma, árbol, equipo y ascensión
  (`TutorialRules.kitOf`, `kTutorialKit`):
  - stats iguales para todos: 150 de vida, 40 de MP, VEL 10, ATQ 18, MAG 18
    y DEF 4, sin crítico;
  - arma `espada` (física: su Quebrar es la física). Las afinidades las
    ponen las habilidades;
  - **kit de tutorial igual para todos (v0.9.7, sin roles):** Bola de
    Fuego (Fuego + Quemadura), Púa Fugaz (Instante + Veneno),
    Rompearmaduras (cuesta 1 de Pulso), Embestida (llena la barra),
    Estocada Firme ("puede quebrar"), Ponzoña Convergente (detona
    Quemadura), Ignición Convergente (detona Veneno), Llamarada (área) y
    la Quebrar del arma (`kTutorialSkills` + `kitSkills()`). Atacar,
    Defender y Pasar los tienen todos;
  - de la persona solo quedan el nombre y el dibujo de su clase;
  - quien se une con la pelea empezada recibe el mismo kit;
  - en ENTRENAR el kit de tutorial se cambia por un **kit de entrenamiento**
    (§ 4.4);
  - al salir, la batalla se descarta y la build vuelve intacta: el kit
    vive solo en `BattleState`.

  Antes de cada paso, el host repone el MP y el Pulso que pide y cumple
  la precondición si falta (`prepare`). Un test recorre el guion
  completo con 1, 2 y 4 humanos o con 3 compañeros IA y verifica que en
  cada paso la habilidad del cartel está en el kit de quien actúa y está
  habilitada.
- No da XP ni loot, no consume pociones y la vida y el MP vuelven a como
  estaban al salir.

## 4. Guion por pasos (sincronizado)

### 4.1 Reglas de sincronía

- El **host** lleva el guion: `TutorialState { etapa, paso, orden de
  jugadores, intento }` viaja en el estado de la batalla, así que todos ven el
  mismo paso, el mismo cartel y el mismo resaltado.
- El orden de turnos es real (timeline), pero el guion **acomoda las
  velocidades** para que el que tiene que actuar sea el que tiene el
  turno. El cartel siempre dice **quién** actúa:
  - si es tu turno: "TE TOCA: usá Ignición sobre el autómata", con la
    habilidad iluminada y el resto desactivado, con el motivo en el
    tooltip;
  - si no es tu turno: "MIRÁ: Ana va a usar Ignición".
- Nunca hay un "me toca, pero no me sale nada": si es tu turno, el
  cartel dice qué hacer.
- **Sin límite de 30 s** durante el tutorial.
- Tests (v0.9.2): votación con 1, 2 y 4 humanos, con IA y con una
  desconexión; sin avance por tiempo (10 minutos de ticks con el cartel
  abierto); el panel no se superpone con la escena, el HUD ni el menú
  (rects, a 900×600, 1280×720 y 1920×1080).
- **Panel lateral fijo (v0.9.2, pedido del dueño: "los carteles tapan la
  pelea").** Nada del tutorial se dibuja encima de la escena. En el
  tutorial la arena se achica y el panel ocupa una columna a la derecha
  (`TutorialOverlay.panelWidth`: 24% del ancho, entre 180 y 320), así
  nunca se superpone con personajes, enemigos, números de daño, el HUD
  del grupo ni el menú. Muestra, de arriba abajo:
  - "Etapa N/10 · título" y el botón ≡ (menú del tutorial);
  - el cartel abierto: el de inicio de etapa ("EN ESTA ETAPA") o el de
    efecto ("LO QUE PASÓ"), con el rótulo de lo que señala ("→ barra de
    quiebre");
  - sin cartel: "AHORA" (quién actúa: TE TOCA / MIRÁ) y "ÚLTIMA ACCIÓN"
    (el último cartel de efecto, atenuado);
  - la votación: "Esperando: Beto", SIGUIENTE y "ESPACIO o Enter: leí y
    entendí" (o "Ya votaste SIGUIENTE.").
  - Desde v0.12 con el sistema de diseño (design_system.md § 10.3):
    `DsCard`, secciones `DsSectionHeader`, ≡ como botón de ícono y
    SIGUIENTE como botón principal (borde y texto dorados).
- El panel **resalta en el HUD** (borde naranja, sin negritas) la barra
  de MP en la etapa 2, los pips de Pulso en la 3, la 7 y la 8, y
  cuando el cartel abierto habla de MP o de Pulso (`hudFocus`).
- Después de cada acción, un **cartel de efecto** de hasta 3 líneas con lo
  nuevo de esa acción: Convergencia con el cálculo, quiebre, afinidad,
  tick de estados, estados que subieron, Instante, Pulso, MP,
  Defender/Pasar. Cada concepto se explica **una sola vez** por intento
  (`TutorialState.said`); las veces siguientes va solo el dato
  ("Quemadura +2 (tiene 4)." en vez de repetir qué hace la Quemadura).
- **Avanza por votación, no por tiempo (v0.9.2).** Cada cartel (de etapa
  o de efecto) espera a que **todos los humanos de la sala** toquen
  SIGUIENTE ("Leí y entendí"; ESPACIO / Enter). Solo = solo vos; los
  compañeros IA no votan. El voto es `tutOk` (uno por jugador; votar dos
  veces no cuenta): el host lo anota en `TutorialState.votes` y cierra el
  cartel con el último voto. Si alguien se desconecta deja de contarse
  (el host lo revisa en cada tick). No hay cierre a los 6 s ni ningún
  otro avance por tiempo en los carteles.
- **El autómata espera (v0.9.6).** Antes de que actúe (ataque, tick de
  estados, aviso o ULT de práctica), el panel abre un cartel "ATENCIÓN"
  que anuncia lo que va a hacer y espera el SIGUIENTE de todos; recién
  ahí actúa, y el cartel de efecto explica lo que hizo.
- En ENTRENAR no hay cartel que votar: el narrador cuenta lo que pasa
  (§ 4.4).
### 4.2 Etapas

Cada etapa es una "escena" corta.

**Cada jugador lo prueba él mismo (v0.9.7, pedido del dueño: "los roles
no tienen sentido").** No hay roles. Lo básico lo hace **todo**
jugador: en cada etapa, cada uno (en el orden de la sala, humanos y
compañeros IA) hace en su propio turno la acción que se enseña, con el
porqué en el cartel ("TE TOCA: atacar al autómata · el ataque básico da
+1 Pulso"); los compañeros IA también, anunciados ("MIRÁ: Caro (IA) va
a …"). Nadie mira sin hacer. El concepto se explica la primera vez y
después el cartel da solo el dato (`TutorialState.said`). Escala a N
jugadores: los pasos de una etapa se reparten al entrar
(`TutorialRules.turnsOf(etapa, n)` → `TutorialTurn(paso, índice)`).

**Cada etapa arranca limpia (v0.9.6).** Al entrar a una etapa el host
resetea el autómata (vida, barra de quiebre, Fisurado, estados, ULT), la
línea de tiempo (todos vuelven a su primer intervalo) y los recursos de
todos (vida y MP llenos, Pulso al inicial, sin estados ni ULT); después
pone lo propio de la etapa (ULT cargada de la 9, Autómatas chicos de la
10, que solo están en esa etapa).

| # | Etapa | Qué hace cada jugador, en su turno | Qué enseña |
|---|---|---|---|
| 1 | Línea de tiempo | Defender y mirar cómo se adelanta su turno | turnos, velocidad, Defender/Pasar |
| 2 | MP | Bola de Fuego (gasta MP) | MP: dura toda la misión, se recupera con pociones o al volver al lobby |
| 3 | Pulso | Ataque básico (+1 Pulso) y después Rompearmaduras (cuesta 1 de Pulso) | Pulso: de esa pelea (0-5), cómo se gana y sus usos (lista leída del catálogo); una habilidad puede pedir MP y Pulso ("3 MP  P2") |
| 4 | Instante | Púa Fugaz (Instante) y, en el mismo turno, ataque básico | Instante **no es un recurso**: no termina el turno |
| 5 | Afinidades | Ataque básico (RESISTE ×0.5) y Bola de Fuego (DÉBIL ×1.5) | debilidad, resistencia |
| 6 | Estados | Bola de Fuego (Quemadura, los stacks se suman); al final, anuncio y turno del autómata (tick) | estados, stacks, duración |
| 7 | Convergencia en parejas | Ver regla de parejas abajo | combos entre jugadores, precondición |
| 8 | Quiebre | Todos usan Embestida y la barra termina de llenarse: Fisurado (se explica). Después, por jugador: reinicio, barra llena sola, y quiebra él | barra de quiebre, Fisurado, Quebrar y "puede quebrar", quebrado (+50%, pierde turno) |
| 9 | ULT enemiga | Anuncio y aviso del autómata; cada uno Defiende; anuncio y ULT de práctica | aviso, cancelar, defender |
| 10 | Área | Llamarada (a todos) y Ponzoña Convergente (salpica) | área para preparar, salpicadura |

**Regla de parejas (etapa 7).** Con n jugadores en el orden de la sala
se arman n parejas en rueda: el jugador i **pone** y el i+1 (mod n)
**detona**. Así todos ponen un estado y todos detonan al menos una vez,
con cualquier n (con número impar alguien repite con otro compañero; con
1 solo, él pone y él detona; si juega solo con compañeros IA, la rueda
los incluye). Las parejas pares usan Quemadura (Bola de Fuego → Ponzoña
Convergente); las impares, Veneno (Púa Fugaz → Ignición Convergente).
Antes de cada pareja el autómata se reinicia (`TutorialResetStep`) con
los stacks justos para que el que pone complete lo que pide la
detonación (5): así el botón de detonar sale desactivado hasta que pone
su pareja. El cartel de la etapa lista las parejas.

**Quiebre uno por uno (etapa 8).** Primero una vez se llena la barra
entre todos (cada uno usa Embestida; lo que falte se completa solo) y el
cartel explica Fisurado. Después, para cada jugador: el autómata se
reinicia, se ve la barra vacía un instante (0.6 s) y se llena sola hasta
Fisurado sin que nadie pegue (`TutorialFillStep`); ese jugador quiebra
con **Quebrar o con Estocada Firme** (las dos valen: el paso tiene
`alt`). El cartel explica la primera vez que Quebrar viene de base y que
algunas habilidades también quiebran ("puede quebrar"); después solo
"Barra llena: FISURADO. Quiebra Ana." Quebrado (+50%, pierde su turno)
se explica la primera vez; después, el dato corto.

Después de la 10 viene la votación del § 4.4.

### 4.3 Repetir

- **Repetir tutorial** (votación del final, § 4.4) o **Repetir** en el
  menú ≡ juega el guion completo otra vez (intento + 1), igual para
  todos.
- **Repetir etapa** (menú ≡) vuelve al principio de la etapa actual (en
  ENTRENAR, reinicia ENTRENAR).
- Si alguien se equivoca de objetivo o de habilidad, no puede, porque
  solo está habilitado lo del paso. Si pasa algo imprevisto (por
  ejemplo, un crítico que llena la barra antes), el guion lo acepta y
  avanza. Si quien tenía el paso se desconecta, el paso se saltea.

### 4.4 Fin del guion: votación y ENTRENAR (v0.9.6)

- Al terminar la última etapa con guion, cada cuenta que sigue en la
  pelea **completa** el tutorial (`tutV = kTutorialVersion`,
  `TutorialDoneEvent`) y, sin salir de la misión, el panel abre una
  votación: **Repetir tutorial**, **Ir a ENTRENAR** o **Salir** (v0.9.7:
  sin elección de roles).
- **Regla de las votaciones (la más simple):** cada humano de la sala
  elige (puede cambiar su voto); se hace lo elegido cuando **todos** los
  humanos eligieron **lo mismo**. Los compañeros IA no votan; quien se
  desconecta deja de contarse. El panel muestra lo que eligió cada uno
  ("Ana: IR A ENTRENAR", "Beto: eligiendo…") y, si todos votaron pero
  distinto, "Falta acuerdo".
- **ENTRENAR (libre):** se resetea todo (vida, MP, Pulso, estados, línea de
  tiempo, autómata) y cada uno recibe un **kit de entrenamiento**. Son 4 kits (`kTrainingKits`); el jugador i de n suma los kits j
  con j mod n = i, así entre todos (o uno solo) está todo:

  | Kit | Habilidades | Para probar |
  |---|---|---|
  | 1 | Bola de Fuego, Llamarada | Quemadura, área |
  | 2 | Púa Fugaz, Ignición Convergente | Instante, Veneno, Explosión tóxica |
  | 3 | Lanza de Hielo, Embestida y ULT cargada | Congelación, quiebre, ULT |
  | 4 | Ponzoña Convergente, Quebrar | Combustión, Quebrar |

  Con 2 o más, Quemadura y Veneno quedan en jugadores distintos
  (Combustión y Explosión tóxica entre jugadores). Los compañeros IA
  juegan con su IA. El autómata **puede caer**; al caer, votación
  **Reiniciar** o **Salir**. Los jugadores siguen sin caer (práctica).
- **Narrador de ENTRENAR:** el panel muestra "LO QUE PASA" (las últimas 8
  líneas), generado desde los eventos reales del combate, con el porqué
  corto: "¡Combustión! (Beto puso 6 de Quemadura y Ana detonó con Veneno:
  6 × 2.5% de la vida = N de daño)", "Fisurado → Quebraste: pierde el
  turno y recibe +50%", "Golpe a la debilidad (×1.5)", "ULT: Ana usó …",
  "Encadenaste un Instante", "+1 Pulso (golpe a la debilidad)" / "(ataque
  básico)" / "(defender)", "−2 Pulso (Quebrar)", "Quemadura +2 (tiene 4)",
  el tick de estados y "¡Autómata de entrenamiento cayó!". Para nombrar
  a quien puso el estado, el host anota quién lo subió por última vez.

## 5. Glosario (siempre a mano)

Una página del panel del entrenamiento y del menú de pausa en batalla,
con una entrada corta por concepto y un ícono:
- Línea de tiempo;
- MP (maná): dura toda la misión, no vuelve solo entre peleas;
- Pulso (corto, pedido del dueño v0.10.x): solo qué es ("puntos de
  cada pelea, de 0 a 5; las habilidades fuertes lo piden") y cómo se
  gana ("+1 al empezar tu turno, con ataque básico, golpe a la debilidad
  o reacción, y al defender"). Sin la lista de habilidades que lo usan;
  la intro de la etapa de Pulso tiene como máximo 2 líneas;
- Precondición;
- Instante (no es un recurso: es un tipo de habilidad);
- Afinidades (débil, resistente, inmune) y tope sin debilidad;
- cada estado (Quemadura, Veneno, Congelación, Aturdido, Sagrado,
  Mojado, Cargado, Marca);
- Reacciones y Convergencias (con las tablas de elemental_reactions.md y
  combo_balance.md);
- Quiebre, Fisurado y Quebrar;
- ULT propia y enemiga;
- Dúo.

Los textos salen de los mismos datos que usa el combate: no se escriben
números a mano.

**Costo en el menú (v0.9.6).** En HABILIDADES el Pulso se ve igual que el
MP pero en dorado: "4 MP", "P2" o "3 MP  P2" en cada fila que lo pida; en
el detalle/tooltip, "3 MP · 2 Pulso" (`skillCostMarkup`,
`skillCostLongMarkup`). Desde v0.10.x el dorado es el mismo token que la
fila PULSO de la tarjeta (`ProtoColors.gold`) en todos los estados de la
fila (normal, elegida y desactivada, atenuado).

## 6. Red

- `TutorialState` viaja en el snapshot de batalla (cambio de protocolo).
- Las acciones de los clientes las valida el host contra el paso
  actual: si no corresponden, se rechazan.
- Al completarse, el host manda `TutorialDoneEvent` y cada cliente marca
  su perfil y lo guarda.
- Si el host se va, el tutorial se corta y nadie lo completa.

## 7. Tests

- Guion completo a 1, 2, 3 y 4 humanos y con compañeros IA: todos
  terminan con `tut` y **cada uno** defendió, atacó, gastó MP, ganó y
  gastó Pulso, encadenó una Instante, vio RESISTE y DÉBIL, puso un
  estado, puso y detonó una Convergencia y quebró al menos una vez (el
  caso de 3 cubre el impar).
- Parejas con n = 1..5: todos ponen y todos detonan.
- Quiebre: reinicio y barra llena sola antes de cada jugador; con 2 o
  más humanos se quiebra con Quebrar y con Estocada Firme.
- Votación del final sin roles: Repetir tutorial, Ir a ENTRENAR, Salir.
- El sello bloquea si alguien no tiene `tut` vigente.
- El autómata nunca muere y la ULT de práctica nunca mata.
- Las acciones fuera del paso se rechazan.
- Al salir, nada del tutorial queda en el perfil: ni las habilidades
  prestadas, ni vida, MP, XP o loot.

## 8. Implementación (v0.9)

Código: `game_engine/models/tutorial.dart` (`TutorialState`,
`TutorialCard`, etapas y pasos, `kTutorialVersion`),
`game_engine/rules/tutorial_rules.dart` (guion, reparto de pasos, validación,
carteles, glosario), `game_engine/rules/session_engine_tutorial.dart`
(el host lleva el guion), `game_engine/models/tutorial_store.dart` +
`AccountTutorialStore` (cuenta), `features/tutorial/presentation/` (sello,
cartel, menú, glosario). Tests: `test/game_engine/tutorial_test.dart`,
`test/features/tutorial/`.

Decisiones tomadas al implementar (el spec manda; esto completa lo que
no decía):

- **Bandera.** `tutV` vive en `account.json` junto a `bv` (se escribe solo
  si es > 0; nunca baja). `kTutorialVersion = 3` desde v0.9.7: sin
  roles, cada jugador prueba todo, 10 etapas, todas con `desde: 3`, así
  quien tenía `tutV` 1 o 2 vuelve a ver el tutorial entero como tutorial
  de cambios (2 desde v0.9.6). El motor recibe la `tutV` de cada jugador en
  `addPlayer(..., tutorialVersion)`; quien no la pasa (tests,
  herramientas, `SessionConfig` sin el dato) cuenta como vigente para no
  bloquear el sello por error. Los compañeros no cuentan para el bloqueo
  ni lo completan (la cuenta es la del líder).
- **Bloqueo.** El host rechaza proponer misión, Eco, Prueba o Jefe del
  Abismo mientras falte alguien. En la UI, el mostrador de misiones
  muestra el aviso en PROPONER; los paneles del Portal del Eco, de la
  Prueba y del Abismo todavía no muestran el motivo (pendiente).
- **Sello.** TUTORIAL es la primera fila del mostrador de misiones
  (elegida por defecto si falta hacerlo). Botones: EMPEZAR / REPETIR EN
  GRUPO (solo el host; si no, "Lo inicia el host"), SOLO, CON COMPAÑEROS
  (si hay party) y GLOSARIO. "Repetir" es volver a empezarlo: cada vez
  que se empieza en la misma sala sube el intento (`tutorialRuns`).
- **Habilidades prestadas.** En vez de cartas nuevas, el guion presta
  habilidades del catálogo, así números y textos salen de los datos:
  Bola de Fuego (Fuego + Quemadura), Embestida (física, mucho quiebre),
  Púa Fugaz (Instante + Veneno), Ignición Convergente (pide Veneno),
  Ponzoña Convergente (pide Quemadura), Llamarada (área), Rompearmaduras
  (Pulso), Estocada Firme ("puede quebrar") y la Quebrar base del arma.
  Todos reciben el mismo kit (§ 3); viven solo en el combatiente de la
  batalla.
- **Sin roles (v0.9.7).** `TutorialStage` tiene `head` (una vez),
  `steps` (cada jugador en orden), `tail` (una vez) y `kind` (`each`,
  `pairs`, `breakEach`). `TutorialRules.turnsOf` reparte los pasos con
  el largo de `TutorialState.order` (fijo al empezar); `currentActor` da
  quién actúa. Pasos automáticos nuevos: `TutorialResetStep` (reinicio
  entre parejas, sin cartel) y `TutorialFillStep` (barra llena sola, con
  cartel `fillCard`).
- **Etapa 6.** Un golpe de Veneno sobre la Quemadura dispara la
  Combustión, así que la etapa de estados usa solo Quemaduras (los stacks
  se suman) y el tick; las Convergencias se ven en la 7.
- **Acomodar turnos.** Antes de cada paso, el próximo turno del que
  actúa pasa a ser el primero de la línea de tiempo y el motor da el
  turno normal (procesa estados). El guion le repone MP y Pulso y, si la
  precondición del paso no se cumple (por ejemplo, Quebrar sin Fisurado),
  la cumple: nunca hay "me toca y no me sale".
- **ULT enemiga (etapa 9).** El autómata arranca con la ULT cargada; el
  cartel "ATENCIÓN" lo anuncia y espera la votación; avisa, todos
  Defienden, otro "ATENCIÓN" y la lanza. La rama "quebrarlo a tiempo la
  cancela" no se juega: la explica el cartel (pendiente: una variante con
  quiebre).
- **Área (etapa 10).** Los Autómatas chicos aparecen y no actúan.
- **Fin del guion y ENTRENAR (v0.9.6).** `TutorialState.phase`
  (`script`, `menu`, `train`, `trainOver`), `picks` (votos de la
  votación abierta), `narration` y `primers`. Acción
  `TutorialChoiceAction` (`tutPick`, `c`: `repeat`, `train`, `exit` o
  `restart`). Protocolo 17: `tut` lleva `ph`, `pk`, `nr`, `pr`; el
  cartel, `h` (rótulo "ATENCIÓN"); se fue `f`. Protocolo 18 (v0.9.7): se
  fueron la fase `roles`, `as` (roles elegidos) y los votos `roles` /
  `role:*`; entra `repeat`.
  Panel: sección "VOTACIÓN" con un botón por opción (el propio voto
  queda seleccionado) y quién eligió qué; en ENTRENAR, "AHORA" y "LO QUE
  PASA". Tests: `test/game_engine/tutorial_v097_test.dart`. Capturas:
  `tool/shots/v097_shots_test.dart` → `docs/release_shots/v0.9.7/`.
- **Autómata.** Usa el dibujo del Gólem, familia nueva "Autómata de
  práctica" (débil Fuego ×1.5, resiste físico ×0.5; oculta en el
  bestiario). Todos los combatientes del tutorial son "de práctica": la
  vida no baja de 1 (el log dice "el autómata se recompone"); la ULT de
  práctica es Diluvio Ácido con ATQ bajo.
- **Carteles (v0.9.2).** El de inicio de etapa sale de
  `TutorialRules.stageIntro` (1-3 líneas cortas, con los números de los
  datos, sin repetir el título que ya está en el panel); el de efecto, de
  `effectCard` (hasta 3 líneas, cada concepto explicado una vez). La
  flecha es un rótulo en el panel ("→ barra de quiebre"); el resaltado
  sobre el HUD existe para MP y Pulso (`HudHighlight`), el resto queda
  pendiente. Los dos se cierran solo por votación (§ 4.1). Protocolo 16:
  `tut` lleva `v` (votos), `la` (último cartel) y `sd` (conceptos ya
  explicados); se fue `cl` (segundos del cartel).
- **Pausa.** Repetir etapa, Repetir, Glosario y Salir están en el botón
  ≡ del panel lateral (no en el menú de pausa general). En grupo solo el
  host repite o sale.
- **Salir / host se va.** Salir vuelve al pueblo sin completar; si el
  host se va, la sala se cierra y nadie lo completa. Nada del tutorial se
  copia al perfil: vida y MP se llenan al volver, pociones, XP y loot no
  cambian.
- **Resaltado.** La acción del paso queda habilitada y el resto sale
  desactivado con "Ahora no: el paso es …"; no hay un brillo extra en el
  botón (pendiente).
