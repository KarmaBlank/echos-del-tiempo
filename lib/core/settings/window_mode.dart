import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Ventana / pantalla completa de la app. En Windows lo hace el runner
/// nativo (`windows/runner/flutter_window.cpp`, canal `ecos/window`): sin
/// paquetes nuevos. En otras plataformas no hay opción (la UI la oculta).
/// Ver docs/specs/settings.md § "PANTALLA".
class WindowMode {
  const WindowMode({this.supported = true, this.channel = _channel});

  const WindowMode.unsupported()
      : supported = false,
        channel = _channel;

  /// La del escritorio actual: solo Windows (no web).
  factory WindowMode.forPlatform() =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows
          ? const WindowMode()
          : const WindowMode.unsupported();

  static const _channel = MethodChannel('ecos/window');

  /// Se puede elegir pantalla completa.
  final bool supported;
  final MethodChannel channel;

  /// Pide pantalla completa (sin bordes, el monitor entero) o vuelve a la
  /// ventana. Devuelve si el runner lo hizo.
  Future<bool> setFullscreen(bool on) async {
    if (!supported) return false;
    try {
      return await channel.invokeMethod<bool>('setFullscreen', on) ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
