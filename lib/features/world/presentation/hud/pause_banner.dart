import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/panel_frame.dart';
import '../../../../app/theme/proto_colors.dart';
import '../../../../app/theme/retro_panel.dart';
import '../../../../app/theme/retro_text.dart';
import '../../../../app/theme/retro_theme.dart';

/// Cartel de la pausa de grupo, centrado y para todos los jugadores:
/// `<nombre> pausó el juego` + REANUDAR (cualquiera reanuda), o
/// `<nombre> reanudó el juego` unos segundos. Con la sala pausada tapa
/// el juego (los clics no llegan). Ver docs/specs/settings.md § "Pausa".
class PauseBanner extends StatelessWidget {
  const PauseBanner({
    super.key,
    this.pausedBy,
    this.resumedBy,
    required this.onResume,
  });

  /// Cuánto dura el aviso de "reanudó".
  static const resumedFor = Duration(milliseconds: 2500);

  /// Quién pausó (`null` = no está pausado).
  final String? pausedBy;

  /// Quién reanudó hace poco.
  final String? resumedBy;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final paused = pausedBy;
    if (paused == null) {
      // Solo el aviso: no bloquea nada.
      return IgnorePointer(
        child: Center(
          child: RetroPanel(
            key: const ValueKey('pause-banner-resumed'),
            child: Text(retroText('$resumedBy reanudó el juego'),
                style: TextStyle(
                    fontFamily: RetroType.bodyFamily,
                    letterSpacing: RetroType.letterSpacing,
                    fontFamilyFallback: RetroType.bodyFallback,
                    fontSize: RetroType.small,
                    color: ProtoColors.green)),
          ),
        ),
      );
    }
    return ColoredBox(
      color: ProtoColors.scrim(0.4),
      child: Center(
        child: RetroPanel(
          key: const ValueKey('pause-banner'),
          selected: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(retroText('$paused pausó el juego'),
                  style: TextStyle(
                      fontFamily: RetroType.titleFamily,
                      fontSize: 16,
                      color: ProtoColors.gold)),
              const SizedBox(height: 8),
              Text('Cualquier jugador puede reanudar.',
                  style: TextStyle(
                      fontFamily: RetroType.bodyFamily,
                      letterSpacing: RetroType.letterSpacing,
                      fontFamilyFallback: RetroType.bodyFallback,
                      fontSize: RetroType.small,
                      color: ProtoColors.dim)),
              const SizedBox(height: 16),
              PanelButton('REANUDAR',
                  key: const ValueKey('pause-banner-resume'),
                  accent: ProtoColors.green,
                  onPressed: onResume),
            ],
          ),
        ),
      ),
    );
  }
}
