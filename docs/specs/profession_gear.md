# Spec: Equipo de oficios (armas únicas por oficio)

Estado: v0.50 (protocolo 92). Código: `game_engine/data/profession_gear_catalog.dart`,
`game_engine/rules/profession_gear_rules.dart` (`GearRules`), ganchos en
`session_engine_{fishing,farming,mining,cozy}.dart`. Números: grupo
**Oficios: equipo** del Balance (`kTuning[TuningId.gear]`).

## 1. Idea
Los tres oficios (Pesca, Cultivo, Herrería) dan **equipo equivalente**
por el mismo esfuerzo (§ 7) y cada uno tiene **armas únicas que solo él
fabrica**. Lore: ecos del pasado magitec que todavía brotan, se hunden o
se templan; el futuro no se toca (un arma "la perdió alguien que todavía
no nació").
- Modos automáticos (pescadores, ayudantes, encargos) suben el árbol
  rápido; el camino dedicado (manual + rama del árbol) lleva a los
  legendarios.

## 2. Marca y catálogo
- Cada arma de oficio es un `ItemInstance` normal con uid
  `gear-<id>-<uid>` (`GearRules.uidFor`); `InventoryRules.addItem`
  conserva la marca (`kUidMarks`). `GearRules.defOf / fishOf /
  professionOf` la leen.
- `kProfessionGear` (12): `vivo_baston/arco/varita/lanza` (Cultivo,
  `GearSource.living`), `hundido_sable/tomo/ballesta/dagas` (Pesca,
  `sunken`), `forja_martillo/hacha/rifle/dagas` (Herrería, `forge`) +
  las forjadas de pez (`fish_<especie>`, `fishForge`).
- Cada una tiene nombre, nombre legendario, tipo, firma (`UniqueMod`
  fijo) y sprite `items.vida_gear_<id>` del manifest.
- Nombres: `data.items.gear.<id>.name/.legend`, `data.items.gear.type.*`,
  `data.items.gear.seed.*` y la plantilla `data.items.gear.fish.name`
  (`localItemName`).

## 3. Cultivo: armas de madera viva
### 3.1 Semillas de arma
`ws_baston/arco/varita/lanza` y sus variantes antiguas `_old`
(`seedAncientChance`), en `farm.ws`. Salen de: buscar en árboles
(`seedSearchChance`), cofres de la mina (`seedMineChestChance`),
encargos (`seedOrderChance`) y variedades mutadas de la cosecha
(Semilla B, `mutate` × `seedMutateShare`).
### 3.2 Cultivo
Se plantan en una parcela como un cultivo (carrusel de semillas del HUD,
`FarmingRules.plantables`); tardan `livingGrowSec`. Etapas de dibujo
`vida_vivo_0..3` (brote, plantín, árbol joven, rama con arma).
### 3.3 Cuidado
Riego (como un cultivo) y hasta `livingCompostMax` bolsas de abono
(`cp` en la parcela). **El tipo de abono decide los afijos**
(`kCompostAffix`): abono → de la vida, rúnico → rúnico, del Eco →
impetuoso, brasa → abrasador, miel → del vampiro, escarcha → gélido.
Las recetas de brasa / miel / escarcha las entrega la rama Abono
(`farm_c5..c7`).
### 3.4 Calidad → rareza
`score = riego × livingWaterQ + abonos × livingCompostQ + antigua ×
livingAncientQ + Madera viva × livingTreeQ + nivel × livingLevelQ`
(± 0.2 al azar). Umbrales `livingFina` / `livingExcelente` /
`livingLegend`: normal → Raro, fina / excelente → Épico (excelente con un
afijo extra), legendaria → Legendario.
**Legendario** pide además: semilla antigua (o un legendario
replantado), `livingLegendCompost` bolsas de `abono_eco` y la rama
Madera viva (`livingRarity` ≥ `livingLegendTree`).
### 3.5 Replantar
Un arma viva de la bolsa (no la equipada) se replanta (`item:<uid>`):
vuelve a crecer y al cosecharla sube `livingRegrowLevels` niveles de
objeto, su rareza puede subir y suma afijos de los abonos nuevos.

## 4. Pesca
### 4.1 Armas hundidas del eco
Cuando el agua da un arma, con `sunkenChance` (× Hondura A, + hondura)
es un arma hundida del eco; los cofres hundidos traen una con
`sunkenChestChance` (baja `sunkenChestFade` por nivel de Pesca, porque el
botín del agua ya crece con el nivel). Rareza: Épico con `sunkenEpic`,
Legendario con `sunkenLegend` + árbol × `sunkenLegendTree` solo si se
cumple la puerta legendaria del agua.
### 4.2 Forja de pez (Brann)
Alternativa a CANJEAR: Brann forja un **pez legendario** en un arma
única (tipo y firma según la especie). Cuesta 1 pez + `fishForgeGold`;
pide Pesca `fishForgeLevel`. Épico, Legendario con `fishForgeLegend` +
árbol × `fishForgeLegendTree`. UI: celdas de pez en ENCARGOS DE FORJA
(`brann-fish-<especie>`), acción `SmithOp.fishForge`.

## 5. Herrería: armas solo de forja
Forjar (no Brann) con `forgeGearChance` (desde Herrería
`forgeGearLevel`) da un arma de `kProfessionGear` forja. Forja B suma un
afijo o sube una rareza (`forgeTierShare`).

## 6. Mecánicas de los sub-caminos
Ver life_trees_v2.md § 2.1 (tabla de efectos por sub-camino).

## 7. Paridad
Test: `test/game_engine/profession_parity_sim_test.dart` (modelo en
`profession_parity_sim.dart`). Una hora de juego manual dedicado por
oficio, con las reglas reales y RNG sembrado, 200 horas por punto;
puntaje = Σ armas/h × peso (`parityRarityRaro/Epico/Legendario`). Cada
oficio debe quedar a ±15 % de la media en los niveles 10, 20 y 30.
Actividad por hora: `parityCatchesPerHour` (× 1 − `parityAutoShare`),
`parityVeinsPerHour`, `parityPlots`, `parityTreeSearchesPerHour`,
`parityOrdersPerHour`, `parityChestsPerHour`.

Resultado actual (puntaje, % frente a la media):

| Nivel | Pesca | Cultivo | Herrería |
|---|---|---|---|
| 10 | 5.47 (+0.4) | 5.09 (−6.7) | 5.80 (+6.3) |
| 20 | 7.42 (−12.4) | 9.23 (+9.0) | 8.75 (+3.3) |
| 30 | 9.69 (+5.8) | 8.75 (−4.4) | 9.04 (−1.4) |

Herrería no forja Legendario en una hora (pide un plano de jefe): su
paridad sale de Épicos más baratos.

## 8. Red
Protocolo 92: `SmithOp.fishForge`; parcela `cp` / `it`; `farm.ws`;
comida `b` / `a`; marcas `gear-`; árbol v2 (`life.tv`, `life.rf`).
