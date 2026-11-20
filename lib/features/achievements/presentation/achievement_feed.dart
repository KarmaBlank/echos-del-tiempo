import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../app/widgets/pixel_icon.dart';
import '../../../core/settings/settings_providers.dart';
import '../../../game_engine/data/achievements_catalog.dart';
import '../../../game_engine/models/achievement.dart';
import '../../../game_engine/models/loot.dart';
import '../../../game_engine/models/session_event.dart';
import '../../inventory/presentation/item_widgets.dart' as items;
import '../../world/presentation/session_controller.dart';

/// Texto del toast de una hazaña (achievements.md § 7), para lectores de
/// pantalla y registros: `HAZAÑA · Primera fusión · +₵300 +2 Esquirlas
/// del Eco`.
String achievementToastText(String id) {
  final d = kAchievementsById[id];
  if (d == null) return 'HAZAÑA · $id';
  final r = d.reward.text;
  return r.isEmpty ? 'HAZAÑA · ${d.name}' : 'HAZAÑA · ${d.name} · $r';
}

/// Cola de toasts de hazañas (achievements.md § 7): hasta [maxVisible] a
/// la vez, apilados; cada uno dura [toastS] segundos (por la DURACIÓN DE
/// LOS AVISOS) desde que se ve. Los que no entran esperan su lugar.
class AchievementFeed extends ChangeNotifier {
  AchievementFeed({double Function()? clock}) : _clock = clock ?? _stopwatch();

  static double Function() _stopwatch() {
    final sw = Stopwatch()..start();
    return () => sw.elapsedMicroseconds / 1e6;
  }

  final double Function() _clock;

  static const toastS = 4.0;
  static const maxVisible = 3;

  double durationFactor = 1;
  bool get persistent => durationFactor.isInfinite;
  double get shownS => toastS * durationFactor;

  final _queue = <String>[];

  /// Desde cuándo se ve cada uno de los primeros [maxVisible].
  final _since = <double>[];

  double get now => _clock();

  void _expire() {
    final t = now;
    var i = 0;
    while (i < _since.length) {
      if (!persistent && t - _since[i] >= shownS) {
        _queue.removeAt(i);
        _since.removeAt(i);
      } else {
        i++;
      }
    }
    while (_since.length < maxVisible && _since.length < _queue.length) {
      _since.add(t);
    }
  }

  /// Los que se ven ahora, el más viejo primero.
  List<String> get visible {
    _expire();
    return List.unmodifiable(_queue.take(_since.length));
  }

  /// El más viejo de los que se ven (o `null`).
  String? get current {
    final v = visible;
    return v.isEmpty ? null : v.first;
  }

  /// Segundos que le quedan al de la posición [i] de [visible].
  double leftOf(int i) =>
      i < _since.length ? shownS - (now - _since[i]) : shownS;

  /// Segundos que le quedan al más viejo.
  double get left => leftOf(0);

  int get pending => _queue.length;

  void push(String id) {
    _queue.add(id);
    _expire();
    notifyListeners();
  }

  /// Saca el de la posición [i] de [visible] (clic o ×).
  void dismissAt(int i) {
    _expire();
    if (i >= _since.length) return;
    _queue.removeAt(i);
    _since.removeAt(i);
    _expire();
    notifyListeners();
  }

  void dismiss() => dismissAt(0);
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

/// Los toasts de hazañas (arriba a la derecha del HUD): apilados, cada
/// uno entra deslizando y se desvanece al final.
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
    final f = widget.feed;
    final list = f.visible;
    if (list.isEmpty) return const SizedBox.shrink();
    // Mismo ancho para todos los apilados (el del más ancho).
    return IntrinsicWidth(
        child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < list.length; i++)
          Padding(
            // Mismo id dos veces seguidas no pasa (una vez por cuenta).
            key: ValueKey('ach-toast-slot-${list[i]}'),
            padding: EdgeInsets.only(bottom: DsSpace.xs),
            child: Opacity(
              opacity:
                  f.persistent ? 1 : (f.leftOf(i) / 0.4).clamp(0.0, 1.0),
              child: AchievementToastBox(
                  id: list[i], onDismiss: () => f.dismissAt(i)),
            ),
          ),
      ],
    ));
  }
}

/// Un toast de hazaña: franja dorada, "HAZAÑA LOGRADA" + nombre y la
/// recompensa con un ícono por material/poción. Entra deslizando desde la
/// derecha con un destello y un eco translúcido (≤ 400 ms; sin animación
/// con "reducir movimiento"). Clic: lo descarta.
class AchievementToastBox extends StatelessWidget {
  const AchievementToastBox({super.key, required this.id, this.onDismiss});

  final String id;
  final VoidCallback? onDismiss;

  /// Ancho máximo a Normal en 1280 × 720 (crece con el texto).
  static const maxWidthBase = 300.0;

  /// Duración de la entrada.
  static const enter = Duration(milliseconds: 360);

  @override
  Widget build(BuildContext context) {
    final d = kAchievementsById[id];
    final card = Semantics(
      label: achievementToastText(id),
      container: true,
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxWidth: RetroType.width(context, maxWidthBase)),
          child: Container(
            key: const ValueKey('ach-toast'),
            decoration: const BoxDecoration(
              color: DsColors.surface,
              border: Border(
                  left: BorderSide(color: DsColors.reward, width: 4)),
            ),
            padding: EdgeInsets.symmetric(
                horizontal: DsSpace.sm, vertical: DsSpace.xs),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  PixelIcon(PixelIconKind.star,
                      size: RetroType.width(context, 10),
                      color: DsColors.reward),
                  SizedBox(width: DsSpace.xs),
                  Text(retroText('HAZAÑA LOGRADA'),
                      key: const ValueKey('ach-toast-head'),
                      style: DsText.subtitle(DsColors.reward)),
                ]),
                Text(retroText(d?.name ?? id),
                    key: const ValueKey('ach-toast-name'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DsText.body(DsColors.textPrimary)),
                if (d != null && !d.reward.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: AchievementRewardRow(reward: d.reward),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    final tappable = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        key: const ValueKey('ach-toast-close'),
        behavior: HitTestBehavior.opaque,
        onTap: onDismiss,
        child: card,
      ),
    );
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return tappable;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: enter,
      curve: Curves.easeOutCubic,
      child: tappable,
      builder: (context, t, child) {
        final dx = (1 - t) * RetroType.width(context, 48);
        // Destello: sube y baja en la primera mitad.
        final flash = (t < 0.5 ? t * 2 : (1 - t) * 2).clamp(0.0, 1.0);
        return Stack(
            clipBehavior: Clip.none, fit: StackFit.passthrough, children: [
          // El eco: una copia translúcida que se queda atrás y se apaga.
          if (t < 1)
            Positioned.fill(
              child: IgnorePointer(
                child: Transform.translate(
                  offset: Offset(dx * 1.8, 0),
                  child: Opacity(
                    opacity: (1 - t) * 0.35,
                    child: Container(color: DsColors.reward),
                  ),
                ),
              ),
            ),
          Transform.translate(
            offset: Offset(dx, 0),
            child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
          ),
          if (flash > 0)
            Positioned.fill(
              child: IgnorePointer(
                child: Transform.translate(
                  offset: Offset(dx, 0),
                  child: Container(
                      color: DsColors.reward.withValues(alpha: flash * 0.25)),
                ),
              ),
            ),
        ]);
      },
    );
  }
}

/// La recompensa de una hazaña en una fila: créditos en dorado y un
/// ícono procedural por material o poción con su cantidad (como los
/// costos del DS: número en Detalle, sin texto largo).
class AchievementRewardRow extends StatelessWidget {
  const AchievementRewardRow({super.key, required this.reward});

  final AchievementReward reward;

  @override
  Widget build(BuildContext context) {
    final icon = RetroType.width(context, 12);
    Widget stack(StackKind k, int n) {
      final (key, accent) = items.iconForStack(k);
      return Row(
          key: ValueKey('ach-toast-reward-${k.name}'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
                message: k.label,
                child: items.PixelIcon(key, accent: accent, size: icon)),
            const SizedBox(width: 2),
            Text('x$n', style: DsText.detail(DsColors.textPrimary)),
          ]);
    }

    return Wrap(
      key: const ValueKey('ach-toast-reward'),
      spacing: DsSpace.sm,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (reward.credits > 0)
          Text('+₵${reward.credits}',
              key: const ValueKey('ach-toast-reward-credits'),
              style: DsText.detail(DsColors.reward)),
        if (reward.esquirlas > 0) stack(StackKind.esquirla, reward.esquirlas),
        if (reward.cristales > 0) stack(StackKind.cristal, reward.cristales),
        if (reward.prismas > 0) stack(StackKind.prisma, reward.prismas),
        if (reward.potions > 0) stack(StackKind.potion, reward.potions),
        if (reward.ethers > 0) stack(StackKind.ether, reward.ethers),
        if (reward.ult != null)
          Text('+ULT',
              key: const ValueKey('ach-toast-reward-ult'),
              style: DsText.detail(DsColors.warning)),
      ],
    );
  }
}
