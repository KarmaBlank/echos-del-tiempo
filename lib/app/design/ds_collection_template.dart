import 'package:material_ui/material_ui.dart';

import 'ds_components.dart';
import 'ds_detail_pane.dart';
import 'ds_tokens.dart';

/// One entry of a collection (design_system.md § "Colección"). Generic:
/// a fish, a crop, a smithing material… The template knows nothing else.
class DsCollectionEntry {
  const DsCollectionEntry({
    required this.id,
    required this.icon,
    required this.discovered,
    required this.title,
    this.titleColor,
    this.border,
    this.tags = const [],
    this.rows = const [],
    this.groups = const {},
  });

  /// Stable id (cell key: `<keyPrefix>-<id>`).
  final String id;

  /// Sprite (32 px). Only shown when [discovered].
  final Widget icon;
  final bool discovered;

  /// Name (only shown when [discovered]).
  final String title;
  final Color? titleColor;

  /// Cell frame (rarity); grey when undiscovered.
  final Color? border;

  /// Short colored tags (rarity, biome…).
  final List<(String, Color)> tags;

  /// Detail rows, one per line (where, season, weather, best size…).
  final List<String> rows;

  /// Filter ids this entry belongs to (the subtabs; `all` always).
  final Set<String> groups;
}

/// Template: a collection of things to discover. Subtabs (filters) and
/// a progress counter on top, a grid of cells (discovered = sprite,
/// undiscovered = grey "?") and the detail of the chosen cell on the
/// right (below on narrow widths). Each cell has a tooltip with the
/// fixed tooltip width and font. Undiscovered entries never show any
/// info: only [unknownTitle] and [unknownHint]. Purely visual.
class DsCollectionTemplate extends StatefulWidget {
  const DsCollectionTemplate({
    super.key,
    required this.entries,
    required this.filters,
    required this.progressLabel,
    required this.unknownTitle,
    required this.unknownHint,
    this.keyPrefix = 'collection',
  });

  final List<DsCollectionEntry> entries;

  /// Subtabs: (id, label). The first one is selected at start; the id
  /// `all` shows every entry.
  final List<(String, String)> filters;

  /// "Descubiertos 3/10" from (found, total) of the current filter.
  final String Function(int found, int total) progressLabel;
  final String unknownTitle;
  final String unknownHint;
  final String keyPrefix;

  /// Cell, icon, gap and detail width (same as INVENTARIO).
  static const cell = 44.0, iconSize = 32.0, gap = 4.0, detailWidth = 280.0;

  /// From this width on the detail goes to the right.
  static const wideFrom = 460.0;

  @override
  State<DsCollectionTemplate> createState() => _DsCollectionTemplateState();
}

class _DsCollectionTemplateState extends State<DsCollectionTemplate> {
  int _tab = 0;
  String? _selected;

  List<DsCollectionEntry> get _shown {
    if (widget.filters.isEmpty) return widget.entries;
    final id = widget.filters[_tab.clamp(0, widget.filters.length - 1)].$1;
    return [
      for (final e in widget.entries)
        if (id == 'all' || e.groups.contains(id)) e
    ];
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    final found = shown.where((e) => e.discovered).length;
    final sel = shown.where((e) => e.id == _selected).firstOrNull ??
        shown.firstOrNull;
    final p = widget.keyPrefix;
    return Column(
      key: ValueKey('$p-template'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          if (widget.filters.isNotEmpty)
            Expanded(
              child: DsTabBar(
                key: ValueKey('$p-tabs'),
                tabs: [
                  for (final f in widget.filters)
                    DsTab(f.$2, key: ValueKey('$p-tab-${f.$1}')),
                ],
                index: _tab.clamp(0, widget.filters.length - 1),
                onChanged: (i) => setState(() => _tab = i),
              ),
            )
          else
            const Spacer(),
          SizedBox(width: DsSpace.sm),
          DsBadge(widget.progressLabel(found, shown.length),
              key: ValueKey('$p-progress')),
        ]),
        SizedBox(height: DsSpace.xs),
        Expanded(
          child: LayoutBuilder(builder: (context, box) {
            final wide = box.maxWidth >= DsCollectionTemplate.wideFrom;
            final grid = SingleChildScrollView(
              child: Wrap(
                spacing: DsCollectionTemplate.gap,
                runSpacing: DsCollectionTemplate.gap,
                children: [
                  for (final e in shown)
                    _Cell(
                        entry: e,
                        selected: e.id == sel?.id,
                        keyPrefix: p,
                        unknownTitle: widget.unknownTitle,
                        unknownHint: widget.unknownHint,
                        onTap: () => setState(() => _selected = e.id)),
                ],
              ),
            );
            final detail = sel == null
                ? const SizedBox.shrink()
                : DsDetailPane(
                    key: ValueKey('$p-detail'),
                    body: _Detail(
                        entry: sel,
                        unknownTitle: widget.unknownTitle,
                        unknownHint: widget.unknownHint));
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: grid),
                  SizedBox(width: DsSpace.sm),
                  SizedBox(
                      width: DsCollectionTemplate.detailWidth, child: detail),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: grid),
                SizedBox(height: DsSpace.xs),
                Expanded(child: detail),
              ],
            );
          }),
        ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell(
      {required this.entry,
      required this.selected,
      required this.keyPrefix,
      required this.unknownTitle,
      required this.unknownHint,
      required this.onTap});
  final DsCollectionEntry entry;
  final bool selected;
  final String keyPrefix, unknownTitle, unknownHint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final border = selected
        ? DsColors.actionPrimary
        : e.discovered
            ? (e.border ?? DsColors.border)
            : DsColors.textSecondary;
    return DsTooltip(
      card: e.discovered
          ? DsTooltipCard(
              title: e.title,
              titleColor: e.titleColor,
              children: [
                for (final r in e.rows) Text(r, style: DsText.detail()),
              ])
          : DsTooltipCard(title: unknownTitle, children: [
              Text(unknownHint, style: DsText.detail()),
            ]),
      child: GestureDetector(
        key: ValueKey('$keyPrefix-${e.id}'),
        onTap: onTap,
        child: Container(
          width: DsCollectionTemplate.cell,
          height: DsCollectionTemplate.cell,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: DsColors.surfaceSunken,
            border: Border.all(color: border, width: selected ? 2 : 1),
          ),
          child: e.discovered
              ? SizedBox.square(
                  dimension: DsCollectionTemplate.iconSize, child: e.icon)
              : FittedBox(
                  child: Text('?',
                      key: ValueKey('$keyPrefix-unknown-${e.id}'),
                      style: DsText.title(DsColors.textSecondary)),
                ),
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail(
      {required this.entry,
      required this.unknownTitle,
      required this.unknownHint});
  final DsCollectionEntry entry;
  final String unknownTitle, unknownHint;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    if (!e.discovered) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(unknownTitle,
              key: const ValueKey('collection-detail-title'),
              style: DsText.subtitle(DsColors.textSecondary)),
          SizedBox(height: DsSpace.xs),
          Text(unknownHint, style: DsText.body(DsColors.textSecondary)),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          SizedBox.square(
              dimension: DsCollectionTemplate.iconSize, child: e.icon),
          SizedBox(width: DsSpace.sm),
          Expanded(
            child: Text(e.title,
                key: const ValueKey('collection-detail-title'),
                style: DsText.subtitle(e.titleColor)),
          ),
        ]),
        if (e.tags.isNotEmpty) ...[
          SizedBox(height: DsSpace.xs),
          Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: [
            for (final (t, c) in e.tags) DsTag(t, color: c),
          ]),
        ],
        SizedBox(height: DsSpace.xs),
        for (final r in e.rows)
          Padding(
            padding: EdgeInsets.only(bottom: DsSpace.xs),
            child: Text(r, style: DsText.body()),
          ),
      ],
    );
  }
}
