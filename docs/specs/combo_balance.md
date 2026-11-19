# Spec (BORRADOR, falta OK del dueño): Rebalance por combos — v0.9

Pedido del dueño (v0.8.6):
- Estar **al nivel de la zona** tiene que costar. Ir sobrenivelado y
  matar todo de un golpe está bien; empezar el juego siendo poderoso, no.
- Curva en serrucho: dentro de cada tramo de 10 niveles, las 2 primeras
  zonas te hacen sentir poderoso y los últimos 4-5 niveles cuestan de
  verdad (te pueden matar). La ascensión, o el tramo siguiente, te
  vuelve a poner arriba.
- **El daño fuerte sale de combos**, sobre todo en grupo. Solo, los
  números te dejan avanzar con un personaje; con más jugadores suben las
  resistencias, el daño plano rinde menos y hay que combinar.
  Ejemplo: 20 stacks de Quemadura detonados le bajan más de la mitad de
  la vida.
- No esponjas de vida: si no le pegás con su debilidad, no lo matás de
  un golpe. Puede haber inmunidades de daño.
- Quiebre: hoy élites y jefes se quiebran tan rápido que nunca llegan a
  su ULT. Ni el daño plano ni los ticks de estados deberían llenar mucho
  la barra; lo que llena el quiebre sale del árbol y de mods o pasivas
  de arma.
- Mini tutorial de combos y quiebre.

Referencias que se tomaron (de lo que se sabe de cada juego, sin
investigación nueva):
- **Baldur's Gate 3:** números chicos, resistencia = mitad, inmunidad =
  0; la dificultad viene de cómo actúan los enemigos, no de su vida.
- **Divinity: Original Sin 2:** la diferencia de nivel pesa mucho y el
  equipo envejece rápido; los combos de superficies son la gracia. Lo
  que **no** se copia: los enemigos esponja.
- **Expedition 33:** afinidades fuertes (débil, resistente, inmune,
  absorbe); el poder viene de preparar (marcas, stacks, cargas) y
  liberar; la barra de quiebre se llena con habilidades que tienen su
  propio valor de quiebre, no con el daño; el techo de daño se rompe
  recién con la build.

Todos los números de abajo son el **punto de partida**: se calibran con
el simulador de balance (balance_admin.md § 5) antes de implementarlos y
quedan editables en `assets/balance/balance.json`.

## 1. Curva por tramos (serrucho)

- Un **tramo** son 10 niveles (1-10, 11-20…) y sus zonas se dividen en 3
  partes: **A** (primeros ~3 niveles), **B** (~3) y **C** (últimos 4-5).
- La vida de los enemigos ya no sube un 15% parejo por nivel. Por
  posición dentro del tramo:
  - A y B: +10% por nivel (el jugador, con el loot nuevo, va por encima
    de la curva).
  - C: +22% por nivel, y las **resistencias** suben (§ 3.3).
  - Al empezar el tramo siguiente, la curva vuelve a la pendiente suave.
- En las zonas C hay más élites (de 1 en 6 grupos a 1 en 3) y los
  comunes pegan un 15% más.
- Las Pruebas del Tiempo (ascension.md) cierran los tramos 30, 40 y 50,
  y la ascensión es el "salto" del serrucho.
- Meta de la simulación, para un personaje al nivel de la zona con loot
  normal del tramo:
  - A y B: los comunes mueren en 1-2 acciones;
  - C: en 3-4 acciones, si no se combina;
  - C a 4 jugadores sin combos: el grupo puede perder.

## 2. El loot no se adelanta a la zona

- Todo lo que cae tiene nivel de objeto ≤ nivel **tope** de la zona.
- En las legendarias, los mods fijos escalan con el nivel del objeto,
  igual que los aleatorios (hoy hay que confirmarlo en el código).
- Tope de forja por nivel del objeto: una legendaria de nivel 5 no llega
  a +10, sino a `min(tope de rareza, 2 + nivel/5)`.
- Así una legendaria se siente enorme en su tramo y en el siguiente ya la
  pasa el loot nuevo, como en Divinity.

## 3. Afinidades

### 3.1 Escala

| Afinidad | Multiplicador | Hoy |
|---|---|---|
| Débil | ×1.5 | ×1.25-1.5 |
| Normal | ×1.0 | ×1.0 |
| Resistente | ×0.5 | ×0.5-0.8 |
| Inmune | ×0 (cartel "INMUNE") | no existe para daño |
| Absorbe (solo jefes, opcional) | cura lo que le pegarías | no existe |

- Cada familia tiene **al menos una** debilidad y **al menos una**
  resistencia; algunas, una inmunidad. Por ejemplo, el Elemental de
  fuego pasa a ser inmune al Fuego.
- La tabla nueva va en bestiary.md y `kFamilyRules`. La ficha del
  enemigo muestra sus afinidades una vez que se descubren (golpeándolo o
  con el bestiario).

**Implementado (v0.9, paso 2):** tabla nueva en bestiary.md § 1.1 y `kFamilyRules`. Inmune: daño 0, log `× 0 INMUNE fuego`, cartel `INMUNE`. Absorbe queda para después (opcional).

### 3.2 Tope por golpe sin debilidad

- Un golpe que **no** pega a una debilidad no puede sacar más de:
  - 60% de la vida máxima de un común;
  - de un élite: 45% solo → 35% a 4 jugadores;
  - de un jefe: 25% solo → 15% a 4 jugadores.
- **Ajuste (pasos 3-4, decisión del dueño):** con el 15% fijo el guerrero
  solo perdía siempre contra el Rey Limo. Élite y jefe escalan con el
  grupo, lineal y editable en el admin (`hitCap`: `eliteSolo` / `elite`,
  `bossSolo` / `boss`):
  `tope = solo + (a 4 − solo) × (jugadores − 1) / 3` → jefe 25 / 22 / 18 /
  15%, élite 45 / 42 / 38 / 35%. El común no cambia.
- Sin tope: golpe a una debilidad, Convergencia (§ 4) o enemigo quebrado.
- El log muestra `→ N (resiste el golpe)` al final del desglose cuando se
  aplica (texto aprobado por el dueño; antes `(tope sin debilidad)`).
- Ir sobrenivelado lo saltea: si el jugador tiene 5 o más niveles que el
  enemigo, no hay tope.
- **Implementado (v0.9, paso 2):** `BattleEngine._hitCapFor`. Tope =
  `ceil(vida máx. × fracción)`. "Golpe a una debilidad" = algún factor
  de familia > 1 en el golpe; "reacción" = cualquier reacción de golpe
  (las Convergencias de § 4 son daño directo y no pasan por el tope);
  "quebrado" = el enemigo
  vulnerable. El nivel del enemigo es el de `ZoneRules.scaleBattle`
  (`Combatant.level`, JSON `lv`, protocolo 13); sin escalar, su nivel
  base del catálogo. Solo topa los golpes de `dmgEnemy` (no ticks ni
  daño secundario de mecánicas). Números editables en el admin de
  balance (`hitCap`, balance_admin.md § v0.9).

### 3.3 Grupo: resistencias, no esponja

- Vida en cooperativo: `0.55 + 0.45 × jugadores` (4 → ×2.35) pasa a
  `0.6 + 0.3 × jugadores` (4 → ×1.8).
- Además, una **mitigación de grupo** baja todo el daño directo, incluido
  el plano: −8% por cada jugador después del primero (4 → −24%). En las
  zonas C, otro −10%.
- Las Convergencias (§ 4) **no** sufren esa mitigación: van por
  porcentaje de vida y por stacks. A 4 jugadores, lo eficiente es
  combinar.

## 4. Combos: preparar y detonar

Hoy las reacciones (elemental_reactions.md) multiplican el golpe que
detona. Pasan a tener dos tipos:

- **Reacciones de golpe** (Electrocución, Derretir, Congelación súbita,
  Cortocircuito): siguen como están, pero ignoran el tope de § 3.2.
- **Convergencias**: consumen stacks y pegan por **porcentaje de la vida
  máxima**.

| Convergencia | Prepara | Detona | Daño por stack | Tope (común / élite / jefe) |
|---|---|---|---|---|
| Explosión tóxica | Veneno | golpe de Fuego | 2.5% | 70% / 55% / 40% |
| Combustión (nueva) | Quemadura | golpe de Veneno | 2.5% | 70% / 55% / 40% |
| Juicio (nueva) | Sagrado | Marca + golpe Sagrado | 2% | 60% / 45% / 30% |

- Si el enemigo es **débil** al elemento que detona: ×1.25. Si es
  **resistente**: ×0.5.
- Le salpica el 30% a los demás enemigos.
- Ejemplo del dueño: 20 de Quemadura y después un golpe de Veneno dan
  un 50% de la vida, más el golpe. Contra un débil al Veneno, 62.5%.
- Los stacks por enemigo suben su tope de 10 a 30. Aplicar stacks se
  vuelve el trabajo de los de soporte y las habilidades de área.
- Las habilidades de **área** pegan ×0.6 por blanco (relativo a hoy),
  pero aplican sus estados completos: el área prepara, no limpia.
- Combos entre jugadores: si el que detona no es el que preparó, la
  Convergencia da +10 de carga de ULT a los dos.

**Implementado (v0.9, paso 3):**
- `ReactionKind.combustion` (al final del enum: el sello de los Jefes del
  Abismo guarda el índice) y `ReactionKind.convergence`. Tabla de
  reacciones: Quemadura + golpe de Veneno → Combustión.
- `_Turn._converge`: `daño = vida máx. × perStack × stacks`, × afinidad de
  la familia del objetivo al elemento que detona (débil ×1.25, resiste
  ×0.5, inmune 0), con tope por común / élite / jefe
  (`ReactionDef.commonCap` / `eliteCap` / `bossCap`). Salpica el 30% de
  ese daño a cada otro del bando, con su propia afinidad y tope. Es daño
  directo: sin tope por golpe ni mitigaciones. El golpe que detona
  igual hace su daño (y, como reacción, ignora el tope por golpe). Log:
  `¡COMBUSTIÓN! 20 Quemadura × 2.5% = 50% × 1.25 → N a X (tope)`.
- Quebrar: una Convergencia quiebra a un enemigo Fisurado (§ 5). Toda
  reacción del grupo suma +8 puntos de quiebre.
- +10 de ULT: si `primedBy` del estado consumido es otro jugador vivo,
  los dos suben 10 (`ComboRulesDef.ultBonus`).
- Tope de stacks de Quemadura y Veneno: 30 (`ComboRulesDef.stackCap`;
  antes no tenían tope, elemental_reactions.md § 6). Vale también para
  los jugadores.
- Área: las habilidades a todos (no las ULT ni los dúos) pegan
  ×0.6 por blanco (`ComboRulesDef.areaMult`, log `× 0.6 área`); sus
  estados entran completos. Los golpes secundarios de mecánicas (rebote,
  repetición de Diluvio) no llevan el ×0.6.
- **Juicio queda pendiente** (no encaja limpio): la Marca es un debuff
  con duración (`BuffStat.damageTaken`), no un estado con stacks; el
  Sagrado tiene tope 9 y dura por turnos; y cualquier golpe Sagrado sobre
  un enemigo marcado consumiría el Sagrado de los builds de Templario,
  que hoy viven del tick. Hace falta decidir antes si Juicio pide la
  Marca como precondición (§ 5.2) o si la Marca pasa a ser un estado.
- Números editables en el admin de balance: por Convergencia en
  `reaction` (`perStack`, `splash`, topes) y los globales en `combo`
  (balance_admin.md).

## 5. Quiebre (rework)

Hoy la barra se llena con `daño × factor`, el umbral es ~0.35 × la vida
del jefe y un golpe grande quiebra solo.

**Nuevo**, inspirado en Expedition 33:
- La barra se llena con **puntos de quiebre** de cada acción, sin mirar
  el daño:

| Fuente | Puntos |
|---|---|
| Ataque básico | 4 |
| Habilidad física | 6 |
| Habilidad mágica | 4 |
| ULT | 12 |
| Dúo | 10 |
| Golpe a una debilidad | +50% |
| Aplicar Aturdido o Congelación | +6 |
| Reacción o Convergencia | +8 |
| Ticks de estado, daño plano, rebotes, ecos | 0 |

- Aumentan los puntos: notables del árbol (+20% a +40% de quiebre), un
  afijo de arma nuevo **"rompedor"** (+10% a +30% de quiebre por tier) y
  algunas pasivas de arma y de ascensión. Las armas pesadas (martillo,
  hacha) traen +25% de base.
- Umbrales (a calibrar):
  - común 12;
  - élite 30;
  - jefe de 40 a 60;
  - × `0.6 + 0.3 × jugadores`.
- **Dos pasos** (como en Expedition 33, donde llenar la barra no hace
  nada y hace falta una habilidad que diga "Puede quebrar"): la barra
  llena deja al enemigo **Fisurado**, y recién un golpe con
  **Quebrar** lo quiebra. Si no se quiebra antes de su turno, se
  recupera y la barra baja a la mitad.
- **Nadie se queda sin Quebrar.** Lo traen:
  - todas las ULT;
  - cualquier Convergencia (§ 4);
  - los dúos;
  - al menos 1 habilidad de **cada** arma, garantizada en su kit base.
    Además, un mod de habilidad lo puede agregar a otra.
- **Sin traba para los jefes** (corrección del dueño): no hay regla de
  "primero muestra su ULT". Los números se calibran para que quebrar a un
  jefe antes de su primera ULT pase **solo** si los 4 encadenan bien sus
  turnos (debilidades, estados que suman quiebre, build de quiebre) y el
  último tiene Quebrar. Tiene que ser difícil pero posible. Meta en el
  simulador: con un grupo de 4 al azar, menos del 10% de las veces; con
  4 builds de quiebre coordinadas, más o menos la mitad.
- El resto sigue igual: quebrado pierde el turno, recibe +50% de daño
  durante 2 turnos del grupo, el umbral sube +25% por quiebre y se
  cancela la ULT avisada.

### 5.1 La habilidad base de Quebrar

- Hace **poco daño** (×0.6 del ATQ/MAG) y casi ningún punto de quiebre
  propio: su trabajo es **cerrar** el quiebre, no llenarlo.
- Pide que el objetivo esté **Fisurado** (precondición, § 5.2) y
  cuesta 2 de Pulso.

**Implementado (v0.9, paso 4):**
- Puntos por acción (`ComboRulesDef`, editables en el admin `combo`): se
  suman **una vez por objetivo y acción** (una ráfaga de 4 golpes suma
  una vez), en el primer golpe primario. Base Quebrar: 1. Golpe a una
  debilidad: +50%. Bonus que se suman y multiplican los puntos:
  `breakBonus` de la habilidad (ULT de rama, variantes), pasivas de arma
  y nodos del árbol (`ProcEffectKind.breakBonus`), el afijo **Rompedor**
  (`ModStat.breakPower`, prefijo, T5 10-12% … T1 26-30%) y +25% de las
  armas pesadas (`kHeavyWeaponTypes`: hacha, martillo y escudo). Siguen
  la familia (constructos ×1.5) y la Congelación (+10% por stack).
  Aturdido o Congelación aplicados por el grupo: +6. Reacción: +8.
  Ticks, rebotes, ecos, daño directo y secundario: 0.
- Umbrales en puntos, sin escalar con la vida ni el nivel de zona:
  comunes 12, élites × 2.5 (30), jefes **65 a 95** por zona (Rey Limo 65
  … Devorador y Jefes del Abismo 95), × `0.6 + 0.3 × jugadores`. **Fuera
  del rango del spec (40-60):** con 40-60 el grupo mixto quebraba al Rey
  Limo y a la Hechicera antes de su primera ULT el 100% de las veces;
  ×1.6 lo deja en 0-9% (tabla de abajo).
- Barra llena → **Fisurado** (`Combatant.fissured`, JSON `fis`, evento
  `BreakPhase.fissured`, cartel `FISURADO`, la etiqueta de quiebre dice
  `FISURADO` y la barra parpadea lento). Fisurado, la barra no se llena.
- Un golpe primario de una acción con **Quebrar** (`SkillDef.breaks`,
  toda ULT, todo dúo, toda Convergencia) sobre un Fisurado de **antes de
  este paso** lo quiebra. Si el mismo golpe lo fisuró, no (dos pasos).
  Quebrar sobre un no Fisurado solo suma sus puntos (el tooltip lo dice).
- Si llega a su turno Fisurado: la barra vuelve a la mitad
  (`steadyGauge`, evento `BreakPhase.steadied`, texto `SE RECOMPONE`).
  La baja del 10% por turno sigue para la barra a medio llenar.
- **Quebrar base** (`quebrar`, física; `quebrarArcano`, mágica para
  báculo, varita y tomo): la agrega el motor al final del kit de toda
  arma (no está en `WeaponDef.skillIds`, no se traslada por fusión). Por
  ahora cuesta 2 de MP; el Pulso y la precondición llegan en el paso 7.
  El "mod de habilidad que agrega Quebrar" queda para después.
- **Hook del árbol:** los notables de quiebre usan el efecto
  `breakBonus` que ya existe (`_breakBonus`, con sus condiciones
  `vsStatus`, `vsMarked`, `vsBroken`...). Nodos que se agregarían (sin
  crearlos todavía): un notable de Guerrero "+30% de quiebre" en la rama
  de martillo / hacha; uno de Paladín "+20% de quiebre a aturdidos";
  uno de Tirador "+20% de quiebre a Marcados"; y uno de grupo "Quebrar
  da +10 de ULT al que lo usa".

## 5.2 Pulso y precondiciones (PROPUESTA, falta OK del dueño)

Punto medio entre los puntos de acción de Expedition 33 y la energía por
turno de Slay the Spire, sin tirar el timeline actual (cada actor sigue
teniendo **un** turno según su velocidad).

- **Pulso:** un recurso de batalla por personaje, de 0 a 5. Arranca la
  pelea en 1.
  - +1 al empezar tu turno;
  - +1 por ataque básico;
  - +1 por golpe a una debilidad o reacción (una vez por acción);
  - +1 al defender.
- El **MP sigue**: es el recurso largo de la expedición (pociones,
  descanso). El Pulso es el ritmo dentro de la pelea.
- Costos según lo que hace la habilidad:
  - **Preparar** (poner estados, Mojar, Marcar): 0-1 de Pulso, más MP.
  - **Detonar y Quebrar:** 2-3 de Pulso.
  - La ULT sigue con su propia carga.
- **Precondiciones:** una habilidad puede pedir algo. Ejemplos:
  - el objetivo con 5 o más stacks de Quemadura;
  - el objetivo Fisurado;
  - un aliado con Marca;
  - tu vida por debajo del 50%.
  Si no se cumple, o falta Pulso o MP, el botón sale **desactivado**, y
  el tooltip dice qué falta ("Necesita: objetivo Fisurado").
- **Encadenar:** las habilidades marcadas **Instante** (preparaciones
  baratas) no terminan el turno. Después de una habilidad Instante podés hacer una
  acción más, máximo una habilidad Instante por turno. Así, en un turno se puede
  "preparar + detonar" si juntaste Pulso, como una mano corta de Slay
  the Spire.
- Compañeros (IA): usan las mismas reglas.

## 6. Mini tutorial

- Se dispara la primera vez que cada cosa pasa, en solo o en grupo, y se
  puede desactivar en Opciones ("Consejos de combate"):
  1. **Debilidad:** primer golpe a una debilidad → "¡DÉBIL! Este enemigo
     recibe ×1.5 de Fuego. Mirá sus afinidades en la ficha (clic
     derecho)".
  2. **Tope:** primer golpe que topa → "Sin pegarle a su debilidad, un
     golpe no lo baja de una. Combiná elementos o detoná estados".
  3. **Preparar:** primera vez con 5 o más stacks → "Acumulaste 5 de
     Quemadura. Un golpe de Veneno los detona por % de su vida".
  4. **Detonar:** primera Convergencia → muestra el cálculo (`20 stacks ×
     2.5% = 50%`).
  5. **Fisurado:** primera barra llena → "Está Fisurado: golpealo
     con una habilidad que tenga Quebrar antes de su turno".
  6. **Quiebre:** primer quiebre → "Pierde su turno y recibe +50% de
     daño durante 2 turnos".
  7. **ULT enemiga:** primer aviso → "Va a usar su ULT: quebralo,
     defendete o protegé al grupo".
- Hay además una página **"Combos"** en el códice o la ayuda con la
  tabla de reacciones, la de Convergencias y cómo funciona el quiebre.
- Es texto mecánico, sin lore.

## 6b. Personajes existentes (migración)

El patrón ya existe en el árbol (`tv`, passive_tree_v3.md § 11: lo que
cambia se devuelve gratis). Se aplica igual:

| Qué | Qué pasa al cargar el personaje |
|---|---|
| Nivel, XP, atributos, oro, materiales, ascensión | no cambia |
| Árbol de pasivas | sube `tv`. Los nodos que cambian (quiebre, área, notables de reacciones) se **devuelven** como puntos libres; el resto se queda. Aviso: "El árbol cambió: te devolvimos N puntos" |
| Armas | se quedan. Los mods fijos de las legendarias se recalculan al nivel del objeto. Si la forja está por encima del tope nuevo, el arma queda en el tope y se **devuelven los materiales** de los niveles de más |
| Habilidades y fusiones | se quedan. Cada habilidad toma del catálogo su costo de Pulso, su precondición y si es Instante. Si una fusión queda inválida, se devuelve el material y la habilidad vuelve a su ranura vacía |
| Afijos de daño plano | se quedan (rinden menos en grupo por § 3.3) |
| Tutorial | por cuenta: `tutV = 0`, así que cada cuenta lo hace una vez completo (combat_tutorial.md § 2) |
| Partidas guardadas en medio de una misión | se cierran (la misión vuelve al sello sin penalidad) |

- Un solo aviso al cargar, con todo lo que se devolvió.
- Antes de migrar se hace una copia de seguridad del archivo de cuenta,
  como en las migraciones anteriores.
- Tests con perfiles reales de v0.8.6 como fixtures (copias inventadas,
  nunca los datos de `%APPDATA%`).

## 7. Orden de implementación

1. Simulador: medir el estado actual (al nivel de la zona, con loot
   normal y con legendaria; zonas A y C; 1 y 4 jugadores).
2. Afinidades y tope (§ 3.1-3.2).
3. Convergencias y área (§ 4). **Hecho.**
4. Quiebre (§ 5). **Hecho.**
5. Curva por tramos y grupo (§ 1, § 3.3).
6. Loot atado a la zona (§ 2).
7. Pulso, precondiciones y encadenar (§ 5.2).
8. Migración de personajes (§ 6b).
9. Tutorial de combate (combat_tutorial.md). Reemplaza al mini tutorial
   de § 6, que queda solo como avisos opcionales en partida.

Cada paso se calibra con el simulador y deja tests; protocolo de red
nuevo si cambia el estado que viaja.

## Medición inicial (v0.8.6)

Con `test/game_engine/balance_measure_test.dart` (imprime la tabla, no
falla). Simulador de balance (balance_admin.md § 5) con su IA simple:
ULT si está cargada, si no la 1.ª habilidad del arma si alcanza el MP,
si no ataque; siempre al primer enemigo vivo. Nunca busca debilidades.

- Personaje **al nivel de la zona**: atributos típicos, arma de la clase
  (espada / báculo) de nivel ≤ zona. **Raro +2** = Raro de nivel de zona,
  forja POT +2. **Leg. +10** = la legendaria de la familia con la base
  más alta que entra, forja POT 5 + CRÍT 5 (no hay legendaria de nivel 1).
- Zonas: T1 A = Pradera nv 1, T1 C = Bosque nv 10, T3 A = Fortaleza nv 21,
  T3 C = Laberinto nv 30. Comunes = 2.º grupo de la misión; élite = el
  élite de la misión; jefe = jefe + escolta. 16 batallas por fila.
- 4 jugadores = 4 copias del mismo personaje. *Acciones* = acciones del
  grupo hasta ganar (promedio de las victorias; por jugador, dividir por
  4). *Mayor golpe* = el DamageEvent directo más grande de cada batalla
  sobre la vida máx. del blanco (puede pasar 100% por exceso, y cuenta
  reacciones y daño secundario, que no topan).
- Cada celda: **v0.8.6 → después del paso 2** (afinidades y tope).

| Zona | Clase | Loot | Jug. | Pelea | Victorias | Acciones (grupo) | Daño/acción | Mayor golpe |
|---|---|---|---|---|---|---|---|---|
| Pradera Esmeralda (T1 A, nv 1) | Guerrero | Raro +2 | 1 | comunes | 16/16 → 16/16 | 1.9 → 2.0 | 43 → 34 | 126% → 76% |
| Pradera Esmeralda (T1 A, nv 1) | Guerrero | Raro +2 | 1 | élite | 16/16 → 16/16 | 2.8 → 2.9 | 28 → 26 | 65% → 65% |
| Pradera Esmeralda (T1 A, nv 1) | Guerrero | Raro +2 | 1 | jefe | 15/16 → 0/16 | 6.7 → 0.0 | 55 → 44 | 127% → 88% |
| Pradera Esmeralda (T1 A, nv 1) | Guerrero | Raro +2 | 4 | comunes | 16/16 → 16/16 | 3.0 → 3.0 | 58 → 58 | 76% → 76% |
| Pradera Esmeralda (T1 A, nv 1) | Guerrero | Raro +2 | 4 | élite | 16/16 → 16/16 | 4.9 → 4.9 | 30 → 30 | 29% → 29% |
| Pradera Esmeralda (T1 A, nv 1) | Guerrero | Raro +2 | 4 | jefe | 16/16 → 16/16 | 21.0 → 21.0 | 35 → 35 | 57% → 57% |
| Pradera Esmeralda (T1 A, nv 1) | Maga | Raro +2 | 1 | comunes | 16/16 → 16/16 | 2.0 → 2.0 | 40 → 48 | 180% → 218% |
| Pradera Esmeralda (T1 A, nv 1) | Maga | Raro +2 | 1 | élite | 16/16 → 16/16 | 1.9 → 1.9 | 50 → 60 | 106% → 127% |
| Pradera Esmeralda (T1 A, nv 1) | Maga | Raro +2 | 1 | jefe | 2/16 → 4/16 | 4.0 → 3.8 | 54 → 64 | 59% → 71% |
| Pradera Esmeralda (T1 A, nv 1) | Maga | Raro +2 | 4 | comunes | 16/16 → 16/16 | 3.9 → 3.9 | 43 → 52 | 91% → 109% |
| Pradera Esmeralda (T1 A, nv 1) | Maga | Raro +2 | 4 | élite | 16/16 → 16/16 | 3.3 → 2.6 | 45 → 55 | 41% → 49% |
| Pradera Esmeralda (T1 A, nv 1) | Maga | Raro +2 | 4 | jefe | 16/16 → 16/16 | 15.1 → 13.4 | 42 → 51 | 62% → 74% |
| Bosque Hondo (T1 C, nv 10) | Guerrero | Raro +2 | 1 | comunes | 16/16 → 16/16 | 1.0 → 2.0 | 81 → 45 | 120% → 74% |
| Bosque Hondo (T1 C, nv 10) | Guerrero | Raro +2 | 1 | élite | 16/16 → 16/16 | 2.0 → 2.0 | 105 → 95 | 74% → 74% |
| Bosque Hondo (T1 C, nv 10) | Guerrero | Raro +2 | 1 | jefe | 0/16 → 0/16 | 0.0 → 0.0 | 106 → 93 | 30% → 28% |
| Bosque Hondo (T1 C, nv 10) | Guerrero | Raro +2 | 4 | comunes | 16/16 → 16/16 | 2.6 → 2.6 | 98 → 95 | 77% → 75% |
| Bosque Hondo (T1 C, nv 10) | Guerrero | Raro +2 | 4 | élite | 16/16 → 16/16 | 4.4 → 4.4 | 103 → 103 | 33% → 33% |
| Bosque Hondo (T1 C, nv 10) | Guerrero | Raro +2 | 4 | jefe | 16/16 → 16/16 | 18.3 → 18.3 | 95 → 95 | 91% → 91% |
| Bosque Hondo (T1 C, nv 10) | Guerrero | Leg. +10 | 1 | comunes | 16/16 → 16/16 | 1.0 → 1.0 | 113 → 136 | 168% → 202% |
| Bosque Hondo (T1 C, nv 10) | Guerrero | Leg. +10 | 1 | élite | 16/16 → 16/16 | 1.8 → 1.8 | 142 → 171 | 100% → 119% |
| Bosque Hondo (T1 C, nv 10) | Guerrero | Leg. +10 | 1 | jefe | 15/16 → 15/16 | 3.4 → 3.4 | 236 → 236 | 210% → 210% |
| Bosque Hondo (T1 C, nv 10) | Guerrero | Leg. +10 | 4 | comunes | 16/16 → 16/16 | 1.8 → 1.5 | 149 → 173 | 107% → 125% |
| Bosque Hondo (T1 C, nv 10) | Guerrero | Leg. +10 | 4 | élite | 16/16 → 16/16 | 3.3 → 2.8 | 145 → 169 | 41% → 48% |
| Bosque Hondo (T1 C, nv 10) | Guerrero | Leg. +10 | 4 | jefe | 16/16 → 16/16 | 6.8 → 6.8 | 246 → 246 | 131% → 131% |
| Bosque Hondo (T1 C, nv 10) | Maga | Raro +2 | 1 | comunes | 16/16 → 16/16 | 1.0 → 2.0 | 105 → 41 | 156% → 61% |
| Bosque Hondo (T1 C, nv 10) | Maga | Raro +2 | 1 | élite | 16/16 → 16/16 | 2.0 → 3.0 | 134 → 95 | 93% → 93% |
| Bosque Hondo (T1 C, nv 10) | Maga | Raro +2 | 1 | jefe | 0/16 → 0/16 | 0.0 → 0.0 | 147 → 72 | 92% → 15% |
| Bosque Hondo (T1 C, nv 10) | Maga | Raro +2 | 4 | comunes | 16/16 → 16/16 | 1.8 → 2.0 | 109 → 95 | 73% → 60% |
| Bosque Hondo (T1 C, nv 10) | Maga | Raro +2 | 4 | élite | 16/16 → 16/16 | 3.8 → 4.0 | 122 → 121 | 39% → 38% |
| Bosque Hondo (T1 C, nv 10) | Maga | Raro +2 | 4 | jefe | 16/16 → 16/16 | 14.3 → 14.3 | 114 → 112 | 78% → 68% |
| Bosque Hondo (T1 C, nv 10) | Maga | Leg. +10 | 1 | comunes | 16/16 → 16/16 | 1.0 → 1.0 | 158 → 189 | 236% → 282% |
| Bosque Hondo (T1 C, nv 10) | Maga | Leg. +10 | 1 | élite | 16/16 → 16/16 | 1.0 → 1.0 | 158 → 189 | 90% → 108% |
| Bosque Hondo (T1 C, nv 10) | Maga | Leg. +10 | 1 | jefe | 12/16 → 12/16 | 3.0 → 3.0 | 297 → 297 | 226% → 226% |
| Bosque Hondo (T1 C, nv 10) | Maga | Leg. +10 | 4 | comunes | 16/16 → 16/16 | 1.4 → 1.0 | 178 → 217 | 121% → 137% |
| Bosque Hondo (T1 C, nv 10) | Maga | Leg. +10 | 4 | élite | 16/16 → 16/16 | 2.4 → 2.3 | 195 → 232 | 56% → 64% |
| Bosque Hondo (T1 C, nv 10) | Maga | Leg. +10 | 4 | jefe | 16/16 → 16/16 | 6.9 → 6.9 | 225 → 225 | 132% → 132% |
| Fortaleza Caída (T3 A, nv 21) | Guerrero | Raro +2 | 1 | comunes | 16/16 → 16/16 | 3.5 → 3.5 | 81 → 81 | 53% → 53% |
| Fortaleza Caída (T3 A, nv 21) | Guerrero | Raro +2 | 1 | élite | 16/16 → 16/16 | 6.7 → 6.7 | 98 → 92 | 40% → 34% |
| Fortaleza Caída (T3 A, nv 21) | Guerrero | Raro +2 | 1 | jefe | 0/16 → 0/16 | 0.0 → 0.0 | 161 → 140 | 119% → 79% |
| Fortaleza Caída (T3 A, nv 21) | Guerrero | Raro +2 | 4 | comunes | 16/16 → 16/16 | 6.3 → 6.3 | 81 → 81 | 23% → 23% |
| Fortaleza Caída (T3 A, nv 21) | Guerrero | Raro +2 | 4 | élite | 16/16 → 16/16 | 16.8 → 16.8 | 75 → 75 | 10% → 10% |
| Fortaleza Caída (T3 A, nv 21) | Guerrero | Raro +2 | 4 | jefe | 16/16 → 16/16 | 43.4 → 43.4 | 85 → 85 | 47% → 47% |
| Fortaleza Caída (T3 A, nv 21) | Guerrero | Leg. +10 | 1 | comunes | 16/16 → 16/16 | 2.4 → 2.4 | 140 → 135 | 94% → 91% |
| Fortaleza Caída (T3 A, nv 21) | Guerrero | Leg. +10 | 1 | élite | 16/16 → 16/16 | 3.9 → 3.9 | 149 → 149 | 42% → 42% |
| Fortaleza Caída (T3 A, nv 21) | Guerrero | Leg. +10 | 1 | jefe | 14/16 → 6/16 | 5.4 → 5.5 | 427 → 303 | 195% → 151% |
| Fortaleza Caída (T3 A, nv 21) | Guerrero | Leg. +10 | 4 | comunes | 16/16 → 16/16 | 4.3 → 4.3 | 130 → 130 | 36% → 36% |
| Fortaleza Caída (T3 A, nv 21) | Guerrero | Leg. +10 | 4 | élite | 16/16 → 16/16 | 9.6 → 9.6 | 134 → 134 | 17% → 17% |
| Fortaleza Caída (T3 A, nv 21) | Guerrero | Leg. +10 | 4 | jefe | 16/16 → 16/16 | 24.1 → 24.1 | 158 → 158 | 72% → 72% |
| Fortaleza Caída (T3 A, nv 21) | Maga | Raro +2 | 1 | comunes | 16/16 → 16/16 | 2.0 → 2.0 | 129 → 118 | 69% → 59% |
| Fortaleza Caída (T3 A, nv 21) | Maga | Raro +2 | 1 | élite | 15/16 → 15/16 | 4.2 → 4.2 | 147 → 151 | 40% → 43% |
| Fortaleza Caída (T3 A, nv 21) | Maga | Raro +2 | 1 | jefe | 0/16 → 0/16 | 0.0 → 0.0 | 214 → 219 | 48% → 54% |
| Fortaleza Caída (T3 A, nv 21) | Maga | Raro +2 | 4 | comunes | 16/16 → 16/16 | 3.9 → 3.9 | 134 → 134 | 33% → 33% |
| Fortaleza Caída (T3 A, nv 21) | Maga | Raro +2 | 4 | élite | 16/16 → 16/16 | 9.3 → 9.3 | 141 → 141 | 17% → 17% |
| Fortaleza Caída (T3 A, nv 21) | Maga | Raro +2 | 4 | jefe | 15/16 → 15/16 | 22.5 → 22.1 | 165 → 166 | 115% → 123% |
| Fortaleza Caída (T3 A, nv 21) | Maga | Leg. +10 | 1 | comunes | 16/16 → 16/16 | 1.0 → 2.0 | 297 → 120 | 148% → 60% |
| Fortaleza Caída (T3 A, nv 21) | Maga | Leg. +10 | 1 | élite | 16/16 → 16/16 | 2.4 → 3.0 | 346 → 264 | 87% → 82% |
| Fortaleza Caída (T3 A, nv 21) | Maga | Leg. +10 | 1 | jefe | 15/16 → 1/16 | 3.5 → 6.0 | 538 → 413 | 178% → 233% |
| Fortaleza Caída (T3 A, nv 21) | Maga | Leg. +10 | 4 | comunes | 16/16 → 16/16 | 2.0 → 2.0 | 313 → 254 | 73% → 56% |
| Fortaleza Caída (T3 A, nv 21) | Maga | Leg. +10 | 4 | élite | 16/16 → 16/16 | 4.2 → 4.2 | 341 → 341 | 39% → 39% |
| Fortaleza Caída (T3 A, nv 21) | Maga | Leg. +10 | 4 | jefe | 16/16 → 16/16 | 7.7 → 7.9 | 512 → 492 | 93% → 76% |
| Laberinto Temporal (T3 C, nv 30) | Guerrero | Raro +2 | 1 | comunes | 16/16 → 16/16 | 1.0 → 2.0 | 265 → 264 | 124% → 186% |
| Laberinto Temporal (T3 C, nv 30) | Guerrero | Raro +2 | 1 | élite | 16/16 → 16/16 | 2.0 → 2.0 | 332 → 297 | 72% → 72% |
| Laberinto Temporal (T3 C, nv 30) | Guerrero | Raro +2 | 1 | jefe | 0/16 → 0/16 | 0.0 → 0.0 | 511 → 566 | 44% → 50% |
| Laberinto Temporal (T3 C, nv 30) | Guerrero | Raro +2 | 4 | comunes | 16/16 → 16/16 | 2.0 → 2.0 | 358 → 350 | 86% → 86% |
| Laberinto Temporal (T3 C, nv 30) | Guerrero | Raro +2 | 4 | élite | 16/16 → 16/16 | 4.5 → 4.5 | 335 → 335 | 32% → 32% |
| Laberinto Temporal (T3 C, nv 30) | Guerrero | Raro +2 | 4 | jefe | 16/16 → 16/16 | 9.5 → 8.5 | 450 → 518 | 137% → 167% |
| Laberinto Temporal (T3 C, nv 30) | Guerrero | Leg. +10 | 1 | comunes | 16/16 → 16/16 | 2.0 → 2.0 | 201 → 188 | 116% → 116% |
| Laberinto Temporal (T3 C, nv 30) | Guerrero | Leg. +10 | 1 | élite | 16/16 → 16/16 | 3.4 → 3.4 | 213 → 213 | 54% → 54% |
| Laberinto Temporal (T3 C, nv 30) | Guerrero | Leg. +10 | 1 | jefe | 15/16 → 5/16 | 4.2 → 4.0 | 615 → 503 | 142% → 127% |
| Laberinto Temporal (T3 C, nv 30) | Guerrero | Leg. +10 | 4 | comunes | 16/16 → 16/16 | 3.3 → 3.3 | 185 → 185 | 47% → 47% |
| Laberinto Temporal (T3 C, nv 30) | Guerrero | Leg. +10 | 4 | élite | 16/16 → 16/16 | 7.8 → 7.8 | 179 → 179 | 19% → 19% |
| Laberinto Temporal (T3 C, nv 30) | Guerrero | Leg. +10 | 4 | jefe | 16/16 → 16/16 | 14.4 → 14.4 | 347 → 347 | 85% → 83% |
| Laberinto Temporal (T3 C, nv 30) | Maga | Raro +2 | 1 | comunes | 16/16 → 16/16 | 8.0 → 16.8 | 30 → 15 | 111% → 60% |
| Laberinto Temporal (T3 C, nv 30) | Maga | Raro +2 | 1 | élite | 16/16 → 16/16 | 21.6 → 30.4 | 32 → 19 | 45% → 28% |
| Laberinto Temporal (T3 C, nv 30) | Maga | Raro +2 | 1 | jefe | 16/16 → 16/16 | 19.8 → 28.4 | 140 → 71 | 267% → 80% |
| Laberinto Temporal (T3 C, nv 30) | Maga | Raro +2 | 4 | comunes | 16/16 → 16/16 | 44.8 → 46.9 | 14 → 13 | 62% → 47% |
| Laberinto Temporal (T3 C, nv 30) | Maga | Raro +2 | 4 | élite | 16/16 → 16/16 | 73.3 → 96.2 | 18 → 13 | 29% → 17% |
| Laberinto Temporal (T3 C, nv 30) | Maga | Raro +2 | 4 | jefe | 16/16 → 16/16 | 79.3 → 81.4 | 71 → 69 | 117% → 96% |
| Laberinto Temporal (T3 C, nv 30) | Maga | Leg. +10 | 1 | comunes | 16/16 → 16/16 | 6.1 → 13.9 | 42 → 19 | 121% → 60% |
| Laberinto Temporal (T3 C, nv 30) | Maga | Leg. +10 | 1 | élite | 16/16 → 16/16 | 16.6 → 25.1 | 42 → 25 | 52% → 31% |
| Laberinto Temporal (T3 C, nv 30) | Maga | Leg. +10 | 1 | jefe | 14/16 → 14/16 | 14.6 → 14.1 | 223 → 235 | 321% → 354% |
| Laberinto Temporal (T3 C, nv 30) | Maga | Leg. +10 | 4 | comunes | 16/16 → 16/16 | 42.0 → 45.5 | 16 → 12 | 69% → 44% |
| Laberinto Temporal (T3 C, nv 30) | Maga | Leg. +10 | 4 | élite | 16/16 → 16/16 | 75.6 → 103.8 | 19 → 14 | 31% → 19% |
| Laberinto Temporal (T3 C, nv 30) | Maga | Leg. +10 | 4 | jefe | 16/16 → 16/16 | 62.6 → 54.9 | 101 → 118 | 173% → 207% |

### Lectura (antes)

- Solo, al nivel de la zona y con loot normal, los comunes mueren en 1-2
  acciones en **todas** las zonas, también en las C (meta § 1: 3-4).
- Un golpe saca más del 100% de un común y >100% de un jefe con la
  legendaria: el "matar de un golpe" sin combinar existe.
- A 4 jugadores casi no cambia nada (la vida ×2.35 se compensa con 4×
  las acciones); el grupo nunca pierde.
- Jefes solos: con Raro, casi nunca se ganan en las C (0/16); con la
  legendaria +10, sí (12-15/16). La legendaria pesa mucho más que el nivel.

### Después del paso 2 (afinidades y tope)

- El "mayor golpe" contra comunes baja a ~60% cuando no hay debilidad
  (Pradera guerrero 126% → 76%, Bosque maga 156% → 61%, Fortaleza maga
  leg. 148% → 60%) y los comunes pasan de 1 a 2 acciones en esos casos.
  Con debilidad (fuego contra bestias y arácnidos) sube: Bosque con
  legendaria 168% → 202%.
- Jefe al 15%: el Rey Limo solo con guerrero Raro pasa de 15/16 a 0/16
  (la IA del simulador no busca debilidades: el guerrero no tiene fuego
  ni electro); legendarias contra jefes de T3 bajan de 14-15/16 a 1-6/16.
  **A calibrar** en el paso 5 (curva por tramos) y con la IA de
  compañeros: hoy la primera zona solo con un guerrero no se puede ganar
  sin combinar. Opciones: tope de jefe 20-25% en el tramo 1, o subir la
  ventana de "sobrenivelado".
- La maga en el Laberinto (temporales: electro ×0.5, el resto normal)
  tarda el doble con la Raro (comunes 8 → 17 acciones).
- A 4 jugadores casi no cambia: la vida del grupo hace que el tope casi
  nunca entre. Eso lo resuelve § 3.3 (mitigación de grupo), no este paso.

### Después de los pasos 3-4 (Convergencias, área y quiebre)

Mismo test (`balance_measure_test.dart`), con dos cambios en el
simulador: la IA quiebra si hay un enemigo **Fisurado** (ULT cargada o la
habilidad con Quebrar de su kit, contra ese enemigo) y hay filas de
**grupo mixto** (Guerrero espada, Maga báculo, Tirador arco, Paladín
espada y escudo, Raro +2, 32 batallas): es el "grupo al azar" de § 5.
La IA sigue sin buscar debilidades ni preparar Convergencias (usa la 1.ª
habilidad del arma: Corte Giratorio del guerrero es de área y ahora pega
×0.6). Columnas nuevas: *Quiebres* por batalla y *Jefe quebrado antes de
su ULT* (batallas en las que un jefe con ULT se quiebra antes de lanzar
la primera; meta § 5: < 10% con grupo al azar).
| Zona | Clase | Loot | Jug. | Pelea | Victorias | Acciones | Acc./jug. | Daño/acción | Mayor golpe | Quiebres | Jefe quebrado antes de su ULT |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Pradera Esmeralda (T1 A, nv 1) | Guerrero | Raro +2 | 1 | comunes | 16/16 | 2.6 | 2.6 | 26 | 64% | 0.0 | — |
| Pradera Esmeralda (T1 A, nv 1) | Guerrero | Raro +2 | 1 | élite | 15/16 | 3.8 | 3.8 | 19 | 45% | 0.0 | — |
| Pradera Esmeralda (T1 A, nv 1) | Guerrero | Raro +2 | 1 | jefe | 0/16 | 0.0 | 0.0 | 36 | 55% | 0.0 | 0/16 (0%) |
| Pradera Esmeralda (T1 A, nv 1) | Guerrero | Raro +2 | 4 | comunes | 16/16 | 5.5 | 1.4 | 26 | 34% | 0.1 | — |
| Pradera Esmeralda (T1 A, nv 1) | Guerrero | Raro +2 | 4 | élite | 16/16 | 9.0 | 2.3 | 16 | 19% | 0.0 | — |
| Pradera Esmeralda (T1 A, nv 1) | Guerrero | Raro +2 | 4 | jefe | 16/16 | 26.1 | 6.5 | 28 | 28% | 0.3 | 0/16 (0%) |
| Pradera Esmeralda (T1 A, nv 1) | Maga | Raro +2 | 1 | comunes | 16/16 | 2.0 | 2.0 | 48 | 218% | 0.0 | — |
| Pradera Esmeralda (T1 A, nv 1) | Maga | Raro +2 | 1 | élite | 16/16 | 1.9 | 1.9 | 48 | 88% | 0.0 | — |
| Pradera Esmeralda (T1 A, nv 1) | Maga | Raro +2 | 1 | jefe | 3/16 | 4.0 | 4.0 | 62 | 71% | 0.0 | 0/16 (0%) |
| Pradera Esmeralda (T1 A, nv 1) | Maga | Raro +2 | 4 | comunes | 16/16 | 3.9 | 1.0 | 50 | 103% | 0.0 | — |
| Pradera Esmeralda (T1 A, nv 1) | Maga | Raro +2 | 4 | élite | 16/16 | 2.8 | 0.7 | 49 | 40% | 0.0 | — |
| Pradera Esmeralda (T1 A, nv 1) | Maga | Raro +2 | 4 | jefe | 16/16 | 14.3 | 3.6 | 48 | 76% | 0.0 | 0/16 (0%) |
| Bosque Hondo (T1 C, nv 10) | Guerrero | Raro +2 | 1 | comunes | 16/16 | 2.0 | 2.0 | 41 | 61% | 0.0 | — |
| Bosque Hondo (T1 C, nv 10) | Guerrero | Raro +2 | 1 | élite | 16/16 | 3.0 | 3.0 | 78 | 45% | 0.0 | — |
| Bosque Hondo (T1 C, nv 10) | Guerrero | Raro +2 | 1 | jefe | 0/16 | 0.0 | 0.0 | 91 | 22% | 0.0 | 0/16 (0%) |
| Bosque Hondo (T1 C, nv 10) | Guerrero | Raro +2 | 4 | comunes | 16/16 | 2.6 | 0.6 | 81 | 54% | 0.0 | — |
| Bosque Hondo (T1 C, nv 10) | Guerrero | Raro +2 | 4 | élite | 16/16 | 5.4 | 1.4 | 86 | 26% | 0.0 | — |
| Bosque Hondo (T1 C, nv 10) | Guerrero | Raro +2 | 4 | jefe | 16/16 | 18.6 | 4.6 | 84 | 60% | 0.0 | 0/16 (0%) |
| Bosque Hondo (T1 C, nv 10) | Guerrero | Leg. +10 | 1 | comunes | 16/16 | 1.0 | 1.0 | 81 | 121% | 0.0 | — |
| Bosque Hondo (T1 C, nv 10) | Guerrero | Leg. +10 | 1 | élite | 16/16 | 2.0 | 2.0 | 82 | 52% | 0.0 | — |
| Bosque Hondo (T1 C, nv 10) | Guerrero | Leg. +10 | 1 | jefe | 11/16 | 4.5 | 4.5 | 173 | 126% | 0.0 | 0/16 (0%) |
| Bosque Hondo (T1 C, nv 10) | Guerrero | Leg. +10 | 4 | comunes | 16/16 | 2.3 | 0.6 | 81 | 60% | 0.0 | — |
| Bosque Hondo (T1 C, nv 10) | Guerrero | Leg. +10 | 4 | élite | 16/16 | 4.0 | 1.0 | 82 | 24% | 0.0 | — |
| Bosque Hondo (T1 C, nv 10) | Guerrero | Leg. +10 | 4 | jefe | 16/16 | 10.2 | 2.5 | 117 | 55% | 0.0 | 0/16 (0%) |
| Bosque Hondo (T1 C, nv 10) | Maga | Raro +2 | 1 | comunes | 16/16 | 2.0 | 2.0 | 41 | 61% | 0.0 | — |
| Bosque Hondo (T1 C, nv 10) | Maga | Raro +2 | 1 | élite | 12/16 | 3.0 | 3.0 | 78 | 45% | 0.0 | — |
| Bosque Hondo (T1 C, nv 10) | Maga | Raro +2 | 1 | jefe | 0/16 | 0.0 | 0.0 | 121 | 48% | 0.0 | 0/16 (0%) |
| Bosque Hondo (T1 C, nv 10) | Maga | Raro +2 | 4 | comunes | 16/16 | 2.0 | 0.5 | 95 | 60% | 0.0 | — |
| Bosque Hondo (T1 C, nv 10) | Maga | Raro +2 | 4 | élite | 16/16 | 4.7 | 1.2 | 104 | 28% | 0.0 | — |
| Bosque Hondo (T1 C, nv 10) | Maga | Raro +2 | 4 | jefe | 16/16 | 14.9 | 3.7 | 105 | 60% | 0.0 | 0/16 (0%) |
| Bosque Hondo (T1 C, nv 10) | Maga | Leg. +10 | 1 | comunes | 16/16 | 1.0 | 1.0 | 203 | 304% | 0.0 | — |
| Bosque Hondo (T1 C, nv 10) | Maga | Leg. +10 | 1 | élite | 16/16 | 1.0 | 1.0 | 203 | 116% | 0.0 | — |
| Bosque Hondo (T1 C, nv 10) | Maga | Leg. +10 | 1 | jefe | 12/16 | 2.8 | 2.8 | 281 | 253% | 0.0 | 0/16 (0%) |
| Bosque Hondo (T1 C, nv 10) | Maga | Leg. +10 | 4 | comunes | 16/16 | 1.0 | 0.3 | 227 | 143% | 0.0 | — |
| Bosque Hondo (T1 C, nv 10) | Maga | Leg. +10 | 4 | élite | 16/16 | 2.1 | 0.5 | 213 | 58% | 0.0 | — |
| Bosque Hondo (T1 C, nv 10) | Maga | Leg. +10 | 4 | jefe | 16/16 | 7.3 | 1.8 | 204 | 128% | 0.0 | 0/16 (0%) |
| Fortaleza Caída (T3 A, nv 21) | Guerrero | Raro +2 | 1 | comunes | 16/16 | 4.8 | 4.8 | 48 | 33% | 0.8 | — |
| Fortaleza Caída (T3 A, nv 21) | Guerrero | Raro +2 | 1 | élite | 7/16 | 8.1 | 8.1 | 65 | 38% | 0.3 | — |
| Fortaleza Caída (T3 A, nv 21) | Guerrero | Raro +2 | 1 | jefe | 0/16 | 0.0 | 0.0 | 157 | 50% | 0.0 | 0/16 (0%) |
| Fortaleza Caída (T3 A, nv 21) | Guerrero | Raro +2 | 4 | comunes | 16/16 | 10.7 | 2.7 | 46 | 14% | 1.0 | — |
| Fortaleza Caída (T3 A, nv 21) | Guerrero | Raro +2 | 4 | élite | 16/16 | 28.3 | 7.1 | 45 | 7% | 1.3 | — |
| Fortaleza Caída (T3 A, nv 21) | Guerrero | Raro +2 | 4 | jefe | 16/16 | 54.2 | 13.5 | 67 | 26% | 1.3 | 0/16 (0%) |
| Fortaleza Caída (T3 A, nv 21) | Guerrero | Leg. +10 | 1 | comunes | 16/16 | 3.1 | 3.1 | 74 | 46% | 0.1 | — |
| Fortaleza Caída (T3 A, nv 21) | Guerrero | Leg. +10 | 1 | élite | 14/16 | 5.4 | 5.4 | 109 | 45% | 0.0 | — |
| Fortaleza Caída (T3 A, nv 21) | Guerrero | Leg. +10 | 1 | jefe | 0/16 | 0.0 | 0.0 | 179 | 59% | 0.0 | 0/16 (0%) |
| Fortaleza Caída (T3 A, nv 21) | Guerrero | Leg. +10 | 4 | comunes | 16/16 | 7.3 | 1.8 | 74 | 25% | 0.6 | — |
| Fortaleza Caída (T3 A, nv 21) | Guerrero | Leg. +10 | 4 | élite | 16/16 | 16.3 | 4.1 | 78 | 11% | 1.0 | — |
| Fortaleza Caída (T3 A, nv 21) | Guerrero | Leg. +10 | 4 | jefe | 16/16 | 37.0 | 9.3 | 101 | 35% | 0.0 | 0/16 (0%) |
| Fortaleza Caída (T3 A, nv 21) | Maga | Raro +2 | 1 | comunes | 16/16 | 2.0 | 2.0 | 118 | 59% | 0.0 | — |
| Fortaleza Caída (T3 A, nv 21) | Maga | Raro +2 | 1 | élite | 13/16 | 4.2 | 4.2 | 153 | 46% | 0.0 | — |
| Fortaleza Caída (T3 A, nv 21) | Maga | Raro +2 | 1 | jefe | 0/16 | 0.0 | 0.0 | 217 | 55% | 0.0 | 0/16 (0%) |
| Fortaleza Caída (T3 A, nv 21) | Maga | Raro +2 | 4 | comunes | 16/16 | 3.9 | 1.0 | 129 | 32% | 0.0 | — |
| Fortaleza Caída (T3 A, nv 21) | Maga | Raro +2 | 4 | élite | 16/16 | 10.1 | 2.5 | 129 | 15% | 0.0 | — |
| Fortaleza Caída (T3 A, nv 21) | Maga | Raro +2 | 4 | jefe | 16/16 | 23.4 | 5.8 | 154 | 119% | 0.0 | 0/16 (0%) |
| Fortaleza Caída (T3 A, nv 21) | Maga | Leg. +10 | 1 | comunes | 16/16 | 2.0 | 2.0 | 120 | 60% | 0.0 | — |
| Fortaleza Caída (T3 A, nv 21) | Maga | Leg. +10 | 1 | élite | 16/16 | 3.0 | 3.0 | 234 | 45% | 0.0 | — |
| Fortaleza Caída (T3 A, nv 21) | Maga | Leg. +10 | 1 | jefe | 0/16 | 0.0 | 0.0 | 371 | 135% | 0.0 | 0/16 (0%) |
| Fortaleza Caída (T3 A, nv 21) | Maga | Leg. +10 | 4 | comunes | 16/16 | 2.0 | 0.5 | 254 | 56% | 0.0 | — |
| Fortaleza Caída (T3 A, nv 21) | Maga | Leg. +10 | 4 | élite | 16/16 | 4.9 | 1.2 | 284 | 30% | 0.0 | — |
| Fortaleza Caída (T3 A, nv 21) | Maga | Leg. +10 | 4 | jefe | 16/16 | 11.1 | 2.8 | 339 | 76% | 0.0 | 0/16 (0%) |
| Laberinto Temporal (T3 C, nv 30) | Guerrero | Raro +2 | 1 | comunes | 16/16 | 2.9 | 2.9 | 198 | 184% | 0.9 | — |
| Laberinto Temporal (T3 C, nv 30) | Guerrero | Raro +2 | 1 | élite | 16/16 | 3.0 | 3.0 | 190 | 45% | 0.0 | — |
| Laberinto Temporal (T3 C, nv 30) | Guerrero | Raro +2 | 1 | jefe | 0/16 | 0.0 | 0.0 | 446 | 38% | 0.0 | 0/16 (0%) |
| Laberinto Temporal (T3 C, nv 30) | Guerrero | Raro +2 | 4 | comunes | 16/16 | 2.0 | 0.5 | 267 | 55% | 0.0 | — |
| Laberinto Temporal (T3 C, nv 30) | Guerrero | Raro +2 | 4 | élite | 16/16 | 5.6 | 1.4 | 274 | 30% | 1.0 | — |
| Laberinto Temporal (T3 C, nv 30) | Guerrero | Raro +2 | 4 | jefe | 16/16 | 9.3 | 2.3 | 465 | 156% | 0.0 | 0/16 (0%) |
| Laberinto Temporal (T3 C, nv 30) | Guerrero | Leg. +10 | 1 | comunes | 16/16 | 2.6 | 2.6 | 94 | 48% | 0.0 | — |
| Laberinto Temporal (T3 C, nv 30) | Guerrero | Leg. +10 | 1 | élite | 16/16 | 5.3 | 5.3 | 132 | 50% | 0.3 | — |
| Laberinto Temporal (T3 C, nv 30) | Guerrero | Leg. +10 | 1 | jefe | 0/16 | 0.0 | 0.0 | 309 | 60% | 0.0 | 0/16 (0%) |
| Laberinto Temporal (T3 C, nv 30) | Guerrero | Leg. +10 | 4 | comunes | 16/16 | 5.5 | 1.4 | 102 | 30% | 0.9 | — |
| Laberinto Temporal (T3 C, nv 30) | Guerrero | Leg. +10 | 4 | élite | 16/16 | 13.0 | 3.3 | 105 | 14% | 1.0 | — |
| Laberinto Temporal (T3 C, nv 30) | Guerrero | Leg. +10 | 4 | jefe | 16/16 | 22.8 | 5.7 | 242 | 46% | 0.0 | 0/16 (0%) |
| Laberinto Temporal (T3 C, nv 30) | Maga | Raro +2 | 1 | comunes | 16/16 | 15.1 | 15.1 | 18 | 60% | 0.4 | — |
| Laberinto Temporal (T3 C, nv 30) | Maga | Raro +2 | 1 | élite | 16/16 | 20.9 | 20.9 | 25 | 29% | 0.8 | — |
| Laberinto Temporal (T3 C, nv 30) | Maga | Raro +2 | 1 | jefe | 1/16 | 13.0 | 13.0 | 214 | 60% | 0.0 | 0/16 (0%) |
| Laberinto Temporal (T3 C, nv 30) | Maga | Raro +2 | 4 | comunes | 16/16 | 48.1 | 12.0 | 12 | 42% | 0.8 | — |
| Laberinto Temporal (T3 C, nv 30) | Maga | Raro +2 | 4 | élite | 16/16 | 93.9 | 23.5 | 13 | 15% | 0.9 | — |
| Laberinto Temporal (T3 C, nv 30) | Maga | Raro +2 | 4 | jefe | 16/16 | 60.1 | 15.0 | 101 | 60% | 0.0 | 0/16 (0%) |
| Laberinto Temporal (T3 C, nv 30) | Maga | Leg. +10 | 1 | comunes | 16/16 | 13.6 | 13.6 | 24 | 60% | 1.0 | — |
| Laberinto Temporal (T3 C, nv 30) | Maga | Leg. +10 | 1 | élite | 16/16 | 19.2 | 19.2 | 32 | 34% | 1.1 | — |
| Laberinto Temporal (T3 C, nv 30) | Maga | Leg. +10 | 1 | jefe | 14/16 | 12.4 | 12.4 | 259 | 360% | 0.0 | 0/16 (0%) |
| Laberinto Temporal (T3 C, nv 30) | Maga | Leg. +10 | 4 | comunes | 16/16 | 42.5 | 10.6 | 14 | 43% | 1.4 | — |
| Laberinto Temporal (T3 C, nv 30) | Maga | Leg. +10 | 4 | élite | 16/16 | 91.1 | 22.8 | 15 | 17% | 2.1 | — |
| Laberinto Temporal (T3 C, nv 30) | Maga | Leg. +10 | 4 | jefe | 16/16 | 50.6 | 12.7 | 135 | 184% | 0.1 | 0/16 (0%) |
| Pradera Esmeralda (T1 A, nv 1) | Mixto | Raro +2 | 4 | comunes | 32/32 | 6.0 | 1.5 | 26 | 99% | 0.0 | — |
| Pradera Esmeralda (T1 A, nv 1) | Mixto | Raro +2 | 4 | élite | 32/32 | 5.2 | 1.3 | 24 | 42% | 0.0 | — |
| Pradera Esmeralda (T1 A, nv 1) | Mixto | Raro +2 | 4 | jefe | 32/32 | 14.3 | 3.6 | 49 | 32% | 0.0 | 0/32 (0%) |
| Bosque Hondo (T1 C, nv 10) | Mixto | Raro +2 | 4 | comunes | 32/32 | 1.6 | 0.4 | 140 | 109% | 0.0 | — |
| Bosque Hondo (T1 C, nv 10) | Mixto | Raro +2 | 4 | élite | 32/32 | 3.7 | 0.9 | 120 | 45% | 0.0 | — |
| Bosque Hondo (T1 C, nv 10) | Mixto | Raro +2 | 4 | jefe | 32/32 | 13.1 | 3.3 | 125 | 108% | 0.0 | 0/32 (0%) |
| Fortaleza Caída (T3 A, nv 21) | Mixto | Raro +2 | 4 | comunes | 32/32 | 6.1 | 1.5 | 86 | 33% | 0.3 | — |
| Fortaleza Caída (T3 A, nv 21) | Mixto | Raro +2 | 4 | élite | 32/32 | 15.3 | 3.8 | 85 | 15% | 0.7 | — |
| Fortaleza Caída (T3 A, nv 21) | Mixto | Raro +2 | 4 | jefe | 32/32 | 44.3 | 11.1 | 83 | 37% | 0.0 | 0/32 (0%) |
| Laberinto Temporal (T3 C, nv 30) | Mixto | Raro +2 | 4 | comunes | 32/32 | 2.8 | 0.7 | 233 | 80% | 0.0 | — |
| Laberinto Temporal (T3 C, nv 30) | Mixto | Raro +2 | 4 | élite | 32/32 | 7.3 | 1.8 | 211 | 36% | 0.8 | — |
| Laberinto Temporal (T3 C, nv 30) | Mixto | Raro +2 | 4 | jefe | 32/32 | 21.6 | 5.4 | 203 | 111% | 0.1 | 3/32 (9%) |

#### Lectura

- **Meta de quiebre cumplida:** con los umbrales de jefe en 65-95, el
  grupo mixto quiebra al jefe antes de su primera ULT 0% en T1 A, T1 C y
  T3 A, y 9% (3/32) en T3 C (Hechicera). Con los 40-60 del spec era 100%
  en T1 A y T3 C. 4 copias del mismo personaje: 0% en todas las filas.
- Quiebres por batalla: 0-1.4 contra comunes (12 × grupo), 0-2 contra
  élites; los jefes casi no se quiebran con la IA simple (no encadena ni
  busca debilidades): el quiebre de jefe queda para builds de quiebre.
- **El ajuste del tope de jefe (A) no recupera al guerrero solo contra el
  Rey Limo** (sigue 0/16). Se probó con tope de jefe 25%, 35% y sin
  tope: 0/16 en los tres. La causa ahora es otra: sin el quiebre por
  daño, el guerrero solo ya no quiebra al jefe ni le cancela el Diluvio
  Ácido, la pelea dura ~10 acciones y con 74 de vida no la aguanta (la
  IA no cura ni defiende). Antes del paso 2 ganaba con golpes de más del
  100% (ULT crítica). Queda **a calibrar** en el paso 5 (curva y vida
  del grupo) o con la IA de compañeros.
- Área ×0.6: el guerrero (Corte Giratorio) pierde daño por acción en
  todas las filas (Pradera solo 34 → 26); los comunes de T1 pasan de 2.0
  a 2.6 acciones.
- Las Convergencias no aparecen en la medición porque la IA no las
  prepara; sus números están cubiertos por `combo_break_test.dart`.