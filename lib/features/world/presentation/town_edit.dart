import '../../../game_engine/models/town_build.dart';

/// Paso de la edición del pueblo (town_editor.md § 1.2).
enum TownEditStep {
  /// Mirando: la paleta a la derecha; clic en una franja o en algo
  /// puesto.
  browse,

  /// Franja fantasma elegida: comprar la ampliación de ese lado.
  side,

  /// Construcción elegida: sus opciones.
  options,

  /// Lago elegido: soltar peces de la bolsa.
  stocking,

  /// Confirmar el borrado.
  confirmDelete,

  /// El fantasma sigue al mouse; clic lo deja.
  moving,

  /// Pieza de la paleta elegida: cada clic válido pone una
  /// (town_editor.md § 1.2).
  placing,
}

/// Editor tool (town_editor.md § 1.7): always visible in the bar, each
/// with its hotkey. [build] is the base one (Esc comes back to it).
enum TownEditMode {
  build('1'),
  move('2'),
  erase('3'),
  paths('4');

  const TownEditMode(this.hotkey);

  /// Label of the key that picks it (digit row or numpad).
  final String hotkey;
}

/// Estado local de la edición del pueblo (no viaja: lo que cambia el
/// pueblo va al anfitrión como `TownAction`).
class TownEdit {
  TownEditStep step = TownEditStep.browse;

  /// Tool in use (town_editor.md § 1.7).
  TownEditMode mode = TownEditMode.build;

  /// CAMINOS: material painted (`kTownPaths` id; `null` until picked).
  String? pathMat;

  /// CAMINOS: erase sub-mode (Shift or the right button also erase).
  bool pathErase = false;

  /// Map tile under the mouse (cursor feedback of every tool).
  (int, int)? hoverTile;

  /// Construcción elegida.
  String? selected;

  /// Lado elegido (paso `side`).
  TownSide? side;

  /// Construcción del catálogo a poner.
  String? placeDef;

  /// Esquina del fantasma (mapa).
  (int, int)? ghost;

  /// Corrimiento pendiente de la cámara (px) tras ampliar al norte o al
  /// oeste; lo consume el mapa.
  (double, double)? shift;

  /// Centrar la cámara en el pueblo al entrar (elegir dónde contratar,
  /// farming.md § 8.1); lo consume el mapa.
  bool center = false;

  /// Franja fantasma bajo el mouse (panel de info, § 1.3).
  TownSide? hoverSide;

  /// Construcción bajo el mouse (panel de info, § 1.3).
  String? hoverBuild;

  /// Elegir dónde contratar (fuente rúnica, farming.md § 8): huerta
  /// (granjero) o lago (pescador). `null` = edición normal.
  BuildKind? hire;

  /// Elegir la casa de un habitante (overworld_biomes.md § 10.1): id del
  /// habitante. Misma cámara que [hire], sin paleta; resalta las CASAS.
  String? houseFor;

  /// Lo que se elige con un clic (`null` = edición normal).
  BuildKind? get pick => hire ?? (houseFor != null ? BuildKind.casa : null);

  /// Ventana CONSTRUIR abierta (town_editor.md § 1.2). Se cierra sola al
  /// elegir una pieza; el botón del borde derecho la vuelve a abrir.
  bool buildOpen = true;

  /// Pasos donde va la paleta: mirando o poniendo, sin elegir dónde
  /// contratar ni la casa de un habitante.
  bool get buildAvailable =>
      pick == null &&
      mode == TownEditMode.build &&
      (step == TownEditStep.browse || step == TownEditStep.placing);

  /// La ventana CONSTRUIR está a la vista.
  bool get buildShown => buildOpen && buildAvailable;

  void reset() {
    step = TownEditStep.browse;
    selected = null;
    side = null;
    placeDef = null;
    ghost = null;
  }
}
