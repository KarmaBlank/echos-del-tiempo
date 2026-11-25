import 'package:echos_del_tiempo/features/world/presentation/panels/biome_npc_panel.dart';
import 'package:echos_del_tiempo/features/world/presentation/world_strings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Regression: "Orden de Brann" showed "5 × ingot_copper".
  test('resident order names resolve smithing / mine items', () {
    final s = worldFallbackStrings();
    expect(residentItemName('ingot_copper', s), 'Lingote de cobre');
    expect(residentItemName('ingot_copper'), 'Lingote de cobre');
    expect(residentItemName('mine_torch', s), 'Antorcha de mina');
    expect(residentItemName('no_such_item', s), 'No such item');
  });
}
