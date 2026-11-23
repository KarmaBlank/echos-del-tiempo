import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../core/procedural/item_icons.dart';
import '../../../../core/settings/settings_providers.dart';
import '../world_strings.dart';

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
  // Sin timer propio: el giro sale del reloj y avanza con los rebuilds que
  // ya hace el HUD en cada paso del juego. Un timer que pide cuadros no
  // deja asentarse a los tests (pumpAndSettle) ni suma trabajo extra.
  int get _frame =>
      (DateTime.now().millisecondsSinceEpoch ~/
          SaveIndicator.step.inMilliseconds) %
      8;

  @override
  Widget build(BuildContext context) {
    final still =
        ref.watch(gameSettingsProvider.select((s) => s.reduceMotion));
    final frame = still ? 0 : _frame;
    return IgnorePointer(
      child: Row(
        key: const ValueKey('hud-saving'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.rotate(
            angle: frame * math.pi / 4,
            child: DsSpriteIcon(ItemIconImages.base(SaveIndicator.spriteKey),
                size: 16),
          ),
          SizedBox(width: DsSpace.sm),
          Flexible(child: Text(context.t('ui.world.notice.saving'), style: DsText.detail())),
        ],
      ),
    );
  }
}
