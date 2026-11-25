import 'localized_text.dart';
import 'sky.dart' show Season, Weather;

/// Kind of world event (docs/specs/world_events.md § 3).
enum WorldEventCategory {
  visitor,
  overworldNpc,
  echoPortal,
  lore,
  caravan;

  /// Happens in town (not in a biome).
  bool get inTown => this == visitor || this == caravan;

  /// A person to talk to (§ 3.6).
  bool get isNpc => this == visitor || this == overworldNpc || this == caravan;

  static WorldEventCategory fromName(Object? n) {
    for (final v in values) {
      if (v.name == n) return v;
    }
    throw FormatException('categoría de evento inválida: $n');
  }
}

/// Objective of a lore quest (§ 3.4). There is no fetch/gather kind on
/// purpose. Only kinds the host can track live here (escort, talk,
/// survive and puzzle wait for their own systems).
enum LoreObjective {
  /// Defeat [WorldEventDef.n] enemies of type [WorldEventDef.target].
  defeat,

  /// Reach the place [WorldEventDef.target] (a biome exterior).
  explore;

  static LoreObjective fromName(Object? n) {
    for (final v in values) {
      if (v.name == n) return v;
    }
    throw FormatException('objetivo inválido: $n');
  }
}

/// One entry of the event catalog (§ 1). Immutable.
class WorldEventDef {
  const WorldEventDef({
    required this.id,
    required this.category,
    this.enabled = true,
    this.weight = 1,
    this.duration = 3,
    this.minDay = 0,
    this.minRenown = 0,
    this.biomes = const [],
    this.resident,
    this.title = LocalizedText.empty,
    this.notice = LocalizedText.empty,
    this.body = LocalizedText.empty,
    this.params = const {},
    this.objective,
    this.target = '',
    this.n = 1,
    this.sprite = '',
    this.season,
    this.weather,
    this.greeting = LocalizedText.empty,
    this.talks,
    this.topics = const [],
    this.actions = const [],
  });

  /// Event NPCs only (visitor, wanderer, caravan; § 3.6): the first
  /// line of their dialogue box (empty = the notice).
  final LocalizedText greeting;

  /// Whether pressing E opens its dialogue box (biome_exploration.md
  /// § 6). `null` = the default of [WorldEventRules.talks]: a roaming
  /// foe (drawn as its enemy) fights at once, everyone else talks. A
  /// future talking enemy sets `true`.
  final bool? talks;

  /// Talk topics of the event NPC (§ 3.6): question and answer.
  final List<EventTopic> topics;

  /// The 1–2 concrete things the event NPC offers (§ 3.6).
  final List<EventNpcAction> actions;

  /// Climate condition (weather_seasons.md, world_events.md § 1): the
  /// event only rolls in this season (`Season.name`; `null` = any) …
  final String? season;

  /// … and with this town weather that day (`Weather.name`; `null` =
  /// any).
  final String? weather;

  /// Sprite of the event's NPC (`items.vida_<sprite>` of the manifest;
  /// visitors, wanderers and caravans). Empty = none.
  final String sprite;

  final String id;
  final WorldEventCategory category;
  final bool enabled;
  final int weight;

  /// Days it lasts (≥ 1).
  final int duration;

  /// Minimum world day.
  final int minDay;

  /// Minimum world renown (renown_town_growth.md § 4.3).
  final int minRenown;

  /// Where it may appear (empty = any open biome).
  final List<String> biomes;

  /// Resident that must live in town (`null` = none).
  final String? resident;

  final LocalizedText title, notice, body;

  /// Numbers (§ 1): missing ones take their neutral value.
  final Map<String, num> params;

  /// Lore only.
  final LoreObjective? objective;
  final String target;
  final int n;

  static const _neutralOne = {'hpMult', 'atkMult', 'rewardMult'};

  /// [key] of [params], or its neutral value.
  double param(String key) =>
      (params[key] ?? (_neutralOne.contains(key) ? 1 : 0)).toDouble();

  Iterable<LocalizedText> get texts => [title, notice, body];

  /// Has a dialogue box (§ 3.6): visitor, wanderer or caravan.
  bool get isNpc => category.isNpc;

  Map<String, Object?> toJson() => {
        'id': id,
        'category': category.name,
        if (!enabled) 'enabled': false,
        'weight': weight,
        'duration': duration,
        if (minDay != 0) 'minDay': minDay,
        if (minRenown != 0) 'minRenown': minRenown,
        if (biomes.isNotEmpty) 'biomes': biomes,
        if (resident != null) 'resident': resident,
        'title': title.toJson(),
        'notice': notice.toJson(),
        'body': body.toJson(),
        if (params.isNotEmpty) 'params': params,
        if (sprite.isNotEmpty) 'sprite': sprite,
        if (season != null) 'season': season,
        if (weather != null) 'weather': weather,
        if (objective != null) ...{
          'objective': objective!.name,
          'target': target,
          'n': n,
        },
        if (greeting.byLocale.values.any((v) => v.isNotEmpty)) 'greeting': greeting.toJson(),
        if (talks != null) 'talks': talks,
        if (topics.isNotEmpty) 'topics': [for (final t in topics) t.toJson()],
        if (actions.isNotEmpty)
          'actions': [for (final a in actions) a.toJson()],
      };

  static WorldEventDef fromJson(Object? raw) {
    if (raw is! Map) throw FormatException('evento inválido: $raw');
    final id = raw['id'];
    if (id is! String || id.isEmpty) throw const FormatException('evento sin id');
    int i(Object? v, int d) => v is num ? v.round() : d;
    final p = raw['params'];
    final res = raw['resident'];
    return WorldEventDef(
      id: id,
      category: WorldEventCategory.fromName(raw['category']),
      enabled: raw['enabled'] != false,
      weight: i(raw['weight'], 1),
      duration: i(raw['duration'], 3),
      minDay: i(raw['minDay'], 0),
      minRenown: i(raw['minRenown'], 0),
      biomes: [
        if (raw['biomes'] case final List l)
          for (final b in l)
            if (b is String && b.isNotEmpty) b
      ],
      resident: res is String && res.isNotEmpty ? res : null,
      title: LocalizedText.fromJson(raw['title']),
      notice: LocalizedText.fromJson(raw['notice']),
      body: LocalizedText.fromJson(raw['body']),
      params: {
        if (p is Map)
          for (final e in p.entries)
            if (e.key is String && e.value is num) e.key as String: e.value as num
      },
      objective: raw['objective'] == null
          ? null
          : LoreObjective.fromName(raw['objective']),
      target: raw['target'] is String ? raw['target'] as String : '',
      n: i(raw['n'], 1),
      sprite: raw['sprite'] is String ? raw['sprite'] as String : '',
      season: raw['season'] is String && (raw['season'] as String).isNotEmpty
          ? raw['season'] as String
          : null,
      weather:
          raw['weather'] is String && (raw['weather'] as String).isNotEmpty
              ? raw['weather'] as String
              : null,
      greeting: LocalizedText.fromJson(raw['greeting']),
      talks: raw['talks'] is bool ? raw['talks'] as bool : null,
      topics: [
        if (raw['topics'] case final List l)
          for (final t in l) EventTopic.fromJson(t)
      ],
      actions: [
        if (raw['actions'] case final List l)
          for (final a in l) EventNpcAction.fromJson(a)
      ],
    );
  }
}

/// A talk topic of an event NPC (§ 3.6): the question the player picks
/// and the NPC's answer.
class EventTopic {
  const EventTopic(
      {required this.id,
      this.label = LocalizedText.empty,
      this.line = LocalizedText.empty});
  final String id;
  final LocalizedText label, line;

  Map<String, Object?> toJson() =>
      {'id': id, 'label': label.toJson(), 'line': line.toJson()};

  static EventTopic fromJson(Object? raw) {
    if (raw is! Map || raw['id'] is! String) {
      throw FormatException('tema inválido: $raw');
    }
    return EventTopic(
        id: raw['id'] as String,
        label: LocalizedText.fromJson(raw['label']),
        line: LocalizedText.fromJson(raw['line']));
  }
}

/// What an event NPC can do for a player (§ 3.6). Fixed whitelist over
/// existing systems.
enum EventActionKind {
  /// One-time present per player: `item` × `qty` and/or `gold`.
  gift,

  /// A useful tip with a map marker on `target` (`rift` = the active
  /// echo rift, or a biome id).
  rumor,

  /// A single scaled fight against `target` (an enemy id), through the
  /// rift battle path; a win pays and adds renown.
  duel,

  /// The town stall with the event discount (visitor / caravan).
  trade;

  static EventActionKind fromName(Object? n) {
    for (final v in values) {
      if (v.name == n) return v;
    }
    throw FormatException('acción de evento inválida: $n');
  }

  /// Something the player still has to do once (drives the "!" mark).
  bool get once => this != trade;
}

/// One action of an event NPC (§ 3.6). Immutable.
class EventNpcAction {
  const EventNpcAction(this.kind,
      {this.label = LocalizedText.empty,
      this.line = LocalizedText.empty,
      this.item = '',
      this.target = '',
      this.params = const {}});

  final EventActionKind kind;

  /// The option in the dialogue box and the NPC's line when picked.
  final LocalizedText label, line;

  /// Gift: item id (smithing material, bait or seed; empty = gold only).
  final String item;

  /// Rumor: `rift` or a biome id. Duel: enemy id.
  final String target;

  /// Numbers: gift `qty` / `gold`; duel `hpMult`, `atkMult`,
  /// `levelBonus`, `rewardMult`.
  final Map<String, num> params;

  /// Rumor target meaning "wherever the echo rift is now".
  static const rift = 'rift';

  /// Duel target: the elite of one of the biome's zones
  /// (biome_exploration.md § 6).
  static const elite = '@elite';

  static const _neutralOne = {'hpMult', 'atkMult', 'rewardMult', 'qty'};

  double param(String key) =>
      (params[key] ?? (_neutralOne.contains(key) ? 1 : 0)).toDouble();

  Map<String, Object?> toJson() => {
        'kind': kind.name,
        'label': label.toJson(),
        'line': line.toJson(),
        if (item.isNotEmpty) 'item': item,
        if (target.isNotEmpty) 'target': target,
        if (params.isNotEmpty) 'params': params,
      };

  static EventNpcAction fromJson(Object? raw) {
    if (raw is! Map) throw FormatException('acción inválida: $raw');
    final p = raw['params'];
    return EventNpcAction(EventActionKind.fromName(raw['kind']),
        label: LocalizedText.fromJson(raw['label']),
        line: LocalizedText.fromJson(raw['line']),
        item: raw['item'] is String ? raw['item'] as String : '',
        target: raw['target'] is String ? raw['target'] as String : '',
        params: {
          if (p is Map)
            for (final e in p.entries)
              if (e.key is String && e.value is num)
                e.key as String: e.value as num
        });
  }
}

/// Global settings plus the catalog (§ 1). Immutable.
class WorldEventsConfig {
  const WorldEventsConfig({
    this.interval = 5,
    this.minPerRoll = 1,
    this.maxPerRoll = 2,
    this.chance = 1,
    this.events = const [],
  });

  final int interval;
  final int minPerRoll, maxPerRoll;

  /// Probability (0–1) that a due roll yields events at all.
  final double chance;
  final List<WorldEventDef> events;

  WorldEventDef? def(String id) =>
      events.where((e) => e.id == id).firstOrNull;

  static const assetPath = 'assets/data/events/world_events.json';

  Map<String, Object?> toJson() => {
        'version': 1,
        'interval': interval,
        'minPerRoll': minPerRoll,
        'maxPerRoll': maxPerRoll,
        'chance': chance,
        'events': [for (final e in events) e.toJson()],
      };

  static WorldEventsConfig fromJson(Object? raw) {
    if (raw is! Map) throw const FormatException('eventos: no es un objeto');
    int i(Object? v, int d) => v is num ? v.round() : d;
    final list = raw['events'];
    return WorldEventsConfig(
      interval: i(raw['interval'], 5),
      minPerRoll: i(raw['minPerRoll'], 1),
      maxPerRoll: i(raw['maxPerRoll'], 2),
      chance: raw['chance'] is num ? (raw['chance'] as num).toDouble() : 1,
      events: [
        if (list is List)
          for (final e in list) WorldEventDef.fromJson(e)
      ],
    );
  }

  /// Text paths lacking a language (`<event>.<field>:<tag>`).
  List<String> missingLocales(List<String> tags) => [
        for (final e in events) ...[
          for (final (f, t) in [
            ('title', e.title),
            ('notice', e.notice),
            ('body', e.body)
          ])
            for (final m in t.missing(tags)) '${e.id}.$f:$m',
          if (e.isNpc &&
              (e.actions.isNotEmpty ||
                  e.topics.isNotEmpty ||
                  e.greeting.byLocale.values.any((v) => v.trim().isNotEmpty)))
            for (final m in e.greeting.missing(tags)) '${e.id}.greeting:$m',
          for (final t in e.topics)
            for (final (f, x) in [('label', t.label), ('line', t.line)])
              for (final m in x.missing(tags)) '${e.id}.topic.${t.id}.$f:$m',
          for (var i = 0; i < e.actions.length; i++)
            for (final (f, x) in [
              ('label', e.actions[i].label),
              ('line', e.actions[i].line)
            ])
              for (final m in x.missing(tags)) '${e.id}.action.$i.$f:$m',
        ]
      ];

  /// Everything that blocks saving (§ 7), empty = valid.
  List<String> validate(List<String> tags,
      {Set<String>? biomes,
      Set<String>? residents,
      Set<String>? enemies,
      Set<String>? items}) {
    final out = <String>[];
    if (interval < 1) out.add('El intervalo tiene que ser 1 o más.');
    if (minPerRoll < 0) out.add('El mínimo por tirada no puede ser negativo.');
    if (maxPerRoll < minPerRoll) out.add('El máximo es menor que el mínimo.');
    if (chance < 0 || chance > 1) out.add('La probabilidad va de 0 a 1.');
    final ids = <String>{};
    for (final e in events) {
      if (!ids.add(e.id)) out.add('Id repetido: ${e.id}');
      if (e.weight < 0) out.add('${e.id}: peso negativo.');
      if (e.duration < 1) out.add('${e.id}: duración menor a 1 día.');
      if (e.category == WorldEventCategory.lore) {
        if (e.resident == null) out.add('${e.id}: la historia necesita habitante.');
        if (e.objective == null) out.add('${e.id}: la historia necesita objetivo.');
        if (e.objective == LoreObjective.defeat &&
            enemies != null &&
            !enemies.contains(e.target)) {
          out.add('${e.id}: enemigo desconocido ${e.target}.');
        }
        if (e.objective == LoreObjective.explore &&
            biomes != null &&
            !biomes.contains(e.target)) {
          out.add('${e.id}: lugar desconocido ${e.target}.');
        }
        if (e.n < 1) out.add('${e.id}: la cantidad tiene que ser 1 o más.');
      }
      if (biomes != null) {
        for (final b in e.biomes) {
          if (!biomes.contains(b)) out.add('${e.id}: bioma desconocido $b.');
        }
      }
      if (residents != null &&
          e.resident != null &&
          !residents.contains(e.resident)) {
        out.add('${e.id}: habitante desconocido ${e.resident}.');
      }
      if (e.season != null &&
          !Season.values.any((s) => s.name == e.season)) {
        out.add('${e.id}: estación desconocida ${e.season}.');
      }
      if (e.weather != null &&
          !Weather.values.any((w) => w.name == e.weather)) {
        out.add('${e.id}: clima desconocido ${e.weather}.');
      }
      out.addAll(
          validateNpc(e, biomes: biomes, enemies: enemies, items: items));
    }
    for (final m in missingLocales(tags)) {
      out.add('Falta idioma: $m');
    }
    return out;
  }
}

/// Problems of the event NPC part of [e] (§ 3.6, § 7).
List<String> validateNpc(WorldEventDef e,
    {Set<String>? biomes, Set<String>? enemies, Set<String>? items}) {
  final out = <String>[];
  if (!e.isNpc) {
    if (e.topics.isNotEmpty || e.actions.isNotEmpty) {
      out.add('${e.id}: solo visitantes, viajeros y caravanas hablan.');
    }
    return out;
  }
  if (e.actions.length > 2) out.add('${e.id}: máximo 2 acciones.');
  final topicIds = <String>{};
  for (final t in e.topics) {
    if (t.id.isEmpty || !topicIds.add(t.id)) {
      out.add('${e.id}: tema sin id o repetido (${t.id}).');
    }
  }
  final kinds = <EventActionKind>{};
  for (final a in e.actions) {
    final w = '${e.id} (${a.kind.name})';
    if (!kinds.add(a.kind)) out.add('$w: acción repetida.');
    switch (a.kind) {
      case EventActionKind.gift:
        if (a.item.isEmpty && a.param('gold') <= 0) {
          out.add('$w: el regalo necesita objeto u oro.');
        }
        if (a.item.isNotEmpty && items != null && !items.contains(a.item)) {
          out.add('$w: objeto desconocido ${a.item}.');
        }
        if (a.item.isNotEmpty && a.param('qty') < 1) {
          out.add('$w: la cantidad tiene que ser 1 o más.');
        }
        if (a.param('gold') < 0) out.add('$w: oro negativo.');
      case EventActionKind.rumor:
        if (a.target != EventNpcAction.rift &&
            (a.target.isEmpty ||
                (biomes != null && !biomes.contains(a.target)))) {
          out.add('$w: rumor sin lugar conocido (${a.target}).');
        }
      case EventActionKind.duel:
        if (e.category != WorldEventCategory.overworldNpc) {
          out.add('$w: el duelo es solo para viajeros del campo.');
        }
        if (a.target.isEmpty ||
            (enemies != null &&
                a.target != EventNpcAction.elite &&
                !enemies.contains(a.target))) {
          out.add('$w: enemigo desconocido ${a.target}.');
        }
        for (final k in const ['hpMult', 'atkMult', 'rewardMult']) {
          if (a.param(k) <= 0) out.add('$w: $k tiene que ser mayor a 0.');
        }
        if (a.param('levelBonus') < 0) out.add('$w: nivel + negativo.');
      case EventActionKind.trade:
        // Deep merchants of the wilds trade too (biome_exploration.md § 6).
        if (!e.category.inTown && e.param('deep') <= 0) {
          out.add('$w: comerciar es solo para visitantes y caravanas.');
        }
    }
  }
  return out;
}

/// A running event (§ 1). Immutable.
class ActiveWorldEvent {
  const ActiveWorldEvent(this.def,
      {required this.biome, required this.start, required this.end});

  final String def;

  /// Where it applies (`pueblo` for town events).
  final String biome;

  /// World days: it ends when the day reaches [end].
  final int start, end;

  String get uid => '$def@$start';

  int daysLeft(int day) => end - day;

  Map<String, Object?> toJson() => {'d': def, 'b': biome, 's': start, 'e': end};

  static ActiveWorldEvent? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final d = raw['d'], b = raw['b'], s = raw['s'], e = raw['e'];
    if (d is! String || b is! String || s is! num || e is! num) return null;
    return ActiveWorldEvent(d, biome: b, start: s.round(), end: e.round());
  }

  @override
  bool operator ==(Object other) =>
      other is ActiveWorldEvent &&
      other.def == def &&
      other.biome == biome &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(def, biome, start, end);
}

/// World events of a world (§ 1): saved and sent in `TownState` (`wev`).
class WorldEventsState {
  const WorldEventsState(
      {this.seed = 0,
      this.last = 0,
      this.active = const [],
      this.seen = const {},
      this.progress = const {},
      this.cleared = const {},
      this.done = const {}});

  /// Event NPC actions already used (§ 3.6): `<uid>#<index>` → player
  /// ids (gift taken, rumor heard). Duels use [cleared].
  final Map<String, Set<String>> done;

  static String doneKey(String uid, int i) => '$uid#$i';

  /// [player] already used action [i] of the event [uid].
  bool doneBy(String uid, int i, String player) =>
      done[doneKey(uid, i)]?.contains(player) ?? false;

  /// With action [i] of [uid] used by [player].
  WorldEventsState markDone(String uid, int i, String player) {
    final k = doneKey(uid, i);
    return copyWith(done: {
      ...done,
      k: {...?done[k], player},
    });
  }

  /// Lore quest progress by event uid (§ 3.4).
  final Map<String, int> progress;

  /// Rift portals closed after a win (§ 3.3): event uid → player ids.
  final Map<String, Set<String>> cleared;

  /// [player] already beat the rift [uid].
  bool clearedBy(String uid, String player) =>
      cleared[uid]?.contains(player) ?? false;

  /// Seed for the rolls (0 = not set yet; the host sets it once).
  final int seed;

  /// World day of the last roll.
  final int last;
  final List<ActiveWorldEvent> active;

  /// Lore events that already happened (once per world).
  final Set<String> seen;

  bool get isEmpty =>
      seed == 0 &&
      last == 0 &&
      active.isEmpty &&
      seen.isEmpty &&
      progress.isEmpty &&
      cleared.isEmpty &&
      done.isEmpty;

  /// Without [uid] (and its progress / portal closures).
  WorldEventsState without(String uid) => copyWith(
      active: [for (final a in active) if (a.uid != uid) a],
      progress: {...progress}..remove(uid),
      cleared: {...cleared}..remove(uid),
      done: {
        for (final e in done.entries)
          if (!e.key.startsWith('$uid#')) e.key: e.value
      });

  /// Active events at [place].
  List<ActiveWorldEvent> at(String place) =>
      [for (final a in active) if (a.biome == place) a];

  WorldEventsState copyWith(
          {int? seed,
          int? last,
          List<ActiveWorldEvent>? active,
          Set<String>? seen,
          Map<String, int>? progress,
          Map<String, Set<String>>? cleared,
          Map<String, Set<String>>? done}) =>
      WorldEventsState(
          seed: seed ?? this.seed,
          last: last ?? this.last,
          active: active ?? this.active,
          seen: seen ?? this.seen,
          progress: progress ?? this.progress,
          cleared: cleared ?? this.cleared,
          done: done ?? this.done);

  Map<String, Object?> toJson() => {
        's': seed,
        'l': last,
        if (active.isNotEmpty) 'a': [for (final a in active) a.toJson()],
        if (seen.isNotEmpty) 'sn': (seen.toList()..sort()),
        if (progress.isNotEmpty) 'pg': progress,
        if (cleared.isNotEmpty)
          'cl': {
            for (final e in cleared.entries) e.key: (e.value.toList()..sort())
          },
        if (done.isNotEmpty)
          'dn': {
            for (final e in done.entries) e.key: (e.value.toList()..sort())
          },
      };

  static WorldEventsState fromJson(Object? raw) {
    if (raw is! Map) return const WorldEventsState();
    int i(Object? v) => v is num ? v.round() : 0;
    Map<String, Set<String>> sets(Object? r) => {
          if (r case final Map m)
            for (final e in m.entries)
              if (e.key is String && e.value is List)
                e.key as String: {
                  for (final x in e.value as List)
                    if (x is String) x
                }
        };
    return WorldEventsState(
      seed: i(raw['s']),
      last: i(raw['l']),
      active: [
        if (raw['a'] case final List l)
          for (final a in l)
            if (ActiveWorldEvent.fromJson(a) case final x?) x
      ],
      seen: {
        if (raw['sn'] case final List l)
          for (final s in l)
            if (s is String) s
      },
      progress: {
        if (raw['pg'] case final Map m)
          for (final e in m.entries)
            if (e.key is String && e.value is num)
              e.key as String: (e.value as num).round()
      },
      cleared: sets(raw['cl']),
      done: sets(raw['dn']),
    );
  }

  @override
  bool operator ==(Object other) {
    final o = other;
    if (o is! WorldEventsState) return false;
    if (o.seed != seed || o.last != last) return false;
    if (o.active.length != active.length || o.seen.length != seen.length) {
      return false;
    }
    for (var k = 0; k < active.length; k++) {
      if (o.active[k] != active[k]) return false;
    }
    if (!o.seen.containsAll(seen)) return false;
    if (o.progress.length != progress.length ||
        o.cleared.length != cleared.length ||
        o.done.length != done.length) {
      return false;
    }
    for (final e in done.entries) {
      final x = o.done[e.key];
      if (x == null || x.length != e.value.length || !x.containsAll(e.value)) {
        return false;
      }
    }

    for (final e in progress.entries) {
      if (o.progress[e.key] != e.value) return false;
    }
    for (final e in cleared.entries) {
      final x = o.cleared[e.key];
      if (x == null || x.length != e.value.length || !x.containsAll(e.value)) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(seed, last, Object.hashAll(active), Object.hashAllUnordered(seen));
}
