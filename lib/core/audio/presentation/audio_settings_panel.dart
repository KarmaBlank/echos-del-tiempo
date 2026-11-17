import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/retro_theme.dart';
import '../../di/service_locator.dart';
import '../audio_settings.dart';
import '../music/music_service.dart';
import '../sfx_service.dart';

/// La música de fondo (la del service locator; en tests, una muda sin
/// timers).
final musicServiceProvider = Provider<MusicService>((ref) =>
    sl.isRegistered<MusicService>() ? sl<MusicService>() : MusicService());

/// Ajustes de audio vivos (docs/specs/music.md § 7). En el juego, el
/// controlador del service locator (ya cargado del disco); en tests, uno
/// en memoria.
final audioSettingsProvider =
    StateNotifierProvider<AudioSettingsController, AudioSettings>((ref) {
  if (sl.isRegistered<AudioSettingsController>()) {
    return sl<AudioSettingsController>();
  }
  return AudioSettingsController(
    store: InMemoryAudioSettingsStore(),
    music: ref.watch(musicServiceProvider),
    sfx: sl.isRegistered<SfxService>() ? sl<SfxService>() : SfxService(),
  );
});

/// Abre el panel de sonido encima de la pantalla actual.
Future<void> showAudioSettings(BuildContext context) => showDialog<void>(
      context: context,
      barrierColor: const Color(0x990B0E1A),
      builder: (_) => const AudioSettingsPanel(),
    );

/// Botón compacto `SONIDO` (título y HUD) que abre el panel.
class AudioSettingsButton extends StatelessWidget {
  const AudioSettingsButton({super.key});

  @override
  Widget build(BuildContext context) => ElevatedButton(
        key: const ValueKey('audio-settings'),
        style: RetroTheme.compactButton(),
        onPressed: () => showAudioSettings(context),
        child: const Text('SONIDO'),
      );
}

/// Panel "SONIDO": volumen de música y de efectos (sliders en %) y
/// silenciar todo. Los cambios se oyen al arrastrar y se guardan al
/// soltar.
class AudioSettingsPanel extends ConsumerWidget {
  const AudioSettingsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(audioSettingsProvider);
    final c = ref.read(audioSettingsProvider.notifier);
    void close() => Navigator.of(context).maybePop();
    return Material(
      type: MaterialType.transparency,
      child: PanelFrame(
        title: 'SONIDO',
        width: 460,
        onClose: close,
        leading: [
          PanelButton(
            s.muted ? 'ACTIVAR SONIDO' : 'SILENCIAR TODO',
            key: const ValueKey('audio-mute'),
            selected: s.muted,
            onPressed: c.toggleMute,
          ),
        ],
        actions: [
          PanelButton('CERRAR', key: const ValueKey('audio-close'), onPressed: close),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _VolumeRow(
              label: 'MUSICA',
              sliderKey: const ValueKey('audio-music'),
              value: s.musicVolume,
              muted: s.muted,
              onChanged: c.setMusic,
              onChangeEnd: (_) => c.commit(),
            ),
            const SizedBox(height: 8),
            _VolumeRow(
              label: 'EFECTOS',
              sliderKey: const ValueKey('audio-sfx'),
              value: s.sfxVolume,
              muted: s.muted,
              onChanged: c.setSfx,
              onChangeEnd: (_) => c.commit(),
            ),
            if (s.muted) ...[
              const SizedBox(height: 8),
              const Text('Todo el sonido está silenciado.',
                  style: TextStyle(color: ProtoColors.dim)),
            ],
          ],
        ),
      ),
    );
  }
}

class _VolumeRow extends StatelessWidget {
  const _VolumeRow({
    required this.label,
    required this.sliderKey,
    required this.value,
    required this.muted,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final String label;
  final Key sliderKey;
  final double value;
  final bool muted;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final color = muted ? ProtoColors.dim : ProtoColors.gold;
    return Row(
      children: [
        SizedBox(width: 88, child: Text(label)),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              inactiveTrackColor: ProtoColors.barBg,
              thumbColor: color,
              overlayShape: SliderComponentShape.noOverlay,
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 6, elevation: 0, pressedElevation: 0),
              trackShape: const RectangularSliderTrackShape(),
            ),
            child: Slider(
              key: sliderKey,
              value: value,
              divisions: 20,
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
          ),
        ),
        SizedBox(
          width: 48,
          child: Text('${(value * 100).round()}%',
              textAlign: TextAlign.right, style: TextStyle(color: color)),
        ),
      ],
    );
  }
}
