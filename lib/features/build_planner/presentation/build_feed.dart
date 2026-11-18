import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../app/widgets/pixel_icon.dart';
import '../../../core/settings/settings_providers.dart';
import '../../../game_engine/models/build_wants.dart';
import '../../world/presentation/session_controller.dart';
import '../domain/build_tracker.dart';
import 'build_fit_badge.dart';
import 'build_plan_providers.dart';

/// Un cartel de avance del plan ("Build: ★ Keystone Demoledor").
class BuildToast {
  const BuildToast(this.text, this.at);
  final String text;
  final double at;
  bool get done => text.startsWith('Build: ★');
}

/// Carteles de build del HUD (docs/specs/build_planner.md § 5): los avisos
/// que produce el [BuildTracker] con cada perfil nuevo del jugador local.
class BuildFeed extends ChangeNotifier {
  BuildFeed({double Function()? clock}) : _clock = clock ?? _stopwatch();

  static double Function() _stopwatch() {
    final sw = Stopwatch()..start();
    return () => sw.elapsedMicroseconds / 1e6;
  }

  final double Function() _clock;

  static const toastS = 4.0;
  static const maxToasts = 3;

  final _toasts = <BuildToast>[];

  double get now => _clock();

  List<BuildToast> get toasts {
    final t = now;
    return _toasts.where((x) => t - x.at < toastS).toList();
  }

  bool get hasLive => toasts.isNotEmpty;

  void push(String text) {
    _toasts.add(BuildToast(text, now));
    if (_toasts.length > maxToasts) _toasts.removeAt(0);
    notifyListeners();
  }
}

/// Sigue el perfil local de la sesión y el plan del personaje elegido:
/// cada avance es un cartel y una línea de sistema del chat local (si el
/// ajuste "Avisos de build" está prendido). `WorldScreen` lo mantiene
/// vivo mientras dura la sesión.
final buildFeedProvider = Provider.autoDispose<BuildFeed>((ref) {
  final c = ref.watch(sessionControllerProvider.notifier);
  final tracker = BuildTracker(ref.watch(buildPlanRulesProvider));
  final feed = BuildFeed();
  void check() {
    final plan = ref.read(buildPlanProvider).plan;
    final texts = tracker.observe(plan, c.view?.me?.profile, feed.now);
    if (texts.isEmpty || !ref.read(gameSettingsProvider).buildNotices) return;
    texts.forEach(feed.push);
    // Fuera de la notificación del controlador (agrega al chat y emite).
    scheduleMicrotask(() => texts.forEach(c.addLocalNotice));
  }

  // El resumen del plan va al host para la condición `Build` del filtro
  // de loot (§ 6): al entrar a la sala y con cada cambio del plan.
  var disposed = false;
  void syncWants() {
    if (disposed || !c.mounted) return;
    c.setBuildWants(BuildWants.fromPlan(ref.read(buildPlanProvider).plan));
  }

  // Fuera de la construcción del provider (aplicarlo emite una vista).
  scheduleMicrotask(syncWants);
  final remove = c.addListener((_) => check());
  ref.listen(buildPlanProvider, (_, __) {
    check();
    syncWants();
  });
  ref.onDispose(() {
    disposed = true;
    remove();
    feed.dispose();
  });
  return feed;
});

/// Los carteles de build (encima de los de loot).
class BuildToasts extends StatefulWidget {
  const BuildToasts({super.key, required this.feed});

  final BuildFeed feed;

  @override
  State<BuildToasts> createState() => _BuildToastsState();
}

class _BuildToastsState extends State<BuildToasts> {
  Timer? _timer;

  void _changed() {
    if (!mounted) return;
    setState(() {});
    _timer ??= Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      setState(() {});
      if (!widget.feed.hasLive) {
        _timer?.cancel();
        _timer = null;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    widget.feed.addListener(_changed);
  }

  @override
  void didUpdateWidget(BuildToasts old) {
    super.didUpdateWidget(old);
    if (old.feed != widget.feed) {
      old.feed.removeListener(_changed);
      widget.feed.addListener(_changed);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.feed.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final toasts = widget.feed.toasts;
    if (toasts.isEmpty) return const SizedBox.shrink();
    final t = widget.feed.now;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final x in toasts)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Opacity(
              opacity: ((BuildFeed.toastS - (t - x.at)) / 0.5).clamp(0.0, 1.0),
              child: BuildToastBox(toast: x),
            ),
          ),
      ],
    );
  }
}

/// Un cartel: fondo oscuro, borde violeta (verde si completó algo).
class BuildToastBox extends StatelessWidget {
  const BuildToastBox({super.key, required this.toast});

  final BuildToast toast;

  @override
  Widget build(BuildContext context) {
    final color = toast.done ? const Color(0xFF7BED9F) : kPlanColor;
    return Container(
      key: const ValueKey('build-toast'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xE6101426),
        border: Border.all(color: kPlanColor, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PixelIcon(PixelIconKind.star,
              size: RetroType.width(context, 14), color: kPlanColor),
          const SizedBox(width: 8),
          // Tamaño de lectura (VT323) como el resto de los avisos.
          Text(retroText(toast.text), style: TextStyle(color: color)),
        ],
      ),
    );
  }
}
