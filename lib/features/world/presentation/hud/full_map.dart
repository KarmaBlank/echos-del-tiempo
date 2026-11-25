import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../app/theme/map_palette.dart';
import '../../../../app/theme/panel_frame.dart';
import '../../../../app/theme/proto_colors.dart';
import '../../../../app/theme/retro_text.dart';
import '../../../../app/theme/retro_theme.dart';
import '../../../../game_engine/models/fog_of_war.dart';
import '../../../../game_engine/models/game_map.dart';
import '../../../../game_engine/models/game_session.dart';
import '../../../../game_engine/rules/map_discovery_rules.dart'
    show OverworldMarkKind;
import 'map_hover_tip.dart';
import 'minimap.dart';
import '../world_strings.dart';

/// Mapa del piso en grande (tecla M, v0.8.1; docs/specs/exploration.md §
/// "HUD" → "Mapa en grande"): el mismo dibujo que el minimapa, ajustado
/// al panel, con zoom (rueda, `+` `−`) y paneo (arrastrar, flechas) y la
/// leyenda de íconos. Esc o M lo cierran.
class FullMap extends StatefulWidget {
  const FullMap({
    super.key,
    required this.title,
    required this.map,
    required this.session,
    required this.localId,
    required this.localX,
    required this.localY,
    required this.time,
    required this.onClose,
    this.loot = const [],
    this.bounds,
    this.entranceOpen,
    this.waystones = const [],
    this.destinations = const [],
    this.originId,
    this.onTravel,
    this.reduceMotion = false,
    this.fog,
    this.pick,
    this.overworld,
  });

  /// Overworld biome layer (biome_exploration.md § 11): discovery, goal
  /// marks and its own legend. `null` = dungeon / world map.
  final OverworldOverlay? overworld;

  /// Which legend this map shows.
  FullMapMode get mode =>
      overworld == null ? FullMapMode.dungeon : FullMapMode.overworld;

  /// Pick mode (biome_regions.md § 4, worldgen.md § 11.4): every stone of
  /// [waystones] is selectable (hover = tooltip, click = select), the
  /// chosen one is described on the right with its own TRAVEL button and
  /// the undiscovered ones are grey. `null` = click travels right away.
  final FullMapPick? pick;

  /// Niebla de mazmorra oscura (lighting.md § 5.4).
  final FogOfWar? fog;

  /// Piedras de paso descubiertas del piso (en orden; activada o no):
  /// se marcan con [waystoneColor] y parpadean (worldgen.md § 11.4).
  final List<(MapPoi, bool)> waystones;

  /// Modo "elegir destino": las piedras a las que se puede viajar desde
  /// [originId] (vacío = mapa normal).
  final List<MapPoi> destinations;
  final int? originId;
  final ValueChanged<int>? onTravel;

  /// Sin parpadeo (opción de accesibilidad "reducir movimiento").
  final bool reduceMotion;

  /// Color vivo de las piedras de paso en el mapa grande.
  static const waystoneColor = Color(0xFF00F0FF);

  /// Período del parpadeo.
  static const blinkPeriod = Duration(milliseconds: 700);

  bool get choosing =>
      (destinations.isNotEmpty || pick != null) && onTravel != null;

  /// `Pradera Esmeralda · Piso 1/2` (o `Mapa del mundo`).
  final String title;
  final GameMap map;
  final GameSession session;
  final String localId;
  final double localX, localY;
  final double time;
  final VoidCallback onClose;
  final List<MinimapLoot> loot;
  final TileRect? bounds;
  final bool Function(int zone)? entranceOpen;

  /// Zoom máximo sobre "el piso entero entra".
  static const maxZoom = 6.0;

  /// Paso del zoom (rueda, `+` `−`).
  static const zoomStep = 1.5;

  /// Tiles por flecha.
  static const panStep = 4.0;

  /// Íconos de la leyenda (las marcas del minimapa del tema activo); el
  /// texto es una clave de `ui.world`.
  static const legendMarks = <(String, MapMark)>[
    ('ui.world.map.legend.me', MapMark.me),
    ('ui.world.map.legend.ally', MapMark.ally),
    ('ui.world.map.legend.stairs', MapMark.stairs),
    ('ui.world.map.legend.boss', MapMark.boss),
    ('ui.world.map.legend.chest', MapMark.chest),
    ('ui.world.map.legend.secret', MapMark.secret),
    ('ui.world.map.legend.shrine', MapMark.shrine),
    ('ui.world.map.legend.waystone', MapMark.waystone),
    ('ui.world.map.legend.enemy', MapMark.enemy),
  ];

  /// La leyenda con los colores del tema activo.
  static List<(String, Color)> get legend => [
        for (final (l, m) in legendMarks)
          (l, m == MapMark.waystone ? waystoneColor : MapPalette.mark(m)),
      ];

  /// Overworld legend (biome_exploration.md § 11.1) in groups: title key
  /// → (label key, mark, is a goal). Only what the overworld draws.
  static const overworldLegendMarks =
      <(String, List<(String, MapMark, bool)>)>[
    (
      'ui.world.map.legend.group_goals',
      [
        ('ui.world.map.legend.portal', MapMark.goal, true),
        ('ui.world.map.legend.echo', MapMark.echo, true),
      ]
    ),
    (
      'ui.world.map.legend.group_optional',
      [
        ('ui.world.map.legend.waystone', MapMark.waystone, false),
        ('ui.world.map.legend.shrine', MapMark.shrine, false),
        ('ui.world.map.legend.chest', MapMark.chest, false),
        ('ui.world.map.legend.mine', MapMark.mine, false),
        ('ui.world.map.legend.dock', MapMark.dock, false),
        ('ui.world.map.legend.resident', MapMark.resident, false),
      ]
    ),
    (
      'ui.world.map.legend.group_party',
      [
        ('ui.world.map.legend.me', MapMark.me, false),
        ('ui.world.map.legend.ally', MapMark.ally, false),
      ]
    ),
  ];

  /// The overworld legend trimmed to what [ow] actually draws: goals
  /// always, optional kinds only once one is discovered, allies only with
  /// company. Empty groups are dropped.
  static List<(String, List<(String, MapMark, bool)>)> overworldLegendFor(
      OverworldOverlay ow,
      {bool allies = true}) {
    bool drawn(MapMark m) {
      if (m == MapMark.me) return true;
      if (m == MapMark.ally) return allies;
      return ow.marks.any((k) =>
          _markOf(k.kind) == m && (k.goal || ow.knownTile(k.x, k.y)));
    }

    return [
      for (final (g, items) in overworldLegendMarks)
        if (items.where((i) => drawn(i.$2)).toList() case final keep
            when keep.isNotEmpty)
          (g, keep),
    ];
  }

  static MapMark _markOf(OverworldMarkKind k) => switch (k) {
        OverworldMarkKind.portal => MapMark.goal,
        OverworldMarkKind.echo => MapMark.echo,
        OverworldMarkKind.waystone => MapMark.waystone,
        OverworldMarkKind.shrine => MapMark.shrine,
        OverworldMarkKind.chest => MapMark.chest,
        OverworldMarkKind.mine => MapMark.mine,
        OverworldMarkKind.dock => MapMark.dock,
        OverworldMarkKind.resident => MapMark.resident,
      };

  /// Every label key of the legend of [mode].
  static List<String> legendKeys(FullMapMode mode) => switch (mode) {
        FullMapMode.dungeon => [for (final (l, _) in legendMarks) l],
        FullMapMode.overworld => [
            for (final (_, items) in overworldLegendMarks)
              for (final (l, _, _) in items) l
          ],
      };

  @override
  State<FullMap> createState() => FullMapState();
}

class FullMapState extends State<FullMap> with SingleTickerProviderStateMixin {
  double _zoom = 1;

  late final AnimationController _blink =
      AnimationController(vsync: this, duration: FullMap.blinkPeriod);

  /// Destino resaltado con Tab (Enter viaja).
  int _sel = 0;

  /// Pick mode: the selected stone (id) and the hovered one + cursor.
  int? _picked;
  int? _hoverId;
  Offset _cursor = Offset.zero;

  FullMapPick? get _pick => widget.pick;

  /// Pick mode: the selected stone.
  MapPoi? get _pickedPoi {
    final all = widget.waystones;
    if (all.isEmpty) return null;
    final id = _picked ?? _pick?.initial;
    return all.where((w) => w.$1.id == id).firstOrNull?.$1 ?? all.first.$1;
  }

  void _select(MapPoi p) => setState(() => _picked = p.id);

  @override
  void initState() {
    super.initState();
    _syncBlink();
  }

  @override
  void didUpdateWidget(FullMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncBlink();
    if (_sel >= widget.destinations.length) _sel = 0;
  }

  void _syncBlink() {
    final on = !widget.reduceMotion && widget.waystones.isNotEmpty;
    if (on) {
      if (!_blink.isAnimating) _blink.repeat(reverse: true);
    } else {
      _blink.stop();
      _blink.value = 1;
    }
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  /// Número de la piedra (1..n en el orden del piso).
  int _number(MapPoi p) =>
      widget.waystones.indexWhere((w) => w.$1.id == p.id) + 1;

  void _travel(MapPoi p) => widget.onTravel?.call(p.id);
  Offset? _center;

  /// Lo último dibujado: para recortar el paneo a los bordes.
  Size _view = Size.zero;
  double _cell = 1;

  /// Zoom actual (1 = el piso entero entra en el panel).
  double get zoom => _zoom;

  TileRect get _area =>
      widget.bounds ?? TileRect(0, 0, widget.map.width, widget.map.height);

  Offset get _player => Offset(widget.localX / 16, widget.localY / 16);

  void _setZoom(double z) =>
      setState(() => _zoom = z.clamp(1.0, FullMap.maxZoom));

  void _zoomIn() => _setZoom(_zoom * FullMap.zoomStep);
  void _zoomOut() => _setZoom(_zoom / FullMap.zoomStep);

  /// Mueve el centro [d] tiles, sin salirse del piso.
  void _pan(Offset d) {
    final c = (_center ?? _player) + d;
    final r = Minimap.viewRect(_area, _view, c);
    setState(() => _center = r.center);
  }

  void _recenter() => setState(() => _center = null);

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final k = e.logicalKey;
    const s = FullMap.panStep;
    final pan = switch (k) {
      LogicalKeyboardKey.arrowLeft ||
      LogicalKeyboardKey.keyA =>
        const Offset(-s, 0),
      LogicalKeyboardKey.arrowRight ||
      LogicalKeyboardKey.keyD =>
        const Offset(s, 0),
      LogicalKeyboardKey.arrowUp ||
      LogicalKeyboardKey.keyW =>
        const Offset(0, -s),
      LogicalKeyboardKey.arrowDown ||
      LogicalKeyboardKey.keyS =>
        const Offset(0, s),
      _ => null,
    };
    if (pan != null) {
      _pan(pan);
      return KeyEventResult.handled;
    }
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    if (k == LogicalKeyboardKey.equal ||
        k == LogicalKeyboardKey.add ||
        k == LogicalKeyboardKey.numpadAdd) {
      _zoomIn();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.minus ||
        k == LogicalKeyboardKey.numpadSubtract) {
      _zoomOut();
      return KeyEventResult.handled;
    }
    if (_pick != null) {
      final all = widget.waystones;
      if (k == LogicalKeyboardKey.tab && all.isNotEmpty) {
        final i = all.indexWhere((w) => w.$1.id == _pickedPoi?.id);
        _select(all[(i + 1) % all.length].$1);
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.enter ||
          k == LogicalKeyboardKey.numpadEnter) {
        final p = _pickedPoi;
        if (p != null && widget.destinations.any((d) => d.id == p.id)) {
          _travel(p);
        }
        return KeyEventResult.handled;
      }
      final digit = _digit(k);
      if (digit != null && digit <= all.length) {
        _select(all[digit - 1].$1);
        return KeyEventResult.handled;
      }
    } else if (widget.choosing) {
      final d = widget.destinations;
      if (k == LogicalKeyboardKey.tab) {
        setState(() => _sel = (_sel + 1) % d.length);
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.enter ||
          k == LogicalKeyboardKey.numpadEnter) {
        _travel(d[_sel.clamp(0, d.length - 1)]);
        return KeyEventResult.handled;
      }
      final digit = _digit(k);
      if (digit != null) {
        final hit = d.where((p) => _number(p) == digit).firstOrNull;
        if (hit != null) _travel(hit);
        return KeyEventResult.handled;
      }
    }
    if (k == LogicalKeyboardKey.keyM) {
      widget.onClose();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.keyC) {
      _recenter();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  static int? _digit(LogicalKeyboardKey k) {
    const rows = [
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
    const pad = [
      LogicalKeyboardKey.numpad1,
      LogicalKeyboardKey.numpad2,
      LogicalKeyboardKey.numpad3,
      LogicalKeyboardKey.numpad4,
      LogicalKeyboardKey.numpad5,
      LogicalKeyboardKey.numpad6,
      LogicalKeyboardKey.numpad7,
      LogicalKeyboardKey.numpad8,
      LogicalKeyboardKey.numpad9,
    ];
    final i = rows.indexOf(k);
    if (i >= 0) return i + 1;
    final j = pad.indexOf(k);
    return j >= 0 ? j + 1 : null;
  }

  /// Las marcas de piedras de paso sobre la ventana [v] del mapa.
  List<Widget> _stoneMarks(BuildContext context, Rect v) {
    final size = math.max(22.0, _cell * 1.6);
    final out = <Widget>[];
    for (final (poi, on) in widget.waystones) {
      final x = (poi.center.x / 16 - v.left) * _cell;
      final y = (poi.center.y / 16 - v.top) * _cell;
      if (x < 0 || y < 0 || x > v.width * _cell || y > v.height * _cell) {
        continue;
      }
      final picking = _pick != null;
      final dest = picking ||
          (widget.choosing && widget.destinations.any((d) => d.id == poi.id));
      final origin = poi.id == widget.originId;
      final selected = picking
          ? _pickedPoi?.id == poi.id
          : dest && widget.destinations[_sel].id == poi.id;
      final hi = selected || origin;
      final color = on
          ? FullMap.waystoneColor
          : picking
              ? DsColors.textDisabled
              : FullMap.waystoneColor.withValues(alpha: 0.45);
      Widget mark = FadeTransition(
        opacity: Tween(begin: 0.25, end: 1.0).animate(_blink),
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(
                color: hi ? ProtoColors.ink : ProtoColors.panelBorder,
                width: hi ? 2 : 1),
          ),
          child: Text(retroText(_number(poi).toString()),
              style: const TextStyle(color: Color(0xFF001014))),
        ),
      );
      if (dest) {
        mark = Semantics(
          button: true,
          label: context.t('ui.world.map.travel_to_stone', {'n': _number(poi)}),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: picking ? (_) => setState(() => _hoverId = poi.id) : null,
            onExit: picking
                ? (_) => setState(() {
                      if (_hoverId == poi.id) _hoverId = null;
                    })
                : null,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => picking ? _select(poi) : _travel(poi),
              child: mark,
            ),
          ),
        );
      }
      out.add(Positioned(
          key: ValueKey('full-map-stone-${poi.id}'),
          left: x - size / 2,
          top: y - size / 2,
          child: mark));
    }
    return out;
  }

  /// Pick mode: the hovered stone's name next to the cursor.
  List<Widget> _hoverTip() {
    final pick = _pick;
    final id = _hoverId;
    if (pick == null || id == null) return const [];
    final p = widget.waystones.where((w) => w.$1.id == id).firstOrNull;
    if (p == null) return const [];
    return [
      Positioned.fill(
        key: const ValueKey('full-map-stone-tip'),
        child: IgnorePointer(
          child: MapHoverTip(
            cursor: _cursor,
            bottomReserve: 0,
            child: DsTooltipCard(title: pick.label(p.$1), children: const []),
          ),
        ),
      ),
    ];
  }

  /// Pick mode: the map with the chosen stone's detail on the right.
  Widget _withDetail(Widget map) {
    final pick = _pick;
    final p = _pickedPoi;
    if (pick == null || p == null) return map;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: map),
        SizedBox(width: DsSpace.md),
        SizedBox(
            width: FullMapPick.detailWidth,
            child: KeyedSubtree(
                key: const ValueKey('full-map-detail'),
                child: pick.detail(p))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final choosing = widget.choosing;
    return PanelFrame(
      title: retroText(context.t('ui.world.map.title', {'name': widget.title})),
      width: 1100,
      fill: true,
      onClose: widget.onClose,
      leading: [
        PanelButton('-',
            key: const ValueKey('full-map-out'), onPressed: _zoomOut),
        PanelButton('+',
            key: const ValueKey('full-map-in'), onPressed: _zoomIn),
        PanelButton(context.t('ui.world.map.center'),
            key: const ValueKey('full-map-center'), onPressed: _recenter),
      ],
      actions: [
        if (choosing && _pick == null)
          for (final d in widget.destinations)
            PanelButton(context.t('ui.world.map.travel_button', {'n': _number(d)}),
                key: ValueKey('full-map-travel-${d.id}'),
                selected: widget.destinations[_sel].id == d.id,
                onPressed: () => _travel(d)),
        PanelButton(context.t('ui.world.map.close'),
            key: const ValueKey('full-map-close'), onPressed: widget.onClose),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _withDetail(Focus(
              autofocus: true,
              onKeyEvent: _onKey,
              child: LayoutBuilder(builder: (context, box) {
                final a = _area;
                final fit = math.min(box.maxWidth / a.w, box.maxHeight / a.h);
                _cell = fit * _zoom;
                _view = Size(box.maxWidth / _cell, box.maxHeight / _cell);
                return Center(
                  child: Listener(
                    onPointerSignal: (s) {
                      if (s is PointerScrollEvent) {
                        s.scrollDelta.dy < 0 ? _zoomIn() : _zoomOut();
                      }
                    },
                    child: GestureDetector(
                      onPanUpdate: (d) => _pan(-d.delta / _cell),
                      child: MouseRegion(
                       onHover: _pick == null
                          ? null
                          : (e) => setState(() => _cursor = e.localPosition),
                       child: Stack(clipBehavior: Clip.hardEdge, children: [
                        Minimap(
                          key: const ValueKey('full-map'),
                          map: widget.map,
                          session: widget.session,
                          localId: widget.localId,
                          localX: widget.localX,
                          localY: widget.localY,
                          time: widget.time,
                          loot: widget.loot,
                          bounds: widget.bounds,
                          entranceOpen: widget.entranceOpen,
                          cell: _cell,
                          view: _view,
                          center: _center ?? _player,
                          fog: widget.fog,
                          overworld: widget.overworld,
                        ),
                        ..._stoneMarks(context,
                            Minimap.viewRect(a, _view, _center ?? _player)),
                        ..._hoverTip(),
                      ]),
                      ),
                    ),
                  ),
                );
              }),
            )),
          ),
          const SizedBox(height: 8),
          Wrap(
            key: const ValueKey('full-map-legend'),
            spacing: 24,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (widget.mode == FullMapMode.dungeon)
                for (final (label, color) in FullMap.legend)
                  _LegendItem(label: context.t(label), color: color)
              else
                for (final (group, items) in FullMap.overworldLegendFor(
                    widget.overworld!,
                    allies: widget.session.players.length > 1))
                  Wrap(
                    key: ValueKey('full-map-legend-$group'),
                    spacing: 12,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(retroText(context.t(group)),
                          style: DsText.subtitle(group.endsWith('goals')
                              ? DsColors.reward
                              : DsColors.textSecondary)),
                      for (final (label, mark, goal) in items)
                        _LegendItem(
                            label: context.t(label),
                            color: mark == MapMark.waystone
                                ? FullMap.waystoneColor
                                : MapPalette.mark(mark),
                            goal: goal),
                    ],
                  ),
              if (choosing && _pick == null)
                Text(
                    key: const ValueKey('full-map-choose-hint'),
                    retroText(context.t('ui.world.map.choose_hint')),
                    style: DsText.subtitle(FullMap.waystoneColor)),
              Text(retroText(context.t('ui.world.map.controls')),
                  style: DsText.subtitle(ProtoColors.dim)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Pick mode of [FullMap]: how to name a stone (hover tooltip) and the
/// detail pane of the selected one (with its own TRAVEL button).
class FullMapPick {
  const FullMapPick({required this.label, required this.detail, this.initial});

  /// Width of the detail pane on the right.
  static const detailWidth = 300.0;

  final String Function(MapPoi stone) label;
  final Widget Function(MapPoi stone) detail;

  /// Stone selected when it opens (id), e.g. the one you stand at.
  final int? initial;
}

/// Which legend / behaviour the big map uses (biome_exploration.md § 11).
enum FullMapMode { dungeon, overworld }

/// One legend entry: swatch + label. Goals get the gold frame they wear
/// on the map (§ 11.2).
class _LegendItem extends StatelessWidget {
  const _LegendItem(
      {required this.label, required this.color, this.goal = false});

  final String label;
  final Color color;
  final bool goal;

  @override
  Widget build(BuildContext context) {
    final box = RetroType.width(context, 12);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: box,
            height: box,
            decoration: BoxDecoration(
                color: color,
                border: Border.all(
                    color: goal
                        ? MapPalette.mark(MapMark.goal)
                        : ProtoColors.panelBorder,
                    width: goal ? 2 : 1))),
        const SizedBox(width: 6),
        Text(retroText(label), style: DsText.subtitle(DsColors.text)),
      ],
    );
  }
}
