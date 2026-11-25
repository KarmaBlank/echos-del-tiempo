import '../../../../core/i18n/game_text.dart';
import '../../../../core/text/plain_text.dart';
import '../../../../core/text/text_detail.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../game_engine/data/bait_catalog.dart' show kBaits;
import '../../../../game_engine/data/cooking_catalog.dart' show kMeals;
import '../../../../game_engine/data/fishing_catalog.dart' show kRods;
import '../../../../game_engine/data/smithing_catalog.dart'
    show kSmithMaterials;
import '../../../../game_engine/models/item.dart' show CraftMaterial;
import '../../../../game_engine/models/player_profile.dart';
import '../../../../game_engine/rules/farming_rules.dart';
import '../../../../game_engine/rules/fishing_rules.dart';
import '../../../../game_engine/rules/life_tree_rules.dart';
import '../world_strings.dart';

/// Localized name of a life tree node.
String lifeNodeName(LifeTreeNode n) =>
    GameText.name('data.life_trees.node.${n.id}.name', n.name);

/// Localized name of branch [b] of [k].
String lifeBranchName(LifeSkillKind k, String b) =>
    GameText.name('data.life_trees.branch.${k.name}.$b', b.toUpperCase());

String _num(String fx, double v) => LifeFx.raw.contains(fx)
    ? (v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(2))
    : '${(v * 100).round()}';

/// Effect lines of [n] with the Balance numbers (life_trees_v2.md § 5).
List<String> lifeNodeEffects(BuildContext context, LifeTreeNode n) => [
      for (final e in n.effects.entries)
        context.t('ui.town.trades.fx.${e.key}',
            {'v': _num(e.key, LifeTreeRules.t.d(e.value))}),
    ];

String _itemName(String kind, String id) => switch (kind) {
      'mat' => GameText.name('ui.endgame.material.$id',
          CraftMaterial.values.where((m) => m.name == id).firstOrNull?.label ??
              id),
      'ore' => GameText.name(
          'data.materials.smith.$id.name', kSmithMaterials[id]?.name ?? id),
      'craft' => GameText.name('data.materials.life.$id.name', id),
      'bait' => GameText.name(
          'data.materials.bait.$id.name', kBaits[id]?.name ?? id),
      'rod' =>
        GameText.name('data.materials.rod.$id.name', kRods[id]?.name ?? id),
      'meal' => GameText.name(
          'data.materials.meal.$id.name', kMeals[id]?.name ?? id),
      _ => id,
    };

/// One-time reward lines of [n] (life_trees_v2.md § 4).
List<String> lifeNodeGrants(BuildContext context, LifeTreeNode n) {
  final out = <String>[];
  for (final e in n.grants.entries) {
    final parts = e.key.split(':');
    final amount = LifeTreeRules.amount(e.value);
    final id = parts.length > 1 ? parts[1] : '';
    out.add(switch (parts.first) {
      'gold' => context.t('ui.town.trades.grant.gold', {'n': amount}),
      'weapon' => context.t('ui.town.trades.grant.weapon', {'n': id}),
      'meal' => context.t('ui.town.trades.grant.meal', {
          'n': amount,
          'item': _itemName('meal', id),
          'q': context.t(
              'ui.town.crop_quality.${CropQuality.values[(int.tryParse(parts.length > 2 ? parts[2] : '0') ?? 0).clamp(0, CropQuality.values.length - 1)].name}'),
        }),
      _ => context.t('ui.town.trades.grant.item',
          {'n': amount, 'item': _itemName(parts.first, id)}),
    });
  }
  return out;
}

/// Full plain text of [n]: effects and rewards, one per line.
String lifeNodeText(BuildContext context, LifeTreeNode n) =>
    [...lifeNodeEffects(context, n), ...lifeNodeGrants(context, n)]
        .join('\n');

/// Pestaña OFICIOS de PERSONAJE (life_trees_v2.md § 3): profession cards,
/// the tree (5 branches × 10 tiers, the root at the bottom) and the
/// detail of the chosen node.
class LifeSkillsView extends StatefulWidget {
  const LifeSkillsView(
      {super.key,
      required this.profile,
      this.editBlocked,
      required this.onTake,
      required this.onReset});

  final PlayerProfile profile;

  /// Why it can't be touched now (e.g. in battle); `null` = it can.
  final String? editBlocked;
  final void Function(LifeSkillKind k, String node) onTake;
  final void Function(LifeSkillKind k) onReset;

  @override
  State<LifeSkillsView> createState() => _LifeSkillsViewState();
}

/// Visual state of a node.
enum LifeNodeState { taken, available, locked }

class _LifeSkillsViewState extends State<LifeSkillsView> {
  LifeSkillKind _kind = LifeSkillKind.pesca;
  String? _sel;

  PlayerProfile get p => widget.profile;

  static const _ruler = 44.0;
  static const _rowH = 76.0;
  static const _headH = 28.0;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 240,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final k in LifeSkillKind.values) ...[
                  _skillRow(k),
                  SizedBox(height: DsSpace.xs),
                ],
              ],
            ),
          ),
        ),
        SizedBox(width: DsSpace.md),
        Expanded(child: _tree()),
        SizedBox(width: DsSpace.md),
        SizedBox(width: 260, child: SingleChildScrollView(child: _detail())),
      ],
    );
  }

  LifeNodeState _state(LifeSkillKind k, LifeTreeNode n) =>
      LifeTreeRules.has(p, k, n.id)
          ? LifeNodeState.taken
          : LifeTreeRules.block(p, k, n.id) == null
              ? LifeNodeState.available
              : LifeNodeState.locked;

  Widget _skillRow(LifeSkillKind k) {
    final lvl = LifeTreeRules.level(p, k);
    final (cur, need) = switch (k) {
      LifeSkillKind.pesca => FishingRules.progress(p.life.fishXp),
      LifeSkillKind.cultivo => FarmingRules.progress(p.life.farm.xp),
      LifeSkillKind.herreria => SmithRules.progress(p.life.smithXp),
    };
    final free = LifeTreeRules.free(p, k);
    final tool = switch (k) {
      LifeSkillKind.pesca => kRods[p.life.rod]?.name ?? '',
      LifeSkillKind.cultivo =>
        '${kFarmTools[p.life.farm.hoe]?.name} · ${kFarmTools[p.life.farm.can]?.name}',
      LifeSkillKind.herreria => context.t('ui.town.trades.smith_tools'),
    };
    // Tarjeta del oficio (v0.24.4): nombre y puntos libres arriba, el
    // nivel grande, la XP con lo que falta y la barra; todo entero.
    return DsCard(
      key: ValueKey('life-row-${k.name}'),
      selected: _kind == k,
      onTap: () => setState(() {
        _kind = k;
        _sel = null;
      }),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Expanded(
                child: Text(k.label.toUpperCase(), style: DsText.subtitle())),
            if (free > 0)
              DsBadge(context.t('ui.town.trades.free', {'n': free}),
                  key: ValueKey('life-free-${k.name}')),
          ]),
          SizedBox(height: DsSpace.xs),
          Text(context.t('ui.town.trades.level', {'n': lvl}),
              key: ValueKey('life-level-${k.name}'),
              style: DsText.title(DsColors.reward)),
          SizedBox(height: DsSpace.xs),
          Text(
              need > 0
                  ? context.t('ui.town.trades.xp_left', {'xp': cur, 'need': need, 'left': need - cur})
                  : context.t('ui.town.trades.max_level'),
              style: DsText.body()),
          SizedBox(height: DsSpace.xs),
          DsPercent(need > 0 ? (cur * 100 ~/ need) : 100,
              key: ValueKey('life-xp-${k.name}'),
              label: context.t('ui.town.trades.xp_of', {'skill': k.label}),
              barWidth: 160),
          SizedBox(height: DsSpace.xs),
          Text(tool, style: DsText.detail()),
        ],
      ),
    );
  }

  Widget _detail() {
    final k = _kind;
    final nodes = kLifeTrees[k]!;
    final n = lifeTreeNode(k, _sel ?? '') ?? nodes.first;
    final has = LifeTreeRules.has(p, k, n.id);
    final blk = LifeTreeRules.block(p, k, n.id);
    final why = widget.editBlocked ??
        (blk == null
            ? null
            : context.t(blk.key, {
                'have': blk.have,
                'need': blk.need,
                'node': blk.node == null ? '' : lifeNodeName(blk.node!),
              }));
    final fx = lifeNodeEffects(context, n);
    final gr = lifeNodeGrants(context, n);
    final claimed = LifeTreeRules.claimed(p, n.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DsSectionHeader(lifeNodeName(n).toUpperCase(),
            trailing: Text(
                n.root
                    ? context.t('ui.town.trades.root')
                    : context.t('ui.town.trades.cost', {'n': n.cost}),
                style: DsText.detail())),
        if (n.branch != null)
          Text(
              context.t('ui.town.trades.tier_of',
                  {'branch': lifeBranchName(k, n.branch!), 'n': n.tier}),
              style: DsText.detail()),
        if (!n.root)
          Text(
              context.t('ui.town.trades.needs_level',
                  {'n': LifeTreeRules.tierLevel(n.tier)}),
              style: DsText.detail(
                  LifeTreeRules.level(p, k) >= LifeTreeRules.tierLevel(n.tier)
                      ? null
                      : DsColors.danger)),
        if (fx.isNotEmpty) ...[
          SizedBox(height: DsSpace.sm),
          Text(context.t('ui.town.trades.effects'), style: DsText.subtitle()),
          for (final l in fx) Text(l, style: DsText.body()),
        ],
        if (gr.isNotEmpty) ...[
          SizedBox(height: DsSpace.sm),
          Text(context.t('ui.town.trades.rewards'),
              style: DsText.subtitle(DsColors.reward)),
          for (final l in gr)
            Text(l,
                style: DsText.body(claimed ? DsColors.textDisabled : null)),
          if (claimed)
            Text(context.t('ui.town.trades.claimed'),
                key: const ValueKey('life-claimed'), style: DsText.detail()),
        ],
        if (n.capstone)
          Text(context.t('ui.town.trades.capstone'), style: DsText.detail()),
        SizedBox(height: DsSpace.sm),
        Text(
            has
                ? context.t('ui.town.trades.taken')
                : why ?? context.t('ui.town.trades.available'),
            key: const ValueKey('life-node-state'),
            style: DsText.detail()),
        SizedBox(height: DsSpace.sm),
        Text(
            context.t('ui.town.trades.points', {
              'free': LifeTreeRules.free(p, k),
              'earned': LifeTreeRules.earned(p, k)
            }),
            key: const ValueKey('life-points'),
            style: DsText.detail()),
        SizedBox(height: DsSpace.md),
        Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: [
          DsButton(context.t('ui.town.trades.reset'),
              key: const ValueKey('life-reset'),
              size: DsButtonSize.compact,
              onPressed: widget.editBlocked != null ||
                      LifeTreeRules.taken(p, k).isEmpty
                  ? null
                  : () => widget.onReset(k)),
          if (!has)
            DsButton(context.t('ui.town.trades.take'),
                key: const ValueKey('life-take'),
                kind: DsButtonKind.primary,
                size: DsButtonSize.compact,
                onPressed: why == null ? () => widget.onTake(k, n.id) : null),
        ]),
      ],
    );
  }

  /// Tree canvas: a header with the branch names, a level ruler on the
  /// left and one row per tier (capstones on top, the root at the bottom).
  Widget _tree() {
    final k = _kind;
    final nodes = kLifeTrees[k]!;
    return LayoutBuilder(builder: (context, box) {
      final colW = ((box.maxWidth - _ruler) / kLifeBranches.length)
          .clamp(56.0, 400.0)
          .toDouble();
      final w = _ruler + colW * kLifeBranches.length;
      const h = _headH + _rowH * (kLifeTiers + 1);
      Offset at(LifeTreeNode n) => Offset(_ruler + (n.x + 2.5) * colW,
          _headH + (kLifeTiers - n.tier + 0.5) * _rowH - 12);
      return SingleChildScrollView(
        key: const ValueKey('life-tree-scroll'),
        child: SizedBox(
          width: w,
          height: h,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned.fill(
                child: CustomPaint(
                    painter: _Links(k, p, nodes, at, _ruler, _headH, _rowH))),
            for (var i = 0; i < kLifeBranches.length; i++)
              Positioned(
                left: _ruler + i * colW,
                top: 0,
                width: colW,
                child: Text(lifeBranchName(k, kLifeBranches[i]).toUpperCase(),
                    key: ValueKey('life-branch-${kLifeBranches[i]}'),
                    textAlign: TextAlign.center,
                    style: DsText.detail(DsColors.textSubtitle)),
              ),
            for (var t = 1; t <= kLifeTiers; t++)
              Positioned(
                left: 0,
                top: _headH + (kLifeTiers - t) * _rowH + _rowH / 2 - 20,
                width: _ruler,
                child: Text(
                    context.t('ui.town.trades.tier',
                        {'n': LifeTreeRules.tierLevel(t)}),
                    style: DsText.detail(
                        LifeTreeRules.level(p, k) >= LifeTreeRules.tierLevel(t)
                            ? DsColors.textSecondary
                            : DsColors.textDisabled)),
              ),
            for (final n in nodes) _node(k, n, at(n), colW),
          ]),
        ),
      );
    });
  }

  Widget _node(LifeSkillKind k, LifeTreeNode n, Offset c, double colW) {
    final big = n.capstone || n.root;
    final size = big ? 36.0 : n.major ? 30.0 : 26.0;
    final st = _state(k, n);
    final sel = (_sel ?? kLifeTrees[k]!.first.id) == n.id;
    final hasGrant = n.grants.isNotEmpty;
    final claimed = LifeTreeRules.claimed(p, n.id);
    final fill = switch (st) {
      LifeNodeState.taken => DsColors.reward,
      LifeNodeState.available => DsColors.surfaceRaised,
      LifeNodeState.locked => DsColors.surfaceSunken,
    };
    final edge = sel
        ? DsColors.mp
        : switch (st) {
            LifeNodeState.taken => DsColors.reward,
            LifeNodeState.available => DsColors.success,
            LifeNodeState.locked => DsColors.border,
          };
    final text = lifeNodeText(context, n);
    return Positioned(
      left: c.dx - colW / 2,
      top: c.dy - size / 2,
      width: colW,
      child: DsTooltip(
        card: DsTooltipCard(title: lifeNodeName(n), detail: text, children: [
          Text(TextDetail.isSummary ? plainShort(text) : text,
              style: DsText.detail())
        ]),
        child: GestureDetector(
          key: ValueKey('life-node-${n.id}'),
          onTap: () => setState(() => _sel = n.id),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              key: ValueKey('life-node-${n.id}-${st.name}'),
              width: size,
              height: size,
              padding: EdgeInsets.all(big ? 3 : 0),
              decoration: BoxDecoration(
                color: fill,
                border: Border.all(color: edge, width: sel || big ? 3 : 2),
              ),
              child: Stack(children: [
                if (big)
                  Positioned.fill(
                    child: DecoratedBox(
                        decoration: BoxDecoration(
                            border: Border.all(color: edge, width: 1))),
                  ),
                Center(
                  child: Text(
                      st == LifeNodeState.taken || n.root ? '' : '${n.cost}',
                      style: DsText.detail(st == LifeNodeState.available
                          ? DsColors.success
                          : DsColors.textDisabled)),
                ),
                if (hasGrant)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                        width: 6,
                        height: 6,
                        color: claimed ? DsColors.textDisabled : DsColors.mp),
                  ),
              ]),
            ),
            const SizedBox(height: 2),
            // Opaque plate: links never show through the label.
            Container(
              key: ValueKey('life-label-${n.id}'),
              color: DsColors.background,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(lifeNodeName(n),
                  textAlign: TextAlign.center,
                  softWrap: true,
                  style: DsText.detail(st == LifeNodeState.locked
                      ? DsColors.textDisabled
                      : DsColors.textPrimary)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Links extends CustomPainter {
  _Links(this.k, this.p, this.nodes, this.at, this.ruler, this.head, this.rowH);
  final LifeSkillKind k;
  final PlayerProfile p;
  final List<LifeTreeNode> nodes;
  final Offset Function(LifeTreeNode) at;
  final double ruler, head, rowH;

  @override
  void paint(Canvas canvas, Size size) {
    // Faint tier rows behind the tree.
    final band = Paint()..color = DsColors.surfaceSunken.withValues(alpha: 0.35);
    for (var t = 0; t <= kLifeTiers; t += 2) {
      canvas.drawRect(
          Rect.fromLTWH(ruler, head + (kLifeTiers - t) * rowH,
              size.width - ruler, rowH),
          band);
    }
    final paint = Paint()..strokeWidth = 3;
    for (final n in nodes) {
      for (final l in n.links) {
        final o = lifeTreeNode(k, l);
        // Draw each edge once, from the lower tier up.
        if (o == null || o.tier >= n.tier) continue;
        final both =
            LifeTreeRules.has(p, k, n.id) && LifeTreeRules.has(p, k, o.id);
        paint.color = both ? DsColors.reward : DsColors.border;
        final a = at(o), b = at(n);
        // Pixel style: orthogonal elbow (up, across, up).
        final mid = (a.dy + b.dy) / 2;
        canvas.drawLine(a, Offset(a.dx, mid), paint);
        canvas.drawLine(Offset(a.dx, mid), Offset(b.dx, mid), paint);
        canvas.drawLine(Offset(b.dx, mid), b, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_Links old) => old.p != p || old.k != k;
}
