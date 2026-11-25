/// Pasa un texto DETALLADO (texto plano, sin markup) a su versión
/// RESUMIDA (docs/specs/ui_minimal.md § 8.2): saca paréntesis y
/// fórmulas, cambia abreviaturas por palabras, se queda con la primera
/// oración entera (nunca la corta). Sirve para los textos que vienen de
/// datos (mecánicas, keystones, mods, oficios, objetos de vida); los que
/// leen mal así se escriben a mano en su armador. Con [sentence] en
/// `false` no agrega el punto final (mods, etiquetas).
String plainShort(String full, {bool sentence = true}) {
  var t = full.trim();
  // Paréntesis: casi siempre reglas finas o el detalle de la fórmula.
  t = t.replaceAll(RegExp(r'\s*\([^()]*\)'), '');
  // Fórmulas: "MAG × 0.8", "ATQ × 1.2", "= 31", "× 2.0".
  t = t.replaceAll(
      RegExp(r'\s*(ATQ|MAG|Curación|DEF)\s*×\s*\d+(?:[.,]\d+)?'), '');
  t = t.replaceAll(RegExp(r'\s*=\s*[\d.,]+'), '');
  // The number must not swallow a trailing "," ("×2.0, pero").
  t = t.replaceAllMapped(RegExp(r'×\s*(\d+(?:[.,]\d+)?)'), (m) {
    final v = double.tryParse(m[1]!.replaceAll(',', '.'));
    if (v == null) return '';
    if (v == 2) return 'el doble';
    if (v == 3) return 'el triple';
    return '${(v * 100).round()}%';
  });
  for (final (a, b) in _words) {
    t = t.replaceAll(RegExp(a), b);
  }
  t = t.replaceAll(RegExp(r'\s{2,}'), ' ').replaceAll(' ,', ',').trim();
  // Primera oración (o hasta el primer ";").
  final end = RegExp(r'[.;](\s|$)').firstMatch(t);
  if (end != null) t = t.substring(0, end.start);
  // The sentence stays whole: never cut mid-way nor end in "…"
  // (ui_style.md § "Tooltips cortos", v0.36.1).
  t = t.trim();
  if (t.isEmpty || !sentence) return t;
  if (!t.endsWith('.') && !t.endsWith('!')) t = '$t.';
  return t;
}

/// Tope de un texto RESUMIDO: unas dos líneas cortas del tooltip.
const kShortMaxChars = 90;

/// Palabras que el RESUMIDO no usa (abreviaturas y jerga) y su cambio.
const _words = <(String, String)>[
  (r'\bATQ\b', 'ataque'),
  (r'\bMAG\b', 'magia'),
  (r'\bDEF\b', 'defensa'),
  (r'\bVEL\b', 'velocidad'),
  (r'\bvel\.', 'velocidad'),
  (r'\bHP\b', 'vida'),
  (r'\bMP\b', 'maná'),
  (r'\bvida máx\.', 'vida'),
  (r'\bmaná máx\.', 'maná'),
  (r'\bmáx\.\s*', 'hasta '),
  (r'\bc/u\b', 'cada uno'),
  (r'\bstacks\b', 'capas'),
  (r'\bstack\b', 'capa'),
  (r'\bbuffs\b', 'mejoras'),
  (r'\bdebuffs\b', 'castigos'),
];

/// Lo que nunca aparece en un texto RESUMIDO (tests y la regla del spec).
const kFormulaTokens = <String>[
  '×',
  ' = ',
  'ATQ',
  'MAG',
  'DEF',
  'stack',
  'máx.',
  'c/u',
];
