import 'package:echos_del_tiempo/features/world/presentation/map/map_game.dart';
import 'package:echos_del_tiempo/game_engine/models/life_skills.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('name label rises only on a raft with an awning', () {
    final roof = LifeSkills(raftDecos: const {'roof'}, raftOn: const {'roof'});
    final bare = LifeSkills();
    expect(MapGame.nameLift(raft: true, life: roof), greaterThan(0));
    expect(MapGame.nameLift(raft: false, life: roof), 0);
    expect(MapGame.nameLift(raft: true, life: bare), 0);
    expect(MapGame.nameLift(raft: true), 0);
  });
}
