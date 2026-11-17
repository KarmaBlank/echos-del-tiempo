import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../features/lobby/presentation/title_screen.dart';
import 'theme/retro_theme.dart';

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
      ),
    );
  }
}
