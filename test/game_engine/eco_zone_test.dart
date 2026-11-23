import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/eco.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/rules/eco_portal_rules.dart';
import 'package:echos_del_tiempo/game_engine/serialization/action_json.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ecos_session_test.dart' show endgamer, lobby, atPortal;
import 'session_test_helpers.dart';

/// Ecos por zona (docs/specs/ecos_zone.md).
const _eco = EcoItem(
  uid: 'x',
  tier: 3,
  zone: 4,
  boss: 1,
  rarity: Rarity.comun,
  mods: [],
  floors: 1,
  seed: 3,
);

void main() {
  test('un portal por zona, en el exterior de su bioma', () {
    expect(EcoPortalRules.all.map((s) => s.zone), [for (var z = 1; z <= 10; z++) z]);
    for (final s in EcoPortalRules.all) {
      final lay = biomeLayout(s.biome)!;
      final rows = lay.rows(const {});
      for (var dx = -1; dx <= 1; dx++) {
        expect(rows[s.y][s.x + dx], Tile.portal, reason: 'zona ${s.zone}');
        expect(rows[s.y + 1][s.x + dx], Tile.path);
      }
      expect(s.x % 3, 1);
      expect(EcoPortalRules.near(s.biome, s.front.x, s.front.y), s.zone);
      expect(EcoPortalRules.near(null, s.front.x, s.front.y), isNull);
    }
  });

  test('tiers por personaje: T1 con el jefe, T(n+1) al completar Tn', () {
    final p = PlayerProfile(name: 'A', classId: 'guerrero');
    final q = p.copyWith(unlockedZone: 5);
    expect(EcoPortalRules.unlockedTier(q, 4), 1);
    expect(EcoPortalRules.unlockedTier(q, 5), 0);
    expect(EcoPortalRules.lockReason(q, 5, 1, zoneName: 'X'),
        contains('Vencé al jefe de X'));
    expect(EcoPortalRules.lockReason(q, 4, 2), contains('Eco T1'));
    final r = EcoPortalRules.recordCompleted(q, 4, 1);
    expect(EcoPortalRules.unlockedTier(r, 4), 2);
    expect(EcoPortalRules.recordCompleted(r, 4, 1), same(r));
    final back = PlayerProfile.fromJson(r.toJson());
    expect(back.ecoTiers, {4: 1});
    expect(EcoPortalRules.unlockedTier(
        q.copyWith(unlockedZone: 10), 10), 0, reason: 'zona 10: Devorador');
  });

  test('el host solo acepta abrir frente al portal de la zona del Eco', () {
    final e = sessionEngine(zones: true);
    final s = lobby(e, [endgamer('Ana', ecos: [_eco])]);
    final uid = s.players['p0']!.profile.ecos.single.uid;
    expect(e.apply(s, 'p0', ProposeEcoAction(uid)), isNull,
        reason: 'desde el pueblo no');
    // En otro portal (zona 3, mismo bioma) tampoco.
    final other = EcoPortalRules.of(3)!;
    s
      ..place = other.biome
      ..players['p0']!.x = other.front.x
      ..players['p0']!.y = other.front.y;
    expect(e.apply(s, 'p0', ProposeEcoAction(uid)), isNull);
    final ok = e.apply(atPortal(s, 'p0', uid), 'p0', ProposeEcoAction(uid));
    expect(ok?.state.vote?.missionId, 'eco');
    // Tier cerrado: no.
    final p = s.players['p0']!;
    p.profile = p.profile.copyWith(ecoTiers: {4: 1});
    expect(e.apply(s, 'p0', ProposeEcoAction(uid)), isNull);
  });

  test('viajar con ecoZone deja frente al portal', () {
    final e = sessionEngine(zones: true);
    var s = lobby(e, [endgamer('Ana')]);
    final spot = EcoPortalRules.of(4)!;
    expect(e.apply(s, 'p0', TravelAction(spot.biome, ecoZone: 3)), isNull,
        reason: 'la zona 3 no está en ese bioma');
    s = e.apply(s, 'p0', TravelAction(spot.biome, ecoZone: 4))!.state;
    expect(s.place, spot.biome);
    expect(EcoPortalRules.near(s.place, s.players['p0']!.x,
        s.players['p0']!.y), 4);
    final j = ActionJson.toJson(TravelAction(spot.biome, ecoZone: 4));
    expect((ActionJson.fromJson(j) as TravelAction).ecoZone, 4);
  });
}
