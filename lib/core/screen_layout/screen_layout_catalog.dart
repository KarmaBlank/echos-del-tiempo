import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'screen_bindings.dart';
import 'screen_layout.dart';

/// Única clase que lee los layouts de pantallas
/// (`assets/layouts/<screen>.screen.json`, docs/specs/screen_editor.md § 3).
/// Sin archivo (o ilegible) [get] da `null` y la pantalla usa su versión
/// armada en código.
class ScreenLayoutCatalog extends ChangeNotifier {
  ScreenLayoutCatalog({AssetBundle? bundle, ScreenBindingRegistry? bindings})
      : _bundle = bundle,
        bindings = bindings ?? ScreenBindingRegistry.instance;

  /// La del juego.
  static ScreenLayoutCatalog instance = ScreenLayoutCatalog();

  static const dir = 'assets/layouts';
  static String pathOf(String screen) => '$dir/$screen.screen.json';

  AssetBundle? _bundle;
  final ScreenBindingRegistry bindings;
  final _layouts = <String, ScreenLayout>{};

  /// Lo que se ignoró al cargar.
  final log = <String>[];

  /// Pantallas editables (las que tienen bindings).
  List<String> get screens => [for (final s in bindings.all) s.screen];

  /// El layout de [screen] o `null` (fallback a código).
  ScreenLayout? get(String screen) => _layouts[screen];

  /// Lee todas las pantallas registradas. [bundle] reemplaza al actual.
  Future<void> load({AssetBundle? bundle}) async {
    if (bundle != null) _bundle = bundle;
    for (final s in screens) {
      await _read(s);
    }
    notifyListeners();
  }

  /// Recarga en caliente [screen].
  Future<void> reload(String screen) async {
    await _read(screen);
    notifyListeners();
  }

  Future<void> _read(String screen) async {
    _layouts.remove(screen);
    final String text;
    try {
      text = await (_bundle ?? rootBundle)
          .loadString(pathOf(screen), cache: false);
    } catch (_) {
      return; // sin archivo: pantalla de código
    }
    final l = parse(text);
    if (l != null) _layouts[screen] = l;
  }

  /// Parsea [text]; `null` (con log) si no es un layout válido.
  ScreenLayout? parse(String text) {
    try {
      return ScreenLayout.parse(text);
    } on Object catch (e) {
      final m = 'layout de pantalla ilegible: $e';
      log.add(m);
      debugPrint('[screen-layout] $m');
      return null;
    }
  }

  /// Fija un layout en memoria (editor, tests). `null` lo quita.
  void put(String screen, ScreenLayout? layout) {
    if (layout == null) {
      _layouts.remove(screen);
    } else {
      _layouts[screen] = layout;
    }
    notifyListeners();
  }
}
