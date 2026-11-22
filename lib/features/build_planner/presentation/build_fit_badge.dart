import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/design/ds_components.dart';
import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../game_engine/models/build_plan.dart';
import '../../../game_engine/models/item.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/rules/build_guide_rules.dart';
import '../../../game_engine/rules/build_plan_rules.dart';
import '../../world/presentation/session_controller.dart';
import 'build_plan_providers.dart';

/// Color de lo que es "de tu build" (★, anillo del árbol, barras).
const kPlanColor = Color(0xFFC39BFF);
const kPlanHex = '#c39bff';

/// Las reglas del planificador sobre las de la sesión.
final buildPlanRulesProvider = Provider<BuildPlanRules>(
    (ref) => BuildPlanRules(ref.watch(sessionEngineProvider).progression));

/// Lo que [item] cumple del plan (o, con [before], lo que agrega
/// respecto de [before]: vista previa de la fusión).
ItemFit buildFitOf(BuildPlanRules rules, BuildPlan plan, ItemInstance item,
        {ItemInstance? before}) =>
    before == null
        ? rules.itemFit(plan, item)
        : rules.advances(plan, before, item);

/// Línea de ficha (markup) "★ Tu build — Cumple: ... · casi: ..." o
/// `null` si el arma no toca el plan.
String? buildFitMarkup(ItemFit fit, {String lead = 'Cumple'}) {
  if (fit.isEmpty) return null;
  final parts = [
    if (fit.matches.isNotEmpty)
      '$lead: ${fit.matches.map(protoEsc).join(' · ')}',
    for (final n in fit.near) 'casi: ${protoEsc(n)}',
  ];
  return '<span style="color:$kPlanHex"><b>★ Tu build</b> — '
      '${parts.join(' · ')}</span>';
}

/// Insignia "★ Tu build" de un arma o de una acción de la fusión
/// (docs/specs/build_planner.md § 4.1): nada si no toca el plan; si no,
/// la ★ (o "★ TU BUILD" sin [compact]) con el detalle en el tooltip.
/// Con [before] muestra lo que la acción **agrega** ([item] = resultado).
class BuildFitBadge extends ConsumerWidget {
  const BuildFitBadge({
    super.key,
    required this.item,
    this.before,
    this.compact = true,
  });

  final ItemInstance? item;
  final ItemInstance? before;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final it = item;
    if (it == null) return const SizedBox.shrink();
    final plan = ref.watch(buildPlanProvider).plan;
    if (plan.goalCount == 0) return const SizedBox.shrink();
    final fit =
        buildFitOf(ref.watch(buildPlanRulesProvider), plan, it, before: before);
    if (!fit.any) return const SizedBox.shrink();
    final tip =
        buildFitMarkup(fit, lead: before == null ? 'Cumple' : 'Avanza')!;
    return RetroTooltip(
      message: tip,
      child: Container(
        key: const ValueKey('build-fit-badge'),
        padding: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          border:
              Border.all(color: kPlanColor, width: RetroTheme.thinBorderWidth),
        ),
        child: Text(compact ? '★' : '★ TU BUILD',
            style: const TextStyle(color: kPlanColor, height: 1.1)),
      ),
    );
  }
}

/// Marca "PARA TU BUILD" / "NO VA CON TU BUILD" de una habilidad
/// ([skillId]) o pasiva ([passiveId]) a trasladar en la fusión
/// (build_planner.md § 9.6). Sin plan, nada. El motivo va en el tooltip.
class TransferFitMark extends ConsumerWidget {
  const TransferFitMark(
      {super.key, required this.profile, this.skillId, this.passiveId})
      : assert((skillId == null) != (passiveId == null));

  final PlayerProfile profile;
  final String? skillId;
  final String? passiveId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(buildPlanProvider).plan;
    final viewer = profile;
    final guide =
        BuildGuideRules(ref.watch(buildPlanRulesProvider).progression);
    final fit = skillId != null
        ? guide.skillFit(plan, viewer, skillId!)
        : guide.passiveFit(plan, viewer, passiveId!);
    if (fit == null) return const SizedBox.shrink();
    return RetroTooltip(
      message: protoEsc(fit.reason),
      child: DsTag.buildFit(fit.fits,
          key: ValueKey('transfer-fit-${skillId ?? passiveId}')),
    );
  }
}
