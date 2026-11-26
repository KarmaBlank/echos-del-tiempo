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
import 'ranch_shop_rows.dart' show qualityColor;

/// Organism: the coop / barn panel (docs/specs/animals.md § 5).
///
/// - Header row: icon counters (animals / capacity, hay in the store,
///   hay in the bag) and DEPOSITAR HENO.
/// - Body: [DsGridDetailLayout] — INVENTARIO-size cells anchored
///   top-left (sprite only; the details live in the hover tooltip) and
///   the detail pane taking the rest of the width: large portrait, name,
///   species chip, hearts, the care checklist and the quality line.
/// - The care buttons sit in one row pinned at the bottom of the pane,
///   grey with the reason in the tooltip when they cannot be used.
class AnimalPanel extends StatefulWidget {
  const AnimalPanel({super.key, required this.view, required this.controller});

  final SessionView view;
  final SessionController controller;

  @override
  State<AnimalPanel> createState() => _AnimalPanelState();
}

class _AnimalPanelState extends State<AnimalPanel> {
  int? _uid;

  /// The controller's pick last seen: a new one (E on another animal)
  /// moves the selection to it.
  int? _asked;

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final b =
        c.animalPanelBuild == null ? null : c.town.build(c.animalPanelBuild!);
    final p = widget.view.me?.profile;
    if (b == null || !b.kind.ranch || p == null) return const SizedBox.shrink();
    final home = AnimalRules.homeOf(b)!;
    final day = c.animalDay;
    final hay = p.life.farm.hay;
    if (c.animalPanelUid != _asked) _uid = _asked = c.animalPanelUid;
    final animals = b.animals;
    final sel = animals.where((a) => a.uid == _uid).firstOrNull ??
        animals.firstOrNull;

    final siloFull = b.hay >= AnimalRules.t.i('siloMax');
    final depositWhy = hay <= 0
        ? context.t('ui.town.ranch.no_hay')
        : siloFull
            ? context.t('ui.town.ranch.panel.silo_full')
            : null;

    final header = Wrap(
      key: const ValueKey('animal-header'),
      spacing: DsSpace.lg,
      runSpacing: DsSpace.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _Counter(
            key: const ValueKey('animal-count'),
            icon: home.sprite,
            value: '${animals.length}/${home.cap}',
            tip: context.t('ui.town.ranch.sign', {
              'n': animals.length,
              'max': home.cap,
              'hay': b.hay,
            })),
        _Counter(
            key: const ValueKey('animal-silo'),
            icon: 'heno',
            value: '${b.hay}/${AnimalRules.t.i('siloMax')}',
            tip: context.t('ui.town.ranch.hay_info')),
        _Counter(
            key: const ValueKey('animal-bag-hay'),
            icon: 'heno',
            value: '$hay',
            label: context.t('ui.town.ranch.panel.bag_hay', {'n': hay})),
        DsButton(context.t('ui.town.ranch.panel.deposit'),
            key: const ValueKey('animal-deposit'),
            tooltip: depositWhy,
            onPressed: depositWhy == null ? () => c.depositHay(b.id) : null),
      ],
    );

    return PanelFrame(
      key: const ValueKey('panel-animals'),
      title: context.t('ui.town.ranch.${b.kind.name}.name'),
      width: 900,
      fill: true,
      onClose: c.closePanel,
      actions: [
        PanelButton(context.t('ui.town.npc.bye_button'),
            key: const ValueKey('animal-close'), onPressed: c.closePanel),
      ],
      child: DsGridDetailLayout(
        key: ValueKey('animal-grid-${b.id}'),
        keyPrefix: 'animal',
        header: header,
        count: animals.length,
        empty: Text(context.t('ui.town.ranch.panel.empty'),
            style: DsText.description()),
        cell: (context, i, size) => _Cell(
          animal: animals[i],
          size: size,
          selected: animals[i].uid == sel?.uid,
          day: day,
          onTap: () => setState(() => _uid = animals[i].uid),
        ),
        detail: sel == null
            ? null
            : _Detail(
                key: ValueKey('animal-detail-${sel.uid}'),
                animal: sel,
                day: day,
                feedWhy: _block(
                    context, AnimalRules.feedBlock(p, b, sel, day), sel),
                petWhy: _block(context, AnimalRules.petBlock(sel, day), sel),
                getWhy: _block(context, AnimalRules.collectBlock(p, sel), sel),
                onFeed: () => c.feedAnimal(b.id, sel.uid),
                onPet: () => c.petAnimal(b.id, sel.uid),
                onCollect: () => c.collectAnimal(b.id, sel.uid),
              ),
      ),
    );
  }
}

/// Why a care action is blocked (`null` = it can be done).
String? _block(BuildContext context, AnimalBlock? k, FarmAnimal a) =>
    switch (k) {
      null => null,
      AnimalBlock.noTool =>
        context.t('ui.town.ranch.need_tool', {'tool': a.def.tool?.text ?? ''}),
      AnimalBlock.noHay => context.t('ui.town.ranch.no_hay'),
      AnimalBlock.fedToday => context.t('ui.town.ranch.panel.fed_done'),
      AnimalBlock.pettedToday => context.t('ui.town.ranch.panel.pet_done'),
      AnimalBlock.nothingReady => context.t('ui.town.ranch.panel.nothing'),
    };

/// The checklist of one animal: (key, done, text).
List<(String, bool, String)> _checklist(
    BuildContext context, FarmAnimal a, int day) {
  final left = (a.def.every - a.cycle).clamp(1, a.def.every);
  return [
    (
      'fed',
      a.fed == day,
      a.fed == day
          ? context.t('ui.town.ranch.panel.fed_yes')
          : context.t('ui.town.ranch.panel.fed_no')
    ),
    (
      'pet',
      a.pet == day,
      a.pet == day
          ? context.t('ui.town.ranch.panel.pet_yes')
          : context.t('ui.town.ranch.panel.pet_no')
    ),
    (
      'ready',
      a.ready != null,
      switch (a.ready) {
        final q? => context.t('ui.town.ranch.panel.ready',
            {'item': animalGoodsName(animalGoodsKey(a.def.product, q))}),
        null => context.t('ui.town.ranch.panel.in_days',
            {'item': a.def.productDef.text, 'n': left}),
      }
    ),
  ];
}

String _odds(BuildContext context, FarmAnimal a) {
  final odds = AnimalRules.odds(a.hearts.clamp(0, 5));
  return context.t('ui.town.ranch.panel.odds', {
    'raro': ((odds[CropQuality.raro] ?? 0) * 100).round(),
    'epico': ((odds[CropQuality.epico] ?? 0) * 100).round(),
  });
}

/// Molecule: an icon with its count (or a label) after it.
class _Counter extends StatelessWidget {
  const _Counter(
      {super.key,
      required this.icon,
      required this.value,
      this.label,
      this.tip});

  final String icon;
  final String value;
  final String? label;
  final String? tip;

  @override
  Widget build(BuildContext context) {
    final row = Row(mainAxisSize: MainAxisSize.min, children: [
      LifeIcon(icon, LifeIconKind.herramienta, size: DsSizes.itemIcon),
      SizedBox(width: DsSpace.xs),
      Text(label ?? value, style: DsText.body(DsColors.textPrimary)),
    ]);
    final t = tip;
    return t == null ? row : row.tip(t);
  }
}

/// A row of five hearts (full / empty sprites).
class _Hearts extends StatelessWidget {
  const _Hearts(this.n, {this.size = 16});

  final int n;
  final double size;

  @override
  Widget build(BuildContext context) => Row(
        key: ValueKey('animal-hearts-$n'),
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 5; i++)
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: LifeIcon(i < n ? 'corazon' : 'corazon_vacio',
                  LifeIconKind.herramienta,
                  size: size),
            ),
        ],
      );
}

/// Atom: one animal cell, sprite only; everything else in the tooltip.
class _Cell extends StatelessWidget {
  const _Cell(
      {required this.animal,
      required this.size,
      required this.selected,
      required this.day,
      required this.onTap});

  final FarmAnimal animal;
  final double size;
  final bool selected;
  final int day;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final a = animal;
    final border = selected
        ? DsColors.selected
        : a.ready != null
            ? qualityColor(a.ready!)
            : DsColors.border;
    return DsTooltip(
      card: DsTooltipCard(
        title: animalPetText(a),
        tags: [
          DsChip(a.def.text, color: DsColors.textSecondary),
          DsChip('♥ ${a.hearts.clamp(0, 5)}/5', color: DsColors.reward),
        ],
        children: [
          for (final (_, done, text) in _checklist(context, a, day))
            Text(text,
                style: DsText.detail(
                    done ? DsColors.success : DsColors.textSecondary)),
        ],
      ),
      child: GestureDetector(
        key: ValueKey('animal-animal-${a.uid}'),
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: DsColors.surfaceSunken,
            border: Border.all(color: border, width: selected ? 2 : 1),
          ),
          child: SizedBox.square(
              dimension: DsSizes.itemIcon * size / DsSizes.itemCell,
              child: FittedBox(
                  child: LifeIcon(a.def.sprite, LifeIconKind.herramienta,
                      size: DsSizes.itemIcon))),
        ),
      ),
    );
  }
}

/// Organism: the chosen animal, full width of the pane.
class _Detail extends StatelessWidget {
  const _Detail({
    super.key,
    required this.animal,
    required this.day,
    required this.feedWhy,
    required this.petWhy,
    required this.getWhy,
    required this.onFeed,
    required this.onPet,
    required this.onCollect,
  });

  final FarmAnimal animal;
  final int day;
  final String? feedWhy, petWhy, getWhy;
  final VoidCallback onFeed, onPet, onCollect;

  static const portrait = 96.0;

  @override
  Widget build(BuildContext context) {
    final a = animal;
    final top = Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        key: const ValueKey('animal-portrait'),
        width: portrait + DsSpace.md,
        height: portrait + DsSpace.md,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: DsColors.surface,
          border: Border.all(
              color: a.ready != null ? qualityColor(a.ready!) : DsColors.border,
              width: 2),
        ),
        child: LifeIcon(a.def.sprite, LifeIconKind.herramienta, size: portrait),
      ),
      SizedBox(width: DsSpace.md),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(animalPetText(a),
                key: const ValueKey('animal-name'), style: DsText.title()),
            SizedBox(height: DsSpace.sm),
            DsTag(a.def.text, color: DsColors.textSecondary),
            SizedBox(height: DsSpace.sm),
            _Hearts(a.hearts.clamp(0, 5), size: 24),
          ],
        ),
      ),
    ]);
    final checks = [
      for (final (k, done, text) in _checklist(context, a, day))
        Padding(
          key: ValueKey('animal-check-$k'),
          padding: EdgeInsets.only(bottom: DsSpace.sm),
          child: Row(children: [
            DsStatusMark(done),
            SizedBox(width: DsSpace.sm),
            Expanded(
                child: Text(text,
                    style: DsText.body(
                        done ? DsColors.success : DsColors.textPrimary))),
          ]),
        ),
      Row(key: const ValueKey('animal-check-quality'), children: [
        Container(
          width: 11,
          height: 11,
          color: DsColors.reward,
        ),
        SizedBox(width: DsSpace.sm),
        Expanded(child: Text(_odds(context, a), style: DsText.accent())),
      ]),
    ];
    DsButton button(String key, String label, String? why, VoidCallback go) =>
        DsButton(context.t(label),
            key: ValueKey('animal-$key-${a.uid}'),
            tooltip: why,
            onPressed: why == null ? go : null);
    return DsDetailPane(
      sunken: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          top,
          SizedBox(height: DsSpace.md),
          ...checks,
        ],
      ),
      actions: Wrap(
        key: const ValueKey('animal-actions'),
        spacing: DsSpace.sm,
        runSpacing: DsSpace.sm,
        children: [
          button('feed', 'ui.town.ranch.panel.feed', feedWhy, onFeed),
          button('pet', 'ui.town.ranch.panel.pet', petWhy, onPet),
          button('collect', 'ui.town.ranch.panel.collect', getWhy, onCollect),
        ],
      ),
    );
  }
}
