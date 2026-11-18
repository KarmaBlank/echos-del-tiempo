import 'package:material_ui/material_ui.dart';

import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../game_engine/models/mission_def.dart';
import '../../../game_engine/rules/zone_rules.dart';
import '../domain/mission_text.dart';

/// Tarjeta de misión (mostrador y preparación): rango, nombre, tipo,
/// nivel recomendado, objetivo, condición de rango S y recompensas, con
/// la acción ([action]) abajo a la derecha. Ver docs/specs/panels.md §
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
    String row(String label, String text) =>
        '<span class="k">$label</span> ${protoEsc(text)}';
    final z = zone;
    final locked = z != null && !z.open;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: locked ? const Color(0x22000000) : null,
        border: Border.all(
            color: locked ? ProtoColors.barBg : ProtoColors.panelBorder,
            width: RetroTheme.thinBorderWidth),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            // `.mrow .rk`: 16 px `#ff9f1c`.
            child: Text(m.rank,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: RetroType.pixelFamily, fontSize: 16,
                    color: ProtoColors.amber,
                    shadows: [
                      Shadow(
                          color: ProtoColors.titleShadow, offset: Offset(2, 2))
                    ])),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (z != null)
                  ProtoText(
                      key: ValueKey('mission-zone-${m.id}'),
                      protoColor(locked ? ProtoColors.dim : ProtoColors.gold,
                          protoEsc(zoneLineText(z.zone)))),
                if (z != null && z.label.isNotEmpty)
                  ProtoText(
                      key: ValueKey('mission-lock-${m.id}'),
                      protoColor(ProtoColors.red, protoEsc(z.label))),
                ProtoText('<b style="color:#e8ecff">${protoEsc(m.name)}</b> · '
                    '<span class="k">${protoEsc(m.type)}</span> · '
                    '${low ? protoColor(ProtoColors.red, lv) : protoColor(ProtoColors.green, lv)}'),
                ProtoText(row('Objetivo:',
                    missionObjectiveText(m, bossName: bossName))),
                ProtoText(row('Rango S:', missionSRankText(m))),
                ProtoText(row('Recompensas:', missionRewardText(m, tier)),
                    key: ValueKey('mission-rewards-${m.id}')),
                if (action != null)
                  Align(alignment: Alignment.centerRight, child: action),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
