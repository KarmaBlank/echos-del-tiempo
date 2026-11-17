# Spec (aprobada; los jefes de las zonas 1-5 están implementados en la v0.2): 10 jefes

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
