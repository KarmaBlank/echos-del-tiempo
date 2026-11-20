import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../app/widgets/pixel_icon.dart';
import '../../../core/settings/settings_providers.dart';
import '../../../game_engine/data/achievements_catalog.dart';
import '../../../game_engine/models/session_event.dart';
import '../../world/presentation/session_controller.dart';

/// Texto del toast de una hazaña (achievements.md § 7):
/// `HAZAÑA · Primera fusión · +₵300 +2 Esquirlas del Eco`.
String achievementToastText(String id) {
  final d = kAchievementsById[id];
  if (d == null) return 'HAZAÑA · $id';
  final r = d.reward.text;
  return r.isEmpty ? 'HAZAÑA · ${d.name}' : 'HAZAÑA · ${d.name} · $r';
}

/// Cola de toasts de hazañas: de a uno, [toastS] segundos cada uno (por
/// la DURACIÓN DE LOS AVISOS), los que llegan seguidos esperan.
class AchievementFeed extends ChangeNotifier {
  AchievementFeed({double Function()? clock}) : _clock = clock ?? _stopwatch();

  static double Function() _stopwatch() {
    final sw = Stopwatch()..start();
    return () => sw.elapsedMicroseconds / 1e6;
  }

  final double Function() _clock;

  static const toastS = 3.0;

  double durationFactor = 1;
  bool get persistent => durationFactor.isInfinite;
  double get shownS => toastS * durationFactor;

  final _queue = <String>[];
  double? _since;

  double get now => _clock();

  /// El id que se ve ahora (o `null`).
  String? get current {
    if (_queue.isEmpty) return null;
    final t = now;
    _since ??= t;
    while (_queue.isNotEmpty && !persistent && t - _since! >= shownS) {
      _queue.removeAt(0);
      _since = _queue.isEmpty ? null : _since! + shownS;
    }
    return _queue.isEmpty ? null : _queue.first;
  }

  /// Segundos que le quedan al actual.
  double get left =>
      _since == null ? shownS : shownS - (now - _since!);

  int get pending => _queue.length;

  void push(String id) {
    if (_queue.isEmpty) _since = now;
    _queue.add(id);
    notifyListeners();
  }

  void dismiss() {
    if (_queue.isEmpty) return;
    _queue.removeAt(0);
    _since = _queue.isEmpty ? null : now;
    notifyListeners();
  }
}

/// Las hazañas de este dispositivo (el jugador local o sus compañeros)
/// que llegan en los eventos de la sesión.
final achievementFeedProvider = Provider.autoDispose<AchievementFeed>((ref) {
  final c = ref.watch(sessionControllerProvider.notifier);
  final feed = AchievementFeed()
    ..durationFactor = ref.read(gameSettingsProvider).noticeDuration.factor;
  final sub = c.events.listen((e) {
    if (e is AchievementUnlockedEvent && c.controls(e.playerId)) {
      feed.push(e.id);
    }
  });
  ref.onDispose(() {
    unawaited(sub.cancel());
    feed.dispose();
  });
  return feed;
});

/// El toast de la hazaña actual (arriba a la derecha del HUD).
class AchievementToasts extends StatefulWidget {
  const AchievementToasts({super.key, required this.feed});

  final AchievementFeed feed;

  @override
  State<AchievementToasts> createState() => _AchievementToastsState();
}

class _AchievementToastsState extends State<AchievementToasts> {
  Timer? _timer;

  void _changed() {
    if (!mounted) return;
    setState(() {});
    _timer ??= Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      setState(() {});
      if (widget.feed.pending == 0) {
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
  void didUpdateWidget(AchievementToasts old) {
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
    final id = widget.feed.current;
    if (id == null) return const SizedBox.shrink();
    return Opacity(
      opacity: widget.feed.persistent
          ? 1
          : (widget.feed.left / 0.4).clamp(0.0, 1.0),
      child: AchievementToastBox(
        id: id,
        onDismiss: widget.feed.dismiss,
      ),
    );
  }
}

/// Un toast de hazaña: `DsToast` chico, franja dorada y la estrella como
/// marca de forma (no depende solo del color).
class AchievementToastBox extends StatelessWidget {
  const AchievementToastBox({super.key, required this.id, this.onDismiss});

  final String id;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: DsToast(
          retroText(achievementToastText(id)),
          key: const ValueKey('ach-toast'),
          kind: DsToastKind.reward,
          textColor: DsColors.reward,
          leading: PixelIcon(PixelIconKind.star,
              size: RetroType.width(context, 14), color: DsColors.reward),
          onClose: onDismiss,
          closeKey: const ValueKey('ach-toast-close'),
          closeFocusable: false,
        ),
      );
}
