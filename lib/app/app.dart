import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../features/world/presentation/world_screen.dart';
import 'theme/retro_panel.dart';
import 'theme/retro_theme.dart';

/// Shell de la app. Todas las pantallas reales (lobby, personaje,
/// batalla con Flame, etc.) se agregan en `features/*/presentation` y
/// se enrutan desde acá — este archivo se mantiene chico a propósito.
///
/// Flujo: título → `WorldScreen` (lobby, misión, batalla y resultado los
/// decide la sesión; docs/specs/exploration.md).
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

/// Pantalla de título (placeholder: el pulido es de la fase 5).
class TitleScreen extends StatelessWidget {
  const TitleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ECOS DEL TIEMPO',
                textAlign: TextAlign.center,
                style: text.displayLarge?.copyWith(color: RetroPalette.gold),
              ),
              const SizedBox(height: 32),
              RetroPanel(
                child: Text(
                  'Co-op JRPG táctico · sesión local',
                  style: text.bodyMedium,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const WorldScreen(),
                  ),
                ),
                child: const Text('> COMENZAR'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
