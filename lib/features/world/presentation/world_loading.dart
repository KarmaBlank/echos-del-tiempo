import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/design/ds_dialogue.dart';
import '../../../app/design/ds_tokens.dart';
import '../../../app/theme/retro_type.dart';
import '../../../core/settings/crt_filter.dart';
import '../../../game_engine/rules/town_plan.dart';
import '../../combat/presentation/game_sprites.dart';
import '../../lobby/presentation/worlds_providers.dart';
import 'map/map_game.dart';
import 'session_controller.dart';
import 'world_screen.dart';

/// Pantalla "Cargando el mundo…" (exploration.md § "Rendimiento",
/// v0.35.1): al JUGAR, CREAR SALA o unirse. Antes de dejar caminar
/// precocina lo que el primer cuadro necesita (sprites decodificados,
/// catálogos, fuentes, shaders, plano del pueblo) y después arma el
/// mundo tapado unos cuadros para que el mapa grabe sus bloques de
/// tiles, mida las etiquetas y calcule la luz. Recién ahí lo muestra.
class WorldLoadingScreen extends ConsumerStatefulWidget {
  const WorldLoadingScreen({super.key, this.warmFrames = 20});

  /// Cuadros del mundo tapado antes de mostrarlo.
  final int warmFrames;

  @override
  ConsumerState<WorldLoadingScreen> createState() =>
      _WorldLoadingScreenState();
}

class _WorldLoadingScreenState extends ConsumerState<WorldLoadingScreen> {
  /// Pasos de la carga previa (antes de armar el mundo).
  late final List<(String, Future<void> Function())> _steps = [
    ('Imágenes', () => ref.read(gameSpritesProvider.future)),
    ('Catálogos', () async => ref.read(sessionEngineProvider)),
    ('Letras', _fonts),
    ('Filtros', () => CrtShaders.load()),
    ('Pueblo', () async {
      final town = ref.read(worldBookProvider)?.selected?.town;
      if (town != null) TownPlan.reserved(town);
    }),
  ];

  int _done = 0;
  bool _world = false;
  int _warm = 0;
  bool get _ready => _world && _warm >= widget.warmFrames;

  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  Future<void> _run() async {
    for (final (_, step) in _steps) {
      try {
        await step();
      } catch (_) {
        // Lo que falle se carga después, como antes.
      }
      if (!mounted) return;
      setState(() => _done++);
    }
    setState(() => _world = true);
    _tick();
  }

  /// Cuenta cuadros del mundo tapado.
  void _tick() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _warm++);
      if (!_ready) _tick();
    });
  }

  /// Las fuentes del juego, medidas una vez (el primer texto no espera).
  Future<void> _fonts() async {
    for (final f in [
      RetroType.pixelFamily,
      RetroType.vt323Family,
      RetroType.atkinsonFamily,
    ]) {
      TextPainter(
        text: TextSpan(text: 'Ecos 0123', style: TextStyle(fontFamily: f)),
        textDirection: TextDirection.ltr,
      )
        ..layout()
        ..dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _steps.length + widget.warmFrames;
    final value = _done + _warm.clamp(0, widget.warmFrames);
    final label = _done < _steps.length
        ? _steps[_done].$1
        : 'Mapa';
    final cover = ColoredBox(
      key: const ValueKey('world-loading'),
      color: DsColors.background,
      child: Center(
        child: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Cargando el mundo…', style: DsText.subtitle()),
              SizedBox(height: DsSpace.md),
              DsMeter(value, total, color: DsColors.actionPrimary),
              SizedBox(height: DsSpace.sm),
              Text(label, style: DsText.detail()),
            ],
          ),
        ),
      ),
    );
    if (!_world) return cover;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Quieto mientras se precocina: la entrada llega al estar listo.
        WorldScreen(
            moveInput: () => _ready ? MapGame.keyboardInput() : (0.0, 0.0)),
        if (!_ready) AbsorbPointer(child: cover),
      ],
    );
  }
}
