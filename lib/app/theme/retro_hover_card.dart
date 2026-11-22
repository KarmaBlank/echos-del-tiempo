import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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
    this.keyboardFocus = false,
    this.pinOnClick = false,
    this.hint,
    this.frameless = false,
  });

  /// Sin la caja del `#tip`: [builder] trae su propia tarjeta (p. ej.
  /// `DsTooltipCard`), que scrollea en el alto que le toca.
  final bool frameless;

  /// Tooltip atravesable (v0.9.13, ui_style.md § "Tooltips cortos"): no
  /// toma el mouse (pasar a otra casilla, aunque la caja la tape, cambia
  /// al instante) y se pega a la casilla del lado con más lugar sin
  /// taparla. Un clic izquierdo sobre el objetivo la fija (ahí sí toma
  /// el mouse: scroll y ▸); Esc o un clic afuera la sueltan.
  final bool pinOnClick;

  /// Línea de ayuda chiquita al pie (p. ej. `Alt: detalle · ...`).
  final String? hint;

  /// Teclas que se mantienen apretadas mientras hay una caja: Alt
  /// despliega todos los ▸ y Shift compara con la equipada.
  static final altHeld = ValueNotifier<bool>(false);
  static final shiftHeld = ValueNotifier<bool>(false);

  /// Lee Alt / Shift del teclado (también al abrir una caja).
  static void syncModifiers() {
    final k = HardwareKeyboard.instance;
    altHeld.value = k.isAltPressed;
    shiftHeld.value = k.isShiftPressed;
  }

  /// ¿La caja abierta está fijada con clic? (tests).
  static bool get pinned => _active?._pinned ?? false;

  /// El objetivo tiene el cursor de teclado aunque el foco esté en un
  /// ancestro (casilla de una grilla): con el teclado se muestra igual
  /// que con el mouse (v0.9.9, panels.md § "Teclado").
  final bool keyboardFocus;

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

  /// Mientras hay un menú contextual abierto no se abre ninguna caja
  /// (nunca tooltip y menú a la vez; ui_style.md § "Tooltips").
  static bool suppressed = false;

  /// ¿La última entrada fue una tecla (no modificadora) y no el puntero?
  /// Los tips por foco solo se abren así (v0.19.1): `highlightMode` de
  /// Flutter queda en `traditional` también con el mouse en escritorio,
  /// y el autofocus al abrir / cambiar de pestaña mostraba el tip del
  /// primer elemento con el mouse quieto.
  static bool get keyboardNav {
    _installInputTracker();
    return _keyboardNav;
  }

  static set keyboardNav(bool v) {
    _installInputTracker();
    _keyboardNav = v;
  }

  static bool _keyboardNav = false;
  static bool _trackerOn = false;

  static void _installInputTracker() {
    // Idempotente: los tests de widgets limpian los handlers del teclado.
    HardwareKeyboard.instance
      ..removeHandler(_onKey)
      ..addHandler(_onKey);
    if (_trackerOn) return;
    _trackerOn = true;
    GestureBinding.instance.pointerRouter.addGlobalRoute((e) {
      if (e is PointerDownEvent ||
          e is PointerSignalEvent ||
          (e is PointerHoverEvent && e.delta != Offset.zero)) {
        _keyboardNav = false;
      }
    });
  }

  static bool _onKey(KeyEvent e) {
    if (e is KeyDownEvent && !_isModifier(e.logicalKey)) _keyboardNav = true;
    return false;
  }

  static bool _isModifier(LogicalKeyboardKey k) => _modifiers.contains(k);

  static final _modifiers = {
    LogicalKeyboardKey.altLeft,
    LogicalKeyboardKey.altRight,
    LogicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.shiftRight,
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.controlRight,
    LogicalKeyboardKey.metaLeft,
    LogicalKeyboardKey.metaRight,
  };

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

  /// Fijada con clic ([RetroHoverCard.pinOnClick]).
  bool _pinned = false;

  /// Abierta por [RetroHoverCard.keyboardFocus] (no por el mouse).
  bool _byKeyboard = false;

  /// Solo si su pantalla es la de arriba: una caja de una ruta tapada no
  /// se abre (ni queda abierta).
  bool get _routeCurrent => ModalRoute.of(context)?.isCurrent ?? true;

  @override
  void initState() {
    super.initState();
    RetroHoverCard._installInputTracker();
    if (widget.keyboardFocus) _syncKeyboard();
  }

  @override
  void didUpdateWidget(RetroHoverCard old) {
    super.didUpdateWidget(old);
    if (widget.keyboardFocus != old.keyboardFocus) _syncKeyboard();
  }

  void _syncKeyboard() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.keyboardFocus) {
        if (RetroHoverCard.keyboardNav) {
          _byKeyboard = true;
          _show();
        }
      } else if (!_overTarget && RetroHoverCard._active == this) {
        _hide();
      }
    });
  }

  void _show() {
    _closer?.cancel();
    if (!mounted || !_routeCurrent || RetroHoverCard.suppressed) return;
    final other = RetroHoverCard._active;
    // Una caja fijada no se reemplaza al pasar por otra casilla.
    if (other != null && other != this && other._pinned) return;
    if (other != null && other != this) other._hide();
    RetroHoverCard.syncModifiers();
    RetroHoverCard._active = this;
    if (!_portal.isShowing) _portal.show();
    _listen(true);
  }

  final _boxKey = GlobalKey();
  final _scroll = ScrollController();
  bool _listening = false;

  /// Mientras está abierta: Esc y un clic fuera de la caja la cierran
  /// (ui_style.md § "Tooltips cortos"; nunca queda pegada).
  void _listen(bool on) {
    if (on == _listening) return;
    _listening = on;
    final router = GestureBinding.instance.pointerRouter;
    if (on) {
      router.addGlobalRoute(_onPointer);
      HardwareKeyboard.instance.addHandler(_onKey);
    } else {
      router.removeGlobalRoute(_onPointer);
      HardwareKeyboard.instance.removeHandler(_onKey);
    }
  }

  void _onPointer(PointerEvent e) {
    if (e is! PointerDownEvent || !_portal.isShowing) return;
    final box = _boxKey.currentContext?.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      final r = box.localToGlobal(Offset.zero) & box.size;
      if (r.contains(e.position)) return;
    }
    // Clic sobre el objetivo de una caja que se fija: lo maneja el
    // objetivo (fija o suelta).
    if (widget.pinOnClick) {
      final t = context.findRenderObject();
      if (t is RenderBox && t.hasSize) {
        final r = t.localToGlobal(Offset.zero) & t.size;
        if (r.contains(e.position)) return;
      }
    }
    _hide();
  }

  bool _onKey(KeyEvent e) {
    RetroHoverCard.syncModifiers();
    // Abierta por el cursor de teclado: Esc sigue siendo del panel.
    if (_byKeyboard || !_portal.isShowing) return false;
    if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.escape) {
      _hide();
      return true;
    }
    return false;
  }

  void _hide() {
    _listen(false);
    _byKeyboard = false;
    _closer?.cancel();
    _overTarget = false;
    _overBox = false;
    _pinned = false;
    if (RetroHoverCard._active == this) RetroHoverCard._active = null;
    if (_portal.isShowing) _portal.hide();
  }

  /// Salida del objetivo o de la caja: en una caja [interactive] espera
  /// un poco por si el mouse va hacia la caja.
  void _leave() {
    if (_pinned) return;
    if (widget.pinOnClick || !widget.interactive) return _hide();
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
    _listen(false);
    _overTarget = false;
    _overBox = false;
    _pinned = false;
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
    _scroll.dispose();
    _listen(false);
    _closer?.cancel();
    if (RetroHoverCard._active == this) RetroHoverCard._active = null;
    super.dispose();
  }

  /// Zona permitida de [RetroTipArea] en coordenadas del overlay.
  Rect? _areaRect() {
    final scope = context.getInheritedWidgetOfExactType<RetroTipArea>();
    final overlay = Overlay.maybeOf(context)?.context.findRenderObject();
    if (scope == null || overlay is! RenderBox || !overlay.hasSize) {
      return null;
    }
    final g = scope.bounds();
    if (g == null) return null;
    final o = overlay.localToGlobal(Offset.zero);
    final all = Offset.zero & overlay.size;
    final r = g.shift(-o).intersect(all);
    return r.width <= 0 || r.height <= 0 ? null : r;
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
        final box = widget.interactive && !widget.pinOnClick
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
        final takesMouse =
            widget.pinOnClick ? _pinned : widget.interactive && !_byKeyboard;
        final child = takesMouse
            ? box
            // Abierta por el cursor de teclado: no toma el mouse (no
            // tapa botones que estén debajo).
            : IgnorePointer(child: box);
        final area = _areaRect();
        if (area == null) {
          return Positioned.fill(
            child: CustomSingleChildLayout(
              delegate: _HoverLayout(rect, widget.gap, widget.margin,
                  widget.placement, MediaQuery.devicePixelRatioOf(ctx),
                  beside: widget.pinOnClick),
              child: child,
            ),
          );
        }
        // Dentro de la zona de [RetroTipArea]: la caja (y lo que mide el
        // ancho con MediaQuery, p. ej. la ficha comparada) no sale de ahí.
        return Positioned.fromRect(
          rect: area,
          child: MediaQuery(
            data: MediaQuery.of(ctx).copyWith(size: area.size),
            child: CustomSingleChildLayout(
              delegate: _HoverLayout(
                  rect.shift(-area.topLeft),
                  widget.gap,
                  widget.margin,
                  widget.placement,
                  MediaQuery.devicePixelRatioOf(ctx),
                  beside: widget.pinOnClick),
              child: child,
            ),
          ),
        );
      },
      // Con el teclado: aparece mientras el foco está en el objetivo (o
      // adentro), como con el mouse (docs/specs/panels.md § "Teclado").
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (f) => f && RetroHoverCard.keyboardNav
            ? _show()
            : _hide(),
        child: MouseRegion(
          onEnter: (_) {
            _overTarget = true;
            _byKeyboard = false;
            _show();
          },
          onExit: (_) {
            _overTarget = false;
            _leave();
          },
          // Como el Tooltip: un clic o un arrastre lo esconde.
          child: Listener(
            onPointerDown: (e) {
              if (!widget.pinOnClick || e.buttons != kPrimaryButton) {
                return _hide();
              }
              // Clic izquierdo: fija (o suelta si ya estaba fijada).
              if (_pinned) return _hide();
              _byKeyboard = false;
              _show();
              if (RetroHoverCard._active == this) {
                setState(() => _pinned = true);
              }
            },
            child: widget.child,
          ),
        ),
      ),
    );
  }

  double _columnsBound(BuildContext ctx, double room) {
    final screen = MediaQuery.sizeOf(ctx).height -
        2 * widget.margin -
        RetroHoverCard.padding.vertical -
        2 * UiTheme.buttonBorderWidth;
    return screen > room ? screen : room;
  }

  Widget _box(BuildContext ctx) => widget.frameless
      ? KeyedSubtree(
          key: _boxKey,
          child: DefaultTextStyle(
              style: RetroHoverCard.textStyle,
              child: Builder(builder: widget.builder)))
      : Container(
        key: _boxKey,
        padding: RetroHoverCard.padding,
        decoration: BoxDecoration(
          color: ProtoColors.bg.withValues(alpha: 0xF5 / 0xFF),
          border: Border.all(
              color: RetroHoverCard.borderColor,
              width: UiTheme.buttonBorderWidth),
          boxShadow: const [
            BoxShadow(
                color: ProtoColors.shadow,
                offset: Offset(0, 4),
                blurRadius: 18),
          ],
        ),
        // El overlay no hereda el estilo de texto del panel.
        child: DefaultTextStyle(
          style: RetroHoverCard.textStyle,
          // La letra nunca se achica: si no entra en el alto máximo, la
          // caja scrollea con la rueda (ui_style.md § "Tooltips cortos").
          child: LayoutBuilder(
            builder: (context, c) => RawScrollbar(
              key: const ValueKey('retro-tip-scroll'),
              controller: _scroll,
              thumbVisibility: true,
              thumbColor: ProtoColors.buttonBorder,
              thickness: 4,
              child: SingleChildScrollView(
                controller: _scroll,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: c.maxWidth),
                  child: RetroTipBounds(
                    // Columnas solo si no entra en la pantalla entera;
                    // si no entra en el lugar de su lado, scrollea.
                    maxHeight: _columnsBound(ctx, c.maxHeight),
                    child: widget.hint == null
                        ? Builder(builder: widget.builder)
                        // La ayuda corta en el ancho de la ficha: nunca
                        // la ensancha (una ayuda larga con texto grande
                        // la hacía más ancha que la columna).
                        : _HintBelow(
                            gap: 4,
                            children: [
                              Builder(builder: widget.builder),
                              Text(
                                  _pinned
                                      ? 'Fijado · Esc o clic afuera: soltar'
                                      : widget.hint!,
                                  key: const ValueKey('retro-tip-hint'),
                                  style: RetroHoverCard.textStyle.copyWith(
                                      fontSize: RetroType.small * 0.85,
                                      color: ProtoColors.dim)),
                            ],
                          ),
                  ),
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

/// Zona de la pantalla donde se abren los tooltips de los descendientes
/// (v0.9.9): en el INVENTARIO, todo lo que está a la izquierda de
/// ESTADÍSTICAS, para no tapar el panel que se quiere mirar.
/// [bounds] devuelve el rectángulo en coordenadas globales (`null` = sin
/// límite).
class RetroTipArea extends InheritedWidget {
  const RetroTipArea({super.key, required this.bounds, required super.child});

  final Rect? Function() bounds;

  @override
  bool updateShouldNotify(RetroTipArea old) => false;
}

/// Al lado de [target] ([RetroTipPlacement.side]: derecha, si no entra
/// izquierda; [RetroTipPlacement.below]: debajo centrada, si no entra
/// arriba), siempre dentro de la pantalla con [margin].
class _HoverLayout extends SingleChildLayoutDelegate {
  _HoverLayout(this.target, this.gap, this.margin, this.placement, this.dpr,
      {this.beside = false});

  /// Pegada al lado con más lugar, sin tapar nunca [target].
  final bool beside;

  final Rect target;
  final double gap;
  final double margin;
  final RetroTipPlacement placement;

  /// Para caer en px físicos enteros: la fuente pixel se ve nítida solo
  /// si el texto arranca en un píxel entero.
  final double dpr;

  double _px(double v) => (v * dpr).roundToDouble() / dpr;

  /// Lugar mínimo (px lógicos) que tiene que haber debajo para quedarse
  /// debajo aunque arriba haya más (ui_style.md § "Tooltips anclados").
  static const minRoom = 160.0;

  double _roomBelow(Size size) =>
      (size.height - margin - (target.bottom + gap)).clamp(0, double.infinity);
  double _roomAbove(Size size) =>
      (target.top - gap - margin).clamp(0, double.infinity);

  /// Lado vertical elegido solo por la geometría del objetivo (nunca por
  /// el alto de la caja): crecer (▸ Ver más) no la hace saltar.
  bool _goesBelow(Size size) {
    final b = _roomBelow(size);
    return b >= minRoom || b >= _roomAbove(size);
  }

  /// Arriba de la caja de costado: a la altura del objetivo, subida solo
  /// lo justo para dejar [minRoom] (o media pantalla) de alto; tampoco
  /// depende del alto de la caja.
  double _sideTop(Size size) {
    final want = (size.height / 2).clamp(minRoom, double.infinity);
    final maxTop = size.height - margin - want;
    return target.top.clamp(margin, maxTop < margin ? margin : maxTop);
  }

  /// Anclada debajo (o arriba, pegada al objetivo): no se corre; si no
  /// entra, el alto máximo es el lugar de ese lado y la caja scrollea.
  double _vertical(Size size, Size child) => _goesBelow(size)
      ? target.bottom + gap
      : target.top - gap - child.height;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final size = constraints.biggest;
    final h = beside || placement == RetroTipPlacement.side
        ? size.height - margin - _sideTop(size)
        : _goesBelow(size)
            ? _roomBelow(size)
            : _roomAbove(size);
    return BoxConstraints.loose(Size(
      (constraints.maxWidth - 2 * margin).clamp(0, double.infinity),
      h.clamp(0, double.infinity),
    ));
  }

  @override
  Offset getPositionForChild(Size size, Size child) {
    final maxX =
        (size.width - margin - child.width).clamp(margin, double.infinity);
    final maxY =
        (size.height - margin - child.height).clamp(margin, double.infinity);
    double x, y;
    if (beside) {
      final right = target.right + gap;
      final left = target.left - gap - child.width;
      final roomR = size.width - margin - right;
      final roomL = target.left - gap - margin;
      final fitsR = child.width <= roomR, fitsL = child.width <= roomL;
      if (fitsR || fitsL) {
        x = (fitsR && (roomR >= roomL || !fitsL)) ? right : left;
        return Offset(_px(x), _px(_sideTop(size)));
      }
      // No entra a ningún costado: debajo o arriba, sin tapar la casilla.
      x = (target.center.dx - child.width / 2).clamp(margin, maxX);
      return Offset(_px(x), _px(_vertical(size, child).clamp(margin, maxY)));
    }
    switch (placement) {
      case RetroTipPlacement.side:
        x = target.right + gap;
        if (x + child.width > size.width - margin) {
          x = target.left - gap - child.width;
        }
        y = _sideTop(size);
        if (x < margin) {
          // No entra a ningún costado: debajo (o arriba) de la casilla.
          x = target.center.dx - child.width / 2;
          y = _vertical(size, child);
        }
      case RetroTipPlacement.below:
        x = target.center.dx - child.width / 2;
        y = _vertical(size, child);
    }
    return Offset(_px(x.clamp(margin, maxX)), _px(y.clamp(margin, maxY)));
  }

  @override
  bool shouldRelayout(_HoverLayout old) =>
      old.target != target ||
      old.gap != gap ||
      old.margin != margin ||
      old.placement != placement ||
      old.dpr != dpr ||
      old.beside != beside;
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
    this.titleIsMarkup = false,
  });

  /// [title] ya es markup (sub-plegables de habilidades).
  final bool titleIsMarkup;

  final String title;
  final String body;
  final double? maxWidth;
  final bool initiallyOpen;

  @override
  State<RetroTipFold> createState() => _RetroTipFoldState();
}

class _RetroTipFoldState extends State<RetroTipFold> {
  late bool _open = widget.initiallyOpen;

  /// El cuerpo; las líneas `cabeza\u0001detalle` (`tipSubFold`) van
  /// como sub-plegables.
  Widget _body(double? w) {
    final body = widget.body;
    if (!body.contains('\u0001')) return ProtoText(body);
    final lines = body.split('<br>');
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, l) in lines.indexed)
          if (l.contains('\u0001'))
            RetroTipFold(
              key: ValueKey('tip-subfold-${widget.title}-$i'),
              title: l.split('\u0001').first,
              titleIsMarkup: true,
              body: l.split('\u0001').last.replaceAll('\u0002', '<br>'),
              maxWidth: w,
            )
          else
            ProtoText(l),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
      valueListenable: RetroHoverCard.altHeld,
      builder: (context, alt, _) => _build(context, _open || alt));

  Widget _build(BuildContext context, bool open) {
    final head = FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => setState(() => _open = !_open)),
      },
      child: GestureDetector(
        key: widget.titleIsMarkup ? null : ValueKey('tip-fold-${widget.title}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _open = !_open),
        child: ProtoText(widget.titleIsMarkup
            ? '${protoColor(ProtoColors.sky, open ? '▼' : '▸')} ${widget.title}'
            : protoColor(ProtoColors.sky,
                '${open ? '▼' : '▸'} ${protoEsc(widget.title)}')),
      ),
    );
    final w = widget.maxWidth;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        head,
        if (open)
          Padding(
            key: ValueKey('tip-fold-body-${widget.title}'),
            padding: const EdgeInsets.only(left: 12),
            child: w == null
                ? _body(null)
                : ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: w - 12),
                    child: _body(w - 12)),
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

/// [children] = (contenido, ayuda): la ayuda va debajo con el ancho del
/// contenido (se parte en líneas si no entra), sin agrandar la caja.
class _HintBelow extends MultiChildRenderObjectWidget {
  const _HintBelow({required this.gap, required super.children});

  final double gap;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderHintBelow(gap);

  @override
  void updateRenderObject(BuildContext context, _RenderHintBelow r) =>
      r.gap = gap;
}

class _HintParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderHintBelow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _HintParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _HintParentData> {
  _RenderHintBelow(this._gap);

  double _gap;
  set gap(double v) {
    if (v == _gap) return;
    _gap = v;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _HintParentData) {
      child.parentData = _HintParentData();
    }
  }

  @override
  void performLayout() {
    final body = firstChild!;
    final hint = childAfter(body)!;
    body.layout(constraints.loosen(), parentUsesSize: true);
    final w = body.size.width;
    hint.layout(BoxConstraints(maxWidth: w), parentUsesSize: true);
    (body.parentData! as _HintParentData).offset = Offset.zero;
    (hint.parentData! as _HintParentData).offset =
        Offset(0, body.size.height + _gap);
    size = constraints
        .constrain(Size(w, body.size.height + _gap + hint.size.height));
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
