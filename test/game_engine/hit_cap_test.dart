import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/enemies_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/game_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/skills_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_event.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/player_state.dart';
import 'package:echos_del_tiempo/game_engine/models/status.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/family_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:echos_del_tiempo/game_engine/serialization/session_json.dart';
import 'package:flutter_test/flutter_test.dart';

// Afinidades y tope por golpe sin debilidad (docs/specs/combo_balance.md
// § 3.1–3.2). Azar fijo 0.99: nunca crítico ni esquiva.

final _stats = StatsCalculator(
    classes: kClasses, treeRules: PassiveTreeRules(kPassiveTree));

const _catalog = GameCatalog(
  classes: kClasses,
  weapons: kWeapons,
  skills: kSkills,
  ultimates: kAllUltimates,
  duals: kDuals,
  enemies: kEnemies,
);

Combatant _hero({String? skill, int? level}) => Combatant(
      id: 'p1',
      name: 'Ana',
      isPlayer: true,
      hp: 100,
      maxHp: 100,
      speed: 10,
      attack: 20,
      magic: 20,
      critChance: 0,
      mp: 50,
      maxMp: 50,
      skillIds: [if (skill != null) skill],
      classId: 'guerrero',
      weaponType: 'espada',
      build: level == null
          ? null
          : PlayerBuild(
              classId: 'guerrero',
              level: level,
              attributes:
                  PlayerAttributes.base(kClasses['guerrero']!.baseAttributes),
              equippedWeapon: kWeapons['espada_bronce']!,
            ),
    );

Combatant _foe(String type,
        {int hp = 30,
        bool elite = false,
        bool boss = false,
        int level = 0,
        Map<StatusKind, int>? st}) =>
    Combatant(
      id: 'e0',
      name: kEnemies[type]!.name,
      isPlayer: false,
      hp: hp,
      maxHp: hp,
      speed: 5,
      attack: 10,
      critChance: 0,
      enemyType: type,
      nextTurn: 50,
      elite: elite,
      boss: boss,
      level: level,
      statuses: st,
    );

BattleStep _hit(Combatant foe, {String? skill, Combatant? hero}) {
  final s = BattleState(
      party: [hero ?? _hero(skill: skill)], enemies: [foe], currentId: 'p1');
  final e = BattleEngine(stats: _stats, catalog: _catalog, random: () => 0.99);
  return e.command(
      s,
      'p1',
      skill == null
          ? const AttackCommand(targetId: 'e0')
          : SkillCommand(skill, targetId: 'e0'))!;
}

int _dmg(BattleStep s) => s.events
    .whereType<DamageEvent>()
    .where((d) => d.targetId == 'e0' && d.sourceId == null)
    .first
    .amount;

void main() {
  group('afinidades (§ 3.1)', () {
    test('cada familia: al menos 1 debilidad y 1 resistencia, escala fija', () {
      for (final r in kFamilyRules.values) {
        final v = r.damage.values;
        expect(v.any((x) => x > 1), isTrue, reason: '${r.family} débil');
        expect(v.any((x) => x < 1), isTrue, reason: '${r.family} resiste');
        for (final x in v) {
          expect([0, 0.5, 1.5], contains(x), reason: '${r.family} $x');
        }
      }
      expect(kFamilyRules[EnemyFamily.fireElemental]!.damage[DamageTag.fire],
          0);
    });

    test('inmune: daño 0, cartel INMUNE y rasgo en la ficha', () {
      final step = _hit(_foe('salamandra', hp: 500), skill: 'chispa');
      final d = step.events.whereType<DamageEvent>().first;
      expect([d.amount, d.affinity], [0, 0]);
      expect(step.state.log, contains('× 0 INMUNE fuego'));
      expect(
          familyTraits(kFamilyRules[EnemyFamily.fireElemental]!)
              .where((t) => t.kind == TraitKind.immune)
              .map((t) => t.label),
          contains('daño de fuego'));
    });
  });

  group('tope por golpe sin debilidad (§ 3.2)', () {
    test('común: 60% de la vida máxima, con el log', () {
      final step = _hit(_foe('lobo'));
      expect(_dmg(step), 18); // ATQ 20 → tope ceil(30 × 0.6)
      expect(step.state.log, contains('→ 18 (resiste el golpe)'));
    });

    test('solo: élite 45% y jefe 25% (escalan con el grupo)', () {
      expect(_dmg(_hit(_foe('lobo', elite: true))), 14); // ceil(13.5)
      expect(_dmg(_hit(_foe('lobo', hp: 60, boss: true))), 15);
    });

    test('golpe que no llega al tope: sin cambios', () {
      final step = _hit(_foe('lobo', hp: 500));
      expect(_dmg(step), 20);
      expect(step.state.log, isNot(contains('resiste el golpe')));
    });

    test('sin tope: golpe a una debilidad', () {
      // Chispa (fuego) a una bestia: ×1.5.
      final step = _hit(_foe('lobo', hp: 20), skill: 'chispa');
      expect(_dmg(step), greaterThan(12));
      expect(step.state.log, isNot(contains('resiste el golpe')));
    });

    test('sin tope: enemigo quebrado', () {
      final f = _foe('lobo')..vulnerable = 2;
      final step = _hit(f);
      expect(_dmg(step), 30); // 20 × 1.5 QUIEBRE
      expect(step.state.log, isNot(contains('resiste el golpe')));
    });

    test('sin tope: reacción (Mojado + Electro)', () {
      final step = _hit(_foe('lobo', hp: 20, st: {StatusKind.wet: 2}),
          skill: 'descarga');
      expect(step.events.whereType<ReactionEvent>(), isNotEmpty);
      expect(_dmg(step), greaterThan(12));
      expect(step.state.log, isNot(contains('resiste el golpe')));
    });

    test('sin tope: jugador 5 o más niveles sobre el enemigo', () {
      // Niveles de la parte A del tramo (sin la mitigación de zona C).
      expect(_dmg(_hit(_foe('lobo', level: 11), hero: _hero(level: 16))), 20);
      expect(_dmg(_hit(_foe('lobo', level: 12), hero: _hero(level: 16))), 18);
    });

    test('el tope sale del catálogo (editable por balance)', () {
      const open = GameCatalog(
        classes: kClasses,
        weapons: kWeapons,
        skills: kSkills,
        ultimates: kAllUltimates,
        duals: kDuals,
        enemies: kEnemies,
        hitCaps: {'tope': HitCapDef(common: 1)},
      );
      final s = BattleState(
          party: [_hero()], enemies: [_foe('lobo')], currentId: 'p1');
      final e = BattleEngine(stats: _stats, catalog: open, random: () => 0.99);
      expect(_dmg(e.command(s, 'p1', const AttackCommand(targetId: 'e0'))!),
          20);
    });

    test('el nivel del enemigo viaja en el estado (lv)', () {
      final s = BattleState(
          party: [_hero()], enemies: [_foe('lobo', level: 23)]);
      const j = SessionJson();
      final back = j.battleStateFromJson(j.battleStateToJson(s));
      expect(back.enemies.single.level, 23);
    });
  });
}
