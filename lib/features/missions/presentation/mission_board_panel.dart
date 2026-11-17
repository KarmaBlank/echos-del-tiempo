import 'package:material_ui/material_ui.dart';

import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/panel_widgets.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../game_engine/models/mission_def.dart';
import 'mission_card.dart';

/// Mostrador de misiones (`board` del prototipo): una tarjeta por misión
/// con objetivo y recompensas, y `PROPONER`. Ver docs/specs/panels.md §
/// "Mostrador".
class MissionBoardPanel extends StatelessWidget {
  const MissionBoardPanel({
    super.key,
    required this.missions,
    required this.voteOpen,
    required this.onPropose,
    required this.onClose,
    this.onCharacter,
    this.bossName,
    this.playerLevel,
  });

  final List<MissionDef> missions;

  /// Ya hay una votación en curso: no se puede proponer otra.
  final bool voteOpen;
  final ValueChanged<String> onPropose;
  final VoidCallback onClose;

  /// `Personaje [C]` (botones de abajo del prototipo, línea 1360).
  final VoidCallback? onCharacter;

  /// Nombre del jefe de una misión (para el objetivo).
  final String? Function(MissionDef m)? bossName;

  /// Nivel del jugador local.
  final int? playerLevel;

  static const help = '<b>Mostrador</b><br>'
      'Elige una misión y pulsa PROPONER: se abre una votación para todo el '
      'grupo.<br>'
      'Cuando <b>todos</b> votan SÍ pasan a la preparación (tienda, forja, '
      'equipo) y la misión empieza cuando todos marcan ¡LISTO!.<br>'
      '<span class="k">Rango</span>: S si terminas a tiempo sin K.O.; más '
      'rango = más créditos y más chance de arma.';

  @override
  Widget build(BuildContext context) {
    return PanelFrame(
      title: 'MOSTRADOR DE MISIONES',
      width: 900,
      help: help,
      onClose: onClose,
      actions: [
        if (onCharacter != null)
          PanelButton('PERSONAJE [C]', onPressed: onCharacter),
        PanelButton('CERRAR [ESC]', onPressed: onClose),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PanelHint('Propón una misión: cuando todos votan SÍ pasan a '
              'la preparación.'),
          for (var i = 0; i < missions.length; i++)
            MissionCard(
              key: ValueKey('mission-${missions[i].id}'),
              mission: missions[i],
              tier: i + 1,
              bossName: bossName?.call(missions[i]),
              playerLevel: playerLevel,
              action: PanelButton('PROPONER',
                  key: ValueKey('propose-${missions[i].id}'),
                  accent: ProtoColors.green,
                  reason: voteOpen ? 'Ya hay una votación' : null,
                  onPressed: () => onPropose(missions[i].id)),
            ),
        ],
      ),
    );
  }
}
