import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/export_sprites.dart';

/// `0xRRGGBBAA` opaco a partir de `#rrggbb`.
int opaque(String hex) => (parseHex(hex) << 8) | 0xff;

void main() {
  group('shade (puerto de JS)', () {
    test('oscurece ×0.78 con Math.round', () {
      // 0x4c=76→59.28→59, 0xd1=209→163.02→163, 0x37=55→42.9→43
      expect(shade('#4cd137', 0.78), '#3ba32b');
    });
    test('aclara ×1.2 y recorta en 255', () {
      // 0xe8=232→278.4→255, 0x43=67→80.4→80, 0x93=147→176.4→176
      expect(shade('#e84393', 1.2), '#ff50b0');
    });
    test('expande hex de 3 dígitos como CSS', () {
      expect(parseHex('#111'), 0x111111);
    });
  });

  group('makeSprite', () {
    test('agrega 1 px de contorno a cada lado', () {
      final s = enemySprite('slime');
      expect(s.width, 18);
      expect(s.height, 14);
      expect(heroSprite('guerrero').width, 14);
      expect(heroSprite('guerrero').height, 18);
    });

    test('contorno #0d0d14 sobre la primera celda llena del limo', () {
      // Fila 1 "......XXXX......": la celda (6,0) está vacía y tiene la
      // (6,1) llena debajo → contorno en el píxel (7,1).
      final s = enemySprite('slime');
      expect(s.rgbaAt(7, 1), opaque('#0d0d14'));
      // Esquina sin vecinos llenos: transparente.
      expect(s.rgbaAt(0, 0), 0);
    });

    test('la diagonal no genera contorno', () {
      // Píxel (6,1) del limo: celda (5,0), su único vecino lleno es la
      // diagonal (6,1).
      expect(enemySprite('slime').rgbaAt(6, 1), 0);
    });

    test('fila inferior del limo sombreada ×0.78', () {
      // Última fila (j=11 > 12*0.6) "..XXXXXXXXXXXX..", celda (2,11).
      expect(enemySprite('slime').rgbaAt(3, 12), opaque('#3ba32b'));
    });

    test('dos filas superiores aclaradas ×1.2 (con clamp)', () {
      // Fila 0 del fantasma ".....XXXX.....", celda (5,0), color del
      // Devorador #e84393.
      expect(enemySprite('devorador').rgbaAt(6, 1), opaque('#ff50b0'));
    });

    test('filas del medio usan el color sin sombrear', () {
      // Limo fila 6 ".XXXXXXXXXXXXXX." (6 <= 7.2), celda (1,6).
      expect(enemySprite('slime').rgbaAt(2, 7), opaque('#4cd137'));
    });

    test('ojos del enemigo usan W y O de la paleta fija', () {
      // Limo fila 4 "..XXXWWXXXWWXX..": celda (5,4) = W.
      expect(enemySprite('slime').rgbaAt(6, 5), opaque('#ffffff'));
      // Fila 5 "..XXXOWXXXOWXX..": celda (5,5) = O (#111).
      expect(enemySprite('slime').rgbaAt(6, 6), opaque('#111111'));
    });

    test('el héroe usa la paleta de su clase', () {
      // Fila 0 "....HHHH....", celda (4,0) = pelo.
      expect(heroSprite('guerrero').rgbaAt(5, 1), opaque('#6b3a1e'));
      expect(heroSprite('paladin').rgbaAt(5, 1), opaque('#d4af37'));
      // Fila 6 "..BBBBBBBB..", celda (2,6) = ropa.
      expect(heroSprite('maga').rgbaAt(3, 7), opaque('#2e5aac'));
    });

    test('los jefes reusan la forma base con su color', () {
      final base = enemySprite('golem'), boss = enemySprite('golemReloj');
      expect(boss.width, base.width);
      expect(boss.height, base.height);
      // Fila 3 "...XXXXXXXXXX...", celda (3,3): color sin sombrear.
      expect(boss.rgbaAt(4, 4), opaque('#d4a017'));
      // Ojos R del gólem.
      expect(boss.rgbaAt(6, 3), opaque('#ff3b3b'));
    });
  });

  group('PNG', () {
    test('CRC32 de referencia', () {
      expect(crc32('123456789'.codeUnits), 0xcbf43926);
    });

    test('firma, IHDR (ancho, alto, RGBA 8 bits) e IEND', () {
      final png = encodePng(enemySprite('bat'));
      expect(png.sublist(0, 8), [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
      expect(String.fromCharCodes(png.sublist(12, 16)), 'IHDR');
      expect(png.sublist(16, 26), [0, 0, 0, 18, 0, 0, 0, 12, 8, 6]);
      expect(String.fromCharCodes(png.sublist(png.length - 8, png.length - 4)), 'IEND');
    });

    test('exporta las 11 rutas del manifest', () {
      // No compara bytes con los archivos del repo a propósito: el arte
      // puede reemplazarse a mano (docs/specs/sprites.md).
      expect(buildAllSprites().keys, hasLength(11));
      for (final path in buildAllSprites().keys) {
        expect(File('assets/sprites/$path').existsSync(), isTrue, reason: path);
      }
    });
  });
}
