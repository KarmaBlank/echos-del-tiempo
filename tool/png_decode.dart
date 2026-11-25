// Minimal PNG reader (8-bit RGBA / RGB, non-interlaced) for the export
// tools and pixel tests. Pure dart:io.
import 'dart:io';
import 'dart:typed_data';

/// (width, height, RGBA pixels) of the PNG [bytes].
(int, int, Uint8List) decodePng(List<int> bytes) {
  final b = ByteData.sublistView(Uint8List.fromList(bytes));
  var o = 8, w = 0, h = 0, type = 6;
  final idat = BytesBuilder();
  while (o < b.lengthInBytes) {
    final len = b.getUint32(o);
    final tag = String.fromCharCodes(bytes.sublist(o + 4, o + 8));
    final data = o + 8;
    if (tag == 'IHDR') {
      w = b.getUint32(data);
      h = b.getUint32(data + 4);
      if (bytes[data + 8] != 8) throw const FormatException('bit depth');
      type = bytes[data + 9];
    } else if (tag == 'IDAT') {
      idat.add(bytes.sublist(data, data + len));
    } else if (tag == 'IEND') {
      break;
    }
    o = data + len + 4;
  }
  final bpp = switch (type) { 6 => 4, 2 => 3, _ => throw const FormatException('color type') };
  final raw = zlib.decode(idat.toBytes());
  final stride = w * bpp;
  final cur = Uint8List(stride), prev = Uint8List(stride);
  final out = Uint8List(w * h * 4);
  var p = 0;
  for (var y = 0; y < h; y++) {
    final f = raw[p++];
    for (var x = 0; x < stride; x++) {
      final a = x >= bpp ? cur[x - bpp] : 0;
      final up = prev[x];
      final c = x >= bpp ? prev[x - bpp] : 0;
      final v = raw[p++];
      int pred;
      switch (f) {
        case 0:
          pred = 0;
        case 1:
          pred = a;
        case 2:
          pred = up;
        case 3:
          pred = (a + up) >> 1;
        default:
          final pa = (up - c).abs(), pb = (a - c).abs(), pc = (a + up - 2 * c).abs();
          pred = pa <= pb && pa <= pc ? a : (pb <= pc ? up : c);
      }
      cur[x] = (v + pred) & 0xff;
    }
    for (var x = 0; x < w; x++) {
      final q = (y * w + x) * 4;
      out[q] = cur[x * bpp];
      out[q + 1] = cur[x * bpp + 1];
      out[q + 2] = cur[x * bpp + 2];
      out[q + 3] = bpp == 4 ? cur[x * bpp + 3] : 0xff;
    }
    prev.setAll(0, cur);
  }
  return (w, h, out);
}
