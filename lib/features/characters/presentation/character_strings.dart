import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/i18n_providers.dart';

export '../../../core/i18n/strings.dart' show Strings;

ProviderContainer? _fallback;

/// Active [Strings] for character widgets that are not Consumers.
/// Reads the enclosing ProviderScope; without one (isolated widget
/// tests, layout previews) it uses a private container, which resolves
/// to the bundled tables in the game and to es-AR from disk in tests.
Strings charStrings(BuildContext context) {
  try {
    return ProviderScope.containerOf(context, listen: false)
        .read(stringsProvider);
  } on StateError {
    return fallbackCharStrings();
  }
}

/// [Strings] without a context (static help texts read by other panels).
Strings fallbackCharStrings() =>
    (_fallback ??= ProviderContainer()).read(stringsProvider);
