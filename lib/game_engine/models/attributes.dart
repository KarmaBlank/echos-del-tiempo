/// Las 5 estadísticas base del prototipo original.
enum Attribute { vit, esp, agi, fue, des }

/// Cuánto suma al atributo elegido cada punto de atributo (uno por nivel;
/// progression_v2.md § 2.1).
const kAttrPerPoint = 3;

/// Topes blandos (progression_v2.md § 2.2): por encima, cada +1 crudo
/// rinde +0.5 efectivo.
const Map<Attribute, int> kAttrSoftCap = {
  Attribute.vit: 60,
  Attribute.esp: 60,
  Attribute.fue: 60,
  Attribute.des: 60,
  Attribute.agi: 40,
};

/// Lo que rinde cada +1 crudo pasado el tope.
const kAttrOverCapYield = 0.5;

/// Valor efectivo de [raw] en el atributo [a] (con tope blando).
double effectiveAttr(Attribute a, int raw) {
  final cap = kAttrSoftCap[a]!;
  return raw <= cap ? raw.toDouble() : cap + (raw - cap) * kAttrOverCapYield;
}

/// Vector de atributos de un personaje. Inmutable — subir un punto
/// devuelve una copia nueva (ver [PlayerAttributes.add]).
class PlayerAttributes {
  final Map<Attribute, int> values;

  const PlayerAttributes(this.values);

  factory PlayerAttributes.base(Map<Attribute, int> base) =>
      PlayerAttributes(Map.unmodifiable(base));

  int operator [](Attribute a) => values[a] ?? 0;

  PlayerAttributes add(Map<Attribute, int> delta) {
    final next = Map<Attribute, int>.from(values);
    delta.forEach((k, v) => next[k] = (next[k] ?? 0) + v);
    return PlayerAttributes(Map.unmodifiable(next));
  }
}
