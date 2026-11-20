// Capturas de las ULT v2 (v0.17.0, docs/specs/ultimates_v2.md): la
// pestaña ULT de PERSONAJE (elegir la activa y mejorar), cuatro ULT
// nuevas a mitad de animación y una ULT de élite telegrafiada. NO es
// parte de la suite:
//   flutter test tool/shots/v0170_ults_shots_test.dart
// Overrides en una carpeta temporal (nunca %APPDATA% ni el repo).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/admin/presentation/editor/fx_preview.dart';
import 'package:echos_del_tiempo/features/admin/presentation/editor/sprite_editor_controller.dart';
import 'package:echos_del_tiempo/features/combat/data/local_sprite_overrides_io.dart';
import 'package:echos_del_tiempo/features/combat/presentation/battle_hud.dart';
import 'package:echos_del_tiempo/core/fx/fx_catalog.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/fx_bridge.dart';
import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../test/features/panel_test_harness.dart';
import '../../test/game_engine/session_test_helpers.dart';
import '../../test/real_fonts.dart';

const _out = 'docs/release_shots/v0.17.0';

class _DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());
}

Future<void> _screen(WidgetTester tester, String name) async {
  final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  await tester.runAsync(() async {
    final img =
        await layer.toImage(const Offset(0, 0) & const Size(1920, 1080));
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final f = File('$_out/$name.png');
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes!.buffer.asUint8List());
  });
}

PlayerProfile _profile() => progression.normalize(PlayerProfile(
      name: 'Ana',
      classId: 'guerrero',
      level: 24,
      credits: 6400,
      materials: const {CraftMaterial.cristal: 6, CraftMaterial.prisma: 2},
      ultKnown: const {
        'ult2_ecoFilo',
        'ult2_sangreEco',
        'ult2_cadenaEras',
        'ult2_golpeMaestro',
        'ult2_juicioAjeno',
        'ult2_milAyeres',
        'ult2_diluvioMenor',
      },
      ultSel: 'ult2_sangreEco',
      ultLevels: const {'ult2_sangreEco': 3, 'ult2_ecoFilo': 2},
    ));

void main() {
  testWidgets('ULT: elegir la activa y mejorar', (tester) async {
    await pumpPanel(tester,
        devicePixelRatio: 1.5,
        profile: _profile(),
        build: (v, c) => CharacterPanel(
            view: v, controller: c, initialTab: CharacterTab.ults));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MEJORAR').first);
    await tester.pumpAndSettle();
    await _screen(tester, 'ult_pestana_elegir_mejorar');
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('ULT de élite telegrafiada', (tester) async {
    final e = Combatant(
        id: 'e0',
        name: 'Lobo Élite',
        isPlayer: false,
        hp: 140,
        maxHp: 160,
        speed: 14,
        attack: 30,
        critChance: 0.15,
        enemyType: 'lobo',
        elite: true,
        breakBase: 30,
        ultId: 'eult_e_lobo',
        ultPending: true);
    await pumpPanel(tester,
        devicePixelRatio: 1.5,
        profile: _profile(),
        build: (v, c) => Center(child: TargetBar(enemy: e)));
    await tester.pumpAndSettle();
    await _screen(tester, 'elite_ult_telegrafiada');
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('ULT v2: cuadros a mitad de animación', (tester) async {
    await loadRealFonts(tester);
    tester.view.physicalSize = const Size(1000, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final tmp = Directory.systemTemp.createTempSync('ecos_ult_shots_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final o = LocalSpriteOverrides('${tmp.path}/overrides');
    final cat = SpriteCatalog.fromYaml(
        File(SpriteCatalog.manifestPath).readAsStringSync(),
        bundle: _DiskBundle(),
        overrides: o);
    final s = SpriteEditorController(catalog: cat, overrides: o, repoPath: tmp.path);
    late FxCatalog fxCat;
    await tester.runAsync(() async {
      await s.loadAll();
      fxCat = await installFx(bundle: _DiskBundle(), overrides: o);
    });
    for (final (id, ms, n) in const [
      ('ult2_ecoFilo', 1060.0, 1),
      ('ult2_brasaAntigua', 1320.0, 3),
      ('ult2_relojPartido', 1450.0, 3),
      ('ult2_yunqueTiempo', 1300.0, 1),
      ('eult_e_lobo', 900.0, 1),
    ]) {
      final t = fxCat.timeline(id)!;
      final key = GlobalKey();
      await tester.pumpWidget(Center(
        child: RepaintBoundary(
          key: key,
          child: SizedBox(
            width: 960,
            height: 540,
            child: CustomPaint(
              painter: FxPreviewPainter(
                timeline: t,
                time: ms,
                sim: FxPreviewSim(),
                enemies: n,
                hero: s.imageOf('characters.${previewClassOf(t)}.idle'),
                enemyImages: [
                  for (final e in const ['lobo', 'slime', 'golem'])
                    s.imageOf('enemies.$e.idle'),
                ],
              ),
            ),
          ),
        ),
      ));
      await tester.pump();
      await tester.runAsync(() async {
        final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await b.toImage();
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        final f = File('$_out/${id}_${ms.round()}ms.png');
        await f.parent.create(recursive: true);
        await f.writeAsBytes(png!.buffer.asUint8List());
        img.dispose();
      });
    }
  });
}
