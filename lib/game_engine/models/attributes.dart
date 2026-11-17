/// Las 5 estadísticas base del prototipo original.
enum Attribute { vit, esp, agi, fue, des }

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
