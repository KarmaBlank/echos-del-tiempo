# Spec: Equipo de oficios v2 (forja por piezas, armas de pez, armas vivas)

Estado: PROPUESTA (sin código). Base: profession_gear.md (v0.50,
protocolo 92), mining_smithing.md § 4, loot.md (afijos, ranuras, tiers),
branch_ults.md, ultimates_v2.md, design_pillars.md. Protocolo nuevo:
**93**. Números: grupo **Oficios: equipo v2** del Balance
(`kTuning[TuningId.gearV2]`), todos ajustables.

## 0. Lo que no cambia
- Un arma de oficio sigue siendo un `ItemInstance` normal (marca `gear-`).
- Afijos, tiers por nivel de objeto, ranura de Quebrar, fusión y
  traslado: loot.md, sin cambios.
- Las ULT de camino (branch_ults.md) y las ULT de rareza
  (ultimates_v2.md) siguen como están; v2 solo decide **qué pool** de ULT
  puede tirar un arma de oficio.
- Paridad ±15 % (profession_gear.md § 7) y pilares: partes simples,
  la suma vale más que las partes, nada de grind; lo automático sube
  rápido, lo manual da resultados; hay un camino dedicado al legendario.
- Lore: solo ecos del tiempo, futuro inmutable, pasado magitec.

## 1. Conceptos comunes a los tres oficios
### 1.1 Afinidad
Toda arma de oficio v2 tiene **una afinidad** (`aff`), que viene del
material que la define (metal base, pez, bioma de la semilla). La afinidad
decide (a) el elemento del arma, (b) un afijo implícito chico y (c) el
**pool de ULT** que puede tirar.

| Afinidad | Elemento / estilo | Implícito | Pool de ULT (caminos de branch_ults.md) |
|---|---|---|---|
| `ferro` | físico, filo | +% ATQ | filo, verdugo, vanguardia |
| `quiebre` | físico, quebradura | +daño a Quebrar | quiebre, coloso, muralla |
| `brasa` | fuego | +stacks Quemadura | brasa, forja |
| `escarcha` | hielo | +stacks Congelación | escarcha, cronos |
| `toxina` | veneno | +stacks Veneno | toxina, acecho, alquimia |
| `voltio` | rayo | +carga de ULT | voltio, centella, galvanica |
| `marea` | agua | +regeneración | marea, monzon, manantial |
| `viento` | aire, velocidad | +velocidad | viento, lluvia, precision |
| `arcano` | maná, runas | +maná | arcano, runas, hojaArcana |
| `luz` | sagrado | +curación | luz, fe, exorcismo |
| `eco` | temporal | +% crítico | cronos, sintonia, prisma |
| `bosque` | vida (solo armas vivas) | +robo de vida | ver § 4.4 |

- Una ULT del pool solo es válida si su camino admite el **tipo** del arma
  (tabla de branch_ults.md § 5). Si el cruce queda vacío, se usa la ULT de
  tipo de siempre (loot.md § 8.1).
- Legendario: además del pool, puede tirar las **ULT legendarias de esa
  afinidad** (ultimates_v2.md, filtradas por elemento) y, si el material
  lo permite, una **ULT especial de material** (§ 2.5 / § 3.4 / § 4.4).

### 1.2 Calidad de oficio y ranuras de mod
Cada fabricación calcula una **calidad** `q` (0..1) y de ahí las
ranuras de mod (prefijos + sufijos):

```
q = clamp(nivelOficio / slotLevelCap × slotLevelW
        + calidadMateriales × slotMatW
        + bonusManual × slotManualW, 0, 1)
ranuras = rarity.minAffixes + floor(q × (rarity.maxAffixes − rarity.minAffixes + slotBonusMax))
```

- `calidadMateriales` = media de la calidad de las piezas (tier del
  material / tier máximo).
- `bonusManual` = 1 si se hizo a mano (forja paso a paso, pesca manual,
  cuidado manual de la parcela), `autoQualityShare` (0.5) si lo hizo un
  ayudante. Lo automático **sube el oficio igual de rápido**, pero rinde
  ranuras un poco menores.
- `slotBonusMax` (1): un arma perfecta puede tener **una ranura más** que
  el máximo de su rareza (marcada "Obra maestra"). Nunca más de una.

### 1.3 Rarezas
Las cinco de loot.md: Normal, Mágico, Raro, Épico, Legendario. Cada oficio
tiene su puerta legendaria propia y dedicada (§ 2.4, § 3.3, § 4.3).

## 2. HERRERÍA: forja por piezas
### 2.1 Idea
Forjar desde cero **cualquier tipo de arma** eligiendo cada pieza. Cada
pieza es simple (un material, una ranura), pero juntas definen el arma.
Empieza con lo más básico (cobre, roble) y escala por tiers.

### 2.2 Piezas por tipo
| Pieza | Qué define | Materiales posibles |
|---|---|---|
| **Base / núcleo** | tier → nivel de objeto, **afinidad** | lingote (§ 2.3) |
| **Cabeza / hoja** | daño base (± % por material), afijo implícito 2 | lingote, escama de pez, cristal |
| **Mango / empuñadura** | velocidad / maná, estadística requerida | madera, hueso, madera viva |
| **Ligadura** | estabilidad: sube `q` y el rango de tiradas | cuero, fibra, alambre, tendón |
| **Engaste** (opcional, desde Raro) | +1 tirada guiada de afijo (elegís la familia) | gema, núcleo, esencia |

Cada tipo de arma nombra sus piezas en la UI (espada: hoja / empuñadura /
guarda; arco: palas / empuñadura / cuerda; varita: núcleo / vara / anillo;
martillo+escudo: cabeza / mango / ribete; tomo: tapa / lomo / cierre;
rifle: cañón / culata / mecanismo; etc.), pero las 5 ranuras son las
mismas en reglas (`kForgePartSlots[type]` solo traduce nombres).

### 2.3 Materiales de base (tiers y afinidad)
| Tier | Material | Nivel de objeto | Afinidad | HerrerÍa mín. |
|---|---|---|---|---|
| 1 | Cobre | 1–8 | ferro | 1 |
| 2 | Hierro | 8–15 | ferro / quiebre (forjado en frío) | 5 |
| 3 | Acero de brasa | 15–22 | brasa | 10 |
| 4 | Plata de escarcha | 18–25 | escarcha | 12 |
| 5 | Bronce de ciénaga | 20–28 | toxina | 15 |
| 6 | Cobre voltaico | 24–32 | voltio | 18 |
| 7 | Oricalco de marea | 28–36 | marea / viento | 22 |
| 8 | Hierro estelar | 32–40 | arcano / luz | 26 |
| 9 | Acero de eco | 36–44 | eco | 30 |
| 10 | Aleación del pasado magitec | 40–50 | cualquiera (elegís) | 35 |

- Los lingotes salen de las vetas existentes (mining_smithing.md § 1–3);
  los tiers 8–10 piden vetas raras de mazmorra/jefe.
- El nivel de objeto final = mín(nivel del personaje − `craftIlGap`,
  rango del tier ajustado por `q`).

### 2.4 Rareza en la forja por piezas
La rareza máxima sigue la tabla de mining_smithing.md § 4 (nivel de
HerrerÍa). Dentro del tope, la rareza tirada depende de `q`:
`q ≥ forgeQRaro/Epico/Legend`. **Legendario** pide además: base de tier
≥ 8, Plano antiguo o Núcleo de guardián (como hoy) y la rama Forja del
árbol de vida. Ese es el camino dedicado.

### 2.5 ULT especiales de material (tiers 8–10)
| Material | ULT especial (nueva) | Efecto |
|---|---|---|
| Hierro estelar | **Caída Estelar** | daño de luz/arcano en área + Quebrar |
| Hierro estelar | **Firmamento Quieto** | escudo al grupo + silencio a enemigos |
| Acero de eco | **Golpe que Ya Ocurrió** | repite el último golpe del aliado con 60 % de daño |
| Acero de eco | **Eco Doble** | la próxima habilidad se lanza dos veces |
| Aleación magitec | **Núcleo Despierto** | sobrecarga: +ULT a todo el grupo, autodaño |
| Aleación magitec | **Engranaje del Pasado** | congela el turno de un enemigo (no jefes) |

Solo Legendarios; `forgeSpecialUltChance` (0.35) de reemplazar la ULT del
pool. Viven en `kMaterialUltimates` (se suman a `kAllUltimates`).

### 2.6 Fallos y sin grind
- No hay fallos que destruyan materiales. La vista previa muestra rangos
  (nivel de objeto, ranuras posibles, pool de ULT), no las tiradas.
- Repetir la misma receta guarda "receta favorita" (un clic).

## 3. PESCA: armas de pez del otro tiempo
### 3.1 Idea
Los peces **Épicos y Legendarios** son peces mágicos "de otro tiempo".
En Brann (forja de pez, profession_gear.md § 4.2) un pez se **desarma en
piezas** que sirven en la forja por piezas o en una receta directa.

### 3.2 Piezas del pez
| Pieza | Uso como pieza (§ 2.2) | Rinde |
|---|---|---|
| **Escamas** | cabeza/hoja o chapado | Épico 2, Legendario 3 |
| **Esqueleto** | mango/cuerpo (como madera, pero hueso: +velocidad) | 1 |
| **Esencia / sangre** | engaste; da el rasgo "Arma de pez del otro tiempo" | Épico 1, Legendario 2 |

Desarmar cuesta `fishPartGold` y pide Pesca `fishPartLevel` (Épico) /
`fishForgeLevel` (Legendario, como hoy).

### 3.3 Rareza
- Receta directa (pez entero, como hoy): Épico → arma Raro/Épico;
  Legendario → Épico, Legendario con `fishForgeLegend` + árbol.
- Por piezas: la rareza la decide la forja (§ 2.4), pero **escama +
  esqueleto + esencia del mismo pez** cuentan como "set del pez" y suben
  `q` en `fishSetQ`. Legendario pide la esencia de un pez legendario.

### 3.4 Rasgo y afinidad por especie
Rasgo fijo **Eco del otro tiempo**: el arma gana +`fishTraitUlt` % de
carga de ULT y su primer golpe de cada combate aplica el elemento de su
afinidad. La especie decide afinidad y tipo sugerido:

| Pez (rareza) | Afinidad | Tipo sugerido | ULT especial (solo Legendario) |
|---|---|---|---|
| Lucio de brasa (Épico) | brasa | dagas | — |
| Raya de escarcha (Épico) | escarcha | lanza | — |
| Anguila voltaica (Épico) | voltio | varita | — |
| Pez de ciénaga (Épico) | toxina | ballesta | — |
| Carpa de eco (Legendario) | eco | tomo | **Marea del Ayer**: cura lo perdido el turno anterior |
| Leviatán menor (Legendario) | marea | sable/espada | **Abismo que Recuerda**: arrastre + Quebrar |
| Pez de luz antigua (Legendario) | luz | báculo | **Faro Sumergido** |

La tabla final usa las especies reales de fishing.md (`kFishSpecies`);
cada especie Épica/Legendaria recibe `aff` y `type` en el catálogo.

## 4. CULTIVO: armas vivas v2
### 4.1 Más variedad
Semillas de arma para **todos los tipos** (`ws_<tipo>`), no solo 4:
espada, hacha, lanza, dagas, arco, ballesta, varita, báculo, tomo,
martillo+escudo, maza+escudo, espada+escudo (rifle no: no crece).

### 4.2 Bioma de la semilla → afinidad
La semilla guarda su bioma de origen (`b`). Cada bioma tiene bosque:

| Bioma | Afinidad | Rasgo vivo |
|---|---|---|
| Bosque / pradera | bosque | Savia: robo de vida |
| Pantano | toxina | Espinas venenosas |
| Lava | brasa | Corteza ardiente |
| Montaña / piedra | quiebre | Raíz pétrea: quebradura |
| Nieve | escarcha | Rama helada |
| Costa | marea | Musgo de marea |
| Ruinas magitec | eco | Brote del eco |

### 4.3 Rareza como botín
Se tira como loot (Normal → Legendario) con pesos movidos por:
`score = nivelCultivo × livingLevelQ + calidadSemilla × livingSeedQ +
abonos × livingCompostQ + riego/cuidado × livingWaterQ` (la fórmula de
profession_gear.md § 3.4, con `calidadSemilla` nueva: común, buena,
antigua). Legendario mantiene su puerta dedicada (semilla antigua, abono
del Eco, rama Madera viva).

### 4.4 Habilidades y ULT "ecos del bosque"
Las armas vivas tienen **habilidad propia** (una, por tipo) y desde Épico
**ULT propia** del pool `bosque` + la de su afinidad de bioma.

| Habilidad viva | Tipos | Efecto |
|---|---|---|
| Brote | báculo, varita, tomo | cura chica en el tiempo |
| Enredadera | lanza, arco, ballesta | inmoviliza 1 turno |
| Corteza | escudos | escudo que crece por turno |
| Espina | espada, hacha, dagas | daño + estado de su afinidad |

| ULT del bosque (nueva) | Rareza | Efecto |
|---|---|---|
| **Eco del Bosque** | Épico+ | invoca un árbol aliado 2 turnos |
| **Raíces del Ayer** | Épico+ | todos los enemigos: inmóviles + estado de afinidad |
| **Bosque que Vuelve** | Legendario | revive a un aliado caído con 30 % |

Al replantar (§ 3.5 de profession_gear.md), un arma viva puede ganar la
ULT si sube a Épico.

## 5. Paridad
- El modelo de `profession_parity_sim.dart` suma `q` y ranuras al
  puntaje: `puntaje = Σ armas/h × peso(rareza) × (1 + ranurasExtra ×
  parityExtraSlotW)`.
- Objetivo: cada oficio ±15 % de la media en niveles 10/20/30, y además
  manual ≥ auto × `parityManualEdge` (1.15) para el mismo oficio.
- Si la forja por piezas sube de más a HerrerÍa, se baja `forgeQEpico`.

## 6. UI (DsColors, grilla + detalle a la derecha, sin secciones apiladas)
### 6.1 HERRERÍA → FORJAR (paso a paso)
- Arriba: subtabs de paso **Tipo · Base · Hoja · Mango · Ligadura ·
  Engaste · Resultado** (no secciones apiladas).
- Centro: grilla de materiales válidos para ese paso (casillas tipo
  INVENTARIO, grises con tooltip si falta nivel o material).
- Derecha: detalle del arma en armado (sprite por piezas desde el
  manifest, nivel de objeto, rangos, ranuras posibles, afinidad, pool de
  ULT, costo). Botón FORJAR gris con motivo si falta algo.
### 6.2 Brann → PEZ DEL OTRO TIEMPO
Grilla de peces Épicos/Legendarios de la bolsa; detalle: piezas que rinde,
afinidad, tipo sugerido; botones **Forjar entero** / **Desarmar**.
### 6.3 Detalle de arma viva
Tooltip y panel: bioma de origen, rasgo, habilidad, ULT, veces
replantada; filtro "Vivas" en el inventario.
### 6.4 Sprites
`items.forge_part_<tipo>_<pieza>_<tier>`, `items.fish_part_<especie>_<pieza>`,
`items.vida_gear_<tipo>_<bioma>` en `sprite_manifest.yaml` (8 bits).
i18n: `data.items.gear2.*` en es-AR, en, zh-Hans.

### 6.5 Íconos: misma forma, color por material
Hoy (sprites.md "Íconos" e "Identidad del arma";
`lib/core/procedural/item_icon_rows.dart`, `WeaponLook` /
`paintItemIcon`, `tool/export_item_icons.dart`, `WeaponOverlay.kGrips`)
hay un PNG 16×16 por forma (25) + `<forma>_acento.png` gris teñido por
rareza. **Decisión del dueño: no hay variantes de silueta.** Cada tipo
conserva su única forma (los 25 PNG, editables en el Editor de Sprites);
solo cambian los **colores** según los materiales elegidos.
- **Capas de recoloreo por región** (escala de grises, mismo 16×16):
  `<forma>_head.png` (hoja/cabeza/metal), `<forma>_grip.png`
  (mango/asta/madera/hueso) y el `<forma>_acento.png` existente
  (gema/acento). Las genera `tool/export_item_icons.dart` a partir del
  arte actual; todas van al manifest y se pueden reemplazar en el Editor.
- **Tinte**: cada capa usa la rampa de 4 tonos (`kMaterialRamps`) del
  material elegido para esa pieza: cabeza → material de base/hoja,
  mango → material del mango, acento → afinidad/rareza. Encima, como hoy:
  aura, destello y marca de ULT por rareza.
- **Peces**: rampa de escama (por especie) en cabeza, rampa de hueso en
  mango. **Vivas**: rampa de madera viva teñida por bioma (§ 4.2).
- **Caché**: ícono compuesto por clave `(forma, materiales, afinidad,
  rareza)`; lo usan inventario, tooltips, retratos y el sprite en mano
  del mapa/batalla (vía `WeaponOverlay.kGrips`).
- **Retrocompatibilidad**: los materiales por defecto reproducen el
  ícono actual píxel a píxel (test de píxeles sobre las 25 formas); un
  arma sin `pt` usa esos materiales.
- **Vista previa**: `docs/preview/weapon_parts/` (export tool): por
  forma, grilla material de cabeza × material de mango, más filas de
  rareza y afinidad.
- Tamaño: 25 formas × 2 capas nuevas = **50 PNG chicos** (el acento ya
  existe); las rampas son datos, no archivos.

## 7. Guardado y red (protocolo 93)
- `ItemInstance` suma campos opcionales: `aff` (afinidad), `pt` (piezas:
  lista de ids de material), `q` (calidad 0..100), `mw` (obra maestra),
  `bo` (bioma de origen, vivas). Ausentes = valores por defecto.
- Acción nueva `SmithOp.forgeParts` con `t` (tipo), `p` (piezas) y
  `SmithOp.fishSplit` (`s` especie). Semilla `farm.ws` gana `b` y `sq`.
- El host valida todo (materiales, niveles, tope de rareza); los clientes
  solo mandan la elección.

## 8. Migración
- Armas de oficio v1: `aff` inferida del afijo/firma (`kCompostAffix`,
  especie, o `ferro`), `q` = 50, sin piezas. No pierden mods.
- Semillas viejas: bioma `bosque`, calidad común (`_old` → antigua).
- Las 4 armas vivas y las 4 de forja v1 quedan como recetas.

## 9. Claves de Balance (grupo gearV2)
`slotLevelCap, slotLevelW, slotMatW, slotManualW, slotBonusMax,
autoQualityShare, forgeQRaro, forgeQEpico, forgeQLegend,
forgeSpecialUltChance, fishPartGold, fishPartLevel, fishSetQ,
fishTraitUlt, livingSeedQ, livingSeedGood, livingSeedAncient,
livingSkillPower, livingUltChance, parityExtraSlotW, parityManualEdge`
+ por tier de base: `baseIlMin/Max[t]`, `baseLevel[t]`.

## 10. Plan de tests
- `forge_parts_rules_test`: afinidad por base, nivel de objeto por tier,
  fórmula de ranuras (bordes 0 y 1, obra maestra máx. +1), puerta
  legendaria, pool de ULT ∩ tipo, fallback a ULT de tipo.
- `fish_parts_test`: rendimientos por rareza, set del pez, rasgo.
- `living_v2_test`: bioma → afinidad, pesos de rareza, habilidad/ULT,
  replantar sube a Épico y gana ULT.
- `session_json` ida y vuelta con campos nuevos y migración v92 → v93.
- `profession_parity_sim_test` con v2: ±15 % y ventaja manual.
- Protocolo: handshake 93 rechaza 92.

## 11. Preguntas abiertas
Ver el reporte de propuesta (afinidades finales, ULT especiales nuevas vs
reusar, número de semillas, rifle vivo, coste de desarmar peces).
