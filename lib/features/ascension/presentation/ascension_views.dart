import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/catalog_names.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../app/theme/panel_frame.dart';
import '../../../core/text/plain_text.dart';
import '../../../core/text/text_detail.dart';
import '../../../game_engine/models/player_state.dart';
import '../../../game_engine/rules/stats_calculator.dart' show ascConditionTimes;
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../game_engine/data/ascension_catalog.dart';
import '../../../game_engine/data/skills_catalog.dart';
import '../../../game_engine/models/ascension.dart';
import '../../../game_engine/rules/ascension_rules.dart';
import '../../combat/domain/skill_text.dart';
import '../../combat/presentation/game_sprites.dart';
import '../../combat/presentation/pixel_sprite.dart';
import '../domain/ascension_text.dart';
import '../../../core/i18n/i18n_providers.dart';

/// Ficha de una ascensión (markup): tema, kit y nodo raíz.
String ascensionCardMarkup(Strings t, AscensionDef a) {
  final hex = ascensionHex(a);
  final skills = [
    for (final id in a.skillIds)
      if (kSkills[id] case final s?) s,
  ];
  final ult = kAscensionUltimatesById[a.ultId];
  final root = a.node(a.rootId);
  return '<b style="color:$hex">${protoEsc(a.tr.toUpperCase())}</b><br>'
      '${protoColor(ProtoColors.dim, protoEsc(a.themeTr))}<br>'
      '${protoColor(ProtoColors.cream, protoEsc(a.mottoTr))}<br>'
      '${t.t('ui.ascension.card.awakening', {'name': protoEsc(root?.tr ?? '')})}<br>'
      '${protoEsc(root?.textTr ?? '')}<br>'
      '${t.t('ui.ascension.card.kit')}<br>'
      '${[
    for (final s in skills)
      '· <b>${protoEsc(s.tr)}</b> ${protoColor(ProtoColors.ice, '${s.mp} MP')}',
    if (ult != null)
      '· ${protoColor(ProtoColors.pink, '★ ULT ${protoEsc(ult.tr)}')}',
  ].join('<br>')}';
}

/// El sprite del héroe ascendido (o el base si no hay arte) con su aura.
class AscendedHero extends StatelessWidget {
  const AscendedHero({
    super.key,
    required this.sprites,
    required this.classId,
    required this.ascensionId,
    this.scale = 4,
  });

  final GameSprites? sprites;
  final String classId;
  final String? ascensionId;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final img = sprites?.heroFor(classId, ascensionId);
    final aura = sprites?.aura(ascensionId);
    final a = ascensionFor(classId, ascensionId);
    return SizedBox(
      width: 26 * scale,
      height: 28 * scale,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          if (aura != null)
            Positioned(
              bottom: 0,
              child: PixelSprite(aura, scale: scale, opacity: 0.8),
            )
          else if (a != null)
            Positioned(
              bottom: 0,
              child: Container(
                width: 20 * scale,
                height: 24 * scale,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(a.color).withValues(alpha: 0.18),
                ),
              ),
            ),
          if (img != null)
            Positioned(
              bottom: scale,
              child: PixelSprite(img, scale: scale),
            ),
        ],
      ),
    );
  }
}

/// Las 2 ascensiones de una clase para elegir (§ 2): dos tarjetas con el
/// héroe ascendido, la ficha y ELEGIR.
class AscensionChoiceView extends ConsumerWidget {
  const AscensionChoiceView({
    super.key,
    required this.classId,
    required this.sprites,
    required this.onChoose,
    this.blocked,
  });

  final String classId;
  final GameSprites? sprites;
  final ValueChanged<String> onChoose;

  /// Por qué no se puede elegir (botones deshabilitados).
  final String? blocked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ascensionsOf(classId);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, a) in options.indexed) ...[
          if (i > 0) const SizedBox(width: 16),
          Expanded(child: _card(ref, a)),
        ],
      ],
    );
  }

  Widget _card(WidgetRef ref, AscensionDef a) {
    final col = Color(a.color);
    return Container(
      key: ValueKey('asc-card-${a.id}'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: col.withValues(alpha: 0.06),
        border: Border.all(color: col, width: RetroTheme.thinBorderWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Héroe al costado de la ficha (no arriba): el kit entra sin bajar.
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AscendedHero(
                    sprites: sprites,
                    classId: classId,
                    ascensionId: a.id,
                    scale: 3),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    child: ProtoText(ascensionCardMarkup(ref.strings, a)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: PanelButton(
                ref.t('ui.ascension.choose',
                    {'name': a.tr.toUpperCase()}),
                key: ValueKey('asc-choose-${a.id}'),
                accent: col,
                reason: blocked,
                onPressed: () => onChoose(a.id)),
          ),
        ],
      ),
    );
  }
}

//// The ascension tree v2 (ascension.md § 3.6): 5 branches × 10 tiers on
/// a pixel canvas, hover tooltip and the selected node's detail on the
/// right.
class AscensionTreeView extends ConsumerStatefulWidget {
  const AscensionTreeView({
    super.key,
    required this.def,
    required this.progress,
    this.sprites,
    this.build,
    this.editBlocked,
    this.onTake,
    this.onReset,
    this.onChange,
  });

  final AscensionDef def;
  final AscensionProgress progress;
  final GameSprites? sprites;

  /// The hero's build, to tell whether the Trades conditions hold now
  /// (`null` = unknown: every condition counts as met).
  final PlayerBuild? build;
  final String? editBlocked;
  final ValueChanged<String>? onTake;
  final VoidCallback? onReset;

  /// Sacar la ascensión (volver a elegir); `null` = no se puede ahora.
  final VoidCallback? onChange;

  /// Columns (branches) and rows (tiers 0–10) of the canvas.
  static const cols = AscTree.branches, rows = AscTree.tiers + 1;

  /// Smallest cell (px) before the canvas scrolls.
  static const minCell = 40.0;

  @override
  ConsumerState<AscensionTreeView> createState() => _AscensionTreeViewState();
}

/// Visual state of a node (§ 3.6).
enum AscNodeState { taken, inactive, available, locked }

class _AscensionTreeViewState extends ConsumerState<AscensionTreeView> {
  static const _rules = AscensionRules();
  String? _sel;

  AscensionProgress get p => widget.progress;
  AscensionDef get a => widget.def;

  String? _why(AscensionNode n) {
    if (_rules.has(p, n.id)) return null;
    final free = _rules.free(p);
    if (free < n.cost) {
      return ref.t('ui.ascension.node.missing_points',
          {'free': free, 'cost': n.cost});
    }
    if (!n.links.any((l) => _rules.has(p, l))) {
      return ref.t('ui.ascension.node.not_linked');
    }
    if (n.capstone &&
        _rules.capstones(p) >= AscensionRules.maxCapstones) {
      return ref.t('ui.ascension.node.capstone_cap');
    }
    return null;
  }

  bool _active(AscensionNode n) {
    final b = widget.build;
    if (b == null || n.condition == AscCondition.none) return true;
    return ascConditionTimes(n.condition, b) > 0;
  }

  AscNodeState _stateOf(AscensionNode n) {
    if (_rules.has(p, n.id)) {
      return _active(n) ? AscNodeState.taken : AscNodeState.inactive;
    }
    return _why(n) == null ? AscNodeState.available : AscNodeState.locked;
  }

  String _stateText(AscensionNode n) {
    if (_rules.has(p, n.id)) {
      if (!_active(n)) {
        return ref.t('ui.ascension.node.inactive',
            {'why': ref.t('ui.ascension.cond.${n.condition.name}')});
      }
      return ref.t(n.root
          ? 'ui.ascension.node.awakened'
          : 'ui.ascension.node.taken');
    }
    return _why(n) ?? ref.t('ui.ascension.node.available');
  }

  /// The node text for the active TEXTOS mode (RESUMIDO: first sentence).
  String _text(AscensionNode n) {
    final full = ascNodeText(n);
    return TextDetail.isSummary ? plainShort(full) : full;
  }

  @override
  Widget build(BuildContext context) {
    final node = a.node(_sel ?? '') ?? a.node(a.rootId)!;
    final col = Color(a.color);
    final taken = _rules.has(p, node.id);
    final why = widget.editBlocked ?? _why(node);
    final cls = classNameTr(a.classId);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: LayoutBuilder(builder: (context, box) {
            // One extra column on the left for the tier numbers.
            final cell = math.max(
                AscensionTreeView.minCell,
                math.min(box.maxWidth / (AscensionTreeView.cols + 0.6),
                    (box.maxHeight - 28) / AscensionTreeView.rows));
            final gutter = cell * 0.6;
            final w = gutter + cell * AscensionTreeView.cols;
            final h = cell * AscensionTreeView.rows;
            Offset at(AscensionNode n) => Offset(
                gutter + (n.x + 0.5) * cell, (n.y + 0.5) * cell);
            return SingleChildScrollView(
              child: Center(
                child: SizedBox(
                  width: w,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 28,
                        child: Row(children: [
                          SizedBox(width: gutter),
                          for (var i = 0; i < AscensionTreeView.cols; i++)
                            SizedBox(
                              key: ValueKey('asc-branch-$i'),
                              width: cell,
                              child: Text(ascBranchName(a, i).toUpperCase(),
                                  textAlign: TextAlign.center,
                                  softWrap: true,
                                  textScaler: RetroType.fixedScaler(context),
                                  style: DsText.detail(i < 3
                                      ? col
                                      : DsColors.textSecondary)),
                            ),
                        ]),
                      ),
                      SizedBox(
                        width: w,
                        height: h,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: CustomPaint(
                                  painter: AscTreeLinks(a, p, at, col)),
                            ),
                            for (var t = 1; t <= AscTree.tiers; t++)
                              Positioned(
                                left: 0,
                                top: (t + 0.5) * cell - 8,
                                width: gutter,
                                child: Text('$t',
                                    textAlign: TextAlign.center,
                                    textScaler:
                                        RetroType.fixedScaler(context),
                                    style: DsText.detail()),
                              ),
                            for (final n in a.nodes)
                              _node(n, at(n), cell, col),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
        SizedBox(width: DsSpace.md),
        SizedBox(
          // Crece con el texto (sin pasar de 45 % de la pantalla).
          width: RetroType.width(context, 340)
              .clamp(340.0, MediaQuery.sizeOf(context).width * 0.45),
          child: DsDetailPane(
            actions: Wrap(
              alignment: WrapAlignment.end,
              spacing: DsSpace.sm,
              runSpacing: DsSpace.xs,
              children: [
                PanelButton(ref.t('ui.ascension.reset'),
                    key: const ValueKey('asc-reset'),
                    onPressed: widget.editBlocked != null || p.nodes.isEmpty
                        ? null
                        : widget.onReset),
                PanelButton(ref.t('ui.ascension.change'),
                    key: const ValueKey('asc-change'),
                    onPressed: widget.onChange),
                if (!taken)
                  PanelButton(ref.t('ui.ascension.take'),
                      key: const ValueKey('asc-take'),
                      accent: ProtoColors.green,
                      reason: why,
                      onPressed: () => widget.onTake?.call(node.id)),
              ],
            ),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Primero el nodo elegido (lo que se decide).
                ProtoText(
                    key: const ValueKey('asc-node-detail'),
                    '<b>${protoEsc(ascNodeName(a, node))}</b><br>'
                    '${protoColor(node.capstone ? ProtoColors.gold : ProtoColors.dim, protoEsc(node.root ? ref.t('ui.ascension.node.root') : '${ascNodeKindText(node)} · ${ref.t('ui.ascension.tier', {'n': node.tier})} · ${ascBranchName(a, node.branch)}'))}<br>'
                    '${protoEsc(_text(node))}<br>'
                    '${protoColor(ProtoColors.dim, protoEsc(_stateText(node)))}'),
                SizedBox(height: DsSpace.sm),
                ProtoText(
                    key: const ValueKey('asc-points'),
                    ref.t('ui.ascension.points', {
                      'free': _rules.free(p),
                      'earned': p.earned,
                      'max': TrialNumbers.count *
                          AscensionProgress.pointsPerTrial,
                    })),
                SizedBox(height: DsSpace.sm),
                Row(
                  children: [
                    AscendedHero(
                        sprites: widget.sprites,
                        classId: a.classId,
                        ascensionId: a.id,
                        scale: 2),
                    SizedBox(width: DsSpace.sm),
                    Expanded(
                      child: ProtoText(
                          '<b style="color:${ascensionHex(a)}">'
                          '${protoEsc(a.tr.toUpperCase())}</b><br>'
                          '${protoColor(ProtoColors.dim, '${protoEsc(cls)} · ${protoEsc(a.themeTr)}')}'),
                    ),
                  ],
                ),
                if (node.root) ...[
                  SizedBox(height: DsSpace.sm),
                  for (final id in a.skillIds)
                    if (kSkills[id] case final s?)
                      ProtoText(describeSkillMarkup(s, null)),
                  if (kAscensionUltimatesById[a.ultId] case final u?)
                    ProtoText(describeSkillMarkup(u, null,
                        ultimate: true, nameColor: '#e84393')),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  double _size(AscensionNode n, double cell) => switch (n.kind) {
        AscNodeKind.root || AscNodeKind.capstone => 0.62,
        AscNodeKind.major => 0.54,
        AscNodeKind.notable => 0.5,
        AscNodeKind.minor => 0.36,
      } *
      cell;

  Widget _node(AscensionNode n, Offset c, double cell, Color col) {
    final size = _size(n, cell);
    final st = _stateOf(n);
    final selected = (_sel ?? a.rootId) == n.id;
    final name = ascNodeName(a, n);
    final full = ascNodeText(n);
    return Positioned(
      left: c.dx - size / 2,
      top: c.dy - size / 2,
      width: size,
      height: size,
      child: DsTooltip(
        card: DsTooltipCard(
          title: name,
          titleColor: n.capstone ? DsColors.reward : col,
          detail: full,
          tags: [
            DsTag(
                n.root
                    ? ref.t('ui.ascension.node.root')
                    : ascNodeKindText(n),
                color: n.capstone ? DsColors.reward : DsColors.border),
          ],
          children: [
            Text(_text(n), style: DsText.body()),
            SizedBox(height: DsSpace.xs),
            Text(_stateText(n), style: DsText.detail()),
          ],
        ),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            key: ValueKey('asc-node-${n.id}'),
            onTap: () => setState(() => _sel = n.id),
            child: AscNodeGlyph(
              kind: n.kind,
              state: st,
              color: col,
              selected: selected,
              label: st == AscNodeState.available ? '${n.cost}' : '',
            ),
          ),
        ),
      ),
    );
  }
}

/// A pixel node of the ascension tree (purely visual, § 3.6): its shape
/// says the kind, its fill and border the state.
class AscNodeGlyph extends StatelessWidget {
  const AscNodeGlyph({
    super.key,
    required this.kind,
    required this.state,
    required this.color,
    this.selected = false,
    this.label = '',
  });

  final AscNodeKind kind;
  final AscNodeState state;
  final Color color;
  final bool selected;
  final String label;

  @override
  Widget build(BuildContext context) {
    final fill = switch (state) {
      AscNodeState.taken => color,
      AscNodeState.inactive => color.withValues(alpha: 0.4),
      _ => DsColors.surfaceSunken,
    };
    final border = selected
        ? ProtoColors.white
        : switch (state) {
            AscNodeState.locked => DsColors.border,
            _ => kind == AscNodeKind.capstone ? DsColors.reward : color,
          };
    final width = selected || state == AscNodeState.available ? 3.0 : 2.0;
    Widget box = Container(
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: border, width: width),
      ),
      padding: kind == AscNodeKind.capstone ? const EdgeInsets.all(3) : null,
      child: kind == AscNodeKind.capstone
          ? Container(
              decoration: BoxDecoration(
                  border: Border.all(
                      color: state == AscNodeState.locked
                          ? DsColors.border
                          : DsColors.reward,
                      width: 2)))
          : null,
    );
    if (kind == AscNodeKind.notable) {
      // Diamond: the square turned 45° (it fits inside the cell).
      box = Transform.rotate(
          angle: math.pi / 4, child: FractionallySizedBox(
              widthFactor: 0.72, heightFactor: 0.72, child: box));
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(child: box),
        if (label.isNotEmpty)
          Text(label,
              textScaler: RetroType.fixedScaler(context),
              style: DsText.subtitle(color)),
      ],
    );
  }
}

/// Links of the tree (§ 3.6): 2 px, the ascension color when both ends
/// are taken, grey otherwise.
class AscTreeLinks extends CustomPainter {
  AscTreeLinks(this.a, this.p, this.at, this.color);

  final AscensionDef a;
  final AscensionProgress p;
  final Offset Function(AscensionNode) at;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const rules = AscensionRules();
    final paint = Paint()
      ..strokeWidth = 2
      ..isAntiAlias = false;
    for (final n in a.nodes) {
      for (final l in n.links) {
        final o = a.node(l);
        if (o == null || o.tier < n.tier) continue;
        if (o.tier == n.tier && o.id.compareTo(n.id) < 0) continue;
        final both = rules.has(p, n.id) && rules.has(p, o.id);
        paint.color = both ? color : DsColors.border;
        final s = at(n), e = at(o);
        if (s.dx == e.dx) {
          canvas.drawLine(s, e, paint);
        } else {
          // Pixel elbow: down from the root, across, then down.
          final mid = Offset(s.dx, (s.dy + e.dy) / 2);
          canvas
            ..drawLine(s, mid, paint)
            ..drawLine(mid, Offset(e.dx, mid.dy), paint)
            ..drawLine(Offset(e.dx, mid.dy), e, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(AscTreeLinks old) => old.p != p || old.a != a;
}

// Texto de los títulos del panel (`retroText`).
String ascensionPanelTitle(Strings t, AscensionDef? a) => retroText(a == null
    ? t.t('ui.ascension.title')
    : t.t('ui.ascension.title_with', {'name': a.tr}));
