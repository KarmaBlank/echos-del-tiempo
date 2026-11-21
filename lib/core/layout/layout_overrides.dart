// `dart:io` en escritorio; en web no hay overrides locales de layouts
// (docs/specs/editor_layout.md § 2.6).
export 'layout_overrides_stub.dart'
    if (dart.library.io) 'layout_overrides_io.dart';
