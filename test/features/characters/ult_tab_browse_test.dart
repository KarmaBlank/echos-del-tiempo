// Pestaña ULT rediseñada (docs/specs/ultimates_v2.md § 2.1.1): ULT
// EQUIPADA fija arriba, repertorio con búsqueda, filtros y orden, vista
// previa e info a la derecha; solo el clic elige y desmarca la NUEVA.
import 'package:echos_del_tiempo/app/design/design.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/features/characters/presentation/ult_repertoire_view.dart';
import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/ults_v2_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/ult_def.dart';
import 'package:echos_del_tiempo/game_engine/rules/ult_browse_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/ult_rules.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../panel_test_harness.dart';

UltDef _v2(UltSource s) => kUltV2List.firstWhere(
    (u) => u.source == s && u.classes.isEmpty);

final _weapon = kWeapons[kClasses['guerrero']!.startWeaponId]!;

void main() {
  final a = _v2(UltSource.boss);
  final b = _v2(UltSource.feat);

  PlayerProfile profile() {
    final p = newProfile('Ana', 'guerrero');
    // b llega después que a: es la más nueva. Las dos quedan NUEVA.
    return UltRules.learn(UltRules.learn(p, a.id), b.id);
  }

  Future<List<String>> pump(WidgetTester tester, PlayerProfile p,
      {UltBrowsePrefs prefs = const UltBrowsePrefs(),
      List<UltBrowsePrefs>? saved}) async {
    final seen = <String>[];
    await pumpPanel(tester,
        profile: p,
        build: (v, c) {
          final rules = c.engine.progression;
          return Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                  width: 1200,
                  height: 800,
                  child: UltRepertoireView(
                      profile: p,
                      weapon: rules.equippedWeapon(p),
                      item: rules.equippedItem(p),
                      editable: true,
                      prefs: prefs,
                      onPrefs: saved?.add,
                      onSeen: seen.addAll,
                      onSelect: (_) => true,
                      onUpgrade: (_) => true)));
        });
    await tester.pumpAndSettle();
    return seen;
  }

  Finder row(String id) => find.byKey(ValueKey('ult-row-$id'));

  testWidgets('el hover no cambia nada; el clic elige y saca la NUEVA',
      (tester) async {
    final p = profile();
    final seen = await pump(tester, p);
    final base = UltRules.baseUltId(p.classId)!;
    expect(find.byKey(ValueKey('ult-info-$base')), findsOneWidget);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await tester.ensureVisible(row(a.id));
    await tester.pump();
    await mouse.moveTo(tester.getCenter(row(a.id)));
    await tester.pump(const Duration(seconds: 1));
    expect(seen, isEmpty);
    expect(find.byKey(ValueKey('ult-info-$base')), findsOneWidget);
    expect(find.byKey(ValueKey('ult-info-${a.id}')), findsNothing);
    await tester.tap(find.byKey(ValueKey('ult-row-${a.id}')));
    await tester.pump();
    expect(seen, ['${UltRules.seenPrefix}${a.id}']);
    expect(find.byKey(ValueKey('ult-info-${a.id}')), findsOneWidget);
    expect(find.byKey(const ValueKey('ult-equip')), findsOneWidget);
    // Otro clic a la misma no la vuelve a mandar.
    await tester.tap(find.byKey(ValueKey('ult-row-${a.id}')));
    await tester.pump();
    expect(seen, hasLength(1));
  });

  testWidgets('MEJORAR al lado de EQUIPAR, con el costo; gris sin fondos',
      (tester) async {
    // Sin créditos: MEJORAR gris, el costo a la vista.
    await pump(tester, profile().copyWith(credits: 0));
    await tester.tap(find.byKey(ValueKey('ult-row-${a.id}')));
    await tester.pump();
    final up = find.byKey(const ValueKey('ult-upgrade'));
    expect(up, findsOneWidget);
    expect(tester.widget<DsButton>(up).onPressed, isNull);
    expect(find.byKey(const ValueKey('ult-upgrade-cost')), findsOneWidget);
    // En la misma fila que EQUIPAR / EQUIPADA (sin scrollear).
    final actions = find.ancestor(of: up, matching: find.byType(Wrap)).first;
    expect(
        find.descendant(
            of: actions,
            matching: find.byWidgetPredicate((w) =>
                w is DsBadge ||
                (w is DsButton && w.key == const ValueKey('ult-equip')))),
        findsOneWidget);
    expect(tester.getBottomLeft(up).dy, lessThan(800));
  });

  testWidgets('la equipada va fija arriba, antes de los filtros',
      (tester) async {
    final p = profile().copyWith(ultSel: () => b.id);
    await pump(tester, p);
    final pinned = find.byKey(ValueKey('ult-equipped-${b.id}'));
    expect(pinned, findsOneWidget);
    expect(row(b.id), findsNothing);
    expect(tester.getRect(pinned).bottom,
        lessThan(tester.getRect(find.byKey(const ValueKey('ult-search'))).top));
  });

  testWidgets('búsqueda, filtro de origen y orden', (tester) async {
    final saved = <UltBrowsePrefs>[];
    await pump(tester, profile(), saved: saved);
    // Más nuevas: b antes que a.
    expect(tester.getRect(row(b.id)).top,
        lessThan(tester.getRect(row(a.id)).top));
    await tester.tap(find.byKey(const ValueKey('ult-sort')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('ult-sort-alpha')));
    await tester.pump();
    expect(saved.last.sort, UltSort.alpha);
    final alphaFirst = UltBrowseRules.fold(a.name)
            .compareTo(UltBrowseRules.fold(b.name)) <
        0;
    expect(
        tester.getRect(row(a.id)).top < tester.getRect(row(b.id)).top,
        alphaFirst);
    await tester.tap(find.byKey(const ValueKey('ult-filter-origin')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('ult-filter-origin-boss')));
    await tester.pump();
    expect(saved.last.origin, UltOrigin.boss);
    expect(row(b.id), findsNothing);
    expect(row(a.id), findsOneWidget);
    await tester.enterText(
        find.descendant(
            of: find.byKey(const ValueKey('ult-search')),
            matching: find.byType(EditableText)),
        'zzzz');
    await tester.pump();
    expect(row(a.id), findsNothing);
    expect(find.text('Ninguna ULT con estos filtros.'), findsOneWidget);
  });

  test('orden y filtros (reglas)', () {
    final p = profile();
    expect(const GameSettings().ultBrowse, const UltBrowsePrefs());
    final all = UltBrowseRules.entries(
        p, _weapon, null);
    final newest = UltBrowseRules.apply(all, const UltBrowsePrefs());
    expect(newest.first.id, b.id);
    expect(newest[1].id, a.id);
    final missing = UltBrowseRules.apply(
        all, const UltBrowsePrefs(owned: UltOwnedFilter.missing));
    expect(missing.every((e) => !e.owned), isTrue);
    expect(missing.length, 50 - 2);
    final byLevel = UltBrowseRules.apply(
        UltBrowseRules.entries(
            p.copyWith(ultLevels: {a.id: 4}), _weapon, null),
        const UltBrowsePrefs(sort: UltSort.level));
    expect(byLevel.first.id, a.id);
    final espada = UltBrowseRules.apply(
        all, const UltBrowsePrefs(weapon: 'espada'));
    expect(espada.every((e) => e.weapons.contains('espada')), isTrue);
    expect(UltBrowseRules.fold('Ráfaga'), 'rafaga');
    // Ajustes: se guardan y se leen.
    const prefs = UltBrowsePrefs(
        sort: UltSort.level, origin: UltOrigin.boss, weapon: 'arco');
    final back = GameSettings.fromJson(
        const GameSettings(ultBrowse: prefs).toJson());
    expect(back.ultBrowse, prefs);
  });

  test('orden de obtención: aditivo en el perfil y compatible', () {
    final p = profile();
    expect(p.ultOrder.indexOf(b.id), greaterThan(p.ultOrder.indexOf(a.id)));
    final j = p.toJson();
    expect(j['uo'], p.ultOrder);
    expect(PlayerProfile.fromJson(j).ultOrder, p.ultOrder);
    // Partida vieja sin `uo`: se lee vacía y lo nuevo va al final.
    final old = PlayerProfile.fromJson({...j}..remove('uo'));
    expect(old.ultOrder, isEmpty);
    final c = _v2(UltSource.eco);
    expect(UltRules.learn(old, c.id).ultOrder, [c.id]);
  });
}
