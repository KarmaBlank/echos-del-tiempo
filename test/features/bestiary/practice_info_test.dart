import 'package:echos_del_tiempo/features/bestiary/presentation/enemy_info_card.dart';
import 'package:echos_del_tiempo/game_engine/models/bestiary.dart';
import 'package:echos_del_tiempo/game_engine/rules/tutorial_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// La ficha del autómata del TUTORIAL es la suya, no la del Gólem cuyo
/// dibujo usa (combat_tutorial.md § 3).
void main() {
  test('la ficha del autómata dice su nombre y sus afinidades', () {
    final a = const TutorialRules().automaton(1);
    final m = EnemyInfoCard.markupFor(a, BestiaryProgress());
    expect(m, contains('Autómata de entrenamiento'));
    expect(m, isNot(contains('Gólem')));
    expect(m, contains('Fuego'));
    expect(m, isNot(contains('Electro')));
    expect(m, isNot(contains('Derrotados')));
  });
}
