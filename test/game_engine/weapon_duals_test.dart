import 'package:echos_del_tiempo/game_engine/balance/balance_codecs.dart';
import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/elements_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/game_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/skills_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapon_duals_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_event.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/player_state.dart';
import 'package:echos_del_tiempo/game_engine/models/skill.dart';
import 'package:echos_del_tiempo/game_engine/models/status.dart';
import 'package:echos_del_tiempo/game_engine/models/weapon.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/dual_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:echos_del_tiempo/game_engine/serialization/action_json.dart';
import 'package:flutter_test/flutter_test.dart';

/// El arma más baja de cada tipo.
WeaponDef _weaponOf(String type) {
  final ws = kWeapons.values.where((w) => w.type == type).toList()
    ..sort((a, b) => a.level.compareTo(b.level));
  return ws.first;
}

BattlePartyMember _member(String id, String weaponType, {double? mp}) {
  final w = _weaponOf(weaponType);
  final cls = kClasses[w.classId]!;
  return BattlePartyMember(
    id: id,
    name: 'P-$id',
    mp: mp,
    build: PlayerBuild(
      classId: w.classId,
      level: 1,
      attributes: PlayerAttributes.base(cls.baseAttributes),
      equippedWeapon: w,
    ),
  );
}

BattleEngine _engine() => BattleEngine(
      stats: StatsCalculator(
          classes: kClasses, treeRules: PassiveTreeRules(kPassiveTree)),
      random: () => 0.99,
    );

/// [a] y [b] (tipos de arma) contra 3 slimes, con el turno de p1.
BattleState _turn(BattleEngine e, String a, String b,
    {double? mpA, double? mpB}) {
  final start = e.start(
    party: [_member('p1', a, mp: mpA), _member('p2', b, mp: mpB)],
    enemyTypes: const ['slime', 'slime', 'golem'],
    triggeredBy: 'p1',
  );
  var s = start.state;
  // Avanza hasta el turno de p1 (sin que actúe nadie más).
  for (var i = 0; i < 10 && s.currentId != 'p1'; i++) {
    s = e.nextTurn(s).state;
    if (s.currentId != null && s.currentId != 'p1') {
      s.currentId = null;
    }
  }
  expect(s.currentId, 'p1');
  return s;
}

const _types = {
  'espada', 'hacha', 'lanza', 'báculo', 'tomo', 'varita', 'arco', 'rifle',
  'ballesta', 'dagas', 'espada+escudo', 'maza+escudo', 'martillo+escudo',
};

void main() {
  group('catálogo de dúos de armas', () {
    test('dobla el roster: 10 de clase + 10 de armas, ids únicos', () {
      expect(kDuals, hasLength(10));
      expect(kWeaponDuals, hasLength(kDuals.length));
      expect(kAllDuals, hasLength(20));
      expect(GameCatalog.standard.duals, same(kAllDuals));
      for (final id in kWeaponDuals.keys) {
        expect(id, startsWith('w_'));
        expect(id.contains('+'), isFalse, reason: id);
        expect(kDuals.containsKey(id), isFalse);
      }
      // Nombres únicos entre todos los dúos.
      final names = [for (final d in kAllDuals.values) d.name];
      expect(names.toSet(), hasLength(names.length));
    });

    test('tipos de arma válidos, pares únicos y todos los tipos cubiertos',
        () {
      final real = {for (final w in kWeapons.values) w.type};
      expect(real, containsAll(_types));
      final pairs = <String>{};
      final used = <String>{};
      for (final MapEntry(:key, :value) in kWeaponDuals.entries) {
        final w = value.weapons!;
        expect(w, hasLength(2), reason: key);
        expect(w[0] == w[1], isFalse, reason: key);
        for (final t in w) {
          expect(real, contains(t), reason: '$key: $t');
        }
        expect(pairs.add(([...w]..sort()).join('|')), isTrue, reason: key);
        used.addAll(w);
      }
      expect(used, real);
      for (final d in kDuals.values) {
        expect(d.byWeapon, isFalse);
      }
    });

    test('cada dúo de armas tiene elemento (y no todos el mismo)', () {
      final els = <GameElement>{};
      for (final d in kWeaponDuals.values) {
        final el = elementOfDual(d);
        if (d.status.kind == StatusKind.stun) {
          expect(el, GameElement.fisico);
        } else {
          expect(el, isNot(GameElement.fisico), reason: d.name);
          expect(el.status, d.status.kind);
        }
        expect(d.power, greaterThan(1));
        els.add(el);
      }
      expect(els.length, greaterThanOrEqualTo(6));
      expect(els, containsAll([GameElement.agua, GameElement.electro]));
    });

    test('el parche de balance conserva el par de armas', () {
      final d = kWeaponDuals['w_flechaArcana']!;
      final codec = codecOf(BalanceKind.dual);
      final f = {...codec.read(d), 'power': 2.0};
      final out = codec.write(d, BalanceFieldReader(f)) as DualDef;
      expect(out.power, 2.0);
      expect(out.weapons, d.weapons);
    });
  });

  group('disponibilidad por par de armas', () {
    test('dualIdsFor: de clase primero, de armas en cualquier orden', () {
      final e = _engine();
      final s = _turn(e, 'arco', 'báculo');
      final p = s.byId('p1')!, q = s.byId('p2')!;
      expect(p.weaponType, 'arco');
      expect(q.weaponType, 'báculo');
      expect(dualIdsFor(kAllDuals, p, q), ['maga+tirador', 'w_flechaArcana']);
      expect(dualIdsFor(kAllDuals, q, p), ['maga+tirador', 'w_flechaArcana']);
      expect(dualFits('w_flechaArcana', kWeaponDuals['w_flechaArcana']!, q, p),
          isTrue);
      expect(dualFits('w_tajoGlaciar', kWeaponDuals['w_tajoGlaciar']!, p, q),
          isFalse);
      // Sin dúo de armas: solo el de clase.
      final s2 = _turn(e, 'espada', 'arco');
      expect(dualIdsFor(kAllDuals, s2.byId('p1')!, s2.byId('p2')!),
          ['guerrero+tirador']);
    });

    test('el motor rechaza un dúo de armas que el par no tiene', () {
      final e = _engine();
      final s = _turn(e, 'espada', 'arco');
      expect(
          e.command(s, 'p1', const DualCommand('p2', dualId: 'w_flechaArcana')),
          isNull);
      expect(e.command(s, 'p1', const DualCommand('p2', dualId: 'nope')),
          isNull);
      // Sin id: el de clase, como v0.8.2.
      final st = e.command(s, 'p1', const DualCommand('p2'))!;
      final act = st.events.whereType<ActionEvent>().single;
      expect(act.skillId, 'guerrero+tirador');
    });

    test('hace falta MP en los dos', () {
      final e = _engine();
      final s = _turn(e, 'arco', 'báculo', mpB: 2);
      expect(
          e.command(s, 'p1', const DualCommand('p2', dualId: 'w_flechaArcana')),
          isNull);
    });
  });

  group('efecto de cada dúo de armas (smoke)', () {
    for (final MapEntry(key: id, value: du) in kWeaponDuals.entries) {
      test('$id · ${du.name}', () {
        final e = _engine();
        final s = _turn(e, du.weapons![0], du.weapons![1]);
        final p = s.byId('p1')!, q = s.byId('p2')!;
        final mp1 = p.mp, mp2 = q.mp;
        final step = e.command(s, 'p1', DualCommand('p2', dualId: id))!;
        final act = step.events.whereType<ActionEvent>().first;
        expect(act.kind, BattleActionKind.dual);
        expect(act.skillId, id);
        expect(act.partnerId, 'p2');
        expect(act.allTargets, isTrue);
        final hits = step.events
            .whereType<DamageEvent>()
            .where((d) => !d.fromStatus && d.sourceId == null)
            .toList();
        expect(hits.map((h) => h.targetId).toSet(),
            {for (final x in s.enemies) x.id});
        expect(hits.every((h) => h.amount > 0), isTrue);
        final after = step.state;
        expect(after.byId('p1')!.mp, mp1 - BattleEngine.dualMpCost);
        expect(after.byId('p2')!.mp, mp2 - BattleEngine.dualMpCost);
        // El estado (sin probabilidad) llega a algún enemigo, salvo que
        // su familia sea inmune (el log lo dice).
        if (du.status.chance == null) {
          expect(
              step.events
                      .whereType<StatusAppliedEvent>()
                      .any((x) => x.kind == du.status.kind) ||
                  step.state.log.contains('INMUNE'),
              isTrue,
              reason: '$id: ${step.state.log}');
        }
        expect(step.state.log, contains(du.name));
      });
    }

    test('un dúo de armas eléctrico detona Mojado (reacción)', () {
      final e = _engine();
      final s = _turn(e, 'arco', 'báculo');
      for (final x in s.enemies) {
        x.statuses[StatusKind.wet] = 1;
      }
      final step =
          e.command(s, 'p1', const DualCommand('p2', dualId: 'w_flechaArcana'))!;
      expect(step.events.whereType<ReactionEvent>(), isNotEmpty);
    });
  });

  test('red: el id del dúo viaja en el comando (y sin él, como v0.8.2)', () {
    const c = DualCommand('p2', dualId: 'w_saetaVoltaica');
    final j = ActionJson.commandToJson(c);
    expect(j, {'a': 'dual', 'pt': 'p2', 'du': 'w_saetaVoltaica'});
    final back = ActionJson.commandFromJson(j) as DualCommand;
    expect(back.partnerId, 'p2');
    expect(back.dualId, 'w_saetaVoltaica');
    expect(ActionJson.commandToJson(const DualCommand('p2')),
        {'a': 'dual', 'pt': 'p2'});
    expect(
        (ActionJson.commandFromJson({'a': 'dual', 'pt': 'p3'}) as DualCommand)
            .dualId,
        isNull);
  });
}
