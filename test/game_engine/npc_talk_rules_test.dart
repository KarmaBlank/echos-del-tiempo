import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/npc_talk_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/biome_fisher_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/npc_talk_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final native = nativeId(kBosque);

  test('los diez tienen charla; arraigados = los cinco pescadores', () {
    for (final b in kBiomeFishers.keys) {
      expect(npcRooted(nativeId(b)), isTrue, reason: b);
      expect(npcTalk(nativeId(b))!.decline, isNotEmpty);
    }
    for (final id in ['ilda', 'velda', 'kael', 'brann', 'oren']) {
      expect(npcTalk(id), isNotNull, reason: id);
      expect(npcRooted(id), isFalse);
    }
  });

  test('una charla por día y los temas se abren con el tiempo', () {
    var s = const TownState();
    final first = NpcTalkRules.topics(s, native, inTown: false);
    expect(first.map((t) => t.id), isNot(contains('vivis')));
    s = NpcTalkRules.talk(s, native, 1)!;
    expect(NpcTalkRules.talk(s, native, 1), isNull);
    expect(NpcTalkRules.topics(s, native, inTown: false).map((t) => t.id),
        contains('vivis'));
    expect(s.bond(native).rep, NpcTalkRules.talkRep);
    // Los que se mudan no muestran "¿Vivís acá?" en el pueblo.
    final r = NpcTalkRules.talk(const TownState(), 'ilda', 1)!;
    expect(NpcTalkRules.topics(r, 'ilda', inTown: true).map((t) => t.id),
        isNot(contains('vivis')));
  });

  test('invitar al arraigado: dice que no, regalo único y puesto', () {
    var s = const TownState();
    expect(NpcTalkRules.cannotInvite(s, kBosque), isNotNull);
    for (var d = 1; d <= 2; d++) {
      s = NpcTalkRules.talk(s, native, d)!;
    }
    for (var i = 0; i < NpcTalkRules.inviteOrders; i++) {
      s = NpcTalkRules.onOrder(s, kBosque);
    }
    expect(NpcTalkRules.cannotInvite(s, kBosque), isNull);
    expect(NpcTalkRules.stock(s, kBosque, 3), isEmpty);
    final p = PlayerProfile(name: 'A');
    final r = NpcTalkRules.invite(p, s, kBosque)!;
    expect(r.$1.credits, p.credits + NpcTalkRules.giftGold);
    expect(r.$1.treeBonus, p.treeBonus + NpcTalkRules.giftPoints);
    expect(NpcTalkRules.invite(r.$1, r.$2, kBosque), isNull);
    s = r.$2;
    expect(BiomeFisherRules.favorGold(s, kBosque, 100), 125);
    final stock = NpcTalkRules.stock(s, kBosque, 3);
    expect(stock.where((g) => g.fresh), hasLength(1));
    expect(NpcTalkRules.stock(s, kBosque, 4).where((g) => g.fresh), isEmpty);
    final g = stock.first;
    final rich = p.copyWith(credits: 10000);
    final bought =
        NpcTalkRules.trade(rich, s, kBosque, g.species, 2, 3, buy: true)!;
    expect(bought.life.count(g.species), 2);
    final sold =
        NpcTalkRules.trade(bought, s, kBosque, g.species, 2, 3, buy: false)!;
    expect(sold.life.count(g.species), 0);
    expect(sold.credits,
        bought.credits + NpcTalkRules.sellPrice(kBosque, g.species)! * 2);
  });

  test('el lazo viaja en el JSON del pueblo y lo viejo carga vacío', () {
    final s = NpcTalkRules.talk(const TownState(), native, 4)!;
    final back = TownState.fromJson(s.farmJson());
    expect(back.bond(native).talks, 1);
    expect(back.bond(native).talkDay, 4);
    expect(TownState.fromJson(const {}).bonds, isEmpty);
  });
}
