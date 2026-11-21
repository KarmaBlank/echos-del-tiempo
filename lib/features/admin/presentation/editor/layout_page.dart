import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../app/design/ds_layout_host.dart';
import '../../../../app/theme/retro_theme.dart';
import '../../../../core/layout/layout_doc.dart';
import '../../../../core/layout/layout_spec.dart';
import '../../../../core/layout/layout_validator.dart';
import 'layout_editor_controller.dart';

/// Editor → LAYOUT (docs/specs/editor_layout.md § 3): galería de
/// pantallas con datos de ejemplo, lienzo con tamaño de ventana y de
/// texto, selección (clic = más interno, de nuevo/Alt/Esc = grupo),
/// arrastrar entre regiones con guías, teclado (flechas reordenan, Tab
/// cambia de región, Ctrl+Z/Ctrl+Y), propiedades por corte, árbol de
/// slots con candados, validación en vivo y VALIDAR TODO.
///
/// Rendimiento (lección de Animaciones): nada de tickers; se reconstruye
/// solo cuando el controlador avisa un cambio, y el arrastre mueve
/// únicamente las guías (`ValueNotifier`), no el lienzo.
class LayoutPage extends StatefulWidget {
  const LayoutPage({super.key, required this.c});
  final LayoutEditorController c;

  @override
  State<LayoutPage> createState() => LayoutPageState();
}

/// Lo que se suelta: contenedor, índice y si se permite.
class _Drop {
  const _Drop(this.container, this.index, this.allowed);
  final String container;
  final int index;
  final bool allowed;

  @override
  bool operator ==(Object o) =>
      o is _Drop &&
      o.container == container &&
      o.index == index &&
      o.allowed == allowed;

  @override
  int get hashCode => Object.hash(container, index, allowed);
}

class LayoutPageState extends State<LayoutPage> {
  LayoutEditorController get c => widget.c;
  final _focus = FocusNode(debugLabel: 'layout-editor');
  final _rootKey = GlobalKey(debugLabel: 'layout-canvas');
  final _slotKeys = <String, GlobalKey>{};
  final _containerKeys = <String, GlobalKey>{};
  final _hover = ValueNotifier<_Drop?>(null);
  late final _hooks = _EditorHooks(this);
  bool _measureQueued = false;
  bool _validating = false;
  final _custom = TextEditingController();

  @override
  void dispose() {
    _focus.dispose();
    _hover.dispose();
    _custom.dispose();
    super.dispose();
  }

  // ------------------------------------------------------- medición

  LayoutRect? _rectOf(GlobalKey k) {
    final root = _rootKey.currentContext?.findRenderObject();
    final b = k.currentContext?.findRenderObject();
    if (root is! RenderBox || b is! RenderBox || !b.hasSize || !b.attached) {
      return null;
    }
    final o = b.localToGlobal(Offset.zero, ancestor: root);
    return LayoutRect(o.dx, o.dy, b.size.width, b.size.height);
  }

  /// Mide el lienzo actual y devuelve los problemas geométricos
  /// (§ 2.5.2): fuera de la ventana, desbordes (un slot que se sale de su
  /// región), solapes entre hermanos, objetivos de clic y orden de foco.
  List<LayoutIssue> measure() {
    final d = c.doc, s = c.spec;
    if (d == null || s == null) return const [];
    final where =
        '${c.canvasSize.width.toInt()}×${c.canvasSize.height.toInt()} · '
        '${(c.textFactor * 100).round()} %';
    final res = d.resolve(c.previewBreakpoint);
    final slots = <String, LayoutRect>{};
    for (final MapEntry(:key, :value) in _slotKeys.entries) {
      if (res.containerOf(key) == null) continue;
      final r = _rectOf(value);
      if (r != null) slots[key] = r;
    }
    final out = <LayoutIssue>[];
    final siblings = <List<String>>[];
    for (final MapEntry(key: cont, value: ids) in res.children.entries) {
      final shown = [for (final id in ids) if (slots.containsKey(id)) id];
      siblings.add(shown);
      final box = _containerKeys[cont] == null ? null : _rectOf(_containerKeys[cont]!);
      if (box == null) continue;
      for (final id in shown) {
        if (!slots[id]!.inside(box)) {
          out.add(LayoutIssue('Desborde: se sale de "$cont"',
              slot: id, where: where));
        }
      }
    }
    final targets = <String, List<LayoutRect>>{
      for (final MapEntry(:key, :value) in slots.entries)
        if ((s.slots[key]?.interactive ?? false) &&
            !(s.slots[key]?.group ?? false))
          key: [value],
    };
    out.addAll(LayoutValidator.validateGeometry(
      where: where,
      viewport: LayoutRect(0, 0, c.canvasSize.width, double.maxFinite),
      slots: slots,
      siblings: siblings,
      targets: targets,
      focusGroups: siblings,
    ));
    return out;
  }

  void _queueMeasure() {
    if (_measureQueued || _validating) return;
    _measureQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureQueued = false;
      if (mounted) c.setGeometry(measure());
    });
  }

  /// VALIDAR TODO: recorre la matriz tamaños × textos en el lienzo.
  Future<void> validateAll() async {
    if (_validating || c.doc == null) return;
    _validating = true;
    final size = c.canvasSize, text = c.textFactor;
    final all = <LayoutIssue>[];
    for (final s in LayoutEditorController.sizes) {
      for (final t in LayoutEditorController.texts) {
        c
          ..setSize(s.size)
          ..setText(t);
        await WidgetsBinding.instance.endOfFrame;
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;
        all.addAll(measure());
      }
    }
    c
      ..setSize(size)
      ..setText(text);
    _validating = false;
    c.setMatrix(all);
  }

  // -------------------------------------------------------- teclado

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    final ctrl = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    if (ctrl && k == LogicalKeyboardKey.keyZ) {
      shift ? c.redo() : c.undo();
    } else if (ctrl && k == LogicalKeyboardKey.keyY) {
      c.redo();
    } else if (k == LogicalKeyboardKey.escape) {
      c.selectParent();
    } else if (k == LogicalKeyboardKey.tab) {
      c.cycleRegion(back: shift);
    } else if (k == LogicalKeyboardKey.arrowUp ||
        k == LogicalKeyboardKey.arrowLeft) {
      c.nudge(-1);
    } else if (k == LogicalKeyboardKey.arrowDown ||
        k == LogicalKeyboardKey.arrowRight) {
      c.nudge(1);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) => Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 280, child: _left()),
              const VerticalDivider(width: 1, color: DsColors.border),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    _toolbar(),
                    const Divider(height: 1, color: DsColors.border),
                    Expanded(child: _canvas()),
                  ])),
              const VerticalDivider(width: 1, color: DsColors.border),
              SizedBox(width: 330, child: _right()),
            ],
          ),
        ),
      );

  // ---------------------------------------------------------- partes

  Widget _left() => ListView(
        padding: EdgeInsets.all(DsSpace.sm),
        children: [
          const DsSectionHeader('PANTALLAS'),
          for (var i = 0; i < c.previews.length; i++)
            DsListRow(
              key: ValueKey('layout-screen-${c.previews[i].screen}'),
              title: c.previews[i].title,
              detail: c.previews[i].migrated ? null : 'sin vista previa',
              selected: i == c.screenIndex,
              onTap: () => c.openScreen(i),
            ),
          SizedBox(height: DsSpace.md),
          const DsSectionHeader('SLOTS'),
          ..._tree(),
        ],
      );

  List<Widget> _tree() {
    final d = c.doc, s = c.spec;
    if (d == null || s == null) {
      return [Text('Pantalla sin migrar.', style: DsText.detail())];
    }
    final res = d.resolve(c.previewBreakpoint);
    final out = <Widget>[];
    void slot(String id, int depth) {
      final sp = s.slots[id];
      final sel = c.selected == id;
      final hidden = res.ruleOf(id).hide == true;
      out.add(InkWell(
        key: ValueKey('layout-tree-$id'),
        onTap: () {
          c.select(id);
          _focus.requestFocus();
        },
        child: Container(
          color: sel ? DsColors.hover : null,
          padding: EdgeInsets.only(
              left: DsSpace.sm + depth * DsSpace.md,
              top: 2,
              bottom: 2,
              right: DsSpace.xs),
          child: Row(children: [
            Expanded(
              child: Text(
                '${sp?.label ?? id}${hidden ? ' (oculto)' : ''}',
                overflow: TextOverflow.ellipsis,
                style: DsText.detail(sel
                    ? DsColors.selected
                    : hidden
                        ? DsColors.textDisabled
                        : null),
              ),
            ),
            if (sp != null && !sp.movable)
              Text('FIJO', style: DsText.detail(DsColors.warning)),
          ]),
        ),
      ));
      if (sp?.group ?? false) {
        for (final k in res.of(id)) {
          slot(k, depth + 1);
        }
      }
    }

    for (final r in s.regions) {
      out.add(Padding(
        padding: EdgeInsets.only(top: DsSpace.xs),
        child: Text('${r.id.toUpperCase()} · ${r.label ?? ''}',
            style: DsText.subtitle()),
      ));
      for (final id in res.of(r.id)) {
        slot(id, 1);
      }
    }
    final hidden = [
      for (final id in s.slots.keys)
        if (res.containerOf(id) == null) id,
    ];
    if (hidden.isNotEmpty) {
      out.add(Text('OCULTOS', style: DsText.subtitle()));
      for (final id in hidden) {
        slot(id, 1);
      }
    }
    return out;
  }

  Widget _chip(String label, bool on, VoidCallback? onTap, {Key? key}) =>
      DsButton(label,
          key: key,
          size: DsButtonSize.compact,
          selected: on,
          onPressed: onTap);

  Widget _toolbar() => Padding(
        padding: EdgeInsets.all(DsSpace.sm),
        child: Wrap(
          spacing: DsSpace.xs,
          runSpacing: DsSpace.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('VENTANA', style: DsText.detail()),
            for (final s in LayoutEditorController.sizes)
              _chip(s.label, c.canvasSize == s.size, () => c.setSize(s.size),
                  key: ValueKey('layout-size-${s.label}')),
            SizedBox(
              width: 110,
              child: TextField(
                key: const ValueKey('layout-size-custom'),
                controller: _custom,
                style: DsText.detail(),
                decoration: const InputDecoration(
                    isDense: true, hintText: 'ancho×alto'),
                onSubmitted: (v) {
                  final m = RegExp(r'(\d+)\D+(\d+)').firstMatch(v);
                  if (m == null) return;
                  final w = double.parse(m[1]!), h = double.parse(m[2]!);
                  if (w >= 320 && h >= 240) c.setSize(Size(w, h));
                },
              ),
            ),
            SizedBox(width: DsSpace.sm),
            Text('TEXTO', style: DsText.detail()),
            for (final t in LayoutEditorController.texts)
              _chip('${(t * 100).round()} %', c.textFactor == t,
                  () => c.setText(t),
                  key: ValueKey('layout-text-${(t * 100).round()}')),
            SizedBox(width: DsSpace.sm),
            _chip('DESHACER', false, c.canUndo ? c.undo : null,
                key: const ValueKey('layout-undo')),
            _chip('REHACER', false, c.canRedo ? c.redo : null,
                key: const ValueKey('layout-redo')),
            _chip('VALIDAR TODO', false, c.doc == null ? null : validateAll,
                key: const ValueKey('layout-validate-all')),
            DsButton('GUARDAR',
                key: const ValueKey('layout-save'),
                kind: DsButtonKind.primary,
                size: DsButtonSize.compact,
                tooltip: c.hasErrors ? 'Hay errores: no se puede guardar' : null,
                onPressed: c.dirty && !c.hasErrors && c.overrides != null
                    ? c.save
                    : null),
            _chip('RESTAURAR', false, c.doc == null ? null : c.restore,
                key: const ValueKey('layout-restore')),
            _chip('RECARGAR', false, c.doc == null ? null : c.reload,
                key: const ValueKey('layout-reload')),
            _chip('PUBLICAR AL REPO', false,
                c.doc != null && c.repoPath != null && !c.hasErrors
                    ? c.publish
                    : null,
                key: const ValueKey('layout-publish')),
          ],
        ),
      );

  Widget _canvas() {
    final p = c.preview, d = c.doc;
    if (d == null || p.build == null) {
      return Center(
          child: Text('${p.title}: SIN VISTA PREVIA (pantalla sin migrar)',
              style: DsText.detail()));
    }
    _queueMeasure();
    final size = c.canvasSize;
    return Container(
      color: Colors.black,
      padding: EdgeInsets.all(DsSpace.sm),
      child: FittedBox(
        fit: BoxFit.contain,
        alignment: Alignment.topCenter,
        child: SizedBox.fromSize(
          key: _rootKey,
          size: size,
          child: ClipRect(
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(size: size),
              child: Theme(
                data: RetroTheme.build(),
                child: RetroTextScale(
                  factor: c.textFactor,
                  child: Material(
                    color: DsColors.background,
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(DsSpace.md),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: p.build!(d, _hooks),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _right() {
    final id = c.selected, s = c.spec;
    return ListView(
      padding: EdgeInsets.all(DsSpace.sm),
      children: [
        const DsSectionHeader('PROPIEDADES'),
        Text(
            'Lienzo en corte: ${c.previewBreakpoint?.name ?? '-'} · editando: '
            '${c.editBreakpoint?.name ?? 'base'}',
            style: DsText.detail()),
        SizedBox(height: DsSpace.xs),
        Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: [
          _chip('BASE', c.editBreakpoint == null,
              () => c.setEditBreakpoint(null),
              key: const ValueKey('layout-bp-base')),
          for (final bp in LayoutBreakpoint.values)
            _chip(bp.name.toUpperCase(), c.editBreakpoint == bp,
                () => c.setEditBreakpoint(bp),
                key: ValueKey('layout-bp-${bp.name}')),
        ]),
        SizedBox(height: DsSpace.sm),
        if (id == null || s == null)
          Text('Elegí un elemento en el lienzo o en el árbol.',
              style: DsText.detail())
        else
          ..._props(id),
        if (s != null && s.params.isNotEmpty) ...[
          SizedBox(height: DsSpace.md),
          const DsSectionHeader('PERILLAS'),
          for (final p in s.params) _param(s, p),
        ],
        SizedBox(height: DsSpace.md),
        const DsSectionHeader('VALIDACIÓN'),
        if (c.message != null)
          Padding(
            padding: EdgeInsets.only(bottom: DsSpace.xs),
            child: Text(c.message!,
                key: const ValueKey('layout-message'),
                style: DsText.body(DsColors.success)),
          ),
        if (c.issues.isEmpty)
          Text('Sin problemas en este tamaño.',
              key: const ValueKey('layout-ok'),
              style: DsText.detail(DsColors.success))
        else
          for (final i in c.issues.take(60))
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text('$i',
                  style: DsText.detail(
                      i.error ? DsColors.danger : DsColors.warning)),
            ),
      ],
    );
  }

  /// Una perilla de la pantalla (§ 2.8): − valor + y DEFECTO.
  Widget _param(LayoutScreenSpec s, LayoutParamSpec p) {
    final d = c.doc;
    if (d == null) return const SizedBox.shrink();
    final v = s.param(d, p.key);
    String fmt(double x) =>
        x == x.roundToDouble() ? '${x.toInt()}' : x.toStringAsFixed(1);
    return Padding(
      key: ValueKey('layout-param-${p.key}'),
      padding: EdgeInsets.only(bottom: DsSpace.xs),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(p.label, style: DsText.subtitle()),
        if (p.help != null) Text(p.help!, style: DsText.detail()),
        Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: [
          _chip('-', false, v <= p.min ? null : () => c.setParam(p.key, v - p.step),
              key: ValueKey('layout-param-${p.key}-minus')),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: DsSpace.xs, vertical: 6),
            child: Text(fmt(v),
                key: ValueKey('layout-param-${p.key}-value'),
                style: DsText.body()),
          ),
          _chip('+', false, v >= p.max ? null : () => c.setParam(p.key, v + p.step),
              key: ValueKey('layout-param-${p.key}-plus')),
          _chip('DEFECTO (${fmt(p.defaultValue)})', v == p.defaultValue,
              () => c.setParam(p.key, p.defaultValue)),
        ]),
      ]),
    );
  }

  List<Widget> _props(String id) {
    final sp = c.spec!.slots[id]!;
    final (own, eff) = c.ruleOf(id);
    final bp = c.editBreakpoint;
    Widget tag(bool set) => Text(
        bp == null ? 'BASE' : (set ? 'SOBRESCRITO' : 'HEREDA'),
        style: DsText.detail(set && bp != null ? DsColors.warning : null));
    Widget row(String label, bool set, List<Widget> controls,
            {VoidCallback? reset}) =>
        Padding(
          padding: EdgeInsets.only(bottom: DsSpace.xs),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(label, style: DsText.subtitle())),
              tag(set),
              if (bp != null && set && reset != null) ...[
                SizedBox(width: DsSpace.xs),
                _chip('X', false, reset),
              ],
            ]),
            Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: controls),
          ]),
        );
    final container = c.containerOf(id) ?? '-';
    return [
      Text(sp.label, style: DsText.title()),
      Text(id, key: const ValueKey('layout-selected-id'), style: DsText.detail()),
      Text(
          [
            sp.movable ? 'movible' : 'FIJO',
            if (sp.hideable) 'ocultable',
            if (sp.group) 'grupo',
            'en $container',
          ].join(' · '),
          style: DsText.detail()),
      SizedBox(height: DsSpace.sm),
      if (sp.movable)
        row('Región', own.region != null, [
          for (final r in [
            ...c.spec!.regions.map((r) => r.id),
            for (final g in c.spec!.slots.values)
              if (g.group) g.id,
          ])
            if (c.allows(id, r))
              _chip(r, container == r, () => c.move(id, r, 1 << 20)),
        ], reset: () => c.setRule(id, (r) => r.copyWith(region: null, order: null))),
      if (sp.group)
        row('Eje', own.axis != null, [
          for (final a in LayoutAxis.values)
            _chip(a.name, (eff.axis ?? sp.groupAxis) == a,
                () => c.setRule(id, (r) => r.copyWith(axis: a))),
        ], reset: () => c.setRule(id, (r) => r.copyWith(axis: null))),
      if (sp.hideable)
        row('Ocultar', own.hide != null, [
          _chip('VISIBLE', eff.hide != true,
              () => c.setRule(id, (r) => r.copyWith(hide: false))),
          _chip('OCULTO', eff.hide == true,
              () => c.setRule(id, (r) => r.copyWith(hide: true))),
        ], reset: () => c.setRule(id, (r) => r.copyWith(hide: null))),
      row('Ocupar el ancho', own.stretch != null, [
        _chip('NO', eff.stretch != true,
            () => c.setRule(id, (r) => r.copyWith(stretch: false))),
        _chip('SÍ', eff.stretch == true,
            () => c.setRule(id, (r) => r.copyWith(stretch: true))),
      ], reset: () => c.setRule(id, (r) => r.copyWith(stretch: null))),
      row('Alinear', own.align != null, [
        for (final a in LayoutAlign.values)
          _chip(a.name, (eff.align ?? LayoutAlign.start) == a,
              () => c.setRule(id, (r) => r.copyWith(align: a))),
      ], reset: () => c.setRule(id, (r) => r.copyWith(align: null))),
      row('Ancho mínimo (tx)', own.minWidth != null, [
        _chip('-', false, () {
          final v = (eff.minWidth ?? 0) - 5;
          c.setRule(id, (r) => r.copyWith(minWidth: v <= 0 ? null : v));
        }),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: DsSpace.xs, vertical: 6),
          child: Text(eff.minWidth == null ? '-' : '${eff.minWidth!.toInt()}',
              style: DsText.body()),
        ),
        _chip('+', false, () {
          final v = (eff.minWidth ?? 0) + 5;
          c.setRule(id, (r) => r.copyWith(minWidth: v));
        }),
      ], reset: () => c.setRule(id, (r) => r.copyWith(minWidth: null))),
    ];
  }
}

/// Ganchos del lienzo: contorno y nombre del seleccionado, clic, arrastre
/// con guías de inserción y regiones resaltadas (verde si se puede soltar,
/// roja tachada si no).
class _EditorHooks extends DsLayoutHooks {
  _EditorHooks(this.s);
  final LayoutPageState s;
  LayoutEditorController get c => s.c;

  @override
  void breakpoint(LayoutBreakpoint bp) => c.previewBreakpoint = bp;

  LayoutAxis _axisOf(String container) {
    final spec = c.spec!;
    final g = spec.slots[container];
    if (g != null && g.group) {
      return c.doc!.resolve(c.previewBreakpoint).ruleOf(container).axis ??
          g.groupAxis;
    }
    return spec.region(container)?.axis ?? LayoutAxis.column;
  }

  @override
  Widget slot(BuildContext context, String id, String container, int index,
      Widget child) {
    final key = s._slotKeys.putIfAbsent(id, () => GlobalKey(debugLabel: id));
    final spec = c.spec!.slots[id];
    final leaf = !(spec?.group ?? false);
    final movable = spec?.movable ?? false;
    final selected = c.selected == id;
    final vertical = _axisOf(container) == LayoutAxis.column;
    final count = c.doc!.resolve(c.previewBreakpoint).of(container).length;
    Widget body = KeyedSubtree(
        key: key, child: leaf ? AbsorbPointer(child: child) : child);
    body = Stack(clipBehavior: Clip.none, children: [
      body,
      Positioned.fill(
        child: IgnorePointer(
          child: ValueListenableBuilder<_Drop?>(
            valueListenable: s._hover,
            builder: (context, h, _) {
              final before = h != null && h.container == container && h.index == index;
              final after = h != null &&
                  h.container == container &&
                  index == count - 1 &&
                  h.index >= count;
              return CustomPaint(
                painter: _SlotPainter(
                  selected: selected,
                  fixed: !movable,
                  before: before,
                  after: after,
                  vertical: vertical,
                  ok: h?.allowed ?? true,
                ),
              );
            },
          ),
        ),
      ),
      if (selected)
        Positioned(
          left: 0,
          top: -14,
          child: IgnorePointer(
            child: Container(
              color: DsColors.selected,
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Text(spec?.label ?? id,
                  style: const TextStyle(
                      fontSize: 10, color: Colors.black, height: 1.2)),
            ),
          ),
        ),
    ]);
    body = GestureDetector(
      key: ValueKey('layout-slot-$id'),
      behavior: HitTestBehavior.opaque,
      onTap: () {
        c.tapSlot(id, alt: HardwareKeyboard.instance.isAltPressed);
        s._focus.requestFocus();
      },
      child: body,
    );
    final target = DragTarget<String>(
      onWillAcceptWithDetails: (d) => d.data != id,
      onMove: (d) {
        final b = key.currentContext?.findRenderObject();
        if (b is! RenderBox) return;
        final local = b.globalToLocal(d.offset);
        final after = vertical
            ? local.dy > b.size.height / 2
            : local.dx > b.size.width / 2;
        s._hover.value = _Drop(container, after ? index + 1 : index,
            c.canMove(d.data) && c.allows(d.data, container));
      },
      onAcceptWithDetails: (d) {
        final h = s._hover.value;
        s._hover.value = null;
        if (h != null && h.allowed) c.move(d.data, h.container, h.index);
      },
      builder: (context, _, __) => body,
    );
    if (!movable) return target;
    return Draggable<String>(
      data: id,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        color: DsColors.selected,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Text(spec?.label ?? id,
              style: const TextStyle(fontSize: 12, color: Colors.black)),
        ),
      ),
      onDragStarted: () => c.select(id),
      onDragEnd: (_) => s._hover.value = null,
      child: target,
    );
  }

  @override
  Widget container(BuildContext context, String id, LayoutAxis axis,
      List<String> children, Widget child) {
    final key =
        s._containerKeys.putIfAbsent(id, () => GlobalKey(debugLabel: 'c:$id'));
    final region = c.spec!.region(id);
    final empty = children.isEmpty;
    Widget body = KeyedSubtree(
      key: key,
      child: empty
          ? ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 160, minHeight: 36),
              child: Center(
                  child: Text('${region?.label ?? id} (vacío)',
                      style: DsText.detail())))
          : child,
    );
    body = Stack(clipBehavior: Clip.none, children: [
      body,
      Positioned.fill(
        child: IgnorePointer(
          child: ValueListenableBuilder<_Drop?>(
            valueListenable: s._hover,
            builder: (context, h, _) => CustomPaint(
              painter: _RegionPainter(
                region: region != null,
                target: h != null && h.container == id,
                ok: h?.allowed ?? true,
              ),
            ),
          ),
        ),
      ),
    ]);
    return DragTarget<String>(
      onWillAcceptWithDetails: (d) => d.data != id,
      onMove: (d) => s._hover.value = _Drop(id, children.length,
          c.canMove(d.data) && c.allows(d.data, id)),
      onAcceptWithDetails: (d) {
        final h = s._hover.value;
        s._hover.value = null;
        if (h != null && h.allowed) c.move(d.data, h.container, h.index);
      },
      builder: (context, _, __) => body,
    );
  }
}

class _SlotPainter extends CustomPainter {
  _SlotPainter(
      {required this.selected,
      required this.fixed,
      required this.before,
      required this.after,
      required this.vertical,
      required this.ok});
  final bool selected, fixed, before, after, vertical, ok;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    if (selected) {
      canvas.drawRect(
          r.inflate(2),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = DsColors.selected);
    } else {
      canvas.drawRect(
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = (fixed ? DsColors.warning : DsColors.mp)
                .withValues(alpha: 0.35));
    }
    final guide = Paint()
      ..strokeWidth = 3
      ..color = ok ? DsColors.success : DsColors.danger;
    if (before) {
      vertical
          ? canvas.drawLine(r.topLeft.translate(0, -2), r.topRight.translate(0, -2), guide)
          : canvas.drawLine(r.topLeft.translate(-3, 0), r.bottomLeft.translate(-3, 0), guide);
    }
    if (after) {
      vertical
          ? canvas.drawLine(r.bottomLeft.translate(0, 2), r.bottomRight.translate(0, 2), guide)
          : canvas.drawLine(r.topRight.translate(3, 0), r.bottomRight.translate(3, 0), guide);
    }
  }

  @override
  bool shouldRepaint(_SlotPainter o) =>
      o.selected != selected ||
      o.fixed != fixed ||
      o.before != before ||
      o.after != after ||
      o.vertical != vertical ||
      o.ok != ok;
}

class _RegionPainter extends CustomPainter {
  _RegionPainter({required this.region, required this.target, required this.ok});
  final bool region, target, ok;

  @override
  void paint(Canvas canvas, Size size) {
    final r = (Offset.zero & size).inflate(region ? 4 : 2);
    if (!target) {
      if (!region) return;
      canvas.drawRect(
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = DsColors.textDisabled);
      return;
    }
    final color = ok ? DsColors.success : DsColors.danger;
    canvas.drawRect(r, Paint()..color = color.withValues(alpha: 0.12));
    canvas.drawRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color);
    if (!ok) {
      final p = Paint()
        ..strokeWidth = 2
        ..color = color;
      canvas
        ..drawLine(r.topLeft, r.bottomRight, p)
        ..drawLine(r.topRight, r.bottomLeft, p);
    }
  }

  @override
  bool shouldRepaint(_RegionPainter o) =>
      o.region != region || o.target != target || o.ok != ok;
}
