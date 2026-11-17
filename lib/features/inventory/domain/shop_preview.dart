import 'dart:math' as math;

import '../../../game_engine/models/attributes.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/models/player_state.dart';
import '../../../game_engine/models/upgrade_stat.dart';
import '../../../game_engine/models/weapon.dart';
import '../../../game_engine/rules/progression_rules.dart';

/// Resultado de una fusión antes de confirmarla.
class FusePreview {
  const FusePreview({
    required this.baseId,
    required this.sacrificeId,
    required this.skillId,
    required this.skillIds,
    required this.replaces,
    required this.lostUpgrades,
    required this.lostFused,
  });

  final String baseId;
  final String sacrificeId;

  /// La habilidad heredada.
  final String skillId;

  /// Habilidades de la base después de fusionar (las del arma + la
  /// fusionada), en el orden de `skHtml`.
  final List<String> skillIds;

  /// La fusión anterior de la base que se pierde, si había.
  final String? replaces;

  /// Mejoras del arma sacrificada que se pierden.
  final WeaponUpgradeLevels lostUpgrades;

  /// Fusión propia del arma sacrificada que se pierde.
  final String? lostFused;
}

/// Vistas previas de la tienda: los stats con otra arma o con una mejora
/// más, y el resultado de una fusión. No valida nada (eso es de
/// [ProgressionRules] y de `ShopGuards`): aplica las reglas sobre un
/// perfil hipotético para mostrar el resultado antes de confirmar. Ver
/// docs/specs/panels.md § "Armería".
class ShopPreview {
  const ShopPreview(this.rules);

  final ProgressionRules rules;

  /// Stats derivados si [p] usara [weaponId] (con sus mejoras o
  /// [upgrades]) y los atributos [attributes] (por defecto, los suyos).
  DerivedStats statsWith(
    PlayerProfile p,
    String weaponId, {
    WeaponUpgradeLevels? upgrades,
    PlayerAttributes? attributes,
  }) {
    final w = rules.catalog.weapons[weaponId]!;
    return rules.stats.calculate(PlayerBuild(
      classId: p.classId,
      level: p.level,
      attributes: attributes ?? p.attributes,
      equippedWeapon: w,
      weaponUpgrades: upgrades ?? p.upgradesFor(weaponId),
      passiveProgress: p.passiveProgress,
    ));
  }

  /// Stats con el arma que hoy usa (como `derivedStats`), con
  /// [attributes] opcionales.
  DerivedStats current(PlayerProfile p, {PlayerAttributes? attributes}) =>
      rules.stats.calculate(rules.buildOf(p, attributes: attributes));

  /// Stats de [weaponId] antes y después de subir [stat] un nivel.
  ({DerivedStats before, DerivedStats after}) upgrade(
      PlayerProfile p, String weaponId, UpgradeStat stat) {
    final now = p.upgradesFor(weaponId);
    final l = now.level(stat);
    return (
      before: statsWith(p, weaponId),
      after: statsWith(p, weaponId,
          upgrades: now.withLevel(
              stat, math.min(l + 1, ProgressionRules.upgradeMax))),
    );
  }

  /// Lo que dejaría [ProgressionRules.fuse]. Los créditos no cuentan para
  /// la vista previa (el motivo `Faltan $N` lo da `ShopGuards`); `null` si
  /// la combinación no es válida.
  FusePreview? fuse(PlayerProfile p, String? baseId, String? sacrificeId,
      String? skillId) {
    if (baseId == null || sacrificeId == null || skillId == null) return null;
    final rich = p.copyWith(
        credits: math.max(p.credits, ProgressionRules.fuseCost));
    final next = rules.fuse(rich, baseId, sacrificeId, skillId);
    if (next == null) return null;
    final base = rules.catalog.weapons[baseId]!;
    final fused = next.fused[baseId];
    return FusePreview(
      baseId: baseId,
      sacrificeId: sacrificeId,
      skillId: skillId,
      skillIds: [
        ...base.skillIds,
        if (fused != null && !base.skillIds.contains(fused)) fused,
      ],
      replaces: p.fused[baseId] == skillId ? null : p.fused[baseId],
      lostUpgrades: p.upgradesFor(sacrificeId),
      lostFused: p.fused[sacrificeId],
    );
  }
}
