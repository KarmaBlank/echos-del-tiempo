import 'strings.dart';

/// Catalog text of the active language for code that has no `Strings` at
/// hand (item names, rarities, materials; docs/specs/i18n.md § 3.4).
///
/// [active] is set by `stringsProvider`. While it is `null` or es-AR the
/// catalog literal ([source]) is returned as is; a language without text
/// for the key also falls back to it. Pure Dart.
abstract final class CatalogText {
  static Strings? active;

  static String of(StringKey key, String source,
      [Map<String, Object?> args = const {}]) {
    final s = active;
    if (s == null || s.isSource) return source;
    return s.lookup(key, args) ?? source;
  }

  /// True when the active language is not the source (es-AR).
  static bool get isTranslated => !(active?.isSource ?? true);
}
