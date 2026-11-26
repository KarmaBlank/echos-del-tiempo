import 'dart:ui';

import '../../../../game_engine/rules/world_zoom_rules.dart';

/// How the world picture is rasterized and placed on screen for one
/// frame (exploration.md § Cámara, "Zoom del mundo").
///
/// The world is recorded in virtual px (480 × 288 at level 0) with
/// `scale(1 / zoom)`; the picture is then rasterized at [imageScale]
/// image px per virtual px into an [imageW] × [imageH] image, drawn
/// with nearest filtering into [dst] and clipped to [clip]. At a
/// non-zero level `imageScale == zoom`, so ONE world px is ONE image px
/// and [pixelScale] (an integer) screen px: no fractional world zoom.
class WorldFrame {
  const WorldFrame({
    required this.dst,
    required this.clip,
    required this.zoom,
    required this.imageScale,
    this.imageW = 480,
    this.imageH = 288,
    this.pixelScale,
  });

  /// Level [level] for the virtual canvas [virtual] shown in [view].
  /// Level 0 keeps the classic path (the virtual canvas scaled to
  /// [view], whole factor with PIXEL PERFECT).
  factory WorldFrame.of(Rect view, Size virtual, int level) {
    final vw = virtual.width.round(), vh = virtual.height.round();
    if (level == 0 || view.width <= 0 || view.height <= 0) {
      return WorldFrame(
          dst: view,
          clip: view,
          zoom: 1,
          imageScale: 1,
          imageW: vw,
          imageH: vh);
    }
    final p = WorldZoomRules.pixelScale(view.width / virtual.width, level);
    final iw = (view.width / p).ceil();
    final k = iw / virtual.width;
    var ih = (view.height / p).ceil();
    final content = (virtual.height * k).ceil();
    if (content > ih) ih = content;
    final w = (iw * p).toDouble(), h = (ih * p).toDouble();
    final left = view.left + ((view.width - w) / 2).floorToDouble();
    final top = view.top + ((view.height - h) / 2).floorToDouble();
    return WorldFrame(
        dst: Rect.fromLTWH(left, top, w, h),
        clip: view,
        zoom: k,
        imageScale: k,
        imageW: iw,
        imageH: ih,
        pixelScale: p);
  }

  /// Where the image goes on screen (may overhang [clip] by < 1 world px).
  final Rect dst;

  /// The map area on screen.
  final Rect clip;

  /// World px per virtual px (`< 1` = closer).
  final double zoom;

  /// Image px per virtual px.
  final double imageScale;
  final int imageW, imageH;

  /// Whole screen px per world px (null at level 0 and in the editor).
  final int? pixelScale;

  /// A world point [w] on screen for the drawn camera ([camX], [camY]).
  Offset toScreen(Offset w, double camX, double camY) {
    final k = dst.width / imageW * imageScale / zoom;
    return Offset(dst.left + (w.dx - camX) * k, dst.top + (w.dy - camY) * k);
  }
}
