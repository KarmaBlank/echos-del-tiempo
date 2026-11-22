/// Lo que se ve de la pesca de un jugador en el mapa (fishing.md § 7):
/// en qué etapa está y dónde quedó la boya. Viaja en el snapshot (`fl`)
/// para que los demás vean la caña, la línea y la boya.
enum FishLineStage {
  /// Caña en la mano, sin lance.
  rod,

  /// Cargando el lance (medidor sobre el personaje).
  charging,

  /// Boya en el agua, esperando.
  line,

  /// Picada: "!" sobre el personaje y la boya hundida.
  bite,

  /// Pelea: la boya sacude.
  reel,
}

class FishLine {
  const FishLine(this.stage, {this.bx = 0, this.by = 0});

  final FishLineStage stage;

  /// Boya en px del mapa (solo con [hasBobber]).
  final double bx, by;

  bool get hasBobber =>
      stage == FishLineStage.line ||
      stage == FishLineStage.bite ||
      stage == FishLineStage.reel;

  List<Object> toJson() => [
        stage.index,
        if (hasBobber) ...[bx, by]
      ];

  static FishLine? fromJson(Object? raw) {
    if (raw is! List || raw.isEmpty || raw.first is! num) return null;
    final i = (raw.first as num).toInt();
    if (i < 0 || i >= FishLineStage.values.length) return null;
    final st = FishLineStage.values[i];
    double at(int k) =>
        raw.length > k && raw[k] is num ? (raw[k] as num).toDouble() : 0;
    return FishLine(st, bx: at(1), by: at(2));
  }

  @override
  bool operator ==(Object other) =>
      other is FishLine &&
      other.stage == stage &&
      other.bx == bx &&
      other.by == by;

  @override
  int get hashCode => Object.hash(stage, bx, by);
}
