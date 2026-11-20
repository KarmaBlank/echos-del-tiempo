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

/// Opciones de los campos de texto que el editor ofrece como botones
/// (game_editor.md § 7.2: anclas, colores por rol, formas, partículas).
const kFxFieldOptions = <String, List<String>>{
  'anchor': _anchors,
  'at': _anchors,
  'from': _anchors,
  'to': _anchors,
  'focus': ['caster', 'target', 'line', 'targets', 'allies', 'group'],
  'color': ['element', 'echo', 'light', 'dark', 'white', 'gold', 'action'],
  'shape': [
    'gather', 'slash_arc', 'slash_cross', 'ring', 'rune_circle', 'shockwave',
    'quake', 'pillar', 'beam', 'shield_dome', 'sky_crack', 'bolt', 'clock',
    'cross', 'rain', 'shards', 'reticle',
  ],
  'preset': [
    'burst', 'sparks', 'shards', 'sparkles', 'embers', 'dust', 'debris', 'frost',
  ],
  'head': ['dot', 'arrow', 'spear', 'hammer', 'meteor', 'bolt'],
};

const _anchors = [
  'caster', 'partner', 'target', 'targets_center', 'allies_center', 'sky',
  'sky_center', 'sky_caster', 'screen',
];

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
    _clearHistory();
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

  // ------------------------------------------------ deshacer / rehacer

  final _undo = <FxTimeline>[];
  final _redo = <FxTimeline>[];
  static const _maxUndo = 200;

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  /// Imán: los tiempos se redondean a 10 ms y se pegan a otros keys a
  /// menos de [snapMs] (game_editor.md § 3.2).
  bool snap = true;
  static const snapMs = 25;

  void setSnap(bool v) {
    snap = v;
    notifyListeners();
  }

  /// [record] = `false` en un arrastre (la foto se toma al empezar).
  void _apply(FxTimeline t, {bool record = true}) {
    final prev = edit;
    if (record && prev != null) {
      _undo.add(prev);
      if (_undo.length > _maxUndo) _undo.removeAt(0);
      _redo.clear();
    }
    edit = t;
    dirty = true;
    catalog.setLive(t.id, t);
    notifyListeners();
  }

  void _restore(FxTimeline t) {
    edit = t;
    dirty = true;
    catalog.setLive(t.id, t);
    if (selectedKey case final r? when keyOf(r) == null) selectedKey = null;
    if ((selectedTrack ?? 0) >= t.tracks.length) selectedTrack = null;
    notifyListeners();
  }

  void undo() {
    final cur = edit;
    if (_undo.isEmpty || cur == null || readOnly) return;
    _redo.add(cur);
    _restore(_undo.removeLast());
  }

  void redo() {
    final cur = edit;
    if (_redo.isEmpty || cur == null || readOnly) return;
    _undo.add(cur);
    _restore(_redo.removeLast());
  }

  void _clearHistory() {
    _undo.clear();
    _redo.clear();
    _dragging = null;
  }

  // ------------------------------------------------ edición visual (paso 3)

  /// Pistas que se editan con disparos (eventos puntuales) y no keys.
  static const fireTracks = {
    'particles',
    'shape',
    'trail',
    'shake',
    'flash',
    'hitstop',
    'impact',
    'sound',
    'prim',
  };

  /// Tipos que ofrece NUEVA PISTA, en orden.
  static const newTrackTypes = [
    'echo',
    'shape',
    'particles',
    'trail',
    'flash',
    'shake',
    'hitstop',
    'impact',
    'dim',
    'letterbox',
    'tint',
    'camera',
    'title_card',
    'sound',
    'prim',
  ];

  /// [ms] con el imán aplicado (10 ms y otros keys/disparos, menos [self]).
  int snapTime(double ms, {FxKeyRef? self}) {
    final t = edit;
    final d = t?.duration ?? 0;
    final raw = ms.round().clamp(0, d);
    if (!snap || t == null) return raw;
    var best = snapMs + 1.0;
    var out = raw;
    for (var i = 0; i < t.tracks.length; i++) {
      final tr = t.tracks[i];
      for (final (fire, list) in [(false, tr.keys), (true, tr.fires)]) {
        for (var k = 0; k < list.length; k++) {
          if (self == (track: i, fire: fire, index: k)) continue;
          final dd = (list[k].t - ms).abs();
          if (dd < best) {
            best = dd;
            out = list[k].t;
          }
        }
      }
    }
    if (best > snapMs) out = ((ms / 10).round() * 10).clamp(0, d);
    return out;
  }

  FxKeyRef? _dragging;

  /// Empieza a arrastrar el key [r] (una sola entrada de deshacer).
  void beginDrag(FxKeyRef r) {
    final t = edit;
    if (t == null || readOnly || keyOf(r) == null) return;
    _undo.add(t);
    _redo.clear();
    _dragging = r;
    selectKey(r);
  }

  /// Mueve el key arrastrado a [ms] (con imán).
  void dragTo(double ms) {
    final r = _dragging;
    if (r == null) return;
    _setKey(r, (k) => k.copyWith(t: snapTime(ms, self: r)), record: false);
    _dragging = selectedKey;
  }

  void endDrag() => _dragging = null;
  bool get dragging => _dragging != null;

  /// Agrega un key (o disparo) a la pista [track] en [ms]: copia los
  /// valores del key anterior (o una plantilla del tipo) y lo elige.
  void addKey(int track, double ms) {
    final t = edit;
    if (t == null || readOnly || track >= t.tracks.length) return;
    final tr = t.tracks[track];
    final fire = tr.fires.isNotEmpty ||
        (tr.keys.isEmpty && fireTracks.contains(tr.type));
    final at = snapTime(ms);
    final list = fire ? tr.fires : tr.keys;
    FxKey? prev;
    for (final k in list) {
      if (k.t <= at) prev = k;
    }
    prev ??= list.isEmpty ? null : list.first;
    final nk =
        FxKey(at, prev?.data ?? _template(tr.type), prev?.ease ?? FxEase.smooth);
    final nl = [...list, nk];
    final ntr = fire ? tr.copyWith(fires: nl) : tr.copyWith(keys: nl);
    _apply(t.withTrack(track, ntr));
    final l = fire ? ntr.fires : ntr.keys;
    selectedTrack = track;
    selectedKey =
        (track: track, fire: fire, index: l.indexWhere((x) => identical(x, nk)));
    notifyListeners();
  }

  /// Borra el key [r].
  void removeKey(FxKeyRef r) {
    final t = edit;
    if (t == null || readOnly || keyOf(r) == null) return;
    final tr = t.tracks[r.track];
    final list = [...(r.fire ? tr.fires : tr.keys)]..removeAt(r.index);
    _apply(t.withTrack(
        r.track, r.fire ? tr.copyWith(fires: list) : tr.copyWith(keys: list)));
    selectedKey = null;
    selectedTrack = r.track;
    notifyListeners();
  }

  /// Curva de llegada del key [r].
  void setKeyEase(FxKeyRef r, FxEase e) =>
      _setKey(r, (k) => k.copyWith(ease: e));

  /// Cambia un campo de texto (ancla, forma, color por rol…) del key [r].
  void setKeyText(FxKeyRef r, String field, String v) =>
      _setKey(r, (k) => k.withField(field, v.isEmpty ? null : v));

  /// Duplica la pista [i] (queda justo debajo y elegida).
  void duplicateTrack(int i) {
    final t = edit;
    if (t == null || readOnly || i >= t.tracks.length) return;
    final tr = t.tracks[i];
    _apply(t.copyWith(tracks: [...t.tracks]..insert(i + 1, tr.copyWith())));
    selectTrack(i + 1);
  }

  /// Borra la pista [i].
  void removeTrack(int i) {
    final t = edit;
    if (t == null || readOnly || i >= t.tracks.length) return;
    _apply(t.copyWith(tracks: [...t.tracks]..removeAt(i)));
    selectTrack(null);
  }

  /// Agrega una pista nueva de [type] con un key de ejemplo.
  void addTrack(String type) {
    final t = edit;
    if (t == null || readOnly) return;
    final tr = type == 'echo' ? echoLayerFor(t) : _newTrack(type, t);
    _apply(t.copyWith(tracks: [...t.tracks, tr]));
    selectTrack(t.tracks.length);
  }

  /// Capa de ecos (la firma de las ULT, § 5.1).
  void addEchoLayer() => addTrack('echo');

  /// Capa de ecos por defecto: copias del lanzador que van al objetivo
  /// justo antes del primer impacto.
  static FxTrack echoLayerFor(FxTimeline t) {
    final imp = t.impacts.isEmpty ? t.phases.build + 200 : t.impacts.first.t;
    final from = math.max(0, imp - 400);
    return FxTrack('echo', props: const {
      'who': 'caster',
      'count': 3,
      'lag': 90,
      'alpha': 0.5,
      'color': 'echo',
      'fade': 160,
    }, keys: [
      FxKey(from, const {'at': 'caster'}),
      FxKey(math.max(from + 10, imp - 120), const {'at': 'target', 'dx': -14},
          FxEase.easeOut),
      FxKey(math.max(from + 20, imp), const {'at': 'target', 'dx': -14}),
    ]);
  }

  static FxTrack _newTrack(String type, FxTimeline t) {
    final mid = t.impacts.isEmpty ? t.duration ~/ 2 : t.impacts.first.t;
    return switch (type) {
      'dim' || 'letterbox' || 'tint' => FxTrack(type, keys: [
          FxKey(0, const {'v': 0}),
          FxKey(200, {'v': type == 'letterbox' ? 0.09 : 0.6}),
          FxKey(t.duration, const {'v': 0}),
        ]),
      'camera' => FxTrack(type, keys: [
          FxKey(0, const {'focus': 'caster'}),
          FxKey(t.phases.build, const {'focus': 'target'}),
        ]),
      'title_card' =>
        FxTrack(type, props: {'at': 80, 'until': t.phases.build}),
      _ when fireTracks.contains(type) =>
        FxTrack(type, fires: [FxKey(mid, _template(type))]),
      _ => FxTrack(type, keys: [FxKey(0, _template(type))]),
    };
  }

  static Map<String, Object?> _template(String type) => switch (type) {
        'shape' => const {
            'shape': 'ring',
            'anchor': 'target',
            'color': 'element',
            'ms': 300
          },
        'particles' => const {
            'preset': 'burst',
            'anchor': 'target',
            'element': 'auto',
            'count': 1
          },
        'trail' => const {
            'from': 'caster',
            'to': 'target',
            'ms': 250,
            'head': 'dot'
          },
        'flash' => const {'color': 'white', 'alpha': 0.5, 'ms': 150},
        'shake' => const {'amp': 4},
        'hitstop' => const {'ms': 80},
        'impact' => const {'stagger': 0},
        'sound' => const {'cue': 'impact'},
        'prim' => const {'kind': 'ring', 'at': 'target', 'color': 'action'},
        'dim' || 'letterbox' || 'tint' => const {'v': 0.5},
        'camera' => const {'focus': 'target'},
        _ => const {},
      };

  /// Convierte una animación del código (legacy) en datos editables: las
  /// pistas de tiempos quedan; la pista `legacy` se cambia por una capa de
  /// ecos, un anillo y partículas en el impacto (punto de partida).
  void convertToData() {
    final t = edit;
    if (t == null || !t.legacy) return;
    final base = t.copyWith(
        legacy: false,
        tags: [
          for (final g in t.tags)
            if (g != 'legacy') g
        ],
        tracks: [
          for (final tr in t.tracks)
            if (tr.type != 'legacy') tr
        ]);
    final imp = base.impacts.isEmpty ? base.phases.build : base.impacts.first.t;
    _apply(base.copyWith(tracks: [
      ...base.tracks,
      echoLayerFor(base),
      FxTrack('shape', fires: [
        FxKey(imp, const {
          'shape': 'ring',
          'anchor': 'target',
          'color': 'element',
          'ms': 320,
          'scale': 1.4
        }),
      ]),
      FxTrack('particles', fires: [
        FxKey(imp, const {
          'preset': 'burst',
          'anchor': 'target',
          'element': 'auto',
          'count': 3
        }),
      ]),
    ]));
    notice =
        const EditorNotice('Convertida a datos: GUARDAR crea el override.');
    notifyListeners();
  }

  /// Errores que impiden guardar (tope de la ULT, impactos fuera).
  List<String> get blocking {
    final t = edit;
    if (t == null) return const [];
    return [
      if (t.category == 'ult' && t.duration > kUltMaxDurationMs)
        'La ULT dura ${t.duration} ms (tope $kUltMaxDurationMs).',
      for (final i in t.impacts)
        if (i.t > t.duration) 'Impacto en ${i.t} ms, después del final.',
    ];
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

  void _setKey(FxKeyRef r, FxKey Function(FxKey) f, {bool record = true}) {
    final t = edit;
    final k = keyOf(r);
    if (t == null || k == null || readOnly) return;
    final tr = t.tracks[r.track];
    final list = [...(r.fire ? tr.fires : tr.keys)];
    final nk = f(k);
    list[r.index] = FxKey(nk.t.clamp(0, t.duration), nk.data, nk.ease);
    final ntr = r.fire ? tr.copyWith(fires: list) : tr.copyWith(keys: list);
    final l = r.fire ? ntr.fires : ntr.keys;
    selectedKey = (
      track: r.track,
      fire: r.fire,
      index: math.max(0, l.indexWhere((x) => identical(x, list[r.index])))
    );
    _apply(t.withTrack(r.track, ntr), record: record);
  }

  /// Avisos de validación de la copia de trabajo (§ 3.2).
  List<String> get validation {
    final t = edit;
    if (t == null) return const [];
    return [
      for (final w in t.warnings) w,
      ...blocking,
      for (final tr in t.tracks)
        for (final k in [...tr.keys, ...tr.fires])
          if (k.t > t.duration && tr.type != 'impact')
            '${tr.type}: key en ${k.t} ms, después del final.',
      for (final tr in t.ofType('echo'))
        if (tr.keys.isEmpty) 'Capa de ecos sin camino (agregá keys).',
      if (t.impacts.isEmpty && const {'ult', 'duo'}.contains(t.category))
        'Sin pista impact: los números caen al empezar la descarga.',
    ];
  }

  /// Guarda la copia de trabajo como override local (§ 4.2). No guarda
  /// si hay errores de [blocking] (p. ej. una ULT de más de 2.6 s).
  Future<void> save() async {
    final t = edit;
    if (t == null || overrides == null || readOnly) return;
    final errors = blocking;
    if (errors.isNotEmpty) {
      notice = EditorNotice('No se guardó: ${errors.first}', error: true);
      notifyListeners();
      return;
    }
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
    _clearHistory();
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
          'Publicado al repo: ${done.length} animaciones (falta commit).',
          ok: true);
    } catch (e) {
      notice = EditorNotice('$e', error: true);
    }
    notifyListeners();
  }
}
