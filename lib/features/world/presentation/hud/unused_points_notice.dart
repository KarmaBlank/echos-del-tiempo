import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../app/theme/panel_frame.dart';
import '../../../../app/theme/retro_text.dart';
import '../../../../app/theme/retro_theme.dart';

import '../../../../app/widgets/points_badge.dart';
import '../../../characters/domain/unused_points.dart';
import '../world_strings.dart';

/// Botón `PERSONAJE [TAB]` del HUD con la insignia `+N` de puntos sin usar
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
      message: '<b>${context.t('ui.world.hud.unused_points')}</b><br>'
          '${points.parts.map(retroText).join('<br>')}',
      // La insignia va dentro del botón, a la derecha del texto (v0.10.1):
      // suma al ancho y nunca lo tapa.
      child: DsButton(
        context.t('ui.world.hud.character'),
        key: const ValueKey('hud-points-button'),
        size: DsButtonSize.compact,
        onPressed: onPressed,
        trailing: points.characterTotal > 0
            ? PointsBadge(
                key: const ValueKey('hud-points-badge'),
                count: points.characterTotal,
                reduceMotion: reduceMotion,
              )
            : null,
      ),
    );
  }
}

/// Aviso suave al subir de nivel (o al ganar puntos de ascensión) si
/// quedan puntos de árbol / ascensión sin usar: `Tenés 2 puntos de árbol
/// sin usar · [TAB]`. Uno por subida, 6 s, sin bloquear nada. Mientras
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
        widget.points.companionTotal > old.points.companionTotal ||
        // Hito nuevo (progression_v2.md § 5): aviso propio.
        widget.points.milestone > old.points.milestone) {
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
          : Padding(
              key: const ValueKey('hud-points-toast'),
              padding: const EdgeInsets.only(top: 6),
              // Aviso del sistema (design_system.md § 6): franja dorada y
              // una marca de forma (no solo color) para daltonismo.
              child: DsToast(
                retroText(text),
                kind: DsToastKind.reward,
                leading: Text('▲',
                    style: RetroType.style(RetroType.glyph,
                        color: DsColors.reward)),
                closeKey: const ValueKey('hud-points-toast-close'),
                closeFocusable: false,
                onClose: widget.duration == null ? _close : null,
              ),
            ),

    );
  }
}
