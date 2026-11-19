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

**Implementado (v0.9, paso 5):**
- `CurveDef` (lib/game_engine/data/zone_curve.dart), editable en el admin
  (`BalanceKind.curve`, balance_admin.md § v0.9). `ZoneRules.hpScale`,
  `atkScale`, `tramoPart`, `isZoneC` y `scaleBattle` la usan.
- **A, B y C por nivel**, no por zona: posición `p = (nivel − 1) % 10`;
  A si `p < 3` (1-3), B si `p < 6` (4-6), C el resto (7-10); igual en
  cada tramo (11-13 / 14-16 / 17-20…). Como las zonas son de 5 niveles
  (worldgen.md § 6.3), la **primera zona de cada tramo es A/B** (Pradera,
  Ruinas, Fortaleza, Grieta, Abismo) y la **segunda es C** (Bosque,
  Cavernas, Laberinto, Cementerio, Corazón): sus pisos 1+ y el jefe están
  en C; el piso 0 del Laberinto (26), del Cementerio (36) y del Corazón
  (46) quedan en B.
- Vida: `hpScale(n) = 1 + Σ pendiente(l)` para `l = 2..n`, con +0.10 si
  `l` cae en A/B y +0.22 si cae en C (relativo a la vida del catálogo,
  como antes). Al final de cada tramo queda en ~+1.48 por tramo, casi lo
  mismo que el 0.15 × 10 viejo: el serrucho cambia la forma dentro del
  tramo, no el total. Se sigue dividiendo por `hpScale(nivel nativo)`.
- ATQ: +8%/nivel parejo (como antes). Comunes en un nivel C: +15% de ATQ
  (`commonAtkC`; élites y jefes no; los escoltas del jefe son comunes).
- Élites en C: además del guardián de cada piso (y el del objetivo
  `elite`), los pisos C suman élites hasta `élites ≥ comunes / 2` (1 de
  cada 3 grupos, `eliteEveryC`). Se agregan con su propio azar
  (`seed + 29`) para no mover las tiradas de siempre y no reemplazan
  comunes (el objetivo de bajas no cambia).
 no se adelanta a la zona

- Todo lo que cae tiene nivel de objeto ≤ nivel **tope** de la zona.
- En las legendarias, los mods fijos escalan con el nivel del objeto,
  igual que los aleatorios (hoy hay que confirmarlo en el código).
- Tope de forja por nivel del objeto: una legendaria de nivel 5 no llega
  a +10, sino a `min(tope de rareza, 2 + nivel/5)`.
- Así una legendaria se siente enorme en su tramo y en el siguiente ya la
  pasa el loot nuevo, como en Divinity.

**Implementado (v0.9, paso 6):**
- `LootRules.itemLevelFor(…, cap:)` y `rollDrops(levelCap:)`: la sesión
  pasa el nivel tope de la zona (`ZoneDef.maxLevel`; en el Abismo, su
  nivel) a todas las tiradas: batallas, cofres, misiones opcionales,
  extras del Eco y el legendario del jefe. El +1 de élites y +2 de jefes
  ya no pasa el tope (antes el jefe de la Pradera soltaba nivel 7).
- **Mods fijos (confirmado: antes no escalaban).** `generateUnique`
  tiraba el rango del catálogo a cualquier nivel (Juramento del Alba de
  nivel 10 con +20-30% ATQ, cuando lo mejor aleatorio era +9%). Ahora
  `ItemRules.fixedRangeAt(mod, nivel)`: el rango del catálogo es el de
  nivel alto (T1) y se multiplica por `máx(T(n−1)) / máx(T1)`, donde `Tn`
  es el mejor tier aleatorio que sale a ese nivel: **un tier por encima
  de los aleatorios** (`legendaryTierBonus = 1`). Feroz 20-30 → 8-12 a
  nivel 1-9, 12-18 a 10-19, 16-24 a 20-29, completo desde 30. Nunca baja
  de 1 (Abrasador 1 sigue en 1). Lo usan la generación y la Esquirla;
  la Esencia sigue sin bajar nunca el valor. `sanitize` acepta del piso
  escalado al techo del catálogo: los legendarios viejos no se recortan
  (eso es la migración, § 6b).
- Tope de forja: `ItemRules.forgeCapOf(item)` = `min(tope de rareza,
  2 + nivel / 5)` (función pura, para reutilizar en la migración).
  `CraftRules.forge` lo usa ("Tope de forja (N)") y la UI de forja lo
  muestra (`Forja +1/4`). Las armas ya forjadas por encima no se tocan
  todavía (paso 8).

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

**Implementado (v0.9, paso 5):**
- Vida: `BattleEngine.start` usa `CurveDef.groupHp` = `0.6 + 0.3 ×
  jugadores` (solo ×0.9, 4 → ×1.8). El umbral de quiebre ya usaba la
  misma fórmula (`ComboRulesDef.groupBreak`, § 5): verificado.
- Mitigación en `dmgEnemy` (golpes del grupo a un enemigo, primarios y
  secundarios que pasan por ahí, incluido el ATQ plano): `× (1 − 0.08 ×
  (jugadores − 1))` y, si el enemigo es de un nivel C, `× 0.9`. Se
  multiplican (4 jugadores en C: × 0.684). Va antes del tope por golpe.
  Log: `… × 0.76 grupo (4 jug.) × 0.9 zona C`. **No** se mitigan: los
  golpes que detonan una reacción, las Convergencias (no pasan por
  `dmgEnemy`), ticks, ni el daño secundario de mecánicas
  (`_procDamage`: rebotes, ecos de pasivas).
- **Fuera del spec:** el −10% de zona C vale también solo (es la
  "resistencia que sube en C" de § 1); la ULT enemiga carga por vida
  perdida como si no hubiera mitigación (si no, el grupo llegaba a más
  turnos antes de la primera ULT).
- **Jefe en solitario (ajuste del paso 5, fuera del spec):** con un solo
  jugador, el jefe pelea **sin escolta** (`soloEscorts = 0`; las
  invocaciones de su mecánica siguen, con su `soloAdds`) y con vida ×1.2
  (`soloBossHp`; ATQ `soloBossAtk = 1`). Ver "Después de los pasos 5-6".
  Efecto lateral: solo, el jefe da la XP y los créditos de él solo (sin
  los de la escolta).

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
5. Curva por tramos y grupo (§ 1, § 3.3). **Hecho.**
6. Loot atado a la zona (§ 2). **Hecho.**
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

### Después de los pasos 5-6 (curva, grupo y loot)

Mismo test, con estos cambios:
- **IA del simulador** (`ImpactSimulator.simulate`): entra con 3 pociones
  (`SimLoadout.potions`, las del perfil nuevo) y toma una con menos del
  40% de vida (`potionAt`); si un enemigo avisó su ULT y le queda menos
  del 50% de vida, se defiende una vez (`defendBelow`). Defender siempre
  que avisa empeoraba al guerrero contra el Rey Limo (30/32 sin defender
  → 11/32 defendiendo siempre): pierde un turno de daño y la pelea se
  alarga. Sigue sin buscar debilidades ni preparar Convergencias.
- **Legendaria:** forjada hasta el tope por nivel de objeto (`Leg. +N`:
  +4 a nivel 10, +6 a 21, +8 a 30; antes +10) y con los mods fijos
  escalados (§ 2).
- Jefes en solitario: sin escolta y vida ×1.2 (§ 3.3).

| Zona | Clase | Loot | Jug. | Pelea | Victorias | Acciones | Acc./jug. | Daño/acción | Mayor golpe | Quiebres | Jefe quebrado antes de su ULT |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Pradera Esmeralda (T1 A, nv 1) | Guerrero | Raro +2 | 1 | comunes | 16/16 | 2.0 | 2.0 | 27 | 61% | 0.0 | — |
| Pradera Esmeralda (T1 A, nv 1) | Guerrero | Raro +2 | 1 | élite | 16/16 | 3.6 | 3.6 | 15 | 45% | 0.0 | — |
| Pradera Esmeralda (T1 A, nv 1) | Guerrero | Raro +2 | 1 | jefe | 11/16 | 13.5 | 13.5 | 19 | 25% | 0.0 | 0/16 (0%) |
| Pradera Esmeralda (T1 A, nv 1) | Guerrero | Raro +2 | 4 | comunes | 16/16 | 5.5 | 1.4 | 19 | 33% | 0.1 | — |
| Pradera Esmeralda (T1 A, nv 1) | Guerrero | Raro +2 | 4 | élite | 16/16 | 9.4 | 2.3 | 12 | 18% | 0.0 | — |
| Pradera Esmeralda (T1 A, nv 1) | Guerrero | Raro +2 | 4 | jefe | 16/16 | 28.6 | 7.2 | 19 | 28% | 0.3 | 0/16 (0%) |
| Pradera Esmeralda (T1 A, nv 1) | Maga | Raro +2 | 1 | comunes | 16/16 | 2.0 | 2.0 | 48 | 240% | 0.0 | — |
| Pradera Esmeralda (T1 A, nv 1) | Maga | Raro +2 | 1 | élite | 16/16 | 1.6 | 1.6 | 48 | 96% | 0.0 | — |
| Pradera Esmeralda (T1 A, nv 1) | Maga | Raro +2 | 1 | jefe | 16/16 | 5.9 | 5.9 | 45 | 30% | 0.0 | 0/16 (0%) |
| Pradera Esmeralda (T1 A, nv 1) | Maga | Raro +2 | 4 | comunes | 16/16 | 3.9 | 1.0 | 38 | 102% | 0.0 | — |
| Pradera Esmeralda (T1 A, nv 1) | Maga | Raro +2 | 4 | élite | 16/16 | 2.8 | 0.7 | 37 | 40% | 0.0 | — |
| Pradera Esmeralda (T1 A, nv 1) | Maga | Raro +2 | 4 | jefe | 16/16 | 14.2 | 3.5 | 36 | 81% | 0.0 | 0/16 (0%) |
| Bosque Hondo (T1 C, nv 10) | Guerrero | Raro +2 | 1 | comunes | 16/16 | 2.0 | 2.0 | 43 | 61% | 0.0 | — |
| Bosque Hondo (T1 C, nv 10) | Guerrero | Raro +2 | 1 | élite | 16/16 | 4.3 | 4.3 | 54 | 45% | 0.0 | — |
| Bosque Hondo (T1 C, nv 10) | Guerrero | Raro +2 | 1 | jefe | 14/16 | 8.5 | 8.5 | 65 | 24% | 0.0 | 0/16 (0%) |
| Bosque Hondo (T1 C, nv 10) | Guerrero | Raro +2 | 4 | comunes | 16/16 | 2.9 | 0.7 | 58 | 46% | 0.0 | — |
| Bosque Hondo (T1 C, nv 10) | Guerrero | Raro +2 | 4 | élite | 16/16 | 6.8 | 1.7 | 58 | 19% | 0.0 | — |
| Bosque Hondo (T1 C, nv 10) | Guerrero | Raro +2 | 4 | jefe | 16/16 | 24.9 | 6.2 | 51 | 60% | 0.0 | 0/16 (0%) |
| Bosque Hondo (T1 C, nv 10) | Guerrero | Leg. +4 | 1 | comunes | 16/16 | 1.9 | 1.9 | 49 | 70% | 0.0 | — |
| Bosque Hondo (T1 C, nv 10) | Guerrero | Leg. +4 | 1 | élite | 16/16 | 2.3 | 2.3 | 49 | 34% | 0.0 | — |
| Bosque Hondo (T1 C, nv 10) | Guerrero | Leg. +4 | 1 | jefe | 16/16 | 6.6 | 6.6 | 66 | 46% | 0.0 | 0/16 (0%) |
| Bosque Hondo (T1 C, nv 10) | Guerrero | Leg. +4 | 4 | comunes | 16/16 | 3.8 | 0.9 | 39 | 38% | 0.6 | — |
| Bosque Hondo (T1 C, nv 10) | Guerrero | Leg. +4 | 4 | élite | 16/16 | 5.5 | 1.4 | 40 | 13% | 0.0 | — |
| Bosque Hondo (T1 C, nv 10) | Guerrero | Leg. +4 | 4 | jefe | 16/16 | 13.8 | 3.4 | 55 | 34% | 1.3 | 0/16 (0%) |
| Bosque Hondo (T1 C, nv 10) | Maga | Raro +2 | 1 | comunes | 16/16 | 2.0 | 2.0 | 43 | 61% | 0.0 | — |
| Bosque Hondo (T1 C, nv 10) | Maga | Raro +2 | 1 | élite | 12/16 | 4.8 | 4.8 | 53 | 45% | 0.0 | — |
| Bosque Hondo (T1 C, nv 10) | Maga | Raro +2 | 1 | jefe | 14/16 | 7.9 | 7.9 | 69 | 22% | 0.0 | 0/16 (0%) |
| Bosque Hondo (T1 C, nv 10) | Maga | Raro +2 | 4 | comunes | 16/16 | 2.8 | 0.7 | 71 | 51% | 0.0 | — |
| Bosque Hondo (T1 C, nv 10) | Maga | Raro +2 | 4 | élite | 16/16 | 5.7 | 1.4 | 74 | 23% | 0.0 | — |
| Bosque Hondo (T1 C, nv 10) | Maga | Raro +2 | 4 | jefe | 16/16 | 20.1 | 5.0 | 63 | 52% | 0.1 | 0/16 (0%) |
| Bosque Hondo (T1 C, nv 10) | Maga | Leg. +4 | 1 | comunes | 16/16 | 1.0 | 1.0 | 126 | 177% | 0.0 | — |
| Bosque Hondo (T1 C, nv 10) | Maga | Leg. +4 | 1 | élite | 16/16 | 1.8 | 1.8 | 131 | 74% | 0.0 | — |
| Bosque Hondo (T1 C, nv 10) | Maga | Leg. +4 | 1 | jefe | 16/16 | 3.0 | 3.0 | 130 | 28% | 0.0 | 0/16 (0%) |
| Bosque Hondo (T1 C, nv 10) | Maga | Leg. +4 | 4 | comunes | 16/16 | 2.0 | 0.5 | 98 | 73% | 0.0 | — |
| Bosque Hondo (T1 C, nv 10) | Maga | Leg. +4 | 4 | élite | 16/16 | 3.5 | 0.9 | 98 | 30% | 0.0 | — |
| Bosque Hondo (T1 C, nv 10) | Maga | Leg. +4 | 4 | jefe | 16/16 | 11.4 | 2.8 | 96 | 74% | 0.0 | 0/16 (0%) |
| Fortaleza Caída (T3 A, nv 21) | Guerrero | Raro +2 | 1 | comunes | 16/16 | 4.6 | 4.6 | 47 | 33% | 0.8 | — |
| Fortaleza Caída (T3 A, nv 21) | Guerrero | Raro +2 | 1 | élite | 14/16 | 9.8 | 9.8 | 52 | 40% | 0.1 | — |
| Fortaleza Caída (T3 A, nv 21) | Guerrero | Raro +2 | 1 | jefe | 0/16 | 0.0 | 0.0 | 61 | 19% | 0.0 | 0/16 (0%) |
| Fortaleza Caída (T3 A, nv 21) | Guerrero | Raro +2 | 4 | comunes | 16/16 | 10.7 | 2.7 | 35 | 14% | 1.0 | — |
| Fortaleza Caída (T3 A, nv 21) | Guerrero | Raro +2 | 4 | élite | 16/16 | 28.3 | 7.1 | 34 | 6% | 1.3 | — |
| Fortaleza Caída (T3 A, nv 21) | Guerrero | Raro +2 | 4 | jefe | 16/16 | 61.4 | 15.4 | 45 | 25% | 1.0 | 0/16 (0%) |
| Fortaleza Caída (T3 A, nv 21) | Guerrero | Leg. +6 | 1 | comunes | 16/16 | 3.9 | 3.9 | 60 | 45% | 0.3 | — |
| Fortaleza Caída (T3 A, nv 21) | Guerrero | Leg. +6 | 1 | élite | 16/16 | 7.8 | 7.8 | 67 | 45% | 0.0 | — |
| Fortaleza Caída (T3 A, nv 21) | Guerrero | Leg. +6 | 1 | jefe | 0/16 | 0.0 | 0.0 | 67 | 14% | 0.0 | 0/16 (0%) |
| Fortaleza Caída (T3 A, nv 21) | Guerrero | Leg. +6 | 4 | comunes | 16/16 | 8.5 | 2.1 | 47 | 22% | 1.0 | — |
| Fortaleza Caída (T3 A, nv 21) | Guerrero | Leg. +6 | 4 | élite | 16/16 | 20.8 | 5.2 | 46 | 9% | 1.0 | — |
| Fortaleza Caída (T3 A, nv 21) | Guerrero | Leg. +6 | 4 | jefe | 16/16 | 45.4 | 11.4 | 63 | 30% | 0.0 | 0/16 (0%) |
| Fortaleza Caída (T3 A, nv 21) | Maga | Raro +2 | 1 | comunes | 16/16 | 2.0 | 2.0 | 108 | 60% | 0.0 | — |
| Fortaleza Caída (T3 A, nv 21) | Maga | Raro +2 | 1 | élite | 15/16 | 4.9 | 4.9 | 121 | 46% | 0.0 | — |
| Fortaleza Caída (T3 A, nv 21) | Maga | Raro +2 | 1 | jefe | 0/16 | 0.0 | 0.0 | 106 | 13% | 0.0 | 0/16 (0%) |
| Fortaleza Caída (T3 A, nv 21) | Maga | Raro +2 | 4 | comunes | 16/16 | 4.5 | 1.1 | 98 | 34% | 0.0 | — |
| Fortaleza Caída (T3 A, nv 21) | Maga | Raro +2 | 4 | élite | 16/16 | 10.1 | 2.5 | 97 | 15% | 0.0 | — |
| Fortaleza Caída (T3 A, nv 21) | Maga | Raro +2 | 4 | jefe | 16/16 | 28.5 | 7.1 | 97 | 118% | 0.0 | 0/16 (0%) |
| Fortaleza Caída (T3 A, nv 21) | Maga | Leg. +6 | 1 | comunes | 16/16 | 2.0 | 2.0 | 108 | 60% | 0.0 | — |
| Fortaleza Caída (T3 A, nv 21) | Maga | Leg. +6 | 1 | élite | 16/16 | 3.0 | 3.0 | 202 | 44% | 0.0 | — |
| Fortaleza Caída (T3 A, nv 21) | Maga | Leg. +6 | 1 | jefe | 5/16 | 9.0 | 9.0 | 147 | 23% | 0.0 | 0/16 (0%) |
| Fortaleza Caída (T3 A, nv 21) | Maga | Leg. +6 | 4 | comunes | 16/16 | 2.5 | 0.6 | 167 | 52% | 0.0 | — |
| Fortaleza Caída (T3 A, nv 21) | Maga | Leg. +6 | 4 | élite | 16/16 | 6.1 | 1.5 | 172 | 24% | 0.0 | — |
| Fortaleza Caída (T3 A, nv 21) | Maga | Leg. +6 | 4 | jefe | 16/16 | 14.2 | 3.5 | 206 | 65% | 0.0 | 0/16 (0%) |
| Laberinto Temporal (T3 C, nv 30) | Guerrero | Raro +2 | 1 | comunes | 16/16 | 2.9 | 2.9 | 180 | 173% | 0.9 | — |
| Laberinto Temporal (T3 C, nv 30) | Guerrero | Raro +2 | 1 | élite | 16/16 | 3.9 | 3.9 | 222 | 69% | 0.9 | — |
| Laberinto Temporal (T3 C, nv 30) | Guerrero | Raro +2 | 1 | jefe | 16/16 | 3.9 | 3.9 | 427 | 33% | 0.0 | 0/16 (0%) |
| Laberinto Temporal (T3 C, nv 30) | Guerrero | Raro +2 | 4 | comunes | 16/16 | 3.1 | 0.8 | 181 | 65% | 0.6 | — |
| Laberinto Temporal (T3 C, nv 30) | Guerrero | Raro +2 | 4 | élite | 16/16 | 6.0 | 1.5 | 195 | 26% | 1.0 | — |
| Laberinto Temporal (T3 C, nv 30) | Guerrero | Raro +2 | 4 | jefe | 16/16 | 11.2 | 2.8 | 307 | 131% | 0.9 | 15/16 (94%) |
| Laberinto Temporal (T3 C, nv 30) | Guerrero | Leg. +8 | 1 | comunes | 16/16 | 3.3 | 3.3 | 77 | 45% | 0.1 | — |
| Laberinto Temporal (T3 C, nv 30) | Guerrero | Leg. +8 | 1 | élite | 16/16 | 6.2 | 6.2 | 136 | 83% | 0.4 | — |
| Laberinto Temporal (T3 C, nv 30) | Guerrero | Leg. +8 | 1 | jefe | 0/16 | 0.0 | 0.0 | 122 | 50% | 0.0 | 0/16 (0%) |
| Laberinto Temporal (T3 C, nv 30) | Guerrero | Leg. +8 | 4 | comunes | 16/16 | 6.9 | 1.7 | 66 | 24% | 1.0 | — |
| Laberinto Temporal (T3 C, nv 30) | Guerrero | Leg. +8 | 4 | élite | 16/16 | 17.0 | 4.3 | 65 | 11% | 1.0 | — |
| Laberinto Temporal (T3 C, nv 30) | Guerrero | Leg. +8 | 4 | jefe | 16/16 | 28.7 | 7.2 | 149 | 38% | 0.0 | 0/16 (0%) |
| Laberinto Temporal (T3 C, nv 30) | Maga | Raro +2 | 1 | comunes | 16/16 | 14.8 | 14.8 | 18 | 60% | 0.8 | — |
| Laberinto Temporal (T3 C, nv 30) | Maga | Raro +2 | 1 | élite | 16/16 | 25.3 | 25.3 | 22 | 27% | 0.8 | — |
| Laberinto Temporal (T3 C, nv 30) | Maga | Raro +2 | 1 | jefe | 16/16 | 22.9 | 22.9 | 88 | 60% | 0.0 | 0/16 (0%) |
| Laberinto Temporal (T3 C, nv 30) | Maga | Raro +2 | 4 | comunes | 16/16 | 50.6 | 12.7 | 9 | 34% | 1.0 | — |
| Laberinto Temporal (T3 C, nv 30) | Maga | Raro +2 | 4 | élite | 16/16 | 104.1 | 26.0 | 9 | 13% | 1.1 | — |
| Laberinto Temporal (T3 C, nv 30) | Maga | Raro +2 | 4 | jefe | 16/16 | 67.4 | 16.8 | 67 | 60% | 0.1 | 0/16 (0%) |
| Laberinto Temporal (T3 C, nv 30) | Maga | Leg. +8 | 1 | comunes | 16/16 | 12.6 | 12.6 | 23 | 60% | 0.9 | — |
| Laberinto Temporal (T3 C, nv 30) | Maga | Leg. +8 | 1 | élite | 16/16 | 23.4 | 23.4 | 25 | 28% | 1.6 | — |
| Laberinto Temporal (T3 C, nv 30) | Maga | Leg. +8 | 1 | jefe | 16/16 | 18.3 | 18.3 | 137 | 210% | 0.0 | 0/16 (0%) |
| Laberinto Temporal (T3 C, nv 30) | Maga | Leg. +8 | 4 | comunes | 16/16 | 45.7 | 11.4 | 10 | 35% | 1.8 | — |
| Laberinto Temporal (T3 C, nv 30) | Maga | Leg. +8 | 4 | élite | 16/16 | 127.5 | 31.9 | 9 | 13% | 2.6 | — |
| Laberinto Temporal (T3 C, nv 30) | Maga | Leg. +8 | 4 | jefe | 16/16 | 53.9 | 13.5 | 91 | 151% | 0.3 | 0/16 (0%) |
| Pradera Esmeralda (T1 A, nv 1) | Mixto | Raro +2 | 4 | comunes | 32/32 | 6.1 | 1.5 | 23 | 130% | 0.0 | — |
| Pradera Esmeralda (T1 A, nv 1) | Mixto | Raro +2 | 4 | élite | 32/32 | 5.0 | 1.2 | 20 | 51% | 0.0 | — |
| Pradera Esmeralda (T1 A, nv 1) | Mixto | Raro +2 | 4 | jefe | 32/32 | 13.7 | 3.4 | 39 | 39% | 0.0 | 0/32 (0%) |
| Bosque Hondo (T1 C, nv 10) | Mixto | Raro +2 | 4 | comunes | 32/32 | 1.8 | 0.5 | 95 | 84% | 0.0 | — |
| Bosque Hondo (T1 C, nv 10) | Mixto | Raro +2 | 4 | élite | 32/32 | 4.7 | 1.2 | 91 | 41% | 0.0 | — |
| Bosque Hondo (T1 C, nv 10) | Mixto | Raro +2 | 4 | jefe | 32/32 | 13.8 | 3.5 | 92 | 93% | 0.0 | 0/32 (0%) |
| Fortaleza Caída (T3 A, nv 21) | Mixto | Raro +2 | 4 | comunes | 32/32 | 6.1 | 1.5 | 66 | 32% | 0.3 | — |
| Fortaleza Caída (T3 A, nv 21) | Mixto | Raro +2 | 4 | élite | 32/32 | 15.4 | 3.8 | 64 | 15% | 0.8 | — |
| Fortaleza Caída (T3 A, nv 21) | Mixto | Raro +2 | 4 | jefe | 32/32 | 44.2 | 11.0 | 63 | 37% | 0.0 | 0/32 (0%) |
| Laberinto Temporal (T3 C, nv 30) | Mixto | Raro +2 | 4 | comunes | 32/32 | 3.3 | 0.8 | 157 | 70% | 0.1 | — |
| Laberinto Temporal (T3 C, nv 30) | Mixto | Raro +2 | 4 | élite | 32/32 | 8.3 | 2.1 | 146 | 32% | 1.0 | — |
| Laberinto Temporal (T3 C, nv 30) | Mixto | Raro +2 | 4 | jefe | 32/32 | 23.4 | 5.9 | 144 | 94% | 0.8 | 21/32 (66%) |

#### Metas de § 1

| Meta | Resultado | ¿Se cumple? |
|---|---|---|
| A/B: comunes en 1-2 acciones (al nivel, loot normal) | Pradera: 2.0 (guerrero y maga). Fortaleza: maga 2.0; guerrero 4.6 (Raro) / 3.9 (Leg.) | Parcial: el guerrero con espada en T3 A tarda el doble (esqueletos: resisten el corte) |
| C: comunes en 3-4 acciones sin combos | Bosque: 2.0 (Raro), 1.9 / 1.0 (Leg.). Laberinto: guerrero 2.9 / 3.3; maga 14.8 / 12.6 | **No** en T1 C; sí el guerrero en T3 C; la maga en T3 C, de más |
| C a 4 jugadores sin combos: puede perder | 16/16 y 32/32 en todas las filas; el grupo termina con 63-100% de vida | **No** |
| Solo se avanza (jefes ganables) | Tramo 1: Rey Limo 11/16 (guerrero) y 16/16 (maga); Matriarca 14/16 y 14/16 (62-100%, promedio 86%). T3: Caballero Hueco 0/16 (salvo maga Leg. 5/16); Hechicera 16/16 con Raro, 0/16 guerrero Leg. | Sí en el tramo 1; **no** en T3 A (Caballero Hueco) |

#### Lectura

- **Rey Limo solo (problema abierto de los pasos 3-4): resuelto.** 0/16 →
  11/16 el guerrero, 16/16 la maga. Qué pesó (32 batallas, sondeo a
  mano): las pociones de la IA llevan al guerrero de 0/32 a 30/32 sin
  defender; la escolta era lo que mataba en la Matriarca (sin tocar
  nada, 0/32; con vida del jefe ×0.5 y ATQ ×0.7 pero con escolta, 0/32;
  sin escolta, 29-32/32). Con vida ×1.2 sin escolta queda 75-100% por
  pelea en el tramo 1 (el rango pedido era 60-80%: un poco arriba en la
  maga; subir `soloBossHp` a 1.35 baja al guerrero contra el Rey Limo a
  47%). A 4 jugadores el jefe sigue con su escolta: 16/16, 7.2
  acciones por jugador del guerrero contra el Rey Limo (antes 6.5).
- **C en 3-4 acciones: no se alcanza con la curva.** Contra comunes de C,
  el golpe del guerrero sin tope pasa el 100% de la vida (el "mayor
  golpe" es 61% = el tope del 60%): las 2 acciones las pone el tope, no
  la vida. Con la pendiente de C en 0.35 o 0.50 (vida de los comunes del
  Bosque ×1.3 / ×1.5) seguían en 2.0 acciones. Para 3-4 haría falta
  vida de los comunes de C ×2.5 o más, o un tope de común en C de 30-35%.
  Queda para decidir.
- **4 jugadores en C no pierden:** los comunes mueren antes de actuar
  (0.7-0.8 acciones por jugador) y élites y jefes no bajan del 60% de la
  vida del grupo. La mitigación (×0.684 en C) alarga las peleas
  (Laberinto, élite a 4: 5.6 → 6.0 acciones) pero el daño enemigo no
  alcanza. Haría falta subir el ATQ enemigo en C para grupos (no está en
  el spec).
- **Regresión de quiebre (meta de § 5) en la Hechicera:** quebrada antes
  de su primera ULT 15/16 con 4 guerreros (antes 0%) y 21/32 con el grupo
  mixto (antes 9%). Causa: Tajo Temporal (hielo, débil ×1.5, **retrasa**)
  la deja sin turno; con la mitigación la pelea dura más, la retrasan más
  veces y la barra se llena antes de que actúe. Sin la mitigación, 0/32.
  No se tocó: hay que decidir si el retraso tiene rendimiento decreciente
  o si sube el umbral de la Hechicera (80).
- Loot: la legendaria de nivel 10 rinde mucho menos que antes (Bosque,
  guerrero solo vs jefe: 173 → 66 de daño por acción; victorias 11/16 →
  16/16 por el ajuste del jefe solo) por la forja +4 y los fijos
  escalados. Queda apenas arriba del Raro +2 (66 vs 65 contra el jefe,
  49 vs 43 contra comunes): para que "se sienta enorme en su tramo" puede
  hacer falta `legendaryTierBonus = 2` (hecho en el ajuste de abajo).

### Ajuste de cierre (decisiones del dueño sobre los pasos 5-6)

Cambios (todos editables en el admin):
- **Retraso con rendimiento decreciente** (`curve.delayFalloff = 0.3`):
  cada retraso del grupo a un mismo enemigo desde su último turno rinde
  0.3 del anterior (1, 0.3, 0.09…); se reinicia cuando el enemigo actúa.
  Vale para el retraso de habilidades y de procs (`Combatant.delayStreak`,
  JSON `dlS`). El umbral de la Hechicera no se tocó.
- **Tope de común en zona C: 35%** (`hitCap.commonC`); A/B sigue en 60%.
- **ATQ enemigo por grupo:** +40% por jugador después del primero
  (`curve.groupAtkPer`, 4 → ×2.2), en `BattleEngine.start`. Con +10-30% el
  grupo no perdía nunca (los comunes morían antes de actuar).
- **Iniciativa en C:** con 2+ jugadores, en un nivel C el primer turno de
  los enemigos llega a ×0.2 de lo normal (`curve.groupInitiativeC`):
  actúan antes de que el grupo los barra.
- **Jefe en solitario:** vida ×1.0 y ATQ ×0.8 (`soloBossHp`,
  `soloBossAtk`), sin escolta. Con vida ×1.2 el Caballero Hueco solo
  quedaba en 0-1/16.
- `legendaryTierBonus = 2`: los fijos van 2 tiers sobre los aleatorios
  (Feroz 12-18 a nivel 1-9, 16-24 a 10-19, completo desde 20).
- Simulador: opción `combos` (detona una Convergencia si el objetivo tiene
  5+ stacks de su preparación; si no, usa una habilidad que pone
  Quemadura o Veneno). Con los kits base del grupo mixto casi no hay
  pares preparar/detonar, así que "+ combos" da casi lo mismo: **la
  medición con combos no es representativa** hasta que haya kits o IA de
  compañeros que combinen.
- Tabla: columna nueva *Vida al ganar* (del jugador 1).

| Zona | Clase | Loot | Jug. | Pelea | Victorias | Acciones | Acc./jug. | Daño/acción | Mayor golpe | Quiebres | Jefe quebrado antes de su ULT | Vida al ganar |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Pradera Esmeralda (T1 A, nv 1) | Guerrero | Raro +2 | 1 | comunes | 16/16 | 2.0 | 2.0 | 27 | 61% | 0.0 | — | 67% |
| Pradera Esmeralda (T1 A, nv 1) | Guerrero | Raro +2 | 1 | élite | 16/16 | 3.6 | 3.6 | 15 | 45% | 0.0 | — | 56% |
| Pradera Esmeralda (T1 A, nv 1) | Guerrero | Raro +2 | 1 | jefe | 16/16 | 12.3 | 12.3 | 18 | 25% | 0.0 | 0/16 (0%) | 52% |
| Pradera Esmeralda (T1 A, nv 1) | Guerrero | Raro +2 | 4 | comunes | 16/16 | 5.5 | 1.4 | 19 | 33% | 0.1 | — | 85% |
| Pradera Esmeralda (T1 A, nv 1) | Guerrero | Raro +2 | 4 | élite | 16/16 | 9.3 | 2.3 | 12 | 18% | 0.0 | — | 75% |
| Pradera Esmeralda (T1 A, nv 1) | Guerrero | Raro +2 | 4 | jefe | 16/16 | 27.1 | 6.8 | 20 | 28% | 0.3 | 0/16 (0%) | 40% |
| Pradera Esmeralda (T1 A, nv 1) | Maga | Raro +2 | 1 | comunes | 16/16 | 2.0 | 2.0 | 48 | 240% | 0.0 | — | 71% |
| Pradera Esmeralda (T1 A, nv 1) | Maga | Raro +2 | 1 | élite | 16/16 | 1.6 | 1.6 | 48 | 96% | 0.0 | — | 89% |
| Pradera Esmeralda (T1 A, nv 1) | Maga | Raro +2 | 1 | jefe | 16/16 | 4.1 | 4.1 | 48 | 28% | 0.0 | 0/16 (0%) | 56% |
| Pradera Esmeralda (T1 A, nv 1) | Maga | Raro +2 | 4 | comunes | 16/16 | 3.9 | 1.0 | 38 | 102% | 0.0 | — | 96% |
| Pradera Esmeralda (T1 A, nv 1) | Maga | Raro +2 | 4 | élite | 16/16 | 2.9 | 0.7 | 36 | 40% | 0.0 | — | 100% |
| Pradera Esmeralda (T1 A, nv 1) | Maga | Raro +2 | 4 | jefe | 16/16 | 15.3 | 3.8 | 33 | 84% | 0.0 | 0/16 (0%) | 68% |
| Bosque Hondo (T1 C, nv 10) | Guerrero | Raro +2 | 1 | comunes | 16/16 | 3.0 | 3.0 | 25 | 35% | 0.0 | — | 54% |
| Bosque Hondo (T1 C, nv 10) | Guerrero | Raro +2 | 1 | élite | 16/16 | 4.3 | 4.3 | 54 | 45% | 0.0 | — | 58% |
| Bosque Hondo (T1 C, nv 10) | Guerrero | Raro +2 | 1 | jefe | 16/16 | 6.9 | 6.9 | 70 | 25% | 0.0 | 0/16 (0%) | 52% |
| Bosque Hondo (T1 C, nv 10) | Guerrero | Raro +2 | 4 | comunes | 16/16 | 3.0 | 0.8 | 51 | 36% | 0.0 | — | 92% |
| Bosque Hondo (T1 C, nv 10) | Guerrero | Raro +2 | 4 | élite | 16/16 | 7.3 | 1.8 | 53 | 18% | 0.0 | — | 52% |
| Bosque Hondo (T1 C, nv 10) | Guerrero | Raro +2 | 4 | jefe | 0/16 | 0.0 | 0.0 | 39 | 10% | 0.0 | 0/16 (0%) | 0% |
| Bosque Hondo (T1 C, nv 10) | Guerrero | Leg. +4 | 1 | comunes | 16/16 | 1.9 | 1.9 | 50 | 71% | 0.0 | — | 68% |
| Bosque Hondo (T1 C, nv 10) | Guerrero | Leg. +4 | 1 | élite | 16/16 | 2.3 | 2.3 | 50 | 35% | 0.0 | — | 41% |
| Bosque Hondo (T1 C, nv 10) | Guerrero | Leg. +4 | 1 | jefe | 14/16 | 6.1 | 6.1 | 72 | 51% | 0.0 | 0/16 (0%) | 54% |
| Bosque Hondo (T1 C, nv 10) | Guerrero | Leg. +4 | 4 | comunes | 16/16 | 3.2 | 0.8 | 36 | 30% | 0.8 | — | 91% |
| Bosque Hondo (T1 C, nv 10) | Guerrero | Leg. +4 | 4 | élite | 16/16 | 5.9 | 1.5 | 37 | 12% | 0.0 | — | 59% |
| Bosque Hondo (T1 C, nv 10) | Guerrero | Leg. +4 | 4 | jefe | 16/16 | 16.4 | 4.1 | 49 | 31% | 1.6 | 0/16 (0%) | 58% |
| Bosque Hondo (T1 C, nv 10) | Maga | Raro +2 | 1 | comunes | 16/16 | 3.0 | 3.0 | 25 | 35% | 0.0 | — | 47% |
| Bosque Hondo (T1 C, nv 10) | Maga | Raro +2 | 1 | élite | 12/16 | 4.8 | 4.8 | 53 | 45% | 0.0 | — | 45% |
| Bosque Hondo (T1 C, nv 10) | Maga | Raro +2 | 1 | jefe | 16/16 | 5.6 | 5.6 | 80 | 23% | 0.0 | 0/16 (0%) | 57% |
| Bosque Hondo (T1 C, nv 10) | Maga | Raro +2 | 4 | comunes | 16/16 | 3.0 | 0.8 | 51 | 36% | 0.0 | — | 88% |
| Bosque Hondo (T1 C, nv 10) | Maga | Raro +2 | 4 | élite | 16/16 | 5.9 | 1.5 | 68 | 23% | 0.0 | — | 75% |
| Bosque Hondo (T1 C, nv 10) | Maga | Raro +2 | 4 | jefe | 0/16 | 0.0 | 0.0 | 52 | 17% | 0.0 | 0/16 (0%) | 0% |
| Bosque Hondo (T1 C, nv 10) | Maga | Leg. +4 | 1 | comunes | 16/16 | 1.0 | 1.0 | 130 | 183% | 0.0 | — | 86% |
| Bosque Hondo (T1 C, nv 10) | Maga | Leg. +4 | 1 | élite | 16/16 | 1.8 | 1.8 | 135 | 76% | 0.0 | — | 79% |
| Bosque Hondo (T1 C, nv 10) | Maga | Leg. +4 | 1 | jefe | 16/16 | 2.9 | 2.9 | 134 | 35% | 0.0 | 0/16 (0%) | 79% |
| Bosque Hondo (T1 C, nv 10) | Maga | Leg. +4 | 4 | comunes | 16/16 | 1.9 | 0.5 | 99 | 71% | 0.0 | — | 88% |
| Bosque Hondo (T1 C, nv 10) | Maga | Leg. +4 | 4 | élite | 16/16 | 3.8 | 0.9 | 94 | 32% | 0.0 | — | 88% |
| Bosque Hondo (T1 C, nv 10) | Maga | Leg. +4 | 4 | jefe | 12/16 | 13.9 | 3.5 | 76 | 63% | 0.0 | 0/16 (0%) | 56% |
| Fortaleza Caída (T3 A, nv 21) | Guerrero | Raro +2 | 1 | comunes | 16/16 | 4.6 | 4.6 | 47 | 33% | 0.8 | — | 80% |
| Fortaleza Caída (T3 A, nv 21) | Guerrero | Raro +2 | 1 | élite | 14/16 | 9.8 | 9.8 | 52 | 40% | 0.1 | — | 61% |
| Fortaleza Caída (T3 A, nv 21) | Guerrero | Raro +2 | 1 | jefe | 9/16 | 18.8 | 18.8 | 58 | 21% | 0.0 | 0/16 (0%) | 14% |
| Fortaleza Caída (T3 A, nv 21) | Guerrero | Raro +2 | 4 | comunes | 16/16 | 10.7 | 2.7 | 35 | 14% | 1.0 | — | 96% |
| Fortaleza Caída (T3 A, nv 21) | Guerrero | Raro +2 | 4 | élite | 16/16 | 27.7 | 6.9 | 36 | 13% | 1.1 | — | 81% |
| Fortaleza Caída (T3 A, nv 21) | Guerrero | Raro +2 | 4 | jefe | 6/16 | 58.2 | 14.5 | 47 | 25% | 0.7 | 0/16 (0%) | 29% |
| Fortaleza Caída (T3 A, nv 21) | Guerrero | Leg. +6 | 1 | comunes | 16/16 | 3.6 | 3.6 | 59 | 43% | 0.1 | — | 74% |
| Fortaleza Caída (T3 A, nv 21) | Guerrero | Leg. +6 | 1 | élite | 16/16 | 7.3 | 7.3 | 70 | 45% | 0.0 | — | 55% |
| Fortaleza Caída (T3 A, nv 21) | Guerrero | Leg. +6 | 1 | jefe | 11/16 | 15.9 | 15.9 | 72 | 24% | 0.0 | 0/16 (0%) | 13% |
| Fortaleza Caída (T3 A, nv 21) | Guerrero | Leg. +6 | 4 | comunes | 16/16 | 8.4 | 2.1 | 48 | 23% | 1.0 | — | 97% |
| Fortaleza Caída (T3 A, nv 21) | Guerrero | Leg. +6 | 4 | élite | 16/16 | 20.3 | 5.1 | 48 | 9% | 1.0 | — | 89% |
| Fortaleza Caída (T3 A, nv 21) | Guerrero | Leg. +6 | 4 | jefe | 15/16 | 45.6 | 11.4 | 63 | 31% | 0.0 | 0/16 (0%) | 28% |
| Fortaleza Caída (T3 A, nv 21) | Maga | Raro +2 | 1 | comunes | 16/16 | 2.0 | 2.0 | 108 | 60% | 0.0 | — | 81% |
| Fortaleza Caída (T3 A, nv 21) | Maga | Raro +2 | 1 | élite | 15/16 | 4.9 | 4.9 | 121 | 46% | 0.0 | — | 67% |
| Fortaleza Caída (T3 A, nv 21) | Maga | Raro +2 | 1 | jefe | 11/16 | 11.5 | 11.5 | 102 | 23% | 0.0 | 0/16 (0%) | 29% |
| Fortaleza Caída (T3 A, nv 21) | Maga | Raro +2 | 4 | comunes | 16/16 | 4.5 | 1.1 | 98 | 34% | 0.0 | — | 95% |
| Fortaleza Caída (T3 A, nv 21) | Maga | Raro +2 | 4 | élite | 16/16 | 10.2 | 2.5 | 96 | 15% | 0.0 | — | 94% |
| Fortaleza Caída (T3 A, nv 21) | Maga | Raro +2 | 4 | jefe | 3/16 | 29.7 | 7.4 | 98 | 101% | 0.0 | 0/16 (0%) | 0% |
| Fortaleza Caída (T3 A, nv 21) | Maga | Leg. +6 | 1 | comunes | 16/16 | 2.0 | 2.0 | 108 | 60% | 0.0 | — | 79% |
| Fortaleza Caída (T3 A, nv 21) | Maga | Leg. +6 | 1 | élite | 16/16 | 3.0 | 3.0 | 209 | 45% | 0.0 | — | 76% |
| Fortaleza Caída (T3 A, nv 21) | Maga | Leg. +6 | 1 | jefe | 15/16 | 8.5 | 8.5 | 149 | 24% | 0.0 | 0/16 (0%) | 53% |
| Fortaleza Caída (T3 A, nv 21) | Maga | Leg. +6 | 4 | comunes | 16/16 | 2.5 | 0.6 | 173 | 53% | 0.0 | — | 95% |
| Fortaleza Caída (T3 A, nv 21) | Maga | Leg. +6 | 4 | élite | 16/16 | 5.6 | 1.4 | 180 | 24% | 0.0 | — | 94% |
| Fortaleza Caída (T3 A, nv 21) | Maga | Leg. +6 | 4 | jefe | 16/16 | 14.2 | 3.5 | 207 | 69% | 0.0 | 0/16 (0%) | 54% |
| Laberinto Temporal (T3 C, nv 30) | Guerrero | Raro +2 | 1 | comunes | 16/16 | 3.0 | 3.0 | 167 | 180% | 1.0 | — | 99% |
| Laberinto Temporal (T3 C, nv 30) | Guerrero | Raro +2 | 1 | élite | 16/16 | 3.1 | 3.1 | 226 | 46% | 0.1 | — | 99% |
| Laberinto Temporal (T3 C, nv 30) | Guerrero | Raro +2 | 1 | jefe | 16/16 | 2.9 | 2.9 | 430 | 38% | 0.0 | 0/16 (0%) | 80% |
| Laberinto Temporal (T3 C, nv 30) | Guerrero | Raro +2 | 4 | comunes | 16/16 | 4.0 | 1.0 | 153 | 69% | 1.0 | — | 91% |
| Laberinto Temporal (T3 C, nv 30) | Guerrero | Raro +2 | 4 | élite | 16/16 | 5.9 | 1.5 | 197 | 30% | 1.0 | — | 88% |
| Laberinto Temporal (T3 C, nv 30) | Guerrero | Raro +2 | 4 | jefe | 8/16 | 18.3 | 4.6 | 204 | 101% | 0.3 | 0/16 (0%) | 45% |
| Laberinto Temporal (T3 C, nv 30) | Guerrero | Leg. +8 | 1 | comunes | 16/16 | 3.6 | 3.6 | 68 | 34% | 0.1 | — | 71% |
| Laberinto Temporal (T3 C, nv 30) | Guerrero | Leg. +8 | 1 | élite | 16/16 | 6.2 | 6.2 | 136 | 83% | 0.4 | — | 53% |
| Laberinto Temporal (T3 C, nv 30) | Guerrero | Leg. +8 | 1 | jefe | 14/16 | 12.0 | 12.0 | 122 | 35% | 0.0 | 0/16 (0%) | 21% |
| Laberinto Temporal (T3 C, nv 30) | Guerrero | Leg. +8 | 4 | comunes | 16/16 | 6.6 | 1.7 | 66 | 26% | 1.0 | — | 91% |
| Laberinto Temporal (T3 C, nv 30) | Guerrero | Leg. +8 | 4 | élite | 16/16 | 17.4 | 4.4 | 63 | 10% | 1.0 | — | 81% |
| Laberinto Temporal (T3 C, nv 30) | Guerrero | Leg. +8 | 4 | jefe | 13/16 | 27.2 | 6.8 | 151 | 34% | 0.1 | 0/16 (0%) | 27% |
| Laberinto Temporal (T3 C, nv 30) | Maga | Raro +2 | 1 | comunes | 16/16 | 16.1 | 16.1 | 12 | 35% | 0.8 | — | 84% |
| Laberinto Temporal (T3 C, nv 30) | Maga | Raro +2 | 1 | élite | 16/16 | 25.3 | 25.3 | 22 | 27% | 0.8 | — | 87% |
| Laberinto Temporal (T3 C, nv 30) | Maga | Raro +2 | 1 | jefe | 16/16 | 18.1 | 18.1 | 77 | 36% | 0.0 | 0/16 (0%) | 79% |
| Laberinto Temporal (T3 C, nv 30) | Maga | Raro +2 | 4 | comunes | 16/16 | 46.0 | 11.5 | 9 | 33% | 1.0 | — | 100% |
| Laberinto Temporal (T3 C, nv 30) | Maga | Raro +2 | 4 | élite | 16/16 | 90.6 | 22.6 | 10 | 13% | 1.3 | — | 60% |
| Laberinto Temporal (T3 C, nv 30) | Maga | Raro +2 | 4 | jefe | 12/16 | 47.3 | 11.8 | 92 | 55% | 0.7 | 0/16 (0%) | 80% |
| Laberinto Temporal (T3 C, nv 30) | Maga | Leg. +8 | 1 | comunes | 16/16 | 14.2 | 14.2 | 17 | 35% | 1.0 | — | 81% |
| Laberinto Temporal (T3 C, nv 30) | Maga | Leg. +8 | 1 | élite | 16/16 | 23.4 | 23.4 | 25 | 28% | 1.6 | — | 77% |
| Laberinto Temporal (T3 C, nv 30) | Maga | Leg. +8 | 1 | jefe | 16/16 | 14.6 | 14.6 | 143 | 210% | 0.0 | 0/16 (0%) | 62% |
| Laberinto Temporal (T3 C, nv 30) | Maga | Leg. +8 | 4 | comunes | 16/16 | 47.2 | 11.8 | 10 | 30% | 1.7 | — | 95% |
| Laberinto Temporal (T3 C, nv 30) | Maga | Leg. +8 | 4 | élite | 16/16 | 107.1 | 26.8 | 10 | 13% | 2.4 | — | 75% |
| Laberinto Temporal (T3 C, nv 30) | Maga | Leg. +8 | 4 | jefe | 13/16 | 41.8 | 10.4 | 121 | 155% | 0.3 | 0/16 (0%) | 82% |
| Pradera Esmeralda (T1 A, nv 1) | Mixto | Raro +2 | 4 | comunes | 32/32 | 6.1 | 1.5 | 23 | 129% | 0.0 | — | 90% |
| Pradera Esmeralda (T1 A, nv 1) | Mixto + combos | Raro +2 | 4 | comunes | 32/32 | 6.1 | 1.5 | 23 | 129% | 0.0 | — | 90% |
| Pradera Esmeralda (T1 A, nv 1) | Mixto | Raro +2 | 4 | élite | 32/32 | 4.9 | 1.2 | 21 | 52% | 0.0 | — | 96% |
| Pradera Esmeralda (T1 A, nv 1) | Mixto + combos | Raro +2 | 4 | élite | 32/32 | 4.9 | 1.2 | 21 | 52% | 0.0 | — | 96% |
| Pradera Esmeralda (T1 A, nv 1) | Mixto | Raro +2 | 4 | jefe | 30/32 | 16.4 | 4.1 | 33 | 56% | 0.0 | 0/32 (0%) | 69% |
| Pradera Esmeralda (T1 A, nv 1) | Mixto + combos | Raro +2 | 4 | jefe | 27/32 | 17.4 | 4.3 | 28 | 38% | 0.0 | 0/32 (0%) | 65% |
| Bosque Hondo (T1 C, nv 10) | Mixto | Raro +2 | 4 | comunes | 32/32 | 2.0 | 0.5 | 86 | 86% | 0.0 | — | 94% |
| Bosque Hondo (T1 C, nv 10) | Mixto + combos | Raro +2 | 4 | comunes | 32/32 | 2.0 | 0.5 | 86 | 86% | 0.0 | — | 94% |
| Bosque Hondo (T1 C, nv 10) | Mixto | Raro +2 | 4 | élite | 32/32 | 4.8 | 1.2 | 88 | 43% | 0.0 | — | 93% |
| Bosque Hondo (T1 C, nv 10) | Mixto + combos | Raro +2 | 4 | élite | 32/32 | 4.8 | 1.2 | 88 | 43% | 0.0 | — | 93% |
| Bosque Hondo (T1 C, nv 10) | Mixto | Raro +2 | 4 | jefe | 32/32 | 15.8 | 4.0 | 82 | 91% | 0.1 | 0/32 (0%) | 69% |
| Bosque Hondo (T1 C, nv 10) | Mixto + combos | Raro +2 | 4 | jefe | 32/32 | 16.2 | 4.1 | 80 | 101% | 0.0 | 0/32 (0%) | 69% |
| Fortaleza Caída (T3 A, nv 21) | Mixto | Raro +2 | 4 | comunes | 32/32 | 6.1 | 1.5 | 66 | 32% | 0.3 | — | 100% |
| Fortaleza Caída (T3 A, nv 21) | Mixto + combos | Raro +2 | 4 | comunes | 32/32 | 5.9 | 1.5 | 69 | 34% | 0.6 | — | 98% |
| Fortaleza Caída (T3 A, nv 21) | Mixto | Raro +2 | 4 | élite | 32/32 | 15.4 | 3.8 | 64 | 15% | 0.8 | — | 100% |
| Fortaleza Caída (T3 A, nv 21) | Mixto + combos | Raro +2 | 4 | élite | 32/32 | 14.2 | 3.5 | 69 | 13% | 0.5 | — | 86% |
| Fortaleza Caída (T3 A, nv 21) | Mixto | Raro +2 | 4 | jefe | 31/32 | 43.2 | 10.8 | 65 | 37% | 0.0 | 0/32 (0%) | 71% |
| Fortaleza Caída (T3 A, nv 21) | Mixto + combos | Raro +2 | 4 | jefe | 26/32 | 41.2 | 10.3 | 64 | 36% | 0.0 | 0/32 (0%) | 38% |
| Laberinto Temporal (T3 C, nv 30) | Mixto | Raro +2 | 4 | comunes | 32/32 | 3.4 | 0.9 | 153 | 73% | 0.1 | — | 99% |
| Laberinto Temporal (T3 C, nv 30) | Mixto + combos | Raro +2 | 4 | comunes | 32/32 | 3.4 | 0.9 | 153 | 73% | 0.1 | — | 99% |
| Laberinto Temporal (T3 C, nv 30) | Mixto | Raro +2 | 4 | élite | 32/32 | 7.6 | 1.9 | 155 | 31% | 0.8 | — | 100% |
| Laberinto Temporal (T3 C, nv 30) | Mixto + combos | Raro +2 | 4 | élite | 32/32 | 7.6 | 1.9 | 155 | 31% | 0.8 | — | 100% |
| Laberinto Temporal (T3 C, nv 30) | Mixto | Raro +2 | 4 | jefe | 21/32 | 24.8 | 6.2 | 134 | 53% | 0.1 | 1/32 (3%) | 59% |
| Laberinto Temporal (T3 C, nv 30) | Mixto + combos | Raro +2 | 4 | jefe | 21/32 | 24.8 | 6.2 | 134 | 53% | 0.1 | 1/32 (3%) | 59% |

#### Metas (ajuste de cierre)

| Meta | Resultado | ¿Se cumple? |
|---|---|---|
| C: comunes en 3-4 acciones sin combos (solo) | Bosque 3.0 (guerrero y maga Raro), Laberinto guerrero 3.0 / 3.6 | Sí (la maga con legendaria, 1.0: es débil al fuego) |
| C a 4 sin combos: gana ~50-80% con poca vida | Jefes de C: mixto 32/32 (Bosque, 69% de vida) y 21/32 (Laberinto, 59%); 4 copias 0-13/16. Comunes y élites de C: 100%, con 52-100% de vida | Sí en jefes (Matriarca a 4 copias de más: 0/16); no en comunes y élites |
| Hechicera quebrada antes de su ULT, grupo al azar < 10% | Mixto 1/32 (3%), 4 guerreros 0/16 (antes 66% y 94%) | Sí |
| Solo tramo 1 ≥ 60-80% | Rey Limo 16/16 y 16/16, Matriarca 16/16 y 16/16 (Raro) | Sí (arriba del rango) |
| Solo T3 | Caballero Hueco 9/16 guerrero, 11/16 maga (Raro), 11-15/16 (Leg.); Hechicera 16/16 | Sí |

#### Lectura

- Los comunes y élites de C a 4 siguen sin poder ganarle al grupo: con
  tope 35% el grupo los baja en ~1 acción por jugador, y ni con iniciativa
  ×0.2 llegan a pegar lo suficiente. Lo que puede perder a 4 es el jefe.
- 4 copias del mismo personaje contra la Matriarca pierden siempre (0/16
  guerrero y maga Raro): ATQ ×2.2 más su escolta y Nido Venenoso. El grupo
  mixto la gana 32/32: la diferencia es el Paladín y el Tirador.
- A/B a 4 también pega más (+40% por jugador es global): Pradera, jefe a
  4 mixto 30/32 (antes 32/32).
- Solo el tramo 1 queda en 100% (arriba del 60-80%) porque el ajuste de
  ATQ ×0.8 hace falta para el Caballero Hueco; si se quiere 60-80% en el
  tramo 1, habría que separar el ajuste de solitario por tramo.

