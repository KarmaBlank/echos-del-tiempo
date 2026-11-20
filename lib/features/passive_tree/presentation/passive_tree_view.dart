import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../app/theme/ui_theme.dart';
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
  });

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
  String? _selected;
  Size? _fittedFor;
  Size _view = Size.zero;
  String _query = '';

  /// Texto de búsqueda de cada nodo (se arma una vez por catálogo).
  static final _searchIndex = Expando<Map<String, String>>();

  @override
  void dispose() {
    _transform.dispose();
    _search.dispose();
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
    if (id == null) return;
    setState(() => _selected = id);
    if (widget.onPlan case final plan?) {
      plan(id);
    } else if (_status(id).canTake) {
      widget.onTake(id);
    } else {
      _askPath(id);
    }
  }

  /// Camino en un clic (progression_v2.md § 4): un notable o keystone que
  /// todavía no conecta → confirmar "Tomar N nodos por N puntos".
  Future<void> _askPath(String id) async {
    final take = widget.onTakePath;
    final node = _cat.nodes[id];
    if (take == null || node == null || widget.inBattle) return;
    if (node.kind != 'n' && node.kind != 'k') return;
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
      _selected = n.id;
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
        : rules.milestoneOptions(p.classId, pending.first);
    final hits = {..._hits(), ...options};
    final focusId = _hover ?? _selected;
    final route = focusId == null
        ? const <String>[]
        : rules.pathTo(p.classId, p.passiveProgress, focusId) ?? const [];
    final hoverPath = focusId == null ? null : _cat.nodes[focusId]?.pathId;
    final fill = widget.height == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (widget.showHelp) ...[
          const Text(
              'Arrastrá para mover, rueda o +/− para zoom. Clic: tomar nodo.',
              style: TextStyle(color: ProtoColors.dim)),
          const SizedBox(height: 8),
        ],
        // Puntos, reinicio, buscador y zoom en una sola fila (si entra):
        // más alto para el visor (árbol v6).
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text.rich(TextSpan(
                style: const TextStyle(color: ProtoColors.sky),
                children: [
                  TextSpan(text: retroText('Puntos de árbol disponibles: ')),
                  TextSpan(
                      text: '$points',
                      style: const TextStyle(color: ProtoColors.gold)),
                ])),
            if (widget.showReset)
              PanelButton(widget.resetLabel,
                  key: const ValueKey('tree-reset'),
                  reason: widget.resetReason,
                  onPressed: widget.onReset),
            _toolbar(hits.length),
          ],
        ),
        const SizedBox(height: 8),
        if (pending.isNotEmpty) ...[
          _milestoneBanner(pending.first, options),
          const SizedBox(height: 8),
        ],
        _grow(
            fill,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SizedBox(
                    height: widget.height,
                    child: LayoutBuilder(builder: (context, box) {
                      _fit(box.biggest);
                      return _viewport(
                          box.biggest, states, hoverPath, hits, route.toSet());
                    }),
                  ),
                ),
                const SizedBox(width: 16),
                // Mismo alto que el visor; si no entra, se desplaza.
                SizedBox(
                  width: 352,
                  height: widget.height,
                  child: SingleChildScrollView(child: _info(focusId, route)),
                ),
              ],
            )),
      ],
    );
  }

  static Widget _grow(bool fill, Widget child) =>
      fill ? Expanded(child: child) : child;

  /// Color de los hitos (los puntos de hito se ven aparte de los libres).
  static const milestoneColor = ProtoColors.orange;

  /// Hito del nivel 10 / 20 (progression_v2.md § 5): qué gana, las
  /// keystones de entrada para elegir (marcadas en el árbol; al pasar o
  /// tocar se ve el camino) y sus puntos aparte.
  Widget _milestoneBanner(int m, List<String> options) {
    final pts = PassiveTreeRules.milestonePoints[m]!;
    final p = widget.profile;
    return Container(
      key: ValueKey('milestone-banner-$m'),
      padding: EdgeInsets.all(UiTheme.space(8)),
      decoration: BoxDecoration(
        border: Border.all(color: milestoneColor, width: 2),
        color: ProtoColors.bg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              retroText('Hito del nivel $m: elegí una keystone de entrada; '
                  'te damos los puntos de su camino.'),
              style: const TextStyle(color: ProtoColors.title)),
          Text(retroText('Puntos de hito: $pts, solo para esta ruta.'),
              key: const ValueKey('milestone-points'),
              style: const TextStyle(color: milestoneColor)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final id in options)
                MouseRegion(
                  onEnter: (_) => setState(() => _selected = id),
                  child: PanelButton(
                    'ELEGIR ${_cat.nodes[id]!.name} '
                    '(${widget.rules.pathTo(p.classId, p.passiveProgress, id)?.length ?? 0} nodos)',
                    key: ValueKey('milestone-pick-$id'),
                    accent: milestoneColor,
                    selected: _selected == id,
                    onPressed: widget.inBattle
                        ? null
                        : () {
                            if (_selected != id) {
                              setState(() => _selected = id);
                              return;
                            }
                            widget.onChooseMilestone?.call(m, id);
                          },
                  ),
                ),
            ],
          ),
          if (options.contains(_selected))
            Text(
                retroText('Clic otra vez para confirmar: se toma el camino '
                    'resaltado.'),
                style: const TextStyle(color: ProtoColors.dim)),
        ],
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

  /// Buscador y botones de zoom.
  Widget _toolbar(int hitCount) => Wrap(
        spacing: 4,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: RetroType.width(context, 220),
            child: TextField(
              key: const ValueKey('tree-search'),
              controller: _search,
              style: RetroType.smallStyle,
              decoration: const InputDecoration(
                  hintText: 'Buscar nodo...',
                  contentPadding: EdgeInsets.all(8),
                  isDense: true),
              onChanged: (v) => setState(() => _query = v),
              onSubmitted: (_) => _goToFirstHit(),
            ),
          ),
          const SizedBox(width: 8),
          if (_query.trim().length >= 2)
            Text(
                retroText(hitCount == 0
                    ? 'Sin coincidencias'
                    : '$hitCount coincidencia${hitCount == 1 ? '' : 's'}'),
                key: const ValueKey('tree-search-count'),
                style: TextStyle(
                    color: hitCount == 0 ? ProtoColors.dim : ProtoColors.sky)),
          const SizedBox(width: 8),
          PanelButton('−',
              key: const ValueKey('tree-zoom-out'),
              onPressed: () => _zoomBy(1 / 1.25)),
          const SizedBox(width: 4),
          PanelButton('+',
              key: const ValueKey('tree-zoom-in'),
              onPressed: () => _zoomBy(1.25)),
          const SizedBox(width: 4),
          PanelButton('TODO',
              key: const ValueKey('tree-fit'), onPressed: _fitAll),
          const SizedBox(width: 4),
          PanelButton('MI CLASE',
              key: const ValueKey('tree-home'), onPressed: _home),
        ],
      );

  Widget _viewport(Size view, Map<String, TreeNodeState> states,
      String? hoverPath, Set<String> hits, Set<String> route) {
    return DecoratedBox(
      key: const ValueKey('tree-viewport'),
      decoration: BoxDecoration(
        color: ProtoColors.bg,
        border: Border.all(
            color: ProtoColors.panelBorder, width: RetroTheme.thinBorderWidth),
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
                            startId:
                                _cat.startNodeByClass[widget.profile.classId],
                            states: states,
                            focus: _hover ?? _selected,
                            highlightPath: hoverPath,
                            route: route,
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
            // Nombres de los clusters en px de pantalla: tamaño de lectura
            // fijo (sigue al "Tamaño del texto") y ocultos con poco zoom.
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
                      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
                    ),
                  ),
                ),
              ),
            ),
            if (_hover != null)
              AnimatedBuilder(
                animation: _transform,
                builder: (context, _) => _tooltip(view, _hover!),
              ),
          ],
        ),
      ),
    );
  }

  String _kindText(PassiveNode n) => switch (n.kind) {
        'k' => 'KEYSTONE',
        'n' => 'NOTABLE',
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

  /// Tooltip en la esquina del visor opuesta al nodo: nombre, tipo,
  /// cluster, efectos completos, costo y estado.
  Widget _tooltip(Size view, String id) {
    final node = _cat.nodes[id];
    if (node == null) return const SizedBox.shrink();
    final at = MatrixUtils.transformPoint(
        _transform.value, PassiveTreeView.nodeCenter(node));
    final w = RetroType.width(context, 300).clamp(0.0, view.width - 16);
    final left = at.dx > view.width / 2 ? 8.0 : view.width - w - 8;
    final onTop = at.dy > view.height / 2;
    final st = _status(id);
    final kind = _kindText(node);
    final pathText = _pathText(_cat.paths[node.pathId]);
    final cost = _costText(id);
    final (stateText, stateColor) = _stateText(st);
    return Positioned(
      left: math.max(4.0, left),
      top: onTop ? 8 : null,
      bottom: onTop ? null : 8,
      width: w,
      child: IgnorePointer(
        child: Container(
          key: const ValueKey('tree-tooltip'),
          padding: EdgeInsets.all(UiTheme.space(8)),
          decoration: BoxDecoration(
            color: ProtoColors.bg.withValues(alpha: 0.96),
            border: Border.all(
                color: node.kind == 'n' || node.kind == 'k'
                    ? ProtoColors.gold
                    : ProtoColors.buttonBorder,
                width: 2),
          ),
          child: DefaultTextStyle.merge(
            style: RetroType.smallStyle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Nombre (rol `title`), tipo · cluster (`muted`),
                // efectos (`body`), costo (`accent`) y estado (accessibility.md
                // § 8.2).
                Text(retroText(node.name),
                    style: const TextStyle(color: ProtoColors.title)),
                if (kind.isNotEmpty || pathText != null)
                  Text(
                      retroText([
                        if (kind.isNotEmpty) kind,
                        if (pathText != null) pathText,
                      ].join(' · ')),
                      style: const TextStyle(color: ProtoColors.dim)),
                SizedBox(height: UiTheme.space(4)),
                for (final line in passiveEffectsText(node))
                  Text(retroText(line)),
                SizedBox(height: UiTheme.space(4)),
                if (cost != null)
                  Text(retroText(cost),
                      style: const TextStyle(color: ProtoColors.gold)),
                if (_milestoneOf(id) case final ms?)
                  Text(retroText(ms),
                      style: const TextStyle(color: milestoneColor)),
                if (widget.planned.contains(id))
                  Text(retroText('★ En tu build'),
                      style:
                          const TextStyle(color: PassiveTreePainter.planColor)),
                Text(retroText(stateText), style: TextStyle(color: stateColor)),
              ],
            ),
          ),
        ),
      ),
    );
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

  Widget _legend() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (label, color) in const [
            ('Inicio de tu clase', RetroPalette.gold),
            ('Tomado', RetroPalette.green),
            ('Keystone tomada', PassiveTreePainter.keyTaken),
            ('Disponible: clic para tomar', ProtoColors.sky),
            ('Bloqueado', PassiveTreePainter.locked),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                Container(width: 8, height: 8, color: color),
                const SizedBox(width: 8),
                Flexible(child: Text(retroText(label))),
              ]),
            ),
          if (widget.planned.isNotEmpty || widget.planning)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        border: Border.all(
                            color: PassiveTreePainter.planColor, width: 2))),
                const SizedBox(width: 8),
                Flexible(child: Text(retroText('En tu plan de build'))),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [
              Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                      border: Border.all(
                          color: PassiveTreePainter.searchColor, width: 2))),
              const SizedBox(width: 8),
              Flexible(child: Text(retroText('Coincide con la búsqueda'))),
            ]),
          ),
          const SizedBox(height: 4),
          const Text(
              'Borde dorado: notable. Hexágono: keystone (fuerte, con '
              'contra). Línea dorada: camino que falta hasta el nodo.',
              style: TextStyle(color: ProtoColors.dim)),
        ],
      );

  Widget _info(String? id, List<String> route) {
    final node = id == null ? null : _cat.nodes[id];
    if (node == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
              'Pasa el mouse o toca un nodo para ver qué da y cuánto cuesta. '
              'Cada cluster se bifurca en 2 notables y termina en una '
              'keystone; el anillo del centro, los puentes y los clusters '
              'de grupo conectan con las otras clases.',
              style: TextStyle(color: RetroPalette.muted)),
          const SizedBox(height: 16),
          _legend(),
        ],
      );
    }
    final st = _status(node.id);
    final (stateText, stateColor) = _stateText(st);
    final path = _cat.paths[node.pathId];
    final cost = _costText(node.id);
    return Column(
      key: const ValueKey('tree-info'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(retroText(node.name),
            style: const TextStyle(color: ProtoColors.title)),
        if (node.kind == 'k' || node.kind == 'n')
          Text(_kindText(node),
              style: const TextStyle(color: RetroPalette.muted)),
        if (path != null)
          Text(retroText(_pathText(path)!.split(':').first),
              style: const TextStyle(color: RetroPalette.muted)),
        const SizedBox(height: 8),
        for (final line in passiveEffectsText(node))
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(retroText(line)),
          ),
        const SizedBox(height: 8),
        if (_milestoneOf(node.id) case final ms?)
          Text(retroText(ms),
              key: const ValueKey('tree-milestone-mark'),
              style: const TextStyle(color: milestoneColor)),
        if (cost != null)
          Text(retroText(cost),
              style: const TextStyle(color: ProtoColors.gold)),
        // Bloqueado: el motivo ya va junto al botón de tomar.
        if (st.state != TreeNodeState.locked)
          Text(retroText(stateText), style: TextStyle(color: stateColor)),
        if (widget.planned.contains(node.id))
          Text(retroText('★ En tu build'),
              style: const TextStyle(color: PassiveTreePainter.planColor)),
        if (widget.onPlan case final plan?) ...[
          const SizedBox(height: 8),
          PanelButton(
              widget.planned.contains(node.id)
                  ? 'QUITAR DEL PLAN'
                  : 'PLANIFICAR',
              key: const ValueKey('tree-plan'),
              accent: PassiveTreePainter.planColor,
              onPressed: () => plan(node.id)),
        ] else if (st.state != TreeNodeState.start &&
            st.state != TreeNodeState.taken) ...[
          const SizedBox(height: 8),
          // El motivo largo no desborda el panel: se achica si hace falta.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: PanelButton('TOMAR NODO',
                key: const ValueKey('tree-take'),
                reason: st.reason,
                onPressed: () => widget.onTake(node.id)),
          ),
          if (widget.onTakePath != null &&
              route.length > 1 &&
              (node.kind == 'n' || node.kind == 'k')) ...[
            const SizedBox(height: 6),
            PanelButton('TOMAR CAMINO (${route.length})',
                key: const ValueKey('tree-take-path'),
                onPressed: widget.inBattle ? null : () => _askPath(node.id)),
          ],
        ],
        const SizedBox(height: 16),
        _legend(),
      ],
    );
  }
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
