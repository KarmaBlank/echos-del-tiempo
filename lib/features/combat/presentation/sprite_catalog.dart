import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:yaml/yaml.dart';

import '../../../core/procedural/npc_variants.dart';
import '../../../core/procedural/procedural_art.dart';
import '../../../game_engine/data/enemies_catalog.dart';
import '../domain/sprite_entry.dart';

export '../domain/sprite_entry.dart';

/// Lee `assets/sprites/sprite_manifest.yaml` y resuelve id lógico ->
/// `Sprite` de Flame. Es la ÚNICA clase que sabe que los sprites viven
/// como archivos; todo lo demás pide sprites por id ("guerrero.idle") y
/// no le importa si mañana cambian a Aseprite, a un atlas distinto, o lo
/// que sea.
///
/// Cambiar un sprite = reemplazar el PNG (y el manifest si cambia el
/// path). Nunca hace falta recompilar lógica de juego.
///
/// Capa de overrides (docs/specs/game_editor.md § 4.2): si hay una
/// [SpriteOverrideSource] (el Editor, o `main_dev` con
/// `FeatureFlags.useLocalOverrides`), cada imagen se busca primero ahí y
/// después en el asset. [reload] invalida la caché (recarga en caliente).
///
/// Todo es pixel art: los `Sprite` salen con `FilterQuality.none`
/// (vecino más cercano). Formato y animaciones: docs/specs/sprites.md.
class SpriteCatalog {
  SpriteCatalog._(this._manifest, this._bundle, this.overrides);

  /// Ruta del manifest dentro del bundle.
  static const manifestPath = 'assets/sprites/sprite_manifest.yaml';

  /// Prefijo de todas las rutas del manifest.
  static const spritesRoot = 'assets/sprites/';

  /// Overrides que usa [load] si no se le pasan otros (los pone el
  /// composition root: `main_dev` con `useLocalOverrides`).
  static SpriteOverrideSource? defaultOverrides;

  final YamlMap _manifest;
  final AssetBundle _bundle;

  /// Capa de overrides locales (`null` en el juego publicado).
  final SpriteOverrideSource? overrides;

  /// Cache de imágenes decodificadas (guarda el `Future` para que dos
  /// pedidos simultáneos del mismo archivo lo carguen una sola vez).
  /// Clave: id de la entrada.
  final _cache = <String, Future<ui.Image>>{};

  /// Carga el manifest. [bundle] permite inyectar otro `AssetBundle`
  /// (tests); por defecto usa `rootBundle`.
  static Future<SpriteCatalog> load(
      {AssetBundle? bundle, SpriteOverrideSource? overrides}) async {
    final b = bundle ?? rootBundle;
    final raw = await b.loadString(manifestPath);
    final c = SpriteCatalog.fromYaml(raw,
        bundle: b, overrides: overrides ?? defaultOverrides);
    await c.loadProcedural();
    await c.loadNpcVariants();
    return c;
  }

  /// Ruta de las variantes procedurales de NPC (npc_variants.md).
  static const npcVariantsPath = 'assets/sprites/npc_variants.yaml';

  /// Variantes de NPC efectivas: override local (si hay) o las del repo.
  NpcVariantsDoc npcVariants = NpcVariantsDoc();
  bool _variantsLoaded = false;
  Future<Map<String, ui.Image>>? _variantImages;

  /// Lee `npc_variants.yaml` (override → repo). Datos rotos = sin
  /// variantes (el juego usa el sprite de respaldo del manifest).
  Future<void> loadNpcVariants() async {
    _variantsLoaded = true;
    _variantImages = null;
    final o = overrides;
    if (o is NpcVariantsOverrideSource) {
      try {
        final raw = await (o as NpcVariantsOverrideSource).readNpcVariants();
        if (raw != null) {
          npcVariants = NpcVariantsDoc.parse(raw);
          return;
        }
      } catch (_) {}
    }
    try {
      npcVariants = NpcVariantsDoc.parse(await _bundle.loadString(npcVariantsPath));
    } catch (_) {
      npcVariants = NpcVariantsDoc();
    }
  }

  /// Píxeles RGBA del cuerpo base [baseId] de las variantes, o `null`.
  Future<Rgba?> npcBasePixels(String baseId, [NpcVariantsDoc? doc]) async {
    final b = (doc ?? npcVariants).bases[baseId];
    if (b == null) return null;
    final e = entry('items.${b.sprite}.idle');
    if (e == null) return null;
    final img = await image(e);
    if (img == null) return null;
    final data = await img.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
    if (data == null) return null;
    return Rgba(img.width, img.height,
        Uint8List.fromList(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes)));
  }

  /// Genera la variante [spec] (sin caché: la usa el Editor al tocar
  /// perillas). `null` si su base no existe.
  Future<ui.Image?> npcVariantImage(NpcVariantSpec spec, [NpcVariantsDoc? doc]) async {
    final d = doc ?? npcVariants;
    final base = await npcBasePixels(spec.base, d);
    if (base == null) return null;
    return rgbaImage(NpcVariantGenerator(d).generate(base, spec));
  }

  /// Todas las variantes del documento, generadas UNA vez y cacheadas
  /// como `ui.Image` (clave: id de la variante = id de sprite del NPC).
  /// Una que falla se omite (queda el sprite de respaldo del manifest).
  Future<Map<String, ui.Image>> npcVariantImages() async {
    if (!_variantsLoaded) await loadNpcVariants();
    return _variantImages ??= () async {
      final out = <String, ui.Image>{};
      final bases = <String, Rgba?>{};
      final gen = NpcVariantGenerator(npcVariants);
      for (final spec in npcVariants.variants.values) {
        try {
          final base = bases.containsKey(spec.base)
              ? bases[spec.base]
              : bases[spec.base] = await npcBasePixels(spec.base);
          if (base == null) continue;
          out[spec.id] = await rgbaImage(gen.generate(base, spec));
        } catch (_) {}
      }
      return out;
    }();
  }

  /// `ui.Image` desde RGBA crudo, 1:1 (sin re-muestreo).
  static Future<ui.Image> rgbaImage(Rgba px) async {
    final buf = await ui.ImmutableBuffer.fromUint8List(px.pixels);
    final desc = ui.ImageDescriptor.raw(buf,
        width: px.width, height: px.height, pixelFormat: ui.PixelFormat.rgba8888);
    final codec = await desc.instantiateCodec();
    final frame = await codec.getNextFrame();
    codec.dispose();
    desc.dispose();
    buf.dispose();
    return frame.image;
  }

  /// Ruta de las perillas del arte procedural publicadas (§ 7.5).
  static const proceduralPath = 'assets/sprites/procedural.yaml';

  /// Carga en [ProceduralArt.instance] las perillas del repo y, si la capa
  /// de overrides las tiene, las del override (game_editor.md § 7.5).
  /// Datos rotos o ausentes = valores por defecto (nunca rompe el juego).
  Future<void> loadProcedural() async {
    final art = ProceduralArt.instance;
    try {
      art.setRepo(ProcDoc.parse(await _bundle.loadString(proceduralPath)));
    } catch (_) {
      art.setRepo(ProcDoc());
    }
    final o = overrides;
    if (o is ProceduralOverrideSource) {
      try {
        art.setOverride(ProcDoc.parse(await (o as ProceduralOverrideSource).readProcedural()));
      } catch (_) {
        art.setOverride(ProcDoc());
      }
    }
  }

  /// Desde el texto del manifest (tests y Editor).
  factory SpriteCatalog.fromYaml(String raw,
          {AssetBundle? bundle, SpriteOverrideSource? overrides}) =>
      SpriteCatalog._(loadYaml(raw) as YamlMap? ?? YamlMap(),
          bundle ?? rootBundle, overrides);

  /// Secciones del manifest que lista el Editor, en orden.
  static const sections = ['characters', 'enemies', 'items', 'tiles', 'ui', 'fx'];

  /// Todas las entradas del manifest (una por frame), en orden del
  /// archivo, con su categoría (game_editor.md § 3.1).
  List<SpriteEntry> get entries => [
        for (final s in sections)
          for (final MapEntry(:key, :value) in _section(s).entries)
            ..._entriesOf(s, key as String, value),
      ];

  Iterable<SpriteEntry> _entriesOf(String section, String key, Object? v) {
    if (v is! YamlMap) return const [];
    final category = switch (section) {
      'characters' => SpriteCategory.characters,
      'enemies' =>
        kEnemies[key]?.boss == true || key.contains('Fase2')
            ? SpriteCategory.bosses
            : SpriteCategory.enemies,
      'items' => SpriteCategory.items,
      'tiles' => SpriteCategory.tiles,
      'ui' => SpriteCategory.ui,
      _ => SpriteCategory.fx,
    };
    final size = v['size'];
    final expected = size is YamlList && size.length == 2
        ? ((size[0] as num).toInt(), (size[1] as num).toInt())
        : null;
    if (v['procedural'] == true) {
      return [
        SpriteEntry(
            section: section,
            key: key,
            animation: 'idle',
            category: category,
            expectedSize: expected),
      ];
    }
    return [
      for (final MapEntry(key: anim, value: path) in v.entries)
        if (path is String && path.endsWith('.png'))
          SpriteEntry(
              section: section,
              key: key,
              animation: anim as String,
              category: category,
              path: path,
              expectedSize: expected),
    ];
  }

  /// La entrada de [id] (`<sección>.<clave>.<frame>`), o `null`.
  SpriteEntry? entry(String id) {
    for (final e in entries) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// [id] tiene override local.
  bool hasOverride(String id) =>
      overrides?.overriddenIds.contains(id) ?? false;

  /// Recarga en caliente: olvida la imagen de [id] (o todas) y relee el
  /// índice de overrides. La próxima vez que alguien la pida se lee de
  /// nuevo (override → asset).
  Future<void> reload([String? id]) async {
    await overrides?.refresh();
    if (id == null) {
      _cache.clear();
      await loadProcedural();
      await loadNpcVariants();
    } else {
      _cache.remove(id);
    }
  }

  /// Bytes PNG del asset del repo (sin override), o `null` si es
  /// procedural o no se puede leer.
  Future<Uint8List?> assetBytes(SpriteEntry e) async {
    if (e.path == null) return null;
    try {
      final data = await _bundle.load('$spritesRoot${e.path}');
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } catch (_) {
      return null;
    }
  }

  /// Bytes PNG efectivos: override si hay, si no el asset.
  Future<Uint8List?> bytes(SpriteEntry e) async {
    if (hasOverride(e.id)) {
      final o = await overrides!.read(e.id);
      if (o != null) return o;
    }
    return assetBytes(e);
  }

  /// Imagen efectiva de [e] (override → asset), o `null` si es
  /// procedural sin override.
  Future<ui.Image?> image(SpriteEntry e) async {
    if (e.procedural && !hasOverride(e.id)) return null;
    try {
      return await _loadImage(e);
    } catch (_) {
      return null;
    }
  }

  /// Ids de clase con sprites (`characters:` del manifest).
  Iterable<String> get characterIds =>
      _section('characters').keys.cast<String>();

  /// Ids de enemigo con sprites (`enemies:` del manifest).
  Iterable<String> get enemyIds => _section('enemies').keys.cast<String>();

  /// Animaciones disponibles de una clase (hoy solo `idle`).
  Iterable<String> characterAnimations(String classId) =>
      (_section('characters')[classId] as YamlMap?)?.keys.cast<String>() ??
      const [];

  Future<Sprite> character(String classId, String animation) async {
    final path = characterPath(classId, animation);
    if (path == null) {
      throw StateError(
          'No hay sprite para $classId.$animation en sprite_manifest.yaml');
    }
    return _pixelSprite(await _loadImage(SpriteEntry(
        section: 'characters',
        key: classId,
        animation: animation,
        category: SpriteCategory.characters,
        path: path)));
  }

  Future<Sprite> enemy(String enemyId) async {
    final path = enemyPath(enemyId);
    if (path == null) {
      throw StateError(
          'No hay sprite para el enemigo $enemyId en sprite_manifest.yaml');
    }
    return _pixelSprite(await _loadImage(SpriteEntry(
        section: 'enemies',
        key: enemyId,
        animation: 'idle',
        category: SpriteCategory.enemies,
        path: path)));
  }

  /// Escala de dibujo del enemigo (`sc` del prototipo; 1 si no figura).
  /// El multiplicador de élite (×1.45) lo aplica quien dibuja.
  double enemyScale(String enemyId) {
    final entry = _section('enemies')[enemyId];
    final scale = entry is YamlMap ? entry['scale'] : null;
    return scale is num ? scale.toDouble() : 1.0;
  }

  /// El enemigo flota en el aire (`float:` del manifest; en el prototipo,
  /// los que usan la forma base `bat` o `ghost`). Por defecto `false`.
  bool enemyFloats(String enemyId) {
    final entry = _section('enemies')[enemyId];
    return entry is YamlMap && entry['float'] == true;
  }

  /// Ruta (relativa a [spritesRoot]) del sprite de una clase, o `null`.
  String? characterPath(String classId, String animation) {
    final entry = _section('characters')[classId];
    return entry is YamlMap ? entry[animation] as String? : null;
  }

  /// Ruta (relativa a [spritesRoot]) del frame `idle` de un enemigo, o
  /// `null`.
  String? enemyPath(String enemyId) {
    final entry = _section('enemies')[enemyId];
    return entry is YamlMap ? entry['idle'] as String? : null;
  }

  /// Precarga todas las imágenes del manifest (útil antes de entrar a
  /// batalla para no decodificar en el primer frame).
  Future<void> preloadAll() async {
    await Future.wait([
      for (final e in entries)
        if (e.section == 'characters' || e.section == 'enemies')
          _loadImage(e),
    ]);
  }

  /// `Paint` para dibujar pixel art a mano (`canvas.drawImageRect`):
  /// vecino más cercano, sin suavizado.
  static ui.Paint pixelPaint() =>
      ui.Paint()..filterQuality = ui.FilterQuality.none;

  Sprite _pixelSprite(ui.Image image) =>
      Sprite(image)..paint.filterQuality = ui.FilterQuality.none;

  YamlMap _section(String name) => _manifest[name] as YamlMap? ?? YamlMap();

  Future<ui.Image> _loadImage(SpriteEntry e) {
    return _cache.putIfAbsent(e.id, () async {
      try {
        Uint8List? bytes;
        if (hasOverride(e.id)) bytes = await overrides!.read(e.id);
        if (bytes == null) {
          final data = await _bundle.load('$spritesRoot${e.path}');
          bytes =
              data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        }
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        codec.dispose();
        return frame.image;
      } catch (_) {
        _cache.remove(e.id); // no cachear fallos: permite reintentar
        rethrow;
      }
    });
  }
}
