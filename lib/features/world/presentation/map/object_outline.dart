import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

/// The 1 px white outline of an object painted into its tiles (portals,
/// waystones, shrines, the fountain, mine mouths, signs, stations,
/// chests; controls.md § Cursor de acción). The object has no sprite, so
/// its silhouette is the set of pixels where the tiles drawn with it
/// differ from the same tiles drawn with plain ground; the outline is the
/// ring of pixels right outside that silhouette. Built once per key
/// (asynchronously: the first frames go without it) and drawn under the
/// actors, so it never covers the player.
class ObjectOutlineCache {
  final _rings = <String, ui.Image?>{};

  /// The build in progress (tests wait on it before a capture).
  Future<void>? pending;

  /// The ring for [key] over [region] (px of the world), or `null` while
  /// it is being built. [withObject] / [ground] paint the region in world
  /// px with and without the object.
  ui.Image? ring(String key, Rect region, void Function(Canvas) withObject,
      void Function(Canvas) ground) {
    if (_rings.containsKey(key)) return _rings[key];
    if (_rings.length > 48) clear();
    _rings[key] = null;
    final w = region.width.round(), h = region.height.round();
    ui.Image shot(void Function(Canvas) paint) {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec, Offset.zero & Size(w.toDouble(), h.toDouble()));
      c.translate(-region.left, -region.top);
      paint(c);
      final pic = rec.endRecording();
      final im = pic.toImageSync(w, h);
      pic.dispose();
      return im;
    }

    final a = shot(withObject), b = shot(ground);
    pending = _build(key, a, b, w, h);
    return null;
  }

  Future<void> _build(String key, ui.Image a, ui.Image b, int w, int h) async {
    final pa = await a.toByteData(format: ui.ImageByteFormat.rawRgba);
    final pb = await b.toByteData(format: ui.ImageByteFormat.rawRgba);
    a.dispose();
    b.dispose();
    if (pa == null || pb == null || !_rings.containsKey(key)) return;
    final obj = Uint8List(w * h);
    for (var i = 0; i < w * h; i++) {
      final o = i * 4;
      if (pa.getUint32(o) != pb.getUint32(o) && pa.getUint8(o + 3) > 0) {
        obj[i] = 1;
      }
    }
    final out = Uint8List(w * h * 4);
    var any = false;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = y * w + x;
        if (obj[i] == 1) continue;
        final edge = (x > 0 && obj[i - 1] == 1) ||
            (x < w - 1 && obj[i + 1] == 1) ||
            (y > 0 && obj[i - w] == 1) ||
            (y < h - 1 && obj[i + w] == 1);
        if (!edge) continue;
        any = true;
        out.fillRange(i * 4, i * 4 + 4, 255);
      }
    }
    if (!any) return;
    final done = Completer<ui.Image>();
    ui.decodeImageFromPixels(out, w, h, ui.PixelFormat.rgba8888, done.complete);
    final img = await done.future;
    if (_rings.containsKey(key)) {
      _rings[key] = img;
    } else {
      img.dispose();
    }
  }

  /// Draws the ring of [key] at [region], if it is ready.
  void draw(Canvas c, String key, Rect region) {
    final im = _rings[key];
    if (im != null) c.drawImage(im, region.topLeft, Paint());
  }

  void clear() {
    for (final im in _rings.values) {
      im?.dispose();
    }
    _rings.clear();
  }
}
