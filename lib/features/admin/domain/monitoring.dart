import 'dart:convert';

/// Modelos y lectores puros del monitoreo (docs/specs/balance_admin.md
/// § 6). Sin red: los clientes de `data/` pasan el texto.

/// Un asset de un release de GitHub.
class GithubAsset {
  const GithubAsset(this.name, this.downloads, this.size);
  final String name;
  final int downloads;
  final int size;
}

/// Un release de GitHub (`GET /repos/:owner/:repo/releases`).
class GithubRelease {
  const GithubRelease({
    required this.tag,
    required this.name,
    required this.publishedAt,
    required this.prerelease,
    required this.draft,
    required this.assets,
    required this.url,
  });

  final String tag;
  final String name;
  final DateTime? publishedAt;
  final bool prerelease;
  final bool draft;
  final List<GithubAsset> assets;
  final String url;

  int get downloads => assets.fold(0, (n, a) => n + a.downloads);

  /// Descargas del instalador (`.exe`), sin contar el `.sha256`.
  int get installerDownloads => assets
      .where((a) => a.name.toLowerCase().endsWith('.exe'))
      .fold(0, (n, a) => n + a.downloads);

  /// Lee la respuesta JSON de la API. Entradas raras se saltean.
  static List<GithubRelease> parseList(String body) {
    final raw = jsonDecode(body);
    if (raw is! List) {
      throw FormatException(raw is Map && raw['message'] is String
          ? raw['message'] as String
          : 'respuesta inesperada de GitHub');
    }
    return [
      for (final r in raw)
        if (r is Map && r['tag_name'] is String)
          GithubRelease(
            tag: r['tag_name'] as String,
            name: r['name'] is String ? r['name'] as String : '',
            publishedAt: r['published_at'] is String
                ? DateTime.tryParse(r['published_at'] as String)
                : null,
            prerelease: r['prerelease'] == true,
            draft: r['draft'] == true,
            url: r['html_url'] is String ? r['html_url'] as String : '',
            assets: [
              for (final a in (r['assets'] is List ? r['assets'] as List : const []))
                if (a is Map)
                  GithubAsset(
                    a['name'] is String ? a['name'] as String : '?',
                    a['download_count'] is int ? a['download_count'] as int : 0,
                    a['size'] is int ? a['size'] as int : 0,
                  ),
            ],
          ),
    ];
  }
}

/// Una línea de `ecos.log` (`<ISO-8601> <NIVEL> <mensaje>`).
class LogLine {
  const LogLine(this.time, this.level, this.message, this.raw);
  final DateTime? time;
  final String level;
  final String message;
  final String raw;

  static final _re = RegExp(r'^(\S+)\s+(INFO|ERROR|WARN|DEBUG)\s(.*)$');

  static LogLine parse(String raw) {
    final m = _re.firstMatch(raw);
    if (m == null) return LogLine(null, '', raw, raw);
    return LogLine(DateTime.tryParse(m.group(1)!), m.group(2)!, m.group(3)!, raw);
  }

  static List<LogLine> parseAll(String text) => [
        for (final l in const LineSplitter().convert(text))
          if (l.trim().isNotEmpty) parse(l),
      ];
}

/// Resultado de contar las salas de señalización.
class RoomCount {
  const RoomCount.ok(this.count) : denied = false, error = null;
  const RoomCount.denied()
      : count = null,
        denied = true,
        error = null;
  const RoomCount.failed(this.error)
      : count = null,
        denied = false;

  final int? count;

  /// Las reglas no permiten `list` sobre `rooms` (lo esperado hoy).
  final bool denied;
  final String? error;

  /// Lee la respuesta de `runAggregationQuery` (lista de resultados con
  /// `result.aggregateFields.n.integerValue`).
  static RoomCount parse(int status, String body) {
    if (status == 403) return const RoomCount.denied();
    if (status != 200) return RoomCount.failed('HTTP $status');
    try {
      final raw = jsonDecode(body);
      final first = raw is List && raw.isNotEmpty ? raw.first : raw;
      final v = first['result']['aggregateFields']['n']['integerValue'];
      return RoomCount.ok(int.parse('$v'));
    } on Object catch (e) {
      return RoomCount.failed('respuesta inesperada: $e');
    }
  }
}

/// Lo que se sabe de una sala buscada por código (`get` permitido).
class RoomInfo {
  const RoomInfo({
    required this.code,
    required this.exists,
    this.createdAt,
    this.expiresAt,
    this.peers = 0,
    this.version,
  });

  final String code;
  final bool exists;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final int peers;
  final int? version;

  bool expiredAt(DateTime now) => expiresAt != null && expiresAt!.isBefore(now);
}

/// Qué haría falta en `firestore.rules` para contar salas (no se aplica).
const kRoomCountRulesHelp =
    'Las reglas desplegadas tienen "allow list: if false" en /rooms, así '
    'que nadie (tampoco el admin) puede listar ni contar salas. No se '
    'cambiaron. Opciones: (1) login del admin con Firebase Auth y '
    '"allow list: if request.auth.uid == \'<uid del dueño>\'"; (2) un '
    'documento contador stats/rooms que los hosts incrementan al crear la '
    'sala (FieldValue.increment) con regla de solo +1; (3) una Cloud '
    'Function programada que cuente con credenciales de servidor y escriba '
    'el total en un documento público de solo lectura.';
