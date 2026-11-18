import 'package:flutter_riverpod/flutter_riverpod.dart';

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
/// en memoria. La UI es la pestaña SONIDO del menú de pausa /
/// configuración (docs/specs/settings.md).
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
