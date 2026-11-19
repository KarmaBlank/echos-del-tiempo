import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Guarda el widget que arma [builder] y lo devuelve igual (el MISMO
/// objeto: Flutter no reconstruye nada debajo) mientras [deps] no cambie
/// (`listEquals`: elemento por elemento con `==`; las listas y mapas
/// adentro se comparan por identidad). Para el HUD, que recibe una vista
/// nueva de la sesión 20 veces por segundo aunque casi nada cambie
/// (docs/specs/exploration.md § "Rendimiento").
///
/// Si cambia algo heredado que [builder] leyó (tema, escala del texto,
/// `MediaQuery`) o se reensambla la app (cambio de tema de interfaz), se
/// vuelve a armar. Lo que está adentro y escucha por su cuenta
/// (`Consumer`, `ValueListenableBuilder`) sigue actualizándose solo.
class Memo extends StatefulWidget {
  const Memo({super.key, required this.deps, required this.builder});

  final List<Object?> deps;
  final WidgetBuilder builder;

  /// Veces que se armó el contenido (tests de rendimiento).
  @visibleForTesting
  static int debugBuilds = 0;

  @override
  State<Memo> createState() => _MemoState();
}

class _MemoState extends State<Memo> {
  Widget? _child;
  List<Object?>? _deps;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _child = null;
  }

  @override
  void reassemble() {
    super.reassemble();
    _child = null;
  }

  @override
  Widget build(BuildContext context) {
    final cached = _child;
    if (cached != null && listEquals(_deps, widget.deps)) return cached;
    _deps = widget.deps;
    assert(() {
      Memo.debugBuilds++;
      return true;
    }());
    return _child = widget.builder(context);
  }
}
