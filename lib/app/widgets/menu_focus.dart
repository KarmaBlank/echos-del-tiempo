import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/proto_colors.dart';

/// Sistema de foco de teclado común a todos los menús (docs/specs/
/// panels.md § "Teclado en los menús (v0.5.1)"). Piezas:
///
/// - [FocusRing]: el aro dorado + cursor ▶ del elemento con foco.
/// - [MenuFocusable]: cualquier tarjeta / fila clicable con foco, aro,
///   `Enter` / `Espacio` = clic.
/// - [MenuTabKeys]: `Q` / `E`, `Ctrl+Tab` / `Ctrl+Shift+Tab`, `RePág` /
///   `AvPág` y los números `1`..`9` cambian de pestaña.
/// - [NavSection]: una sección (lista, detalle, grupo de tarjetas): las
///   flechas se mueven dentro y `Tab` / `Shift+Tab` saltan a la sección
///   siguiente / anterior.
/// - [FocusGrid]: grilla de casillas (inventario, alijo): las flechas
///   mueven el cursor casilla por casilla, `Enter` la activa.
/// - [MenuKeyScope]: el teclado de [PanelFrame] para pantallas que no son
///   un panel (título): flechas, `Tab`, `Enter`, `Esc` y números.
/// - [InitialFocus]: al abrir, el foco va al primer elemento (o al que se
///   marque) en vez de quedar en el marco.
///
/// Con un campo de texto enfocado nada de esto toca las teclas.

/// Las teclas de los menús, para el `[?]`, CONTROLES y el spec.
const kMenuKeys = <(String, String)>[
  ('Flechas', 'Mover el foco (aro dorado ▶) dentro de la lista o grilla'),
  ('Tab / Shift+Tab', 'Saltar a la sección siguiente / anterior'),
  ('Enter / Espacio', 'Elegir o activar lo que tiene el foco'),
  ('Esc', 'Volver un paso; si no hay, cerrar el panel (sin panel: pausa)'),
  ('Q / E', 'Pestaña anterior / siguiente'),
  ('Ctrl+Tab', 'Pestaña siguiente (Ctrl+Shift+Tab: anterior)'),
  ('1 - 9', 'Ir a la pestaña N (o al personaje / clase N en el título)'),
  ('Inventario', 'Flechas mueven la casilla; Enter otra vez equipa el arma'),
];

/// Hay un campo de texto con el foco: las teclas son suyas.
bool typingInField() {
  final ctx = FocusManager.instance.primaryFocus?.context;
  return ctx != null &&
      ctx.findAncestorWidgetOfExactType<EditableText>() != null;
}

/// El aro de foco se dibuja solo si se está usando el teclado (como los
/// botones de Flutter): con el mouse no molesta.
bool get keyboardHighlight =>
    FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

/// Aro de foco: borde dorado de 2 px **por fuera** de [child] (no cambia
/// el tamaño ni empuja nada) y, con [pointer], el cursor ▶ dorado pegado
/// al borde izquierdo, como el cursor de un JRPG. Distinto del borde
/// `gold` de "elegida" (ese va por dentro).
class FocusRing extends StatelessWidget {
  const FocusRing({
    super.key,
    required this.focused,
    required this.child,
    this.pointer = true,
  });

  final bool focused;
  final bool pointer;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Siempre el mismo árbol (con o sin aro): si no, el hijo perdería su
    // estado al ganar el foco (p. ej. un arrastre en curso).
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (focused)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                key: const ValueKey('focus-ring'),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: ProtoColors.gold,
                      width: 2,
                      strokeAlign: BorderSide.strokeAlignOutside),
                ),
              ),
            ),
          ),
        if (focused && pointer)
          const Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Center(
                child:
                    CustomPaint(size: Size(6, 10), painter: _PointerPainter()),
              ),
            ),
          ),
      ],
    );
  }
}

/// Triángulo ▶ de 6 × 10 px (pixel art: escalones de 2 px).
class _PointerPainter extends CustomPainter {
  const _PointerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = ProtoColors.gold;
    canvas
      ..drawRect(const Rect.fromLTWH(0, 0, 2, 10), p)
      ..drawRect(const Rect.fromLTWH(2, 2, 2, 6), p)
      ..drawRect(const Rect.fromLTWH(4, 4, 2, 2), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Envoltorio clicable con foco de teclado: clic / `Enter` / `Espacio` =
/// [onTap], aro de foco ([FocusRing]) y [builder] con `hot` (mouse o
/// foco) para que la tarjeta se resalte a su manera.
class MenuFocusable extends StatefulWidget {
  const MenuFocusable({
    super.key,
    required this.onTap,
    required this.builder,
    this.focusNode,
    this.autofocus = false,
    this.pointer = true,
    this.onHover,
    this.onFocus,
    this.onKeyActivate,
  });

  /// El cursor del teclado llegó acá (p. ej. elegir la clase al pasar).
  final VoidCallback? onFocus;

  /// `Enter` / `Espacio` (si no, [onTap]): p. ej. jugar con el personaje
  /// que ya está elegido.
  final VoidCallback? onKeyActivate;

  final VoidCallback onTap;
  final Widget Function(BuildContext context, bool hot) builder;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool pointer;

  /// Mouse o foco entró / salió.
  final ValueChanged<bool>? onHover;

  @override
  State<MenuFocusable> createState() => _MenuFocusableState();
}

class _MenuFocusableState extends State<MenuFocusable> {
  bool _hover = false, _focus = false;

  void _set({bool? hover, bool? focus}) {
    final was = _hover || _focus;
    setState(() {
      _hover = hover ?? _hover;
      _focus = focus ?? _focus;
    });
    final now = _hover || _focus;
    if (now != was) widget.onHover?.call(now);
  }

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      mouseCursor: SystemMouseCursors.click,
      onShowFocusHighlight: (v) {
        _set(focus: v);
        if (v) widget.onFocus?.call();
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => (widget.onKeyActivate ?? widget.onTap)()),
      },
      child: MouseRegion(
        onEnter: (_) => _set(hover: true),
        onExit: (_) => _set(hover: false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: FocusRing(
            focused: _focus,
            pointer: widget.pointer,
            child: widget.builder(context, _hover || _focus),
          ),
        ),
      ),
    );
  }
}

/// Pestañas por teclado: envuelve el panel entero (afuera del marco, así
/// recibe las teclas que el marco no usa). `Q` / `RePág` /
/// `Ctrl+Shift+Tab` = anterior, `E` / `AvPág` / `Ctrl+Tab` = siguiente
/// (en círculo) y, con [digits], `1`..`9` = pestaña N.
class MenuTabKeys extends StatelessWidget {
  const MenuTabKeys({
    super.key,
    required this.count,
    required this.index,
    required this.onChanged,
    required this.child,
    this.digits = true,
    this.enabled = true,
  });

  final int count;
  final int index;
  final ValueChanged<int> onChanged;
  final Widget child;
  final bool digits;
  final bool enabled;

  static final _digitKeys = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
    LogicalKeyboardKey.digit7,
    LogicalKeyboardKey.digit8,
    LogicalKeyboardKey.digit9,
  ];

  /// La pestaña que pide [e] (o `null` si la tecla no es de pestañas).
  int? target(KeyEvent e) {
    if (e is! KeyDownEvent || count < 2) return null;
    final k = e.logicalKey;
    final hw = HardwareKeyboard.instance;
    if (hw.isAltPressed || hw.isMetaPressed) return null;
    final ctrl = hw.isControlPressed;
    int step(int d) => (index + d) % count;
    if (k == LogicalKeyboardKey.tab) {
      return ctrl ? step(hw.isShiftPressed ? -1 : 1) : null;
    }
    if (ctrl) return null;
    if (k == LogicalKeyboardKey.keyQ || k == LogicalKeyboardKey.pageUp) {
      return step(-1);
    }
    if (k == LogicalKeyboardKey.keyE || k == LogicalKeyboardKey.pageDown) {
      return step(1);
    }
    if (digits) {
      final d = _digitKeys.indexOf(k);
      if (d >= 0 && d < count) return d;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (_, e) {
        if (!enabled || typingInField()) return KeyEventResult.ignored;
        final t = target(e);
        if (t == null) return KeyEventResult.ignored;
        if (t != index) onChanged(t);
        return KeyEventResult.handled;
      },
      child: child,
    );
  }
}

/// Una sección de un menú (lista, detalle, grupo de tarjetas, botones):
/// `Tab` salta al primer elemento de la sección siguiente y `Shift+Tab` al
/// de la anterior (en el orden de lectura de la pantalla); las flechas
/// siguen moviéndose elemento por elemento.
class NavSection extends StatefulWidget {
  const NavSection({super.key, required this.child});

  final Widget child;

  static const _label = 'nav-section';

  /// Mueve el foco a la sección siguiente ([back]: anterior) de la del
  /// foco actual. Las "secciones" son las [NavSection] y cada elemento
  /// suelto (botón fuera de una sección). `false` si no hay a dónde ir.
  static bool jump({required bool back}) {
    final cur = FocusManager.instance.primaryFocus;
    final scope = cur?.nearestScope;
    if (cur == null || scope == null || cur == scope) return false;
    final nodes = <(FocusNode, Rect)>[
      for (final n in scope.traversalDescendants)
        if (n.canRequestFocus && !n.skipTraversal)
          if (_rectOf(n) case final r?) (n, r),
    ];
    if (nodes.isEmpty) return false;
    // Unidades (sección o elemento suelto): su caja y su primer nodo en
    // orden de lectura.
    final box = <FocusNode, Rect>{};
    final first = <FocusNode, (FocusNode, Rect)>{};
    for (final (n, r) in nodes) {
      final u = _unitOf(n);
      box[u] = box[u]?.expandToInclude(r) ?? r;
      final f = first[u];
      if (f == null || _before(r, f.$2)) first[u] = (n, r);
    }
    final order = box.keys.toList()
      ..sort((a, b) {
        final ra = box[a]!, rb = box[b]!;
        if ((ra.top - rb.top).abs() > 24) return ra.top.compareTo(rb.top);
        return ra.left.compareTo(rb.left);
      });
    if (order.length < 2) return false;
    final i = order.indexOf(_unitOf(cur));
    final next =
        i < 0 ? order.first : order[(i + (back ? -1 : 1)) % order.length];
    first[next]!.$1.requestFocus();
    return true;
  }

  static bool _before(Rect a, Rect b) =>
      (a.top - b.top).abs() > 4 ? a.top < b.top : a.left < b.left;

  static Rect? _rectOf(FocusNode n) {
    final ro = n.context?.findRenderObject();
    if (ro is! RenderBox || !ro.attached || !ro.hasSize) return null;
    return n.rect;
  }

  static FocusNode _unitOf(FocusNode n) {
    for (final a in n.ancestors) {
      if (a.debugLabel == _label) return a;
    }
    return n;
  }

  @override
  State<NavSection> createState() => _NavSectionState();
}

class _NavSectionState extends State<NavSection> {
  final _node = FocusNode(
      debugLabel: NavSection._label,
      canRequestFocus: false,
      skipTraversal: true);

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final hw = HardwareKeyboard.instance;
    if (e.logicalKey != LogicalKeyboardKey.tab ||
        hw.isControlPressed ||
        hw.isAltPressed ||
        typingInField()) {
      return KeyEventResult.ignored;
    }
    return NavSection.jump(back: hw.isShiftPressed)
        ? KeyEventResult.handled
        : KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) => Focus(
        focusNode: _node,
        onKeyEvent: _onKey,
        child: FocusTraversalGroup(child: widget.child),
      );
}

/// Grilla de casillas con cursor de teclado (inventario, alijo): las
/// flechas mueven el foco casilla por casilla (y, en el borde, lo dejan
/// salir de la grilla), `Enter` / `Espacio` = [onActivate]. [onFocusCell]
/// avisa cada vez que el cursor llega a una casilla con las flechas (para
/// elegirla y ver su detalle). Clic en una casilla también le pasa el
/// cursor.
class FocusGrid extends StatefulWidget {
  const FocusGrid({
    super.key,
    required this.count,
    required this.columns,
    required this.cell,
    this.onFocusCell,
    this.onActivate,
    this.spacing = 4,
    this.width,
    this.keyPrefix,
  });

  final int count;
  final int columns;

  /// La casilla [i] (`focused`: tiene el cursor).
  final Widget Function(BuildContext context, int i, bool focused) cell;
  final ValueChanged<int>? onFocusCell;
  final ValueChanged<int>? onActivate;
  final double spacing;
  final double? width;

  /// Prefijo de las claves del foco de cada casilla (`<prefijo><i>`).
  final String? keyPrefix;

  @override
  State<FocusGrid> createState() => FocusGridState();
}

class FocusGridState extends State<FocusGrid> {
  final _nodes = <FocusNode>[];
  int? _focused;

  /// Casilla con el cursor.
  int? get focused => _focused;

  /// Pone el cursor en [i].
  void focus(int i) {
    if (i >= 0 && i < _nodes.length) _nodes[i].requestFocus();
  }

  void _sync() {
    while (_nodes.length < widget.count) {
      _nodes.add(FocusNode(debugLabel: 'grid-${_nodes.length}'));
    }
    while (_nodes.length > widget.count) {
      _nodes.removeLast().dispose();
    }
  }

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(FocusGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    final i = _focused;
    if (i == null || (e is! KeyDownEvent && e is! KeyRepeatEvent)) {
      return KeyEventResult.ignored;
    }
    final k = e.logicalKey;
    final cols = widget.columns;
    int? to;
    if (k == LogicalKeyboardKey.arrowLeft && i % cols > 0) to = i - 1;
    if (k == LogicalKeyboardKey.arrowRight &&
        i % cols < cols - 1 &&
        i + 1 < widget.count) {
      to = i + 1;
    }
    if (k == LogicalKeyboardKey.arrowUp && i - cols >= 0) to = i - cols;
    if (k == LogicalKeyboardKey.arrowDown && i + cols < widget.count) {
      to = i + cols;
    }
    if (to != null) {
      _nodes[to].requestFocus();
      widget.onFocusCell?.call(to);
      return KeyEventResult.handled;
    }
    if (e is KeyDownEvent &&
        (k == LogicalKeyboardKey.enter ||
            k == LogicalKeyboardKey.numpadEnter ||
            k == LogicalKeyboardKey.space) &&
        widget.onActivate != null) {
      widget.onActivate!(i);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final grid = Wrap(
      spacing: widget.spacing,
      runSpacing: widget.spacing,
      children: [
        for (var i = 0; i < widget.count; i++)
          Focus(
            key: widget.keyPrefix == null
                ? null
                : ValueKey('${widget.keyPrefix}$i'),
            focusNode: _nodes[i],
            onFocusChange: (f) => setState(() {
              if (f) {
                _focused = i;
              } else if (_focused == i) {
                _focused = null;
              }
            }),
            child: Listener(
              onPointerDown: (_) => _nodes[i].requestFocus(),
              child: FocusRing(
                focused: _focused == i,
                pointer: false,
                child: widget.cell(context, i, _focused == i),
              ),
            ),
          ),
      ],
    );
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: widget.width == null
          ? grid
          : SizedBox(width: widget.width, child: grid),
    );
  }
}

/// El teclado de los paneles para pantallas que no son un [PanelFrame]
/// (título, creador): atrapa el foco, las flechas lo mueven en esa
/// dirección (o al siguiente / anterior), `Tab` / `Shift+Tab` recorren,
/// `Enter` / `Espacio` activan, `Esc` = [onBack] y `1`..`9` = [onDigit]
/// (si devuelve `true`, la tecla se usó). En un campo de texto solo
/// atiende `Esc` (sale del campo).
class MenuKeyScope extends StatefulWidget {
  const MenuKeyScope({
    super.key,
    required this.child,
    this.onBack,
    this.onDigit,
    this.autofocus = true,
  });

  final Widget child;
  final VoidCallback? onBack;
  final bool Function(int n)? onDigit;
  final bool autofocus;

  @override
  State<MenuKeyScope> createState() => _MenuKeyScopeState();
}

class _MenuKeyScopeState extends State<MenuKeyScope> {
  final _scope = FocusScopeNode(debugLabel: 'menu-keys');

  static final _dirs = {
    LogicalKeyboardKey.arrowUp: TraversalDirection.up,
    LogicalKeyboardKey.arrowDown: TraversalDirection.down,
    LogicalKeyboardKey.arrowLeft: TraversalDirection.left,
    LogicalKeyboardKey.arrowRight: TraversalDirection.right,
  };

  @override
  void dispose() {
    _scope.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final k = e.logicalKey;
    if (typingInField()) {
      if (k == LogicalKeyboardKey.escape && e is KeyDownEvent) {
        FocusManager.instance.primaryFocus
            ?.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    final focused = FocusManager.instance.primaryFocus;
    final inside = focused != null && focused != _scope;
    if (k == LogicalKeyboardKey.escape) {
      if (widget.onBack == null || e is! KeyDownEvent) {
        return KeyEventResult.ignored;
      }
      widget.onBack!();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.tab) {
      final back = HardwareKeyboard.instance.isShiftPressed;
      final from = inside ? focused : _scope;
      back ? from.previousFocus() : from.nextFocus();
      return KeyEventResult.handled;
    }
    if (_dirs[k] case final dir?) {
      if (!inside) {
        _scope.nextFocus();
      } else if (!focused.focusInDirection(dir)) {
        dir == TraversalDirection.up || dir == TraversalDirection.left
            ? focused.previousFocus()
            : focused.nextFocus();
      }
      return KeyEventResult.handled;
    }
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    if (k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.numpadEnter ||
        k == LogicalKeyboardKey.space) {
      if (!inside) return KeyEventResult.ignored;
      Actions.maybeInvoke(focused.context!, const ActivateIntent());
      return KeyEventResult.handled;
    }
    if (widget.onDigit != null) {
      final d = MenuTabKeys._digitKeys.indexOf(k);
      if (d >= 0 && widget.onDigit!(d + 1)) return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) => FocusScope(
        node: _scope,
        autofocus: widget.autofocus,
        onKeyEvent: _onKey,
        child: widget.child,
      );
}

/// Al aparecer, pasa el foco al primer elemento enfocable de [child] (en
/// orden del árbol): el panel abre con el cursor ya puesto en vez de
/// esperar la primera flecha. Con [enabled] `false` no hace nada.
class InitialFocus extends StatefulWidget {
  const InitialFocus({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<InitialFocus> createState() => _InitialFocusState();
}

class _InitialFocusState extends State<InitialFocus> {
  final _node = FocusNode(
      debugLabel: 'initial-focus', canRequestFocus: false, skipTraversal: true);

  @override
  void initState() {
    super.initState();
    if (!widget.enabled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final n in _node.traversalDescendants) {
        if (n.canRequestFocus && !n.skipTraversal) {
          n.requestFocus();
          return;
        }
      }
    });
  }

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Focus(focusNode: _node, child: widget.child);
}
