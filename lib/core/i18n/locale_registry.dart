import 'dart:convert';

import 'locale_id.dart';

/// Publication status of a language (docs/specs/i18n.md § 3.1).
enum LocaleStatus {
  /// The player can pick it and it is taken from Steam / the OS.
  published,

  /// Generated and editable, but not offered in OPCIONES nor taken from
  /// Steam / the OS (only builds with `FeatureFlags.showHiddenLocales`).
  hidden;

  static LocaleStatus fromName(Object? v) =>
      v == 'published' ? LocaleStatus.published : LocaleStatus.hidden;
}

/// `assets/i18n/locales.json`: which languages exist, which are
/// published and which string domains (one JSON per domain and locale)
/// the game loads.
class LocaleRegistry {
  const LocaleRegistry({required this.status, required this.domains});

  /// Languages absent from the file count as hidden.
  final Map<LocaleId, LocaleStatus> status;
  final List<String> domains;

  static const fileName = 'locales.json';

  factory LocaleRegistry.parse(String json) {
    final j = jsonDecode(json);
    if (j is! Map) throw const FormatException('locales.json: not an object');
    final status = <LocaleId, LocaleStatus>{};
    final locales = j['locales'];
    if (locales is Map) {
      for (final e in locales.entries) {
        final id = LocaleId.fromTag(e.key);
        if (id != null) status[id] = LocaleStatus.fromName(e.value);
      }
    }
    // The source language is always available.
    status[LocaleId.source] = LocaleStatus.published;
    final domains = [
      for (final d in (j['domains'] as List? ?? const [])) d as String,
    ];
    return LocaleRegistry(status: status, domains: domains);
  }

  bool isPublished(LocaleId id) => status[id] == LocaleStatus.published;

  /// Languages the player may pick, in enum order (es-AR first).
  List<LocaleId> selectable({bool showHidden = false}) => [
        for (final l in LocaleId.values)
          if (status.containsKey(l) && (showHidden || isPublished(l))) l,
      ];

  /// The language to use (§ 3.1, § 5): the player's choice ([chosen], a
  /// tag; empty = automatic) if selectable; otherwise Steam's language,
  /// else the OS one. A detected language that is hidden or not offered
  /// falls to English (e.g. Steam `schinese` while zh-Hans is hidden);
  /// nothing detected = es-AR.
  LocaleId resolve({
    String chosen = '',
    String? steamLanguage,
    String? systemLocale,
    bool showHidden = false,
  }) {
    final allowed = selectable(showHidden: showHidden);
    final pick = LocaleId.fromTag(chosen);
    if (pick != null && allowed.contains(pick)) return pick;
    if (steamLanguage == null && (systemLocale ?? '').isEmpty) {
      return LocaleId.source;
    }
    final detected = steamLanguage != null
        ? LocaleId.fromSteamLanguage(steamLanguage)
        : LocaleId.fromSystemLocale(systemLocale);
    if (detected != null && allowed.contains(detected)) return detected;
    return allowed.contains(LocaleId.en) ? LocaleId.en : LocaleId.source;
  }
}
