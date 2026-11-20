// ignore_for_file: avoid_print
// Medición para docs/specs/achievements.md § 4 (créditos por misión). No es
// parte de la suite. Correr con
//   flutter test tool/hazanas_economia_measure_test.dart
// Arma cada misión de zona con el motor real (mismas semillas que el
// juego) y suma lo que paga: batallas (enemigos del mapa, élite ×3, jefe),
// cofres del mapa (promedio de la tirada × calidad), la misión opcional y
// el bonus de rango A (25 %). No juega las batallas: es el techo de una
// misión limpia.
import 'package:echos_del_tiempo/game_engine/data/achievements_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/exploration_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/game_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/zones_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/achievement.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/game_engine/session_test_helpers.dart';

void main() {
  test('créditos por misión de zona', () {
    final enemies = GameCatalog.standard.enemies;
    final totals = <int>[];
    for (final def in kZoneMissions) {
      final perSeed = <int>[];
      for (var seed = 1; seed <= 5; seed++) {
        final e = sessionEngine(zones: true, seed: seed * 7919);
        final prof = zoneProgression.normalize(PlayerProfile(
            name: 'Ana',
            classId: 'guerrero',
            level: def.recommendedLevel,
            unlockedZone: 10));
        GameSession s;
        try {
          s = inField(e, def.id, profiles: [prof]);
        } catch (_) {
          continue;
        }
        final m = s.mission!;
        // Lo justo: los grupos que pide el objetivo (promedio de los del
        // mapa) más el jefe; el resto del mapa no se pelea.
        var normal = 0, nGroups = 0, boss = 0;
        for (final f in m.enemies) {
          var g = 0;
          for (var i = 0; i < f.group.length; i++) {
            final c = enemies[f.group[i]]?.credits ?? 0;
            g += c * (f.elite && i == 0 ? 3 : 1);
          }
          if (f.boss) {
            boss += g;
          } else {
            normal += g;
            nGroups++;
          }
        }
        final goal = def.floorGoal > 0 ? def.floorGoal * def.floors : def.goal;
        final battle =
            (nGroups == 0 ? 0 : normal / nGroups * goal).round() + boss;
        var chests = 0.0;
        for (final it in m.items) {
          if (it.kind != MissionItemKind.chest) continue;
          final d = kChestTiers[it.tier]!;
          chests += (20 + 15 + def.chestTier * 10) * d.creditMult / 2; // la mitad
        }
        final quest = kQuestCreditsBase + kQuestCreditsPerLevel * m.zoneLevel;
        final bonus = battle * 0.25;
        perSeed.add((battle + chests + quest + bonus).round());
      }
      if (perSeed.isEmpty) continue;
      perSeed.sort();
      final med = perSeed[perSeed.length ~/ 2];
      totals.add(med);
      print('${def.id.padRight(4)} nv ${def.recommendedLevel.toString().padLeft(2)}'
          '  ₵$med  (${perSeed.join(', ')})');
    }
    totals.sort();
    var sum = const AchievementReward();
    for (final a in kAchievements) {
      sum += a.reward;
    }
    final mid = totals.sublist(totals.length ~/ 4, totals.length * 3 ~/ 4);
    final avgMid = mid.reduce((a, b) => a + b) / mid.length;
    print('mediana ₵${totals[totals.length ~/ 2]} · mitad de juego ₵${avgMid.round()}');
    print('total hazañas ₵${sum.credits} ≈ ${(sum.credits / avgMid).toStringAsFixed(1)} misiones');
  });
}
