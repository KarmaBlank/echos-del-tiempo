import 'package:echos_del_tiempo/features/inventory/domain/item_text.dart';
import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/player_state.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/session_event.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/ult_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// ULT libres del arma (ultimates_v2.md § 2.1, v0.20.15).
void main() {
  const modded = ItemInstance(
      uid: 'w9', baseId: 'espada_bronce', rarity: Rarity.raro, ultId: 'ult2_ecoFilo');

  String? castBy(PlayerBuild b) {
    final s = BattleEngine(stats: progression.stats, random: () => 0.5)
        .start(
        party: [BattlePartyMember(id: 'p1', name: 'A', build: b)],
        enemyTypes: ['golem']).state;
    return ultimateOf(s.party.first)?.id;
  }

  PlayerBuild build(String cls, String weapon,
          {ItemInstance? item, String? sel}) =>
      PlayerBuild(
        classId: cls,
        level: 10,
        attributes: PlayerAttributes.base(kClasses[cls]!.baseAttributes),
        equippedWeapon: kWeapons[weapon]!,
        item: item,
        ultSel: sel,
      );

  test('la ULT base de la Maga es Meteoro y es la activa por defecto', () {
    expect(UltRules.baseUltId('maga'), 'ult_baculo');
    expect(castBy(build('maga', 'baculo_aprendiz')), 'ult_baculo');
    // Con otra arma equipada sigue siendo la base.
    expect(castBy(build('maga', 'espada_bronce')), 'ult_baculo');
  });

  test('el arma equipada nunca decide la ULT (mod "ULT" incluido)', () {
    expect(castBy(build('guerrero', 'espada_bronce', item: modded)),
        UltRules.baseUltId('guerrero'));
    expect(
        castBy(build('guerrero', 'baculo_aprendiz', sel: 'ult2_ecoFilo')),
        'ult2_ecoFilo');
  });

  test('conseguir el arma enseña la ULT con NUEVA; verla la desmarca', () {
    final p = progression.normalize(
        PlayerProfile(name: 'Ana', classId: 'guerrero'));
    expect(p.ultNew, isEmpty);
    final got = UltRules.absorb(p.copyWith(items: [...p.items, modded]));
    expect(got.ultKnown, contains('ult2_ecoFilo'));
    expect(got.ultNew, contains('ult2_ecoFilo'));
    final seen = UltRules.markSeen(got, ['${UltRules.seenPrefix}ult2_ecoFilo'])!;
    expect(seen.ultNew, isNot(contains('ult2_ecoFilo')));
    expect(seen.ultKnown, contains('ult2_ecoFilo'));
    // Ida y vuelta del JSON (`un`).
    expect(PlayerProfile.fromJson(got.toJson()).ultNew, got.ultNew);
  });

  test('migración: un perfil viejo absorbe las ULT de sus armas sin NUEVA', () {
    final old = PlayerProfile(
        name: 'Ana',
        classId: 'guerrero',
        items: const [modded],
        equipped: 'w9',
        ultSel: 'ult_espada');
    final p = progression.normalize(old);
    expect(p.ultKnown,
        containsAll(['ult2_ecoFilo', UltRules.baseUltId('guerrero')]));
    expect(p.ultNew, isEmpty);
    expect(p.ultSel, 'ult_espada');
  });

  test('los tooltips del arma ya no muestran su ULT', () {
    final lines = itemSkillLinesMarkup(progression, modded).join(' ');
    expect(lines, isNot(contains('ULT')));
    expect(itemSkillsMarkup(progression, modded), isNot(contains('ULT')));
  });

  test('comprar un arma de otro tipo: «¡Nueva ULT!» y NUEVA hasta verla', () {
    final e = sessionEngine();
    final p = progression.normalize(
        PlayerProfile(name: 'Ana', classId: 'guerrero', credits: 99999));
    var s = e.addPlayer(e.create(), 'p0', p)!.state;
    final base = UltRules.baseUltId('guerrero');
    final id = progression.catalog.weapons.keys.firstWhere((w) {
      final u = progression.catalog.ultimates[kWeapons[w]?.type]?.id;
      return u != null && u != base && progression.buyWeapon(p, w) != null;
    });
    final ult = progression.catalog.ultimates[kWeapons[id]!.type]!;
    final step = e.apply(s, 'p0', BuyWeaponAction(id))!;
    s = step.state;
    final me = s.players['p0']!.profile;
    expect(me.ultKnown, contains(ult.id));
    expect(me.ultNew, contains(ult.id));
    expect(
        step.events.whereType<SystemMessageEvent>().map((m) => m.text),
        contains('Ana: ¡Nueva ULT: ${ult.name}!'));
    s = act(e, s, 'p0', SeenItemsAction(['${UltRules.seenPrefix}${ult.id}']));
    expect(s.players['p0']!.profile.ultNew, isEmpty);
  });

  test('ultSel nunca se pierde ni cede al arma equipada (aunque no esté en uk)',
      () {
    // Perfil "viejo": eligió la de báculo sin tenerla anotada y equipa un
    // arma con mod "ULT".
    final raw = PlayerProfile(
        name: 'Ana',
        classId: 'guerrero',
        items: const [modded],
        equipped: 'w9',
        ultSel: 'ult_baculo');
    final p = progression.normalize(raw);
    expect(p.ultSel, 'ult_baculo');
    expect(p.ultKnown, contains('ult_baculo'));
    final b = progression.buildOf(raw);
    expect(b.ultSel, 'ult_baculo');
    expect(castBy(b), 'ult_baculo');
    expect(castBy(progression.buildOf(p)), 'ult_baculo');
  });
}
