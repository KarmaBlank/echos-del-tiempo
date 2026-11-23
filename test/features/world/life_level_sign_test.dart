import 'package:echos_del_tiempo/features/world/presentation/map/life_level_layer.dart';
import 'package:echos_del_tiempo/game_engine/data/life_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/rules/farming_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/fishing_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('el cartel sale al cruzar el umbral de Pesca y de Cultivo', () {
    final l = MapLifeLevelLayer();
    final fishNeed = FishingRules.xpNeed(1), farmNeed = FarmingRules.xpNeed(1);
    int fish(int xp) => FishingRules.levelFor(xp);
    int farm(int xp) => FarmingRules.levelFor(xp);
    expect(l.observe('b', 'Bruno', fish(0), farm(0), 0), isEmpty);
    expect(l.observe('b', 'Bruno', fish(fishNeed - 1), farm(farmNeed - 1), 1),
        isEmpty);
    final a = l.observe('b', 'Bruno', fish(fishNeed), farm(farmNeed - 1), 2);
    expect(a.single.kind, LifeSkillKind.pesca);
    expect(a.single.title, 'Pescador 2');
    final b = l.observe('b', 'Bruno', fish(fishNeed), farm(farmNeed), 3);
    expect(b.single.kind, LifeSkillKind.cultivo);
    expect(b.single.title, 'Granjero 2');
    expect(l.signs.length, 2);
  });
}
