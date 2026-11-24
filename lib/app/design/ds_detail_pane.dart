import 'package:material_ui/material_ui.dart';

import 'ds_tokens.dart';

/// Organism: the detail column of every grid + detail layout (shops,
/// trader, stalls, lost loot, trade grids).
///
/// - Fills the height it is given (the panel body), never a small box.
/// - [actions] (quantity, total, primary button) stay PINNED at the
///   bottom, always visible; only [body] scrolls, with a visible
///   scrollbar when it overflows.
/// - With unbounded height (inside an outer scroll) it falls back to a
///   plain column: body, then actions.
///
/// Purely visual: it knows nothing about items, prices or callbacks.
class DsDetailPane extends StatefulWidget {
  const DsDetailPane({
    super.key,
    required this.body,
    this.actions,
    this.padding,
    this.sunken = false,
  });

  /// Info section (icon + name, tags, data, description). Scrolls.
  final Widget body;

  /// Action area pinned at the bottom (null: none).
  final Widget? actions;

  /// Inner padding (default `md`).
  final EdgeInsets? padding;

  /// Sunken surface with border (shop look) instead of the card surface.
  final bool sunken;

  @override
  State<DsDetailPane> createState() => _DsDetailPaneState();
}

class _DsDetailPaneState extends State<DsDetailPane> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actions = widget.actions;
    final deco = BoxDecoration(
      color: widget.sunken ? DsColors.surfaceSunken : DsColors.surface,
      border: Border.all(
          color: widget.sunken ? DsColors.border : Colors.transparent),
    );
    return Container(
      decoration: deco,
      padding: widget.padding ?? EdgeInsets.all(DsSpace.md),
      child: LayoutBuilder(builder: (context, box) {
        if (!box.hasBoundedHeight) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              widget.body,
              if (actions != null) ...[
                SizedBox(height: DsSpace.sm),
                KeyedSubtree(
                    key: const ValueKey('ds-detail-actions'), child: actions),
              ],
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Scrollbar(
                controller: _scroll,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  key: const ValueKey('ds-detail-body'),
                  controller: _scroll,
                  padding: EdgeInsets.only(right: DsSpace.sm),
                  child: widget.body,
                ),
              ),
            ),
            if (actions != null) ...[
              Divider(height: DsSpace.md, color: DsColors.border),
              KeyedSubtree(
                  key: const ValueKey('ds-detail-actions'), child: actions),
            ],
          ],
        );
      }),
    );
  }
}
