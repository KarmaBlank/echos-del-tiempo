import 'dart:io';

import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/app/theme/text_detail_scope.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/core/text/plain_text.dart';
import 'package:echos_del_tiempo/features/combat/domain/skill_text.dart';
import 'package:echos_del_tiempo/features/inventory/domain/item_text.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/skill_chip.dart';
import 'package:echos_del_tiempo/features/passive_tree/domain/passive_text.dart';
import 'package:echos_del_tiempo/game_engine/data/game_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_mechanics.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/skill.dart';
import 'package:echos_del_tiempo/game_engine/models/status.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Texto sin markup (lo que lee el jugador).
String _plain(String markup) => markup
    .replaceAll('<br>', '\n')
    .replaceAll(RegExp(r'<[^>]+>'), '')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&amp;', '&');

/// Sin la cabecera (nombre y costo).
String _body(String markup) => _plain(markup).split('\n').skip(1).join('\n');

void _expectShort(String text, {int maxLines = 2}) {
  final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
  expect(lines.length, lessThanOrEqualTo(maxLines), reason: text);
  for (final l in lines) {
    // Whole sentences (v0.36.1): never cut with an ellipsis, at most
    // two short lines.
    expect(l.contains('…'), isFalse, reason: l);
    expect(l.length, lessThanOrEqualTo(kShortMaxChars * 2), reason: l);
    for (final tok in kFormulaTokens) {
      expect(l.contains(tok), isFalse, reason: '"$tok" en "$l"');
    }
  }
}

void main() {
  final skills = GameCatalog.standard.skills.values.toList();
  final ults = GameCatalog.standard.ultimates.values.toList();
  tearDown(() => TextDetail.current = TextDetail.full);

  group('generador RESUMIDO', () {
    test('habilidades representativas: 1-2 líneas cortas, sin fórmulas', () {
      final sample = [
        skills.firstWhere((s) => s.kind == SkillKind.physical && s.power > 0),
        skills
            .firstWhere((s) => s.kind == SkillKind.magical && s.status != null),
        skills.firstWhere((s) => s.kind == SkillKind.heal),
        skills.firstWhere((s) => s.kind == SkillKind.support),
        ...ults.take(3),
      ];
      for (final s in sample) {
        final full = describeSkillMarkup(s, null);
        final short = TextDetail.run(
            TextDetail.summary, () => describeSkillMarkup(s, null));
        expect(short.length, lessThanOrEqualTo(full.length), reason: s.id);
        _expectShort(_body(short));
      }
    });

    test('todas las habilidades y ULT del catálogo cumplen la regla', () {
      TextDetail.current = TextDetail.summary;
      for (final s in [...skills, ...ults]) {
        _expectShort(_body(describeSkillMarkup(s, null)));
      }
    });

    test('estados: una línea simple', () {
      TextDetail.current = TextDetail.summary;
      for (final k in StatusKind.values) {
        _expectShort(statusDescriptionOf(k), maxLines: 1);
      }
      expect(statusFullDescriptionOf(StatusKind.burn), contains('stack'));
    });

    test('pasivas, keystones y mecánicas', () {
      TextDetail.current = TextDetail.summary;
      final nodes = kPassiveTree.nodes.values;
      final picks = [
        nodes.firstWhere((n) => n.effects['atk'] != null),
        nodes.firstWhere((n) => n.keystoneId != null),
        nodes.firstWhere((n) => n.mechanicId != null && n.keystoneId == null),
      ];
      for (final n in picks) {
        for (final l in passiveEffectsText(n)) {
          _expectShort(l, maxLines: 1);
        }
      }
      for (final m in kMechanics.values) {
        _expectShort(plainShort(m.description), maxLines: 1);
      }
    });

    test('mods: sin abreviaturas ni fórmulas', () {
      TextDetail.current = TextDetail.summary;
      expect(modShort('+12% ATQ'), '+12% ataque');
      expect(modShort('+3 DEF'), '+3 defensa');
      _expectShort(modShort('Golpe de luz: MAG × 0.8 a todos (3 turnos).'),
          maxLines: 1);
      TextDetail.current = TextDetail.full;
      expect(modShort('+12% ATQ'), '+12% ATQ');
    });
  });

  group('ajuste TEXTOS', () {
    test('por defecto RESUMIDO, también con un game.json viejo; se guarda',
        () async {
      expect(const GameSettings().textDetail, TextDetail.summary);
      expect(GameSettings.fromJson(const {'crt': 'normal'}).textDetail,
          TextDetail.summary);
      expect(GameSettings.fromJson(const {'textDetail': 'basura'}).textDetail,
          TextDetail.summary);
      final dir = await Directory.systemTemp.createTemp('ecos_textdetail_');
      addTearDown(() => dir.delete(recursive: true));
      final file = JsonFileGameSettingsStore.inDirectory(dir.path);
      const s = GameSettings(textDetail: TextDetail.full);
      await file.save(s);
      expect((await file.load())!.textDetail, TextDetail.full);
      expect(s.toJson()['textDetail'], 'full');
    });

    testWidgets('cambiar TEXTOS cambia el tooltip de una habilidad',
        (tester) async {
      final sk = skills.firstWhere(
          (s) => s.kind == SkillKind.physical && s.power > 0 && s.charge == 0);
      final mode = ValueNotifier(TextDetail.summary);
      await tester.pumpWidget(MaterialApp(
        theme: RetroTheme.build(),
        home: Scaffold(
          body: ValueListenableBuilder<TextDetail>(
            valueListenable: mode,
            builder: (_, m, __) => TextDetailScope(
                mode: m, child: Center(child: SkillChip(skill: sk))),
          ),
        ),
      ));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      Future<void> hover() async {
        await mouse.moveTo(Offset.zero);
        await tester.pumpAndSettle();
        await mouse.moveTo(
            tester.getCenter(find.byKey(ValueKey('skill-chip-${sk.id}'))));
        await tester.pumpAndSettle();
      }

      await hover();
      expect(find.textContaining('de tu ataque', findRichText: true),
          findsWidgets);
      expect(
          find.textContaining('S DETALLE', findRichText: true), findsOneWidget);
      expect(find.textContaining('Físico · a 1 enemigo', findRichText: true),
          findsNothing);

      mode.value = TextDetail.full;
      await tester.pumpAndSettle();
      await hover();
      expect(find.textContaining('Físico · a 1 enemigo', findRichText: true),
          findsWidgets);
      expect(
          find.textContaining('S DETALLE', findRichText: true), findsNothing);
    });
  });
}
