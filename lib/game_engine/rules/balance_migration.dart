import '../data/skills_catalog.dart';
import '../data/ascension_catalog.dart';
import '../models/item.dart';
import '../models/player_profile.dart';
import '../models/upgrade_stat.dart';
import 'craft_rules.dart';
import 'item_rules.dart';

/// Versión del balance con la que se guardó la cuenta (JSON `bv` de la
/// cuenta). 1 = rebalance por combos v0.9 (combo_balance.md § 6b). Las
/// cuentas sin `bv` son de antes (v0.8.x) y se migran una vez.
const kBalanceVersion = 1;

/// Lo que la migración cambió y devolvió, para el aviso único al cargar.
class BalanceRefund {
  const BalanceRefund({
    this.credits = 0,
    this.rescaledMods = 0,
    this.forgeLevels = 0,
    this.skills = 0,
  });

  /// Créditos devueltos (forja de más y fusiones inválidas).
  final int credits;

  /// Mods fijos de legendarias que bajaron al rango de su nivel.
  final int rescaledMods;

  /// Niveles de forja por encima del tope que se sacaron.
  final int forgeLevels;

  /// Habilidades trasladadas que ya no valen (ranura vaciada).
  final int skills;

  bool get isEmpty =>
      credits == 0 && rescaledMods == 0 && forgeLevels == 0 && skills == 0;

  BalanceRefund operator +(BalanceRefund o) => BalanceRefund(
        credits: credits + o.credits,
        rescaledMods: rescaledMods + o.rescaledMods,
        forgeLevels: forgeLevels + o.forgeLevels,
        skills: skills + o.skills,
      );

  /// Partes del aviso (`2 mods de legendarias ajustados a su nivel`…).
  List<String> get lines => [
        if (rescaledMods > 0)
          '$rescaledMods mod${rescaledMods == 1 ? '' : 's'} fijo'
              '${rescaledMods == 1 ? '' : 's'} de legendarias ajustado'
              '${rescaledMods == 1 ? '' : 's'} al nivel del arma',
        if (forgeLevels > 0)
          '$forgeLevels nivel${forgeLevels == 1 ? '' : 'es'} de forja por '
              'encima del tope nuevo',
        if (skills > 0)
          '$skills habilidad${skills == 1 ? '' : 'es'} trasladada'
              '${skills == 1 ? '' : 's'} que ya no vale'
              '${skills == 1 ? '' : 'n'} (ranura vaciada)',
        if (credits > 0) '₵$credits devueltos',
      ];
}

/// Migración de armas y perfiles al balance v0.9 (combo_balance.md § 6b).
/// Pura e idempotente: aplicarla a algo ya migrado no cambia nada.
class BalanceMigration {
  const BalanceMigration({this.craft = const CraftRules()});

  final CraftRules craft;

  ItemRules get items => craft.items;

  /// [i] migrada y lo que se devuelve:
  /// - mods fijos de legendaria: el valor baja al techo del rango a su
  ///   nivel de objeto ([ItemRules.fixedRangeAt]); nunca sube;
  /// - forja total por encima de [ItemRules.forgeCapOf]: se sacan niveles
  ///   (de la estadística más alta, empezando por el último nivel) y se
  ///   devuelve su costo ([CraftRules.forgeCost]);
  /// - habilidades trasladadas inválidas (desconocidas, de un kit de
  ///   ascensión, del motor, repetidas o de más para la rareza): se
  ///   sacan y se devuelve su traslado ([CraftRules.transferSkillCost]).
  (ItemInstance, BalanceRefund) migrateItem(ItemInstance i) {
    final w = items.baseOf(i);
    if (w == null) return (i, const BalanceRefund());
    var credits = 0, mods = 0, levels = 0, skills = 0;

    var affixes = i.affixes;
    if (i.rarity == Rarity.legendario) {
      affixes = [
        for (final a in i.affixes)
          if (a.fixed)
            switch (items.rangeOf(i, a)) {
              final r? when a.value > r.$2 => () {
                  mods++;
                  return a.withValue(r.$2);
                }(),
              _ => a,
            }
          else
            a,
      ];
    }

    var forge = i.forge;
    final cap = ItemRules.forgeCapOf(i);
    while (forge.total > cap) {
      UpgradeStat? top;
      for (final s in UpgradeStat.values) {
        if (forge.level(s) > 0 &&
            (top == null || forge.level(s) >= forge.level(top))) {
          top = s;
        }
      }
      if (top == null) break;
      final l = forge.level(top) - 1;
      credits += CraftRules.forgeCost(w, i.rarity, l);
      forge = forge.withLevel(top, l);
      levels++;
    }

    final kept = <String>[];
    for (final s in i.extraSkills) {
      final ok = craft.catalog.skills.containsKey(s) &&
          !kAscensionSkills.containsKey(s) &&
          !kEngineSkillIds.contains(s) &&
          !kept.contains(s) &&
          kept.length < i.rarity.skillSlots;
      if (ok) {
        kept.add(s);
      } else {
        skills++;
        credits += CraftRules.transferSkillCost(i.rarity);
      }
    }

    if (mods == 0 && levels == 0 && skills == 0) {
      return (i, const BalanceRefund());
    }
    return (
      i.copyWith(affixes: affixes, forge: forge, extraSkills: kept),
      BalanceRefund(
          credits: credits,
          rescaledMods: mods,
          forgeLevels: levels,
          skills: skills),
    );
  }

  /// Todas las armas de [p] migradas; los créditos devueltos se suman al
  /// perfil. Nivel, XP, atributos, materiales, árbol y ascensión no se
  /// tocan.
  (PlayerProfile, BalanceRefund) migrateProfile(PlayerProfile p) {
    var total = const BalanceRefund();
    final out = <ItemInstance>[];
    for (final i in p.items) {
      final (m, r) = migrateItem(i);
      out.add(m);
      total += r;
    }
    if (total.isEmpty) return (p, total);
    return (
      p.copyWith(items: out, credits: p.credits + total.credits),
      total,
    );
  }
}
