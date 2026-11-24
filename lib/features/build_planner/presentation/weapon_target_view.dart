import 'package:material_ui/material_ui.dart';
import '../../inventory/domain/item_names.dart';

import '../../../app/design/design.dart';
import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/retro_text.dart';
import '../../../game_engine/data/affixes_catalog.dart';
import '../../../game_engine/data/weapon_passives.dart';
import '../../../game_engine/models/attributes.dart';
import '../../../game_engine/models/build_plan.dart';
import '../../../game_engine/models/elements.dart';
import '../../../game_engine/models/item.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/models/upgrade_stat.dart';
import '../../../game_engine/models/weapon.dart';
import '../../../game_engine/rules/build_plan_rules.dart';
import '../../../game_engine/rules/weapon_target_rules.dart';
import '../../inventory/presentation/item_grid.dart';
import '../../inventory/presentation/item_hover_tip.dart';
import '../../inventory/presentation/item_widgets.dart' hide PixelIcon;
import 'build_planner_view.dart' show GoalMark, PickOption, showBuildPicker;
import 'build_text.dart';

// BUILD v2 — arma objetivo (docs/specs/build_planner_v2.md § 1 y § 4):
// fila del objetivo, buscador de bases y detalle con requisitos, "qué
// te falta", PLAN DE FUSIÓN y candidatas (inventario + alijo aparte).

/// Fila de un objetivo de arma en la sección ARMA Y MODS (organismo
/// DsListRow + DsPercent): `★ Hacha Tronante Épica 72% · faltan 3`.
class WeaponTargetRow extends StatelessWidget {
  const WeaponTargetRow({
    super.key,
    required this.rules,
    required this.target,
    required this.best,
    this.onTap,
    this.trailing,
  });

  final WeaponTargetRules rules;
  final WeaponTarget target;
  final WeaponMatch? best;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final name = rules.targetName(target);
    final pct = best?.percent ?? 0;
    final miss = best?.missing;
    final color = target.rarity == null
        ? DsColors.reward
        : RarityColors.of(target.rarity!);
    final s = context.buildStrings;
    return Semantics(
      label: s.t('ui.build.target.semantics', {'name': name, 'pct': pct}) +
          (miss == null
              ? ''
              : s.t('ui.build.target.semantics_miss', {'n': miss})),
      child: DsListRow(
        leading: Text('★', style: DsText.body(color)),
        title: retroText(name),
        titleColor: color,
        detail: retroText(best == null
            ? s.t('ui.build.target.row_none', {'prio': target.priority.label})
            : s.t('ui.build.target.row_miss',
                    {'prio': target.priority.label, 'n': miss}) +
                (best!.inStash ? s.t('ui.build.target.row_stash') : '')),
        onTap: onTap,
        tooltip: best == null
            ? null
            : DsTooltipCard(title: retroText(name), children: [
                Text(
                    retroText(s.t('ui.build.target.best', {
                          'name':
                              localItemName(rules.progression.items, best!.item)
                        }) +
                        (best!.inStash
                            ? s.t('ui.build.target.best_stash')
                            : '')),
                    style: DsText.detail()),
              ]),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          DsPercent(pct, label: name),
          if (trailing != null) ...[SizedBox(width: DsSpace.xs), trailing!],
        ]),
      ),
    );
  }
}

Future<T?> _dialog<T>(BuildContext context, WidgetBuilder builder) =>
    showDialog<T>(
      context: context,
      barrierColor: ProtoColors.scrim(0.6),
      builder: (ctx) =>
          Material(type: MaterialType.transparency, child: builder(ctx)),
    );

// ---------------------------------------------------------------------
// Buscador de bases (§ 1.1)
// ---------------------------------------------------------------------

/// Selector con todas las bases del juego, buscador y filtros. Devuelve
/// la base elegida o `null`.
Future<WeaponDef?> showBaseSearch(
  BuildContext context, {
  required WeaponTargetRules rules,
  required PlayerAttributes Function(int level) attributesAt,
  required int planLevel,
  Set<String> starred = const {},
}) =>
    _dialog<WeaponDef>(
        context,
        (_) => _BaseSearch(
            rules: rules,
            attributesAt: attributesAt,
            planLevel: planLevel,
            starred: starred));

class _BaseSearch extends StatefulWidget {
  const _BaseSearch({
    required this.rules,
    required this.attributesAt,
    required this.planLevel,
    required this.starred,
  });

  final WeaponTargetRules rules;
  final PlayerAttributes Function(int level) attributesAt;
  final int planLevel;
  final Set<String> starred;

  @override
  State<_BaseSearch> createState() => _BaseSearchState();
}

class _BaseSearchState extends State<_BaseSearch> {
  final _q = TextEditingController();
  final _types = <String>{};
  final _families = <String>{};
  final _categories = <WeaponCategory>{};
  final _elements = <GameElement>{};
  bool _usable = false;

  Strings get _s => context.buildStrings;

  Map<String, String> get _familyNames => {
        'guerrero': _s.t('ui.build.search.fam_warrior'),
        'maga': _s.t('ui.build.search.fam_mage'),
        'tirador': _s.t('ui.build.search.fam_shooter'),
        'paladin': _s.t('ui.build.search.fam_paladin'),
      };
  Map<WeaponCategory, String> get _categoryNames => {
        WeaponCategory.melee: _s.t('ui.build.search.cat_melee'),
        WeaponCategory.ranged: _s.t('ui.build.search.cat_ranged'),
        WeaponCategory.caster: _s.t('ui.build.search.cat_caster'),
      };

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Widget _toggles<T>(String label, Iterable<T> values, Set<T> on,
      String Function(T) name, String keyPrefix) {
    return Padding(
      padding: EdgeInsets.only(top: DsSpace.xs),
      child: Wrap(
        spacing: DsSpace.xs,
        runSpacing: DsSpace.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(retroText(label), style: DsText.detail()),
          for (final v in values)
            DsButton(retroText(name(v)),
                key: ValueKey('$keyPrefix-${name(v)}'),
                size: DsButtonSize.compact,
                kind: DsButtonKind.ghost,
                selected: on.contains(v),
                onPressed: () =>
                    setState(() => on.contains(v) ? on.remove(v) : on.add(v))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.rules;
    final types = <String>{
      for (final w in r.progression.catalog.weapons.values) w.type
    }.toList()
      ..sort();
    final list = r.searchBases(BaseQuery(
      text: _q.text,
      types: _types,
      families: _families,
      categories: _categories,
      elements: _elements,
      usableAt: _usable ? widget.planLevel : null,
    ));
    final families = _familyNames;
    final categories = _categoryNames;
    return PanelFrame(
      key: const ValueKey('base-search'),
      title: _s.t('ui.build.search.title'),
      width: 760,
      onClose: () => Navigator.of(context).pop(),
      actions: [
        DsButton(_s.t('ui.build.dialog.cancel'),
            key: const ValueKey('base-search-cancel'),
            onPressed: () => Navigator.of(context).pop()),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: DsSearchField(
              key: const ValueKey('base-search-field'),
              hint: _s.t('ui.build.search.hint'),
              width: 520,
              controller: _q,
              onChanged: (_) => setState(() {}),
            ),
          ),
          _toggles(_s.t('ui.build.search.type'), types, _types,
              (t) => t.toUpperCase(), 'bs-type'),
          _toggles(_s.t('ui.build.search.family'), families.keys, _families,
              (f) => families[f]!, 'bs-fam'),
          _toggles(_s.t('ui.build.search.category'), WeaponCategory.values,
              _categories, (c) => categories[c]!, 'bs-cat'),
          _toggles(
              _s.t('ui.build.search.element'),
              [
                for (final e in GameElement.values)
                  if (e != GameElement.fisico) e
              ],
              _elements,
              (e) => e.label.toUpperCase(),
              'bs-el'),
          Padding(
            padding: EdgeInsets.only(top: DsSpace.xs),
            child: Wrap(children: [
              DsButton(
                  retroText(
                      _s.t('ui.build.search.usable', {'n': widget.planLevel})),
                  key: const ValueKey('bs-usable'),
                  size: DsButtonSize.compact,
                  kind: DsButtonKind.ghost,
                  selected: _usable,
                  onPressed: () => setState(() => _usable = !_usable)),
            ]),
          ),
          SizedBox(height: DsSpace.sm),
          Text(retroText(_s.t('ui.build.search.count', {'n': list.length})),
              style: DsText.detail()),
          if (list.isEmpty)
            Text(retroText(_s.t('ui.build.search.none')),
                style: DsText.detail()),
          for (final w in list.take(80)) _row(w),
        ],
      ),
    );
  }

  Widget _row(WeaponDef w) {
    final at = widget.attributesAt(w.level);
    final miss = widget.rules.missingRequirements(w, at);
    final req = [
      for (final e in w.requirements.entries)
        '${e.key.name.toUpperCase()} ${e.value}'
    ].join(' ');
    final skills =
        [for (final s in w.skillIds) widget.rules.skillName(s)].join(', ');
    return DsListRow(
      key: ValueKey('base-${w.id}'),
      leading: widget.starred.contains(w.id)
          ? Text('★', style: DsText.body(DsColors.reward))
          : null,
      title: retroText(w.name),
      detail: retroText(
          _s.t('ui.build.search.row', {'type': w.type, 'level': w.level}) +
              (req.isEmpty ? '' : ' · $req') +
              (miss.isEmpty ? '' : _s.t('ui.build.search.row_short'))),
      detailColor: miss.isEmpty ? null : DsColors.danger,
      onTap: () => Navigator.of(context).pop(w),
      tooltip: DsTooltipCard(title: retroText(w.name), children: [
        Text(
            retroText(_s.t('ui.build.search.tip_line',
                {'type': w.type, 'level': w.level, 'family': w.classId})),
            style: DsText.detail()),
        if (skills.isNotEmpty)
          Text(retroText(_s.t('ui.build.search.skills', {'list': skills})),
              style: DsText.body()),
        for (final m in w.implicit)
          Text(retroText(_s.t('ui.build.search.implicit', {'text': m.text})),
              style: DsText.detail()),
        if (req.isNotEmpty)
          Text(retroText(_s.t('ui.build.search.requires', {'req': req})),
              style: DsText.detail(miss.isEmpty ? null : DsColors.danger)),
        Text(
            retroText(w.price > 0
                ? _s.t('ui.build.search.armory', {'price': '₵${w.price}'})
                : _s.t('ui.build.search.loot')),
            style: DsText.detail()),
      ]),
    );
  }
}

// ---------------------------------------------------------------------
// Detalle del objetivo (§ 1.2, 1.3, 1.5 y § 4.3)
// ---------------------------------------------------------------------

/// Resultado del detalle: el objetivo editado, o [removed].
class TargetEdit {
  const TargetEdit(this.target) : removed = false;
  const TargetEdit.removed()
      : target = null,
        removed = true;
  final WeaponTarget? target;
  final bool removed;
}

/// Detalle de un objetivo de arma: requisitos y % de la candidata
/// elegida, "qué te falta" con costos, PLAN DE FUSIÓN y la grilla de
/// candidatas (inventario y alijo por separado). Con [editable], también
/// se edita el objetivo.
Future<TargetEdit?> showWeaponTargetDetail(
  BuildContext context, {
  required BuildPlanRules rules,
  required WeaponTarget target,
  required PlayerProfile profile,
  List<ItemInstance> stash = const [],
  bool editable = false,
  PlayerAttributes Function(int level)? attributesAt,
}) =>
    _dialog<TargetEdit>(
        context,
        (_) => WeaponTargetDetail(
            rules: rules,
            target: target,
            profile: profile,
            stash: stash,
            editable: editable,
            attributesAt: attributesAt));

class WeaponTargetDetail extends StatefulWidget {
  const WeaponTargetDetail({
    super.key,
    required this.rules,
    required this.target,
    required this.profile,
    this.stash = const [],
    this.editable = false,
    this.attributesAt,
  });

  final BuildPlanRules rules;
  final WeaponTarget target;
  final PlayerProfile profile;
  final List<ItemInstance> stash;
  final bool editable;
  final PlayerAttributes Function(int level)? attributesAt;

  @override
  State<WeaponTargetDetail> createState() => _WeaponTargetDetailState();
}

class _WeaponTargetDetailState extends State<WeaponTargetDetail> {
  late WeaponTarget _t = widget.target;
  String? _uid;

  WeaponTargetRules get _r => widget.rules.targets;
  PlayerProfile get _p => widget.profile;

  Future<T?> _pick<T>(String title, List<PickOption<T>> o) =>
      showBuildPicker<T>(context, title, o);

  Strings get _s => context.buildStrings;

  @override
  Widget build(BuildContext context) {
    final cands = _r.candidates(_t, _p, stash: widget.stash);
    final cur =
        cands.where((c) => c.item.uid == _uid).firstOrNull ?? cands.firstOrNull;
    final errors =
        _r.validate(_t, attributes: widget.attributesAt?.call(_t.level));
    final name = _r.targetName(_t);
    return PanelFrame(
      key: const ValueKey('target-detail'),
      title: retroText('★ ${name.toUpperCase()}'),
      width: 1040,
      onClose: () => Navigator.of(context).pop(),
      actions: [
        if (widget.editable)
          DsButton(_s.t('ui.build.target.remove'),
              key: const ValueKey('target-remove'),
              kind: DsButtonKind.ghost,
              onPressed: () =>
                  Navigator.of(context).pop(const TargetEdit.removed())),
        DsButton(
            widget.editable
                ? _s.t('ui.build.dialog.cancel')
                : _s.t('ui.build.tpl.close'),
            key: const ValueKey('target-close'),
            onPressed: () => Navigator.of(context).pop()),
        if (widget.editable)
          DsButton(_s.t('ui.build.dialog.save'),
              key: const ValueKey('target-save'),
              kind: DsButtonKind.primary,
              onPressed: () => Navigator.of(context).pop(TargetEdit(_t))),
      ],
      child: LayoutBuilder(builder: (context, box) {
        final left = _targetColumn(cur, errors);
        final right = _missingColumn(cur);
        final wide = box.maxWidth >= 760;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (wide)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: left),
                SizedBox(width: DsSpace.md),
                Expanded(child: right),
              ])
            else ...[
              left,
              right,
            ],
            _candidates(cands, cur),
          ],
        );
      }),
    );
  }

  Widget _targetColumn(WeaponMatch? cur, List<String> errors) {
    final pct = cur?.percent ?? 0;
    return Column(
      key: const ValueKey('target-reqs'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DsSectionHeader(_s.t('ui.build.target.header'),
            trailing: DsPercent(pct, label: _r.targetName(_t))),
        Text(
            retroText(_s.t('ui.build.target.from_level',
                    {'prio': _t.priority.label, 'n': _t.level}) +
                (_t.keepQuebrar ? '' : _s.t('ui.build.target.no_break'))),
            style: DsText.detail()),
        if (cur == null)
          Text(retroText(_s.t('ui.build.target.no_candidates')),
              style: DsText.detail()),
        for (final r in cur?.reqs ?? const <TargetReq>[])
          DsListRow(
            key: ValueKey('req-${r.key}'),
            leading: GoalMark(r.state),
            title: retroText(r.label),
            titleColor: r.done ? DsColors.success : null,
            detail: r.detail == null
                ? null
                : retroText(r.done
                    ? r.detail!
                    : _s.t('ui.build.target.has', {'detail': r.detail})),
          ),
        for (final e in errors)
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: DsSpace.md, vertical: DsSpace.xs),
            child: Text(retroText('× $e'),
                key: const ValueKey('target-error'),
                style: DsText.detail(DsColors.danger)),
          ),
        if (widget.editable) _editBar(),
      ],
    );
  }

  Widget _editBar() => Padding(
        padding: EdgeInsets.only(top: DsSpace.sm),
        child: Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: [
          for (final (k, l, f) in [
            ('prio', _s.t('ui.build.target.edit_prio'), _editPriority),
            ('rarity', _s.t('ui.build.target.edit_rarity'), _editRarity),
            ('mod', _s.t('ui.build.target.edit_mod'), _addMod),
            ('passive', _s.t('ui.build.target.edit_passive'), _editPassive),
            ('skill', _s.t('ui.build.target.edit_skill'), _addSkill),
            ('ilvl', _s.t('ui.build.target.edit_ilvl'), _editIlvl),
            ('forge', _s.t('ui.build.target.edit_forge'), _editForge),
          ])
            DsButton(l,
                key: ValueKey('target-edit-$k'),
                size: DsButtonSize.compact,
                onPressed: f),
          DsButton(
              _t.keepQuebrar
                  ? _s.t('ui.build.target.keep_break')
                  : _s.t('ui.build.target.no_break_btn'),
              key: const ValueKey('target-edit-quebrar'),
              size: DsButtonSize.compact,
              kind: DsButtonKind.ghost,
              selected: !_t.keepQuebrar,
              onPressed: () => setState(
                  () => _t = _t.copyWith(keepQuebrar: !_t.keepQuebrar))),
          if (_t.mods.isNotEmpty || _t.skills.isNotEmpty)
            DsButton(_s.t('ui.build.target.drop_req'),
                key: const ValueKey('target-edit-drop'),
                size: DsButtonSize.compact,
                kind: DsButtonKind.ghost,
                onPressed: _dropReq),
        ]),
      );

  Widget _missingColumn(WeaponMatch? cur) {
    final lines = cur == null
        ? const <MissingLine>[]
        : _r.missing(_t, cur, _p,
            stash: widget.stash, attributesAt: widget.attributesAt);
    final plan = cur == null
        ? FusionPlan.empty
        : _r.fusionPlan(_t, cur, _p, stash: widget.stash);
    return Column(
      key: const ValueKey('target-missing'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DsSectionHeader(_s.t('ui.build.target.missing', {'n': lines.length})),
        if (lines.isEmpty)
          Text(
              retroText(cur == null
                  ? _s.t('ui.build.target.pick_candidate')
                  : _s.t('ui.build.target.complete')),
              style: DsText.body(DsColors.success)),
        for (final l in lines)
          Padding(
            key: ValueKey('missing-${l.key}'),
            padding: EdgeInsets.symmetric(
                horizontal: DsSpace.md, vertical: DsSpace.xs),
            child: Text(retroText(l.text),
                style: DsText.body(l.sourceInStash ? DsColors.mp : null)),
          ),
        if (plan.steps.isNotEmpty) ...[
          DsSectionHeader(_s.t('ui.build.target.fusion_plan'),
              trailing: Text(retroText(WeaponTargetRules.credits(plan.credits)),
                  style: DsText.body(DsColors.reward))),
          for (var i = 0; i < plan.steps.length; i++)
            Padding(
              key: ValueKey('fusion-step-$i'),
              padding: EdgeInsets.symmetric(
                  horizontal: DsSpace.md, vertical: DsSpace.xs),
              child: Text(
                  retroText('${i + 1}. ${plan.steps[i].text}'
                      '${plan.steps[i].sourceInStash ? _s.t('ui.build.target.from_stash') : ''}'),
                  style: DsText.detail()),
            ),
          if (plan.materials.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: DsSpace.md),
              child: Text(
                  retroText(_s.t('ui.build.target.materials', {
                    'list': [
                      for (final e in plan.materials.entries)
                        '${e.value} ${e.key.label}'
                    ].join(' · ')
                  })),
                  style: DsText.detail()),
            ),
        ],
      ],
    );
  }

  Widget _candidates(List<WeaponMatch> cands, WeaponMatch? cur) {
    final inv = [
      for (final c in cands)
        if (!c.inStash) c
    ];
    final st = [
      for (final c in cands)
        if (c.inStash) c
    ];
    Widget grid(String key, List<WeaponMatch> list) => DsItemGrid(
          key: ValueKey(key),
          rules: widget.rules.progression,
          count: list.length,
          empty: _s.t('ui.build.target.no_weapons'),
          slot: (i) => ItemSlotData(
            content: CellContent.item(list[i].item),
            selected: list[i].item.uid == cur?.item.uid,
            buildMatch: i == 0 && list[i].percent > 0,
          ),
          onTap: (i) => setState(() => _uid = list[i].item.uid),
          tip: (i, child, focused) => itemHoverTip(
            rules: widget.rules.progression,
            viewer: _p,
            item: list[i].item,
            attributes: _p.attributes,
            focused: focused,
            note: '★ ${_s.t('ui.build.target.note', {
                  'pct': list[i].percent
                })}${list[i].inStash ? _s.t('ui.build.target.note_stash') : ''}',
            child: child,
          ),
          decorate: (i, child) => Stack(children: [
            child,
            Positioned(
              right: 1,
              top: 1,
              child: IgnorePointer(
                child: Container(
                  color: ProtoColors.bg.withValues(alpha: 0.8),
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Text('${list[i].percent}',
                      textScaler: TextScaler.noScaling,
                      style: DsText.detail(DsColors.reward)
                          .copyWith(fontSize: 10, height: 1)),
                ),
              ),
            ),
          ]),
        );
    return Column(
      key: const ValueKey('target-candidates'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DsSectionHeader(_s.t('ui.build.target.cand_inv', {'n': inv.length})),
        grid('cand-inv', inv),
        DsSectionHeader(_s.t('ui.build.target.cand_stash', {'n': st.length}),
            trailing:
                DsTag(_s.t('ui.build.target.stash_tag'), color: DsColors.mp)),
        Text(retroText(_s.t('ui.build.target.stash_note')),
            style: DsText.detail()),
        grid('cand-stash', st),
      ],
    );
  }

  // ---- edición ----

  Future<void> _editPriority() async {
    final p = await _pick<TargetPriority>(_s.t('ui.build.target.edit_prio'), [
      for (final p in TargetPriority.values)
        PickOption(p, p.label, null, key: 'prio-${p.key}'),
    ]);
    if (p != null) setState(() => _t = _t.copyWith(priority: p));
  }

  Future<void> _editRarity() async {
    final r = await _pick<Rarity>(_s.t('ui.build.target.min_rarity'), [
      for (final r in Rarity.values)
        PickOption(
            r,
            r.label,
            _s.t('ui.build.target.rarity_sub',
                {'slots': r.maxMods, 'forge': r.forgeCap}),
            key: 'rar-${r.name}'),
    ]);
    if (r != null) {
      setState(() => _t = _t.copyWith(rarity: () => r, slots: () => r.maxMods));
    }
  }

  Future<void> _addMod() async {
    final type = _r.typeOf(_t);
    final id = await _pick<String>(_s.t('ui.build.pick.mod_title'), [
      for (final a in kAffixes.values)
        if (!_t.mods.any((m) => m.affixId == a.id) &&
            (type == null || a.allows(type)))
          PickOption(
              a.id,
              BuildPlanRules.affixLabel(a.id),
              _s.t('ui.build.pick.slot',
                  {'slot': a.slot == AffixSlot.prefix ? 'prefix' : 'suffix'}),
              key: 'mod-${a.id}'),
    ]);
    if (id == null) return;
    final def = kAffixes[id]!;
    final tier = await _pick<int>(_s.t('ui.build.pick.min_tier'), [
      for (final t in def.tiers.reversed)
        PickOption(t.tier, _s.t('ui.build.pick.tier', {'tier': t.tier}),
            _s.t('ui.build.target.item_level', {'n': t.minLevel}),
            key: 'tier-${t.tier}'),
    ]);
    if (tier != null) {
      setState(() => _t = _t.copyWith(mods: [..._t.mods, ModGoal(id, tier)]));
    }
  }

  Future<void> _editPassive() async {
    final type = _r.typeOf(_t);
    final id = await _pick<String>(_s.t('ui.build.pick.passive_title'), [
      PickOption('', _s.t('ui.build.target.none'), null, key: 'wp-none'),
      for (final w in kWeaponPassives.values)
        if (!w.unique && (type == null || w.types.contains(type)))
          PickOption(w.id, w.text, w.descriptionAt(1), key: 'wp-${w.id}'),
    ]);
    if (id == null) return;
    if (id.isEmpty) {
      setState(() => _t = _t.copyWith(passive: () => null));
      return;
    }
    final lv = await _pick<int>(_s.t('ui.build.target.min_level'), [
      for (var l = 1; l <= 5; l++)
        PickOption(l, kWeaponPassives[id]!.nameAtText(l), null, key: 'wpl-$l'),
    ]);
    if (lv != null) {
      setState(() => _t = _t.copyWith(passive: () => id, passiveLevel: lv));
    }
  }

  Future<void> _addSkill() async {
    final cat = widget.rules.progression.catalog;
    final list = cat.skills.values
        .where((s) => !_t.skills.contains(s.id))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final id = await _pick<String>(_s.t('ui.build.target.skill_title'), [
      for (final s in list) PickOption(s.id, s.name, null, key: 'sk-${s.id}'),
    ]);
    if (id != null) {
      setState(() => _t = _t.copyWith(skills: [..._t.skills, id]));
    }
  }

  Future<void> _editIlvl() async {
    final v = await _pick<int>(_s.t('ui.build.target.ilvl_title'), [
      for (final l in const [10, 20, 30, 36, 40, 50])
        PickOption(l, _s.t('ui.build.tpl.level', {'n': l}), null,
            key: 'ilvl-$l'),
    ]);
    if (v != null) setState(() => _t = _t.copyWith(itemLevel: () => v));
  }

  Future<void> _editForge() async {
    final s = await _pick<UpgradeStat>(_s.t('ui.build.target.edit_forge'), [
      for (final s in UpgradeStat.values)
        PickOption(s, s.label,
            _s.t('ui.build.target.forge_sub', {'n': _t.forge[s] ?? 0}),
            key: 'forge-${s.key}'),
    ]);
    if (s == null) return;
    final l = await _pick<int>(
        _s.t('ui.build.target.forge_level', {'stat': s.label.toUpperCase()}), [
      for (var l = 0; l <= 5; l++) PickOption(l, '$l', null, key: 'fl-$l'),
    ]);
    if (l == null) return;
    setState(() => _t = _t.copyWith(forge: {
          for (final e in _t.forge.entries)
            if (e.key != s) e.key: e.value,
          if (l > 0) s: l,
        }));
  }

  Future<void> _dropReq() async {
    final id = await _pick<String>(_s.t('ui.build.target.drop_req'), [
      for (final m in _t.mods)
        PickOption('mod:${m.affixId}', BuildPlanRules.affixLabel(m.affixId),
            'T${m.minTier}',
            key: 'drop-mod-${m.affixId}'),
      for (final s in _t.skills)
        PickOption('skill:$s', _r.skillName(s), null, key: 'drop-sk-$s'),
    ]);
    if (id == null) return;
    setState(() => _t = _t.copyWith(
          mods: [
            for (final m in _t.mods)
              if ('mod:${m.affixId}' != id) m
          ],
          skills: [
            for (final s in _t.skills)
              if ('skill:$s' != id) s
          ],
        ));
  }
}
