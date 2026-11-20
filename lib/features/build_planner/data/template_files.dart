import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

/// Diálogos de archivo de las plantillas de BUILD (exportar / importar
/// para compartir con amigos; build_planner_v2.md § 2.2). Inyectable en
/// los tests (nunca tocan el disco real).
abstract class TemplateFiles {
  /// Texto del archivo elegido, o `null` si se canceló.
  Future<String?> pickYaml();

  /// `false` si se canceló.
  Future<bool> saveYaml(String text, String suggestedName);
}

/// Diálogos reales (`file_selector`).
class FileSelectorTemplateFiles implements TemplateFiles {
  const FileSelectorTemplateFiles();

  static const _group =
      XTypeGroup(label: 'Plantillas de BUILD', extensions: ['yaml', 'yml']);

  /// Tope de lo que se lee (un archivo de plantillas pesa pocos KB).
  static const maxBytes = 512 * 1024;

  @override
  Future<String?> pickYaml() async {
    final f = await openFile(acceptedTypeGroups: const [_group]);
    if (f == null) return null;
    final bytes = await f.readAsBytes();
    if (bytes.length > maxBytes) return null;
    return utf8.decode(bytes, allowMalformed: true);
  }

  @override
  Future<bool> saveYaml(String text, String suggestedName) async {
    final loc = await getSaveLocation(
        suggestedName: suggestedName, acceptedTypeGroups: const [_group]);
    if (loc == null) return false;
    await XFile.fromData(Uint8List.fromList(utf8.encode(text)),
            mimeType: 'text/yaml', name: suggestedName)
        .saveTo(loc.path);
    return true;
  }
}
