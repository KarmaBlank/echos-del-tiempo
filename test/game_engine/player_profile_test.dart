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

  group('migración del árbol v1 → v2', () {
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
      expect(treeRules.pointsAvailable(p.level, p.passiveProgress), 5);
      expect(p.toJson()['tv'], PlayerProfile.treeVersion);
      expect(p.toJson().containsKey('tvRef'), isFalse);
    });

    test('un perfil v2 conserva su árbol', () {
      final p = PlayerProfile.fromJson({
        ...v1,
        'tv': 2,
        'tree': ['filo_1', 'filo_2'],
      });
      expect(p.tree, ['filo_1', 'filo_2']);
      expect(p.treeRefunded, 0);
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
