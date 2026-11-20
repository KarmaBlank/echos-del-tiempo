import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../app/theme/retro_text.dart';
import '../../../game_engine/models/mission_def.dart';
import '../../../game_engine/rules/zone_rules.dart';
import '../domain/mission_text.dart';

/// Detalle de una misión (mostrador y preparación) con el sistema de
/// diseño (design_system.md § 10.3): rango y nombre, `tipo · Lv`, zona y
/// motivo de bloqueo en una línea cada uno; OBJETIVO y RECOMPENSAS con
/// `DsSectionHeader`; la condición de rango S en un `DsFold`. La acción
/// ([action]) va abajo a la derecha. Ver docs/specs/panels.md §
/// "Mostrador".
class MissionCard extends StatelessWidget {
  const MissionCard({
    super.key,
    required this.mission,
    required this.tier,
    this.bossName,
    this.playerLevel,
    this.action,
    this.zone,
  });

  /// Zona de la misión con su estado para el jugador local (mostrador de
  /// zonas): agrega la línea de zona y, si está bloqueada, el motivo.
  final ZoneStatus? zone;

  final MissionDef mission;

  /// Nº de misión: tier de las armas que suelta.
  final int tier;
  final String? bossName;

  /// Nivel del jugador local (en rojo si está por debajo del recomendado).
  final int? playerLevel;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final m = mission;
    final low = playerLevel != null && playerLevel! < m.recommendedLevel;
    final lv = 'Lv recomendado ${m.recommendedLevel}'
        '${low ? ' · tu Lv $playerLevel' : ''}';
    final z = zone;
    final locked = z != null && !z.open;
    return Padding(
      padding: EdgeInsets.only(bottom: DsSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Rango (naranja) y nombre (Título): la jerarquía es por color.
          Text.rich(
            TextSpan(children: [
              TextSpan(
                  text: '${m.rank}  ',
                  style: DsText.title(DsColors.warning)),
              TextSpan(
                  text: retroText(m.name),
                  style: DsText.title(
                      locked ? DsColors.textDisabled : DsColors.textTitle)),
            ]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          ProtoText(
              '${protoColor(DsColors.textSecondary, protoEsc(m.type))} · '
              '${protoColor(low ? DsColors.danger : DsColors.success, lv)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          if (z != null)
            ProtoText(
                key: ValueKey('mission-zone-${m.id}'),
                protoColor(
                    locked ? DsColors.textDisabled : DsColors.textSecondary,
                    protoEsc(zoneLineText(z.zone)))),
          if (z != null && z.label.isNotEmpty)
            ProtoText(
                key: ValueKey('mission-lock-${m.id}'),
                protoColor(ProtoColors.red, protoEsc(z.label))),
          SizedBox(height: DsSpace.sm),
          const DsSectionHeader('OBJETIVO'),
          Text(retroText(missionObjectiveText(m, bossName: bossName)),
              style: DsText.body(DsColors.textPrimary)),
          SizedBox(height: DsSpace.sm),
          const DsSectionHeader('RECOMPENSAS'),
          Text(retroText(missionRewardText(m, tier)),
              key: ValueKey('mission-rewards-${m.id}'),
              style: DsText.body(DsColors.textPrimary)),
          SizedBox(height: DsSpace.xs),
          DsFold(
            key: ValueKey('mission-srank-${m.id}'),
            label: 'RANGO S',
            openLabel: 'RANGO S',
            child: Text(retroText(missionSRankText(m))),
          ),
          if (action != null)
            Align(alignment: Alignment.centerRight, child: action),
        ],
      ),
    );
  }
}
