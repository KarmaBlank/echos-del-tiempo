import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../edition/game_edition.dart';
import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../app/theme/retro_bar.dart';
import '../../../app/theme/retro_panel.dart';
import '../release_info.dart';
import '../update_service.dart';
import 'update_controller.dart';

/// Aviso de actualización para la pantalla de título. Ver
/// docs/specs/distribution.md § "Flujo de actualización".
///
/// - Al día / sin buscar: una línea `v0.1.0 · al día` + `BUSCAR`.
/// - Hay versión nueva: panel dorado "Actualización disponible vX.Y.Z",
///   notas del release y `ACTUALIZAR`.
/// - Descargando: barra de progreso; instalando: el juego se cierra solo y
///   el instalador lo vuelve a abrir.
/// - Sin red / error: el motivo en gris y `REINTENTAR`. Nunca bloquea.
class UpdateBanner extends StatefulWidget {
  const UpdateBanner(
      {super.key, this.service, this.autoCheck, this.compact = false});

  /// Esquina del título (title_screen.md § 1, v0.37.4): la versión y
  /// `BUSCAR`; con versión nueva, solo el botón `ACTUALIZAR` (y, después,
  /// el porcentaje o `REINTENTAR`). Nunca el panel grande.
  final bool compact;

  /// `null`: GitHub Releases del repo con la versión y el canal del juego
  /// instalado (`GameEdition.current`).
  final UpdateService? service;

  /// Buscar al montarse. `null`: solo en builds release (lo que reciben
  /// los amigos); en desarrollo se busca con el botón.
  final bool? autoCheck;

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner> {
  late final UpdateController _c = UpdateController(
      widget.service ?? GitHubUpdateService(
          currentVersion: GameEdition.current.version,
          channel: GameEdition.current.releases));

  @override
  void initState() {
    super.initState();
    if (widget.autoCheck ?? kReleaseMode) _c.check();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _c,
        builder: (context, _) => ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: _body(),
        ),
      );

  Widget _body() {
    final current = 'v${_c.service.currentVersion}';
    final rel = _c.release;
    if (widget.compact) return _compact(rel);
    switch (_c.phase) {
      case UpdatePhase.idle:
      case UpdatePhase.checking:
      case UpdatePhase.upToDate:
        final status = switch (_c.phase) {
          UpdatePhase.checking => 'buscando actualizaciones…',
          UpdatePhase.upToDate => _c.message ?? 'al día',
          _ => null,
        };
        return _line(
          '$current${status == null ? '' : ' · ${protoEsc(status)}'}',
          PanelButton('BUSCAR',
              key: const ValueKey('update-check'),
              onPressed: _c.busy ? null : _c.check),
        );
      case UpdatePhase.failed when rel == null:
        return _line(
          '$current · ${protoEsc(_c.message ?? 'error')}',
          PanelButton('REINTENTAR',
              key: const ValueKey('update-check'), onPressed: _c.check),
        );
      case UpdatePhase.available:
      case UpdatePhase.downloading:
      case UpdatePhase.installing:
      case UpdatePhase.failed:
        return _available(rel!, current);
    }
  }

  Widget _compact(ReleaseInfo? rel) {
    switch (_c.phase) {
      case UpdatePhase.available:
        return _updateButton('ACTUALIZAR');
      case UpdatePhase.failed when rel != null:
        return _updateButton('REINTENTAR');
      case UpdatePhase.downloading:
        return _compactLine(
            'Descargando ${(_c.progress * 100).floor()}%',
            const ValueKey('update-progress'));
      case UpdatePhase.installing:
        return _compactLine(
            'Instalando', const ValueKey('update-installing'));
      case UpdatePhase.checking:
        return _compactCheck('buscando', busy: true);
      case UpdatePhase.upToDate:
        return _compactCheck(_c.message ?? 'al día');
      case UpdatePhase.failed:
        return _compactCheck(_c.message ?? 'error', retry: true);
      case UpdatePhase.idle:
        return _compactCheck(null);
    }
  }

  /// Versión instalada + BUSCAR (o REINTENTAR), sin cortar con "…".
  Widget _compactCheck(String? status,
      {bool busy = false, bool retry = false}) {
    final current = 'v${_c.service.currentVersion}';
    return Wrap(
      key: const ValueKey('update-line'),
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ProtoText(
            '$current${status == null ? '' : ' · ${protoEsc(status)}'}',
            style: const TextStyle(color: ProtoColors.dim)),
        PanelButton(retry ? 'REINTENTAR' : 'BUSCAR',
            key: const ValueKey('update-check'),
            onPressed: busy ? null : _c.check),
      ],
    );
  }

  Widget _compactLine(String text, Key key) => ProtoText(protoEsc(text),
      key: key, style: const TextStyle(color: ProtoColors.dim));

  Widget _line(String markup, Widget button) => Row(
        key: const ValueKey('update-line'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: ProtoText(markup,
                style: const TextStyle(color: ProtoColors.dim),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          button,
        ],
      );

  Widget _available(ReleaseInfo rel, String current) {
    final notes = rel.notes.isEmpty ? 'Sin notas.' : rel.notes;
    return RetroPanel(
      key: const ValueKey('update-available'),
      selected: true,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ProtoText('Actualización disponible <b>v${rel.version}</b> '
              '<span style="color:#7d8bc4">(tenés $current)</span>'),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 120),
            child: SingleChildScrollView(
              child: ProtoText(protoEsc(notes),
                  style: const TextStyle(color: ProtoColors.chat)),
            ),
          ),
          const SizedBox(height: 8),
          ..._footer(),
        ],
      ),
    );
  }

  List<Widget> _footer() {
    switch (_c.phase) {
      case UpdatePhase.downloading:
        final pct = (_c.progress * 100).floor();
        return [
          ProtoText('Descargando… $pct%',
              key: const ValueKey('update-progress')),
          const SizedBox(height: 4),
          RetroBar(value: _c.progress, max: 1, color: ProtoColors.gold),
        ];
      case UpdatePhase.installing:
        return const [
          ProtoText('Instalando… el juego se cierra y se vuelve a abrir solo.',
              key: ValueKey('update-installing'),
              style: TextStyle(color: ProtoColors.green)),
        ];
      case UpdatePhase.failed:
        return [
          ProtoText(protoEsc(_c.message ?? 'Error'),
              style: const TextStyle(color: ProtoColors.red)),
          const SizedBox(height: 8),
          _updateButton('REINTENTAR'),
        ];
      default:
        return [_updateButton('ACTUALIZAR')];
    }
  }

  Widget _updateButton(String label) => Align(
        alignment: Alignment.centerRight,
        child: PanelButton(label,
            key: const ValueKey('update-apply'),
            accent: ProtoColors.gold,
            reason: _c.service.canInstall
                ? null
                : 'Solo en Windows: bajalo de la página del release',
            onPressed: _c.update),
      );
}
