import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import '../../../../game_engine/data/cozy_catalog.dart' show kFarmDecos;
import '../../../../game_engine/rules/cozy_rules.dart';

import '../../../../app/design/design.dart';
import '../../../../game_engine/data/construction_catalog.dart';
import '../../../../game_engine/models/town_build.dart';
import '../../../../game_engine/rules/animal_rules.dart';
import '../../../../game_engine/rules/farming_rules.dart' show FarmingRules;
import '../../../../game_engine/rules/helper_rules.dart';
import '../../../../game_engine/rules/resident_rules.dart';
import '../../../../game_engine/rules/town_rules.dart';
import '../session_controller.dart';
import '../world_strings.dart';
import 'item_source_text.dart';
import 'town_piece_preview.dart';

/// Filtro de la paleta (town_editor.md § 1.2).
enum TownPieceCategory { farm, water, home, light }

/// Una pieza de la paleta: qué se pone, cuánto ocupa y si se puede pagar.
class TownPiece {
  const TownPiece({
    required this.id,
    required this.category,
    required this.name,
    required this.w,
    required this.h,
    required this.detail,
    this.cost,
    this.costItems = const {},
    this.flags = const [],
    this.why,
  });

  final String id;
  final TownPieceCategory category;
  final String name;
  final int w, h;
  final String detail;

  /// Texto del costo; `null` = gratis.
  final String? cost;

  /// Items it costs (id → amount), shown as a cost grid.
  final Map<String, int> costItems;

  /// Its own traits (lights up at night, blocks the way...), already
  /// translated; only the ones that apply to this piece.
  final List<String> flags;

  /// Por qué no se puede poner ahora (o `null`).
  final String? why;

  bool get enabled => why == null;

  static TownPieceCategory categoryOf(BuildKind k) => switch (k) {
        BuildKind.huerta => TownPieceCategory.farm,
        BuildKind.lago => TownPieceCategory.water,
        BuildKind.casa => TownPieceCategory.home,
        BuildKind.gallinero || BuildKind.establo => TownPieceCategory.farm,
      };
}

/// Organismo: la ventana CONSTRUIR de la edición del pueblo
/// (town_editor.md § 1.2). Grilla de casillas estilo INVENTARIO con
/// filtros por categoría y el detalle a la derecha, con la regla
/// "elegir → detalle → acción fija" (design_system.md § "Grilla +
/// detalle"): un clic ELIGE la pieza (queda marcada y su detalle fijo),
/// el hover solo previsualiza mientras no hay nada elegido, y la pieza se
/// coloca con el botón COLOCAR fijo abajo del detalle (atajos: doble clic
/// en la casilla o Enter). Flechas mueven la selección, Esc cierra.
class TownBuildPalette extends StatefulWidget {
  const TownBuildPalette({super.key, required this.controller, this.onClose});

  final SessionController controller;

  /// Botón CERRAR de la cabecera (y Esc) (`null`: sin botón).
  final VoidCallback? onClose;

  /// Lado de la miniatura grande del detalle.
  static const detailPreview = 128.0;

  /// Ventana entre dos clics para el doble clic que coloca.
  static const doubleClick = Duration(milliseconds: 400);

  /// Tamaño de la ventana para un área de [box]: grande pero con margen.
  static Size windowSize(Size box) => Size(
        (box.width - 64).clamp(320.0, 1100.0),
        (box.height - 48).clamp(240.0, 680.0),
      );

  /// Las piezas que se pueden poner, con su costo y motivo.
  static List<TownPiece> pieces(Strings s, SessionController c) {
    final p = c.view?.me?.profile;
    String gold(int n) => s.t('ui.town.edit.gold', {'cost': n});
    String? cantPay(int n) => p == null
        ? s.t('ui.town.edit.no_character')
        : p.credits < n
            ? s.t('ui.town.edit.missing_gold', {'have': p.credits, 'need': n})
            : null;
    List<String> decorFlags(String id) => [
          if (id == 'lamp') s.t('ui.town.edit.flag_light'),
          if (id == 'fence') s.t('ui.town.edit.flag_blocks'),
          if (id == 'fence_gate') s.t('ui.town.edit.flag_passable'),
          if (id == 'stone_path') s.t('ui.town.edit.flag_walkable'),
        ];
    return [
      for (final d in kConstructions)
        if (animalHomeById(d.id) case final h?)
          // Coop / barn (animals.md § 3): gold and a Cultivo level.
          TownPiece(
            id: d.id,
            category: TownPieceCategory.farm,
            name: s.t('ui.town.ranch.${d.kind.name}.name'),
            w: d.w,
            h: d.h,
            detail: s.t('ui.town.ranch.${d.kind.name}.info',
                {'cap': h.cap, 'level': h.level}),
            cost: gold(h.price),
            why: p != null && FarmingRules.level(p) < h.level
                ? s.t('ui.town.ranch.need_level', {'n': h.level})
                : cantPay(h.price),
          )
        else if (d.kind == BuildKind.casa)
          TownPiece(
            id: d.id,
            category: TownPieceCategory.home,
            name: s.t('ui.town.build.${d.id}.name'),
            w: d.w,
            h: d.h,
            detail: s.t('ui.town.build.${d.id}.info'),
            cost: HelperRules.costText(ResidentRules.placeCost()),
            costItems: ResidentRules.placeCost().mats,
            why: p == null
                ? s.t('ui.town.edit.no_character')
                : HelperRules.cannotPay(p, ResidentRules.placeCost()),
          )
        else
          TownPiece(
            id: d.id,
            category: TownPiece.categoryOf(d.kind),
            name: s.t('ui.town.build.${d.id}.name'),
            w: d.w,
            h: d.h,
            detail: s.t('ui.town.build.${d.id}.info'),
          ),
      // Farm decorations (cozy_life.md § 2): 1×1, cheap, cosmetic.
      for (final d in kFarmDecos.values)
        TownPiece(
          id: d.id,
          category: TownPieceCategory.farm,
          name: s.t('ui.town.decor.${d.id}.name'),
          w: 1,
          h: 1,
          detail: s.t('ui.town.decor.${d.id}.info'),
          cost: gold(CozyRules.decorCost(d.id)),
          flags: decorFlags(d.id),
          why: cantPay(CozyRules.decorCost(d.id)),
        ),
      TownPiece(
        id: kFaroId,
        category: TownPieceCategory.light,
        name: s.t('ui.town.edit.lamp'),
        w: 1,
        h: 1,
        detail: s.t('ui.town.edit.lamp_info'),
        cost: gold(TownRules.faroCost),
        flags: [s.t('ui.town.edit.flag_light')],
        why: cantPay(TownRules.faroCost),
      ),
    ];
  }

  @override
  State<TownBuildPalette> createState() => _TownBuildPaletteState();
}

class _TownBuildPaletteState extends State<TownBuildPalette> {
  /// Filtro elegido: `null` = TODO.
  TownPieceCategory? _filter;

  /// Pieza elegida (fija): manda sobre el hover.
  String? _selected;

  /// Pieza bajo el mouse (solo previsualiza si no hay elegida).
  String? _hover;

  /// Último clic (para el doble clic que coloca).
  String? _lastTapId;
  DateTime? _lastTapAt;

  /// Columnas de la grilla (para las flechas): INVENTARIO's.
  static const _cols = DsSizes.gridColumns;

  final _focus = FocusNode(debugLabel: 'town-build-palette');

  @override
  void initState() {
    super.initState();
    final e = widget.controller.townEdit;
    if (e != null && e.step == TownEditStep.placing) _selected = e.placeDef;
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  static String _catKey(TownPieceCategory? c) => switch (c) {
        null => 'ui.town.edit.cat_all',
        TownPieceCategory.farm => 'ui.town.edit.cat_farm',
        TownPieceCategory.water => 'ui.town.edit.cat_water',
        TownPieceCategory.home => 'ui.town.edit.cat_home',
        TownPieceCategory.light => 'ui.town.edit.cat_light',
      };

  static Color _catColor(TownPieceCategory c) => switch (c) {
        TownPieceCategory.farm => DsColors.success,
        TownPieceCategory.water => DsColors.mp,
        TownPieceCategory.home => DsColors.warning,
        TownPieceCategory.light => DsColors.reward,
      };

  List<TownPiece> _shown(List<TownPiece> all) => [
        for (final p in all)
          if (_filter == null || p.category == _filter) p
      ];

  void _select(String id) {
    if (_selected != id) setState(() => _selected = id);
  }

  /// Coloca [p]: cierra la ventana y arranca la colocación.
  void _place(TownPiece p) {
    if (!p.enabled) return;
    final c = widget.controller;
    final e = c.townEdit;
    if (e != null && e.step == TownEditStep.placing && e.placeDef == p.id) {
      // Ya se está colocando esa pieza: solo cerrar (no la suelta).
      c.setBuildOpen(false);
    } else {
      c.editChoose(p.id);
    }
  }

  void _tap(TownPiece p) {
    final now = DateTime.now();
    final dbl = _lastTapId == p.id &&
        _lastTapAt != null &&
        now.difference(_lastTapAt!) <= TownBuildPalette.doubleClick;
    _lastTapId = dbl ? null : p.id;
    _lastTapAt = dbl ? null : now;
    _focus.requestFocus();
    _select(p.id);
    if (dbl) _place(p);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent ev) {
    if (ev is! KeyDownEvent && ev is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final k = ev.logicalKey;
    if (k == LogicalKeyboardKey.escape) {
      if (widget.onClose == null) return KeyEventResult.ignored;
      widget.onClose!();
      return KeyEventResult.handled;
    }
    final shown = _shown(
        TownBuildPalette.pieces(worldStrings(context), widget.controller));
    if (shown.isEmpty) return KeyEventResult.ignored;
    final i = shown.indexWhere((p) => p.id == _selected);
    if (ev is KeyDownEvent &&
        (k == LogicalKeyboardKey.enter ||
            k == LogicalKeyboardKey.numpadEnter)) {
      if (i < 0) return KeyEventResult.ignored;
      _place(shown[i]);
      return KeyEventResult.handled;
    }
    final step = switch (k) {
      LogicalKeyboardKey.arrowLeft => -1,
      LogicalKeyboardKey.arrowRight => 1,
      LogicalKeyboardKey.arrowUp => -_cols,
      LogicalKeyboardKey.arrowDown => _cols,
      _ => 0,
    };
    if (step == 0) return KeyEventResult.ignored;
    final to = i < 0 ? 0 : (i + step).clamp(0, shown.length - 1);
    _select(shown[to].id);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final s = worldStrings(context);
    final e = c.townEdit;
    final all = TownBuildPalette.pieces(s, c);
    final cats = <TownPieceCategory?>[
      null,
      for (final k in TownPieceCategory.values)
        if (all.any((p) => p.category == k)) k,
    ];
    final shown = _shown(all);
    final placing =
        e != null && e.step == TownEditStep.placing ? e.placeDef : null;
    final selected = all.where((p) => p.id == _selected).firstOrNull;
    // Elegida fija; sin elegida, el hover previsualiza.
    final focus = selected ?? all.where((p) => p.id == _hover).firstOrNull;
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Column(
        key: const ValueKey('town-build-palette'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DsSectionHeader(s.t('ui.town.edit.build'),
              trailing: widget.onClose == null
                  ? null
                  : DsButton(s.t('ui.town.edit.build_close'),
                      key: const ValueKey('town-build-close'),
                      size: DsButtonSize.compact,
                      onPressed: widget.onClose)),
          DsTabBar(
            key: const ValueKey('town-build-filters'),
            tabs: [
              for (final k in cats)
                DsTab(s.t(_catKey(k)),
                    key: ValueKey('town-build-filter-${k?.name ?? 'all'}'))
            ],
            index: cats.indexOf(_filter).clamp(0, cats.length - 1),
            onChanged: (i) => setState(() => _filter = cats[i]),
          ),
          SizedBox(height: DsSpace.sm),
          // INVENTARIO grid (design_system.md § DsGridDetailLayout): 6
          // cells top-left, the detail takes the rest of the width. Hover
          // only changes the detail CONTENT, never a cell (no flicker).
          Expanded(
            child: DsGridDetailLayout(
              keyPrefix: 'town-build',
              count: shown.length,
              cell: (context, i, size) => _cell(s, shown[i], size,
                  shown[i].id == selected?.id, shown[i].id == placing),
              detail: DsDetailPane(
                sunken: true,
                body: _detail(
                    s, focus, placing != null && focus?.id == placing),
                actions: selected == null
                    ? null
                    : SizedBox(
                        width: double.infinity,
                        child: DsButton(s.t('ui.town.edit.build_place'),
                            key: const ValueKey('town-build-place'),
                            kind: DsButtonKind.primary,
                            tooltip: selected.why,
                            onPressed: selected.enabled
                                ? () => _place(selected)
                                : null),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detail(Strings s, TownPiece? p, bool placing) {
    if (p == null) {
      return Text(s.t('ui.town.edit.palette_empty'),
          key: const ValueKey('town-build-detail'), style: DsText.body());
    }
    final err = placing ? widget.controller.editGhostError : null;
    final gap = SizedBox(height: DsSpace.xs);
    return Column(
      key: const ValueKey('town-build-detail'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Padding(
            padding: EdgeInsets.only(bottom: DsSpace.sm),
            child: TownPiecePreview(p.id,
                key: const ValueKey('town-build-detail-preview'),
                size: TownBuildPalette.detailPreview),
          ),
        ),
        Text(p.name,
            key: const ValueKey('town-build-detail-name'),
            style: DsText.title()),
        Text(s.t('ui.town.edit.size', {'w': p.w, 'h': p.h}),
            style: DsText.detail()),
        gap,
        DsGoldText(p.detail, style: DsText.body()),
        gap,
        DsGoldText(
            p.cost == null
                ? s.t('ui.town.edit.free')
                : s.t('ui.town.edit.cost', {'cost': p.cost}),
            style: p.enabled ? DsText.detail() : DsText.key()),
        for (final f in p.flags)
          Text(f, style: DsText.detail(DsColors.reward)),
        if (p.costItems.isNotEmpty) ...[
          gap,
          itemCostGrid(context, widget.controller.view?.me?.profile,
              p.costItems,
              key: const ValueKey('town-build-cost')),
        ],
        if (p.why case final why?)
          Text(why,
              key: const ValueKey('town-build-why'),
              style: DsText.key()),
        if (placing)
          Text(err ?? s.t('ui.town.edit.placing_info'),
              key: const ValueKey('town-edit-ghost'),
              style: DsText.detail(err == null ? null : DsColors.danger)),
      ],
    );
  }

  Widget _cell(
      Strings s, TownPiece p, double size, bool selected, bool placing) {
    final color = p.enabled ? _catColor(p.category) : DsColors.textDisabled;
    // INVENTARIO cell: only the piece preview; name, footprint and cost
    // go in the fixed-size tooltip (and the detail on the right).
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        if (_hover != p.id) setState(() => _hover = p.id);
      },
      onExit: (_) {
        if (_hover == p.id) setState(() => _hover = null);
      },
      child: DsTooltip(
        card: IgnorePointer(
          child: DsTooltipCard(title: p.name, children: [
            Text(s.t('ui.town.edit.size', {'w': p.w, 'h': p.h}),
                style: DsText.detail()),
            DsGoldText(
                p.cost == null
                    ? s.t('ui.town.edit.free')
                    : s.t('ui.town.edit.cost', {'cost': p.cost}),
                style: DsText.detail(p.enabled ? null : DsColors.danger)),
            for (final f in p.flags) Text(f, style: DsText.detail()),
            if (p.why case final why?)
              Text(why, style: DsText.detail(DsColors.danger)),
          ]),
        ),
        child: GestureDetector(
          key: ValueKey('town-edit-build-${p.id}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => _tap(p),
          child: DsItemCell(
            dimension: size,
            icon: Opacity(
              opacity: p.enabled ? 1 : 0.4,
              child: TownPiecePreview(p.id,
                  size: DsSizes.itemIcon * size / DsSizes.itemCell),
            ),
            border: placing ? DsColors.reward : color,
            selected: selected,
          ),
        ),
      ),
    );
  }
}
