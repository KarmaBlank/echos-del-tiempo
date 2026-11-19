# Spec (aprobada): Árbol de pasivas v3 — red de ~350 nodos

> **v0.6:** reemplazada en parte por `passive_tree_v4.md` (clusters con 4
> notables, ruta sin `r2`, punta notable en los grupos, `tv` 4). Lo que
> la v4 no nombra sigue valiendo como está acá.

Pedido del dueño (v0.5.0): "el árbol normal es muy pequeño". Propuesta
aprobada ("sí, dale"): ~350 nodos para que, con el máximo de puntos, un
personaje cubra ~20% del árbol y tenga que **elegir** (como en los ARPG de loot); los
caminos rectos de la v2 pasan a ser una **red con bifurcaciones**:
clusters temáticos por clase, **puentes híbridos** entre clases vecinas y
**clusters de grupo** pensados para el co-op (que sirven también solo).

Reemplaza a la v2 (`passive_tree_v2.md` queda como historia: sus 24
notables y 12 keystones siguen existiendo con el mismo id de mecánica y
el mismo efecto, ahora dentro de los clusters). Las reglas de puntos no
cambian (passive_tree.md § Reglas): 1 punto por nivel después del 1 más
la Maestría (`PlayerProfile.treeLevel = nivel + maestría`), el inicio de
la clase siempre está tomado y no cuesta, solo se toman nodos conectados
a uno que ya tenés, exclusión Creyente ↔ Inherente. **Reiniciar es
gratis siempre** (`ProgressionRules.freeRespec`).

Implementación:
- Datos: `lib/game_engine/data/passive_tree_catalog.dart` (`kPassiveTree`,
  `kPassiveTreeVersion = 3`; el dibujo se genera desde las definiciones
  de cluster con ids determinísticos) y
  `lib/game_engine/data/passive_mechanics.dart` (`kMechanics`).
- Migración: `lib/game_engine/rules/passive_tree_migration.dart`.
- Reglas: `passive_tree_rules.dart` (`aggregate`, `pathTo`),
  `stats_calculator.dart`, `battle_engine.dart`.
- UI: `lib/features/passive_tree/**`.
- Tests: `test/game_engine/passive_tree_catalog_test.dart`,
  `passive_tree_v3_mechanics_test.dart`, `passive_tree_balance_test.dart`
  (compara con la v2, que vive como dato de test en
  `test/game_engine/fixtures/passive_tree_v2_catalog.dart`),
  `player_profile_test.dart` (migración),
  `test/features/passive_tree/passive_tree_view_test.dart`.

## 1. Números

| | v2 | v3 |
|---|---|---|
| Nodos | 112 | **352** |
| Notables | 24 | **60** |
| Keystones | 12 | **20** |
| Puntos máx. (nivel 50 + 20 Maestría) | 69 | 69 (≈ 19.6% del árbol) |

Desglose v3: 4 inicios + 12 anillo + 28 de rutas de clase (7 × 4) +
220 de clusters de clase (11 × 20) + 48 de puentes (12 × 4) + 40 de
clusters de grupo (10 × 4) = 352.

## 2. Forma y coordenadas

Unidades de árbol (la UI multiplica por 30 px; centro (0, 0); y hacia
abajo; ángulo 0° = derecha, crece en sentido horario). Ángulo de clase
θ: Guerrero −90° (arriba), Maga 0° (derecha), Tirador 90° (abajo),
Paladín 180° (izquierda). `polar(r, a) = (r·cos a, r·sin a)`.

Marco local de un elemento orientado al ángulo φ: `P = (R + u)·dir(φ) +
v·dir(φ + 90°)` (u hacia afuera, v lateral: v < 0 hacia el ángulo menor).

- **Anillo central** (12 nodos, mismos ids, nombres y efectos que la v2):
  radio 2.0, uno cada 30° desde −90°, en ciclo. Los 4 umbrales (`p_gue`,
  `p_mag`, `p_tir`, `p_pal`) enlazan con el inicio de su clase.
- **Inicios** (`s_gue`, `s_mag`, `s_tir`, `s_pal`): radio 3.1 en θ, mismos
  ids y efectos.
- **Ruta de clase** (7 nodos, ids `<c>_r1`, `<c>_r2`, `<c>_f1`..`<c>_f5`,
  `<c>` = `gue`/`mag`/`tir`/`pal`): `r1` radio 4.0 y `r2` radio 4.9 en θ;
  el **abanico** `f1..f5` a radio 6.0 en θ −30°, −15°, 0°, +15°, +30°,
  en cadena `f1–f2–f3–f4–f5`. Enlaces: inicio–r1–r2–f3.
- **Clusters de clase** (5 por clase, en el orden de la tabla § 4 = de
  ángulo menor a mayor): el cluster `i` (0..4) está en φ = θ + (i − 2)·15°,
  enlazado desde `f(i+1)`, con su entrada a radio R = 7.0. Plantilla
  (u, v):

  | Id | (u, v) | Tipo | Enlaces |
  |---|---|---|---|
  | `_e1` | (0, 0) | chico A | `f(i+1)`, `_e2` |
  | `_e2` | (0.8, 0) | chico A | `_f` |
  | `_f` | (1.6, 0) | chico A (bifurcación) | `_a1`, `_b1` |
  | `_a1`, `_a2` | (2.35, −0.65), (3.15, −0.85) | chicos A | en cadena |
  | `_na` | (3.95, −0.95) | NOTABLE A | `_a2`, `_j` |
  | `_b1`, `_b2` | (2.35, 0.65), (3.15, 0.85) | chicos B | en cadena |
  | `_nb` | (3.95, 0.95) | NOTABLE B | `_b2`, `_j` |
  | `_j` | (4.65, 0) | chico B (unión) | `_na`, `_nb`, `_k` |
  | `_k` | (5.55, 0) | KEYSTONE | `_j` |

  **Atajos** entre clusters vecinos de la misma clase: `_b2` del cluster
  `i` ↔ `_a2` del cluster `i+1` (red: se llega a un notable vecino sin
  pasar por su entrada).
- **Puentes híbridos** (4, uno por par de clases vecinas, en la diagonal
  δ = θ + 45° de la primera): marco local con R = 0, φ = δ.

  | Id | (u, v) | Tipo | Enlaces |
  |---|---|---|---|
  | `_a1`, `_a2` | (11.6, −1.6), (12.4, −0.8) | chicos lado A | `_nb` del cluster 4 de la clase A, cadena, `_h` |
  | `_b1`, `_b2` | (11.6, 1.6), (12.4, 0.8) | chicos lado B | `_na` del cluster 0 de la clase B, cadena, `_h` |
  | `_h` | (13.2, 0) | chico híbrido | `_n1` |
  | `_n1` | (14.0, 0) | NOTABLE | `_l1`, `_r1` |
  | `_l1`, `_l2` | (14.7, −0.7), (15.4, −1.1) | chicos lado A | cadena |
  | `_nl` | (16.2, −1.3) | NOTABLE | `_l2` |
  | `_r1`, `_r2` | (14.7, 0.7), (15.4, 1.1) | chicos lado B | cadena |
  | `_nr` | (16.2, 1.3) | NOTABLE | `_r2` |
- **Clusters de grupo** (4, en las diagonales δ = −45°, 45°, 135°, 225°,
  entre los dos nodos de anillo de δ ± 15°): marco local R = 0, φ = δ.

  | Id | (u, v) | Tipo | Enlaces |
  |---|---|---|---|
  | `_e1` | (2.9, 0) | chico A | los 2 nodos de anillo, `_e2` |
  | `_e2` | (3.7, 0) | chico A | `_a1`, `_b1` |
  | `_a1`, `_a2` | (4.45, −0.45), (5.25, −0.55) | chicos A | cadena |
  | `_na` | (6.05, −0.55) | NOTABLE A | `_a2`, `_j` |
  | `_b1`, `_b2` | (4.45, 0.45), (5.25, 0.55) | chicos B | cadena |
  | `_nb` | (6.05, 0.55) | NOTABLE B | `_b2`, `_j` |
  | `_j` | (6.75, 0) | chico B | `_t` |
  | `_t` | (7.55, 0) | chico A (punta) | — |

Todo nodo guarda su cluster (`pathId`) y el catálogo tiene un
`PassivePath` por cluster/puente/grupo (`kind`: `clase`, `puente`,
`grupo`) con la posición de su etiqueta (más allá de la keystone; puente:
(17.2, δ); grupo: (8.4, δ)). Ningún par de nodos queda a menos de 0.75
unidades (test).

**Costo de viajar** (puntos antes del primer nodo del cluster, desde tu
inicio): cluster central de tu clase 3 (`r1`, `r2`, `f3`); los de los
costados 4 y 5; cluster de grupo 2 (umbral + nodo de anillo); zona vecina
8 a 10 (anillo + inicio vecino + su ruta); zona opuesta 11 a 13. Un
puente se alcanza por el notable del cluster de borde (≥ 11 desde tu
inicio).

## 3. Rutas de clase

| Clase | r1 | r2 | f1..f5 (cada uno) |
|---|---|---|---|
| Guerrero | Disciplina +3% ATQ | Temple +3% vida | Sendero del Acero +2% ATQ, +3% vida |
| Maga | Estudio +3% MAG | Reserva Arcana +4% maná | Sendero Arcano +2% MAG, +4% maná |
| Tirador | Ojo Atento +1.5% crítico | Paso Ágil +0.15 vel. | Sendero del Viento +1% crítico, +2% ATQ |
| Paladín | Voto +1 DEF | Devoción +3% vida | Sendero Sagrado +3% vida, +3% curación |

## 4. Clusters de clase

Chicos A = `_e1`, `_e2`, `_f`, `_a1`, `_a2` (5); chicos B = `_b1`, `_b2`,
`_j` (3). Los notables dan además el stat indicado. ★ = nuevo en v3.

| Clase | i | Cluster (id) | Tema | Chico A | Chico B | Notable A (+stat) | Notable B (+stat) | Keystone |
|---|---|---|---|---|---|---|---|---|
| Guerrero | 0 | Muralla (`muralla`) | defensa, contraataque | Coraza +1 DEF | Aguante +3% vida | Contraataque (+2 DEF) | Represalia (+3% vida) | Golpe Imparable |
| Guerrero | 1 | Sangre (`sangre`) | robo de vida, poca vida | Fuerza Bruta +3% ATQ | Vigor +3% vida | Último Aliento (+3% vida) | Sed de Sangre (+3% ATQ) | Furia de Sangre |
| Guerrero | 2 | ★ Quiebre (`quiebre`) | quebrar enemigos | Impacto +3% ATQ | Firmeza +3% vida | ★ Rompeguardias (+3% ATQ) | ★ Ensañamiento (+3% ATQ) | ★ Demoledor |
| Guerrero | 3 | ★ Gritos (`gritos`) | ULT y gritos de grupo | Aliento +3% carga ULT | Pulmones +3% vida | ★ Clamor (+3% ATQ) | ★ Rugido (+4% carga ULT) | ★ Caudillo |
| Guerrero | 4 | Filo (`filo`) | críticos y velocidad | Filo Agudo +1.5% crítico | Pies Ligeros +0.15 vel. | Frenesí (+1.5% crítico) | Corte en Cadena (+3% ATQ) | Danza de Cuchillas |
| Maga | 0 | Arcano (`arcano`) | maná, ULT, cadenas | Concentración +4% maná | Afinidad +3% carga ULT | Arco Voltaico (+3% MAG) | Eco Arcano (+4% maná) | Mente sobre Materia |
| Maga | 1 | Brasa (`brasa`) | quemadura, explosiones | Ascua +3% MAG | Reserva +4% maná | Combustión (+1 Quemadura) | Choque Térmico (+3% MAG) | Tormenta Arcana |
| Maga | 2 | ★ Cronos (`cronos`) | retrasos y timeline | Segundero +3% MAG | Péndulo +0.15 vel. | ★ Reloj Roto (+0.15 vel.) | ★ Paso Compartido (+0.15 vel.) | ★ Bucle Eterno |
| Maga | 3 | Escarcha (`escarcha`) | congelación | Escarcha +3% MAG | Calma Helada +0.15 vel. | Tiempo Gélido (+1 Congelación) | Fractura (+3% MAG) | Alma de Hielo |
| Maga | 4 | ★ Prisma (`prisma`) | elementos combinados | Facetas +2% MAG, +2% maná | Lente +3% vida | ★ Refracción (+3% carga ULT) | ★ Catalizador (+3% carga ULT) | ★ Singularidad |
| Tirador | 0 | Viento (`viento`) | velocidad, ataques extra | Reflejos +0.15 vel. | Ráfaga +3% ATQ | Viento a Favor (+0.15 vel.) | Rebote (+3% ATQ) | Cadena Infinita |
| Tirador | 1 | ★ Lluvia (`lluvia`) | habilidades a todos | Carcaj +3% ATQ | Aljaba +3% carga ULT | ★ Aguacero (+3% ATQ) | ★ Esquirlas (+0.15 vel.) | ★ Diluvio |
| Tirador | 2 | Precisión (`precision`) | críticos, marca | Puntería +1.5% crítico | Tensión +3% ATQ | Marca del Cazador (+1.5% crítico) | Punto Débil (+3% ATQ) | Ojo de Halcón |
| Tirador | 3 | ★ Acecho (`acecho`) | marcas y remate | Rastro +1% crítico, +0.1 vel. | Sigilo +0.15 vel. | ★ Presa Herida (+1.5% crítico) | ★ Rematar (+3% ATQ) | ★ Depredador |
| Tirador | 4 | Toxina (`toxina`) | veneno, debilitar | Ponzoña +3% ATQ | Resistencia +3% vida | Debilitar (+1 Veneno) | Plaga Contagiosa (+3% ATQ) | Toxicidad |
| Paladín | 0 | ★ Luz (`luz`) | Sagrado | Destello +2% MAG, +2% curación | Calidez +4% curación | ★ Llama Sagrada (+3% MAG) | ★ Resplandor (+4% curación) | ★ Sol Interior |
| Paladín | 1 | Juicio (`juicio`) | daño sagrado, aturdir | Celo +3% ATQ | Rigor +1.5% crítico | Martillo Bendito (+3% ATQ) | Castigo Divino (+3% MAG) | Paladín Inherente |
| Paladín | 2 | Fe (`fe`) | curación | Gracia +4% curación | Fe +3% vida | Mano Sanadora (+5% curación) | Plegaria (+3% vida) | Paladín Creyente |
| Paladín | 3 | ★ Vigilia (`vigilia`) | reducción de daño | Centinela +1 DEF | Entereza +3% vida | ★ Guardia Alta (+1 DEF) | ★ Voto de Hierro (+3% vida) | ★ Inamovible |
| Paladín | 4 | Bastión (`bastion`) | escudos, provocar | Templanza +1 DEF | Firmeza +3% vida | Guardián (+2 DEF) | Desafío (+3% vida) | Égida Eterna |

Exclusiones: `fe_k` (Creyente) ↔ `juicio_k` (Inherente).

## 5. Notables nuevos (mecánicas)

Mismo sistema que la v2 (passive_tree_v2.md § 3 y § 5): disparador +
filtro + probabilidad + efectos, sin código por notable. Reglas de
orden, "golpe primario" y topes de la v2 sin cambios.

| Notable (id) | Disparador | Efecto exacto |
|---|---|---|
| Rompeguardias (`rompeguardias`) | siempre | Tus golpes llenan la barra de quiebre +30%. |
| Ensañamiento (`ensanamiento`) | condición: objetivo quebrado (★ `vsBroken`) | +25% de daño a ese objetivo. |
| Clamor (`clamor`) | al usar tu ULT | Todo el grupo +15% ATQ (2 turnos). |
| Rugido (`rugido`) | al matar (1 por acción) | +5 de carga de ULT para vos y +8 para cada aliado. |
| Reloj Roto (`relojRoto`) | al retrasar a un enemigo | Tu próximo turno llega 25% antes. |
| Paso Compartido (`pasoCompartido`) | al retrasar a un enemigo | El aliado más lento se adelanta 20% de su espera (solo: tu próximo turno 20% antes). |
| Refracción (`refraccion`) | condición: objetivo con 2+ estados elementales distintos | +15% de daño. |
| Catalizador (`catalizador`) | al aplicar Quemadura / Congelación / Veneno, 50% | +1 stack del primer elemento que el objetivo no tiene. |
| Aguacero (`aguacero`) | siempre, en habilidades a todos (no ULT) | +15% de daño. |
| Esquirlas (`esquirlas`) | después de una habilidad a todos (no ULT) | Tu próximo turno llega 20% antes. |
| Presa Herida (`presaHerida`) | condición: objetivo marcado | +15% de daño. |
| Rematar (`rematar`) | golpe a un solo objetivo | Remata (no jefes ni élites) si queda con menos de 12% de vida. |
| Llama Sagrada (`llamaSagrada`) | golpe a un solo objetivo, 30% | +1 Sagrado al objetivo. |
| Resplandor (`resplandor`) | condición: objetivo con Sagrado | +20% de daño. |
| Guardia Alta (`guardiaAlta`) | al recibir un golpe defendiendo | Escudo del 10% de tu vida máx. (2 turnos). |
| Voto de Hierro (`votoHierro`) | condición: vida < 50% (★ guarda por condición) | Recibís −15% de daño. |

Puentes y grupo: ver § 7 y § 8.

## 6. Keystones (20)

Las 12 de la v2 sin cambios (passive_tree_v2.md § 4). Nuevas (8), todas
con su contra:

| Keystone (id) | Cluster | Efecto | Contra |
|---|---|---|---|
| Demoledor (`demoledor`) | Quiebre | Cuando cualquier aliado (o vos) quiebra a un enemigo: +20 de carga de ULT y +25% ATQ (2 turnos, renueva). | −15% vida máx. |
| Caudillo (`caudillo`) | Gritos | Al empezar tu turno: todo el grupo +12% ATQ (1 turno, renueva). | −30% carga de ULT. |
| Bucle Eterno (`bucle`) | Cronos | Tus retrasos son 60% más largos. | −1 velocidad. |
| Singularidad (`singularidad`) | Prisma | Contra enemigos con 2+ estados elementales: +30% de daño y +10% crítico. | −10% MAG. |
| Diluvio (`diluvio`) | Lluvia | Tus habilidades a todos (no ULT) se repiten gratis al 40% (1 eco por acción, como Eco Arcano). | −15% ATQ. |
| Depredador (`depredador`) | Acecho | Cada golpe tuyo marca al objetivo sin marca: +25% de daño recibido de todos (3 turnos). | −20% vida máx. |
| Sol Interior (`solInterior`) | Luz | Cada golpe primario tuyo aplica 1 Sagrado. | −15% ATQ. |
| Inamovible (`inamovible`) | Vigilia | Recibís −25% de daño (suma con la defensa de grupo; tope 60%). | −1 velocidad. |

Las contras numéricas las aplica `PassiveTreeRules.aggregate` (igual que
`furia`, `mente`...). El texto del tooltip de una keystone con mecánica
es `Nombre: descripción` (la descripción incluye la contra).

## 7. Puentes híbridos

Chicos lado A = `_a1`, `_a2`, `_l1`, `_l2`; lado B = `_b1`, `_b2`, `_r1`,
`_r2`; `_h` = híbrido.

| Puente (id) | Clases (δ) | Chico A | Chico B | Híbrido | Notables (`_n1`, `_nl`, `_nr`) |
|---|---|---|---|---|---|
| Hoja Arcana (`hojaArcana`) | Guerrero–Maga (−45°) | Temple Rúnico +3% ATQ | Runa de Filo +2% MAG +2% carga ULT | Acero Arcano +2% ATQ +2% MAG | Filo Rúnico, Hechizo Afilado, Égida Rúnica |
| Runas (`runas`) | Maga–Tirador (45°) | Glifo +2% MAG +2% carga ULT | Mira Rúnica +1.5% crítico | Runa Certera +2% MAG +1% crítico | Ojo Arcano, Sobrecarga, Disparo Rúnico |
| Centinela (`centinela`) | Tirador–Paladín (135°) | Vigía +1.5% crítico | Escudo Ligero +1 DEF | Guardia Atenta +1% crítico +3% vida | Ojo del Vigía, Saeta Sagrada, Cobertura |
| Coloso (`coloso`) | Paladín–Guerrero (225°) | Muro +1 DEF | Mole +3% vida | Coloso +3% vida +1 DEF | Piel de Piedra, Desquite, Peso Muerto |

El lado A es la clase del ángulo menor (la primera del par).

| Notable (id) | Disparador | Efecto exacto |
|---|---|---|
| Filo Rúnico (`filoRunico`) | al usar una habilidad mágica (no ULT) | +20% ATQ (2 turnos, renueva). |
| Hechizo Afilado (`hechizoAfilado`) | habilidad mágica a un solo objetivo | +1 Quemadura al objetivo. |
| Égida Rúnica (`egidaRunica`) | al usar una habilidad mágica (no ULT) | Escudo del 8% de tu vida máx. (2 turnos). |
| Ojo Arcano (`ojoArcano`) | siempre, en habilidades mágicas (no ULT) | +15% crítico. |
| Sobrecarga (`sobrecarga`) | al hacer crítico | +8 de carga de ULT. |
| Disparo Rúnico (`disparoRunico`) | al hacer crítico a un solo objetivo | Lo marca: +10% de daño recibido (2 turnos). |
| Ojo del Vigía (`vigia`) | al recibir un golpe | Marca al atacante: +15% de daño recibido de todos (3 turnos). |
| Saeta Sagrada (`saetaSagrada`) | al hacer crítico | +1 Sagrado al objetivo. |
| Cobertura (`cobertura`) | al empezar tu turno | El aliado con menor % de vida (vos incluido) gana un escudo del 6% de tu vida máx. (1 turno). |
| Piel de Piedra (`pielPiedra`) | al recibir un golpe | Escudo del 5% de tu vida máx. (1 turno, no acumula). |
| Desquite (`desquite`) | al recibir un golpe con menos de 50% de vida | Devolvés el 40% del daño. |
| Peso Muerto (`pesoMuerto`) | al recibir un golpe | +15% ATQ (2 turnos, renueva). |

Nota (v0.5): el Paladín ya no tiene kit fijo de clase (Aura, Fortaleza y
Protección pasan a la ascensión Guardián). Ningún notable o keystone
**nuevo** de la v3 depende de esas habilidades: los de la zona Paladín
se basan en golpes, Sagrado, escudos, DEF y vida. Los de la v2 que las
usan (Desafío, Guardián, Paladín Creyente) siguen igual y valen con
cualquier fuente de esas habilidades (armas, ascensión).

## 8. Clusters de grupo (co-op)

Pensados para jugar en grupo, pero con efecto también solo (el dueño es
parte del grupo). Chicos A = `_e1`, `_e2`, `_a1`, `_a2`, `_t`; chicos B
= `_b1`, `_b2`, `_j`.

| Cluster (id) | δ (anillo) | Chico A | Chico B | Notable A | Notable B |
|---|---|---|---|---|---|
| Estandarte (`estandarte`) | −45° (`r_gm1`, `r_gm2`) | Asta +2% ATQ, +2% MAG | Hermanos de Armas +3% vida | Bandera de Guerra | Carga Conjunta |
| Sintonía (`sintonia`) | 45° (`r_mt1`, `r_mt2`) | Compás +3% carga ULT | Ritmo +0.15 vel. | Relevo | A la Carga |
| Vínculo (`vinculo`) | 135° (`r_tp1`, `r_tp2`) | Lazo +3% curación | Cuidado +3% vida | Lazo Vital | Escudo Compartido |
| Refugio (`refugio`) | 225° (`r_pg1`, `r_pg2`) | Trinchera +1 DEF | Abrigo +3% vida | Formación | Hermandad |

| Notable (id) | Disparador | Efecto exacto |
|---|---|---|
| Bandera de Guerra (`banderaGuerra`) | aura: mientras estés en pie | Todo el grupo (vos incluido) hace +5% de daño. |
| Carga Conjunta (`cargaConjunta`) | cuando cualquier aliado (o vos) quiebra a un enemigo | Todo el grupo +10% ATQ (2 turnos). |
| Relevo (`relevo`) | al usar tu ULT | +10 de carga de ULT a cada aliado y +5 para vos. |
| A la Carga (`alaCarga`) | al matar (1 por acción) | El aliado más lento se adelanta 20% (solo: tu próximo turno 20% antes). |
| Lazo Vital (`lazoVital`) | al matar (1 por acción) | Todo el grupo se cura 4% de su vida máx. |
| Escudo Compartido (`escudoCompartido`) | al usar tu ULT | Todo el grupo gana un escudo del 10% de tu vida máx. (2 turnos). |
| Formación (`formacion`) | aura: mientras estés en pie | Todo el grupo recibe −5% de daño. |
| Hermandad (`hermandad`) | al empezar tu turno | El aliado con menor % de vida se cura 3% de su vida máx. |

## 9. Motor

Se reusan los disparadores y efectos de la v2 y de la ascensión
(ascension.md § 3.1). Cambios:

1. **Disparador nuevo `vsBroken`** (condición): el objetivo está quebrado
   (`Combatant.broken`, break_and_enemy_ults.md). Suma en
   `_conditionParts` y en `_breakBonus`, como `vsStatus`.
2. **Guarda por condición**: `statBonus` de `BuffStat.guard` en una
   mecánica propia (`always`, `whileLowHealth`...) suma a la reducción de
   daño recibido junto con los buffs y auras de guarda (tope 60%,
   `BattleEngine.maxGuard`). Antes solo contaban buffs y auras.

Todo lo demás (efectos de grupo, trampas, eco, remate, marcas) ya
existía. Sin azar extra para quien no tiene las mecánicas: las batallas
sin árbol v3 dan los mismos números.

## 10. Balance

- Chicos: +3-4% (ATQ/MAG/vida +3%, maná +4%, curación +4%, carga ULT
  +3%, crítico +1.5%, vel. +0.15, DEF +1; algunos mixtos +2%/+2%). La v2
  daba +6%/+8%/+3%/+0.3: con 3 veces más nodos, cada uno vale menos.
- Notables: mecánica fuerte + un stat chico (a veces de otro tipo, para
  no apilar un solo stat). Keystones: cambian el build y traen una contra.
- **Chequeo** (`passive_tree_balance_test.dart`, contra la v2 congelada
  en `test/game_engine/fixtures/`). Con 69 puntos se arma el build
  "codicioso" (BFS desde lo tomado; toma el camino de mejor valor por
  punto; el valor de un nodo incluye las contras fijas de su keystone):
  1. **Un solo stat** (vida, ATQ, MAG, crítico, velocidad, DEF, maná):
     la v3 da como mucho **1.6×** el bono de la v2 (especializarse rinde
     más, porque hay más nodos de cada stat, pero sin desbordar). La DEF
     se compara con su tope real (3% de reducción por punto, máx. 60%).
  2. **Build mixto** de la clase (suma ponderada de todos los stats):
     la v3 queda entre **0.7× y 1.25×** de la v2 (hoy ≈ 0.78×: menos stat
     bruto, a cambio de 60 notables y 20 keystones a elegir).
  3. **Build representativo** (Guerrero: Muralla + Sangre + Filo
     completos): mismas mecánicas que en la v2 y bono ≤ 1.25×, aunque
     cuesta 40 puntos en vez de 24.
  Valores medidos al cerrar la v3 (bono v2 → v3): vida 1.14 → 1.6, ATQ
  1.45 → 1.74, MAG 0.95 → 1.5, crítico 0.37 → 0.59, velocidad 3.2 →
  4.8, maná 0.66 → 0.86.

## 11. Migración (reinicio gratis)

El perfil guarda la versión del árbol (`tv`, ahora 3). Al cargar un
perfil (`PlayerProfile.fromJson` → `migrateTreeIds`):

- `tv` 3: sin cambios (los ids desconocidos los descarta
  `ProgressionRules.normalize`, que nunca falla).
- `tv` 2: se conservan solo los nodos que **existen igual** en la v3
  (mismo id y mismo efecto: el anillo central y los inicios de clase),
  en el orden tomado y solo si siguen conectados; el resto se devuelve
  (todos los puntos de los caminos viejos vuelven).
- Sin `tv` o `tv` < 2 (v1): se devuelve todo.

Los puntos devueltos quedan en `treeRefunded` (clave `tvRef` mientras no
se normaliza) y la sala avisa una vez: `<nombre>: el árbol de pasivas
cambió; se reinició gratis y recuperaste N puntos.` Reiniciar el árbol
sigue siendo gratis en cualquier momento fuera de batalla.

## 12. Red

Los ids de nodo viajan en el perfil (`tree` + `tv`) y las mecánicas en el
`Combatant` (`mech`). El host migra/normaliza el perfil que recibe igual
que uno de disco, así que un `tv` 2 no rompe nada. `kProtocolVersion` ya
es 5 para la v0.5.0 (que sale junto con este árbol): un cliente v0.4
(protocolo 4) no puede entrar. No se sube de nuevo.

## 13. UI

- Lienzo de 1080 × 1080 px (30 px por unidad) dentro de un visor con
  arrastre y rueda (zoom 0.3×–2.5×). Botones `+`, `−`, `TODO` (encuadra
  el árbol entero) y `MI CLASE` (centra tu zona). Arranca centrado en tu
  zona.
- **Buscador**: un campo de texto; resalta (aro celeste) los nodos cuyo
  nombre, cluster, tema, efectos o mecánica contienen el texto (sin
  distinguir mayúsculas ni tildes) y dice cuántos hay. `Enter` centra el
  visor en el primero.
- **Camino**: al pasar el mouse por un nodo que todavía no tenés, se
  resaltan en dorado los nodos que faltan para llegar (`pathTo`: camino
  más corto desde lo que ya tenés, respetando la exclusión) y el
  tooltip dice el costo (`Costo: N puntos`).
- Tooltip: nombre, tipo (NOTABLE / KEYSTONE / INICIO), cluster y tema,
  efectos (stats + texto completo de la mecánica, keystones con su
  contra), costo y estado.
- Etiquetas: nombre de cada cluster más allá de su keystone; puentes y
  grupos con su etiqueta en su posición. Leyenda en el panel lateral
  (estados, notable, keystone, búsqueda, camino).
- Nodos: chicos r 5, inicio r 9, notables r 8 con borde dorado,
  keystones hexágono r 11. Colores de estado como la v2.
- Fluido a 1280 × 720: el dibujo es un solo `CustomPaint`; las
  etiquetas se miden una sola vez (cache) y el estado de los nodos se
  calcula una vez por build.
