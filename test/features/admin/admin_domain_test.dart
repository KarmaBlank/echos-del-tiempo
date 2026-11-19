import 'dart:convert';

import 'package:echos_del_tiempo/features/admin/domain/admin_index.dart';
import 'package:echos_del_tiempo/features/admin/domain/balance_diff.dart';
import 'package:echos_del_tiempo/features/admin/domain/impact_preview.dart';
import 'package:echos_del_tiempo/features/admin/domain/monitoring.dart';
import 'package:echos_del_tiempo/features/admin/domain/release_plan.dart';
import 'package:echos_del_tiempo/game_engine/balance/balance_codecs.dart';
import 'package:echos_del_tiempo/game_engine/balance/balance_patch.dart';
import 'package:echos_del_tiempo/game_engine/balance/balance_registries.dart';
import 'package:echos_del_tiempo/game_engine/data/game_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

BalancePatch _patch(Map<String, Object?> overrides) => BalancePatch.parse(
        jsonEncode({'schema': 1, 'overrides': overrides}), BalanceBase.standard())
    .patch;

void main() {
  tearDown(BalanceRegistries.restore);

  group('diff y notas de parche', () {
    test('Golpe Sísmico: poder 1.2 → 1.4 y desactivaciones', () {
      final base = BalanceBase.standard();
      final to = _patch({
        'skill': {
          'sismo': {'power': 1.4, 'mp': 5},
          'giro': {'disabled': true},
          'chispa': {
            'status': {'kind': 'burn', 'stacks': 2}
          },
        },
        'enemy': {
          'slime': {'hp': 32, 'armor': 0.1}
        },
        'affix': {
          'veloz': {'disabled': true}
        },
      });
      final changes = diffBalance(base, BalancePatch.empty, to);
      final sismo = changes.where((c) => c.id == 'sismo').toList();
      expect(sismo.map((c) => c.field.key), ['mp', 'power'],
          reason: 'en el orden de los campos del codec');
      expect(sismo.last.beforeText, '1.2');
      expect(sismo.last.afterText, '1.4');
      expect(sismo.last.increased, isTrue);
      expect(sismo.first.increased, isFalse);

      final notes = buildPatchNotes(version: '0.5.1', changes: changes);
      expect(notes, startsWith('# Ecos del Tiempo v0.5.1 — Parche de balance'));
      expect(notes, contains('## Habilidades'));
      expect(notes, contains('- **Golpe Sísmico**: MP 6 → 5; poder 1.2 → 1.4.'));
      expect(notes, contains('- **Chispa**: estado Quemadura ×1 → Quemadura ×2.'));
      expect(notes, contains('- **Corte Giratorio**: desactivada (ya no la otorgan las armas).'));
      expect(notes, contains('## Enemigos'));
      expect(notes, contains('- **Limo**: vida 30 → 32; armadura 0% → 10%.'));
      expect(notes, contains('desactivado (ya no sale en drops ni crafteo)'));
      // Enemigos después de habilidades (orden de los tipos).
      expect(notes.indexOf('## Enemigos'), greaterThan(notes.indexOf('## Habilidades')));
    });

    test('sin cambios → notas que lo dicen; mismo parche → diff vacío', () {
      final p = _patch({
        'skill': {
          'sismo': {'power': 1.4}
        }
      });
      expect(diffBalance(BalanceBase.standard(), p, p), isEmpty);
      expect(buildPatchNotes(version: '1.0.1', changes: const []),
          contains('Sin cambios de balance.'));
    });
  });

  group('plan de release', () {
    test('versión del pubspec y la siguiente', () {
      expect(ReleasePlan.pubspecVersion('name: x\nversion: 0.5.0+7\n'), '0.5.0');
      expect(ReleasePlan.next('0.5.0'), '0.5.1');
      expect(ReleasePlan.next('0.5.9'), '0.5.10');
      expect(ReleasePlan.next('0.5.3', minor: true), '0.6.0');
    });

    test('comandos exactos', () {
      const p = ReleasePlan('0.5.1');
      expect(p.notesPath, 'docs/patch_notes/v0.5.1.md');
      final all = p.steps().expand((s) => s.commands).toList();
      expect(all, contains('git checkout -b balance/v0.5.1'));
      expect(all, contains('git add assets/balance/balance.json docs/patch_notes/v0.5.1.md'));
      expect(all, contains(r'.\tool\release.ps1 -Version 0.5.1 -NotesFile docs\patch_notes\v0.5.1.md -DryRun'));
      expect(p.scriptArgs(dryRun: true), containsAllInOrder(['-Version', '0.5.1', '-DryRun']));
      expect(p.scriptArgs(dryRun: false), isNot(contains('-DryRun')));
    });
  });

  group('monitoreo', () {
    test('releases de GitHub con descargas', () {
      final list = GithubRelease.parseList(jsonEncode([
        {
          'tag_name': 'v0.5.0',
          'name': 'Ecos del Tiempo v0.5.0',
          'published_at': '2026-11-01T10:00:00Z',
          'prerelease': false,
          'html_url': 'https://github.com/x',
          'assets': [
            {'name': 'EcosDelTiempo-Setup-0.5.0.exe', 'download_count': 12, 'size': 100},
            {'name': 'EcosDelTiempo-Setup-0.5.0.exe.sha256', 'download_count': 3, 'size': 1},
          ],
        },
        {'tag_name': 'v0.4.0', 'assets': []},
        'basura',
      ]));
      expect(list.map((r) => r.tag), ['v0.5.0', 'v0.4.0']);
      expect(list.first.installerDownloads, 12);
      expect(list.first.downloads, 15);
      expect(list.first.publishedAt, DateTime.utc(2026, 11, 1, 10));
      expect(() => GithubRelease.parseList('{"message":"API rate limit exceeded"}'),
          throwsA(isA<FormatException>().having((e) => e.message, 'm', contains('rate limit'))));
    });

    test('ecos.log', () {
      final lines = LogLine.parseAll(
          '2026-11-18T10:00:00.000 INFO Inicio del juego\n'
          '2026-11-18T10:01:00.000 ERROR Balance: ERROR skill.x: no existe\n'
          'línea rara\n');
      expect(lines.length, 3);
      expect(lines[1].level, 'ERROR');
      expect(lines[1].message, startsWith('Balance:'));
      expect(lines[2].level, '');
    });

    test('contar salas: 403 = reglas; 200 = número', () {
      expect(RoomCount.parse(403, '{}').denied, isTrue);
      final ok = RoomCount.parse(200, jsonEncode([
        {
          'result': {
            'aggregateFields': {
              'n': {'integerValue': '7'}
            }
          }
        }
      ]));
      expect(ok.count, 7);
      expect(RoomCount.parse(500, '').error, 'HTTP 500');
    });
  });

  group('navegador', () {
    test('índice con todos los tipos y búsqueda sin tildes', () {
      final index = buildAdminIndex(BalanceBase.standard());
      final kinds = {for (final e in index) e.category};
      expect(kinds, containsAll([for (final k in BalanceKind.values) k.jsonKey]));
      expect(kinds, contains(AdminEntry.ascensionCategory));
      final hits = index.where((e) => e.matches('golpe sismico')).toList();
      expect(hits.map((e) => e.id), contains('sismo'));
      final berserker = index.firstWhere((e) => e.id == 'berserker');
      expect(berserker.links, contains((BalanceKind.skill, 'sangria')));
    });
  });

  group('vista previa de impacto', () {
    test('más poder → más daño por uso y menos acciones para ganar', () {
      final before = ImpactSimulator(GameCatalog.standard);
      final buffed = ImpactSimulator(_patch({
        'skill': {
          'sismo': {'power': 2.4}
        }
      }).applyTo(GameCatalog.standard));
      const l = SimLoadout(
          classId: 'guerrero', level: 8, weaponId: 'hacha_rompe', skillId: 'sismo');
      final a = before.hit(l, enemyId: 'golem', skillId: 'sismo')!;
      final b = buffed.hit(l, enemyId: 'golem', skillId: 'sismo')!;
      expect(b.normal, greaterThan(a.normal));
      expect(a.crit, greaterThan(a.normal));
      expect(a.mp, 6);

      final sa = before.simulate(l, enemies: ['golem', 'golem'], enemyLevel: 8, runs: 12);
      final sb = buffed.simulate(l, enemies: ['golem', 'golem'], enemyLevel: 8, runs: 12);
      expect(sa.runs, 12);
      expect(sb.avgDamagePerAction, greaterThan(sa.avgDamagePerAction));
      // Determinista: mismas semillas, mismo resultado.
      final again = before.simulate(l, enemies: ['golem', 'golem'], enemyLevel: 8, runs: 12);
      expect(again.wins, sa.wins);
      expect(again.avgActions, sa.avgActions);
    });

    test('simulador: grupo mixto, quiebres y jefe quebrado antes de su ULT '
        '(combo_balance.md § 5)', () {
      final sim = ImpactSimulator(GameCatalog.standard);
      const g = SimLoadout(
          classId: 'guerrero', level: 10, weaponId: 'hacha_rompe', skillId: 'sismo');
      const m = SimLoadout(
          classId: 'maga', level: 10, weaponId: 'baculo_fuego', skillId: 'bola');
      final r = sim.simulate(g,
          enemies: const ['reyLimo', 'slime'],
          enemyLevel: 10,
          party: const [g, m, g, m],
          runs: 6);
      expect(r.runs, 6);
      expect(r.bossRuns, 6);
      expect(r.bossEarlyBreaks, inInclusiveRange(0, 6));
      expect(r.avgBreaks, greaterThanOrEqualTo(0));
      expect(r.bossEarlyBreakRate, r.bossEarlyBreaks / 6);
      // Sin jefe con ULT no cuenta.
      final c = sim.simulate(g, enemies: const ['slime'], enemyLevel: 10, runs: 2);
      expect(c.bossRuns, 0);
    });
    test('personaje típico: ⅔ al atributo principal del arma y ⅓ a VIT', () {
      final sim = ImpactSimulator(GameCatalog.standard);
      final w = GameCatalog.standard.weapons['hacha_rompe']!;
      final base = sim.typicalAttributes('guerrero', 1, w);
      final at10 = sim.typicalAttributes('guerrero', 10, w);
      const points = 9 * 3;
      final dFue = at10.values.entries
          .map((e) => e.value - base[e.key])
          .reduce((a, b) => a + b);
      expect(dFue, points);
    });
  });
}
