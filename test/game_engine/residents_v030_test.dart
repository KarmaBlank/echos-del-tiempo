import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/construction_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/resident_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/town_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// Habitantes en el pueblo (overworld_biomes.md § 10, roles.md).
void main() {
  test('invitar, casa, beneficio, órdenes y guardado', () {
    var town = const TownState()
        .withResident(const ResidentState('ilda', rep: 3));
    expect(ResidentRules.cannotInvite(town, 'ilda'), isNull);
    town = ResidentRules.invite(town, 'ilda')!;
    expect(ResidentRules.bonus(town, NpcRole.herbolaria), 0);
    // Una casa en un lugar libre del pueblo.
    TownState? placed;
    for (var y = 2; y < 20 && placed == null; y++) {
      for (var x = 2; x < 30 && placed == null; x++) {
        placed = TownRules.place(town, kCasaId, x, y).town;
      }
    }
    expect(placed, isNotNull);
    final casa = placed!.houses.single;
    town = ResidentRules.assign(placed, 'ilda', casa.id)!;
    expect(town.resident('ilda').house, 1);
    expect(ResidentRules.bonus(town, NpcRole.herbolaria),
        ResidentRules.benefit(NpcRole.herbolaria, 0));
    town = ResidentRules.onDayAll(town, 5, fishLv: 30, farmLv: 30);
    final r = town.resident('ilda');
    expect(r.order, isNotNull);
    expect(r.request, ResidentRequest.casa);
    final back = TownState.fromJson(town.toJson());
    expect(back.resident('ilda'), r);
    expect(back.houseOf('ilda')?.id, casa.id);
    // Sin la casa, sin beneficio.
    final gone = ResidentRules.sync(
        town.copyWith(builds: [...town.builds.where((b) => b.id != casa.id)]));
    expect(gone.resident('ilda').house, 0);
    expect(ResidentRules.tier(gone.resident('ilda')), -1);
  });

  test('cadenas de 3 a 4 pasos con objeto único al final', () {
    for (final n in kBiomeNpcs) {
      final c = kResidentQuests[n.id]!;
      expect(c.length, inInclusiveRange(2, 4), reason: n.id);
      expect(kResidentRelics.containsKey(c.last.reward), isTrue, reason: n.id);
    }
  });
}
