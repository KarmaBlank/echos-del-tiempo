import 'locale_id.dart';
import 'string_tables.dart';
import 'strings.dart';

/// The active [Strings] for the pure-Dart text builders (skill, status,
/// passive and combat log text: docs/specs/i18n.md § 3.4), like
/// `TextDetail.current`. The app sets [current] from `stringsProvider`
/// (`app.dart`); outside the app (domain tests) it is es-AR read once
/// from `assets/i18n` on disk.
class GameText {
  const GameText._();

  static Strings? current;
  static Strings? _disk;

  static Strings get strings =>
      current ??
      (_disk ??= (StringTables.loadDirectorySync(StringTables.assetRoot) ??
              StringTables.empty())
          .strings(LocaleId.source));

  /// `strings.t(key, args)`.
  static String t(StringKey key, [Map<String, Object?> args = const {}]) =>
      strings.t(key, args);

  /// A catalog text by [key]; [source] (the engine's es-AR literal) when
  /// no table has it (a catalog test keeps both in sync).
  static String name(StringKey key, String source) {
    final s = strings;
    final own = s.lookup(key);
    if (own != null) return own;
    if (s.isSource) return source;
    final t = s.t(key);
    return t == key ? source : t;
  }
}
