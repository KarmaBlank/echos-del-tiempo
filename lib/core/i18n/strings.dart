import 'icu_formatter.dart';
import 'locale_id.dart';
import 'string_tables.dart';

/// Stable, English, hierarchical key: `<domain>.<id>.<field>`
/// (`ui.title.play`, `skills.fireball.desc`). docs/specs/i18n.md § 3.
typedef StringKey = String;

/// Player-facing text of the active language (pure Dart: `game_engine`
/// can receive it by injection). docs/specs/i18n.md § 3.
abstract class Strings {
  LocaleId get locale;

  /// True when [locale] is the source language (es-AR).
  bool get isSource => locale == LocaleId.source;

  /// [key] formatted with [args]. Fallback: active language → es-AR →
  /// the key itself (a test keeps keys from reaching a release).
  String t(StringKey key, [Map<String, Object?> args = const {}]);

  /// Like [t] but only the active language: `null` if it has no text.
  String? lookup(StringKey key, [Map<String, Object?> args = const {}]);
}

/// [Strings] backed by the in-memory [StringTables].
class CatalogStrings extends Strings {
  CatalogStrings(this.tables, this.locale, {this.allowMachineText = false});

  final StringTables tables;
  @override
  final LocaleId locale;

  /// Shows `status: machine` text (dev / beta flavors only).
  final bool allowMachineText;

  String? _raw(LocaleId l, StringKey key) {
    final e = tables.entry(l, key);
    if (e == null || e.text.isEmpty) return null;
    if (e.status == EntryStatus.machine && !allowMachineText) return null;
    return e.text;
  }

  String _format(String raw, LocaleId l, Map<String, Object?> args) {
    try {
      return IcuFormatter.format(raw, l, args);
    } on FormatException {
      return raw; // malformed entry: show it as is (a test catches it)
    }
  }

  @override
  String t(StringKey key, [Map<String, Object?> args = const {}]) {
    final own = _raw(locale, key);
    if (own != null) return _format(own, locale, args);
    final src = _raw(LocaleId.source, key);
    if (src != null) return _format(src, LocaleId.source, args);
    return key;
  }

  @override
  String? lookup(StringKey key, [Map<String, Object?> args = const {}]) {
    final own = _raw(locale, key);
    return own == null ? null : _format(own, locale, args);
  }
}
