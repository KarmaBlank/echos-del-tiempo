import 'package:echos_del_tiempo/app/theme/proto_markup.dart';
import 'package:echos_del_tiempo/features/inventory/domain/item_text.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/item_widgets.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/loot.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import 'loot_fixtures.dart';

void main() {
  final p = lootWarrior();

  test('colores de rareza = los del filtro', () {
    expect(rarityHex(Rarity.comun), '#dcdcdc');
    expect(rarityHex(Rarity.magico), '#7896ff');
    expect(rarityHex(Rarity.raro), '#ffd23c');
    expect(rarityHex(Rarity.epico), '#be6eff');
    expect(rarityHex(Rarity.legendario), '#ff8c28');
    expect(RarityColors.of(Rarity.epico), const Color(0xFFBE6EFF));
  });

  test('ficha de un épico: nombre, rareza, requisitos, mods, pasiva, forja',
      () {
    final it = p.itemByUid('e1')!;
    final m = itemTooltipMarkup(progression, it,
        level: p.level,
        attributes: p.attributes,
        stats: progression.previewEquip(p, 'e1'));
    // Nombre en el color de la rareza.
    expect(m, contains('<b style="color:#be6eff">Filo del Alba +1</b>'));
    final t = protoPlain(m);
    expect(t, contains(protoPlain('Épico · espada · nivel de objeto 10')));
    expect(t, contains(protoPlain('Espada Ígnea')));
    // Requisitos: Nv 2 y FUE 14 cumplidos (verde), DES 8 cumplido.
    expect(m, contains('<span style="color:#7bed9f">Nv 2</span>'));
    expect(m, contains('<span style="color:#7bed9f">FUE 14</span>'));
    expect(t, contains('ATQ '));
    expect(t, contains('Mods 4/6'));
    expect(t, contains('+7% ATQ (T5)'));
    // Ímpetu nivel I + 1 de forja = I (sube cada 2).
    expect(t, contains(protoPlain('Ímpetu I:')));
    // Nivel de objeto 10: tope min(8, 2 + 10/5) = 4 (combo_balance.md § 2).
    expect(t, contains('Forja +1/4 (Poder 1)'));
    expect(t, contains('ULT:'));
  });

  test('requisitos que faltan en rojo y habilidad trasladada', () {
    final staff = p.itemByUid('c1')!.copyWith(extraSkills: const ['sismo']);
    final m = itemTooltipMarkup(progression, staff,
        level: 1, attributes: p.attributes);
    expect(m, contains('<span style="color:#ff6b81">Nv 2</span>'));
    expect(m, contains('<span style="color:#ff6b81">ESP 14</span>'));
    expect(protoPlain(m), contains('(trasladada)'));
    expect(missingRequirements(
            progression.catalog.weapons['baculo_fuego']!, p.attributes),
        'ESP 14');
  });

  test('legendario: mods fijos (único), pasiva única y texto', () {
    final t = protoPlain(itemTooltipMarkup(progression, p.itemByUid('l1')!,
        level: p.level, attributes: p.attributes));
    expect(t, contains('Fauce del Volcán'));
    expect(t, contains('(único)'));
    expect(t, contains('Erupción Interna I'));
    expect(t, contains('Todavía está caliente'));
  });

  test('pilas: material con su descripción', () {
    final t = protoPlain(stackTooltipMarkup(StackKind.cristal, 3));
    expect(t, contains('Cristal de Era x3'));
    expect(t, contains('Material de fusión'));
  });
}
