import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../game_engine/models/battle_command.dart';
import '../../../../game_engine/models/game_session.dart';
import '../session_controller.dart';
import '../world_strings.dart';

/// Atajos de pociones del HUD del mundo (exploration.md § HUD): dos
/// botones compactos con el contador, teclas 1 (vida) y 2 (maná). Fuera
/// de batalla; desactivados con motivo ("Vida llena", "No te quedan").
class PotionShortcuts extends StatelessWidget {
  const PotionShortcuts({
    super.key,
    required this.controller,
    required this.player,
  });

  final SessionController controller;
  final SessionPlayer player;

  @override
  Widget build(BuildContext context) {
    Widget button(BattleItem item, String key, String name, int count) {
      final why = controller.useItemBlock(item);
      return DsButton(
        '[$key] $name ×$count',
        key: ValueKey('hud-use-${item.name}'),
        size: DsButtonSize.compact,
        tooltip: why ?? context.t('ui.world.hud.use_item', {'item': name}),
        onPressed: why == null ? () => controller.useItem(item) : null,
      );
    }

    final prof = player.profile;
    return Row(
      key: const ValueKey('hud-potions'),
      mainAxisSize: MainAxisSize.min,
      children: [
        button(BattleItem.potion, '1', 'Vida', prof.potions),
        const SizedBox(width: 6),
        button(BattleItem.ether, '2', 'Maná', prof.ethers),
      ],
    );
  }
}
