import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/panel_frame.dart';
import '../../../../app/theme/proto_colors.dart';
import '../../../../app/theme/retro_text.dart';
import '../../../../app/theme/retro_type.dart';
import '../../../../app/widgets/menu_focus.dart';
import '../../../../app/widgets/points_badge.dart';
import '../../../../game_engine/models/game_session.dart';
import '../../../characters/domain/unused_points.dart';
import '../session_controller.dart';
import '../session_view.dart';

/// Selector de miembro de la party jugando solo (docs/specs/
/// solo_party.md § 6.2): `Ana (vos) · Leo · Mia · Cid`, cada uno con su
/// insignia `+N` de puntos sin usar. El elegido es el **miembro activo**
/// del controlador: los paneles de personaje, inventario y tiendas lo
/// muestran y actúan sobre él. Sin compañeros no ocupa lugar.
class PartyMemberBar extends StatelessWidget {
  const PartyMemberBar({
    super.key,
    required this.view,
    required this.controller,
  });

  final SessionView view;
  final SessionController controller;

  /// Se ve: hay compañeros y no es el reparto obligatorio del líder.
  static bool shows(SessionView v) =>
      v.companions.isNotEmpty && !v.mustAllocate;

  /// [tabs] con el selector arriba (si se ve): para `PanelFrame.header`.
  static Widget header(SessionView v, SessionController c, Widget tabs) =>
      shows(v)
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [PartyMemberBar(view: v, controller: c), tabs],
            )
          : tabs;

  @override
  Widget build(BuildContext context) {
    if (!shows(view)) return const SizedBox.shrink();
    final rules = controller.engine.progression;
    final actor = view.actorId;
    final dim = RetroType.style(RetroType.small, color: ProtoColors.dim);
    return Padding(
      key: const ValueKey('party-member-bar'),
      // Lugar para las insignias `+N` de las pestañas, que suben un poco.
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(retroText('PERSONAJE:'), style: dim),
          for (final id in [view.localId, ...view.companions])
            if (view.session.players[id] case final SessionPlayer p)
              _member(p, id == actor, UnusedPoints.of(p.profile, rules)),
          // Sin flechas Unicode: la fuente pixel no las tiene.
          Text(retroText('Ctrl+Izq / Ctrl+Der'), style: dim),
        ],
      ),
    );
  }

  Widget _member(SessionPlayer p, bool selected, UnusedPoints points) {
    final local = p.id == view.localId;
    return RetroTooltip(
      message: points.any
          ? '<b>${retroText(p.name)}</b>: puntos sin usar<br>'
              '${points.parts.map(retroText).join('<br>')}'
          : '<b>${retroText(p.name)}</b>: sin puntos sin usar',
      // La insignia dentro del botón, a la derecha del nombre (v0.10.1).
      child: PanelButton(local ? '${p.name} (vos)' : p.name,
          key: ValueKey('member-${p.id}'),
          selected: selected,
          onPressed: () => controller.setActing(p.id),
          trailing: points.any
              ? PointsBadge(
                  key: ValueKey('member-points-${p.id}'),
                  count: points.total,
                  pulse: false,
                )
              : null),
    );
  }
}

/// `Ctrl+←` / `Ctrl+→`: miembro anterior / siguiente. Envuelve el panel
/// entero (afuera del marco, como `MenuTabKeys`); `PanelFrame` y
/// `FocusGrid` dejan pasar las flechas con `Ctrl`.
class PartyMemberKeys extends StatelessWidget {
  const PartyMemberKeys({
    super.key,
    required this.view,
    required this.controller,
    required this.child,
  });

  final SessionView view;
  final SessionController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (_, e) {
        if (e is! KeyDownEvent ||
            !PartyMemberBar.shows(view) ||
            typingInField()) {
          return KeyEventResult.ignored;
        }
        final hw = HardwareKeyboard.instance;
        if (!hw.isControlPressed || hw.isAltPressed || hw.isMetaPressed) {
          return KeyEventResult.ignored;
        }
        final d = switch (e.logicalKey) {
          LogicalKeyboardKey.arrowLeft => -1,
          LogicalKeyboardKey.arrowRight => 1,
          _ => 0,
        };
        if (d == 0) return KeyEventResult.ignored;
        controller.cycleActing(d);
        return KeyEventResult.handled;
      },
      child: child,
    );
  }
}
