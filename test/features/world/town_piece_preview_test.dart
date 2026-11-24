import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/world/presentation/panels/town_piece_preview.dart';
import 'package:echos_del_tiempo/game_engine/data/construction_catalog.dart';
import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// town_editor.md § 1.2: cada miniatura dibuja SOLO dentro de su caja
/// (el faro, más alto que un tile, se achica para entrar).
void main() {
  const pad = 20.0;
  for (final side in const [60.0, 128.0]) {
    for (final id in [for (final d in kConstructions) d.id, kFaroId]) {
      testWidgets('miniatura $id ($side) no se sale de su caja',
          (tester) async {
        final key = GlobalKey();
        late GameSprites sprites;
        await tester.runAsync(() async {
          sprites = await GameSprites.load(await SpriteCatalog.load());
        });
        await tester.pumpWidget(ProviderScope(
            overrides: [gameSpritesProvider.overrideWith((ref) => sprites)],
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Center(
                child: RepaintBoundary(
                  key: key,
                  child: Padding(
                    padding: const EdgeInsets.all(pad),
                    child: TownPiecePreview(id, size: side),
                  ),
                ),
              ),
            )));
        await tester.pump();
        final ro =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final bytes = await tester.runAsync(() async {
          final img = await ro.toImage();
          final d = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
          final w = img.width;
          img.dispose();
          return (d!, w);
        });
        final (data, w) = bytes!;
        final h = data.lengthInBytes ~/ (4 * w);
        var inside = 0;
        for (var y = 0; y < h; y++) {
          for (var x = 0; x < w; x++) {
            final a = data.getUint8((y * w + x) * 4 + 3);
            if (a == 0) continue;
            final within =
                x >= pad && x < pad + side && y >= pad && y < pad + side;
            expect(within, isTrue, reason: '$id pinta en ($x, $y)');
            inside++;
          }
        }
        if (id == kFaroId) expect(inside, greaterThan(0));
      });
    }
  }
}
