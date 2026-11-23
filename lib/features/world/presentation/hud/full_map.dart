import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/map_palette.dart';
import '../../../../app/theme/panel_frame.dart';
import '../../../../app/theme/proto_colors.dart';
import '../../../../app/theme/retro_text.dart';
import '../../../../app/theme/retro_theme.dart';
import '../../../../game_engine/models/fog_of_war.dart';
import '../../../../game_engine/models/game_map.dart';
import '../../../../game_engine/models/game_session.dart';
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
  });

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

  bool get choosing => destinations.isNotEmpty && onTravel != null;

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

  @override
  State<FullMap> createState() => FullMapState();
}

class FullMapState extends State<FullMap> with SingleTickerProviderStateMixin {
  double _zoom = 1;

  late final AnimationController _blink =
      AnimationController(vsync: this, duration: FullMap.blinkPeriod);

  /// Destino resaltado con Tab (Enter viaja).
  int _sel = 0;

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
    if (widget.choosing) {
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
      final dest =
          widget.choosing && widget.destinations.any((d) => d.id == poi.id);
      final origin = poi.id == widget.originId;
      final selected = dest && widget.destinations[_sel].id == poi.id;
      final hi = selected || origin;
      Widget mark = FadeTransition(
        opacity: Tween(begin: 0.25, end: 1.0).animate(_blink),
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on
                ? FullMap.waystoneColor
                : FullMap.waystoneColor.withValues(alpha: 0.45),
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
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _travel(poi),
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
        if (choosing)
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
            child: Focus(
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
                        ),
                        ..._stoneMarks(context,
                            Minimap.viewRect(a, _view, _center ?? _player)),
                      ]),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            key: const ValueKey('full-map-legend'),
            spacing: 16,
            runSpacing: 4,
            children: [
              for (final (label, color) in FullMap.legend)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                        width: RetroType.width(context, 8),
                        height: RetroType.width(context, 8),
                        decoration: BoxDecoration(
                            color: color,
                            border: Border.all(
                                color: ProtoColors.panelBorder, width: 1))),
                    const SizedBox(width: 6),
                    Text(retroText(context.t(label))),
                  ],
                ),
              if (choosing)
                Text(
                    key: const ValueKey('full-map-choose-hint'),
                    retroText(context.t('ui.world.map.choose_hint')),
                    style: const TextStyle(color: FullMap.waystoneColor)),
              Text(retroText(context.t('ui.world.map.controls')),
                  style: const TextStyle(color: ProtoColors.dim)),
            ],
          ),
        ],
      ),
    );
  }
}
