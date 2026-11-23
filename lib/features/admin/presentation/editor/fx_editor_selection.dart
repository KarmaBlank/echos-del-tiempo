import 'dart:ui';

import '../../../../core/fx/fx_catalog.dart';
import '../../../combat/presentation/scene/fx_player.dart';

/// What the animation editor shows as "the thing being animated"
/// (game_editor.md § 7.7): readable labels for tracks and fields, one
/// timeline row per element and property, the before/after values of a
/// key and the selection box on the preview canvas.

/// Element name per track type (UI text).
const kFxTrackLabels = <String, String>{
  'camera': 'Cámara',
  'dim': 'Oscurecido',
  'letterbox': 'Barras de cine',
  'title_card': 'Tarjeta',
  'actor': 'Actor',
  'echo': 'Ecos',
  'sprite': 'Sprite',
  'particles': 'Partículas',
  'trail': 'Estela',
  'shape': 'Forma',
  'shake': 'Sacudida',
  'flash': 'Destello',
  'tint': 'Tinte',
  'hitstop': 'Congelado',
  'impact': 'Impacto',
  'sound': 'Sonido',
  'prim': 'Primitiva',
  'legacy': 'Código',
};

/// Property name per key field (UI text).
const kFxFieldLabels = <String, String>{
  'v': 'Valor',
  'alpha': 'Opacidad',
  'scale': 'Escala',
  'dx': 'Posición X',
  'dy': 'Posición Y',
  'angle': 'Rotación',
  'count': 'Cantidad',
  'color': 'Color',
  'anchor': 'Ancla',
  'at': 'Ancla',
  'from': 'Desde',
  'to': 'Hasta',
  'focus': 'Foco',
  'zoom': 'Zoom',
  'shape': 'Forma',
  'preset': 'Tipo',
  'amp': 'Amplitud',
  'ms': 'Duración',
  'lag': 'Retraso',
  'fade': 'Desvanecido',
  'head': 'Cabeza',
  'cue': 'Sonido',
  'vol': 'Volumen',
  'pitch': 'Tono',
  'width': 'Ancho',
  'spacing': 'Separación',
  'who': 'Quién',
  'kind': 'Clase',
  'element': 'Elemento',
  'echoes': 'Ecos',
};

String fxTrackLabel(String type) => kFxTrackLabels[type] ?? type;
String fxFieldLabel(String field) => kFxFieldLabels[field] ?? field;

/// One timeline row: a track and, for keyframe tracks, one property.
/// [field] is null for the row of fires (one-shot events).
typedef FxRow = ({int track, String? field});

/// Rows of [t]: one per (track, keyed field) in order of first
/// appearance; tracks with fires (or nothing keyed) get one row.
List<FxRow> fxRowsOf(FxTimeline t) => [
      for (var i = 0; i < t.tracks.length; i++) ...() {
        final tr = t.tracks[i];
        final fields = <String>{
          for (final k in tr.keys) ...k.data.keys,
        };
        return [
          for (final f in fields) (track: i, field: f),
          if (tr.fires.isNotEmpty || fields.isEmpty) (track: i, field: null),
        ];
      }(),
    ];

/// "Sprite · Escala", "Partículas · Disparos".
String fxRowLabel(FxTimeline t, FxRow r) =>
    '${fxTrackLabel(t.tracks[r.track].type)} · '
    '${r.field == null ? 'Disparos' : fxFieldLabel(r.field!)}';

/// Whether key [k] appears as a marker on row [r].
bool fxRowShows(FxRow r, FxKey k, {required bool fire}) =>
    r.field == null ? fire : !fire && k.data.containsKey(r.field);

/// Seconds with two decimals, as the editor shows times ("0.40 s").
String fxSeconds(num ms) => '${(ms / 1000).toStringAsFixed(2)} s';

/// "Key en 0.40 s · Sprite · Escala" (or "Disparo en …").
String fxKeyPlaceLabel(FxTimeline t, ({int track, bool fire, int index}) r,
    {String? field}) {
  final tr = t.tracks[r.track];
  final list = r.fire ? tr.fires : tr.keys;
  final k = list[r.index];
  final what = field != null
      ? fxFieldLabel(field)
      : r.fire
          ? 'Disparos'
          : k.data.keys.map(fxFieldLabel).take(3).join(', ');
  return '${r.fire ? 'Disparo' : 'Key'} en ${fxSeconds(k.t)} · '
      '${fxTrackLabel(tr.type)}${what.isEmpty ? '' : ' · $what'}';
}

/// One property of the selected key in the inspector.
class FxFieldChange {
  const FxFieldChange(this.field, this.before, this.after, {required this.keyed});
  final String field;

  /// Value at the previous key of the same list (null: none / unset).
  final Object? before;

  /// Value at this key (null: not keyed here, holds the previous one).
  final Object? after;

  /// This key sets the field.
  final bool keyed;

  /// The key changes the value with respect to the previous key.
  bool get changed => keyed && before != after;
}

/// Before/after of every field the key [r] or its previous key touch.
List<FxFieldChange> fxKeyChanges(
    FxTimeline t, ({int track, bool fire, int index}) r) {
  final tr = t.tracks[r.track];
  final list = [...(r.fire ? tr.fires : tr.keys)];
  final k = list[r.index];
  FxKey? prev;
  for (final o in list) {
    if (!identical(o, k) && o.t <= k.t && (prev == null || o.t >= prev.t)) {
      prev = o;
    }
  }
  final fields = <String>{...k.data.keys, ...?prev?.data.keys};
  return [
    for (final f in fields)
      FxFieldChange(f, prev?.data[f], k.data[f], keyed: k.data.containsKey(f)),
  ];
}

/// Times of the keys right before and after [ms] on track [track] (for
/// the onion skin).
(int?, int?) fxNeighborKeys(FxTimeline t, int track, double ms) {
  final tr = t.tracks[track];
  int? before, after;
  for (final k in [...tr.keys, ...tr.fires]) {
    if (k.t < ms - 0.5 && (before == null || k.t > before)) before = k.t;
    if (k.t > ms + 0.5 && (after == null || k.t < after)) after = k.t;
  }
  return (before, after);
}

/// Tracks that act on the whole frame (no place in the world).
const kFxScreenTracks = {
  'camera', 'dim', 'letterbox', 'title_card', 'flash', 'tint', 'shake',
  'hitstop', 'sound', 'legacy',
};

/// Where the selected element is on the preview, in world units.
class FxSelectionBox {
  const FxSelectionBox(this.rect,
      {required this.screen, required this.canMove, required this.canScale});
  final Rect rect;

  /// Acts on the whole frame: the box frames the scene.
  final bool screen;

  /// The key has `dx`/`dy` (move handle) or `scale` (corner handles).
  final bool canMove, canScale;
}

/// Base side of the box of a placed element (world px) at scale 1.
const kFxSelectionBase = 28.0;

/// Selection box of track [track] at [ms] on stage [st]; [world] is the
/// visible world (used by whole-frame tracks).
FxSelectionBox fxSelectionBox(
    FxTimeline t, int track, double ms, FxStage st, Rect world,
    {FxKey? key}) {
  final tr = t.tracks[track];
  final fields = <String>{
    for (final k in [...tr.keys, ...tr.fires]) ...k.data.keys,
  };
  final canMove = fields.contains('dx') || fields.contains('dy');
  final canScale = fields.contains('scale');
  if (kFxScreenTracks.contains(tr.type)) {
    return FxSelectionBox(world.deflate(2),
        screen: true, canMove: false, canScale: false);
  }
  // A fire has no interpolation: use the selected (or latest) one.
  FxKey? fire = key;
  if (fire == null && tr.fires.isNotEmpty) {
    for (final f in tr.fires) {
      if (f.t <= ms || fire == null) fire = f;
    }
  }
  String? text(String f) => fire?.s(f) ?? tr.textAt(f, ms) ?? tr.s(f);
  double num(String f, double d) =>
      fire?.n(f)?.toDouble() ?? tr.numAt(f, ms) ?? tr.n(f)?.toDouble() ?? d;
  final anchorName = text('anchor') ??
      text('at') ??
      text('to') ??
      (tr.type == 'echo' ? 'caster' : 'target');
  final feet = st.anchor(anchorName);
  final side = (kFxSelectionBase * num('scale', 1)).clamp(8.0, 200.0);
  final c = feet.translate(num('dx', 0), num('dy', 0) - side / 2);
  return FxSelectionBox(Rect.fromCenter(center: c, width: side, height: side),
      screen: false, canMove: canMove, canScale: canScale);
}
