import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../session_controller.dart';
import '../world_strings.dart';
import 'life_icon.dart';

/// The mine NPC (miner / hermit) dialogue box: name, the line of the day
/// and a close option (cozy_life.md § 3).
class MineNpcPanel extends StatelessWidget {
  const MineNpcPanel({super.key, required this.controller});

  final SessionController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final id = c.talkMineNpcId;
    if (id == null) return const SizedBox.shrink();
    return Align(
      key: const ValueKey('panel-mine-npc'),
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.all(DsSpace.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: DsDialogueBox(
            portrait: LifeIcon('npc_mina_$id', LifeIconKind.herramienta,
                size: DsDialogueBox.portraitSize),
            name: context.t('ui.world.mine.npc.$id.name'),
            text: context.t(c.mineNpcLineKey(id)),
            skipLabel: context.t('ui.town.npc.skip'),
            onCancel: c.closePanel,
            choices: [
              DsChoice(context.t('ui.endgame.hint.close'),
                  key: const ValueKey('mine-npc-close'),
                  onSelected: c.closePanel),
            ],
          ),
        ),
      ),
    );
  }
}