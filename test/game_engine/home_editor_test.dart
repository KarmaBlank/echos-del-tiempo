import 'package:echos_del_tiempo/game_engine/data/construction_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/home_furniture_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/home_layout.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/home_interior_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/session_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/sky_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/town_rules.dart';
import 'package:echos_del_tiempo/game_engine/serialization/action_json.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// EDITAR CASA: furniture, walls, floors, paint and daylight
/// (docs/specs/player_house.md § 8).
void main() {
  final errors = <String>[];
  setUp(() {
    errors.clear();
    SessionEngine.onRuleError = (rule, e, st) => errors.add('$rule: $e');
  });
  tearDown(() {
    SessionEngine.onRuleError = null;
    expect(errors, isEmpty);
  });

  const town = TownState();
  PlayerProfile rich([int credits = 9000]) =>
      newProfile('Ana', 'guerrero').copyWith(credits: credits);
  const empty = HomeLayout(pieces: [HomePiece(1, 'bed_basic', 1, 1)]);

  test('every piece and surface has a level, a gold cost and a sprite', () {
    for (final f in kHomeFurniture) {
      expect(HomeInteriorRules.levelOf(f.id), greaterThanOrEqualTo(1));
      expect(HomeInteriorRules.costOf(f.id).gold, greaterThan(0), reason: f.id);
      expect(f.sprite, 'home_${f.id}');
    }
    for (final s in kHomeSurfaces) {
      final c = HomeInteriorRules.costOf(s.id);
      if (s.mat.isNotEmpty) expect(c.mats[s.mat], greaterThan(0), reason: s.id);
    }
    expect(HomeInteriorRules.paintGold, greaterThan(0));
  });

  test('the default layout fits: four beds and a window, all reachable', () {
    final beds = kDefaultHomeLayout.pieces
        .where((p) => furniture(p.id)?.kind == FurnitureKind.bed);
    expect(beds, hasLength(4));
    for (final p in kDefaultHomeLayout.pieces) {
      expect(
          HomeInteriorRules.cannotPlace(kDefaultHomeLayout, p.id, p.x, p.y,
              moving: p.uid),
          isNull,
          reason: p.id);
    }
  });

  test('placement: inside, off the door, never overlapping, never walling in',
      () {
    String? why(String id, int x, int y, [HomeLayout l = empty]) =>
        HomeInteriorRules.cannotPlace(l, id, x, y);
    expect(why('table', 4, 3), isNull);
    expect(why('table', 0, 3), 'Fuera de la casa');
    expect(why('table', 10, 3), 'Fuera de la casa');
    expect(why('plant', 5, 6), 'Tapa la puerta');
    expect(why('plant', 1, 2), 'Se pisa con otro mueble');
    // Wall pieces only on the back wall; floor pieces never there.
    expect(why('window', 3, 0), isNull);
    expect(why('window', 3, 2), 'Va en la pared del fondo');
    expect(why('plant', 3, 0), 'Fuera de la casa');
    // A wall piece and a bed under it do not collide (other layer).
    expect(why('picture_meadow', 1, 0), isNull);
    // The rug is walkable: it never walls anything in.
    expect(why('rug', 2, 3), isNull);
    // Closing a corner off is refused.
    const corner = HomeLayout(pieces: [
      HomePiece(1, 'bed_basic', 5, 1),
      HomePiece(2, 'plant', 2, 1),
    ]);
    expect(why('plant', 1, 2, corner), 'Así queda un rincón sin paso');
  });

  test('buying: town level gates the piece, then gold and materials pay', () {
    expect(HomeInteriorRules.level(town), 1);
    expect(HomeInteriorRules.levelOf('bed_canopy'), greaterThan(1));
    expect(HomeInteriorRules.cannotBuy(rich(), town, 'bed_canopy'),
        startsWith('Necesita el pueblo en nivel'));
    expect(HomeInteriorRules.cannotBuy(rich(0), town, 'plant'), isNotNull);
    final p = rich().copyWith(home: empty);
    final r = HomeInteriorRules.placePiece(p, town, 'plant', 4, 4);
    expect(r.error, isNull);
    expect(r.profile!.credits, 9000 - HomeInteriorRules.costOf('plant').gold);
    expect(r.profile!.home.pieces.last.id, 'plant');
    expect(r.profile!.home.pieces.last.uid, 2);
    // A material wall needs its level (and its craft material).
    expect(HomeInteriorRules.costOf('wall_stone').mats, isNotEmpty);
    expect(HomeInteriorRules.surface(p, town, 'wall_stone').profile, isNull);
  });

  test('move, remove (a bed always stays), surface, paint and rack', () {
    var p = rich().copyWith(home: empty);
    p = HomeInteriorRules.placePiece(p, town, 'table', 4, 3).profile!;
    final uid = p.home.pieces.last.uid;
    expect(HomeInteriorRules.move(p, uid, 1, 1), isNull); // over the bed
    p = HomeInteriorRules.move(p, uid, 6, 4)!;
    expect((p.home.piece(uid)!.x, p.home.piece(uid)!.y), (6, 4));
    expect(HomeInteriorRules.cannotRemove(p.home, 1),
        'Tiene que quedar una cama');
    p = HomeInteriorRules.remove(p, uid)!;
    expect(p.home.piece(uid), isNull);
    // Same floor again: refused; plaster is free.
    expect(HomeInteriorRules.surface(p, town, 'floor_planks').error,
        'Ya está puesto');
    final before = p.credits;
    p = HomeInteriorRules.paint(p, 2)!;
    expect(p.home.paint, 2);
    expect(p.credits, before - HomeInteriorRules.paintGold);
    expect(HomeInteriorRules.cannotPaint(p, 2), 'Ya está puesto');
    // A rack keeps up to three weapons the owner really has.
    p = HomeInteriorRules.placePiece(p, town, 'table', 4, 3).profile!;
    expect(HomeInteriorRules.rack(p, p.home.pieces.last.uid, const []), isNull);
  });

  test('layout and the edit action survive JSON', () {
    const l = HomeLayout(
        pieces: [
          HomePiece(1, 'bed_basic', 1, 1),
          HomePiece(3, 'weapon_rack', 4, 3, weapons: ['w1', 'w2']),
        ],
        wall: 'wall_wood',
        floor: 'floor_stone',
        paint: 3);
    final back = HomeLayout.fromJson(l.toJson())!;
    expect(back.key, l.key);
    expect(back.nextUid, 4);
    final p = rich().copyWith(home: l);
    expect(PlayerProfile.fromJson(p.toJson()).home.key, l.key);
    // The default layout is left out of the profile JSON.
    expect(rich().toJson().containsKey('hl'), isFalse);
    const a = HomeEditAction(HomeOp.place, id: 'plant', x: 3, y: 4);
    final b = ActionJson.fromJson(ActionJson.toJson(a)) as HomeEditAction;
    expect((b.op, b.id, b.x, b.y), (HomeOp.place, 'plant', 3, 4));
    const r = HomeEditAction(HomeOp.rack, uid: 3, weapons: ['a']);
    final rb = ActionJson.fromJson(ActionJson.toJson(r)) as HomeEditAction;
    expect(rb.uid, 3);
    expect(rb.weapons, ['a']);
  });

  test('only the owner inside the house edits it, through the engine', () {
    final e = sessionEngine();
    var s = e.create();
    s = e.addPlayer(s, 'p0', rich())!.state;
    s = e.addPlayer(s, 'p1', rich())!.state;
    TownState? t;
    for (var y = 2; y < 24 && t == null; y++) {
      for (var x = 2; x < 34 && t == null; x++) {
        t = TownRules.place(s.town, kPlayerHouseId, x, y).town;
      }
    }
    s.town = t!;
    const place = HomeEditAction(HomeOp.place, id: 'plant', x: 4, y: 4);
    // Out of the house: refused.
    expect(e.apply(s, 'p0', place), isNull);
    s = act(e, s, 'p0', const TravelAction(HomeInteriorRules.place));
    expect(HomeInteriorRules.layoutOwner(s), 'p0');
    expect(e.apply(s, 'p1', place), isNull);
    s = act(e, s, 'p0', place);
    final home = s.players['p0']!.profile.home;
    expect(home.pieces.last.id, 'plant');
    expect(HomeInteriorRules.layoutOf(s).key, home.key);
    // The room map follows the layout: the plant is solid.
    expect(HomeInteriorRules.rowsOf(home)[4][4], 'C');
  });

  test('windows light the floor by day and not at night', () {
    final day = SkyRules.start(() => 0.5).copyWith(clock: SkyRules.daySec * 0.4);
    final night = day.copyWith(clock: SkyRules.daySec + 60);
    expect(HomeInteriorRules.daylight(kDefaultHomeLayout, day), isNotEmpty);
    expect(HomeInteriorRules.daylight(kDefaultHomeLayout, night), isEmpty);
    expect(HomeInteriorRules.daylight(empty, day), isEmpty);
  });
}
