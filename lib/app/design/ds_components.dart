import 'package:material_ui/material_ui.dart';

import '../theme/proto_colors.dart';
import '../theme/retro_text.dart';
import '../theme/retro_theme.dart';
import '../theme/ui_theme.dart';
import 'ds_button.dart';
import 'ds_focus.dart';
import 'ds_tokens.dart';

// Catálogo de componentes (docs/specs/design_system.md § 6).

/// Pastilla con un número o una palabra corta. Va AL LADO del texto, nunca
/// encima. Base: `Badge` sin hijo.
class DsBadge extends StatelessWidget {
  const DsBadge(this.text, {super.key, this.neutral = false});

  final String text;

  /// Sin relleno: texto secundario sobre la superficie.
  final bool neutral;

  @override
  Widget build(BuildContext context) {
    final fs = MediaQuery.textScalerOf(context).scale(RetroType.label);
    final style =
        DsText.subtitle(neutral ? DsColors.textSecondary : ProtoColors.bg);
    return Badge(
      label: Text(retroText(text), textScaler: TextScaler.noScaling),
      textStyle: style.copyWith(fontSize: fs, height: 1),
      textColor: style.color,
      backgroundColor:
          neutral ? DsColors.surfaceSunken : DsColors.actionPrimary,
      largeSize: fs + 10,
      padding: EdgeInsets.symmetric(horizontal: DsSpace.xs + 2),
      alignment: Alignment.center,
    );
  }
}

/// Una pestaña: texto y, opcional, [badge] adentro a la derecha.
class DsTab {
  const DsTab(this.label, {this.badge, this.key, this.badgeKey});
  final String label;
  final String? badge;

  /// Clave de la pestaña y de su insignia (tests y atajos).
  final Key? key;
  final Key? badgeKey;
}

/// Fila de pestañas sobre `TabBar`. Elegida: texto dorado y subrayado.
class DsTabBar extends StatefulWidget {
  const DsTabBar(
      {super.key,
      required this.tabs,
      required this.index,
      required this.onChanged});

  final List<DsTab> tabs;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  State<DsTabBar> createState() => _DsTabBarState();
}

class _DsTabBarState extends State<DsTabBar>
    with SingleTickerProviderStateMixin {
  late TabController _c = _make();

  TabController _make() => TabController(
      length: widget.tabs.length,
      initialIndex: widget.index,
      vsync: this,
      animationDuration: Duration.zero);

  @override
  void didUpdateWidget(DsTabBar old) {
    super.didUpdateWidget(old);
    if (old.tabs.length != widget.tabs.length) {
      _c.dispose();
      _c = _make();
    } else if (_c.index != widget.index) {
      _c.index = widget.index;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TabBar(
      controller: _c,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      onTap: widget.onChanged,
      // El padding va dentro de cada pestaña (con su clave): la pestaña
      // completa, con su aire, es el área clickeable.
      labelPadding: EdgeInsets.zero,

      labelStyle: DsText.subtitle(),
      unselectedLabelStyle: DsText.subtitle(),
      labelColor: DsColors.selected,
      unselectedLabelColor: DsColors.text,
      indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(color: DsColors.selected, width: 3),
          borderRadius: BorderRadius.zero),
      indicatorSize: TabBarIndicatorSize.tab,
      dividerHeight: 0,
      splashFactory: NoSplash.splashFactory,
      mouseCursor: SystemMouseCursors.click,
      overlayColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.hovered) || s.contains(WidgetState.focused)
              ? DsColors.hover
              : Colors.transparent),
      tabs: [
        for (final t in widget.tabs)
          Padding(
              key: t.key,
              padding: EdgeInsets.symmetric(horizontal: DsSpace.md),
              child: Tab(
                height: RetroType.width(context, DsMetrics.minHeight),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(retroText(t.label)),
                  if (t.badge != null) ...[
                    SizedBox(width: DsSpace.sm),
                    DsBadge(t.badge!, key: t.badgeKey),
                  ],
                ]),
              )),
      ],
    );
  }
}

/// Barra superior de un panel: título, [center] (pestañas) y [actions] a la
/// derecha ("?" siempre la última). Sin caja: solo una línea abajo.
class DsToolbar extends StatelessWidget {
  const DsToolbar(
      {super.key, required this.title, this.center, this.actions = const []});

  final String title;
  final Widget? center;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.xs),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: DsColors.border, width: 2))),
      child: Row(children: [
        // Sin título (barra de una pestaña): arranca con [center].
        if (title.isNotEmpty) ...[
          Text(retroText(title), style: DsText.title()),
          SizedBox(width: DsSpace.lg),
        ],
        Expanded(
            child: Align(
                alignment: Alignment.centerLeft,
                child: center ?? const SizedBox.shrink())),
        for (final a in actions) ...[SizedBox(width: DsSpace.xs), a],
      ]),
    );
  }
}

/// Tarjeta: superficie sin borde (borde dorado si está elegida). Con
/// [onTap], clickeable con hover.
class DsCard extends StatelessWidget {
  const DsCard(
      {super.key, required this.child, this.onTap, this.selected = false});

  final Widget child;
  final VoidCallback? onTap;
  final bool selected;

  BoxDecoration _deco(bool hot) => BoxDecoration(
        color: hot ? DsColors.hover : DsColors.surface,
        border: Border.all(
            color: selected ? DsColors.selected : Colors.transparent, width: 2),
      );

  @override
  Widget build(BuildContext context) {
    Widget box(bool hot) => Container(
        decoration: _deco(hot),
        padding: EdgeInsets.all(DsSpace.md),
        child: child);
    if (onTap == null) return box(false);
    return DsPressable(onTap: onTap, builder: (_, s) => box(s.hot));
  }
}

/// Tipo de [DsToast].
enum DsToastKind { info, success, danger, reward }

/// Aviso de una línea con franja de color a la izquierda y × opcional.
class DsToast extends StatelessWidget {
  const DsToast(this.message,
      {super.key, this.kind = DsToastKind.info, this.onClose});

  final String message;
  final DsToastKind kind;
  final VoidCallback? onClose;

  Color get color => switch (kind) {
        DsToastKind.info => DsColors.mp,
        DsToastKind.success => DsColors.success,
        DsToastKind.danger => DsColors.danger,
        DsToastKind.reward => DsColors.reward,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DsColors.surface,
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      padding: EdgeInsets.only(
          left: DsSpace.md,
          right: DsSpace.xs,
          top: DsSpace.xs,
          bottom: DsSpace.xs),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Flexible(
            child: Padding(
          padding: EdgeInsets.symmetric(vertical: DsSpace.xs),
          child: Text(message, style: DsText.body(DsColors.textPrimary)),
        )),
        if (onClose != null) ...[
          SizedBox(width: DsSpace.sm),
          DsButton.icon(const Text('×'),
              tooltip: 'Cerrar',
              onPressed: onClose,
              size: DsButtonSize.compact),
        ] else
          SizedBox(width: DsSpace.sm),
      ]),
    );
  }
}

/// Campo de búsqueda hundido, sobre `SearchBar` cuadrada.
class DsSearchField extends StatelessWidget {
  const DsSearchField(
      {super.key,
      this.hint = 'BUSCAR',
      this.controller,
      this.onChanged,
      this.onSubmitted,
      this.focusNode,
      this.width = 240});

  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;

  /// Enter en el campo (p. ej. ir a la primera coincidencia).
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final double width;

  @override
  Widget build(BuildContext context) {
    final h = RetroType.width(context, DsMetrics.minHeight);
    return SizedBox(
      width: RetroType.width(context, width),
      child: SearchBar(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        hintText: hint,
        elevation: const WidgetStatePropertyAll(0),
        constraints: BoxConstraints(minHeight: h, maxHeight: h),
        backgroundColor: const WidgetStatePropertyAll(DsColors.surfaceSunken),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        shadowColor: const WidgetStatePropertyAll(Colors.transparent),
        padding: WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: DsSpace.sm)),
        shape: const WidgetStatePropertyAll(RoundedRectangleBorder()),
        side: WidgetStateProperty.resolveWith((s) => BorderSide(
            color: s.contains(WidgetState.focused)
                ? DsColors.focus
                : s.contains(WidgetState.hovered)
                    ? DsColors.hoverBorder
                    : DsColors.borderControl,
            width: DsMetrics.controlBorder)),
        textStyle: WidgetStatePropertyAll(DsText.body(DsColors.textPrimary)),
        hintStyle: WidgetStatePropertyAll(DsText.detail()),
      ),
    );
  }
}

/// Fila de UNA línea: [leading], [title] en principal, [detail] corto en
/// secundario en la misma línea, [trailing] a la derecha. Lo demás, en
/// [tooltip] (aparece con hover y foco).
class DsListRow extends StatelessWidget {
  const DsListRow({
    super.key,
    required this.title,
    this.detail,
    this.leading,
    this.trailing,
    this.onTap,
    this.selected = false,
    this.enabled = true,
    this.titleColor,
    this.detailColor,
    this.tooltip,
    this.focusNode,
    this.autofocus = false,
    this.compact = false,
  });

  final String title;
  final String? detail;

  /// Foco propio (listas que se recorren con flechas).
  final FocusNode? focusNode;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool selected;
  final bool enabled;
  final Color? titleColor;

  /// Color del dato corto (p. ej. el motivo de una desactivada, en rojo).
  final Color? detailColor;
  final Widget? tooltip;

  /// El foco de teclado arranca en esta fila (menús).
  final bool autofocus;

  /// Fila baja para listas densas (menú de batalla): aire vertical
  /// mínimo y `sm` a los lados.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    Widget row(DsPressState s) => Container(
          padding: compact
              ? EdgeInsets.symmetric(horizontal: DsSpace.sm, vertical: 2)
              : EdgeInsets.symmetric(
                  horizontal: DsSpace.md, vertical: DsSpace.sm),
          decoration: BoxDecoration(
            color: s.hot ? DsColors.hover : Colors.transparent,
            border: Border.all(
                color: selected ? DsColors.selected : Colors.transparent,
                width: 2),
          ),
          child: Row(children: [
            if (leading != null) ...[leading!, SizedBox(width: DsSpace.sm)],
            Expanded(
                child: Row(children: [
              Flexible(
                child: Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DsText.body(!enabled
                        ? DsColors.textDisabled
                        : selected
                            ? DsColors.selected
                            : titleColor ?? DsColors.textPrimary)),
              ),
              if (detail != null) ...[
                SizedBox(width: DsSpace.sm),
                // Un dato largo se corta con "…" (nunca desborda la fila).
                Flexible(
                  child: Text(detail!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DsText.detail(detailColor ??
                          (enabled
                              ? DsColors.textSecondary
                              : DsColors.textDisabled))),
                ),
              ],
            ])),
            if (trailing != null) ...[SizedBox(width: DsSpace.sm), trailing!],
          ]),
        );
    final Widget body = DsPressable(
        focusNode: focusNode,
        onTap: enabled ? (onTap ?? () {}) : null,
        autofocus: autofocus,
        builder: (_, s) => row(s));
    if (tooltip == null) return body;
    return DsTooltip(card: tooltip!, child: body);
  }
}

/// Fila de ATRIBUTOS en una línea: nombre, valor, ★ de plan, − y "+3 VIT".
/// Pasando el tope blando, el botón dice `+3 → +1.5` en naranja.
class DsAttributeRow extends StatelessWidget {
  const DsAttributeRow({
    super.key,
    required this.name,
    required this.code,
    required this.value,
    this.planned = false,
    this.step = 3,
    this.cappedStep,
    this.onAdd,
    this.onRemove,
  });

  final String name;
  final String code;
  final int value;
  final bool planned;
  final num step;

  /// Lo que suma de verdad si pasa el tope (null: no lo pasa).
  final num? cappedStep;
  final VoidCallback? onAdd;
  final VoidCallback? onRemove;

  String _n(num v) => v == v.roundToDouble() ? '${v.round()}' : '$v';

  @override
  Widget build(BuildContext context) {
    final capped = cappedStep != null;
    return Padding(
      padding:
          EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.xs),
      child: Row(children: [
        SizedBox(
            width: RetroType.em(context, 14, size: RetroType.body),
            child: Text(name, style: DsText.body(DsColors.textPrimary))),
        SizedBox(
            width: RetroType.em(context, 5, size: RetroType.body),
            child: Text('$value',
                textAlign: TextAlign.right,
                style: DsText.body(DsColors.textPrimary))),
        SizedBox(width: DsSpace.sm),
        SizedBox(
          width: RetroType.em(context, 2, size: RetroType.label),
          child: planned
              ? Tooltip(
                  message: 'En el plan',
                  child: Text('★', style: DsText.subtitle(DsColors.reward)))
              : null,
        ),
        const Spacer(),
        DsButton.icon(const Text('-'),
            tooltip: 'Quitar $code',
            onPressed: onRemove,
            size: DsButtonSize.compact),
        SizedBox(width: DsSpace.xs),
        SizedBox(
            width: RetroType.em(context, 10) +
                2 *
                    (UiTheme.space(12) +
                        DsMetrics.controlBorder +
                        DsFocusRing.extent),
            child: DsButton(
              capped
                  ? '+${_n(step)} → +${_n(cappedStep!)}'
                  : '+${_n(step)} $code',
              onPressed: onAdd,
              size: DsButtonSize.compact,
              tooltip: capped ? 'Pasa el tope: rinde la mitad' : null,
              accent: capped ? DsColors.warning : null,
            )),
      ]),
    );
  }
}

/// `ATQ  15 → 50  ▲35`: flecha además del color (nunca solo el color).
/// ▲ verde si mejora, ▼ rojo si empeora ([higherIsBetter] `false`: menos
/// es mejor, p. ej. el peso). Sin cambio (o con [showChange] `false`),
/// solo `ATQ  15` en Detalle: un dato se muestra cuando cambia algo.
class DsStatLine extends StatelessWidget {
  const DsStatLine(this.label, this.from, this.to,
      {super.key,
      this.labelWidth = 5,
      this.format,
      this.diffFormat,
      this.higherIsBetter = true,
      this.showChange = true});

  final String label;
  final num from;
  final num to;
  final double labelWidth;

  /// Cómo se escribe un valor (`7.5`, `12%`); por defecto el número.
  final String Function(num)? format;

  /// Cómo se escribe la diferencia (sin signo); por defecto [format].
  final String Function(num)? diffFormat;
  final bool higherIsBetter;
  final bool showChange;

  static String _n(num v) => v == v.roundToDouble() ? '${v.round()}' : '$v';

  @override
  Widget build(BuildContext context) {
    final f = format ?? _n;
    final d = to - from;
    final changed = showChange && d.abs() > 1e-6;
    final good = higherIsBetter ? d > 0 : d < 0;
    final c = good ? DsColors.success : DsColors.danger;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
          width: RetroType.em(context, labelWidth, size: RetroType.body),
          child: Text(label, style: DsText.detail())),
      Text(f(from), style: DsText.detail()),
      if (changed) ...[
        Text(' → ',
            style: RetroType.style(RetroType.glyph,
                color: DsColors.textSecondary)),
        Text(f(to), style: DsText.body(DsColors.textPrimary)),
        SizedBox(width: DsSpace.sm),
        Text(good ? '▲' : '▼',
            style: RetroType.style(RetroType.glyph, color: c)),
        Text((diffFormat ?? f)(d.abs()), style: DsText.body(c)),
      ],
    ]);
  }
}

/// Costo de MP (azul) o de Pulso (dorado); en rojo si no alcanza.
class DsCost extends StatelessWidget {
  const DsCost.mp(this.amount, {super.key, this.affordable = true})
      : pulse = false;
  const DsCost.pulse(this.amount, {super.key, this.affordable = true})
      : pulse = true;

  final int amount;
  final bool pulse;
  final bool affordable;

  @override
  Widget build(BuildContext context) {
    final c = !affordable
        ? DsColors.danger
        : pulse
            ? DsColors.pulse
            : DsColors.mp;
    return Text('$amount ${pulse ? 'P' : 'MP'}', style: DsText.body(c));
  }
}

/// Etiqueta en mayúsculas con borde del color de su tipo.
class DsTag extends StatelessWidget {
  const DsTag(this.text, {super.key, required this.color});

  const DsTag.instant({super.key})
      : text = 'INSTANTE',
        color = DsColors.instant;
  const DsTag.canBreak({super.key})
      : text = 'PUEDE QUEBRAR',
        color = DsColors.warning;
  const DsTag.isNew({super.key})
      : text = 'NUEVO',
        color = DsColors.reward;

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: DsSpace.xs + 2, vertical: 3),
      decoration: BoxDecoration(border: Border.all(color: color, width: 2)),
      child: Text(retroText(text), style: DsText.subtitle(color)),
    );
  }
}

/// Encabezado de sección: Subtítulo secundario + línea fina; acción
/// opcional a la derecha.
class DsSectionHeader extends StatelessWidget {
  const DsSectionHeader(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: DsSpace.md, bottom: DsSpace.xs),
      // Con texto enorme el título y la acción (hasta 45 % del ancho cada
      // uno) se achican: nunca desborda. La línea ocupa lo que sobra.
      child: LayoutBuilder(
        builder: (context, box) => Row(children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: box.maxWidth * 0.45),
            child:
                Text(retroText(text.toUpperCase()), style: DsText.subtitle()),
          ),
          SizedBox(width: DsSpace.sm),
          Expanded(child: Container(height: 2, color: DsColors.border)),
          if (trailing != null) ...[
            SizedBox(width: DsSpace.sm),
            ConstrainedBox(
                constraints: BoxConstraints(maxWidth: box.maxWidth * 0.45),
                child: trailing!),
          ],
        ]),
      ),
    );
  }
}

/// Plegable: "▸ MÁS" / "▾ MENOS" (botón fantasma) y el contenido abajo.
class DsFold extends StatefulWidget {
  const DsFold(
      {super.key,
      required this.child,
      this.label = 'MÁS',
      this.openLabel = 'MENOS',
      this.initiallyOpen = false});

  final Widget child;
  final String label;
  final String openLabel;
  final bool initiallyOpen;

  @override
  State<DsFold> createState() => _DsFoldState();
}

class _DsFoldState extends State<DsFold> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        DsButton(_open ? 'v ${widget.openLabel}' : '> ${widget.label}',
            kind: DsButtonKind.ghost,
            size: DsButtonSize.compact,
            onPressed: () => setState(() => _open = !_open)),
        if (_open)
          Padding(
            padding: EdgeInsets.only(left: DsSpace.md, top: DsSpace.xs),
            child: DefaultTextStyle.merge(
                style: DsText.body(), child: widget.child),
          ),
      ],
    );
  }
}

/// Atajo del pie de un [DsTooltipCard]: tecla + qué hace.
class DsShortcut {
  const DsShortcut(this.key, this.label);
  final String key;
  final String label;
}

/// Tarjeta de tooltip: una columna, ancho máximo, scroll si no entra,
/// pie de atajos.
class DsTooltipCard extends StatelessWidget {
  const DsTooltipCard({
    super.key,
    required this.title,
    this.titleColor,
    this.tags = const [],
    this.children = const [],
    this.shortcuts = const [],
  });

  final String title;
  final Color? titleColor;
  final List<Widget> tags;
  final List<Widget> children;
  final List<DsShortcut> shortcuts;

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.6;
    return Container(
      constraints: BoxConstraints(
          maxWidth: RetroType.width(context, DsMetrics.tooltipWidth),
          maxHeight: maxH),
      decoration: BoxDecoration(
        color: DsColors.background,
        border: Border.all(color: DsColors.borderControl, width: 2),
        boxShadow: const [
          BoxShadow(color: ProtoColors.shadow, offset: Offset(4, 4))
        ],
      ),
      padding: EdgeInsets.all(DsSpace.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: DsText.body(titleColor ?? DsColors.textPrimary)),
          if (tags.isNotEmpty) ...[
            SizedBox(height: DsSpace.xs),
            Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: tags),
          ],
          if (children.isNotEmpty) ...[
            SizedBox(height: DsSpace.sm),
            Flexible(
              child: SingleChildScrollView(
                child: DefaultTextStyle.merge(
                  style: DsText.body(),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: children),
                ),
              ),
            ),
          ],
          if (shortcuts.isNotEmpty) ...[
            SizedBox(height: DsSpace.sm),
            Wrap(spacing: DsSpace.md, runSpacing: DsSpace.xs, children: [
              for (final s in shortcuts)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                        border: Border.all(color: DsColors.border, width: 2)),
                    child: Text(s.key, style: DsText.detail(DsColors.text)),
                  ),
                  SizedBox(width: DsSpace.xs),
                  Text(s.label, style: DsText.detail()),
                ]),
            ]),
          ],
        ],
      ),
    );
  }
}

/// Muestra [card] (un [DsTooltipCard]) al pasar el mouse o con foco, sobre
/// `Tooltip` sin caja propia.
class DsTooltip extends StatelessWidget {
  const DsTooltip({super.key, required this.card, required this.child});

  final Widget card;
  final Widget child;

  @override
  Widget build(BuildContext context) => Tooltip(
        richMessage: WidgetSpan(child: card),
        decoration: const BoxDecoration(),
        padding: EdgeInsets.zero,
        waitDuration: const Duration(milliseconds: 250),
        preferBelow: true,
        child: child,
      );
}
