import 'package:material_ui/material_ui.dart';

import '../design/design.dart';
import '../theme/retro_type.dart';
import 'pixel_icon.dart';

/// Ícono de una [DsActionRow]: el de la acción en su color, o el candado
/// gris si está bloqueada (ui_minimal.md § 6).
Widget actionRowIcon(BuildContext context, PixelIconKind kind, Color color,
        {bool locked = false}) =>
    PixelIcon(locked ? PixelIconKind.lock : kind,
        size: RetroType.width(context, 16),
        color: locked ? DsColors.textDisabled : color);
