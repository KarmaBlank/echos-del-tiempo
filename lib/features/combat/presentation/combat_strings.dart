import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/i18n/i18n_providers.dart';

export 'package:flutter_riverpod/flutter_riverpod.dart'
    show ProviderSubscription;

export '../../../core/i18n/i18n_providers.dart' show Strings;

ProviderContainer? _fallback;

/// The enclosing `ProviderScope`'s container, or `null` without one.
ProviderContainer? combatStringsContainer(BuildContext context) {
  try {
    return ProviderScope.containerOf(context, listen: false);
  } catch (_) {
    return null;
  }
}

/// Active [Strings] for the battle widgets, which are plain widgets (no
/// `WidgetRef`): the enclosing `ProviderScope` if there is one, else the
/// tables on disk (tests pump the battle without a scope, so es-AR).
/// `BattleView` listens to [stringsProvider] and rebuilds on a language
/// change (docs/specs/i18n.md § 3).
Strings combatStrings(BuildContext context) =>
    (combatStringsContainer(context) ?? (_fallback ??= ProviderContainer()))
        .read(stringsProvider);

/// [Strings] without a `BuildContext` (scene painters before the battle
/// sets its own, tests): the tables on disk in the default language.
Strings fallbackCombatStrings() =>
    (_fallback ??= ProviderContainer()).read(stringsProvider);

/// Calls [onChange] when the active language changes; `null` without a
/// `ProviderScope`. Close the subscription on dispose.
ProviderSubscription<Strings>? listenCombatStrings(
        BuildContext context, VoidCallback onChange) =>
    combatStringsContainer(context)
        ?.listen<Strings>(stringsProvider, (_, __) => onChange());
