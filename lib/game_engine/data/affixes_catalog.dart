import '../models/item.dart';

// Pool de afijos de loot v2 (docs/specs/loot.md § 9). Cada tier dice
// desde qué nivel de objeto sale, su rango de valores (enteros, ver
// `ModStat.scale`) y su peso dentro del afijo.

const _p = AffixSlot.prefix;
const _s = AffixSlot.suffix;

/// Tipos con fórmula de MAG (usan % MAG, MAG plano y % curación).
const kMagicWeaponTypes = {
  'báculo',
  'tomo',
  'varita',
  'espada+escudo',
  'maza+escudo',
  'martillo+escudo',
};

/// Tipos con escudo (DEF).
const kShieldWeaponTypes = {'espada+escudo', 'maza+escudo', 'martillo+escudo'};

/// Tiers estándar de 5 escalones: T5 desde nivel 1, T4 10, T3 20, T2 30,
/// T1 40; pesos 100/80/60/40/20.
List<AffixTier> _five(List<(int, int)> ranges) => [
      for (var i = 0; i < 5; i++)
        AffixTier(i + 1, const [40, 30, 20, 10, 1][i], ranges[i].$1,
            ranges[i].$2, const [20, 40, 60, 80, 100][i]),
    ];

/// Afijos por id, en el orden de la tabla del spec.
final Map<String, AffixDef> kAffixes = {for (final a in _list) a.id: a};

final List<AffixDef> _list = [
  // ---------------- prefijos ----------------
  AffixDef(
      id: 'feroz', name: 'Feroz', slot: _p, stat: ModStat.atkPct, weight: 1000,
      tiers: _five([(33, 40), (25, 32), (17, 24), (10, 16), (5, 9)])),
  AffixDef(
      id: 'arcano', name: 'Arcano', slot: _p, stat: ModStat.magPct, weight: 1000,
      types: kMagicWeaponTypes,
      tiers: _five([(33, 40), (25, 32), (17, 24), (10, 16), (5, 9)])),
  AffixDef(
      id: 'afilado', name: 'Afilado', slot: _p, stat: ModStat.flatAtk, weight: 800,
      tiers: _five([(16, 22), (11, 15), (7, 10), (4, 6), (1, 3)])),
  AffixDef(
      id: 'runico', name: 'Rúnico', slot: _p, stat: ModStat.flatMag, weight: 800,
      types: kMagicWeaponTypes,
      tiers: _five([(16, 22), (11, 15), (7, 10), (4, 6), (1, 3)])),
  AffixDef(
      id: 'certero', name: 'Certero', slot: _p, stat: ModStat.critChance, weight: 700,
      tiers: _five([(10, 12), (8, 9), (6, 7), (4, 5), (2, 3)])),
  AffixDef(
      id: 'letal', name: 'Letal', slot: _p, stat: ModStat.critMulti, weight: 500,
      tiers: _five([(34, 42), (26, 33), (19, 25), (13, 18), (8, 12)])),
  AffixDef(
      id: 'veloz', name: 'Veloz', slot: _p, stat: ModStat.speed, weight: 600,
      tiers: _five([(9, 11), (7, 8), (5, 6), (3, 4), (1, 2)])),
  const AffixDef(
      id: 'abrasador', name: 'Abrasador', slot: _p, stat: ModStat.burnStacks, weight: 300,
      types: {'espada', 'hacha', 'lanza', 'báculo', 'varita', 'arco', 'ballesta'},
      tiers: [AffixTier(1, 36, 2, 2, 40), AffixTier(2, 12, 1, 1, 100)]),
  const AffixDef(
      id: 'ponzonoso', name: 'Ponzoñoso', slot: _p, stat: ModStat.poisonStacks, weight: 300,
      types: {'hacha', 'tomo', 'arco', 'rifle', 'dagas', 'ballesta'},
      tiers: [AffixTier(1, 36, 2, 2, 40), AffixTier(2, 12, 1, 1, 100)]),
  const AffixDef(
      id: 'gelido', name: 'Gélido', slot: _p, stat: ModStat.freezeStacks, weight: 300,
      types: {'báculo', 'tomo', 'varita', 'rifle'},
      tiers: [AffixTier(1, 36, 2, 2, 40), AffixTier(2, 12, 1, 1, 100)]),
  AffixDef(
      id: 'impetuoso', name: 'Impetuoso', slot: _p, stat: ModStat.ultCharge, weight: 500,
      tiers: _five([(18, 22), (14, 17), (10, 13), (7, 9), (4, 6)])),
  // Quiebre v0.9 (combo_balance.md § 5): +10% a +30% de puntos.
  AffixDef(
      id: 'rompedor', name: 'Rompedor', slot: _p, stat: ModStat.breakPower, weight: 400,
      tiers: _five([(26, 30), (21, 25), (16, 20), (13, 15), (10, 12)])),
  // Quebrantador v0.9.1 (combo_balance.md § 5.3): la habilidad principal
  // del arma "Puede quebrar". Un solo tier desde nivel 10, poco frecuente.
  // No sale en maza+escudo (varias bases sin habilidad de daño).
  const AffixDef(
      id: 'quebrantador', name: 'Quebrantador', slot: _p, stat: ModStat.breakSkill, weight: 150,
      types: {'espada', 'hacha', 'lanza', 'espada+escudo', 'martillo+escudo', 'arco', 'ballesta', 'rifle', 'dagas', 'báculo', 'varita', 'tomo'},
      tiers: [AffixTier(1, 10, 1, 1, 100)]),
  // ---------------- sufijos ----------------
  AffixDef(
      id: 'del_oso', name: 'del Oso', slot: _s, stat: ModStat.vit, weight: 900,
      tiers: _five([(16, 20), (12, 15), (8, 11), (5, 7), (2, 4)])),
  AffixDef(
      id: 'del_sabio', name: 'del Sabio', slot: _s, stat: ModStat.esp, weight: 900,
      tiers: _five([(16, 20), (12, 15), (8, 11), (5, 7), (2, 4)])),
  AffixDef(
      id: 'del_zorro', name: 'del Zorro', slot: _s, stat: ModStat.agi, weight: 900,
      tiers: _five([(16, 20), (12, 15), (8, 11), (5, 7), (2, 4)])),
  AffixDef(
      id: 'del_toro', name: 'del Toro', slot: _s, stat: ModStat.fue, weight: 900,
      tiers: _five([(16, 20), (12, 15), (8, 11), (5, 7), (2, 4)])),
  AffixDef(
      id: 'del_halcon', name: 'del Halcón', slot: _s, stat: ModStat.des, weight: 900,
      tiers: _five([(16, 20), (12, 15), (8, 11), (5, 7), (2, 4)])),
  AffixDef(
      id: 'de_la_vida', name: 'de la Vida', slot: _s, stat: ModStat.maxHp, weight: 1000,
      tiers: _five([(66, 90), (46, 65), (29, 45), (16, 28), (8, 15)])),
  AffixDef(
      id: 'del_eter', name: 'del Éter', slot: _s, stat: ModStat.maxMp, weight: 800,
      tiers: _five([(21, 28), (15, 20), (10, 14), (6, 9), (3, 5)])),
  AffixDef(
      id: 'del_baluarte', name: 'del Baluarte', slot: _s, stat: ModStat.defense, weight: 800,
      types: kShieldWeaponTypes,
      tiers: _five([(6, 7), (4, 5), (3, 3), (2, 2), (1, 1)])),
  AffixDef(
      id: 'de_la_gracia', name: 'de la Gracia', slot: _s, stat: ModStat.healReceived, weight: 500,
      tiers: _five([(23, 28), (18, 22), (13, 17), (9, 12), (5, 8)])),
  const AffixDef(
      id: 'del_renacer', name: 'del Renacer', slot: _s, stat: ModStat.regen, weight: 300,
      tiers: [AffixTier(1, 40, 3, 3, 30), AffixTier(2, 25, 2, 2, 60), AffixTier(3, 10, 1, 1, 100)]),
  const AffixDef(
      id: 'de_la_pureza', name: 'de la Pureza', slot: _s, stat: ModStat.statusResist, weight: 300,
      tiers: [AffixTier(1, 40, 2, 2, 40), AffixTier(2, 15, 1, 1, 100)]),
  const AffixDef(
      id: 'del_vampiro', name: 'del Vampiro', slot: _s, stat: ModStat.lifeSteal, weight: 400,
      tiers: [
        AffixTier(1, 40, 5, 6, 20),
        AffixTier(2, 25, 4, 4, 40),
        AffixTier(3, 15, 3, 3, 60),
        AffixTier(4, 5, 1, 2, 100),
      ]),
  AffixDef(
      id: 'de_la_fe', name: 'de la Fe', slot: _s, stat: ModStat.healPower, weight: 600,
      types: kMagicWeaponTypes,
      tiers: _five([(25, 30), (19, 24), (14, 18), (9, 13), (5, 8)])),
  // ---- Invocador v0.8.1 (docs/specs/summoner.md § 2): solo tomos ----
  AffixDef(
      id: 'evocador', name: 'Evocador', slot: _p, stat: ModStat.summonDamage, weight: 400,
      types: const {'tomo'},
      tiers: _five([(21, 25), (16, 20), (11, 15), (7, 10), (3, 6)])),
  const AffixDef(
      id: 'del_pacto', name: 'del Pacto', slot: _s, stat: ModStat.summonTurns, weight: 300,
      types: {'tomo'},
      tiers: [AffixTier(1, 20, 1, 1, 100)]),
];
