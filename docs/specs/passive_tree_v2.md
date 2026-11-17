# Spec (aprobada): Árbol de pasivas v2 — notables con mecánicas

Pedido del dueño: "que haya puntos gordos que no sean solo subir stats;
por ejemplo, si hace un crítico aumenta la velocidad de ataque, o realiza
un ataque en cadena; que se note el camino, como en PoE". Se toma la
**mecánica** del género (árbol grande con caminos temáticos, nodos
chicos de stats que llevan a notables con efectos que cambian el juego y
keystones con trade-offs); los nodos, nombres y efectos son propios.

Reemplaza a la v1 (`passive_tree.md` queda como resumen de reglas y
apunta acá). Las reglas de puntos no cambian: 1 punto por nivel después
del 1, el inicio de la clase siempre está tomado y no cuesta, solo se
toman nodos conectados a uno que ya tenés, exclusiones de keystones.

Implementación:
- Datos: `lib/game_engine/data/passive_tree_catalog.dart` (`kPassiveTree`,
  versión `kPassiveTreeVersion = 2`) y
  `lib/game_engine/data/passive_mechanics.dart` (`kMechanics`).
- Modelo: `lib/game_engine/models/passive_tree.dart`,
  `lib/game_engine/models/passive_mechanic.dart`.
- Reglas: `lib/game_engine/rules/passive_tree_rules.dart` (`TreeMods`
  con la lista de mecánicas), `stats_calculator.dart`, y el sistema de
  disparadores en `battle_engine.dart` (combat.md § "Disparadores").
- UI: `lib/features/passive_tree/**`, chips en `battle_hud.dart`.
- Tests: `test/game_engine/passive_tree_catalog_test.dart`,
  `passive_mechanics_test.dart`, `player_profile_test.dart`,
  `serialization_test.dart`, `test/features/passive_tree/*`.

En un juego por turnos, "velocidad de ataque" = **el próximo turno llega
antes** (se acorta la espera en el timeline, `IV = 100 / velocidad`).

## 1. Forma del árbol (112 nodos)

Coordenadas en "unidades de árbol" (la UI las multiplica por 30 px; el
centro del lienzo es (0, 0); y crece hacia abajo).

- **4 inicios de clase** (`kind: st`), radio 2.5, mismos ids y efectos
  que la v1: Guerrero `s_gue` arriba (−90°), Maga `s_mag` derecha (0°),
  Tirador `s_tir` abajo (90°), Paladín `s_pal` izquierda (180°).
- **Anillo central compartido**: 12 nodos chicos en un círculo de radio
  1.5, uno cada 30° empezando en −90°, enlazados en ciclo. Los 4 que caen
  en la dirección de una clase son sus **umbrales** (`p_gue`, `p_mag`,
  `p_tir`, `p_pal`, enlazados con el inicio de esa clase); entre dos
  umbrales hay 2 nodos de anillo:

| Id | Ángulo | Nombre | Efecto |
|---|---|---|---|
| `p_gue` | −90° | Umbral de Acero | +4% ATQ |
| `r_gm1`, `r_gm2` | −60°, −30° | Equilibrio | +4% vida, +4% maná |
| `p_mag` | 0° | Umbral Arcano | +4% MAG |
| `r_mt1`, `r_mt2` | 30°, 60° | Fluidez | +4% carga ULT, +0.2 velocidad |
| `p_tir` | 90° | Umbral del Viento | +2% crítico |
| `r_tp1`, `r_tp2` | 120°, 150° | Guardia | +1 DEF, +2% crítico |
| `p_pal` | 180° | Umbral Sagrado | +1 DEF |
| `r_pg1`, `r_pg2` | 210°, 240° | Aguante | +6% vida |

  Cualquier clase puede viajar por el anillo a la zona de otra: desde
  tu inicio, umbral propio → 2 nodos de anillo → umbral vecino → inicio
  de esa clase (se puede tomar, cuesta 1 punto y da su efecto) → sus
  caminos. Zona vecina: 5 puntos antes del primer nodo de un camino;
  zona opuesta: 8.
- **12 caminos**, 3 por clase, que salen del inicio de la clase en los
  ángulos `clase − 32°`, `clase`, `clase + 32°`. Cada camino tiene 8
  nodos en línea recta desde el centro, nodo `i` (0..7) a radio
  `3.4 + 0.8 × i`:
  `inicio → chico ×3 → NOTABLE → chico ×2 → NOTABLE → KEYSTONE`.
  Ids: `<camino>_1`, `_2`, `_3`, `_n1`, `_4`, `_5`, `_n2`, `_k`.
  Cada nodo guarda su camino (`pathId`) para resaltarlo en la UI.

Total: 4 + 12 + 12 × 8 = **112 nodos**; 24 notables, 12 keystones.

## 2. Caminos y nodos chicos

Los chicos 1-3 dan el stat A, los 4-5 el stat B. Los notables dan además
un stat chico. Notables y keystones detallados en § 3 y § 4.

| Clase | Ángulo | Camino (id) | Tema | Chicos 1-3 | Chicos 4-5 | Notable 1 (+stat) | Notable 2 (+stat) | Keystone |
|---|---|---|---|---|---|---|---|---|
| Guerrero | −122° | Muralla (`muralla`) | defensa, contraataque | Coraza +1 DEF | Aguante +6% vida | Contraataque (+2 DEF) | Represalia (+6% vida) | Golpe Imparable |
| Guerrero | −90° | Sangre (`sangre`) | robo de vida, poca vida | Fuerza Bruta +6% ATQ | Vigor +6% vida | Último Aliento (+5% vida) | Sed de Sangre (+6% ATQ) | Furia de Sangre |
| Guerrero | −58° | Filo (`filo`) | críticos y velocidad | Filo Agudo +3% crítico | Pies Ligeros +0.3 vel. | Frenesí (+3% crítico) | Corte en Cadena (+5% ATQ) | Danza de Cuchillas |
| Maga | −32° | Arcano (`arcano`) | maná, ULT, cadenas | Concentración +8% maná | Afinidad +6% carga ULT | Arco Voltaico (+6% MAG) | Eco Arcano (+10% maná) | Mente sobre Materia |
| Maga | 0° | Brasa (`brasa`) | quemadura, explosiones | Ascua +6% MAG | Reserva +8% maná | Combustión (+1 Quemadura) | Choque Térmico (+6% MAG) | Tormenta Arcana |
| Maga | 32° | Escarcha (`escarcha`) | congelación, tiempo | Escarcha +5% MAG | Calma Helada +0.3 vel. | Tiempo Gélido (+1 Congelación) | Fractura (+6% MAG) | Alma de Hielo |
| Tirador | 58° | Viento (`viento`) | velocidad, ataques extra | Reflejos +0.3 vel. | Ráfaga +5% ATQ | Viento a Favor (+0.4 vel.) | Rebote (+5% ATQ) | Cadena Infinita |
| Tirador | 90° | Precisión (`precision`) | críticos, marca | Puntería +3% crítico | Tensión +5% ATQ | Marca del Cazador (+3% crítico) | Punto Débil (+5% ATQ) | Ojo de Halcón |
| Tirador | 122° | Toxina (`toxina`) | veneno, debilitar | Ponzoña +5% ATQ | Resistencia +5% vida | Debilitar (+1 Veneno) | Plaga Contagiosa (+5% ATQ) | Toxicidad |
| Paladín | 148° | Juicio (`juicio`) | daño sagrado, aturdir | Celo +6% ATQ | Rigor +2% crítico | Martillo Bendito (+5% ATQ) | Castigo Divino (+6% MAG) | Paladín Inherente |
| Paladín | 180° | Fe (`fe`) | curación, regeneración | Gracia +8% curación | Fe +6% vida | Mano Sanadora (+10% curación) | Plegaria (+6% vida) | Paladín Creyente |
| Paladín | 212° | Bastión (`bastion`) | escudos, provocar | Templanza +1 DEF | Firmeza +6% vida | Guardián (+2 DEF) | Desafío (+8% vida) | Égida Eterna |

Exclusiones: `fe_k` (Creyente) ↔ `juicio_k` (Inherente), como en la v1.

## 3. Notables (mecánicas)

Cada notable se declara como dato (`PassiveMechanic`): disparador +
filtro + probabilidad + lista de efectos con parámetros. El motor no
tiene código por notable, solo por **tipo de efecto**.

| Notable (id) | Disparador | Efecto exacto |
|---|---|---|
| Frenesí (`frenesi`) | al hacer crítico | +20% velocidad por 2 turnos. No acumula: renueva. |
| Corte en Cadena (`corteCadena`) | al hacer crítico con una acción a un solo objetivo | Rebota a otro enemigo con el 50% del daño del golpe. |
| Último Aliento (`ultimoAliento`) | condición: vida < 30% al actuar | +25% ATQ y +10% crítico. |
| Sed de Sangre (`sedSangre`) | al matar (1 vez por acción) | Tu próximo turno llega un 50% antes y te curás 10% de tu vida máx. |
| Contraataque (`contraataque`) | al recibir un golpe defendiendo | Devolvés el 50% del daño recibido al atacante. |
| Represalia (`represalia`) | al recibir un golpe | +30% ATQ por 1 turno. No acumula. |
| Combustión (`combustion`) | al golpear a un enemigo que ya tenía 3+ Quemadura | Explota: 50% del daño de ese golpe a cada otro enemigo. 1 explosión por acción. |
| Choque Térmico (`choqueTermico`) | al aplicar Quemadura a un enemigo con Congelación | Le quita toda la Congelación y lo aturde (1). |
| Tiempo Gélido (`tiempoGelido`) | al aplicar Congelación | El enemigo se retrasa `IV × 0.2` en el timeline. |
| Fractura (`fractura`) | condición: el objetivo tiene Congelación | +25% de daño a ese objetivo. |
| Arco Voltaico (`arcoVoltaico`) | habilidad mágica a un solo objetivo | Rebota a otro enemigo con el 50% del daño. |
| Eco Arcano (`ecoArcano`) | al usar una habilidad mágica (no ULT), 20% | Se repite gratis: 50% del daño base (sin crítico) a los mismos objetivos vivos y vuelve a aplicar su estado. |
| Marca del Cazador (`marcaCazador`) | al golpear a un enemigo sin marca | Lo marca: recibe +15% de daño de todos por 3 turnos (suyos). |
| Punto Débil (`puntoDebil`) | condición: el objetivo está marcado | +20% crítico contra él. |
| Debilitar (`debilitar`) | al aplicar Veneno | El enemigo pega −15% ATQ por 2 turnos. No acumula. |
| Plaga Contagiosa (`plagaContagiosa`) | al morir un enemigo envenenado (cualquier causa) | Sus stacks de Veneno pasan al enemigo vivo con más vida. |
| Viento a Favor (`vientoFavor`) | después de una habilidad de daño a todos (no ULT) | Ataque básico gratis inmediato al enemigo vivo con menos vida. |
| Rebote (`rebote`) | acción de daño a un solo objetivo | Rebota a otro enemigo con el 40% del daño. |
| Mano Sanadora (`manoSanadora`) | al curar con una habilidad (Cura, Aura, Baluarte...) | Cada aliado curado gana un escudo del 20% de lo curado por 3 turnos. |
| Plegaria (`plegaria`) | al empezar tu turno | El aliado vivo con menor % de vida se cura 5% de su vida máx. |
| Guardián (`guardian`) | cuando recibís un golpe dirigido a un aliado (Protección) | +8 carga de ULT. |
| Desafío (`desafio`) | al usar Provocar, Protección o Escudo de Fe | Escudo del 15% de tu vida máx. por 2 turnos. |
| Martillo Bendito (`martilloBendito`) | tus aturdimientos (no a jefes) | Duran 1 turno más. |
| Castigo Divino (`castigoDivino`) | al aturdir a un enemigo | Daño sagrado `MAG × 0.6` a ese enemigo. |

"Acción a un solo objetivo": ataque básico (sin Golpe Imparable),
habilidad o ULT de daño que no es a todos. "Habilidad mágica": `kind`
mágica (MAG).

## 4. Keystones (una por camino)

Las 8 de la v1 mantienen exactamente su efecto:

| Keystone (id) | Camino | Efecto |
|---|---|---|
| Golpe Imparable (`imparable`) | Muralla | El ataque básico golpea a TODOS al 60%. |
| Furia de Sangre (`furia`) | Sangre | +35% ATQ, −4 DEF. |
| Mente sobre Materia (`mente`) | Arcano | +30% MAG, −20% vida máx. |
| Tormenta Arcana (`tormenta`) | Brasa | Habilidades a todos +25%; a uno −15%. |
| Ojo de Halcón (`halcon`) | Precisión | Críticos ×2.0, −15% ATQ. |
| Toxicidad (`toxicidad`) | Toxina | +2 Veneno en habilidades, −10% ATQ. |
| Paladín Creyente (`creyente`) | Fe | Aura daña `MAG × 0.8`; básico 25% cura 2% a todos. Excluye Inherente. |
| Paladín Inherente (`inherente`) | Juicio | Básico 25% Sagrado. Excluye Creyente. |

Nuevas (4):

| Keystone (id) | Camino | Efecto | Trade-off |
|---|---|---|---|
| Danza de Cuchillas (`danza`) | Filo | Cada crítico te da otro turno inmediato (tu próximo turno = ahora). Un turno extra no da otro turno extra. | Tu crítico máximo baja a 40% (stats y en combate). |
| Alma de Hielo (`almaHielo`) | Escarcha | Mientras estés en pie, la Congelación de los enemigos no se derrite sola (solo se vacía al llegar a 5 y perder el turno). | No podés aplicar Quemadura. |
| Cadena Infinita (`cadena`) | Viento | Tus rebotes siguen saltando a todos los enemigos que no golpeó la cadena; cada salto hace el 60% del anterior. | Tus acciones a un solo objetivo hacen −20% de daño (el golpe principal). |
| Égida Eterna (`egida`) | Bastión | Al empezar tu turno ganás un escudo del 10% de tu vida máx. por 1 turno (no acumula: queda el mayor). | −20% ATQ y −20% MAG. |

## 5. Motor: disparadores, efectos y reglas de orden

Ver también combat.md § "Disparadores del árbol".

**Disparadores** (`ProcTrigger`): `onCrit`, `onHit`, `onKill`,
`onEnemyDeath`, `onHitTaken`, `onProtectHit`, `onStatusApplied`,
`onSkill`, `onHeal`, `onTurnStart`, y condiciones que modifican el
cálculo: `whileLowHealth`, `vsStatus`, `vsMarked`.

**Efectos** (`ProcEffectKind`): `buffSelf`, `debuffTarget`, `markTarget`,
`advanceTurn`, `extraTurn`, `healSelf`, `healLowestAlly`, `chain`,
`explode`, `reflect`, `shatterStun`, `delayTarget`, `repeatSkill`,
`spreadStatus`, `freeAttack`, `shieldHealed`, `shieldSelf`, `ultCharge`,
`stunExtend`, `holyDamage`, `statBonus`.

**Efectos con duración** (`TimedEffect` en el `Combatant`): stat
(`speed`, `attack`, `damageTaken`, `shield`, `stunLock`), valor, turnos
y origen (id de la mecánica). Duración N = N turnos del portador: al
**terminar** cada turno del portador (después de actuar, de defender, de
perder el turno o de agotar el tiempo, y antes de calcular su próximo
turno) se resta 1 y a 0 se quita; un efecto aplicado durante el propio
turno del portador empieza a descontar desde su turno siguiente
(`fresh`). Así Frenesí (2) acelera las 2 esperas siguientes, Represalia
(1) vale para el próximo ataque, la Marca (3) dura 3 turnos del enemigo
y Debilitar (2) sus 2 próximos ataques. Martillo Bendito (`stunLock`) se
consume cuando el aturdido pierde el turno. No acumulan:
aplicar de nuevo el mismo origen renueva (el escudo queda con el mayor
valor). Velocidad: `IV = 100 / (vel × (1 + buff_vel) × (1 − 0.12 ×
congelación))`. ATQ: `ATQ efectivo = round(ATQ × (1 + buff_atq +
Último Aliento))`. Enemigo debilitado: pega con `round(ATQ × (1 − 0.15))`.
Escudo: absorbe daño de golpes enemigos (no de estados) antes que la
vida; el número flotante y la carga de ULT usan el daño que pasa.

**Reglas que evitan bucles:**
1. Solo los **golpes primarios** de tu acción (ataque, habilidad, ULT,
   dúo) disparan `onHit`, `onCrit` y `onStatusApplied`. Lo que generan
   los notables (rebotes, explosiones, eco, ataque gratis, reflejo,
   contagio, daño sagrado, aturdir de Choque Térmico) es **secundario**:
   hace daño, puede matar y aplicar estados, pero no dispara nada nuevo.
   Excepciones: `onKill` cuenta cualquier muerte de tu acción (1 vez por
   acción) y `onEnemyDeath` (Plaga) cuenta cualquier muerte, pero solo
   aplican estados / turnos / curas, nunca daño.
2. Una mecánica dispara como máximo una vez por acción (las que afectan
   al objetivo: una vez por objetivo y acción).
3. Como máximo **1 rebote** por acción (si hay varios, gana el mayor %)
   salvo Cadena Infinita (cada enemigo una vez por cadena), **1
   explosión**, **1 eco**, **1 ataque gratis** por acción.
4. Tope de seguridad: 64 efectos disparados por paso del motor.

**Orden dentro de una acción:**
1. Golpes primarios, uno por objetivo: daño (con condiciones:
   Fractura, Marca, Punto Débil, Último Aliento, Cadena Infinita) →
   `onHit` → `onCrit` → estado de la habilidad → `onStatusApplied`.
2. `onSkill` / `onHeal`.
3. Resolución diferida, en este orden: rebote, explosión, eco, ataque
   gratis.
4. `onKill` (si murió algún enemigo en la acción).
5. Próximo turno: turno extra (Danza) → `reloj`; si no, adelanto (Sed de
   Sangre) → `reloj + IV × 0.5`; si no, `reloj + IV`.

Rebote: salta al siguiente enemigo vivo en orden (después del objetivo,
dando la vuelta) que no haya golpeado la cadena; daño = `round(daño del
golpe × %)`, después × 1.15 si está marcado; mín. 1. Daño secundario:
solo aplica la Marca del objetivo (no críticos, salvo el ataque gratis
de Viento a Favor, que tira crítico normal).

Todo está en el azar inyectado (`RandomSource`): solo se tira azar
extra si el jugador tiene la mecánica (Eco Arcano 20%, críticos del
ataque gratis), así que las batallas sin árbol v2 dan los mismos números
que antes.

**Eventos** (opcionales, compatibles hacia atrás):
`ProcEvent(actor, fuente, objetivo?)` cada vez que dispara una mecánica;
`BuffAppliedEvent(objetivo, fuente, stat, valor, turnos)`;
`ShieldEvent(objetivo, cantidad, absorbed)`; `DamageEvent.sourceId`
(id de la mecánica en el daño secundario). **Log**: cada efecto
disparado se agrega a la línea del log con su origen, p. ej.
`Frenesí: +20% velocidad (2 turnos)`, `Rebote: 7 a Murciélago`,
`Sed de Sangre: próximo turno 50% antes, +4 HP`.

**Red**: el `Combatant` serializa `mech` (mecánicas), `fx` (efectos con
duración) y `xt` (turno extra); los eventos nuevos tienen claves `proc`,
`buff`, `shield`. Todas opcionales al leer.

## 6. Migración (reinicio gratis)

El perfil guarda la versión del árbol (`tv`, hoy 2). Un perfil sin `tv`
o con `tv < 2` (árbol v1) que tenía nodos tomados se carga con el árbol
vacío: todos los puntos vuelven (los puntos se calculan como
`nivel − 1 − nodos`). El perfil recuerda cuántos nodos se devolvieron
(`treeRefunded`, clave `tvRef` en el JSON solo mientras no se normaliza)
y al entrar a la sala el sistema avisa una vez:
`<nombre>: el árbol de pasivas cambió; se reinició gratis y recuperaste
N puntos.`

## 7. UI

- Lienzo de 600 × 600 px (30 px por unidad) dentro de un visor con
  arrastre (mouse) y rueda para zoom (0.5×–2.5×); arranca ajustado al
  visor y centrado en tu clase.
- Nodos chicos: círculo r 6; inicio: r 9; notables: círculo r 9 con
  borde dorado; keystones: hexágono r 12. Colores de estado como la v1
  (inicio dorado, tomado verde, keystone tomada roja, disponible celeste,
  bloqueado gris azulado).
- Anillo central con un aro tenue; enlaces tomados en verde.
- Pasar el mouse por un nodo resalta su camino entero (enlaces dorados)
  y muestra un tooltip junto al nodo: nombre, tipo (NOTABLE /
  KEYSTONE), camino y tema, efectos (stats + texto completo de la
  mecánica) y estado. Clic: lo toma si se puede. El panel lateral
  muestra el nodo elegido, el botón TOMAR NODO con su motivo y la
  leyenda.
- Barra de batalla: chips de los efectos con duración (▲VEL, ▲ATQ,
  ▼ATQ, Marca, Escudo, Aturdido +1) y de Último Aliento activo, con
  tooltip que dice el origen y los turnos.

## 8. Decisiones del dueño

1. **Anillo central compartido**: cualquier clase puede llegar a la zona
   de otra.
2. **Los 12 caminos de § 2** quedan como están.
3. **Reinicio gratis** al migrar: los perfiles guardados recuperan todos
   los puntos del árbol viejo.
4. **(Temporal) Reiniciar es gratis siempre**: reiniciar el árbol y los
   puntos de atributo no cuesta nada y se puede en cualquier modo salvo
   en batalla (`ProgressionRules.freeRespec`, ver progression.md).
