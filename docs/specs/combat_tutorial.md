# Spec: Tutorial de combate — v0.9 (implementado, ver § 8; falta OK del dueño)

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

- **Autómata de entrenamiento** (jefe dummy): mucha vida y su vida nunca baja
  de 1 (no muere, el log dice "el autómata se recompone"). Tiene barra de
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
    Fuego y Embestida) para la etapa libre;
  - al salir, la batalla se descarta y la build vuelve intacta: el kit
    vive solo en `BattleState`.

  | Rol | Habilidades del kit | Etapas |
  |---|---|---|
  | Acumula (`acumula`) | Bola de Fuego, Llamarada | 3, 4, 6, 7, 9 |
  | Detona (`detona`) | Embestida, Púa Fugaz, Ignición Convergente, Ponzoña Convergente | 2, 5, 6, 9 |
  | Barra (`barra`) | Embestida, Bola de Fuego | 3, 4, 7 |
  | Quiebra (`quiebra`) | Quebrar | 7 |

  Atacar, Defender y Pasar (etapas 1, 2 y 8) los tienen todos. Antes de
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
- Después de cada acción, un **cartel de efecto** de 2-3 líneas que
  señala lo que pasó en pantalla (con una flecha a la barra o al estado):
  - "Ignición dejó 6 de **Quemadura** ↓ (cada turno le hace daño; si se
    acumula, se puede detonar)";
  - "La barra de **quiebre** subió 9 ↑ (golpe a la debilidad: +50%)";
  - "Ana ganó 1 de **Pulso** (golpe a la debilidad)".
- El cartel se cierra con ESPACIO, clic o al pasar 6 s. En grupo, el
  paso avanza cuando el que actuó termina; los demás pueden cerrarlo
  antes.

### 4.2 Etapas

Cada etapa es una "escena" corta. Con un jugador, él hace todos los
roles; con compañeros, la IA hace los roles que no son tuyos y lo
anuncia.

| # | Etapa | Qué pasa | Qué enseña |
|---|---|---|---|
| 1 | Línea de tiempo | Se ilumina la barra de turnos; el que es más rápido actúa antes; Defender y Pasar adelantan tu próximo turno | turnos, velocidad, Defender/Pasar |
| 2 | Maná y Pulso | Ataque básico (+1 Pulso), después una habilidad que gasta MP | qué es cada recurso y cómo se recupera |
| 3 | Afinidades | Golpe físico (RESISTE ×0.5) y golpe de Fuego (DÉBIL ×1.5); muestra el tope sin debilidad | debilidad, resistencia, tope |
| 4 | Estados | Dos Quemaduras se suman (un Veneno acá detonaría la Combustión; el Veneno se ve en la 5); se ve el tick al empezar el turno del autómata | estados, stacks, duración |
| 5 | Precondición y encadenar | "Detonar" aparece desactivado ("Necesita: 5 de Veneno"); una Instante que pone Veneno no termina el turno y en el mismo turno se detona | precondiciones, Instante, encadenar |
| 6 | Convergencia en equipo | Uno acumula Quemadura y **otro** la detona con Veneno; el cartel muestra el cálculo (`20 × 2.5% = 50%`) y los dos ganan Pulso | combos entre jugadores |
| 7 | Quiebre | Los demás llenan la barra (debilidad, Golpe pesado, aturdir); el autómata queda **Fisurado** y el último usa **Quebrar** | puntos de quiebre, Fisurado, Quebrar, +50% de daño |
| 8 | ULT enemiga | El autómata avisa su ULT; si se quiebra a tiempo se cancela, y si no, se ve cómo Defender reduce el daño | aviso, cancelar, defender |
| 9 | Área | Aparecen los Autómatas chicos: un área deja estados a todos y una Convergencia salpica | área para preparar, salpicadura |
| 10 | Libre | 3 turnos sin guion para probar; después, "¡Entrenamiento completo!" | — |

### 4.3 Repetir con roles rotados

- Al terminar o con **Repetir** en el menú de pausa, el intento siguiente
  rota los roles: el que quebró ahora acumula, el que acumuló ahora
  detona, etc. El cartel inicial lo dice: "Intento 2: esta vez quebrás
  vos".
- **Repetir etapa** (pausa) vuelve al principio de la etapa actual.
- Si alguien se equivoca de objetivo o de habilidad, no puede, porque
  solo está habilitado lo del paso. Si pasa algo imprevisto (por
  ejemplo, un crítico que llena la barra antes), el guion lo acepta y
  avanza.

## 5. Glosario (siempre a mano)

Una página del panel del entrenamiento y del menú de pausa en batalla,
con una entrada corta por concepto y un ícono:
- Línea de tiempo;
- MP;
- Pulso;
- Precondición;
- Instante y encadenar;
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
  si es > 0; nunca baja). `kTutorialVersion = 1` (todas las etapas tienen
  `desde: 1`). El motor recibe la `tutV` de cada jugador en
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
- **ULT enemiga (etapa 8).** El autómata arranca con la ULT cargada,
  avisa, todos Defienden y la lanza. La rama "quebrarlo a tiempo la
  cancela" no se juega: la explica el cartel (pendiente: una variante con
  quiebre).
- **Área (etapa 9).** Los Autómatas chicos aparecen y no actúan.
- **Libre.** 3 acciones de jugadores con la línea de tiempo real; los
  compañeros actúan con su IA.
- **Autómata.** Usa el dibujo del Gólem, familia nueva "Autómata de
  práctica" (débil Fuego ×1.5, resiste físico ×0.5; oculta en el
  bestiario). Todos los combatientes del tutorial son "de práctica": la
  vida no baja de 1 (el log dice "el autómata se recompone"); la ULT de
  práctica es Diluvio Ácido con ATQ bajo.
- **Cartel de efecto.** Hasta 3 líneas generadas de los eventos y del
  estado antes/después (Convergencia con el cálculo, quiebre, afinidad,
  estados, Instante, Pulso, MP, Defender/Pasar). La flecha es un rótulo
  ("→ barra de quiebre"); falta dibujarla sobre la escena (pendiente). El
  cartel de efecto lo cierra quien actuó (o su líder si es un compañero)
  o se cierra solo a los 6 s; los demás lo cierran solo en su pantalla.
  El cartel de inicio de etapa lo cierra cualquiera.
- **Pausa.** Repetir etapa, Repetir, Glosario y Salir están en el botón
  "TUTORIAL ≡" de la batalla (no en el menú de pausa general). En grupo
  solo el host repite o sale.
- **Salir / host se va.** Salir vuelve al pueblo sin completar; si el
  host se va, la sala se cierra y nadie lo completa. Nada del tutorial se
  copia al perfil: vida y MP se llenan al volver, pociones, XP y loot no
  cambian.
- **Resaltado.** La acción del paso queda habilitada y el resto sale
  desactivado con "Ahora no: el paso es …"; no hay un brillo extra en el
  botón (pendiente).
