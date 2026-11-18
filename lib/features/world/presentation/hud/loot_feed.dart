import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/retro_text.dart';
import '../../../../game_engine/models/item.dart';
import '../../../../game_engine/models/loot.dart';
import '../../../../game_engine/models/loot_filter.dart';
import '../../../../game_engine/models/session_event.dart';
import '../../../../game_engine/rules/loot_filter_rules.dart';
import '../map/loot_painter.dart';
import '../session_controller.dart';

/// Una línea del registro de loot: `Ana encontró: <objeto>` con el
/// objeto en el color de su rareza.
class LootLine {
  const LootLine(this.prefix, this.item, this.color, this.at);

  /// `Ana encontró: ` (texto neutro).
  final String prefix;

  /// Nombre del objeto (en [color]).
  final String item;
  final Color color;

  /// Segundos del reloj del registro.
  final double at;

  String get text => '$prefix$item';
}

/// Un aviso corto en el centro: lo que el jugador local levantó o le
/// entró al inventario, con el estilo de su filtro.
class LootToast {
  const LootToast(this.title, this.name, this.style, this.color, this.at,
      {this.legendary = false});

  /// `+` al levantar, `¡LEGENDARIO!`, `Te dio Ana:`…
  final String title;
  final String name;

  /// Estilo del filtro (fondo, borde, color y tamaño).
  final FilterStyle style;

  /// Color del texto si el filtro no trae uno (el de la rareza).
  final Color color;
  final double at;
  final bool legendary;

  double get durationS =>
      legendary ? LootFeed.legendaryToastS : LootFeed.toastS;
}

/// Registro y avisos de loot del HUD (docs/specs/exploration.md § "HUD",
/// docs/specs/loot.md § 4). Escucha los eventos de la sesión mientras la
/// pantalla del juego vive (también durante la batalla: el loot de una
/// pelea llega con su fin).
class LootFeed extends ChangeNotifier {
  LootFeed({
    required this.localId,
    required this.playerName,
    required this.itemName,
    required this.verdictFor,
    double Function()? clock,
  }) : _clock = clock ?? _stopwatchClock();

  final String localId;
  final String Function(String playerId) playerName;
  final String Function(LootDrop d) itemName;

  /// Cómo ve el jugador [playerId] un drop según SU filtro (`null` = no
  /// se sabe: se muestra).
  final FilterVerdict? Function(String playerId, LootDrop d) verdictFor;
  final double Function() _clock;

  static double Function() _stopwatchClock() {
    final sw = Stopwatch()..start();
    return () => sw.elapsedMicroseconds / 1e6;
  }

  /// Líneas que se conservan y cuánto se ven.
  static const maxLines = 4;
  static const lineS = 14.0;

  /// Duración de un aviso (s); el del Legendario dura más.
  static const toastS = 3.0;
  static const legendaryToastS = 5.0;
  static const maxToasts = 3;

  final _lines = <LootLine>[];
  final _toasts = <LootToast>[];

  double get now => _clock();

  /// Las líneas vigentes (la más nueva al final).
  List<LootLine> get lines {
    final t = now;
    return _lines.where((l) => t - l.at < lineS).toList();
  }

  /// Los avisos vigentes (el más nuevo al final).
  List<LootToast> get toasts {
    final t = now;
    return _toasts.where((x) => t - x.at < x.durationS).toList();
  }

  /// Hay algo a la vista (para seguir refrescando).
  bool get hasLive => lines.isNotEmpty || toasts.isNotEmpty;

  void _line(String prefix, LootDrop d) {
    _lines.add(LootLine(prefix, itemName(d), dropColor(d), now));
    if (_lines.length > maxLines) _lines.removeAt(0);
  }

  void _toast(String title, LootDrop d, FilterStyle style,
      {bool legendary = false}) {
    _toasts.add(LootToast(title, itemName(d), style, dropColor(d), now,
        legendary: legendary));
    if (_toasts.length > maxToasts) _toasts.removeAt(0);
  }

  void onEvent(SessionEvent e) {
    switch (e) {
      case LootDropEvent(:final playerId, :final drop, :final groundId):
        final v = verdictFor(playerId, drop);
        if (v != null && !v.visible) return;
        _line('${playerName(playerId)} encontró: ', drop);
        if (playerId == localId) {
          final legendary = drop.item?.rarity == Rarity.legendario;
          final style = v?.style ?? LootFilterRules.defaultStyle(drop);
          if (legendary) {
            _toast('¡LEGENDARIO!', drop, style, legendary: true);
          } else if (groundId == null) {
            // Sin loot en el piso: entró directo al inventario.
            _toast('+', drop, style);
          }
        }
      case LootPickedEvent(:final playerId, :final drop)
          when playerId == localId:
        final v = verdictFor(playerId, drop);
        _toast('+', drop, v?.style ?? LootFilterRules.defaultStyle(drop));
      case ItemGivenEvent(:final fromId, :final toId, :final drop):
        _line('${playerName(fromId)} le dio a ${playerName(toId)}: ', drop);
        if (toId == localId) {
          final v = verdictFor(toId, drop);
          _toast('Te dio ${playerName(fromId)}:', drop,
              v?.style ?? LootFilterRules.defaultStyle(drop));
        }
      default:
        return;
    }
    notifyListeners();
  }
}

/// El registro de loot de la pantalla del juego. `WorldScreen` lo
/// mantiene vivo a través de `sessionSfxProvider` (que lo mira), así no
/// se pierden los drops del fin de una batalla.
final lootFeedProvider = Provider.autoDispose<LootFeed>((ref) {
  final c = ref.watch(sessionControllerProvider.notifier);
  final feed = LootFeed(
    localId: c.localId,
    playerName: (id) => c.session?.players[id]?.name ?? id,
    itemName: (d) => lootDropName(c.engine.progression.items.displayName, d,
        ecoName: c.engine.progression.ecos.fullName),
    verdictFor: (id, d) {
      final p = c.session?.players[id]?.profile;
      return p == null ? null : c.engine.lootVerdict(p, d);
    },
  );
  final sub = c.events.listen(feed.onEvent);
  ref.onDispose(() {
    unawaited(sub.cancel());
    feed.dispose();
  });
  return feed;
});

/// Refresca mientras haya algo vigente (las líneas y avisos vencen solos).
mixin _FeedTicker<T extends StatefulWidget> on State<T> {
  LootFeed get feed;
  Timer? _timer;

  void _changed() {
    if (!mounted) return;
    setState(() {});
    _timer ??= Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      setState(() {});
      if (!feed.hasLive) {
        _timer?.cancel();
        _timer = null;
      }
    });
  }

  void attach(LootFeed f) {
    f.addListener(_changed);
    if (f.hasLive) _changed();
  }

  void detach(LootFeed f) => f.removeListener(_changed);

  @override
  void dispose() {
    _timer?.cancel();
    detach(feed);
    super.dispose();
  }
}

/// Las últimas líneas del registro de loot (arriba del chat).
class LootLog extends StatefulWidget {
  const LootLog({super.key, required this.feed});

  final LootFeed feed;

  @override
  State<LootLog> createState() => _LootLogState();
}

class _LootLogState extends State<LootLog> with _FeedTicker<LootLog> {
  @override
  LootFeed get feed => widget.feed;

  @override
  void initState() {
    super.initState();
    attach(widget.feed);
  }

  @override
  void didUpdateWidget(LootLog old) {
    super.didUpdateWidget(old);
    if (old.feed != widget.feed) {
      detach(old.feed);
      attach(widget.feed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lines = widget.feed.lines;
    if (lines.isEmpty) return const SizedBox.shrink();
    final t = widget.feed.now;
    return Container(
      key: const ValueKey('loot-log'),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
      color: const Color(0x99000000),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final l in lines)
            Opacity(
              // Se desvanece el último segundo.
              opacity: ((LootFeed.lineS - (t - l.at)).clamp(0.0, 1.0)),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: retroText(l.prefix),
                        style: const TextStyle(color: Color(0xFFDFE6E9))),
                    TextSpan(
                        text: retroText(l.item),
                        style: TextStyle(color: l.color)),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Los avisos de loot (abajo al centro, encima del aviso de [E]).
class LootToasts extends StatefulWidget {
  const LootToasts({super.key, required this.feed});

  final LootFeed feed;

  @override
  State<LootToasts> createState() => _LootToastsState();
}

class _LootToastsState extends State<LootToasts>
    with _FeedTicker<LootToasts> {
  @override
  LootFeed get feed => widget.feed;

  @override
  void initState() {
    super.initState();
    attach(widget.feed);
  }

  @override
  void didUpdateWidget(LootToasts old) {
    super.didUpdateWidget(old);
    if (old.feed != widget.feed) {
      detach(old.feed);
      attach(widget.feed);
    }
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
              opacity: ((x.durationS - (t - x.at)) / 0.5).clamp(0.0, 1.0),
              child: LootToastBox(toast: x),
            ),
          ),
      ],
    );
  }
}

/// Tamaño del filtro (18–45) → px de pantalla del aviso (9–14).
double toastFontSize(int? size) =>
    (6 + (size ?? FilterStyle.defaultSize) / 6).roundToDouble();

/// Un aviso con el estilo del filtro: fondo, borde y color del texto.
class LootToastBox extends StatelessWidget {
  const LootToastBox({super.key, required this.toast});

  final LootToast toast;

  @override
  Widget build(BuildContext context) {
    final st = toast.style;
    final text =
        st.textColor != null ? filterColor(st.textColor!) : toast.color;
    final border = st.borderColor != null
        ? filterColor(st.borderColor!)
        : toast.legendary
            ? const Color(0xFFFF8C28)
            : null;
    return Container(
      key: ValueKey('loot-toast-${toast.name}'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: st.backgroundColor != null
            ? filterColor(st.backgroundColor!)
            : const Color(0xCC000000),
        border: border == null
            ? null
            : Border.all(color: border, width: toast.legendary ? 3 : 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (toast.title != '+')
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(retroText(toast.title),
                  style: TextStyle(
                      fontSize: 8,
                      color: toast.legendary
                          ? const Color(0xFFFF8C28)
                          : const Color(0xFFDFE6E9))),
            ),
          Text(
            retroText(toast.title == '+' ? '+ ${toast.name}' : toast.name),
            style: TextStyle(fontSize: toastFontSize(st.size), color: text),
          ),
        ],
      ),
    );
  }
}
