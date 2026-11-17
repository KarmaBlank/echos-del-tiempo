import 'sfx_recipes.dart';

/// Forma de onda de una voz (`OscillatorNode.type` del prototipo, más
/// `pulse` 25 % y ruido LFSR). Ver docs/specs/audio.md § "Sintetizador".
enum Waveform { square, pulse, sawtooth, triangle, sine, noise }

/// Una voz del sintetizador. Con los parámetros opcionales por defecto
/// es un `beep(f, d, type, vol)` del prototipo, con el retraso del
/// `setTimeout` que lo encadena.
class SfxTone {
  const SfxTone(
    this.frequency,
    this.duration, {
    this.wave = Waveform.square,
    this.volume = 0.05,
    this.delay = 0,
    this.endFrequency,
    this.attack = 0,
    this.hold = 0,
    this.vibratoRate = 0,
    this.vibratoDepth = 0,
    this.lowpass = 0,
    this.crush = 0,
    this.seed = 1,
  });

  /// Hz (en `noise`, la frecuencia de reloj del LFSR).
  final double frequency;

  /// Segundos hasta que la ganancia llega a 0.0001 y la voz se corta.
  final double duration;
  final Waveform wave;

  /// Ganancia pico (0..1). El prototipo usa 0.05 por defecto.
  final double volume;

  /// Segundos desde el inicio del efecto.
  final double delay;

  /// Frecuencia al final de la voz (barrido exponencial). `null`: fija.
  final double? endFrequency;

  /// Subida lineal desde 0 (s).
  final double attack;

  /// Meseta a volumen pleno después del ataque (s).
  final double hold;

  /// Vibrato: `f·(1 + depth·sin(2π·rate·t))`.
  final double vibratoRate;
  final double vibratoDepth;

  /// Filtro pasabajos de un polo (Hz). 0: apagado.
  final double lowpass;

  /// Bits del cuantizado de la voz (sonido "4 bits"). 0: apagado.
  final int crush;

  /// Semilla del LFSR de `noise`.
  final int seed;

  double get end => delay + duration;

  /// La misma voz desplazada [dt] segundos, con la altura × [pitch], el
  /// largo × [len] y el volumen × [gain].
  SfxTone shifted({
    double dt = 0,
    double pitch = 1,
    double len = 1,
    double gain = 1,
  }) =>
      SfxTone(
        frequency * pitch,
        duration * len,
        wave: wave,
        volume: volume * gain,
        delay: delay * len + dt,
        endFrequency: endFrequency == null ? null : endFrequency! * pitch,
        attack: attack * len,
        hold: hold * len,
        vibratoRate: vibratoRate,
        vibratoDepth: vibratoDepth,
        lowpass: lowpass == 0 ? 0 : lowpass * pitch,
        crush: crush,
        seed: seed,
      );
}

/// Un efecto: voces mezcladas y, si [peak] no es `null`, normalizadas a
/// ese pico (docs/specs/audio.md § "Niveles").
class SfxDef {
  const SfxDef(this.voices, {this.peak});

  final List<SfxTone> voices;
  final double? peak;

  double get length => voices.fold<double>(0, (m, t) => m > t.end ? m : t.end);
}

/// Ids de los efectos fijos. Las familias usan [Sfx.skill],
/// [Sfx.enemy], [Sfx.status], [Sfx.tick], [Sfx.weapon].
abstract final class Sfx {
  // ---- prototipo (`beep`) ----
  /// Empieza tu turno (línea 1200).
  static const myTurn = 'myTurn';

  /// Cuenta regresiva del turno con ≤ 5 s (línea 1231).
  static const turnTick = 'turnTick';

  /// Cinemática de ULT (línea 1461).
  static const ultimate = 'ultimate';

  /// Número verde: curación (línea 1469).
  static const heal = 'heal';

  /// Número rojo claro: daño normal a un jugador (línea 1469).
  static const hurt = 'hurt';

  /// Cualquier otro número (línea 1469).
  static const hit = 'hit';

  /// Destello de pantalla (línea 1469).
  static const flash = 'flash';

  /// `¡NIVEL N!` (línea 1469).
  static const levelUp = 'levelUp';

  /// Los ocho del prototipo.
  static const legacy = [
    myTurn, turnTick, ultimate, heal, hurt, hit, flash, levelUp, //
  ];

  // ---- arranque por arma ----
  static const swingBlade = 'swing.blade';
  static const swingHeavy = 'swing.heavy';
  static const shotBow = 'shot.bow';
  static const shotRifle = 'shot.rifle';
  static const shotStaff = 'shot.staff';
  static const shotTome = 'shot.tome';

  // ---- impactos ----
  static const impactSlash = 'impact.slash';
  static const impactBlunt = 'impact.blunt';
  static const impactArrow = 'impact.arrow';
  static const impactBullet = 'impact.bullet';
  static const impactArcane = 'impact.arcane';
  static const impactFire = 'impact.fire';
  static const impactIce = 'impact.ice';
  static const impactPoison = 'impact.poison';
  static const impactHoly = 'impact.holy';
  static const impactHurt = 'impact.hurt';

  /// "Clink" de cada golpe crítico, encima del impacto.
  static const critClink = 'crit.clink';

  // ---- curas, ítems, defensa ----
  static const healSparkle = 'heal.sparkle';
  static const manaUp = 'mana.up';
  static const potion = 'item.potion';
  static const ether = 'item.ether';
  static const defend = 'defend';
  static const dualCast = 'dual.cast';

  // ---- estados y otros ----
  static const skipFreeze = 'skip.freeze';
  static const skipStun = 'skip.stun';
  static const koEnemy = 'ko.enemy';
  static const koPlayer = 'ko.player';
  static const revive = 'revive';
  static const delay = 'delay';

  // ---- enemigos ----
  static const enemyGeneric = 'enemy.generic';
  static const enemyHeavy = 'enemy.heavy';

  /// Impacto propio de un tipo de enemigo sobre un jugador.
  static String enemyHit(String type) => 'enemy.hit.$type';

  // ---- quiebre y ULT enemigas ----
  static const breakTick = 'break.tick';
  static const breakShatter = 'break.shatter';
  static const breakVuln = 'break.vuln';
  static const breakDazed = 'break.dazed';
  static const enemyUltWarn = 'enemyUlt.warn';

  /// Firma de una habilidad (`SkillDef.id`).
  static String skill(String id) => 'skill.$id';

  /// Sonido de un tipo de enemigo (`EnemyDef.id`).
  static String enemy(String type) => 'enemy.$type';

  /// Aplicar un estado (`StatusKind.name`).
  static String status(String kind) => 'status.$kind';

  /// Daño / cura de un estado al empezar el turno (`StatusKind.name`).
  static String tick(String kind) => 'tick.$kind';

  // ---- procs del árbol (docs/specs/audio.md § "Disparadores del
  // árbol (procs)") ----
  /// Salto [hop] de un rebote (0..2; cada salto suena más agudo).
  static String zip(int hop) => 'proc.zip.${hop.clamp(0, maxZip)}';
  static const maxZip = 2;
  static const whump = 'proc.whump';
  static const clang = 'proc.clang';
  static const bell = 'proc.bell';
  static const frenzyWhoosh = 'proc.whoosh';
  static const flare = 'proc.flare';
  static const mark = 'proc.mark';
  static const weaken = 'proc.weaken';
  static const shieldUp = 'proc.shield';
  static const shieldBreak = 'proc.shieldBreak';
  static const extraTurn = 'proc.extraTurn';
  static const heartbeat = 'proc.heartbeat';
  static const plague = 'proc.plague';
  static const steam = 'proc.steam';
  static const ultCharge = 'proc.ultCharge';
  static const anvil = 'proc.anvil';
  static const wind = 'proc.wind';

  /// Eco Arcano: la firma de la habilidad [skillId] con eco.
  static String echo(String skillId) => 'echo.$skillId';

  /// Partes del sonido de una ULT (docs/specs/audio.md § "Ultimates").
  static const ultBuild = 'build';
  static const ultRelease = 'release';
  static const ultImpact = 'impact';
  static const ultParts = [ultBuild, ultRelease, ultImpact];

  /// Sonido [part] de la ULT [ultId] (`SkillDef.id`), p. ej.
  /// `ult_baculo.impact`.
  static String ult(String ultId, String part) => '$ultId.$part';
}

/// Retraso del impacto de la ULT (`ULT_DL`, 1150 ms).
const double kUltImpactDelay = 1.15;

/// Picos por categoría (docs/specs/audio.md § "Niveles").
abstract final class SfxLevel {
  static const ui = 0.28;
  static const number = 0.30;
  static const status = 0.30;

  /// Procs del árbol; los "golpes" de proc usan [impact] y el turno
  /// extra 0.40.
  static const proc = 0.34;
  static const extraTurn = 0.40;
  static const action = 0.36;
  static const impact = 0.38;
  static const heavy = 0.42;
  static const crit = 0.45;
  static const ultimate = 0.45;
  static const ultBuild = 0.45;
  static const ultRelease = 0.46;
  static const ultImpact = 0.50;

  /// Ataques enemigos (wind-up + golpe): más fuertes que los del grupo.
  static const enemy = 0.42;
  static const enemyBoss = 0.45;
  static const enemyHit = 0.42;

  /// Quiebre: el tic de la barra es sutil; el estallido, fuerte.
  static const breakTick = 0.16;
  static const breakShatter = 0.45;
  static const breakVuln = 0.36;
  static const enemyUltWarn = 0.44;
}

/// Las voces del prototipo, copiadas de las llamadas a `beep(`.
const Map<String, List<SfxTone>> kLegacyTones = {
  Sfx.myTurn: [
    SfxTone(523, 0.08),
    SfxTone(784, 0.12, delay: 0.09),
  ],
  Sfx.turnTick: [SfxTone(1200, 0.04)],
  Sfx.ultimate: [
    SfxTone(196, 0.5, wave: Waveform.sawtooth, volume: 0.05),
    SfxTone(392, 0.4, volume: 0.04, delay: 0.3),
    SfxTone(98, 0.6,
        wave: Waveform.sawtooth, volume: 0.07, delay: kUltImpactDelay),
  ],
  Sfx.heal: [SfxTone(880, 0.08)],
  Sfx.hurt: [SfxTone(160, 0.08)],
  Sfx.hit: [SfxTone(420, 0.08)],
  Sfx.flash: [SfxTone(220, 0.3, wave: Waveform.sawtooth, volume: 0.04)],
  Sfx.levelUp: [
    SfxTone(660, 0.1),
    SfxTone(990, 0.15, delay: 0.1),
  ],
};

const _legacyPeak = {
  Sfx.myTurn: SfxLevel.ui,
  Sfx.turnTick: SfxLevel.ui,
  Sfx.levelUp: SfxLevel.ui,
  Sfx.ultimate: SfxLevel.ultimate,
  Sfx.heal: SfxLevel.number,
  Sfx.hurt: SfxLevel.number,
  Sfx.hit: SfxLevel.number,
  Sfx.flash: SfxLevel.number,
};

/// El catálogo completo: id → efecto. Los del prototipo conservan sus
/// voces (sólo cambia el nivel); el resto es el diseño de
/// docs/specs/audio.md § "Diseño de sonido de combate".
final Map<String, SfxDef> kSfxCatalog = {
  for (final e in kLegacyTones.entries)
    e.key: SfxDef(e.value, peak: _legacyPeak[e.key]),
  ...buildCombatSfx(),
};
