import '../../../game_engine/data/classes_catalog.dart';
import '../../../game_engine/data/weapons_catalog.dart';
import '../../../game_engine/models/attributes.dart';
import '../../../game_engine/models/battle_state.dart';
import '../../../game_engine/models/player_state.dart';
import 'battle_controller.dart';

/// Batalla de prueba local: las 4 clases en nivel 1 con su arma inicial
/// contra un grupo de la Pradera Esmeralda. Reemplazo temporal hasta que
/// existan el lobby, los personajes guardados y las misiones.
BattleSetup demoBattleSetup() {
  BattlePartyMember member(String classId) {
    final cls = kClasses[classId]!;
    return BattlePartyMember(
      id: classId,
      name: cls.name,
      potions: 2,
      ethers: 1,
      build: PlayerBuild(
        classId: classId,
        level: 1,
        attributes: PlayerAttributes.base(cls.baseAttributes),
        equippedWeapon: kWeapons[cls.startWeaponId]!,
      ),
    );
  }

  return BattleSetup(
    party: [
      member('guerrero'),
      member('maga'),
      member('tirador'),
      member('paladin'),
    ],
    enemyTypes: const ['slime', 'bat', 'golem'],
    triggeredBy: 'guerrero',
  );
}
