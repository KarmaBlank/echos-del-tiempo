import 'package:material_ui/material_ui.dart';

import 'proto_colors.dart';
import 'retro_text.dart';

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

final _tag = RegExp(r'<(/?)([a-zA-Z]+)([^>]*)>');
final _colorAttr = RegExp(r'color:\s*(#[0-9a-fA-F]{3,8})');
final _classAttr = RegExp('class=["\']([^"\']*)["\']');

/// El subconjunto de HTML que arma el prototipo → [TextSpan]. Ver
/// docs/specs/ui_style.md § "Texto rico".
///
/// Etiquetas: `b` (negrita; [boldColor] si no trae color propio),
/// `span`/`b` con `style="color:#hex"`, `class="k"` (`sky`),
/// `class="sys"` (`green`), `small` (`sky`), `br`.
/// Entidades `&nbsp; &amp; &lt; &gt; &quot; &#39;`. Cada trozo de texto
/// pasa por [retroText]. Lo que no entiende lo deja como texto.
TextSpan protoSpan(String markup, {TextStyle? style, Color? boldColor}) {
  final root = <InlineSpan>[];
  // (etiqueta, hijos, estilo)
  final stack = <(String, List<InlineSpan>, TextStyle?)>[];
  var children = root;
  final buf = StringBuffer();

  void flush() {
    if (buf.isEmpty) return;
    children.add(TextSpan(text: retroText(_unescape(buf.toString()))));
    buf.clear();
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
    if (!const {'b', 'span', 'small'}.contains(name)) {
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
    if (c == null && cls.contains('k')) c = ProtoColors.sky;
    if (c == null && cls.contains('sys')) c = ProtoColors.green;
    if (name == 'small') c ??= ProtoColors.sky;
    final TextStyle? st = name == 'b'
        ? TextStyle(fontWeight: FontWeight.bold, color: c ?? boldColor)
        : c == null
            ? null
            : TextStyle(color: c);
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

String _unescape(String s) => s
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&amp;', '&');

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
  Widget build(BuildContext context) => Text.rich(
        protoSpan(markup, style: style, boldColor: boldColor),
        maxLines: maxLines,
        overflow: overflow,
        textAlign: textAlign,
      );
}
