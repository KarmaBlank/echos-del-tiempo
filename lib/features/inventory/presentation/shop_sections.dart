import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/panel_widgets.dart';
import '../../../app/design/design.dart';
import '../../../app/design/ds_layout_host.dart';
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
import 'craft_layout.dart';
import 'item_grid.dart';
import 'item_hover_tip.dart';
import 'item_widgets.dart' show CellContent;
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

  String itemName(ItemInstance it) => rules.items.displayName(it);
}

/// Pestañas de la tienda (armería del lobby y preparación). Ver
/// docs/specs/panels.md § "Armería" (loot v2).
enum ArmoryTab {
  buy('COMPRAR', 'Armas base para cualquier clase.'),
  forge('FORJA', 'Arma, mejora, confirmar.'),
  fuse('FUSIÓN', 'Destino, acción, vista previa, confirmar.'),
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
    '<span class="k">FUSIÓN</span>: 1 DESTINO → 2 ACCIÓN → 3 PREVIA → '
    'CONFIRMAR. '
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
    // `DsStatLine` (design_system.md § 6): una línea por stat, sufijo en
    // Detalle; la fórmula de VEL va al tooltip.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DsStatLine('HP', now.maxHp, next.maxHp, key: const ValueKey('stat-HP')),
        DsStatLine('MP', now.maxMp, next.maxMp, key: const ValueKey('stat-MP')),
        Tooltip(
          key: const ValueKey('stat-weight'),
          message: retroText('VEL = 6 + AGI×0.5 + DES×0.1 − peso del arma'),
          child: DsStatLine('VEL', now.speed, next.speed,
              key: const ValueKey('stat-VEL'),
              format: dec,
              suffix: 'peso ${w == w2 ? w : '$w → $w2'}'),
        ),
        DsStatLine('ATQ', now.attack, next.attack,
            key: const ValueKey('stat-ATQ')),
        DsStatLine('MAG', now.magic, next.magic,
            key: const ValueKey('stat-MAG')),
        DsStatLine('DEF', now.defense, next.defense,
            key: const ValueKey('stat-DEF'),
            suffix: '(-${(next.defensePercent * 100).round()}% daño)'),
        DsStatLine('CRÍT', now.critChance, next.critChance,
            key: const ValueKey('stat-CRIT'),
            format: pct,
            suffix: '(daño ×${next.critMultiplier == 2 ? '2' : '1.5'})'),
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
    final text = foldSearch('${w.name} ${w.type}');
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
    final eqNow = shop.rules.equippedItem(p);
    // Cabecera de la plantilla: buscador siempre y la equipada fija.
    final head = [
      DsSearchField(
        key: const ValueKey('buy-search'),
        hint: 'BUSCAR: nombre, tipo',
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
      return Column(children: [filter, const Text('No hay armas a la venta.')]);
    }
    if (list.isEmpty) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        filter,
        ...head,
        Text('Ninguna arma coincide con la búsqueda.', style: DsText.detail()),
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
                              '${rules.ignoreRequirements ? '' : 'Nv ${x.level}  '}'
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
                if (pick != null)
                  ProtoText(
                      key: const ValueKey('shop-build-pick'),
                      protoColor(kPlanColor,
                          '» Recomendada para tu build: ${protoEsc(pick.reasons.join(' · '))}')),
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
                      '${protoColor(ProtoColors.green, 'tienes ${p.itemCount(it.item)}/${ProgressionRules.maxItems}')}'),
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
  final left = ItemRules.forgeCapOf(it) - it.forgeLevel;
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
    if (owned.isEmpty) return const Text('No tienes armas.');
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
      ForgeLayout.title: (_) => SizedBox(
            width: double.infinity,
            child: Row(
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
          ),
      ForgeLayout.skills: (_) => SkillChips(
          rules: rules, item: it, stats: shop.preview.withItem(p, it)),
      ForgeLayout.upgrades: (_) => SizedBox(
            width: double.infinity,
            child: SectionPanel(
              icon: PixelIconKind.anvil,
              title: 'FORJA',
              subtitle: 'elegí una y confirmá',
              children: [
                Row(
                  key: const ValueKey('forge-cap'),
                  children: [
                    Flexible(
                        child:
                            Text(retroText('Forja ${it.forgeLevel}/$cap  '))),
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
                  // Las 4 mejoras en una fila siempre que entren.
                  minWidth: 180,
                  children: [
                    for (final s in rules
                        .upgradeStatsFor(rules.catalog.weapons[it.baseId]!))
                      _UpgradeCard(
                          shop: shop,
                          item: it,
                          stat: s,
                          selected: s == _stat,
                          onSelect: () => setState(() => _stat = s)),
                  ],
                ),
              ],
            ),
          ),
      ForgeLayout.keys: (_) =>
          const KeyHints(confirm: 'Forjar', back: 'Cerrar'),
      ForgeLayout.equipped: (_) => equipped
          ? const Text('EQUIPADA', style: TextStyle(color: ProtoColors.gold))
          : null,
      ForgeLayout.equip: (_) => equipped
          ? null
          : PanelButton('EQUIPAR',
              key: ValueKey('equip-${it.uid}'),
              reason: shop.guards.equip(p, it.uid),
              onPressed: () => shop.controller.equip(it.uid)),
    };
    // Migas arriba de todo, como en FUSIÓN (ui_minimal.md § 4).
    final crumbs = StepCrumbs(
      steps: const ['ARMA', 'MEJORA', 'CONFIRMAR'],
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
                        hint: 'BUSCAR: nombre, tipo, mod',
                        controller: _q,
                        onChanged: (_) => setState(() {})),
                    empty: 'Ninguna arma coincide con la búsqueda.',
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
                            ? protoColor(ProtoColors.gold, 'EQUIPADA')
                            : protoColor(ProtoColors.dim,
                                'forja ${list[i].forgeLevel}/${ItemRules.forgeCapOf(list[i])}'),
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
                _confirm(p, it),
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
  Widget _confirm(PlayerProfile p, ItemInstance it) {
    final s = _stat;
    final shop = widget.shop;
    final atMax = s != null && it.forge.level(s) >= WeaponUpgradeLevels.upMax;
    final reason = s == null
        ? 'Elegí una mejora'
        : atMax
            ? 'Ya está al máximo'
            : shop.guards.upgrade(p, it.uid, s);
    return DsButton('FORJAR',
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
      {required this.shop,
      required this.item,
      required this.stat,
      required this.selected,
      required this.onSelect});

  final ShopContext shop;
  final ItemInstance item;
  final UpgradeStat stat;

  /// Elegida en el paso 2 (borde dorado); tocarla solo la elige.
  final bool selected;
  final VoidCallback onSelect;

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
        selected: selected,
        onTap: () {
          if (!atMax && reason == null) onSelect();
        },
        footer: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [LevelPips(l, max), Text('$l/$max')],
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
