# Spec: Ascensión y Prueba del Tiempo (v0.5.0)

Entrega de endgame.md § 4 (Ascensión), § 8 ("la ascensión tiene que
**sentirse**") y las reglas de § 7 que le tocan. Decisión del dueño:
"sí, pero que se sienta eso". Fuera de esta versión: Jefes del Abismo,
Fragmentos, Grietas del Atlas y Temporadas.

Código: `lib/game_engine/models/ascension.dart` (modelo y progreso),
`data/ascension_catalog.dart` (8 ascensiones, 64 nodos, kit),
`data/ascension_mechanics.dart` (mecánicas de los nodos),
`rules/ascension_rules.dart` (elegir, tomar, reiniciar),
`rules/trial_rules.dart` (Pruebas, mazmorra con trampas, recompensas),
`rules/battle_engine.dart` (efectos nuevos), `rules/session_engine.dart`
(flujo en la sala). UI: `lib/features/ascension/`.

## 1. La Prueba del Tiempo

En el pueblo hay una **Estatua del Tiempo** (tile `Tile.statue`, `'S'`,
sólido) en x 20–22, y 10 (debajo de la fuente derecha). Frente a ella
(`WorldRules.nearStatue`: `10.6 < y < 12.9 tiles`, `19.5 < x < 23.5
tiles`): `[E] Estatua del Tiempo` abre el panel **ASCENSIÓN** (pestañas
PRUEBAS y ASCENSIÓN).

| # | Nombre | Nivel pedido | Requisito | Mazmorra (generador de) | Monstruos | Pisos | Jefe | Púas / piso | Pulsos / piso | Daño de púas |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Prueba I · El Umbral | 30 | — | Laberinto Temporal (z6) | nivel 32 | 2 | Gólem Reloj | 6 | 4 | 8% |
| 2 | Prueba II · La Encrucijada | 40 | Prueba I | Fortaleza Caída (z5) | nivel 42 | 2 | Caballero Hueco | 8 | 6 | 10% |
| 3 | Prueba III · El Juicio | 50 | Prueba II | Corazón del Tiempo (z10) | nivel 52 | 3 | Hechicera del Eco | 10 | 8 | 12% |

- Proponer: `ProposeTrialAction(n)` en el pueblo (modo lobby, sin otra
  votación). Lo puede proponer quien cumple el nivel y el requisito.
  Votación y preparación como cualquier misión (`MissionVote` con
  `missionId = 'trial'`, número en `GameSession.trial`, JSON `trial`).
- Se puede repetir: la primera vez da los puntos, después solo loot.
- Mazmorra: `MapGenerator.zone` del `ZoneDef` sintético de la Prueba
  (generador y tema de su zona, los pisos de la tabla) con la semilla de
  la misión, y después las trampas (§ 1.1). Grupos: los del último piso
  de la misión de esa zona; jefe: el grupo del jefe de la misión de su
  zona. 4 grupos por piso. Sin objetivos extra. Rango por tiempo con
  `sTime = 300 × pisos`.
- **Completar** = vencer al jefe → `TrialCompletedEvent(n, ganadores)`.

### 1.1 Trampas

Tiles nuevos, caminables (para el motor son suelo; para la IA de los
enemigos también: no los afectan).

- **Púas** (`Tile.spikes`, `'x'`): parches de 2 × 2. Quien las pisa
  pierde el % de su vida máx. de la tabla, **una vez por segundo**
  mientras siga encima. No matan: dejan en 1 HP como mínimo.
  `TrapTriggeredEvent(id, spikes, daño)`.
- **Pulso del Tiempo** (`Tile.pulse`, `'p'`): parches de 3 × 3. Ciclo de
  3 s del reloj de la sala: 2 s cargando (se ve cómo crece), 1 s
  **activo** (`time % 3 ≥ 2`). Quien está encima cuando está activo
  **vuelve al inicio del piso** (como caer al vacío, sin daño) y se le
  dice `X fue devuelto por un Pulso del Tiempo`.
  `TrapTriggeredEvent(id, pulse, 0)`.
- Ubicación (`TrialRules.withTraps`): azar propio `mulberry32(semilla ^
  (0x7A11 + 131 × piso))`, sobre tiles `spots` del piso que sean suelo
  (`.`/`,`) a más de 7 tiles del spawn, más de 4 de las escaleras y fuera
  de la arena del jefe (con 2 de margen); los parches no se tocan (4
  tiles entre centros). Hasta 200 intentos por trampa.

### 1.2 Recompensa y co-op

- Cada jugador presente al vencer al jefe que todavía no tenía esa
  Prueba, con el nivel pedido y la Prueba anterior hecha, gana **2 puntos
  de ascensión** (en su perfil). Los demás acompañan (loot normal). Así
  en grupo **cada uno gana sus propios puntos**; solo es igual de
  jugable (el escalado de siempre baja vida y quiebre).
- Puntos: 2 por Prueba → **6 máximo**. Con la primera Prueba se
  desbloquea la elección de ascensión.
- Aviso: `<nombre> superó la Prueba del Tiempo I: +2 puntos de
  ascensión`. Si todavía no eligió: `Elegí tu ascensión en la Estatua
  del Tiempo`. El resultado muestra el botón **ELEGIR ASCENSIÓN**.

## 2. Elegir la ascensión

- Cada clase elige **1 de 2** (ids fijos, contrato con el arte):

| Clase | A | B |
|---|---|---|
| Guerrero | `berserker` Berserker | `senorGuerra` Señor de la Guerra |
| Maga | `cronomante` Cronomante | `elementalista` Elementalista |
| Tirador | `francotirador` Francotirador | `trampero` Trampero |
| Paladín | `templario` Templario | `guardian` Guardián |

- `ChooseAscensionAction(id)`: con la Prueba I hecha, de su clase, sin
  ascensión elegida; en lobby, preparación o resultado. Da gratis el
  **nodo raíz** (su mecánica de identidad) y el **kit**: 2 habilidades
  propias (el Guardián: 3, el kit clásico del Paladín mejorado, § 4) +
  su ULT (reemplaza la ULT del arma).
- Evento `AscensionChosenEvent(id, ascensión)` → cinemática (§ 5) para
  todos los de la sala, aviso `¡<nombre> ascendió: <Ascensión>!`.
- **Reinicio (regla temporal del dueño: reiniciar es gratis siempre)**:
  - `ResetAscensionAction()`: devuelve todos los puntos de los nodos
    (la raíz y el kit quedan). Como el árbol de pasivas: en cualquier
    modo salvo batalla (`ProgressionRules.canRespec`).
  - `ResetAscensionAction(full: true)`: además **saca la ascensión**
    (vuelve la clase base: sprite, ULT y kit). Solo en el pueblo
    (lobby / preparación). Volver a elegir repite la cinemática.
  - Cambiar de clase saca la ascensión (las Pruebas hechas se quedan).
- JSON del perfil (opcional, perfiles v0.4 cargan sin ascensión):
  `asc: {tr: [1,2], id: 'cronomante', n: ['cronomante_a1', ...]}`.
  `ProgressionRules.normalize` descarta lo inválido (Pruebas fuera de
  1–3 o sin la anterior, ascensión de otra clase o sin la Prueba I,
  nodos que no se podrían tomar en orden).

## 3. Mini-árbol (8 nodos por ascensión)

Forma (igual en las 8; x, y en celdas del lienzo):

```
           R (0,0)  raíz, gratis al elegir
      A1 (-1,1)       B1 (1,1)     costo 1
      A2 (-1,2)       B2 (1,2)     costo 1
      A3 (-1,3)       B3 (1,3)     costo 2 (mayor)
              K (0,4)              costo 2, se une a A3 y a B3
```

Costo total 10, puntos 6: se elige (una rama entera + la final, una rama
+ media otra, ...). Un nodo se toma si hay puntos libres y está unido a
uno tomado. Ids: `<asc>_r`, `_a1`, `_a2`, `_a3`, `_b1`, `_b2`, `_b3`,
`_k`. Cada nodo es una **mecánica** de datos (`PassiveMechanic`, mismo
sistema de disparadores de passive_tree_v2.md § 5) salvo `Sobrecarga`
(stats).

### Guerrero · Berserker (vida baja = más daño, robo de vida)

| Nodo | Nombre | Efecto |
|---|---|---|
| r | Sed Roja | Con menos de 50% de vida, cada acción que golpea hace que tu próximo turno llegue **50% antes** (turno parcial). |
| a1 | Furia Creciente | +0.8% de daño por cada 1% de vida que te falta (con 10% de vida: +72%). |
| a2 | Golpe Desesperado | Con menos de 30% de vida **todos tus golpes son críticos**. |
| a3 | Carnicero | Al matar: **turno extra inmediato** (uno por acción; un turno extra no da otro). |
| b1 | Sangre por Sangre | Con menos de 50% de vida robás 30% del daño que hacés. |
| b2 | Cicatrices | Al recibir un golpe con menos de 50% de vida: escudo del 12% de tu vida máx. (1 turno). |
| b3 | Inmortal | El primer golpe que te dejaría en 0 te deja en **1 HP** (1 vez por batalla). |
| k | Berserker Desatado | Con menos de 50% de vida, cada acción que golpea da +15 de carga de ULT. |

### Guerrero · Señor de la Guerra (gritos que buffean al grupo)

| Nodo | Nombre | Efecto |
|---|---|---|
| r | Voz de Mando | Tus gritos (habilidades de grupo y tu ULT) **adelantan a cada aliado 25%** de su espera (solo: tu propio próximo turno). |
| a1 | Eco del Grito | Tus buffs de grupo duran +1 turno. |
| a2 | Inspiración | Al empezar tu turno, cada aliado (no vos) gana +6 de carga de ULT. |
| a3 | Estratega | Cuando **cualquier aliado quiebra** a un enemigo: +20% ATQ a todo el grupo (2 turnos). |
| b1 | Bandera Firme | Mientras estés en pie, **todo el grupo recibe −10% de daño**. |
| b2 | Muralla de Voces | Tus gritos dan a cada aliado un escudo del 8% de tu vida máx. (2 turnos). |
| b3 | Último Bastión | Cuando cae un aliado: el resto gana +30% ATQ y −20% de daño recibido (3 turnos). |
| k | Señor de la Guerra | Tus buffs de grupo son **50% más fuertes**. |

### Maga · Cronomante (manipula el timeline)

| Nodo | Nombre | Efecto |
|---|---|---|
| r | Bucle Temporal | Tus habilidades que **retrasan** también **adelantan al aliado más lento** 30% de su espera (solo: tu próximo turno). |
| a1 | Ecos del Reloj | Tus retrasos son 50% más largos. |
| a2 | Ancla del Tiempo | Al retrasar a un enemigo con ULT, pierde 20 de carga (si ya la avisó, no). |
| a3 | Tiempo Robado | Al retrasar: tu próximo turno llega 35% antes. |
| b1 | Sincronía | Al empezar tu turno, el aliado más lento se adelanta 15%. |
| b2 | Contratiempo | Al recibir un golpe, el atacante se retrasa 30%. |
| b3 | Instante Eterno | Al usar tu ULT, **todos los aliados actúan ya** (pasan al frente del timeline; solo: tu próximo turno llega 50% antes). |
| k | Desfase | Los enemigos que retrasás reciben +20% de daño de todos (2 turnos). |

### Maga · Elementalista (combos Quemadura / Congelación / Veneno)

| Nodo | Nombre | Efecto |
|---|---|---|
| r | Reacción Elemental | +30% de daño contra enemigos con **2 o más** estados elementales distintos. |
| a1 | Contagio Elemental | Al aplicar Quemadura, Congelación o Veneno, el objetivo recibe además 1 stack del primero que no tiene (Quemadura → Congelación → Veneno). |
| a2 | Sobrecarga | +1 stack a toda Quemadura, Congelación y Veneno que aplicás. |
| a3 | Detonación | Al morir un enemigo con estados elementales, la mitad (redondeo arriba) de cada uno **pasa a cada enemigo vivo**. |
| b1 | Estallido Glacial | Golpear a un enemigo con 3+ Congelación lo hace estallar: 60% del golpe a cada otro enemigo. |
| b2 | Fiebre | +25% de crítico contra enemigos con Quemadura. |
| b3 | Eco Elemental | 35% de que una habilidad mágica (no ULT) se repita gratis al 60%. |
| k | Tormenta Perfecta | Contra enemigos con **los 3** estados: +50% de daño y +25% de crítico. |

### Tirador · Francotirador (críticos enormes a un objetivo)

| Nodo | Nombre | Efecto |
|---|---|---|
| r | Un Disparo, Una Baja | En acciones a un solo objetivo tus críticos hacen **+0.75 de multiplicador**. |
| a1 | Marca Letal | Tu golpe a un solo objetivo lo marca: +15% de daño recibido (3 turnos). |
| a2 | Tiro Seguro | +40% de crítico contra enemigos marcados. |
| a3 | Ejecución | Tus golpes a un solo objetivo **rematan** a enemigos (no jefes ni élites) que queden con menos de 20% de vida. |
| b1 | Recarga | Al hacer crítico: +15 de carga de ULT. |
| b2 | Concentración | Al hacer crítico a un solo objetivo: tu próximo turno llega 30% antes. |
| b3 | Disparo Perforante | Al hacer crítico a un solo objetivo: el disparo atraviesa al siguiente enemigo con el 75% del daño. |
| k | Leyenda del Gatillo | Al hacer crítico: +0.5 de multiplicador de crítico (2 turnos, renueva). |

### Tirador · Trampero (trampas y daño en área)

Una **trampa** es un efecto con duración sobre un enemigo (`BuffStat.trap`,
valor = daño): salta **al empezar el turno del enemigo** (daño
secundario del dueño, `DamageEvent.sourceId` = la mecánica) mientras le
queden turnos (base 1: salta una vez). Trampas de orígenes distintos no
se pisan; la del mismo origen se renueva. Daño = `ATQ del dueño × poder
× (1 + Cazador Supremo)`.

| Nodo | Nombre | Efecto |
|---|---|---|
| r | Maestro de Trampas | Tus golpes a un solo objetivo le dejan una trampa de ATQ × 0.6. |
| a1 | Púas Envenenadas | Tus trampas aplican 2 Veneno al saltar. |
| a2 | Trampa Persistente | Tus trampas saltan 1 turno más (+1 turno). |
| a3 | Detonador | Al saltar una trampa, explota: 50% de su daño a cada otro enemigo. |
| b1 | Lluvia Constante | Tus habilidades a todos (no ULT) hacen +25% de daño. |
| b2 | Fragmentación | Tus habilidades a todos aplican 1 Veneno a cada golpeado. |
| b3 | Campo de Muerte | Tus habilidades a todos dejan una trampa de ATQ × 0.4 en cada golpeado. |
| k | Cazador Supremo | Tus trampas hacen +80% de daño. |

### Paladín · Templario (daño sagrado y aturdir)

| Nodo | Nombre | Efecto |
|---|---|---|
| r | Martillo de la Fe | Al aturdir a un enemigo: daño sagrado MAG × 0.8 y +1 Sagrado. |
| a1 | Condena | +35% de daño a enemigos aturdidos. |
| a2 | Fervor | Al aturdir: +12 de carga de ULT. |
| a3 | Sentencia | Tus golpes a aturdidos llenan la barra de **quiebre al doble**. |
| b1 | Aura Sagrada | Mientras estés en pie, **todo el grupo hace +10% de daño**. |
| b2 | Penitencia | Al recibir un golpe, el atacante recibe 2 Sagrado. |
| b3 | Ira Divina | Mientras estés en pie, el Sagrado de los enemigos hace el doble por turno. |
| k | Avatar de Luz | Al usar tu ULT: el grupo se cura 20% y gana un escudo del 10% de tu vida máx. (3 turnos). |

### Paladín · Guardián (escudos y protección del grupo)

| Nodo | Nombre | Efecto |
|---|---|---|
| r | Escudo Viviente | Al empezar tu turno, el aliado con menor % de vida (vos incluido) gana un escudo del 10% de tu vida máx. (2 turnos). |
| a1 | Égida Reflectante | Cuando un escudo tuyo absorbe un golpe, el atacante recibe el 50% de lo absorbido. |
| a2 | Escudos Duraderos | Tus escudos son 30% más grandes. |
| a3 | Bastión Inquebrantable | Mientras estés en pie, **todo el grupo recibe −15% de daño**. |
| b1 | Represalia del Guardián | Al recibir un golpe dirigido a un aliado (Protección): devolvés el 60%. |
| b2 | Muralla Viviente | Al empezar tu turno, todo el grupo gana un escudo del 6% de tu vida máx. (1 turno). |
| b3 | Mártir | El primer aliado (o vos) que caería por un golpe queda en **1 HP** (1 vez por batalla por Guardián). |
| k | Juramento Eterno | Mientras estés en pie, **recibís el 25% del daño** que reciben tus aliados (tus escudos lo absorben). |

### 3.1 Reglas del motor (además de passive_tree_v2.md § 5)

- Disparadores nuevos: `onDelayApplied` (un golpe primario tuyo retrasó a
  un enemigo), `onUltimate`, `onBreak` (cualquier aliado quiebra a un
  enemigo; la mecánica la tiene el dueño, vivo), `onAllyDown`, `onTrap`;
  condiciones `partyAura` (vale para todo el grupo mientras el dueño esté
  en pie), `whileMissingHealth` (escala con la vida que falta) y
  `vsElements` (cantidad de estados elementales distintos ≥ `minStacks`).
- Filtros nuevos: `belowThreshold` (vida del dueño < `threshold`) y
  `rallySkill` (habilidad o ULT con efecto de grupo). Las condiciones
  ahora también respetan su filtro.
- Efectos nuevos: `buffParty`, `shieldParty` (escudo = % de la vida máx.
  del dueño), `shieldLowestAlly`, `healParty`, `advanceAlly` (el aliado
  vivo con el próximo turno más lejano, sin el dueño), `advanceParty`
  (todos los aliados menos el dueño; `nextTurn = max(reloj + 0.01,
  nextTurn − IV × valor)`; sin aliados, el dueño: `turnFactor` con tope
  0.5), `ultChargeParty`, `drainUlt`, `execute`, `plantTrap`, `burst`,
  `spreadAll`, `addElement`, `cheatDeath`.
- Stats nuevos (`BuffStat`): `lifeSteal`, `guard` (daño recibido −;
  tope 60% sumado), `critMulti`, `delayPower`, `buffPower`, `buffTurns`,
  `trapPower`, `trapTurns`, `shieldPower`, `shieldReflect`, `holyPower`,
  `shareDamage`, `trap`.
- Una vez por batalla: `Combatant.once` (ids ya usados; JSON `once`).
- Todo lo nuevo es secundario según la regla 1 (no dispara otras cosas),
  salvo los golpes primarios de las habilidades del kit.

## 4. Kit (habilidades y ULT)

Habilidades nuevas de `SkillDef` (opcionales, por defecto apagadas):
`hpCost` (fracción de la vida máx.; no baja de 1), `lifeSteal` (fracción
del daño de la acción), `extraStatuses`, `detonate` (+% por stack
elemental del objetivo; los consume), `execute`, `trap` (poder de la
trampa), `partyBuff` (stat, valor, turnos; a todos los aliados vivos,
vos incluido), `partyShield` (% de tu vida máx. a cada aliado, turnos en
`partyShieldTurns`), `advanceAllies`, `selfBuff`, `selfTurn` (factor de
tu próximo turno), `protect` (Protección). `SkillKind.support`: sin daño.

| Ascensión | Habilidad 1 | Habilidad 2 | ULT |
|---|---|---|---|
| Berserker | **Sangría** (`sangria`, 3 MP): físico 2.4, cuesta 10% de vida | **Torbellino Rojo** (`torbellino`, 6 MP): físico a todos 1.2, roba 30% | **Frenesí Carmesí** (`ult_berserker`): físico 3.6, +30% crít, roba 50% |
| Señor de la Guerra | **Grito de Guerra** (`gritoGuerra`, 5 MP): grupo +25% ATQ 3 turnos | **Estandarte** (`estandarte`, 6 MP): grupo −25% daño recibido 2 turnos | **Llamado a las Armas** (`ult_senorGuerra`): físico a todos 1.6, grupo +30% ATQ 3 turnos, adelanta aliados 30% |
| Cronomante | **Acelerón** (`aceleron`, 6 MP): adelanta a los aliados 40% (solo: a vos) | **Grieta Temporal** (`grietaTemporal`, 5 MP): mágico 1.5, retrasa 0.8 | **Detener el Tiempo** (`ult_cronomante`): mágico a todos 1.4, retrasa 1.2, adelanta aliados 50% |
| Elementalista | **Prisma Elemental** (`prismaElemental`, 4 MP): mágico 1.4, +1 Quemadura +1 Congelación +1 Veneno | **Detonar** (`detonar`, 6 MP): mágico 1.2, +30% por stack elemental del objetivo y los consume | **Trinidad** (`ult_elementalista`): mágico a todos 1.7, +2 de cada elemento |
| Francotirador | **Tiro a la Cabeza** (`tiroCabeza`, 6 MP): físico 2.4, +35% crít, remata < 25% | **Apuntar** (`apuntar`, 3 MP): +100% crít 1 turno y tu turno llega 50% antes | **Bala del Juicio** (`ult_francotirador`): físico 4.5, crítico seguro, remata < 30% |
| Trampero | **Trampa de Púas** (`trampaPuas`, 4 MP): trampa ATQ × 1.0 a todos | **Red de Caza** (`redCaza`, 4 MP): físico 1.1, retrasa 0.5, 2 Veneno | **Campo Minado** (`ult_trampero`): físico a todos 1.5 y trampa ATQ × 0.8 a todos |
| Templario | **Castigo Sagrado** (`castigo`, 4 MP): mágico 1.6, 35% aturdir, +1 Sagrado | **Luz Cegadora** (`luzCegadora`, 7 MP): mágico a todos 0.9, 25% aturdir | **Juicio Final** (`ult_templario`): mágico a todos 2.0, aturde, +1 Sagrado |
| Guardián | **Protección** (`proteccion`, 5 MP): Protección hasta tu próximo turno y −20% de daño recibido propio (1 turno) · **Fortaleza** (`fortaleza`, 6 MP): DEF +2 propia (tope 12), escudo 15% de tu vida máx. a todos (3 turnos) y grupo −10% daño (2 turnos) | **Aura Restauradora** (`aura`, 6 MP): cura `MAG × 1.0 + 4` a cada aliado + Regeneración 3 | **Fortaleza Inquebrantable** (`ult_guardian`): escudo 25% a todos, −25% daño 3 turnos y Protección |

**Kit clásico del Paladín → Guardián (v0.5).** Hasta v0.4 el Paladín
tenía un kit de clase fijo (Aura Restauradora, Fortaleza, Protección)
que no se podía quitar ni buildear. Desde v0.5 el Paladín base juega
como las demás clases (habilidades del arma + árbol + ascensión) y ese
kit pasa, mejorado, al **Guardián** (3 habilidades en vez de 2):

| Habilidad | Antes (clase Paladín) | Ahora (kit del Guardián) |
|---|---|---|
| Protección | 5 MP: Protección | 5 MP: Protección + `selfBuff` −20% daño recibido (1 turno) |
| Fortaleza | 3 MP: DEF +2 propia | 6 MP: DEF +2 propia + escudo 15% de tu vida máx. a todos (3 turnos) + grupo −10% daño (2 turnos) — absorbe a la vieja **Égida Grupal** |
| Aura Restauradora | 6 MP: `MAG × 0.6 + 4` + Regeneración | 6 MP: `MAG × 1.0 + 4` + Regeneración |

Los ids (`proteccion`, `fortaleza`, `aura`) no cambian: viven ahora en
`kAscensionSkills`. **Égida Grupal** (`egidaGrupal`) se fusionó en
Fortaleza y **Juramento** (`juramento`, Protección + grupo −30%) se
quitó: era redundante con Protección, la ULT y el nodo Juramento Eterno.
Ningún perfil los guarda (el kit sale de la ascensión, no del perfil) y
una habilidad trasladada nunca puede ser del kit de una ascensión
(`ItemRules.sanitize` la descarta). Los rasgos de clase del Paladín
(DEF base 6, VIT 15, 3% de aturdir al atacar, débil a perforante ×1.5 y
a estados +1) no cambian.

Las ULT de ascensión usan el guion y los colores de `kUltScripts` con su
propio id (reusan un estilo visual y lo tiñen) y tienen sonido propio.

## 5. Que se sienta (endgame.md § 8)

- **Cinemática** al elegir (`AscensionCinematic`, 5.2 s, se salta con un
  clic / Esc / Enter después de 1 s): 0–0.4 s la pantalla se congela
  (oscurece y bajan las barras de cine); 0.4–2.2 s el personaje en
  grande, la luz de su ascensión converge en él (partículas, columna de
  luz, sacudida que crece); 2.2–2.5 s destello blanco y **cambia el
  sprite** al ascendido; 2.5–4.6 s cartel `ASCENSIÓN` / nombre en el
  color de la ascensión / `<nombre> · <clase>` / su lema; 4.6–5.2 s se
  desvanece. Sonido propio (`asc.build` a los 0.4 s, `asc.reveal` en el
  destello) y jingle `jingle.ascension` (Re menor → Re mayor, 104 bpm,
  ≈ 6.9 s) cuando cualquiera de la sala asciende. Si no hay sprite
  ascendido, en la revelación se ve el de la clase teñido del color.
- **Cambio visual permanente**: sprite `<clase>_<ascensión>` del
  `SpriteCatalog` (p. ej. `maga_cronomante`, `GameSprites.heroFor`); si
  el manifest no lo tiene (o el archivo falla al cargar), el de la clase
  base: nunca rompe. El arma se dibuja con la clase base.
  **Aura** en batalla, en el mapa y en las fichas: el sprite
  `aura_<ascensión>` (24 × 26 en (−12, −25) desde los pies, alfa `0.65 +
  0.25 · sin(t / 220)`, espejada con el héroe, oculta si está caído;
  docs/specs/sprites.md § "Ascensiones"); sin sprite, un anillo pintado
  del color de la ascensión con motas que suben.
- **Título** en el HUD, el chat, los paneles de grupo (mapa y batalla) y
  las tarjetas del título: `Ana, Cronomante`.

### 5.1 Panel de la Estatua (presentación v0.5)

Lista + detalle (ui_style.md § "Menús: lista + detalle"). Líneas cortas:
`Mazmorras con trampas y jefe: cada una da 2 puntos de ascensión.` /
`Elegí 1 de 2 subclases y gastá los puntos en su mini-árbol (gratis
cambiar).`

- **PRUEBAS**: filas de una línea (`trial-row-<n>`): `Prueba I · El
  Umbral` y a la derecha `Superada` (verde) o `Nv 30` (dorado si se
  puede proponer, `dim` si no). Ficha corta (`trial-detail`): nombre y
  estado; `Nivel N · requiere la Prueba X`; mazmorra, pisos y nivel;
  `Jefe:`; `Trampas por piso: N púas (−P% de vida/s) · M Pulsos (te
  devuelven al inicio)`; `Premio: +2 puntos de ascensión` (y `elegir
  subclase` en la I). Abajo `PROPONER` (`trial-propose`) con el motivo.
- **ASCENSIÓN sin elegir**: las 2 tarjetas lado a lado (comparar es la
  decisión); el héroe a la izquierda de la ficha (no arriba) para que el
  kit entre; `ELEGIR <NOMBRE>` abajo.
- **Mini-árbol**: el lateral crece con el texto (hasta 45 % de la
  pantalla); primero el nodo elegido (`asc-node-detail`), después
  `Puntos libres · ganados`, el héroe con el nombre y, en la raíz, el
  kit. Abajo `REINICIAR` · `CAMBIAR` (gratis, lo dice la línea) ·
  `TOMAR` (con el motivo).

## 6. Red

- Protocolo `kProtocolVersion` 5. Acciones `trial`, `ascChoose`,
  `ascNode`, `ascReset`, `devTrial`; eventos `trialDone`, `ascChosen`,
  `trap`; sesión `trial`; perfil `asc`; build del combatiente `asc`;
  combatiente `once`. Todo opcional al leer: un perfil v0.4 carga sin
  ascensión.

## 7. Desarrollo (solo `main_dev`)

`DevGrantTrialAction(n)` (motor con `devTools`): marca las Pruebas 1..n
como hechas y sube al jugador al nivel de la Prueba n si le faltaba
(con sus puntos de atributo y árbol). El panel ASCENSIÓN muestra
`DEV: PRUEBA I / II / III`. En `main_p2p` / `main_lan` el motor la
rechaza.
