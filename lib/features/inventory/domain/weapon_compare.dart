import '../../../game_engine/data/branch_ults_catalog.dart' show itemUlt;
import '../../../game_engine/data/weapon_elements_catalog.dart';
import '../../../game_engine/models/attributes.dart';
import '../../../game_engine/models/elements.dart';
import '../../../game_engine/models/item.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/models/player_state.dart';
import '../../../game_engine/rules/progression_rules.dart';
import '../../../game_engine/rules/weapon_weight.dart';
import 'shop_preview.dart';

/// Comparación de dos armas para el jugador local: stats finales con A y
/// con B (vistas previas del motor sobre una build hipotética) y qué
/// cambia (habilidades, mods, pasiva, ULT, requisitos). Dart puro: la UI
/// solo la dibuja. Ver docs/specs/panels.md § "Comparar armas".

/// Un stat derivado antes (con A) y después (con B).
class StatDelta {
  const StatDelta(this.label, this.before, this.after,
      {this.kind = StatFormat.integer, this.higherIsBetter = true});

  final String label;
  final num before;
  final num after;
  final StatFormat kind;

  /// `false` en el peso: menos es mejor (▲ verde si baja).
  final bool higherIsBetter;

  num get diff => after - before;
  bool get changed => diff.abs() > 1e-6;
  bool get better => higherIsBetter ? diff > 0 : diff < 0;

  String format(num x) => switch (kind) {
        StatFormat.integer => '${x.round()}',
        StatFormat.decimal => x.toStringAsFixed(1),
        StatFormat.percent => '${(x * 100).round()}%',
      };

  /// `+9`, `-0.5`, `+3%`.
  String get diffText {
    final d = diff;
    final sign = d > 0 ? '+' : '-';
    return switch (kind) {
      StatFormat.integer => '$sign${d.abs().round()}',
      StatFormat.decimal => '$sign${d.abs().toStringAsFixed(1)}',
      StatFormat.percent => '$sign${(d.abs() * 100).round()}%',
    };
  }
}

enum StatFormat { integer, decimal, percent }

/// Resultado de [compareWeapons].
class WeaponComparison {
  const WeaponComparison({
    required this.from,
    required this.to,
    required this.before,
    required this.after,
    required this.stats,
    required this.skillsGained,
    required this.skillsLost,
    required this.modsGained,
    required this.modsLost,
    required this.passiveBefore,
    required this.passiveAfter,
    required this.ultBefore,
    required this.ultAfter,
    required this.meetsRequirements,
    this.weightBefore,
    this.weightAfter,
  });

  /// Arma de partida (A) y candidata (B).
  final ItemInstance? from;
  final ItemInstance to;

  /// Stats finales con A y con B.
  final DerivedStats before;
  final DerivedStats after;

  /// ATQ, MAG, Crítico, VEL, Peso, Vida, Maná, DEF.
  final List<StatDelta> stats;

  /// Nombres de habilidades (del arma) que B trae y A no, y al revés.
  final List<String> skillsGained;
  final List<String> skillsLost;

  /// Mods con su tier (`+12% ATQ (T3)`).
  final List<String> modsGained;
  final List<String> modsLost;

  /// `nombre nivel: efecto` o `null`.
  final String? passiveBefore;
  final String? passiveAfter;

  /// Nombre de la ULT del tipo de cada arma.
  final String? ultBefore;
  final String? ultAfter;

  /// Si el jugador cumple nivel y requisitos de B.
  final bool meetsRequirements;

  /// Peso de la base de A y de B (`null` sin arma / base desconocida).
  final double? weightBefore;
  final double? weightAfter;

  /// Categoría de peso de A y de B (sin arma: Ligera).
  WeightClass get weightClassBefore => weightClassFor(weightBefore ?? 0);
  WeightClass get weightClassAfter => weightClassFor(weightAfter ?? 0);
  bool get weightClassChanged => weightClassBefore != weightClassAfter;

  bool get same => identical(from, to) || from == to;
  bool get passiveChanged => passiveBefore != passiveAfter;
  bool get ultChanged => ultBefore != ultAfter;

  /// Elemento de base de A y de B (weapon_identity.md § 4).
  GameElement? get elementBefore => weaponElementOf(from);
  GameElement? get elementAfter => weaponElementOf(to);
  bool get elementChanged => elementBefore != elementAfter;
}

/// Compara usar [from] (por defecto, el arma que [viewer] realmente usa)
/// con usar [to], para [viewer] con [attributes] (su reparto pendiente;
/// por defecto, los suyos). [from] y [to] pueden ser de cualquier dueño:
/// se calculan sobre una build hipotética de [viewer].
WeaponComparison compareWeapons(
  ProgressionRules rules,
  PlayerProfile viewer, {
  ItemInstance? from,
  required ItemInstance to,
  PlayerAttributes? attributes,
}) {
  final preview = ShopPreview(rules);
  final a = from ?? rules.equippedItem(viewer);
  final usingA = from == null;
  final before = usingA
      ? preview.current(viewer, attributes: attributes)
      : preview.withItem(viewer, a!, attributes: attributes);
  final after = preview.withItem(viewer, to, attributes: attributes);
  final items = rules.items;
  final cat = rules.catalog;

  final skA = a == null ? const <String>[] : items.skillsOf(a);
  final skB = items.skillsOf(to);
  String sName(String id) => cat.skills[id]?.name ?? id;

  final modsA = a == null
      ? const <String>[]
      : [for (final r in a.affixes) items.affixText(r, on: a)];
  final modsB = [for (final r in to.affixes) items.affixText(r, on: to)];

  String? ult(ItemInstance? i) {
    final w = i == null ? null : items.baseOf(i);
    return w == null ? null : (itemUlt(i!) ?? cat.ultimates[w.type])?.name;
  }

  final wA = a == null ? null : items.baseOf(a);
  final wB = items.baseOf(to);
  return WeaponComparison(
    from: a,
    to: to,
    before: before,
    after: after,
    stats: [
      StatDelta('ATQ', before.attack, after.attack),
      StatDelta('MAG', before.magic, after.magic),
      StatDelta('Crítico', before.critChance, after.critChance,
          kind: StatFormat.percent),
      StatDelta('VEL', before.speed, after.speed, kind: StatFormat.decimal),
      StatDelta('Peso', wA?.weight ?? 0, wB?.weight ?? 0,
          kind: StatFormat.decimal, higherIsBetter: false),
      StatDelta('Vida', before.maxHp, after.maxHp),
      StatDelta('Maná', before.maxMp, after.maxMp),
      StatDelta('DEF', before.defense, after.defense),
    ],
    skillsGained: [
      for (final s in skB)
        if (!skA.contains(s)) sName(s)
    ],
    skillsLost: [
      for (final s in skA)
        if (!skB.contains(s)) sName(s)
    ],
    modsGained: _minus(modsB, modsA),
    modsLost: _minus(modsA, modsB),
    passiveBefore: a == null ? null : items.passiveText(a),
    passiveAfter: items.passiveText(to),
    ultBefore: ult(a),
    ultAfter: ult(to),
    meetsRequirements: wB != null &&
        rules.meetsRequirements(viewer, wB, attributes: attributes),
    weightBefore: wA?.weight,
    weightAfter: wB?.weight,
  );
}

/// [a] menos [b] como multiconjuntos (conserva el orden de [a]).
List<String> _minus(List<String> a, List<String> b) {
  final left = [...b];
  return [
    for (final x in a)
      if (!left.remove(x)) x,
  ];
}

/// Stats de la franja de cambios (panels.md § "Inventario", v0.9.13), en
/// orden ATQ, MAG, CRÍT, VEL, Vida, Maná, DEF, Peso con rótulos cortos:
/// usar [to] en vez de la equipada, o sin [to] los valores actuales
/// (`before == after`).
List<StatDelta> stripStats(ProgressionRules rules, PlayerProfile viewer,
    {ItemInstance? to, PlayerAttributes? attributes}) {
  final List<StatDelta> base;
  if (to != null) {
    base = compareWeapons(rules, viewer, to: to, attributes: attributes).stats;
  } else {
    final eq = rules.equippedItem(viewer);
    final now = ShopPreview(rules).current(viewer, attributes: attributes);
    final w = eq == null ? 0.0 : rules.items.baseOf(eq)?.weight ?? 0.0;
    base = [
      StatDelta('ATQ', now.attack, now.attack),
      StatDelta('MAG', now.magic, now.magic),
      StatDelta('Crítico', now.critChance, now.critChance,
          kind: StatFormat.percent),
      StatDelta('VEL', now.speed, now.speed, kind: StatFormat.decimal),
      StatDelta('Peso', w, w, kind: StatFormat.decimal, higherIsBetter: false),
      StatDelta('Vida', now.maxHp, now.maxHp),
      StatDelta('Maná', now.maxMp, now.maxMp),
      StatDelta('DEF', now.defense, now.defense),
    ];
  }
  const order = ['ATQ', 'MAG', 'Crítico', 'VEL', 'Vida', 'Maná', 'DEF', 'Peso'];
  final by = {for (final s in base) s.label: s};
  return [
    for (final l in order)
      if (by[l] case final s?)
        StatDelta(l == 'Crítico' ? 'CRÍT' : l, s.before, s.after,
            kind: s.kind, higherIsBetter: s.higherIsBetter),
  ];
}
