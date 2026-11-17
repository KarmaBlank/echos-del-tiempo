import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

/// Inicializa Firebase si el proyecto está configurado
/// (`lib/firebase_options.dart` generado por `flutterfire configure`).
/// Con el stub de hoy, o si la inicialización falla, devuelve `false` y
/// el juego arranca igual sin P2P por internet. Ver docs/specs/netcode.md.
Future<bool> initFirebaseIfConfigured() async {
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    return true;
  } on Object catch (e) {
    debugPrint('Firebase no disponible: $e');
    return false;
  }
}
