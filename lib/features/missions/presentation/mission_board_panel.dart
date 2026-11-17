import 'package:material_ui/material_ui.dart';

import '../../../app/theme/proto_colors.dart';

import '../../../app/feature_flags.dart';
import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../game_engine/models/class_def.dart';
import '../../../game_engine/models/mission_def.dart';

/// Mostrador de misiones (`board` del prototipo): proponer una misión y
/// cambiar de clase. Ver docs/specs/exploration.md § "Paneles".
class MissionBoardPanel extends StatelessWidget {
  const MissionBoardPanel({
    super.key,
    required this.missions,
    required this.classes,
    required this.currentClassId,
    required this.voteOpen,
    required this.onPropose,
    required this.onChangeClass,
    required this.onClose,
    this.onCharacter,
  });

  final List<MissionDef> missions;
  final Map<String, ClassDef> classes;
  final String currentClassId;

  /// Ya hay una votación en curso: no se puede proponer otra.
  final bool voteOpen;
  final ValueChanged<String> onPropose;
  final ValueChanged<String> onChangeClass;
  final VoidCallback onClose;

  /// `Personaje [C]` (botones de abajo del prototipo, línea 1360).
  final VoidCallback? onCharacter;

  @override
  Widget build(BuildContext context) {
    return PanelFrame(
      title: 'MOSTRADOR DE MISIONES',
      actions: [
        if (onCharacter != null)
          PanelButton('PERSONAJE [C]', onPressed: onCharacter),
        PanelButton('CERRAR [ESC]', onPressed: onClose),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final m in missions)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    // `.mrow .rk`: 16 px `#ff9f1c`.
                    child: Text(m.rank,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 16, color: ProtoColors.amber)),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(retroText(m.name)),
                        const SizedBox(height: 4),
                        Text(
                          retroText('${m.type} · Lv recomendado '
                              '${m.recommendedLevel} · Elimina ${m.goal} grupos '
                              'y vence al jefe · S: < ${m.sTime ~/ 60} min sin '
                              'K.O. · Jefe suelta armas'),
                          style: const TextStyle(color: ProtoColors.sky),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  PanelButton('PROPONER',
                      key: ValueKey('propose-${m.id}'),
                      onPressed: voteOpen ? null : () => onPropose(m.id)),
                ],
              ),
            ),
          const SizedBox(height: 8),
          const Text('Clase:'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in classes.values)
                if (FeatureFlags.instance.isCharacterAllowed(c.id))
                  PanelButton(c.name,
                      onPressed: c.id == currentClassId
                          ? null
                          : () => onChangeClass(c.id)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            retroText('Cuando TODOS votan que sí pasan a la preparación '
                '(tienda, herrería, equipo) y la '
                'misión empieza cuando todos marcan ¡Listo!. Cambiar de clase '
                'reinicia tus atributos (mantienes nivel y puntos).'),
            style: const TextStyle(color: RetroPalette.muted),
          ),
        ],
      ),
    );
  }
}
