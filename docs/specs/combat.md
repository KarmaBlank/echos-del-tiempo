# Spec: Combate y stats

Fuente de verdad: prototipo `ecos-del-tiempo.html`, funciones `stats(p)`,
`startBattle`, `nextTurn`, `statusTick`, `addStatus`, `enemyAct`, `hurt`,
`dmgEnemy`, `battleCmd`, `checkEnd`, y las tablas `CLASSES`, `WEAPONS`,
`SK`, `ULTS`, `DUALS`, `EN`, `STATUS`.

Implementación Dart:
- Stats: `lib/game_engine/rules/stats_calculator.dart`
- Motor de batalla: `lib/game_engine/rules/battle_engine.dart`
- Estado / comandos / eventos: `lib/game_engine/models/battle_*.dart`
- Catálogos (datos 1:1 del prototipo): `lib/game_engine/data/`

Tests: `test/game_engine/stats_calculator_test.dart`,
`test/game_engine/battle_engine_test.dart`.

## Redondeo

Todo redondeo usa el `Math.round` de JS (`floor(x + 0.5)`), helper
`jsRound` en `lib/game_engine/rules/js_math.dart`.

## Cálculo de stats (`StatsCalculator.calculate`)

Primero los valores base, cada uno redondeado como en el prototipo:

```
maxHp  = round(20 + VIT*4 + nivel*2)
maxMp  = round(4 + ESP*1.5 + nivel)
speed  = round((6 + AGI*0.5 + DES*0.1 − peso_arma + mejora_spd*0.3) * 10) / 10
crit   = min(0.60, 0.03 + DES*0.012 + mejora_crit*0.02)
defn   = defensa_clase + defensa_escudo_arma + bonus_def_batalla + mejora_def
atk    = round(fórmula_atk(atributos) * (1 + mejora_pow*0.12))
mag    = round(fórmula_mag(atributos) * (1 + mejora_pow*0.12))   // sin fórmula mag → usa la de atk
```

Después los mods del árbol (`passive_tree.md`):

```
maxHp  = max(1, round(maxHp * (1 + árbol.hp)))
maxMp  = round(maxMp * (1 + árbol.mp))
atk    = max(1, round(atk * (1 + árbol.atk)))
mag    = max(1, round(mag * (1 + árbol.mag)))
crit   = min(0.75, crit + árbol.crit)     // 0.40 con la keystone danza
speed  = round((speed + árbol.spd) * 10) / 10
defn   = max(0, defn + árbol.def)
defp   = min(0.60, defn * 0.03)          // % de daño que se resta
critMult = 2.0 con keystone halcon, si no 1.5
```

Loot v2 (loot.md § 12): con un arma con implícito / afijos, sus
atributos se suman antes de todo; `atk = round((fórmula + plano) × (1 +
%ATQ) × forja)` (igual MAG), y vida, maná, velocidad, crítico (antes del
tope 0.60), DEF, daño crítico, carga de ULT, curación y stacks de estados
suman lo suyo. La pasiva del arma entra como mecánica (`wp:<id>:<nivel>`)
con el sistema de disparadores del árbol (§ "Disparadores del árbol"). En
combate: robo de vida (% del daño de la acción), regeneración al empezar
el turno, resistencia a estados (−N stacks de Quemadura / Veneno /
Congelación, mín. 1) y curación recibida. `DerivedStats.breakdown` tiene
el desglose de cada stat para el log y la UI.

`bonus_def_batalla` (`p.bdef`) solo existe dentro de una batalla: lo suben
Fortaleza (+2) y Baluarte (+4), tope 12, y vuelve a 0 al empezar la
siguiente batalla.

## Inicio de batalla (`BattleEngine.start`)

- Multiplicador de vida enemiga por tamaño del grupo: `0.55 + 0.45 × jugadores`.
- Enemigo: `hp = round(hp_base × mult × (élite ? 2.6 : 1))`,
  `atk = round(atk_base × (élite ? 1.35 : 1))`,
  `vel = vel_base × (élite ? 1.1 : 1)`. Solo el primer enemigo del grupo
  puede ser élite. Crítico enemigo: 0.15 si es élite, 0.12 si es jefe,
  0.08 si no.
- Primer turno: enemigos en `IV × (0.35 + azar × 0.60)` (con su velocidad
  base); jugadores en `IV × (0.30 + azar × 0.50)`, salvo el que tocó al
  enemigo: `IV × 0.20`.
- Jugadores: se borran estados, provocación, protección, defensa y
  `bonus_def_batalla`. Vida y maná se conservan del campo (limitados al máximo).

## Timeline de turnos

- `IV(actor) = 100 / vel_efectiva`, con
  `vel_efectiva = vel × (1 + buff_vel) × (1 − 0.12 × stacks_congelación)`
  (`buff_vel`: Frenesí, ver § "Disparadores del árbol").
- `nextTurn`: actúa el actor vivo con `nextTurn` más bajo; en empate,
  jugadores antes que enemigos y el de menor índice primero. El reloj
  avanza a `max(reloj, nextTurn)`.
- Al empezar el turno de un jugador se le quitan Defender y Protección.
- Luego se procesan sus estados (ver abajo). Si muere o pierde el turno,
  su próximo turno es `reloj + IV` y el turno termina.
- Después de actuar, el próximo turno es `reloj + IV`.
  Defender: `reloj + IV × 0.7` (actúa antes).
- Si un jugador no actúa en 30 s, se defiende solo (`BattleEngine.timeout`)
  y su próximo turno es `reloj + IV`.

## Daño

El daño es **determinístico**: el único azar es si sale crítico (y algunas
probabilidades de estado marcadas abajo). La UI muestra siempre el
desglose exacto (log de batalla). Este comportamiento DEBE preservarse
(feedback de usuario: "los números deben ser claros, sin inconsistencias").

Jugador → enemigo (`dmgEnemy`):
```
daño = max(1, round(base × (crítico ? critMult_atacante : 1)))
```
Los enemigos no tienen defensa.

Enemigo → jugador (`hurt`):
```
daño = max(1, round(base × (crítico ? 1.5 : 1) × perforante × (defendiendo ? 0.5 : 1) × (1 − defp)))
perforante = 1.5 si el enemigo es perforante y el jugador es Paladín, si no 1
```
Recibir daño carga el ULT: `+ daño / maxHp × 110 × (1 + árbol.ult)`, tope 100.

### Desvíos intencionales respecto del prototipo

El prototipo tenía inconsistencias entre el número aplicado y el texto
del log; acá el log siempre muestra lo que realmente se aplicó:
- Con la keystone `halcon`, el log muestra `× 2 CRÍTICO` (el prototipo
  mostraba `× 1.5` aunque aplicaba `× 2`).
- Con la keystone `tormenta`, el log incluye el factor `× 1.25` / `× 0.85`.
- Los stacks de estado mostrados incluyen el bonus del árbol.
- Los textos no usan emojis (la fuente 8 bits no los tiene).

## Acciones del jugador (`BattleEngine.command`)

Un comando solo se acepta si la batalla no terminó, es el turno de ese
jugador y está vivo; si no, `command` devuelve `null` y no cambia nada.
Objetivo: el enemigo vivo pedido, o el primero vivo.

- **Ataque**: `ATQ` al objetivo. Con keystone `imparable`: `ATQ × 0.6`
  a todos. Paladín: 3% de aturdir. Rama `creyente`: 25% de curar 2% de
  vida máx. a todos los aliados. Rama `inherente`: 25% de aplicar 1 Sagrado.
- **Habilidad** (`SK`): debe estar en `kit de clase + habilidades del arma
  (+ habilidad fusionada)` y alcanzar el MP. Base `ATQ` (físicas) o
  `MAG` (mágicas) × poder. Con `tormenta`: × 1.25 si es a todos, × 0.85
  si es a uno. Crítico: `crit + bonus_crit_habilidad`. Después del daño
  aplica su estado (con probabilidad `stc` si la tiene, + bonus del árbol)
  y, si tiene `delay` y el enemigo sigue vivo, lo retrasa
  `IV(enemigo) × delay`.
  - Curación: `round((MAG × poder + 6) × (1 + árbol.heal))` a cada aliado
    vivo, y resta `cleanse` stacks de cada estado.
  - Aura Restauradora (regen): `round((MAG × poder + 4) × (1 + árbol.heal))`
    + Regeneración 3 a cada aliado. Con `creyente` además `MAG × 0.8` a
    cada enemigo.
  - Fortaleza: `bonus_def_batalla + 2` (tope 12). Protección: absorbe los
    golpes dirigidos a sus aliados hasta su próximo turno. Provocar: los
    próximos 3 ataques enemigos van contra él. Escudo de Fe: todo el
    equipo defiende. Prisa: adelanta `IV × 0.5` a cada aliado (sin
    aliados, devuelve el MP y repite turno).
- **ULT**: requiere carga 100 y la vacía. Depende del tipo de arma (`ULTS`).
  Baluarte: cura 30% a todos, todos defienden, Protección y DEF +4.
- **Dúo**: con un aliado vivo; ambos pagan 4 MP. Daño a todos:
  `(max(ATQ,MAG) + max(ATQ,MAG)_aliado) × poder`, crítico promedio de
  ambos. El aliado gasta su próximo turno (`max(su turno, reloj) + IV`).
- **Poción de vida**: cura 45% de la vida máx., revive y quita Quemadura
  y Veneno. Sin objetivo: el aliado con menor % de vida (puede estar caído).
  Si revive, su próximo turno es `reloj + IV`.
- **Poción de maná**: 50% del maná máx. Sin objetivo: el aliado vivo con
  menor % de maná.
- **Defender**: ½ daño hasta su próximo turno, que llega antes (`IV × 0.7`).

Carga de ULT por acción (no al usar el ULT):
`(base_acción + (hizo daño ? min(22, 5 + daño_total / maxHp_enemigo_mayor × 30) : 0)) × (1 + árbol.ult)`,
con `base_acción` = 8 en curación, regen y Protección, 6 en Fortaleza, 0
en el resto. `daño_total` no cuenta el daño que sobra al matar.

## Acciones enemigas (`BattleEngine.enemyTurn`)

- Objetivo: el primer aliado vivo con Provocar (y le resta 1); si no hay,
  uno vivo al azar. Si un aliado tiene Protección, recibe él el golpe.
- Jefe con `aoe` (Devorador de Eras), cada 3 acciones: `ATQ × 0.7` a
  todos, los retrasa `IV × 0.4` y les aplica su estado.
- Jefe, cada 4 acciones: Golpe Brutal `ATQ × 1.6`.
- Si no: `ATQ` al objetivo. Siempre aplica su estado (`inf`) si tiene.
- Jefes y élites con la carga de ULT en 100: avisan (pierden la acción)
  y en su siguiente turno lanzan su ULT. Ver
  docs/specs/break_and_enemy_ults.md § 2.

## Barra de quiebre

Cada enemigo tiene una barra que llenan los golpes del grupo; al llegar
al umbral queda **quebrado** (pierde su próximo turno y recibe +50% de
daño durante 2 turnos del grupo). Números, llenado por tipo de acción,
baja, umbral creciente y cancelación de la ULT avisada en
docs/specs/break_and_enemy_ults.md § 1. Daño a un quebrado:
`daño = max(1, round(base × crítico × Fractura × Cadena × Marca × 1.5))`
(log `× 1.5 QUIEBRE`), también en el daño secundario.

## Estados alterados

Se procesan al empezar el turno del afectado (`statusTick`), en este orden:

| Estado | Efecto | Máx. stacks |
|---|---|---|
| Quemadura | `max(1, min(8 × stacks, round(maxHp × 0.04 × stacks)))`; después los stacks se reducen a la mitad (hacia abajo) | sin límite |
| Veneno | `max(1, min(5 × stacks, round(maxHp × 0.03 × stacks)))`; pierde 1 stack | sin límite |
| Sagrado | `5 × stacks`; dura 3 turnos (se renueva al aplicar) | 9 |
| Regeneración | cura 5% de vida y maná máx.; pierde 1 stack (aplicar la deja en 3) | 3 |
| Aturdido | pierde el turno y se quita | 1 |
| Congelación | −12% velocidad por stack. Con 5: pierde el turno y vuelve a 0. Si no, pierde 1 stack | 5 |

La curación de Regeneración se aplica antes que el daño de los demás estados.
El Paladín recibe +1 stack de cualquier estado que no sea Regeneración.

## Fin de batalla

- Victoria: todos los enemigos caídos. Cada jugador recibe la suma de XP
  y créditos de los enemigos (× 3 los élite). El reparto y la subida de
  nivel quedan fuera del motor (los hace `SessionEngine`, ver missions.md).
- Derrota: todos los jugadores caídos.

## Entrar y salir de una batalla en curso

- `BattleEngine.join`: un jugador que llega a mitad de batalla entra con
  su vida y maná actuales y su próximo turno en `reloj + IV`. No cambia
  la vida de los enemigos.
- `BattleEngine.leave`: el jugador sale de la batalla; si tenía el turno,
  el turno queda libre. Si el resto del equipo está caído, la derrota se
  detecta al terminar el próximo turno enemigo.

## Eventos para la UI (`BattleEvent`)

Cada paso devuelve, en orden, lo que pasó (el equivalente semántico de
los `addFx` del prototipo, sin coordenadas ni colores: eso lo decide la
UI, ver docs/specs/battle_presentation.md):

| Evento | Cuándo |
|---|---|
| `TurnStartedEvent(actor)` | `nextTurn` le da el turno a alguien |
| `ActionEvent(actor, kind, skillId?, partnerId?, targetId?, allTargets)` | un actor empieza una acción, **antes** de los eventos que produce |
| `UltimateUsedEvent(actor, nombre)` | se usa una ULT (antes de su `ActionEvent`) |
| `DamageEvent(objetivo, daño, critical, critMultiplier, pierceMultiplier, fromStatus, statusSource?)` | cada golpe o daño de estado |
| `HealEvent(objetivo, n, mana)` | curación de vida o maná |
| `StatusAppliedEvent(objetivo, estado, stacks, weakness)` | `addStatus` aplicó stacks |
| `TurnSkippedEvent(actor, causa)` | aturdido o congelado ×5 |
| `DelayedEvent(objetivo)` | lo retrasaron en el timeline |
| `KnockedOutEvent(objetivo)` / `RevivedEvent(objetivo)` | cae / revive |
| `BattleEndedEvent(victoria, xp, créditos)` | `checkEnd` |
| `ProcEvent(actor, fuente, objetivo?)` | disparó una mecánica del árbol v2 (`fuente` = id en `kMechanics`) |
| `BuffAppliedEvent(objetivo, fuente, stat, valor, turnos)` | buff / debuff / marca con duración |
| `ShieldEvent(objetivo, cantidad, absorbed)` | ganó un escudo, o su escudo absorbió daño |
| `BreakEvent(objetivo, fase, barra, umbral, cancelledUlt)` | la barra de quiebre se llena (`fill`), baja (`decay`), se quiebra (`broken`), pierde el turno quebrado (`skipped`) o se recupera (`recovered`) |
| `EnemyUltWarningEvent(actor, ultId, nombre)` | un jefe / élite avisa su ULT |
| `EnemyUltEvent(actor, ultId, nombre, targetId?, allTargets, wipedBuffs)` | lanza su ULT: abre la acción (los golpes, estados y retrasos que siguen son de la ULT) |

`DamageEvent.sourceId`: id de la mecánica en el daño secundario (rebote,
explosión, eco, reflejo, sagrado). `DamageEvent.vulnerable`: el objetivo
estaba quebrado (lleva el +50%). `BattleEvent` no es `sealed`: un
`switch` que no conoce los eventos nuevos los ignora.

`ActionEvent.kind` (`BattleActionKind`):
- `attack` (con `targetId`; `allTargets` con la keystone `imparable`),
  `skill` / `ultimate` (con `skillId` = `SkillDef.id`, p. ej. `giro` o
  `ult_espada`; `targetId` solo si es de daño a un enemigo), `dual`
  (`partnerId`, siempre `allTargets`), `potion` / `ether` (`targetId` =
  el aliado que la recibe), `defend` (también al agotarse el tiempo);
- enemigos: `enemyAttack` y `enemyHeavy` (Golpe Brutal), con
  `targetId` = la víctima elegida (antes de la Protección),
  `enemyArea` (Colapso Temporal, `allTargets`).

`DamageEvent.statusSource` (solo con `fromStatus`): Quemadura si tenía
stacks de Quemadura, si no Veneno, si no Sagrado (el `hadBurn` del
prototipo elige aura y color con esto).

Todos los campos nuevos son opcionales: quien no los use no cambia.

## Disparadores del árbol (v2)

Detalle y números en passive_tree_v2.md § 3-5. Resumen del motor:

- Cada jugador lleva `mechanics` (ids de `kMechanics`, de notables y
  keystones nuevas) y `effects` (`TimedEffect`: buffs, debuffs, marcas,
  escudos, aturdido extendido). `_Turn._fire(disparador, dueño, ...)`
  evalúa las mecánicas del dueño con ese disparador (filtro, estado,
  probabilidad) y aplica sus efectos por tipo.
- Disparadores: `onHit` / `onCrit` (golpes primarios), `onStatusApplied`
  (estados de golpes primarios), `onSkill`, `onHeal`, `onKill` (1 vez por
  acción), `onEnemyDeath` (cualquier muerte, primer jugador con la
  mecánica), `onHitTaken` (golpe enemigo recibido), `onProtectHit` (golpe
  desviado por Protección), `onTurnStart` (después de los estados, si
  sigue vivo). Condiciones en el cálculo: `whileLowHealth` (ATQ efectivo
  y crítico), `vsStatus` / `vsMarked` (daño y crítico contra ese
  objetivo).
- Daño jugador → enemigo con árbol:
  `daño = max(1, round(base × (crítico ? critMult : 1) × Fractura × Cadena
  Infinita × Marca))`; `crit = min(tope, crit + condiciones)` (tope 0.40
  con danza). ATQ efectivo: `round(ATQ × (1 + buff_atq + Último Aliento))`
  (el log muestra `ATQ 26 (20 +30%)`).
- Daño enemigo → jugador: el ATQ del enemigo se multiplica por
  `1 + debuff` (Debilitar, log `ATQ 9 (debilitado)`); los escudos
  absorben antes que la vida y la carga de ULT usa el daño que pasa.
- Secundario (rebote, explosión, eco, reflejo, sagrado, ataque gratis):
  no dispara `onHit` / `onCrit` / `onStatusApplied`. Tope: 64 efectos por
  paso (`BattleEngine.maxProcsPerStep`).
- Efectos con duración: se descuentan al terminar el turno del portador
  (antes de calcular su próximo turno); los aplicados en su propio turno
  empiezan a contar en el siguiente.
- Turno: con Danza de Cuchillas (`extraTurn`) el próximo turno es
  `reloj`; con Sed de Sangre `reloj + IV × 0.5`.
- Alma de Hielo: la Congelación enemiga no baja sola mientras el jugador
  con la keystone esté en pie; sus Quemaduras no se aplican (log `sin
  Quemadura (Alma de Hielo)`). Martillo Bendito: el aturdido pierde un
  turno más (no jefes).
- Sin mecánicas no se tira azar extra: los números de siempre no cambian.
- Red: `Combatant` serializa `mech`, `fx`, `xt` (opcionales).
- Quiebre: el daño secundario llena la barra × 0.5 y los Aturdidos /
  Congelaciones de procs suman el +15 plano
  (docs/specs/break_and_enemy_ults.md § 1).

## Fuera de este motor

Lo que pasa alrededor de la batalla lo hace `SessionEngine`
(`lib/game_engine/rules/session_engine.dart`):
- Ritmo de la batalla (pausas, límite de 30 s) y conteo de K.O. de la
  misión: missions.md § "Batalla en la sesión".
- Reparto de XP y créditos, subida de nivel, drops de élite, contadores
  de la misión y derrota → misión fallida: missions.md y progression.md.
- Movimiento en el mapa y contacto con enemigos: world.md.
- Tienda, mejoras de armas, fusión y perfil: progression.md.
