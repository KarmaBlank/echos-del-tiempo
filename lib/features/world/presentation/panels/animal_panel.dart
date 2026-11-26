import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../app/theme/panel_frame.dart';
import '../../../../game_engine/data/farming_catalog.dart';
import '../../../../game_engine/rules/animal_rules.dart';
import '../../../inventory/domain/item_names.dart';
import '../session_controller.dart';
import '../session_view.dart';
import '../world_strings.dart';
import 'life_icon.dart';
import 'life_item_grid.dart';
import 'ranch_shop_rows.dart' show qualityColor;

/// Organism: the coop / barn panel (docs/specs/animals.md § 5). An
/// INVENTARIO-style grid of the animals with the detail on the right and
/// the care buttons (grey with the reason when they cannot be used).
class AnimalPanel extends StatelessWidget {
  const AnimalPanel({super.key, required this.view, required this.controller});

  final SessionView view;
  final SessionController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final b = c.animalPanelBuild == null ? null : c.town.build(c.animalPanelBuild!);
    final p = view.me?.profile;
    if (b == null || !b.kind.ranch || p == null) return const SizedBox.shrink();
    final home = AnimalRules.homeOf(b)!;
    final day = c.animalDay;
    final hay = p.life.farm.hay;
    final title = context.t('ui.town.ranch.${b.kind.name}.name');

    String? blockText(AnimalBlock? k, FarmAnimal a) => switch (k) {
          null => null,
          AnimalBlock.noTool =>
            context.t('ui.town.ranch.need_tool', {'tool': a.def.tool?.text ?? ''}),
          AnimalBlock.noHay => context.t('ui.town.ranch.no_hay'),
          AnimalBlock.fedToday => context.t('ui.town.ranch.panel.fed_done'),
          AnimalBlock.pettedToday => context.t('ui.town.ranch.panel.pet_done'),
          AnimalBlock.nothingReady => context.t('ui.town.ranch.panel.nothing'),
        };

    String hearts(int h) => '♥ $h/5';

    final cells = [
      for (final a in b.animals)
        () {
          final h = a.hearts.clamp(0, 5);
          final feedWhy = blockText(AnimalRules.feedBlock(p, b, a, day), a);
          final petWhy = blockText(AnimalRules.petBlock(a, day), a);
          final getWhy = blockText(AnimalRules.collectBlock(p, a), a);
          final odds = AnimalRules.odds(h);
          final left = (a.def.every - a.cycle).clamp(1, a.def.every);
          return LifeItemCellData(
            id: 'animal-${a.uid}',
            icon: LifeIcon(a.def.sprite, LifeIconKind.herramienta,
                size: LifeItemGrid.iconSize),
            border: a.ready != null ? qualityColor(a.ready!) : DsColors.border,
            search: animalPetText(a),
            caption: hearts(h),
            equipped: a.ready != null,
            detail: LifeItemDetail(
              itemId: a.def.sprite,
              name: animalPetText(a),
              nameColor: DsColors.textPrimary,
              tags: [
                (a.def.text, DsColors.textSecondary),
                (hearts(h), DsColors.reward),
              ],
              lines: [
                a.fed == day
                    ? context.t('ui.town.ranch.panel.fed_yes')
                    : context.t('ui.town.ranch.panel.fed_no'),
                a.pet == day
                    ? context.t('ui.town.ranch.panel.pet_yes')
                    : context.t('ui.town.ranch.panel.pet_no'),
                if (a.ready case final q?)
                  context.t('ui.town.ranch.panel.ready', {
                    'item': animalGoodsName(animalGoodsKey(a.def.product, q))
                  })
                else
                  context.t('ui.town.ranch.panel.in_days',
                      {'item': a.def.productDef.text, 'n': left}),
                context.t('ui.town.ranch.panel.odds', {
                  'raro': ((odds[CropQuality.raro] ?? 0) * 100).round(),
                  'epico': ((odds[CropQuality.epico] ?? 0) * 100).round(),
                }),
              ],
              actions: [
                DsButton(context.t('ui.town.ranch.panel.feed'),
                    key: ValueKey('animal-feed-${a.uid}'),
                    size: DsButtonSize.compact,
                    tooltip: feedWhy,
                    onPressed: feedWhy == null
                        ? () => c.feedAnimal(b.id, a.uid)
                        : null),
                DsButton(context.t('ui.town.ranch.panel.pet'),
                    key: ValueKey('animal-pet-${a.uid}'),
                    size: DsButtonSize.compact,
                    tooltip: petWhy,
                    onPressed:
                        petWhy == null ? () => c.petAnimal(b.id, a.uid) : null),
                DsButton(context.t('ui.town.ranch.panel.collect'),
                    key: ValueKey('animal-collect-${a.uid}'),
                    size: DsButtonSize.compact,
                    tooltip: getWhy,
                    onPressed: getWhy == null
                        ? () => c.collectAnimal(b.id, a.uid)
                        : null),
              ],
            ),
          );
        }(),
    ];

    final siloFull = b.hay >= AnimalRules.t.i('siloMax');
    final depositWhy = hay <= 0
        ? context.t('ui.town.ranch.no_hay')
        : siloFull
            ? context.t('ui.town.ranch.panel.silo_full')
            : null;

    return PanelFrame(
      key: const ValueKey('panel-animals'),
      title: title,
      width: 900,
      fill: true,
      onClose: c.closePanel,
      header: Padding(
        padding: EdgeInsets.all(DsSpace.sm),
        child: Wrap(
          spacing: DsSpace.md,
          runSpacing: DsSpace.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
                context.t('ui.town.ranch.sign', {
                  'n': b.animals.length,
                  'max': home.cap,
                  'hay': b.hay,
                }),
                style: DsText.body()),
            Text(context.t('ui.town.ranch.panel.bag_hay', {'n': hay}),
                style: DsText.body()),
            DsButton(context.t('ui.town.ranch.panel.deposit'),
                key: const ValueKey('animal-deposit'),
                size: DsButtonSize.compact,
                tooltip: depositWhy,
                onPressed: depositWhy == null ? () => c.depositHay(b.id) : null),
          ],
        ),
      ),
      actions: [
        PanelButton(context.t('ui.town.npc.bye_button'),
            key: const ValueKey('animal-close'), onPressed: c.closePanel),
      ],
      child: LifeItemGrid(
        key: ValueKey('animal-grid-${b.id}'),
        groups: [LifeItemGroup(null, cells)],
        initial: c.animalPanelUid == null ? null : 'animal-${c.animalPanelUid}',
        empty: context.t('ui.town.ranch.panel.empty'),
      ),
    );
  }
}
