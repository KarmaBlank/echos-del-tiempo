import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../../game_engine/data/construction_catalog.dart';
import '../../../../game_engine/data/animals_catalog.dart' show animalHomeById;
import '../../../../game_engine/data/cozy_catalog.dart' show kFarmDecos;
import '../../../../game_engine/models/game_map.dart';
import '../../../../game_engine/models/town_build.dart';
import '../map/farm_layer.dart';
import '../map/tile_painter.dart';
import 'life_icon.dart';

/// Átomo: miniatura de una pieza de la paleta CONSTRUIR
/// (town_editor.md § 1.2). Usa el MISMO arte que el mapa: la casa es su
/// sprite del manifest (`items.vida_casa_1`, vía [LifeIcon]); lagos,
/// huertas y el faro se dibujan con los pintores del mapa
/// ([TilePainter], [MapFarmLayer.drawTilled]) escalados a [size].
class TownPiecePreview extends StatelessWidget {
  const TownPiecePreview(this.id, {super.key, this.size = 40});

  /// Id de la pieza: una de `kConstructions` o [kFaroId].
  final String id;
  final double size;

  @override
  Widget build(BuildContext context) {
    final def = construction(id);
    final decor = kFarmDecos[id];
    final home = animalHomeById(id);
    final Widget child = decor != null
        // Farm decorations (cozy_life.md § 2): their map sprite.
        ? LifeIcon(decor.sprite, LifeIconKind.herramienta, size: size)
        : def?.kind == BuildKind.casa
        ? LifeIcon('casa_1', LifeIconKind.herramienta, size: size)
        // Town kitchen (farming.md § 17): its own house sprite.
        : def?.kind == BuildKind.cocina
        ? LifeIcon('cocina', LifeIconKind.herramienta, size: size)
        : def?.kind == BuildKind.home
        ? LifeIcon('home_exterior', LifeIconKind.herramienta, size: size)
        // Coop / barn (animals.md § 3): the house sprite of the manifest.
        : home != null
        ? LifeIcon(home.sprite, LifeIconKind.herramienta, size: size)
        : CustomPaint(size: Size.square(size), painter: _PiecePainter(id, def));
    // Never paints outside its box (town_editor.md § 1.2).
    return SizedBox.square(
        key: ValueKey('town-piece-preview-$id'),
        dimension: size,
        child: ClipRect(child: child));
  }
}

class _PiecePainter extends CustomPainter {
  _PiecePainter(this.id, this.def);

  final String id;
  final ConstructionDef? def;

  static const ts = MapFarmLayer.ts;

  /// Lo que el faro dibuja por encima de su tile (brasero + resplandor).
  static const faroOverhang = 11.0;
  static final _tiles = TilePainter();

  @override
  void paint(Canvas c, Size size) {
    final d = def;
    // Faro: un tile con el brasero y su resplandor, que sobresalen 11 px
    // por arriba (TilePainter.faro). La pieza entera entra en la caja,
    // con margen y sin deformarse; escala entera si es >= 1 (pixel art).
    final w = d?.w ?? 1, h = d?.h ?? 1;
    final top = d == null ? faroOverhang : 0.0;
    final pw = w * ts, ph = h * ts + top;
    final pad = math.max(1.0, size.shortestSide * 0.06);
    var k = math.min((size.width - 2 * pad) / pw, (size.height - 2 * pad) / ph);
    if (k >= 1) k = k.floorToDouble();
    c.save();
    c.clipRect(Offset.zero & size);
    c.translate((size.width - pw * k) / 2, (size.height - ph * k) / 2);
    c.scale(k);
    c.translate(0, top);
    if (d == null) {
      _tiles.faro(c, 0, 0, 0, lit: true);
    } else {
      final lake = d.kind == BuildKind.lago;
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final px = x * ts, py = y * ts;
          // Lago: agua con las esquinas de pasto (orilla orgánica, como
          // `TownPlan`); huerta: tierra con las parcelas aradas.
          final corner = (x == 0 || x == w - 1) && (y == 0 || y == h - 1);
          final tile = lake ? (corner ? Tile.grass : Tile.water) : Tile.soil;
          _tiles.draw(c, tile, px, py, 'pueblo', x, y,
              t: 0, gateOpen: false, lobby: false);
          if (!lake) MapFarmLayer.drawTilled(c, px, py);
        }
      }
    }
    c.restore();
  }

  @override
  bool shouldRepaint(_PiecePainter old) => old.id != id;
}
