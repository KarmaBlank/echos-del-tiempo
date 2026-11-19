/// Parte de un tramo de 10 niveles (combo_balance.md § 1): A (primeros
/// niveles), B (medio) y C (los últimos, los que cuestan).
enum TramoPart { a, b, c }

/// Curva por tramos (serrucho) y reglas de grupo (combo_balance.md § 1 y
/// § 3.3), editables en el admin de balance (`BalanceKind.curve`).
///
/// Un tramo son [tramoSize] niveles. Dentro del tramo, la posición
/// `p = (nivel − 1) % tramoSize` (0 = primer nivel) cae en A si
/// `p < aEnd`, en B si `p < bEnd` y en C si no. Con los valores de
/// arranque: A = 1-3, B = 4-6, C = 7-10 (11-13, 14-16, 17-20…). Como las
/// zonas son de 5 niveles, la primera zona de cada tramo es A/B (Pradera,
/// Ruinas, Fortaleza…) y la segunda es C (Bosque, Cavernas, Laberinto…).
class CurveDef {
  const CurveDef({
    this.tramoSize = 10,
    this.aEnd = 3,
    this.bEnd = 6,
    this.hpSlopeAB = 0.10,
    this.hpSlopeC = 0.22,
    this.atkSlope = 0.08,
    this.commonAtkC = 0.15,
    this.eliteEveryC = 3,
    this.groupHpBase = 0.6,
    this.groupHpPer = 0.3,
    this.groupMitigation = 0.08,
    this.zoneCMitigation = 0.10,
    this.soloBossHp = 1.2,
    this.soloBossAtk = 1.0,
    this.soloEscorts = 0,
  });

  String get id => 'curva';
  String get name => 'Curva y grupo';

  /// Niveles por tramo.
  final int tramoSize;

  /// Fin (exclusivo) de A y de B como posición dentro del tramo.
  final int aEnd, bEnd;

  /// Vida: + fracción de la vida base por nivel en A/B y en C.
  final double hpSlopeAB, hpSlopeC;

  /// ATQ: + fracción por nivel (parejo, como antes).
  final double atkSlope;

  /// Comunes en zonas C: + fracción de ATQ.
  final double commonAtkC;

  /// Zonas C: 1 de cada N grupos es élite (antes ~1 de 6).
  final int eliteEveryC;

  /// Vida en cooperativo: `groupHpBase + groupHpPer × jugadores`.
  final double groupHpBase, groupHpPer;

  /// Mitigación de grupo: − fracción del daño directo por jugador después
  /// del primero; y otra − fracción en zonas C.
  final double groupMitigation, zoneCMitigation;

  /// Jefes en solitario (combo_balance.md § 3.3, ajuste del paso 5):
  /// vida y ATQ × estos factores si el grupo es de 1.
  final double soloBossHp, soloBossAtk;

  /// Jefes en solitario: cuántos de su escolta entran (el resto del grupo
  /// del catálogo se queda afuera).
  final int soloEscorts;

  TramoPart partOf(int level) {
    final size = tramoSize < 1 ? 1 : tramoSize;
    final p = (level < 1 ? 0 : level - 1) % size;
    if (p < aEnd) return TramoPart.a;
    if (p < bEnd) return TramoPart.b;
    return TramoPart.c;
  }

  bool isZoneC(int level) => level > 0 && partOf(level) == TramoPart.c;

  /// Multiplicador de vida a nivel [level] (1 en el nivel 1): suma la
  /// pendiente de cada nivel subido según su parte del tramo. Al pasar
  /// al tramo siguiente la pendiente vuelve a la de A/B.
  double hpScale(int level) {
    var s = 1.0;
    for (var l = 2; l <= level; l++) {
      s += partOf(l) == TramoPart.c ? hpSlopeC : hpSlopeAB;
    }
    return s;
  }

  double atkScale(int level) => 1 + atkSlope * (level - 1);

  /// Vida de los enemigos por tamaño del grupo.
  double groupHp(int players) => groupHpBase + groupHpPer * players.clamp(1, 4);

  /// Multiplicador de la mitigación de grupo (1 = sin mitigación).
  double groupMitigationMult(int players) =>
      (1 - groupMitigation * (players.clamp(1, 4) - 1)).clamp(0.0, 1.0);

  /// Multiplicador de la mitigación de zona C a nivel [level].
  double zoneCMult(int level) =>
      isZoneC(level) ? (1 - zoneCMitigation).clamp(0.0, 1.0) : 1.0;
}

const kCurves = {'curva': CurveDef()};
