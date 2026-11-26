import '../../../../core/text/text_detail.dart';
import '../../../../game_engine/data/fishing_catalog.dart';
import '../../../../game_engine/rules/farming_rules.dart';
import '../../../../game_engine/rules/fishing_rules.dart';

/// Textos de las herramientas de oficio (cañas, azadas, regaderas) para
/// el detalle y el tooltip (town_loop.md § 11c, ui_minimal.md § 8): qué
/// hace cada una, según TEXTOS, y la comparación con la equipada.

String _pct(double v) => '${(v * 100).round()} %';

String _area(int a) => switch (a) {
      0 => '1 casilla',
      1 => 'cruz de 5',
      _ => '3 × 3',
    };

/// Cabecera común: se usa a cualquier nivel; [req] es el nivel para
/// rendir al 100 %; abajo, sus bonos valen menos.
List<String> _yieldLines(String skill, int level, int req, double k) {
  final full = !TextDetail.isSummary;
  return [
    if (k >= 1 - 1e-6)
      'Con tu nivel ($skill $level) rinde al 100 %.'
    else ...[
      'Nivel $req para rendir al 100 % (se usa igual a cualquier nivel).',
      'Con tu nivel ($skill $level) rinde ${_pct(k)}: '
          'sus bonos valen el ${_pct(k)}.',
    ],
    if (full)
      'Rinde = piso + (1 − piso) × (tu nivel / $req)^curva, tope 100 %.',
  ];
}

/// Un bono: en RESUMIDO el valor que te da hoy; en DETALLADO también el
/// valor completo (`Peces raros +30 % → +13 % con tu nivel`).
String _bonus(String label, String Function(double) fmt, double v, double k) {
  if (TextDetail.isSummary || k >= 1 - 1e-6) return '$label ${fmt(v * k)}';
  return '$label ${fmt(v)} → ${fmt(v * k)} con tu nivel';
}

String _plus(double v) => '+${_pct(v)}';

/// Líneas de una caña con [level] de Pesca.
List<String> rodLines(RodDef r, int level) {
  final k = FishingRules.effectiveness(level, r.reqLevel);
  final none = r.rareBonus == 0 && r.biteSpeed == 0 && r.zoneBonus == 0;
  if (none) return ['Caña básica: pesca sin bonos, a cualquier nivel.'];
  return [
    ..._yieldLines('Pesca', level, r.reqLevel, k),
    if (r.rareBonus > 0) _bonus('Peces raros', _plus, r.rareBonus, k),
    if (r.biteSpeed > 0) _bonus('Pican más rápido', _plus, r.biteSpeed, k),
    if (r.zoneBonus > 0)
      _bonus('Zona de captura más ancha', _plus, r.zoneBonus, k),
  ];
}

/// Líneas de una azada o regadera con [level] de Cultivo.
List<String> farmToolLines(FarmToolDef d, int level) {
  final k = FarmingRules.effectiveness(level, d.reqLevel);
  final hoe = d.kind == FarmToolKind.azada;
  final area = (d.area * k + 1e-6).floor();
  if (d.quality == 0 && d.extra == 0 && d.area == 0) {
    return [
      hoe
          ? 'Azada básica: ara 1 casilla, sin bonos.'
          : 'Regadera básica: riega 1 casilla, sin bonos.'
    ];
  }
  String x(double v) => '×${(1 + v).toStringAsFixed(2)}';
  return [
    ..._yieldLines('Granjero', level, d.reqLevel, k),
    TextDetail.isSummary || area == d.area
        ? 'Área ${_area(area)}'
        : 'Área ${_area(d.area)} → ${_area(area)} con tu nivel',
    if (d.quality > 0) _bonus('Calidad de cosecha', _plus, d.quality, k),
    if (d.extra > 0)
      hoe
          ? _bonus('Chance de cosecha doble', _pct, d.extra, k)
          : _bonus('El riego dura', x, d.extra, k),
  ];
}

/// Una diferencia contra la equipada: texto y si mejora.
typedef ToolDelta = (String text, bool better);

List<ToolDelta> _deltas(List<(String, double, double)> stats,
    {String Function(double)? fmt}) {
  final f = fmt ?? (v) => '${(v * 100).round()} %';
  return [
    for (final (label, a, b) in stats)
      if ((a - b).abs() > 1e-6)
        ('$label ${f(b)} → ${f(a)} ${a > b ? '▲' : '▼'}', a > b),
  ];
}

/// Cambios de equipar [r] en vez de [eq] (valores con tu nivel).
List<ToolDelta> rodCompare(RodDef r, RodDef eq, int level) {
  final k = FishingRules.effectiveness(level, r.reqLevel);
  final ke = FishingRules.effectiveness(level, eq.reqLevel);
  return _deltas([
    ('Peces raros', r.rareBonus * k, eq.rareBonus * ke),
    ('Picada', r.biteSpeed * k, eq.biteSpeed * ke),
    ('Zona', r.zoneBonus * k, eq.zoneBonus * ke),
  ]);
}

/// Cambios de equipar [d] en vez de [eq] (misma clase; con tu nivel).
List<ToolDelta> farmToolCompare(FarmToolDef d, FarmToolDef eq, int level) {
  final k = FarmingRules.effectiveness(level, d.reqLevel);
  final ke = FarmingRules.effectiveness(level, eq.reqLevel);
  final a = (d.area * k + 1e-6).floor(), ae = (eq.area * ke + 1e-6).floor();
  return [
    if (a != ae) ('Área ${_area(ae)} → ${_area(a)} ${a > ae ? '▲' : '▼'}', a > ae),
    ..._deltas([
      ('Calidad', d.quality * k, eq.quality * ke),
      (d.kind == FarmToolKind.azada ? 'Cosecha doble' : 'Riego extra',
          d.extra * k, eq.extra * ke),
    ]),
  ];
}
