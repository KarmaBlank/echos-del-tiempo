# Spec: Paladín, tres caminos

Estado: propuesta (sin código). Hoy el Paladín es "vida y defensa altas,
daño bajo, lento" sin kit propio (su kit pasó al Guardián, ascension.md
§ 4), y en `run_balance_sim_test.dart` vence al jefe del piso 3 en 5 de
10 semillas contra 9 de 10 del Guerrero y la Maga. Objetivo: tres
builds viables. Todas usan Sagrado (`StatusKind.holy`, daño por turno,
3 turnos) como hilo común y el par inicio / remate de
conditional_skills.md.

## 1. Daño

Fuerte en solitario: acumula Sagrado y lo detona.

| id propuesto | papel | campos existentes | nuevo |
|---|---|---|---|
| `juicio` Juicio | inicio, Instante | `status: holy ×2`, `power` 0.8, `pulse` 1 | — |
| `sentencia` Sentencia | remate | `requires: targetStacks(holy, 4)`, `detonate` 0.12 por stack, `pulse` 2 | `consume` (solo 4) |
| `martillo` Martillo Celeste | remate | `requires: targetStacks(holy, 2)`, `power` 1.8, `breaks` | — |

Pasivas (rama Daño del árbol):

- Sagrado acumulable hasta 8: `ElementStatusDef.maxStacks` (nuevo).
- Detonación automática: al llegar a X stacks (ajuste, 6) explota por
  `MAG × 0.4 × stacks` y vuelve a 0. Disparador nuevo
  `ProcTrigger.onStacksReached`.
- +15% de daño contra objetivos con Sagrado: `ProcTrigger.vsStatus` con
  `status: holy` (ya existe).

El tope por golpe de jefes (35%) y élites (60%) también corta la
detonación (combat.md § "Límites").

## 2. Híbrido

Escudos para sí y un aliado, daño moderado.

| id propuesto | papel | campos existentes | nuevo |
|---|---|---|---|
| `egidaLuz` Égida de Luz | inicio | `power` 1.0, `status: holy ×1`; escudo propio con mecánica `onSkill` + `shieldSelf` 0.12 | — |
| `bastion` Bastión | libre | `kind: protect` (protege a un aliado) | `shieldTarget` 0.10 en la habilidad |
| `castigo` Castigo | remate | `requires: targetStacks(holy, 2)`, `power` 1.4, `lifeSteal` 0.2 | — |

Límite propio: los escudos de este camino no se acumulan (ya es la regla
de `_giveEffect`: del mismo origen queda el mayor) y tienen tope de 25%
de la vida del protegido (ajuste `hybridShieldCap`). Sin ese tope el
híbrido protegería mejor que el soporte.

## 3. Soporte

Curas y escudos fuertes, estados sobre enemigos. Proteger y bloquear le
carga la ULT.

| id propuesto | papel | campos existentes | nuevo |
|---|---|---|---|
| `plegaria` Plegaria | libre | cura de grupo, `rally` | — |
| `santuario` Santuario | libre | `buffs` de escudo (`BuffStat.shield`) al grupo, 2 turnos | — |
| `bautizo` Bautizo | inicio | `status: holy ×1` y Mojado | estado combinado Bautizado |
| `custodia` Custodia | libre | `kind: protect` | — |

Carga de ULT al proteger: mecánica con `ProcTrigger.onProtectHit` (ya
existe) y efecto `ultCharge` 6 por golpe bloqueado. Es carga extra: pasa
por el tope de 50% por acción y por turno (combat.md § "Límites"). Para
que el camino no dependa solo de eso, el soporte suma además 4 de carga
base por golpe bloqueado (como `defendHitUlt`), que no tiene tope. Ajuste
nuevo: `paladinBlockUlt`.

## 4. Lo que necesita motor nuevo

1. `ElementStatusDef.maxStacks` para Sagrado.
2. `ProcTrigger.onStacksReached` (detonación automática).
3. `SkillReq.consume` (conditional_skills.md § 3).
4. Escudo al protegido en una habilidad de proteger (`shieldTarget`).
5. Estados combinados (Bautizado, Purgado).
6. Carga base por golpe bloqueado (`paladinBlockUlt`).

Todo lo demás son datos: habilidades y nodos del árbol, editables en
Balance.

## 5. Medición

Meta: 8 de 10 jefes del piso 3 en `run_balance_sim_test.dart` con un kit
por camino, y en el Mundo el mismo tiempo por pelea que el Guerrero
(±15%) en `balance_measure_test.dart`.
