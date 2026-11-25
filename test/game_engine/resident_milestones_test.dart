import 'package:echos_del_tiempo/game_engine/data/tuning_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/resident_milestone_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

// Resident milestones (roles.md § 9).

int _t(String k) => kTuning[TuningId.town]!.values[k]!.round();

TownState _town(int rep, {int house = 1, bool invited = true}) =>
    const TownState().withResident(
        ResidentState('ilda', rep: rep, house: house, invited: invited));

int _idx(MilestoneReward r) =>
    kResidentMilestones.firstWhere((m) => m.reward == r).index;

void main() {
  final p0 = newProfile('Ana', 'guerrero');

  test('the track is sorted by relationship and reachable (§ 9.4)', () {
    final reps = [for (final m in ResidentMilestoneRules.track) m.rep];
    expect(reps, [...reps]..sort());
    expect(reps.last, _t('msRepUnique'));
    expect(_t('resRootedRep'), 10);
    expect(_t('orderRep'), 2);
  });

  test('states: claimable, next, locked; perks are not claimed', () {
    final r = _town(5).resident('ilda');
    final chest = kResidentMilestones[_idx(MilestoneReward.chestWood)];
    final meal = kResidentMilestones[_idx(MilestoneReward.meal)];
    final silver = kResidentMilestones[_idx(MilestoneReward.chestSilver)];
    expect(ResidentMilestoneRules.state(p0, r, chest), MilestoneState.claimable);
    expect(ResidentMilestoneRules.state(p0, r, meal), MilestoneState.next);
    expect(ResidentMilestoneRules.state(p0, r, silver), MilestoneState.locked);
    expect(ResidentMilestoneRules.cannotClaim(
            p0, _town(5), 'ilda', _idx(MilestoneReward.perk)),
        isNotNull);
  });

  test('needs a house; claim pays materials once', () {
    final i = _idx(MilestoneReward.material);
    expect(ResidentMilestoneRules.cannotClaim(p0, _town(9, house: 0), 'ilda', i),
        isNotNull);
    final p = ResidentMilestoneRules.claim(p0, _town(9), 'ilda', i)!;
    expect(ResidentMilestoneRules.isClaimed(p, 'ilda', i), isTrue);
    final got = p.life.farm.crops.values.fold(0, (a, b) => a + b) -
        p0.life.farm.crops.values.fold(0, (a, b) => a + b);
    expect(got, _t('msMaterialN'));
    expect(ResidentMilestoneRules.claim(p, _town(9), 'ilda', i), isNull);
  });

  test('endgame adds currency (Esquirlas on chests)', () {
    final end = p0.copyWith(ecosUnlocked: true);
    final i = _idx(MilestoneReward.chestWood);
    final p = ResidentMilestoneRules.claim(end, _town(3), 'ilda', i)!;
    expect(p.materials[CraftMaterial.esquirla] ?? 0,
        (end.materials[CraftMaterial.esquirla] ?? 0) + _t('msEndShards'));
  });

  test('migration: old saves get reached milestones as claimable', () {
    final json = p0.toJson()..remove('rcl');
    final old = PlayerProfile.fromJson(json);
    expect(old.resClaims, isEmpty);
    expect(ResidentMilestoneRules.claimableCount(old, _town(20).resident('ilda')),
        greaterThanOrEqualTo(5));
    final claimed = old.copyWith(resClaims: {'ilda': 5});
    expect(PlayerProfile.fromJson(claimed.toJson()).resClaims, {'ilda': 5});
  });

  test('host op: claim delivers a chest and rejects a second claim', () {
    final e = sessionEngine(fieldFallback: 0.5);
    var s = e.addPlayer(e.create(), 'p0', p0)!.state;
    s.town = _town(3);
    final gold = s.players['p0']!.profile.credits;
    final a = TownAction(TownOp.claimMilestone,
        id: 'ilda', n: _idx(MilestoneReward.chestWood));
    s = act(e, s, 'p0', a);
    expect(s.players['p0']!.profile.credits, greaterThan(gold));
    expect(e.apply(s, 'p0', a), isNull);
  });
}
