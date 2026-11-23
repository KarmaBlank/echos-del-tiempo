import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/farming_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/fishing_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/rules/biome_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/map_generator.dart';
import 'package:echos_del_tiempo/game_engine/rules/resident_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cada exterior tiene datos válidos y un mapa jugable', () {
    for (final lay in kBiomeLayouts.values) {
      final m = MapGenerator.biome(lay);
      expect(m.place, lay.id);
      for (final f in lay.fish) {
        expect(kFish[f]?.biome, lay.id, reason: f);
      }
      for (final j in lay.junk) {
        expect(kFish.containsKey(j), isTrue, reason: j);
      }
      for (final s in lay.seeds.keys) {
        expect(kCrops[s]?.biome, lay.id, reason: s);
      }
      for (final s in lay.npc.seeds.keys) {
        expect(lay.seeds.containsKey(s), isTrue, reason: s);
      }
      for (final f in lay.forage) {
        expect(m.tileAt(f.x, f.y), Tile.forage, reason: '${lay.id} $f');
        expect(kCrops[kForageKinds[f.kind].item], isNotNull);
      }
      final (nx, ny) = lay.npc.tile;
      expect(m.tileAt(nx, ny), Tile.grass, reason: lay.id);
    }
  });

  test('los biomas se abren con la zona del dueño', () {
    expect(BiomeRules.canTravelTo(kBosque), isTrue);
    expect(BiomeRules.canTravelTo(kRuinas, unlockedZone: 2), isFalse);
    expect(BiomeRules.canTravelTo(kRuinas, unlockedZone: 3), isTrue);
    expect(BiomeRules.lockedReason(kAbismo, 3), isNotNull);
    expect(BiomeRules.vendorPrice(kBosque, 'helecho_dulce'), 40);
    expect(BiomeRules.vendorPrice(null, 'helecho_dulce'), isNull);
  });

  test('habitante: cadena de Ilda, etapas, pedidos y descontento', () {
    var r = const ResidentState('ilda', house: 1);
    expect(ResidentRules.tier(r), 0);
    for (final q in kResidentQuests['ilda']!) {
      final kind = q.kind, target = q.target;
      final (next, done) = ResidentRules.advance(r, kind, target, q.n);
      expect(done, q);
      r = next;
    }
    expect(ResidentRules.currentQuest(r), isNull);
    expect(ResidentRules.stage(r), ResidentStage.asentado);
    r = ResidentRules.onDay(r, 10);
    expect(r.request, ResidentRequest.casa);
    final sad = ResidentRules.onDay(r, 20);
    expect(sad.unhappy, isTrue);
    expect(ResidentRules.tier(sad), ResidentRules.tier(r) - 1);
    final ok = ResidentRules.fulfill(sad, 21);
    expect(ok.request, isNull);
    expect(ok.unhappy, isFalse);
    expect(ResidentState.fromJson(ok.toJson()), ok);
    expect(ResidentRules.benefit(NpcRole.herbolaria, 1), greaterThan(
        ResidentRules.benefit(NpcRole.herbolaria, 0)));
  });
}
