import 'dart:math' as math;

import '../data/fishing_catalog.dart';
import '../data/tuning_catalog.dart';
import '../models/player_profile.dart';
import '../models/player_stall.dart';
import 'farming_rules.dart';
import 'life_give_rules.dart';
import 'life_time_rules.dart';
import 'mining_rules.dart';
import 'weather_rules.dart';

/// Why a stall operation is refused (player_shop.md § 3).
enum StallBlock { unknown, amount, missing, price, full, own, gold, bagFull }

/// The player's own stall (docs/specs/player_shop.md): listing goods at
/// the owner's prices, teammates buying and the daily town visitors.
/// Pure Dart; the host validates inside `SessionEngine`.
abstract final class StallRules {
  static const kinds = ['fish', 'crop', 'ore'];

  /// Price presets the UI offers over the reference (§ 3).
  static const priceSteps = [0.8, 1.0, 1.25, 1.5, 2.0];

  static TuningDef get t => tuning(TuningId.town);

  static int get slots => math.max(1, t.i('stallSlots'));
  static int get logCap => math.max(1, t.i('stallLogCap'));

  static String? _kind(String cell) {
    final i = cell.indexOf(':');
    if (i <= 0) return null;
    final k = cell.substring(0, i);
    return kinds.contains(k) ? k : null;
  }

  /// Reference price of one unit of [cell] (0 = cannot be listed).
  static int refPrice(String cell) {
    final kind = _kind(cell);
    if (kind == null) return 0;
    final id = cell.substring(kind.length + 1);
    return switch (kind) {
      'fish' => kFish[id] == null || kFish[id]!.biome == kWaterJunkBiome
          ? 0
          : kFish[id]!.price,
      'crop' => switch (parseCropKey(id)) {
          (final c, final q)? =>
            (c.price * FarmingRules.t.d('qualityMult${q.key}')).round(),
          null => 0,
        },
      _ => SmithCraftRules.sellPrice(id),
    };
  }

  /// Visitor demand for [cell] in [season] (crops follow the trader's
  /// season price; the rest is 1).
  static double demand(String cell, Season season) {
    if (!cell.startsWith('crop:')) return 1;
    final c = parseCropKey(cell.substring(5));
    return c == null ? 1 : LifeTimeRules.seasonPrice(c.$1.id, season);
  }

  /// Highest price allowed for [cell].
  static int maxPrice(String cell) =>
      math.max(1, (refPrice(cell) * t.d('stallMaxMarkup')).round());

  /// The preset price [step] × reference, within the allowed range.
  static int stepPrice(String cell, double step) =>
      (refPrice(cell) * step).round().clamp(1, maxPrice(cell));

  /// Why [p] cannot list [qty] of [cell] at [price] (`qty == 0` only
  /// changes the price of an existing listing).
  static StallBlock? listBlock(
      PlayerProfile p, String cell, int qty, int price) {
    if (refPrice(cell) <= 0) return StallBlock.unknown;
    if (qty < 0) return StallBlock.amount;
    if (price < 1 || price > maxPrice(cell)) return StallBlock.price;
    final st = p.life.stall;
    final cur = st.listing(cell);
    if (qty == 0 && cur == null) return StallBlock.amount;
    if (LifeGiveRules.have(p, cell) < qty) return StallBlock.missing;
    if (cur == null && st.listings.length >= slots) return StallBlock.full;
    return null;
  }

  /// [p] with [qty] of [cell] moved from the bag into the stall at
  /// [price]; `null` if [listBlock] refuses.
  static PlayerProfile? list(
      PlayerProfile p, String cell, int qty, int price) {
    if (listBlock(p, cell, qty, price) != null) return null;
    final st = p.life.stall;
    final cur = st.listing(cell);
    final next = StallListing(cell, (cur?.qty ?? 0) + qty, price);
    final listings = [
      for (final l in st.listings) l.cell == cell ? next : l,
      if (cur == null) next,
    ];
    final q = LifeGiveRules.add(p, cell, -qty);
    return q.copyWith(
        life: q.life.copyWith(stall: st.copyWith(listings: listings)));
  }

  /// [p] with the listing of [cell] back in the bag; `null` if none.
  static PlayerProfile? unlist(PlayerProfile p, String cell) {
    final st = p.life.stall;
    final cur = st.listing(cell);
    if (cur == null) return null;
    final q = LifeGiveRules.add(p, cell, cur.qty);
    return q.copyWith(
        life: q.life.copyWith(
            stall: st.copyWith(listings: [
      for (final l in st.listings)
        if (l.cell != cell) l
    ])));
  }

  /// Why [buyer] cannot buy [n] of [cell] from [owner].
  static StallBlock? buyBlock(PlayerProfile owner, PlayerProfile buyer,
      String cell, int n, {bool same = false}) {
    if (same) return StallBlock.own;
    final l = owner.life.stall.listing(cell);
    if (l == null) return StallBlock.missing;
    if (n < 1 || n > l.qty) return StallBlock.amount;
    if (buyer.credits < l.price * n) return StallBlock.gold;
    if (!LifeGiveRules.fits(buyer, cell, n)) return StallBlock.bagFull;
    return null;
  }

  /// [owner] after selling [n] of its listing [cell] for [gold] to
  /// [buyer] (empty = visitor) on [day].
  static PlayerProfile _sold(
      PlayerProfile owner, String cell, int n, int gold, String buyer, int day) {
    final st = owner.life.stall;
    final log = [...st.log, StallSale(day, cell, n, gold, buyer)];
    final listings = [
      for (final l in st.listings)
        l.cell == cell ? StallListing(cell, l.qty - n, l.price) : l,
    ];
    return owner.copyWith(
        credits: owner.credits + gold,
        life: owner.life.copyWith(
            stall: st.copyWith(
                listings: listings,
                log: log.length > logCap
                    ? log.sublist(log.length - logCap)
                    : log,
                earned: st.earned + gold)));
  }

  /// A teammate buys: `(owner, buyer)` after the trade, or `null`.
  static (PlayerProfile, PlayerProfile)? buy(PlayerProfile owner,
      PlayerProfile buyer, String cell, int n,
      {required String buyerName, required int day}) {
    if (buyBlock(owner, buyer, cell, n) != null) return null;
    final gold = owner.life.stall.listing(cell)!.price * n;
    final b = LifeGiveRules.add(buyer.copyWith(credits: buyer.credits - gold),
        cell, n);
    return (_sold(owner, cell, n, gold, buyerName, day), b);
  }

  /// Chance that one visitor buys [l] in [season] (§ 3).
  static double chance(StallListing l, Season season) {
    final ref = refPrice(l.cell) * demand(l.cell, season);
    if (ref <= 0 || l.price <= 0) return 0;
    return (t.d('stallBaseChance') *
            math.pow(ref / l.price, t.d('stallElasticity')))
        .clamp(0.0, t.d('stallMaxChance'))
        .toDouble();
  }

  /// The visitors of world [day] (§ 3): `(profile, sales)`. A day not
  /// after `stall.day` sells nothing (and returns [p] unchanged).
  static (PlayerProfile, List<StallSale>) visitDay(
      PlayerProfile p, int day, double Function() rand) {
    final st0 = p.life.stall;
    if (day <= st0.day) return (p, const []);
    // An empty stall is not stamped: the profile stays untouched.
    if (st0.listings.isEmpty) return (p, const []);
    var q = p.copyWith(life: p.life.copyWith(stall: st0.copyWith(day: day)));
    final season = WeatherRules.season(day);
    final sales = <StallSale>[];
    for (var v = 0; v < math.max(0, t.i('stallVisitors')); v++) {
      final open = q.life.stall.listings;
      if (open.isEmpty) break;
      final l = open[(rand() * open.length).floor().clamp(0, open.length - 1)];
      if (rand() >= chance(l, season)) continue;
      final n = math.min(
          l.qty, 1 + (rand() * math.max(1, t.i('stallMaxBuy'))).floor());
      final gold = l.price * n;
      q = _sold(q, l.cell, n, gold, '', day);
      sales.add(StallSale(day, l.cell, n, gold, ''));
    }
    return (q, sales);
  }
}
