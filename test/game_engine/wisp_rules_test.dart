import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/rules/light_rules.dart';
import 'package:echos_del_tiempo/game_engine/serialization/action_json.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Llama errante agranda la luz que lleva el jugador', () {
    final base = LightRules.carried(dark: true);
    final lit =
        LightRules.carried(dark: true, bonus: LightRules.wispBonusFor(true));
    expect(lit.radius, base.radius + LightRules.wispBonus);
    expect(LightRules.wispBonusFor(false), 0);
  });

  test('Llama errante: solo en lo oscuro te detectan de más lejos', () {
    expect(LightRules.aggroFactor(wisp: true, dark: true), greaterThan(1));
    expect(LightRules.aggroFactor(wisp: true, dark: false), 1);
    expect(LightRules.aggroFactor(wisp: false, dark: true), 1);
  });

  test('La acción wisp va y vuelve por la red', () {
    for (final on in [true, false]) {
      final back = ActionJson.fromJson(ActionJson.toJson(WispAction(on)));
      expect((back as WispAction).on, on);
    }
  });
}
