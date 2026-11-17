/// `Math.round` de JavaScript: redondea .5 hacia +∞ (Dart `round()` lo
/// hace alejándose de cero). Todos los cálculos portados del prototipo
/// usan esto para dar exactamente los mismos números.
int jsRound(num x) => (x + 0.5).floor();

/// Formato numérico de los logs del prototipo (`fm`): hasta 2 decimales,
/// sin ceros de más (1.50 → "1.5", 2.00 → "2").
String fm(num x) {
  final v = double.parse(x.toStringAsFixed(2));
  return v == v.truncateToDouble() ? v.toInt().toString() : v.toString();
}
