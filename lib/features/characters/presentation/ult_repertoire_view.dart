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
import '../../../core/text/text_detail.dart';
import '../../../game_engine/models/player_state.dart';
import '../../combat/domain/skill_text.dart';
import '../../combat/presentation/game_sprites.dart';
import 'ult_preview_panel.dart';

/// Pestaña ULT de PERSONAJE (docs/specs/panels.md § Pestaña ULT,
/// ultimates_v2.md § 2.1.1 y § 2.4): arriba la ULT EQUIPADA, los
/// contadores y los filtros a todo el ancho; abajo una tabla de 4
/// columnas iguales (`DsColumnsTemplate`): LISTA, DESCRIPCIÓN, ACCIONES
/// (EQUIPAR, MEJORAR con confirmación, qué mejora y costo) y
/// PREVISUALIZACIÓN (vista previa animada).
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

  /// Alto mínimo de la tabla de columnas.
  static const minTable = 300.0;

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
  final _topKey = GlobalKey();
  double _topH = 0;
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
    final eq = all.where((e) => e.id == equipped).firstOrNull;
    final shown = UltBrowseRules.apply(
        [for (final e in all) if (e.id != equipped) e], _prefs,
        text: _text);
    final top = Column(
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
          _row(eq, equipped, sel?.id, key: ValueKey('ult-equipped-${eq.id}')),
        const DsSectionHeader('REPERTORIO'),
        _filters(p, all),
        SizedBox(height: DsSpace.sm),
      ],
    );
    final table = DsColumnsTemplate(
      key: const ValueKey('ult-table'),
      columns: [
        DsColumn(
            header: 'LISTA',
            key: const ValueKey('ult-col-list'),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (shown.isEmpty)
                    Text('Ninguna ULT con estos filtros.',
                        style: DsText.detail()),
                  for (final e in shown) _row(e, equipped, sel?.id),
                ])),
        DsColumn(
            header: 'DESCRIPCIÓN',
            key: const ValueKey('ult-col-desc'),
            child: sel == null ? const SizedBox() : _description(sel)),
        DsColumn(
            header: 'ACCIONES',
            key: const ValueKey('ult-col-actions'),
            child: sel == null ? const SizedBox() : _actions(sel, equipped)),
        DsColumn(
            header: 'PREVISUALIZACIÓN',
            key: const ValueKey('ult-col-preview'),
            scrollable: false,
            child: sel == null ? const SizedBox() : _preview(sel)),
      ],
    );
    return LayoutBuilder(builder: (context, box) {
      if (!box.hasBoundedHeight) {
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [top, SizedBox(height: 560, child: table)]);
      }
      // Arriba (equipada, contadores y filtros) con todo su alto, nada
      // recortado; la tabla toma el resto del panel (mínimo
      // [minTable]). Si no entra todo, scrollea el panel entero.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final h = (_topKey.currentContext?.findRenderObject() as RenderBox?)
            ?.size
            .height;
        if (mounted && h != null && (h - _topH).abs() > 0.5) {
          setState(() => _topH = h);
        }
      });
      final tableH = (box.maxHeight - _topH)
          .clamp(UltRepertoireView.minTable, double.infinity);
      return SingleChildScrollView(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
            KeyedSubtree(key: _topKey, child: top),
            SizedBox(height: tableH, child: table),
          ]));
    });
  }

  bool _learned(UltEntry e) =>
      e.owned && e.option?.kind == UltOptionKind.learned;

  Widget _preview(UltEntry e) {
    final p = widget.profile;
    final learned = _learned(e);
    final lv = learned ? UltRules.levelOf(p, e.id) : 1;
    final next = learned &&
        (_hoverUpgrade || _confirm) &&
        lv < UltRules.maxLevel;
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

  /// Contadores y barra de búsqueda y filtros a todo el ancho; lo que no
  /// entra baja a otra línea (v0.32.5: nada se corta).
  Widget _filters(PlayerProfile p, List<UltEntry> all) {
    final weapons = UltBrowseRules.weaponTypes(all);
    final origins = UltBrowseRules.origins(all);
    final known = {...p.ultKnown, ...UltRules.earned(p)};
    final got = kUltV2List.where((u) => known.contains(u.id)).length;
    final weaponLabel = _prefs.weapon == null ? 'Todas' : _cap(_prefs.weapon!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(spacing: DsSpace.sm, children: [
          Text('Las 50: $got/50', style: DsText.detail()),
          Text('Jefes vencidos: ${bossUltsDefeated(p)}/10',
              key: const ValueKey('ult-boss-progress'),
              style: DsText.detail()),
        ]),
        SizedBox(height: DsSpace.xs),
        Wrap(
          key: const ValueKey('ult-filter-bar'),
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
    final reason = e.option?.reason;
    // Nombre solo en su línea (completo, puede bajar); nivel y origen
    // abajo, también completos (v0.24.4).
    final detail = [
      if (_learned(e)) 'Nv ${e.level}',
      if (!e.owned) 'Falta · ${_how(e)}' else e.origin.label,
      if (e.owned && reason != null) reason,
    ].join(' · ');
    final fresh = widget.profile.ultNew.contains(e.id);
    final isEq = e.id == equipped;
    return DsListRow(
      key: key ?? ValueKey('ult-row-${e.id}'),
      compact: true,
      wrap: true,
      title: e.name,
      subtitle: detail,
      subtitleColor: e.available ? null : DsColors.textSecondary,
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

  /// Columna DESCRIPCIÓN: nombre, origen, cómo se consigue y la
  /// descripción corta; VER DETALLE abre el texto largo.
  Widget _description(UltEntry e) {
    final def = e.def;
    final reason = e.option?.reason;
    final lv = _learned(e) ? UltRules.levelOf(widget.profile, e.id) : 1;
    final skill = UltRules.leveled(e.skill, lv);
    return Column(
      key: ValueKey('ult-info-${e.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(e.name.toUpperCase(), style: DsText.subtitle()),
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
        ProtoText(
            TextDetail.run(TextDetail.summary,
                () => describeSkillMarkup(skill, null, ultimate: true)),
            key: const ValueKey('ult-desc-short')),
        SizedBox(height: DsSpace.xs),
        DsFold(
            key: const ValueKey('ult-detail-fold'),
            label: 'VER DETALLE',
            openLabel: 'OCULTAR DETALLE',
            child: ProtoText(TextDetail.run(TextDetail.full,
                () => describeSkillMarkup(skill, null, ultimate: true)))),
      ],
    );
  }

  /// Columna ACCIONES: EQUIPAR y MEJORAR arriba y, abajo, apilado, qué
  /// mejora (nivel, poder, daño y curación) y el costo.
  Widget _actions(UltEntry e, String? equipped) {
    final o = e.option;
    final isEq = e.id == equipped;
    final learned = _learned(e);
    final lv = learned ? UltRules.levelOf(widget.profile, e.id) : 1;
    final cost = learned ? UltRules.upgradeCost(e.id, lv) : null;
    return Column(
      key: ValueKey('ult-actions-${e.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: DsSpace.sm,
          runSpacing: DsSpace.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (isEq)
              const DsBadge('EQUIPADA')
            else if (e.owned)
              DsButton('EQUIPAR',
                  key: const ValueKey('ult-equip'),
                  kind: DsButtonKind.primary,
                  size: DsButtonSize.compact,
                  onPressed: widget.editable && e.available
                      ? () => widget.onSelect(e.id)
                      : null),
            if (o != null) ..._upgrade(o),
          ],
        ),
        if (learned) ...[
          SizedBox(height: DsSpace.sm),
          Text(
              'Nivel $lv/${UltRules.maxLevel}: poder ×'
              '${UltRules.levelFactor(lv).toStringAsFixed(2)}',
              style: DsText.body()),
          if (cost == null)
            Text('Nivel máximo.', style: DsText.detail())
          else
            _upgradeSummary(lv, cost),
        ] else if (!e.owned)
          Text('Todavía no la tenés.', style: DsText.detail()),
      ],
    );
  }

  /// Qué mejora al subir de nivel, una línea por cosa, y el costo.
  Widget _upgradeSummary(int lv, UltUpgradeCost cost) {
    final p = widget.profile;
    final a = UltRules.levelFactor(lv), b = UltRules.levelFactor(lv + 1);
    final pct = ((b / a - 1) * 100).round();
    return Column(
      key: const ValueKey('ult-upgrade-diff'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: DsSpace.xs),
        Text('AL MEJORAR: NIVEL $lv → ${lv + 1}', style: DsText.subtitle()),
        Text('Poder ×${a.toStringAsFixed(2)} → ×${b.toStringAsFixed(2)}',
            style: DsText.body(DsColors.success)),
        Text('Daño y curación +$pct %', style: DsText.body(DsColors.success)),
        Text('Escudos, trampas y golpes diferidos +$pct %',
            style: DsText.detail()),
        SizedBox(height: DsSpace.xs),
        Text('COSTO', style: DsText.subtitle()),
        Text('Créditos: ₵${cost.credits} (tenés ₵${p.credits})',
            key: const ValueKey('ult-upgrade-cost'),
            style: DsText.detail(p.credits >= cost.credits
                ? DsColors.textSecondary
                : DsColors.danger)),
        for (final m in cost.materials.entries)
          Text('${m.key.label}: ${m.value} (tenés ${p.material(m.key)})',
              style: DsText.detail(p.material(m.key) >= m.value
                  ? DsColors.textSecondary
                  : DsColors.danger)),
      ],
    );
  }

  /// MEJORAR (o CONFIRMAR / CANCELAR) con el costo al lado; gris si no
  /// alcanza. Con el mouse encima, la vista previa muestra el próximo
  /// nivel.
  List<Widget> _upgrade(UltOption o) {
    final p = widget.profile;
    if (o.kind != UltOptionKind.learned) return const [];
    final lv = UltRules.levelOf(p, o.id);
    final cost = UltRules.upgradeCost(o.id, lv);
    if (cost == null) return const [];
    final affordable = p.credits >= cost.credits &&
        cost.materials.entries.every((e) => p.material(e.key) >= e.value);
    if (_confirm) {
      return [
        DsButton('CONFIRMAR',
            key: const ValueKey('ult-upgrade-confirm'),
            kind: DsButtonKind.primary,
            size: DsButtonSize.compact,
            onPressed: () {
              widget.onUpgrade(o.id);
              setState(() => _confirm = false);
            }),
        DsButton('CANCELAR',
            key: const ValueKey('ult-upgrade-cancel'),
            size: DsButtonSize.compact,
            onPressed: () => setState(() => _confirm = false)),
      ];
    }
    return [
      MouseRegion(
        onEnter: (_) => setState(() => _hoverUpgrade = true),
        onExit: (_) => setState(() => _hoverUpgrade = false),
        child: DsButton('MEJORAR',
            key: const ValueKey('ult-upgrade'),
            kind: DsButtonKind.primary,
            size: DsButtonSize.compact,
            onPressed: widget.editable && affordable
                ? () => setState(() => _confirm = true)
                : null),
      ),
    ];
  }
}
