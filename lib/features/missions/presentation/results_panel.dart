import 'package:material_ui/material_ui.dart';

import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../game_engine/models/game_session.dart';

/// Pantalla de resultado de la misión (`#result` del prototipo): rango,
/// tiempo, XP, créditos, bonus y armas obtenidas. Ver
/// docs/specs/exploration.md § "Paneles".
class ResultsPanel extends StatelessWidget {
  const ResultsPanel({
    super.key,
    required this.result,
    required this.localId,
    required this.playerName,
    required this.weaponName,
    required this.onBack,
  });

  final MissionResult result;
  final String localId;
  final String Function(String playerId) playerName;
  final String Function(String weaponId) weaponName;
  final VoidCallback onBack;

  static String rankLabel(MissionRank r) => r.name.toUpperCase();

  @override
  Widget build(BuildContext context) {
    final r = result;
    final el = r.time.floor();
    final time = '${el ~/ 60}:${(el % 60).toString().padLeft(2, '0')}';
    final mine = r.drops[localId];
    Widget line(String s, {Color? color}) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(retroText(s),
              textAlign: TextAlign.center, style: TextStyle(color: color)),
        );
    return PanelFrame(
      width: 640,
      title: r.success ? 'MISIÓN COMPLETADA' : 'MISIÓN FALLIDA',
      actions: [
        PanelButton('VOLVER AL LOBBY',
            key: const ValueKey('results-back'), onPressed: onBack),
      ],
      child: Column(
        children: [
          line(r.missionName, color: RetroPalette.muted),
          Text(rankLabel(r.rank),
              style: TextStyle(
                  fontSize: 32,
                  height: 2,
                  color: r.success ? RetroPalette.gold : RetroPalette.red)),
          line('Tiempo $time · K.O. ${r.kos}'),
          line('XP total +${r.xp} · Créditos de peleas ₵${r.credits}'),
          line('Bonus de rango ${rankLabel(r.rank)}: +₵${r.bonus} '
              '(${(r.bonusPercent * 100).round()}%)'),
          if (r.eliteDrops.isNotEmpty)
            line(
                'Élites derrotados: ${r.elites} · '
                '${r.eliteDrops.map((d) => '${playerName(d.playerId)}: ${weaponName(d.weaponId)}').join(' · ')}',
                color: RetroPalette.gold),
          if (mine != null)
            line('¡Obtuviste: ${weaponName(mine)}!', color: RetroPalette.gold),
          if (r.drops.isNotEmpty)
            line(
                r.drops.entries
                    .map((e) => '${playerName(e.key)}: ${weaponName(e.value)}')
                    .join(' · '),
                color: RetroPalette.muted),
          line('Regreso automático en ${r.timeLeft.ceil()}s',
              color: RetroPalette.muted),
        ],
      ),
    );
  }
}
