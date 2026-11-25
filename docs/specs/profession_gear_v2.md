# Spec: Equipo de oficios v2 (forja por piezas, peces desarmados, armas vivas)

Estado: IMPLEMENTADO (v0.50.x, protocolo **93**). Base: profession_gear.md
(protocolo 92), mining_smithing.md § 4, loot.md, branch_ults.md,
ultimates_v2.md, design_pillars.md. Números: grupo **Oficios: equipo v2**
del Balance (`kTuning[TuningId.gearV2]`), todos ajustables.

Dirección del dueño: **simple y mínimo**. Nada de ULT nuevas, metales
nuevos, rasgos nuevos ni habilidades nuevas: v2 solo **combina lo que ya
existe** (lingotes, raros de bioma, peces, semillas, elementos, pools de
ULT, íconos).

## 0. Lo que no cambia
- Un arma de oficio sigue siendo un `ItemInstance` normal (marca `gear-`).
- Afijos, tiers, Quebrar, fusión y traslado: loot.md, sin cambios.
- Las ULT existentes no cambian; v2 solo decide **qué pool** puede tirar.
- Las armas fijas de v1 (vivas, hundidas, de forja, de pez) siguen igual.
- Paridad ±15 % (profession_gear.md § 7) y pilares (lo automático sube
  igual de rápido, lo manual rinde más; camino dedicado al legendario).
- Lore: solo ecos del tiempo, futuro inmutable, pasado magitec.

## 1. Afinidad = elemento existente
La afinidad de un arma v2 es un **`GameElement`** (físico, fuego, hielo,
veneno, sagrado, agua, electro). No hay tipos nuevos.

| Fuente | Afinidad |
|---|---|
| Lingote de cobre / Ámbar de raíz | físico / veneno |
| Lingote de bronce rúnico / Engranaje antiguo | electro |
| Lingote de hierro helado / Cristal de escarcha | hielo |
| Lingote de acero ígneo / Corazón de magma | fuego |
| Lingote de plata del eco / Arena detenida | sagrado |
| Pez (por especie, `fishAffinity`) | hielo / fuego / electro / sagrado / agua |
| Arma viva (abono elemental que más tiene) | fuego / hielo / electro / sagrado / veneno / físico |

Efectos:
- **Elemento del arma** (`ItemInstance.element`, weapon_identity.md § 4)
  desde Raro, salvo físico.
- **Pool de ULT**: las ULT que ya existen para ese tipo de arma
  (`branchUltsForType` y, en Legendario, las ULT de legendarios v2 de ese
  tipo) **filtradas por elemento == afinidad**. Si el cruce queda vacío,
  el pool normal del tipo (`ultV2ModsForType`). Probabilidad: la de
  siempre (Raro 8 %, Épico 20 %); Legendario `legendUltChance`.

## 2. Calidad y ranuras (manual vs ayudante)
```
q = clamp(nivelOficio / slotLevelCap × slotLevelW
        + calidadMateriales × slotMatW
        + manual × slotManualW, 0, 1)
mods = rarity.minMods + floor(q × (rarity.maxMods − rarity.minMods + 1)) (tope maxMods)
obra maestra: q ≥ masterworkQ → +1 mod sobre el máximo (`mw`), nunca más
```
- `manual` = 1 hecho a mano; `autoQualityShare` (0.5) si lo hizo un
  ayudante (Brann forja el pez entero; arma viva que cosecha quien no la
  plantó). El oficio sube igual de rápido.
- `calidadMateriales` = media de `tier / 5` de las piezas (los peces:
  Épico 4, Legendario 5). Arma viva: semilla común 0.5, antigua 1.
- Paridad: manual ≥ ayudante × `parityManualEdge` (1.15).

## 3. HERRERÍA: forja por piezas
HERRERÍA → FORJAR, **paso a paso** (subtabs, no secciones apiladas):

| Paso | Material | Define |
|---|---|---|
| **Tipo** | cualquier tipo de arma | la forma |
| **Base** | lingote (5 tiers existentes) | nivel de objeto (`ingotIlPerTier`), afinidad |
| **Cabeza / hoja** | lingote o escama de pez | color de la cabeza, calidad |
| **Mango** | lingote o hueso de pez | color del mango, calidad |
| **Engaste** (opcional) | raro de bioma o esencia de pez | **cambia la afinidad** al suyo, +`settingQ` |

Sin ligadura (no aportaba decisión). Sin fallos que destruyan materiales.
- Costo: `partsBaseIngots` del lingote base + 1 de cada pieza + oro
  `craftGoldPerIl` × nivel de objeto.
- Rareza = la que da `q` (`forgeQMagico/Raro/Epico/Legend`), con tope del
  nivel de Herrería (mining_smithing.md § 4). **Legendario** además
  consume un Plano antiguo o un Núcleo de guardián (camino dedicado).
- El arma: base del catálogo del tipo al nivel de objeto, mods por § 2,
  elemento y ULT por § 1, nombre "<Tipo> de <material base>".
- Brann (encargo) sigue con la receta de siempre (mining_smithing.md § 5).

## 4. PESCA: peces del otro tiempo
En Brann → PEZ DEL OTRO TIEMPO (grilla de peces Épicos y Legendarios):
- **Épico**: solo **Desarmar** (piezas).
- **Legendario**: **Forjar entero** (flujo de v1, ahora con afinidad, pool
  de ULT y `q` de ayudante) **o Desarmar**.
- Desarmar **consume el pez**, cuesta `fishPartGold` y pide Pesca
  `fishPartLevel`. Rinde escamas (`fishScaleEpic/Legend`), hueso
  (`fishBone`) y esencia (`fishEssenceEpic/Legend`), que se guardan como
  materiales de herrería (`fp_<especie>_<pieza>`) y se usan en la forja
  por piezas (§ 3).

## 5. CULTIVO: armas vivas
- Semillas para **todos los tipos menos rifle** (`ws_<tipo>` y
  `ws_<tipo>_old`), desde el principio, con el mismo flujo de semilla
  (plantar, regar, abonar, cosechar, replantar).
- Afinidad = el abono elemental que más tiene la parcela (§ 1). Pool de
  ULT por § 1 (ULT existentes). Ranuras por § 2.
- Las 4 armas vivas de v1 conservan su sprite; las nuevas tienen su
  sprite generado `vida_gear_vivo_<tipo>` (y semilla `vida_semilla_ws_*`)
  por `tool/export_life_icons.dart`, vía manifest.

## 5b. Pesca: armas hundidas y peces enteros
- El arma hundida pasa por el mismo toque v2 (afinidad + calidad); la
  pesca manual cuenta como mano (`slotManualW`), la autopesca no.
- Ajustes de v1 (`profession_gear` en el catálogo): `sunkenLegend`
  0.02 → 0.035 y `fishForgeLevel` 10 → 12 para mantener la paridad.

## 6. Íconos: misma forma, color por material
Cada tipo conserva **su única forma** (los PNG de `items/`, editables en
el Editor). Solo cambian colores:
- Capas en grises por forma, 16 × 16: `<forma>_head.png` (metal) y
  `<forma>_grip.png` (mango), más el `<forma>_acento.png` de siempre.
  Las genera `tool/export_item_icons.dart` **a partir del PNG actual**: un
  píxel va a la capa si coincide con uno de los 4 tonos del color por
  defecto (sombra, base, luz, brillo); el gris guarda el índice del tono.
- Tinte: cada píxel de la capa toma el tono de la rampa de 4
  (`kMaterialRamps`) del material de esa pieza. Cabeza → material de la
  cabeza; mango → material del mango; acento → rareza (como hoy).
- **Retrocompatibilidad**: la rampa por defecto reproduce el PNG píxel a
  píxel (test sobre las 25 formas); un arma sin `pt` no se recolorea.
- Vista previa: `docs/preview/weapon_parts/` (forma × material de
  cabeza × material de mango).

## 7. Guardado y red (protocolo 93)
- `ItemInstance`: `pt` (piezas: `[base, cabeza, mango, engaste?]`, ids de
  material; un arma viva guarda `['living', <afinidad>]`, una de pez entero `['fish', <especie>]`) y `mw` (obra
  maestra). Ausentes = v1.
- `SmithOp.forgeParts` (`b` tipo, `g` lingote base, `p` piezas) y
  `SmithOp.fishSplit` (`g` especie).
- El host valida todo (materiales, niveles, tope de rareza).

## 8. Migración
- Armas de oficio v1 sin `pt`: se les infiere la afinidad (elemento, si
  no el del afijo firma) y quedan con `pt = ['v1', <material>]`; no
  pierden mods, nombre ni sprite.
- Semillas: los ids `ws_*` de v1 siguen válidos; las nuevas solo se suman.

## 9. Claves de Balance (grupo gearV2)
`slotLevelCap, slotLevelW, slotMatW, slotManualW, autoQualityShare,
masterworkQ, settingQ, forgeQMagico, forgeQRaro, forgeQEpico,
forgeQLegend, partsBaseIngots, fishPartGold, fishPartLevel,
fishScaleEpic, fishScaleLegend, fishBone, fishEssenceEpic,
fishEssenceLegend, legendUltChance, parityExtraSlotW, parityManualEdge`.

## 10. Tests
- `gear_v2_rules_test`: afinidad por material, q y ranuras (bordes,
  obra maestra +1 máx.), rareza por q con tope y receta, pool de ULT ∩
  elemento y fallback, desarmar pez (épico solo piezas, consume el pez).
- `gear_v2_migration_test`: v1 → `pt`, ida y vuelta de `session_json`.
- `weapon_parts_icon_test`: rampas por defecto = PNG actual (25 formas).
- Widgets: pasos de la forja y desarme en Brann.
- `profession_parity_sim_test`: ±15 % en 10/20/30 y manual ≥ 1.15×.
- Handshake 93.
