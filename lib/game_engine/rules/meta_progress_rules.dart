import 'dart:math' as math;

import '../data/game_catalog.dart';
import '../data/run_boons.dart';
import '../data/tuning_catalog.dart';
import '../models/attributes.dart';
import '../models/run_state.dart';
import '../models/skill.dart';
import '../models/travesia_meta.dart';

/// Qué hace un nodo del árbol de afuera (§ 8.1).
enum MetaEffect { oro, pocion, eter, atributo, mejora, repertorio, sinergia }

/// Un nodo del árbol de afuera: se compra con la moneda de la Travesía y
/// vale al empezar cada run.
class MetaNode {
  const MetaNode(this.id, this.name, this.cost, this.effect,
      {this.amount = 0, this.attribute, this.boon, this.requires, this.pair});

  final String id;
  final String name;
  final int cost;
  final MetaEffect effect;
  final int amount;
  final Attribute? attribute;

  /// Mejora directa con la que se arranca (o la que da la sinergia).
  final RunBoon? boon;

  /// Nodo que hay que tener antes.
  final String? requires;

  /// Sinergia de loadout: tipos de las dos habilidades de arranque.
  final (SkillKind, SkillKind)? pair;

  String get text => switch (effect) {
        MetaEffect.oro => '+$amount de oro al empezar',
        MetaEffect.pocion => '+$amount poción al empezar',
        MetaEffect.eter => '+$amount Éter al empezar',
        MetaEffect.atributo => '+$amount ${_attrName(attribute!)} al empezar',
        MetaEffect.mejora => 'Empezás con: ${boon!.text}',
        MetaEffect.repertorio => 'Suma una habilidad más al loadout',
        MetaEffect.sinergia => 'Si arrancás con ${_pairText(pair!)}: '
            '${boon!.text}',
      };

  static String _attrName(Attribute a) => switch (a) {
        Attribute.vit => 'Vitalidad',
        Attribute.fue => 'Fuerza',
        Attribute.esp => 'Espíritu',
        Attribute.des => 'Destreza',
        Attribute.agi => 'Agilidad',
      };

  static String _kindName(SkillKind k) => switch (k) {
        SkillKind.physical => 'física',
        SkillKind.magical => 'mágica',
        SkillKind.heal || SkillKind.regen => 'de cura',
        _ => 'de apoyo',
      };

  static String _pairText((SkillKind, SkillKind) p) => p.$1 == p.$2
      ? 'dos habilidades ${_kindName(p.$1)}s'
      : 'una habilidad ${_kindName(p.$1)} y una ${_kindName(p.$2)}';
}

/// El árbol de afuera (igual para todas las clases; se compra por
/// personaje).
const kMetaNodes = <MetaNode>[
  MetaNode('bolsa', 'Bolsa de viaje', 10, MetaEffect.oro, amount: 30),
  MetaNode('reserva', 'Reserva', 10, MetaEffect.pocion, amount: 1),
  MetaNode('temple', 'Temple', 15, MetaEffect.atributo,
      amount: 2, attribute: Attribute.vit),
  MetaNode('brazo', 'Brazo firme', 15, MetaEffect.atributo,
      amount: 2, attribute: Attribute.fue),
  MetaNode('mente', 'Mente clara', 15, MetaEffect.atributo,
      amount: 2, attribute: Attribute.esp),
  MetaNode('pulso_fino', 'Mano precisa', 15, MetaEffect.atributo,
      amount: 2, attribute: Attribute.des),
  MetaNode('frasco', 'Frasco de Éter', 20, MetaEffect.eter,
      amount: 1, requires: 'reserva'),
  MetaNode('repertorio1', 'Repertorio', 20, MetaEffect.repertorio),
  MetaNode('repertorio2', 'Repertorio antiguo', 30, MetaEffect.repertorio,
      requires: 'repertorio1'),
  MetaNode('doble_filo', 'Doble filo', 25, MetaEffect.sinergia,
      boon: RunBoon.ataque, pair: (SkillKind.physical, SkillKind.physical)),
  MetaNode('doble_conjuro', 'Doble conjuro', 25, MetaEffect.sinergia,
      boon: RunBoon.hechizos, pair: (SkillKind.magical, SkillKind.magical)),
  MetaNode('mano_y_rezo', 'Mano y rezo', 25, MetaEffect.sinergia,
      boon: RunBoon.curas, pair: (SkillKind.physical, SkillKind.heal)),
  MetaNode('bolsa_honda', 'Bolsa honda', 25, MetaEffect.oro,
      amount: 40, requires: 'bolsa'),
  MetaNode('eco_inicial', 'Eco del arranque', 35, MetaEffect.mejora,
      boon: RunBoon.pulso, requires: 'repertorio1'),
];

/// Progreso entre runs de la Travesía (docs/specs/roguelike.md § 8):
/// árbol de afuera, loadout, moneda, zonas, élites y dificultad. Puro.
class MetaProgressRules {
  const MetaProgressRules({required this.catalog});

  final GameCatalog catalog;

  static TuningDef get _t => tuning(TuningId.travesia);

  /// Casilleros del loadout.
  static const loadoutSlots = 2;

  /// Tamaño del pool de loadout por clase y cuántas vienen abiertas.
  static const poolSize = 5;
  static const poolOpen = 3;

  static MetaNode? node(String id) {
    for (final n in kMetaNodes) {
      if (n.id == id) return n;
    }
    return null;
  }

  /// El pool de habilidades de arranque de [classId]: las de las armas
  /// tempranas de su clase (hasta [loadoutMaxLevel]) que no trae
  /// el arma inicial, en orden de nivel del arma; las primeras
  /// [poolOpen] abiertas y el resto con Repertorio.
  /// Nivel máximo de las armas de donde sale el pool de arranque.
  static const loadoutMaxLevel = 9;

  List<String> loadoutPool(String classId, List<String> startSkills) {
    final cls = catalog.classes[classId];
    if (cls == null) return const [];
    final types = cls.allowedWeaponTypes.toSet();
    final ws = [
      for (final w in catalog.weapons.values)
        if (w.price > 0 &&
            types.contains(w.type) &&
            w.level <= loadoutMaxLevel)
          w,
    ]..sort((a, b) =>
        a.level != b.level ? a.level.compareTo(b.level) : a.id.compareTo(b.id));
    final out = <String>[];
    for (final w in ws) {
      for (final s in w.skillIds) {
        final sk = catalog.skills[s];
        if (sk == null ||
            startSkills.contains(s) ||
            out.contains(s) ||
            sk.kind == SkillKind.taunt) {
          continue;
        }
        out.add(s);
        if (out.length == poolSize) return out;
      }
    }
    return out;
  }

  /// Cuántas del pool están abiertas con los nodos [nodes].
  static int openCount(Set<String> nodes) =>
      poolOpen +
      kMetaNodes
          .where((n) => n.effect == MetaEffect.repertorio && nodes.contains(n.id))
          .length;

  /// Si [c] puede comprar [n] con [coins]; el motivo si no.
  static String? cantBuy(MetaNode n, TravesiaCharMeta c, int coins) {
    if (c.nodes.contains(n.id)) return 'Ya lo tenés';
    if (n.requires != null && !c.nodes.contains(n.requires)) {
      return 'Pide ${node(n.requires!)?.name ?? n.requires}';
    }
    if (coins < n.cost) return 'Faltan ${n.cost - coins} Ecos';
    return null;
  }

  /// Compra [id] para el personaje [key]; `null` si no se puede.
  static TravesiaMeta? buy(TravesiaMeta m, String key, String id) {
    final n = node(id);
    final c = m.charOf(key);
    if (n == null || cantBuy(n, c, m.coins) != null) return null;
    return m
        .copyWith(coins: m.coins - n.cost)
        .withChar(key, c.copyWith(nodes: {...c.nodes, id}));
  }

  /// Elige el loadout (hasta [loadoutSlots] del pool abierto).
  TravesiaMeta? setLoadout(TravesiaMeta m, String key, String classId,
      List<String> startSkills, List<String> skills) {
    final c = m.charOf(key);
    final pool = loadoutPool(classId, startSkills);
    final open = pool.take(openCount(c.nodes)).toSet();
    if (skills.length > loadoutSlots ||
        skills.toSet().length != skills.length ||
        !skills.every(open.contains)) {
      return null;
    }
    return m.withChar(key, c.copyWith(loadout: skills));
  }

  /// Lo que el personaje [key] trae a la run.
  RunPrep prepOf(TravesiaMeta m, String key, String classId,
      List<String> startSkills) {
    final c = m.charOf(key);
    final pool = loadoutPool(classId, startSkills);
    final open = pool.take(openCount(c.nodes)).toSet();
    final skills = [
      for (final s in c.loadout)
        if (open.contains(s)) s
    ].take(loadoutSlots).toList();
    var gold = 0, potions = 0, ethers = 0;
    final attrs = <Attribute, int>{};
    final boons = <String>[];
    final kinds = [
      for (final s in skills) catalog.skills[s]?.kind,
    ];
    SkillKind? norm(SkillKind? k) =>
        k == SkillKind.regen ? SkillKind.heal : k;
    for (final n in kMetaNodes) {
      if (!c.nodes.contains(n.id)) continue;
      switch (n.effect) {
        case MetaEffect.oro:
          gold += n.amount;
        case MetaEffect.pocion:
          potions += n.amount;
        case MetaEffect.eter:
          ethers += n.amount;
        case MetaEffect.atributo:
          attrs[n.attribute!] = (attrs[n.attribute!] ?? 0) + n.amount;
        case MetaEffect.mejora:
          boons.add(n.boon!.name);
        case MetaEffect.repertorio:
          break;
        case MetaEffect.sinergia:
          if (kinds.length == 2) {
            final (a, b) = n.pair!;
            final k0 = norm(kinds[0]), k1 = norm(kinds[1]);
            if ((k0 == a && k1 == b) || (k0 == b && k1 == a)) {
              boons.add(n.boon!.name);
            }
          }
      }
    }
    return RunPrep(
      skills: skills,
      gold: gold,
      potions: potions,
      ethers: ethers,
      attributes: attrs,
      boons: boons,
    );
  }

  // ---------------- fin de la run ----------------

  /// Moneda que da [r] (terminada): pisos alcanzados, élites, jefes y la
  /// victoria.
  static int coinsOf(RunState r) =>
      (r.floor + 1) * _t.i('coinPerFloor') +
      r.elitesBeaten.length * _t.i('coinElite') +
      r.bossesBeaten * _t.i('coinBoss') +
      (r.victory == true ? _t.i('coinWin') : 0);

  /// Cobra la run [r] (una vez por semilla): moneda, zona nueva si llegó
  /// al piso pedido, élites vencidas y dificultad nueva si ganó en la
  /// más alta.
  static TravesiaMeta settle(TravesiaMeta m, RunState r,
      {required int playableZones}) {
    if (r.phase != RunPhase.over || m.lastSeed == r.seed) return m;
    final start = _t.i('zonesStart');
    final reached = r.floor + 1 >= _t.i('zoneUnlockFloor');
    final zones = reached
        ? math.min(math.max(0, playableZones - start), m.zones + 1)
        : m.zones;
    final elites = {...m.eliteWins};
    for (final e in r.elitesBeaten) {
      elites[e] = (elites[e] ?? 0) + 1;
    }
    final won = r.victory == true;
    final unlocked = won && r.difficulty >= m.difficultyUnlocked
        ? math.min(_t.i('diffMax'), m.difficultyUnlocked + 1)
        : m.difficultyUnlocked;
    return m.copyWith(
      coins: m.coins + coinsOf(r),
      zones: zones,
      eliteWins: elites,
      difficultyUnlocked: unlocked,
      runs: m.runs + 1,
      wins: m.wins + (won ? 1 : 0),
      lastSeed: r.seed,
    );
  }

  /// Multiplicadores de vida y ATQ enemigos de la dificultad [d] (§ 8.2).
  /// Incluye la base de la Travesía (`enemyHp` / `enemyAtk`).
  static (double, double) difficultyMults(int d) => (
        _t.d('enemyHp') * (1 + _t.d('diffHp') * d),
        _t.d('enemyAtk') * (1 + _t.d('diffAtk') * d),
      );
}
