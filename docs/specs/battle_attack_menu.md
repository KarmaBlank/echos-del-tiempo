# Spec: categoría ARMA del menú de batalla

Estado: **APROBADO (etapa 1)**, implementado en v0.20.0. Lo que manda es
§ 6 (decisión del dueño); §§ 1–5 quedan como análisis previo.

Pedido del dueño: "En el menú de batalla, la categoría ATAQUE solo tiene
'Atacar'; queda solito mientras HABILIDADES puede tener 6. Podría haber
alguna otra cosa en ese menú. Analizalo."

Relacionados: combat.md (§ "Acciones del jugador", § "Pulso,
precondiciones e Instante", § "Dúos", § "Elementos y reacciones"),
break_and_enemy_ults.md § 0 (Fisurado y Quebrar), elemental_reactions.md,
ultimates_v2.md, battle_presentation.md § "Barra de batalla",
design_system.md § 10.3, combat_tutorial.md § 4.1. El elemento de base
del arma (el ataque básico pasa a tener elemento) está aprobado pero su
spec (`weapon_identity.md`) todavía no está en `main`; acá se asume solo
"el básico pega con el elemento del arma".

---

## 1. Estado actual

Código: `lib/features/combat/presentation/battle_command_window.dart`
(`BattleCategory`, `BattleAction`) y `battle_screen.dart` (`_entries`,
`handleKey`, `_moveCategory`, `_resetMenu`).

Ventana de tres columnas: categorías · acciones de la categoría · detalle
de la elegida (quién actúa, motivos en rojo, resumen y `DsFold`).

| # | Categoría | Acciones | Se ve |
|---|---|---|---|
| 1 | ATACAR | `Atacar` (+ `Liberar a X`, ½ turno, solo con un aliado en la telaraña) | siempre |
| 2 | HABILIDADES | kit del arma + fusión + ascensión + Quebrar base; Instante arriba con separador (hasta ~6) | si hay alguna |
| 3 | DÚOS | por aliado vivo: el de clase y los de arma | si hay alguno |
| 4 | ULTIMATE | la ULT (con % de carga en la insignia) | si tiene ULT |
| 5 | OBJETOS | Poción de vida, Poción de maná | siempre |
| 6 | DEFENDER | `Defender` (½ daño, próximo turno ×0.7, +1 Pulso) | siempre |
| 7 | PASAR | `Pasar turno` / `Terminar turno` tras Instante | siempre |

O sea: **tres** categorías de una sola fila (ATACAR, DEFENDER, PASAR), no
solo ATACAR.

Costo de cada acción al empezar el turno (`_resetMenu` deja ATACAR elegida
con la fila 0):

| Acción | Teclado | Mouse |
|---|---|---|
| Atacar | `Enter`/`Espacio` o `1` (1 tecla) | 1 clic (fila ya visible) |
| Cambiar objetivo | `Q`/`Tab` | clic en el enemigo |
| Habilidad N | `→` + `N` (2) | 2 clics |
| Dúo | `→ →` + `N` (3) | 2 clics |
| ULT | `→`×3 + `1` (4; menos si no hay dúos) | 2 clics |
| Poción | `→`×4 + `1` + elegir aliado (≥6) | 3 clics |
| Defender | `→`×5 + `1` (6) | 2 clics |
| Pasar | `P P` (2) | 2 clics |

Lectura: el básico ya es **la acción más barata del juego**; el problema
no es de costo sino visual (una fila vacía de contenido) y de **decisión**
(el básico no tiene variantes, así que su categoría no ofrece elección).
Defender, que sí es una decisión táctica, es la más cara por teclado.

## 2. Patrones de diseño comunes (en abstracto)

1. **Básico como acción directa.** El comando principal no abre submenú:
   elegirlo ya es actuar (o pasa directo a elegir objetivo). Las demás
   categorías sí abren lista.
2. **Variantes del básico.** El botón de ataque se convierte en una
   pequeña lista con versiones del mismo golpe:
   - *golpe cargado*: no pega ahora, pega más fuerte al próximo turno;
   - *golpe que quiebra/aturde*: menos daño, más presión sobre la barra
     de aguante;
   - *golpe elemental del arma*: el básico con el elemento propio del arma;
   - *guardia/postura*: el arma se usa para cubrirse;
   - *ataque a posición*: elegir fila o zona en lugar de un objetivo;
   - *contraataque preparado*: se renuncia a pegar para responder al
     próximo golpe recibido;
   - *apuntar a punto débil*: menos probabilidad o más costo, más daño o
     efecto;
   - *robar/analizar*: acción utilitaria que usa el turno del básico.
3. **Fusionar categorías.** Juntar las que tienen una fila (ataque,
   defender, pasar) en una sola categoría "ACCIÓN"/"COMANDOS".
4. **Acciones contextuales.** Filas que aparecen solo cuando aplican
   (liberar a un aliado, rematar a un quebrado, recoger algo). Este juego
   ya lo hace con `Liberar a X`.
5. **Defensa con valor.** Defender no solo reduce daño: genera recurso
   (carga especial, puntos de acción) o prepara algo, para que no sea
   "la acción de cuando no hay nada mejor".
6. **Información como acción.** Ver debilidades o estado de un enemigo,
   gratis (panel) o pagando turno (con un bonus a cambio).

## 3. Opciones para este juego

Restricciones que cualquier opción respeta: el motor es Dart puro
(`BattleEngine.command`), los comandos viajan por red (cambiar o agregar
un comando sube `kProtocolVersion`), el AUTO de compañeros
(solo_party.md § 4) tiene que saber usarlo, y el tutorial filtra por
`actionGate(id)`.

### A) ATAQUE como acción directa (solo UI)

- La categoría ATACAR deja de tener lista: con ATACAR enfocada, el centro
  muestra solo el detalle del básico (daño estimado, elemento, Pulso +1,
  puntos de quiebre 4) y confirmar ataca. `Liberar a X` pasa a ser fila
  contextual en la misma columna (o se resuelve clicando al aliado).
- Teclado igual que hoy (Enter/1). Mouse: clic en ATACAR = atacar.
- Pro: costo casi cero (solo `battle_command_window.dart`, sin red ni
  motor). Contra: no resuelve que haya poco para decidir; un clic en la
  categoría que ataca es peligroso (clic suelto = turno gastado).
  Mitigación: el clic en la categoría solo enfoca; ataca el segundo clic o
  Enter.
- Costo: **S** (½ día). Tests de widget del menú.

### B) ATAQUE pasa a ARMA (3–4 acciones propias del tipo de arma)

Renombrar la categoría a **ARMA** y darle acciones que dependen del tipo
de arma, **sin MP y sin Pulso** (así no pisan HABILIDADES, que siguen
siendo el lugar de MP/Pulso/Instante):

| Fila | Efecto propuesto | Pulso | Quiebre | Notas |
|---|---|---|---|---|
| **Atacar** | como hoy, con el elemento de base del arma | +1 | 4 | sigue siendo la fila 0 / Enter |
| **Golpe de quiebre** | ATQ × 0.6, puntos de quiebre × 2 (8; 12 en pesadas) | +0 | 8 | sin Quebrar: solo llena hacia Fisurado; da un uso al turno que hoy es "atacar y esperar" |
| **Postura** (= Defender movido acá) | ver opción C | +1 (+1 extra) | — | libera la categoría DEFENDER |
| **Técnica del arma** (opcional) | una por tipo de arma, p. ej. espada: corte que aplica 1 stack del elemento; arco: disparo que retrasa `IV × 0.15`; bastón/tomo: golpe que da 3 MP | +0 | 4 | 1 vez por batalla o enfriamiento 3 turnos para que no reemplace al básico |

- Encaje: **quiebre** (el golpe de quiebre acelera Fisurado; Quebrar sigue
  en HABILIDADES con Pulso 2, así se arma el ciclo "básico → Pulso →
  Quebrar"); **Pulso/Instante** (nada de ARMA es Instante; se puede usar
  después de una Instante como cualquier acción); **Convergencia/elemento
  base** (Atacar y la técnica ceban el elemento del arma para que otro
  jugador detone); **dúos** (sin cambio; los dúos de arma siguen en DÚOS);
  **co-op** (en red viajan como `AttackCommand(variant: …)` o
  `WeaponCommand(id)`; protocolo +1).
- Pro: la categoría pasa a tener decisiones reales y le da identidad a
  cada arma sin gastar ranuras de habilidad. Contra: más balance
  (combo_balance.md tiene que medir que el golpe de quiebre no adelante
  el quiebre de jefes por debajo de la meta "0-9% antes de la primera
  ULT"); el AUTO necesita reglas nuevas; texto/tutorial nuevos.
- Costo: **M–L**. Motor (+ tests), catálogo por tipo de arma, protocolo,
  AUTO, UI, admin de balance (`ComboRulesDef` suma `heavyStrike`).
  Atacar + Golpe de quiebre + Postura: ~2–3 días; técnicas por arma: +2–4
  días según cuántos tipos.

### C) DEFENDER/GUARDIA con valor táctico

Hoy: ½ daño, próximo turno ×0.7, +1 Pulso. Propuesta (sea en su
categoría o como "Postura" dentro de ARMA):

- ½ daño hasta su próximo turno (igual).
- **+2 Pulso** en vez de +1 (Defender pasa a ser la forma de "cargar" para
  una habilidad cara o una Instante).
- **Carga de ULT +6** al defender y **+6 más** si recibe un golpe
  mientras defiende (hoy `base_acción` = 0).
- Próximo turno ×0.7 (igual). La defensa automática por tiempo agotado
  queda en +1 Pulso y sin ULT (no premiar el AFK).
- Pro: muy barato (motor + texto), da sentido real al turno defensivo en
  co-op (el que tanquea carga para el grupo). Contra: riesgo de "defender
  en bucle" contra jefes; mitigar con rendimientos decrecientes (el +2
  baja a +1 si defendió el turno anterior).
- Costo: **S** (1 día con tests). Protocolo sin cambios (mismo comando).

### D) ANALIZAR

- Gratis, no gasta turno: el detalle del objetivo (hover o `Q`) ya muestra
  quiebre `n/m` y FISURADO; se suma una línea de debilidades/resistencias
  y elemento que tiene encima. Esto es solo UI y conviene siempre.
- Versión con turno (fila en ARMA): 0 daño, marca al objetivo 2 turnos
  (+10% daño recibido, usa `BuffStat.damageTaken`, o sea cumple
  `targetMarked`), +1 Pulso. Encaja con las habilidades que piden
  "objetivo con Marca".
- Pro: la versión gratis mejora la lectura del combate. Contra: la versión
  con turno se superpone con habilidades de Marca que ya existen.
- Costo: gratis **S** (UI); con turno **M** (motor + red).

### E) Fusionar ATACAR + DEFENDER + PASAR en "ACCIÓN"

- Una categoría con 3 filas: Atacar (1), Defender (2), Pasar/Terminar
  turno (3). Quedan 5 categorías en vez de 7; Defender baja de 6 teclas a
  2 (`2` directo).
- Pro: solo UI, resuelve las tres categorías solitarias de una. Contra:
  Pasar al lado de Atacar facilita un error (mitigado porque `P P` ya
  pide dos toques; con `3` pedir confirmación igual que P).
- Costo: **S**.

## 4. Recomendación

Por etapas, de menor a mayor riesgo:

1. **Ahora (S):** E + C + D gratis. La primera categoría pasa a **ARMA**
   (o ACCIÓN) con `Atacar`, `Defender` (con el valor de C) y las filas
   contextuales (`Liberar a X`); PASAR queda aparte por seguridad. El
   detalle muestra el elemento de base del arma y las debilidades del
   objetivo. Sin cambio de protocolo.
2. **Después (M):** sumar **Golpe de quiebre** a ARMA (opción B parcial),
   medido con el banco de combo_balance.md.
3. **Más adelante (L):** técnica propia por tipo de arma, cuando
   weapon_identity.md esté cerrado.

Descarto A sola: el básico ya cuesta una tecla; cambiarlo a un clic sobre
la categoría ahorra poco y suma errores.

## 5. Preguntas para el dueño

1. **¿Nombre de la categoría?** ARMA / ACCIÓN / se queda ATACAR.
   *Recomiendo ARMA* (prepara las variantes por arma).
2. **¿Defender se muda a esa categoría y pasa a +2 Pulso y carga ULT?**
   *Recomiendo sí*, con el +2 bajando a +1 si defendió el turno anterior.
3. **¿PASAR también entra?** *Recomiendo no*: queda aparte con `P P` para
   no perder turnos por un clic.
4. **¿Golpe de quiebre (ATQ × 0.6, quiebre × 2, sin Pulso) en la segunda
   etapa?** *Recomiendo sí*, condicionado a que el banco mantenga la meta
   de quiebre de jefes.
5. **¿Técnicas por tipo de arma en ARMA o en HABILIDADES?** *Recomiendo
   ARMA*, sin MP ni Pulso y con enfriamiento, para que HABILIDADES siga
   siendo el lugar del Pulso y las Instante; definirlas en
   weapon_identity.md.

## 6. Decisión del dueño (APROBADO, etapa 1)

Solo la etapa 1 de § 4, con un ajuste: las **Instante** se mudan a ARMA
("un instante es más un ataque que una habilidad").

### 6.1 Menú

| # | Categoría | Filas (en orden) |
|---|---|---|
| 1 | **ARMA** | `Atacar` · `Defender` · `Liberar a X` (contextual) · separador "Instante — no terminan tu turno" · las Instante del kit |
| 2 | HABILIDADES | solo las que terminan el turno (sin Instante; si no queda ninguna, la categoría no aparece) |
| 3 | DÚOS | sin cambio |
| 4 | ULTIMATE | sin cambio |
| 5 | OBJETOS | sin cambio |
| 6 | PASAR | sin cambio, aparte (`P P`) para no perder turnos por un clic |

La categoría DEFENDER desaparece. Costo por teclado al empezar el turno:
Atacar `1`/`Enter` (1 tecla), **Defender `2` (1 tecla)**, Instante N
`N` (1 tecla, después de Liberar si hay). El separador no cuenta para los
atajos 1-9. El resaltado de objetivos de la escena vale para las Instante
en ARMA igual que en HABILIDADES.

Panel derecho: cada fila trae su detalle. Atacar como antes; Defender:
`½ daño · +N Pulso · +6 ULT` y el texto de § 6.2; las Instante, la
insignia INSTANTE y "no termina tu turno" (battle_presentation.md).

### 6.2 Defender con valor (motor, host-autoritativo)

- ½ daño hasta su próximo turno; próximo turno en `IV × 0.7` (igual).
- **+2 Pulso** (`BattleEngine.defendPulse`). Si su turno anterior también
  terminó en un Defender elegido, **+1** (`defendPulseRepeat`):
  rendimiento decreciente contra "defender en bucle".
- **+6 de carga de ULT** al defender (`defendUlt`) y **+6** más al
  **primer** golpe enemigo que reciba defendiendo (`defendHitUlt`, una
  vez por defensa). Ambos escalan con `ultChargeBonus`.
- **Tiempo agotado**: la defensa automática da el +1 de Pulso de siempre,
  nada de ULT, y corta la racha (no premia el AFK).
- Estado: `Combatant.guardStreak` (racha) y `guardHitPending` (+6
  pendiente). Viajan en el estado como claves opcionales `gst` / `ghp`
  (ausentes = `false`); el comando `DefendCommand` no cambia, así que
  **no sube `kProtocolVersion`**.
- AUTO / IA de compañeros: sigue usando `DefendCommand` como respaldo; el
  valor lo aplica el motor.

### 6.3 Debilidades gratis

El tooltip del enemigo (`EnemyLiveInfo`) muestra Débil / Resiste / Inmune
de su familia aunque el bestiario todavía no lo conozca (cuando la ficha
dice "???"); si ya lo conoce, la ficha las muestra y no se repiten.

### 6.4 Fuera de alcance

- **Golpe de quiebre y técnicas por arma: NO.** Las Instante en ARMA
  cumplen el rol de "variante del golpe" que proponían § 3 B y § 4.2–4.3.
- Analizar con turno (§ 3 D) no se hace.
