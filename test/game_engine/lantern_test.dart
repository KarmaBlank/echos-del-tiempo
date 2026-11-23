import 'package:echos_del_tiempo/game_engine/data/light_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/zones_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/rules/light_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/map_generator.dart';
import 'package:echos_del_tiempo/game_engine/rules/world_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// Faroles de las mazmorras oscuras (lighting.md § 5.5).
void main() {
  test('solo en pisos oscuros, sin cortar el paso ni pisar lugares', () {
    var dark = 0;
    for (final z in kZones) {
      for (final seed in [1, 7, 42, 1234]) {
        final m = MapGenerator.zone(z, seed);
        for (final f in m.floors) {
          final ls = [
            for (final p in f.pois)
              if (p.kind == PoiKind.lantern) p,
          ];
          final isDark = LightRules.isDark(z.theme, floor: f.index);
          if (!isDark) {
            expect(ls, isEmpty, reason: '${z.id} $seed ${f.index}');
            continue;
          }
          dark++;
          expect(ls.length, greaterThanOrEqualTo(2),
              reason: '${z.id} $seed ${f.index}');
          for (final l in ls) {
            expect(m.tileAt(l.tx, l.ty), Tile.lantern);
            expect(f.spots.contains((l.tx, l.ty)), isFalse);
            // Los 8 vecinos caminables: no tapa ningún pasillo.
            for (var dy = -1; dy <= 1; dy++) {
              for (var dx = -1; dx <= 1; dx++) {
                if (dx == 0 && dy == 0) continue;
                expect(Tile.isWalkable(m.tileAt(l.tx + dx, l.ty + dy)), isTrue);
              }
            }
            for (final o in ls) {
              if (identical(o, l)) continue;
              final dx = o.tx - l.tx, dy = o.ty - l.ty;
              expect(dx * dx + dy * dy, greaterThanOrEqualTo(144));
            }
          }
        }
      }
    }
    expect(dark, greaterThan(0), reason: 'hay zonas oscuras en el catálogo');
  });

  test('E enciende el farol: tile encendido y luz grande', () {
    final zone = kZones.indexWhere((z) => z.theme == 'cavernas') + 1;
    final e = sessionEngine(zones: true, seed: 7);
    var s = inField(e, kZones[zone - 1].missionId!,
        profiles: [newProfile('J0', 'guerrero').copyWith(unlockedZone: 10)]);
    final f = e.mapFor(s).floor(0)!;
    final l = f.pois.firstWhere((p) => p.kind == PoiKind.lantern);
    final map = e.mapFor(s);
    WorldPoint? at;
    for (final (dx, dy) in const [(0, 1), (1, 0), (-1, 0), (0, -1)]) {
      final x = (l.tx + dx) * 16 + 8.0, y = (l.ty + dy) * 16 + 8.0;
      if (!WorldRules.collides(map, x, y, blockVoid: true)) {
        at = WorldPoint(x, y);
        break;
      }
    }
    s = moveTo(e, s, 'p0', at!.x, at.y);
    s = act(e, s, 'p0', InteractPoiAction(l.id));
    expect(s.mission!.poiUsed, contains(l.id));
    expect(e.mapFor(s).tileAt(l.tx, l.ty), Tile.lanternLit);
    expect(kTileLights[Tile.lanternLit], LightId.farol);
    expect(kLightDefs[LightId.farol]!.radius,
        greaterThan(kLightDefs[LightId.jugadorOscuro]!.radius));
    // No se vuelve a usar.
    expect(e.apply(s, 'p0', InteractPoiAction(l.id)), isNull);
  });
}
