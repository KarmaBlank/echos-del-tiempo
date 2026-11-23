import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/feature_flags.dart';
import '../di/service_locator.dart';
import '../settings/settings_providers.dart';
import 'catalog_text.dart';
import 'locale_id.dart';
import 'string_tables.dart';
import 'strings.dart';

export 'locale_id.dart';
export 'strings.dart';

StringTables? _diskTables;

/// The loaded string tables (docs/specs/i18n.md § 3). In the game, the
/// ones the flavor loaded from the bundle; in tests, read once from
/// `assets/i18n` on disk (empty if it is not there).
final stringTablesProvider = Provider<StringTables>((ref) {
  if (sl.isRegistered<StringTables>()) return sl<StringTables>();
  return _diskTables ??=
      StringTables.loadDirectorySync(StringTables.assetRoot) ??
          StringTables.empty();
});

/// OS locale for the automatic language. `null` in tests (no tables in
/// the service locator) so they always run in es-AR.
final systemLocaleProvider = Provider<String?>((ref) {
  if (!sl.isRegistered<StringTables>()) return null;
  try {
    return Platform.localeName;
  } catch (_) {
    return null;
  }
});

/// Steam's `GetCurrentGameLanguage()`; `null` until the Steamworks
/// binding exists (docs/specs/i18n.md § 5; tech_debt.md).
final steamLanguageProvider = Provider<String?>((ref) => null);

/// The language in use: OPCIONES → IDIOMA, else Steam / the OS (§ 3.1).
final activeLocaleProvider = Provider<LocaleId>((ref) {
  final tables = ref.watch(stringTablesProvider);
  final chosen = ref.watch(gameSettingsProvider.select((s) => s.locale));
  return tables.registry.resolve(
    chosen: chosen,
    steamLanguage: ref.watch(steamLanguageProvider),
    systemLocale: ref.watch(systemLocaleProvider),
    showHidden: FeatureFlags.instance.showHiddenLocales,
  );
});

/// Player-facing text of the active language: `ref.watch(stringsProvider)
/// .t('ui.title.play')`, or `ref.t(…)` / `ref.strings`.
/// Also publishes the result as [CatalogText.active] (catalog names).
final stringsProvider = Provider<Strings>((ref) {
  final s = ref.watch(stringTablesProvider).strings(
      ref.watch(activeLocaleProvider),
      allowMachineText: FeatureFlags.instance.allowMachineText);
  CatalogText.active = s;
  return s;
});

extension WidgetRefStrings on WidgetRef {
  /// Watches the active [Strings] (rebuilds when the language changes).
  Strings get strings => watch(stringsProvider);

  /// Shorthand for `strings.t(key, args)`.
  String t(StringKey key, [Map<String, Object?> args = const {}]) =>
      strings.t(key, args);
}
