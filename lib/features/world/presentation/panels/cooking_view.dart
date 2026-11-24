import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../core/i18n/catalog_text.dart';
import '../../../../game_engine/data/farming_catalog.dart' show kCrops;
import '../../../../game_engine/data/fishing_catalog.dart' show kFish;
import '../../../../game_engine/models/player_profile.dart';
import '../../../../game_engine/rules/cooking_rules.dart';
import '../../../inventory/domain/item_names.dart';
import '../../domain/town_names.dart';
import '../session_controller.dart';
import '../world_strings.dart';
import 'fishing_widgets.dart' show fishRarityColor;
import 'life_icon.dart';

// OFICIOS → CULTIVO → COCINA (farming.md § 17): the town pot. Recipes,
// cooked meals and the Cocina collection, each on the shared templates
// (grid with the detail on the right).

/// Quality → rarity color (same scale as crops).
Color mealQualityColor(CropQuality q) => fishRarityColor(switch (q) {
      CropQuality.normal => FishRarity.comun,
      CropQuality.raro => FishRarity.raro,
      CropQuality.epico => FishRarity.epico,
      CropQuality.legendario => FishRarity.legendario,
    });

String _qualityText(CropQuality q) =>
    CatalogText.of('ui.town.crop_quality.${q.name}', q.label);

String _withQuality(String name, CropQuality q) => '$name (${_qualityText(q)})';

String _elementText(BuildContext context, DamageTag? t) =>
    context.t('ui.town.cook.el.${t?.name ?? 'fire'}');

/// One line with what a meal does at [q] (`+8% de vida máxima`).
String mealEffectText(BuildContext context, MealDef m, CropQuality q) {
  final n = (CookingRules.buffValue(m, q) * 100).round();
  return switch (m.stat) {
    MealStat.hp => context.t('ui.town.cook.effect.hp', {'n': n}),
    MealStat.atk => context.t('ui.town.cook.effect.atk', {'n': n}),
    MealStat.res => context.t('ui.town.cook.effect.res',
        {'n': n, 'el': _elementText(context, m.element)}),
  };
}

/// Lines of the active meal for HUD tooltips: name, effect and missions.
List<String> activeMealLines(BuildContext context, MealBuff b) {
  final d = b.def;
  if (d == null) return const [];
  return [
    _withQuality(d.text, b.quality),
    mealEffectText(context, d, b.quality),
    context.t('ui.town.cook.left', {'n': b.left}),
  ];
}

class CookingView extends StatefulWidget {
  const CookingView(
      {super.key, required this.profile, required this.controller});

  final PlayerProfile profile;
  final SessionController controller;

  @override
  State<CookingView> createState() => _CookingViewState();
}

enum _CookTab { recetas, comidas, coleccion }

class _CookingViewState extends State<CookingView> {
  var _tab = _CookTab.recetas;

  PlayerProfile get p => widget.profile;

  Widget _icon(String id) => LifeIcon('comida_$id', LifeIconKind.cosecha,
      size: DsCollectionTemplate.iconSize);

  String _tag(MealStat s) => s.name;

  List<DsTransferFilter> _statFilters(BuildContext context) => [
        DsTransferFilter(context.t('ui.town.cook.tab.all'), null),
        DsTransferFilter(context.t('ui.town.cook.tab.hp'), _tag(MealStat.hp)),
        DsTransferFilter(
            context.t('ui.town.cook.tab.atk'), _tag(MealStat.atk)),
        DsTransferFilter(
            context.t('ui.town.cook.tab.res'), _tag(MealStat.res)),
      ];

  List<String> _ingredients(BuildContext context, MealDef m, CropQuality q) {
    final f = p.life.farm;
    return [
      for (final e in m.crops.entries)
        context.t('ui.town.cook.need', {
          'item': '${kCrops[e.key]?.text ?? e.key} (${_qualityText(q)})',
          'have': f.cropCount(cropKey(e.key, q)),
          'need': e.value,
        }),
      for (final e in m.fish.entries)
        context.t('ui.town.cook.need', {
          'item': kFish[e.key]?.text ?? e.key,
          'have': p.life.count(e.key),
          'need': e.value,
        }),
    ];
  }

  /// The best quality with every crop on hand, or normal.
  CropQuality _shownQuality(MealDef m) {
    for (final q in CropQuality.values.reversed) {
      if (CookingRules.cookBlock(p, m.id, q) == null) return q;
    }
    return CropQuality.normal;
  }

  DsCraftItem _recipe(BuildContext context, MealDef m) {
    final q = _shownQuality(m);
    return DsCraftItem(
      id: m.id,
      icon: _icon(m.id),
      border: fishRarityColor(m.rarity),
      name: m.text,
      tag: _tag(m.stat),
      search: m.text,
      description: m.loreText.isEmpty ? null : m.loreText,
      lines: [
        mealEffectText(context, m, q),
        context.t('ui.town.cook.lasts', {'n': CookingRules.missionsFor(m)}),
        if (m.hasFish) context.t('ui.town.cook.fish_bonus'),
        ..._ingredients(context, m, q),
      ],
      actions: [
        for (final cq in CropQuality.values)
          if (cq == CropQuality.normal ||
              CookingRules.cookBlock(p, m.id, cq) == null)
            DsButton(
                context.t('ui.town.cook.cook_q',
                    {'q': _qualityText(cq).toUpperCase()}),
                key: ValueKey('cook-${m.id}-${cq.index}'),
                size: DsButtonSize.compact,
                onPressed: CookingRules.cookBlock(p, m.id, cq) == null
                    ? () => widget.controller.cookMeal(m.id, cq.index)
                    : null),
      ],
    );
  }

  DsCraftItem _meal(BuildContext context, String key, int n) {
    final (m, q) = parseMealKey(key)!;
    return DsCraftItem(
      id: '${m.id}-${q.index}',
      icon: _icon(m.id),
      border: mealQualityColor(q),
      name: _withQuality(m.text, q),
      tag: _tag(m.stat),
      search: m.text,
      count: n,
      lines: [
        mealEffectText(context, m, q),
        context.t('ui.town.cook.lasts', {'n': CookingRules.missionsFor(m)}),
        if (p.life.farm.meal != null) context.t('ui.town.cook.replaces'),
      ],
      actions: [
        DsButton(context.t('ui.town.cook.eat'),
            key: ValueKey('eat-$key'),
            size: DsButtonSize.compact,
            kind: DsButtonKind.primary,
            onPressed: () => widget.controller.eatMeal(key)),
      ],
    );
  }

  DsCollectionEntry _entry(BuildContext context, MealDef m) {
    final best = p.life.farm.mealLog[m.id];
    return DsCollectionEntry(
      id: m.id,
      discovered: best != null,
      icon: _icon(m.id),
      title: m.text,
      titleColor: fishRarityColor(m.rarity),
      border: fishRarityColor(m.rarity),
      groups: {_tag(m.stat)},
      tags: [(m.rarity.text.toUpperCase(), fishRarityColor(m.rarity))],
      rows: best == null
          ? const []
          : [
              mealEffectText(context, m, CropQuality.normal),
              context.t('ui.town.collection.best_quality', {
                'q': _qualityText(CropQuality.values[best.clamp(0, 3)]),
              }),
            ],
    );
  }

  Widget _active(BuildContext context) {
    final b = p.life.farm.meal;
    final lines = b == null
        ? [context.t('ui.town.cook.active_none')]
        : [
            context.t('ui.town.cook.active'),
            ...activeMealLines(context, b),
          ];
    return Padding(
      key: const ValueKey('cook-active'),
      padding: EdgeInsets.only(bottom: DsSpace.xs),
      child: Text(lines.join(' · '),
          style: DsText.detail(
              b == null ? DsColors.textSecondary : DsColors.reward)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = p.life.farm;
    final tabs = [
      (_CookTab.recetas, context.t('ui.town.cook.tab.recipes')),
      (_CookTab.comidas, context.t('ui.town.cook.tab.meals')),
      (_CookTab.coleccion, context.t('ui.town.bag.filter.collection')),
    ];
    return Column(
      key: const ValueKey('cooking-view'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _active(context),
        Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: [
          for (final (t, label) in tabs)
            DsButton(label,
                key: ValueKey('cook-tab-${t.name}'),
                size: DsButtonSize.compact,
                selected: _tab == t,
                onPressed: () => setState(() => _tab = t)),
        ]),
        SizedBox(height: DsSpace.xs),
        Expanded(
          child: switch (_tab) {
            _CookTab.recetas => DsCraftGridTemplate(
                key: const ValueKey('cook-recipes'),
                keyPrefix: 'cook',
                items: [for (final m in kMeals.values) _recipe(context, m)],
                filters: _statFilters(context),
                empty: context.t('ui.town.bag.no_results'),
              ),
            _CookTab.comidas => DsCraftGridTemplate(
                key: const ValueKey('cook-meals'),
                keyPrefix: 'meal',
                items: [
                  for (final e in f.meals.entries)
                    if (parseMealKey(e.key) != null)
                      _meal(context, e.key, e.value),
                ],
                filters: _statFilters(context),
                empty: context.t('ui.town.cook.empty'),
              ),
            _CookTab.coleccion => DsCollectionTemplate(
                key: const ValueKey('cook-collection'),
                keyPrefix: 'cook-col',
                entries: [for (final m in kMeals.values) _entry(context, m)],
                filters: [
                  for (final fl in _statFilters(context))
                    (fl.tag ?? 'all', fl.label),
                ],
                progressLabel: (a, b) => context.t(
                    'ui.town.collection.progress', {'found': a, 'total': b}),
                unknownTitle: context.t('ui.town.bag.undiscovered'),
                unknownHint: context.t('ui.town.cook.unknown_hint'),
              ),
          },
        ),
      ],
    );
  }
}
