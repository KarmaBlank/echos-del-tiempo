import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/retro_theme.dart';
import '../../../../game_engine/models/game_map.dart';
import '../../../../game_engine/models/game_session.dart';

/// `drawMinimap` del prototipo como widget (docs/specs/exploration.md §
/// "HUD"). Colores = arte del prototipo, igual que el mapa.
class Minimap extends StatelessWidget {
  const Minimap({
    super.key,
    required this.map,
    required this.session,
    required this.localId,
    required this.localX,
    required this.localY,
    required this.time,
  });

  /// Píxeles de pantalla por tile (el prototipo usa 1.25 px virtuales,
  /// ×2 para la pantalla).
  static const cell = 2.5;

  /// Factor de los puntos respecto del prototipo.
  static const dotScale = cell / 1.25;

  final GameMap map;
  final GameSession session;
  final String localId;
  final double localX, localY;

  /// Reloj de la sesión en segundos (parpadeo del jefe).
  final double time;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: map.width * cell,
      height: map.height * cell,
      child: CustomPaint(
        painter: _MinimapPainter(this),
      ),
    );
  }
}

/// La base del minimapa (tiles) se graba una vez por mapa.
final _baseCache = Expando<ui.Picture>('minimapa');

class _MinimapPainter extends CustomPainter {
  _MinimapPainter(this.w);

  final Minimap w;

  static const _ts = 16.0;

  ui.Picture _base(GameMap map) {
    final cached = _baseCache[map];
    if (cached != null) return cached;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final p = Paint()..isAntiAlias = false;
    for (var y = 0; y < map.height; y++) {
      for (var x = 0; x < map.width; x++) {
        p.color = switch (map.tileAt(x, y)) {
          Tile.wall || Tile.gate => const Color(0xFF0B0E1A),
          Tile.water => const Color(0xFF2E86DE),
          Tile.merchant => const Color(0xFFFFD166),
          Tile.path => const Color(0xFF6C7A9C),
          _ => const Color(0xFF4B5878),
        };
        c.drawRect(
            Rect.fromLTWH(x * Minimap.cell, y * Minimap.cell, Minimap.cell,
                Minimap.cell),
            p);
      }
    }
    return _baseCache[map] = rec.endRecording();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final map = w.map;
    final s = w.session;
    canvas.saveLayer(Offset.zero & size,
        Paint()..color = const Color.fromRGBO(0, 0, 0, 0.85));
    canvas.drawPicture(_base(map));
    canvas.restore();

    final p = Paint()..isAntiAlias = false;
    const cell = Minimap.cell;
    for (var y = 0; y < map.height; y++) {
      for (var x = 0; x < map.width; x++) {
        if (map.tileAt(x, y) != Tile.gate) continue;
        p.color =
            s.gateOpen ? const Color(0xFF7BED9F) : const Color(0xFFFF4757);
        canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, cell, cell), p);
      }
    }
    void dot(double px, double py, Color c, double s2) {
      final d = s2 * Minimap.dotScale;
      p.color = c;
      canvas.drawRect(
          Rect.fromLTWH(px / _ts * cell - d / 2, py / _ts * cell - d / 2, d, d),
          p);
    }

    final m = s.mission;
    if (m != null) {
      for (final e in m.enemies) {
        if (e.alive && !e.boss) {
          dot(e.x, e.y,
              e.elite ? const Color(0xFFFFD166) : const Color(0xFFFF4757),
              e.elite ? 3 : 2);
        }
      }
      for (final it in m.items) {
        switch (it.kind) {
          case MissionItemKind.fragment when !it.done:
            dot(it.x, it.y, const Color(0xFF48DBFB), 3);
          case MissionItemKind.seal:
            dot(it.x, it.y,
                it.done ? const Color(0xFF7BED9F) : const Color(0xFFA29BFE), 3);
          case MissionItemKind.chest when !it.done:
            dot(it.x, it.y, const Color(0xFFFFD166), 3);
          default:
            break;
        }
      }
      for (final e in m.enemies) {
        if (!e.boss || !e.alive) continue;
        final blink = (w.time * 1000 / 300).floor() % 2 == 1;
        final tp = TextPainter(
          text: TextSpan(
            text: '*',
            style: TextStyle(
              fontFamily: RetroTheme.fontFamily,
              fontSize: 8,
              height: 1,
              color: blink ? const Color(0xFFE84393) : const Color(0xFFFFD166),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
            canvas,
            Offset(e.x / _ts * cell - tp.width / 2,
                e.y / _ts * cell - tp.height / 2));
      }
    }
    final merchant = map.merchant;
    if (merchant != null) {
      dot(merchant.x, merchant.y - 10, const Color(0xFFFFD166), 3);
    }
    for (final pl in s.playerList) {
      final mine = pl.id == w.localId;
      dot(mine ? w.localX : pl.x, mine ? w.localY : pl.y,
          mine ? const Color(0xFFFFFFFF) : const Color(0xFF48DBFB), 3);
    }
  }

  @override
  bool shouldRepaint(_MinimapPainter old) => true;
}
