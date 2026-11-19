import 'package:echos_del_tiempo/features/inventory/domain/filter_quick.dart';
import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/build_wants.dart';
import 'package:echos_del_tiempo/game_engine/models/eco.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/loot.dart';
import 'package:echos_del_tiempo/game_engine/models/loot_filter.dart';
import 'package:echos_del_tiempo/game_engine/rules/loot_filter_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// Casillas del filtro (docs/specs/loot.md § 13.1).

const _fr = LootFilterRules();
final _opts = quickOptions();

FilterDoc _doc(String t) => FilterDoc.parse(t, _opts);

FilterContext _ctx({BuildWants? wants}) => FilterContext(
      level: 10,
      attributes: PlayerAttributes.base(kClasses['guerrero']!.baseAttributes),
      classId: 'guerrero',
      wants: wants,
    );

LootDrop _w(String base, Rarity r, {int il = 10}) => LootDrop.item(
    ItemInstance(uid: 'x', baseId: base, rarity: r, itemLevel: il));

bool _visible(String text, LootDrop d, {BuildWants? wants}) {
  final p = _fr.parse(text);
  expect(p.errors, isEmpty, reason: text);
  return _fr.evaluate(p.filter, d, _ctx(wants: wants)).visible;
}

/// Las líneas de [a] que no están en [b] (para ver que solo se agregó).
List<String> _minus(String a, String b) {
  final rest = b.split('\n');
  return [
    for (final l in a.split('\n'))
      if (!rest.remove(l)) l
  ];
}

const _player = '''
# mi filtro
Mostrar # Raros
  Rareza Raro
  Color 255 210 60
Ocultar
  Rareza Común
  Tipo hacha
''';

void main() {
  test('todas las casillas generan una regla válida y se reconocen', () {
    expect(_opts.map((o) => o.id).toSet().length, _opts.length);
    expect(_opts.first.id, 'build', reason: 'la excepción ★ va primero');
    expect(_opts.where((o) => o.group == QuickGroup.tipo).length,
        greaterThanOrEqualTo(9));
    for (final o in _opts) {
      final p = _fr.parse(o.rule);
      expect(p.errors, isEmpty, reason: o.id);
      expect(p.filter.rules, hasLength(1), reason: o.id);
      expect(p.filter.rules.single.name, startsWith('rápido: '));
      expect(_doc(o.rule).checked, {o.id});
    }
  });

  test('el por defecto: 8 reglas, ninguna casilla, resúmenes', () {
    final d = _doc(LootFilterRules.defaultText);
    expect(d.blocks, hasLength(8));
    expect(d.checked, isEmpty);
    expect(FilterDoc.summary(d.blocks.first), 'Ecos');
    expect(FilterDoc.conditionsText(d.blocks.last),
        'Rareza Mágico · NivelRelativo <= -10');
    expect(d.blocks.every((b) => b.enabled && b.errors.isEmpty), isTrue);
  });

  test('marcar agrega la regla arriba sin tocar el resto; desmarcar la saca',
      () {
    final on = _doc(_player).setQuick('rareza-comun', true);
    expect(_minus(on, _player), [
      'Ocultar # rápido: armas comunes',
      '  Objeto Arma',
      '  Rareza Común',
    ]);
    expect(_minus(_player, on), isEmpty, reason: 'no borra nada');
    // Después del comentario de arriba y antes de la primera regla.
    expect(on, startsWith('# mi filtro\nOcultar # rápido: armas comunes\n'));
    expect(_doc(on).checked, {'rareza-comun'});
    expect(_doc(on).setQuick('rareza-comun', false), _player);
    // Ida y vuelta con varias.
    var t = _player;
    for (final id in ['peso-pesada', 'tipo-espada', 'mat-prisma']) {
      t = _doc(t).setQuick(id, true);
    }
    expect(_doc(t).checked, {'peso-pesada', 'tipo-espada', 'mat-prisma'});
    for (final id in ['tipo-espada', 'mat-prisma', 'peso-pesada']) {
      t = _doc(t).setQuick(id, false);
    }
    expect(t, _player);
  });

  test('orden: excepción ★, después los rápidos, después las del jugador', () {
    var t = _doc(_player).setQuick('rareza-comun', true);
    t = _doc(t).setQuick('build', true);
    final names = [for (final b in _doc(t).blocks) b.rule?.name];
    expect(names, [
      'rápido: lo de mi build',
      'rápido: armas comunes',
      'Raros',
      null,
    ]);
    const wants = BuildWants(weaponTypes: ['espada']);
    final common = _w('espada_bronce', Rarity.comun);
    expect(_visible(t, common, wants: wants), isTrue,
        reason: 'la ★ le gana al Ocultar rápido');
    expect(_visible(t, common), isFalse, reason: 'sin plan, se oculta');
    expect(_visible(t, _w('arco_corto', Rarity.comun), wants: wants), isFalse);
  });

  test('las casillas por tipo no ocultan Épicos; las de rareza no tocan Ecos',
      () {
    final t = _doc('').setQuick('tipo-espada', true);
    expect(_visible(t, _w('espada_bronce', Rarity.raro)), isFalse);
    expect(_visible(t, _w('espada_bronce', Rarity.epico)), isTrue);
    expect(_visible(t, _w('arco_corto', Rarity.comun)), isTrue);
    final commons = _doc('').setQuick('rareza-comun', true);
    expect(_visible(commons, _w('arco_corto', Rarity.comun)), isFalse);
    expect(
        _visible(commons,
            const LootDrop.eco(EcoItem(uid: 'e', tier: 2, zone: 1, boss: 1))),
        isTrue);
    final low = _doc('').setQuick('nivel-bajo', true);
    expect(_visible(low, _w('espada_bronce', Rarity.comun, il: 4)), isFalse);
    expect(_visible(low, _w('espada_bronce', Rarity.comun, il: 5)), isTrue);
    final mats = _doc('').setQuick('mat-fragmentos', true);
    expect(
        _visible(mats, const LootDrop.stack(StackKind.fragReloj, 1)), isFalse);
    expect(_visible(mats, const LootDrop.stack(StackKind.prisma, 1)), isTrue);
    final pots = _doc('').setQuick('pociones', true);
    expect(_visible(pots, const LootDrop.stack(StackKind.ether, 1)), isFalse);
  });

  test('una regla rápida editada a mano queda desmarcada e intacta', () {
    final edited = _doc(_player)
        .setQuick('rareza-comun', true)
        .replaceFirst('  Rareza Común', '  Rareza Común\n  Mods < 2');
    final d = _doc(edited);
    expect(d.checked, isEmpty);
    final t = d.setQuick('rareza-magico', true);
    expect(_minus(edited, t), isEmpty, reason: 'la editada sigue');
    expect(_doc(t).checked, {'rareza-magico'});
    expect(_doc(t).blocks.map((b) => b.rule?.name).take(2),
        ['rápido: armas mágicas', 'rápido: armas comunes']);
  });

  test('apagar comenta la regla con #OFF y deja de aplicar; prender vuelve',
      () {
    final d = _doc(_player);
    final off = d.setEnabled(1, false);
    expect(off,
        contains('#OFF Ocultar\n#OFF   Rareza Común\n#OFF   Tipo hacha\n'));
    final od = _doc(off);
    expect(od.blocks, hasLength(2), reason: 'sigue en la lista');
    expect(od.blocks[1].enabled, isFalse);
    expect(FilterDoc.summary(od.blocks[1]), 'Rareza Común · Tipo hacha');
    expect(_fr.parse(off).filter.rules, hasLength(1));
    final axe = _w('hacha_rompe', Rarity.comun);
    expect(_visible(_player, axe), isFalse);
    expect(_visible(off, axe), isTrue);
    expect(od.setEnabled(1, true), _player);
    // Una rápida apagada desmarca la casilla y no se pierde al marcar otra.
    final q = _doc(_doc(_player).setQuick('rareza-comun', true));
    final qOff = _doc(q.setEnabled(0, false));
    expect(qOff.checked, isEmpty);
    final both = qOff.setQuick('rareza-raro', true);
    expect(both, contains('#OFF Ocultar # rápido: armas comunes'));
    // Volver a marcarla la prende (sin duplicarla).
    final again = _doc(both).setQuick('rareza-comun', true);
    expect(again, isNot(contains('#OFF')));
    expect('rápido: armas comunes'.allMatches(again), hasLength(1));
  });

  test('✕ borra solo esa regla', () {
    final d = _doc(LootFilterRules.defaultText);
    final t = d.remove(2);
    final nd = _doc(t);
    expect(nd.blocks, hasLength(7));
    expect(nd.blocks.map((b) => b.rule?.name), isNot(contains('Tu build')));
    expect(_minus(LootFilterRules.defaultText, t).first, 'Mostrar # Tu build');
    expect(
        _doc(_player).remove(1),
        '# mi filtro\nMostrar # Raros\n'
        '  Rareza Raro\n  Color 255 210 60\n');
  });

  test('Material con mayúsculas (fragReloj): ida y vuelta', () {
    const f = LootFilter([
      FilterRule(show: false, conditions: [
        MaterialCondition([CraftMaterial.fragReloj])
      ]),
    ]);
    final text = _fr.serialize(f);
    final p = _fr.parse(text);
    expect(p.errors, isEmpty);
    expect(p.filter, f);
  });
}
