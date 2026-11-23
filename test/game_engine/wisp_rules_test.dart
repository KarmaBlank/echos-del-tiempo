import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/rules/light_rules.dart';
import 'package:echos_del_tiempo/game_engine/serialization/action_json.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Llama errante agranda la luz que lleva el jugador', () {
    for (final dark in [true, false]) {
      final base = LightRules.carried(dark: dark);
      final lit = LightRules.carried(dark: dark, wisp: true);
      expect(lit.radius, base.radius + LightRules.wispBonus);
      expect(lit.intensity, greaterThanOrEqualTo(base.intensity));
      // Lo que se ve de verdad (sobre el umbral de penumbra) crece claro.
      expect(LightRules.visibleRadius(lit),
          greaterThan(LightRules.visibleRadius(base) + 2.5));
    }
  });

  test('Llama errante: sola de noche afuera, con L en mazmorras', () {
    expect(LightRules.wispActive(toggled: false, outdoor: true, night: true),
        isTrue);
    expect(LightRules.wispActive(toggled: true, outdoor: true, night: false),
        isFalse);
    expect(LightRules.wispActive(toggled: true, outdoor: false, night: false),
        isTrue);
    expect(LightRules.wispActive(toggled: false, outdoor: false, night: true),
        isFalse);
  });

  test('Llama errante: solo en mazmorras oscuras te detectan de más lejos',
      () {
    expect(LightRules.aggroFactor(wisp: true, dark: true), greaterThan(1));
    expect(LightRules.aggroFactor(wisp: true, dark: true, outdoor: true), 1);
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
