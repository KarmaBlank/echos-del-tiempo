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
- Mensaje inicial: jefe `start_boss`, élite `start_elite`; si no,
  `start_first_strike` ("¡PRIMER GOLPE!") o `start_ambush`
  ("¡EMBOSCADA!") según la iniciativa (sin iniciativa: `start_ambush`).
- Repetidos (v0.13.1): `assignCombatantTags` da una letra A, B, C… a
  los enemigos del mismo tipo, a los aliados con el mismo nombre y a las
  invocaciones del mismo tipo, y la agrega al nombre ("Lobo B"). Se
  vuelve a llamar cuando entra alguien a mitad de batalla (jugador,
  séquito del jefe, invocación): los que ya tienen letra la conservan y
  el nuevo recibe la primera libre. Viaja por la red como `tag`.
- Jugadores: se borran estados, provocación, protección, defensa y
  `bonus_def_batalla`. Vida y maná se conservan del campo (limitados al máximo).

## Iniciativa del encuentro (`EncounterRules`)

Regla del dueño: quien provoca el encuentro actúa primero.

- `EncounterRules.kind`: el host mira el último paso del jugador que tocó
  (`stepX/stepY`, la diferencia entre sus dos últimas posiciones mientras
  camina; 0 si se detuvo). **PRIMER GOLPE** si se está moviendo
  (paso² ≥ 0.25: los pasos menores a 0.5 px son el redondeo a 0.1 px de la posición enviada y no pisan el último paso real) y `paso · (enemigo − (jugador − paso)) > 0` (desde donde arrancó el paso: pisar justo al enemigo también cuenta). Si no (quieto o
  alejándose) es **EMBOSCADA**.
- Primer golpe: abre el grupo y el que tocó es el primero. Emboscada:
  abren los enemigos y el que tocó (el líder del grupo, `e0`) es el
  primero. Jefes y élites usan la misma regla (solo cambia el mensaje).
  Entrar a un Jefe del Abismo desde la sala es siempre primer golpe.
- Por modo (`BattleEngine._applyInitiative`):
  - Línea de tiempo: el que abre queda con `nextTurn = mín(resto) × 0.5`
    (`applyTimelineOpener`; se reaplica después del escalado de zona/Eco).
  - Por fases: primer golpe saltea la fase enemiga de la ronda 1 (empieza
    la fase de jugadores, simultánea); emboscada = fase enemiga primero,
    `e0` primero (orden de lista).
  - Por bando: primer golpe = turno del grupo (por defecto); emboscada
    abre la ronda 1 con los enemigos, `e0` primero.
  - Por rondas: el orden de la ronda 1 es por velocidad con el que abre
    adelante.
- Travesía y vistas previas llaman `start` sin `encounter`: comportamiento
  anterior. No viaja nada nuevo por la red (usa `rd`, `act`, `ro`, `gp`).

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
  Defender: `reloj + IV × 0.7` (actúa antes). Pasar turno (v0.8.3):
  `reloj + IV × 0.5` (§ "Pasar turno").
- Si un jugador no actúa en 30 s, se defiende solo (`BattleEngine.timeout`)
  y su próximo turno es `reloj + IV`. (El timeout **no** es un Pasar:
  sigue defendiendo, sin el adelanto.) Los 30 s son del **turno entero**:
  una habilidad Instante no reinicia el reloj (§ "Pulso, precondiciones e
  Instante").
- Pulso (v0.9): +1 al empezar el turno de un jugador (aunque lo pierda
  por un estado). Ver § "Pulso, precondiciones e Instante".

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

### Familias de enemigos (v0.6)

Cada enemigo tiene familia (docs/specs/bestiary.md § 1): el daño del
grupo que pasa por `dmgEnemy` se multiplica por el factor de la familia
según los tipos del golpe (físico / mágico y el elemento: fuego, hielo,
Sagrado), después de la armadura y antes de la esquiva (`× 1.5 DÉBIL
Sagrado`, `× 0.7 RESISTE físico`; `DamageEvent.affinity`). Las curas y
regeneraciones de habilidad dañan a los no muertos (y a medias a los
espectros) con el mismo número que curan (`¡La cura quema al
Esqueleto! 36`). Las familias también dan inmunidades a estados (nota
`INMUNE a Veneno (No muerto)`), stacks de más / de menos, y multiplican
el llenado del quiebre, los retrasos, la Marca y el estado Sagrado. La
tabla es data (`kFamilyRules`); `BattleEngine(familiesEnabled: false)` la
apaga.

## Acciones del jugador (`BattleEngine.command`)

Un comando solo se acepta si la batalla no terminó, es el turno de ese
jugador y está vivo; si no, `command` devuelve `null` y no cambia nada.
Objetivo: el enemigo vivo pedido, o el primero vivo.

- **Ataque**: `ATQ` al objetivo. Con keystone `imparable`: `ATQ × 0.6`
  a todos. Paladín: 3% de aturdir; con un aliado vivo, **Escudo compartido** suma +15% a todo lo que aturde (básico y habilidades, `duoStunBonus`, editable en Balance → clase). Rama `creyente`: 25% de curar 2% de
  vida máx. a todos los aliados. Rama `inherente`: 25% de aplicar 1 Sagrado.
- **Habilidad** (`SK`): debe estar en `kit de clase + habilidades del arma
  (+ habilidad fusionada) + kit de la ascensión` (+ combo de clase y
  Quebrar base, que agrega el motor), alcanzar el MP y el **Pulso** y
  cumplir sus **precondiciones** (v0.9, § "Pulso, precondiciones e
  Instante"; si no, `command` devuelve `null`). Desde
  v0.5 ninguna clase tiene kit de clase (el del Paladín pasó al Guardián,
  ascension.md § 4); `ClassDef.kitSkillIds` queda vacío. Base `ATQ` (físicas) o
  `MAG` (mágicas) × poder. Con `tormenta`: × 1.25 si es a todos, × 0.85
  si es a uno. Crítico: `crit + bonus_crit_habilidad`. Después del daño
  aplica su estado (con probabilidad `stc` si la tiene, + bonus del árbol)
  y, si tiene `delay` y el enemigo sigue vivo, lo retrasa
  `IV(enemigo) × delay`.
  - Curación: `round((MAG × poder + 6) × (1 + árbol.heal))` a cada aliado
    vivo, y resta `cleanse` stacks de cada estado.
  - Aura Restauradora (regen, kit del Guardián, poder 1.0):
    `round((MAG × poder + 4) × (1 + árbol.heal))` + Regeneración 3 a cada
    aliado. Con `creyente` además `MAG × 0.8` a cada enemigo.
  - Fortaleza (kit del Guardián): `bonus_def_batalla + 2` (tope 12) y sus
    efectos de grupo (escudo 15% y −10% daño, ascension.md § 4).
    Protección (kit del Guardián): absorbe los golpes dirigidos a sus
    aliados hasta su próximo turno (y −20% de daño propio 1 turno). Provocar: los
    próximos 3 ataques enemigos van contra él. Escudo de Fe: todo el
    equipo defiende. Prisa: adelanta `IV × 0.5` a cada aliado (sin
    aliados, devuelve el MP y repite turno).
- **ULT**: requiere carga 100 y la vacía. Depende del tipo de arma (`ULTS`).
  Baluarte: cura 30% a todos, todos defienden, Protección y DEF +4.
- **Dúo**: con un aliado vivo; ambos pagan 4 MP. Daño a todos:
  `(max(ATQ,MAG) + max(ATQ,MAG)_aliado) × poder`, crítico promedio de
  ambos. El aliado gasta su próximo turno (`max(su turno, reloj) + IV`).
  De clase o de armas (v0.8.3): ver § "Dúos".
- **Poción de vida**: cura 45% de la vida máx., revive y quita Quemadura
  y Veneno. Sin objetivo: el aliado con menor % de vida (puede estar caído).
  Si revive, su próximo turno es `reloj + IV`.
- **Poción de maná**: 50% del maná máx. Sin objetivo: el aliado vivo con
  menor % de maná.
- **Éter** (v0.21, loot.md § 17.6): revive a un aliado caído con el 100%
  de su vida máx. y le quita Quemadura y Veneno; su próximo turno es
  `reloj + IV`. Sin caídos no vale.
- **Defender** (en la categoría ARMA desde v0.20.0, battle_attack_menu.md
  § 6): ½ daño hasta su próximo turno, que llega antes (`IV × 0.7`); +2
  Pulso (+1 si su turno anterior también fue Defender), +6 de ULT y +6
  más al primer golpe recibido defendiendo. La defensa automática por
  tiempo agotado no se premia (+1 Pulso, sin ULT).
- **Pasar turno** (`PassCommand`, v0.8.3): ver abajo.

### Dúos (v0.8.3)

Hay dos familias de dúos, todas en `GameCatalog.duals` (`kAllDuals`):

- **De clase** (`kDuals`, `skills_catalog.dart`, del prototipo): clave
  `dualKey(claseA, claseB)` = las dos clases en orden alfabético unidas
  por `+` (`guerrero+maga`).
- **De armas** (`kWeaponDuals`, `weapon_duals_catalog.dart`, nuevos en
  v0.8.3): clave `w_<nombre>` (sin `+`), con `DualDef.weapons` = el par
  de tipos de arma (`WeaponDef.type`) que lo habilita, en cualquier
  orden y sin importar la clase.

Disponibilidad (`dual_rules.dart`, puro, lo usan motor y UI):
`dualFits(id, dúo, p, q)` — de clase si `id == dualKey(clase p, clase
q)`; de armas si `{arma p, arma q}` es su par. `dualIdsFor(duals, p, q)`
= primero el de clase (si el par tiene), después los de armas en el
orden del catálogo. Además: el aliado vivo y 4 MP cada uno (igual que
antes; no hay regla de "turnos cercanos": cualquier aliado vivo sirve,
y pierde su próximo turno). Si un par habilita varios dúos, se ofrecen
**todos** (DÚOS lista cada uno). Vale igual para co-op y para los
compañeros de la party en solitario (su turno manual usa el mismo menú).
En los modos de turno agrupados (Por fases, Por bando, Por rondas) el
aliado que **ya actuó** en este turno del grupo no puede sumarse: el
motor lo rechaza y la UI muestra esa fila deshabilitada con el motivo
("X ya actuó en este turno."); si no queda ningún dúo posible, la
categoría DÚOS se ve gris (antes se ofrecía habilitada y el toque no
hacía nada o, en un cliente, solo reiniciaba el menú).

Comando: `DualCommand(partnerId, dualId?)`. `dualId == null` = el dúo de
clase del par (exactamente v0.8.2); si no, ese dúo, y el comando se
rechaza si el par no lo puede hacer (`dualFits`). `ActionEvent` del dúo:
`skillId` = la clave del dúo (`guerrero+maga` o `w_...`).

Elemento: el de su estado (`elementOfDual` = `statusElement(status)`,
físico si es Aturdido). Todos los golpes del dúo llevan ese elemento:
**ceban y detonan reacciones** como cualquier golpe elemental (§
"Elementos y reacciones").

Balance: los dúos de armas son entidades `dual` del parche de balance
como los de clase (poder y estado editables; `weapons` no se edita).

Ritmo (sesión): después de un dúo el host espera 1.5 s antes del
próximo paso (la cinemática de dúo dura 1.6 s; ULT 2.3 s, resto 0.8 s).

| Id | Armas | Nombre | Estado | Elemento | Poder |
|---|---|---|---|---|---|
| `w_flechaArcana` | arco + báculo | Flecha Arcana Gemela | Cargado 1 | Electro | 1.45 |
| `w_bastionRunico` | espada+escudo + tomo | Bastión Rúnico | Sagrado 2 | Sagrado | 1.45 |
| `w_fuegoCruzado` | dagas + rifle | Fuego Cruzado Letal | Quemadura 2 | Fuego | 1.45 |
| `w_terremotoDoble` | hacha + martillo+escudo | Terremoto Doble | Aturdido 1 (40%) | Físico | 1.45 |
| `w_saetaVoltaica` | varita + ballesta | Saeta Voltaica | Cargado 1 | Electro | 1.45 |
| `w_juicioPerforante` | lanza + maza+escudo | Juicio Perforante | Sagrado 2 | Sagrado | 1.45 |
| `w_filoIgneo` | espada + varita | Filo Ígneo Arcano | Quemadura 2 | Fuego | 1.45 |
| `w_hojaMaldita` | tomo + dagas | Hoja Maldita | Veneno 2 | Veneno | 1.45 |
| `w_tajoGlaciar` | hacha + báculo | Tajo Glaciar | Congelación 1 | Hielo | 1.45 |
| `w_diluvioAstas` | lanza + arco | Diluvio de Astas | Mojado 1 | Agua | 1.45 |

Los 13 tipos de arma aparecen en al menos un dúo. "Fuego Cruzado" ya era
el dúo `tirador+tirador`: el de dagas + rifle se llama "Fuego Cruzado
Letal" para no repetir nombre. Los 10 de clase siguen igual
(`guerrero+maga` Espada Llameante ... `tirador+tirador` Fuego Cruzado).

Red: `du` en el JSON del comando (aditivo, sin subir `kProtocolVersion`).
Un host v0.8.2 lo ignora y hace el dúo de clase del par (o rechaza el
comando si el par no tiene dúo de clase): para usar los dúos de armas el
**anfitrión** tiene que tener v0.8.3.

### Pasar turno (v0.8.3)

Pedido del dueño ("botón de saltar turno"). Termina el turno **sin
actuar** para que el próximo llegue antes: sirve para esperar la reacción
o el cebado de un aliado (p. ej. dejar que la Maga moje al enemigo y
volver justo después a detonarlo) o para reordenar el timeline.

| Qué | Valor |
|---|---|
| Próximo turno | `reloj + IV × 0.5` (`BattleEngine.passTurnFactor`; acción normal × 1, Defender × 0.7) |
| Carga de ULT | ninguna (no hay daño ni acción) |
| Defender | no (`defending` queda en `false`: recibe el daño completo) |
| MP / pociones | no gasta |
| Procs del árbol (`onSkill`, `onAttack`...) | ninguno |
| Efectos con duración | bajan 1 turno (`tickEffects`), como cualquier turno terminado |
| Eventos | ninguno de acción (no hay `ActionEvent` nuevo); solo el log `X pasa el turno (el próximo llega antes)` |

Notas de balance:
- Como el próximo turno llega antes, lo que se dispara "al empezar el
  turno" (estados como Veneno/Quemadura, regeneración del arma,
  `onTurnStart`) se procesa antes también: pasar seguido no es gratis.
- Pasar dos veces seguidas = un turno entero sin actuar (`0.5 + 0.5`).
- El AUTO de los compañeros (`CompanionAi`) **nunca** pasa.
- `passTurnFactor` es una constante del motor (no está en la admin de
  balance todavía).
- Validación: como cualquier comando (`command` → `null` fuera de turno,
  batalla terminada o actor caído). Sin enemigos vivos también `null`.

Red (host-autoritativo, sin subir `kProtocolVersion`): viaja como
`{"t":"cmd","a":"def","ps":true}`, una variante aditiva de Defender. Un
host v0.8.2 ignora `ps` y lo resuelve como Defender (degrada sin romper);
un host v0.8.3 lo resuelve como Pasar. Sin `ps` (o `ps: false`) sigue
siendo Defender.

### Pulso, precondiciones e Instante (v0.9)

combo_balance.md § 5.2 (paso 7). Todo en `BattleEngine` (Dart puro),
`SkillRequirements` (`rules/skill_requirements.dart`, la usan host, UI e
IA) y el catálogo (`SkillDef.pulse`, `instant`, `requires`).

**Pulso** (`Combatant.pulse`, solo jugadores; enemigos e invocaciones 0):

| Qué | Pulso |
|---|---|
| Inicio de la pelea (y al entrar a mitad de batalla) | 1 (`pulseStart`) |
| Empezar su turno (`nextTurn`) | +1 |
| Ataque básico | +1 (no al liberar a un aliado de la telaraña) |
| Golpe primario a una debilidad o que reacciona (incluye Convergencia) | +1, una vez por acción (una habilidad a todos que reacciona en 3 enemigos da +1) |
| Defender (v0.20.0, battle_attack_menu.md § 6) | +2; +1 si su turno anterior también fue Defender |
| Defensa automática del tiempo agotado | +1 (sin ULT, corta la racha) |
| Pasar, pociones, dúos, ULT | 0 (salvo lo que el golpe gane por debilidad o reacción) |
| Tope | 5 (`pulseMax`) |

- La habilidad cobra su Pulso y su MP al usarse, antes del golpe; lo que
  gane el golpe (debilidad, reacción) entra después. La ULT y los dúos
  no usan Pulso.
- No se guarda entre batallas (cada pelea arranca en 1).

**Precondiciones** (`SkillDef.requires`, lista de `SkillReq`; todas se
tienen que cumplir):

| `SkillReqKind` | Texto ("Necesita: …") |
|---|---|
| `targetStacks(estado, n)` | `objetivo con 5+ de Veneno` |
| `targetFissured` | `objetivo Fisurado` |
| `targetMarked` (`BuffStat.damageTaken` > 0) | `objetivo con Marca` |
| `selfHpBelow(f)` | `tu vida bajo el 50%` |

- El objetivo es el del comando (o el primer enemigo vivo). En una
  habilidad a todos, una precondición de objetivo vale si la cumple
  **algún** enemigo vivo.
- `SkillRequirements.missing(sk, actor, objetivo)` devuelve lo que falta,
  en orden: `N MP`, `Pulso N`, cada precondición. El host rechaza el
  comando si no está vacío; la UI muestra el botón desactivado con
  `Necesita: 3 MP · Pulso 2 · objetivo con 5+ de Veneno`.

**Instante** (`SkillDef.instant`):
- La habilidad se resuelve entera (daño, estados, procs `onSkill`, carga
  de ULT) pero **no termina el turno**: `currentId` sigue siendo el
  jugador, su `nextTurn` no se mueve, sus efectos con duración no bajan y
  la vulnerabilidad del quebrado no descuenta. `Combatant.chained = true`
  y el log suma `Instante: una acción más`.
- Una por turno: con `chained`, otra Instante se resuelve como una acción
  normal (termina el turno). Después de una Instante se puede hacer
  **cualquier** acción (atacar, otra habilidad, ULT, dúo, poción,
  Defender).
- `chained` vuelve a `false` al empezar su próximo turno.
- **Pasar** con `chained` = "Terminar turno": termina sin el adelanto
  (`reloj + IV`, × 1, log `X termina el turno`). Sin `chained`, Pasar es
  como siempre (× 0.5). Decisión del paso 7 (fuera del spec): si no,
  Instante + Pasar era actuar y además adelantar el próximo turno.
- **Tiempo agotado**: el reloj de 30 s (`SessionBattle.turnTime`) se
  reinicia solo cuando empieza otro turno, así que cuenta el turno entero;
  si se agota después de una Instante, defiende y termina.
- **Desde v0.20.0 las Instante viven en ARMA** (debajo de Atacar y
  Defender, con el separador "Instante — no terminan tu turno"); en
  HABILIDADES ya no aparecen (battle_attack_menu.md § 6). Historia:
- **Menú de HABILIDADES (v0.10.x, pedido del dueño):** las Instante van
  primero, con la marca `[INSTANTE]` en celeste junto al nombre y un
  etiqueta "[INSTANTE] · no termina tu turno" en el panel derecho cuando
  está bajo el cursor (v0.19.1, battle_presentation.md; antes era un
  separador arriba de la lista). Con `chained` el
  encabezado del menú dice "Encadenaste: te queda una acción". Cada fila
  lleva su objetivo (`skillReach`: `[1 enemigo]`, `[TODOS]`,
  `[aliado]`, `[grupo]`, `[vos]`); con el cursor o el mouse sobre
  una habilidad contra enemigos la escena marca a quién afectaría (todos
  o el objetivo actual). El detalle arranca con un resumen de una línea
  ("A TODOS · Fuego · 32 c/u · +2 Quemadura"). Si no se puede usar, la
  fila sale atenuada y el detalle muestra arriba, en rojo, una línea por
  condición (`SkillRequirements.missingLines`: "Falta: 3 MP (tenés 1)",
  "Falta: Pulso 2 (tenés 1)", "Necesita: objetivo Fisurado"); confirmar
  no hace nada.
- Si la Instante gana la batalla, termina como cualquier acción.
- Sesión: después de una Instante el host espera la pausa normal (0.8 s)
  y vuelve a esperar al mismo jugador (`waitingForPlayer`); el AUTO de los
  compañeros elige de nuevo (solo_party.md § 4.1).

**Red**: los comandos no cambian (la habilidad viaja por id). En el
estado, `Combatant` suma `pls` (Pulso) y `chn` (encadenó), opcionales:
sin ellos se lee 0 y `false`. Van dentro de `kProtocolVersion` 13 (v0.9,
todavía sin publicar).

**UI**: la tarjeta de cada jugador muestra 5 pips de Pulso (oro llenos,
borde celeste si encadenó); el tooltip dice `Pulso n/5` y `+1 acción
(Instante)`. En HABILIDADES el costo es `N MP` y `Pulso N`, la fila de
una Instante dice `Instante` (no, si ya encadenaste) y el botón se
desactiva con el `Necesita: …`. Después de una Instante, PASAR dice
`Terminar turno`.

### Variantes de habilidades (v0.5)

48 habilidades nuevas en `data/skill_variants_catalog.dart`
(`kSkillVariants`, se suman a `kSkills`; 120 en total). Cada una tiene
familia (`kSkillVariantFamily`) y "se parece" a una habilidad existente
(`kSkillLooks`): de ahí salen su color, su FX y su firma de sonido (sin
arte ni sonido nuevo). Los campos nuevos de `SkillDef` vienen apagados;
ninguna variante se apunta a un aliado a mano: lo que dice "al más
herido" elige al aliado vivo con menor % de vida.

| Campo | Efecto |
|---|---|
| `lowestAlly` | Curación / Regeneración solo al aliado más herido. |
| `revive` | Curación: si hay un aliado caído, revive al primero con `round(vida_máx × revive)` (con `cleanse` le quita todos los estados; si no, Quemadura y Veneno), `RevivedEvent`, su próximo turno es `reloj + IV`; y no cura a nadie más. Sin caídos: cura normal. |
| `overheal` | Curación: lo que sobra (vida llena) × `overheal` se vuelve escudo (`shieldTurns`). |
| `drainHeal` | Daño: `round(daño_de_la_acción × drainHeal)` cura al aliado más herido (si no está lleno). |
| `allyShield` / `selfShield` | Escudo de `vida_máx_del_que_la_usa × valor` (× escudos del árbol) al más herido / a uno mismo, por `shieldTurns` (2). |
| `shieldReflect` | Los escudos de esa habilidad devuelven `round(absorbido × valor)` al enemigo que pega (daño secundario). |
| `shieldBurst` | Al romperse por daño, explota: `ATQ_dueño × valor` a cada enemigo (secundario). |
| `shieldGrow` | Tras absorber, el escudo queda en `max(resto, min(50% vida máx. del portador, resto + absorbido × valor))`. |
| `hits` | Golpes seguidos al mismo objetivo, cada uno de `poder` (todos primarios). |
| `pierce` | Tras el golpe a un objetivo, golpea a cada enemigo vivo **detrás** (siguientes en la formación) con `base × pierce` (secundario: sin árbol), con el estado y los debuffs. |
| `bounces` | Rebota N veces a otro enemigo vivo al azar (`base × 0.7^k`); si no hay otro, vuelve al mismo. |
| `charge` | Disparo cargado: no pega; pone en el tirador un `TimedEffect` `BuffStat.charge` (valor `round(ATQ × charge)`, `ownerId` = objetivo). Al empezar su próximo turno cae como daño secundario sobre el objetivo (o el primer enemigo en pie) + su estado; si mata al último, la batalla termina. Carga ULT 6. |
| `debuffs` | `PartyBuff`s a cada enemigo golpeado (o a los objetivos de una de apoyo): Marca `damageTaken` (+daño recibido de todos), Debilitar `attack` < 0, Lentitud `speed` < 0. |
| `breakBonus` | `factor_de_quiebre × (1 + breakBonus)`. |
| `ultDrain` | Silencio: resta esa carga de ULT a cada enemigo golpeado (no si ya la anunció). |

Familias (ids): **Curación** `curaFocal` (2.6 al más herido), `rocio`
(0.7 a todos), `brotes` (regen 0.5 a todos), `semilla` (regen 1.2 al más
herido), `purificar` (1.2 + quita todo, al más herido), `resurreccion`
(revive 35%), `fenix` (revive 70% sin estados), `graciaDesbordante` (2.0 al más
herido, desborde 100%), `marea` (1.2 a todos, desborde 60%),
`flechaSanadora` / `drenar` / `sifon` (drenan 100/60/50%). **Escudos**
`escudoArcano` (30% al más herido), `barrera` (12% a todos),
`egidaEspinosa` (22% + refleja 60%), `escudoVolatil` (20% + explota ATQ
× 1.2), `bastionCreciente` (12% propio, crece 130%, 3 turnos), `retoEscudado`
(Provocar ×2 + 20% propio), `murallaFe` (18% a todos + refleja 30%),
`cupula` (10% a todos + −10% daño). **Disparos** `flechaPerforante`,
`balaTraspasante`, `tiroRebote`, `dagaSaltarina`, `disparoCargado`
(ATQ × 3.4), `viroteAsedio` (ATQ × 4.2, 50% aturdir), `rafagaTriple`
(3 × 0.6), `cadencia` (5 × 0.45), `flechaMarcadora`, `senalar` (Marca 35%
sin daño, turno 40% antes), `flechaIncendiaria`, `flechaEscarcha`,
`balaCorrosiva`, `tiroQuebrantador` (+100% quiebre). **Debuffs**
`rompearmaduras`, `rugidoIntimidante` (−25% ATQ a todos, sin daño),
`golpeDebilitante`, `lentitud`, `maldicion`, `pesoTiempo`. **Control**
`golpeConmocion` (50% aturdir), `silencio` (−50 ULT), `selloSagrado`,
`retroceso` (retrasa 35% a todos). **Apoyo** `inspirar`, `vientoPrisa`,
`impulso`, `ojoAguila`. Números exactos: el catálogo.

Carga de ULT por acción (no al usar el ULT):
`(base_acción + (hizo daño ? min(22, 5 + daño_total / maxHp_enemigo_mayor × 30) : 0)) × (1 + árbol.ult)`,
con `base_acción` = 8 en curación, regen y Protección, 6 en Fortaleza, 0
en el resto. `daño_total` no cuenta el daño que sobra al matar.

### Objetivo de las curas (v0.20.14)

`SkillCommand.targetId` de una cura (`SkillKind.heal` sin revivir): un
enemigo vivo con `healHarm > 0` → daño Sagrado solo a él
(bestiary.md § 1.4.1); un aliado vivo (solo curas de un blanco) → lo
cura a él; cualquier otro valor o `null` → como siempre (más herido o
grupo). El host lo valida; el cliente no manda el enemigo apuntado en
las curas.

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
| Congelación | −6% velocidad y +10% quiebre recibido por stack. Con 5: pierde el turno y queda **Quebradizo** (el próximo golpe físico ×1.5 y se descongela; si nadie lo rompe, se descongela al turno siguiente) y después resiste la Congelación 2 turnos. Si no, pierde 1 stack (v0.7) | 5 |
| Mojado (v0.7) | sin daño; dura 2 turnos propios (se renueva, no acumula). Lo detonan Electro y Hielo | 2 |
| Cargado (v0.7) | sin daño; dura 1 turno propio. Lo detona Agua | 1 |

La curación de Regeneración se aplica antes que el daño de los demás estados.
El Paladín recibe +1 stack de cualquier estado que no sea Regeneración.

### Aturdido y Congelación ×5: un controlado nunca actúa (v0.5.1)

- El control se evalúa con los estados que tenía **al empezar** el
  turno. Si el daño de los estados de ese mismo `statusTick` lo cambia
  (el Devorador cruza el 50%, se transforma y la fase 2 limpia los
  estados), el aturdido / congelado ×5 igual pierde ese turno; el
  Martillo Bendito no extiende un aturdimiento que la transformación
  quitó.
- Un aturdimiento que entra **durante la acción** del propio afectado
  (hoy ningún proc lo hace: Represalia / Penitencia / Égida devuelven
  daño, que puede quebrar) no corta esa acción: cuenta desde su
  **próximo** turno. Lo mismo el Quiebre.
- El log informa el **resultado**, no la probabilidad: una habilidad con
  probabilidad escribe `+1 Aturdido (30%)` si entró, `Aturdido: falla
  (30%)` si no, y a todos `+1 Aturdido a 1 de 3 (15%)`. Sin probabilidad,
  `+1 Aturdido` solo si entró en alguno (a un jefe con séquito el log
  dice INMUNE y no lo nombra). El `¡aturde!` del ataque del Paladín, el
  "queda aturdido" de Choque Térmico y las notas de stacks extra / estados
  que pasan solo aparecen si `addStatus` aplicó el estado (mismo criterio
  que `StatusAppliedEvent`).
- La Congelación por debajo de 5 stacks solo frena (−6% velocidad por
  stack desde v0.7): no hace perder el turno.

### Elementos y reacciones (v0.7)

Spec: docs/specs/elemental_reactions.md (§ 9: cómo quedó en el motor).
Cada golpe tiene un elemento (`elementOf`; enemigos `enemyAttackElement`
/ `enemyUltElement`). Si el objetivo tiene el estado que ese elemento
detona, hay **una** reacción: Mojado + Electro = Electrocución (×1.5,
Aturdido 1), Veneno + Fuego = Explosión tóxica (golpe × stacks, 50% al
resto de su bando, tope 25% de vida en jefes), Mojado + Hielo =
Congelación súbita, Congelación + Fuego = Derretir (×1.5), Cargado + Agua
= Cortocircuito (50% salta al siguiente). Simétrico: los enemigos
también detonan los estados de los jugadores.

Elemento por familia de habilidad (tabla completa en `kSkillElement`):

| Elemento | Habilidades |
|---|---|
| Fuego | las que aplican Quemadura (Chispa, Bola de Fuego, Llamarada, Infierno, Golpe Ígneo, Erupción, Tajo Carmesí, Flecha Solar / Incendiaria, Virote Ígneo, Meteoro), Prisma Elemental, Trinidad |
| Hielo | las que aplican Congelación (Lanza de Hielo, Ventisca, Escarcha Fugaz, Tajo Temporal, Corte Glacial, Vendaval, Saeta, Cero Absoluto, Flecha de Escarcha, Paradoja) |
| Veneno | las que aplican Veneno (dardos, nieblas, flechas y dagas tóxicas, Plaga, Red de Caza, Tormenta de Flechas) |
| Sagrado | curas y regeneraciones, `kHolySkillIds`, Juicio Final |
| Agua | Marea Vital y las 10 nuevas (Chorro, Oleada, Géiser, Torrente, Bruma Densa, Escudo de Agua, Tajo de Marea, Remolino, Lanza de las Mareas, Flecha Acuática) |
| Electro | Flecha Rayo, Descarga y las 10 nuevas (Chispazo, Cadena de Rayos, Tormenta Eléctrica, Descarga Estática, Campo Estático, Corriente, Golpe de Trueno, Puñalada Eléctrica, Flecha Voltaica, Relámpago) |
| Físico (neutro) | el resto (ataques, arcanas, apoyo, control) |

Habilidades nuevas (v0.7, `kElementalSkills`): Chorro de Agua (3 MP,
mágico ×1.5, Mojado), Oleada (8, ×1.0 a todos, Mojado), Géiser (5, ×1.8,
retrasa 0.3, Mojado), Torrente (7, ×2.3: detonador de Cargado), Bruma
Densa (6, ×0.5 a todos, Mojado, −10% velocidad 2 turnos), Escudo de Agua
(5, escudo 20% al aliado más herido 2 turnos), Tajo de Marea (4, físico
×1.6, Mojado), Remolino (6, físico ×0.9 a todos, Mojado), Lanza de las
Mareas (5, físico ×1.5, atraviesa 50%, Mojado), Flecha Acuática (3,
físico ×1.3, Mojado); Chispazo (3, mágico ×1.5, Cargado), Cadena de Rayos
(7, ×1.3, 2 rebotes, Cargado), Tormenta Eléctrica (10, ×1.1 a todos,
Cargado), Descarga Estática (5, ×1.2, Cargado + 20% Aturdido), Campo
Estático (6, ×0.5 a todos, Cargado, Marca +10% 2 turnos), Corriente (5,
adelanta 35% a los aliados), Golpe de Trueno (5, físico ×1.8, +30%
quiebre, Cargado), Puñalada Eléctrica (3, físico ×1.3, +20% crít.,
Cargado), Flecha Voltaica (4, físico ×1.5, Cargado), Relámpago (6, físico
×2.3, +15% crít.: detonador de Mojado). Cada una se ve y suena como una
existente (`kSkillLooks`).

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
  (`partnerId`, siempre `allTargets`; `skillId` = clave del dúo desde
  v0.8.3), `potion` / `ether` (`targetId` =
  el aliado que la recibe), `defend` (también al agotarse el tiempo);
- enemigos: `enemyAttack` y `enemyHeavy` (Golpe Brutal), con
  `targetId` = la víctima elegida (antes de la Protección),
  `enemyArea` (Colapso Temporal, `allTargets`).

`DamageEvent.statusSource` (solo con `fromStatus`): Quemadura si tenía
stacks de Quemadura, si no Veneno, si no Sagrado (el `hadBurn` del
prototipo elige aura y color con esto).

Todos los campos nuevos son opcionales: quien no los use no cambia.

## Disparadores del árbol (v2 / v3)

Detalle y números en passive_tree_v2.md § 3-5 y passive_tree_v3.md § 5-9 (v3 suma la condición `vsBroken` y la guarda por condición: `statBonus` de `guard` propio). Resumen del motor:

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

## Mecánicas de jefe (v0.2)

Telaraña, Campo Helado y Postura: docs/specs/bosses.md § "v0.2". Reglas
que tocan el combate general: `AttackCommand` con un aliado atrapado como
objetivo lo libera (medio turno); los enemigos `passive` (cristales) no
entran a la línea de tiempo y mueren con su jefe; `EnemyDef.armor` y la
postura multiplican el daño de los golpes primarios del grupo.


## Compañeros de la party (v0.8.1, solo_party.md § 4)

- Un compañero es un miembro más de `BattleState.party` (mismo motor,
  mismo escalado `0.55 + 0.45 × n`). En su turno sin AUTO la ventana de
  comandos dice `Turno de Leo (compañero)`; con AUTO la barra dice `Turno
  de Leo (AUTO)` y a los 0.5 s actúa `CompanionAi` (curar a quien esté
  bajo el 40 % con una habilidad de cura o una poción, ULT al 100 % al
  más débil, combos con Pulso y precondiciones desde v0.9, si no atacar
  al más débil; solo_party.md § 4.1). El tiempo de turno de la sala
  vale para cada turno.
- Su tarjeta del grupo muestra la ULT y el botón `AUTO: SÍ / NO`.

## Elemento de base del arma (v0.20.0)

weapon_identity.md § 6. Con arma de elemento, el **ataque básico** (y
Golpe Imparable) pega con ese elemento: entra en las debilidades y
resistencias de familia y en las reacciones (sus pilas sirven para una
Convergencia), y cada 2 básicos (`kWeaponElementHitsPerStack`) aplica 1
pila del estado del elemento al blanco. El contador es
`Combatant.basicHits` (snapshot `bh`). Las habilidades del mismo elemento
que el arma hacen ×1.08 (`kWeaponElementSynergy`, modificador
`arma <Elemento>` en el desglose); con otro elemento, sin penalidad.

## Revivir y el árbol (v0.21)

Toda habilidad con `revive > 0` (Eco de Regreso, Resurrección, Llama
Fénix y las ULT que reviven) suma la sinergia del lanzador
(`rules/revive_rules.dart`, `ReviveRules`):

- Vida al revivir: `min(100%, revive + ESP × espPer + Curación × healScale)`.
  ESP es el atributo del lanzador; Curación es `Combatant.healBonus`
  (nodos `heal` del árbol + `healPower` del arma).
- Velo del Retorno: si Curación > 0, el revivido recibe un escudo
  (`BuffStat.shield`, fuente `veloRetorno`, `ShieldEvent`) de
  `min(shieldCap, Curación × shieldScale) × su vida máx.` por
  `shieldTurns` turnos. Revivir otra vez lo reemplaza, no se apila.

Valores (Editor → Balance → Apoyo, `kTuning['consumables']`):
`espPer` 0.003 (+0.3% por ESP), `healScale` 0.5, `shieldScale` 1.0,
`shieldCap` 0.25, `shieldTurns` 2.

Ejemplos: Eco de Regreso (25%) con ESP 20 y sin Curación revive con 31%;
con ESP 40 y Curación 20%, 25 + 12 + 10 = 47% y escudo del 20%.
Llama Fénix (70%) con ESP 60 y Curación 20% llega a 98%.

Tooltip (`reviveLinesMarkup`, skill_text.dart): con el lanzador muestra el
% final con el desglose (base + ESP + Curación) y el escudo (o "sin
Curación del árbol no hay escudo"); sin lanzador, la regla con los
números vigentes. El log de batalla dice el % final y el escudo.

## Límites (v0.20.20)

Todos los números de esta sección son ajustes de Balance (Editor →
Balance → "Combate: límites", `TuningId.combatLimits`). El motor los lee
en cada paso; cambiar el parche cambia la pelea sin tocar código.

### Efectos encadenados

Auditoría (v0.20.19, antes de este cambio): no había bucles infinitos
posibles. Lo que ya los cortaba:

- Un paso del motor (una acción: comando de jugador, turno enemigo,
  turno de invocación) tiene un presupuesto de 64 efectos (`_spend`);
  cada disparo del árbol, de armas, mods, ascensión e invocaciones gasta
  1. Al llegar a 0 no se dispara nada más en ese paso.
- En una acción de jugador cada mecánica dispara una sola vez (por
  objetivo si su efecto va al objetivo): el registro `fired` de la acción.
- Rebote, explosión, eco arcano y ataque gratis se guardan en la acción y
  se resuelven una vez al final (`_resolveAction`); sus golpes no vuelven
  a guardar otro rebote. Cadena Infinita recorre cada enemigo una vez.
- Turno extra: una vez por turno (`extraTurn` 0 → 1 → 2).
- Lo que no tenía tope propio era la profundidad (un efecto que aplica un
  estado que dispara otro efecto que daña y dispara otro...): solo lo
  frenaba el presupuesto de 64.

Desde v0.20.20 el límite es explícito y editable:

| ajuste | valor | qué hace |
|---|---|---|
| `procMax` | 64 | efectos encadenados como máximo por acción |
| `procDepth` | 6 | pasos como máximo de una cadena (`_fire` dentro de `_fire`) |

Se muestra en la ayuda del árbol: "Los efectos encadenados tienen un
límite: como máximo N por acción". Tests: `combat_limits_test.dart`
(peor caso con todas las mecánicas y keystones, con el tope por defecto
y con el tope bajado a 5).

### Tope absoluto por golpe

Además del tope de combo_balance.md § 3.2 (que no vale con debilidad,
reacción o quiebre), cada golpe a un jefe o élite saca como máximo una
fracción de su vida máxima, siempre:

| ajuste | valor |
|---|---|
| `capBoss` | 0.35 |
| `capElite` | 0.60 |
| `capCommon` | 0 (sin tope) |

Otros ajustes de Límites de combate: `phaseHold` 0.5 (§ "Nadie solo en una
fase"), `wardMult` 0.5, `wardTurns` 3 y `tankGuard` 0.7 (§ "Tanques").

Vale para golpes, daño de efectos, reacciones, daño crudo y estados por
turno. La ficha del enemigo en combate lo dice: "No cae de un golpe: cada
golpe le saca como máximo el N% de su vida."

### Aguanta una ronda

Un común (ni jefe ni élite) aguanta el primer golpe letal de la ronda si
todavía queda algún jugador vivo, aparte del que actúa, sin actuar en la
ronda: queda en 1 de vida ("aguanta la ronda"). Una vez por enemigo y por
ronda; el remate también respeta la regla. `holdCoop` = 1 (con 2 o más
jugadores), `holdSolo` = 0.

Ronda: en `porBando` la de siempre; en `velocidad` termina cuando actuaron
todos los jugadores vivos (`state.acted` / `state.round` también se usan
en la línea de tiempo; la marca del enemigo es `!aguanta:<id>`).

### Nadie solo en una fase

Un solo personaje no puede tumbar a un enemigo (común, élite, jefe o
tanque: todos) dentro de su fase si el enemigo tenía al menos `phaseHold`
(0.5) de su vida máxima cuando esa fase empezó: el golpe letal lo deja en
1 ("{a} aguanta: {b} solo no lo puede tumbar en una fase"). Bajarlo de la
mitad está bien; el que lo remata tiene que ser otro personaje (o el
mismo en su fase siguiente).

- Fase de un personaje: en `porBando` / `porFases` / `porRonda`, su turno
  dentro de la fase de jugadores (o de la ronda); en `velocidad`, la ronda
  de § "Aguanta una ronda" (termina cuando actuaron todos los vivos).
- Se cuenta el daño que ese personaje ya le sacó en la fase
  (`Combatant.phaseDealt`, viaja como `phd`): vida al empezar la fase =
  vida actual + lo que le sacó. Cubre golpes, efectos, reacciones,
  remates y daño crudo del jugador que tiene el turno (no las
  invocaciones en su propio turno ni el daño por turno del enemigo).
- Vale en cooperativo y en solitario si queda otro aliado vivo
  (compañeros incluidos), aunque ya haya actuado (lo remata en la fase
  siguiente). Sin ningún otro aliado vivo no aplica: nada de peleas
  trabadas.
- `phaseHold` = 0 lo apaga (Balance → Límites de combate).

### Tanques

Los comunes pesados son tanques (`EnemyDef.tank`): Gólem, Elemental de
Escarcha, Caballero Caído, Guardián del Reloj y Gólem de Magma.

- Escudo elemental: resiste un elemento al que el tanque es débil. Elige,
  entre sus debilidades elementales de familia, la que más usa el grupo
  (tipos de daño de las habilidades de los jugadores vivos); empate: la
  debilidad más alta. Sin debilidades elementales no alza escudo (solo
  defiende). Mientras dura, ese elemento le pega × `wardMult` (0.5) y no
  cuenta como debilidad (no salta el tope sin debilidad ni da puntos de
  quiebre de debilidad).
- En su turno, si no tiene escudo, usa la acción en DEFENDER y alzarlo:
  recibe × `tankGuard` (0.7) hasta su próximo turno y el escudo dura
  `wardTurns` (3) turnos propios. Si tiene escudo, ataca normal.
- Al empezar la pelea, si el tanque no actúa primero (el grupo abre la
  pelea: `porBando`, golpe primero en la línea de tiempo, o algún jugador
  antes que él en `porRonda`), ya trae el escudo puesto (`wardTurns`
  turnos). En `porFases` abre la fase enemiga, así que no. Se calcula con
  el estado ya armado (`BattleEngine.applyOpeningWards`), así sirve con
  cualquier regla de iniciativa.
- El escudo se ve como chip "ESCUDO <elemento>" con tooltip (cuánto
  resiste y turnos que quedan) y en el log (sube, ya lo trae, cae). La
  ficha del enemigo dice que es tanque.
- Viaja en el estado de batalla (`wrd` = [elemento, turnos]); protocolo
  Mundo 63.

### Velocidad

- Rendimiento decreciente: la velocidad efectiva que pasa de
  `speedSoftCap` (16) rinde × `speedSoftFactor` (0.5).
  `interval = 100 / softSpeed(VEL × buffs × congelación)`.
- Tope de turnos: el intervalo de un combatiente nunca es menor que el
  del aliado vivo más lento de su bando / `turnsPerSlowest` (2). Bando:
  grupo + invocaciones, o enemigos (sin los pasivos). 0 = sin tope.
  Lo aplica el paso (`cappedInterval`); `interval` solo es la curva.

### Carga de ULT extra

Auditoría de fuentes (máximo por disparo, catálogo v0.20.19):

| fuente | máximo |
|---|---|
| ATACAR / habilidad (daño hecho) | `dealtCap` 22 + la ganancia de la habilidad |
| Defender / golpe defendiendo | 6 / 6 |
| daño recibido | 110 × fracción de vida perdida |
| árbol / ascensión: `ultCharge` | 20 (árbol), 15 (ascensión) |
| árbol: `ultChargeParty` | 10 a cada aliado |
| pasivas de arma (crítico, matar, aliados) | según la tirada del arma |
| `% carga de ULT` (árbol `ult`, afijos, implícitos 8-12%, objetos 25%, mejora de la Travesía 20) | multiplica toda la carga |
| mod de invocación `invokeUlt` | por invocación |
| combo entre jugadores | `combo.ultBonus` (regla de combos, sin tope) |

Lo que sumaba el caso reportado (Instante con +60% y otra acción en el
mismo turno) era la parte extra: el multiplicador `% carga de ULT` y los
disparos. Desde v0.20.20 la carga extra (la parte del multiplicador sobre
1, los `ultCharge` / `ultChargeParty`, las pasivas de arma y la de
invocación) pasa por `_bonusUlt`, con tope:

| ajuste | valor |
|---|---|
| `ultBonusAction` | 50 por acción |
| `ultBonusTurn` | 50 por turno de quien la recibe (`Combatant.ultBonusTurn`, vuelve a 0 al empezar su turno) |

La carga base (golpes, Defender, daño recibido, ganancia de la
habilidad) no tiene tope. La ayuda de ULT lo dice: "Las cargas extra de
ULT tienen un tope de 50% por turno."
