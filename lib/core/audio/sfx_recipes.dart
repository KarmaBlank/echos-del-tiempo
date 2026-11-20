import '../../game_engine/data/skill_variants_catalog.dart';
import '../../game_engine/data/branch_ults_catalog.dart' show kBranchUltLooks;
import '../../game_engine/data/elite_ults_catalog.dart' show kEliteUltLooks;
import 'sfx_catalog.dart';

// Recetas del diseño de sonido de combate (docs/specs/audio.md
// § "Diseño de sonido de combate"). Los volúmenes de cada voz son
// relativos dentro del efecto: el nivel final lo fija `SfxDef.peak`.

const _sq = Waveform.square;
const _pu = Waveform.pulse;
const _saw = Waveform.sawtooth;
const _tri = Waveform.triangle;
const _sin = Waveform.sine;

/// Una voz tonal.
SfxTone _t(
  double f,
  double d, {
  Waveform w = _sq,
  double? to,
  double v = 0.5,
  double at = 0,
  double a = 0,
  double h = 0,
  double vr = 0,
  double vd = 0,
  double lp = 0,
  int crush = 0,
}) =>
    SfxTone(f, d,
        wave: w,
        endFrequency: to,
        volume: v,
        delay: at,
        attack: a,
        hold: h,
        vibratoRate: vr,
        vibratoDepth: vd,
        lowpass: lp,
        crush: crush);

/// Una voz de ruido (LFSR con reloj [clock] Hz).
SfxTone _n(
  double clock,
  double d, {
  double? to,
  double v = 0.5,
  double at = 0,
  double a = 0,
  double h = 0,
  double lp = 0,
  int crush = 0,
  int seed = 1,
}) =>
    SfxTone(clock, d,
        wave: Waveform.noise,
        endFrequency: to,
        volume: v,
        delay: at,
        attack: a,
        hold: h,
        lowpass: lp,
        crush: crush,
        seed: seed);

/// [voices] desplazadas / transpuestas / estiradas.
List<SfxTone> _x(List<SfxTone> voices,
        {double dt = 0, double p = 1, double l = 1, double g = 1}) =>
    [for (final v in voices) v.shifted(dt: dt, pitch: p, len: l, gain: g)];

/// Notas en cadena (arpegio).
List<SfxTone> _arp(List<double> notes,
        {double step = 0.05,
        double d = 0.1,
        Waveform w = _tri,
        double v = 0.4,
        double at = 0}) =>
    [
      for (var i = 0; i < notes.length; i++)
        _t(notes[i], d, w: w, v: v, at: at + i * step),
    ];

// ---------------------------------------------------------------- bases

List<SfxTone> _swingBlade([double p = 1, double l = 1]) => [
      _n(9000 * p, 0.12 * l, to: 3000 * p, a: 0.02 * l, lp: 6000 * p, v: 0.5),
      _t(1400 * p, 0.05 * l, w: _pu, to: 700 * p, v: 0.15),
    ];

List<SfxTone> _swingHeavy([double p = 1, double l = 1]) => [
      _n(4000 * p, 0.2 * l, to: 1200 * p, a: 0.05 * l, lp: 2200 * p, v: 0.6),
      _t(160 * p, 0.16 * l, w: _tri, to: 90 * p, v: 0.5),
    ];

List<SfxTone> _whoosh([double p = 1, double l = 1, double at = 0]) => [
      _n(5000 * p, 0.14 * l, to: 9000 * p, lp: 6000 * p, a: 0.03 * l, v: 0.45, at: at),
    ];

List<SfxTone> _fire([double p = 1, double l = 1, int seed = 1]) => [
      _n(1500 * p, 0.3 * l, to: 6000 * p, lp: 3500 * p, a: 0.12 * l, v: 0.6, seed: seed),
      _t(110 * p, 0.3 * l, w: _saw, to: 220 * p, a: 0.05 * l, v: 0.25),
    ];

List<SfxTone> _crackle([double l = 1, double at = 0]) => [
      _n(11000, 0.18 * l, crush: 3, v: 0.3, seed: 7, at: at),
    ];

List<SfxTone> _ice([double p = 1, double l = 1]) => [
      _t(2093 * p, 0.25 * l, w: _tri, v: 0.4),
      _t(2637 * p, 0.25 * l, w: _tri, at: 0.05 * l, v: 0.35),
      _t(3136 * p, 0.3 * l, w: _tri, at: 0.1 * l, v: 0.3),
      _t(1500 * p, 0.2 * l, w: _sin, to: 3000 * p, v: 0.2),
    ];

List<SfxTone> _bubbles([double p = 1, double l = 1, int n = 3]) => [
      for (var i = 0; i < n; i++)
        _t((520 - i * 40) * p, 0.07 * l,
            w: _sq, to: (260 - i * 20) * p, at: i * 0.06 * l, v: 0.35),
      _n(1500 * p, 0.2 * l, lp: 700 * p, v: 0.3),
    ];

List<SfxTone> _holy([double p = 1, double l = 1]) => [
      _t(1047 * p, 0.35 * l, w: _sin, vr: 7, vd: 0.01, v: 0.4),
      _t(1568 * p, 0.35 * l, w: _sin, at: 0.02 * l, vr: 7, vd: 0.01, v: 0.35),
      _t(2093 * p, 0.35 * l, w: _sin, at: 0.04 * l, v: 0.3),
    ];

List<SfxTone> _rumble([double p = 1, double l = 1]) => [
      _n(900 * p, 0.45 * l, lp: 400 * p, a: 0.03 * l, v: 0.6),
      _t(55 * p, 0.45 * l, w: _sin, to: 35 * p, v: 0.6),
      _t(110 * p, 0.3 * l, w: _tri, to: 60 * p, crush: 3, v: 0.3),
    ];

List<SfxTone> _shieldRing([double p = 1]) => [
      _t(220 * p, 0.05, w: _sq, v: 0.3),
      _n(8000 * p, 0.05, v: 0.3),
      _t(1500 * p, 0.3, w: _tri, v: 0.3),
      _t(3790 * p, 0.2, w: _sin, v: 0.12),
    ];

/// Cúpula de escudos del Guardián (la vieja Égida Grupal): Fortaleza y
/// la firma de su ULT.
List<SfxTone> _guardianDome() => [
      ..._shieldRing(0.7),
      for (final f in [523.0, 784.0, 1047.0]) _t(f, 0.45, w: _tri, at: 0.15, v: 0.2),
    ];

List<SfxTone> _wind([double p = 1, double l = 1]) => [
      _n(2500 * p, 0.6 * l, to: 5000 * p, lp: 3000 * p, a: 0.2 * l, v: 0.5, seed: 11),
    ];

List<SfxTone> _zap([double p = 1]) => [
      _n(20000, 0.12, crush: 2, v: 0.35, seed: 5),
      _t(2000 * p, 0.15, w: _sq, vr: 30, vd: 0.25, v: 0.2),
    ];

// -------------------------------------------------------------- tablas

/// Arranque por tipo de arma.
const Map<String, String> kWeaponStartSfx = {
  'espada': Sfx.swingBlade,
  'espada+escudo': Sfx.swingBlade,
  'hacha': Sfx.swingHeavy,
  'maza+escudo': Sfx.swingHeavy,
  'martillo+escudo': Sfx.swingHeavy,
  'arco': Sfx.shotBow,
  'rifle': Sfx.shotRifle,
  'báculo': Sfx.shotStaff,
  'tomo': Sfx.shotTome,
  // Tipos nuevos de loot v2 (docs/specs/loot.md § 8).
  'lanza': Sfx.swingSpear,
  'dagas': Sfx.swingDaggers,
  'varita': Sfx.shotWand,
  'ballesta': Sfx.shotCrossbow,
};

/// Impacto físico por tipo de arma.
const Map<String, String> kWeaponImpactSfx = {
  'espada': Sfx.impactSlash,
  'espada+escudo': Sfx.impactSlash,
  'hacha': Sfx.impactBlunt,
  'maza+escudo': Sfx.impactBlunt,
  'martillo+escudo': Sfx.impactBlunt,
  'arco': Sfx.impactArrow,
  'rifle': Sfx.impactBullet,
  'báculo': Sfx.impactArcane,
  'tomo': Sfx.impactArcane,
  'lanza': Sfx.impactPierce,
  'dagas': Sfx.impactDagger,
  'varita': Sfx.impactWand,
  'ballesta': Sfx.impactBolt,
};

/// Firma de cada habilidad de `kSkills` (sin el prefijo `skill.`).
final Map<String, List<SfxTone>> _kBaseSkillVoices = {
  // ---- Quebrar base (combo_balance.md § 5.1): golpe seco y crujido ----
  'quebrar': [
    ..._swingBlade(0.7, 0.9),
    _n(2600, 0.06, crush: 3, v: 0.5, at: 0.08, seed: 211),
  ],
  'quebrarArcano': [
    _n(4200, 0.08, lp: 3000, v: 0.4, seed: 223),
    _n(2600, 0.06, crush: 3, v: 0.5, at: 0.09, seed: 227),
  ],
  // ---- combo de clase (combo_balance.md § 5.2) ----
  'brasaEco': [..._swingBlade(1.3, 0.6), ..._x(_fire(1.2, 0.5, 5), dt: 0.04)],
  'ascuaEco': [..._fire(1.6, 0.4, 11), ..._crackle(0.3)],
  'puaEco': [..._whoosh(1.15, 0.5), ..._x(_bubbles(1.3, 0.5, 2), dt: 0.04)],
  'selloInstante': [
    _t(1400, 0.06, w: _tri, to: 2100, v: 0.35),
    _t(700, 0.25, w: _pu, to: 520, vr: 7, vd: 0.08, v: 0.25, at: 0.05),
  ],
  'ignicionEco': [
    ..._fire(0.9, 1.0, 7),
    _n(2200, 0.12, crush: 2, v: 0.45, at: 0.1, seed: 233),
  ],
  'ponzonaEco': [
    ..._whoosh(0.95, 0.8),
    ..._x(_bubbles(0.85, 0.9, 6), dt: 0.06),
    _n(1800, 0.1, crush: 2, v: 0.4, at: 0.12, seed: 239),
  ],
  // ---- corte ----
  'giro': [..._swingBlade(1, 0.8), ..._x(_swingBlade(1.15, 0.8), dt: 0.1)],
  'embestida': [
    for (final at in [0.0, 0.06, 0.12]) _n(1500, 0.03, lp: 800, v: 0.5, at: at),
    ..._x(_swingBlade(0.8, 1.2), dt: 0.15),
  ],
  'estocada': [
    _n(12000, 0.06, to: 6000, v: 0.5),
    _t(1800, 0.08, w: _pu, to: 2400, v: 0.25),
  ],
  'tajoT': [
    ..._swingBlade(0.7, 1.6),
    _t(600, 0.4, w: _tri, to: 300, vr: 12, vd: 0.15, v: 0.3),
  ],
  'sagrado': [..._swingBlade(1.2), ..._x(_holy(1.2, 0.7), dt: 0.05)],
  'golpeEscudo': [..._shieldRing(0.9), _n(3000, 0.08, lp: 1500, v: 0.4)],
  // ---- corte elemental ----
  'ignea': [..._swingBlade(), ..._x(_fire(1, 0.8), dt: 0.03)],
  'tajoCarmesi': [
    ..._swingBlade(0.9, 1.1),
    ..._x(_fire(0.85, 0.9, 3), dt: 0.03),
    ..._crackle(0.8, 0.1),
  ],
  'corteGlacial': [..._swingBlade(1.1), ..._x(_ice(1, 0.7), dt: 0.05)],
  'tajoOcaso': [
    ..._swingBlade(0.7, 1.2),
    ..._x(_bubbles(0.7), dt: 0.08),
    _t(90, 0.3, w: _saw, v: 0.2),
  ],
  'hendir': [..._swingHeavy(1.1, 0.8), ..._x(_bubbles(), dt: 0.08)],
  // ---- pesado ----
  'sismo': _rumble(1, 1.4),
  'temblor': [
    ..._rumble(0.9, 1.2),
    _t(60, 0.5, w: _sin, vr: 12, vd: 0.2, v: 0.4),
  ],
  'aplastar': [
    _t(120, 0.15, w: _sin, to: 40, v: 0.7),
    _n(3000, 0.1, lp: 1500, v: 0.5),
    _t(80, 0.2, w: _tri, crush: 3, v: 0.3),
  ],
  'juicio': [..._rumble(1, 1.3), ..._x(_holy(1, 1.2), dt: 0.05)],
  'erupcion': [..._rumble(0.8, 1.3), ..._fire(0.8, 1.3, 9), ..._crackle(1, 0.15)],
  'vendaval': [..._wind(), ..._x(_ice(1.2, 0.8), dt: 0.2)],
  // ---- flecha / disparo ----
  'rafaga': [for (final at in [0.0, 0.07, 0.14]) ..._x(_whoosh(1, 0.6), dt: at)],
  'lluvia': [
    for (var i = 0; i < 5; i++) ..._x(_whoosh(1.3 - i * 0.08, 0.7), dt: i * 0.06),
  ],
  'certero': [
    _t(900, 0.08, w: _tri, to: 1400, v: 0.4),
    _n(9000, 0.12, to: 12000, lp: 8000, v: 0.4),
  ],
  'aturdir': [..._whoosh(0.9), _t(1100, 0.3, w: _tri, vr: 9, vd: 0.2, v: 0.3, at: 0.05)],
  'rayoF': [..._whoosh(1.1), ..._zap()],
  'venenosa': [..._whoosh(), ..._x(_bubbles(1.2, 0.7), dt: 0.05)],
  'saeta': [..._whoosh(1.05), ..._x(_ice(1.2, 0.6), dt: 0.04)],
  'ceroAbs': [..._whoosh(0.8), ..._x(_ice(0.75, 1.2), dt: 0.04)],
  'sombra': [
    _n(3000, 0.18, to: 1500, lp: 2500, v: 0.45),
    _t(110, 0.25, w: _pu, vr: 5, vd: 0.1, v: 0.3),
  ],
  'flechaSolar': [..._whoosh(1.2), ..._x(_holy(1.3, 0.7), dt: 0.04)],
  'metralla': [
    for (final at in [0.0, 0.05, 0.1, 0.15]) _n(15000, 0.03, v: 0.5, at: at, seed: 3),
    ..._x(_bubbles(1, 0.6), dt: 0.1),
  ],
  'perfora': [
    _n(18000, 0.04, v: 0.7),
    _n(8000, 0.3, to: 14000, lp: 9000, a: 0.05, v: 0.4),
    _t(90, 0.25, w: _sq, to: 40, v: 0.4, at: 0.05),
  ],
  // ---- fuego ----
  'chispa': [..._fire(1.4, 0.6), ..._crackle(0.5)],
  'bola': _fire(),
  'llamarada': [..._fire(1, 1.4), ..._crackle(1.2, 0.15)],
  'infierno': [
    ..._fire(0.7, 1.8),
    ..._x(_fire(1.2, 1.4, 3), dt: 0.08),
    _t(55, 0.6, w: _saw, v: 0.3),
  ],
  'consagrar': [..._fire(1.1), ..._x(_holy(), dt: 0.1)],
  // ---- hielo ----
  'lanzaH': [..._ice(), _t(1500, 0.2, w: _sin, to: 3200, v: 0.3)],
  'ventisca': [..._wind(1.2, 1.2), ..._x(_ice(1, 1.6), dt: 0.1)],
  // ---- veneno ----
  'dardo': [..._bubbles(1.2, 0.7), _n(7000, 0.06, v: 0.4)],
  'niebla': [..._bubbles(0.9, 1.4, 4), _n(1200, 0.5, lp: 600, a: 0.15, v: 0.4)],
  'plaga': [..._bubbles(0.7, 1.8, 5), _t(80, 0.6, w: _saw, vr: 4, vd: 0.1, v: 0.3)],
  // ---- arcano / tiempo ----
  'detener': [
    for (final at in [0.0, 0.12, 0.24, 0.36]) _t(2000, 0.015, w: _sq, v: 0.4, at: at),
    _t(900, 0.5, w: _pu, to: 150, crush: 4, vr: 6, vd: 0.05, v: 0.35),
  ],
  'descarga': [
    ..._zap(),
    _t(1500, 0.25, w: _sq, vr: 40, vd: 0.2, v: 0.2, at: 0.05),
  ],
  // ---- sagrado ----
  'lanzaLuz': [_t(500, 0.25, w: _sin, to: 2000, v: 0.4), ..._x(_holy(), dt: 0.1)],
  // ---- cura ----
  'cura': _arp([784, 988, 1175, 1568]),
  'curaM': _arp([523, 659, 784, 1047, 1319, 2093]),
  'sanar': _arp([659, 784, 988], step: 0.07, d: 0.14, w: _sin),
  'bendicion': [..._arp([880, 1109, 1319, 1760]), ..._x(_holy(1, 0.8), dt: 0.15)],
  // ---- mejora / escudo ----
  'prisa': _arp([523, 659, 784, 1047, 1319, 1568, 2093],
      step: 0.035, d: 0.06, w: _sq, v: 0.3),
  // Fortaleza (kit del Guardián): el golpe de escudo de siempre y la
  // cúpula de la vieja Égida Grupal, que absorbió.
  'fortaleza': [
    _t(196, 0.12, w: _sq, v: 0.4),
    _t(262, 0.18, w: _sq, v: 0.4, at: 0.1),
    ..._x(_shieldRing(), dt: 0.15),
    ..._x(_guardianDome(), dt: 0.15, g: 0.8),
  ],
  'proteccion': [
    _t(300, 0.3, w: _tri, to: 900, v: 0.4),
    for (final f in [784.0, 988.0, 1175.0]) _t(f, 0.4, w: _sin, v: 0.25, at: 0.2),
  ],
  'escudoFe': [..._shieldRing(1.2), ..._x(_holy(1, 0.8), dt: 0.08)],
  'aura': [
    for (final f in [523.0, 659.0, 784.0])
      _t(f, 0.6, w: _sin, a: 0.15, vr: 3, vd: 0.01, v: 0.3),
  ],
  // ---- provocar ----
  'provocar': [
    _t(150, 0.35, w: _saw, vr: 30, vd: 0.15, v: 0.5),
    _t(300, 0.3, w: _sq, vr: 30, vd: 0.1, v: 0.2),
  ],
  // ---- loot v2: lanza, varita, ballesta y dagas ----
  'perforar': [
    _n(14000, 0.05, to: 7000, v: 0.55),
    _t(1300, 0.1, w: _pu, to: 2600, v: 0.25),
  ],
  'barrido': [..._swingHeavy(1.3, 0.9), ..._x(_swingBlade(0.9), dt: 0.08)],
  'empalar': [
    _n(10000, 0.05, to: 4000, v: 0.6),
    _t(140, 0.2, w: _tri, to: 60, v: 0.5, at: 0.04),
    _t(900, 0.25, w: _tri, vr: 9, vd: 0.2, v: 0.25, at: 0.08),
  ],
  'misil': [_t(1200, 0.12, w: _sq, to: 2400, v: 0.3), ..._x(_zap(1.3), dt: 0.05)],
  'escarchaFugaz': [..._whoosh(1.2, 0.7), ..._x(_ice(1.4, 0.5), dt: 0.03)],
  'rayoArcano': [
    ..._zap(0.8),
    _t(700, 0.3, w: _saw, to: 1400, vr: 20, vd: 0.1, v: 0.25),
  ],
  'virote': [
    _n(16000, 0.03, v: 0.6),
    ..._x(_whoosh(0.7, 1.1), dt: 0.02),
    _t(70, 0.2, w: _sq, to: 35, v: 0.4, at: 0.08),
  ],
  'viroteIgneo': [..._whoosh(0.85), ..._x(_fire(1.15, 0.7, 5), dt: 0.05)],
  'tajoGemelo': [
    ..._swingBlade(1.3, 0.6),
    ..._x(_swingBlade(1.45, 0.6), dt: 0.07),
  ],
  'abanico': [
    for (final at in [0.0, 0.04, 0.08, 0.12, 0.16]) ..._x(_whoosh(1.4, 0.4), dt: at),
    ..._x(_bubbles(1.3, 0.5), dt: 0.12),
  ],
  // ---- kit de las ascensiones (docs/specs/ascension.md § 4) ----
  // Berserker: corte con latido; torbellino rojo.
  'sangria': [
    _t(65, 0.12, w: _sin, to: 45, v: 0.7),
    ..._x(_swingBlade(0.75, 1.1), dt: 0.08),
    _t(220, 0.2, w: _saw, to: 110, crush: 4, v: 0.3, at: 0.1),
  ],
  'torbellino': [
    for (final at in [0.0, 0.08, 0.16, 0.24]) ..._x(_swingHeavy(1.2, 0.6), dt: at),
    _t(150, 0.4, w: _saw, to: 300, vr: 8, vd: 0.1, v: 0.25),
  ],
  // Señor de la Guerra: grito y estandarte.
  'gritoGuerra': [
    _t(180, 0.45, w: _saw, to: 260, vr: 9, vd: 0.06, a: 0.05, v: 0.5),
    _t(360, 0.4, w: _sq, to: 520, vr: 9, vd: 0.05, a: 0.05, v: 0.2),
    _n(3000, 0.3, lp: 2000, a: 0.05, v: 0.3, seed: 31),
  ],
  'estandarte': [
    _t(392, 0.18, w: _sq, v: 0.35),
    _t(523, 0.18, w: _sq, v: 0.35, at: 0.14),
    _t(659, 0.35, w: _sq, v: 0.35, at: 0.28),
    _n(2000, 0.3, to: 600, lp: 1500, v: 0.2, at: 0.05, seed: 32),
  ],
  // Cronomante: reloj que se acelera y grieta que tira para atrás.
  'aceleron': [
    for (var k = 0; k < 8; k++) _t(1800 + k * 120.0, 0.015, w: _sq, at: k * 0.045, v: 0.35),
    _t(300, 0.4, w: _sin, to: 1800, a: 0.3, v: 0.3),
  ],
  'grietaTemporal': [
    _t(1400, 0.45, w: _pu, to: 180, crush: 4, vr: 5, vd: 0.06, v: 0.35),
    for (final at in [0.05, 0.2, 0.35]) _t(2400, 0.015, w: _sq, at: at, v: 0.3),
  ],
  // Elementalista: tres elementos en fila; estallido.
  'prismaElemental': [
    ..._x(_fire(1.3, 0.5, 33), g: 0.7),
    ..._x(_ice(1.1, 0.5), dt: 0.1),
    ..._x(_bubbles(1.2, 0.5), dt: 0.2),
  ],
  'detonar': [
    _t(800, 0.15, w: _sq, to: 2400, v: 0.3),
    _n(1200, 0.4, lp: 900, at: 0.12, v: 0.7, seed: 34),
    _t(70, 0.4, w: _sin, to: 30, at: 0.12, v: 0.7),
  ],
  // Francotirador: estampido largo; respiración y mira.
  'tiroCabeza': [
    _n(20000, 0.03, v: 0.8, seed: 35),
    _n(2500, 0.45, to: 600, lp: 2000, v: 0.55, seed: 36),
    _t(2637, 0.3, w: _sin, to: 2600, at: 0.05, v: 0.2),
  ],
  'apuntar': [
    _n(1500, 0.4, to: 800, lp: 900, a: 0.15, v: 0.3, seed: 37),
    _t(3136, 0.02, w: _sq, at: 0.3, v: 0.4),
    _t(3951, 0.12, w: _sin, at: 0.33, v: 0.3),
  ],
  // Trampero: resortes y red.
  'trampaPuas': [
    for (final at in [0.0, 0.07, 0.14]) _t(900, 0.05, w: _sq, to: 2200, at: at, v: 0.3),
    _n(8000, 0.08, crush: 3, at: 0.2, v: 0.4, seed: 38),
    _t(180, 0.15, w: _tri, to: 90, at: 0.2, v: 0.4),
  ],
  'redCaza': [
    ..._whoosh(0.9, 1.2),
    _n(6000, 0.25, to: 2000, lp: 3000, at: 0.1, v: 0.35, seed: 39),
    ..._x(_bubbles(0.9, 0.6), dt: 0.15),
  ],
  // Templario: campanazo y luz que ciega.
  'castigo': [
    _t(784, 0.4, w: _sin, a: 0.003, vr: 5, vd: 0.004, v: 0.4),
    _t(2093, 0.3, w: _sin, a: 0.003, v: 0.2),
    _t(110, 0.25, w: _sin, to: 50, v: 0.5),
  ],
  'luzCegadora': [
    _t(600, 0.35, w: _sin, to: 2400, v: 0.35),
    ..._x(_holy(1.4, 1.2), dt: 0.12),
    _n(12000, 0.1, at: 0.3, v: 0.3, seed: 40),
  ],
  // Guardián: su kit es Protección, Fortaleza y Aura Restauradora (arriba).
};

/// Firma de cada habilidad de `kSkills`: las propias y las variantes v0.5,
/// que suenan como la habilidad a la que se parecen (`kSkillLooks`).
final Map<String, List<SfxTone>> kSkillVoices = {
  ..._kBaseSkillVoices,
  // Cada variante con su tono (distinto de la original y de las demás).
  for (final (i, e) in kSkillLooks.entries.indexed)
    if (_kBaseSkillVoices[e.value] case final v?)
      e.key: _x(v, p: 0.885 + 0.0125 * i),
};

/// Las partes del sonido propio de cada ULT de ascensión (ascension.md
/// § 4): preparación con el timbre de la ascensión, descarga e impacto.
UltVoices _ascUlt(List<SfxTone> sig, double p, int seed) => (
      build: [
        _t(55 * p, 0.85, w: _saw, to: 110 * p, a: 0.6, lp: 900, v: 0.45),
        _n(2000 * p, 0.8, to: 6000 * p, lp: 4000, a: 0.6, v: 0.3, seed: seed),
        ..._x(sig, dt: 0.4, g: 0.6),
      ],
      release: [
        ..._x(sig, dt: 0.05, p: 1.1),
        _n(4000 * p, 0.5, to: 1500 * p, lp: 3000, at: 0.1, v: 0.35, seed: seed + 1),
      ],
      impact: [
        _t(70 * p, 0.6, w: _sin, to: 26, v: 0.8),
        _n(1500 * p, 0.5, lp: 1100, v: 0.6, seed: seed + 2),
        ..._x(sig, g: 0.5, p: 0.8),
      ],
    );

/// Sonido de las ULT de las ascensiones por `SkillDef.id`.
final Map<String, UltVoices> kAscensionUltVoices = {
  'ult_berserker': _ascUlt(kSkillVoices['sangria']!, 0.8, 60),
  'ult_senorGuerra': _ascUlt(kSkillVoices['gritoGuerra']!, 1.0, 63),
  'ult_cronomante': _ascUlt(kSkillVoices['aceleron']!, 1.2, 66),
  'ult_elementalista': _ascUlt(kSkillVoices['prismaElemental']!, 1.1, 69),
  'ult_francotirador': _ascUlt(kSkillVoices['tiroCabeza']!, 0.9, 72),
  'ult_trampero': _ascUlt(kSkillVoices['trampaPuas']!, 1.05, 75),
  'ult_templario': _ascUlt(kSkillVoices['castigo']!, 1.3, 78),
  'ult_guardian': _ascUlt(_guardianDome(), 0.95, 81),
};

/// Ascensión y trampas de la Prueba (ascension.md § 1.1 y § 5).
Map<String, SfxDef> buildAscensionSfx() => {
      // Cinemática: la luz que converge (sube y vibra) y la revelación.
      Sfx.ascBuild: SfxDef([
        _t(110, 1.6, w: _saw, to: 440, a: 1.2, lp: 1500, vr: 6, vd: 0.03, v: 0.4),
        _t(165, 1.6, w: _saw, to: 660, a: 1.2, lp: 1500, v: 0.25),
        _n(2000, 1.6, to: 9000, lp: 6000, a: 1.3, v: 0.3, seed: 90),
      ], peak: SfxLevel.ultimate),
      Sfx.ascReveal: SfxDef([
        _n(16000, 0.12, v: 0.6, seed: 91),
        _t(60, 0.9, w: _sin, to: 30, v: 0.7),
        ..._arp([523, 659, 784, 1047, 1319, 1568],
            step: 0.05, d: 0.5, w: _sin, v: 0.3, at: 0.05),
        _t(2093, 0.9, w: _sin, at: 0.35, vr: 6, vd: 0.01, v: 0.25),
      ], peak: SfxLevel.ultimate),
      // Trampas.
      Sfx.trapSpike: SfxDef([
        _n(10000, 0.05, crush: 3, v: 0.5, seed: 92),
        _t(700, 0.06, w: _sq, to: 300, v: 0.35),
        _t(190, 0.12, w: _sq, to: 85, at: 0.04, v: 0.35),
      ], peak: SfxLevel.status),
      Sfx.trapPulse: SfxDef([
        _t(1600, 0.4, w: _pu, to: 200, crush: 4, vr: 8, vd: 0.06, v: 0.4),
        for (final at in [0.0, 0.1, 0.2]) _t(2600, 0.015, w: _sq, at: at, v: 0.35),
      ], peak: SfxLevel.status),
      Sfx.trapSpring: SfxDef([
        _t(1200, 0.04, w: _sq, to: 3000, v: 0.35),
        _n(7000, 0.08, crush: 3, at: 0.03, v: 0.45, seed: 93),
        _t(150, 0.15, w: _tri, to: 70, at: 0.04, v: 0.45),
      ], peak: SfxLevel.impact),
      for (final e in kAscensionUltVoices.entries) ...{
        Sfx.ult(e.key, Sfx.ultBuild):
            SfxDef(e.value.build, peak: SfxLevel.ultBuild),
        Sfx.ult(e.key, Sfx.ultRelease):
            SfxDef(e.value.release, peak: SfxLevel.ultRelease),
        Sfx.ult(e.key, Sfx.ultImpact):
            SfxDef(e.value.impact, peak: SfxLevel.ultImpact),
      },
    };


/// Inicio del golpe dentro de `enemy.<tipo>`: el "wind-up" suena antes
/// (docs/specs/audio.md § "Enemigos"). El impacto `enemy.hit.<tipo>`
/// suena en `BattleFx.enemyStrikeMs`.
const double kEnemyBodyAt = 0.11;

/// "Wind-up" de cada tipo: lo que se oye mientras el enemigo se echa
/// atrás (~0.14 s, sube hacia el golpe).
final Map<String, List<SfxTone>> kEnemyWindups = {
  // ---- v0.3 (docs/specs/audio.md § "Mecánicas de jefe v0.3") ----
  // Eco Sombrío: susurro que se desdobla.
  'ecoSombra': [
    _n(3000, 0.15, to: 6000, lp: 4000, a: 0.12, v: 0.35, seed: 401),
    _t(440, 0.15, w: _sin, to: 466, a: 0.1, vr: 11, vd: 0.03, v: 0.2),
    _t(220, 0.15, w: _sin, to: 233, a: 0.1, vr: 9, vd: 0.03, v: 0.2),
  ],
  // Guardián del Reloj: cuerda del reloj (tics que se aceleran).
  'guardianReloj': [
    for (final at in [0.0, 0.06, 0.1, 0.13]) _t(2794, 0.012, w: _sq, v: 0.35, at: at),
    _n(500, 0.16, to: 1300, lp: 700, a: 0.12, v: 0.4, seed: 403),
  ],
  // Hechicera: acorde mágico que sube.
  'hechicera': [
    _t(523, 0.16, w: _sin, to: 784, a: 0.12, vr: 6, vd: 0.02, v: 0.3),
    _t(659, 0.16, w: _tri, to: 988, a: 0.12, v: 0.2),
    _n(6000, 0.15, to: 10000, lp: 8000, a: 0.12, v: 0.2, seed: 405),
  ],
  // Eco de la Hechicera: el mismo acorde, hueco y desafinado.
  'ecoHechicera': [
    _t(554, 0.15, w: _sin, to: 740, a: 0.12, vr: 13, vd: 0.04, v: 0.25),
    _n(8000, 0.14, to: 12000, lp: 9000, a: 0.1, v: 0.15, seed: 407),
  ],
  // Salamandra: siseo con chispas.
  'salamandra': [
    _n(4500, 0.15, to: 8000, lp: 6000, a: 0.1, v: 0.4, seed: 409),
    ..._crackle(0.6),
  ],
  // Gólem de Magma: roca que cruje y burbujea.
  'golemMagma': [
    _n(350, 0.17, to: 800, lp: 500, a: 0.13, v: 0.55, seed: 411),
    _t(60, 0.17, w: _saw, to: 90, a: 0.12, lp: 400, v: 0.35),
    _t(300, 0.06, w: _sq, to: 150, at: 0.08, v: 0.2),
  ],
  // Bestia de Magma: bramido que sube con fuego.
  'bestiaMagma': [
    _t(45, 0.17, w: _saw, to: 85, a: 0.14, vr: 12, vd: 0.12, lp: 600, v: 0.55),
    _n(1200, 0.17, to: 4000, lp: 3000, a: 0.14, v: 0.45, seed: 413),
  ],
  // Necrófago: jadeo gutural.
  'necrofago': [
    _n(900, 0.15, to: 1800, lp: 1200, a: 0.1, v: 0.45, seed: 415),
    _t(120, 0.15, w: _saw, to: 160, a: 0.1, vr: 25, vd: 0.2, lp: 700, v: 0.3),
  ],
  // Alma Errante: suspiro frío.
  'almaErrante': [
    _n(2000, 0.16, to: 5000, lp: 3500, a: 0.14, v: 0.35, seed: 417),
    _t(880, 0.15, w: _sin, to: 1175, a: 0.12, vr: 7, vd: 0.02, v: 0.2),
  ],
  // Espectro Coronado: coro de lamentos que crece.
  'espectroCoronado': [
    _t(294, 0.17, w: _sin, to: 392, a: 0.14, vr: 6, vd: 0.03, v: 0.3),
    _t(349, 0.17, w: _tri, to: 466, a: 0.14, vr: 5, vd: 0.03, v: 0.2),
    _n(1500, 0.17, to: 4000, lp: 2500, a: 0.14, v: 0.35, seed: 419),
  ],
  // Siervo Espectral: gemido corto.
  'siervoEspectral': [
    _t(392, 0.14, w: _sin, to: 587, a: 0.1, vr: 8, vd: 0.04, v: 0.3),
    _n(3000, 0.12, lp: 2000, a: 0.1, v: 0.15, seed: 421),
  ],
  // Vigilante del Vacío: zumbido de energía que carga.
  'vigilanteVacio': [
    _t(110, 0.16, w: _sq, to: 220, a: 0.12, lp: 900, v: 0.3),
    _t(1760, 0.14, w: _sin, to: 2637, a: 0.1, v: 0.15),
  ],
  // Ojo del Abismo: parpadeo húmedo y tentáculos.
  'ojoAbismo': [
    _n(1800, 0.06, lp: 900, v: 0.4, seed: 423),
    _t(200, 0.15, w: _tri, to: 330, a: 0.1, vr: 16, vd: 0.1, v: 0.35),
  ],
  // Centinela: placas de obsidiana que se abren + carga del vacío.
  'centinela': [
    _n(700, 0.17, to: 2000, lp: 1200, a: 0.12, v: 0.5, seed: 425),
    _t(55, 0.17, w: _sq, to: 110, a: 0.14, lp: 500, v: 0.35),
    _t(1319, 0.16, w: _sin, to: 1976, a: 0.13, v: 0.2),
  ],
  // Heraldo de las Eras: arena que cae + campana lejana.
  'heraldoEras': [
    _n(7000, 0.16, lp: 5000, a: 0.08, v: 0.3, seed: 427),
    _t(1047, 0.15, w: _sin, a: 0.1, vr: 5, vd: 0.01, v: 0.2),
  ],
  // Fragmento del Tiempo: arena que se arremolina rápido.
  'fragmentoTiempo': [
    _n(5000, 0.12, to: 11000, lp: 8000, a: 0.08, v: 0.35, seed: 429),
    _t(2349, 0.1, w: _tri, to: 3136, a: 0.06, v: 0.15),
  ],
  // ---- v0.2 ----
  // Araña: patitas que corretean (clics secos) + siseo.
  'arana': [
    for (final at in [0.0, 0.03, 0.06, 0.09, 0.12]) _n(7000, 0.015, lp: 5000, v: 0.4, at: at, seed: 211),
    _n(5000, 0.14, to: 9000, lp: 7000, a: 0.1, v: 0.25, seed: 213),
  ],
  // Lobo: gruñido que sube.
  'lobo': [
    _t(90, 0.16, w: _saw, to: 150, a: 0.1, vr: 22, vd: 0.15, lp: 900, v: 0.55),
    _n(600, 0.14, to: 1200, lp: 800, a: 0.1, v: 0.3, seed: 217),
  ],
  // Murciélago de hielo: aleteos + campanita fría.
  'murcielagoHielo': [
    for (final at in [0.0, 0.05, 0.1]) _n(4200, 0.03, lp: 3000, v: 0.4, at: at, seed: 219),
    _t(2637, 0.12, w: _tri, to: 3520, a: 0.08, v: 0.15),
  ],
  // Elemental: hielo que cruje al juntarse.
  'elementalEscarcha': [
    _n(1500, 0.16, to: 5000, lp: 3000, a: 0.12, crush: 3, v: 0.5, seed: 221),
    _t(70, 0.16, w: _tri, to: 110, a: 0.1, v: 0.4),
  ],
  // Esqueleto: huesos que castañetean.
  'esqueleto': [
    for (final at in [0.0, 0.04, 0.08, 0.12]) _t(1100 + at * 1000, 0.018, w: _sq, v: 0.35, at: at),
    _n(2500, 0.12, lp: 1800, a: 0.08, v: 0.2, seed: 223),
  ],
  // Caballero caído: armadura que rechina.
  'caballeroCaido': [
    _n(900, 0.16, to: 2400, lp: 1600, a: 0.12, v: 0.45, seed: 227),
    _t(330, 0.14, w: _saw, to: 300, vr: 18, vd: 0.05, a: 0.1, lp: 1200, v: 0.25),
  ],
  // Cristal de hielo (no ataca): zumbido de cristal.
  'cristalHielo': [
    _t(1568, 0.14, w: _sin, a: 0.1, vr: 9, vd: 0.02, v: 0.35),
    _n(9000, 0.1, lp: 6000, a: 0.08, v: 0.15, seed: 229),
  ],
  // Matriarca: siseo grande + patas.
  'matriarca': [
    _n(4000, 0.16, to: 9000, lp: 6000, a: 0.12, v: 0.45, seed: 231),
    for (final at in [0.0, 0.05, 0.1]) _n(2500, 0.02, lp: 2000, v: 0.4, at: at, seed: 233),
    _t(60, 0.16, w: _saw, to: 90, a: 0.1, lp: 500, v: 0.3),
  ],
  // Sierpe: inhalación helada.
  'sierpe': [
    _n(700, 0.16, to: 3500, lp: 2500, a: 0.14, v: 0.5, seed: 237),
    _t(220, 0.16, w: _sin, to: 440, a: 0.12, vr: 6, vd: 0.03, v: 0.3),
  ],
  // Caballero Hueco: eco de metal hueco que se levanta.
  'caballeroHueco': [
    _t(98, 0.16, w: _saw, to: 147, a: 0.12, lp: 700, v: 0.45),
    _t(1245, 0.16, w: _sin, a: 0.1, vr: 5, vd: 0.02, v: 0.2),
    _n(800, 0.15, to: 1600, lp: 900, a: 0.1, v: 0.3, seed: 239),
  ],
  'slime': [
    _t(110, 0.14, w: _tri, to: 260, a: 0.1, vr: 14, vd: 0.12, v: 0.5),
    _n(900, 0.12, to: 1800, lp: 700, a: 0.1, v: 0.35),
  ],
  'bat': [
    for (final at in [0.0, 0.045, 0.09]) _n(3500, 0.03, lp: 2500, v: 0.4, at: at, seed: 31),
    _t(1400, 0.12, w: _sq, to: 2400, a: 0.08, v: 0.12),
  ],
  'golem': [
    _n(300, 0.16, to: 900, lp: 500, a: 0.12, v: 0.6, seed: 37),
    _t(55, 0.16, w: _saw, to: 85, a: 0.1, lp: 400, v: 0.35),
  ],
  'ghost': [
    _n(800, 0.15, to: 3000, lp: 2500, a: 0.13, v: 0.45, seed: 41),
    _t(300, 0.15, w: _sin, to: 600, a: 0.12, vr: 8, vd: 0.04, v: 0.3),
  ],
  'reyLimo': [
    _t(70, 0.16, w: _tri, to: 170, a: 0.12, vr: 10, vd: 0.15, v: 0.6),
    _n(600, 0.15, to: 1400, lp: 600, a: 0.12, v: 0.45, seed: 43),
  ],
  'golemReloj': [
    for (var i = 0; i < 4; i++) _t(2400, 0.012, w: _sq, v: 0.35, at: i * 0.035),
    _n(400, 0.16, to: 1100, lp: 600, a: 0.12, v: 0.5, seed: 47),
  ],
  'devorador': [
    _t(38, 0.17, w: _saw, to: 75, a: 0.14, vr: 9, vd: 0.12, lp: 600, v: 0.55),
    _n(500, 0.17, to: 2200, lp: 1500, a: 0.15, v: 0.5, seed: 53),
  ],
};

/// Sonido de cada tipo de enemigo de `kEnemies` (`enemy.<tipo>`): el
/// wind-up y el ataque (la voz del tipo) en [kEnemyBodyAt].
final Map<String, List<SfxTone>> kEnemyVoices = {
  for (final e in _enemyBodies.entries)
    e.key: [
      ...?kEnemyWindups[e.key],
      ..._x(e.value, dt: kEnemyBodyAt),
    ],
  for (final (id, base, p) in _kAbyssEnemySfx)
    id: [
      ..._x(kEnemyWindups[base] ?? const [], p: p),
      ..._x(_enemyBodies[base]!, dt: kEnemyBodyAt, p: p),
    ],
};

/// La voz del ataque de cada tipo (lo que era `enemy.<tipo>`).
final Map<String, List<SfxTone>> _enemyBodies = {
  // ---- v0.3 ----
  'ecoSombra': [
    ..._swingBlade(0.7, 0.9),
    _t(330, 0.2, w: _sin, to: 220, vr: 10, vd: 0.05, v: 0.3, at: 0.02),
  ],
  'guardianReloj': [
    ..._golem(),
    _t(1661, 0.3, w: _sin, a: 0.002, at: 0.05, v: 0.25),
  ],
  'hechicera': [
    _t(784, 0.3, w: _sin, to: 1568, a: 0.01, vr: 8, vd: 0.03, v: 0.35),
    ..._x(_zap(1.2), dt: 0.05),
    ..._x(_ice(1.1, 0.6), dt: 0.08, g: 0.6),
  ],
  'ecoHechicera': [
    _t(830, 0.25, w: _sin, to: 1480, vr: 14, vd: 0.05, v: 0.3),
    _t(415, 0.25, w: _tri, to: 740, at: 0.03, v: 0.15),
  ],
  'salamandra': [
    ..._fire(1.3, 0.6, 31),
    _t(700, 0.08, w: _sq, to: 350, v: 0.2),
  ],
  'golemMagma': [
    _t(65, 0.35, w: _sin, to: 35, v: 0.6),
    ..._fire(0.7, 0.8, 33),
    ..._x(_bubbles(0.6, 0.8, 2), dt: 0.1),
  ],
  'bestiaMagma': [
    _t(70, 0.5, w: _saw, to: 40, vr: 9, vd: 0.12, lp: 900, v: 0.5),
    ..._fire(0.8, 1.2, 35),
    ..._crackle(1, 0.1),
  ],
  'necrofago': [
    _n(5000, 0.12, to: 1500, lp: 4000, v: 0.45, seed: 431),
    ..._x(_bubbles(0.9, 0.7, 3), dt: 0.05),
  ],
  'almaErrante': [
    _t(660, 0.4, w: _sin, to: 440, a: 0.05, vr: 6, vd: 0.03, v: 0.4),
    ..._x(_ice(1.3, 0.6), dt: 0.08, g: 0.6),
  ],
  'espectroCoronado': [
    _t(392, 0.55, w: _sin, to: 262, a: 0.05, vr: 6, vd: 0.03, v: 0.45),
    _t(466, 0.55, w: _tri, to: 311, a: 0.05, vr: 6, vd: 0.03, v: 0.2),
    _n(1200, 0.4, lp: 800, a: 0.05, v: 0.35, seed: 433),
  ],
  'siervoEspectral': [
    _t(587, 0.3, w: _sin, to: 392, a: 0.03, vr: 7, vd: 0.03, v: 0.35),
    _n(4000, 0.1, lp: 2500, v: 0.2, seed: 435),
  ],
  'vigilanteVacio': [
    ..._swingHeavy(1.1, 0.9),
    _t(1760, 0.2, w: _sq, to: 880, vr: 30, vd: 0.1, v: 0.15),
  ],
  'ojoAbismo': [
    _t(1200, 0.15, w: _sin, to: 300, v: 0.4),
    ..._zap(0.8),
  ],
  'centinela': [
    ..._swingHeavy(0.6, 1.4),
    _t(55, 0.45, w: _sin, to: 30, v: 0.55),
    _t(1976, 0.35, w: _sin, to: 988, a: 0.01, at: 0.05, v: 0.2),
  ],
  'heraldoEras': [
    ..._swingHeavy(0.9, 1.1),
    _t(784, 0.4, w: _sin, a: 0.002, at: 0.06, vr: 5, vd: 0.01, v: 0.25),
    _n(6000, 0.25, lp: 4000, at: 0.1, v: 0.2, seed: 437),
  ],
  'fragmentoTiempo': [
    ..._swingBlade(1.3, 0.7),
    _t(3136, 0.15, w: _tri, to: 2093, at: 0.03, v: 0.2),
  ],
  'arana': [
    _n(6000, 0.08, to: 2000, lp: 5000, v: 0.45, seed: 241),
    _t(900, 0.06, w: _sq, to: 400, v: 0.25, at: 0.02),
    ..._x(_bubbles(1.4, 0.4, 2), dt: 0.05),
  ],
  'lobo': [
    _t(260, 0.18, w: _saw, to: 520, vr: 14, vd: 0.1, lp: 1500, v: 0.45),
    _n(3000, 0.1, lp: 2000, v: 0.4, at: 0.06, seed: 243),
  ],
  'murcielagoHielo': [
    _t(3136, 0.1, w: _sq, to: 4186, vr: 40, vd: 0.05, v: 0.25),
    _t(2093, 0.15, w: _tri, at: 0.04, v: 0.3),
  ],
  'elementalEscarcha': [
    _t(55, 0.3, w: _sin, to: 35, v: 0.6),
    ..._x(_ice(0.7, 0.8), dt: 0.02),
    _n(3000, 0.2, lp: 1500, crush: 3, v: 0.35, seed: 247),
  ],
  'esqueleto': [
    ..._swingBlade(0.8, 1.1),
    for (final at in [0.08, 0.13]) _t(900, 0.02, w: _sq, v: 0.25, at: at),
  ],
  'caballeroCaido': [
    ..._swingHeavy(0.85, 1.2),
    _t(190, 0.15, w: _sq, to: 120, v: 0.2, at: 0.05),
  ],
  'cristalHielo': [
    _t(2637, 0.2, w: _tri, v: 0.35),
    _t(3951, 0.16, w: _sin, at: 0.03, v: 0.2),
  ],
  'matriarca': [
    _n(5000, 0.25, to: 1500, lp: 4000, a: 0.03, v: 0.5, seed: 251),
    _t(80, 0.3, w: _saw, to: 45, lp: 600, v: 0.45),
    ..._x(_bubbles(1.1, 0.6, 3), dt: 0.08),
  ],
  'sierpe': [
    _n(3000, 0.4, to: 8000, lp: 6000, a: 0.05, v: 0.5, seed: 253),
    _t(110, 0.35, w: _saw, to: 70, vr: 7, vd: 0.08, lp: 800, v: 0.45),
    ..._x(_ice(1, 0.7), dt: 0.12, g: 0.6),
  ],
  'caballeroHueco': [
    ..._swingHeavy(0.7, 1.3),
    _t(73, 0.35, w: _sin, to: 49, v: 0.5),
    _t(1245, 0.3, w: _sin, a: 0.002, at: 0.06, v: 0.2),
  ],
  'slime': _slime(),
  'bat': [
    _t(2400, 0.12, w: _sq, to: 3400, vr: 40, vd: 0.05, v: 0.3),
    _t(2800, 0.1, w: _sq, to: 3800, vr: 40, vd: 0.05, v: 0.25, at: 0.1),
  ],
  'golem': _golem(),
  'ghost': [
    _t(520, 0.45, w: _sin, to: 340, a: 0.05, vr: 6, vd: 0.03, v: 0.5),
    _t(780, 0.45, w: _tri, to: 510, a: 0.05, vr: 6, vd: 0.03, v: 0.2),
  ],
  'reyLimo': [
    ..._x(_slime(), p: 0.67, l: 1.5),
    _t(70, 0.3, w: _sin, to: 45, v: 0.5),
  ],
  'golemReloj': [
    ..._golem(),
    for (var i = 0; i < 4; i++) _t(2000, 0.015, w: _sq, v: 0.25, at: 0.12 + i * 0.1),
  ],
  'devorador': [
    _t(80, 0.6, w: _saw, to: 50, vr: 8, vd: 0.1, v: 0.45),
    _n(800, 0.6, lp: 900, a: 0.05, v: 0.5),
    _t(45, 0.6, w: _sin, v: 0.4),
  ],
};

/// Impacto propio de cada tipo de enemigo sobre un jugador
/// (`enemy.hit.<tipo>`), en vez de `impact.hurt`.
final Map<String, List<SfxTone>> kEnemyHitVoices = {
  ..._kBaseEnemyHitVoices,
  for (final (id, base, p) in _kAbyssEnemySfx)
    id: _x(_kBaseEnemyHitVoices[base]!, p: p),
};

final Map<String, List<SfxTone>> _kBaseEnemyHitVoices = {
  // ---- v0.3 ----
  // Corte sombrío con eco.
  'ecoSombra': [
    _n(9000, 0.06, to: 3000, v: 0.55, seed: 441),
    _t(180, 0.15, w: _sin, to: 70, v: 0.55),
    _n(9000, 0.05, to: 3000, v: 0.25, at: 0.09, seed: 443),
  ],
  // Engranaje que golpea y tic que se detiene.
  'guardianReloj': [
    _t(100, 0.28, w: _sin, to: 35, v: 0.8),
    _t(2217, 0.18, w: _sin, a: 0.002, v: 0.3),
    _t(2794, 0.015, w: _sq, at: 0.12, v: 0.3),
    _n(2500, 0.1, lp: 1200, v: 0.45, seed: 445),
  ],
  // Rayo arcano con campanas.
  'hechicera': [
    _n(16000, 0.06, v: 0.55, seed: 447),
    _t(120, 0.3, w: _sin, to: 40, v: 0.75),
    _t(1568, 0.35, w: _sin, a: 0.002, v: 0.3),
    _t(2349, 0.3, w: _sin, a: 0.002, at: 0.03, v: 0.2),
  ],
  // Eco: el mismo rayo, más débil y doble.
  'ecoHechicera': [
    _n(14000, 0.05, v: 0.45, seed: 449),
    _t(1480, 0.2, w: _sin, a: 0.002, v: 0.3),
    _t(1480, 0.15, w: _sin, a: 0.002, at: 0.08, v: 0.15),
    _t(150, 0.15, w: _sin, to: 70, v: 0.5),
  ],
  // Mordisco ardiente chico.
  'salamandra': [
    _n(9000, 0.05, v: 0.55, seed: 451),
    _t(220, 0.12, w: _sin, to: 80, v: 0.55),
    ..._crackle(0.5, 0.03),
  ],
  // Puñetazo de roca fundida.
  'golemMagma': [
    _t(80, 0.35, w: _sin, to: 28, v: 0.85),
    _n(1400, 0.2, lp: 800, v: 0.6, seed: 453),
    _n(9000, 0.12, crush: 3, at: 0.04, v: 0.3, seed: 455),
  ],
  // Zarpazo de magma enorme.
  'bestiaMagma': [
    _n(10000, 0.1, to: 2000, lp: 8000, v: 0.6, seed: 457),
    _t(60, 0.45, w: _sin, to: 22, v: 0.9),
    ..._fire(0.6, 0.6, 459),
  ],
  // Mordida podrida.
  'necrofago': [
    _n(7000, 0.05, to: 2000, v: 0.6, seed: 461),
    _t(160, 0.15, w: _sin, to: 60, v: 0.6),
    ..._x(_bubbles(0.8, 0.6, 2), dt: 0.05),
  ],
  // Toque helado.
  'almaErrante': [
    _t(3520, 0.2, w: _tri, v: 0.35),
    _t(2637, 0.2, w: _tri, at: 0.03, v: 0.3),
    _t(250, 0.2, w: _sin, to: 120, v: 0.45),
    _n(15000, 0.04, v: 0.35, seed: 463),
  ],
  // Garra espectral real.
  'espectroCoronado': [
    _n(11000, 0.08, to: 3000, v: 0.6, seed: 465),
    _t(90, 0.35, w: _sin, to: 30, v: 0.8),
    _t(2093, 0.3, w: _tri, at: 0.02, v: 0.3),
    _t(1568, 0.3, w: _tri, at: 0.05, v: 0.25),
  ],
  // Roce espectral.
  'siervoEspectral': [
    _t(1976, 0.15, w: _tri, v: 0.35),
    _t(260, 0.15, w: _sin, to: 130, v: 0.45),
    _n(10000, 0.04, v: 0.35, seed: 467),
  ],
  // Lanzazo del vacío.
  'vigilanteVacio': [
    _n(12000, 0.06, to: 4000, v: 0.55, seed: 469),
    _t(140, 0.2, w: _sin, to: 50, v: 0.7),
    _t(880, 0.25, w: _sq, to: 440, vr: 20, vd: 0.05, v: 0.15),
  ],
  // Mirada que aturde: zumbido + golpe.
  'ojoAbismo': [
    _t(1000, 0.3, w: _tri, vr: 12, vd: 0.15, v: 0.35),
    _t(170, 0.18, w: _sin, to: 60, v: 0.6),
    _n(6000, 0.05, v: 0.4, seed: 471),
  ],
  // Mazazo de obsidiana.
  'centinela': [
    _t(55, 0.5, w: _sin, to: 20, v: 0.9),
    _n(3000, 0.15, lp: 1500, v: 0.6, seed: 473),
    _t(988, 0.4, w: _sin, a: 0.002, v: 0.3),
    _t(1319, 0.3, w: _sin, a: 0.002, at: 0.02, v: 0.2),
  ],
  // Golpe del estandarte: campana y arena.
  'heraldoEras': [
    _t(85, 0.35, w: _sin, to: 30, v: 0.8),
    _t(523, 0.5, w: _sin, a: 0.002, v: 0.3),
    _n(7000, 0.2, lp: 5000, at: 0.03, v: 0.35, seed: 475),
  ],
  // Corte de arena rápido.
  'fragmentoTiempo': [
    _n(13000, 0.05, to: 5000, v: 0.55, seed: 477),
    _t(3136, 0.1, w: _tri, v: 0.3),
    _t(200, 0.1, w: _sin, to: 90, v: 0.5),
  ],
  // ---- v0.2 ----
  // Picadura venenosa.
  'arana': [
    _n(10000, 0.03, v: 0.6, seed: 257),
    _t(700, 0.08, w: _sq, to: 300, v: 0.35),
    ..._x(_bubbles(1.2, 0.5, 2), dt: 0.04),
  ],
  // Mordisco con desgarro.
  'lobo': [
    _n(8000, 0.06, to: 2500, v: 0.6, seed: 259),
    _t(180, 0.12, w: _sin, to: 70, v: 0.6),
    _n(6000, 0.05, to: 2000, v: 0.45, at: 0.06, seed: 261),
  ],
  // Colmillo de hielo.
  'murcielagoHielo': [
    _n(12000, 0.04, v: 0.55, seed: 263),
    _t(3136, 0.15, w: _tri, v: 0.35),
    _t(400, 0.1, w: _sin, to: 200, v: 0.4),
  ],
  // Mazazo helado.
  'elementalEscarcha': [
    _t(85, 0.3, w: _sin, to: 30, v: 0.85),
    _n(14000, 0.08, v: 0.5, seed: 267),
    _t(2093, 0.2, w: _tri, at: 0.02, v: 0.3),
    _t(2794, 0.2, w: _tri, at: 0.04, v: 0.25),
  ],
  // Tajo de hueso: corte + crujido.
  'esqueleto': [
    _n(11000, 0.08, to: 3000, lp: 9000, v: 0.6, seed: 269),
    _t(1300, 0.03, w: _sq, v: 0.35, at: 0.03),
    _t(140, 0.12, w: _sin, to: 60, v: 0.5),
  ],
  // Escudazo de metal.
  'caballeroCaido': [
    _t(110, 0.3, w: _sin, to: 40, v: 0.8),
    _t(587, 0.35, w: _sin, a: 0.002, v: 0.3),
    _t(1661, 0.25, w: _sin, a: 0.002, v: 0.25),
    _n(3000, 0.1, lp: 1500, v: 0.5, seed: 271),
  ],
  // Cristal (no ataca): tintineo.
  'cristalHielo': [
    _t(4186, 0.12, w: _tri, v: 0.35),
    _t(3520, 0.12, w: _tri, at: 0.03, v: 0.3),
  ],
  // Colmillos de la reina.
  'matriarca': [
    _n(9000, 0.06, v: 0.6, seed: 273),
    _t(160, 0.25, w: _sin, to: 45, v: 0.8),
    ..._x(_bubbles(0.9, 0.8, 3), dt: 0.05),
  ],
  // Coletazo helado.
  'sierpe': [
    _t(75, 0.35, w: _sin, to: 28, v: 0.85),
    _n(1800, 0.2, lp: 1200, v: 0.55, seed: 277),
    _t(2637, 0.25, w: _tri, at: 0.03, v: 0.3),
    _n(15000, 0.06, v: 0.4, at: 0.02, seed: 279),
  ],
  // Espadazo hueco: metal que retumba.
  'caballeroHueco': [
    _n(12000, 0.08, to: 3000, lp: 9000, v: 0.6, seed: 281),
    _t(65, 0.4, w: _sin, to: 25, v: 0.85),
    _t(830, 0.45, w: _sin, a: 0.002, vr: 4, vd: 0.01, v: 0.3),
    _t(2217, 0.3, w: _sin, a: 0.002, v: 0.2),
  ],
  // Salpicón húmedo.
  'slime': [
    _n(2000, 0.12, lp: 900, v: 0.6, seed: 59),
    _t(220, 0.12, w: _sin, to: 80, v: 0.6),
    _t(520, 0.06, w: _sin, to: 260, v: 0.3, at: 0.05),
  ],
  // Mordida doble.
  'bat': [
    _n(9000, 0.03, v: 0.6, seed: 61),
    _t(1500, 0.05, w: _sq, to: 600, v: 0.35),
    _n(9000, 0.03, v: 0.5, at: 0.07, seed: 67),
    _t(1300, 0.05, w: _sq, to: 500, v: 0.3, at: 0.07),
  ],
  // Golpe sordo de piedra.
  'golem': [
    _t(95, 0.3, w: _sin, to: 32, v: 0.85),
    _n(1500, 0.15, lp: 700, v: 0.6, seed: 71),
    _t(70, 0.2, w: _tri, to: 35, crush: 3, v: 0.35),
  ],
  // Escalofrío: cristal frío.
  'ghost': [
    _t(2637, 0.22, w: _tri, v: 0.4),
    _t(1976, 0.25, w: _tri, at: 0.02, v: 0.35),
    _n(12000, 0.05, v: 0.45, seed: 73),
    _t(300, 0.2, w: _sin, to: 150, v: 0.4),
  ],
  // Gran salpicón con golpe grave.
  'reyLimo': [
    _n(1500, 0.2, lp: 800, v: 0.7, seed: 79),
    _t(150, 0.25, w: _sin, to: 45, v: 0.8),
    _t(360, 0.1, w: _sin, to: 180, v: 0.35, at: 0.08),
    _t(300, 0.1, w: _sin, to: 150, v: 0.3, at: 0.15),
  ],
  // Metal y piedra.
  'golemReloj': [
    _t(90, 0.3, w: _sin, to: 30, v: 0.8),
    _t(1320, 0.3, w: _sin, to: 1300, a: 0.002, v: 0.3),
    _t(2980, 0.2, w: _sin, a: 0.002, v: 0.2),
    _n(2000, 0.12, lp: 900, v: 0.55, seed: 83),
  ],
  // Mordisco ardiente.
  'devorador': [
    _t(70, 0.4, w: _sin, to: 25, v: 0.85),
    _n(1200, 0.3, lp: 900, v: 0.6, seed: 89),
    ..._crackle(1, 0.04),
  ],
};

const _kBossTypes = {
  'reyLimo', 'golemReloj', 'devorador', //
  'matriarca', 'sierpe', 'caballeroHueco', //
  'hechicera', 'bestiaMagma', 'espectroCoronado', 'centinela',
  // v0.8 · Jefes del Abismo.
  'golemAbismo', 'hechiceraAbismo', 'espectroAbismo', 'devoradorAbismo',
  'ecoPrimordial',
};

/// v0.8 · Jefes del Abismo (docs/specs/abyss_bosses.md § 4): la voz de
/// su jefe base, transpuesta (más grave: el vacío). Sin piezas nuevas.
const _kAbyssEnemySfx = [
  ('golemAbismo', 'golemReloj', 0.8),
  ('hechiceraAbismo', 'hechicera', 0.84),
  ('ecoAbismo', 'ecoHechicera', 1.12),
  ('espectroAbismo', 'espectroCoronado', 0.82),
  ('devoradorAbismo', 'devorador', 0.86),
  ('ecoPrimordial', 'centinela', 0.74),
];

/// ULT de los Jefes del Abismo: las de su jefe base, transpuestas.
const _kAbyssUltSfx = [
  ('eult_abismoReloj', 'eult_engranaje', 0.82),
  ('eult_abismoEco', 'eult_coro', 0.84),
  ('eult_abismoCorona', 'eult_lamento', 0.8),
  ('eult_abismoEras', 'eult_finEras', 0.86),
  ('eult_primordial', 'eult_colapsoVacio', 0.76),
];

List<SfxTone> _slime() => [
      _t(180, 0.12, w: _tri, to: 420, v: 0.5),
      _n(1500, 0.1, lp: 800, v: 0.4),
      _t(420, 0.1, w: _tri, to: 160, v: 0.45, at: 0.1),
    ];

List<SfxTone> _golem() => [
      _t(70, 0.3, w: _sin, to: 40, v: 0.6),
      _n(1200, 0.2, lp: 400, v: 0.5),
      _t(110, 0.2, w: _tri, to: 55, crush: 3, v: 0.3),
    ];

/// Los sonidos de combate (todo lo que no es del prototipo).
Map<String, SfxDef> buildCombatSfx() {
  SfxDef act(List<SfxTone> v) => SfxDef(v, peak: SfxLevel.action);
  SfxDef imp(List<SfxTone> v) => SfxDef(v, peak: SfxLevel.impact);
  SfxDef st(List<SfxTone> v) => SfxDef(v, peak: SfxLevel.status);
  SfxDef heavy(List<SfxTone> v) => SfxDef(v, peak: SfxLevel.heavy);

  return {
    // ---- arranque por arma ----
    Sfx.swingBlade: act(_swingBlade()),
    Sfx.swingHeavy: act(_swingHeavy()),
    Sfx.shotBow: act([
      _t(330, 0.14, w: _tri, to: 240, vr: 18, vd: 0.03, v: 0.5),
      _n(5000, 0.22, to: 9000, at: 0.02, lp: 5000, a: 0.05, v: 0.3),
    ]),
    Sfx.shotRifle: act([
      _n(20000, 0.03, v: 0.8),
      _n(3000, 0.28, to: 700, lp: 2500, v: 0.6, seed: 9),
      _t(140, 0.1, w: _sq, to: 55, v: 0.5),
    ]),
    Sfx.shotStaff: act([
      _t(520, 0.18, w: _sq, to: 1250, vr: 22, vd: 0.04, v: 0.35),
      _t(1040, 0.16, w: _tri, to: 2500, v: 0.3),
    ]),
    Sfx.shotTome: act([
      _t(300, 0.2, w: _pu, to: 900, crush: 4, v: 0.35),
      _t(1200, 0.18, w: _sin, vr: 9, vd: 0.05, v: 0.3),
    ]),
    // Loot v2: estocada, dos tajitos, chispa de varita y cuerda pesada.
    Sfx.swingSpear: act([
      _n(10000, 0.08, to: 5000, a: 0.005, lp: 7000, v: 0.55),
      _t(900, 0.06, w: _pu, to: 1800, v: 0.2),
      _n(3000, 0.1, to: 6000, lp: 3000, at: 0.02, v: 0.25, seed: 3),
    ]),
    Sfx.swingDaggers: act([
      _n(12000, 0.06, to: 6000, a: 0.01, lp: 8000, v: 0.45),
      _n(12000, 0.06, to: 7000, a: 0.01, lp: 8000, at: 0.07, v: 0.45, seed: 5),
      _t(2200, 0.03, w: _pu, to: 1400, at: 0.07, v: 0.12),
    ]),
    Sfx.shotWand: act([
      _t(1500, 0.1, w: _tri, to: 3000, v: 0.4),
      _t(3000, 0.03, w: _sq, at: 0.04, v: 0.15),
      _n(15000, 0.02, crush: 3, at: 0.02, v: 0.3, seed: 6),
    ]),
    Sfx.shotCrossbow: act([
      _n(20000, 0.02, v: 0.6, seed: 4),
      _t(180, 0.18, w: _tri, to: 120, vr: 25, vd: 0.05, v: 0.55),
      _n(4000, 0.2, to: 1500, lp: 2500, at: 0.02, v: 0.35, seed: 8),
    ]),
    // ---- impactos ----
    Sfx.impactSlash: imp([
      _n(12000, 0.06, v: 0.5),
      _t(900, 0.06, w: _sq, to: 280, v: 0.3),
    ]),
    Sfx.impactBlunt: imp([
      _t(150, 0.2, w: _sin, to: 45, v: 0.7),
      _n(2500, 0.09, lp: 1200, v: 0.5),
      _t(90, 0.14, w: _tri, to: 40, v: 0.3),
    ]),
    Sfx.impactArrow: imp([
      _n(7000, 0.04, v: 0.5),
      _t(620, 0.05, w: _sq, to: 180, v: 0.35),
    ]),
    Sfx.impactBullet: imp([
      _n(16000, 0.05, v: 0.5),
      _t(1500, 0.08, w: _tri, to: 900, v: 0.3),
    ]),
    Sfx.impactArcane: imp([
      _t(1200, 0.14, w: _pu, to: 380, crush: 4, v: 0.4),
      _n(8000, 0.05, v: 0.35),
    ]),
    Sfx.impactPierce: imp([
      _n(10000, 0.04, v: 0.5),
      _t(300, 0.09, w: _tri, to: 90, v: 0.45),
    ]),
    Sfx.impactDagger: imp([
      _n(16000, 0.03, v: 0.45),
      _t(1400, 0.04, w: _sq, to: 700, v: 0.25),
      _n(16000, 0.03, at: 0.05, v: 0.35, seed: 9),
    ]),
    Sfx.impactWand: imp([
      _t(2400, 0.1, w: _tri, to: 800, v: 0.4),
      _t(1600, 0.08, w: _pu, to: 500, crush: 3, v: 0.25),
    ]),
    Sfx.impactBolt: imp([
      _n(6000, 0.05, v: 0.55),
      _t(130, 0.18, w: _sin, to: 45, v: 0.6),
      _t(700, 0.05, w: _sq, to: 200, v: 0.25),
    ]),
    Sfx.impactFire: imp([
      _n(2600, 0.28, lp: 2200, a: 0.01, v: 0.6),
      ..._crackle(),
    ]),
    Sfx.impactIce: imp([
      _t(3136, 0.3, w: _tri, v: 0.4),
      _t(2349, 0.34, w: _tri, at: 0.02, v: 0.35),
      _n(14000, 0.05, v: 0.4),
    ]),
    Sfx.impactPoison: imp([
      _t(520, 0.07, w: _sin, to: 260, v: 0.45),
      _t(440, 0.07, w: _sin, to: 220, v: 0.45, at: 0.06),
      _t(600, 0.07, w: _sin, to: 300, v: 0.45, at: 0.12),
      _n(1500, 0.2, lp: 700, v: 0.35),
    ]),
    Sfx.impactHoly: imp(_holy()),
    Sfx.impactHurt: imp([
      _t(190, 0.13, w: _sq, to: 85, v: 0.4),
      _n(3000, 0.08, lp: 1800, v: 0.5),
    ]),
    // Dos parciales inarmónicos (×2.52) con ataque rápido, caída corta y
    // un leve descenso de altura, más un transitorio de ruido.
    Sfx.critClink: SfxDef([
      _t(2093, 0.26, w: _sin, to: 2030, a: 0.002, v: 0.55),
      _t(5267, 0.18, w: _sin, to: 5110, a: 0.002, v: 0.3),
      _t(3140, 0.12, w: _tri, to: 3050, a: 0.002, v: 0.08),
      _n(18000, 0.012, v: 0.35, seed: 13),
    ], peak: SfxLevel.crit),
    // ---- curas, ítems, defensa ----
    Sfx.healSparkle: st(_arp([1319, 1568, 2093, 2637], step: 0.04, d: 0.08)),
    Sfx.manaUp: st([
      _t(600, 0.2, w: _sin, to: 1200, vr: 8, vd: 0.02, v: 0.45),
      _t(1800, 0.15, w: _tri, at: 0.1, v: 0.3),
    ]),
    Sfx.potion: st([
      _t(300, 0.07, w: _sin, to: 520, v: 0.5),
      _t(280, 0.07, w: _sin, to: 500, v: 0.5, at: 0.09),
      _t(700, 0.05, w: _sq, to: 1000, v: 0.15, at: 0.18),
    ]),
    Sfx.ether: st([
      _t(900, 0.22, w: _sin, to: 1800, vr: 8, vd: 0.02, v: 0.45),
      _t(2400, 0.15, w: _tri, at: 0.12, v: 0.3),
    ]),
    Sfx.defend: act(_shieldRing()),
    Sfx.dualCast: act([
      for (final f in [392.0, 494.0, 587.0])
        _t(f, 0.35, w: _sq, to: f * 2, v: 0.2),
    ]),
    // Dúos v0.8.3: dos barridos que se cruzan (uno sube, otro baja) con
    // un soplido, y el choque: dos golpes casi juntos + acorde brillante.
    Sfx.dualRise: act([
      _t(196, 0.55, w: _saw, to: 784, v: 0.16, lp: 2400),
      _t(1568, 0.55, w: _saw, to: 392, v: 0.12, lp: 2400),
      _n(5000, 0.5, to: 12000, v: 0.12, a: 0.3, seed: 31),
    ]),
    Sfx.dualClash: SfxDef([
      _n(9000, 0.18, v: 0.5, seed: 33),
      _t(110, 0.22, w: _sin, to: 45, v: 0.7),
      _n(7000, 0.16, v: 0.45, at: 0.06, seed: 34),
      _t(98, 0.2, w: _sin, to: 40, v: 0.6, at: 0.06),
      for (final f in [523.0, 659.0, 784.0, 1047.0])
        _t(f, 0.5, w: _tri, v: 0.14, at: 0.08),
    ], peak: SfxLevel.crit),
    // ---- estados ----
    Sfx.status('burn'): st([
      _n(9000, 0.22, crush: 3, v: 0.4, seed: 7),
      _t(220, 0.12, w: _saw, to: 330, v: 0.3),
    ]),
    Sfx.status('poison'): st(_bubbles(1.1, 0.8)),
    Sfx.status('freeze'): st(_arp([2637, 3520, 4186], step: 0.03, d: 0.2)),
    Sfx.status('stun'): st([
      _t(1200, 0.4, w: _tri, to: 700, vr: 9, vd: 0.12, v: 0.45),
    ]),
    Sfx.status('holy'): st([
      _t(1568, 0.3, w: _sin, v: 0.4),
      _t(2349, 0.3, w: _sin, v: 0.3),
    ]),
    Sfx.status('regen'): st([_t(784, 0.25, w: _tri, to: 1175, v: 0.45)]),
    Sfx.tick('burn'): st([
      _n(3000, 0.16, lp: 2000, v: 0.5),
      _n(10000, 0.1, crush: 3, v: 0.3, seed: 7),
    ]),
    Sfx.tick('poison'): st([
      _t(330, 0.08, w: _sin, to: 180, v: 0.5),
      _t(280, 0.08, w: _sin, to: 150, v: 0.5, at: 0.08),
    ]),
    Sfx.tick('holy'): st([_t(1319, 0.18, w: _sin, v: 0.45)]),
    Sfx.tick('regen'): st(_arp([1047, 1319], d: 0.12)),
    // ---- turno salteado, K.O., revivir, retraso ----
    Sfx.skipFreeze: st([
      _n(16000, 0.12, v: 0.5),
      ..._arp([2637, 3520, 1760], step: 0.04, d: 0.08, v: 0.35),
    ]),
    Sfx.skipStun: st([
      _t(1000, 0.45, w: _tri, vr: 10, vd: 0.15, v: 0.45),
      for (final at in [0.05, 0.2, 0.35]) _t(1500, 0.03, w: _sq, v: 0.15, at: at),
    ]),
    Sfx.koEnemy: heavy([
      _n(6000, 0.35, to: 400, lp: 3000, v: 0.5),
      _t(400, 0.3, w: _sq, to: 80, v: 0.3),
    ]),
    Sfx.koPlayer: heavy(_arp([392, 330, 262, 196], step: 0.12, d: 0.12, w: _sq)),
    Sfx.revive: st([
      _t(262, 0.3, w: _tri, to: 1047, v: 0.45),
      ..._arp([1047, 1319, 1568], step: 0.05, d: 0.1, at: 0.28, v: 0.35),
    ]),
    Sfx.delay: st([_t(800, 0.35, w: _saw, to: 200, vr: 6, vd: 0.05, v: 0.4)]),
    // ---- enemigos ----
    Sfx.enemyGeneric: SfxDef([
      _n(600, 0.12, to: 2000, lp: 1500, a: 0.1, v: 0.4),
      _n(5000, 0.12, to: 2000, lp: 4000, v: 0.5, at: kEnemyBodyAt),
      _t(300, 0.1, w: _sq, to: 150, v: 0.3, at: kEnemyBodyAt),
    ], peak: SfxLevel.enemy),
    Sfx.enemyHeavy: heavy([
      _t(60, 0.4, w: _sin, to: 30, v: 0.7),
      _n(2000, 0.3, lp: 600, v: 0.5),
    ]),
    // Más fuertes que los arranques del grupo; los jefes, más todavía.
    for (final e in kEnemyVoices.entries)
      Sfx.enemy(e.key): SfxDef(e.value,
          peak: _kBossTypes.contains(e.key) ? SfxLevel.enemyBoss : SfxLevel.enemy),
    for (final e in kEnemyHitVoices.entries)
      Sfx.enemyHit(e.key): SfxDef(e.value, peak: SfxLevel.enemyHit),
    // ---- quiebre y ULT enemigas ----
    ...buildBreakSfx(),
    // ---- loot en el mapa ----
    ...buildLootSfx(),
    // ---- firma de cada habilidad ----
    for (final e in kSkillVoices.entries) Sfx.skill(e.key): act(e.value),
    // ---- procs del árbol ----
    ...buildProcSfx(),
    // ---- ultimates: preparación, descarga e impacto ----
    for (final e in kUltVoices.entries) ...{
      Sfx.ult(e.key, Sfx.ultBuild):
          SfxDef(e.value.build, peak: SfxLevel.ultBuild),
      Sfx.ult(e.key, Sfx.ultRelease):
          SfxDef(e.value.release, peak: SfxLevel.ultRelease),
      Sfx.ult(e.key, Sfx.ultImpact):
          SfxDef(e.value.impact, peak: SfxLevel.ultImpact),
    },
    // ULT de camino (branch_ults.md): suenan como la ULT a la que se
    // parecen.
    for (final e in kBranchUltLooks.entries)
      if (kUltVoices[e.value] case final v?) ...{
        Sfx.ult(e.key, Sfx.ultBuild): SfxDef(v.build, peak: SfxLevel.ultBuild),
        Sfx.ult(e.key, Sfx.ultRelease):
            SfxDef(v.release, peak: SfxLevel.ultRelease),
        Sfx.ult(e.key, Sfx.ultImpact):
            SfxDef(v.impact, peak: SfxLevel.ultImpact),
      },
  };
}

// ------------------------------------------------------- procs del árbol

/// La firma de una habilidad con eco: el original más bajo y dos copias
/// que se apagan (Eco Arcano).
List<SfxTone> _echo(List<SfxTone> voices) => [
      ..._x(voices, g: 0.7),
      ..._x(voices, dt: 0.12, g: 0.4),
      ..._x(voices, dt: 0.24, g: 0.2),
    ];

/// Los sonidos de los disparadores del árbol (docs/specs/audio.md
/// § "Disparadores del árbol (procs)").
Map<String, SfxDef> buildProcSfx() {
  SfxDef proc(List<SfxTone> v) => SfxDef(v, peak: SfxLevel.proc);
  SfxDef hit(List<SfxTone> v) => SfxDef(v, peak: SfxLevel.impact);

  return {
    // Rebotes: un "zip" que sube con cada salto.
    for (var h = 0; h <= Sfx.maxZip; h++)
      Sfx.zip(h): proc([
        _t(600 * [1.0, 1.26, 1.5][h], 0.09,
            w: _sq, to: 2400 * [1.0, 1.26, 1.5][h], vr: 30, vd: 0.1, v: 0.35),
        _n(14000, 0.05, crush: 2, v: 0.35, seed: 5 + h),
      ]),
    // Combustión: golpe grave de fuego.
    Sfx.whump: hit([
      _t(90, 0.35, w: _sin, to: 40, v: 0.8),
      _n(900, 0.3, lp: 500, v: 0.6),
      _t(60, 0.25, w: _tri, crush: 3, v: 0.3),
      ..._crackle(1, 0.06),
    ]),
    // Contraataque: metal contra metal.
    Sfx.clang: hit([
      _t(1760, 0.02, w: _sq, v: 0.4),
      _t(1320, 0.35, w: _sin, to: 1300, a: 0.002, v: 0.45),
      _t(2980, 0.25, w: _sin, to: 2940, a: 0.002, v: 0.3),
      _t(4410, 0.15, w: _sin, a: 0.002, v: 0.15),
      _n(12000, 0.02, v: 0.4, seed: 17),
      _t(220, 0.08, w: _tri, to: 160, v: 0.35),
    ]),
    // Castigo Divino: campana (parciales inarmónicos).
    Sfx.bell: hit([
      _t(523, 0.9, w: _sin, a: 0.003, v: 0.35),
      _t(1047, 0.9, w: _sin, a: 0.003, vr: 5, vd: 0.004, v: 0.4),
      _t(2890, 0.6, w: _sin, a: 0.003, v: 0.18),
      _t(5650, 0.3, w: _sin, a: 0.003, v: 0.08),
      _n(9000, 0.02, v: 0.2, seed: 21),
    ]),
    Sfx.frenzyWhoosh: proc([
      ..._whoosh(1.4, 0.7),
      ..._whoosh(1.7, 0.5, 0.05),
    ]),
    Sfx.flare: proc([
      _t(180, 0.25, w: _saw, to: 360, lp: 2000, v: 0.45),
      _n(3000, 0.2, to: 6000, lp: 4000, a: 0.05, v: 0.35),
    ]),
    Sfx.mark: proc([
      _t(2400, 0.02, w: _sq, v: 0.35),
      _t(3200, 0.02, w: _sq, v: 0.35, at: 0.07),
      _t(1600, 0.12, w: _sin, v: 0.4, at: 0.07),
    ]),
    Sfx.weaken: proc([
      _t(600, 0.3, w: _tri, to: 220, v: 0.45),
      _t(300, 0.3, w: _sin, to: 150, vr: 6, vd: 0.05, v: 0.35),
    ]),
    // Escudo: vidrio que se arma / que se quiebra.
    Sfx.shieldUp: proc([
      _t(400, 0.18, w: _tri, to: 1200, v: 0.4),
      _t(1568, 0.4, w: _sin, at: 0.12, vr: 7, vd: 0.01, v: 0.3),
      _t(2093, 0.4, w: _sin, at: 0.14, vr: 7, vd: 0.01, v: 0.25),
    ]),
    Sfx.shieldBreak: hit([
      _n(16000, 0.06, v: 0.5, seed: 19),
      _t(3136, 0.12, w: _tri, v: 0.35),
      _t(4186, 0.1, w: _tri, at: 0.02, v: 0.3),
      _t(2637, 0.14, w: _tri, at: 0.04, v: 0.3),
      _t(220, 0.05, w: _sq, v: 0.3),
    ]),
    // Danza de Cuchillas: barrido al revés + reloj + campanitas.
    Sfx.extraTurn: SfxDef([
      _t(400, 0.25, w: _sin, to: 1600, a: 0.2, v: 0.4),
      _t(2000, 0.015, w: _sq, at: 0.05, v: 0.35),
      _t(2000, 0.015, w: _sq, at: 0.15, v: 0.35),
      ..._arp([1568, 2093, 3136], step: 0.04, d: 0.1, w: _sq, v: 0.3, at: 0.22),
    ], peak: SfxLevel.extraTurn),
    Sfx.heartbeat: proc([
      _t(70, 0.14, w: _sin, to: 45, v: 0.9),
      _t(140, 0.08, w: _tri, to: 90, v: 0.3),
      _t(70, 0.14, w: _sin, to: 45, v: 0.7, at: 0.2),
      _t(140, 0.08, w: _tri, to: 90, v: 0.25, at: 0.2),
    ]),
    Sfx.plague: proc([
      ..._bubbles(0.8, 1.2, 4),
      _t(90, 0.4, w: _saw, vr: 5, vd: 0.1, v: 0.25),
    ]),
    Sfx.steam: proc([
      _n(6000, 0.45, to: 9000, lp: 7000, a: 0.02, v: 0.5, seed: 23),
      _n(2000, 0.2, lp: 1500, v: 0.35, seed: 29),
    ]),
    Sfx.ultCharge: proc([
      ..._arp([1319, 1760, 2349], step: 0.035, d: 0.07, w: _sq, v: 0.25),
      _t(2637, 0.15, w: _sin, at: 0.1, v: 0.3),
    ]),
    Sfx.anvil: proc([
      _t(1100, 0.02, w: _sq, v: 0.4),
      _t(880, 0.25, w: _tri, vr: 9, vd: 0.12, v: 0.4),
      _t(2200, 0.12, w: _sin, v: 0.25),
    ]),
    Sfx.wind: proc(_wind(1.3, 0.6)),
    // Eco Arcano: cada firma de habilidad con eco.
    for (final e in kSkillVoices.entries)
      Sfx.echo(e.key): SfxDef(_echo(e.value), peak: SfxLevel.status),
  };
}

// ------------------------------------------------------------ ultimates

/// Las tres partes del sonido de una ULT ("@t" relativo al inicio de
/// cada parte; la parte se toca en el ms de su fase del guion).
typedef UltVoices = ({
  List<SfxTone> build,
  List<SfxTone> release,
  List<SfxTone> impact,
});

/// Sonido de cada ULT por `SkillDef.id` (docs/specs/audio.md
/// § "Ultimates").
final Map<String, UltVoices> kUltVoices = {
  // Tajo Final: viento que sube + brillo de la hoja; tres tajos; tajo
  // pesado con campanazo.
  'ult_espada': (
    build: [
      _n(2000, 0.75, to: 7000, a: 0.5, lp: 4000, v: 0.4, seed: 11),
      _t(98, 0.7, w: _saw, a: 0.4, lp: 600, v: 0.25),
      _t(2637, 0.18, w: _tri, at: 0.62, vr: 9, vd: 0.01, v: 0.35),
      _t(3951, 0.16, w: _sin, at: 0.64, v: 0.25),
    ],
    release: [
      _n(3000, 0.5, to: 9000, at: 0.05, a: 0.45, lp: 6000, v: 0.25, seed: 5),
      for (final at in [0.2, 0.32, 0.44]) ..._x(_swingBlade(1.3, 0.9), dt: at),
    ],
    impact: [
      _n(12000, 0.25, to: 2000, v: 0.6),
      _t(110, 0.5, w: _sin, to: 35, v: 0.7),
      _t(1568, 0.6, w: _tri, to: 1520, v: 0.25),
      _t(3951, 0.4, w: _sin, to: 3830, v: 0.15),
      _n(800, 0.6, lp: 400, at: 0.03, v: 0.4),
    ],
  ),
  // Cataclismo: retumbo que crece; golpe al piso y crujidos; estallido.
  'ult_hacha': (
    build: [
      _t(38, 0.9, w: _sin, a: 0.7, v: 0.6),
      _n(700, 0.9, lp: 300, a: 0.7, v: 0.6),
      for (var k = 0; k < 5; k++)
        _n(5000, 0.03, crush: 3, at: 0.15 + k * 0.13, v: 0.25, seed: 3 + k),
    ],
    release: [
      _t(90, 0.35, w: _sin, to: 30, at: 0.05, v: 0.8),
      _n(2000, 0.25, lp: 900, at: 0.05, v: 0.6),
      _t(55, 0.4, w: _tri, crush: 3, at: 0.1, v: 0.3),
      for (var k = 0; k < 5; k++)
        _n(9000, 0.06, crush: 3, at: 0.12 + k * 0.07, v: 0.35, seed: 7 + k),
    ],
    impact: [
      _n(1200, 0.9, lp: 900, v: 0.7),
      _t(60, 0.8, w: _sin, to: 22, v: 0.8),
      for (var k = 0; k < 5; k++)
        _n(6000, 0.08, crush: 3, at: 0.1 + k * 0.09, v: 0.3, seed: 2 + k),
    ],
  ),
  // Meteoro: dron ominoso con fuego; silbido que cae; explosión.
  'ult_baculo': (
    build: [
      _t(55, 0.9, w: _saw, to: 110, vr: 5, vd: 0.04, a: 0.5, lp: 900, v: 0.5),
      _t(82.5, 0.9, w: _saw, to: 165, a: 0.6, lp: 900, v: 0.3),
      _n(1500, 0.8, to: 4000, lp: 2500, a: 0.6, v: 0.3),
      ..._crackle(2.5, 0.2),
    ],
    release: [
      _t(1800, 0.45, w: _sin, to: 300, v: 0.4),
      _t(1200, 0.4, w: _sin, to: 220, at: 0.12, v: 0.25),
      _n(1500, 0.5, to: 6000, lp: 3500, a: 0.4, v: 0.45, seed: 3),
    ],
    impact: [
      _n(1500, 0.7, lp: 1200, v: 0.8),
      _t(70, 0.6, w: _sin, to: 28, v: 0.8),
      ..._crackle(2, 0.05),
    ],
  ),
  // Paradoja: tic-tac que se acelera + barrido al revés; oleaje inverso;
  // cristal que se congela y estalla.
  'ult_tomo': (
    build: [
      for (final at in [0.05, 0.17, 0.28, 0.38, 0.47, 0.55, 0.62, 0.68, 0.73, 0.77, 0.8])
        _t(2000, 0.015, w: _sq, at: at, v: 0.4),
      _t(900, 0.85, w: _pu, to: 150, crush: 4, vr: 6, vd: 0.05, v: 0.3),
      _t(400, 0.7, w: _sin, to: 1200, a: 0.6, vr: 7, vd: 0.03, v: 0.2),
    ],
    release: [
      _n(600, 0.55, to: 6000, a: 0.5, lp: 4000, v: 0.5, seed: 9),
      ..._arp([3136, 2637, 2093, 1568], step: 0.1, d: 0.15, v: 0.25),
    ],
    impact: [
      _t(3136, 0.5, w: _tri, v: 0.4),
      _t(3951, 0.45, w: _tri, at: 0.02, v: 0.3),
      _t(4699, 0.4, w: _tri, at: 0.04, v: 0.25),
      _n(16000, 0.12, v: 0.5),
      _t(2093, 0.6, w: _sin, vr: 6, vd: 0.02, v: 0.25),
    ],
  ),
  // Tormenta de Flechas: cuerda + andanada al cielo; lluvia; ráfaga de
  // impactos con burbujas.
  'ult_arco': (
    build: [
      _t(220, 0.35, w: _tri, to: 180, vr: 12, vd: 0.04, v: 0.4),
      for (var k = 0; k < 5; k++)
        ..._x(_whoosh(1.0 + k * 0.12, 0.8), dt: 0.3 + k * 0.06),
    ],
    release: [
      _n(4000, 1.1, to: 2500, lp: 3000, a: 0.3, v: 0.25, seed: 13),
      for (var k = 0; k < 14; k++)
        _n(7000, 0.03, at: 0.1 + k * 0.075 + (k % 3) * 0.01, v: 0.35, seed: k + 1),
    ],
    impact: [
      for (var k = 0; k < 4; k++) _n(7000, 0.04, at: k * 0.05, v: 0.5, seed: k + 20),
      _t(620, 0.05, w: _sq, to: 180, v: 0.35),
      ..._x(_bubbles(1, 1.2), dt: 0.08),
    ],
  ),
  // Disparo Letal: carga + cerrojo; estampido y vuelo lento; impacto con
  // ping metálico.
  'ult_rifle': (
    build: [
      _t(300, 0.8, w: _sin, to: 2400, vr: 9, vd: 0.03, v: 0.35),
      _t(600, 0.8, w: _sq, to: 4800, a: 0.6, v: 0.06),
      _n(15000, 0.02, at: 0.72, v: 0.5, seed: 4),
      _t(1200, 0.03, w: _sq, at: 0.74, v: 0.3),
    ],
    release: [
      _n(20000, 0.05, at: 0.05, v: 0.9),
      _n(2000, 0.5, to: 500, lp: 1500, at: 0.05, v: 0.7, seed: 9),
      _t(120, 0.3, w: _sq, to: 40, at: 0.05, v: 0.6),
      _n(4000, 0.4, to: 800, lp: 2000, at: 0.08, a: 0.1, v: 0.35, seed: 6),
    ],
    impact: [
      _n(18000, 0.06, v: 0.7),
      _t(1760, 0.5, w: _sin, to: 1720, v: 0.35),
      _t(4435, 0.35, w: _sin, to: 4320, v: 0.2),
      _t(90, 0.3, w: _sin, to: 35, v: 0.7),
    ],
  ),
  // Baluarte: acorde que se hincha; escudo + cúpula; campanas de cura.
  'ult_espada_escudo': (
    build: [
      for (final f in [196.0, 247.0, 294.0])
        _t(f, 0.8, w: _saw, a: 0.6, lp: 1200, v: 0.25),
      _t(98, 0.8, w: _tri, a: 0.5, v: 0.3),
    ],
    release: [
      ..._shieldRing(0.8),
      for (final f in [392.0, 587.0, 784.0])
        _t(f, 0.9, w: _sin, a: 0.2, vr: 3, vd: 0.01, at: 0.05, v: 0.25),
    ],
    impact: [
      ..._arp([1047, 1319, 1568, 2093], step: 0.06, d: 0.25, w: _sin, v: 0.4),
      ..._x(_holy(1.2, 0.8), dt: 0.2),
    ],
  ),
  // Juicio Divino: coro; campana que baja + puntería; pilar de luz.
  'ult_maza_escudo': (
    build: [
      for (final f in [523.0, 659.0, 784.0])
        _t(f, 0.85, w: _sin, a: 0.5, vr: 5, vd: 0.012, v: 0.3),
      _t(2093, 0.3, w: _sin, at: 0.55, vr: 7, vd: 0.01, v: 0.2),
    ],
    release: [
      _t(1568, 0.5, w: _sin, to: 784, v: 0.35),
      _t(400, 0.4, w: _tri, to: 1600, at: 0.02, v: 0.2),
    ],
    impact: [
      ..._holy(0.9, 1.5),
      _n(3000, 0.35, to: 9000, lp: 6000, v: 0.45),
      _t(80, 0.5, w: _sin, to: 30, v: 0.6),
    ],
  ),
  // Martillo Celestial: trueno y chispas; caída; golpe brutal con mareo.
  'ult_martillo_escudo': (
    build: [
      _n(400, 0.9, lp: 250, a: 0.3, v: 0.6),
      for (var k = 0; k < 4; k++)
        _n(20000, 0.06, crush: 2, at: 0.1 + k * 0.2, v: 0.3, seed: k + 5),
      _t(200, 0.85, w: _sq, to: 800, a: 0.5, lp: 1500, v: 0.2),
    ],
    release: [
      _n(6000, 0.3, to: 600, lp: 4000, at: 0.1, a: 0.15, v: 0.55, seed: 3),
      _t(800, 0.3, w: _tri, to: 150, at: 0.1, v: 0.2),
    ],
    impact: [
      _t(80, 1.0, w: _sin, to: 22, v: 0.9),
      _n(1000, 0.7, lp: 700, v: 0.7),
      _t(1200, 0.4, w: _tri, to: 1150, v: 0.2),
      _t(3030, 0.3, w: _sin, to: 2950, v: 0.12),
      _t(1000, 0.5, w: _tri, vr: 9, vd: 0.15, at: 0.25, v: 0.2),
    ],
  ),
  // ---- loot v2 (kNewUltimates) ----
  // Lluvia de Lanzas: giro metálico que sube; lanzas al cielo que caen
  // silbando; clavadas.
  'ult_lanza': (
    build: [
      _n(3000, 0.75, to: 8000, a: 0.45, lp: 5000, v: 0.35, seed: 14),
      _t(1760, 0.7, w: _tri, vr: 14, vd: 0.02, a: 0.3, v: 0.25),
      _t(110, 0.7, w: _saw, to: 165, a: 0.4, lp: 700, v: 0.2),
    ],
    release: [
      for (var k = 0; k < 6; k++)
        ..._x(_whoosh(1.0 + k * 0.1, 0.6), dt: 0.02 + k * 0.05),
      for (var k = 0; k < 4; k++)
        _t(2400 - k * 150, 0.4, w: _sin, to: 600, at: 0.3 + k * 0.12, v: 0.2),
    ],
    impact: [
      for (var k = 0; k < 3; k++) ...[
        _n(10000, 0.04, at: k * 0.06, v: 0.5, seed: 30 + k),
        _t(240, 0.12, w: _tri, to: 70, at: k * 0.06, v: 0.45),
      ],
      _t(1245, 0.4, w: _tri, to: 1220, at: 0.04, v: 0.2),
      _t(55, 0.4, w: _sin, to: 30, v: 0.5),
    ],
  ),
  // Tormenta Arcana: zumbido arcano que gira y sube; lluvia de chispas
  // arcanas; estallido cristalino.
  'ult_varita': (
    build: [
      _t(220, 0.8, w: _pu, to: 440, vr: 6, vd: 0.06, a: 0.5, v: 0.3),
      _t(440, 0.75, w: _sin, to: 1760, a: 0.5, vr: 9, vd: 0.02, v: 0.25),
      for (var k = 0; k < 4; k++)
        _n(18000, 0.04, crush: 2, at: 0.2 + k * 0.15, v: 0.2, seed: 40 + k),
    ],
    release: [
      for (var k = 0; k < 10; k++)
        _t(1600.0 + (k % 3) * 300, 0.06, w: _sq, to: 3200.0 + (k % 4) * 200,
            at: 0.05 + k * 0.08, v: 0.22),
      _n(5000, 0.9, to: 2500, lp: 4000, a: 0.3, v: 0.2, seed: 41),
    ],
    impact: [
      _t(1200, 0.25, w: _pu, to: 300, crush: 4, v: 0.45),
      _n(12000, 0.08, v: 0.45, seed: 42),
      _t(880, 0.5, w: _sin, vr: 8, vd: 0.02, at: 0.05, v: 0.25),
      _t(2637, 0.35, w: _tri, at: 0.06, v: 0.2),
    ],
  ),
  // Andanada: manivela que tensa la ballesta; cuerda pesada y virote que
  // silba; impacto brutal con mareo.
  'ult_ballesta': (
    build: [
      for (final at in [0.05, 0.2, 0.33, 0.44, 0.53, 0.6, 0.66, 0.71])
        _t(600, 0.02, w: _sq, at: at, v: 0.35),
      _t(120, 0.85, w: _tri, to: 180, vr: 5, vd: 0.05, a: 0.4, v: 0.3),
      _n(15000, 0.03, at: 0.8, v: 0.4, seed: 50),
    ],
    release: [
      _n(20000, 0.03, at: 0.05, v: 0.7, seed: 51),
      _t(160, 0.25, w: _tri, to: 90, vr: 25, vd: 0.06, at: 0.05, v: 0.6),
      _n(6000, 0.4, to: 2000, lp: 4000, at: 0.08, a: 0.05, v: 0.4, seed: 52),
    ],
    impact: [
      _n(6000, 0.08, v: 0.6),
      _t(90, 0.7, w: _sin, to: 28, v: 0.8),
      _n(2000, 0.5, lp: 1000, v: 0.55, seed: 53),
      _t(1000, 0.5, w: _tri, vr: 9, vd: 0.15, at: 0.2, v: 0.2),
    ],
  ),
  // Danza de Mil Cortes: latido y hojas que se desenvainan; ráfaga de
  // cortes; el corte final cruzado con clink.
  'ult_dagas': (
    build: [
      _t(60, 0.15, w: _sin, to: 45, v: 0.6),
      _t(60, 0.15, w: _sin, to: 45, at: 0.22, v: 0.6),
      _t(3520, 0.2, w: _tri, at: 0.35, vr: 9, vd: 0.01, v: 0.2),
      ..._x(_swingBlade(1.6, 0.5), dt: 0.45),
      _t(4186, 0.18, w: _sin, at: 0.55, v: 0.2),
    ],
    release: [
      for (var k = 0; k < 12; k++)
        ..._x(_swingBlade(1.25 + (k % 3) * 0.12, 0.45), dt: 0.08 + k * 0.06),
    ],
    impact: [
      _n(14000, 0.2, to: 3000, v: 0.6),
      _t(2349, 0.3, w: _sin, to: 2300, a: 0.002, v: 0.3),
      _t(5919, 0.2, w: _sin, to: 5800, a: 0.002, v: 0.15),
      _t(100, 0.4, w: _sin, to: 35, v: 0.6),
    ],
  ),
};

// ----------------------------------------------------------------- loot

/// Sonidos del loot en el mapa (docs/specs/audio.md § "Loot"): uno por
/// nombre de `kLootFilterSounds`, levantar y el haz del Legendario.
Map<String, SfxDef> buildLootSfx() {
  SfxDef l(List<SfxTone> v) => SfxDef(v, peak: SfxLevel.loot);
  return {
    // Dos tonos de aviso.
    Sfx.loot('alerta'): l([
      _t(880, 0.08, w: _sq, v: 0.35),
      _t(1175, 0.12, w: _sq, at: 0.09, v: 0.35),
    ]),
    // Campana inarmónica que se apaga.
    Sfx.loot('campana'): l([
      _t(1319, 0.7, w: _sin, to: 1300, a: 0.003, v: 0.5),
      _t(3317, 0.45, w: _sin, to: 3280, a: 0.003, v: 0.22),
      _t(659, 0.5, w: _tri, v: 0.15),
    ]),
    // Destello de gema: arpegio agudo.
    Sfx.loot('gema'): l([
      ..._arp([2093, 2637, 3136, 4186], step: 0.045, d: 0.14),
      _t(4186, 0.3, w: _sin, at: 0.18, vr: 8, vd: 0.01, v: 0.2),
    ]),
    // Fanfarria corta.
    Sfx.loot('legendario'): l([
      ..._arp([523, 659, 784], step: 0.08, d: 0.1, w: _sq, v: 0.3),
      for (final f in [1047.0, 1319.0, 1568.0])
        _t(f, 0.6, w: _sq, at: 0.24, vr: 6, vd: 0.01, v: 0.2),
    ]),
    // Clink de material.
    Sfx.loot('material'): l([
      _t(1568, 0.12, w: _tri, v: 0.4),
      _t(1976, 0.16, w: _tri, at: 0.05, v: 0.3),
    ]),
    Sfx.loot('suave'): l([_t(660, 0.18, w: _sin, to: 880, a: 0.02, v: 0.4)]),
    Sfx.lootPickup: l([
      _t(700, 0.06, w: _sin, to: 1400, v: 0.45),
      _t(1760, 0.05, w: _tri, at: 0.05, v: 0.3),
    ]),
    // Haz de luz: ruido que sube + tono que trepa + brillo.
    Sfx.lootBeam: SfxDef([
      _n(2000, 0.6, to: 8000, a: 0.2, lp: 5000, v: 0.4, seed: 12),
      _t(220, 0.7, w: _saw, to: 880, a: 0.1, lp: 2000, v: 0.3),
      _t(1760, 0.5, w: _sin, at: 0.35, vr: 7, vd: 0.01, v: 0.25),
      _t(2637, 0.45, w: _sin, at: 0.4, vr: 7, vd: 0.01, v: 0.2),
    ], peak: SfxLevel.lootBeam),
  };
}

// ------------------------------------------- quiebre y ULT enemigas

/// Quiebre, aviso y ULT enemigas (docs/specs/audio.md § "Quiebre y ULT
/// enemigas").
Map<String, SfxDef> buildBreakSfx() => {
      // Tic de la barra: vidrio chico, muy suave.
      Sfx.breakTick: SfxDef([
        _t(2349, 0.04, w: _tri, a: 0.002, v: 0.5),
        _t(3520, 0.05, w: _sin, at: 0.01, v: 0.3),
      ], peak: SfxLevel.breakTick),
      // ¡QUIEBRE!: golpe sordo + cristal que estalla en astillas.
      Sfx.breakShatter: SfxDef([
        _t(110, 0.28, w: _sin, to: 38, v: 0.8),
        _n(16000, 0.09, v: 0.7, seed: 97),
        _n(3000, 0.25, to: 900, lp: 2500, v: 0.4, seed: 101),
        for (var k = 0; k < 7; k++)
          _t(const [3136.0, 4186.0, 2637.0, 3951.0, 4699.0, 3520.0, 5274.0][k], 0.12 + (k % 3) * 0.05,
              w: _tri, a: 0.002, at: 0.02 + k * 0.035, v: 0.3),
        _t(1500, 0.35, w: _sin, to: 3000, at: 0.05, v: 0.15),
      ], peak: SfxLevel.breakShatter),
      // Golpe a un quebrado: "ting" brillante encima del impacto.
      Sfx.breakVuln: SfxDef([
        _t(1760, 0.06, w: _sq, to: 2349, v: 0.35),
        _t(3520, 0.14, w: _sin, at: 0.02, a: 0.002, v: 0.4),
        _n(14000, 0.02, v: 0.3, seed: 103),
      ], peak: SfxLevel.breakVuln),
      // Quebrado pierde el turno: mareo con campanitas de vidrio.
      Sfx.breakDazed: SfxDef([
        _t(900, 0.4, w: _tri, vr: 9, vd: 0.15, v: 0.4),
        for (final at in [0.05, 0.17, 0.29]) _t(3136, 0.06, w: _tri, at: at, v: 0.25),
      ], peak: SfxLevel.status),
      // Aviso de ULT enemiga: alarma de dos tonos + dron grave que crece.
      Sfx.enemyUltWarn: SfxDef([
        for (var k = 0; k < 4; k++)
          _t(k.isEven ? 880 : 622, 0.1, w: _saw, at: k * 0.11, lp: 2500, v: 0.4),
        _t(55, 0.7, w: _sin, a: 0.3, vr: 6, vd: 0.05, v: 0.6),
        _n(400, 0.7, to: 1600, lp: 900, a: 0.5, v: 0.4, seed: 107),
      ], peak: SfxLevel.enemyUltWarn),
      ...buildBossMechanicSfx(),
      for (final e in kEnemyUltVoices.entries) ...{
        Sfx.ult(e.key, Sfx.ultBuild):
            SfxDef(e.value.build, peak: SfxLevel.ultBuild),
        Sfx.ult(e.key, Sfx.ultRelease):
            SfxDef(e.value.release, peak: SfxLevel.ultRelease),
        Sfx.ult(e.key, Sfx.ultImpact):
            SfxDef(e.value.impact, peak: SfxLevel.ultImpact),
      },
    };

/// Mecánicas de los jefes v0.2 (docs/specs/audio.md § "Mecánicas de
/// jefe").
Map<String, SfxDef> buildBossMechanicSfx() => {
      // ---- v0.3 (docs/specs/audio.md § "Mecánicas de jefe v0.3") ----
      // Eco que aparece: acorde que se desdobla (dos voces desafinadas).
      Sfx.echoSummon: SfxDef([
        ..._arp([523, 659, 784, 1047], step: 0.05, d: 0.2, w: _sin, v: 0.3),
        ..._arp([554, 698, 831, 1109], step: 0.05, d: 0.2, w: _sin, at: 0.08, v: 0.2),
        _n(8000, 0.4, to: 3000, lp: 6000, a: 0.2, v: 0.2, seed: 501),
      ], peak: SfxLevel.status),
      // Golpe a un eco: tintineo hueco (el daño se va al vacío).
      Sfx.echoResist: SfxDef([
        _t(1480, 0.18, w: _sin, vr: 14, vd: 0.05, v: 0.35),
        _t(740, 0.18, w: _tri, at: 0.02, v: 0.2),
      ], peak: SfxLevel.status),
      // La lava sube: rugido de tierra + burbujeo grave.
      Sfx.lavaRise: SfxDef([
        ..._rumble(0.8, 1.4),
        ..._x(_bubbles(0.5, 1.4, 5), dt: 0.15),
        _n(1500, 0.6, to: 4000, lp: 2500, a: 0.3, v: 0.35, seed: 503),
      ], peak: SfxLevel.heavy),
      // La lava quema al que se defiende: chisporroteo + siseo.
      Sfx.lavaBurn: SfxDef([
        _n(5000, 0.35, to: 9000, lp: 7000, a: 0.02, v: 0.5, seed: 505),
        ..._fire(1.1, 0.7, 507),
        ..._crackle(0.8, 0.05),
      ], peak: SfxLevel.impact),
      // La lava se enfría: vapor que baja.
      Sfx.lavaFade: SfxDef([
        _n(6000, 0.5, to: 1500, lp: 4000, a: 0.05, v: 0.35, seed: 509),
        _t(300, 0.3, w: _sin, to: 150, at: 0.1, v: 0.2),
      ], peak: SfxLevel.status),
      // Invocación del séquito: campana fúnebre + lamento que sube.
      Sfx.summon: SfxDef([
        _t(196, 0.8, w: _sin, a: 0.002, vr: 4, vd: 0.01, v: 0.45),
        _t(392, 0.6, w: _tri, a: 0.002, v: 0.2),
        _t(330, 0.5, w: _sin, to: 660, a: 0.2, at: 0.1, vr: 7, vd: 0.03, v: 0.25),
      ], peak: SfxLevel.status),
      // Inmune: estado que rebota contra el escudo del séquito.
      Sfx.immune: SfxDef([
        _t(1319, 0.08, w: _sq, to: 988, v: 0.3),
        _t(2637, 0.25, w: _sin, a: 0.002, at: 0.02, v: 0.3),
        _n(10000, 0.05, v: 0.25, seed: 511),
      ], peak: SfxLevel.status),
      // Marca del Vacío: zumbido que fija el objetivo + "bip" de mira.
      Sfx.markCast: SfxDef([
        _t(110, 0.5, w: _saw, to: 220, a: 0.2, lp: 900, vr: 6, vd: 0.05, v: 0.35),
        for (final at in [0.2, 0.32, 0.44]) _t(1760, 0.05, w: _sq, at: at, v: 0.25),
        _t(2637, 0.2, w: _sin, at: 0.5, v: 0.3),
      ], peak: SfxLevel.status),
      // Golpe al marcado: implosión del vacío encima del impacto.
      Sfx.markHit: SfxDef([
        _t(40, 0.5, w: _sin, to: 18, v: 0.9),
        _n(2000, 0.2, to: 400, lp: 1500, v: 0.55, seed: 513),
        _t(880, 0.3, w: _sq, to: 110, crush: 3, v: 0.2),
      ], peak: SfxLevel.heavy),
      // Marca contrarrestada: escudo que la disipa.
      Sfx.markGuard: SfxDef([
        ..._shieldRing(1.1),
        ..._arp([784, 1047, 1319], step: 0.05, d: 0.15, w: _sin, at: 0.08, v: 0.3),
      ], peak: SfxLevel.status),
      // Transformación del Devorador: el mundo se quiebra (golpe sordo,
      // vacío que traga y rugido que sube).
      Sfx.phaseShift: SfxDef([
        _t(30, 1.6, w: _sin, to: 60, a: 0.6, v: 0.7),
        _n(400, 1.4, to: 200, lp: 400, a: 0.8, v: 0.5, seed: 515),
        _t(55, 0.6, w: _saw, to: 110, at: 0.9, vr: 10, vd: 0.12, lp: 900, v: 0.5),
        _t(220, 0.7, w: _sin, to: 40, at: 0.9, v: 0.55),
        _n(16000, 0.15, at: 0.9, v: 0.5, seed: 517),
      ], peak: SfxLevel.enemyUltWarn),
      // Esquiva de un común: silbido que pasa de largo.
      Sfx.evade: SfxDef([
        ..._whoosh(1.3, 0.8),
        _t(1200, 0.06, w: _sin, to: 1800, at: 0.04, v: 0.2),
      ], peak: SfxLevel.status),
      // Cartel de entrada: golpe grave + acorde menor de metales.
      Sfx.bossIntro: SfxDef([
        _t(55, 0.9, w: _sin, to: 40, v: 0.7),
        _n(600, 0.6, lp: 500, a: 0.02, v: 0.4, seed: 301),
        for (final (k, f) in [(0, 220.0), (1, 262.0), (2, 330.0)])
          _t(f, 0.8, w: _saw, a: 0.05 + k * 0.04, lp: 1400, vr: 5, vd: 0.01, v: 0.25),
        _t(110, 0.9, w: _sq, a: 0.3, lp: 600, v: 0.2),
      ], peak: SfxLevel.enemyUltWarn),
      // Telaraña: hilo que vuela (silbido) y se pega (chasquido húmedo).
      Sfx.webCast: SfxDef([
        _n(6000, 0.18, to: 2500, lp: 5000, a: 0.04, v: 0.4, seed: 303),
        _t(1200, 0.12, w: _tri, to: 500, v: 0.25),
        _n(1500, 0.08, lp: 900, v: 0.5, at: 0.16, seed: 307),
        _t(300, 0.1, w: _sin, to: 150, v: 0.4, at: 0.16),
      ], peak: SfxLevel.status),
      // Liberar: hilos que se cortan (dos "snip") + campanita.
      Sfx.webFree: SfxDef([
        _n(12000, 0.03, v: 0.5, seed: 309),
        _n(12000, 0.03, v: 0.45, at: 0.06, seed: 311),
        ..._arp([1319, 1760], step: 0.06, d: 0.1, at: 0.1, v: 0.3),
      ], peak: SfxLevel.status),
      // Atrapado: forcejeo (cuerda tensa que vibra).
      Sfx.webStuck: SfxDef([
        _t(180, 0.35, w: _tri, vr: 12, vd: 0.12, v: 0.45),
        _n(2000, 0.3, lp: 1200, a: 0.05, v: 0.25, seed: 313),
      ], peak: SfxLevel.status),
      // Campo Helado: viento frío + cristales que crecen.
      Sfx.frost: SfxDef([
        ..._wind(0.8, 0.8),
        ..._x(_ice(0.8, 1), dt: 0.08, g: 0.7),
      ], peak: SfxLevel.status),
      // Deshielo: goteo y acorde que sube.
      Sfx.thaw: SfxDef([
        for (var k = 0; k < 4; k++) _t(900 - k * 60, 0.05, w: _sin, to: 500, at: k * 0.07, v: 0.3),
        ..._arp([523, 659, 784, 1047], step: 0.06, d: 0.18, w: _sin, at: 0.1, v: 0.3),
      ], peak: SfxLevel.status),
      // Cristal roto: estallido de vidrio.
      Sfx.crystalBreak: SfxDef([
        _n(15000, 0.08, v: 0.7, seed: 317),
        for (var k = 0; k < 5; k++)
          _t(const [3951.0, 3136.0, 4699.0, 2637.0, 5274.0][k], 0.1, w: _tri, at: 0.01 + k * 0.03, v: 0.3),
        _t(140, 0.15, w: _sin, to: 60, v: 0.45),
      ], peak: SfxLevel.impact),
      // Cristal que se reforma: cristales al revés (de grave a agudo).
      Sfx.crystalReform: SfxDef([
        ..._arp([1568, 2093, 2637, 3136], step: 0.05, d: 0.15, at: 0, v: 0.3),
        _n(4000, 0.3, to: 12000, lp: 9000, a: 0.25, v: 0.25, seed: 319),
      ], peak: SfxLevel.status),
      // Cambio de postura: metal que gira y queda en guardia.
      Sfx.stanceShift: SfxDef([
        _n(3000, 0.2, to: 8000, lp: 6000, a: 0.08, v: 0.4, seed: 321),
        _t(220, 0.05, w: _sq, at: 0.2, v: 0.4),
        _t(1661, 0.35, w: _sin, at: 0.2, a: 0.002, v: 0.3),
        _t(2489, 0.25, w: _sin, at: 0.21, a: 0.002, v: 0.2),
      ], peak: SfxLevel.heavy),
      // La postura bloquea: golpe sordo contra metal ("clonk").
      Sfx.stanceBlock: SfxDef([
        _t(160, 0.12, w: _sq, to: 90, v: 0.45),
        _t(740, 0.2, w: _sin, a: 0.002, v: 0.3),
        _n(2500, 0.05, lp: 1500, v: 0.35, seed: 323),
      ], peak: SfxLevel.impact),
    };

/// Las tres partes de cada ULT enemiga por `EnemyUltDef.id`.
final Map<String, UltVoices> kEnemyUltVoices = {
  ..._kBaseEnemyUltVoices,
  for (final (id, base, p) in _kAbyssUltSfx)
    id: (
      build: _x(_kBaseEnemyUltVoices[base]!.build, p: p),
      release: _x(_kBaseEnemyUltVoices[base]!.release, p: p),
      impact: _x(_kBaseEnemyUltVoices[base]!.impact, p: p),
    ),
  // ULT de élite v2 (ultimates_v2.md § 4.3): la voz del jefe al que se
  // parecen, cada una en su propio tono.
  for (final (i, MapEntry(key: id, value: base)) in kEliteUltLooks.entries.indexed)
    if (_kBaseEnemyUltVoices[base] case final v?)
      id: (
        build: _x(v.build, p: 0.84 + 0.031 * i),
        release: _x(v.release, p: 0.84 + 0.031 * i),
        impact: _x(v.impact, p: 0.84 + 0.031 * i),
      ),
};

final Map<String, UltVoices> _kBaseEnemyUltVoices = {
  // ---- v0.3 ----
  // Coro de Ecos: coro que se multiplica; ondas del canto; resonancia.
  'eult_coro': (
    build: [
      for (var k = 0; k < 4; k++)
        _t(const [523.0, 659.0, 784.0, 988.0][k], 0.95 - k * 0.15,
            w: _sin, a: 0.2, at: k * 0.15, vr: 6, vd: 0.02, v: 0.25),
      for (var k = 0; k < 3; k++)
        _t(const [554.0, 698.0, 831.0][k], 0.6, w: _tri, a: 0.2, at: 0.25 + k * 0.12, vr: 9, vd: 0.03, v: 0.15),
      _n(6000, 0.9, to: 10000, lp: 8000, a: 0.7, v: 0.2, seed: 521),
    ],
    release: [
      for (var k = 0; k < 5; k++)
        _t(1047 + k * 131.0, 0.25, w: _sin, to: 523, at: k * 0.07, v: 0.3),
      _n(3000, 0.6, to: 8000, lp: 6000, a: 0.1, v: 0.3, seed: 523),
    ],
    impact: [
      _t(110, 0.4, w: _sin, to: 40, v: 0.75),
      _t(1568, 0.6, w: _sin, a: 0.002, vr: 6, vd: 0.02, v: 0.3),
      _t(1661, 0.6, w: _sin, a: 0.002, vr: 7, vd: 0.02, v: 0.25),
      _n(12000, 0.08, v: 0.45, seed: 525),
    ],
  ),
  // Erupción Total: la tierra ruge y se agrieta; géiseres y rocas; lava
  // que revienta.
  'eult_erupcion': (
    build: [
      ..._rumble(0.7, 2.0),
      ..._x(_bubbles(0.45, 2.0, 6), dt: 0.1),
      _n(1000, 0.95, to: 3500, lp: 2500, a: 0.8, v: 0.4, seed: 527),
    ],
    release: [
      _n(2500, 0.9, to: 600, lp: 3000, a: 0.03, v: 0.6, seed: 529),
      _t(50, 0.9, w: _saw, to: 35, vr: 7, vd: 0.1, lp: 500, v: 0.45),
      for (var k = 0; k < 6; k++) _t(120 - k * 8.0, 0.08, w: _sq, at: 0.15 + k * 0.1, crush: 3, v: 0.25),
    ],
    impact: [
      _t(45, 0.6, w: _sin, to: 20, v: 0.9),
      ..._fire(0.7, 1.4, 531),
      ..._crackle(1.4, 0.05),
      _n(14000, 0.08, v: 0.5, seed: 533),
    ],
  ),
  // Lamento Eterno: coro de lamentos que gira; ola espectral; manos
  // heladas que atrapan.
  'eult_lamento': (
    build: [
      for (var k = 0; k < 4; k++)
        _t(const [294.0, 349.0, 440.0, 523.0][k], 0.95, w: _sin, to: const [262.0, 311.0, 392.0, 466.0][k],
            a: 0.3, at: k * 0.05, vr: 5 + k.toDouble(), vd: 0.03, v: 0.2),
      _n(1500, 0.95, to: 3000, lp: 2000, a: 0.6, v: 0.3, seed: 535),
    ],
    release: [
      ..._wind(0.9, 1.5),
      _t(660, 0.8, w: _sin, to: 220, a: 0.05, vr: 8, vd: 0.05, v: 0.35),
    ],
    impact: [
      _t(70, 0.4, w: _sin, to: 28, v: 0.8),
      ..._x(_ice(0.9, 1.2), dt: 0.02),
      _t(392, 0.5, w: _sin, to: 196, vr: 9, vd: 0.05, at: 0.08, v: 0.25),
    ],
  ),
  // Colapso del Vacío: el agujero negro se forma y traga la luz; viaja y
  // colapsa; implosión y esquirlas del vacío.
  'eult_colapsoVacio': (
    build: [
      _t(28, 1.05, w: _sin, to: 55, a: 0.8, v: 0.7),
      _n(300, 1.05, to: 1200, lp: 800, a: 0.9, v: 0.45, seed: 537),
      _t(3520, 0.9, w: _sin, to: 880, a: 0.4, v: 0.15),
    ],
    release: [
      _n(1200, 0.5, to: 300, lp: 1000, a: 0.05, v: 0.5, seed: 539),
      _t(880, 0.45, w: _sq, to: 55, crush: 2, v: 0.25),
      _t(40, 0.6, w: _sin, at: 0.35, v: 0.6),
    ],
    impact: [
      _t(35, 0.6, w: _sin, to: 18, v: 0.95),
      _n(16000, 0.1, v: 0.6, seed: 541),
      for (var k = 0; k < 4; k++)
        _t(const [1976.0, 2637.0, 1480.0, 3136.0][k], 0.12, w: _tri, at: 0.02 + k * 0.03, v: 0.25),
      _n(2000, 0.3, to: 500, lp: 1500, at: 0.05, v: 0.4, seed: 543),
    ],
  ),
  // Nido Venenoso: sacos que laten y patas; red que vuela; red que cae
  // y revienta en veneno.
  'eult_nido': (
    build: [
      for (final at in [0.0, 0.25, 0.5, 0.7]) _t(65, 0.12, w: _sin, to: 45, at: at, v: 0.6),
      for (var k = 0; k < 10; k++) _n(6000, 0.015, lp: 4500, at: 0.05 + k * 0.08, v: 0.35, seed: 331),
      _n(4000, 0.85, to: 8000, lp: 6000, a: 0.6, v: 0.3, seed: 333),
    ],
    release: [
      _n(7000, 0.3, to: 2500, lp: 6000, a: 0.03, v: 0.55, seed: 335),
      _t(400, 0.4, w: _tri, to: 900, a: 0.05, vr: 8, vd: 0.05, v: 0.3),
      _n(3000, 0.5, to: 1200, lp: 2500, a: 0.2, at: 0.3, v: 0.35, seed: 337),
    ],
    impact: [
      _n(1500, 0.3, lp: 900, v: 0.7, seed: 339),
      _t(130, 0.35, w: _sin, to: 45, v: 0.75),
      ..._x(_bubbles(0.8, 1.4, 5), dt: 0.06),
      _n(10000, 0.05, v: 0.4, at: 0.02, seed: 341),
    ],
  ),
  // Aliento Glacial: inhalación helada que crece; soplido de ventisca;
  // cristales que encierran.
  'eult_aliento': (
    build: [
      _n(600, 0.95, to: 4000, lp: 3000, a: 0.85, v: 0.55, seed: 343),
      _t(110, 0.95, w: _saw, to: 220, a: 0.7, lp: 800, vr: 5, vd: 0.05, v: 0.35),
      for (var k = 0; k < 5; k++) _t(2093 + k * 300, 0.06, w: _tri, at: 0.4 + k * 0.1, v: 0.2),
    ],
    release: [
      _n(4000, 0.95, to: 9000, lp: 7000, a: 0.08, v: 0.6, seed: 347),
      _n(900, 0.9, lp: 600, a: 0.1, v: 0.4, seed: 349),
      _t(80, 0.8, w: _saw, vr: 9, vd: 0.1, lp: 500, v: 0.3),
    ],
    impact: [
      _t(70, 0.45, w: _sin, to: 28, v: 0.8),
      _n(16000, 0.1, v: 0.6, seed: 351),
      ..._x(_ice(1.1, 1.3), dt: 0.02),
      _t(2093, 0.5, w: _sin, vr: 6, vd: 0.01, at: 0.1, v: 0.25),
    ],
  ),
  // Juicio Hueco: coro hueco y runas; espada que se forma y cae;
  // impacto sagrado-metálico enorme con mareo.
  'eult_juicio': (
    build: [
      for (final f in [147.0, 175.0, 220.0])
        _t(f, 0.9, w: _saw, a: 0.5, lp: 900, vr: 4, vd: 0.01, v: 0.3),
      _t(1245, 0.8, w: _sin, a: 0.3, vr: 6, vd: 0.02, v: 0.2),
      _t(37, 0.9, w: _sin, a: 0.6, v: 0.5),
    ],
    release: [
      _t(2637, 0.4, w: _sin, to: 1319, a: 0.1, v: 0.3),
      _n(2000, 0.5, to: 9000, lp: 7000, a: 0.4, at: 0.1, v: 0.5, seed: 353),
      _t(400, 0.45, w: _sin, to: 1600, a: 0.3, at: 0.05, v: 0.25),
    ],
    impact: [
      _t(55, 0.7, w: _sin, to: 20, v: 0.9),
      _n(9000, 0.12, to: 2000, lp: 8000, v: 0.65, seed: 357),
      _t(523, 0.8, w: _sin, a: 0.002, v: 0.3),
      _t(1397, 0.6, w: _sin, a: 0.002, v: 0.25),
      _t(3322, 0.4, w: _sin, a: 0.002, v: 0.15),
      _t(1000, 0.4, w: _tri, vr: 9, vd: 0.15, at: 0.25, v: 0.3),
    ],
  ),
  // Diluvio Ácido: borboteo que crece; escupitajo y lluvia; salpicón.
  'eult_diluvio': (
    build: [
      ..._x(_bubbles(0.55, 1.6, 5), dt: 0.05),
      ..._x(_bubbles(0.75, 1.2, 4), dt: 0.4),
      _t(60, 0.85, w: _saw, to: 120, a: 0.6, lp: 700, vr: 5, vd: 0.06, v: 0.45),
      _n(700, 0.8, lp: 500, a: 0.6, v: 0.35, seed: 109),
    ],
    release: [
      _t(300, 0.22, w: _sin, to: 900, v: 0.55),
      _n(2500, 0.25, to: 6000, lp: 4000, a: 0.05, v: 0.35, at: 0.02, seed: 113),
      _n(6000, 0.75, lp: 4000, a: 0.25, at: 0.3, v: 0.4, seed: 127),
      for (var k = 0; k < 10; k++)
        _t(700 + (k * 137) % 500, 0.03, w: _sin, to: 300, at: 0.3 + k * 0.06, v: 0.25),
    ],
    impact: [
      _n(2500, 0.45, lp: 1500, v: 0.7, seed: 131),
      _t(120, 0.4, w: _sin, to: 40, v: 0.75),
      ..._x(_bubbles(0.9, 1.3, 4), dt: 0.08),
    ],
  ),
  // Engranaje del Fin: tic-tac y engranaje que rechina; rueda que rueda;
  // campanazo de metal, hielo y el tiempo que se estira.
  'eult_engranaje': (
    build: [
      for (final at in [0.0, 0.14, 0.27, 0.38, 0.48, 0.57, 0.65, 0.72, 0.78, 0.83])
        _t(2200, 0.015, w: _sq, at: at, v: 0.45),
      _t(80, 0.9, w: _saw, vr: 6, vd: 0.08, a: 0.4, lp: 900, v: 0.4),
      _n(1200, 0.8, lp: 700, a: 0.5, v: 0.3, seed: 137),
    ],
    release: [
      _n(1000, 0.48, to: 3000, lp: 2000, a: 0.3, v: 0.5, seed: 139),
      for (var k = 0; k < 8; k++)
        _t(1800 + (k % 2) * 400, 0.012, w: _sq, at: 0.05 + k * 0.055, v: 0.35),
      _t(110, 0.45, w: _tri, to: 70, vr: 12, vd: 0.1, v: 0.35),
    ],
    impact: [
      _t(70, 0.6, w: _sin, to: 25, v: 0.85),
      _t(523, 0.8, w: _sin, a: 0.002, v: 0.3),
      _t(1320, 0.6, w: _sin, a: 0.002, v: 0.35),
      _t(2980, 0.4, w: _sin, a: 0.002, v: 0.2),
      _t(3136, 0.35, w: _tri, at: 0.05, v: 0.3),
      _t(3951, 0.3, w: _tri, at: 0.07, v: 0.25),
      _t(900, 0.7, w: _pu, to: 150, crush: 4, at: 0.15, vr: 6, vd: 0.05, v: 0.3),
    ],
  ),
  // Fin de las Eras: el vacío que traga; rugido que sube y colapso;
  // estallido y los buffs que se rompen como vidrio.
  'eult_finEras': (
    build: [
      _t(30, 1.0, w: _sin, to: 60, a: 0.8, v: 0.7),
      _t(45, 1.0, w: _saw, vr: 4, vd: 0.1, a: 0.7, lp: 500, v: 0.4),
      _n(400, 1.0, to: 200, lp: 400, a: 0.85, v: 0.5, seed: 149),
    ],
    release: [
      _n(300, 0.45, to: 3000, lp: 2500, a: 0.4, v: 0.55, seed: 151),
      _t(80, 0.45, w: _saw, to: 160, a: 0.3, lp: 900, v: 0.4),
      _t(200, 0.35, w: _sin, to: 40, at: 0.4, v: 0.6),
    ],
    impact: [
      _n(1200, 0.9, lp: 900, v: 0.8, seed: 157),
      _t(50, 0.9, w: _sin, to: 20, v: 0.85),
      ..._crackle(2, 0.05),
      for (var k = 0; k < 5; k++)
        _t(const [3136.0, 4186.0, 2637.0, 3951.0, 4699.0][k], 0.1, w: _tri, at: 0.12 + k * 0.04, v: 0.2),
    ],
  ),
  // Furia Élite: gruñido y fuego; embestida y zarpazos; desgarro brutal.
  'eult_furia': (
    build: [
      _t(70, 0.65, w: _saw, to: 140, vr: 20, vd: 0.12, a: 0.4, lp: 1200, v: 0.5),
      ..._x(_fire(0.8, 1.6, 11), dt: 0.1),
    ],
    release: [
      ..._whoosh(0.9, 1.2),
      for (final at in [0.3, 0.37])
        _n(9000, 0.07, to: 3000, lp: 7000, at: at, v: 0.55, seed: 163),
    ],
    impact: [
      for (final at in [0.0, 0.04, 0.08])
        _n(12000, 0.1, to: 2000, lp: 9000, at: at, v: 0.6, seed: 167),
      _t(90, 0.4, w: _sin, to: 30, v: 0.8),
      _t(2093, 0.3, w: _sin, to: 2030, a: 0.002, v: 0.3),
    ],
  ),
};
