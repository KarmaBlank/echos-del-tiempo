/// Local state of EDITAR CASA (player_house.md § 8.3). Nothing here
/// travels: every change goes to the host as a `HomeEditAction`.
enum HomeEditStep {
  /// Looking: the palette is open; a click on a piece selects it.
  browse,

  /// A palette piece is picked: the ghost follows the mouse; each valid
  /// click places one.
  placing,

  /// A placed piece is being moved: a click drops it.
  moving,
}

class HomeEdit {
  HomeEditStep step = HomeEditStep.browse;

  /// Palette filter (`all`, `bed`, `wall`, `use`, `decor`, `surface`).
  String filter = 'all';

  /// Palette entry picked in the window (furniture or surface id, or
  /// `paint:<n>`): its detail stays fixed.
  String? picked;

  /// Furniture id being placed ([HomeEditStep.placing]).
  String? placeDef;

  /// Uid of the placed piece selected (menu MOVER · BORRAR) or moving.
  int? selected;

  /// Tile under the mouse (ghost corner).
  (int, int)? hover;

  /// The palette window is open.
  bool paletteOpen = true;

  void reset() {
    step = HomeEditStep.browse;
    placeDef = null;
    selected = null;
  }
}
