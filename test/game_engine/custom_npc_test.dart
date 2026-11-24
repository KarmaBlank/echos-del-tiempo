import 'dart:io';

import 'package:echos_del_tiempo/features/admin/presentation/admin_controller.dart';
import 'package:echos_del_tiempo/features/admin/presentation/editor/events_editor_controller.dart';
import 'package:echos_del_tiempo/features/admin/presentation/editor/npc_editor_controller.dart';
import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/npc_talk_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/custom_npc.dart';
import 'package:echos_del_tiempo/game_engine/models/world_event.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/custom_npc_rules.dart';
import 'package:echos_del_tiempo/game_engine/serialization/npc_data_json.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/admin/fake_admin_host.dart';

/// docs/specs/npc_editor.md § 6: NPCs hechos solo con datos.
void main() {
  tearDown(NpcData.restore);

  const all = {'es-AR': 'Mira', 'en': 'Mira', 'zh-Hans': '米拉'};
  Map<String, Object?> file(Map<String, Object?> def) => {
        'version': 2,
        'npcs': {
          'mira': {
            'def': def,
            'greet': [all],
            'topics': [
              {
                'id': 'hola',
                'label': all,
                'lines': [all],
              }
            ],
          },
        },
      };

  test('def: ida y vuelta por npcs.json e instalación', () {
    final d = NpcData.fromJson(file({
      'name': all,
      'bio': {'es-AR': 'Viene del sur.'},
      'sprite': 'npc_mira',
      'spawn': 'biome',
      'place': kBosque,
      'x': 4,
      'y': 5,
      'time': 'night',
      'invitable': true,
    }));
    final m = d.customs['mira']!;
    expect(m.spawn, CustomNpcSpawn.biome);
    expect(m.time, TalkTime.night);
    expect(m.bioDraft, isTrue);
    final again = NpcData.decode(d.encode());
    expect(again.encode(), d.encode());
    expect(d.install(), isEmpty);
    expect(kCustomNpcs, contains('mira'));
    expect(npcTalk('mira')?.topics.single.id, 'hola');
  });

  test('lore BORRADOR no bloquea; el nombre sin idiomas sí', () {
    const tags = ['es-AR', 'en', 'zh-Hans'];
    final draft = NpcData.fromJson(file({
      'name': all,
      'bio': {'es-AR': 'Solo español.'},
    }));
    expect(draft.missingLocales(tags), isEmpty);
    final fin = NpcData.fromJson(file({
      'name': {'es-AR': 'Mira'},
      'bio': {'es-AR': 'Solo español.'},
      'bio_final': true,
    }));
    expect(fin.missingLocales(tags).length, 2);
  });

  test('un id del código no se puede pisar con un def', () {
    final d = NpcData.fromJson({
      'version': 2,
      'npcs': {
        'ilda': {
          'def': {'name': all}
        }
      }
    });
    expect(d.install(), contains('ilda'));
    expect(kCustomNpcs, isEmpty);
  });

  group('dónde aparece', () {
    CustomNpcDef def(CustomNpcSpawn s, {String place = '', bool inv = false}) =>
        CustomNpcDef(
            id: 'mira',
            name: const LocalizedText.of(all),
            sprite: 'npc_mira',
            spawn: s,
            place: place,
            x: 3,
            y: 4,
            invitable: inv);

    test('pueblo, bioma y mina', () {
      const s = TownState();
      Map<String, CustomNpcDef> one(CustomNpcDef d) => {'mira': d};
      final town = one(def(CustomNpcSpawn.town));
      expect(CustomNpcRules.here(s, null, defs: town).single.x, 3.5 * 16);
      expect(CustomNpcRules.here(s, kBosque, defs: town), isEmpty);
      final biome = one(def(CustomNpcSpawn.biome, place: kBosque));
      expect(CustomNpcRules.here(s, kBosque, defs: biome), hasLength(1));
      expect(CustomNpcRules.here(s, null, defs: biome), isEmpty);
      final mine = one(def(CustomNpcSpawn.mine, place: kBosque));
      expect(CustomNpcRules.here(s, 'mine:$kBosque:0', defs: mine), hasLength(1));
      expect(CustomNpcRules.here(s, 'mine:ruinas:0', defs: mine), isEmpty);
    });

    test('evento: solo mientras está activo, junto a su actor', () {
      final ev = {
        'mira': def(CustomNpcSpawn.event, place: 'visitor_clockmaker'),
      };
      expect(CustomNpcRules.here(const TownState(), null, defs: ev), isEmpty);
      const s = TownState(
          events: WorldEventsState(active: [
        ActiveWorldEvent('visitor_clockmaker',
            biome: kPueblo, start: 1, end: 4),
      ]));
      expect(CustomNpcRules.here(s, null, defs: ev), hasLength(1));
    });

    test('invitable: INVITAR lo muda del bioma al pueblo', () {
      kCustomNpcs['mira'] = def(CustomNpcSpawn.biome, place: kBosque, inv: true);
      const s = TownState();
      expect(CustomNpcRules.invite(s, 'mira', null), isNull);
      final moved = CustomNpcRules.invite(s, 'mira', kBosque)!;
      expect(CustomNpcRules.here(moved, kBosque), isEmpty);
      expect(CustomNpcRules.here(moved, null), hasLength(1));
      expect(CustomNpcRules.invite(moved, 'mira', kBosque), isNull);
    });
  });

  test('editor: NUEVO NPC desde una variante crea el NPC y su visita apagada',
      () async {
    final host = FakeAdminHost(files: {
      'repo/pubspec.yaml': File('pubspec.yaml').readAsStringSync(),
      'repo/assets/balance/balance.json':
          File('assets/balance/balance.json').readAsStringSync(),
    });
    final b = AdminController(host: host);
    await b.load();
    final events = EventsEditorController(balance: b);
    final c = NpcEditorController(balance: b)..events = events;
    final id = c.createCustom('npc_mira');
    expect(id, 'mira');
    expect(c.selected!.custom, isTrue);
    final d = c.defOf(id)!;
    expect(d['sprite'], 'npc_mira');
    expect(d['spawn'], 'event');
    final ev = events.eventOf('${d['place']}')!;
    expect(ev['enabled'], isFalse);
    expect(ev['duration'], 3);
    expect(ev['category'], 'visitor');
    expect(ev['sprite'], 'npc_mira');
    // Se decodifica como un NPC de datos y los eventos siguen válidos.
    expect(c.draft.$1!.customs, contains(id));
    expect(events.problems, isEmpty);
    // Mismo sprite otra vez: abre el mismo NPC.
    expect(c.createCustom('npc_mira'), id);
  });
}
