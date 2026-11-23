import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../app/feature_flags.dart';
import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/retro_text.dart';
import '../../../core/data/build_template_loader.dart';
import '../../../game_engine/data/ascension_catalog.dart';
import '../../../game_engine/data/build_templates_catalog.dart';
import '../../../game_engine/data/ults_v2_catalog.dart';
import '../../../game_engine/models/attributes.dart';
import '../../../game_engine/models/build_plan.dart';
import '../../../game_engine/models/item.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/rules/build_guide_rules.dart';
import '../../../game_engine/rules/build_plan_rules.dart';
import '../../../game_engine/rules/build_template_rules.dart';
import '../../inventory/presentation/item_widgets.dart' hide PixelIcon;
import '../../passive_tree/presentation/passive_tree_view.dart';
import '../data/template_files.dart';
import 'build_fit_badge.dart' show kPlanColor;
import 'build_planner_view.dart' show PickOption, showBuildPicker;
import 'weapon_advice_block.dart';
import 'weapon_target_view.dart';

// BUILD v2 — plantillas (docs/specs/build_planner_v2.md § 2 y § 3): lista
// de la clase con filtro por etiqueta, vista con el árbol por nivel,
// slider, línea de tiempo, atributos, arma, SEGUIR / COMPARAR y
// exportar / importar a archivo.

/// Violeta de las Pruebas / ascensión: el del plan.
const _violet = kPlanColor;

Future<T?> _dialog<T>(BuildContext context, WidgetBuilder builder) =>
    showDialog<T>(
      context: context,
      barrierColor: ProtoColors.scrim(0.6),
      builder: (ctx) =>
          Material(type: MaterialType.transparency, child: builder(ctx)),
    );

/// PLANTILLA: devuelve el plan nuevo si se eligió SEGUIR ESTA PLANTILLA.
Future<BuildPlan?> showTemplateBrowser(
  BuildContext context, {
  required BuildPlanRules rules,
  required PlayerProfile profile,
  required BuildPlan plan,
  TemplateFiles files = const FileSelectorTemplateFiles(),
  List<ItemInstance> stash = const [],
  bool editable = true,
}) =>
    _dialog<BuildPlan>(
        context,
        (_) => TemplateBrowser(
            rules: rules,
            profile: profile,
            plan: plan,
            files: files,
            stash: stash,
            editable: editable));

class TemplateBrowser extends StatefulWidget {
  const TemplateBrowser({
    super.key,
    required this.rules,
    required this.profile,
    required this.plan,
    this.files = const FileSelectorTemplateFiles(),
    this.stash = const [],
    this.editable = true,
  });

  final BuildPlanRules rules;
  final PlayerProfile profile;
  final BuildPlan plan;
  final TemplateFiles files;
  final List<ItemInstance> stash;
  final bool editable;

  @override
  State<TemplateBrowser> createState() => _TemplateBrowserState();
}

class _TemplateBrowserState extends State<TemplateBrowser> {
  String? _id;
  String? _tag;
  String? _notice;
  bool _noticeError = false;

  PlayerProfile get _p => widget.profile;

  List<BuildTemplate> get _all => buildTemplatesFor(_p.classId);

  @override
  void initState() {
    super.initState();
    final mine = widget.plan.templateId;
    _id = _all.any((t) => t.id == mine) ? mine : _all.firstOrNull?.id;
  }

  void _say(String text, {bool error = false}) => setState(() {
        _notice = text;
        _noticeError = error;
      });

  Future<void> _import() async {
    final raw = await widget.files.pickYaml();
    if (raw == null) return;
    final f = BuildTemplateYaml.parse(raw, imported: true);
    final rules = BuildTemplateRules(widget.rules.progression);
    final ok = <BuildTemplate>[];
    final bad = <String>[...f.issues];
    for (final t in f.templates) {
      final errs = rules.validate(t);
      if (errs.isEmpty) {
        ok.add(t);
      } else {
        bad.add('${t.name}: ${errs.first}');
      }
    }
    final added = BuildTemplates.addImported(ok);
    final mine = added.where((t) => t.classId == _p.classId).toList();
    setState(() {
      if (mine.isNotEmpty) _id = mine.first.id;
    });
    if (added.isEmpty) {
      _say(bad.isEmpty ? 'El archivo no trae plantillas' : bad.first,
          error: true);
    } else {
      _say('Importadas ${added.length}'
          '${mine.length < added.length ? ' (${mine.length} de tu clase)' : ''}'
          '${bad.isEmpty ? '' : ' · ${bad.length} descartadas'}');
    }
  }

  Future<void> _export(List<BuildTemplate> list, String name) async {
    final ok = await widget.files.saveYaml(BuildTemplateYaml.write(list), name);
    if (ok) _say('Exportadas ${list.length} a $name');
  }

  @override
  Widget build(BuildContext context) {
    final all = _all;
    final tags = <String>{for (final t in all) ...t.tags}.toList()..sort();
    final list = [
      for (final t in all)
        if (_tag == null || t.tags.contains(_tag)) t
    ];
    final sel = all.where((t) => t.id == _id).firstOrNull;
    return PanelFrame(
      key: const ValueKey('template-browser'),
      title: 'PLANTILLAS',
      width: 1180,
      fill: true,
      onClose: () => Navigator.of(context).pop(),
      actions: [
        // main_dev: probar cambios del YAML sin recompilar (§ 2.2).
        if (FeatureFlags.instance.devTools)
          DsButton('RECARGAR PLANTILLAS',
              key: const ValueKey('tpl-reload'),
              kind: DsButtonKind.ghost, onPressed: () async {
            await BuildTemplateLoader.load();
            if (mounted) _say('Plantillas recargadas');
          }),
        DsButton('IMPORTAR',
            key: const ValueKey('tpl-import'), onPressed: _import),
        DsButton('EXPORTAR CLASE',
            key: const ValueKey('tpl-export-all'),
            onPressed: all.isEmpty
                ? null
                : () => _export(all, 'plantillas_${_p.classId}.yaml')),
        DsButton('CERRAR',
            key: const ValueKey('tpl-close'),
            onPressed: () => Navigator.of(context).pop()),
      ],
      child: LayoutBuilder(builder: (context, box) {
        final side = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Etiquetas en una sola fila que se desliza de costado: la
            // lista se queda con el alto (v0.24.4).
            SingleChildScrollView(
              key: const ValueKey('tpl-tag-bar'),
              scrollDirection: Axis.horizontal,
              child: Row(children: [
              for (final w in <Widget>[
              DsButton('TODAS',
                  key: const ValueKey('tpl-tag-all'),
                  size: DsButtonSize.compact,
                  kind: DsButtonKind.ghost,
                  selected: _tag == null,
                  onPressed: () => setState(() => _tag = null)),
              for (final t in tags)
                DsButton(retroText(t.toUpperCase()),
                    key: ValueKey('tpl-tag-$t'),
                    size: DsButtonSize.compact,
                    kind: DsButtonKind.ghost,
                    selected: _tag == t,
                    onPressed: () => setState(() => _tag = t)),
              ]) ...[w, SizedBox(width: DsSpace.xs)],
            ])),
            SizedBox(height: DsSpace.xs),
            for (final t in list)
              DsListRow(
                key: ValueKey('tpl-${t.id}'),
                leading: t.id == widget.plan.templateId
                    ? Text('★', style: DsText.body(DsColors.reward))
                    : null,
                // Nombre completo en su línea; dificultad y marcas abajo.
                wrap: true,
                title: retroText(t.name),
                subtitle: retroText('${'♦' * t.difficulty}'
                    '${t.imported ? ' · importada' : ''}'
                    '${t.isGroup ? ' · grupo' : ''}'),
                selected: t.id == _id,
                onTap: () => setState(() => _id = t.id),
              ),
            if (_notice != null)
              Padding(
                padding: EdgeInsets.all(DsSpace.sm),
                child: Text(retroText(_notice!),
                    key: const ValueKey('tpl-notice'),
                    style: DsText.detail(
                        _noticeError ? DsColors.danger : DsColors.success)),
              ),
          ],
        );
        final view = sel == null
            ? Text(retroText('Sin plantillas para tu clase'),
                style: DsText.detail())
            : TemplateView(
                key: ValueKey('tpl-view-${sel.id}'),
                rules: widget.rules,
                template: sel,
                profile: _p,
                plan: widget.plan,
                stash: widget.stash,
                editable: widget.editable,
                onExport: () => _export([sel], '${sel.id}.yaml'),
                onFollow: (p) => Navigator.of(context).pop(p),
              );
        if (box.maxWidth < 820) {
          return SingleChildScrollView(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [side, SizedBox(height: DsSpace.md), view]),
          );
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: math.min(300, box.maxWidth * 0.28),
              child: SingleChildScrollView(child: side)),
          SizedBox(width: DsSpace.md),
          Expanded(child: SingleChildScrollView(child: view)),
        ]);
      }),
    );
  }
}

/// Vista de una plantilla (§ 3): ficha, árbol con el camino por nivel,
/// slider 1–70 (50 + Maestría 20), línea de tiempo, atributos y arma al
/// nivel del slider, SEGUIR ESTA PLANTILLA y COMPARAR.
class TemplateView extends StatefulWidget {
  const TemplateView({
    super.key,
    required this.rules,
    required this.template,
    required this.profile,
    required this.plan,
    this.stash = const [],
    this.editable = true,
    this.onFollow,
    this.onExport,
    this.treeHeight = 320,
  });

  final BuildPlanRules rules;
  final BuildTemplate template;
  final PlayerProfile profile;
  final BuildPlan plan;
  final List<ItemInstance> stash;
  final bool editable;
  final ValueChanged<BuildPlan>? onFollow;
  final VoidCallback? onExport;
  final double treeHeight;

  @override
  State<TemplateView> createState() => _TemplateViewState();
}

class _TemplateViewState extends State<TemplateView> {
  late int _level = widget.profile.treeLevel.clamp(1, 70);
  List<String>? _compare;

  BuildTemplate get _t => widget.template;
  BuildTemplateRules get _tr => BuildTemplateRules(widget.rules.progression);

  String _node(String id) => widget.rules.nodeName(id);

  bool _major(String id) {
    final k = widget.rules.progression.treeRules.catalog.nodes[id]?.kind;
    return k == 'n' || k == 'k';
  }

  @override
  Widget build(BuildContext context) {
    final tl = _tr.timeline(_t);
    final next = tl.nextAfter(_level, _major);
    final taken = tl.takenAt(_level);
    final pts = math.min(BuildTemplateRules.pointsAt(_level), tl.points);
    final asc = kAscensions[_t.ascensionId];
    final p = widget.profile;
    // El árbol pinta tomado lo de la plantilla a ese nivel y en dorado
    // tenue el resto del camino; el próximo objetivo, en el texto.
    final shown = p.copyWith(
      level: math.min(_level, 50),
      mastery: math.max(0, _level - 50),
      tree: [
        for (final s in tl.steps)
          if (taken.contains(s.node)) s.node
      ],
      milestone10: () => null,
      milestone20: () => null,
    );
    final planned = {for (final s in tl.steps) s.node}..removeAll(taken);
    final lvlLabel = _level > 50 ? 'Maestría ${_level - 50}' : 'Nv $_level';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DsToolbar(
          title: '',
          center: Wrap(
            spacing: DsSpace.sm,
            runSpacing: DsSpace.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(retroText(_t.name),
                  key: const ValueKey('tpl-name'),
                  style: DsText.body(DsColors.reward)),
              for (final tag in _t.tags)
                DsTag(tag.toUpperCase(), color: DsColors.textSecondary),
              Text(retroText('dificultad ${'♦' * _t.difficulty}'),
                  style: DsText.detail()),
              if (asc != null)
                Text(retroText('· ${asc.name}'), style: DsText.detail()),
            ],
          ),
          actions: [
            DsButton.icon(Text('?', style: DsText.body()),
                key: const ValueKey('tpl-help'),
                tooltip: _t.description,
                size: DsButtonSize.compact,
                onPressed: () {}),
          ],
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: DsSpace.md),
          child: Text(retroText(_t.description), style: DsText.detail()),
        ),
        SizedBox(height: DsSpace.xs),
        LayoutBuilder(builder: (context, box) {
          // El visor arma su propia fila de arriba: crece en alto con el
          // texto grande en vez de desbordar.
          final tree = PassiveTreeView(
            key: const ValueKey('tpl-tree'),
            rules: widget.rules.progression.treeRules,
            profile: shown,
            inBattle: false,
            onTake: (_) {},
            showReset: false,
            showHelp: false,
            planned: planned,
            height: widget.treeHeight,
          );
          final timeline = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: DsSpace.xs),
              DsSlider(
                key: const ValueKey('tpl-slider'),
                value: _level,
                min: 1,
                max: BuildTemplateRules.maxTreeLevel,
                semanticLabel: 'Nivel de la plantilla',
                marks: _marks(),
                onChanged: (v) => setState(() {
                  _level = v;
                  _compare = null;
                }),
              ),
              Text(
                  retroText('$lvlLabel · $pts puntos'
                      '${next == null ? '' : ' · próximo: ${_node(next.node)} (Nv ${next.level > 50 ? 'M${next.level - 50}' : next.level})'}'),
                  key: const ValueKey('tpl-level'),
                  style: DsText.body()),
              DsTimeline(
                key: const ValueKey('tpl-timeline'),
                selected: _level,
                onSelect: (v) => setState(() => _level = v),
                marks: _timelineMarks(),
              ),
            ],
          );
          final side = _sideColumn(tl);
          if (box.maxWidth < 720) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [tree, timeline, side],
            );
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [tree, timeline])),
            SizedBox(width: DsSpace.md),
            SizedBox(width: math.min(340, box.maxWidth * 0.38), child: side),
          ]);
        }),
      ],
    );
  }

  Map<int, Color> _marks() => {
        10: DsColors.warning,
        20: DsColors.warning,
        30: _violet,
        40: _violet,
        50: _violet,
        for (final w in _t.weapons)
          w.level:
              w.rarity == null ? DsColors.reward : RarityColors.of(w.rarity!),
      };

  List<DsTimelineMark> _timelineMarks() {
    final out = <DsTimelineMark>[
      const DsTimelineMark(10, '10 HITO', color: DsColors.warning),
      const DsTimelineMark(20, '20 HITO', color: DsColors.warning),
      const DsTimelineMark(30, '30 PRUEBA I', color: _violet),
      const DsTimelineMark(40, '40 PRUEBA II', color: _violet),
      const DsTimelineMark(50, '50 PRUEBA III', color: _violet),
      for (final w in _t.weapons)
        DsTimelineMark(w.level, '${w.level} ARMA',
            key: ValueKey('tpl-mark-arma-${w.level}'),
            color: w.rarity == null
                ? DsColors.reward
                : RarityColors.of(w.rarity!)),
      if (_t.endgame.mastery.isNotEmpty)
        DsTimelineMark(
            50 + _t.endgame.mastery.map((m) => m.ms).reduce(math.max),
            'MAESTRÍA 1-20',
            color: DsColors.mp),
    ]..sort((a, b) => a.value.compareTo(b.value));
    return out;
  }

  Widget _sideColumn(TemplateTimeline tl) {
    final lvl = math.min(_level, 50);
    final attrs = _tr.attributesAt(_t.classId, _t.attributes, lvl);
    final plan = _tr.toPlan(_t);
    final target = plan.targetAt(lvl);
    final best = target == null
        ? null
        : widget.rules.targets
            .best(target, widget.profile, stash: widget.stash);
    final ult = kUltV2[_t.ultActive];
    return Column(
      key: const ValueKey('tpl-side'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DsSectionHeader('ATRIBUTOS AL NV $lvl'),
        for (final a in Attribute.values)
          DsStatLine(a.name.toUpperCase(), attrs[a], attrs[a],
              key: ValueKey('tpl-attr-${a.name}'),
              showChange: false,
              suffix: attrs[a] > kAttrSoftCap[a]!
                  ? 'pasa el tope ${kAttrSoftCap[a]}'
                  : null),
        const DsSectionHeader('ARMA'),
        if (target == null)
          Text(retroText('Sin arma objetivo'), style: DsText.detail())
        else
          WeaponTargetRow(
            key: const ValueKey('tpl-weapon'),
            rules: widget.rules.targets,
            target: target,
            best: best,
            onTap: () => showWeaponTargetDetail(context,
                rules: widget.rules,
                target: target,
                profile: widget.profile,
                stash: widget.stash,
                attributesAt: (l) =>
                    _tr.attributesAt(_t.classId, _t.attributes, l)),
          ),
        // Consejo de arma con el plan de la plantilla (§ 9.4).
        WeaponAdviceBlock(
          key: const ValueKey('tpl-advice'),
          advice: BuildGuideRules(widget.rules.progression).advice(
              plan.copyWith(chosenType: () => widget.plan.chosenType),
              widget.profile,
              stash: widget.stash),
          nameOf: widget.rules.progression.items.displayName,
          stashUids: {for (final s in widget.stash) s.uid},
        ),
        if (ult != null) ...[
          const DsSectionHeader('ULT ACTIVA'),
          DsListRow(
              title: retroText(ult.name),
              detail: retroText(_t.ultUpgrades.isEmpty
                  ? ult.how
                  : 'mejorar a nivel ${_t.ultUpgrades.values.reduce(math.max)}')),
        ],
        SizedBox(height: DsSpace.sm),
        Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: [
          if (widget.editable && widget.onFollow != null)
            DsButton('SEGUIR ESTA PLANTILLA',
                key: const ValueKey('tpl-follow'),
                kind: DsButtonKind.primary,
                onPressed: _follow),
          DsButton('COMPARAR',
              key: const ValueKey('tpl-compare'),
              onPressed: () => setState(() => _compare = _tr.compare(
                  _t,
                  {...widget.profile.passiveProgress.takenNodeIds},
                  widget.profile.attributes,
                  _level))),
          if (widget.onExport != null)
            DsButton('EXPORTAR',
                key: const ValueKey('tpl-export'),
                kind: DsButtonKind.ghost,
                onPressed: widget.onExport),
        ]),
        if (_compare != null) ...[
          DsSectionHeader('TU PERSONAJE VS. PLANTILLA AL $lvlLabelShort'),
          for (final l in _compare!)
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: DsSpace.md, vertical: DsSpace.xs),
              child: Text(retroText(l),
                  key: const ValueKey('tpl-compare-line'),
                  style: DsText.detail()),
            ),
        ],
      ],
    );
  }

  String get lvlLabelShort =>
      _level > 50 ? 'MAESTRÍA ${_level - 50}' : 'NV $_level';

  Future<void> _follow() async {
    if (widget.plan.goalCount > 0) {
      final ok = await showBuildPicker<bool>(
          context, '¿SEGUIR ESTA PLANTILLA?', const [
        PickOption(true, 'Sí, seguirla',
            'Reemplaza las metas; tus notas y tu checklist se quedan.',
            key: 'follow-yes'),
        PickOption(false, 'No', null, key: 'follow-no'),
      ]);
      if (ok != true || !mounted) return;
    }
    widget.onFollow?.call(_tr.follow(widget.plan, _t));
  }
}
