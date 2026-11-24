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

/// Estado local de la edición del pueblo (no viaja: lo que cambia el
/// pueblo va al anfitrión como `TownAction`).
class TownEdit {
  TownEditStep step = TownEditStep.browse;

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

  void reset() {
    step = TownEditStep.browse;
    selected = null;
    side = null;
    placeDef = null;
    ghost = null;
  }
}
