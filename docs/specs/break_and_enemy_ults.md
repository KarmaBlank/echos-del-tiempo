# Spec: Barra de quiebre y ULT enemigas

Pedido del dueño: "sonidos de ataque de los enemigos y ultimates de los
enemigos, una barra de aturdimiento a lo Expedition 33". Se toma la
**mecánica** del género (barra de quiebre que se llena con golpes y deja
al enemigo vulnerable; ataques definitivos de jefes con aviso y
cinemática); el contenido es propio de Ecos del Tiempo.

Implementado. Motor: `lib/game_engine/rules/battle_engine.dart`
(`_addBreak`, `_break`, `_decayBreak`, `_tickVulnerable`, `_chargeUlt`,
`enemyAct`, `_enemyUlt`); datos: `lib/game_engine/data/enemies_catalog.dart`
(`breakMax`, `ultId`, `kEnemyUlts`, `kEliteUltId`). Escena:
docs/specs/battle_presentation.md § "Quiebre" y § "ULT enemigas"; sonido:
docs/specs/audio.md § "Quiebre y ULT enemigas". Tests:
`test/game_engine/break_and_enemy_ults_test.dart`,
`test/features/combat/break_fx_test.dart`,
`test/features/world/session_sfx_test.dart` (grupo "quiebre y ULT
enemigas"), `test/core/audio/sfx_catalog_test.dart`.

## Números refinados (antes de implementar)

Se simularon peleas (40 semillas, grupo de nivel 4-10 con ataques y
habilidades al azar) contra cada jefe. Con los umbrales del borrador
(Rey Limo 160, Gólem Reloj 220) y una baja del 15% los jefes casi nunca
se quebraban (la baja por turno igualaba lo que llena un grupo chico), y
con +20 de carga por turno las peleas terminaban antes de la primera
ULT. Cambios:

| Qué | Borrador | Final | Por qué |
|---|---|---|---|
| Umbral Limo / Murciélago / Gólem / Espectro | 40 / 30 / 80 / 60 | 25 / 20 / 50 / 40 | ~0.8 × su vida: un común se puede quebrar antes de morir |
| Umbral Rey Limo / Gólem Reloj / Devorador | 160 / 220 / 300 | 80 / 150 / 280 | ~0.35 × su vida: primer quiebre hacia el 40-50% de la vida del jefe, a veces un segundo |
| Escala por grupo | — | × `0.55 + 0.45 × jugadores` | la misma que la vida (más jugadores llenan más rápido) |
| Baja al empezar su turno | 15% del umbral | 10% | con 15% un grupo chico no llegaba nunca |
| Carga de ULT | +20 por turno, +1 cada 2% de vida | +25 por turno, +1 por cada 1% de vida; jefes y élites **empiezan con 40** | la primera ULT llega hacia su 3.er-4.º turno |

Resultado de la simulación (por batalla): quiebres 0.9-1.4, primer
quiebre con el 40-50% de la vida perdida; avisos 0.5-1.9 y ULT 0.2-1.8
(muchos avisos terminan cancelados por un quiebre). Con el sistema el
grupo gana **más** que sin él (los turnos de aviso y los quiebres
compensan la ULT): no endurece las peleas, les da ritmo.

## 1. Barra de quiebre (todos los enemigos)

- Cada enemigo tiene `breakGauge` 0..`breakMax`. Umbral base
  (`EnemyDef.breakMax`): Limo 25, Murciélago 20, Gólem 50, Espectro 40,
  Rey Limo 80, Gólem Reloj 150, Devorador 910 (v0.3, nivel 50); × `0.55 + 0.45 ×
  jugadores`; élite × 1.5 (`Combatant.breakBase`).
- **Se llena** con cada golpe del grupo a un enemigo vivo y no quebrado:
  `daño × factor`, redondeado a 0.1:
  - ataque básico × 1.0; habilidad física × 1.3; habilidad mágica (y la
    luz de Aura Restauradora) × 0.8; ULT × 2.0; dúo × 1.5;
  - crítico × 1.5 adicional;
  - daño secundario de notables (rebotes, explosión, eco, reflejo,
    sagrado, ataque gratis de Viento a Favor) × 0.5, sin crítico;
  - Aturdido o Congelación aplicados por el grupo: **+15 plano** por
    aplicación (también los de procs: Choque Térmico, el eco).
  - El daño de estados (Quemadura, Veneno, Sagrado) no llena.
- **Baja** 10% del umbral al empezar cada turno del enemigo si no está
  quebrado (`BreakEvent(decay)`).
- **Quebrado** al llegar al umbral (`BreakEvent(broken)`, log
  `¡QUIEBRE! X: pierde su turno, +50% de daño`):
  - pierde su próximo turno (`BreakEvent(skipped)`, log `X está
    QUEBRADO y pierde su turno`; se suma al Aturdido si también lo
    tiene) y su carga de ULT vuelve a 0;
  - recibe **+50% de daño** (`× 1.5 QUIEBRE` en el log,
    `DamageEvent.vulnerable`) durante **2 turnos del grupo**: se
    descuentan al terminar cada turno de un jugador (acción, tiempo
    agotado o turno perdido), sin contar el turno en que se quebró;
  - quebrado, la barra queda llena y no se llena más;
  - al terminar (`BreakEvent(recovered)`, log `X se recupera del
    quiebre`) la barra vuelve a 0 y el umbral sube +25% por quiebre
    (`breakBase × min(2, 1 + 0.25 × quiebres)`).
- Si el enemigo había **avisado su ULT**, el quiebre la cancela
  (`cancelledUlt`, log `· Diluvio Ácido cancelada`).

## 2. ULT enemigas (jefes y élites)

- Jefes: su ULT (`EnemyDef.ultId`); élites (cualquier tipo): Furia
  Élite. Los comunes no tienen.
- Carga `Combatant.ult` 0..100: empieza en 40, +25 al actuar en su turno
  y +1 por cada 1% de su vida máxima perdida (golpes, secundarios y
  estados). Se ve como una barra roja segmentada bajo la de quiebre.
- Con la carga en 100, en su turno **avisa** en vez de atacar
  (`EnemyUltWarningEvent`, `ultPending`, log
  `¡El Rey Limo se prepara para Diluvio Ácido! · Quiébralo, defiéndete
  o protégete`). El grupo tiene ese tiempo para quebrarlo, defenderse o
  protegerse.
- En su siguiente turno la lanza (`EnemyUltEvent`, que abre la acción;
  sin `ActionEvent`), con cinemática y sonido de 3 partes. La carga
  vuelve a 0. El aviso y la ULT no cuentan como acciones para el Golpe
  Brutal (cada 4) ni para Colapso Temporal (cada 3).

| Enemigo | Id | ULT | Efecto |
|---|---|---|---|
| Rey Limo | `eult_diluvio` | Diluvio Ácido | ATQ × 1.2 a todos + 2 Veneno |
| Gólem Reloj | `eult_engranaje` | Engranaje del Fin | ATQ × 1.5 al objetivo + 3 Congelación; retrasa a todos `IV × 0.5` |
| Devorador de Eras | `eult_finEras` | Fin de las Eras | ATQ × 1.4 a todos + 2 Quemadura; después borra los buffs del grupo (efectos positivos del árbol, escudos y DEF de batalla) |
| Élite (cualquiera) | `eult_furia` | Furia Élite | ATQ × 2.0 al objetivo, crítico garantizado (× 1.5) |
| Matriarca Araña | `eult_nido` | Nido Venenoso | ATQ × 1.1 a todos + 3 Veneno; con 2+ vivos atrapa en telaraña al de más vida (`EnemyUltExtra.web`) |
| Sierpe de Escarcha | `eult_aliento` | Aliento Glacial | ATQ × 1.2 a todos + 2 Congelación; rearma los cristales rotos (`reformCrystals`) |
| Caballero Hueco | `eult_juicio` | Juicio Hueco | ATQ × 1.9 al objetivo + 1 Aturdido; cambia de postura (`stanceShift`) |
| Hechicera del Eco | `eult_coro` | Coro de Ecos | ATQ × (1.0 + 0.3 por eco vivo) a todos; retrasa a todos `IV × 0.3`; rehace los ecos (`echoChorus`) |
| Bestia de Magma | `eult_erupcion` | Erupción Total | ATQ × 1.3 a todos + 2 Quemadura; la lava sube 3 turnos (`lavaFlood`) |
| Espectro Coronado | `eult_lamento` | Lamento Eterno | ATQ × 1.25 a todos + 2 Congelación; completa el séquito (`summonAll`) |
| Centinela del Vacío | `eult_colapsoVacio` | Colapso del Vacío | ATQ × 1.3 a todos, el marcado sin proteger × 2; marca al de más vida (`voidMark`) |

Mecánicas de cada jefe nuevo: docs/specs/bosses.md § "v0.2" y § "v0.3".
El Heraldo de las Eras (común de la zona 10) tiene Furia Élite aunque no
sea élite. El Devorador de Eras se rebalanceó a nivel 50 (umbral 910).

- Objetivo (a uno): como un golpe normal (Provocar primero, si no al
  azar). Defender reduce a la mitad, Protección desvía cada golpe al
  protector, los escudos absorben antes que la vida y el Paladín recibe
  su +1 stack de estado, como siempre. Debilitar baja el ATQ.
- Log: `Rey Limo · ULT Diluvio Ácido (todos, ATQ 13 × 1.2): Guerrero 14,
  Maga 16 · +2 Veneno`.
- Sesión: tras el paso de una ULT enemiga la pausa es de 2.3 s (como las
  del grupo); tras el aviso, 1.4 s para leer el cartel.

## 3. Sonidos enemigos

Docs/specs/audio.md § "Enemigos" y § "Quiebre y ULT enemigas": cada
ataque enemigo tiene un **wind-up** (se oye mientras el enemigo se echa
atrás) y el golpe; el impacto sobre el jugador es **propio de cada tipo**
(`enemy.hit.<tipo>`, en vez del genérico) y cae con el golpe visual a
160 ms; los enemigos suenan más fuerte que las acciones del grupo
(pico 0.42, jefes 0.45). Sonidos propios para el tic de la barra (sutil),
el quiebre (cristal), el golpe a un quebrado, el quebrado que pierde el
turno, el aviso de ULT y cada ULT enemiga (preparación, descarga,
impacto). Tope de 12 sonidos por paso como siempre.

## 4. Red

`Combatant` serializa (opcionales) `brkB`, `brk`, `brkN`, `vul`, `brkS`,
`eult`, `ultP`; la carga va en `ult` como la de los jugadores. Mecánicas
de jefe v0.2 y v0.3 (opcionales): `web` (atrapado), `stc` (postura), `stcN`
(turnos para cambiarla), `lava`, `vmk`, `phase`, `mchN`; evento `boss` (`BossMechanicEvent`: `id`, `ph`,
`tg`, `v`). Eventos:
`brk` (`BreakEvent`), `eultWarn`, `eult`; `DamageEvent.vulnerable` →
`vul`. Un estado o evento viejo sin esas claves se lee con los valores
por defecto (sin barra).

## 5. Tests angostos

`BattleEngine(breakEnabled: false, enemyUltsEnabled: false)` apaga el
sistema (sin barra ni ULT): los tests de reglas viejas que lo necesiten
pueden usarlo. Ninguno existente lo necesitó: sin golpes del grupo la
barra no se mueve, y el azar no cambia (el sistema no tira dados extra).
