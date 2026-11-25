# Terrain tile detail

The cave tiles (biome caverns, `_caveRock` / `_caveFloor`; mines,
`mine_tiles.dart`) are the reference detail level. This spec states what
makes them detailed and how every open terrain tile matches it.
Code: `lib/features/world/presentation/map/terrain_tiles.dart`.

## 1. Scope

Applies to the outdoor themes (`pueblo`, `mundo` outside the town,
every `*_ext` biome exterior): grass `g`, ground `.`, path `,`, water `~`,
mountain `^`, tilled soil `u`. Dungeon themes and the lobby keep their
look. Tiles are procedural (no sprite assets); the only knobs are the
`MapTheme` colours in `map_themes.dart` (`grass/grass2`, `ground/ground2`,
`path/path2`, `water`, `rock/rock2`) and `FarmPalette.soil*`.

## 2. What makes the cave tiles detailed

1. A ramp of 4-5 steps per material (deep, shade, base, mid, lit), not
   one colour plus a speck.
2. Every feature is lit up-left and shadowed down-right (a lit pixel on
   top, a deep pixel under it).
3. Several hash-varied features per tile (boulders, pebbles, cracks,
   tufts) so no two neighbouring tiles repeat.
4. Neighbour-aware edges: irregular 4 px bumps of 0-3 px toward a
   different neighbour, plus contact shadow — never a straight seam.

`TerrainRamp.of(base, alt)` derives the ramp: deep = base 45 % to black,
shade = base 22 % to black, base, mid = alt colour, lit = alt 32 % to
white (pass 2: wider spread, closer to the cave contrast). Ramps are cached (water is redrawn each frame).

## 3. Per terrain

- **Clump** (shared): 2-4 px square, deep base row one px wider, mid
  body, lit top edge and a lit pixel up-left.
- **Grass**: base, a darker 6-9 px patch with a deep lower rim (1/3),
  1-2 clumps, a blade tuft (1/2), a small stone in the mountain colours
  (1/11), flower (1/17). Deep 2 px shade under a mountain above; deep
  bumps on the bottom edge toward water. Calm: at most ~4 features.
- **Ground**: base, a darker patch (1/3), 1-2 earth clumps (2-3 px), a
  pebble (1/4), a deep crack (1/5), lit speck (1/9). Theme
  `_floorDetail` still runs on top.
- **Path / road**: base, a rut in `path2` (1/3), 2-3 gravel bits (lit
  top, deep under). Toward grass, tree or mountain neighbours: grass bumps
  (0-2 px) eat in, and a shade band falls on the top edge.
- **Water**: shade body, 1-2 ripples (deep trough, base crest), and per
  land neighbour a shore band of mid bumps (0-3 px) with lit foam (0-1
  px). The moving glint stays the animated part.
- **Mountain** (§ 3.1): shape by `h % 4` — tall (slope 0.55, may
  snow), low and wide (0.95, no snow), double peak (second one lower), or
  shoulder (apex at x 4 or 12). Lit left face (`rock2`), shaded right
  face (`rock`), lit ridge pixels every 3 rows, deep right rim, strata.
  Snow only on non-covered tiles and 2 of 3 hashes. **Mass**: with rock
  above, the whole cell is a dark body fill (`rock` 25 % to black) and
  peaks rise over it; rock to the sides extends a body band to that edge;
  inside the range there is no foot line. At the range foot (no rock
  below): 1-2 boulders and a deep contact line.
- **Soil**: base, 3-4 clods (lit top, deep under), a furrow (1/4).

## 4. Rules

- Everything stays inside its 16 × 16 cell (non-negative hash offsets),
  so `TilePainter.overflow` and the chunk cache are unchanged.
- Grass, path, ground, mountain and soil stay static (chunk cache);
  only water is animated, as before.
- 8-bit minimalism: axis-aligned rects only, no gradients or
  anti-aliasing.
- Preview: `TILE_PREVIEW=<name> flutter test
  test/features/world/tile_detail_preview_test.dart` writes
  `docs/preview/<name>.png` (every outdoor theme plus the cave reference).
