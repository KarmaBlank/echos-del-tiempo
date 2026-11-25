import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../core/i18n/catalog_text.dart';
import '../../../../game_engine/data/cozy_catalog.dart';
import '../../../../game_engine/data/farming_catalog.dart';
import '../../../../game_engine/data/fishing_catalog.dart';
import '../../../../game_engine/data/smithing_catalog.dart';
import '../../../../game_engine/models/player_profile.dart';
import '../../../../game_engine/rules/cozy_rules.dart';
import '../../../inventory/domain/item_names.dart';
import '../../domain/town_names.dart';
import '../world_strings.dart';
import 'fishing_widgets.dart' show fishRarityColor;
import 'life_icon.dart';
import 'life_item_grid.dart';
import 'seed_text.dart' show lifeBiomeLabel;
import 'smith_collection.dart' show smithKindColor, smithSourceText;

/// Profession journals of the DIARIO (cozy_life.md § 4): one subtab per
/// profession the player has, each a grid of what they found with the
/// detail on the right. Only found things show (it is a journal, not the
/// full collection of PERSONAJE > OFICIOS).
class ProfessionJournalView extends StatefulWidget {
  const ProfessionJournalView(
      {super.key, required this.profile, this.onCompost});

  final PlayerProfile profile;

  /// Prepare a compost recipe (`null` = read only).
  final bool Function(String recipe)? onCompost;

  @override
  State<ProfessionJournalView> createState() => _ProfessionJournalViewState();
}

class _ProfessionJournalViewState extends State<ProfessionJournalView> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final journals = CozyRules.journals(p.life);
    if (journals.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(DsSpace.md),
        child: Text(context.t('ui.town.journal.prof_none'),
            key: const ValueKey('prof-journal-none'),
            softWrap: true,
            style: DsText.detail(DsColors.textSecondary)),
      );
    }
    final tab = _tab.clamp(0, journals.length - 1);
    final j = journals[tab];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        DsTabBar(
          tabs: [
            for (final k in journals)
              DsTab(context.t('ui.town.journal.prof_${k.name}'),
                  key: ValueKey('prof-journal-tab-${k.name}')),
          ],
          index: tab,
          onChanged: (i) => setState(() => _tab = i),
        ),
        SizedBox(height: DsSpace.xs),
        LifeItemGrid(
          key: ValueKey('prof-journal-grid-${j.name}'),
          groups: [
            LifeItemGroup(
                null,
                switch (j) {
                  ProfessionJournal.fishing => _fish(context, p),
                  ProfessionJournal.mining => _ores(context, p),
                  ProfessionJournal.farming => _farm(context, p),
                }),
          ],
          empty: context.t('ui.town.journal.prof_empty'),
        ),
      ],
    );
  }

  List<LifeItemCellData> _fish(BuildContext context, PlayerProfile p) => [
        for (final d in kFish.values)
          if (p.life.log[d.id] case final cm?)
            LifeItemCellData(
              id: 'journal-fish-${d.id}',
              icon: LifeIcon(d.id, LifeIconKind.pescado, size: 32),
              border: fishRarityColor(d.rarity),
              search: d.text,
              caption: '$cm cm',
              detail: LifeItemDetail(
                name: d.text,
                nameColor: fishRarityColor(d.rarity),
                tags: [
                  (d.rarity.text.toUpperCase(), fishRarityColor(d.rarity))
                ],
                lines: [
                  context.t('ui.town.bag.record', {'n': cm}),
                  if (p.life.fishFinds[d.id] case final f?) ...[
                    context.t('ui.town.journal.first_where',
                        {'place': lifeBiomeLabel(context, f.source)}),
                    context.t('ui.town.journal.first_day', {'n': f.day}),
                    context.t('ui.town.journal.times', {'n': f.count}),
                  ],
                ],
              ),
            ),
      ];

  List<LifeItemCellData> _ores(BuildContext context, PlayerProfile p) => [
        for (final e in p.life.oreLog.entries)
          if (kSmithMaterials[e.key] case final d?)
            LifeItemCellData(
              id: 'journal-ore-${e.key}',
              icon: LifeIcon(e.key, LifeIconKind.herramienta, size: 32),
              border: smithKindColor(d.kind),
              search: context.t(d.textKey),
              count: e.value.count,
              detail: LifeItemDetail(
                name: context.t(d.textKey),
                nameColor: smithKindColor(d.kind),
                lines: [
                  context.t('ui.inventory.smith.col.found',
                      {'source': smithSourceText(context, e.value.source)}),
                  context.t('ui.inventory.smith.col.day', {'n': e.value.day}),
                  context
                      .t('ui.inventory.smith.col.count', {'n': e.value.count}),
                ],
              ),
            ),
      ];

  List<LifeItemCellData> _farm(BuildContext context, PlayerProfile p) {
    final f = p.life.farm;
    return [
      for (final e in f.cropLog.entries)
        if (kCrops[e.key] case final d?)
          LifeItemCellData(
            id: 'journal-crop-${d.id}',
            icon: LifeIcon('cosecha_${d.id}', LifeIconKind.cosecha, size: 32),
            border: fishRarityColor(d.rarity),
            search: d.text,
            detail: LifeItemDetail(
              name: d.text,
              nameColor: fishRarityColor(d.rarity),
              tags: [
                (context.t('ui.town.journal.crop_tag'), DsColors.success),
              ],
              lines: [
                context.t('ui.town.collection.best_quality', {
                  'q': CatalogText.of(
                      'ui.town.crop_quality.${CropQuality.values[e.value.clamp(0, 3)].name}',
                      CropQuality.values[e.value.clamp(0, 3)].label),
                }),
                context
                    .t('ui.town.journal.seeds_have', {'n': f.seedCount(d.id)}),
              ],
            ),
          ),
      for (final id in CozyRules.knownSeeds(f))
        if (!f.cropLog.containsKey(id))
          if (kCrops[id] case final d?)
            LifeItemCellData(
              id: 'journal-seed-${d.id}',
              icon: LifeIcon('semilla_${d.id}', LifeIconKind.semilla, size: 32),
              border: fishRarityColor(d.rarity),
              search: d.text,
              count: f.seedCount(d.id),
              detail: LifeItemDetail(
                name: d.text,
                nameColor: fishRarityColor(d.rarity),
                tags: [
                  (
                    context.t('ui.town.journal.seed_tag'),
                    DsColors.textSecondary
                  )
                ],
                lines: [
                  context.t(
                      'ui.town.journal.seeds_have', {'n': f.seedCount(d.id)}),
                  context.t('ui.town.journal.seed_from',
                      {'place': lifeBiomeLabel(context, d.biome)}),
                ],
              ),
            ),
      for (final r in kCompostRecipes.values)
        if (f.recipes.contains(r.id))
          () {
            final can = CozyRules.canCompost(f, r.id);
            final fert = kFertilizers[r.fert];
            return LifeItemCellData(
              id: 'journal-recipe-${r.id}',
              icon: LifeIcon(r.fert, LifeIconKind.herramienta, size: 32),
              border: can ? DsColors.success : DsColors.selected,
              search: context.t('ui.town.compost.${r.id}'),
              caption: 'x${r.makes}',
              detail: LifeItemDetail(
                name: context.t('ui.town.compost.${r.id}'),
                nameColor: DsColors.textTitle,
                tags: [
                  (context.t('ui.town.journal.recipe_tag'), DsColors.reward)
                ],
                lines: [
                  for (final i in r.inputs.entries)
                    context.t('ui.town.journal.recipe_input', {
                      'n': i.value,
                      'item': cropName(i.key.split('@').first),
                      'have': f.cropCount(i.key),
                    }),
                  context.t('ui.town.journal.recipe_gives', {
                    'n': r.makes,
                    'item': fert == null
                        ? r.fert
                        : CatalogText.of(
                            'data.materials.fert.${fert.id}.name', fert.name),
                  }),
                ],
                actions: [
                  if (widget.onCompost case final go?)
                    DsButton(context.t('ui.town.journal.recipe_make'),
                        key: ValueKey('journal-compost-${r.id}'),
                        size: DsButtonSize.compact,
                        tooltip: can
                            ? null
                            : context.t('ui.town.journal.recipe_missing'),
                        onPressed: can ? () => go(r.id) : null),
                ],
              ),
            );
          }(),
    ];
  }
}

/// Name of crop [id] for the journal lines.
String cropName(String id) => kCrops[id]?.text ?? id;
