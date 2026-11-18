import 'package:echos_del_tiempo/core/settings/window_mode.dart';

/// Ventana falsa: anota los pedidos de pantalla completa.
class FakeWindowMode extends WindowMode {
  FakeWindowMode() : super(supported: true);

  final calls = <bool>[];

  @override
  Future<bool> setFullscreen(bool on) async {
    calls.add(on);
    return true;
  }
}
