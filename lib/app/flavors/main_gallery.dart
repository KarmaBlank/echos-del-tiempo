import 'package:flutter/widgets.dart';

import '../app.dart';
import '../design/gallery/ds_gallery_screen.dart';
import '../feature_flags.dart';

/// Galería del sistema de diseño (docs/specs/design_system.md § 8): la app
/// con los FeatureFlags de dev, arrancando en la galería en vez del título.
///   flutter run -d windows -t lib/app/flavors/main_gallery.dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FeatureFlags.instance = const FeatureFlags(
    unlockAllCharacters: true,
    showDebugOverlay: true,
    enableExperimentalFeatures: true,
    devTools: true,
    soloParty: true,
  );
  runApp(const EcosApp(home: DsGalleryScreen()));
}
