import '../../../game_engine/models/build_wants.dart';
import '../../../game_engine/models/loot_filter.dart';

/// Atajos del editor de filtro para la condición `Build` ("Coincide con
/// mi build"; docs/specs/loot.md § 13 y panels.md § "Filtro de loot").
/// Puro: trabaja sobre el texto y la posición del cursor.
abstract final class FilterBuildSnippets {
  /// La condición para las clases elegidas (vacío = cualquier meta).
  static BuildCondition condition(Set<BuildMatch> kinds) =>
      BuildCondition(kinds: [
        for (final k in BuildMatch.values)
          if (kinds.contains(k)) k
      ]);

  /// Regla que resalta lo que coincide (va arriba de todo: gana la
  /// primera que coincide). Mismo estilo que la del filtro por defecto.
  static String highlightRule(Set<BuildMatch> kinds) =>
      'Mostrar # Coincide con mi build\n'
      '  ${condition(kinds).text}\n'
      '  Borde 195 155 255\n'
      '  Fondo 30 12 50 220\n'
      '  Tamaño 36\n'
      '  Sonido campana\n'
      '  Icono estrella violeta\n';

  /// Regla que oculta los Comunes que no sirven a tu plan.
  static const hideRule = 'Ocultar # Comunes fuera de mi build\n'
      '  Build No\n'
      '  Rareza Común\n';

  /// Agrega [rule] al principio de [text]. Devuelve el texto y dónde
  /// queda el cursor (al final de la regla).
  static (String, int) prependRule(String text, String rule) =>
      ('$rule$text', rule.length);

  /// Agrega la condición como una línea nueva debajo de la línea del
  /// cursor ([cursor] < 0: al final), dentro de la regla en la que está.
  /// Si el cursor no está dentro de una regla, agrega una regla nueva
  /// que resalta ([highlightRule]) al principio.
  static (String, int) insertCondition(
      String text, int cursor, Set<BuildMatch> kinds) {
    final at = cursor < 0 || cursor > text.length ? text.length : cursor;
    final before = text.substring(0, at);
    final inRule = before
        .split(RegExp(r'\r?\n'))
        .map((l) => l.split('#').first.trim().toLowerCase())
        .any((w) => w == 'mostrar' || w == 'ocultar');
    if (!inRule) return prependRule(text, highlightRule(kinds));
    final nl = text.indexOf('\n', at);
    final lineEnd = nl < 0 ? text.length : nl;
    final line = '  ${condition(kinds).text}';
    if (nl < 0) {
      final pre = text.isEmpty || text.endsWith('\n') ? '' : '\n';
      final out = '$text$pre$line\n';
      return (out, out.length);
    }
    final out =
        '${text.substring(0, lineEnd + 1)}$line\n${text.substring(lineEnd + 1)}';
    return (out, lineEnd + 1 + line.length);
  }
}
