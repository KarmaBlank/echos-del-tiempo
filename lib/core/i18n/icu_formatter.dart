import 'locale_id.dart';

/// Subset of ICU MessageFormat (docs/specs/i18n.md § 3):
///
/// - `{name}`: the argument as text (numbers without grouping).
/// - `{n, number}`: number with the locale's separators.
/// - `{n, plural, =0{…} one{…} other{…}}`: `#` inside a case is `n`.
/// - `{x, select, a{…} b{…} other{…}}`.
/// - `''` is a literal apostrophe; `'{'` / `'}'` quote a brace.
///
/// A missing argument renders as `{name}` so the gap is visible.
class IcuFormatter {
  const IcuFormatter._();

  static String format(String message, LocaleId locale,
      [Map<String, Object?> args = const {}]) {
    if (!message.contains('{') && !message.contains("'")) return message;
    final p = _Parser(message);
    final nodes = p.parseMessage(topLevel: true);
    final out = StringBuffer();
    _render(nodes, locale, args, null, out);
    return out.toString();
  }

  /// Argument names used by [message] (for the placeholder test).
  static Set<String> argumentNames(String message) {
    final names = <String>{};
    void walk(List<_Node> nodes) {
      for (final n in nodes) {
        if (n is _Arg) {
          names.add(n.name);
          for (final c in n.cases.values) {
            walk(c);
          }
        }
      }
    }

    walk(_Parser(message).parseMessage(topLevel: true));
    return names;
  }

  /// Throws [FormatException] if [message] is not valid.
  static void validate(String message) =>
      _Parser(message).parseMessage(topLevel: true);

  static String formatNumber(num n, LocaleId locale) {
    final neg = n < 0;
    final abs = n.abs();
    String intPart, frac = '';
    if (abs is int || abs == abs.truncateToDouble()) {
      intPart = abs.toInt().toString();
    } else {
      final s = abs.toString();
      final dot = s.indexOf('.');
      intPart = s.substring(0, dot);
      frac = s.substring(dot + 1);
    }
    final grouped = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) {
        grouped.write(locale.groupSeparator);
      }
      grouped.write(intPart[i]);
    }
    return '${neg ? '-' : ''}$grouped'
        '${frac.isEmpty ? '' : '${locale.decimalSeparator}$frac'}';
  }

  static void _render(List<_Node> nodes, LocaleId locale,
      Map<String, Object?> args, num? pound, StringBuffer out) {
    for (final n in nodes) {
      switch (n) {
        case _Text(:final text):
          out.write(text);
        case _Pound():
          out.write(pound == null ? '#' : formatNumber(pound, locale));
        case _Arg(:final name, :final type, :final cases):
          final v = args[name];
          if (!args.containsKey(name)) {
            out.write('{$name}');
            continue;
          }
          switch (type) {
            case 'number':
              out.write(v is num ? formatNumber(v, locale) : '$v');
            case 'plural':
              final num count = v is num ? v : num.tryParse('$v') ?? 0;
              final exact = count == count.truncate()
                  ? '=${count.toInt()}'
                  : '=$count';
              final chosen = cases[exact] ??
                  cases[locale.pluralCategory(count)] ??
                  cases['other'] ??
                  const <_Node>[];
              _render(chosen, locale, args, count, out);
            case 'select':
              final chosen =
                  cases['$v'] ?? cases['other'] ?? const <_Node>[];
              _render(chosen, locale, args, pound, out);
            default:
              out.write(v ?? '');
          }
      }
    }
  }
}

sealed class _Node {}

class _Text extends _Node {
  _Text(this.text);
  final String text;
}

class _Pound extends _Node {}

class _Arg extends _Node {
  _Arg(this.name, this.type, this.cases);
  final String name;
  final String type;
  final Map<String, List<_Node>> cases;
}

class _Parser {
  _Parser(this.src);
  final String src;
  int i = 0;

  Never _fail(String why) =>
      throw FormatException('ICU: $why at $i in "$src"');

  List<_Node> parseMessage({required bool topLevel, bool inPlural = false}) {
    final nodes = <_Node>[];
    final buf = StringBuffer();
    void flush() {
      if (buf.isNotEmpty) {
        nodes.add(_Text(buf.toString()));
        buf.clear();
      }
    }

    while (i < src.length) {
      final c = src[i];
      if (c == "'") {
        if (i + 1 < src.length && src[i + 1] == "'") {
          buf.write("'");
          i += 2;
        } else if (i + 1 < src.length &&
            (src[i + 1] == '{' || src[i + 1] == '}' || src[i + 1] == '#')) {
          final end = src.indexOf("'", i + 1);
          if (end < 0) _fail('unclosed quote');
          buf.write(src.substring(i + 1, end));
          i = end + 1;
        } else {
          buf.write(c);
          i++;
        }
      } else if (c == '{') {
        flush();
        i++;
        nodes.add(_parseArg());
      } else if (c == '}') {
        if (topLevel) _fail('unexpected }');
        break;
      } else if (c == '#' && inPlural) {
        flush();
        nodes.add(_Pound());
        i++;
      } else {
        buf.write(c);
        i++;
      }
    }
    flush();
    return nodes;
  }

  void _ws() {
    while (i < src.length && src[i].trim().isEmpty) {
      i++;
    }
  }

  String _word() {
    _ws();
    final start = i;
    while (i < src.length && !',{}'.contains(src[i]) && src[i].trim().isNotEmpty) {
      i++;
    }
    if (start == i) _fail('expected a name');
    return src.substring(start, i);
  }

  _Arg _parseArg() {
    final name = _word();
    _ws();
    if (i >= src.length) _fail('unclosed {');
    if (src[i] == '}') {
      i++;
      return _Arg(name, '', const {});
    }
    if (src[i] != ',') _fail('expected , or }');
    i++;
    final type = _word();
    _ws();
    if (type == 'number') {
      if (i >= src.length || src[i] != '}') _fail('expected }');
      i++;
      return _Arg(name, type, const {});
    }
    if (type != 'plural' && type != 'select') _fail('unknown type $type');
    if (i >= src.length || src[i] != ',') _fail('expected ,');
    i++;
    final cases = <String, List<_Node>>{};
    while (true) {
      _ws();
      if (i >= src.length) _fail('unclosed $type');
      if (src[i] == '}') {
        i++;
        break;
      }
      final sel = _word();
      _ws();
      if (i >= src.length || src[i] != '{') _fail('expected { after $sel');
      i++;
      cases[sel] = parseMessage(topLevel: false, inPlural: type == 'plural');
      if (i >= src.length || src[i] != '}') _fail('unclosed case $sel');
      i++;
    }
    if (!cases.containsKey('other')) _fail('$type without other');
    return _Arg(name, type, cases);
  }
}
