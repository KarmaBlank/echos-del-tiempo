import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guardia del tema de interfaz (docs/specs/accessibility.md § 8.4): la UI
/// (cajas, bordes, texto, etiquetas, insignias) usa los tokens de
/// `ProtoColors` / `UiTheme` / `MapPalette` para seguir al TEMA DE
/// INTERFAZ y a los COLORES DEL TEXTO. Un `Color(0x…)` (o
/// `Color.fromARGB` / `fromRGBO`) suelto en un archivo de UI rompe eso.
///
/// Quedan permitidos, con su motivo y su cuenta máxima (un literal nuevo
/// hace fallar el test): el arte (mundo, escena, sprites, íconos), los
/// colores con significado que no son del tema (estados, filtro de loot) y
/// los archivos que definen los tokens.

final _literal = RegExp(r'Color\(0x|Color\.from(ARGB|RGBO)\(');

/// Carpetas de arte: se dibujan con sus propios colores en todos los temas.
const _artDirs = [
  'lib/features/world/presentation/map/', // tiles, actores, loot del piso
  'lib/features/combat/presentation/scene/', // arenas, FX, escena
];

/// Archivo → (literales permitidos como mucho, motivo).
const _allow = <String, (int, String)>{
  // Fuentes de los tokens.
  'lib/app/theme/proto_colors.dart': (12, 'define los tokens'),
  'lib/app/design/ds_tokens.dart':
      (1, 'Instante: celeste fijo del sistema de diseño (design_system.md)'),
  // Arte.
  'lib/features/combat/presentation/weapon_overlay.dart':
      (40, 'arte: armas dibujadas sobre los sprites'),
  'lib/features/combat/presentation/status_icons.dart':
      (2, 'arte: contorno y brillo de los íconos de estado'),
  'lib/features/combat/presentation/pixel_sprite.dart':
      (1, 'arte: sombra del sprite'),
  'lib/features/ascension/presentation/ascension_aura.dart':
      (1, 'arte: aura de la ascensión'),
  'lib/features/ascension/presentation/ascension_cinematic.dart':
      (5, 'arte: rayos, partículas y franjas de la cinemática'),
  'lib/features/inventory/presentation/item_widgets.dart':
      (9, 'arte de los íconos de objeto (metal, mango…) y los colores de '
          'pila / Eco (significado)'),
  'lib/features/passive_tree/presentation/passive_tree_view.dart':
      (4, 'lienzo del árbol: estados de los nodos (bloqueado, keystone, '
          'búsqueda, plan)'),
  // Significado.
  'lib/features/combat/presentation/battle_hud.dart':
      (15, 'significado: chips de estados y mecánicas de jefe, y el hex de los markups'),
  'lib/features/world/presentation/hud/minimap.dart':
      (10, 'colores del ícono que elige el jugador en su filtro de loot y '
          'el vacío de AZUL; el terreno y las marcas son MapPalette'),
  'lib/features/build_planner/presentation/build_fit_badge.dart':
      (1, 'significado: violeta del plan de build (kPlanColor)'),
  // Fuera del juego.
  'lib/features/admin/presentation/admin_app.dart':
      (1, 'herramienta de balance (no es la UI del juego)'),
  'lib/features/admin/presentation/editor/fx_preview.dart':
      (25, 'Editor: arena de prueba de la mini escena y colores de la línea '
          'de tiempo (fases, keys, impactos, cabezal); herramienta'),
  'lib/features/admin/presentation/editor/sprites_page.dart':
      (9, 'Editor: damero de transparencia, rayado procedural y fondo de '
          'la escena de contexto (herramienta, no la UI del juego)'),
};

/// Archivos de UI: lib/app y toda `presentation/`.
Iterable<File> _uiFiles() sync* {
  for (final root in ['lib/app', 'lib/features', 'lib/core']) {
    final dir = Directory(root);
    if (!dir.existsSync()) continue;
    for (final e in dir.listSync(recursive: true)) {
      if (e is! File || !e.path.endsWith('.dart')) continue;
      final p = e.path.replaceAll('\\', '/');
      final ui = p.startsWith('lib/app/') || p.contains('/presentation/');
      if (!ui) continue;
      if (_artDirs.any(p.startsWith)) continue;
      yield e;
    }
  }
}

int _count(File f) => f
    .readAsLinesSync()
    .where((l) => !l.trimLeft().startsWith('//'))
    .map((l) => _literal.allMatches(l).length)
    .fold(0, (a, b) => a + b);

void main() {
  test('la UI no tiene colores sueltos fuera de los permitidos', () {
    final bad = <String>[];
    for (final f in _uiFiles()) {
      final p = f.path.replaceAll('\\', '/');
      final n = _count(f);
      final max = _allow[p]?.$1 ?? 0;
      if (n > max) bad.add('$p: $n literales (máx. $max)');
    }
    expect(bad, isEmpty,
        reason: 'Usá ProtoColors / UiTheme / MapPalette (o, si es arte o '
            'significado, agregalo a _allow con el motivo).');
  });

  test('la lista de permitidos no queda vieja', () {
    for (final p in _allow.keys) {
      expect(File(p).existsSync(), isTrue, reason: p);
    }
  });
}
