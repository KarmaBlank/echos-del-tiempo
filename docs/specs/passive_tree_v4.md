# Spec: Árbol de pasivas v4 — más notables que cambian la jugabilidad

Pedido del dueño (v0.6, backlog_v0.6.md § 2-3): "el árbol me gusta mucho,
pero hay pocos nodos notables que cambien la jugabilidad; tenés que
avanzar mucho. Los nodos chicos son como subir atributos (para eso está
subir de nivel). Que cada rama tenga más notables." Y: "una notificación
un poco más visible de que tiene puntos de árbol sin usar, no tan
invasiva pero que se destaque".

Parte de la v3 (`passive_tree_v3.md`): todo lo que no se nombra acá
sigue igual (anillo, inicios, puentes, reglas de puntos, exclusión
Creyente ↔ Inherente, motor de mecánicas, UI del visor). Reiniciar sigue
siendo gratis.

Implementación: `lib/game_engine/data/passive_tree_catalog.dart`
(`kPassiveTreeVersion = 4`, `kTreeIdsStableSinceV3`),
`lib/game_engine/data/passive_mechanics.dart` (`_v4`),
`lib/game_engine/rules/passive_tree_migration.dart`. Aviso:
`lib/features/characters/domain/unused_points.dart`,
`lib/app/widgets/points_badge.dart`,
`lib/features/world/presentation/hud/unused_points_notice.dart`,
`PanelTabs.badges`. Tests: `passive_tree_catalog_test.dart`,
`passive_tree_v4_mechanics_test.dart`, `passive_tree_balance_test.dart`
(v2 y v3 congelados en `test/game_engine/fixtures/`),
`player_profile_test.dart`, `test/features/world/unused_points_notice_test.dart`.

## 1. Números

| | v3 | v4 |
|---|---|---|
| Nodos | 352 | **308** |
| Notables | 60 | **104** (80 de clase + 12 de puentes + 12 de grupo) |
| Keystones | 20 | 20 (sin cambios) |
| Chicos | 268 | 180 |
| Notables por cluster de clase | 2 | **4** |
| Primer notable desde tu inicio | 5-7 puntos | **3** (4 en los clusters de las puntas) |
| Keystone de tu clase | 9-11 puntos | 9-10 puntos |
| Cluster completo | 11 puntos | 9 puntos |
| Puntos máx. | 69 (19.6%) | 69 (**22.4%**) |

La cobertura sube 3 puntos porque se sacó relleno: con los mismos 69
puntos se toman ~10 notables más, que es lo pedido. Sigue habiendo que
elegir (no entra ni un cuarto del árbol).

Desglose: 4 inicios + 12 anillo + 24 de rutas (6 × 4) + 180 de clusters
de clase (9 × 20) + 48 de puentes + 40 de grupos = 308.

## 2. Forma

- **Ruta de clase**: se saca `r2`. Queda `r1` (radio 4.5, mismo nombre
  y efecto que la v3) enlazado a `f2`, `f3` y `f4`; el abanico
  `f1..f5` igual (radio 6.0, en cadena). Así el cluster central y los
  dos de al lado arrancan a 2 puntos y los de las puntas a 3.
- **Cluster de clase** (marco local de la v3, entrada a R = 7.0):

  | Id | (u, v) | Tipo | Enlaces |
  |---|---|---|---|
  | `_n1` | (0, 0) | NOTABLE de entrada ★ | `f(i+1)`, `_m1` |
  | `_m1` | (0.8, 0) | chico A | `_m2` |
  | `_m2` | (1.6, 0) | chico A (bifurcación) | `_na`, `_nb` |
  | `_na` | (2.4, −0.8) | NOTABLE A (el de la v3) | `_ma` |
  | `_nb` | (2.4, 0.8) | NOTABLE B (el de la v3) | `_mb` |
  | `_ma` | (3.25, −0.9) | chico B | `_nc` |
  | `_mb` | (3.25, 0.9) | chico B | `_nc` |
  | `_nc` | (4.05, 0) | NOTABLE de unión ★ | `_k` |
  | `_k` | (4.95, 0) | KEYSTONE | — |

  Atajo entre clusters vecinos de la misma clase: `_mb` del cluster `i`
  ↔ `_ma` del `i+1`. Etiqueta del cluster en u = 5.95.
- **Puentes**: sin cambios (siguen colgando de `_nb` del último cluster
  de la clase A y de `_na` del primero de la clase B).
- **Clusters de grupo**: la punta `_t` (chico) pasa a ser el notable
  `_nt` (misma posición, u = 7.55).
- Ningún par de nodos a menos de 0.75 unidades (test).

## 3. Chicos y notables de clase

Chicos: menos y un poco más fuertes que en la v3: ATQ +5%, MAG +4.5%,
vida +4%, maná +6%, curación +6%, carga ULT +5%, crítico +2%, vel. +0.2,
DEF +2; mixtos +3%/+3% (Facetas, Destello) y Rastro +1.5% crít. +0.15
vel. Cada notable trae además un stat chico (+3% / +1.5% / +0.15 / +1).

Notables nuevos (`_n1` / `_nc`), todos con disparadores y efectos que ya
existían (passive_tree_v2.md § 5, ascension.md § 3.1, v3 § 9):

| Cluster | `_n1` (id) | Efecto | `_nc` (id) | Efecto |
|---|---|---|---|---|
| Muralla | Rompeolas (`rompeolas`) | Golpe recibido defendiendo: el atacante se retrasa 25%. | Coraza de Espinas (`corazaEspinas`) | Todo golpe recibido devuelve 20% al atacante. |
| Sangre | Sangría (`sangriaVital`) | Robo de vida 10%. | Frenesí Sangriento (`frenesiSangriento`) | Hasta +40% de daño según la vida que falta. |
| Quiebre | Mazazo (`mazazo`) | Golpes a uno: 12% de aturdir. | Brecha (`brecha`) | Al quebrar (cualquiera): el aliado más lento se adelanta 30% (solo: tu turno). |
| Gritos | Arenga (`arenga`) | Al matar: grupo +15% velocidad 2 turnos. | Estruendo (`estruendo`) | Buffs de grupo +30% y +1 turno. |
| Filo | Estocada Precisa (`estocadaPrecisa`) | Críticos a uno ×1.8. | Desarme (`desarme`) | Al critear: objetivo −20% ATQ 2 turnos. |
| Arcano | Canalizar (`canalizar`) | Habilidad mágica: +4 ULT. | Pulso Arcano (`pulsoArcano`) | Tras tu ULT: próximo turno 50% antes. |
| Brasa | Ascuas Vivas (`ascuasVivas`) | +15% crítico vs. Quemadura. | Pira (`pira`) | Muere un quemado: su Quemadura pasa al de más vida. |
| Cronos | Arena del Tiempo (`arenaTiempo`) | Golpes a uno: 25% de retrasar 15%. | Ancla Temporal (`anclaTemporal`) | Al retrasar con habilidad: −20% velocidad 2 turnos. |
| Escarcha | Frío Penetrante (`frioPenetrante`) | Al congelar: 50% de +1 Congelación. | Hielo Quebradizo (`hieloQuebradizo`) | +50% de quiebre vs. congelados. |
| Prisma | Chispa Prismática (`chispaPrismatica`) | Mágica a uno: +1 Congelación. | Descomposición (`descomposicion`) | Muere un enemigo: la mitad de sus elementos pasa a todos. |
| Viento | Viento Cortante (`vientoCortante`) | Tras habilidad a todos: +15% crítico 2 turnos. | Huracán (`huracan`) | Al matar: 35% de turno extra. |
| Lluvia | Lluvia Ácida (`lluviaAcida`) | Habilidades a todos: +1 Veneno. | Granizo (`granizo`) | Habilidades a todos: retrasan 10%. |
| Precisión | Tiro a la Cabeza (`tiroALaCabeza`) | Crítico a uno: 25% de aturdir. | Grieta Expuesta (`grietaExpuesta`) | +40% de quiebre vs. marcados. |
| Acecho | Trampa de Caza (`trampaCaza`) | Golpes a uno: 30% de trampa ATQ × 0.6 (2 turnos). | Cacería (`caceria`) | Al saltar tu trampa: marca +20% (3 turnos). |
| Toxina | Toxina Paralizante (`toxinaParalizante`) | Al envenenar: −15% velocidad 2 turnos. | Nube Tóxica (`nubeToxica`) | Golpe a un enemigo con 4+ Veneno: 40% salpica a los demás. |
| Luz | Mano Luminosa (`manoLuminosa`) | Golpes a uno: curan 3% al más herido. | Estallido Solar (`estallidoSolar`) | Golpe a un enemigo con 3+ Sagrado: sagrado MAG × 0.5. |
| Juicio | Sentencia (`sentencia`) | +30% de daño a aturdidos. | Veredicto (`veredicto`) | Al aturdir: marca +20% (3 turnos). |
| Fe | Comunión (`comunion`) | Tus curas te curan 5% (1 por acción). | Milagro (`milagro`) | 1 vez por batalla, un golpe mortal te deja en 1 HP. |
| Vigilia | Represalia Sagrada (`represaliaSagrada`) | Golpe recibido: +1 Sagrado al atacante. | Resiliencia (`resiliencia`) | Hasta −30% de daño recibido según la vida que falta. |
| Bastión | Púas (`puas`) | Tus escudos devuelven 40% de lo absorbido. | Escudo Solidario (`escudoSolidario`) | Golpe recibido: escudo 6% al aliado más herido. |

Los ids `sangriaVital`, `tiroALaCabeza` y `resonanciaGrupal` llevan sufijo
porque `sangria` / `tiroCabeza` son habilidades y `resonancia` un Eco.

## 4. Puntas de los clusters de grupo

| Cluster | `_nt` (id) | Efecto (también solo) |
|---|---|---|
| Estandarte | Estandarte Alzado (`estandarteAlzado`) | Al usar tu ULT: los aliados se adelantan 25% (solo: tu turno). |
| Sintonía | Resonancia (`resonanciaGrupal`) | Al quebrar (cualquiera): +6 ULT a todo el grupo. |
| Vínculo | Ángel Guardián (`angelGuardian`) | 1 vez por batalla, el primer golpe mortal a alguien del grupo lo deja en 1 HP. |
| Refugio | Muro de Escudos (`muroEscudos`) | Golpe recibido defendiendo: escudo 6% a todo el grupo (2 turnos). |

## 5. Balance (`passive_tree_balance_test.dart`)

Con 69 puntos y el build codicioso de la v3 § 10:

1. **Un stat**: ≤ 1.6× la v2 (sin cambios en la regla). Medido (v2 → v3
   → v4): vida 1.14 → 1.60 → 1.77, ATQ 1.45 → 1.74 → 1.99, MAG 0.95 →
   1.50 → 1.46, crítico 0.37 → 0.59 → 0.57, vel. 3.2 → 4.95 → 5.1, maná
   0.66 → 0.86 → 0.86, DEF al tope (60%).
2. **Build mixto**: entre 0.7× y 1.25× de la v2 **y** no menos que la
   v3: v2 4.04, v3 3.15, v4 3.53 (≈ 0.87×).
3. **Representativo** (Guerrero Muralla + Sangre + Filo, 33 puntos): las
   mecánicas de la v2 más 6 notables nuevos, bono ≤ 1.25× v2 (1.41 →
   1.48).

Para no apilar un stat, los notables de unión dan stats variados (ATQ,
ULT, maná, DEF, curación, vel.) en vez de vida/MAG/crítico.

## 6. Migración (reinicio gratis)

`tv` pasa a 4. Al cargar (`migrateTreeIds`):

- `tv` 4: sin cambios.
- `tv` 3: se conservan, en el orden tomado y solo si siguen conectados,
  los ids de `kTreeIdsStableSinceV3` (mismo id, tipo, nombre, efectos y
  mecánica que en la v3): anillo, inicios, `r1` y abanico de cada ruta,
  `_na` / `_nb` / `_k` de cada cluster de clase, los puentes enteros y
  los clusters de grupo salvo la punta (184 ids; un test lo verifica
  contra la v3 congelada). El resto se devuelve (`r2`, los chicos de los
  clusters, la punta `_t` de los grupos y lo que quedó sin conexión).
- `tv` 2 / sin `tv`: como antes (anillo e inicios / nada).

Los puntos devueltos van a `treeRefunded` y la sala avisa una vez, igual
que en la v3 (`<nombre>: el árbol de pasivas cambió; se reinició gratis y
recuperaste N puntos.`). El protocolo de red no cambia por esto (los ids
viajan en el perfil y el host migra igual).

## 7. Aviso de puntos sin usar

`UnusedPoints.of(perfil)`: atributos (`points`), árbol
(`pointsAvailable(treeLevel)`) y ascensión (`AscensionRules.free`).

- **HUD**: junto a `≡ MENÚ`, un botón compacto `PERSONAJE [C]` con una
  insignia `+N` (total) arriba a la derecha. Solo aparece si hay puntos
  sin usar (no ocupa lugar si no). Tooltip con el desglose
  (`3 puntos de atributos`, `2 puntos de árbol`…). Clic = tecla C.
- **Pestañas**: ATRIBUTOS y ÁRBOL del panel de personaje llevan su `+N`
  (quieto) cuando tienen puntos (`PanelTabs.badges`).
- **Aviso** (zona de avisos del HUD, sobre el centro): cuando sube el
  `treeLevel` (nivel o Maestría) o los puntos de ascensión ganados, y
  quedan puntos de árbol / ascensión, un cartel suave 6 s: `▲ Tenés 2
  puntos de árbol sin usar · [C]` (ascensión: `· Estatua del Tiempo`).
  Uno por subida; espera a que termine el reparto de la subida y a que
  se cierre el panel abierto; si ya no quedan puntos, no dice nada. Al
  entrar al juego no avisa (lo muestra la insignia).
- **Accesibilidad**: la insignia late suave (opacidad 70-100% y brillo,
  900 ms); con "Reducir movimiento" queda quieta con un borde de 2 px.
  No depende solo del color: el `+N` y la marca `▲` se leen igual con
  cualquier paleta. Desactivar el aviso desde ajustes queda para más
  adelante (no hizo falta un ajuste nuevo).
