import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../game_engine/models/battle_command.dart';
import '../../../../game_engine/models/game_session.dart';
import '../session_controller.dart';
import '../world_strings.dart';

/// Atajos de pociones del HUD del mundo (exploration.md § HUD): dos
/// botones compactos con el contador, teclas 1 (vida) y 2 (maná). Fuera
/// de batalla; desactivados con motivo ("Vida llena", "No te quedan").
/// Al lado, la Llama errante (tecla L) con el mismo botón.
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

    // Llama errante (lighting.md § 3.1.1): mismo atajo, tecla L;
    // seleccionado mientras alumbra, gris con motivo si no aplica.
    Widget flame() {
      final whyKey = controller.wispBlock();
      final why = whyKey == null ? null : context.t(whyKey);
      final on = controller.wispOn;
      return DsButton(
        context.t('ui.world.hud.flame.slot',
            {'name': context.t('ui.world.hud.flame.name')}),
        key: const ValueKey('hud-flame'),
        size: DsButtonSize.compact,
        selected: on,
        tooltip: why ??
            context.t(on ? 'ui.world.hud.flame.off' : 'ui.world.hud.flame.on'),
        onPressed: why == null ? controller.toggleWisp : null,
      );
    }

    final prof = player.profile;
    // Wrap: si no entran en el ancho del HUD, la Llama sube a otra fila.
    return Wrap(
      key: const ValueKey('hud-potions'),
      alignment: WrapAlignment.end,
      verticalDirection: VerticalDirection.up,
      spacing: 6,
      runSpacing: 6,
      children: [
        button(BattleItem.potion, '1', context.t('ui.world.hud.potion.hp'), prof.potions),
        button(BattleItem.ether, '2', context.t('ui.world.hud.potion.mp'), prof.ethers),
        flame(),
      ],
    );
  }
}
