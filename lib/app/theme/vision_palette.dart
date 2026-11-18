import 'dart:ui' show ColorSpace;

import 'package:material_ui/material_ui.dart';

import '../../core/settings/game_settings.dart' show ColorVision;

export '../../core/settings/game_settings.dart' show ColorVision;

/// Cada color "con significado" que cambia con el modo daltónico
/// (docs/specs/accessibility.md § 3).
enum VisionSlot {
  /// Mejora, cura, requisito cumplido, mensajes del sistema (`green`).
  good,

  /// Empeora, error, requisito que falta (`red`).
  bad,

  /// Golpe crítico recibido, reloj ≤ 10 s (`crimson`).
  crimson,

  /// Relleno de las barras de HP / MP del grupo.
  hp,
  mp,

  /// Números flotantes de cura, de daño recibido y de crítico recibido.
  heal,
  hurt,
  critHurt,

  /// Vida de los enemigos (normal, élite, jefe).
  enemyHp,
  enemyHpElite,
  enemyHpBoss,

  /// Barra de quiebre (y el número / cartel de QUIEBRE).
  breakBar,

  /// Carga de la ULT enemiga (5 segmentos) y su cartel.
  enemyUlt,

  /// Rarezas (Común no cambia: es gris).
  magic,
  rare,
  epic,
  legendary,
}

/// Paletas por [ColorVision]. Los valores de cada modo están elegidos
/// para que cada par que se confunde con ese tipo de visión se separe en
/// la simulación (Machado 2009, severidad 1; test
/// `test/app/color_vision_test.dart`) y los de texto sigan en AA.
abstract final class VisionPalette {
  /// El modo activo. Lo fija `ColorVisionScope` (la app) con el ajuste;
  /// en tests, a mano.
  static ColorVision mode = ColorVision.off;

  /// El color de [slot] en el modo activo.
  static Color of(VisionSlot slot) => Color(table[mode]![slot.index]);

  /// El color de [slot] en [m].
  static Color inMode(ColorVision m, VisionSlot slot) =>
      Color(table[m]![slot.index]);

  /// ARGB por modo, en el orden de [VisionSlot].
  static const table = <ColorVision, List<int>>{
    ColorVision.off: [
      0xFF5EB77A, // good
      0xFFDB828F, // bad
      0xFFDB8289, // crimson
      0xFF2ED573, // hp
      0xFF1E90FF, // mp
      0xFF7BED9F, // heal
      0xFFFF6B81, // hurt
      0xFFFF4757, // critHurt
      0xFFFF9F43, // enemyHp
      0xFFFFD166, // enemyHpElite
      0xFFFF4757, // enemyHpBoss
      0xFFFFE14D, // breakBar
      0xFFFF3355, // enemyUlt
      0xFF7896FF, // magic
      0xFFFFD23C, // rare
      0xFFBE6EFF, // epic
      0xFFFF8C28, // legendary
    ],
    // Verde / rojo: el bien en azul y el mal en ámbar; HP azul y MP
    // amarillo; quiebre celeste; Épico lila claro (no se confunde con el
    // azul del Mágico) y Legendario naranja oscuro (lejos del amarillo).
    ColorVision.deuteranopia: [
      0xFF6FA8E0, // good
      0xFFD9A24A, // bad
      0xFFD9A24A, // crimson
      0xFF3D9BF0, // hp
      0xFFE0C341, // mp
      0xFF7CC4FF, // heal
      0xFFFFA94D, // hurt
      0xFFFFD23C, // critHurt
      0xFFF08A3C, // enemyHp
      0xFFF0A860, // enemyHpElite
      0xFFE07020, // enemyHpBoss
      0xFF8FD8FF, // breakBar
      0xFFD040FF, // enemyUlt
      0xFF5C9AFF, // magic
      0xFFFFE14A, // rare
      0xFFF0B8FF, // epic
      0xFFE8782E, // legendary
    ],
    // Rojo: como la anterior, sin rojos (se ven casi negros): todo lo
    // "malo" en ámbar claro.
    ColorVision.protanopia: [
      0xFF6FA8E0, // good
      0xFFD9A24A, // bad
      0xFFD9A24A, // crimson
      0xFF3D9BF0, // hp
      0xFFE0C341, // mp
      0xFF7CC4FF, // heal
      0xFFFFB347, // hurt
      0xFFFFE14A, // critHurt
      0xFFF0A040, // enemyHp
      0xFFF5B860, // enemyHpElite
      0xFFE89530, // enemyHpBoss
      0xFF8FD8FF, // breakBar
      0xFFD040FF, // enemyUlt
      0xFF5C9AFF, // magic
      0xFFFFE14A, // rare
      0xFFF0B8FF, // epic
      0xFFD08A3A, // legendary
    ],
    // Azul / amarillo: el bien en turquesa y el mal en rojo; HP
    // turquesa y MP magenta; quiebre celeste claro; Raro rosado (el
    // amarillo se ve rosado-blanco) y Mágico cian.
    ColorVision.tritanopia: [
      0xFF4FBFB8, // good
      0xFFDB7F8A, // bad
      0xFFDB7F8A, // crimson
      0xFF2EC4B0, // hp
      0xFFE65FA8, // mp
      0xFF5FE3D8, // heal
      0xFFFF6B81, // hurt
      0xFFFF3D3D, // critHurt
      0xFFFF6060, // enemyHp
      0xFFFF9090, // enemyHpElite
      0xFFE83A3A, // enemyHpBoss
      0xFF9FF0F0, // breakBar
      0xFFD040FF, // enemyUlt
      0xFF2FB8D8, // magic
      0xFFFFA0B4, // rare
      0xFFC77DFF, // epic
      0xFFFF6A4A, // legendary
    ],
  };

  /// Color "por defecto" (modo apagado) → su [VisionColor]: el markup y
  /// los colores que vienen de datos (rarezas del filtro) escriben el hex
  /// de siempre y se pintan con el del modo activo.
  /// Solo los de texto y rareza: los de la batalla se usan directo como
  /// [VisionColor] (y algunos comparten hex con otros tokens).
  static final Map<int, VisionColor> byDefault = {
    for (final s in const [
      VisionSlot.good,
      VisionSlot.bad,
      VisionSlot.crimson,
      VisionSlot.hp,
      VisionSlot.mp,
      VisionSlot.magic,
      VisionSlot.rare,
      VisionSlot.epic,
      VisionSlot.legendary,
    ])
      table[ColorVision.off]![s.index]: VisionColor(s),
  };

  /// [c] tal como se ve en el modo activo: si es un color con significado
  /// (en su valor por defecto), el del modo; si no, el mismo.
  ///
  /// Devuelve un `Color` común (con el modo apagado, el mismo [c]): se
  /// llama al armar o pintar, y `ColorVisionScope` reconstruye todo al
  /// cambiar de modo.
  static Color remap(Color c) {
    if (c is VisionColor || mode == ColorVision.off) return c;
    final v = byDefault[c.toARGB32()];
    return v == null ? c : of(v.slot).withValues(alpha: c.a);
  }
}

/// Un color que sigue al modo daltónico activo ([VisionPalette.mode]).
/// Es `const` (los tokens de `ProtoColors` lo siguen siendo y se pueden
/// usar en `const TextStyle(...)`); sus canales se leen del modo activo
/// cada vez que se pinta. Al cambiar de modo, `ColorVisionScope`
/// reconstruye y vuelve a medir el texto de toda la app.
class VisionColor extends Color {
  const VisionColor(this.slot) : super(0);

  final VisionSlot slot;

  Color get _c => VisionPalette.of(slot);

  @override
  double get a => _c.a;

  @override
  double get r => _c.r;

  @override
  double get g => _c.g;

  @override
  double get b => _c.b;

  @override
  ColorSpace get colorSpace => ColorSpace.sRGB;

  @override
  String toString() =>
      'VisionColor(${slot.name}: ${_c.toARGB32().toRadixString(16)})';
}

/// Aplica el modo daltónico [mode] a toda la app (va en
/// `MaterialApp.builder`, como `RetroTextScale`). Al cambiar, reconstruye
/// todo el árbol sin perder estado y vuelve a medir el texto: los
/// [VisionColor] son `const` y un `Text` con el mismo estilo no sabría
/// que su color cambió.
class ColorVisionScope extends StatefulWidget {
  const ColorVisionScope({super.key, required this.mode, required this.child});

  final ColorVision mode;
  final Widget child;

  @override
  State<ColorVisionScope> createState() => _ColorVisionScopeState();
}

class _ColorVisionScopeState extends State<ColorVisionScope> {
  @override
  void didUpdateWidget(ColorVisionScope old) {
    super.didUpdateWidget(old);
    if (old.mode != widget.mode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // El texto ya armado guarda sus colores: se vuelve a medir como
        // si cambiaran las fuentes del sistema.
        // ignore: invalid_use_of_protected_member
        PaintingBinding.instance.handleSystemMessage(
            const <String, Object?>{'type': 'fontsChange'});
        WidgetsBinding.instance.reassembleApplication();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    VisionPalette.mode = widget.mode;
    return widget.child;
  }
}
