import '../../game_engine/models/elements.dart';
import 'sfx_catalog.dart';

// Sonidos de las reacciones elementales y de los estados nuevos de v0.7
// (docs/specs/elemental_reactions.md § 3 y § 8; docs/specs/audio.md
// § "Reacciones elementales"). Mismo sintetizador que `sfx_recipes.dart`:
// los volúmenes de cada voz son relativos; el nivel final lo fija el pico.

/// Pico de una reacción: por encima de un impacto (se tiene que oír
/// sobre el golpe que la detona) y por debajo del crítico.
const kReactionPeak = SfxLevel.heavy;

SfxTone _t(double f, double d,
        {Waveform w = Waveform.square,
        double? to,
        double v = 0.5,
        double at = 0,
        double a = 0,
        double h = 0,
        double vr = 0,
        double vd = 0,
        double lp = 0,
        int crush = 0}) =>
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

SfxTone _n(double clock, double d,
        {double? to,
        double v = 0.5,
        double at = 0,
        double a = 0,
        double lp = 0,
        int crush = 0,
        int seed = 1}) =>
    SfxTone(clock, d,
        wave: Waveform.noise,
        endFrequency: to,
        volume: v,
        delay: at,
        attack: a,
        lowpass: lp,
        crush: crush,
        seed: seed);

/// Salpicadura corta (agua).
List<SfxTone> _splash({double at = 0, double p = 1}) => [
      _n(3000 * p, 0.12, to: 900 * p, lp: 2500 * p, v: 0.45, at: at, seed: 41),
      _t(700 * p, 0.09, w: Waveform.sine, to: 260 * p, v: 0.35, at: at),
    ];

/// Chasquido eléctrico: ruido crujiente + zumbido con vibrato.
List<SfxTone> _zap({double at = 0, double p = 1, double l = 1}) => [
      _n(12000 * p, 0.16 * l, crush: 2, v: 0.5, at: at, seed: 53),
      _t(180 * p, 0.22 * l,
          w: Waveform.sawtooth, vr: 38, vd: 0.25, v: 0.35, at: at),
      _t(2400 * p, 0.06 * l, w: Waveform.pulse, to: 600 * p, v: 0.3, at: at),
    ];

/// Las cinco reacciones (`sfx.reaction.<kind>`) y el sonido al aplicar
/// Mojado / Cargado (`status.wet`, `status.charged`).
Map<String, SfxDef> buildReactionSfx() {
  SfxDef r(List<SfxTone> v) => SfxDef(v, peak: kReactionPeak);
  SfxDef st(List<SfxTone> v) => SfxDef(v, peak: SfxLevel.status);
  return {
    // Agua + Electro: chispazo sobre la salpicadura y zumbido del
    // aturdido.
    ReactionKind.electrocucion.sfxId: r([
      ..._splash(p: 1.1),
      ..._zap(at: 0.03),
      ..._zap(at: 0.16, p: 1.25, l: 0.8),
      _t(1200, 0.3, w: Waveform.square, vr: 14, vd: 0.06, v: 0.18, at: 0.3),
    ]),
    // Veneno + Fuego: burbujas que revientan y un estallido grave.
    ReactionKind.explosionToxica.sfxId: r([
      for (var i = 0; i < 3; i++)
        _t(560 - i * 70.0, 0.05, to: 240, v: 0.3, at: i * 0.035),
      _n(1400, 0.5, to: 300, lp: 900, a: 0.01, v: 0.8, at: 0.1, seed: 61),
      _t(80, 0.5, w: Waveform.sine, to: 34, v: 0.7, at: 0.1),
      _n(5000, 0.35, to: 1500, lp: 3500, v: 0.35, at: 0.14, seed: 67),
      _t(140, 0.3, w: Waveform.triangle, to: 60, crush: 3, v: 0.3, at: 0.12),
    ]),
    // Agua + Hielo: salpicadura que se congela de golpe (cristal + crujido).
    ReactionKind.congelacionSubita.sfxId: r([
      ..._splash(p: 0.9),
      for (var i = 0; i < 4; i++)
        _t(2093.0 * (1 + i * 0.26), 0.16,
            w: Waveform.triangle, v: 0.35, at: 0.06 + i * 0.03),
      _n(9000, 0.08, crush: 3, v: 0.4, at: 0.2, seed: 71),
      _t(3136, 0.35, w: Waveform.sine, v: 0.22, at: 0.2),
    ]),
    // Hielo + Fuego: siseo de vapor y el hielo que cede (barrido grave).
    ReactionKind.derretir.sfxId: r([
      _n(7000, 0.45, to: 3000, lp: 6000, a: 0.03, v: 0.55, seed: 73),
      _t(1760, 0.28, w: Waveform.sine, to: 440, v: 0.35),
      _t(220, 0.3, w: Waveform.sawtooth, to: 110, lp: 900, v: 0.3, at: 0.05),
      _n(2000, 0.15, lp: 1200, v: 0.3, at: 0.2, seed: 79),
    ]),
    // Electro + Agua: dos chispazos que saltan (el segundo más agudo).
    ReactionKind.cortocircuito.sfxId: r([
      ..._splash(p: 1.3),
      ..._zap(at: 0.02, p: 1.1, l: 0.7),
      ..._zap(at: 0.15, p: 1.6, l: 0.7),
      _t(3000, 0.04, w: Waveform.square, v: 0.25, at: 0.15),
      _t(3500, 0.04, w: Waveform.square, v: 0.2, at: 0.21),
    ]),
    // Aplicar Mojado: una gota.
    Sfx.status('wet'): st([
      _t(1320, 0.12, w: Waveform.sine, to: 520, v: 0.5),
      _n(2500, 0.08, lp: 1800, v: 0.25, at: 0.02, seed: 83),
    ]),
    // Aplicar Cargado: zumbido que sube.
    Sfx.status('charged'): st([
      _t(220, 0.22, w: Waveform.sawtooth, to: 660, vr: 30, vd: 0.15, v: 0.4),
      _n(10000, 0.1, crush: 2, v: 0.25, at: 0.12, seed: 89),
    ]),
  };
}
