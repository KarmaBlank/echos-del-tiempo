import 'package:material_ui/material_ui.dart';

import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/panel_widgets.dart';
import '../../../app/theme/proto_markup.dart';
import '../../world/presentation/session_controller.dart';
import '../../world/presentation/session_view.dart';
import 'shop_sections.dart';

/// Armería del lobby (`shop` del prototipo, líneas 1352-1358) en
/// pestañas: COMPRAR · FORJA · FUSIÓN · CONSUMIBLES, cada una con su
/// línea "qué hace" y lista + detalle. Ver docs/specs/panels.md §
/// "Armería".
class ArmoryPanel extends StatefulWidget {
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
  State<ArmoryPanel> createState() => _ArmoryPanelState();
}

class _ArmoryPanelState extends State<ArmoryPanel> {
  late var _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    final controller = widget.controller;
    final shop = ShopContext(view, controller);
    final p = shop.profile;
    final close = view.mustAllocate ? null : controller.closePanel;
    return PanelFrame(
      title: 'ARMERÍA',
      width: 1000,
      fill: true,
      help: kShopHelp,
      onClose: close,
      titleTrailing: ProtoText('Créditos <b>₵${p.credits}</b> · '
          '<span class="k">${protoEsc(shop.className())}</span>'),
      header: PanelTabs(
        labels: [for (final t in ArmoryTab.values) t.label],
        index: _tab.index,
        onChanged: (i) => setState(() => _tab = ArmoryTab.values[i]),
      ),
      actions: [
        PanelButton('PERSONAJE [C]',
            onPressed: () => controller.openPanel(WorldPanel.character)),
        PanelButton('CERRAR [ESC]', onPressed: close),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PanelHint(_tab.hint),
          Expanded(child: KeyedSubtree(
              key: ValueKey(_tab), child: _tab.build(shop))),
        ],
      ),
    );
  }
}
