import 'package:echos_del_tiempo/features/world/presentation/map/map_labels.dart';
import 'package:echos_del_tiempo/game_engine/data/tuning_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

/// World labels show only near the player (ui_style.md § "Etiquetas en el
/// mundo", v0.49.9): one rule for NPC names and place labels alike.
void main() {
  const ts = 16.0;
  final range = tuning(TuningId.town).d('labelRevealTiles');

  test('NPC label: hidden when far, visible when near', () {
    // e.g. a wandering NPC at the bottom edge of the view.
    expect(worldLabelAlpha(0, 9 * ts, ts), 0, reason: 'far: hidden');
    expect(worldLabelAlpha(ts, 2 * ts, ts), 1, reason: 'near: visible');
  });

  test('place label: same rule, with a one-tile fade', () {
    expect(worldLabelAlpha((range + 2) * ts, 0, ts), 0);
    expect(worldLabelAlpha(range * ts, 0, ts), 1);
    final mid = worldLabelAlpha((range + 0.5) * ts, 0, ts);
    expect(mid, closeTo(0.5, 1e-9));
  });
}
