# Spec: Habilidades de inicio y de remate

Estado: propuesta (sin código). Base: `SkillDef.requires` (`SkillReq`,
`skill_requirements.dart`), `SkillDef.detonate`, `conditionReady` (el
resaltado de la opción en el menú de combate, `battle_command_window.dart`)
y las reacciones (elemental_reactions.md).

## 1. Dos papeles

| papel | se puede usar | costo | qué hace |
|---|---|---|---|
| inicio | siempre (sin `requires`) | bajo; muchas son Instante | aplica un estado o marca: Sagrado, Quemadura, Veneno, Mojado, Marca (`damageTaken`) |
| remate | solo si el objetivo cumple la condición (`requires`) | medio o alto, Pulso 2 | golpe fuerte; puede consumir la condición |

Una habilidad de remate sin su condición queda en gris con "Necesita:
objetivo con Sagrado ×3" (`SkillRequirements.missingLines`, ya existe).
Con la condición lista, la opción se resalta (`conditionReady`, ya
existe).

## 2. Regla del 50%

Como máximo la mitad de las ranuras de habilidades de un jugador (sin
contar ATACAR, DEFENDER, Quebrar ni el combo de clase) pueden ser de
remate. Motivo: que nadie arme un kit que no puede hacer nada hasta que
otro le prepare el objetivo.

- Ajuste de Balance: `conditionalMax` = 0.5 (fracción, redondeo hacia
  abajo; con 1 ranura, 0).
- Dónde se valida: al equipar (Mundo: panel de habilidades; Travesía:
  recompensa y armería). El motor no lo valida en combate.
- UI: el contador "Remate 1/2" junto a las ranuras; la ranura que
  pasaría el tope sale en gris con el motivo.

## 3. Condiciones

Lo que el motor ya entiende (`SkillReqKind`):

| condición | ejemplo |
|---|---|
| `targetStacks(estado, n)` | Ignición Convergente: Veneno ×5 |
| `targetFissured` | Quebrar |
| `targetMarked` | objetivo con Marca |
| `selfHpBelow(f)` | habilidades de desesperación |

Falta (motor nuevo):

- `targetAnyOf([estados], n)`: cualquiera de varios estados.
- `consume`: la habilidad saca exactamente los stacks pedidos al pegar
  (hoy solo `detonate` consume, y consume todo).
- `byAlly`: la condición la puso otro jugador; da +10% de daño para
  premiar el cooperativo (opcional).

## 4. Combinaciones entre clases

Estados nuevos que nacen de dos estados en el mismo objetivo, como las
reacciones (mismo lugar del catálogo, `ReactionDef`, editables en
Balance). Cada uno habilita remates propios.

| estados | resultado | efecto |
|---|---|---|
| Sagrado + Quemadura | Purgado (2 turnos) | +20% de daño mágico recibido; los remates de Paladín y Maga lo consumen por +60% |
| Sagrado + Veneno | Expiado | la cura que recibe quien lo golpea sube 15% |
| Mojado + Sagrado | Bautizado | no puede ganar buffs; el remate de Paladín además aturde |
| Marca + Veneno | Señalado | los críticos contra él suman 1 de Veneno |
| Quemadura + barra de quiebre a la mitad | Agrietado | la barra se llena × 1.5 |

Reglas: se forma al aplicar el segundo estado; los de origen quedan
(salvo que el remate los consuma); dura 2 turnos del objetivo; uno por
objetivo a la vez (el último reemplaza). Cuenta como reacción para el
árbol (`onReaction`), con el tope de efectos encadenados por acción.

## 5. Migración por clase

Primero se marca cada habilidad existente con su papel (`role: inicio |
remate | libre`) sin cambiar números; después se ajustan.

| clase | inicio | remate (propuesta) |
|---|---|---|
| Guerrero | golpes que dejan Marca | un golpe fuerte que pide Marca y la consume (+50%) |
| Maga | Bola de fuego, Chispa (Quemadura, Mojado) | Ignición y Ponzoña Convergente (ya son remate); uno nuevo de Purgado |
| Tirador | Flecha Venenosa (Veneno), disparos con Marca | un disparo que pide Marca; Ráfaga queda libre |
| Paladín | ver paladin_rework.md | ver paladin_rework.md |

Pasos:

1. `role` en `SkillDef` (con su campo en el codec de Balance) y la regla
   del 50% al equipar. Sin cambios de combate.
2. `consume` y `targetAnyOf` en `SkillRequirements`: host, UI e IA de
   compañeros usan la misma función, no hay que tocar tres lugares.
3. Estados combinados como `ReactionDef` nuevas.
4. IA de compañeros (`companion_ai.dart`): prioriza el remate si la
   condición está lista; si no, una de inicio.
5. Ayuda del menú de combate: "Las de inicio preparan, las de remate
   cobran".

## 6. Netcode

Paso 1: sin cambios de protocolo (es del perfil, que ya viaja entero).
Pasos 2-3: cambian el estado de batalla (estados nuevos), suben
`kProtocolVersion`.
