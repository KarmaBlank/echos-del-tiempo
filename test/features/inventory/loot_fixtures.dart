import 'package:echos_del_tiempo/app/design/design.dart';
import 'package:echos_del_tiempo/app/theme/panel_frame.dart';
import 'package:echos_del_tiempo/app/widgets/action_card.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/shop_sections.dart' show ForgeUpgradeRow;
import 'package:echos_del_tiempo/features/inventory/presentation/inventory_action_menu.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/weapon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';

/// Épico con pasiva (Ímpetu) y 1 nivel de forja.
const epicSword = ItemInstance(
  uid: 'e1',
  baseId: 'espada_ignea',
  rarity: Rarity.epico,
  itemLevel: 10,
  name: 'Filo del Alba',
  passiveId: 'impetu',
  forge: WeaponUpgradeLevels(pow: 1),
  affixes: [
    AffixRoll('feroz', 5, 7),
    AffixRoll('certero', 5, 3),
    AffixRoll('del_oso', 5, 3),
    AffixRoll('de_la_vida', 5, 10),
  ],
);

/// Raro con 2 mods (lugar para más).
const rareAxe = ItemInstance(
  uid: 'r1',
  baseId: 'hacha_rompe',
  rarity: Rarity.raro,
  itemLevel: 10,
  name: 'Eco Voraz',
  affixes: [AffixRoll('feroz', 5, 6), AffixRoll('del_toro', 5, 3)],
);

/// Mágico con un prefijo y un sufijo.
const magicKatana = ItemInstance(
  uid: 'm1',
  baseId: 'katana_escarcha',
  rarity: Rarity.magico,
  itemLevel: 5,
  affixes: [AffixRoll('afilado', 5, 2), AffixRoll('del_zorro', 5, 3)],
);

/// Común de otra familia (maga): Nv 2, ESP 14.
const commonStaff =
    ItemInstance(uid: 'c1', baseId: 'baculo_fuego', itemLevel: 2);

/// Legendario con mods fijos y pasiva única.
const legendAxe = ItemInstance(
  uid: 'l1',
  baseId: 'hacha_volcanica',
  rarity: Rarity.legendario,
  itemLevel: 6,
  uniqueId: 'fauceVolcan',
  passiveId: 'erupcionInterna',
  affixes: [
    AffixRoll('afilado', 0, 5),
    AffixRoll('abrasador', 0, 1),
    AffixRoll('del_oso', 5, 3),
  ],
);

/// Guerrero Lv5 (FUE 16, DES 10, ESP [esp]; ESP 14 pide Lv7) con un arma de cada rareza, la
/// Espada de Bronce equipada, créditos y materiales.
PlayerProfile lootWarrior({
  int credits = 5000,
  Map<CraftMaterial, int> materials = const {
    CraftMaterial.esquirla: 2,
    CraftMaterial.cristal: 1,
  },
  int esp = 4,
  int level = 5,
  List<ItemInstance>? extra,
}) =>
    progression.normalize(PlayerProfile(
      name: 'Ana',
      classId: 'guerrero',
      level: level,
      credits: credits,
      // Suma válida (progresión v2: Lv5 = 4 puntos, 2 en FUE y DES, 2 libres);
      // cada +3 de ESP sobre 4 sale de los libres.
      points: 2 + (level - 5) - (esp - 4) ~/ 3,
      attributes: PlayerAttributes({
        Attribute.vit: 10,
        Attribute.esp: esp,
        Attribute.agi: 6,
        Attribute.fue: 15,
        Attribute.des: 9,
      }),
      items: [
        const ItemInstance(uid: 'espada_bronce', baseId: 'espada_bronce'),
        epicSword,
        rareAxe,
        magicKatana,
        commonStaff,
        legendAxe,
        ...?extra,
      ],
      equipped: 'espada_bronce',
      materials: materials,
    ));

/// Un botón o una tarjeta de acción y su motivo de bloqueo (`null` = se
/// puede): `PanelButton`, `DsButton`, `ConfirmButton` o `ActionCard`.
class ActionRef {
  const ActionRef(this.reason);
  final String? reason;
}

ActionRef button(WidgetTester tester, String key) =>
    switch (tester.widget(find.byKey(ValueKey(key)))) {
      PanelButton b => ActionRef(b.reason),
      // Del sistema de diseño: deshabilitado, el motivo va en el tooltip.
      DsButton b => ActionRef(b.onPressed == null ? b.tooltip : null),
      ConfirmButton b => ActionRef(b.reason),
      ActionCard c => ActionRef(c.reason),
      DsActionRow r => ActionRef(r.reason),
      ForgeUpgradeRow r => ActionRef(r.reason),
      InventoryActionRow r => ActionRef(r.entry.reason),
      final w => throw StateError('$key no es un botón: ${w.runtimeType}'),
    };

/// Texto plano de los `Text` / `ProtoText` debajo de [key]. La moneda
/// (`DsGold`, un `WidgetSpan`) se lee como `$`.
String plain(WidgetTester tester, String key) => tester
    .widgetList<Text>(find.descendant(
        of: find.byKey(ValueKey(key)), matching: find.byType(Text)))
    .map((t) => t.textSpan?.toPlainText() ?? t.data ?? '')
    .join(' ')
    .replaceAll('￼', '\$');

/// Abre "MÁS DETALLE" de la mejora elegida en FORJA.
Future<void> openForgeMore(WidgetTester tester) async {
  final f = find.descendant(
      of: find.byKey(const ValueKey('forge-more')),
      matching: find.byType(DsButton));
  await tester.ensureVisible(f);
  await tester.tap(f);
  await tester.pump();
}
