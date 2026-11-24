# Spec: Minería y herrería (v0.44.0, protocolo 69)

Pedido del dueño: minas tranquilas en cada exterior de bioma, vetas que
se pican con un pico, materiales de herrería con sentido (mena → lingote
→ arma) y la Herrería como oficio de jugador, con Brann como camino para
quien no forja. Todo mínimo.

Código: datos en `lib/game_engine/data/smithing_catalog.dart`; minas en
`lib/game_engine/rules/mine_generator.dart`; reglas puras en
`lib/game_engine/rules/mining_rules.dart` (`MiningRules`,
`SmithCraftRules`); sala en `session_engine_mining.dart`. Tunables:
Editor → Balance → **Minería y herrería** (`TuningId.smithing`).

## 0. Lo que no cambia

- Esquirlas, Cristales y Prismas siguen siendo los materiales de
  **mejora de armas encontradas** (materials_economy.md). La herrería no
  los usa ni los da.
- Pueblo 100 % opcional (roles.md § 0): nada del camino crítico depende
  de minar o forjar; el balance de solo mazmorras no cuenta las armas
  forjadas.
- Clima y estaciones (otra rama): cada material tiene `seasons` (vacío =
  todo el año). Hoy no se mira; el gancho de temporada filtra o pondera
  por ese campo sin tocar las reglas.

## 1. Minas

### 1.1 Entradas

Cada exterior de bioma (`BiomeLayout.mines`, por defecto dos: tiles
(4, 3) y (20, 3), en la fila de las entradas de mazmorra) tiene bocas de
mina (`Tile.mineEntrance`, `m`, sólida) con su cartel `MINA`. Con E
frente a la boca el jugador entra (`TravelAction('mine:<bioma>:<i>')`);
en la mina, E frente a la salida (`<`) vuelve al exterior, delante de la
misma boca. Con movimiento libre (free_movement.md) cada mina es su
propia instancia (clave `mine:<bioma>:<i>`), como un bioma.

### 1.2 Generación

`MineGenerator.generate(bioma, i, semilla)`: 30 × 20 tiles, caminata al
azar (`mulberry32`, el mismo PRNG de los mapas) desde la salida hasta
cubrir ~40 % del área. Determinista: misma semilla → mismo mapa.
Semilla = FNV-1a de `<mundo>|mine:<bioma>:<i>|<semana>` (semana = día
del mundo / `mineReshapeDays`): la mina cambia de forma cada semana.

- Vetas: `mineNodes` tiles `r` (sólidos) que no desconectan nada (sus 8
  vecinos son caminables) y lejos de la salida.
- Ambiente: 2–3 faroles encendidos (`Tile.lanternLit`), tema `mina`
  (oscuro: la oscuridad y las luces se dibujan solo en lo visible, como
  las mazmorras oscuras; lighting.md § 5) y las vetas brillan tenue.
- PNJ ocasional (`mineNpcChance`): un minero o un ermitaño parado en un
  tile libre. E muestra una frase (aviso local). Frases **BORRADOR**
  (`ui.world.mine.npc.*`; es-AR y en, zh-Hans como borrador).
- **Sin enemigos**: la mina es un mapa `lobby` (zona segura, modo
  lobby); nunca hay misión ni encuentros.

### 1.3 Picar

E frente a una veta (≤ `mineReach` px) manda `MineAction(i)`. Se pica con
el pico que todo personaje lleva (como la caña de rama; sprite
`items.vida_pico`). Igual que recolectar: un toque, el anfitrión valida
distancia y que la veta esté lista. Da:

- `mineOreMin`..`mineOreMax` menas del bioma.
- Con `mineRareChance`, 1 material raro del bioma.
- XP de Herrería `mineXp` × nivel de la mena.

La veta queda gastada (`r` → `j`) por `mineRespawnSec` segundos del reloj
de la sala (`TownState.wild`, clave `mine:<bioma>:<i>:<veta>`).

### 1.4 Vetas raras en mazmorras

Cada piso de una mazmorra de zona tiene, con `dungeonOreChance`, una veta
rara (`PoiKind.ore`, tile `r`, en un lugar con los 8 vecinos libres). Se
pica con E como cualquier PdI (una vez: `poiUsed`, id `piso × 100 + 70`;
vuelve con la reaparición de la mazmorra, persistent_dungeons.md § 3). Da 1
material raro del bioma de la zona y, con `dungeonSchematicChance`, un
**Plano antiguo**.

### 1.5 Jefes

Vencer a un jefe de zona (no Travesía ni tutorial) da a cada jugador
`bossCore` **Núcleo de guardián**.

## 2. Materiales de herrería

Guardados en el perfil, `LifeSkills.ores` (JSON `ore`, tope 999 por
material). Ids en inglés; nombres en `data.materials.smith.<id>.name`.

| Bioma | Mena (nivel) | Lingote | Raro del bioma |
|---|---|---|---|
| Bosque | `ore_copper` Mena de cobre (1) | `ingot_copper` | `rare_amber` Ámbar de raíz |
| Ruinas | `ore_bronze` Mena de bronce rúnico (2) | `ingot_bronze` | `rare_cog` Engranaje antiguo |
| Cavernas | `ore_frost` Mena de hierro helado (3) | `ingot_frost` | `rare_rime` Cristal de escarcha |
| Grieta | `ore_ember` Mena de acero ígneo (4) | `ingot_ember` | `rare_magma` Corazón de magma |
| Abismo | `ore_echo` Mena de plata del eco (5) | `ingot_echo` | `rare_sand` Arena detenida |

Especiales: `schematic` Plano antiguo (receta, vetas de mazmorra) y
`guardian_core` Núcleo de guardián (jefes).

### 2.1 Colección de materiales (datos; UI pendiente)

Para OFICIOS → Herrería → COLECCIÓN (la plantilla de grilla compartida
la arma otra rama; el integrador la conecta). Por jugador,
`LifeSkills.oreLog` (JSON `ol`: `{id: [día, origen, total]}`): primer
hallazgo, origen (`mine:<bioma>`, `dungeon:<zona>`, `boss`, `smelt`) y
cuántos se encontraron en total. Usos por material, sacados de los datos
(`SmithCollection.usesOf`: `smelt`, `forge`, `rare`, `legend`).
`SmithCollection.entries(perfil)` devuelve cada material (id, ícono del
manifest, clave del nombre, descubierto y filas como clave i18n +
argumentos `ui.inventory.smith.col.*`); los no descubiertos van sin
filas (la UI los muestra como "?" gris).

## 3. Fundir

En la FORJA del pueblo, pestaña HERRERÍA → FUNDIR: `smeltOre` menas +
`smeltGoldPerTier` × nivel de oro → 1 lingote. XP `smeltXp` × nivel por
lingote. Lotes ×1 / ×5. Cualquiera puede fundir.

## 4. Forjar un arma

HERRERÍA → FORJAR: grilla de bases del catálogo de armas (las de nivel ≤
el nivel de objeto posible), detalle a la derecha con lingote, rareza y
costo. `SmithAction(forge, base, ingot, rareza)`.

- Nivel de objeto = mín(nivel del personaje − `craftIlGap`, `ingotIlPerTier`
  × nivel del lingote). Las mejores armas siguen saliendo de las mazmorras.
- Costo: lingotes por rareza (`ingots<Rareza>`), materiales raros del
  bioma del lingote (`rare<Rareza>`, desde Raro) y `craftGoldPerIl` × nivel
  de objeto.
- Rareza por nivel de Herrería:

| Rareza | Nivel | Lingotes | Raros | Extra |
|---|---|---|---|---|
| Común | 1 | 3 | 0 | |
| Mágico | `lvMagico` 4 | 4 | 0 | |
| Raro | `lvRaro` 10 | 6 | 1 | |
| Épico | `lvEpico` 18 | 8 | 2 | |
| Legendario | `lvLegend` 25 | 10 | 3 | 1 Plano antiguo **o** 1 Núcleo de guardián |

- Legendario = un único (`LootRules.pickUnique`) con preferencia por la
  familia de la base elegida; usa el Plano si hay, si no el Núcleo.
- Mods, elemento y pasiva salen como un arma de cofre de esa rareza.
- XP: `craftXp` × (rareza + 1).

## 5. Encargo a Brann

HERRERÍA → BRANN (solo con Brann viviendo en una casa, roles.md § 4):
la misma receta, pero Brann pone el oficio. Paga `brannGoldPerIl` × nivel
de objeto en vez de `craftGoldPerIl`. Rareza máxima = la del encargo de
forja (`ResidentRules.commissionRarity`: oficio más alto + relación;
legendaria solo arraigado, con su objeto y el oficio en
`comLegendLevel`), y el legendario igual pide el Plano o el Núcleo. Da
`smithXpCommission` / 2 de Herrería a quien lo pide. Es la extensión
del encargo de forja de siempre, que sigue igual.

## 6. Red

- Protocolo 69: `ore` y `ol` en `LifeSkills`, acciones `mine` (`i`) y `smith`
  (`o`, `b`, `g`, `r`, `n`), `PoiKind.ore`, lugares `mine:<bioma>:<i>`.
- Todo lo valida el anfitrión (distancia, veta lista, pueblo, costo,
  nivel, Brann). La Travesía rechaza todo.

## 7. Balance

Números en `kTuning[TuningId.smithing]` con etiqueta en Balance. Prueba
`test/game_engine/mining_smithing_test.dart`: el nivel de objeto
forjado queda debajo del personaje, la rareza respeta el nivel y un
Épico forjado cuesta al menos `ingotsEpico` × `smeltOre` menas.

## 8. Pendiente

- Picos mejores (hoy uno solo) y minijuego de golpe.
- Arte final de vetas, boca de mina y PNJ (placeholders en
  `sprite_manifest.yaml`).
- Estaciones (§ 0).
