import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../app/theme/panel_frame.dart';
import '../../../../game_engine/data/biomes_catalog.dart';
import '../../../../game_engine/data/fishing_catalog.dart';
import '../../../../game_engine/models/player_profile.dart';
import '../../../../game_engine/models/session_action.dart' show TownOp;
import '../../../../game_engine/models/world_save.dart';
import '../../../../game_engine/models/item.dart' show Rarity;
import '../../../../game_engine/rules/farming_rules.dart';
import '../../../../game_engine/rules/fishing_rules.dart';
import '../../../../game_engine/rules/helper_rules.dart';
import '../../../../game_engine/rules/resident_rules.dart';
import '../session_controller.dart';
import '../session_view.dart';
import 'fishing_widgets.dart' show fishRarityColor;
import 'life_icon.dart';
import 'life_item_grid.dart';

/// Nombre de un producto, cultivo o pez.
String residentItemName(String id) =>
    kFish[id]?.name ?? kCrops[id]?.name ?? id;

/// Ícono de un producto, cultivo o pez.
Widget residentItemIcon(String id) => kFish.containsKey(id)
    ? LifeIcon(id, LifeIconKind.pescado, size: 32)
    : LifeIcon('cosecha_$id', LifeIconKind.cosecha, size: 32);

/// Casillas de la cadena de encargos de [n] (también en el registro).
List<LifeItemCellData> questCells(SessionController c, BiomeNpcDef n,
    ResidentState r, PlayerProfile? p) {
  final chain = kResidentQuests[n.id] ?? const <QuestStepDef>[];
  return [
    for (var i = 0; i < chain.length; i++)
      _questCell(c, n, r, p, chain, i),
  ];
}

LifeItemCellData _questCell(SessionController c, BiomeNpcDef n,
    ResidentState r, PlayerProfile? p, List<QuestStepDef> chain, int i) {
  final q = chain[i];
  final done = i < r.quest, now = i == r.quest;
  final have = p == null ? 0 : ResidentRules.questHave(p, q);
  final what = switch (q.kind) {
    QuestKind.mazmorra => 'Ganar la zona ${q.target}',
    QuestKind.elite => 'Vencer un élite en la zona ${q.target}',
    _ => '${q.n} × ${residentItemName(q.target)}',
  };
  final relic = kResidentRelics[q.reward];
  return LifeItemCellData(
    id: 'quest-${n.id}-$i',
    icon: q.kind.delivered
        ? residentItemIcon(q.target)
        : const LifeIcon('cofre_oficio', LifeIconKind.herramienta, size: 32),
    border: done
        ? DsColors.success
        : now
            ? DsColors.selected
            : DsColors.border,
    search: what,
    caption: done ? 'HECHO' : (now ? '${r.progress}/${q.n}' : '${i + 1}'),
    detail: LifeItemDetail(
      name: '${n.name}: encargo ${i + 1} de ${chain.length}',
      nameColor: DsColors.textTitle,
      tags: [
        (q.kind.label.toUpperCase(), DsColors.textSecondary),
        if (done) ('CUMPLIDO', DsColors.success),
      ],
      lines: [
        what,
        if (now && q.kind.delivered) 'Tenés $have',
        if (now) 'Avance: ${r.progress}/${q.n}',
        'Premio: ${q.gold} de oro y +${q.rep} de relación',
        if (relic != null) 'Objeto único: ${relic.name}',
      ],
      description: done || now ? q.text : 'Todavía no lo pidió.',
      actions: [
        if (now && q.kind.delivered)
          DsButton('ENTREGAR',
              key: ValueKey('quest-turnin-${n.id}'),
              size: DsButtonSize.compact,
              onPressed: have > 0
                  ? () => c.residentOp(TownOp.turnIn, n.id)
                  : null),
      ],
    ),
  );
}

/// Casilla de la orden de entrega de [r] (§ 10.5), o `null`.
LifeItemCellData? orderCell(SessionController c, BiomeNpcDef n,
    ResidentState r, PlayerProfile? p,
    {required bool home}) {
  final o = r.order;
  if (o == null) return null;
  final have = p == null ? 0 : ResidentRules.orderHave(p, o, r.orderQ);
  final w = ResidentRules.orderReward(r);
  final q = CropQuality.values[r.orderQ];
  return LifeItemCellData(
    id: 'order-${n.id}',
    icon: residentItemIcon(o),
    border: DsColors.reward,
    search: residentItemName(o),
    count: r.orderN,
    caption: 'ORDEN',
    detail: LifeItemDetail(
      name: 'Orden de ${n.name}',
      nameColor: DsColors.textTitle,
      tags: [
        ('ORDEN', DsColors.reward),
        if (r.orderQ > 0) (q.label.toUpperCase(), DsColors.textSecondary),
      ],
      lines: [
        '${r.orderN} × ${residentItemName(o)}'
            '${r.orderQ > 0 ? ' (${q.label} o mejor)' : ''}',
        'Tenés $have',
        'XP de personaje: +${w.xp} (con tope diario)',
        'Oro: +${w.gold} · Relación: +${w.rep}',
        if (w.point) 'Punto de árbol: +1',
        'Entregadas: ${r.orders}',
      ],
      description: 'Pide algo nuevo cada día del mundo. Se entrega en el '
          'pueblo.',
      actions: [
        DsButton('ENTREGAR ORDEN',
            key: ValueKey('order-deliver-${n.id}'),
            size: DsButtonSize.compact,
            onPressed: home && have >= r.orderN
                ? () => c.residentOp(TownOp.order, n.id)
                : null),
      ],
    ),
  );
}

/// Habitante de un bioma o del pueblo (overworld_biomes.md § 9 y § 10):
/// una frase, relación, etapa y beneficio; pestañas TIENDA, ENCARGOS,
/// PEDIDOS, REGALOS y CASA, cada una con su grilla y el detalle a la
/// derecha.
class BiomeNpcPanel extends StatefulWidget {
  const BiomeNpcPanel(
      {super.key, required this.view, required this.controller});

  final SessionView view;
  final SessionController controller;

  @override
  State<BiomeNpcPanel> createState() => _BiomeNpcPanelState();
}

class _BiomeNpcPanelState extends State<BiomeNpcPanel> {
  int _tab = 0;

  static const _tabs = ['TIENDA', 'ENCARGOS', 'PEDIDOS', 'REGALOS', 'CASA'];

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final n = c.talkNpc ?? c.nearNpc ?? biomeLayout(c.place)?.npc;
    if (n == null) return const SizedBox.shrink();
    final p = widget.view.me?.profile;
    final town = c.town;
    final r = town.resident(n.id);
    final home = c.place == kPueblo;
    final tier = ResidentRules.tier(r);
    final next = ResidentRules.nextTier(r);
    final tab = _tab.clamp(0, _tabs.length - 1);
    final cells = switch (tab) {
      0 => _shop(c, n, tier, p, inBiome: !home),
      1 => questCells(c, n, r, p),
      2 => _requests(c, n, r, p, town, home: home),
      3 => _gifts(c, n, p),
      _ => _house(c, n, r, p, town, home: home),
    };
    final inviteWhy = ResidentRules.cannotInvite(town, n.id);
    final status = r.invited
        ? ' · vive en el pueblo'
        : inviteWhy == null
            ? ' · se lo puede invitar'
            : ' · para invitarlo: $inviteWhy';
    return PanelFrame(
      key: const ValueKey('panel-biome-npc'),
      title: '${n.name.toUpperCase()} · ${n.role.label.toUpperCase()}',
      width: 680,
      onClose: c.closePanel,
      actions: [
        if (!r.invited)
          PanelButton('INVITAR AL PUEBLO',
              key: const ValueKey('npc-invite'),
              onPressed: inviteWhy == null
                  ? () => c.residentOp(TownOp.invite, n.id)
                  : null),
        PanelButton('CERRAR',
            key: const ValueKey('npc-close'), onPressed: c.closePanel),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(c.npcLine(n), softWrap: true, style: DsText.detail()),
          SizedBox(height: DsSpace.xs),
          Text(
              'Relación ${r.rep} · ${ResidentRules.stage(r).label}$status'
              '${r.unhappy ? ' · descontento' : ''}',
              key: const ValueKey('npc-rep'),
              softWrap: true,
              style: DsText.detail(DsColors.textSecondary)),
          Text(
              'Beneficio en el pueblo: ${ResidentRules.benefitText(n, tier)}'
              '${tier < 0 ? ' (con casa)' : ' (nivel $tier)'}'
              '${next != null ? ' · siguiente: ${ResidentRules.benefitText(n, next)}' : ''}',
              key: const ValueKey('npc-benefit'),
              softWrap: true,
              style: DsText.detail(DsColors.textSecondary)),
          SizedBox(height: DsSpace.xs),
          DsTabBar(
            tabs: [
              for (var i = 0; i < _tabs.length; i++)
                DsTab(_tabs[i], key: ValueKey('npc-tab-$i')),
            ],
            index: tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
          SizedBox(height: DsSpace.xs),
          LifeItemGrid(
            key: ValueKey('npc-grid-$tab'),
            groups: [LifeItemGroup(null, cells)],
            empty: switch (tab) {
              0 => 'No vende nada todavía.',
              2 => r.invited
                  ? 'No pidió nada por ahora.'
                  : 'Pide cosas cuando vive en el pueblo.',
              3 => 'No tenés nada de su bioma para regalarle.',
              4 => 'Primero invitalo al pueblo.',
              _ => 'Nada por ahora.',
            },
          ),
        ],
      ),
    );
  }

  List<LifeItemCellData> _shop(
      SessionController c, BiomeNpcDef n, int tier, PlayerProfile? p,
      {required bool inBiome}) {
    final f = p?.life.farm;
    final gold = p?.credits ?? 0;
    return [
      for (final e in ResidentRules.stock(n, tier, home: inBiome).entries)
        if (kCrops[e.key] case final s?)
          LifeItemCellData(
            id: 'npc-seed-${s.id}',
            icon: LifeIcon('semilla_${s.id}', LifeIconKind.semilla, size: 32),
            border: fishRarityColor(s.rarity),
            search: s.seedName,
            count: (f?.seedCount(s.id) ?? 0) > 0 ? f!.seedCount(s.id) : null,
            caption: '${e.value} oro',
            detail: LifeItemDetail(
              name: s.seedName,
              nameColor: fishRarityColor(s.rarity),
              tags: [
                ('SEMILLA', DsColors.textSecondary),
                (s.rarity.label.toUpperCase(), fishRarityColor(s.rarity)),
              ],
              lines: [
                'Crece en ${(s.growSec / 60).round()} min',
                'Tenés ${f?.seedCount(s.id) ?? 0}',
                'Precio: ${e.value} de oro c/u',
              ],
              description: s.lore.isEmpty ? null : s.lore,
              actions: [
                DsButton('COMPRAR 1 · ${e.value}',
                    key: ValueKey('npc-seed-buy-${s.id}'),
                    size: DsButtonSize.compact,
                    onPressed: gold >= e.value ? () => c.buySeed(s.id) : null),
              ],
            ),
          ),
    ];
  }

  List<LifeItemCellData> _requests(SessionController c, BiomeNpcDef n,
      ResidentState r, PlayerProfile? p, TownState town,
      {required bool home}) {
    final req = r.request;
    final why = ResidentRules.requestUnmet(town, n.id);
    return [
      if (orderCell(c, n, r, p, home: home) case final o?) o,
      if (req != null)
        LifeItemCellData(
          id: 'request-${n.id}',
          icon: const LifeIcon('cofre_oficio', LifeIconKind.herramienta,
              size: 32),
          border: r.unhappy ? DsColors.danger : DsColors.selected,
          search: req.label,
          caption: 'PEDIDO',
          detail: LifeItemDetail(
            name: req.label,
            nameColor: DsColors.textTitle,
            tags: [
              ('PEDIDO', DsColors.selected),
              if (r.unhappy) ('DESCONTENTO', DsColors.danger),
            ],
            lines: [
              'Pedido el día ${r.requestDay}',
              'Premio: +${ResidentRules.t.i('resRequestRep')} de relación',
              if (why != null) why,
            ],
            description: r.unhappy
                ? 'Su beneficio bajó un nivel hasta que lo cumplas. '
                    'Nunca se va del pueblo.'
                : 'Si lo ignorás varios días, queda descontento.',
            actions: [
              if (req != ResidentRequest.casa)
                DsButton('CUMPLIDO',
                    key: ValueKey('request-fulfil-${n.id}'),
                    size: DsButtonSize.compact,
                    onPressed: home && why == null
                        ? () => c.residentOp(TownOp.fulfil, n.id)
                        : null),
            ],
          ),
        ),
    ];
  }

  /// Encargo de forja (roles.md § 4): un arma de tu clase.
  LifeItemCellData _commission(
      SessionController c, PlayerProfile p, TownState town, ResidentState r,
      {required bool home}) {
    final cost = ResidentRules.commissionCost(p.level);
    final why = ResidentRules.cannotCommission(p, town);
    final rr = Rarity.values[ResidentRules.commissionRarity(r,
        fishLv: FishingRules.level(p), farmLv: FarmingRules.level(p))];
    return LifeItemCellData(
      id: 'commission-brann',
      icon: const LifeIcon('cofre_oficio', LifeIconKind.herramienta, size: 32),
      border: DsColors.reward,
      search: 'ENCARGO DE FORJA',
      caption: 'FORJA',
      detail: LifeItemDetail(
        name: 'Encargo de forja',
        nameColor: DsColors.textTitle,
        tags: [(rr.label.toUpperCase(), DsColors.reward)],
        lines: [
          'Un arma de tu clase, ${rr.label.toLowerCase()}, de nivel '
              '${ResidentRules.commissionItemLevel(p.level)}',
          'Costo: ${HelperRules.costText(cost.cost)} + ${cost.lootN} '
              '${residentItemName(cost.loot)}',
          'La rareza sube con tu oficio y la relación con Brann',
          if (why != null) why,
        ],
        description: 'Si me conseguís esto, te hago un arma de tu clase. '
            'Uno por día.',
        actions: [
          DsButton('ENCARGAR',
              key: const ValueKey('commission-brann'),
              size: DsButtonSize.compact,
              onPressed: home && why == null
                  ? () => c.residentOp(TownOp.commission, 'brann')
                  : null),
        ],
      ),
    );
  }

  List<LifeItemCellData> _gifts(
      SessionController c, BiomeNpcDef n, PlayerProfile? p) {
    if (p == null) return const [];
    return [
      for (final id in ResidentRules.giftables(n))
        if (ResidentRules.orderHave(p, id, 0) case final have when have > 0)
          LifeItemCellData(
            id: 'gift-$id',
            icon: residentItemIcon(id),
            border: DsColors.border,
            search: residentItemName(id),
            count: have,
            detail: LifeItemDetail(
              name: residentItemName(id),
              nameColor: DsColors.textTitle,
              tags: const [('REGALO', DsColors.textSecondary)],
              lines: [
                'Tenés $have',
                'El primer regalo de cada día suma +1 de relación',
              ],
              actions: [
                DsButton('REGALAR 1',
                    key: ValueKey('gift-$id'),
                    size: DsButtonSize.compact,
                    onPressed: () =>
                        c.residentOp(TownOp.gift, n.id, target: id)),
              ],
            ),
          ),
    ];
  }

  List<LifeItemCellData> _house(SessionController c, BiomeNpcDef n,
      ResidentState r, PlayerProfile? p, TownState town,
      {required bool home}) {
    if (!r.invited) return const [];
    final h = town.houseOf(n.id);
    final max = ResidentRules.t.i('resMaxHouse');
    final lv = h?.level ?? 0;
    final cost = lv < max ? ResidentRules.investCost(n, lv + 1) : null;
    final why =
        p == null ? 'Sin perfil' : ResidentRules.cannotInvest(p, town, n.id);
    final relicId = kResidentQuests[n.id]?.last.reward;
    final relic = r.relic ? kResidentRelics[relicId] : null;
    return [
      LifeItemCellData(
        id: 'house-${n.id}',
        icon: LifeIcon('casa_${lv.clamp(1, 3)}', LifeIconKind.herramienta,
            size: 32),
        border: DsColors.border,
        search: 'CASA',
        caption: h == null ? 'SIN CASA' : 'NIVEL $lv',
        detail: LifeItemDetail(
          name: h == null ? 'Sin casa' : 'Casa de ${n.name}',
          nameColor: DsColors.textTitle,
          tags: const [('CASA', DsColors.textSecondary)],
          lines: [
            if (h == null)
              'Poné una CASA en EDITAR PUEBLO y asignásela '
                  '(${HelperRules.costText(ResidentRules.placeCost())})'
            else
              'Nivel $lv de $max',
            if (h != null && cost != null)
              'Subir: ${HelperRules.costText(cost.cost)} + '
                  '${cost.lootN} ${residentItemName(cost.loot)}',
            if (h != null && why != null && cost != null) why,
            'Cada nivel sube su beneficio y su tienda',
          ],
          actions: [
            if (h != null && cost != null)
              DsButton('INVERTIR',
                  key: ValueKey('house-invest-${n.id}'),
                  size: DsButtonSize.compact,
                  onPressed: home && why == null
                      ? () => c.residentOp(TownOp.invest, n.id)
                      : null),
          ],
        ),
      ),
      if (n.id == 'brann' && p != null) _commission(c, p, town, r, home: home),
      if (relic != null)
        LifeItemCellData(
          id: 'relic-${relic.id}',
          icon: const LifeIcon('cofre_oficio', LifeIconKind.herramienta,
              size: 32),
          border: DsColors.reward,
          search: relic.name,
          caption: 'ÚNICO',
          detail: LifeItemDetail(
            name: relic.name,
            nameColor: DsColors.reward,
            tags: const [('OBJETO ÚNICO', DsColors.reward)],
            lines: const ['Su beneficio sube un nivel'],
            description: relic.lore,
          ),
        ),
    ];
  }
}
