import 'dart:typed_data';

import 'package:yaml/yaml.dart';

/// Variantes procedurales de NPC (docs/specs/npc_variants.md): a partir
/// de un cuerpo base (un sprite del manifest) y una semilla, cambia la
/// paleta por región (pelo, piel, ropa, pantalón, acento) con colores
/// curados, suma partes en capas (sombreros, capuchas, barbas, bufandas,
/// mochilas, herramientas, accesorio magitec) y, si el pixel art lo
/// permite, estira el torso un píxel. Dart puro y pixel-perfect: trabaja
/// sobre RGBA crudo, nunca re-muestrea ni suaviza.
///
/// Los datos viven en `assets/sprites/npc_variants.yaml`, que solo lee
/// `SpriteCatalog`.

/// Imagen RGBA cruda (straight alpha), 4 bytes por píxel.
class Rgba {
  Rgba(this.width, this.height, [Uint8List? pixels])
      : pixels = pixels ?? Uint8List(width * height * 4);
  final int width, height;
  final Uint8List pixels;

  int _i(int x, int y) => (y * width + x) * 4;
  bool inside(int x, int y) => x >= 0 && y >= 0 && x < width && y < height;

  /// Alfa del píxel.
  int alpha(int x, int y) => pixels[_i(x, y) + 3];

  /// Color `0xRRGGBB` del píxel (sin alfa).
  int rgb(int x, int y) {
    final i = _i(x, y);
    return (pixels[i] << 16) | (pixels[i + 1] << 8) | pixels[i + 2];
  }

  void set(int x, int y, int rgb, [int a = 255]) {
    final i = _i(x, y);
    pixels[i] = (rgb >> 16) & 0xff;
    pixels[i + 1] = (rgb >> 8) & 0xff;
    pixels[i + 2] = rgb & 0xff;
    pixels[i + 3] = a;
  }

  Rgba copy() => Rgba(width, height, Uint8List.fromList(pixels));

  @override
  bool operator ==(Object other) =>
      other is Rgba &&
      other.width == width &&
      other.height == height &&
      _same(other.pixels, pixels);

  static bool _same(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(width, height, Object.hashAll(pixels));
}

/// RNG con semilla (splitmix32): mismo resultado en toda plataforma.
class SeededRng {
  SeededRng(int seed) : _s = seed & 0xffffffff;
  int _s;

  /// Entero de 32 bits sin signo.
  int next() {
    _s = (_s + 0x9e3779b9) & 0xffffffff;
    var z = _s;
    z = ((z ^ (z >> 16)) * 0x85ebca6b) & 0xffffffff;
    z = ((z ^ (z >> 13)) * 0xc2b2ae35) & 0xffffffff;
    return (z ^ (z >> 16)) & 0xffffffff;
  }

  /// `[0, n)`.
  int below(int n) => n <= 0 ? 0 : next() % n;

  /// `[0, 1)`.
  double unit() => next() / 4294967296.0;

  T pick<T>(List<T> xs) => xs[below(xs.length)];
}

/// Regiones de paleta que se pueden recolorear.
const kNpcRegions = ['hair', 'skin', 'clothes', 'pants', 'accent'];

/// Ranuras de partes: en cada una entra como mucho una parte.
const kNpcSlots = ['head', 'chin', 'neck', 'back', 'hand', 'magitec'];

/// Un cuerpo base: qué sprite del manifest (`items.<sprite>`) y qué
/// colores suyos son de cada región (`hair`, `clothes_dark`, ...).
class NpcBase {
  const NpcBase(
      {required this.id,
      required this.sprite,
      required this.regions,
      this.outline = 0x1a1420});
  final String id;

  /// Clave de `items:` del manifest (p. ej. `vida_npc_granjero`).
  final String sprite;

  /// Color `0xRRGGBB` del base → región (`<región>` o
  /// `<región>_dark` / `<región>_light` para sombras y brillos).
  final Map<int, String> regions;

  /// Color del contorno (lo usan las partes).
  final int outline;
}

/// Paletas curadas: por región, la lista de colores permitidos.
class NpcPalette {
  const NpcPalette(this.id, this.regions);
  final String id;
  final Map<String, List<int>> regions;
}

/// Una parte en capas: grilla de caracteres anclada a un punto del
/// cuerpo (ver [NpcVariantGenerator.anchors]).
///
/// Caracteres: `.` vacío, `o` contorno, `h` pelo, `s` piel, `c` ropa,
/// `C` ropa oscura, `p` pantalón, `a` acento, `A` acento oscuro, `m`
/// metal, `M` metal oscuro, `w` madera, `g` brillo magitec.
class NpcPart {
  const NpcPart(
      {required this.id,
      required this.slot,
      required this.anchor,
      required this.pivot,
      required this.rows,
      this.under = false});
  final String id;
  final String slot;

  /// `top`, `chin`, `back` o `hand`.
  final String anchor;

  /// Píxel de la grilla que cae sobre el ancla.
  final (int, int) pivot;
  final List<String> rows;

  /// Solo pinta donde el base es transparente (mochilas: detrás).
  final bool under;
}

/// La variante de un NPC: base, semilla, paleta y partes permitidas.
class NpcVariantSpec {
  const NpcVariantSpec(
      {required this.id,
      required this.base,
      required this.seed,
      required this.palette,
      this.parts = const [],
      this.tweak = true,
      this.fixed});
  final String id;

  /// Aspecto fijo guardado desde el Editor ("Guardar como fijo"): si
  /// está, se usa tal cual y la semilla ya no decide nada. Sin él, el NPC
  /// se regenera de la semilla.
  final NpcVariantPick? fixed;
  final String base;
  final int seed;
  final String palette;
  final List<String> parts;

  /// Permite el retoque de silueta (torso un píxel más alto).
  final bool tweak;

  NpcVariantSpec copyWith(
          {String? id,
          int? seed,
          String? palette,
          List<String>? parts,
          bool? tweak,
          String? base,
          NpcVariantPick? fixed,
          bool clearFixed = false}) =>
      NpcVariantSpec(
          id: id ?? this.id,
          base: base ?? this.base,
          seed: seed ?? this.seed,
          palette: palette ?? this.palette,
          parts: parts ?? this.parts,
          tweak: tweak ?? this.tweak,
          fixed: clearFixed ? null : fixed ?? this.fixed);
}

/// El documento `npc_variants.yaml`.
class NpcVariantsDoc {
  NpcVariantsDoc(
      {Map<String, NpcBase>? bases,
      Map<String, NpcPalette>? palettes,
      Map<String, NpcPart>? parts,
      Map<String, NpcVariantSpec>? variants})
      : bases = bases ?? {},
        palettes = palettes ?? {},
        parts = parts ?? {},
        variants = variants ?? {};

  final Map<String, NpcBase> bases;
  final Map<String, NpcPalette> palettes;
  final Map<String, NpcPart> parts;
  final Map<String, NpcVariantSpec> variants;

  static const schema = 1;

  bool get isEmpty => variants.isEmpty;

  /// Lee el texto. Entradas inválidas se ignoran; [FormatException] si
  /// no es YAML de este esquema.
  static NpcVariantsDoc parse(String? raw) {
    final d = NpcVariantsDoc();
    if (raw == null || raw.trim().isEmpty) return d;
    final Object? doc;
    try {
      doc = loadYaml(raw);
    } catch (_) {
      throw const FormatException('npc_variants.yaml no es YAML válido.');
    }
    if (doc == null) return d;
    if (doc is! YamlMap || (doc['schema'] as num? ?? 1) > schema) {
      throw const FormatException('npc_variants.yaml no soportado.');
    }
    Iterable<MapEntry<String, YamlMap>> each(Object? m) sync* {
      if (m is! YamlMap) return;
      for (final MapEntry(:key, :value) in m.entries) {
        if (value is YamlMap) yield MapEntry('$key', value);
      }
    }

    for (final MapEntry(:key, :value) in each(doc['bases'])) {
      final sprite = value['sprite'];
      final regions = <int, String>{};
      final r = value['regions'];
      if (r is YamlMap) {
        for (final MapEntry(key: c, value: reg) in r.entries) {
          final rgb = parseHex('$c');
          if (rgb != null && reg is String) regions[rgb] = reg;
        }
      }
      if (sprite is! String) continue;
      d.bases[key] = NpcBase(
          id: key,
          sprite: sprite,
          regions: regions,
          outline: parseHex('${value['outline']}') ?? 0x1a1420);
    }
    for (final MapEntry(:key, :value) in each(doc['palettes'])) {
      final regions = <String, List<int>>{};
      for (final reg in kNpcRegions) {
        final l = value[reg];
        if (l is! YamlList) continue;
        final cs = [for (final c in l) parseHex('$c')].whereType<int>().toList();
        if (cs.isNotEmpty) regions[reg] = cs;
      }
      d.palettes[key] = NpcPalette(key, regions);
    }
    for (final MapEntry(:key, :value) in each(doc['parts'])) {
      final slot = value['slot'], anchor = value['anchor'];
      final rows = value['rows'], pivot = value['pivot'];
      if (slot is! String || !kNpcSlots.contains(slot)) continue;
      if (anchor is! String || rows is! YamlList) continue;
      final pv = pivot is YamlList && pivot.length == 2
          ? ((pivot[0] as num).toInt(), (pivot[1] as num).toInt())
          : (0, 0);
      d.parts[key] = NpcPart(
          id: key,
          slot: slot,
          anchor: anchor,
          pivot: pv,
          rows: [for (final r in rows) '$r'],
          under: value['under'] == true);
    }
    for (final MapEntry(:key, :value) in each(doc['variants'])) {
      final base = value['base'], palette = value['palette'];
      final seed = value['seed'];
      if (base is! String || palette is! String || seed is! num) continue;
      final parts = value['parts'];
      NpcVariantPick? fixed;
      final f = value['fixed'];
      if (f is YamlMap) {
        final cs = f['colors'], ps = f['parts'];
        fixed = NpcVariantPick({
          if (cs is YamlMap)
            for (final MapEntry(key: r, value: c) in cs.entries)
              if (kNpcRegions.contains('$r') && parseHex('$c') != null)
                '$r': parseHex('$c')!,
        }, ps is YamlList ? [for (final p in ps) '$p'] : const [],
            f['stretched'] == true);
      }
      d.variants[key] = NpcVariantSpec(
          fixed: fixed,
          id: key,
          base: base,
          seed: seed.toInt(),
          palette: palette,
          parts: parts is YamlList ? [for (final p in parts) '$p'] : const [],
          tweak: value['tweak'] != false);
    }
    return d;
  }

  /// `#rrggbb` → `0xRRGGBB`, o `null`.
  static int? parseHex(String s) {
    final t = s.trim().toLowerCase();
    if (!RegExp(r'^#[0-9a-f]{6}$').hasMatch(t)) return null;
    return int.parse(t.substring(1), radix: 16);
  }

  static String hex(int rgb) => '#${rgb.toRadixString(16).padLeft(6, '0')}';

  /// Texto YAML estable (el Editor lo guarda).
  String encode() {
    final b = StringBuffer('# Variantes procedurales de NPC '
        '(docs/specs/npc_variants.md).\n'
        '# Solo lo lee SpriteCatalog; el Editor (Visuales → VARIANTES NPC) '
        'lo reescribe.\nschema: $schema\n');
    b.writeln('bases:');
    for (final x in bases.values) {
      b.writeln('  ${x.id}:');
      b.writeln('    sprite: ${x.sprite}');
      b.writeln("    outline: '${hex(x.outline)}'");
      b.writeln('    regions:');
      for (final MapEntry(:key, :value) in x.regions.entries) {
        b.writeln("      '${hex(key)}': $value");
      }
    }
    b.writeln('palettes:');
    for (final p in palettes.values) {
      b.writeln('  ${p.id}:');
      for (final MapEntry(:key, :value) in p.regions.entries) {
        b.writeln("    $key: [${value.map((c) => "'${hex(c)}'").join(', ')}]");
      }
    }
    b.writeln('parts:');
    for (final p in parts.values) {
      b.writeln('  ${p.id}:');
      b.writeln('    slot: ${p.slot}');
      b.writeln('    anchor: ${p.anchor}');
      b.writeln('    pivot: [${p.pivot.$1}, ${p.pivot.$2}]');
      if (p.under) b.writeln('    under: true');
      b.writeln('    rows:');
      for (final r in p.rows) {
        b.writeln("      - '$r'");
      }
    }
    b.writeln('variants:');
    for (final v in variants.values) {
      b.write('  ${v.id}: { base: ${v.base}, seed: ${v.seed}, '
          'palette: ${v.palette}, parts: [${v.parts.join(', ')}]');
      if (!v.tweak) b.write(', tweak: false');
      if (v.fixed case final f?) {
        final cs = [
          for (final r in kNpcRegions)
            if (f.colors[r] case final c?) "$r: '${hex(c)}'"
        ];
        b.write(', fixed: { colors: { ${cs.join(', ')} }, '
            'parts: [${f.parts.join(', ')}], stretched: ${f.stretched} }');
      }
      b.writeln(' }');
    }
    return b.toString();
  }
}

/// Lo que eligió la semilla (el Editor lo muestra).
class NpcVariantPick {
  const NpcVariantPick(this.colors, this.parts, this.stretched);
  final Map<String, int> colors;
  final List<String> parts;
  final bool stretched;
}

/// Generador puro: misma entrada → mismos píxeles.
class NpcVariantGenerator {
  const NpcVariantGenerator(this.doc);
  final NpcVariantsDoc doc;

  /// Qué elige [spec] (colores por región, partes, retoque).
  NpcVariantPick pick(NpcVariantSpec spec) {
    if (spec.fixed case final f?) return f;
    return roll(spec);
  }

  /// Lo que elige la semilla, ignorando un aspecto fijo.
  NpcVariantPick roll(NpcVariantSpec spec) {
    final rng = SeededRng(spec.seed);
    final pal = doc.palettes[spec.palette];
    final colors = <String, int>{};
    for (final reg in kNpcRegions) {
      final opts = pal?.regions[reg];
      // Se consume siempre un número: cambiar una paleta no corre las
      // demás elecciones.
      final r = rng.below(1 << 30);
      if (opts != null && opts.isNotEmpty) colors[reg] = opts[r % opts.length];
    }
    final chosen = <String>[];
    for (final slot in kNpcSlots) {
      final opts = [
        for (final p in spec.parts)
          if (doc.parts[p]?.slot == slot) p,
      ];
      final roll = rng.unit();
      final which = rng.below(1 << 30);
      if (opts.isEmpty) continue;
      // La ranura magitec es la identidad del autómata: siempre va.
      final always = slot == 'magitec';
      if (always || roll < 0.65) chosen.add(opts[which % opts.length]);
    }
    final stretched = spec.tweak && rng.unit() < 0.5;
    return NpcVariantPick(colors, chosen, stretched);
  }

  /// Genera la variante [spec] sobre los píxeles del [base].
  Rgba generate(Rgba base, NpcVariantSpec spec) {
    final b = doc.bases[spec.base];
    final pick = this.pick(spec);
    var img = recolor(base, b?.regions ?? const {}, pick.colors);
    if (pick.stretched) img = stretch(img, b?.regions ?? const {});
    final regions = _regionMask(base, img, b?.regions ?? const {}, pick.stretched);
    final anchors = anchorsOf(img, regions);
    for (final id in pick.parts) {
      final part = doc.parts[id];
      if (part == null) continue;
      final at = anchors[part.anchor];
      if (at == null) continue;
      _paint(img, part, at, pick.colors, b?.outline ?? 0x1a1420);
    }
    return img;
  }

  /// Cambia cada color mapeado del base por el de su región; lo no
  /// mapeado (contorno, ojos) y la transparencia quedan intactos.
  static Rgba recolor(Rgba base, Map<int, String> regions, Map<String, int> colors) {
    final out = base.copy();
    for (var y = 0; y < base.height; y++) {
      for (var x = 0; x < base.width; x++) {
        final a = base.alpha(x, y);
        if (a == 0) continue;
        final reg = regions[base.rgb(x, y)];
        if (reg == null) continue;
        final c = shadeOf(reg, colors);
        if (c != null) out.set(x, y, c, a);
      }
    }
    return out;
  }

  /// Color de `<región>[_dark|_light]` con la paleta elegida.
  static int? shadeOf(String reg, Map<String, int> colors) {
    if (reg.endsWith('_dark')) {
      final c = colors[reg.substring(0, reg.length - 5)];
      return c == null ? null : _scale(c, 0.68);
    }
    if (reg.endsWith('_light')) {
      final c = colors[reg.substring(0, reg.length - 6)];
      return c == null ? null : _mix(c, 0xffffff, 0.3);
    }
    return colors[reg];
  }

  static int _scale(int c, double f) {
    int ch(int s) => (((c >> s) & 0xff) * f).round().clamp(0, 255);
    return (ch(16) << 16) | (ch(8) << 8) | ch(0);
  }

  static int _mix(int a, int b, double t) {
    int ch(int s) =>
      (((a >> s) & 0xff) * (1 - t) + ((b >> s) & 0xff) * t).round().clamp(0, 255);
    return (ch(16) << 16) | (ch(8) << 8) | ch(0);
  }

  /// Retoque de silueta: si la fila de arriba está vacía, la quita y
  /// duplica la primera fila de ropa (torso un píxel más alto, mismos
  /// pies y mismo tamaño). Si no hay espacio, devuelve [img] tal cual.
  static Rgba stretch(Rgba img, Map<int, String> regions) {
    if (!_rowEmpty(img, 0)) return img;
    final row = _firstRow(img, regions, 'clothes');
    if (row == null || row < 1) return img;
    final out = Rgba(img.width, img.height);
    final stride = img.width * 4;
    // Filas 1..row suben una; la fila `row` queda duplicada.
    out.pixels.setRange(0, row * stride, img.pixels, stride);
    out.pixels.setRange(row * stride, img.pixels.length, img.pixels, row * stride);
    return out;
  }

  static bool _rowEmpty(Rgba img, int y) {
    for (var x = 0; x < img.width; x++) {
      if (img.alpha(x, y) != 0) return false;
    }
    return true;
  }

  static int? _firstRow(Rgba img, Map<int, String> regions, String reg) {
    for (var y = 0; y < img.height; y++) {
      for (var x = 0; x < img.width; x++) {
        if (img.alpha(x, y) == 0) continue;
        final r = regions[img.rgb(x, y)];
        if (r != null && r.startsWith(reg)) return y;
      }
    }
    return null;
  }

  /// Región de cada píxel de [img] (leída del [base] original, porque el
  /// recoloreo puede repetir colores entre regiones).
  static List<String?> _regionMask(
      Rgba base, Rgba img, Map<int, String> regions, bool stretched) {
    final src = <String?>[
      for (var y = 0; y < base.height; y++)
        for (var x = 0; x < base.width; x++)
          base.alpha(x, y) == 0 ? null : regions[base.rgb(x, y)]
    ];
    if (!stretched || img.height != base.height) return src;
    final row = _firstRow(base, regions, 'clothes')!;
    final w = base.width;
    return [
      ...src.sublist(w, (row + 1) * w),
      ...src.sublist(row * w),
    ];
  }

  /// Anclas de las partes, calculadas de las regiones (sin coordenadas a
  /// mano): `top` (centro de la fila más alta), `chin` (debajo de la
  /// piel), `back` (borde izquierdo del torso) y `hand` (borde derecho
  /// del torso, a media altura).
  static Map<String, (int, int)> anchorsOf(Rgba img, List<String?> regions) {
    final w = img.width;
    int? top, topL, topR;
    int? skinMinX, skinMaxX, skinMaxY;
    int? torsoY, torsoMinX, torsoMaxX, torsoMaxY;
    for (var y = 0; y < img.height; y++) {
      for (var x = 0; x < w; x++) {
        if (img.alpha(x, y) == 0) continue;
        if (top == null || top == y) {
          top = y;
          topL = topL == null || x < topL ? x : topL;
          topR = topR == null || x > topR ? x : topR;
        }
        final r = regions[y * w + x];
        if (r == null) continue;
        if (r.startsWith('skin') && (torsoY == null)) {
          skinMinX = skinMinX == null || x < skinMinX ? x : skinMinX;
          skinMaxX = skinMaxX == null || x > skinMaxX ? x : skinMaxX;
          skinMaxY = skinMaxY == null || y > skinMaxY ? y : skinMaxY;
        }
        if (r.startsWith('clothes')) {
          torsoY ??= y;
          torsoMinX = torsoMinX == null || x < torsoMinX ? x : torsoMinX;
          torsoMaxX = torsoMaxX == null || x > torsoMaxX ? x : torsoMaxX;
          torsoMaxY = torsoMaxY == null || y > torsoMaxY ? y : torsoMaxY;
        }
      }
    }
    final out = <String, (int, int)>{};
    if (top != null) out['top'] = (((topL! + topR!) / 2).floor(), top);
    if (skinMaxY != null) {
      out['chin'] = (((skinMinX! + skinMaxX!) / 2).floor(), skinMaxY + 1);
    }
    if (torsoY != null) {
      out['back'] = (torsoMinX!, torsoY);
      out['hand'] = (torsoMaxX! + 1, ((torsoY + torsoMaxY!) / 2).floor());
    }
    return out;
  }

  static void _paint(Rgba img, NpcPart part, (int, int) at,
      Map<String, int> colors, int outline) {
    int? colorOf(String ch) => switch (ch) {
          'o' => outline,
          'h' => colors['hair'],
          's' => colors['skin'],
          'c' => colors['clothes'],
          'C' => shadeOf('clothes_dark', colors),
          'p' => colors['pants'],
          'a' => colors['accent'],
          'A' => shadeOf('accent_dark', colors),
          'm' => 0xa8b0bc,
          'M' => 0x6a7280,
          'w' => 0x8a5a32,
          'g' => 0x6fb6ff,
          _ => null,
        };
    final ox = at.$1 - part.pivot.$1, oy = at.$2 - part.pivot.$2;
    for (var j = 0; j < part.rows.length; j++) {
      final row = part.rows[j];
      for (var i = 0; i < row.length; i++) {
        final c = colorOf(row[i]);
        if (c == null) continue;
        final x = ox + i, y = oy + j;
        if (!img.inside(x, y)) continue;
        if (part.under && img.alpha(x, y) != 0) continue;
        img.set(x, y, c);
      }
    }
  }
}
