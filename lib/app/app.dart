import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../features/combat/presentation/battle_screen.dart';
import '../features/combat/presentation/demo_battle.dart';
import 'theme/retro_panel.dart';
import 'theme/retro_theme.dart';

/// Shell de la app. Todas las pantallas reales (lobby, personaje,
/// batalla con Flame, etc.) se agregan en `features/*/presentation` y
/// se enrutan desde acá — este archivo se mantiene chico a propósito.
class EcosApp extends StatelessWidget {
  const EcosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: 'Ecos del Tiempo',
        debugShowCheckedModeBanner: false,
        theme: RetroTheme.build(),
        home: const _ScaffoldPlaceholder(),
      ),
    );
  }
}

/// Placeholder temporal — se reemplaza por el lobby real
/// (`features/lobby/presentation`) a medida que se migra esa feature.
class _ScaffoldPlaceholder extends StatelessWidget {
  const _ScaffoldPlaceholder();

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
                  'Batalla de prueba: 4 clases vs. Pradera Esmeralda',
                  style: text.bodyMedium,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BattleScreen(setup: demoBattleSetup()),
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
