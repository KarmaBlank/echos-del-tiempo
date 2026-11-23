import 'package:echos_del_tiempo/game_engine/models/fog_of_war.dart';
import 'package:flutter_test/flutter_test.dart';

/// Niebla de exploración de las mazmorras oscuras (lighting.md § 5.4).
void main() {
  double Function(int, int) litAround(int cx, int cy) =>
      (x, y) => (x - cx).abs() <= 1 && (y - cy).abs() <= 1 ? 1 : 0;

  test('lo explorado se recuerda; lo visible es solo lo de este cuadro', () {
    final f = FogOfWar()..begin(('m', 1), 20, 20);
    expect(f.active, isTrue);
    f.reveal(0, 0, 20, 20, litAround(3, 3), 0.12);
    expect(f.explored(3, 3), isTrue);
    expect(f.visible(3, 3), isTrue);
    expect(f.explored(10, 10), isFalse);

    f.reveal(0, 0, 20, 20, litAround(10, 10), 0.12);
    expect(f.explored(3, 3), isTrue, reason: 'el mapa recuerda');
    expect(f.visible(3, 3), isFalse, reason: 'ya no está a la vista');
    expect(f.visible(10, 10), isTrue);
  });

  test('la versión sube solo al descubrir; otra misión borra todo', () {
    final f = FogOfWar()..begin(('m', 1), 10, 10);
    f.reveal(0, 0, 10, 10, litAround(2, 2), 0.12);
    final v = f.version;
    f.reveal(0, 0, 10, 10, litAround(2, 2), 0.12);
    expect(f.version, v);
    f.begin(('m', 1), 10, 10);
    expect(f.explored(2, 2), isTrue, reason: 'misma misión: sigue');
    f.begin(('m', 2), 10, 10);
    expect(f.explored(2, 2), isFalse);
    f.reset();
    expect(f.active, isFalse);
  });

  test('ventana corrida y fuera del mapa no rompen', () {
    final f = FogOfWar()..begin(('m', 1), 8, 8);
    f.reveal(-16, -16, 32, 32, (_, __) => 1, 0.12);
    expect(f.explored(0, 0), isTrue);
    expect(f.explored(7, 7), isTrue);
    expect(f.explored(-1, 0), isFalse);
  });
}
