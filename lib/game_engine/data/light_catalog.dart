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
}

/// Catálogo de luces con sus números (lighting.md § 3). Se ajusta acá,
/// nunca en los pintores.
const Map<String, LightDef> kLightDefs = {
  LightId.faro: LightDef(radius: 6, intensity: 0.95, tint: 'calida', flicker: 0.05),
  LightId.forja: LightDef(radius: 5, intensity: 0.9, tint: 'brasa', flicker: 0.12),
  LightId.fuente: LightDef(radius: 4, intensity: 0.6, tint: 'runa'),
  LightId.portal: LightDef(radius: 5, intensity: 0.75, tint: 'eco'),
  LightId.ventana: LightDef(radius: 3, intensity: 0.55, tint: 'calida', flicker: 0.03),
  LightId.brasero: LightDef(radius: 6, intensity: 1, tint: 'brasa', flicker: 0.12),
  LightId.farol: LightDef(radius: 11, intensity: 1, tint: 'calida', flicker: 0.04),
  LightId.antorcha: LightDef(radius: 4.5, intensity: 0.85, tint: 'brasa', flicker: 0.14),
  LightId.luciernaga: LightDef(radius: 1.6, intensity: 0.35, tint: 'luciernaga'),
  LightId.flora: LightDef(radius: 2.2, intensity: 0.35, tint: 'flora'),
  LightId.pesca: LightDef(radius: 2, intensity: 0.3, tint: 'agua'),
  LightId.botin: LightDef(radius: 2.5, intensity: 0.5, tint: 'botin'),
  LightId.jugadorPueblo: LightDef(radius: 3.5, intensity: 0.5, tint: 'calida'),
  LightId.jugadorOscuro: LightDef(radius: 9, intensity: 1, tint: 'calida', flicker: 0.04),
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

/// Tiles que cortan la luz del todo (la luz los ilumina pero no pasa).
const Set<String> kOpaqueTiles = {
  Tile.wall, Tile.rock, Tile.cracked, Tile.secretFloor, Tile.shortcut,
  Tile.gear, Tile.gate,
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
