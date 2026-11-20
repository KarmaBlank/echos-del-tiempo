# Spec (APROBADA por el dueño): Progresión v2 — punto medio

Estado: **implementado en v0.10** (ver § 11 al final: lo que quedó, las
decisiones fuera del spec y lo pendiente). Reemplaza las partes de
`progression.md` (§ Niveles, § Atributos, § Reiniciar) y de
`passive_tree_v6.md` (§ 7 Puntos) que se citan abajo.

Objetivo: menos clics por nivel y cada decisión más pesada, sin cambiar
el poder total ni la forma del juego. Hoy cada nivel son **5 decisiones**
(3 puntos de atributo sueltos + 2 puntos de árbol); en la v2 son **2**
(1 elección de atributo + 1 punto de árbol), con hitos grandes en 10, 20,
30, 40 y 50.

Números medidos con `tool/progression_v2_measure_test.dart` (catálogo
vigente, `kPassiveTree`, `kWeapons`) y con las fórmulas de
`stats_calculator.dart` / `progression_rules.dart`.

## 0. Qué NO cambia

- Curva de XP (`xpNeed`), nivel máximo 50, Maestría 0–20 y su costo.
- Total de atributos al nivel 50: `Σ base + 49 × 3 = Σ base + 147`.
- Requisitos de las armas (loot.md) y las fórmulas `atk` / `mag`.
- Forma del árbol (posiciones, clusters, puentes, keystones, contras,
  mecánicas de notables y keystones).
- Ascensiones y Pruebas del Tiempo (ascension.md): siguen en 30/40/50.
- Protocolo de red: las acciones `AllocateStats` / `TakeNode` siguen
  existiendo (cambian los valores válidos, no la forma del mensaje), ver § 8.

## 1. Ritmo de niveles hoy (referencia para los hitos)

Con la XP por batalla de una zona de tu nivel (`32 × xpFactor(l)`, sin
bono del mundo; worldgen.md § 6.3 lo acelera):

| Nivel | XP acumulada | Batallas aprox. | Misiones de 10 grupos aprox. |
|---|---|---|---|
| 10 | 2 370 | ~40 | ~4 |
| 20 | 14 712 | ~166 | ~17 |
| 30 | 38 342 | ~328 | ~33 |
| 40 | 76 697 | ~526 | ~53 |
| 50 | 133 236 | ~761 | ~76 |

Con el bono de zona, progression.md estima nivel ~25 en unas 10
misiones de zona. Conclusión: hay un hito cada ~4 h de juego en el
tramo 10–20 y cada ~6–8 misiones de zona después; no hay tramos largos
sin algo grande.

## 2. Atributos: 1 decisión por nivel

### 2.1 Regla

- Cada nivel ganado da **1 punto de atributo**; gastarlo suma **+3** al
  atributo elegido (`kAttrPerPoint = 3`). No hay medios puntos.
- `ProgressionRules.allocate` pasa a recibir "cuántos puntos a cada
  atributo" en unidades de punto (cada una = +3). Validación de
  `normalize`: cada atributo `= base + 3 × k` con `k ≥ 0` y
  `Σ k + puntos = nivel − 1`. Al 50: 49 puntos = +147, igual que hoy.
- Requisitos de armas: miden el **valor crudo** (base + 3 × k), como
  hoy. Ningún requisito cambia. Los múltiplos de 3 no traban ningún
  requisito: el más alto es 60 y desde cualquier base se llega con
  `ceil((60 − base) / 3)` puntos (FUE del Guerrero: 12 → 60 en 16
  puntos; ESP de la Maga 13 → 61 en 16; DES del Tirador 11 → 62 en 17;
  VIT del Paladín 15 → 60 en 15).

### 2.2 Topes blandos

Sin topes, lo óptimo casi siempre es volcar todo al atributo de daño
(el arma escala lineal: `espada_cronos` da 1.1 ATQ por FUE). Con +3 por
elección eso se vuelve todavía más obvio, así que se agregan topes
blandos: **por encima del tope, cada +1 crudo rinde +0.5 efectivo**.

```
efectivo(a) = crudo ≤ tope ? crudo : tope + (crudo − tope) × 0.5
```

`StatsCalculator` usa el efectivo en todas sus fórmulas (vida, maná,
velocidad, crítico, `atk` / `mag`); los requisitos usan el crudo; los
afijos de atributo se suman al crudo antes del tope (igual que hoy se
suman antes de las fórmulas).

| Atributo | Tope | Qué da hoy por punto (stats_calculator) | Por qué ese número |
|---|---|---|---|
| VIT | **60** | +4 vida | El requisito más alto de VIT es 60 (`maza_escudo_eterna`). 60 VIT = 260 de vida base al 50; pasado eso la vida ya duplica la del resto del grupo. |
| ESP | **60** | +1.5 maná, ESP × 1.15–1.25 de MAG | Requisito máx. 60 (`baculo_origen`). La Maga llega con 16 puntos y le quedan 33. |
| FUE | **60** | FUE × 0.6–1.18 de ATQ | Requisito máx. 60 (`espada_cronos`). |
| DES | **48** | +1.2% crítico, +0.1 vel., DES × 1.0–1.15 de ATQ en arcos | El crítico llega al tope duro de 60% con DES 47.5 (`0.03 + 0.012 × DES`); pasado 48, DES solo sube ATQ de arcos/ballestas. **Pregunta abierta 2** (el requisito de `arco_eterno` es 60). |
| AGI | **40** | +0.5 velocidad | Requisito máx. 30. 40 AGI = 26 de velocidad base; la velocidad decide el orden de turnos y escala más fuerte que cualquier otro stat por punto. |

Ejemplos al nivel 50 (49 puntos = +147):
- Guerrero que vuelca todo a FUE: 12 + 147 = 159 crudo → hoy ATQ base
  de `espada_cronos` ≈ 1.1 × 159 + 0.3 × 6 = 177; con tope, FUE efectiva
  60 + 49.5 = 109.5 → ≈ 122 (**−31%**). Ganó 0 vida.
- Guerrero repartido: FUE 60 (16 puntos), DES 30 (8), VIT 60 (17), AGI
  24 (6), ESP 10 (2): no toca ningún tope. ATQ base ≈ 1.1 × 60 + 0.3 ×
  30 = 75 contra el 122 del volcado, pero con 260 de vida contra 140 y
  14% más de crítico. La diferencia entre volcar y repartir baja de
  ~2.4× de daño (hoy) a ~1.6×.
- Un build "normal" de hoy (requisitos + resto a VIT) no cambia en nada.

UI: en ATRIBUTOS cada barra muestra el tope con una muesca y, pasado el
tope, el tramo en otro color con el texto `rinde ½`. El botón `+` dice
`+3 FUE` y la vista previa (`previewAllocation`) muestra el cambio de
stats real (ya con el tope). Un `?` explica: "Hasta el tope cada punto
rinde completo; después, la mitad".

## 3. Árbol: nodos de paso fusionados, 1 punto por nivel

### 3.1 Conteo de hoy (catálogo vigente, no el de la tabla de v6 § 1)

| Tipo | Hoy | Después |
|---|---|---|
| Inicios | 4 | 4 |
| Chicos (de paso) | 348 | **≈ 207** (≈ 140 dobles + ≈ 67 sueltos, ver 3.2) |
| Notables | 207 | **≈ 207 + 40 = 247** (ver 3.4) |
| Keystones | 38 | 38 |
| **Total** | **597** | **≈ 456** (no se agregan nodos: bajan) |

(La v6 § 1 dice 584 / 200 / 36: después de esa spec se agregaron 13
nodos; manda el catálogo.)

### 3.2 Fusión

Medido sobre el grafo: de los 348 chicos, **67 no tienen ningún chico
vecino** (están solos entre dos notables), 193 tienen 1 vecino chico y
88 tienen 2–3 (tallos de 3 o más). Regla:

- Cada **par de chicos seguidos** en un tallo se vuelve **un chico doble**
  en la posición del primero, con la suma de los dos efectos (dos chicos
  v5 de +5% ATQ → un +10% ATQ; dos chicos v6 con mecánicas distintas →
  un nodo con las dos mecánicas). Enlaces: los de afuera del par.
- Un tallo de 3 → 1 doble + 1 simple; de 5 → 2 dobles + 1 simple.
- Los **67 chicos sueltos** no se fusionan (no tienen par). 40 de ellos
  se promueven a notables (3.4); los otros 27 quedan simples.
- Ids: el doble conserva el id del primero; el segundo pasa a la tabla
  de migración (`kTreeV7Merged: segundo → primero`).
- Test nuevo: con todo el árbol tomado, `aggregate` da exactamente los
  mismos stats y las mismas mecánicas en la v7 que en la v6 (el poder
  total del árbol no cambia; solo el precio de recorrerlo).

### 3.3 Puntos

Medido: el camino más corto a las keystones tiene ~5 chicos y ~4
notables, y en todo el árbol el 58% de los nodos son chicos. Con la
fusión, recorrer el árbol cuesta **~71% de los puntos de hoy**. Para
mantener el poder total:

| Fuente | Hoy | v2 |
|---|---|---|
| Niveles 2–50 | 2 × 49 = 98 | **1 × 49 = 49** |
| Hito 10 (§ 5) | — | 7 (ligados a la ruta elegida) |
| Hito 20 (§ 5) | — | 10 (ligados a la ruta elegida) |
| Ascensión 30 / 40 / 50 | — | +2 cada una = 6 |
| **Subtotal nivel 50** | **98** | **72** (≈ 98 × 0.71 = 70) |
| Maestría 1–20 | 2 × 20 = 40 | 1 × 20 + 2 en 5/10/15/20 = **28** (≈ 40 × 0.71) |
| **Total** | **138** | **100** (≈ 138 × 0.71 = 98) |

Decisión sobre Maestría: **sigue dando +1 por nivel** (no se toca la
regla que el jugador ya conoce) y se suma **+2 cada 5 niveles** de
Maestría para cerrar el hueco del 0.71. Alternativa más simple si el
dueño prefiere: Maestría +1 y aceptar −2% de poder total al máximo
(pregunta 3).

`PassiveTreeRules.pointsEarned(level, mastery, ascensions)` deja de ser
`(treeLevel − 1) × 2` y suma la tabla de arriba.

### 3.4 Dónde poner notables (sin agregar nodos)

Con 1 punto por nivel, "algo que se sienta" tiene que aparecer cada
2–3 puntos. Hoy el notable más cercano al inicio está a 3 nodos (2
puntos v2) y los caminos tienen tramos de hasta 3 chicos seguidos entre
notables (2 puntos v2: bien). El problema son los clusters exteriores y
los puentes elementales, donde el tallo `_s1`–`_s2` y la cola `_m3`
dejan 2–3 puntos seguidos sin notable.

Propuesta: **promover 40 de los 67 chicos sueltos a "notables menores"**
(un notable con una mecánica de las ya existentes en
`kTreeV6SmallMechanics` multiplicada × 2, sin disparadores nuevos):

- Los 32 clusters de clase: el chico suelto más cercano a la keystone
  de cada uno (`_m3` en los exteriores, el previo a `_k` en los v4) → 32.
- Los 8 puentes: el chico de eje (`_i1` en los elementales, su
  equivalente en los v3) → 8.

Resultado: en cualquier ruta a una keystone no hay más de 2 puntos
seguidos sin un notable. El balance de condiciones de v6 § 9.3 se
vuelve a medir (el notable menor ×2 puede empujar Cargado arriba del
+80%; si pasa, ese notable va a quiebre o defensa como ya se hizo con
Chispa Viva).

### 3.5 Puntos para llegar a cada keystone (desde el inicio de la clase)

Medido (camino más corto; hoy = nodos; v2 = chicos dobles a 1 y simples
a 1, redondeado hacia arriba), igual para las 4 clases por simetría:

| Keystone | Ejemplos | Hoy (puntos) | Hoy: nivel en que se llega | v2 (puntos) | v2: nivel (sin hito) | v2: con hito 10 |
|---|---|---|---|---|---|---|
| Las 3 más cercanas de tu clase | Sangre, Quiebre, Gritos (Guerrero) | 9 | 6 | **7** | 8 | **10** (gratis) |
| Las otras 2 de tu clase | Muralla, Filo | 10 | 6 | **7** | 8 | 10 + 7 → nivel 17 |
| Las de las clases vecinas | Brasa, Cronos, Vigilia, Juicio… | 14 | 8 | **10** | 11 | nivel 20 con el hito 20 (gratis) |
| La más lejana | Prisma (Guerrero), Filo (Maga) | 15 | 9 | **10** | 11 | — |

Lectura: hoy una keystone sale en el nivel 6 (las primeras ~25
batallas) y es casi automática. En la v2 sale entre el 8 y el 10 y es
**la** decisión de ese tramo. Para un nivel 50 la cantidad de keystones
alcanzables es la misma (el árbol cuesta el 71% y hay el 71-73% de los
puntos).

## 4. Camino en un clic y marcadores

- **Ya existe** `PassiveTreeRules.pathTo(classId, progress, nodeId)` y el
  visor muestra `Costo: N puntos` en el tooltip y resalta el camino al
  pasar el mouse (`passive_tree_view.dart`). Falta la acción.
- Clic en un notable o keystone no conectado → diálogo **"Tomar N nodos
  por N puntos"** con la lista (nombre y efecto corto) y `TOMAR` /
  `CANCELAR`. Si faltan puntos: "Tomar los primeros P de N (te faltan
  N − P)" o solo `MARCAR`. Si la ruta pasa por una keystone excluyente,
  `pathTo` ya la evita; si no hay ruta, se explica por qué.
- En red: se manda **una** `TakeNodesAction(ids)` (lista) que el host
  valida en orden con `canTake`; si un nodo falla, se aplica hasta ese y
  se avisa. Una acción en vez de N evita N viajes.
- **Marcadores**: se reusa el plan de BUILD (build_planner.md): un
  nodo del plan ya se ve marcado en el visor. Se agrega `MARCAR` en el
  diálogo y clic derecho / mantener apretado en un nodo para
  agregar/quitar del plan. El plan sigue siendo local.
- Con plan activo, al subir de nivel el aviso ofrece `TOMAR SIGUIENTE
  DEL PLAN` (el próximo nodo del plan que se puede tomar).

## 5. Hitos

| Nivel | Hito | Qué es |
|---|---|---|
| 10 | **Juramento** (nuevo) | Elegís 1 de las 3 keystones más cercanas de tu clase (tabla 3.5, fila 1). Recibís 7 puntos ligados que solo se gastan en la ruta más corta a esa keystone; se toma con un clic (§ 4). |
| 20 | **Encrucijada** (nuevo) | Elegís 1 entre 3: las 2 keystones restantes de tu clase o la keystone del puente con la clase vecina más cercana. 10 puntos ligados a esa ruta. |
| 30 | Ascensión I (existe, Prueba I) | Sin cambios + 2 puntos de árbol libres. |
| 40 | Ascensión II (existe, Prueba II) | Sin cambios + 2 puntos. |
| 50 | Ascensión III (existe, Prueba III) | Sin cambios + 2 puntos. |

- Pantalla de hito: 3 tarjetas grandes (nombre, efecto y contra de la
  keystone, cluster) y `ELEGIR`. Se puede posponer (queda la insignia
  `!` en ÁRBOL) pero no se pierde.
- Los puntos ligados que sobren (si ya tenías nodos de esa ruta) se
  vuelven puntos libres.
- Reasignar el árbol (§ 6) también reabre la elección del hito.
- Perfil: `ms10` / `ms20` (id de la keystone elegida o vacío).

## 6. Reasignar

- **Ya existe y es gratis**: `ProgressionRules.freeRespec = true` (hoy),
  `RespecAction` (atributos) y `ResetTreeAction` (árbol) en cualquier
  modo salvo batalla; los botones dicen `(GRATIS)` (progression.md §
  Reiniciar). No cambia.
- Nuevo: `REASIGNAR TODO` en BUILD hace los dos reinicios juntos y, si
  hay un plan, ofrece aplicarlo de una (atributos y nodos del plan, en
  orden, hasta donde alcancen los puntos).

## 7. Migración

- `kPassiveTreeVersion` 5 → **6** (ids fusionados, § 3.2) y
  `kBalanceVersion` 2 → **3** (atributos en unidades de +3, topes).
- Al cargar un perfil con `tv < 6` o `bv < 3`: atributos al base de la
  clase, árbol vacío, todos los puntos devueltos (`(nivel − 1)` de
  atributo; los de árbol de § 3.3 según nivel, Maestría y ascensiones),
  hitos 10 / 20 sin elegir. **Gratis.** Arma equipada que deja de
  cumplir requisitos → la inicial (como `resetBuild`).
- Al entrar: cartel una vez "La progresión cambió: te devolvimos todos
  tus puntos. Reasigná antes de salir" y el panel de personaje se abre
  con `mustAllocate` (igual que al subir de nivel). Si el personaje
  tenía plan de BUILD, se ofrece aplicarlo (§ 6).
- Plantillas del planificador: se re-escriben con ids v7; un plan
  guardado con un id fusionado se traduce con `kTreeV7Merged`.
- **Copia de seguridad**: antes de migrar se guarda
  `account.pre-bv3-<fecha>.json` con el mismo mecanismo que hoy usa
  `account_store.dart` para `bv` (no pisa una copia existente).
- Red: un compañero con versión vieja no debe poder unirse (al
  implementar, verificar que el saludo de netcode.md compare la versión
  y, si no, agregarlo).

## 8. Impacto en balance

Re-medir con el simulador (combo_balance.md, balance_admin.md § 5):

1. **Curva 1–20**: las keystones llegan 2–4 niveles más tarde sin
   hito y en el 10 con hito. Simular misiones de zona 1–4 con builds a
   nivel 6, 8 y 10 (tasa de victoria y turnos por batalla).
2. **Volcado vs. repartido** con topes: daño por turno de un build
   volcado y uno repartido por clase a nivel 30 y 50; meta: volcado
   ≤ 1.6× el daño del repartido y con menos supervivencia.
3. **Notables menores** (§ 3.4): repetir `passive_tree_balance_test`
   punto 3 (condiciones ≤ +80% daño / +75% crítico).
4. Pruebas del Tiempo y jefes del abismo con los builds plantilla
   migrados.

No debería cambiar (y un test lo fija):

- Stats con **todo** el árbol tomado (v6 vs. v7): idénticos.
- Stats de un build que no pasa ningún tope: idénticos a hoy.
- XP, requisitos, armas, forja, afijos, ascensión.

## 9. Pantallas que cambian

- **ATRIBUTOS**: `+3 X` por punto, muesca del tope, tramo `rinde ½`,
  texto de ayuda "Cada nivel da 1 punto (+3 a un atributo)" (hoy dice
  "Cada nivel da 3"; panels.md).
- **ÁRBOL**: chicos dobles con un aro doble, notables menores con el
  tamaño de notable y borde fino; diálogo de camino (§ 4); insignia `!`
  de hito pendiente; puntos ligados mostrados aparte (`7 de Juramento`).
- **BUILD**: `MARCAR` desde el árbol, `REASIGNAR TODO`, `TOMAR
  SIGUIENTE DEL PLAN`; plantillas con ids nuevos.
- **Avisos de subida de nivel**: "¡Nivel N! 1 punto de atributo y 1 de
  árbol" y, en 10 / 20, la pantalla del hito.
- **Tutorial** (combat_tutorial.md) y ayudas `?` de panels.md: revisar
  todo texto que diga "3 puntos" o "2 puntos de árbol".
- HUD y pestañas: la insignia `+N` cuenta puntos libres + ligados.

## 10. Plan de implementación

1. `game_engine`: `kAttrPerPoint`, topes y valor efectivo en
   `StatsCalculator` (+ tests: build sin topes = hoy; volcado con tope).
2. `allocate` / `normalize` / `resetBuild` en unidades de punto.
3. Catálogo v7: fusión de pares, 40 notables menores, `kTreeV7Merged`
   (+ test "todo el árbol = mismos stats").
4. `pointsEarned` nuevo, hitos 10 / 20 (perfil `ms10` / `ms20`, puntos
   ligados), +2 por ascensión y por 5 de Maestría.
5. Migración `tv 6` / `bv 3` con copia de seguridad y cartel.
6. `TakeNodesAction` en el protocolo + host.
7. UI: ATRIBUTOS, ÁRBOL (diálogo de camino, marcar), BUILD, hitos,
   avisos, textos del tutorial.
8. Simulador (§ 8) y ajuste de números; actualizar progression.md y
   passive_tree_v6.md (§ 7) para que no queden desactualizados.

## Preguntas abiertas para el dueño

1. ¿Los hitos 10 / 20 con "puntos ligados a una ruta" te gustan, o
   preferís que el hito dé la keystone directa (sin los nodos del
   camino, más fuerte y más rara de dibujar)?
2. Tope de DES en 48 (donde el crítico ya topa) aunque `arco_eterno`
   pide 60, ¿o lo subimos a 60 como FUE / ESP / VIT?
3. Maestría: ¿+1 por nivel y +2 cada 5 (cierra el poder total), o solo
   +1 y aceptamos ~2% menos al máximo?
4. Los 27 chicos sueltos que no se promueven, ¿los dejamos simples
   (cuestan 1 punto por la mitad de valor) o los absorbe el notable
   vecino (bajan otros 27 nodos)?


## Respuestas del dueño (aprobado)

1. Hitos 10 / 20: **puntos ligados a la ruta** de la keystone elegida.
2. Tope blando de DES: **60**, como FUE / ESP / VIT.
3. Maestría: **solo +1 por nivel** (se acepta ~2% menos al máximo).
4. Los 27 nodos chicos sueltos que no se promueven: **los absorbe el notable vecino**.

## 11. Implementación (v0.10)

Versiones: `kPassiveTreeVersion` 5 → **6** (árbol v7), `kBalanceVersion`
2 → **3**, `kProtocolVersion` 19 → **20** (perfil con `ms10` / `ms20`,
`AllocateStats` en puntos de +3 y acciones nuevas `nodes` /
`milestone`; un cliente viejo queda afuera por el saludo).

Lo que quedó:

- Atributos: `kAttrPerPoint = 3`, `ProgressionRules.pointsPerLevel = 1`,
  `allocate` / `previewAllocation` en puntos, `normalize` exige
  `base + 3k`. Topes blandos `kAttrSoftCap` (VIT / ESP / FUE / DES 60,
  AGI 40; respuesta 2 del dueño) y `effectiveAttr`; `StatsCalculator`
  usa el efectivo en vida, maná, velocidad, crítico, ATQ y MAG. El
  asesor de atributos (`AttributeAdvisor`) cuenta en puntos y muestra lo
  que suma (`FUE +6`).
- ATRIBUTOS: botón `+3 FUE` (pasado el tope `+3 VIT → +1.5`, naranja),
  valor en naranja pasado el tope; tooltip con qué da por punto, `Tope
  60: pasado el tope rinde ½` y el rendimiento real; la vista previa ya
  usa el tope. v0.10.1 (pedido del dueño): cada fila es una sola línea
  (nombre, valor, ★ del plan, `-` y `+3 X`), sin la línea `tope N` ni la
  descripción (están en el tooltip). Con texto ENORME, solo la sigla.
- Árbol v7 (`passive_tree_v7.dart`, armado desde el v6 con reglas
  determinísticas): **422 nodos** (v6: 597): 132 chicos dobles, 17
  chicos simples, 207 notables + 24 notables menores, 38 keystones, 4
  inicios; `kTreeV7Merged` (175 ids v6 → v7). Con todo el árbol tomado
  los stats son los del v6 más el × 2 de los notables menores (test).
- Puntos de árbol (`PlayerProfile.treePoints`): `(nivel − 1) + Maestría
  + 2 × Pruebas + 7 (hito 10) + 10 (hito 20)` = 92 al máximo (respuesta
  3: Maestría solo +1).
- Hitos: `milestoneOptions(clase, 10 | 20)`; elegir toma con los puntos
  del hito el camino más corto (`chooseMilestone`); las 3 keystones del
  10 están a 7 puntos (llegan justo), las 2 de clase del 20 a 8 (sobran
  2, quedan libres) y la del puente a 13 (faltan 3, se pagan con libres).
  Vista de hito en ÁRBOL (cartel naranja, keystones resaltadas, primer
  clic muestra el camino y el segundo elige, `Puntos de hito: N, solo
  para esta ruta.`), marca `Hito del nivel N` en la keystone, aviso
  propio en el HUD (`¡Hito del nivel 10! Elegí tu keystone en ÁRBOL`) y
  línea de chat al subir.
- Reiniciar árbol (decisión del dueño, v0.10): devuelve los puntos y deja
  los hitos **pendientes** otra vez; los puntos de hito vuelven al elegir
  (no se pierden ni se duplican); la confirmación dice "También podés
  volver a elegir tus hitos (nivel 10 y 20)". Mientras está pendiente,
  esos puntos no existen para gastar en otra cosa.
- Camino en un clic: clic en un notable o keystone que no conecta →
  diálogo `Tomar N nodos por N puntos` (o `Tomar los primeros P de N
  (te faltan …)`) con `Marcar` (agrega o quita del plan de BUILD); botón
  `TOMAR CAMINO (N)` en el panel del nodo. Por red, una
  `TakeNodesAction` (máx. 64 ids).
- Migración: `tv < 6` → árbol vacío; `bv < 3` → `resetProgressionV2`
  (atributos base, `nivel − 1` puntos, árbol vacío, hitos sin elegir) con
  la copia `account.pre-bv3-<fecha>.json` de siempre y el aviso único
  "La progresión cambió: te devolvimos todos tus puntos de atributo y de
  árbol. Reasigná antes de salir."; migrar dos veces no cambia nada
  (test). Los planes de BUILD traducen ids con `kTreeV7Merged`.

Decisiones fuera del spec:

1. **24 notables menores, no 40.** De los 67 chicos sueltos medidos, solo
   8 clusters v4 (`_ma` / `_mb`), los 12 exteriores (`_m3`) y los 4
   puentes elementales (`_i1`) tienen uno; los puentes v3 no tienen
   sueltos y el Invocador suma sus mecánicas por id (no se puede duplicar
   con una copia), así que sus 3 sueltos se absorben. Los otros 43 los
   absorbe el notable vecino (respuesta 4). Con eso, en una ruta a
   keystone hay como mucho 4 chicos seguidos (en el anillo central),
   2 puntos v7.
2. **× 2 de un notable menor:** números dobles; la mecánica se repite con
   id `<id>_x2`. Tres menores de crítico contra Mojado empujaban esa
   condición a +80% (tope +75%): esa copia pasa a **quiebre** contra el
   mismo estado (como pedía § 3.4).
3. **Hito 20:** las 2 keystones restantes de los clusters v4 de la clase
   y la del puente elemental más cercano (los puentes v3 no tienen
   keystone).
4. El aviso de migración sale en la pantalla de título; adentro, el
   botón `PERSONAJE [C] +N` del HUD y la insignia de las pestañas llevan
   a ATRIBUTOS / ÁRBOL (no se fuerza `mustAllocate`).

Balance (§ 8):

- `passive_tree_balance_test` (nuevo bloque v7): 92 puntos v7 contra 138
  del v6, build codicioso mixto: **6.19 → 6.24 (1.01×)** en las 4
  clases; cada stat dentro de ±15%; condiciones ≤ +80% daño / ≤ +75%
  crítico en las 4 clases (después del cambio del punto 2).
- `balance_measure_test` antes / después: los escenarios de nivel 1, 10
  y 20 dan **idénticos**; en nivel 30 hay diferencias chicas por el
  build de árbol del simulador con menos puntos: Guerrero Raro +2 4 jug.
  jefe 7/16 → 7/16 (46% → 40% vida), Leg. +8 4 jug. jefe 12/16 → 9/16;
  Maga Leg. +8 4 jug. élite 14/16 → 14/16 (79% → 57% vida); grupo mixto
  jefe 22/32 → 19/32, mixto + combos 30/32 → 30/32. Todo dentro de las
  metas de combo_balance.md (sin ajustes).

Pendiente:

- Capturas de v0.10 (`tool/shots/v0100_shots_test.dart`): no se
  generaron (el dueño pidió publicar primero).
- Volcado vs. repartido a nivel 30 / 50 con el simulador (§ 8.2) y la
  curva 1–20 por hitos (§ 8.1): sin medir; los topes están cubiertos por
  tests de `StatsCalculator`.
- BUILD: `REASIGNAR TODO` y `TOMAR SIGUIENTE DEL PLAN` (§ 6 y § 4) no se
  hicieron; `MARCAR` está en el diálogo del camino, no en clic derecho.
- Dibujo: los chicos dobles y los notables menores se ven como un chico
  y un notable comunes (sin aro doble ni borde fino).

### 11.1 Forma del árbol v7 (v0.10.1)

En v0.10.0 cada nodo fusionado quedaba en el punto del id que
sobrevivía y la arista nueva era una recta al vecino lejano: diagonales
largas, tres aristas que cruzaban el anillo central y cuadrantes que ya
no eran simétricos. Desde v0.10.1 (sin tocar ids, enlaces, costos ni
balance):

- Cada nodo v7 queda en el punto v6 de su id (los notables que absorben
  y los menores promovidos, donde estaban).
- `PassiveTreeCatalog.edgeRoutes` (`a|b`, `a < b`): puntos intermedios
  de cada arista v7, tomados de la arista v6 que la generó (la más
  corta si hay varias). La arista se dibuja como polilínea por los
  puntos de los nodos absorbidos: sigue los tallos y arcos del v6.
- `PassiveTreeCatalog.extraStrokes`: los tramos v6 que ninguna arista
  dibuja (dentro de un nodo fusionado o de la arista v6 no elegida)
  quedan como trazo fijo de su nodo / arista dueño (se pinta tomado
  cuando el dueño lo está). Así el trazado es exactamente el del v6.
- `passive_tree_v7_shape_test`: segmentos que entran al disco central:
  v6 0 / v0.10.0 3 / ahora **0**; cruces: v6 0 / ahora **0**; asimetría
  al rotar 90° (nodos + segmentos, a 0.05): v6 47 / v0.10.0 93 / ahora
  **56**; solo líneas: **26 = v6**. Lo que queda son los puntos de los
  nodos que la fusión saca en un cuadrante y no en otro (lo decide el
  emparejamiento por id, que no cambia).
- Capturas antes / después: `docs/release_shots/v0.10.1/arbol_*.png`
  (`tool/shots/v0101_tree_shape_shots_test.dart`).

### 11.2 Pantalla ÁRBOL compacta (v0.10.1, pedido del dueño)

- **Barra de una fila** (`tree-points`): a la izquierda los puntos libres
  grandes en dorado (`10 puntos`) y, con un hito pendiente, `Hito: 7` en
  naranja; a la derecha buscador, zoom con íconos de píxel (−, +, ver
  todo, mi clase; `tree-zoom-out` / `tree-zoom-in` / `tree-fit` /
  `tree-home`) y REINICIAR. Sin línea de ayuda (el panel de personaje no
  pone su `PanelHint` en esta pestaña).
- **El árbol ocupa casi toda la pantalla**: se fue la columna fija de la
  derecha (párrafo general y leyenda grande).
- **Tooltip junto al nodo** (padding y borde de `RetroHoverCard`), del
  lado con más lugar y sin tapar el nodo: nombre, tipo, cluster,
  efectos, costo, marca de hito, plan y estado. Pasar el mouse lo
  muestra; un clic en un nodo que no se puede tomar lo **fija**
  (`tree-info`) con sus botones; Esc, un clic en el vacío o afuera del
  visor lo sueltan. Un nodo conectado con puntos se sigue tomando con un
  clic.
- Botones del tooltip fijado: **TOMAR NODO** solo si el nodo toca uno
  tomado (con el motivo si no se puede: exclusión, sin puntos); si no
  conecta, solo **TOMAR CAMINO (N)** (abre `Tomar N nodos por N
  puntos`). En PLANIFICAR, PLANIFICAR / QUITAR DEL PLAN.
- **Hito pendiente = tarjetas** arriba del árbol: título chico
  `HITO · NIVEL 10 · 7 puntos de hito para su camino` y una tarjeta por
  keystone de entrada (`milestone-pick-<id>`: nombre + una línea de
  efecto). Pasar el mouse resalta su camino; el primer clic la elige
  (pasa a `Confirmar <nombre>`) y el segundo confirma. Sin "te damos" ni
  "ELEGIR … (7 nodos)".
- **Leyenda** (`tree-legend`) en una fila de una línea abajo del visor:
  Inicio · Tomado · Keystone · Disponible · Bloqueado · Búsqueda (· Plan).
- Botones con padding ≥ 8 px (ui_style.md § "Padding de botones",
  v0.10.1: la densidad compacta de escritorio se lo comía).
- Tests: `passive_tree_view_test` (disposición, Esc, TOMAR CAMINO sin
  TOMAR NODO, textos del hito), `button_padding_test`. Capturas:
  `docs/release_shots/v0.10.1/pantalla_arbol*.png`
  (`tool/shots/v0101_tree_screen_shots_test.dart`).

### 11.3 Hitos con keystones ya tomadas (v0.10.1, bug del dueño)

Si el jugador tomaba una keystone de entrada con puntos normales, el
hito se la volvía a ofrecer. Regla (en `PassiveTreeRules.milestoneOptions`,
no solo en la UI):

- Las opciones de cada hito excluyen las keystones **tomadas a mano**
  (`PassiveTreeRules.milestoneTaken`: el árbol menos las elegidas en
  hitos, que siguen siendo opción de su propio hito).
- La lista de cada hito sigue el § 5 (5 keystones de clase por costo: el
  10 las 3 primeras no tomadas, el 20 las que quedan + la del puente más
  cercano no tomada). Si una falta, entra **la siguiente elegible** de
  esa lista (p. ej. el 10 pasa a ofrecer la 4.ª de clase).
- Si así no llega a 3, se completa con **las keystones no tomadas más
  cercanas al inicio** (de clase, puente o grupo), nunca una que ofrezca
  el otro hito. Cada hito ofrece siempre 3 mientras queden.
- Al elegir, los puntos del hito solo pagan los nodos que **faltan** del
  camino (`pathTo` ya salta los tomados); lo que sobra queda libre.
- El host valida igual (`ProgressionRules.chooseMilestone` rechaza una
  keystone ya tomada o fuera de las opciones), y `normalize` sanea con
  las mismas opciones.
- Reiniciar el árbol vacía árbol e hitos: vuelven las opciones del § 5.
- Tests: `progression_v2_test` ("una keystone tomada a mano no se vuelve
  a ofrecer", "el hito paga solo los nodos que faltan").
