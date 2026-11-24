import '../../domain/town_names.dart';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../app/theme/panel_frame.dart';
import '../../../../game_engine/data/fishing_catalog.dart';
import '../../../../game_engine/data/npc_talk_catalog.dart';
import '../../../../game_engine/models/player_profile.dart';
import '../../../../game_engine/models/world_save.dart';
import '../../../../game_engine/rules/biome_fisher_rules.dart';
import '../../../../game_engine/rules/fishing_rules.dart';
import '../../../../game_engine/rules/npc_talk_rules.dart';
import '../session_controller.dart';
import '../session_view.dart';
import 'fishing_widgets.dart' show fishRarityColor;
import 'life_icon.dart';
import 'life_item_grid.dart';
import 'npc_talk.dart';
import '../world_strings.dart';

/// Las ventanas del arraigado.
enum _FisherMenu { pedido, puesto }

/// Pescador nativo del bioma, un arraigado (fishing.md § 12,
/// overworld_biomes.md § 12): el mismo cuadro de diálogo que los
/// habitantes; HABLAR, PEDIDO DEL DÍA, PUESTO (después de invitarlo) e
/// INVITAR AL PUEBLO (cuando hay amistad) salen del menú de opciones.
class BiomeFisherPanel extends StatefulWidget {
  const BiomeFisherPanel(
      {super.key, required this.view, required this.controller});

  final SessionView view;
  final SessionController controller;

  @override
  State<BiomeFisherPanel> createState() => _BiomeFisherPanelState();
}

class _BiomeFisherPanelState extends State<BiomeFisherPanel> {
  _FisherMenu? _menu;
  String? _greet;
  String? _greetTo;
  NpcTalk? _talk;

  /// Lo que dijo al invitarlo (reemplaza al saludo).
  String? _answer;

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final f = kBiomeFishers[c.place];
    final p = widget.view.me?.profile;
    if (f == null || p == null) return const SizedBox.shrink();
    final id = nativeId(f.biome);
    if (_greetTo != id) {
      _greetTo = id;
      _greet = NpcTalk.greet(id, extra: f.lines);
      _talk = NpcTalk(id);
      _answer = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => c.npcTalked(id));
    }
    final menu = _menu;
    if (menu == null) return _dialogue(c, f, p, c.townState);
    return _window(c, f, p, c.townState, menu);
  }

  String _giftText(NpcTalkDef? d) => [
        ...?d?.decline,
        if (d != null && d.gift.isNotEmpty)
          context.t('ui.town.fisher.gift_text', {'gift': d.gift, 'gold': NpcTalkRules.giftGold, 'xp': NpcTalkRules.giftFishXp, 'points': NpcTalkRules.giftPoints}),
      ].join(' ');

  Widget _dialogue(SessionController c, BiomeFisherDef f, PlayerProfile p,
      TownState town) {
    final id = nativeId(f.biome);
    final talk = _talk ??= NpcTalk(id);
    void refresh() => setState(() {});
    void open(_FisherMenu m) => setState(() => _menu = m);
    final declined = NpcTalkRules.declined(town, f.biome);
    final canInvite = NpcTalkRules.cannotInvite(town, f.biome) == null;
    return Align(
      key: const ValueKey('panel-biome-fisher'),
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.all(DsSpace.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: DsDialogueBox(
            portrait: LifeIcon(f.sprite, LifeIconKind.herramienta,
                size: DsDialogueBox.portraitSize),
            name: f.name,
            role: context.t('ui.town.fisher.role'),
            text: talk.text(_answer ?? _greet ?? f.lines.first),
            onCancel: c.closePanel,
            choices: talk.active
                ? talk.choices(town, refresh, inTown: false)
                : [
                    talk.entry(town, refresh, inTown: false),
                    DsChoice(context.t('ui.town.fisher.menu_order'),
                        key: const ValueKey('fisher-choice-pedido'),
                        onSelected: () => open(_FisherMenu.pedido)),
                    if (declined)
                      DsChoice(context.t('ui.town.fisher.menu_stall'),
                          key: const ValueKey('fisher-choice-puesto'),
                          onSelected: () => open(_FisherMenu.puesto)),
                    if (canInvite)
                      DsChoice(context.t('ui.town.npc.invite'),
                          key: const ValueKey('fisher-invite'),
                          onSelected: () {
                        if (c.nativeInvite()) {
                          setState(() => _answer = _giftText(npcTalk(id)));
                        }
                      }),
                    DsChoice(context.t('ui.town.npc.bye'),
                        key: const ValueKey('fisher-close'),
                        onSelected: c.closePanel),
                  ],
          ),
        ),
      ),
    );
  }

  Widget _status(BiomeFisherDef f, PlayerProfile p, TownState town) {
    final b = town.bond(nativeId(f.biome));
    const goal = NpcTalkRules.inviteRep;
    return DsStatusStrip([
      DsStatusCell(
          context.t('ui.town.fisher.friendship'),
          key: const ValueKey('fisher-rep'),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  b.declined
                      ? b.rep.toString()
                      : context.t('ui.town.npc.rep_value', {'n': b.rep, 'goal': goal}),
                  style: DsText.body(DsColors.mp)),
              SizedBox(height: DsSpace.xs),
              DsMeter(b.rep, goal, color: DsColors.mp),
            ],
          )),
      DsStatusCell(context.t('ui.town.fisher.orders_done'),
          Text(b.orders.toString(), style: DsText.body(DsColors.success))),
      DsStatusCell(context.t('ui.town.npc.your_gold'),
          key: const ValueKey('fisher-gold'),
          Text(p.credits.toString(), style: DsText.body(DsColors.reward))),
    ]);
  }

  Widget _window(SessionController c, BiomeFisherDef f, PlayerProfile p,
      TownState town, _FisherMenu menu) {
    void back() => setState(() => _menu = null);
    final (title, cells, empty) = switch (menu) {
      _FisherMenu.pedido => (
          context.t('ui.town.fisher.order_title'),
          _order(c, f, p),
          context.t('ui.town.fisher.no_order')
        ),
      _FisherMenu.puesto => (
          context.t('ui.town.fisher.stall_title'),
          _stall(c, f, p, town),
          context.t('ui.town.fisher.no_stall')
        ),
    };
    return PanelFrame(
      key: const ValueKey('panel-biome-fisher'),
      title: context.t('ui.town.fisher.window_title', {'name': f.name.toUpperCase(), 'menu': title}),
      width: 1000,
      onClose: back,
      header: _status(f, p, town),
      leading: [
        PanelButton(context.t('ui.town.npc.back'),
            key: const ValueKey('fisher-back'), onPressed: back),
      ],
      actions: [
        PanelButton(context.t('ui.town.npc.bye_button'),
            key: const ValueKey('fisher-bye'), onPressed: c.closePanel),
      ],
      child: LifeItemGrid(
        key: ValueKey('fisher-grid-${menu.name}'),
        groups: [LifeItemGroup(null, cells)],
        empty: empty,
      ),
    );
  }

  List<LifeItemCellData> _order(
      SessionController c, BiomeFisherDef f, PlayerProfile p) {
    final day = math.max(1, c.town.sky.day);
    final lv = FishingRules.level(p);
    final r = BiomeFisherRules.request(f.biome, day, lv);
    final why = BiomeFisherRules.cannot(p, c.townState, f.biome, day);
    final d = r == null ? null : kFish[r.species];
    if (r == null || d == null) return const [];
    final w = BiomeFisherRules.reward(r, lv);
    return [
      LifeItemCellData(
        id: 'fisher-req-${d.id}',
        icon: LifeIcon(d.id, LifeIconKind.pescado, size: 32),
        border: fishRarityColor(d.rarity),
        search: d.name,
        count: r.n,
        caption: '${r.cm} cm',
        detail: LifeItemDetail(
          name: context.t('ui.town.fisher.order_name', {'name': f.name}),
          nameColor: DsColors.textTitle,
          tags: [
            (context.t('ui.town.fisher.order_title'), DsColors.reward),
            (d.rarity.text.toUpperCase(), fishRarityColor(d.rarity)),
          ],
          lines: [
            context.t('ui.town.npc.order_line_cm', {'n': r.n, 'item': d.name, 'cm': r.cm}),
            context.t('ui.town.fisher.have_record', {'n': p.life.count(d.id), 'cm': p.life.log[d.id] ?? 0}),
            context.t('ui.town.fisher.fish_xp', {'n': w.fishXp}),
            context.t('ui.town.fisher.char_xp', {'n': w.charXp}),
            context.t('ui.town.fisher.gold_plus', {'n': BiomeFisherRules.favorGold(c.townState, f.biome, w.gold)}),
            context.t('ui.town.fisher.friendship_plus', {'n': NpcTalkRules.orderRep}),
          ],
          description: context.t('ui.town.fisher.order_desc'),
          actions: [
            DsButton(context.t('ui.town.npc.turn_in'),
                key: const ValueKey('fisher-deliver'),
                size: DsButtonSize.compact,
                tooltip: why,
                onPressed: why == null ? c.fisherDeliver : null),
          ],
        ),
      ),
    ];
  }

  /// Puesto: lo que vende hoy (con la novedad) y lo que te compra de tu
  /// bolsa, todo en la misma grilla con el detalle a la derecha.
  List<LifeItemCellData> _stall(SessionController c, BiomeFisherDef f,
      PlayerProfile p, TownState town) {
    final day = math.max(1, c.town.sky.day);
    final cells = <LifeItemCellData>[];
    for (final g in NpcTalkRules.stock(town, f.biome, day)) {
      final d = kFish[g.species];
      if (d == null) continue;
      final short = p.credits < g.price;
      cells.add(LifeItemCellData(
        id: 'fisher-buy-${d.id}',
        icon: LifeIcon(d.id, LifeIconKind.pescado, size: 32),
        border: fishRarityColor(d.rarity),
        search: d.name,
        caption: context.t('ui.town.npc.gold_short', {'n': g.price}),
        detail: LifeItemDetail(
          name: d.name,
          nameColor: fishRarityColor(d.rarity),
          tags: [
            (context.t('ui.town.fisher.sells'), DsColors.reward),
            if (g.fresh) (context.t('ui.town.fisher.new'), DsColors.success),
            (d.rarity.text.toUpperCase(), fishRarityColor(d.rarity)),
          ],
          lines: [
            context.t('ui.town.fisher.price', {'n': g.price}),
            context.t('ui.town.npc.have', {'n': p.life.count(d.id)}),
          ],
          description: g.fresh
              ? context.t('ui.town.fisher.fresh_desc', {'n': NpcTalkRules.freshEvery})
              : context.t('ui.town.fisher.from_lake'),
          actions: [
            DsButton(context.t('ui.town.npc.buy'),
                key: ValueKey('fisher-buy-${d.id}'),
                size: DsButtonSize.compact,
                onPressed:
                    short ? null : () => c.nativeTrade(d.id, 1, buy: true)),
          ],
        ),
      ));
    }
    for (final e in p.life.bag.entries) {
      final pr = NpcTalkRules.sellPrice(f.biome, e.key);
      final d = kFish[e.key];
      if (pr == null || d == null || e.value <= 0) continue;
      cells.add(LifeItemCellData(
        id: 'fisher-sell-${d.id}',
        icon: LifeIcon(d.id, LifeIconKind.pescado, size: 32),
        border: fishRarityColor(d.rarity),
        search: d.name,
        count: e.value,
        caption: context.t('ui.town.fisher.buys'),
        detail: LifeItemDetail(
          name: d.name,
          nameColor: fishRarityColor(d.rarity),
          tags: [
            (context.t('ui.town.fisher.buys_from_you'), DsColors.textSecondary),
            (d.rarity.text.toUpperCase(), fishRarityColor(d.rarity)),
          ],
          lines: [
            context.t('ui.town.fisher.pays_each', {'n': pr}),
            context.t('ui.town.npc.have', {'n': e.value}),
          ],
          description: context.t('ui.town.fisher.buys_desc'),
          actions: [
            DsButton(context.t('ui.town.fisher.sell_one'),
                key: ValueKey('fisher-sell-${d.id}'),
                size: DsButtonSize.compact,
                onPressed: () => c.nativeTrade(d.id, 1, buy: false)),
            DsButton(context.t('ui.town.fisher.sell_all'),
                key: ValueKey('fisher-sell-all-${d.id}'),
                size: DsButtonSize.compact,
                onPressed: () => c.nativeTrade(d.id, e.value, buy: false)),
          ],
        ),
      ));
    }
    return cells;
  }
}
