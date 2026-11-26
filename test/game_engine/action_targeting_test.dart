import 'package:echos_del_tiempo/game_engine/rules/action_targeting.dart';
import 'package:flutter_test/flutter_test.dart';

/// The action cursor rule (controls.md § Cursor de acción).
void main() {
  const tree = ActionTargetKind.tree;
  ActionTarget at(int x, int y, {bool ok = true, ActionTargetKind k = tree}) =>
      ActionTarget(x, y, k, ok: ok);

  test('auto-select picks the nearest in reach, deterministic tie-break', () {
    final c = [at(6, 6), at(5, 4), at(4, 5), at(7, 5)];
    // Player on (5, 5) facing a wall: (5,4) and (4,5) tie at 1; y first.
    final t = ActionTargeting.select(
        px: 5, py: 5, candidates: c, facing: (0, 1));
    expect(t?.tile, (5, 4));
    // Same input, same answer, in any order.
    expect(
        ActionTargeting.select(
                px: 5, py: 5, candidates: c.reversed, facing: (0, 1))
            ?.tile,
        (5, 4));
  });

  test('out of reach is never selected', () {
    expect(
        ActionTargeting.select(px: 0, py: 0, candidates: [at(2, 0)]), isNull);
  });

  test('a possible target wins over a nearer blocked one', () {
    final t = ActionTargeting.select(
        px: 5,
        py: 5,
        candidates: [at(5, 4, ok: false), at(6, 6)],
        facing: (-1, 0));
    expect(t?.tile, (6, 6));
  });

  test('mouse hover selects that neighbour; off reach falls back', () {
    final c = [at(4, 5), at(6, 6)];
    expect(
        ActionTargeting.select(px: 5, py: 5, candidates: c, hover: (6, 6))
            ?.tile,
        (6, 6));
    expect(
        ActionTargeting.select(
                px: 5, py: 5, candidates: c, hover: (9, 9), facing: (-1, 0))
            ?.tile,
        (4, 5));
    // Hover on an empty tile in reach: back to auto-select.
    expect(
        ActionTargeting.select(
                px: 5, py: 5, candidates: c, hover: (5, 4), facing: (-1, 0))
            ?.tile,
        (4, 5));
  });

  test('WASD direction picks the neighbour on that side', () {
    final c = [at(5, 4), at(5, 6), at(4, 5), at(6, 5)];
    for (final (d, want) in [
      ((-1.0, 0.0), (4, 5)), // A
      ((1.0, 0.0), (6, 5)), // D
      ((0.0, -1.0), (5, 4)), // W
      ((0.0, 1.0), (5, 6)), // S
    ]) {
      final f = ActionTargeting.facingStep(d.$1, d.$2);
      expect(
          ActionTargeting.select(px: 5, py: 5, candidates: c, facing: f)?.tile,
          want);
    }
  });

  test('hold moves on to the next nearest once one is done', () {
    final c = [at(5, 4), at(6, 4), at(3, 3)];
    final first =
        ActionTargeting.select(px: 5, py: 5, candidates: c, facing: (0, -1));
    expect(first?.tile, (5, 4));
    final next = ActionTargeting.select(
        px: 5, py: 5, candidates: c, facing: (0, -1), skip: {first!.tile});
    expect(next?.tile, (6, 4));
    expect(
        ActionTargeting.select(
            px: 5,
            py: 5,
            candidates: c,
            skip: {(5, 4), (6, 4)}),
        isNull,
        reason: '(3, 3) is out of reach');
  });

  test('a tree is selectable from every side', () {
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        if (dx == 0 && dy == 0) continue;
        // Facing away from the tree: still the tree.
        expect(
            ActionTargeting.select(
                    px: 5 + dx,
                    py: 5 + dy,
                    candidates: [at(5, 5)],
                    facing: (dx == 0 ? 1 : dx, 0))
                ?.tile,
            (5, 5));
      }
    }
  });

  test('cursor colour: green possible, orange blocked, none for NPCs', () {
    expect(ActionTargeting.tone(null), CursorTone.none);
    expect(ActionTargeting.tone(at(1, 1)), CursorTone.ok);
    expect(ActionTargeting.tone(at(1, 1, ok: false)), CursorTone.blocked);
    expect(ActionTargeting.tone(at(1, 1, k: ActionTargetKind.npc)),
        CursorTone.none);
  });

  test('two NPCs side by side: one selected, hover / WASD switch it', () {
    const npc = ActionTargetKind.npc;
    final c = [
      const ActionTarget(4, 5, npc, id: 0),
      const ActionTarget(6, 5, npc, id: 1),
    ];
    int? pick({(int, int)? hover, (int, int) f = (0, 1)}) =>
        ActionTargeting.select(
                px: 5, py: 5, candidates: c, hover: hover, facing: f, reach: 3)
            ?.id;
    expect(pick(f: (-1, 0)), 0);
    expect(pick(f: (1, 0)), 1);
    expect(pick(hover: (6, 5), f: (-1, 0)), 1);
    expect(pick(hover: (4, 5), f: (1, 0)), 0);
    // Only one is ever selected (and so only one outlined).
    expect(pick(), anyOf(0, 1));
  });
}
