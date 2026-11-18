import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/panel_frame.dart';
import '../../../../app/theme/proto_colors.dart';
import '../../../../app/theme/retro_text.dart';
import '../../../../app/theme/retro_theme.dart';
import '../../../../game_engine/models/game_map.dart';
import '../../../../game_engine/models/game_session.dart';
import 'minimap.dart';

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
  });

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

  /// Íconos de la leyenda (colores = arte del minimapa).
  static const legend = <(String, Color)>[
    ('Tú', Color(0xFFFFFFFF)),
    ('Aliados', Color(0xFF48DBFB)),
    ('Escalera', Color(0xFFFFD166)),
    ('Jefe', Color(0xFFE84393)),
    ('Cofre', Color(0xFFFFD166)),
    ('Secreto', Color(0xFFBE6EFF)),
    ('Santuario', Color(0xFF5AE6D2)),
    ('Piedra de paso', Color(0xFFB0B6C8)),
    ('Enemigos', Color(0xFFFF4757)),
  ];

  @override
  State<FullMap> createState() => FullMapState();
}

class FullMapState extends State<FullMap> {
  double _zoom = 1;
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

  @override
  Widget build(BuildContext context) {
    return PanelFrame(
      title: retroText('MAPA · ${widget.title}'),
      width: 1100,
      fill: true,
      onClose: widget.onClose,
      leading: [
        PanelButton('-',
            key: const ValueKey('full-map-out'), onPressed: _zoomOut),
        PanelButton('+',
            key: const ValueKey('full-map-in'), onPressed: _zoomIn),
        PanelButton('CENTRAR [C]',
            key: const ValueKey('full-map-center'), onPressed: _recenter),
      ],
      actions: [
        PanelButton('CERRAR [M]',
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
                      child: Minimap(
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
                      ),
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
                        color: color),
                    const SizedBox(width: 6),
                    Text(retroText(label)),
                  ],
                ),
              Text(retroText('Rueda / + -: zoom · Arrastrar / flechas: mover'),
                  style: const TextStyle(color: ProtoColors.dim)),
            ],
          ),
        ],
      ),
    );
  }
}
