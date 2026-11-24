import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../core/i18n/strings.dart';
import '../../../../game_engine/data/npc_talk_catalog.dart';
import '../../../../game_engine/models/world_save.dart';
import '../../../../game_engine/rules/npc_talk_rules.dart';

/// The fixed behaviours a topic can trigger (npc_editor.md § 3.3). The
/// screen that hosts the talk says why an action is not possible now
/// ([why], `null` = possible) and runs it ([run]).
class TalkActions {
  const TalkActions({required this.why, required this.run});

  /// Reason the action cannot run now (or `null`). Actions the screen
  /// does not support return a reason and are hidden.
  final String? Function(TalkAction a) why;
  final void Function(TalkAction a) run;

  /// No action supported (the topic is hidden).
  static final none = TalkActions(why: (_) => '', run: (_) {});
}

/// HABLAR dentro del cuadro de diálogo (overworld_biomes.md § 12): el
/// menú cambia a los temas abiertos; elegir uno muestra sus frases y, si
/// tiene, sus sub-temas. Lo usan el habitante y el arraigado por igual;
/// el estado vive en el `State` de su pantalla.
class NpcTalk {
  NpcTalk(this.npc);

  final String npc;
  bool active = false;

  /// Dialogue node stack: each pushed topic is a node whose line is the
  /// NPC's answer and whose options are its sub-topics plus VOLVER.
  /// VOLVER pops back to the previous menu.
  final List<TalkTopic> _path = [];

  /// Topic ids already asked: dimmed in their menu, still selectable.
  final Set<String> _asked = {};
  String? said;

  /// Saludo al abrir (uno al azar del catálogo, más [extra]).
  static String greet(String npc, {List<LocalizedText> extra = const []}) =>
      NpcTalkRules.greeting(npc, math.Random(), extra: extra);

  /// Texto a mostrar ([fallback] si no está hablando).
  String text(String fallback) => active ? (said ?? fallback) : fallback;

  /// La opción HABLAR del menú principal.
  DsChoice entry(TownState s, VoidCallback refresh,
      {required bool inTown, required Strings strings}) {
    final none = NpcTalkRules.topics(s, npc, inTown: inTown).isEmpty;
    return DsChoice(strings.t('ui.town.npc.talk'),
        key: const ValueKey('npc-choice-hablar'),
        reason: none ? strings.t('ui.town.npc.talk_nothing') : null,
        onSelected: none
            ? null
            : () {
                active = true;
                _path.clear();
                _asked.clear();
                said = strings.t('ui.town.npc.talk_prompt');
                refresh();
              });
  }

  /// Las opciones mientras habla: temas (o sub-temas) y VOLVER. A topic
  /// with an action runs it through [actions] (hidden when the screen
  /// does not support it).
  List<DsChoice> choices(TownState s, VoidCallback refresh,
      {required bool inTown, required Strings strings, TalkActions? actions}) {
    final acts = actions ?? TalkActions.none;
    final list = _path.isEmpty
        ? NpcTalkRules.topics(s, npc, inTown: inTown)
        : _path.last.sub;
    final more =
        _path.isEmpty && NpcTalkRules.locked(s, npc, inTown: inTown) > 0;
    return [
      for (final t in list)
        if (t.action == TalkAction.none)
          DsChoice(t.label.text,
              key: ValueKey('npc-topic-${t.id}'),
              dimmed: _asked.contains(t.id), onSelected: () {
            said = t.lines.map((l) => l.text).join(' ');
            _asked.add(t.id);
            _path.add(t);
            refresh();
          })
        else if (acts.why(t.action) case final why when why != '')
          DsChoice(t.label.text,
              key: ValueKey('npc-topic-${t.id}'),
              reason: why,
              onSelected: why != null
                  ? null
                  : () {
                      active = false;
                      said = null;
                      _path.clear();
                      acts.run(t.action);
                      refresh();
                    }),
      if (more)
        DsChoice('…',
            key: const ValueKey('npc-topic-more'),
            reason: strings.t('ui.town.npc.talk_more')),
      DsChoice(strings.t('ui.town.npc.talk_back'),
          key: const ValueKey('npc-topic-back'), onSelected: () {
        if (_path.isNotEmpty) {
          _path.removeLast();
          said = strings.t('ui.town.npc.talk_again');
        } else {
          active = false;
          said = null;
        }
        refresh();
      }),
    ];
  }
}
