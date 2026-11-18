import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/settings/crt_filter.dart';
import '../core/settings/game_settings.dart';
import '../core/settings/settings_providers.dart';
import '../features/lobby/presentation/title_screen.dart';
import 'theme/retro_theme.dart';
import 'theme/ui_theme.dart';
import 'theme/vision_palette.dart';
import 'widgets/perf_overlay.dart';

/// Shell de la app. Todas las pantallas reales (lobby, personaje,
/// batalla con Flame, etc.) se agregan en `features/*/presentation` y
/// se enrutan desde acá — este archivo se mantiene chico a propósito.
///
/// Flujo: título (nombre y clase, `features/lobby`) → `WorldScreen`
/// (lobby, misión, batalla y resultado los decide la sesión;
/// docs/specs/exploration.md).
class EcosApp extends StatelessWidget {
  const EcosApp({super.key, this.overrides = const []});

  /// Overrides de Riverpod (tests: motor determinístico, store en memoria).
  final List<Override> overrides;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        title: 'Ecos del Tiempo',
        debugShowCheckedModeBanner: false,
        theme: RetroTheme.build(),
        home: const TitleScreen(),
        // Tamaño del texto (accesibilidad, docs/specs/settings.md § 3)
        // y filtro CRT (§ 3.2) sobre toda la app, overlays incluidos.
        builder: (context, child) => Consumer(
          builder: (context, ref, _) => RetroTextScale(
            factor: ref
                .watch(gameSettingsProvider.select((s) => s.textSize.factor)),
            // Fuente de lectura (settings.md § 3.7).
            classic: ref.watch(gameSettingsProvider
                .select((s) => s.readingFont == ReadingFont.classic)),
            // Modo daltónico (accessibility.md § 3).
            child: ColorVisionScope(
              mode:
                  ref.watch(gameSettingsProvider.select((s) => s.colorVision)),
              // FPS y ping (§ 3.9): encima del CRT (no se curva) y sin
              // recibir clics.
              // Tema, colores del texto y espaciado (accessibility.md § 8).
              child: UiThemeScope(
                theme:
                    ref.watch(gameSettingsProvider.select((s) => s.uiTheme)),
                textColors: ref
                    .watch(gameSettingsProvider.select((s) => s.textColors)),
                spacing:
                    ref.watch(gameSettingsProvider.select((s) => s.spacing)),
                child: PerfOverlay(
                  child: CrtFilter(
                    level:
                        ref.watch(gameSettingsProvider.select((s) => s.crt)),
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
