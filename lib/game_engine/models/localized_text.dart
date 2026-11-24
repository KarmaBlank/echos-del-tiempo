/// A player-facing text written by hand in every language
/// (docs/specs/npc_editor.md § 1.1): a map from locale tag (`es-AR`,
/// `en`, `zh-Hans`, …) to text. Pure Dart; the app publishes the active
/// language in [activeTag].
class LocalizedText {
  /// Only the source language (es-AR): code defaults and the old
  /// plain-string format of the data files.
  const LocalizedText(String source)
      : _source = source,
        _map = const {};

  /// One text per locale tag.
  const LocalizedText.of(Map<String, String> byLocale)
      : _source = null,
        _map = byLocale;

  final String? _source;
  final Map<String, String> _map;

  /// The source language: every text falls back to it.
  static const sourceTag = 'es-AR';

  /// The language the game shows now (set by the i18n layer when the
  /// player picks a language; es-AR in tests).
  static String activeTag = sourceTag;

  static const empty = LocalizedText('');

  /// Deed tokens (docs/specs/renown_town_growth.md § 3): `{name}` in a
  /// shown text becomes its value. The game layer publishes them (like
  /// [activeTag]); unknown tokens stay as written.
  static Map<String, String> tokens = const {};

  static final _token = RegExp(r'\{([A-Za-z]+)\}');

  /// [s] with the [tokens] of [values] (default: [tokens]) filled in.
  static String fill(String s, [Map<String, String>? values]) {
    final v = values ?? tokens;
    if (v.isEmpty || !s.contains('{')) return s;
    return s.replaceAllMapped(_token, (m) => v[m[1]] ?? m[0]!);
  }

  /// Text per locale tag (may lack locales or hold empty strings).
  Map<String, String> get byLocale =>
      _source != null ? {sourceTag: _source} : _map;

  /// The es-AR text.
  String get source => byLocale[sourceTag] ?? '';

  /// Text in [tag] with the deed [tokens] filled; empty or missing =
  /// es-AR (the game never shows a blank line).
  String resolve(String tag) {
    final own = byLocale[tag];
    if (own != null && own.trim().isNotEmpty) return fill(own);
    return fill(source);
  }

  /// Text in the active language.
  String get text => resolve(activeTag);

  /// The tags of [tags] with no text.
  List<String> missing(Iterable<String> tags) => [
        for (final t in tags)
          if ((byLocale[t] ?? '').trim().isEmpty) t
      ];

  /// A copy with [tag] set to [value].
  LocalizedText withLocale(String tag, String value) =>
      LocalizedText.of({...byLocale, tag: value});

  /// Always the map form (the new format).
  Map<String, String> toJson() => {...byLocale};

  /// Accepts the new map form and the old plain string (= es-AR).
  static LocalizedText fromJson(Object? j) {
    if (j == null) return empty;
    if (j is String) return LocalizedText(j);
    if (j is Map) {
      return LocalizedText.of({
        for (final e in j.entries)
          if (e.key is String) e.key as String: '${e.value ?? ''}',
      });
    }
    throw FormatException('texto inválido: $j');
  }

  @override
  bool operator ==(Object other) {
    if (other is! LocalizedText) return false;
    final a = byLocale, b = other.byLocale;
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAllUnordered(
      byLocale.entries.map((e) => Object.hash(e.key, e.value)));

  @override
  String toString() => text;
}
