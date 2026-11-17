import 'package:material_ui/material_ui.dart';

import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../game_engine/models/mission_def.dart';

/// Un jugador en la lista de preparación.
class PrepEntry {
  const PrepEntry(this.name, this.className, this.level, {required this.ready});
  final String name;
  final String className;
  final int level;
  final bool ready;
}

/// Fase de preparación (`prep` del prototipo): marcar ¡Listo!, cancelar
/// o ir al personaje. Tienda/herrería/fusión son de la fase 5.
class PrepPanel extends StatelessWidget {
  const PrepPanel({
    super.key,
    required this.mission,
    required this.players,
    required this.ready,
    required this.credits,
    required this.weaponName,
    required this.onReady,
    required this.onCancel,
    required this.onCharacter,
  });

  final MissionDef mission;
  final List<PrepEntry> players;

  /// El jugador local ya marcó ¡Listo!.
  final bool ready;
  final int credits;
  final String weaponName;
  final ValueChanged<bool> onReady;
  final VoidCallback onCancel;
  final VoidCallback onCharacter;

  @override
  Widget build(BuildContext context) {
    return PanelFrame(
      title: 'PREPARACIÓN · ${mission.name} (rango ${mission.rank})',
      actions: [
        PanelButton(ready ? 'YA NO ESTOY LISTO' : '¡LISTO!',
            key: const ValueKey('prep-ready'),
            accent: ready ? null : RetroPalette.green,
            onPressed: () => onReady(!ready)),
        PanelButton('PERSONAJE [C]', onPressed: onCharacter),
        PanelButton('CANCELAR MISIÓN', onPressed: onCancel),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            retroText('Dentro de la misión vas con lo que lleves: no hay '
                'tienda ni cambio de arma, solo subes de nivel.'),
          ),
          const SizedBox(height: 16),
          for (final p in players)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                retroText('${p.ready ? '> ' : '... '}${p.name} '
                    '(${p.className} Lv${p.level})'),
                style: TextStyle(
                    color: p.ready ? RetroPalette.green : RetroPalette.muted),
              ),
            ),
          const SizedBox(height: 16),
          Text(retroText('Créditos: ₵$credits · Arma: $weaponName'),
              style: const TextStyle(color: RetroPalette.gold)),
          const ComingSoon('Tienda, herrería y fusión'),
        ],
      ),
    );
  }
}
