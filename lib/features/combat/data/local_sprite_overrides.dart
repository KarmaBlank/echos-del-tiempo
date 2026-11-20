// `dart:io` en escritorio; en web no hay overrides locales
// (docs/specs/game_editor.md § 4.2).
export 'local_sprite_overrides_stub.dart'
    if (dart.library.io) 'local_sprite_overrides_io.dart';
