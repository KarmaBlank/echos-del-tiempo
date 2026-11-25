// Weapon icons by material (docs/specs/profession_gear_v2.md § 6): the
// same single shape per type; only the colours of the head (metal) and
// grip (handle) change. Pure Dart: the painter, the export tool and the
// pixel tests share it.

import '../../game_engine/data/gear_v2_catalog.dart';
import '../../game_engine/models/elements.dart';
import '../../game_engine/models/item.dart';
import '../../game_engine/rules/gear_v2_rules.dart' show GearV2Rules;

/// Default metal and handle colours of the item icons (the `item_icon`
/// knobs; tool/export_item_icons.dart).
const kDefaultMetal = 0xc8d2ff;
const kDefaultHandle = 0xa0703c;

/// Grey of tone `i` in a `_head` / `_grip` layer (shade, base, light,
/// shine).
const kLayerGreys = [0x40, 0x80, 0xc0, 0xff];

int _mix(int a, int b, double t) {
  int ch(int s) =>
      (((a >> s) & 0xff) * (1 - t) + ((b >> s) & 0xff) * t).round() & 0xff;
  return (ch(16) << 16) | (ch(8) << 8) | ch(0);
}

/// The 4 tones (shade, base, light, shine) of colour [c], shaded exactly
/// like tool/export_item_icons.dart.
List<int> rampOf(int c) => [
      _mix(c, 0x000000, 0.35),
      c,
      _mix(c, 0xffffff, 0.4),
      _mix(c, 0xffffff, 0.55),
    ];

/// Tone index of [grey] in a layer (`null` = not in the layer).
int? toneOfGrey(int grey) {
  for (var i = 0; i < kLayerGreys.length; i++) {
    if ((grey - kLayerGreys[i]).abs() <= 0x10) return i;
  }
  return null;
}

/// Colour of each element (scale / living head tint).
const kAffinityColor = <GameElement, int>{
  GameElement.fisico: 0xb8c0d0,
  GameElement.fuego: 0xe0704a,
  GameElement.hielo: 0x9fd8f5,
  GameElement.veneno: 0x7bc86a,
  GameElement.sagrado: 0xf0e0a0,
  GameElement.agua: 0x4aa3e8,
  GameElement.electro: 0xb08ef0,
};

/// Base colour of each ingot.
const kIngotColor = <String, int>{
  'ingot_copper': 0xd08a50,
  'ingot_bronze': 0xc8a860,
  'ingot_frost': 0xa8d8f0,
  'ingot_ember': 0xe0704a,
  'ingot_echo': 0xe8e0ff,
};

const _bone = 0xe8e0c8;
const _livingWood = 0x6f8f3e;

/// Base colour of a head / grip material id (`null` = default).
int? materialColor(String id) {
  if (kIngotColor[id] case final c?) return c;
  if (parseFishPart(id) case (final sp, final part)?) {
    return part == FishPart.bone ? _bone : kAffinityColor[fishAffinity(sp)];
  }
  if (id == 'living') return _livingWood;
  if (id.startsWith('living_')) {
    final e = GameElement.values.asNameMap()[id.substring(7)];
    return e == null ? null : kAffinityColor[e];
  }
  return null;
}

/// (head, grip) material ids of [i]'s parts (`null` = default colours).
(String?, String?) partMaterials(ItemInstance i) {
  final pt = i.parts;
  if (pt.isEmpty || pt.first == 'v1') return (null, null);
  if (pt.first == 'living') {
    return ('living_${GearV2Rules.partsAffinity(pt).name}', 'living');
  }
  if (pt.first == 'fish' && pt.length > 1) {
    return (
      fishPartId(pt[1], FishPart.scale),
      fishPartId(pt[1], FishPart.bone)
    );
  }
  return (pt.length > 1 ? pt[1] : null, pt.length > 2 ? pt[2] : null);
}

/// Recolours [base] (RGBA, w × h) in place: every pixel of the [head] /
/// [grip] layers (RGBA greys) takes the tone of [headRamp] / [gripRamp].
/// A `null` ramp leaves that region as it is.
void recolor(List<int> base, List<int>? head, List<int>? grip,
    List<int>? headRamp, List<int>? gripRamp) {
  void apply(List<int>? layer, List<int>? ramp) {
    if (layer == null || ramp == null) return;
    for (var o = 0; o + 3 < layer.length && o + 3 < base.length; o += 4) {
      if (layer[o + 3] == 0) continue;
      final t = toneOfGrey(layer[o]);
      if (t == null) continue;
      final c = ramp[t];
      base[o] = (c >> 16) & 0xff;
      base[o + 1] = (c >> 8) & 0xff;
      base[o + 2] = c & 0xff;
    }
  }

  apply(head, headRamp);
  apply(grip, gripRamp);
}

/// Splits an icon PNG's pixels into (head, grip) layers: a pixel goes to
/// a layer when it matches one of the 4 default tones of that region.
(List<int>, List<int>) splitLayers(List<int> rgba) {
  final metal = rampOf(kDefaultMetal), handle = rampOf(kDefaultHandle);
  final head = List<int>.filled(rgba.length, 0);
  final grip = List<int>.filled(rgba.length, 0);
  for (var o = 0; o + 3 < rgba.length; o += 4) {
    if (rgba[o + 3] == 0) continue;
    final c = (rgba[o] << 16) | (rgba[o + 1] << 8) | rgba[o + 2];
    for (final (ramp, layer) in [(metal, head), (handle, grip)]) {
      final t = ramp.indexOf(c);
      if (t < 0) continue;
      final g = kLayerGreys[t];
      layer
        ..[o] = g
        ..[o + 1] = g
        ..[o + 2] = g
        ..[o + 3] = 0xff;
      break;
    }
  }
  return (head, grip);
}
