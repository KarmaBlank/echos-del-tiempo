import 'localized_text.dart';

/// Renown sources (docs/specs/renown_town_growth.md § 2).
abstract final class RenownSource {
  static const zone = 'zone';
  static const biomeBoss = 'biomeBoss';
  static const rift = 'rift';
  static const lore = 'lore';
  static const tourney = 'tourney';
  static const resident = 'resident';
  static const building = 'building';

  static const all = [zone, biomeBoss, rift, lore, tourney, resident, building];
}

/// Town tier weights (§ 5.1).
abstract final class TownWeight {
  static const resident = 'resident';
  static const building = 'building';
  static const renown = 'renown';

  static const all = [resident, building, renown];
}

/// Who says a recognition line (§ 4.2), besides a resident id.
abstract final class RecognitionWho {
  static const visitor = 'visitor';
  static const wanderer = 'wanderer';
  static const caravan = 'caravan';

  static const actors = [visitor, wanderer, caravan];
}

/// A named threshold: a renown tier or a town tier (§ 2.1, § 5.1).
class RenownTier {
  const RenownTier(this.min, this.name);
  final int min;
  final LocalizedText name;

  Map<String, Object?> toJson() => {'min': min, 'name': name.toJson()};

  static RenownTier fromJson(Object? raw) {
    if (raw is! Map || raw['min'] is! num) {
      throw FormatException('nivel inválido: $raw');
    }
    return RenownTier(
        (raw['min'] as num).round(), LocalizedText.fromJson(raw['name']));
  }
}

/// A line that references the party's deeds (§ 4.2).
class RecognitionLine {
  const RecognitionLine(
      {required this.id,
      required this.who,
      this.minRenown = 0,
      this.text = LocalizedText.empty});

  final String id;

  /// `visitor` · `wanderer` · `caravan` · a resident id.
  final String who;
  final int minRenown;
  final LocalizedText text;

  Map<String, Object?> toJson() => {
        'id': id,
        'who': who,
        if (minRenown != 0) 'minRenown': minRenown,
        'text': text.toJson(),
      };

  static RecognitionLine fromJson(Object? raw) {
    if (raw is! Map || raw['id'] is! String || raw['who'] is! String) {
      throw FormatException('frase inválida: $raw');
    }
    return RecognitionLine(
        id: raw['id'] as String,
        who: raw['who'] as String,
        minRenown: raw['minRenown'] is num ? (raw['minRenown'] as num).round() : 0,
        text: LocalizedText.fromJson(raw['text']));
  }
}

/// Kind of a friendship-proposed town event (§ 6).
enum TownEventKind {
  tournament,
  festival;

  static TownEventKind fromName(Object? n) {
    for (final v in values) {
      if (v.name == n) return v;
    }
    throw FormatException('tipo de evento del pueblo inválido: $n');
  }
}

/// A town event a resident proposes (§ 6). Immutable.
class TownEventDef {
  const TownEventDef({
    required this.id,
    required this.kind,
    required this.proposer,
    this.minRep = 0,
    this.minRenown = 0,
    this.delay = 2,
    this.cooldown = 10,
    this.rounds = const [],
    this.levelBonus = 0,
    this.prize = 0,
    this.title = LocalizedText.empty,
    this.propose = LocalizedText.empty,
    this.accept = LocalizedText.empty,
    this.signup = LocalizedText.empty,
  });

  final String id;
  final TownEventKind kind;

  /// Resident who proposes it.
  final String proposer;
  final int minRep, minRenown;

  /// Days between accepting and the event day (≥ 1).
  final int delay;

  /// Days after it was held before it can be proposed again.
  final int cooldown;

  /// Tournament only: the fighters of each round (enemy ids).
  final List<List<String>> rounds;
  final int levelBonus;

  /// Gold per human for winning.
  final int prize;

  final LocalizedText title, propose, accept, signup;

  Iterable<(String, LocalizedText)> get texts => [
        ('title', title),
        ('propose', propose),
        ('accept', accept),
        ('signup', signup),
      ];

  Map<String, Object?> toJson() => {
        'id': id,
        'kind': kind.name,
        'proposer': proposer,
        if (minRep != 0) 'minRep': minRep,
        if (minRenown != 0) 'minRenown': minRenown,
        'delay': delay,
        'cooldown': cooldown,
        if (rounds.isNotEmpty) 'rounds': rounds,
        if (levelBonus != 0) 'levelBonus': levelBonus,
        if (prize != 0) 'prize': prize,
        for (final (k, t) in texts) k: t.toJson(),
      };

  static TownEventDef fromJson(Object? raw) {
    if (raw is! Map || raw['id'] is! String || raw['proposer'] is! String) {
      throw FormatException('evento del pueblo inválido: $raw');
    }
    int i(Object? v, int d) => v is num ? v.round() : d;
    return TownEventDef(
      id: raw['id'] as String,
      kind: TownEventKind.fromName(raw['kind']),
      proposer: raw['proposer'] as String,
      minRep: i(raw['minRep'], 0),
      minRenown: i(raw['minRenown'], 0),
      delay: i(raw['delay'], 2),
      cooldown: i(raw['cooldown'], 10),
      rounds: [
        if (raw['rounds'] case final List l)
          for (final r in l)
            [
              if (r is List)
                for (final x in r)
                  if (x is String) x
            ]
      ],
      levelBonus: i(raw['levelBonus'], 0),
      prize: i(raw['prize'], 0),
      title: LocalizedText.fromJson(raw['title']),
      propose: LocalizedText.fromJson(raw['propose']),
      accept: LocalizedText.fromJson(raw['accept']),
      signup: LocalizedText.fromJson(raw['signup']),
    );
  }
}

/// The renown catalog (§ 2–§ 6): `assets/data/renown/renown.json`.
class RenownConfig {
  const RenownConfig({
    this.sources = const {},
    this.town = const {},
    this.tiers = const [],
    this.townTiers = const [],
    this.lines = const [],
    this.events = const [],
  });

  static const assetPath = 'assets/data/renown/renown.json';

  /// Weight per [RenownSource] (missing = 0).
  final Map<String, num> sources;

  /// Weight per [TownWeight] (missing = 0).
  final Map<String, num> town;
  final List<RenownTier> tiers, townTiers;
  final List<RecognitionLine> lines;
  final List<TownEventDef> events;

  double weight(String source) => (sources[source] ?? 0).toDouble();
  double townWeight(String k) => (town[k] ?? 0).toDouble();

  TownEventDef? event(String id) => events.where((e) => e.id == id).firstOrNull;

  Map<String, Object?> toJson() => {
        'version': 1,
        'sources': sources,
        'town': town,
        'tiers': [for (final t in tiers) t.toJson()],
        'townTiers': [for (final t in townTiers) t.toJson()],
        'lines': [for (final l in lines) l.toJson()],
        'events': [for (final e in events) e.toJson()],
      };

  static RenownConfig fromJson(Object? raw) {
    if (raw is! Map) throw const FormatException('renombre: no es un objeto');
    Map<String, num> nums(Object? m) => {
          if (m is Map)
            for (final e in m.entries)
              if (e.key is String && e.value is num) e.key as String: e.value as num
        };
    List<T> list<T>(Object? l, T Function(Object?) f) =>
        [if (l is List) for (final x in l) f(x)];
    return RenownConfig(
      sources: nums(raw['sources']),
      town: nums(raw['town']),
      tiers: list(raw['tiers'], RenownTier.fromJson),
      townTiers: list(raw['townTiers'], RenownTier.fromJson),
      lines: list(raw['lines'], RecognitionLine.fromJson),
      events: list(raw['events'], TownEventDef.fromJson),
    );
  }

  /// Text paths lacking a language (`<where>:<tag>`).
  List<String> missingLocales(List<String> tags) => [
        for (final (i, t) in tiers.indexed)
          for (final m in t.name.missing(tags)) 'tiers.$i:$m',
        for (final (i, t) in townTiers.indexed)
          for (final m in t.name.missing(tags)) 'townTiers.$i:$m',
        for (final l in lines)
          for (final m in l.text.missing(tags)) '${l.id}:$m',
        for (final e in events)
          for (final (k, t) in e.texts)
            for (final m in t.missing(tags)) '${e.id}.$k:$m',
      ];

  /// Everything that blocks saving (§ 8), empty = valid.
  List<String> validate(List<String> tags,
      {Set<String>? residents, Set<String>? enemies}) {
    final out = <String>[];
    for (final e in sources.entries) {
      if (e.value < 0) out.add('Peso negativo: ${e.key}.');
    }
    for (final e in town.entries) {
      if (e.value < 0) out.add('Peso del pueblo negativo: ${e.key}.');
    }
    void ladder(String what, List<RenownTier> l) {
      if (l.isEmpty) {
        out.add('$what: hace falta al menos un nivel.');
        return;
      }
      if (l.first.min != 0) out.add('$what: el primer nivel empieza en 0.');
      for (var k = 1; k < l.length; k++) {
        if (l[k].min <= l[k - 1].min) {
          out.add('$what: los umbrales tienen que subir (${l[k].min}).');
        }
      }
    }

    ladder('Renombre', tiers);
    ladder('Pueblo', townTiers);
    final ids = <String>{};
    for (final l in lines) {
      if (!ids.add(l.id)) out.add('Id repetido: ${l.id}');
      if (l.minRenown < 0) out.add('${l.id}: renombre negativo.');
      final known = RecognitionWho.actors.contains(l.who) ||
          residents == null ||
          residents.contains(l.who);
      if (!known) out.add('${l.id}: quién desconocido ${l.who}.');
    }
    for (final e in events) {
      if (!ids.add(e.id)) out.add('Id repetido: ${e.id}');
      if (residents != null && !residents.contains(e.proposer)) {
        out.add('${e.id}: habitante desconocido ${e.proposer}.');
      }
      if (e.delay < 1) out.add('${e.id}: la demora tiene que ser 1 o más.');
      if (e.cooldown < 0) out.add('${e.id}: enfriamiento negativo.');
      if (e.prize < 0) out.add('${e.id}: premio negativo.');
      if (e.kind == TownEventKind.tournament) {
        if (e.rounds.length != 3 || e.rounds.any((r) => r.isEmpty)) {
          out.add('${e.id}: el torneo necesita 3 rondas con luchadores.');
        }
        if (enemies != null) {
          for (final r in e.rounds) {
            for (final x in r) {
              if (!enemies.contains(x)) out.add('${e.id}: enemigo desconocido $x.');
            }
          }
        }
      }
    }
    for (final m in missingLocales(tags)) {
      out.add('Falta idioma: $m');
    }
    return out;
  }
}

/// The world's renown milestones and town events (§ 1, § 6), saved and
/// sent in `TownState` (`rn`). Immutable.
class RenownState {
  const RenownState({
    this.zones = const {},
    this.rifts = 0,
    this.lore = 0,
    this.tourneys = 0,
    this.lastBoss = '',
    this.lastBiome = '',
    this.scheduled = const {},
    this.held = const {},
  });

  /// Zone indices whose zone mission (boss) was won.
  final Set<int> zones;
  final int rifts, lore, tourneys;

  /// Name of the last boss beaten and the id of its biome (tokens).
  final String lastBoss, lastBiome;

  /// Town events accepted: event id → world day it happens.
  final Map<String, int> scheduled;

  /// Town events held (won, lost or missed): event id → world day.
  final Map<String, int> held;

  bool get isEmpty =>
      zones.isEmpty &&
      rifts == 0 &&
      lore == 0 &&
      tourneys == 0 &&
      lastBoss.isEmpty &&
      lastBiome.isEmpty &&
      scheduled.isEmpty &&
      held.isEmpty;

  RenownState copyWith({
    Set<int>? zones,
    int? rifts,
    int? lore,
    int? tourneys,
    String? lastBoss,
    String? lastBiome,
    Map<String, int>? scheduled,
    Map<String, int>? held,
  }) =>
      RenownState(
        zones: zones ?? this.zones,
        rifts: rifts ?? this.rifts,
        lore: lore ?? this.lore,
        tourneys: tourneys ?? this.tourneys,
        lastBoss: lastBoss ?? this.lastBoss,
        lastBiome: lastBiome ?? this.lastBiome,
        scheduled: scheduled ?? this.scheduled,
        held: held ?? this.held,
      );

  Map<String, Object?> toJson() => {
        if (zones.isNotEmpty) 'z': (zones.toList()..sort()),
        if (rifts != 0) 'r': rifts,
        if (lore != 0) 'l': lore,
        if (tourneys != 0) 't': tourneys,
        if (lastBoss.isNotEmpty) 'lb': lastBoss,
        if (lastBiome.isNotEmpty) 'lp': lastBiome,
        if (scheduled.isNotEmpty) 'sc': scheduled,
        if (held.isNotEmpty) 'hd': held,
      };

  static RenownState fromJson(Object? raw) {
    if (raw is! Map) return const RenownState();
    int i(Object? v) => v is num ? v.round() : 0;
    String s(Object? v) => v is String ? v : '';
    Map<String, int> m(Object? v) => {
          if (v is Map)
            for (final e in v.entries)
              if (e.key is String && e.value is num)
                e.key as String: (e.value as num).round()
        };
    return RenownState(
      zones: {
        if (raw['z'] case final List l)
          for (final x in l)
            if (x is num) x.round()
      },
      rifts: i(raw['r']),
      lore: i(raw['l']),
      tourneys: i(raw['t']),
      lastBoss: s(raw['lb']),
      lastBiome: s(raw['lp']),
      scheduled: m(raw['sc']),
      held: m(raw['hd']),
    );
  }

  @override
  bool operator ==(Object other) {
    if (other is! RenownState) return false;
    bool sameMap(Map<String, int> a, Map<String, int> b) =>
        a.length == b.length && a.entries.every((e) => b[e.key] == e.value);
    return other.zones.length == zones.length &&
        other.zones.containsAll(zones) &&
        other.rifts == rifts &&
        other.lore == lore &&
        other.tourneys == tourneys &&
        other.lastBoss == lastBoss &&
        other.lastBiome == lastBiome &&
        sameMap(other.scheduled, scheduled) &&
        sameMap(other.held, held);
  }

  @override
  int get hashCode => Object.hash(Object.hashAllUnordered(zones), rifts, lore,
      tourneys, lastBoss, lastBiome, scheduled.length, held.length);
}
