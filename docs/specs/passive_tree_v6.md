# Spec: Árbol de pasivas v6 — el doble de nodos y de puntos (v0.8)

Pedido del dueño (v0.8): "el doble de nodos y de puntos". Y, para todos
los nodos nuevos: "que los nodos sigan la premisa de hacer efectos, ya sea
con la clase o con efectos de estado".

Parte del árbol v5 (`passive_tree_v4.md`, con las reacciones de su § 8),
que queda **entero y sin tocar**: mismos ids, posiciones, nombres,
efectos y mecánicas. La v6 solo agrega un anillo exterior y enlaces
hacia él; todo build v5 sigue siendo válido (no hay reinicio).

Implementación: `lib/game_engine/data/passive_tree_v6.dart` (datos:
clusters, puentes, grupos, mecánicas, chicos y contras),
`lib/game_engine/data/passive_tree_catalog.dart` (geometría, `_buildV6`),
`lib/game_engine/data/passive_mechanics.dart` (registra `kTreeV6Mechanics`
y `kTreeV6SmallMechanics` en `kMechanics`),
`lib/game_engine/rules/passive_tree_rules.dart` (`pointsPerLevel`,
`pointsEarned`, contras v6), `lib/game_engine/rules/battle_engine.dart`
(buffs de daño con duración, § 5) y
`lib/features/passive_tree/presentation/passive_tree_view.dart` (§ 9).
Tests: `passive_tree_catalog_test.dart`, `passive_tree_v6_mechanics_test.dart`,
`passive_tree_v6_points_test.dart`, `passive_tree_balance_test.dart` (v5
congelado en `test/game_engine/fixtures/passive_tree_v5_catalog.dart`),
`passive_tree_view_test.dart`.

## 1. Números

| | v5 | v6 |
|---|---|---|
| Nodos | 308 | **584** |
| Notables | 104 | **200** |
| Keystones | 20 | **36** |
| Chicos | 180 | 344 (164 nuevos, todos con efecto) |
| Clusters de clase | 20 | 32 (+12 exteriores) |
| Puentes | 4 | 8 (+4 elementales) |
| Clusters de grupo | 4 | 8 (+4 exteriores) |
| Puntos máx. (nivel 50 + Maestría 20) | 69 | **138** |
| Cobertura con el máximo | 22.4% | **23.6%** |

Desglose de lo nuevo: 12 clusters × 15 + 4 puentes × 15 + 4 grupos × 9 =
276 nodos (96 notables, 16 keystones, 164 chicos).

## 2. Forma (unidades de árbol; el lienzo pasa a ±23)

- **Clusters exteriores de clase** (3 por clase). El `j` (0, 1, 2) cuelga
  del notable de unión `_nc` del cluster v4 `j + 1` (los de θ − 15°, θ y
  θ + 15°) y sale en su mismo ángulo, con la entrada a R = 13.5
  (`kOuterRadius`). Marco local (u desde 13.5, v lateral):

  | Id | (u, v) | Tipo | Enlaces |
  |---|---|---|---|
  | `_s1` | (−2.0, 0.85) | chico A (tallo) | `_nc` v4, `_s2` |
  | `_s2` | (−1.0, 0.85) | chico A (tallo) | `_n1` |
  | `_n1` | (0, 0) | NOTABLE de entrada | `_m1` |
  | `_m1`, `_m2` | (0.8, 0), (1.6, 0) | chico A | `_m2` → `_na`, `_nb` |
  | `_na` / `_nb` | (2.4, ∓0.85) | NOTABLES de la bifurcación | `_ma` / `_mb` |
  | `_ma` / `_mb` | (3.2, ∓1.05) | chico B | `_ma2` / `_mb2` |
  | `_ma2` / `_mb2` | (4.0, ∓1.0) | chico B | `_nc` |
  | `_nc` | (4.6, 0) | NOTABLE de unión | `_m3` |
  | `_m3` | (5.4, 0) | chico B | `_nd` |
  | `_nd` | (6.2, 0) | NOTABLE de la cola | `_k` |
  | `_k` | (7.1, 0) | KEYSTONE (punta) | — |

  Atajo entre exteriores vecinos de la misma clase: `_mb2` del `j` ↔
  `_ma2` del `j + 1`. Etiqueta en u = 8.7. La etiqueta del cluster v4
  del que cuelga se corre al costado, a (5.95, −1.0) de su marco, para
  dejar libre el tallo (que sale por +v).
- **Puentes elementales** (uno detrás de cada puente v3, en la diagonal
  δ = θ + 45°; u = radio):

  | Id | (u, v) | Tipo | Enlaces |
  |---|---|---|---|
  | `_i1` | (17.2, 0) | chico X | `_nl` y `_nr` del puente v3, `_n1` |
  | `_a1`, `_a2` | (16.6, −6.4), (17.3, −5.0) | chico A | `_mb2` del último exterior de la clase A → `_a2` → `_na` |
  | `_na` | (18.0, −3.6) | NOTABLE | `_h1` |
  | `_h1` | (18.6, −1.8) | chico A | `_n1` |
  | `_b1`, `_b2`, `_nb`, `_h2` | espejo (v > 0) | chico B / NOTABLE | `_ma2` del primer exterior de la clase B |
  | `_n1` | (19.2, 0) | NOTABLE central | `_l1`, `_r1`, `_k` |
  | `_l1` / `_r1` | (19.9, ∓0.9) | chico X | `_nl` / `_nr` |
  | `_nl` / `_nr` | (20.6, ∓1.7) | NOTABLES | grupo exterior |
  | `_k` | (20.3, 0) | KEYSTONE | — |

  La etiqueta del puente v3 se mueve de u = 17.2 a u = 10.8 (el hueco
  entre su cluster de grupo y el puente); la del elemental va en u = 18.2.
- **Clusters de grupo exteriores** (detrás de cada puente elemental):
  `_e1` (21.4, 0) chico A enlazado a `_nl` y `_nr` del puente elemental →
  `_n0` (22.2, 0) NOTABLE → `_a1` / `_b1` (22.9, ∓0.7) chicos →
  `_na` / `_nb` (23.6, ∓1.1) NOTABLES → `_a2` / `_b2` (24.35, ∓0.75)
  chicos → `_nt` (25.0, 0) NOTABLE. Etiqueta en u = 26.
- Ningún par de nodos a menos de 0.75 (test); todo dentro de ±21.5 y las
  etiquetas de ±23.

Costos: el primer notable de cada cluster exterior está a **3 puntos**
del `_nc` v4 del que cuelga; la keystone exterior a 11 de ese hub. El
notable central de un puente elemental, a 2 de la punta del puente v3 (3
desde el cluster exterior de cada clase). El primer notable de un grupo
exterior, a 2 de las puntas del puente elemental.

## 3. Regla de los nodos nuevos (dueño)

Ningún nodo nuevo es un stat pelado:

- **Chicos**: un efecto chico atado al kit de la clase o a un estado,
  sin stats. Casi todos son modificadores (sin log ni cartel): daño o
  crítico contra un estado / familia / marcados, quiebre, golpe que
  detona, multiplicador de crítico a uno, defensa defendiendo, auras de
  grupo, potencia de buffs / escudos / trampas, reflejo de escudo, curas
  que dañan. Los únicos con disparo son "15% de +1 stack al aplicar
  Quemadura / Veneno / Congelación" (3 nodos por puente).
- Cada chico tiene **su propia mecánica con el id del nodo**
  (`kTreeV6SmallMechanics`; las mecánicas de un jugador son un conjunto
  de ids, así dos chicos iguales suman). La fuerza es la de un chico v5
  (+5% ATQ ≈ +6% de daño contra un estado).
- **Notables**: cambian la forma de jugar (disparadores y efectos).
- **Keystones**: definen el build y traen contra (§ 6).
- Los nodos v5 no cambian (siguen con su stat chico).

Chicos por cluster (A = tallo y entrada, B = ramas y cola; puente: X =
eje, A / B = brazos; grupo: A = `_e1`, `_a1`, `_a2`, B = `_b1`, `_b2`):

| Cluster | Chico A | Chico B (o X / A / B) |
|---|---|---|
| Verdugo | Tajo Certero: críticos a uno ×0.06 más | Sal y Acero: +8% vs. Aberraciones |
| Tempestad | Estática: +6% vs. Cargados | Oleaje: +4% crítico vs. Mojados |
| Vanguardia | Escolta: aura −1% daño recibido | Grito de Ánimo: buffs de grupo +6% |
| Marea | Gota: +6% vs. Mojados | Bajamar: +4% crítico vs. Mojados |
| Voltio | Chispa Viva: +8% quiebre vs. Cargados | Bobina: golpe que detona +5% |
| Alquimia | Reactivo: golpe que detona +5% | Destilado: +5% vs. 2+ elementos |
| Monzón | Llovizna: +4% crítico vs. Mojados | Tromba: habilidades a todos +4% |
| Centella | Gatillo Eléctrico: +4% crítico vs. Cargados | Voltaje: críticos a uno ×0.06 más |
| Montería | Trampero: trampas +8% | Rastreador: +5% vs. marcados |
| Exorcismo | Agua Bendita: +6% vs. Sagrado | Salmo: curas que dañan +10% |
| Manantial | Fuente: escudos al grupo +6% | Remanso: aura −1% daño recibido |
| Pararrayos | Toma de Tierra: defendiendo −4% | Descarga a Tierra: tus escudos reflejan 6% |
| Forja | X Yunque: quiebre +6% · A Martillazo: +10% quiebre vs. Quemadura | B Brasa Viva: 15% de +1 Quemadura |
| Galvánica | X Electrolito: +4% crítico vs. Mojados · A Condensador: detonar +4% | B Hilo de Cobre: +5% vs. Cargados |
| Eclipse | X Penumbra: +6% vs. envenenados · A Miasma: 15% de +1 Veneno | B Ofrenda: +4% crítico vs. Sagrado |
| Glaciar | X Permafrost: +6% vs. Congelación · A Escarcha Dura: defendiendo −4% | B Témpano: 15% de +1 Congelación |
| Táctica | Señal: +3% crítico vs. marcados | Coordinación: aura +1.5% daño |
| Coro | Compás Mayor: buffs de grupo +5% | Eco Coral: aura +1.5% daño |
| Santuario | Vela: aura −1.5% daño recibido | Incienso: aura Sagrado enemigo +10% |
| Fortaleza | Almena: escudos al grupo +6% | Bastión Común: aura −1.5% daño recibido |

## 4. Clusters exteriores de clase (notables)

Orden: `_n1`, `_na`, `_nb`, `_nc`, `_nd` (id de la mecánica entre
paréntesis). Todos con disparadores y efectos que ya existían.

**Guerrero**

| Cluster (cuelga de) | Notables |
|---|---|
| Verdugo (Sangre): rematar, cazar monstruos | Decapitar (`decapitar`): golpes a uno rematan con <15% (no jefes ni élites) · Quiebrahuesos (`quiebrahuesos`): No muertos +25% daño +10% crítico · Desguace (`desguace`): Constructos +25% / +10% · Cosecha (`cosecha`): al matar +20% ATQ 3 turnos · Ejecución Pública (`ejecucionPublica`): al matar, grupo +10% daño 2 turnos |
| Tempestad (Quiebre): Agua y Electro con el arma | Martillo Trueno (`martilloTrueno`): golpes a uno 25% de Cargado · Resaca (`resaca`): Electrocución → +25% ATQ 2 turnos · Trueno Sordo (`truenoSordo`): +40% quiebre vs. Cargados · Galerna (`galerna`): al quebrar (cualquiera), el quebrado queda Mojado · Ojo de la Tormenta (`ojoTormenta`): golpes a uno Mojado 30% de aturdir |
| Vanguardia (Gritos): proteger y empujar al grupo | Toque de Clarín (`toqueClarin`): ULT → aliados se adelantan 25% · Guardaespaldas (`guardaespaldas`): golpe absorbido por Protección refleja 30% · Ánimo Inquebrantable (`animoInquebrantable`): cae un aliado → grupo +20% ATQ 3 turnos · Formación Cerrada (`formacionCerrada`): golpe defendiendo → escudo 8% al más herido · Grito de Victoria (`gritoVictoria`): al matar +10 ULT a cada aliado |

**Maga**

| Cluster (cuelga de) | Notables |
|---|---|
| Marea (Brasa): Agua | Pleamar (`pleamar`): mojar retrasa 10% · Marejada (`marejada`): Congelación súbita → +15 ULT y turno 20% antes · Ahogo (`ahogo`): +20% vs. Mojados · Vórtice (`vortice`): habilidades a todos: Mojados −15% velocidad 2 turnos · Tsunami (`tsunami`): mágica a uno Mojado salpica 30% |
| Voltio (Cronos): Electro | Arco Eléctrico (`arcoElectrico`): cargar → rebote 35% · Sobretensión (`sobretension`): Electrocución → +15 ULT · Campo Magnético (`campoMagnetico`): cargar → −15% ATQ 2 turnos · Relámpago Globular (`relampagoGlobular`): Cortocircuito → turno 30% antes · Descarga en Cadena (`descargaCadena`): crítico → Cargado |
| Alquimia (Escarcha): reacciones en cadena | Solvente (`solvente`): Derretir deja Mojado · Transmutación (`transmutacion`): Electrocución deja 2 Veneno · Precipitado (`precipitado`): Explosión tóxica deja Congelación = ½ Venenos · Reacción en Cadena (`reaccionCadena`): al detonar, ½ de Quemadura / Congelación / Veneno restantes pasa a los demás · Piedra Filosofal (`piedraFilosofal`): golpe que detona +20% |

**Tirador**

| Cluster (cuelga de) | Notables |
|---|---|
| Monzón (Lluvia): Agua en área para el grupo | Aguanieve (`aguanieve`): habilidades a todos +1 Congelación a Mojados · Remojón (`remojon`): detonan un estado tuyo → +12 ULT · Tormenta Tropical (`tormentaTropical`): tras habilidad a todos, grupo +10% crítico · Inundación (`inundacion`): habilidades a todos marcan a los Mojados (+12%) · Ojo del Monzón (`ojoMonzon`): reacción del grupo → grupo se cura 3% |
| Centella (Precisión): Electro y críticos | Flecha Imantada (`flechaImantada`): crítico a uno → Cargado · Chispa Certera (`chispaCertera`): +20% crítico vs. Cargados · Electroshock (`electroshock`): Electrocución marca +20% · Tensión Máxima (`tensionMaxima`): Electrocución → turno 30% antes · Trueno Final (`truenoFinal`): muere un Cargado → el Cargado pasa al de más vida |
| Montería (Acecho): trampas y presas | Lazo de Caza (`lazoCaza`): salta tu trampa → marca +20% · Cazador de Arácnidos (`cazadorAracnidos`): +25% / +10% · Cazador de Cienos (`cazadorCienos`): +25% / +10% · Cepo (`cepo`): salta tu trampa → 30% de aturdir · Trofeo (`trofeo`): al matar +10 ULT y 5% de vida |

**Paladín**

| Cluster (cuelga de) | Notables |
|---|---|
| Exorcismo (Juicio): Sagrado contra no muertos | Exorcizar (`exorcizar`): Espectros +25% / +10% · Destierro (`destierro`): No muertos +30% · Consagración (`consagracion`): golpe a uno con Sagrado → +1 Sagrado · Cegar (`cegar`): golpe a uno con Sagrado → −15% ATQ · Juicio Final (`juicioFinal`): muere uno con Sagrado → su Sagrado pasa al de más vida |
| Manantial (Fe): curar y cuidar al grupo | Agua Bendecida (`aguaBendecida`): curar → +4 ULT · Marea Sanadora (`mareaSanadora`): ULT cura 10% al grupo · Bautismo (`bautismo`): cae un aliado → el resto se cura 15% · Fuente de Vida (`fuenteVida`): curar adelanta al más lento 15% · Desborde (`desborde`): cada cura también cura 3% al grupo |
| Pararrayos (Vigilia): Electro defensivo | Pararrayos (`pararrayos`): el que te pega queda Cargado · Jaula de Faraday (`jaulaFaraday`): golpe con <50% de vida → escudo 12% · Polo Opuesto (`poloOpuesto`): golpe absorbido por Protección → atacante Cargado y +4 ULT · Retorno a Tierra (`retornoTierra`): el que te pega −10% ATQ · Tormenta Protectora (`tormentaProtectora`): Provocar / Protección / Escudo de Fe → escudo 8% al grupo |

Ids que chocaban con habilidades (`gritoGuerra`, `luzCegadora`,
`graciaDesbordante`) se renombraron a `gritoVictoria`, `cegar` y
`desborde`.

## 5. Puentes elementales y grupos exteriores (notables)

| Puente / grupo | Notables (`_na`, `_nb`, `_n1`, `_nl`, `_nr`; grupo: `_n0`, `_na`, `_nb`, `_nt`) |
|---|---|
| Forja (Guerrero–Maga): fuego y quiebre | Temple (`temple`): al quebrar +2 Quemadura · Hierro al Rojo (`hierroRojo`): +40% quiebre vs. Quemadura · Crisol (`crisol`): Derretir deja 3 Quemadura · Acero Fundido (`aceroFundido`): +15% crítico vs. Quemadura · Escoria (`escoria`): al quebrar −20% ATQ |
| Galvánica (Maga–Tirador): Agua y Electro | Pila (`pila`): Cortocircuito → +12 ULT · Electrólisis (`electrolisis`): Electrocución deja Cargado · Circuito Cerrado (`circuitoCerrado`): Cortocircuito deja Mojado · Arco de Plasma (`arcoPlasma`): Cargados +15% daño +5% crítico · Corriente Alterna (`corrienteAlterna`): mojar → 30% de Cargado |
| Eclipse (Tirador–Paladín): Veneno y Sagrado | Purga (`purga`): muere un envenenado → grupo se cura 4% · Sombra Sagrada (`sombraSagrada`): crítico → +2 Veneno · Penitencia (`penitencia`): envenenar → +1 Sagrado · Corrupción (`corrupcion`): golpe a uno con 5+ Veneno → sagrado MAG × 0.5 · Antídoto (`antidoto`): al matar, el más herido se cura 8% |
| Glaciar (Paladín–Guerrero): hielo y aguante | Avalancha (`avalancha`): golpe a uno con 3+ Congelación salpica 40% · Escarcha Viva (`escarchaViva`): congelar → −15% ATQ · Glaciación (`glaciacion`): Congelación súbita → escudo 12% · Quebrar Témpanos (`quebrarTempanos`): +15% crítico vs. Congelación · Aliento Gélido (`alientoGelido`): ULT → grupo −10% daño 2 turnos |
| Táctica (grupo): preparar y detonar juntos | Preparación (`preparacion`): detonan un estado tuyo → +15% daño 2 turnos · Pinza (`pinza`): reacción del grupo → +6 ULT · Fuego Cruzado (`fuegoCruzado`): al quebrar lo marca +15% · Golpe Maestro (`golpeMaestro`): detonan lo tuyo → grupo +10% daño 2 turnos |
| Coro (grupo): ULT y buffs | Himno (`himno`): ULT → grupo +15% velocidad · Contrapunto (`contrapunto`): al quebrar, grupo +10% crítico · Canon (`canon`): buffs de grupo +1 turno · Crescendo (`crescendo`): al empezar tu turno +4 ULT a cada aliado |
| Santuario (grupo): curas y Sagrado | Altar (`altar`): aura Sagrado enemigo +25% · Oración Compartida (`oracionCompartida`): curar → escudo 5% al más herido · Último Rezo (`ultimoRezo`): cae un aliado → escudo 12% al grupo · Santuario (`santuarioGrupal`): al empezar tu turno el grupo se cura 2% |
| Fortaleza (grupo): escudos y protección | Rastrillo (`rastrillo`): golpe absorbido por Protección → escudo 8% · Torre del Homenaje (`torreHomenaje`): golpe defendiendo → +4 ULT a los aliados · Foso (`foso`): golpe absorbido por Protección → atacante se retrasa 25% · Ciudadela (`ciudadela`): cae un aliado → grupo −20% daño 3 turnos |

**Motor (sin disparadores nuevos).** Hizo falta un solo arreglo
localizado en `BattleEngine`: los buffs de **daño** con duración
(`BuffStat.damage` como `TimedEffect`) no se leían al calcular el golpe
(Combo de Equipo de la v5 tampoco hacía nada). Ahora suman como `× 1.xx
buff` en el log. Lo usan Preparación, Golpe Maestro y Ejecución Pública.

## 6. Keystones nuevas (16)

Las contras de stats las suma `PassiveTreeRules.aggregate`
(`kTreeV6Drawbacks`); el texto de la mecánica dice "Pero …".

| Keystone (id) | Dónde | Efecto | Contra |
|---|---|---|---|
| Verdugo (`verdugo`) | Verdugo | Golpes a uno rematan con <25% (no jefes ni élites) | ULT −30% de carga |
| Dios del Trueno (`diosTrueno`) | Tempestad | Cada golpe deja Cargado | −15% vida |
| Primera Línea (`primeraLinea`) | Vanguardia | Aura: grupo −10% daño recibido | −20% ATQ |
| Señora de las Mareas (`senoraMareas`) | Marea | Cada golpe deja Mojado | −15% MAG |
| Corazón de Tormenta (`corazonTormenta`) | Voltio | Mágicas a uno: Cargado + rebote 40% | −20% vida |
| Gran Obra (`granObra`) | Alquimia | Aplicar un elemento suma el primero que falta (siempre) | −12% MAG |
| Frente de Tormenta (`frenteTormenta`) | Monzón | Tras habilidad a todos: aliados +25% de adelanto | −20% ATQ |
| Tormenta Perfecta (`tormentaPerfecta`) | Centella | Cargados: +25% crítico y +15% daño | −15% vida |
| Gran Cazador (`granCazador`) | Montería | Cada golpe a uno deja trampa ATQ × 0.5 (2 turnos) | −1 velocidad |
| Inquisidor (`inquisidor`) | Exorcismo | +30% daño vs. Sagrado | −30% curación |
| Santo Patrono (`santoPatrono`) | Manantial | Al empezar tu turno, grupo se cura 5% | −25% ATQ |
| Torre de Tormenta (`torreTormenta`) | Pararrayos | Golpe recibido: refleja 40% y Cargado | −15% ATQ |
| Alma de Forja (`almaForja`) | Forja | Quemados: +25% daño y +50% quiebre | −30% maná |
| Superconductor (`superconductor`) | Galvánica | Golpe que detona +50% | −10% crítico |
| Crepúsculo (`crepusculo`) | Eclipse | Envenenados: +20% daño y +10% crítico | −30% curación |
| Corazón Glaciar (`corazonGlaciar`) | Glaciar | El que te pega recibe 2 Congelación | −1 velocidad |

## 7. Puntos (el doble)

- `PassiveTreeRules.pointsPerLevel = 2`: **2 puntos por nivel ganado
  después del 1 y 2 por nivel de Maestría** (`pointsEarned(treeLevel) =
  (treeLevel − 1) × 2`, con `treeLevel = nivel + Maestría`). Máximo:
  (49 + 20) × 2 = **138**.
- Todo lo que mira los puntos usa esa regla: visor, aviso de puntos sin
  usar (`UnusedPoints`, HUD, pestañas), `normalize`, planificador de
  builds.

## 8. Migración (sin reinicio)

Los ids v5 no cambian, así que **`kPassiveTreeVersion` sigue en 5** y no
hay migración de ids: un perfil v5 carga con todos sus nodos y,
simplemente, `pointsAvailable` da el doble de puntos ganados. Ej.: nivel
50 + Maestría 20 con 69 nodos → 69 puntos sin gastar, que muestran la
insignia `+69` del HUD y de la pestaña ÁRBOL (el aviso de 6 s sigue
saliendo solo al subir de nivel o de Maestría, passive_tree_v4.md § 7).
Las plantillas del planificador de builds siguen válidas (apuntan a
nodos v5 que no se movieron). El protocolo de red no cambia.

## 9. Balance (`passive_tree_balance_test.dart`)

Con el build codicioso de la v3 § 10, v6 con 138 puntos contra v5
congelado con 69:

1. **Un stat**: ≤ 1.35× (los nodos nuevos no dan stats; el techo es el
   pozo de stats del v5). Medido: vida 1.21-1.30×, ATQ 1.15-1.19×, MAG,
   crítico, vel., DEF y maná 1.00×.
2. **Build mixto**: entre 1.4× y 1.9× (más fuerte, como se pidió; medido
   1.75×: 3.53 → 6.19).
3. **Condiciones**: lo que se puede juntar contra un mismo estado ≤ +80%
   de daño y ≤ +75% de crítico. Medido: Cargado +69% / +66%, Mojado +44%
   / +68%, Sagrado +74% / +12%, Congelación +43% / +15% (por esto
   Chispa Viva da quiebre en vez de crítico, Descarga a Tierra reflejo
   de escudo en vez de daño y Tormenta Perfecta +25% de crítico).
4. El build v5 de 69 puntos da exactamente los mismos stats y mecánicas
   en el v6.

## 10. Visor (~600 nodos)

- Lienzo de 1380 px (±23 unidades). TODO encuadra la caja de todos los
  nodos en los dos ejes (`min(zoomX, zoomY)`, margen de 20 px para el
  radio de las keystones), centrada; zoom mínimo 0.2. MI CLASE incluye los
  clusters exteriores de tu clase.
- Puntos, reinicio, buscador y zoom van en una sola fila (si entra), y en
  el panel de personaje el visor ocupa todo el alto que queda
  (`PassiveTreeView.height: null`); la columna de info se desplaza.
- **Capa fija cacheada**: anillo, enlaces y nodos (con su estado y el
  plan) se graban una vez en un `ui.Picture` y se reutilizan mientras no
  cambien los estados, el plan ni la clase. Mover el mouse, buscar o
  resaltar un cluster solo dibuja la capa de resaltado (enlaces del
  camino y del cluster, sus nodos, anillos de búsqueda / foco). Los
  estados de los nodos se recalculan solo cuando cambia el perfil.
- Test de rendimiento: el hover y la búsqueda no regraban la capa fija y
  200 cuadros con resaltado se pintan en < 1 s.
