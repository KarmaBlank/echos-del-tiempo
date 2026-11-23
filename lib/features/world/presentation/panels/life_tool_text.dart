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

/// Líneas de una caña con [level] de Pesca.
List<String> rodLines(RodDef r, int level) {
  final k = FishingRules.effectiveness(level, r.reqLevel);
  final full = !TextDetail.isSummary;
  String b(String label, String full0, double v) => full
      ? '$full0: +${_pct(v)} (con tu nivel: +${_pct(v * k)})'
      : '$label +${_pct(v * k)}';
  return [
    full
        ? 'Rinde al 100 % con Pesca ${r.reqLevel} · ahora ${_pct(k)}'
        : 'Nv ${r.reqLevel} para 100 % · rinde ${_pct(k)}',
    if (r.rareBonus > 0)
      b('Peces raros', 'Chance de peces más raros', r.rareBonus),
    if (r.biteSpeed > 0) b('Picada', 'Pican más rápido', r.biteSpeed),
    if (r.zoneBonus > 0) b('Zona', 'Zona de captura más ancha', r.zoneBonus),
    if (r.rareBonus == 0 && r.biteSpeed == 0 && r.zoneBonus == 0)
      'Sin bonus: la caña básica.',
  ];
}

/// Líneas de una azada o regadera con [level] de Cultivo.
List<String> farmToolLines(FarmToolDef d, int level) {
  final k = FarmingRules.effectiveness(level, d.reqLevel);
  final full = !TextDetail.isSummary;
  final area = (d.area * k + 1e-6).floor();
  final hoe = d.kind == FarmToolKind.azada;
  return [
    full
        ? 'Rinde al 100 % con Cultivo ${d.reqLevel} · ahora ${_pct(k)}'
        : 'Nv ${d.reqLevel} para 100 % · rinde ${_pct(k)}',
    full
        ? 'Área: ${_area(d.area)}${area != d.area ? ' (con tu nivel: ${_area(area)})' : ''}'
        : 'Área: ${_area(area)}',
    if (d.quality > 0)
      full
          ? 'Calidad de cosecha: +${_pct(d.quality)} (con tu nivel: +${_pct(d.quality * k)})'
          : 'Calidad +${_pct(d.quality * k)}',
    if (d.extra > 0)
      hoe
          ? (full
              ? 'Chance de cosecha doble: ${_pct(d.extra)} (con tu nivel: ${_pct(d.extra * k)})'
              : 'Cosecha doble ${_pct(d.extra * k)}')
          : (full
              ? 'El riego dura ×${(1 + d.extra).toStringAsFixed(2)} (con tu nivel: ×${(1 + d.extra * k).toStringAsFixed(2)})'
              : 'Riego ×${(1 + d.extra * k).toStringAsFixed(2)}'),
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
