import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// "Cerrar todos los avisos" (DURACIÓN DE LOS AVISOS = HASTA CERRAR,
/// docs/specs/accessibility.md § 9.5): `WorldScreen` lo dispara con
/// `Retroceso`; los registros de loot y build, los avisos del chat
/// plegado, el de puntos sin usar y el cartel de misión opcional lo
/// escuchan y se vacían.
class NoticeDismissal extends ChangeNotifier {
  /// Cuántas veces se cerró todo (tests).
  int count = 0;

  void dismissAll() {
    count++;
    notifyListeners();
  }
}

/// El bus de "cerrar todos los avisos" de la app.
final noticeDismissProvider = Provider<NoticeDismissal>((ref) {
  final d = NoticeDismissal();
  ref.onDispose(d.dispose);
  return d;
});
