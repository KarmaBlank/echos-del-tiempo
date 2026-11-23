import 'package:material_ui/material_ui.dart';

import '../../core/text/text_detail.dart';

/// Pone el ajuste TEXTOS (ui_minimal.md § 8) en [TextDetail.current]
/// para todos los armadores de descripciones. Al cambiar, se vuelve a
/// armar la app entera (como el modo daltónico): los textos ya armados
/// en estados de widgets también se regeneran.
class TextDetailScope extends StatefulWidget {
  const TextDetailScope({super.key, required this.mode, required this.child});

  final TextDetail mode;
  final Widget child;

  @override
  State<TextDetailScope> createState() => _TextDetailScopeState();
}

class _TextDetailScopeState extends State<TextDetailScope> {
  @override
  void didUpdateWidget(TextDetailScope old) {
    super.didUpdateWidget(old);
    if (old.mode != widget.mode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) WidgetsBinding.instance.reassembleApplication();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    TextDetail.current = widget.mode;
    return widget.child;
  }
}
