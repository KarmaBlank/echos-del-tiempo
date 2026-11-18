import 'package:material_ui/material_ui.dart';

import 'proto_colors.dart';
import 'proto_markup.dart';
import 'retro_text.dart';
import 'retro_theme.dart';

/// Piezas de los paneles "lista + detalle" de la pasada de UX v3. Ver
/// docs/specs/ui_style.md § "Panel sobre el mapa" y docs/specs/panels.md
/// § "Marco común".

/// Línea "qué hace" de una pestaña o sección: [RetroType.small] `dim`, en
/// markup.
class PanelHint extends StatelessWidget {
  const PanelHint(this.markup, {super.key});

  final String markup;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child:
            ProtoText(markup, style: const TextStyle(color: ProtoColors.dim)),
      );
}

/// Lista compacta (izquierda, [listWidth] px) y detalle (el resto). La
/// lista tiene su propio scroll; el detalle lo maneja [detail] (por lo
/// general un [PanelDetail]). Con texto más grande la lista se ensancha
/// igual que el texto (sin pasar de la mitad del panel), salvo que
/// [scaleList] sea `false` (listas de ancho fijo, como la grilla del
/// inventario).
class PanelSplit extends StatelessWidget {
  const PanelSplit({
    super.key,
    required this.list,
    required this.detail,
    this.listWidth = 360,
    this.scaleList = true,
  });

  final List<Widget> list;
  final Widget detail;
  final double listWidth;
  final bool scaleList;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      var w = listWidth;
      if (scaleList) {
        final scaled = RetroType.width(context, listWidth);
        final cap = box.maxWidth.isFinite
            ? (box.maxWidth * 0.5).clamp(listWidth, double.infinity)
            : scaled;
        w = scaled.clamp(listWidth, cap);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: w,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: list,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: detail),
        ],
      );
    });
  }
}

/// Caja del detalle / vista previa: borde `#2e3b6b`, contenido con
/// scroll y [footer] fijo abajo a la derecha (el botón de la acción).
class PanelDetail extends StatelessWidget {
  const PanelDetail(
      {super.key, required this.children, this.footer = const []});

  final List<Widget> children;
  final List<Widget> footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(
            color: ProtoColors.panelBorder, width: RetroTheme.thinBorderWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
          if (footer.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: footer,
            ),
          ],
        ],
      ),
    );
  }
}

/// Fila elegible de una lista (`.mrow`): borde `gold` si está elegida,
/// `sky` con foco o mouse. Se activa con clic, `Enter` o `Espacio`.
class PanelListItem extends StatefulWidget {
  const PanelListItem({
    super.key,
    required this.child,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  final Widget child;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  State<PanelListItem> createState() => _PanelListItemState();
}

class _PanelListItemState extends State<PanelListItem> {
  bool _hot = false;

  @override
  Widget build(BuildContext context) {
    final border = widget.selected
        ? ProtoColors.gold
        : _hot
            ? ProtoColors.sky
            : ProtoColors.panelBorder;
    return FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      onShowFocusHighlight: (v) => setState(() => _hot = v),
      onShowHoverHighlight: (v) => setState(() => _hot = v),
      actions: {
        ActivateIntent:
            CallbackAction<ActivateIntent>(onInvoke: (_) => widget.onTap()),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: widget.selected
                ? ProtoColors.button.withValues(alpha: 0.5)
                : null,
            border:
                Border.all(color: border, width: RetroTheme.thinBorderWidth),
          ),
          child: Row(
            children: [
              Expanded(child: widget.child),
              if (widget.trailing != null) ...[
                const SizedBox(width: 8),
                widget.trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// `ETIQUETA antes → después`: el después en verde si mejora y en rojo si
/// empeora; sin cambio, solo `ETIQUETA valor`.
class StatChange extends StatelessWidget {
  const StatChange(
    this.label,
    this.before,
    this.after, {
    super.key,
    this.format,
    this.higherIsBetter = true,
    this.suffix,
  });

  final String label;
  final num before;
  final num after;
  final String Function(num)? format;
  final bool higherIsBetter;

  /// Texto `dim` al final (p. ej. la fórmula).
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    final f = format ?? (num x) => '$x';
    final changed = (before - after).abs() > 1e-6;
    final better = (after > before) == higherIsBetter;
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: retroText('$label ${f(before)}')),
        // ▲ mejora / ▼ empeora: no solo el color (daltonismo).
        if (changed)
          TextSpan(
              style: TextStyle(
                  color: better ? ProtoColors.green : ProtoColors.red),
              children: symbolSpans(
                  retroText(' → ${f(after)} ${better ? '▲' : '▼'}'))),
        if (suffix != null)
          TextSpan(
              text: retroText(' $suffix'),
              style: const TextStyle(color: ProtoColors.dim)),
      ]),
    );
  }
}

/// Nivel `n/max` en cuadritos de 6 px (`gold` llenos, `barBg` vacíos).
class LevelPips extends StatelessWidget {
  const LevelPips(this.level, this.max, {super.key});

  final int level;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < max; i++)
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 2),
            color: i < level ? ProtoColors.gold : ProtoColors.barBg,
          ),
      ],
    );
  }
}

/// `Costo $N · Te quedan $M`. Si no alcanza solo `Costo $N`: el `Faltan
/// $X` lo dice el motivo del botón de al lado.
class CostLine extends StatelessWidget {
  const CostLine({super.key, required this.cost, required this.credits});

  final int cost;
  final int credits;

  @override
  Widget build(BuildContext context) {
    final left = credits - cost;
    return ProtoText(
        'Costo <b>₵$cost</b>${left >= 0 ? ' · Te quedan ₵$left' : ''}');
  }
}

/// Una pestaña de un panel: etiqueta, línea "qué hace" y contenido.
class PanelTabSpec {
  const PanelTabSpec(this.label, this.hint, this.builder);

  final String label;
  final String hint;
  final WidgetBuilder builder;
}
