import 'package:material_ui/material_ui.dart';

import 'ds_components.dart';
import 'ds_detail_pane.dart';
import 'ds_tokens.dart';

/// One entry of a collection (design_system.md Â§ "ColecciÃ³n"). Generic:
/// a fish, a crop, a smithing materialâ€¦ The template knows nothing else.
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

  /// Short colored tags (rarity, biomeâ€¦).
  final List<(String, Color)> tags;

  /// Detail rows, one per line (where, season, weather, best sizeâ€¦).
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
  static const cell = DsSizes.itemCell,
      iconSize = DsSizes.itemIcon,
      gap = DsSizes.itemGap,
      detailWidth = DsSizes.detailPaneWidth;


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
    final header = Row(children: [
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
    ]);
    return KeyedSubtree(
      key: ValueKey('$p-template'),
      child: DsGridDetailLayout(
        keyPrefix: p,
        header: header,
        count: shown.length,
        cell: (context, i, size) => _Cell(
            entry: shown[i],
            size: size,
            selected: shown[i].id == sel?.id,
            keyPrefix: p,
            unknownTitle: widget.unknownTitle,
            unknownHint: widget.unknownHint,
            onTap: () => setState(() => _selected = shown[i].id)),
        detail: sel == null
            ? null
            : DsDetailPane(
                key: ValueKey('$p-detail'),
                body: _Detail(
                    entry: sel,
                    unknownTitle: widget.unknownTitle,
                    unknownHint: widget.unknownHint)),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell(
      {required this.entry,
      required this.selected,
      this.size = DsSizes.itemCell,
      required this.keyPrefix,
      required this.unknownTitle,
      required this.unknownHint,
      required this.onTap});
  final DsCollectionEntry entry;
  final bool selected;
  final double size;
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
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: DsColors.surfaceSunken,
            border: Border.all(color: border, width: selected ? 2 : 1),
          ),
          child: e.discovered
              ? SizedBox.square(
                  dimension: DsSizes.itemIcon * size / DsSizes.itemCell,
                  child: FittedBox(child: e.icon))
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

/// Organism DsGridDetailLayout (design_system.md Â§ "Grilla de Ã­tems"):
/// the body of [DsCollectionTemplate] and the ONE grid + detail layout of every screen that shows items (shops, stalls, stash,
/// forge, ecos, fishing and farming, helpers, journals, loot).
///
/// - [header] (filters, search, counters) on top, full width.
/// - A grid exactly [DsSizes.gridColumns] wide of cells the size
///   of INVENTARIO's; rows grow downward and a visible scrollbar appears
///   when they overflow.
/// - [detail] on the right, [DsSizes.detailPaneWidth] wide and the
///   full height (usually a `DsDetailPane`, actions pinned at the bottom).
/// - Narrow (< [DsSizes.gridDetailWideFrom]) or inside an outer scroll:
///   detail on top, the grid below, scale Ã—1.
///
/// Purely visual: [cell] builds cell [i] at side `size`.
class DsGridDetailLayout extends StatefulWidget {
  const DsGridDetailLayout({
    super.key,
    required this.count,
    required this.cell,
    this.detail,
    this.header,
    this.empty,
    this.footer = const [],
    this.leading,
    this.keyPrefix = 'igd',
  });

  /// Optional column left of the grid (wide) or above it (narrow).
  final Widget? leading;

  final int count;
  final Widget Function(BuildContext context, int i, double size) cell;
  final Widget? detail;
  final Widget? header;

  /// Shown instead of the grid when [count] is 0.
  final Widget? empty;

  /// Extra widgets under the grid (inside its scroll).
  final List<Widget> footer;

  /// Keys: `<p>-grid`, `<p>-pane`, `<p>-scroll`.
  final String keyPrefix;

  @override
  State<DsGridDetailLayout> createState() => _DsGridDetailLayoutState();
}

class _DsGridDetailLayoutState extends State<DsGridDetailLayout> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Widget _grid(BuildContext context, double k) {
    final size = DsSizes.itemCell * k;
    final gap = DsSizes.itemGap * k;
    final p = widget.keyPrefix;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.count == 0 && widget.empty != null)
          widget.empty!
        else
          SizedBox(
            key: ValueKey('$p-grid'),
            width: DsSizes.gridWidth(k),
            child: Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (var i = 0; i < widget.count; i++)
                  SizedBox.square(
                      dimension: size, child: widget.cell(context, i, size)),
              ],
            ),
          ),
        for (final f in widget.footer) ...[SizedBox(height: DsSpace.sm), f],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.keyPrefix;
    final detail = widget.detail == null
        ? null
        : KeyedSubtree(key: ValueKey('$p-pane'), child: widget.detail!);
    final body = LayoutBuilder(builder: (context, box) {
      final bounded = box.hasBoundedHeight;
      final wide =
          box.maxWidth >= DsSizes.gridDetailWideFrom && bounded;
      Widget pair(double w, double h) {
        final k = DsSizes.itemScale(w, h,
            screen: MediaQuery.sizeOf(context),
            text: MediaQuery.textScalerOf(context).scale(240) / 240);
        // Top-left anchored: the grid keeps INVENTARIO's cell and the
        // actions pane takes every pixel left (never a narrow strip next
        // to empty space). Without a pane the grid just sits top-left.
        final gridBox = SizedBox(
          width: DsSizes.gridWidth(k) + DsSizes.gridScrollbar,
          child: Scrollbar(
            key: ValueKey('$p-scroll'),
            controller: _scroll,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.only(right: DsSizes.gridScrollbar),
              child: _grid(context, k),
            ),
          ),
        );
        return Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            gridBox,
            if (detail != null) ...[
              const SizedBox(width: DsSizes.gridDetailGap),
              Expanded(child: detail),
            ] else
              const Spacer(),
          ],
        );
      }

      if (wide) {
        final lead = widget.leading;
        if (lead == null) return pair(box.maxWidth, box.maxHeight);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SingleChildScrollView(child: lead),
            const SizedBox(width: DsSizes.gridDetailGap),
            Expanded(
                child: LayoutBuilder(
                    builder: (context, b) => pair(b.maxWidth, b.maxHeight))),
          ],
        );
      }
      final k = box.maxWidth.isFinite &&
              box.maxWidth < DsSizes.gridWidth()
          ? box.maxWidth / DsSizes.gridWidth()
          : 1.0;
      final column = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (detail != null) ...[detail, SizedBox(height: DsSpace.sm)],
          if (widget.leading != null) ...[
            Align(alignment: Alignment.topLeft, child: widget.leading),
            SizedBox(height: DsSpace.sm),
          ],
          Align(alignment: Alignment.topLeft, child: _grid(context, k)),
        ],
      );
      return bounded ? SingleChildScrollView(child: column) : column;
    });
    if (widget.header == null) return body;
    return LayoutBuilder(builder: (context, box) {
      final header = Padding(
        padding: EdgeInsets.only(bottom: DsSpace.xs),
        child: widget.header,
      );
      if (!box.hasBoundedHeight) {
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [header, body]);
      }
      return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [header, Expanded(child: body)]);
    });
  }
}

