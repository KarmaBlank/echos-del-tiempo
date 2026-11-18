import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'graphics.dart';

/// Parámetros del shader para un nivel (docs/specs/settings.md § 3.2).
@immutable
class CrtParams {
  const CrtParams({
    required this.scan,
    required this.mask,
    required this.bloom,
    required this.vignette,
    required this.curve,
    this.bezel = 0,
  });

  /// [curve]: curvatura de barril (remuestrea la imagen; hoy 0 en todos
  /// los niveles). [bezel]: radio de las esquinas redondeadas del "tubo"
  /// (fracción del lado menor), que oscurece sin mover píxeles.
  final double scan, mask, bloom, vignette, curve, bezel;

  /// `null` = APAGADO.
  static CrtParams? of(CrtLevel level) => switch (level) {
        CrtLevel.off => null,
        CrtLevel.soft => const CrtParams(
            scan: 0.14, mask: 0.05, bloom: 0.15, vignette: 0.15, curve: 0),
        // Sin curvatura: la curva remuestrea toda la UI y la fuente pixel
        // pierde nitidez (columnas duplicadas o salteadas; settings.md §
        // 3.2).
        CrtLevel.normal => const CrtParams(
            scan: 0.24, mask: 0.09, bloom: 0.25, vignette: 0.25, curve: 0),
        // FUERTE (por defecto desde v0.8.2): el look marcado sin
        // remuestrear; la "pantalla curva" la dan las esquinas
        // redondeadas del bisel y la viñeta.
        CrtLevel.strong => const CrtParams(
            scan: 0.38,
            mask: 0.16,
            bloom: 0.40,
            vignette: 0.40,
            curve: 0,
            bezel: 0.035),
      };

  /// Px físicos por scanline para una pantalla de [physicalHeight] px:
  /// ~240 líneas, al menos 2 px (3 px en 720p).
  static double lineFor(double physicalHeight) =>
      math.max(2, (physicalHeight / 240).roundToDouble());

  /// Px físicos por columna de la rejilla RGB.
  static double maskWidthFor(double devicePixelRatio) =>
      math.max(1, devicePixelRatio.roundToDouble());

  /// Los uniformes después de `uSize` (mismo orden en los dos shaders;
  /// `uBezel` va al final).
  List<double> uniforms(double line, double maskW) =>
      [scan, mask, bloom, vignette, curve, line, maskW, bezel];
}

/// Punto del contenido que se ve en el punto [p] de la pantalla con la
/// curvatura [k] (la misma deformación que `crt.frag`).
Offset crtWarp(Offset p, Size size, double k) {
  if (k == 0 || size.isEmpty) return p;
  final cx = p.dx / size.width - 0.5, cy = p.dy / size.height - 0.5;
  final f = 1 + k * (cx * cx + cy * cy);
  return Offset((0.5 + cx * f) * size.width, (0.5 + cy * f) * size.height);
}

/// Los dos programas (cargan una vez).
class CrtShaders {
  CrtShaders(this.filter, this.overlay);

  /// `crt.frag` (con ImageFilter.shader, Impeller).
  final ui.FragmentProgram? filter;

  /// `crt_overlay.frag` (encima, multiplicando; sin Impeller).
  final ui.FragmentProgram? overlay;

  static Future<CrtShaders>? _loading;

  /// Lo ya cargado (sin esperar), o `null` si todavía no terminó.
  static CrtShaders? loaded;

  /// Lo que se pudo cargar (o nada: sin filtro).
  static Future<CrtShaders> load() => _loading ??= () async {
        Future<ui.FragmentProgram?> one(String asset) async {
          try {
            return await ui.FragmentProgram.fromAsset(asset);
          } catch (e) {
            debugPrint('CRT: no se pudo cargar $asset: $e');
            return null;
          }
        }

        final filter = shaderFilterSupported ? await one('shaders/crt.frag') : null;
        final overlay = filter == null ? await one('shaders/crt_overlay.frag') : null;
        return loaded = CrtShaders(filter, overlay);
      }();

  /// El motor puede filtrar con shaders (Impeller).
  static bool get shaderFilterSupported {
    try {
      return ui.ImageFilter.isShaderFilterSupported;
    } catch (_) {
      return false;
    }
  }
}

/// Filtro retro CRT sobre [child] (toda la app: `MaterialApp.builder`).
/// La estructura de widgets es la misma con el filtro prendido o
/// apagado: cambiar el nivel nunca reconstruye lo de abajo.
class CrtFilter extends StatefulWidget {
  const CrtFilter({super.key, required this.level, required this.child});

  final CrtLevel level;
  final Widget child;

  @override
  State<CrtFilter> createState() => CrtFilterState();
}

class CrtFilterState extends State<CrtFilter> {
  CrtShaders? _shaders;

  /// Qué camino usa ahora (tests y diagnóstico).
  String get mode {
    final p = CrtParams.of(widget.level);
    if (p == null) return 'off';
    if (_shaders?.filter != null) return 'filter';
    if (_shaders?.overlay != null) return 'overlay';
    return 'none';
  }

  ui.FragmentShader? _filterShader;
  ui.ImageFilter? _imageFilter;
  (CrtLevel, double, double)? _filterKey;

  @override
  void initState() {
    super.initState();
    _shaders = CrtShaders.loaded;
    if (_shaders != null) return;
    unawaited(CrtShaders.load().then((s) {
      if (mounted) setState(() => _shaders = s);
    }));
  }

  @override
  void dispose() {
    _filterShader?.dispose();
    super.dispose();
  }

  ui.ImageFilter? _filterFor(CrtParams p, double line, double maskW) {
    final program = _shaders?.filter;
    if (program == null) return null;
    final key = (widget.level, line, maskW);
    if (_filterKey == key && _imageFilter != null) return _imageFilter;
    _filterShader?.dispose();
    final sh = program.fragmentShader();
    final u = p.uniforms(line, maskW);
    // 0 y 1 son `uSize` (los pone el motor).
    for (var i = 0; i < u.length; i++) {
      sh.setFloat(2 + i, u[i]);
    }
    _filterShader = sh;
    _filterKey = key;
    try {
      // Con mucha curvatura, vecino más cercano duplica y saltea columnas
      // de la fuente pixel: con curva se muestrea bilineal (§ 3.2). Sin
      // curva (todos los niveles desde v0.8.2), vecino más cercano.
      return _imageFilter = ui.ImageFilter.shader(sh,
          filterQuality: p.curve >= 0.04 ? FilterQuality.low : FilterQuality.none);
    } catch (e) {
      debugPrint('CRT: ImageFilter.shader falló: $e');
      return _imageFilter = null;
    }
  }

  static final _identity = ui.ImageFilter.matrix(Matrix4.identity().storage);

  @override
  Widget build(BuildContext context) {
    final p = CrtParams.of(widget.level);
    final mq = MediaQuery.maybeOf(context);
    final dpr = mq?.devicePixelRatio ?? 1;
    final h = (mq?.size.height ?? 720) * dpr;
    final line = CrtParams.lineFor(h);
    final maskW = CrtParams.maskWidthFor(dpr);
    final filter = p == null ? null : _filterFor(p, line, maskW);
    final overlay = p == null || filter != null ? null : _shaders?.overlay;
    return _CrtHitWarp(
      curve: filter == null ? 0 : p!.curve,
      child: ImageFiltered(
        enabled: filter != null,
        imageFilter: filter ?? _identity,
        child: CustomPaint(
          foregroundPainter: overlay == null
              ? null
              : _OverlayPainter(overlay, p!, line, maskW, dpr),
          child: widget.child,
        ),
      ),
    );
  }
}

/// `crt_overlay.frag` encima de todo, multiplicando.
class _OverlayPainter extends CustomPainter {
  _OverlayPainter(this.program, this.params, this.line, this.maskW, this.dpr);

  final ui.FragmentProgram program;
  final CrtParams params;
  final double line, maskW, dpr;

  @override
  void paint(Canvas canvas, Size size) {
    final sh = program.fragmentShader()
      ..setFloat(0, size.width * dpr)
      ..setFloat(1, size.height * dpr);
    final u = params.uniforms(line, maskW);
    for (var i = 0; i < u.length; i++) {
      sh.setFloat(2 + i, u[i]);
    }
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = sh
          ..blendMode = BlendMode.multiply);
    sh.dispose();
  }

  @override
  bool shouldRepaint(_OverlayPainter old) =>
      old.program != program ||
      old.params != params ||
      old.line != line ||
      old.maskW != maskW ||
      old.dpr != dpr;
}

/// Con curvatura, los clics van al punto del contenido que se ve bajo el
/// puntero (la misma deformación del shader).
class _CrtHitWarp extends SingleChildRenderObjectWidget {
  const _CrtHitWarp({required this.curve, super.child});

  final double curve;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderCrtHitWarp(curve);

  @override
  void updateRenderObject(BuildContext context, RenderCrtHitWarp r) =>
      r.curve = curve;
}

/// Ver [_CrtHitWarp].
class RenderCrtHitWarp extends RenderProxyBox {
  RenderCrtHitWarp(this.curve);

  double curve;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (curve == 0 || !size.contains(position)) {
      return super.hitTest(result, position: position);
    }
    final w = crtWarp(position, size, curve);
    return result.addWithPaintOffset(
      offset: position - w,
      position: position,
      hitTest: (r, p) => super.hitTest(r, position: p),
    );
  }
}
