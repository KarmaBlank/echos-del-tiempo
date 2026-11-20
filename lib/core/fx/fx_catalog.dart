import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:yaml/yaml.dart';

import '../../game_engine/fx/cinematic_durations.dart';
import '../../game_engine/fx/fx_timeline.dart';

import 'fx_overrides.dart';

export '../../game_engine/fx/fx_timeline.dart';
export 'fx_overrides.dart';

/// Animaciones que todavía son código (§ 2.3): las arma el
/// `LegacyFxAdapter` de la presentación.
abstract class LegacyFxSource {
  Iterable<String> get ids;
  FxTimeline? build(String id);
}

/// De dónde sale la animación que se reproduce.
enum FxSource { override, data, legacy }

/// Lee `assets/fx/fx_manifest.yaml` + los `.fx.yaml` (§ 2.2). Es la
/// ÚNICA clase que sabe que las animaciones viven como archivos; el
/// resto pide por id (`ult_espada`, `duo`).
///
/// Resolución: edición en vivo del Editor → override local → asset →
/// adaptador legacy. Nunca lanza: un archivo roto queda en [log] y se usa
/// la capa siguiente.
class FxCatalog {
  FxCatalog._(this._bundle, this.overrides, this.legacy);

  static const manifestPath = 'assets/fx/fx_manifest.yaml';
  static const fxRoot = 'assets/fx/';

  /// El catálogo del juego en curso (lo pone el composition root; `null`
  /// en tests del motor y de la escena: todo usa el código).
  static FxCatalog? active;

  /// Overrides que usa [load] si no se le pasan otros (`main_dev`).
  static FxOverrideSource? defaultOverrides;

  final AssetBundle _bundle;
  final FxOverrideSource? overrides;
  final LegacyFxSource? legacy;

  /// id → ruta relativa a `assets/fx/` (orden del manifest).
  final paths = <String, String>{};
  final _assets = <String, FxTimeline>{};
  final _overrides = <String, FxTimeline>{};
  final _live = <String, FxTimeline>{};

  /// Avisos de carga (archivos rotos, pistas desconocidas).
  final log = <String>[];

  /// Sube con cada cambio (recarga, edición en vivo): la escena y el
  /// Editor lo usan para invalidar lo derivado.
  final revision = ValueNotifier<int>(0);

  static Future<FxCatalog> load(
      {AssetBundle? bundle,
      FxOverrideSource? overrides,
      LegacyFxSource? legacy}) async {
    final c = FxCatalog._(
        bundle ?? rootBundle, overrides ?? defaultOverrides, legacy);
    await c._loadAssets();
    await c._loadOverrides();
    return c;
  }

  /// Catálogo armado a mano (tests): [files] = ruta relativa → texto.
  static FxCatalog fromFiles(String manifest, Map<String, String> files,
      {FxOverrideSource? overrides, LegacyFxSource? legacy}) {
    final c = FxCatalog._(rootBundle, overrides, legacy);
    c._readManifest(manifest);
    for (final MapEntry(key: id, value: rel) in c.paths.entries) {
      final raw = files[rel];
      if (raw == null) {
        c.log.add('$id: falta $rel');
        continue;
      }
      c._parseAsset(id, raw);
    }
    return c;
  }

  void _readManifest(String raw) {
    paths.clear();
    try {
      final doc = loadYaml(raw);
      final fx = doc is YamlMap ? doc['fx'] : null;
      if (fx is YamlMap) {
        for (final MapEntry(:key, :value) in fx.entries) {
          if (value is String) paths['$key'] = value;
        }
      }
    } catch (e) {
      log.add('fx_manifest.yaml roto: $e');
    }
  }

  void _parseAsset(String id, String raw) {
    try {
      final t = FxTimeline.parse(raw, fallbackId: id);
      for (final w in t.warnings) {
        log.add('$id: $w');
      }
      _assets[id] = t;
    } on FormatException catch (e) {
      log.add('$id: ${e.message} (se usa la animación del código)');
    }
  }

  Future<void> _loadAssets() async {
    _assets.clear();
    try {
      _readManifest(await _bundle.loadString(manifestPath));
    } catch (e) {
      log.add('sin $manifestPath: $e');
      return;
    }
    for (final MapEntry(key: id, value: rel) in paths.entries) {
      try {
        _parseAsset(id, await _bundle.loadString('$fxRoot$rel'));
      } catch (e) {
        log.add('$id: no se pudo leer $rel');
      }
    }
  }

  Future<void> _loadOverrides() async {
    _overrides.clear();
    final o = overrides;
    if (o == null) return;
    await o.refreshFx();
    for (final id in o.overriddenFx) {
      final raw = await o.readFx(id);
      if (raw == null) continue;
      try {
        _overrides[id] = FxTimeline.parse(raw, fallbackId: id);
      } on FormatException catch (e) {
        log.add('override $id: ${e.message}');
      }
    }
  }

  /// Recarga en caliente: relee los overrides (y descarta la edición en
  /// vivo de [id], o de todas).
  Future<void> reload([String? id]) async {
    if (id == null) {
      _live.clear();
    } else {
      _live.remove(id);
    }
    await _loadOverrides();
    revision.value++;
  }

  /// Edición en vivo (Editor): [t] se reproduce en lugar de [id] hasta
  /// guardar o descartar.
  void setLive(String id, FxTimeline t) {
    _live[id] = t;
    revision.value++;
  }

  void clearLive(String id) {
    if (_live.remove(id) != null) revision.value++;
  }

  bool hasLive(String id) => _live.containsKey(id);

  /// Todos los ids conocidos (datos, overrides y legacy), ordenados.
  List<String> get ids => {
        ...paths.keys,
        ..._overrides.keys,
        ...?legacy?.ids,
      }.toList()
        ..sort();

  bool hasOverride(String id) => _overrides.containsKey(id);

  FxSource? sourceOf(String id) => _overrides.containsKey(id)
      ? FxSource.override
      : _assets.containsKey(id)
          ? FxSource.data
          : legacy?.build(id) != null
              ? FxSource.legacy
              : null;

  /// La animación del release (asset → legacy), sin overrides.
  FxTimeline? assetTimeline(String id) => _assets[id] ?? legacy?.build(id);

  /// La que se reproduce: en vivo → override → asset → legacy.
  FxTimeline? timeline(String id) =>
      _live[id] ?? _overrides[id] ?? assetTimeline(id);

  /// Consulta por acción (§ 2.2): `duo` busca `duo_<clave>` y cae en
  /// `duo`; el resto, por id.
  FxTimeline? forAction(String kind, String? id) => switch (kind) {
        'duo' => (id == null ? null : timeline('duo_$id')) ?? timeline('duo'),
        _ => id == null ? null : timeline(id),
      };

  /// Duración (ms) que se reproduce para [id], o `null`.
  int? durationOf(String id) => timeline(id)?.duration;

  /// Duraciones del release (asset → legacy, nunca overrides; § 4.3).
  CinematicDurations releaseDurations() => CinematicDurations({
        for (final id in {...paths.keys, ...?legacy?.ids})
          if (assetTimeline(id) case final t?) id: t.duration,
      });
}
