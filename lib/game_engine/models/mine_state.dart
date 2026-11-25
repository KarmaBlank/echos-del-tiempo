import 'town_build.dart' show HelperStat;

/// Where a mine level's cart is (docs/specs/mining_smithing.md § 1.8).
enum CartPhase {
  /// At the mine station, being filled by the miners.
  mine,

  /// Full and rolling to town; arrives at `t + cartTravelSec`.
  toTown,

  /// Parked at the town cart station, waiting to be unloaded.
  town,

  /// Unloaded at `t`, rolling back to its mine.
  back,
}

/// The cart of one mine level: where it is, since when ([t], room
/// seconds) and what it carries.
class MineCart {
  const MineCart(
      {this.phase = CartPhase.mine, this.t = 0, this.load = const {}});

  final CartPhase phase;
  final double t;
  final Map<String, int> load;

  int get total => load.values.fold(0, (a, b) => a + b);

  MineCart copyWith({CartPhase? phase, double? t, Map<String, int>? load}) =>
      MineCart(
          phase: phase ?? this.phase, t: t ?? this.t, load: load ?? this.load);

  Map<String, Object?> toJson() => {
        if (phase != CartPhase.mine) 'p': phase.index,
        if (t != 0) 't': (t * 10).round() / 10,
        if (load.isNotEmpty) 'o': load,
      };

  static MineCart fromJson(Object? raw) {
    if (raw is! Map) return const MineCart();
    final p = raw['p'];
    return MineCart(
      phase: p is num && p >= 0 && p < CartPhase.values.length
          ? CartPhase.values[p.toInt()]
          : CartPhase.mine,
      t: raw['t'] is num ? (raw['t'] as num).toDouble() : 0,
      load: _ints(raw['o']),
    );
  }
}

/// A hired miner working a level (§ 1.7): tile, dig progress on the tile
/// it is breaking, tiles dug since its last torch and its helper stats.
class MinerState {
  const MinerState(this.x, this.y,
      {this.work = 0,
      this.sinceTorch = 0,
      this.stat = const HelperStat(),
      this.tier = 0});

  final int x, y;

  /// Pick tier of this miner (0–4, § 1.7): it only breaks what a pick of
  /// that tier breaks.
  final int tier;
  final int work;
  final int sinceTorch;
  final HelperStat stat;

  MinerState copyWith(
          {int? x,
          int? y,
          int? work,
          int? sinceTorch,
          HelperStat? stat,
          int? tier}) =>
      MinerState(x ?? this.x, y ?? this.y,
          work: work ?? this.work,
          sinceTorch: sinceTorch ?? this.sinceTorch,
          stat: stat ?? this.stat,
          tier: tier ?? this.tier);

  Map<String, Object?> toJson() => {
        'x': x,
        'y': y,
        if (work != 0) 'w': work,
        if (sinceTorch != 0) 's': sinceTorch,
        if (stat.xp != 0 || stat.ups.isNotEmpty) 'st': stat.toJson(),
        if (tier != 0) 'pt': tier,
      };

  static MinerState? fromJson(Object? raw) {
    if (raw is! Map || raw['x'] is! num || raw['y'] is! num) return null;
    return MinerState((raw['x'] as num).toInt(), (raw['y'] as num).toInt(),
        work: raw['w'] is num ? (raw['w'] as num).toInt() : 0,
        sinceTorch: raw['s'] is num ? (raw['s'] as num).toInt() : 0,
        stat: HelperStat.fromJson(raw['st']),
        tier: raw['pt'] is num ? (raw['pt'] as num).toInt().clamp(0, 4) : 0);
  }
}

/// What changed in one mine level of this world (§ 1.5): saved with the
/// town (`mn`) and sent to everyone in the room, so the map is the same
/// for all. Tiles are indexes `y × width + x` of the generated level.
class MineLevelState {
  const MineLevelState({
    this.dug = const {},
    this.torches = const {},
    this.opened = const {},
    this.grown = const {},
    this.regrow = const {},
    this.station = false,
    this.miners = const [],
    this.cart = const MineCart(),
    this.known = const {},
  });

  /// Rock and veins broken (now floor). Tunnels never close.
  final Set<int> dug;

  /// Torches placed by players and miners.
  final Set<int> torches;

  /// Chests opened and mushroom patches picked.
  final Set<int> opened;

  /// Veins that grew back into intact rock (§ 1.5): tile → vein code.
  final Map<int, String> grown;

  /// Mined veins waiting to grow back: original tile → room second when
  /// due. They grow only out of sight (`MineWorkRules.regrowTick`).
  final Map<int, double> regrow;

  /// The cart station of this level is built.
  final bool station;
  final List<MinerState> miners;
  final MineCart cart;

  /// Veins each player discovered (§ 1.11), by profile name: tile
  /// indexes shown on that player's minimap while still a vein. A vein
  /// that grows back elsewhere must be found again.
  final Map<String, Set<int>> known;

  /// Veins [who] discovered.
  Set<int> knownBy(String who) => known[who] ?? const {};

  bool get isEmpty =>
      dug.isEmpty &&
      torches.isEmpty &&
      opened.isEmpty &&
      grown.isEmpty &&
      regrow.isEmpty &&
      !station &&
      miners.isEmpty &&
      known.isEmpty;

  MineLevelState copyWith({
    Set<int>? dug,
    Set<int>? torches,
    Set<int>? opened,
    Map<int, String>? grown,
    Map<int, double>? regrow,
    bool? station,
    List<MinerState>? miners,
    MineCart? cart,
    Map<String, Set<int>>? known,
  }) =>
      MineLevelState(
        dug: dug ?? this.dug,
        torches: torches ?? this.torches,
        opened: opened ?? this.opened,
        grown: grown ?? this.grown,
        regrow: regrow ?? this.regrow,
        station: station ?? this.station,
        miners: miners ?? this.miners,
        cart: cart ?? this.cart,
        known: known ?? this.known,
      );

  static List<int> _sorted(Set<int> s) => s.toList()..sort();

  Map<String, Object?> toJson() => {
        if (dug.isNotEmpty) 'd': _sorted(dug),
        if (torches.isNotEmpty) 'l': _sorted(torches),
        if (opened.isNotEmpty) 'op': _sorted(opened),
        if (grown.isNotEmpty)
          'g': {for (final k in _sorted(grown.keys.toSet())) '$k': grown[k]},
        if (regrow.isNotEmpty)
          'rg': {
            for (final k in _sorted(regrow.keys.toSet()))
              '$k': (regrow[k]! * 10).round() / 10
          },
        if (station) 'st': 1,
        if (miners.isNotEmpty) 'mi': [for (final m in miners) m.toJson()],
        if (cart.phase != CartPhase.mine || cart.load.isNotEmpty || cart.t != 0)
          'c': cart.toJson(),
        if (known.isNotEmpty)
          'k': {
            for (final k in (known.keys.toList()..sort()))
              if (known[k]!.isNotEmpty) k: _sorted(known[k]!)
          },
      };

  static Set<int> _set(Object? v) => v is List
      ? {
          for (final x in v)
            if (x is num) x.toInt()
        }
      : const {};

  static MineLevelState fromJson(Object? raw) {
    if (raw is! Map) return const MineLevelState();
    final g = raw['g'], rg = raw['rg'], mi = raw['mi'], kn = raw['k'];
    return MineLevelState(
      dug: _set(raw['d']),
      torches: _set(raw['l']),
      opened: _set(raw['op']),
      grown: g is Map
          ? {
              for (final e in g.entries)
                if (int.tryParse('${e.key}') case final k?)
                  if (e.value is String) k: e.value as String,
            }
          : const {},
      regrow: rg is Map
          ? {
              for (final e in rg.entries)
                if (int.tryParse('${e.key}') case final k?)
                  if (e.value is num) k: (e.value as num).toDouble(),
            }
          : const {},
      station: raw['st'] == 1 || raw['st'] == true,
      miners: mi is List
          ? [
              for (final m in mi)
                if (MinerState.fromJson(m) case final s?) s
            ]
          : const [],
      cart: MineCart.fromJson(raw['c']),
      known: kn is Map
          ? {
              for (final e in kn.entries)
                if (e.key is String) e.key as String: _set(e.value),
            }
          : const {},
    );
  }
}

Map<String, int> _ints(Object? v) => v is Map
    ? {
        for (final e in v.entries)
          if (e.value is num && (e.value as num) > 0)
            '${e.key}': (e.value as num).round()
      }
    : const {};

/// Every mine level of the world that changed, by place id
/// (`mine:<biome>:<i>` or `mine:<biome>:<i>:<level>`).
typedef MinesState = Map<String, MineLevelState>;

Map<String, Object?> minesToJson(MinesState m) => {
      for (final k in (m.keys.toList()..sort()))
        if (!m[k]!.isEmpty || m[k]!.cart.phase != CartPhase.mine) k: m[k]!.toJson(),
    };

MinesState minesFromJson(Object? raw) => raw is Map
    ? {
        for (final e in raw.entries)
          if (e.key is String) e.key as String: MineLevelState.fromJson(e.value),
      }
    : const {};
