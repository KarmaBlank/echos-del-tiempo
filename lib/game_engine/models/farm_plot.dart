import 'item.dart' show ItemInstance;

/// Una parcela arada de la huerta del pueblo (farming.md § 2). Inmutable;
/// vive en `TownState.plots` con clave `"x,y"` (tile).
///
/// La huerta es compartida (farming.md § 2.4): cada labor guarda lo que
/// aportó quien la hizo (potencial de quien plantó, riegos con su calidad,
/// abono y de quién) y la cosecha sale de esos aportes más los de quien
/// cosecha.
class FarmPlot {
  const FarmPlot({
    this.composts = const {},
    this.held,
    this.seed,
    this.grow = 0,
    this.wet = 0,
    this.wetGrow = 0,
    this.fert,
    this.boost = 0,
    this.potential = 0,
    this.waterRate = 1,
    this.waterQ = 0,
    this.waterings = 0,
    this.planter,
    this.waterer,
    this.fertBy,
  });

  /// Cultivo plantado (`null` = arada y vacía).
  final String? seed;

  /// Segundos de crecimiento acumulados.
  final double grow;

  /// Segundos de riego que le quedan (0 = seca).
  final double wet;

  /// Parte de [grow] que creció regada (sube la calidad).
  final double wetGrow;

  /// Abono usado (id de `kFertilizers`; `null` = sin abono).
  final String? fert;

  /// Velocidad extra del árbol de Cultivo de quien la plantó.
  final double boost;

  /// Potencial de calidad que puso quien plantó (nivel, azada, árbol).
  final double potential;

  /// × de crecimiento del riego actual (un regador de nivel bajo riega
  /// más lento).
  final double waterRate;

  /// Calidad media de los riegos (nivel y regadera de cada regador).
  final double waterQ;
  final int waterings;

  /// Nombres de quién plantó, regó por última vez y abonó.
  final String? planter, waterer, fertBy;

  /// Composts given to a living weapon seed (profession_gear.md § 3.3):
  /// fertilizer id → bags. JSON `cp`.
  final Map<String, int> composts;
  int get compostCount => composts.values.fold(0, (a, b) => a + b);

  /// The living weapon regrowing in this plot (replant, § 3.5). JSON `it`.
  final ItemInstance? held;

  bool get planted => seed != null;
  bool get watered => wet > 0;

  FarmPlot copyWith({
    double? grow,
    double? wet,
    double? wetGrow,
    String? fert,
    double? waterRate,
    double? waterQ,
    int? waterings,
    String? waterer,
    String? fertBy,
    Map<String, int>? composts,
  }) =>
      FarmPlot(
          seed: seed,
          composts: composts ?? this.composts,
          held: held,
          grow: grow ?? this.grow,
          wet: wet ?? this.wet,
          wetGrow: wetGrow ?? this.wetGrow,
          fert: fert ?? this.fert,
          boost: boost,
          potential: potential,
          waterRate: waterRate ?? this.waterRate,
          waterQ: waterQ ?? this.waterQ,
          waterings: waterings ?? this.waterings,
          planter: planter,
          waterer: waterer ?? this.waterer,
          fertBy: fertBy ?? this.fertBy);

  static double _r(double v, [int k = 10]) => (v * k).roundToDouble() / k;

  Map<String, Object?> toJson() => {
        if (seed != null) 's': seed,
        if (grow > 0) 'g': _r(grow),
        if (wet > 0) 'w': _r(wet),
        if (wetGrow > 0) 'wg': _r(wetGrow),
        if (fert != null) 'f': fert,
        if (boost > 0) 'b': _r(boost, 100),
        if (potential != 0) 'pq': _r(potential, 100),
        if (waterRate != 1) 'wr': _r(waterRate, 100),
        if (waterQ != 0) 'wq': _r(waterQ, 100),
        if (waterings > 0) 'wn': waterings,
        if (planter != null) 'pb': planter,
        if (waterer != null) 'wb': waterer,
        if (fertBy != null) 'fb': fertBy,
        if (composts.isNotEmpty) 'cp': composts,
        if (held != null) 'it': held!.toJson(),
      };

  static FarmPlot fromJson(Object? raw) {
    if (raw is! Map) return const FarmPlot();
    double d(Object? v, [double or = 0]) =>
        v is num && v.isFinite ? v.toDouble() : or;
    String? s(Object? v) => v is String ? v : null;
    return FarmPlot(
        seed: s(raw['s']),
        grow: d(raw['g']),
        wet: d(raw['w']),
        wetGrow: d(raw['wg']),
        fert: s(raw['f']),
        boost: d(raw['b']),
        potential: d(raw['pq']),
        waterRate: d(raw['wr'], 1),
        waterQ: d(raw['wq']),
        waterings: d(raw['wn']).round(),
        planter: s(raw['pb']),
        waterer: s(raw['wb']),
        fertBy: s(raw['fb']),
        composts: raw['cp'] is Map
            ? {
                for (final e in (raw['cp'] as Map).entries)
                  if (e.value is num && (e.value as num) > 0)
                    '${e.key}': (e.value as num).toInt(),
              }
            : const {},
        held: ItemInstance.fromJson(raw['it']));
  }

  @override
  bool operator ==(Object other) =>
      other is FarmPlot &&
      other.seed == seed &&
      other.grow == grow &&
      other.wet == wet &&
      other.wetGrow == wetGrow &&
      other.fert == fert &&
      other.boost == boost &&
      other.potential == potential &&
      other.waterRate == waterRate &&
      other.waterQ == waterQ &&
      other.waterings == waterings &&
      other.planter == planter &&
      other.waterer == waterer &&
      other.fertBy == fertBy &&
      other.compostCount == compostCount &&
      composts.entries.every((e) => other.composts[e.key] == e.value) &&
      other.held?.uid == held?.uid;

  @override
  int get hashCode =>
      Object.hash(seed, grow, wet, wetGrow, fert, potential, waterings);
}

/// Clave de una parcela.
String plotKey(int x, int y) => '$x,$y';

/// (x, y) de una clave de parcela; `null` si no es válida.
(int, int)? parsePlotKey(String k) {
  final i = k.indexOf(',');
  if (i <= 0) return null;
  final x = int.tryParse(k.substring(0, i));
  final y = int.tryParse(k.substring(i + 1));
  return x == null || y == null ? null : (x, y);
}

/// Tipo de zona de una ampliación del pueblo (farming.md § 6).
enum TownZoneKind {
  lago('LAGO'),
  huerta('HUERTA');

  const TownZoneKind(this.label);
  final String label;

  static TownZoneKind? fromName(Object? n) {
    for (final v in values) {
      if (v.name == n) return v;
    }
    return null;
  }
}
