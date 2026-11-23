import '../models/game_map.dart';

/// Qué hace un lugar del pueblo con E (town_loop.md § 2.1).
enum TownSpot {
  /// Tablero de encargos: elegir zona / misión (el mapa de viaje).
  board,

  /// Forja / armería.
  forge,

  /// Portal del Eco (ecos_atlas.md § 1).
  portal,

  /// Estatua del Tiempo (ascension.md § 1).
  statue,

  /// Torre del Loot perdido (missions.md § "Loot perdido").
  lostLoot,

  /// Fuente rúnica: punto de reunión; abre el tablero.
  fountain,

  /// Puesto del agropecuario: compra pescado, vende cañas (fishing.md § 5).
  trader,

  /// Cartel del lago: qué especies hay y tu nivel de Pesca.
  sign,

  /// Punto de pesca del lago: abre la pesca (fishing.md § 4).
  fishing,

  /// Camino del borde sur: abre el mapa de viaje (overworld_biomes.md
  /// § 1). En el pueblo y en cada exterior.
  travel,

  /// Mata recolectable de un exterior de bioma (overworld_biomes.md § 3.2).
  forage,
}

/// Un lugar del pueblo: rectángulo de tiles, el tile que lo dibuja y su
/// nombre (etiqueta sobre el mapa).
class TownLandmark {
  const TownLandmark(this.spot, this.name, this.tile, this.x, this.y,
      {this.w = 1, this.h = 1});

  final TownSpot spot;
  final String name;
  final String tile;
  final int x, y, w, h;

  /// Centro en px.
  WorldPoint get center => WorldPoint((x + w / 2) * 16, (y + h / 2) * 16);
}

/// El layout del pueblo (town_loop.md § 2.1, v0.21.0). Datos puros: el
/// mapa lo arma `MapGenerator.town()`; la UI solo dibuja los tiles que
/// salen de acá (sprites vía `sprite_manifest.yaml`).
///
/// Las posiciones de los edificios de 3 tiles respetan el tile del medio
/// que dibuja el detalle (`tx % 3`) del pintor de tiles.
abstract final class TownLayout {
  static const width = 34;
  static const height = 22;
  static const theme = 'pueblo';

  /// Aparición: en el camino, al sur de la fuente.
  static const spawn = WorldPoint(17.0 * 16, 14.5 * 16);

  static const landmarks = <TownLandmark>[
    TownLandmark(TownSpot.portal, 'PORTAL', Tile.portal, 3, 3, w: 3),
    TownLandmark(TownSpot.board, 'TABLERO DE ENCARGOS', Tile.counter, 10, 3,
        w: 6),
    TownLandmark(TownSpot.forge, 'FORJA', Tile.armory, 19, 3, w: 5),
    TownLandmark(TownSpot.statue, 'ESTATUA DEL TIEMPO', Tile.statue, 28, 3,
        w: 3),
    TownLandmark(TownSpot.fountain, 'FUENTE RÚNICA', Tile.fountain, 16, 10,
        w: 2, h: 2),
    TownLandmark(TownSpot.trader, 'AGROPECUARIO', Tile.merchant, 12, 17, w: 2),
    TownLandmark(TownSpot.lostLoot, 'LOOT PERDIDO', Tile.lostTower, 24, 15,
        w: 3),
  ];

  /// Muelles del lago base sin mover (los arma `TownPlan`).
  static const fishingSpots = [(10, 15), (10, 18), (6, 14)];

  /// Árboles sueltos dentro del claro (decorado, sólidos).
  static const trees = [
    (3, 8),
    (4, 8),
    (3, 9),
    (29, 8),
    (30, 9),
    (29, 10),
    (23, 20),
    (27, 19),
    (12, 9),
    (21, 12),
    (6, 11),
    (26, 11),
    (9, 7),
    (24, 8),
  ];

  // ---- huerta y lago base (town_editor.md § 7) ----

  /// Huerta del pueblo base sin mover (la construcción `h0`).
  static const baseFarm = (x: 19, y: 18, w: 4, h: 3);

  /// Cartel del lago base sin mover (la construcción `l0`).
  static const baseSign = (12, 15);

  static TownLandmark landmark(TownSpot s) =>
      landmarks.firstWhere((l) => l.spot == s);
}
