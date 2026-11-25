import 'dart:math' as math;

import 'cooking_rules.dart';
import '../data/tuning_catalog.dart';
import 'revive_rules.dart';
import '../data/ascension_catalog.dart';
import '../data/branch_ults_catalog.dart';
import '../data/elements_catalog.dart';
import '../data/weapon_elements_catalog.dart';
import '../data/enemies_catalog.dart';
import '../data/game_catalog.dart';
import '../data/passive_mechanics.dart' show mechanicById;
import '../data/skills_catalog.dart';
import '../data/summoner_catalog.dart';
import '../data/zones_catalog.dart' show kEnemyBaseLevel;
import '../models/battle_command.dart';
import '../models/battle_event.dart';
import '../models/battle_state.dart';
import '../models/enemy_def.dart';
import '../models/item.dart' show ModStat;
import '../models/passive_mechanic.dart';
import '../models/skill.dart';
import '../models/status.dart';
import '../data/abyss_catalog.dart';
import 'abyss_rules.dart';
import 'display_names.dart';
import 'dual_rules.dart';
import 'encounter_rules.dart';
import 'enemy_combo_rules.dart';
import 'family_rules.dart';
import 'js_math.dart';
import 'skill_requirements.dart';
import 'stats_calculator.dart';
import 'summon_rules.dart';
import 'break_rules.dart';
import '../catalog_text_keys.dart';
import 'ult_rules.dart';

part 'battle_engine_abyss.dart';
part 'battle_engine_summons.dart';
part 'battle_engine_enemy_combo.dart';

/// Fuente de azar: devuelve un número en [0, 1), igual que `Math.random`.
/// Los tests inyectan una secuencia fija para que todo sea reproducible.
typedef RandomSource = double Function();

/// La ULT de [c] (ultimates_v2.md § 2.1): la elegida (`PlayerBuild.ultSel`)
/// si es válida; si no, la de su ascensión; si no, la ULT base de su
/// clase. El arma equipada nunca decide qué ULT se lanza.
/// Carga de ULT por recibir el 100% de la vida en daño (Ajustes → Carga de barra ULT).
double get _ultTaken => tuning(TuningId.ultCharge).d('takenFactor');

SkillDef? ultimateOf(Combatant c,
    [GameCatalog catalog = GameCatalog.standard]) {
  final b = c.build;
  if (b != null) {
    final sel = UltRules.selected(b, catalog);
    if (sel != null) return sel;
  }
  final asc = kAscensions[c.ascensionId];
  if (asc != null && asc.classId == c.classId) {
    final u = kAscensionUltimates[asc.id];
    if (u != null) return u;
  }
  // ULT libres del arma (ultimates_v2.md § 2.1): sin elegida ni
  // ascensión, la ULT base de la clase. El arma equipada nunca decide.
  // Sin build (enemigos, invocaciones, pruebas sin perfil): la del tipo.
  if (b == null) return catalog.ultimates[c.weaponType];
  return UltRules.baseUltLeveled(b.classId, b.ultLevel, catalog);
}

/// La ULT de [c] se puede lanzar: tiene la carga de su costo
/// (ultimates_v2.md § 2.2).
bool ultReady(Combatant c, [GameCatalog catalog = GameCatalog.standard]) {
  final u = ultimateOf(c, catalog);
  return u != null && c.ult >= kUltCost && !ultSilenced(c);
}

/// [c] is silenced and Silence blocks the ULT (combat.md § "Silencio").
bool ultSilenced(Combatant c) =>
    c.silenced > 0 && BattleEngine.silenceBlocksUlt;

/// Los 3 estados elementales (Elementalista).
const kElementalStatuses = [
  StatusKind.burn,
  StatusKind.freeze,
  StatusKind.poison
];

/// Resultado de un paso del motor: el estado nuevo y lo que pasó, en orden.
class BattleStep {
  final BattleState state;
  final List<BattleEvent> events;
  const BattleStep(this.state, this.events);
}

/// Motor de combate por timeline — puerto de `startBattle`, `nextTurn`,
/// `statusTick`, `addStatus`, `enemyAct`, `hurt`, `dmgEnemy`, `battleCmd`
/// y `checkEnd` del prototipo. Reglas en docs/specs/combat.md.
///
/// Dart puro y sin estado propio: cada método recibe un [BattleState],
/// trabaja sobre una copia y devuelve el estado nuevo. Quien lo usa (el
/// host en P2P) maneja los tiempos: llama a [nextTurn] cuando no hay
/// turno en curso, a [enemyTurn] si le toca a un enemigo, y espera un
/// [command] (o [timeout]) si le toca a un jugador.
class BattleEngine {
  BattleEngine({
    required this.stats,
    this.catalog = GameCatalog.standard,
    RandomSource? random,
    this.breakEnabled = true,
    this.enemyUltsEnabled = true,
    this.familiesEnabled = true,
  }) : _random = random ?? math.Random().nextDouble;

  final StatsCalculator stats;
  final GameCatalog catalog;
  final RandomSource _random;

  /// Barra de quiebre de los enemigos (docs/specs/break_and_enemy_ults.md
  /// § 1). Los tests angostos pueden apagarla.
  final bool breakEnabled;

  /// ULT de jefes y élites (§ 2).
  final bool enemyUltsEnabled;

  /// Familias de enemigos: debilidades, resistencias, inmunidades y curas
  /// que dañan (docs/specs/bestiary.md § 1). Los tests de otras fórmulas
  /// pueden apagarlas.
  final bool familiesEnabled;

  /// Beneficios permanentes del pueblo (overworld_biomes.md § 10.6): Ilda
  /// (+% de curación de pociones) y Oren (+% de vida máxima). Los pone el
  /// anfitrión antes de cada batalla.
  double townPotion = 0;
  double townHp = 0;

  // ---- quiebre (combo_balance.md § 5) ----
  // Los puntos por acción, el umbral del élite y el del grupo están en
  // `ComboRulesDef` (catálogo, editable en el admin de balance).

  /// Baja al empezar el turno del enemigo (fracción del umbral).
  static const breakDecay = 0.10;

  /// Turnos del grupo con +50% de daño.
  static const vulnerableTurns = 2;
  static const vulnerableBonus = 0.5;

  /// Golpe esquivado por un común (Eco Sombrío): solo lo roza.
  static const evadeFactor = 0.3;

  /// Pasar turno (v0.8.3, combat.md § "Pasar turno"): el próximo turno
  /// llega en IV × esto (Defender: × 0.7; acción normal: × 1).
  static const passTurnFactor = 0.5;

  // ---- Defender con valor (battle_attack_menu.md § 6) ----
  /// Pulso de Defender elegido; baja a [defendPulseRepeat] si también
  /// defendió (a mano) su turno anterior. La defensa automática por
  /// tiempo agotado da solo el +1 normal y nada de ULT.
  static const defendPulse = 2;
  static const defendPulseRepeat = 1;

  /// Carga de ULT al defender y, una vez por defensa, al recibir un
  /// golpe defendiendo (escala con `ultChargeBonus`).
  static const defendUlt = 6.0;
  static const defendHitUlt = 6.0;

  // ---- Pulso (combo_balance.md § 5.2) ----
  /// Tope de Pulso por jugador.
  static const pulseMax = 5;

  /// Pulso con el que arranca la pelea.
  static const pulseStart = 1;

  // ---- ULT enemiga ----
  /// Carga por turno propio.
  static double get enemyUltPerTurn =>
      tuning(TuningId.ultCharge).d('enemyPerTurn');

  /// Carga por vida perdida: +1 por cada 1% (= 100 × fracción).
  static double get enemyUltPerHp => tuning(TuningId.ultCharge).d('enemyPerHp');

  /// Tope de lo que el drenaje le quita a una ULT ya avisada
  /// (ultimates_v2.md § 4.1).
  static const ultWeakenMax = 0.4;

  /// Carga con la que empiezan jefes y élites (la primera ULT llega
  /// hacia su 3.er turno).
  static const enemyUltStart = 40.0;

  /// −velocidad por stack de Congelación del código (§ 7); el motor usa
  /// la del catálogo (`ElementStatusDef.slowPerStack`, editable).
  static const freezeSlowPerStack = 0.06;
  static const enemyCritMultiplier = 1.5;
  static const maxBonusDefense = 12;
  static const dualMpCost = 4;

  static TuningDef get _limits => tuning(TuningId.combatLimits);

  /// Tope de efectos encadenados (árbol, armas, mods, invocaciones) en
  /// un paso del motor, es decir, por acción (passive_tree_v2.md § 5,
  /// regla 4; combat.md § "Límites"). Editable en Balance.
  static int get maxProcsPerStep => math.max(1, _limits.i('procMax'));

  /// Profundidad máxima de una cadena de efectos: un efecto que dispara
  /// otro que dispara otro... (combat.md § "Límites").
  static int get maxProcDepth => math.max(1, _limits.i('procDepth'));

  /// Tope absoluto por golpe como fracción de la vida máxima (0 = sin
  /// tope), aunque haya debilidad, reacción o quiebre (combat.md §
  /// "Límites").
  static double absoluteHitCap({required bool boss, required bool elite}) =>
      _limits.d(boss
          ? 'capBoss'
          : elite
              ? 'capElite'
              : 'capCommon');

  /// "Aguanta una ronda" de los comunes (combat.md § "Límites").
  static bool holdsRound({required bool coop}) =>
      _limits.i(coop ? 'holdCoop' : 'holdSolo') > 0;

  /// Nobody alone in one phase (combat.md § "Nadie solo en una fase"):
  /// fraction of max HP from which one character cannot kill an enemy
  /// within their phase (0 = off).
  static double get phaseHold => _limits.d('phaseHold');

  /// Tank elemental ward (combat.md § "Tanques"): × damage of the warded
  /// element, duration in own turns, and Defense (× damage taken).
  static double get wardMult => _limits.d('wardMult');
  static int get wardTurns => math.max(1, _limits.i('wardTurns'));
  static double get tankGuard => _limits.d('tankGuard');

  /// Enemy Silence (combat.md § "Silencio"): own turns of the silenced
  /// player, recast period of a silencer (0 = only when it opens the
  /// fight) and whether the ULT is blocked too.
  static int get silenceTurns => math.max(0, _limits.i('silenceTurns'));
  static int get silenceEvery => math.max(0, _limits.i('silenceEvery'));

  /// Own turns a player can't be silenced again after Silence ends, so
  /// several silencers can't chain it every turn (combat.md § "Silencio").
  static int get silenceCooldown => math.max(0, _limits.i('silenceCooldown'));
  static bool get silenceBlocksUlt => _limits.i('silenceUlt') > 0;

  /// Player break bar (combo_balance.md § 5.4).
  static bool get playerBreakOn => _limits.i('pBreakOn') > 0;
  static double get playerBreakBase => math.max(1, _limits.d('pBreakMax'));
  static double get playerBreakHit => _limits.d('pBreakHit');
  static double get playerBreakHp => _limits.d('pBreakHp');
  static double get playerBreakDecay => _limits.d('pBreakDecay');
  static int get playerBrokenTurns => math.max(1, _limits.i('pBrokenTurns'));
  static double get playerBrokenMult => _limits.d('pBrokenMult');

  /// Current threshold of a player's break bar: base × min(2, 1 + 0.25 ×
  /// breaks), like the enemies'.
  static double playerBreakMax(Combatant p) =>
      playerBreakBase * (1 + 0.25 * p.breaks).clamp(1.0, 2.0).toDouble();

  /// Tope de carga de ULT extra (árbol, mods, efectos, invocaciones) por
  /// acción y por turno de quien la recibe (combat.md § "Límites").
  static double get ultBonusPerAction => _limits.d('ultBonusAction');
  static double get ultBonusPerTurn => _limits.d('ultBonusTurn');

  /// Turnos como máximo por cada turno del aliado vivo más lento (0 = sin
  /// tope).
  static double get turnsPerSlowest => _limits.d('turnsPerSlowest');

  /// Velocidad efectiva con rendimiento decreciente: lo que pasa de
  /// `speedSoftCap` rinde × `speedSoftFactor`.
  static double softSpeed(double v) {
    final cap = _limits.d('speedSoftCap');
    if (v <= cap) return v;
    return cap + (v - cap) * _limits.d('speedSoftFactor');
  }

  /// Tope de la defensa de grupo sumada (`BuffStat.guard`, ascension.md).
  static const maxGuard = 0.6;

  /// Tiempo entre turnos (`IVa`): 100 / velocidad efectiva. Los buffs de
  /// velocidad del árbol (Frenesí) suben la velocidad efectiva; sobre el
  /// umbral rinden menos ([softSpeed]). No incluye el tope por el aliado
  /// más lento: ese lo aplica el paso, que ve la batalla
  /// ([cappedInterval]).
  double interval(Combatant a) =>
      100 /
      softSpeed(a.speed *
          (1 + a.effectTotal(BuffStat.speed)) *
          (1 -
              catalog.elementStatus(StatusKind.freeze).slowPerStack *
                  a.stacks(StatusKind.freeze)));

  /// [interval] de [a] con el tope de turnos (combat.md § "Límites"):
  /// nunca menor que el intervalo del aliado vivo más lento de su bando
  /// / `turnsPerSlowest`. Bando: grupo + invocaciones, o enemigos.
  double cappedInterval(BattleState s, Combatant a) {
    final iv = interval(a);
    final k = turnsPerSlowest;
    if (k <= 0) return iv;
    final side =
        a.isPlayer || a.isSummon ? [...s.party, ...s.summons] : s.enemies;
    var slowest = 0.0;
    for (final c in side) {
      if (!c.alive ||
          c.speed <= 0 ||
          (!c.isPlayer && (catalog.enemies[c.enemyType]?.passive ?? false))) {
        continue;
      }
      slowest = math.max(slowest, interval(c));
    }
    if (slowest <= 0) return iv;
    return math.max(iv, slowest / k);
  }

  // ------------------------------------------------------------------
  // API pública
  // ------------------------------------------------------------------

  BattleStep start({
    required List<BattlePartyMember> party,
    required List<String> enemyTypes,
    bool elite = false,
    String? triggeredBy,
    EncounterKind? encounter,
    TurnRule turnRule = TurnRule.velocidad,
    double roomExtra = 0,
  }) {
    // Vida en cooperativo (combo_balance.md § 3.3): 0.6 + 0.3 × jugadores
    // (antes 0.55 + 0.45 × jugadores). [roomExtra]: jugadores de la sala
    // que no están en la pelea, ya ponderados (overworld_biomes.md § 6).
    final curve = catalog.curve;
    final n = party.length;
    double lerp(double Function(int) f) => f(n) + (f(n + 1) - f(n)) * roomExtra;
    final mult = lerp(curve.groupHp);
    final atkMult = lerp(curve.groupAtk);
    final solo = party.length == 1;
    final first = catalog.enemies[enemyTypes.first]!;
    // Jefe en solitario: escolta recortada (§ 3.3, ajuste del paso 5).
    final types = solo && first.boss
        ? enemyTypes.take(1 + math.max(0, curve.soloEscorts)).toList()
        : enemyTypes;

    final enemies = <Combatant>[];
    for (var i = 0; i < types.length; i++) {
      final d = catalog.enemies[types[i]]!;
      final el = elite && i == 0;
      // Jefe en solitario (§ 3.3, ajuste del paso 5).
      final soloBoss = solo && d.boss;
      final hp = jsRound(
          d.hp * mult * (el ? 2.6 : 1) * (soloBoss ? curve.soloBossHp : 1));
      // Élite: su ULT propia (ultimates_v2.md § 4.3) o Furia Élite.
      final ultId = el ? (d.eliteUltId ?? kEliteUltId) : d.ultId;
      enemies.add(Combatant(
        id: 'e$i',
        name: el ? '${d.name} Élite' : d.name,
        isPlayer: false,
        hp: hp,
        maxHp: hp,
        speed: d.speed * (el ? 1.1 : 1),
        attack: jsRound(d.attack *
            (el ? 1.35 : 1) *
            (soloBoss ? curve.soloBossAtk : 1) *
            atkMult),
        critChance: el ? 0.15 : (d.boss ? 0.12 : 0.08),
        enemyType: d.id,
        elite: el,
        boss: d.boss,
        areaAttack: d.areaAttack,
        pierce: d.pierce,
        inflicts: d.inflicts,
        // Umbral de quiebre en puntos (combo_balance.md § 5): × grupo y
        // élite, no escala con la vida.
        breakBase: breakEnabled
            ? d.breakMax *
                catalog.combo.groupBreak(party.length) *
                (el ? catalog.combo.eliteBreak : 1)
            : 0,
        ultId: enemyUltsEnabled && catalog.enemyUlts.containsKey(ultId)
            ? ultId
            : null,
        ult: enemyUltsEnabled && catalog.enemyUlts.containsKey(ultId)
            ? enemyUltStart
            : 0,
        // Con la velocidad base, como el prototipo (IVa(d)).
        nextTurn: (100 / d.speed) * (0.35 + _random() * 0.6),
      ));
    }

    // Mecánica propia del jefe (docs/specs/bosses.md § "v0.2").
    final mech = first.boss ? bossMechanicOf(first) : null;
    if (mech != null) {
      final boss = enemies.first;
      if (mech.kind == BossMechanicKind.stance) {
        boss
          ..stance = 1
          ..stanceTurns = mech.every;
      }
      // Jefe del Abismo (abyss_bosses.md § 2): fase 1, su aspecto, y las
      // invocaciones solo si su primera fase las pide.
      final abyss = catalog.abyssOf(first.id);
      if (abyss != null) {
        final ph = abyss.phases.first;
        boss.phase = 1;
        if (ph.aspects.isNotEmpty) {
          boss.abyssAspect = ph.aspects.first.index + 1;
        }
      }
      final add = abyss != null && !abyss.phases.first.summon
          ? null
          : catalog.enemies[mech.addType];
      if (add != null) {
        final n = party.length == 1 ? mech.soloAdds : mech.adds;
        for (var k = 0; k < n; k++) {
          final c = addCombatant(add, 'e${enemies.length}', mult, 1);
          // Las invocaciones que actúan (ecos, séquito) entran a la línea
          // de tiempo sin tirar dados (docs/specs/bosses.md § "v0.3").
          if (!add.passive) c.nextTurn = (100 / add.speed) * (0.6 + 0.2 * k);
          enemies.add(c);
        }
      }
    }

    final players = <Combatant>[];
    for (final m in party) {
      final c = _playerCombatant(m);
      c.nextTurn =
          interval(c) * (triggeredBy == m.id ? 0.2 : 0.3 + _random() * 0.5);
      players.add(c);
    }

    final state = BattleState(
      party: players,
      enemies: enemies,
      boss: first.boss,
      elite: elite,
      turnRule: turnRule,
      logLine: first.boss
          ? _l('start_boss', {'a': first.name})
          : elite
              ? _l('start_elite', {'a': first.name})
              : encounter == EncounterKind.firstStrike
                  ? _l('start_first_strike')
                  : _l('start_ambush'),
    );
    applyMealShields(state);
    assignCombatantTags(state);
    if (encounter != null) _applyInitiative(state, encounter, triggeredBy);
    // After the initiative: opening wards read the opening order.
    applyOpeningWards(state);
    applyOpeningSilence(state,
        ambush: encounter == EncounterKind.ambush);
    return BattleStep(state, const []);
  }

  /// Tanks that do not act first start with their ward up (combat.md §
  /// "Tanques"). Reads the opening order from [state] as built, so it
  /// works with any initiative rule.
  void applyOpeningWards(BattleState state) {
    LogLine? line;
    for (final e in state.enemies) {
      if (!isTank(e) || actsBeforeParty(state, e)) continue;
      final tag = chooseWard(state, e);
      if (tag == null) continue;
      e
        ..ward = tag.index + 1
        ..wardTurns = wardTurns;
      final t = _l('ward_opening', {
        'a': e.name,
        't': LogLine.named(CatalogKeys.damageTag(tag), tag.label),
      });
      line = line == null ? t : line.plus(t);
    }
    if (line != null) state.logLine = state.logLine.plus(line);
  }

  /// Key in `Combatant.once` of a silencer that opens the fight before
  /// the party: its first action is Silence (combat.md § "Silencio").
  static const silenceOpenKey = 'silence_open';

  /// Silencers that act before every player (or any in an [ambush]) arm
  /// their opening Silence.
  void applyOpeningSilence(BattleState state, {bool ambush = false}) {
    if (silenceTurns <= 0) return;
    for (final e in state.enemies) {
      if (isSilencer(e) && (ambush || actsBeforeParty(state, e))) {
        e.once.add(silenceOpenKey);
      }
    }
  }

  /// [e] casts Silence (`EnemyDef.silencer`).
  bool isSilencer(Combatant e) =>
      !e.isPlayer && (catalog.enemies[e.enemyType]?.silencer ?? false);

  /// Skill power of [p] (combat.md § "Silencio"): the best estimated hit
  /// among its skills that cost MP (stat × power, ×1.5 if it hits every
  /// foe), else half its best stat.
  double skillPower(Combatant p) {
    var best = 0.0;
    for (final id in p.skillIds) {
      final sk = catalog.skills[id];
      if (sk == null || sk.mp <= 0) continue;
      final stat = sk.kind == SkillKind.physical ? p.attack : p.magic;
      final v = stat * sk.power * (sk.allTargets ? 1.5 : 1);
      if (v > best) best = v;
    }
    return best > 0 ? best : math.max(p.magic, p.attack) * 0.5;
  }

  /// Who a silencer silences: the living, non-silenced player with the
  /// highest [skillPower] (ties: party order); `null` if none.
  Combatant? silenceTarget(BattleState state) {
    Combatant? pick;
    var best = -1.0;
    for (final p in state.party) {
      if (!p.alive || p.isSummon || p.silenced != 0) continue;
      final v = skillPower(p);
      if (v > best) {
        best = v;
        pick = p;
      }
    }
    return pick;
  }

  /// [e] is a tank (`EnemyDef.tank`).
  bool isTank(Combatant e) =>
      !e.isPlayer && (catalog.enemies[e.enemyType]?.tank ?? false);

  /// [e] acts before every player in the opening of [state].
  bool actsBeforeParty(BattleState state, Combatant e) {
    final players = [
      for (final p in state.party)
        if (p.alive && !p.isSummon) p
    ];
    if (players.isEmpty) return true;
    switch (state.turnRule) {
      case TurnRule.porFases:
        return true; // The enemy phase opens the fight.
      case TurnRule.porBando:
        return false; // The party turn opens the fight.
      case TurnRule.porRonda:
        final iv = interval(e);
        return players.every((p) => iv < interval(p));
      case TurnRule.velocidad:
        return players.every((p) => e.nextTurn < p.nextTurn);
    }
  }

  /// Element [e] wards against: among its elemental weaknesses, the one
  /// the party hits with most (skills); else its strongest weakness;
  /// `null` if it has none.
  DamageTag? chooseWard(BattleState state, Combatant e) {
    final f = e.family;
    final r = !familiesEnabled || f == null ? null : kFamilyRules[f];
    if (r == null) return null;
    final weak = [
      for (final en in r.damage.entries)
        if (en.key.isElement && en.value > 1) en.key
    ];
    if (weak.isEmpty) return null;
    final count = <DamageTag, int>{};
    for (final p in state.party) {
      if (!p.alive || p.isSummon) continue;
      for (final id in p.skillIds) {
        for (final t in skillDamageTags(catalog.skills[id])) {
          count[t] = (count[t] ?? 0) + 1;
        }
      }
    }
    weak.sort((a, b) {
      final c = (count[b] ?? 0).compareTo(count[a] ?? 0);
      if (c != 0) return c;
      final v = r.damage[b]!.compareTo(r.damage[a]!);
      return v != 0 ? v : a.index.compareTo(b.index);
    });
    return weak.first;
  }

  /// Encounter initiative (combat.md § "Encounter initiative"): who opens
  /// round 1. FIRST STRIKE: the party, [triggeredBy] first; AMBUSH: the
  /// enemies, the touching enemy (`e0`, the group leader) first.
  void _applyInitiative(
      BattleState state, EncounterKind kind, String? triggeredBy) {
    final ambush = kind == EncounterKind.ambush;
    final opener = ambush
        ? state.enemies.firstOrNull?.id
        : (state.party.any((p) => p.id == triggeredBy)
            ? triggeredBy
            : state.party.firstOrNull?.id);
    if (state.porFases) {
      // Default opens with the enemy phase; first strike skips the enemy
      // phase of round 1 (the party phase comes first).
      if (!ambush) {
        state
          ..round = 1
          ..groupPhase = false
          ..acted.addAll([for (final e in state.enemies) e.id]);
      }
    } else if (state.porBando) {
      // Default opens with the party turn; an ambush opens round 1 with
      // the enemies (in list order: the touching enemy first).
      if (ambush) {
        state
          ..round = 1
          ..groupPhase = false
          ..clock = 1;
      }
    } else if (state.porRonda) {
      // Round 1 order: by speed, with the opener moved to the front.
      final all = [
        for (final c in [...state.party, ...state.summons, ...state.enemies])
          if (c.alive &&
              !(!c.isPlayer &&
                  (catalog.enemies[c.enemyType]?.passive ?? false)))
            c
      ];
      if (all.isEmpty) return;
      final idx = {for (var i = 0; i < all.length; i++) all[i].id: i};
      final iv = {for (final c in all) c.id: interval(c)};
      all.sort((a, b) {
        if (a.id == opener) return -1;
        if (b.id == opener) return 1;
        final d = iv[a.id]!.compareTo(iv[b.id]!);
        return d != 0 ? d : idx[a.id]!.compareTo(idx[b.id]!);
      });
      state
        ..round = 1
        ..clock = 1
        ..acted.clear()
        ..waited.clear()
        ..roundOrder.replaceRange(
            0, state.roundOrder.length, [for (final c in all) c.id]);
    } else {
      EncounterRules.applyTimelineOpener(state, opener);
    }
  }

  /// Le da el turno al próximo actor y procesa sus estados alterados.
  BattleStep nextTurn(BattleState state) {
    final t = _Turn(this, state.copy());
    t.nextTurn();
    return t.result;
  }

  /// Hace actuar al enemigo que tiene el turno. `null` si no le toca a
  /// un enemigo.
  BattleStep? enemyTurn(BattleState state) {
    final cur = state.current;
    if (state.ended || cur == null || cur.isPlayer) return null;
    final t = _Turn(this, state.copy());
    final e = t.state.current!;
    if (e.alive && e.isSummon) {
      // Invocación (summoner.md § 3): su IA y su próxima espera.
      t._summonTurn(e);
      e.nextTurn = t.state.clock + interval(e);
    } else if (e.alive) {
      final before = e.nextTurn;
      t.enemyAct(e);
      t.tickEffects(e);
      // Un retraso recibido durante su propia acción (Contratiempo) se
      // suma a su próxima espera.
      e.nextTurn =
          t.state.clock + interval(e) + math.max(0.0, e.nextTurn - before);
      // Distorsión de un Jefe del Abismo: su próximo turno llega antes.
      final haste = _abyssHaste[t];
      if (haste != null) {
        e.nextTurn -= interval(e) * haste;
        t._hasted.add(e.id);
      }
    }
    t.endTurn();
    return _roundHaste(state, t, e.id);
  }

  /// El jugador [playerId] actúa. `null` si el comando no es válido
  /// (no es su turno, no le alcanza el MP, etc.): el estado no cambia.
  BattleStep? command(BattleState state, String playerId, BattleCommand cmd) {
    final cur = state.current;
    if (cmd is WaitCommand) return _wait(state, playerId);
    if (cmd is EndTurnCommand) {
      // Línea de tiempo: TERMINAR TURNO es Pasar.
      if (!state.grouped) return command(state, playerId, const PassCommand());
      return _endTurnCmd(state, playerId);
    }
    if (state.awaitingGroup) {
      // porBando (roguelike.md § 6): el primero del grupo que manda, actúa.
      if (!state.pendingGroup.any((p) => p.id == playerId)) return null;
      final t = _Turn(this, state.copy()..currentId = playerId);
      return t.command(t.state.current!, cmd)
          ? _roundDelays(state, _roundHaste(state, t, playerId), playerId)
          : null;
    }
    if (state.ended ||
        cur == null ||
        !cur.isPlayer ||
        cur.id != playerId ||
        !cur.alive) {
      return null;
    }
    final t = _Turn(this, state.copy());
    return t.command(t.state.current!, cmd)
        ? _roundDelays(state, _roundHaste(state, t, playerId), playerId)
        : null;
  }

  /// Prisa in `porRonda` / `porFases` (turn_modes.md § 4.2). A hasted unit
  /// that still has to act this round (or phase) acts next: right after
  /// the actor (after the actor's whole party block in `porRonda`, so the
  /// block stays intact; a hasted player then joins it). The actor itself,
  /// or a unit that already acted, opens the next round instead
  /// (`hasteNext`). The timeline ignores this.
  BattleStep _roundHaste(BattleState before, _Turn t, String actor) {
    final s = t.state;
    if (t._hasted.isEmpty || !(s.porRonda || s.porFases) || s.ended) {
      return t.result;
    }
    final now = <String>[];
    for (final id in t._hasted) {
      final c = s.byId(id);
      if (c == null || !c.alive) continue;
      if (id == actor || s.acted.contains(id)) {
        if (!s.hasteNext.contains(id)) s.hasteNext.add(id);
      } else {
        now.add(id);
      }
    }
    if (now.isEmpty) return t.result;
    if (s.porFases) {
      // Players share their phase already: only enemies and summons queue.
      final q = [
        for (final id in now)
          if (s.byId(id) case final c? when !c.isPlayer || c.isSummon) id
      ];
      s.roundOrder
        ..removeWhere(q.contains)
        ..insertAll(0, q);
      return t.result;
    }
    // porRonda: keep their speed order (the round order), insert after
    // the actor and the rest of its block.
    now.sort(
        (a, b) => s.roundOrder.indexOf(a).compareTo(s.roundOrder.indexOf(b)));
    final block = {for (final p in before.pendingGroup) p.id};
    s.roundOrder.removeWhere(now.contains);
    var at = -1;
    for (final (i, id) in s.roundOrder.indexed) {
      if (id == actor || block.contains(id)) at = i;
    }
    s.roundOrder.insertAll(at + 1, now);
    // A player now at the front of the block starts its turn right away
    // (two adjacent players form a block and share the coop queue).
    if (s.groupPhase) {
      final log = s.logLine, cur = s.currentId;
      var began = false;
      for (final p in s.roundBlock) {
        if (block.contains(p.id) || s.waited.contains(p.id)) continue;
        t._beginTurn(p);
        s.currentId = null;
        began = true;
        if (s.ended) break;
      }
      if (began) {
        s.logLine = LogLine.join([log, s.logLine]);
        if (!s.ended) s.currentId = cur;
      }
    }
    return t.result;
  }

  /// `porRonda` (turn_modes.md § 4.1): a combatant still to act this round
  /// that a command delayed (its `nextTurn` pushed back: Retraso,
  /// Contratiempo, ...) or froze (gained Congelación stacks) moves to the
  /// end of what remains of the round (the actor itself never moves). Party blocks (`roundBlock`) are
  /// recomputed from the new order right away, so two players that are now
  /// consecutive form a block (and share the action queue in coop).
  BattleStep _roundDelays(BattleState before, BattleStep step, String actor) {
    final s = step.state;
    if (!s.porRonda) return step;
    final pushed = <String>[];
    for (final id in s.roundOrder) {
      if (id == actor || s.acted.contains(id)) continue;
      final now = s.byId(id);
      final was = before.byId(id);
      if (now == null || was == null || !now.alive) continue;
      if (now.nextTurn > was.nextTurn + 1e-9 ||
          now.stacks(StatusKind.freeze) > was.stacks(StatusKind.freeze)) {
        pushed.add(id);
      }
    }
    if (pushed.isEmpty) return step;
    s.roundOrder
      ..removeWhere(pushed.contains)
      ..addAll(pushed);
    return step;
  }

  /// ESPERAR (turn_modes.md § 4): [playerId], del bloque en curso, pasa al
  /// final de la ronda. Una vez por ronda, antes de actuar, y solo si
  /// queda alguien detrás suyo.
  BattleStep? _wait(BattleState state, String playerId) {
    if (!state.porRonda || !state.awaitingGroup) return null;
    if (!state.pendingGroup.any((p) => p.id == playerId)) return null;
    if (state.waited.contains(playerId)) return null;
    final rest = state.roundRemaining;
    final i = rest.indexWhere((c) => c.id == playerId);
    if (i < 0 || i == rest.length - 1) return null;
    final s = state.copy();
    final p = s.byId(playerId)!;
    if (p.extraTurn == 2 || p.chained) return null;
    s.roundOrder
      ..remove(playerId)
      ..add(playerId);
    s.waited.add(playerId);
    s.logLine = _l('wait_round', {'a': p.name});
    return BattleStep(s, const []);
  }

  /// TERMINAR TURNO (turn_modes.md § 3): [playerId] cierra su parte de la
  /// fase o del bloque sin actuar (o renuncia a la acción extra).
  BattleStep? _endTurnCmd(BattleState state, String playerId) {
    if (!state.awaitingGroup ||
        !state.pendingGroup.any((p) => p.id == playerId)) {
      return null;
    }
    final t = _Turn(this, state.copy()..currentId = playerId);
    final p = t.state.current!;
    // Si ya actuó (acción extra pendiente), sus efectos ya contaron.
    if (p.extraTurn != 2 && !p.chained) t.tickEffects(p);
    p.extraTurn = 0;
    t.state.logLine = _l('end_turn', {'a': p.name});
    t.endTurn();
    return t.result;
  }

  /// Se le acabó el tiempo al jugador de turno: se defiende solo.
  BattleStep? timeout(BattleState state) {
    if (state.awaitingGroup) {
      // porBando: se acabó el tiempo del grupo; los que faltaban se
      // defienden solos.
      final t = _Turn(this, state.copy());
      for (final p in t.state.pendingGroup) {
        if (t.state.ended) break;
        t.state.currentId = p.id;
        t._autoDefend(p);
      }
      return t.result;
    }
    final cur = state.current;
    if (state.ended || cur == null || !cur.isPlayer) return null;
    final t = _Turn(this, state.copy());
    t._autoDefend(t.state.current!);
    return t.result;
  }

  /// Un jugador llega a mitad de batalla (`addPlayer` con `S.battle`):
  /// entra con su vida/maná y su primer turno en `reloj + IV`. Si ya
  /// estaba, no cambia nada.
  /// [delay]: intervalos extra de espera del refuerzo (overworld_biomes.md
  /// § 5, `reinforceDelay`).
  BattleStep join(BattleState state, BattlePartyMember member,
      {double delay = 0}) {
    final s = state.copy();
    if (s.ended || s.party.any((c) => c.id == member.id)) {
      return BattleStep(s, const []);
    }
    final c = _playerCombatant(member);
    c.nextTurn = s.clock + interval(c) * (1 + math.max(0.0, delay));
    s.party.add(c);
    assignCombatantTags(s);
    return BattleStep(s, const []);
  }

  /// Un jugador se va de la sala en plena batalla: sale del timeline y,
  /// si tenía el turno, el turno queda libre.
  BattleStep leave(BattleState state, String playerId) {
    final s = state.copy();
    s.party.removeWhere((c) => c.id == playerId);
    if (s.currentId == playerId) s.currentId = null;
    return BattleStep(s, const []);
  }

  /// Una invocación de jefe (cristal, eco, siervo) de tipo [add]: vida ×
  /// [hpMult], ATQ × [atkMult], sin crítico, quiebre ni ULT.
  Combatant addCombatant(
      EnemyDef add, String id, double hpMult, double atkMult) {
    final hp = math.max(1, jsRound(add.hp * hpMult));
    return Combatant(
      id: id,
      name: add.name,
      isPlayer: false,
      hp: hp,
      maxHp: hp,
      speed: add.speed,
      attack: jsRound(add.attack * atkMult),
      critChance: 0,
      enemyType: add.id,
      pierce: add.pierce,
      inflicts: add.inflicts,
    );
  }

  // ------------------------------------------------------------------
  // Jugadores
  // ------------------------------------------------------------------

  Combatant _playerCombatant(BattlePartyMember m) {
    final cls = catalog.classes[m.build.classId]!;
    final w = m.build.equippedWeapon;
    final skills = [...cls.kitSkillIds, ...w.skillIds];
    // Habilidades trasladadas por fusión (loot v2) y la fusión vieja.
    for (final extra in [
      ...?m.build.item?.extraSkills,
      if (m.fusedSkillId != null) m.fusedSkillId!,
      ...m.extraSkills,
    ]) {
      if (catalog.skills.containsKey(extra) && !skills.contains(extra)) {
        skills.add(extra);
      }
    }
    // Kit de la ascensión (docs/specs/ascension.md § 4).
    final asc = kAscensions[m.build.ascension.id];
    if (asc != null && asc.classId == cls.id) {
      for (final id in asc.skillIds) {
        if (catalog.skills.containsKey(id) && !skills.contains(id)) {
          skills.add(id);
        }
      }
    }
    // Combo de clase (combo_balance.md § 5.2) y Quebrar de la ranura base
    // del arma (§ 5.1, loot.md § 16.3), al final de todo. Si el jugador la
    // reemplazó por fusión (`quebrarReplaced`), el arma no la trae.
    for (final combo in kClassComboSkill[cls.id] ?? const <String>[]) {
      if (catalog.skills.containsKey(combo) && !skills.contains(combo)) {
        skills.add(combo);
      }
    }
    final quebrar = quebrarSkillFor(w.type);
    if (!(m.build.item?.quebrarReplaced ?? false) &&
        catalog.skills.containsKey(quebrar) &&
        !skills.contains(quebrar)) {
      skills.add(quebrar);
    }
    final c = Combatant(
      id: m.id,
      name: m.name,
      isPlayer: true,
      hp: 0,
      maxHp: 1,
      speed: 1,
      attack: 1,
      critChance: 0,
      pierceWeakness: cls.pierceWeakness,
      statusWeakness: cls.statusWeakness,
      stunOnAttackChance: cls.stunOnAttackChance,
      duoStunBonus: cls.duoStunBonus,
      build: m.build.withBonusDefense(0),
      classId: cls.id,
      weaponType: w.type,
      skillIds: skills,
      potions: m.potions,
      ethers: m.ethers,
      aethers: m.aethers,
      ult: m.ult,
      skillScale: m.skillScale,
    );
    _refreshStats(c);
    c.hp = math.min(m.hp ?? c.maxHp, c.maxHp);
    c.mp = math.min(m.mp ?? c.maxMp.toDouble(), c.maxMp.toDouble());
    c.pulse = pulseStart;
    return c;
  }

  /// `stats(p)` dentro de la batalla: recalcula con el bonus de DEF actual.
  void _refreshStats(Combatant c) {
    // Sin build (kit del TUTORIAL): stats fijas.
    final build = c.build;
    if (build == null) return;
    final d = stats.calculate(build.withBonusDefense(c.bonusDefense));
    c
      ..maxHp = c.isPlayer ? jsRound(d.maxHp * (1 + townHp)) : d.maxHp
      ..maxMp = d.maxMp
      ..speed = d.speed
      ..attack = d.attack
      ..magic = d.magic
      ..critChance = d.critChance
      ..critMultiplier = d.critMultiplier
      ..defense = d.defense
      ..defensePercent = d.defensePercent
      ..ultChargeBonus = d.ultChargeBonus
      ..healBonus = d.healBonus
      ..statusBonus = Map.of(d.statusBonus)
      ..keystones = Set.of(d.keystones)
      ..mechanics = Set.of(d.mechanics)
      ..lifeSteal = d.lifeSteal
      ..regenPerTurn = d.regenPerTurn
      ..statusResist = d.statusResist
      ..healReceived = d.healReceived
      ..hp = math.min(c.hp, d.maxHp)
      ..mp = math.min(c.mp, d.maxMp.toDouble());
  }
}

class _Hit {
  final int damage;
  final bool critical;
  final Combatant target;

  /// Multiplicadores del árbol que entraron en el golpe (`× 1.15 Marca`).
  final List<LogLine> mods;
  const _Hit(this.damage, this.critical, this.target, [this.mods = const []]);
}

class _Hurt {
  final int damage;
  final bool critical;
  final double pierce;
  final double defensePercent;
  const _Hurt(this.damage, this.critical, this.pierce, this.defensePercent);
}

/// Contexto de una acción de jugador para el sistema de disparadores del
/// árbol v2 (passive_tree_v2.md § 5): qué acción es y qué efectos quedan
/// diferidos para después de los golpes primarios.
class _Action {
  SkillDef? skill;
  bool ultimate = false;

  /// Acción de daño a un solo objetivo (ataque, habilidad o ULT).
  bool single = false;
  Combatant? mainTarget;
  _Hit? mainHit;

  /// Daño base de la habilidad (para Eco Arcano) y bonus de su estado.
  double skillBase = 0;
  int skillStatusBonus = 0;

  /// Mecánicas ya disparadas en esta acción (`id` o `id|objetivo`).
  final fired = <String>{};

  double chain = 0;
  PassiveMechanic? chainSource;
  (Combatant, int, PassiveMechanic)? explosion;
  (double, PassiveMechanic)? repeat;
  PassiveMechanic? freeAttack;
  bool killed = false;
  bool extraTurn = false;

  /// Factor del próximo turno (Sed de Sangre: 0.5).
  double turnFactor = 1;

  /// Puntos de quiebre de la acción por objetivo (combo_balance.md § 5):
  /// ataque 4, habilidad física 6, mágica 4, ULT 12, dúo 10, Quebrar
  /// base 1. `null`: los del ataque básico.
  double? breakPoints;

  /// La acción tiene Quebrar (ULT, dúo, habilidad con `breaks`).
  bool canBreak = false;

  /// Objetivos que ya recibieron los puntos de quiebre de esta acción.
  final breakHit = <String>{};

  /// Dúo (la postura del Caballero Hueco no lo bloquea).
  bool dual = false;

  /// Ya ganó el +1 de Pulso por debilidad o reacción (una vez por acción).
  bool pulsed = false;
}

/// Contexto de una reacción para las mecánicas del árbol (§ 8 de
/// passive_tree_v4.md): tipo, stacks consumidos, quién detonó, a quiénes
/// ya les llegó (objetivo y salto) y el estado del golpe.
class _Rx {
  _Rx(this.kind, this.consumed, this.by, this.hitIds, this.hitStatus);
  final ReactionKind kind;
  final int consumed;
  final Combatant by;
  final Set<String> hitIds;
  final StatusApplication? hitStatus;
}

/// Un paso del motor sobre una copia del estado. Equivale al contexto
/// global (`S.battle`, `DEALT`, `ATT`) que el prototipo usaba durante
/// un `battleCmd`.
class _Turn {
  _Turn(this.engine, this.state);

  final BattleEngine engine;
  final BattleState state;
  final events = <BattleEvent>[];

  // `DEALT` / `DEALT_MHP` / `ATT` del prototipo.
  int _dealt = 0;
  int _dealtMaxHp = 1;
  Combatant? _attacker;

  /// Acción de jugador en curso (disparadores del árbol).
  _Action? _act;

  /// Efectos disparados que se agregan al log, con su origen.
  final _notes = <LogLine>[];
  int _procBudget = BattleEngine.maxProcsPerStep;

  /// Profundidad de la cadena de disparos en curso (`_fire` dentro de
  /// `_fire`), con tope en [BattleEngine.maxProcDepth].
  int _fireDepth = 0;

  /// Enemigos quebrados en este paso (su vulnerabilidad empieza a
  /// contar en el próximo turno del grupo).
  final _brokenNow = <String>{};

  /// Enemigos que quedaron Fisurados en este paso: Quebrar los quiebra
  /// recién desde el paso siguiente (dos pasos, combo_balance.md § 5).
  final _fissuredNow = <String>{};

  /// Enemigos cuya postura ya bloqueó en este paso (un evento por paso;
  /// también los ecos que recibieron daño reducido).
  final _resisted = <String>{};

  /// Jefes cuya inmunidad ya se avisó en este paso.
  final _immuneShown = <String>{};

  /// Derretidos en este paso: Choque Térmico igual los aturde (la
  /// reacción ya les quitó la Congelación).
  final _meltedNow = <String>{};

  /// Reacción cuyos disparadores del árbol se están evaluando
  /// (passive_tree_v4.md § 8).
  _Rx? _rx;

  /// Golpe de jugador cuyos `onHit` / `onCrit` se están disparando: si
  /// todavía no reaccionó, un estado elemental que el golpe deja por el
  /// árbol o el arma (Dios del Trueno...) lo detona
  /// (elemental_reactions.md § 9).
  ({Combatant target, int damage, bool reacted})? _hitNow;

  /// Hasted in this step (Prisa and every "next turn sooner" effect):
  /// reorders `porRonda` / `porFases` (turn_modes.md § 4.2).
  final _hasted = <String>{};

  BattleStep get result => BattleStep(state, List.unmodifiable(events));

  double _rand() => engine._random();
  double _iv(Combatant c) => engine.cappedInterval(state, c);
  Iterable<Combatant> get _aliveParty => state.party.where((p) => p.alive);

  /// Agrega los efectos disparados a la línea del log.
  void _flush() {
    if (_notes.isEmpty) return;
    state.logLine = LogLine.join([state.logLine, ..._notes]);
    _notes.clear();
  }

  // ---------------- turnos ----------------

  /// Tiempo agotado: [p] (que tiene el turno) se defiende solo.
  void _autoDefend(Combatant p) {
    events.add(ActionEvent(p.id, BattleActionKind.defend));
    p.defending = true;
    p.guardStreak = false;
    p.guardHitPending = false;
    _gainPulse(p);
    tickEffects(p);
    p.nextTurn = state.clock + _iv(p);
    state.logLine = _l('timeout_defend', {'a': p.name});
    endTurn();
  }

  /// `porBando` (roguelike.md § 6): turno del grupo y turno enemigo.
  /// Al empezar la ronda arrancan los turnos de todos los jugadores
  /// (estados, Pulso, aturdidos que pierden el turno) y nadie queda con
  /// el turno: actúa el primero que manda un comando. Cuando no queda
  /// ninguno, actúan las invocaciones y después los enemigos, de a uno y
  /// en orden de lista. La velocidad no cuenta.
  void _nextBando() {
    if (state.groupPhase) {
      if (state.pendingGroup.isNotEmpty) return;
      state.groupPhase = false;
    }
    // La pelea empieza con el turno del grupo.
    if (state.round > 0) {
      for (final c in [...state.summons, ...state.enemies]) {
        if (c.alive && !_passive(c) && !state.acted.contains(c.id)) {
          _beginTurn(c);
          return;
        }
      }
    }
    state
      ..round += 1
      ..acted.clear()
      ..groupPhase = true
      ..clock += 1;
    for (final p in [...state.party]) {
      if (state.ended) return;
      if (!p.alive) {
        state.acted.add(p.id);
        continue;
      }
      _beginTurn(p);
      state.currentId = null;
    }
    if (!state.ended) {
      final names = [for (final p in state.pendingGroup) p.name];
      state.logLine = names.isEmpty
          ? _l('group_turn_none')
          : _l('group_turn', {'a': names.join(', ')});
    }
  }

  /// `porFases` (turn_modes.md § 3): FASE ENEMIGA (enemigos de a uno, en
  /// orden de lista) y después FASE DE JUGADORES (como el turno del grupo
  /// de `porBando`); cuando todos los jugadores terminaron, actúan las
  /// invocaciones y empieza la ronda siguiente. Los efectos y cargas del
  /// grupo cuentan en sus propios turnos, nunca en la fase enemiga.
  /// `porFases`: the hasted of [side] (`roundOrder` holds Prisa's queue in
  /// this mode, turn_modes.md § 4.2), in queue order.
  List<Combatant> _hastedFirst(List<Combatant> side) => [
        for (final id in state.roundOrder)
          for (final c in side)
            if (c.id == id) c
      ];

  void _nextFases() {
    if (state.round == 0) {
      state
        ..round = 1
        ..acted.clear()
        ..groupPhase = false;
    }
    if (state.groupPhase) {
      if (state.pendingGroup.isNotEmpty) return;
      for (final c in [..._hastedFirst(state.summons), ...state.summons]) {
        if (c.alive && !state.acted.contains(c.id)) {
          _beginTurn(c);
          return;
        }
      }
      state
        ..round += 1
        ..acted.clear()
        ..groupPhase = false
        ..clock += 1;
      // Prisa on itself / after acting (§ 4.2): first in its phase, in
      // speed order.
      final next = [
        for (final id in state.hasteNext)
          if (state.byId(id) case final c? when c.alive) c
      ]..sort((a, b) => engine.interval(a).compareTo(engine.interval(b)));
      state.hasteNext.clear();
      state.roundOrder
        ..clear()
        ..addAll([for (final c in next) c.id]);
    }
    for (final c in [..._hastedFirst(state.enemies), ...state.enemies]) {
      if (c.alive && !_passive(c) && !state.acted.contains(c.id)) {
        _beginTurn(c);
        return;
      }
    }
    state.groupPhase = true;
    for (final p in [...state.party]) {
      if (state.ended) return;
      if (!p.alive) {
        state.acted.add(p.id);
        continue;
      }
      _beginTurn(p);
      state.currentId = null;
    }
    if (!state.ended) {
      final names = [for (final p in state.pendingGroup) p.name];
      state.logLine = names.isEmpty
          ? _l('player_phase_none')
          : _l('player_phase', {'a': names.join(', ')});
    }
  }

  /// `porRonda` (turn_modes.md § 4): al empezar la ronda se ordena a todos
  /// los vivos por velocidad efectiva (empate: orden de lista, grupo,
  /// invocaciones, enemigos). Cada uno actúa una vez. Los jugadores
  /// seguidos al frente de lo que falta forman un bloque: arrancan sus
  /// turnos juntos y actúa el primero que manda. Los cambios de velocidad
  /// rigen desde la ronda siguiente.
  void _nextRonda() {
    if (state.groupPhase) {
      if (state.pendingGroup.isNotEmpty) return;
      state.groupPhase = false;
    }
    if (state.round == 0 || state.roundRemaining.isEmpty) {
      final all = [
        for (final c in [...state.party, ...state.summons, ...state.enemies])
          if (c.alive && !_passive(c)) c
      ];
      final idx = {for (var i = 0; i < all.length; i++) all[i].id: i};
      final iv = {for (final c in all) c.id: engine.interval(c)};
      // Prisa on itself / after acting (§ 4.2): opens this round.
      final first = state.hasteNext.toSet();
      all.sort((a, b) {
        final h = (first.contains(a.id) ? 0 : 1)
            .compareTo(first.contains(b.id) ? 0 : 1);
        if (h != 0) return h;
        final d = iv[a.id]!.compareTo(iv[b.id]!);
        return d != 0 ? d : idx[a.id]!.compareTo(idx[b.id]!);
      });
      state.hasteNext.clear();
      state
        ..round += 1
        ..acted.clear()
        ..waited.clear()
        ..clock += 1
        ..roundOrder.replaceRange(
            0, state.roundOrder.length, [for (final c in all) c.id]);
      if (all.isEmpty) return;
    }
    final rest = state.roundRemaining;
    if (rest.isEmpty) return;
    final first = rest.first;
    if (!first.isPlayer || first.isSummon) {
      _beginTurn(first);
      return;
    }
    state.groupPhase = true;
    for (final p in state.roundBlock) {
      if (state.ended) return;
      // Quien esperó ya arrancó su turno en esta ronda.
      if (state.waited.contains(p.id)) continue;
      _beginTurn(p);
      state.currentId = null;
    }
    if (!state.ended) {
      final names = [for (final p in state.pendingGroup) p.name];
      if (names.isNotEmpty) {
        state.logLine = _l('round', {'n': state.round, 'a': names.join(', ')});
      }
    }
  }

  void nextTurn() {
    if (state.ended) return;
    if (state.porFases) {
      _nextFases();
      return;
    }
    if (state.porBando) {
      _nextBando();
      return;
    }
    if (state.porRonda) {
      _nextRonda();
      return;
    }
    Combatant? best;
    for (final c in [...state.party, ...state.enemies, ...state.summons]) {
      if (c.alive &&
          !_passive(c) &&
          (best == null || c.nextTurn < best.nextTurn)) {
        best = c;
      }
    }
    if (best == null) return;
    state.clock = math.max(state.clock, best.nextTurn);
    _beginTurn(best);
  }

  /// Empieza el turno de [best]: estados, Pulso, quiebre, trampas...
  /// Si lo pierde (aturdido, quebrado) el turno queda libre.
  void _beginTurn(Combatant best) {
    state.currentId = best.id;
    best.ultBonusTurn = 0;
    events.add(TurnStartedEvent(best.id));
    if (best.isSummon) {
      state.logLine = _l('turn_of', {'a': best.name});
      return;
    }
    if (best.isPlayer && !best.isSummon && state.grouped) {
      // A new phase for this character (combat.md § "Nadie solo en una
      // fase").
      for (final e in state.enemies) {
        e.phaseDealt.remove(best.id);
      }
    }
    if (best.isPlayer) {
      // Racha de Defender: solo sigue si viene de un Defender elegido.
      if (!best.defending) best.guardStreak = false;
      best.guardHitPending = false;
      best.defending = false;
      best.protecting = false;
      best.extraTurn = best.extraTurn == 1 ? 2 : 0;
      // Pulso (combo_balance.md § 5.2): +1 al empezar su turno.
      best.chained = false;
      _gainPulse(best);
      state.logLine = _l('turn_of', {'a': best.name});
      _tickSilence(best);
      _decayPlayerBreak(best);
    } else {
      _decayBreak(best);
      _tickWard(best);
    }
    var (skip, text) = _statusTick(best);
    // Trampas del Trampero: saltan al empezar el turno del enemigo.
    if (!best.isPlayer && best.alive) _springTraps(best);
    // Lo Que Será (ULT v2): la marca baja y, en 0, cae.
    if (!best.isPlayer && best.alive) _tickDoom(best);
    // Disparo cargado (variantes): cae al empezar el turno del tirador.
    if (best.isPlayer && best.alive) _fireCharge(best);
    final cleared = state.enemies.every((e) => !e.alive);
    final wasBroken = best.isPlayer && best.vulnerable > 0;
    if (!skip && best.alive && best.breakSkip) {
      // Quebrado: pierde su turno (como aturdido).
      skip = true;
      best.breakSkip = false;
      events.add(BreakEvent(
          best.id, BreakPhase.skipped, best.breakGauge, best.breakMax));
      final t = _l('broken_skip', {'a': best.name});
      text = text == null ? t : text.plus(t);
    }
    var struggle = false;
    if (!skip && best.alive && best.isPlayer && best.webbed) {
      // Telaraña de la Matriarca: pierde el turno (solo: medio turno).
      best.webbed = false;
      skip = true;
      struggle = !_aliveParty.any((q) => q != best);
      events.add(BossMechanicEvent(best.id,
          struggle ? BossMechanicPhase.webStruggle : BossMechanicPhase.webSkip,
          targetId: best.id));
      final t = struggle
          ? _l('web_struggle', {'a': best.name})
          : _l('web_skip', {'a': best.name});
      text = text == null ? t : text.plus(t);
    }
    if (wasBroken) _tickPlayerBroken(best);
    if (text != null) state.logLine = text;
    // Regeneración del arma (afijo `del Renacer`, loot.md § 12).
    if (best.alive &&
        best.isPlayer &&
        best.regenPerTurn > 0 &&
        best.hp < best.maxHp) {
      final h = math.max(1, jsRound(best.maxHp * best.regenPerTurn));
      _heal(best, h);
      _notes.add(_l('weapon_regen', {'a': best.name, 'h': h}));
    }
    if (best.alive) _fire(ProcTrigger.onTurnStart, best);
    if (best.alive && best.isPlayer) _summonPactTick(best);
    if ((!best.alive || skip) && best.isPlayer) _tickVulnerable();
    _flush();
    if (!best.alive || skip || cleared) {
      if (skip) {
        tickEffects(best);
        best.nextTurn = state.clock +
            _iv(best) * (struggle ? kBossMechanics['telarana']!.soloValue : 1);
      }
      state.currentId = null;
      if (state.grouped) {
        state.acted.add(best.id);
      } else if (best.isPlayer && !best.isSummon) {
        _markActed(best);
      }
      _checkEnd();
    }
  }

  /// +[n] de Pulso a un jugador, con tope (combo_balance.md § 5.2).
  void _gainPulse(Combatant p, [int n = 1]) {
    if (!p.isPlayer || p.isSummon) return;
    p.pulse = math.min(BattleEngine.pulseMax, p.pulse + n);
  }

  void endTurn() {
    final cur = state.current;
    if (cur != null && cur.isPlayer) _tickVulnerable();
    if (cur != null && state.grouped) {
      // Por rondas / Por fases: el turno extra es una acción extra dentro
      // del mismo turno (turn_modes.md § 4).
      if (cur.isPlayer && !cur.isSummon && cur.extraTurn == 1 && cur.alive) {
        // Turno extra (Danza de Cuchillas): vuelve a actuar en este turno
        // del grupo (una vez).
        cur.extraTurn = 2;
      } else {
        state.acted.add(cur.id);
      }
    } else if (cur != null && cur.isPlayer && !cur.isSummon) {
      _markActed(cur);
    }
    _flush();
    state.currentId = null;
    _checkEnd();
  }

  /// Fin del turno de [c]: descuenta 1 turno a sus efectos con duración
  /// (los aplicados en este mismo turno empiezan a contar desde el
  /// próximo) y quita los que llegan a 0.
  void tickEffects(Combatant c) {
    if (c.effects.isEmpty) return;
    final next = <TimedEffect>[];
    for (final e in c.effects) {
      if (e.fresh) {
        next.add(e.copyWith(fresh: false));
      } else if (e.turns > 1) {
        next.add(e.copyWith(turns: e.turns - 1));
      }
    }
    c.effects = next;
  }

  void _checkEnd() {
    if (state.ended) return;
    if (state.enemies.every((e) => !e.alive)) {
      var xp = 0, credits = 0;
      for (final e in state.enemies) {
        final d = engine.catalog.enemies[e.enemyType]!;
        final m = e.elite ? 3 : 1;
        xp += d.xp * m;
        credits += d.credits * m;
      }
      state
        ..outcome = BattleOutcome(victory: true, xp: xp, credits: credits)
        ..currentId = null
        ..logLine = _l('victory', {'xp': xp, 'c': credits});
      events.add(BattleEndedEvent(true, xp, credits));
    } else if (state.party.every((p) => !p.alive)) {
      state
        ..outcome = const BattleOutcome(victory: false)
        ..currentId = null
        ..logLine = _l('defeat');
      events.add(const BattleEndedEvent(false, 0, 0));
    }
  }

  // ---------------- estados ----------------

  /// Alma de Hielo: algún jugador en pie con la keystone.
  bool get _almaHielo =>
      state.party.any((p) => p.alive && p.keystones.contains('almaHielo'));

  /// `statusTick`: devuelve (pierde el turno, texto para el log).
  (bool, LogLine?) _statusTick(Combatant a) {
    final parts = <LogLine>[];
    var total = 0;
    // El control se mira como estaba al EMPEZAR el turno: si el daño de
    // los estados transforma al Devorador (fase 2 limpia los estados), el
    // aturdimiento / congelación ya ganado igual le cuesta este turno.
    final stunnedAtStart = a.stacks(StatusKind.stun) > 0;
    // Hielo v0.7 (elemental_reactions.md § 7): con 5 stacks pierde el
    // turno y queda Quebradizo; el turno siguiente se descongela solo.
    final frozenAtStart =
        a.stacks(StatusKind.freeze) >= StatusKind.freeze.maxStacks &&
            !a.brittle;
    final brittleAtStart = a.brittle;
    if (a.freezeResist > 0) a.freezeResist--;
    // Mojado y Cargado: pierden 1 turno (no hacen daño).
    for (final k in const [StatusKind.wet, StatusKind.charged]) {
      final n = a.stacks(k);
      if (n > 0) a.statuses[k] = n - 1;
    }

    final burn = a.stacks(StatusKind.burn);
    if (burn > 0) {
      final d = math.max(1, math.min(8 * burn, jsRound(a.maxHp * 0.04 * burn)));
      total += d;
      parts.add(_l('tick_part', {'s': _st(StatusKind.burn), 'd': d}));
      a.statuses[StatusKind.burn] = burn ~/ 2;
    }
    final poison = a.stacks(StatusKind.poison);
    if (poison > 0) {
      final d =
          math.max(1, math.min(5 * poison, jsRound(a.maxHp * 0.03 * poison)));
      total += d;
      parts.add(_l('tick_part', {'s': _st(StatusKind.poison), 'd': d}));
      a.statuses[StatusKind.poison] = poison - 1;
    }
    final holy = a.stacks(StatusKind.holy);
    if (holy > 0) {
      // Ira Divina (Templario): el Sagrado de los enemigos hace más.
      // No muertos / espectros: el Sagrado arde más (bestiary.md § 1).
      // Simétrico (§ 5.3): la familia / raza vale también para jugadores.
      final d = jsRound(5 *
          holy *
          (a.isPlayer ? 1 : 1 + _aura(BuffStat.holyPower)) *
          (_fam(a)?.holyTick ?? 1));
      total += d;
      parts.add(_l('tick_part', {'s': _st(StatusKind.holy), 'd': d}));
      a.holyTurns = (a.holyTurns == 0 ? 1 : a.holyTurns) - 1;
      if (a.holyTurns <= 0) a.statuses[StatusKind.holy] = 0;
    }

    LogLine? healText;
    final regen = a.stacks(StatusKind.regen);
    if (regen > 0 && a.alive) {
      final hh = jsRound(a.maxHp * 0.05);
      final mm = jsRound(a.maxMp * 0.05);
      final harm = _fam(a)?.healHarm ?? 0;
      if (harm > 0) {
        // Raza / familia a la que las curas dañan (no muertos).
        a.statuses[StatusKind.regen] = regen - 1;
        final d = _rawDamage(
            null, a, math.max(1, jsRound(hh * harm)), kHealHarmSourceId);
        healText = _l('regen_burns', {'a': a.name, 'd': d});
      } else {
        a.hp = math.min(a.maxHp, a.hp + hh);
        if (a.maxMp > 0) a.mp = math.min(a.maxMp.toDouble(), a.mp + mm);
        a.statuses[StatusKind.regen] = regen - 1;
        healText = mm > 0
            ? _l('regen_hp_mp', {'a': a.name, 'h': hh, 'm': mm})
            : _l('regen_hp', {'a': a.name, 'h': hh});
        events.add(HealEvent(a.id, hh));
        if (mm > 0) events.add(HealEvent(a.id, mm, mana: true));
      }
    }

    if (total > 0) {
      total = _limitEnemyHit(a, total);
      _chargeUlt(a, math.min(total, a.hp));
      a.hp = math.max(0, a.hp - total);
      final shift = !a.isPlayer && _gatePhase(a);
      events.add(DamageEvent(a.id, total,
          fromStatus: true,
          statusSource: burn > 0
              ? StatusKind.burn
              : poison > 0
                  ? StatusKind.poison
                  : StatusKind.holy));
      if (!a.alive) _knockedOut(a);
      if (shift) _transform(a);
    }

    var skip = false;
    var stunned = false;
    var locked = false;
    if (stunnedAtStart && a.alive) {
      skip = true;
      stunned = true;
      // Martillo Bendito: el aturdimiento dura un turno más (salvo que la
      // transformación se lo haya quitado).
      locked = a.hasEffect(BuffStat.stunLock) && a.stacks(StatusKind.stun) > 0;
      if (a.hasEffect(BuffStat.stunLock)) {
        a.effects =
            a.effects.where((e) => e.stat != BuffStat.stunLock).toList();
      }
      if (!locked) a.statuses[StatusKind.stun] = 0;
      events.add(TurnSkippedEvent(a.id, StatusKind.stun));
    } else if (frozenAtStart && a.alive) {
      // Congelado: pierde el turno y queda Quebradizo (el próximo golpe
      // físico hace ×1.5 y lo descongela).
      skip = true;
      a.brittle = true;
      events.add(TurnSkippedEvent(a.id, StatusKind.freeze));
      events.add(IceEvent(a.id, IcePhase.brittle));
    } else if (brittleAtStart && a.alive) {
      // Nadie lo rompió: se descongela solo (salvo Alma de Hielo).
      if (a.isPlayer || !_almaHielo) {
        _thawFreeze(a);
        _notes.add(_l('thaws', {'a': a.name}));
      }
    } else if (a.stacks(StatusKind.freeze) > 0 && (a.isPlayer || !_almaHielo)) {
      a.statuses[StatusKind.freeze] = a.stacks(StatusKind.freeze) - 1;
    }

    final texts = <LogLine>[
      if (total > 0)
        _l(a.alive ? 'tick_damage' : 'tick_damage_falls', {
          'a': a.name,
          'p': LogLine.join(parts, ' + '),
          'd': total,
        }),
      if (healText != null) healText,
      if (skip)
        _l(stunned ? 'stun_skip' : 'freeze_skip', {
          'a': a.name,
          'lock': locked ? 'yes' : 'no',
          'x': fm(_frz.brittleMult),
        }),
    ];
    return (skip, texts.isEmpty ? null : LogLine.join(texts));
  }

  /// `addStatus`. [source]: quién lo aplica; con [primary] (golpe
  /// primario de su acción) dispara `onStatusApplied`.
  /// Escudo compartido: aturdir extra de [s] si tiene un aliado vivo.
  double _duoStun(Combatant? s) => s != null &&
          s.isPlayer &&
          s.duoStunBonus > 0 &&
          _aliveParty.any((q) => q.id != s.id)
      ? s.duoStunBonus
      : 0;

  bool _addStatus(Combatant a, StatusApplication st,
      {int bonus = 0, Combatant? source, bool primary = false}) {
    if (!a.alive) return false;
    // Séquito del Espectro Coronado: inmune a los estados.
    if (!a.isPlayer && _immune(a)) {
      if (_immuneShown.add(a.id)) {
        events.add(BossMechanicEvent(a.id, BossMechanicPhase.immune));
        _notes.add(_l('immune_retinue', {'a': a.name}));
      }
      return false;
    }
    // Alma de Hielo: no puede aplicar Quemadura.
    if (st.kind == StatusKind.burn &&
        source != null &&
        source.keystones.contains('almaHielo')) {
      return false;
    }
    if (st.chance != null &&
        _rand() >=
            st.chance! + (st.kind == StatusKind.stun ? _duoStun(source) : 0)) {
      return false;
    }
    // Recién descongelado: resiste la Congelación (§ 7).
    if (st.kind == StatusKind.freeze && a.freezeResist > 0) {
      if (_immuneShown.add('${a.id}|resist')) {
        events.add(IceEvent(a.id, IcePhase.resisted));
        _notes.add(_l('freeze_resist', {'a': a.name}));
      }
      return false;
    }
    // Familia (bestiary.md § 1): inmunidades y stacks de más / de menos.
    final family = _fam(a);
    if (family != null && family.immune.contains(st.kind)) {
      if (_immuneShown.add('${a.id}|${st.kind.name}')) {
        _notes.add(_l('immune_family', {
          'a': a.name,
          's': _st(st.kind),
          'f': LogLine.named(
              'data.families.${family.family.name}', family.family.label),
        }));
      }
      return false;
    }
    final weak =
        a.isPlayer && a.statusWeakness > 0 && st.kind != StatusKind.regen
            ? a.statusWeakness
            : 0;
    var n = st.stacks + bonus + weak;
    // Resistencia del arma: menos stacks de daño / Congelación (mín. 1).
    if (a.isPlayer &&
        a.statusResist > 0 &&
        (st.kind == StatusKind.burn ||
            st.kind == StatusKind.poison ||
            st.kind == StatusKind.freeze)) {
      n = math.max(1, n - a.statusResist);
    }
    if (family != null) n = familyStacks(family, st.kind, n);
    if (st.kind.timed) {
      // Mojado / Cargado: no se acumulan, se renuevan a su duración.
      final turns = engine.catalog.elementStatus(st.kind).turns;
      if (turns <= 0) return false;
      a.statuses[st.kind] = math.max(a.stacks(st.kind), turns);
    } else {
      // Quemadura y Veneno: tope de stacks del catálogo (combo_balance.md
      // § 4: 30).
      final cap = st.kind == StatusKind.burn || st.kind == StatusKind.poison
          ? engine.catalog.combo.stackCap
          : st.kind.maxStacks;
      a.statuses[st.kind] = math.min(cap, a.stacks(st.kind) + n);
    }
    if (st.kind == StatusKind.holy) a.holyTurns = 3;
    if (st.kind == StatusKind.regen) a.statuses[StatusKind.regen] = 3;
    // Quién preparó la reacción (árbol v5: onPrimedReaction).
    if (source != null &&
        source.isPlayer &&
        !a.isPlayer &&
        kReactionTable.any((r) => r.primer == st.kind)) {
      a.primedBy[st.kind] = source.id;
    }
    events.add(StatusAppliedEvent(a.id, st.kind, n, weakness: weak > 0));
    if (source != null && source.isPlayer && !a.isPlayer) {
      if (st.kind == StatusKind.stun || st.kind == StatusKind.freeze) {
        _addBreak(a, engine.catalog.combo.breakStatus);
      }
      if (st.kind == StatusKind.stun && !a.boss) _extendStun(source, a);
      if (primary) {
        _fire(ProcTrigger.onStatusApplied, source, target: a, status: st.kind);
      }
    }
    return true;
  }

  /// Efecto `stunExtend` (Martillo Bendito): modificador, se aplica a
  /// todos los aturdimientos de [source] (también los secundarios).
  void _extendStun(Combatant source, Combatant target) {
    for (final m in _mechanicsOf(source)) {
      for (final fx in m.effects) {
        if (fx.kind != ProcEffectKind.stunExtend) continue;
        if (target.hasEffect(BuffStat.stunLock) || !_spend()) return;
        target.effects = [
          ...target.effects,
          TimedEffect(
              sourceId: m.id,
              stat: BuffStat.stunLock,
              value: 1,
              turns: fx.turns,
              ownerId: source.id),
        ];
        events.add(ProcEvent(source.id, m.id, targetId: target.id));
        events.add(
            BuffAppliedEvent(target.id, m.id, BuffStat.stunLock, 1, fx.turns));
        _notes.add(_l('stun_more', {'m': _mech(m), 'a': target.name}));
        return;
      }
    }
  }

  void _heal(Combatant q, int amount) {
    // Curación recibida del arma (afijo `de la Gracia`).
    if (q.isPlayer && q.healReceived != 0) {
      amount = math.max(1, jsRound(amount * (1 + q.healReceived)));
    }
    final before = q.hp;
    q.hp = math.min(q.maxHp, q.hp + amount);
    events.add(HealEvent(q.id, amount));
    // Jefes del Abismo: las curas del grupo los dañan.
    if (q.isPlayer) _abyssHealed(q, q.hp - before);
  }

  // ---------------- daño ----------------

  /// `hurt`: enemigo → jugador. Los escudos del árbol absorben antes que
  /// la vida; [from] es el enemigo que pega (Contraataque, Represalia).
  ///
  /// v0.7: el golpe tiene [element] (reacciones sobre el jugador, § 5.3)
  /// y la familia / raza del jugador cuenta como la de un enemigo.
  /// [inflicted]: el estado del golpe (Cortocircuito lo lleva al salto).
  _Hurt _hurt(Combatant p, double base, double critChance, bool pierce,
      {Combatant? from,
      GameElement element = GameElement.fisico,
      StatusApplication? inflicted}) {
    final crit = _rand() < critChance;
    // Reacción (una por golpe) o golpe a un Quebradizo (los golpes
    // enemigos cuentan como físicos).
    // El estado que deja el golpe también cuenta como su elemento (§ 9).
    final reaction = _reactionFor(p, element) ??
        _carriedReaction(p, [if (inflicted != null) inflicted]);
    var react = _reactionMult(reaction);
    if (reaction == null && _isBrittle(p)) react = _frz.brittleMult;
    // Familia / raza del jugador (null hasta que existan las razas).
    final affinity = familyMultiplier(_fam(p), {
      DamageTag.physical,
      if (damageTagOf(element) case final t?) t,
    });
    final pmul = pierce ? p.pierceWeakness : 1.0;
    final defp = p.defensePercent;
    // Marca del Vigilante del Vacío: +daño recibido.
    final marked = 1 + p.effectTotal(BuffStat.damageTaken);
    // Defensa de grupo (Estandarte, Bandera Firme, Bastión): tope 60%.
    final guard = math.min(
        BattleEngine.maxGuard,
        p.effectTotal(BuffStat.guard) +
            _aura(BuffStat.guard) +
            // Guarda propia por condición (árbol v3: Voto de Hierro, Inamovible).
            _conditionBonus(p, BuffStat.guard));
    var dmg = math.max(
      1,
      jsRound(base *
          (crit ? BattleEngine.enemyCritMultiplier : 1) *
          marked *
          pmul *
          (p.defending ? 0.5 : 1) *
          (1 - defp) *
          (1 - guard) *
          react *
          affinity),
    );
    // Player broken (combo_balance.md § 5.4): takes more damage.
    if (p.isPlayer && !p.isSummon && p.vulnerable > 0) {
      dmg = math.max(1, jsRound(dmg * BattleEngine.playerBrokenMult));
    }
    // Juramento Eterno (Guardián): parte del golpe va al Guardián.
    dmg -= _shareDamage(p, dmg);
    final absorbed = _absorb(p, dmg, from: from);
    var taken = dmg - absorbed;
    if (taken >= p.hp && p.hp > 0) taken = _cheatDeath(p, taken);
    if (taken > 0) {
      _ultWithBonus(p, taken / p.maxHp * _ultTaken);
    }
    if (p.defending && p.guardHitPending) {
      // Defender con valor: +6 de ULT al primer golpe recibido.
      p.guardHitPending = false;
      _ultWithBonus(p, BattleEngine.defendHitUlt);
    }
    p.hp = math.max(0, p.hp - taken);
    events.add(DamageEvent(p.id, taken,
        critical: crit,
        critMultiplier: BattleEngine.enemyCritMultiplier,
        pierceMultiplier: pmul,
        affinity: affinity));
    if (!p.alive) {
      events.add(KnockedOutEvent(p.id));
      p.voidMarked = false;
      _allyDown(p);
    }
    if (reaction != null) {
      _react(from, p, reaction, dmg, hitStatus: inflicted);
    } else if (react != 1) {
      _shatter(p);
    }
    if (from != null && !from.isPlayer && p.alive) _addPlayerBreak(p, dmg);
    if (from != null && p.alive) {
      _fire(ProcTrigger.onHitTaken, p, target: from, amount: dmg);
    }
    return _Hurt(dmg, crit, pmul, defp);
  }

  /// Los escudos de [p] absorben hasta [dmg]; devuelve cuánto absorbieron.
  /// Con [from], los escudos de un dueño con Égida Reflectante devuelven
  /// parte de lo absorbido al atacante.
  int _absorb(Combatant p, int dmg, {Combatant? from}) {
    if (!p.hasEffect(BuffStat.shield)) return 0;
    var left = dmg;
    final next = <TimedEffect>[];
    final byOwner = <String, int>{};
    // Variantes: escudos que reflejan, explotan o crecen (por habilidad).
    final reflects = <(String, SkillDef, int)>[];
    final bursts = <(String, SkillDef)>[];
    for (final e in p.effects) {
      if (e.stat != BuffStat.shield || left <= 0) {
        next.add(e);
        continue;
      }
      final v = e.value.round();
      final use = math.min(v, left);
      left -= use;
      final o = e.ownerId;
      if (o != null) byOwner[o] = (byOwner[o] ?? 0) + use;
      var rest = (v - use).toDouble();
      final sk = engine.catalog.skills[e.sourceId];
      if (sk != null && use > 0) {
        if (sk.shieldGrow > 0) {
          rest = math.max(
              rest,
              math
                  .min(p.maxHp * 0.5, rest + use * sk.shieldGrow)
                  .roundToDouble());
        }
        if (sk.shieldReflect > 0 && o != null) reflects.add((o, sk, use));
        if (sk.shieldBurst > 0 && rest <= 0 && o != null) bursts.add((o, sk));
      }
      if (rest > 0) next.add(e.copyWith(value: rest));
    }
    p.effects = next;
    final absorbed = dmg - left;
    if (absorbed > 0) {
      events.add(ShieldEvent(p.id, absorbed, absorbed: true));
      _notes.add(_l('shield_absorbs', {'a': p.name, 'd': absorbed}));
    }
    for (final (o, sk, use) in reflects) {
      final owner = state.byId(o);
      if (from == null || !from.alive || from.isPlayer || owner == null) {
        continue;
      }
      events.add(ProcEvent(owner.id, sk.id, targetId: from.id));
      final d = _procDamage(
          owner, from, math.max(1, jsRound(use * sk.shieldReflect)), sk.id);
      _notes.add(_l('reflects', {'s': _sk(sk), 'd': d, 'a': from.name}));
    }
    for (final (o, sk) in bursts) {
      final owner = state.byId(o);
      if (owner == null) continue;
      final foes = state.enemies.where((e) => e.alive).toList();
      if (foes.isEmpty) break;
      final d = math.max(1, jsRound(_atk(owner) * sk.shieldBurst));
      events.add(ProcEvent(owner.id, sk.id, targetId: p.id));
      for (final e in foes) {
        _procDamage(owner, e, d, sk.id);
      }
      _notes.add(_l('shield_burst', {'s': _sk(sk), 'd': d}));
    }
    if (from != null && from.alive && !from.isPlayer) {
      for (final e in byOwner.entries) {
        final owner = state.byId(e.key);
        if (owner == null || !owner.alive) continue;
        final r = _conditionBonus(owner, BuffStat.shieldReflect);
        if (r <= 0 || !_spend()) continue;
        final src = _sourceOf(owner, BuffStat.shieldReflect) ?? 'escudo';
        events.add(ProcEvent(owner.id, src, targetId: from.id));
        final d =
            _procDamage(owner, from, math.max(1, jsRound(e.value * r)), src);
        _notes.add(_l('src_dmg_to', {'m': _disp(src), 'd': d, 'a': from.name}));
      }
    }
    return absorbed;
  }

  // ---------------- ascensión (docs/specs/ascension.md § 3.1) ----------

  /// Suma de los `statBonus` de [stat] de las auras de grupo
  /// (`partyAura`) de los jugadores en pie.
  double _aura(BuffStat stat) {
    var t = 0.0;
    for (final q in state.party) {
      if (!q.alive) continue;
      for (final m in _mechanicsOf(q)) {
        if (m.trigger != ProcTrigger.partyAura) continue;
        for (final fx in m.effects) {
          if (fx.kind == ProcEffectKind.statBonus && fx.stat == stat) {
            t += fx.value;
          }
        }
      }
    }
    return t;
  }

  /// La primera mecánica de [c] que da `statBonus` de [stat].
  String? _sourceOf(Combatant c, BuffStat stat) {
    for (final m in _mechanicsOf(c)) {
      if (m.effects.any(
          (fx) => fx.kind == ProcEffectKind.statBonus && fx.stat == stat)) {
        return m.id;
      }
    }
    return null;
  }

  /// Juramento Eterno: un Guardián en pie (no [p]) recibe su parte de
  /// [dmg]. Devuelve cuánto se llevó.
  int _shareDamage(Combatant p, int dmg) {
    if (!p.isPlayer || dmg <= 1) return 0;
    for (final g in state.party) {
      if (g == p || !g.alive) continue;
      for (final m in _mechanicsOf(g)) {
        if (m.trigger != ProcTrigger.partyAura) continue;
        for (final fx in m.effects) {
          if (fx.kind != ProcEffectKind.statBonus ||
              fx.stat != BuffStat.shareDamage) {
            continue;
          }
          final part = math.min(dmg - 1, jsRound(dmg * fx.value));
          if (part <= 0) return 0;
          events.add(ProcEvent(g.id, m.id, targetId: p.id));
          final taken = part - _absorb(g, part);
          g.hp = math.max(g.practice ? 1 : 0, g.hp - taken);
          events.add(DamageEvent(g.id, taken, sourceId: m.id));
          _notes.add(_l('share_dmg',
              {'m': _mech(m), 'a': g.name, 'd': part, 'b': p.name}));
          if (!g.alive) {
            events.add(KnockedOutEvent(g.id));
            g.voidMarked = false;
            _allyDown(g);
          }
          return part;
        }
      }
    }
    return 0;
  }

  /// Inmortal / Mártir: el golpe mortal deja a [p] en 1 HP (1 vez por
  /// batalla y por dueño). Devuelve el daño que pasa.
  int _cheatDeath(Combatant p, int taken) {
    // De práctica (combat_tutorial.md § 3): queda en 1 de vida.
    if (p.practice) return math.max(0, p.hp - 1);
    // Primero la propia (Inmortal), después el aura de un aliado (Mártir).
    for (final pass in [false, true]) {
      for (final owner in pass ? state.party : [p]) {
        if (!owner.alive) continue;
        for (final m in _mechanicsOf(owner)) {
          final ok = pass
              ? m.trigger == ProcTrigger.partyAura
              : m.trigger == ProcTrigger.always;
          if (!ok ||
              !m.effects.any((fx) => fx.kind == ProcEffectKind.cheatDeath) ||
              owner.once.contains(m.id)) {
            continue;
          }
          owner.once.add(m.id);
          events.add(ProcEvent(owner.id, m.id, targetId: p.id));
          _notes.add(_l('cheat_death', {'m': _mech(m), 'a': p.name}));
          return math.max(0, p.hp - 1);
        }
      }
    }
    return taken;
  }

  /// Cayó el jugador [p]: `onAllyDown` de los demás en pie.
  void _allyDown(Combatant p) {
    for (final q in state.party) {
      if (q != p && q.alive) _fire(ProcTrigger.onAllyDown, q, target: p);
    }
  }

  /// Las trampas de [e] saltan (al empezar su turno).
  void _springTraps(Combatant e) {
    final traps = [
      for (final fx in e.effects)
        if (fx.stat == BuffStat.trap) fx
    ];
    for (final t in traps) {
      if (!e.alive) return;
      final owner = t.ownerId == null ? null : state.byId(t.ownerId!);
      if (owner == null) continue;
      events.add(ProcEvent(owner.id, t.sourceId, targetId: e.id));
      final d = _procDamage(owner, e, math.max(1, t.value.round()), t.sourceId);
      _notes.add(_l('trap_springs', {'a': owner.name, 'd': d, 'b': e.name}));
      _fire(ProcTrigger.onTrap, owner, target: e, amount: d);
    }
  }

  /// Pone una trampa de [owner] en [target] (ATQ × [power]).
  void _plantTrap(Combatant owner, Combatant target, String sourceId,
      double power, int turns) {
    if (!target.alive || target.isPlayer) return;
    final dmg = math.max(
        1,
        jsRound(_atk(owner) *
            power *
            (1 + _conditionBonus(owner, BuffStat.trapPower))));
    final n = turns + _conditionBonus(owner, BuffStat.trapTurns).round();
    target.effects = [
      for (final e in target.effects)
        if (!(e.sourceId == sourceId && e.stat == BuffStat.trap)) e,
      TimedEffect(
          sourceId: sourceId,
          stat: BuffStat.trap,
          value: dmg.toDouble(),
          turns: n,
          ownerId: owner.id),
    ];
    events.add(BuffAppliedEvent(
        target.id, sourceId, BuffStat.trap, dmg.toDouble(), n));
  }

  /// Remata a [target] (no jefes ni élites) si quedó por debajo de
  /// [threshold] de su vida.
  void _execute(Combatant owner, Combatant target, double threshold,
      String sourceId, LogLine name) {
    if (!target.alive ||
        target.isPlayer ||
        target.boss ||
        target.elite ||
        target.hp >= target.maxHp * threshold) {
      return;
    }
    events.add(ProcEvent(owner.id, sourceId, targetId: target.id));
    // Aguanta una ronda (combat.md § "Límites"): el remate también.
    final d = _limitEnemyHit(target, target.hp);
    target.hp -= d;
    if (owner == _attacker) _dealt += d;
    events.add(DamageEvent(target.id, d, sourceId: sourceId));
    if (target.alive) return;
    _knockedOut(target);
    _notes.add(_l('executed', {'m': name, 'a': target.name}));
  }

  /// Buff de grupo de [owner] (con Eco del Grito y Señor de la Guerra).
  void _partyBuff(Combatant owner, String sourceId, LogLine name, BuffStat stat,
      double value, int turns,
      {String nameText = ''}) {
    final v = value * (1 + _conditionBonus(owner, BuffStat.buffPower));
    final n = turns + _conditionBonus(owner, BuffStat.buffTurns).round();
    final m = PassiveMechanic(
        id: sourceId,
        name: nameText,
        trigger: ProcTrigger.onSkill,
        effects: const [],
        description: '');
    for (final q in _aliveParty) {
      _giveEffect(q, owner, m, stat, v, n);
      events.add(BuffAppliedEvent(q.id, sourceId, stat, v, n));
    }
    _notes.add(_l('party_buff', {
      'm': name,
      'v': '${v < 0 ? '−' : '+'}${_pct(v)}',
      's': _stat(stat),
      't': _turnsL(n),
    }));
  }

  /// Escudo a todo el grupo: [frac] de la vida máx. de [owner].
  void _partyShield(Combatant owner, PassiveMechanic m, double frac, int turns,
      {Iterable<Combatant>? only}) {
    final amount = jsRound(owner.maxHp *
        frac *
        (1 + _conditionBonus(owner, BuffStat.shieldPower)));
    for (final q in only ?? _aliveParty.toList()) {
      _shield(q, owner, m, amount, turns);
    }
  }

  /// Adelanta a [allies] la fracción [frac] de su espera; sin aliados,
  /// adelanta el próximo turno de [owner] (tope [soloCap]).
  void _advance(
      Combatant owner, List<Combatant> allies, double frac, LogLine name,
      {double soloCap = 1}) {
    if (allies.isEmpty) {
      final act = _act;
      if (act == null || act.extraTurn) return;
      final f = math.min(frac, soloCap);
      act.turnFactor = math.min(act.turnFactor, 1 - f);
      _hasted.add(owner.id);
      _notes.add(_l('next_turn_sooner', {'m': name, 'p': _pct(f)}));
      return;
    }
    for (final (i, q) in allies.indexed) {
      _hasted.add(q.id);
      // 100% o más: actúa ya (en orden, después del reloj).
      q.nextTurn = frac >= 1
          ? math.min(q.nextTurn, state.clock + 0.01 * (i + 1))
          : math.max(state.clock + 0.01, q.nextTurn - _iv(q) * frac);
    }
    _notes.add(_l(frac >= 1 ? 'allies_act_now' : 'allies_advance', {
      'm': name,
      'a': allies.map((q) => q.name).join(', '),
      'n': allies.length,
      'p': _pct(frac),
    }));
  }

  /// Una habilidad como "mecánica" (origen de sus efectos con duración).
  PassiveMechanic _skillMech(SkillDef sk) => PassiveMechanic(
      id: sk.id,
      name: sk.name,
      trigger: ProcTrigger.onSkill,
      effects: const [],
      description: '');

  /// Debuffs y Silencio de una variante sobre el enemigo [e]
  /// (combat.md § "Variantes de habilidades").
  void _variantOnHit(Combatant p, Combatant e, SkillDef tk) {
    if (!e.alive || e.isPlayer) return;
    if (tk.debuffs.isNotEmpty) {
      final m = _skillMech(tk);
      for (final d in tk.debuffs) {
        _giveEffect(e, p, m, d.stat, d.value, d.turns);
        events.add(BuffAppliedEvent(e.id, tk.id, d.stat, d.value, d.turns));
      }
    }
    if (tk.ultDrain > 0 && e.ultId != null && !e.ultPending && e.ult > 0) {
      e.ult = math.max(0, e.ult - tk.ultDrain);
      _notes.add(_l(
          'ult_drain', {'s': _sk(tk), 'a': e.name, 'n': jsRound(tk.ultDrain)}));
    } else if (tk.ultDrain > 0 && e.ultPending) {
      // Avisada (ultimates_v2.md § 4.1): −1% de poder por punto, tope −40%.
      final before = e.ultWeaken;
      e.ultWeaken =
          math.min(BattleEngine.ultWeakenMax, e.ultWeaken + tk.ultDrain / 100);
      if (e.ultWeaken > before) {
        _notes.add(_l(
            'ult_weaken', {'s': _sk(tk), 'a': e.name, 'p': _pct(e.ultWeaken)}));
      }
    }
  }

  /// Texto de los debuffs de [tk] para el log.
  List<LogLine> _debuffText(SkillDef tk) => [
        for (final d in tk.debuffs)
          _l('debuff', {
            'x': switch (d.stat) {
              BuffStat.damageTaken => _l('debuff_mark', {'p': _pct(d.value)}),
              BuffStat.attack => _l('debuff_atk', {'p': _pct(d.value)}),
              BuffStat.speed => _l('debuff_speed', {'p': _pct(d.value)}),
              _ => _l('debuff_other', {'s': _stat(d.stat), 'p': _pct(d.value)}),
            },
            't': _turnsL(d.turns),
          }),
      ];

  /// Revive a [q] con la fracción `revive` de su vida (Resurrección),
  /// más la sinergia del árbol (combat.md § Revivir, [ReviveRules]).
  void _revive(Combatant p, Combatant q, SkillDef tk) {
    final frac = ReviveRules.lifeFor(p, tk.revive);
    final h = math.max(1, jsRound(q.maxHp * frac));
    _heal(q, h);
    if (tk.cleanse > 0) {
      for (final k in q.statuses.keys.toList()) {
        q.statuses[k] = 0;
      }
    } else {
      q.statuses[StatusKind.burn] = 0;
      q.statuses[StatusKind.poison] = 0;
    }
    q.nextTurn = state.clock + _iv(q);
    events.add(RevivedEvent(q.id));
    _fire(ProcTrigger.onHeal, p, target: q, amount: h);
    // Velo del Retorno: escudo según la Curación del lanzador.
    final shield = jsRound(q.maxHp * ReviveRules.shieldFraction(p.healBonus));
    if (shield > 0) {
      q.effects = [
        for (final fx in q.effects)
          if (fx.sourceId != kReviveVeilId) fx,
        TimedEffect(
            sourceId: kReviveVeilId,
            stat: BuffStat.shield,
            value: shield.toDouble(),
            turns: ReviveRules.shieldTurns,
            ownerId: p.id),
      ];
      events.add(ShieldEvent(q.id, shield));
    }
    state.logLine = LogLine.join([
      _l('revive', {
        'a': p.name,
        's': _sk(tk),
        'b': q.name,
        'h': h,
        'p': _pct(frac),
      }),
      if (shield > 0) _l('revive_veil', {'n': shield}),
    ]);
  }

  /// Atraviesa y rebota (variantes): golpes secundarios tras el golpe a
  /// [target]. Aplican el estado (sin disparar el árbol) y los debuffs.
  void _pierceAndBounce(Combatant p, SkillDef tk, Combatant target, double base,
      StatusApplication? st, int bonus,
      {bool blocked = false}) {
    void extra(Combatant e, double dmg, List<LogLine> parts,
        {String? from, bool pierced = false}) {
      final h = _damageEnemy(e, dmg, p.critChance + tk.critBonus,
          primary: false, chainFrom: from, pierced: pierced);
      parts.add(_l('dmg_to', {'d': h.damage, 'a': e.name}));
      if (st != null && !blocked) _addStatus(e, st, bonus: bonus, source: p);
      _variantOnHit(p, e, tk);
    }

    if (tk.pierce > 0) {
      final i = state.enemies.indexOf(target);
      final behind = [
        for (final e in state.enemies.skip(i + 1))
          if (e.alive) e
      ];
      final parts = <LogLine>[];
      for (final e in behind) {
        extra(e, base * tk.pierce, parts, pierced: true);
      }
      if (parts.isNotEmpty) {
        _notes.add(_l('pierces', {'p': LogLine.join(parts, ', ')}));
      }
    }
    if (tk.bounces > 0) {
      var last = target;
      var f = 1.0;
      final parts = <LogLine>[];
      for (var i = 0; i < tk.bounces; i++) {
        f *= 0.7;
        final others = [
          for (final e in state.enemies)
            if (e.alive && e != last) e
        ];
        final pick = others.isEmpty
            ? (last.alive ? last : null)
            : others[
                math.min(others.length - 1, (_rand() * others.length).floor())];
        if (pick == null) break;
        extra(pick, base * f, parts, from: last.id);
        last = pick;
      }
      if (parts.isNotEmpty) {
        _notes.add(_l('bounces', {'p': LogLine.join(parts, ', ')}));
      }
    }
  }

  /// Disparo cargado: al empezar el turno de [p] cae sobre su objetivo
  /// (o el primer enemigo en pie).
  void _fireCharge(Combatant p) {
    final ch = [
      for (final e in p.effects)
        if (e.stat == BuffStat.charge) e
    ];
    if (ch.isEmpty) return;
    p.effects = [
      for (final e in p.effects)
        if (e.stat != BuffStat.charge) e
    ];
    for (final c in ch) {
      final foes = state.enemies.where((e) => e.alive).toList();
      if (foes.isEmpty) return;
      final t = foes.where((e) => e.id == c.ownerId).firstOrNull ?? foes.first;
      final sk = engine.catalog.skills[c.sourceId] ?? _ultById(c.sourceId);
      events.add(ProcEvent(p.id, c.sourceId, targetId: t.id));
      final d =
          _skillProcDamage(p, t, math.max(1, c.value.round()), c.sourceId, sk);
      var note = _l('charged_shot', {
        's': sk == null ? _l('charged_shot_name') : _sk(sk),
        'a': p.name,
        'd': d,
        'b': t.name,
      });
      final st = sk?.status;
      if (st != null && t.alive && _addStatus(t, st, source: p)) {
        note = note.plus(_st(st.kind));
      }
      _notes.add(note);
    }
  }

  /// Efectos de grupo / propios de una habilidad o ULT (kit de ascensión).
  void _skillExtras(Combatant p, SkillDef sk) {
    final asMech = PassiveMechanic(
        id: sk.id,
        name: sk.name,
        trigger: ProcTrigger.onSkill,
        effects: const [],
        description: '');
    for (final b in sk.partyBuffs) {
      _partyBuff(p, sk.id, _sk(sk), b.stat, b.value, b.turns,
          nameText: sk.name);
    }
    if (sk.partyShield > 0) {
      _partyShield(p, asMech, sk.partyShield, sk.partyShieldTurns);
    }
    // Variantes: escudo al aliado más herido / a uno mismo.
    if (sk.allyShield > 0) {
      final q = _lowest(_aliveParty, (c) => c.hp / c.maxHp);
      if (q != null) {
        _partyShield(p, asMech, sk.allyShield, sk.shieldTurns, only: [q]);
      }
    }
    if (sk.selfShield > 0 && p.alive) {
      _partyShield(p, asMech, sk.selfShield, sk.shieldTurns, only: [p]);
    }
    if (sk.advanceAllies > 0) {
      _advance(
          p,
          [
            for (final q in _aliveParty)
              if (q != p) q
          ],
          sk.advanceAllies,
          _sk(sk));
    }
    final sb = sk.selfBuff;
    if (sb != null) {
      _giveEffect(p, p, asMech, sb.stat, sb.value, sb.turns);
      events.add(BuffAppliedEvent(p.id, sk.id, sb.stat, sb.value, sb.turns));
      _notes.add(_l('self_buff', {
        's': _sk(sk),
        'p': _pct(sb.value),
        'x': _stat(sb.stat),
        't': _turnsL(sb.turns),
      }));
    }
    if (sk.selfTurn < 1) {
      final act = _act;
      if (act != null) {
        act.turnFactor = math.min(act.turnFactor, sk.selfTurn);
        _hasted.add(p.id);
      }
    }
    if (sk.protect) p.protecting = true;
    // Pulso Magitec: +Pulso a todo el grupo.
    if (sk.pulseParty > 0) {
      for (final q in _aliveParty) {
        _gainPulse(q, sk.pulseParty);
      }
      _notes.add(_l('pulse_party', {'s': _sk(sk), 'n': sk.pulseParty}));
    }
  }

  /// Fin Prestado: quita los buffs (efectos positivos y escudos) de [e].
  void _stripBuffs(Combatant e, LogLine name) {
    if (!e.alive) return;
    final before = e.effects.length;
    e.effects = [
      for (final fx in e.effects)
        if (fx.value <= 0 ||
            fx.stat == BuffStat.stunLock ||
            fx.stat == BuffStat.damageTaken)
          fx,
    ];
    if (e.effects.length < before) {
      _notes.add(_l('strip_buffs', {'m': name, 'a': e.name}));
    }
  }

  /// Lo Que Será: al empezar el turno del marcado baja la cuenta; en 0
  /// cae el golpe y, si está Fisurado, se quiebra.
  void _tickDoom(Combatant e) {
    if (e.doomTurns <= 0) return;
    e.doomTurns--;
    if (e.doomTurns > 0) return;
    final owner = state.byId(e.doomBy ?? '') ?? e;
    final dmg = e.doom;
    e
      ..doom = 0
      ..doomBy = null;
    events.add(ProcEvent(owner.id, 'ult2_loQueSera', targetId: e.id));
    final d = _procDamage(owner, e, dmg, 'ult2_loQueSera');
    var note = _l('doom', {
      's': LogLine.named(CatalogKeys.ultName('ult2_loQueSera'), 'Lo Que Será'),
      'a': e.name,
      'd': d,
    });
    if (e.alive && e.fissured) {
      _break(e);
      note = note.plus(_l('broken_tag'));
    }
    _notes.add(note);
  }

  /// Bonus de las condiciones del árbol de [a] (Último Aliento, Fractura,
  /// Punto Débil) sobre [stat], contra [target] si hay.
  double _conditionBonus(Combatant a, BuffStat stat, [Combatant? target]) {
    var total = 0.0;
    for (final (_, v) in _conditionParts(a, stat, target)) {
      total += v;
    }
    return total;
  }

  /// Las condiciones de [a] que suman a [stat] (mecánica, valor).
  List<(PassiveMechanic, double)> _conditionParts(Combatant a, BuffStat stat,
      [Combatant? target]) {
    final out = <(PassiveMechanic, double)>[];
    for (final m in _mechanicsOf(a)) {
      var scale = 1.0;
      final ok = switch (m.trigger) {
        ProcTrigger.whileLowHealth => a.hp < a.maxHp * m.threshold,
        ProcTrigger.vsStatus =>
          target != null && m.status != null && target.stacks(m.status!) > 0,
        ProcTrigger.vsMarked =>
          target != null && target.hasEffect(BuffStat.damageTaken),
        ProcTrigger.always => true,
        ProcTrigger.whileMissingHealth => () {
            scale = (1 - a.hp / a.maxHp).clamp(0.0, 1.0);
            return scale > 0;
          }(),
        ProcTrigger.vsBroken => target != null && target.broken,
        ProcTrigger.vsFamily => target != null &&
            m.family != null &&
            _fam(target)?.family == m.family,
        ProcTrigger.vsElements => target != null &&
            kElementalStatuses.where((k) => target.stacks(k) > 0).length >=
                m.minStacks,
        _ => false,
      };
      if (!ok || !_filterOk(m, a)) continue;
      for (final fx in m.effects) {
        if (fx.kind == ProcEffectKind.statBonus && fx.stat == stat) {
          out.add((m, fx.value * scale));
        }
      }
    }
    return out;
  }

  /// Multiplicador de crítico de [a] (con Un Disparo, Una Baja y Leyenda
  /// del Gatillo).
  double _critMult(Combatant? a) => a == null
      ? 1.5
      : a.critMultiplier +
          _conditionBonus(a, BuffStat.critMulti) +
          a.effectTotal(BuffStat.critMulti);

  /// Bonus al llenado de quiebre de las pasivas de arma de [a] contra
  /// [target] (Rompehielos, Grieta).
  double _breakBonus(Combatant a, Combatant target) {
    var total = 0.0;
    for (final m in _mechanicsOf(a)) {
      final ok = switch (m.trigger) {
        ProcTrigger.vsStatus =>
          m.status != null && target.stacks(m.status!) > 0,
        ProcTrigger.vsMarked => target.hasEffect(BuffStat.damageTaken),
        ProcTrigger.vsBroken => target.broken,
        ProcTrigger.whileLowHealth => a.hp < a.maxHp * m.threshold,
        ProcTrigger.always => true,
        _ => false,
      };
      if (!ok) continue;
      for (final fx in m.effects) {
        if (fx.kind == ProcEffectKind.breakBonus) total += fx.value;
      }
    }
    return total;
  }

  /// Puntos de quiebre de la acción en curso de [a] sobre [e]
  /// (combo_balance.md § 5): los de la acción, +50% a una debilidad, ×
  /// (1 + quiebre extra de la habilidad, del árbol / pasivas de arma, del
  /// afijo "rompedor" y de las armas pesadas).
  double _breakPoints(Combatant a, Combatant e, {required bool weak}) {
    final combo = engine.catalog.combo;
    var pts = _act?.breakPoints ?? combo.breakAttack;
    if (weak) pts *= 1 + combo.breakWeak;
    final bonus = _breakBonus(a, e) +
        (_act?.skill?.breakBonus ?? 0) +
        SummonRules.affix(a.build, ModStat.breakPower) *
            ModStat.breakPower.scale +
        CookingRules.breakBonus(a.build?.meal) +
        (kHeavyWeaponTypes.contains(a.weaponType) ? combo.heavyBreak : 0);
    return pts * (1 + bonus);
  }

  /// ATQ efectivo: con buffs (Represalia) y Último Aliento.
  int _atk(Combatant p) {
    final b =
        p.effectTotal(BuffStat.attack) + _conditionBonus(p, BuffStat.attack);
    return b == 0 ? p.attack : math.max(1, jsRound(p.attack * (1 + b)));
  }

  /// Texto de la fuente de daño con ATQ efectivo (`ATQ 36 (30 +20%)`).
  LogLine _atkText(Combatant p) {
    final a = _atk(p);
    if (a == p.attack) return _l('src_atk', {'n': p.attack});
    final pct = jsRound((a / p.attack - 1) * 100);
    return _l('src_atk_mod',
        {'n': a, 'b': p.attack, 'p': '${pct >= 0 ? '+' : ''}$pct%'});
  }

  /// `dmgEnemy`: jugador → enemigo. Con [primary] (golpe de la acción,
  /// no de una mecánica) dispara `onHit` / `onCrit`.
  _Hit _damageEnemy(Combatant e, double base, double critChance,
      {bool primary = true,
      bool single = false,
      int hitIndex = 0,
      String? chainFrom,
      bool pierced = false,
      Set<DamageTag>? tags,
      GameElement? element,
      bool? physical,
      StatusApplication? hitStatus}) {
    final a = _attacker;
    final cm = _critMult(a);
    // Elemento del golpe (v0.7): el de la habilidad de la acción, si no
    // físico (ataque normal).
    // Catalizador (Elementalista, ascension.md § 4.1): toma el elemento
    // que reacciona con lo que tenga el objetivo.
    final sk0 = _act?.skill;
    final catalyst = element == null && sk0 != null ? sk0.catalyst : 0.0;
    final el = element ??
        (catalyst > 0 ? _catalystElement(e) : null) ??
        elementOf(sk0?.id);
    // Sinergia del elemento de base del arma (weapon_identity.md § 4):
    // las habilidades del mismo elemento pegan +8 %.
    final weaponEl = a == null ? null : weaponElementOf(a.build?.item);
    final phys = physical ??
        (_act?.skill == null || _act!.skill!.kind == SkillKind.physical);
    var chance = critChance;
    var mult = 1.0;
    final mods = <LogLine>[];
    if (a != null) {
      chance +=
          _conditionBonus(a, BuffStat.crit, e) + a.effectTotal(BuffStat.crit);
      if (a.keystones.contains('danza')) chance = math.min(chance, 0.40);
      final parts = _conditionParts(a, BuffStat.damage, e);
      var dmgBonus = 0.0;
      for (final (_, v) in parts) {
        dmgBonus += v;
      }
      // Buffs de daño con duración (Combo de Equipo; árbol v6:
      // Preparación, Golpe Maestro, Ejecución Pública). Antes de la v0.8
      // no se leían (passive_tree_v6.md § 5).
      final buff = a.effectTotal(BuffStat.damage);
      if (buff != 0) {
        mult *= 1 + buff;
        mods.add(_mod(1 + buff, _l('mod.buff')));
      }
      // Aura Sagrada (Templario): todo el grupo hace más daño.
      final aura = a.isPlayer ? _aura(BuffStat.damage) : 0.0;
      if (dmgBonus != 0) {
        mult *= 1 + dmgBonus;
        final seen = <String>{};
        mods.add(_mod(
            1 + dmgBonus,
            LogLine.join([
              for (final p in parts)
                if (seen.add(p.$1.name)) _mech(p.$1),
            ], ' + ')));
      }
      if (aura != 0) {
        mult *= 1 + aura;
        mods.add(_mod(1 + aura, _l('mod.aura')));
      }
      if (weaponEl != null &&
          primary &&
          sk0 != null &&
          el == weaponEl &&
          kWeaponElementSynergy != 0) {
        mult *= 1 + kWeaponElementSynergy;
        mods.add(_mod(1 + kWeaponElementSynergy,
            _l('mod.weapon_el', {'e': _el(weaponEl)})));
      }
      if (single && primary && a.keystones.contains('cadena')) {
        mult *= 0.8;
        mods.add(_mod(
            0.8,
            LogLine.named(
                CatalogKeys.nodeName('viento_k'), 'Cadena Infinita')));
      }
    }
    final family = _fam(e);
    var taken = e.effectTotal(BuffStat.damageTaken);
    // Bestias: la Marca pega más (bestiary.md § 1).
    if (taken > 0) taken *= family?.markMult ?? 1;
    if (taken != 0) {
      mult *= 1 + taken;
      mods.add(_mod(1 + taken, _l('mod.mark')));
    }
    // Área (combo_balance.md § 4): las habilidades a todos pegan menos
    // por blanco; sus estados entran completos. Las ULT no.
    final areaSkill = primary &&
        sk0 != null &&
        sk0.allTargets &&
        !(_act?.ultimate ?? false) &&
        !(_act?.dual ?? false);
    final areaMult = engine.catalog.combo.areaMult;
    if (areaSkill && areaMult != 1) {
      mult *= areaMult;
      mods.add(_mod(areaMult, _l('mod.area')));
    }
    final vul = e.broken;
    if (vul) {
      mult *= 1 + BattleEngine.vulnerableBonus;
      mods.add(_mod(1 + BattleEngine.vulnerableBonus, _l('mod.break')));
    }
    final armor = engine.catalog.enemies[e.enemyType]?.armor ?? 0;
    if (armor > 0) {
      mult *= 1 - armor;
      mods.add(_mod(1 - armor, _l('mod.armor')));
    }
    // Tank Defense (combat.md § "Tanques").
    final guard = BattleEngine.tankGuard;
    if (e.defending && !e.isPlayer && guard > 0 && guard < 1) {
      mult *= guard;
      mods.add(_mod(guard, _l('mod.tank_guard')));
    }
    // Familia: debilidades y resistencias por tipo de daño
    // (bestiary.md § 1.3).
    final hitTags = {
      ...(tags ?? skillDamageTags(_act?.skill)),
      if (damageTagOf(el) case final t?) t,
    };
    final affinity = _familyMods(family, hitTags, mods);
    // Tank ward (combat.md § "Tanques"): the warded element hits for
    // `wardMult` and no longer counts as a weakness.
    final warded = e.ward > 0 && e.ward <= DamageTag.values.length
        ? DamageTag.values[e.ward - 1]
        : null;
    final wardHit = warded != null && hitTags.contains(warded);
    final weakHit = familyFactors(family, hitTags)
        .any((f) => f.weak && !(wardHit && f.tag == warded));
    mult *= affinity;
    // Comida del jugador (farming.md § 17): resiste un elemento.
    if (e.isPlayer && e.build?.meal != null) {
      var res = 0.0;
      for (final tg in hitTags) {
        if (tg.isElement) {
          res = math.max(res, CookingRules.resist(e.build!.meal, tg));
        }
      }
      if (res > 0) {
        mult *= 1 - res;
        mods.add(_mod(1 - res, _l('mod.meal')));
      }
    }
    if (wardHit) {
      final w = BattleEngine.wardMult;
      mult *= w;
      mods.add(_mod(w, _l('mod.ward', {'t': _tagName(warded)})));
    }
    // Reacción elemental (una por golpe) o golpe físico a un Quebradizo
    // (elemental_reactions.md § 2 y § 7). Si el elemento propio del golpe
    // no reacciona, cuentan los estados que el golpe lleva (§ 9): los
    // extra de la habilidad (Electrólisis: Agua + Cargado) y los del
    // Avatar del Pacto.
    final carried = <StatusApplication>[
      if (hitStatus != null) hitStatus,
      if (element == null &&
          sk0 != null &&
          !kPrimeOnlySkills.contains(sk0.id)) ...[
        if (sk0.status != null) sk0.status!,
        ...sk0.extraStatuses,
      ],
      if (a != null) ..._avatarStatuses(a),
    ];
    final reaction = _reactionFor(e, el) ?? _carriedReaction(e, carried);
    var shatter = false;
    if (reaction != null) {
      final rm = _reactionMult(reaction);
      if (rm != 1) {
        mult *= rm;
        mods.add(_mod(rm, LogLine.upper(_rxL(reaction))));
      }
      if (catalyst > 0) {
        mult *= 1 + catalyst;
        mods.add(_mod(1 + catalyst, _l('mod.catalyst')));
      }
      final rb = a == null ? 0.0 : _modTotal(a, ProcEffectKind.reactionBonus);
      if (rb > 0) {
        mult *= 1 + rb;
        mods.add(_mod(1 + rb, _l('mod.reaction')));
      }
    } else if (phys && _isBrittle(e)) {
      shatter = true;
      mult *= _frz.brittleMult;
      mods.add(_mod(_frz.brittleMult, _l('mod.brittle')));
    }
    final res = primary ? _stanceResist(e) : 0.0;
    if (res > 0) {
      mult *= 1 - res;
      mods.add(_mod(1 - res, _l('mod.stance')));
      if (_resisted.add(e.id)) {
        events.add(
            BossMechanicEvent(e.id, BossMechanicPhase.resisted, value: res));
      }
    }
    // Ecos de la Hechicera: reciben daño reducido.
    final echo = _echoFactor(e);
    if (echo < 1) {
      mult *= echo;
      mods.add(_mod(echo, _l('mod.echo')));
      if (_resisted.add(e.id)) {
        events.add(
            BossMechanicEvent(e.id, BossMechanicPhase.echoResist, value: echo));
      }
    }
    // Jefes del Abismo: inmunidad, sello y aspecto (abyss_bosses.md § 2).
    final abyss = _abyssFactor(e, el, mods);
    mult *= abyss;
    // Esquiva de los comunes (solo tira el dado si la tiene).
    final ev = engine.catalog.enemies[e.enemyType]?.evasion ?? 0;
    if (primary && ev > 0 && _rand() < ev) {
      mult *= BattleEngine.evadeFactor;
      mods.add(_mod(BattleEngine.evadeFactor, _l('mod.evade')));
      events.add(BossMechanicEvent(e.id, BossMechanicPhase.evaded));
    }
    // Mitigación de grupo (combo_balance.md § 3.3): todo el daño directo
    // al enemigo, incluido el plano, salvo los golpes que detonan una
    // reacción (y las Convergencias, que no pasan por acá).
    var mitigation = 1.0;
    if (a != null && !e.isPlayer && reaction == null) {
      final curve = engine.catalog.curve;
      final n = state.party.length;
      final gm = curve.groupMitigationMult(n);
      if (gm != 1) {
        mult *= gm;
        mitigation *= gm;
        mods.add(_mod(gm, _l('mod.group', {'n': n})));
      }
      final zc = curve.zoneCMult(e.level);
      if (zc != 1) {
        mult *= zc;
        mitigation *= zc;
        mods.add(_mod(zc, _l('mod.zone_c')));
      }
    }
    final crit = _rand() < chance;
    var dmg = abyss == 0 || affinity == 0
        ? 0
        : math.max(1, jsRound(base * (crit ? cm : 1) * mult));
    // Tope por golpe sin debilidad (combo_balance.md § 3.2).
    if (a != null && dmg > 0) {
      final cap = _hitCapFor(a, e,
          weak: weakHit, reacted: reaction != null, broken: vul);
      if (cap != null && dmg > cap) {
        mods.add(_l('mod.cap_resist', {'n': cap}));
        dmg = cap;
      }
    }
    // Límites (combat.md § "Límites"): tope absoluto y aguanta una ronda.
    final limited = _limitEnemyHit(e, dmg);
    if (limited != dmg) {
      mods.add(_l(limited == e.hp - 1 ? 'mod.cap_hold' : 'mod.cap_top',
          {'n': limited}));
      dmg = limited;
    }
    // Quebrar (combo_balance.md § 5): el golpe quiebra a un Fisurado de
    // antes de este paso. Se mira antes de que el golpe sume puntos.
    final quebrar = primary &&
        a != null &&
        (_act?.canBreak ?? false) &&
        e.fissured &&
        !_fissuredNow.contains(e.id);
    final before = e.hp;
    e.hp = math.max(0, e.hp - dmg);
    final shift = _gatePhase(e);
    final lost = before - e.hp;
    _dealt += lost;
    _dealtMaxHp = math.max(_dealtMaxHp, e.maxHp);
    events.add(DamageEvent(e.id, dmg,
        critical: crit,
        critMultiplier: cm,
        vulnerable: vul,
        hitIndex: hitIndex,
        chainFrom: chainFrom,
        pierced: pierced,
        affinity: affinity));
    if (!e.alive) _knockedOut(e);
    if (shift) _transform(e);
    // La mitigación no atrasa la ULT enemiga: carga como sin mitigar.
    _chargeUlt(e, lost, scale: mitigation > 0 ? 1 / mitigation : 1);
    if (reaction != null) {
      _react(a, e, reaction, dmg, hitStatus: hitStatus ?? _act?.skill?.status);
    } else if (shatter) {
      _shatter(e);
    }
    // Avatar del Pacto (summoner.md § 7): los estados de lo absorbido.
    if (primary && a != null) _avatarHit(a, e);
    // La transformación vacía la barra: el golpe que la causa no llena.
    // Puntos de quiebre (§ 5): una vez por objetivo y acción, sin mirar el
    // daño; los golpes secundarios no suman.
    if (!shift && e.alive) {
      if (quebrar) {
        _break(e);
      } else if (primary &&
          a != null &&
          _act != null &&
          _act!.breakHit.add(e.id)) {
        _addBreak(e, _breakPoints(a, e, weak: weakHit));
      }
    }
    // Pulso: +1 por golpe a una debilidad o reacción, una vez por acción.
    if (primary &&
        a != null &&
        a.isPlayer &&
        _act != null &&
        !_act!.pulsed &&
        (weakHit || reaction != null)) {
      _act!.pulsed = true;
      _gainPulse(a);
    }
    final hit = _Hit(dmg, crit, e, mods);
    if (primary && a != null && _act != null) {
      final prevHit = _hitNow;
      _hitNow = (target: e, damage: dmg, reacted: reaction != null);
      _fire(ProcTrigger.onHit, a, target: e, amount: dmg);
      if (crit) _fire(ProcTrigger.onCrit, a, target: e, amount: dmg);
      _hitNow = prevHit;
    }
    return hit;
  }

  /// Daño secundario de una mecánica: sin crítico, solo la Marca del
  /// objetivo. No dispara nada (salvo las muertes).
  int _procDamage(Combatant owner, Combatant e, int amount, String sourceId) {
    if (!e.alive) return 0;
    final taken = e.effectTotal(BuffStat.damageTaken);
    final vul = e.broken;
    final abyss = _abyssFactor(e, null);
    final dmg = _limitEnemyHit(
        e,
        abyss == 0
            ? 0
            : math.max(
                1,
                jsRound(amount *
                    (1 + taken) *
                    _echoFactor(e) *
                    abyss *
                    (vul ? 1 + BattleEngine.vulnerableBonus : 1))));
    final before = e.hp;
    e.hp = math.max(0, e.hp - dmg);
    final shift = _gatePhase(e);
    final lost = before - e.hp;
    if (owner == _attacker) {
      _dealt += lost;
      _dealtMaxHp = math.max(_dealtMaxHp, e.maxHp);
    }
    events.add(DamageEvent(e.id, dmg, sourceId: sourceId, vulnerable: vul));
    if (!e.alive) _knockedOut(e);
    if (shift) _transform(e);
    _chargeUlt(e, lost);
    return dmg;
  }

  // ---------------- familias (docs/specs/bestiary.md § 1) ----------------

  /// Reglas de la familia / raza de [c] (`null`: sin familia o familias
  /// apagadas). Simétrico desde v0.7 (elemental_reactions.md § 5.3): un
  /// jugador con raza usa las mismas reglas que un enemigo.
  FamilyRule? _fam(Combatant c) {
    final f = c.family;
    return !engine.familiesEnabled || f == null ? null : kFamilyRules[f];
  }

  // ---------------- elementos v0.7 (elemental_reactions.md) ------------

  /// Reglas de la Congelación (§ 7).
  ElementStatusDef get _frz => engine.catalog.elementStatus(StatusKind.freeze);

  /// La reacción que detonaría un golpe de [el] sobre [t] (§ 2), o
  /// `null`. Congelación súbita solo si [t] se puede congelar.
  ReactionKind? _reactionFor(Combatant t, GameElement el) {
    if (el == GameElement.fisico || !t.alive) return null;
    for (final r in kReactionTable) {
      if (r.detonator != el || t.stacks(r.primer) <= 0) continue;
      if (r.kind == ReactionKind.congelacionSubita && !_canFreeze(t)) continue;
      return r.kind;
    }
    return null;
  }

  /// La reacción que detona algún estado que lleva el golpe ([carried],
  /// en orden), o `null` (§ 9: el golpe cuenta como de ese elemento).
  ReactionKind? _carriedReaction(
      Combatant t, Iterable<StatusApplication> carried) {
    for (final s in carried) {
      final el = statusElement(s.kind);
      if (el == null) continue;
      final r = _reactionFor(t, el);
      if (r != null) return r;
    }
    return null;
  }

  /// La reacción que detonaría un golpe de la habilidad [tk] sobre [t]
  /// (como la calcula `_damageEnemy`), o `null`.
  ReactionKind? _skillReaction(Combatant t, SkillDef tk) {
    final el =
        (tk.catalyst > 0 ? _catalystElement(t) : null) ?? elementOf(tk.id);
    final prime = kPrimeOnlySkills.contains(tk.id);
    return _reactionFor(t, el) ??
        _carriedReaction(t, [
          if (!prime && tk.status != null) tk.status!,
          if (!prime) ...tk.extraStatuses,
          if (_attacker case final a?) ..._avatarStatuses(a),
        ]);
  }

  /// La ULT [id] (de tipo de arma, de camino / Invocador o de ascensión).
  SkillDef? _ultById(String id) =>
      kWeaponUltSkills[id] ??
      engine.catalog.ultimates.values.where((u) => u.id == id).firstOrNull ??
      kAscensionUltimates.values.where((u) => u.id == id).firstOrNull;

  /// Daño de mecánica que repite / difiere un golpe de la habilidad [sk]
  /// (Eco Arcano, Disparo cargado): lleva su elemento, así que detona
  /// como el golpe original (§ 9). Devuelve el daño hecho.
  int _skillProcDamage(
      Combatant owner, Combatant e, int amount, String sourceId, SkillDef? sk) {
    final k = sk == null || !e.alive ? null : _skillReaction(e, sk);
    final d = _procDamage(
        owner,
        e,
        k == null ? amount : math.max(1, jsRound(amount * _reactionMult(k))),
        sourceId);
    if (k != null) _react(owner, e, k, d, hitStatus: sk!.status);
    return d;
  }

  /// Un estado elemental [st] que [owner] deja con el golpe en curso
  /// (`onHit` / `onCrit` del árbol o del arma: Dios del Trueno, Señora
  /// de las Mareas...) detona la reacción si el golpe no reaccionó ya
  /// (§ 9). Lo que falta del ×1.5 entra como daño de la reacción. Se
  /// resuelve ANTES de aplicar [st].
  void _procHitReact(Combatant owner, Combatant target, PassiveMechanic m,
      StatusApplication st) {
    final h = _hitNow;
    // Las mecánicas "contra un X" (`status`: Aguanieve sobre Mojados)
    // trabajan SOBRE el estado preparado: no lo detonan.
    if (h == null ||
        h.reacted ||
        h.target != target ||
        m.status != null ||
        (m.trigger != ProcTrigger.onHit && m.trigger != ProcTrigger.onCrit)) {
      return;
    }
    final el = statusElement(st.kind);
    if (el == null) return;
    final k = _reactionFor(target, el);
    if (k == null) return;
    _hitNow = (target: h.target, damage: h.damage, reacted: true);
    final rb = _modTotal(owner, ProcEffectKind.reactionBonus);
    final mult = _reactionMult(k) * (1 + rb);
    final total = math.max(h.damage, jsRound(h.damage * mult));
    if (total > h.damage) {
      _rawDamage(owner, target, total - h.damage, reactionSourceId(k));
    }
    _react(owner, target, k, total, hitStatus: st);
  }

  /// Elemento con el que un golpe catalizador detona lo que tiene [t]
  /// (orden de prioridad de la tabla), o `null` si no hay nada.
  GameElement? _catalystElement(Combatant t) {
    for (final r in kReactionTable) {
      if (t.stacks(r.primer) > 0 && _reactionFor(t, r.detonator) == r.kind) {
        return r.detonator;
      }
    }
    return null;
  }

  /// Suma de un modificador fijo (`always`) del árbol de [a]
  /// (`reactionBonus`, `healHarmBonus`).
  double _modTotal(Combatant a, ProcEffectKind kind) {
    var total = 0.0;
    for (final m in _mechanicsOf(a)) {
      if (m.trigger != ProcTrigger.always || !_filterOk(m, a)) continue;
      for (final fx in m.effects) {
        if (fx.kind == kind) total += fx.value;
      }
    }
    return total;
  }

  /// [t] puede quedar congelado ya (Congelación súbita).
  bool _canFreeze(Combatant t) =>
      t.freezeResist <= 0 &&
      !t.brittle &&
      t.stacks(StatusKind.freeze) < StatusKind.freeze.maxStacks &&
      !(_fam(t)?.immune.contains(StatusKind.freeze) ?? false) &&
      !(!t.isPlayer && _immune(t));

  /// Multiplicador del golpe que detona [k] (1 si no cambia el golpe).
  double _reactionMult(ReactionKind? k) => switch (k) {
        ReactionKind.electrocucion ||
        ReactionKind.derretir =>
          engine.catalog.reaction(k!).damageMult,
        _ => 1.0,
      };

  /// Quebradizo con Congelación encima.
  bool _isBrittle(Combatant c) => c.brittle && c.stacks(StatusKind.freeze) > 0;

  /// Se descongela: sin Congelación ni Quebradizo y, si estaba congelado,
  /// resistencia a la Congelación ([ElementStatusDef.turns]).
  void _thawFreeze(Combatant c, {bool resist = true}) {
    final wasFrozen =
        c.brittle || c.stacks(StatusKind.freeze) >= StatusKind.freeze.maxStacks;
    c.statuses[StatusKind.freeze] = 0;
    c.brittle = false;
    if (resist && wasFrozen) {
      c.freezeResist = math.max(c.freezeResist, _frz.turns);
      events.add(IceEvent(c.id, IcePhase.thawed));
    }
  }

  /// Un golpe físico rompió al Quebradizo [c].
  void _shatter(Combatant c) {
    _thawFreeze(c, resist: false);
    c.freezeResist = math.max(c.freezeResist, _frz.turns);
    events.add(IceEvent(c.id, IcePhase.shattered));
    _notes.add(_l('shatter', {'a': c.name, 'x': fm(_frz.brittleMult)}));
  }

  /// Los demás vivos del bando de [t], en orden de formación desde [t].
  List<Combatant> _sideOf(Combatant t) {
    final side = t.isPlayer ? state.party : state.enemies;
    final i = side.indexOf(t);
    final out = <Combatant>[];
    for (var k = 1; k < side.length; k++) {
      final c = side[(i + k) % side.length];
      if (c.alive && !_passive(c)) out.add(c);
    }
    return out;
  }

  /// La reacción [k]: [by] detonó el estado de [t] con un golpe de
  /// [hitDamage] (ya con el ×1.5 si corresponde). [hitStatus]: el estado
  /// del golpe (Cortocircuito lo lleva al salto).
  void _react(Combatant? by, Combatant t, ReactionKind k, int hitDamage,
      {StatusApplication? hitStatus}) {
    final def = engine.catalog.reaction(k);
    final consumed = t.stacks(k.primer);
    // La transformación (Devorador) pudo limpiar el estado.
    if (consumed <= 0) return;
    final primer = t.primedBy.remove(k.primer);
    final src = reactionSourceId(k);
    final splash = <String, int>{};
    var amount = hitDamage;
    switch (k) {
      case ReactionKind.electrocucion:
        t.statuses[StatusKind.wet] = 0;
        events.add(ReactionEvent(t.id, k, amount,
            sourceId: by?.id, consumedStacks: consumed));
        final stunned = def.stunTurns > 0 &&
            _addStatus(t, StatusApplication(StatusKind.stun, def.stunTurns),
                source: by);
        _notes.add(_l(stunned ? 'rx_electro_stun' : 'rx_electro',
            {'a': t.name, 'x': fm(def.damageMult)}));
      case ReactionKind.explosionToxica || ReactionKind.combustion:
        amount = _converge(by, t, k, def, consumed, splash);
      case ReactionKind.congelacionSubita:
        t.statuses[StatusKind.wet] = 0;
        final n = StatusKind.freeze.maxStacks - t.stacks(StatusKind.freeze);
        t.statuses[StatusKind.freeze] = StatusKind.freeze.maxStacks;
        events.add(ReactionEvent(t.id, k, 0,
            sourceId: by?.id, consumedStacks: consumed));
        events.add(StatusAppliedEvent(t.id, StatusKind.freeze, n));
        _notes.add(_l('rx_flash_freeze', {'a': t.name}));
      case ReactionKind.derretir:
        events.add(ReactionEvent(t.id, k, amount,
            sourceId: by?.id, consumedStacks: consumed));
        _meltedNow.add(t.id);
        _thawFreeze(t);
        _notes.add(_l('rx_melt', {'a': t.name, 'x': fm(def.damageMult)}));
      case ReactionKind.cortocircuito:
        t.statuses[StatusKind.charged] = 0;
        final next = _sideOf(t).firstOrNull;
        amount = 0;
        if (next != null && def.splash > 0) {
          amount = math.max(1, jsRound(hitDamage * def.splash));
          splash[next.id] = amount;
        }
        events.add(ReactionEvent(t.id, k, amount,
            sourceId: by?.id, consumedStacks: consumed, splash: splash));
        if (next != null && amount > 0) {
          final d = _rawDamage(by, next, amount, src);
          if (hitStatus != null && next.alive) {
            _addStatus(next, hitStatus, source: by);
          }
          _notes.add(_l('rx_short', {'a': next.name, 'd': d}));
        } else {
          _notes.add(_l('rx_short_none'));
        }
    }
    // Quiebre (combo_balance.md § 5): toda reacción suma puntos; una
    // Convergencia además tiene Quebrar.
    if (by != null && by.isPlayer && !t.isPlayer && t.alive) {
      if (k.convergence && t.fissured && !_fissuredNow.contains(t.id)) {
        _break(t);
      } else {
        _addBreak(t, engine.catalog.combo.breakReaction);
      }
    }
    // Combo entre jugadores: si detona otro, carga de ULT para los dos.
    if (k.convergence &&
        by != null &&
        by.isPlayer &&
        primer != null &&
        primer != by.id) {
      final q = state.party.where((c) => c.id == primer).firstOrNull;
      final bonus = engine.catalog.combo.ultBonus;
      if (q != null && q.alive && bonus > 0) {
        by.ult = math.min(100, by.ult + bonus);
        q.ult = math.min(100, q.ult + bonus);
        _notes
            .add(_l('combo_ult', {'a': q.name, 'b': by.name, 'n': fm(bonus)}));
      }
    }
    _reactionTriggers(by, t, k, hitDamage, consumed, primer,
        {t.id, ...splash.keys}, hitStatus);
    // Sello de un Jefe del Abismo: lo rompe la reacción pedida.
    _abyssReacted(by, t, k);
  }

  /// Convergencia [k] (combo_balance.md § 4): consume los [consumed]
  /// stacks de su estado y pega `vida máx. × perStack × stacks`, × débil /
  /// resiste al elemento que detona, con tope por común / élite / jefe y
  /// salpicadura a los demás del bando. Daño directo: ni tope por golpe ni
  /// mitigaciones. Llena [splash] y devuelve el daño al objetivo.
  int _converge(Combatant? by, Combatant t, ReactionKind k, ReactionDef def,
      int consumed, Map<String, int> splash) {
    final combo = engine.catalog.combo;
    t.statuses[k.primer] = 0;
    // Afinidad de la familia al elemento que detona.
    double affinity(Combatant c) {
      final tag = damageTagOf(k.detonator);
      if (tag == null) return 1;
      final fs = familyFactors(_fam(c), {tag});
      if (fs.any((f) => f.value == 0)) return 0;
      if (fs.any((f) => f.weak)) return combo.weakMult;
      if (fs.any((f) => f.value < 1)) return combo.resistMult;
      return 1;
    }

    int capped(Combatant c, double raw) {
      // Enemy Convergences: a player has its own, survivable cap.
      final cap = c.isPlayer
          ? EnemyComboTuning.playerCap
          : def.capFor(elite: c.elite, boss: c.boss);
      final d = cap > 0 ? math.min(raw, c.maxHp * cap) : raw;
      return d <= 0 ? 0 : math.max(1, jsRound(d));
    }

    final pct = def.perStack * consumed;
    final aff = affinity(t);
    final raw = t.maxHp * pct * aff;
    final amount = t.alive ? capped(t, raw) : 0;
    final others = _sideOf(t);
    if (def.splash > 0 && amount > 0) {
      for (final c in others) {
        final d = capped(c, amount * def.splash * affinity(c));
        if (d > 0) splash[c.id] = d;
      }
    }
    events.add(ReactionEvent(t.id, k, amount,
        sourceId: by?.id, consumedStacks: consumed, splash: splash));
    if (amount > 0) _rawDamage(by, t, amount, reactionSourceId(k));
    for (final c in others) {
      final d = splash[c.id];
      if (d != null) _rawDamage(by, c, d, reactionSourceId(k));
    }
    _notes.add(LogLine.join([
      _l('converge', {
        'r': LogLine.upper(_rxL(k)),
        'n': consumed,
        's': _st(k.primer),
        'p': '${fm(def.perStack * 100)}%',
        'q': '${fm(pct * 100)}%',
        'aff': aff == 1 ? '' : ' × ${fm(aff)}',
        'd': amount,
        'a': t.name,
        'cap': amount > 0 && amount < jsRound(raw) ? 'yes' : 'no',
      }),
      if (splash.isNotEmpty)
        _l('converge_splash', {
          'n': splash.length,
          'd': splash.values.map((d) => '$d').join(', '),
        }),
    ]));
    return amount;
  }

  /// Disparadores del árbol de una reacción que detonó [by] sobre [t]
  /// (passive_tree_v4.md § 8): `onReaction` (quien detonó),
  /// `onPrimedReaction` (quien preparó el estado consumido) y
  /// `onPartyReaction` (todo el grupo vivo). Solo jugadores sobre
  /// enemigos.
  void _reactionTriggers(
      Combatant? by,
      Combatant t,
      ReactionKind k,
      int hitDamage,
      int consumed,
      String? primer,
      Set<String> hitIds,
      StatusApplication? hitStatus) {
    if (by == null || !by.isPlayer || t.isPlayer) return;
    final prev = _rx;
    _rx = _Rx(k, consumed, by, hitIds, hitStatus);
    _fire(ProcTrigger.onReaction, by, target: t, amount: hitDamage);
    if (primer != null) {
      final q = state.party.where((c) => c.id == primer).firstOrNull;
      if (q != null && q.alive) {
        _fire(ProcTrigger.onPrimedReaction, q, target: t, amount: hitDamage);
      }
    }
    for (final q in state.party) {
      if (q.alive) {
        _fire(ProcTrigger.onPartyReaction, q, target: t, amount: hitDamage);
      }
    }
    _rx = prev;
  }

  /// Daño directo (reacciones, curas que dañan): sin crítico ni
  /// multiplicadores; a un jugador lo absorben sus escudos. Devuelve el
  /// daño hecho.
  int _rawDamage(Combatant? by, Combatant t, int amount, String sourceId) {
    if (!t.alive || amount <= 0) return 0;
    if (t.isPlayer) {
      final absorbed = _absorb(t, amount);
      var taken = amount - absorbed;
      if (taken >= t.hp) taken = _cheatDeath(t, taken);
      if (taken > 0) {
        _ultWithBonus(t, taken / t.maxHp * _ultTaken);
      }
      t.hp = math.max(0, t.hp - taken);
      events.add(DamageEvent(t.id, taken, sourceId: sourceId));
      if (!t.alive) {
        t.voidMarked = false;
        _knockedOut(t);
      }
      return taken;
    }
    // Jefe del Abismo inmune al daño (las curas que dañan sí entran).
    if (sourceId != kAbyssHealSourceId && _abyssFactor(t, null) == 0) {
      return 0;
    }
    amount = _limitEnemyHit(t, amount);
    final before = t.hp;
    t.hp = math.max(0, t.hp - amount);
    final shift = _gatePhase(t);
    final lost = before - t.hp;
    if (by != null && by == _attacker) {
      _dealt += lost;
      _dealtMaxHp = math.max(_dealtMaxHp, t.maxHp);
    }
    events.add(DamageEvent(t.id, amount, sourceId: sourceId));
    if (!t.alive) _knockedOut(t);
    if (shift) _transform(t);
    _chargeUlt(t, lost);
    // Daño directo (reacciones, curas que dañan): 0 puntos de quiebre
    // (combo_balance.md § 5); la reacción suma los suyos en `_react`.
    return amount;
  }

  /// Cura de habilidad de [p] a [q]; a una raza / familia con `healHarm`
  /// (no muerto) le hace daño (§ 5.4). Devuelve lo curado (0 si dañó).
  int _skillHeal(Combatant p, Combatant q, int amount) {
    final harm = _fam(q)?.healHarm ?? 0;
    if (harm <= 0) {
      _heal(q, amount);
      return amount;
    }
    final d = _rawDamage(
        null, q, math.max(1, jsRound(amount * harm)), kHealHarmSourceId);
    _notes.add(_l('heal_burns', {'a': q.name, 'd': d}));
    return 0;
  }

  /// Factor de la familia [r] para un golpe con [tags]; agrega cada
  /// factor a [mods] (`× 1.5 DÉBIL Sagrado`).
  double _familyMods(FamilyRule? r, Set<DamageTag> tags, List<LogLine> mods) {
    var m = 1.0;
    for (final f in familyFactors(r, tags)) {
      m *= f.value;
      final tag = LogLine.named(CatalogKeys.damageTag(f.tag), f.tag.label);
      mods.add(f.value == 0
          ? _l('mod.immune_tag', {'t': tag})
          : _mod(f.value,
              _l(f.weak ? 'mod.weak_tag' : 'mod.resist_tag', {'t': tag})));
    }
    return m;
  }

  /// Tope de daño de un golpe de [a] a [e] (combo_balance.md § 3.2), o
  /// `null` si no hay: golpe a una debilidad, reacción, enemigo quebrado
  /// o [a] con `overLevel` o más niveles sobre [e].
  /// Límites de un golpe a un enemigo (combat.md § "Límites"), después de
  /// todo lo demás: tope absoluto de jefe / élite (fracción de su vida
  /// máxima, aunque haya debilidad o quiebre) y "aguanta una ronda" de
  /// los comunes. Devuelve el daño que entra.
  int _limitEnemyHit(Combatant e, int dmg) {
    if (e.isPlayer || e.isSummon || dmg <= 0 || !e.alive) return dmg;
    final f = BattleEngine.absoluteHitCap(boss: e.boss, elite: e.elite);
    if (f > 0 && f < 1) {
      dmg = math.min(dmg, math.max(1, (e.maxHp * f).ceil()));
    }
    if (dmg >= e.hp && e.hp > 1 && _holds(e)) {
      state.acted.add(holdKey(e.id));
      dmg = e.hp - 1;
      _notes.add(_l('holds_round', {'a': e.name}));
    }
    final by = _phaseActor();
    if (by != null) {
      final dealt = e.phaseDealt[by.id] ?? 0;
      if (dmg >= e.hp && e.hp > 1 && _holdsPhase(e, by, dealt)) {
        dmg = e.hp - 1;
        _notes.add(_l('holds_phase', {'a': e.name, 'b': by.name}));
      }
      e.phaseDealt[by.id] = dealt + dmg;
    }
    return dmg;
  }

  /// Character whose phase is running (the player with the turn), or
  /// `null` (enemy or summon turn).
  Combatant? _phaseActor() {
    final c = state.current;
    if (c == null || !c.isPlayer || c.isSummon) return null;
    return c;
  }

  /// Nobody alone in one phase (combat.md § "Nadie solo en una fase"):
  /// [e] was at or above `phaseHold` of its max HP when [by]'s phase
  /// began ([dealt] = what [by] already took from it) and another living
  /// ally can still finish it.
  bool _holdsPhase(Combatant e, Combatant by, int dealt) {
    final f = BattleEngine.phaseHold;
    if (f <= 0) return false;
    if (e.hp + dealt < e.maxHp * f) return false;
    return state.party.any((p) => p.alive && !p.isSummon && p.id != by.id);
  }

  /// Start of an enemy's own turn: its Defense ends and its ward loses a
  /// turn (it drops at 0).
  void _tickWard(Combatant e) {
    if (engine.isTank(e)) e.defending = false;
    if (e.ward == 0) return;
    e.wardTurns -= 1;
    if (e.wardTurns > 0) return;
    final tag = DamageTag.values[e.ward - 1];
    e
      ..ward = 0
      ..wardTurns = 0;
    _notes.add(_l('ward_down', {'a': e.name, 't': _tagName(tag)}));
  }

  /// Tank turn (combat.md § "Tanques"): without a ward it defends and
  /// raises one. Returns `true` if that used its action.
  bool _tankGuard(Combatant e) {
    if (!engine.isTank(e) || e.ward != 0) return false;
    final tag = engine.chooseWard(state, e);
    events.add(ActionEvent(e.id, BattleActionKind.defend));
    e.defending = true;
    if (tag != null) {
      // +1: the tick at the start of its next turn does not count.
      e
        ..ward = tag.index + 1
        ..wardTurns = BattleEngine.wardTurns + 1;
    }
    state.logLine = tag == null
        ? _l('tank_guard', {'a': e.name})
        : _l('ward_up', {
            'a': e.name,
            't': _tagName(tag),
            'n': BattleEngine.wardTurns,
          });
    return true;
  }

  LogLine _tagName(DamageTag t) =>
      LogLine.named(CatalogKeys.damageTag(t), t.label);

  // ---------------- silence (combat.md § "Silencio") ----------------

  /// Silencer turn: on its opening action (acting before the party) or
  /// every `silenceEvery` own actions, it silences the player with the
  /// highest skill power. Returns `true` if that used its action.
  bool _castSilence(Combatant e) {
    if (!engine.isSilencer(e) || BattleEngine.silenceTurns <= 0) return false;
    final opening = e.once.remove(BattleEngine.silenceOpenKey);
    final every = BattleEngine.silenceEvery;
    if (!opening && (every <= 0 || e.actions % every != 0)) return false;
    final t = engine.silenceTarget(state);
    if (t == null) return false;
    events.add(ActionEvent(e.id, BattleActionKind.enemyAttack, targetId: t.id));
    // +1: the tick at the start of its next turn does not count.
    t.silenced = BattleEngine.silenceTurns + 1;
    state.logLine = _l('silence_cast',
        {'a': e.name, 'b': t.name, 'n': BattleEngine.silenceTurns});
    return true;
  }

  /// Start of a player's turn: Silence loses a turn.
  void _tickSilence(Combatant p) {
    // Negative = immune turns left after a Silence (silenceCooldown).
    if (p.silenced < 0) {
      p.silenced++;
      return;
    }
    if (p.silenced == 0) return;
    p.silenced--;
    if (p.silenced == 0) {
      _notes.add(_l('silence_ends', {'a': p.name}));
      p.silenced = -BattleEngine.silenceCooldown;
    }
  }

  // ---------------- player break (combo_balance.md § 5.4) -------------

  /// An enemy hit for [dmg] fills [p]'s break bar: a flat amount per hit
  /// plus per 1% of max HP (half while defending). Full: broken (loses
  /// its next turn, takes × `pBrokenMult` damage for `pBrokenTurns` own
  /// turns).
  void _addPlayerBreak(Combatant p, int dmg) {
    if (!BattleEngine.playerBreakOn ||
        !p.isPlayer ||
        p.isSummon ||
        p.vulnerable > 0 ||
        p.breakSkip) {
      return;
    }
    var amount = BattleEngine.playerBreakHit +
        (p.maxHp <= 0 ? 0 : dmg / p.maxHp * 100) * BattleEngine.playerBreakHp;
    if (p.defending) amount *= 0.5;
    if (amount <= 0) return;
    final max = BattleEngine.playerBreakMax(p);
    p.breakGauge = math.min(max, _r1(p.breakGauge + amount));
    if (p.breakGauge < max) {
      events.add(BreakEvent(p.id, BreakPhase.fill, p.breakGauge, max));
      return;
    }
    p
      ..breakGauge = max
      ..breakSkip = true
      ..vulnerable = BattleEngine.playerBrokenTurns;
    events.add(BreakEvent(p.id, BreakPhase.broken, max, max));
    _notes.add(_l('player_break', {
      'a': p.name,
      'p': jsRound((BattleEngine.playerBrokenMult - 1) * 100),
    }));
  }

  /// Start of a player's turn: the bar drops `pBreakDecay` of the
  /// threshold (not while broken).
  void _decayPlayerBreak(Combatant p) {
    if (p.vulnerable > 0 || p.breakSkip || p.breakGauge <= 0) return;
    final max = BattleEngine.playerBreakMax(p);
    p.breakGauge =
        math.max(0, _r1(p.breakGauge - max * BattleEngine.playerBreakDecay));
  }

  /// A broken player's own turn passed: one less turn vulnerable; at 0
  /// it recovers (bar to 0, threshold +25%).
  void _tickPlayerBroken(Combatant p) {
    if (p.vulnerable <= 0) return;
    p.vulnerable--;
    if (p.vulnerable > 0) return;
    p
      ..breakGauge = 0
      ..breaks += 1;
    if (!p.alive) return;
    events.add(BreakEvent(
        p.id, BreakPhase.recovered, 0, BattleEngine.playerBreakMax(p)));
    _notes.add(_l('break_recovers', {'a': p.name}));
  }

  /// Clave en `state.acted` de un común que ya aguantó en esta ronda.
  static String holdKey(String id) => '!aguanta:$id';

  /// [e] (común) aguanta un golpe letal: está activo para el grupo, no lo
  /// usó en esta ronda y queda algún jugador vivo, aparte del que tiene
  /// el turno, sin actuar en la ronda.
  bool _holds(Combatant e) {
    if (e.boss || e.elite) return false;
    final players = [
      for (final p in state.party)
        if (!p.isSummon) p
    ];
    if (!BattleEngine.holdsRound(coop: players.length > 1)) return false;
    if (state.acted.contains(holdKey(e.id))) return false;
    return players.any((p) =>
        p.alive && p.id != state.currentId && !state.acted.contains(p.id));
  }

  /// Carga de ULT extra ganada por cada combatiente en esta acción.
  final _ultBonusAct = <String, double>{};

  /// Suma a [c] carga de ULT extra (árbol, mods, efectos, invocaciones)
  /// con los topes por acción y por turno (combat.md § "Límites").
  /// Devuelve lo que entró. Lo negativo (mods en contra) no tiene tope.
  double _bonusUlt(Combatant c, double amount) {
    if (amount <= 0) {
      c.ult = math.max(0, math.min(100, c.ult + amount));
      return amount;
    }
    final act = BattleEngine.ultBonusPerAction - (_ultBonusAct[c.id] ?? 0);
    final turn = BattleEngine.ultBonusPerTurn - c.ultBonusTurn;
    final g = math.max(0.0, math.min(amount, math.min(act, turn)));
    if (g <= 0) return 0;
    _ultBonusAct[c.id] = (_ultBonusAct[c.id] ?? 0) + g;
    c.ultBonusTurn += g;
    c.ult = math.min(100, c.ult + g);
    return g;
  }

  /// Carga de ULT [base] (sin tope) más la parte de `ultChargeBonus`
  /// (árbol, mods) como carga extra con tope.
  void _ultWithBonus(Combatant c, double base) {
    c.ult = math.min(100, c.ult + base);
    _bonusUlt(c, base * c.ultChargeBonus);
  }

  /// Marca que [p] actuó en la ronda. En `velocidad` la ronda termina
  /// cuando actuaron todos los jugadores vivos (combat.md § "Límites");
  /// en `porBando` la cierra `_nextBando`.
  void _markActed(Combatant p) {
    state.acted.add(p.id);
    if (state.grouped || !p.isPlayer || p.isSummon) return;
    final done = state.party
        .where((q) => q.alive && !q.isSummon)
        .every((q) => state.acted.contains(q.id));
    if (done) {
      state
        ..round += 1
        ..acted.clear();
      for (final e in state.enemies) {
        e.phaseDealt.clear();
      }
    }
  }

  int? _hitCapFor(Combatant a, Combatant e,
      {required bool weak, required bool reacted, required bool broken}) {
    if (e.isPlayer || weak || reacted || broken) return null;
    final rule = engine.catalog.hitCap;
    final pl = a.build?.level ?? 0;
    final el = e.level > 0 ? e.level : (kEnemyBaseLevel[e.enemyType] ?? 1);
    if (pl > 0 && pl - el >= rule.overLevel) return null;
    final f = rule.fraction(
        elite: e.elite,
        boss: e.boss,
        partySize: state.party.length,
        zoneC: engine.catalog.curve.isZoneC(e.level));
    if (f >= 1) return null;
    return math.max(1, (e.maxHp * f).ceil());
  }

  /// Las curas de habilidad del grupo dañan a las familias con
  /// `healHarm` (no muertos, espectros): cada enemigo vivo así recibe
  /// [amount] × `healHarm` (más Marca y quiebre). Devuelve el texto del
  /// log ("¡La cura quema al Esqueleto! 34") o vacío.
  LogLine _healHarm(Combatant p, int amount) {
    final hit = <(Combatant, int)>[];
    for (final e in state.enemies) {
      if (!e.alive) continue;
      final r = _fam(e);
      if (r == null || r.healHarm <= 0) continue;
      // Luz Purificadora (árbol v5): +daño de tus curas a estas familias.
      final bonus = 1 + _modTotal(p, ProcEffectKind.healHarmBonus);
      final d = math.max(1, jsRound(amount * r.healHarm * bonus));
      hit.add((e, _procDamage(p, e, d, kHealHarmSourceId)));
    }
    if (hit.isEmpty) return LogLine.empty;
    if (hit.length == 1) {
      final (e, d) = hit.first;
      final fem = engine.catalog.enemies[e.enemyType]?.feminine ?? false;
      return _l('heal_burns_one', {'g': fem ? 'f' : 'm', 'a': e.name, 'd': d});
    }
    return _l('heal_burns_all',
        {'p': hit.map((h) => '${h.$1.name} ${h.$2}').join(', ')});
  }

  /// Un actor cae. Si es un enemigo: cuenta para `onKill` de la acción y
  /// dispara `onEnemyDeath` (Plaga) del primer jugador que la tenga.
  void _knockedOut(Combatant c) {
    // De práctica (combat_tutorial.md § 3): queda en 1 y no cae.
    if (c.practice) {
      c.hp = 1;
      _notes.add(c.isPlayer
          ? _l('practice_hold', {'a': c.name})
          : _l('practice_recover', {'a': c.name.toLowerCase()}));
      return;
    }
    events.add(KnockedOutEvent(c.id));
    if (c.isPlayer) {
      _allyDown(c);
      return;
    }
    _mechanicDeath(c);
    _act?.killed = true;
    // Cada mecánica `onEnemyDeath` dispara una vez por muerte: la del
    // primer jugador que la tenga (Plaga, Detonación).
    final used = <String>{};
    for (final p in state.party) {
      if (!p.alive) continue;
      if (_mechanicsOf(p).any((m) => m.trigger == ProcTrigger.onEnemyDeath)) {
        _fire(ProcTrigger.onEnemyDeath, p, target: c, once: used);
      }
    }
  }

  /// `dmgLog`: el desglose que ve el jugador. Muestra siempre el
  /// multiplicador de crítico real del atacante.
  LogLine _damageLog(
    LogLine head,
    LogLine source,
    num sourceValue,
    double power,
    List<_Hit> hits, {
    required bool all,
    double tormenta = 1,
  }) {
    final cm = _critMult(_attacker);
    final formula = _l(tormenta != 1 ? 'formula_storm' : 'formula',
        {'s': source, 'p': fm(power), 't': fm(tormenta)});
    if (!all) {
      final r = hits.first;
      return _l('dmg_one', {
        'h': head,
        'd': r.damage,
        'f': formula,
        'crit': r.critical ? 'yes' : 'no',
        'c': fm(cm),
        'm': LogLine.join(r.mods, ' '),
        'mods': r.mods.isEmpty ? 'no' : 'yes',
      });
    }
    final base = jsRound(sourceValue * power * tormenta);
    final crits = hits.where((h) => h.critical).length;
    final modded = [
      for (final h in hits)
        if (h.mods.isNotEmpty)
          _l('dmg_modded', {
            'a': h.target.name,
            'm': LogLine.join(h.mods, ' '),
            'd': h.damage,
          }),
    ];
    return LogLine.join([
      _l(crits > 0 ? 'dmg_all_crit' : 'dmg_all', {
        'h': head,
        'd': base,
        'f': formula,
        'n': crits,
        'c': jsRound(base * cm),
      }),
      if (modded.isNotEmpty) LogLine.join(modded, ', '),
    ]);
  }

  LogLine _statusText(StatusApplication? st, {int bonus = 0}) => st == null
      ? LogLine.empty
      : _l('status_plus', {'n': st.stacks + bonus, 's': _st(st.kind)});

  /// Texto del estado principal de una acción del grupo según lo que
  /// PASÓ: intentado en [tried] objetivos vivos, entró en [landed]. Nunca
  /// dice que un estado entró si no entró (falló la probabilidad o el
  /// objetivo es inmune: "un enemigo aturdido igual me atacó", v0.5.1).
  LogLine _statusOutcome(
      StatusApplication st, int bonus, int tried, int landed) {
    final n = st.stacks + bonus;
    final chance = st.chance;
    final pct = chance == null ? '' : ' (${jsRound(chance * 100)}%)';
    if (tried == 0) {
      // Los objetivos cayeron con el golpe: nada que informar.
      return chance == null ? _statusText(st, bonus: bonus) : LogLine.empty;
    }
    if (landed == 0) {
      // Inmune (el aviso de INMUNE ya va en el log) o falló la tirada.
      return chance == null
          ? LogLine.empty
          : _l('status_miss', {'s': _st(st.kind), 'p': pct});
    }
    if (tried == 1 || (landed == tried && chance == null)) {
      return _l('status_pct', {'n': n, 's': _st(st.kind), 'p': pct});
    }
    return _l('status_some',
        {'n': n, 's': _st(st.kind), 'a': landed, 'b': tried, 'p': pct});
  }

  // ---------------- disparadores del árbol ----------------

  Iterable<PassiveMechanic> _mechanicsOf(Combatant c) sync* {
    for (final id in c.mechanics) {
      final m = mechanicById(id);
      if (m != null) yield m;
    }
  }

  /// Gasta 1 del tope de efectos del paso. `false` si se acabó.
  bool _spend() {
    if (_procBudget <= 0) return false;
    _procBudget--;
    return true;
  }

  bool _passes(PassiveMechanic m, Combatant owner, Combatant? target,
      StatusKind? status) {
    if (!_filterOk(m, owner)) return false;
    if (m.reaction != null &&
        (m.trigger == ProcTrigger.onReaction ||
            m.trigger == ProcTrigger.onPrimedReaction ||
            m.trigger == ProcTrigger.onPartyReaction) &&
        _rx?.kind != m.reaction) {
      return false;
    }
    final st = m.status;
    if (st == null) return true;
    return switch (m.trigger) {
      ProcTrigger.onStatusApplied => status == st,
      ProcTrigger.onHit => target != null && target.stacks(st) >= m.minStacks,
      ProcTrigger.onEnemyDeath => target != null && target.stacks(st) > 0,
      _ => true,
    };
  }

  /// El filtro de [m] sobre la acción en curso de [owner].
  bool _filterOk(PassiveMechanic m, Combatant owner) {
    final act = _act;
    final sk = act?.skill;
    final ult = act?.ultimate ?? false;
    return switch (m.filter) {
      ProcFilter.any => true,
      ProcFilter.singleTarget => act != null && act.single,
      ProcFilter.magicalSingle =>
        act != null && act.single && sk?.kind == SkillKind.magical,
      ProcFilter.magicalSkill =>
        sk != null && sk.kind == SkillKind.magical && !ult,
      ProcFilter.areaSkill =>
        sk != null && sk.dealsDamage && sk.allTargets && !ult,
      ProcFilter.defending => owner.defending,
      ProcFilter.guardSkill => sk != null &&
          (sk.kind == SkillKind.taunt ||
              sk.kind == SkillKind.protect ||
              sk.kind == SkillKind.guard),
      ProcFilter.belowThreshold => owner.hp < owner.maxHp * m.threshold,
      ProcFilter.rallySkill => sk != null && sk.rally,
    };
  }

  /// Evalúa las mecánicas de [owner] con disparador [trigger]. [amount]:
  /// daño del golpe, daño recibido o vida curada, según el disparador.
  void _fire(ProcTrigger trigger, Combatant owner,
      {Combatant? target,
      StatusKind? status,
      int amount = 0,
      Set<String>? once}) {
    if (owner.mechanics.isEmpty) return;
    // Cadena demasiado profunda (combat.md § "Límites"): el efecto que
    // dispararía otro más no dispara nada.
    if (_fireDepth >= BattleEngine.maxProcDepth) return;
    _fireDepth++;
    try {
      _fireAll(trigger, owner,
          target: target, status: status, amount: amount, once: once);
    } finally {
      _fireDepth--;
    }
  }

  void _fireAll(ProcTrigger trigger, Combatant owner,
      {Combatant? target,
      StatusKind? status,
      int amount = 0,
      Set<String>? once}) {
    for (final m in _mechanicsOf(owner).toList()) {
      if (m.trigger != trigger || m.effects.isEmpty) continue;
      if (!_passes(m, owner, target, status)) continue;
      if (once != null && once.contains(m.id)) continue;
      final act = _act;
      if (act != null) {
        final perTarget = target != null && m.effects.any((e) => e.onTarget);
        // Reacciones (árbol v5): cada dueño dispara la suya.
        final who = trigger == ProcTrigger.onPrimedReaction ||
                trigger == ProcTrigger.onPartyReaction
            ? '@${owner.id}'
            : '';
        if (!act.fired
            .add('${perTarget ? '${m.id}|${target.id}' : m.id}$who')) {
          continue;
        }
      }
      if (m.chance < 1 && _rand() >= m.chance) continue;
      if (!_spend()) return;
      once?.add(m.id);
      for (final fx in m.effects) {
        _applyEffect(m, fx, owner, target, amount, status);
      }
    }
  }

  String _pct(double v) => '${jsRound(v.abs() * 100)}%';

  /// Pone (o renueva) un efecto con duración de [m] sobre [c]. Los
  /// escudos del mismo origen no acumulan: queda el mayor.
  void _giveEffect(Combatant c, Combatant owner, PassiveMechanic m,
      BuffStat stat, double value, int turns) {
    final old = c.effectFrom(m.id, stat);
    final v = stat == BuffStat.shield && old != null
        ? math.max(old.value, value)
        : value;
    c.effects = [
      for (final e in c.effects)
        if (!(e.sourceId == m.id && e.stat == stat)) e,
      TimedEffect(
        sourceId: m.id,
        stat: stat,
        value: v,
        turns: turns,
        ownerId: owner.id,
        fresh: state.currentId == c.id,
      ),
    ];
  }

  void _shield(
      Combatant c, Combatant owner, PassiveMechanic m, int amount, int turns) {
    if (amount <= 0 || !c.alive) return;
    events.add(ProcEvent(owner.id, m.id, targetId: c.id));
    _giveEffect(c, owner, m, BuffStat.shield, amount.toDouble(), turns);
    events.add(ShieldEvent(c.id, amount));
    _notes.add(_l('mech_shield',
        {'m': _mech(m), 'n': amount, 'a': c.name, 't': _turnsL(turns)}));
  }

  void _applyEffect(PassiveMechanic m, ProcEffect fx, Combatant owner,
      Combatant? target, int amount,
      [StatusKind? status]) {
    final act = _act;
    switch (fx.kind) {
      // ---- ascensión (docs/specs/ascension.md § 3.1) ----
      case ProcEffectKind.buffParty:
        events.add(ProcEvent(owner.id, m.id));
        _partyBuff(owner, m.id, _mech(m), fx.stat!, fx.value, fx.turns,
            nameText: m.name);
      case ProcEffectKind.shieldParty:
        _partyShield(owner, m, fx.value, fx.turns);
      case ProcEffectKind.shieldLowestAlly:
        final q = _lowest(_aliveParty, (c) => c.hp / c.maxHp);
        if (q == null) return;
        _partyShield(owner, m, fx.value, fx.turns, only: [q]);
      case ProcEffectKind.healParty:
        events.add(ProcEvent(owner.id, m.id));
        for (final q in _aliveParty) {
          _heal(q, math.max(1, jsRound(q.maxHp * fx.value)));
        }
        _notes.add(_l('party_heals', {'m': _mech(m), 'p': _pct(fx.value)}));
      case ProcEffectKind.advanceAlly:
        Combatant? slow;
        for (final q in _aliveParty) {
          if (q != owner && (slow == null || q.nextTurn > slow.nextTurn)) {
            slow = q;
          }
        }
        events.add(ProcEvent(owner.id, m.id, targetId: slow?.id));
        _advance(owner, [if (slow != null) slow], fx.value, _mech(m));
      case ProcEffectKind.advanceParty:
        events.add(ProcEvent(owner.id, m.id));
        _advance(
            owner,
            [
              for (final q in _aliveParty)
                if (q != owner) q
            ],
            fx.value,
            _mech(m),
            soloCap: 0.5);
      case ProcEffectKind.ultChargeParty:
        final allies = [
          for (final q in _aliveParty)
            if (q != owner) q
        ];
        if (allies.isEmpty) return;
        events.add(ProcEvent(owner.id, m.id));
        for (final q in allies) {
          _bonusUlt(q, fx.value);
        }
        _notes.add(_l('allies_ult', {'m': _mech(m), 'n': jsRound(fx.value)}));
      case ProcEffectKind.drainUlt:
        if (target == null ||
            !target.alive ||
            target.ultId == null ||
            target.ultPending ||
            target.ult <= 0) {
          return;
        }
        events.add(ProcEvent(owner.id, m.id, targetId: target.id));
        target.ult = math.max(0, target.ult - fx.value);
        _notes.add(_l('ult_drain',
            {'s': _mech(m), 'a': target.name, 'n': jsRound(fx.value)}));
      case ProcEffectKind.execute:
        if (target == null) return;
        _execute(owner, target, fx.value, m.id, _mech(m));
      case ProcEffectKind.plantTrap:
        if (target == null || !target.alive) return;
        events.add(ProcEvent(owner.id, m.id, targetId: target.id));
        _plantTrap(owner, target, m.id, fx.value, fx.turns);
      case ProcEffectKind.burst:
        if (target == null) return;
        final others =
            state.enemies.where((e) => e != target && e.alive).toList();
        if (others.isEmpty) return;
        final d = math.max(1, jsRound(amount * fx.value));
        events.add(ProcEvent(owner.id, m.id, targetId: target.id));
        final parts = [
          for (final e in others)
            _l('dmg_to', {'d': _procDamage(owner, e, d, m.id), 'a': e.name}),
        ];
        _notes.add(
            _l('mech_parts', {'m': _mech(m), 'p': LogLine.join(parts, ', ')}));
      case ProcEffectKind.spreadAll:
        if (target == null) return;
        final stacks = {
          for (final k in kElementalStatuses)
            if (target.stacks(k) > 0) k: (target.stacks(k) * fx.value).ceil(),
        };
        final others = state.enemies.where((e) => e != target && e.alive);
        if (stacks.isEmpty || others.isEmpty) return;
        events.add(ProcEvent(owner.id, m.id, targetId: target.id));
        for (final e in others.toList()) {
          stacks.forEach(
              (k, n) => _addStatus(e, StatusApplication(k, n), source: owner));
        }
        _notes.add(_l('spread_all', {'m': _mech(m), 'a': target.name}));
      case ProcEffectKind.addElement:
        if (target == null ||
            !target.alive ||
            status == null ||
            !kElementalStatuses.contains(status)) {
          return;
        }
        final k = kElementalStatuses
            .where((s) => s != status && target.stacks(s) == 0)
            .firstOrNull;
        if (k == null) return;
        events.add(ProcEvent(owner.id, m.id, targetId: target.id));
        if (_addStatus(target, StatusApplication(k, fx.value.round()),
            source: owner)) {
          _notes.add(_l('target_plus_status', {
            'm': _mech(m),
            'a': target.name,
            'n': fx.value.round(),
            's': _st(k),
          }));
        }
      case ProcEffectKind.cheatDeath:
        break; // modificador: lo aplica `_cheatDeath`

      // ---- reacciones v0.7 (passive_tree_v4.md § 8) ----
      case ProcEffectKind.extraJump:
        final rx = _rx;
        if (rx == null || target == null) return;
        final def = engine.catalog.reaction(rx.kind);
        final d = math.max(1, jsRound(amount * def.splash));
        final next = [
          for (final c in _sideOf(target))
            if (!rx.hitIds.contains(c.id)) c,
        ].take(math.max(1, fx.value.round())).toList();
        if (next.isEmpty || def.splash <= 0) return;
        events.add(ProcEvent(owner.id, m.id, targetId: next.first.id));
        final parts = <LogLine>[];
        for (final c in next) {
          rx.hitIds.add(c.id);
          final dealt = _rawDamage(owner, c, d, reactionSourceId(rx.kind));
          if (rx.hitStatus != null && c.alive) {
            _addStatus(c, rx.hitStatus!, source: owner);
          }
          parts.add(_l('dmg_to', {'d': dealt, 'a': c.name}));
        }
        _notes.add(
            _l('jumps_again', {'m': _mech(m), 'p': LogLine.join(parts, ', ')}));
      case ProcEffectKind.refundMp:
        final sk = act?.skill;
        if (act == null || sk == null || act.ultimate || sk.mp <= 0) return;
        events.add(ProcEvent(owner.id, m.id));
        owner.mp = math.min(owner.maxMp.toDouble(), owner.mp + sk.mp);
        events.add(HealEvent(owner.id, sk.mp, mana: true));
        _notes.add(_l('mech_mp', {'m': _mech(m), 'n': sk.mp}));
      case ProcEffectKind.reactionStatus:
        final rx = _rx;
        final st = fx.status;
        if (rx == null || st == null || target == null || !target.alive) {
          return;
        }
        final n = (rx.consumed * fx.value).ceil();
        if (n <= 0) return;
        events.add(ProcEvent(owner.id, m.id, targetId: target.id));
        if (_addStatus(target, StatusApplication(st, n), source: owner)) {
          _notes.add(_l('target_plus_status',
              {'m': _mech(m), 'a': target.name, 'n': n, 's': _st(st)}));
        }
      case ProcEffectKind.brittleAll:
        final hit = [
          for (final e in state.enemies)
            if (e != target &&
                e.alive &&
                !e.brittle &&
                e.stacks(StatusKind.freeze) > 0 &&
                e.stacks(StatusKind.freeze) < StatusKind.freeze.maxStacks)
              e,
        ];
        if (hit.isEmpty) return;
        events.add(ProcEvent(owner.id, m.id, targetId: target?.id));
        for (final e in hit) {
          e.brittle = true;
          events.add(IceEvent(e.id, IcePhase.brittle));
        }
        _notes.add(_l('brittle_all',
            {'m': _mech(m), 'a': hit.map((e) => e.name).join(', ')}));
      case ProcEffectKind.lockStun:
        if (target == null ||
            !target.alive ||
            target.boss ||
            target.stacks(StatusKind.stun) <= 0 ||
            target.hasEffect(BuffStat.stunLock)) {
          return;
        }
        final turns = math.max(1, fx.turns);
        target.effects = [
          ...target.effects,
          TimedEffect(
              sourceId: m.id,
              stat: BuffStat.stunLock,
              value: 1,
              turns: turns,
              ownerId: owner.id),
        ];
        events.add(ProcEvent(owner.id, m.id, targetId: target.id));
        events.add(
            BuffAppliedEvent(target.id, m.id, BuffStat.stunLock, 1, turns));
        _notes.add(_l('stun_more', {'m': _mech(m), 'a': target.name}));
      case ProcEffectKind.buffDuo:
        final rx = _rx;
        events.add(ProcEvent(owner.id, m.id));
        final who = [
          owner,
          if (rx != null && rx.by != owner && rx.by.alive) rx.by,
        ];
        for (final c in who) {
          _giveEffect(c, owner, m, fx.stat!, fx.value, fx.turns);
          events
              .add(BuffAppliedEvent(c.id, m.id, fx.stat!, fx.value, fx.turns));
        }
        _notes.add(_l('buff_duo', {
          'm': _mech(m),
          'a': who.first.name,
          'b': who.length > 1 ? who[1].name : '',
          'two': who.length > 1 ? 'yes' : 'no',
          'p': _pct(fx.value),
          's': _stat(fx.stat!),
          't': _turnsL(fx.turns),
        }));
      case ProcEffectKind.reactionBonus:
      case ProcEffectKind.healHarmBonus:
      case ProcEffectKind.summon:
        break; // modificadores: los aplican `_damageEnemy` y `_healHarm`

      case ProcEffectKind.buffSelf:
        events.add(ProcEvent(owner.id, m.id));
        _giveEffect(owner, owner, m, fx.stat!, fx.value, fx.turns);
        events.add(
            BuffAppliedEvent(owner.id, m.id, fx.stat!, fx.value, fx.turns));
        _notes.add(_l('self_buff', {
          's': _mech(m),
          'p': _pct(fx.value),
          'x': _stat(fx.stat!),
          't': _turnsL(fx.turns),
        }));
      case ProcEffectKind.debuffTarget:
      case ProcEffectKind.markTarget:
        if (target == null || !target.alive) return;
        if (fx.kind == ProcEffectKind.markTarget &&
            target.hasEffect(fx.stat!)) {
          return;
        }
        events.add(ProcEvent(owner.id, m.id, targetId: target.id));
        _giveEffect(target, owner, m, fx.stat!, fx.value, fx.turns);
        events.add(
            BuffAppliedEvent(target.id, m.id, fx.stat!, fx.value, fx.turns));
        _notes.add(fx.kind == ProcEffectKind.markTarget
            ? _l('mark_target', {
                'm': _mech(m),
                'a': target.name,
                'p': _pct(fx.value),
                't': _turnsL(fx.turns),
              })
            : _l('debuff_target', {
                'm': _mech(m),
                'a': target.name,
                'v': '${fx.value < 0 ? '−' : '+'}${_pct(fx.value)}',
                's': _stat(fx.stat!),
                't': _turnsL(fx.turns),
              }));
      case ProcEffectKind.advanceTurn:
        if (act == null) return;
        events.add(ProcEvent(owner.id, m.id));
        act.turnFactor = math.min(act.turnFactor, 1 - fx.value);
        _hasted.add(owner.id);
        _notes
            .add(_l('next_turn_sooner', {'m': _mech(m), 'p': _pct(fx.value)}));
      case ProcEffectKind.extraTurn:
        if (act == null || owner.extraTurn == 2 || act.extraTurn) return;
        events.add(ProcEvent(owner.id, m.id));
        act.extraTurn = true;
        _notes.add(_l('extra_turn', {'m': _mech(m)}));
      case ProcEffectKind.healSelf:
        if (!owner.alive) return;
        final h = math.max(1, jsRound(owner.maxHp * fx.value));
        events.add(ProcEvent(owner.id, m.id, targetId: owner.id));
        _heal(owner, h);
        _notes.add(_l('mech_hp', {'m': _mech(m), 'h': h}));
      case ProcEffectKind.healLowestAlly:
        final q = _lowest(_aliveParty, (c) => c.hp / c.maxHp);
        if (q == null || q.hp >= q.maxHp) return;
        final h = math.max(1, jsRound(q.maxHp * fx.value));
        events.add(ProcEvent(owner.id, m.id, targetId: q.id));
        _heal(q, h);
        _notes.add(_l('mech_ally_hp', {'m': _mech(m), 'a': q.name, 'h': h}));
      case ProcEffectKind.chain:
        if (act == null || fx.value <= act.chain) return;
        act
          ..chain = fx.value
          ..chainSource = m;
      case ProcEffectKind.explode:
        if (act == null || act.explosion != null || target == null) return;
        act.explosion = (target, math.max(1, jsRound(amount * fx.value)), m);
      case ProcEffectKind.reflect:
        if (target == null || !target.alive) return;
        final d = math.max(1, jsRound(amount * fx.value));
        events.add(ProcEvent(owner.id, m.id, targetId: target.id));
        final dealt = _procDamage(owner, target, d, m.id);
        _notes.add(
            _l('src_dmg_to', {'m': _mech(m), 'd': dealt, 'a': target.name}));
      case ProcEffectKind.shatterStun:
        if (target == null ||
            !target.alive ||
            (target.stacks(StatusKind.freeze) <= 0 &&
                !_meltedNow.contains(target.id))) {
          return;
        }
        events.add(ProcEvent(owner.id, m.id, targetId: target.id));
        target.statuses[StatusKind.freeze] = 0;
        target.brittle = false;
        // El log solo dice "aturdido" si el estado entró.
        final stunned = _addStatus(
            target, const StatusApplication(StatusKind.stun, 1),
            source: owner);
        _notes.add(_l(stunned ? 'loses_freeze_stun' : 'loses_freeze',
            {'m': _mech(m), 'a': target.name}));
      case ProcEffectKind.delayTarget:
        if (target == null || !target.alive) return;
        events.add(ProcEvent(owner.id, m.id, targetId: target.id));
        target.nextTurn += _iv(target) *
            fx.value *
            (_fam(target)?.delayMult ?? 1) *
            _delayFalloff(target);
        events.add(DelayedEvent(target.id));
        _notes.add(_l(
            'delayed', {'m': _mech(m), 'a': target.name, 'p': _pct(fx.value)}));
      case ProcEffectKind.repeatSkill:
        if (act == null || act.repeat != null) return;
        act.repeat = (fx.value, m);
      case ProcEffectKind.spreadStatus:
        final st = m.status;
        if (target == null || st == null) return;
        final n = target.stacks(st);
        Combatant? dest;
        for (final e in state.enemies) {
          if (e != target && e.alive && (dest == null || e.hp > dest.hp)) {
            dest = e;
          }
        }
        if (n <= 0 || dest == null) return;
        events.add(ProcEvent(owner.id, m.id, targetId: dest.id));
        if (_addStatus(dest, StatusApplication(st, n), source: owner)) {
          _notes.add(_l('spread_status',
              {'m': _mech(m), 'n': n, 's': _st(st), 'a': dest.name}));
        }
      case ProcEffectKind.freeAttack:
        if (act == null || act.freeAttack != null) return;
        act.freeAttack = m;
      case ProcEffectKind.shieldHealed:
        if (target == null) return;
        _shield(target, owner, m, jsRound(amount * fx.value), fx.turns);
      case ProcEffectKind.shieldSelf:
        _shield(owner, owner, m, jsRound(owner.maxHp * fx.value), fx.turns);
      case ProcEffectKind.ultCharge:
        events.add(ProcEvent(owner.id, m.id));
        _bonusUlt(owner, fx.value);
        _notes.add(_l('mech_ult', {'m': _mech(m), 'n': jsRound(fx.value)}));
      case ProcEffectKind.holyDamage:
        if (target == null || !target.alive) return;
        events.add(ProcEvent(owner.id, m.id, targetId: target.id));
        final dealt = _procDamage(
            owner, target, math.max(1, jsRound(owner.magic * fx.value)), m.id);
        _notes.add(_l('holy_dmg', {
          'm': _mech(m),
          'd': dealt,
          'a': target.name,
          'g': owner.magic,
          'x': fm(fx.value),
        }));
      case ProcEffectKind.extraStacks:
        final st = fx.status ?? m.status;
        if (target == null || !target.alive || st == null) return;
        final n = fx.value.round();
        if (n <= 0) return;
        events.add(ProcEvent(owner.id, m.id, targetId: target.id));
        if (_addStatus(target, StatusApplication(st, n), source: owner)) {
          _notes.add(_l('plus_status_to',
              {'m': _mech(m), 'n': n, 's': _st(st), 'a': target.name}));
        }
      case ProcEffectKind.inflict:
        final st = fx.status;
        if (target == null || !target.alive || st == null) return;
        final n = math.max(1, fx.value.round());
        events.add(ProcEvent(owner.id, m.id, targetId: target.id));
        // El golpe lleva este estado: primero la reacción (§ 9).
        _procHitReact(owner, target, m, StatusApplication(st, n));
        if (!target.alive) return;
        if (_addStatus(target, StatusApplication(st, n), source: owner)) {
          _notes.add(_l('target_plus_status',
              {'m': _mech(m), 'a': target.name, 'n': n, 's': _st(st)}));
        }
      case ProcEffectKind.stunExtend:
      case ProcEffectKind.statBonus:
      case ProcEffectKind.breakBonus:
        // Modificadores: los aplican `_addStatus`, `_conditionBonus` y
        // `_breakBonus`.
        break;
    }
  }

  /// Resolución diferida de la acción (passive_tree_v2.md § 5, pasos 3-4):
  /// rebote, explosión, eco, ataque gratis y `onKill`.
  void _resolveAction(Combatant p, _Action act) {
    // Rebote / cadena.
    final hit = act.mainHit;
    final src = act.chainSource;
    if (act.chain > 0 && hit != null && src != null && _spend()) {
      final infinite = p.keystones.contains('cadena');
      final hitIds = {hit.target.id};
      final start = state.enemies.indexOf(hit.target);
      var prev = hit.damage.toDouble();
      var frac = act.chain;
      final parts = <LogLine>[];
      for (var k = 1; k < state.enemies.length; k++) {
        final e = state.enemies[(start + k) % state.enemies.length];
        if (!e.alive || hitIds.contains(e.id)) continue;
        final d = math.max(1, jsRound(prev * frac));
        events.add(ProcEvent(p.id, src.id, targetId: e.id));
        parts.add(
            _l('dmg_to', {'d': _procDamage(p, e, d, src.id), 'a': e.name}));
        hitIds.add(e.id);
        prev = d.toDouble();
        frac = 0.6;
        if (!infinite) break;
      }
      if (parts.isNotEmpty) {
        _notes.add(_l(infinite ? 'chain_infinite' : 'mech_parts',
            {'m': _mech(src), 'p': LogLine.join(parts, ', ')}));
      }
    }

    // Explosión (Combustión).
    final ex = act.explosion;
    if (ex != null) {
      final (center, d, m) = ex;
      final others =
          state.enemies.where((e) => e != center && e.alive).toList();
      if (others.isNotEmpty) {
        events.add(ProcEvent(p.id, m.id, targetId: center.id));
        final parts = [
          for (final e in others)
            _l('dmg_to', {'d': _procDamage(p, e, d, m.id), 'a': e.name}),
        ];
        _notes.add(_l('explodes', {
          'm': _mech(m),
          'a': center.name,
          'p': LogLine.join(parts, ', '),
        }));
      }
    }

    // Eco Arcano.
    final rep = act.repeat;
    final sk = act.skill;
    if (rep != null && sk != null) {
      final (frac, m) = rep;
      final alive = state.enemies.where((e) => e.alive).toList();
      final main = act.mainTarget;
      final targets = sk.allTargets
          ? alive
          : [
              if (main != null && main.alive)
                main
              else if (alive.isNotEmpty)
                alive.first,
            ];
      if (targets.isNotEmpty) {
        events.add(ProcEvent(p.id, m.id));
        final d = math.max(1, jsRound(act.skillBase * frac));
        final parts = <LogLine>[];
        for (final e in targets) {
          parts.add(_l('dmg_to',
              {'d': _skillProcDamage(p, e, d, m.id, sk), 'a': e.name}));
          final st = sk.status;
          if (st != null && e.alive) {
            _addStatus(e, st, bonus: act.skillStatusBonus, source: p);
          }
        }
        _notes.add(_l('repeats', {
          'm': _mech(m),
          's': _sk(sk),
          'p': _pct(frac),
          'x': LogLine.join(parts, ', '),
        }));
      }
    }

    // Viento a Favor.
    final free = act.freeAttack;
    if (free != null) {
      final target =
          _lowest(state.enemies.where((e) => e.alive), (c) => c.hp.toDouble());
      if (target != null) {
        events.add(ProcEvent(p.id, free.id, targetId: target.id));
        events.add(
            ActionEvent(p.id, BattleActionKind.attack, targetId: target.id));
        final h = _damageEnemy(target, _atk(p).toDouble(), p.critChance,
            primary: false, element: GameElement.fisico, physical: true);
        _notes.add(_l(h.critical ? 'free_attack_crit' : 'free_attack',
            {'m': _mech(free), 'a': target.name, 'd': h.damage}));
      }
    }

    if (act.killed) _fire(ProcTrigger.onKill, p);
  }

  // ---------------- quiebre (docs/specs/break_and_enemy_ults.md § 1) ----

  static double _r1(double v) => (v * 10).round() / 10;

  /// Suma [amount] puntos a la barra de quiebre de [e]; al llegar al
  /// umbral queda **Fisurado** (combo_balance.md § 5): recién un golpe con
  /// Quebrar lo quiebra. Quebrado o Fisurado, la barra no se llena.
  void _addBreak(Combatant e, double amount) {
    if (e.isPlayer ||
        !e.alive ||
        !e.hasBreak ||
        e.broken ||
        e.fissured ||
        amount <= 0) {
      return;
    }
    // Familia (bestiary.md § 1): los constructos se quiebran antes.
    amount *= _fam(e)?.breakMult ?? 1;
    // Hielo (elemental_reactions.md § 7): +10% de quiebre por stack.
    final ice = e.stacks(StatusKind.freeze);
    if (ice > 0) amount *= 1 + _frz.breakPerStack * ice;
    final max = e.breakMax;
    e.breakGauge = math.min(max, _r1(e.breakGauge + amount));
    if (e.breakGauge >= max) {
      e.fissured = true;
      _fissuredNow.add(e.id);
      events.add(BreakEvent(e.id, BreakPhase.fissured, max, max));
      _notes.add(_l('fissured', {'a': e.name}));
    } else {
      events.add(BreakEvent(e.id, BreakPhase.fill, e.breakGauge, max));
    }
  }

  /// Fisurado que llega a su turno sin quebrarse: la barra vuelve a la
  /// mitad (combo_balance.md § 5).
  void _steady(Combatant e) {
    if (!e.fissured) return;
    final max = e.breakMax;
    e
      ..fissured = false
      ..breakGauge = _r1(max * engine.catalog.combo.steadyGauge);
    events.add(BreakEvent(e.id, BreakPhase.steadied, e.breakGauge, max));
    _notes.add(_l('steadied', {'a': e.name}));
  }

  /// Quiebre: pierde su próximo turno, su ULT vuelve a 0 (y se cancela
  /// si la había avisado) y recibe +50% de daño 2 turnos del grupo.
  void _break(Combatant e) {
    final max = e.breakMax;
    final cancelled = e.ultPending;
    e
      ..fissured = false
      ..breakGauge = max
      ..vulnerable = BattleEngine.vulnerableTurns
      ..breakSkip = true
      ..ultPending = false;
    if (e.ultId != null) e.ult = 0;
    _brokenNow.add(e.id);
    events.add(
        BreakEvent(e.id, BreakPhase.broken, max, max, cancelledUlt: cancelled));
    final ult = engine.catalog.enemyUlts[e.ultId];
    _notes.add(LogLine.join([
      _l('break', {'a': e.name}),
      if (cancelled && ult != null) _l('ult_cancelled', {'u': _eult(ult)}),
    ]));
    // Estratega (Señor de la Guerra): cualquier quiebre del grupo.
    for (final q in state.party) {
      if (q.alive) _fire(ProcTrigger.onBreak, q, target: e);
    }
    // Jefe del Abismo: el quiebre rompe su sello.
    _abyssBroken(e);
    // Sierpe: el quiebre rompe uno de sus cristales (Hechicera: disipa un
    // eco).
    final m = _mechanicOf(e);
    if (m != null &&
        m.addType != null &&
        (m.kind == BossMechanicKind.frost || m.kind == BossMechanicKind.echo)) {
      final crystal =
          state.enemies.where((c) => c.alive && c.enemyType == m.addType);
      if (crystal.isNotEmpty) {
        final c = crystal.first;
        c.hp = 0;
        events.add(
            BossMechanicEvent(e.id, BossMechanicPhase.shatter, targetId: c.id));
        _notes.add(_l(
            m.kind == BossMechanicKind.echo
                ? 'break_dispels'
                : 'break_shatters',
            {'a': c.name}));
        _knockedOut(c);
      }
    }
  }

  /// Al empezar su turno, la barra baja 10% del umbral (si no está
  /// quebrado).
  void _decayBreak(Combatant e) {
    if (e.fissured) {
      _steady(e);
      return;
    }
    if (!e.alive || !e.hasBreak || e.broken || e.breakGauge <= 0) return;
    final max = e.breakMax;
    e.breakGauge =
        math.max(0, _r1(e.breakGauge - max * BattleEngine.breakDecay));
    events.add(BreakEvent(e.id, BreakPhase.decay, e.breakGauge, max));
  }

  /// Terminó un turno del grupo: descuenta la vulnerabilidad de los
  /// quebrados antes de este paso; al llegar a 0 se recuperan (barra a 0
  /// y umbral +25%).
  void _tickVulnerable() {
    for (final e in state.enemies) {
      if (e.vulnerable <= 0 || _brokenNow.contains(e.id)) continue;
      e.vulnerable--;
      if (e.vulnerable > 0) continue;
      e
        ..breakGauge = 0
        ..breaks += 1;
      if (!e.alive) continue;
      events.add(BreakEvent(e.id, BreakPhase.recovered, 0, e.breakMax));
      _notes.add(_l('break_recovers', {'a': e.name}));
    }
  }

  /// Carga de ULT enemiga por vida perdida: +1 cada 2%.
  /// Rendimiento decreciente del retraso (combo_balance.md § 3.3, ajuste
  /// de los pasos 5-6): cada retraso del grupo a un enemigo desde su
  /// último turno rinde `delayFalloff` del anterior (1, 0.5, 0.25…).
  double _delayFalloff(Combatant e) {
    if (e.isPlayer) return 1;
    final f = math.pow(engine.catalog.curve.delayFalloff, e.delayStreak);
    e.delayStreak++;
    return f.toDouble();
  }

  /// [scale] compensa la mitigación de grupo (combo_balance.md § 3.3).
  void _chargeUlt(Combatant e, int lost, {double scale = 1}) {
    // Rebobinar (Jefes del Abismo): lo recibido desde su acción anterior.
    if (lost > 0 && _abyssDef(e) != null) e.abyssTaken += lost;
    if (e.isPlayer || e.ultId == null || e.ultPending || lost <= 0) return;
    e.ult = math.min(
        100, e.ult + lost * scale / e.maxHp * BattleEngine.enemyUltPerHp);
  }

  // ---------------- enemigos ----------------

  /// `enemyAct`. Con ULT (jefes y élites): con la carga llena avisa (pierde
  /// la acción) y en su siguiente turno la lanza.
  void enemyAct(Combatant e) {
    e.delayStreak = 0;
    if (_aliveParty.isEmpty) return;
    final mech = _mechanicOf(e);
    if (mech != null) _mechanicTurn(e, mech);
    // La lava puede tumbar a alguien al empezar el turno.
    final alive = _aliveParty.toList();
    if (alive.isEmpty) return;
    final ult = engine.catalog.enemyUlts[e.ultId];
    if (ult != null) {
      if (e.ultPending) {
        _enemyUlt(e, ult, alive);
        return;
      }
      if (e.ult >= 100) {
        e.ultPending = true;
        events.add(EnemyUltWarningEvent(e.id, ult.id, ult.name));
        final fem = engine.catalog.enemies[e.enemyType]?.feminine ?? false;
        state.logLine = _l('ult_warning',
            {'g': fem ? 'f' : 'm', 'a': e.name, 'u': _eult(ult)});
        return;
      }
      e.ult = math.min(100, e.ult + BattleEngine.enemyUltPerTurn);
    }
    e.actions++;
    if (_tankGuard(e)) return;
    if (_castSilence(e)) return;
    // Jefe del Abismo: su rotación de movimientos (abyss_bosses.md § 2).
    if (mech != null && mech.kind == BossMechanicKind.abyss) {
      _abyssAct(e, mech, alive);
      return;
    }
    if (mech != null &&
        mech.kind == BossMechanicKind.web &&
        e.actions % mech.every == 0 &&
        _castWeb(e, mech, alive)) {
      return;
    }
    if (mech != null && mech.kind == BossMechanicKind.mark) {
      // Marca del Vacío: el golpe al marcado, o marcar a alguien.
      final marked = alive.where((p) => p.voidMarked).firstOrNull;
      if (marked != null) {
        _markStrike(e, mech, marked, alive);
        return;
      }
      if (e.actions % mech.every == 0) {
        _castMark(e, mech, alive);
        return;
      }
    }
    _basicAttack(e, mech, alive);
    if (mech != null &&
        mech.kind == BossMechanicKind.lava &&
        e.lava <= 0 &&
        e.actions % mech.every == 0) {
      _lavaRise(e, mech.turns);
    }
  }

  /// Estado que aplica el golpe de [e] (en ciclo si su tipo lo tiene).
  StatusApplication? _inflictsOf(Combatant e) {
    // Aspecto de un Jefe del Abismo: sus golpes dejan el estado de ese
    // elemento.
    final asp = _abyssAspectStatus(e);
    if (asp != null) return asp;
    final cyc = engine.catalog.enemies[e.enemyType]?.inflictCycle ?? const [];
    if (cyc.isEmpty) return e.inflicts;
    return cyc[math.max(0, e.actions - 1) % cyc.length];
  }

  /// Efectos de los comunes v0.3 sobre el jugador que golpean: retraso
  /// (Guardián del Reloj, Fragmento) y marca (Vigilante). Texto del log.
  List<LogLine> _onHitExtras(Combatant e, Combatant p) {
    final d = engine.catalog.enemies[e.enemyType];
    if (d == null || !p.alive) return const [];
    final log = <LogLine>[];
    if (d.delayHit > 0) {
      p.nextTurn += _iv(p) * d.delayHit;
      events.add(DelayedEvent(p.id));
      log.add(_l('hit_delays', {'p': _pct(d.delayHit)}));
    }
    if (d.markHit > 0) {
      const src = 'vigilancia';
      p.effects = [
        for (final fx in p.effects)
          if (!(fx.sourceId == src && fx.stat == BuffStat.damageTaken)) fx,
        TimedEffect(
            sourceId: src,
            stat: BuffStat.damageTaken,
            value: d.markHit,
            turns: 2,
            ownerId: e.id),
      ];
      events
          .add(BuffAppliedEvent(p.id, src, BuffStat.damageTaken, d.markHit, 2));
      log.add(_l('hit_marks', {'p': _pct(d.markHit)}));
    }
    return log;
  }

  /// Ataque normal, Golpe Brutal o Colapso Temporal de [e].
  void _basicAttack(Combatant e, BossMechanicDef? mech, List<Combatant> alive) {
    // Invocaciones del grupo: el Gólem provoca (summoner.md § 3).
    if (_summonIntercept(e)) return;
    final taunter = alive.where((p) => p.taunt > 0).firstOrNull;
    final inf = _inflictsOf(e);
    // Elemento del golpe (v0.7): reacciones sobre los jugadores.
    final el = enemyAttackElement(engine.catalog.enemies[e.enemyType], inf);
    // Enemy Convergences: prime / detonate the primed player.
    final pick0 = taunter ??
        _comboPick(e, alive, el, inf) ??
        alive[(_rand() * alive.length).floor()];
    if (taunter != null) taunter.taunt--;
    final protector = alive.where((p) => p.protecting).firstOrNull;
    Combatant victim(Combatant q) =>
        protector != null && q != protector ? protector : q;
    final pick = victim(pick0);
    final protText = protector != null && pick0 != protector
        ? _l('protected', {'a': protector.name, 'b': pick0.name})
        : LogLine.empty;
    // Devorador en fase 2: Colapso Temporal cada `every` acciones.
    final areaEvery =
        mech != null && mech.kind == BossMechanicKind.phases && e.phase >= 2
            ? mech.every
            : 3;
    final area = e.areaAttack && e.actions % areaEvery == 0;
    events.add(ActionEvent(
      e.id,
      area
          ? BattleActionKind.enemyArea
          : e.boss && e.actions % 4 == 0
              ? BattleActionKind.enemyHeavy
              : BattleActionKind.enemyAttack,
      targetId: area ? null : pick.id,
      allTargets: area,
    ));

    // Debilitar: el enemigo pega con menos ATQ.
    final atkMod = e.effectTotal(BuffStat.attack);
    final atk =
        atkMod == 0 ? e.attack : math.max(1, jsRound(e.attack * (1 + atkMod)));
    final atkText = atkMod == 0
        ? _l('src_atk', {'n': e.attack})
        : _l('src_atk_weak', {'n': atk});

    LogLine detail(_Hurt h, double mult, Combatant p) => LogLine.join([
          atkText,
          if (mult != 1) _l('x_mult', {'x': fm(mult)}),
          if (h.critical)
            _l('x_crit', {'x': fm(BattleEngine.enemyCritMultiplier)}),
          if (h.pierce > 1) _l('x_pierce', {'x': fm(h.pierce)}),
          if (p.defending) _l('x_defend'),
          if (p.effectTotal(BuffStat.damageTaken) > 0)
            _l('x_mark', {'x': fm(1 + p.effectTotal(BuffStat.damageTaken))}),
          if (h.defensePercent > 0)
            _l('x_def', {'n': jsRound(h.defensePercent * 100)}),
        ], ' ');
    LogLine infText(Combatant p) => p.alive && inf != null
        ? _statusText(inf,
            bonus: inf.kind == StatusKind.regen ? 0 : p.statusWeakness)
        : LogLine.empty;
    final tauntText = taunter != null ? _l('taunted') : LogLine.empty;
    // Guardián: el protector recibió un golpe dirigido a un aliado.
    void guarded(Combatant p, Combatant p0, int dmg) {
      if (p != p0 && p.alive) {
        _fire(ProcTrigger.onProtectHit, p, target: e, amount: dmg);
      }
    }

    if (area) {
      final parts = <LogLine>[];
      for (final p0 in alive) {
        final p = victim(p0);
        if (!p.alive) {
          parts.add(_l('who_dmg', {'w': p0.name, 'd': 0, 'c': ''}));
          continue;
        }
        final h = _hurt(p, atk * 0.7, e.critChance, e.pierce,
            from: e, element: el, inflicted: inf);
        guarded(p, p0, h.damage);
        p.nextTurn += _iv(p) * 0.4;
        if (inf != null) _addStatus(p, inf);
        events.add(DelayedEvent(p.id));
        final who = p != p0
            ? _l('for_ally', {'a': p.name, 'b': p0.name})
            : LogLine.raw(p.name);
        parts.add(_l(
            'who_dmg', {'w': who, 'd': h.damage, 'c': h.critical ? '!' : ''}));
      }
      state.logLine = _l('time_collapse', {
        'a': e.name,
        's': atkText,
        'p': LogLine.join(parts, ', '),
      });
    } else if (e.boss && e.actions % 4 == 0) {
      final h = _hurt(pick, atk * 1.6, e.critChance, e.pierce,
          from: e, element: el, inflicted: inf);
      guarded(pick, pick0, h.damage);
      final got = inf != null && _addStatus(pick, inf);
      state.logLine = _enemyHitLine(
        _l('brutal_hit', {
          'a': e.name,
          'b': pick.name,
          'd': h.damage,
          'x': detail(h, 1.6, pick),
        }),
        got ? infText(pick) : LogLine.empty,
        tauntText,
        protText,
        _onHitExtras(e, pick),
      );
    } else {
      final h = _hurt(pick, atk.toDouble(), e.critChance, e.pierce,
          from: e, element: el, inflicted: inf);
      guarded(pick, pick0, h.damage);
      final got = inf != null && _addStatus(pick, inf);
      final explain = h.critical ||
          pick.defending ||
          h.pierce > 1 ||
          h.defensePercent > 0 ||
          pick.effectTotal(BuffStat.damageTaken) > 0 ||
          atkMod != 0;
      state.logLine = _enemyHitLine(
        _l(explain ? 'enemy_hit_x' : 'enemy_hit', {
          'a': e.name,
          'b': pick.name,
          'd': h.damage,
          'x': explain ? detail(h, 1, pick) : LogLine.empty,
        }),
        got ? infText(pick) : LogLine.empty,
        tauntText,
        protText,
        _onHitExtras(e, pick),
      );
    }
  }

  /// La ULT de [e] (docs/specs/break_and_enemy_ults.md § 2): Defender,
  /// Protección, Provocar y escudos aplican como en un golpe normal.
  void _enemyUlt(Combatant e, EnemyUltDef ult, List<Combatant> alive) {
    final weaken = e.ultWeaken;
    e
      ..ultPending = false
      ..ultWeaken = 0
      ..ult = 0;
    final taunter = alive.where((p) => p.taunt > 0).firstOrNull;
    final protector = alive.where((p) => p.protecting).firstOrNull;
    Combatant victim(Combatant q) =>
        protector != null && q != protector ? protector : q;
    Combatant? pick0;
    if (!ult.allTargets) {
      pick0 = taunter ?? alive[(_rand() * alive.length).floor()];
      if (taunter != null) taunter.taunt--;
    }
    events.add(EnemyUltEvent(e.id, ult.id, ult.name,
        targetId: pick0?.id,
        allTargets: ult.allTargets,
        wipedBuffs: ult.wipeBuffs));

    final atkMod = e.effectTotal(BuffStat.attack);
    final atk =
        atkMod == 0 ? e.attack : math.max(1, jsRound(e.attack * (1 + atkMod)));
    final atkText = atkMod == 0
        ? _l('src_atk', {'n': e.attack})
        : _l('src_atk_weak', {'n': atk});
    final crit = ult.guaranteedCrit ? 1.0 : e.critChance;
    final mech = _mechanicOf(e);
    // Coro de Ecos: más poder por cada eco vivo.
    var power = ult.power * (1 - weaken);
    if (weaken > 0) _notes.add(_l('drained', {'p': _pct(weaken)}));
    // Anuncio de las Eras: el estado de su ciclo.
    final def = engine.catalog.enemies[e.enemyType];
    final cycle = def?.inflictCycle ?? const <StatusApplication>[];
    final status = ult.cycleStatus && cycle.isNotEmpty
        ? cycle[e.actions % cycle.length]
        : ult.status;
    var dealt = 0;
    if (ult.extra == EnemyUltExtra.echoChorus && mech?.addType != null) {
      power += ult.perAdd *
          state.enemies
              .where((c) => c.alive && c.enemyType == mech!.addType)
              .length;
    }
    final solo = alive.length == 1;
    final parts = <LogLine>[];
    void strike(Combatant p0) {
      final p = victim(p0);
      if (!p.alive) {
        parts.add(_l('who_dmg', {'w': p0.name, 'd': 0, 'c': ''}));
        return;
      }
      // Colapso del Vacío: el marcado sin proteger recibe × value.
      var mult = 1.0;
      if (ult.extra == EnemyUltExtra.voidMark &&
          mech != null &&
          p0.voidMarked &&
          p == p0 &&
          !(solo && p0.defending)) {
        mult = solo ? mech.soloValue : mech.value;
        events.add(BossMechanicEvent(e.id, BossMechanicPhase.markHit,
            targetId: p0.id, value: mult));
      }
      final h = _hurt(p, atk * power * mult, crit, e.pierce,
          from: e, element: enemyUltElement(ult), inflicted: status);
      dealt += h.damage;
      if (p != p0 && p.alive) {
        _fire(ProcTrigger.onProtectHit, p, target: e, amount: h.damage);
      }
      final st = status;
      if (st != null) _addStatus(p, st);
      // ULT de élite v2 (ultimates_v2.md § 4.3): estados extra, debuffs y
      // retraso al golpeado.
      for (final x in ult.extraStatuses) {
        if (p.alive && (x.chance == null || _rand() < x.chance!)) {
          _addStatus(p, StatusApplication(x.kind, x.stacks));
        }
      }
      if (p.alive && ult.debuffs.isNotEmpty) {
        final m = _ultMech(ult);
        for (final d in ult.debuffs) {
          _giveEffect(p, e, m, d.stat, d.value, d.turns);
          events.add(BuffAppliedEvent(p.id, ult.id, d.stat, d.value, d.turns));
        }
      }
      if (p.alive && ult.delayTarget > 0) {
        p.nextTurn += _iv(p) * ult.delayTarget;
        events.add(DelayedEvent(p.id));
      }
      final who = p != p0
          ? _l('for_ally', {'a': p.name, 'b': p0.name})
          : LogLine.raw(p.name);
      final hit =
          _l('who_dmg', {'w': who, 'd': h.damage, 'c': h.critical ? '!' : ''});
      parts.add(mult != 1
          ? LogLine.join([
              hit,
              _l('void_mark_x', {'x': fm(mult)})
            ], ' ')
          : hit);
    }

    for (var i = 0; i < math.max(1, ult.hits); i++) {
      final now = _aliveParty.toList();
      if (now.isEmpty) break;
      if (ult.allTargets) {
        now.forEach(strike);
      } else if (i == 0) {
        strike(pick0!);
      } else {
        // Ráfaga: cada golpe extra a uno al azar (Provocar manda).
        final t = now.where((p) => p.taunt > 0).firstOrNull ??
            now[(_rand() * now.length).floor().clamp(0, now.length - 1)];
        strike(t);
      }
    }
    if (ult.drainHeal > 0 && dealt > 0 && e.alive) {
      final h = math.max(1, jsRound(dealt * ult.drainHeal));
      e.hp = math.min(e.maxHp, e.hp + h);
      events.add(HealEvent(e.id, h));
      parts.add(_l('heals_self', {'n': h}));
    }
    if (ult.selfShield > 0 && e.alive) {
      _shield(e, e, _ultMech(ult), jsRound(e.maxHp * ult.selfShield),
          ult.selfShieldTurns);
    }
    if (ult.delayAll > 0) {
      for (final p in _aliveParty) {
        p.nextTurn += _iv(p) * ult.delayAll;
        events.add(DelayedEvent(p.id));
      }
    }
    if (ult.wipeBuffs) {
      for (final p in state.party) {
        p.effects = [
          for (final fx in p.effects)
            if (fx.value <= 0 ||
                fx.stat == BuffStat.stunLock ||
                fx.stat == BuffStat.damageTaken)
              fx,
        ];
        if (p.bonusDefense > 0) {
          p.bonusDefense = 0;
          engine._refreshStats(p);
        }
      }
    }
    final extra = _ultExtra(e, ult);
    state.logLine = LogLine.join([
      _l('enemy_ult', {
        'a': e.name,
        'u': _eult(ult),
        'f': LogLine.join([
          LogLine.join([
            if (ult.allTargets) _l('all_tag'),
            atkText,
          ], ', '),
          _l('x_mult', {'x': fm(power)}),
          if (ult.guaranteedCrit)
            _l('x_crit', {'x': fm(BattleEngine.enemyCritMultiplier)}),
        ], ' '),
        'p': LogLine.join(parts, ', '),
      }),
      if (status != null) _statusText(status),
      if (ult.delayAll > 0) _l('delays_all'),
      if (ult.wipeBuffs) _l('wipes_buffs'),
      extra,
    ]);
  }

  /// La ULT enemiga [ult] como fuente de efectos (debuffs, escudo).
  PassiveMechanic _ultMech(EnemyUltDef ult) => PassiveMechanic(
      id: ult.id,
      name: ult.name,
      trigger: ProcTrigger.onSkill,
      effects: const [],
      description: '');

  // ---------------- mecánicas de jefe (docs/specs/bosses.md § "v0.2") ----

  /// Invocación que no actúa (cristales).
  bool _passive(Combatant c) =>
      !c.isPlayer && (engine.catalog.enemies[c.enemyType]?.passive ?? false);

  BossMechanicDef? _mechanicOf(Combatant e) =>
      e.isPlayer ? null : bossMechanicOf(engine.catalog.enemies[e.enemyType]);

  /// Quedan invocaciones vivas del tipo [type].
  bool _addsAlive(String type) =>
      state.enemies.any((c) => c.alive && c.enemyType == type);

  /// Fracción del golpe que bloquea la postura de [e] (0 si no aplica):
  /// escudo → físico (ataque, habilidad o ULT física), espada → mágico.
  /// Quebrado no bloquea; el dúo y los secundarios tampoco.
  double _stanceResist(Combatant e) {
    if (e.stance == 0 || e.broken) return 0;
    final act = _act;
    if (act == null || act.dual) return 0;
    final sk = act.skill;
    final physical = sk == null || sk.kind == SkillKind.physical;
    if ((e.stance == 1) != physical) return 0;
    final m = _mechanicOf(e);
    if (m == null) return 0;
    return _aliveParty.length == 1 ? m.soloValue : m.value;
  }

  /// Al empezar el turno del jefe: Campo Helado o cambio de postura.
  void _mechanicTurn(Combatant e, BossMechanicDef m) {
    switch (m.kind) {
      case BossMechanicKind.frost:
        if (m.addType != null && _addsAlive(m.addType!)) _frost(e, m);
      case BossMechanicKind.stance:
        e.stanceTurns--;
        if (e.stanceTurns <= 0) _shiftStance(e, m);
      case BossMechanicKind.echo || BossMechanicKind.summon:
        _refillTurn(e, m);
      case BossMechanicKind.lava:
        _lavaTick(e, m);
      case BossMechanicKind.abyss:
        _abyssTurnStart(e);
      case BossMechanicKind.web ||
            BossMechanicKind.mark ||
            BossMechanicKind.phases:
        break;
    }
  }

  // ---------------- mecánicas de jefe v0.3 (docs/specs/bosses.md § "v0.3")

  /// Fracción del daño que recibe cada tipo de eco (`ecoHechicera` 0.5).
  static final Map<String, double> _echoAdds = {
    for (final m in kBossMechanics.values)
      if ((m.kind == BossMechanicKind.echo ||
              (m.kind == BossMechanicKind.abyss && m.value > 0)) &&
          m.addType != null)
        m.addType!: m.value,
  };

  /// Fracción del daño que recibe [e] (1 salvo los ecos).
  double _echoFactor(Combatant e) =>
      e.isPlayer ? 1 : (_echoAdds[e.enemyType] ?? 1);

  /// Séquito vivo: el jefe es inmune a los estados.
  bool _immune(Combatant e) {
    final m = _mechanicOf(e);
    if (m != null && m.kind == BossMechanicKind.abyss) {
      return _abyssStatusImmune(e);
    }
    return m != null &&
        m.kind == BossMechanicKind.summon &&
        m.addType != null &&
        _addsAlive(m.addType!);
  }

  /// Invocaciones que tiene que tener [m] (con grupo / solo).
  int _addsMax(BossMechanicDef m) =>
      state.party.length == 1 ? m.soloAdds : m.adds;

  /// Al empezar su turno: si le faltan invocaciones, cuenta; al llegar a
  /// `every` turnos, las vuelve a crear.
  void _refillTurn(Combatant e, BossMechanicDef m) {
    final type = m.addType;
    if (type == null) return;
    final n = state.enemies.where((c) => c.alive && c.enemyType == type).length;
    if (n >= _addsMax(m)) {
      e.mechTurns = 0;
      return;
    }
    e.mechTurns++;
    if (e.mechTurns < m.every) return;
    e.mechTurns = 0;
    final k = _summonAdds(e, m);
    if (k > 0) {
      _notes.add(_l(
          m.kind == BossMechanicKind.echo
              ? 'mech_echo_split'
              : 'mech_summon_servants',
          {'m': m.name, 'a': e.name, 'n': k}));
    }
  }

  /// Completa las invocaciones de [boss]: revive las caídas y, si faltan,
  /// agrega nuevas escaladas como el jefe. Devuelve cuántas volvieron.
  int _summonAdds(Combatant boss, BossMechanicDef m) {
    final add = engine.catalog.enemies[m.addType];
    if (add == null) return 0;
    final phase = m.kind == BossMechanicKind.echo
        ? BossMechanicPhase.echoSummon
        : BossMechanicPhase.summon;
    final max = _addsMax(m);
    var alive =
        state.enemies.where((c) => c.alive && c.enemyType == add.id).length;
    var n = 0;
    void entered(Combatant c) {
      c.nextTurn = state.clock + _iv(c) * 0.5;
      alive++;
      n++;
      events.add(BossMechanicEvent(boss.id, phase, targetId: c.id));
    }

    for (final c in state.enemies) {
      if (alive >= max) break;
      if (c.alive || c.enemyType != add.id) continue;
      c
        ..hp = c.maxHp
        ..statuses = {}
        ..holyTurns = 0
        ..brittle = false
        ..freezeResist = 0
        ..effects = []
        ..actions = 0;
      entered(c);
    }
    final bd = engine.catalog.enemies[boss.enemyType];
    while (alive < max && bd != null) {
      final c = engine.addCombatant(add, 'e${state.enemies.length}',
          boss.maxHp / bd.hp, boss.attack / math.max(1, bd.attack));
      state.enemies.add(c);
      assignCombatantTags(state);
      entered(c);
    }
    return n;
  }

  /// Al empezar el turno de la Bestia con lava: quema a los que se
  /// defienden; baja 1 turno.
  void _lavaTick(Combatant e, BossMechanicDef m) {
    if (e.lava <= 0) return;
    final party = _aliveParty.toList();
    final solo = party.length == 1;
    final power = solo ? m.soloPower : m.power;
    final stacks = (solo ? m.soloValue : m.value).round();
    final atkMod = e.effectTotal(BuffStat.attack);
    final atk =
        atkMod == 0 ? e.attack : math.max(1, jsRound(e.attack * (1 + atkMod)));
    final parts = <String>[];
    for (final p in party) {
      if (!p.defending) continue;
      events.add(BossMechanicEvent(e.id, BossMechanicPhase.lavaBurn,
          targetId: p.id, value: stacks.toDouble()));
      // Defender no lo reduce (es el piso); la DEF sí.
      final dmg = math.max(1, jsRound(atk * power * (1 - p.defensePercent)));
      final taken = dmg - _absorb(p, dmg);
      if (taken > 0) {
        _ultWithBonus(p, taken / p.maxHp * _ultTaken);
      }
      p.hp = math.max(0, p.hp - taken);
      events.add(DamageEvent(p.id, taken));
      if (!p.alive) {
        events.add(KnockedOutEvent(p.id));
        p.voidMarked = false;
        _allyDown(p);
      } else {
        _addStatus(p, StatusApplication(StatusKind.burn, stacks));
      }
      parts.add('${p.name} $taken');
    }
    if (parts.isNotEmpty) {
      _notes.add(_l('lava_burn', {
        'm': m.name,
        'n': atk,
        'x': fm(power),
        'k': stacks,
        's': _st(StatusKind.burn),
        'p': parts.join(', '),
      }));
    }
    e.lava--;
    if (e.lava <= 0) {
      e.lava = 0;
      events.add(BossMechanicEvent(e.id, BossMechanicPhase.lavaFade));
      _notes.add(_l('lava_cools'));
    }
  }

  /// La lava sube [turns] turnos de [e].
  void _lavaRise(Combatant e, int turns) {
    if (turns <= 0) return;
    e.lava = math.max(e.lava, turns);
    events.add(BossMechanicEvent(e.id, BossMechanicPhase.lavaRise,
        value: e.lava.toDouble()));
    _notes.add(_l('lava_rises', {'n': e.lava}));
  }

  /// El Centinela marca a un jugador (el provocador si hay).
  void _castMark(Combatant e, BossMechanicDef m, List<Combatant> alive) {
    final taunter = alive.where((p) => p.taunt > 0).firstOrNull;
    final p = taunter ?? alive[(_rand() * alive.length).floor()];
    if (taunter != null) taunter.taunt--;
    p.voidMarked = true;
    events.add(
        BossMechanicEvent(e.id, BossMechanicPhase.markCast, targetId: p.id));
    final solo = alive.length == 1;
    state.logLine = _l('mark_cast', {
      'a': e.name,
      'm': m.name,
      'b': p.name,
      'x': fm(solo ? m.soloValue : m.value),
      'solo': solo ? 'yes' : 'no',
    });
  }

  /// El golpe al marcado: × value, salvo que otro lo proteja (o, en solo,
  /// que se esté defendiendo).
  void _markStrike(
      Combatant e, BossMechanicDef m, Combatant marked, List<Combatant> alive) {
    final protector =
        alive.where((q) => q.protecting && q != marked).firstOrNull;
    final solo = alive.length == 1;
    final guarded = protector != null || (solo && marked.defending);
    final victim = protector ?? marked;
    final mult = guarded ? 1.0 : (solo ? m.soloValue : m.value);
    marked.voidMarked = false;
    events.add(ActionEvent(e.id,
        guarded ? BattleActionKind.enemyAttack : BattleActionKind.enemyHeavy,
        targetId: victim.id));
    events.add(guarded
        ? BossMechanicEvent(victim.id, BossMechanicPhase.markGuarded,
            targetId: marked.id)
        : BossMechanicEvent(e.id, BossMechanicPhase.markHit,
            targetId: marked.id, value: mult));
    final atkMod = e.effectTotal(BuffStat.attack);
    final atk =
        atkMod == 0 ? e.attack : math.max(1, jsRound(e.attack * (1 + atkMod)));
    final inf = _inflictsOf(e);
    final h = _hurt(victim, atk * mult, e.critChance, e.pierce,
        from: e,
        element: enemyAttackElement(engine.catalog.enemies[e.enemyType], inf),
        inflicted: inf);
    if (protector != null && victim.alive) {
      _fire(ProcTrigger.onProtectHit, victim, target: e, amount: h.damage);
    }
    final got = inf != null && _addStatus(victim, inf);
    state.logLine = LogLine.join([
      guarded
          ? _l(protector != null ? 'mark_protected' : 'mark_defended', {
              'a': e.name,
              'm': m.name,
              'b': marked.name,
              'p': protector?.name ?? '',
              'd': h.damage,
            })
          : _l('mark_hits', {
              'a': e.name,
              'm': m.name,
              'b': marked.name,
              'd': h.damage,
              'n': atk,
              'x': LogLine.join([
                LogLine.raw(fm(mult)),
                if (h.critical)
                  _l('x_crit', {'x': fm(BattleEngine.enemyCritMultiplier)}),
                if (marked.defending) _l('x_defend'),
              ], ' '),
            }),
      if (got) _statusText(inf),
    ]);
  }

  /// Fases (Devorador): si [e] llegó al umbral, la vida queda en él y
  /// pasa a la fase 2. `true` si hay que llamar a [_transform] (después
  /// del `DamageEvent`).
  bool _gatePhase(Combatant e) {
    if (e.isPlayer) return false;
    // Jefes del Abismo: 2–3 fases (abyss_bosses.md § 2).
    if (_abyssDef(e) != null) return _abyssGate(e);
    if (e.phase >= 2) return false;
    final m = _mechanicOf(e);
    if (m == null || m.kind != BossMechanicKind.phases) return false;
    final gate = (e.maxHp * m.value).ceil();
    if (e.hp > gate) return false;
    e
      ..hp = gate
      ..phase = 2;
    return true;
  }

  /// Transformación: fuera estados y barra, ATQ × power, acciones a 0.
  void _transform(Combatant e) {
    if (_abyssDef(e) != null) {
      _abyssTransform(e);
      return;
    }
    final m = _mechanicOf(e);
    if (m == null) return;
    e
      ..statuses = {}
      ..holyTurns = 0
      ..brittle = false
      ..attack = jsRound(e.attack * (m.power > 0 ? m.power : 1))
      ..actions = 0;
    if (!e.broken) {
      e
        ..breakGauge = 0
        ..fissured = false;
    }
    events.add(BossMechanicEvent(e.id, BossMechanicPhase.phaseShift, value: 2));
    _notes.add(_l('transform',
        {'a': e.name, 'p': _pct(m.power - 1), 'n': m.every}));
  }

  void _shiftStance(Combatant e, BossMechanicDef m) {
    e
      ..stance = e.stance == 1 ? 2 : 1
      ..stanceTurns = m.every;
    events.add(BossMechanicEvent(e.id, BossMechanicPhase.stanceShift,
        value: e.stance.toDouble()));
    _notes.add(_l(e.stance == 1 ? 'stance_shift_phys' : 'stance_shift_mag', {
      'a': e.name,
      's': stanceName(e.stance),
      'p': _pct(m.value),
    }));
  }

  /// −[BossMechanicDef.value] de velocidad a todo el grupo (tope `cap`).
  void _frost(Combatant e, BossMechanicDef m) {
    var total = 0.0;
    for (final p in _aliveParty) {
      final old = p.effectFrom(m.id, BuffStat.speed);
      final v = math.max(-m.cap, (old?.value ?? 0) - m.value);
      p.effects = [
        for (final fx in p.effects)
          if (!(fx.sourceId == m.id && fx.stat == BuffStat.speed)) fx,
        TimedEffect(
            sourceId: m.id,
            stat: BuffStat.speed,
            value: _r2(v),
            turns: 99,
            ownerId: e.id),
      ];
      total = math.max(total, _r2(-v));
    }
    events.add(BossMechanicEvent(e.id, BossMechanicPhase.frost, value: total));
    _notes.add(_l('frost',
        {'m': m.name, 'p': _pct(m.value), 't': _pct(total)}));
  }

  static double _r2(double v) => (v * 100).round() / 100;

  /// Se fue la escarcha: el grupo recupera la velocidad.
  void _thaw(Combatant boss, BossMechanicDef m) {
    for (final p in state.party) {
      p.effects = [
        for (final fx in p.effects)
          if (fx.sourceId != m.id) fx,
      ];
    }
    events.add(BossMechanicEvent(boss.id, BossMechanicPhase.thaw));
    _notes.add(_l('crystals_broken'));
  }

  /// Murió [c]: si es un jefe, sus invocaciones caen con él; si era la
  /// última invocación, se termina su efecto.
  void _mechanicDeath(Combatant c) {
    final m = _mechanicOf(c);
    if (m != null && m.kind == BossMechanicKind.mark) {
      for (final p in state.party) {
        p.voidMarked = false;
      }
    }
    if (m != null && c.lava > 0) {
      c.lava = 0;
      events.add(BossMechanicEvent(c.id, BossMechanicPhase.lavaFade));
    }
    if (m != null && m.addType != null) {
      for (final a in state.enemies) {
        if (a.alive && a.enemyType == m.addType) {
          a.hp = 0;
          events.add(KnockedOutEvent(a.id));
        }
      }
      if (state.party.any((p) => p.effectFrom(m.id, BuffStat.speed) != null)) {
        _thaw(c, m);
      }
      return;
    }
    if (!_passive(c) || _addsAlive(c.enemyType!)) return;
    for (final b in state.enemies) {
      final bm = _mechanicOf(b);
      if (b.alive && bm != null && bm.addType == c.enemyType) {
        _thaw(b, bm);
        return;
      }
    }
  }

  /// Golpe que teje la telaraña: ATQ × `value` a un jugador no atrapado
  /// (el provocador si hay). `false` si todos están atrapados.
  bool _castWeb(Combatant e, BossMechanicDef m, List<Combatant> alive) {
    final free = alive.where((p) => !p.webbed).toList();
    if (free.isEmpty) return false;
    final taunter = free.where((p) => p.taunt > 0).firstOrNull;
    final p = taunter ?? free[(_rand() * free.length).floor()];
    if (taunter != null) taunter.taunt--;
    events.add(ActionEvent(e.id, BattleActionKind.enemyAttack, targetId: p.id));
    final atkMod = e.effectTotal(BuffStat.attack);
    final atk =
        atkMod == 0 ? e.attack : math.max(1, jsRound(e.attack * (1 + atkMod)));
    final h = _hurt(p, atk * m.value, e.critChance, e.pierce, from: e);
    var log =
        _l('mech_hit', {'a': e.name, 'm': m.name, 'b': p.name, 'd': h.damage});
    if (p.alive) {
      p.webbed = true;
      events.add(
          BossMechanicEvent(e.id, BossMechanicPhase.webCast, targetId: p.id));
      log =
          log.plus(_l(_aliveParty.length > 1 ? 'webbed_party' : 'webbed_solo'));
    }
    state.logLine = log;
    return true;
  }

  /// [p] libera a [ally] de la telaraña: cuesta medio turno.
  bool _freeAlly(Combatant p, Combatant ally) {
    if (ally == p || !ally.alive || !ally.webbed) return false;
    ally.webbed = false;
    _act = null;
    _attacker = null;
    events.add(ActionEvent(p.id, BattleActionKind.attack, targetId: ally.id));
    events.add(
        BossMechanicEvent(p.id, BossMechanicPhase.webFreed, targetId: ally.id));
    state.logLine = _l('web_freed', {'a': p.name, 'b': ally.name});
    tickEffects(p);
    p.nextTurn = state.clock + _iv(p) * 0.5;
    endTurn();
    return true;
  }

  /// Efecto extra de la ULT de un jefe; devuelve el texto del log.
  LogLine _ultExtra(Combatant e, EnemyUltDef ult) {
    final m = _mechanicOf(e);
    switch (ult.extra) {
      case EnemyUltExtra.none:
        return LogLine.empty;
      case EnemyUltExtra.web:
        final free = _aliveParty.where((p) => !p.webbed).toList();
        if (_aliveParty.length < 2 || free.isEmpty) return LogLine.empty;
        final p = _lowest(free, (c) => -c.hp.toDouble())!;
        p.webbed = true;
        events.add(
            BossMechanicEvent(e.id, BossMechanicPhase.webCast, targetId: p.id));
        return _l('web_caught', {'a': p.name});
      case EnemyUltExtra.reformCrystals:
        if (m == null || m.addType == null) return LogLine.empty;
        var n = 0;
        for (final c in state.enemies) {
          if (c.alive || c.enemyType != m.addType) continue;
          c.hp = c.maxHp;
          n++;
          events.add(BossMechanicEvent(e.id, BossMechanicPhase.reform,
              targetId: c.id));
        }
        return n == 0 ? LogLine.empty : _l('crystals_form', {'n': n});
      case EnemyUltExtra.stanceShift:
        if (m == null || e.stance == 0) return LogLine.empty;
        _shiftStance(e, m);
        return LogLine.empty;
      case EnemyUltExtra.echoChorus:
        if (m == null) return LogLine.empty;
        e.mechTurns = 0;
        final n = _summonAdds(e, m);
        return n == 0 ? LogLine.empty : _l('echoes_return', {'n': n});
      case EnemyUltExtra.summonAll:
        if (m == null) return LogLine.empty;
        e.mechTurns = 0;
        final n = _summonAdds(e, m);
        return n == 0 ? LogLine.empty : _l('summons_servants', {'n': n});
      case EnemyUltExtra.lavaFlood:
        e.lava = math.max(e.lava, ult.turns);
        events.add(BossMechanicEvent(e.id, BossMechanicPhase.lavaRise,
            value: e.lava.toDouble()));
        return _l('lava_rises_short', {'n': e.lava});
      case EnemyUltExtra.voidMark:
        for (final p in state.party) {
          p.voidMarked = false;
        }
        final p = _lowest(_aliveParty, (c) => -c.hp.toDouble());
        if (p == null || m == null) return LogLine.empty;
        p.voidMarked = true;
        events.add(BossMechanicEvent(e.id, BossMechanicPhase.markCast,
            targetId: p.id));
        return _l('marks_target', {'a': p.name});
    }
  }

  // ---------------- jugadores ----------------

  /// `battleCmd`. Devuelve false si el comando no es válido.
  bool command(Combatant p, BattleCommand cmd) {
    final foes = state.enemies.where((e) => e.alive).toList();
    if (foes.isEmpty) return false;
    if (cmd is AttackCommand) {
      // Atacar a un aliado atrapado = liberarlo de la telaraña.
      final ally = state.party.where((q) => q.id == cmd.targetId).firstOrNull;
      if (ally != null) return _freeAlly(p, ally);
    }
    final targetId = switch (cmd) {
      AttackCommand(:final targetId) => targetId,
      SkillCommand(:final targetId) => targetId,
      UltimateCommand(:final targetId) => targetId,
      _ => null,
    };
    final target =
        foes.firstWhere((e) => e.id == targetId, orElse: () => foes.first);

    _dealt = 0;
    _dealtMaxHp = 1;
    _attacker = p;
    final act = _act = _Action();
    var ultGain = 0.0;
    var usedUlt = false;

    switch (cmd) {
      case AttackCommand():
        events.add(ActionEvent(p.id, BattleActionKind.attack,
            targetId: target.id,
            allTargets: p.keystones.contains('imparable')));
        _attack(p, foes, target);
        _gainPulse(p);
      case SkillCommand(:final skillId):
        final base = engine.catalog.skills[skillId];
        final scale = p.skillScale[skillId];
        final sk = base == null || scale == null || scale == 1
            ? base
            : base.scaled(scale, keepCosts: true);
        // MP, Pulso y precondiciones (combo_balance.md § 5.2): el host
        // rechaza la acción si falta algo.
        if (sk == null ||
            !p.skillIds.contains(skillId) ||
            SkillRequirements.missing(sk, p, target, foes: foes).isNotEmpty) {
          return false;
        }
        final combo = engine.catalog.combo;
        act
          ..breakPoints = kBaseQuebrarIds.contains(sk.id)
              ? combo.breakQuebrar
              : sk.kind == SkillKind.physical
                  ? combo.breakPhysical
                  : combo.breakMagical
          ..canBreak = BreakRules.canBreak(sk, p, engine.catalog.skills);
        p.mp -= sk.mp;
        p.pulse -= sk.pulse;
        // Sangría: cuesta vida (nunca deja en menos de 1).
        if (sk.hpCost > 0) {
          final cost = math.min(p.hp - 1, jsRound(p.maxHp * sk.hpCost));
          if (cost > 0) {
            p.hp -= cost;
            events.add(DamageEvent(p.id, cost, sourceId: sk.id));
            _notes.add(_l('hp_cost', {'s': _sk(sk), 'n': cost}));
          }
        }
        // Curas (bestiary.md § 1.4.1): el objetivo elegido puede ser un
        // enemigo con `healHarm` o (las de un blanco) un aliado vivo; si
        // no es ninguno, la cura va como siempre.
        Combatant? healPick;
        if (isTargetableHeal(sk)) {
          healPick = (sk.lowestAlly
                  ? state.party
                      .where((q) => q.id == targetId && q.alive)
                      .firstOrNull
                  : null) ??
              (engine.familiesEnabled
                  ? foes
                      .where((e) => e.id == targetId && healCanTargetFoe(sk, e))
                      .firstOrNull
                  : null);
        }
        final healFoe = healPick != null && !healPick.isPlayer;
        events.add(ActionEvent(p.id, BattleActionKind.skill,
            skillId: sk.id,
            targetId: healFoe || (sk.dealsDamage && !sk.allTargets)
                ? target.id
                : null,
            allTargets: sk.allTargets));
        act.skill = sk;
        p.lastSkillId = sk.id;
        // Reflejo de los Jefes del Abismo: copian la última habilidad.
        _abyssCopied(sk.id);
        final gain =
            _useSkill(p, sk, foes, target, ultimate: false, healPick: healPick);
        // Prisa sin aliados: ya terminó el turno.
        if (gain == null) return true;
        ultGain = gain;
        _skillExtras(p, sk);
        _fire(ProcTrigger.onSkill, p);
      case UltimateCommand():
        final sk = ultimateOf(p, engine.catalog);
        // Costo variable (ultimates_v2.md § 2.2): resta, no vacía.
        if (sk == null || p.ult < kUltCost || ultSilenced(p)) return false;
        p.ult = 0;
        usedUlt = true;
        if (sk.hpCost > 0) {
          final cost = math.min(p.hp - 1, jsRound(p.maxHp * sk.hpCost));
          if (cost > 0) {
            p.hp -= cost;
            events.add(DamageEvent(p.id, cost, sourceId: sk.id));
            _notes.add(_l('hp_cost', {'s': _sk(sk), 'n': cost}));
          }
        }
        events.add(UltimateUsedEvent(p.id, sk.name));
        events.add(ActionEvent(p.id, BattleActionKind.ultimate,
            skillId: sk.id,
            targetId: sk.dealsDamage && !sk.allTargets ? target.id : null,
            allTargets: sk.allTargets));
        act
          ..skill = sk
          ..ultimate = true
          ..breakPoints = engine.catalog.combo.breakUltimate
          ..canBreak = true;
        // Eco Doble: repite la última habilidad al `echoLast` de poder.
        final last =
            sk.echoLast > 0 ? engine.catalog.skills[p.lastSkillId ?? ''] : null;
        if (last != null) {
          final copy = last.scaled(sk.echoLast);
          act.skill = copy;
          _notes.add(_l('echo_repeat',
              {'s': _sk(sk), 'b': _sk(last), 'p': _pct(sk.echoLast)}));
          _useSkill(p, copy, foes, target, ultimate: true);
          _skillExtras(p, copy);
        } else {
          _useSkill(p, sk, foes, target, ultimate: true);
        }
        _skillExtras(p, sk);
        _fire(ProcTrigger.onSkill, p);
        _fire(ProcTrigger.onUltimate, p);
      case DualCommand(:final partnerId, :final dualId):
        act
          ..breakPoints = engine.catalog.combo.breakDual
          ..canBreak = true
          ..dual = true;
        if (!_dual(p, partnerId, dualId, foes)) return false;
      case ItemCommand(:final item, :final targetPlayerId):
        final ok = switch (item) {
          BattleItem.ether => _ether(p, targetPlayerId),
          BattleItem.potion => _potion(p, targetPlayerId),
          BattleItem.aether => _aether(p, targetPlayerId),
        };
        if (!ok) return false;
      case DefendCommand():
        events.add(ActionEvent(p.id, BattleActionKind.defend));
        p.defending = true;
        _gainPulse(
            p,
            p.guardStreak
                ? BattleEngine.defendPulseRepeat
                : BattleEngine.defendPulse);
        p.guardStreak = true;
        p.guardHitPending = true;
        _ultWithBonus(p, BattleEngine.defendUlt);
        state.logLine = _l('defends', {'a': p.name});
        _act = null;
        tickEffects(p);
        p.nextTurn = state.clock + _iv(p) * 0.7;
        endTurn();
        return true;
      case PassCommand():
        // Sin acción: no carga ULT, no defiende, no dispara procs ni
        // emite ActionEvent (los eventos siguen siendo los de v0.8.2).
        // Después de una Instante ya actuó: termina el turno sin el
        // adelanto de Pasar (combat.md § "Pulso e Instante").
        final acted = p.chained;
        state.logLine = _l(acted ? 'turn_done' : 'pass_turn', {'a': p.name});
        _act = null;
        _attacker = null;
        tickEffects(p);
        p.nextTurn =
            state.clock + _iv(p) * (acted ? 1 : BattleEngine.passTurnFactor);
        endTurn();
        return true;
      // Los resuelve BattleEngine.command antes de llegar acá.
      case WaitCommand():
      case EndTurnCommand():
        _act = null;
        _attacker = null;
        return false;
    }

    _resolveAction(p, act);
    // Robo de vida del arma (afijo `del Vampiro`): sobre todo el daño de
    // la acción.
    // Más el de la ascensión (Sangre por Sangre) y el de la habilidad.
    final steal = p.lifeSteal +
        _conditionBonus(p, BuffStat.lifeSteal) +
        (act.skill?.lifeSteal ?? 0);
    if (steal > 0 && _dealt > 0 && p.alive && p.hp < p.maxHp) {
      final h = math.max(1, jsRound(_dealt * steal));
      _heal(p, h);
      _notes.add(_l('life_steal', {'h': h}));
    }
    // Drenaje (variantes): el daño cura al aliado más herido.
    final drain = act.skill?.drainHeal ?? 0;
    if (drain > 0 && _dealt > 0) {
      final q = _lowest(_aliveParty, (c) => c.hp / c.maxHp);
      if (q != null && q.hp < q.maxHp) {
        final h = math.max(1, jsRound(_dealt * drain));
        _heal(q, h);
        _fire(ProcTrigger.onHeal, p, target: q, amount: h);
        _notes.add(_l('drain_heal', {
          's': _sk(act.skill!),
          'a': q.name,
          'h': h,
          'p': _pct(drain),
        }));
      }
    }
    if (!usedUlt) {
      final dealtBonus = _dealt > 0
          ? math.min(
              tuning(TuningId.ultCharge).d('dealtCap'),
              tuning(TuningId.ultCharge).d('dealtBase') +
                  _dealt /
                      _dealtMaxHp *
                      tuning(TuningId.ultCharge).d('dealtScale'))
          : 0.0;
      _ultWithBonus(p, (ultGain + dealtBonus));
    }
    _attacker = null;
    _act = null;
    // Instante (combo_balance.md § 5.2): no termina el turno; una por
    // turno, y después una acción más.
    final instant = (cmd is SkillCommand || cmd is UltimateCommand) &&
        (act.skill?.instant ?? false);
    if (instant && !p.chained && p.alive) {
      p.chained = true;
      _notes.add(_l('instant_more'));
      _flush();
      _checkEnd();
      if (state.ended) state.currentId = null;
      return true;
    }
    tickEffects(p);
    if (act.extraTurn) {
      // Danza de Cuchillas: el próximo turno es ahora.
      p.extraTurn = 1;
      p.nextTurn = state.clock;
    } else {
      p.nextTurn = state.clock + _iv(p) * act.turnFactor;
    }
    endTurn();
    return true;
  }

  void _attack(Combatant p, List<Combatant> foes, Combatant target) {
    final atk = _atk(p);
    // Elemento de base del arma (weapon_identity.md § 4): el básico pasa a
    // ser de ese elemento (respeta débil/resiste y reacciona) y aplica 1
    // pila de su estado cada `kWeaponElementHitsPerStack` golpes.
    final wel = weaponElementOf(p.build?.item);
    if (p.keystones.contains('imparable')) {
      final hits = [
        for (final e in foes)
          _damageEnemy(e, atk * 0.6, p.critChance, element: wel),
      ];
      _weaponElementStack(p, wel, foes);
      state.logLine = _damageLog(
          _l('unstoppable_head', {'a': p.name}), _atkText(p), atk, 0.6, hits,
          all: true);
      return;
    }
    final act = _act!..single = true;
    final hit = _damageEnemy(target, atk.toDouble(), p.critChance,
        single: true, element: wel);
    act
      ..mainTarget = target
      ..mainHit = hit;
    var log = _damageLog(_l('attacks', {'a': p.name, 'b': target.name}),
        _atkText(p), atk, 1, [hit],
        all: false);
    if (_weaponElementStack(p, wel, [target])) {
      log = log.plus(_l('weapon_stack', {'e': _el(wel!)}));
    }
    final stunChance =
        p.stunOnAttackChance > 0 ? p.stunOnAttackChance + _duoStun(p) : 0.0;
    if (stunChance > 0 &&
        target.alive &&
        _rand() < stunChance &&
        // Solo si entró (un jefe con séquito es inmune).
        _addStatus(target, const StatusApplication(StatusKind.stun, 1),
            source: p, primary: true)) {
      log = log.plus(_l('stuns_pct', {'p': jsRound(stunChance * 100)}));
    }
    if (p.branch == 'creyente' && _rand() < 0.25) {
      for (final q in _aliveParty) {
        _heal(q, math.max(1, jsRound(q.maxHp * 0.02)));
      }
      log = log.plus(_l('faith_heal'));
    }
    if (p.branch == 'inherente' &&
        target.alive &&
        _rand() < 0.25 &&
        _addStatus(target, const StatusApplication(StatusKind.holy, 1),
            source: p, primary: true)) {
      log = log.plus(_l('holy_proc', {'s': _st(StatusKind.holy)}));
    }
    state.logLine = log;
  }

  /// Cuenta un básico con elemento de arma y, cada
  /// `kWeaponElementHitsPerStack`, aplica 1 pila del estado del elemento
  /// a [targets]. `true` si entró en alguno.
  bool _weaponElementStack(
      Combatant p, GameElement? wel, List<Combatant> targets) {
    final st = wel?.status;
    if (st == null) return false;
    p.basicHits++;
    final every = math.max(1, kWeaponElementHitsPerStack);
    if (p.basicHits % every != 0) return false;
    var any = false;
    for (final t in targets) {
      if (t.alive &&
          _addStatus(t, StatusApplication(st, 1), source: p, primary: true)) {
        any = true;
      }
    }
    return any;
  }

  /// Rama `tech`/`ult` de `battleCmd`. Devuelve la carga de ULT base de
  /// la acción, o `null` si el turno ya terminó (Prisa sin aliados).
  double? _useSkill(
    Combatant p,
    SkillDef tk,
    List<Combatant> foes,
    Combatant target, {
    required bool ultimate,
    Combatant? healPick,
  }) {
    state.logLine = _l('skill_use', {'a': p.name, 's': _sk(tk)});
    final allies = _aliveParty.toList();

    switch (tk.kind) {
      case SkillKind.support:
        // Invocador (summoner.md): invocar, sacrificar, comandar, Portal.
        if (_summonSkill(p, tk, foes)) return ultimate ? 0 : 6;
        // Kit de ascensión: los efectos los pone `_skillExtras`; las
        // trampas sin daño, acá.
        if (tk.trap > 0) {
          for (final e in tk.allTargets ? foes : [target]) {
            _plantTrap(p, e, tk.id, tk.trap, 1);
          }
          state.logLine = _l('trap_set', {
            'a': p.name,
            's': _sk(tk),
            'all': tk.allTargets ? 'yes' : 'no',
            'b': target.name,
          });
        } else if (tk.debuffs.isNotEmpty || tk.ultDrain > 0) {
          // Variantes sin daño: Rugido, Señalar Presa.
          for (final e in tk.allTargets ? foes : [target]) {
            _variantOnHit(p, e, tk);
          }
          state.logLine = LogLine.join([
            _l(tk.allTargets ? 'skill_all_foes' : 'skill_on',
                {'a': p.name, 's': _sk(tk), 'b': target.name}),
            ..._debuffText(tk),
          ]);
        } else {
          state.logLine = _l('skill_use', {'a': p.name, 's': _sk(tk)});
        }
        return 6;

      case SkillKind.regen:
        final a = jsRound((p.magic * tk.power + 4) * (1 + p.healBonus));
        final regenTo = tk.lowestAlly
            ? [if (_lowest(allies, (c) => c.hp / c.maxHp) case final q?) q]
            : allies;
        for (final q in regenTo) {
          if (_skillHeal(p, q, a) <= 0) continue;
          _addStatus(q, const StatusApplication(StatusKind.regen, 3));
          _fire(ProcTrigger.onHeal, p, target: q, amount: a);
        }
        var log = _l(
            tk.lowestAlly && regenTo.isNotEmpty
                ? 'heal_regen_one'
                : 'heal_regen_all',
            {
              'a': p.name,
              's': _sk(tk),
              'n': a,
              'b': regenTo.isNotEmpty ? regenTo.first.name : '',
              'm': p.magic,
              'x': fm(tk.power),
            });
        log += _healHarm(p, a);
        if (p.branch == 'creyente') {
          final base = p.magic * 0.8;
          for (final e in foes) {
            _damageEnemy(e, base, p.critChance);
          }
          log = log.plus(_l('light_dmg', {'n': jsRound(base)}));
        }
        state.logLine = log;
        return 8;

      case SkillKind.defenseUp:
        p.bonusDefense =
            math.min(BattleEngine.maxBonusDefense, p.bonusDefense + tk.amount);
        engine._refreshStats(p);
        state.logLine = _l('defense_up', {
          'a': p.name,
          's': _sk(tk),
          'd': p.defense,
          'p': jsRound(p.defensePercent * 100),
        });
        return 6;

      case SkillKind.protect:
        p.protecting = true;
        state.logLine = _l('protect', {'a': p.name, 's': _sk(tk)});
        return 8;

      case SkillKind.bulwark:
        for (final q in allies) {
          final h = jsRound(q.maxHp * 0.3);
          _heal(q, h);
          q.defending = true;
          _fire(ProcTrigger.onHeal, p, target: q, amount: h);
        }
        p.protecting = true;
        p.bonusDefense =
            math.min(BattleEngine.maxBonusDefense, p.bonusDefense + 4);
        engine._refreshStats(p);
        state.logLine = _l('bulwark', {'a': p.name, 's': _sk(tk)});
        return 0;

      case SkillKind.heal:
        final a = jsRound((p.magic * tk.power + 6) * (1 + p.healBonus));
        // Resurrección: primero el aliado caído.
        if (tk.revive > 0) {
          // ULT (ultimates_v2.md § 3): revive a todos los caídos y además
          // cura al grupo.
          final downs = [
            for (final q in state.party)
              if (!q.alive && !q.isSummon) q
          ];
          if (downs.isNotEmpty && !ultimate) {
            _revive(p, downs.first, tk);
            return 8;
          }
          for (final q in downs) {
            _revive(p, q, tk);
          }
          if (downs.isNotEmpty) allies.addAll(downs.where((q) => q.alive));
        }
        if (healPick != null && !healPick.isPlayer) {
          // Lanzada a un no muerto / espectro: daño Sagrado solo a él.
          final d = healOnFoeDamage(a, healPick,
              mult: engine.catalog.combo.healFoeMult,
              bonus: _modTotal(p, ProcEffectKind.healHarmBonus));
          final dealt = _procDamage(p, healPick, d, kHealHarmSourceId);
          final fem =
              engine.catalog.enemies[healPick.enemyType]?.feminine ?? false;
          state.logLine = _l('heal_burns_foe', {
            'a': p.name,
            's': _sk(tk),
            'g': fem ? 'f' : 'm',
            'b': healPick.name,
            'd': dealt,
          });
          return 8;
        }
        final healed = tk.lowestAlly
            ? [
                if (healPick ?? _lowest(allies, (c) => c.hp / c.maxHp)
                    case final q?)
                  q
              ]
            : allies;
        final m = _skillMech(tk);
        for (final q in healed) {
          final before = q.hp;
          if (_skillHeal(p, q, a) <= 0) continue;
          // Desborde: lo que sobra de la cura se vuelve escudo.
          final over = a - (q.hp - before);
          if (tk.overheal > 0 && over > 0) {
            _shield(q, p, m, math.max(1, jsRound(over * tk.overheal)),
                tk.shieldTurns);
          }
          if (tk.cleanse > 0) {
            for (final k in q.statuses.keys.toList()) {
              q.statuses[k] = math.max(0, q.statuses[k]! - tk.cleanse);
            }
            q.holyTurns = math.max(0, q.holyTurns - tk.cleanse);
          }
          _fire(ProcTrigger.onHeal, p, target: q, amount: a);
        }
        state.logLine = LogLine.join([
          _l(tk.lowestAlly && healed.isNotEmpty ? 'heal_one' : 'heal_all', {
            'a': p.name,
            's': _sk(tk),
            'n': a,
            'b': healed.isNotEmpty ? healed.first.name : '',
            'm': p.magic,
            'x': fm(tk.power),
          }),
          if (tk.cleanse > 0)
            _l(tk.cleanse >= 5 ? 'cleanse_all' : 'cleanse_one'),
          _healHarm(p, a),
        ]);
        return 8;

      case SkillKind.taunt:
        p.taunt = tk.amount;
        state.logLine =
            _l('taunt', {'a': p.name, 's': _sk(tk), 'n': tk.amount});
        return 0;

      case SkillKind.guard:
        for (final q in allies) {
          q.defending = true;
        }
        state.logLine = _l('guard_all', {'a': p.name, 's': _sk(tk)});
        return 0;

      case SkillKind.haste:
        for (final q in allies.where((q) => q != p)) {
          q.nextTurn = math.max(state.clock + 0.01, q.nextTurn - _iv(q) * 0.5);
          _hasted.add(q.id);
        }
        if (state.party.length == 1) {
          p.mp += tk.mp;
          p.nextTurn = state.clock;
          state.logLine = _l('haste_no_allies');
          _act = null;
          endTurn();
          return null;
        }
        return 0;

      case SkillKind.physical:
      case SkillKind.magical:
        if (tk.charge > 0) {
          // Disparo cargado: apunta ahora, cae al empezar tu próximo turno.
          // También las ULT cargadas (Tensión Máxima): antes caían al
          // golpe normal con `power` 0 y hacían 1 de daño.
          final dmg = math.max(1, jsRound(_atk(p) * tk.charge));
          p.effects = [
            for (final e in p.effects)
              if (e.stat != BuffStat.charge) e,
            TimedEffect(
                sourceId: tk.id,
                stat: BuffStat.charge,
                value: dmg.toDouble(),
                turns: 1,
                ownerId: target.id,
                fresh: true),
          ];
          events.add(BuffAppliedEvent(
              p.id, tk.id, BuffStat.charge, dmg.toDouble(), 1));
          state.logLine = _l('charge_set', {
            'a': p.name,
            's': _sk(tk),
            'b': target.name,
            'd': dmg,
            'f': _atkText(p),
            'x': fm(tk.charge),
          });
          return 6;
        }
        if (tk.pureBreak) {
          // Quebrar base (combo_balance.md § 5.1, v0.9.1): sin daño, solo
          // quiebra a un Fisurado de antes de este paso.
          final ok = target.alive &&
              target.fissured &&
              !_fissuredNow.contains(target.id);
          if (ok) _break(target);
          state.logLine = _l('pure_break', {
            'a': p.name,
            's': _sk(tk),
            'b': target.name,
            'ok': ok ? 'yes' : 'no',
          });
          return 0;
        }
        if (tk.delayedHit > 0) {
          // Lo Que Será (ultimates_v2.md § 3.5): marca; el golpe cae tras
          // 2 turnos del objetivo.
          final v = tk.kind == SkillKind.magical ? p.magic : _atk(p);
          target
            ..doom = math.max(1, jsRound(v * tk.delayedHit))
            ..doomTurns = 2
            ..doomBy = p.id;
          events.add(ProcEvent(p.id, tk.id, targetId: target.id));
          state.logLine = _l('doom_set', {
            'a': p.name,
            'u': ultimate ? 'yes' : 'no',
            's': _sk(tk),
            'b': target.name,
            'd': target.doom,
            'mag': tk.kind == SkillKind.magical ? 'yes' : 'no',
            'v': v,
            'x': fm(tk.delayedHit),
          });
          return 0;
        }
        final tormenta = p.keystones.contains('tormenta')
            ? (tk.allTargets ? 1.25 : 0.85)
            : 1.0;
        final magical = tk.kind == SkillKind.magical;
        final sourceValue = magical ? p.magic : _atk(p);
        // Coro Prestado: +poder por aliado vivo (además del lanzador).
        final allyPower = tk.perAlly > 0
            ? tk.perAlly *
                _aliveParty.where((q) => q != p && !q.isSummon).length
            : 0.0;
        if (allyPower > 0) {
          _notes.add(_l('ally_power', {'s': _sk(tk), 'x': fm(allyPower)}));
        }
        final base = sourceValue * (tk.power + allyPower) * tormenta;
        final st = tk.status;
        final bonus = st == null ? 0 : (p.statusBonus[st.kind] ?? 0);
        final act = _act!
          ..single = !tk.allTargets
          ..skillBase = base
          ..skillStatusBonus = bonus;
        final burnBlocked =
            st?.kind == StatusKind.burn && p.keystones.contains('almaHielo');
        final hits = <_Hit>[];
        final delayMult = 1 + _conditionBonus(p, BuffStat.delayPower);
        var detonated = 0;
        // Estado principal: a cuántos se intentó aplicar y en cuántos entró
        // (el log informa el resultado, no la probabilidad).
        var tried = 0, landed = 0;
        for (final e in tk.allTargets ? foes : [target]) {
          // Detonar: +daño por cada stack elemental, que se consumen.
          var b = base;
          if (tk.detonate > 0) {
            final n = kElementalStatuses.fold(0, (s, k) => s + e.stacks(k));
            b = base * (1 + tk.detonate * n);
            detonated += n;
            // El estado que el golpe detona (Supernova sobre Veneno →
            // Explosión tóxica) queda para la reacción, que lo consume
            // (elemental_reactions.md § 9).
            final keep = _skillReaction(e, tk)?.primer;
            for (final k in kElementalStatuses) {
              if (k != keep) e.statuses[k] = 0;
            }
            if (keep != StatusKind.freeze) e.brittle = false;
          }
          // Primer Golpe: +daño si el objetivo tiene la vida llena.
          if (tk.openerBonus > 0 && e.hp >= e.maxHp) {
            b *= 1 + tk.openerBonus;
            _notes.add(
                _l('opener', {'s': _sk(tk), 'p': _pct(tk.openerBonus)}));
          }
          final hit = _damageEnemy(e, b, p.critChance + tk.critBonus,
              single: !tk.allTargets);
          hits.add(hit);
          if (tk.stripBuffs) _stripBuffs(e, _sk(tk));
          if (!tk.allTargets) {
            act
              ..mainTarget = e
              ..mainHit = hit;
          }
          // Ráfaga (variantes): golpes seguidos al mismo objetivo.
          if (tk.hits > 1) {
            final more = <int>[hit.damage];
            for (var h = 1; h < tk.hits && e.alive; h++) {
              more.add(_damageEnemy(e, b, p.critChance + tk.critBonus,
                      single: !tk.allTargets, hitIndex: h)
                  .damage);
            }
            _notes.add(_l('multi_hits', {
              'n': more.length,
              'p': more.join(' + '),
              't': more.fold<int>(0, (s, d) => s + d),
            }));
          }
          _variantOnHit(p, e, tk);
          if (st != null && !burnBlocked) {
            if (e.alive) tried++;
            if (_addStatus(e, st, bonus: bonus, source: p, primary: true)) {
              landed++;
            }
          }
          for (final x in tk.extraStatuses) {
            if (x.kind == StatusKind.burn &&
                p.keystones.contains('almaHielo')) {
              continue;
            }
            _addStatus(e, x,
                bonus: p.statusBonus[x.kind] ?? 0, source: p, primary: true);
          }
          if (tk.delay > 0 && e.alive) {
            e.nextTurn += _iv(e) *
                tk.delay *
                delayMult *
                (_fam(e)?.delayMult ?? 1) *
                _delayFalloff(e);
            events.add(DelayedEvent(e.id));
            _fire(ProcTrigger.onDelayApplied, p, target: e);
          }
          if (tk.execute > 0) _execute(p, e, tk.execute, tk.id, _sk(tk));
          if (tk.trap > 0 && e.alive) _plantTrap(p, e, tk.id, tk.trap, 1);
        }
        if (detonated > 0) {
          _notes.add(_l('detonate', {
            's': _sk(tk),
            'n': detonated,
            'p': _pct(tk.detonate * detonated),
          }));
        }
        if (!tk.allTargets) {
          _pierceAndBounce(p, tk, target, base, st, burnBlocked ? 0 : bonus,
              blocked: burnBlocked);
        }
        final head = _l('skill_head', {
          'a': p.name,
          'u': ultimate ? 'yes' : 'no',
          's': _sk(tk),
          'all': tk.allTargets ? 'yes' : 'no',
          'b': target.name,
        });
        var log = _damageLog(
            head,
            magical ? _l('src_mag', {'n': sourceValue}) : _atkText(p),
            sourceValue,
            tk.power,
            hits,
            all: tk.allTargets,
            tormenta: tormenta);
        if (tk.delay > 0) log = log.plus(_l('delays'));
        log += _debuffText(tk);
        if (burnBlocked) {
          log = log.plus(_l('burn_blocked', {
            's': _st(StatusKind.burn),
            'k': LogLine.named(CatalogKeys.mechName('almaHielo'), 'Alma de Hielo'),
          }));
        } else if (st != null) {
          log += _statusOutcome(st, bonus, tried, landed);
        }
        state.logLine = log;
        return 0;
    }
  }

  bool _dual(
      Combatant p, String partnerId, String? dualId, List<Combatant> foes) {
    final q = state.party.where((c) => c.id == partnerId).firstOrNull;
    if (q == null ||
        q == p ||
        !q.alive ||
        p.mp < BattleEngine.dualMpCost ||
        q.mp < BattleEngine.dualMpCost ||
        // Silence (combat.md § "Silencio"): duos cost MP.
        p.silenced > 0 ||
        q.silenced > 0 ||
        // porBando: el compañero gasta su acción de este turno del grupo.
        (state.grouped && state.acted.contains(q.id))) {
      return false;
    }
    // Sin id: el dúo de clase del par (v0.8.2). Con id: ese dúo, si el
    // par lo puede hacer (clase o tipos de arma, dual_rules.dart).
    final id = dualId ?? dualKey(p.classId ?? '', q.classId ?? '');
    final du = engine.catalog.duals[id];
    if (du == null || !dualFits(id, du, p, q)) return false;

    events.add(ActionEvent(p.id, BattleActionKind.dual,
        skillId: id, partnerId: q.id, allTargets: true));
    q.defending = false;
    p.mp -= BattleEngine.dualMpCost;
    q.mp -= BattleEngine.dualMpCost;
    q.nextTurn = math.max(q.nextTurn, state.clock) + _iv(q);
    if (state.grouped) state.acted.add(q.id);

    final pv = math.max(_atk(p), p.magic);
    final qv = math.max(_atk(q), q.magic);
    final bonus = p.statusBonus[du.status.kind] ?? 0;
    final hits = <_Hit>[];
    var tried = 0, landed = 0;
    for (final e in foes) {
      hits.add(_damageEnemy(
          e, (pv + qv) * du.power, (p.critChance + q.critChance) / 2,
          element: elementOfDual(du), hitStatus: du.status));
      if (e.alive) tried++;
      if (_addStatus(e, du.status, bonus: bonus, source: p, primary: true)) {
        landed++;
      }
    }
    state.logLine = (_damageLog(
            _l('dual_head',
                {'a': p.name, 'b': q.name, 's': LogLine.dual(id, du.name)}),
            LogLine.raw('($pv + $qv)'),
            pv + qv,
            du.power,
            hits,
            all: true) +
        _statusOutcome(du.status, bonus, tried, landed));
    return true;
  }

  /// Primer aliado con el menor valor (como el `sort(...)[0]` estable
  /// del prototipo).
  Combatant? _lowest(Iterable<Combatant> list, double Function(Combatant) f) {
    Combatant? best;
    for (final c in list) {
      if (best == null || f(c) < f(best)) best = c;
    }
    return best;
  }

  bool _ether(Combatant p, String? targetId) {
    if (p.ethers <= 0) return false;
    final chosen = targetId == null ? null : state.byId(targetId);
    final t = chosen != null && chosen.isPlayer && chosen.alive
        ? chosen
        : _lowest(_aliveParty, (c) => c.mp / c.maxMp);
    if (t == null) return false;
    events.add(ActionEvent(p.id, BattleActionKind.ether, targetId: t.id));
    p.ethers--;
    final a = jsRound(t.maxMp * 0.5);
    t.mp = math.min(t.maxMp.toDouble(), t.mp + a);
    events.add(HealEvent(t.id, a, mana: true));
    state.logLine =
        _l('ether', {'a': p.name, 'b': t.name, 'n': a, 'm': t.maxMp});
    return true;
  }

  /// Éter (loot.md § 17.6): revive a un aliado caído con toda la vida.
  /// Sin caídos no se gasta (la acción no vale).
  bool _aether(Combatant p, String? targetId) {
    if (p.aethers <= 0) return false;
    final chosen = targetId == null ? null : state.byId(targetId);
    final t =
        chosen != null && chosen.isPlayer && !chosen.isSummon && !chosen.alive
            ? chosen
            : state.party.where((c) => !c.alive && !c.isSummon).firstOrNull;
    if (t == null) return false;
    events.add(ActionEvent(p.id, BattleActionKind.potion, targetId: t.id));
    p.aethers--;
    _heal(t, t.maxHp);
    t.statuses[StatusKind.burn] = 0;
    t.statuses[StatusKind.poison] = 0;
    t.nextTurn = state.clock + _iv(t);
    events.add(RevivedEvent(t.id));
    state.logLine = _l('aether_revive',
        {'a': p.name, 'b': t.name, 'h': t.hp, 'm': t.maxHp});
    return true;
  }

  bool _potion(Combatant p, String? targetId) {
    if (p.potions <= 0) return false;
    final chosen = targetId == null ? null : state.byId(targetId);
    final t = chosen != null && chosen.isPlayer
        ? chosen
        : _lowest(state.party, (c) => c.hp / c.maxHp);
    if (t == null) return false;
    events.add(ActionEvent(p.id, BattleActionKind.potion, targetId: t.id));
    p.potions--;
    final a = jsRound(t.maxHp * 0.45 * (1 + engine.townPotion));
    final was = t.hp;
    _heal(t, a);
    t.statuses[StatusKind.burn] = 0;
    t.statuses[StatusKind.poison] = 0;
    if (was == 0) {
      t.nextTurn = state.clock + _iv(t);
      events.add(RevivedEvent(t.id));
    }
    state.logLine = _l('potion', {
      'a': p.name,
      'b': t.name,
      'n': a,
      'm': t.maxHp,
      'rev': was == 0 ? 'yes' : 'no',
      'x': _st(StatusKind.burn),
      'y': _st(StatusKind.poison),
    });
    return true;
  }
}

/// Id del escudo que deja revivir con Curación (Velo del Retorno).
const kReviveVeilId = 'veloRetorno';

/// Source id of the opening shield of a legendary meal (farming.md § 19.3).
const kMealShieldId = 'comidaEscudo';

/// Opening shield of legendary resistance meals (farming.md § 19.3).
void applyMealShields(BattleState state) {
  for (final p in state.party) {
    final f = CookingRules.shield(p.build?.meal);
    if (f <= 0 || !p.alive) continue;
    final v = (p.maxHp * f).round();
    if (v <= 0) continue;
    p.effects = [
      ...p.effects,
      TimedEffect(
          sourceId: kMealShieldId,
          stat: BuffStat.shield,
          value: v.toDouble(),
          turns: CookingRules.shieldTurns,
          ownerId: p.id),
    ];
  }
}

/// Nombre de la postura del Caballero Hueco (`Combatant.stance`).
LogLine stanceName(int stance) => stance == 1
    ? _l('stance.shield')
    : stance == 2
        ? _l('stance.sword')
        : const LogLine.raw('—');

// ---------------- log (docs/specs/i18n.md § 3.4) ----------------

/// A battle log line `ui.battle_log.<key>` with [args].
LogLine _l(String key, [Map<String, Object?> args = const {}]) =>
    LogLine('ui.battle_log.$key', args);

LogLine _sk(SkillDef s) => LogLine.skill(s.id, s.name);
LogLine _st(StatusKind k) => LogLine.status(k.name, k.label);
LogLine _mech(PassiveMechanic m) =>
    LogLine.named(displayNameKey(m.id) ?? CatalogKeys.mechName(m.id), m.name);

/// "(N turnos)".
LogLine _turnsL(int n) => _l('turns', {'n': n});
LogLine _stat(BuffStat s) => _l('stat.${s.name}');
LogLine _eult(EnemyUltDef u) => LogLine.enemyUlt(u.id, u.name);

/// An enemy hit line: `head` + status (` · `), then taunt / protection
/// (with a leading space) and the extras (` · `), as the old text.
LogLine _enemyHitLine(LogLine head, LogLine status, LogLine taunt, LogLine prot,
    List<LogLine> extras) {
  final tail = LogLine.join([taunt, prot], ' ');
  return LogLine.join([
    LogLine.join([head, status]),
    if (!tail.isEmpty) _l('pre_space', {'x': tail}),
    for (final x in extras) _l('pre_dot', {'x': x}),
  ], '');
}

LogLine _rxL(ReactionKind k) => LogLine.reaction(k.name, k.label);
LogLine _el(GameElement e) => LogLine.named(CatalogKeys.element(e), e.label);

/// `× 1.15 Marca`.
LogLine _mod(num x, LogLine label) => _l('mod', {'x': fm(x), 'l': label});

/// Name of any effect source id ([displayName]) as a log ref.
LogLine _disp(String id) =>
    LogLine.named(displayNameKey(id) ?? '', displayName(id));
