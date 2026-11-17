import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shell de la app. Todas las pantallas reales (lobby, personaje,
/// batalla con Flame, etc.) se agregan en `features/*/presentation` y
/// se enrutan desde acá — este archivo se mantiene chico a propósito.
class EcosApp extends StatelessWidget {
  const EcosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProviderScope(
      child: MaterialApp(
        title: 'Ecos del Tiempo',
        debugShowCheckedModeBanner: false,
        home: _ScaffoldPlaceholder(),
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
    return const Scaffold(
      body: Center(
        child: Text('Ecos del Tiempo — scaffold en migración'),
      ),
    );
  }
}
