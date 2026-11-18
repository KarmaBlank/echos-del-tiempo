import 'passive_mechanic.dart' show BuffStat;
import 'status.dart';

/// Forma de entrega de una habilidad de arma, para trasladarla en la
/// fusión (loot.md § 16.1): las físicas de golpe solo van a armas cuerpo
/// a cuerpo, las de disparo solo a armas a distancia; el resto (mágicas,
/// curas, escudos, buffs y debuffs sin golpe) a cualquiera.
enum SkillDelivery { melee, ranged, any }

/// Tipos de habilidad del prototipo (`kind` en `SK` / `ULTS`).
enum SkillKind {
  physical, // 'phys': daño con ATQ
  magical, // 'mag': daño con MAG
  heal,
  regen,
  haste,
  taunt,
  guard,
  defenseUp, // 'defup'
  protect,
  bulwark,

  /// Sin daño: solo sus efectos de grupo / propios (kit de ascensión,
  /// docs/specs/ascension.md § 4).
  support,
}

/// Buff de grupo de una habilidad (gritos del kit de ascensión).
class PartyBuff {
  const PartyBuff(this.stat, this.value, this.turns);
  final BuffStat stat;
  final double value;
  final int turns;
}

/// Una habilidad (o ULT). Puerto 1:1 de las entradas de `SK` / `ULTS`,
/// más los efectos opcionales del kit de ascensión (ascension.md § 4).
class SkillDef {
  final String id;
  final String name;
  final int mp;
  final SkillKind kind;
  final double power;
  final bool allTargets;
  final double delay;
  final StatusApplication? status;
  final double critBonus;
  final int cleanse;

  /// `n` del prototipo: turnos de Provocar o DEF de Fortaleza.
  final int amount;

  // ---- kit de ascensión (todo apagado por defecto) ----

  /// Fracción de la vida máx. que cuesta usarla (no baja de 1).
  final double hpCost;

  /// Fracción del daño de la acción que cura.
  final double lifeSteal;

  /// Estados extra que aplica a cada golpeado (secundarios).
  final List<StatusApplication> extraStatuses;

  /// +daño por cada stack elemental del objetivo (los consume).
  final double detonate;

  /// Catalizador (Elementalista v0.7, ascension.md § 4.1): el golpe toma
  /// el elemento que reacciona con lo que tenga el objetivo y, si
  /// detona, hace × (1 + catalyst). 0 = apagado.
  final double catalyst;

  /// Remata (no jefes ni élites) si el objetivo queda por debajo de esto.
  final double execute;

  /// Poder de la trampa que deja en cada objetivo (ATQ × trap).
  final double trap;

  /// Buffs para todos los aliados vivos (el que la usa incluido).
  final List<PartyBuff> partyBuffs;

  /// Escudo para cada aliado: fracción de la vida máx. del que la usa.
  final double partyShield;
  final int partyShieldTurns;

  /// Adelanta a cada aliado (no al que la usa) esta fracción de su
  /// espera; sin aliados, adelanta el próximo turno propio.
  final double advanceAllies;

  /// Buff propio (Apuntar).
  final PartyBuff? selfBuff;

  /// Factor del próximo turno propio (Apuntar: 0.5).
  final double selfTurn;

  /// Pone Protección (como la habilidad Protección).
  final bool protect;

  // ---- variantes (docs/specs/combat.md § "Variantes de habilidades") ----

  /// Cura / Regeneración / escudo solo al aliado más herido (% de vida).
  final bool lowestAlly;

  /// Revive al primer aliado caído con esta fracción de su vida máx.
  /// (si no hay caídos, cura normal).
  final double revive;

  /// Fracción de la cura que sobra (vida llena) que se vuelve escudo.
  final double overheal;

  /// Fracción del daño de la acción que cura al aliado más herido.
  final double drainHeal;

  /// Escudo al aliado más herido / a uno mismo: fracción de la vida máx.
  /// del que la usa, por [shieldTurns] turnos.
  final double allyShield;
  final double selfShield;
  final int shieldTurns;

  /// Los escudos de esta habilidad devuelven esta fracción de lo que
  /// absorben al enemigo que pega.
  final double shieldReflect;

  /// Los escudos de esta habilidad, al romperse, explotan: ATQ del dueño
  /// × esto a todos los enemigos.
  final double shieldBurst;

  /// Los escudos de esta habilidad crecen esta fracción de lo que
  /// absorben (tope: 50% de la vida máx. del que lo lleva).
  final double shieldGrow;

  /// Atraviesa: también golpea a los enemigos detrás del objetivo (los
  /// siguientes de la formación) con esta fracción del daño.
  final double pierce;

  /// Rebota a N enemigos al azar (×0.7 por rebote; solo: al mismo).
  final int bounces;

  /// Golpes seguidos al objetivo (ráfaga), cada uno de `power`.
  final int hits;

  /// Disparo cargado: no pega ahora; al empezar tu próximo turno cae
  /// ATQ × charge sobre el objetivo (o el primer enemigo en pie).
  final double charge;

  /// Debuffs a cada enemigo golpeado (o a los objetivos, si no hace
  /// daño): Marca (`damageTaken`), Debilitar (`attack` < 0), Lentitud
  /// (`speed` < 0).
  final List<PartyBuff> debuffs;

  /// +fracción de llenado de la barra de quiebre.
  final double breakBonus;

  /// Silencio: quita esta carga de ULT a cada enemigo golpeado.
  final double ultDrain;

  const SkillDef({
    required this.id,
    required this.name,
    required this.kind,
    this.mp = 0,
    this.power = 0,
    this.allTargets = false,
    this.delay = 0,
    this.status,
    this.critBonus = 0,
    this.cleanse = 0,
    this.amount = 0,
    this.hpCost = 0,
    this.lifeSteal = 0,
    this.extraStatuses = const [],
    this.detonate = 0,
    this.catalyst = 0,
    this.execute = 0,
    this.trap = 0,
    this.partyBuffs = const [],
    this.partyShield = 0,
    this.partyShieldTurns = 0,
    this.advanceAllies = 0,
    this.selfBuff,
    this.selfTurn = 1,
    this.protect = false,
    this.lowestAlly = false,
    this.revive = 0,
    this.overheal = 0,
    this.drainHeal = 0,
    this.allyShield = 0,
    this.selfShield = 0,
    this.shieldTurns = 2,
    this.shieldReflect = 0,
    this.shieldBurst = 0,
    this.shieldGrow = 0,
    this.pierce = 0,
    this.bounces = 0,
    this.hits = 1,
    this.charge = 0,
    this.debuffs = const [],
    this.breakBonus = 0,
    this.ultDrain = 0,
  });

  bool get dealsDamage =>
      kind == SkillKind.physical || kind == SkillKind.magical;

  /// Tiene un efecto para el grupo (filtro `rallySkill`).
  bool get rally =>
      partyBuffs.isNotEmpty || partyShield > 0 || advanceAllies > 0;

  /// Da algún escudo (a uno, a sí mismo o al grupo).
  bool get shields => partyShield > 0 || allyShield > 0 || selfShield > 0;
}

/// Ataque combinado de dos clases (`DUALS`).
class DualDef {
  final String name;
  final StatusApplication status;
  final double power;

  const DualDef(this.name, this.status, this.power);
}
