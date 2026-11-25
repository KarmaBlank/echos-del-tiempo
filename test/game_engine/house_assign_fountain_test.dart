import 'package:echos_del_tiempo/game_engine/data/construction_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/resident_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/town_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// ASIGNAR CASAS from the rune fountain (town_editor.md § 1.1).
void main() {
  TownState withHouse(TownState town) {
    for (var y = 2; y < 20; y++) {
      for (var x = 2; x < 30; x++) {
        final t = TownRules.place(town, kCasaId, x, y).town;
        if (t != null) return t;
      }
    }
    fail('no house spot');
  }

  test('awaitingHouse lists invited residents without a house', () {
    expect(ResidentRules.awaitingHouse(const TownState()), isEmpty);
    var town = ResidentRules.invite(
        const TownState().withResident(const ResidentState('ilda', rep: 3)),
        'ilda',
        time: 1)!;
    town = withHouse(town);
    expect(ResidentRules.awaitingHouse(town).map((n) => n.id), ['ilda']);
    final free = ResidentRules.freeHouses(town).single;
    town = ResidentRules.assign(town, 'ilda', free.id)!;
    expect(ResidentRules.awaitingHouse(town), isEmpty);
    expect(ResidentRules.freeHouses(town), isEmpty);
  });
}
