// `dart:io` en escritorio; stub en web (docs/specs/balance_admin.md § 5).
export 'admin_host_stub.dart' if (dart.library.io) 'admin_host_io.dart'
    show createAdminHost;
