import 'package:echos_del_tiempo/app/theme/panel_frame.dart';
import 'package:echos_del_tiempo/app/theme/proto_colors.dart';
import 'package:echos_del_tiempo/app/theme/proto_markup.dart';
import 'package:echos_del_tiempo/app/theme/retro_hover_card.dart';
import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/app/theme/ui_theme.dart';
import 'package:echos_del_tiempo/app/theme/vision_palette.dart';
import 'package:echos_del_tiempo/app/widgets/pixel_icon.dart';
import 'package:echos_del_tiempo/app/widgets/section_panel.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/core/settings/settings_providers.dart';
import 'package:echos_del_tiempo/features/bestiary/presentation/bestiary_view.dart';
import 'package:echos_del_tiempo/features/combat/presentation/battle_screen.dart';
import 'package:echos_del_tiempo/features/inventory/domain/item_text.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/armory_panel.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/shop_sections.dart';
import 'package:echos_del_tiempo/features/combat/presentation/battle_command_window.dart';
import 'package:echos_del_tiempo/features/settings/presentation/settings_menu.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/bestiary.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../features/combat/battle_screen_test.dart' show member;
import '../features/inventory/loot_fixtures.dart';
import '../features/panel_test_harness.dart';
import '../game_engine/session_test_helpers.dart';
import '../real_fonts.dart';
import 'contrast_test.dart' show contrast;
import 'text_size_test.dart' show legendWand;

/// Tema de interfaz, colores del texto por roles y espaciado
/// (docs/specs/accessibility.md § 8).
void main() {
  tearDown(() {
    UiTheme.reset();
    VisionPalette.mode = ColorVision.off;
  });

  group('ajustes', () {
    test('por defecto ALTO CONTRASTE (v0.8.2) + REDUCIDO + NORMAL; '
        'game.json aditivo', () {
      const d = GameSettings();
      expect(d.uiTheme, InterfaceTheme.highContrast);
      // Un tema guardado se conserva.
      expect(GameSettings.fromJson(const {'uiTheme': 'dark'}).uiTheme,
          InterfaceTheme.dark);
      expect(d.textColors, TextColorMode.reduced);
      expect(d.spacing, UiSpacing.normal);
      const s = GameSettings(
          uiTheme: InterfaceTheme.highContrast,
          textColors: TextColorMode.full,
          spacing: UiSpacing.wide);
      expect(s.toJson()['uiTheme'], 'highContrast');
      expect(s.toJson()['textColors'], 'full');
      expect(s.toJson()['spacing'], 'wide');
      expect(GameSettings.fromJson(s.toJson()), s);
      // game.json de v0.8.0 (sin las claves) o con basura: por defecto.
      final old = GameSettings.fromJson(const {'crt': 'soft', 'uiTheme': 'x'});
      expect(old.uiTheme, InterfaceTheme.highContrast);
      expect(old.textColors, TextColorMode.reduced);
      expect(old.spacing, UiSpacing.normal);
    });
  });

  group('tokens por tema', () {
    test('cada tema define todos los slots; ThemeColor sigue al activo', () {
      for (final t in InterfaceTheme.values) {
        expect(UiTheme.table[t]!.length, UiSlot.values.length, reason: t.name);
      }
      expect(ProtoColors.panel.toARGB32(), 0xFF121936);
      UiTheme.kind = InterfaceTheme.dark;
      expect(ProtoColors.bg.toARGB32(), 0xFF0A0A0A);
      expect(ProtoColors.panel.toARGB32(), 0xFF141414);
      expect(ProtoColors.button.toARGB32(), 0xFF1F1F1F);
      expect(ProtoColors.panelBorder.toARGB32(), 0xFF2E2E2E);
      expect(ProtoColors.ink.toARGB32(), 0xFFD4D4D4);
      expect(ProtoColors.dim.toARGB32(), 0xFFA3A3A3);
      expect(ProtoColors.gold.toARGB32(), 0xFFF5C451);
      UiTheme.kind = InterfaceTheme.highContrast;
      expect(ProtoColors.bg.toARGB32(), 0xFF000000);
      expect(ProtoColors.title.toARGB32(), 0xFFFFFFFF);
      expect(UiTheme.panelBorderWidth, greaterThan(3));
      expect(UiTheme.buttonBorderWidth, greaterThan(2));
    });

    test('title: dorado con COMPLETO, casi blanco por roles', () {
      UiTheme.kind = InterfaceTheme.dark;
      expect(ProtoColors.title.toARGB32(), ProtoColors.gold.toARGB32());
      UiTheme.textColors = TextColorMode.reduced;
      expect(ProtoColors.title.toARGB32(), 0xFFF5F5F5);
    });

    test('el markup lleva el hex canónico y vuelve a ser el token', () {
      UiTheme.kind = InterfaceTheme.dark;
      expect(ProtoColors.hex(ProtoColors.orange), '#d1975f');
      expect(ProtoColors.parse('#d1975f')!.toARGB32(),
          ProtoColors.orange.toARGB32());
      expect(
          ProtoColors.parse(ProtoColors.hex(ProtoColors.dim)), ProtoColors.dim);
    });
  });

  group('contraste por tema × modo daltónico', () {
    const text = {
      'ink': ProtoColors.ink,
      'title': ProtoColors.title,
      'gold': ProtoColors.gold,
      'sky': ProtoColors.sky,
      'dim': ProtoColors.dim,
      'chat': ProtoColors.chat,
      'green': ProtoColors.green,
      'ice': ProtoColors.ice,
      'red': ProtoColors.red,
      'crimson': ProtoColors.crimson,
      'orange': ProtoColors.orange,
      'pink': ProtoColors.pink,
      'violet': ProtoColors.violet,
      'cream': ProtoColors.cream,
      'mint': ProtoColors.mint,
      'burn': ProtoColors.burn,
      'white': ProtoColors.white,
    };
    const backgrounds = {
      'bg': ProtoColors.bg,
      'panel': ProtoColors.panel,
      'input': ProtoColors.input,
      'button': ProtoColors.button,
    };
    for (final theme in InterfaceTheme.values) {
      for (final roles in TextColorMode.values) {
        for (final mode in ColorVision.values) {
          test('${theme.name} · ${roles.name} · ${mode.name}', () {
            UiTheme.kind = theme;
            UiTheme.textColors = roles;
            VisionPalette.mode = mode;
            // Texto de lectura: AA (≥ 4.5:1).
            for (final t in text.entries) {
              for (final b in backgrounds.entries) {
                expect(contrast(t.value, b.value), greaterThanOrEqualTo(4.5),
                    reason: '${t.key} sobre ${b.key}');
              }
            }
            // Rarezas (nombres) AA sobre fondo / panel / campo y ≥ 3:1
            // sobre botón (etiquetas).
            for (final s in const [
              VisionSlot.magic,
              VisionSlot.rare,
              VisionSlot.epic,
              VisionSlot.legendary,
            ]) {
              for (final b in [
                ProtoColors.bg,
                ProtoColors.panel,
                ProtoColors.input
              ]) {
                expect(contrast(VisionColor(s), b), greaterThanOrEqualTo(4.5),
                    reason: s.name);
              }
              expect(contrast(VisionColor(s), ProtoColors.button),
                  greaterThanOrEqualTo(3),
                  reason: '${s.name} sobre botón');
            }
            // Foco / selección (dorado) ≥ 3:1 contra el panel y el botón.
            expect(contrast(ProtoColors.gold, ProtoColors.panel),
                greaterThanOrEqualTo(3));
            expect(contrast(ProtoColors.gold, ProtoColors.button),
                greaterThanOrEqualTo(3));
          });
        }
      }
    }

    test('jerarquía por brillo: título > cuerpo > atenuado (por roles)', () {
      for (final theme in InterfaceTheme.values) {
        UiTheme.kind = theme;
        UiTheme.textColors = TextColorMode.reduced;
        final t = ProtoColors.title.computeLuminance();
        final b = ProtoColors.ink.computeLuminance();
        final m = ProtoColors.dim.computeLuminance();
        expect(t, greaterThan(b), reason: theme.name);
        expect(b, greaterThan(m), reason: theme.name);
        if (theme == InterfaceTheme.dark) {
          // Atenuado claramente más oscuro que la descripción.
          expect(contrast(ProtoColors.ink, ProtoColors.dim),
              greaterThanOrEqualTo(1.5));
        }
      }
    });

    test('ALTO CONTRASTE: bordes y foco ≥ 7:1 sobre negro', () {
      UiTheme.kind = InterfaceTheme.highContrast;
      for (final c in [
        ProtoColors.buttonBorder,
        ProtoColors.inputBorder,
        ProtoColors.gold,
        ProtoColors.ink,
      ]) {
        expect(contrast(c, ProtoColors.panel), greaterThanOrEqualTo(7));
      }
    });
  });

  group('colores del texto por roles', () {
    /// Color de cada trozo de texto de [markup] (`texto` → color).
    Map<String, Color?> colors(String markup) {
      final out = <String, Color?>{};
      void walk(InlineSpan s, Color? inherited) {
        if (s is! TextSpan) return;
        final c = s.style?.color ?? inherited;
        if (s.text != null && s.text!.trim().isNotEmpty) {
          out[s.text!.trim()] = c;
        }
        for (final k in s.children ?? const <InlineSpan>[]) {
          walk(k, c);
        }
      }

      walk(protoSpan(markup), null);
      return out;
    }

    const m = '<b>Paladín Creyente</b><br>'
        '<span class="k">KEYSTONE · Cluster Fe</span><br>'
        'ATQ <b>120</b> · <span style="color:#c39bff">Pasiva viva</span><br>'
        '• <span style="color:#9fc4ff">+12% crítico</span><br>'
        '<span style="color:#7bed9f">▲ mejor</span> '
        '<span style="color:#ff6b81">Necesita un nodo</span><br>'
        '<b style="color:#be6eff">Hoja Larga</b> '
        '<span style="color:#ff7b29">Quemadura</span> '
        '<span style="color:#e84393">ULT: Juicio</span> '
        '<small>pie</small>';

    test('COMPLETO: cada uno con su color (como v0.8.0)', () {
      final c = colors(m);
      expect(c['Paladín Creyente'], ProtoColors.gold);
      expect(c['KEYSTONE · Cluster Fe'], ProtoColors.sky);
      expect(c['Pasiva viva']!.toARGB32(), 0xFFC39BFF);
      expect(c['ULT: Juicio'], ProtoColors.pink);
    });

    test('REDUCIDO: título, cuerpo, atenuado, acento; significado igual', () {
      UiTheme.kind = InterfaceTheme.dark;
      UiTheme.textColors = TextColorMode.reduced;
      final c = colors(m);
      expect(c['Paladín Creyente'], ProtoColors.title);
      expect(c['KEYSTONE · Cluster Fe'], ProtoColors.dim);
      expect(c['120'], ProtoColors.gold);
      expect(c['Pasiva viva'], ProtoColors.ink);
      expect(c['+12% crítico'], ProtoColors.ink);
      expect(c['ULT: Juicio'], ProtoColors.ink);
      expect(c['pie'], ProtoColors.dim);
      // Mejora / empeora, rarezas y estados no cambian.
      expect(c['▲'], ProtoColors.green);
      expect(c['Necesita un nodo'], ProtoColors.red);
      expect(c['Hoja Larga']!.toARGB32(),
          const VisionColor(VisionSlot.epic).toARGB32());
      expect(c['Quemadura']!.toARGB32(), 0xFFFF7B29);
      // La paleta que queda es chica.
      final used = {for (final v in c.values.nonNulls) v.toARGB32()};
      expect(used.length, lessThanOrEqualTo(8));
    });

    test('ALTO CONTRASTE usa siempre los roles', () {
      UiTheme.kind = InterfaceTheme.highContrast;
      expect(colors(m)['Pasiva viva'], ProtoColors.ink);
    });
  });

  group('espaciado AMPLIO', () {
    Future<void> pump(WidgetTester tester, Widget child) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
          MaterialApp(theme: RetroTheme.build(), home: Scaffold(body: child)));
      await tester.pump();
    }

    testWidgets('interlineado, párrafos, separadores y aire', (tester) async {
      expect(RetroType.line, 1.0);
      UiTheme.spacing = UiSpacing.wide;
      expect(RetroType.line, 1.25);
      RetroType.classic = true;
      expect(RetroType.line, 1.9);
      RetroType.classic = false;
      expect(UiTheme.space(8), 12);
      await pump(
          tester,
          const Column(children: [
            ProtoText('Uno<br>Dos<br>Tres'),
            RetroTipText('Nombre<br><span class="k">Mods 1/4</span><br>• mod',
                maxWidth: 300),
            SectionPanel(
                key: ValueKey('sp'),
                icon: PixelIconKind.lock,
                title: 'S',
                children: [SizedBox(height: 4)]),
          ]));
      // Un párrafo por línea.
      expect(find.text('Uno'), findsOneWidget);
      expect(find.text('Tres'), findsOneWidget);
      expect(find.byKey(const ValueKey('tip-rule-1')), findsOneWidget);
      final sp = tester.widget<Container>(find
          .descendant(
              of: find.byKey(const ValueKey('sp')),
              matching: find.byType(Container))
          .first);
      expect(sp.margin, const EdgeInsets.only(bottom: 15));
    });

    testWidgets('NORMAL: el markup queda en un solo texto', (tester) async {
      await pump(tester, const ProtoText('Uno<br>Dos'));
      expect(find.text('Uno\nDos'), findsOneWidget);
    });
  });

  testWidgets('ACCESIBILIDAD: tema, colores, espaciado y vista previa',
      (tester) async {
    await loadRealFonts(tester);
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = InMemoryGameSettingsStore();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        gameSettingsProvider
            .overrideWith((ref) => GameSettingsController(store: store)),
      ],
      child: MaterialApp(
        theme: RetroTheme.build(),
        builder: (context, child) => Consumer(
          builder: (context, ref, _) {
            final s = ref.watch(gameSettingsProvider);
            return UiThemeScope(
                theme: s.uiTheme,
                textColors: s.textColors,
                spacing: s.spacing,
                child: child!);
          },
        ),
        home: Scaffold(
            body: SettingsMenu(
                onClose: () {}, initialTab: SettingsTab.accessibility)),
      ),
    ));
    await tester.pump();
    expect(find.byKey(const ValueKey('a11y-theme-preview')), findsOneWidget);
    // ALTO CONTRASTE por defecto desde v0.8.2.
    expect(UiTheme.kind, InterfaceTheme.highContrast);
    for (final (key, check) in <(String, bool Function())>[
      ('a11y-theme-OSCURO', () => store.saved?.uiTheme == InterfaceTheme.dark),
      (
        'a11y-theme-ALTO CONTRASTE',
        () => store.saved?.uiTheme == InterfaceTheme.highContrast
      ),
      ('a11y-theme-AZUL', () => store.saved?.uiTheme == InterfaceTheme.blue),
      (
        'a11y-textcolors-COMPLETO',
        () => store.saved?.textColors == TextColorMode.full
      ),
      ('a11y-spacing-AMPLIO', () => store.saved?.spacing == UiSpacing.wide),
    ]) {
      await tapVisible(tester, find.byKey(ValueKey(key)));
      await tester.pump();
      expect(check(), isTrue, reason: key);
      expect(tester.takeException(), isNull);
    }
    expect(UiTheme.kind, InterfaceTheme.blue);
    expect(UiTheme.wide, isTrue);
  });

  // Sin desbordes a 1280×720 en los 3 temas × 2 espaciados, Normal y Muy
  // grande, en las pantallas más cargadas.
  group('sin desbordes', () {
    setUpAll(loadRealFonts);
    for (final theme in InterfaceTheme.values) {
      for (final spacing in UiSpacing.values) {
        for (final size in [TextSize.normal, TextSize.huge]) {
          final name = '${theme.name} ${spacing.name} ${size.name}';
          void apply() {
            UiTheme.kind = theme;
            UiTheme.spacing = spacing;
            UiTheme.textColors = TextColorMode.reduced;
          }

          testWidgets('$name: ficha de objeto, FUSIÓN 2/3, ATRIBUTOS',
              (tester) async {
            apply();
            final p = lootWarrior(extra: [legendWand]);
            // Ficha de un Legendario (tooltip).
            await pumpPanel(tester,
                profile: p,
                textSize: size,
                build: (v, c) => Align(
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
            expect(r.left >= 0 && r.top >= 0, isTrue);
            expect(r.right <= 1280 && r.bottom <= 720, isTrue);
            expect(tester.takeException(), isNull);
            await mouse.moveTo(Offset.zero);
            await tester.pumpWidget(const SizedBox());

            // FUSIÓN: paso 2 (acciones) y 3 (confirmar).
            await pumpPanel(tester,
                profile: lootWarrior(),
                textSize: size,
                build: (v, c) => ForgePanel(
                    view: v, controller: c, initialTab: ForgeHallTab.fuse));
            await tapVisible(
                tester, find.byKey(const ValueKey('bench-weapon-r1')));
            await tapVisible(tester, find.byKey(const ValueKey('bench-next')));
            expect(
                find.byKey(const ValueKey('bench-op-reroll')), findsOneWidget);
            expect(tester.takeException(), isNull, reason: 'paso 2');
            await tapVisible(
                tester, find.byKey(const ValueKey('bench-op-reroll')));
            expect(find.byKey(const ValueKey('craft-confirm')), findsOneWidget);
            expect(tester.takeException(), isNull, reason: 'paso 3');
            await tester.pumpWidget(const SizedBox());

            // ATRIBUTOS.
            await pumpPanel(tester,
                profile: p,
                textSize: size,
                build: (v, c) => CharacterPanel(
                    view: v,
                    controller: c,
                    initialTab: CharacterTab.attributes));
            expect(tester.takeException(), isNull, reason: 'atributos');
          });

          testWidgets('$name: bestiario y ventana de comandos', (tester) async {
            apply();
            tester.view.physicalSize = const Size(1280, 720);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            Widget app(Widget home) => MaterialApp(
                  theme: RetroTheme.build(),
                  builder: (context, child) =>
                      RetroTextScale(factor: size.factor, child: child!),
                  home: Scaffold(body: home),
                );
            await tester.pumpWidget(app(BestiaryView(
                bestiary: BestiaryProgress({'slime': 5, 'lobo': 3}))));
            await tester.pump();
            expect(find.byKey(const ValueKey('bestiary-detail-slime')),
                findsOneWidget);
            expect(tester.takeException(), isNull, reason: 'bestiario');

            final engine = BattleEngine(
              stats: StatsCalculator(
                  classes: kClasses, treeRules: PassiveTreeRules(kPassiveTree)),
              random: () => 0.99,
            );
            final start = engine.start(
              party: [
                for (final id in ['guerrero', 'maga', 'tirador', 'paladin'])
                  member(id),
              ],
              enemyTypes: const ['slime', 'bat', 'golem'],
              triggeredBy: 'guerrero',
            );
            final state = engine.nextTurn(start.state).state;
            await tester.pumpWidget(app(BattleView(
                battle: state,
                canAct: true,
                localId: 'guerrero',
                turnTimeLeft: 25,
                onCommand: (_) => true)));
            await tester.pump();
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
}
