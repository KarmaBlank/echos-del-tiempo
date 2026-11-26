# Spec (aprobada; los 10 jefes implementados: zonas 1-5 en la v0.2, 6-10 en la v0.3): 10 jefes

Pedido del dueño: "que haya más bosses, unos 10". Hoy hay 3 (Rey Limo,
Gólem Reloj, Devorador de Eras). Se agregan 7 para tener **uno por zona**
del mundo nuevo (worldgen.md), repartidos en los niveles 1–50. Cada jefe
tiene: sprite propio (pixel art generado por `tool/export_sprites.dart`,
como los demás), stats que escalan con el nivel de la zona, barra de
quiebre, **una mecánica propia** que obliga a jugar distinto, ULT con
cinemática y sonido, y loot garantizado (Mágico o mejor; chance de su
legendario).

| # | Jefe | Zona (tipo) | Nivel | Mecánica propia | ULT |
|---|---|---|---|---|---|
| 1 | Rey Limo | Pradera (bosque) | 5 | Se divide en 2 limos al bajar del 50% | Diluvio Ácido |
| 2 | Matriarca Araña | Bosque Hondo (bosque) | 10 | Teje telarañas: un jugador pierde su turno si no lo liberan con un golpe | Nido Venenoso |
| 3 | Gólem Reloj | Ruinas Cronales (ruinas) | 15 | Cada 3 turnos "rebobina" y se cura lo recibido en el último turno, salvo que esté quebrado | Engranaje del Fin |
| 4 | Sierpe de Escarcha | Cavernas Heladas (cavernas) | 20 | Congela el campo: todos pierden 10% de velocidad por turno hasta romper sus cristales | Aliento Glacial |
| 5 | Caballero Hueco | Fortaleza Caída (ruinas) | 25 | Postura: alterna escudo (−70% daño físico) y espada (−70% daño mágico) | Juicio Hueco |
| 6 | Hechicera del Eco | Laberinto Temporal (laberinto) | 30 | Crea 2 ecos de sí misma; solo la real recibe daño completo | Coro de Ecos |
| 7 | Bestia de Magma | Grieta Ígnea (cavernas) | 35 | Charcos de lava: Quemadura extra a quien se defienda | Erupción Total |
| 8 | Espectro Coronado | Cementerio de Eras (abismo) | 40 | Invoca espectros; mientras vivan, es inmune a estados | Lamento Eterno |
| 9 | Centinela del Vacío | Abismo del Tiempo (abismo) | 45 | Marca a un jugador: si no se lo protege, recibe el próximo golpe ×2 | Colapso del Vacío |
| 10 | Devorador de Eras | Corazón del Tiempo (abismo) | 50 | Jefe final: 2 fases; en la 2.ª, Colapso Temporal cada 2 acciones | Fin de las Eras |

- Las mecánicas usan el sistema de disparadores del motor (como los
  notables) y se muestran en la barra de batalla con un chip y tooltip
  que explica cómo contrarrestarlas.
- Cada jefe tiene un cartel de entrada al empezar la pelea (nombre y
  título) y música/sonido de jefe.
- Élites y comunes nuevos por zona se definen junto con el mundo.

## Decisiones del dueño

1. Los 10 jefes de la tabla, aprobados.
2. **Repetibles**: cada misión de su zona se puede repetir y el jefe
   vuelve con nueva chance de su legendario. En el endgame aparecen al
   final de los Ecos y en versión extrema como Jefes del Abismo
   (endgame.md).
3. Foco co-op (endgame.md § 7): las mecánicas que piden coordinación
   tienen variante resoluble en solo.

## v0.2: Matriarca Araña, Sierpe de Escarcha y Caballero Hueco (implementado)

Motor: `lib/game_engine/rules/battle_engine.dart` (sección "mecánicas de
jefe": `_mechanicTurn`, `_castWeb`, `_freeAlly`, `_frost`, `_thaw`,
`_mechanicDeath`, `_stanceResist`, `_shiftStance`, `_ultExtra`); datos:
`lib/game_engine/data/enemies_catalog.dart` (`kEnemies`, `kBossMechanics`,
`kEnemyUlts`) y `models/enemy_def.dart` (`BossMechanicDef`,
`EnemyUltExtra`). Eventos: `BossMechanicEvent` (`models/battle_event.dart`).
Escena/HUD: battle_presentation.md § "Mecánicas de jefe"; sonido: audio.md
§ "Mecánicas de jefe". Tests: `test/game_engine/boss_mechanics_test.dart`,
`test/features/combat/boss_mechanics_fx_test.dart`.

Las mecánicas son **datos** (`BossMechanicDef`: tipo, cada cuánto, valor
con grupo y en solo, tope, invocaciones); el motor tiene código por tipo
(`web`, `frost`, `stance`), como los efectos de las notables.

### Stats (nivel nativo)

Los stats del catálogo son los del **nivel nativo** de cada id
(`kEnemyBaseLevel` de `zones_catalog.dart`): comunes al mínimo de su zona,
jefes al máximo. La sesión escala vida, quiebre y ATQ al nivel del piso
con `ZoneRules.scaleBattle` (worldgen.md § 6). XP y créditos son los
crudos (la sesión los escala por nivel). Calibrados contra los existentes
escalados a ese nivel (p. ej. el Gólem a nivel 21 ≈ 209 / 28; el Gólem
Reloj a nivel 20 ≈ 1000 / 35).

| Id | Nombre | Zona | Nivel | Vida | ATQ | VEL | XP | ₵ | Quiebre | Otros |
|---|---|---|---|---|---|---|---|---|---|---|
| `arana` | Araña | 2 | 6 | 52 | 11 | 10 | 8 | 7 | 42 | +1 Veneno |
| `lobo` | Lobo | 2 | 6 | 50 | 12 | 14 | 8 | 7 | 40 | perforante, rápido |
| `matriarca` | Matriarca Araña | 2 | 10 | 480 | 21 | 9 | 90 | 110 | 170 | jefe, +1 Veneno, ULT `eult_nido`, mecánica `telarana` |
| `murcielagoHielo` | Murciélago de Hielo | 4 | 16 | 80 | 22 | 14 | 10 | 9 | 64 | +1 Congelación, vuela |
| `elementalEscarcha` | Elemental de Escarcha | 4 | 16 | 170 | 23 | 5 | 16 | 15 | 136 | +1 Congelación, armadura −15% |
| `sierpe` | Sierpe de Escarcha | 4 | 20 | 1050 | 33 | 8 | 150 | 190 | 370 | jefe, +1 Congelación, ULT `eult_aliento`, mecánica `escarcha` |
| `cristalHielo` | Cristal de Hielo | 4 | 20 | 60 | 0 | — | 0 | 0 | — | invocación de la Sierpe (`passive`) |
| `esqueleto` | Esqueleto | 5 | 21 | 125 | 27 | 10 | 12 | 11 | 100 | perforante |
| `caballeroCaido` | Caballero Caído | 5 | 21 | 200 | 28 | 7 | 18 | 16 | 160 | 25% Aturdido, armadura −20% |
| `caballeroHueco` | Caballero Hueco | 5 | 25 | 1250 | 38 | 9 | 200 | 240 | 440 | jefe, ULT `eult_juicio`, mecánica `postura` |

- Quiebre ≈ 0.8 × vida en los comunes y ≈ 0.35 × vida en los jefes (como
  break_and_enemy_ults.md); × grupo y × élite como siempre. Los élites de
  los comunes nuevos salen del sistema de élites existente (× 2.6 vida,
  × 1.35 ATQ, Furia Élite).
- **Armadura** (`EnemyDef.armor`): multiplica el daño de los golpes del
  grupo (`× 0.8 armadura` en el log). No toca daño de estados.
- El Aturdido con probabilidad del Caballero Caído solo aparece en el log
  si entra.
- **Legendario de cada jefe** (`EnemyDef.legendaryId`, dato para el loot):
  Matriarca → Susurro de la Víbora (`susurroVibora`), Sierpe → Invierno
  Perpetuo (`inviernoPerpetuo`), Caballero Hueco → Égida del Primer Rey
  (`egidaPrimerRey`). Conectarlo a la tabla de drops es del loot.
- **Cartel de entrada**: `EnemyDef.title` (Rey Limo "Soberano de la
  Pradera", Gólem Reloj "Guardián de las Ruinas Cronales", Devorador "El
  hambre al final del tiempo", Matriarca "Reina del Bosque Hondo", Sierpe
  "Aliento de las Cavernas Heladas", Caballero Hueco "Juramento sin alma
  de la Fortaleza Caída"). `EnemyDef.feminine` da "La Matriarca…/La
  Sierpe…" en el aviso de ULT.

### Matriarca Araña — Telaraña (`telarana`)

- Cada **3 acciones** suyas (en vez del ataque normal) teje: golpe de
  `ATQ × 0.6` a un jugador **no atrapado** (el provocador si hay; si no
  al azar) y lo deja atrapado (`Combatant.webbed`,
  `BossMechanicEvent(webCast)`). Si todos están atrapados, ataca normal.
  La Protección no desvía la telaraña.
- **Co-op**: al empezar su turno, el atrapado **pierde el turno**
  (`webSkip`) y se suelta. Un aliado lo libera antes usando **Atacar**
  con el atrapado como objetivo (`AttackCommand(targetId: aliado)`; el
  menú muestra "Liberar a X"): no hace daño, cuesta **medio turno** al
  que libera (`webFreed`, próximo turno en `reloj + IV × 0.5`). Atacar a
  un aliado no atrapado (o a uno mismo) es un comando inválido.
- **Solo** (nadie más vivo al empezar su turno): forcejea y pierde
  **medio turno** (`webStruggle`, próximo turno en `reloj + IV × 0.5`).
- **ULT Nido Venenoso** (`eult_nido`): `ATQ × 1.1` a todos + 3 Veneno; con
  2+ vivos, atrapa además al de más vida.

### Sierpe de Escarcha — Campo Helado (`escarcha`)

- Empieza con **2 Cristales de Hielo** (1 en solo), combatientes
  `cristalHielo` agregados por `BattleEngine.start` después del jefe
  (`e1`, `e2`): no tienen turno (no entran a la línea de tiempo), no
  tienen barra ni ULT, no dan XP, y **mueren con la Sierpe**. Se les pega
  como a cualquier enemigo (las habilidades a todos también los tocan).
- Al empezar cada turno de la Sierpe, si queda algún cristal: todo el
  grupo **−10% de velocidad** acumulable, tope **−50%** (efecto
  `TimedEffect(sourceId: 'escarcha', stat: speed)`, `frost` con el total).
- Al caer el último cristal (o la Sierpe), el campo **se descongela**: se
  quita el efecto (`thaw`).
- **Quiebre**: quebrar a la Sierpe rompe un cristal (`shatter`).
- **ULT Aliento Glacial** (`eult_aliento`): `ATQ × 1.2` a todos + 2
  Congelación y **vuelve a formar** los cristales rotos (`reform`, vida
  llena).
- **Solo**: un solo cristal (un golpe o dos lo rompen).

### Caballero Hueco — Postura (`postura`)

- Empieza en **escudo** (`Combatant.stance` 1) con `stanceTurns` 2. Al
  empezar cada turno suyo baja 1; al llegar a 0 cambia (escudo ↔ espada)
  y vuelve a 2: cada postura dura 2 turnos suyos y con `stanceTurns` 1
  la escena y el chip avisan "cambia en su próximo turno".
- **Escudo**: −70% al daño **físico** (ataque básico, habilidad física,
  ULT física). **Espada**: −70% al daño **mágico** (habilidades y ULT
  mágicas, la luz de Aura Restauradora). El dúo y el daño secundario de
  notables no se bloquean. Log `× 0.3 POSTURA`, evento `resisted` (uno por
  paso).
- **Quebrado** (vulnerable) pierde la postura: no bloquea nada.
- **Solo** (1 jugador vivo): bloquea −50%.
- **ULT Juicio Hueco** (`eult_juicio`): `ATQ × 1.9` a uno + 1 Aturdido;
  después cambia de postura.

### Sprites

Pixel art en `tool/export_sprites.dart` (docs/specs/sprites.md), todos
mirando a la izquierda:
- Araña: cuerpo violeta oscuro, 8 patas marrones, ojos rojos, colmillos
  verdes de veneno. Lobo: gris azulado de perfil, orejas en punta, ojo
  amarillo, colmillos. Murciélago de Hielo: alas cian pálido con puntas
  escarchadas, colmillos de hielo (flota). Elemental de Escarcha: gólem de
  cristales azules con núcleo blanco. Esqueleto: hueso con pupilas rojas y
  espada oxidada. Caballero Caído: acero gris abollado, capa violeta
  rota, escudo torre, visor verde fantasma. Cristal de Hielo: esquirla
  facetada cian con núcleo brillante.
- Jefes (escala 1.7-1.8 del manifest): Matriarca (araña reina con corona,
  reloj de arena rojo en el abdomen, muchos ojos), Sierpe (serpiente de
  escarcha enroscada en anillos, crin de hielo), Caballero Hueco (yelmo
  vacío con ojos cian, espada y escudo, capa, ribetes de oro gastado).

## v0.3: Hechicera, Bestia de Magma, Espectro Coronado, Centinela y Devorador final (implementado)

Zonas 6–10 (worldgen.md § 8). Mismos patrones que la v0.2: la mecánica
es dato (`BossMechanicDef` en `kBossMechanics`, con los campos nuevos
`turns`, `power` y `soloPower`), el motor tiene código por tipo
(`echo`, `lava`, `summon`, `mark`, `phases`), cada fase emite un
`BossMechanicEvent`, las que piden coordinación tienen variante en solo,
cada jefe tiene cartel de entrada (`title`), chip con tooltip de cómo
contrarrestarla (`counter`), ULT propia con cinemática y sonido de 3
partes, y legendario (`legendaryId`). Tests:
`test/game_engine/boss_mechanics_v03_test.dart`,
`test/features/combat/boss_mechanics_v03_fx_test.dart`.

### Stats (nivel nativo; la sesión escala con `kEnemyBaseLevel`)

Comunes al mínimo de su zona, jefes al máximo. Calibrados escalando los
de la zona 5 con `ZoneRules.hpScale` / `atkScale` (vida ×1.19 / ATQ
×1.15 de nivel 21 a 26, etc.) más un escalón de jefe a jefe. Quiebre
≈ 0.8 × vida (comunes) y ≈ 0.35 × vida (jefes). La XP de los comunes
quedó ~20% por debajo de su escalón para que el ritmo de worldgen.md
(≈ nivel 50 al terminar la zona 10, test "ritmo" de
`zones_v03_test.dart`) se cumpla.

| Id | Nombre | Zona | Nivel | Vida | ATQ | VEL | XP | ₵ | Quiebre | Otros |
|---|---|---|---|---|---|---|---|---|---|---|
| `ecoSombra` | Eco Sombrío | 6 | 26 | 120 | 32 | 15 | 12 | 13 | 96 | esquiva 25% (golpe primario ×0.3, `ESQUIVA`), flota |
| `guardianReloj` | Guardián del Reloj | 6 | 26 | 190 | 30 | 6 | 16 | 18 | 152 | armadura −15%, sus golpes retrasan 30% de un turno |
| `hechicera` | Hechicera del Eco | 6 | 30 | 1350 | 42 | 10 | 230 | 280 | 470 | jefa, +1 Congelación, ULT `eult_coro`, mecánica `ecos` |
| `ecoHechicera` | Eco de la Hechicera | 6 | 30 | 140 | 21 | 10 | 0 | 0 | — | invocación de la Hechicera (actúa; recibe ×0.5) |
| `salamandra` | Salamandra | 7 | 31 | 150 | 37 | 12 | 12 | 14 | 120 | +2 Quemadura |
| `golemMagma` | Gólem de Magma | 7 | 31 | 260 | 36 | 5 | 17 | 20 | 208 | +1 Quemadura, armadura −25% |
| `bestiaMagma` | Bestia de Magma | 7 | 35 | 1700 | 48 | 7 | 260 | 320 | 600 | jefa, +2 Quemadura, ULT `eult_erupcion`, mecánica `lava` |
| `necrofago` | Necrófago | 8 | 36 | 190 | 41 | 11 | 13 | 15 | 152 | +2 Veneno, perforante |
| `almaErrante` | Alma Errante | 8 | 36 | 165 | 40 | 13 | 13 | 15 | 132 | +1 Congelación, flota |
| `espectroCoronado` | Espectro Coronado | 8 | 40 | 1800 | 53 | 11 | 290 | 360 | 630 | jefe, +1 Congelación, ULT `eult_lamento`, mecánica `sequito` |
| `siervoEspectral` | Siervo Espectral | 8 | 40 | 150 | 30 | 12 | 0 | 0 | — | invocación del Espectro (actúa, +1 Congelación) |
| `vigilanteVacio` | Vigilante del Vacío | 9 | 41 | 210 | 43 | 10 | 15 | 17 | 168 | sus golpes marcan: +20% daño recibido 2 turnos |
| `ojoAbismo` | Ojo del Abismo | 9 | 41 | 170 | 44 | 12 | 14 | 16 | 136 | 30% Aturdido, flota |
| `centinela` | Centinela del Vacío | 9 | 45 | 2100 | 59 | 9 | 320 | 400 | 735 | jefe, perforante, ULT `eult_colapsoVacio`, mecánica `marca` |
| `heraldoEras` | Heraldo de las Eras | 10 | 46 | 330 | 50 | 9 | 20 | 24 | 264 | élite natural: ULT Furia Élite; estados en ciclo Quemadura → Veneno → Congelación |
| `fragmentoTiempo` | Fragmento del Tiempo | 10 | 46 | 160 | 45 | 17 | 14 | 16 | 128 | rápido, sus golpes retrasan 25% |
| `devorador` | Devorador de Eras | 10 | 50 | 2600 | 64 | 10 | 400 | 500 | 910 | jefe final, +2 Quemadura, ULT `eult_finEras`, mecánica `fases` |

- El **Devorador** se rebalancea a nivel 50 (`kEnemyBaseLevel`
  `devorador: 50`, lo cambia el mundo). Solo lo usa la zona 10 (la
  misión `m3` del prototipo queda para los tests de paridad del mapa).
- Campos nuevos de `EnemyDef` (comunes): `evasion` (probabilidad de que
  un golpe primario del grupo "roce": ×0.3 y `BossMechanicEvent(evaded)`;
  solo tira el dado si el enemigo la tiene), `delayHit` (cada golpe que
  conecta retrasa al jugador `IV × delayHit`, `DelayedEvent`), `markHit`
  (`TimedEffect(sourceId: 'vigilancia', stat: damageTaken, 0.2, 2
  turnos)` sobre el jugador golpeado; el daño enemigo a un jugador ahora
  multiplica `1 + damageTaken`), `inflictCycle` (estado de cada acción
  en ciclo; reemplaza a `inflicts`).
- `heraldoEras` tiene `ultId: eult_furia` aunque no sea élite (empieza
  con 40 de carga como los élites).
- **Invocaciones que actúan** (`ecoHechicera`, `siervoEspectral`): tienen
  turno (entran en la línea de tiempo, primer turno a `IV × (0.6 +
  0.2·k)`), no tienen barra de quiebre ni ULT, no dan XP ni créditos y
  caen con su jefe. Las que vuelven a mitad de pelea reviven los ids
  caídos (vida llena, sin estados, turno en `reloj + IV × 0.5`); si falta
  alguno (entró un jugador) se agrega uno nuevo con vida y ATQ del
  catálogo × la razón jefe actual / jefe del catálogo (así escalan con el
  piso sin depender del mundo).
- Legendarios: Hechicera → Trueno de Bronce (`truenoBronce`), Bestia →
  Fauce del Volcán (`fauceVolcan`), Espectro → Arco de la Primavera Rota
  (`primaveraRota`), Centinela → Rompemundos (`rompemundos`), Devorador →
  Segadora de Eras (`segadoraEras`).
- Títulos: Hechicera "Voz múltiple del Laberinto Temporal", Bestia
  "Furia viva de la Grieta Ígnea", Espectro "Rey sin reino del
  Cementerio de Eras", Centinela "Guardián del borde del Abismo",
  Devorador (sin cambio) "El hambre al final del tiempo".

### Hechicera del Eco — Ecos (`ecos`, tipo `echo`)

- Empieza con **2 Ecos de la Hechicera** (1 en solo). Los ecos actúan
  (golpe débil) y **reciben ×0.5 de todo el daño** (`× 0.5 ECO` en el
  log, `BossMechanicEvent(echoResist)` una vez por paso y eco): con poca
  vida caen en pocos golpes. La Hechicera recibe daño completo.
- Si la Hechicera pasa **3 turnos suyos con ecos caídos**, al empezar el
  tercero los vuelve a crear (`echoSummon` por eco).
- **Quebrarla disipa un eco** (`shatter`, como el cristal de la Sierpe).
- **ULT Coro de Ecos** (`eult_coro`): `ATQ × (1.0 + 0.3 por eco vivo)` a
  todos y retrasa a todos `IV × 0.3`; después **rehace los ecos**
  caídos (`echoSummon`).
- Solo: 1 eco.

### Bestia de Magma — Charcos de lava (`lava`, tipo `lava`)

- Cada **3 acciones** suyas, después de atacar, el piso hace erupción:
  **lava 2 turnos suyos** (`Combatant.lava`, `lavaRise` con los turnos).
- Al empezar cada turno suyo con lava, **todo jugador que esté
  Defendiendo** se quema: `ATQ × 0.4` de daño de fuego (Defender no lo
  reduce; la DEF sí) + **2 Quemadura** (`lavaBurn` por jugador). Después
  baja 1 turno; al llegar a 0, `lavaFade`.
- Contrarrestar: no defenderse mientras hay lava; Guardia de todo el
  grupo quema a todos.
- **Solo**: `ATQ × 0.25` + 1 Quemadura.
- **ULT Erupción Total** (`eult_erupcion`): `ATQ × 1.3` a todos + 2
  Quemadura y la lava sube 3 turnos (`lavaRise`).

### Espectro Coronado — Séquito (`sequito`, tipo `summon`)

- Empieza con **2 Siervos Espectrales** (1 en solo), que actúan.
- **Mientras viva algún siervo, el Espectro es inmune a los estados**:
  no entran (tampoco el +15 de quiebre por estado) y el log dice
  `INMUNE` (`immune`, uno por paso).
- Si pasa **3 turnos suyos** con el séquito incompleto, al empezar el
  tercero invoca hasta completarlo (`summon` por siervo).
- **ULT Lamento Eterno** (`eult_lamento`): `ATQ × 1.25` a todos + 2
  Congelación y **completa el séquito**.
- Solo: 1 siervo.

### Centinela del Vacío — Marca del Vacío (`marca`, tipo `mark`)

- Cada **3 acciones** suyas, en vez de atacar, **marca a un jugador**
  (`Combatant.voidMarked`, `markCast`; el provocador si hay, si no al
  azar).
- Su **próxima acción** va contra el marcado (ignora la provocación) y
  pega **×2** (`markHit`). Si **otro aliado lo Protege** (Protección /
  Baluarte), el protector recibe un golpe normal y la marca se consume
  (`markGuarded`, actor = protector).
- **Solo**: además, **Defender** contrarresta la marca: golpe normal
  (con el ½ de defender) y se consume (`markGuarded`, actor = el mismo).
- Si el marcado cae, la marca se pierde.
- **ULT Colapso del Vacío** (`eult_colapsoVacio`): `ATQ × 1.3` a todos;
  el marcado sin proteger recibe ×2; después marca al de más vida.

### Devorador de Eras — Fases (`fases`, tipo `phases`)

- **Fase 1**: como siempre (Colapso Temporal cada 3 acciones, Golpe
  Brutal cada 4).
- Al llegar al **50% de la vida** se transforma: el golpe que lo baja de
  la mitad se queda en la mitad (la transformación absorbe el resto, así
  la fase 2 es siempre media barra). `phaseShift` (valor 2),
  `Combatant.phase = 2`: pierde sus estados, la barra de quiebre vuelve
  a 0 (si no está quebrado), **ATQ × 1.15**, sus acciones vuelven a 0 y
  **Colapso Temporal cada 2 acciones**. Fin de las Eras no cambia.
- Escena: cinemática de transformación (oscurece, vórtice, destello) y
  el sprite `devoradorFase2` (escala 2.8).

### Red

`Combatant` serializa (opcionales) `lava`, `vmk` (marcado), `phase`,
`mchN` (turnos sin invocaciones). Fases nuevas de `BossMechanicEvent`:
`echoSummon`, `echoResist`, `lavaRise`, `lavaBurn`, `lavaFade`,
`summon`, `immune`, `markCast`, `markHit`, `markGuarded`, `phaseShift`,
`evaded`.

### Sprites

`tool/export_sprites.dart`, mismo pipeline, todos mirando a la izquierda:
Eco Sombrío (silueta violeta oscura con ojos blancos y estela), Guardián
del Reloj (constructo de bronce con esfera de reloj), Salamandra (lagarto
naranja con lomo de brasas), Gólem de Magma (roca negra con grietas de
lava), Necrófago (carroñero gris verdoso encorvado con garras), Alma
Errante (llama azul pálida con cara), Vigilante del Vacío (centinela
violeta con ojo único y lanza), Ojo del Abismo (ojo flotante con
tentáculos), Heraldo de las Eras (encapuchado con estandarte y reloj de
arena), Fragmento del Tiempo (cristal de arena dorado). Jefes: Hechicera
(túnica violeta, sombrero alto, bastón con orbe cian; el eco es la misma
figura en cian pálido), Bestia de Magma (cuadrúpedo de roca con melena de
fuego), Espectro Coronado (corona de oro y manto rasgado; siervos:
espectros chicos encapuchados), Centinela (coloso de obsidiana con ojo
del vacío), Devorador fase 2 (fauces, cuernos, núcleo carmesí). Escalas:
Hechicera 1.7, su eco 1.4, Heraldo 1.2, Bestia 1.9, Espectro 1.8, Centinela 1.9, Devorador
fase 2 2.8.

## v0.50: jefes de zona con fases telegrafiadas, escalado, Ofrenda del Eco y botín de oficio

Paso 1 de la hoja de ruta aprobada (jefes → invocaciones → modos R →
widget → viajeros y reputación). Visión del dueño (roles.md § 1): cada
rol sube igual de rápido y **los jefes abren las zonas**. Pilares: partes
simples, nada obligatorio (design_pillars.md).

### 1. Qué cambia en cada jefe de zona

Los 10 jefes de arriba ya abren la zona siguiente (worldgen.md § 6.4:
al vencerlo, quien tenía esa zona como tope pasa a la siguiente) y ya
tienen su Ofrenda (persistent_dungeons.md § 4). Esta versión les suma,
uno por uno empezando por el de la zona 1:

1. **Patrón legible en 2–3 fases.** El jefe pasa a usar la máquina de
   fases y movimientos de los Jefes del Abismo (abyss_bosses.md § 2:
   `AbyssBossDef`, umbral de vida, rotación de movimientos, aviso
   `PRÓX: <movimiento>` una acción antes). No se duplica código: el
   catálogo nuevo `zone_bosses_catalog.dart` arma esas definiciones con
   los números de `kTuning[bosses]` y `GameCatalog.abyssOf` las devuelve
   además de las del Abismo. Nada del Abismo (Portal, Fragmentos, música,
   arena) los ve.
2. **Escalado co-op por tamaño de grupo y nivel de zona.** Encima del
   escalado de siempre (`ZoneRules.scaleBattle` al nivel del piso y la
   vida en grupo `groupHp`), el jefe con fases suma `partyHpPer` de vida
   y quiebre por jugador extra. Sus invocaciones son `adds` con grupo y
   `soloAdds` en solo.
3. **Dificultad normal y Eco.** La pelea **normal** está pensada para un
   grupo promedio del nivel de la zona (el máximo de la zona,
   `ZoneDef.maxLevel`). La **re-pelea Eco** es opcional: en el altar de
   la Ofrenda, OFRENDA DEL ECO paga `ecoCostMult` × la Ofrenda y revive
   al jefe con vida y quiebre × `ecoHp` y ATQ × `ecoAtk`; da `ecoLootRolls`
   tiradas de botín de jefe extra, `ecoMat` materiales del jefe (en vez
   de `bossMat`) y `ecoLegendBonus` más de chance de su legendario.
   Nunca hace falta para abrir nada.
4. **Botín propio del jefe para los oficios.** Cada jefe deja un
   **material de jefe** (`SmithMatKind.rare`, con afinidad) a cada
   jugador: `bossMat` en la normal, `ecoMat` en la Eco. Sirve como
   **engarce** en la forja por partes (profession_gear_v2.md § 3) con la
   afinidad del jefe, así alimenta los sistemas de equipo de los oficios
   sin ser obligatorio. Fuente en el detalle: "Jefe".

Todos los números viven en `kTuning[TuningId.bosses]` (Balance → Jefes
de zona).

### 2. Zona 1: Rey Limo — Marea Real (implementado)

Mecánica `mareaReal` (tipo `abyss`, invoca `slime`). Nivel de zona 5.

| Fase | Umbral | ATQ | Rotación (una por acción) |
|---|---|---|---|
| 1 «Corte de Gel» | 100 % | ×1 | ataque · ataque · **Ola Ácida** · ataque |
| 2 «División» | `p2Gate` 66 % | × `p2Atk` 1.1 | ataque · **Ola Ácida** · ataque · **invoca** |
| 3 «Marea Real» | `p3Gate` 33 % | × `p3Atk` 1.15 (sobre la 2) | **Marea Real** · ataque · **Ola Ácida** · ataque |

- **Ola Ácida**: golpe a todos ATQ × `wavePower` (0.8) + `wavePoison` (2)
  Veneno. **Marea Real**: ATQ × `tidePower` (1.1) a todos + Mojado y
  retrasa al grupo `tideDelay` (0.3) de turno.
- **Aviso**: cada golpe especial se anuncia en su turno anterior (chip
  `PRÓX: Ola Ácida` y la barra del jefe). Contrarrestar: **Defender**
  (½ daño, el golpe llega físico, no reacciona).
- **División** (al entrar a la fase 2 y con su movimiento `invoca`):
  completa sus limos hasta `adds` 3 (`soloAdds` 2 en solo). Los limos
  normales del grupo inicial cuentan.
- El golpe que cruza un umbral deja la vida justo en él (como el
  Devorador): cada fase se ve entera.
- **Furia**: `enrageTurns` (0 = sin furia en los jefes de zona).
- Sprites: `reyLimo` (fase 1, corona dorada), `reyLimoFase2` (rajado,
  goteando, corona torcida) y `reyLimoFase3` (marea violeta, ojos rojos,
  corona encendida) en `tool/export_boss_sprites.dart`; el manifest los
  mapea y `enemySpriteId` usa `Fase3` en la fase 3 (si falta, `Fase2`).
- Botín: **Corona de Gel** (`boss_gelcrown`, rara, tier 2, afinidad
  Veneno) × `bossMat` 1 (Eco: `ecoMat` 3).
- Desbloqueo: al vencerlo se abre la zona 2 (Bosque Hondo), como siempre.

- **Solo en Mundo.** La mecánica no está en `EnemyDef` (Travesía y las
  misiones viejas del prototipo siguen con el Rey Limo simple):
  `kZoneBossMechanics` la asigna y la pelea de una misión de zona la
  prende arrancando al jefe en fase 1 (`BossRules.applyBattle`).
- La Ofrenda del Eco no se guarda en la mazmorra persistente: si todos
  salen antes de pelear, el jefe queda vivo pero normal (deuda menor).

### 3. Barra del jefe (sistema de diseño)

Organismo `DsBossHealthBar` (`lib/app/design/ds_boss_bar.dart`, en la
galería): nombre, ECO si es la re-pelea, vida con las marcas de los
umbrales, `FASE n/3` y nombre de la fase, y la línea `PRÓX:` cuando el
próximo movimiento es especial. Arriba al centro de la batalla, solo con
un jefe con fases. Visual agnóstico a la lógica: recibe textos y números.

### 4. Red

Protocolo 100: `OfferBossAction` lleva `eco` (`{'t':'offer','eco':true}`)
y la misión manda `be` (el jefe revivido es Eco) para la barra.

### 5. Tuning (`kTuning[bosses]`)

| Clave | Valor | Qué |
|---|---|---|
| `p2Gate` / `p3Gate` | 0.66 / 0.33 | umbrales de fase |
| `p2Atk` / `p3Atk` | 1.1 / 1.15 | ATQ al entrar a cada fase |
| `wavePower` / `wavePoison` | 0.8 / 2 | Ola Ácida |
| `tidePower` / `tideDelay` | 1.1 / 0.3 | Marea Real |
| `adds` / `soloAdds` | 3 / 2 | limos de la División |
| `enrageTurns` / `enragePower` | 0 / 1.5 | furia (0 = no) |
| `partyHpPer` | 0.1 | vida y quiebre extra por jugador después del primero |
| `ecoHp` / `ecoAtk` | 1.6 / 1.3 | re-pelea Eco |
| `ecoCostMult` | 2 | × costo de la Ofrenda |
| `ecoLootRolls` | 1 | tiradas extra de botín de jefe |
| `ecoLegendBonus` | 0.15 | + chance del legendario |
| `bossMat` / `ecoMat` | 1 / 3 | material de jefe por jugador |

### 6. Pendiente (zonas 2–10)

Cada jefe de 2 a 10 conserva hoy su mecánica propia (telaraña, escarcha,
postura…). Falta, por jefe: su definición de fases en
`zone_bosses_catalog.dart` (2–3 fases que integren la mecánica actual en
la rotación), su material de jefe (afinidad del bioma) con ícono, los
sprites de fase y sus textos. El Eco, el escalado por grupo y la barra
ya valen para cualquiera que tenga definición.
