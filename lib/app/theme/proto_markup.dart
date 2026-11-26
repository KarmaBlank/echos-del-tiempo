import 'package:material_ui/material_ui.dart';

import '../design/ds_gold.dart';
import '../design/ds_tokens.dart' show DsColors, DsTextColor, DsTextRole;
import 'proto_colors.dart';
import 'retro_text.dart';
import 'retro_type.dart';
import 'ui_theme.dart';
import 'vision_palette.dart';

/// `esc` del prototipo: escapa un texto libre (nombres, chat) antes de
/// meterlo en markup.
String protoEsc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');

/// `<span style="color:#hex">texto</span>` (texto ya escapado o fijo).
String protoColor(Color c, String text) =>
    '<span style="color:${ProtoColors.hex(c)}">$text</span>';

/// Lo que no cuenta como "texto" al principio de una línea (viñetas).
final _lead = RegExp(r'[\s•·]');

final _tag = RegExp(r'<(/?)([a-zA-Z]+)([^>]*)>');
final _colorAttr = RegExp(r'color:\s*(#[0-9a-fA-F]{3,8})');
final _classAttr = RegExp('class=["\']([^"\']*)["\']');

/// El subconjunto de HTML que arma el prototipo → [TextSpan]. Ver
/// docs/specs/ui_style.md § "Texto rico".
///
/// Etiquetas: `b` (resaltado SOLO con color, sin peso: [boldColor] o
/// `gold` si no trae color propio),
/// `span`/`b` con `style="color:#hex"`, `class="k"` (rol Subtítulo),
/// `class="sys"` (`green`), `small` (`sky`), `br`, y los roles de texto
/// `title`, `sub`, `muted`, `key` (`**…**` = `key`; design_system.md
/// § 3.4).
/// Entidades `&nbsp; &amp; &lt; &gt; &quot; &#39;`. Cada trozo de texto
/// pasa por [retroText]. Lo que no entiende lo deja como texto.
///
/// El resultado se guarda (LRU de [ProtoSpanCache.max]) por markup, estilo,
/// color de `<b>` y el estado de tema / colores del texto / modo
/// daltónico: el HUD lo vuelve a pedir en cada reconstrucción
/// (docs/specs/exploration.md § "Rendimiento").
TextSpan protoSpan(String markup, {TextStyle? style, Color? boldColor}) =>
    ProtoSpanCache.get(markup, style, boldColor);

/// Caché de [protoSpan] (ver ahí).
abstract final class ProtoSpanCache {
  static const max = 256;

  /// Lo interpretado con el tema [_themeOf]. Un mapa por tema: los
  /// `ThemeColor` de los estilos cambian su `hashCode` con el tema, así
  /// que nunca se mezclan claves de temas distintos.
  static var _spans = <(String, TextStyle?, int?), TextSpan>{};
  static Object? _themeOf;

  /// Aciertos y markups interpretados (tests).
  static int hits = 0, misses = 0;

  /// Lo que cambia los colores del resultado.
  static Object get _theme => (
        UiTheme.kind,
        UiTheme.textColors,
        VisionPalette.mode,
      );

  static TextSpan get(String markup, TextStyle? style, Color? boldColor) {
    final theme = _theme;
    if (theme != _themeOf) {
      _spans = {};
      _themeOf = theme;
    }
    final key = (markup, style, boldColor?.toARGB32());
    final hit = _spans.remove(key);
    if (hit != null) {
      hits++;
      return _spans[key] = hit;
    }
    misses++;
    if (_spans.length >= max) {
      // El menos usado; si algo raro impide sacarlo, se vacía.
      if (_spans.remove(_spans.keys.first) == null) _spans.clear();
    }
    return _spans[key] =
        _parseProtoSpan(markup, style: style, boldColor: boldColor);
  }

  static void clear() {
    _spans = {};
    _themeOf = null;
  }
}

/// `**text**` → `<key>text</key>` (KEY INFO role, design_system.md
/// § 3.4). Lets i18n strings mark the rule or number that matters.
final _keyStars = RegExp(r'\*\*(.+?)\*\*');

/// [markup] with `**…**` turned into `<key>…</key>`.
String protoKeyMarkup(String markup) => markup.contains('**')
    ? markup.replaceAllMapped(_keyStars, (m) => '<key>${m.group(1)}</key>')
    : markup;

/// Semantic text-role tags (design_system.md § 3.4): `<title>`,
/// `<sub>`, `<muted>`, `<key>` (also `**…**`).
const _roleTags = {
  'title': DsTextRole.title,
  'sub': DsTextRole.subtitle,
  'muted': DsTextRole.detail,
  'key': DsTextRole.key,
};

/// Every tag the parser understands (the rest stays as text).
const _tags = {'b', 'span', 'small', 'title', 'sub', 'muted', 'key'};

TextSpan _parseProtoSpan(String markup,
    {TextStyle? style, Color? boldColor}) {
  markup = protoKeyMarkup(markup);
  final root = <InlineSpan>[];
  // (etiqueta, hijos, estilo)
  final stack = <(String, List<InlineSpan>, TextStyle?)>[];
  var children = root;
  final buf = StringBuffer();
  // Colores por roles (accessibility.md § 8.2): un `<b>` que abre la
  // línea es un nombre / título.
  final roles = UiTheme.roles;
  var lineStart = true;

  void flush() {
    if (buf.isEmpty) return;
    final t = _unescape(buf.toString());
    // Each `₵` is the gold coin (design_system.md § DsGold), never "$".
    final parts = t.split('₵');
    for (var k = 0; k < parts.length; k++) {
      if (k > 0) children.add(DsGoldText.coinSpan(style));
      if (parts[k].isNotEmpty) children.addAll(symbolSpans(retroText(parts[k])));
    }
    buf.clear();
    final nl = t.lastIndexOf('\n');
    if (nl >= 0) lineStart = true;
    if (t.substring(nl + 1).replaceAll(_lead, '').isNotEmpty) {
      lineStart = false;
    }
  }

  void closeTop() {
    final (_, kids, st) = stack.removeLast();
    final parent = stack.isEmpty ? root : stack.last.$2;
    parent.add(TextSpan(style: st, children: kids));
    children = parent;
  }

  var i = 0;
  for (final m in _tag.allMatches(markup)) {
    buf.write(markup.substring(i, m.start));
    i = m.end;
    final closing = m.group(1) == '/';
    final name = m.group(2)!.toLowerCase();
    final attrs = m.group(3) ?? '';
    if (name == 'br') {
      buf.write('\n');
      continue;
    }
    if (!_tags.contains(name)) {
      buf.write(m.group(0));
      continue;
    }
    flush();
    if (closing) {
      // Cierra hasta la etiqueta del mismo nombre (HTML tolerante).
      final at = stack.lastIndexWhere((e) => e.$1 == name);
      if (at < 0) continue;
      while (stack.length > at) {
        closeTop();
      }
      continue;
    }
    final col = _colorAttr.firstMatch(attrs);
    final cls = _classAttr.firstMatch(attrs)?.group(1)?.split(' ') ?? const [];
    var c = col == null ? null : ProtoColors.parse(col.group(1)!);
    // `class="k"` (section label) is the Subtitle role (§ 3.4): never
    // the sky blue that reads as Magic / ice.
    final isLabel = c == null && cls.contains('k');
    if (isLabel) c = DsColors.textSubtitle;
    if (c == null && cls.contains('sys')) c = ProtoColors.green;
    if (name == 'small') c ??= ProtoColors.sky;
    final bold = name == 'b';
    if (bold) c ??= boldColor ?? ProtoColors.gold;
    if (roles && c != null && !isLabel) {
      final inBold = stack.any((e) => e.$1 == 'b');
      c = UiTheme.role(c, bold: bold || inBold, lineStart: lineStart);
    }
    // Text-role tags: their own role colour, never remapped
    // (design_system.md § 3.4).
    if (_roleTags[name] case final role?) c = DsTextColor(role);
    // Sin peso (las fuentes pixel se "engordan" con negrita sintética):
    // `<b>` resalta solo con el color (ui_style.md).
    final TextStyle? st = c == null ? null : TextStyle(color: c);
    final kids = <InlineSpan>[];
    stack.add((name, kids, st));
    children = kids;
  }
  buf.write(markup.substring(i));
  flush();
  while (stack.isNotEmpty) {
    closeTop();
  }
  return TextSpan(style: style, children: root);
}

/// Símbolos que VT323 (texto de lectura) no tiene y salen de Press
/// Start 2P: van en su tamaño chico ([RetroType.label]) para no salir
/// enormes al lado del texto.
final _symbols = RegExp('[←→★♥▶▲▼½♦◀▸▾]');

const _symbolStyle = TextStyle(
    fontFamily: RetroType.pixelFamily, fontSize: RetroType.glyph, height: 1);

/// [text] en trozos: los símbolos de [_symbols] con su estilo propio.
List<InlineSpan> symbolSpans(String text) {
  if (!_symbols.hasMatch(text)) return [TextSpan(text: text)];
  final out = <InlineSpan>[];
  var i = 0;
  for (final m in _symbols.allMatches(text)) {
    if (m.start > i) out.add(TextSpan(text: text.substring(i, m.start)));
    out.add(TextSpan(text: m.group(0), style: _symbolStyle));
    i = m.end;
  }
  if (i < text.length) out.add(TextSpan(text: text.substring(i)));
  return out;
}

String _unescape(String s) => s
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&amp;', '&');

/// Corta un markup en sus líneas (`<br>`), cerrando al final de cada una
/// las etiquetas abiertas y reabriéndolas en la siguiente: cada línea es
/// un markup válido con el mismo aspecto. Para repartir un tip largo en
/// columnas (`RetroTipText`).
List<String> protoSplitLines(String markup) {
  markup = protoKeyMarkup(markup);
  final out = <String>[];
  // (nombre, etiqueta de apertura tal cual)
  final open = <(String, String)>[];
  var line = StringBuffer();
  var i = 0;
  for (final m in _tag.allMatches(markup)) {
    line.write(markup.substring(i, m.start));
    i = m.end;
    final closing = m.group(1) == '/';
    final name = m.group(2)!.toLowerCase();
    if (name == 'br') {
      for (final (n, _) in open.reversed) {
        line.write('</$n>');
      }
      out.add(line.toString());
      line = StringBuffer();
      for (final (_, tag) in open) {
        line.write(tag);
      }
      continue;
    }
    line.write(m.group(0));
    if (!_tags.contains(name)) continue;
    if (closing) {
      final at = open.lastIndexWhere((e) => e.$1 == name);
      if (at >= 0) open.removeRange(at, open.length);
    } else {
      open.add((name, m.group(0)!));
    }
  }
  line.write(markup.substring(i));
  out.add(line.toString());
  return out;
}

/// Texto plano de un markup (tests, accesibilidad).
String protoPlain(String markup) => protoSpan(markup).toPlainText();

/// [Text.rich] de un markup del prototipo.
class ProtoText extends StatelessWidget {
  const ProtoText(
    this.markup, {
    super.key,
    this.style,
    this.boldColor = ProtoColors.gold,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  final String markup;
  final TextStyle? style;

  /// Color de `<b>` sin color propio (dorado como `#tip b` / `#menu b`).
  final Color? boldColor;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    // ESPACIADO AMPLIO (accessibility.md § 8.3): cada línea (`<br>`) es
    // un párrafo con aire entre medio. Con [maxLines] queda en un bloque.
    if (UiTheme.wide && maxLines == null && markup.contains('<br')) {
      final lines = protoSplitLines(markup);
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: switch (textAlign) {
          TextAlign.right || TextAlign.end => CrossAxisAlignment.end,
          TextAlign.center => CrossAxisAlignment.center,
          _ => CrossAxisAlignment.start,
        },
        children: [
          for (var i = 0; i < lines.length; i++) ...[
            if (i > 0) SizedBox(height: UiTheme.paragraphGap),
            Text.rich(
              protoSpan(lines[i], style: style, boldColor: boldColor),
              overflow: overflow,
              textAlign: textAlign,
            ),
          ],
        ],
      );
    }
    return Text.rich(
      protoSpan(markup, style: style, boldColor: boldColor),
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }
}
