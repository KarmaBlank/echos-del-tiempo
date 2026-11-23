import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/i18n_providers.dart';

export '../../../core/i18n/i18n_providers.dart' show Strings, StringKey, stringsProvider;

ProviderContainer? _fallback;

/// Player-facing text for the world widgets that are not Riverpod
/// consumers (docs/specs/i18n.md § 3). Reads [stringsProvider] from the
/// nearest `ProviderScope`; without one (isolated widget tests) it falls
/// back to a private container, i.e. the es-AR tables on disk.
///
/// It does not subscribe: the world screen watches [stringsProvider] so a
/// language change rebuilds the HUD and panels.
Strings worldStrings(BuildContext context) {
  ProviderContainer container;
  try {
    container = ProviderScope.containerOf(context, listen: false);
  } catch (_) {
    container = _fallback ??= ProviderContainer();
  }
  return container.read(stringsProvider);
}

/// The text outside any widget tree (e.g. a `SessionController` built in
/// a test): the es-AR tables on disk.
Strings worldFallbackStrings() =>
    (_fallback ??= ProviderContainer()).read(stringsProvider);

extension WorldContextStrings on BuildContext {
  /// Shorthand for `worldStrings(this).t(key, args)`.
  String t(StringKey key, [Map<String, Object?> args = const {}]) =>
      worldStrings(this).t(key, args);
}
