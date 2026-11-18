import 'elements.dart';
import 'item.dart';
import 'loot.dart';
import 'status.dart';

// Jefes del Abismo v0.8 (docs/specs/abyss_bosses.md): las mecánicas son
// datos (fases con una rotación de movimientos); el motor tiene código
// por tipo de movimiento, como las mecánicas de jefe de siempre.

/// Tipo de movimiento de un Jefe del Abismo (§ 2.1).
enum AbyssMoveKind {
  attack('Ataque'),
  strike('Golpe a todos'),
  rewind('Rebobinar'),
  timeWarp('Distorsión'),
  mirror('Reflejo'),
  seal('Sello'),
  summon('Invocación'),
  devour('Devorar');

  const AbyssMoveKind(this.label);
  final String label;

  /// Movimiento que se avisa una acción antes (todos menos el ataque).
  bool get telegraphed => this != attack;
}

/// Un movimiento de la rotación de una fase. `value` / `soloValue` según
/// el tipo: fracción curada (rebobinar), fracción de turno (distorsión),
/// daño bloqueado (sello), +ATQ por buff (devorar).
class AbyssMoveDef {
  const AbyssMoveDef(
    this.kind, {
    this.name,
    this.power = 1,
    this.element,
    this.status,
    this.delay = 0,
    this.value = 0,
    this.soloValue = 0,
    this.turns = 0,
    this.reaction,
    this.cap = 0,
  });

  final AbyssMoveKind kind;

  /// Nombre propio (golpes a todos); si no, el del tipo.
  final String? name;

  /// Multiplicador del ATQ (golpes a todos, reflejo).
  final double power;

  /// Elemento del golpe (`null` = el aspecto o el del jefe).
  final GameElement? element;
  final StatusApplication? status;

  /// Retraso al grupo (`IV × delay`).
  final double delay;
  final double value;
  final double soloValue;

  /// Sello: turnos propios que dura.
  final int turns;

  /// Sello: la reacción que lo rompe con grupo.
  final ReactionKind? reaction;

  /// Devorar: tope del ATQ ganado.
  final double cap;

  String get label => name ?? kind.label;
}

/// Una fase de un Jefe del Abismo.
class AbyssPhaseDef {
  const AbyssPhaseDef({
    required this.name,
    required this.gate,
    required this.moves,
    this.attackMult = 1,
    this.aspects = const [],
    this.summon = false,
    this.immuneWhileAdds = false,
    this.statusImmuneWhileAdds = false,
  });

  /// Nombre de la fase (cartel y chip).
  final String name;

  /// Fracción de la vida a la que empieza (la primera: 1).
  final double gate;

  /// ATQ × al entrar.
  final double attackMult;

  /// Rotación: cada acción usa `moves[acciones % n]`.
  final List<AbyssMoveDef> moves;

  /// Aspecto elemental: uno fijo o en ciclo (cambia al empezar cada turno
  /// del jefe). Sus golpes llevan ese elemento y su estado; recibe ×0.5
  /// del mismo elemento.
  final List<GameElement> aspects;

  /// Al entrar completa sus invocaciones.
  final bool summon;

  /// Inmune al daño mientras viva alguna invocación.
  final bool immuneWhileAdds;

  /// Inmune a los estados mientras viva alguna invocación.
  final bool statusImmuneWhileAdds;
}

/// Un Jefe del Abismo (`kAbyssBosses`, por número 1..5).
class AbyssBossDef {
  const AbyssBossDef({
    required this.number,
    required this.enemyId,
    required this.name,
    required this.level,
    required this.phases,
    required this.arenaZone,
    required this.legendaryIds,
    this.fragment,
    this.matchBoss = 0,
    this.fragmentCost = 5,
    this.enrageTurns = 40,
    this.enragePower = 2.0,
    this.healHurts = 0,
    this.aspectResist = 0.5,
    this.secret = false,
    this.legendaryChance = 0.25,
    this.essence = 1,
    this.essenceExtra = 0.5,
    this.atlasPoints = 1,
  });

  /// 1..4 los jefes, 5 el secreto.
  final int number;

  /// Id del enemigo (`kEnemies`).
  final String enemyId;
  final String name;

  /// Nivel de monstruo (stats del catálogo a ese nivel).
  final int level;
  final List<AbyssPhaseDef> phases;

  /// Zona de la arena / el mapa (0 = arena propia del secreto).
  final int arenaZone;

  /// Legendarios exclusivos (`kUniques`).
  final List<String> legendaryIds;

  /// Fragmento que lo abre (`null`: el secreto, 1 de cada uno).
  final CraftMaterial? fragment;

  /// Jefe de Eco (1..10) que da mejores chances de su Fragmento.
  final int matchBoss;

  /// Fragmentos para abrirlo.
  final int fragmentCost;

  /// Turno propio en el que entra en furia y su multiplicador de ATQ.
  final int enrageTurns;
  final double enragePower;

  /// Fracción de las curas del grupo que le hace daño (0 = no).
  final double healHurts;

  /// Daño que recibe del elemento de su aspecto.
  final double aspectResist;
  final bool secret;

  /// Chance del legendario exclusivo después de la primera victoria.
  final double legendaryChance;

  /// Esencias por jugador: [essence] seguras + [essenceExtra] de otra.
  final int essence;
  final double essenceExtra;

  /// Puntos de Atlas de la primera victoria de la cuenta.
  final int atlasPoints;

  String get id => enemyId;

  /// Clave de "primera vez" en el Atlas (`x1`..`x5`).
  String get atlasKey => 'x$number';

  StackKind? get fragmentStack =>
      fragment == null ? null : StackKind.of(fragment!);
}

/// Números del drop de Fragmentos (§ 1.1), editables.
class FragmentDropDef {
  const FragmentDropDef({
    this.minTier = 10,
    this.battle = 0.02,
    this.chest = 0.04,
    this.elite = 0.08,
    this.boss = 0.20,
    this.mission = 0.30,
    this.perTier = 0.15,
    this.perRarity = 0.10,
    this.perMod = 0.05,
    this.matchChance = 1.5,
    this.matchWeight = 4,
    this.cap = 0.95,
  });

  String get id => 'fragmentos';
  String get name => 'Fragmentos del Abismo';

  final int minTier;
  final double battle, chest, elite, boss, mission;
  final double perTier;
  final double perRarity;
  final double perMod;

  /// En el jefe y el fin del Eco cuyo jefe coincide: chance × esto.
  final double matchChance;

  /// Peso del Fragmento que coincide (los demás pesan 1).
  final double matchWeight;
  final double cap;

  double base(LootSource s) => switch (s) {
        LootSource.battle => battle,
        LootSource.chest => chest,
        LootSource.elite => elite,
        LootSource.boss => boss,
        LootSource.mission => mission,
      };
}
