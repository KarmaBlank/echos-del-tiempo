/// Languages the game knows about (docs/specs/i18n.md § 3). Whether a
/// language can be picked by the player is decided by
/// `assets/i18n/locales.json` (see `LocaleRegistry`), not here.
enum LocaleId {
  /// Rioplatense Spanish: the source language every key must exist in.
  esAR('es-AR', 'ESPAÑOL'),
  en('en', 'ENGLISH'),
  zhHans('zh-Hans', '简体中文');

  const LocaleId(this.tag, this.nativeName);

  /// BCP-47 tag; also the folder name under `assets/i18n/`.
  final String tag;

  /// The language's own name (endonym), shown as is in every language.
  final String nativeName;

  static const source = LocaleId.esAR;

  static LocaleId? fromTag(Object? tag) {
    for (final l in values) {
      if (l.tag == tag) return l;
    }
    return null;
  }

  /// Steamworks `GetCurrentGameLanguage()` API names (§ 5).
  static LocaleId? fromSteamLanguage(String? language) =>
      switch (language?.toLowerCase()) {
        'latam' || 'spanish' => LocaleId.esAR,
        'english' => LocaleId.en,
        'schinese' => LocaleId.zhHans,
        _ => null,
      };

  /// OS locale names such as `es_AR`, `en-US`, `zh_Hans_CN`, `zh_CN`.
  static LocaleId? fromSystemLocale(String? name) {
    if (name == null || name.isEmpty) return null;
    final lang = name.split(RegExp('[-_.@]')).first.toLowerCase();
    return switch (lang) {
      'es' => LocaleId.esAR,
      'en' => LocaleId.en,
      // Traditional-script Chinese is not offered: no match.
      'zh' => RegExp('hant|[-_](tw|hk|mo)', caseSensitive: false)
              .hasMatch(name)
          ? null
          : LocaleId.zhHans,
      _ => null,
    };
  }

  /// CLDR plural category for [n] (subset: `one` / `other`).
  String pluralCategory(num n) => switch (this) {
        LocaleId.zhHans => 'other',
        _ => n == 1 ? 'one' : 'other',
      };

  String get decimalSeparator => this == LocaleId.esAR ? ',' : '.';
  String get groupSeparator => this == LocaleId.esAR ? '.' : ',';
}
