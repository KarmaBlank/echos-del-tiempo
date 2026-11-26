import 'package:material_ui/material_ui.dart';

import 'ds_components.dart';
import 'ds_cost_grid.dart';
import 'ds_detail_pane.dart';
import 'ds_gold.dart';
import 'ds_tokens.dart';

/// One line of a quest's checklist (design_system.md § "Encargos").
/// [label] comes fully written by the caller ("Trucha de río — tenés 2 /
/// pide 5", "Vencé al guardián de la Cripta").
class DsQuestObjective {
  const DsQuestObjective(this.label, {required this.done, this.key});

  final String label;
  final bool done;

  /// Key of the line (tests).
  final Key? key;
}

/// One quest of a [DsQuestTemplate]: the left row and the right detail.
class DsQuestEntry {
  const DsQuestEntry({
    required this.id,
    required this.title,
    this.status,
    this.statusColor,
    this.giver,
    this.flavor,
    this.objectives = const [],
    this.items = const [],
    this.rewards = const [],
    this.notes = const [],
    this.actions = const [],
    this.done = false,
  });

  /// Stable id: the row is `ValueKey(id)`.
  final String id;
  final String title;

  /// Short status on the row ("2/5", "LISTO", "CUMPLIDO").
  final String? status;
  final Color? statusColor;

  /// Who asks for it ("Pide: Brann").
  final String? giver;

  /// The quest's own text ("Necesito…"), in the Description style.
  final String? flavor;

  /// The checklist, one ticked line per objective.
  final List<DsQuestObjective> objectives;

  /// Item-collection objectives as the shared item grid ([DsCostGrid]):
  /// `have/need` in the corner, grey until enough, check when complete.
  final List<DsCostEntry> items;

  /// Rewards as chips (label, color, long text as tooltip).
  final List<({String label, Color color, String? tip})> rewards;

  /// Extra meta lines (day it was asked, how many delivered).
  final List<String> notes;

  /// Buttons pinned at the bottom (deliver / claim / track). A deliver
  /// button stays grey, with its reason, until the checklist is done.
  final List<Widget> actions;

  /// Completed (row tick).
  final bool done;
}

/// Template ENCARGOS (design_system.md § "Encargos"): every quest screen
/// (a resident's requests and quests, the DIARIO, notice boards). LEFT
/// HALF: the vertical list of quests (title + short status, the chosen
/// one highlighted). RIGHT HALF: its detail — title, giver, flavor text,
/// the objectives checklist, the required items grid, rewards — with the
/// actions pinned at the bottom. Narrow widths stack the detail under the
/// list. Purely visual: it knows nothing about quests or callbacks.
class DsQuestTemplate extends StatefulWidget {
  const DsQuestTemplate({
    super.key,
    required this.entries,
    required this.empty,
    this.initial,
    this.header,
    this.keyPrefix = 'quest',
    this.itemsLabel,
    this.rewardsLabel,
  });

  final List<DsQuestEntry> entries;

  /// Shown instead of the list when there are no quests.
  final String empty;

  /// Entry selected first (`null`: the first one).
  final String? initial;

  /// Optional row above both halves (status line, filters).
  final Widget? header;

  /// Headers of the items grid and the rewards ("PIDE", "RECOMPENSA").
  final String? itemsLabel, rewardsLabel;

  /// Keys: `<p>-template`, `<p>-list`, `<p>-detail`, `<p>-title`.
  final String keyPrefix;

  /// Width from which the two halves go side by side.
  static const wideFrom = 560.0;

  @override
  State<DsQuestTemplate> createState() => _DsQuestTemplateState();
}

class _DsQuestTemplateState extends State<DsQuestTemplate> {
  late String? _sel = widget.initial;
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.keyPrefix;
    final all = widget.entries;
    final sel = all.where((e) => e.id == _sel).firstOrNull ?? all.firstOrNull;
    if (all.isEmpty) {
      return KeyedSubtree(
        key: ValueKey('$p-template'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.header != null) widget.header!,
            Padding(
              padding: EdgeInsets.all(DsSpace.sm),
              child: Text(widget.empty,
                  key: ValueKey('$p-empty'), style: DsText.meta()),
            ),
          ],
        ),
      );
    }
    final rows = Column(
      key: ValueKey('$p-list'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final e in all)
          DsListRow(
            key: ValueKey(e.id),
            title: e.title,
            titleColor: e.done ? DsColors.success : DsColors.textPrimary,
            subtitle: e.status,
            subtitleColor: e.statusColor,
            wrap: true,
            selected: e.id == sel?.id,
            leading: _Tick(done: e.done),
            onTap: () => setState(() => _sel = e.id),
          ),
      ],
    );
    final detail = sel == null
        ? null
        : DsDetailPane(
            key: ValueKey('$p-detail'),
            body: _QuestDetail(
                entry: sel,
                keyPrefix: p,
                itemsLabel: widget.itemsLabel,
                rewardsLabel: widget.rewardsLabel),
            actions: sel.actions.isEmpty
                ? null
                : Wrap(
                    spacing: DsSpace.xs,
                    runSpacing: DsSpace.xs,
                    children: sel.actions),
          );
    final body = LayoutBuilder(builder: (context, box) {
      final bounded = box.hasBoundedHeight;
      if (box.maxWidth >= DsQuestTemplate.wideFrom && bounded) {
        // Two equal halves: list left, detail right.
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Scrollbar(
                controller: _scroll,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _scroll,
                  padding: EdgeInsets.only(right: DsSpace.sm),
                  child: rows,
                ),
              ),
            ),
            SizedBox(width: DsSpace.sm),
            Expanded(child: detail ?? const SizedBox.shrink()),
          ],
        );
      }
      final column = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          rows,
          if (detail != null) ...[SizedBox(height: DsSpace.sm), detail],
        ],
      );
      return bounded ? SingleChildScrollView(child: column) : column;
    });
    final withHeader = widget.header == null
        ? body
        : LayoutBuilder(builder: (context, box) {
            final h = Padding(
                padding: EdgeInsets.only(bottom: DsSpace.xs),
                child: widget.header);
            return box.hasBoundedHeight
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [h, Expanded(child: body)])
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [h, body]);
          });
    return KeyedSubtree(key: ValueKey('$p-template'), child: withHeader);
  }
}

/// Atom: the checklist tick (empty box / check).
class _Tick extends StatelessWidget {
  const _Tick({required this.done});
  final bool done;

  @override
  Widget build(BuildContext context) => Icon(
        done ? Icons.check_box : Icons.check_box_outline_blank,
        size: 14,
        color: done ? DsColors.success : DsColors.textDisabled,
      );
}

/// Molecule: one checklist line, ticked when done.
class DsChecklistLine extends StatelessWidget {
  const DsChecklistLine(this.objective, {super.key});
  final DsQuestObjective objective;

  @override
  Widget build(BuildContext context) {
    final o = objective;
    return Padding(
      key: o.key,
      padding: EdgeInsets.only(bottom: DsSpace.xs),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Tick(done: o.done),
        SizedBox(width: DsSpace.xs),
        Expanded(
          child: Text(o.label,
              softWrap: true,
              style: DsText.body(
                  o.done ? DsColors.success : DsColors.textPrimary)),
        ),
      ]),
    );
  }
}

class _QuestDetail extends StatelessWidget {
  const _QuestDetail(
      {required this.entry,
      required this.keyPrefix,
      this.itemsLabel,
      this.rewardsLabel});
  final DsQuestEntry entry;
  final String keyPrefix;
  final String? itemsLabel, rewardsLabel;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(e.title,
            key: ValueKey('$keyPrefix-title'),
            softWrap: true,
            style: DsText.subtitle(DsColors.textTitle)),
        if (e.giver != null) ...[
          SizedBox(height: DsSpace.xs),
          Text(e.giver!,
              key: ValueKey('$keyPrefix-giver'), style: DsText.meta()),
        ],
        if (e.flavor != null) ...[
          SizedBox(height: DsSpace.sm),
          Text(e.flavor!,
              key: ValueKey('$keyPrefix-flavor'),
              softWrap: true,
              style: DsText.description()),
        ],
        if (e.objectives.isNotEmpty) ...[
          SizedBox(height: DsSpace.sm),
          for (final o in e.objectives) DsChecklistLine(o),
        ],
        if (e.items.isNotEmpty) ...[
          SizedBox(height: DsSpace.xs),
          if (itemsLabel != null) ...[
            Text(itemsLabel!, style: DsText.subtitle()),
            SizedBox(height: DsSpace.xs),
          ],
          DsCostGrid(e.items, key: ValueKey('$keyPrefix-items')),
        ],
        if (e.rewards.isNotEmpty) ...[
          SizedBox(height: DsSpace.sm),
          if (rewardsLabel != null) ...[
            Text(rewardsLabel!, style: DsText.subtitle()),
            SizedBox(height: DsSpace.xs),
          ],
          Wrap(
            key: ValueKey('$keyPrefix-rewards'),
            spacing: DsSpace.xs,
            runSpacing: DsSpace.xs,
            children: [
              for (final r in e.rewards)
                DsChip(r.label, color: r.color, tip: r.tip),
            ],
          ),
        ],
        if (e.notes.isNotEmpty) ...[
          SizedBox(height: DsSpace.sm),
          for (final n in e.notes) DsGoldText(n, style: DsText.meta()),
        ],
      ],
    );
  }
}
