import 'dart:math' as math;

import 'package:echos_del_tiempo/app/theme/proto_colors.dart';
import 'package:echos_del_tiempo/app/theme/vision_palette.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/item_widgets.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/loot_painter.dart'
    as map;
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Simulación de daltonismo (Machado, Oliveira y Fernandes 2009,
/// severidad 1) sobre RGB lineal.
const _machado = <ColorVision, List<double>>{
  ColorVision.protanopia: [
    0.152286, 1.052583, -0.204868, //
    0.114503, 0.786281, 0.099216, //
    -0.003882, -0.048116, 1.051998,
  ],
  ColorVision.deuteranopia: [
    0.367322, 0.860646, -0.227968, //
    0.280085, 0.672501, 0.047413, //
    -0.011820, 0.042940, 0.968881,
  ],
  ColorVision.tritanopia: [
    1.255528, -0.076749, -0.178779, //
    -0.078411, 0.930809, 0.147602, //
    0.004733, 0.691367, 0.303900,
  ],
};

double _lin(double v) =>
    v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();

List<double> _lab(Color c, ColorVision m) {
  final rgb = [_lin(c.r), _lin(c.g), _lin(c.b)];
  final k = _machado[m];
  final s = k == null
      ? rgb
      : [
          for (var i = 0; i < 3; i++)
            (k[i * 3] * rgb[0] + k[i * 3 + 1] * rgb[1] + k[i * 3 + 2] * rgb[2])
                .clamp(0.0, 1.0),
        ];
  final x = (0.4124 * s[0] + 0.3576 * s[1] + 0.1805 * s[2]) / 0.95047;
  final y = 0.2126 * s[0] + 0.7152 * s[1] + 0.0722 * s[2];
  final z = (0.0193 * s[0] + 0.1192 * s[1] + 0.9505 * s[2]) / 1.08883;
  double f(double t) =>
      t > 0.008856 ? math.pow(t, 1 / 3).toDouble() : 7.787 * t + 16 / 116;
  return [116 * f(y) - 16, 500 * (f(x) - f(y)), 200 * (f(y) - f(z))];
}

/// ΔE (CIE76) entre [a] y [b] vistos con [m].
double deltaE(Color a, Color b, ColorVision m) {
  final la = _lab(a, m), lb = _lab(b, m);
  return math.sqrt(math.pow(la[0] - lb[0], 2) +
      math.pow(la[1] - lb[1], 2) +
      math.pow(la[2] - lb[2], 2));
}

/// Pares que tienen que distinguirse (accessibility.md § 3).
const _pairs = [
  (VisionSlot.good, VisionSlot.bad),
  (VisionSlot.hp, VisionSlot.mp),
  (VisionSlot.heal, VisionSlot.hurt),
  (VisionSlot.heal, VisionSlot.critHurt),
  (VisionSlot.enemyHp, VisionSlot.breakBar),
  (VisionSlot.enemyHpElite, VisionSlot.breakBar),
  (VisionSlot.enemyHpBoss, VisionSlot.breakBar),
  (VisionSlot.breakBar, VisionSlot.enemyUlt),
  (VisionSlot.enemyHp, VisionSlot.enemyUlt),
  (VisionSlot.magic, VisionSlot.rare),
  (VisionSlot.magic, VisionSlot.epic),
  (VisionSlot.magic, VisionSlot.legendary),
  (VisionSlot.rare, VisionSlot.epic),
  (VisionSlot.rare, VisionSlot.legendary),
  (VisionSlot.epic, VisionSlot.legendary),
];

/// ΔE mínimo para decir "se distingue".
const _minDelta = 20.0;

void main() {
  tearDown(() => VisionPalette.mode = ColorVision.off);

  test('cada modo tiene un color por slot', () {
    for (final m in ColorVision.values) {
      expect(VisionPalette.table[m], hasLength(VisionSlot.values.length),
          reason: m.name);
    }
  });

  for (final m in [
    ColorVision.deuteranopia,
    ColorVision.protanopia,
    ColorVision.tritanopia,
  ]) {
    test('${m.name}: los pares con significado se distinguen simulados', () {
      for (final (a, b) in _pairs) {
        expect(
            deltaE(VisionPalette.inMode(m, a), VisionPalette.inMode(m, b), m),
            greaterThanOrEqualTo(_minDelta),
            reason: '${a.name} / ${b.name}');
      }
    });

    test('${m.name}: la paleta normal NO alcanzaba (por eso existe el modo)',
        () {
      final weak = [
        for (final (a, b) in _pairs)
          if (deltaE(VisionPalette.inMode(ColorVision.off, a),
                  VisionPalette.inMode(ColorVision.off, b), m) <
              _minDelta)
            '${a.name}/${b.name}',
      ];
      expect(weak, isNotEmpty);
    });
  }

  // (La paleta del prototipo tiene élite / quiebre parecidos —dorado y
  // amarillo—; los separa el patrón rayado de la barra de quiebre.)
  test('las paletas daltónicas también se distinguen con visión normal', () {
    for (final m in ColorVision.values.skip(1)) {
      for (final (a, b) in _pairs) {
        expect(
            deltaE(VisionPalette.inMode(m, a), VisionPalette.inMode(m, b),
                ColorVision.off),
            greaterThanOrEqualTo(_minDelta),
            reason: '${m.name}: ${a.name} / ${b.name}');
      }
    }
  });

  test('VisionColor: const, sigue al modo activo', () {
    const c = ProtoColors.green;
    expect(c.toARGB32(), 0xFF5EB77A);
    VisionPalette.mode = ColorVision.deuteranopia;
    expect(c.toARGB32(),
        VisionPalette.inMode(ColorVision.deuteranopia, VisionSlot.good)
            .toARGB32());
    expect(Paint()..color = c, isNotNull);
    expect(c.withValues(alpha: 0.5).toARGB32() & 0xFFFFFF,
        c.toARGB32() & 0xFFFFFF);
    // v0.8.1: el markup lleva el hex canónico (modo apagado) y al
    // pintarse vuelve a ser el token del modo activo.
    expect(ProtoColors.hex(c), '#5eb77a');
    expect(ProtoColors.parse(ProtoColors.hex(c))!.toARGB32(),
        VisionPalette.inMode(ColorVision.deuteranopia, VisionSlot.good)
            .toARGB32());
  });

  test('markup y colores del filtro: el hex por defecto toma el del modo',
      () {
    VisionPalette.mode = ColorVision.tritanopia;
    // Token suavizado (`green`) y hex del prototipo (`#7bed9f` → green).
    expect(ProtoColors.parse('#5eb77a')!.toARGB32(), 0xFF4FBFB8);
    expect(ProtoColors.parse('#7bed9f')!.toARGB32(), 0xFF4FBFB8);
    // Rarezas: fichas (borde), mapa y markup.
    expect(RarityColors.of(Rarity.raro).toARGB32(), 0xFFFFA0B4);
    expect(map.rarityColor(Rarity.magico).toARGB32(), 0xFF2FB8D8);
    expect(ProtoColors.parse('#ffd23c')!.toARGB32(), 0xFFFFA0B4);
    // Lo que no tiene significado no cambia.
    expect(ProtoColors.parse('#ffd166'), ProtoColors.gold);
    expect(RarityColors.of(Rarity.comun).toARGB32(), 0xFFDCDCDC);
    VisionPalette.mode = ColorVision.off;
    expect(RarityColors.of(Rarity.raro).toARGB32(), 0xFFFFD23C);
  });
}
