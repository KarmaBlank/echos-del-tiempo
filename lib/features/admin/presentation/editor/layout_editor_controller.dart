import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../../../core/layout/layout_catalog.dart';
import '../../../../core/layout/layout_doc.dart';
import '../../../../core/layout/layout_spec.dart';
import '../../../../core/layout/layout_validator.dart';
import 'layout_previews.dart';

/// Un tamaño de ventana del lienzo (§ 3, "Lienzo").
class LayoutCanvasSize {
  const LayoutCanvasSize(this.label, this.size);
  final String label;
  final Size size;
}

/// Estado de Editor → LAYOUT (editor_layout.md § 3): pantalla elegida,
/// doc en edición, selección, deshacer/rehacer, tamaño de ventana y de
/// texto, validación. Sin Flutter de UI: la página lo dibuja.
class LayoutEditorController extends ChangeNotifier {
  LayoutEditorController({
    required this.catalog,
    this.overrides,
    this.repoPath,
    List<LayoutPreview>? previews,
  }) : previews = previews ?? layoutPreviews() {
    _open(0);
  }

  final LayoutCatalog catalog;
  final EditableLayoutOverrides? overrides;
  final String? repoPath;
  final List<LayoutPreview> previews;

  /// Matriz de tamaños (§ 3): 1280×720, 1920×1080, 2560×1440, angostos.
  static const sizes = [
    LayoutCanvasSize('1280×720', Size(1280, 720)),
    LayoutCanvasSize('1920×1080', Size(1920, 1080)),
    LayoutCanvasSize('2560×1440', Size(2560, 1440)),
    LayoutCanvasSize('800×600', Size(800, 600)),
    LayoutCanvasSize('600×900', Size(600, 900)),
  ];

  /// Tamaños de texto (100/125/150/200 %).
  static const texts = [1.0, 1.25, 1.5, 2.0];

  int _screen = 0;
  int get screenIndex => _screen;
  LayoutPreview get preview => previews[_screen];
  LayoutScreenSpec? get spec => preview.spec;

  LayoutDoc? _doc;
  LayoutDoc? get doc => _doc;
  LayoutDoc? _saved;

  /// Hay cambios sin guardar como override.
  bool get dirty => _doc != null && _saved != null && !_doc!.sameAs(_saved!);

  final _undo = <LayoutDoc>[];
  final _redo = <LayoutDoc>[];
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  String? _selected;
  String? get selected => _selected;

  Size _size = sizes.first.size;
  Size get canvasSize => _size;
  double _text = 1;
  double get textFactor => _text;

  /// Corte que se edita en el panel de propiedades (`null` = base).
  LayoutBreakpoint? _editBp;
  LayoutBreakpoint? get editBreakpoint => _editBp;

  /// Corte que muestra el lienzo (lo informa el host).
  LayoutBreakpoint? previewBreakpoint;

  /// Última línea de resultado (guardar, publicar, ...).
  String? message;

  List<LayoutIssue> _static = const [];
  List<LayoutIssue> get staticIssues => _static;

  /// Problemas geométricos del tamaño actual (los mide la página).
  List<LayoutIssue> geometry = const [];

  /// Resultado de VALIDAR TODO (`null` = no se corrió para este doc).
  List<LayoutIssue>? matrix;

  List<LayoutIssue> get issues => [..._static, ...geometry, ...?matrix];
  bool get hasErrors => issues.any((i) => i.error);

  void _open(int i) {
    _screen = i;
    _selected = null;
    _undo.clear();
    _redo.clear();
    final s = spec;
    _doc = s == null ? null : catalog.docFor(s);
    _saved = _doc;
    _revalidate();
  }

  void _revalidate() {
    final s = spec, d = _doc;
    _static = s == null || d == null ? const [] : LayoutValidator.validateStatic(d, s);
    matrix = null;
  }

  void openScreen(int i) {
    if (i == _screen) return;
    _open(i);
    message = null;
    notifyListeners();
  }

  // ---------------------------------------------------------- lienzo

  void setSize(Size s) {
    if (s == _size) return;
    _size = s;
    notifyListeners();
  }

  void setText(double f) {
    if (f == _text) return;
    _text = f;
    notifyListeners();
  }

  void setEditBreakpoint(LayoutBreakpoint? bp) {
    _editBp = bp;
    notifyListeners();
  }

  /// Lo llama la página tras medir (no notifica si no cambió).
  void setGeometry(List<LayoutIssue> g) {
    if (listEquals(g.map((e) => '$e').toList(),
        geometry.map((e) => '$e').toList())) {
      return;
    }
    geometry = g;
    notifyListeners();
  }

  void setMatrix(List<LayoutIssue> m) {
    matrix = m;
    message = m.where((i) => i.error).isEmpty
        ? 'VALIDAR TODO: sin errores (${sizes.length}×${texts.length})'
        : 'VALIDAR TODO: ${m.where((i) => i.error).length} errores';
    notifyListeners();
  }

  // ------------------------------------------------------- selección

  /// Región o grupo que contiene a [id] en el corte del lienzo.
  String? containerOf(String id) =>
      _doc?.resolve(previewBreakpoint).containerOf(id) ??
      _doc?.placementOf(id)?.region;

  bool isGroup(String id) => spec?.slots[id]?.group ?? false;

  void select(String? id) {
    if (id == _selected) return;
    _selected = id;
    notifyListeners();
  }

  /// Clic: el slot más interno; clic de nuevo (o Alt) sube al grupo.
  void tapSlot(String id, {bool alt = false}) {
    if (alt || _selected == id) {
      final parent = containerOf(id);
      if (parent != null && isGroup(parent)) return select(parent);
      return select(id);
    }
    select(id);
  }

  /// Esc: sube al grupo padre (o suelta la selección).
  void selectParent() {
    final s = _selected;
    if (s == null) return;
    final parent = containerOf(s);
    select(parent != null && isGroup(parent) ? parent : null);
  }

  // --------------------------------------------------------- edición

  void _apply(LayoutDoc next) {
    final d = _doc;
    if (d == null || next.sameAs(d)) return;
    _undo.add(d);
    if (_undo.length > 200) _undo.removeAt(0);
    _redo.clear();
    _doc = next;
    message = null;
    _revalidate();
    notifyListeners();
  }

  bool canMove(String id) => spec?.slots[id]?.movable ?? false;

  bool allows(String id, String container) =>
      spec?.allows(id, container) ?? false;

  /// Arrastrar/soltar o teclado: [id] a [container] en [index] (índice
  /// en el orden actual del corte que se edita). `false` si no se puede.
  bool move(String id, String container, int index) {
    final d = _doc;
    if (d == null || !canMove(id) || !allows(id, container)) return false;
    var at = index;
    final cur = d.resolve(_editBp).of(container);
    final from = cur.indexOf(id);
    if (from >= 0 && from < at) at--;
    _apply(d.move(id, container, at, bp: _editBp));
    _selected = id;
    return true;
  }

  /// Flechas: reordena el seleccionado dentro de su región.
  void nudge(int delta) {
    final id = _selected, d = _doc;
    if (id == null || d == null || !canMove(id)) return;
    final res = d.resolve(_editBp);
    final c = res.containerOf(id) ?? d.placementOf(id)!.region;
    final list = res.of(c);
    final i = list.indexOf(id);
    final j = (i + delta).clamp(0, list.length - 1);
    if (j == i) return;
    _apply(d.move(id, c, j, bp: _editBp));
  }

  /// Tab: pasa el seleccionado a la siguiente región (o grupo) permitida.
  void cycleRegion({bool back = false}) {
    final id = _selected, d = _doc, s = spec;
    if (id == null || d == null || s == null || !canMove(id)) return;
    final all = [
      for (final r in s.regions) r.id,
      for (final g in s.slots.values)
        if (g.group) g.id,
    ].where((c) => s.allows(id, c)).toList();
    if (all.length < 2) return;
    final cur = d.resolve(_editBp).containerOf(id) ?? d.placementOf(id)!.region;
    final i = all.indexOf(cur);
    final next = all[(i + (back ? -1 : 1)) % all.length];
    _apply(d.move(id, next, 1 << 20, bp: _editBp));
  }

  /// Cambia una propiedad del seleccionado en el corte que se edita.
  void setRule(String id, SlotRule Function(SlotRule) f) {
    final d = _doc;
    if (d == null) return;
    _apply(d.withRule(_editBp, id, f));
  }

  /// Cambia una perilla de la pantalla (§ 2.8); el defecto la saca del
  /// YAML.
  void setParam(String key, double v) {
    final d = _doc, p = spec?.paramSpec(key);
    if (d == null || p == null) return;
    final c = p.clamp(v);
    _apply(d.withParam(key, c == p.defaultValue ? null : c));
  }

  /// La regla propia del corte que se edita (sin heredar) y la efectiva.
  (SlotRule own, SlotRule effective) ruleOf(String id) {
    final d = _doc;
    if (d == null) return (const SlotRule(), const SlotRule());
    final bp = _editBp;
    final own = bp == null
        ? d.placementOf(id)?.rule ?? const SlotRule()
        : d.breakpoints[bp]?[id] ?? const SlotRule();
    return (own, d.resolve(bp).ruleOf(id));
  }

  void undo() {
    if (_undo.isEmpty || _doc == null) return;
    _redo.add(_doc!);
    _doc = _undo.removeLast();
    _revalidate();
    notifyListeners();
  }

  void redo() {
    if (_redo.isEmpty || _doc == null) return;
    _undo.add(_doc!);
    _doc = _redo.removeLast();
    _revalidate();
    notifyListeners();
  }

  // ------------------------------------------------------ persistencia

  String _encode(LayoutDoc d) => d.encode(
      header: '${preview.title} (docs/specs/editor_layout.md). Generado por '
          'Editor -> LAYOUT.');

  /// Guarda el override local y recarga en caliente. Con errores, no.
  Future<bool> save() async {
    final d = _doc, s = spec, o = overrides;
    if (d == null || s == null) return false;
    if (hasErrors) {
      message = 'No se guarda: hay errores de validación';
      notifyListeners();
      return false;
    }
    if (o == null) {
      message = 'Sin carpeta de overrides';
      notifyListeners();
      return false;
    }
    await o.put(s.screen, _encode(d));
    await catalog.reload(s.screen);
    _saved = d;
    message = 'Guardado como override (${s.screen})';
    notifyListeners();
    return true;
  }

  /// RESTAURAR: borra el override y vuelve al del repo.
  Future<void> restore() async {
    final s = spec;
    if (s == null) return;
    await overrides?.remove(s.screen);
    await catalog.reload(s.screen);
    final repo = catalog.repoDoc(s);
    if (_doc != null) _apply(repo);
    _saved = repo;
    message = 'Restaurado el layout del repo';
    notifyListeners();
  }

  /// RECARGAR: relee repo + override del disco (descarta lo no guardado).
  Future<void> reload() async {
    final s = spec;
    if (s == null) return;
    await catalog.reload(s.screen);
    final d = catalog.docFor(s);
    if (_doc != null) _apply(d);
    _saved = d;
    message = 'Recargado (${catalog.sourceOf(s.screen)})';
    notifyListeners();
  }

  /// PUBLICAR AL REPO (mismo circuito que sprites): guarda, copia a
  /// `assets/layouts/` y borra el override.
  Future<bool> publish() async {
    final s = spec, o = overrides, repo = repoPath;
    if (s == null || o == null || repo == null) {
      message = 'Sin repo para publicar';
      notifyListeners();
      return false;
    }
    if (!await save()) return false;
    final ok = await o.publish(repo, s.screen);
    await catalog.reload(s.screen);
    message = ok
        ? 'Publicado en assets/layouts/${s.screen}.layout.yaml'
        : 'Nada para publicar';
    notifyListeners();
    return ok;
  }
}
