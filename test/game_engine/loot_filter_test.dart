import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/loot.dart';
import 'package:echos_del_tiempo/game_engine/models/loot_filter.dart';
import 'package:echos_del_tiempo/game_engine/rules/loot_filter_rules.dart';
import 'package:flutter_test/flutter_test.dart';

const _rules = LootFilterRules();

final _ctx = FilterContext(
  level: 10,
  attributes: PlayerAttributes.base(kClasses['guerrero']!.baseAttributes),
  classId: 'guerrero',
);

LootDrop _w(String base,
        {Rarity r = Rarity.comun,
        int il = 10,
        List<AffixRoll> a = const [],
        String? passive}) =>
    LootDrop.item(ItemInstance(
        uid: 'x',
        baseId: base,
        rarity: r,
        itemLevel: il,
        affixes: a,
        passiveId: passive));

void main() {
  test('English keywords read the same as the Spanish ones', () {
    final en = _rules.parse('''
Show
  Rarity >= Rare
  Class guerrero
  Weight Light Heavy
  Item Weapon Echo
  Passive Yes
  Build Base Skill
  Color 255 210 60
  Sound alerta
Hide
  Rarity Common
  ItemLevel < 10
''');
    final es = _rules.parse('''
Mostrar
  Rareza >= Raro
  Clase guerrero
  Peso Ligera Pesada
  Objeto Arma Eco
  Pasiva Si
  Build Base Habilidad
  Color 255 210 60
  Sonido alerta
Ocultar
  Rareza Comun
  NivelObjeto < 10
''');
    expect(en.errors, isEmpty);
    expect(_rules.serialize(en.filter), _rules.serialize(es.filter));
  });

  test('el ejemplo del spec se lee', () {
    final r = _rules.parse('''
Mostrar
  Rareza >= Rara
  Clase Guerrero
  Color 255 210 60
  Sonido alerta
Ocultar
  Rareza Normal
  NivelObjeto < 10
''');
    expect(r.errors, isEmpty);
    expect(r.filter.rules, hasLength(2));
    final a = r.filter.rules[0];
    expect(a.show, isTrue);
    expect(a.conditions.first, const RarityCondition(FilterOp.ge, Rarity.raro));
    expect(a.conditions[1], const FamilyCondition(['guerrero']));
    expect(a.style.textColor, const FilterColor(255, 210, 60));
    expect(a.style.sound, 'alerta');
    expect(r.filter.rules[1].show, isFalse);
  });

  test('ida y vuelta: parse(serialize(f)) == f; texto canónico estable', () {
    final f = _rules.parse(LootFilterRules.defaultText).filter;
    final text = _rules.serialize(f);
    final again = _rules.parse(text);
    expect(again.errors, isEmpty);
    expect(again.filter, f);
    expect(_rules.serialize(again.filter), text);
    // Todas las condiciones y acciones.
    const all = '''
Mostrar # todo
  Rareza != Común
  Tipo espada báculo
  Base espada_ignea arco_corto
  Clase maga
  NivelObjeto >= 5
  NivelRelativo <= -3
  Mods > 2
  TieneMod feroz <= 2
  TieneMod del_oso
  Pasiva No
  Material esquirla prisma
  Objeto Arma Material
  Utilizable
  Color 1 2 3
  Borde 4 5 6 7
  Fondo 8 9 10
  Tamaño 40
  Sonido gema
  Icono estrella rojo
''';
    final p = _rules.parse(all);
    expect(p.errors, isEmpty);
    expect(p.filter.rules.single.conditions, hasLength(13));
    expect(_rules.parse(_rules.serialize(p.filter)).filter, p.filter);
    expect(_rules.serialize(p.filter), contains('Mostrar # todo'));
  });

  test('errores por línea y el resto se conserva', () {
    final r = _rules.parse('''
Rareza Raro
Mostrar
  Rareza Rarísima
  TieneMod nada
  Color 300 0 0
  Sonido trompeta
  Icono hexagono
  Base no_existe
  Volar alto
  Tamaño 200
  Rareza Épico
''');
    expect(r.errors, hasLength(8));
    expect(r.errors.first, startsWith('línea 1:'));
    final rule = r.filter.rules.single;
    expect(rule.conditions.single, const RarityCondition(FilterOp.eq, Rarity.epico));
    expect(rule.style.size, FilterStyle.maxSize, reason: 'se recorta al rango');
  });

  group('evaluar', () {
    final f = _rules.parse('''
Ocultar
  Rareza Común
  NivelRelativo <= -6
Mostrar # buenos
  TieneMod feroz <= 2
  Color 0 255 0
Mostrar
  Objeto Material
  Material prisma
  Sonido material
Ocultar
  Utilizable No
''').filter;

    test('gana la primera que coincide; sin regla, estilo de la rareza', () {
      final low = _rules.evaluate(f, _w('espada_bronce', il: 2), _ctx);
      expect(low.visible, isFalse);
      expect(low.ruleIndex, 0);
      final good = _rules.evaluate(
          f,
          _w('espada_ignea', r: Rarity.raro, a: [const AffixRoll('feroz', 2, 28)]),
          _ctx);
      expect(good.visible, isTrue);
      expect(good.ruleIndex, 1);
      expect(good.style.textColor, const FilterColor(0, 255, 0));
      expect(good.style.size, FilterStyle.defaultSize,
          reason: 'lo que la regla no dice sale del estilo por defecto');
      final t3 = _rules.evaluate(
          f, _w('espada_bronce', r: Rarity.magico, a: [const AffixRoll('feroz', 3, 20)]), _ctx);
      expect(t3.ruleIndex, isNull);
      expect(t3.visible, isTrue);
      expect(t3.style.textColor, LootFilterRules.rarityColor(Rarity.magico));
    });

    test('materiales y "Utilizable"', () {
      final prism = _rules.evaluate(f, const LootDrop.stack(StackKind.prisma, 1), _ctx);
      expect(prism.ruleIndex, 2);
      expect(prism.style.sound, 'material');
      final shard = _rules.evaluate(f, const LootDrop.stack(StackKind.esquirla, 1), _ctx);
      expect(shard.ruleIndex, isNull);
      // Tomo del Tiempo pide ESP 22: un guerrero base no puede.
      final tome = _rules.evaluate(f, _w('tomo_tiempo', r: Rarity.magico), _ctx);
      expect(tome.visible, isFalse);
      expect(tome.ruleIndex, 3);
    });

    test('filtro por defecto', () {
      final d = LootFilterRules.defaultFilter;
      expect(_rules.evaluate(d, _w('espada_bronce', il: 1), _ctx).visible, isFalse);
      expect(_rules.evaluate(d, _w('espada_bronce', il: 10), _ctx).visible, isTrue);
      final leg = _rules.evaluate(d, _w('espada_templada', r: Rarity.legendario), _ctx);
      expect(leg.style.sound, 'legendario');
      expect(leg.style.icon, const MapIcon(MapIconShape.estrella, MapIconColor.naranja));
      expect(_rules.evaluate(d, const LootDrop.stack(StackKind.cristal, 1), _ctx)
          .style.icon?.shape, MapIconShape.triangulo);
      expect(_rules.fromProfileText(null), d);
    });
  });
}
