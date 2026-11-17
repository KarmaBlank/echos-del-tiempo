import 'package:material_ui/material_ui.dart';

import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/panel_widgets.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../game_engine/models/mission_def.dart';
import '../../../game_engine/rules/zone_rules.dart';
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
    this.zones,
  });

  /// Las 10 zonas con su estado para el jugador local
  /// (`ZoneRules.zoneList`). Con zonas, el mostrador lista las zonas en
  /// orden: tarjeta por cada zona con misión (bloqueadas con motivo) y una
  /// fila gris por las "Próximamente". Sin zonas, una tarjeta por misión.
  final List<ZoneStatus>? zones;

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

  Widget _card(MissionDef m, ZoneStatus? z) {
    final locked = z != null && !z.open;
    return MissionCard(
      key: ValueKey('mission-${m.id}'),
      mission: m,
      tier: missions.indexOf(m) + 1,
      bossName: bossName?.call(m),
      playerLevel: playerLevel,
      zone: z,
      action: PanelButton('PROPONER',
          key: ValueKey('propose-${m.id}'),
          accent: ProtoColors.green,
          reason: locked
              ? 'Bloqueada'
              : voteOpen
                  ? 'Ya hay una votación'
                  : null,
          onPressed: () => onPropose(m.id)),
    );
  }

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
          PanelHint(zones == null
              ? 'Propón una misión: cuando todos votan SÍ pasan a la '
                  'preparación.'
              : 'Propón una zona: cuando todos votan SÍ pasan a la '
                  'preparación. También podés entrar por las puertas del '
                  'mapa del mundo.'),
          if (zones case final zs?)
            for (final z in zs)
              if (z.mission case final m?)
                _card(m, z)
              else
                Padding(
                  key: ValueKey('zone-soon-${z.zone.index}'),
                  padding: const EdgeInsets.only(bottom: 4),
                  child: ProtoText(protoColor(
                      ProtoColors.dim,
                      protoEsc('Zona ${z.zone.index} · ${z.zone.name} · '
                          '${z.zone.levelText} · ${z.label}'))),
                )
          else
            for (final m in missions) _card(m, null),
        ],
      ),
    );
  }
}
