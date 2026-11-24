import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../app/theme/retro_type.dart';
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
/// detalle a la derecha (tamaño fijo, sin parpadeo al pasar el mouse); elegir una pieza la deja lista para poner en el mapa.
class TownBuildPalette extends StatefulWidget {
  const TownBuildPalette({super.key, required this.controller});

  final SessionController controller;

  static const cell = DsItemCell.size;

  /// Ancho de una casilla con su nombre (fijo: el hover no la mueve).
  static const cellWidth = 72.0;

  /// Alto de una casilla: cuadro + dos renglones de nombre.
  static const cellHeight = cell + 40.0;

  /// Alto fijo de grilla + detalle (dos filas de casillas).
  static const paneHeight = cellHeight * 2 + 24.0;

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
        TownPieceCategory.farm => DsColors.success,
        TownPieceCategory.water => DsColors.mp,
        TownPieceCategory.home => DsColors.warning,
        TownPieceCategory.light => DsColors.reward,
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
        // Grilla a la izquierda y detalle a la derecha, de tamaño fijo:
        // el hover cambia el CONTENIDO del detalle, nunca el tamaño ni la
        // posición de una casilla (así no parpadea).
        SizedBox(
          height: TownBuildPalette.paneHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: TownBuildPalette.cellWidth * 2 + DsSpace.xs,
                child: SingleChildScrollView(
                  key: const ValueKey('town-build-grid'),
                  child: Wrap(
                    spacing: DsSpace.xs,
                    runSpacing: DsSpace.xs,
                    children: [
                      for (final p in shown) _cell(s, c, p, p.id == placing)
                    ],
                  ),
                ),
              ),
              SizedBox(width: DsSpace.xs),
              Expanded(
                child: DsDetailPane(
                  key: const ValueKey('town-build-pane'),
                  sunken: true,
                  padding: EdgeInsets.all(DsSpace.sm),
                  body: _detail(
                      s, focus, placing != null && focus?.id == placing),
                ),
              ),
            ],
          ),
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
    final color = p.enabled ? _catColor(p.category) : DsColors.textDisabled;
    // Casilla de tamaño fijo (DsItemCell + nombre): el hover solo cambia
    // el detalle de la derecha, nunca mueve ni agranda la casilla.
    return MouseRegion(
      cursor: p.enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) {
        if (_hover != p.id) setState(() => _hover = p.id);
      },
      onExit: (_) {
        if (_hover == p.id) setState(() => _hover = null);
      },
      child: GestureDetector(
        key: ValueKey('town-edit-build-${p.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: p.enabled ? () => c.editChoose(p.id) : null,
        child: SizedBox(
          width: TownBuildPalette.cellWidth,
          height: TownBuildPalette.cellHeight,
          child: Column(children: [
            DsItemCell(
              icon: Text(
                s.t('ui.town.edit.footprint', {'w': p.w, 'h': p.h}),
                textAlign: TextAlign.center,
                textScaler: RetroType.fixedScaler(context),
                style: DsText.detail(color),
              ),
              border: color,
              selected: selected,
            ),
            Expanded(child: _PieceName(p.name, enabled: p.enabled)),
          ]),
        ),
      ),
    );
  }
}

/// Átomo: nombre de una casilla de la paleta. Hasta dos renglones,
/// cortando solo entre palabras; si no entra, se acorta con "…" y el
/// nombre completo va en un tooltip que no recibe el mouse.
class _PieceName extends StatelessWidget {
  const _PieceName(this.name, {required this.enabled});

  final String name;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final style = DsText.detail(enabled ? null : DsColors.textDisabled);
    final scaler = RetroType.fixedScaler(context);
    final dir = Directionality.of(context);
    return LayoutBuilder(builder: (context, box) {
      bool fits(String text, int lines) {
        final tp = TextPainter(
            text: TextSpan(text: text, style: style),
            maxLines: lines,
            textScaler: scaler,
            textDirection: dir)
          ..layout(maxWidth: box.maxWidth);
        final ok = !tp.didExceedMaxLines &&
            tp.width <= box.maxWidth &&
            tp.height <= box.maxHeight;
        tp.dispose();
        return ok;
      }

      final ok = fits(name, 2) && name.split(' ').every((w) => fits(w, 1));
      final text = Text(name,
          maxLines: ok ? 2 : 1,
          softWrap: ok,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          textScaler: scaler,
          style: style);
      if (ok) return text;
      return DsTooltip(
          card: IgnorePointer(child: DsTooltipCard(title: name)),
          child: text);
    });
  }
}
