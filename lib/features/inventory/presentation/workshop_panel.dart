import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/panel_widgets.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../game_engine/models/item.dart';
import '../../../game_engine/models/life_skills.dart' show kLifeMaterialIds;
import '../../../game_engine/models/session_action.dart';
import '../../../game_engine/rules/life_craft_rules.dart';
import '../../world/presentation/panels/life_icon.dart';
import '../../world/presentation/panels/party_member_bar.dart';
import '../../world/presentation/session_controller.dart';
import '../../world/presentation/session_view.dart';
import 'shop_sections.dart';

/// Oficio de cada receta del taller (filtro de chip).
const kWorkshopOficio = <String, String>{
  'fibra': 'cultivo',
  'cebo': 'pesca',
  'tabla': 'cultivo',
};

/// Ayuda `[?]` del taller.
const kWorkshopHelp = '<b>Taller de oficios</b><br>'
    'Cosechas y pescados (nunca legendarios; primero los de menos valor) '
    'se condensan en materiales de oficio para contratar y mejorar '
    'ayudantes.<br>'
    'Elegí una casilla; los botones ×1 / ×5 / MÁX están en el detalle de '
    'la derecha. Las armas y sus materiales se trabajan en la ARMERÍA.';

/// TALLER DE OFICIOS del pueblo (town_loop.md § 2.1, materials_economy.md
/// § 4.4, ui_minimal.md § 4.1; v0.32.3): todo lo de los oficios que antes
/// estaba en CONDENSAR de la armería. Grilla con chips por oficio y el
/// detalle a la derecha (`DsCraftGridTemplate`). El host valida
/// (`CraftOp.condense` con el prefijo de oficio).
class WorkshopPanel extends StatelessWidget {
  const WorkshopPanel(
      {super.key, required this.view, required this.controller});

  final SessionView view;
  final SessionController controller;

  @override
  Widget build(BuildContext context) {
    final close = view.mustAllocate ? null : controller.closePanel;
    final shop = ShopContext(view, controller);
    final p = shop.profile;
    return PartyMemberKeys(
      view: view,
      controller: controller,
      child: PanelFrame(
        title: 'TALLER DE OFICIOS',
        width: 1000,
        fill: true,
        help: kWorkshopHelp,
        onClose: close,
        titleTrailing: ProtoText('Créditos <b>₵${p.credits}</b>'),
        header: PartyMemberBar.header(view, controller, const SizedBox.shrink()),
        actions: [
          PanelButton('PERSONAJE [TAB]',
              onPressed: () => controller.openPanel(WorldPanel.character)),
          PanelButton('CERRAR [ESC]', onPressed: close),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PanelHint('Receta, cantidad, condensar. Sin azar.'),
            Expanded(
              child: KeyedSubtree(
                key: ValueKey(view.actorId),
                child: WorkshopGrid(shop: shop),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// La grilla de recetas del taller (también la usa el Editor).
class WorkshopGrid extends StatelessWidget {
  const WorkshopGrid({super.key, required this.shop});

  final ShopContext shop;

  @override
  Widget build(BuildContext context) {
    final p = shop.profile;
    final inWorld = shop.view.session.run == null;
    DsCraftItem item(String id) {
      final d = kLifeMaterials[id]!;
      final max = LifeCraftRules.maxTimes(p, id);
      Widget go(String label, int n) {
        final a = CraftAction(CraftOp.condense, '${LifeCraftRules.prefix}$id',
            index: n);
        final why = !inWorld
            ? 'Solo en el Mundo'
            : max < n || n < 1
                ? 'No alcanza'
                : shop.guards.craft(p, a);
        return DsButton(label,
            key: ValueKey('workshop-$id-$label'),
            size: DsButtonSize.compact,
            kind: DsButtonKind.primary,
            tooltip: why,
            onPressed: why == null ? () => shop.controller.craft(a) : null);
      }

      return DsCraftItem(
        id: id,
        icon: LifeIcon('mat_$id', switch (id) {
          'cebo' => LifeIconKind.pescado,
          'fibra' => LifeIconKind.cosecha,
          _ => LifeIconKind.herramienta,
        }, size: 32),
        border: DsColors.border,
        name: d.name,
        tag: kWorkshopOficio[id],
        count: p.life.craft(id),
        description: d.description,
        lines: [
          'Receta: ${LifeCraftRules.recipeText(id)}',
          'Tenés ${p.life.craft(id)} · alcanza para $max',
        ],
        actions: [go('×1', 1), go('×5', 5), go('MÁX', max)],
      );
    }

    return DsCraftGridTemplate(
      key: const ValueKey('workshop-grid'),
      keyPrefix: 'workshop',
      filters: const [
        DsTransferFilter('TODOS', null),
        DsTransferFilter('CULTIVO', 'cultivo'),
        DsTransferFilter('PESCA', 'pesca'),
      ],
      items: [for (final id in kLifeMaterialIds) item(id)],
    );
  }
}
