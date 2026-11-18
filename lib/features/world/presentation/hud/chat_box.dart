import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/proto_colors.dart';
import '../../../../app/theme/proto_markup.dart';
import '../../../../app/theme/retro_panel.dart';
import '../../../../app/theme/retro_theme.dart';
import '../../../../game_engine/models/session_action.dart';
import '../session_view.dart';

/// Línea de sistema que merece aviso con el chat plegado (v0.8.1): las
/// que empiezan con `¡` (misión aceptada, piso despejado, subida de
/// nivel, Eco completado…), las de misión opcional y las propuestas que
/// piden votar. Ver docs/specs/exploration.md § "Chat".
bool isImportantChat(ChatLine l) =>
    l.system &&
    (l.text.startsWith('¡') ||
        l.text.startsWith('Misión opcional') ||
        l.text.endsWith('¡Voten!'));

/// Chat (`#chatbox` del prototipo, líneas 103-106 y 1376-1379): las
/// últimas 5 líneas (`#chatlog` en `#c8d2ff`; sistema `.sys` en verde
/// con `» `, jugadores con su nombre en negrita dorada) y el campo
/// `Enter para chatear…` de 120 caracteres.
///
/// Enter en el campo manda el mensaje y devuelve el foco al juego; Esc lo
/// devuelve sin mandar (líneas 909-912). Con [collapsible] (ajuste CHAT:
/// OCULTO, v0.8.1) el chat se ve plegado en la píldora `CHAT [ENTER]`
/// con el contador `+N` de mensajes nuevos y solo se despliega mientras
/// el campo tiene el foco. Ver docs/specs/exploration.md § "Chat".
class ChatBox extends StatefulWidget {
  const ChatBox({
    super.key,
    required this.lines,
    required this.focusNode,
    required this.onSend,
    required this.onDone,
    this.collapsible = false,
    this.notices = true,
    this.localName,
  });

  final List<ChatLine> lines;

  /// Foco del campo; `WorldScreen` lo enfoca con Enter.
  final FocusNode focusNode;
  final ValueChanged<String> onSend;

  /// Se terminó de escribir (Enter o Esc): el foco vuelve al juego.
  final VoidCallback onDone;

  /// Plegado salvo mientras se escribe (CHAT: OCULTO).
  final bool collapsible;

  /// Plegado: avisos de 4 s de las líneas de sistema importantes.
  final bool notices;

  /// Nombre (con título) del jugador local: sus mensajes no suman al
  /// contador.
  final String? localName;

  static const visibleLines = 5;
  static const toastDuration = Duration(seconds: 4);
  static const maxToasts = 3;

  @override
  State<ChatBox> createState() => _ChatBoxState();
}

class _Toast {
  _Toast(this.line, this.timer);
  final ChatLine line;
  final Timer timer;
}

class _ChatBoxState extends State<ChatBox> {
  final _text = TextEditingController();

  /// Última línea ya contada (por identidad: la lista tiene tope).
  ChatLine? _seen;
  int _unread = 0;
  final _toasts = <_Toast>[];

  bool get _open => !widget.collapsible || widget.focusNode.hasFocus;

  @override
  void initState() {
    super.initState();
    widget.focusNode.onKeyEvent = _onKey;
    widget.focusNode.addListener(_onFocus);
    _seen = widget.lines.isEmpty ? null : widget.lines.last;
  }

  @override
  void didUpdateWidget(ChatBox old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      old.focusNode.removeListener(_onFocus);
      widget.focusNode.onKeyEvent = _onKey;
      widget.focusNode.addListener(_onFocus);
    }
    if (!widget.collapsible || !widget.notices) _clearToasts();
    _absorb(widget.lines);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    _clearToasts();
    _text.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (!mounted) return;
    setState(() {
      if (widget.focusNode.hasFocus) {
        _unread = 0;
        _clearToasts();
      }
      _seen = widget.lines.isEmpty ? null : widget.lines.last;
    });
  }

  void _clearToasts() {
    for (final t in _toasts) {
      t.timer.cancel();
    }
    _toasts.clear();
  }

  /// Cuenta lo nuevo desde [_seen] (plegado): mensajes de otros al
  /// contador y líneas de sistema importantes a los avisos.
  void _absorb(List<ChatLine> lines) {
    if (lines.isEmpty || identical(lines.last, _seen)) return;
    if (_open) {
      _seen = lines.last;
      return;
    }
    final at =
        _seen == null ? -1 : lines.lastIndexWhere((l) => identical(l, _seen));
    for (final l in lines.sublist(at + 1)) {
      if (!l.system) {
        if (l.from != widget.localName) _unread++;
      } else if (widget.notices && isImportantChat(l)) {
        _addToast(l);
      }
    }
    _seen = lines.last;
  }

  void _addToast(ChatLine l) {
    late final _Toast toast;
    toast = _Toast(
        l,
        Timer(ChatBox.toastDuration, () {
          if (mounted) setState(() => _toasts.remove(toast));
        }));
    _toasts.add(toast);
    while (_toasts.length > ChatBox.maxToasts) {
      _toasts.removeAt(0).timer.cancel();
    }
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

  static String _markup(ChatLine l) => l.system
      ? '<span class="sys">» ${protoEsc(l.text)}</span>'
      : '<b>${protoEsc(l.from ?? '')}:</b> ${protoEsc(l.text)}';

  @override
  Widget build(BuildContext context) {
    final lines = widget.lines;
    final last = lines.length > ChatBox.visibleLines
        ? lines.sublist(lines.length - ChatBox.visibleLines)
        : lines;
    final lineStyle =
        TextStyle(color: ProtoColors.chat, height: RetroType.line);
    final panel = RetroPanel(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final l in last)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: ProtoText(
                _markup(l),
                style: lineStyle,
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
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
          ),
        ],
      ),
    );
    if (!widget.collapsible) return panel;
    final open = _open;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!open) ...[
          for (final (i, t) in _toasts.indexed)
            Padding(
              key: ValueKey('chat-toast-$i'),
              padding: const EdgeInsets.only(bottom: 4),
              child: RetroPanel(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ProtoText(_markup(t.line),
                    style: lineStyle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
            ),
          // La píldora no toma el foco: el teclado sigue en el juego.
          ExcludeFocus(
            child: ElevatedButton(
              key: const ValueKey('chat-pill'),
              style: RetroTheme.compactButton(),
              onPressed: widget.focusNode.requestFocus,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('CHAT [ENTER]'),
                  if (_unread > 0) ...[
                    const SizedBox(width: 8),
                    Text('+$_unread',
                        key: const ValueKey('chat-unread'),
                        style: const TextStyle(color: ProtoColors.gold)),
                  ],
                ],
              ),
            ),
          ),
        ],
        // El campo existe siempre (fuera de escena plegado): Enter en el
        // mapa lo enfoca y eso lo despliega.
        Offstage(
          key: const ValueKey('chat-panel'),
          offstage: !open,
          child: panel,
        ),
      ],
    );
  }
}
