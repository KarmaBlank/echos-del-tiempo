import 'package:material_ui/material_ui.dart';

import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_theme.dart';
import '../../world/presentation/session_controller.dart';
import '../../world/presentation/session_view.dart';
import 'shop_sections.dart';

/// Armería del lobby (`shop` del prototipo, líneas 1352-1358): armas de
/// su clase, consumibles, herrería (+ equipar) y fusión. Ver
/// docs/specs/panels.md § "Armería".
class ArmoryPanel extends StatelessWidget {
  const ArmoryPanel({super.key, required this.view, required this.controller});

  final SessionView view;
  final SessionController controller;

  @override
  Widget build(BuildContext context) {
    final shop = ShopContext(view, controller);
    final p = shop.profile;
    final cls = shop.rules.catalog.classes[p.classId]?.name ?? p.classId;
    return PanelFrame(
      title: 'ARMERÍA',
      width: 1000,
      actions: [
        PanelButton('PERSONAJE [C]',
            onPressed: () => controller.openPanel(WorldPanel.character)),
        PanelButton('CERRAR [ESC]',
            onPressed: view.mustAllocate ? null : controller.closePanel),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(TextSpan(children: [
            const TextSpan(text: 'Créditos: '),
            TextSpan(
                text: retroText('₵${p.credits}'),
                style: const TextStyle(color: RetroPalette.gold)),
            TextSpan(text: retroText(' · Solo armas de tu clase ($cls)')),
          ])),
          WeaponShopSection(shop: shop, title: 'Armas a la venta'),
          ItemShopSection(shop: shop),
          ForgeSection(shop: shop),
          FuseSection(shop: shop),
          const SizedBox(height: 16),
          const Text(
            'Puedes comprar aunque no cumplas los requisitos: súbelos para '
            'poder equiparla. (retrasa) = retrasa al enemigo en la línea de '
            'tiempo. Pasa el mouse sobre un arma para ver el detalle.',
            textAlign: TextAlign.center,
            style: TextStyle(color: RetroPalette.muted),
          ),
        ],
      ),
    );
  }
}
