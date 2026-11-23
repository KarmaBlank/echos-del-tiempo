import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../core/update/presentation/update_controller.dart';

/// Aviso del HUD del mundo cuando el actualizador sabe que hay una versión
/// nueva (docs/specs/update_notice.md): texto que late suave y una X que
/// lo cierra por esta partida. No hace nada más.
class UpdateNotice extends StatefulWidget {
  const UpdateNotice({super.key, this.source});

  static const text = 'Hay una nueva actualización';

  /// `null`: [UpdateController.newerVersion].
  final ValueListenable<String?>? source;

  @override
  State<UpdateNotice> createState() => _UpdateNoticeState();
}

class _UpdateNoticeState extends State<UpdateNotice>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200));
  late final Animation<double> _opacity =
      Tween(begin: 0.45, end: 1.0).animate(_pulse);
  bool _dismissed = false;

  ValueListenable<String?> get _src =>
      widget.source ?? UpdateController.newerVersion;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String?>(
        valueListenable: _src,
        builder: (context, version, _) {
          if (version == null || _dismissed) {
            if (_pulse.isAnimating) _pulse.stop();
            return const SizedBox.shrink();
          }
          if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
          return Padding(
            padding: EdgeInsets.only(top: DsSpace.xs),
            child: Container(
              key: const ValueKey('hud-update-notice'),
              padding: EdgeInsets.only(left: DsSpace.sm),
              decoration: BoxDecoration(
                  color: DsColors.surface,
                  border: Border.all(color: DsColors.border)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FadeTransition(
                    opacity: _opacity,
                    child: Text(UpdateNotice.text,
                        style: DsText.detail(DsColors.reward)),
                  ),
                  SizedBox(width: DsSpace.sm),
                  DsButton('X',
                      key: const ValueKey('hud-update-notice-close'),
                      size: DsButtonSize.compact,
                      onPressed: () => setState(() => _dismissed = true)),
                ],
              ),
            ),
          );
        },
      );
}
