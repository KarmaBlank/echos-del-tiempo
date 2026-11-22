# Spec (APROBADO, implementado en v0.17.0): ULT v2 — 50 ULT de jugador y una ULT por jefe y élite

Pedido del dueño: "quiero 50 ULTs, repartidas en armas y en todos los
lugares donde se puedan conseguir ultis; los enemigos también: una ULT
por jefe o élite".

Estado: **APROBADO** por el dueño con las respuestas del § 6 (la 3 fue
reemplazada después por "las ULT nunca se pierden", § 2.1) e
**implementado en v0.17.0** (§ 7 cuenta cómo quedó). Asume el formato de animación FXA del
Editor (game_editor.md § 2.1, `assets/fx/<categoría>/<id>.fx.yaml`,
categorías `ult` y `enemy_ult`) y **no toca** lo que hace el paso 2 del
Editor (FxCatalog, rediseño de las 13 ULT de tipo de arma con ecos
translúcidos, tope ~2.6 s). Lore: solo docs/lore.md (ecos que llegan del
futuro o del pasado, futuro inmutable, pasado magitec).

## 1. Estado actual (código)

**Jugador**

- La ULT no cuesta MP: pide **100 de carga** (`Combatant.ult`, 0-100).
  Uso: `battle_engine.dart` (`UltimateCommand`: `if (sk == null || p.ult < 100) return false; p.ult = 0;`).
- Carga: por acción (`ultGain` + `dealtBonus` hasta 22, `battle_engine.dart`
  ~4205), por daño recibido (`taken / maxHp × 110`, ~1091 y ~3731),
  multiplicada por `1 + ultChargeBonus` (afijo **Impetuoso**,
  `ModStat.ultCharge`; procs `ultCharge` / `ultChargeParty` de árbol v6,
  ascensión y pasivas).
- Qué ULT tenés: `ultimateOf` (`battle_engine.dart` l. 40), en orden:
  1. ascensión (`kAscensionUltimates`, 8 ULT, `ascension_catalog.dart`);
  2. ULT propia del arma: mod "ULT: <nombre>" (`ItemInstance.ultId`, JSON
     `ul`) > legendario (`UniqueDef.ultId`) > base del Invocador
     (`kWeaponUltOf`) — `branch_ults_catalog.dart` (`ownWeaponUlt`);
  3. la del tipo de arma (`kAllUltimates` = `kUltimates` 9 + `kNewUltimates` 4
     = **13**, `skills_catalog.dart` l. 266-289).
- Además existen **144 ULT de camino** (`kBranchUltList`, branch_ults.md):
  generadas por campos de `SkillDef`, con el aspecto prestado de otra ULT
  (`kBranchUltLooks`), y salen como mod en armas Raras (8%) / Épicas (20%).
- Toda ULT **quiebra** a un Fisurado (break_and_enemy_ults.md § 0) y da
  12 puntos de quiebre; dúos y Convergencias también quiebran
  (combo_balance.md § 4-5). Pulso 0-5 e Instante: combo_balance.md § 5.2.
  Las ULT hoy no usan Pulso.
- Companion IA: `companion_ai.dart` l. 56 tira la ULT con 100.

**Enemigos**

- `EnemyDef.ultId` + `kEnemyUlts` (`enemies_catalog.dart` l. 321-455),
  `EnemyUltDef` (power, allTargets, status, delayAll, wipeBuffs,
  guaranteedCrit, extra, perAdd, turns).
- Carga: empiezan con 40 (jefes y élites), +25 por turno
  (`enemyUltPerTurn`), +100 × daño / vida (`enemyUltPerHp`, `_chargeUlt`).
- Telegrafiado: con 100 **avisa** y pierde la acción
  (`EnemyUltWarningEvent`, log "se prepara para…· Quiébralo, defiéndete o
  protégete"); en su turno siguiente la lanza (`_enemyUlt`). Un **quiebre**
  la cancela y la vacía (`cancelled = e.ultPending`, l. ~3166);
  `SkillDef.ultDrain` resta carga si aún no avisó.
- 15 jefes con ULT propia; los 5 del Abismo **repiten nombre** de la de
  su jefe base. **Todos los élites comparten** `eult_furia` (Furia Élite:
  poder 2.0, crítico seguro): `battle_engine.dart` l. 190
  (`final ultId = el ? kEliteUltId : d.ultId;`). El Heraldo de las Eras
  la trae fija aunque no sea élite.

## 2. Fuentes de ULT para jugadores

### 2.1 Modelo: repertorio + 1 ULT activa

- Cada personaje tiene un **Repertorio de ULT** (ids aprendidos, en el
  perfil) y **una ULT activa** elegida (`ultSel`). En combate se lanza
  solo la activa. Se elige en PERSONAJE (ficha de habilidades) fuera de
  combate; en el pueblo o en un campamento.
- Dos clases de ULT por su origen:
  - **De objeto** (armas Raras/Épicas con mod, legendarios/únicos): solo
    disponibles mientras el arma está equipada; no se aprenden. Si está
    equipada y es compatible, aparece en el selector.
  - **Aprendidas** (árbol, hazañas, Ecos/Atlas/Maestría, botín de jefe):
    quedan en el repertorio para siempre.
- **v0.20.9 (dueño): manda la elegida.** La ULT activa se usa con
  cualquier arma equipada: ni el arma ni el árbol la pisan. Solo `classes`
  la restringe (una ULT de otra clase sale gris). `weapons` queda como
  dato informativo. Las ULT del tipo de cada arma que el personaje tiene
  también se pueden elegir (`UltRules.ownedTypeUlts`, no se anotan en
  `uk`). Al obtener un arma con ULT propia sale el aviso «<arma> le dio a
  <jugador> la ULT <nombre>. Equipala desde el menú.»; el arma ya no la
  impone (branch_ults.md § 3).
- **v0.20.13:** elegir una ULT la anota en `uk` (también las de tipo de
  arma), así no depende de seguir teniendo el arma. Todo armado de
  `PlayerBuild` (bendiciones de santuario incluidas) conserva `ultSel` y
  `ultLevel`.
- **v0.20.15 (dueño): las ULT ya no dependen del arma.**
  - **ULT base:** cada clase tiene la ULT que traía su arma inicial
    (`UltRules.baseUltId`: Maga → Meteoro `ult_baculo`, Guerrero → la de
    espada, etc.). Está siempre en el repertorio y es la activa si no se
    eligió otra.
  - **Conseguir un arma enseña sus ULT en el momento** (`UltRules.taughtBy`):
    la propia (mod "ULT: …", legendario/único, tomo del Invocador
    `kWeaponUltOf`) **y la de su tipo** (decisión: un arma de un tipo
    nuevo enseña la ULT de ese tipo; reemplaza a `ownedTypeUlts`). Se
    anota en `uk`, sale el mensaje de sesión «<jugador>: ¡Nueva ULT:
    <nombre>!» y queda con la marca **NUEVA** (`un` en el perfil) hasta
    hacerle clic a su fila en PERSONAJE → ULT (v0.20.18; antes, al
    pasar el mouse, § 2.1.1); la pestaña ULT muestra
    la insignia NUEVA mientras haya alguna. Se desmarca con
    `SeenItemsAction` usando el id `ult:<id>` (sin acción nueva). La base
    nunca sale como NUEVA. Las de jefe/Ecos/hazañas también usan NUEVA.
  - **Combate** (`ultimateOf`): elegida (`ultSel`, solo la clase la
    restringe) > ascensión > ULT base. **El arma equipada nunca decide**
    (ni su tipo ni su ULT propia). Un `Combatant` sin build (enemigos,
    pruebas) sigue con la del tipo.
  - **El arma no muestra ULT**: tooltips, comparación, tienda, fusión,
    inventario y chips de habilidad ya no listan la ULT del arma ni el mod
    "ULT: …" (decisión: se quitó del todo, sin línea "Enseña…").
  - **Mods "ULT" en fusión/forja:** se conservan como dato (el arma sigue
    enseñando esa ULT a quien la consiga; el filtro de loot `Ult` sigue
    sirviendo) y el traslado queda como estaba; en combate no importa.
  - **Migración:** al normalizar el perfil (`ProgressionRules.normalize`)
    se absorben sin marca NUEVA la base y las ULT de las armas del
    inventario. El alijo no se recorre (vive en la cuenta, no en el
    perfil): esas ULT se aprenden al sacar el arma. `ultSel` se conserva.
  - **Travesía:** la run arranca con la ULT base de la clase (default) y
    las recompensas siguen usando `ultSel`.
- Orden si no hay `ultSel` (o es de otra clase): ascensión > ULT base de
  la clase (v0.20.15; antes base del arma > tipo de arma).
- **Las ULT nunca se pierden** (cambio del dueño, reemplaza la respuesta
  3): toda ULT que el personaje obtiene —también la de un arma con mod
  "ULT" o de un legendario— entra al repertorio permanente (`uk`) apenas
  la consigue; el arma es solo la fuente. Vender o desarmar el arma no
  la quita. Elegir/cambiar la activa es algo "de afuera" (PERSONAJE →
  ULT), sin consumir armas ni ULT. Se mantiene la compatibilidad por
  **tipo** de arma (una de espada se usa con cualquier espada equipada),
  no hace falta el arma concreta. No hay fusión ni grabado de ULT.
  Migración: las armas que el personaje ya tiene con ULT propia (de
  camino, v2 o del Invocador) suman esa ULT al repertorio.

### 2.1.1 Pestaña PERSONAJE → ULT (v0.20.18, dueño)

- **Disposición:** a la izquierda la lista; a la derecha la vista previa
  animada (§ 2.5) y, abajo de ella, la info de la ULT elegida (nombre,
  origen y tipos de arma, motivo si no se puede usar, cómo se consigue si
  falta, efecto, nivel y MEJORAR). En ventana angosta (< 760 px) la
  vista previa con su info va arriba de la lista.
- **ULT EQUIPADA:** sección fija arriba de la izquierda con la equipada
  (la elegida válida o, si no, la que usa el motor). No aparece repetida
  en la lista de abajo.
- **REPERTORIO:** debajo, separado: contador `Las 50: n/50` y `Jefes
  vencidos: x/10`, búsqueda por nombre (sin distinguir mayúsculas ni
  tildes) y cuatro menús: ARMA (tipos presentes), ORIGEN, ESTADO (Todas /
  Obtenidas / Faltan) y ORDEN. La lista incluye el repertorio y las ULT
  de las 50 que faltan (gris, `Falta · <cómo>`).
- **Origen** (`UltBrowseRules.originOf`, derivado de los catálogos): ULT
  base de la clase, Tipo de arma, Arma Rara / Épica, Camino, Legendario,
  Tomo, Ascensión, Hito del árbol, Hazaña, Ecos y Atlas, Botín de jefe.
- **Orden:** Más nuevas (por defecto: orden de obtención, la más nueva
  primero), Alfabético, Por nivel (mayor primero), Por origen y Por tipo
  de arma. En Más nuevas y Por nivel las obtenidas van antes que las que
  faltan; los empates, alfabéticos.
- **Orden de obtención:** `PlayerProfile.ultOrder` (JSON `uo`, aditivo y
  opcional). `copyWith` agrega al final cada id nuevo de `ultKnown`. Una
  partida vieja no lo trae y sus ULT cuentan como las más viejas. No
  cambia el protocolo (el perfil ya viaja como JSON tolerante).
- **Interacción:** el hover no hace nada (ni vista previa, ni info, ni
  NUEVA). Solo el clic elige una ULT: cambia la vista previa y la info y
  le saca la NUEVA (`SeenItemsAction` con `ult:<id>`, una vez). Equipar
  es el botón EQUIPAR de la info (gris fuera del pueblo o campamento o si
  la clase no la puede usar).
- **Ajustes:** filtros y orden (no el texto) se recuerdan por equipo en
  `game.json`, clave `ultBrowse` (`UltBrowsePrefs`).

### 2.2 Costo

- ~~Nuevo campo `SkillDef.ultCost` (60 / 80 / 100)~~ — revertido (§ 7):
  toda ULT pide la barra llena y la vacía.
- Las de 60 son más chicas o utilitarias; las de 100 son las fuertes.
  Regla de balance: valor esperado ≈ proporcional al costo
  (§ 3.2, script de medición).
- Algunas suman o piden **Pulso** (`pulse`) como sinergia, nunca como
  condición dura salvo que el texto lo diga.

### 2.4 Mejora de ULT (niveles 1-5)

Cambio del dueño. Cada ULT del repertorio tiene un **nivel por
personaje** (perfil `ulv`, aditivo; sin entrada = 1). Cada nivel suma
**+6%** a poder, disparo cargado, trampa, golpe diferido, poder por
aliado y escudos de la ULT (nivel 5 = ×1.24). La activa viaja con su
nivel en el `build` del combatiente (`ulv`).

| De → a | Créditos | Cristal de Era | Prisma Roto | Fragmento de Abismo* |
|---|---|---|---|---|
| 1 → 2 | 1000 | 1 | — | — |
| 2 → 3 | 2000 | 2 | — | — |
| 3 → 4 | 3000 | 3 | 1 | 1 |
| 4 → 5 | 4000 | 4 | 2 | 1 |

*Solo las 4 ULT de jefe con versión del Abismo (Engranaje Prestado →
Fragmento del Reloj, Coro Prestado → del Eco, Lamento Prestado → de la
Corona, Fin Prestado → de las Eras). Total por ULT a nivel 5: ₵10000,
10 Cristales, 3 Prismas (materials_economy.md § "Sumideros"). La mejora
es una acción del jugador (`ultUp`) que el host valida (la tiene, no
está al máximo, alcanzan créditos y materiales); fuera de combate. UI:
PERSONAJE → ULT, ficha con nivel, próximo efecto, costo y MEJORAR →
CONFIRMAR MEJORA / CANCELAR.

### 2.5 Vista previa animada (v0.19.1)

Pedido del dueño. Al lado del repertorio (ventana ancha, ≥ 760 px de
panel) o arriba de la lista (angosta) hay una **mini escena de
batalla** en loop de la ULT elegida en la lista o bajo el mouse (filas
del repertorio y de LAS 50 ULT), además del texto de siempre:

- Escena de 240 × 135 px: el personaje (sprite de su clase/ascensión
  con la silueta de su arma) y dos aliados a la izquierda, enemigos a la
  derecha. Objetivo según `skillReach`: 1 enemigo, TODOS (3), un
  aliado / vos (1) o el grupo (3).
- La animación es la de datos (`assets/fx/ult/<id>.fx.yaml`, o la de la
  ULT a la que se parece si es de camino) reproducida con el mismo
  `FxPlayer` que la batalla (ecos, estelas, formas, partículas,
  destellos); sin catálogo, una genérica de ecos. Pausa de 700 ms entre
  vueltas.
- Números de ejemplo después del primer impacto, con los stats reales
  del personaje y la ULT a su nivel (`ultPreviewSamples`, mismas
  fórmulas que el motor): daño (`ATQ/MAG × poder`, `×golpes`), cura
  `(MAG × poder + 6) × (1 + cura)`, `ESCUDO` (fracción de la vida máx.),
  estados, `QUIEBRE`, buffs / debuffs. Con el mouse sobre MEJORAR, los
  del próximo nivel.
- Liviana: un único `Ticker` mueve un reloj que solo escucha el lienzo
  (`CustomPainter(repaint:)` dentro de `RepaintBoundary`); ningún
  controlador ni la página se reconstruyen por frame. Se pausa con
  PAUSA / REPRODUCIR, cuando la ventana pierde el foco y cuando la
  pestaña no está a la vista (`TickerMode` / la vista se desmonta).
- Sonido apagado por defecto; `SONIDO: NO / SÍ` toca los cues de la ULT
  (pista `sound`, o preparación/descarga) y los impactos.
- En `flutter test` arranca en pausa (`UltPreviewPanel.autoplayOverride`).

Código: `features/combat/presentation/scene/ult_preview_scene.dart`
(organismo: escena, reloj, pintor), `features/characters/presentation/
ult_preview_panel.dart`, `features/characters/domain/
ult_preview_samples.dart`. Tests: `test/features/characters/
ult_preview_test.dart`.

### 2.3 Reparto de las 50

| Fuente | Cuántas | Cómo se obtienen |
|---|---|---|
| Armas Raras / Épicas (mod "ULT: …") | 12 | igual que hoy el mod de branch_ults (8% / 20%), pool por tipo de arma |
| Legendarios / únicos | 8 | `UniqueDef.ultId` fijo (únicos sin ULT hoy o nuevos) |
| Hitos del árbol | 8 | 2 por clase (guerrero, maga, paladín, tirador) al gastar 20 y 40 puntos en el árbol de la clase |
| Hazañas | 6 | recompensa de 6 hazañas nuevas (achievements.md § 2.5-2.7) |
| Ecos / Atlas / Maestría | 6 | nodos notables del Atlas (3), Maestría (2), Eco con modificador raro (1) |
| Jefes (botín) | 10 | "Botín de jefe": la 1ª victoria contra cada jefe base (o su versión del Abismo) la enseña |
| **Total** | **50** | |

## 3. Catálogo de 50 ULT de jugador

Convenciones: ids `ult2_*`. **Poder** como `SkillDef.power` (× ATQ o
MAG). "todos" = `allTargets`. Afinidad = elemento (Físico, Fuego, Hielo,
Veneno, Sagrado, Agua, Electro). Campos marcados **[nuevo]** requieren
motor (§ 5.4); el resto usa campos existentes de `SkillDef`. Todas
quiebran a un Fisurado y dan 12 puntos de quiebre (regla actual).
Dirección visual: FXA `category: ult`, `duration` ≤ 2600 ms; la firma
común son **ecos translúcidos** del lanzador o del arma que llegan
desfasados (del pasado o del futuro) y repiten el golpe.

Rol: D1 = daño a uno, DA = daño en área, C = control, S = soporte,
Q = quiebre, R = reacción/Convergencia.

### 3.1 Armas Raras / Épicas (mod) — 12

| # | id | Nombre | Arma | Afin. | Rol | Efecto | Costo | Visual (≤2.6 s) |
|---|---|---|---|---|---|---|---|---|
| 1 | ult2_ecoFilo | Eco del Filo | espada | Físico | D1/Q | 3 golpes × 1.05 (`hits: 3`), `breakBonus` +0.5 | 100 | tres ecos del espadachín cortan en abanico, 1 por golpe; 2300 ms |
| 2 | ult2_taladoEras | Talado de Eras | hacha | Físico | DA/Q | 1.7 a todos, `breakBonus` +0.6, retrasa 0.2 | 100 | hacha cae y deja una grieta con ecos del hachazo anterior; 2400 ms |
| 3 | ult2_lanzaInmovil | Lanza Inmóvil | lanza | Físico | D1/C | 2.6, `pierce` 0.5, retrasa 0.6 al objetivo | 100 | la lanza se queda clavada en el aire; su eco futuro la empuja; 2200 ms |
| 4 | ult2_flechaVuelve | Flecha que Vuelve | arco | Físico | D1 | 2.4 + `bounces` 2 (60%) | 80 | flecha y su eco de vuelta en trayectoria inversa; 2000 ms |
| 5 | ult2_disparoAnterior | Disparo Anterior | rifle | Físico | D1 | `charge` 1 turno; luego 5.0, crítico +0.3 | 80 | tiro sale del eco de un turno anterior; brillo en el cañón; 2100 ms |
| 6 | ult2_viroteDetenido | Virote Detenido | ballesta | Físico | C/Q | 2.2, Aturdido 1, debuff daño recibido +20% 2 t | 100 | virote frenado en el aire, ecos se apilan y lo sueltan; 2300 ms |
| 7 | ult2_milAyeres | Mil Ayeres | dagas | Veneno | D1 | 6 golpes × 0.55 al azar, crítico +0.25, Veneno 2 | 100 | seis ecos de las dagas en rombos traslúcidos; 2500 ms |
| 8 | ult2_brasaAntigua | Brasa Antigua | báculo | Fuego | DA/R | 1.8 a todos, Quemadura 2, `catalyst` 0.2 | 100 | runas magitec se encienden en el piso y estallan; 2400 ms |
| 9 | ult2_paginaRecuerda | Página que Recuerda | tomo | Hielo | C/R | 1.4 a todos, Mojado 1 + Congelación 1 (súbita sobre mojados) | 100 | páginas pasan solas; ecos de escarcha de una pelea vieja; 2300 ms |
| 10 | ult2_chispaRelojera | Chispa Relojera | varita | Electro | DA/S | 1.5 a todos, Cargado 1, adelanta aliados 0.2 | 100 | engranajes de luz giran y descargan; 2200 ms |
| 11 | ult2_muroAyer | Muro de Ayer | espada+escudo | — | S | escudo grupo 20% 3 t, `shieldReflect` 0.3 | 100 | muralla translúcida de un fuerte antiguo se levanta; 2000 ms |
| 12 | ult2_campanaPasado | Campana del Pasado | maza+escudo | Sagrado | S/C | 1.3 a todos, Sagrado 1, buff grupo defensa +20% 2 t | 100 | campanada con ondas concéntricas desfasadas; 2200 ms |

### 3.2 Legendarios / únicos — 8

| # | id | Nombre | Arma | Afin. | Rol | Efecto | Costo | Visual |
|---|---|---|---|---|---|---|---|---|
| 13 | ult2_yunqueTiempo | Yunque del Tiempo | martillo+escudo | Físico | Q | 3.4, Aturdido 1, `breakBonus` +1.0 | 100 | martillo y dos ecos golpean el mismo punto en sucesión; 2500 ms |
| 14 | ult2_relojPartido | Reloj Partido | tomo, varita | — | C | 1.0 a todos, retrasa 1.0, adelanta aliados 0.3 | 100 | esfera de reloj magitec se agrieta sobre los enemigos; 2400 ms |
| 15 | ult2_ultimaCuerda | Última Cuerda | arco, ballesta | Físico | DA | 1.6 a todos + `trap` 0.6 | 100 | lluvia de flechas que se quedan como trampas brillantes; 2300 ms |
| 16 | ult2_coronaRota | Hoja de la Corona Rota | espada, dagas | Físico | D1 | 3.2, `execute` 0.25, robo de vida 0.25 | 100 | eco de un rey caído cruza con la hoja; 2400 ms |
| 17 | ult2_pulsoMagitec | Pulso Magitec | rifle | Electro | S/DA | 1.4 a todos, Cargado 1; +2 Pulso a todo el grupo **[nuevo: `pulseParty`]** | 100 | anillo de energía de autómata se expande desde el arma; 2000 ms |
| 18 | ult2_mareaAntigua | Marea Antigua | báculo, varita | Agua | R/S | 1.3 a todos, Mojado 2, buff grupo crítico +15% 2 t | 100 | ola translúcida con siluetas de ruinas dentro; 2400 ms |
| 19 | ult2_baluarteAutomata | Baluarte Autómata | espada+escudo, maza+escudo | — | S | `protect`, escudo propio 40% 3 t, `shieldBurst` 0.8 | 100 | autómata fantasma se pone delante del portador; 2300 ms |
| 20 | ult2_dobleHorizonte | Doble Horizonte | lanza, hacha | Físico | DA/C | 1.6 a todos, retrasa 0.5 | 100 | barrido doble: el golpe y su eco del futuro un instante después; 2200 ms |

### 3.3 Hitos del árbol — 8 (aprendidas, por clase)

| # | id | Nombre | Clase | Afin. | Rol | Efecto | Costo | Visual |
|---|---|---|---|---|---|---|---|---|
| 21 | ult2_sangreEco | Sangre de Eco | guerrero | Físico | D1 | 2.6, robo de vida 0.4, cuesta 10% de vida (`hpCost`) | 80 | silueta roja del guerrero se superpone y golpea; 2000 ms |
| 22 | ult2_gritoRuinas | Grito de las Ruinas | guerrero | — | S | buff grupo ATQ +20% 3 t, adelanta aliados 0.25 | 80 | el grito hace vibrar ecos de estandartes antiguos; 1900 ms |
| 23 | ult2_bucleBreve | Bucle Breve | maga | — | C | 0.9 a todos, retrasa 0.6; **Instante** (`instant`) | 60 | rebobinado: los enemigos retroceden en ecos; 1800 ms |
| 24 | ult2_prismaPasado | Prisma del Pasado | maga | (el del estado) | R | 1.6 a todos, `detonate` 0.5 | 100 | prisma de cristal magitec refracta estados y los rompe; 2400 ms |
| 25 | ult2_luzAyer | Luz de Ayer | paladín | Sagrado | S | cura grupo 35%, revive 30% | 100 | luz baja en columnas; ecos de los aliados se re-forman; 2300 ms |
| 26 | ult2_sentenciaLejana | Sentencia Lejana | paladín | Sagrado | D1/Q | 2.8, Sagrado 2, `breakBonus` +0.5 | 80 | espada de luz que llega desde arriba y su eco futuro; 2100 ms |
| 27 | ult2_ojoFuturo | Ojo del Futuro | tirador | Físico | D1 | 3.8, crítico +0.5 | 100 | mira con el eco del impacto ya visible antes del tiro; 2200 ms |
| 28 | ult2_lluviaEcos | Lluvia de Ecos | tirador | Físico | DA | 8 golpes × 0.35 al azar, `pierce` 0.3 | 100 | proyectiles fantasmas caen desfasados; 2500 ms |

### 3.4 Hazañas — 6 (aprendidas, cualquier clase)

| # | id | Nombre | Hazaña (nueva) | Compat. | Afin. | Rol | Efecto | Costo | Visual |
|---|---|---|---|---|---|---|---|---|---|
| 29 | ult2_primerGolpe | Primer Golpe | ganar 25 peleas sin recibir daño el 1.er turno | cuerpo a cuerpo | Físico | D1 | 2.5; +50% si el objetivo tiene vida llena **[nuevo: `openerBonus`]** | 80 | eco que golpea antes que el portador; 1800 ms |
| 30 | ult2_cadenaEras | Cadena de Eras | quebrar 100 enemigos | cualquiera | Físico/arma | Q | 1.2 a todos, `breakBonus` +0.8 | 100 | cadenas translúcidas unen a los enemigos y se tensan; 2300 ms |
| 31 | ult2_lluviaEsquirlas | Lluvia de Esquirlas | cancelar 20 ULT de jefe | cualquiera | Físico/arma | C | 1.5 a todos, `ultDrain` 30 | 100 | esquirlas de reloj caen y vacían el brillo de carga enemigo; 2200 ms |
| 32 | ult2_custodioInstante | Custodio del Instante | salvar a 50 aliados con escudo | escudos | — | S | escudo 50% al más herido (`lowestAlly`, `allyShield`), `protect`, `cleanse` 2 | 80 | burbuja con un eco del aliado sano; 1900 ms |
| 33 | ult2_forjadoAyer | Forjado en el Ayer | forjar 10 armas a +10 | cualquiera | — | S | buff propio daño +30% 3 t, `selfTurn` 0.5 | 60 | yunque fantasma suena tras el portador; 1600 ms |
| 34 | ult2_remateEco | Remate del Eco | 200 rematadas | cualquiera | Físico/arma | D1 | 2.2, `execute` 0.35 | 80 | eco del golpe final llega primero; 1900 ms |

### 3.5 Ecos / Atlas / Maestría — 6 (aprendidas)

| # | id | Nombre | Fuente | Compat. | Afin. | Rol | Efecto | Costo | Visual |
|---|---|---|---|---|---|---|---|---|---|
| 35 | ult2_atlasAbierto | Atlas Abierto | nodo notable del Atlas | maga, tirador | varios | R | 1.7 a todos, Quemadura 1 + Congelación 1 + Veneno 1 | 100 | mapa estelar se despliega con tres corrientes; 2500 ms |
| 36 | ult2_eraSuspendida | Era Suspendida | nodo notable del Atlas | mágicas | — | C | 1.2, retrasa 1.4 a un objetivo, `ultDrain` 50 | 100 | el objetivo queda en un cubo de tiempo detenido; 2200 ms |
| 37 | ult2_anclaTemporal | Ancla Temporal | nodo notable del Atlas | guerrero, paladín | — | S | escudo grupo 30% 2 t, buff grupo defensa +30% 2 t | 100 | ancla de luz cae y fija ecos del grupo; 2100 ms |
| 38 | ult2_golpeMaestro | Golpe Maestro | Maestría 25 | cualquiera | Físico/arma | D1 | 3.0, crítico +1.0 | 100 | toda la party aparece en eco detrás del portador; 2400 ms |
| 39 | ult2_ecoDoble | Eco Doble | Maestría 50 | cualquiera | (la repetida) | S/D | repite la última habilidad del lanzador al 80% **[nuevo: `echoLast`]** | 80 | eco del portador repite su última animación en traslúcido; 2000 ms |
| 40 | ult2_loQueSera | Lo Que Será | Eco con modificador raro | cualquiera | — | D1/Q | marca: tras 2 turnos del objetivo recibe 4.0 y quiebra si está Fisurado **[nuevo: `delayedHit`]** | 100 | reloj sobre el objetivo; el impacto "ya pasó" en el futuro; 2300 ms |

### 3.6 Botín de jefe — 10 (aprendidas)

Etiqueta visible del origen: **Botín de jefe** (UltSource.boss, clave
`boss` sin cambios). No hay contador ni nada que juntar: la ULT se aprende
al vencer a ese jefe por primera vez. La palabra "Fragmento" queda
reservada a los Fragmentos del Abismo (abyss_bosses.md), que solo piden
los niveles altos de MEJORAR de 4 de estas ULT.

En la pestaña ULT de PERSONAJE (v0.20.6):

- Encabezado de la sección: `Jefes vencidos: X/10`. Un jefe cuenta como
  vencido si su ULT ya está en el repertorio o si la zona siguiente está
  desbloqueada (`unlockedZone > zona`).
- Fila: `Falta · Vencé a <Jefe> (zona N, Nv a–b)` (u `Obtenida · ...`).
- Tooltip: `Se aprende al vencer a <Jefe> (la primera victoria la
  enseña). Aparece como jefe de la zona N, <Zona> (Nv a–b).` + `Su
  versión del Abismo también la enseña.` si corresponde + estado
  (`Ya lo venciste: volvé a vencerlo para aprenderla.` /
  `Todavía no lo venciste.`) si falta.

| # | id | Nombre | Jefe | Compat. | Afin. | Rol | Efecto | Costo | Visual |
|---|---|---|---|---|---|---|---|---|---|
| 41 | ult2_diluvioMenor | Diluvio Menor | Rey Limo | cualquiera | Veneno | DA/R | 1.0 a todos, Veneno 3 | 80 | lluvia verde con ecos del Rey Limo; 2000 ms |
| 42 | ult2_engranajePrestado | Engranaje Prestado | Gólem Reloj | cualquiera | Hielo | C | 1.3 a todos, Congelación 2, retrasa 0.4 | 100 | engranajes gigantes giran y frenan; 2400 ms |
| 43 | ult2_telarTiempo | Telar del Tiempo | Matriarca Araña | cualquiera | Veneno | C | 1.2 a todos, Veneno 2, debuff velocidad −20% 2 t | 100 | hilos de luz atan a los enemigos; 2200 ms |
| 44 | ult2_alientoPrestado | Aliento Prestado | Sierpe de Escarcha | cualquiera | Agua/Hielo | R | 1.2 a todos, Mojado 1 + Congelación 1 | 100 | eco de la sierpe exhala detrás del portador; 2300 ms |
| 45 | ult2_juicioAjeno | Juicio Ajeno | Caballero Hueco | cuerpo a cuerpo | Físico | D1/C | 3.2, Aturdido 1, buff propio defensa +30% 2 t | 100 | armadura hueca fantasma ejecuta el tajo; 2400 ms |
| 46 | ult2_coroPrestado | Coro Prestado | Hechicera del Eco | mágicas | — | DA/S | 1.0 a todos, +0.25 de poder por aliado vivo **[nuevo: `perAlly`]** | 100 | ecos de cada aliado cantan un acorde; 2500 ms |
| 47 | ult2_erupcionContenida | Erupción Contenida | Bestia de Magma | cualquiera | Fuego | DA/R | 1.5 a todos, Quemadura 2, `catalyst` 0.25 | 100 | grietas de magma bajo los enemigos; 2300 ms |
| 48 | ult2_lamentoPrestado | Lamento Prestado | Espectro Coronado | cualquiera | Sagrado | S | revive caídos 40%, cura grupo 20% | 100 | ecos de los caídos vuelven a ocupar su lugar; 2400 ms |
| 49 | ult2_marcaVacio | Marca del Vacío | Centinela del Vacío | cualquiera | Electro | D1/S | 2.4, Cargado 1, debuff daño recibido +30% 3 t | 80 | sello del vacío se graba en el objetivo; 2000 ms |
| 50 | ult2_finPrestado | Fin Prestado | Devorador de Eras | cualquiera | Fuego | DA/C | 1.6 a todos, Quemadura 2, quita los buffs enemigos **[nuevo: `stripBuffs`]** | 100 | eras superpuestas se desmoronan; 2600 ms |

### 3.7 Equilibrio

- Roles: D1 14, DA 12, C 9, S 11, Q/R repartidos en todas las fuentes
  (contando roles dobles). Cada fuente tiene al menos una de soporte y
  una de control: ninguna fuente es "la del daño".
- Ninguna domina: el daño bruto más alto (Disparo Anterior 5.0) pide un
  turno de carga y cuesta 80; las de 60 cambian poder por tempo
  (Bucle Breve Instante, Forjado en el Ayer). Comparadas con las 13 de
  tipo de arma: daño a uno 2.6-3.8 (hoy 3.0-4.0), área 1.0-1.8 (hoy
  1.6-2.2) con más efecto atado.
- Sinergias: Quiebre (1, 2, 6, 13, 26, 30, 40), Convergencia y reacciones
  (8, 9, 18, 24, 35, 44, 47), Pulso (17), Instante (23), cancelar ULT
  enemiga (31, 36).
- **Medición**: antes de implementar, un script `tool/ult_balance.dart`
  (como la simulación de break_and_enemy_ults.md: 40 semillas, grupo
  1-4) mide daño esperado por punto de carga y turnos ganados; meta: cada
  ULT dentro de ±15% del valor de su costo. No incluido en este borrador.

## 4. ULT enemigas: una por jefe y por élite

### 4.1 Telegrafiado (reglas comunes)

- Igual que hoy: con 100 de carga **avisa** (pierde la acción) y la
  lanza en su turno siguiente. En la **línea de tiempo** su ficha muestra
  el icono de ULT y el nombre; el turno de lanzamiento se resalta.
- Se cancela: **quebrándolo** (como hoy, "ULT de jefe cancelada"), o
  **retrasándolo** no la cancela pero da más turnos al grupo. Nuevo: si
  `ultDrain` llega mientras avisa, baja el poder 1% por punto (tope −40%)
  en vez de no hacer nada.
- Defensas: "defiéndete o protégete" (sin cambios).
- Élites: carga inicial 40 como hoy, pero su ULT es más chica que la
  Furia Élite actual (poder 1.4-2.0) y cada una tiene su firma; avisan
  igual que los jefes. FXA `category: enemy_ult`, ≤ 2.6 s, con ecos
  translúcidos del propio enemigo.

### 4.2 Jefes (15)

Las 10 de jefes base quedan **con el efecto actual** (`kEnemyUlts`);
solo se agrega FXA propia. Los 5 del Abismo pasan a nombre y firma
propios (hoy repiten nombre).

| Jefe (id) | ULT (id) | Efecto | Visual |
|---|---|---|---|
| Rey Limo (`reyLimo`) | Diluvio Ácido (`eult_diluvio`) | 1.2 a todos, Veneno 2 | gotas gigantes con ecos que caen dos veces |
| Gólem Reloj (`golemReloj`) | Engranaje del Fin (`eult_engranaje`) | 1.5, Congelación 3, retrasa 0.5 a todos | engranaje del pasado aplasta |
| Matriarca Araña (`matriarca`) | Nido Venenoso (`eult_nido`) | 1.1 a todos, Veneno 3, telaraña | crías fantasma caen del techo |
| Sierpe de Escarcha (`sierpe`) | Aliento Glacial (`eult_aliento`) | 1.2 a todos, Congelación 2, rehace cristales | aliento con eco de una sierpe mayor |
| Caballero Hueco (`caballeroHueco`) | Juicio Hueco (`eult_juicio`) | 1.9, Aturdido 1, cambia de postura | tres armaduras ecos atacan en fila |
| Hechicera del Eco (`hechicera`) | Coro de Ecos (`eult_coro`) | 1.0 a todos, retrasa 0.3, +0.3 por eco vivo | ecos de la hechicera cantan en círculo |
| Bestia de Magma (`bestiaMagma`) | Erupción Total (`eult_erupcion`) | 1.3 a todos, Quemadura 2, lava 3 t | columnas de lava desfasadas |
| Espectro Coronado (`espectroCoronado`) | Lamento Eterno (`eult_lamento`) | 1.25 a todos, Congelación 2, invoca séquito | corona flota, siervos aparecen |
| Centinela del Vacío (`centinela`) | Colapso del Vacío (`eult_colapsoVacio`) | 1.3 a todos, Mojado 1, marca del vacío | portal magitec implota |
| Devorador de Eras (`devorador`) | Fin de las Eras (`eult_finEras`) | 1.4 a todos, Quemadura 2, borra buffs | eras superpuestas arden |
| Gólem Reloj del Abismo (`golemAbismo`) | **Reloj sin Agujas** (`eult_abismoReloj`) | sin cambios (1.5 a todos, Congelación 2, retrasa 0.5) | reloj sin agujas que gira hacia atrás |
| Hechicera del Eco del Abismo (`hechiceraAbismo`) | **Coro del Abismo** (`eult_abismoEco`) | sin cambios | coro invertido, voces del futuro |
| Espectro Coronado del Abismo (`espectroAbismo`) | **Corona Vacía** (`eult_abismoCorona`) | sin cambios | corona sin portador convoca |
| Devorador de Eras del Abismo (`devoradorAbismo`) | **Última Era** (`eult_abismoEras`) | sin cambios | todas las eras se apagan menos una |
| Eco Primordial (`ecoPrimordial`) | Todas las Eras (`eult_primordial`) | sin cambios | ecos de todos los jefes pasan en fila |

### 4.3 Élites (20: cada tipo común que puede salir élite)

Reemplazan `kEliteUltId` por `EnemyDef.eliteUltId` (si falta, Furia
Élite como respaldo). Invocaciones (Cristal de Hielo, Eco de la
Hechicera, Siervo Espectral, Eco del Abismo) no salen élite y no tienen.

| Enemigo (id) | ULT (id) | Efecto | Visual |
|---|---|---|---|
| Limo (`slime`) | Masa Pegajosa (`eult_e_slime`) | 1.4 a todos, debuff velocidad −20% 2 t | se infla con ecos y revienta |
| Murciélago (`bat`) | Chillido Antiguo (`eult_e_bat`) | 1.4 a todos, retrasa 0.3 | ondas de sonido desfasadas |
| Gólem (`golem`) | Puño de Piedra (`eult_e_golem`) | 2.0 a uno, Aturdido 1 | puño y eco de piedra |
| Espectro (`ghost`) | Toque Frío (`eult_e_ghost`) | 1.6 a uno, Congelación 2 | atraviesa al objetivo dos veces |
| Araña (`arana`) | Red Envenenada (`eult_e_arana`) | 1.4 a todos, Veneno 2 | red con ecos de hilos |
| Lobo (`lobo`) | Manada Fantasma (`eult_e_lobo`) | 3 golpes × 0.7 al azar | ecos de lobos cruzan |
| Murciélago de Hielo (`murcielagoHielo`) | Ventisca Alada (`eult_e_murcielagoHielo`) | 1.4 a todos, Congelación 1 | remolino de alas de escarcha |
| Elemental de Escarcha (`elementalEscarcha`) | Prisión de Hielo (`eult_e_elementalEscarcha`) | 1.8 a uno, Congelación 3 | bloque de hielo con eco del elemental |
| Esqueleto (`esqueleto`) | Carga de Huesos (`eult_e_esqueleto`) | 2.0 a uno, crítico seguro | esqueletos ecos en carga |
| Caballero Caído (`caballeroCaido`) | Último Juramento (`eult_e_caballeroCaido`) | 1.8 a uno + escudo propio 20% 2 t | armadura antigua superpuesta |
| Eco Sombrío (`ecoSombra`) | Paso Doble (`eult_e_ecoSombra`) | 2 golpes × 1.0, retrasa 0.3 al objetivo | se parte en dos ecos |
| Guardián del Reloj (`guardianReloj`) | Campanada (`eult_e_guardianReloj`) | 1.2 a todos, retrasa 0.5 | campana magitec suena |
| Salamandra (`salamandra`) | Escupitajo Ígneo (`eult_e_salamandra`) | 1.5 a todos, Quemadura 2 | chorro de fuego con estela |
| Gólem de Magma (`golemMagma`) | Corazón Fundido (`eult_e_golemMagma`) | 1.6 a todos, Quemadura 1 | pecho se abre y estalla |
| Necrófago (`necrofago`) | Festín (`eult_e_necrofago`) | 1.8 a uno, se cura 50% del daño | mordida con ecos voraces |
| Alma Errante (`almaErrante`) | Llanto Errante (`eult_e_almaErrante`) | 1.3 a todos, Congelación 1 | alma se multiplica y llora |
| Vigilante del Vacío (`vigilanteVacio`) | Ojo que Inunda (`eult_e_vigilanteVacio`) | 1.4 a todos, Mojado 2 | ola desde un portal |
| Ojo del Abismo (`ojoAbismo`) | Mirada Eléctrica (`eult_e_ojoAbismo`) | 1.8 a uno, Cargado 1, Aturdido 1 (30%) | rayo con eco previo |
| Heraldo de las Eras (`heraldoEras`) | Anuncio de las Eras (`eult_e_heraldoEras`) | 1.5 a todos, Quemadura/Veneno/Congelación 1 (su ciclo) | tres eras pasan detrás |
| Fragmento del Tiempo (`fragmentoTiempo`) | Esquirla Desfasada (`eult_e_fragmentoTiempo`) | 1.6 a uno, retrasa 0.6 | se astilla en ecos y vuelve |

Efectos nuevos de élites que no caben en `EnemyUltDef` hoy: `hits`,
`selfShield`, `drainHeal`, `debuff` (velocidad), `delayTarget`.
Se agregan como campos opcionales (§ 5.4). El Heraldo deja de traer ULT
fija fuera de élite (pregunta 5).

## 5. Red, datos, Editor y plan

### 5.1 Datos (YAML)

Un archivo por ULT en `assets/data/ults/<id>.ult.yaml` + índice
`assets/data/ults/ult_manifest.yaml`. La animación vive aparte en FXA
(`fx:` = id del FxCatalog), así arte y balance se editan por separado.

```yaml
schema: 1
id: ult2_ecoFilo
name: Eco del Filo
source: { kind: weapon_mod, rarity: [rara, epica] }  # weapon_mod | unique | tree | feat | eco | boss
weapons: [espada]
classes: []            # vacío = cualquiera
element: physical
cost: 100              # (ignorado: toda ULT cuesta 100)
pulse: 0
skill:                 # campos de SkillDef, mismos nombres
  kind: physical
  power: 1.05
  hits: 3
  breakBonus: 0.5
fx: ult2_ecoFilo       # assets/fx/ult/ult2_ecoFilo.fx.yaml, ≤ 2600 ms
```

Enemigas: `assets/data/enemy_ults/<id>.eult.yaml` con los campos de
`EnemyUltDef` + `fx`. El código Dart mantiene los mapas actuales como
respaldo hasta que el cargador esté probado (mismo patrón que el
adaptador de game_editor.md § 2.3). `game_engine/` sigue Dart puro: el
YAML lo parsea `data/` y entra al `GameCatalog` como mapas.

### 5.2 Protocolo

- Perfil: `uk` (lista de ids aprendidos) y `us` (activa), aditivos;
  ausentes = comportamiento de hoy.
- `UltimateCommand` sin cambios (`{"t":"cmd","a":"ult","tg":…}`): el host
  resuelve qué ULT usa con `us`. `Combatant` agrega `ultSel` al JSON de
  batalla para que el cliente muestre nombre y FXA.
- Eventos: `EnemyUltWarningEvent` ya lleva el id; la FXA se busca por id.
- Versionado: un cliente sin la ULT en su catálogo cae al FXA genérico
  `ult_generic`; el host rechaza `us` desconocido.

### 5.3 Editor

- Área **Visuales**: categoría **ULT** con dos listas (jugador / enemigas),
  vista previa con la FXA y aviso si dura > 2600 ms.
- Área **Balance**: categoría **ULT** con los campos del YAML (costo,
  poder, estados, breakBonus…), fuente y compatibilidad; el impacto
  (`impact_panel.dart`) ya calcula ULT enemigas: se extiende a las 20 de
  élite y a las de jugador.

### 5.4 Motor (campos nuevos)

Jugador: `ultCost`, `pulseParty`, `openerBonus`, `echoLast`,
`delayedHit`, `perAlly`, `stripBuffs`; `ultimateOf` mira `ultSel`.
Enemigos: `EnemyDef.eliteUltId`; en `EnemyUltDef`: `hits`, `selfShield`,
`drainHeal`, `debuffs`, `delayTarget`; drenaje durante aviso (§ 4.1).

### 5.5 Pasos

1. Datos: cargador YAML de ULT + `ultCost` + repertorio (`uk`, `us`) y
   selector en PERSONAJE; migrar 13 + 8 existentes al YAML sin cambiar
   números. Tests de ida y vuelta y de perfiles viejos.
2. Script `tool/ult_balance.dart` y ajuste de números.
3. ULT de élite (20) + nombres del Abismo + drenaje en aviso.
4. Fuentes: mod de arma (12) y únicos (8); filtro de botín.
5. Árbol (8), hazañas (6), Atlas/Maestría/Eco (6), botín de jefe (10).
6. Campos de motor nuevos, uno por PR con su test.
7. FXA de las 50 + 35 enemigas (lo arma el Editor; esta spec solo da la
   dirección). Capturas de release.

Pruebas: `test/game_engine/ultimates_v2_test.dart` (costo resta, activa
inválida cae al orden viejo, cada campo nuevo), `break_and_enemy_ults_test.dart`
(cada élite usa su ULT, aviso + quiebre cancela, drenaje en aviso),
codec de perfil (`uk`/`us`), sanitize del mod, y una prueba que valida
que cada `fx` exista y dure ≤ 2600 ms.

## 6. Preguntas abiertas

1. **¿Qué pasa con las 144 ULT de camino?** Recomiendo **retirarlas del
   loot nuevo** y que el mod de arma use el pool de 12 (§ 3.1); las armas
   ya caídas conservan su `ul` (sanitize las sigue aceptando). Son
   generadas y prestan su aspecto: chocan con "50 bien hechas".
2. **¿Una ULT activa o dos?** Recomiendo **una**, elegida fuera de combate;
   dos ranuras complican la IA de compañero y la UI.
3. ~~¿Grabar el mod ULT de un arma en otra (fusión)?~~ **Reemplazada**
   por el dueño: las ULT nunca se pierden y no se graban (§ 2.1).
4. **¿Costos variables (60/80/100) o todas 100?** Recomiendo **variables**:
   abre decisiones de ritmo sin tocar la carga.
5. **¿El Heraldo de las Eras sigue con ULT sin ser élite?** Recomiendo
   **no**: solo élite, con Anuncio de las Eras; ya tiene ciclo de estados.
6. **Botín de jefe en co-op**: recomiendo que **cada jugador** tire
   su propia ULT (botín por jugador como el resto del loot).

## 7. Implementación (v0.17.0)

Respuestas aprobadas: 1) las 144 de camino ya no caen (el mod de arma
usa el pool de 12; las armas ya caídas conservan `ul`); 2) una ULT
activa; 3) reemplazada (§ 2.1: nunca se pierden); 4) costos 60/80/100 (revertido después: toda ULT cuesta la barra llena);
5) Heraldo con ULT solo como élite; 6) botín de jefe por jugador.

**Código**

- Modelo: `UltDef` (`game_engine/models/ult_def.dart`), catálogo
  `ults_v2_catalog.dart` (respaldo del código), élites en
  `elite_ults_catalog.dart` (`kEliteUlts`, `kEliteUltLooks` = guion y
  sonido de código que toman prestados). `GameCatalog.playerUlts`.
- Datos: `assets/data/ults/*.ult.yaml` + `ult_manifest.yaml`,
  `assets/data/enemy_ults/*.eult.yaml` + `eult_manifest.yaml`;
  `UltYaml` (Dart puro) y `UltDataLoader` (core, pone los datos debajo
  del parche de balance). `dart run tool/export_ult_data.dart` los
  regenera desde el código; `ult_data_test.dart` comprueba que coincidan.
- Motor: ~~`SkillDef.ultCost`~~ (revertido), `pulseParty`, `openerBonus`,
  `echoLast` (`Combatant.lastSkillId`), `delayedHit` (`doom`,
  `doomTurns`, `doomBy`; cae al empezar el turno del marcado),
  `perAlly`, `stripBuffs`; ULT con `hpCost` cobra vida; ULT `instant`
  no termina el turno; las ULT de cura con `revive` reviven a todos los
  caídos y además curan. Enemigos: `EnemyDef.eliteUltId`,
  `EnemyUltDef.hits/selfShield/selfShieldTurns/drainHeal/debuffs/
  delayTarget/extraStatuses/cycleStatus`; drenaje durante el aviso:
  `Combatant.ultWeaken` (−1% por punto, tope 40%).
- Repertorio: `UltRules` (`absorb`, `learn`, `options`, `validSel`,
  `selected`, `upgrade`, `upgradeCost`). `ultimateOf` mira primero
  `PlayerBuild.ultSel` (validada por el host en `buildOf`).
- Fuentes: mod de arma (pool v2 en `rollUltMod`), 8 legendarios (6
  existentes sin ULT + 2 nuevos: Corazón de Autómata, rifle, y Yunque de
  las Eras, martillo+escudo, con pasivas únicas nuevas), hitos (árbol de
  la clase con 20 y 40 nodos), 6 hazañas nuevas (pagan la ULT con
  `AchievementReward.ult`), Atlas (nodos notables resonancia / fortuna /
  ecojefe al completar un Eco), Maestría, Eco Raro o mejor, botín de
  jefe (al ganar, por jugador; Abismo → el del jefe base).
- UI: PERSONAJE → ULT (`ult_repertoire_view.dart`), botón de ULT con su
  costo, barra de objetivo con "Prepara <ULT>", Balance → ULT (las 50
  con fuente y compatibilidad en el nombre) y ULT enemigas (las 20 de
  élite, con impacto), Visuales → Animaciones (categorías ULT y ULT
  ENEMIGAS, 86 FXA nuevas: 50 en `assets/fx/ult/`, 36 en
  `assets/fx/enemy_ult/`, todas con pista `echo` y ≤ 2600 ms).

**Red** (lo cambia el protocolo; la versión la sube el dueño)

- Perfil: `uk` (lista), `us` (activa), `ulv` (niveles) — aditivos.
- `build` del combatiente: `us`, `ulv` — aditivos.
- `Combatant`: `ultW`, `lsk`, `doom` — aditivos.
- Acciones nuevas `{"t":"ultSel","id":…}` y `{"t":"ultUp","id":…}`: un
  host viejo las rechaza (acción desconocida).
- Avisos de ULT aprendidas / mejoradas por `SystemMessageEvent` (sin
  eventos nuevos). La ULT enemiga avisada ya llevaba su id.
- Un cliente sin los datos nuevos dibuja las ULT nuevas con el guion de
  código (la ULT de tipo de arma a la que se parecen / Furia Élite).

**Balance** (`dart run tool/ult_balance.dart`: 40 semillas, grupos 1-4,
valor por 100 de carga contra la mediana de su rol D1 / DA / S / C).
Ajustes respecto de las tablas del § 3: Lanza Inmóvil 2.6→2.1, Flecha
que Vuelve 2.4→1.5, Disparo Anterior carga 5.0→3.6, Brasa Antigua
1.8→1.0, Campana del Pasado 1.3→1.1, Luz de Ayer cura 2.2→1.4 y revive
30%→25%, Sentencia Lejana 2.8→1.9, Erupción Contenida 1.5→1.2, Fin
Prestado 1.6→1.05, Ancla Temporal escudo 30%→15% y defensa +30%→+20%;
suben Era Suspendida 1.2→1.6, Forjado en el Ayer +30%→+40% y Baluarte
Autómata escudo 40%→50%. Resultado: ninguna pasa 1.35× la mediana de su
rol a nivel 1 ni 1.7× a nivel 5. La meta de ±15% no se cumple en la
cola baja (utilitarias de un objetivo y buffs que el script valora por
debajo); quedan anotadas como "baja" en la salida del script.

**Costo único (revierte la respuesta 4).** El dueño pidió que toda ULT
se lance con la barra al 100% y la vacíe, como antes: se quitó `ultCost`
(`SkillDef`, codec, YAML `cost`, UI). La velocidad de carga la dan las
pasivas y el árbol. Datos viejos: el `cost` / `ultCost` de un YAML se
ignora y un `ultCost` en `balance.json` queda como aviso (no se aplica).
Las ULT que costaban 60 / 80 suben de poder para compensar.

**Balance v2 de utilidad (rama balance/ult-utilidad).** El dueño pidió
subir las ULT flojas: mejor que queden un poco fuertes y después se
bajan, antes que inútiles.

Correcciones al modelo de `tool/ult_balance.dart`:

- Enemigos con 10× vida al medir: el esqueleto (125) se moría y el daño
  de un objetivo se perdía en exceso, así que los golpes grandes de un
  objetivo (Corona Rota, Golpe Maestro, Remate) quedaban subvalorados.
  El remate (`execute`) ya casi no se dispara en la medición.
- Control duro: aturdir / congelar suma +0.5 golpe por stack aparte de
  los 0.3 de cualquier estado (un turno perdido vale como un retraso de
  un turno entero).
- Robo de carga de ULT (`ultDrain`): los esqueletos no tienen ULT y el
  motor no lo registraba. Ahora vale carga/100 golpes por enemigo golpeado.
- Proteger (`protect`): 0.25 golpe por aliado cubierto.
- Toda ULT se mide con costo 100.

**Objetivo absoluto.** Referencia fija = las medianas de rol con el
modelo nuevo sobre los números originales (antes de estas subas, con sus
costos originales): D1 3.83, DA 5.42, S 1.15, C 6.27 golpes por 100 de
carga. Las tocadas (y cualquiera que midiera < 1.0 de la referencia)
quedan entre 1.05× y 1.15× de la referencia a nivel 1, sin pasar 1.35× a
nivel 5. Las demás no cambian.

| ULT | costo antes | cambio | nv1 / ref | nv5 / ref |
|---|---|---|---|---|
| Eco del Filo | 100 | poder 1.05 → 1.42 | 1.08 | 1.34 |
| Talado de Eras | 100 | poder 1.7 → 1.929 | 1.09 | 1.34 |
| Flecha que Vuelve | 80 | poder 1.5 → 1.854 | 1.08 | 1.34 |
| Disparo Anterior | 80 | carga 3.6 → 4.149 | 1.08 | 1.34 |
| Virote Detenido | 100 | poder 2.2 → 3.13 | 1.14 | 1.35 |
| Mil Ayeres | 100 | poder 0.55 → 0.599 | 1.09 | 1.35 |
| Página que Recuerda | 100 | poder 1.4 → 1.9 | 1.12 | 1.24 |
| Chispa Relojera | 100 | poder 1.5 → 1.72 | 1.12 | 1.34 |
| Muro de Ayer | 100 | escudo grupo 0.20 → 0.22 | 1.07 | 1.34 |
| Yunque del Tiempo | 100 | poder 3.4 → 3.927 | 1.11 | 1.32 |
| Reloj Partido | 100 | poder 1.0 → 1.51 | 1.12 | 1.32 |
| Hoja de la Corona Rota | 100 | poder 3.2 → 4.169 | 1.08 | 1.34 |
| Pulso Magitec | 100 | poder 1.4 → 1.684 | 1.11 | 1.34 |
| Doble Horizonte | 100 | poder 1.6 → 1.792 | 1.10 | 1.33 |
| Sangre de Eco | 80 | poder 2.6 → 3.29 | 1.08 | 1.34 |
| Grito de las Ruinas | 80 | ATQ grupo 0.20 → 0.281 | 1.07 | 1.07 |
| Bucle Breve | 60 | poder 0.9 → 1.7 | 1.08 | 1.30 |
| Prisma del Pasado | 100 | poder 1.6 → 2.002 | 1.08 | 1.33 |
| Sentencia Lejana | 80 | poder 1.9 → 2.364 | 1.06 | 1.28 |
| Lluvia de Ecos | 100 | poder 0.35 → 0.476 | 1.09 | 1.35 |
| Primer Golpe | 80 | poder 2.5 → 2.775 | 1.08 | 1.34 |
| Cadena de Eras | 100 | poder 1.2 → 2.005 | 1.08 | 1.34 |
| Lluvia de Esquirlas | 100 | poder 1.5 → 1.751 | 1.11 | 1.34 |
| Custodio del Instante | 80 | poder 0.5 → 1.255 | 1.06 | 1.27 |
| Forjado en el Ayer | 60 | daño propio 0.40 → 0.846 | 1.10 | 1.10 |
| Remate del Eco | 80 | poder 2.2 → 4.175 | 1.08 | 1.34 |
| Era Suspendida | 100 | poder 1.6 → 3.16 | 1.13 | 1.33 |
| Golpe Maestro | 100 | poder 3.0 → 3.13 | 1.08 | 1.34 |
| Eco Doble | 80 | poder 2.0 → 4.164 | 1.08 | 1.34 |
| Lo Que Será | 100 | golpe diferido 4.0 → 4.853 | 1.08 | 1.34 |
| Diluvio Menor | 80 | poder 1.0 → 2.066 | 1.08 | 1.34 |
| Telar del Tiempo | 100 | poder 1.2 → 1.901 | 1.10 | 1.34 |
| Aliento Prestado | 100 | poder 1.2 → 1.95 | 1.12 | 1.24 |
| Coro Prestado | 100 | poder 1.0 → 1.655 | 1.08 | 1.34 |
| Lamento Prestado | 100 | poder 1.2 → 1.35 | 1.11 | 1.34 |
| Marca del Vacío | 80 | poder 2.4 → 3.416 | 1.05 | 1.26 |

Siguen por encima de la meta sin tocar (ya estaban altas): Ojo del
Futuro (1.22 / 1.51), Atlas Abierto (1.29 / 1.46), Engranaje Prestado
(1.35 / 1.43), Erupción Contenida (1.27 / 1.50), Lanza Inmóvil (1.15 /
1.41), Baluarte Autómata (1.20 / 1.40), Última Cuerda (1.17 / 1.39);
candidatas a bajar después.

En Editor → Balance las 50 ULT de jugador se listan (fuente, rol,
compatibilidad) y se editan con los campos de ULT v2. El parche llega
también a la ULT que trae el arma (mod o legendario), no solo a la
elegida en el repertorio.

**Desvíos**

- Maestría 25 / 50 no existe (tope 20): Golpe Maestro en Maestría 10 y
  Eco Doble en Maestría 20.
- Botín de jefe: el primero es seguro (mientras no la tenga); como
  la ULT se aprende, la tirada de 5% / 15% posterior no aplica.
- "Al azar" de Mil Ayeres y Lluvia de Ecos: los golpes van al objetivo
  (ráfaga), con atraviesa en Lluvia de Ecos.
- Hazañas con contador aproximado: "sin recibir daño el 1.er turno" =
  ningún daño antes de tu segundo turno; "salvar aliados con escudo" =
  poner escudos a otro jugador; "rematadas" = golpes finales.
- Anuncio de las Eras aplica el estado de su ciclo (uno por lanzamiento).

### v0.21.1

En la info de la ULT elegida (aprendida y no al máximo) se ve siempre "AL MEJORAR: NIVEL n → n+1": poder antes → después, costo y la descripción del próximo nivel. La vista previa muestra el próximo nivel también mientras se confirma.
