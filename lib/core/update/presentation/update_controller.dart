import 'package:flutter/foundation.dart';

import '../release_info.dart';
import '../update_service.dart';

/// En qué anda el actualizador (lo que dibuja [UpdateBanner]).
enum UpdatePhase {
  /// Todavía no buscó (build de desarrollo sin búsqueda automática).
  idle,
  checking,
  upToDate,
  available,
  downloading,
  installing,

  /// Falló la búsqueda o la descarga; [UpdateController.message] dice qué.
  failed,
}

/// Estado del auto-actualizador para la UI. Ver docs/specs/distribution.md
/// § "Flujo de actualización".
class UpdateController extends ChangeNotifier {
  UpdateController(this.service);

  final UpdateService service;

  UpdatePhase _phase = UpdatePhase.idle;
  UpdatePhase get phase => _phase;

  ReleaseInfo? _release;

  /// El release nuevo (desde que se detectó, también durante la descarga
  /// y si la descarga falla, para poder reintentar).
  ReleaseInfo? get release => _release;

  String? _message;

  /// Motivo de [UpdatePhase.failed], o detalle de [UpdatePhase.upToDate].
  String? get message => _message;

  double _progress = 0;

  /// 0..1 durante [UpdatePhase.downloading].
  double get progress => _progress;

  bool _disposed = false;

  bool get busy =>
      _phase == UpdatePhase.checking ||
      _phase == UpdatePhase.downloading ||
      _phase == UpdatePhase.installing;

  void _set(UpdatePhase p, {String? message}) {
    _phase = p;
    _message = message;
    if (!_disposed) notifyListeners();
  }

  /// Busca un release nuevo. Nunca lanza: sin red queda en `failed`.
  Future<void> check() async {
    if (busy) return;
    _set(UpdatePhase.checking);
    final r = await service.check();
    if (_disposed) return;
    switch (r) {
      case UpdateAvailable(:final release):
        _release = release;
        _set(UpdatePhase.available);
      case UpToDate(:final latest):
        _release = null;
        _set(UpdatePhase.upToDate,
            message: latest == null ? 'Todavía no hay versiones publicadas.' : null);
      case UpdateCheckFailed(:final message):
        _release = null;
        _set(UpdatePhase.failed, message: message);
    }
  }

  /// Baja el instalador, lo verifica y lo lanza (cierra el juego).
  Future<void> update() async {
    final rel = _release;
    if (rel == null || busy) return;
    _progress = 0;
    _set(UpdatePhase.downloading);
    try {
      final file = await service.download(rel, onProgress: (got, total) {
        _progress = total <= 0 ? 0 : got / total;
        if (!_disposed) notifyListeners();
      });
      if (_disposed) return;
      _set(UpdatePhase.installing);
      await service.installAndExit(file);
    } on UpdateFailure catch (e) {
      _set(UpdatePhase.failed, message: e.message);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
