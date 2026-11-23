import 'dart:convert';
import 'dart:io';

import 'locale_id.dart';
import 'locale_registry.dart';
import 'strings.dart';

/// Review state of a translated entry (docs/specs/i18n.md § 4).
enum EntryStatus {
  /// Human text that went through review. Source (es-AR) entries and
  /// plain-string entries count as reviewed.
  reviewed,

  /// Human text not yet reviewed.
  draft,

  /// Machine draft: only shown with `allowMachineText`.
  machine;

  static EntryStatus fromName(Object? v) =>
      values.firstWhere((s) => s.name == v, orElse: () => EntryStatus.reviewed);
}

class StringEntry {
  const StringEntry(this.text,
      {this.status = EntryStatus.reviewed, this.srcHash});

  /// Empty = missing (falls back to es-AR).
  final String text;
  final EntryStatus status;

  /// Hash of the es-AR text it was translated from (outdated detection).
  final String? srcHash;

  /// A value is either a plain string or
  /// `{"text": …, "status": "reviewed|draft|machine", "srcHash": …}`.
  static StringEntry? fromJson(Object? v) => switch (v) {
        final String s => StringEntry(s),
        final Map m when m['text'] is String => StringEntry(m['text'] as String,
            status: EntryStatus.fromName(m['status']),
            srcHash: m['srcHash'] as String?),
        _ => null,
      };
}

/// Every loaded string table, per language: `assets/i18n/<tag>/<domain>.json`
/// (flat `{key: value}`), listed by `assets/i18n/locales.json`.
class StringTables {
  StringTables(this.registry, this.tables);

  /// No text at all: every [Strings.t] returns the key.
  StringTables.empty()
      : registry = const LocaleRegistry(
            status: {LocaleId.source: LocaleStatus.published}, domains: []),
        tables = const {};

  final LocaleRegistry registry;
  final Map<LocaleId, Map<String, StringEntry>> tables;

  static const assetRoot = 'assets/i18n';

  static String path(LocaleId l, String domain) =>
      '$assetRoot/${l.tag}/$domain.json';

  StringEntry? entry(LocaleId l, String key) => tables[l]?[key];

  Strings strings(LocaleId l, {bool allowMachineText = false}) =>
      CatalogStrings(this, l, allowMachineText: allowMachineText);

  /// Loads with [read] (an asset path → its text; `rootBundle.loadString`
  /// in the game). A missing or broken domain file is skipped.
  static Future<StringTables> load(
      Future<String> Function(String path) read) async {
    final registry =
        LocaleRegistry.parse(await read('$assetRoot/${LocaleRegistry.fileName}'));
    final tables = <LocaleId, Map<String, StringEntry>>{};
    for (final l in registry.status.keys) {
      final t = tables[l] = {};
      for (final d in registry.domains) {
        try {
          _merge(t, await read(path(l, d)));
        } catch (_) {
          // Missing domain for this language: falls back to es-AR.
        }
      }
    }
    return StringTables(registry, tables);
  }

  /// Synchronous load from a folder laid out like `assets/i18n` (tests and
  /// tools; `null` if there is no `locales.json`).
  static StringTables? loadDirectorySync(String root) {
    final reg = File('$root/${LocaleRegistry.fileName}');
    if (!reg.existsSync()) return null;
    final registry = LocaleRegistry.parse(reg.readAsStringSync());
    final tables = <LocaleId, Map<String, StringEntry>>{};
    for (final l in registry.status.keys) {
      final t = tables[l] = {};
      for (final d in registry.domains) {
        final f = File('$root/${l.tag}/$d.json');
        if (f.existsSync()) _merge(t, f.readAsStringSync());
      }
    }
    return StringTables(registry, tables);
  }

  static void _merge(Map<String, StringEntry> into, String json) {
    final j = jsonDecode(json);
    if (j is! Map) return;
    for (final e in j.entries) {
      final entry = StringEntry.fromJson(e.value);
      if (entry != null) into[e.key as String] = entry;
    }
  }
}
