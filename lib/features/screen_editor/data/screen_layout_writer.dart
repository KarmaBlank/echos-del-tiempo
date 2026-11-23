// `dart:io` en escritorio; en web el editor de pantallas no guarda en
// disco (docs/specs/screen_editor.md § 5).
export 'screen_layout_writer_stub.dart'
    if (dart.library.io) 'screen_layout_writer_io.dart';
