import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/i18n_providers.dart';

ProviderContainer? _fallback;

/// Active [Strings] for settings widgets that are not Consumers.
/// Reads the enclosing ProviderScope; without one (isolated widget
/// tests, dialogs in previews) it uses a private container.
Strings settingsStrings(BuildContext context) {
  try {
    return ProviderScope.containerOf(context, listen: false)
        .read(stringsProvider);
  } on StateError {
    return (_fallback ??= ProviderContainer()).read(stringsProvider);
  }
}

/// Glyphs the fonts may lack in translation tables: passed as args.
const kDot = '·';
const kTimes = '×';
