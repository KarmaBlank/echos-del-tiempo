import 'package:material_ui/material_ui.dart';

import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/panel_widgets.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../app/theme/retro_text.dart';
import '../../../game_engine/data/items_catalog.dart';
import '../../../game_engine/models/attributes.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/models/player_state.dart';
import '../../../game_engine/models/upgrade_stat.dart';
import '../../../game_engine/models/weapon.dart';
import '../../../game_engine/rules/progression_rules.dart';
import '../../combat/domain/skill_text.dart';
import '../../world/presentation/session_controller.dart';
import '../../world/presentation/session_view.dart';
import '../domain/shop_guards.dart';
import '../domain/shop_preview.dart';
import '../domain/weapon_text.dart';

/// Lo que comparten las pestañas de tienda: el jugador local, las
/// reglas, los motivos de bloqueo del modo actual y las vistas previas.
class ShopContext {
  ShopContext(this.view, this.controller)
      : rules = controller.engine.progression,
        guards = ShopGuards(controller.engine.progression, view.mode),
        preview = ShopPreview(controller.engine.progression);

  final SessionView view;
  final SessionController controller;
  final ProgressionRules rules;
  final ShopGuards guards;
  final ShopPreview preview;

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

  String className() =>
      rules.catalog.classes[profile.classId]?.name ?? profile.classId;

  String weaponName(String id) => profile.inventory.contains(id)
      ? rules.weaponDisplayName(profile, id)
      : rules.catalog.weapons[id]?.name ?? id;
}

/// Pestañas de la tienda (armería del lobby y preparación). Ver
/// docs/specs/panels.md § "Armería".
enum ArmoryTab {
  buy('COMPRAR',
      'Armas de tu clase. Puedes comprarlas sin cumplir los requisitos; '
          'para equiparlas, sí.'),
  forge('FORJA',
      'Cada mejora sube 1 nivel una estadística del arma (máx '
          '${ProgressionRules.upgradeMax}). Las mejoras se quedan en el arma.'),
  fuse('FUSIÓN',
      'La base aprende 1 habilidad de otra arma, que se destruye. Una fusión '
          'nueva reemplaza a la anterior.'),
  items('CONSUMIBLES',
      'Se usan en batalla desde el menú. Máximo ${ProgressionRules.maxItems} '
          'de cada uno.');

  const ArmoryTab(this.label, this.hint);
  final String label;
  final String hint;

  Widget build(ShopContext shop) => switch (this) {
        ArmoryTab.buy => BuyTab(shop: shop),
        ArmoryTab.forge => ForgeTab(shop: shop),
        ArmoryTab.fuse => FuseTab(shop: shop),
        ArmoryTab.items => ItemsTab(shop: shop),
      };

  /// Como [PanelTabSpec] para un panel con pestañas.
  PanelTabSpec spec(ShopContext Function() shop) =>
      PanelTabSpec(label, hint, (_) => build(shop()));
}

/// Ayuda `[?]` de la tienda.
const kShopHelp = '<b>Tienda</b><br>'
    '<span class="k">COMPRAR</span>: armas de tu clase; compara con la '
    'equipada antes de pagar.<br>'
    '<span class="k">FORJA</span>: sube Poder, Crítico, Velocidad o Defensa '
    'de un arma (5 niveles c/u).<br>'
    '<span class="k">FUSIÓN</span>: un arma hereda una habilidad de otra, '
    'que se consume.<br>'
    'Elige en la lista de la izquierda; el botón de la acción está abajo a '
    'la derecha del detalle.';

// ---------------------------------------------------------------------
// Fichas comunes
// ---------------------------------------------------------------------

/// Ficha de un arma (cuerpo de las `.mrow` de armas del prototipo):
/// nombre, tipo, requisitos coloreados, escala, peso y habilidades. Con
/// [describe] cada habilidad va con su descripción completa.
class WeaponInfo extends StatelessWidget {
  const WeaponInfo({
    super.key,
    required this.shop,
    required this.weapon,
    this.attributes,
    this.showWeightNote = false,
    this.describe = false,
  });

  final ShopContext shop;
  final WeaponDef weapon;

  /// Atributos para colorear los requisitos (por defecto los del perfil).
  final PlayerAttributes? attributes;

  /// `(-vel.)` después del peso, como en la armería.
  final bool showWeightNote;

  /// Descripción de cada habilidad en vez de la lista corta.
  final bool describe;

  @override
  Widget build(BuildContext context) {
    final p = shop.profile;
    final w = weapon;
    final owned = p.inventory.contains(w.id);
    final cat = shop.rules.catalog;
    final fused = owned ? p.fused[w.id] : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProtoText('<b>${protoEsc(shop.weaponName(w.id))}</b> '
            '<span class="k">${w.type} · tier ${w.tier}</span>'),
        ProtoText(
          'Req: ${requirementsMarkup(w, attributes ?? p.attributes)}'
          ' · Escala: ${weaponScaleText(w)} · Peso ${fmtNum(w.weight)}'
          '${showWeightNote && w.weight > 0 ? ' (−vel.)' : ''}',
        ),
        if (!describe)
          ProtoText('<small>Habilidades: '
              '${skillListMarkup(cat, w, fusedId: fused)}</small>')
        else ...[
          const SizedBox(height: 8),
          const Text('HABILIDADES', style: TextStyle(color: ProtoColors.sky)),
          for (final id in [
            ...w.skillIds,
            if (fused != null && !w.skillIds.contains(fused)) fused,
          ])
            if (cat.skills[id] case final s?)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: ProtoText(describeSkillMarkup(s, null) +
                    (id == fused
                        ? ' ${protoColor(ProtoColors.orange, '(fusión)')}'
                        : '')),
              ),
          if (cat.ultimates[w.type] case final u?)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: ProtoText(describeSkillMarkup(u, null,
                  ultimate: true, nameColor: ProtoColors.hex(ProtoColors.pink))),
            ),
          if (w.shieldDefense > 0)
            ProtoText(protoColor(ProtoColors.ice, 'Escudo: DEF +${w.shieldDefense}')),
        ],
      ],
    );
  }
}

/// ATQ / MAG / VEL / CRÍT / DEF de [before] → [after].
class StatsCompare extends StatelessWidget {
  const StatsCompare(
      {super.key, required this.title, required this.before, required this.after});

  final String title;
  final DerivedStats before;
  final DerivedStats after;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProtoText(title, style: const TextStyle(color: ProtoColors.sky)),
          Wrap(
            spacing: 16,
            children: [
              StatChange('ATQ', before.attack, after.attack),
              StatChange('MAG', before.magic, after.magic),
              StatChange('VEL', before.speed, after.speed,
                  format: (x) => x.toStringAsFixed(1)),
              StatChange('CRÍT', before.critChance, after.critChance,
                  format: (x) => '${(x * 100).round()}%'),
              StatChange('DEF', before.defense, after.defense),
            ],
          ),
        ],
      ),
    );
  }
}

/// Encabezado de grupo dentro de una lista.
class _ListHeader extends StatelessWidget {
  const _ListHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 4),
        child: Text(retroText(text),
            style: const TextStyle(color: ProtoColors.gold)),
      );
}

// ---------------------------------------------------------------------
// COMPRAR
// ---------------------------------------------------------------------

/// Armas de su clase a la venta (`shop`, líneas 1352-1356): lista y
/// ficha con comparación contra la equipada.
class BuyTab extends StatefulWidget {
  const BuyTab({super.key, required this.shop});

  final ShopContext shop;

  @override
  State<BuyTab> createState() => _BuyTabState();
}

class _BuyTabState extends State<BuyTab> {
  String? _sel;

  @override
  Widget build(BuildContext context) {
    final shop = widget.shop;
    final p = shop.profile;
    final list = shop.forSale;
    if (list.isEmpty) return const Text('No hay armas a la venta.');
    final w = list.firstWhere((w) => w.id == _sel, orElse: () => list.first);
    final owned = p.inventory.contains(w.id);
    final eq = shop.rules.equippedWeapon(p);
    return PanelSplit(
      list: [
        for (final x in list)
          PanelListItem(
            key: ValueKey('shop-row-${x.id}'),
            selected: x.id == w.id,
            onTap: () => setState(() => _sel = x.id),
            trailing: p.inventory.contains(x.id)
                ? const Text('TIENES',
                    style: TextStyle(color: ProtoColors.green))
                : ProtoText('<b>₵${x.price}</b>'),
            child: ProtoText('${protoEsc(x.name)}<br>'
                '<small>${x.type} · tier ${x.tier}</small>'),
          ),
      ],
      detail: PanelDetail(
        footer: owned
            ? const [
                Text('TIENES', style: TextStyle(color: ProtoColors.green))
              ]
            : [
                CostLine(cost: w.price, credits: p.credits),
                PanelButton('COMPRAR \$${w.price}',
                    key: ValueKey('buy-${w.id}'),
                    accent: ProtoColors.green,
                    reason: shop.guards.buyWeapon(p, w.id),
                    onPressed: () => shop.controller.buyWeapon(w.id)),
              ],
        children: [
          WeaponInfo(shop: shop, weapon: w, showWeightNote: true, describe: true),
          if (w.id != eq.id)
            StatsCompare(
              title: 'Si la equipas (ahora: ${protoEsc(shop.weaponName(eq.id))})'
                  '${w.meetsRequirements(p.attributes) ? '' : ' · ${protoColor(ProtoColors.red, 'faltan requisitos')}'}',
              before: shop.preview.current(p),
              after: shop.preview.statsWith(p, w.id),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// CONSUMIBLES
// ---------------------------------------------------------------------

/// Consumibles (`itemsHtml`, línea 1267).
class ItemsTab extends StatelessWidget {
  const ItemsTab({super.key, required this.shop});

  final ShopContext shop;

  @override
  Widget build(BuildContext context) {
    final p = shop.profile;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final it in kItems.values)
            PanelRow(
              trailing: PanelButton('COMPRAR \$${it.price}',
                  key: ValueKey('item-${it.key}'),
                  reason: shop.guards.buyItem(p, it.item),
                  onPressed: () => shop.controller.buyItem(it.item)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProtoText('<b>${it.name}</b> '
                      '${protoColor(ProtoColors.green, 'tienes ${it.key == 'pot' ? p.potions : p.ethers}/${ProgressionRules.maxItems}')}'),
                  ProtoText('<small>${it.description}</small>'),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// FORJA
// ---------------------------------------------------------------------

/// `UPSTATS[k].fmt(l × per)`.
String upgradeValueText(UpgradeStat s, int level) {
  final v = level * s.perLevel;
  return switch (s) {
    UpgradeStat.pow || UpgradeStat.crit => '+${(v * 100).round()}%',
    UpgradeStat.spd => '+${v.toStringAsFixed(1)}',
    UpgradeStat.def => '+${v.round()}',
  };
}

/// Herrería (`upHtml`, líneas 1278-1285) + equipar (agregado del puerto):
/// lista de armas propias y, por estadística, valor y stats antes →
/// después de la mejora.
class ForgeTab extends StatefulWidget {
  const ForgeTab({super.key, required this.shop});

  final ShopContext shop;

  @override
  State<ForgeTab> createState() => _ForgeTabState();
}

class _ForgeTabState extends State<ForgeTab> {
  String? _sel;

  @override
  Widget build(BuildContext context) {
    final shop = widget.shop;
    final p = shop.profile;
    final list = shop.owned;
    if (list.isEmpty) return const Text('No tienes armas de tu clase.');
    final w = list.firstWhere((w) => w.id == _sel,
        orElse: () => list.firstWhere((w) => w.id == p.equipped,
            orElse: () => list.first));
    final equipped = p.equipped == w.id;
    return PanelSplit(
      list: [
        for (final x in list)
          PanelListItem(
            key: ValueKey('forge-row-${x.id}'),
            selected: x.id == w.id,
            onTap: () => setState(() => _sel = x.id),
            trailing: p.equipped == x.id
                ? const Text('EQUIPADA',
                    style: TextStyle(color: ProtoColors.gold))
                : null,
            child: ProtoText('${protoEsc(shop.weaponName(x.id))}<br>'
                '<small>${x.type} · mejoras ${p.upgradesFor(x.id).total}/'
                '${shop.rules.upgradeStatsFor(x).length * ProgressionRules.upgradeMax}</small>'),
          ),
      ],
      detail: PanelDetail(
        footer: [
          if (equipped)
            const Text('EQUIPADA', style: TextStyle(color: ProtoColors.gold))
          else
            PanelButton('EQUIPAR',
                key: ValueKey('equip-${w.id}'),
                reason: shop.guards.equip(p, w.id),
                onPressed: () => shop.controller.equip(w.id)),
        ],
        children: [
          ProtoText('<b>${protoEsc(shop.weaponName(w.id))}</b> '
              '<span class="k">${w.type}</span>'
              '${equipped ? '' : ' <small>(efecto si la equipas)</small>'}'),
          const SizedBox(height: 8),
          for (final s in shop.rules.upgradeStatsFor(w))
            _UpgradeRow(shop: shop, weapon: w, stat: s),
        ],
      ),
    );
  }
}

class _UpgradeRow extends StatelessWidget {
  const _UpgradeRow(
      {required this.shop, required this.weapon, required this.stat});

  final ShopContext shop;
  final WeaponDef weapon;
  final UpgradeStat stat;

  @override
  Widget build(BuildContext context) {
    final p = shop.profile;
    final l = p.upgradesFor(weapon.id).level(stat);
    const max = ProgressionRules.upgradeMax;
    final atMax = l >= max;
    final pv = shop.preview.upgrade(p, weapon.id, stat);
    final b = pv.before, a = atMax ? pv.before : pv.after;
    final effect = switch (stat) {
      UpgradeStat.pow => weapon.mag != null
          ? StatChange('MAG', b.magic, a.magic)
          : StatChange('ATQ', b.attack, a.attack),
      UpgradeStat.crit => StatChange('CRÍT', b.critChance, a.critChance,
          format: (x) => '${(x * 100).round()}%'),
      UpgradeStat.spd => StatChange('VEL', b.speed, a.speed,
          format: (x) => x.toStringAsFixed(1)),
      UpgradeStat.def => StatChange('DEF', b.defense, a.defense),
    };
    return PanelRow(
      key: ValueKey('forge-stat-${stat.key}'),
      trailing: atMax
          ? const Text('MAX', style: TextStyle(color: ProtoColors.green))
          : PanelButton(
              '+1 \$${shop.rules.upgradeCost(weapon.id, l)}',
              key: ValueKey('up-${weapon.id}-${stat.key}'),
              reason: shop.guards.upgrade(p, weapon.id, stat),
              onPressed: () => shop.controller.upgrade(weapon.id, stat),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 96,
                child: Text(retroText(stat.label),
                    style: const TextStyle(color: ProtoColors.sky)),
              ),
              LevelPips(l, max),
              const SizedBox(width: 8),
              Text('$l/$max'),
            ],
          ),
          Wrap(
            spacing: 16,
            children: [
              StatChange('Bono', l, atMax ? l : l + 1,
                  format: (x) => upgradeValueText(stat, x.toInt())),
              effect,
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// FUSIÓN
// ---------------------------------------------------------------------

/// Fusión (`fuseHtml`, líneas 1270-1277): base, sacrificio y habilidad en
/// tres pasos y la vista previa del resultado antes de confirmar.
class FuseTab extends StatefulWidget {
  const FuseTab({super.key, required this.shop});

  final ShopContext shop;

  @override
  State<FuseTab> createState() => _FuseTabState();
}

class _FuseTabState extends State<FuseTab> {
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
    final reason = g.fuse(p, _base, _sacrifice, _skill);
    final pv = shop.preview.fuse(p, _base, _sacrifice, _skill);

    Widget item(String prefix, String id, String? sel, String label,
            ValueChanged<String> pick) =>
        PanelListItem(
          key: ValueKey('$prefix-$id'),
          selected: id == sel,
          onTap: () => setState(() => pick(id)),
          child: Text(retroText(label)),
        );

    return PanelSplit(
      list: [
        const _ListHeader('1. Arma base (la que aprende)'),
        for (final id in bases)
          item('fuse-base', id, _base, shop.weaponName(id), (x) => _base = x),
        const _ListHeader('2. Arma a sacrificar (se destruye)'),
        if (others.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text('(no hay armas disponibles)',
                style: TextStyle(color: ProtoColors.dim)),
          ),
        for (final id in others)
          item('fuse-sac', id, _sacrifice, shop.weaponName(id),
              (x) => _sacrifice = x),
        if (skills.isNotEmpty) const _ListHeader('3. Habilidad a heredar'),
        for (final id in skills)
          item('fuse-skill', id, _skill, cat.skills[id]?.name ?? id,
              (x) => _skill = x),
      ],
      detail: PanelDetail(
        footer: [
          CostLine(cost: ProgressionRules.fuseCost, credits: p.credits),
          PanelButton('FUSIONAR',
              key: const ValueKey('fuse'),
              accent: ProtoColors.green,
              reason: reason,
              onPressed: () =>
                  shop.controller.fuse(_base!, _sacrifice!, _skill!)),
        ],
        children: pv == null
            ? [
                const Text('RESULTADO', style: TextStyle(color: ProtoColors.gold)),
                const SizedBox(height: 8),
                Text(retroText(
                    'Necesitas otra arma de tu clase para sacrificar: no puede '
                    'ser la inicial ni la equipada. Consigue armas en COMPRAR, '
                    'en cofres o al terminar misiones.')),
              ]
            : _preview(pv),
      ),
    );
  }

  List<Widget> _preview(FusePreview pv) {
    final shop = widget.shop;
    final cat = shop.rules.catalog;
    final base = cat.weapons[pv.baseId]!;
    final names = [
      for (final id in pv.skillIds)
        id == pv.skillId
            ? '<b style="color:#7bed9f">${cat.skills[id]?.name ?? id}</b>'
                '${protoColor(ProtoColors.green, ' (nueva)')}'
            : (cat.skills[id]?.name ?? id),
    ].join(' · ');
    final p = shop.profile;
    final nowFused = p.fused[pv.baseId];
    final now = [
      for (final id in [
        ...base.skillIds,
        if (nowFused != null && !base.skillIds.contains(nowFused)) nowFused,
      ])
        '${cat.skills[id]?.name ?? id}${id == nowFused ? ' (fusión)' : ''}',
    ].join(' · ');
    final lostUp = pv.lostUpgrades;
    final lost = [
      '<b style="color:#ff6b81">${protoEsc(shop.weaponName(pv.sacrificeId))}</b>',
      if (lostUp.total > 0)
        'sus mejoras (${UpgradeStat.values.where((s) => lostUp.level(s) > 0).map((s) => '${s.label} +${lostUp.level(s)}').join(', ')})',
      if (pv.lostFused != null)
        'su fusión (${cat.skills[pv.lostFused]?.name ?? pv.lostFused})',
    ].join(', ');
    return [
      const Text('RESULTADO', style: TextStyle(color: ProtoColors.gold)),
      const SizedBox(height: 4),
      ProtoText('<b>${protoEsc(shop.weaponName(pv.baseId))}</b> '
          '<span class="k">${base.type}</span>'),
      ProtoText(protoColor(ProtoColors.dim, 'Ahora: ${protoEsc(now)}')),
      ProtoText('Después: $names',
          key: const ValueKey('fuse-result-skills')),
      if (pv.replaces != null)
        ProtoText(
            protoColor(ProtoColors.orange,
                'Reemplaza ${cat.skills[pv.replaces]?.name ?? pv.replaces} '
                '(la fusión anterior se pierde)'),
            key: const ValueKey('fuse-replaces')),
      if (cat.skills[pv.skillId] case final s?) ...[
        const SizedBox(height: 8),
        const Text('HABILIDAD HEREDADA', style: TextStyle(color: ProtoColors.sky)),
        ProtoText(describeSkillMarkup(s, null)),
      ],
      const SizedBox(height: 8),
      ProtoText('Se pierde: ${protoColor(ProtoColors.red, lost)}',
          key: const ValueKey('fuse-lost')),
    ];
  }
}

// ---------------------------------------------------------------------
// Armas del personaje
// ---------------------------------------------------------------------

/// Armas propias con requisitos según el reparto pendiente, comparación
/// con la equipada y botón de equipar (pestaña "Armas" del personaje,
/// líneas 1325-1329).
class EquipTab extends StatefulWidget {
  const EquipTab({super.key, required this.shop, this.pending = const {}});

  final ShopContext shop;

  /// Reparto de puntos sin confirmar (`alloc`).
  final Map<Attribute, int> pending;

  @override
  State<EquipTab> createState() => _EquipTabState();
}

class _EquipTabState extends State<EquipTab> {
  String? _sel;

  @override
  Widget build(BuildContext context) {
    final shop = widget.shop;
    final p = shop.profile;
    final attrs = p.attributes.add(widget.pending);
    final list = shop.owned;
    if (list.isEmpty) return const Text('No tienes armas de tu clase.');
    final w = list.firstWhere((w) => w.id == _sel,
        orElse: () => list.firstWhere((w) => w.id == p.equipped,
            orElse: () => list.first));
    final eq = shop.rules.equippedWeapon(p);
    return PanelSplit(
      list: [
        for (final x in list)
          PanelListItem(
            key: ValueKey('weapon-row-${x.id}'),
            selected: x.id == w.id,
            onTap: () => setState(() => _sel = x.id),
            trailing: p.equipped == x.id
                ? const Text('EQUIPADA',
                    style: TextStyle(color: ProtoColors.gold))
                : x.meetsRequirements(attrs)
                    ? null
                    : const Text('Req', style: TextStyle(color: ProtoColors.red)),
            child: ProtoText('${protoEsc(shop.weaponName(x.id))}<br>'
                '<small>${x.type} · tier ${x.tier}</small>'),
          ),
        const SizedBox(height: 8),
        ProtoText('Pociones x${p.potions} · Éteres x${p.ethers} · '
            '<b>₵${p.credits}</b>'),
      ],
      detail: PanelDetail(
        footer: [
          if (p.equipped == w.id)
            const Text('Es tu arma equipada',
                style: TextStyle(color: ProtoColors.gold))
          else
            PanelButton('EQUIPAR',
                key: ValueKey('equip-${w.id}'),
                accent: ProtoColors.green,
                reason: shop.guards.equip(p, w.id, pending: widget.pending),
                onPressed: () => shop.controller.equip(w.id)),
        ],
        children: [
          WeaponInfo(shop: shop, weapon: w, attributes: attrs, describe: true),
          if (w.id != eq.id)
            StatsCompare(
              title: 'Comparada con ${protoEsc(shop.weaponName(eq.id))}',
              before: shop.preview.current(p, attributes: attrs),
              after: shop.preview.statsWith(p, w.id, attributes: attrs),
            ),
        ],
      ),
    );
  }
}
