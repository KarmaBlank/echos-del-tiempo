import 'package:material_ui/material_ui.dart';

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
    return Semantics(
      label: '$name, $pct por ciento del objetivo'
          '${miss == null ? '' : ', faltan $miss'}',
      child: DsListRow(
        leading: Text('★', style: DsText.body(color)),
        title: retroText(name),
        titleColor: color,
        detail: retroText(best == null
            ? '${target.priority.label} · sin candidata'
            : '${target.priority.label} · faltan $miss'
                '${best!.inStash ? ' · ALIJO' : ''}'),
        onTap: onTap,
        tooltip: best == null
            ? null
            : DsTooltipCard(title: retroText(name), children: [
                Text(
                    retroText('Mejor candidata: '
                        '${rules.progression.items.displayName(best!.item)}'
                        '${best!.inStash ? ' (en el alijo)' : ''}'),
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

  static const _familyNames = {
    'guerrero': 'GUERRERO',
    'maga': 'MAGA',
    'tirador': 'TIRADOR',
    'paladin': 'PALADÍN',
  };
  static const _categoryNames = {
    WeaponCategory.melee: 'CUERPO A CUERPO',
    WeaponCategory.ranged: 'DISTANCIA',
    WeaponCategory.caster: 'LANZADOR',
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
                onPressed: () => setState(
                    () => on.contains(v) ? on.remove(v) : on.add(v))),
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
    return PanelFrame(
      key: const ValueKey('base-search'),
      title: 'ARMA OBJETIVO',
      width: 760,
      onClose: () => Navigator.of(context).pop(),
      actions: [
        DsButton('CANCELAR',
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
              hint: 'Nombre, habilidad o implícito...',
              width: 520,
              controller: _q,
              onChanged: (_) => setState(() {}),
            ),
          ),
          _toggles('TIPO', types, _types, (t) => t.toUpperCase(), 'bs-type'),
          _toggles('FAMILIA', _familyNames.keys, _families,
              (f) => _familyNames[f]!, 'bs-fam'),
          _toggles('CATEGORÍA', WeaponCategory.values, _categories,
              (c) => _categoryNames[c]!, 'bs-cat'),
          _toggles(
              'ELEMENTO',
              [for (final e in GameElement.values) if (e != GameElement.fisico) e],
              _elements,
              (e) => e.label.toUpperCase(),
              'bs-el'),
          Padding(
            padding: EdgeInsets.only(top: DsSpace.xs),
            child: Wrap(children: [
              DsButton(
                  retroText('PUEDO USARLA AL NIVEL DEL PLAN (${widget.planLevel})'),
                  key: const ValueKey('bs-usable'),
                  size: DsButtonSize.compact,
                  kind: DsButtonKind.ghost,
                  selected: _usable,
                  onPressed: () => setState(() => _usable = !_usable)),
            ]),
          ),
          SizedBox(height: DsSpace.sm),
          Text(retroText('${list.length} bases'), style: DsText.detail()),
          if (list.isEmpty)
            Text(retroText('Ninguna base coincide'), style: DsText.detail()),
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
    final skills = [
      for (final s in w.skillIds) widget.rules.skillName(s)
    ].join(', ');
    return DsListRow(
      key: ValueKey('base-${w.id}'),
      leading: widget.starred.contains(w.id)
          ? Text('★', style: DsText.body(DsColors.reward))
          : null,
      title: retroText(w.name),
      detail: retroText('${w.type} · Nv ${w.level}${req.isEmpty ? '' : ' · $req'}'
          '${miss.isEmpty ? '' : ' (no llegás)'}'),
      detailColor: miss.isEmpty ? null : DsColors.danger,
      onTap: () => Navigator.of(context).pop(w),
      tooltip: DsTooltipCard(title: retroText(w.name), children: [
        Text(retroText('${w.type} · Nv ${w.level} · familia ${w.classId}'),
            style: DsText.detail()),
        if (skills.isNotEmpty)
          Text(retroText('Habilidades: $skills'), style: DsText.body()),
        for (final m in w.implicit)
          Text(retroText('Implícito: ${m.text}'), style: DsText.detail()),
        if (req.isNotEmpty)
          Text(retroText('Pide $req'),
              style: DsText.detail(miss.isEmpty ? null : DsColors.danger)),
        Text(
            retroText(w.price > 0
                ? 'Armería ₵${w.price}'
                : 'Sale como loot'),
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

  @override
  Widget build(BuildContext context) {
    final cands = _r.candidates(_t, _p, stash: widget.stash);
    final cur = cands.where((c) => c.item.uid == _uid).firstOrNull ??
        cands.firstOrNull;
    final errors = _r.validate(_t,
        attributes: widget.attributesAt?.call(_t.level));
    final name = _r.targetName(_t);
    return PanelFrame(
      key: const ValueKey('target-detail'),
      title: retroText('★ ${name.toUpperCase()}'),
      width: 1040,
      onClose: () => Navigator.of(context).pop(),
      actions: [
        if (widget.editable)
          DsButton('QUITAR OBJETIVO',
              key: const ValueKey('target-remove'),
              kind: DsButtonKind.ghost,
              onPressed: () =>
                  Navigator.of(context).pop(const TargetEdit.removed())),
        DsButton(widget.editable ? 'CANCELAR' : 'CERRAR',
            key: const ValueKey('target-close'),
            onPressed: () => Navigator.of(context).pop()),
        if (widget.editable)
          DsButton('GUARDAR',
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
        DsSectionHeader('OBJETIVO',
            trailing: DsPercent(pct, label: _r.targetName(_t))),
        Text(
            retroText('${_t.priority.label} · desde Nv ${_t.level}'
                '${_t.keepQuebrar ? '' : ' · sin Quebrar'}'),
            style: DsText.detail()),
        if (cur == null)
          Text(retroText('Sin candidatas: buscala en el loot o la Armería.'),
              style: DsText.detail()),
        for (final r in cur?.reqs ?? const <TargetReq>[])
          DsListRow(
            key: ValueKey('req-${r.key}'),
            leading: GoalMark(r.state),
            title: retroText(r.label),
            titleColor: r.done ? DsColors.success : null,
            detail: r.detail == null
                ? null
                : retroText(r.done ? r.detail! : 'tiene ${r.detail}'),
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
            ('prio', 'PRIORIDAD', _editPriority),
            ('rarity', 'RAREZA', _editRarity),
            ('mod', '+ MOD', _addMod),
            ('passive', 'PASIVA', _editPassive),
            ('skill', '+ HABILIDAD', _addSkill),
            ('ilvl', 'NV. DE OBJETO', _editIlvl),
            ('forge', 'FORJA', _editForge),
          ])
            DsButton(l,
                key: ValueKey('target-edit-$k'),
                size: DsButtonSize.compact,
                onPressed: f),
          DsButton(_t.keepQuebrar ? 'CONSERVAR QUEBRAR' : 'SIN QUEBRAR',
              key: const ValueKey('target-edit-quebrar'),
              size: DsButtonSize.compact,
              kind: DsButtonKind.ghost,
              selected: !_t.keepQuebrar,
              onPressed: () =>
                  setState(() => _t = _t.copyWith(keepQuebrar: !_t.keepQuebrar))),
          if (_t.mods.isNotEmpty || _t.skills.isNotEmpty)
            DsButton('QUITAR REQUISITO',
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
        DsSectionHeader('QUÉ TE FALTA  ${lines.length}'),
        if (lines.isEmpty)
          Text(retroText(cur == null ? 'Elegí una candidata' : '¡Completa!'),
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
          DsSectionHeader('PLAN DE FUSIÓN',
              trailing: Text(
                  retroText(WeaponTargetRules.credits(plan.credits)),
                  style: DsText.body(DsColors.reward))),
          for (var i = 0; i < plan.steps.length; i++)
            Padding(
              key: ValueKey('fusion-step-$i'),
              padding: EdgeInsets.symmetric(
                  horizontal: DsSpace.md, vertical: DsSpace.xs),
              child: Text(
                  retroText('${i + 1}. ${plan.steps[i].text}'
                      '${plan.steps[i].sourceInStash ? ' (sacala del alijo primero)' : ''}'),
                  style: DsText.detail()),
            ),
          if (plan.materials.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: DsSpace.md),
              child: Text(
                  retroText('Materiales: ${[
                    for (final e in plan.materials.entries)
                      '${e.value} ${e.key.label}'
                  ].join(' · ')}'),
                  style: DsText.detail()),
            ),
        ],
      ],
    );
  }

  Widget _candidates(List<WeaponMatch> cands, WeaponMatch? cur) {
    final inv = [for (final c in cands) if (!c.inStash) c];
    final st = [for (final c in cands) if (c.inStash) c];
    Widget grid(String key, List<WeaponMatch> list) => DsItemGrid(
          key: ValueKey(key),
          rules: widget.rules.progression,
          count: list.length,
          empty: 'Sin armas',
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
            note: '★ ${list[i].percent}% del objetivo'
                '${list[i].inStash ? ' · en el alijo' : ''}',
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
        DsSectionHeader('CANDIDATAS · INVENTARIO  ${inv.length}'),
        grid('cand-inv', inv),
        DsSectionHeader('CANDIDATAS · ALIJO COMPARTIDO  ${st.length}',
            trailing: const DsTag('ALIJO', color: DsColors.mp)),
        Text(
            retroText('Solo se miran: nada sale del alijo sin que lo '
                'saques vos.'),
            style: DsText.detail()),
        grid('cand-stash', st),
      ],
    );
  }

  // ---- edición ----

  Future<void> _editPriority() async {
    final p = await _pick<TargetPriority>('PRIORIDAD', [
      for (final p in TargetPriority.values)
        PickOption(p, p.label, null, key: 'prio-${p.key}'),
    ]);
    if (p != null) setState(() => _t = _t.copyWith(priority: p));
  }

  Future<void> _editRarity() async {
    final r = await _pick<Rarity>('RAREZA MÍNIMA', [
      for (final r in Rarity.values)
        PickOption(r, r.label, '${r.maxMods} ranuras · forja ${r.forgeCap}',
            key: 'rar-${r.name}'),
    ]);
    if (r != null) {
      setState(() => _t = _t.copyWith(rarity: () => r, slots: () => r.maxMods));
    }
  }

  Future<void> _addMod() async {
    final type = _r.typeOf(_t);
    final id = await _pick<String>('MOD', [
      for (final a in kAffixes.values)
        if (!_t.mods.any((m) => m.affixId == a.id) &&
            (type == null || a.allows(type)))
          PickOption(a.id, BuildPlanRules.affixLabel(a.id),
              a.slot == AffixSlot.prefix ? 'prefijo' : 'sufijo',
              key: 'mod-${a.id}'),
    ]);
    if (id == null) return;
    final def = kAffixes[id]!;
    final tier = await _pick<int>('TIER MÍNIMO (T1 es el mejor)', [
      for (final t in def.tiers.reversed)
        PickOption(t.tier, 'T${t.tier} o mejor', 'objeto Nv ${t.minLevel}+',
            key: 'tier-${t.tier}'),
    ]);
    if (tier != null) {
      setState(() => _t = _t.copyWith(mods: [..._t.mods, ModGoal(id, tier)]));
    }
  }

  Future<void> _editPassive() async {
    final type = _r.typeOf(_t);
    final id = await _pick<String>('PASIVA DE ARMA', [
      const PickOption('', 'Ninguna', null, key: 'wp-none'),
      for (final w in kWeaponPassives.values)
        if (!w.unique && (type == null || w.types.contains(type)))
          PickOption(w.id, w.name, w.descriptionAt(1), key: 'wp-${w.id}'),
    ]);
    if (id == null) return;
    if (id.isEmpty) {
      setState(() => _t = _t.copyWith(passive: () => null));
      return;
    }
    final lv = await _pick<int>('NIVEL MÍNIMO', [
      for (var l = 1; l <= 5; l++)
        PickOption(l, kWeaponPassives[id]!.nameAt(l), null, key: 'wpl-$l'),
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
    final id = await _pick<String>('HABILIDAD EN EL ARMA', [
      for (final s in list) PickOption(s.id, s.name, null, key: 'sk-${s.id}'),
    ]);
    if (id != null) {
      setState(() => _t = _t.copyWith(skills: [..._t.skills, id]));
    }
  }

  Future<void> _editIlvl() async {
    final v = await _pick<int>('NIVEL DE OBJETO MÍNIMO', [
      for (final l in const [10, 20, 30, 36, 40, 50])
        PickOption(l, 'Nv $l', null, key: 'ilvl-$l'),
    ]);
    if (v != null) setState(() => _t = _t.copyWith(itemLevel: () => v));
  }

  Future<void> _editForge() async {
    final s = await _pick<UpgradeStat>('FORJA', [
      for (final s in UpgradeStat.values)
        PickOption(s, s.label, 'pedís ${_t.forge[s] ?? 0}',
            key: 'forge-${s.key}'),
    ]);
    if (s == null) return;
    final l = await _pick<int>('NIVEL DE ${s.label.toUpperCase()}', [
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
    final id = await _pick<String>('QUITAR REQUISITO', [
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
