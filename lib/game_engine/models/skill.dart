import 'passive_mechanic.dart' show BuffStat;
import 'status.dart';

/// Forma de entrega de una habilidad de arma, para trasladarla en la
/// fusión (loot.md § 16.1): las físicas de golpe solo van a armas cuerpo
/// a cuerpo, las de disparo solo a armas a distancia; el resto (mágicas,
/// curas, escudos, buffs y debuffs sin golpe) a cualquiera.
/// [caster]: solo armas de lanzador (báculo, varita, tomo): las
/// invocaciones (docs/specs/summoner.md § 4).
enum SkillDelivery { melee, ranged, any, caster }

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

/// Tipo de precondición de una habilidad (combo_balance.md § 5.2).
enum SkillReqKind {
  /// El objetivo tiene `amount` o más stacks de `status`.
  targetStacks,

  /// El objetivo está Fisurado (barra de quiebre llena).
  targetFissured,

  /// El objetivo tiene Marca (`BuffStat.damageTaken` > 0).
  targetMarked,

  /// La vida propia está por debajo de `fraction` de la máxima.
  selfHpBelow,
}

/// Precondición declarativa de una habilidad (combo_balance.md § 5.2):
/// si no se cumple, el botón sale desactivado ("Necesita: …") y el host
/// rechaza la acción. La evalúa `SkillRequirements` (rules).
class SkillReq {
  const SkillReq.targetStacks(StatusKind this.status, this.amount)
      : kind = SkillReqKind.targetStacks,
        fraction = 0;
  const SkillReq.targetFissured()
      : kind = SkillReqKind.targetFissured,
        status = null,
        amount = 0,
        fraction = 0;
  const SkillReq.targetMarked()
      : kind = SkillReqKind.targetMarked,
        status = null,
        amount = 0,
        fraction = 0;
  const SkillReq.selfHpBelow(this.fraction)
      : kind = SkillReqKind.selfHpBelow,
        status = null,
        amount = 0;

  final SkillReqKind kind;
  final StatusKind? status;
  final int amount;
  final double fraction;

  /// Lo que falta, para el tooltip ("Necesita: objetivo Fisurado").
  String get label => switch (kind) {
        SkillReqKind.targetStacks =>
          'objetivo con $amount+ de ${status!.label}',
        SkillReqKind.targetFissured => 'objetivo Fisurado',
        SkillReqKind.targetMarked => 'objetivo con Marca',
        SkillReqKind.selfHpBelow =>
          'tu vida bajo el ${(fraction * 100).round()}%',
      };

  /// Pide algo del objetivo (no de quien la usa).
  bool get onTarget => kind != SkillReqKind.selfHpBelow;
}

/// Una habilidad (o ULT). Puerto 1:1 de las entradas de `SK` / `ULTS`,
/// más los efectos opcionales del kit de ascensión (ascension.md § 4).
/// Carga que pide toda ULT: la barra llena (la vacía al lanzarla). El
/// costo variable 60 / 80 / 100 de ULT v2 se revirtió (ultimates_v2.md § 7).
const double kUltCost = 100;

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

  /// Quebrar (combo_balance.md § 5): un golpe de esta habilidad quiebra
  /// a un enemigo Fisurado ("Puede quebrar"; si no está Fisurado pega
  /// normal). Las ULT, los dúos y las Convergencias lo tienen siempre.
  final bool breaks;

  // ---- Pulso, precondiciones e Instante (combo_balance.md § 5.2) ----

  /// Pulso que cuesta (además del MP): preparar 0-1, detonar y Quebrar
  /// 2-3. Las ULT no usan Pulso.
  final int pulse;

  /// Instante: no termina el turno (una por turno; después, una acción
  /// más). Ver combat.md § "Pulso e Instante".
  final bool instant;

  /// Precondiciones (todas tienen que cumplirse).
  final List<SkillReq> requires;

  // ---- ULT v2 (docs/specs/ultimates_v2.md § 2.2 y § 5.4) ----

  /// +Pulso a todo el grupo (Pulso Magitec).
  final int pulseParty;

  /// +daño (fracción) si el objetivo tiene la vida llena (Primer Golpe).
  final double openerBonus;

  /// Repite la última habilidad del lanzador con este factor de poder
  /// (Eco Doble). Sin habilidad previa, pega con `power`.
  final double echoLast;

  /// Marca: tras 2 turnos del objetivo recibe ATQ/MAG × esto y queda
  /// quebrado si está Fisurado (Lo Que Será). Reemplaza el golpe.
  final double delayedHit;

  /// +poder por cada aliado vivo además del lanzador (Coro Prestado).
  final double perAlly;

  /// Quita los buffs (efectos positivos) de los enemigos golpeados.
  final bool stripBuffs;

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
    this.breaks = false,
    this.pulse = 0,
    this.instant = false,
    this.requires = const [],
    this.pulseParty = 0,
    this.openerBonus = 0,
    this.echoLast = 0,
    this.delayedHit = 0,
    this.perAlly = 0,
    this.stripBuffs = false,
  });

  /// Copia con el poder escalado por [factor] (Eco Doble repite la última
  /// habilidad al 80%): golpe, disparo cargado y trampa. Con [keepCosts]
  /// (nivel de una ULT, ultimates_v2.md § 2.4) conserva costos, Pulso,
  /// Instante y precondiciones y también escala escudos, golpe diferido
  /// y poder por aliado.
  SkillDef scaled(double factor, {bool keepCosts = false}) {
    final s = keepCosts ? factor : 1.0;
    return SkillDef(
        id: id,
        name: name,
        kind: kind,
        mp: mp,
        power: power * factor,
        allTargets: allTargets,
        delay: delay,
        status: status,
        critBonus: critBonus,
        cleanse: cleanse,
        amount: amount,
        hpCost: keepCosts ? hpCost : 0,
        lifeSteal: lifeSteal,
        extraStatuses: extraStatuses,
        detonate: detonate,
        catalyst: catalyst,
        execute: execute,
        trap: trap * factor,
        partyBuffs: partyBuffs,
        partyShield: partyShield * s,
        partyShieldTurns: partyShieldTurns,
        advanceAllies: advanceAllies,
        selfBuff: selfBuff,
        selfTurn: selfTurn,
        protect: protect,
        lowestAlly: lowestAlly,
        revive: revive,
        overheal: overheal,
        drainHeal: drainHeal,
        allyShield: allyShield * s,
        selfShield: selfShield * s,
        shieldTurns: shieldTurns,
        shieldReflect: shieldReflect,
        shieldBurst: shieldBurst,
        shieldGrow: shieldGrow,
        pierce: pierce,
        bounces: bounces,
        hits: hits,
        charge: charge * factor,
        debuffs: debuffs,
        breakBonus: breakBonus,
        ultDrain: ultDrain,
        breaks: breaks,
        pulse: keepCosts ? pulse : 0,
        instant: keepCosts && instant,
        requires: keepCosts ? requires : const [],
        pulseParty: pulseParty,
        openerBonus: openerBonus,
        echoLast: keepCosts ? echoLast : 0,
        delayedHit: delayedHit * s,
        perAlly: perAlly * s,
        stripBuffs: stripBuffs,
      );
  }

  bool get dealsDamage =>
      kind == SkillKind.physical || kind == SkillKind.magical;

  /// Quebrar puro (Quebrar base, combo_balance.md § 5.1): no hace daño,
  /// solo quiebra a un Fisurado.
  bool get pureBreak => breaks && dealsDamage && power <= 0 && charge <= 0;

  /// Tiene un efecto para el grupo (filtro `rallySkill`).
  bool get rally =>
      partyBuffs.isNotEmpty || partyShield > 0 || advanceAllies > 0;

  /// Da algún escudo (a uno, a sí mismo o al grupo).
  bool get shields => partyShield > 0 || allyShield > 0 || selfShield > 0;
}

/// Ataque combinado (`DUALS`): de dos clases (clave `dualKey`) o, desde
/// v0.8.3, de dos TIPOS DE ARMA ([weapons], docs/specs/combat.md § "Dúos").
class DualDef {
  final String name;
  final StatusApplication status;
  final double power;

  /// Dúo de armas: los dos tipos de arma (`WeaponDef.type`) que lo
  /// habilitan, en cualquier orden. `null` = dúo de clase.
  final List<String>? weapons;

  const DualDef(this.name, this.status, this.power, {this.weapons});

  /// Dúo de armas (v0.8.3).
  bool get byWeapon => weapons != null;
}
