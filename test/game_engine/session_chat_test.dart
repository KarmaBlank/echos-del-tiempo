import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/session_event.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

void main() {
  test('chat: emite el mensaje con el nombre, recortado a 120', () {
    final e = sessionEngine();
    final s = e.addPlayer(e.create(), 'p0', newProfile('Ana', 'maga'))!.state;

    final step = e.apply(s, 'p0', const ChatAction('  hola  '))!;
    final msg = step.events.whereType<ChatMessageEvent>().single;
    expect(msg.playerId, 'p0');
    expect(msg.from, 'Ana');
    expect(msg.text, 'hola');
    // El chat no cambia el estado.
    expect(step.state.mode, SessionMode.lobby);

    final long = e.apply(s, 'p0', ChatAction('x' * 200))!;
    expect(long.events.whereType<ChatMessageEvent>().single.text.length,
        ChatAction.maxLength);
  });

  test('chat: vacío o de alguien que no está en la sala se rechaza', () {
    final e = sessionEngine();
    final s = e.addPlayer(e.create(), 'p0', newProfile('Ana', 'maga'))!.state;
    expect(e.apply(s, 'p0', const ChatAction('   ')), isNull);
    expect(e.apply(s, 'zz', const ChatAction('hola')), isNull);
  });

  test('chat: se acepta fuera del lobby (campo)', () {
    final e = sessionEngine();
    final s = inField(e, 'm1');
    expect(s.mode, SessionMode.field);
    expect(e.apply(s, 'p0', const ChatAction('vamos')), isNotNull);
  });
}
