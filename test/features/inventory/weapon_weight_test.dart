import 'package:echos_del_tiempo/app/theme/proto_markup.dart';
import 'package:echos_del_tiempo/features/inventory/domain/battle_impact.dart';
import 'package:echos_del_tiempo/features/inventory/domain/item_text.dart';
import 'package:echos_del_tiempo/features/inventory/domain/weapon_compare.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/weapon_compare_view.dart';
import 'package:echos_del_tiempo/game_engine/data/game_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/loot.dart';
import 'package:echos_del_tiempo/game_engine/models/loot_filter.dart';
import 'package:echos_del_tiempo/game_engine/rules/loot_filter_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/weapon_weight.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../panel_test_harness.dart';
import 'loot_fixtures.dart';

/// Peso del arma: categorías, ficha, comparación y filtro. Ver
/// docs/specs/loot.md § 1.1 y panels.md § "Peso del arma".
void main() {
  final weapons = GameCatalog.standard.weapons;

  group('weightClassOf (motor)', () {
    test('cortes: 0 Ligera, 0 < p < 0.8 Media, ≥ 0.8 Pesada', () {
      expect(weightClassFor(0), WeightClass.ligera);
      expect(weightClassFor(0.1), WeightClass.media);
      expect(weightClassFor(0.6), WeightClass.media);
      expect(weightClassFor(0.79), WeightClass.media);
      expect(weightClassFor(0.8), WeightClass.pesada);
      expect(weightClassFor(1.5), WeightClass.pesada);
      expect(kHeavyWeightFrom, 0.8);
    });

    test('todo el catálogo cae en su categoría y hay de las tres', () {
      final count = {for (final c in WeightClass.values) c: 0};
      for (final w in weapons.values) {
        final c = weightClassOf(w);
        count[c] = count[c]! + 1;
        switch (c) {
          case WeightClass.ligera:
            expect(w.weight, 0, reason: w.id);
          case WeightClass.media:
            expect(w.weight, inExclusiveRange(0, 0.8), reason: w.id);
          case WeightClass.pesada:
            expect(w.weight, greaterThanOrEqualTo(0.8), reason: w.id);
        }
      }
      // Distribución del catálogo v0.8.4 (loot.md § 1.1).
      expect(count[WeightClass.ligera], 42);
      expect(count[WeightClass.media], 30);
      expect(count[WeightClass.pesada], 22);
      // Ejemplos por tipo.
      expect(weightClassOf(weapons['espada_bronce']!), WeightClass.ligera);
      expect(weightClassOf(weapons['tomo_plaga']!), WeightClass.media);
      expect(weightClassOf(weapons['hacha_rompe']!), WeightClass.pesada);
      expect(weightClassOf(weapons['mandoble_eco']!), WeightClass.pesada);
    });
  });

  group('ficha', () {
    final p = lootWarrior();

    String tip(ItemInstance it, {bool stats = false}) =>
        protoPlain(itemTooltipMarkup(progression, it,
            level: p.level,
            attributes: p.attributes,
            stats: stats ? progression.previewEquip(p, it.uid) : null));

    test('ligera: "Ligera · sin penalización de velocidad", sin turno', () {
      final t = tip(p.itemByUid('espada_bronce')!, stats: true);
      expect(t, contains('Ligera · sin penalización de velocidad'));
      expect(t, isNot(contains('Por el peso')));
    });

    test('media: "Media: −0.3 vel. · algo más lenta a cambio de poder"', () {
      final t = tip(epicSword);
      expect(
          t,
          contains(protoPlain(
              'Media: −0.3 vel. · algo más lenta a cambio de poder')));
      // Sin stats no hay línea de turno.
      expect(t, isNot(contains('Por el peso')));
    });

    test('pesada: tag, trade-off y lo que cuesta en turnos', () {
      final t = tip(rareAxe, stats: true);
      expect(t, contains(protoPlain('Pesada: −1.5 vel. · suele dar más ATQ')));
      final s = progression.previewEquip(p, 'r1');
      // El mismo cálculo que la batalla: 100 / VEL.
      final withW = 100 / s.speed, without = 100 / (s.speed + 1.5);
      String f(double x) =>
          x == x.roundToDouble() ? '${x.round()}' : x.toStringAsFixed(1);
      expect(
          t,
          contains('Por el peso tu turno llega cada ${f(withW)} de tiempo en '
              'vez de ${f(without)}'));
      expect(t, contains('% más lento)'));
      expect(weightTurnLine(progression, s, 0), isNull);
    });

    test('la línea vieja "Peso X (−X vel.)" ya no está', () {
      expect(tip(rareAxe), isNot(contains(protoPlain('(−1.5 vel.)'))));
    });
  });

  group('comparación', () {
    test('Ligera → Pesada: VEL y Peso con ▼ (empeoran)', () {
      final p = lootWarrior();
      final cmp = compareWeapons(progression, p, to: rareAxe);
      final by = {for (final s in cmp.stats) s.label: s};
      expect(by['Peso']!.before, 0);
      expect(by['Peso']!.after, 1.5);
      expect(by['Peso']!.better, isFalse);
      expect(by['Peso']!.diffText, '+1.5');
      expect(by['VEL']!.better, isFalse);
      expect(cmp.weightClassBefore, WeightClass.ligera);
      expect(cmp.weightClassAfter, WeightClass.pesada);
      expect(cmp.weightClassChanged, isTrue);
    });

    test('Pesada → Ligera: VEL y Peso con ▲ (mejoran)', () {
      final p = lootWarrior();
      final cmp = compareWeapons(progression, p,
          from: rareAxe, to: p.itemByUid('espada_bronce')!);
      final by = {for (final s in cmp.stats) s.label: s};
      expect(by['Peso']!.better, isTrue);
      expect(by['Peso']!.diffText, '-1.5');
      expect(by['VEL']!.better, isTrue);
    });

    testWidgets('la vista dice la categoría y el turno', (tester) async {
      final p = lootWarrior();
      final cmp = compareWeapons(progression, p, to: rareAxe);
      await pumpPanel(tester,
          profile: p,
          build: (v, c) => ComparisonDelta(
              rules: progression,
              cmp: cmp,
              level: p.level,
              attributes: p.attributes));
      final t = protoPlain(tester
          .widget<ProtoText>(find.byKey(const ValueKey('cmp-weight')))
          .markup);
      expect(t, contains('Peso: Ligera → Pesada'));
      expect(
          t,
          contains(protoPlain(
              turnIntervalLine(progression, cmp.before, cmp.after.speed))));
      expect(t, contains('% más lento'));
      // ▼ en VEL y en Peso.
      expect(find.textContaining('▼'), findsAtLeastNWidgets(2));
    });
  });

  group('filtro Peso', () {
    const rules = LootFilterRules();
    final ctx = FilterContext(level: 10, attributes: lootWarrior().attributes);
    LootDrop drop(String base) =>
        LootDrop.item(ItemInstance(uid: 'x', baseId: base, itemLevel: 10));

    test('Peso Media Pesada: coincide por categoría; ida y vuelta', () {
      final r = rules.parse('Mostrar\n  Peso media PESADA\n  Color 255 0 0');
      expect(r.errors, isEmpty);
      final c = r.filter.rules.single.conditions.single;
      expect(c, const WeightCondition([WeightClass.media, WeightClass.pesada]));
      expect(rules.matches(c, drop('hacha_rompe'), ctx), isTrue);
      expect(rules.matches(c, drop('tomo_plaga'), ctx), isTrue);
      expect(rules.matches(c, drop('espada_bronce'), ctx), isFalse);
      final text = rules.serialize(r.filter);
      expect(text, contains('Peso Media Pesada'));
      expect(rules.parse(text).filter, r.filter);
    });

    test('Peso Ligera; palabra mala = error de línea', () {
      final c = rules
          .parse('Mostrar\n  Peso Ligera')
          .filter
          .rules
          .single
          .conditions
          .single;
      expect(rules.matches(c, drop('espada_bronce'), ctx), isTrue);
      expect(rules.matches(c, drop('hacha_rompe'), ctx), isFalse);
      final bad = rules.parse('Mostrar\n  Peso liviana');
      expect(bad.errors.single, contains('Ligera, Media o Pesada'));
      // Materiales: no es un arma, no coincide.
      expect(
          rules.matches(c, const LootDrop.stack(StackKind.potion, 1), ctx),
          isFalse);
    });
  });
}
