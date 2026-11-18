import 'package:material_ui/material_ui.dart';

import 'ui_theme.dart';
import 'vision_palette.dart';

/// Terreno del minimapa y del mapa en grande (exploration.md § "HUD").
enum MapTerrain {
  wall,
  tree,
  rock,
  water,
  path,
  grass,
  floor,
  voidTile,
  bridge,
  lava,
  tombstone,
  gear,
}

/// Marcas con significado del minimapa: jugador, aliados, escalera, jefe,
/// cofres, PdI, enemigos… Cada tema las mantiene distintas entre sí (y la
/// forma ayuda: ★ el jefe, cofres de oro más grandes, íconos del loot).
enum MapMark {
  me,
  ally,
  stairs,
  boss,

  /// El otro color del parpadeo del jefe.
  bossAlt,
  chest,
  secret,
  shrine,
  waystone,
  waystoneUsed,
  enemy,
  elite,
  fragment,
  seal,
  merchant,
  wind,
  shortcut,
  brazier,
  brazierLit,
  relic,

  /// PdI ya usado.
  spent,

  /// Contorno de los íconos y marco de las entradas.
  outline,
}

/// Colores del minimapa y del mapa en grande según el tema de interfaz
/// (docs/specs/accessibility.md § 8.4). AZUL = el arte de siempre;
/// OSCURO = grises neutros para piso / muros / vacío y el acento solo
/// para el jugador; ALTO CONTRASTE = negro / gris con íconos brillantes.
/// Mejora / empeora (rejas, sellos) van con `VisionColor` (modo daltónico).
abstract final class MapPalette {
  /// Cambia cuando cambia el tema o el modo daltónico (caché de la base).
  static Object get version => (UiTheme.kind, VisionPalette.mode);

  static Color terrain(MapTerrain t) =>
      Color(_terrain[UiTheme.kind]![t.index]);

  static Color mark(MapMark m) =>
      VisionPalette.remap(Color(_marks[UiTheme.kind]![m.index]));

  /// Reja abierta / sello cumplido (mejora) y reja cerrada (empeora).
  static Color get good => const VisionColor(VisionSlot.good);
  static Color get bad => const VisionColor(VisionSlot.bad);

  // Tablas ARGB en el orden de [MapTerrain] / [MapMark] (arte de los
  // temas: esta es la única fuente de estos hex).
  static const _terrain = <InterfaceTheme, List<int>>{
    InterfaceTheme.blue: [
      0xFF0B0E1A, // wall
      0xFF1D3B26, // tree
      0xFF3A3D48, // rock
      0xFF2E86DE, // water
      0xFF6C7A9C, // path
      0xFF3E6B48, // grass
      0xFF4B5878, // floor
      0xFF05060C, // void
      0xFFA07A44, // bridge
      0xFFFF5A1F, // lava
      0xFF6C707A, // tombstone
      0xFFB08A3A, // gear
    ],
    InterfaceTheme.dark: [
      0xFF0F0F0F,
      0xFF262626,
      0xFF333333,
      0xFF2B4A63,
      0xFF5A5A5A,
      0xFF404040,
      0xFF4A4A4A,
      0xFF050505,
      0xFF5C5040,
      0xFF9A4A2A,
      0xFF3D3D3D,
      0xFF6B5A3A,
    ],
    InterfaceTheme.highContrast: [
      0xFF000000,
      0xFF141414,
      0xFF1F1F1F,
      0xFF0040A0,
      0xFF595959,
      0xFF333333,
      0xFF404040,
      0xFF000000,
      0xFF6E5530,
      0xFFC03C00,
      0xFF2A2A2A,
      0xFF7A5C24,
    ],
  };

  static const _marks = <InterfaceTheme, List<int>>{
    InterfaceTheme.blue: [
      0xFFFFFFFF, // me
      0xFF48DBFB, // ally
      0xFFFFD166, // stairs
      0xFFE84393, // boss
      0xFFFFD166, // bossAlt
      0xFFFFB142, // chest (ámbar: distinto de la escalera)
      0xFFBE6EFF, // secret
      0xFF5AE6D2, // shrine
      0xFFB0B6C8, // waystone
      0xFFFFD166, // waystoneUsed
      0xFFFF4757, // enemy
      0xFFFFD166, // elite
      0xFF48DBFB, // fragment
      0xFFA29BFE, // seal
      0xFFFFD166, // merchant
      0xFFBFEFFF, // wind
      0xFFFF8C28, // shortcut
      0xFFE8D6B0, // brazier
      0xFFFF8C28, // brazierLit
      0xFFFFB347, // relic
      0xFF6C707A, // spent
      0xFF000000, // outline
    ],
    // Grises + un solo acento (el jugador); el resto, tonos distintos.
    InterfaceTheme.dark: [
      0xFFF5C451,
      0xFF7CC8F0,
      0xFFF5F5F5,
      0xFFE070A8,
      0xFFF5F5F5,
      0xFFE08A3C,
      0xFFB48CFF,
      0xFF5AD6C0,
      0xFFA3A3A3,
      0xFFF5F5F5,
      0xFFF05252,
      0xFFE08A3C,
      0xFF7CC8F0,
      0xFFB4AEDD,
      0xFFD4D4D4,
      0xFFA3D4E5,
      0xFFE08A3C,
      0xFFD4C4A0,
      0xFFE08A3C,
      0xFFE0A262,
      0xFF525252,
      0xFF000000,
    ],
    // Íconos brillantes sobre negro / gris.
    InterfaceTheme.highContrast: [
      0xFFFFFFFF,
      0xFF00E5FF,
      0xFFFFE600,
      0xFFFF40FF,
      0xFFFFFFFF,
      0xFFFFA000,
      0xFFD08CFF,
      0xFF00FFC8,
      0xFFC8C8C8,
      0xFFFFE600,
      0xFFFF3030,
      0xFFFFA000,
      0xFF00E5FF,
      0xFFD0C8FF,
      0xFFFFE600,
      0xFFC8F0FF,
      0xFFFFA000,
      0xFFFFE6B4,
      0xFFFFA000,
      0xFFFFC040,
      0xFF6E6E6E,
      0xFF000000,
    ],
  };
}
