# Procedural vegetation (trees and bushes)

Status: implemented (feat/procedural-trees). Scope: how trees and bushes
LOOK and how they are edited. Where they are placed (biome generation,
`biome_regions.dart`) is out of scope and unchanged.

## 1. Goals

- Always procedural, full pixel art, minimalist 8-bit feel. Not more
  detailed than the previous round canopy: one 16 × 16 tile, at most
  seven palette slots, flat shading (lit top-left, dark bottom-right),
  optional one-pixel dark outline for a readable silhouette.
- A small, limited palette per biome (6 colours).
- A few species per biome: `deciduous`, `conifer`, `dead` (dead / ash
  tree) and `bush`.
- Deterministic by seed; generated once and cached as images.
- Editable in the Editor; any biome × species can be replaced by a PNG.

## 2. Data: `assets/sprites/vegetation_presets.yaml`

Read only by `SpriteCatalog` (override → repo, like `npc_variants.yaml`).

- `themes`: map theme id → biome id (`pradera`, `pueblo`, `mundo` →
  `meadow`; `bosque*` → `forest`; `ruinas_ext` → `ruins`;
  `cavernas_ext` → `frost`; `grieta_ext` → `ash`; `abismo_ext` → `void`).
  A theme without a biome keeps the fallback drawing.
- `biomes.<id>.palette`: 6 hex colours, in slot order: outline, leaf dark,
  leaf mid, leaf light, trunk, trunk dark.
- `biomes.<id>.species.<species>`: `weight` (share of the biome's tree
  tiles; for `bush`, unused), `seed`, `variants` (1..8), `size` [w, h]
  (8..16 each), `density` (0..1), `trunk` (0..1), `outline` (bool).

Broken or missing data = no procedural vegetation (fallback drawing).

## 3. Generator (`lib/game_engine/procedural/vegetation.dart`, pure Dart)

`VegetationGenerator.generate(VegetationParams)` returns palette-slot
indices per pixel plus the *sway cluster* (the leaf-light pixels of one
top cluster). Variant `v` of a preset uses `seed + v * 7919`.

- deciduous: trunk (1–2 px), 2–5 overlapping leaf discs (density), plus a
  top disc that is the sway cluster.
- conifer: trunk stub and 2–4 stacked triangular tiers (density), tip one
  pixel wide; the top tier's lit side sways.
- dead: trunk and 2–5 bare branches walking up and out (density); above
  0.5 density, a few light specks (embers / buds) at branch tips.
- bush: 2–4 low discs on the ground, top disc sways. No trunk.
- outline: transparent pixels 4-adjacent to the shape become `outline`.

Invariants (tested): deterministic; every opaque pixel is a biome palette
colour; fits 16 × 16; sway pixels are leaf-light pixels.

## 4. Runtime

### 4.1 Atlas and cache

`VegetationAtlas` (`lib/core/procedural/vegetation_atlas.dart`) builds
every biome × species × variant ONCE into a `ui.Image` when `GameSprites`
loads (`SpriteCatalog.vegetationAtlas`). Drawing never generates.
`TilePainter` draws the image bottom-centred in the cell; tiles still go
to the static chunk cache, so per-frame cost is unchanged.

Tree tiles pick species by weight and variant from the tile hash
(`VegetationDoc.pickTree`); forage bushes use the `bush` species (fruit
dots on top unchanged; a picked bush keeps the fallback drawing). The
`pradera` / `mundo` tree walls use the same trees.

### 4.2 Wind sway

`VegetationSwayLayer` (biome_regions.md § 7.2.2) keeps its rhythm and
tile subset; with the atlas, a tree / bush shifts its own sway cluster
pixels by the wind offset (one 1 × 1 rect per pixel, leaf-light colour)
instead of the generic canopy rect. Reduce motion: no sway (unchanged).
PNG overrides do not sway.

## 5. PNG overrides (precedence)

Each biome × species has a manifest slot under `tiles:`:
`veg_<biome>_<species>: { procedural: true, size: [16, 16] }`. If that
slot has a PNG path in the manifest, or the Editor has a local override
of `tiles.veg_<biome>_<species>.idle`, that PNG is used for every variant
of that species; otherwise the generator. Overrides are managed in the
SPRITES tab like any other sprite.

## 6. Editor: Visuales → VEGETACIÓN

Biome subtabs, a species grid, the live preview of every variant of the
preset (integer scaled, no smoothing) and the knobs: seed (+ REGENERAR),
width, height, density, trunk, variants, weight, outline, and the biome
palette. GUARDAR PRESET writes the override's `vegetation_presets.yaml`
and, with the repo path, the repo file. A species drawn from a PNG shows
a note pointing to SPRITES. Text in es-AR / en / zh-Hans
(`ui.world.veg.*`).

## 7. Preview

`VEG_PREVIEW=1 flutter test test/core/procedural/vegetation_atlas_test.dart`
writes `docs/preview/trees_sheet.png` (rows: biomes; columns: species ×
up to 3 variants, 6×).
