import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../app/design/registry/ds_registry.dart';
import '../../../app/design/registry/ds_screen_view.dart';
import '../../../app/theme/retro_text.dart';
import '../../../core/screen_layout/screen_layout.dart';
import '../domain/screen_checks.dart';
import 'screen_editor_controller.dart';

/// Editor → PANTALLAS (docs/specs/screen_editor.md § 5): paleta del
/// sistema de diseño, lienzo a la resolución del juego e inspector.
class ScreenEditorPage extends StatefulWidget {
  const ScreenEditorPage({super.key, required this.c});
  final ScreenEditorController c;

  @override
  State<ScreenEditorPage> createState() => _ScreenEditorPageState();
}

class _ScreenEditorPageState extends State<ScreenEditorPage> {
  int _level = 0;
  int _side = 0;
  int _inspectorTab = 0;

  ScreenEditorController get c => widget.c;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _toolbar(),
          Expanded(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(width: 300, child: _palette()),
              Expanded(child: _center()),
              SizedBox(width: 360, child: _sidePanel()),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _toolbar() {
    final sel = c.selectedId;
    return DsToolbar(
      title: '',
      center: Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: [
        for (final s in c.screens)
          DsButton(c.bindings[s]?.label ?? s,
              size: DsButtonSize.compact,
              selected: s == c.screen,
              onPressed: () => c.openScreen(s)),
        if (c.message case final m?)
          Padding(
            padding: EdgeInsets.all(DsSpace.xs),
            child: Text(retroText(m), style: DsText.detail()),
          ),
      ]),
      actions: [
        DsButton('GRILLA',
            size: DsButtonSize.compact,
            selected: c.showGrid,
            onPressed: c.toggleGrid),
        DsButton('ADELANTE',
            size: DsButtonSize.compact,
            onPressed: sel == null ? null : () => c.reorder(sel, 1)),
        DsButton('ATRÁS',
            size: DsButtonSize.compact,
            onPressed: sel == null ? null : () => c.reorder(sel, -1)),
        DsButton('DUPLICAR',
            size: DsButtonSize.compact,
            onPressed: sel == null ? null : () => c.duplicate(sel)),
        DsButton('BORRAR',
            key: const ValueKey('screen-editor-delete'),
            size: DsButtonSize.compact,
            onPressed: sel == null ? null : () => c.delete(sel)),
        DsButton('DESHACER',
            size: DsButtonSize.compact,
            onPressed: c.canUndo ? c.undo : null),
        DsButton('VERIFICAR',
            key: const ValueKey('screen-editor-verify'),
            size: DsButtonSize.compact,
            onPressed: () {
              c.verify();
              setState(() => _side = 1);
            }),
        DsButton('RESTAURAR',
            size: DsButtonSize.compact, onPressed: c.dirty ? c.revert : null),
        DsButton('GUARDAR',
            key: const ValueKey('screen-editor-save'),
            kind: DsButtonKind.primary,
            size: DsButtonSize.compact,
            onPressed: c.canSave ? c.save : null),
      ],
    );
  }

  // ── Paleta ──

  Widget _palette() {
    final level = DsLevel.values[_level];
    final items = c.registry.byLevel(level);
    return Container(
      color: DsColors.surface,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        DsTabBar(
          key: const ValueKey('screen-palette-levels'),
          index: _level,
          onChanged: (i) => setState(() => _level = i),
          tabs: [
            for (final l in DsLevel.values)
              DsTab(l.label),
          ],
        ),
        Padding(
          padding: EdgeInsets.all(DsSpace.sm),
          child: Text(level.label, style: DsText.subtitle()),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(DsSpace.sm),
            child: Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: [
              for (final s in items)
                SizedBox(
                  width: 116,
                  height: 64,
                  child: DsCard(
                    key: ValueKey('screen-palette-${s.id}'),
                    padding: EdgeInsets.all(DsSpace.xs),
                    onTap: () => c.add(s.id),
                    child: Text(retroText(s.name), style: DsText.body()),
                  ),
                ),
            ]),
          ),
        ),
      ]),
    );
  }

  // ── Lienzo ──

  Widget _center() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: EdgeInsets.all(DsSpace.xs),
        child: Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: [
          DsButton('EDITAR',
              size: DsButtonSize.compact,
              selected: c.preview == null,
              onPressed: () => c.setPreview(null)),
          for (final s in screenPreviewSizes)
            DsButton('${s.width.toInt()}×${s.height.toInt()}',
                size: DsButtonSize.compact,
                selected: c.preview == s,
                onPressed: () => c.setPreview(s)),
        ]),
      ),
      Expanded(
        child: Padding(
          padding: EdgeInsets.all(DsSpace.sm),
          child: c.preview == null
              ? _EditCanvas(c: c)
              : _PreviewCanvas(c: c, window: c.preview!),
        ),
      ),
    ]);
  }

  // ── Panel derecho ──

  Widget _sidePanel() {
    final n = c.issues?.length;
    return Container(
      color: DsColors.surface,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        DsTabBar(
          index: _side,
          onChanged: (i) => setState(() => _side = i),
          tabs: [
            const DsTab('INSPECTOR'),
            DsTab('AVISOS', badge: n == null || n == 0 ? null : '$n'),
          ],
        ),
        Expanded(child: _side == 0 ? _inspector() : _issues()),
      ]),
    );
  }

  Widget _issues() {
    final list = c.issues;
    if (list == null) {
      return Center(
          child: Text('Tocá VERIFICAR', style: DsText.detail()));
    }
    if (list.isEmpty) {
      return Center(
          child: Text('Sin avisos', style: DsText.body(DsColors.success)));
    }
    return ListView(padding: EdgeInsets.all(DsSpace.sm), children: [
      for (final (i, issue) in list.indexed)
        Padding(
          padding: EdgeInsets.only(bottom: DsSpace.xs),
          child: DsCard(
            selected: issue.elementId == c.selectedId,
            onTap: () => c.select(issue.elementId),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(issue.elementId, style: DsText.detail()),
                Text(retroText(issue.message),
                    style: DsText.body(DsColors.warning)),
                if (issue.fixLabel case final f?)
                  Text(retroText(f), style: DsText.detail()),
                if (issue.fix != null) ...[
                  SizedBox(height: DsSpace.xs),
                  DsButton('APLICAR',
                      key: ValueKey('screen-fix-$i'),
                      size: DsButtonSize.compact,
                      onPressed: () => c.applyFix(issue)),
                ],
              ],
            ),
          ),
        ),
    ]);
  }

  Widget _inspector() {
    final e = c.selected;
    if (e == null) {
      return Center(
          child: Text('Elegí un elemento del lienzo', style: DsText.detail()));
    }
    final spec = c.registry[e.component];
    if (spec == null) {
      return Center(child: Text(e.component, style: DsText.detail()));
    }
    final tabs = ['CONTENIDO', 'CAJA', 'LÓGICA'];
    final body = switch (_inspectorTab) {
      1 => _boxProps(e),
      2 => _logicProps(e, spec),
      _ => _contentProps(e, spec),
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: EdgeInsets.all(DsSpace.sm),
        child: Text(retroText('${spec.name} · ${e.id}'),
            style: DsText.subtitle()),
      ),
      DsTabBar(
        index: _inspectorTab,
        onChanged: (i) => setState(() => _inspectorTab = i),
        tabs: [for (final t in tabs) DsTab(t)],
      ),
      Expanded(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(DsSpace.sm),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: body),
        ),
      ),
    ]);
  }

  Widget _choices<T>(String label, List<(T, String)> opts, T current,
      ValueChanged<T> onPick) {
    return Padding(
      padding: EdgeInsets.only(bottom: DsSpace.sm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: DsText.detail()),
        SizedBox(height: DsSpace.xs),
        Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: [
          for (final (v, l) in opts)
            DsButton(l,
                size: DsButtonSize.compact,
                selected: v == current,
                onPressed: () => onPick(v)),
        ]),
      ]),
    );
  }

  List<Widget> _contentProps(ScreenElement e, DsComponentSpec spec) {
    final p = spec.props;
    return [
      if (p.contains(DsProp.text))
        _TextProp(
            key: ValueKey('screen-text-${e.id}'),
            value: e.text ?? '',
            onChanged: (v) => c.update(e.copyWith(text: v), record: false)),
      if (p.contains(DsProp.variant) && spec.variants.isNotEmpty)
        _choices<String?>(
            'VARIANTE',
            [for (final v in spec.variants) (v.id, v.label)],
            e.variant ?? spec.defaultVariant,
            (v) => c.update(e.copyWith(variant: v))),
      if (p.contains(DsProp.size) && spec.sizes.isNotEmpty)
        _choices<String?>(
            'TAMAÑO',
            [for (final v in spec.sizes) (v.id, v.label)],
            e.size ?? spec.defaultSizeId,
            (v) => c.update(e.copyWith(size: v))),
      if (spec.textStyles.length > 1)
        _choices<String?>(
            'ESTILO DE TEXTO',
            [for (final s in spec.textStyles) (s.name, s.label)],
            e.textStyle ?? spec.defaultTextStyle?.name,
            (v) => c.update(e.copyWith(textStyle: v))),
      if (p.contains(DsProp.role))
        _choices<String?>(
            'ROL',
            [
              (null, 'Ninguno'),
              for (final r in roleLabels.entries) (r.key, r.value),
            ],
            e.role,
            (v) => c.update(e.copyWith(role: v))),
      if (p.contains(DsProp.align))
        _choices<ScreenAlign>(
            'ALINEACIÓN',
            const [
              (ScreenAlign.start, 'Izquierda'),
              (ScreenAlign.center, 'Centro'),
              (ScreenAlign.end, 'Derecha'),
            ],
            e.align,
            (v) => c.update(e.copyWith(align: v))),
    ];
  }

  List<Widget> _boxProps(ScreenElement e) {
    Widget num(String label, double v, ScreenElement Function(double) set) =>
        _NumProp(
            label: label,
            value: v,
            onSubmitted: (n) => c.update(set(n)));
    return [
      _choices<HAnchor>(
          'ANCLA HORIZONTAL',
          const [
            (HAnchor.left, 'Izquierda'),
            (HAnchor.center, 'Centro'),
            (HAnchor.right, 'Derecha'),
            (HAnchor.stretch, 'Estirar'),
          ],
          e.hAnchor,
          (v) => c.update(e.copyWith(hAnchor: v))),
      _choices<VAnchor>(
          'ANCLA VERTICAL',
          const [
            (VAnchor.top, 'Arriba'),
            (VAnchor.center, 'Centro'),
            (VAnchor.bottom, 'Abajo'),
            (VAnchor.stretch, 'Estirar'),
          ],
          e.vAnchor,
          (v) => c.update(e.copyWith(vAnchor: v))),
      Wrap(spacing: DsSpace.sm, runSpacing: DsSpace.sm, children: [
        num('X', e.x, (n) => e.copyWith(x: n)),
        num('Y', e.y, (n) => e.copyWith(y: n)),
        num('ANCHO', e.w, (n) => e.copyWith(w: n)),
        num('ALTO', e.h, (n) => e.copyWith(h: n)),
      ]),
    ];
  }

  List<Widget> _logicProps(ScreenElement e, DsComponentSpec spec) {
    final s = c.spec;
    final p = spec.props;
    final out = <Widget>[];
    if (spec.interactive) {
      out.add(Padding(
        padding: EdgeInsets.only(bottom: DsSpace.sm),
        child: Row(children: [
          Text('ORDEN DE FOCO  ${e.focusOrder ?? '-'}',
              style: DsText.detail()),
          SizedBox(width: DsSpace.sm),
          DsButton('-',
              size: DsButtonSize.compact,
              onPressed: (e.focusOrder ?? 0) > 1
                  ? () => c.update(e.copyWith(focusOrder: e.focusOrder! - 1))
                  : null),
          SizedBox(width: DsSpace.xs),
          DsButton('+',
              size: DsButtonSize.compact,
              onPressed: () =>
                  c.update(e.copyWith(focusOrder: (e.focusOrder ?? 0) + 1))),
        ]),
      ));
    }
    if (s == null) return out;
    if (p.contains(DsProp.action)) {
      out.add(_choices<String?>(
          'ACCIÓN',
          [(null, 'Ninguna'), for (final a in s.actions) (a.id, a.label)],
          e.action,
          (v) => c.update(e.copyWith(action: v))));
    }
    if (p.contains(DsProp.dataSource)) {
      out.add(_choices<String?>(
          'FUENTE DE DATOS',
          [for (final d in s.dataSources) (d.id, d.label)],
          e.dataSource,
          (v) => c.update(e.copyWith(dataSource: v))));
      final sample = c.sampleFor(e);
      out
        ..add(Text('APARECERÍAN ${sample.length} (EJEMPLO)',
            style: DsText.detail()))
        ..add(SizedBox(height: DsSpace.xs));
      for (final d in sample) {
        out.add(Text(retroText('${d.label}  ${d.detail}'),
            style: DsText.body()));
      }
    }
    if (p.contains(DsProp.slot)) {
      out.add(_choices<String?>(
          'HUECO',
          [for (final d in s.slots) (d.id, d.label)],
          e.slot,
          (v) => c.update(e.copyWith(slot: v))));
    }
    if (out.isEmpty) {
      out.add(Text('Sin lógica para este componente', style: DsText.detail()));
    }
    return out;
  }
}

class _TextProp extends StatefulWidget {
  const _TextProp({super.key, required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_TextProp> createState() => _TextPropState();
}

class _TextPropState extends State<_TextProp> {
  late final _ctl = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(_TextProp old) {
    super.didUpdateWidget(old);
    if (widget.value != _ctl.text) _ctl.text = widget.value;
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: DsSpace.sm),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('TEXTO', style: DsText.detail()),
          SizedBox(height: DsSpace.xs),
          TextField(
              key: const ValueKey('screen-text-field'),
              controller: _ctl,
              style: DsText.body(),
              onChanged: widget.onChanged),
        ]),
      );
}

class _NumProp extends StatefulWidget {
  const _NumProp(
      {required this.label, required this.value, required this.onSubmitted});
  final String label;
  final double value;
  final ValueChanged<double> onSubmitted;

  @override
  State<_NumProp> createState() => _NumPropState();
}

class _NumPropState extends State<_NumProp> {
  late final _ctl = TextEditingController(text: _fmt(widget.value));

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  @override
  void didUpdateWidget(_NumProp old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _ctl.text = _fmt(widget.value);
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _submit(String s) {
    final n = double.tryParse(s.replaceAll(',', '.'));
    if (n != null) widget.onSubmitted(n);
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 150,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.label, style: DsText.detail()),
          TextField(
              controller: _ctl,
              style: DsText.body(),
              keyboardType: TextInputType.number,
              onSubmitted: _submit),
        ]),
      );
}

/// Lienzo de edición a la resolución base, escalado para entrar.
class _EditCanvas extends StatefulWidget {
  const _EditCanvas({required this.c});
  final ScreenEditorController c;

  @override
  State<_EditCanvas> createState() => _EditCanvasState();
}

class _EditCanvasState extends State<_EditCanvas> {
  Rect? _start;
  Offset _acc = Offset.zero;

  ScreenEditorController get c => widget.c;

  void _begin(String id) {
    c.beginEdit();
    c.select(id);
    _start = c.layout.byId(id)?.rect;
    _acc = Offset.zero;
  }

  @override
  Widget build(BuildContext context) {
    final l = c.layout;
    return LayoutBuilder(builder: (context, box) {
      final k = (box.maxWidth / l.width) < (box.maxHeight / l.height)
          ? box.maxWidth / l.width
          : box.maxHeight / l.height;
      return Center(
        child: SizedBox(
          width: l.width * k,
          height: l.height * k,
          child: GestureDetector(
            onTap: () => c.select(null),
            child: Stack(clipBehavior: Clip.hardEdge, children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: DsColors.background,
                    border: Border.all(color: DsColors.border, width: 2),
                  ),
                ),
              ),
              if (c.showGrid)
                Positioned.fill(
                  child: CustomPaint(
                      painter: _GridPainter(
                          step: ScreenEditorController.grid * 2 * k,
                          color: DsColors.border)),
                ),
              for (final e in l.elements) _element(e, k),
            ]),
          ),
        ),
      );
    });
  }

  Widget _element(ScreenElement e, double k) {
    final selected = e.id == c.selectedId;
    return Positioned(
      key: ValueKey('screen-el-${e.id}'),
      left: e.x * k,
      top: e.y * k,
      width: e.w * k,
      height: e.h * k,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => c.select(e.id),
        onPanStart: (_) => _begin(e.id),
        onPanUpdate: (d) {
          final s = _start;
          if (s == null) return;
          _acc += d.delta / k;
          c.setRect(e.id, s.shift(_acc));
        },
        onPanEnd: (_) => _start = null,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(
            child: IgnorePointer(
              child: OverflowBox(
                alignment: Alignment.topLeft,
                minWidth: 0,
                minHeight: 0,
                maxWidth: double.infinity,
                maxHeight: double.infinity,
                child: Transform.scale(
                  scale: k,
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: e.w,
                    height: e.h,
                    child: buildScreenElement(context, e,
                        registry: c.registry, spec: c.spec, preview: true),
                  ),
                ),
              ),
            ),
          ),
          if (selected)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                      border: Border.all(color: DsColors.selected, width: 2)),
                ),
              ),
            ),
          if (selected)
            Positioned(
              right: -6,
              bottom: -6,
              width: 12,
              height: 12,
              child: GestureDetector(
                key: const ValueKey('screen-resize-handle'),
                behavior: HitTestBehavior.opaque,
                onPanStart: (_) => _begin(e.id),
                onPanUpdate: (d) {
                  final s = _start;
                  if (s == null) return;
                  _acc += d.delta / k;
                  c.setRect(
                      e.id,
                      Rect.fromLTWH(s.left, s.top, s.width + _acc.dx,
                          s.height + _acc.dy));
                },
                onPanEnd: (_) => _start = null,
                child: const ColoredBox(color: DsColors.selected),
              ),
            ),
        ]),
      ),
    );
  }
}

/// Vista previa a un tamaño de ventana, con las anclas aplicadas.
class _PreviewCanvas extends StatelessWidget {
  const _PreviewCanvas({required this.c, required this.window});
  final ScreenEditorController c;
  final Size window;

  @override
  Widget build(BuildContext context) => Center(
        child: FittedBox(
          child: Container(
            width: window.width,
            height: window.height,
            decoration: BoxDecoration(
              color: DsColors.background,
              border: Border.all(color: DsColors.border, width: 2),
            ),
            child: DsScreenView(
                layout: c.layout,
                registry: c.registry,
                spec: c.spec,
                preview: true),
          ),
        ),
      );
}

class _GridPainter extends CustomPainter {
  const _GridPainter({required this.step, required this.color});
  final double step;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (step < 4) return;
    final p = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    for (var x = 0.0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (var y = 0.0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.step != step || old.color != color;
}
