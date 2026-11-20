import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

import 'layout_doc.dart';
import 'layout_spec.dart';
import 'layout_validator.dart';

/// Capa de overrides locales de layouts (Editor; § 2.6):
/// `overrides/layouts/<screen>.layout.yaml`.
abstract class LayoutOverrideSource {
  Future<String?> read(String screen);
}

/// Overrides que el Editor puede escribir y publicar.
abstract class EditableLayoutOverrides implements LayoutOverrideSource {
  /// Pantallas con override.
  Future<Set<String>> screens();
  Future<void> put(String screen, String yaml);
  Future<void> remove(String screen);

  /// PUBLICAR AL REPO: copia el override a
  /// `<repo>/assets/layouts/<screen>.layout.yaml`, lo suma al manifest y
  /// borra el override. `false` si no había override.
  Future<bool> publish(String repoRoot, String screen);
}

/// Única clase que lee los layouts (§ 2.6). Prioridad: override local
/// válido → asset del repo válido → layout por defecto en código. Un
/// archivo que no valida se ignora (con log) y se usa el siguiente.
///
/// Resuelve cada pantalla una vez (doc inmutable, cacheado); por build
/// solo se elige el corte. [reload] = recarga en caliente.
class LayoutCatalog extends ChangeNotifier {
  LayoutCatalog({AssetBundle? bundle, this.overrides})
      : _bundle = bundle;

  /// La del juego. Sin [load], cada pantalla usa su layout por defecto.
  static LayoutCatalog instance = LayoutCatalog();

  static const manifestPath = 'assets/layouts/layout_manifest.yaml';
  static const dir = 'assets/layouts';

  final AssetBundle? _bundle;
  LayoutOverrideSource? overrides;

  /// screen → archivo del manifest.
  final _manifest = <String, String>{};
  final _repo = <String, String>{};
  final _over = <String, String>{};
  final _docs = <String, LayoutDoc>{};
  final _from = <String, String>{};

  /// Mensajes de lo que se ignoró al cargar (archivos inválidos).
  final log = <String>[];

  AssetBundle get _b => _bundle ?? rootBundle;

  /// Pantallas del manifest.
  List<String> get screens => _manifest.keys.toList();

  /// De dónde salió el layout de [screen]: `override`, `repo` o `código`.
  String sourceOf(String screen) => _from[screen] ?? 'código';

  /// Lee el manifest, los YAML del repo y los overrides.
  Future<void> load() async {
    _manifest.clear();
    try {
      final m = loadYaml(await _b.loadString(manifestPath));
      if (m is YamlMap && m['screens'] is YamlMap) {
        for (final MapEntry(:key, :value) in (m['screens'] as YamlMap).entries) {
          _manifest[key as String] = value as String;
        }
      }
    } catch (e) {
      log.add('Sin manifest de layouts ($e)');
    }
    for (final s in _manifest.keys) {
      await _read(s);
    }
    _docs.clear();
    notifyListeners();
  }

  Future<void> _read(String screen) async {
    _repo.remove(screen);
    _over.remove(screen);
    final file = _manifest[screen];
    if (file != null) {
      try {
        _repo[screen] = await _b.loadString('$dir/$file', cache: false);
      } catch (e) {
        log.add('$screen: falta $file');
      }
    }
    try {
      final o = await overrides?.read(screen);
      if (o != null) _over[screen] = o;
    } catch (e) {
      log.add('$screen: override ilegible ($e)');
    }
  }

  /// Recarga en caliente [screen] (repo + override).
  Future<void> reload(String screen) async {
    await _read(screen);
    _docs.remove(screen);
    notifyListeners();
  }

  /// Fija el texto del repo de [screen] sin bundle (tests, editor).
  @visibleForTesting
  void setRepoText(String screen, String? yaml) {
    if (yaml == null) {
      _repo.remove(screen);
    } else {
      _repo[screen] = yaml;
    }
    _docs.remove(screen);
    notifyListeners();
  }

  /// El texto del repo de [screen] (para RESTAURAR en el editor).
  String? repoText(String screen) => _repo[screen];

  /// El layout del repo (válido) o el de código, sin override.
  LayoutDoc repoDoc(LayoutScreenSpec spec) =>
      _parseValid(spec, _repo[spec.screen], 'repo') ?? spec.defaults;

  /// El layout resuelto de [spec.screen].
  LayoutDoc docFor(LayoutScreenSpec spec) =>
      _docs[spec.screen] ??= _resolve(spec);

  LayoutDoc _resolve(LayoutScreenSpec spec) {
    final o = _parseValid(spec, _over[spec.screen], 'override');
    if (o != null) {
      _from[spec.screen] = 'override';
      return o;
    }
    final r = _parseValid(spec, _repo[spec.screen], 'repo');
    if (r != null) {
      _from[spec.screen] = 'repo';
      return r;
    }
    _from[spec.screen] = 'código';
    return spec.defaults;
  }

  LayoutDoc? _parseValid(LayoutScreenSpec spec, String? yaml, String what) {
    if (yaml == null) return null;
    try {
      final d = LayoutDoc.parse(yaml);
      final errors =
          LayoutValidator.validateStatic(d, spec).where((i) => i.error);
      if (errors.isEmpty) return d;
      _warn('${spec.screen}: $what inválido, se ignora (${errors.first})');
    } on FormatException catch (e) {
      _warn('${spec.screen}: $what ilegible, se ignora (${e.message})');
    }
    return null;
  }

  void _warn(String m) {
    if (log.contains(m)) return;
    log.add(m);
    debugPrint('[layout] $m');
  }
}
