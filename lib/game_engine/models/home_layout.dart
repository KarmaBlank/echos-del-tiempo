/// The inside of a player's house (player_house.md § 8): furniture, wall
/// and floor materials and the wall paint. Saved in the player's profile
/// (JSON `hl`), so it travels with the profile in co-op.
class HomePiece {
  const HomePiece(this.uid, this.id, this.x, this.y,
      {this.weapons = const []});

  /// Number of the piece in its layout (stable).
  final int uid;

  /// Furniture id (`kHomeFurniture`).
  final String id;

  /// Top-left tile in the room.
  final int x, y;

  /// Weapon rack: uids of the weapons it shows (at most 3).
  final List<String> weapons;

  HomePiece copyWith({int? x, int? y, List<String>? weapons}) => HomePiece(
      uid, id, x ?? this.x, y ?? this.y,
      weapons: weapons ?? this.weapons);

  List<Object?> toJson() =>
      [uid, id, x, y, if (weapons.isNotEmpty) weapons];

  static HomePiece? fromJson(Object? raw) {
    if (raw is! List || raw.length < 4) return null;
    final [uid, id, x, y, ...] = raw;
    if (uid is! int || id is! String || x is! int || y is! int) return null;
    final w = raw.length > 4 && raw[4] is List
        ? [
            for (final v in raw[4] as List)
              if (v is String) v
          ]
        : const <String>[];
    return HomePiece(uid, id, x, y, weapons: w.take(3).toList());
  }

  @override
  bool operator ==(Object other) =>
      other is HomePiece &&
      other.uid == uid &&
      other.id == id &&
      other.x == x &&
      other.y == y &&
      other.weapons.join(',') == weapons.join(',');

  @override
  int get hashCode => Object.hash(uid, id, x, y, weapons.join(','));
}

class HomeLayout {
  const HomeLayout(
      {this.pieces = kDefaultHomePieces,
      this.wall = 'wall_plaster',
      this.floor = 'floor_planks',
      this.paint = 0});

  final List<HomePiece> pieces;
  final String wall, floor;

  /// Index in `kHomePaints` (0 = the material's colour).
  final int paint;

  int get nextUid =>
      pieces.fold(0, (a, p) => p.uid >= a ? p.uid + 1 : a);

  HomePiece? piece(int uid) =>
      pieces.where((p) => p.uid == uid).firstOrNull;

  HomeLayout copyWith(
          {List<HomePiece>? pieces, String? wall, String? floor, int? paint}) =>
      HomeLayout(
          pieces: pieces ?? this.pieces,
          wall: wall ?? this.wall,
          floor: floor ?? this.floor,
          paint: paint ?? this.paint);

  /// Stable text of the layout (map cache key).
  String get key => [
        wall,
        floor,
        paint,
        for (final p in pieces) '${p.uid}:${p.id}:${p.x}.${p.y}',
      ].join('|');

  Map<String, Object?> toJson() => {
        'p': [for (final p in pieces) p.toJson()],
        if (wall != 'wall_plaster') 'w': wall,
        if (floor != 'floor_planks') 'f': floor,
        if (paint != 0) 'c': paint,
      };

  static HomeLayout? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final p = raw['p'];
    return HomeLayout(
      pieces: p is List
          ? [
              for (final x in p)
                if (HomePiece.fromJson(x) case final h?) h
            ]
          : kDefaultHomePieces,
      wall: raw['w'] is String ? raw['w'] as String : 'wall_plaster',
      floor: raw['f'] is String ? raw['f'] as String : 'floor_planks',
      paint: raw['c'] is int ? raw['c'] as int : 0,
    );
  }

  @override
  bool operator ==(Object other) => other is HomeLayout && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

/// A new house: four basic beds along the back wall, a window and the
/// stash chest (the phase 1 room).
const kDefaultHomePieces = <HomePiece>[
  HomePiece(0, 'bed_basic', 1, 1),
  HomePiece(1, 'bed_basic', 3, 1),
  HomePiece(2, 'bed_basic', 6, 1),
  HomePiece(3, 'bed_basic', 8, 1),
  HomePiece(4, 'window', 4, 0),
];

const kDefaultHomeLayout = HomeLayout();
