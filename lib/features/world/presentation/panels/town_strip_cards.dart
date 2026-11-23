import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../game_engine/models/world_save.dart';
import '../../../../game_engine/rules/town_rules.dart';
import '../map/map_game.dart';
import '../map/town_edit_layer.dart';
import '../session_controller.dart';

/// Tarjetas de las franjas fantasma de la edición (town_editor.md §
/// 1.3): en px de pantalla, centradas en la parte visible de cada franja
/// (debajo de la barra de arriba y a la izquierda del panel de la
/// derecha): AMPLIAR y, abajo, el costo de a un recurso por renglón con
/// lo que tenés (verde si alcanza, rojo si no). Se achican para entrar
/// en la franja; nunca se salen. Siguen a la cámara cuadro a cuadro.
class TownStripCards extends StatefulWidget {
  const TownStripCards(
      {super.key,
      required this.game,
      required this.controller,
      this.top = 0,
      this.right = 0});

  final MapGame game;
  final SessionController controller;

  /// Lo que tapan la barra de arriba y el panel de la derecha (px).
  final double top, right;

  @override
  State<TownStripCards> createState() => _TownStripCardsState();
}

class _TownStripCardsState extends State<TownStripCards>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      if (mounted) setState(() {});
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final view = c.view;
    final p = view?.me?.profile;
    if (view == null || p == null || c.townEdit == null) {
      return const SizedBox.shrink();
    }
    final g = widget.game;
    final town = c.town;
    final screen = MediaQuery.sizeOf(context);
    final area = Rect.fromLTRB(0, widget.top, screen.width - widget.right,
            screen.height)
        .intersect(g.screenView);
    final cost = TownRules.cost(town.expansions + 1);
    final lines = TownRules.costLines(p, cost);
    final w = view.map.width * TownEditLayer.ts,
        h = view.map.height * TownEditLayer.ts;
    return IgnorePointer(
      child: Stack(children: [
        for (final side in TownSide.values)
          if (TownRules.sideFull(town, side) == null)
            if (g.worldToScreen(TownEditLayer.stripRect(side, w, h))
                    .intersect(area)
                case final r when r.width > 24 && r.height > 24)
              Positioned.fromRect(
                rect: r.deflate(4),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _card(side, lines,
                        hot: c.townEdit?.hoverSide == side ||
                            c.townEdit?.side == side,
                        maxWidth: r.width - 8),
                  ),
                ),
              ),
      ]),
    );
  }

  Widget _card(TownSide side, List<({String name, int need, int have})> lines,
      {required bool hot, required double maxWidth}) {
    return Container(
      key: ValueKey('town-strip-${side.code}'),
      constraints: BoxConstraints(maxWidth: maxWidth.clamp(160, 360)),
      padding: EdgeInsets.all(DsSpace.sm),
      decoration: BoxDecoration(
        color: DsColors.background,
        border: Border.all(
            color: hot ? DsColors.selected : DsColors.border, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AMPLIAR', style: DsText.title()),
          SizedBox(height: DsSpace.xs),
          for (final l in lines)
            Text('${l.name} ${l.need} (tenés ${l.have})',
                key: ValueKey('town-strip-${side.code}-${l.name}'),
                softWrap: true,
                style: DsText.subtitle(
                    l.have >= l.need ? DsColors.success : DsColors.danger)),
        ],
      ),
    );
  }
}
