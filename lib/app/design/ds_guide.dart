import 'package:material_ui/material_ui.dart';

import '../theme/retro_bar.dart';
import '../theme/retro_text.dart';
import '../theme/retro_theme.dart';
import '../widgets/pixel_icon.dart';
import 'ds_focus.dart';
import 'ds_tokens.dart';

// Piezas de las guías simples (build_planner.md § 10, ui_minimal.md § 6):
// marca de estado con leyenda, fila que baja de línea (nunca "…") y
// sección plegable con medidor.

/// Marca de estado: tilde verde = listo, cajita dorada = falta. Mismos
/// colores en toda guía; [DsLegend] los explica.
class DsStatusMark extends StatelessWidget {
  const DsStatusMark(this.done, {super.key});

  final bool done;

  static Color colorOf(bool done) => done ? DsColors.success : DsColors.reward;

  @override
  Widget build(BuildContext context) {
    final s = RetroType.width(context, 11);
    return SizedBox(
      key: ValueKey(done ? 'ds-mark-done' : 'ds-mark-todo'),
      width: s,
      height: s,
      child: done
          ? PixelIcon(PixelIconKind.check, size: s, color: colorOf(true))
          : DecoratedBox(
              decoration: BoxDecoration(
                  border: Border.all(color: colorOf(false), width: 1.5))),
    );
  }
}

/// Leyenda de una línea: "✓ Listo · □ Falta".
class DsLegend extends StatelessWidget {
  const DsLegend({super.key, this.done = 'Listo', this.todo = 'Falta'});

  final String done;
  final String todo;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: DsSpace.sm,
        runSpacing: DsSpace.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const DsStatusMark(true),
          Text(retroText(done), style: DsText.detail()),
          const DsStatusMark(false),
          Text(retroText(todo), style: DsText.detail()),
        ],
      );
}

/// Fila que baja de línea en vez de cortar: ícono, título, línea
/// secundaria opcional y acciones a la derecha (o abajo si no entran).
class DsInfoRow extends StatelessWidget {
  const DsInfoRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.tags = const [],
    this.actions = const [],
    this.titleColor,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;

  /// Etiquetas cortas al lado del título (dificultad, ajuste).
  final List<Widget> tags;
  final List<Widget> actions;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: DsSpace.sm,
          runSpacing: DsSpace.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(retroText(title),
                style: DsText.body(titleColor ?? DsColors.textPrimary)),
            ...tags,
          ],
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(retroText(subtitle!), style: DsText.detail()),
          ),
      ],
    );
    return Padding(
      padding:
          EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null) ...[
            Padding(padding: const EdgeInsets.only(top: 3), child: leading!),
            SizedBox(width: DsSpace.sm),
          ],
          Expanded(
            child: actions.isEmpty
                ? text
                : Wrap(
                    spacing: DsSpace.sm,
                    runSpacing: DsSpace.xs,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      text,
                      Wrap(
                          spacing: DsSpace.xs,
                          runSpacing: DsSpace.xs,
                          children: actions),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Sección plegable con medidor: "> ARMA  ▮▮▮▯  2 de 3" (tilde al
/// completar). Cerrada por defecto.
class DsProgressFold extends StatefulWidget {
  const DsProgressFold({
    super.key,
    required this.title,
    required this.done,
    required this.total,
    required this.child,
    this.initiallyOpen = false,
  });

  final String title;
  final int done;
  final int total;
  final Widget child;
  final bool initiallyOpen;

  @override
  State<DsProgressFold> createState() => _DsProgressFoldState();
}

class _DsProgressFoldState extends State<DsProgressFold> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final complete = widget.total > 0 && widget.done >= widget.total;
    final count =
        widget.total == 0 ? 'sin metas' : '${widget.done} de ${widget.total}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        DsPressable(
          onTap: () => setState(() => _open = !_open),
          builder: (context, s) => Container(
            key: const ValueKey('ds-fold-head'),
            color: s.hot ? DsColors.hover : Colors.transparent,
            padding: EdgeInsets.symmetric(
                horizontal: DsSpace.md, vertical: DsSpace.sm),
            child: Row(children: [
              Text(_open ? 'v' : '>', style: DsText.body(DsColors.reward)),
              SizedBox(width: DsSpace.sm),
              Expanded(
                flex: 3,
                child: Text(retroText(widget.title.toUpperCase()),
                    style: DsText.subtitle()),
              ),
              Expanded(
                flex: 2,
                child: RetroBar(
                    value: widget.done,
                    max: widget.total == 0 ? 1 : widget.total,
                    color: DsStatusMark.colorOf(complete),
                    height: 6),
              ),
              SizedBox(width: DsSpace.sm),
              if (complete) ...[
                const DsStatusMark(true),
                SizedBox(width: DsSpace.xs),
              ],
              Text(retroText(count), style: DsText.detail()),
            ]),
          ),
        ),
        if (_open)
          Padding(
            key: const ValueKey('ds-fold-body'),
            padding: EdgeInsets.only(left: DsSpace.md, bottom: DsSpace.sm),
            child: widget.child,
          ),
      ],
    );
  }
}
