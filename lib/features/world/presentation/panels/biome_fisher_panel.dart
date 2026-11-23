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
          '(${d.gift}: +${NpcTalkRules.giftGold} de oro, '
              '+${NpcTalkRules.giftFishXp} XP de Pesca, '
              '+${NpcTalkRules.giftPoints} punto de árbol y sus pedidos '
              'pagan más oro.)',
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
            role: 'Pescador',
            text: talk.text(_answer ?? _greet ?? f.lines.first),
            onCancel: c.closePanel,
            choices: talk.active
                ? talk.choices(town, refresh, inTown: false)
                : [
                    talk.entry(town, refresh, inTown: false),
                    DsChoice('Pedido del día',
                        key: const ValueKey('fisher-choice-pedido'),
                        onSelected: () => open(_FisherMenu.pedido)),
                    if (declined)
                      DsChoice('Puesto',
                          key: const ValueKey('fisher-choice-puesto'),
                          onSelected: () => open(_FisherMenu.puesto)),
                    if (canInvite)
                      DsChoice('Invitar al pueblo',
                          key: const ValueKey('fisher-invite'),
                          onSelected: () {
                        if (c.nativeInvite()) {
                          setState(() => _answer = _giftText(npcTalk(id)));
                        }
                      }),
                    DsChoice('Adiós',
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
          'Amistad',
          key: const ValueKey('fisher-rep'),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(b.declined ? '${b.rep}' : '${b.rep} / $goal',
                  style: DsText.body(DsColors.mp)),
              SizedBox(height: DsSpace.xs),
              DsMeter(b.rep, goal, color: DsColors.mp),
            ],
          )),
      DsStatusCell('Pedidos cumplidos',
          Text('${b.orders}', style: DsText.body(DsColors.success))),
      DsStatusCell('Tu oro',
          key: const ValueKey('fisher-gold'),
          Text('${p.credits}', style: DsText.body(DsColors.reward))),
    ]);
  }

  Widget _window(SessionController c, BiomeFisherDef f, PlayerProfile p,
      TownState town, _FisherMenu menu) {
    void back() => setState(() => _menu = null);
    final (title, cells, empty) = switch (menu) {
      _FisherMenu.pedido => (
          'PEDIDO DEL DÍA',
          _order(c, f, p),
          'Hoy no pide nada.'
        ),
      _FisherMenu.puesto => (
          'PUESTO',
          _stall(c, f, p, town),
          'Hoy no tiene nada.'
        ),
    };
    return PanelFrame(
      key: const ValueKey('panel-biome-fisher'),
      title: '${f.name.toUpperCase()} · PESCADOR · $title',
      width: 1000,
      onClose: back,
      header: _status(f, p, town),
      leading: [
        PanelButton('VOLVER',
            key: const ValueKey('fisher-back'), onPressed: back),
      ],
      actions: [
        PanelButton('ADIÓS',
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
          name: 'Pedido de ${f.name}',
          nameColor: DsColors.textTitle,
          tags: [
            ('PEDIDO DEL DÍA', DsColors.reward),
            (d.rarity.label.toUpperCase(), fishRarityColor(d.rarity)),
          ],
          lines: [
            '${r.n} × ${d.name} (de ${r.cm} cm o más)',
            'Tenés ${p.life.count(d.id)} · tu récord: '
                '${p.life.log[d.id] ?? 0} cm',
            'XP de Pesca: +${w.fishXp}',
            'XP de personaje: +${w.charXp}',
            'Oro: +${BiomeFisherRules.favorGold(c.townState, f.biome, w.gold)}',
            'Amistad: +${NpcTalkRules.orderRep}',
          ],
          description: 'Solo se pesca en este lago. Pide algo nuevo cada '
              'día del mundo, según tu nivel de Pesca.',
          actions: [
            DsButton('ENTREGAR',
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
        caption: '${g.price} oro',
        detail: LifeItemDetail(
          name: d.name,
          nameColor: fishRarityColor(d.rarity),
          tags: [
            ('VENDE', DsColors.reward),
            if (g.fresh) ('NOVEDAD', DsColors.success),
            (d.rarity.label.toUpperCase(), fishRarityColor(d.rarity)),
          ],
          lines: [
            'Precio: ${g.price} oro',
            'Tenés ${p.life.count(d.id)}',
          ],
          description: g.fresh
              ? 'Lo trajo hoy. Trae algo así cada '
                  '${NpcTalkRules.freshEvery} días.'
              : 'De su lago.',
          actions: [
            DsButton('COMPRAR',
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
        caption: 'COMPRA',
        detail: LifeItemDetail(
          name: d.name,
          nameColor: fishRarityColor(d.rarity),
          tags: [
            ('TE COMPRA', DsColors.textSecondary),
            (d.rarity.label.toUpperCase(), fishRarityColor(d.rarity)),
          ],
          lines: [
            'Paga $pr oro c/u',
            'Tenés ${e.value}',
          ],
          description: 'Solo compra peces de su lago.',
          actions: [
            DsButton('VENDER 1',
                key: ValueKey('fisher-sell-${d.id}'),
                size: DsButtonSize.compact,
                onPressed: () => c.nativeTrade(d.id, 1, buy: false)),
            DsButton('VENDER TODO',
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
