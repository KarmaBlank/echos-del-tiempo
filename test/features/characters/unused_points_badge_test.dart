import 'package:echos_del_tiempo/features/characters/domain/unused_points.dart';
import 'package:flutter_test/flutter_test.dart';

/// v0.20.16: la insignia de PERSONAJE cuenta solo lo que se reparte ahí
/// (atributos, árbol, compañeros); la ascensión va en el tooltip.
void main() {
  test('la ascensión no suma a la insignia de PERSONAJE', () {
    const u = UnusedPoints(tree: 1, ascension: 2);
    expect(u.characterTotal, 1);
    expect(u.any, isTrue);
    expect(u.parts, contains('2 puntos de ascensión'));
  });
}
