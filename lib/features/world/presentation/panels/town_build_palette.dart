import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../app/theme/proto_colors.dart';
import '../../../../game_engine/data/construction_catalog.dart';
import '../../../../game_engine/models/town_build.dart';
import '../../../../game_engine/rules/helper_rules.dart';
import '../../../../game_engine/rules/resident_rules.dart';
import '../../../../game_engine/rules/town_rules.dart';
import '../session_controller.dart';
import '../world_strings.dart';

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
    this.why,
  });

  final String id;
  final TownPieceCategory category;
  final String name;
  final int w, h;
  final String detail;

  /// Texto del costo; `null` = gratis.
  final String? cost;

  /// Por qué no se puede poner ahora (o `null`).
  final String? why;

  bool get enabled => why == null;

  static TownPieceCategory categoryOf(BuildKind k) => switch (k) {
        BuildKind.huerta => TownPieceCategory.farm,
        BuildKind.lago => TownPieceCategory.water,
        BuildKind.casa => TownPieceCategory.home,
      };
}

/// Organismo: la paleta de la edición del pueblo (town_editor.md § 1.2).
/// Grilla de casillas estilo INVENTARIO con filtros por categoría y el
/// detalle arriba; elegir una pieza la deja lista para poner en el mapa.
class TownBuildPalette extends StatefulWidget {
  const TownBuildPalette({super.key, required this.controller});

  final SessionController controller;

  static const cell = 48.0;

  /// Las piezas que se pueden poner, con su costo y motivo.
  static List<TownPiece> pieces(Strings s, SessionController c) {
    final p = c.view?.me?.profile;
    return [
      for (final d in kConstructions)
        if (d.kind == BuildKind.casa)
          TownPiece(
            id: d.id,
            category: TownPieceCategory.home,
            name: d.name,
            w: d.w,
            h: d.h,
            detail: d.detail,
            cost: HelperRules.costText(ResidentRules.placeCost()),
            why: p == null
                ? s.t('ui.town.edit.no_character')
                : HelperRules.cannotPay(p, ResidentRules.placeCost()),
          )
        else
          TownPiece(
            id: d.id,
            category: TownPiece.categoryOf(d.kind),
            name: d.name,
            w: d.w,
            h: d.h,
            detail: d.detail,
          ),
      TownPiece(
        id: kFaroId,
        category: TownPieceCategory.light,
        name: s.t('ui.town.edit.lamp'),
        w: 1,
        h: 1,
        detail: s.t('ui.town.edit.lamp_info'),
        cost: s.t('ui.town.edit.lamp_detail', {'cost': TownRules.faroCost}),
        why: p == null
            ? s.t('ui.town.edit.no_character')
            : p.credits < TownRules.faroCost
                ? s.t('ui.town.edit.missing_gold',
                    {'have': p.credits, 'need': TownRules.faroCost})
                : null,
      ),
    ];
  }

  @override
  State<TownBuildPalette> createState() => _TownBuildPaletteState();
}

class _TownBuildPaletteState extends State<TownBuildPalette> {
  /// Filtro elegido: `null` = TODO.
  TownPieceCategory? _filter;
  String? _hover;

  static String _catKey(TownPieceCategory? c) => switch (c) {
        null => 'ui.town.edit.cat_all',
        TownPieceCategory.farm => 'ui.town.edit.cat_farm',
        TownPieceCategory.water => 'ui.town.edit.cat_water',
        TownPieceCategory.home => 'ui.town.edit.cat_home',
        TownPieceCategory.light => 'ui.town.edit.cat_light',
      };

  static Color _catColor(TownPieceCategory c) => switch (c) {
        TownPieceCategory.farm => ProtoColors.green,
        TownPieceCategory.water => ProtoColors.ice,
        TownPieceCategory.home => ProtoColors.orange,
        TownPieceCategory.light => ProtoColors.gold,
      };

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
    final shown = [
      for (final p in all)
        if (_filter == null || p.category == _filter) p
    ];
    final placing =
        e != null && e.step == TownEditStep.placing ? e.placeDef : null;
    final focus = all.where((p) => p.id == _hover).firstOrNull ??
        all.where((p) => p.id == placing).firstOrNull;
    return Column(
      key: const ValueKey('town-build-palette'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        DsSectionHeader(s.t('ui.town.edit.build')),
        _detail(s, focus, placing != null && focus?.id == placing),
        SizedBox(height: DsSpace.xs),
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
        SizedBox(height: DsSpace.xs),
        Wrap(
          spacing: DsSpace.xs,
          runSpacing: DsSpace.xs,
          children: [for (final p in shown) _cell(s, c, p, p.id == placing)],
        ),
      ],
    );
  }

  Widget _detail(Strings s, TownPiece? p, bool placing) {
    if (p == null) {
      return Text(s.t('ui.town.edit.palette_empty'),
          key: const ValueKey('town-build-detail'), style: DsText.detail());
    }
    final err = placing ? widget.controller.editGhostError : null;
    return Column(
      key: const ValueKey('town-build-detail'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(p.name, style: DsText.body(_catColor(p.category))),
        Text(s.t('ui.town.edit.size', {'w': p.w, 'h': p.h}),
            style: DsText.detail()),
        Text(p.detail, style: DsText.detail()),
        Text(
            p.cost == null
                ? s.t('ui.town.edit.free')
                : s.t('ui.town.edit.cost', {'cost': p.cost}),
            style: DsText.detail(p.enabled ? null : DsColors.danger)),
        if (p.why case final why?)
          Text(why, style: DsText.detail(DsColors.danger)),
        if (placing)
          Text(err ?? s.t('ui.town.edit.placing_info'),
              key: const ValueKey('town-edit-ghost'),
              style: DsText.detail(err == null ? null : DsColors.danger)),
      ],
    );
  }

  Widget _cell(Strings s, SessionController c, TownPiece p, bool selected) {
    const size = TownBuildPalette.cell;
    final color = p.enabled ? _catColor(p.category) : DsColors.textDisabled;
    final box = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: ProtoColors.input,
        border: Border.all(
            color: selected ? DsColors.selected : color,
            width: selected ? 3 : 1),
      ),
      alignment: Alignment.center,
      child: Text(
        s.t('ui.town.edit.footprint', {'w': p.w, 'h': p.h}),
        textAlign: TextAlign.center,
        style: DsText.detail(color),
      ),
    );
    return MouseRegion(
      cursor: p.enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = p.id),
      onExit: (_) {
        if (_hover == p.id) setState(() => _hover = null);
      },
      child: GestureDetector(
        key: ValueKey('town-edit-build-${p.id}'),
        onTap: p.enabled ? () => c.editChoose(p.id) : null,
        child: SizedBox(
          width: size + DsSpace.md,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            box,
            Text(p.name,
                maxLines: 2,
                textAlign: TextAlign.center,
                style: DsText.detail(p.enabled ? null : DsColors.textDisabled)),
          ]),
        ),
      ),
    );
  }
}
