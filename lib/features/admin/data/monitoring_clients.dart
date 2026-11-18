import 'dart:convert';

import '../../../netcode/p2p_webrtc/firestore_rest_codec.dart';
import '../domain/admin_host.dart';
import '../domain/monitoring.dart';

/// Releases públicos de GitHub (sin token, 60 pedidos/hora).
class GithubReleasesClient {
  GithubReleasesClient(this.host);
  final AdminHost host;

  static final endpoint = Uri.parse(
      'https://api.github.com/repos/KarmaBlank/echos-del-tiempo/releases?per_page=30');

  Future<List<GithubRelease>> fetch() async {
    final r = await host.http('GET', endpoint,
        headers: {'Accept': 'application/vnd.github+json'});
    if (!r.ok) {
      throw StateError('GitHub respondió ${r.status}: '
          '${r.body.length > 200 ? r.body.substring(0, 200) : r.body}');
    }
    return GithubRelease.parseList(r.body);
  }
}

/// Lectura de la señalización de Firestore por REST (como
/// `FirestoreRestSignaling`), sin escribir nada.
class FirestoreMonitor {
  FirestoreMonitor(this.host, {required this.projectId, required this.apiKey});

  final AdminHost host;
  final String projectId;
  final String apiKey;

  Uri _uri(String path) => Uri.https(
        'firestore.googleapis.com',
        '/v1/projects/$projectId/databases/(default)/documents$path',
        {'key': apiKey},
      );

  /// Cuenta las salas (hoy las reglas lo prohíben: [RoomCount.denied]).
  Future<RoomCount> countRooms() async {
    try {
      final r = await host.http('POST', _uri(':runAggregationQuery'),
          body: jsonEncode({
            'structuredAggregationQuery': {
              'structuredQuery': {
                'from': [
                  {'collectionId': 'rooms'}
                ],
              },
              'aggregations': [
                {'alias': 'n', 'count': {}}
              ],
            },
          }));
      return RoomCount.parse(r.status, r.body);
    } on Object catch (e) {
      return RoomCount.failed('$e');
    }
  }

  /// Una sala por código (`get` y `list` de `peers` están permitidos).
  Future<RoomInfo> room(String code) async {
    final c = code.trim().toUpperCase();
    final r = await host.http('GET', _uri('/rooms/$c'));
    if (r.status == 404) return RoomInfo(code: c, exists: false);
    if (!r.ok) throw StateError('Firestore respondió ${r.status}');
    final fields =
        FirestoreRestCodec.decodeFields((jsonDecode(r.body) as Map)['fields']);
    var peers = 0;
    final p = await host.http('GET', _uri('/rooms/$c/peers'));
    if (p.ok) {
      final docs = (jsonDecode(p.body) as Map)['documents'];
      peers = docs is List ? docs.length : 0;
    }
    DateTime? date(Object? v) => v is DateTime
        ? v
        : v is String
            ? DateTime.tryParse(v)
            : null;
    return RoomInfo(
      code: c,
      exists: true,
      createdAt: date(fields['createdAt']),
      expiresAt: date(fields['expiresAt']),
      version: fields['v'] is int ? fields['v'] as int : null,
      peers: peers,
    );
  }
}
