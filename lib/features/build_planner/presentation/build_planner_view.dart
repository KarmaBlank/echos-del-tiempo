import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/retro_bar.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../app/widgets/pixel_icon.dart';
import '../../../game_engine/data/affixes_catalog.dart';
import '../../../game_engine/data/ascension_catalog.dart';
import '../../../game_engine/data/build_templates_catalog.dart';
import '../../../game_engine/data/weapon_passives.dart';
import '../../../game_engine/models/attributes.dart';
import '../../../game_engine/models/build_plan.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/rules/attribute_advisor.dart';
import '../../../game_engine/rules/build_plan_rules.dart';
import '../../passive_tree/presentation/passive_tree_view.dart';
import 'build_fit_badge.dart';

/// Pantalla BUILD (docs/specs/build_planner.md § 4): progreso total,
/// siguiente paso, tarjetas por sección con su checklist y, con
/// [onChanged], edición (agregar / quitar metas, plantillas, árbol en
/// modo planificar). Sin [onChanged] es de solo lectura.
class BuildPlannerView extends StatefulWidget {
  const BuildPlannerView({
    super.key,
    required this.rules,
    required this.profile,
    required this.plan,
    this.onChanged,
    this.treeHeight = 360,
  });

  final BuildPlanRules rules;
  final PlayerProfile profile;
  final BuildPlan plan;
  final ValueChanged<BuildPlan>? onChanged;

  /// Alto del árbol en modo planificar.
  final double treeHeight;

  static const help = '<b>Build</b><br>'
      'Armá un plan para tu personaje: atributos, nodos del árbol, '
      'ascensión, arma, mods y habilidades. El progreso se calcula solo '
      'con lo que tenés.<br>'
      '<span class="k">PLANTILLA</span>: un plan listo de tu clase.<br>'
      '<span class="k">★ Tu build</span>: marca en la tienda, el inventario '
      'y la fusión lo que sirve para el plan.<br>'
      'Cuando una meta avanza aparece un aviso (se apaga en Configuración › '
      'Juego › Avisos de build).<br>'
      '<span class="k">ATRIBUTOS</span>: ej. FUE 40; al subir de nivel te '
      'recuerda dónde poner los puntos. APLICAR SUGERENCIA agrega como metas '
      'el reparto sugerido para tus puntos libres y los de los próximos '
      'niveles.<br>'
      '<span class="k">ÁRBOL</span>: marcá notables y keystones; + CAMINOS '
      'agrega los nodos que los conectan.<br>'
      '<span class="k">ASCENSIÓN</span>: una de las 2 de tu clase y sus '
      'nodos.<br>'
      '<span class="k">ARMA</span>: tipo o base, mods con tier mínimo y '
      'pasiva.<br>'
      'Pasá el mouse por una meta para ver qué falta.';

  @override
  State<BuildPlannerView> createState() => _BuildPlannerViewState();
}

class _BuildPlannerViewState extends State<BuildPlannerView> {
  bool _tree = false;
  late final _notes = TextEditingController(text: widget.plan.notes);
  bool _notesDirty = false;

  bool get _editable => widget.onChanged != null;
  BuildPlan get _plan => widget.plan;
  BuildPlanRules get _rules => widget.rules;
  PlayerProfile get _p => widget.profile;

  @override
  void didUpdateWidget(BuildPlannerView old) {
    super.didUpdateWidget(old);
    if (!_notesDirty && old.plan.notes != widget.plan.notes) {
      _notes.text = widget.plan.notes;
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  void _set(BuildPlan p) => widget.onChanged?.call(p);

  @override
  Widget build(BuildContext context) {
    if (_tree) return _treeMode();
    final progress = _rules.evaluate(_plan, _p);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(progress),
        const SizedBox(height: 8),
        Expanded(
          child: SingleChildScrollView(
            child: LayoutBuilder(builder: (context, box) {
              final left = [
                _attributes(progress),
                _treeCard(progress),
                _ascension(progress),
                _level(progress),
              ];
              final right = [
                _weapon(progress),
                _skills(progress),
                _notesCard(progress),
              ];
              if (box.maxWidth < 640) {
                return Column(children: [...left, ...right]);
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Column(children: left)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(children: right)),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // Encabezado
  // ------------------------------------------------------------------

  Widget _header(BuildProgress progress) {
    final pct = (progress.ratio * 100).round();
    final name = _plan.name.isEmpty ? 'Plan sin nombre' : _plan.name;
    final counted = progress.counted.length;
    return Column(
      key: const ValueKey('build-header'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DsToolbar(
          title: '',
          center: Row(mainAxisSize: MainAxisSize.min, children: [
            PixelIcon(PixelIconKind.star,
                size: RetroType.width(context, 16), color: kPlanColor),
            SizedBox(width: DsSpace.sm),
            Flexible(
              child: Text.rich(
                key: const ValueKey('build-name'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                TextSpan(children: [
                  TextSpan(
                      text: retroText(name), style: DsText.body(kPlanColor)),
                  TextSpan(
                      text: retroText(
                          '  ${progress.doneCount}/$counted metas'),
                      style: DsText.detail()),
                ]),
              ),
            ),
            SizedBox(width: DsSpace.sm),
            Text('$pct%',
                key: const ValueKey('build-percent'),
                style: DsText.body(kPlanColor)),
          ]),
          actions: [
            if (_editable) ...[
              DsButton('PLANTILLA',
                  key: const ValueKey('build-template'),
                  size: DsButtonSize.compact,
                  onPressed: _chooseTemplate),
              DsButton('RENOMBRAR',
                  key: const ValueKey('build-rename'),
                  kind: DsButtonKind.ghost,
                  size: DsButtonSize.compact,
                  onPressed: _rename),
              DsButton('BORRAR PLAN',
                  key: const ValueKey('build-clear'),
                  kind: DsButtonKind.ghost,
                  size: DsButtonSize.compact,
                  onPressed: _plan.isEmpty ? null : _clear),
            ],
          ],
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: DsSpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: DsSpace.xs),
              RetroBar(
                  value: progress.ratio, max: 1, color: kPlanColor, height: 8),
              SizedBox(height: DsSpace.xs),
              Text.rich(
                key: const ValueKey('build-next'),
                TextSpan(children: [
                  TextSpan(
                      text: retroText('Siguiente paso: '),
                      style: DsText.detail()),
                  TextSpan(
                      text: retroText(progress.next),
                      style: DsText.body(DsColors.reward)),
                ]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // Secciones
  // ------------------------------------------------------------------

  Widget _card(BuildSection s, BuildProgress progress, List<Widget> rows,
      {VoidCallback? onAdd}) {
    final goals = progress.section(s);
    final done = goals.where((g) => g.done).length;
    return Column(
      key: ValueKey('build-section-${s.name}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DsSectionHeader(
          goals.isEmpty ? s.label : '${s.label}  $done/${goals.length}',
          trailing: _editable && onAdd != null
              ? DsButton('+ AGREGAR',
                  key: ValueKey('build-add-${s.name}'),
                  kind: DsButtonKind.ghost,
                  size: DsButtonSize.compact,
                  onPressed: onAdd)
              : null,
        ),
        if (rows.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: DsSpace.md, vertical: DsSpace.xs),
            child: Text(retroText('Sin metas'), style: DsText.detail()),
          )
        else
          ...rows,
      ],
    );
  }

  /// Una meta en una fila (design_system.md § 6, DsListRow): marca, nombre,
  /// avance o motivo; la pista va al tooltip.
  Widget _row(GoalStatus g,
      {VoidCallback? onRemove, Widget? trailing, VoidCallback? onToggle}) {
    final blocked = g.state == GoalState.blocked;
    final detail = blocked && g.hint != null
        ? g.hint!
        : g.countable
            ? '${g.current}/${g.total}'
            : null;
    final toggle = onToggle != null && _editable;
    return DsListRow(
      key: ValueKey('build-goal-${g.key}'),
      leading: toggle
          ? KeyedSubtree(
              key: ValueKey('build-toggle-${g.key}'), child: GoalMark(g.state))
          : GoalMark(g.state),
      title: retroText(g.label),
      titleColor: g.done ? DsColors.success : null,
      detail: detail == null ? null : retroText(detail),
      detailColor: blocked
          ? DsColors.danger
          : g.done
              ? DsColors.success
              : DsColors.mp,
      onTap: toggle ? onToggle : null,
      tooltip: g.hint == null || blocked
          ? null
          : DsTooltipCard(title: retroText(g.label), children: [
              Text(retroText(g.hint!), style: DsText.detail()),
            ]),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (trailing != null) trailing,
        if (_editable && onRemove != null) ...[
          SizedBox(width: DsSpace.xs),
          DsButton.icon(Text('×', style: DsText.body(DsColors.danger)),
              key: ValueKey('build-remove-${g.key}'),
              tooltip: 'Quitar meta',
              size: DsButtonSize.compact,
              onPressed: onRemove),
        ],
      ]),
    );
  }

  Widget _attributes(BuildProgress progress) {
    return _card(
      BuildSection.attributes,
      progress,
      [
        if (_advice() case final w?) w,
        for (final g in progress.section(BuildSection.attributes))
          _row(g,
              trailing: _editable ? _stepper(g) : null,
              onRemove: () => _set(_plan.copyWith(attributes: {
                    for (final e in _plan.attributes.entries)
                      if (e.key.name != g.ref) e.key: e.value,
                  }))),
      ],
      onAdd: _addAttribute,
    );
  }

  /// "Atributos sugeridos" (build_planner.md § 8.5): el reparto del
  /// asesor para tus puntos libres + los de los próximos 5 niveles, y
  /// APLICAR SUGERENCIA (las agrega como metas). El porqué, en el tooltip.
  Widget? _advice() {
    final pts = AttributeAdvisor.horizonPoints(_p);
    final s = AttributeAdvisor(_rules.progression).recommend(_p, _plan, pts);
    if (s.isEmpty) return null;
    final goals = AttributeAdvisor.addAsGoals(_plan, _p, s);
    final why = s.first.reasons.isEmpty ? null : s.first.reasons.first;
    final same = goals == _plan;
    return Padding(
      key: const ValueKey('build-attr-advice'),
      padding: EdgeInsets.symmetric(
          horizontal: DsSpace.md, vertical: DsSpace.xs),
      child: Wrap(
        spacing: DsSpace.sm,
        runSpacing: DsSpace.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
              retroText('Atributos sugeridos ($pts puntos: libres y '
                  'próximos niveles): ${AttributeAdvisor.split(s)}'),
              key: const ValueKey('build-attr-advice-split'),
              style: DsText.body(DsColors.reward)),
          if (_editable)
            DsButton('APLICAR SUGERENCIA',
                key: const ValueKey('build-advice-goals'),
                kind: DsButtonKind.primary,
                size: DsButtonSize.compact,
                tooltip: same ? 'Ya están en tus metas' : why,
                onPressed: same ? null : () => _set(goals)),
        ],
      ),
    );
  }

  Widget _stepper(GoalStatus g) {
    final a = Attribute.values.byName(g.ref);
    void bump(int d) {
      final v = ((_plan.attributes[a] ?? 0) + d).clamp(1, 200);
      _set(_plan.copyWith(attributes: {..._plan.attributes, a: v}));
    }

    return Row(mainAxisSize: MainAxisSize.min, children: [
      DsButton.icon(Text('-5', style: DsText.body(DsColors.mp)),
          key: ValueKey('build-dec-${g.ref}'),
          tooltip: 'Bajar el objetivo 5',
          size: DsButtonSize.compact,
          onPressed: () => bump(-5)),
      SizedBox(width: DsSpace.xs),
      DsButton.icon(Text('+5', style: DsText.body(DsColors.mp)),
          key: ValueKey('build-inc-${g.ref}'),
          tooltip: 'Subir el objetivo 5',
          size: DsButtonSize.compact,
          onPressed: () => bump(5)),
    ]);
  }

  Widget _treeCard(BuildProgress progress) {
    final goals = progress.section(BuildSection.tree);
    final major = goals.where((g) => g.major).toList();
    final small = goals.where((g) => !g.major).toList();
    final smallDone = small.where((g) => g.done).length;
    return _card(
      BuildSection.tree,
      progress,
      [
        for (final g in major)
          _row(g, onRemove: () => _set(_plan.toggleTreeNode(g.ref))),
        if (small.isNotEmpty)
          DsListRow(
            key: const ValueKey('build-tree-small'),
            title: retroText('Nodos de camino'),
            detail: '$smallDone/${small.length}',
            detailColor:
                smallDone == small.length ? DsColors.success : DsColors.mp,
          ),
        Padding(
          padding: EdgeInsets.symmetric(
              horizontal: DsSpace.md, vertical: DsSpace.xs),
          child: Align(
            alignment: Alignment.centerLeft,
            child: DsButton(
                _editable ? 'PLANIFICAR EN EL ÁRBOL' : 'VER EN EL ÁRBOL',
                key: const ValueKey('build-open-tree'),
                size: DsButtonSize.compact,
                accent: kPlanColor,
                onPressed: () => setState(() => _tree = true)),
          ),
        ),
      ],
    );
  }

  Widget _ascension(BuildProgress progress) {
    return _card(
      BuildSection.ascension,
      progress,
      [
        for (final g in progress.section(BuildSection.ascension))
          _row(g,
              onRemove: () => _set(g.kind == BuildGoalKind.ascension
                  ? _plan.copyWith(
                      ascensionId: () => null, ascensionNodes: const [])
                  : _plan.copyWith(ascensionNodes: [
                      for (final n in _plan.ascensionNodes)
                        if (n != g.ref) n
                    ]))),
      ],
      onAdd: _addAscension,
    );
  }

  Widget _weapon(BuildProgress progress) {
    BuildPlan without(GoalStatus g) => switch (g.kind) {
          BuildGoalKind.weaponType => _plan.copyWith(weaponTypes: [
              for (final t in _plan.weaponTypes)
                if (t != g.ref) t
            ]),
          BuildGoalKind.weaponBase => _plan.copyWith(weaponBases: [
              for (final t in _plan.weaponBases)
                if (t != g.ref) t
            ]),
          BuildGoalKind.mod => _plan.copyWith(mods: [
              for (final m in _plan.mods)
                if (m.affixId != g.ref) m
            ]),
          _ => _plan.copyWith(weaponPassive: () => null),
        };
    return _card(
      BuildSection.weapon,
      progress,
      [
        for (final g in progress.section(BuildSection.weapon))
          _row(g, onRemove: () => _set(without(g))),
      ],
      onAdd: _addWeapon,
    );
  }

  Widget _skills(BuildProgress progress) => _card(
        BuildSection.skills,
        progress,
        [
          for (final g in progress.section(BuildSection.skills))
            _row(g,
                onRemove: () => _set(_plan.copyWith(skills: [
                      for (final s in _plan.skills)
                        if (s != g.ref) s
                    ]))),
        ],
        onAdd: _addSkill,
      );

  Widget _level(BuildProgress progress) => _card(
        BuildSection.level,
        progress,
        [
          for (final g in progress.section(BuildSection.level))
            _row(g,
                onRemove: () => _set(g.kind == BuildGoalKind.level
                    ? _plan.copyWith(targetLevel: () => null)
                    : _plan.copyWith(targetMastery: () => null))),
        ],
        onAdd: _addLevel,
      );

  Widget _notesCard(BuildProgress progress) {
    final checks = progress.section(BuildSection.notes);
    return _card(
      BuildSection.notes,
      progress,
      [
        for (final g in checks)
          _row(g, onToggle: () {
            final i = int.parse(g.ref);
            _set(_plan.copyWith(checklist: [
              for (var k = 0; k < _plan.checklist.length; k++)
                k == i ? _plan.checklist[k].toggled() : _plan.checklist[k],
            ]));
          }, onRemove: () {
            final i = int.parse(g.ref);
            _set(_plan.copyWith(checklist: [
              for (var k = 0; k < _plan.checklist.length; k++)
                if (k != i) _plan.checklist[k],
            ]));
          }),
        if (_editable || _plan.notes.isNotEmpty) ...[
          SizedBox(height: DsSpace.xs),
          if (_editable)
            TextField(
              key: const ValueKey('build-notes'),
              controller: _notes,
              maxLines: 3,
              minLines: 2,
              maxLength: BuildPlan.maxNotes,
              style: RetroType.smallStyle,
              decoration: const InputDecoration(
                  hintText: 'Notas libres...',
                  isDense: true,
                  counterText: '',
                  contentPadding: EdgeInsets.all(6)),
              onChanged: (_) {
                if (!_notesDirty) setState(() => _notesDirty = true);
              },
            )
          else
            Text(retroText(_plan.notes), style: DsText.body()),
          if (_notesDirty)
            Align(
              alignment: Alignment.centerRight,
              child: DsButton('GUARDAR NOTAS',
                  key: const ValueKey('build-notes-save'),
                  kind: DsButtonKind.primary,
                  size: DsButtonSize.compact, onPressed: () {
                setState(() => _notesDirty = false);
                _set(_plan.copyWith(notes: _notes.text.trim()));
              }),
            ),
        ],
      ],
      onAdd: _addCheck,
    );
  }

  // ------------------------------------------------------------------
  // Árbol en modo planificar
  // ------------------------------------------------------------------

  Widget _treeMode() {
    final planned = _plan.treeNodes.toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DsToolbar(
          title: '',
          center: Row(mainAxisSize: MainAxisSize.min, children: [
            DsButton('< VOLVER AL PLAN',
                key: const ValueKey('build-tree-back'),
                kind: DsButtonKind.ghost,
                size: DsButtonSize.compact,
                onPressed: () => setState(() => _tree = false)),
            SizedBox(width: DsSpace.sm),
            Flexible(
              child: Text(
                  retroText(_editable
                      ? 'PLANIFICAR · ${planned.length} nodos en el plan'
                      : '${planned.length} nodos en el plan'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DsText.body(kPlanColor)),
            ),
          ]),
          actions: [
            if (_editable)
              DsButton('+ CAMINOS',
                  key: const ValueKey('build-tree-paths'),
                  size: DsButtonSize.compact,
                  tooltip: planned.isEmpty
                      ? 'Marcá un nodo primero'
                      : 'Agrega los nodos que conectan lo marcado',
                  onPressed: planned.isEmpty
                      ? null
                      : () => _set(_rules.withTreePaths(_plan, _p.classId,
                          taken: _p.passiveProgress))),
          ],
        ),
        SizedBox(height: DsSpace.xs),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              child: PassiveTreeView(
                key: const ValueKey('build-tree'),
                rules: _rules.progression.treeRules,
                profile: _p,
                inBattle: false,
                onTake: (_) {},
                showReset: false,
                showHelp: false,
                planned: planned,
                onPlan:
                    _editable ? (id) => _set(_plan.toggleTreeNode(id)) : null,
                height: (box.maxHeight - 60).clamp(220.0, widget.treeHeight),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // Edición
  // ------------------------------------------------------------------

  Future<T?> _pick<T>(String title, List<PickOption<T>> options) =>
      showBuildPicker<T>(context, title, options);

  Future<void> _chooseTemplate() async {
    final list = buildTemplatesFor(_p.classId);
    final t = await _pick<BuildTemplate>(
      _plan.goalCount == 0
          ? 'PLANTILLA'
          : 'PLANTILLA (reemplaza las metas; notas y checklist se quedan)',
      [
        for (final t in list)
          PickOption(t, t.name, t.description, key: 'tpl-${t.id}'),
      ],
    );
    if (t == null) return;
    _set(_rules.applyTemplate(_plan, t));
  }

  Future<void> _rename() async {
    final name = await showBuildTextDialog(context, 'NOMBRE DEL PLAN',
        initial: _plan.name, maxLength: BuildPlan.maxName);
    if (name == null) return;
    _set(_plan.copyWith(name: name));
  }

  Future<void> _clear() async {
    final ok = await _pick<bool>('¿BORRAR EL PLAN?', const [
      PickOption(true, 'Sí, borrar', 'Se borran metas, notas y checklist.',
          key: 'clear-yes'),
      PickOption(false, 'No', null, key: 'clear-no'),
    ]);
    if (ok == true) _set(BuildPlan.empty);
  }

  Future<void> _addAttribute() async {
    final a = await _pick<Attribute>('ATRIBUTO', [
      for (final a in Attribute.values)
        PickOption(
            a, BuildPlanRules.attributeShort(a), 'tenés ${_p.attributes[a]}',
            key: 'attr-${a.name}'),
    ]);
    if (a == null) return;
    final cur = _p.attributes[a];
    final base = ((cur + 5) / 5).ceil() * 5;
    final target =
        await _pick<int>('OBJETIVO DE ${BuildPlanRules.attributeShort(a)}', [
      for (var v = base; v <= base + 50; v += 5)
        PickOption(v, '$v', '+${v - cur} puntos', key: 'target-$v'),
    ]);
    if (target == null) return;
    _set(_plan.copyWith(attributes: {..._plan.attributes, a: target}));
  }

  Future<void> _addAscension() async {
    final defs = ascensionsOf(_p.classId);
    final what = _plan.ascensionId == null
        ? 'asc'
        : await _pick<String>('AGREGAR', const [
            PickOption('asc', 'Cambiar ascensión', null, key: 'what-asc'),
            PickOption('node', 'Nodo del mini-árbol', null, key: 'what-node'),
          ]);
    if (what == 'asc') {
      final id = await _pick<String>('ASCENSIÓN', [
        for (final d in defs)
          PickOption(d.id, d.name, d.theme, key: 'asc-${d.id}'),
      ]);
      if (id == null || id == _plan.ascensionId) return;
      _set(_plan.copyWith(ascensionId: () => id, ascensionNodes: const []));
    } else if (what == 'node') {
      final def = kAscensions[_plan.ascensionId];
      if (def == null) return;
      final id = await _pick<String>('NODO DE ${def.name.toUpperCase()}', [
        for (final n in def.nodes)
          if (!n.root && !_plan.ascensionNodes.contains(n.id))
            PickOption(n.id, '${n.name} (${n.cost})', n.text,
                key: 'ascn-${n.id}'),
      ]);
      if (id == null) return;
      _set(_plan.copyWith(ascensionNodes: [..._plan.ascensionNodes, id]));
    }
  }

  Future<void> _addWeapon() async {
    final cat = _rules.progression.catalog;
    final what = await _pick<String>('AGREGAR AL ARMA', const [
      PickOption('type', 'Tipo de arma', 'hacha, báculo, rifle...',
          key: 'what-type'),
      PickOption('base', 'Base de arma', 'una base concreta', key: 'what-base'),
      PickOption('mod', 'Mod (afijo)', 'con tier mínimo', key: 'what-mod'),
      PickOption('wp', 'Pasiva de arma', 'Épicas y Legendarias',
          key: 'what-wp'),
    ]);
    switch (what) {
      case 'type':
        final types = <String>{for (final w in cat.weapons.values) w.type}
            .where((t) => !_plan.weaponTypes.contains(t))
            .toList()
          ..sort();
        final t = await _pick<String>('TIPO DE ARMA', [
          for (final t in types) PickOption(t, t, null, key: 'type-$t'),
        ]);
        if (t != null) {
          _set(_plan.copyWith(weaponTypes: [..._plan.weaponTypes, t]));
        }
      case 'base':
        final bases = cat.weapons.values
            .where((w) => !_plan.weaponBases.contains(w.id))
            .toList()
          ..sort((a, b) => a.level.compareTo(b.level));
        final b = await _pick<String>('BASE DE ARMA', [
          for (final w in bases)
            PickOption(w.id, w.name,
                '${w.type} · Nv ${w.level}${w.price > 0 ? ' · ₵${w.price}' : ' · loot'}',
                key: 'base-${w.id}'),
        ]);
        if (b != null) {
          _set(_plan.copyWith(weaponBases: [..._plan.weaponBases, b]));
        }
      case 'mod':
        final id = await _pick<String>('MOD', [
          for (final a in kAffixes.values)
            if (!_plan.mods.any((m) => m.affixId == a.id))
              PickOption(
                  a.id,
                  BuildPlanRules.affixLabel(a.id),
                  '${a.slot.name == 'prefix' ? 'prefijo' : 'sufijo'}'
                  '${a.types == null ? '' : ' · ${a.types!.join(', ')}'}',
                  key: 'mod-${a.id}'),
        ]);
        if (id == null) return;
        final def = kAffixes[id]!;
        final tier = await _pick<int>('TIER MÍNIMO (T1 es el mejor)', [
          for (final t in def.tiers.reversed)
            PickOption(t.tier, 'T${t.tier} o mejor',
                '${def.stat.format(t.min)}–${t.max} · objeto Nv ${t.minLevel}+',
                key: 'tier-${t.tier}'),
        ]);
        if (tier != null) {
          _set(_plan.copyWith(mods: [..._plan.mods, ModGoal(id, tier)]));
        }
      case 'wp':
        final list = kWeaponPassives.values.toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        final id = await _pick<String>('PASIVA DE ARMA', [
          for (final w in list)
            PickOption(w.id, w.name,
                '${w.unique ? 'única · ' : ''}${w.descriptionAt(1)}',
                key: 'wp-${w.id}'),
        ]);
        if (id != null) _set(_plan.copyWith(weaponPassive: () => id));
    }
  }

  Future<void> _addSkill() async {
    final cat = _rules.progression.catalog;
    final givers = <String, List<String>>{};
    for (final w in cat.weapons.values) {
      for (final s in w.skillIds) {
        (givers[s] ??= []).add(w.name);
      }
    }
    for (final a in kAscensions.values) {
      for (final s in a.skillIds) {
        (givers[s] ??= []).add('kit de ${a.name}');
      }
    }
    final list = cat.skills.values
        .where((s) => !_plan.skills.contains(s.id))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final id = await _pick<String>('HABILIDAD', [
      for (final s in list)
        PickOption(
            s.id,
            s.name,
            givers[s.id] == null
                ? null
                : 'la da ${givers[s.id]!.take(2).join(', ')}',
            key: 'skill-${s.id}'),
    ]);
    if (id != null) _set(_plan.copyWith(skills: [..._plan.skills, id]));
  }

  Future<void> _addLevel() async {
    final what = await _pick<String>('AGREGAR', const [
      PickOption('lvl', 'Nivel objetivo', null, key: 'what-lvl'),
      PickOption('ms', 'Maestría objetivo', 'con nivel 50', key: 'what-ms'),
    ]);
    if (what == 'lvl') {
      final l = await _pick<int>('NIVEL', [
        for (final v in const [10, 20, 30, 40, 50])
          PickOption(v, 'Nivel $v', null, key: 'lvl-$v'),
      ]);
      if (l != null) _set(_plan.copyWith(targetLevel: () => l));
    } else if (what == 'ms') {
      final m = await _pick<int>('MAESTRÍA', [
        for (final v in const [5, 10, 15, 20])
          PickOption(v, 'Maestría $v', null, key: 'ms-$v'),
      ]);
      if (m != null) _set(_plan.copyWith(targetMastery: () => m));
    }
  }

  Future<void> _addCheck() async {
    final text = await showBuildTextDialog(context, 'ÍTEM DEL CHECKLIST',
        maxLength: BuildPlan.maxText);
    if (text == null || text.isEmpty) return;
    _set(_plan.copyWith(checklist: [..._plan.checklist, ChecklistItem(text)]));
  }
}

// ---------------------------------------------------------------------
// Selectores
// ---------------------------------------------------------------------

/// Una opción de [showBuildPicker].
class PickOption<T> {
  const PickOption(this.value, this.label, this.sub, {required this.key});
  final T value;
  final String label;
  final String? sub;
  final String key;
}

Future<T?> _dialog<T>(BuildContext context, WidgetBuilder builder) =>
    showDialog<T>(
      context: context,
      barrierColor: ProtoColors.scrim(0.6),
      builder: (ctx) =>
          Material(type: MaterialType.transparency, child: builder(ctx)),
    );

/// Lista buscable (si hay más de 8 opciones) para elegir una opción.
Future<T?> showBuildPicker<T>(
        BuildContext context, String title, List<PickOption<T>> options) =>
    _dialog<T>(context, (_) => _Picker<T>(title: title, options: options));

class _Picker<T> extends StatefulWidget {
  const _Picker({required this.title, required this.options});
  final String title;
  final List<PickOption<T>> options;

  @override
  State<_Picker<T>> createState() => _PickerState<T>();
}

class _PickerState<T> extends State<_Picker<T>> {
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  static String _fold(String s) {
    const from = 'áéíóúüñÁÉÍÓÚÜÑ';
    const to = 'aeiouunAEIOUUN';
    final b = StringBuffer();
    for (final c in s.split('')) {
      final i = from.indexOf(c);
      b.write(i < 0 ? c : to[i]);
    }
    return b.toString().toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final q = _fold(_q.text.trim());
    final list = [
      for (final o in widget.options)
        if (q.isEmpty || _fold('${o.label} ${o.sub ?? ''}').contains(q)) o,
    ];
    final searchable = widget.options.length > 8;
    // Confirmación (Sí / No): la explicación en una línea y dos botones.
    final confirm = widget.options.isNotEmpty &&
        widget.options.length <= 2 &&
        widget.options.every((o) => o.value is bool);
    final note = confirm ? widget.options.first.sub : null;
    void pick(PickOption<T> o) => Navigator.of(context).pop(o.value);
    return PanelFrame(
      key: const ValueKey('build-picker'),
      title: widget.title,
      width: 560,
      onClose: () => Navigator.of(context).pop(),
      actions: [
        if (confirm)
          for (final o in widget.options.reversed)
            DsButton(retroText(o.label.toUpperCase()),
                key: ValueKey('pick-${o.key}'),
                kind: o.value == true
                    ? DsButtonKind.primary
                    : DsButtonKind.secondary,
                onPressed: () => pick(o))
        else
          DsButton('CANCELAR',
              key: const ValueKey('build-picker-cancel'),
              onPressed: () => Navigator.of(context).pop()),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (confirm) ...[
            if (note != null) Text(retroText(note), style: DsText.body()),
          ] else ...[
            if (searchable) ...[
              DsSearchField(
                key: const ValueKey('build-picker-search'),
                hint: 'Buscar...',
                width: 520,
                controller: _q,
                onChanged: (_) => setState(() {}),
              ),
              SizedBox(height: DsSpace.sm),
            ],
            if (list.isEmpty)
              Text(retroText('Nada para agregar'), style: DsText.detail()),
            for (final o in list)
              DsListRow(
                key: ValueKey('pick-${o.key}'),
                title: retroText(o.label),
                detail: o.sub == null ? null : retroText(o.sub!),
                onTap: () => pick(o),
              ),
          ],
        ],
      ),
    );
  }
}

/// Texto corto (nombre del plan, ítem del checklist); `null` si cancela.
Future<String?> showBuildTextDialog(BuildContext context, String title,
        {String initial = '', int maxLength = 80}) =>
    _dialog<String>(
        context,
        (_) =>
            _TextDialog(title: title, initial: initial, maxLength: maxLength));

class _TextDialog extends StatefulWidget {
  const _TextDialog(
      {required this.title, required this.initial, required this.maxLength});
  final String title;
  final String initial;
  final int maxLength;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final _c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _ok() => Navigator.of(context).pop(_c.text.trim());

  @override
  Widget build(BuildContext context) => PanelFrame(
        key: const ValueKey('build-text-dialog'),
        title: widget.title,
        width: 480,
        onClose: () => Navigator.of(context).pop(),
        actions: [
          DsButton('CANCELAR', onPressed: () => Navigator.of(context).pop()),
          DsButton('GUARDAR',
              key: const ValueKey('build-text-ok'),
              kind: DsButtonKind.primary,
              onPressed: _ok),
        ],
        child: TextField(
          key: const ValueKey('build-text-field'),
          controller: _c,
          autofocus: true,
          maxLength: widget.maxLength,
          style: RetroType.smallStyle,
          decoration: const InputDecoration(
              isDense: true, contentPadding: EdgeInsets.all(8)),
          onSubmitted: (_) => _ok(),
        ),
      );
}

/// Marca de estado de una meta (sin glifos que la fuente no tiene):
/// hecha = tilde verde, en camino = cajita dorada a medio llenar,
/// pendiente = cajita vacía, bloqueada = cruz roja.
class GoalMark extends StatelessWidget {
  const GoalMark(this.state, {super.key});

  final GoalState state;

  @override
  Widget build(BuildContext context) {
    final s = RetroType.width(context, 11);
    final Widget mark = switch (state) {
      GoalState.done =>
        PixelIcon(PixelIconKind.check, size: s, color: ProtoColors.green),
      GoalState.blocked => Text('×',
          style: RetroType.style(RetroType.label,
              color: ProtoColors.red, height: 1)),
      _ => Container(
          width: s,
          height: s,
          decoration: BoxDecoration(
            border: Border.all(
                color: state == GoalState.partial
                    ? ProtoColors.gold
                    : ProtoColors.dim,
                width: 1.5),
          ),
          alignment: Alignment.bottomCenter,
          child: state == GoalState.partial
              ? const FractionallySizedBox(
                  heightFactor: 0.5,
                  widthFactor: 1,
                  child: ColoredBox(color: ProtoColors.gold))
              : null,
        ),
    };
    return Align(
      key: ValueKey('goal-mark-${state.name}'),
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: mark,
      ),
    );
  }
}
