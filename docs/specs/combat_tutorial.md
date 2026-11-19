# Spec: Tutorial de combate — v0.9.6 (implementado, ver § 8; falta OK del dueño)

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
  ya las sabían actúan igual en su rol (hacen falta para los combos),
  con el cartel "Ya lo conocés: ayudá al grupo".
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
  - las habilidades son **exactamente** las de sus roles en el guion, en el
    orden del guion (tabla de abajo). Con menos de 4 personajes, uno hace
    varios roles y suma sus kits. Los roles rotan con cada intento (§ 4.3)
    y el kit se arma de nuevo;
  - de la persona solo quedan el nombre y el dibujo de su clase;
  - quien se une con la pelea empezada recibe el kit básico (Bola de
    Fuego y Embestida);
  - en ENTRENAR el kit de rol se cambia por un **kit de entrenamiento**
    (§ 4.4);
  - al salir, la batalla se descarta y la build vuelve intacta: el kit
    vive solo en `BattleState`.

  | Rol | Habilidades del kit | Etapas |
  |---|---|---|
  | Acumula (`acumula`) | Bola de Fuego, Llamarada | todas (clave en 3, 4, 6, 9) |
  | Detona (`detona`) | Embestida, Púa Fugaz, Ignición Convergente, Ponzoña Convergente | todas (clave en 1, 2, 5, 6, 9) |
  | Barra (`barra`) | Embestida, Bola de Fuego | todas (clave en 7) |
  | Quiebra (`quiebra`) | Quebrar | todas (clave en 7) |

  Atacar, Defender y Pasar los tienen todos: son las acciones de apoyo
  con las que cada rol actúa en las etapas que no son la suya (§ 4.2). Antes de
  cada paso, el host repone el MP y el Pulso que pide y cumple la
  precondición (`prepare`). Un test recorre el guion completo con 1, 2 y 4
  humanos o con 3 compañeros IA, en 4 intentos con los roles rotados.
  Verifica que en cada paso la habilidad del cartel está en el kit de
  quien actúa y está habilitada.
- No da XP ni loot, no consume pociones y la vida y el MP vuelven a como
  estaban al salir.

## 4. Guion por pasos (sincronizado)

### 4.1 Reglas de sincronía

- El **host** lleva el guion: `TutorialState { paso, rol por jugador,
  intento }` viaja en el estado de la batalla, así que todos ven el
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
  - "Etapa N/9 · título" y el botón ≡ (menú del tutorial);
  - el cartel abierto: el de inicio de etapa ("EN ESTA ETAPA") o el de
    efecto ("LO QUE PASÓ"), con el rótulo de lo que señala ("→ barra de
    quiebre");
  - sin cartel: "AHORA" (quién actúa: TE TOCA / MIRÁ) y "ÚLTIMA ACCIÓN"
    (el último cartel de efecto, atenuado);
  - la votación: "Esperando: Beto", SIGUIENTE y "ESPACIO o Enter: leí y
    entendí" (o "Ya votaste SIGUIENTE.").
- El panel **resalta en el HUD** (borde naranja, sin negritas) la barra
  de MP y los pips de Pulso en la etapa 2, los pips en la 5 y la 7, y
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

Cada etapa es una "escena" corta. Con un jugador, él hace todos los
roles; con compañeros, la IA hace los roles que no son tuyos y lo
anuncia.

**Nadie se queda mirando (v0.9.6, pedido del dueño).** Cada etapa tiene un
paso para cada uno de los 4 roles, así cada humano (y cada compañero)
actúa en cada etapa: los roles que no son los de la etapa hacen una
acción de apoyo (ataque básico, Defender, Pasar) con el porqué en el
cartel ("TE TOCA: atacar al autómata · el ataque básico no gasta MP y da
+1 Pulso"), y el rol de la etapa hace la acción clave al final.

**Cada etapa arranca limpia (v0.9.6).** Al entrar a una etapa el host
resetea el autómata (vida, barra de quiebre, Fisurado, estados, ULT), la
línea de tiempo (todos vuelven a su primer intervalo) y los recursos de
todos (vida y MP llenos, Pulso al inicial, sin estados ni ULT); después
pone lo propio de la etapa (Veneno de la 5, ULT cargada de la 8,
Autómatas chicos de la 9, que solo están en esa etapa).

| # | Etapa | Qué pasa (apoyo → clave) | Qué enseña |
|---|---|---|---|
| 1 | Línea de tiempo | Barra ataca, Quiebra defiende, Acumula pasa → Detona defiende y mira cómo se adelanta su turno | turnos, velocidad, Defender/Pasar |
| 2 | MP y Pulso | Quiebra ataca (+1 Pulso), Barra defiende (+1 Pulso), Acumula usa Bola de Fuego (MP) → Detona usa Embestida (MP) | MP: dura toda la misión, lo gastan casi todas las habilidades, se recupera con pociones o al volver al lobby. Pulso: de esa pelea (0-5), sube jugando (turno, ataque básico, debilidad o reacción, defender); se gasta en todas las habilidades del catálogo que lo piden (lista leída de los datos: Quebrar, las Convergentes, Dardo Tóxico, Rompearmaduras, Tiro Quebrantador…); una puede pedir los dos ("3 MP  P2") |
| 3 | Afinidades | Quiebra ataca y Detona usa Embestida (RESISTE ×0.5), Barra defiende → Acumula usa Bola de Fuego (DÉBIL ×1.5) | debilidad, resistencia, tope |
| 4 | Estados | Quiebra ataca (lo físico no detona), Detona defiende (el autómata va a pegar), Barra pone Quemadura → Acumula suma otra; anuncio y turno del autómata (tick) | estados, stacks, duración |
| 5 | Precondición e Instante | Barra y Quiebra atacan, Acumula defiende → Detona usa la Instante con Veneno y detona en el mismo turno | precondiciones; Instante **no es un recurso** |
| 6 | Convergencia en equipo | Quiebra ataca, Barra defiende, Acumula pone Quemadura → **otro** (Detona) la detona con Veneno; el cartel muestra el cálculo | combos entre jugadores |
| 7 | Quiebre | Acumula (debilidad) y Detona (Embestida) llenan la barra, Barra repite Embestida hasta Fisurado → Quiebra usa **Quebrar** | puntos de quiebre, Fisurado, Quebrar, +50% |
| 8 | ULT enemiga | Anuncio y aviso del autómata; los 4 Defienden (cada uno con el porqué); anuncio y ULT de práctica | aviso, cancelar, defender |
| 9 | Área | Quiebra ataca, Barra defiende, Acumula usa Llamarada (a todos) → Detona detona y salpica | área para preparar, salpicadura |

Después de la 9 viene la votación del § 4.4 (ya no hay "etapa libre"
de 3 acciones: la reemplaza ENTRENAR).

### 4.3 Repetir con roles rotados (o elegidos)

- Al terminar o con **Repetir** en el menú de pausa, el intento siguiente
  rota los roles: el que quebró ahora acumula, el que acumuló ahora
  detona, etc. El cartel inicial lo dice: "Intento 2: esta vez quebrás
  vos".
- **Repetir etapa** (pausa) vuelve al principio de la etapa actual (en
  ENTRENAR, reinicia ENTRENAR).
- "Repetir con otros roles" (§ 4.4) usa los roles elegidos por votación en
  vez de rotarlos.
- Si alguien se equivoca de objetivo o de habilidad, no puede, porque
  solo está habilitado lo del paso. Si pasa algo imprevisto (por
  ejemplo, un crítico que llena la barra antes), el guion lo acepta y
  avanza.

### 4.4 Fin del guion: votación y ENTRENAR (v0.9.6)

- Al terminar la última etapa con guion, cada cuenta que sigue en la
  pelea **completa** el tutorial (`tutV = kTutorialVersion`,
  `TutorialDoneEvent`) y, sin salir de la misión, el panel abre una
  votación: **Repetir con otros roles**, **Ir a ENTRENAR** o **Salir**.
- **Regla de las votaciones (la más simple):** cada humano de la sala
  elige (puede cambiar su voto); se hace lo elegido cuando **todos** los
  humanos eligieron **lo mismo**. Los compañeros IA no votan; quien se
  desconecta deja de contarse. El panel muestra lo que eligió cada uno
  ("Ana: IR A ENTRENAR", "Beto: eligiendo…") y, si todos votaron pero
  distinto, "Falta acuerdo".
- **Repetir con otros roles:** cada humano elige el rol que quiere
  probar (ACUMULA, DETONA, LLENA LA BARRA, QUIEBRA); se ve la elección de
  todos. Vale cuando todos eligieron y **sin roles repetidos entre
  humanos** ("Hay un rol repetido"). Los roles que nadie eligió van
  primero a quien no tiene rol (compañeros) y después, en orden, a todos.
  Se repite el guion completo (intento + 1) con esos roles y sus kits.
- **ENTRENAR (libre):** se resetea todo (vida, MP, Pulso, estados, línea de
  tiempo, autómata) y cada uno recibe un **kit de entrenamiento** (no de
  rol). Son 4 kits (`kTrainingKits`); el jugador i de n suma los kits j
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
- Pulso: de la pelea, pips 0-5, cómo se gana (turno, ataque básico,
  debilidad o reacción, defender) y **todos sus usos leídos del catálogo**
  (cada habilidad con costo de Pulso, `TutorialRules.pulseSkills`), con
  ejemplo de habilidad que pide MP y Pulso ("3 MP  P2");
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
`skillCostLongMarkup`).

## 6. Red

- `TutorialState` viaja en el snapshot de batalla (cambio de protocolo).
- Las acciones de los clientes las valida el host contra el paso
  actual: si no corresponden, se rechazan.
- Al completarse, el host manda `TutorialDoneEvent` y cada cliente marca
  su perfil y lo guarda.
- Si el host se va, el tutorial se corta y nadie lo completa.

## 7. Tests

- Guion completo a 1, 2 y 4 jugadores, en solo y con compañeros: todos
  terminan con `tut`.
- Rotar roles: en el intento 2 cada uno tiene otro rol.
- El sello bloquea si alguien no tiene `tut` vigente.
- El autómata nunca muere y la ULT de práctica nunca mata.
- Las acciones fuera del paso se rechazan.
- Al salir, nada del tutorial queda en el perfil: ni las habilidades
  prestadas, ni vida, MP, XP o loot.

## 8. Implementación (v0.9)

Código: `game_engine/models/tutorial.dart` (`TutorialState`,
`TutorialCard`, etapas y pasos, `kTutorialVersion`),
`game_engine/rules/tutorial_rules.dart` (guion, roles, validación,
carteles, glosario), `game_engine/rules/session_engine_tutorial.dart`
(el host lleva el guion), `game_engine/models/tutorial_store.dart` +
`AccountTutorialStore` (cuenta), `features/tutorial/presentation/` (sello,
cartel, menú, glosario). Tests: `test/game_engine/tutorial_test.dart`,
`test/features/tutorial/`.

Decisiones tomadas al implementar (el spec manda; esto completa lo que
no decía):

- **Bandera.** `tutV` vive en `account.json` junto a `bv` (se escribe solo
  si es > 0; nunca baja). `kTutorialVersion = 2` desde v0.9.6: las 9
  etapas se rehicieron (todos actúan, reinicio por etapa) y tienen
  `desde: 2`, así quien ya tenía `tutV = 1` vuelve a ver el tutorial
  entero como tutorial de cambios. El motor recibe la `tutV` de cada jugador en
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
  que se empieza en la misma sala sube el intento (`tutorialRuns`) y
  rotan los roles.
- **Habilidades prestadas.** En vez de cartas nuevas, el guion presta
  habilidades del catálogo, así números y textos salen de los datos:
  Bola de Fuego (Fuego + Quemadura), Embestida (física, mucho quiebre),
  Púa Fugaz (Instante + Veneno), Ignición Convergente (pide Veneno),
  Ponzoña Convergente (pide Quemadura), Llamarada (área) y la Quebrar
  base del arma. A cada jugador se le prestan las de sus roles; viven
  solo en el combatiente de la batalla.
- **Roles.** Cuatro: acumula, detona, llena la barra, quiebra. El rol r lo
  hace el jugador `(r + intento − 1) mod n` del orden de la sala; con
  menos de 4, uno hace varios.
- **Etapa 4.** Un golpe de Veneno sobre la Quemadura dispara la
  Combustión (Convergencia), así que la etapa de estados usa dos
  Quemaduras (los stacks se suman) y el tick; el Veneno se ve en la 5.
- **Acomodar turnos.** Antes de cada paso, el próximo turno del que
  actúa pasa a ser el primero de la línea de tiempo y el motor da el
  turno normal (procesa estados). El guion le repone MP y Pulso y, si la
  precondición del paso no se cumple (por ejemplo, Quebrar sin Fisurado),
  la cumple: nunca hay "me toca y no me sale". "Hasta Fisurado" repite
  el Golpe pesado hasta 3 veces y sigue igual.
- **ULT enemiga (etapa 8).** El autómata arranca con la ULT cargada; el
  cartel "ATENCIÓN" lo anuncia y espera la votación; avisa, los 4
  Defienden, otro "ATENCIÓN" y la lanza. La rama "quebrarlo a tiempo la
  cancela" no se juega: la explica el cartel (pendiente: una variante con
  quiebre).
- **Área (etapa 9).** Los Autómatas chicos aparecen y no actúan.
- **Fin del guion y ENTRENAR (v0.9.6).** `TutorialState.phase`
  (`script`, `menu`, `roles`, `train`, `trainOver`), `picks` (votos de la
  votación abierta), `assign` (roles elegidos), `narration` y `primers`.
  Acción `TutorialChoiceAction` (`tutPick`, `c`: `roles`, `train`,
  `exit`, `restart` o `role:<rol>`). Protocolo 17: `tut` lleva `ph`,
  `pk`, `as`, `nr`, `pr`; el cartel, `h` (rótulo "ATENCIÓN"); se fue `f`.
  Panel: sección "VOTACIÓN" con un botón por opción (el propio voto
  queda seleccionado) y quién eligió qué; en ENTRENAR, "AHORA" y "LO QUE
  PASA". Tests: `test/game_engine/tutorial_v096_test.dart`. Capturas:
  `tool/shots/v096_shots_test.dart` → `docs/release_shots/v0.9.6/`.
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
