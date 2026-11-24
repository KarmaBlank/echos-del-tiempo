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

/// Organismo: la ventana CONSTRUIR de la edición del pueblo
/// (town_editor.md § 1.2). Grilla de casillas estilo INVENTARIO con
/// filtros por categoría y el detalle a la derecha, para ir centrada en
/// la pantalla con el tamaño que le da su contenedor. Casillas y
/// columnas de tamaño fijo (sin parpadeo al pasar el mouse); elegir una
/// pieza la deja lista para poner en el mapa.
class TownBuildPalette extends StatefulWidget {
  const TownBuildPalette({super.key, required this.controller, this.onClose});

  final SessionController controller;

  /// Botón CERRAR de la cabecera (`null`: sin botón).
  final VoidCallback? onClose;

  static const cell = DsItemCell.size;

  /// Ancho de una casilla con su nombre (fijo: el hover no la mueve).
  static const cellWidth = 104.0;

  /// Alto de una casilla: cuadro + dos renglones de nombre.
  static const cellHeight = cell + 44.0;

  /// Lado de la miniatura grande del detalle.
  static const detailPreview = 96.0;

  /// Ancho fijo de la columna de detalle.
  static const detailWidth = 300.0;

  /// Tamaño de la ventana para un área de [box]: grande pero con margen.
  static Size windowSize(Size box) => Size(
        (box.width - 64).clamp(320.0, 900.0),
        (box.height - 48).clamp(240.0, 540.0),
      );

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
        // Grilla a la izquierda y detalle a la derecha, de tamaño fijo:
        // el hover cambia el CONTENIDO del detalle, nunca el tamaño ni la
        // posición de una casilla (así no parpadea).
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  key: const ValueKey('town-build-grid'),
                  child: Wrap(
                    spacing: DsSpace.sm,
                    runSpacing: DsSpace.sm,
                    children: [
                      for (final p in shown) _cell(s, c, p, p.id == placing)
                    ],
                  ),
                ),
              ),
              SizedBox(width: DsSpace.sm),
              SizedBox(
                width: TownBuildPalette.detailWidth,
                child: DsDetailPane(
                  key: const ValueKey('town-build-pane'),
                  sunken: true,
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
        Center(
          child: Padding(
            padding: EdgeInsets.only(bottom: DsSpace.sm),
            child: TownPiecePreview(p.id,
                key: const ValueKey('town-build-detail-preview'),
                size: TownBuildPalette.detailPreview),
          ),
        ),
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
              // Miniatura de la pieza con el tamaño como etiqueta chica
              // en la esquina (town_editor.md § 1.2).
              icon: SizedBox.square(
                dimension: TownBuildPalette.cell - 4,
                child: Stack(children: [
                  Center(
                    child: Opacity(
                      opacity: p.enabled ? 1 : 0.4,
                      child: TownPiecePreview(p.id,
                          size: TownBuildPalette.cell - 8),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      color: DsColors.surfaceSunken,
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Text(
                        s.t('ui.town.edit.footprint', {'w': p.w, 'h': p.h}),
                        textScaler: RetroType.fixedScaler(context),
                        style: DsText.detail(color)
                            .copyWith(fontSize: RetroType.label),
                      ),
                    ),
                  ),
                ]),
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
