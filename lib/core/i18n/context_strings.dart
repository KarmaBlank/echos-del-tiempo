import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'i18n_providers.dart';

ProviderContainer? _fallback;

/// Player-facing text for widgets that are not Riverpod consumers and may
/// be pumped without a `ProviderScope` (docs/specs/i18n.md § 3): the
/// nearest scope's [stringsProvider] or, without one, es-AR from disk.
/// It does not subscribe to language changes.
Strings contextStrings(BuildContext context) {
  ProviderContainer container;
  try {
    container = ProviderScope.containerOf(context, listen: false);
  } catch (_) {
    container = _fallback ??= ProviderContainer();
  }
  return container.read(stringsProvider);
}
