import 'dart:math' as math;
import 'dart:ui';

/// Estilo visual de cada ULT (uno por `SkillDef.id` de `kAllUltimates`).
enum UltStyle {
  finalSlash,
  cataclysm,
  meteor,
  paradox,
  arrowStorm,
  deadShot,
  bulwark,
  judgment,
  skyHammer,

  // Tipos de arma de loot v2 (`kNewUltimates`).
  spearRain,
  arcaneStorm,
  volley,
  thousandCuts,

  // ULT enemigas (docs/specs/break_and_enemy_ults.md § 2).
  acidFlood,
  endGear,
  endOfEras,
  eliteFury,

  // Jefes de la v0.2 (docs/specs/bosses.md § "v0.2").
  venomNest,
  glacialBreath,
  hollowJudgment,

  // Jefes de la v0.3 (docs/specs/bosses.md § "v0.3").
  echoChorus,
  totalEruption,
  eternalLament,
  voidCollapse,
}

/// Fase de la cinemática.
enum UltPhase { buildUp, release, recover, done }

/// Hacia dónde mira la cámara en la descarga.
enum UltFocus {
  /// Todos los objetivos, zoom base.
  targets,

  /// Un objetivo, zoom base + 1.
  single,

  /// Punto medio lanzador–objetivo, zoom base (Disparo Letal).
  line,

  /// El grupo (Baluarte), zoom base.
  party,

  /// Todo el grupo (ULT enemigas a todos: el grupo está en columna),
  /// con el alto del encuadre base y zoom base − 1.
  group,
}

/// Guion de una ULT: duraciones de las fases, impactos y peso. Datos
/// puros; los usan la escena (`battle_fx.dart`, `ult_fx.dart`) y el
/// sonido (`session_sfx.dart`) para caer en el mismo ms. Tabla en
/// docs/specs/battle_presentation.md § "Ultimates".
class UltScript {
  const UltScript({
    required this.style,
    required this.buildMs,
    required this.releaseMs,
    this.returnMs = 400,
    required this.impactMs,
    this.staggerMs = 0,
    this.preHitsMs = const [],
    this.hitStopMs = 0,
    this.shake = 8,
    this.focus = UltFocus.targets,
  });

  final UltStyle style;

  /// Preparación, descarga y regreso (ms).
  final int buildMs, releaseMs, returnMs;

  /// Impacto en el primer objetivo (ms desde el inicio).
  final int impactMs;

  /// Separación entre objetivos (ms).
  final int staggerMs;

  /// Golpes previos al impacto (solo visuales: Tajo Final).
  final List<int> preHitsMs;

  /// Congelado del reloj de la escena en el último impacto.
  final int hitStopMs;

  /// Sacudida del impacto (px del mundo, como `shake`).
  final double shake;
  final UltFocus focus;

  /// Objetivos con separación propia (el 5.º en adelante pega con el 4.º).
  static const maxStaggered = 4;

  int get releaseAt => buildMs;
  int get returnAt => buildMs + releaseMs;
  int get totalMs => buildMs + releaseMs + returnMs;

  /// Impacto en el objetivo [i] (orden de los eventos).
  int impactFor(int i) =>
      impactMs + staggerMs * i.clamp(0, maxStaggered - 1);

  /// Impacto del último de [n] objetivos (el del hit-stop).
  int lastImpact(int n) => impactFor(math.max(0, n - 1));

  UltPhase phaseAt(double a) {
    if (a < buildMs) return UltPhase.buildUp;
    if (a < returnAt) return UltPhase.release;
    if (a < totalMs) return UltPhase.recover;
    return UltPhase.done;
  }

  /// Oscurecido (0..1): sube en 200 ms, se mantiene (0.6 en la
  /// descarga respecto de la preparación lo aplica quien dibuja) y baja
  /// en el regreso.
  double darkness(double a) {
    if (a < 0) return 0;
    if (a < 200) return a / 200;
    if (a < returnAt) return 1;
    if (a < totalMs) return 1 - (a - returnAt) / returnMs;
    return 0;
  }
}

/// Los guiones por `SkillDef.id` de la ULT.
const Map<String, UltScript> kUltScripts = {
  'ult_espada': UltScript(
    style: UltStyle.finalSlash,
    buildMs: 800,
    releaseMs: 1000,
    impactMs: 1380,
    preHitsMs: [1000, 1120, 1240],
    hitStopMs: 110,
    shake: 10,
    focus: UltFocus.single,
  ),
  'ult_hacha': UltScript(
    style: UltStyle.cataclysm,
    buildMs: 900,
    releaseMs: 1100,
    impactMs: 1300,
    staggerMs: 60,
    hitStopMs: 100,
    shake: 12,
  ),
  'ult_baculo': UltScript(
    style: UltStyle.meteor,
    buildMs: 900,
    releaseMs: 1200,
    impactMs: 1350,
    staggerMs: 120,
    hitStopMs: 100,
    shake: 11,
  ),
  'ult_tomo': UltScript(
    style: UltStyle.paradox,
    buildMs: 900,
    releaseMs: 1100,
    impactMs: 1450,
    staggerMs: 50,
    hitStopMs: 120,
    shake: 8,
  ),
  'ult_arco': UltScript(
    style: UltStyle.arrowStorm,
    buildMs: 700,
    releaseMs: 1200,
    impactMs: 1300,
    staggerMs: 70,
    hitStopMs: 80,
    shake: 8,
  ),
  'ult_rifle': UltScript(
    style: UltStyle.deadShot,
    buildMs: 900,
    releaseMs: 900,
    impactMs: 1350,
    hitStopMs: 140,
    shake: 12,
    focus: UltFocus.line,
  ),
  'ult_espada_escudo': UltScript(
    style: UltStyle.bulwark,
    buildMs: 800,
    releaseMs: 1100,
    impactMs: 1150,
    staggerMs: 60,
    shake: 4,
    focus: UltFocus.party,
  ),
  'ult_maza_escudo': UltScript(
    style: UltStyle.judgment,
    buildMs: 900,
    releaseMs: 1100,
    impactMs: 1300,
    staggerMs: 90,
    hitStopMs: 90,
    shake: 9,
  ),
  'ult_martillo_escudo': UltScript(
    style: UltStyle.skyHammer,
    buildMs: 900,
    releaseMs: 1000,
    impactMs: 1300,
    hitStopMs: 150,
    shake: 14,
    focus: UltFocus.single,
  ),
  // ---- loot v2 (`kNewUltimates`) ----
  'ult_lanza': UltScript(
    style: UltStyle.spearRain,
    buildMs: 800,
    releaseMs: 1100,
    impactMs: 1300,
    staggerMs: 80,
    hitStopMs: 90,
    shake: 10,
  ),
  'ult_varita': UltScript(
    style: UltStyle.arcaneStorm,
    buildMs: 800,
    releaseMs: 1200,
    impactMs: 1350,
    staggerMs: 60,
    hitStopMs: 90,
    shake: 9,
  ),
  'ult_ballesta': UltScript(
    style: UltStyle.volley,
    buildMs: 900,
    releaseMs: 900,
    impactMs: 1300,
    hitStopMs: 150,
    shake: 13,
    focus: UltFocus.line,
  ),
  'ult_dagas': UltScript(
    style: UltStyle.thousandCuts,
    buildMs: 700,
    releaseMs: 1100,
    impactMs: 1500,
    preHitsMs: [950, 1030, 1110, 1190, 1270, 1350, 1420],
    hitStopMs: 130,
    shake: 11,
    focus: UltFocus.single,
  ),
  // ---- ascensiones (docs/specs/ascension.md § 4): reusan un estilo
  // visual, teñido con el color de la ascensión (kSkillColors). ----
  'ult_berserker': UltScript(
    style: UltStyle.thousandCuts,
    buildMs: 900,
    releaseMs: 1100,
    impactMs: 1550,
    preHitsMs: [1050, 1150, 1250, 1350, 1450],
    hitStopMs: 150,
    shake: 13,
    focus: UltFocus.single,
  ),
  'ult_senorGuerra': UltScript(
    style: UltStyle.cataclysm,
    buildMs: 900,
    releaseMs: 1100,
    impactMs: 1300,
    staggerMs: 60,
    hitStopMs: 110,
    shake: 12,
  ),
  'ult_cronomante': UltScript(
    style: UltStyle.paradox,
    buildMs: 900,
    releaseMs: 1200,
    impactMs: 1500,
    staggerMs: 50,
    hitStopMs: 160,
    shake: 9,
  ),
  'ult_elementalista': UltScript(
    style: UltStyle.meteor,
    buildMs: 900,
    releaseMs: 1200,
    impactMs: 1350,
    staggerMs: 110,
    hitStopMs: 110,
    shake: 12,
  ),
  'ult_francotirador': UltScript(
    style: UltStyle.deadShot,
    buildMs: 900,
    releaseMs: 1000,
    impactMs: 1400,
    hitStopMs: 180,
    shake: 14,
    focus: UltFocus.line,
  ),
  'ult_trampero': UltScript(
    style: UltStyle.arrowStorm,
    buildMs: 800,
    releaseMs: 1200,
    impactMs: 1300,
    staggerMs: 80,
    hitStopMs: 90,
    shake: 10,
  ),
  'ult_templario': UltScript(
    style: UltStyle.judgment,
    buildMs: 900,
    releaseMs: 1100,
    impactMs: 1300,
    staggerMs: 90,
    hitStopMs: 120,
    shake: 11,
  ),
  'ult_guardian': UltScript(
    style: UltStyle.bulwark,
    buildMs: 900,
    releaseMs: 1100,
    impactMs: 1150,
    staggerMs: 60,
    shake: 5,
    focus: UltFocus.party,
  ),
};

/// Guion de respaldo (ULT desconocida): el de Tajo Final.
const UltScript kDefaultUltScript = UltScript(
  style: UltStyle.finalSlash,
  buildMs: 800,
  releaseMs: 1000,
  impactMs: 1380,
  preHitsMs: [1000, 1120, 1240],
  hitStopMs: 110,
  shake: 10,
  focus: UltFocus.single,
);

/// Los guiones de las ULT enemigas por `EnemyUltDef.id`
/// (docs/specs/battle_presentation.md § "ULT enemigas").
const Map<String, UltScript> kEnemyUltScripts = {
  'eult_diluvio': UltScript(
    style: UltStyle.acidFlood,
    buildMs: 900,
    releaseMs: 1100,
    impactMs: 1380,
    staggerMs: 70,
    hitStopMs: 90,
    shake: 10,
    focus: UltFocus.group,
  ),
  'eult_engranaje': UltScript(
    style: UltStyle.endGear,
    buildMs: 900,
    releaseMs: 1000,
    impactMs: 1400,
    hitStopMs: 130,
    shake: 12,
    focus: UltFocus.single,
  ),
  'eult_finEras': UltScript(
    style: UltStyle.endOfEras,
    buildMs: 1000,
    releaseMs: 1100,
    impactMs: 1500,
    staggerMs: 60,
    hitStopMs: 140,
    shake: 14,
    focus: UltFocus.group,
  ),
  'eult_nido': UltScript(
    style: UltStyle.venomNest,
    buildMs: 900,
    releaseMs: 1100,
    impactMs: 1350,
    staggerMs: 70,
    hitStopMs: 100,
    shake: 10,
    focus: UltFocus.group,
  ),
  'eult_aliento': UltScript(
    style: UltStyle.glacialBreath,
    buildMs: 1000,
    releaseMs: 1100,
    impactMs: 1420,
    staggerMs: 60,
    hitStopMs: 120,
    shake: 12,
    focus: UltFocus.group,
  ),
  'eult_juicio': UltScript(
    style: UltStyle.hollowJudgment,
    buildMs: 900,
    releaseMs: 1000,
    impactMs: 1400,
    hitStopMs: 160,
    shake: 15,
    focus: UltFocus.single,
  ),
  // v0.3 (docs/specs/battle_presentation.md § "ULT de los jefes v0.3").
  'eult_coro': UltScript(
    style: UltStyle.echoChorus,
    buildMs: 1000,
    releaseMs: 1100,
    impactMs: 1450,
    staggerMs: 80,
    hitStopMs: 110,
    shake: 11,
    focus: UltFocus.group,
  ),
  'eult_erupcion': UltScript(
    style: UltStyle.totalEruption,
    buildMs: 1000,
    releaseMs: 1100,
    impactMs: 1400,
    staggerMs: 70,
    hitStopMs: 130,
    shake: 15,
    focus: UltFocus.group,
  ),
  'eult_lamento': UltScript(
    style: UltStyle.eternalLament,
    buildMs: 1000,
    releaseMs: 1100,
    impactMs: 1450,
    staggerMs: 70,
    hitStopMs: 120,
    shake: 12,
    focus: UltFocus.group,
  ),
  'eult_colapsoVacio': UltScript(
    style: UltStyle.voidCollapse,
    buildMs: 1000,
    releaseMs: 1100,
    impactMs: 1500,
    staggerMs: 60,
    hitStopMs: 150,
    shake: 15,
    focus: UltFocus.group,
  ),
  'eult_furia': UltScript(
    style: UltStyle.eliteFury,
    buildMs: 700,
    releaseMs: 900,
    impactMs: 1150,
    preHitsMs: [1000, 1070],
    hitStopMs: 120,
    shake: 12,
    focus: UltFocus.single,
  ),
};

/// La ULT es de un enemigo.
bool isEnemyUlt(String? ultId) => kEnemyUltScripts.containsKey(ultId);

UltScript ultScriptFor(String? ultId) =>
    kUltScripts[ultId] ?? kEnemyUltScripts[ultId] ?? kDefaultUltScript;

/// Una vista de cámara: centro (px del mundo) y zoom (px de pantalla
/// por px del mundo).
class CameraView {
  const CameraView(this.center, this.zoom);

  final Offset center;
  final double zoom;

  static CameraView lerp(CameraView a, CameraView b, double k) => CameraView(
      Offset.lerp(a.center, b.center, k)!, a.zoom + (b.zoom - a.zoom) * k);

  @override
  String toString() => 'CameraView($center, ×$zoom)';
}

double _smooth(double x) {
  final t = x.clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// Cámara de la cinemática a la edad [a] (docs/specs/battle_presentation.md
/// § "Cámara de la cinemática"). [base] = encuadre normal; [caster] y
/// [targets] en px del mundo (pies); [party] = pies del grupo.
CameraView ultCameraAt(
  UltScript s,
  double a, {
  required CameraView base,
  required Offset caster,
  required List<Offset> targets,
  List<Offset> party = const [],
}) {
  final bz = base.zoom.roundToDouble();
  final casterView = CameraView(
      caster.translate(0, -12), bz + math.max(1, (0.6 * bz).round()));
  Offset centroid(List<Offset> l) {
    if (l.isEmpty) return base.center;
    var x = 0.0, y = 0.0;
    for (final p in l) {
      x += p.dx;
      y += p.dy;
    }
    return Offset(x / l.length, y / l.length - 10);
  }

  final CameraView releaseView;
  switch (s.focus) {
    case UltFocus.single:
      releaseView = CameraView(
          targets.isEmpty ? base.center : targets.first.translate(0, -10),
          bz + 1);
    case UltFocus.line:
      final t = targets.isEmpty ? caster : targets.first;
      releaseView = CameraView(
          Offset((caster.dx + t.dx) / 2, (caster.dy + t.dy) / 2 - 10), bz);
    case UltFocus.party:
      releaseView = CameraView(centroid(party.isEmpty ? [caster] : party), bz);
    case UltFocus.targets:
      releaseView = CameraView(
          targets.isEmpty ? base.center : centroid(targets), bz);
    case UltFocus.group:
      // Un paso más lejos: el grupo en columna entra entero entre las
      // barras de cine, con sus números arriba.
      final c = targets.isEmpty ? base.center : centroid(targets);
      releaseView =
          CameraView(Offset(c.dx, base.center.dy), math.max(1, bz - 1));
  }

  final inMs = math.min(350.0, 0.45 * s.buildMs);
  if (a < 0) return base;
  if (a < s.buildMs) {
    return CameraView.lerp(base, casterView, _smooth(a / inMs));
  }
  if (a < s.returnAt) {
    var v = CameraView.lerp(
        casterView, releaseView, _smooth((a - s.buildMs) / 250));
    final dt = a - s.impactMs;
    if (dt >= 0 && dt < 180) {
      v = CameraView(v.center, v.zoom + 0.15 * (1 - dt / 180));
    }
    return v;
  }
  if (a < s.totalMs) {
    return CameraView.lerp(
        releaseView, base, _smooth((a - s.returnAt) / s.returnMs));
  }
  return base;
}
