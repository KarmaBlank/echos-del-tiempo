import '../../../game_engine/models/build_plan.dart';
import '../../../game_engine/models/build_wants.dart';
import '../../../game_engine/models/item.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/rules/build_plan_rules.dart';
import '../../characters/domain/stash.dart';

/// Resumen del plan para el anfitrión (build_planner.md § 6 y
/// build_planner_v2.md § 1.4): con el objetivo principal y el % de tu
/// mejor candidata (inventario + alijo), calculado igual que el host
/// (sin estadísticas), para `BuildMejora`.
BuildWants buildWantsOf(BuildPlanRules rules, BuildPlan plan,
    PlayerProfile? profile, {List<ItemInstance> stash = const []}) {
  final t = plan.mainTarget;
  var best = 0;
  if (t != null && profile != null) {
    final tr = rules.targets;
    for (final it in [...profile.items, ...stash]) {
      final s = (tr.score(t, it) * 100).round();
      if (s > best) best = s;
    }
  }
  return BuildWants.fromPlan(plan, best: best);
}

/// Armas del alijo compartido ([stash] `null` = sin alijo cargado).
List<ItemInstance> stashWeapons(Stash? stash) => [
      for (final c in stash?.cells ?? const <StashEntry?>[])
        if (c?.item case final it?) it,
    ];
