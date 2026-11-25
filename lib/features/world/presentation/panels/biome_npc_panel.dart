import '../../../inventory/domain/item_names.dart';
import '../../domain/town_names.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../app/theme/panel_frame.dart';
import '../../../../game_engine/data/renown_catalog.dart';
import '../../../../game_engine/rules/renown_rules.dart';
import '../../../../game_engine/data/biomes_catalog.dart';
import '../../../../game_engine/data/cooking_catalog.dart' show kMeals;
import '../../../../game_engine/data/fishing_catalog.dart';
import '../../../../game_engine/data/npc_talk_catalog.dart';
import '../../../../game_engine/models/player_profile.dart';
import '../../../../game_engine/models/session_action.dart' show TownOp;
import '../../../../game_engine/models/world_save.dart';
import '../../../../game_engine/models/item.dart' show Rarity;
import '../../../../core/procedural/item_icons.dart' show procKeyForType;
import '../../../inventory/presentation/item_widgets.dart'
    show PixelIcon, RarityColors, iconKeyForType;
import '../../../../game_engine/rules/farming_rules.dart';
import '../../../../game_engine/rules/fishing_rules.dart';
import '../../../../game_engine/rules/helper_rules.dart';
import '../../../../game_engine/rules/npc_talk_rules.dart';
import '../../../../game_engine/rules/quest_track_rules.dart';
import '../../../../game_engine/rules/resident_rules.dart';
import '../../../../game_engine/rules/sky_rules.dart';
import '../session_controller.dart';
import '../session_view.dart';
import 'cooking_view.dart' show mealTierText;
import 'fishing_widgets.dart' show fishRarityColor;
import 'life_icon.dart';
import 'life_item_grid.dart';
import 'npc_talk.dart';
import 'seed_text.dart';
import '../world_strings.dart';

/// Nombre de un producto, cultivo o pez.
String residentItemName(String id) =>
    kMeals[id]?.text ?? kFish[id]?.text ?? kCrops[id]?.text ?? id;

/// Ícono de un producto, cultivo o pez (o del tipo de arma de una orden
/// de arma forjada).
Widget residentItemIcon(String id) => ResidentRules.isForgeOrder(id)
    ? _forgeOrderIcon(id)
    : kMeals.containsKey(id)
    ? LifeIcon('comida_$id', LifeIconKind.cosecha, size: 32)
    : kFish.containsKey(id)
        ? LifeIcon(id, LifeIconKind.pescado, size: 32)
        : LifeIcon('cosecha_$id', LifeIconKind.cosecha, size: 32);

Widget _forgeOrderIcon(String id, [int q = 0]) {
  final type = ResidentRules.parseForgeOrder(id)?.$1 ?? 'espada';
  return PixelIcon(iconKeyForType(type),
      accent: RarityColors.of(Rarity.values[q]),
      procKey: procKeyForType(type),
      size: 32);
}

/// Localized name of a weapon type (`ui.town.npc.wtype.<key>`).
String weaponTypeText(Strings s, String type) => s.t(
    'ui.town.npc.wtype.${type.replaceAll('+', '_').replaceAll('á', 'a')}');

/// Casilla de una orden de arma forjada (mining_smithing.md § 2.2): tipo,
/// rareza y nivel de objeto mínimos; si varias armas sirven, un botón por
/// cada una para elegir cuál entregar (nunca la equipada).
LifeItemCellData _forgeOrderCell(Strings s, SessionController c,
    BiomeNpcDef n, ResidentState r, PlayerProfile? p,
    {required bool home}) {
  final o = r.order!;
  final (type, il) = ResidentRules.parseForgeOrder(o) ?? ('espada', 1);
  final q = Rarity.values[r.orderQ.clamp(0, Rarity.values.length - 1)];
  final matches =
      p == null ? const [] : ResidentRules.forgeOrderMatches(p, o, r.orderQ);
  final w = ResidentRules.orderReward(r);
  final tName = weaponTypeText(s, type);
  return LifeItemCellData(
    id: 'order-${n.id}',
    icon: _forgeOrderIcon(o, r.orderQ),
    border: DsColors.reward,
    search: tName,
    count: 1,
    caption: s.t('ui.town.npc.order'),
    detail: LifeItemDetail(
      name: s.t('ui.town.npc.order_name', {'name': n.name}),
      nameColor: DsColors.textTitle,
      tags: [
        (s.t('ui.town.npc.order'), DsColors.reward),
        (s.t('ui.town.npc.forge_tag'), DsColors.textSecondary),
      ],
      lines: [
        s.t('ui.town.npc.forge_line',
            {'type': tName, 'q': q.text, 'il': il}),
        s.t('ui.town.npc.have', {'n': matches.length}),
        s.t('ui.town.npc.order_xp', {'n': w.xp}),
        s.t('ui.town.npc.order_gold', {'gold': w.gold, 'rep': w.rep}),
        s.t('ui.town.npc.forge_xp',
            {'n': ResidentRules.forgeOrderXp(r.orderQ)}),
        if (w.point) s.t('ui.town.npc.order_point'),
        s.t('ui.town.npc.delivered', {'n': r.orders}),
      ],
      description: s.t('ui.town.npc.forge_desc'),
      actions: [
        trackButton(c, p, n.id, QuestTrackKind.orden),
        if (matches.length <= 1)
          DsButton(s.t('ui.town.npc.deliver_order'),
              key: ValueKey('order-deliver-${n.id}'),
              size: DsButtonSize.compact,
              onPressed: home && matches.isNotEmpty
                  ? () => c.residentOp(TownOp.order, n.id,
                      target: matches.first.uid)
                  : null)
        else
          for (final m in matches)
            DsButton(
                s.t('ui.town.npc.forge_pick', {
                  'q': m.rarity.text,
                  'il': m.itemLevel,
                }),
                key: ValueKey('order-deliver-${n.id}-${m.uid}'),
                size: DsButtonSize.compact,
                onPressed: home
                    ? () => c.residentOp(TownOp.order, n.id, target: m.uid)
                    : null),
      ],
    ),
  );
}

/// Botón SEGUIR / DEJAR DE SEGUIR de un encargo activo (roles.md § 8).
Widget trackButton(
    SessionController c, PlayerProfile? p, String npc, QuestTrackKind kind) {
  final key = QuestTrackRules.trackKey(kind, npc);
  final on = p?.tracked.contains(key) ?? false;
  final full = (p?.tracked.length ?? 0) >= QuestTrackRules.maxTracked;
  return Builder(builder: (context) {
    final s = worldStrings(context);
    return DsButton(on ? s.t('ui.town.npc.untrack') : s.t('ui.town.npc.track'),
        key: ValueKey('track-$key'),
        size: DsButtonSize.compact,
        selected: on,
        tooltip: !on && full
            ? s.t('ui.town.npc.track_full', {'n': QuestTrackRules.maxTracked})
            : null,
        onPressed:
            p == null || (!on && full) ? null : () => c.trackQuest(npc, key));
  });
}

/// Casillas de la cadena de encargos de [n] (también en el registro):
/// solo los que ya pidió (cumplidos + el activo). Los pasos futuros no se
/// listan nunca; el próximo lo cuenta él en el diálogo.
List<LifeItemCellData> questCells(Strings s, SessionController c, BiomeNpcDef n,
    ResidentState r, PlayerProfile? p) {
  final chain = kResidentQuests[n.id] ?? const <QuestStepDef>[];
  // El activo aparece recién cuando él lo pidió en el diálogo.
  final asked = p == null || r.progress > 0 || QuestTrackRules.questSeen(p, r);
  final upTo = (r.quest + (asked ? 1 : 0)).clamp(0, chain.length);
  return [
    for (var i = 0; i < upTo; i++) _questCell(s, c, n, r, p, chain, i),
  ];
}

LifeItemCellData _questCell(Strings s, SessionController c, BiomeNpcDef n,
    ResidentState r, PlayerProfile? p, List<QuestStepDef> chain, int i) {
  final q = chain[i];
  final done = i < r.quest, now = i == r.quest;
  final have = p == null ? 0 : ResidentRules.questHave(p, q);
  final what = switch (q.kind) {
    QuestKind.mazmorra => s.t('ui.town.npc.quest_zone', {'zone': q.target}),
    QuestKind.elite => s.t('ui.town.npc.quest_elite', {'zone': q.target}),
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
    caption: done
        ? s.t('ui.town.npc.done')
        : (now ? '${r.progress}/${q.n}' : '${i + 1}'),
    detail: LifeItemDetail(
      name: s.t('ui.town.npc.quest_name', {'name': n.name, 'n': i + 1}),
      nameColor: DsColors.textTitle,
      tags: [
        (q.kind.label.toUpperCase(), DsColors.textSecondary),
        if (done) (s.t('ui.town.npc.fulfilled'), DsColors.success),
      ],
      lines: [
        what,
        if (now && q.kind.delivered) s.t('ui.town.npc.have', {'n': have}),
        if (now) s.t('ui.town.npc.progress', {'n': r.progress, 'goal': q.n}),
        s.t('ui.town.npc.quest_reward', {'gold': q.gold, 'rep': q.rep}),
        if (relic != null) s.t('ui.town.npc.unique_item', {'name': relic.name}),
      ],
      description: q.text,
      actions: [
        if (now) trackButton(c, p, n.id, QuestTrackKind.encargo),
        if (now && q.kind.delivered)
          DsButton(s.t('ui.town.npc.turn_in'),
              key: ValueKey('quest-turnin-${n.id}'),
              size: DsButtonSize.compact,
              onPressed:
                  have > 0 ? () => c.residentOp(TownOp.turnIn, n.id) : null),
      ],
    ),
  );
}

/// Casilla de la orden de entrega de [r] (§ 10.5), o `null`.
LifeItemCellData? orderCell(Strings s, SessionController c, BiomeNpcDef n,
    ResidentState r, PlayerProfile? p,
    {required bool home}) {
  final o = r.order;
  if (o == null) return null;
  if (ResidentRules.isForgeOrder(o)) {
    return _forgeOrderCell(s, c, n, r, p, home: home);
  }
  final have = p == null ? 0 : ResidentRules.orderHave(p, o, r.orderQ);
  final w = ResidentRules.orderReward(r);
  final q = CropQuality.values[r.orderQ];
  final cm = ResidentRules.orderCm(o, r.orderQ);
  final fish = kFish.containsKey(o);
  final meal = kMeals.containsKey(o);
  return LifeItemCellData(
    id: 'order-${n.id}',
    icon: residentItemIcon(o),
    border: DsColors.reward,
    search: residentItemName(o),
    count: r.orderN,
    caption: s.t('ui.town.npc.order'),
    detail: LifeItemDetail(
      name: s.t('ui.town.npc.order_name', {'name': n.name}),
      nameColor: DsColors.textTitle,
      tags: [
        (s.t('ui.town.npc.order'), DsColors.reward),
        if (r.orderQ > 0)
          (
            fish
                ? s.t('ui.town.npc.from_cm', {'cm': cm})
                : meal
                    ? mealTierText(q).toUpperCase()
                    : q.label.toUpperCase(),
            DsColors.textSecondary
          ),
      ],
      lines: [
        r.orderQ <= 0
            ? '${r.orderN} × ${residentItemName(o)}'
            : fish
                ? s.t('ui.town.npc.order_line_cm',
                    {'n': r.orderN, 'item': residentItemName(o), 'cm': cm})
                : s.t('ui.town.npc.order_line_q', {
                    'n': r.orderN,
                    'item': residentItemName(o),
                    'q': meal ? mealTierText(q) : q.label
                  }),
        if (fish && cm > 0)
          s.t('ui.town.npc.record', {'cm': p?.life.log[o] ?? 0}),
        s.t('ui.town.npc.have', {'n': have}),
        s.t('ui.town.npc.order_xp', {'n': w.xp}),
        s.t('ui.town.npc.order_gold', {'gold': w.gold, 'rep': w.rep}),
        if (w.point) s.t('ui.town.npc.order_point'),
        s.t('ui.town.npc.delivered', {'n': r.orders}),
      ],
      description: s.t('ui.town.npc.order_desc'),
      actions: [
        trackButton(c, p, n.id, QuestTrackKind.orden),
        DsButton(s.t('ui.town.npc.deliver_order'),
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
/// ui_minimal.md § 10): primero el cuadro de diálogo abajo (retrato,
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
  Strings get _s => worldStrings(context);

  NpcMenu? _menu;
  String? _sel;
  int _qty = 1;

  /// Lo que dijo al abrir el diálogo (no cambia al marcarlo visto).
  String? _spoken;
  String? _spokenTo;
  NpcTalk? _talk;

  /// A town event this resident offers in the dialogue
  /// (renown_town_growth.md § 6): proposing it, or signing up on its day.
  TownEventDef? _offer;
  bool _offerSignup = false;

  /// Aceptó la invitación (overworld_biomes.md § 10.1): dice que sí y, al
  /// cerrar el diálogo, se manda la invitación y sale caminando.
  /// Id del habitante que aceptó (o `null`).
  String? _acceptedBy;
  bool get _accepted => _acceptedBy != null;

  /// Manda la invitación aceptada (una vez).
  void _sendInvite() {
    final id = _acceptedBy;
    if (id == null) return;
    _acceptedBy = null;
    widget.controller.residentOp(TownOp.invite, id);
  }

  /// Cierra el diálogo; si aceptó, recién ahí se muda.
  void _close(SessionController c, BiomeNpcDef n) {
    _sendInvite();
    c.closePanel();
  }

  @override
  void dispose() {
    // Cerrado por otro lado (Esc, cambio de panel): igual se muda.
    _sendInvite();
    super.dispose();
  }

  /// Lo que dice al hablarle (roles.md § 8.4): si tiene un paso nuevo de
  /// su cadena que todavía no te contó, lo pide con sus palabras; si no,
  /// su frase del día. Suma el pedido o la orden nuevos.
  String _line(
      SessionController c, BiomeNpcDef n, ResidentState r, PlayerProfile? p) {
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
        NpcTalk.greet(n.id, extra: [
          ...?npcTalk(n.id)?.ambient,
          // Recognition (renown_town_growth.md § 4.2).
          if (RenownRules.recognition(n.id, RenownRules.score(c.town))
              case final l?)
            l.text,
        ]),
      if (fresh && r.request != null)
        _s.t('ui.town.npc.line_request',
            {'what': r.request!.label.toLowerCase()}),
      if (fresh && r.order != null)
        _s.t('ui.town.npc.line_order',
            {'n': r.orderN, 'item': residentItemName(r.order!)}),
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
      // De noche, fuera de su casa: dice por qué salió (§ 10.1.1).
      if (home && SkyRules.isNight(town.sky)) {
        if (ResidentRules.nightOuting(town, n.id) case final o?) {
          _spoken = NpcTalkRules.nightLine(n.id, o.id) ?? _spoken;
        }
      }
      _talk = NpcTalk(n.id);
      _sendInvite();
      // Recién le asignaron casa: agradece (frase según la hora).
      if (c.thanksNpc == n.id) {
        c.thanksNpc = null;
        _spoken =
            NpcTalkRules.houseThanks(n.id, night: SkyRules.isNight(town.sky)) ??
                _spoken;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => c.npcTalked(n.id));
      if (p != null && !QuestTrackRules.seen(p, r)) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => c.markNpcSeen(n.id));
      }
    }
    final menu = _menu;
    if (menu == null) return _dialogue(c, n, r, p, town, home: home);
    return _window(c, n, r, p, town, menu, home: home);
  }

  Widget _portrait(BiomeNpcDef n) =>
      LifeIcon(n.portrait, LifeIconKind.herramienta,
          size: DsDialogueBox.portraitSize);

  Widget _dialogue(SessionController c, BiomeNpcDef n, ResidentState r,
      PlayerProfile? p, TownState town,
      {required bool home}) {
    final tier = ResidentRules.tier(r);
    final inviteWhy = ResidentRules.cannotInvite(town, n.id);
    final houseWhy = home && r.invited && town.houseOf(n.id) == null
        ? (ResidentRules.cannotAssignFree(town, n.id) != null
            ? _s.t('ui.town.npc.no_free_house')
            : c.cannotEditTown)
        : null;
    final offerHouse = home && r.invited && town.houseOf(n.id) == null;
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
    final talk = _talk ??= NpcTalk(n.id);
    void refresh() => setState(() {});
    // Town events (renown_town_growth.md § 6): propose, or sign up today.
    final day = town.sky.day;
    final proposals =
        home ? RenownRules.proposals(town, n.id, day) : const <TownEventDef>[];
    final live = home ? RenownRules.live(town, n.id, day) : null;
    final offer = _offer;
    // Topic actions (npc_editor.md § 3.3): same rules as the menu.
    final actions = TalkActions(
      why: (a) => switch (a) {
        TalkAction.trade =>
          stock.isEmpty ? _s.t('ui.town.npc.sells_nothing') : null,
        TalkAction.house =>
          offerHouse ? houseWhy : _s.t('ui.town.npc.invite_first'),
        TalkAction.invite => offerHouse || r.invited ? '' : inviteWhy,
        TalkAction.none => '',
      },
      run: (a) {
        switch (a) {
          case TalkAction.trade:
            open(NpcMenu.comprar);
          case TalkAction.house:
            c.enterHousePick(n.id);
          case TalkAction.invite:
            setState(() => _acceptedBy = n.id);
          case TalkAction.none:
        }
      },
    );
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
            text: _accepted
                ? (NpcTalkRules.inviteAccept(n.id) ?? '')
                : offer != null
                    ? (_offerSignup ? offer.signup.text : offer.propose.text)
                    : talk.text(_spoken ?? c.npcLine(n)),
            onCancel: () => _close(c, n),
            skipLabel: _s.t('ui.town.npc.skip'),
            choices: _accepted
                ? [
                    DsChoice(_s.t('ui.town.npc.bye'),
                        key: const ValueKey('npc-close'),
                        onSelected: () => _close(c, n)),
                  ]
                : offer != null
                    ? [
                        DsChoice(
                            _offerSignup
                                ? _s.t('ui.town.npc.event_signup')
                                : _s.t('ui.town.npc.event_accept'),
                            key: const ValueKey('npc-event-yes'), onSelected: () {
                          setState(() => _offer = null);
                          if (_offerSignup) {
                            c.signUpTourney(offer.id);
                          } else {
                            c.scheduleTownEvent(offer.id);
                          }
                        }),
                        DsChoice(_s.t('ui.town.npc.event_back'),
                            key: const ValueKey('npc-event-no'),
                            onSelected: () => setState(() => _offer = null)),
                      ]
                    : talk.active
                    ? talk.choices(town, refresh,
                        inTown: home, strings: _s, actions: actions)
                    : [
                        talk.entry(town, refresh, inTown: home, strings: _s),
                        if (live != null &&
                            live.kind == TownEventKind.tournament)
                          DsChoice(
                              _s.t('ui.town.npc.event_today',
                                  {'title': live.title.text}),
                              key: ValueKey('npc-event-live-${live.id}'),
                              onSelected: () => setState(() {
                                    _offer = live;
                                    _offerSignup = true;
                                  })),
                        for (final d in proposals)
                          DsChoice(d.title.text,
                              key: ValueKey('npc-event-${d.id}'),
                              onSelected: () => setState(() {
                                    _offer = d;
                                    _offerSignup = false;
                                  })),
                        opt(
                            NpcMenu.comprar,
                            _s.t('ui.town.npc.menu_buy'),
                            stock.isEmpty
                                ? _s.t('ui.town.npc.sells_nothing')
                                : null),
                        opt(
                            NpcMenu.encargos,
                            _s.t('ui.town.npc.menu_quests'),
                            questCells(_s, c, n, r, p).isEmpty
                                ? _s.t('ui.town.npc.asked_nothing')
                                : null),
                        opt(
                            NpcMenu.pedidos,
                            _s.t('ui.town.npc.menu_requests'),
                            r.invited
                                ? null
                                : _s.t('ui.town.npc.requests_when_living')),
                        opt(
                            NpcMenu.regalar,
                            _s.t('ui.town.npc.menu_gift'),
                            _gifts(c, n, p).isEmpty
                                ? _s.t('ui.town.npc.nothing_from_biome')
                                : null),
                        opt(
                            NpcMenu.casa,
                            _s.t('ui.town.npc.menu_house'),
                            r.invited
                                ? null
                                : _s.t('ui.town.npc.invite_first')),
                        if (offerHouse)
                          DsChoice(_s.t('ui.town.npc.assign_house'),
                              key: const ValueKey('npc-assign-house'),
                              reason: houseWhy,
                              onSelected: houseWhy == null
                                  ? () => c.enterHousePick(n.id)
                                  : null)
                        else
                          DsChoice(_s.t('ui.town.npc.invite'),
                              key: const ValueKey('npc-invite'),
                              reason: inviteWhy,
                              onSelected: inviteWhy == null
                                  ? () => setState(() => _acceptedBy = n.id)
                                  : null),
                        DsChoice(_s.t('ui.town.npc.bye'),
                            key: const ValueKey('npc-close'),
                            onSelected: c.closePanel),
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
      {required bool shop, required bool inTown}) {
    final tier = ResidentRules.tier(r);
    final next = ResidentRules.nextTier(r);
    final goal = _repGoal(r);
    return DsStatusStrip([
      DsStatusCell(
          _s.t('ui.town.npc.rep'),
          key: const ValueKey('npc-rep'),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_s.t('ui.town.npc.rep_value', {'n': r.rep, 'goal': goal}),
                  style: DsText.body(DsColors.mp)),
              SizedBox(height: DsSpace.xs),
              DsMeter(r.rep, goal, color: DsColors.mp),
            ],
          )),
      // La etapa es de la vida en el pueblo: en su bioma no se muestra.
      if (inTown)
        DsStatusCell(
            _s.t('ui.town.npc.stage'),
            Text.rich(TextSpan(children: [
              TextSpan(
                  text: ResidentRules.stage(r).label,
                  style: DsText.body(DsColors.conditionReady)),
              TextSpan(
                  text:
                      '\n${r.invited ? _s.t('ui.town.npc.lives_in_town') : _s.t('ui.town.npc.in_biome')}',
                  style: DsText.detail(DsColors.textSecondary)),
              if (r.unhappy)
                TextSpan(
                    text: '\n${_s.t('ui.town.npc.unhappy')}',
                    style: DsText.detail(DsColors.danger)),
            ]))),
      DsStatusCell(
          _s.t('ui.town.npc.benefit_now'),
          key: const ValueKey('npc-benefit'),
          flex: 2,
          Text(
              tier < 0
                  ? _s.t('ui.town.npc.benefit_none')
                  : _s.t('ui.town.npc.benefit_level', {
                      'benefit': ResidentRules.benefitText(n, tier),
                      'n': tier
                    }),
              style: DsText.body(DsColors.success))),
      DsStatusCell(
          _s.t('ui.town.npc.next'),
          flex: 2,
          Text(
              next == null
                  ? _s.t('ui.town.npc.maxed')
                  : _s.t('ui.town.npc.benefit_level', {
                      'benefit': ResidentRules.benefitText(n, next),
                      'n': next
                    }),
              style: DsText.body(DsColors.reward))),
      if (shop)
        DsStatusCell(
            _s.t('ui.town.npc.your_gold'),
            key: const ValueKey('npc-gold'),
            Text((p?.credits ?? 0).toString(),
                style: DsText.body(DsColors.reward))),
    ]);
  }

  Widget _window(SessionController c, BiomeNpcDef n, ResidentState r,
      PlayerProfile? p, TownState town, NpcMenu menu,
      {required bool home}) {
    final tier = ResidentRules.tier(r);
    void back() => setState(() => _menu = null);
    final title = switch (menu) {
      NpcMenu.comprar => _s.t('ui.town.npc.title_shop'),
      NpcMenu.encargos => _s.t('ui.town.npc.title_quests'),
      NpcMenu.pedidos => _s.t('ui.town.npc.title_requests'),
      NpcMenu.regalar => _s.t('ui.town.npc.title_gift'),
      NpcMenu.casa => _s.t('ui.town.npc.title_house'),
    };
    final Widget body = switch (menu) {
      NpcMenu.comprar => _shopView(c, n, tier, p, inBiome: !home),
      NpcMenu.encargos =>
        _grid(questCells(_s, c, n, r, p), _s.t('ui.town.npc.nothing_yet')),
      NpcMenu.pedidos => _grid(_requests(c, n, r, p, town, home: home),
          _s.t('ui.town.npc.no_requests')),
      NpcMenu.regalar => _grid(_gifts(c, n, p), _s.t('ui.town.npc.no_gifts')),
      NpcMenu.casa => _grid(_house(c, n, r, p, town, home: home),
          _s.t('ui.town.npc.invite_first_dot')),
    };
    return PanelFrame(
      key: const ValueKey('panel-biome-npc'),
      title: '${n.name.toUpperCase()} · ${n.role.label.toUpperCase()} · $title',
      width: 1000,
      // Grid + detail use the whole body; the detail pins its actions.
      fill: true,
      onClose: back,
      header: _status(n, r, p,
          shop: menu == NpcMenu.comprar, inTown: home && r.invited),
      leading: [
        PanelButton(_s.t('ui.town.npc.back'),
            key: const ValueKey('npc-back'), onPressed: back),
      ],
      actions: [
        PanelButton(_s.t('ui.town.npc.bye_button'),
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

  Widget _grid(List<LifeItemCellData> cells, String empty) =>
      LifeItemGrid(groups: [LifeItemGroup(null, cells)], empty: empty);

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
      return Text(_s.t('ui.town.npc.sells_nothing_dot'),
          style: DsText.detail(DsColors.textSecondary));
    }
    final sel = goods.where((g) => g.$1.id == _sel).firstOrNull ?? goods.first;
    final (s, price) = sel;
    final maxQ = price <= 0 ? 1 : (gold ~/ price).clamp(1, 99);
    final qty = _qty.clamp(1, maxQ);
    final owned = f?.seedCount(s.id) ?? 0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Same cell as INVENTARIO; name and data in the hover card.
        Expanded(
          child: SingleChildScrollView(
            child: Wrap(
              spacing: LifeItemGrid.gap,
              runSpacing: LifeItemGrid.gap,
              children: [
                for (final (g, pr) in goods)
                  LifeItemCell(
                    key: ValueKey('npc-seed-${g.id}'),
                    selected: g.id == s.id,
                    onTap: () => setState(() {
                      _sel = g.id;
                      _qty = 1;
                    }),
                    data: LifeItemCellData(
                      id: 'npc-seed-cell-${g.id}',
                      icon: LifeIcon('semilla_${g.id}', LifeIconKind.semilla,
                          size: LifeItemGrid.iconSize),
                      border: fishRarityColor(g.rarity),
                      search: g.seedText,
                      count: (f?.seedCount(g.id) ?? 0) > 0
                          ? f!.seedCount(g.id)
                          : null,
                      detail: LifeItemDetail(
                        name: g.seedText,
                        nameColor: fishRarityColor(g.rarity),
                        tags: [
                          (_s.t('ui.town.npc.seed'), DsColors.textSecondary),
                          (
                            g.rarity.text.toUpperCase(),
                            fishRarityColor(g.rarity)
                          ),
                        ],
                        lines: [
                          ...seedInfoLines(context, g),
                          _s.t('ui.town.npc.gold_each', {'n': pr}),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        SizedBox(width: DsSpace.md),
        SizedBox(
          width: LifeItemGrid.detailWidth,
          child: DsDetailPane(
            key: const ValueKey('npc-shop-detail'),
            sunken: true,
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  LifeIcon('semilla_${s.id}', LifeIconKind.semilla, size: 48),
                  SizedBox(width: DsSpace.sm),
                  Expanded(
                    child: Text(s.seedText,
                        style: DsText.title(fishRarityColor(s.rarity))),
                  ),
                ]),
                SizedBox(height: DsSpace.sm),
                Wrap(spacing: DsSpace.xs, children: [
                  DsTag(_s.t('ui.town.npc.seed'),
                      color: DsColors.textSecondary),
                  DsTag(s.rarity.text.toUpperCase(),
                      color: fishRarityColor(s.rarity)),
                ]),
                if (s.lore.isNotEmpty) ...[
                  SizedBox(height: DsSpace.sm),
                  Text(s.lore,
                      softWrap: true,
                      style: DsText.detail(DsColors.textSecondary)),
                ],
                SizedBox(height: DsSpace.sm),
                _kv(
                    _s.t('ui.town.npc.grows_in'),
                    _s.t('ui.town.npc.minutes',
                        {'n': (s.growSec / 60).round()})),
                _kv(_s.t('ui.town.npc.owned'), owned.toString()),
                _kv(_s.t('ui.town.npc.price'),
                    _s.t('ui.town.npc.gold_each', {'n': price})),
              ],
            ),
            actions: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  DsQuantity(
                      value: qty,
                      max: maxQ,
                      onChanged: (v) => setState(() => _qty = v)),
                  SizedBox(width: DsSpace.sm),
                  Flexible(
                    child: Text(_s.t('ui.town.npc.total', {'n': price * qty}),
                        key: const ValueKey('npc-shop-total'),
                        style: DsText.body(gold >= price * qty
                            ? DsColors.reward
                            : DsColors.danger)),
                  ),
                ]),
                SizedBox(height: DsSpace.sm),
                DsButton(_s.t('ui.town.npc.buy'),
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
    );
  }

  List<LifeItemCellData> _requests(SessionController c, BiomeNpcDef n,
      ResidentState r, PlayerProfile? p, TownState town,
      {required bool home}) {
    final req = r.request;
    final why = ResidentRules.requestUnmet(town, n.id);
    return [
      if (orderCell(_s, c, n, r, p, home: home) case final o?) o,
      if (req != null)
        LifeItemCellData(
          id: 'request-${n.id}',
          icon: const LifeIcon('cofre_oficio', LifeIconKind.herramienta,
              size: 32),
          border: r.unhappy ? DsColors.danger : DsColors.selected,
          search: req.label,
          caption: _s.t('ui.town.npc.request'),
          detail: LifeItemDetail(
            name: req.label,
            nameColor: DsColors.textTitle,
            tags: [
              (_s.t('ui.town.npc.request'), DsColors.selected),
              if (r.unhappy) (_s.t('ui.town.npc.unhappy_tag'), DsColors.danger),
            ],
            lines: [
              _s.t('ui.town.npc.requested_day', {'day': r.requestDay}),
              _s.t('ui.town.npc.request_reward',
                  {'rep': ResidentRules.t.i('resRequestRep')}),
              if (why != null) why,
            ],
            description: r.unhappy
                ? _s.t('ui.town.npc.unhappy_desc')
                : _s.t('ui.town.npc.request_desc'),
            actions: [
              trackButton(c, p, n.id, QuestTrackKind.pedido),
              if (req != ResidentRequest.casa)
                DsButton(_s.t('ui.town.npc.fulfilled'),
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
      search: _s.t('ui.town.npc.commission_search'),
      caption: _s.t('ui.town.npc.forge'),
      detail: LifeItemDetail(
        name: _s.t('ui.town.npc.commission'),
        nameColor: DsColors.textTitle,
        tags: [(rr.label.toUpperCase(), DsColors.reward)],
        lines: [
          _s.t('ui.town.npc.commission_weapon', {
            'rarity': rr.label.toLowerCase(),
            'level': ResidentRules.commissionItemLevel(p.level)
          }),
          _s.t('ui.town.npc.cost_line', {
            'cost': HelperRules.costText(cost.cost),
            'n': cost.lootN,
            'item': residentItemName(cost.loot)
          }),
          _s.t('ui.town.npc.commission_rarity'),
          if (why != null) why,
        ],
        description: _s.t('ui.town.npc.commission_desc'),
        actions: [
          DsButton(_s.t('ui.town.npc.order_it'),
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
              tags: [(_s.t('ui.town.npc.gift'), DsColors.textSecondary)],
              lines: [
                _s.t('ui.town.npc.have', {'n': have}),
                _s.t('ui.town.npc.gift_rule'),
              ],
              actions: [
                DsButton(_s.t('ui.town.npc.gift_one'),
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
    final why = p == null
        ? _s.t('ui.town.npc.no_profile')
        : ResidentRules.cannotInvest(p, town, n.id);
    final relicId = kResidentQuests[n.id]?.last.reward;
    final relic = r.relic ? kResidentRelics[relicId] : null;
    return [
      LifeItemCellData(
        id: 'house-${n.id}',
        icon: LifeIcon('casa_${lv.clamp(1, 3)}', LifeIconKind.herramienta,
            size: 32),
        border: DsColors.border,
        search: _s.t('ui.town.npc.title_house'),
        caption: h == null
            ? _s.t('ui.town.npc.no_house_caps')
            : _s.t('ui.town.npc.level_caps', {'n': lv}),
        detail: LifeItemDetail(
          name: h == null
              ? _s.t('ui.town.npc.no_house')
              : _s.t('ui.town.npc.house_of', {'name': n.name}),
          nameColor: DsColors.textTitle,
          tags: [(_s.t('ui.town.npc.title_house'), DsColors.textSecondary)],
          lines: [
            if (h == null)
              _s.t('ui.town.npc.house_hint',
                  {'cost': HelperRules.costText(ResidentRules.placeCost())})
            else
              _s.t('ui.town.npc.level_of', {'n': lv, 'max': max}),
            if (h != null && cost != null)
              _s.t('ui.town.npc.upgrade_line', {
                'cost': HelperRules.costText(cost.cost),
                'n': cost.lootN,
                'item': residentItemName(cost.loot)
              }),
            if (h != null && why != null && cost != null) why,
            _s.t('ui.town.npc.house_levels'),
          ],
          actions: [
            if (h != null && cost != null)
              DsButton(_s.t('ui.town.npc.invest'),
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
          caption: _s.t('ui.town.npc.unique'),
          detail: LifeItemDetail(
            name: relic.name,
            nameColor: DsColors.reward,
            tags: [(_s.t('ui.town.npc.unique_tag'), DsColors.reward)],
            lines: [_s.t('ui.town.npc.relic_line')],
            description: relic.lore,
          ),
        ),
    ];
  }
}
