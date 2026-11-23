import 'dart:math' as math;
import 'dart:ui' show Color, Size;

import '../../../app/design/ds_tokens.dart';
import '../../../app/design/registry/ds_registry.dart';
import '../../../core/screen_layout/screen_bindings.dart';
import '../../../core/screen_layout/screen_layout.dart';

/// Tipo de aviso de VERIFICAR (docs/specs/screen_editor.md § 6).
enum ScreenIssueKind {
  contrast,
  textSize,
  hierarchy,
  roleStyle,
  tapTarget,
  clipped,
  focusOrder,
  disabled,
  binding,
  bounds,
}

/// Un aviso con su arreglo (si lo hay).
class ScreenIssue {
  const ScreenIssue(this.elementId, this.kind, this.message,
      {this.fixLabel, this.fix});

  final String elementId;
  final ScreenIssueKind kind;
  final String message;

  /// Texto del arreglo sugerido (también cuando no es automático).
  final String? fixLabel;
  final ScreenLayout Function(ScreenLayout)? fix;

  @override
  String toString() => '$elementId: ${kind.name} — $message';
}

/// Mide un texto con un estilo del DS en un ancho máximo.
typedef TextMeasure = Size Function(
    String text, DsTextStyleId style, double maxWidth);

/// Tamaños de ventana de la vista previa (§ 5).
const screenPreviewSizes = <Size>[
  Size(1280, 720),
  Size(1366, 768),
  Size(1600, 900),
  Size(1920, 1080),
  Size(2560, 1440),
  Size(1280, 800),
  Size(1024, 768),
];

/// Rol semántico → estilos admitidos (el primero es el sugerido).
const roleStyles = <String, List<DsTextStyleId>>{
  'titulo': [DsTextStyleId.display, DsTextStyleId.title],
  'subtitulo': [DsTextStyleId.subtitle],
  'texto': [DsTextStyleId.body],
  'detalle': [DsTextStyleId.detail],
};

const roleLabels = <String, String>{
  'titulo': 'Título',
  'subtitulo': 'Subtítulo',
  'texto': 'Texto',
  'detalle': 'Detalle',
};

/// Relación de contraste WCAG entre dos colores.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// Chequeos semánticos y de accesibilidad por elemento.
class ScreenChecker {
  ScreenChecker({
    DsRegistry? registry,
    this.bindings,
    required this.measure,
    this.previewSizes = screenPreviewSizes,
    Color? background,
  })  : registry = registry ?? DsRegistry.instance,
        background = background ?? DsColors.background;

  final DsRegistry registry;
  final ScreenBindingSpec? bindings;
  final TextMeasure measure;
  final List<Size> previewSizes;
  final Color background;

  static const minTap = 32.0;
  static const minTextPx = 7.0;
  static const grid = 8.0;

  double _minScale(ScreenLayout l) =>
      previewSizes.map(l.scaleFor).fold(double.infinity, math.min);

  static double _snapUp(double v) => (v / grid).ceil() * grid;

  List<ScreenIssue> run(ScreenLayout l) {
    final out = <ScreenIssue>[];
    final minScale = _minScale(l);
    for (var i = 0; i < l.elements.length; i++) {
      final e = l.elements[i];
      final c = registry[e.component];
      if (c == null) {
        out.add(ScreenIssue(e.id, ScreenIssueKind.binding,
            'Componente "${e.component}" no existe en el sistema de diseño',
            fixLabel: 'Borrar el elemento',
            fix: (l) => l.copyWith(
                elements: [for (final o in l.elements) if (o.id != e.id) o])));
        continue;
      }
      _bounds(l, e, out);
      final style = DsTextStyleInfo.parse(e.textStyle) ?? c.defaultTextStyle;
      final hasText = c.props.contains(DsProp.text) && style != null;
      if (hasText && c.textColor != null) {
        _contrast(l, i, e, c, style, out);
      }
      if (hasText) {
        _textSize(e, style, minScale, out);
        _clipped(e, c, style, out);
      }
      if (c.props.contains(DsProp.role)) _roleStyle(e, style, out);
      if (c.interactive) {
        _tap(e, minScale, out);
        _disabled(e, c, out);
      }
      _bindings(e, c, out);
    }
    _hierarchy(l, out);
    _focus(l, out);
    return out;
  }

  void _bounds(ScreenLayout l, ScreenElement e, List<ScreenIssue> out) {
    if (e.x >= 0 &&
        e.y >= 0 &&
        e.x + e.w <= l.width &&
        e.y + e.h <= l.height) {
      return;
    }
    out.add(ScreenIssue(
        e.id, ScreenIssueKind.bounds, 'La caja se sale de la pantalla',
        fixLabel: 'Meterla adentro',
        fix: (l) {
          final o = l.byId(e.id)!;
          final w = math.min(o.w, l.width), h = math.min(o.h, l.height);
          return l.replace(o.copyWith(
              w: w,
              h: h,
              x: o.x.clamp(0, l.width - w).toDouble(),
              y: o.y.clamp(0, l.height - h).toDouble()));
        }));
  }

  /// Fondo detrás de [index]: su propia superficie o la superficie más
  /// alta debajo que contenga su centro; si no, el fondo de pantalla.
  Color backgroundOf(ScreenLayout l, int index) {
    final e = l.elements[index];
    final own = registry[e.component]?.surface?.call(e.variant);
    if (own != null) return own;
    final center = e.rect.center;
    for (var j = index - 1; j >= 0; j--) {
      final o = l.elements[j];
      final s = registry[o.component]?.surface?.call(o.variant);
      if (s != null && o.rect.contains(center)) return s;
    }
    return background;
  }

  void _contrast(ScreenLayout l, int i, ScreenElement e, DsComponentSpec c,
      DsTextStyleId style, List<ScreenIssue> out) {
    final fg = c.textColor!(e.variant, style);
    final bg = backgroundOf(l, i);
    final ratio = contrastRatio(fg, bg);
    final large = style == DsTextStyleId.display || style == DsTextStyleId.title;
    final need = large ? 3.0 : 4.5;
    if (ratio >= need) return;
    final defaultTone = c.defaultVariant;
    final canFix = defaultTone != null &&
        e.variant != defaultTone &&
        contrastRatio(c.textColor!(defaultTone, style), bg) >= need;
    out.add(ScreenIssue(
        e.id,
        ScreenIssueKind.contrast,
        'Contraste ${ratio.toStringAsFixed(1)}:1 '
        '(mínimo ${need.toStringAsFixed(1)}:1)',
        fixLabel: canFix
            ? 'Usar la variante ${c.variants.first.label}'
            : 'Moverlo a otra superficie o cambiar la variante',
        fix: canFix
            ? (l) => l.replace(l.byId(e.id)!.copyWith(variant: defaultTone))
            : null));
  }

  void _textSize(ScreenElement e, DsTextStyleId style, double minScale,
      List<ScreenIssue> out) {
    final px = style.nominal * minScale;
    if (px >= minTextPx) return;
    out.add(ScreenIssue(e.id, ScreenIssueKind.textSize,
        'El texto queda en ${px.toStringAsFixed(1)} px en la ventana más chica',
        fixLabel: 'Usar el estilo Texto',
        fix: style == DsTextStyleId.body
            ? null
            : (l) => l.replace(l.byId(e.id)!.copyWith(
                textStyle: DsTextStyleId.body.name, role: 'texto'))));
  }

  void _clipped(ScreenElement e, DsComponentSpec c, DsTextStyleId style,
      List<ScreenIssue> out) {
    final text = e.text ?? c.defaultText ?? '';
    if (text.isEmpty) return;
    final pad = c.textPadding;
    final availW = math.max(0.0, e.w - pad.horizontal);
    final availH = math.max(0.0, e.h - pad.vertical);
    final m = measure(text, style, availW);
    // Una palabra más larga que el ancho tampoco entra.
    final longestWord = text
        .split(RegExp(r'\s+'))
        .map((w) => measure(w, style, double.infinity).width)
        .fold(0.0, math.max);
    if (m.height <= availH + 0.5 && longestWord <= availW + 0.5) return;
    out.add(ScreenIssue(
        e.id, ScreenIssueKind.clipped, 'El texto no entra en su caja',
        fixLabel: 'Agrandar la caja',
        fix: (l) {
          final o = l.byId(e.id)!;
          final w = math.max(o.w, _snapUp(longestWord + pad.horizontal));
          final fit = measure(text, style, w - pad.horizontal);
          final h = math.max(o.h, _snapUp(fit.height + pad.vertical));
          return l.replace(o.copyWith(w: w, h: h));
        }));
  }

  void _roleStyle(
      ScreenElement e, DsTextStyleId? style, List<ScreenIssue> out) {
    final allowed = roleStyles[e.role];
    if (allowed == null || style == null || allowed.contains(style)) return;
    out.add(ScreenIssue(
        e.id,
        ScreenIssueKind.roleStyle,
        'Rol ${roleLabels[e.role]} con estilo ${style.label}',
        fixLabel: 'Usar el estilo ${allowed.first.label}',
        fix: (l) => l.replace(
            l.byId(e.id)!.copyWith(textStyle: allowed.first.name))));
  }

  void _hierarchy(ScreenLayout l, List<ScreenIssue> out) {
    final titles = [for (final e in l.elements) if (e.role == 'titulo') e];
    final subs = [for (final e in l.elements) if (e.role == 'subtitulo') e];
    for (final extra in titles.skip(1)) {
      out.add(ScreenIssue(extra.id, ScreenIssueKind.hierarchy,
          'Hay más de un título en la pantalla',
          fixLabel: 'Bajarlo a subtítulo',
          fix: (l) => l.replace(l.byId(extra.id)!.copyWith(
              role: 'subtitulo', textStyle: DsTextStyleId.subtitle.name))));
    }
    if (titles.isEmpty) {
      for (final s in subs.take(1)) {
        out.add(ScreenIssue(s.id, ScreenIssueKind.hierarchy,
            'Hay subtítulos pero ningún título',
            fixLabel: 'Subirlo a título',
            fix: (l) => l.replace(l.byId(s.id)!.copyWith(
                role: 'titulo', textStyle: DsTextStyleId.title.name))));
      }
      return;
    }
    final t = titles.first;
    for (final s in subs) {
      if (s.y + s.h <= t.y) {
        out.add(ScreenIssue(s.id, ScreenIssueKind.hierarchy,
            'El subtítulo está arriba del título',
            fixLabel: 'Moverlo debajo del título'));
      }
    }
  }

  void _tap(ScreenElement e, double minScale, List<ScreenIssue> out) {
    final need = minTap / minScale;
    if (e.w >= need && e.h >= need) return;
    out.add(ScreenIssue(e.id, ScreenIssueKind.tapTarget,
        'Objetivo de clic chico (mínimo ${minTap.toInt()} × ${minTap.toInt()})',
        fixLabel: 'Agrandar',
        fix: (l) {
          final o = l.byId(e.id)!;
          return l.replace(o.copyWith(
              w: math.max(o.w, _snapUp(need)), h: math.max(o.h, _snapUp(need))));
        }));
  }

  void _disabled(ScreenElement e, DsComponentSpec c, List<ScreenIssue> out) {
    final b = bindings;
    final ok = e.action != null && (b == null || b.action(e.action) != null);
    if (ok) return;
    final accent = e.variant == 'primario' || e.variant == 'peligro';
    out.add(ScreenIssue(
        e.id,
        ScreenIssueKind.disabled,
        e.action == null
            ? 'Sin acción: queda deshabilitado (gris)'
            : 'La acción "${e.action}" no existe en esta pantalla: queda '
                'deshabilitado (gris)',
        fixLabel: accent
            ? 'Quitar el acento (un deshabilitado va en gris)'
            : 'Elegir una acción en el inspector',
        fix: accent && c.hasVariant('secundario')
            ? (l) => l.replace(l.byId(e.id)!.copyWith(variant: 'secundario'))
            : null));
  }

  void _bindings(ScreenElement e, DsComponentSpec c, List<ScreenIssue> out) {
    final b = bindings;
    if (b == null) return;
    if (c.props.contains(DsProp.dataSource) &&
        b.dataSource(e.dataSource) == null) {
      final first = b.dataSources.firstOrNull;
      out.add(ScreenIssue(e.id, ScreenIssueKind.binding,
          'Sin fuente de datos de esta pantalla',
          fixLabel: first == null ? null : 'Usar "${first.label}"',
          fix: first == null
              ? null
              : (l) =>
                  l.replace(l.byId(e.id)!.copyWith(dataSource: first.id))));
    }
    if (c.props.contains(DsProp.slot) && b.slot(e.slot) == null) {
      final first = b.slots.firstOrNull;
      out.add(ScreenIssue(
          e.id, ScreenIssueKind.binding, 'Hueco sin elegir o inexistente',
          fixLabel: first == null ? null : 'Usar "${first.label}"',
          fix: first == null
              ? null
              : (l) => l.replace(l.byId(e.id)!.copyWith(slot: first.id))));
    }
  }

  /// Orden de lectura: por filas (centro vertical en bandas de 24 px),
  /// luego de izquierda a derecha.
  static int readingCompare(ScreenElement a, ScreenElement b) {
    final ra = (a.rect.center.dy / 24).floor(),
        rb = (b.rect.center.dy / 24).floor();
    if (ra != rb) return ra.compareTo(rb);
    return a.x.compareTo(b.x);
  }

  void _focus(ScreenLayout l, List<ScreenIssue> out) {
    final inter = [
      for (final e in l.elements)
        if (registry[e.component]?.interactive ?? false) e
    ];
    if (inter.isEmpty) return;
    final visual = [...inter]..sort(readingCompare);
    ScreenLayout renumber(ScreenLayout l) {
      final ids = [
        for (final e in l.elements)
          if (registry[e.component]?.interactive ?? false) e
      ]..sort(readingCompare);
      var out = l;
      for (var i = 0; i < ids.length; i++) {
        out = out.replace(ids[i].copyWith(focusOrder: i + 1));
      }
      return out;
    }

    final seen = <int>{};
    for (final e in inter) {
      final o = e.focusOrder;
      if (o == null) {
        out.add(ScreenIssue(e.id, ScreenIssueKind.focusOrder,
            'Sin orden de foco (no se llega con el teclado en orden)',
            fixLabel: 'Renumerar en orden de lectura', fix: renumber));
      } else if (!seen.add(o)) {
        out.add(ScreenIssue(e.id, ScreenIssueKind.focusOrder,
            'Orden de foco $o repetido',
            fixLabel: 'Renumerar en orden de lectura', fix: renumber));
      }
    }
    if (inter.any((e) => e.focusOrder == null)) return;
    final byFocus = [...inter]
      ..sort((a, b) => a.focusOrder!.compareTo(b.focusOrder!));
    for (var i = 0; i < visual.length; i++) {
      if (visual[i].id != byFocus[i].id) {
        out.add(ScreenIssue(byFocus[i].id, ScreenIssueKind.focusOrder,
            'El orden de foco no sigue la lectura (arriba→abajo, izq→der)',
            fixLabel: 'Renumerar en orden de lectura', fix: renumber));
        return;
      }
    }
  }
}
