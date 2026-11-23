import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../core/procedural/item_icons.dart';
import '../../../../core/settings/settings_providers.dart';
import '../../../combat/presentation/game_sprites.dart';

/// Aviso de guardado del HUD (docs/specs/save_indicator.md § 2): el ícono
/// `items.eco` del manifest girando en bucle (de a octavos de vuelta, al
/// estilo pixel art) + el texto, mientras algo se escribe a disco. Con
/// REDUCIR MOVIMIENTO el ícono queda quieto.
class SaveIndicator extends ConsumerStatefulWidget {
  const SaveIndicator({super.key});

  static const text = 'Guardando… no cierres el juego';

  /// Sprite del ícono (id lógico del manifest, sección `items`).
  static const spriteKey = 'eco';

  /// Cada cuánto avanza un octavo de vuelta.
  static const step = Duration(milliseconds: 125);

  @override
  ConsumerState<SaveIndicator> createState() => _SaveIndicatorState();
}

class _SaveIndicatorState extends ConsumerState<SaveIndicator> {
  Timer? _timer;
  int _frame = 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Los íconos de ítems se cargan junto con los sprites del juego.
    ref.watch(gameSpritesProvider);
    final still =
        ref.watch(gameSettingsProvider.select((s) => s.reduceMotion));
    if (still) {
      _timer?.cancel();
      _timer = null;
    } else {
      _timer ??= Timer.periodic(SaveIndicator.step, (_) {
        if (mounted) setState(() => _frame = (_frame + 1) % 8);
      });
    }
    return IgnorePointer(
      child: Row(
        key: const ValueKey('hud-saving'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.rotate(
            angle: _frame * math.pi / 4,
            child: DsSpriteIcon(ItemIconImages.base(SaveIndicator.spriteKey),
                size: 16),
          ),
          SizedBox(width: DsSpace.sm),
          Flexible(child: Text(SaveIndicator.text, style: DsText.detail())),
        ],
      ),
    );
  }
}
