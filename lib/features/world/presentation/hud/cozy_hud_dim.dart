import 'package:material_ui/material_ui.dart';

import '../../../../game_engine/rules/cozy_rules.dart';

/// While fishing the HUD steps back (cozy_life.md § 1): it fades to
/// `cozyHudOpacity` and comes back when the rod is put away. It never
/// changes size or position: only the world camera zooms. Pointer input
/// still reaches it.
class CozyHudDim extends StatelessWidget {
  const CozyHudDim({super.key, required this.calm, required this.child});

  /// The local player is fishing.
  final bool calm;
  final Widget child;

  static const duration = Duration(milliseconds: 700);

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
        key: const ValueKey('cozy-hud-dim'),
        opacity: calm ? CozyRules.hudOpacity : 1,
        duration: duration,
        curve: Curves.easeInOut,
        child: child,
      );
}
