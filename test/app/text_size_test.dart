import 'package:echos_del_tiempo/app/theme/panel_frame.dart';
import 'package:echos_del_tiempo/app/theme/proto_colors.dart';
import 'package:echos_del_tiempo/app/theme/proto_markup.dart';
import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/features/combat/presentation/battle_command_window.dart';
import 'package:echos_del_tiempo/features/combat/presentation/battle_screen.dart';
import 'package:echos_del_tiempo/game_engine/data/skills_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/player_state.dart';
import 'package:echos_del_tiempo/features/inventory/domain/item_text.dart';
import 'package:echos_del_tiempo/features/passive_tree/presentation/passive_tree_view.dart';
import 'package:echos_del_tiempo/features/world/presentation/hud/chat_box.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_view.dart';
import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/weapon.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/inventory_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../features/combat/battle_screen_test.dart' show member;
import '../features/inventory/loot_fixtures.dart';
import '../features/panel_test_harness.dart';
import '../game_engine/session_test_helpers.dart';
import '../real_fonts.dart';

/// "Tamaño del texto" (docs/specs/settings.md § 3) y escala tipográfica
/// (docs/specs/ui_style.md § "Tipografía"): persistencia, tamaños nítidos
/// y que nada desborde a 1280×720 en los tres tamaños (con la fuente
/// real: el desborde depende del ancho de los glifos).

/// Legendario de maga como el de la captura del dueño: implícito, 4 mods,
/// pasiva, forja, habilidades, ULT y frase.
const legendWand = ItemInstance(
  uid: 'lw',
  baseId: 'varita_rayo',
  rarity: Rarity.legendario,
  itemLevel: 20,
  uniqueId: 'relampagoDormido',
  passiveId: 'arcoDormido',
  forge: WeaponUpgradeLevels(pow: 2),
  affixes: [
    AffixRoll('arcano', 0, 26),
    AffixRoll('letal', 0, 24),
    AffixRoll('certero', 5, 8),
    AffixRoll('de_la_vida', 5, 14),
  ],
);

/// (tamaño, escala de Windows, fuente de lectura) que se prueban: las dos
/// fuentes en los tres tamaños a 1280×720, y VT323 también a 150 %.
final _cases = [
  for (final f in ReadingFont.values)
    for (final t in TextSize.values)
      for (final dpr in f == ReadingFont.vt323 ? [1.0, 1.5] : [1.0])
        (t, dpr, f),
];

String _name((TextSize, double, ReadingFont) c) =>
    '${c.$3.name} ${c.$1.name} @${c.$2}x';

/// La fuente de lectura para el próximo `pumpWidget` (el tema la lee al
/// armarse).
ReadingFont _font = ReadingFont.vt323;

Future<void> _view(WidgetTester tester, double dpr) async {
  tester.view.physicalSize = Size(1280 * dpr, 720 * dpr);
  tester.view.devicePixelRatio = dpr;
  addTearDown(tester.view.reset);
}

Widget _app(TextSize t, Widget home) {
  RetroType.font = _font;
  return MaterialApp(
    theme: RetroTheme.build(),
    builder: (context, child) =>
        RetroTextScale(factor: t.factor, font: _font, child: child!),
    home: Scaffold(body: home),
  );
}

Future<TestGesture> _hover(WidgetTester tester, Finder f) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  addTearDown(mouse.removePointer);
  await mouse.moveTo(tester.getCenter(f));
  await tester.pump();
  return mouse;
}

/// El rectángulo de [f] queda dentro de 1280×720.
void _onScreen(WidgetTester tester, Finder f) {
  final r = tester.getRect(f);
  expect(r.left, greaterThanOrEqualTo(0));
  expect(r.top, greaterThanOrEqualTo(0));
  expect(r.right, lessThanOrEqualTo(1280));
  expect(r.bottom, lessThanOrEqualTo(720));
}

/// La caja del tip abierta (el `Container` con borde dorado del overlay).
Finder _tipBox() => find.byWidgetPredicate((w) =>
    w is Container &&
    w.decoration is BoxDecoration &&
    (w.decoration! as BoxDecoration).border ==
        Border.all(color: ProtoColors.gold, width: 2) &&
    (w.decoration! as BoxDecoration).boxShadow != null);

void main() {
  setUpAll(loadRealFonts);


  test('fuente de lectura: VT323 por defecto; se guarda; viejo = VT323', () {
    expect(const GameSettings().readingFont, ReadingFont.vt323);
    const s = GameSettings(readingFont: ReadingFont.classic);
    expect(s.toJson()['readingFont'], 'classic');
    expect(GameSettings.fromJson(s.toJson()), s);
    expect(GameSettings.fromJson(const {'crt': 'soft'}).readingFont,
        ReadingFont.vt323);
    // CLÁSICA: lectura en Press Start 2P en su grilla de 8 (8 / 16 / 16).
    expect([
      for (final t in TextSize.values)
        RetroTextScaler(t.factor, classicReading: true).scale(RetroType.small)
    ], [8, 16, 16, 24]);
  });

  group('ajuste', () {
    test('por defecto Normal; se guarda y se lee de game.json', () {
      expect(const GameSettings().textSize, TextSize.normal);
      const s = GameSettings(textSize: TextSize.huge);
      expect(s.toJson()['textSize'], 'huge');
      expect(GameSettings.fromJson(s.toJson()), s);
      // game.json viejo (sin la clave) o con basura: Normal.
      expect(GameSettings.fromJson(const {'crt': 'soft'}).textSize,
          TextSize.normal);
      expect(GameSettings.fromJson(const {'textSize': 'gigante'}).textSize,
          TextSize.normal);
      expect([for (final t in TextSize.values) t.factor], [1, 1.25, 1.5, 2]);
    });

    test('el controlador guarda el cambio', () async {
      final store = InMemoryGameSettingsStore();
      final c = GameSettingsController(store: store);
      await c.update(c.state.copyWith(textSize: TextSize.large));
      expect(store.saved!.textSize, TextSize.large);
    });
  });

  group('escala nítida (grilla de cada fuente)', () {
    double body(TextSize t, double dpr) =>
        RetroTextScaler(t.factor, devicePixelRatio: dpr)
            .scale(RetroType.small);

    test('VT323: 20 / 25 / 30 px en px físicos enteros', () {
      expect([for (final t in TextSize.values) body(t, 1)], [20, 25, 30, 40]);
      expect([for (final t in TextSize.values) body(t, 1.5)],
          [20, closeTo(25.333, 0.001), 30, 40]); // 38 físicos
      expect(body(TextSize.large, 1.25), closeTo(24.8, 1e-9)); // 31 físicos
      expect(const RetroTextScaler(1).scale(RetroType.body),
          const RetroTextScaler(1).scale(RetroType.small));
    });

    test('todo tamaño queda en su grilla y Muy grande > Normal', () {
      for (final dpr in [1.0, 1.25, 1.5, 1.75, 2.0, 2.5]) {
        for (final t in TextSize.values) {
          final sc = RetroTextScaler(t.factor, devicePixelRatio: dpr);
          for (final size in const [RetroType.small, RetroType.body]) {
            final px = sc.scale(size) * dpr;
            expect(px, closeTo(px.roundToDouble(), 1e-6),
                reason: 'VT323 $size @$dpr $t');
          }
          for (final size in const [
            8.0,
            RetroType.label,
            12.0,
            14.0,
            16.0,
            24.0,
            32.0,
            56.0,
          ]) {
            final px = sc.scale(size) * dpr;
            expect(px % 8, closeTo(0, 1e-6), reason: '$size @$dpr $t');
            expect(px, greaterThanOrEqualTo(8));
          }
        }
        expect(body(TextSize.huge, dpr), greaterThan(body(TextSize.normal, dpr)),
            reason: '@$dpr');
      }
    });

    test('cada tamaño nominal va con su fuente', () {
      expect(RetroType.familyFor(RetroType.small), RetroType.bodyFamily);
      expect(RetroType.familyFor(RetroType.body), RetroType.bodyFamily);
      for (final s in const [
        RetroType.label,
        RetroType.title,
        RetroType.heading,
        RetroType.display,
        12.0,
        14.0,
      ]) {
        expect(RetroType.familyFor(s), RetroType.pixelFamily);
      }
      expect(RetroType.style(RetroType.small).fontFamilyFallback,
          [RetroType.pixelFamily]);
    });
  });

  test('árbol: nombres de clusters solo con zoom suficiente', () {
    TreeLabelsPainter at(double z) => TreeLabelsPainter(
        catalog: kPassiveTree,
        transform: Matrix4.diagonal3Values(z, z, 1),
        textScaler: const RetroTextScaler(1));
    expect(at(0.3).visible, isFalse);
    expect(at(TreeLabelsPainter.minZoom - 0.01).visible, isFalse);
    expect(at(TreeLabelsPainter.minZoom).visible, isTrue);
    expect(at(1.2).visible, isTrue);
  });

  test('protoSplitLines cierra y reabre las etiquetas en cada línea', () {
    const m = '<b>A<br><span style="color:#ff0000">B<br>C</span></b><br>D';
    final lines = protoSplitLines(m);
    expect(lines, [
      '<b>A</b>',
      '<b><span style="color:#ff0000">B</span></b>',
      '<b><span style="color:#ff0000">C</span></b>',
      'D',
    ]);
    expect(lines.map(protoPlain).join('\n'), protoPlain(m));
  });

  for (final c in _cases) {
    final (size, dpr, font) = c;
    group(_name(c), () {
      setUp(() => _font = font);
      tearDown(RetroType.reset);
      testWidgets('ficha de un Legendario: dentro de la pantalla',
          (tester) async {
        await _view(tester, dpr);
        final p = lootWarrior(extra: [legendWand]);
        final markup = itemTooltipMarkup(progression, legendWand,
            level: p.level, attributes: p.attributes);
        // Un objetivo abajo a la derecha: la ficha sube y se corre.
        await tester.pumpWidget(_app(
            size,
            Align(
              alignment: const Alignment(0.8, 0.7),
              child: RetroTooltip(
                message: markup,
                child: const SizedBox(
                    key: ValueKey('target'), width: 44, height: 44),
              ),
            )));
        await _hover(tester, find.byKey(const ValueKey('target')));
        expect(find.textContaining('Relámpago Dormido', findRichText: true),
            findsWidgets);
        _onScreen(tester, _tipBox());
        expect(tester.takeException(), isNull);
      });

      testWidgets('comparación del inventario al pasar el mouse',
          (tester) async {
        final c = await pumpPanel(tester,
            profile: lootWarrior(extra: [legendWand]),
            textSize: size,
            readingFont: font,
            devicePixelRatio: dpr,
            build: (v, c) => CharacterPanel(
                view: v, controller: c, initialTab: CharacterTab.inventory));
        final p = c.view!.me!.profile;
        final cell = InventoryRules.layout(p).cells.indexOf('lw');
        final f = find.byKey(ValueKey('inv-cell-$cell'));
        await tester.ensureVisible(f);
        await tester.pump();
        await _hover(tester, f);
        final tip = find.byKey(const ValueKey('inv-cmp-tip'));
        expect(tip, findsOneWidget);
        _onScreen(tester, _tipBox());
        expect(tester.takeException(), isNull);
      });

      testWidgets('panel de personaje: atributos, inventario, árbol y filtro',
          (tester) async {
        for (final tab in [
          CharacterTab.attributes,
          CharacterTab.inventory,
          CharacterTab.tree,
          CharacterTab.filter,
        ]) {
          await pumpPanel(tester,
              profile: lootWarrior(extra: [legendWand]),
              textSize: size,
              readingFont: font,
              devicePixelRatio: dpr,
              build: (v, c) =>
                  CharacterPanel(view: v, controller: c, initialTab: tab));
          expect(tester.takeException(), isNull, reason: tab.name);
          await tester.pumpWidget(const SizedBox());
        }
      });

      testWidgets('batalla: cada categoría, pociones y técnicas largas',
          (tester) async {
        await _view(tester, dpr);
        final engine = BattleEngine(
          stats: StatsCalculator(
              classes: kClasses, treeRules: PassiveTreeRules(kPassiveTree)),
          random: () => 0.99,
        );
        // El guerrero con las técnicas de nombre más largo del juego.
        final longest = kSkills.values.toList()
          ..sort((a, b) => b.name.length.compareTo(a.name.length));
        final g = member('guerrero');
        final start = engine.start(
          party: [
            BattlePartyMember(
              id: g.id,
              name: 'Guerrero Larguísimo',
              potions: 2,
              ethers: 1,
              build: PlayerBuild(
                classId: 'guerrero',
                level: g.build.level,
                attributes: g.build.attributes,
                equippedWeapon: g.build.equippedWeapon,
                item: ItemInstance(
                    uid: 'w',
                    baseId: g.build.equippedWeapon.id,
                    rarity: Rarity.legendario,
                    extraSkills: [for (final k in longest.take(6)) k.id]),
              ),
            ),
            for (final id in ['maga', 'tirador', 'paladin']) member(id),
          ],
          enemyTypes: const ['slime', 'bat', 'golem'],
          triggeredBy: 'guerrero',
        );
        final state = engine.nextTurn(start.state).state;
        await tester.pumpWidget(_app(
            size,
            BattleView(
                key: const ValueKey('bv'),
                battle: state,
                canAct: true,
                localId: 'guerrero',
                turnTimeLeft: 25,
                onCommand: (_) => true)));
        await tester.pump();
        final bv = tester.state<BattleViewState>(find.byType(BattleView));
        expect(find.byKey(const ValueKey('battle-menu')), findsOneWidget);
        expect(tester.takeException(), isNull);
        for (final c in BattleCategory.values) {
          bv.selectCategory(c);
          await tester.pump();
          expect(tester.takeException(), isNull, reason: c.name);
        }
        // Pociones: la lista de a quién.
        bv.selectCategory(BattleCategory.items);
        await tester.pump();
        bv.handleKey(LogicalKeyboardKey.digit1);
        await tester.pump();
        expect(find.byKey(const ValueKey('battle-act-give-maga')),
            findsOneWidget);
        expect(tester.takeException(), isNull);
        // El tip de la tarjeta propia tampoco se sale.
        await _hover(tester, find.byKey(const ValueKey('my-panel-guerrero')));
        _onScreen(tester, _tipBox());
        expect(tester.takeException(), isNull);
      });

      testWidgets('chat con líneas largas', (tester) async {
        await _view(tester, dpr);
        final focus = FocusNode();
        addTearDown(focus.dispose);
        await tester.pumpWidget(_app(
            size,
            Align(
              alignment: Alignment.bottomLeft,
              child: Builder(
                builder: (context) => SizedBox(
                  width: RetroType.width(context, 240),
                  child: ChatBox(
                    lines: [
                      for (var i = 0; i < 6; i++)
                        ChatLine(
                            i.isEven ? 'Anastasia' : null,
                            'Mensaje largo número $i para ver que '
                            'el chat corta en dos líneas sin romperse.'),
                    ],
                    focusNode: focus,
                    onSend: (_) {},
                    onDone: () {},
                  ),
                ),
              ),
            )));
        await tester.pump();
        expect(find.byKey(const ValueKey('chat-input')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  }
}
