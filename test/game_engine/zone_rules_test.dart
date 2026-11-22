import 'dart:convert';

import 'package:echos_del_tiempo/game_engine/data/game_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/js_math.dart';
import 'package:echos_del_tiempo/game_engine/rules/progression_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/zone_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

BattlePartyMember partyOf(String classId) => BattlePartyMember(
    id: 'p0',
    name: 'J',
    build: zoneProgression.buildOf(newProfile('J', classId)));

void main() {
  const cat = GameCatalog.standard;

  group('catálogo de zonas', () {
    test('10 zonas en orden, todas jugables con su misión', () {
      expect(cat.zones, hasLength(10));
      for (var i = 0; i < 10; i++) {
        final z = cat.zones[i];
        expect(z.index, i + 1);
        expect(z.id, 'z${i + 1}');
        expect(z.minLevel, i * 5 + 1);
        expect(z.maxLevel, i * 5 + 5);
        expect(z.playable, isTrue);
        expect(cat.zone(i + 1), same(z));
      }
      expect(cat.zones.map((z) => z.floors).take(5), [2, 3, 3, 3, 4]);
      expect(cat.zone(1)!.levelText, 'Lv 1-5');
      expect(cat.missions.map((m) => m.id),
          ['m1', 'z2', 'm2', 'z4', 'z5', 'z6', 'z7', 'z8', 'z9', 'z10']);
      for (final m in cat.missions) {
        final z = cat.zoneOfMission(m.id)!;
        expect(z.missionId, m.id);
        expect(m.floors, z.floors);
        expect(m.floorGroups, hasLength(z.floors));
        expect(m.goal, m.floorGoal * m.floors);
        expect(m.recommendedLevel, z.minLevel);
        expect(m.boss.first, z.bossId);
      }
      expect(cat.mission('m3'), isNull, reason: 'el abismo es la misión z9');
    });

    test('ids de enemigos: existen o tienen reemplazo provisorio', () {
      for (final m in cat.missions) {
        for (final id in {
          ...m.boss,
          m.elite,
          for (final g in m.floorGroups) ...g.expand((x) => x),
        }) {
          final r = ZoneRules.resolveEnemy(id, cat);
          expect(cat.enemies.containsKey(r), isTrue, reason: id);
          if (cat.enemies.containsKey(id)) expect(r, id);
        }
      }
      expect(ZoneRules.resolveEnemy('noExiste', cat), 'slime');
    });
  });

  group('niveles y escalado', () {
    test('nivel de piso, élite y jefe', () {
      final z1 = cat.zone(1)!, z5 = cat.zone(5)!;
      expect([for (var f = 0; f < 2; f++) ZoneRules.floorLevel(z1, f)], [2, 3]);
      expect(ZoneRules.bossLevel(z1), 5);
      // v0.20.22: la zona 5 juega 3 pisos (worldgen.md § 6.8).
      expect([for (var f = 0; f < 3; f++) ZoneRules.floorLevel(z5, f)],
          [22, 23, 24]);
      expect(ZoneRules.eliteLevel(z5, 2), 25);
      expect(ZoneRules.floorLevel(cat.zone(3)!, 0), 12);
    });

    test('scaleBattle: vida y ATQ relativos al nivel nativo; el quiebre no', () {
      final b = BattleEngine(stats: statsCalc, random: () => 0.5);
      final st = b.start(
          party: [partyOf('guerrero')], enemyTypes: ['golem', 'slime']);
      final golemHp = st.state.enemies[0].maxHp;
      final golemBreak = st.state.enemies[0].breakBase;
      final slimeAtk = st.state.enemies[1].attack;
      ZoneRules.scaleBattle(st.state, 13);
      final g = st.state.enemies[0], s = st.state.enemies[1];
      final hf = ZoneRules.hpScale(13) / ZoneRules.hpScale(4);
      expect(g.maxHp, jsRound(golemHp * hf));
      expect(g.hp, g.maxHp);
      // Quiebre en puntos (combo_balance.md § 5): no escala con la vida.
      expect(g.breakBase, golemBreak);
      expect(s.attack, jsRound(slimeAtk * ZoneRules.atkScale(13)));
      // Nivel 0: sin cambios; debajo del nativo: nunca baja.
      final st2 = b.start(party: [partyOf('guerrero')], enemyTypes: ['ghost']);
      final hp = st2.state.enemies[0].maxHp;
      ZoneRules.scaleBattle(st2.state, 0);
      expect(st2.state.enemies[0].maxHp, hp);
      ZoneRules.scaleBattle(st2.state, 2);
      expect(st2.state.enemies[0].maxHp, hp);
    });

    test('XP: xpFactor × bonus del mundo', () {
      expect(ZoneRules.xpMult(0), 1);
      expect(ZoneRules.xpMult(1), 1);
      expect(ZoneRules.xpMult(5), closeTo(1.6, 1e-9));
      expect(ZoneRules.xpMult(10), closeTo(2.35 * 1.375, 1e-9));
      expect(ZoneRules.xpMult(25), closeTo(4.6 * 1.75, 1e-9));
      expect(ZoneRules.battleXp(20, 13), jsRound(20 * 2.8 * 1.6));
    });

    test('ritmo: ~nivel 25 en una tarde (2 pasadas por zona 1–5)', () {
      // worldgen.md § 6.3: 5 grupos por piso, media élite por piso, jefe.
      const groupXp = [14, 18, 19, 24, 30];
      const eliteXp = [27, 34, 56, 70, 90];
      const bossXp = [72, 106, 134, 180, 220];
      var level = 1, xp = 0;
      final after = <int>[];
      for (var zi = 0; zi < 5; zi++) {
        final z = cat.zones[zi];
        for (var run = 0; run < 2; run++) {
          var gained = 0.0;
          for (var f = 0; f < z.floors; f++) {
            final l = ZoneRules.floorLevel(z, f);
            gained += (5 * groupXp[zi] + 0.5 * eliteXp[zi]) * ZoneRules.xpMult(l);
          }
          gained += bossXp[zi] * ZoneRules.xpMult(z.maxLevel);
          xp += gained.round();
          while (level < ProgressionRules.maxLevel &&
              xp >= ProgressionRules.xpNeed(level)) {
            xp -= ProgressionRules.xpNeed(level);
            level++;
          }
          after.add(level);
        }
      }
      // Al salir de cada zona el grupo está en su rango (o apenas arriba).
      for (var zi = 0; zi < 5; zi++) {
        expect(after[zi * 2 + 1], inInclusiveRange(cat.zones[zi].maxLevel - 1,
            cat.zones[zi].maxLevel + 2), reason: 'zona ${zi + 1}: $after');
      }
      expect(after.last, inInclusiveRange(24, 28));
    });
  });

  group('desbloqueo por perfil', () {
    test('perfil nuevo: zona 1; solo propone lo desbloqueado y jugable', () {
      final p = newProfile('Ana', 'guerrero');
      expect(p.unlockedZone, 1);
      expect(ZoneRules.canPropose(cat, p, 'm1'), isTrue);
      expect(ZoneRules.canPropose(cat, p, 'z2'), isFalse);
      final p5 = p.copyWith(unlockedZone: 10);
      expect(ZoneRules.canPropose(cat, p5, 'z5'), isTrue);
      expect(ZoneRules.canPropose(cat, p5, 'nada'), isFalse);
      final list = ZoneRules.zoneList(cat, p);
      expect(list, hasLength(10));
      expect(list[0].open, isTrue);
      expect(list[0].label, '');
      expect(list[1].open, isFalse);
      expect(list[1].label, 'Bloqueada: vencé a Rey Limo en Pradera Esmeralda');
      expect(list[5].playable, isTrue);
      expect(ZoneRules.zoneList(cat, p5)[5].label, '');
      expect(ZoneRules.zoneList(cat, p5)[9].open, isTrue);
      expect(ZoneRules.canPropose(cat, p5, 'z10'), isTrue);
    });

    test('JSON: zu ida y vuelta; migración de perfiles viejos por nivel', () {
      final p = newProfile('Ana', 'guerrero').copyWith(unlockedZone: 4);
      final back = PlayerProfile.fromJson(
          jsonDecode(jsonEncode(p.toJson())) as Map<String, Object?>);
      expect(back.unlockedZone, 4);
      expect(p.toJson()['zu'], 4);
      Map<String, Object?> old(int lvl) =>
          {'name': 'Viejo', 'cls': 'maga', 'lvl': lvl, 'xp': 0, 'cr': 10};
      expect(PlayerProfile.fromJson(old(1)).unlockedZone, 1);
      expect(PlayerProfile.fromJson(old(5)).unlockedZone, 1);
      expect(PlayerProfile.fromJson(old(8)).unlockedZone, 2);
      expect(PlayerProfile.fromJson(old(16)).unlockedZone, 4);
      expect(PlayerProfile.fromJson(old(40)).unlockedZone, 5);
      // normalize lo conserva; fuera de rango se recorta.
      expect(zoneProgression.normalize(back).unlockedZone, 4);
      expect(PlayerProfile.fromJson({...p.toJson(), 'zu': 99}).unlockedZone, 10);
      expect(PlayerProfile.fromJson({...p.toJson(), 'zu': 0}).unlockedZone, 1);
    });
  });
}
