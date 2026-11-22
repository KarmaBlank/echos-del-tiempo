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
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _empty ? _chooser() : _withPlan(),
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

  List<Widget> _chooser() {
    final list = buildTemplatesFor(profile.classId);
    return [
      const DsSectionHeader('Elegí una plantilla',
          key: ValueKey('build-choose')),
      if (list.isEmpty)
        Padding(
          padding: EdgeInsets.all(DsSpace.md),
          child: Text(retroText('No hay plantillas para tu clase'),
              style: DsText.detail()),
        ),
      for (final t in list) _templateRow(t),
      Padding(
        padding:
            EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
        child: Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: [
          if (editable && onChangeTemplate != null)
            DsButton('COMPARAR PLANTILLAS',
                key: const ValueKey('build-template'),
                kind: DsButtonKind.ghost,
                size: DsButtonSize.compact,
                tooltip: 'Ver cada plantilla en detalle, importar o exportar',
                onPressed: onChangeTemplate),
          if (onEdit != null)
            DsButton('ARMAR A MANO',
                key: const ValueKey('build-edit'),
                kind: DsButtonKind.ghost,
                size: DsButtonSize.compact,
                tooltip: 'Editar plan: agregar metas una por una',
                onPressed: onEdit),
        ]),
      ),
    ];
  }

  Widget _templateRow(BuildTemplate t) {
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
          if (type != null) 'Arma: ${BuildCoach.typeName(type)}',
        ].join('\n'),
        actions: [
          if (onApply != null)
            DsButton('APLICAR',
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

  List<Widget> _withPlan() {
    final areas = _coach.areas(plan, profile, progress, stash: stash);
    return [
      _summary(),
      const DsSectionHeader('Qué hacer ahora', key: ValueKey('build-now')),
      ..._steps(),
      Padding(
        padding:
            EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.xs),
        child: const DsLegend(key: ValueKey('build-legend')),
      ),
      const DsSectionHeader('Tu progreso'),
      for (final a in areas)
        DsProgressFold(
          key: ValueKey('build-area-${a.area.name}'),
          title: a.area.label,
          done: a.done,
          total: a.total,
          child: _areaBody(a.area),
        ),
    ];
  }

  Widget _summary() {
    final name = plan.name.isEmpty
        ? (plan.templateId == null
            ? 'Plan propio'
            : buildTemplate(plan.templateId!)?.name ?? 'Plan propio')
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
              Text(retroText('Tu plan: $name  ·  $pct%'),
                  key: const ValueKey('build-summary-name'),
                  style: DsText.body(kPlanColor)),
              Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: [
                if (editable)
                  DsButton('CAMBIAR PLANTILLA',
                      key: const ValueKey('build-template'),
                      size: DsButtonSize.compact,
                      onPressed: onChangeTemplate),
                if (onEdit != null)
                  DsButton('EDITAR PLAN',
                      key: const ValueKey('build-edit'),
                      kind: DsButtonKind.ghost,
                      size: DsButtonSize.compact,
                      tooltip: 'Avanzado: agregar y quitar metas a mano',
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

  List<Widget> _steps() {
    final steps =
        _coach.nextSteps(plan, profile, stash: stash, progress: progress);
    if (steps.isEmpty) {
      return [
        const DsInfoRow(
          key: ValueKey('build-step-none'),
          leading: DsStatusMark(true),
          title: 'Estás al día con tu plan',
        ),
      ];
    }
    return [
      for (final (i, s) in steps.indexed)
        KeyedSubtree(
          key: ValueKey('build-step-$i'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              DsInfoRow(
                leading: Text('${i + 1}.', style: DsText.body(DsColors.reward)),
                title: s.text,
                actions: [if (_stepButton(s, i) case final b?) b],
              ),
              if (s.where.isNotEmpty) _where(s, i),
            ],
          ),
        ),
    ];
  }

  /// "Dónde la conseguís": sub-lista plegable bajo el paso (§ 10.2).
  Widget _where(BuildStep s, int i) => Padding(
        key: ValueKey('build-step-where-$i'),
        padding: EdgeInsets.fromLTRB(DsSpace.lg, 0, DsSpace.md, DsSpace.xs),
        child: Align(
          alignment: Alignment.centerLeft,
          child: DsFold(
            label: s.text.contains(' el mod ')
                ? 'DÓNDE LO CONSEGUÍS'
                : 'DÓNDE LA CONSEGUÍS',
            tooltip: 'De dónde sacarlo',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (j, w) in s.where.indexed)
                  Text(retroText('- ${_x(w)}'),
                      key: ValueKey('build-step-where-$i-$j'),
                      style: DsText.detail()),
              ],
            ),
          ),
        ),
      );

  Widget? _stepButton(BuildStep s, int i) {
    DsButton b(String label, VoidCallback? on, {String? tooltip}) =>
        DsButton(label,
            key: ValueKey('build-step-go-$i'),
            size: DsButtonSize.compact,
            tooltip: tooltip,
            onPressed: on);
    return switch (s.action) {
      BuildStepAction.attributes when onOpenAttributes != null =>
        b('IR A ATRIBUTOS', onOpenAttributes),
      BuildStepAction.tree when onOpenTree != null =>
        b('IR AL ÁRBOL', onOpenTree),
      BuildStepAction.ult when onOpenUlt != null => b('IR A ULT', onOpenUlt),
      BuildStepAction.armory when onOpenShop != null =>
        b('IR A LA ARMERÍA', onOpenShop),
      BuildStepAction.equip when onEquip != null && s.ref != null => () {
          final why = equipBlocked?.call(s.ref!);
          return b('EQUIPAR', why == null ? () => onEquip!(s.ref!) : null,
              tooltip: why);
        }(),
      _ => null,
    };
  }

  // ------------------------------------------------------------------
  // 3. Detalle por área (plegado por defecto)
  // ------------------------------------------------------------------

  Widget _areaBody(BuildArea a) {
    final rows = switch (a) {
      BuildArea.attributes => _attrRows(),
      BuildArea.tree => _treeRows(),
      BuildArea.weapon => _weaponRows(),
      BuildArea.mods => _modRows(),
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
              const DsInfoRow(title: 'Tu plan no pide nada en esta área'),
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

  List<Widget> _attrRows() => [
        for (final g in progress.goals)
          if (g.kind == BuildGoalKind.attribute)
            _status(
                'build-simple-${g.key}',
                g.done,
                '${BuildCoach.attributeLabel(Attribute.values.byName(g.ref))}: '
                    '${g.current} de ${g.total}'),
      ];

  List<Widget> _treeRows() {
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
        _status('build-simple-tree-small', smallDone == small.length,
            'Nodos de camino: $smallDone de ${small.length}'),
      if (onOpenTree != null)
        Padding(
          padding: EdgeInsets.symmetric(
              horizontal: DsSpace.md, vertical: DsSpace.xs),
          child: Align(
            alignment: Alignment.centerLeft,
            child: DsButton('VER EN EL ÁRBOL',
                key: const ValueKey('build-simple-tree'),
                size: DsButtonSize.compact,
                onPressed: onOpenTree),
          ),
        ),
    ];
  }

  /// "Armas recomendadas" (§ 10.4): el mejor tipo con su motivo y tus
  /// armas con Ideal / Sirve / De paso; el % va al tooltip.
  List<Widget> _weaponRows() {
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
        child: Text(retroText('Armas recomendadas'),
            key: const ValueKey('build-weapons'),
            style: DsText.detail(kPlanColor)),
      ),
      if (type.isNotEmpty)
        KeyedSubtree(
          key: const ValueKey('build-weapon-type'),
          child: DsInfoRow(
            leading: _icon(kPlanColor),
            title: 'Mejor tipo: ${BuildCoach.typeName(type)}',
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
                Text(retroText('${(r * 100).round()}% del arma objetivo'),
                    style: DsText.detail(kPlanColor)),
              for (final x in w.reasons)
                Text(retroText(_x(x)), style: DsText.detail()),
            ]),
            child: DsInfoRow(
              leading: _icon(DsColors.textSecondary),
              subtitle: moves.isEmpty
                  ? null
                  : ['Podés traerle en FUSIÓN:', for (final m in moves) '- $m']
                      .join('\n'),
              title: [
                name,
                if (w.equipped) '(equipada)',
                if (stashUids.contains(w.item?.uid)) '(alijo)',
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
  List<Widget> _modRows() {
    final mods = _coach.modsWanted(plan, profile, stash: stash);
    if (mods.isEmpty) return const [];
    return [
      Padding(
        padding: EdgeInsets.fromLTRB(DsSpace.md, DsSpace.xs, DsSpace.md, 0),
        child: Text(retroText('Mods buscados'),
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
