import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/i18n_providers.dart';

ProviderContainer? _fallback;

/// Active [Strings] for lobby widgets that are not Consumers. Reads the
/// enclosing ProviderScope; without one (isolated widget tests) it uses
/// a private container (es-AR from disk in tests).
Strings lobbyStrings(BuildContext context) {
  try {
    return ProviderScope.containerOf(context, listen: false)
        .read(stringsProvider);
  } on StateError {
    return (_fallback ??= ProviderContainer()).read(stringsProvider);
  }
}
