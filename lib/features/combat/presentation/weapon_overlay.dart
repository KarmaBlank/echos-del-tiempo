import 'dart:math' as math;
import 'dart:ui';

import '../../../core/procedural/item_icons.dart';
import '../../../core/procedural/procedural_art.dart';

/// El arma dibujada en la mano del héroe (docs/specs/sprites.md
/// § "Héroe" › "Armas en mano"), la misma en el mapa (`ActorPainter`),
/// la batalla (`BattlePainter`), las ULT y los retratos (`HeroFigure`).
/// Coordenadas relativas a los pies del héroe, mirando a la derecha
/// (quien llama espeja).
///
/// Se elige por **tipo de arma** (loot v2: cualquier clase equipa
/// cualquier arma); sin tipo conocido, el arma de siempre de la clase.
/// El dibujo es el **ícono procedural** del tipo (`kItemIconRows`) con
/// las perillas de su entrada del Editor (`items.<tipo>`, game_editor.md
/// § 7.5): si el dueño recolorea el arma en el Editor, cambia también
/// en la mano.
abstract final class WeaponOverlay {
  static final _fill = Paint()..isAntiAlias = false;

  /// Arma por defecto de cada clase (sin arma equipada conocida).
  static const _classType = {
    'guerrero': 'espada',
    'maga': 'báculo',
    'paladin': 'espada+escudo',
    'tirador': 'rifle',
  };

  /// Qué arte lleva cada tipo de arma.
  static const Map<String, WeaponArt> kWeaponArt = {
    'espada': WeaponArt.sword,
    'hacha': WeaponArt.axe,
    'báculo': WeaponArt.staff,
    'tomo': WeaponArt.tome,
    'arco': WeaponArt.bow,
    'rifle': WeaponArt.gun,
    'espada+escudo': WeaponArt.sword,
    'maza+escudo': WeaponArt.mace,
    'martillo+escudo': WeaponArt.hammer,
    'lanza': WeaponArt.spear,
    'dagas': WeaponArt.daggers,
    'varita': WeaponArt.wand,
    'ballesta': WeaponArt.crossbow,
  };

  /// Cómo se agarra cada arte: forma del catálogo, tamaño de la celda
  /// (px del héroe), celda del agarre dentro del ícono 8×8, dónde está la
  /// mano, si se espeja el ícono y cuartos de giro horario.
  static const Map<WeaponArt, WeaponGrip> kGrips = {
    WeaponArt.sword: WeaponGrip('espada', 1.25, 3, 5, 5, -7),
    WeaponArt.axe: WeaponGrip('hacha', 1.25, 4, 5, 5, -7, mirror: true),
    WeaponArt.staff: WeaponGrip('báculo', 1.5, 3, 4, 5, -7),
    WeaponArt.tome: WeaponGrip('tomo', 1, 3.5, 6, 6, -5),
    WeaponArt.bow: WeaponGrip('arco', 1.25, 0, 4, 10, -8, mirror: true),
    WeaponArt.gun: WeaponGrip('rifle', 1.25, 3, 4, 4, -6),
    WeaponArt.mace: WeaponGrip('maza', 1.25, 3, 6, 5, -6),
    WeaponArt.hammer: WeaponGrip('martillo', 1.25, 3, 6, 5, -6),
    WeaponArt.spear: WeaponGrip('lanza', 1.5, 3, 4, 5, -7),
    WeaponArt.daggers: WeaponGrip('dagas', 1, 3.5, 4, 7, -6),
    WeaponArt.wand: WeaponGrip('varita', 1, 3, 5, 5, -7),
    WeaponArt.crossbow:
        WeaponGrip('ballesta', 1.25, 3, 5, 5, -7, quarterTurns: 1),
  };

  /// Caja que ocupa el héroe con cualquier arma (para los retratos).
  static const bounds = Rect.fromLTWH(-11, -18, 24, 20);

  /// Color de la mano que agarra.
  static const handColor = Color(0xFFE8B890);

  /// El tipo efectivo: el equipado o el de la clase.
  static String? typeFor(String classId, String? weaponType) =>
      kWeaponArt.containsKey(weaponType) ? weaponType : _classType[classId];

  /// El arte para [weaponType] (o la clase si no se conoce).
  static WeaponArt artFor(String classId, String? weaponType) =>
      kWeaponArt[typeFor(classId, weaponType)] ?? WeaponArt.gun;

  /// Las armas con escudo llevan además el escudo en el otro brazo.
  static bool hasShield(String classId, String? weaponType) =>
      typeFor(classId, weaponType)?.endsWith('+escudo') ?? false;

  /// Entrada del Editor cuyas perillas usa el arma en mano.
  static String entryFor(String classId, String? weaponType) {
    final t = typeFor(classId, weaponType);
    return 'items.${(t == null ? null : procKeyForType(t)) ?? kGrips[artFor(classId, weaponType)]!.shape}';
  }

  static void draw(Canvas c, String classId, String? weaponType,
      {Color accent = kItemDefaultAccent}) {
    final grip = kGrips[artFor(classId, weaponType)]!;
    final params = ProceduralArt.instance.resolve(entryFor(classId, weaponType));
    if (hasShield(classId, weaponType)) {
      // Escudo en el brazo de atrás, con el puño en el centro.
      paintItemIcon(c, const Rect.fromLTWH(-11, -13, 8, 8),
          kItemIconRows['escudo']!, accent, params);
    }
    c.save();
    c.translate(grip.handX, grip.handY);
    if (grip.quarterTurns != 0) c.rotate(grip.quarterTurns * math.pi / 2);
    if (grip.mirror) c.scale(-1, 1);
    c.scale(grip.cell);
    paintItemIcon(
        c,
        Rect.fromLTWH(-grip.gripX - 0.5, -grip.gripY - 0.5, 8, 8),
        kItemIconRows[grip.shape]!,
        accent,
        params);
    c.restore();
    // La mano encima del mango: se ve agarrada.
    _fill.color = handColor;
    c.drawRect(
        Rect.fromLTWH(grip.handX - 1, grip.handY - 1, 2, 2), _fill);
  }
}

/// Agarre de un arte (ver [WeaponOverlay.kGrips]).
class WeaponGrip {
  const WeaponGrip(this.shape, this.cell, this.gripX, this.gripY, this.handX,
      this.handY,
      {this.mirror = false, this.quarterTurns = 0});
  final String shape;
  final double cell, gripX, gripY, handX, handY;
  final bool mirror;
  final int quarterTurns;
}

/// Dibujo del arma (uno por familia de tipos).
enum WeaponArt {
  sword,
  axe,
  staff,
  tome,
  bow,
  hammer,
  mace,
  gun,
  spear,
  daggers,
  wand,
  crossbow
}
