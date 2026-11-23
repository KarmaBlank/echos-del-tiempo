import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show Rect, Size;

/// Ancla horizontal de un elemento (docs/specs/screen_editor.md § 2.1).
enum HAnchor { left, center, right, stretch }

/// Ancla vertical de un elemento.
enum VAnchor { top, center, bottom, stretch }

/// Alineación del contenido dentro de su caja.
enum ScreenAlign { start, center, end }

T _enumOr<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

const _keep = Object();

/// Un elemento colocado en la pantalla. Solo nombres del registro del
/// sistema de diseño y de los bindings: nunca colores ni código.
class ScreenElement {
  const ScreenElement({
    required this.id,
    required this.component,
    this.variant,
    this.size,
    this.text,
    this.textStyle,
    this.role,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    this.hAnchor = HAnchor.left,
    this.vAnchor = VAnchor.top,
    this.align = ScreenAlign.start,
    this.focusOrder,
    this.action,
    this.dataSource,
    this.slot,
  });

  final String id;
  final String component;
  final String? variant;
  final String? size;
  final String? text;
  final String? textStyle;

  /// Rol semántico del texto: `titulo`, `subtitulo`, `texto`, `detalle`.
  final String? role;
  final double x, y, w, h;
  final HAnchor hAnchor;
  final VAnchor vAnchor;
  final ScreenAlign align;
  final int? focusOrder;
  final String? action;
  final String? dataSource;
  final String? slot;

  Rect get rect => Rect.fromLTWH(x, y, w, h);

  ScreenElement copyWith({
    String? id,
    String? component,
    Object? variant = _keep,
    Object? size = _keep,
    Object? text = _keep,
    Object? textStyle = _keep,
    Object? role = _keep,
    double? x,
    double? y,
    double? w,
    double? h,
    HAnchor? hAnchor,
    VAnchor? vAnchor,
    ScreenAlign? align,
    Object? focusOrder = _keep,
    Object? action = _keep,
    Object? dataSource = _keep,
    Object? slot = _keep,
  }) =>
      ScreenElement(
        id: id ?? this.id,
        component: component ?? this.component,
        variant: identical(variant, _keep) ? this.variant : variant as String?,
        size: identical(size, _keep) ? this.size : size as String?,
        text: identical(text, _keep) ? this.text : text as String?,
        textStyle: identical(textStyle, _keep)
            ? this.textStyle
            : textStyle as String?,
        role: identical(role, _keep) ? this.role : role as String?,
        x: x ?? this.x,
        y: y ?? this.y,
        w: w ?? this.w,
        h: h ?? this.h,
        hAnchor: hAnchor ?? this.hAnchor,
        vAnchor: vAnchor ?? this.vAnchor,
        align: align ?? this.align,
        focusOrder: identical(focusOrder, _keep)
            ? this.focusOrder
            : focusOrder as int?,
        action: identical(action, _keep) ? this.action : action as String?,
        dataSource: identical(dataSource, _keep)
            ? this.dataSource
            : dataSource as String?,
        slot: identical(slot, _keep) ? this.slot : slot as String?,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'component': component,
        if (variant != null) 'variant': variant,
        if (size != null) 'size': size,
        if (text != null) 'text': text,
        if (textStyle != null) 'textStyle': textStyle,
        if (role != null) 'role': role,
        'x': x,
        'y': y,
        'w': w,
        'h': h,
        'hAnchor': hAnchor.name,
        'vAnchor': vAnchor.name,
        'align': align.name,
        if (focusOrder != null) 'focusOrder': focusOrder,
        if (action != null) 'action': action,
        if (dataSource != null) 'dataSource': dataSource,
        if (slot != null) 'slot': slot,
      };

  factory ScreenElement.fromJson(Map<String, Object?> j) {
    double n(String k) {
      final v = j[k];
      if (v is num) return v.toDouble();
      throw FormatException('"$k" no es número en ${j['id']}');
    }

    final id = j['id'], component = j['component'];
    if (id is! String || component is! String) {
      throw const FormatException('elemento sin id o componente');
    }
    return ScreenElement(
      id: id,
      component: component,
      variant: j['variant'] as String?,
      size: j['size'] as String?,
      text: j['text'] as String?,
      textStyle: j['textStyle'] as String?,
      role: j['role'] as String?,
      x: n('x'),
      y: n('y'),
      w: n('w'),
      h: n('h'),
      hAnchor: _enumOr(HAnchor.values, j['hAnchor'], HAnchor.left),
      vAnchor: _enumOr(VAnchor.values, j['vAnchor'], VAnchor.top),
      align: _enumOr(ScreenAlign.values, j['align'], ScreenAlign.start),
      focusOrder: (j['focusOrder'] as num?)?.toInt(),
      action: j['action'] as String?,
      dataSource: j['dataSource'] as String?,
      slot: j['slot'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ScreenElement &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;
}

/// Dónde cae un elemento en una ventana: caja final y escala del
/// contenido.
class ScreenPlacement {
  const ScreenPlacement(this.rect, this.scale);
  final Rect rect;
  final double scale;
}

/// Layout de una pantalla como datos (docs/specs/screen_editor.md § 2).
class ScreenLayout {
  const ScreenLayout({
    required this.screen,
    this.version = 1,
    this.width = 1280,
    this.height = 720,
    this.elements = const [],
  });

  final String screen;
  final int version;
  final double width, height;

  /// En orden Z: el último queda arriba.
  final List<ScreenElement> elements;

  Size get size => Size(width, height);

  ScreenElement? byId(String id) {
    for (final e in elements) {
      if (e.id == id) return e;
    }
    return null;
  }

  ScreenLayout copyWith({List<ScreenElement>? elements}) => ScreenLayout(
        screen: screen,
        version: version,
        width: width,
        height: height,
        elements: elements ?? this.elements,
      );

  /// Reemplaza el elemento con el id de [e].
  ScreenLayout replace(ScreenElement e) => copyWith(elements: [
        for (final o in elements) o.id == e.id ? e : o,
      ]);

  Map<String, Object?> toJson() => {
        'screen': screen,
        'version': version,
        'width': width,
        'height': height,
        'elements': [for (final e in elements) e.toJson()],
      };

  /// JSON con sangría (diffs legibles en el repo).
  String encode() => '${const JsonEncoder.withIndent('  ').convert(toJson())}\n';

  factory ScreenLayout.fromJson(Map<String, Object?> j) {
    final screen = j['screen'];
    if (screen is! String) throw const FormatException('falta "screen"');
    final raw = j['elements'];
    return ScreenLayout(
      screen: screen,
      version: (j['version'] as num?)?.toInt() ?? 1,
      width: (j['width'] as num?)?.toDouble() ?? 1280,
      height: (j['height'] as num?)?.toDouble() ?? 720,
      elements: [
        if (raw is List)
          for (final e in raw)
            ScreenElement.fromJson((e as Map).cast<String, Object?>()),
      ],
    );
  }

  /// Lee un JSON; [FormatException] si no es un layout.
  static ScreenLayout parse(String source) {
    final d = jsonDecode(source);
    if (d is! Map) throw const FormatException('no es un objeto');
    return ScreenLayout.fromJson(d.cast<String, Object?>());
  }

  /// Escala del contenido en [window].
  double scaleFor(Size window) =>
      math.min(window.width / width, window.height / height);

  /// Caja de [e] en [window] según sus anclas (§ 2.1).
  ScreenPlacement place(ScreenElement e, Size window) {
    final s = scaleFor(window);
    (double, double) axis(int anchor, double pos, double len, double design,
        double real) {
      switch (anchor) {
        case 0: // inicio
          return (pos * s, len * s);
        case 1: // centro
          return (real / 2 + (pos - design / 2) * s, len * s);
        case 2: // fin
          return (real - (design - pos) * s, len * s);
        default: // estirar
          final start = pos * s;
          final end = (design - pos - len) * s;
          return (start, math.max(0, real - start - end));
      }
    }

    final (l, w) = axis(e.hAnchor.index, e.x, e.w, width, window.width);
    final (t, h) = axis(e.vAnchor.index, e.y, e.h, height, window.height);
    return ScreenPlacement(Rect.fromLTWH(l, t, w, h), s);
  }

  @override
  bool operator ==(Object other) =>
      other is ScreenLayout && encode() == other.encode();

  @override
  int get hashCode => encode().hashCode;
}
