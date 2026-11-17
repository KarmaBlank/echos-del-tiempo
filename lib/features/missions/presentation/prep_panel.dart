import 'package:material_ui/material_ui.dart';

import '../../../app/theme/proto_markup.dart';

import '../../../app/theme/proto_colors.dart';

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

/// Fase de preparación (`prep` del prototipo, líneas 1341-1349): marcar
/// ¡Listo!, cancelar, ir al personaje y la tienda (consumibles, herrería,
/// fusión y armería, que llegan armadas en [shop]). Ver
/// docs/specs/panels.md § "Preparación".
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
    this.shop,
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

  /// Secciones de tienda (consumibles, herrería, fusión, armería).
  final Widget? shop;

  @override
  Widget build(BuildContext context) {
    return PanelFrame(
      title: 'PREPARACIÓN · ${mission.name} (rango ${mission.rank})',
      width: 1000,
      header: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          PanelButton(ready ? 'YA NO ESTOY LISTO' : '¡LISTO!',
              key: const ValueKey('prep-ready'),
              accent: ready ? null : RetroPalette.green,
              selected: !ready,
              onPressed: () => onReady(!ready)),
          PanelButton('PERSONAJE / EQUIPAR [C]',
              key: const ValueKey('prep-character'), onPressed: onCharacter),
          PanelButton('CANCELAR MISIÓN',
              key: const ValueKey('prep-cancel'), onPressed: onCancel),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(TextSpan(children: [
            const TextSpan(text: 'Dentro de la misión vas con lo que lleves: '),
            const TextSpan(
                text: 'no hay tienda ni cambio de arma',
                style: TextStyle(
                    color: ProtoColors.orange, fontWeight: FontWeight.bold)),
            TextSpan(text: retroText(', solo subes de nivel.')),
          ])),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              for (final p in players)
                Text(
                  retroText('${p.ready ? '> ' : '... '}${p.name} '
                      '(${p.className} Lv${p.level})'),
                  style: TextStyle(
                      color: p.ready ? RetroPalette.green : RetroPalette.muted),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ProtoText('Créditos: <b>₵$credits</b> · Arma: '
              '<b style="color:#ff9f43">${protoEsc(weaponName)}</b>'),
          if (shop != null) shop!,
        ],
      ),
    );
  }
}
