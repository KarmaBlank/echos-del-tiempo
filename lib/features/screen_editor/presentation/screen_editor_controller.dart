import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../../app/design/registry/ds_registry.dart';
import '../../../core/screen_layout/screen_bindings.dart';
import '../../../core/screen_layout/screen_layout.dart';
import '../../../core/screen_layout/screen_layout_catalog.dart';
import '../data/screen_layout_writer.dart';
import '../domain/screen_checks.dart';

/// Mide con el `TextPainter` del motor (lo que el juego dibuja).
Size measureDsText(String text, DsTextStyleId style, double maxWidth) {
  final p = TextPainter(
    text: TextSpan(text: text, style: style.style()),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: maxWidth.isFinite ? math.max(0, maxWidth) : double.infinity);
  final s = p.size;
  p.dispose();
  return s;
}

/// Estado del editor de pantallas (docs/specs/screen_editor.md § 5).
class ScreenEditorController extends ChangeNotifier {
  ScreenEditorController({
    required this.catalog,
    this.writer,
    DsRegistry? registry,
    ScreenBindingRegistry? bindings,
    this.measure = measureDsText,
  })  : registry = registry ?? DsRegistry.instance,
        bindings = bindings ?? catalog.bindings {
    _open(screens.first);
  }

  final ScreenLayoutCatalog catalog;
  final ScreenLayoutWriter? writer;
  final DsRegistry registry;
  final ScreenBindingRegistry bindings;
  final TextMeasure measure;

  static const grid = 8.0;

  late String screen;
  late ScreenLayout layout;
  late ScreenLayout _saved;
  String? selectedId;
  bool showGrid = true;

  /// Tamaño de ventana de la vista previa (`null` = editando).
  Size? preview;

  /// Resultado del último VERIFICAR (`null` = no se corrió).
  List<ScreenIssue>? issues;
  String? message;
  final _undo = <ScreenLayout>[];

  List<String> get screens => catalog.screens;
  ScreenBindingSpec? get spec => bindings[screen];
  bool get dirty => layout != _saved;
  bool get canUndo => _undo.isNotEmpty;
  bool get canSave => writer != null && dirty;
  ScreenElement? get selected =>
      selectedId == null ? null : layout.byId(selectedId!);

  void _open(String s) {
    screen = s;
    layout = catalog.get(s) ?? ScreenLayout(screen: s);
    _saved = layout;
    selectedId = null;
    issues = null;
    _undo.clear();
  }

  void openScreen(String s) {
    _open(s);
    notifyListeners();
  }

  void _set(ScreenLayout l, {bool record = true}) {
    if (record) {
      _undo.add(layout);
      if (_undo.length > 100) _undo.removeAt(0);
    }
    layout = l;
    if (issues != null) issues = _checker().run(layout);
    notifyListeners();
  }

  /// Guarda un punto de DESHACER (al empezar a arrastrar).
  void beginEdit() {
    _undo.add(layout);
  }

  void undo() {
    if (_undo.isEmpty) return;
    layout = _undo.removeLast();
    if (selectedId != null && layout.byId(selectedId!) == null) {
      selectedId = null;
    }
    if (issues != null) issues = _checker().run(layout);
    notifyListeners();
  }

  void select(String? id) {
    selectedId = id;
    notifyListeners();
  }

  static double snap(double v) => (v / grid).round() * grid;

  String _newId(String component) {
    var i = 1;
    while (layout.byId('$component-$i') != null) {
      i++;
    }
    return '$component-$i';
  }

  /// Suma un componente del registro en el centro del lienzo.
  void add(String componentId) {
    final c = registry[componentId];
    if (c == null) return;
    final sz = c.defaultSize;
    final s = spec;
    final e = ScreenElement(
      id: _newId(componentId),
      component: componentId,
      variant: c.defaultVariant,
      size: c.defaultSizeId,
      text: c.props.contains(DsProp.text) ? c.defaultText : null,
      textStyle: c.defaultTextStyle?.name,
      x: snap((layout.width - sz.width) / 2),
      y: snap((layout.height - sz.height) / 2),
      w: sz.width,
      h: sz.height,
      focusOrder: c.interactive
          ? layout.elements
                  .map((e) => e.focusOrder ?? 0)
                  .fold(0, math.max) +
              1
          : null,
      dataSource: c.props.contains(DsProp.dataSource)
          ? s?.dataSources.firstOrNull?.id
          : null,
      slot: c.props.contains(DsProp.slot) ? s?.slots.firstOrNull?.id : null,
    );
    _set(layout.copyWith(elements: [...layout.elements, e]));
    selectedId = e.id;
    notifyListeners();
  }

  /// Reemplaza un elemento (inspector).
  void update(ScreenElement e, {bool record = true}) =>
      _set(layout.replace(e), record: record);

  /// Caja nueva de [id] (arrastre / redimensión), con imán a la grilla.
  void setRect(String id, Rect r, {bool record = false}) {
    final e = layout.byId(id);
    if (e == null) return;
    update(
        e.copyWith(
          x: snap(r.left),
          y: snap(r.top),
          w: math.max(grid, snap(r.width)),
          h: math.max(grid, snap(r.height)),
        ),
        record: record);
  }

  /// Orden Z: [delta] +1 adelante, -1 atrás.
  void reorder(String id, int delta) {
    final list = [...layout.elements];
    final i = list.indexWhere((e) => e.id == id);
    final j = i + delta;
    if (i < 0 || j < 0 || j >= list.length) return;
    final e = list.removeAt(i);
    list.insert(j, e);
    _set(layout.copyWith(elements: list));
  }

  void delete(String id) {
    _set(layout.copyWith(
        elements: [for (final e in layout.elements) if (e.id != id) e]));
    if (selectedId == id) selectedId = null;
    notifyListeners();
  }

  void duplicate(String id) {
    final e = layout.byId(id);
    if (e == null) return;
    final copy = e.copyWith(id: _newId(e.component), x: e.x + 16, y: e.y + 16);
    _set(layout.copyWith(elements: [...layout.elements, copy]));
    selectedId = copy.id;
    notifyListeners();
  }

  void toggleGrid() {
    showGrid = !showGrid;
    notifyListeners();
  }

  void setPreview(Size? s) {
    preview = s;
    notifyListeners();
  }

  ScreenChecker _checker() =>
      ScreenChecker(registry: registry, bindings: spec, measure: measure);

  /// VERIFICAR.
  void verify() {
    issues = _checker().run(layout);
    message = issues!.isEmpty
        ? 'Sin avisos'
        : '${issues!.length} aviso${issues!.length == 1 ? '' : 's'}';
    notifyListeners();
  }

  /// APLICAR el arreglo de [issue].
  void applyFix(ScreenIssue issue) {
    final f = issue.fix;
    if (f == null) return;
    _set(f(layout));
  }

  /// Datos de ejemplo de la fuente de [e] (lo que aparecería).
  List<ScreenDataEntry> sampleFor(ScreenElement e) =>
      spec?.dataSource(e.dataSource)?.sample ?? const [];

  /// GUARDAR: escribe el JSON en el repo y recarga el catálogo.
  Future<bool> save() async {
    final w = writer;
    if (w == null) {
      message = 'Sin repo para guardar';
      notifyListeners();
      return false;
    }
    await w(screen, layout.encode());
    catalog.put(screen, layout);
    _saved = layout;
    message = 'Guardado en ${ScreenLayoutCatalog.pathOf(screen)}';
    notifyListeners();
    return true;
  }

  /// RESTAURAR lo guardado.
  void revert() {
    _set(_saved);
    message = 'Restaurado';
    notifyListeners();
  }
}
