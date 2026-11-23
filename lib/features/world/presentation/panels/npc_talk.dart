import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../game_engine/data/npc_talk_catalog.dart';
import '../../../../game_engine/models/world_save.dart';
import '../../../../game_engine/rules/npc_talk_rules.dart';

/// HABLAR dentro del cuadro de diálogo (overworld_biomes.md § 12): el
/// menú cambia a los temas abiertos; elegir uno muestra sus frases y, si
/// tiene, sus sub-temas. Lo usan el habitante y el arraigado por igual;
/// el estado vive en el `State` de su pantalla.
class NpcTalk {
  NpcTalk(this.npc);

  final String npc;
  bool active = false;
  final List<TalkTopic> _path = [];
  String? said;

  /// Saludo al abrir (uno al azar del catálogo, más [extra]).
  static String greet(String npc, {List<String> extra = const []}) =>
      NpcTalkRules.greeting(npc, math.Random(), extra: extra);

  /// Texto a mostrar ([fallback] si no está hablando).
  String text(String fallback) => active ? (said ?? fallback) : fallback;

  /// La opción HABLAR del menú principal.
  DsChoice entry(TownState s, VoidCallback refresh, {required bool inTown}) {
    final none = NpcTalkRules.topics(s, npc, inTown: inTown).isEmpty;
    return DsChoice('Hablar',
        key: const ValueKey('npc-choice-hablar'),
        reason: none ? 'No tiene nada para contarte todavía' : null,
        onSelected: none
            ? null
            : () {
                active = true;
                _path.clear();
                said = '¿De qué querés hablar?';
                refresh();
              });
  }

  /// Las opciones mientras habla: temas (o sub-temas) y VOLVER.
  List<DsChoice> choices(TownState s, VoidCallback refresh,
      {required bool inTown}) {
    final list = _path.isEmpty
        ? NpcTalkRules.topics(s, npc, inTown: inTown)
        : _path.last.sub;
    final more =
        _path.isEmpty && NpcTalkRules.locked(s, npc, inTown: inTown) > 0;
    return [
      for (final t in list)
        DsChoice(t.label, key: ValueKey('npc-topic-${t.id}'), onSelected: () {
          said = t.lines.join(' ');
          if (t.sub.isNotEmpty) _path.add(t);
          refresh();
        }),
      if (more)
        const DsChoice('…',
            key: ValueKey('npc-topic-more'),
            reason: 'Volvé otro día: hay más para hablar'),
      DsChoice('Volver', key: const ValueKey('npc-topic-back'), onSelected: () {
        if (_path.isNotEmpty) {
          _path.removeLast();
          said = '¿Algo más?';
        } else {
          active = false;
          said = null;
        }
        refresh();
      }),
    ];
  }
}
