// Fila del grupo (free_movement.md § 4, v0.49.21): UNA fila de cajas del
// mismo tamaño; los atajos de pociones no se mueven cuando alguien entra,
// sale o cambia de lugar. Con PARTY_HUD_SHOTS=1 guarda
// docs/preview/party_hud_row.png (1, 2 y 4 miembros, 2 en otro lugar):
//   $env:PARTY_HUD_SHOTS = "1"; flutter test test/features/world/party_hud_row_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/core/settings/settings_providers.dart';
import 'package:echos_del_tiempo/features/world/presentation/hud/world_hud.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../real_fonts.dart';
import '../../game_engine/session_test_helpers.dart';
import 'big_room_fixture.dart';

final _shots = Platform.environment['PARTY_HUD_SHOTS'] != null;

const _awayPool = [
  AwayPlayer('x1', 'AitorTilla', 'BOSQUE', 'bosque'),
  AwayPlayer('x2', 'Héroe', 'BOSQUE', 'bosque'),
];

class _Shot {
  _Shot(this.quick, this.boxes, this.cards);
  final Rect quick;
  final Rect boxes;
  final List<Rect> cards;
}

Future<_Shot> _pump(WidgetTester tester, int present, int away,
    List<ui.Image> images) async {
  late List<SessionController> all;
  await tester.runAsync(() async {
    (all, _) = await bigRoom(present);
  });
  final host = all.first;
  host.view!.session.away = _awayPool.take(away).toList();
  final g = GameSettingsController(
      store: InMemoryGameSettingsStore(), initial: const GameSettings());
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sessionEngineProvider.overrideWithValue(sessionEngine(zones: true)),
      profileStoreProvider.overrideWithValue(InMemoryProfileStore()),
      sessionClockProvider
          .overrideWithValue(const SessionClock(autoStart: false)),
      gameSettingsProvider.overrideWith((ref) => g),
    ],
    child: MaterialApp(
      theme: RetroTheme.build(),
      home: Scaffold(
        body: RepaintBoundary(
          key: const ValueKey('shot'),
          child: WorldHud(
              view: host.view!, controller: host, chatFocus: FocusNode()),
        ),
      ),
    ),
  ));
  await tester.pump();
  expect(tester.takeException(), isNull);
  final s = host.view!.session;
  final shot = _Shot(
    tester.getRect(find.byKey(const ValueKey('hud-quick-slots'))),
    tester.getRect(find.byKey(const ValueKey('hud-party-boxes'))),
    [
      for (final a in s.away)
        tester.getRect(find.byKey(ValueKey('hud-away-${a.id}'))),
      for (final p in s.playerList)
        tester.getRect(find.byKey(ValueKey('hud-party-${p.id}'))),
    ],
  );
  if (_shots) {
    await tester.runAsync(() async {
      final b = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('shot')));
      images.add(await b.toImage());
    });
  }
  await tester.pumpWidget(const SizedBox());
  for (final c in all.reversed) {
    if (c.mounted) c.dispose();
  }
  return shot;
}

void main() {
  setUpAll(loadRealFonts);

  testWidgets('una fila fija: 1, 2 y 4 miembros, con gente en otro lugar',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final images = <ui.Image>[];
    final shots = [
      await _pump(tester, 1, 0, images),
      await _pump(tester, 2, 0, images),
      await _pump(tester, 4, 0, images),
      // Los mismos 4, dos en otro lugar: nada cambia de tamaño ni lugar.
      await _pump(tester, 2, 2, images),
    ];
    final first = shots.first;
    for (final s in shots) {
      // Atajos: mismo rectángulo con 1, 2 o 4.
      expect(s.quick, first.quick);
      // Todas las cajas del mismo tamaño y en una sola fila.
      for (final c in s.cards) {
        expect(c.size, first.cards.first.size);
        expect(c.top, closeTo(s.cards.first.top, 0.01));
      }
      expect(s.boxes.height, closeTo(first.boxes.height, 0.01));
      expect(s.boxes.right, closeTo(first.boxes.right, 0.01));
    }
    // Cambiar de lugar no cambia la fila.
    expect(shots[3].boxes, shots[2].boxes);
    expect(shots[3].cards.length, 4);

    if (!_shots) return;
    await tester.runAsync(() async {
      // Recorte de la esquina de abajo a la derecha de cada caso, apilados.
      const crop = Rect.fromLTWH(1280 - 900, 720 - 150, 900, 150);
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      for (var i = 0; i < images.length; i++) {
        canvas.drawImageRect(images[i], crop,
            Rect.fromLTWH(0, i * crop.height, crop.width, crop.height),
            Paint());
      }
      final img = await rec.endRecording().toImage(
          crop.width.toInt(), (crop.height * images.length).toInt());
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      Directory('docs/preview').createSync(recursive: true);
      File('docs/preview/party_hud_row.png')
          .writeAsBytesSync(png!.buffer.asUint8List());
    });
  });
}
