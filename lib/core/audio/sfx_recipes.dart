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
};

/// Firma de cada habilidad de `kSkills` (sin el prefijo `skill.`).
final Map<String, List<SfxTone>> kSkillVoices = {
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
  'fortaleza': [
    _t(196, 0.12, w: _sq, v: 0.4),
    _t(262, 0.18, w: _sq, v: 0.4, at: 0.1),
    ..._x(_shieldRing(), dt: 0.15),
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
};

/// Sonido de cada tipo de enemigo de `kEnemies`.
final Map<String, List<SfxTone>> kEnemyVoices = {
  'slime': _slime(),
  'bat': [
    _t(2400, 0.12, w: _sq, to: 3400, vr: 40, vd: 0.05, v: 0.3),
    _t(2800, 0.1, w: _sq, to: 3800, vr: 40, vd: 0.05, v: 0.25, at: 0.1),
  ],
  'golem': _golem(),
  'ghost': [
    _t(520, 0.6, w: _sin, to: 340, a: 0.15, vr: 6, vd: 0.03, v: 0.5),
    _t(780, 0.6, w: _tri, to: 510, a: 0.15, vr: 6, vd: 0.03, v: 0.2),
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

const _kBossTypes = {'reyLimo', 'golemReloj', 'devorador'};

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
    Sfx.enemyGeneric: act([
      _n(5000, 0.12, to: 2000, lp: 4000, v: 0.5),
      _t(300, 0.1, w: _sq, to: 150, v: 0.3),
    ]),
    Sfx.enemyHeavy: heavy([
      _t(60, 0.4, w: _sin, to: 30, v: 0.7),
      _n(2000, 0.3, lp: 600, v: 0.5),
    ]),
    // Los jefes suenan más fuerte que los enemigos comunes.
    for (final e in kEnemyVoices.entries)
      Sfx.enemy(e.key): _kBossTypes.contains(e.key) ? heavy(e.value) : act(e.value),
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
};
