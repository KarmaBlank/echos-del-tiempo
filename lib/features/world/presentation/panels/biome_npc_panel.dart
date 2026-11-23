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
import '../../../../game_engine/rules/quest_track_rules.dart';
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

/// Botón SEGUIR / DEJAR DE SEGUIR de un encargo activo (roles.md § 7).
Widget trackButton(SessionController c, PlayerProfile? p, String npc,
    QuestTrackKind kind) {
  final key = QuestTrackRules.trackKey(kind, npc);
  final on = p?.tracked.contains(key) ?? false;
  final full = (p?.tracked.length ?? 0) >= QuestTrackRules.maxTracked;
  return DsButton(on ? 'DEJAR DE SEGUIR' : 'SEGUIR',
      key: ValueKey('track-$key'),
      size: DsButtonSize.compact,
      selected: on,
      tooltip: !on && full
          ? 'Ya seguís ${QuestTrackRules.maxTracked} encargos'
          : null,
      onPressed: p == null || (!on && full)
          ? null
          : () => c.trackQuest(npc, key));
}

/// Casillas de la cadena de encargos de [n] (también en el registro):
/// solo los que ya pidió (cumplidos + el activo). Los pasos futuros no se
/// listan nunca; el próximo lo cuenta él en el diálogo.
List<LifeItemCellData> questCells(SessionController c, BiomeNpcDef n,
    ResidentState r, PlayerProfile? p) {
  final chain = kResidentQuests[n.id] ?? const <QuestStepDef>[];
  // El activo aparece recién cuando él lo pidió en el diálogo.
  final asked = p == null || r.progress > 0 || QuestTrackRules.questSeen(p, r);
  final upTo = (r.quest + (asked ? 1 : 0)).clamp(0, chain.length);
  return [
    for (var i = 0; i < upTo; i++)
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
      name: '${n.name}: encargo ${i + 1}',
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
      description: q.text,
      actions: [
        if (now) trackButton(c, p, n.id, QuestTrackKind.encargo),
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
        trackButton(c, p, n.id, QuestTrackKind.orden),
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

/// Las opciones del diálogo con un habitante, en orden.
enum NpcMenu { comprar, encargos, pedidos, regalar, casa }

/// Habitante de un bioma o del pueblo (overworld_biomes.md § 9 y § 10,
/// ui_minimal.md § 9): primero el cuadro de diálogo abajo (retrato,
/// nombre, frase escrita letra a letra y menú de opciones); cada opción
/// abre una ventana de menú con franja de estado y su contenido.
class BiomeNpcPanel extends StatefulWidget {
  const BiomeNpcPanel(
      {super.key, required this.view, required this.controller});

  final SessionView view;
  final SessionController controller;

  @override
  State<BiomeNpcPanel> createState() => _BiomeNpcPanelState();
}

class _BiomeNpcPanelState extends State<BiomeNpcPanel> {
  NpcMenu? _menu;
  String? _sel;
  int _qty = 1;

  /// Lo que dijo al abrir el diálogo (no cambia al marcarlo visto).
  String? _spoken;
  String? _spokenTo;

  /// Lo que dice al hablarle (roles.md § 7.4): si tiene un paso nuevo de
  /// su cadena que todavía no te contó, lo pide con sus palabras; si no,
  /// su frase del día. Suma el pedido o la orden nuevos.
  String _line(SessionController c, BiomeNpcDef n, ResidentState r,
      PlayerProfile? p) {
    final q = ResidentRules.currentQuest(r);
    final fresh = p != null && !QuestTrackRules.seen(p, r);
    final parts = [
      if (q != null &&
          p != null &&
          r.progress == 0 &&
          !QuestTrackRules.questSeen(p, r) &&
          q.text.isNotEmpty)
        q.text
      else
        c.npcLine(n),
      if (fresh && r.request != null)
        'Además, en el pueblo necesito esto: ${r.request!.label.toLowerCase()}.',
      if (fresh && r.order != null)
        'Hoy te pido ${r.orderN} × ${residentItemName(r.order!)}.',
    ];
    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final n = c.talkNpc ?? c.nearNpc ?? biomeLayout(c.place)?.npc;
    if (n == null) return const SizedBox.shrink();
    final p = widget.view.me?.profile;
    final town = c.town;
    final r = town.resident(n.id);
    final home = c.place == kPueblo;
    if (_spokenTo != n.id) {
      _spokenTo = n.id;
      _spoken = _line(c, n, r, p);
      if (p != null && !QuestTrackRules.seen(p, r)) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => c.markNpcSeen(n.id));
      }
    }
    final menu = _menu;
    if (menu == null) return _dialogue(c, n, r, p, town, home: home);
    return _window(c, n, r, p, town, menu, home: home);
  }

  Widget _portrait(BiomeNpcDef n) => LifeIcon(n.portrait,
      LifeIconKind.herramienta, size: DsDialogueBox.portraitSize);

  Widget _dialogue(SessionController c, BiomeNpcDef n, ResidentState r,
      PlayerProfile? p, TownState town,
      {required bool home}) {
    final tier = ResidentRules.tier(r);
    final inviteWhy = ResidentRules.cannotInvite(town, n.id);
    void open(NpcMenu m) => setState(() {
          _menu = m;
          _sel = null;
          _qty = 1;
        });
    DsChoice opt(NpcMenu m, String label, String? why) => DsChoice(label,
        key: ValueKey('npc-choice-${m.name}'),
        reason: why,
        onSelected: why == null ? () => open(m) : null);
    final stock = ResidentRules.stock(n, tier, home: !home);
    return Align(
      key: const ValueKey('panel-biome-npc'),
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.all(DsSpace.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: DsDialogueBox(
            portrait: _portrait(n),
            name: n.name,
            role: n.role.label,
            text: _spoken ?? c.npcLine(n),
            onCancel: c.closePanel,
            choices: [
              opt(NpcMenu.comprar, 'Comprar',
                  stock.isEmpty ? 'No vende nada todavía' : null),
              opt(NpcMenu.encargos, 'Encargos',
                  questCells(c, n, r, p).isEmpty ? 'No te pidió nada' : null),
              opt(NpcMenu.pedidos, 'Pedidos',
                  r.invited ? null : 'Pide cosas cuando vive en el pueblo'),
              opt(NpcMenu.regalar, 'Regalar',
                  _gifts(c, n, p).isEmpty
                      ? 'No tenés nada de su bioma'
                      : null),
              opt(NpcMenu.casa, 'Casa',
                  r.invited ? null : 'Primero invitalo al pueblo'),
              DsChoice('Invitar al pueblo',
                  key: const ValueKey('npc-invite'),
                  reason: inviteWhy,
                  onSelected: inviteWhy == null
                      ? () => c.residentOp(TownOp.invite, n.id)
                      : null),
              DsChoice('Adiós',
                  key: const ValueKey('npc-close'), onSelected: c.closePanel),
            ],
          ),
        ),
      ),
    );
  }

  /// Próxima meta de relación: invitarlo, asentarse o arraigarse.
  int _repGoal(ResidentState r) {
    final t = ResidentRules.t;
    for (final g in [
      if (!r.invited) t.i('resInviteRep'),
      t.i('resSettledRep'),
      t.i('resRootedRep'),
    ]) {
      if (r.rep < g) return g;
    }
    return t.i('resRootedRep');
  }

  Widget _status(BiomeNpcDef n, ResidentState r, PlayerProfile? p,
      {required bool shop}) {
    final tier = ResidentRules.tier(r);
    final next = ResidentRules.nextTier(r);
    final goal = _repGoal(r);
    return DsStatusStrip([
      DsStatusCell('Relación',
          key: const ValueKey('npc-rep'),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${r.rep} / $goal', style: DsText.body(DsColors.mp)),
              SizedBox(height: DsSpace.xs),
              DsMeter(r.rep, goal, color: DsColors.mp),
            ],
          )),
      DsStatusCell('Etapa',
          Text.rich(TextSpan(children: [
            TextSpan(
                text: ResidentRules.stage(r).label,
                style: DsText.body(DsColors.conditionReady)),
            TextSpan(
                text: r.invited ? '\nVive en el pueblo' : '\nEn su bioma',
                style: DsText.detail(DsColors.textSecondary)),
            if (r.unhappy)
              TextSpan(
                  text: '\nDescontento',
                  style: DsText.detail(DsColors.danger)),
          ]))),
      DsStatusCell('Beneficio actual',
          key: const ValueKey('npc-benefit'),
          flex: 2,
          Text(
              tier < 0
                  ? 'Ninguno (necesita casa)'
                  : '${ResidentRules.benefitText(n, tier)} · nivel $tier',
              style: DsText.body(DsColors.success))),
      DsStatusCell('Siguiente',
          flex: 2,
          Text(
              next == null
                  ? 'Al máximo'
                  : '${ResidentRules.benefitText(n, next)} · nivel $next',
              style: DsText.body(DsColors.reward))),
      if (shop)
        DsStatusCell('Tu oro',
            key: const ValueKey('npc-gold'),
            Text('${p?.credits ?? 0}', style: DsText.body(DsColors.reward))),
    ]);
  }

  Widget _window(SessionController c, BiomeNpcDef n, ResidentState r,
      PlayerProfile? p, TownState town, NpcMenu menu,
      {required bool home}) {
    final tier = ResidentRules.tier(r);
    void back() => setState(() => _menu = null);
    final title = switch (menu) {
      NpcMenu.comprar => 'TIENDA',
      NpcMenu.encargos => 'ENCARGOS',
      NpcMenu.pedidos => 'PEDIDOS',
      NpcMenu.regalar => 'REGALAR',
      NpcMenu.casa => 'CASA',
    };
    final Widget body = switch (menu) {
      NpcMenu.comprar => _shopView(c, n, tier, p, inBiome: !home),
      NpcMenu.encargos => _grid(questCells(c, n, r, p), 'Nada por ahora.'),
      NpcMenu.pedidos => _grid(_requests(c, n, r, p, town, home: home),
          'No pidió nada por ahora.'),
      NpcMenu.regalar =>
        _grid(_gifts(c, n, p), 'No tenés nada de su bioma para regalarle.'),
      NpcMenu.casa => _grid(_house(c, n, r, p, town, home: home),
          'Primero invitalo al pueblo.'),
    };
    return PanelFrame(
      key: const ValueKey('panel-biome-npc'),
      title: '${n.name.toUpperCase()} · ${n.role.label.toUpperCase()} · $title',
      width: 1000,
      onClose: back,
      header: _status(n, r, p, shop: menu == NpcMenu.comprar),
      leading: [
        PanelButton('VOLVER',
            key: const ValueKey('npc-back'), onPressed: back),
      ],
      actions: [
        PanelButton('ADIÓS',
            key: const ValueKey('npc-close'), onPressed: c.closePanel),
      ],
      child: KeyedSubtree(key: ValueKey('npc-menu-${menu.name}'), child: body),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: EdgeInsets.symmetric(vertical: DsSpace.xs / 2),
        child: Row(children: [
          Expanded(
              child: Text(k, style: DsText.detail(DsColors.textSecondary))),
          Text(v, style: DsText.body(DsColors.text)),
        ]),
      );

  Widget _grid(List<LifeItemCellData> cells, String empty) => LifeItemGrid(
      groups: [LifeItemGroup(null, cells)], empty: empty);

  /// Tienda: grilla de mercancía (ícono, nombre, precio, cuántos tenés) y
  /// el detalle a la derecha con cantidad y COMPRAR.
  Widget _shopView(
      SessionController c, BiomeNpcDef n, int tier, PlayerProfile? p,
      {required bool inBiome}) {
    final f = p?.life.farm;
    final gold = p?.credits ?? 0;
    final goods = [
      for (final e in ResidentRules.stock(n, tier, home: inBiome).entries)
        if (kCrops[e.key] case final s?) (s, e.value),
    ];
    if (goods.isEmpty) {
      return Text('No vende nada todavía.',
          style: DsText.detail(DsColors.textSecondary));
    }
    final sel = goods.where((g) => g.$1.id == _sel).firstOrNull ?? goods.first;
    final (s, price) = sel;
    final maxQ = price <= 0 ? 1 : (gold ~/ price).clamp(1, 99);
    final qty = _qty.clamp(1, maxQ);
    final owned = f?.seedCount(s.id) ?? 0;
    return SizedBox(
      height: 340,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: GridView.extent(
              maxCrossAxisExtent: 300,
              mainAxisExtent: 64,
              crossAxisSpacing: DsSpace.sm,
              mainAxisSpacing: DsSpace.sm,
              children: [
                for (final (g, pr) in goods)
                  DsGoodsCell(
                    key: ValueKey('npc-seed-${g.id}'),
                    icon: LifeIcon('semilla_${g.id}', LifeIconKind.semilla,
                        size: 32),
                    name: g.seedName,
                    nameColor: fishRarityColor(g.rarity),
                    price: '$pr oro',
                    owned: f?.seedCount(g.id) ?? 0,
                    selected: g.id == s.id,
                    affordable: gold >= pr,
                    onTap: () => setState(() {
                      _sel = g.id;
                      _qty = 1;
                    }),
                  ),
              ],
            ),
          ),
          SizedBox(width: DsSpace.md),
          Container(
            width: 320,
            padding: EdgeInsets.all(DsSpace.md),
            decoration: BoxDecoration(
                color: DsColors.surfaceSunken,
                border: Border.all(color: DsColors.border)),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    LifeIcon('semilla_${s.id}', LifeIconKind.semilla,
                        size: 48),
                    SizedBox(width: DsSpace.sm),
                    Expanded(
                      child: Text(s.seedName,
                          style: DsText.title(fishRarityColor(s.rarity))),
                    ),
                  ]),
                  SizedBox(height: DsSpace.sm),
                  Wrap(spacing: DsSpace.xs, children: [
                    const DsTag('SEMILLA', color: DsColors.textSecondary),
                    DsTag(s.rarity.label.toUpperCase(),
                        color: fishRarityColor(s.rarity)),
                  ]),
                  if (s.lore.isNotEmpty) ...[
                    SizedBox(height: DsSpace.sm),
                    Text(s.lore,
                        softWrap: true,
                        style: DsText.detail(DsColors.textSecondary)),
                  ],
                  SizedBox(height: DsSpace.sm),
                  _kv('Crece en', '${(s.growSec / 60).round()} min'),
                  _kv('Tenés', '$owned'),
                  _kv('Precio', '$price oro c/u'),
                  SizedBox(height: DsSpace.md),
                  Row(children: [
                    DsQuantity(
                        value: qty,
                        max: maxQ,
                        onChanged: (v) => setState(() => _qty = v)),
                    SizedBox(width: DsSpace.sm),
                    Text('Total ${price * qty}',
                        key: const ValueKey('npc-shop-total'),
                        style: DsText.body(gold >= price * qty
                            ? DsColors.reward
                            : DsColors.danger)),
                  ]),
                  SizedBox(height: DsSpace.sm),
                  DsButton('COMPRAR',
                      key: ValueKey('npc-seed-buy-${s.id}'),
                      kind: DsButtonKind.primary,
                      onPressed: gold >= price * qty
                          ? () => c.buySeed(s.id, qty)
                          : null),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
              trackButton(c, p, n.id, QuestTrackKind.pedido),
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
