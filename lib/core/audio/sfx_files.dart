import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:yaml/yaml.dart';

import 'sfx_overrides.dart';

export 'sfx_overrides.dart';

/// Extensión de un archivo de sonido según su cabecera (`ogg` o `wav`).
String sfxExtOf(Uint8List b) =>
    b.length >= 4 && b[0] == 0x4f && b[1] == 0x67 && b[2] == 0x67 && b[3] == 0x53
        ? 'ogg'
        : 'wav';

/// `true` si [b] parece un WAV (RIFF/WAVE) o un OGG.
bool isSfxFile(Uint8List b) =>
    sfxExtOf(b) == 'ogg' ||
    (b.length >= 12 &&
        ascii.decode(b.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
        ascii.decode(b.sublist(8, 12), allowInvalid: true) == 'WAVE');

/// Archivos de sonido que reemplazan (o agregan) efectos del catálogo
/// sintetizado: `assets/sfx/sfx_manifest.yaml` (`sfx: { <id>: <archivo> }`)
/// + los overrides locales. Es la ÚNICA clase que sabe que los sonidos
/// pueden vivir como archivos. Nunca lanza: lo roto queda en [log].
class SfxFiles {
  SfxFiles._(this._bundle, this.overrides);

  static const manifestPath = 'assets/sfx/sfx_manifest.yaml';
  static const root = 'assets/sfx/';

  /// Los archivos del juego en curso (los pone el composition root;
  /// `null` en tests: todo sale del sintetizador).
  static SfxFiles? active;

  final AssetBundle _bundle;
  final SfxOverrideSource? overrides;

  /// id → ruta relativa a `assets/sfx/`.
  final paths = <String, String>{};
  final _assets = <String, Uint8List>{};
  final _overrides = <String, Uint8List>{};
  final log = <String>[];

  /// Sube con cada recarga (el Editor la usa para repintar).
  final revision = ValueNotifier<int>(0);

  static Future<SfxFiles> load(
      {AssetBundle? bundle, SfxOverrideSource? overrides}) async {
    final f = SfxFiles._(bundle ?? rootBundle, overrides);
    await f._loadAssets();
    await f._loadOverrides();
    return f;
  }

  /// Carga los archivos y los deja activos para el `SfxService` del juego.
  static Future<SfxFiles> install(
      {AssetBundle? bundle, SfxOverrideSource? overrides}) async =>
      active = await load(bundle: bundle, overrides: overrides);

  /// Armado a mano (tests): [assets] = id → bytes.
  static SfxFiles fromMaps(Map<String, Uint8List> assets,
      {SfxOverrideSource? overrides}) {
    final f = SfxFiles._(rootBundle, overrides);
    f._assets.addAll(assets);
    return f;
  }

  Future<void> _loadAssets() async {
    _assets.clear();
    paths.clear();
    try {
      final doc = loadYaml(await _bundle.loadString(manifestPath));
      final m = doc is YamlMap ? doc['sfx'] : null;
      if (m is YamlMap) {
        for (final MapEntry(:key, :value) in m.entries) {
          if (value is String) paths['$key'] = value;
        }
      }
    } catch (e) {
      log.add('sin $manifestPath: $e');
      return;
    }
    for (final MapEntry(key: id, value: rel) in paths.entries) {
      try {
        final d = await _bundle.load('$root$rel');
        _assets[id] = d.buffer.asUint8List(d.offsetInBytes, d.lengthInBytes);
      } catch (e) {
        log.add('$id: no se pudo leer $rel');
      }
    }
  }

  Future<void> _loadOverrides() async {
    _overrides.clear();
    final o = overrides;
    if (o == null) return;
    await o.refreshSfx();
    for (final id in o.overriddenSfx) {
      final b = await o.readSfx(id);
      if (b != null) _overrides[id] = b;
    }
  }

  /// Recarga en caliente de los overrides.
  Future<void> reload() async {
    await _loadOverrides();
    revision.value++;
  }

  /// Ids con archivo (asset u override), ordenados.
  List<String> get ids => {..._assets.keys, ..._overrides.keys}.toList()..sort();

  bool has(String id) => _overrides.containsKey(id) || _assets.containsKey(id);
  bool hasOverride(String id) => _overrides.containsKey(id);
  bool hasAsset(String id) => _assets.containsKey(id);

  /// Bytes del archivo que suena para [id] (override → asset), o `null`
  /// (se sintetiza).
  Uint8List? bytesOf(String id) => _overrides[id] ?? _assets[id];
}

/// [wav] (PCM de 16 bits) con el tono multiplicado por [pitch] (> 1 más
/// agudo y más corto). Interpolación lineal. Si no es un WAV PCM16 (p.
/// ej. un OGG), devuelve [wav] igual.
Uint8List retuneWav(Uint8List wav, double pitch) {
  if ((pitch - 1).abs() < 0.001 || wav.length < 44) return wav;
  final bd = ByteData.sublistView(wav);
  if (sfxExtOf(wav) != 'wav') return wav;
  // Busca los trozos fmt y data.
  var p = 12;
  int? channels, bits, dataAt, dataLen;
  while (p + 8 <= wav.length) {
    final id = ascii.decode(wav.sublist(p, p + 4), allowInvalid: true);
    final len = bd.getUint32(p + 4, Endian.little);
    if (id == 'fmt ' && p + 24 <= wav.length) {
      if (bd.getUint16(p + 8, Endian.little) != 1) return wav; // no PCM
      channels = bd.getUint16(p + 10, Endian.little);
      bits = bd.getUint16(p + 22, Endian.little);
    } else if (id == 'data') {
      dataAt = p + 8;
      dataLen = math.min(len, wav.length - dataAt);
      break;
    }
    p += 8 + len + (len.isOdd ? 1 : 0);
  }
  if (channels == null || bits != 16 || dataAt == null || dataLen == null) {
    return wav;
  }
  final frames = dataLen ~/ (2 * channels);
  final outFrames = math.max(1, (frames / pitch).floor());
  final out = Uint8List(dataAt + outFrames * 2 * channels);
  out.setRange(0, dataAt, wav);
  final ob = ByteData.sublistView(out);
  ob.setUint32(4, out.length - 8, Endian.little);
  ob.setUint32(dataAt - 4, outFrames * 2 * channels, Endian.little);
  for (var i = 0; i < outFrames; i++) {
    final src = i * pitch;
    final a = src.floor();
    final b = math.min(a + 1, frames - 1);
    final k = src - a;
    for (var c = 0; c < channels; c++) {
      final sa = bd.getInt16(dataAt + (a * channels + c) * 2, Endian.little);
      final sb = bd.getInt16(dataAt + (b * channels + c) * 2, Endian.little);
      ob.setInt16(dataAt + (i * channels + c) * 2,
          (sa + (sb - sa) * k).round().clamp(-32768, 32767), Endian.little);
    }
  }
  return out;
}

/// Suma (o corrige) `<id>: <path>` bajo `sfx:` en el texto de
/// sfx_manifest.yaml, conservando comentarios.
String addSfxManifestEntry(String manifest, String id, String path) {
  final lines = const LineSplitter().convert(manifest);
  var s = lines.indexWhere((l) => l == 'sfx:' || l.startsWith('sfx: {}'));
  if (s < 0) return '${manifest.trimRight()}\nsfx:\n  $id: $path\n';
  if (lines[s] != 'sfx:') lines[s] = 'sfx:';
  var end = s + 1;
  while (end < lines.length &&
      (lines[end].startsWith(' ') || lines[end].trim().isEmpty)) {
    end++;
  }
  final k = lines.indexWhere((l) => l.startsWith('  $id:'), s + 1);
  if (k >= 0 && k < end) {
    lines[k] = '  $id: $path';
  } else {
    var at = end;
    while (at > s + 1 && lines[at - 1].trim().isEmpty) {
      at--;
    }
    lines.insert(at, '  $id: $path');
  }
  return '${lines.join('\n')}\n';
}
