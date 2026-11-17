import 'net_session.dart';

/// Lo que cada composition root registra para decir si este build tiene
/// red y cuál. El título la usa para habilitar `CREAR SALA` / `UNIRSE`
/// (docs/specs/exploration.md § "Título"); cada sala usa una
/// [NetSession] nueva de [create].
class NetSessionFactory {
  const NetSessionFactory({
    required this.label,
    required this.codeHint,
    required NetSession Function() create,
    this.unavailableReason,
  }) : _create = create;

  /// Una que nunca está disponible, con el motivo para mostrar.
  factory NetSessionFactory.unavailable(String label, String reason) =>
      NetSessionFactory(
        label: label,
        codeHint: 'CODIGO',
        unavailableReason: reason,
        create: () => throw StateError(reason),
      );

  /// Nombre corto del modo de red (`LAN`, `P2P`).
  final String label;

  /// Qué se escribe en el campo de código (`IP:PUERTO`, `CODIGO`).
  final String codeHint;

  /// `null` = disponible; si no, por qué no (se muestra en el título).
  final String? unavailableReason;

  final NetSession Function() _create;

  bool get available => unavailableReason == null;

  NetSession create() => _create();
}
