import 'dart:ui' as ui;

import 'package:echos_del_tiempo/app/theme/panel_frame.dart';
import 'package:echos_del_tiempo/app/theme/pixel_label.dart';
import 'package:echos_del_tiempo/app/theme/proto_colors.dart';
import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/app/theme/ui_theme.dart';
import 'package:echos_del_tiempo/app/widgets/notice_close.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/features/bestiary/presentation/bestiary_view.dart';
import 'package:echos_del_tiempo/features/build_planner/presentation/build_feed.dart';
import 'package:echos_del_tiempo/features/combat/presentation/battle_command_window.dart';
import 'package:echos_del_tiempo/features/combat/presentation/battle_screen.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/battle_scene.dart';
import 'package:echos_del_tiempo/features/inventory/domain/item_text.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/armory_panel.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/shop_sections.dart';
import 'package:echos_del_tiempo/features/world/presentation/hud/chat_box.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/map_labels.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_view.dart';
import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/bestiary.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../features/combat/battle_screen_test.dart' show member;
import '../features/inventory/loot_fixtures.dart';
import '../features/panel_test_harness.dart';
import '../game_engine/session_test_helpers.dart';
import '../real_fonts.dart';
import 'text_size_test.dart' show legendWand;

/// Opciones de texto de v0.8.1 (docs/specs/accessibility.md § 9):
/// ATKINSON, títulos con la fuente de lectura, ENORME, espaciado entre
/// letras, duración de los avisos, fondo del texto en el mapa y registro
/// de batalla extendido.

BattleState _battle() {
  final engine = BattleEngine(
    stats: StatsCalculator(
        classes: kClasses, treeRules: PassiveTreeRules(kPassiveTree)),
    random: () => 0.99,
  );
  final start = engine.start(
    party: [
      for (final id in ['guerrero', 'maga', 'tirador', 'paladin']) member(id),
    ],
    enemyTypes: const ['slime', 'bat', 'golem'],
    triggeredBy: 'guerrero',
  );
  return engine.nextTurn(start.state).state;
}

void main() {
  setUpAll(loadRealFonts);
  tearDown(RetroType.reset);

  group('ajustes (game.json)', () {
    test('por defecto = como antes; se guardan; viejo / inválido = defecto',
        () {
      const d = GameSettings();
      expect(d.readingTitles, isFalse);
      expect(d.letterSpacing, LetterSpacing.normal);
      expect(d.noticeDuration, NoticeDuration.normal);
      expect(d.mapLabelBackdrop, MapLabelBackdrop.none);
      expect(d.battleLog, BattleLogMode.normal);
      const s = GameSettings(
        readingFont: ReadingFont.atkinson,
        textSize: TextSize.enormous,
        readingTitles: true,
        letterSpacing: LetterSpacing.wide,
        noticeDuration: NoticeDuration.untilDismissed,
        mapLabelBackdrop: MapLabelBackdrop.box,
        battleLog: BattleLogMode.extended,
      );
      final j = s.toJson();
      expect(j['readingFont'], 'atkinson');
      expect(j['textSize'], 'enormous');
      expect(j['readingTitles'], true);
      expect(j['letterSpacing'], 'wide');
      expect(j['noticeDuration'], 'untilDismissed');
      expect(j['mapLabelBackdrop'], 'box');
      expect(j['battleLog'], 'extended');
      expect(GameSettings.fromJson(j), s);
      expect(s.hashCode, GameSettings.fromJson(j).hashCode);
      // Un game.json de v0.8.0 (sin las claves) o con basura.
      final old = GameSettings.fromJson(const {'textSize': 'huge'});
      expect(old.textSize, TextSize.huge);
      expect(old.readingTitles, isFalse);
      expect(old.noticeDuration, NoticeDuration.normal);
      final junk = GameSettings.fromJson(const {
        'readingFont': 'comic',
        'readingTitles': 'sí',
        'letterSpacing': 3,
        'noticeDuration': 'siempre',
        'mapLabelBackdrop': null,
        'battleLog': 'x',
      });
      expect(junk, const GameSettings());
    });

    test('el controlador guarda cada opción', () async {
      final store = InMemoryGameSettingsStore();
      final c = GameSettingsController(store: store);
      await c.update(c.state.copyWith(
          readingTitles: true, mapLabelBackdrop: MapLabelBackdrop.shaded));
      expect(store.saved!.readingTitles, isTrue);
      expect(store.saved!.mapLabelBackdrop, MapLabelBackdrop.shaded);
    });

    test('duración de los avisos', () {
      const base = Duration(seconds: 4);
      expect(NoticeDuration.normal.scale(base), base);
      expect(NoticeDuration.long.scale(base), const Duration(seconds: 8));
      expect(NoticeDuration.untilDismissed.scale(base), isNull);
      expect(NoticeDuration.untilDismissed.persistent, isTrue);
    });
  });

  group('tipografía', () {
    test('ATKINSON: 18 / 23 / 27 / 36 px enteros, sin grilla de 8', () {
      double body(TextSize t, double dpr) => RetroTextScaler(t.factor,
              devicePixelRatio: dpr, font: ReadingFont.atkinson)
          .scale(RetroType.small);
      expect([for (final t in TextSize.values) body(t, 1)], [18, 23, 27, 36]);
      for (final dpr in [1.0, 1.25, 1.5, 2.0]) {
        for (final t in TextSize.values) {
          final px = body(t, dpr) * dpr;
          expect(px, closeTo(px.roundToDouble(), 1e-6));
        }
      }
      RetroType.font = ReadingFont.atkinson;
      expect(RetroType.bodyFamily, RetroType.atkinsonFamily);
      expect(RetroType.familyFor(RetroType.small), RetroType.atkinsonFamily);
      // Los títulos siguen en Press Start sin la opción.
      expect(RetroType.titleFamily, RetroType.pixelFamily);
      expect(RetroType.familyFor(RetroType.title), RetroType.pixelFamily);
    });

    test('ENORME: ×2 (VT323 40 px; títulos +8)', () {
      expect(TextSize.enormous.factor, 2);
      const sc = RetroTextScaler(2);
      expect(sc.scale(RetroType.small), 40);
      expect(sc.scale(RetroType.title), 24);
      expect(sc.scale(RetroType.label), 24);
    });

    test('títulos con la fuente de lectura: familia y tamaños', () {
      RetroType.readingTitles = true;
      expect(RetroType.titleFamily, RetroType.vt323Family);
      expect(RetroType.familyFor(RetroType.title), RetroType.vt323Family);
      // Los símbolos siempre en Press Start.
      expect(RetroType.familyFor(RetroType.glyph), RetroType.pixelFamily);
      RetroType.font = ReadingFont.atkinson;
      expect(RetroType.titleFamily, RetroType.atkinsonFamily);
      // CLÁSICA: no cambia nada (ya es Press Start).
      RetroType.font = ReadingFont.classic;
      expect(RetroType.titleFamily, RetroType.pixelFamily);

      const vt = RetroTextScaler(1, readingTitles: true);
      expect(vt.scale(RetroType.title), 24); // 16 × 1.5
      expect(vt.scale(RetroType.label), 16); // 10 × 1.6
      expect(vt.scale(RetroType.glyph), 8); // Press Start
      const at = RetroTextScaler(1,
          readingTitles: true, font: ReadingFont.atkinson);
      expect(at.scale(RetroType.title), 20);
      expect(at.scale(RetroType.label), 13);
      // Sin la opción, la grilla de siempre.
      const off = RetroTextScaler(1, font: ReadingFont.atkinson);
      expect(off.scale(RetroType.title), 16);
      expect(off.scale(RetroType.label), 8);
      // CLÁSICA ignora la opción.
      const cl = RetroTextScaler(1,
          readingTitles: true, font: ReadingFont.classic);
      expect(cl.scale(RetroType.title), 16);
    });

    test('espaciado entre letras: +0.08 em en px físicos enteros', () {
      expect(RetroType.letterSpacing, isNull);
      expect(RetroType.smallStyle.letterSpacing, isNull);
      RetroType.wideLetters = true;
      RetroType.readingPx = 20;
      expect(RetroType.letterSpacing, 2); // 1.6 → 2
      RetroType.readingPx = 40;
      expect(RetroType.letterSpacing, 3); // 3.2 → 3
      RetroType.devicePixelRatio = 1.5;
      expect(RetroType.letterSpacing, closeTo(5 / 1.5, 1e-9)); // 4.8 → 5
      expect(RetroType.smallStyle.letterSpacing, RetroType.letterSpacing);
      expect(RetroType.style(RetroType.small).letterSpacing,
          RetroType.letterSpacing);
      // Solo el texto de lectura.
      expect(RetroType.style(RetroType.title).letterSpacing, isNull);
    });

    testWidgets('se aplican en vivo: tema, paneles y espaciado',
        (tester) async {
      await pumpPanel(tester,
          profile: lootWarrior(),
          textSize: TextSize.normal,
          readingFont: ReadingFont.atkinson,
          readingTitles: true,
          wideLetters: true,
          build: (v, c) => CharacterPanel(
              view: v, controller: c, initialTab: CharacterTab.attributes));
      await tester.pump();
      final ctx = tester.element(find.byType(CharacterPanel));
      final theme = Theme.of(ctx);
      expect(theme.textTheme.titleMedium!.fontFamily, RetroType.atkinsonFamily);
      expect(theme.textTheme.bodySmall!.fontFamily, RetroType.atkinsonFamily);
      // 18 × 0.08 = 1.44 → 1 px (el tema de la app se vuelve a armar al
      // cambiar; acá lo armó el test antes de medir).
      expect(RetroType.letterSpacing, 1);
      expect(RetroType.smallStyle.letterSpacing, 1);
      final title = tester.widget<Text>(find.descendant(
          of: find.byType(PanelFrame), matching: find.byType(Text)).first);
      expect(title.style!.fontFamily, RetroType.atkinsonFamily);
      expect(tester.takeException(), isNull);
    });
  });

  group('duración de los avisos', () {
    test('build: LARGA ×2; HASTA CERRAR queda y se cierra', () {
      var now = 0.0;
      final f = BuildFeed(clock: () => now)..durationFactor = 2;
      f.push('Build: ★ Keystone');
      now = BuildFeed.toastS + 0.5;
      expect(f.toasts, hasLength(1));
      now = BuildFeed.toastS * 2 + 0.1;
      expect(f.toasts, isEmpty);
      f.dismissAll();
      f
        ..setDurationFactor(NoticeDuration.untilDismissed.factor)
        ..push('Build: algo');
      now = 1e6;
      // Con HASTA CERRAR vale para todos (también el que ya había).
      expect(f.toasts, hasLength(1));
      expect(f.needsTick, isFalse);
      f.dismiss(f.toasts.single);
      expect(f.toasts, isEmpty);
      f.push('a');
      f.dismissAll();
      expect(f.toasts, isEmpty);
    });

    testWidgets('chat plegado: × en HASTA CERRAR; cerrar todos',
        (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      final signal = ChangeNotifier();
      addTearDown(signal.dispose);
      Widget chat(List<ChatLine> lines, {Duration? d}) => MaterialApp(
            theme: RetroTheme.build(),
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomLeft,
                child: SizedBox(
                  width: 400,
                  child: ChatBox(
                    lines: lines,
                    focusNode: focus,
                    onSend: (_) {},
                    onDone: () {},
                    collapsible: true,
                    noticeDuration: d,
                    dismissSignal: signal,
                  ),
                ),
              ),
            ),
          );
      const a = ChatLine.system('¡Jefe a la vista!');
      const b = ChatLine.system('¡Cofre secreto!');
      await tester.pumpWidget(chat(const []));
      await tester.pumpWidget(chat(const [a]));
      expect(find.byKey(const ValueKey('chat-toast-0')), findsOneWidget);
      expect(find.byType(NoticeClose), findsOneWidget);
      // Mucho después sigue ahí.
      await tester.pump(const Duration(minutes: 5));
      expect(find.byKey(const ValueKey('chat-toast-0')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('chat-toast-close-0')));
      await tester.pump();
      expect(find.byKey(const ValueKey('chat-toast-0')), findsNothing);
      await tester.pumpWidget(chat(const [a, b]));
      expect(find.byKey(const ValueKey('chat-toast-0')), findsOneWidget);
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      signal.notifyListeners();
      await tester.pump();
      expect(find.byKey(const ValueKey('chat-toast-0')), findsNothing);
      // LARGA: 8 s, sin ×.
      const c = ChatLine.system('¡Voten!');
      await tester.pumpWidget(
          chat(const [a, b, c], d: NoticeDuration.long.scale(ChatBox.toastDuration)));
      expect(find.byType(NoticeClose), findsNothing);
      await tester.pump(const Duration(seconds: 5));
      expect(find.byKey(const ValueKey('chat-toast-0')), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      expect(find.byKey(const ValueKey('chat-toast-0')), findsNothing);
    });
  });

  group('fondo del texto en el mapa', () {
    Future<List<Color>> sample(WidgetTester tester, MapLabelBackdrop b) async {
      const size = Size(170, 24);
      final rec = ui.PictureRecorder();
      MapLabelSamplePainter(backdrop: b).paint(Canvas(rec), size);
      final img = rec.endRecording().toImageSync(170, 24);
      final data = (await tester.runAsync(
          () => img.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
      Color at(int x, int y) {
        final i = (y * 170 + x) * 4;
        return Color.fromARGB(data.getUint8(i + 3), data.getUint8(i),
            data.getUint8(i + 1), data.getUint8(i + 2));
      }

      // Una esquina de la caja de fondo (pegada al texto) y un tile lejos.
      final pen = PixelLabelPen();
      final w = pen.width('Herrera Ana', 8);
      final r = mapLabelBackdropRect(85, 16, w, 8, 1);
      return [at(r.left.toInt() + 1, r.top.toInt() + 1), at(1, 1)];
    }

    testWidgets('NINGUNO: tiles; SOMBREADO: fondo del tema al 60 %; CAJA: '
        'fondo del tema opaco', (tester) async {
      UiTheme.kind = InterfaceTheme.dark;
      addTearDown(UiTheme.reset);
      final none = await sample(tester, MapLabelBackdrop.none);
      final shaded = await sample(tester, MapLabelBackdrop.shaded);
      final box = await sample(tester, MapLabelBackdrop.box);
      // Lejos del texto, los tiles iguales en los tres.
      expect(shaded[1], none[1]);
      expect(box[1], none[1]);
      // NINGUNO deja ver el tile; SOMBREADO lo oscurece; CAJA es el
      // fondo del tema (adentro del borde de 1 px).
      expect(none[0], isNot(shaded[0]));
      expect(shaded[0].computeLuminance(), lessThan(none[0].computeLuminance()));
      expect(box[0], UiTheme.of(UiSlot.bg));
    });

    test('la caja rodea el texto con 3 / 2 px de aire', () {
      final r = mapLabelBackdropRect(100, 50, 40, 8, 1);
      expect(r, const Rect.fromLTRB(77, 40, 123, 52));
    });
  });

  group('registro de batalla', () {
    Widget view(BattleState b, {required bool extended}) => MaterialApp(
          theme: RetroTheme.build(),
          home: Scaffold(
            body: BattleView(
              battle: b,
              canAct: false,
              localId: 'guerrero',
              onCommand: (_) => true,
              sceneOptions: SceneOptions(extendedLog: extended),
            ),
          ),
        );

    testWidgets('EXTENDIDO: las 2 anteriores debajo de la banda; vencen',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final b = _battle();
      for (final l in ['Uno', 'Dos', 'Tres', 'Cuatro']) {
        await tester.pumpWidget(view(b.copy()..log = l, extended: true));
      }
      final st = tester.state<BattleViewState>(find.byType(BattleView));
      expect(st.logHistory, ['Dos', 'Tres']);
      expect(find.byKey(const ValueKey('battle-log-history')), findsOneWidget);
      expect(find.text('Tres'), findsOneWidget);
      await tester.pump(
          Duration(milliseconds: (kBattleLogHistoryS * 1000).round() + 50));
      expect(st.logHistory, isEmpty);
      expect(find.byKey(const ValueKey('battle-log-history')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('NORMAL: solo la banda', (tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final b = _battle();
      for (final l in ['Uno', 'Dos', 'Tres']) {
        await tester.pumpWidget(view(b.copy()..log = l, extended: false));
      }
      expect(tester.state<BattleViewState>(find.byType(BattleView)).logHistory,
          isEmpty);
      expect(find.byKey(const ValueKey('battle-log-history')), findsNothing);
    });
  });

  // Sin desbordes a 1280×720: VT323 / ATKINSON × títulos de lectura ×
  // NORMAL / ENORME (con espaciado AMPLIO en los de títulos) en las
  // pantallas más cargadas. El tema y la pestaña de ajustes: en
  // settings_menu_test.
  group('sin desbordes', () {
    for (final font in [ReadingFont.vt323, ReadingFont.atkinson]) {
      for (final titles in [false, true]) {
        for (final size in [TextSize.normal, TextSize.enormous]) {
          final name = '${font.name}${titles ? ' +títulos' : ''} ${size.name}';
          testWidgets('$name: ficha, FUSIÓN 2/3, ATRIBUTOS, bestiario, comandos',
              (tester) async {
            Future<void> pump(Widget Function(SessionView, dynamic) b) =>
                pumpPanel(tester,
                    profile: lootWarrior(extra: [legendWand]),
                    textSize: size,
                    readingFont: font,
                    readingTitles: titles,
                    wideLetters: titles,
                    build: (v, c) => b(v, c));
            final p = lootWarrior(extra: [legendWand]);
            await pump((v, c) => Align(
                  alignment: const Alignment(0.8, 0.7),
                  child: RetroTooltip(
                    message: itemTooltipMarkup(progression, legendWand,
                        level: p.level, attributes: p.attributes),
                    child: const SizedBox(
                        key: ValueKey('target'), width: 44, height: 44),
                  ),
                ));
            final mouse =
                await tester.createGesture(kind: PointerDeviceKind.mouse);
            await mouse.addPointer(location: Offset.zero);
            addTearDown(mouse.removePointer);
            await mouse
                .moveTo(tester.getCenter(find.byKey(const ValueKey('target'))));
            await tester.pump();
            final tip = find.byWidgetPredicate((w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration! as BoxDecoration).boxShadow != null);
            final r = tester.getRect(tip.first);
            expect(r.left >= 0 && r.top >= 0, isTrue, reason: 'ficha');
            expect(r.right <= 1280 && r.bottom <= 720, isTrue, reason: 'ficha');
            expect(tester.takeException(), isNull, reason: 'ficha');
            await mouse.moveTo(Offset.zero);
            await tester.pumpWidget(const SizedBox());

            await pump((v, c) =>
                ArmoryPanel(view: v, controller: c, initialTab: ArmoryTab.fuse));
            await tapVisible(
                tester, find.byKey(const ValueKey('bench-weapon-r1')));
            await tapVisible(tester, find.byKey(const ValueKey('bench-next')));
            expect(tester.takeException(), isNull, reason: 'FUSIÓN 2');
            await tapVisible(
                tester, find.byKey(const ValueKey('bench-op-reroll')));
            expect(find.byKey(const ValueKey('craft-confirm')), findsOneWidget);
            expect(tester.takeException(), isNull, reason: 'FUSIÓN 3');
            await tester.pumpWidget(const SizedBox());

            await pump((v, c) => CharacterPanel(
                view: v, controller: c, initialTab: CharacterTab.attributes));
            expect(tester.takeException(), isNull, reason: 'ATRIBUTOS');
            await tester.pumpWidget(const SizedBox());

            await pump((v, c) =>
                BestiaryView(bestiary: BestiaryProgress({'slime': 5, 'lobo': 3})));
            expect(find.byKey(const ValueKey('bestiary-detail-slime')),
                findsOneWidget);
            expect(tester.takeException(), isNull, reason: 'bestiario');
            await tester.pumpWidget(const SizedBox());

            await pump((v, c) => BattleView(
                battle: _battle(),
                canAct: true,
                localId: 'guerrero',
                turnTimeLeft: 25,
                onCommand: (_) => true,
                sceneOptions: const SceneOptions(extendedLog: true)));
            expect(find.byKey(const ValueKey('battle-menu')), findsOneWidget);
            final bv = tester.state<BattleViewState>(find.byType(BattleView));
            for (final c in BattleCategory.values) {
              bv.selectCategory(c);
              await tester.pump();
              expect(tester.takeException(), isNull, reason: c.name);
            }
          });
        }
      }
    }
  });

  test('contraste: el texto del mapa sobre la caja opaca ≥ 4.5:1', () {
    for (final t in InterfaceTheme.values) {
      final bg = UiTheme.inTheme(t, UiSlot.bg);
      for (final ink in [const Color(0xFFFFFFFF), ProtoColors.gold.base]) {
        final l1 = ink.computeLuminance(), l2 = bg.computeLuminance();
        final ratio = (l1 + 0.05) / (l2 + 0.05);
        expect(ratio, greaterThanOrEqualTo(4.5), reason: '$t');
      }
    }
  });
}
