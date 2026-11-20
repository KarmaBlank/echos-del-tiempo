import 'dart:typed_data';

/// Cabecera de un PNG (IHDR + si declara transparencia). Dart puro.
class PngInfo {
  const PngInfo(this.width, this.height, this.colorType, this.hasAlpha);
  final int width;
  final int height;

  /// Tipo de color del IHDR (6 = RGBA, 4 = gris+alfa, 3 = paleta, …).
  final int colorType;

  /// Canal alfa (tipo 4/6) o chunk `tRNS`.
  final bool hasAlpha;

  static const _sig = [137, 80, 78, 71, 13, 10, 26, 10];

  /// `null` si no es un PNG.
  static PngInfo? parse(Uint8List b) {
    if (b.length < 33) return null;
    for (var i = 0; i < 8; i++) {
      if (b[i] != _sig[i]) return null;
    }
    final d = ByteData.sublistView(b);
    if (String.fromCharCodes(b.sublist(12, 16)) != 'IHDR') return null;
    final w = d.getUint32(16);
    final h = d.getUint32(20);
    final colorType = b[25];
    var trns = false;
    var off = 8;
    while (off + 8 <= b.length) {
      final len = d.getUint32(off);
      final type = String.fromCharCodes(b.sublist(off + 4, off + 8));
      if (type == 'tRNS') trns = true;
      if (type == 'IDAT' || type == 'IEND') break;
      off += 12 + len;
    }
    return PngInfo(w, h, colorType, colorType == 4 || colorType == 6 || trns);
  }
}

/// Píxeles RGBA decodificados (los decodifica quien tenga `dart:ui`; el
/// validador no depende de Flutter).
class RgbaPixels {
  const RgbaPixels(this.width, this.height, this.rgba);
  final int width;
  final int height;
  final Uint8List rgba;
}

/// Resultado de validar un PNG de reemplazo (game_editor.md § 3.1).
class SpriteValidation {
  const SpriteValidation(this.errors, this.warnings, this.info);
  final List<String> errors;
  final List<String> warnings;
  final PngInfo? info;

  bool get ok => errors.isEmpty;
}

/// Peso máximo de un PNG de sprite.
const kMaxSpriteBytes = 1024 * 1024;

/// Colores distintos a partir de los cuales se avisa (informativo).
const kPaletteWarnColors = 32;

/// Valida [png] como reemplazo de un sprite de tamaño [expected]:
/// - error: no es PNG, sin transparencia, > 1 MB, tamaño distinto que no
///   es múltiplo/divisor entero exacto del original;
/// - aviso: múltiplo/divisor exacto (se acepta), píxeles semitransparentes
///   (pixel art: alfa 0 o 255), más de [kPaletteWarnColors] colores.
SpriteValidation validateSpritePng(Uint8List png,
    {(int, int)? expected, RgbaPixels? pixels}) {
  final errors = <String>[];
  final warnings = <String>[];
  final info = PngInfo.parse(png);
  if (info == null) {
    return const SpriteValidation(['No es un PNG válido.'], [], null);
  }
  if (png.length > kMaxSpriteBytes) {
    errors.add('Pesa ${(png.length / 1024).ceil()} KB (máx. 1024 KB).');
  }
  if (!info.hasAlpha) {
    errors.add('Sin transparencia: exportá el PNG con canal alfa.');
  }
  if (expected != null) {
    final (ew, eh) = expected;
    final (w, h) = (info.width, info.height);
    if (w != ew || h != eh) {
      final up = w % ew == 0 && h % eh == 0 && w ~/ ew == h ~/ eh;
      final down = ew % w == 0 && eh % h == 0 && ew ~/ w == eh ~/ h;
      if (up) {
        warnings.add('Tamaño ${w}x$h = ×${w ~/ ew} del original ${ew}x$eh.');
      } else if (down) {
        warnings.add('Tamaño ${w}x$h = 1/${ew ~/ w} del original ${ew}x$eh.');
      } else {
        errors.add('Tamaño ${w}x$h: se espera ${ew}x$eh '
            '(o un múltiplo/divisor exacto).');
      }
    }
  }
  if (pixels != null) {
    final colors = <int>{};
    var semi = 0;
    final p = pixels.rgba;
    for (var i = 0; i + 3 < p.length; i += 4) {
      final a = p[i + 3];
      if (a == 0) continue;
      if (a < 255) semi++;
      colors.add((p[i] << 16) | (p[i + 1] << 8) | p[i + 2]);
    }
    if (semi > 0) {
      warnings.add('$semi píxeles semitransparentes (pixel art: alfa 0 o 255).');
    }
    if (colors.length > kPaletteWarnColors) {
      warnings.add('${colors.length} colores (más de $kPaletteWarnColors).');
    }
  }
  return SpriteValidation(errors, warnings, info);
}
