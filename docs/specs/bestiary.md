# Spec: Familias de enemigos y Bestiario (v0.6)

Pedido del dueño (backlog_v0.6.md § 4): "builds tipo D&D". Cada enemigo
pertenece a una **familia** con debilidades, resistencias e inmunidades
que cambian cómo conviene pelearle (la más pedida: **las curas dañan a
los no muertos**, así una build "full curas" también pega). La ficha de
un enemigo solo se ve **después de matarlo una vez**; las fichas viven en
el **Bestiario**, una pestaña de información de la cuenta.

Código:

- Datos: `lib/game_engine/data/enemy_families.dart` (`EnemyFamily`,
  `DamageTag`, `FamilyRule`, `kFamilyRules`, `kEnemyFamily`,
  `kHolySkillIds`).
- Reglas puras: `lib/game_engine/rules/family_rules.dart` (`familyOf`,
  `familyRuleOf`, `isFamily`, `skillDamageTags`, `familyFactors`,
  `familyStacks`, `familyTraits`).
- Motor: `lib/game_engine/rules/battle_engine.dart` (lee la tabla; no
  conoce familias concretas). `BattleEngine(familiesEnabled: false)` las
  apaga (tests de otras fórmulas).
- Bestiario: `lib/game_engine/models/bestiary.dart` (`BestiaryProgress`,
  `BestiaryStore`), cuenta en `features/characters` (JSON `best`), UI en
  `lib/features/bestiary/`.

## 1. Familias

### 1.1 Tabla

Factores de daño: multiplican el golpe del grupo (`> 1` débil, `< 1`
resiste). "+1 stack" = cuando el grupo le aplica ese estado entra uno
más (mín. 1 con los negativos).

| Familia (sigla) | Enemigos | Débil | Resiste | Inmune | Especial |
|---|---|---|---|---|---|
| No muerto (NM) | Esqueleto, Caballero Caído, **Caballero Hueco**, Necrófago | Sagrado ×1.5, fuego ×1.25 | — | Veneno | **Las curas lo dañan** (100% de la cura); estado Sagrado ×2 |
| Espectro (ES) | Espectro, Alma Errante, **Espectro Coronado**, Siervo Espectral | mágico ×1.25, Sagrado ×1.25 | físico ×0.7 | Veneno | Las curas lo dañan al 50%; estado Sagrado ×1.5 |
| Bestia (BE) | Murciélago, Lobo, Murciélago de Hielo | fuego ×1.25, Quemadura +1 stack, Marca ×1.5 | — | — | — |
| Arácnido (AR) | Araña, **Matriarca Araña** | fuego ×1.5, Quemadura +1 stack | — | Veneno | — |
| Cieno (CI) | Limo, **Rey Limo** | fuego ×1.25 | — | — | — |
| Constructo (CO) | Gólem, **Gólem Reloj**, Guardián del Reloj | quiebre ×1.5 | mágico ×0.8 | Veneno | — |
| Elemental ígneo (IG) | Salamandra, Gólem de Magma, **Bestia de Magma** | hielo ×1.5, Congelación +1 stack | fuego ×0.5 | Quemadura | — |
| Elemental de escarcha (HE) | Elemental de Escarcha, **Sierpe de Escarcha**, Cristal de Hielo | fuego ×1.5, Quemadura +1 stack | hielo ×0.5 | Congelación | — |
| Temporal (TE) | Eco Sombrío, **Hechicera del Eco**, Eco de la Hechicera, Fragmento del Tiempo, Heraldo de las Eras, **Devorador de Eras** | hielo ×1.25, Congelación +1 stack, retrasos ×1.5 | Veneno −1 stack | — | — |
| Aberración del Vacío (VA) | Vigilante del Vacío, Ojo del Abismo, **Centinela del Vacío** | físico ×1.2, Sagrado ×1.5 | mágico ×0.75 | — | — |

(En negrita, los jefes.) La ficha muestra solo datos de juego: cada
rasgo con su factor numérico (`Sagrado ×1.5`, `Veneno +1 stack`) y, para
las curas, la explicación mecánica (`las curas le hacen daño (100% de la
cura)`). **Sin historia ni ambientación** (regla del dueño, v0.6): no
hay motivos poéticos, títulos de jefe ni descripciones inventadas.
Todo enemigo del catálogo tiene
familia (test). La familia es del tipo: el élite y la fase 2 del
Devorador la conservan.

Builds que habilita: curas / sagrado contra la Fortaleza y el Cementerio
(zonas 5 y 8, donde el veneno no sirve), fuego contra el Bosque, hielo
contra la Grieta Ígnea, retrasos / congelación contra el Laberinto y el
Corazón, físico o sagrado contra el Abismo, quiebre contra los gólems.

### 1.2 Tipos de daño de un golpe (`skillDamageTags`)

- Ataque normal (y cualquier golpe sin habilidad): **físico**.
- `SkillKind.physical` → físico; `SkillKind.magical` → mágico; curas y
  regeneraciones → **Sagrado** (la Luz del creyente).
- Elementos, por el estado que aplica la habilidad (`status` y
  `extraStatuses`): Quemadura → **fuego**, Congelación → **hielo**,
  Sagrado → **Sagrado**. Además son Sagradas las de `kHolySkillIds`
  (Golpe Sagrado, Lanza de Luz, Consagrar, Martillo del Juicio, Castigo
  Sagrado, Luz Cegadora, Sello Sagrado, Juicio Divino, Martillo
  Celestial). No hacen falta tags nuevos en `SkillDef`.
- v0.7: también el elemento de la habilidad (`elementOf`): Agua →
  **agua**, Electro → **electro** (y fuego / hielo / Sagrado). Los
  golpes enemigos a un jugador con raza: físico + su elemento.
- v0.7: **Constructo** débil a electro ×1.25; **Elemental ígneo** débil a
  agua ×1.5. Las familias valen igual para los jugadores
  (`Combatant.family`; razas más adelante, elemental_reactions.md § 5.4).

### 1.3 Factor de daño (`familyFactors`)

Factor = (factor del tipo físico / mágico) × (la **mayor** debilidad de
los elementos del golpe) × (la **mayor** resistencia de los elementos).
Dos debilidades elementales no se multiplican entre sí (Consagrar, mágico
+ Sagrado + fuego, a un no muerto: ×1.5, no ×1.875).

Se aplica a todo daño del grupo que pasa por `dmgEnemy` (golpes
primarios, atraviesa, rebote, ataque gratis), después de armadura y antes
de la esquiva, con la acción en curso (`_Action.skill`). No se aplica al
daño secundario de mecánicas del árbol (`_procDamage`: rebote de Arco
Voltaico, Combustión, Eco Arcano...), que ya usa la Marca y el quiebre.

El log lo dice con el resto de multiplicadores: `× 1.5 DÉBIL Sagrado`,
`× 0.7 RESISTE físico`. `DamageEvent.affinity` lleva el factor (JSON
`af`, solo si ≠ 1: aditivo, sin subir el protocolo) y la escena muestra
`DÉBIL ×1.5` (naranja) o `RESISTE ×0.7` (gris) sobre el enemigo, una vez
por acción (encima de `QUIEBRE ×1.5` si lo hay).

### 1.4 Las curas dañan (`healHarm`)

Una habilidad de cura (`SkillKind.heal`, también Bendición, Purificación,
Llama Fénix...) o de regeneración (`SkillKind.regen`) del grupo, además
de curar, daña a **cada enemigo vivo** con `healHarm > 0`: la cura
calculada (`(MAG × poder + 6) × (1 + healBonus)`; regeneración `+4`) ×
`healHarm`. Más poder de curación = más daño. Es daño secundario
(`_procDamage`, `DamageEvent.sourceId = 'curaSagrada'`): lleva Marca,
quiebre y ecos, sin crítico; llena la barra de quiebre ×0.5 y puede
matar. Una resurrección que revive a un aliado no daña. Pociones y
curas de pasivas tampoco.

Log: `· ¡La cura quema al Esqueleto! 36` (o `a la` si el nombre es
femenino); con varios, `· ¡La cura quema a los no muertos! Esqueleto 36,
Espectro 18`. FX: el número y el tajo en la luz del Sagrado
(`procHitStyle('curaSagrada')`).

### 1.5 Estados

- Inmune: el estado no entra (`_addStatus` devuelve `false`, sin
  `StatusAppliedEvent`; el log no dice que entró) y una nota por paso:
  `Esqueleto es INMUNE a Veneno (No muerto)`.
- Stacks de más / de menos: después del bonus del atacante; mínimo 1.
- Estado Sagrado (`holyTick`): el daño al empezar su turno (5 × stacks ×
  aura) se multiplica.

### 1.6 Quiebre, retrasos y Marca

- `breakMult`: multiplica todo llenado de la barra (golpes y el +15 de
  Aturdir / Congelar).
- `delayMult`: multiplica los retrasos de habilidades (`SkillDef.delay`)
  y de mecánicas del árbol (`delayTarget`).
- `markMult`: multiplica el bonus de la Marca (`damageTaken > 0`) que
  recibe en `dmgEnemy`.

### 1.7 Para otras reglas (notables del árbol, pasivas)

`isFamily(target, EnemyFamily.undead)`, `familyOfCombatant(c)` y
`familyRuleOf(enemyType)` en `rules/family_rules.dart`. Una notable "vs no
muertos" usa esos helpers; no hace falta tocar la tabla.

## 2. Bestiario (cuenta)

### 2.1 Modelo y persistencia

`BestiaryProgress.kills`: muertes por id de enemigo (`EnemyDef.id`). La
primera muerte desbloquea la ficha (`knows`). Es de la **cuenta** (como
el Atlas): `account.json` clave `best` = `{"k": {"slime": 12, ...}}`,
opcional (cuentas viejas: sin la clave = vacío; se escribe solo si hay
algo). Lectura tolerante: conteos no numéricos o < 1 se descartan.
`AccountBestiaryStore` guarda el máximo de cada conteo entre lo que hay
en la cuenta y lo nuevo (no pisa lo que sumó otra sesión).

### 2.2 Cuándo se suma

En `SessionController`, en los tres roles (solo, anfitrión, cliente):
con `BattleFinishedEvent(victory: true)`, si el jugador local estaba en
el grupo de la batalla, cada enemigo de la última batalla vista
(`bestiaryKills`: todos los de `BattleState.enemies`, invocaciones
incluidas; al ganar no queda ninguno en pie) suma 1. El cliente usa el
estado que ya le llega en los snapshots: **sin cambios de protocolo**.
Cada ficha nueva avisa en el chat local `Bestiario: Lobo agregado`.

## 3. Ficha al pasar el mouse (batalla)

Sobre un enemigo vivo de la escena (mismo hit test que el clic), una caja
con el estilo del `#tip` junto al puntero (sin salirse de la pantalla):

- **Conocido**: nombre (+ ÉLITE), nivel de la pelea (`SessionBattle.level`),
  familia (sigla y nombre en su color), `Débil:`, `Resiste:`,
  `Inmune:` con sus factores, la mecánica del jefe
  (`kBossMechanics.counter`) y `Derrotados: N`.
- **Desconocido**: `???` y "Derrotalo para agregarlo al bestiario".

Con el turno propio, la línea "Objetivo:" del menú suma la familia y
`débil a …` si ya se lo conoce.

(El mapa no tiene hover sobre los enemigos del campo: queda para más
adelante.)

## 4. Elementos de los enemigos (v0.7)

Elemento de cada golpe enemigo: `kEnemyElement` (abajo) o, si no está, el
del estado que aplica ese golpe (Quemadura = fuego, Congelación = hielo,
Veneno = veneno...), si no físico. ULT: `kEnemyUltElement` o su estado.
Así los enemigos mojan, cargan y detonan los estados de los jugadores
(elemental_reactions.md § 5.3):

| Enemigo | Golpe | ULT | Combo |
|---|---|---|---|
| Sierpe de Escarcha (zona 4) | **Agua**, deja Mojado (antes Congelación 1) | Aliento Glacial: Hielo | el Aliento congela al instante a los mojados (Congelación súbita): limpiá el Mojado o quebrala |
| Comunes de hielo (zonas 4, 8) | Hielo (Congelación) | — | derriten / congelan como siempre |
| Salamandra, Gólem de Magma, Bestia de Magma (zona 7) | Fuego (Quemadura) | Erupción Total: Fuego | detonan el Veneno de los jugadores (Explosión tóxica) y derriten |
| Vigilante del Vacío (zona 9) | **Agua**, deja Mojado (nuevo) | — | prepara al Ojo |
| Ojo del Abismo (zona 9) | **Electro** (sigue con 30% de Aturdido) | — | electrocuta a los mojados |
| Centinela del Vacío (zona 9) | **Electro**, deja Cargado (nuevo) | Colapso del Vacío: **Agua**, deja Mojado (nuevo) | la ULT hace Cortocircuito sobre los Cargados y moja; sus golpes siguientes electrocutan |
| Heraldo de las Eras (zona 10) | el elemento del estado del ciclo (fuego, veneno, hielo) | Furia Élite | su fuego detona el Veneno que dejó antes |
| Devorador (zona 10) | Fuego | Fin de las Eras: Fuego | detona Veneno |

## 5. Pestaña BESTIARIO

**Descripciones: pendiente del dueño.** `lib/game_engine/data/
enemy_descriptions.dart` (`kEnemyDescriptions`, id → texto) está vacío a
propósito; la ficha muestra la descripción solo si hay una. El juego no
inventa historia.

En el panel de personaje (pestaña 6, `CharacterTab.bestiary`) y desde el
título (`BESTIARIO`, solo lectura, `BestiaryScreen`).

- Izquierda: búsqueda por nombre, filtros por familia (`TODAS` + una por
  familia, en su color), `Descubiertos N/M` y la grilla por zona
  (comunes, invocaciones, jefe). Las desconocidas: silueta del sprite y
  `???`. Familia y búsqueda solo muestran fichas descubiertas (no
  revelan lo que falta).
- Derecha: sprite grande, la ficha de § 3 (más la descripción del
  dueño, si hay), zona, rol, nivel nativo y botín (XP, créditos, legendario del
  jefe). Desconocida: silueta, `???` y la zona.
- Teclado (`menu_focus.dart`): flechas dentro de cada zona (`FocusGrid`,
  sale por el borde a la siguiente), `Tab` entre filtros y grilla; elegir
  una ficha con el cursor muestra su detalle.
