import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../../../../core/fx/fx_catalog.dart';
import '../../../combat/domain/sprite_entry.dart';
import 'sprite_editor_controller.dart';

/// Categoría de la lista de animaciones (game_editor.md § 3.2).
const kFxCategoryLabels = {
  'ult': 'ULT',
  'duo': 'DÚOS',
  'skill': 'HABILIDADES',
  'attack': 'ATAQUES',
  'enemy_ult': 'ULT ENEMIGAS',
  'status': 'ESTADOS',
  'death': 'MUERTES',
  'proc': 'PROCS',
  'map_move': 'MAPA',
  'ui': 'UI',
};

/// Qué key o disparo está elegido: pista, si es disparo, índice.
typedef FxKeyRef = ({int track, bool fire, int index});

/// Estado de Visuales → Animaciones (game_editor.md § 3.2): lista
/// categorizada + buscador, reproducción (play/pausa/scrub/velocidad),
/// edición de parámetros básicos de keyframes con recarga en caliente,
/// guardado como override local, paquete de arte y publicar al repo.
class FxEditorController extends ChangeNotifier {
  FxEditorController({
    required this.catalog,
    this.overrides,
    this.files = const FileSelectorEditorFiles(),
    this.repoPath,
    this.spriteImage,
  });

  final FxCatalog catalog;
  final EditableSpriteOverrides? overrides;
  final EditorFiles files;
  final String? repoPath;

  /// Sprites de prueba de la mini escena (`characters.maga.idle`…).
  final ui.Image? Function(String id)? spriteImage;

  String query = '';
  String? category;
  String? selectedId;

  /// Copia de trabajo del elegido (lo que se reproduce y se guarda).
  FxTimeline? edit;
  bool dirty = false;

  // Reproducción.
  double time = 0;
  bool playing = true;
  bool loop = true;
  double speed = 1;
  bool camera = true;
  int enemies = 3;

  int? selectedTrack;
  FxKeyRef? selectedKey;
  EditorNotice? notice;

  bool get canWrite => overrides != null;
  bool get readOnly => edit?.legacy ?? true;

  List<String> get ids => catalog.ids;

  FxTimeline? timelineOf(String id) => catalog.timeline(id);

  List<String> get visible {
    final q = query.trim().toLowerCase();
    return [
      for (final id in ids)
        if (timelineOf(id) case final t?)
          if ((category == null || t.category == category) &&
              (q.isEmpty ||
                  id.toLowerCase().contains(q) ||
                  t.name.toLowerCase().contains(q) ||
                  t.tags.any((g) => g.toLowerCase().contains(q))))
            id,
    ];
  }

  int countOf(String? cat) => cat == null
      ? ids.length
      : ids.where((id) => timelineOf(id)?.category == cat).length;

  int get overrideCount => ids.where(catalog.hasOverride).length;

  void setQuery(String q) {
    query = q;
    notifyListeners();
  }

  void setCategory(String? c) {
    category = c;
    notifyListeners();
  }

  void clearNotice() {
    notice = null;
    notifyListeners();
  }

  void select(String id) {
    if (dirty && selectedId != null) catalog.clearLive(selectedId!);
    selectedId = id;
    edit = catalog.timeline(id);
    dirty = false;
    time = 0;
    selectedTrack = null;
    selectedKey = null;
    notifyListeners();
  }

  // ------------------------------------------------------------ reproducción

  double get duration => (edit?.duration ?? 0).toDouble();

  void togglePlay() {
    playing = !playing;
    notifyListeners();
  }

  void setSpeed(double s) {
    speed = s;
    notifyListeners();
  }

  void setLoop(bool v) {
    loop = v;
    notifyListeners();
  }

  void setCamera(bool v) {
    camera = v;
    notifyListeners();
  }

  void setEnemies(int n) {
    enemies = n.clamp(1, 4);
    notifyListeners();
  }

  /// Scrub: lleva el cabezal a [ms] (pausa).
  void seek(double ms) {
    time = ms.clamp(0, duration);
    playing = false;
    notifyListeners();
  }

  /// Avanza el reloj [dtMs] ms reales (con la velocidad).
  void advance(double dtMs) {
    if (!playing || edit == null) return;
    var t = time + dtMs * speed;
    if (t > duration + 400) {
      // Pausa corta al final antes de volver a empezar.
      if (loop) {
        t = 0;
      } else {
        t = duration;
        playing = false;
      }
    }
    time = t;
    notifyListeners();
  }

  // ------------------------------------------------------------ edición

  void selectTrack(int? i) {
    selectedTrack = i;
    selectedKey = null;
    notifyListeners();
  }

  void selectKey(FxKeyRef? k) {
    selectedKey = k;
    if (k != null) selectedTrack = k.track;
    notifyListeners();
  }

  FxKey? keyOf(FxKeyRef r) {
    final t = edit;
    if (t == null || r.track >= t.tracks.length) return null;
    final l = r.fire ? t.tracks[r.track].fires : t.tracks[r.track].keys;
    return r.index < l.length ? l[r.index] : null;
  }

  void _apply(FxTimeline t) {
    edit = t;
    dirty = true;
    catalog.setLive(t.id, t);
    notifyListeners();
  }

  /// Cambia la duración total (ms, ≤ tope del formato).
  void setDuration(int ms) {
    final t = edit;
    if (t == null || readOnly) return;
    final d = ms.clamp(100, kFxMaxDurationMs);
    final build = math.min(t.phases.build, d);
    final release = math.min(t.phases.release, d - build);
    _apply(t.copyWith(
        duration: d, phases: FxPhases(build, release, d - build - release)));
  }

  /// Cambia el tiempo (ms) del key [r]; la lista se reordena y la
  /// selección sigue al key.
  void setKeyTime(FxKeyRef r, int ms) => _setKey(r, (k) => k.copyWith(t: ms));

  /// Cambia el campo numérico [field] del key [r].
  void setKeyField(FxKeyRef r, String field, num v) =>
      _setKey(r, (k) => k.withField(field, v));

  void _setKey(FxKeyRef r, FxKey Function(FxKey) f) {
    final t = edit;
    final k = keyOf(r);
    if (t == null || k == null || readOnly) return;
    final tr = t.tracks[r.track];
    final list = [...(r.fire ? tr.fires : tr.keys)];
    final nk = f(k);
    list[r.index] = FxKey(nk.t.clamp(0, t.duration), nk.data, nk.ease);
    final ntr = r.fire ? tr.copyWith(fires: list) : tr.copyWith(keys: list);
    _apply(t.withTrack(r.track, ntr));
    final l = r.fire ? ntr.fires : ntr.keys;
    selectedKey = (
      track: r.track,
      fire: r.fire,
      index: math.max(0, l.indexWhere((x) => identical(x, list[r.index])))
    );
  }

  /// Avisos de validación de la copia de trabajo (§ 3.2).
  List<String> get validation {
    final t = edit;
    if (t == null) return const [];
    return [
      for (final w in t.warnings) w,
      if (t.category == 'ult' && t.duration > kUltMaxDurationMs)
        'La ULT dura ${t.duration} ms (tope $kUltMaxDurationMs).',
      for (final i in t.impacts)
        if (i.t > t.duration) 'Impacto en ${i.t} ms, después del final.',
      if (t.impacts.isEmpty && const {'ult', 'duo'}.contains(t.category))
        'Sin pista impact: los números caen al empezar la descarga.',
    ];
  }

  /// Guarda la copia de trabajo como override local (§ 4.2).
  Future<void> save() async {
    final t = edit;
    if (t == null || overrides == null || readOnly) return;
    await overrides!.putFx(t.id, t.toYaml());
    await catalog.reload(t.id);
    edit = catalog.timeline(t.id);
    dirty = false;
    notice = EditorNotice('Override guardado: ${t.id}', ok: true);
    notifyListeners();
  }

  /// Descarta la edición sin guardar (vuelve a lo guardado).
  void revert() {
    final id = selectedId;
    if (id == null) return;
    catalog.clearLive(id);
    edit = catalog.timeline(id);
    dirty = false;
    notifyListeners();
  }

  /// Borra el override local (vuelve el asset del repo).
  Future<void> discardOverride() async {
    final id = selectedId;
    if (id == null || overrides == null) return;
    await overrides!.removeFx(id);
    await catalog.reload(id);
    edit = catalog.timeline(id);
    dirty = false;
    notice = EditorNotice('Override descartado: $id');
    notifyListeners();
  }

  Future<void> reloadAll() async {
    await catalog.reload();
    if (selectedId != null) edit = catalog.timeline(selectedId!);
    dirty = false;
    notice = const EditorNotice('Animaciones recargadas.');
    notifyListeners();
  }

  Future<void> exportPack() async {
    final o = overrides;
    if (o == null) return;
    await o.refreshFx();
    final n = o.overriddenIds.length + o.overriddenFx.length;
    if (n == 0) {
      notice = const EditorNotice('No hay overrides para exportar.', error: true);
    } else if (await files.saveZip(await o.exportPack(), 'paquete_de_arte.zip')) {
      notice = EditorNotice(
          'Paquete exportado (${o.overriddenIds.length} sprites, '
          '${o.overriddenFx.length} animaciones).',
          ok: true);
    }
    notifyListeners();
  }

  Future<void> importPack() async {
    final o = overrides;
    if (o == null) return;
    final zip = await files.pickZip();
    if (zip == null) return;
    try {
      final got = await o.importPack(zip);
      await catalog.reload();
      if (selectedId != null) edit = catalog.timeline(selectedId!);
      dirty = false;
      notice = EditorNotice('Paquete importado (${got.length} archivos).', ok: true);
    } on FormatException catch (e) {
      notice = EditorNotice(e.message, error: true);
    }
    notifyListeners();
  }

  /// Overrides de fx a publicar: id → ruta dentro de `assets/fx/`.
  Map<String, String> get publishable => {
        for (final id in ids)
          if (catalog.hasOverride(id))
            id: catalog.paths[id] ??
                '${catalog.timeline(id)?.category ?? 'ult'}/$id.fx.yaml',
      };

  Future<void> publish() async {
    final repo = repoPath;
    if (overrides == null || repo == null) {
      notice = const EditorNotice('No hay repo detectado.', error: true);
      notifyListeners();
      return;
    }
    try {
      final done = await overrides!.publishFx(repo, publishable);
      await catalog.reload();
      if (selectedId != null) edit = catalog.timeline(selectedId!);
      notice = EditorNotice(
          'Publicado al repo: ${done.length} animaciones (falta commit; '
          'carpetas nuevas van en pubspec.yaml).',
          ok: true);
    } catch (e) {
      notice = EditorNotice('$e', error: true);
    }
    notifyListeners();
  }
}
