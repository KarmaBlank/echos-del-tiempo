/// Nivel de detalle de los textos del juego (ajuste TEXTOS,
/// docs/specs/ui_minimal.md § 8 y settings.md § 3.10). Dart puro: lo leen
/// los armadores de descripciones (habilidades, ULT, mods, pasivas,
/// estados, oficios, objetos de vida) sin depender de Flutter.
enum TextDetail {
  /// RESUMIDO (por defecto): una o dos líneas cortas, en palabras
  /// simples, con el número principal de cada efecto y sin fórmulas.
  summary,

  /// DETALLADO: el texto completo con números, escalado, fórmulas y
  /// reglas finas.
  full;

  static TextDetail fromName(Object? v, TextDetail def) =>
      values.firstWhere((m) => m.name == v, orElse: () => def);

  /// Modo vigente. Lo pone `TextDetailScope` (arriba de toda la app) a
  /// partir del ajuste; fuera de la app (tests de dominio) queda en
  /// DETALLADO, el texto de siempre.
  static TextDetail current = TextDetail.full;

  static bool get isSummary => current == TextDetail.summary;

  /// Corre [f] con el modo [mode] (y vuelve al de antes). Sirve para el
  /// `MÁS DETALLE` de un tooltip: el mismo armador, en DETALLADO.
  static T run<T>(TextDetail mode, T Function() f) {
    final prev = current;
    current = mode;
    try {
      return f();
    } finally {
      current = prev;
    }
  }

  /// En RESUMIDO, el texto DETALLADO de [f] (para el `MÁS DETALLE` del
  /// tooltip); en DETALLADO, `null` (ya se ve todo).
  static String? fullIfSummary(String Function() f) =>
      isSummary ? run(TextDetail.full, f) : null;
}
