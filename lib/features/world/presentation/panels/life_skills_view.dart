import 'dart:math' as math;

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
import '../../../../game_engine/models/passive_tree.dart';
import '../../../passive_tree/domain/passive_text.dart' show TreeNodeState;
import '../../../passive_tree/presentation/skill_tree_canvas.dart';

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
      'recipe' => context.t('ui.town.trades.grant.recipe',
          {'item': context.t('ui.town.compost.$id')}),
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
/// the radial tree (5 branches x 10 tiers around the root) and the
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


class _LifeSkillsViewState extends State<LifeSkillsView> {
  LifeSkillKind _kind = LifeSkillKind.pesca;
  String? _sel;

  PlayerProfile get p => widget.profile;


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
                // Tree v2 refund (life_trees_v2.md § 6): until a node is
                // taken again.
                if (p.life.refunded) ...[
                  Container(
                    key: const ValueKey('life-refunded'),
                    padding: EdgeInsets.all(DsSpace.sm),
                    decoration: BoxDecoration(
                        border: Border.all(color: DsColors.reward)),
                    child: Text(context.t('ui.town.trades.refunded'),
                        style: DsText.body(DsColors.reward)),
                  ),
                  SizedBox(height: DsSpace.xs),
                ],
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
        SizedBox(width: 300, child: SingleChildScrollView(child: _detail())),
      ],
    );
  }

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
          Text(tool, style: DsText.body()),
        ],
      ),
    );
  }

  Widget _detail() {
    final k = _kind;
    final nodes = kLifeTrees[k]!;
    final n = lifeTreeNode(k, _sel ?? '') ?? nodes.first;
    final has = LifeTreeRules.has(p, k, n.id);
    final why = widget.editBlocked ?? _why(k, n);
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
                style: DsText.body())),
        if (n.branch != null)
          Text(
              context.t('ui.town.trades.tier_of',
                  {'branch': lifeBranchName(k, n.branch!), 'n': n.tier}),
              style: DsText.body()),
        if (!n.root)
          Text(
              context.t('ui.town.trades.needs_level',
                  {'n': LifeTreeRules.tierLevel(n.tier)}),
              style: DsText.body(
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
                key: const ValueKey('life-claimed'), style: DsText.body()),
        ],
        if (n.capstone)
          Text(context.t('ui.town.trades.capstone'), style: DsText.body()),
        SizedBox(height: DsSpace.sm),
        Text(has ? _stateText(k, n) : why ?? _stateText(k, n),
            key: const ValueKey('life-node-state'),
            style: DsText.body()),
        SizedBox(height: DsSpace.sm),
        Text(
            context.t('ui.town.trades.points', {
              'free': LifeTreeRules.free(p, k),
              'earned': LifeTreeRules.earned(p, k)
            }),
            key: const ValueKey('life-points'),
            style: DsText.body()),
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

  /// The tree, drawn by the shared skill-tree organism (life_trees_v2.md
  /// § 3): the root in the centre, the five branches as spokes and one
  /// level-gate ring per tier. Names live in the hover card and the
  /// detail pane, never next to the nodes.
  Widget _tree() {
    final k = _kind;
    final cat = _catalog(context, k);
    final lvl = LifeTreeRules.level(p, k);
    return SkillTreeCanvas(
      key: ValueKey('life-tree-${k.name}'),
      keyPrefix: 'life-node',
      labelScale: 1.6,
      catalog: cat,
      startId: kLifeTrees[k]!.first.id,
      selected: _sel ?? kLifeTrees[k]!.first.id,
      states: {
        for (final n in kLifeTrees[k]!) n.id: _state(k, n),
      },
      gates: [
        for (var t = 1; t <= kLifeTiers; t++)
          SkillTreeGate(lifeTierY(t), lifeGateHalf(t, k),
              open: lvl >= LifeTreeRules.tierLevel(t)),
      ],
      onSelect: (id) => setState(() => _sel = id),
      tooltip: (id) {
        final n = lifeTreeNode(k, id)!;
        final text = lifeNodeText(context, n);
        return DsTooltipCard(
            title: lifeNodeName(n),
            titleColor: n.capstone ? DsColors.reward : null,
            detail: text,
            children: [
              if (text.isNotEmpty)
                Text(TextDetail.isSummary ? plainShort(text) : text,
                    style: DsText.body()),
              // Why it can't be taken is KEY INFO (design_system.md § 3.4).
              Text(_stateText(k, n),
                  style: _why(k, n) != null && !LifeTreeRules.has(p, k, n.id)
                      ? DsText.key()
                      : DsText.muted()),
            ]);
      },
    );
  }

  /// Why [n] can't be taken now (`null` = it can).
  String? _why(LifeSkillKind k, LifeTreeNode n) {
    final blk = LifeTreeRules.block(p, k, n.id);
    return blk == null
        ? null
        : context.t(blk.key, {
            'have': blk.have,
            'need': blk.need,
            'node': blk.node == null ? '' : lifeNodeName(blk.node!),
          });
  }

  String _stateText(LifeSkillKind k, LifeTreeNode n) =>
      LifeTreeRules.has(p, k, n.id)
          ? context.t('ui.town.trades.taken')
          : _why(k, n) ?? context.t('ui.town.trades.available');

  /// One catalog per profession and language (the painters cache by
  /// identity).
  static final _catalogs = <(LifeSkillKind, String), PassiveTreeCatalog>{};

  PassiveTreeCatalog _catalog(BuildContext context, LifeSkillKind k) {
    final branches = [for (final b in lifeBranchesOf(k)) lifeBranchName(k, b)];
    final tiers = [
      for (var t = 1; t <= kLifeTiers; t++)
        context.t('ui.town.trades.tier', {'n': LifeTreeRules.tierLevel(t)})
    ];
    final groups = {
      for (final g in ['crops', 'animals'])
        g: context.t('data.life_trees.group.$g'),
    };
    return _catalogs.putIfAbsent(
        (k, [...branches, ...tiers, ...groups.values].join('|')),
        () => lifeTreeCatalog(k, branches, tiers, groups: groups));
  }

  TreeNodeState _state(LifeSkillKind k, LifeTreeNode n) => n.root
      ? TreeNodeState.start
      : LifeTreeRules.has(p, k, n.id)
          ? TreeNodeState.taken
          : LifeTreeRules.block(p, k, n.id) == null
              ? TreeNodeState.available
              : TreeNodeState.locked;
}

/// Height (tree units, up is negative) of tier [t]: the root sits at the
/// bottom and the tree grows up.
double lifeTierY(int t) => t == 0 ? 0.0 : -(1.0 + 1.05 * t);

/// Horizontal spread of the branches at tier [t]: they leave the root
/// close together and open like a canopy.
double _spread(int t) => t == 0 ? 0.0 : 0.7 + 1.15 * math.sqrt(t);

/// Side offset of the two sub-paths of a fork at tier [t].
double _forkOffset(int t) => t == kLifeForkFrom || t == kLifeForkTo ? 0.5 : 0.7;

/// Position (tree units) of node [n] (life_trees_v2.md § 3).
/// With n branches the fan is centred: branch i sits at i − (n − 1) / 2
/// (life_trees_v2.md § 8).
Offset lifeNodePos(LifeTreeNode n, [LifeSkillKind? k]) {
  if (n.root) return Offset.zero;
  final bs = k == null ? kLifeBranches : lifeBranchesOf(k);
  final i = bs.indexOf(n.branch!) - (bs.length - 1) / 2;
  var x = i * _spread(n.tier);
  if (n.tier >= kLifeForkFrom && n.tier <= kLifeForkTo) {
    // The sub-path that leans outward is the second one; the middle
    // branch forks to the right.
    final out = i < 0 ? -1.0 : 1.0;
    x += (isLifeFork(n) ? out : -out) * _forkOffset(n.tier);
  }
  return Offset(x, lifeTierY(n.tier));
}

/// Centre (tree units) of the branches of [k] in group [g].
double _groupX(LifeSkillKind k, List<String> bs, String g, double mid) {
  final xs = [
    for (var i = 0; i < bs.length; i++)
      if (lifeBranchGroup(k, bs[i]) == g) (i - mid) * _spread(kLifeTiers)
  ];
  return xs.reduce((a, b) => a + b) / xs.length;
}

/// Width (tree units) of the level-gate line of tier [t].
double lifeGateHalf(int t, [LifeSkillKind? k]) =>
    (((k == null ? kLifeBranches : lifeBranchesOf(k)).length - 1) / 2) *
        _spread(t) +
    1.2;

/// Profession tree [k] as a skill-tree catalog (life_trees_v2.md § 3):
/// root → start node, capstones → keystones, major nodes → notables;
/// [branches] and [tiers] are the localized labels drawn on the canvas.
PassiveTreeCatalog lifeTreeCatalog(
    LifeSkillKind k, List<String> branches, List<String> tiers,
    {Map<String, String> groups = const {}}) {
  final bs = lifeBranchesOf(k);
  final mid = (bs.length - 1) / 2;
  final nodes = <String, PassiveNode>{};
  for (final n in kLifeTrees[k]!) {
    final o = lifeNodePos(n, k);
    nodes[n.id] = PassiveNode(
      id: n.id,
      x: o.dx,
      y: o.dy,
      name: n.name,
      effects: const {},
      kind: n.root
          ? 'st'
          : n.capstone
              ? 'k'
              : n.major
                  ? 'n'
                  : 's',
      links: n.links,
      pathId: n.branch == null ? null : 'life_${k.name}_${n.branch}',
    );
  }
  final top = lifeTierY(kLifeTiers) - 1.1;
  final left = -lifeGateHalf(kLifeTiers, k) - 1.0;
  return PassiveTreeCatalog(
    nodes: nodes,
    startNodeByClass: const {},
    exclusions: const {},
    paths: {
      for (var i = 0; i < bs.length; i++)
        'life_${k.name}_${bs[i]}': PassivePath(
          id: 'life_${k.name}_${bs[i]}',
          name: branches[i],
          theme: '',
          classId: k.name,
          kind: 'grupo',
          labelX: (i - mid) * _spread(kLifeTiers),
          labelY: top,
        ),
      // Group headings above the branch names (CULTIVOS / ANIMALES).
      for (final g in ['crops', 'animals'])
        if (groups[g] != null &&
            bs.any((b) => lifeBranchGroup(k, b) == g))
          'life_group_$g': PassivePath(
            id: 'life_group_$g',
            name: groups[g]!,
            theme: '',
            classId: k.name,
            kind: 'grupo',
            labelX: _groupX(k, bs, g, mid),
            labelY: top - 0.9,
          ),
      // Level gates: a "Nv N" tick at the left end of each tier line.
      for (var t = 1; t <= kLifeTiers; t++)
        'life_tier_$t': PassivePath(
          id: 'life_tier_$t',
          name: tiers[t - 1],
          theme: '',
          classId: k.name,
          labelX: left,
          labelY: lifeTierY(t),
        ),
    },
  );
}
