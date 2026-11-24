import 'package:material_ui/material_ui.dart';
import '../domain/item_names.dart';

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
import 'inventory_strings.dart';
import 'shop_sections.dart';

/// Oficio de cada receta del taller (filtro de chip).
const kWorkshopOficio = <String, String>{
  'fibra': 'cultivo',
  'cebo': 'pesca',
  'tabla': 'cultivo',
};

/// Ayuda `[?]` del taller.
String workshopHelp(BuildContext context) =>
    invStrings(context).t('ui.inventory.workshop.help');

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
    final s = invStrings(context);
    return PartyMemberKeys(
      view: view,
      controller: controller,
      child: PanelFrame(
        title: s.t('ui.inventory.workshop.title'),
        width: 1000,
        fill: true,
        help: workshopHelp(context),
        onClose: close,
        titleTrailing: ProtoText(s.t('ui.inventory.workshop.credits',
            {'credits': '₵${p.credits}'})),
        header: PartyMemberBar.header(view, controller, const SizedBox.shrink()),
        actions: [
          PanelButton(s.t('ui.inventory.armory.character'),
              onPressed: () => controller.openPanel(WorldPanel.character)),
          PanelButton(s.t('ui.inventory.armory.close'), onPressed: close),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PanelHint(s.t('ui.inventory.workshop.hint')),
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
    final s = invStrings(context);
    DsCraftItem item(String id) {
      final d = kLifeMaterials[id]!;
      final max = LifeCraftRules.maxTimes(p, id);
      Widget go(String label, int n, [String? keyLabel]) {
        final a = CraftAction(CraftOp.condense, '${LifeCraftRules.prefix}$id',
            index: n);
        final why = !inWorld
            ? s.t('ui.inventory.workshop.world_only')
            : max < n || n < 1
                ? s.t('ui.inventory.workshop.not_enough')
                : shop.guards.craft(p, a);
        return DsButton(label,
            key: ValueKey('workshop-$id-${keyLabel ?? label}'),
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
        name: d.text,
        tag: kWorkshopOficio[id],
        count: p.life.craft(id),
        description: d.description,
        lines: [
          s.t('ui.inventory.workshop.recipe',
              {'recipe': LifeCraftRules.recipeText(id)}),
          s.t('ui.inventory.workshop.have',
              {'n': p.life.craft(id), 'max': max}),
        ],
        actions: [
          go('×1', 1),
          go('×5', 5),
          // The key keeps the es-AR label so tests and macros stay stable.
          go(s.t('ui.inventory.workshop.max'), max, 'MÁX'),
        ],
      );
    }

    return DsCraftGridTemplate(
      key: const ValueKey('workshop-grid'),
      keyPrefix: 'workshop',
      filters: [
        DsTransferFilter(s.t('ui.inventory.workshop.filter.all'), null),
        DsTransferFilter(s.t('ui.inventory.workshop.filter.farming'), 'cultivo'),
        DsTransferFilter(s.t('ui.inventory.workshop.filter.fishing'), 'pesca'),
      ],
      items: [for (final id in kLifeMaterialIds) item(id)],
    );
  }
}
