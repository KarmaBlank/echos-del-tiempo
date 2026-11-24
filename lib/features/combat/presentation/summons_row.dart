import 'package:material_ui/material_ui.dart';

import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../game_engine/data/summoner_catalog.dart';
import '../../../game_engine/models/battle_state.dart';
import 'combat_strings.dart';
import 'scene/summon_sprite.dart';
import '../../../core/i18n/catalog_names.dart';

/// Fila compacta de las invocaciones de un jugador en su tarjeta de la
/// barra del grupo (docs/specs/summoner.md § 8): color del elemento,
/// vida y turnos que le quedan; el detalle, en el tooltip.
class SummonsRow extends StatelessWidget {
  const SummonsRow({super.key, required this.summons});

  final List<Combatant> summons;

  @override
  Widget build(BuildContext context) {
    if (summons.isEmpty) return const SizedBox.shrink();
    return Wrap(
      key: const ValueKey('summons-row'),
      spacing: 4,
      runSpacing: 2,
      children: [for (final s in summons) _chip(combatStrings(context), s)],
    );
  }

  Widget _chip(Strings t, Combatant s) {
    final k = summonKindOf(s);
    final col = k == null ? ProtoColors.dim : summonColor(k);
    final d = k == null ? null : kSummons[k];
    return RetroTooltip(
      message: '${s.name}\n${t.t('ui.combat.summon.stats', {
            'hp': s.hp,
            'max': s.maxHp,
            'power': s.attack
          })}'
          '${d == null ? '' : ' · ${d.element.tr}'}\n'
          '${t.t('ui.combat.summon.turns', {'turns': summonTurnsText(s)})}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, color: col),
          const SizedBox(width: 2),
          Text('${s.hp} · ${summonTurnsText(s)}t',
              style: RetroType.smallStyle.copyWith(color: col)),
        ],
      ),
    );
  }
}
