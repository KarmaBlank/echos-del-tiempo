import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'proto_colors.dart';
import 'proto_markup.dart';
import 'retro_theme.dart';
import 'ui_theme.dart';

/// Dónde aparece la caja respecto de lo que se señala.
enum RetroTipPlacement {
  /// A la derecha (si no entra, a la izquierda), alineada arriba. Fichas
  /// grandes (comparación de armas).
  side,

  /// Debajo y centrada (si no entra, arriba), como el `#tip` del
  /// prototipo y el `Tooltip` de Flutter.
  below,
}

/// Caja del `#tip` (docs/specs/ui_style.md § "Tooltips") con lo que arme
/// [builder], al lado de [child] mientras el mouse está encima. No toma
/// el mouse; un clic la esconde.
///
/// Nunca se sale de la pantalla (margen [margin]): se corre hacia adentro
/// y, si es más alta que la pantalla, primero el texto se reparte en
/// columnas ([RetroTipText]) y, como último recurso, se achica lo justo
/// para entrar (sin recortar nada). Ver docs/specs/panels.md § "Comparar
/// armas".
class RetroHoverCard extends StatefulWidget {
  const RetroHoverCard({
    super.key,
    required this.builder,
    required this.child,
    this.gap = 8,
    this.margin = 8,
    this.placement = RetroTipPlacement.side,
    this.interactive = false,
  });

  /// Con secciones plegables ([RetroTipFold]): la caja toma el mouse y
  /// se **fija** mientras el mouse está encima: se puede pasar de la
  /// casilla a la caja sin que se cierre ([pinDelay]) y hacer clic en
  /// los ▸. Sin esto la caja no toma el mouse.
  final bool interactive;

  /// Margen para cruzar de la casilla a una caja [interactive].
  static const pinDelay = Duration(milliseconds: 220);

  /// La caja visible (una sola a la vez en toda la app; ui_style.md §
  /// "Tooltips").
  static _RetroHoverCardState? _active;

  /// ¿Hay una caja abierta? (tests).
  static bool get anyShowing => _active != null;

  /// Cierra la caja abierta, si hay (cambio de pantalla, menú contextual).
  static void dismissAll() => _active?._hide();

  /// Contenido; se arma recién al mostrarse.
  final WidgetBuilder builder;
  final Widget child;
  final double gap;
  final double margin;
  final RetroTipPlacement placement;

  /// Texto del `#tip`: lectura ([RetroType.small], VT323) `#e8ecff`.
  static TextStyle get textStyle => TextStyle(
      fontFamily: RetroType.bodyFamily,
      letterSpacing: RetroType.letterSpacing,
      fontFamilyFallback: RetroType.bodyFallback,
      fontSize: RetroType.small,
      height: RetroType.line,
      color: ProtoColors.ink);

  /// Ancho máximo del texto de un tip en Normal (~45 letras de VT323);
  /// crece con el tamaño del texto ([RetroType.width]).
  static const textWidth = 360.0;

  /// Padding interno de la caja (8 × 10 del `#tip`; más en AMPLIO).
  static EdgeInsets get padding => EdgeInsets.symmetric(
      horizontal: UiTheme.space(10), vertical: UiTheme.space(8));

  /// Borde de la caja: dorado en AZUL (como el prototipo); en OSCURO y
  /// ALTO CONTRASTE un gris / blanco (el dorado queda para el foco).
  static Color get borderColor => switch (UiTheme.kind) {
        InterfaceTheme.blue => ProtoColors.gold,
        InterfaceTheme.dark => ProtoColors.buttonBorder,
        InterfaceTheme.highContrast => ProtoColors.buttonBorder,
      };

  @override
  State<RetroHoverCard> createState() => _RetroHoverCardState();
}

class _RetroHoverCardState extends State<RetroHoverCard> {
  final _portal = OverlayPortalController();
  Timer? _closer;
  bool _overTarget = false;
  bool _overBox = false;

  /// Solo si su pantalla es la de arriba: una caja de una ruta tapada no
  /// se abre (ni queda abierta).
  bool get _routeCurrent => ModalRoute.of(context)?.isCurrent ?? true;

  void _show() {
    _closer?.cancel();
    if (!mounted || !_routeCurrent) return;
    final other = RetroHoverCard._active;
    if (other != null && other != this) other._hide();
    RetroHoverCard._active = this;
    if (!_portal.isShowing) _portal.show();
  }

  void _hide() {
    _closer?.cancel();
    _overTarget = false;
    _overBox = false;
    if (RetroHoverCard._active == this) RetroHoverCard._active = null;
    if (_portal.isShowing) _portal.hide();
  }

  /// Salida del objetivo o de la caja: en una caja [interactive] espera
  /// un poco por si el mouse va hacia la caja.
  void _leave() {
    if (!widget.interactive) return _hide();
    _closer?.cancel();
    _closer = Timer(RetroHoverCard.pinDelay, () {
      if (!_overTarget && !_overBox) _hide();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Cambió la pantalla (se tapó la ruta): fuera la caja.
    if (!_routeCurrent && _portal.isShowing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _hide();
      });
    }
  }

  @override
  void deactivate() {
    // Sale del árbol (cambió la pantalla): deja de ser la caja activa.
    // El portal se va con el elemento; si vuelve (se movió), se cierra
    // después del cuadro (no se puede ocultar en medio del build).
    _closer?.cancel();
    _overTarget = false;
    _overBox = false;
    if (RetroHoverCard._active == this) RetroHoverCard._active = null;
    if (_portal.isShowing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && RetroHoverCard._active != this) _hide();
      });
    }
    super.deactivate();
  }

  @override
  void dispose() {
    _closer?.cancel();
    if (RetroHoverCard._active == this) RetroHoverCard._active = null;
    super.dispose();
  }

  Rect? _targetRect(BuildContext overlayContext) {
    final box = context.findRenderObject();
    final overlay = Overlay.maybeOf(context)?.context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || overlay is! RenderBox) {
      return null;
    }
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    return topLeft & box.size;
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (ctx) {
        final rect = _targetRect(ctx);
        if (rect == null) return const SizedBox.shrink();
        final box = widget.interactive
            ? MouseRegion(
                key: const ValueKey('retro-tip-pinned'),
                onEnter: (_) {
                  _overBox = true;
                  _closer?.cancel();
                },
                onExit: (_) {
                  _overBox = false;
                  _leave();
                },
                child: _box(ctx),
              )
            : _box(ctx);
        return Positioned.fill(
          child: CustomSingleChildLayout(
            delegate: _HoverLayout(rect, widget.gap, widget.margin,
                widget.placement, MediaQuery.devicePixelRatioOf(ctx)),
            child: widget.interactive ? box : IgnorePointer(child: box),
          ),
        );
      },
      // Con el teclado: aparece mientras el foco está en el objetivo (o
      // adentro), como con el mouse (docs/specs/panels.md § "Teclado").
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (f) => f &&
                FocusManager.instance.highlightMode ==
                    FocusHighlightMode.traditional
            ? _show()
            : _hide(),
        child: MouseRegion(
          onEnter: (_) {
            _overTarget = true;
            _show();
          },
          onExit: (_) {
            _overTarget = false;
            _leave();
          },
          // Como el Tooltip: un clic o un arrastre lo esconde.
          child: Listener(
            onPointerDown: (_) => _hide(),
            child: widget.child,
          ),
        ),
      ),
    );
  }

  Widget _box(BuildContext ctx) => Container(
        padding: RetroHoverCard.padding,
        decoration: BoxDecoration(
          color: ProtoColors.bg.withValues(alpha: 0xF5 / 0xFF),
          border: Border.all(
              color: RetroHoverCard.borderColor,
              width: UiTheme.buttonBorderWidth),
          boxShadow: const [
            BoxShadow(
                color: ProtoColors.shadow, offset: Offset(0, 4), blurRadius: 18),
          ],
        ),
        // El overlay no hereda el estilo de texto del panel.
        child: DefaultTextStyle(
          style: RetroHoverCard.textStyle,
          child: LayoutBuilder(
            builder: (context, c) => FittedBox(
              // Último recurso: si ni en columnas entra, se achica.
              fit: BoxFit.scaleDown,
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: c.maxWidth),
                child: RetroTipBounds(
                  maxHeight: c.maxHeight,
                  child: Builder(builder: widget.builder),
                ),
              ),
            ),
          ),
        ),
      );
}

/// Alto disponible dentro de la caja de un tip (la pantalla menos los
/// márgenes y el padding), para que el contenido se reparta en columnas.
class RetroTipBounds extends InheritedWidget {
  const RetroTipBounds(
      {super.key, required this.maxHeight, required super.child});

  final double maxHeight;

  static double? maxHeightOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RetroTipBounds>()?.maxHeight;

  @override
  bool updateShouldNotify(RetroTipBounds old) => old.maxHeight != maxHeight;
}

/// Texto de un tip (markup, `ProtoMarkup`) de ancho máximo [maxWidth]
/// (ya agrandado por el tamaño del texto). Si no entra en el alto de la
/// pantalla se reparte en columnas, cortando en los `<br>`.
class RetroTipText extends StatelessWidget {
  const RetroTipText(this.markup, {super.key, required this.maxWidth});

  final String markup;
  final double maxWidth;

  /// Separación entre columnas.
  static const columnGap = 16.0;

  /// Línea que abre una sección (`<span class="k">Mods…`): en AMPLIO
  /// lleva un separador arriba.
  static bool startsSection(String line) {
    final t = line.trimLeft();
    return t.startsWith('<span class="k">') || t.startsWith("<span class='k'>");
  }

  @override
  Widget build(BuildContext context) {
    final maxH = RetroTipBounds.maxHeightOf(context);
    if (UiTheme.wide) return _wide(maxH);
    final text = ProtoText(markup);
    if (maxH == null || !maxH.isFinite) {
      return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth), child: text);
    }
    final lines = protoSplitLines(markup);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Wrap(
        direction: Axis.vertical,
        runSpacing: columnGap,
        children: [
          for (final l in lines)
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: ProtoText(l),
            ),
        ],
      ),
    );
  }
}

extension on RetroTipText {
  /// ESPACIADO AMPLIO (accessibility.md § 8.3): una línea por párrafo con
  /// aire entre medio y un separador antes de cada sección; si no entra
  /// en el alto, en columnas como siempre.
  Widget _wide(double? maxH) {
    final lines = protoSplitLines(markup);
    final children = <Widget>[
      for (var i = 0; i < lines.length; i++) ...[
        if (i > 0 && RetroTipText.startsSection(lines[i]))
          Container(
            key: ValueKey('tip-rule-$i'),
            width: maxWidth,
            height: 1,
            margin: const EdgeInsets.symmetric(vertical: 3),
            color: ProtoColors.panelBorder,
          ),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: ProtoText(lines[i]),
        ),
      ],
    ];
    return ConstrainedBox(
      constraints: BoxConstraints(
          maxHeight: maxH != null && maxH.isFinite ? maxH : double.infinity),
      child: Wrap(
        direction: Axis.vertical,
        spacing: UiTheme.paragraphGap,
        runSpacing: RetroTipText.columnGap,
        children: children,
      ),
    );
  }
}

/// Al lado de [target] ([RetroTipPlacement.side]: derecha, si no entra
/// izquierda; [RetroTipPlacement.below]: debajo centrada, si no entra
/// arriba), siempre dentro de la pantalla con [margin].
class _HoverLayout extends SingleChildLayoutDelegate {
  _HoverLayout(this.target, this.gap, this.margin, this.placement, this.dpr);

  final Rect target;
  final double gap;
  final double margin;
  final RetroTipPlacement placement;

  /// Para caer en px físicos enteros: la fuente pixel se ve nítida solo
  /// si el texto arranca en un píxel entero.
  final double dpr;

  double _px(double v) => (v * dpr).roundToDouble() / dpr;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(Size(
        (constraints.maxWidth - 2 * margin).clamp(0, double.infinity),
        (constraints.maxHeight - 2 * margin).clamp(0, double.infinity),
      ));

  @override
  Offset getPositionForChild(Size size, Size child) {
    final maxX =
        (size.width - margin - child.width).clamp(margin, double.infinity);
    final maxY =
        (size.height - margin - child.height).clamp(margin, double.infinity);
    double x, y;
    switch (placement) {
      case RetroTipPlacement.side:
        x = target.right + gap;
        if (x + child.width > size.width - margin) {
          x = target.left - gap - child.width;
        }
        y = target.top;
      case RetroTipPlacement.below:
        x = target.center.dx - child.width / 2;
        y = target.bottom + gap;
        if (y + child.height > size.height - margin) {
          final above = target.top - gap - child.height;
          // Arriba si entra; si no, del lado con más lugar (y se corre).
          y = above >= margin || target.top > size.height - target.bottom
              ? above
              : y;
        }
    }
    return Offset(_px(x.clamp(margin, maxX)), _px(y.clamp(margin, maxY)));
  }

  @override
  bool shouldRelayout(_HoverLayout old) =>
      old.target != target ||
      old.gap != gap ||
      old.margin != margin ||
      old.placement != placement ||
      old.dpr != dpr;
}

/// Sección plegable de un tip (ui_style.md § "Tooltips cortos"): una
/// línea `▸ Título` (`sky`) que se despliega con clic, Enter o Espacio y
/// muestra [body] (markup) debajo; `▼` cuando está abierta. Cerrada por
/// defecto ([initiallyOpen]).
class RetroTipFold extends StatefulWidget {
  const RetroTipFold({
    super.key,
    required this.title,
    required this.body,
    this.maxWidth,
    this.initiallyOpen = false,
  });

  final String title;
  final String body;
  final double? maxWidth;
  final bool initiallyOpen;

  @override
  State<RetroTipFold> createState() => _RetroTipFoldState();
}

class _RetroTipFoldState extends State<RetroTipFold> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final head = FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => setState(() => _open = !_open)),
      },
      child: GestureDetector(
        key: ValueKey('tip-fold-${widget.title}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _open = !_open),
        child: ProtoText(protoColor(
            ProtoColors.sky, '${_open ? '▼' : '▸'} ${protoEsc(widget.title)}')),
      ),
    );
    final w = widget.maxWidth;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        head,
        if (_open)
          Padding(
            key: ValueKey('tip-fold-body-${widget.title}'),
            padding: const EdgeInsets.only(left: 12),
            child: w == null
                ? ProtoText(widget.body)
                : ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: w - 12),
                    child: ProtoText(widget.body)),
          ),
      ],
    );
  }
}

/// Resumen + secciones plegables: lo esencial a la vista y el resto en
/// [RetroTipFold] (`(título, markup)`; las vacías no se dibujan).
class RetroTipFolds extends StatelessWidget {
  const RetroTipFolds(
      {super.key,
      required this.summary,
      required this.sections,
      required this.maxWidth});

  final String summary;
  final List<(String, String)> sections;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProtoText(summary),
            for (final (t, b) in sections)
              if (b.isNotEmpty)
                RetroTipFold(title: t, body: b, maxWidth: maxWidth),
          ],
        ),
      );
}
