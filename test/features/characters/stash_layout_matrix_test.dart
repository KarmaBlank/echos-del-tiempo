// ALIJO por datos (docs/specs/editor_layout.md § 2.5.2, § 4 "Widget"):
// en toda la matriz de tamaños × textos, con el layout por defecto y con
// la fila de acciones movida, sin desbordes, nada fuera del panel, sin
// solapes entre hermanos, objetivos de clic ≥ 32 y orden de foco = orden
// visual en cada región.
import 'package:echos_del_tiempo/app/design/ds_layout_host.dart';
import 'package:echos_del_tiempo/app/theme/panel_frame.dart';
import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/core/layout/layout_doc.dart';
import 'package:echos_del_tiempo/core/layout/layout_validator.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/features/characters/domain/stash.dart';
import 'package:echos_del_tiempo/features/characters/presentation/stash_board.dart';
import 'package:echos_del_tiempo/features/characters/presentation/stash_layout.dart';
import 'package:echos_del_tiempo/game_engine/models/loot.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/rules/inventory_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/progression_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../../real_fonts.dart';
import '../inventory/loot_fixtures.dart';

class _Host implements StashBoardHost {
  _Host(this.profile, this.stash);
  @override
  ProgressionRules get rules => progression;
  @override
  PlayerProfile profile;
  @override
  Stash stash;
  @override
  bool get busy => false;
  @override
  String? get notice => null;
  @override
  String? put(List<String> tokens, int tab) => null;
  @override
  String? take(List<int> cells) => null;
  @override
  bool moveStash(int from, int to) => false;
  @override
  bool moveCharacter(int from, int to) => false;
  @override
  void achievement(String id) {}
}

/// Solo mide: una clave por slot.
class _Measure extends DsLayoutHooks {
  final keys = <String, GlobalKey>{};
  LayoutBreakpoint? bp;
  @override
  void breakpoint(LayoutBreakpoint b) => bp = b;
  @override
  Widget slot(BuildContext context, String id, String container, int index,
          Widget child) =>
      KeyedSubtree(key: keys.putIfAbsent(id, GlobalKey.new), child: child);
  @override
  Widget container(BuildContext context, String id, LayoutAxis axis,
          List<String> children, Widget child) =>
      child;
}

void main() {
  final spec = StashLayout.spec;
  final docs = {
    'por defecto': spec.defaults,
    'acciones arriba y ELEGIR a la derecha': spec.defaults
        .move(StashLayout.actions, 'header', 0)
        .move(StashLayout.pick, 'right', 1)
        .withRule(LayoutBreakpoint.narrow, StashLayout.actions,
            (r) => r.copyWith(axis: LayoutAxis.column)),
  };
  const sizes = [
    Size(1280, 720),
    Size(1920, 1080),
    Size(2560, 1440),
    Size(800, 600),
    Size(600, 900),
  ];
  const texts = [TextSize.normal, TextSize.huge, TextSize.enormous];
  for (final MapEntry(key: name, value: doc) in docs.entries) {
    test('$name valida (estático)', () {
      expect(LayoutValidator.validateStatic(doc, spec).where((i) => i.error),
          isEmpty);
    });
    for (final size in sizes) {
      testWidgets(
          'alijo $name ${size.width.toInt()}x${size.height.toInt()}: sin '
          'desbordes ni solapes en todos los textos', (tester) async {
        await loadRealFonts(tester);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var p = lootWarrior();
        for (final k in StackKind.values) {
          p = InventoryRules.withStack(p, k, 3);
        }
        final host =
            _Host(p, Stash.empty().put(0, const StashEntry.item(epicSword)));
        for (final t in texts) {
          final m = _Measure();
          await tester.pumpWidget(MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: RetroTheme.build(),
            builder: (context, child) =>
                RetroTextScale(factor: t.factor, child: child!),
            home: Scaffold(
                body: SingleChildScrollView(
              child: PanelFrame(
                key: const ValueKey('panel'),
                title: 'ALIJO',
                width: 1000,
                onClose: () {},
                child: StashBoard(
                    key: ValueKey(t),
                    host: host,
                    title: 'Ana · Guerrero · Nv 5',
                    layout: doc,
                    layoutHooks: m),
              ),
            )),
          ));
          await tester.pump();
          expect(tester.takeException(), isNull, reason: t.name);
          final board = tester.getRect(find.byType(StashBoard));
          LayoutRect rect(Rect r) => LayoutRect(r.left, r.top, r.width, r.height);
          final rects = <String, LayoutRect>{
            for (final MapEntry(:key, :value) in m.keys.entries)
              if (value.currentContext != null)
                key: rect(tester.getRect(find.byKey(value))),
          };
          final res = doc.resolve(m.bp);
          final siblings = [
            for (final ids in res.children.values)
              [for (final id in ids) if (rects.containsKey(id)) id],
          ];
          final issues = LayoutValidator.validateGeometry(
            where: '${size.width.toInt()}x${size.height.toInt()} ${t.name}',
            viewport: LayoutRect(board.left, board.top, board.width, 1e9),
            slots: rects,
            siblings: siblings,
            targets: {
              for (final MapEntry(:key, :value) in rects.entries)
                if ((spec.slots[key]?.interactive ?? false) &&
                    !(spec.slots[key]?.group ?? false))
                  key: [value],
            },
            focusGroups: siblings,
          );
          expect(issues, isEmpty, reason: issues.join('\n'));
          // Las claves de test se conservan (§ 4, riesgos).
          for (final k in ['stash-deposit', 'stash-move-all', 'stash-pick']) {
            expect(find.byKey(ValueKey(k)), findsOneWidget, reason: k);
          }
        }
      });
    }
  }
}
