import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/i18n_providers.dart';

export '../../../core/i18n/strings.dart' show Strings;

ProviderContainer? _fallback;

/// Player-facing text for the build planner widgets that are not
/// Riverpod consumers (docs/specs/i18n.md § 3, domain `ui.build`).
/// Outside a [ProviderScope] (bare widget tests) it reads a private
/// container, which resolves to es-AR like every test.
extension BuildPlannerText on BuildContext {
  Strings get buildStrings {
    ProviderContainer c;
    try {
      c = ProviderScope.containerOf(this, listen: false);
    } catch (_) {
      c = _fallback ??= ProviderContainer();
    }
    return c.read(stringsProvider);
  }

  /// Shorthand for `buildStrings.t(key, args)`.
  String bt(StringKey key, [Map<String, Object?> args = const {}]) =>
      buildStrings.t(key, args);
}
