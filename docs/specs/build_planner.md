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
     "Tenés 3 puntos: según tu build, FUE (32/40)";
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
