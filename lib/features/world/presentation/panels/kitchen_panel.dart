import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/panel_frame.dart';
import '../session_controller.dart';
import '../session_view.dart';
import '../world_strings.dart';
import 'cooking_view.dart';

/// The cooking screen (farming.md § 17) with its RECETAS / COMIDAS /
/// COLECCIÓN subtabs (the shared [CookingView] organism). Reusable: every
/// cooking spot (the town COCINA building, the player house's kitchen
/// furniture) opens it through `SessionController.openKitchen()`, which
/// shows this panel for `WorldPanel.kitchen`; it only needs the view and
/// the controller. Every player in town can use it; the
/// host validates each `FarmShopOp.cook` / `eat` / `giveMeal`.
class KitchenPanel extends StatelessWidget {
  const KitchenPanel({super.key, required this.view, required this.controller});

  final SessionView view;
  final SessionController controller;

  @override
  Widget build(BuildContext context) {
    final me = view.me;
    final close = view.mustAllocate ? null : controller.closePanel;
    return PanelFrame(
      key: const ValueKey('panel-kitchen'),
      title: context.t('ui.world.kitchen.title'),
      width: 1000,
      fill: true,
      help: context.t('ui.world.kitchen.help'),
      onClose: close,
      actions: [
        PanelButton(context.t('ui.world.kitchen.close'), onPressed: close),
      ],
      child: me == null
          ? const SizedBox.shrink()
          : CookingView(
              key: ValueKey('kitchen-cooking-${me.id}'),
              profile: me.profile,
              controller: controller),
    );
  }
}
