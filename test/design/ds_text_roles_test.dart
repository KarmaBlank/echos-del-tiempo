import 'dart:math' as math;

import 'package:echos_del_tiempo/app/design/design.dart';
import 'package:echos_del_tiempo/app/theme/proto_colors.dart';
import 'package:echos_del_tiempo/app/theme/proto_markup.dart';
import 'package:echos_del_tiempo/app/theme/ui_theme.dart';
import 'package:echos_del_tiempo/core/procedural/weapon_look.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/fx_style.dart';
import 'package:echos_del_tiempo/game_engine/models/elements.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/status.dart';
import 'package:echos_del_tiempo/game_engine/rules/loot_filter_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// CIE Lab (D65) of an sRGB colour.
(double, double, double) lab(Color c) {
  double lin(double v) =>
      v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  final r = lin(c.r), g = lin(c.g), b = lin(c.b);
  final x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047;
  final y = 0.2126 * r + 0.7152 * g + 0.0722 * b;
  final z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883;
  double f(double t) =>
      t > 0.008856 ? math.pow(t, 1 / 3).toDouble() : 7.787 * t + 16 / 116;
  return (116 * f(y) - 16, 500 * (f(x) - f(y)), 200 * (f(y) - f(z)));
}

/// CIE76 ΔE between two colours.
double deltaE(Color a, Color b) {
  final (l1, a1, b1) = lab(a);
  final (l2, a2, b2) = lab(b);
  return math
      .sqrt(math.pow(l1 - l2, 2) + math.pow(a1 - a2, 2) + math.pow(b1 - b2, 2));
}

double chroma(Color c) {
  final (_, a, b) = lab(c);
  return math.sqrt(a * a + b * b);
}

/// Reserved palettes (design_system.md § 3.4): elements, rarities,
/// statuses. Text roles never reuse them.
Map<String, Color> reserved() => {
      for (final e in GameElement.values) 'element ${e.name}': elementColor(e),
      for (final r in Rarity.values)
        'rarity ${r.name}': () {
          final f = LootFilterRules.rarityColor(r);
          return Color.fromARGB(255, f.r, f.g, f.b);
        }(),
      'eco': () {
        const f = LootFilterRules.ecoColor;
        return Color.fromARGB(255, f.r, f.g, f.b);
      }(),
      for (final s in StatusKind.values) 'status ${s.name}': statusColor(s),
    };

/// Chromatic roles: must be far from every reserved colour.
const chromaticMin = 20.0;

/// Neutral (achromatic) roles: white/grey ink, the "no colour" of text.
/// They may sit near the neutral physical / common greys but never on
/// top of them, and must stay achromatic so they never read as a hue.
const neutralMin = 8.0, neutralMaxChroma = 12.0;

const neutral = {DsTextRole.title, DsTextRole.body};

void main() {
  tearDown(() => UiTheme.kind = InterfaceTheme.blue);

  for (final t in InterfaceTheme.values) {
    test('text roles never look like an element / rarity · ${t.name}', () {
      final res = reserved();
      for (final role in DsTextRole.values) {
        final c = DsTextColor.inTheme(t, role);
        final isNeutral = neutral.contains(role);
        if (isNeutral) {
          expect(chroma(c), lessThanOrEqualTo(neutralMaxChroma),
              reason: '${role.name} must stay achromatic (${t.name})');
        }
        for (final r in res.entries) {
          final d = deltaE(c, r.value);
          expect(c.toARGB32(), isNot(r.value.toARGB32()),
              reason: '${role.name} equals ${r.key}');
          expect(d, greaterThanOrEqualTo(isNeutral ? neutralMin : chromaticMin),
              reason: '${role.name} (${t.name}) too close to ${r.key}: '
                  'ΔE ${d.toStringAsFixed(1)}');
        }
      }
    });
  }

  test('the KEY role stands out from the rest of the hierarchy', () {
    for (final t in InterfaceTheme.values) {
      final k = DsTextColor.inTheme(t, DsTextRole.key);
      for (final role in DsTextRole.values.where((r) => r != DsTextRole.key)) {
        expect(deltaE(k, DsTextColor.inTheme(t, role)), greaterThan(40),
            reason: 'key vs ${role.name} (${t.name})');
      }
    }
  });

  test('KEY never reads as danger red or success green', () {
    for (final t in InterfaceTheme.values) {
      UiTheme.kind = t;
      final k = DsTextColor.inTheme(t, DsTextRole.key);
      for (final c in [DsColors.danger, DsColors.success]) {
        expect(deltaE(k, Color(c.toARGB32())), greaterThan(25),
            reason: 'key vs ${c.toARGB32().toRadixString(16)} (${t.name})');
      }
    }
  });

  test('**…** in markup is drawn in the KEY colour', () {
    ProtoSpanCache.clear();
    final span = protoSpan('Only tends **12 plots**, marked in green.');
    expect(span.toPlainText(), 'Only tends 12 plots, marked in green.');
    final keyRun = _find(span, '12 plots');
    expect(keyRun?.style?.color?.toARGB32(), DsColors.textKey.toARGB32());
    expect(ProtoColors.gold.toARGB32(), isNot(DsColors.textKey.toARGB32()));
  });
}

TextSpan? _find(TextSpan s, String text) {
  if (s.style?.color != null && s.toPlainText() == text) return s;
  for (final c in s.children ?? const <InlineSpan>[]) {
    if (c is TextSpan) {
      final f = _find(c, text);
      if (f != null) return f;
    }
  }
  return null;
}
