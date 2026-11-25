import 'package:echos_del_tiempo/features/world/presentation/map/farm_layer.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/town_rules.dart';
import 'package:flutter_test/flutter_test.dart';

// Pescador ayudante en pantalla (farming.md § 8.1, v0.48.2): respira
// quieto, usa el cuadro de trabajo solo en el momento de la pesca (la
// vuelta del motor) y cada tanto cambia de lugar en la orilla.

void main() {
  const town = TownState();
  final lake = town.builds
      .firstWhere((b) => b.id == 'l0')
      .copyWith(helper: 3);
  final period = TownRules.t.d('helperEverySec');
  final move = TownRules.t.d('fisherMoveSec');
  final catchSec = TownRules.t.d('fisherCatchSec');

  test('sin brazo fuera del momento de pesca; respira 1 px lento', () {
    for (var s = 1.0; s < period - 1; s += 0.5) {
      final time = period * 3 + s;
      final f = MapFarmLayer.fisherFrame(town, lake, 0, time, time * 1000, period);
      expect(f.sprite, 'npc_pescador', reason: 't=$time');
      expect(f.catching, isFalse);
      expect(f.dy, anyOf(0.0, -1.0));
    }
    // Respiración: cambia cada fisherBreathSec, no en cada cuadro.
    final b = TownRules.t.d('fisherBreathSec') * 1000;
    expect(TownRules.fisherBreath(0), TownRules.fisherBreath(b - 1));
    expect(TownRules.fisherBreath(0), isNot(TownRules.fisherBreath(b + 1)));
  });

  test('el momento de pesca coincide con la vuelta del motor', () {
    for (var k = 1; k < 6; k++) {
      // La vuelta k del motor se dispara al cruzar time = k · period.
      final at = k * period;
      expect(TownRules.fisherCatching(at + 0.01, period), isTrue);
      expect(TownRules.fisherCatching(at + catchSec - 0.01, period), isTrue);
      expect(TownRules.fisherCatching(at + catchSec + 0.01, period), isFalse);
      expect(TownRules.fisherCatching(at - 0.01, period), isFalse);
      final time = at + 0.1;
      if (TownRules.fisherAt(town, lake, 0, time).walk) continue;
      final f = MapFarmLayer.fisherFrame(town, lake, 0, time, 0, period);
      expect(f.sprite, 'npc_pescador_trabajo');
      expect(f.catching, isTrue);
    }
    // Antes de la primera vuelta no hay pesca.
    expect(TownRules.fisherCatching(0.1, period), isFalse);
  });

  test('cambia de lugar: válido, sin compartir y determinista', () {
    final valid = TownRules.fisherSpots(town, lake).toSet();
    expect(valid.length, greaterThanOrEqualTo(3));
    final seen = <(int, int)>{};
    for (var seg = 0; seg < 12; seg++) {
      final spots = [
        for (var i = 0; i < lake.helper; i++)
          TownRules.fisherSpotAt(town, lake, i, seg)
      ];
      expect(spots.toSet().length, spots.length);
      for (final p in spots) {
        expect(valid, contains(p));
        expect(town.builds.any((o) => o.contains(p.$1, p.$2)), isFalse);
        expect(p, isNot(TownRules.chestOf(town, lake)));
        // Mira al agua desde ahí.
        final i = spots.indexOf(p);
        final (dx, dy) =
            TownRules.fisherFacing(town, lake, i, seg * move + move / 2);
        expect(lake.contains(p.$1 + dx, p.$2 + dy), isTrue);
      }
      // Determinista: la misma cuenta da lo mismo.
      expect(TownRules.fisherSpotAt(town, lake, 0, seg), spots[0]);
      seen.add(spots[0]);
    }
    expect(seen.length, greaterThan(1));
    // Tramo 0 = el lugar de siempre.
    expect(TownRules.fisherSpotAt(town, lake, 0, 0),
        TownRules.fisherSpot(town, lake, 0));
  });

  test('camina por la orilla al cambiar, sin teletransportarse', () {
    final a = TownRules.fisherSpotAt(town, lake, 0, 0);
    final z = TownRules.fisherSpotAt(town, lake, 0, 1);
    expect(a, isNot(z));
    final start = TownRules.fisherAt(town, lake, 0, move + 0.01);
    expect(start.walk, isTrue);
    expect((start.x - a.$1).abs() + (start.y - a.$2).abs(), lessThan(0.1));
    final shore = TownRules.shoreTiles(lake).toSet();
    var prev = (start.x, start.y);
    for (var s = 0.05; s < 60; s += 0.05) {
      final p = TownRules.fisherAt(town, lake, 0, move + s);
      // Pasos chicos y siempre fuera del agua.
      expect((p.x - prev.$1).abs() + (p.y - prev.$2).abs(), lessThan(0.3));
      expect(lake.contains(p.x.round(), p.y.round()), isFalse);
      expect(shore.contains((p.x.round(), p.y.round())), isTrue);
      prev = (p.x, p.y);
      if (!p.walk) {
        expect((p.x, p.y), (z.$1.toDouble(), z.$2.toDouble()));
        return;
      }
      final pos = TownRules.helperPos(town, lake, 0, move + s);
      expect(pos.work, isFalse);
    }
    fail('nunca llegó');
  });
}
