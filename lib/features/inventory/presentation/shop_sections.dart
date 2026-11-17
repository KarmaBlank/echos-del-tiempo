import 'package:material_ui/material_ui.dart';

import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../app/theme/retro_text.dart';
import '../../../game_engine/data/items_catalog.dart';
import '../../../game_engine/models/attributes.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/models/upgrade_stat.dart';
import '../../../game_engine/models/weapon.dart';
import '../../../game_engine/rules/progression_rules.dart';
import '../../world/presentation/session_controller.dart';
import '../../world/presentation/session_view.dart';
import '../domain/shop_guards.dart';
import '../domain/weapon_text.dart';

/// Lo que comparten las secciones de tienda: el jugador local, las
/// reglas y los motivos de bloqueo del modo actual.
class ShopContext {
  ShopContext(this.view, this.controller)
      : rules = controller.engine.progression,
        guards = ShopGuards(controller.engine.progression, view.mode);

  final SessionView view;
  final SessionController controller;
  final ProgressionRules rules;
  final ShopGuards guards;

  PlayerProfile get profile => view.me!.profile;

  /// Armas de su clase a la venta, en el orden del catálogo.
  List<WeaponDef> get forSale => [
        for (final w in rules.catalog.weapons.values)
          if (w.classId == profile.classId && w.price > 0) w,
      ];

  /// Armas propias de su clase, en orden de obtención.
  List<WeaponDef> get owned => [
        for (final id in profile.inventory)
          if (rules.catalog.weapons[id] case final w?
              when w.classId == profile.classId)
            w,
      ];
}

/// Nombre, tipo, requisitos coloreados, escala, peso y habilidades de
/// un arma (el cuerpo de cada `.mrow` de armas del prototipo).
class WeaponInfo extends StatelessWidget {
  const WeaponInfo({
    super.key,
    required this.shop,
    required this.weapon,
    this.attributes,
    this.showWeightNote = false,
  });

  final ShopContext shop;
  final WeaponDef weapon;

  /// Atributos para colorear los requisitos (por defecto los del perfil).
  final PlayerAttributes? attributes;

  /// `(-vel.)` después del peso, como en la armería.
  final bool showWeightNote;

  @override
  Widget build(BuildContext context) {
    final p = shop.profile;
    final w = weapon;
    final owned = p.inventory.contains(w.id);
    final name = owned ? shop.rules.weaponDisplayName(p, w.id) : w.name;
    // `.mrow` de armas: nombre, `tipo ⓘ` en `#9fb4ff` y dos `<small>`.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProtoText('${protoEsc(name)} <span class="k">${w.type}</span>'),
        ProtoText(
          '<small>Req: ${requirementsMarkup(w, attributes ?? p.attributes)}'
          ' · Escala: ${weaponScaleText(w)} · Peso ${fmtNum(w.weight)}'
          '${showWeightNote ? ' (−vel.)' : ''}</small>',
        ),
        ProtoText(
          '<small>Habilidades: '
          '${skillListMarkup(shop.rules.catalog, w, fusedId: owned ? p.fused[w.id] : null)}'
          '</small>',
        ),
      ],
    );
  }
}

/// Armas de su clase a la venta (`shop`, líneas 1352-1356).
class WeaponShopSection extends StatelessWidget {
  const WeaponShopSection({super.key, required this.shop, this.title});

  final ShopContext shop;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final p = shop.profile;
    final cls = shop.rules.catalog.classes[p.classId]?.name ?? p.classId;
    return PanelSection(
      title ?? 'Armería ($cls)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final w in shop.forSale)
            PanelRow(
              tooltip: weaponTooltip(shop.rules, p, w),
              trailing: p.inventory.contains(w.id)
                  ? const Text('TIENES',
                      style: TextStyle(color: ProtoColors.green))
                  : PanelButton('\$${w.price}',
                      key: ValueKey('buy-${w.id}'),
                      reason: shop.guards.buyWeapon(p, w.id),
                      onPressed: () => shop.controller.buyWeapon(w.id)),
              child: WeaponInfo(shop: shop, weapon: w, showWeightNote: true),
            ),
        ],
      ),
    );
  }
}

/// Consumibles (`itemsHtml`, línea 1267).
class ItemShopSection extends StatelessWidget {
  const ItemShopSection({super.key, required this.shop});

  final ShopContext shop;

  @override
  Widget build(BuildContext context) {
    final p = shop.profile;
    return PanelSection(
      'Consumibles (máx. ${ProgressionRules.maxItems} de cada uno)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final it in kItems.values)
            PanelRow(
              trailing: PanelButton('\$${it.price}',
                  key: ValueKey('item-${it.key}'),
                  reason: shop.guards.buyItem(p, it.item),
                  onPressed: () => shop.controller.buyItem(it.item)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProtoText('${it.name} '
                      '${protoColor(ProtoColors.gold, 'tienes ${it.key == 'pot' ? p.potions : p.ethers}')}'),
                  ProtoText('<small>${it.description}</small>'),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// `UPSTATS[k].fmt(l × per)`.
String upgradeValueText(UpgradeStat s, int level) {
  final v = level * s.perLevel;
  return switch (s) {
    UpgradeStat.pow || UpgradeStat.crit => '+${(v * 100).round()}%',
    UpgradeStat.spd => '+${v.toStringAsFixed(1)}',
    UpgradeStat.def => '+${v.round()}',
  };
}

/// Herrería (`upHtml`, líneas 1278-1285) + equipar (agregado del puerto).
class ForgeSection extends StatelessWidget {
  const ForgeSection({super.key, required this.shop});

  final ShopContext shop;

  @override
  Widget build(BuildContext context) {
    final p = shop.profile;
    return PanelSection(
      'Herrería: elige qué estadística mejorar en cada arma (máx nivel '
      '${ProgressionRules.upgradeMax} por estadística)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final w in shop.owned)
            PanelRow(
              tooltip: weaponTooltip(shop.rules, p, w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: Text(retroText(
                              shop.rules.weaponDisplayName(p, w.id)))),
                      if (p.equipped == w.id)
                        const Text('EQUIPADA',
                            style: TextStyle(color: ProtoColors.gold))
                      else
                        PanelButton('EQUIPAR',
                            key: ValueKey('equip-${w.id}'),
                            reason: shop.guards.equip(p, w.id),
                            onPressed: () => shop.controller.equip(w.id)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      for (final s in shop.rules.upgradeStatsFor(w))
                        _UpgradeCell(shop: shop, weapon: w, stat: s),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _UpgradeCell extends StatelessWidget {
  const _UpgradeCell(
      {required this.shop, required this.weapon, required this.stat});

  final ShopContext shop;
  final WeaponDef weapon;
  final UpgradeStat stat;

  @override
  Widget build(BuildContext context) {
    final p = shop.profile;
    final l = p.upgradesFor(weapon.id).level(stat);
    const max = ProgressionRules.upgradeMax;
    final reason = shop.guards.upgrade(p, weapon.id, stat);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // `<div style="font-size:7px;color:#9fb4ff">` del prototipo.
        ProtoText(
            '${stat.label} ${protoColor(ProtoColors.green, upgradeValueText(stat, l))}'
            ' ($l/$max)',
            style: const TextStyle(color: ProtoColors.sky)),
        const SizedBox(height: 4),
        if (l >= max)
          const Text('MAX', style: TextStyle(color: ProtoColors.green))
        else
          PanelButton(
            '+1 \$${shop.rules.upgradeCost(weapon.id, l)}',
            key: ValueKey('up-${weapon.id}-${stat.key}'),
            reason: reason,
            onPressed: () => shop.controller.upgrade(weapon.id, stat),
          ),
      ],
    );
  }
}

/// Fusión (`fuseHtml`, líneas 1270-1277): una fila de botones por lista
/// en vez de los `<select>` del prototipo.
class FuseSection extends StatefulWidget {
  const FuseSection({super.key, required this.shop});

  final ShopContext shop;

  @override
  State<FuseSection> createState() => _FuseSectionState();
}

class _FuseSectionState extends State<FuseSection> {
  String? _base, _sacrifice, _skill;

  @override
  Widget build(BuildContext context) {
    final shop = widget.shop;
    final p = shop.profile;
    final cat = shop.rules.catalog;
    final g = shop.guards;
    final bases = g.fuseBases(p);
    // Mismos valores por defecto que el prototipo.
    if (!bases.contains(_base)) _base = p.equipped;
    final others = g.fuseSacrifices(p, _base);
    if (!others.contains(_sacrifice)) {
      _sacrifice = others.isEmpty ? null : others.first;
    }
    final skills = _sacrifice == null
        ? const <String>[]
        : cat.weapons[_sacrifice]!.skillIds;
    if (!skills.contains(_skill)) _skill = skills.isEmpty ? null : skills.first;
    final replaces = _base == null ? null : p.fused[_base];
    final reason = g.fuse(p, _base, _sacrifice, _skill);

    Widget choices(String label, List<String> ids, String? sel,
            String Function(String) name, ValueChanged<String> pick,
            {required String prefix, String? empty}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(width: 160, child: Text(retroText(label))),
              if (ids.isEmpty && empty != null)
                Text(empty, style: const TextStyle(color: ProtoColors.dim)),
              for (final id in ids)
                PanelButton(name(id),
                    key: ValueKey('$prefix-$id'),
                    selected: id == sel,
                    accent: id == sel ? ProtoColors.gold : null,
                    onPressed: () => setState(() => pick(id))),
            ],
          ),
        );

    return PanelSection(
      'Fusión (\$${ProgressionRules.fuseCost}): un arma hereda una habilidad '
      'de otra; la segunda se consume',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          choices('Base:', bases, _base,
              (id) => shop.rules.weaponDisplayName(p, id), (id) => _base = id,
              prefix: 'fuse-base'),
          choices('< Sacrificar:', others, _sacrifice,
              (id) => shop.rules.weaponDisplayName(p, id),
              (id) => _sacrifice = id,
              prefix: 'fuse-sac',
              empty: '(no hay armas disponibles)'),
          choices('Habilidad a heredar:', skills, _skill,
              (id) => cat.skills[id]?.name ?? id, (id) => _skill = id,
              prefix: 'fuse-skill'),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PanelButton('FUSIONAR',
                  key: const ValueKey('fuse'),
                  reason: reason,
                  onPressed: () =>
                      shop.controller.fuse(_base!, _sacrifice!, _skill!)),
              if (replaces != null)
                Text(
                    retroText(
                        '(reemplaza ${cat.skills[replaces]?.name ?? replaces})'),
                    style: const TextStyle(color: ProtoColors.orange)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'No se puede sacrificar el arma inicial ni la equipada. Cada arma '
            'guarda 1 habilidad fusionada.',
            textAlign: TextAlign.center,
            style: TextStyle(color: ProtoColors.dim),
          ),
        ],
      ),
    );
  }
}

/// Armas propias con requisitos según el reparto pendiente y botón de
/// equipar (sección "Armas" del panel de personaje, líneas 1325-1329).
class OwnedWeaponsSection extends StatelessWidget {
  const OwnedWeaponsSection(
      {super.key, required this.shop, this.pending = const {}});

  final ShopContext shop;

  /// Reparto de puntos sin confirmar (`alloc`).
  final Map<Attribute, int> pending;

  @override
  Widget build(BuildContext context) {
    final p = shop.profile;
    final c = shop.rules.catalog.classes[p.classId];
    final preview = p.attributes.add(pending);
    return PanelSection(
      'Armas (${c?.allowedWeaponTypes.join(' / ') ?? ''})',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final w in shop.owned)
            PanelRow(
              tooltip: weaponTooltip(shop.rules, p, w),
              trailing: p.equipped == w.id
                  ? const Text('EQUIPADA',
                      style: TextStyle(color: ProtoColors.gold))
                  : PanelButton('EQUIPAR',
                      key: ValueKey('equip-${w.id}'),
                      reason: shop.guards.equip(p, w.id, pending: pending),
                      onPressed: () => shop.controller.equip(w.id)),
              child: WeaponInfo(shop: shop, weapon: w, attributes: preview),
            ),
        ],
      ),
    );
  }
}
