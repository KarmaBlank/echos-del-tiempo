# Spec (APROBADO, implementado en v0.19.0): BUILD v2

> **Aprobado por el dueño** con estas respuestas a § 5:
> 1. **5 plantillas por clase**: las 4 de abajo + una **de grupo** con los
>    clusters de grupo del árbol (20 en total).
> 2. **Alijo**: la comparación y las sugerencias de fusión miran también
>    el alijo compartido, **marcado aparte con etiqueta** (`ALIJO`); nada
>    se mueve sin una acción explícita del jugador.
> 3. **Plantillas en YAML del juego** + **exportar / importar a archivo**
>    para compartir con amigos.
> 4. **`BuildMejora`** es una condición **nueva** del filtro; `Build`
>    sigue igual.
>
> El borrador se escribió antes de v0.14–v0.18; § 6 lo pone al día con
> lo que existe hoy (economía v0.15, ULT v2, Hazañas, Editor) y § 7 dice
> cómo quedó la implementación y qué se desvió.

Amplía `build_planner.md` (v0.5–v0.11). Todo lo que no se nombra acá
sigue igual: el plan es local, va en `CharacterSlot.plan`, se evalúa con
`BuildPlanRules.evaluate` y solo viaja al anfitrión el resumen del arma
para la condición `Build` del filtro de loot (build_planner.md § 6).

Qué agrega:

1. **Arma objetivo**: un buscador sobre todas las bases del juego y un
   objetivo de arma completo (rareza, ranuras, mods con tier, pasiva,
   habilidades, nivel de objeto, estadísticas mínimas, forja), con
   comparación contra inventario y alijo.
2. **Plantillas v2**: 4 por clase (16 en total), con árbol hasta el 50
   por nivel, hitos, ascensión, atributos por nivel, arma(s) objetivo y
   endgame. Viven en un archivo de datos que el dueño puede editar sin
   tocar Dart.
3. **Vista de plantilla**: el camino sobre el árbol con un slider de
   nivel 1–50, una línea de tiempo y **SEGUIR ESTA PLANTILLA**.
4. **UI** con los organismos del sistema de diseño que ya usan
   inventario, fusión y árbol.

Referencias: progression_v2.md (puntos, topes blandos, hitos § 5,
árbol v7 § 11), passive_tree_v6.md (clusters exteriores, puentes
elementales), ascension.md § 3, loot.md § 8–10 y § 16, ecos_atlas.md
§ 5–6, design_system.md.

---

## 1. Arma objetivo

### 1.1 Buscador de bases

Botón **+ ARMA OBJETIVO** en la sección Arma y mods de BUILD. Abre un
selector con **todas las bases del catálogo** (`kWeapons`: las 89 de
loot.md § 8.2 y § 8.7, más las que se agreguen), no solo las de tu
familia: las armas son libres por requisitos (loot.md § 0.2).

- `DsSearchField` arriba: busca por nombre de la base, de sus
  habilidades o de su implícito ("trueno" encuentra Hacha Tronante por
  Golpe de Trueno).
- Filtros en una fila de `DsTag` conmutables (varios a la vez, se
  combinan con Y):
  - **Tipo**: espada, hacha, lanza, dagas, báculo, tomo, varita, arco,
    rifle, ballesta, espada+escudo, maza+escudo, martillo+escudo.
  - **Familia** (guerrero / maga / tirador / paladín): es solo una
    etiqueta del catálogo, no restringe.
  - **Nivel**: rango de dos valores (por defecto 1–50) y la casilla
    **Puedo usarla al nivel del plan** (filtra por nivel de la base ≤
    nivel objetivo del plan).
  - **Categoría** (cuerpo a cuerpo / distancia / lanzador,
    loot.md § 16.1): sirve para saber qué habilidades podés traer.
  - **Elemento** de sus habilidades (Fuego, Hielo, Veneno, Agua,
    Electro, Sagrado).
- Cada fila (`DsListRow`): nombre, tipo, `Nv 34`, requisitos (`FUE 44`)
  en rojo si el plan de atributos no los alcanza a ese nivel, y ★ si ya
  es objetivo. El tooltip es la **ficha de arma** (§ 4.2) de una Común.
- Orden: por nivel; con texto buscado, por coincidencia.

### 1.2 El objetivo de arma

Un plan puede tener **hasta 3 objetivos de arma** con prioridad
(principal, de transición, alternativa). Cada uno guarda:

| Campo | Qué es | Ejemplo real |
|---|---|---|
| `base` | id de base (o vacío = cualquier base del `type`) | `hacha_tronante` |
| `type` | tipo, si no se fija base | `hacha` |
| `rarity` | rareza mínima | `epico` |
| `slots` | ranuras de mods mínimas (cupo de la rareza, loot.md § 9) | 6 |
| `mods` | lista de afijo + tier mínimo (T1 el mejor) | `feroz` T2, `letal` T3, `del_toro` T3 |
| `passive` | pasiva de arma (pool o única) y nivel mínimo I–V | `conmocion` III |
| `skills` | habilidades deseadas en el arma (base o trasladadas) | `golpeTrueno`, `remolino`, `tajoMarea` |
| `ilvl` | nivel de objeto mínimo (decide qué tiers pueden salir) | 40 |
| `stats` | estadísticas mínimas del arma equipada, con tu perfil del plan | ATQ ≥ 140, crítico ≥ 20% |
| `forge` | niveles de forja por estadística (Poder / Crítico / Velocidad / Defensa) | Poder 5, Crítico 3 |
| `keepQuebrar` | si querés conservar la ranura de Quebrar (loot.md § 16.3) | `true` |

Validación al armarlo (cada regla con su motivo en una línea, igual que
la fusión):
- `mods` respeta el cupo de la rareza y de cada lado (Épico: 3
  prefijos / 3 sufijos), y el afijo admite el tipo ("Arcano no sale en
  hacha").
- `ilvl` alcanza el tier pedido (T1 desde 40, T2 30, T3 20, T4 10; los
  de stacks: T1 36, T2 12). Si no: "Feroz T1 pide nivel de objeto 40".
- `passive` está en el pool del tipo (o es la única del legendario de
  esa base).
- `skills` entra en `skillCapacity` y cada una se puede traer a esa
  categoría de arma (Tajo de Marea es cuerpo a cuerpo: entra en hacha,
  no en tomo).
- `forge` no pasa el tope de la rareza (Épico 8, máx. 5 por estadística).
- `stats` se calcula con `StatsCalculator` sobre el perfil **del plan**
  al nivel del plan (atributos de la plantilla, árbol sin mecánicas
  condicionales). Al lado se muestra lo que da el objetivo armado, así
  el jugador ve si el mínimo es posible.

### 1.3 Comparar con lo que tenés

`BuildPlanRules.weaponMatch(target, item, profile) → WeaponMatch` (puro,
en `game_engine/`), para cada arma del **inventario y del alijo**
compartido (endgame.md § 5):

- Un `RequirementMatch` por requisito: `done` / `partial` / `todo` /
  `blocked`, con `current`/`total`:
  - base / tipo: 1 o 0 (tipo correcto con otra base = 0.5);
  - rareza: escalón actual / pedido (Raro contra Épico = 3/4);
  - ranuras: cupo actual / pedido;
  - cada mod: 1 si tiene el afijo con tier ≤ pedido; si lo tiene con
    peor tier, `(6 − tier actual) / (6 − tier pedido)`; 0 si no;
  - pasiva: 1 si coincide con nivel ≥ pedido; nivel actual / pedido si
    coincide; 0 si es otra;
  - cada habilidad: 1 / 0;
  - nivel de objeto: `min(1, ilvl / pedido)`;
  - cada estadística mínima: `min(1, actual / mínimo)`;
  - forja: niveles hechos / pedidos.
- **% de cumplimiento** = promedio de los requisitos con peso (base 2,
  mods 1.5 cada uno, el resto 1). Se muestra redondeado (`72%`).
- **Qué te falta**: una línea por requisito incumplido, con la acción
  concreta y su costo de fusión (loot.md § 16), en este orden:

| Caso | Línea |
|---|---|
| Mod ausente y otra arma lo tiene | `Falta Feroz T3 → trasladalo desde Hacha Volcánica Feroz (T3) · ₵450` |
| Mod ausente y nadie lo tiene | `Falta Feroz T3 → Cristal de Era (al azar) o buscalo en el loot` |
| Mod con peor tier | `Feroz T4 (pedís T3) → Esquirla del Eco no sube tier: buscá uno mejor` |
| Pasiva distinta | `Pasiva distinta (Espinas) → fusioná Golpe Conmocionante desde Hacha Rompeturnos Épica · ₵600` |
| Habilidad ausente | `Falta Tajo de Marea → traela desde Espada de Coral · ₵400` |
| Rareza baja | `Raro → Épico: 4 Prismas Rotos + ₵800` |
| Forja | `Forja Poder 3/5 → ₵2 140` |
| Nivel de objeto bajo | `Nv. de objeto 28: Feroz T1 no puede salir; buscá una de nivel 40+` |
| Requisito de atributo | `Pide FUE 44: según tu plan la tenés al nivel 28` |

- La **mejor candidata** es la de mayor % (empate: la equipada, después
  la de mayor nivel de objeto). Se resume en la sección Arma y mods:
  `★ Hacha Tronante Épica 72% · faltan 3`.
- Las metas v1 `weaponType`, `weaponBase`, `mod`, `weaponPassive` y
  `skill` se mantienen (planes viejos siguen andando); un plan v2 las
  genera a partir de su objetivo principal.

### 1.4 Loot y filtro

- En el piso y en el mapa, un arma que **sube el % de la mejor
  candidata** o que **cumple un requisito que ninguna tuya cumple**
  lleva ★ y el color de la rareza en el borde. El tooltip dice qué
  aporta: `★ Feroz T2 (te falta)` o `★ 81% del objetivo`.
- El filtro de loot gana dos condiciones (loot.md § 13, gramática):
  `Build` (como hoy: cualquier requisito del objetivo) y
  `BuildMejora` (solo si mejora la mejor candidata). El resumen que
  viaja al anfitrión suma `rarity`, `ilvl` y la lista de pasivas
  deseadas (sigue sin mandar el plan).
- Aviso al levantar: `★ Hacha Tronante Épica: 81% de tu objetivo`.

### 1.5 Fusión

En la mesa de fusión, con un objetivo cargado:
- Elegir **destino** sugiere la mejor candidata (★ arriba).
- Para cada requisito que falta, la lista de **donantes** marca con ★ el
  arma de la que conviene traerlo (la que lo tiene con mejor tier y
  menos se pierde al destruirla: no equipada, no la última inicial, sin
  otros requisitos del plan). Ej.: para Feroz T3 sugiere Hacha Volcánica
  Feroz y no la Espada de Coral, porque esa es la donante de Tajo de
  Marea.
- La vista previa (`CraftResult`) muestra el % antes y después:
  `72% → 81%`.
- **PLAN DE FUSIÓN**: lista ordenada de operaciones para llegar al
  objetivo con lo que ya tenés (primero subir rareza, después
  trasladar mods, después pasiva, después habilidades, al final forja,
  porque subir rareza tira mods al azar y la forja no cambia con la
  fusión), con el costo total. No ejecuta nada: cada paso es un botón
  que abre la fusión con origen y destino ya elegidos.

---

## 2. Plantillas v2

### 2.1 Qué define una plantilla

| Bloque | Contenido |
|---|---|
| Identidad | id, clase, nombre, una línea de descripción, etiquetas (`electro`, `quiebre`, `grupo`…), dificultad 1–3 |
| Árbol | lista ordenada de **objetivos** (notables y keystones) con el nivel desde el que se toman; los hitos 10 y 20 con su keystone preferida y una de respaldo |
| Ascensión | id y orden de los 6 puntos del mini-árbol por Prueba (30 / 40 / 50) |
| Atributos | tramos de nivel → atributo (cada nivel = 1 punto = +3); respeta topes blandos |
| Armas | 1–3 objetivos de arma (§ 1.2) con el nivel en que se busca cada uno |
| Endgame | orden de nodos con los puntos de Maestría 1–20, nodos del Atlas a priorizar, mods de Ecos que conviene correr, metas de checklist |

El árbol guarda **solo objetivos**: el camino entre ellos lo completa
`pathTo` al aplicar (como `withTreePaths` hoy). Así una plantilla no se
rompe si la fusión de nodos de paso cambia ids (`kTreeV7Merged`), y el
dueño no tiene que escribir nodos chicos.

### 2.2 Formato de datos

Archivo: `assets/data/build_templates.yaml` (uno solo, una entrada por
plantilla; declarado en `pubspec.yaml`). Lo lee
`BuildTemplateCatalog` (la única clase que lo toca, como
`SpriteCatalog` con el manifiesto de sprites); `game_engine/` recibe ya
el modelo parseado, sin Flutter. YAML porque el proyecto ya lo usa y
permite comentarios.

```yaml
version: 2
templates:
  - id: gue_tormenta_filo          # único, [a-z0-9_]
    class: guerrero
    name: Tormenta de filo
    desc: Carga con el arma, quiebra a los Cargados y encadena críticos.
    tags: [electro, quiebre, criticos]
    difficulty: 2
    tree:                           # en orden; "lvl" = desde qué nivel
      - {lvl: 10, milestone: 10, key: quiebre_k, alt: gritos_k}
      - {lvl: 11, node: tempestad_n1}
      - {lvl: 20, milestone: 20, key: filo_k, alt: muralla_k}
    ascension:
      id: senorGuerra
      order: [senorGuerra_a1, senorGuerra_a2, senorGuerra_a3, senorGuerra_k]
    attributes:                     # tramos cerrados; cada nivel = +3
      - {from: 2, to: 17, attr: FUE}
    weapons:
      - {lvl: 34, priority: main, base: hacha_tronante, rarity: epico,
         slots: 6, ilvl: 40,
         mods: [[feroz, 2], [letal, 3]],
         passive: [conmocion, 3], skills: [golpeTrueno, tajoMarea],
         stats: {atk: 140}, forge: {power: 5, crit: 3}}
    endgame:
      mastery: [{ms: 1, node: verdugo_n1}]
      atlas: [rutas, piedra, resonancia]
      ecoMods: {prefer: [], avoid: []}   # ids de kEcoMods
      checklist: ["Prueba III superada"]
```

Reglas del archivo (las valida un test, `build_templates_data_test`, y
también la carga: lo inválido se descarta con un aviso en el log de
desarrollo, nunca rompe el juego):
- Todos los ids existen en su catálogo (nodos v7, ascensiones, bases,
  afijos, pasivas, habilidades, nodos del Atlas, mods de Eco).
- Árbol: para cada objetivo, la suma de `pathTo` desde el anterior entra
  en `PassiveTreeRules.pointsEarned` del nivel indicado (con los puntos
  de hito y de Prueba que correspondan). Los hitos usan
  `milestoneOptions`: si `key` no aparece para esa clase se usa `alt`;
  si ninguna aparece, error.
- Atributos: los tramos no se pisan, cubren 2–50 sin huecos, y el
  efectivo nunca pasa un tope blando por más de 6 puntos crudos (si la
  plantilla quiere pasarlo a propósito, `overcap: true` en el tramo).
- Armas: las reglas de § 1.2; los requisitos de la base se cumplen con
  los atributos de la plantilla en `lvl`.
- Plantillas del dueño: un segundo archivo opcional
  `assets/data/build_templates_custom.yaml` con el mismo formato; si
  repite un id, gana el custom. En `main_dev` hay **RECARGAR
  PLANTILLAS** para probar sin recompilar.

Guardado del plan: el plan v1 gana `v: 2` y los campos `wt` (objetivos
de arma, misma forma que el YAML en JSON) y `tl` (árbol por nivel). Un
plan v1 carga como hoy; aplicar una plantilla v2 lo pasa a v2.

### 2.3 Catálogo propuesto (4 por clase)

Arquetipos base (la ascensión que mejor les va) y combinaciones con los
**puentes** y **clusters exteriores** del árbol v7. Hito 10 / hito 20
según `milestoneOptions` (Guerrero: 10 = Sangre / Quiebre / Gritos; 20 =
Muralla / Filo / puente).

| id | Clase | Nombre | Árbol (hitos → foco) | Ascensión | Arma objetivo |
|---|---|---|---|---|---|
| `gue_berserker` | Guerrero | Berserker sangrado (v1, actualizada) | Sangre → Filo → Verdugo | Berserker A | `hacha_berserker` |
| `gue_quiebre` | Guerrero | Rompeguardias (v1, actualizada) | Quiebre → Muralla → Glaciar | Señor de la Guerra B | `espada_runica` |
| `gue_tormenta_filo` | Guerrero | **Tormenta de filo** (combinación: estados Electro + Filo + quiebres) | Quiebre → Filo → Tempestad | Señor de la Guerra A | `hacha_tronante` |
| `gue_forja` | Guerrero | Quiebre al rojo (combinación con el puente Forja) | Quiebre → puente → Forja | Berserker B | `hacha_volcanica` → `espada_ignea` |
| `mag_brasa` | Maga | Elementalista de brasa (v1) | Brasa → Prisma → Marea | Elementalista A | `tomo_infernal` |
| `mag_cronos` | Maga | Cronomante del tiempo (v1) | Cronos → Arcano → Alquimia | Cronomante A | `tomo_tiempo` |
| `mag_galvanica` | Maga | **Galvánica** (combinación: Voltio + Marea + puente Galvánica) | Cronos → Prisma → Voltio / Galvánica | Elementalista A | `tomo_tormentas` → `tomo_mareas` |
| `mag_hielo_forja` | Maga | Escarcha y forja (combinación con Forja por el lado Maga) | Escarcha → Arcano → Forja | Elementalista B | `baculo_escarcha` → `baculo_marea` |
| `tir_precision` | Tirador | Francotirador crítico (v1) | Precisión → Viento → Centella | Francotirador A | `rifle_ocaso` |
| `tir_toxina` | Tirador | Trampero tóxico (v1) | Toxina → Acecho → Montería | Trampero A | `arco_sombra` |
| `tir_centella` | Tirador | Centella galvánica (combinación con Galvánica por el lado Tirador) | Precisión → puente → Galvánica | Francotirador B | `arco_relampago` |
| `tir_eclipse` | Tirador | Eclipse (combinación Veneno + Sagrado con el puente Eclipse) | Toxina → puente → Eclipse | Trampero B | `dagas_electricas` → ballesta |
| `pal_guardian` | Paladín | Guardián muralla (v1) | Bastión → Fe → Fortaleza | Guardián B | maza+escudo |
| `pal_templario` | Paladín | Templario del juicio (v1) | Juicio → Vigilia → Exorcismo | Templario A | martillo+escudo |
| `pal_pararrayos` | Paladín | Pararrayos (combinación Electro defensivo + Glaciar) | Vigilia → Bastión → Pararrayos | Guardián A | espada+escudo |
| `pal_eclipse` | Paladín | Penitente (combinación con Eclipse por el lado Paladín) | Juicio → puente → Eclipse | Templario B | maza+escudo |

Las 10 v1 se reescriben al formato v2 (mismo id, así un plan con
`tpl: gue_berserker` sigue apuntando a la suya). Las 6 nuevas son las
combinaciones con puentes. Las tablas completas de las 14 que no van
acá se escriben al implementar, con el mismo formato y el mismo test.

### 2.4 Plantilla completa 1 — `gue_tormenta_filo` (Guerrero)

Idea: el arma deja **Cargado** (Golpe de Trueno, Martillo Trueno), el
árbol premia quebrar a los Cargados (Trueno Sordo, Demoledor) y Filo
convierte los críticos en turnos y rebotes. Señor de la Guerra A
convierte cada quiebre del grupo en +20% ATQ para todos.

**Árbol** (puntos v2: 1 por nivel, +7 hito 10, +10 hito 20, +2 por
Prueba; `Σ` = puntos acumulados que pide el camino, lo verifica el test):

| Nivel | Objetivo (id) | Qué es | Por qué |
|---|---|---|---|
| 2–6 | `quiebre_n1` | Mazazo (notable de entrada) | primer efecto del cluster de quiebre |
| 7–9 | (camino) | nodos de paso hacia Rompeguardias | los completa `pathTo` |
| **10** | **hito 10: `quiebre_k`** (alt. `gritos_k`) | Demoledor | gratis; el camino pasa por Rompeguardias (`quiebre_na`) |
| 11–13 | `quiebre_nb` | Ensañamiento | |
| 14–16 | `quiebre_nc` | Brecha (unión, de la que cuelga Tempestad) | |
| 17–19 | `tempestad_n1` | Martillo Trueno: golpes a uno 25% de Cargado | arranca el Electro con el arma |
| **20** | **hito 20: `filo_k`** (alt. `muralla_k`) | Danza de Cuchillas: cada crítico, otro turno (crítico máx. 40%) | gratis; pasa por Estocada Precisa y Frenesí |
| 21–23 | `filo_nb` | Corte en Cadena: crítico a uno rebota 50% | |
| 24–27 | `tempestad_nb` | Trueno Sordo: +40% quiebre vs. Cargados | núcleo del build |
| 28–30 | `tempestad_na` | Resaca: Electrocución → +25% ATQ | |
| 31–34 | `tempestad_nc` | Galerna: al quebrar, el quebrado queda Mojado | Mojado + Cargado = Electrocución |
| 35–38 | `tempestad_nd` | Ojo de la Tormenta: a Mojados 30% de aturdir | |
| 39–44 | `tempestad_k` | Dios del Trueno: cada golpe deja Cargado (−15% vida) | cierra el bucle Cargado → quiebre |
| 45–50 | `filo_nc` y `sangre_n1` | Desarme y Sangría (aguante) | lo que sobra |

**Ascensión** `senorGuerra`: Prueba I → `senorGuerra_a1` Eco del Grito +
`senorGuerra_a2` Inspiración; Prueba II → `senorGuerra_a3` Estratega
(cualquier quiebre del grupo: +20% ATQ al grupo); Prueba III →
`senorGuerra_k` Señor de la Guerra (buffs de grupo +50%). Kit: Grito de
Guerra y Estandarte (ascension.md § 4).

**Atributos** (Guerrero, FUE base 12; tope blando FUE 60, DES 48, VIT 60,
AGI 40):

| Niveles | Puntos | A | Resultado al cerrar el tramo |
|---|---|---|---|
| 2–17 | 16 | FUE | FUE 60 (justo el tope; `hacha_tronante` pide 44) |
| 18–27 | 10 | DES | +30 DES: crítico para Danza y Corte en Cadena |
| 28–42 | 15 | VIT | +45 VIT (compensa el −15% de Dios del Trueno) |
| 43–50 | 8 | AGI | +24 AGI: velocidad, más turnos para cargar |

**Armas**:

| Prioridad | Desde | Base | Objetivo |
|---|---|---|---|
| transición | 9 | `espada_coral` (Tajo de Marea, Escudo de Agua) | Raro, 4 ranuras: `feroz` T4, `certero` T4, `del_toro` T4, `de_la_vida` T4; ilvl 10 |
| transición | 21 | `lanza_mareas` (Lanza de las Mareas, Remolino) | Épico, `feroz` T3, `certero` T3, `letal` T3, `del_toro` T3, `del_halcon` T3, `de_la_vida` T3; pasiva `filoResonante` I; ilvl 30 |
| **principal** | 34 | `hacha_tronante` (Golpe de Trueno, Remolino; +10% ATQ) | Épico, 6 ranuras, ilvl 40: `feroz` T2, `afilado` T2, `letal` T3 / `del_toro` T2, `de_la_vida` T3, `del_halcon` T3; pasiva `conmocion` III; habilidades `golpeTrueno`, `remolino` + traer `tajoMarea` (de la Espada de Coral, ocupa la ranura de Quebrar: `keepQuebrar: false`); forja Poder 5, Crítico 3; mínimo ATQ 140, crítico 30% |

**Endgame**:
- Maestría 1–20 (28 puntos con los +2 cada 5): lado Guerrero de
  Glaciar (`glaciar_nb` Quebrar Témpanos: +15%
  crítico vs. Congelación, ms 1–6), `forja_na` Temple / `forja_nb`
  Hierro al Rojo (ms 7–14, quiebre extra), `vanguardia_n1` Toque de
  Clarín y `vanguardia_nd` Grito de Victoria (ms 15–20, co-op).
- Atlas: `rutas` → `piedra` (Ruinas y Fortaleza: Constructos, donde
  Galerna + Trueno Sordo rinden) → `resonancia` → `brillo` → `destello`
  → `fortuna` (buscar el Épico/Legendario de nivel 40+).
- Ecos: preferir los mods que dan rareza; evitar los que suben la
  resistencia a estados de los enemigos.
- Checklist: "Prueba III superada", "Hacha Tronante Épica 100%".

### 2.5 Plantilla completa 2 — `mag_galvanica` (Maga)

Idea: Agua + Electro. Mojar y cargar para **Electrocución** y
**Cortocircuito**; Voltio hace rebotar y adelanta turnos; el puente
Galvánica convierte cada reacción en ULT y vuelve a dejar los estados.
Elementalista A: Conductora (mojar también carga) y Detonación en
Cadena.

**Árbol** (Maga, hito 10 = Brasa / Cronos / Escarcha; hito 20 = Arcano /
Prisma / puente):

| Nivel | Objetivo (id) | Qué es | Por qué |
|---|---|---|---|
| 2–6 | `cronos_n1` | Arena del Tiempo | |
| **10** | **hito 10: `cronos_k`** (alt. `brasa_k`) | Bucle Eterno | gratis; deja abierto `cronos_nc`, de donde cuelga Voltio |
| 11–14 | `voltio_n1` | Arco Eléctrico: cargar → rebote 35% | |
| 15–19 | `voltio_nb` | Campo Magnético: cargar → −15% ATQ al enemigo | |
| **20** | **hito 20: `prisma_k`** (alt. `arcano_k`) | Singularidad | gratis; Prisma = elementos combinados |
| 21–24 | `voltio_na` | Sobretensión: Electrocución → +15 ULT | |
| 25–28 | `voltio_nc` | Relámpago Globular: Cortocircuito → turno 30% antes | |
| 29–33 | `galvanica_nb` / `galvanica_n1` | (lado Maga del puente) → Electrólisis | Electrocución deja Cargado |
| 34–37 | `galvanica_na` | Pila: Cortocircuito → +12 ULT | |
| 38–41 | `galvanica_nl` | Circuito Cerrado: Cortocircuito deja Mojado | bucle de reacciones |
| 42–46 | `galvanica_k` | Superconductor: golpe que detona +50% (−10% crítico) | |
| 47–50 | `marea_n1` / `marea_nb` | Pleamar, Ahogo (+20% vs. Mojados) | |

**Ascensión** `elementalista`: Prueba I → `elementalista_a1` Conductora
+ `elementalista_a2` Sobrecarga; Prueba II → `elementalista_a3`
Detonación en Cadena; Prueba III → `elementalista_k` Tormenta Perfecta
(al detonar, 50% de turno extra).

**Atributos** (Maga, ESP base 13):

| Niveles | Puntos | A | Resultado |
|---|---|---|---|
| 2–17 | 16 | ESP | ESP 61 (tope 60; `tomo_mareas` pide 51) |
| 18–29 | 12 | VIT | +36 VIT |
| 30–39 | 10 | AGI | +30 AGI: más turnos para preparar |
| 40–50 | 11 | DES | +33 DES: crítico (Superconductor quita 10%) |

**Armas**:

| Prioridad | Desde | Base | Objetivo |
|---|---|---|---|
| transición | 10 | `varita_voltaica` (Chispazo, Corriente) | Raro: `arcano` T4, `runico` T4, `del_sabio` T4, `del_eter` T4 |
| transición | 18 | `baculo_marea` (Chorro de Agua, Oleada, Escudo de Agua) | Épico ilvl 20: `arcano` T3, `runico` T3, `impetuoso` T3, `del_sabio` T3; pasiva `ecoMistico` I; **donante** de `chorro` y `oleada` |
| **principal** | 30 | `tomo_tormentas` (Tormenta Eléctrica, Cadena de Rayos, Descarga Estática; +12% ULT) | Épico ilvl 40: `arcano` T1, `runico` T2, `certero` T3 / `del_sabio` T2, `del_eter` T3, `de_la_vida` T3; pasiva `ecoMistico` III; traer `chorro` y `oleada` (lanzador: solo `any`, las dos son mágicas); forja Poder 5, Crítico 3; mínimo MAG 180 |
| alternativa | 41 | `tomo_mareas` (Torrente, Bruma Densa, Géiser) | igual que la principal, con `cadenaRayos` traída |

**Endgame**:
- Maestría: `marea_nc` Vórtice y `marea_nd` Tsunami (ms 1–8),
  `galvanica_nr` Arco de Plasma (Cargados +15% daño, ms 9–11),
  `alquimia_n1` Solvente / `alquimia_nd` Piedra Filosofal (ms 12–20).
- Atlas: `rutas` → `tiempo` (Laberinto y Corazón) → `resonancia` →
  `gratis` → `potencia` → `gratis2` (más mods = más loot para el tomo
  T1).
- Checklist: "Arcano T1 en el tomo", "Prueba III superada".

> Los ids de nodo siguen el esquema del catálogo (`<cluster>_n1`, `_na`,
> `_nb`, `_nc`, `_nd`, `_k`; puentes: `_na`, `_nb`, `_n1`, `_nl`,
> `_nr`, `_k`). Los niveles de la columna "Nivel" son el objetivo de
> diseño: el test de datos (§ 2.2) los ajusta con `pathTo` al escribir
> el YAML; si un objetivo no entra, se corre al primer nivel en que
> entra y el spec se actualiza.

---

## 3. Vista de plantilla

Se abre desde **PLANTILLA** en BUILD (lista de las de tu clase, con
filtro por etiqueta) o desde el árbol.

- **Ficha** arriba (`DsToolbar`): nombre, etiquetas como `DsTag`,
  dificultad, ascensión, ? (descripción completa).
- **Visor del árbol** (el mismo `PassiveTreeView` en modo solo
  lectura): el camino completo de la plantilla en dorado tenue; un
  **slider de nivel 1–50** (`DsSlider`, nuevo átomo) pinta tomado lo que
  la plantilla tiene a ese nivel y pone en blanco el próximo objetivo.
  Con flechas del teclado se mueve de a 1; `Inicio` / `Fin` al 1 / 50.
  A la derecha del slider: `Nv 24 · 31 puntos · Trueno Sordo`.
- Lo que ya tenés tomado se ve con la marca normal de tomado: la
  diferencia entre tu árbol y la plantilla salta a la vista.
- **Línea de tiempo** debajo (una fila horizontal, desplazable): marcas
  en 10 y 20 (hitos, naranja), 30 / 40 / 50 (Pruebas y nodos de
  ascensión, violeta), los niveles en que cambia el arma objetivo (el
  color de la rareza) y un tramo final "Maestría 1–20" con los nodos de
  endgame. Clic en una marca mueve el slider ahí.
- **Atributos** al nivel del slider: una `DsStatLine` por atributo
  (`FUE 60`, la muesca del tope solo si se pasa).
- **Arma** al nivel del slider: la ficha de arma (§ 4.2) del objetivo
  vigente con ★ y el % de tu mejor candidata.
- **SEGUIR ESTA PLANTILLA** (`DsButton` principal): convierte la
  plantilla en tu plan (reemplaza metas, conserva notas y checklist,
  pide confirmar si había metas, igual que hoy). Desde ahí:
  - "Siguiente paso" usa el árbol por nivel: al subir de nivel,
    `TOMAR SIGUIENTE DEL PLAN` toma el próximo nodo del camino;
  - en un hito, la tarjeta de la keystone de la plantilla lleva ★;
  - en la Estatua, el nodo de ascensión que toca lleva ★;
  - en ATRIBUTOS, el `+` del atributo del tramo vigente lleva ★.
- **COMPARAR**: al lado del botón, muestra `Tu personaje vs. plantilla
  al nivel N`: nodos de más / de menos y atributos fuera de tramo, una
  línea cada cosa.

---

## 4. UI

### 4.1 Reglas generales

Siguen design_system.md § 2 (minimalista, una línea por dato, ayuda en
"?", todo cuadrado, accesible con TAMAÑO DEL TEXTO, ESPACIADO AMPLIO y
ALTO CONTRASTE, foco visible). Además:
- Ningún color es la única señal: ★, `done`/`partial` y requisitos
  incumplidos llevan ícono o texto además del color.
- Los porcentajes se leen con el lector de pantalla ("Hacha Tronante,
  72 por ciento del objetivo, faltan 3").
- Todo se usa con teclado: slider, filtros, filas y botones en orden de
  tabulación de arriba abajo y de izquierda a derecha.

### 4.2 Organismos compartidos

| Organismo | Dónde se usa hoy | Qué suma BUILD v2 |
|---|---|---|
| **Ficha de arma** (`DsWeaponCard`, extraer de inventario/fusión) | tooltip de inventario, mesa de fusión, loot del piso | modo **objetivo**: cada requisito con su marca (`GoalMark`) y el % arriba; los mods que faltan en gris con ★ |
| **Grilla de armas** (`DsItemGrid`, la de inventario) | inventario, alijo, elegir origen/destino de fusión | resultado del buscador de bases y de "mejor candidata"; ★ y % en la esquina de la celda |
| **Visor de árbol** (`PassiveTreeView`) | ÁRBOL, hito | modo solo lectura con capa de plantilla y slider |
| **Fila de requisito** (`DsListRow` + `GoalMark`) | metas de BUILD | requisitos del arma objetivo y líneas de "qué te falta" con botón de acción (abre la fusión) |
| **Selector** (`DsSearchField` + filtros `DsTag` + `DsListRow`) | selectores de BUILD | buscador de bases |

Nuevos átomos/moléculas (entran a la galería `DsGalleryScreen`):
`DsSlider` (cuadrado, con marcas), `DsTimeline` (fila de marcas
cliqueables) y `DsPercent` (número + barra de una línea).

### 4.3 Disposición

- **BUILD**: igual que hoy (toolbar, progreso, Siguiente paso,
  secciones). La sección **Arma y mods** pasa a mostrar los objetivos
  de arma como filas (`★ Hacha Tronante Épica 72% · faltan 3`); clic
  abre el detalle: ficha de arma objetivo a la izquierda, lista de
  requisitos y "qué te falta" a la derecha, grilla de candidatas
  (inventario + alijo) abajo.
- **Vista de plantilla**: visor de árbol arriba ocupando el ancho, slider
  y línea de tiempo debajo, y una columna a la derecha (como la del
  hito, progression_v2.md § 11.5) con atributos, arma y SEGUIR. En
  ancho chico la columna baja debajo de la línea de tiempo.
- Con TAMAÑO DEL TEXTO grande, las filas bajan de línea antes que
  cortar; la ficha de arma crece en alto.

---

## 5. Preguntas abiertas para el dueño (respondidas)

1. **Plantillas**: 5 por clase (las 4 + una "de grupo"). ✔
2. **Alijo**: sí, marcado aparte con etiqueta y sin moverlo solo. ✔
3. **Archivo editable**: YAML del juego + exportar / importar a archivo. ✔
4. **Filtro**: `BuildMejora` nueva; `Build` igual. ✔

---

## 6. Puesta al día (v0.14–v0.18)

### 6.1 Economía v0.15 (materials_economy.md § 4)

Los costos de "qué te falta" y del PLAN DE FUSIÓN son los de hoy
(`CraftRules`):
- **Rareza**: 1 / 3 / 6 Prismas Rotos + ₵100 / ₵300 / ₵800 (Común →
  Mágico → Raro → Épico). Si no te alcanzan los Prismas, la línea suma
  `(te faltan N: Condensar 10 Cristales + ₵500 = 1)`.
- **Mod**: trasladar `100 × peso del tier × rareza`; un mod con peor tier
  se **quita** (`50 × peso × rareza`) y se traslada el mejor. Sin
  donante: **Cristal de Era** (afijo al azar, `50 × rareza` + 1 Cristal).
- **Pasiva**: `300 × rareza` (solo hacia un Épico).
- **Habilidad**: `200 × rareza` + **2 Cristales de Era** hacia Raro o
  mejor.
- **Forja**: la suma de `forgeCost` de cada nivel que falta.

### 6.2 ULT v2 (ultimates_v2.md § 2)

Un plan v2 puede pedir la **ULT activa** (`ult`) y **mejoras** de ULT del
repertorio (`ultUp`: id → nivel 2–5). Son metas de la sección nueva **ULT
Y HAZAÑAS**: hecha si es tu `us` / llegó al nivel; en camino si ya está
en tu repertorio (la pista dice el costo del próximo nivel: créditos,
Cristales y, desde el 3, Prismas); si no, cómo se consigue (`how`). Cada
plantilla trae una ULT activa sugerida y su mejora.

### 6.3 Hazañas (achievements.md)

`feat`: lista de ids de `kAchievements`; meta hecha cuando la hazaña está
en tu progreso. Las plantillas sugieren las que van con su estilo (p. ej.
`ult_breaks` para las de quiebre, `ult_shields` para las de escudo).

### 6.4 Editor (game_editor.md)

**Balance → Plantillas**: cada plantilla cargada es una entidad del
navegador. Se edita como el mapa del YAML (en JSON), se valida con las
mismas reglas del test de datos (ids, tramos, árbol por puntos, armas) y
**GUARDAR EN EL REPO** la escribe en `assets/data/build_templates_custom.yaml`
(gana su id sobre la del juego). Nunca toca la carpeta de datos del
juego.

### 6.5 Hitos reales del árbol v7

El borrador tenía mal los hitos del Guerrero. Los de hoy
(`milestoneOptions`):

| Clase | Hito 10 | Hito 20 |
|---|---|---|
| Guerrero | Muralla / Quiebre / Sangre | Filo / Gritos / puente Glaciar |
| Maga | Arcano / Brasa / Cronos | Escarcha / Prisma / puente Forja |
| Tirador | Lluvia / Precisión / Viento | Acecho / Toxina / puente Galvánica |
| Paladín | Fe / Juicio / Luz | Bastión / Vigilia / puente Eclipse |

### 6.6 Catálogo final (5 por clase)

| Clase | Plantillas |
|---|---|
| Guerrero | `gue_berserker`, `gue_quiebre`, `gue_tormenta_filo`, `gue_forja`, **`gue_grupo`** (Estandarte + Refugio + Fortaleza) |
| Maga | `mag_brasa`, `mag_cronos`, `mag_galvanica`, `mag_hielo_forja`, **`mag_grupo`** (Estandarte + Sintonía + Táctica) |
| Tirador | `tir_precision`, `tir_toxina`, `tir_centella`, `tir_eclipse`, **`tir_grupo`** (Sintonía + Vínculo + Coro) |
| Paladín | `pal_guardian`, `pal_templario`, `pal_pararrayos`, `pal_eclipse`, **`pal_grupo`** (Refugio + Vínculo + Santuario) |

Las 8 de v1 conservan su id. Los niveles del YAML son "desde"; el árbol
por nivel (`BuildTemplateRules.timeline`) corre cada objetivo al primer
nivel en que entra con los puntos (1 por nivel, +7 hito 10, +10 hito 20,
+2 por Prueba; hasta 50 + Maestría 20). Las armas de las tablas de § 2.4
y § 2.5 se ajustaron a lo que permiten los atributos de cada tramo (p.
ej. la Espada de Coral se busca desde el 19, cuando hay DES 10).

---

## 7. Implementación (v0.19.0)

- **Dart puro**: `models/weapon_target.dart` (objetivo de arma),
  `BuildPlan` v2 (`wt`, `tl`, `as`, `ult`, `ultUp`, `feat`; un plan sin
  esos campos se sigue guardando como `v: 1`),
  `rules/weapon_target_rules.dart` (validación, %, candidatas con alijo,
  donantes, "qué te falta", plan de fusión, buscador de bases, aviso de
  loot), `rules/build_template_rules.dart` (timeline, atributos por
  nivel, validación, `toPlan`, `follow`, `compare`),
  `data/build_templates_catalog.dart` (modelo, YAML, registro).
- **Datos**: `assets/data/build_templates.yaml` (20 plantillas) y
  `build_templates_custom.yaml` (del dueño, vacío). Los carga
  `BuildTemplateLoader` en cada composition root; en `main_dev` hay
  **RECARGAR PLANTILLAS** en la lista.
- **Exportar / importar**: EXPORTAR (una plantilla) y EXPORTAR CLASE
  escriben un `.yaml` con el formato del juego (una línea JSON por
  plantilla, que también es YAML); IMPORTAR lo lee, valida cada una y
  descarta las inválidas con aviso. Las importadas viven en la sesión
  (marcadas "importada"); un id que choca con una del juego se renombra
  `<id>_imp`. Seguir una importada la deja en tu plan como cualquier otra.
- **Red** (sin subir `kProtocolVersion`): `BuildWants` suma dos claves
  opcionales, `wt` (objetivo principal sin estadísticas, acotado como lo
  demás) y `best` (% de tu mejor candidata, 0–100). Un par viejo las
  ignora; un host viejo no evalúa `BuildMejora` (no coincide). El plan
  sigue sin viajar.
- **UI** (sistema de diseño): átomos nuevos `DsSlider`, `DsTimeline`,
  `DsPercent` (en la galería, TARJETAS); `WeaponTargetRow`, buscador de
  bases, detalle del objetivo (requisitos con `GoalMark`, qué te falta,
  PLAN DE FUSIÓN, candidatas en dos `DsItemGrid`: INVENTARIO y ALIJO
  COMPARTIDO con etiqueta), lista + vista de plantilla, sección ULT Y
  HAZAÑAS, TOMAR SIGUIENTE DEL PLAN (pestaña BUILD de la sesión), SOLO SI
  MEJORA en el filtro y, en la FUSIÓN, ★ a la mejor candidata (destino) y
  a los donantes sugeridos (origen) más la línea `Objetivo: 72% → 81%`.

**Desvíos** respecto del borrador:
- Las **estadísticas mínimas** se calculan con tu perfil actual (no con
  el del plan al nivel del plan); el anfitrión no las cuenta.
- No se extrajo un `DsWeaponCard` nuevo: la ficha sigue siendo
  `itemHoverTip` (la misma de inventario / alijo / fusión); el modo
  "objetivo" es la lista de requisitos del detalle.
- Los pasos del **PLAN DE FUSIÓN** se listan con su costo, pero todavía
  no abren la fusión con origen y destino elegidos (la mesa marca con ★
  la candidata y el donante).
- La **vista de plantilla** pinta como tomado lo de la plantilla a ese
  nivel (no tu árbol); la diferencia con tu personaje la da COMPARAR.
- Las marcas ★ del loot en el piso / mapa con el aporte al objetivo
  quedan para después: el aviso (`lootNote`) ya está en las reglas.
