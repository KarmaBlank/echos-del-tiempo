import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/proto_colors.dart';
import '../../../../app/theme/proto_markup.dart';
import '../../../../app/theme/retro_panel.dart';
import '../../../../app/theme/retro_theme.dart';
import '../../../../game_engine/models/session_action.dart';
import '../session_view.dart';

/// Chat (`#chatbox` del prototipo, líneas 103-106 y 1376-1379): las
/// últimas 5 líneas (`#chatlog` en `#c8d2ff`; sistema `.sys` en verde
/// con `» `, jugadores con su nombre en negrita dorada) y el campo
/// `Enter para chatear…` de 120 caracteres.
///
/// Enter en el campo manda el mensaje y devuelve el foco al juego; Esc lo
/// devuelve sin mandar (líneas 909-912). Ver docs/specs/exploration.md §
/// "Chat".
class ChatBox extends StatefulWidget {
  const ChatBox({
    super.key,
    required this.lines,
    required this.focusNode,
    required this.onSend,
    required this.onDone,
  });

  final List<ChatLine> lines;

  /// Foco del campo; `WorldScreen` lo enfoca con Enter.
  final FocusNode focusNode;
  final ValueChanged<String> onSend;

  /// Se terminó de escribir (Enter o Esc): el foco vuelve al juego.
  final VoidCallback onDone;

  static const visibleLines = 5;

  @override
  State<ChatBox> createState() => _ChatBoxState();
}

class _ChatBoxState extends State<ChatBox> {
  final _text = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.focusNode.onKeyEvent = _onKey;
  }

  @override
  void didUpdateWidget(ChatBox old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      widget.focusNode.onKeyEvent = _onKey;
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.escape) {
      _text.clear();
      widget.onDone();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _submit(String value) {
    final v = value.trim();
    if (v.isNotEmpty) widget.onSend(v);
    _text.clear();
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final lines = widget.lines;
    final last = lines.length > ChatBox.visibleLines
        ? lines.sublist(lines.length - ChatBox.visibleLines)
        : lines;
    return RetroPanel(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final l in last)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: ProtoText(
                l.system
                    ? '<span class="sys">» ${protoEsc(l.text)}</span>'
                    : '<b>${protoEsc(l.from ?? '')}:</b> ${protoEsc(l.text)}',
                style: TextStyle(
                    color: ProtoColors.chat, height: RetroType.line),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          // Sin alto fijo: el campo crece con el tamaño del texto.
          TextField(
            key: const ValueKey('chat-input'),
            controller: _text,
            focusNode: widget.focusNode,
            maxLength: ChatAction.maxLength,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            textInputAction: TextInputAction.send,
            onSubmitted: _submit,
            style: TextStyle(
                fontFamily: RetroType.bodyFamily,
                fontFamilyFallback: RetroType.bodyFallback,
                fontSize: RetroType.small,
                color: ProtoColors.white),
            cursorColor: ProtoColors.gold,
            decoration: InputDecoration(
              isDense: true,
              counterText: '',
              hintText: 'Enter para chatear…',
              hintStyle: TextStyle(
                  fontFamily: RetroType.bodyFamily,
                  fontFamilyFallback: RetroType.bodyFallback,
                  fontSize: RetroType.small,
                  color: ProtoColors.dim),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
          ),
        ],
      ),
    );
  }
}
