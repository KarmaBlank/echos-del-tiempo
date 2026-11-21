import 'package:echos_del_tiempo/app/theme/proto_colors.dart';
import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/features/combat/domain/skill_text.dart';
import 'package:echos_del_tiempo/features/combat/presentation/battle_hud.dart';
import 'package:echos_del_tiempo/features/combat/presentation/enemy_live_info.dart';
import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/enemies_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/skills_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/player_state.dart';
import 'package:echos_del_tiempo/game_engine/models/skill.dart';
import 'package:echos_del_tiempo/game_engine/models/status.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Tooltip del enemigo (ULT que prepara, mecánica, estados) y número de
/// crítico del panel de habilidades (battle_ui.md).

BattlePartyMember member(String classId) {
  final cls = kClasses[classId]!;
  return BattlePartyMember(
    id: classId,
    name: cls.name,
    potions: 1,
    ethers: 1,
    build: PlayerBuild(
      classId: classId,
      level: 1,
      attributes: PlayerAttributes.base(cls.baseAttributes),
      equippedWeapon: kWeapons[cls.startWeaponId]!,
    ),
  );
}

void main() {
  final bossId = kEnemies.values
      .firstWhere((d) =>
          d.boss && d.ultId != null && bossMechanicOf(d) != null)
      .id;

  BattleState start() => BattleEngine(
        stats: StatsCalculator(
            classes: kClasses, treeRules: PassiveTreeRules(kPassiveTree)),
        random: () => 0.99,
      )
          .start(
              party: [member('guerrero')],
              enemyTypes: [bossId],
              triggeredBy: 'guerrero')
          .state;

  Future<void> pump(WidgetTester tester, Widget w) => tester.pumpWidget(
      MaterialApp(theme: RetroTheme.build(), home: Scaffold(body: w)));

  testWidgets(
      'estados: uno por fila, nombre y color estándar, plegables (v0.20.6)',
      (tester) async {
    final e = start().enemies.first
      ..statuses[StatusKind.burn] = 2
      ..statuses[StatusKind.poison] = 1
      ..statuses[StatusKind.holy] = 3;
    Color? colorOf(StatusKind k) {
      Color? found;
      for (final rt in tester.widgetList<RichText>(find.descendant(
          of: find.byKey(ValueKey('enemy-live-status-name-${k.name}')),
          matching: find.byType(RichText)))) {
        // El tramo más interno con color que contiene el nombre.
        void walk(InlineSpan s) {
          if (s is! TextSpan) return;
          if (s.style?.color != null && s.toPlainText().contains(k.label)) {
            found = s.style!.color;
          }
          for (final c in s.children ?? const <InlineSpan>[]) {
            walk(c);
          }
        }

        walk(rt.text);
      }
      return found;
    }

    await pump(tester, EnemyLiveInfo(enemy: e));
    const kinds = [StatusKind.burn, StatusKind.poison, StatusKind.holy];
    final tops = <double>[];
    for (final k in kinds) {
      final row = find.byKey(ValueKey('enemy-live-status-${k.name}'));
      expect(row, findsOneWidget);
      tops.add(tester.getTopLeft(row).dy);
      expect(colorOf(k), ProtoColors.parse(statusHex(k)), reason: k.label);
      expect(find.byKey(ValueKey('enemy-live-status-desc-${k.name}')),
          findsNothing);
    }
    // En columna: cada uno más abajo que el anterior.
    expect(tops[0] < tops[1] && tops[1] < tops[2], isTrue);
    // Desplegados: qué hace cada uno.
    await pump(tester, EnemyLiveInfo(enemy: e, open: true));
    for (final k in kinds) {
      final desc = find.byKey(ValueKey('enemy-live-status-desc-${k.name}'));
      expect(desc, findsOneWidget);
      expect(tester.widget<Text>(desc).data,
          contains(statusDescriptionOf(k).substring(0, 12)));
    }
  });

  testWidgets('prepara ULT (plegada), mecánica y estados con nombre',
      (tester) async {
    final e = start().enemies.firstWhere((x) => x.boss);
    e
      ..ultPending = true
      ..statuses[StatusKind.burn] = 3;
    await pump(tester, EnemyLiveInfo(enemy: e));
    final ult = kEnemyUlts[e.ultId]!;
    expect(find.text('Prepara ${ult.name}: la lanza en su turno'),
        findsOneWidget);
    expect(find.byKey(const ValueKey('enemy-live-ult-detail')), findsNothing);
    expect(find.byKey(const ValueKey('enemy-live-mech')), findsOneWidget);
    expect(
        find.textContaining('${StatusKind.burn.label} ×3', findRichText: true),
        findsOneWidget);
    // Desplegado: qué hace y cómo cancelarla.
    await pump(tester, EnemyLiveInfo(enemy: e, open: true));
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('enemy-live-ult-detail')),
            matching: find.textContaining('Cancelala', findRichText: true)),
        findsOneWidget);
  });

  testWidgets('insignia abreviada: hover muestra el nombre completo',
      (tester) async {
    final e = start().enemies.first..statuses[StatusKind.burn] = 2;
    final chip = combatantChips(e).first;
    await pump(tester, Center(child: StatusChipView(chip)));
    final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await g.addPointer(location: Offset.zero);
    addTearDown(g.removePointer);
    await g.moveTo(tester.getCenter(find.byType(StatusChipView)));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining(StatusKind.burn.label, findRichText: true),
        findsWidgets);
  });

  test('crítico: probabilidad efectiva y número; curas sin crítico', () {
    final p = start().party.first
      ..critChance = 0.1
      ..critMultiplier = 1.5;
    final dmg = kSkills.values.firstWhere((s) =>
        s.kind == SkillKind.physical && s.charge == 0 && s.power > 0);
    final txt = describeSkillMarkup(dmg, p);
    final pct = ((0.1 + dmg.critBonus).clamp(0.0, 1.0) * 100).round();
    expect(txt, contains('Crítico $pct%: '));
    final heal = kSkills.values.firstWhere((s) => s.kind == SkillKind.heal);
    expect(describeSkillMarkup(heal, p), isNot(contains('Crítico')));
    final multi = kSkills.values.where((s) => s.hits > 1).firstOrNull;
    if (multi != null) {
      expect(describeSkillMarkup(multi, p), contains('en total'));
    }
    final charged = kSkills.values.where((s) => s.charge > 0).firstOrNull;
    if (charged != null) {
      expect(describeSkillMarkup(charged, p), contains('Crítico'));
    }
    expect(critLineMarkup(p, 100), contains('Crítico 10%: 150'));
  });
}
