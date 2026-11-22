import 'package:material_ui/material_ui.dart';

import 'ds_components.dart';
import 'ds_tokens.dart';

/// Acción elegible de la ARMERÍA (FORJA, FUSIÓN, CONDENSAR; ui_minimal.md
/// § 6): una fila [DsListRow] sin marco propio. Ícono, nombre (Título),
/// una línea (Detalle: qué hace, o el motivo si está bloqueada) y el
/// costo a la derecha como [DsTag]. Bloqueada = gris con candado; elegida
/// = borde dorado (lo pone [DsListRow]).
class DsActionRow extends StatelessWidget {
  const DsActionRow({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.reason,
    this.cost,
    this.extra,
    this.selected = false,
    this.onTap,
    this.tooltip,
    this.focusNode,
    this.line,
    this.lockedTap = false,
  });

  /// Línea clave como widget (`MAG 29 → 32`), en lugar de [description].
  final Widget? line;

  /// Bloqueada pero tocable (el paso siguiente muestra el motivo entero).
  final bool lockedTap;

  /// Ícono ya coloreado (bloqueada: el candado gris, lo elige quien
  /// llama; el sistema de diseño no conoce los íconos pixel).
  final Widget icon;
  final String title;
  final String? description;

  /// Motivo del bloqueo (`null` = se puede).
  final String? reason;

  /// Costo (un [DsTag] corto, p. ej. [DsActionRow.costTag]).
  final Widget? cost;

  /// Dato extra a la derecha, antes del costo (nivel, ★ de build).
  final Widget? extra;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? tooltip;
  final FocusNode? focusNode;

  bool get locked => reason != null;

  /// Costo como etiqueta: dorado si alcanza, rojo si no, gris bloqueada.
  static Widget costTag(String text,
          {bool affordable = true, bool locked = false, Key? key}) =>
      DsTag(text,
          key: key,
          color: locked
              ? DsColors.textDisabled
              : affordable
                  ? DsColors.reward
                  : DsColors.danger);

  @override
  Widget build(BuildContext context) {
    return DsListRow(
      title: title,
      titleColor: DsColors.textTitle,
      subtitle: reason ?? description,
      subtitleWidget: line,
      tapWhenDisabled: lockedTap,
      shrinkTrailing: true,
      leading: icon,
      trailing: extra == null && cost == null
          ? null
          : Row(mainAxisSize: MainAxisSize.min, children: [
              if (extra != null) extra!,
              if (extra != null && cost != null) SizedBox(width: DsSpace.sm),
              if (cost != null) cost!,
            ]),
      selected: selected,
      enabled: !locked,
      onTap: onTap,
      tooltip: tooltip,
      focusNode: focusNode,
    );
  }
}
