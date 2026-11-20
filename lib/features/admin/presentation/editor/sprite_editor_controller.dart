import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/procedural/procedural_art.dart';
import '../../../combat/presentation/sprite_catalog.dart';
import '../../domain/sprites/png_validator.dart';
import 'fx_editor_controller.dart';

/// Diálogos de archivo del área Visuales (inyectable en tests).
abstract class EditorFiles {
  Future<Uint8List?> pickPng();
  Future<Uint8List?> pickZip();

  /// `false` si se canceló.
  Future<bool> saveZip(Uint8List bytes, String suggestedName);
}

/// Diálogos reales (`file_selector`).
class FileSelectorEditorFiles implements EditorFiles {
  const FileSelectorEditorFiles();

  @override
  Future<Uint8List?> pickPng() async {
    final f = await openFile(acceptedTypeGroups: const [
      XTypeGroup(label: 'PNG', extensions: ['png']),
    ]);
    return f?.readAsBytes();
  }

  /// Un sonido WAV u OGG (Animaciones → disparo de sonido, § 7.6).
  Future<Uint8List?> pickAudio() async {
    final f = await openFile(acceptedTypeGroups: const [
      XTypeGroup(label: 'Sonido', extensions: ['wav', 'ogg']),
    ]);
    return f?.readAsBytes();
  }

  @override
  Future<Uint8List?> pickZip() async {
    final f = await openFile(acceptedTypeGroups: const [
      XTypeGroup(label: 'Paquete de arte', extensions: ['zip']),
    ]);
    return f?.readAsBytes();
  }

  @override
  Future<bool> saveZip(Uint8List bytes, String suggestedName) async {
    final loc = await getSaveLocation(suggestedName: suggestedName);
    if (loc == null) return false;
    await XFile.fromData(bytes, mimeType: 'application/zip', name: suggestedName)
        .saveTo(loc.path);
    return true;
  }
}

/// Aviso para el usuario (se muestra con `DsToast`).
class EditorNotice {
  const EditorNotice(this.text, {this.error = false, this.ok = false});
  final String text;
  final bool error;
  final bool ok;
}

/// Estado del área Visuales → Sprites (game_editor.md § 3.1).
class SpriteEditorController extends ChangeNotifier {
  SpriteEditorController({
    required this.catalog,
    this.overrides,
    this.files = const FileSelectorEditorFiles(),
    this.repoPath,
  }) : entries = catalog.entries;

  final SpriteCatalog catalog;
  final EditableSpriteOverrides? overrides;
  final EditorFiles files;
  final String? repoPath;
  final List<SpriteEntry> entries;

  /// Animaciones (paso 2): el paquete de arte y "publicar al repo"
  /// también las llevan. Lo conecta el composition root.
  FxEditorController? fx;

  String query = '';
  SpriteCategory? category;
  bool onlyOverrides = false;
  SpriteEntry? selected;
  int zoom = 4;
  EditorNotice? notice;
  SpriteValidation? validation;

  /// Imágenes decodificadas por id (efectiva: override → asset).
  final images = <String, ui.Image?>{};

  /// Imagen del asset del repo (sin override) del elegido, para comparar.
  ui.Image? assetImage;

  /// Tamaño esperado del elegido (PNG del repo o `size:` del manifest).
  (int, int)? expectedSize;

  bool get canWrite => overrides != null;

  List<SpriteEntry> get visible => [
        for (final e in entries)
          if ((category == null || e.category == category) &&
              (!onlyOverrides || catalog.hasOverride(e.id)) &&
              e.matches(query))
            e,
      ];

  int countOf(SpriteCategory? c) => c == null
      ? entries.length
      : entries.where((e) => e.category == c).length;

  int get overrideCount =>
      entries.where((e) => catalog.hasOverride(e.id)).length;

  void setQuery(String q) {
    query = q;
    notifyListeners();
  }

  void setCategory(SpriteCategory? c) {
    category = c;
    notifyListeners();
  }

  void setOnlyOverrides(bool v) {
    onlyOverrides = v;
    notifyListeners();
  }

  void setZoom(int z) {
    zoom = z;
    notifyListeners();
  }

  void clearNotice() {
    notice = null;
    notifyListeners();
  }

  /// Carga las miniaturas de todo el catálogo (y los actores de prueba de
  /// la escena de contexto).
  Future<void> loadAll() async {
    for (final e in entries) {
      images[e.id] = await catalog.image(e);
    }
    notifyListeners();
  }

  ui.Image? imageOf(String id) => images[id];

  // ------------------------------------- perillas procedurales (§ 7.5)

  ProceduralArt get art => ProceduralArt.instance;

  /// Id de perillas de una entrada (`items.espada`, sin el frame).
  static String procIdOf(SpriteEntry e) => '${e.section}.${e.key}';

  /// El elegido se dibuja en código con un generador con perillas.
  bool get hasKnobs {
    final e = selected;
    return e != null && e.procedural && ProceduralArt.hasKnobs(procIdOf(e));
  }

  List<ProcKnob> get knobs =>
      selected == null ? const [] : kProcKnobs[selected!.section] ?? const [];

  /// `true`: lo que se edita aplica a toda la familia (sección).
  bool procFamily = false;

  /// Perillas del alcance actual (lo guardado + lo editado sin guardar).
  Map<String, Object> procDraft = {};
  bool procDirty = false;

  /// Id del alcance actual: `items.espada` o `items`.
  String? get procScope => selected == null
      ? null
      : procFamily
          ? selected!.section
          : procIdOf(selected!);

  Map<String, Object> _stored(String scope) => {
        ...?(scope.contains('.')
            ? art.override.entries[scope]
            : art.override.families[scope]),
      };

  /// Perillas resueltas del elegido (con el borrador: vista previa).
  ProcParams get procParams => art.resolve(procIdOf(selected!));

  void _resetDraft() {
    final s = procScope;
    procDraft = s == null ? {} : _stored(s);
    procDirty = false;
    art.setDraft(null);
  }

  void setProcFamily(bool v) {
    procFamily = v;
    _resetDraft();
    notifyListeners();
  }

  /// Cambia una perilla: vista previa en tiempo real (sin guardar).
  void setKnob(String key, Object value) {
    final s = procScope;
    if (s == null) return;
    final k = knobs.where((k) => k.key == key).firstOrNull;
    final v = k?.coerce(value);
    if (v == null) return;
    procDraft[key] = v;
    procDirty = true;
    art.setDraft(s, procDraft);
    notifyListeners();
  }

  Future<void> _writeProcedural(ProcDoc doc) async {
    if (doc.isEmpty) {
      await overrides!.removeProcedural();
    } else {
      await overrides!.putProcedural(doc.encode());
    }
    art.setOverride(doc);
  }

  /// GUARDAR: las perillas del alcance quedan en el override local.
  Future<void> saveProc() async {
    final s = procScope;
    if (s == null || overrides == null) return;
    final doc = art.override.copy();
    (s.contains('.') ? doc.entries : doc.families)[s] = {...procDraft};
    await _writeProcedural(doc);
    _resetDraft();
    notice = EditorNotice('Perillas guardadas: $s', ok: true);
    notifyListeners();
  }

  /// DESHACER CAMBIOS: vuelve a lo guardado.
  void revertProc() {
    _resetDraft();
    notifyListeners();
  }

  /// DESCARTAR: borra las perillas del alcance del override.
  Future<void> discardProc() async {
    final s = procScope;
    if (s == null || overrides == null) return;
    final doc = art.override.copy();
    (s.contains('.') ? doc.entries : doc.families).remove(s);
    await _writeProcedural(doc);
    _resetDraft();
    notice = EditorNotice('Perillas descartadas: $s');
    notifyListeners();
  }

  /// El alcance actual tiene perillas en el override.
  bool get procHasOverride {
    final s = procScope;
    return s != null && _stored(s).isNotEmpty;
  }

  Future<void> select(SpriteEntry e) async {
    selected = e;
    validation = null;
    _resetDraft();
    notifyListeners();
    final asset = await catalog.assetBytes(e);
    final info = asset == null ? null : PngInfo.parse(asset);
    expectedSize = info != null ? (info.width, info.height) : e.expectedSize;
    assetImage = asset == null ? null : await _decode(asset);
    images[e.id] = await catalog.image(e);
    notifyListeners();
  }

  /// Valida [png] y, si pasa, lo guarda como override del elegido y
  /// recarga en caliente.
  Future<SpriteValidation?> replace(Uint8List png) async {
    final e = selected;
    if (e == null || overrides == null) return null;
    final img = await _decode(png);
    RgbaPixels? px;
    if (img != null) {
      final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data != null) {
        px = RgbaPixels(img.width, img.height, data.buffer.asUint8List());
      }
    }
    final v = validateSpritePng(png, expected: expectedSize, pixels: px);
    validation = v;
    if (!v.ok) {
      notice = EditorNotice(v.errors.first, error: true);
      notifyListeners();
      return v;
    }
    await overrides!.put(e.id, png);
    await _reload(e);
    notice = EditorNotice(
        v.warnings.isEmpty
            ? 'Override guardado: ${e.id}'
            : 'Guardado con avisos: ${v.warnings.first}',
        ok: v.warnings.isEmpty);
    notifyListeners();
    return v;
  }

  Future<void> pickAndReplace() async {
    final png = await files.pickPng();
    if (png != null) await replace(png);
  }

  Future<void> discard() async {
    final e = selected;
    if (e == null || overrides == null) return;
    await overrides!.remove(e.id);
    validation = null;
    await _reload(e);
    notice = EditorNotice('Override descartado: ${e.id}');
    notifyListeners();
  }

  /// Recarga en caliente todo (botón RECARGAR).
  Future<void> reloadAll() async {
    await catalog.reload();
    await loadAll();
    if (selected != null) await select(selected!);
    notice = const EditorNotice('Arte recargado.');
    notifyListeners();
  }

  Future<void> exportPack() async {
    if (overrides == null) return;
    await overrides!.refreshFx();
    if (overrides!.overriddenIds.isEmpty &&
        overrides!.overriddenFx.isEmpty &&
        art.override.isEmpty) {
      notice = const EditorNotice('No hay overrides para exportar.', error: true);
    } else if (await files.saveZip(
        await overrides!.exportPack(), 'paquete_de_arte.zip')) {
      notice = EditorNotice(
          'Paquete exportado (${overrides!.overriddenIds.length} sprites, '
          '${overrides!.overriddenFx.length} animaciones).',
          ok: true);
    }
    notifyListeners();
  }

  Future<void> importPack() async {
    if (overrides == null) return;
    final zip = await files.pickZip();
    if (zip == null) return;
    try {
      final ids = await overrides!.importPack(zip);
      await catalog.reload();
      _resetDraft();
      await loadAll();
      if (selected != null) await select(selected!);
      await fx?.catalog.reload();
      notice = EditorNotice('Paquete importado (${ids.length} archivos).', ok: true);
    } on FormatException catch (e) {
      notice = EditorNotice(e.message, error: true);
    }
    notifyListeners();
  }

  /// Ids que se publicarían al repo.
  List<SpriteEntry> get publishable =>
      [for (final e in entries) if (catalog.hasOverride(e.id)) e];

  /// Hay perillas en el override para publicar.
  bool get procPublishable => !art.override.isEmpty;

  Future<void> publish() async {
    final repo = repoPath;
    if (overrides == null || repo == null) {
      notice = const EditorNotice('No hay repo detectado.', error: true);
      notifyListeners();
      return;
    }
    try {
      final ids = await overrides!.publish(repo, publishable);
      final f = fx;
      final fxIds = f == null
          ? const <String>[]
          : await overrides!.publishFx(repo, f.publishable);
      if (fxIds.isNotEmpty) await f!.catalog.reload();
      final published = art.override;
      final proc = await overrides!.publishProcedural(repo);
      await catalog.reload();
      if (proc) {
        // El repo del Editor es una carpeta, no el bundle: se toma lo
        // publicado como base sin esperar a recompilar.
        art.setRepo(art.repo.merged(published));
      }
      _resetDraft();
      await loadAll();
      notice = EditorNotice(
          'Publicado al repo: ${ids.length} sprites, ${fxIds.length} '
          'animaciones${proc ? ' y perillas' : ''} (falta commit).',
          ok: true);
    } catch (e) {
      notice = EditorNotice('$e', error: true);
    }
    notifyListeners();
  }

  Future<void> _reload(SpriteEntry e) async {
    await catalog.reload(e.id);
    images[e.id] = await catalog.image(e);
  }

  static Future<ui.Image?> _decode(Uint8List png) async {
    try {
      final codec = await ui.instantiateImageCodec(png);
      final frame = await codec.getNextFrame();
      codec.dispose();
      return frame.image;
    } catch (_) {
      return null;
    }
  }
}
