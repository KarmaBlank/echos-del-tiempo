import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import 'package:flutter/services.dart';

import '../../../app/design/design.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../app/theme/ui_theme.dart';
import '../../../app/widgets/pixel_icon.dart';
import '../../../game_engine/models/passive_tree.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/rules/passive_tree_rules.dart';
import '../../build_planner/presentation/build_planner_view.dart'
    show PickOption, showBuildPicker;
import '../domain/passive_text.dart';

/// El árbol de pasivas v3 (docs/specs/passive_tree_v3.md § 13): lienzo con
/// arrastre, rueda y botones de zoom, buscador que resalta nodos, camino
/// hasta el nodo bajo el mouse con su costo, tooltip con el efecto
/// completo, info del nodo elegido y botones de tomar y reiniciar. Ver
/// también docs/specs/panels.md § "Árbol".
class PassiveTreeView extends StatefulWidget {
  const PassiveTreeView({
    super.key,
    required this.rules,
    required this.profile,
    required this.inBattle,
    required this.onTake,
    this.resetReason,
    this.onReset,
    this.showReset = true,
    this.resetLabel = 'REINICIAR ÁRBOL',
    this.height = PassiveTreeView.viewportHeight,
    this.showHelp = true,
    this.planned = const {},
    this.onPlan,
    this.onTakePath,
    this.onMark,
    this.onChooseMilestone,
    this.onUntake,
    this.untakeReason,
  });

  /// Quitar un nodo tomado (progression_v2.md § 6.1); `null` = no se
  /// ofrece.
  final ValueChanged<String>? onUntake;

  /// Motivo por el que no se puede quitar un nodo (`null` = se puede).
  final String? Function(String nodeId)? untakeReason;

  /// Camino en un clic (progression_v2.md § 4): toma la lista en orden.
  final ValueChanged<List<String>>? onTakePath;

  /// MARCAR: agrega o quita un nodo del plan de build.
  final ValueChanged<String>? onMark;

  /// Hito del nivel 10 / 20 (progression_v2.md § 5).
  final void Function(int milestone, String keystoneId)? onChooseMilestone;

  final PassiveTreeRules rules;
  final PlayerProfile profile;
  final bool inBattle;
  final ValueChanged<String> onTake;

  /// Motivo por el que no se puede reiniciar (`null` = se puede).
  final String? resetReason;
  final VoidCallback? onReset;
  final bool showReset;
  final String resetLabel;

  /// Alto del visor; `null` = ocupa lo que queda debajo de la fila de
  /// arriba (el padre debe dar un alto acotado, como el panel de
  /// personaje).
  final double? height;

  /// Línea de ayuda propia (el panel de personaje ya pone la suya).
  final bool showHelp;

  /// Nodos del plan de build: anillo violeta (build_planner.md § 4.2).
  final Set<String> planned;

  /// Modo PLANIFICAR: el clic marca o desmarca el nodo en el plan en vez
  /// de tomarlo.
  final ValueChanged<String>? onPlan;

  bool get planning => onPlan != null;

  /// Lado del lienzo (mundo) y píxeles por unidad de árbol. El árbol v6
  /// llega a ±21.5 unidades con las etiquetas (passive_tree_v6.md § 2):
  /// ±23.
  static const size = 1380.0;
  static const scale = 30.0;

  /// Zoom mínimo y máximo del visor (0.2: TODO encuadra el árbol v6 de
  /// ~41 unidades en un visor de ~350 px de alto).
  static const minZoom = 0.2;
  static const maxZoom = 2.5;

  /// Alto del visor por defecto.
  static const viewportHeight = 420.0;

  /// Centro del nodo [n] en el lienzo (coordenadas del mundo).
  static Offset nodeCenter(PassiveNode n) => toCanvas(n.x, n.y);

  /// Punto del árbol (unidades) → lienzo.
  static Offset toCanvas(double x, double y) =>
      Offset(size / 2 + x * scale, size / 2 + y * scale);

  /// Radio mínimo del área de clic de un nodo, en px de pantalla.
  static const minHitRadius = 12.0;

  /// Radio del nodo: keystone 11 (hexágono), inicio 9, notable 8, resto 5.
  static double nodeRadius(PassiveNode n, {required bool start}) =>
      switch (n.kind) {
        'k' => 11,
        'st' => 9,
        'n' => 8,
        _ => start ? 9 : 5,
      };

  @override
  State<PassiveTreeView> createState() => _PassiveTreeViewState();
}

class _PassiveTreeViewState extends State<PassiveTreeView> {
  final _transform = TransformationController();
  final _search = TextEditingController();
  String? _hover;

  /// Hito: keystone elegida con el primer clic (el segundo confirma).
  String? _selected;

  /// Nodo con el tooltip fijado (clic); Esc o un clic afuera lo suelta.
  String? _pinned;

  /// Último cambio de un nodo (DESHACER): (tomado, id).
  (bool, String)? _last;

  bool _isTaken(String id) => widget.profile.tree.contains(id);

  /// Hito pendiente: el árbol no se puede gastar hasta elegirlo
  /// (progression_v2.md § 5.1). Quitar nodos sigue permitido.
  bool get _locked =>
      widget.onChooseMilestone != null &&
      widget.profile.pendingMilestones.isNotEmpty;

  /// Aviso del árbol bloqueado por un hito pendiente.
  static const lockedText = 'Primero elegí tu hito';

  void _take(String id) {
    if (_locked) return;
    _last = (true, id);
    widget.onTake(id);
  }

  void _untake(String id) {
    final f = widget.onUntake;
    if (f == null) return;
    setState(() {
      _pinned = null;
      _last = (false, id);
    });
    f(id);
  }

  /// DESHACER: el inverso del último cambio, si todavía aplica.
  VoidCallback? get _undo {
    final l = _last;
    if (l == null || widget.inBattle) return null;
    final (took, id) = l;
    if (took) {
      if (!_isTaken(id) || widget.untakeReason?.call(id) != null) return null;
      return () {
        widget.onUntake?.call(id);
        setState(() => _last = null);
      };
    }
    if (_locked || !_status(id).canTake) return null;
    return () {
      widget.onTake(id);
      setState(() => _last = null);
    };
  }

  /// Clic derecho: quita el nodo tomado sin confirmar (atajo).
  void _secondaryTap(Offset pos) {
    final id = _hit(pos);
    if (id == null || widget.onPlan != null || !_isTaken(id)) return;
    if (widget.untakeReason?.call(id) == null) _untake(id);
  }

  /// Tarjeta de hito bajo el mouse (resalta su camino).
  String? _cardHover;
  final _keys = FocusNode(debugLabel: 'tree');
  Size? _fittedFor;
  Size _view = Size.zero;
  String _query = '';

  /// Texto de búsqueda de cada nodo (se arma una vez por catálogo).
  static final _searchIndex = Expando<Map<String, String>>();

  @override
  void dispose() {
    _transform.dispose();
    _search.dispose();
    _keys.dispose();
    super.dispose();
  }

  PassiveTreeCatalog get _cat => widget.rules.catalog;

  /// Estados de todos los nodos, recalculados solo cuando cambia el
  /// perfil (no al mover el mouse: ~600 nodos en el árbol v6).
  Map<String, TreeNodeState>? _states;
  String? _statesKey;

  Map<String, TreeNodeState> _allStates() {
    final p = widget.profile;
    final key = '${identityHashCode(_cat)}|${p.classId}|${p.treePoints}|'
        '${widget.inBattle}|${p.tree.join(',')}';
    if (_statesKey != key || _states == null) {
      _statesKey = key;
      _states = {for (final id in _cat.nodes.keys) id: _status(id).state};
    }
    return _states!;
  }

  /// Caja de todos los nodos (unidades de árbol).
  static final _bounds = Expando<Rect>();

  Rect get _treeBounds => _bounds[_cat] ??= _cat.nodes.values.fold<Rect?>(
          null,
          (r, n) => (r ?? Rect.fromLTWH(n.x, n.y, 0, 0))
              .expandToInclude(Rect.fromLTWH(n.x, n.y, 0, 0))) ??
      Rect.zero;

  /// Margen de TODO en px de pantalla: el radio de una keystone (11) más
  /// su anillo de foco y un respiro.
  static const fitMargin = 20.0;

  TreeNodeStatus _status(String id) => treeNodeStatus(
        widget.rules,
        classId: widget.profile.classId,
        // La Maestría suma puntos de árbol (ecos_atlas.md § 6).
        level: widget.profile.treePoints,
        progress: widget.profile.passiveProgress,
        nodeId: id,
        inBattle: widget.inBattle,
      );

  Set<String> _hits() {
    final q = foldSearch(_query.trim());
    if (q.length < 2) return const {};
    final index = _searchIndex[_cat] ??= {
      for (final n in _cat.nodes.values) n.id: passiveSearchText(_cat, n),
    };
    return {
      for (final e in index.entries)
        if (e.value.contains(q)) e.key,
    };
  }

  String? _hit(Offset pos) {
    String? best;
    var bestD = double.infinity;
    // El área de clic es más grande que el nodo dibujado: por lo menos
    // 12 px de pantalla de radio (24 de diámetro) con cualquier zoom; si
    // dos se pisan, gana el más cercano (accessibility.md § "Objetivos
    // clicables").
    final zoom = _transform.value.getMaxScaleOnAxis();
    final minR = PassiveTreeView.minHitRadius / (zoom <= 0 ? 1 : zoom);
    for (final n in _cat.nodes.values) {
      final d = (PassiveTreeView.nodeCenter(n) - pos).distance;
      final r = math.max(
          PassiveTreeView.nodeRadius(n, start: n.kind == 'st') + 4, minR);
      if (d <= r && d < bestD) {
        best = n.id;
        bestD = d;
      }
    }
    return best;
  }

  void _tap(Offset pos) {
    final id = _hit(pos);
    if (id == null) {
      if (_pinned != null) setState(() => _pinned = null);
      return;
    }
    if (widget.onPlan case final plan?) {
      setState(() => _pinned = id);
      plan(id);
    } else if (!_locked && _status(id).canTake) {
      // Conectado y con puntos: se toma con un clic.
      setState(() => _pinned = null);
      _take(id);
    } else {
      // Si no, se fija el tooltip con sus botones (TOMAR CAMINO).
      setState(() => _pinned = id);
      _keys.requestFocus();
    }
  }

  /// Camino en un clic (progression_v2.md § 4): un notable o keystone que
  /// todavía no conecta → confirmar "Tomar N nodos por N puntos".
  Future<void> _askPath(String id) async {
    final take = widget.onTakePath;
    final node = _cat.nodes[id];
    if (take == null || node == null || widget.inBattle || _locked) return;
    final p = widget.profile;
    final route = widget.rules.pathTo(p.classId, p.passiveProgress, id);
    if (route == null || route.length < 2) return;
    final n = route.length;
    final have = widget.rules.pointsAvailable(p.treePoints, p.passiveProgress);
    final names = [for (final r in route) _cat.nodes[r]!.name].join(' · ');
    final can = math.min(n, have);
    final choice = await showBuildPicker<String>(
        context, can >= n ? 'Tomar $n nodos por $n puntos' : 'Faltan puntos', [
      if (can > 0)
        PickOption(
            'take',
            can >= n
                ? 'Tomar $n nodos por $n puntos'
                : 'Tomar los primeros $can de $n (te faltan ${n - can})',
            names,
            key: 'path-take'),
      if (widget.onMark != null)
        PickOption('mark',
            widget.planned.contains(id) ? 'Quitar marca' : 'Marcar', null,
            key: 'path-mark'),
    ]);
    if (!mounted) return;
    switch (choice) {
      case 'take':
        take(route.take(can).toList());
      case 'mark':
        widget.onMark?.call(id);
    }
  }

  /// Zoom actual (escala en x; la z queda en 1).
  double get _zoom => _transform.value.storage[0];

  /// Pone el visor con zoom [k] centrado en el punto [focus] del lienzo.
  void _look(Offset focus, double k) {
    final z = k.clamp(PassiveTreeView.minZoom, PassiveTreeView.maxZoom);
    _transform.value = Matrix4.diagonal3Values(z, z, 1)
      ..setTranslationRaw(
          _view.width / 2 - focus.dx * z, _view.height / 2 - focus.dy * z, 0);
  }

  /// Centro del visor en coordenadas del lienzo.
  Offset get _viewCenter => MatrixUtils.transformPoint(
      Matrix4.inverted(_transform.value),
      Offset(_view.width / 2, _view.height / 2));

  void _zoomBy(double f) => setState(() => _look(_viewCenter, _zoom * f));

  /// Todo el árbol en el visor.
  /// Todo el árbol en el visor: la caja de todos los nodos (más el radio
  /// de los nodos) entra en los dos ejes, centrada.
  void _fitAll() {
    final b = _treeBounds;
    const s = PassiveTreeView.scale;
    final zx = (_view.width - 2 * fitMargin) / math.max(1, b.width * s);
    final zy = (_view.height - 2 * fitMargin) / math.max(1, b.height * s);
    setState(() => _look(
        PassiveTreeView.toCanvas(b.center.dx, b.center.dy), math.min(zx, zy)));
  }

  /// La zona de tu clase (su ruta y sus clusters).
  void _home({bool rebuild = true}) {
    final start = _cat.nodes[_cat.startNodeByClass[widget.profile.classId]];
    var focus =
        const Offset(PassiveTreeView.size / 2, PassiveTreeView.size / 2);
    var z = 0.8;
    if (start != null) {
      // Caja de la zona: los nodos de clusters de tu clase (v4 y
      // exteriores v6), del inicio a las keystones (sin los puentes).
      final dir = math.atan2(start.y, start.x);
      var box = Rect.fromCircle(center: Offset(start.x, start.y), radius: 1);
      for (final n in _cat.nodes.values) {
        final r = math.sqrt(n.x * n.x + n.y * n.y);
        var da = (math.atan2(n.y, n.x) - dir).abs();
        if (da > math.pi) da = 2 * math.pi - da;
        if (r < 2.5 || r > 21.0 || da > 40 * math.pi / 180) continue;
        final path = _cat.paths[n.pathId];
        if (path != null && path.kind != 'clase') continue;
        box = box.expandToInclude(Rect.fromLTWH(n.x, n.y, 0, 0));
      }
      // Margen para las etiquetas de los clusters (1 unidad más allá).
      box = box.inflate(1.6);
      focus = PassiveTreeView.toCanvas(box.center.dx, box.center.dy);
      z = math.min(_view.width / box.width, _view.height / box.height) /
          PassiveTreeView.scale;
    }
    z = z.clamp(0.5, 1.2);
    if (rebuild) {
      setState(() => _look(focus, z));
    } else {
      _look(focus, z);
    }
  }

  void _fit(Size view) {
    _view = view;
    if (_fittedFor == view) return;
    _fittedFor = view;
    _home(rebuild: false);
  }

  void _goToFirstHit() {
    final hits = _hits();
    if (hits.isEmpty) return;
    final n = _cat.nodes[hits.first]!;
    setState(() {
      _pinned = n.id;
      _look(PassiveTreeView.nodeCenter(n), math.max(_zoom, 1.0));
    });
  }

  @override
  Widget build(BuildContext context) {
    final rules = widget.rules;
    final p = widget.profile;
    final points = rules.pointsAvailable(p.treePoints, p.passiveProgress);
    final states = _allStates();
    // Hito pendiente (progression_v2.md § 5): sus keystones se marcan.
    final pending =
        widget.onChooseMilestone == null ? const <int>[] : p.pendingMilestones;
    final options = pending.isEmpty
        ? const <String>[]
        : rules.milestoneOptions(p.classId, pending.first,
            taken: PassiveTreeRules.milestoneTaken(
                p.tree, p.milestone10, p.milestone20));
    final hits = {..._hits(), ...options};
    final focusId = _hover ?? _pinned ?? _cardHover ?? _selected;
    final route = focusId == null
        ? const <String>[]
        : rules.pathTo(p.classId, p.passiveProgress, focusId) ?? const [];
    final hoverPath = focusId == null ? null : _cat.nodes[focusId]?.pathId;
    final fill = widget.height == null;
    return Focus(
      focusNode: _keys,
      onKeyEvent: (node, e) {
        if (e is KeyDownEvent &&
            e.logicalKey == LogicalKeyboardKey.escape &&
            _pinned != null) {
          setState(() => _pinned = null);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
        children: [
          _topBar(points, pending, hits.length),
          SizedBox(height: UiTheme.space(6)),
          if (pending.isNotEmpty) ...[
            _milestoneCards(pending.first, options),
            SizedBox(height: UiTheme.space(6)),
            Text(retroText(lockedText),
                key: const ValueKey('tree-locked'),
                style: DsText.detail(milestoneColor)),
            SizedBox(height: UiTheme.space(4)),
          ],
          _grow(
            fill,
            SizedBox(
              height: widget.height,
              child: LayoutBuilder(builder: (context, box) {
                _fit(box.biggest);
                return _viewport(
                    box.biggest, states, hoverPath, hits, route);
              }),
            ),
          ),
          SizedBox(height: UiTheme.space(4)),
          _legend(),
        ],
      ),
    );
  }

  static Widget _grow(bool fill, Widget child) =>
      fill ? Expanded(child: child) : child;

  /// Color de los hitos (los puntos de hito se ven aparte de los libres).
  static const milestoneColor = ProtoColors.orange;

  /// Barra de arriba en una fila (progression_v2.md § 11.2,
  /// design_system.md § 4): puntos y hito a la izquierda; buscador, zoom
  /// y reinicio a la derecha.
  Widget _topBar(int points, List<int> pending, int hitCount) {
    final pts = pending.isEmpty
        ? 0
        : pending
            .map((m) => PassiveTreeRules.milestonePoints[m] ?? 0)
            .reduce((a, b) => a + b);
    return DsToolbar(
      title: '',
      center: Row(children: [
        Text(retroText('$points ${points == 1 ? 'punto' : 'puntos'}'),
            key: const ValueKey('tree-points'),
            style: DsText.body(
                points > 0 ? DsColors.reward : DsColors.textSecondary)),
        if (pts > 0) ...[
          SizedBox(width: DsSpace.sm),
          const DsTag('HITO PENDIENTE',
              key: ValueKey('tree-milestone-points'),
              color: milestoneColor),
        ],
        SizedBox(width: DsSpace.md),
        // Con texto grande la barra se desplaza (nunca desborda).
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: _toolbar(hitCount),
            ),
          ),
        ),
      ]),
    );
  }

  /// Hito del nivel 10 / 20 (progression_v2.md § 5 y § 11.2): una
  /// tarjeta por keystone de entrada; pasar el mouse resalta su camino,
  /// el primer clic la elige ("Confirmar …") y el segundo confirma.
  Widget _milestoneCards(int m, List<String> options) {
    return Container(
      key: ValueKey('milestone-banner-$m'),
      padding: EdgeInsets.all(DsSpace.sm),
      decoration: BoxDecoration(
        border: Border.all(color: milestoneColor, width: 2),
        color: milestoneColor.withValues(alpha: 0.08),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(retroText('HITO DEL NIVEL $m'),
              style: DsText.subtitle(milestoneColor)),
          SizedBox(height: DsSpace.xs),
          Text(
              retroText('Elegí una keystone. El camino hasta ella '
                  'se toma solo y es gratis.'),
              key: const ValueKey('milestone-points'),
              style: DsText.body()),
          SizedBox(height: DsSpace.sm),
          Wrap(
            spacing: DsSpace.sm,
            runSpacing: DsSpace.sm,
            children: [
              for (final id in options) _milestoneCard(m, id),
            ],
          ),
        ],
      ),
    );
  }

  /// Centra el visor en el camino hasta [id] y la keystone (hover o
  /// elección de una tarjeta de hito).
  void _lookAtPath(String id) {
    final p = widget.profile;
    final ids = [
      ...?widget.rules.pathTo(p.classId, p.passiveProgress, id),
      id,
    ];
    Rect? box;
    for (final n in ids.map((i) => _cat.nodes[i]).nonNulls) {
      final c = PassiveTreeView.nodeCenter(n);
      box = (box ?? Rect.fromCenter(center: c, width: 0, height: 0))
          .expandToInclude(Rect.fromCenter(center: c, width: 0, height: 0));
    }
    if (box == null || _view.isEmpty) return;
    box = box.inflate(PassiveTreeView.scale * 1.5);
    final z = math.min(_view.width / box.width, _view.height / box.height);
    _look(box.center, z.clamp(0.4, 1.4));
  }

  Widget _milestoneCard(int m, String id) {
    final node = _cat.nodes[id]!;
    final chosen = _selected == id;
    final p = widget.profile;
    final steps =
        (widget.rules.pathTo(p.classId, p.passiveProgress, id)?.length ?? 1);
    final free = math.min(steps, PassiveTreeRules.milestonePoints[m]!);
    final pathText = free >= steps
        ? 'Camino: $steps ${steps == 1 ? 'nodo' : 'nodos'} gratis'
        : 'Camino: $steps nodos, $free gratis';
    return MouseRegion(
      onEnter: (_) => setState(() {
        _cardHover = id;
        _lookAtPath(id);
      }),
      onExit: (_) => setState(() {
        if (_cardHover == id) _cardHover = null;
        if (_selected case final s?) _lookAtPath(s);
      }),
      child: SizedBox(
        width: RetroType.width(context, 300),
        child: DsCard(
          key: ValueKey('milestone-pick-$id'),
          selected: chosen,
          onTap: widget.inBattle
              ? null
              : () {
                  if (!chosen) {
                    setState(() {
                      _selected = id;
                      _lookAtPath(id);
                    });
                    return;
                  }
                  widget.onChooseMilestone?.call(m, id);
                },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(retroText(node.name),
                  style: DsText.body(
                      chosen ? DsColors.selected : milestoneColor)),
              SizedBox(height: DsSpace.xs),
              // El efecto completo, sin repetir el nombre ("Nombre: …").
              for (final e in passiveEffectsText(node))
                Text(
                    retroText(e.startsWith('${node.name}: ')
                        ? e.substring(node.name.length + 2)
                        : e),
                    key: ValueKey('milestone-effect-$id'),
                    style: DsText.detail(DsColors.textPrimary)),
              SizedBox(height: DsSpace.xs),
              Text(
                  retroText(chosen
                      ? 'Clic de nuevo para confirmar'
                      : pathText),
                  style: DsText.detail(
                      chosen ? DsColors.selected : DsColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  /// "Hito del nivel N" si [id] es la keystone elegida en un hito.
  String? _milestoneOf(String id) {
    final p = widget.profile;
    if (p.milestone10 == id) return 'Hito del nivel 10';
    if (p.milestone20 == id) return 'Hito del nivel 20';
    return null;
  }

  /// Botón de ícono del sistema (tooltip obligatorio).
  Widget _iconButton(
          String key, PixelIconKind icon, String tip, VoidCallback f) =>
      DsButton.icon(
          Semantics(
              label: tip,
              child: PixelIcon(icon, size: 16, color: DsColors.textPrimary)),
          key: ValueKey(key),
          tooltip: tip,
          size: DsButtonSize.compact,
          onPressed: f);

  /// Buscador, zoom con íconos y reinicio.
  Widget _toolbar(int hitCount) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_query.trim().length >= 2) ...[
            Text(
                retroText(hitCount == 0
                    ? 'Sin coincidencias'
                    : '$hitCount coincidencia${hitCount == 1 ? '' : 's'}'),
                key: const ValueKey('tree-search-count'),
                style: DsText.detail(
                    hitCount == 0 ? DsColors.textSecondary : DsColors.mp)),
            SizedBox(width: DsSpace.sm),
          ],
          DsSearchField(
            key: const ValueKey('tree-search'),
            hint: 'Buscar nodo...',
            width: 180,
            controller: _search,
            onChanged: (v) => setState(() => _query = v),
            onSubmitted: (_) => _goToFirstHit(),
          ),
          SizedBox(width: DsSpace.sm),
          _iconButton('tree-zoom-out', PixelIconKind.minus, 'Alejar',
              () => _zoomBy(1 / 1.25)),
          SizedBox(width: DsSpace.xs),
          _iconButton(
              'tree-zoom-in', PixelIconKind.plus, 'Acercar', () => _zoomBy(1.25)),
          SizedBox(width: DsSpace.xs),
          _iconButton('tree-fit', PixelIconKind.fit, 'Ver todo', _fitAll),
          SizedBox(width: DsSpace.xs),
          _iconButton('tree-home', PixelIconKind.target, 'Mi clase', _home),
          if (widget.onUntake != null && _last != null) ...[
            SizedBox(width: DsSpace.sm),
            DsButton('DESHACER',
                key: const ValueKey('tree-undo'),
                kind: DsButtonKind.ghost,
                size: DsButtonSize.compact,
                tooltip: _undo == null ? 'Ya no se puede deshacer' : null,
                onPressed: _undo),
          ],
          if (widget.showReset) ...[
            SizedBox(width: DsSpace.sm),
            // El motivo (p. ej. "No hay nodos tomados") va en el tooltip.
            DsButton(widget.resetLabel,
                key: const ValueKey('tree-reset'),
                kind: DsButtonKind.ghost,
                size: DsButtonSize.compact,
                tooltip: widget.resetReason,
                onPressed:
                    widget.resetReason == null ? widget.onReset : null),
          ],
        ],
      );

  Widget _viewport(Size view, Map<String, TreeNodeState> states,
      String? hoverPath, Set<String> hits, List<String> route) {
    final tipId = _pinned ?? _hover;
    return TapRegion(
      onTapOutside: (_) {
        if (_pinned != null) setState(() => _pinned = null);
      },
      child: DecoratedBox(
        key: const ValueKey('tree-viewport'),
        decoration: BoxDecoration(
          color: ProtoColors.bg,
          border: Border.all(
              color: ProtoColors.panelBorder,
              width: RetroTheme.thinBorderWidth),
        ),
        child: ClipRect(
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  transformationController: _transform,
                  constrained: false,
                  minScale: PassiveTreeView.minZoom,
                  maxScale: PassiveTreeView.maxZoom,
                  boundaryMargin: const EdgeInsets.all(600),
                  child: MouseRegion(
                    onHover: (e) {
                      final id = _hit(e.localPosition);
                      if (id != _hover) setState(() => _hover = id);
                    },
                    onExit: (_) => setState(() => _hover = null),
                    child: GestureDetector(
                      key: const ValueKey('tree-canvas'),
                      onTapUp: (d) => _tap(d.localPosition),
                      onSecondaryTapUp: (d) =>
                          _secondaryTap(d.localPosition),
                      // Repinta solo si cambia el estado, el resaltado o el
                      // nivel de zoom ([PassiveTreePainter.farLevel]); el
                      // arrastre solo mueve la capa.
                      child: RepaintBoundary(
                        child: ValueListenableBuilder<Matrix4>(
                          valueListenable: _transform,
                          builder: (context, m, _) => CustomPaint(
                            size: const Size.square(PassiveTreeView.size),
                            painter: PassiveTreePainter(
                              zoom: m.storage[0],
                              devicePixelRatio:
                                  MediaQuery.devicePixelRatioOf(context),
                              catalog: _cat,
                              startId: _cat
                                  .startNodeByClass[widget.profile.classId],
                              states: states,
                              focus: _hover ?? _pinned ?? _cardHover ??
                                  _selected,
                              highlightPath: hoverPath,
                              route: route.toSet(),
                              hits: hits,
                              planned: widget.planned,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Nombres de los clusters en px de pantalla: tamaño de
              // lectura fijo (sigue al "Tamaño del texto") y ocultos con
              // poco zoom.
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _transform,
                    builder: (context, _) => CustomPaint(
                      key: const ValueKey('tree-labels'),
                      painter: TreeLabelsPainter(
                        catalog: _cat,
                        transform: _transform.value.clone(),
                        highlightPath: hoverPath,
                        textScaler: MediaQuery.textScalerOf(context),
                        devicePixelRatio:
                            MediaQuery.devicePixelRatioOf(context),
                      ),
                    ),
                  ),
                ),
              ),
              if (tipId != null)
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _transform,
                    builder: (context, _) => _tooltip(view, tipId,
                        pinned: tipId == _pinned,
                        route: tipId == focusOf() ? route : null),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String? focusOf() => _hover ?? _pinned ?? _cardHover ?? _selected;

  String _kindText(PassiveNode n) => switch (n.kind) {
        'k' => 'KEYSTONE',
        'n' => n.isMinor ? 'NOTABLE MENOR' : 'NOTABLE',
        'st' => 'INICIO DE CLASE',
        _ => '',
      };

  String? _pathText(PassivePath? path) => path == null
      ? null
      : '${switch (path.kind) {
          'puente' => 'Puente',
          'grupo' => 'Grupo',
          _ => 'Cluster',
        }} ${path.name}: ${path.theme}';

  /// Cuántos puntos cuesta llegar (y tomar) el nodo, si todavía no lo tiene.
  String? _costText(String id) {
    final p = widget.profile;
    if (widget.rules.hasNode(p.classId, p.passiveProgress, id)) return null;
    final route = widget.rules.pathTo(p.classId, p.passiveProgress, id);
    if (route == null) return null;
    final n = route.length;
    return 'Costo: $n punto${n == 1 ? '' : 's'}';
  }

  /// Si [id] toca un nodo tomado (o el inicio): TOMAR NODO tiene sentido.
  bool _connected(String id) {
    final p = widget.profile;
    final n = _cat.nodes[id];
    if (n == null) return false;
    return n.links
        .any((l) => widget.rules.hasNode(p.classId, p.passiveProgress, l));
  }

  /// Tooltip junto al nodo (del lado con más lugar, sin taparlo): nombre,
  /// tipo, cluster, efectos, costo, estado y, fijado con un clic, los
  /// botones de tomar (progression_v2.md § 11.2).
  Widget _tooltip(Size view, String id,
      {required bool pinned, List<String>? route}) {
    final node = _cat.nodes[id];
    if (node == null) return const SizedBox.shrink();
    final at = MatrixUtils.transformPoint(
        _transform.value, PassiveTreeView.nodeCenter(node));
    final r = PassiveTreeView.nodeRadius(node, start: false) * _zoom + 6;
    final w = RetroType.width(context, 300).clamp(0.0, view.width - 16);
    final st = _status(id);
    final kind = _kindText(node);
    final pathText = _pathText(_cat.paths[node.pathId]);
    final cost = _costText(id);
    final (stateText, stateColor) = _stateText(st);
    final p = widget.profile;
    final path = route ??
        widget.rules.pathTo(p.classId, p.passiveProgress, id) ??
        const <String>[];
    final keyNode = node.kind == 'n' || node.kind == 'k';
    final box = SizedBox(
      key: const ValueKey('tree-tooltip'),
      width: w,
      child: DsTooltipCard(
        key: pinned ? const ValueKey('tree-info') : null,
        title: retroText(node.name),
        titleColor: keyNode ? DsColors.textTitle : null,
        tags: [
          if (_milestoneOf(id) case final ms?)
            DsTag(ms.toUpperCase(),
                key: pinned ? const ValueKey('tree-milestone-mark') : null,
                color: milestoneColor),
          if (widget.planned.contains(id))
            const DsTag('★ EN TU BUILD', color: PassiveTreePainter.planColor),
        ],
        children: [
          if (kind.isNotEmpty || pathText != null)
            Text(
                retroText([
                  if (kind.isNotEmpty) kind,
                  if (pathText != null) pathText,
                ].join(' · ')),
                style: DsText.detail()),
          for (final line in passiveEffectsText(node))
            Text(retroText(line), style: DsText.body()),
          SizedBox(height: DsSpace.xs),
          if (cost != null)
            Text(retroText(cost), style: DsText.body(DsColors.reward)),
          Text(retroText(stateText), style: DsText.body(stateColor)),
          if (pinned) ..._actions(node, st, path),
        ],
      ),
    );
    return CustomSingleChildLayout(
      delegate: _BesideNode(at, r),
      child: pinned ? box : IgnorePointer(child: box),
    );
  }

  /// Botones del tooltip fijado: TOMAR NODO solo si conecta; si no,
  /// TOMAR CAMINO (N). El motivo de un botón apagado va en su tooltip y
  /// ya se lee en la línea de estado.
  List<Widget> _actions(
      PassiveNode node, TreeNodeStatus st, List<String> route) {
    Widget gap() => SizedBox(height: DsSpace.sm);
    if (widget.onPlan case final plan?) {
      return [
        gap(),
        DsButton(
            widget.planned.contains(node.id) ? 'QUITAR DEL PLAN' : 'PLANIFICAR',
            key: const ValueKey('tree-plan'),
            size: DsButtonSize.compact,
            accent: PassiveTreePainter.planColor,
            onPressed: () => plan(node.id)),
      ];
    }
    if (st.state == TreeNodeState.taken && widget.onUntake != null) {
      return _untakeBox(node);
    }
    if (st.state == TreeNodeState.start || st.state == TreeNodeState.taken) {
      return const [];
    }
    if (_connected(node.id)) {
      return [
        gap(),
        DsButton('TOMAR NODO',
            key: const ValueKey('tree-take'),
            kind: DsButtonKind.primary,
            size: DsButtonSize.compact,
            tooltip: _locked ? lockedText : st.reason,
            onPressed: st.reason == null && !_locked
                ? () => _take(node.id)
                : null),
      ];
    }
    if (widget.onTakePath == null || route.length < 2) return const [];
    return [
      gap(),
      DsButton('TOMAR CAMINO (${route.length})',
          key: const ValueKey('tree-take-path'),
          size: DsButtonSize.compact,
          tooltip: _locked ? lockedText : null,
          onPressed:
              widget.inBattle || _locked ? null : () => _askPath(node.id)),
    ];
  }

  /// Confirmación de QUITAR junto al nodo tomado (progression_v2.md
  /// § 6.1): qué devuelve, o el motivo si no se puede.
  List<Widget> _untakeBox(PassiveNode node) {
    final p = widget.profile;
    final reason = widget.inBattle
        ? 'No en batalla'
        : widget.untakeReason?.call(node.id);
    final ms = p.milestone10 == node.id
        ? 10
        : p.milestone20 == node.id
            ? 20
            : null;
    final what = ms == null
        ? 'Te devuelve 1 punto'
        : 'Deja pendiente el hito del nivel $ms';
    return [
      SizedBox(height: DsSpace.sm),
      Text(
          retroText(reason ?? '¿Quitar ${node.name}? $what'),
          key: const ValueKey('tree-untake-text'),
          style: DsText.body(
              reason == null ? DsColors.textPrimary : RetroPalette.red)),
      SizedBox(height: DsSpace.xs),
      Row(mainAxisSize: MainAxisSize.min, children: [
        if (reason == null) ...[
          DsButton('QUITAR',
              key: const ValueKey('tree-untake'),
              kind: DsButtonKind.primary,
              size: DsButtonSize.compact,
              onPressed: () => _untake(node.id)),
          SizedBox(width: DsSpace.sm),
        ],
        DsButton('Cancelar',
            key: const ValueKey('tree-untake-cancel'),
            size: DsButtonSize.compact,
            onPressed: () => setState(() => _pinned = null)),
      ]),
    ];
  }

  (String, Color) _stateText(TreeNodeStatus st) => switch (st.state) {
        TreeNodeState.start => ('Nodo inicial', RetroPalette.muted),
        TreeNodeState.taken => ('Tomado', RetroPalette.green),
        TreeNodeState.available => (
            'Disponible: clic para tomar',
            ProtoColors.sky
          ),
        TreeNodeState.locked => (st.reason ?? 'Bloqueado', RetroPalette.red),
      };

  /// Leyenda en una sola fila, abajo del árbol (Detalle, marca de color).
  Widget _legend() {
    Widget dot(Color c, {bool ring = false}) => Container(
        width: 8,
        height: 8,
        decoration: ring
            ? BoxDecoration(border: Border.all(color: c, width: 2))
            : BoxDecoration(color: c));
    final items = <(String, Widget)>[
      ('Inicio', dot(RetroPalette.gold)),
      ('Tomado', dot(RetroPalette.green)),
      ('Keystone', dot(PassiveTreePainter.keyTaken)),
      ('Disponible', dot(ProtoColors.sky)),
      ('Bloqueado', dot(PassiveTreePainter.locked)),
      ('Búsqueda', dot(PassiveTreePainter.searchColor, ring: true)),
      if (widget.planned.isNotEmpty || widget.planning)
        ('Plan', dot(PassiveTreePainter.planColor, ring: true)),
    ];
    return FittedBox(
      key: const ValueKey('tree-legend'),
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: DsSpace.md),
        child: Row(
          children: [
            for (final (i, (label, mark)) in items.indexed) ...[
              if (i > 0) SizedBox(width: DsSpace.md),
              mark,
              SizedBox(width: DsSpace.xs),
              Text(retroText(label), style: DsText.detail()),
            ],
          ],
        ),
      ),
    );
  }
}

/// Pone el tooltip al costado del nodo (a la derecha si entra, si no a la
/// izquierda), centrado en alto y dentro del visor.
class _BesideNode extends SingleChildLayoutDelegate {
  _BesideNode(this.at, this.gap);
  final Offset at;
  final double gap;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints c) => c.loosen();

  @override
  Offset getPositionForChild(Size size, Size child) {
    final right = at.dx + gap;
    final left = at.dx - gap - child.width;
    final x = right + child.width <= size.width - 4 || left < 4
        ? math.min(right, size.width - child.width - 4)
        : left;
    final y = (at.dy - child.height / 2)
        .clamp(4.0, math.max(4.0, size.height - child.height - 4))
        .toDouble();
    return Offset(math.max(4.0, x), y);
  }

  @override
  bool shouldRelayout(_BesideNode old) => old.at != at || old.gap != gap;
}

/// Dibuja el anillo, los enlaces, los nodos (círculo, notable con borde
/// dorado, keystone hexagonal), el camino hasta el nodo enfocado, los
/// resultados de la búsqueda. Los nombres de los clusters van aparte, en
/// px de pantalla ([TreeLabelsPainter]).
class PassiveTreePainter extends CustomPainter {
  PassiveTreePainter({
    required this.catalog,
    required this.startId,
    required this.states,
    this.focus,
    this.highlightPath,
    this.route = const {},
    this.hits = const {},
    this.planned = const {},
    this.zoom = 1,
    this.devicePixelRatio = 1,
  });

  /// Zoom del visor y px físicos por px lógico: con zoom alejado
  /// ([farZoom]) la capa fija se dibuja como UNA imagen ya rasterizada a
  /// esa escala ([farLevel]) en vez de reproducir ~600 nodos y ~800
  /// enlaces vectoriales en cada cuadro (passive_tree_v6.md § 9).
  final double zoom;
  final double devicePixelRatio;

  /// Apagado solo en el benchmark, para comparar con el dibujo vectorial.
  @visibleForTesting
  static bool farCache = true;

  /// Por debajo de este zoom la capa fija va como imagen.
  static const farZoom = 0.75;

  /// Por debajo de este zoom (nivel de detalle) los nodos del cluster
  /// bajo el mouse no llevan el anillo dorado fino de 1 px (mediría
  /// menos de medio px de pantalla); sus enlaces dorados, el camino, el
  /// foco, la búsqueda y el plan se dibujan igual.
  static const detailZoom = 0.4;

  /// Escala (px de la imagen por px del lienzo) de la capa fija con este
  /// zoom, o `null` si va vectorial. Se redondea hacia arriba en pasos de
  /// 2^(1/4) (~19 %) para no regrabar con cada tick de la rueda, y nunca
  /// pasa de 2048 px de lado.
  double? get farLevel {
    if (!farCache || zoom >= farZoom) return null;
    final want = zoom * devicePixelRatio;
    final step = (math.log(want) / math.ln2 * 4).ceil() / 4;
    final l = math.pow(2, step).toDouble();
    return math.min(l, 2048 / PassiveTreeView.size);
  }

  bool get _fine => zoom >= detailZoom;
  final PassiveTreeCatalog catalog;
  final String? startId;
  final Map<String, TreeNodeState> states;
  final String? focus;

  /// Cluster resaltado (el del nodo bajo el mouse).
  final String? highlightPath;

  /// Nodos que faltan para llegar al nodo enfocado.
  final Set<String> route;

  /// Nodos que coinciden con la búsqueda.
  final Set<String> hits;

  /// Nodos del plan de build (anillo violeta).
  final Set<String> planned;

  static const locked = Color(0xFF3A4570);
  static const keyTaken = Color(0xFFFF6B6B);
  static const searchColor = Color(0xFF81ECEC);
  static const planColor = Color(0xFFC39BFF);

  bool _has(String id) {
    final s = states[id];
    return s == TreeNodeState.start || s == TreeNodeState.taken;
  }

  bool _inPath(PassiveNode n) =>
      highlightPath != null && n.pathId == highlightPath;

  bool _onRoute(String id) =>
      route.contains(id) || (id == focus && route.isNotEmpty);

  /// Capa fija (anillo, enlaces y nodos con su estado y el plan),
  /// grabada una vez y reutilizada mientras no cambien los estados, el
  /// plan ni la clase: mover el mouse o buscar solo redibuja la capa de
  /// resaltado (árbol v6, ~600 nodos; passive_tree_v6.md § 9).
  static ui.Picture? _base;
  static (
    PassiveTreeCatalog,
    String?,
    Map<String, TreeNodeState>,
    Set<String>
  )? _baseKey;

  /// Cuántas veces se grabó la capa fija (tests de rendimiento).
  @visibleForTesting
  static int baseBuilds = 0;

  /// Capa fija rasterizada para el zoom alejado ([farLevel]).
  static ui.Image? _far;
  static double? _farLevel;
  static ui.Picture? _farOf;

  /// Cuántas veces se rasterizó la capa fija (tests de rendimiento).
  @visibleForTesting
  static int farBuilds = 0;

  bool _baseValid() {
    final k = _baseKey;
    return _base != null &&
        k != null &&
        identical(k.$1, catalog) &&
        k.$2 == startId &&
        (identical(k.$3, states) || _sameStates(k.$3, states)) &&
        _sameSet(k.$4, planned);
  }

  void _paintBase(Canvas canvas) {
    const center = Offset(PassiveTreeView.size / 2, PassiveTreeView.size / 2);
    // Anillo central compartido.
    final ringR = math.sqrt(math.pow(catalog.nodes['p_gue']?.x ?? 0, 2) +
        math.pow(catalog.nodes['p_gue']?.y ?? 2, 2));
    canvas.drawCircle(
        center,
        ringR * PassiveTreeView.scale,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..color = ProtoColors.panelBorder.withValues(alpha: 0.35));

    final idle = Paint()
      ..strokeWidth = 2
      ..color = ProtoColors.panelBorder;
    final owned = Paint()
      ..strokeWidth = 2
      ..color = ProtoColors.green;
    for (final n in catalog.nodes.values) {
      for (final l in n.links) {
        if (n.id.compareTo(l) >= 0) continue;
        final b = catalog.nodes[l];
        if (b == null) continue;
        _drawEdge(canvas, n.id, l, _has(n.id) && _has(l) ? owned : idle);
      }
    }
    catalog.extraStrokes.forEach((key, segs) {
      final paint = key.split('|').every(_has) ? owned : idle;
      for (final (a, b) in segs) {
        canvas.drawLine(PassiveTreeView.toCanvas(a.$1, a.$2),
            PassiveTreeView.toCanvas(b.$1, b.$2), paint);
      }
    });
    for (final n in catalog.nodes.values) {
      _drawNode(canvas, n);
    }
  }

  /// Arista como polilínea por su recorrido (`edgeRoutes`): sigue los
  /// tallos y arcos del árbol original en vez de cortar en diagonal.
  void _drawEdge(Canvas canvas, String a, String b, Paint paint) {
    final pts = catalog.edgePoints(a, b);
    if (pts.length == 2) {
      canvas.drawLine(PassiveTreeView.toCanvas(pts[0].$1, pts[0].$2),
          PassiveTreeView.toCanvas(pts[1].$1, pts[1].$2), paint);
      return;
    }
    final path = Path();
    for (var i = 0; i < pts.length; i++) {
      final o = PassiveTreeView.toCanvas(pts[i].$1, pts[i].$2);
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = paint.color
          ..strokeWidth = paint.strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round);
  }

  void _drawNode(Canvas canvas, PassiveNode n) {
    final c = PassiveTreeView.nodeCenter(n);
    final r = PassiveTreeView.nodeRadius(n, start: n.id == startId);
    final state = states[n.id] ?? TreeNodeState.locked;
    final fill = switch (state) {
      TreeNodeState.start => ProtoColors.gold,
      TreeNodeState.taken => n.kind == 'k' ? keyTaken : ProtoColors.green,
      TreeNodeState.available => ProtoColors.sky,
      TreeNodeState.locked => locked,
    };
    final big = n.kind == 'n' || n.kind == 'k';
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = big ? 2.5 : 1.5
      ..color = big ? ProtoColors.gold : ProtoColors.bg;
    if (n.kind == 'k') {
      final hex = _hexagon(c, r);
      canvas.drawPath(hex, Paint()..color = fill);
      canvas.drawPath(hex, border);
    } else {
      canvas.drawCircle(c, r, Paint()..color = fill);
      canvas.drawCircle(c, r, border);
    }
    if (planned.contains(n.id)) {
      canvas.drawCircle(
          c,
          r + 5,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = planColor);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (!_baseValid()) {
      final rec = ui.PictureRecorder();
      _paintBase(Canvas(rec));
      _base?.dispose();
      _base = rec.endRecording();
      _baseKey = (catalog, startId, states, Set.of(planned));
      baseBuilds++;
    }
    final level = farLevel;
    if (level == null) {
      canvas.drawPicture(_base!);
    } else {
      if (_far == null || _farLevel != level || !identical(_farOf, _base)) {
        final rec = ui.PictureRecorder();
        Canvas(rec)
          ..scale(level)
          ..drawPicture(_base!);
        final pic = rec.endRecording();
        final side = (PassiveTreeView.size * level).ceil();
        _far?.dispose();
        _far = pic.toImageSync(side, side);
        pic.dispose();
        _farLevel = level;
        _farOf = _base;
        farBuilds++;
      }
      final img = _far!;
      canvas.drawImageRect(
          img,
          Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
          Rect.fromLTWH(0, 0, img.width / level, img.height / level),
          Paint()..filterQuality = FilterQuality.low);
    }

    // Resaltado: enlaces del camino y del cluster bajo el mouse (encima
    // de la capa fija), y se vuelven a dibujar sus nodos.
    final hot = <String>{
      ...route,
      if (focus != null) focus!,
      if (highlightPath != null)
        for (final n in catalog.nodes.values)
          if (n.pathId == highlightPath) n.id,
    };
    final link = Paint();
    final redraw = <String>{};
    final seen = <String>{};
    for (final id in hot) {
      final n = catalog.nodes[id];
      if (n == null) continue;
      for (final l in n.links) {
        final key = n.id.compareTo(l) < 0 ? '${n.id}|$l' : '$l|${n.id}';
        if (!seen.add(key)) continue;
        final b = catalog.nodes[l];
        if (b == null) continue;
        if (_has(n.id) && _has(l)) continue;
        final routeLink = (_onRoute(n.id) || _has(n.id)) &&
            (_onRoute(l) || _has(l)) &&
            (_onRoute(n.id) || _onRoute(l));
        final lit = _inPath(n) && _inPath(b);
        if (!routeLink && !lit) continue;
        link
          ..color = routeLink
              ? ProtoColors.gold
              : ProtoColors.gold.withValues(alpha: 0.5)
          ..strokeWidth = routeLink ? 4 : 3;
        _drawEdge(canvas, n.id, l, link);
        redraw
          ..add(n.id)
          ..add(l);
      }
    }
    for (final id in redraw) {
      _drawNode(canvas, catalog.nodes[id]!);
    }

    for (final id in {...hits, ...hot}) {
      final n = catalog.nodes[id];
      if (n == null) continue;
      final c = PassiveTreeView.nodeCenter(n);
      final r = PassiveTreeView.nodeRadius(n, start: n.id == startId);
      if (hits.contains(n.id)) {
        canvas.drawCircle(
            c,
            r + 6,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5
              ..color = searchColor);
        // Planificado y encontrado: el anillo del plan va por fuera.
        if (planned.contains(n.id)) {
          canvas.drawCircle(
              c,
              r + 9,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2.5
                ..color = planColor);
        }
      }
      if (_onRoute(n.id) || n.id == focus || (_inPath(n) && _fine)) {
        canvas.drawCircle(
          c,
          r + 3,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = n.id == focus || _onRoute(n.id) ? 2 : 1
            ..color = ProtoColors.gold,
        );
      }
    }
  }

  static Path _hexagon(Offset c, double r) {
    final p = Path();
    for (var i = 0; i < 6; i++) {
      final a = math.pi / 6 + i * math.pi / 3;
      final v = c + Offset(math.cos(a), math.sin(a)) * r;
      if (i == 0) {
        p.moveTo(v.dx, v.dy);
      } else {
        p.lineTo(v.dx, v.dy);
      }
    }
    return p..close();
  }

  @override
  bool shouldRepaint(PassiveTreePainter old) =>
      old.focus != focus ||
      old.startId != startId ||
      old.farLevel != farLevel ||
      old._fine != _fine ||
      old.highlightPath != highlightPath ||
      !_sameSet(old.route, route) ||
      !_sameSet(old.hits, hits) ||
      !_sameSet(old.planned, planned) ||
      !_sameStates(old.states, states);

  static bool _sameSet(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);

  static bool _sameStates(
      Map<String, TreeNodeState> a, Map<String, TreeNodeState> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }
}

/// Nombres de clusters, puentes y grupos del árbol, dibujados en px de
/// pantalla sobre el visor (docs/specs/accessibility.md § 3): siempre en
/// el tamaño de lectura (VT323, [RetroType.small] con el
/// [textScaler] de la app, nítido), en un px entero, y ocultos cuando el
/// zoom es menor que [minZoom] (ahí no se leerían ni entrarían). Si dos
/// nombres se pisan, queda el primero (el resaltado va primero).
class TreeLabelsPainter extends CustomPainter {
  TreeLabelsPainter({
    required this.catalog,
    required this.transform,
    required this.textScaler,
    this.highlightPath,
    this.devicePixelRatio = 1,
  });

  final PassiveTreeCatalog catalog;
  final Matrix4 transform;
  final TextScaler textScaler;
  final String? highlightPath;
  final double devicePixelRatio;

  /// Zoom mínimo con nombres.
  static const minZoom = 0.55;

  static final _cache = <(String, bool, TextScaler), TextPainter>{};

  double get zoom => transform.storage[0];

  /// Si con este zoom se dibujan los nombres (tests).
  bool get visible => zoom >= minZoom;

  @override
  void paint(Canvas canvas, Size size) {
    if (!visible) return;
    final drawn = <Rect>[];
    final paths = catalog.paths.values.toList()
      ..sort((a, b) => (b.id == highlightPath ? 1 : 0)
          .compareTo(a.id == highlightPath ? 1 : 0));
    for (final path in paths) {
      final lit = path.id == highlightPath;
      final tp = _cache.putIfAbsent(
          (path.name, lit, textScaler),
          () => TextPainter(
                text: TextSpan(
                  text: retroText(path.name.toUpperCase()),
                  style: RetroType.smallStyle.copyWith(
                    color: lit
                        ? ProtoColors.gold
                        : path.kind == 'clase'
                            ? ProtoColors.dim
                            : ProtoColors.sky,
                    shadows: const [
                      Shadow(color: ProtoColors.shadow, offset: Offset(1, 1)),
                    ],
                  ),
                ),
                textScaler: textScaler,
                textDirection: TextDirection.ltr,
              )..layout());
      final at = MatrixUtils.transformPoint(
          transform, PassiveTreeView.toCanvas(path.labelX, path.labelY));
      double px(double v) =>
          (v * devicePixelRatio).roundToDouble() / devicePixelRatio;
      final o = Offset(px(at.dx - tp.width / 2), px(at.dy - tp.height / 2));
      final r = o & tp.size;
      if (!r.overlaps(Offset.zero & size)) continue;
      if (drawn.any((d) => d.overlaps(r))) continue;
      drawn.add(r);
      tp.paint(canvas, o);
    }
  }

  @override
  bool shouldRepaint(TreeLabelsPainter old) =>
      old.transform != transform ||
      old.highlightPath != highlightPath ||
      old.textScaler != textScaler ||
      old.devicePixelRatio != devicePixelRatio;
}
