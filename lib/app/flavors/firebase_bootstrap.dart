import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';
import '../../netcode/p2p_webrtc/firestore_rest_signaling.dart';
import '../../netcode/p2p_webrtc/firestore_signaling_service.dart';
import '../../netcode/p2p_webrtc/signaling_service.dart';

/// Escritorio (Windows/Linux/macOS): ahí la señalización P2P va por la
/// API REST de Firestore, no por el SDK nativo.
bool get isDesktopPlatform =>
    !kIsWeb &&
    const {TargetPlatform.windows, TargetPlatform.linux, TargetPlatform.macOS}
        .contains(defaultTargetPlatform);

/// Elige la señalización P2P según la plataforma (docs/specs/netcode.md
/// § "P2P por internet"). Devuelve cómo crearla, o `null` si Firebase no
/// está configurado (el stub de `lib/firebase_options.dart` lanza) o no
/// arrancó: el juego arranca igual, sin P2P por internet.
///
/// - **Escritorio**: `FirestoreRestSignaling` con `projectId` + `apiKey`
///   de las opciones. **No** llama a `Firebase.initializeApp`: el SDK C++
///   de escritorio pierde eventos de los listeners (avisos "non-platform
///   thread") y no hace falta para REST.
/// - **Web/Android/iOS**: `Firebase.initializeApp` + `cloud_firestore`.
Future<SignalingService Function()?> resolveP2PSignaling() async {
  final FirebaseOptions options;
  try {
    options = DefaultFirebaseOptions.currentPlatform;
  } on Object catch (e) {
    debugPrint('Firebase no configurado: $e');
    return null;
  }
  if (isDesktopPlatform) {
    if (options.projectId.isEmpty || options.apiKey.isEmpty) return null;
    return () => FirestoreRestSignaling(
        projectId: options.projectId, apiKey: options.apiKey);
  }
  try {
    await Firebase.initializeApp(options: options);
    return FirestoreSignalingService.new;
  } on Object catch (e) {
    debugPrint('Firebase no disponible: $e');
    return null;
  }
}
