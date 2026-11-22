import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../game_engine/data/achievements_catalog.dart';
import '../../../game_engine/data/classes_catalog.dart';
import '../../../game_engine/data/enemies_catalog.dart';
import '../../../game_engine/data/uniques_catalog.dart';
import '../../../game_engine/data/ults_v2_catalog.dart';
import '../../../game_engine/models/item.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/models/ult_def.dart';
import '../../../game_engine/models/weapon.dart';
import '../../../game_engine/rules/battle_engine.dart';
import '../../../game_engine/rules/js_math.dart';
import '../../../game_engine/rules/ult_browse_rules.dart';
import '../../../game_engine/rules/ult_rules.dart';
import '../../../core/audio/sfx_service.dart';
import '../../../game_engine/models/player_state.dart';
import '../../combat/domain/skill_text.dart';
import '../../combat/presentation/game_sprites.dart';
import 'ult_preview_panel.dart';

/// Pestaña ULT de PERSONAJE (docs/specs/ultimates_v2.md § 2.1.1 y § 2.4):
/// a la izquierda la ULT EQUIPADA fija arriba y el repertorio con
/// búsqueda, filtros (arma, origen, estado) y orden; a la derecha la
/// vista previa animada de la ULT elegida con clic y, abajo, su info
/// (EQUIPAR, nivel, MEJORAR con confirmación).
class UltRepertoireView extends StatefulWidget {
  const UltRepertoireView({
    super.key,
    required this.profile,
    required this.weapon,
    required this.item,
    required this.editable,
    required this.onSelect,
    required this.onUpgrade,
    this.onSeen,
    this.prefs = const UltBrowsePrefs(),
    this.onPrefs,
    this.stats,
    this.sprites,
    this.sfx,
  });

  /// Stats del personaje para los números de ejemplo de la vista previa.
  final DerivedStats? stats;
  final GameSprites? sprites;
  final SfxService? sfx;

  /// Ancho desde el que la vista previa va al lado de la lista.
  static const wideFrom = 760.0;

  /// Builds de la vista (tests: la vista previa no la reconstruye).
  static int debugBuilds = 0;

  final PlayerProfile profile;
  final WeaponDef weapon;
  final ItemInstance? item;

  /// Fuera de combate (pueblo o campamento).
  final bool editable;
  final bool Function(String? id) onSelect;
  final bool Function(String id) onUpgrade;

  /// Desmarca la NUEVA de una ULT al hacerle clic a su fila (manda
  /// `SeenItemsAction` con `ult:<id>`, ultimates_v2.md § 2.1.1). El hover
  /// no la desmarca.
  final void Function(List<String> ids)? onSeen;

  /// Filtros y orden con que arranca la lista (los de los ajustes).
  final UltBrowsePrefs prefs;

  /// Cambió un filtro o el orden (para guardarlo en los ajustes).
  final ValueChanged<UltBrowsePrefs>? onPrefs;

  static String get help => '<b>ULT</b><br>'
      'Tu repertorio: toda ULT que conseguís queda para siempre. Al '
      'conseguir un arma que enseña una ULT la aprendés en el momento. '
      'Hacé clic en una para verla y equipala fuera de combate; el arma equipada no la cambia. '
      'Sin elegir, se usa la ULT base de tu clase.<br>'
      'MEJORAR sube su nivel (1 a 5) con créditos y materiales.<br>'
      'Las cargas extra de ULT (árbol, mods, efectos) tienen un tope de '
      '${jsRound(BattleEngine.ultBonusPerTurn)}% por turno.';

  @override
  State<UltRepertoireView> createState() => _UltRepertoireViewState();
}

class _UltRepertoireViewState extends State<UltRepertoireView> {
  /// La ULT elegida con clic (`null` = la equipada).
  String? _selected;
  String _text = '';
  late UltBrowsePrefs _prefs = widget.prefs;
  bool _hoverUpgrade = false;
  bool _confirm = false;
  final _seenSent = <String>{};

  void _seen(String id) {
    if (!widget.profile.ultNew.contains(id) || !_seenSent.add(id)) return;
    widget.onSeen?.call(['${UltRules.seenPrefix}$id']);
  }

  /// Clic en una fila: la muestra a la derecha y le saca la NUEVA.
  void _select(String id) {
    _seen(id);
    setState(() {
      _selected = id;
      _confirm = false;
      _hoverUpgrade = false;
    });
  }

  void _setPrefs(UltBrowsePrefs p) {
    setState(() => _prefs = p);
    widget.onPrefs?.call(p);
  }

  String _name(String id) =>
      kUniques[id]?.name ??
      kAchievementsById[id]?.name ??
      kEnemies[id]?.name ??
      kClasses[id]?.name ??
      id;

  static String _cap(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final opts = UltRules.optionsOf(p, widget.weapon, widget.item);
    final active = UltRules.validSel(p, widget.weapon, widget.item);
    final equipped = active ??
        opts
            .where((o) => o.kind != UltOptionKind.learned || o.available)
            .firstOrNull
            ?.id;
    final all = UltBrowseRules.entries(p, widget.weapon, widget.item);
    UltRepertoireView.debugBuilds++;
    final sel = all.where((e) => e.id == (_selected ?? equipped)).firstOrNull;
    final right = sel == null
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
                _preview(sel),
                SizedBox(height: DsSpace.sm),
                _info(sel, equipped),
              ]);
    final list = _list(p, all, active, equipped, sel?.id);
    return LayoutBuilder(builder: (context, box) {
      if (right == null) return SingleChildScrollView(child: list);
      if (box.maxWidth >= UltRepertoireView.wideFrom) {
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: SingleChildScrollView(child: list)),
          SizedBox(width: DsSpace.md),
          SizedBox(
              width: (box.maxWidth * 0.4).clamp(260.0, 420.0),
              child: SingleChildScrollView(child: right)),
        ]);
      }
      // Angosta: la vista previa y su info arriba de la lista.
      return SingleChildScrollView(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [right, SizedBox(height: DsSpace.md), list]));
    });
  }

  bool _learned(UltEntry e) =>
      e.owned && e.option?.kind == UltOptionKind.learned;

  Widget _preview(UltEntry e) {
    final p = widget.profile;
    final learned = _learned(e);
    final lv = learned ? UltRules.levelOf(p, e.id) : 1;
    final next = learned && _hoverUpgrade && lv < UltRules.maxLevel;
    final shownLv = next ? lv + 1 : lv;
    return UltPreviewPanel(
      skill: UltRules.leveled(e.skill, shownLv),
      level: shownLv,
      nextLevel: next,
      classId: p.classId,
      ascensionId: p.ascension.id,
      weaponType: widget.weapon.type,
      stats: widget.stats,
      sprites: widget.sprites,
      sfx: widget.sfx,
    );
  }

  Widget _list(PlayerProfile p, List<UltEntry> all, String? active,
      String? equipped, String? selected) {
    final eq = all.where((e) => e.id == equipped).firstOrNull;
    final shown = UltBrowseRules.apply(
        [for (final e in all) if (e.id != equipped) e], _prefs,
        text: _text);
    final weapons = UltBrowseRules.weaponTypes(all);
    final origins = UltBrowseRules.origins(all);
    final known = {...p.ultKnown, ...UltRules.earned(p)};
    final got = kUltV2List.where((u) => known.contains(u.id)).length;
    final weaponLabel = _prefs.weapon == null ? 'Todas' : _cap(_prefs.weapon!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DsSectionHeader('ULT EQUIPADA',
            trailing: Text(
                p.ultSel == null
                    ? 'Automática'
                    : active == null
                        ? 'No disponible: se usa la ULT base'
                        : 'Elegida',
                style: DsText.detail())),
        if (eq != null)
          _row(eq, equipped, selected, key: ValueKey('ult-equipped-${eq.id}')),
        SizedBox(height: DsSpace.md),
        const DsSectionHeader('REPERTORIO'),
        Wrap(spacing: DsSpace.sm, children: [
          Text('Las 50: $got/50', style: DsText.detail()),
          Text('Jefes vencidos: ${bossUltsDefeated(p)}/10',
              key: const ValueKey('ult-boss-progress'),
              style: DsText.detail()),
        ]),
        SizedBox(height: DsSpace.xs),
        Wrap(
          spacing: DsSpace.sm,
          runSpacing: DsSpace.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DsSearchField(
                key: const ValueKey('ult-search'),
                hint: 'BUSCAR POR NOMBRE',
                width: 200,
                onChanged: (t) => setState(() => _text = t)),
            DsMenuButton<String?>(
                label: 'ARMA: $weaponLabel',
                options: [null, ...weapons],
                optionLabel: (w) => w == null ? 'Todas' : _cap(w),
                current: _prefs.weapon,
                onChanged: (w) => _setPrefs(_prefs.copyWith(weapon: () => w)),
                buttonKey: const ValueKey('ult-filter-weapon'),
                optionKey: (w) => ValueKey('ult-filter-weapon-${w ?? 'all'}')),
            DsMenuButton<UltOrigin?>(
                label: 'ORIGEN: ${_prefs.origin?.label ?? 'Todos'}',
                options: [null, ...origins],
                optionLabel: (o) => o?.label ?? 'Todos',
                current: _prefs.origin,
                onChanged: (o) => _setPrefs(_prefs.copyWith(origin: () => o)),
                buttonKey: const ValueKey('ult-filter-origin'),
                optionKey: (o) =>
                    ValueKey('ult-filter-origin-${o?.name ?? 'all'}')),
            DsMenuButton<UltOwnedFilter>(
                label: 'ESTADO: ${_prefs.owned.label}',
                options: UltOwnedFilter.values,
                optionLabel: (o) => o.label,
                current: _prefs.owned,
                onChanged: (o) => _setPrefs(_prefs.copyWith(owned: o)),
                buttonKey: const ValueKey('ult-filter-owned'),
                optionKey: (o) => ValueKey('ult-filter-owned-${o.name}')),
            DsMenuButton<UltSort>(
                label: 'ORDEN: ${_prefs.sort.label}',
                options: UltSort.values,
                optionLabel: (o) => o.label,
                current: _prefs.sort,
                onChanged: (o) => _setPrefs(_prefs.copyWith(sort: o)),
                buttonKey: const ValueKey('ult-sort'),
                optionKey: (o) => ValueKey('ult-sort-${o.name}')),
          ],
        ),
        SizedBox(height: DsSpace.xs),
        if (shown.isEmpty)
          Text('Ninguna ULT con estos filtros.', style: DsText.detail()),
        for (final e in shown) _row(e, equipped, selected),
      ],
    );
  }

  String _how(UltEntry e) {
    final u = e.def;
    if (u == null) return e.origin.label;
    return u.source == UltSource.boss
        ? bossUltShortText(u)
        : ultHowText(u, name: _name);
  }

  Widget _row(UltEntry e, String? equipped, String? selected, {Key? key}) {
    final lv = _learned(e) ? ' · Nv ${e.level}' : '';
    final reason = e.option?.reason;
    final detail = !e.owned
        ? 'Falta · ${_how(e)}'
        : reason == null
            ? e.origin.label
            : '${e.origin.label} · $reason';
    final fresh = widget.profile.ultNew.contains(e.id);
    final isEq = e.id == equipped;
    return DsListRow(
      key: key ?? ValueKey('ult-row-${e.id}'),
      compact: true,
      title: '${e.name}$lv',
      detail: detail,
      titleColor: e.available ? null : DsColors.textSecondary,
      selected: e.id == selected,
      // Solo el clic elige (el hover no cambia nada).
      onTap: () => _select(e.id),
      trailing: fresh || isEq
          ? Row(mainAxisSize: MainAxisSize.min, children: [
              if (fresh) DsBadge('NUEVA', key: ValueKey('ult-new-${e.id}')),
              if (fresh && isEq) SizedBox(width: DsSpace.sm),
              if (isEq) const DsBadge('EQUIPADA', neutral: true),
            ])
          : null,
    );
  }

  /// Info de la ULT elegida, abajo de la vista previa: origen, cómo se
  /// consigue, efecto, nivel y mejora, y EQUIPAR.
  Widget _info(UltEntry e, String? equipped) {
    final o = e.option;
    final def = e.def;
    final isEq = e.id == equipped;
    final reason = o?.reason;
    return Column(
      key: ValueKey('ult-info-${e.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DsSectionHeader(e.name.toUpperCase()),
        if (isEq || e.owned)
          Align(
            alignment: Alignment.centerLeft,
            child: isEq
                ? const DsBadge('EQUIPADA')
                : DsButton('EQUIPAR',
                    key: const ValueKey('ult-equip'),
                    kind: DsButtonKind.primary,
                    size: DsButtonSize.compact,
                    onPressed: widget.editable && e.available
                        ? () => widget.onSelect(e.id)
                        : null),
          ),
        Text(
            [
              e.origin.label,
              if (e.weapons.isNotEmpty) e.weapons.map(_cap).join(', '),
            ].join(' · '),
            style: DsText.detail()),
        if (reason != null) Text(reason, style: DsText.detail(DsColors.danger)),
        if (!e.owned && def != null) ...[
          Text(ultHowText(def, name: _name),
              style: DsText.detail(DsColors.text)),
          if (def.source == UltSource.boss)
            Text(bossUltStatusText(def, widget.profile),
                style: DsText.detail()),
        ],
        SizedBox(height: DsSpace.xs),
        if (o != null)
          _detail(o)
        else
          DsCard(
              child: ProtoText(
                  describeSkillMarkup(e.skill, null, ultimate: true))),
      ],
    );
  }

  Widget _detail(UltOption o) {
    final p = widget.profile;
    final learned = o.kind == UltOptionKind.learned;
    final lv = learned ? UltRules.levelOf(p, o.id) : 1;
    final cost = learned ? UltRules.upgradeCost(o.id, lv) : null;
    final affordable = cost != null &&
        p.credits >= cost.credits &&
        cost.materials.entries.every((e) => p.material(e.key) >= e.value);
    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProtoText(describeSkillMarkup(UltRules.leveled(o.skill, lv), null,
              ultimate: true)),
          if (learned) ...[
            SizedBox(height: DsSpace.sm),
            Text(
                'Nivel $lv/${UltRules.maxLevel}: poder ×'
                '${UltRules.levelFactor(lv).toStringAsFixed(2)}',
                style: DsText.body()),
            if (cost != null) ...[
              Text(
                  'Próximo nivel ${lv + 1}: poder ×'
                  '${UltRules.levelFactor(lv + 1).toStringAsFixed(2)}',
                  style: DsText.body()),
              Text('Costo: ${cost.text}',
                  style: DsText.detail(
                      affordable ? DsColors.textSecondary : DsColors.danger)),
              SizedBox(height: DsSpace.sm),
              Row(children: [
                if (!_confirm)
                  // Hover de MEJORAR: la vista previa muestra el próximo
                  // nivel.
                  MouseRegion(
                    onEnter: (_) => setState(() => _hoverUpgrade = true),
                    onExit: (_) => setState(() => _hoverUpgrade = false),
                    child: DsButton('MEJORAR',
                        kind: DsButtonKind.primary,
                        onPressed: widget.editable && affordable
                            ? () => setState(() => _confirm = true)
                            : null),
                  )
                else ...[
                  DsButton('CONFIRMAR MEJORA',
                      kind: DsButtonKind.primary,
                      onPressed: () {
                        widget.onUpgrade(o.id);
                        setState(() => _confirm = false);
                      }),
                  SizedBox(width: DsSpace.sm),
                  DsButton('CANCELAR',
                      onPressed: () => setState(() => _confirm = false)),
                ],
              ]),
            ] else
              Text('Nivel máximo.', style: DsText.detail()),
          ],
        ],
      ),
    );
  }
}
