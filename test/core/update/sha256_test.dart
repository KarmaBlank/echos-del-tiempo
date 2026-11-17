import 'dart:convert';

import 'package:echos_del_tiempo/core/update/sha256.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('vectores de FIPS 180-4', () {
    expect(Sha256.of([]),
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
    expect(Sha256.of(ascii.encode('abc')),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
    expect(
        Sha256.of(ascii.encode(
            'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq')),
        '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1');
  });

  test('por trozos = de una vez (cruza bloques de 64)', () {
    final data = List<int>.generate(1000003, (i) => (i * 31 + 7) & 0xff);
    final h = Sha256();
    for (var i = 0; i < data.length; i += 4097) {
      h.add(data.sublist(i, i + 4097 > data.length ? data.length : i + 4097));
    }
    expect(h.close(), Sha256.of(data));
    // Un millón de 'a' (vector largo conocido).
    expect(Sha256.of(List.filled(1000000, 0x61)),
        'cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0');
  });

  test('archivo .sha256 estilo sha256sum', () {
    const hex =
        'E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855';
    expect(parseSha256File('$hex  EcosDelTiempo-Setup-0.1.0.exe\n'),
        hex.toLowerCase());
    expect(parseSha256File(hex), hex.toLowerCase());
    expect(parseSha256File('no hay hash'), isNull);
  });
}
