/// The player's own stall (docs/specs/player_shop.md § 3-4): what is on
/// sale at the owner's prices, the sales log, total earned and the last
/// world day the visitors were served. JSON `ps` inside `life`.
class PlayerStall {
  PlayerStall({
    List<StallListing> listings = const [],
    List<StallSale> log = const [],
    this.earned = 0,
    this.day = 0,
  })  : listings = List.unmodifiable(listings.where((l) => l.qty > 0)),
        log = List.unmodifiable(log);

  static final empty = PlayerStall();

  final List<StallListing> listings;

  /// Newest last.
  final List<StallSale> log;
  final int earned;
  final int day;

  bool get isEmpty => listings.isEmpty && log.isEmpty && earned == 0 && day == 0;

  StallListing? listing(String cell) {
    for (final l in listings) {
      if (l.cell == cell) return l;
    }
    return null;
  }

  PlayerStall copyWith({
    List<StallListing>? listings,
    List<StallSale>? log,
    int? earned,
    int? day,
  }) =>
      PlayerStall(
          listings: listings ?? this.listings,
          log: log ?? this.log,
          earned: earned ?? this.earned,
          day: day ?? this.day);

  Map<String, Object?> toJson() => {
        if (listings.isNotEmpty)
          'l': [for (final l in listings) [l.cell, l.qty, l.price]],
        if (log.isNotEmpty)
          'g': [
            for (final s in log) [s.day, s.cell, s.qty, s.gold, s.buyer]
          ],
        if (earned > 0) 'e': earned,
        if (day > 0) 'd': day,
      };

  static PlayerStall fromJson(Object? raw) {
    if (raw is! Map) return empty;
    int n(Object? v) => v is num && v.isFinite ? v.truncate() : 0;
    final l = raw['l'], g = raw['g'];
    return PlayerStall(
      listings: [
        if (l is List)
          for (final x in l)
            if (x is List &&
                x.length == 3 &&
                x[0] is String &&
                n(x[1]) > 0 &&
                n(x[2]) > 0)
              StallListing(x[0] as String, n(x[1]), n(x[2])),
      ],
      log: [
        if (g is List)
          for (final x in g)
            if (x is List &&
                x.length == 5 &&
                x[1] is String &&
                x[4] is String &&
                n(x[2]) > 0)
              StallSale(n(x[0]), x[1] as String, n(x[2]), n(x[3]),
                  x[4] as String),
      ],
      earned: n(raw['e']),
      day: n(raw['d']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PlayerStall &&
      other.earned == earned &&
      other.day == day &&
      _listEq(other.listings, listings) &&
      _listEq(other.log, log);

  static bool _listEq(List a, List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(earned, day, listings.length, log.length);
}

/// [qty] units of the profession cell [cell] on sale at [price] each.
class StallListing {
  const StallListing(this.cell, this.qty, this.price);
  final String cell;
  final int qty;
  final int price;

  @override
  bool operator ==(Object other) =>
      other is StallListing &&
      other.cell == cell &&
      other.qty == qty &&
      other.price == price;

  @override
  int get hashCode => Object.hash(cell, qty, price);
}

/// One sale: world [day], what, how many, gold earned and [buyer] (empty
/// = a town visitor, else the teammate's name).
class StallSale {
  const StallSale(this.day, this.cell, this.qty, this.gold, this.buyer);
  final int day;
  final String cell;
  final int qty;
  final int gold;
  final String buyer;

  bool get byVisitor => buyer.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is StallSale &&
      other.day == day &&
      other.cell == cell &&
      other.qty == qty &&
      other.gold == gold &&
      other.buyer == buyer;

  @override
  int get hashCode => Object.hash(day, cell, qty, gold, buyer);
}
