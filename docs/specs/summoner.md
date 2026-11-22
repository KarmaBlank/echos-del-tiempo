# Spec: Invocador (Maga) — v0.8.1

Pedido del dueño: "una línea de Invocador para el mago, y tomos con
habilidades de invocador, máximo 4 invocaciones; que sea divertido".

Código: `lib/game_engine/data/summoner_catalog.dart` (datos),
`lib/game_engine/rules/summon_rules.dart` (escalado),
`lib/game_engine/rules/battle_engine_summons.dart` (motor, `part` de
`battle_engine.dart`), `lib/features/combat/domain/summon_text.dart`
(textos), `lib/features/combat/presentation/scene/summon_sprite.dart`,
`summons_row.dart`, `lib/features/characters/presentation/grimoire_section.dart`.
Tests: `test/game_engine/summoner_test.dart`,
`test/features/combat/summons_ui_test.dart`.

## 1. Qué es una invocación

Un `Combatant` en `BattleState.summons` (no en `party`), con
`summonOwner` (id del jugador), `summonKind`, `summonTurns` y
`summonKills`. Tiene su turno en la línea de tiempo (como un enemigo,
el host lo hace actuar con `BattleEngine.enemyTurn`) y una IA por tipo.
No cuenta para ganar ni perder; si su invocador cae, se desvanece en su
turno. Familias: no tiene ("invocación").

## 2. Números

| | Valor |
|---|---|
| Máximo activas por invocador | **4** (Legión: 6); al pasarse se va la más vieja |
| Duración | **4** turnos propios (+2 Pacto Duradero, +1 afijo del Pacto / implícito; Pacto Eterno: hasta caer) |
| Vida | (MAG × 1.5 + nivel × 6 + 15% de la vida máx. del invocador) × mult. de vida × escala |
| Poder (daño base) | MAG × mult. de daño × escala × (1 + % afijo + % elementales) |
| Velocidad | la del invocador × mult. de velocidad |
| Crítico | 5% + crítico del invocador × herencia (Herencia Arcana 30%) |
| Escala | 1 + rareza del tomo (Mágico 5%, Raro 10%, Épico 15%, Legendario 25%) + forja Poder 4%/nivel + nodos de stats; × 0.7 con Legión |
| Festín Arcano | +10% de daño por enemigo que mató (tope +50%) |

| Invocación | Elemento / estado | Vida | Daño | Vel. | IA |
|---|---|---|---|---|---|
| Elemental de Fuego | Fuego, Quemadura 2 | 0.8 | 0.9 | 1.0 | pega (prefiere al que reacciona con su elemento, si no al que no tiene su estado, si no al más herido) |
| Elemental de Agua | Agua, Mojado | 0.9 | 0.7 | 1.0 | ídem |
| Elemental de Electro | Electro, Cargado | 0.7 | 0.8 | 1.2 | ídem |
| Elemental de Hielo | Hielo, Congelación 1 | 0.9 | 0.7 | 0.9 | ídem |
| Gólem | Físico | 2.2 | 0.5 | 0.8 | escudo MAG × 0.8 (2 turnos) al aliado más herido + golpe; atrae 50% de los golpes enemigos de un objetivo (× 0.6 de daño) |
| Espíritu | Sagrado | 0.8 | 0.4 | 1.1 | cura MAG × 0.9 al más herido si está bajo 80%; si no, Marca +12% daño recibido (2 turnos) + golpe |

Sin Gólem, cada invocación atrae un golpe enemigo de un objetivo con
12% (tope 40%). Los ataques en área no las tocan. Sus golpes usan
`_damageEnemy` con su elemento: detonan reacciones como cualquier golpe;
el estado lo aplican a nombre del invocador (cuenta para quién preparó
la reacción).

## 3. Habilidades (todas `SkillKind.support`, entrega `caster`)

| Id | Nombre | MP | Efecto |
|---|---|---|---|
| `invFuego` `invAgua` `invElectro` `invHielo` | Invocar Elemental de … | 6 | invoca uno |
| `invGolem` | Invocar Gólem | 8 | |
| `invEspiritu` | Invocar Espíritu | 7 | |
| `sacrificio` | Sacrificio | 4 | la más vieja detona su elemento: MAG × 1.6 a todos (reacciones sí); Sacrificio Ritual deja además su estado |
| `enjambre` | Llamado del Enjambre | 14 | 2 elementales al azar |
| `comandar` | Comandar | 5 | todas actúan ya (no gastan turnos) |

Entrega `SkillDelivery.caster`: por fusión solo las reciben báculo,
varita y tomo ("Solo armas de lanzador").

## 4. Tomos y ULT de arma

| Base | Nv | Habilidades | Implícito | ULT |
|---|---|---|---|---|
| Tomo del Invocador `tomo_invocador` | 6 | Fuego, Gólem, Sacrificio | +6% daño de invocaciones | la del tomo |
| Grimorio de las Mareas Vivas `grimorio_mareas_vivas` | 18 | Agua, Hielo, Comandar | +10% | la del tomo |
| Códice del Enjambre `codice_enjambre` | 30 | Electro, Enjambre, Sacrificio | +1 turno | **Marea de Espíritus** |
| Tomo del Pacto `tomo_pacto` | 36 | Fuego, Hielo, Sacrificio | +1 turno | **Avatar del Pacto** |
| Libro de los Cuatro `libro_cuatro` | 44 | Espíritu, Enjambre, Comandar | +15% | **Portal de los Cuatro** |

ULT propias (`kSummonerUltimates`, ids estables `ult_portal`,
`ult_avatar`, `ult_marea`; `kWeaponUltOf` base → ULT; `weaponBaseUlt`
para la UI). La ascensión sigue mandando sobre la ULT del arma, como
siempre.

- **Portal de los Cuatro**: invoca los 4 elementales (reemplazando a los
  más viejos), atacan ya × 1.5; al terminar cada uno detona MAG × 0.8 de
  su elemento en todos.
- **Avatar del Pacto**: consume tus invocaciones; por 3 turnos +15% de
  daño por cada una y sus estados en cada golpe tuyo.
- **Marea de Espíritus**: Gólem + 2 Espíritus, escudo 15% de tu vida
  máx. a todo el grupo (2 turnos) y tus invocaciones se llevan los
  próximos 2 golpes enemigos.

Afijos de tomo (loot.md § 9): **Evocador** (prefijo, +3–25% daño de
invocaciones, `ModStat.summonDamage`) y **del Pacto** (sufijo, +1 turno,
nivel 20+, `ModStat.summonTurns`).

## 5. Árbol: cluster Invocador (Maga)

13 nodos nuevos en el hueco entre Alquimia y el puente Galvánica (entra
por `galvanica_a1`). Ids nuevos `invocador_*`; v5/v6 sin cambios. Cada
nodo tiene su mecánica (`ProcEffectKind.summon`, la lee solo el motor de
invocaciones vía `kSummonerModOf`).

| Nodo | Tipo | Efecto |
|---|---|---|
| `invocador_s1` Vínculo / `invocador_s6` Conjuro Amplio | chico | +6% vida y daño |
| `invocador_s2` Chispa Elemental | chico | elementales +8% daño |
| `invocador_s4` Piedra Viva | chico | escudo del Gólem +15% |
| `invocador_n1` Herencia Arcana | notable | heredan 30% de tu crítico |
| `invocador_na` Ofrenda Volátil | notable | al morir o sacrificarse explotan: MAG × 0.8 de su elemento a todos |
| `invocador_nr` Sacrificio Ritual | notable | Sacrificio deja el estado en todos |
| `invocador_nb` Llamado Resonante | notable | invocar da +10 ULT |
| `invocador_nk` Festín Arcano | notable | +10% daño por muerte (tope 50%) |
| `invocador_nc` Pacto Duradero | notable | +2 turnos |
| `invocador_nd` Coro de Ecos | notable | +5% de daño propio por invocación activa |
| `invocador_kl` Legión | keystone | máx. 6, −30% stats |
| `invocador_kp` Pacto Eterno | keystone | duran hasta caer; −5% de tu vida máx. por invocación al empezar tu turno (nunca menos de 1) |

Legión y Pacto Eterno se excluyen. Total del árbol: 597 nodos.

## 6. Red

Aditivo: batalla `sum` (lista de combatientes), combatiente `smO` `smK`
`smT` `smN`. `kProtocolVersion` = **10** (v0.8.1 no juega en red con
v0.8.0).

## 7. UI

- Escena: sprites procedurales chicos delante del invocador, color del
  elemento (tokens `ProtoColors`), barra de vida y turnos (`∞` con Pacto).
- Tarjeta del grupo: fila compacta (vida · turnos) con tooltip.
- Tooltip de las habilidades: qué hace, stats con tus números y el tope.
- Tooltip del tomo: bonos a las invocaciones (desde v0.20.15 ya no
  muestra la ULT: conseguir el tomo la enseña al repertorio y se elige en
  PERSONAJE → ULT, ultimates_v2.md § 2.1).
- **GRIMORIO** (ATRIBUTOS): las que tenés (stats con tu equipo, de qué
  arma salen, trasladadas) y las que no, con "Se obtiene con: …".

## 8. Pendiente

- Arte propio (hoy procedural; cuando haya, al manifiesto de sprites).
