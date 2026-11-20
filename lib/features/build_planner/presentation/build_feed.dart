import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';

import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../app/widgets/pixel_icon.dart';
import '../../../core/settings/notices.dart';
import '../../../core/settings/settings_providers.dart';
import '../../world/presentation/session_controller.dart';
import '../domain/build_tracker.dart';
import '../domain/build_wants_of.dart';
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

  /// DURACIÓN DE LOS AVISOS (accessibility.md § 9.5): multiplica
  /// [toastS]; infinito = hasta cerrarlos.
  double durationFactor = 1;

  bool get persistent => durationFactor.isInfinite;

  /// Cuánto se ve un cartel (s).
  double get shownS => toastS * durationFactor;

  List<BuildToast> get toasts {
    final t = now;
    return _toasts.where((x) => t - x.at < shownS).toList();
  }

  bool get hasLive => toasts.isNotEmpty;

  /// Hay que refrescar (algo vence solo).
  bool get needsTick => hasLive && !persistent;

  void dismiss(BuildToast x) {
    if (_toasts.remove(x)) notifyListeners();
  }

  void dismissAll() {
    if (_toasts.isEmpty) return;
    _toasts.clear();
    notifyListeners();
  }

  void setDurationFactor(double f) {
    if (f == durationFactor) return;
    durationFactor = f;
    notifyListeners();
  }

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
  final feed = BuildFeed()
    ..durationFactor = ref.read(gameSettingsProvider).noticeDuration.factor;
  ref.listen(gameSettingsProvider.select((s) => s.noticeDuration),
      (_, n) => feed.setDurationFactor(n.factor));
  final bus = ref.watch(noticeDismissProvider);
  bus.addListener(feed.dismissAll);
  void check() {
    final plan = ref.read(buildPlanProvider).plan;
    final texts = tracker.observe(plan, c.view?.me?.profile, feed.now);
    // Hazaña `build_plan_done` (achievements.md § 2.6): todos los
    // objetivos del plan activo cumplidos.
    final last = tracker.last;
    if (last != null &&
        plan.goalCount > 0 &&
        last.goals.isNotEmpty &&
        last.goals.every((g) => g.done)) {
      scheduleMicrotask(() {
        if (c.mounted) c.claimAchievement('build_plan_done');
      });
    }
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
    c.setBuildWants(buildWantsOf(ref.read(buildPlanRulesProvider),
        ref.read(buildPlanProvider).plan, c.view?.me?.profile,
        stash: stashWeapons(c.stash)));
  }

  // Fuera de la construcción del provider (aplicarlo emite una vista).
  scheduleMicrotask(syncWants);
  // El % de la mejor candidata cambia con el inventario: se resincroniza
  // (setBuildWants no manda nada si no cambió).
  final remove = c.addListener((_) {
    check();
    syncWants();
  });
  ref.listen(buildPlanProvider, (_, __) {
    check();
    syncWants();
  });
  ref.onDispose(() {
    disposed = true;
    bus.removeListener(feed.dismissAll);
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
    if (!widget.feed.needsTick) return;
    _timer ??= Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      setState(() {});
      if (!widget.feed.needsTick) {
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
              opacity:
                  ((widget.feed.shownS - (t - x.at)) / 0.5).clamp(0.0, 1.0),
              child: BuildToastBox(
                  toast: x,
                  onDismiss: widget.feed.persistent
                      ? () => widget.feed.dismiss(x)
                      : null),
            ),
          ),
      ],
    );
  }
}

/// Un cartel: fondo oscuro, borde violeta (verde si completó algo).
class BuildToastBox extends StatelessWidget {
  const BuildToastBox({super.key, required this.toast, this.onDismiss});

  final BuildToast toast;

  /// HASTA CERRAR: la × del cartel.
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    // Aviso del sistema (design_system.md § 6): franja violeta del plan
    // (verde si completó algo) y la ★ como marca de forma.
    return DsToast(
      retroText(toast.text),
      key: const ValueKey('build-toast'),
      color: toast.done ? DsColors.success : kPlanColor,
      textColor: toast.done ? DsColors.success : DsColors.textPrimary,
      leading: PixelIcon(PixelIconKind.star,
          size: RetroType.width(context, 14), color: kPlanColor),
      closeKey: const ValueKey('build-toast-close'),
      closeFocusable: false,
      onClose: onDismiss,
    );

  }
}
