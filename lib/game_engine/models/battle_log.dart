/// One line of the battle log as data (docs/specs/i18n.md § 3.4): a
/// string key (`ui.battle_log.*`) plus its arguments. Each client
/// formats it in its own language; the network only carries ids, keys
/// and numbers.
///
/// An argument is a `String` (a runtime name such as a combatant's),
/// a number, a `bool`, a nested [LogLine] or a `List<LogLine>` (joined
/// with ` · `). Catalog names travel as refs ([LogLine.skill] etc.).
class LogLine {
  const LogLine(this.key, [this.args = const {}]) : _text = null;

  const LogLine._(this.key, this.args, this._text);

  /// No text.
  static const empty = LogLine('');

  /// Text as is (a test or a name that needs no translation).
  const LogLine.raw(String text) : this._(rawKey, const {}, text);

  /// Several parts joined with [sep] (` · ` by default; empty parts
  /// skipped).
  factory LogLine.join(Iterable<LogLine> parts, [String sep = ' · ']) {
    final l = [
      for (final p in parts)
        if (!p.isEmpty) p
    ];
    if (l.isEmpty) return empty;
    if (l.length == 1) return l.first;
    return LogLine(joinKey, {'p': l, if (sep != ' · ') 's': sep});
  }

  /// [v] as a line: a [LogLine] as is, anything else as raw text
  /// (engine text not yet keyed; shown as is in every language).
  factory LogLine.of(Object v) => v is LogLine ? v : LogLine.raw(v.toString());

  /// Appends [o]: a [LogLine] (or a list of them) after ` · `; raw text
  /// right after (it carries its own separator).
  LogLine operator +(Object o) => switch (o) {
        LogLine l => plus(l),
        Iterable<LogLine> ls => LogLine.join([this, ...ls]),
        _ => '$o'.isEmpty ? this : LogLine.join([this, LogLine.raw('$o')], ''),
      };

  /// This line followed by [other] (joined with [sep]).
  LogLine plus(LogLine other, [String sep = ' · ']) =>
      LogLine.join([this, other], sep);

  // Catalog refs: the formatter shows the name in the active language
  // ([name] is the engine's es-AR text, shown as is in es-AR).
  static LogLine skill(String id, String name) =>
      LogLine(skillRef, {'id': id, 'n': name});
  static LogLine dual(String key, String name) =>
      LogLine(dualRef, {'id': key, 'n': name});
  static LogLine enemyUlt(String id, String name) =>
      LogLine(enemyUltRef, {'id': id, 'n': name});
  static LogLine status(String kind, String name) =>
      LogLine(statusRef, {'id': kind, 'n': name});
  static LogLine reaction(String kind, String name) =>
      LogLine(reactionRef, {'id': kind, 'n': name});
  static LogLine summon(String kind, String name) =>
      LogLine(summonRef, {'id': kind, 'n': name});

  /// [line] in upper case (in every language).
  static LogLine upper(LogLine line) => LogLine(upperKey, {'x': line});
  static const upperKey = '^';

  /// Any catalog name by its string key (`CatalogKeys`).
  static LogLine named(String key, String name) =>
      LogLine(namedRef, {'k': key, 'n': name});

  static const rawKey = '=';
  static const namedRef = '@name';
  static const joinKey = '+';
  static const skillRef = '@skill';
  static const dualRef = '@dual';
  static const enemyUltRef = '@eult';
  static const statusRef = '@status';
  static const reactionRef = '@reaction';
  static const summonRef = '@summon';

  final String key;
  final Map<String, Object?> args;

  final String? _text;

  /// The literal of a [LogLine.raw].
  String? get rawText => key == rawKey ? _text : null;

  bool get isEmpty => key.isEmpty || (key == rawKey && (rawText ?? '').isEmpty);

  /// `{"k": key, "a": {...}}` (or a plain string for a raw line).
  Object? toJson() {
    if (key == rawKey) return rawText ?? '';
    if (key.isEmpty) return null;
    return {
      'k': key,
      if (args.isNotEmpty)
        'a': {for (final e in args.entries) e.key: _argToJson(e.value)},
    };
  }

  static Object? _argToJson(Object? v) => switch (v) {
        final LogLine l => {'l': l.toJson()},
        final List<LogLine> l => {
            'ls': [for (final x in l) x.toJson()]
          },
        final List l => {
            'ls': [for (final x in l) (x as LogLine).toJson()]
          },
        _ => v,
      };

  static LogLine fromJson(Object? j) {
    if (j == null) return empty;
    if (j is String) return j.isEmpty ? empty : LogLine.raw(j);
    if (j is! Map) return empty;
    final a = j['a'];
    return LogLine(j['k'] as String? ?? '', {
      if (a is Map)
        for (final e in a.entries) e.key as String: _argFromJson(e.value),
    });
  }

  static Object? _argFromJson(Object? v) {
    if (v is Map && v.containsKey('l')) return fromJson(v['l']);
    if (v is Map && v.containsKey('ls')) {
      return [for (final x in v['ls'] as List) fromJson(x)];
    }
    return v;
  }

  @override
  bool operator ==(Object other) =>
      other is LogLine && _deepEq(toJson(), other.toJson());

  @override
  int get hashCode => toJson().toString().hashCode;

  static bool _deepEq(Object? a, Object? b) {
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final k in a.keys) {
        if (!b.containsKey(k) || !_deepEq(a[k], b[k])) return false;
      }
      return true;
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_deepEq(a[i], b[i])) return false;
      }
      return true;
    }
    return a == b;
  }

  @override
  String toString() => 'LogLine(${toJson()})';
}
