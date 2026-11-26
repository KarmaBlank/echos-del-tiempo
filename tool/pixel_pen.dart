// Small pixel-art pen shared by the procedural sprite exporters
// (tool/export_house_sprites.dart, tool/export_shop_interior_sprites.dart).
import 'dart:io';

import 'export_sprites.dart' show RgbaImage, encodePng;

const kOutline = 0x1a1420;

class Pen {
  Pen(int w, int h) : img = RgbaImage(w, h);
  final RgbaImage img;
  int get w => img.width;
  int get h => img.height;

  /// Paints one pixel; [a] < 255 blends over what is there.
  void px(int x, int y, int rgb, [int a = 0xff]) {
    if (x < 0 || y < 0 || x >= w || y >= h) return;
    final o = (y * w + x) * 4;
    final p = img.pixels;
    if (a >= 0xff || p[o + 3] == 0) {
      p
        ..[o] = (rgb >> 16) & 0xff
        ..[o + 1] = (rgb >> 8) & 0xff
        ..[o + 2] = rgb & 0xff
        ..[o + 3] = a;
      return;
    }
    final f = a / 255;
    p[o] = (((rgb >> 16) & 0xff) * f + p[o] * (1 - f)).round();
    p[o + 1] = (((rgb >> 8) & 0xff) * f + p[o + 1] * (1 - f)).round();
    p[o + 2] = ((rgb & 0xff) * f + p[o + 2] * (1 - f)).round();
  }

  bool on(int x, int y) =>
      x >= 0 && y >= 0 && x < w && y < h && img.pixels[(y * w + x) * 4 + 3] != 0;

  void rect(int x, int y, int rw, int rh, int rgb, [int a = 0xff]) {
    for (var j = y; j < y + rh; j++) {
      for (var i = x; i < x + rw; i++) {
        px(i, j, rgb, a);
      }
    }
  }

  /// Rectangle with its four corner pixels cut (a softer silhouette).
  void round(int x, int y, int rw, int rh, int rgb, [int a = 0xff]) {
    rect(x + 1, y, rw - 2, rh, rgb, a);
    rect(x, y + 1, 1, rh - 2, rgb, a);
    rect(x + rw - 1, y + 1, 1, rh - 2, rgb, a);
  }

  void line(int x0, int y0, int x1, int y1, int rgb, [int a = 0xff]) {
    final n =
        [(x1 - x0).abs(), (y1 - y0).abs(), 1].reduce((a, b) => a > b ? a : b);
    for (var k = 0; k <= n; k++) {
      px((x0 + (x1 - x0) * k / n).round(), (y0 + (y1 - y0) * k / n).round(),
          rgb, a);
    }
  }

  /// Filled ellipse in the box (x, y, rw, rh).
  void oval(int x, int y, int rw, int rh, int rgb, [int a = 0xff]) {
    final cx = x + rw / 2, cy = y + rh / 2;
    for (var j = y; j < y + rh; j++) {
      for (var i = x; i < x + rw; i++) {
        final dx = (i + 0.5 - cx) / (rw / 2), dy = (j + 0.5 - cy) / (rh / 2);
        if (dx * dx + dy * dy <= 1.0) px(i, j, rgb, a);
      }
    }
  }

  /// Dark outline around everything painted so far.
  void outline([int rgb = kOutline]) {
    final add = <(int, int)>[];
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (on(x, y)) continue;
        if (on(x - 1, y) || on(x + 1, y) || on(x, y - 1) || on(x, y + 1)) {
          add.add((x, y));
        }
      }
    }
    for (final (x, y) in add) {
      px(x, y, rgb);
    }
  }

  /// Copies [s] at (ox, oy), alpha-blended.
  void blit(RgbaImage s, int ox, int oy) {
    for (var y = 0; y < s.height; y++) {
      for (var x = 0; x < s.width; x++) {
        final so = (y * s.width + x) * 4;
        final a = s.pixels[so + 3];
        if (a == 0) continue;
        px(ox + x, oy + y,
            (s.pixels[so] << 16) | (s.pixels[so + 1] << 8) | s.pixels[so + 2],
            a);
      }
    }
  }
}

void writePng(String path, RgbaImage img) => File(path)
  ..createSync(recursive: true)
  ..writeAsBytesSync(encodePng(img));
