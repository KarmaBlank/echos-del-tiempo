import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../app/theme/retro_bar.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../app/widgets/pixel_icon.dart';
import '../../../game_engine/data/build_templates_catalog.dart';
import '../../../game_engine/models/attributes.dart';
import '../../../game_engine/models/build_plan.dart';
import '../../../game_engine/models/item.dart' show ItemInstance;
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/rules/build_coach_rules.dart';
import '../../../game_engine/rules/build_guide_rules.dart';
import '../../../game_engine/rules/build_plan_rules.dart';
import 'build_fit_badge.dart' show kPlanColor;
import 'build_text.dart';

/// Vista simple de BUILD (build_planner.md § 10): elegir plantilla, "Qué
/// hacer ahora" y progreso por área plegable. Sin controles de edición:
/// esos viven en EDITAR PLAN.
class BuildCoachView extends StatelessWidget {
  const BuildCoachView({
    super.key,
    required this.rules,
    required this.profile,
    required this.plan,
    required this.progress,
    this.stash = const [],
    this.onApply,
    this.onChangeTemplate,
    this.onEdit,
    this.onOpenTree,
    this.onOpenAttributes,
    this.onOpenUlt,
    this.onOpenShop,
    this.onEquip,
    this.equipBlocked,
    this.editable = true,
  });

  final BuildPlanRules rules;
  final PlayerProfile profile;
  final BuildPlan plan;
  final BuildProgress progress;
  final List<ItemInstance> stash;
  final ValueChanged<BuildTemplate>? onApply;
  final VoidCallback? onChangeTemplate;
  final VoidCallback? onEdit;
  final VoidCallback? onOpenTree;
  final VoidCallback? onOpenAttributes;
  final VoidCallback? onOpenUlt;
  final VoidCallback? onOpenShop;
  final ValueChanged<String>? onEquip;
  final String? Function(String uid)? equipBlocked;
  final bool editable;

  BuildCoach get _coach => BuildCoach(rules);
  BuildGuideRules get _guide => BuildGuideRules(rules.progression);

  bool get _empty => plan.goalCount == 0;

  @override
  Widget build(BuildContext context) {
    final s = context.buildStrings;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _empty ? _chooser(s) : _withPlan(s),
      ),
    );
  }

  Widget _icon(Color c) => Builder(
      builder: (context) => PixelIcon(PixelIconKind.sword,
          size: RetroType.width(context, 14), color: c));

  static String _x(String s) => BuildCoach.expandShorts(s);

  // ------------------------------------------------------------------
  // 1. Sin plan: elegí una plantilla
  // ------------------------------------------------------------------

  List<Widget> _chooser(Strings s) {
    final list = buildTemplatesFor(profile.classId);
    return [
      DsSectionHeader(s.t('ui.build.coach.choose'),
          key: const ValueKey('build-choose')),
      if (list.isEmpty)
        Padding(
          padding: EdgeInsets.all(DsSpace.md),
          child: Text(retroText(s.t('ui.build.coach.no_templates')),
              style: DsText.detail()),
        ),
      for (final t in list) _templateRow(t, s),
      Padding(
        padding:
            EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
        child: Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: [
          if (editable && onChangeTemplate != null)
            DsButton(s.t('ui.build.coach.compare'),
                key: const ValueKey('build-template'),
                kind: DsButtonKind.ghost,
                size: DsButtonSize.compact,
                tooltip: s.t('ui.build.coach.compare_tip'),
                onPressed: onChangeTemplate),
          if (onEdit != null)
            DsButton(s.t('ui.build.coach.by_hand'),
                key: const ValueKey('build-edit'),
                kind: DsButtonKind.ghost,
                size: DsButtonSize.compact,
                tooltip: s.t('ui.build.coach.by_hand_tip'),
                onPressed: onEdit),
        ]),
      ),
    ];
  }

  Widget _templateRow(BuildTemplate t, Strings s) {
    final type = _coach.templateWeaponType(t);
    final line = t.description.split('\n').first.trim();
    return KeyedSubtree(
      key: ValueKey('build-tpl-${t.id}'),
      child: DsInfoRow(
        leading: _icon(kPlanColor),
        title: t.name,
        tags: [
          DsTag(BuildCoach.difficultyLabel(t.difficulty).toUpperCase(),
              key: ValueKey('build-tpl-diff-${t.id}'),
              color: switch (t.difficulty) {
                <= 1 => DsColors.success,
                2 => DsColors.reward,
                _ => DsColors.warning,
              }),
        ],
        subtitle: [
          if (line.isNotEmpty) line,
          if (type != null)
            s.t('ui.build.coach.weapon', {'type': BuildCoach.typeName(type)}),
        ].join('\n'),
        actions: [
          if (onApply != null)
            DsButton(s.t('ui.build.coach.apply'),
                key: ValueKey('build-apply-${t.id}'),
                kind: DsButtonKind.primary,
                size: DsButtonSize.compact,
                onPressed: () => onApply!(t)),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // 2. Con plan
  // ------------------------------------------------------------------

  List<Widget> _withPlan(Strings s) {
    final areas = _coach.areas(plan, profile, progress, stash: stash);
    return [
      _summary(s),
      DsSectionHeader(s.t('ui.build.coach.now'),
          key: const ValueKey('build-now')),
      ..._steps(s),
      Padding(
        padding:
            EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.xs),
        child: const DsLegend(key: ValueKey('build-legend')),
      ),
      DsSectionHeader(s.t('ui.build.coach.progress')),
      for (final a in areas)
        DsProgressFold(
          key: ValueKey('build-area-${a.area.name}'),
          title: a.area.label,
          done: a.done,
          total: a.total,
          child: _areaBody(a.area, s),
        ),
    ];
  }

  Widget _summary(Strings s) {
    final name = plan.name.isEmpty
        ? (plan.templateId == null
            ? s.t('ui.build.coach.own_plan')
            : buildTemplate(plan.templateId!)?.name ??
                s.t('ui.build.coach.own_plan'))
        : plan.name;
    final pct = (progress.ratio * 100).round();
    return Padding(
      key: const ValueKey('build-summary'),
      padding: EdgeInsets.all(DsSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: DsSpace.sm,
            runSpacing: DsSpace.xs,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                  retroText(s
                      .t('ui.build.coach.summary', {'name': name, 'pct': pct})),
                  key: const ValueKey('build-summary-name'),
                  style: DsText.body(kPlanColor)),
              Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: [
                if (editable)
                  DsButton(s.t('ui.build.coach.change_template'),
                      key: const ValueKey('build-template'),
                      size: DsButtonSize.compact,
                      onPressed: onChangeTemplate),
                if (onEdit != null)
                  DsButton(s.t('ui.build.coach.edit_plan'),
                      key: const ValueKey('build-edit'),
                      kind: DsButtonKind.ghost,
                      size: DsButtonSize.compact,
                      tooltip: s.t('ui.build.coach.edit_plan_tip'),
                      onPressed: onEdit),
              ]),
            ],
          ),
          SizedBox(height: DsSpace.xs),
          RetroBar(value: progress.ratio, max: 1, color: kPlanColor, height: 8),
        ],
      ),
    );
  }

  List<Widget> _steps(Strings s) {
    final steps =
        _coach.nextSteps(plan, profile, stash: stash, progress: progress);
    if (steps.isEmpty) {
      return [
        DsInfoRow(
          key: const ValueKey('build-step-none'),
          leading: const DsStatusMark(true),
          title: s.t('ui.build.coach.up_to_date'),
        ),
      ];
    }
    return [
      for (final (i, st) in steps.indexed)
        KeyedSubtree(
          key: ValueKey('build-step-$i'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              DsInfoRow(
                leading: Text('${i + 1}.', style: DsText.body(DsColors.reward)),
                title: st.text,
                actions: [if (_stepButton(st, i, s) case final b?) b],
              ),
              if (st.where.isNotEmpty) _where(st, i, s),
            ],
          ),
        ),
    ];
  }

  /// "Dónde la conseguís": sub-lista plegable bajo el paso (§ 10.2).
  Widget _where(BuildStep st, int i, Strings s) => Padding(
        key: ValueKey('build-step-where-$i'),
        padding: EdgeInsets.fromLTRB(DsSpace.lg, 0, DsSpace.md, DsSpace.xs),
        child: Align(
          alignment: Alignment.centerLeft,
          child: DsFold(
            label: s.t('ui.build.coach.where',
                {'kind': st.text.contains(' el mod ') ? 'mod' : 'other'}),
            tooltip: s.t('ui.build.coach.where_tip'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (j, w) in st.where.indexed)
                  Text(retroText('- ${_x(w)}'),
                      key: ValueKey('build-step-where-$i-$j'),
                      style: DsText.detail()),
              ],
            ),
          ),
        ),
      );

  Widget? _stepButton(BuildStep st, int i, Strings s) {
    DsButton b(String label, VoidCallback? on, {String? tooltip}) =>
        DsButton(label,
            key: ValueKey('build-step-go-$i'),
            size: DsButtonSize.compact,
            tooltip: tooltip,
            onPressed: on);
    return switch (st.action) {
      BuildStepAction.attributes when onOpenAttributes != null =>
        b(s.t('ui.build.action.go_attributes'), onOpenAttributes),
      BuildStepAction.tree when onOpenTree != null =>
        b(s.t('ui.build.action.go_tree'), onOpenTree),
      BuildStepAction.ult when onOpenUlt != null =>
        b(s.t('ui.build.action.go_ult'), onOpenUlt),
      BuildStepAction.armory when onOpenShop != null =>
        b(s.t('ui.build.action.go_shop'), onOpenShop),
      BuildStepAction.equip when onEquip != null && st.ref != null => () {
          final why = equipBlocked?.call(st.ref!);
          return b(s.t('ui.build.action.equip'),
              why == null ? () => onEquip!(st.ref!) : null,
              tooltip: why);
        }(),
      _ => null,
    };
  }

  // ------------------------------------------------------------------
  // 3. Detalle por área (plegado por defecto)
  // ------------------------------------------------------------------

  Widget _areaBody(BuildArea a, Strings s) {
    final rows = switch (a) {
      BuildArea.attributes => _attrRows(s),
      BuildArea.tree => _treeRows(s),
      BuildArea.weapon => _weaponRows(s),
      BuildArea.mods => _modRows(s),
      BuildArea.skills => _goalRows({BuildGoalKind.skill}),
      BuildArea.ult => _goalRows({
          BuildGoalKind.ultActive,
          BuildGoalKind.ultUpgrade,
          BuildGoalKind.feat
        }),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows.isEmpty
          ? [
              DsInfoRow(title: s.t('ui.build.coach.area_empty')),
            ]
          : rows,
    );
  }

  Widget _status(String key, bool done, String title, {String? sub}) =>
      KeyedSubtree(
        key: ValueKey(key),
        child: DsInfoRow(
          leading: DsStatusMark(done),
          title: title,
          subtitle: sub,
        ),
      );

  List<Widget> _attrRows(Strings s) => [
        for (final g in progress.goals)
          if (g.kind == BuildGoalKind.attribute)
            _status(
                'build-simple-${g.key}',
                g.done,
                s.t('ui.build.coach.attr_progress', {
                  'attr':
                      BuildCoach.attributeLabel(Attribute.values.byName(g.ref)),
                  'current': g.current,
                  'total': g.total,
                })),
      ];

  List<Widget> _treeRows(Strings s) {
    final goals = [
      for (final g in progress.goals)
        if (g.kind == BuildGoalKind.treeNode ||
            g.kind == BuildGoalKind.ascension ||
            g.kind == BuildGoalKind.ascensionNode)
          g
    ];
    final major = [
      for (final g in goals)
        if (g.kind != BuildGoalKind.treeNode || g.major) g
    ];
    final small = [
      for (final g in goals)
        if (g.kind == BuildGoalKind.treeNode && !g.major) g
    ];
    final smallDone = small.where((g) => g.done).length;
    return [
      for (final g in major)
        _status('build-simple-${g.key}', g.done, _x(g.label),
            sub: g.done || g.hint == null ? null : _x(g.hint!)),
      if (small.isNotEmpty)
        _status(
            'build-simple-tree-small',
            smallDone == small.length,
            s.t('ui.build.coach.path_nodes',
                {'done': smallDone, 'total': small.length})),
      if (onOpenTree != null)
        Padding(
          padding: EdgeInsets.symmetric(
              horizontal: DsSpace.md, vertical: DsSpace.xs),
          child: Align(
            alignment: Alignment.centerLeft,
            child: DsButton(s.t('ui.build.action.view_tree'),
                key: const ValueKey('build-simple-tree'),
                size: DsButtonSize.compact,
                onPressed: onOpenTree),
          ),
        ),
    ];
  }

  /// "Armas recomendadas" (§ 10.4): el mejor tipo con su motivo y tus
  /// armas con Ideal / Sirve / De paso; el % va al tooltip.
  List<Widget> _weaponRows(Strings s) {
    final advice = _guide.advice(plan, profile, stash: stash);
    final picks = _guide
        .rankItems(plan, profile, stash: stash)
        .where((w) => w.recommended)
        .take(3)
        .toList();
    final type = advice.activeType;
    final stashUids = {for (final s in stash) s.uid};
    return [
      Padding(
        padding: EdgeInsets.fromLTRB(DsSpace.md, DsSpace.xs, DsSpace.md, 0),
        child: Text(retroText(s.t('ui.build.coach.weapons')),
            key: const ValueKey('build-weapons'),
            style: DsText.detail(kPlanColor)),
      ),
      if (type.isNotEmpty)
        KeyedSubtree(
          key: const ValueKey('build-weapon-type'),
          child: DsInfoRow(
            leading: _icon(kPlanColor),
            title: s.t('ui.build.coach.best_type',
                {'type': BuildCoach.typeName(type)}),
            subtitle:
                advice.idealReason.isEmpty ? null : _x(advice.idealReason),
          ),
        ),
      for (final (i, w) in picks.indexed)
        () {
          final fit = _coach.fitOf(w, plan, advice);
          final moves = i == 0 && w.item != null
              ? _coach.transferableTo(w.item!, plan, profile, stash: stash)
              : const <String>[];
          final r = _coach.targetRatio(w, plan);
          final name = w.item == null
              ? w.base.name
              : rules.progression.items.displayName(w.item!);
          return DsTooltip(
            key: ValueKey('build-weapon-$i'),
            card: DsTooltipCard(title: retroText(name), children: [
              if (r != null)
                Text(
                    retroText(s.t('ui.build.coach.target_pct',
                        {'pct': (r * 100).round()})),
                    style: DsText.detail(kPlanColor)),
              for (final x in w.reasons)
                Text(retroText(_x(x)), style: DsText.detail()),
            ]),
            child: DsInfoRow(
              leading: _icon(DsColors.textSecondary),
              subtitle: moves.isEmpty
                  ? null
                  : [
                      s.t('ui.build.coach.fusion_moves'),
                      for (final m in moves) '- $m'
                    ].join('\n'),
              title: [
                name,
                if (w.equipped) s.t('ui.build.weapon.equipped'),
                if (stashUids.contains(w.item?.uid))
                  s.t('ui.build.weapon.in_stash'),
              ].join(' '),
              tags: [
                DsTag(fit.label.toUpperCase(),
                    key: ValueKey('build-weapon-fit-$i'),
                    color: switch (fit) {
                      WeaponFit.ideal => DsColors.success,
                      WeaponFit.works => DsColors.reward,
                      WeaponFit.stopgap => DsColors.textSecondary,
                    }),
              ],
            ),
          );
        }(),
    ];
  }

  /// "Mods buscados" (§ 10.5): uno por línea, nombre completo y nivel en
  /// palabras.
  List<Widget> _modRows(Strings s) {
    final mods = _coach.modsWanted(plan, profile, stash: stash);
    if (mods.isEmpty) return const [];
    return [
      Padding(
        padding: EdgeInsets.fromLTRB(DsSpace.md, DsSpace.xs, DsSpace.md, 0),
        child: Text(retroText(s.t('ui.build.coach.mods')),
            key: const ValueKey('build-mods'),
            style: DsText.detail(kPlanColor)),
      ),
      for (final m in mods)
        _status('build-mod-${m.affixId}', m.have, m.text, sub: m.status),
    ];
  }

  List<Widget> _goalRows(Set<BuildGoalKind> kinds) => [
        for (final g in progress.goals)
          if (kinds.contains(g.kind))
            _status('build-simple-${g.key}', g.done, _x(g.label),
                sub: g.done || g.hint == null ? null : _x(g.hint!)),
      ];
}
