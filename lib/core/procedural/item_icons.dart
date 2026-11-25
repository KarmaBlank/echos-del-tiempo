import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../../game_engine/models/item.dart' show Rarity;
import 'item_icon_rows.dart';
import 'procedural_art.dart';
import 'weapon_look.dart';

export 'item_icon_rows.dart';

/// Pintor del ícono de [entryId] (`items.espada`, o `items` = familia)
/// con las perillas vigentes de [ProceduralArt.instance].
class ItemIconPainter extends CustomPainter {
  ItemIconPainter(this.rows, this.accent, this.entryId, {this.look})
      : revision = ProceduralArt.instance.revision;
  final List<String> rows;
  final Color accent;
  final String entryId;
  final int revision;

  /// Identidad del arma concreta (aura sutil, acento, ULT, variante).
  final WeaponLook? look;

  /// Clave del PNG (`items.<clave>` del manifest; ver [ItemIconImages]),
  /// o `null` = siempre procedural.
  String? pngKey;

  /// Manifest id of a profession weapon's own icon (`gear_<id>`, see
  /// profession_gear.md); when loaded it replaces the type's icon.
  String? gearSprite;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final p = ProceduralArt.instance.resolve(entryId);
    final gear = gearSprite == null ? null : ItemIconImages.gear(gearSprite!);
    if (gear != null) {
      paintItemIconPng(canvas, r, gear, null, accent);
      if (look != null) {
        paintItemIcon(canvas, r, rows, accent, p, look: look, base: false);
      }
      return;
    }
    final png = pngKey == null ? null : ItemIconImages.base(pngKey!);
    if (png == null) {
      paintItemIcon(canvas, r, rows, accent, p, look: look);
      return;
    }
    paintItemIconPng(canvas, r, png, ItemIconImages.accent(pngKey!), accent);
    // Identidad del arma (aura, destello, ULT) encima del PNG.
    if (look != null) {
      paintItemIcon(canvas, r, rows, accent, p, look: look, base: false);
    }
  }

  @override
  bool shouldRepaint(ItemIconPainter old) =>
      old.rows != rows ||
      old.accent != accent ||
      old.entryId != entryId ||
      old.look != look ||
      old.pngKey != pngKey ||
      old.gearSprite != gearSprite ||
      old.revision != revision;
}

/// PNG de los íconos de armas e ítems (`items.<clave>` y
/// `items.<clave>_acento` del manifest; tool/export_item_icons.dart). Los
/// carga GameSprites vía SpriteCatalog; si falta uno, el pintor vuelve al
/// dibujo procedural.
abstract final class ItemIconImages {
  static final _base = <String, ui.Image>{};
  static final _accent = <String, ui.Image>{};
  static final _gear = <String, ui.Image>{};

  /// Registers the icon of profession weapon sprite [id] (`gear_<id>`).
  static void putGear(String id, ui.Image img) => _gear[id] = img;

  /// Icon of profession weapon sprite [id], or `null` if not loaded.
  static ui.Image? gear(String id) => _gear[id];

  /// Registra la imagen de la entrada [key] del manifest.
  static void put(String key, ui.Image img) => key.endsWith('_acento')
      ? _accent[key.substring(0, key.length - 7)] = img
      : _base[key] = img;

  static void clear() {
    _base.clear();
    _accent.clear();
    _gear.clear();
  }

  static ui.Image? base(String key) => _base[key];
  static ui.Image? accent(String key) => _accent[key];

  /// Clave del PNG de una forma (`báculo` → `baculo`).
  static String keyOf(String shape) => shape.replaceAll('á', 'a');
}

/// Dibuja el PNG [base] en [r] sin difuminado y encima el acento [mask]
/// (grises) teñido con [accent].
void paintItemIconPng(
    Canvas canvas, Rect r, ui.Image base, ui.Image? mask, Color accent) {
  final side = r.shortestSide;
  final dst = Rect.fromCenter(center: r.center, width: side, height: side);
  Rect src(ui.Image i) =>
      Rect.fromLTWH(0, 0, i.width.toDouble(), i.height.toDouble());
  final paint = Paint()
    ..filterQuality = FilterQuality.none
    ..isAntiAlias = false;
  canvas.drawImageRect(base, src(base), dst, paint);
  if (mask != null) {
    canvas.drawImageRect(mask, src(mask), dst,
        paint..colorFilter = ColorFilter.mode(accent, BlendMode.modulate));
  }
}

/// Dibuja la entrada [entryId] del manifest (`items.espada`) si tiene
/// generador; `false` si no (el Editor la marca rayada).
bool paintProceduralEntry(Canvas canvas, Rect r, String entryId,
    {Color accent = kItemDefaultAccent}) {
  final parts = entryId.split('.');
  if (parts.length < 2 || parts[0] != 'items') return false;
  final shape = kItemEntryShapes[parts[1]];
  if (shape == null) return false;
  final side = r.shortestSide;
  paintItemIcon(canvas, Rect.fromCenter(center: r.center, width: side, height: side),
      kItemIconRows[shape]!, accent,
      ProceduralArt.instance.resolve('items.${parts[1]}'));
  return true;
}


/// Entrada `items.<clave>` del sprite_manifest.yaml → forma.
const kItemEntryShapes = <String, String>{
  'espada': 'espada',
  'hacha': 'hacha',
  'lanza': 'lanza',
  'dagas': 'dagas',
  'espada_escudo': 'espada_escudo',
  'maza_escudo': 'maza_escudo',
  'martillo_escudo': 'martillo_escudo',
  'arco': 'arco',
  'ballesta': 'ballesta',
  'rifle': 'rifle',
  'baculo': 'báculo',
  'varita': 'varita',
  'tomo': 'tomo',
  'pocion': 'pocion',
  'cofre': 'cofre',
};

/// Acento por defecto de las entradas del Editor (sin rareza): celeste.
const kItemDefaultAccent = Color(0xFF9FB4FF);

/// Clave de entrada del manifest de un tipo de arma (`espada+escudo` →
/// `espada_escudo`, `báculo` → `baculo`), o `null` si no tiene.
String? procKeyForType(String type) {
  final k = type.replaceAll('+', '_').replaceAll('á', 'a');
  return kItemEntryShapes.containsKey(k) ? k : null;
}

Color _hex(String s) => Color(0xFF000000 | int.parse(s.substring(1), radix: 16));

Color _tone(Color c, double shine) => shine == 0
    ? c
    : Color.lerp(c, shine > 0 ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
        shine.abs())!;

/// Dibuja la forma [rows] en [r] con las perillas [p]. [accent] = el
/// acento que decide el juego (rareza, material) si la perilla `accent`
/// está vacía.
///
/// Con [look] (un arma concreta, weapon_identity.md § 3) suma la
/// identidad: acento de la rareza, variante suave por uid (tono del
/// metal y gema, sin tocar la silueta), aura tenue del elemento con
/// partículas, destello del legendario y el píxel de la ULT en el pomo.
/// [time] (segundos) anima el aura y el destello; con 0 queda quieto.
void paintItemIcon(Canvas canvas, Rect r, List<String> rows, Color accent,
    ProcParams p, {WeaponLook? look, double time = 0, bool base = true}) {
  // Grilla cuadrada de n × n (8 o 14). Encima de un PNG ([base] false)
  // la grilla va sobre los 14 px internos (margen de 1 para el contorno),
  // alineada con el dibujo exportado (tool/export_item_icons.dart).
  final n = rows.length;
  if (!base) r = r.deflate(r.shortestSide / 16);
  final vary = look != null && p.flag('variation') ? look.variant : 0;
  final shine = (p.number('shine') +
          switch (vary) { 1 => 0.12, 2 => -0.12, _ => 0.0 })
      .clamp(-0.6, 0.6);
  Color col(String k) => _tone(_hex(p.color(k)), shine);
  final acc = p.color('accent').isEmpty ? _tone(accent, shine) : col('accent');
  final palette = {
    'm': col('metal'),
    'h': col('handle'),
    'g': acc,
    's': col('string'),
    'p': col('paper'),
    'c': col('cover'),
    'w': col('glass'),
  };
  final scale = p.number('scale');
  final px = r.width * scale / n;
  final ox = r.left + (r.width - px * n) / 2;
  final oy = r.top + (r.height - px * n) / 2;
  final mirror = p.flag('mirror');
  final paint = Paint()..isAntiAlias = false;
  void cell(int x, int y, Color c) {
    paint.color = c;
    final cx = mirror ? n - 1 - x : x;
    canvas.drawRect(Rect.fromLTWH(ox + cx * px, oy + y * px, px, px), paint);
  }

  bool filled(int x, int y) =>
      y >= 0 && y < rows.length && x >= 0 && x < rows[y].length &&
      palette.containsKey(rows[y][x]);

  if (base && p.flag('outline')) {
    final oc = _hex(p.color('outline_color'));
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        if (filled(x, y)) continue;
        if (filled(x - 1, y) || filled(x + 1, y) || filled(x, y - 1) || filled(x, y + 1)) {
          cell(x, y, oc);
        }
      }
    }
  }
  // Aura del elemento: halo de 1 celda alrededor de la silueta.
  final aura = look?.auraColor;
  final auraK = p.number('aura');
  if (aura != null && auraK > 0) {
    final ac = aura.withValues(alpha: (auraK * 0.7).clamp(0.0, 1.0));
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        if (filled(x, y)) continue;
        if (filled(x - 1, y) || filled(x + 1, y) || filled(x, y - 1) ||
            filled(x, y + 1)) {
          cell(x, y, ac);
        }
      }
    }
  }
  final highlight = p.flag('highlight') || look?.rarity == Rarity.epico;
  var gem = p.flag('gem') || vary == 2;
  for (var y = 0; base && y < rows.length; y++) {
    var lit = false;
    for (var x = 0; x < rows[y].length; x++) {
      final k = rows[y][x];
      var c = palette[k];
      if (c == null) continue;
      if (gem && k == 'h') {
        c = acc;
        gem = false;
      } else if (highlight && !lit && k == 'm') {
        c = Color.lerp(c, const Color(0xFFFFFFFF), 0.5)!;
        lit = true;
      }
      cell(x, y, c);
    }
  }
  if (look == null) return;
  // Partículas lentas del aura (2), solo en celdas vacías.
  if (aura != null && auraK > 0 && p.flag('aura_particles')) {
    final pc = aura.withValues(alpha: (auraK * 0.9).clamp(0.0, 1.0));
    for (var k = 0; k < 2; k++) {
      final ph = time * 1.2 + k * 4 + look.variant;
      final y = n - 1 - (ph % n).floor();
      final x = (k * 5 + 1 + (ph / n).floor() * 3) % n;
      if (!filled(x, y)) cell(x, y, pc);
    }
  }
  // Destello del legendario: un píxel blanco recorre el metal cada ~2 s.
  if (look.legendary && p.flag('sparkle')) {
    final metal = <(int, int)>[
      for (var y = 0; y < rows.length; y++)
        for (var x = 0; x < rows[y].length; x++)
          if (rows[y][x] == 'm' || rows[y][x] == 'g') (x, y),
    ];
    if (metal.isNotEmpty) {
      final i = (time * 6).floor() % (metal.length + 6);
      final (x, y) = metal[i < metal.length ? i : 0];
      cell(x, y, i < metal.length ? const Color(0xFFFFFFFF) : const Color(0xFFFFE08A));
    }
  }
  // Marca de ULT: un píxel rosa en el pomo (la última celda del mango).
  if (look.hasUlt && p.flag('ult_mark')) {
    (int, int)? pommel;
    for (var y = rows.length - 1; y >= 0 && pommel == null; y--) {
      for (var x = 0; x < rows[y].length; x++) {
        if (rows[y][x] == 'h') {
          pommel = (x, y);
          break;
        }
      }
    }
    if (pommel == null) {
      for (var y = rows.length - 1; y >= 0 && pommel == null; y--) {
        for (var x = 0; x < rows[y].length; x++) {
          if (filled(x, y)) {
            pommel = (x, y);
            break;
          }
        }
      }
    }
    if (pommel != null) cell(pommel.$1, pommel.$2, kUltMarkColor);
  }
}
