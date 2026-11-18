import 'dart:ui';

/// El arma dibujada encima del sprite del héroe (docs/specs/sprites.md
/// § "Héroe"), la misma en el mapa (`ActorPainter`) y en la batalla
/// (`BattlePainter`). Coordenadas relativas a los pies del héroe, mirando
/// a la derecha (quien llama espeja).
///
/// Se elige por **tipo de arma** (loot v2: cualquier clase equipa
/// cualquier arma); los tipos del prototipo conservan el arte de la
/// clase que los usaba y los 4 tipos nuevos tienen el suyo. Sin tipo
/// conocido, el de la clase.
abstract final class WeaponOverlay {
  static final _fill = Paint()..isAntiAlias = false;

  static void _rect(
      Canvas c, Color color, double x, double y, double w, double h) {
    _fill.color = color;
    c.drawRect(Rect.fromLTWH(x, y, w, h), _fill);
  }

  static void _dot(Canvas c, Color color, double x, double y, double r) {
    _fill.color = color;
    c.drawCircle(Offset(x, y), r, _fill);
  }

  /// Arte del prototipo por clase (`drawHero`).
  static const _classArt = {
    'guerrero': WeaponArt.sword,
    'maga': WeaponArt.staff,
    'paladin': WeaponArt.sword,
    'tirador': WeaponArt.gun,
  };

  /// Qué arte lleva cada tipo de arma.
  static const Map<String, WeaponArt> kWeaponArt = {
    'espada': WeaponArt.sword,
    'hacha': WeaponArt.sword,
    'báculo': WeaponArt.staff,
    'tomo': WeaponArt.staff,
    'arco': WeaponArt.gun,
    'rifle': WeaponArt.gun,
    'espada+escudo': WeaponArt.sword,
    'maza+escudo': WeaponArt.mace,
    'martillo+escudo': WeaponArt.hammer,
    // Loot v2.
    'lanza': WeaponArt.spear,
    'dagas': WeaponArt.daggers,
    'varita': WeaponArt.wand,
    'ballesta': WeaponArt.crossbow,
  };

  /// El arte para [weaponType] (o la clase si no se conoce).
  static WeaponArt artFor(String classId, String? weaponType) =>
      kWeaponArt[weaponType] ?? _classArt[classId] ?? WeaponArt.gun;

  /// Las armas con escudo llevan además el escudo en la espalda.
  static bool hasShield(String classId, String? weaponType) =>
      weaponType == null
          ? classId == 'paladin'
          : weaponType.endsWith('+escudo');

  static void draw(Canvas c, String classId, String? weaponType) {
    switch (artFor(classId, weaponType)) {
      case WeaponArt.sword:
        _rect(c, const Color(0xFFDFE6E9), 5, -17, 2, 9);
        _rect(c, const Color(0xFFFFD166), 3, -9, 6, 1);
      case WeaponArt.staff:
        _rect(c, const Color(0xFF8A5A2B), 6, -15, 1, 15);
        _dot(c, const Color(0xFF74B9FF), 6.5, -16, 2.2);
      case WeaponArt.hammer:
        _rect(c, const Color(0xFF8A5A2B), 6, -14, 1, 11);
        _rect(c, const Color(0xFF95A5A6), 3, -18, 7, 5);
        _rect(c, const Color(0xFF636E72), 3, -14, 7, 1);
      case WeaponArt.mace:
        _rect(c, const Color(0xFF8A5A2B), 6, -13, 1, 9);
        _dot(c, const Color(0xFFB2BEC3), 6.5, -15, 2.6);
        for (final (px, py) in const [
          (4.0, -16.0),
          (8.0, -16.0),
          (6.0, -18.0)
        ]) {
          _rect(c, const Color(0xFFDFE6E9), px, py, 1, 1);
        }
      case WeaponArt.gun:
        _rect(c, const Color(0xFF636E72), 5, -8, 6, 2);
        _rect(c, const Color(0xFF636E72), 5, -7, 2, 3);
      case WeaponArt.spear:
        // Asta larga que pasa la cabeza, punta de acero y borla roja.
        _rect(c, const Color(0xFF8A5A2B), 6, -20, 1, 21);
        _rect(c, const Color(0xFFDFE6E9), 6, -25, 1, 5);
        _rect(c, const Color(0xFFDFE6E9), 5, -23, 3, 2);
        _rect(c, const Color(0xFFFFFFFF), 6, -24, 1, 1);
        _rect(c, const Color(0xFFD63031), 5, -19, 3, 1);
        _rect(c, const Color(0xFFD63031), 5, -18, 1, 2);
      case WeaponArt.daggers:
        // Una daga en cada mano: la de atrás asoma del otro lado.
        _rect(c, const Color(0xFFB2BEC3), -8, -12, 1, 4);
        _rect(c, const Color(0xFF6C5CE7), -9, -8, 3, 1);
        _rect(c, const Color(0xFFDFE6E9), 6, -12, 1, 5);
        _rect(c, const Color(0xFFFFFFFF), 6, -12, 1, 1);
        _rect(c, const Color(0xFF6C5CE7), 5, -7, 3, 1);
        _rect(c, const Color(0xFF2D3436), 6, -6, 1, 2);
      case WeaponArt.wand:
        // Varita corta con gema arcana y destello.
        _rect(c, const Color(0xFF5A3A1A), 6, -11, 1, 7);
        _rect(c, const Color(0xFFFFD166), 5, -12, 3, 1);
        _rect(c, const Color(0xFFA29BFE), 5, -15, 3, 3);
        _rect(c, const Color(0xFFE84393), 6, -14, 1, 1);
        _rect(c, const Color(0xFFFFFFFF), 8, -16, 1, 1);
      case WeaponArt.crossbow:
        // Ballesta pesada: culata, arco de acero al frente y virote.
        _rect(c, const Color(0xFF6B4423), 3, -9, 8, 2);
        _rect(c, const Color(0xFF6B4423), 3, -7, 2, 2);
        _rect(c, const Color(0xFF95A5A6), 11, -13, 1, 10);
        _rect(c, const Color(0xFF636E72), 10, -13, 1, 1);
        _rect(c, const Color(0xFF636E72), 10, -4, 1, 1);
        _rect(c, const Color(0xFFDFE6E9), 8, -10, 6, 1);
        _rect(c, const Color(0xFFFF7B29), 14, -10, 1, 1);
    }
    if (hasShield(classId, weaponType)) {
      _rect(c, const Color(0xFF2C3E50), -10, -13, 6, 9);
      _rect(c, const Color(0xFFECF0F1), -9, -12, 4, 7);
      _rect(c, const Color(0xFFD4AF37), -8, -11, 2, 5);
      _rect(c, const Color(0xFFD4AF37), -9, -9, 4, 1);
    }
  }
}

/// Dibujo del arma (uno por familia de tipos).
enum WeaponArt {
  sword,
  staff,
  hammer,
  mace,
  gun,
  spear,
  daggers,
  wand,
  crossbow
}
