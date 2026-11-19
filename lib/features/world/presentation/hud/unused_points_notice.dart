import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/panel_frame.dart';
import '../../../../app/theme/proto_colors.dart';
import '../../../../app/theme/retro_text.dart';
import '../../../../app/theme/retro_theme.dart';
import '../../../../app/widgets/notice_close.dart';
import '../../../../app/widgets/points_badge.dart';
import '../../../characters/domain/unused_points.dart';

/// Botón `PERSONAJE [C]` del HUD con la insignia `+N` de puntos sin usar
/// (passive_tree_v4.md § 7). Solo aparece si hay puntos: no ocupa lugar
/// en el HUD mientras no haga falta. El tooltip dice de qué son.
class UnusedPointsButton extends StatelessWidget {
  const UnusedPointsButton({
    super.key,
    required this.points,
    required this.onPressed,
    this.reduceMotion = false,
  });

  final UnusedPoints points;
  final VoidCallback onPressed;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    if (!points.any) return const SizedBox.shrink();
    return RetroTooltip(
      message: '<b>Puntos sin usar</b><br>'
          '${points.parts.map(retroText).join('<br>')}',
      // La insignia va pegada al botón (no encima: no tapa el texto).
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            key: const ValueKey('hud-points-button'),
            style: RetroTheme.compactButton(),
            onPressed: onPressed,
            child: const Text('PERSONAJE [C]'),
          ),
          const SizedBox(width: 4),
          PointsBadge(
            key: const ValueKey('hud-points-badge'),
            count: points.total,
            reduceMotion: reduceMotion,
          ),
        ],
      ),
    );
  }
}

/// Aviso suave al subir de nivel (o al ganar puntos de ascensión) si
/// quedan puntos de árbol / ascensión sin usar: `Tenés 2 puntos de árbol
/// sin usar · [C]`. Uno por subida, 6 s, sin bloquear nada. Mientras
/// [blocked] (reparto de la subida de nivel, un panel abierto) espera; si
/// al terminar ya no quedan puntos, no dice nada.
class UnusedPointsToast extends StatefulWidget {
  const UnusedPointsToast({
    super.key,
    required this.points,
    required this.treeLevel,
    required this.ascensionEarned,
    this.blocked = false,
    this.reduceMotion = false,
    this.duration = shown,
    this.dismissSignal,
  });

  final UnusedPoints points;

  /// `PlayerProfile.treeLevel` (nivel + Maestría): sube → aviso.
  final int treeLevel;

  /// Puntos de ascensión ganados: suben → aviso.
  final int ascensionEarned;
  final bool blocked;
  final bool reduceMotion;

  /// Cuánto se ve (DURACIÓN DE LOS AVISOS); `null` = hasta cerrarlo.
  final Duration? duration;

  /// "Cerrar todos los avisos" (`noticeDismissProvider`).
  final Listenable? dismissSignal;

  static const shown = Duration(seconds: 6);

  @override
  State<UnusedPointsToast> createState() => _UnusedPointsToastState();
}

class _UnusedPointsToastState extends State<UnusedPointsToast> {
  late int _level;
  late int _asc;
  bool _pending = false;
  String? _text;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Lo que ya tenía al aparecer no se avisa (lo muestra la insignia).
    _level = widget.treeLevel;
    _asc = widget.ascensionEarned;
    widget.dismissSignal?.addListener(_close);
  }

  void _close() {
    _timer?.cancel();
    if (mounted && _text != null) setState(() => _text = null);
  }

  @override
  void didUpdateWidget(UnusedPointsToast old) {
    super.didUpdateWidget(old);
    if (old.dismissSignal != widget.dismissSignal) {
      old.dismissSignal?.removeListener(_close);
      widget.dismissSignal?.addListener(_close);
    }
    if (widget.treeLevel > _level ||
        widget.ascensionEarned > _asc ||
        // Un compañero ganó puntos (solo_party.md § 6.3).
        widget.points.companionTotal > old.points.companionTotal) {
      _pending = true;
    }
    // Bajar (cambio de personaje, reinicio de Maestría): solo se anota.
    _level = widget.treeLevel;
    _asc = widget.ascensionEarned;
    if (_pending && !widget.blocked) {
      _pending = false;
      // Solo árbol y ascensión: los atributos ya los pide la subida.
      // Los compañeros guardan sus puntos (también de atributos).
      final p = UnusedPoints(
          tree: widget.points.tree,
          ascension: widget.points.ascension,
          companions: widget.points.companions);
      final text = p.toastText;
      if (text != null) {
        _text = text;
        _timer?.cancel();
        if (widget.duration case final d?) {
          _timer = Timer(d, () {
            if (mounted) setState(() => _text = null);
          });
        }
      }
    }
  }

  @override
  void dispose() {
    widget.dismissSignal?.removeListener(_close);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _text;
    return AnimatedSwitcher(
      duration: widget.reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 250),
      child: text == null
          ? const SizedBox.shrink()
          : Container(
              key: const ValueKey('hud-points-toast'),
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: ProtoColors.scrim(0.8),
                border: Border.all(color: ProtoColors.gold, width: 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Marca de forma (no solo color) para daltonismo.
                  Text('▲ ',
                      style: RetroType.style(RetroType.small,
                          color: ProtoColors.gold)),
                  Text(retroText(text),
                      style: RetroType.style(RetroType.small,
                          color: ProtoColors.white)),
                  if (widget.duration == null) ...[
                    const SizedBox(width: 8),
                    NoticeClose(
                        key: const ValueKey('hud-points-toast-close'),
                        onPressed: _close),
                  ],
                ],
              ),
            ),
    );
  }
}
