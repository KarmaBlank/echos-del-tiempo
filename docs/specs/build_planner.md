# Spec: Planificador de build (v0.5)

Pedido del dueño: "como ahora el juego tiene muchas opciones, un build
planner de personaje con checklists, y que se pueda consultar al
comprar, al subir de nivel, al hacer fusiones, etc., y que te notifique
cuando has avanzado en algo de la build".

Un **plan de build** es una lista de metas (atributos, nodos del árbol,
ascensión, arma y mods, habilidades, nivel, notas) que el jugador arma
para **un personaje**. El juego calcula solo cuánto avanzó cada meta
mirando el perfil, lo muestra en la pestaña **BUILD**, marca con
**★ Tu build** lo que sirve en la tienda, el inventario y la fusión, y
avisa con un cartel cuando una meta avanza.

Es **local**: el plan no viaja por la red ni va en el `PlayerProfile`.
Desde v0.5.1 solo viaja al anfitrión un **resumen** con lo que pide de
un arma, para la condición `Build` del filtro de loot (§ 6). Los
compañeros no ven tu plan.

Código:
- Modelo y reglas puras: `lib/game_engine/models/build_plan.dart`,
  `lib/game_engine/rules/build_plan_rules.dart`, plantillas en
  `lib/game_engine/data/build_templates_catalog.dart`.
- Guardado: `CharacterSlot.plan` (`lib/features/characters/domain/account.dart`).
- UI y avisos: `lib/features/build_planner/` (domain / presentation).

Tests: `test/game_engine/build_plan_test.dart`,
`test/features/build_planner/*`.

## 1. Guardado (`account.json`)

El plan va en el **slot del personaje**, al lado del perfil (clave
`plan`, opcional). Una cuenta sin `plan` (todas las anteriores a v0.5)
carga igual: el personaje no tiene plan. Guardar el perfil desde la
sesión (`SelectedCharacterProfileStore`) conserva el plan.

```json
{"id":"c1","p":{...perfil...},
 "plan":{"v":1,"name":"Berserker sangrado","notes":"...","tpl":"gue_berserker",
         "attr":{"FUE":40,"VIT":25},
         "tree":["sangre_e1","sangre_nb","sangre_k"],
         "asc":"berserker","ascN":["berserker_a1","berserker_k"],
         "types":["hacha"],"bases":["hacha_berserker"],
         "mods":[["feroz",3],["del_vampiro",4]],
         "wp":"sedDelArma","skills":["hendir"],
         "lvl":50,"ms":5,
         "check":[["Farmear Prueba I",true],["Conseguir 3 Prismas",false]]}}
```

Lectura tolerante: lo que falta o tiene otro tipo toma su valor por
defecto; ids que no existen en los catálogos se **conservan** (se
muestran como "desconocido" y no cuentan para el progreso), así un plan
no se rompe si cambia un catálogo.

## 2. Metas (`BuildGoalKind`)

| Clase | Qué guarda | Hecha | Parcial |
|---|---|---|---|
| `attribute` | atributo + objetivo (FUE 40) | puntos repartidos ≥ objetivo | muestra `actual/objetivo` |
| `treeNode` | id de nodo del árbol | nodo tomado | — (el detalle dice cuántos puntos faltan: `pathTo`) |
| `ascension` | id de ascensión | es la elegida | Prueba I superada (ya puede elegirla) |
| `ascensionNode` | id de nodo del mini-árbol | nodo tomado | ascensión del plan elegida |
| `weaponType` | tipo (`hacha`) | el arma equipada es de ese tipo | tiene un arma de ese tipo |
| `weaponBase` | id de base | la equipada es esa base | tiene una de esa base |
| `mod` | afijo + tier mínimo (T1 es el mejor) | la equipada lo tiene con tier ≤ mínimo (los mods fijos de un legendario cuentan) | la equipada lo tiene con peor tier, o lo tiene otra arma (se puede trasladar en la fusión) |
| `weaponPassive` | id de pasiva de arma | la equipada la tiene | otra arma la tiene |
| `skill` | id de habilidad | la tenés en batalla (kit, arma equipada, fusionadas o kit de ascensión) | otra arma la da |
| `level` | nivel objetivo | nivel ≥ objetivo | `actual/objetivo` |
| `mastery` | maestría objetivo | maestría ≥ objetivo | `actual/objetivo` |
| `check` | texto libre | tildada a mano | — |

Estados: `done` (hecha), `partial` (en camino), `todo` (sin empezar),
`blocked` (no se puede con este personaje: nodo excluido por otra
keystone, ascensión de otra clase o ya elegiste otra, id desconocido).

`BuildPlanRules.evaluate(plan, profile) → BuildProgress`:
- `goals`: un `GoalStatus` por meta, en el orden de las secciones
  (Atributos, Árbol, Ascensión, Arma y mods, Habilidades, Nivel, Notas),
  con `key` estable (`attr:fue`, `node:<id>`, `asc`, `ascN:<id>`,
  `type:<t>`, `base:<id>`, `mod:<afijo>`, `wp`, `skill:<id>`, `lvl`,
  `ms`, `check:<i>`), `label`, `current`/`total` y `hint`.
- `ratio` (0..1): promedio de las metas (hecha 1, parcial
  `current/total` o 0.5, el resto 0; las bloqueadas no cuentan).
- `next`: **siguiente paso sugerido** (una línea), en este orden:
  1. puntos de atributo sin repartir y el atributo del plan al que más
     le falta:
     "Tenés 2 puntos: según tu build, FUE (18/40)" (progresión v2: cada punto +3);
  2. puntos de árbol libres y un nodo del plan: el más cercano
     (`pathTo`): "Te faltan 3 puntos para Rompeguardias" (si alcanzan:
     "Tomá Impacto → camino a Rompeguardias");
  3. ascensión elegible y no elegida; nodo de ascensión con puntos;
  4. arma: base o tipo del plan que ya tenés sin equipar ("Equipá Hacha
     Berserker"), mod en otra arma ("Trasladá Feroz en la FUSIÓN");
  5. la primera meta sin hacer con pista.
  Sin metas: "Agregá metas o aplicá una plantilla".

### 2.1 Árbol

Los nodos se planifican en el árbol (modo **PLANIFICAR**, § 4.2).
Planificar un nodo lejano no agrega el camino solo: el detalle de la
meta dice cuántos puntos faltan y el modo planificar tiene **+ CAMINO**
que agrega los nodos que faltan hasta él. Una sección del plan lista
notables y keystones con su marca y resume los nodos chicos ("8/12 nodos").

## 3. Plantillas

`kBuildTemplates`: 2–3 por clase, armadas con ids reales de los
catálogos (un test lo verifica). Aplicar una plantilla **reemplaza** las
metas del plan (pide confirmar si había metas) y conserva notas y
checklist del jugador.

| id | Clase | Nombre |
|---|---|---|
| `gue_berserker` | Guerrero | Berserker sangrado |
| `gue_quiebre` | Guerrero | Rompeguardias (Señor de la Guerra) |
| `mag_brasa` | Maga | Elementalista de brasa |
| `mag_cronos` | Maga | Cronomante del tiempo |
| `tir_precision` | Tirador | Francotirador crítico |
| `tir_toxina` | Tirador | Trampero tóxico |
| `pal_guardian` | Paladín | Guardián muralla |
| `pal_templario` | Paladín | Templario del juicio |

## 4. Pantalla BUILD

Pestaña **BUILD** del panel de personaje (en sesión) y botón **BUILD**
en la selección de personaje del título (fuera de la sesión, se puede
editar: es solo el plan).

- Arriba: nombre del plan, barra de progreso total (`ratio`), y la
  línea **Siguiente paso** en dorado. Botones **PLANTILLA** (lista de las
  de tu clase) y **BORRAR PLAN**.
- Tarjetas por sección (Atributos / Árbol / Ascensión / Arma y mods /
  Habilidades / Nivel / Notas): cada meta es una fila con su marca (`GoalMark`: tilde verde = hecha,
  cajita dorada a medio llenar = en camino, cajita vacía = pendiente,
  × roja = bloqueada), su texto, su
  barra `actual/objetivo` cuando corresponde, la pista corta y una **×**
  para quitarla.
- **+ AGREGAR** en cada sección abre un selector buscable (atributos con
  objetivo −/+; ascensiones de tu clase y sus nodos; tipos y bases de
  arma; afijos con tier mínimo; pasivas de arma; habilidades; nivel y
  maestría; texto libre para el checklist).
- Árbol: botón **PLANIFICAR EN EL ÁRBOL** abre el árbol en modo
  planificar.

Sistema de diseño (v0.11, design_system.md § 10.1): la fila de arriba
es un `DsToolbar` (★ nombre, `hechas/total metas`, %, PLANTILLA,
RENOMBRAR y BORRAR PLAN), debajo la barra de progreso y Siguiente paso.
Cada sección es un `DsSectionHeader` (`ATRIBUTOS  2/3`, + AGREGAR a la
derecha) sin caja; cada meta un `DsListRow` de una línea (marca, texto,
`actual/objetivo` o, si está bloqueada, el motivo en rojo; la pista
corta va al tooltip; −5 / +5 y × son botones de ícono). Sin metas: solo
"Sin metas" (los ejemplos de cada sección están en el "?"). Los
selectores usan `DsSearchField` y filas `DsListRow`; las confirmaciones
(¿BORRAR EL PLAN?, ¿REINICIAR ÁRBOL?, ¿APLICAR SUGERENCIA?) muestran la
explicación en una línea y Sí / No como `DsButton` (Sí principal).
Captura: `docs/release_shots/v0.11.0/05_build_despues.png`.

### 4.1 Contexto (consultar sin abrir la pestaña)

- **COMPRAR** (armería): la fila de una base que coincide con el plan
  lleva **★** y el detalle una línea "★ Tu build: base del plan · tipo
  hacha · Hendidura Tóxica".
- **Inventario**: la casilla de un arma que coincide lleva una **★**
  chica arriba a la derecha y su ficha la línea "★ Tu build — Cumple:
  +7% ATQ (T5) · base del plan" (y "casi: Feroz T5 (buscás T3)" si el
  tier no alcanza).
- **ATRIBUTOS**: los atributos del plan muestran "según tu build:
  32/40" y la ayuda de arriba dice "Según tu build: FUE"; el árbol en
  modo normal marca los nodos planificados con un **anillo violeta**.
- **FUSIÓN**: `BuildFitBadge(item, before:)` muestra ★ con lo que la
  acción **avanza** (mods/pasiva/habilidades que la acción agrega y el
  plan pide). Lo usa la mesa de fusión en su ranura `badge`.

### 4.2 Árbol en modo planificar

`PassiveTreeView(planned:, onPlan:)`: con `onPlan` el clic **marca o
desmarca** el nodo en el plan en vez de tomarlo; los planificados se
dibujan con un anillo violeta (`kPlanColor`) y la ficha dice "En tu
build". Sin `onPlan` (modo normal), los planificados igual llevan el
anillo.

## 5. Avisos

`BuildPlanRules.diff(antes, después) → List<BuildNotice>` (puro):
- meta que pasa a `done`: "Build: ★ Keystone Demoledor", "Build: ★
  FUE 40", "Build: ★ Feroz T3+" (solo glifos que tiene la fuente: ★ y », no ✓;
  `retro_text.dart`);
- meta contable que sube sin terminar (atributos, nivel, maestría):
  "Build: FUE 32/40";
- meta de objeto que pasa de `todo` a `partial` (te llegó un arma con el
  mod / base / pasiva / habilidad): "Build: » Feroz T3+ (T2 en Hacha
  Rúnica: trasladalo en FUSIÓN)";
- los nodos chicos del árbol que se completan juntos se resumen en una
  línea "Build: árbol 8/12".
- No avisa retrocesos (desequipar, reiniciar) ni nada cuando cambia el
  plan o el personaje (se toma como nueva base).

`BuildNoticeThrottle`: como mucho **3 avisos cada 4 s**; lo que sobra se
junta en "Build: +N avances". Cada aviso es un cartel en el HUD (arriba
a la derecha, 4 s) y una línea de sistema en el chat local.

Se calcula en el cliente con el perfil local (sirve igual como host o
como cliente). Ajuste **Avisos de build** (JUEGO, `game.json`
`buildNotices`, por defecto sí) los apaga.

## 6. Filtro de loot: "Coincide con mi build" (v0.5.1)

Pedido del dueño: poder filtrar y resaltar el loot que sirve a tu plan.
El filtro lo evalúa el **anfitrión** (decide qué se auto-levanta y qué
queda oculto), así que el anfitrión tiene que conocer lo que pide el plan
de cada jugador.

### 6.1 Resumen del plan (`BuildWants`)

`lib/game_engine/models/build_wants.dart`, puro. `BuildWants.fromPlan(plan)`
toma **solo** lo que mira `BuildPlanRules.itemFit`: tipos y bases de arma,
mods con tier mínimo, pasiva de arma y habilidades. Nada de nombre,
notas, checklist, atributos, árbol, ascensión, nivel ni maestría. JSON con
las mismas claves que el plan (`types`, `bases`, `mods`, `wp`, `skills`).
Lectura acotada (viene de la red): como mucho 24 por lista, ids de hasta
48 caracteres, tier de mod 1..5; lo que no es del tipo esperado se ignora.

`BuildWants.matches(item, base) → Set<BuildMatch>` con la **misma regla**
que `itemFit` (un test lo compara caso por caso):
- `base`: la base está en el plan o su tipo está en el plan;
- `mod`: tiene un afijo del plan con tier ≤ el mínimo (los fijos de un
  legendario, tier 0, siempre cumplen);
- `pasiva`: es la pasiva del plan;
- `habilidad`: la base o una habilidad fusionada es una del plan.
"Casi" (mod con peor tier) **no** cuenta.

### 6.2 Viaje al anfitrión

- Acción `SetBuildWantsAction(BuildWants?)` (`{"t":"wants","w":{...}}`;
  sin `w` = sin plan). Protocolo **6** (netcode.md § "Build y filtro").
- El cliente la manda **al entrar** (después del primer snapshot) y
  **cada vez que cambia el plan** (`SessionController.setBuildWants`; la
  conecta `buildFeedProvider`, que vive mientras dura `WorldScreen`). Si el
  resumen no cambió, no se manda nada.
- Solo / anfitrión: la misma acción se aplica en el motor local.
- El host la acepta siempre (también con la sala pausada) y la guarda en
  `SessionPlayer.buildWants`: **no** va en el snapshot (`SessionJson` no
  la escribe), no se guarda en disco, se pierde si el jugador sale.

### 6.3 Evaluación

`FilterContext.wants`: el motor del anfitrión evalúa el filtro de cada
jugador con **su** resumen (`_deliver` y el auto-levantar usan
`SessionPlayer.buildWants`). En la UI de cada dispositivo se usa el plan
local y **solo para el jugador local** (`SessionController.lootVerdictFor`;
un compañero se evalúa sin plan, así el anfitrión tampoco muestra el
plan de otro). `FilterVerdict.build` dice qué cumple (vacío = nada).

Condición `Build` (loot.md § 13): sin plan no coincide nunca (ni
`Build No`), así una regla de build no hace nada hasta que armes uno.

### 6.4 Lo que se ve

- Etiquetas del piso (mapa), vista previa del filtro, resultado de la
  misión y registro / avisos de loot del HUD: **★** delante del nombre
  cuando el arma cumple algo del plan (aunque ninguna regla la use).
- Filtro por defecto: regla **Tu build** después de Ecos y Legendarios:
  `Build` + `Rareza >= Mágico` → borde violeta (`195 155 255`, el del
  planificador), fondo violeta oscuro, tamaño 36, sonido `campana`, ícono
  estrella violeta en el minimapa; el color del texto sigue siendo el de
  la rareza. Sin plan no coincide (el filtro se comporta como antes). Los
  Comunes que cumplen solo llevan la ★ (no se resaltan: un tipo de arma
  del plan haría resaltar demasiados). Sin haz de luz: el haz sigue
  siendo solo de los Legendarios.
- Editor del filtro (pestaña FILTRO): sección **★ COINCIDE CON MI
  BUILD** con qué tiene que cumplir (CUALQUIER META / BASE O TIPO / MOD /
  PASIVA / HABILIDAD), la línea que se agrega y tres atajos: **+ A LA
  REGLA DEL CURSOR** (línea nueva debajo del cursor; fuera de una regla,
  agrega la de resaltar), **+ REGLA: RESALTAR** y **+ REGLA: OCULTAR
  COMUNES FUERA DEL PLAN** (al principio: gana la primera). Dice qué
  busca tu plan ("Tu plan busca: 1 base o tipo · 2 mods") o que no tenés
  plan. La vista previa usa tu plan.

## 7. Fuera de alcance

- Compartir el plan con el grupo (los compañeros nunca lo ven).
- Condición por meta concreta (`Build feroz`): hoy es por clase de meta.

## 8. Recomendación de atributos (v0.8.3)

Pedido del dueño: "que el builder te recomiende qué atributos subir según
el arma y el árbol que elegiste".

`AttributeAdvisor(progression).recommend(profile, [plan], [points])` →
`List<AttrSuggestion>` (`lib/game_engine/rules/attribute_advisor.dart`,
puro y determinista). Reparte los puntos libres del perfil (o `points`,
para proyectar). Sin puntos devuelve vacío. Cada sugerencia: atributo,
puntos, clase (`requirement` / `survival` / `scaling`, la más urgente
que lo puso) y razones legibles. Orden: por clase, después más puntos.
`AttributeAdvisor.split` da "FUE +2, DES +1"; `summary`, esa línea con
la razón principal; `allocation`, el mapa para `AllocateStatsAction`.

El reparto se arma en tres pasos, en este orden:

### 8.1 Requisitos de las armas del plan (prioridad dura)

Por cada base del plan (`weaponBases`, en orden) con nivel ≤ tu nivel +
3: lo que falta de cada requisito va primero. Razón: "Te faltan 6 FUE
para equipar Hacha Rompeturnos" (con " (nivel 4)" si todavía no tenés
el nivel y " (después quedan N)" si no alcanzan los puntos). Las bases
más lejanas no son requisito duro (solo pesan en 8.3).

### 8.2 Piso de supervivencia

Si tu vida máxima (con lo ya asignado en 8.1) está por debajo de
`30 + 4 × nivel`, VIT hasta llegar, como mucho la mitad de los puntos
(mínimo 1). Razón: "Tu vida (64) está baja para nivel 10 (mínimo
sugerido 70): +4 HP por punto".

### 8.3 Lo que más rinde (arma y árbol)

Puntaje por atributo = Σ por stat de `peso(stat) × ganancia por punto /
valor actual del stat`. La ganancia se mide con `previewAllocation`
(+10 puntos / 10: incluye fórmulas de arma, forja, afijos, árbol y el
tope de crítico). Stats: ATQ, MAG, HP, MP, VEL y crítico (este como
daño esperado: `Δcrit × (multi − 1) / (1 + crit × (multi − 1))`).

Pesos:
- el stat de daño del arma equipada vale 1 (MAG si es báculo / varita /
  tomo, si no ATQ); un arma no-caster con fórmula de MAG suma 0.3 a MAG;
- base: HP 0.15, MP 0.10 (+0.10 si es caster), crítico 0.30, VEL 0.15;
- **árbol** (nodos tomados + planificados, sin el inicio): efectos `atk`,
  `mag`, `heal` (las curas escalan con MAG) y `hp` × 5; `mp` × 4; `crit`
  × 8; `spd` × 0.6; `def` × 0.05 a HP. Cada mecánica suma 0.1: al hacer
  crítico, bonos de crítico / multiplicador → crítico; bonos de ATQ →
  ATQ; velocidad, adelantar turno y turno extra → VEL; invocaciones y
  daño Sagrado → MAG; escudos, curas de mecánica (% de vida), reflejo,
  robo de vida, defensa y disparadores de vida baja / golpe recibido →
  HP (× 0.8);
- **armas del plan** sin equipar (bases, y por cada tipo sin base la de
  mayor nivel ≤ tu nivel + 5): `0.6 ×` promedio de `coef / valor de su
  fórmula` (MAG si es caster, si no ATQ).

Entran al reparto los atributos con puntaje ≥ 40% del mejor (como mucho
3), proporcional al puntaje con resto mayor (empates: el de más
puntaje, después el orden VIT, ESP, AGI, FUE, DES). Razones: las dos
partes más fuertes, p. ej. "+0.6 ATQ por punto con tu Espada de Bronce
(escala FUE×0.6)", "+1.2% crítico por punto; tu árbol: Frenesí, Ojo
Certero +2", "Hacha Berserker del plan escala FUE×0.9 (ATQ)".

Las metas de atributo del plan **no** entran en el cálculo (son la
salida de AGREGAR COMO META).

### 8.4 ATRIBUTOS: tarjeta SUGERENCIA

Debajo de los atributos, si el miembro activo tiene puntos libres:
"Sugerencia: FUE +2, DES +1", una línea por atributo con sus razones y
**APLICAR SUGERENCIA**. Pide confirmar ("Sí, repartir: …"; avisa si
descarta el reparto pendiente) y manda un `AllocateStatsAction` con el
reparto para el **miembro activo** (el líder o el compañero elegido en
el selector de la party). Usa el plan de ese miembro.

### 8.5 BUILD: "Atributos sugeridos"

Arriba de la tarjeta Atributos: la sugerencia para tus puntos libres +
los de los próximos 5 niveles (`horizonPoints`, sin pasar del 50) y su
razón principal (v0.11: en el tooltip del botón). **APLICAR SUGERENCIA**
(antes AGREGAR COMO META; botón principal, `build-advice-goals`) pone cada atributo sugerido con
objetivo `actual + puntos` (si ya había una meta mayor, queda la mayor;
`AttributeAdvisor.addAsGoals`).

Tests: `test/game_engine/attribute_advisor_test.dart`,
`test/features/world/attribute_advice_ui_test.dart`.

## 9. Guía del builder: orden del árbol y armas recomendadas (v0.20.6)

Pedido del dueño: "el builder no te dice mucho, cuesta seguirle la
pista". El árbol marcaba el camino en violeta pero no en qué orden
tomarlo, y no había forma de saber qué arma del inventario o de la
armería le sirve más a tu build.

Reglas puras en `lib/game_engine/rules/build_guide_rules.dart`
(`BuildGuideRules(progression)`), deterministas. Pesos en
`kTuning['buildGuide']` (Editor → Balance, grupo "Guía del builder").
Es local: no viaja por la red (el protocolo no cambia).

### 9.1 Afinidad (`BuildAffinity`)

Un mapa etiqueta → peso, con de dónde salió cada etiqueta para armar el
motivo. Etiquetas: stats `atk`, `mag`, `crit`, `hp`, `def`, `spd`,
`heal`, `mp`; estados `s:<StatusKind>` (`s:burn`, `s:poison`...);
disparadores `t:<ProcTrigger>` (`t:onCrit`...).

- **Del arma** (`weaponAffinity(base, item)`): su stat de daño
  (`dmgWeight`, MAG si es caster); cada habilidad (base, fusionadas y
  ULT del arma): tipo físico → `atk`, mágico → `mag`, cura → `heal`,
  guardia / provocar / proteger → `def` + `hp`, prisa → `spd`, estado →
  `s:`, bono de crítico → `crit`; el elemento del arma → su estado
  (`elementWeight`); la pasiva de arma: el disparador y el estado de sus
  mecánicas (`passiveWeight`); los mods: su stat (`modWeight`).
- **Del plan**: habilidades y pasiva de arma del plan (como arriba, a la
  mitad) y la primera base del plan si no es la equipada.
- **De un nodo**: sus efectos (`atk`, `mag`, `crit`... ; `burn` / `poi` /
  `frz` → estado) y sus mecánicas (disparador y estado, × 1.5).

`affinityOf(plan, profile)` = arma equipada + plan.
`treeAffinity(plan, profile)` = nodos tomados + planificados.

### 9.2 Orden del árbol (`treeOrder(plan, profile) → TreeOrder`)

Secuencia numerada de los nodos del plan que faltan tomar:

1. Si el plan tiene **línea de tiempo** (plantilla), manda: por cada paso
   en orden de nivel, el camino que falta hasta él. Motivo: "Plantilla:
   nivel N" (o el de afinidad si encaja con el arma).
2. Lo que quede se ordena **goloso**: en cada paso los candidatos son
   los nodos del plan pegados a lo ya tomado (o tomado antes en la
   secuencia). Puntaje = afinidad del nodo con el arma + por cada
   notable / keystone del plan que falta, si el candidato está en su
   camino más corto: `goalWeight / largo del camino` + la afinidad de esa
   meta × 0.5 / largo. Empate: el orden en que está en el plan.
3. Si ningún nodo del plan está pegado (plan sin + CAMINOS), el primer
   nodo del camino más corto al nodo del plan más cercano entra como
   paso "Conecta con X" (fuera del plan).

Cada `TreeOrderStep`: nodo, número (1..), motivo corto y cuántas
opciones había en ese paso (`alternatives`; > 1 = había que elegir).
`TreeOrder.next` es el paso 1; `numbers` mapea nodo → número.
Motivos: "Encaja con Hendir (Quemadura)", "Camino a Keystone Demoledor",
"Plantilla: nivel 12", "Del plan".

En la UI:
- Árbol (panel de personaje y BUILD): sobre cada nodo del plan que falta
  su número de paso (cuadradito violeta con el número, tamaño fijo de
  pantalla) y el siguiente en dorado con "SIG". La ficha del nodo dice
  "Paso N del plan: motivo". Leyenda: "Orden".
- BUILD, tarjeta Árbol: "Siguiente nodo: X — motivo" y los próximos 5
  pasos numerados ("1. Impacto · 2. Golpe firme ..."). Con varias
  opciones en el paso dice "(entre N opciones)".

### 9.3 Armas que te sirven (`rankItems` / `rankBases`)

`WeaponPick`: arma (instancia o base), puntaje, motivos cortos (como
mucho 3), si cumple requisitos y si está equipada. Puntaje:

- **plan**: `fitWeight` × metas del arma que cumple (`itemFit`): "Del
  plan: base del plan";
- **atributos**: el atributo de mayor coeficiente de su fórmula de daño;
  si es de tus 2 más altos o tiene meta en el plan, `attrWeight`: "Usa
  FUE, que tenés alta (32)" / "Usa FUE, la de tu plan";
- **árbol**: Σ afinidad del arma × afinidad del árbol (normalizado a 1)
  × `treeWeight`: "Su pasiva Furia encaja con tu rama (al critar)";
- **poder**: su fórmula de daño con tus atributos / la mejor de la
  lista × `powerWeight`;
- **requisitos**: si no los cumple, × `reqPenalty` y "Te faltan 6 FUE"
  (o "Nivel 12"); si los cumple, "Requisitos cumplidos" (último motivo).

Orden: puntaje, después nivel de base, después uid / id. Las primeras
`recommendTop` con puntaje > 0 son **recomendadas**; si alguna de la
lista cumple requisitos, solo se recomiendan las que los cumplen.

En la UI:
- BUILD, tarjeta Arma y mods: "Armas que te sirven": las 3 mejores del
  inventario y el alijo con sus motivos (tooltip con todos).
- Inventario: la ficha de un arma recomendada suma "» Recomendada:
  motivo · motivo".
- Armería (COMPRAR): las bases recomendadas llevan **»** en la fila y el
  detalle "» Recomendada para tu build: motivos". Sin plan también
  recomienda (por arma equipada, árbol y atributos).

### 9.4 Consejo de arma (`advice(plan, profile, stash, shop) → WeaponAdvice`) (v0.20.10)

Pedido del dueño: "cuesta saber qué arma le sirve a mi build". Al elegir
o mirar una plantilla el builder dice, en 4 líneas:

1. **Tipo ideal** (`idealTypes`, `idealAttribute`, `idealReason`): si el
   plan tiene base, el tipo de la primera ("Base de tu plan: X · usa
   FUE"); si tiene tipo, ese ("Tipo de tu plan"); si no, por cada tipo
   permitido a la clase la base cuya afinidad (§ 9.1) más se parece a
   lo que pide el plan (habilidades, pasiva, base) + el árbol (tomado y
   planificado). Gana el de mayor solape; empate: el tipo equipado,
   después alfabético. Se listan hasta 2 tipos a menos de `typeTie` del
   primero. Atributo: la meta de atributo más alta del plan o, sin ella,
   el de mayor coeficiente de la fórmula de daño. Sin plan ni árbol: "Sin
   plan: el tipo que usás".
2. **Mejor que tenés** (`best`): un solo ranking (§ 9.3) con inventario +
   alijo + armería (así los puntajes se comparan). Valor de un arma tuya
   = puntaje + `forgeWeight` × 0.12 × niveles de POT forjados. Solo las
   que cumplen requisitos si alguna los cumple. Empate: la equipada,
   después el uid. Marca si ya está equipada.
3. **Mejor para mejorar** (`upgrade`, `ForgeProjection`): para cada arma
   tuya que cumple requisitos, se proyectan **todos los niveles que le
   quedan hasta su tope de forja** (`ItemRules.forgeCapOf`: rareza y
   nivel de objeto), todos en POT (tope 5 por estadística). Elegido así
   porque es lo que se ve en la forja y es determinista; CRÍT y VEL no se
   proyectan. Costo = Σ `CraftRules.forgeCost` de esos niveles. Se
   muestra si su valor proyectado le gana a la mejor por al menos
   `upgradeMinGain`. Empate: más barata, después uid.
4. **Para comprar** (`buy`): la primera base de la armería (las de tu
   familia con precio, sin las que ya tenés) que cumple requisitos y le
   gana a la mejor por `buyMinGain`.

Pesos en `kTuning['buildGuide']`: `forgeWeight`, `upgradeMinGain`,
`buyMinGain`, `typeTie`, `howToNames`.

UI (`WeaponAdviceBlock`): arriba de la tarjeta Arma y mods de BUILD y en
la vista de plantilla (columna ARMA, con el tipo elegido del plan
actual). Tooltip con todos los motivos. Botones en su propia fila:
EQUIPAR (si la mejor no está equipada ni en el alijo; gris con motivo si
la guardia no deja), IR A FORJA / IR A LA ARMERÍA solo si quien monta la
vista pasa el callback (hoy el panel de personaje no navega a la forja
ni a la armería, así que no se muestran).

### 9.5 Tipo elegido y "Cómo armarlo" (v0.20.10)

En Mundo cualquier clase usa cualquier tipo. "Quiero usar: ‹ TIPO ›"
elige entre IDEAL (el de 9.4) y todos los tipos del catálogo. Se guarda
en el plan: `BuildPlan.chosenType` (JSON `wantType`, aditivo: planes
viejos lo leen como `null`; no es meta, no suma a `goalCount`; local, no
viaja en `BuildWants`, el protocolo no cambia). Un tipo desconocido se
ignora.

Con tipo elegido, las líneas 2-4 se filtran a ese tipo y la armería mira
las bases de ese tipo de **cualquier** familia. Con IDEAL no se filtra.

`howTo(plan, profile, type)` (`WeaponAdvice.howTo`) para el tipo vigente:
- "Subí FUE y DES": los 2 atributos con más coeficiente sumado en las
  fórmulas de daño de las bases del tipo;
- "Te sirven del árbol: A, B, C": nodos del plan o tomados cuya afinidad
  solapa con la del tipo (suma de `weaponAffinity` de sus bases), de
  mayor a menor;
- "No rinden con ARCO: X": notables / keystones sin solape que tienen
  etiquetas ofensivas (daño, crítico, estados, disparadores); las
  defensivas sirven con cualquier arma y no se listan;
- "Suele traer: X, Y": las habilidades más repetidas entre sus bases.
Como mucho `howToNames` nombres por línea.
