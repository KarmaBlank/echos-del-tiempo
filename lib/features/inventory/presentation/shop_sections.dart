import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/panel_widgets.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../app/theme/retro_text.dart';
import '../../../game_engine/data/branch_ults_catalog.dart';
import '../../../game_engine/data/items_catalog.dart';
import '../../../game_engine/models/attributes.dart';
import '../../../game_engine/models/item.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/models/player_state.dart';
import '../../../game_engine/models/upgrade_stat.dart';
import '../../../game_engine/models/weapon.dart';
import '../../../game_engine/models/weapon_passive.dart';
import '../../../game_engine/rules/build_plan_rules.dart';
import '../../../game_engine/rules/craft_rules.dart';
import '../../../game_engine/rules/progression_rules.dart';
import '../../build_planner/presentation/build_fit_badge.dart';
import '../../build_planner/presentation/build_plan_providers.dart';
import '../../world/presentation/session_controller.dart';
import '../../world/presentation/session_view.dart';
import '../domain/item_text.dart';
import '../domain/shop_guards.dart';
import '../domain/shop_preview.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../app/widgets/action_card.dart';
import '../../../app/widgets/cost_chip.dart';
import '../../../app/widgets/menu_focus.dart';
import '../../../app/widgets/menu_widgets.dart';
import '../../../app/widgets/pixel_icon.dart';
import '../../../app/widgets/section_panel.dart';
import '../domain/battle_impact.dart';
import '../domain/skill_tip.dart';
import 'craft_bench.dart';
import 'skill_chip.dart';

/// Lo que comparten las pestañas de tienda e inventario: el jugador
/// local, las reglas, los motivos de bloqueo del modo actual y las
/// vistas previas.
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

  /// El perfil del miembro activo (el local o el compañero elegido en el
  /// selector; solo_party.md § 6).
  PlayerProfile get profile => view.actor!.profile;

  /// Bases a la venta (cualquier familia: loot v2), por nivel.
  List<WeaponDef> forSale([String? family]) => [
        for (final w in rules.catalog.weapons.values)
          if (w.price > 0 && (family == null || w.classId == family)) w,
      ]..sort((a, b) => a.level != b.level
          ? a.level.compareTo(b.level)
          : a.price.compareTo(b.price));

  /// Tus armas: la equipada primero y después en orden de obtención.
  List<ItemInstance> get owned {
    final p = profile;
    return [
      ...p.items.where((i) => i.uid == p.equippedUid),
      ...p.items.where((i) => i.uid != p.equippedUid),
    ];
  }

  String className() =>
      rules.catalog.classes[profile.classId]?.name ?? profile.classId;

  String itemName(ItemInstance it) => rules.items.displayName(it);
}

/// Pestañas de la tienda (armería del lobby y preparación). Ver
/// docs/specs/panels.md § "Armería" (loot v2).
enum ArmoryTab {
  buy('COMPRAR',
      'Armas base por nivel; cualquier clase las equipa si cumple los requisitos.'),
  forge(
      'FORJA', 'Sube una estadística del arma; cada 2 niveles sube su pasiva.'),
  fuse('FUSIÓN',
      'Elige arma, acción y confirma: ves el resultado antes de pagar.'),
  items('CONSUMIBLES',
      'Se usan en batalla. Máximo ${ProgressionRules.maxItems} de cada uno.');

  const ArmoryTab(this.label, this.hint);
  final String label;
  final String hint;

  Widget build(ShopContext shop) => switch (this) {
        ArmoryTab.buy => BuyTab(shop: shop),
        ArmoryTab.forge => ForgeTab(shop: shop),
        ArmoryTab.fuse => CraftBench(shop: shop),
        ArmoryTab.items => ItemsTab(shop: shop),
      };

  /// Como [PanelTabSpec] para un panel con pestañas.
  PanelTabSpec spec(ShopContext Function() shop) =>
      PanelTabSpec(label, hint, (_) => build(shop()));
}

/// Ayuda `[?]` de la tienda.
const kShopHelp = '<b>Armería</b><br>'
    '<span class="k">COMPRAR</span>: bases Comunes de cualquier clase; '
    'compara con la equipada antes de pagar.<br>'
    '<span class="k">FORJA</span>: sube Poder, Crítico, Velocidad o Defensa '
    '(5 c/u, tope total por rareza). Cada 2 niveles sube la pasiva.<br>'
    '<span class="k">FUSIÓN</span>: 1 ARMA → 2 ACCIÓN → 3 CONFIRMAR. '
    'Mejora con materiales, trae mods / pasiva / habilidades de otra arma '
    '(que se destruye), quita mods o reforja la base a otro tipo.<br>'
    'Para <b>desarmar</b> o <b>vender</b> lo que no te sirve: Personaje › '
    'Inventario.<br>'
    'Elige en la lista de la izquierda; el botón de la acción está abajo a '
    'la derecha del detalle.';

// ---------------------------------------------------------------------
// Fichas comunes
// ---------------------------------------------------------------------

/// Ficha de un arma (tooltip completo) y, con [describe], cada habilidad
/// con su descripción.
class ItemCard extends StatelessWidget {
  const ItemCard({
    super.key,
    required this.rules,
    required this.item,
    required this.level,
    required this.attributes,
    this.stats,
    this.equipped = false,
    this.describe = false,
  });

  final ProgressionRules rules;
  final ItemInstance item;
  final int level;
  final PlayerAttributes attributes;
  final DerivedStats? stats;
  final bool equipped;
  final bool describe;

  @override
  Widget build(BuildContext context) {
    final cat = rules.catalog;
    final w = cat.weapons[item.baseId];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProtoText(itemTooltipMarkup(rules, item,
            level: level,
            attributes: attributes,
            stats: stats,
            equipped: equipped,
            skills: false)),
        // Cada habilidad con su ficha (mouse o foco = tooltip, el mismo
        // texto que en batalla, con tus stats).
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: SkillChips(rules: rules, item: item, stats: stats),
        ),
        if (describe) ...[
          const SizedBox(height: 8),
          const Text('QUÉ HACEN', style: TextStyle(color: ProtoColors.sky)),
          for (final id in rules.items.skillsOf(item))
            if (cat.skills[id] case final s?)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: ProtoText(skillTipMarkup(s, stats: stats)),
              ),
          // ULT propia de la base (tomos del Invocador) o la del tipo.
          if (w != null &&
              (ownWeaponUlt(w.id, null) ?? cat.ultimates[w.type]) != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: ProtoText(skillTipMarkup(
                  (ownWeaponUlt(w.id, null) ?? cat.ultimates[w.type])!,
                  stats: stats,
                  ultimate: true)),
            ),
        ],
      ],
    );
  }
}

/// ATQ / MAG / VEL / CRÍT / DEF de [before] → [after].
class StatsCompare extends StatelessWidget {
  const StatsCompare(
      {super.key,
      required this.title,
      required this.before,
      required this.after});

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
              StatChange('HP', before.maxHp, after.maxHp),
            ],
          ),
        ],
      ),
    );
  }
}

/// Encabezado de grupo dentro de una lista.
class ListHeader extends StatelessWidget {
  const ListHeader(this.text, {super.key});
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

/// Bases Comunes a la venta (cualquier familia), por nivel, con filtro
/// de familia y comparación con la equipada.
class BuyTab extends ConsumerStatefulWidget {
  const BuyTab({super.key, required this.shop});

  final ShopContext shop;

  @override
  ConsumerState<BuyTab> createState() => _BuyTabState();
}

class _BuyTabState extends ConsumerState<BuyTab> {
  String? _sel;
  late String? _family = widget.shop.profile.classId;

  @override
  Widget build(BuildContext context) {
    final shop = widget.shop;
    final p = shop.profile;
    final rules = shop.rules;
    final list = shop.forSale(_family);
    final families = rules.catalog.classes.values.toList();
    final filter = ChoiceCycler<String?>(
      label: 'Familia',
      keyPrefix: 'buy-family-',
      options: [null, for (final c in families) c.id],
      value: _family,
      display: (id) => id == null
          ? 'TODAS'
          : (rules.catalog.classes[id]?.name ?? id).toUpperCase(),
      onChanged: (id) => setState(() => _family = id),
    );
    if (list.isEmpty) {
      return Column(children: [filter, const Text('No hay armas a la venta.')]);
    }
    final w = list.firstWhere((w) => w.id == _sel, orElse: () => list.first);
    final owned = p.items.any((i) => i.baseId == w.id);
    final sample = ItemInstance.common('_shop', w.id, itemLevel: w.level);
    final eq = shop.rules.equippedItem(p);
    // ★ Tu build (build_planner.md § 4.1): qué metas cumple cada base.
    final plan = ref
        .watch(buildPlanProvider)
        .planFor(shop.controller.slotOf(shop.view.actorId));
    final fitRules = ref.watch(buildPlanRulesProvider);
    ItemFit fitOf(String baseId) => plan.goalCount == 0
        ? ItemFit.none
        : fitRules.itemFit(plan, ItemInstance.common('_shop', baseId));
    final fit = fitOf(w.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        filter,
        const SizedBox(height: 8),
        Expanded(
          child: PanelSplit(
            listWidth: 420,
            list: [
              NavSection(
                child: InitialFocus(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final x in list)
                        MenuRow(
                          wrap: true,
                          key: ValueKey('shop-row-${x.id}'),
                          selected: x.id == w.id,
                          onTap: () => setState(() => _sel = x.id),
                          onFocus: () => setState(() => _sel = x.id),
                          label:
                              '${fitOf(x.id).any ? '<span style="color:$kPlanHex">★</span> ' : ''}'
                              '${protoEsc(x.name)} '
                              '${protoColor(ProtoColors.dim, protoEsc(x.type))} '
                              '${weightTagMarkup(x)}',
                          value: 'Nv ${x.level}  '
                              '${p.items.any((i) => i.baseId == x.id) ? protoColor(ProtoColors.green, 'TIENES') : '${rules.meetsRequirements(p, x) ? '' : '${protoColor(ProtoColors.red, 'Req')} '}<b>₵${x.price}</b>'}',
                        ),
                    ],
                  ),
                ),
              ),
            ],
            detail: PanelDetail(
              footer: [
                const KeyHints(confirm: 'Elegir', back: 'Cerrar'),
                if (owned)
                  const Text('YA LA TIENES',
                      style: TextStyle(color: ProtoColors.green))
                else
                  ConfirmButton('COMPRAR',
                      key: ValueKey('buy-${w.id}'),
                      reason: shop.guards.buyWeapon(p, w.id),
                      cost: CostChip([
                        CostPart(PixelIconKind.coin, '₵${w.price}',
                            ok: p.credits >= w.price),
                      ]),
                      onPressed: () => shop.controller.buyWeapon(w.id)),
              ],
              children: [
                // Encabezado: nombre, tipo y nivel, con la ★ de tu build.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ProtoText(
                          key: const ValueKey('shop-title'),
                          '<b style="color:#e8ecff">${protoEsc(w.name)}</b> '
                          '${protoColor(ProtoColors.dim, '${protoEsc(w.type)} · Nv ${w.level} · Común')} '
                          '${protoColor(ProtoColors.dim, '·')} ${weightTagMarkup(w)}'),
                    ),
                    BuildFitBadge(item: sample, compact: false),
                  ],
                ),
                if (fit.any)
                  ProtoText(buildFitMarkup(fit, lead: 'Sirve')!,
                      key: const ValueKey('shop-build-fit')),
                const SizedBox(height: 6),
                // Primero lo que cambia (antes → después), después el
                // costo y la ficha.
                SectionPanel(
                  icon: PixelIconKind.arrowIn,
                  title: 'SI LA EQUIPAS',
                  subtitle: rules.meetsRequirements(p, w)
                      ? null
                      : 'no cumples nivel o requisitos: puedes comprarla igual',
                  children: [
                    StatsCompare(
                      title: 'Si la equipas (ahora: '
                          '${protoEsc(eq == null ? '-' : shop.itemName(eq))})',
                      before: shop.preview.current(p),
                      after: shop.preview.withBase(p, w),
                    ),
                  ],
                ),
                SectionPanel(
                  icon: PixelIconKind.coin,
                  title: 'COSTO',
                  children: [
                    if (owned)
                      ProtoText(protoColor(ProtoColors.green,
                          'Ya tienes una. Mejórala en FORJA o FUSIÓN.'))
                    else
                      CostLine(cost: w.price, credits: p.credits),
                  ],
                ),
                SectionPanel(
                  icon: PixelIconKind.sword,
                  title: 'FICHA',
                  subtitle: 'habilidades y ULT del arma',
                  children: [
                    ItemCard(
                        rules: rules,
                        item: sample,
                        level: p.level,
                        attributes: p.attributes,
                        stats: shop.preview.withBase(p, w),
                        describe: true),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
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

/// Valor del bono de forja de [s] con [level] niveles.
String upgradeValueText(UpgradeStat s, int level) {
  final v = level * s.perLevel;
  return switch (s) {
    UpgradeStat.pow || UpgradeStat.crit => '+${(v * 100).round()}%',
    UpgradeStat.spd => '+${v.toStringAsFixed(1)}',
    UpgradeStat.def => '+${v.round()}',
  };
}

/// Cuándo sube la pasiva de [it] con la forja (texto en markup).
String passiveForgeNote(ItemInstance it) {
  if (it.passiveId == null || !it.rarity.hasPassive) {
    return protoColor(
        ProtoColors.dim, 'Sin pasiva (Épico y Legendario la traen)');
  }
  final l = it.effectivePassiveLevel;
  if (l >= ItemInstance.maxPassiveLevel) {
    return protoColor(ProtoColors.green, 'Pasiva al máximo (V)');
  }
  final left = it.rarity.forgeCap - it.forgeLevel;
  final need = 2 - it.forgeLevel % 2;
  if (need > left) {
    return protoColor(ProtoColors.dim,
        'La pasiva no sube más: tope de forja de ${it.rarity.label}');
  }
  final next = WeaponPassiveDef.roman(l + 1);
  return '<span style="color:$kPassiveHex">Sube a nivel $next '
      '${need == 1 ? 'en la próxima mejora' : 'en $need mejoras'}</span>';
}

/// Herrería sobre instancias: lista de tus armas y, por estadística,
/// valor y stats antes → después, con el tope de la rareza y la subida de
/// la pasiva cada 2 niveles.
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
    final rules = shop.rules;
    final list = shop.owned;
    if (list.isEmpty) return const Text('No tienes armas.');
    final it = list.firstWhere((i) => i.uid == _sel, orElse: () => list.first);
    final equipped = p.equippedUid == it.uid;
    final cap = it.rarity.forgeCap;
    final passive = rules.items.passiveText(it);
    return PanelSplit(
      list: [
        NavSection(
          child: InitialFocus(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final x in list)
                  MenuRow(
                    wrap: true,
                    key: ValueKey('forge-row-${x.uid}'),
                    selected: x.uid == it.uid,
                    onTap: () => setState(() => _sel = x.uid),
                    onFocus: () => setState(() => _sel = x.uid),
                    label: itemNameMarkup(rules, x),
                    value: p.equippedUid == x.uid
                        ? protoColor(ProtoColors.gold, 'EQUIPADA')
                        : protoColor(ProtoColors.dim,
                            'forja ${x.forgeLevel}/${x.rarity.forgeCap}'),
                  ),
              ],
            ),
          ),
        ),
      ],
      detail: PanelDetail(
        footer: [
          const KeyHints(confirm: 'Forjar', back: 'Cerrar'),
          if (equipped)
            const Text('EQUIPADA', style: TextStyle(color: ProtoColors.gold))
          else
            PanelButton('EQUIPAR',
                key: ValueKey('equip-${it.uid}'),
                reason: shop.guards.equip(p, it.uid),
                onPressed: () => shop.controller.equip(it.uid)),
        ],
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ProtoText('${itemNameMarkup(rules, it)} '
                    '<span class="k">${it.rarity.label}</span>'
                    '${equipped ? '' : ' <small>(efecto si la equipas)</small>'}'),
              ),
              BuildFitBadge(item: it),
            ],
          ),
          SkillChips(
              rules: rules, item: it, stats: shop.preview.withItem(p, it)),
          const SizedBox(height: 4),
          SectionPanel(
            icon: PixelIconKind.anvil,
            title: 'FORJA',
            subtitle: 'cada mejora sube 1 nivel una estadística (máx 5)',
            children: [
              Row(
                key: const ValueKey('forge-cap'),
                children: [
                  Text(retroText('Forja ${it.forgeLevel}/$cap  ')),
                  LevelPips(it.forgeLevel.clamp(0, cap), cap),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(retroText('(tope de ${it.rarity.label})'),
                        style: const TextStyle(color: ProtoColors.dim)),
                  ),
                ],
              ),
              if (passive != null)
                ProtoText('Pasiva: <span style="color:$kPassiveHex">'
                    '${protoEsc(passive)}</span>'),
              ProtoText(passiveForgeNote(it),
                  key: const ValueKey('forge-passive-note')),
              const SizedBox(height: 6),
              CardGrid(
                minWidth: 220,
                children: [
                  for (final s in rules
                      .upgradeStatsFor(rules.catalog.weapons[it.baseId]!))
                    _UpgradeCard(shop: shop, item: it, stat: s),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Qué hace cada estadística de forja (una línea).
const _forgeWhat = {
  UpgradeStat.pow: 'Más ATQ (o MAG) con esta arma.',
  UpgradeStat.crit: 'Más probabilidad de golpe crítico.',
  UpgradeStat.spd: 'Más velocidad: turnos más seguidos.',
  UpgradeStat.def: 'Más defensa: menos daño recibido.',
};

const _forgeIcon = {
  UpgradeStat.pow: PixelIconKind.sword,
  UpgradeStat.crit: PixelIconKind.star,
  UpgradeStat.spd: PixelIconKind.arrowIn,
  UpgradeStat.def: PixelIconKind.anchor,
};

/// Una estadística de forja como tarjeta: nivel en cuadritos, bono y
/// efecto antes → después, si sube la pasiva, y el costo (o el motivo
/// completo). Clic / `Enter` = +1.
class _UpgradeCard extends StatelessWidget {
  const _UpgradeCard(
      {required this.shop, required this.item, required this.stat});

  final ShopContext shop;
  final ItemInstance item;
  final UpgradeStat stat;

  @override
  Widget build(BuildContext context) {
    final p = shop.profile;
    final rules = shop.rules;
    final w = rules.catalog.weapons[item.baseId]!;
    final l = item.forge.level(stat);
    const max = WeaponUpgradeLevels.upMax;
    final atMax = l >= max;
    final r = rules.crafting.forge(p, item.uid, stat);
    final after = r.after ?? item;
    final b = shop.preview.withItem(p, item);
    final a = shop.preview.withItem(p, after);
    final effect = switch (stat) {
      UpgradeStat.pow => w.mag != null
          ? StatChange('MAG', b.magic, a.magic)
          : StatChange('ATQ', b.attack, a.attack),
      UpgradeStat.crit => StatChange('CRÍT', b.critChance, a.critChance,
          format: (x) => '${(x * 100).round()}%'),
      UpgradeStat.spd => StatChange('VEL', b.speed, a.speed,
          format: (x) => x.toStringAsFixed(1)),
      UpgradeStat.def => StatChange('DEF', b.defense, a.defense),
    };
    final passiveUp = r.after != null &&
        r.after!.effectivePassiveLevel > item.effectivePassiveLevel &&
        item.rarity.hasPassive &&
        item.passiveId != null;
    final def = rules.items.passiveOf(item);
    final cost = CraftRules.forgeCost(w, item.rarity, l);
    final reason = atMax ? null : shop.guards.upgrade(p, item.uid, stat);
    return KeyedSubtree(
      key: ValueKey('forge-stat-${stat.key}'),
      child: ActionCard(
        key: ValueKey('up-${item.uid}-${stat.key}'),
        icon: PixelIcon(_forgeIcon[stat]!,
            size: RetroType.width(context, 20),
            color: atMax ? ProtoColors.green : ProtoColors.gold),
        title: '<b>${protoEsc(stat.label)}</b>',
        description: _forgeWhat[stat],
        disabled: atMax,
        reason: reason,
        onTap: () {
          if (!atMax && reason == null) {
            shop.controller.upgrade(item.uid, stat);
          }
        },
        footer: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                LevelPips(l, max),
                const SizedBox(width: 8),
                Text('$l/$max'),
              ],
            ),
            StatChange('Bono', l, atMax ? l : l + 1,
                format: (x) => upgradeValueText(stat, x.toInt())),
            effect,
            if (passiveUp && def != null)
              ProtoText(
                key: ValueKey('forge-passive-up-${stat.key}'),
                '<b style="color:$kPassiveHex">¡La pasiva sube!</b> '
                '<span style="color:$kPassiveHex">${protoEsc(def.name)} '
                '${WeaponPassiveDef.roman(item.effectivePassiveLevel)} → '
                '${WeaponPassiveDef.roman(r.after!.effectivePassiveLevel)}: '
                '${protoEsc(def.descriptionAt(r.after!.effectivePassiveLevel))}</span>',
              ),
            // Qué cambia en batalla, con tus números (battle_impact.dart).
            if (!atMax)
              if (battleImpactMarkup(rules, b, a, weapon: after)
                  case final impact?)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: ProtoText(impact,
                      key: ValueKey('forge-impact-${stat.key}')),
                ),
            const SizedBox(height: 4),
            if (atMax)
              const CostChip.note('MAX')
            else if (reason != null)
              CostChip.blocked(reason)
            else
              CostChip([
                CostPart(PixelIconKind.coin, '+1 · ₵$cost',
                    ok: p.credits >= cost),
              ]),
          ],
        ),
      ),
    );
  }
}
