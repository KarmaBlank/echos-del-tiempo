import 'package:material_ui/material_ui.dart';

import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/panel_widgets.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../app/widgets/menu_focus.dart';
import '../../world/presentation/session_controller.dart';
import '../../world/presentation/panels/party_member_bar.dart';
import '../../world/presentation/session_view.dart';
import 'inventory_strings.dart';
import 'shop_sections.dart';

/// ARMERÍA del pueblo (v0.32.3): COMPRAR · VENDER · CONSUMIBLES. Ver
/// docs/specs/panels.md § "Armería".
class ArmoryPanel extends StatelessWidget {
  const ArmoryPanel({
    super.key,
    required this.view,
    required this.controller,
    this.initialTab = ArmoryTab.buy,
  });

  final SessionView view;
  final SessionController controller;
  final ArmoryTab initialTab;

  @override
  Widget build(BuildContext context) => ShopTabsPanel(
      view: view,
      controller: controller,
      title: invStrings(context).t('ui.inventory.armory.title'),
      help: shopHelp(invStrings(context)),
      tabs: ArmoryTab.values,
      initial: initialTab.index);
}

/// FORJA del pueblo (v0.32.3): MEJORAR · CONDENSAR · FUSIÓN. Ver
/// docs/specs/panels.md § "Forja".
class ForgePanel extends StatelessWidget {
  const ForgePanel({
    super.key,
    required this.view,
    required this.controller,
    this.initialTab = ForgeHallTab.upgrade,
  });

  final SessionView view;
  final SessionController controller;
  final ForgeHallTab initialTab;

  @override
  Widget build(BuildContext context) => ShopTabsPanel(
      view: view,
      controller: controller,
      title: invStrings(context).t('ui.inventory.armory.forge_title'),
      help: forgeHelp(invStrings(context)),
      tabs: ForgeHallTab.values,
      initial: initialTab.index);
}

/// Organismo común de la ARMERÍA y la FORJA: marco, pestañas, línea "qué
/// hace" y el contenido de la pestaña.
class ShopTabsPanel extends StatefulWidget {
  const ShopTabsPanel({
    super.key,
    required this.view,
    required this.controller,
    required this.title,
    required this.help,
    required this.tabs,
    this.initial = 0,
  });

  final SessionView view;
  final SessionController controller;
  final String title;
  final String help;
  final List<ShopTabDef> tabs;
  final int initial;

  @override
  State<ShopTabsPanel> createState() => _ShopTabsPanelState();
}

class _ShopTabsPanelState extends State<ShopTabsPanel> {
  late var _tab = widget.initial;

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    final controller = widget.controller;
    final shop = ShopContext(view, controller);
    final p = shop.profile;
    final tab = widget.tabs[_tab];
    final close = view.mustAllocate ? null : controller.closePanel;
    final s = invStrings(context);
    // Q / E, Ctrl+Tab y 1-4 cambian de pestaña (menu_focus.dart).
    return PartyMemberKeys(
      view: view,
      controller: controller,
      child: MenuTabKeys(
        count: widget.tabs.length,
        index: _tab,
        onChanged: (i) => setState(() => _tab = i),
        child: PanelFrame(
          title: widget.title,
          width: 1200,
          fill: true,
          help: widget.help,
          onClose: close,
          titleTrailing: ProtoText(s.t('ui.inventory.armory.credits_class', {
            'credits': '₵${p.credits}',
            'class': protoEsc(shop.className()),
          })),
          header: PartyMemberBar.header(
              view,
              controller,
              PanelTabs(
                labels: [for (final t in widget.tabs) t.label(s)],
                index: _tab,
                onChanged: (i) => setState(() => _tab = i),
              )),
          actions: [
            PanelButton(s.t('ui.inventory.armory.character'),
                onPressed: () => controller.openPanel(WorldPanel.character)),
            PanelButton(s.t('ui.inventory.armory.close'), onPressed: close),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PanelHint(tab.hint(s)),
              Expanded(
                  child: KeyedSubtree(
                      key: ValueKey((_tab, view.actorId)),
                      child: tab.build(shop))),
            ],
          ),
        ),
      ),
    );
  }
}
