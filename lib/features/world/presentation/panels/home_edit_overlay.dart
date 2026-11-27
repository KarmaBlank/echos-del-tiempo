import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../game_engine/data/home_furniture_catalog.dart';
import '../../../../game_engine/rules/home_interior_rules.dart';
import '../../../../game_engine/rules/life_craft_rules.dart' show kLifeMaterials;
import '../home_edit.dart';
import '../session_controller.dart';
import '../world_strings.dart';
import 'life_icon.dart';
import 'life_item_grid.dart';

/// One entry of the AMUEBLAR palette: a piece of furniture, a wall or
/// floor material, or a paint (`paint:<n>`).
class HomePaletteEntry {
  const HomePaletteEntry(this.id, this.filter);
  final String id;

  /// `bed`, `wall`, `use`, `decor` or `surface`.
  final String filter;

  bool get isPaint => id.startsWith('paint:');
  bool get isSurface => homeSurface(id) != null;
  FurnitureDef? get def => furniture(id);
}

/// EDITAR CASA (player_house.md § 8.3): bar on top (title, hint, AMUEBLAR,
/// LISTO [ESC]), the room under it takes the clicks (place, move, pick),
/// the menu of the picked piece (MOVER · BORRAR) and the AMUEBLAR window:
/// an INVENTARIO grid with filters as subtabs and the detail on the right.
class HomeEditOverlay extends StatelessWidget {
  const HomeEditOverlay(
      {super.key, required this.controller, required this.tileAt});

  final SessionController controller;

  /// Room tile under a screen point (`MapGame.tileAtScreen`).
  final (int, int)? Function(Offset p) tileAt;

  static const barHeight = 56.0;

  static const filters = ['all', 'bed', 'wall', 'use', 'decor', 'surface'];

  static List<HomePaletteEntry> entries(String filter) => [
        for (final f in kHomeFurniture)
          if (filter == 'all' || filter == f.kind.filter)
            HomePaletteEntry(f.id, f.kind.filter),
        if (filter == 'all' || filter == 'surface') ...[
          for (final s in kHomeSurfaces) HomePaletteEntry(s.id, 'surface'),
          for (var i = 1; i < kHomePaints.length; i++)
            HomePaletteEntry('paint:$i', 'surface'),
        ],
      ];

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final e = c.homeEdit;
    if (e == null) return const SizedBox.shrink();
    final hint = c.homeGhostWhy ??
        switch (e.step) {
          HomeEditStep.placing => context.t('ui.town.home.edit.hint_place'),
          HomeEditStep.moving => context.t('ui.town.home.edit.hint_move'),
          HomeEditStep.browse => context.t('ui.town.home.edit.hint'),
        };
    final selected = e.selected == null ? null : c.homeLayout.piece(e.selected!);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        key: const ValueKey('home-edit-bar'),
        color: DsColors.background,
        height: barHeight,
        padding:
            EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.xs),
        child: Row(children: [
          Text(context.t('ui.town.home.edit.title'), style: DsText.title()),
          SizedBox(width: DsSpace.md),
          Expanded(
              child: Text(hint,
                  key: const ValueKey('home-edit-hint'),
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  style: DsText.subtitle(c.homeGhostWhy != null
                      ? DsColors.danger
                      : DsColors.textPrimary))),
          SizedBox(width: DsSpace.md),
          DsButton(context.t('ui.town.home.edit.palette'),
              key: const ValueKey('home-edit-palette-toggle'),
              size: DsButtonSize.compact,
              selected: e.paletteOpen,
              onPressed: c.homeEditTogglePalette),
          SizedBox(width: DsSpace.xs),
          DsButton(context.t('ui.town.home.edit.done'),
              key: const ValueKey('home-edit-done'),
              size: DsButtonSize.compact,
              kind: DsButtonKind.primary,
              onPressed: c.exitHomeEdit),
        ]),
      ),
      Expanded(
        child: Stack(children: [
          // The room takes the clicks: place, move or pick a piece.
          Positioned.fill(
            key: const ValueKey('home-edit-pointer'),
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (p) {
                if (p.buttons != kPrimaryMouseButton) return;
                final t = tileAt(p.localPosition + const Offset(0, barHeight));
                if (t != null) c.homeClick(t.$1, t.$2);
              },
              child: MouseRegion(
                opaque: false,
                onExit: (_) => c.homeHover(null),
                onHover: (p) => c.homeHover(
                    tileAt(p.localPosition + const Offset(0, barHeight))),
              ),
            ),
          ),
          if (selected != null && e.step == HomeEditStep.browse)
            Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: EdgeInsets.all(DsSpace.md),
                child: DsCard(
                  key: const ValueKey('home-edit-menu'),
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(context.t('ui.town.home.f.${selected.id}.name'),
                            style: DsText.subtitle()),
                        SizedBox(height: DsSpace.xs),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          DsButton(context.t('ui.town.home.edit.move'),
                              key: const ValueKey('home-edit-move'),
                              size: DsButtonSize.compact,
                              onPressed: c.homeStartMove),
                          SizedBox(width: DsSpace.xs),
                          DsButton(context.t('ui.town.home.edit.remove'),
                              key: const ValueKey('home-edit-remove'),
                              size: DsButtonSize.compact,
                              tooltip: c.homeRemoveWhy,
                              onPressed: c.homeRemoveWhy == null
                                  ? c.homeRemoveSelected
                                  : null),
                          SizedBox(width: DsSpace.xs),
                          DsButton(context.t('ui.town.home.edit.cancel'),
                              key: const ValueKey('home-edit-cancel'),
                              size: DsButtonSize.compact,
                              onPressed: c.homeEditBack),
                        ]),
                      ]),
                ),
              ),
            ),
          if (e.paletteOpen)
            Center(
              child: LayoutBuilder(
                builder: (context, box) => SizedBox(
                  width: (box.maxWidth - 64).clamp(320.0, 1100.0),
                  height: (box.maxHeight - 48).clamp(240.0, 640.0),
                  child: HomePalette(controller: c),
                ),
              ),
            ),
        ]),
      ),
    ]);
  }
}

/// The AMUEBLAR window (player_house.md § 8.3): filters as subtabs, the
/// INVENTARIO grid and the detail with the fixed action (COLOCAR or
/// APLICAR), grey with the reason in its tooltip when it cannot be done.
class HomePalette extends StatelessWidget {
  const HomePalette({super.key, required this.controller});

  final SessionController controller;

  String _name(BuildContext context, HomePaletteEntry e) => e.isPaint
      ? context.t('ui.town.home.paint.name', {'n': e.id.substring(6)})
      : e.isSurface
          ? context.t('ui.town.home.s.${e.id}.name')
          : context.t('ui.town.home.f.${e.id}.name');

  Widget _icon(HomePaletteEntry e, double size) {
    if (e.isPaint) {
      final n = int.parse(e.id.substring(6));
      return Container(
          width: size * 0.6,
          height: size * 0.6,
          decoration: BoxDecoration(
              color: Color(0xFF000000 | kHomePaints[n]),
              border: Border.all(color: DsColors.border)));
    }
    final sprite = e.isSurface ? homeSurface(e.id)!.sprite : e.def!.sprite;
    return LifeIcon(sprite, LifeIconKind.herramienta, size: size * 0.7);
  }

  /// Why the action of [e] is grey (localized), or `null`.
  String? _why(SessionController c, HomePaletteEntry e) {
    if (e.isPaint) {
      final p = c.view?.me?.profile;
      if (p == null) return c.strings.t('ui.town.edit.no_character');
      final why = HomeInteriorRules.cannotPaint(p, int.parse(e.id.substring(6)));
      return why == null ? null : c.homeReason(why);
    }
    if (e.isSurface) {
      final l = c.homeLayout;
      final d = homeSurface(e.id)!;
      if ((d.wall ? l.wall : l.floor) == e.id) {
        return c.strings.t('ui.town.home.why.already');
      }
    }
    return c.homeBuyWhy(e.id);
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final edit = c.homeEdit!;
    final list = HomeEditOverlay.entries(edit.filter);
    final sel = list.where((x) => x.id == edit.picked).firstOrNull ??
        list.firstOrNull;
    Widget? detail;
    if (sel != null) {
      final why = _why(c, sel);
      final cost = sel.isPaint
          ? (gold: HomeInteriorRules.paintGold, mats: const <String, int>{})
          : (() {
              final k = HomeInteriorRules.costOf(sel.id);
              return (gold: k.gold, mats: k.mats);
            })();
      detail = DsDetailPane(
        key: const ValueKey('home-palette-detail'),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: _icon(sel, 128)),
            SizedBox(height: DsSpace.sm),
            Text(_name(context, sel), softWrap: true, style: DsText.title()),
            if (sel.def case final d?)
              Text(context.t('ui.town.home.size', {'w': d.w, 'h': d.h}),
                  style: DsText.detail(DsColors.textSecondary)),
            if (!sel.isPaint)
              Text(
                  context.t('ui.town.home.level',
                      {'n': HomeInteriorRules.levelOf(sel.id)}),
                  style: DsText.detail(DsColors.textSecondary)),
            Text(
                [
                  context.t('ui.town.home.cost', {'gold': cost.gold}),
                  for (final m in cost.mats.entries)
                    '${kLifeMaterials[m.key]?.name ?? m.key} × ${m.value}',
                ].join(' · '),
                style: DsText.detail(
                    why == null ? DsColors.textSecondary : DsColors.danger)),
            SizedBox(height: DsSpace.xs),
            Text(
                sel.isPaint
                    ? context.t('ui.town.home.paint.info')
                    : sel.isSurface
                        ? context.t('ui.town.home.s.${sel.id}.info')
                        : context.t('ui.town.home.f.${sel.id}.info'),
                softWrap: true,
                style: DsText.body()),
          ],
        ),
        actions: DsButton(
            sel.def != null
                ? context.t('ui.town.home.edit.place')
                : context.t('ui.town.home.edit.apply'),
            key: const ValueKey('home-palette-action'),
            kind: DsButtonKind.primary,
            tooltip: why,
            onPressed: why != null
                ? null
                : () => sel.def != null
                    ? c.homeStartPlacing(sel.id)
                    : c.homeApplySurface(sel.id)),
      );
    }
    return DsCard(
      key: const ValueKey('home-palette'),
      child: DsGridDetailLayout(
        keyPrefix: 'home-build',
        header: Wrap(spacing: DsSpace.xs, children: [
          for (final f in HomeEditOverlay.filters)
            DsButton(context.t('ui.town.home.filter.$f'),
                key: ValueKey('home-filter-$f'),
                size: DsButtonSize.compact,
                selected: edit.filter == f,
                onPressed: () => c.homeEditFilter(f)),
        ]),
        count: list.length,
        detail: detail,
        cell: (context, i, size) {
          final x = list[i];
          final dim = _why(c, x) != null;
          return KeyedSubtree(
            key: ValueKey('home-build-cell-${x.id}'),
            child: GestureDetector(
              onDoubleTap: () {
                if (_why(c, x) != null) return;
                x.def != null
                    ? c.homeStartPlacing(x.id)
                    : c.homeApplySurface(x.id);
              },
              child: LifeItemCell(
                size: size,
                selected: x.id == sel?.id,
                onTap: () => c.homeEditPick(x.id),
                data: LifeItemCellData(
                  id: 'home-build-item-${x.id}',
                  icon: Opacity(opacity: dim ? 0.4 : 1, child: _icon(x, size)),
                  border: DsColors.border,
                  search: _name(context, x),
                  detail: LifeItemDetail(
                      name: _name(context, x),
                      nameColor: DsColors.textTitle,
                      lines: [
                        if (_why(c, x) case final w?) w,
                      ]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
