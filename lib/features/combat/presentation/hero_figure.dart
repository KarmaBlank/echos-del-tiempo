import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../../core/procedural/procedural_art.dart';
import '../../../core/procedural/weapon_look.dart';
import 'sprite_catalog.dart';
import 'weapon_overlay.dart';

/// Retrato del héroe con el arma en la mano (docs/specs/sprites.md
/// § "Armas en mano"): el sprite y [WeaponOverlay] escalados para que
/// la figura entera (con cualquier arma) entre en la caja; nunca
/// desborda.
class HeroFigure extends StatelessWidget {
  const HeroFigure(this.image,
      {super.key,
      required this.classId,
      required this.weaponType,
      required this.size,
      this.look});

  final ui.Image image;
  final String classId;
  final String? weaponType;
  final Size size;

  /// Identidad del arma equipada (aura, acento...). `null` = genérica.
  final WeaponLook? look;

  @override
  Widget build(BuildContext context) => SizedBox.fromSize(
        size: size,
        child: CustomPaint(
            painter: HeroFigurePainter(image, classId, weaponType, look: look)),
      );
}

class HeroFigurePainter extends CustomPainter {
  HeroFigurePainter(this.image, this.classId, this.weaponType, {this.look})
      : revision = ProceduralArt.instance.revision;
  final WeaponLook? look;
  final ui.Image image;
  final String classId;
  final String? weaponType;
  final int revision;

  @override
  void paint(Canvas canvas, Size size) {
    const b = WeaponOverlay.bounds;
    final k = math.min(size.width / b.width, size.height / b.height);
    canvas.save();
    canvas.translate(size.width / 2 - b.center.dx * k,
        size.height / 2 - b.center.dy * k);
    canvas.scale(k);
    canvas.drawImage(image, const Offset(-7, -17), SpriteCatalog.pixelPaint());
    WeaponOverlay.draw(canvas, classId, weaponType, look: look);
    canvas.restore();
  }

  @override
  bool shouldRepaint(HeroFigurePainter old) =>
      old.image != image ||
      old.classId != classId ||
      old.weaponType != weaponType ||
      old.look != look ||
      old.revision != revision;
}
