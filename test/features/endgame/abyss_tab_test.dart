import 'package:echos_del_tiempo/app/theme/panel_frame.dart';
import 'package:echos_del_tiempo/features/endgame/presentation/eco_portal_panel.dart';
import 'package:echos_del_tiempo/features/missions/presentation/results_panel.dart';
import 'package:echos_del_tiempo/game_engine/data/abyss_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/loot_filter.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/rules/abyss_rules.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../../real_fonts.dart';
import '../inventory/loot_fixtures.dart';
import '../panel_test_harness.dart';

/// Pestaña ABISMO del Portal del Eco (docs/specs/abyss_bosses.md § 4).

const _shown = FilterVerdict(true, FilterStyle());

PlayerProfile _hero({Map<CraftMaterial, int> mats = const {}, Set<int> kills = const {}}) {
  final p = zoneProgression.normalize(PlayerProfile(name: 'Ana', classId: 'guerrero', level: 50));
  return zoneProgression
      .allocate(p, {Attribute.vit: p.points})!
      .copyWith(ecosUnlocked: true, materials: mats, abyssKills: kills);
}

Future<void> _key(WidgetTester tester, LogicalKeyboardKey k) async {
  await tester.sendKeyEvent(k);
  await tester.pump();
}

String? _focusedKey() {
  final ctx = FocusManager.instance.primaryFocus?.context;
  if (ctx?.widget.key case final ValueKey<String> k) return k.value;
  String? found;
  ctx?.visitAncestorElements((e) {
    final k = e.widget.key;
    if (k is ValueKey<String>) {
      found = k.value;
      return false;
    }
    return true;
  });
  return found;
}

void main() {
  testWidgets('ABISMO: Fragmentos, 5 tarjetas, secreto oculto y requisitos', (tester) async {
    await pumpPanel(tester,
        profile: _hero(mats: {CraftMaterial.fragReloj: 3}),
        engine: sessionEngine(zones: true),
        textSize: TextSize.normal,
        build: (v, c) => EcoPortalPanel(view: v, controller: c, initialTab: EcoPortalTab.abismo));
    expect(plain(tester, 'abyss-fragments'), contains('Reloj 3'));
    for (final n in kAbyssBosses.keys) {
      expect(find.byKey(ValueKey('abyss-card-$n')), findsOneWidget);
    }
    expect(find.textContaining('??? · Jefe secreto'), findsWidgets);
    expect(plain(tester, 'abyss-detail'), contains('Gólem Reloj del Abismo'));
    expect(plain(tester, 'abyss-detail'), contains('Manecilla del Abismo'));
    expect(button(tester, 'abyss-open').reason, 'Faltan Fragmento del Reloj (3/5)');
    // El secreto: requisito.
    await tapVisible(tester, find.byKey(const ValueKey('abyss-card-5')));
    expect(plain(tester, 'abyss-detail'), contains('vencer a los 4 Jefes del Abismo (0/4)'));
    expect(button(tester, 'abyss-open').reason, 'Vencé a los 4 Jefes del Abismo');
    // Sin devTools no hay atajos.
    expect(find.byKey(const ValueKey('abyss-dev-frag')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ABRIR pide confirmar el costo y propone al grupo', (tester) async {
    final c = await pumpPanel(tester,
        profile: _hero(mats: {CraftMaterial.fragEco: 5}),
        engine: sessionEngine(zones: true),
        build: (v, c) => EcoPortalPanel(view: v, controller: c, initialTab: EcoPortalTab.abismo));
    await tapVisible(tester, find.byKey(const ValueKey('abyss-card-2')));
    expect(button(tester, 'abyss-open').reason, isNull);
    await tapVisible(tester, find.byKey(const ValueKey('abyss-open')));
    expect(plain(tester, 'abyss-confirm-text'), contains('5 Fragmento del Eco'));
    // Cancelar no propone nada.
    await tapVisible(tester, find.byKey(const ValueKey('abyss-cancel')));
    expect(c.session!.vote, isNull);
    await tapVisible(tester, find.byKey(const ValueKey('abyss-open')));
    await tapVisible(tester, find.byKey(const ValueKey('abyss-confirm')));
    expect(c.session!.vote?.missionId, AbyssRules.missionId);
    expect(c.session!.abyss, 2);
    // No se consume hasta empezar.
    expect(c.session!.players.values.first.profile.material(CraftMaterial.fragEco), 5);
  });

  testWidgets('vencidos: nombre y sprite; el secreto aparece tras los 4', (tester) async {
    await pumpPanel(tester,
        profile: _hero(kills: {1, 2, 3, 4}, mats: {for (final f in kFragments) f: 1}),
        engine: sessionEngine(zones: true),
        build: (v, c) => EcoPortalPanel(view: v, controller: c, initialTab: EcoPortalTab.abismo));
    expect(find.textContaining('??? · Jefe secreto'), findsNothing);
    await tapVisible(tester, find.byKey(const ValueKey('abyss-card-1')));
    expect(plain(tester, 'abyss-detail'), contains('(vencido)'));
    await tapVisible(tester, find.byKey(const ValueKey('abyss-card-5')));
    expect(plain(tester, 'abyss-detail'), contains('Prisma Primordial'));
    expect(button(tester, 'abyss-open').reason, isNull);
  });

  testWidgets('teclado: 3 abre ABISMO, flechas recorren las tarjetas, Enter elige', (tester) async {
    await pumpPanel(tester,
        profile: _hero(),
        engine: sessionEngine(zones: true),
        build: (v, c) => EcoPortalPanel(view: v, controller: c));
    await _key(tester, LogicalKeyboardKey.digit3);
    await tester.pump();
    expect(tester.widget<PanelButton>(find.byKey(const ValueKey('tab-2'))).selected, isTrue);
    expect(find.byKey(const ValueKey('abyss-view')), findsOneWidget);
    // El foco entra a las tarjetas y Enter elige la que tiene el foco.
    for (var i = 0; i < 6 && !(_focusedKey()?.startsWith('abyss-card-') ?? false); i++) {
      await _key(tester, LogicalKeyboardKey.tab);
    }
    expect(_focusedKey(), startsWith('abyss-card-'));
    await _key(tester, LogicalKeyboardKey.arrowDown);
    final k = _focusedKey()!;
    expect(k, startsWith('abyss-card-'));
    await _key(tester, LogicalKeyboardKey.enter);
    final n = int.parse(k.split('-').last);
    expect(plain(tester, 'abyss-detail'),
        contains(n == 5 ? 'Jefe secreto' : kAbyssBosses[n]!.name));
  });

  testWidgets('resultado: el exclusivo se destaca y la línea del Abismo', (tester) async {
    await loadRealFonts(tester);
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final r = MissionResult(
      id: 1,
      missionId: AbyssRules.missionId,
      missionName: 'Gólem Reloj del Abismo',
      success: true,
      rank: MissionRank.a,
      time: 200,
      xp: 9000,
      credits: 1200,
      bonus: 300,
      bonusPercent: 0.25,
      kos: 0,
      elites: 0,
      eliteDrops: const [],
      drops: const {},
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ResultsPanel(
          result: r,
          localId: 'local',
          playerName: (id) => 'Ana',
          weaponName: (id) => id,
          onBack: () {},
          abyss: 'Gólem Reloj del Abismo vencido: +1 punto de Atlas',
          loot: const [
            ResultDrop('Manecilla del Abismo', _shown, exclusive: true),
            ResultDrop('2 Esencia del Abismo', _shown),
          ],
        ),
      ),
    ));
    expect(find.byKey(const ValueKey('results-exclusive')), findsOneWidget);
    expect(find.textContaining('EXCLUSIVO DEL ABISMO'), findsOneWidget);
    expect(find.byKey(const ValueKey('results-abyss')), findsOneWidget);
    expect(ResultsPanel.isFinalVictory(r), isFalse);
    expect(tester.takeException(), isNull);
  });
}
