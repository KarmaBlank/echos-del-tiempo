// Prueba de humo de la señalización REST contra el proyecto Firebase REAL
// (docs/specs/netcode.md § "Señalización REST en escritorio"). No es parte
// de `flutter test`: escribe en Firestore.
//
//   dart run tool/p2p_signaling_smoke.dart
//
// Crea una sala, una oferta, una respuesta y un candidato ICE de cada lado,
// verifica que vuelvan iguales y borra todo lo que creó (y comprueba que
// no quedó nada). Toma `projectId` y `apiKey` de la configuración de
// Windows en lib/firebase_options.dart.
// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:echos_del_tiempo/netcode/p2p_webrtc/firestore_rest_signaling.dart';

const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

Future<void> main() async {
  final opts = File('lib/firebase_options.dart').readAsStringSync();
  final windows = opts.substring(opts.indexOf('FirebaseOptions windows'));
  String field(String name) =>
      RegExp("$name: '([^']+)'").firstMatch(windows)!.group(1)!;
  final projectId = field('projectId');
  final sig =
      FirestoreRestSignaling(projectId: projectId, apiKey: field('apiKey'));
  final rnd = math.Random.secure();
  final code =
      List.generate(5, (_) => _alphabet[rnd.nextInt(_alphabet.length)]).join();
  final sw = Stopwatch()..start();
  void step(String s) =>
      print('[${sw.elapsedMilliseconds.toString().padLeft(5)} ms] $s');

  var ok = true;
  void check(bool cond, String what) {
    step('${cond ? 'OK  ' : 'FALLA'} $what');
    ok &= cond;
  }

  var created = false;
  String? peerId;
  try {
    step('proyecto $projectId, sala $code');
    created = await sig.createRoom(code);
    check(created, 'createRoom($code)');
    check(!await sig.createRoom(code), 'createRoom repetido devuelve false');
    check(await sig.roomExists(code), 'roomExists');

    final offers = sig.watchOffers(code).first;
    final id = peerId = await sig.createPeer(code, 'smoke-offer-sdp', 'offer');
    step('peer creado: $id');
    final offer = await offers.timeout(const Duration(seconds: 10));
    check(offer.peerId == id && offer.sdp == 'smoke-offer-sdp',
        'el host ve la oferta por consulta');

    final answer = sig.watchAnswer(code, id).first;
    await sig.publishAnswer(code, id, 'smoke-answer-sdp', 'answer');
    final a = await answer.timeout(const Duration(seconds: 10));
    check(a.sdp == 'smoke-answer-sdp' && a.type == 'answer',
        'el cliente ve la respuesta');

    Map<String, dynamic> cand(String c) =>
        {'candidate': c, 'sdpMid': '0', 'sdpMLineIndex': 0};
    final atHost = sig.watchCandidates(code, id, fromHost: false).first;
    final atClient = sig.watchCandidates(code, id, fromHost: true).first;
    await sig.addCandidate(code, id,
        fromHost: false, candidate: cand('candidate:smoke-client'));
    await sig.addCandidate(code, id,
        fromHost: true, candidate: cand('candidate:smoke-host'));
    final ch = await atHost.timeout(const Duration(seconds: 10));
    final hc = await atClient.timeout(const Duration(seconds: 10));
    check(
        ch['candidate'] == 'candidate:smoke-client' && ch['sdpMLineIndex'] == 0,
        'candidato cliente → host');
    check(hc['candidate'] == 'candidate:smoke-host' && hc['sdpMid'] == '0',
        'candidato host → cliente');
  } on Object catch (e) {
    ok = false;
    step('ERROR: $e');
  } finally {
    if (created) {
      try {
        await sig.closeRoom(code);
        check(!await sig.roomExists(code), 'closeRoom: la sala ya no existe');
        // Lectura directa por REST de lo que pudo quedar (las reglas
        // permiten listar peers y candidatos, no salas).
        final base = 'https://firestore.googleapis.com/v1/projects/$projectId'
            '/databases/(default)/documents/rooms/$code/peers';
        final paths = [
          base,
          if (peerId != null) ...[
            '$base/$peerId/clientCandidates',
            '$base/$peerId/hostCandidates',
          ],
        ];
        final http = HttpClient();
        for (final p in paths) {
          final rq = await http.getUrl(Uri.parse('$p?key=${field('apiKey')}'));
          final rs = await rq.close();
          final body =
              await rs.transform(const SystemEncoding().decoder).join();
          check(rs.statusCode == 200 && !body.contains('"documents"'),
              'vacío: ${p.substring(p.indexOf('rooms/'))}');
        }
        http.close();
      } on Object catch (e) {
        ok = false;
        step('ERROR limpiando: $e');
      }
    }
    sig.close();
  }
  print(ok ? 'RESULTADO: OK' : 'RESULTADO: FALLA');
  exitCode = ok ? 0 : 1;
}
