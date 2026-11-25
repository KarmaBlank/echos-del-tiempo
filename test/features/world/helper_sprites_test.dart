import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/farm_layer.dart';
import 'package:echos_del_tiempo/game_engine/rules/town_rules.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

Future<int> opaque(ui.Image im) async {
  final d = (await im.toByteData(format: ui.ImageByteFormat.rawStraightRgba))!;
  var n = 0;
  for (var i = 3; i < d.lengthInBytes; i += 4) {
    if (d.getUint8(i) > 0) n++;
  }
  return n;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('helper and miner sprites resolve to visible pixels', () async {
    final sprites = await GameSprites.load(await SpriteCatalog.load());
    for (final id in const [
      'npc_granjero',
      'npc_granjero_trabajo',
      'npc_pescador',
      'npc_pescador_trabajo',
      'npc_mina_miner',
    ]) {
      final im = sprites.lifeIcon(id, 'herramienta');
      expect(im, isNotNull, reason: id);
      expect(await opaque(im!), greaterThan(20), reason: id);
    }
  });

  test('a hired farm/fishing helper paints pixels on the town layer', () async {
    final sprites = await GameSprites.load(await SpriteCatalog.load());
    const base = TownState();
    final town = base.copyWith(builds: [
      for (final b in base.builds)
        b.kind == BuildKind.huerta || b.kind == BuildKind.lago
            ? b.copyWith(helper: 1)
            : b
    ]);
    expect(town.builds.where((b) => b.helper > 0), isNotEmpty);
    for (final b in town.builds.where((b) => b.helper > 0)) {
      final pos = TownRules.helperPos(town, b, 0, 1);
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      c.translate(-pos.x + 32, -pos.y + 32);
      MapFarmLayer().drawHelpers(c, town, 1, 0,
          (id) => sprites.lifeIcon(id, 'herramienta'), (a, b, c2, d, e) {});
      final im = await rec.endRecording().toImage(64, 64);
      final d = (await im.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      var n = 0;
      for (var y = 16; y < 48; y++) {
        for (var x = 16; x < 48; x++) {
          if (d.getUint8((y * 64 + x) * 4 + 3) > 0) n++;
        }
      }
      expect(n, greaterThan(20), reason: '${b.kind}');
    }
  });
}
