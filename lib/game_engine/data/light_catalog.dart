import '../models/game_map.dart';

/// Una clase de luz (docs/specs/lighting.md § 3). El color no vive acá:
/// [tint] es una clave que la capa de dibujo resuelve en su paleta
/// (`LightPalette`), así el motor queda sin colores.
class LightDef {
  const LightDef({
    required this.radius,
    required this.intensity,
    required this.tint,
    this.flicker = 0,
    this.nightOnly = true,
  });

  /// Alcance en tiles (la luz llega a 0 en este radio).
  final double radius;

  /// Brillo en el centro (0–1; las luces se suman y se recortan a 1).
  final double intensity;

  /// Clave de color en la paleta de luces.
  final String tint;

  /// Cuánto titila (0 = fija; 0.1 = ±10 % de brillo), solo las llamas.
  final double flicker;

  /// Solo se prende cuando está oscuro (en mazmorras oscuras siempre).
  final bool nightOnly;
}

/// Claves de luz del catálogo.
abstract final class LightId {
  static const faro = 'faro';
  static const forja = 'forja';
  static const fuente = 'fuente';
  static const portal = 'portal';
  static const ventana = 'ventana';
  static const brasero = 'brasero';
  static const farol = 'farol';
  static const antorcha = 'antorcha';
  static const luciernaga = 'luciernaga';
  static const flora = 'flora';
  static const pesca = 'pesca';
  static const botin = 'botin';
  static const jugadorPueblo = 'jugador_pueblo';
  static const jugadorOscuro = 'jugador_oscuro';
  // Luz natural de los lugares oscuros (lighting.md § 3.3, v0.36.2).
  static const hongo = 'hongo';
  static const cristal = 'cristal';
  static const magitec = 'magitec';
  static const fatuo = 'fatuo';
  static const ascua = 'ascua';
  static const enjambre = 'enjambre';
  static const guia = 'guia';
  // Biome resident camps (overworld_biomes.md § 9.2).
  static const campfire = 'campfire';
}

/// Catálogo de luces con sus números (lighting.md § 3). Se ajusta acá,
/// nunca en los pintores.
const Map<String, LightDef> kLightDefs = {
  LightId.faro:
      LightDef(radius: 11, intensity: 1.4, tint: 'calida', flicker: 0.05),
  LightId.forja:
      LightDef(radius: 5, intensity: 0.9, tint: 'brasa', flicker: 0.12),
  LightId.fuente: LightDef(radius: 4, intensity: 0.6, tint: 'runa'),
  LightId.portal: LightDef(radius: 5, intensity: 0.75, tint: 'eco'),
  LightId.ventana:
      LightDef(radius: 3, intensity: 0.55, tint: 'calida', flicker: 0.03),
  LightId.brasero:
      LightDef(radius: 6, intensity: 1, tint: 'brasa', flicker: 0.12),
  LightId.farol:
      LightDef(radius: 13, intensity: 1, tint: 'calida', flicker: 0.04),
  LightId.antorcha:
      LightDef(radius: 4.5, intensity: 0.85, tint: 'brasa', flicker: 0.14),
  LightId.luciernaga: LightDef(radius: 3, intensity: 0.6, tint: 'luciernaga'),
  LightId.flora: LightDef(radius: 2.2, intensity: 0.35, tint: 'flora'),
  LightId.pesca: LightDef(radius: 2, intensity: 0.3, tint: 'agua'),
  LightId.botin: LightDef(radius: 2.5, intensity: 0.5, tint: 'botin'),
  LightId.jugadorPueblo: LightDef(radius: 4.5, intensity: 0.6, tint: 'calida'),
  LightId.jugadorOscuro:
      LightDef(radius: 5.5, intensity: 1, tint: 'calida', flicker: 0.04),
  LightId.hongo: LightDef(radius: 4, intensity: 0.6, tint: 'hongo'),
  LightId.cristal: LightDef(radius: 4.5, intensity: 0.65, tint: 'runa'),
  LightId.magitec: LightDef(radius: 5, intensity: 0.7, tint: 'eco'),
  LightId.fatuo: LightDef(radius: 4, intensity: 0.55, tint: 'runa'),
  LightId.ascua:
      LightDef(radius: 4.5, intensity: 0.7, tint: 'brasa', flicker: 0.1),
  LightId.enjambre: LightDef(radius: 4, intensity: 0.55, tint: 'luciernaga'),
  LightId.guia:
      LightDef(radius: 6, intensity: 0.9, tint: 'calida', flicker: 0.05),
  LightId.campfire:
      LightDef(radius: 5, intensity: 0.9, tint: 'brasa', flicker: 0.12),
};

/// Luz natural de un tema (lighting.md § 3.3): una luz [light] en los
/// tiles caminables elegidos por hash de la posición (uno cada [every]).
/// No cambia el mapa ni corta el paso: es solo luz (y el brillo propio).
class AmbientLight {
  const AmbientLight(this.light, this.every);
  final String light;
  final int every;
}

/// Tema → luz natural. Todo lugar que puede quedar a oscuras (exteriores
/// y mazmorras de noche, pisos oscuros) tiene la suya; el pueblo no (tiene
/// faros).
const Map<String, AmbientLight> kAmbientLights = {
  'pradera': AmbientLight(LightId.enjambre, 26),
  'mundo': AmbientLight(LightId.enjambre, 30),
  'bosque': AmbientLight(LightId.hongo, 16),
  'bosque_ext': AmbientLight(LightId.hongo, 14),
  'ruinas': AmbientLight(LightId.magitec, 24),
  'ruinas_ext': AmbientLight(LightId.magitec, 24),
  'cavernas': AmbientLight(LightId.cristal, 22),
  'cavernas_ext': AmbientLight(LightId.cristal, 22),
  'fortaleza': AmbientLight(LightId.ascua, 24),
  'laberinto': AmbientLight(LightId.magitec, 24),
  'grieta': AmbientLight(LightId.ascua, 22),
  'grieta_ext': AmbientLight(LightId.ascua, 22),
  'cementerio': AmbientLight(LightId.fatuo, 10),
  'abismo': AmbientLight(LightId.cristal, 18),
  'abismo_ext': AmbientLight(LightId.cristal, 22),
  'corazon': AmbientLight(LightId.magitec, 20),
};

/// Tile que emite luz → clave del catálogo.
const Map<String, String> kTileLights = {
  Tile.brazierLit: LightId.brasero,
  Tile.lanternLit: LightId.farol,
  Tile.fountain: LightId.fuente,
  Tile.portal: LightId.portal,
  Tile.house: LightId.ventana,
  Tile.armory: LightId.forja,
  Tile.fishing: LightId.pesca,
  Tile.forage: LightId.flora,
};

/// Tiles que cortan la luz del todo (la luz los ilumina pero no pasa;
/// lighting.md § 2.1): muros y rocas de mazmorra, y desde v0.36.2 los
/// edificios y estructuras sólidas del pueblo y los biomas (casas, forja,
/// armería, taller, tablero, puesto, fuente, estatua, portal, torre del
/// loot). Árboles y lápidas siguen atenuando ([kAttenuatingTiles]).
const Set<String> kOpaqueTiles = {
  Tile.wall,
  Tile.rock,
  Tile.cracked,
  Tile.secretFloor,
  Tile.shortcut,
  Tile.gear,
  Tile.gate,
  Tile.house,
  Tile.armory,
  Tile.shop,
  Tile.workshop,
  Tile.counter,
  Tile.merchant,
  Tile.fountain,
  Tile.statue,
  Tile.portal,
  Tile.lostTower,
};

/// Tiles que atenúan (la luz pasa, pero cuesta [kAttenuationCost] tiles
/// extra de recorrido): árboles y lápidas.
const Set<String> kAttenuatingTiles = {Tile.tree, Tile.tombstone};
const double kAttenuationCost = 2.5;

/// Temas siempre oscuros (lighting.md § 5).
const Set<String> kDarkThemes = {'cavernas'};

/// Temas con pisos oscuros alternados (los pisos impares, 0-based).
const Set<String> kDarkFloorThemes = {'abismo'};

/// Antorchas de pared en mazmorras oscuras: una cada tanto (hash % n).
const int kTorchEvery = 29;
