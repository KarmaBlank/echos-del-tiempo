import 'dart:convert';

import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/game_engine/models/session_event.dart';
import 'package:echos_del_tiempo/game_engine/models/weapon.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

void main() {
  test('lee un perfil guardado por el prototipo (mismas claves)', () {
    final json = jsonDecode('{"name":"Ana","cls":"maga","lvl":3,"xp":12,"cr":250,'
        '"st":{"VIT":6,"ESP":19,"AGI":7,"FUE":4,"DES":6},"pts":0,'
        '"inv":["baculo_aprendiz","baculo_fuego"],"eq":"baculo_fuego","pot":2,"eter":4,'
        '"up":{"baculo_fuego":{"pow":2,"spd":1}},"fuse":{"baculo_fuego":"cura"},'
        '"tree":["mag_a0","mag_a1"]}') as Map<String, Object?>;
    final p = progression.normalize(PlayerProfile.fromJson(json));
    expect(p.name, 'Ana');
    expect(p.classId, 'maga');
    expect(p.level, 3);
    expect(p.xp, 12);
    expect(p.credits, 250);
    expect(p.attributes[Attribute.esp], 19);
    expect(p.inventory, ['baculo_aprendiz', 'baculo_fuego']);
    expect(p.equipped, 'baculo_fuego');
    expect(p.potions, 2);
    expect(p.ethers, 4);
    expect(p.upgradesFor('baculo_fuego').pow, 2);
    expect(p.upgradesFor('baculo_fuego').spd, 1);
    expect(p.fused, {'baculo_fuego': 'cura'});
    // Árbol v1 (sin `tv`): se reinicia gratis y devuelve los puntos.
    expect(p.tree, isEmpty);
  });

  group('migración del árbol (v1 / v2 / v3 → v4)', () {
    final v1 = {
      'name': 'Ana',
      'cls': 'guerrero',
      'lvl': 6,
      'tree': ['gue_a0', 'gue_a1', 'b_ne'],
    };

    test('un perfil v1 con nodos carga con el árbol vacío y todos los puntos',
        () {
      final raw = PlayerProfile.fromJson(v1);
      expect(raw.tree, isEmpty);
      expect(raw.treeRefunded, 3);
      final p = progression.normalize(raw);
      expect(p.tree, isEmpty);
      expect(p.treeRefunded, 0, reason: 'normalize lo consume');
      expect(treeRules.pointsAvailable(p.level, p.passiveProgress), 10);
      expect(p.toJson()['tv'], PlayerProfile.treeVersion);
      expect(p.toJson().containsKey('tvRef'), isFalse);
    });

    test('un perfil v4 conserva su árbol', () {
      final p = PlayerProfile.fromJson({
        ...v1,
        'tv': 4,
        'tree': ['gue_r1', 'gue_f3'],
      });
      expect(p.tree, ['gue_r1', 'gue_f3']);
      expect(p.treeRefunded, 0);
    });

    // passive_tree_v4.md § 6: de la v3 queda lo que sigue igual (anillo,
    // inicios, r1, abanico, notables A/B, keystones, puentes y grupos salvo
    // la punta) si sigue conectado; el resto vuelve gratis.
    test('un perfil v3 conserva lo que no cambió y recupera lo demás', () {
      final raw = PlayerProfile.fromJson({
        ...v1,
        'lvl': 30,
        'tv': 3,
        'tree': [
          'gue_r1', 'gue_r2', 'gue_f3', 'quiebre_e1', 'quiebre_e2', //
          'quiebre_f', 'quiebre_a1', 'quiebre_a2', 'quiebre_na', 'p_gue',
          'r_gm1', 'estandarte_e1', 'estandarte_e2', 'estandarte_a1',
          'estandarte_a2', 'estandarte_na', 'estandarte_j', 'estandarte_t',
        ],
      });
      expect(raw.tree, [
        'gue_r1', 'gue_f3', 'p_gue', 'r_gm1', 'estandarte_e1', //
        'estandarte_e2', 'estandarte_a1', 'estandarte_a2', 'estandarte_na',
        'estandarte_j',
      ]);
      expect(raw.treeRefunded, 8,
          reason: 'quiebre_na sigue igual pero ya no conecta: también vuelve');
      final p = progression.normalize(raw);
      expect(p.tree, raw.tree);
      expect(treeRules.pointsAvailable(p.level, p.passiveProgress), 58 - 10);
      expect(p.toJson()['tv'], PlayerProfile.treeVersion);
    });

    // passive_tree_v3.md § 11: de la v2 solo quedan el anillo y los
    // inicios (mismo id y efecto), si siguen conectados; el resto vuelve.
    test('un perfil v2 conserva anillo e inicios y recupera lo demás', () {
      final raw = PlayerProfile.fromJson({
        ...v1,
        'lvl': 20,
        'tv': 2,
        'tree': [
          'p_gue', 'sangre_1', 'sangre_2', 'r_gm1', 'r_gm2', 'p_mag', //
          's_mag', 'brasa_1', 'brasa_2', 'id_que_no_existe', 'r_tp1',
        ],
      });
      expect(raw.tree, ['p_gue', 'r_gm1', 'r_gm2', 'p_mag', 's_mag']);
      expect(raw.treeRefunded, 6, reason: 'r_tp1 no conecta: también vuelve');
      final p = progression.normalize(raw);
      expect(p.tree, raw.tree);
      expect(treeRules.pointsAvailable(p.level, p.passiveProgress), 38 - 5);
      expect(p.toJson()['tv'], PlayerProfile.treeVersion);
    });

    test('v2 con una clase desconocida o ids basura no rompe', () {
      final raw = PlayerProfile.fromJson({
        'cls': 'nigromante',
        'lvl': 5,
        'tv': 2,
        'tree': ['???', 's_gue', 'p_gue', 42],
      });
      expect(raw.tree, ['p_gue']);
      expect(raw.treeRefunded, 2);
      expect(progression.normalize(raw).tree, ['p_gue']);
    });

    test('v1 sin nodos: nada que devolver', () {
      final p = PlayerProfile.fromJson({...v1, 'tree': <String>[]});
      expect(p.treeRefunded, 0);
    });

    test('el aviso viaja por la red (hello) y la sala avisa una vez', () {
      final raw = PlayerProfile.fromJson(v1);
      final sent = PlayerProfile.fromJson(
          jsonDecode(jsonEncode(raw.toJson())) as Map<String, Object?>);
      expect(sent.treeRefunded, 3);
      final e = sessionEngine();
      final step = e.addPlayer(e.create(), 'a', sent)!;
      final notices = step.events
          .whereType<SystemMessageEvent>()
          .where((m) => m.text.contains('árbol de pasivas cambió'))
          .toList();
      expect(notices, hasLength(1));
      expect(notices.single.text, contains('recuperaste 3 puntos'));
      expect(step.state.players['a']!.profile.treeRefunded, 0);
    });
  });

  test('toJson → JSON → fromJson da el mismo perfil', () {
    final p = newProfile('Leo', 'paladin').copyWith(
      credits: 99,
      potions: 5,
      upgrades: {'espada_escudo_novato': const WeaponUpgradeLevels(pow: 3, crit: 1)},
      fused: {'espada_escudo_novato': 'sanar'},
    );
    final text = jsonEncode(p.toJson());
    final back = PlayerProfile.fromJson(jsonDecode(text) as Map<String, Object?>);
    expect(back.toJson(), p.toJson());
    expect(progression.normalize(back).toJson(), p.toJson());
  });

  test('fromJson tolera basura', () {
    final p = PlayerProfile.fromJson({'lvl': 'x', 'inv': 'no', 'st': 5, 'up': []});
    expect(p.level, 1);
    expect(p.inventory, isEmpty);
    expect(p.potions, PlayerProfile.defaultPotions);
    expect(p.ethers, PlayerProfile.defaultEthers);
    final fixed = progression.normalize(p);
    expect(fixed.classId, 'guerrero');
    expect(fixed.equipped, 'espada_bronce');
  });

  test('InMemoryProfileStore guarda y carga', () async {
    final store = InMemoryProfileStore();
    expect(await store.load(), isNull);
    final p = newProfile('Mia', 'tirador').copyWith(credits: 42);
    await store.save(p);
    final loaded = await store.load();
    expect(loaded!.toJson(), p.toJson());
  });
}
