import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../app/theme/panel_frame.dart';
import '../../../../game_engine/data/biomes_catalog.dart';
import '../../../../game_engine/data/renown_catalog.dart';
import '../../../../game_engine/data/world_events_catalog.dart';
import '../../../../game_engine/rules/renown_rules.dart';
import '../../../../game_engine/rules/world_event_rules.dart';
import '../session_controller.dart';
import '../session_view.dart';
import '../world_strings.dart';
import 'life_icon.dart';
import 'world_event_cells.dart';

/// A world event actor (world_events.md § 3.6, § 6). Visitors, wanderers
/// and caravans talk in the real dialogue box ([EventNpcDialogue]); an
/// echo rift shows its info panel with ENTRAR.
class WorldEventPanel extends StatelessWidget {
  const WorldEventPanel(
      {super.key, required this.view, required this.controller});

  final SessionView view;
  final SessionController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final a = c.worldEvent;
    final d = a == null ? null : kWorldEvents.def(a.def);
    if (a != null && d != null && d.isNpc) {
      return EventNpcDialogue(key: ValueKey('event-npc-${a.uid}'), c: c);
    }
    final cell = a == null ? null : worldEventCell(context, a, c.town);
    final rift = d?.category == WorldEventCategory.echoPortal;
    return PanelFrame(
      key: const ValueKey('panel-world-event'),
      title: d?.title.text.toUpperCase() ?? context.t('ui.town.journal.events'),
      width: 520,
      onClose: c.closePanel,
      actions: [
        if (a != null && rift)
          PanelButton(context.t('ui.town.events.enter'),
              key: const ValueKey('world-event-enter'),
              onPressed: () => c.enterRift(a.uid)),
        PanelButton(context.t('ui.town.events.close'),
            key: const ValueKey('world-event-close'), onPressed: c.closePanel),
      ],
      child: a == null || d == null || cell == null
          ? Text(context.t('ui.town.journal.no_events'), style: DsText.detail())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(d.notice.text,
                    key: const ValueKey('world-event-notice'),
                    softWrap: true,
                    style: DsText.body()),
                SizedBox(height: DsSpace.sm),
                Text(d.body.text, softWrap: true, style: DsText.body()),
                SizedBox(height: DsSpace.sm),
                for (final l in cell.detail.lines)
                  Text(l, softWrap: true, style: DsText.detail()),
              ],
            ),
    );
  }
}

/// The dialogue of an event NPC (§ 3.6): greeting (or the renown
/// recognition), topics as a node stack with VOLVER (ui_minimal.md
/// § 10.1) and its 1–2 actions. Place and days left go in the caption.
class EventNpcDialogue extends StatefulWidget {
  const EventNpcDialogue({super.key, required this.c});
  final SessionController c;

  @override
  State<EventNpcDialogue> createState() => _EventNpcDialogueState();
}

class _EventNpcDialogueState extends State<EventNpcDialogue> {
  /// The NPC's current answer (`null` = the greeting, root menu).
  String? _said;

  /// A duel waits for confirmation.
  bool _duelAsk = false;
  final Set<String> _asked = {};

  void _back() => setState(() {
        _said = null;
        _duelAsk = false;
      });

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final s = worldStrings(context);
    final a = c.worldEvent;
    final d = a == null ? null : kWorldEvents.def(a.def);
    if (a == null || d == null) return const SizedBox.shrink();
    // Recognition (renown_town_growth.md § 4.2) as the greeting.
    final who = switch (d.category) {
      WorldEventCategory.visitor => RecognitionWho.visitor,
      WorldEventCategory.overworldNpc => RecognitionWho.wanderer,
      _ => RecognitionWho.caravan,
    };
    final known = RenownRules.recognition(who, RenownRules.score(c.town));
    final greeting = known?.text.text ??
        (d.greeting.text.trim().isEmpty ? d.notice.text : d.greeting.text);
    final caption = '${biomeDef(a.biome)?.name ?? a.biome} · '
        '${s.t('ui.town.events.days_left', {'n': a.daysLeft(c.town.sky.day)})}';
    final back = DsChoice(s.t('ui.town.npc.talk_back'),
        key: const ValueKey('event-npc-back'), onSelected: _back);
    List<DsChoice> root() => [
          for (final t in d.topics)
            DsChoice(t.label.text,
                key: ValueKey('event-npc-topic-${t.id}'),
                dimmed: _asked.contains(t.id),
                onSelected: () => setState(() {
                      _asked.add(t.id);
                      _said = t.line.text;
                    })),
          for (var i = 0; i < d.actions.length; i++) _action(c, s, a, d, i),
          DsChoice(s.t('ui.town.npc.bye'),
              key: const ValueKey('event-npc-bye'), onSelected: c.closePanel),
        ];
    final choices = _said == null
        ? root()
        : _duelAsk
            ? [
                DsChoice(s.t('ui.town.events.duel_go'),
                    key: const ValueKey('event-npc-duel-go'),
                    onSelected: () => c.enterRift(a.uid)),
                back,
              ]
            : [back];
    return Align(
      key: const ValueKey('panel-world-event'),
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.all(DsSpace.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: DsDialogueBox(
            portrait: LifeIcon(d.sprite, LifeIconKind.herramienta,
                size: DsDialogueBox.portraitSize),
            name: d.title.text,
            role: caption,
            text: _said ?? greeting,
            onCancel: _said == null ? c.closePanel : _back,
            skipLabel: s.t('ui.town.npc.skip'),
            choices: choices,
          ),
        ),
      ),
    );
  }

  DsChoice _action(SessionController c, Strings s, ActiveWorldEvent a,
      WorldEventDef d, int i) {
    final act = d.actions[i];
    final done =
        WorldEventRules.actionDone(c.town.events, a, d, i, c.localId);
    final label = done
        ? '${act.label.text} ${s.t('ui.town.events.done')}'
        : act.label.text;
    final key = ValueKey('event-npc-action-${act.kind.name}');
    switch (act.kind) {
      case EventActionKind.trade:
        return DsChoice(label,
            key: key, onSelected: () => c.openPanel(WorldPanel.trader));
      case EventActionKind.duel:
        if (WorldEventRules.duel(d, a.biome) == null) {
          return DsChoice(label,
              key: key, reason: s.t('ui.town.events.duel_none'));
        }
        if (done) {
          return DsChoice(label,
              key: key, dimmed: true, onSelected: () {
            setState(() => _said = act.line.text);
          });
        }
        return DsChoice(label, key: key, onSelected: () {
          setState(() {
            _said = act.line.text;
            _duelAsk = true;
          });
        });
      case EventActionKind.gift || EventActionKind.rumor:
        return DsChoice(label, key: key, dimmed: done, onSelected: () {
          if (!done) c.eventNpcAct(a.uid, i);
          setState(() => _said = act.line.text);
        });
    }
  }
}
