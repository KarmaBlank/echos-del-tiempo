import 'dart:ui' show FramePhase, FrameTiming;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/perf/fps_meter.dart';
import '../../core/settings/settings_providers.dart';
import '../../features/world/presentation/session_controller.dart'
    show activeNetSessionProvider;
import '../../netcode/contracts/net_latency.dart';
import '../theme/proto_colors.dart';
import '../theme/retro_type.dart';

/// FPS medidos de la app (`null` = sin datos). Solo escucha los
/// `FrameTiming` mientras alguien la escucha a ella (el indicador
/// prendido). Los tests la reemplazan por un `ValueNotifier`.
final frameRateProvider = Provider<ValueListenable<double?>>((ref) {
  final m = TimingsFrameRate();
  ref.onDispose(m.dispose);
  return m;
});

/// FPS reales a partir de `SchedulerBinding.addTimingsCallback` (hora de
/// vsync de cada cuadro dibujado; los que salta el `FrameLimiter` no
/// llegan). Avisa solo cuando cambia el número redondeado.
class TimingsFrameRate extends ChangeNotifier
    implements ValueListenable<double?> {
  final _meter = FpsMeter();
  int _listeners = 0;
  int? _shown;

  @override
  double? get value => _meter.fps;

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    if (_listeners++ == 0) {
      _meter.reset();
      _shown = null;
      SchedulerBinding.instance.addTimingsCallback(_onTimings);
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (_listeners > 0 && --_listeners == 0) {
      SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    }
  }

  @override
  void dispose() {
    if (_listeners > 0) {
      SchedulerBinding.instance.removeTimingsCallback(_onTimings);
      _listeners = 0;
    }
    super.dispose();
  }

  void _onTimings(List<FrameTiming> timings) {
    final times = [
      for (final t in timings) t.timestampInMicroseconds(FramePhase.vsyncStart),
    ]..sort();
    _meter.addFrames(times);
    final r = _meter.fps?.round();
    if (r != _shown) {
      _shown = r;
      notifyListeners();
    }
  }
}

/// Bueno / regular / malo: color + cantidad de barras (no depende solo
/// del color; docs/specs/settings.md § 3.9).
enum PerfLevel {
  unknown(0),
  bad(1),
  medium(2),
  good(3);

  const PerfLevel(this.bars);

  /// Barritas encendidas de 3.
  final int bars;

  Color get color => switch (this) {
        PerfLevel.good => ProtoColors.green,
        PerfLevel.medium => ProtoColors.gold,
        PerfLevel.bad => ProtoColors.red,
        PerfLevel.unknown => ProtoColors.dim,
      };

  /// Ping: < 80 ms bueno, < 150 ms regular.
  static PerfLevel ping(Duration? rtt) {
    if (rtt == null) return unknown;
    final ms = rtt.inMicroseconds / 1000;
    return ms < 80
        ? good
        : ms < 150
            ? medium
            : bad;
  }

  /// FPS contra el objetivo (el tope, o 60 sin tope): ≥ 90 % bueno,
  /// ≥ 50 % regular.
  static PerfLevel fps(double? fps, int? limit) {
    if (fps == null) return unknown;
    final target = (limit ?? 60).toDouble();
    return fps >= target * 0.9
        ? good
        : fps >= target * 0.5
            ? medium
            : bad;
  }
}

/// Textos del indicador (puros, para los tests).
abstract final class PerfText {
  /// `60 FPS`, `60 FPS (máx 60)` con tope, `-- FPS` sin datos.
  static String fps(double? fps, int? limit) {
    final n = fps == null ? '--' : '${fps.round()}';
    return limit == null ? '$n FPS' : '$n FPS (máx $limit)';
  }

  static String _n(Duration d) {
    final ms = d.inMicroseconds / 1000;
    return ms < 1 ? '<1' : '${ms.round()}';
  }

  /// Cliente `ping 23 ms`; host `ping 23 ms (máx 41)` (con un solo
  /// cliente, sin el máximo); sin medir `ping --`.
  static String ping(NetLatency? l) {
    final rtt = l?.rtt;
    if (l == null || rtt == null) return 'ping --';
    final max = l.max;
    if (l.isHost && l.peers > 1 && max != null) {
      return 'ping ${_n(rtt)} ms (máx ${_n(max)})';
    }
    return 'ping ${_n(rtt)} ms';
  }
}

/// "FPS Y PING" (docs/specs/settings.md § 3.9): un indicador chico en una
/// esquina, encima de toda la app. Nunca recibe clics. [child] (la app)
/// queda siempre como primer hijo del mismo `Stack`: prender o apagar el
/// indicador no reconstruye la app.
class PerfOverlay extends ConsumerWidget {
  const PerfOverlay({super.key, required this.child});

  final Widget child;

  /// Margen desde el borde. Es una sola línea en la letra de los botones
  /// (`RetroType.label`): arriba entra en la franja libre de 16 px sobre
  /// la fila del HUD (`≡ MENU [ESC]`, `Sala: CODIGO [COPIAR]`, minimapa),
  /// abajo en la de debajo del chat y la ficha. A los costados, 8 px.
  static const edge = 1.0, side = 8.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(gameSettingsProvider.select((s) => s.perfOverlay));
    final corner = ref.watch(gameSettingsProvider.select((s) => s.perfCorner));
    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        if (on)
          Positioned(
            top: corner.top ? edge : null,
            bottom: corner.top ? null : edge,
            left: corner.right ? null : side,
            right: corner.right ? side : null,
            child: const IgnorePointer(child: PerfReadout()),
          ),
      ],
    );
  }
}

/// Una línea: FPS y, en una sala, ping (cada uno con sus barras).
class PerfReadout extends ConsumerWidget {
  const PerfReadout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final limit = ref.watch(gameSettingsProvider.select((s) => s.fpsLimit.fps));
    final net = ref.watch(activeNetSessionProvider);
    final fps = ref.watch(frameRateProvider);
    return Container(
      key: const ValueKey('perf-overlay'),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      color: ProtoColors.scrim(0.75),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ValueListenableBuilder<double?>(
            valueListenable: fps,
            builder: (context, v, _) => _Line(
              key: const ValueKey('perf-fps'),
              text: PerfText.fps(v, limit),
              level: PerfLevel.fps(v, limit),
            ),
          ),
          if (net case final LatencyProbe probe) ...[
            const SizedBox(width: 10),
            StreamBuilder<NetLatency>(
              stream: probe.latencyChanges,
              initialData: probe.latency,
              builder: (context, snap) {
                final l = snap.data;
                return _Line(
                  key: const ValueKey('perf-ping'),
                  text: PerfText.ping(l),
                  level: PerfLevel.ping(l?.rtt),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// Barritas + texto en el color del nivel (sin negrita ni subrayado: el
/// indicador está fuera de cualquier `Material`).
class _Line extends StatelessWidget {
  const _Line({super.key, required this.text, required this.level});

  final String text;
  final PerfLevel level;

  @override
  Widget build(BuildContext context) {
    final style = RetroType.style(RetroType.label, color: level.color)
        .copyWith(decoration: TextDecoration.none, fontWeight: FontWeight.w400);
    final h = MediaQuery.textScalerOf(context).scale(RetroType.label);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: '${level.bars} de 3',
          child: _Bars(level: level, height: h),
        ),
        const SizedBox(width: 4),
        Text(text, style: style, maxLines: 1, softWrap: false),
      ],
    );
  }
}

/// Tres barras tipo señal: las encendidas en el color del nivel.
class _Bars extends StatelessWidget {
  const _Bars({required this.level, required this.height});

  final PerfLevel level;
  final double height;

  @override
  Widget build(BuildContext context) {
    final w = (height / 3).clamp(2.0, 6.0).roundToDouble();
    return SizedBox(
      height: height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) SizedBox(width: (w / 2).ceilToDouble()),
            Container(
              key: ValueKey('perf-bar-$i-${i < level.bars ? 'on' : 'off'}'),
              width: w,
              height: (height * (i + 1) / 3).roundToDouble(),
              color: i < level.bars ? level.color : ProtoColors.barBg,
            ),
          ],
        ],
      ),
    );
  }
}
