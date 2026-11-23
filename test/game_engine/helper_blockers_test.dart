import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/farming_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/helper_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/town_rules.dart';
import 'package:flutter_test/flutter_test.dart';

// Ayudantes bloqueados (farming.md § 8.6, v0.33.1).

FarmPlot _seedling() => FarmingRules.plant(FarmingRules.till(), 'nabo_claro')!;

FarmPlot _ripe() => _seedling().copyWith(
    grow: FarmingRules.growSec('nabo_claro'),
    wetGrow: FarmingRules.growSec('nabo_claro'));

Map<String, FarmPlot> _all(TownBuild b, FarmPlot p) =>
    {for (final (x, y) in TownRules.helperArea(b, 0)) plotKey(x, y): p};

Map<String, int> _fullChest() => {'mojarra_claro': TownRules.t.i('chestMax')};

void main() {
  final farm = kBaseFarm.copyWith(helper: 1);

  group('granjero bloqueado', () {
    test('sin semillas para plantar', () {
      final b = farm.copyWith(tasks: [HelperTask.plantar.bit]);
      expect(HelperRules.blockers(b, 0), ['Sin semillas para plantar']);
      expect(HelperRules.blockers(farm, 0), contains('Sin semillas para plantar'));
    });

    test('sin parcelas asignadas', () {
      final b = farm.copyWith(helper: 9, seeds: {'nabo_claro': 5});
      final last = b.helper - 1;
      expect(TownRules.helperArea(b, last), isEmpty);
      expect(HelperRules.blockers(b, last), ['No hay parcelas asignadas']);
    });

    test('todo plantado y su única tarea es plantar', () {
      var b = farm.copyWith(
          seeds: {'nabo_claro': 5}, tasks: [HelperTask.plantar.bit]);
      b = b.copyWith(plots: _all(b, _seedling()));
      expect(HelperRules.blockers(b, 0), ['Todas sus parcelas están plantadas']);
    });

    test('cofre lleno con cosecha madura', () {
      var b = farm.copyWith(chest: _fullChest(), tasks: [HelperTask.cosechar.bit]);
      b = b.copyWith(plots: _all(b, _ripe()));
      expect(HelperRules.blockers(b, 0), ['El cofre está lleno']);
    });

    test('sin tareas prendidas', () {
      final b = farm.copyWith(seeds: {'nabo_claro': 5}, tasks: [0]);
      expect(HelperRules.blockers(b, 0), ['No tiene tareas prendidas']);
    });

    test('bloqueado se queda quieto', () {
      final s = const TownState().withBuild(farm);
      final a = TownRules.helperPos(s, farm, 0, 0);
      final z = TownRules.helperPos(s, farm, 0, 37);
      expect((a.x, a.y, a.work), (z.x, z.y, false));
    });
  });

  group('granjero esperando (no bloqueado)', () {
    test('tiene semillas y lugar', () {
      expect(HelperRules.blockers(farm.copyWith(seeds: {'nabo_claro': 1}), 0),
          isEmpty);
    });

    test('todo plantado: va a regar y a cosechar', () {
      var b = farm.copyWith(seeds: {'nabo_claro': 5});
      b = b.copyWith(plots: _all(b, _seedling().copyWith(wet: 30)));
      expect(TownRules.farmerNext(b, 0), isNull, reason: 'hoy no hay nada');
      expect(HelperRules.blockers(b, 0), isEmpty);
    });

    test('solo cosechar: espera que crezca lo regado', () {
      var b = farm.copyWith(tasks: [HelperTask.cosechar.bit]);
      b = b.copyWith(plots: _all(b, _seedling().copyWith(wet: 30)));
      expect(HelperRules.blockers(b, 0), isEmpty);
    });

    test('solo plantar, sin lugar pero cosechando liberará parcelas', () {
      var b = farm.copyWith(seeds: {'nabo_claro': 5}, tasks: [
        HelperTask.plantar.bit | HelperTask.cosechar.bit
      ]);
      b = b.copyWith(plots: _all(b, _ripe()));
      expect(HelperRules.blockers(b, 0), isEmpty);
    });
  });

  test('texto del cofre: vacío, con cosas, lleno', () {
    expect(HelperRules.chestText(kBaseLake), 'Cofre vacío');
    expect(HelperRules.chestText(kBaseLake.copyWith(chest: {'mojarra_claro': 3})),
        'Cofre: 3 objetos');
    expect(HelperRules.chestText(kBaseLake.copyWith(chest: _fullChest())),
        'Cofre lleno');
  });

  group('pescador', () {
    final lake = kBaseLake.copyWith(helper: 1);
    test('pesca mientras haya lugar en el cofre', () {
      expect(HelperRules.blockers(lake, 0), isEmpty);
    });
    test('cofre lleno', () {
      expect(HelperRules.blockers(lake.copyWith(chest: _fullChest()), 0),
          ['El cofre está lleno']);
    });
  });
}
