# Economía de materiales

> Estado: **APROBADO** por el dueño e **implementado en v0.15.0** (rama
> `feat/materiales`). Respuestas a las preguntas en § 5; números finales
> medidos contra el código real en § 7. Las tablas de §§ 1–2 son el
> estado previo (v0.14), como referencia.
> Números medidos con `tool/materiales_economia_measure_test.dart`
> (`flutter test tool/materiales_economia_measure_test.dart`), motor real,
> mismas semillas que `tool/hazanas_economia_measure_test.dart`.

## 0. Pedido

Bajar las tasas de los materiales altos (el que sube a Épico), que llegar a
Épico "cueste un rato", que traer una habilidad pida materiales, que el
material bajo deje de ser basura (convertirlo a alto en vez de agregar
materiales nuevos) y que el endgame tenga escalones de riesgo con más
recompensa, sin grindeo excesivo.

## 1. Cómo funciona hoy (código)

| Material | Uso | Fuente principal |
|---|---|---|
| Esquirla del Eco | re-tirar valores (1 c/u, ₵25×rareza) | 10% por tirada, jefe +1, cofres, misión opcional 3, desarme |
| Cristal de Era | agregar afijo (1 c/u) | 4% por tirada, misión opcional 1, desarme Mágico 25% / Raro 1 / Épico 2–3 |
| Prisma Roto | subir rareza: Común→Mágico 1, →Raro 2, →Épico 4 (total **7** + ₵1200). Ecos: 1/2/3 | 1.5% por tirada, misión opcional 1 desde nv 30, desarme Raro 10% / Épico 35% / Leg 1 |

- Tirada de material: `chance × fuente (batalla 1, cofre/misión 2, élite 3, jefe 5) × (1 + bonus de zona ≤ 0.5)` (`LootRules.rollMaterials`).
- **Legendario no se craftea**: solo cae (o se mejora con Esencia del Abismo).
- **Traer una habilidad** (`transferSkill`): solo créditos (₵200 × rareza) y el arma sacrificada; **0 materiales**.
- Tope de pila: 99 por material; lo que sobra se pierde.
- **Ecos**: el tier sube el nivel de los monstruos (`48 + 2t`) pero **no** el botín; el bonus de zona ya está topado en nivel 50. Solo los mods del Eco suben cantidad/rareza.
- Hazañas v0.14.0 (total de todas): 18 Esquirlas, 11 Cristales, **11 Prismas**.

## 2. Diagnóstico (medido)

Supuestos: 1 jugador, rango A, una misión opcional por misión, objetivo de
grupos cumplido (élites en la proporción del mapa), mitad de los cofres
abiertos, **todas** las armas no legendarias desarmadas. Es un techo de una
misión limpia.

### 2.1 Por misión (drop + desarme)

| Tramo | Esquirlas | Cristales | Prismas | Épicos que caen | Legendarios |
|---|---|---|---|---|---|
| Temprano (m1–z4) | 37 | 9.0 | 1.5 | 0.9 | 0.10 (1 cada 10) |
| Medio (z5–z7) | 62 | 13.9 | 2.4 | 1.3 | 0.18 (1 cada 6) |
| Tardío (z8–z10) | 78 | 16.0 | 3.7 | 1.4 | 0.16 (1 cada 6) |
| Eco T1, 0 mods | 102 | 21.3 | 4.8 | — | 0.25 (1 cada 4) |
| Eco T16, ~4.5 mods | 125 | 26.7 | 5.9 | — | 0.30 (1 cada 3.3) |

Campaña completa (cada misión una vez): **611 Esquirlas, 133 Cristales,
27 Prismas** + hazañas (18 / 11 / 11).

### 2.2 Hitos hoy

| Hito | Costo | Misiones hoy |
|---|---|---|
| Común → Épico (arma) | 7 Prismas + 1 Cristal + ₵1300 | temprano 4.6 · medio 2.9 · tardío **1.9** · Eco **1.2–1.5** |
| Traer una habilidad | ₵200–600, 0 materiales | 0 (solo créditos) |
| Legendario | solo drop | ~6 misiones tardías, ~3.5 Ecos |

### 2.3 Lectura

1. **Prismas sobran.** En el tramo tardío un Épico crafteado sale en menos de
   2 misiones; en Ecos en ~1. Las hazañas solas regalan 11 (más de un Épico y medio).
2. **Esquirlas son basura**: 40–100 por misión contra un consumo de 1 por
   re-tirada. La pila de 99 se llena en 1–2 misiones y el resto se pierde.
   Los Cristales también sobran (16/misión; un Épico usa 1–2).
3. **El crafteo de rareza compite con el drop**: ya caen ~1.4 Épicos por
   misión tardía y un Legendario cada ~6. Bajar solo los Prismas no hace
   que "Épico cueste" si el Épico cae del piso (ver pregunta 1).
4. **El endgame no escala con el riesgo**: un Eco T16 da lo mismo que un T1
   con los mismos mods. El tier solo sube la dificultad.

## 3. Metas de diseño

- **Épico crafteado** (Común→Épico): ≈ **5–8 misiones** en el tramo medio, ≈ **3–4** en el tardío, ≈ **3–5 Ecos** en endgame bajo y ≈ **3** en Ecos altos.
- **Legendario**: sigue siendo solo drop; ≈ 6 misiones tardías, ≈ **2.5 Ecos** en tier alto (más rápido que hoy solo arriba).
- **Traer una habilidad**: decisión, no trámite: 2 Cristales + créditos.
- **Ningún material bajo se tira**: todo excedente tiene una salida (conversión).
- **Sin grindeo excesivo**: ningún hito por encima de ~8 misiones del tramo en el que se busca.

## 4. Propuesta

### 4.1 Tasas de drop (`LootRules.materialChance`)

| Material | Hoy | Propuesta |
|---|---|---|
| Esquirla | 10% | 8% |
| Cristal | 4% | 2.5% |
| Prisma | 1.5% | **0.6%** |

- Misión opcional: Prisma (nv ≥ 30) pasa de seguro a **50%**.
- Épico que cae: peso base **2.7 → 1.5** fuera de un Eco
  (`LootRules.zoneEpicWeight`; zonas, cofres, misiones, Pruebas, Abismo).
  Dentro de un Eco sigue 2.7 (`eco: true`), así el endgame no pierde
  Épicos y el Legendario no se toca (§ 7: cumple la meta sin cambiarlo).
- Desarme: Raro `1 Cristal + 1 Esq + 10% Prisma` → `2 Esq + 50% Cristal + 5% Prisma`; Épico `2 Cristales + 35% Prisma` → `1 Cristal (+1 desde nv 25) + 15% Prisma`. Mágico, Común y Legendario igual.
- Hazañas: sin cambio (11 Prismas pasan a ser ~1 Épico extra, un premio que se nota).

### 4.2 Curva de costos

| Operación | Hoy | Propuesta |
|---|---|---|
| Común→Mágico | 1 Prisma + ₵100 | igual |
| Mágico→Raro | 2 Prismas + ₵300 | **3** Prismas + ₵300 |
| Raro→Épico | 4 Prismas + ₵800 | **6** Prismas + ₵800 |
| Total a Épico | 7 | **10** (desde un Raro caído: 6) |
| Ecos (1/2/3) | 6 | 1/2/**4** = 7 |
| Traer habilidad | ₵200×rareza | ₵200×rareza **+ 2 Cristales** (destino Raro+); Común/Mágico sin material |

### 4.3 Conversión bajo→alto ("Condensar", en la mesa de forja)

Nueva operación de `CraftRules` en el mismo banco (sin edificio nuevo):

- **10 Esquirlas + ₵100 → 1 Cristal**
- **10 Cristales + ₵500 → 1 Prisma** (1 Prisma = 100 Esquirlas + ₵1500)
- Sin vuelta atrás, sin azar, por lotes (x1 / x5 / todo).
- Ancla, Fragmentos y Esencia **no** se convierten (son llaves del endgame).
- El tope de 99 hace que convertir antes de perder sea natural; la UI
  avisa "pila llena: condensar" cuando se pierde material.

Los créditos hacen de freno: convertir todo un tramo tardío cuesta del
orden de lo que paga una misión, así que acelera pero no reemplaza jugar.

### 4.4 Riesgo alto, recompensa alta (endgame)

Se reusa lo que ya existe (mods de Eco = modificadores de dificultad) y se
agrega que **el tier pague**:

- `Q` del Eco suma **+3% de cantidad por tier sobre T1** (T8 +21%, T16 +45%).
- Riesgo real: el tier ya sube los monstruos (`48 + 2t`, T16 ≈ +54% vida,
  +49% ATQ) y los mods suman encima; un fallo consume el Eco y no da botín de fin.
- No hace falta un sistema nuevo de "tiers de misión" en la campaña: el
  Eco *es* la misión de tier alto. Si el dueño quiere escalones también en
  zonas (pregunta 4), se haría con los mismos mods.

### 4.5 Antes / después (mismo script)

| Hito | Hoy | Propuesta (solo drops) | Propuesta + conversión de todo el excedente |
|---|---|---|---|
| Épico, temprano | 4.6 | 15.8 | 7.7 |
| Épico, medio | 2.9 | 9.9 | **4.4** |
| Épico, tardío | 1.9 | 6.2 | **3.1** |
| Épico, Eco T1 (0 mods) | 1.5 | 4.8 | — |
| Épico, Eco T8 raro | 1.3 | 3.8 | — |
| Épico, Eco T16 legendario | 1.2 | 3.3 | — |
| Legendario, Eco T16 | 3.3 | **2.4** | — |
| Campaña: Prismas | 27 | 11 (+11 hazañas) | — |
| Campaña: Cristales | 133 | 88 | — |

Por misión tardía con la propuesta: 80 Esquirlas, 10.7 Cristales, 1.6 Prismas.
La conversión es el tope (todo convertido, reserva de 10 Esq y 2 Cri por
misión); un jugador real queda entre las dos columnas, es decir **Épico ≈
4–6 misiones medias y 3–6 tardías**, dentro de la meta.

## 5. Decisiones del dueño (aprobadas)

1. **Bajar el drop directo de Épicos**: SÍ. Peso base del Épico 2.7 →
   1.5 en zonas (no en Ecos). Simulado (§ 7): con 1.5 se cumple la meta;
   no hizo falta tocar el Legendario.
2. **Condensar cuesta créditos**: SÍ, ₵100 (→ Cristal) y ₵500 (→ Prisma)
   por unidad; sin azar, irreversible, host-autoritativo.
3. **Traer habilidad**: 2 Cristales de Era hacia un arma Rara o mejor
   (Común / Mágico solo créditos).
4. **Escalones de riesgo**: solo en Ecos: +3% de cantidad por tier sobre
   T1 (`EcoRules.tierQuantity`). Sin modo de riesgo en la campaña.
5. **Tope de pila**: se mantiene en 99 (Condensar no deja pasarlo).

## 6. Implementación (v0.15.0)

- `LootRules.materialChance` 8% / 2.5% / 0.6%; `LootRules.zoneEpicWeight`
  1.5 y el parámetro `eco` en `rarityOdds` / `rollRarity` / `generate` /
  `rollDrops` (el `SessionEngine` pasa `eco: _eco != null`).
- `kQuestPrismaChance = 0.5` (misión opcional, desde nivel 30).
- `CraftRules.salvageYield`: Raro y Épico nuevos (§ 4.1).
- `CraftRules.upgradeRarityCost` 1 / 3 / 6; `EcoRules.prismCost` 1 / 2 / 4.
- `CraftRules.transferSkillMaterials` (2 Cristales a Raro+): lo cobra
  `transferSkill` (el host lo valida con `_payError`) y la UI lo muestra
  desde la misma vista previa (`CraftResult.materials`: chip del paso 2,
  `Cuesta:` del tooltip y GASTAS del paso 3).
- `CraftOp.condense` + `CraftRules.condense` / `condenseRecipe` /
  `condenseMax`; UI en la mesa de fusión (`CondensePanel`, panels.md §
  "FUSIÓN (v0.15: CONDENSAR)").
- `EcoRules.tierBonus` dentro de `EcoRules.lootBonus` (el tooltip del
  Eco ya suma el tier).
- **Red**: `CraftAction` no cambia de forma (`t: craft`, `op` por
  nombre), pero hay un valor nuevo de `op`: `condense` (`w` = material,
  `i` = cuántos). Un host viejo no lo entiende: requiere subir
  `kProtocolVersion` al integrar.
- Sin migración de perfiles (solo cambian tablas).

## 7. Resultado medido (código real, v0.15.0)

`flutter test tool/materiales_economia_measure_test.dart` (usa
`LootRules.rollDrops`, `CraftRules.salvageYield`,
`CraftRules.upgradeRarityCost`, `CraftRules.condenseRecipe`,
`EcoRules.tierQuantity` y `kQuestPrismaChance`; ninguna copia).

| Tramo | Esquirlas | Cristales | Prismas | Épicos que caen | Legendario |
|---|---|---|---|---|---|
| Temprano (m1–z4) | 39 | 5.6 | 0.58 | 0.60 | 1 cada 10.3 |
| Medio (z5–z7) | 64 | 8.4 | 0.94 | 0.84 | 1 cada 6.6 |
| Tardío (z8–z10) | 81 | 9.9 | 1.58 | 0.91 | 1 cada 5.5 |
| Eco T1, 0 mods | 103 | 14.3 | 2.06 | 2.0 | 1 cada 5.4 |
| Eco T8, ~2.5 mods (+37%) | 133 | 18.3 | 2.49 | 2.5 | 1 cada 2.7 |
| Eco T16, ~4.5 mods (+74%) | 161 | 23.0 | 3.11 | 3.2 | 1 cada 2.5 |

| Hito | Meta | Hoy (v0.14) | v0.15 solo drops | v0.15 + condensar todo |
|---|---|---|---|---|
| Épico crafteado, temprano | — | 4.6 | 17.1 | 8.1 |
| Épico crafteado, medio | 5–8 | 2.9 | 10.7 | 4.7 |
| Épico crafteado, tardío | 3–4 | 1.9 | 6.3 | 3.3 |
| Épico crafteado, Eco T1 | 3–5 | 1.5 | 4.8 | 2.4 |
| Épico crafteado, Eco T8 | — | 1.3 | 4.0 | 1.9 |
| Épico crafteado, Eco T16 | ≈ 3 | 1.2 | 3.2 | 1.5 |
| Legendario, tardío | ≈ 6 | 6 | 5.5 | — |
| Legendario, Eco T16 | ≈ 2.5 | 3.3 | **2.5** | — |
| Épicos que caen / misión tardía | bajar | 1.4 | **0.91** | — |
| Campaña: Prismas / Cristales | — | 27 / 133 | 10.9 / 81 (+11 / 11 hazañas) | — |

Un jugador real queda entre las dos columnas (condensa parte del
excedente y gasta Esquirlas y Cristales en re-tirar y agregar mods):
Épico ≈ 5–8 misiones medias, 3–6 tardías y 3–5 Ecos. Condensar todo un
tramo tardío cuesta ≈ ₵1500 por Prisma, del orden de lo que paga una
misión: acelera pero no reemplaza jugar.

## 8. Fuera de alcance / pendiente

- Créditos por misión (ya medidos en achievements.md § 4) no se tocan acá.
- El script asume 1 jugador; en grupo cada uno tira su propio botín.

## v0.17.0: mejora de ULT (ultimates_v2.md § 2.4)

Sumidero nuevo de Cristales de Era y Prismas Rotos: subir una ULT de
nivel 1 a 5 cuesta ₵10000, 10 Cristales y 3 Prismas (las 4 de jefe con
Abismo, además 2 Fragmentos de ese jefe). Con ~50 ULT posibles es un
sumidero de largo plazo que no compite con la forja temprana (los
Prismas recién desde el nivel 3).