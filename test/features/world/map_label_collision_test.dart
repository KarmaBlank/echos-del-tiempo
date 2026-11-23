import 'package:echos_del_tiempo/features/world/presentation/map/map_labels.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('sin choques quedan donde estaban', () {
    final r = placeLabels(
        [const Rect.fromLTWH(0, 0, 50, 10), const Rect.fromLTWH(60, 0, 50, 10)],
        [0, 1]);
    expect(r, [0.0, 0.0]);
  });

  test('la de menor prioridad sube un renglón', () {
    final r = placeLabels(
        [const Rect.fromLTWH(0, 20, 50, 10), const Rect.fromLTWH(30, 20, 50, 10)],
        [1, 0]);
    expect(r[1], 0.0);
    expect(r[0], -12.0);
  });

  test('si no entra en ningún renglón se oculta', () {
    final boxes = List.generate(5, (_) => const Rect.fromLTWH(0, 40, 50, 10));
    final r = placeLabels(boxes, [0, 1, 2, 3, 4]);
    expect(r.take(4).every((d) => d != null), isTrue);
    expect(r[4], isNull);
  });
}
