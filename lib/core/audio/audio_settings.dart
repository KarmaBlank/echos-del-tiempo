import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'music/music_service.dart';
import 'sfx_service.dart';

/// Volúmenes y silencio (docs/specs/music.md § 7).
class AudioSettings {
  const AudioSettings({
    this.musicVolume = defaultMusic,
    this.sfxVolume = defaultSfx,
    this.muted = false,
  });

  static const defaultMusic = 0.6;
  static const defaultSfx = 0.8;

  /// 0..1.
  final double musicVolume;
  final double sfxVolume;

  /// Silencia música y efectos.
  final bool muted;

  AudioSettings copyWith({double? musicVolume, double? sfxVolume, bool? muted}) =>
      AudioSettings(
        musicVolume: (musicVolume ?? this.musicVolume).clamp(0.0, 1.0),
        sfxVolume: (sfxVolume ?? this.sfxVolume).clamp(0.0, 1.0),
        muted: muted ?? this.muted,
      );

  Map<String, Object?> toJson() =>
      {'music': musicVolume, 'sfx': sfxVolume, 'muted': muted};

  /// Valores inválidos o ausentes caen al de por defecto.
  factory AudioSettings.fromJson(Map<String, Object?> json) {
    double vol(Object? v, double d) =>
        v is num && v.isFinite ? v.toDouble().clamp(0.0, 1.0) : d;
    return AudioSettings(
      musicVolume: vol(json['music'], defaultMusic),
      sfxVolume: vol(json['sfx'], defaultSfx),
      muted: json['muted'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AudioSettings &&
      other.musicVolume == musicVolume &&
      other.sfxVolume == sfxVolume &&
      other.muted == muted;

  @override
  int get hashCode => Object.hash(musicVolume, sfxVolume, muted);

  @override
  String toString() =>
      'AudioSettings(music: $musicVolume, sfx: $sfxVolume, muted: $muted)';
}

/// Dónde se guardan los ajustes.
abstract interface class AudioSettingsStore {
  Future<AudioSettings?> load();
  Future<void> save(AudioSettings settings);
}

/// En memoria (tests, plataformas sin carpeta de datos conocida).
class InMemoryAudioSettingsStore implements AudioSettingsStore {
  InMemoryAudioSettingsStore([this.saved]);

  AudioSettings? saved;

  @override
  Future<AudioSettings?> load() async => saved;

  @override
  Future<void> save(AudioSettings settings) async => saved = settings;
}

/// `audio.json` junto al perfil (escritura atómica).
class JsonFileAudioSettingsStore implements AudioSettingsStore {
  JsonFileAudioSettingsStore(this.file);

  /// El archivo dentro de la carpeta de datos [dir].
  JsonFileAudioSettingsStore.inDirectory(String dir)
      : file = File('$dir${Platform.pathSeparator}$fileName');

  static const fileName = 'audio.json';

  final File file;

  @override
  Future<AudioSettings?> load() async {
    try {
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString());
      return json is Map<String, Object?> ? AudioSettings.fromJson(json) : null;
    } catch (_) {
      return null; // corrupto: por defecto
    }
  }

  @override
  Future<void> save(AudioSettings settings) async {
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(settings.toJson()), flush: true);
    await tmp.rename(file.path);
  }
}

/// Los ajustes vivos: los aplica a la música y a los efectos en cada
/// cambio y los guarda cuando se confirman ([commit]).
class AudioSettingsController extends StateNotifier<AudioSettings> {
  AudioSettingsController({
    required this.store,
    required this.music,
    required this.sfx,
    AudioSettings initial = const AudioSettings(),
  }) : super(initial) {
    _apply(initial);
  }

  final AudioSettingsStore store;
  final MusicService music;
  final SfxService sfx;

  /// Carga lo guardado (si hay) y lo aplica.
  Future<void> load() async {
    AudioSettings? s;
    try {
      s = await store.load();
    } catch (_) {
      s = null;
    }
    if (s != null && mounted) set(s);
  }

  /// Cambia y aplica (sin guardar: los sliders llaman esto al arrastrar).
  void set(AudioSettings s) {
    state = s;
    _apply(s);
  }

  void setMusic(double v) => set(state.copyWith(musicVolume: v));
  void setSfx(double v) => set(state.copyWith(sfxVolume: v));

  /// Silencio sí/no (se guarda enseguida).
  Future<void> toggleMute() {
    set(state.copyWith(muted: !state.muted));
    return commit();
  }

  /// Guarda el estado actual.
  Future<void> commit() async {
    try {
      await store.save(state);
    } catch (_) {
      // Sin disco: se usa igual en esta ejecución.
    }
  }

  void _apply(AudioSettings s) {
    music
      ..volume = s.musicVolume
      ..muted = s.muted;
    sfx
      ..volume = s.sfxVolume
      ..muted = s.muted;
  }
}
