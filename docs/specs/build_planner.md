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

Es **local**: no viaja por la red, no cambia el protocolo ni el
`PlayerProfile`. Los compañeros no ven tu plan (quizás más adelante).

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

## 6. Fuera de alcance (v0.5)

- Condición del filtro de loot "coincide con mi build": el filtro lo
  evalúa también el anfitrión, que no conoce tu plan (haría falta
  cambiar el protocolo). Queda para más adelante.
- Compartir el plan con el grupo.
