import 'package:echos_del_tiempo/features/combat/presentation/combat_strings.dart';
import 'package:echos_del_tiempo/features/combat/presentation/enemy_live_info.dart';
import 'package:echos_del_tiempo/game_engine/data/elite_ults_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

/// The ULT tooltip lists secondary statuses too: a 30% stun on top of
/// the main one fills the break bar (combat.md § "Control sobre
/// jugadores").
void main() {
  test('Mirada Eléctrica menciona su aturdido secundario del 30%', () {
    final s = fallbackCombatStrings();
    final u = kEliteUlts['eult_e_ojoAbismo']!;
    final txt = EnemyLiveInfo.ultDetail(s, u);
    expect(txt, contains(s.t('ui.combat.enemy.ult_break_fill', {'pct': '30%: '})));
  });
}
