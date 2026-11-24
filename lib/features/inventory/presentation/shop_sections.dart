import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import '../domain/item_names.dart';

import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/panel_widgets.dart';
import '../../../app/design/design.dart';
import '../../../app/design/ds_layout_host.dart';
import '../../../core/i18n/i18n_providers.dart';
import '../../../core/layout/layout_doc.dart';
import '../../../app/theme/proto_colors.dart';

import '../../../app/theme/proto_markup.dart';
import '../../../app/theme/retro_text.dart';
import '../../../game_engine/rules/build_guide_rules.dart';
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
import '../../../game_engine/rules/resident_rules.dart';
import '../../../game_engine/rules/item_rules.dart';
import '../../../game_engine/rules/progression_rules.dart';
import '../../build_planner/presentation/build_fit_badge.dart';
import '../../build_planner/presentation/build_plan_providers.dart';
import '../../world/presentation/session_controller.dart';
import '../../world/presentation/session_view.dart';
import '../domain/inventory_menu.dart' show foldSearch, inventoryMatches;
import '../domain/item_text.dart';
import '../domain/shop_guards.dart';
import '../domain/shop_preview.dart';
import '../../../app/widgets/action_card.dart';
import '../../../app/widgets/action_row_icon.dart';
import '../../../app/widgets/cost_chip.dart';
import '../../../app/widgets/menu_focus.dart';
import '../../../app/widgets/menu_widgets.dart';
import '../../../app/widgets/pixel_icon.dart';
import '../../../app/widgets/section_panel.dart';
import '../domain/battle_impact.dart';
import '../domain/skill_tip.dart';
import 'armory_shop.dart';
import 'condense_panel.dart';
import 'craft_bench.dart';
import 'craft_layout.dart';
import 'item_grid.dart';
import 'inventory_strings.dart';
import 'item_hover_tip.dart';
import 'item_widgets.dart' show CellContent, RarityColors;
import 'skill_chip.dart';

/// Lo que comparten las pestañas de tienda e inventario: el jugador
/// local, las reglas, los motivos de bloqueo del modo actual y las
/// vistas previas.
class ShopContext {
  ShopContext(this.view, this.controller)
      : rules = controller.engine.progression,
        guards = ShopGuards(controller.engine.progression, view.mode,
            forgeDiscount: view.actor == null
                ? 0
                : ResidentRules.forgeDiscount(
                    view.actor!.profile, view.session.town)),
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
  /// En la Travesía, solo los tipos de arma de su clase (roguelike.md § 5).
  List<WeaponDef> forSale([String? family]) => [
        for (final w in rules.catalog.weapons.values)
          if (w.price > 0 &&
              (family == null || w.classId == family) &&
              (view.session.run == null ||
                  (rules.catalog.classes[profile.classId]?.allowedWeaponTypes
                          .contains(w.type) ??
                      true)))
            w,
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

  String itemName(ItemInstance it) => localItemName(rules.items, it);
}

/// Una pestaña de la ARMERÍA o la FORJA (rótulo, línea "qué hace" y su
/// contenido).
abstract interface class ShopTabDef {
  String label(Strings s);
  String hint(Strings s);
  Widget build(ShopContext shop);
}

ProviderContainer? _fallbackContainer;

/// Strings for callers without a [BuildContext] (tab specs built ahead of
/// time); widgets use `invStrings(context)` / `ref.strings`.
Strings shopFallbackStrings() =>
    (_fallbackContainer ??= ProviderContainer()).read(stringsProvider);

/// Pestañas de la ARMERÍA (v0.32.3: solo comprar y vender; panels.md §
/// "Armería"). CONSUMIBLES sigue acá hasta que tenga su lugar.
enum ArmoryTab implements ShopTabDef {
  buy,
  sell,
  items;

  @override
  String label(Strings s) => s.t('ui.inventory.shop.tab.$name.label');
  @override
  String hint(Strings s) => s.t('ui.inventory.shop.tab.$name.hint',
      {'max': ProgressionRules.maxItems});

  @override
  Widget build(ShopContext shop) => switch (this) {
        ArmoryTab.buy => ArmoryBuyGrid(shop: shop),
        ArmoryTab.sell => ArmorySellGrid(shop: shop),
        ArmoryTab.items => ItemsTab(shop: shop),
      };

  /// Como [PanelTabSpec] para un panel con pestañas.
  PanelTabSpec spec(ShopContext Function() shop, [Strings? strings]) {
    final s = strings ?? shopFallbackStrings();
    return PanelTabSpec(label(s), hint(s), (_) => build(shop()));
  }
}

/// Pestañas de la FORJA (v0.32.3; panels.md § "Forja"): MEJORAR,
/// CONDENSAR (materiales de arma) y FUSIÓN.
enum ForgeHallTab implements ShopTabDef {
  upgrade,
  condense,
  fuse;

  @override
  String label(Strings s) => s.t('ui.inventory.shop.forge_tab.$name.label');
  @override
  String hint(Strings s) => s.t('ui.inventory.shop.forge_tab.$name.hint');

  @override
  Widget build(ShopContext shop) => switch (this) {
        ForgeHallTab.upgrade => ForgeTab(shop: shop),
        ForgeHallTab.condense => CondensePanel(shop: shop),
        ForgeHallTab.fuse => CraftBench(shop: shop),
      };

  PanelTabSpec spec(ShopContext Function() shop, [Strings? strings]) {
    final s = strings ?? shopFallbackStrings();
    return PanelTabSpec(label(s), hint(s), (_) => build(shop()));
  }
}

/// Ayuda `[?]` de la ARMERÍA.
String shopHelp(Strings s) => s.t('ui.inventory.shop.help');

/// Ayuda `[?]` de la FORJA.
String forgeHelp(Strings s) =>
    s.t('ui.inventory.shop.forge_help', {'arrow': '→'});

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
          Text(invStrings(context).t('ui.inventory.shop.what_they_do'),
              style: const TextStyle(color: ProtoColors.sky)),
          for (final id in rules.items.skillsOf(item))
            if (cat.skills[id] case final s?)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: ProtoText(skillTipMarkup(s, stats: stats)),
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
    final s = invStrings(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProtoText(title, style: const TextStyle(color: ProtoColors.sky)),
          Wrap(
            spacing: 16,
            children: [
              StatChange(s.t('ui.inventory.craft.stat.atk'), before.attack,
                  after.attack),
              StatChange(s.t('ui.inventory.craft.stat.mag'), before.magic,
                  after.magic),
              StatChange(s.t('ui.inventory.craft.stat.spd'), before.speed,
                  after.speed,
                  format: (x) => x.toStringAsFixed(1)),
              StatChange(s.t('ui.inventory.craft.stat.crit'), before.critChance,
                  after.critChance,
                  format: (x) => '${(x * 100).round()}%'),
              StatChange(s.t('ui.inventory.craft.stat.def'), before.defense,
                  after.defense),
              StatChange('HP', before.maxHp, after.maxHp),
            ],
          ),
        ],
      ),
    );
  }
}

/// Filas de stats del personaje [now] → [next] (HP, MP, VEL con el peso
/// del arma, ATQ, MAG, DEF, CRÍT): la misma lista en ATRIBUTOS › VISTA
/// PREVIA y en INVENTARIO › ESTADÍSTICAS (v0.9.9). Cada fila muestra
/// la diferencia en verde si sube y en rojo si baja.
class CharacterStatRows extends StatelessWidget {
  const CharacterStatRows(
      {super.key,
      required this.now,
      required this.next,
      required this.weight,
      double? nextWeight})
      : nextWeight = nextWeight ?? weight;

  final DerivedStats now;
  final DerivedStats next;

  /// Peso del arma equipada y del arma con la que se compara.
  final double weight;
  final double nextWeight;

  @override
  Widget build(BuildContext context) {
    String pct(num x) => '${(x * 100).round()}%';
    String dec(num x) => x.toStringAsFixed(1);
    final w = weight.toStringAsFixed(1);
    final w2 = nextWeight.toStringAsFixed(1);
    final s = invStrings(context);
    // `DsStatLine` (design_system.md § 6): una línea por stat, sufijo en
    // Detalle; la fórmula de VEL va al tooltip.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DsStatLine('HP', now.maxHp, next.maxHp, key: const ValueKey('stat-HP')),
        DsStatLine('MP', now.maxMp, next.maxMp, key: const ValueKey('stat-MP')),
        Tooltip(
          key: const ValueKey('stat-weight'),
          message: retroText(s.t('ui.inventory.shop.stats.speed_formula',
              {'times': '×', 'minus': '−'})),
          child: DsStatLine(s.t('ui.inventory.craft.stat.spd'), now.speed,
              next.speed,
              key: const ValueKey('stat-VEL'),
              format: dec,
              suffix: s.t('ui.inventory.shop.stats.weight',
                  {'weight': w == w2 ? w : '$w → $w2'})),
        ),
        DsStatLine(s.t('ui.inventory.craft.stat.atk'), now.attack, next.attack,
            key: const ValueKey('stat-ATQ')),
        DsStatLine(s.t('ui.inventory.craft.stat.mag'), now.magic, next.magic,
            key: const ValueKey('stat-MAG')),
        DsStatLine(s.t('ui.inventory.craft.stat.def'), now.defense,
            next.defense,
            key: const ValueKey('stat-DEF'),
            suffix: s.t('ui.inventory.shop.stats.def_suffix',
                {'pct': (next.defensePercent * 100).round()})),
        DsStatLine(s.t('ui.inventory.craft.stat.crit'), now.critChance,
            next.critChance,
            key: const ValueKey('stat-CRIT'),
            format: pct,
            suffix: s.t('ui.inventory.shop.stats.crit_suffix', {
              'mult': '×${next.critMultiplier == 2 ? '2' : '1.5'}'
            })),
      ],
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

  /// Buscador de la lista (plantilla de listas de armas, ui_minimal.md
  /// § 3): nombre o tipo de la base.
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  bool _hit(WeaponDef w) {
    final words =
        foldSearch(_q.text).split(RegExp(r'\s+')).where((x) => x.isNotEmpty);
    final text = foldSearch('${w.text} ${w.name} ${w.type}');
    return words.every(text.contains);
  }

  @override
  Widget build(BuildContext context) {
    final shop = widget.shop;
    final p = shop.profile;
    final rules = shop.rules;
    final all = shop.forSale(_family);
    final list = [
      for (final x in all)
        if (x.id == _sel || _hit(x)) x
    ];
    final families = rules.catalog.classes.values.toList();
    final s = ref.strings;
    final filter = ChoiceCycler<String?>(
      label: s.t('ui.inventory.craft.family'),
      keyPrefix: 'buy-family-',
      options: [null, for (final c in families) c.id],
      value: _family,
      display: (id) => id == null
          ? s.t('ui.inventory.craft.all')
          : (rules.catalog.classes[id]?.name ?? id).toUpperCase(),
      onChanged: (id) => setState(() => _family = id),
    );
    final eqNow = shop.rules.equippedItem(p);
    // Cabecera de la plantilla: buscador siempre y la equipada fija.
    final head = [
      DsSearchField(
        key: const ValueKey('buy-search'),
        hint: s.t('ui.inventory.shop.buy.search_hint'),
        width: 320,
        controller: _q,
        onChanged: (_) => setState(() {}),
      ),
      SizedBox(height: DsSpace.xs),
      if (eqNow != null)
        PinnedEquippedRow(
            key: const ValueKey('buy-pinned'),
            cell: itemHoverTip(
                rules: rules,
                viewer: p,
                item: eqNow,
                attributes: p.attributes,
                equipped: true,
                child: ItemSlot(
                    rules: rules,
                    data: ItemSlotData(content: CellContent.item(eqNow)))),
            note: eqNow.name),
    ];
    if (all.isEmpty) {
      return Column(
          children: [filter, Text(s.t('ui.inventory.shop.buy.none_for_sale'))]);
    }
    if (list.isEmpty) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        filter,
        ...head,
        Text(s.t('ui.inventory.craft.no_match_weapon'), style: DsText.detail()),
      ]);
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
    // » Recomendadas para tu build (build_planner.md § 9.3).
    final picks = {
      for (final x in BuildGuideRules(rules).rankBases(plan, p, list))
        if (x.recommended) x.base.id: x,
    };
    final pick = picks[w.id];
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
                      ...head,
                      for (final x in list)
                        MenuRow(
                          wrap: true,
                          key: ValueKey('shop-row-${x.id}'),
                          selected: x.id == w.id,
                          onTap: () => setState(() => _sel = x.id),
                          onFocus: () => setState(() => _sel = x.id),
                          label:
                              '${fitOf(x.id).any ? '<span style="color:$kPlanHex">★</span> ' : ''}'
                              '${picks.containsKey(x.id) ? '<span style="color:$kPlanHex">»</span> ' : ''}'
                              '${protoEsc(x.name)} '
                              '${protoColor(ProtoColors.dim, protoEsc(x.type))} '
                              '${weightTagMarkup(x)}',
                          value:
                              '${rules.ignoreRequirements ? '' : '${s.t('ui.inventory.craft.level_short', {'n': x.level})}  '}'
                              '${p.items.any((i) => i.baseId == x.id) ? protoColor(ProtoColors.green, s.t('ui.inventory.shop.buy.owned_tag')) : '${rules.meetsRequirements(p, x) ? '' : '${protoColor(ProtoColors.red, s.t('ui.inventory.shop.buy.req_tag'))} '}<b>₵${x.price}</b>'}',
                        ),
                    ],
                  ),
                ),
              ),
            ],
            detail: PanelDetail(
              footer: [
                KeyHints(
                    confirm: s.t('ui.inventory.shop.keys.choose'),
                    back: s.t('ui.inventory.shop.keys.close')),
                if (owned)
                  Text(s.t('ui.inventory.shop.buy.already_have'),
                      style: const TextStyle(color: ProtoColors.green))
                else
                  ConfirmButton(s.t('ui.inventory.shop.tab.buy.label'),
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
                          '<b style="color:#e8ecff">${protoEsc(w.text)}</b> '
                          '${protoColor(ProtoColors.dim, '${protoEsc(w.type)} · ${s.t('ui.inventory.craft.level_short', {'n': w.level})} · ${s.t('ui.inventory.shop.buy.common')}')} '
                          '${protoColor(ProtoColors.dim, '·')} ${weightTagMarkup(w)}'),
                    ),
                    BuildFitBadge(item: sample, compact: false),
                  ],
                ),
                if (fit.any)
                  ProtoText(
                      buildFitMarkup(fit,
                          lead: s.t('ui.inventory.shop.buy.fit_lead'))!,
                      key: const ValueKey('shop-build-fit')),
                if (pick != null)
                  ProtoText(
                      key: const ValueKey('shop-build-pick'),
                      protoColor(
                          kPlanColor,
                          s.t('ui.inventory.shop.buy.recommended', {
                            'why': protoEsc(pick.reasons.join(' · '))
                          }))),
                const SizedBox(height: 6),
                // Primero lo que cambia (antes → después), después el
                // costo y la ficha.
                SectionPanel(
                  icon: PixelIconKind.arrowIn,
                  title: s.t('ui.inventory.shop.buy.if_equipped_title'),
                  subtitle: rules.meetsRequirements(p, w)
                      ? null
                      : s.t('ui.inventory.shop.buy.unmet_requirements'),
                  children: [
                    StatsCompare(
                      title: s.t('ui.inventory.shop.buy.if_equipped_now', {
                        'name': protoEsc(eq == null ? '-' : shop.itemName(eq))
                      }),
                      before: shop.preview.current(p),
                      after: shop.preview.withBase(p, w),
                    ),
                  ],
                ),
                SectionPanel(
                  icon: PixelIconKind.coin,
                  title: s.t('ui.inventory.shop.buy.cost_title'),
                  children: [
                    if (owned)
                      ProtoText(protoColor(ProtoColors.green,
                          s.t('ui.inventory.shop.buy.owned_note')))
                    else
                      CostLine(cost: w.price, credits: p.credits),
                  ],
                ),
                SectionPanel(
                  icon: PixelIconKind.sword,
                  title: s.t('ui.inventory.shop.buy.sheet_title'),
                  subtitle: s.t('ui.inventory.shop.buy.sheet_subtitle'),
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
    final s = invStrings(context);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final it in kItems.values)
            PanelRow(
              trailing: PanelButton(
                  s.t('ui.inventory.shop.items.buy', {'price': '\$${it.price}'}),
                  key: ValueKey('item-${it.key}'),
                  reason: shop.guards.buyItem(p, it.item),
                  onPressed: () => shop.controller.buyItem(it.item)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProtoText('<b>${it.text}</b> '
                      '${protoColor(ProtoColors.green, s.t('ui.inventory.shop.items.have', {'n': p.itemCount(it.item), 'max': ProgressionRules.maxItems}))}'),
                  ProtoText('<small>${it.descriptionText}</small>'),
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
String passiveForgeNote(Strings s, ItemInstance it) {
  if (it.passiveId == null || !it.rarity.hasPassive) {
    return protoColor(ProtoColors.dim, s.t('ui.inventory.shop.forge.no_passive'));
  }
  final l = it.effectivePassiveLevel;
  if (l >= ItemInstance.maxPassiveLevel) {
    return protoColor(
        ProtoColors.green, s.t('ui.inventory.shop.forge.passive_max'));
  }
  final left = ItemRules.forgeCapOf(it) - it.forgeLevel;
  final need = 2 - it.forgeLevel % 2;
  if (need > left) {
    return protoColor(ProtoColors.dim,
        s.t('ui.inventory.shop.forge.passive_capped', {'rarity': it.rarity.text}));
  }
  final next = WeaponPassiveDef.roman(l + 1);
  return '<span style="color:$kPassiveHex">'
      '${s.t('ui.inventory.shop.forge.passive_next', {'level': next, 'n': need})}'
      '</span>';
}

/// Herrería sobre instancias: lista de tus armas y, por estadística,
/// valor y stats antes → después, con el tope de la rareza y la subida de
/// la pasiva cada 2 niveles.
class ForgeTab extends StatefulWidget {
  const ForgeTab(
      {super.key, required this.shop, this.layout, this.layoutHooks});

  final ShopContext shop;

  /// Layout fijo (Editor → LAYOUT); `null` = el del catálogo
  /// (editor_layout.md § 6).
  final LayoutDoc? layout;
  final DsLayoutHooks? layoutHooks;

  @override
  State<ForgeTab> createState() => _ForgeTabState();
}

class _ForgeTabState extends State<ForgeTab> {
  String? _sel;

  /// Paso 2: la mejora elegida (vista previa); FORJAR la confirma
  /// (ui_minimal.md § 4, igual que FUSIÓN).
  UpgradeStat? _stat;

  void _pickWeapon(String uid) => setState(() {
        if (_sel != uid) _stat = null;
        _sel = uid;
      });

  /// Buscador de la lista (plantilla DsWeaponList, ui_minimal.md § 3).
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shop = widget.shop;
    final p = shop.profile;
    final rules = shop.rules;
    final owned = shop.owned;
    final s = invStrings(context);
    if (owned.isEmpty) return Text(s.t('ui.inventory.shop.forge.no_weapons'));
    final it = owned.firstWhere((i) => i.uid == _sel,
        orElse: () => owned.firstWhere((i) => i.uid == p.equippedUid,
            orElse: () => owned.first));
    // La equipada primero (fija arriba); el resto, lo que coincida.
    final eqItem = owned.where((i) => i.uid == p.equippedUid).firstOrNull;
    final list = [
      if (eqItem != null) eqItem,
      for (final i in owned)
        if (i.uid != p.equippedUid &&
            (i.uid == it.uid || inventoryMatches(rules, _q.text, item: i)))
          i
    ];
    final equipped = p.equippedUid == it.uid;
    final cap = ItemRules.forgeCapOf(it);
    final passive = rules.items.passiveText(it);
    // Slots del layout (editor_layout.md § 6): la grilla y las tarjetas
    // de forja son fijas; nombre, habilidades, teclas y EQUIPAR se mueven.
    final slots = <String, DsSlotBuilder>{
      // Cabecera (ui_minimal.md § 6): nombre + rareza, forja n/tope y
      // la pasiva en una línea; el detalle, con el mouse.
      ForgeLayout.title: (_) => SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: DsSpace.sm,
                  runSpacing: DsSpace.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(retroText(localItemName(rules.items, it)),
                        key: const ValueKey('forge-title'),
                        style: DsText.title(RarityColors.of(it.rarity))),
                    DsTag(it.rarity.text, color: RarityColors.of(it.rarity)),
                    BuildFitBadge(item: it),
                  ],
                ),
                SizedBox(height: DsSpace.xs),
                Row(
                  key: const ValueKey('forge-cap'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                        s.t('ui.inventory.shop.forge.level',
                            {'n': it.forgeLevel, 'cap': cap}),
                        style: DsText.detail()),
                    SizedBox(width: DsSpace.sm),
                    LevelPips(it.forgeLevel.clamp(0, cap), cap),
                  ],
                ).tip(s.t('ui.inventory.shop.forge.cap_tip',
                    {'rarity': it.rarity.text, 'cap': cap})),
                SizedBox(height: DsSpace.xs),
                _ForgePassiveLine(item: it, rules: rules, passive: passive),
              ],
            ),
          ),
      ForgeLayout.skills: (_) => SkillChips(
          rules: rules, item: it, stats: shop.preview.withItem(p, it)),
      ForgeLayout.upgrades: (_) => SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DsSectionHeader(s.t('ui.inventory.shop.forge.upgrades')),
                for (final st in rules
                    .upgradeStatsFor(rules.catalog.weapons[it.baseId]!))
                  _UpgradeRow(
                      shop: shop,
                      item: it,
                      stat: st,
                      selected: st == _stat,
                      onSelect: () => setState(() => _stat = st)),
                if (_stat case final st?)
                  DsFold(
                      key: const ValueKey('forge-more'),
                      label: s.t('ui.inventory.shop.forge.more_detail'),
                      child: _ForgeDetail(shop: shop, item: it, stat: st)),
              ],
            ),
          ),
      ForgeLayout.keys: (_) =>
          KeyHints(confirm: s.t('ui.inventory.shop.keys.forge'), back: null),
      ForgeLayout.equipped: (_) => equipped
          ? DsTag(s.t('ui.inventory.bag.equipped'), color: DsColors.reward)
          : null,
      ForgeLayout.equip: (_) => equipped
          ? null
          : DsButton(s.t('ui.inventory.shop.forge.equip'),
              key: ValueKey('equip-${it.uid}'),
              size: DsButtonSize.compact,
              tooltip: shop.guards.equip(p, it.uid),
              onPressed: shop.guards.equip(p, it.uid) != null
                  ? null
                  : () => shop.controller.equip(it.uid)),
    };
    // Migas arriba de todo, como en FUSIÓN (ui_minimal.md § 4).
    final crumbs = StepCrumbs(
      steps: [
        s.t('ui.inventory.shop.forge.step.weapon'),
        s.t('ui.inventory.shop.forge.step.upgrade'),
        s.t('ui.inventory.shop.forge.step.confirm'),
      ],
      current: _stat == null ? 1 : 2,
      keyPrefix: 'forge-crumb-',
      onStep: (i) => setState(() {
        if (i < 2) _stat = null;
      }),
    );
    return DsLayoutHost(
      spec: ForgeLayout.spec,
      doc: widget.layout,
      hooks: widget.layoutHooks,
      slots: slots,
      frame: (context, box, r) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          crumbs,
          SizedBox(height: DsSpace.xs),
          Expanded(
              child: PanelSplit(
            list: [
              NavSection(
                child: InitialFocus(
                  // La misma grilla que el INVENTARIO (design_system.md
                  // § "Estructura atómica").
                  child: DsWeaponList(
                    rules: rules,
                    count: list.length,
                    equipped: eqItem == null ? null : 0,
                    keyPrefix: 'forge-',
                    search: ItemGridSearch(
                        fieldKey: const ValueKey('forge-search'),
                        hint: s.t('ui.inventory.bag.search_hint'),
                        controller: _q,
                        onChanged: (_) => setState(() {})),
                    empty: s.t('ui.inventory.craft.no_match_weapon'),
                    cellKey: (i) => ValueKey('forge-row-${list[i].uid}'),
                    focusKeyPrefix: 'forge-row-at-',
                    slot: (i) => ItemSlotData(
                        content: CellContent.item(list[i]),
                        selected: list[i].uid == it.uid),
                    tip: (i, child, focused) => itemHoverTip(
                        rules: rules,
                        viewer: p,
                        item: list[i],
                        attributes: p.attributes,
                        equipped: list[i].uid == p.equippedUid,
                        focused: focused,
                        note: p.equippedUid == list[i].uid
                            ? protoColor(ProtoColors.gold,
                                s.t('ui.inventory.bag.equipped'))
                            : protoColor(
                                ProtoColors.dim,
                                s.t('ui.inventory.shop.forge.level_short', {
                                  'n': list[i].forgeLevel,
                                  'cap': ItemRules.forgeCapOf(list[i])
                                })),
                        child: child),
                    onTap: (i) => _pickWeapon(list[i].uid),
                    onFocusCell: (i) => _pickWeapon(list[i].uid),
                  ),
                ),
              ),
            ],
            detail: PanelDetail(
              footer: [
                if (!r.isEmpty('footer')) r.region('footer'),
                _confirm(s, p, it),
              ],
              children: [
                r.region('detail'),
              ],
            ),
          )),
        ],
      ),
    );
  }

  /// CONFIRMAR de la forja: gris con el motivo hasta elegir una mejora.
  Widget _confirm(Strings str, PlayerProfile p, ItemInstance it) {
    final s = _stat;
    final shop = widget.shop;
    final atMax = s != null && it.forge.level(s) >= WeaponUpgradeLevels.upMax;
    final reason = s == null
        ? str.t('ui.inventory.shop.forge.pick_upgrade')
        : atMax
            ? str.t('ui.inventory.shop.forge.at_max')
            : shop.guards.upgrade(p, it.uid, s);
    return DsButton(str.t('ui.inventory.shop.forge.confirm'),
        key: const ValueKey('forge-confirm'),
        size: DsButtonSize.compact,
        kind: DsButtonKind.primary,
        tooltip: reason,
        onPressed: reason != null
            ? null
            : () {
                shop.controller.upgrade(it.uid, s!);
                setState(() {});
              });
  }
}

/// Qué hace cada estadística de forja (una línea).
String _forgeWhat(Strings s, UpgradeStat stat) =>
    s.t('ui.inventory.shop.forge.what.${stat.name}');

const _forgeIcon = {
  UpgradeStat.pow: PixelIconKind.sword,
  UpgradeStat.crit: PixelIconKind.star,
  UpgradeStat.spd: PixelIconKind.arrowIn,
  UpgradeStat.def: PixelIconKind.anchor,
};

/// Lo que cambia con +1 en [stat]: stats antes / después y el arma.
({DerivedStats b, DerivedStats a, ItemInstance after, int level, bool atMax})
    _forgeCalc(ShopContext shop, ItemInstance item, UpgradeStat stat) {
  final p = shop.profile;
  final l = item.forge.level(stat);
  final r = shop.rules.crafting.forge(p, item.uid, stat);
  final after = r.after ?? item;
  return (
    b: shop.preview.withItem(p, item),
    a: shop.preview.withItem(p, after),
    after: after,
    level: l,
    atMax: l >= WeaponUpgradeLevels.upMax,
  );
}

/// La línea clave (`MAG 29 → 32`) de una mejora.
Widget _forgeDelta(
    Strings s, ShopContext shop, ItemInstance item, UpgradeStat stat) {
  final w = shop.rules.catalog.weapons[item.baseId]!;
  final c = _forgeCalc(shop, item, stat);
  final (b, a) = (c.b, c.a);
  return switch (stat) {
    UpgradeStat.pow => w.mag != null
        ? DsStatLine(s.t('ui.inventory.craft.stat.mag'), b.magic, a.magic)
        : DsStatLine(s.t('ui.inventory.craft.stat.atk'), b.attack, a.attack),
    UpgradeStat.crit => DsStatLine(
        s.t('ui.inventory.shop.forge.crit'), b.critChance, a.critChance,
        format: (x) => '${(x * 100).round()}%'),
    UpgradeStat.spd => DsStatLine(
        s.t('ui.inventory.craft.stat.spd'), b.speed, a.speed,
        format: (x) => x.toStringAsFixed(1)),
    UpgradeStat.def =>
      DsStatLine(s.t('ui.inventory.craft.stat.def'), b.defense, a.defense),
  };
}

/// La pasiva en una línea: nombre (color de pasiva) y cuándo sube; la
/// descripción entera, con el mouse.
class _ForgePassiveLine extends StatelessWidget {
  const _ForgePassiveLine(
      {required this.item, required this.rules, required this.passive});

  final ItemInstance item;
  final ProgressionRules rules;
  final String? passive;

  @override
  Widget build(BuildContext context) {
    final line = ProtoText(passiveForgeNote(invStrings(context), item),
        key: const ValueKey('forge-passive-note'),
        style: DsText.detail());
    final name = rules.items.passiveOf(item)?.nameAt(item.effectivePassiveLevel);
    if (passive == null || name == null) return line;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Flexible(
        child: ProtoText(
            '<span style="color:$kPassiveHex">${protoEsc(name)}</span>',
            style: DsText.body()),
      ),
      SizedBox(width: DsSpace.sm),
      Flexible(child: line),
    ]).tip(passive!);
  }
}

/// "Más detalle" de una mejora (nivel 3): bono, pasiva que sube y qué
/// cambia en batalla con tus números.
class _ForgeDetail extends StatelessWidget {
  const _ForgeDetail(
      {required this.shop, required this.item, required this.stat});

  final ShopContext shop;
  final ItemInstance item;
  final UpgradeStat stat;

  @override
  Widget build(BuildContext context) {
    final rules = shop.rules;
    final c = _forgeCalc(shop, item, stat);
    final l = c.level;
    final passiveUp =
        c.after.effectivePassiveLevel > item.effectivePassiveLevel &&
            item.rarity.hasPassive &&
            item.passiveId != null;
    final def = rules.items.passiveOf(item);
    final s = invStrings(context);
    return Column(
      key: ValueKey('forge-detail-${stat.key}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DsStatLine(s.t('ui.inventory.shop.forge.bonus'), l, c.atMax ? l : l + 1,
            format: (x) => upgradeValueText(stat, x.toInt())),
        _forgeDelta(s, shop, item, stat),
        if (passiveUp && def != null)
          ProtoText(
            key: ValueKey('forge-passive-up-${stat.key}'),
            '<span style="color:$kPassiveHex">'
            '${s.t('ui.inventory.shop.forge.passive_up', {
                  'name': protoEsc(def.name),
                  'from': WeaponPassiveDef.roman(item.effectivePassiveLevel),
                  'arrow': '→',
                  'to': WeaponPassiveDef.roman(c.after.effectivePassiveLevel),
                  'desc': protoEsc(
                      def.descriptionAt(c.after.effectivePassiveLevel)),
                })}</span>',
          ),
        if (!c.atMax)
          if (battleImpactMarkup(rules, c.b, c.a, weapon: c.after)
              case final impact?)
            ProtoText(impact, key: ValueKey('forge-impact-${stat.key}')),
      ],
    );
  }
}

/// Una mejora de forja como [DsActionRow] (ui_minimal.md § 6): ícono,
/// nombre, línea clave, nivel n/5 y costo a la derecha. Tocarla solo la
/// elige (borde dorado); FORJAR la aplica. El detalle, con el mouse o en
/// "Más detalle".
class _UpgradeRow extends StatelessWidget {
  const _UpgradeRow(
      {required this.shop,
      required this.item,
      required this.stat,
      required this.selected,
      required this.onSelect});

  final ShopContext shop;
  final ItemInstance item;
  final UpgradeStat stat;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final p = shop.profile;
    final w = shop.rules.catalog.weapons[item.baseId]!;
    final l = item.forge.level(stat);
    const max = WeaponUpgradeLevels.upMax;
    final atMax = l >= max;
    final cost = CraftRules.discounted(
        CraftRules.forgeCost(w, item.rarity, l), shop.guards.forgeDiscount);
    final reason = atMax ? null : shop.guards.upgrade(p, item.uid, stat);
    final locked = reason != null;
    final s = invStrings(context);
    return KeyedSubtree(
      key: ValueKey('forge-stat-${stat.key}'),
      child: ForgeUpgradeRow(
        key: ValueKey('up-${item.uid}-${stat.key}'),
        reason: reason,
        child: DsActionRow(
          icon: actionRowIcon(context, _forgeIcon[stat]!,
              atMax ? DsColors.success : DsColors.reward,
              locked: locked),
          title: stat.label,
          selected: selected,
          reason: reason,
          line: atMax || locked
              ? null
              : FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: _forgeDelta(s, shop, item, stat)),
          extra: LevelPips(l, max),
          cost: atMax
              ? DsActionRow.costTag(s.t('ui.inventory.shop.forge.max'),
                  locked: true)
              : DsActionRow.costTag('₵$cost',
                  key: ValueKey('forge-cost-${stat.key}'),
                  affordable: p.credits >= cost,
                  locked: locked),
          tooltip: DsTooltipCard(
            title: '${stat.label} $l/$max',
            children: [
              Text(_forgeWhat(s, stat), style: DsText.detail()),
              if (!atMax) _ForgeDetail(shop: shop, item: item, stat: stat),
            ],
          ),
          onTap: atMax || locked ? null : onSelect,
        ),
      ),
    );
  }
}

/// Fila de una mejora con su motivo de bloqueo (`null` = se puede).
class ForgeUpgradeRow extends StatelessWidget {
  const ForgeUpgradeRow({super.key, required this.reason, required this.child});

  final String? reason;
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
