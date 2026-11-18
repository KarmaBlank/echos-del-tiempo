import 'package:echos_del_tiempo/app/theme/map_palette.dart';
import 'package:echos_del_tiempo/app/theme/ui_theme.dart';
import 'package:echos_del_tiempo/features/world/presentation/hud/full_map.dart';
import 'package:echos_del_tiempo/features/world/presentation/hud/minimap.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Minimapa y mapa en grande por tema (docs/specs/accessibility.md § 8.4).

double _ratio(Color a, Color b) {
  final l1 = a.computeLuminance(), l2 = b.computeLuminance();
  return (l1 > l2 ? l1 + 0.05 : l2 + 0.05) / (l1 > l2 ? l2 + 0.05 : l1 + 0.05);
}

bool _grey(Color c) => c.r == c.g && c.g == c.b;

void main() {
  tearDown(UiTheme.reset);

  test('AZUL = el arte de siempre', () {
    UiTheme.kind = InterfaceTheme.blue;
    expect(minimapTileColor(Tile.voidTile), kMinimapVoid);
    expect(minimapTileColor(Tile.floor), const Color(0xFF4B5878));
    expect(MapPalette.mark(MapMark.me), const Color(0xFFFFFFFF));
    expect(MapPalette.mark(MapMark.enemy), const Color(0xFFFF4757));
  });

  test('OSCURO: piso, muros y vacío en grises; el acento solo en el jugador',
      () {
    UiTheme.kind = InterfaceTheme.dark;
    for (final t in [
      MapTerrain.wall,
      MapTerrain.floor,
      MapTerrain.voidTile,
      MapTerrain.path,
      MapTerrain.grass,
      MapTerrain.tree,
      MapTerrain.rock,
    ]) {
      expect(_grey(MapPalette.terrain(t)), isTrue, reason: t.name);
    }
    expect(MapPalette.mark(MapMark.me), UiTheme.of(UiSlot.gold));
    for (final m in MapMark.values.where((m) => m != MapMark.me)) {
      expect(MapPalette.mark(m), isNot(UiTheme.of(UiSlot.gold)), reason: m.name);
    }
  });

  for (final theme in InterfaceTheme.values) {
    test('${theme.name}: la leyenda se distingue y se ve sobre el piso', () {
      UiTheme.kind = theme;
      final legend = FullMap.legend;
      final colors = [for (final (_, c) in legend) c];
      expect(colors.toSet(), hasLength(colors.length),
          reason: 'cada marca de la leyenda con su color');
      final floor = MapPalette.terrain(MapTerrain.floor);
      final path = MapPalette.terrain(MapTerrain.path);
      for (final (l, c) in legend) {
        expect(_ratio(c, floor), greaterThanOrEqualTo(1.8),
            reason: '$l / piso');
        // AZUL conserva el arte del prototipo (camino claro).
        if (theme != InterfaceTheme.blue) {
          expect(_ratio(c, path), greaterThanOrEqualTo(1.3),
              reason: '$l / camino');
        }
      }
      // El piso se distingue del muro.
      expect(_ratio(floor, MapPalette.terrain(MapTerrain.wall)),
          greaterThanOrEqualTo(1.5));
      expect(minimapTileColor(Tile.floor), floor);
    });
  }

  test('la base del minimapa se vuelve a grabar al cambiar de tema', () {
    UiTheme.kind = InterfaceTheme.blue;
    final v1 = MapPalette.version;
    UiTheme.kind = InterfaceTheme.highContrast;
    expect(MapPalette.version, isNot(v1));
  });
}
