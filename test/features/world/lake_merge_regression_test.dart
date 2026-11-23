import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/map_generator.dart';
import 'package:echos_del_tiempo/game_engine/rules/town_rules.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/fishing_layer.dart';
import 'package:flutter_test/flutter_test.dart';

/// v0.31.2: huertas/lagos pegados por un lado se funden (esquina sola o
/// un tile de hueco: separados) y las sombras de peces no se regeneran
/// con cada snapshot.
void main() {
  final rich = PlayerProfile(name: 'Ana', classId: 'guerrero').copyWith(
      credits: 10000000,
      materials: {CraftMaterial.esquirla: 999, CraftMaterial.cristal: 999});
  final s = TownRules.expand(rich, const TownState(), TownSide.este)!.$2;
  final big = TownRules.place(s, 'huerta', 34, 8); // 6×4: x 34..39, y 8..11

  test('huertas: lado con lado se funden; esquina o hueco, no', () {
    expect(big.error, isNull);
    final base = big.town!.copyWith(builds: [
      for (final b in big.town!.builds)
        b.id == big.id ? b.copyWith(helper: 1, chest: {'nabo_claro': 2}) : b
    ]);
    final edge = TownRules.place(base, 'huerta_chica', 34, 12);
    expect(edge.error, isNull);
    expect(edge.town!.farms.length, 2, reason: 'base + fundida');
    final m = edge.town!.build(edge.id!)!;
    expect(m.id, big.id, reason: 'la más grande conserva id y cartel');
    expect(m.parts.length, 2);
    expect(m.helper, 1);
    expect(m.chest['nabo_claro'], 2);
    // El contorno de la unión no tiene el borde compartido.
    final o = TownRect.outline(m.parts);
    expect(o.where((e) => e.$2 == 12 && e.$4 == 12 && e.$1 >= 34 && e.$3 <= 38),
        isEmpty);

    final corner = TownRules.place(base, 'huerta_chica', 30, 5);
    if (corner.error == null) {
      expect(corner.town!.farms.length, 3, reason: 'esquina sola no funde');
    }
    final gap = TownRules.place(base, 'huerta_chica', 34, 13);
    expect(gap.error, isNull);
    expect(gap.town!.farms.length, 3, reason: 'un tile de hueco: separadas');
  });

  test('sombras de peces: deterministas y estables entre snapshots', () {
    final town = TownRules.place(s, 'lago', 32, 7).town!;
    GameMap fresh() => MapGenerator.townOf(town);
    final a = MapFishingLayer(), b = MapFishingLayer();
    a.update(fresh(), 0, null);
    b.update(fresh(), 0, null);
    expect(a.shadowLayout, isNotEmpty);
    expect(a.shadowLayout, b.shadowLayout, reason: 'mismo lago, misma disposición');
    // Avanzan; un snapshot nuevo (otra instancia, mismo lago) no las resetea.
    for (var i = 0; i < 20; i++) {
      a.update(fresh(), 0.05, null);
    }
    final before = a.shadowLayout;
    a.update(fresh(), 0, null);
    expect(a.shadowLayout, before);
    // Si cambia el agua (editor), se regeneran.
    final more = TownRules.place(town, 'lago_chico', 32, 13).town!;
    a.update(MapGenerator.townOf(more), 0, null);
    expect(a.shadowLayout, isNot(before));
  });
}
